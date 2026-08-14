# Zen layered background prototype

## Goal

Prove the production approach for a living Zen background without changing the
stacking physics. The prototype covers only the starting 720 x 1280 section.

## Architecture

- `zen_start_prototype.tscn` is an isolated visual scene.
- `zen_start_prototype.gd` owns the background animation.
- `assets/skins/zen/prototype/start_clean.png` is the static clean plate.
- `sakura_branch.png` and `waterfall.png` are independent alpha sprites.
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

## Current scope and limitations

- Only the starting section is complete. The world above it still needs
  separate garden, monastery, mountain, cloud, and sky sections.
- The generated sakura and waterfall need final art-direction approval before
  they become the style contract for the remaining sections.
- Stones and pedestal were deliberately left unchanged for this prototype.

## Verification

- Native Godot start screenshot completed without script errors.
- Seven-second 720 x 1280, 30 FPS movie recorded from Godot Movie Maker.
- Web export completed successfully for the Telegram build.
- Live GitHub Pages deployment completed successfully.
- Review files: `art_review/zen_start_layered_prototype.mp4` and `.gif`.

## Next checkpoint

Approve or reject the visual language and motion of the starting section. If
approved, replace the temporary branch and waterfall with final art and build
the second vertical world section using the same layer contract.
