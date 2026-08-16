# Balance Tower project journal

This is the mandatory chronological record of key project checkpoints. Each
entry records the agreed goal, implementation method, observed result, user
verdict, and consequence. Read this file before any substantial project work.

## Entry format

- Goal: what was agreed.
- Method: how it was implemented.
- Result: what was actually produced and verified.
- User verdict: accepted, partially accepted, or rejected.
- Consequence: what must happen next and what must not be repeated.

## Checkpoint 1 — Preserve mechanics, replace graphics

- Goal: improve the graphics of the existing Telegram game without changing
  stacking physics, stone behavior, bonuses, advertising, or scene switching.
- Method: inspected the Godot project and separated visual selection from the
  shared `RigidBody2D` mechanics in `game.gd`.
- Result: Zen, Diner, and Airport remained skins over one physics core.
- User verdict: accepted constraint.
- Consequence: visual experiments must remain isolated from gameplay mechanics.

## Checkpoint 2 — Zen composition and stones

- Goal: create a tall Japanese Zen world for a vertically climbing camera, with
  coherent stone scale, contact, perspective, and a base integrated into the
  scene.
- Method: generated and iterated painted and pixel-art backgrounds, stones,
  pedestal variants, spacing, transparency, framing, and parallax.
- Result: background composition and parallax improved; stone transparency and
  spacing issues were corrected through several iterations.
- User verdict: later painted backgrounds were liked; several pedestal and
  stone variants were rejected as stylistically foreign.
- Consequence: preserve the successful visual composition, but do not treat a
  beautiful still image as a completed living scene.

## Checkpoint 3 — Procedural movement in Godot

- Goal: animate trees, water, bamboo, mist, clouds, lanterns, petals, birds, and
  kites so the Zen scene feels alive.
- Method: used tweens, sinusoidal transforms, UV movement, particles, mesh
  deformation, and procedural overlays in Godot.
- Result: objects technically moved, but the motion looked like distortion
  filters applied to a still image.
- User verdict: rejected and reverted.
- Consequence: do not repeat generic transforms or call them production
  animation.

## Checkpoint 4 — Sliced layers and sprite cycles

- Goal: replace procedural distortion with separately drawn animated objects.
- Method: cut foliage, water, waterfalls, mist, and clouds into alpha layers;
  later created rest/sway, rest/flow, and eight-frame sprite cycles.
- Result: overlays were visible as separate stickers, attachment and occlusion
  were unconvincing, and frame changes looked random.
- User verdict: rejected; active overlays were removed in `dc161f2`.
- Consequence: automatic slicing and short replacement cycles are closed paths.

## Checkpoint 5 — Layered prototypes and painted diorama

- Goal: rebuild the scene as authored vertical sections with coherent depth.
- Method: created layered start and gorge prototypes, then a painted diorama,
  four `Parallax2D` planes, mist transitions, and a complete vertical route.
- Result: composition, depth, camera climb, and background coverage improved.
- User verdict: the painted environments and parallax were useful and sometimes
  strongly liked; internal object animation remained unacceptable.
- Consequence: retain this as visual research, not proof of animation quality.

## Checkpoint 6 — Fresh painted world rebuild

- Goal: stop patching rejected artwork and rebuild the whole Zen environment.
- Method: generated a new cohesive valley, connected vertical chapters, added
  soft transitions, and used procedural ripples, clouds, petals, and birds.
- Result: deployed in `ffda097`; the painting was attractive and camera coverage
  worked through the tested climb.
- User verdict: generation quality liked; moving objects still felt dead or
  incorrectly animated.
- Consequence: `ffda097` is a visual baseline only. Its animation system is not
  an approved solution.

## Checkpoint 7 — Incorrect repeated recommendation

- Goal: identify another environment capable of Rayman-like animation.
- Method: recommended Krita/Photoshop, Spine, and Godot after reviewing engine
  features.
- Result: this repeated an already discussed principle without producing a new
  demonstrable production method.
- User verdict: rejected as another trip around the same circle.
- Consequence: "use Spine" is not a sufficient answer. Future recommendations
  must identify a materially different production environment and explain what
  can actually be built and tested there.

## Current key point — 2026-08-16

- Accepted: high-quality generated painted composition and vertical parallax.
- Rejected: all attempts to animate a flattened painting with transforms,
  particles, extracted overlays, or short sprite replacement.
- Unresolved: production of genuinely articulated environmental objects.
- New direction under analysis: a real 2.5D diorama authored in Blender and
  rendered either inside Godot or directly on the Web. This has not yet been
  implemented, approved, or rejected.
- No new implementation may begin until its smallest complete test, toolchain,
  performance target, and rollback boundary are written here.

## Checkpoint 8 — First Blender 2.5D diorama test

- Goal: test a materially different production environment where environmental
  elements are real scene objects instead of extracted parts of a flat image.
