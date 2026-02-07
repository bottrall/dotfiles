eval "$(starship init bash)"
eval "$(rbenv init -)"

# Source shared configs
for f in ~/.config/sh/*.sh; do
  [[ -f "$f" ]] && source "$f"
done

# Source modular configs
for f in ~/.config/bash/*.bash; do
  [[ -f "$f" ]] && source "$f"
done

# Machine-specific overrides (not tracked)
[[ -f ~/.bashrc.local ]] && source ~/.bashrc.local
