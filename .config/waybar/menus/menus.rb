#!/usr/bin/env ruby
# frozen_string_literal: true

# hotglass bar menus: calendar (clock), power and wifi, in one resident
# process. Each menu is a layer-shell dropdown under the bar with a click
# catcher beneath it: click anywhere else or press Esc to close; opening a
# menu closes any other.
#
#   menus.rb --gapplication-service   start resident (Hyprland does this at login)
#   toggle.sh calendar|power|wifi     toggle a menu over D-Bus (~15ms), or
#                                     start this script with the name (~1s)
#
# Loading the GTK gems takes about a second, which is why it stays resident.
# gtk4-layer-shell must be loaded before libwayland, so the script re-execs
# itself with it preloaded. Needs the ruby-gnome gtk4 gem (`gem install
# gtk4`). Styling: menus.css, generated from hotglass/templates/menus.css.erb.
# After editing these files, restart it: pkill -f menus.rb, then toggle.sh.

require "rbconfig"

LAYER_SHELL_LIB = "/usr/lib/libgtk4-layer-shell.so"
if File.exist?(LAYER_SHELL_LIB) && !ENV.fetch("LD_PRELOAD", "").include?(LAYER_SHELL_LIB)
  preload = [LAYER_SHELL_LIB, ENV.fetch("LD_PRELOAD", nil)].compact.reject(&:empty?).join(":")
  exec({ "LD_PRELOAD" => preload }, RbConfig.ruby, __FILE__, *ARGV)
end

require "gtk4"
require_relative "ui"
require_relative "calendar_menu"
require_relative "power_menu"
require_relative "wifi_menu"

APP_ID = "dev.jake.hotglass.menus"
CSS_PATH = File.join(__dir__, "menus.css")

# Which menu is open, and its window and catcher. The one stateful piece;
# menus themselves are built fresh on every open.
class MenuHost
  def initialize(app, builders, offset:)
    @app = app
    @builders = builders
    @offset = offset
    @open = nil
    @windows = []
  end

  def toggle(name)
    return close if @open == name

    open(name)
  end

  def open(name)
    close
    builder = @builders.fetch(name)
    catcher = MenuUI.catcher(@app) { close }
    menu = builder.call(@app, offset: @offset, close: method(:close))
    MenuUI.on_escape(menu) { close }
    @windows = [catcher, menu]
    @open = name
    @windows.each(&:present)
  end

  def close
    @windows.each(&:destroy)
    @windows = []
    @open = nil
  end
end

def load_css
  return unless File.exist?(CSS_PATH)

  provider = Gtk::CssProvider.new
  provider.load(path: CSS_PATH)
  Gtk::StyleContext.add_provider_for_display(Gdk::Display.default, provider, Gtk::StyleProvider::PRIORITY_USER + 1)
end

BUILDERS = {
  "calendar" => CalendarMenu.method(:build),
  "power" => PowerMenu.method(:build),
  "wifi" => WifiMenu.method(:build),
}.freeze

app = Gtk::Application.new(APP_ID, :handles_command_line)
host = nil

app.signal_connect("startup") do |application|
  application.hold # stay resident between opens
  load_css
  host = MenuHost.new(application, BUILDERS, offset: MenuUI.overlay_offset)
  BUILDERS.each_key do |name|
    action = Gio::SimpleAction.new(name)
    action.signal_connect("activate") { host.toggle(name) }
    application.add_action(action)
  end
end

# `menus.rb power` (or a second launch) toggles that menu in the primary
# instance; with no name it just stays resident.
app.signal_connect("command-line") do |_application, command_line|
  name = command_line.arguments.drop(1).first
  host.toggle(name) if BUILDERS.key?(name)
  0
end

exit(app.run([$PROGRAM_NAME, *ARGV]))
