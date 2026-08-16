# Log — balance-tower

## 2026-08-16 — Blender 2.5D technical prototype

- Installed Blender 5.2.0 and created a reproducible Zen diorama script under
  `tools/blender/zen_diorama_prototype.py`.
- Rendered an eight-second 360 x 640, 30 FPS object-animation test.
- Confirmed that branches, blossoms, lantern, water, clouds, petals, and camera
  can move as connected scene objects rather than image overlays.
- Visual review found the procedural geometry too crude for production quality.
- Kept the result out of the active game and did not deploy it.

## 2026-08-16 — Restored key-point project journal

- Added `PROJECT_JOURNAL.md` in the format originally required by the user:
  agreed goal, implementation method, observed result, user verdict, and
  consequence for every major checkpoint.
- Reconstructed the visual project history from the repository and conversation
  outcomes instead of recording only commit-level changes.
- Marked the repeated "use Spine" recommendation as an error, not a new result.
- Recorded 2.5D Blender diorama production as a new direction under analysis,
  not as an approved solution.
- No game implementation or live deployment was changed.

## 2026-08-16 — Animation history audit

- Audited the complete Zen animation commit history from `372936d` through
  `ffda097` after repeatedly proposing already-tried approaches.
- Added `wiki/zen-animation-decisions.md` as the mandatory source of truth.
- Recorded whole-image warps, sliced overlays, short sprite cycles, layered
  prototypes, painted dioramas, and the latest procedural rebuild with explicit
  verdicts.
- Marked "use Spine" as insufficient by itself: a runtime or rigging tool does
  not replace purpose-built layered art and authored motion.
- No game code, active assets, mechanics, build, or deployment was changed.

## 2026-08-16 — Latest painted rebuild review

- `ffda097` replaced the active Zen visual scene with a new painted vertical
  world and procedural water, cloud, petal, and bird motion.
- The generated painting was positively received.
- The animation was not accepted: objects still did not feel physically alive
  or integrated into the world.
- Treat this commit as the current visual baseline, not an approved animation
  solution.

## 2026-08-16 — Rejected overlay animation

- Removed the waterfall and sakura sprite-sheet overlays from the active scene.
- Live review showed that they were not anchored to the painted world and read
  as randomly switching stickers.
- The next animation pass requires clean background plates, fixed attachment
  pivots, occlusion masks, and continuous object rigs before activation.

## 2026-08-16 — Authored Zen animation pass

- Removed the active UV cloud/water warps and whole-image canopy deformation.
- Added eight-frame authored waterfall and sakura `AnimatedSprite2D` cycles.
- Matched the new frames to the existing valley and foreground source art.
- Recorded 481 fixed-camera frames at 720 x 1280 and 60 FPS for visual QA.
- Kept camera, stacking physics, stones, and input mechanics unchanged.

## 2026-08-15 — Complete vertical Zen world

- Rebuilt the start around the authored valley, bridge, water, and terrace.
- Extended the route through high mountains, open sky, and evening zenith.
- Added local cloud, water, canopy, and petal motion to the parallax system.
- Replaced hard image joins with broad mist transitions.
- Verified the start, five physical drops, mid-climb, and `BT_CLIMB=5200`.
- Kept stacking physics and shared game mechanics unchanged.

## 2026-06-22
- Added BOOTSTRAP knowledge docs (CLAUDE.md, spec, tasks, wiki, LOG) and populated
  spec/wiki from the actual code, so laptop + VPS Telegram agent share one source
  of truth.

## 2026-08-14 — Layered Zen starting-section prototype

- Audited the existing tall-background overlay approach from both art-direction
  and Godot implementation perspectives.
- Replaced the Zen start view with an isolated visual prototype while leaving
  stacking physics and object dimensions unchanged.
- Added a clean 720 x 1280 world-space background plate, a subdivided sakura
  mesh with intermittent gusts, a fixed-silhouette animated waterfall, and
  drifting procedural mist.
- Rounded the Zen prototype camera to integer pixels to avoid pixel shimmer.
- Recorded a seven-second 720 x 1280 animation review and completed a Web export.
- Deployed the prototype to GitHub Pages for immediate Telegram testing.
- The next decision is visual approval before extending the world upward.

## 2026-08-14 — Zen monastery-gorge extension

- Extended the layered Zen route upward with a second 720 x 1280 authored
  section containing cliff monasteries, distant peaks, bamboo, and open mist.
- Added a separate animated waterfall and a drifting mist band.
- Joined the two plates with a 96-pixel overlap and lower-edge fade.
- Removed an independent pine overlay after visual QA exposed a color fringe.
- Verified both the upper composition and the transition during camera climb.

## 2026-08-14 — Painted Zen diorama experiment

- Replaced the active pixel-art prototype with an original hand-painted
  theatrical diorama while retaining the existing stacking physics.
- Added a valley start plate, an authored transparent foreground with integrated
  terrace, and an upper cloud-temple plate.
- Hid only the old Zen pedestal sprite; its collision and tower coordinates are
  unchanged.
- Added restrained foreground deformation and short drifting petal movement.
- Verified the start, first placed stone, upper camera position, and section
  transition in native Godot.

## 2026-08-15 — Four-plane Zen parallax demonstration

- Rebuilt the active painted diorama around four independent `Parallax2D`
  planes instead of manual camera compensation.
- Added authored far and mid plates derived from one visual composition.
- Kept the existing foreground terrace as a separate near plane and moved
  petals into an atmosphere plane.
- Tuned vertical depth for a climbing game and added a 128-pixel upper-section
  overlap.
- Verified start, mid-climb, and upper-section camera positions in Godot.

## 2026-08-16 — Playable Blender Zen world

- Replaced the active Zen background renderer with a continuous Blender 2.5D
  world displayed through a Godot `SubViewport`.
- Connected the existing vertical gameplay camera to the Blender world without
  changing stone physics or drop coordinates.
- Merged environmental object motion into one glTF scene timeline so Godot can
  animate branches, blossoms, clouds, lanterns, kites, petals, and water.
- Rebuilt the river as a perspective plane and animated foam geometry because
  glTF does not preserve Blender procedural material animation.
- Verified start framing, five automatic drops, camera climb, and timed motion
  differences in native Godot before Web export.

## 2026-08-16 — Anime 16-bit Zen visual rebuild

- Replaced the active low-poly Blender background with five saturated Japanese
  anime pixel-art chapters covering the full tested camera climb.
- Standardized every chapter through a `360 x 640` logical grid and exact `2x`
  nearest-neighbor output.
- Added eight matching opaque stone sprites with exact `180 x 56` canvases and
  removed the old per-texture vertical stretching and offsets.
- Aligned the illustrated shrine platform with the unchanged physical base.
- Added pixel-fog overlap between chapters and verified three upper climb
  positions plus a five-stone gameplay stack.
