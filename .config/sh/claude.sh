function cc() {
  printf '\033]0;claude: %s\007' "$(basename "$PWD")"
  CLAUDE_CODE_DISABLE_TERMINAL_TITLE=1 claude "$@"
}