- Method: installed Blender 5.2.0; created an orthographic 3D Zen diorama with
  separate cliffs, shrine, articulated sakura branches, attached blossoms,
  hanging lantern, animated water material, moving cloud groups, petals, and a
  vertically animated camera. Rendered 240 frames at 30 FPS.
- Result: object attachment and continuous movement work as intended. The test
  no longer depends on screen-space warps or randomly switched PNG overlays.
  However, programmatically assembled primitives look like a rough blockout,
  not finished Rayman-quality environment art.
- User verdict: pending review of `art_review/blender_zen/zen_diorama.mp4`.
- Consequence: Blender is technically viable for coherent motion, but procedural
  geometry alone is not an acceptable art pipeline. Do not deploy this test.
  Continuing this direction requires authored models, silhouettes, textures,
  lighting, and composition rather than adding more motion to the blockout.

## Checkpoint 9 — Full-height Blender Zen integration

- Goal: turn the accepted Blender direction into a playable Zen background
  while preserving the existing stacking mechanics and camera behavior.
- Method: extended one continuous 2.5D world through valley, monastery, clouds,
  gates, kites, and night sky; exported it as GLB; rendered it through a Godot
  `SubViewport`; linked the 3D camera to the existing 2D camera climb.
- Result: the Godot scene now renders the Blender world behind live stones.
  Blender exports all environmental motion as one scene timeline, including
  articulated sakura, clouds, lantern, kites, petals, river foam, and waterfall
  streams. Start, five-drop gameplay, multiple climb heights, and motion between
  timed screenshots were checked locally.
- User verdict: pending live Telegram review.
- Consequence: this is the first deployable object-animation baseline. It does
  not modify stone physics. Further art passes should replace or refine actual
  Blender objects instead of returning to sliced PNG overlays or distortion.

## Checkpoint 10 — Saturated anime 16-bit Zen rebuild

- Goal: replace the rejected low-poly Blender art with one coherent Japanese
  anime 16-bit visual language shared by the world, foundation, and stones.
- Method: approved one complete art-direction frame, authored five continuous
  vertical chapters at a logical `360 x 640` pixel grid, normalized them to
  exact `2x` nearest-neighbor output, and rebuilt eight stone sprites around
  the unchanged `180 x 56` physics contract.
- Result: the active Zen renderer now presents a dense village, shrine street,
  mountain monastery, cloud sunset, and night zenith. The illustrated shrine
  platform is aligned with the physical foundation at `y = 970`; stone artwork
  uses identical top and bottom contact lines without per-sprite stretch hacks.
  Start, five drops, and climb positions `1200`, `2800`, and `4800` were checked
  in native Godot.
- User verdict: the art-direction target was approved; live build review is
  pending.
- Consequence: this becomes the new visual baseline. Environmental animation
  must be authored against these pixel layers and may not revive the rejected
  low-poly Blender blockout or generic distortion filters.

## Checkpoint 11 — Authored object animation for chapter zero

- Goal: make the approved pixel-art world genuinely alive without deforming a
  flattened background or moving rectangular cutouts.
- Method: regenerated chapter zero as a clean base with the world inpainted
  behind moving elements; separately authored six-frame sakura and banner
  cycles, an eight-frame waterfall cycle, four cloud objects, lantern interiors,
  and individual petal paths. Integrated them as `AnimatedSprite2D` objects and
  attached transforms using integer coordinates and nearest filtering.
- Result: waterfall foam changes internally while its silhouette remains fixed;
  sakura and cloth use coherent drawn poses; clouds travel as whole forms;
  lantern light stays inside its housing. Timed screenshots at one and four
  seconds differ visibly, and a five-stone gameplay stack remains unobstructed.
- User verdict: pending live Telegram review.
- Consequence: chapter zero is the production template for the remaining four
  chapters. They must receive their own clean bases, authored objects, and
  occlusion masks rather than reusing generic overlays.

## Checkpoint 12 — Standalone WebGL prototype without Godot

- Goal: prove that the Telegram game can run without the Godot runtime while
  retaining the stacking rules and using Blender as the scene source.
- Method: created an independent `web-next` Mini App. Three.js renders the
  existing animated Blender GLB, Rapier2D owns stone movement and contacts, and
  plain JavaScript owns the carrier, score, camera climb, boosts, persistence,
  and Telegram lifecycle calls.
- Result: the browser loads without Godot JavaScript or Godot WebAssembly. A
  centred first drop contacts the foundation and increments the score; a miss
  triggers game over; restart and the animated GLB timeline run without console
  errors. The prototype is isolated at `/next/`, so the current live game is
  unaffected.
- Visual status: the included GLB is the previously rejected low-poly technical
  blockout. It validates the new runtime architecture, not the final art target.
  Production work now belongs in the Blender scene rather than Godot overlays.
