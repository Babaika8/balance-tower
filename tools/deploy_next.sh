#!/usr/bin/env bash
# Publish the standalone WebGL prototype beside the current Godot build.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ORIGIN="${DEPLOY_ORIGIN:-$(git -C "$REPO" remote get-url origin)}"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

git clone -q --depth 1 --branch gh-pages "$ORIGIN" "$TMP/site"
rm -rf "$TMP/site/next"
mkdir -p "$TMP/site/next"
cp -a "$REPO/web-next/." "$TMP/site/next/"
touch "$TMP/site/.nojekyll"

git -C "$TMP/site" add -A
git -C "$TMP/site" -c user.name="ILYA SCHERBAKOV" -c user.email="sir.fatlo@gmail.com" \
  commit -q -m "deploy WebGL prototype $(date -u +%FT%TZ)"
git -C "$TMP/site" push origin gh-pages
echo "deployed -> https://babaika8.github.io/balance-tower/next/"
