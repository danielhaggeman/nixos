# Created by newuser for 5.9
# ----------------------
# ZSH CONFIG
# ----------------------

# E for Yazi
alias e="yazi"

# Enable colors
autoload -U colors && colors

# Smooth GPU-friendly prompt (Pokémon style)
PROMPT=$'%F{red}%n%f@%F{blue}%m%f %F{magenta}[%~]%f\n%F{green}▶%f %F{cyan}❯%f '

# Core smoothness options
setopt PROMPT_SUBST
setopt AUTO_CD
setopt HIST_IGNORE_DUPS
setopt SHARE_HISTORY

# Enable Kitty GPU features
export TERM=kitty
export KITTY_ENABLE_WAYLAND=1

# Required for Zsh smooth rendering
zmodload zsh/zle
zmodload zsh/complist

# Syntax highlighting speed boost
ZSH_HIGHLIGHT_HIGHLIGHTERS=(main brackets pattern)

# Atuin for instant fuzzy history
if command -v atuin >/dev/null; then
  eval "$(atuin init zsh)"
fi

# ---------------------------------------------
# FIXED: Correct plugin paths for NixOS
# ---------------------------------------------

# Autosuggestions
if [ -f /run/current-system/sw/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh ]; then
  source /run/current-system/sw/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh
fi

# Syntax highlighting (must ALWAYS be last)
if [ -f /run/current-system/sw/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ]; then
  source /run/current-system/sw/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
fi

# PATH additions
export PATH="$HOME/.spicetify:$PATH"
export PATH="$HOME/go/bin:$PATH"

# Steam fix for Wayland
export STEAM_FORCE_X11=1
