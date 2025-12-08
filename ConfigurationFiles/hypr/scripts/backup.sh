#!/usr/bin/env bash

# Run all git operations as real user "daniel"
USER_NAME="daniel"
USER_HOME="/home/$USER_NAME"
REPO_DIR="$USER_HOME/nixos-backup"
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
    chown -R $USER_NAME:$USER_NAME "$REPO_DIR"

    sudo -u $USER_NAME git -C "$REPO_DIR" init
    sudo -u $USER_NAME git -C "$REPO_DIR" remote add origin "git@github.com:danielhaggeman/nixos.git"
fi

# Sync files into repo
log "Syncing configuration files..."

sudo -u $USER_NAME rm -rf "$REPO_DIR/rofi"
sudo -u $USER_NAME rm -rf "$REPO_DIR/hypr"
sudo -u $USER_NAME rm -rf "$REPO_DIR/nixos"

sudo -u $USER_NAME mkdir -p "$REPO_DIR"

sudo -u $USER_NAME cp -r "$ROFI_DIR" "$REPO_DIR/rofi"
sudo -u $USER_NAME cp -r "$HYPR_DIR" "$REPO_DIR/hypr"
sudo -u $USER_NAME cp -r "$NIX_DIR" "$REPO_DIR/nixos"

# Check for changes
log "Checking for changes..."
if sudo -u $USER_NAME git -C "$REPO_DIR" diff --quiet; then
    log "No changes detected — nothing to commit."
    exit 0
fi

# Commit & push
log "Committing changes..."
sudo -u $USER_NAME git -C "$REPO_DIR" add .
sudo -u $USER_NAME git -C "$REPO_DIR" commit -m "Automated hourly backup"

log "Pushing to GitHub..."
sudo -u $USER_NAME git -C "$REPO_DIR" push origin main || sudo -u $USER_NAME git -C "$REPO_DIR" push origin master

log "Backup completed successfully."
