# frozen_string_literal: true

# Power menu: who and how long, then Lock / Suspend, a hairline, and the
# session-ending actions. Those carry "…" and open an inline confirm with
# the destructive button in the status red, so a stray click can't power off.

require "socket"

module PowerMenu
  module_function

  ACTIONS = [
    { id: :lock, glyph: "\u{F033E}", label: "Lock", argv: %w[loginctl lock-session] },
    { id: :suspend, glyph: "\u{F0904}", label: "Suspend", argv: %w[systemctl suspend] },
    :separator,
    { id: :logout, glyph: "\u{F0343}", label: "Log out…", verb: "Log out",
      detail: "Open apps will be closed.", argv: ["hyprctl", "eval", "hl.dispatch(hl.dsp.exit())"] },
    { id: :restart, glyph: "\u{F0709}", label: "Restart…", verb: "Restart",
      detail: "Open apps will be closed.", argv: %w[systemctl reboot] },
    { id: :shutdown, glyph: "\u{F0425}", label: "Shut down…", verb: "Shut down",
      detail: "Open apps will be closed.", argv: %w[systemctl poweroff] },
  ].freeze

  def uptime_text(seconds)
    hours, rest = seconds.to_i.divmod(3600)
    minutes = rest / 60
    days, hours = hours.divmod(24)
    parts = [("#{days} d" if days.positive?), ("#{hours} h" if hours.positive?), "#{minutes} min"].compact
    "Up #{parts.join(' ')}"
  end

  def uptime_seconds = File.read("/proc/uptime").split.first.to_f

  def build(app, offset:, close:, **)
    MenuUI.dropdown(app, width: 300, offset:).tap do |window|
      header, = MenuUI.header("Power", "#{ENV.fetch('USER', 'you')} on #{Socket.gethostname}",
                              uptime_text(uptime_seconds))
      stack = Gtk::Stack.new
      stack.transition_type = :crossfade
      stack.transition_duration = 120

      run = lambda do |action|
        close.call
        MenuUI.spawn(*action.fetch(:argv))
      end

      confirm_for = lambda do |action|
        title = MenuUI.label("#{action.fetch(:verb)} now?", "title")
        detail = MenuUI.label(action.fetch(:detail), "caption")
        cancel = MenuUI.button("Cancel", "menu-button") { stack.visible_child_name = "list" }
        go = MenuUI.button(action.fetch(:verb), "menu-button", "danger") { run.call(action) }
        buttons = MenuUI.hbox(cancel, go, css: "button-row")
        buttons.homogeneous = true
        MenuUI.vbox(MenuUI.vbox(title, detail, css: "confirm"), buttons)
      end

      rows = {}
      list = MenuUI.list do |row|
        action = rows[row]
        next unless action
        next run.call(action) unless action[:verb]

        stack.remove(stack.get_child_by_name("confirm")) if stack.get_child_by_name("confirm")
        stack.add_named(confirm_for.call(action), "confirm")
        stack.visible_child_name = "confirm"
      end
      ACTIONS.each do |action|
        next list.append(MenuUI.separator_row) if action == :separator

        row = MenuUI.row(action.fetch(:glyph), action.fetch(:label))
        rows[row] = action
        list.append(row)
      end

      stack.add_named(list, "list")
      stack.visible_child_name = "list"
      window.child = MenuUI.vbox(header, stack)
    end
  end
end
