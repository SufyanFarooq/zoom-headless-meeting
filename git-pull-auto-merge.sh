#!/bin/bash

# Auto-merge git pull script
# Automatically resolves conflicts by preferring remote for compose file

set -e

COMPOSE_FILE="compose-50-bots.yaml"

echo "🔄 Auto-Merge Git Pull"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Check if we're in a git repository
if ! git rev-parse --git-dir > /dev/null 2>&1; then
    echo "❌ Not a git repository"
    exit 1
fi

# Check current branch
CURRENT_BRANCH=$(git branch --show-current)
echo "📍 Current branch: $CURRENT_BRANCH"
echo ""

# Check if there are local changes
if git diff --quiet && git diff --cached --quiet; then
    echo "✅ No local changes, pulling directly..."
    git pull origin "$CURRENT_BRANCH"
    echo ""
    echo "✅ Pull completed successfully!"
    exit 0
fi

echo "⚠️  Local changes detected"
echo ""

# Strategy: For compose file, prefer remote version
# For other files, try to merge

# Stash only compose file if it has changes
if git diff --quiet "$COMPOSE_FILE" 2>/dev/null && git diff --cached --quiet "$COMPOSE_FILE" 2>/dev/null; then
    echo "✅ $COMPOSE_FILE has no local changes"
    # Pull normally
    git pull origin "$CURRENT_BRANCH" || {
        echo "⚠️  Merge conflict in other files"
        echo "   Resolve manually and commit"
        exit 1
    }
else
    echo "📝 $COMPOSE_FILE has local changes"
    echo "   Strategy: Prefer remote version (will be regenerated)"
    echo ""
    
    # Stash compose file changes
    git stash push -m "Auto-stash compose file $(date +%Y%m%d_%H%M%S)" -- "$COMPOSE_FILE" 2>/dev/null || {
        # If stash fails, commit it temporarily
        echo "   Stashing failed, committing temporarily..."
        git add "$COMPOSE_FILE"
        git commit -m "temp: local compose changes before pull" || true
    }
    
    # Pull
    echo "📥 Pulling latest changes..."
    git pull origin "$CURRENT_BRANCH" || {
        echo "⚠️  Pull failed"
        echo "   Restoring compose file..."
        git stash pop 2>/dev/null || true
        exit 1
    }
    
    # Drop the stash (we prefer remote version)
    git stash drop 2>/dev/null || true
    
    echo "✅ Using remote version of $COMPOSE_FILE"
    echo "   (ZAK tokens will be regenerated if needed)"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Pull completed successfully!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

