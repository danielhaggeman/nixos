#!/usr/bin/env bash
set -euo pipefail

echo "==> Backup + Push (everything UNDER dotfiles/)"

# -------------------------
# CONFIG
# -------------------------

SRC_HOME_DOTFILES="$HOME/dotfiles"
SRC_ZSHRC="$HOME/.zshrc"
SRC_NIXOS="/etc/nixos"

REPO_ROOT="$HOME/github/dotfiles"
DOTFILES_ROOT="$REPO_ROOT/dotfiles"

REPO_URL="git@github.com:danielhaggeman/nixos.git"

# -------------------------
# PREPARE REPO
# -------------------------

echo "-> Preparing repo"
mkdir -p "$DOTFILES_ROOT"
rm -rf "$DOTFILES_ROOT"/*

# -------------------------
# COPY ~/dotfiles
# -------------------------

echo "-> Copying ~/dotfiles"
rsync -a \
  --exclude ".git" \
  "$SRC_HOME_DOTFILES/" "$DOTFILES_ROOT/"

# -------------------------
# COPY .zshrc
# -------------------------

echo "-> Copying .zshrc"
cp -f "$SRC_ZSHRC" "$DOTFILES_ROOT/.zshrc"

# -------------------------
# COPY /etc/nixos (NO SYMLINKS)
# -------------------------

echo "-> Copying /etc/nixos (flatten symlinks, skip broken)"
mkdir -p "$DOTFILES_ROOT/nixos"

rsync -aL \
  --exclude "hardware-configuration.nix" \
  --exclude "scripts" \
  "$SRC_NIXOS/" "$DOTFILES_ROOT/nixos/"

# -------------------------
# COPY nixos/scripts SAFELY
# -------------------------

if [ -L "$SRC_NIXOS/scripts" ] && [ -d "$(readlink -f "$SRC_NIXOS/scripts" 2>/dev/null)" ]; then
  echo "-> Copying nixos/scripts (resolved symlink)"
  mkdir -p "$DOTFILES_ROOT/nixos/scripts"
  rsync -a \
    "$(readlink -f "$SRC_NIXOS/scripts")/" \
    "$DOTFILES_ROOT/nixos/scripts/"
else
  echo "-> nixos/scripts is broken or missing, skipping"
fi

# -------------------------
# .gitignore
# -------------------------

cat <<EOF > "$REPO_ROOT/.gitignore"
dotfiles/nixos/hardware-configuration.nix

result
*.drv
*.qcow2

.ssh/
.gnupg/
.env
EOF

# -------------------------
# GIT SETUP
# -------------------------

cd "$REPO_ROOT"

if [ ! -d ".git" ]; then
  git init
  git remote add origin "$REPO_URL"
else
  git remote set-url origin "$REPO_URL"
fi

# -------------------------
# HARD SYMLINK GUARD
# -------------------------

if find dotfiles -type l | grep -q .; then
  echo "ERROR: Symlinks detected under dotfiles/ (this should never happen)"
  find dotfiles -type l
  exit 1
fi

# -------------------------
# COMMIT + PUSH
# -------------------------

git add -A

if git diff --cached --quiet; then
  echo "-> No changes to commit"
else
  git commit -m "Update dotfiles (everything under dotfiles/, no symlinks)"
fi

git branch -M main
git push -u origin main

echo "==> DONE"
