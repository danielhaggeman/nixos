#!/usr/bin/env bash
set -euo pipefail

echo "==> Backup + Push to ~/github/dotfiles"

# SOURCES
SRC_DOTFILES="$HOME/dotfiles"
SRC_ZSH="$HOME/.zshrc"
SRC_NIXOS="/etc/nixos"

# DESTINATION (repo root)
DST="$HOME/github/dotfiles"

REPO_URL="https://github.com/danielhaggeman/nixos.git"

# -------------------------
# 1. PREPARE DESTINATION
# -------------------------

mkdir -p "$DST"
rm -rf "$DST"/*

# -------------------------
# 2. COPY USER DOTFILES
# -------------------------

if [ -d "$SRC_DOTFILES" ]; then
  echo "-> Copying ~/dotfiles"
  rsync -a \
    --exclude ".git" \
    "$SRC_DOTFILES/" "$DST/"
fi

# -------------------------
# 3. COPY .zshrc
# -------------------------

echo "-> Copying .zshrc"
cp -f "$SRC_ZSH" "$DST/.zshrc"

# -------------------------
# 4. COPY NIXOS CONFIG
# -------------------------

echo "-> Copying NixOS config (excluding hardware-configuration.nix)"
mkdir -p "$DST/nixos"
rsync -a \
  --exclude "hardware-configuration.nix" \
  "$SRC_NIXOS/" "$DST/nixos/"

# -------------------------
# 5. GITIGNORE SAFETY NET
# -------------------------

cat <<EOF > "$DST/.gitignore"
# NixOS hardware-specific
nixos/hardware-configuration.nix

# Nix build artifacts
result
*.drv
*.qcow2
EOF

# -------------------------
# 6. GIT COMMIT + PUSH
# -------------------------

cd "$DST"

if [ ! -d ".git" ]; then
  echo "-> Initializing git repo"
  git init
  git remote add origin "$REPO_URL"
fi

git add -A

if git diff --cached --quiet; then
  echo "-> No changes to commit"
else
  git commit -m "Update dotfiles (user + nixos, no hardware config)"
fi

git branch -M main
git push -u origin main

echo "==> Done"
echo "    Repo root : ~/github/dotfiles"
echo "    GitHub    : dotfiles as root"
