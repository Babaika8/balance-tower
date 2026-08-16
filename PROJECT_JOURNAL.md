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
