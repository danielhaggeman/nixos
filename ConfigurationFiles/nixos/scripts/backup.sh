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

# Ensure upstream tracking
if ! sudo -u $USER_NAME git -C "$REPO_DIR" rev-parse --abbrev-ref --symbolic-full-name @{u} >/dev/null 2>&1; then
    sudo -u $USER_NAME git -C "$REPO_DIR" branch -u origin/main 2>/dev/null || \
    sudo -u $USER_NAME git -C "$REPO_DIR" branch -u origin/master 2>/dev/null
fi

# ------------------------------------------------------------------------------
# Self-healing pull
# ------------------------------------------------------------------------------
log "Updating from GitHub..."

if ! sudo -u $USER_NAME git -C "$REPO_DIR" pull --ff-only; then
    log "Fast-forward failed, attempting rebase..."
    if ! sudo -u $USER_NAME git -C "$REPO_DIR" pull --rebase; then
        log "Rebase failed, resetting to remote HEAD..."
        BRANCH=$(sudo -u $USER_NAME git -C "$REPO_DIR" rev-parse --abbrev-ref HEAD || echo "main")
        sudo -u $USER_NAME git -C "$REPO_DIR" fetch origin
        sudo -u $USER_NAME git -C "$REPO_DIR" reset --hard "origin/$BRANCH"
    fi
fi

# ------------------------------------------------------------------------------
# ALWAYS WRITE: sync files with overwrite + timestamp marker
# ------------------------------------------------------------------------------
log "Syncing configuration files..."

sudo -u $USER_NAME mkdir -p "$TARGET_DIR"

RSYNC="rsync -av --delete --exclude='.git' --exclude='.cache'"

$RSYNC "$ROFI_DIR/"   "$TARGET_DIR/rofi/"
$RSYNC "$HYPR_DIR/"   "$TARGET_DIR/hypr/"
$RSYNC "$KITTY_DIR/"  "$TARGET_DIR/kitty/"
$RSYNC "$WAYBAR_DIR/" "$TARGET_DIR/waybar/"
$RSYNC "$NIX_DIR/"    "$TARGET_DIR/nixos/"

# FORCE A CHANGE so git ALWAYS commits something
echo "$(date)" > "$TARGET_DIR/LAST_BACKUP_TIMESTAMP"

log "✔ Synced and timestamp updated"

# ------------------------------------------------------------------------------
# Always commit & push
# ------------------------------------------------------------------------------
log "Preparing commit..."

sudo -u $USER_NAME git -C "$REPO_DIR" add -A

sudo -u $USER_NAME git -C "$REPO_DIR" commit -m "Backup $(date '+%Y-%m-%d %H:%M:%S')" || \
log "No meaningful changes, but timestamp ensures push."

log "Pushing to GitHub..."
sudo -u $USER_NAME git -C "$REPO_DIR" push origin main || \
sudo -u $USER_NAME git -C "$REPO_DIR" push origin master

log "🎉 Backup completed successfully."
