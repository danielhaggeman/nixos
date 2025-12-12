#!/run/current-system/sw/bin/bash
set -e

USER_NAME="daniel"
USER_HOME="/home/$USER_NAME"

REPO_DIR="$USER_HOME/nixos-backup"
TARGET_DIR="$REPO_DIR/ConfigurationFiles"

DOTFILES_DIR="$USER_HOME/dotfiles"
ZSHRC_FILE="$USER_HOME/.zshrc"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# ------------------------------------------------------------------------------
# Ensure repo exists
# ------------------------------------------------------------------------------
if [ ! -d "$REPO_DIR/.git" ]; then
    log "Initializing repository..."
    mkdir -p "$REPO_DIR"
    chown -R "$USER_NAME:users" "$REPO_DIR"

    sudo -u "$USER_NAME" git -C "$REPO_DIR" init
    sudo -u "$USER_NAME" git -C "$REPO_DIR" remote add origin "git@github.com:danielhaggeman/nixos.git"
fi

# ------------------------------------------------------------------------------
# Ensure branch tracks upstream
# ------------------------------------------------------------------------------
if ! sudo -u "$USER_NAME" git -C "$REPO_DIR" rev-parse --abbrev-ref --symbolic-full-name @{u} >/dev/null 2>&1; then
    sudo -u "$USER_NAME" git -C "$REPO_DIR" branch -u origin/main 2>/dev/null || \
    sudo -u "$USER_NAME" git -C "$REPO_DIR" branch -u origin/master 2>/dev/null
fi

# ------------------------------------------------------------------------------
# Pull changes (self-healing)
# ------------------------------------------------------------------------------
log "Updating from GitHub..."

if ! sudo -u "$USER_NAME" git -C "$REPO_DIR" pull --ff-only; then
    log "Fast-forward failed — attempting rebase..."
    if ! sudo -u "$USER_NAME" git -C "$REPO_DIR" pull --rebase; then
        log "Rebase failed — hard resetting to remote branch..."

        BRANCH=$(sudo -u "$USER_NAME" git -C "$REPO_DIR" rev-parse --abbrev-ref HEAD || echo "main")

        sudo -u "$USER_NAME" git -C "$REPO_DIR" fetch origin
        sudo -u "$USER_NAME" git -C "$REPO_DIR" reset --hard "origin/$BRANCH"
    fi
fi

# ------------------------------------------------------------------------------
# Sync dotfiles + zshrc ONLY
# ------------------------------------------------------------------------------
log "Syncing dotfiles..."

sudo -u "$USER_NAME" mkdir -p "$TARGET_DIR"

RSYNC="rsync -av --delete --exclude='.git' --exclude='.cache'"

# dotfiles (entire directory)
$RSYNC "$DOTFILES_DIR/" "$TARGET_DIR/dotfiles/"

# .zshrc
if [ -f "$ZSHRC_FILE" ]; then
    sudo -u "$USER_NAME" mkdir -p "$TARGET_DIR/zsh"
    sudo -u "$USER_NAME" cp "$ZSHRC_FILE" "$TARGET_DIR/zsh/.zshrc"
fi

log "✔ Synced dotfiles and zshrc"

# ------------------------------------------------------------------------------
# Commit only if changes exist
# ------------------------------------------------------------------------------
log "Checking for changes..."
sudo -u "$USER_NAME" git -C "$REPO_DIR" add -A

if sudo -u "$USER_NAME" git -C "$REPO_DIR" diff --cached --quiet; then
    log "No changes detected — nothing to commit."
else
    sudo -u "$USER_NAME" git -C "$REPO_DIR" commit -m "Backup $(date '+%Y-%m-%d %H:%M:%S')"
fi

# ------------------------------------------------------------------------------
# Push
# ------------------------------------------------------------------------------
log "Pushing to GitHub..."
sudo -u "$USER_NAME" git -C "$REPO_DIR" push origin main || \
sudo -u "$USER_NAME" git -C "$REPO_DIR" push origin master

log "🎉 Backup completed successfully."
