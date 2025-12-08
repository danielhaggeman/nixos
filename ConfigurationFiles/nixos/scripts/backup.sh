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
# Ensure repository exists
# ------------------------------------------------------------------------------
if [ ! -d "$REPO_DIR/.git" ]; then
    log "Creating new repository at $REPO_DIR..."
    mkdir -p "$REPO_DIR"
    chown -R "$USER_NAME":"$(id -gn $USER_NAME)" "$REPO_DIR"
    sudo -u $USER_NAME git -C "$REPO_DIR" init

    sudo -u $USER_NAME git -C "$REPO_DIR" remote add origin "git@github.com:danielhaggeman/nixos.git"
fi

# ------------------------------------------------------------------------------
# Ensure branch tracks upstream
# ------------------------------------------------------------------------------
if ! sudo -u $USER_NAME git -C "$REPO_DIR" rev-parse --abbrev-ref --symbolic-full-name @{u} >/dev/null 2>&1; then
    log "Setting upstream branch..."
    sudo -u $USER_NAME git -C "$REPO_DIR" branch -u origin/main 2>/dev/null || \
    sudo -u $USER_NAME git -C "$REPO_DIR" branch -u origin/master 2>/dev/null || \
    log "⚠️ Could not set upstream automatically."
fi

# ------------------------------------------------------------------------------
# Update self-healing pull
# ------------------------------------------------------------------------------
log "Updating from GitHub..."

if ! sudo -u $USER_NAME git -C "$REPO_DIR" pull --ff-only; then
    log "⚠️ Fast-forward not possible — attempting rebase..."

    if ! sudo -u $USER_NAME git -C "$REPO_DIR" pull --rebase; then
        log "⚠️ Rebase failed — hard resetting repo..."

        BRANCH=$(sudo -u $USER_NAME git -C "$REPO_DIR" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "main")

        sudo -u $USER_NAME git -C "$REPO_DIR" fetch origin
        sudo -u $USER_NAME git -C "$REPO_DIR" reset --hard "origin/$BRANCH"

        log "✔ Repo reset to origin/$BRANCH"
    else
        log "✔ Rebase successful"
    fi
else
    log "✔ Fast-forward update successful"
fi

# ------------------------------------------------------------------------------
# Sync configuration files (rsync → no .git copied)
# ------------------------------------------------------------------------------
log "Syncing configuration files..."

sudo -u $USER_NAME rm -rf "$TARGET_DIR"
sudo -u $USER_NAME mkdir -p "$TARGET_DIR"

RSYNC="rsync -av --exclude='.git' --exclude='.cache' --delete"

$RSYNC "$ROFI_DIR/"   "$TARGET_DIR/rofi/"   >/dev/null
$RSYNC "$HYPR_DIR/"   "$TARGET_DIR/hypr/"   >/dev/null
$RSYNC "$KITTY_DIR/"  "$TARGET_DIR/kitty/"  >/dev/null
$RSYNC "$WAYBAR_DIR/" "$TARGET_DIR/waybar/" >/dev/null
$RSYNC "$NIX_DIR/"     "$TARGET_DIR/nixos/" >/dev/null

log "✔ Synced to $TARGET_DIR"

# ------------------------------------------------------------------------------
# Check for changes
# ------------------------------------------------------------------------------
log "Checking for changes..."
if sudo -u $USER_NAME git -C "$REPO_DIR" diff --quiet; then
    log "No changes detected — nothing to commit."
    exit 0
fi

# ------------------------------------------------------------------------------
# Commit & push
# ------------------------------------------------------------------------------
log "Committing changes..."
sudo -u $USER_NAME git -C "$REPO_DIR" add .
sudo -u $USER_NAME git -C "$REPO_DIR" commit -m "Automated backup $(date '+%Y-%m-%d %H:%M:%S')"

log "Pushing to GitHub..."

sudo -u $USER_NAME git -C "$REPO_DIR" push origin main || \
sudo -u $USER_NAME git -C "$REPO_DIR" push origin master

log "🎉 Backup completed successfully."
