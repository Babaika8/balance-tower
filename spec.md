# Spec — balance-tower

## Product
Casual 2D physics balance-stacking game delivered as a Telegram web app
(Godot 4.6 → HTML5/wasm). The player drops objects onto a growing tower; real
2D physics make it lean and topple on misaligned placement (NOT Stack-style
slicing). Score = tower height, submitted to an online leaderboard.

## Core loop
1. An object is carried at the top; tap/click releases it.
2. It falls with physics and rests on the stack; misalignment tilts the tower.
3. Tower topples -> game over -> score submitted, top-10 shown.

## Skins / themes
One core engine, cosmetic skins via `skin` int (saved to `user://skin.dat`,
cycled by the top-right button):
- 0 — Zen meadow (warm-dawn parallax; day/dusk/night by tower height).
- 1 — Diner (interior; stones become pancakes on a plate).
Add a skin = bump SKIN_COUNT/SKIN_NAMES + add `_setup_X` and a `_stone_visual` branch.

## Leaderboard
Cloudflare Workers + D1 (`server/`). POST /api/score verifies Telegram WebApp
initData HMAC against the bot token; GET /api/leaderboard returns top 10.

## Platform / deploy
Godot 4.6 web export (thread_support=false) -> GitHub Pages (`gh-pages`) at
https://babaika8.github.io/balance-tower/ ; launched in Telegram via @BotFather
menu button -> the Pages URL.

## Monetization (planned)
Rewarded "continue" ad + interstitials + remove-ads IAP.

## Constraints
Responsive to any aspect ratio (backgrounds screen-anchored/centered per frame).
No secrets in the repo (bot token is a Cloudflare secret).
