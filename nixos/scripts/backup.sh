#!/run/current-system/sw/bin/bash
set -e

REPO_DIR="$HOME/dotfiles"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# ------------------------------------------------------------------------------
# Sanity checks
# ------------------------------------------------------------------------------
if [ ! -d "$REPO_DIR/.git" ]; then
    echo "ERROR: $REPO_DIR is not a git repository"
    exit 1
fi

cd "$REPO_DIR"

# ------------------------------------------------------------------------------
# Update from remote (safe)
# ------------------------------------------------------------------------------
log "Pulling latest changes..."

git pull --rebase --autostash

# ------------------------------------------------------------------------------
# Commit if changes exist
# ------------------------------------------------------------------------------
log "Checking for changes..."

git add -A

if git diff --cached --quiet; then
    log "No changes detected — nothing to commit."
    exit 0
fi

git commit -m "Update $(date '+%Y-%m-%d %H:%M:%S')"

# ------------------------------------------------------------------------------
# Push
# ------------------------------------------------------------------------------
log "Pushing to GitHub..."
git push origin main || git push origin master

log "🎉 Dotfiles pushed successfully."
