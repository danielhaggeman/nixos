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
DOTFILES_DIR="$REPO_ROOT/dotfiles"

REPO_URL="git@github.com:danielhaggeman/nixos.git"

# -------------------------
# PREPARE REPO
# -------------------------

echo "-> Preparing repo"
mkdir -p "$DOTFILES_DIR"
rm -rf "$REPO_ROOT"/*

# -------------------------
# COPY ~/dotfiles
# -------------------------

echo "-> Copying ~/dotfiles"
rsync -a \
  --exclude ".git" \
  "$SRC_HOME_DOTFILES/" "$DOTFILES_DIR/"

# -------------------------
# COPY .zshrc
# -------------------------

echo "-> Copying .zshrc"
cp -f "$SRC_ZSHRC" "$DOTFILES_DIR/.zshrc"

# -------------------------
# COPY /etc/nixos (NO SYMLINKS)
# -------------------------

echo "-> Copying /etc/nixos (flatten symlinks, skip broken)"
mkdir -p "$DOTFILES_DIR/nixos"

rsync -aL \
  --exclude "hardware-configuration.nix" \
  --exclude "scripts" \
  "$SRC_NIXOS/" "$DOTFILES_DIR/nixos/"

# -------------------------
# COPY nixos/scripts SAFELY
# -------------------------

SCRIPTS_TARGET=$(readlink -f "$SRC_NIXOS/scripts" 2>/dev/null) || true
if [ -n "$SCRIPTS_TARGET" ] && [ -d "$SCRIPTS_TARGET" ]; then
  echo "-> Copying nixos/scripts (resolved symlink)"
  mkdir -p "$DOTFILES_DIR/nixos/scripts"
  rsync -a "$SCRIPTS_TARGET/" "$DOTFILES_DIR/nixos/scripts/"
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

if find . -type l 2>/dev/null | grep -q .; then
  echo "ERROR: Symlinks detected (this should never happen)"
  find . -type l
  exit 1
fi

# -------------------------
# COMMIT + PUSH
# -------------------------

cd "$REPO_ROOT"

git add -A

if git diff --cached --quiet; then
  echo "-> No changes to commit"
else
  TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
  git commit --no-edit -m "backup $TIMESTAMP"
fi

git branch -M main
git push -u origin main --force

echo "==> DONE"
