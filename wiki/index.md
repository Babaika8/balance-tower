# Wiki — balance-tower

Everything is built in code; one scene.

## Layout
- `game.gd` (~2050 lines) — the entire game: physics, stacking, input, scoring,
  skins, backgrounds/atmosphere, leaderboard client.
- `main.tscn`, `project.godot`, `export_presets.cfg` — scene + Godot/web export.
- `assets/zen/` — SVG art (far/mid/near backgrounds, scene, stones, hand, petal,
  smoke). `assets/font/Comfortaa.ttf`.
- `tools/gen_art.py` — art helper.
- `server/` — leaderboard backend (Cloudflare Worker `src/index.js`,
  `wrangler.toml`, `schema.sql`).
- `docs/superpowers/specs/2026-06-14-balance-tower-design.md` — original design.

## Key systems (in game.gd)
- Skins: `skin` int, `SKIN_NAMES`/`SKIN_COUNT`, `_setup_background()` + `_stone_visual()`
  branch per skin (`_make_pancake` for Diner).
- Zen atmosphere: `_setup_background()` + `_update_atmosphere()` — layered parallax,
  sun->moon + stars cycling by score.
- Diner: `_setup_diner()` + `_update_diner()` — screen-anchored interior.
- Leaderboard client via JavaScriptBridge; head_include in export_presets.cfg.

## Build & deploy
- Web build: `godot --headless --export-release "Web" build/web/index.html`
- Preview (run WITHOUT --headless, else blank): `BT_SHOT=hold` or `BT_SHOT=1`
  -> /tmp/bt_shot.png ; `BT_SKIN` overrides skin.
- Frontend: copy `build/web` to `gh-pages`, force-push (GitHub Pages).
- Backend: `wrangler deploy` in `server/`.

## Live
https://babaika8.github.io/balance-tower/
