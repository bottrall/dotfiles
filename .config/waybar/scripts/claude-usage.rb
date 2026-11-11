#!/usr/bin/env ruby
# frozen_string_literal: true

# Waybar module: Claude Code 5-hour and weekly usage limits.
#
# Reads the OAuth token Claude Code stores at ~/.claude/.credentials.json and
# queries Anthropic's official usage endpoint, so the numbers match what
# `/usage` shows in-app and cover account-wide activity across machines.
# Prints one line of JSON for a waybar custom module (return-type: "json").
#
# Display follows the hotglass contract (hotglass/DESIGN.md): healthy state is
# neutral — the bar shows "5h N% · 7d N%" and the tooltip adds progress bars
# and reset countdowns, all in plain text. Color means attention: the class
# turns claude-usage-warning at WARNING_PCT and claude-usage-critical at
# CRITICAL_PCT on the fuller window, and claude-usage-error on failure.
#
# Rate limiting: the API is hit at most once per CACHE_TTL, no matter how
# often waybar re-renders, and the last good response is kept in ~/.cache and
# served (with a note in the tooltip) if the endpoint errors or rate-limits.

require 'json'
require 'net/http'
require 'time'
require 'yaml'

CREDENTIALS_PATH = File.expand_path('~/.claude/.credentials.json')
ENDPOINT = URI('https://api.anthropic.com/api/oauth/usage')
CACHE_PATH = File.expand_path('~/.cache/claude-usage.json')
CACHE_TTL = 300 # seconds between real API hits
TOKENS_PATH = File.expand_path('~/.config/hotglass/tokens.yml')
WINDOWS = [
  { key: 'five_hour', label: '5-hour', short: '5h' },
  { key: 'seven_day', label: 'Weekly', short: '7d' },
].freeze
USER_AGENT = 'claude-usage-waybar/1.0'
WARNING_PCT = 80
CRITICAL_PCT = 95

# Identity comes from the Clawd image module paired next to this one in the
# bar (see group/claude-usage in config.jsonc), so text stays numbers-only.
FetchError = Class.new(StandardError)

# --- pure helpers -------------------------------------------------------------

def clamp_pct(value)
  value.clamp(0.0, 100.0)
end

def relative_time(seconds)
  return 'now' if seconds <= 0

  days, rem = seconds.divmod(86_400)
  hours, rem = rem.divmod(3_600)
  mins, = rem.divmod(60)
  return "#{days}d #{hours}h" if days.positive?
  return "#{hours}h #{mins}m" if hours.positive?

  "#{mins}m"
end

# Accent and status colors from the hotglass tokens, for the tooltip bars.
def palette
  tokens = YAML.load_file(TOKENS_PATH)
  { accent: "##{tokens.dig('accent', 'base')}", yellow: "##{tokens.dig('status', 'yellow')}",
    red: "##{tokens.dig('status', 'red')}" }
rescue Errno::ENOENT, Psych::SyntaxError, NoMethodError
  { accent: '#FF52AB', yellow: '#FFC44D', red: '#FF6A4D' }
end

# Progress fills are accent; past the thresholds they take the status color.
def fill_color(pct, colors)
  return colors[:red] if pct >= CRITICAL_PCT
  return colors[:yellow] if pct >= WARNING_PCT

  colors[:accent]
end

def mini_bar(pct, color, width = 12)
  filled = (pct / 100.0 * width).round.clamp(0, width)
  "<span foreground='#{color}'>#{'━' * filled}</span><span alpha='30%'>#{'━' * (width - filled)}</span>"
end

def parse_window(entry, window)
  # resets_at is null while the window is idle (no active session)
  resets_at = entry.fetch('resets_at')&.then { |t| Time.iso8601(t) }
  {
    label: window[:label],
    short: window[:short],
    used: clamp_pct(Float(entry.fetch('utilization'))),
    resets_at:,
  }
rescue KeyError, TypeError, ArgumentError
  raise FetchError, 'unexpected response shape'
end

def bar_text(windows)
  windows.map { |w| "#{w[:short]} #{w[:used].round}%" }.join(' · ')
end

