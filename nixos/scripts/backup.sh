#!/run/current-system/sw/bin/bash
set -e

# Run all git operations as real user "daniel"
USER_NAME="daniel"
USER_HOME="/home/$USER_NAME"
REPO_DIR="$USER_HOME/nixos-backup"
TARGET_DIR="$REPO_DIR/ConfigurationFiles"

ROFI_DIR="$USER_HOME/.config/rofi"
HYPR_DIR="$USER_HOME/.config/hypr"
NIX_DIR="/etc/nixos"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Ensure repo exists
if [ ! -d "$REPO_DIR/.git" ]; then
    log "Creating new repository at $REPO_DIR..."
    mkdir -p "$REPO_DIR"
    chown -R "$USER_NAME":"$(id -gn $USER_NAME)" "$REPO_DIR"
    sudo -u $USER_NAME git -C "$REPO_DIR" init
    sudo -u $USER_NAME git -C "$REPO_DIR" remote add origin "git@github.com:danielhaggeman/nixos.git"
else
    log "Updating from GitHub..."
    sudo -u $USER_NAME git -C "$REPO_DIR" pull --ff-only || \
        log "⚠️ No fast-forward possible — continuing anyway."
fi

# Sync files
log "Syncing configuration files..."

sudo -u $USER_NAME rm -rf "$TARGET_DIR"
sudo -u $USER_NAME mkdir -p "$TARGET_DIR"

sudo -u $USER_NAME cp -r "$ROFI_DIR" "$TARGET_DIR/rofi"
sudo -u $USER_NAME cp -r "$HYPR_DIR" "$TARGET_DIR/hypr"
sudo -u $USER_NAME cp -r "$NIX_DIR" "$TARGET_DIR/nixos"

log "✔ Synced to $TARGET_DIR"

# Check for changes
log "Checking for changes..."
if sudo -u $USER_NAME git -C "$REPO_DIR" diff --quiet; then
    log "No changes detected — nothing to commit."
    exit 0
fi

# Commit & push
log "Committing changes..."
sudo -u $USER_NAME git -C "$REPO_DIR" add .
sudo -u $USER_NAME git -C "$REPO_DIR" commit -m "Automated backup $(date '+%Y-%m-%d %H:%M:%S')"

log "Pushing to GitHub..."
sudo -u $USER_NAME git -C "$REPO_DIR" push origin main || \
sudo -u $USER_NAME git -C "$REPO_DIR" push origin master

log "🎉 Backup completed successfully."
