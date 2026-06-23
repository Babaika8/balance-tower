#!/usr/bin/env bash
# Сборка Godot Web-экспорта и публикация на ветку gh-pages (живой сайт).
# Запуск:  bash tools/deploy.sh            — собрать и задеплоить
#          bash tools/deploy.sh --dry-run  — собрать и проверить пуш без изменений
set -euo pipefail
DRY="${1:-}"
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO"

echo ">>> [1/2] сборка веб-экспорта (Godot headless)..."
rm -rf build/web && mkdir -p build/web
godot --headless --import >/dev/null 2>&1 || true
godot --headless --export-release "Web" build/web/index.html
touch build/web/.nojekyll
echo "    билд готов ($(du -sh build/web | cut -f1))"

echo ">>> [2/2] публикация в gh-pages..."
ORIGIN="$(git remote get-url origin)"
TMP="$(mktemp -d)"
cp -a build/web/. "$TMP"/
cd "$TMP"
git init -q
git checkout -q -b gh-pages
git add -A
git -c user.name="ILYA SCHERBAKOV" -c user.email="sir.fatlo@gmail.com" commit -q -m "deploy $(date -u +%FT%TZ)"
if [ "$DRY" = "--dry-run" ]; then
  git push --dry-run -f "$ORIGIN" gh-pages:gh-pages
  echo "    (dry-run) пуш проверен, ничего не изменено"
else
  git push -f "$ORIGIN" gh-pages:gh-pages
  echo "    задеплоено -> https://babaika8.github.io/balance-tower/"
fi
cd "$REPO"; rm -rf "$TMP"
