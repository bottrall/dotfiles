# frozen_string_literal: true

# Wi-Fi menu, backed by nmcli. Header: the connected network (or state) with
# a radio switch; the caption carries status (scanning, connecting, errors in
# the status red). List: networks, connected first, then saved, then by
# signal. Clicking a saved or open network connects; a new secured network
# opens an inline password field. All nmcli calls are async, so the menu
# never freezes while NetworkManager works.

module WifiMenu
  module_function

  SIGNAL_GLYPHS = ["\u{F092F}", "\u{F091F}", "\u{F0922}", "\u{F0925}", "\u{F0928}"].freeze
  LOCK_GLYPH = "\u{F033E}"
  WIFI_TYPE = "802-11-wireless"

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

  # ---- UI --------------------------------------------------------------

  def build(app, offset:, **)
    MenuUI.dropdown(app, width: 360, offset:).tap do |window|
      alive = true
      window.signal_connect("destroy") { alive = false }

      radio = Gtk::Switch.new.tap { it.valign = :center }
      header, (overline, title, caption) = MenuUI.header("Wi-Fi", "", "Scanning…", trailing: radio)

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
      state = { networks: [], active_name: nil, pending: nil }

      set_status = lambda do |text, error: false|
        caption.text = text
        error ? caption.add_css_class("error") : caption.remove_css_class("error")
      end

      list = nil
      refresh = nil
      connect = lambda do |network, password = nil|
        password_box.visible = false
        set_status.call("Connecting to #{network[:ssid]}…")
        nmcli(connect_argv(network, password)) do |ok, _out|
          next unless alive

          if ok
            refresh.call
          else
            set_status.call("Couldn't connect to #{network[:ssid]}", error: true)
          end
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

      disconnect = MenuUI.button("Disconnect", "menu-button") do
        next unless state[:active_name]

        set_status.call("Disconnecting…")
        nmcli(["nmcli", "connection", "down", "id", state[:active_name]]) { refresh.call if alive }
      end
      footer = MenuUI.vbox(disconnect, css: "footer")

      render = lambda do |enabled|
        rows.clear
        while (child = list.first_child)
          list.remove(child)
        end
        active = state[:networks].find { it[:active] }
        title.text = enabled ? (active ? active[:ssid] : "Not connected") : "Wi-Fi is off"
        set_status.call(enabled ? (active ? "Signal #{active[:signal]}%" : "Choose a network") : "Turn it on to see networks")
        footer.visible = !active.nil?
        state[:networks].first(12).each do |network|
          row = MenuUI.row(signal_glyph(network[:signal]), network[:ssid], caption: caption_for(network),
                                                                          css: network[:active] ? "active" : nil)
          rows[row] = network
          list.append(row)
        end
      end

      refresh = lambda do |rescan: false|
        nmcli(%w[nmcli radio wifi]) do |_ok, radio_out|
          next unless alive

          enabled = radio_out.strip == "enabled"
          state[:syncing] = true
          radio.active = enabled
          state[:syncing] = false
          unless enabled
            state[:networks] = []
            render.call(false)
            next
          end

          nmcli(%w[nmcli -t -f NAME,TYPE connection show]) do |_ok2, saved_out|
            nmcli(%w[nmcli -t -f NAME,TYPE connection show --active]) do |_ok3, active_out|
              args = %w[nmcli -t -f IN-USE,SSID,SIGNAL,SECURITY device wifi list]
              # Without --rescan no, nmcli rescans (and waits) when its last
              # scan is over ~30s old; show the cached list now, rescan after.
              args += rescan ? %w[--rescan yes] : %w[--rescan no]
              nmcli(args) do |_ok4, list_out|
                next unless alive

                state[:active_name] = wifi_names(active_out).first
                state[:networks] = parse_networks(list_out, wifi_names(saved_out))
                render.call(true)
              end
            end
          end
        end
      end

      radio.signal_connect("state-set") do |_switch, on|
        next false if state[:syncing] # set from code, not by the user

        set_status.call(on ? "Turning Wi-Fi on…" : "Turning Wi-Fi off…")
        nmcli(["nmcli", "radio", "wifi", on ? "on" : "off"]) do
          GLib::Timeout.add(on ? 1500 : 300) { refresh.call(rescan: on) if alive; false }
        end
        false
      end

      scroller = Gtk::ScrolledWindow.new.tap do |scrolled|
        scrolled.set_policy(:never, :automatic)
        scrolled.propagate_natural_height = true
        scrolled.max_content_height = 360
        scrolled.child = list
      end
      window.child = MenuUI.vbox(header, password_box, scroller, footer)
      footer.visible = false
      refresh.call
      GLib::Timeout.add(200) { refresh.call(rescan: true) if alive; false }
    end
  end
end
