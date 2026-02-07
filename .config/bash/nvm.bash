export NVM_DIR="$([ -z "${XDG_CONFIG_HOME-}" ] && printf %s "${HOME}/.nvm" || printf %s "${XDG_CONFIG_HOME}/nvm")"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

load-nvmrc() {
  local nvmrc_path="$(nvm_find_nvmrc)"

  if [[ -n "$nvmrc_path" ]]; then
    if [[ "$nvmrc_path" != "$_nvmrc_previous_path" ]]; then
      _nvmrc_previous_path="$nvmrc_path"
      local nvmrc_node_version="$(cat "$nvmrc_path")"

      if [[ "$nvmrc_node_version" = "lts/*" ]]; then
        nvm use --lts > /dev/null
      else
        nvm use > /dev/null
      fi
    fi
  elif [[ -n "$_nvmrc_previous_path" ]]; then
    _nvmrc_previous_path=""
    nvm use default > /dev/null
  fi
}

PROMPT_COMMAND="load-nvmrc${PROMPT_COMMAND:+;$PROMPT_COMMAND}"
load-nvmrc
