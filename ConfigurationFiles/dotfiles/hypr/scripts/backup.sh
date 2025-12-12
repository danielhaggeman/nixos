#!/bin/bash
# ~/.config/hypr/scripts/backup.sh
# Auto backup selected configs to GitHub

# Define the source config folders
CONFIG_FOLDERS=(kitty spicetify wal hypr waybar wofi)

# Ensure dotfiles repo exists
cd ~/dotfiles || exit

# Copy the selected configs to the repo
mkdir -p .config
for folder in "${CONFIG_FOLDERS[@]}"; do
    cp -r ~/.config/"$folder" .config/ 2>/dev/null
done

# Copy .zshrc
cp ~/.zshrc . 2>/dev/null

# Only commit if there are changes
if ! git diff-index --quiet HEAD --; then
    git add .
    git commit -m "Auto-backup: $(date '+%Y-%m-%d %H:%M:%S')"
    git push origin main
fi

