# frozen_string_literal: true

# Shared building blocks for the hotglass bar menus: layer-shell setup, the
# click catcher, and the header / row / button widgets every menu is made of.
# Styling lives in menus.css (generated from hotglass/templates/menus.css.erb).

require "yaml"

module LayerShell; end
GObjectIntrospection::Loader.new(LayerShell).load("Gtk4LayerShell")

module MenuUI
  module_function

  TOKENS_PATH = File.expand_path("~/.config/hotglass/tokens.yml")

  # Overlays sit overlay_offset from the bar and the screen edge (tokens.yml).
  def overlay_offset
    YAML.load_file(TOKENS_PATH).fetch("overlay_offset", 24)
  rescue Errno::ENOENT, Psych::SyntaxError
    24
  end

  def make_layer(window, namespace:, anchors:, keyboard:, margin: 0, exclusive: nil)
    return unless LayerShell.supported?

    LayerShell.init_for_window(window)
    LayerShell.set_namespace(window, namespace)
    LayerShell.set_layer(window, LayerShell::Layer::OVERLAY)
    anchors.each do |edge|
      LayerShell.set_anchor(window, edge, true)
      LayerShell.set_margin(window, edge, margin)
    end
    LayerShell.set_keyboard_mode(window, keyboard)
    LayerShell.set_exclusive_zone(window, exclusive) if exclusive
  end

  # Top-right under the bar. Layers respect waybar's exclusive zone, so the
  # margin is measured from the bar's bottom edge. Keyboard focus on demand:
  # it has focus when it opens, so Esc and arrow keys work at once.
  def dropdown(app, width:, offset:)
    Gtk::ApplicationWindow.new(app).tap do |window|
      window.decorated = false
      window.resizable = false
      window.add_css_class("hotglass-menu")
      window.set_default_size(width, -1)
      make_layer(window, namespace: "hotglass-menu",
                         anchors: [LayerShell::Edge::TOP, LayerShell::Edge::RIGHT],
                         keyboard: LayerShell::KeyboardMode::ON_DEMAND, margin: offset)
    end
  end

  # An invisible full-screen layer (the bar included: exclusive zone -1)
  # beneath the open menu; any click on it closes the menu. Closing on focus
  # loss can't work with Hyprland's follow_mouse, which moves focus on hover.
  def catcher(app, &on_click)
    Gtk::ApplicationWindow.new(app).tap do |catcher|
      catcher.decorated = false
      catcher.add_css_class("hotglass-menu-catcher")
      edges = LayerShell::Edge
      make_layer(catcher, namespace: "hotglass-menu-catcher",
                          anchors: [edges::TOP, edges::BOTTOM, edges::LEFT, edges::RIGHT],
                          keyboard: LayerShell::KeyboardMode::NONE, exclusive: -1)
      # GTK won't map a window with no content.
      catcher.child = Gtk::Box.new(:vertical, 0).tap do |fill|
        fill.hexpand = true
        fill.vexpand = true
      end
      click = Gtk::GestureClick.new
      click.button = 0 # any button
      click.signal_connect("pressed") { on_click.call }
      catcher.add_controller(click)
    end
  end

  def on_escape(window, &block)
    keys = Gtk::EventControllerKey.new
    keys.signal_connect("key-pressed") do |_controller, keyval, _keycode, _state|
      next false unless keyval == Gdk::Keyval::KEY_Escape

      block.call
      true
    end
    window.add_controller(keys)
  end

  def label(text, *css_classes, xalign: 0.0)
    Gtk::Label.new(text).tap do |widget|
      widget.xalign = xalign
      css_classes.each { widget.add_css_class(it) }
    end
  end

  def vbox(*children, css: nil)
    Gtk::Box.new(:vertical, 0).tap do |box|
      box.add_css_class(css) if css
      children.compact.each { box.append(it) }
    end
  end

  def hbox(*children, css: nil, spacing: 0)
    Gtk::Box.new(:horizontal, spacing).tap do |box|
      box.add_css_class(css) if css
      children.compact.each { box.append(it) }
    end
  end

  # Overline / title / caption block, split from the body by a hairline.
  # Returns [widget, labels] so callers can update the text later.
  def header(overline, title, caption, trailing: nil)
    labels = [label(overline, "overline"), label(title, "title"), label(caption, "caption")]
    text = vbox(*labels)
    text.hexpand = true
    [hbox(text, trailing, css: "header"), labels]
  end

  # A 44px menu row: glyph, label, optional trailing caption.
  def row(glyph, text, caption: nil, css: nil)
    content = hbox(label(glyph, "row-glyph"), label(text, "row-label").tap { it.hexpand = true },
                   caption && label(caption, "row-caption"))
    Gtk::ListBoxRow.new.tap do |row|
      row.child = content
      row.add_css_class(css) if css
    end
  end

  def list(&on_activate)
    Gtk::ListBox.new.tap do |list|
      list.selection_mode = :none
      list.add_css_class("menu-list")
      list.signal_connect("row-activated") { |_list, row| on_activate.call(row) }
    end
  end

  def separator = Gtk::Separator.new(:horizontal).tap { it.add_css_class("menu-separator") }

  # A hairline inside a list: a row that can't be activated, selected or
  # focused, so clicks and arrow keys pass over it.
  def separator_row
    Gtk::ListBoxRow.new.tap do |row|
      row.child = separator
      row.activatable = false
      row.selectable = false
      row.focusable = false
      row.add_css_class("separator-row")
    end
  end

  def button(text, *css_classes, &on_click)
    Gtk::Button.new(label: text).tap do |button|
      css_classes.each { button.add_css_class(it) }
      button.signal_connect("clicked") { on_click.call }
    end
  end

  # Fire and forget a command, detached from the menu process.
  def spawn(*argv)
    Process.detach(Process.spawn(*argv, %i[out err] => File::NULL, pgroup: true))
  end
end
