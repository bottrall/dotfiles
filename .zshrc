eval "$(starship init zsh)"
eval "$(rbenv init -)"

# Source shared configs
for f in ~/.config/sh/*.sh; do
  [[ -f "$f" ]] && source "$f"
done

# Source modular configs
for f in ~/.config/zsh/*.zsh; do
  [[ -f "$f" ]] && source "$f"
done

# Machine-specific overrides (not tracked)
[[ -f ~/.zshrc.local ]] && source ~/.zshrc.local
