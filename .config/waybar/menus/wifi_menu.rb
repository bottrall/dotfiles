# frozen_string_literal: true

# Wi-Fi menu, backed by nmcli. Header: the connected network (or state) with
# a radio switch; the caption carries status (signal, connecting, errors in
# the status red). List: networks, connected first, then saved, then by
# signal. Clicking a saved or open network connects; a new secured network
# opens an inline password field. All nmcli calls are async.
#
# No pop-in: the menus process is resident, so it keeps the last snapshot of
# NetworkManager's state (fetched at startup, refreshed on every open) and
# the menu opens with it already rendered. The list viewport has a fixed
# height, and a refresh only re-renders rows when something visible changed,
# so updates never resize or reflow the menu.

module WifiMenu
  module_function

  SIGNAL_GLYPHS = ["\u{F092F}", "\u{F091F}", "\u{F0922}", "\u{F0925}", "\u{F0928}"].freeze
  LOCK_GLYPH = "\u{F033E}"
  WIFI_TYPE = "802-11-wireless"
  ROW_HEIGHT = 44     # matches list.menu-list > row in menus.css
  VISIBLE_ROWS = 8
  LIST_PADDING = 16   # list.menu-list padding, top + bottom

  # ---- pure helpers ----------------------------------------------------

  # nmcli -t separates fields with ':' and escapes ':' and '\' inside them.
  def split_terse(line)
    line.each_char.with_object([[+""], [false]]) do |char, (fields, escaped)|
      if escaped[0]
        fields.last << char
        escaped[0] = false
      elsif char == "\\"
        escaped[0] = true
      elsif char == ":"
        fields << +""
      else
        fields.last << char
      end
    end.first
  end

  def wifi_names(output)
    output.to_s.lines.map { split_terse(it.chomp) }.select { it[1] == WIFI_TYPE }.map(&:first)
  end

  # One entry per SSID (strongest access point), hidden networks dropped,
  # sorted connected, saved, then by signal.
  def parse_networks(output, saved)
    output.to_s.lines.map { split_terse(it.chomp) }
          .select { it.size >= 4 && !it[1].empty? }
          .map do |in_use, ssid, signal, security|
            { ssid:, signal: signal.to_i, secure: !["", "--"].include?(security),
              active: in_use == "*", saved: saved.include?(ssid) }
          end
          .group_by { it[:ssid] }
          .map { |_ssid, aps| aps.max_by { [it[:active] ? 1 : 0, it[:signal]] } }
          .sort_by { [it[:active] ? 0 : 1, it[:saved] ? 0 : 1, -it[:signal]] }
  end

  def signal_glyph(signal) = SIGNAL_GLYPHS[signal.clamp(0, 99) / 20]

  def caption_for(network)
    return "Connected" if network[:active]
    return "Saved" if network[:saved]

    network[:secure] ? LOCK_GLYPH : nil
  end

  def connect_argv(network, password = nil)
    return ["nmcli", "connection", "up", "id", network[:ssid]] if network[:saved]
    return ["nmcli", "device", "wifi", "connect", network[:ssid], "password", password] if password

    ["nmcli", "device", "wifi", "connect", network[:ssid]]
  end

  # What the rows show: a refresh with the same signature changes nothing on
  # screen, so it skips the re-render (signal counts by glyph step).
  def signature(snapshot)
    [snapshot[:enabled], snapshot[:networks].map { [it[:ssid], it[:active], it[:saved], it[:secure], it[:signal] / 20] }]
  end

  # Title and caption for a snapshot (nil = nothing fetched yet).
  def header_text(snapshot)
    return ["Wi-Fi", "Scanning…"] if snapshot.nil?
    return ["Wi-Fi is off", "Turn it on to see networks"] unless snapshot[:enabled]

    active = snapshot[:networks].find { it[:active] }
    active ? [active[:ssid], "Signal #{active[:signal]}%"] : ["Not connected", "Choose a network"]
  end

  # ---- effects ---------------------------------------------------------

  # Run argv without blocking the main loop; yields (ok, output).
  def nmcli(argv, &on_done)
    process = Gio::Subprocess.new(argv, %i[stdout_pipe stderr_merge])
    process.communicate_utf8_async(nil, nil) do |sp, result|
      _ok, out, _err = sp.communicate_utf8_finish(result)
      on_done.call(sp.successful?, out.to_s)
    end
  rescue GLib::Error => e
    on_done.call(false, e.message)
  end

  # NetworkManager's state as a snapshot: { enabled:, active_name:, networks: }.
  # Without --rescan no, nmcli rescans (and waits seconds) whenever its last
  # scan is over ~30s old; rescan: true asks for a fresh scan explicitly.
  def fetch(rescan: false, &on_done)
    nmcli(%w[nmcli radio wifi]) do |_ok, radio_out|
      next on_done.call({ enabled: false, active_name: nil, networks: [] }) unless radio_out.strip == "enabled"

      nmcli(%w[nmcli -t -f NAME,TYPE connection show]) do |_ok2, saved_out|
        nmcli(%w[nmcli -t -f NAME,TYPE connection show --active]) do |_ok3, active_out|
          list = %w[nmcli -t -f IN-USE,SSID,SIGNAL,SECURITY device wifi list --rescan] + [rescan ? "yes" : "no"]
          nmcli(list) do |_ok4, list_out|
            on_done.call({ enabled: true, active_name: wifi_names(active_out).first,
                           networks: parse_networks(list_out, wifi_names(saved_out)) })
          end
        end
      end
    end
  end

  # ---- UI --------------------------------------------------------------

  # cache: a Hash shared across opens (owned by menus.rb); cache[:snapshot]
  # is the last known state, so the menu can open fully rendered.
  def build(app, offset:, cache:, **)
    MenuUI.dropdown(app, width: 360, offset:).tap do |window|
      alive = true
      window.signal_connect("destroy") { alive = false }

      radio = Gtk::Switch.new.tap { it.valign = :center }
      header, (_overline, title, caption) = MenuUI.header("Wi-Fi", "", "", trailing: radio)

      password_entry = Gtk::PasswordEntry.new.tap do |entry|
        entry.show_peek_icon = true
        entry.hexpand = true
      end
      password_label = MenuUI.label("", "caption")
      connect_button = MenuUI.button("Connect", "menu-button", "primary") {}
      password_box = MenuUI.vbox(password_label, MenuUI.hbox(password_entry, connect_button, spacing: 8),
                                 css: "password")
      password_box.visible = false

      rows = {}
      state = { pending: nil, shown: nil, syncing: false }
      list = nil

      set_status = lambda do |text, error: false|
        caption.text = text
        error ? caption.add_css_class("error") : caption.remove_css_class("error")
      end

      scroller = Gtk::ScrolledWindow.new.tap do |scrolled|
        scrolled.set_policy(:never, :automatic)
        height = (VISIBLE_ROWS * ROW_HEIGHT) + LIST_PADDING
        scrolled.min_content_height = height
        scrolled.max_content_height = height
      end
      disconnect = MenuUI.button("Disconnect", "menu-button") {}
      footer = MenuUI.vbox(disconnect, css: "footer")

      render_rows = lambda do |snapshot|
        rows.clear
        while (child = list.first_child)
          list.remove(child)
        end
        snapshot[:networks].each do |network|
          row = MenuUI.row(signal_glyph(network[:signal]), network[:ssid], caption: caption_for(network),
                                                                          css: network[:active] ? "active" : nil)
          rows[row] = network
          list.append(row)
        end
      end

      # Header text always follows the snapshot; rows, the switch and the
      # footer only change when the signature does.
      show = lambda do |snapshot|
        title.text, status = header_text(snapshot)
        set_status.call(status)
        next if snapshot.nil? || signature(snapshot) == state[:shown]

        state[:shown] = signature(snapshot)
        state[:syncing] = true
        radio.active = snapshot[:enabled]
        state[:syncing] = false
        scroller.visible = snapshot[:enabled]
        footer.visible = snapshot[:networks].any? { it[:active] }
        render_rows.call(snapshot)
      end

      refresh = lambda do |rescan: false|
        fetch(rescan:) do |snapshot|
          cache[:snapshot] = snapshot
          show.call(snapshot) if alive
        end
      end

      connect = lambda do |network, password = nil|
        password_box.visible = false
        set_status.call("Connecting to #{network[:ssid]}…")
        nmcli(connect_argv(network, password)) do |ok, _out|
          next unless alive
          next refresh.call if ok

          set_status.call("Couldn't connect to #{network[:ssid]}", error: true)
        end
      end

      ask_password = lambda do |network|
        state[:pending] = network
        password_label.text = "Password for #{network[:ssid]}"
        password_entry.text = ""
        password_box.visible = true
        password_entry.grab_focus
      end
      submit = lambda do
        network = state[:pending]
        connect.call(network, password_entry.text) if network && !password_entry.text.empty?
      end
      password_entry.signal_connect("activate") { submit.call }
      connect_button.signal_connect("clicked") { submit.call }

      list = MenuUI.list do |row|
        network = rows[row]
        next unless network && !network[:active]

        network[:secure] && !network[:saved] ? ask_password.call(network) : connect.call(network)
      end
      scroller.child = list

      disconnect.signal_connect("clicked") do
        name = cache.dig(:snapshot, :active_name)
        next unless name

        set_status.call("Disconnecting…")
        nmcli(["nmcli", "connection", "down", "id", name]) { refresh.call if alive }
      end

      radio.signal_connect("state-set") do |_switch, on|
        next false if state[:syncing] # set from code, not by the user

        set_status.call(on ? "Turning Wi-Fi on…" : "Turning Wi-Fi off…")
        nmcli(["nmcli", "radio", "wifi", on ? "on" : "off"]) do
          GLib::Timeout.add(on ? 1500 : 300) { refresh.call(rescan: on) if alive; false }
        end
        false
      end

      window.child = MenuUI.vbox(header, password_box, scroller, footer)
      footer.visible = false
      show.call(cache[:snapshot])
      # Cached list first (fast), then a fresh scan; each only re-renders if
      # something visible changed.
      refresh.call
      GLib::Timeout.add(200) { refresh.call(rescan: true) if alive; false }
    end
  end
end
