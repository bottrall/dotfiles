export NVM_DIR="$([ -z "${XDG_CONFIG_HOME-}" ] && printf %s "${HOME}/.nvm" || printf %s "${XDG_CONFIG_HOME}/nvm")"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

autoload -U add-zsh-hook

load-nvmrc() {
  local nvmrc_path="$(nvm_find_nvmrc)"

  # If we found an .nvmrc and it's different from the last one we processed
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
  # No .nvmrc found - only reset to default if we were previously using one
  elif [[ -n "$_nvmrc_previous_path" ]]; then
    _nvmrc_previous_path=""
    nvm use default > /dev/null
  fi
}

add-zsh-hook chpwd load-nvmrc
load-nvmrc
