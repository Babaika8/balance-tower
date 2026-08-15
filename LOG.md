# Log — balance-tower

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
