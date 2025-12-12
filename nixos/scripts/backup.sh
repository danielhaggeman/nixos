#!/run/current-system/sw/bin/bash
set -e

REPO_DIR="$HOME/dotfiles"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Sanity check
if [ ! -d "$REPO_DIR/.git" ]; then
    echo "ERROR: $REPO_DIR is not a git repository"
    exit 1
fi

cd "$REPO_DIR"

log "Staging changes..."
git add -A

if git diff --cached --quiet; then
    log "No changes to commit."
    exit 0
fi

git commit -m "Update $(date '+%Y-%m-%d %H:%M:%S')"

log "Pushing to GitHub..."
git push

log "✅ Dotfiles pushed safely."
