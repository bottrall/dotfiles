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
# neutral — the bar shows "<icon> N% used" per window and the tooltip adds
# progress bars and reset countdowns, all in plain text. Only the failure
# state carries a status color, via the claude-usage-error class in style.css.
#
# Rate limiting: the API is hit at most once per CACHE_TTL, no matter how
# often waybar re-renders, and the last good response is kept in ~/.cache and
# served (with a note in the tooltip) if the endpoint errors or rate-limits.

require 'json'
require 'net/http'
require 'time'

CREDENTIALS_PATH = File.expand_path('~/.claude/.credentials.json')
ENDPOINT = URI('https://api.anthropic.com/api/oauth/usage')
CACHE_PATH = File.expand_path('~/.cache/claude-usage.json')
CACHE_TTL = 300 # seconds between real API hits
WINDOWS = [
  { key: 'five_hour', label: '5-hour', short: '5h' },
  { key: 'seven_day', label: 'Weekly', short: '7d' },
].freeze
USER_AGENT = 'claude-usage-waybar/1.0'

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

def mini_bar(pct, width = 10)
  filled = (pct / 100.0 * width).round.clamp(0, width)
  ('█' * filled) + ('░' * (width - filled))
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

def tooltip_line(window)
  tail = window[:resets_at] ? "resets in #{relative_time(window[:resets_at] - Time.now)}" : 'idle'
  "#{window[:label].ljust(6)}  #{mini_bar(window[:used])}  #{window[:used].round}% used · #{tail}"
end

def tooltip(windows, note: nil)
  lines = ['<b>Claude Code usage</b>', *windows.map { |w| tooltip_line(w) }]
  lines << "(cached: #{note})" if note
  lines.join("\n")
end

def payload_from(windows, note: nil)
  { text: bar_text(windows), tooltip: tooltip(windows, note:), class: 'claude-usage' }
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

  { text: 'n/a', tooltip: "<b>Claude Code usage</b>\n#{e.message}", class: 'claude-usage-error' }
end

emit(usage_payload)
