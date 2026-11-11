# frozen_string_literal: true

# Clock menu: the selected day as overline / title / caption, and a month
# grid with today marked by the accent.

require "date"

module CalendarMenu
  module_function

  def days_in_year(year) = Date.new(year, 12, 31).yday

  # Overline, title and caption for the selected day.
  def header_lines(day, today)
    overline = day == today ? "Today" : day.strftime("%A")
    title = day == today ? day.strftime("%A %-d %B %Y") : day.strftime("%-d %B %Y")
    caption = "Week #{day.cweek} · Day #{day.yday} of #{days_in_year(day.year)}"
    [overline, title, caption]
  end

  def to_date(date_time) = Date.new(date_time.year, date_time.month, date_time.day_of_month)

  def build(app, offset:, today: Date.today, **)
    MenuUI.dropdown(app, width: 360, offset:).tap do |window|
      header, labels = MenuUI.header("", "", "")
      calendar = Gtk::Calendar.new
      refresh = lambda do
        header_lines(to_date(calendar.date), today).zip(labels).each { |text, label| label.text = text }
      end
      calendar.signal_connect("day-selected") { refresh.call }
      window.child = MenuUI.vbox(header, calendar)
      refresh.call
    end
  end
end
