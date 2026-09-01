# repos — print the machine-local project list, one absolute path per line.
#
# The shared source of truth for any script/automation that iterates local
# repos (sweep, future tooling). Reads ~/.repos.local — untracked and
# machine-specific, same convention as ~/.zshrc.local. One path per line,
# # comments and ~ expansion supported. Override the file with $REPOS_FILE.
#
# Usage:
#   repos
#   repos | while IFS= read -r r; do ...; done

repos() {
  local file="${REPOS_FILE:-$HOME/.repos.local}" line
  if [[ ! -f "$file" ]]; then
    echo "No project list found at $file" >&2
    echo "Create it with one repo path per line, e.g.:" >&2
    echo "" >&2
    echo "  # machine-local project list" >&2
    echo "  ~/code/my-app" >&2
    echo "  ~/code/another-repo" >&2
    return 1
  fi
  while IFS= read -r line; do
    line="${line%%#*}"
    line=$(printf '%s' "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    [[ -z "$line" ]] && continue
    printf '%s\n' "${line/#\~/$HOME}"
  done < "$file"
}
