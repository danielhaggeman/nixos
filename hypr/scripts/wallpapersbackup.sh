#!/bin/bash
# ~/.config/hypr/scripts/backup_wallpapers.sh
# Auto backup wallpapers to GitHub

set -e  # Stop if any command fails

# Ensure wallpapers repo exists
cd ~/wallpapers-repo || exit

# Force correct SSH remote (in case it's still HTTPS)
git remote set-url origin git@github.com:danielhaggeman/wallpapers.git

# Copy wallpapers from Pictures
mkdir -p wallpapers
cp -r ~/Pictures/wallpapers/* wallpapers/ 2>/dev/null || true

# Sync repo with GitHub
git fetch origin main || true
git rebase origin/main || true

# Commit only if there are changes
if ! git diff-index --quiet HEAD --; then
    git add .
    git commit -m "Auto-backup wallpapers: $(date '+%Y-%m-%d %H:%M:%S')"
    git push origin main
    echo "✅ Wallpapers backup completed and pushed."
else
    echo "🟡 No new wallpapers to back up."
fi
