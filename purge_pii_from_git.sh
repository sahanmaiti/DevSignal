#!/bin/bash
# purge_pii_from_git.sh
#
# PURPOSE:
#   Removes .hunter_cache.json from the entire git history.
#   This file contains real names, emails, and LinkedIn profiles — PII.
#
# WHAT THIS DOES:
#   Uses git filter-branch to rewrite every commit that ever touched
#   .hunter_cache.json, as if the file never existed. The file itself
#   stays on disk (so Hunter.io caching still works locally), but it
#   will no longer exist in any commit, branch, or tag.
#
# RUN FROM: your project root (where .git/ lives)
# REQUIRES: git 2.x
#
# ⚠️  WARNING: this rewrites git history.
#   - Anyone with a clone will need to re-clone or hard reset.
#   - If you have GitHub/GitLab remote, force-push after this script.
#   - Coordinate with any collaborators BEFORE running.

set -e

echo "=== DevSignal: PII Purge Script ==="
echo ""

# 1. Verify we're in a git repo
if [ ! -d ".git" ]; then
  echo "ERROR: Run this from your project root (where .git/ lives)."
  exit 1
fi

# 2. Make sure the file is already in .gitignore before rewriting history.
#    If it's not, git would re-add it on the next commit.
if ! grep -q "\.hunter_cache\.json" .gitignore 2>/dev/null; then
  echo "Adding .hunter_cache.json to .gitignore first..."
  echo ".hunter_cache.json" >> .gitignore
  git add .gitignore
  git commit -m "chore: ignore hunter cache (contains PII)" || true
fi

echo "Rewriting git history to remove .hunter_cache.json..."
echo "This may take a minute on large repos."
echo ""

# 3. Rewrite history using git filter-branch
#    --force:           allow re-running if you've done this before
#    --index-filter:    faster than --tree-filter (doesn't check out files)
#    --prune-empty:     drop commits that become empty after the file removal
#    --tag-name-filter: rewrite tags to point to the new commits
#    -- --all:          process every branch and tag
git filter-branch \
  --force \
  --index-filter 'git rm --cached --ignore-unmatch .hunter_cache.json' \
  --prune-empty \
  --tag-name-filter cat \
  -- --all

echo ""
echo "✓ History rewritten."

# 4. Remove the old refs that filter-branch leaves behind
echo "Cleaning up leftover refs..."
git for-each-ref --format="%(refname)" refs/original/ | \
  xargs -r git update-ref -d

# 5. Expire the reflog and garbage collect so the data is truly gone
echo "Expiring reflogs and running GC..."
git reflog expire --expire=now --all
git gc --prune=now --aggressive

echo ""
echo "=== Done locally. ==="
echo ""
echo "NEXT STEPS:"
echo ""
echo "  1. Force-push to your remote (replaces the rewritten history):"
echo "     git push origin --force --all"
echo "     git push origin --force --tags"
echo ""
echo "  2. If using GitHub, you may also need to contact GitHub Support"
echo "     to purge the file from their server-side caches."
echo ""
echo "  3. Rotate any credentials that were near the PII in commits:"
echo "     - Hunter.io API key (HUNTER_API_KEY)"
echo "     - Serper API key (SERPER_API_KEY)"
echo ""
echo "  4. Anyone with an existing clone must re-clone:"
echo "     git clone <repo-url>"
echo "     (or: git fetch origin && git reset --hard origin/main)"
