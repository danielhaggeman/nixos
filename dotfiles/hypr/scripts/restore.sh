#!/usr/bin/env bash
set -euo pipefail


echo "==> Restore (everything from github to original locations)"

# -------------------------
# CONFIG
# -------------------------

REPO_ROOT="$HOME/github/dotfiles"
DOTFILES_DIR="$REPO_ROOT/dotfiles"

DEST_HOME_DOTFILES="$HOME/dotfiles"
DEST_ZSHRC="$HOME/.zshrc"
DEST_NIXOS="/etc/nixos"

# -------------------------
# VALIDATE REPO
# -------------------------

if [ ! -d "$DOTFILES_DIR" ]; then
  echo "ERROR: Dotfiles directory not found at $DOTFILES_DIR"
  echo "Make sure you have run backup.sh first or cloned the repo"
  exit 1
fi

echo "-> Found dotfiles at $DOTFILES_DIR"

# -------------------------
# RESTORE ~/dotfiles
# -------------------------

echo "-> Restoring ~/dotfiles"
mkdir -p "$DEST_HOME_DOTFILES"
rsync -a \
  --exclude ".git" \
  --exclude ".zshrc" \
  "$DOTFILES_DIR/" "$DEST_HOME_DOTFILES/"

# -------------------------
# RESTORE .zshrc
# -------------------------

if [ -f "$DOTFILES_DIR/.zshrc" ]; then
  echo "-> Restoring .zshrc"
  cp -f "$DOTFILES_DIR/.zshrc" "$DEST_ZSHRC"
else
  echo "-> .zshrc not found, skipping"
fi

# -------------------------
# RESTORE /etc/nixos
# -------------------------

if [ -d "$DOTFILES_DIR/nixos" ]; then
  echo "-> Restoring /etc/nixos"
  
  # Check if we have sudo access
  if ! sudo -n true 2>/dev/null; then
    echo "WARNING: sudo password required for /etc/nixos restore"
    sudo true
  fi
  
  # Create nixos dir if it doesn't exist
  sudo mkdir -p "$DEST_NIXOS"
  
  # Restore all nixos files except hardware-configuration.nix
  sudo rsync -a \
    --exclude "hardware-configuration.nix" \
    "$DOTFILES_DIR/nixos/" "$DEST_NIXOS/"
else
  echo "-> nixos directory not found, skipping"
fi

# -------------------------
# VERIFY RESTORE
# -------------------------

echo ""
echo "==> Restore Complete"
echo ""
echo "Restored locations:"
echo "  - ~/dotfiles       -> $DEST_HOME_DOTFILES"
echo "  - .zshrc           -> $DEST_ZSHRC"
echo "  - /etc/nixos       -> $DEST_NIXOS"
echo ""
echo "Note: hardware-configuration.nix was NOT restored (system-specific)"
echo ""
