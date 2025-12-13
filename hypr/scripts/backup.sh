#!/usr/bin/env bash
set -euo pipefail

echo "==> Backup + Push dotfiles (clean rewrite)"

# -------------------------
# CONFIG
# -------------------------

SRC_HOME_DOTFILES="$HOME/dotfiles"
SRC_ZSHRC="$HOME/.zshrc"
SRC_NIXOS="/etc/nixos"

REPO_DIR="$HOME/github/dotfiles"
REPO_URL="git@github.com:danielhaggeman/nixos.git"

# -------------------------
# PREPARE REPO DIR
# -------------------------

echo "-> Preparing repo directory"
mkdir -p "$REPO_DIR"
rm -rf "$REPO_DIR"/*

# -------------------------
# COPY ~/dotfiles
# -------------------------

if [ -d "$SRC_HOME_DOTFILES" ]; then
  echo "-> Copying ~/dotfiles"
  rsync -aL \
    --exclude ".git" \
    "$SRC_HOME_DOTFILES/" "$REPO_DIR/"
fi

# -------------------------
# COPY .zshrc
# -------------------------

if [ -f "$SRC_ZSHRC" ]; then
  echo "-> Copying .zshrc"
  cp -f "$SRC_ZSHRC" "$REPO_DIR/.zshrc"
fi

# -------------------------
# COPY /etc/nixos (NO SYMLINKS)
# -------------------------

echo "-> Copying /etc/nixos (dereferencing symlinks)"
mkdir -p "$REPO_DIR/nixos"

rsync -aL \
  --exclude "hardware-configuration.nix" \
  "$SRC_NIXOS/" "$REPO_DIR/nixos/"

# -------------------------
# ENSURE .gitignore
# -------------------------

echo "-> Writing .gitignore"
cat <<EOF > "$REPO_DIR/.gitignore"
# Hardware specific
nixos/hardware-configuration.nix

# Secrets
.ssh/
.gnupg/
.env
*.key
*.pem

# Nix artifacts
result
*.drv
*.qcow2
EOF

# -------------------------
# GIT SETUP
# -------------------------

cd "$REPO_DIR"

if [ ! -d ".git" ]; then
  echo "-> Initializing git repo"
  git init
  git remote add origin "$REPO_URL"
else
  git remote set-url origin "$REPO_URL"
fi

# -------------------------
# SAFETY: NO SYMLINKS
# -------------------------

if find . -type l | grep -q .; then
  echo "ERROR: Symlinks detected in repo. Aborting."
  find . -type l
  exit 1
fi

# -------------------------
# COMMIT + PUSH
# -------------------------

git add -A

if git diff --cached --quiet; then
  echo "-> No changes to commit"
else
  git commit -m "Update dotfiles (user + nixos, portable)"
fi

git branch -M main
git push -u origin main

echo "==> Done"
echo "    Repo path : ~/github/dotfiles"
echo "    Repo root : dotfiles"
echo "    Symlinks  : none"
