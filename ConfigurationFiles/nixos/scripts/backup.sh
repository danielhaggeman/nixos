#!/run/current-system/sw/bin/bash
set -e

USER_NAME="daniel"
USER_HOME="/home/$USER_NAME"
REPO_DIR="$USER_HOME/nixos-backup"
TARGET_DIR="$REPO_DIR/ConfigurationFiles"

ROFI_DIR="$USER_HOME/.config/rofi"
HYPR_DIR="$USER_HOME/.config/hypr"
KITTY_DIR="$USER_HOME/.config/kitty"
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

    # Set origin
    sudo -u $USER_NAME git -C "$REPO_DIR" remote add origin "git@github.com:danielhaggeman/nixos.git"
fi

# ------------------------------------------------------------------------------
# Ensure branch tracks upstream (origin/main or origin/master)
# ------------------------------------------------------------------------------
if ! sudo -u $USER_NAME git -C "$REPO_DIR" rev-parse --abbrev-ref --symbolic-full-name @{u} >/dev/null 2>&1; then
    log "Setting upstream branch..."
    sudo -u $USER_NAME git -C "$REPO_DIR" branch -u origin/main 2>/dev/null || \
    sudo -u $USER_NAME git -C "$REPO_DIR" branch -u origin/master 2>/dev/null || \
    log "⚠️ Could not set upstream automatically. (Repo may be empty.)"
fi

# ------------------------------------------------------------------------------
# Update repository from GitHub (self-healing pull)
# ------------------------------------------------------------------------------
log "Updating from GitHub..."

# Try normal fast-forward pull
if ! sudo -u $USER_NAME git -C "$REPO_DIR" pull --ff-only; then
    log "⚠️ Fast-forward not possible — attempting rebase..."

    # Try rebase pull
    if ! sudo -u $USER_NAME git -C "$REPO_DIR" pull --rebase; then
        log "⚠️ Rebase failed — resetting to remote branch..."

        # Determine branch
        BRANCH=$(sudo -u $USER_NAME git -C "$REPO_DIR" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "main")

        # Force reset
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
# Sync configuration files
# ------------------------------------------------------------------------------
log "Syncing configuration files..."

sudo -u $USER_NAME rm -rf "$TARGET_DIR"
sudo -u $USER_NAME mkdir -p "$TARGET_DIR"

sudo -u $USER_NAME cp -r "$ROFI_DIR" "$TARGET_DIR/rofi"
sudo -u $USER_NAME cp -r "$HYPR_DIR" "$TARGET_DIR/hypr"
sudo -u $USER_NAME cp -r "$KITTY_DIR" "$TARGET_DIR/kitty"
sudo -u $USER_NAME cp -r "$NIX_DIR" "$TARGET_DIR/nixos"

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
