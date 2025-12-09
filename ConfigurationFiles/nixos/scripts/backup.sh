#!/run/current-system/sw/bin/bash
set -e

USER_NAME="daniel"
USER_HOME="/home/$USER_NAME"
REPO_DIR="$USER_HOME/nixos-backup"
TARGET_DIR="$REPO_DIR/ConfigurationFiles"

ROFI_DIR="$USER_HOME/.config/rofi"
HYPR_DIR="$USER_HOME/.config/hypr"
KITTY_DIR="$USER_HOME/.config/kitty"
WAYBAR_DIR="$USER_HOME/.config/waybar"
YAZI_DIR="$USER_HOME/.config/yazi"
NIX_DIR="/etc/nixos"

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

    sudo -u $USER_NAME git -C "$REPO_DIR" init
    sudo -u $USER_NAME git -C "$REPO_DIR" remote add origin "git@github.com:danielhaggeman/nixos.git"
fi

# ------------------------------------------------------------------------------
# Ensure branch tracks upstream
# ------------------------------------------------------------------------------
if ! sudo -u $USER_NAME git -C "$REPO_DIR" rev-parse --abbrev-ref --symbolic-full-name @{u} >/dev/null 2>&1; then
    sudo -u $USER_NAME git -C "$REPO_DIR" branch -u origin/main 2>/dev/null || \
    sudo -u $USER_NAME git -C "$REPO_DIR" branch -u origin/master 2>/dev/null
fi

# ------------------------------------------------------------------------------
# Pull changes — with self-healing logic
# ------------------------------------------------------------------------------
log "Updating from GitHub..."

if ! sudo -u $USER_NAME git -C "$REPO_DIR" pull --ff-only; then
    log "Fast-forward failed — attempting rebase..."
    if ! sudo -u $USER_NAME git -C "$USER_HOME/nixos-backup" pull --rebase; then
        log "Rebase failed — hard resetting to remote branch..."

        BRANCH=$(sudo -u $USER_NAME git -C "$REPO_DIR" rev-parse --abbrev-ref HEAD || echo "main")

        sudo -u $USER_NAME git -C "$REPO_DIR" fetch origin
        sudo -u $USER_NAME git -C "$REPO_DIR" reset --hard "origin/$BRANCH"
    fi
fi

# ------------------------------------------------------------------------------
# Sync configuration files (rsync → no symlinks, no .git copies)
# ------------------------------------------------------------------------------
log "Syncing configuration files..."

sudo -u $USER_NAME mkdir -p "$TARGET_DIR"

RSYNC="rsync -av --delete --exclude='.git' --exclude='.gitmodules' --exclude='.cache'"

$RSYNC "$ROFI_DIR/"      "$TARGET_DIR/rofi/"
$RSYNC "$HYPR_DIR/"      "$TARGET_DIR/hypr/"
$RSYNC "$KITTY_DIR/"     "$TARGET_DIR/kitty/"
$RSYNC "$WAYBAR_DIR/"    "$TARGET_DIR/waybar/"
$RSYNC "$NIX_DIR/"       "$TARGET_DIR/nixos/"

# NEW: Yazi backup
$RSYNC "$YAZI_DIR/"      "$TARGET_DIR/yazi/"

# NEW: .zshrc backup
if [ -f "$USER_HOME/.zshrc" ]; then
    sudo -u $USER_NAME mkdir -p "$TARGET_DIR/zsh"
    sudo -u $USER_NAME cp "$USER_HOME/.zshrc" "$TARGET_DIR/zsh/.zshrc"
fi

log "✔ Synced configuration files"

# ------------------------------------------------------------------------------
# Commit only if real changes exist
# ------------------------------------------------------------------------------
log "Checking for changes..."
sudo -u $USER_NAME git -C "$REPO_DIR" add -A

if sudo -u $USER_NAME git -C "$REPO_DIR" diff --cached --quiet; then
    log "No changes detected — nothing to commit."
else
    sudo -u $USER_NAME git -C "$REPO_DIR" commit -m "Backup $(date '+%Y-%m-%d %H:%M:%S')"
fi

# ------------------------------------------------------------------------------
# Push
# ------------------------------------------------------------------------------
log "Pushing to GitHub..."
sudo -u $USER_NAME git -C "$REPO_DIR" push origin main || \
sudo -u $USER_NAME git -C "$REPO_DIR" push origin master

log "🎉 Backup completed successfully."
