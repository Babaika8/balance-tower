# Zen Skin Assets

Optional art overrides for the Zen location.

The physics box is still about 180 x 56 in game units. Falling-object PNGs
should be wide, horizontal, transparent sprites.

Supported files:

- `background.png` or `background_gpt_v1.png` — full vertical background.
- `stone.png`, `stone2.png`, `stone3.png`, `stone4.png` — falling stones.
- `hand.png` — carrier above the stone.
- `pedestal.png` — base under the first stone.

If a file is missing, the game falls back to the older `assets/zen` art or the
code-drawn object.
