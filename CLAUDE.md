# balance-tower

2D physics balance-stacking game (Godot 4.6) as a Telegram web app. Drop objects
onto a tower; misaligned placement makes it lean and topple (real physics, not
Stack-style slicing). One core engine, swappable skins.
See `spec.md` (product) and `wiki/index.md` (code map).

## Structure
- `main.tscn` + `game.gd` — the whole game, built in code.
- Skins via `skin` int (0 = Zen meadow, 1 = Diner), saved to `user://skin.dat`.
  New skin = bump SKIN_COUNT/SKIN_NAMES + add `_setup_X` + `_stone_visual` branch.
- `assets/zen/` — SVG art. `server/` — Cloudflare Worker leaderboard.

## Build & deploy (manual, no CI)
- Web build: `godot --headless --export-release "Web" build/web/index.html`
- Preview: run WITHOUT --headless, `BT_SHOT=hold` or `BT_SHOT=1` -> /tmp/bt_shot.png.
- Frontend: copy `build/web` to `gh-pages`, force-push. Backend: `wrangler deploy`.

## Art approach
Geometric shapes drawn directly; organic shapes (hands) extracted/transformed from
vector references, not freehand. SVG imports as crisp Texture2D, tiny.

## Secrets
NEVER commit secrets. Bot token is a Cloudflare Worker secret, never in repo.

## Публикация в Telegram (одна команда)
Godot установлен на сервере, поэтому сборку+деплой можно делать прямо там:
- `bash tools/deploy.sh` — собирает веб-экспорт и force-push в `gh-pages` →
  через ~1-2 мин обновляется https://babaika8.github.io/balance-tower/ (и в Telegram).
- `bash tools/deploy.sh --dry-run` — собрать и проверить без публикации.
Деплой меняет ЖИВОЙ сайт — публикуй только когда правка готова.
