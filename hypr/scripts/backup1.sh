#!/bin/bash
# ~/.config/hypr/scripts/backup.sh
# Auto backup selected configs to GitHub safely (sync + push)

# Define the source config folders
CONFIG_FOLDERS=(kitty spicetify wal hypr waybar wofi)

# Ensure dotfiles repo exists
cd ~/dotfiles || { echo "❌ dotfiles repo not found in ~/dotfiles"; exit 1; }

# Copy the selected configs to the repo
mkdir -p .config
for folder in "${CONFIG_FOLDERS[@]}"; do
    cp -r ~/.config/"$folder" .config/ 2>/dev/null
done

# Copy .zshrc
cp ~/.zshrc . 2>/dev/null

# Sync with remote before committing
git fetch origin main
git rebase origin/main || {
    echo "⚠️ Rebase failed, attempting merge..."
    git merge --strategy-option ours origin/main || exit 1
}

# Only commit if there are changes
if ! git diff-index --quiet HEAD --; then
    git add .
    git commit -m "Auto-backup: $(date '+%Y-%m-%d %H:%M:%S')"
    git push origin main
else
    echo "✅ No changes to commit."
fi