# Tooltips share one shape (hotglass/DESIGN.md): what it is (600), values
# (secondary), extra detail (tertiary). Rows are set in the mono face so the
# bars and percentages line up.
def tooltip_line(window, colors)
  tail = window[:resets_at] ? "resets in #{relative_time(window[:resets_at] - Time.now)}" : 'idle'
  used = window[:used]
  row = "<span alpha='72%'>#{window[:label].ljust(6)}</span>  #{mini_bar(used, fill_color(used, colors))}  " \
        "#{format('%3d', used.round)}%"
  "<span font_family='CaskaydiaCove Nerd Font'>#{row}</span>  <span alpha='49%'>#{tail}</span>"
end

def tooltip(windows, note: nil)
  colors = palette
  lines = ["<span weight='600'>Claude Code usage</span>", *windows.map { |w| tooltip_line(w, colors) }]
  lines << "<span alpha='49%'>Showing cached numbers (#{note})</span>" if note
  lines.join("\n")
end

def usage_class(windows)
  peak = windows.map { |w| w[:used] }.max || 0
  return 'claude-usage-critical' if peak >= CRITICAL_PCT
  return 'claude-usage-warning' if peak >= WARNING_PCT

  'claude-usage'
end

def payload_from(windows, note: nil)
  { text: bar_text(windows), tooltip: tooltip(windows, note:), class: usage_class(windows) }
end

def emit(payload)
  puts JSON.generate(payload)
end

def windows_from_cache(cache)
  cache.fetch('windows').map do |w|
    { label: w.fetch('label'), short: w.fetch('short'), used: w.fetch('used'), resets_at: w.fetch('resets_at')&.then { |t| Time.iso8601(t) } }
  end
rescue KeyError, TypeError, ArgumentError, JSON::ParserError
  nil
end

# --- effects: credentials, network, cache --------------------------------------

def read_token
  oauth = JSON.parse(File.read(CREDENTIALS_PATH)).fetch('claudeAiOauth', {})
  token = oauth.fetch('accessToken')
  raise FetchError, 'token expired' if Time.now >= Time.at(Float(oauth.fetch('expiresAt')) / 1000)

  token
rescue Errno::ENOENT, JSON::ParserError, KeyError, TypeError, ArgumentError
  raise FetchError, 'credentials not found or invalid'
end

def fetch_windows(token)
  response = Net::HTTP.get_response(
    ENDPOINT,
    {
      'Authorization' => "Bearer #{token}",
      'Accept' => 'application/json',
      'Content-Type' => 'application/json',
      'User-Agent' => USER_AGENT,
      'anthropic-beta' => 'oauth-2025-04-20',
    },
  )
  raise FetchError, "HTTP #{response.code}" unless response.is_a?(Net::HTTPSuccess)

  data = JSON.parse(response.body)
  WINDOWS.filter_map { |window| parse_window(data[window[:key]], window) if data[window[:key]] }
rescue JSON::ParserError, Net::ReadTimeout, SocketError, Errno::ECONNREFUSED, OpenSSL::SSL::SSLError
  raise FetchError, 'network error'
end

def read_cache
  raw = JSON.parse(File.read(CACHE_PATH))
  return nil unless Time.now.to_i - raw.fetch('fetched_at', 0) < CACHE_TTL

  raw
rescue Errno::ENOENT, JSON::ParserError, KeyError
  nil
end

def write_cache(windows)
  File.write(CACHE_PATH, JSON.generate({
    'fetched_at' => Time.now.to_i,
    'windows' => windows.map { |w| { 'label' => w[:label], 'short' => w[:short], 'used' => w[:used], 'resets_at' => w[:resets_at]&.iso8601 } },
  }))
rescue Errno::ENOENT, IOError
  nil # a failed cache write just costs us the next cache hit
end

# --- entry point ---------------------------------------------------------------

def usage_payload
  fresh = read_cache
  return payload_from(windows_from_cache(fresh)) if fresh && windows_from_cache(fresh)

  windows = fetch_windows(read_token)
  write_cache(windows)
  payload_from(windows)
rescue FetchError => e
  stale = JSON.parse(File.read(CACHE_PATH)) rescue nil
  cached = stale && windows_from_cache(stale)
  return payload_from(cached, note: e.message) if cached

  { text: 'n/a', tooltip: "<span weight='600'>Claude Code usage</span>\n<span alpha='72%'>Couldn't load: #{e.message}</span>", class: 'claude-usage-error' }
end

emit(usage_payload)
