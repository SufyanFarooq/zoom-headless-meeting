#!/bin/bash

# Safe git pull script that handles local changes automatically
# Handles merge conflicts by preferring remote changes for compose file

set -e

COMPOSE_FILE="compose-50-bots.yaml"

echo "🔄 Safe Git Pull Script"
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

# Show what files have changes
echo "📋 Changed files:"
git status --short
echo ""

# Strategy: Stash local changes, pull, then reapply
echo "💾 Stashing local changes..."
git stash push -m "Auto-stash before pull $(date +%Y%m%d_%H%M%S)"

echo "📥 Pulling latest changes..."
git pull origin "$CURRENT_BRANCH"

echo "🔄 Reapplying local changes..."
if git stash list | head -1 | grep -q "Auto-stash"; then
    # Try to apply stash
    if git stash pop; then
        echo "✅ Local changes reapplied successfully!"
    else
        echo "⚠️  Merge conflicts detected when reapplying changes"
        echo ""
        echo "📋 Conflict files:"
        git status --short | grep "^UU\|^AA\|^DD"
        echo ""
        echo "💡 Options:"
        echo "   1. Resolve conflicts manually"
        echo "   2. Keep remote version: git checkout --theirs $COMPOSE_FILE && git add $COMPOSE_FILE"
        echo "   3. Keep local version: git checkout --ours $COMPOSE_FILE && git add $COMPOSE_FILE"
        echo ""
        echo "   After resolving, run: git stash drop"
        exit 1
    fi
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Pull completed successfully!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

