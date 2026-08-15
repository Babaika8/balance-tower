# Zen layered background prototype

> Superseded on 2026-08-14 by `zen_diorama.tscn`. The files remain available
> for comparison and rollback.

## Four-plane parallax demonstration

The active `zen_diorama.gd` now uses four independent `Parallax2D` nodes:

- `FarWorld`: distant sky, mountains, and the upper cloud-temple section;
- `MidWorld`: cliffs, shrines, stairs, bridge, and river banks;
- `NearWorld`: the authored cherry-tree and terrace theatre-flat;
- `Atmosphere`: drifting petals.

The vertical story is complete across five authored chapters: garden valley,
cloud temples, high mountains, open sky, and evening zenith. The joins overlap
inside broad mist banks. At the maximum tested climb (`BT_CLIMB=5200`) authored
art still covers the full viewport.

Vertical scroll values are deliberately close together (`0.84`, `0.90`,
`0.96`, `0.88`). Horizontal platformer values such as `0.2` would prevent a
vertical narrative background from advancing with the climbing camera.

The far section transition uses 128 pixels of physical overlap. Story panels
do not repeat; only future seamless cloud or mist textures may use
`Parallax2D.repeat_size`.

## Goal

Prove the production approach for a living Zen background without changing the
stacking physics. The prototype now covers the start and monastery-gorge
sections of the vertical route.

## Architecture

- `zen_start_prototype.tscn` is an isolated visual scene.
- `zen_start_prototype.gd` owns the background animation.
- `assets/skins/zen/prototype/start_clean.png` is the static clean plate.
- `assets/skins/zen/prototype/gorge_clean.png` is the next 720 x 1280 plate.
- `sakura_branch.png` and `waterfall.png` are independent alpha sprites.
- `gorge_waterfall.png` is the animated water layer in the upper section.
- The scene stays in world coordinates and therefore moves naturally with the
  gameplay camera.
- The camera is rounded to integer pixels for this Zen prototype.

## Animation

- Sakura uses a subdivided `ArrayMesh`. Its root stays fixed while the free end
  bends during intermittent gusts.
- The waterfall keeps a fixed silhouette. A shader changes highlights inside
  the flow instead of moving the whole sprite rectangle.
- Mist is a low-opacity procedural band with slow horizontal noise drift.
- The clean plate never changes exposure or geometry.
- The gorge plate overlaps the start by 96 pixels and fades at its lower edge,
  hiding the boundary while the camera climbs.

## Current scope

- The full vertical camera route is covered through approximately 100 stones.
- Stones and shared stacking physics remain unchanged.
- The painted terrace supplies the visible base while the physical pedestal
  remains the collision surface.

## Verification

- Native Godot start screenshot completed without script errors.
- Seven-second 720 x 1280, 30 FPS movie recorded from Godot Movie Maker.
- Web export completed successfully for the Telegram build.
- Live GitHub Pages deployment completed successfully.
- Review files: `art_review/zen_start_layered_prototype.mp4` and `.gif`.

## Next checkpoint

Review the monastery-gorge section in the live camera climb. Continue with the
mountain and cloud sections after its composition and motion are approved.
