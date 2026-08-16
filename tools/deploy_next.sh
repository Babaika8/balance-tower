#!/usr/bin/env bash
# Publish the standalone WebGL prototype beside the current Godot build.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ORIGIN="${DEPLOY_ORIGIN:-$(git -C "$REPO" remote get-url origin)}"
PUSH_ORIGIN="$ORIGIN"
if [[ "$PUSH_ORIGIN" =~ ^https://github.com/(.+)$ ]]; then
  PUSH_ORIGIN="git@github.com:${BASH_REMATCH[1]}"
fi
TMP="$(mktemp -d)"
cleanup() {
  git -C "$REPO" worktree remove --force "$TMP/site" >/dev/null 2>&1 || true
  rm -rf "$TMP"
}
trap cleanup EXIT

git -C "$REPO" fetch origin gh-pages
git -C "$REPO" worktree add --detach "$TMP/site" origin/gh-pages
rm -rf "$TMP/site/next"
mkdir -p "$TMP/site/next"
cp -a "$REPO/web-next/." "$TMP/site/next/"
touch "$TMP/site/.nojekyll"

git -C "$TMP/site" add -A
git -C "$TMP/site" -c user.name="ILYA SCHERBAKOV" -c user.email="sir.fatlo@gmail.com" \
  commit -q -m "deploy WebGL prototype $(date -u +%FT%TZ)"
git -C "$TMP/site" push "$PUSH_ORIGIN" HEAD:gh-pages
echo "deployed -> https://babaika8.github.io/balance-tower/next/"
