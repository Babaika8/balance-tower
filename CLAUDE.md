# balance-tower

2D physics balance-stacking game (Godot 4.6) running as a Telegram web app.
Drop objects onto a tower; misaligned placement makes it lean and topple (real
physics, not Stack-style slicing). One core engine, swappable skins.

## Structure
- `main.tscn` + `game.gd` — the whole game, built in code.
- Skins via `skin` int (0 = Zen meadow, 1 = Diner), saved to `user://skin.dat`;
  top-right button cycles them. New skin = bump SKIN_COUNT/SKIN_NAMES + add
  `_setup_X` and a `_stone_visual` branch.
- `assets/` — flat vector / code-drawn art.
- `server/` — leaderboard backend: Cloudflare Workers + D1.
- `docs/` — design docs.

## Build & deploy (manual, no CI)
- Web build: `godot --headless --export-release "Web" build/web/index.html`
- Frontend: copy `build/web` to `gh-pages`, force-push →
  https://babaika8.github.io/balance-tower/
- Backend: `wrangler deploy` (Worker `balance-tower-api`).

## Art approach
Geometric shapes drawn directly; organic shapes (hands) extracted/transformed
from vector references, not freehand. SVG imports as crisp Texture2D, stays tiny.

## Secrets
NEVER commit secrets. `BOT_TOKEN` is a Cloudflare Worker secret, never in repo.
