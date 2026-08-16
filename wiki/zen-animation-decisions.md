# Zen animation decision ledger

This file is the source of truth for Zen visual experiments. Read it before
proposing, generating, implementing, or deploying another animation approach.

## Product requirement

- Preserve the stacking mechanics and vertical camera climb.
- The scene must feel like one coherent living world.
- Motion must belong to objects in that world, not look like filters, stickers,
  overlays, or random image switching.
- Visual approval happens in the deployed Telegram build.
- A technically moving object is not automatically acceptable animation.

## Attempts and verdicts

| Commits | Approach | Observed result | Verdict |
| --- | --- | --- | --- |
| `372936d`–`8ec6048` | Whole-tree sway, stronger sway, water and mist transforms | Motion was synthetic and visibly distorted the still art | Reverted. Do not repeat. |
| `174a70d`–`c85020f` | Background cut into foliage, water, waterfall, cloud and mist PNG overlays | Layers did not share convincing attachment, depth, lighting or occlusion | Rejected. Do not revive these assets as production animation. |
| `7a3df17`, `ab98858` | Separate rest/sway foliage and rest/flow waterfall frames | Read as image switching instead of continuous physical motion | Rejected. |
| `a94646f`, `a4195dc` | Second layered artwork pass | Whole scene direction was rejected and explicitly reverted | Closed. |
| `b1842c7`, `7b16354` | Isolated layered start and monastery gorge | Better composition, but animation remained an overlay-based prototype | Useful only as visual research. |
| `76fe054`–`bf35412` | Painted diorama, four parallax planes, complete vertical world | Static composition and camera climb improved substantially | Composition accepted as useful; did not solve authored object animation. |
| `effdbb9`, `dc161f2` | Eight-frame authored sakura and waterfall sprite sheets | Still looked like unanchored stickers and random frame replacement | Explicitly rejected and removed from the active scene. |
| `ffda097` | Fresh painted vertical rebuild with procedural ripples, particles, clouds and birds | Generated painting was liked; object motion still did not meet the requested quality | Current visual baseline only. Animation approach not approved. |

## Closed proposals

Do not present the following as a new solution without new evidence in a
deployed prototype:

- sinusoidal rotation or scaling of extracted branches;
- UV warping of water, clouds, trees, or the whole image;
- generic particles placed over a static painting;
- two-frame or short sprite replacement presented as smooth animation;
- automatic slicing of a finished AI image;
- FFmpeg camera crops and overlay composites;
- "change engines" without proving that source-art production changes;
- "use Spine" as a conclusion by itself. Rigging software does not create the
  missing layered artwork, occlusion, attachment points, in-betweens, or art
  direction automatically.

## Current diagnosis

Godot is not proven to be the limiting factor. The repeated failure occurred
before runtime integration: the source scene was generated as a finished flat
painting, while production animation requires objects designed for motion from
the beginning. Moving a flattened result cannot reconstruct hidden surfaces,
correct pivots, changing silhouettes, shadows, or water flow.

The unresolved question is not "which tween or plugin should be tried next?".
It is whether a production-quality animated source package can be created for
one complete screen and then rendered efficiently in Telegram.

## Required evidence for any next approach

Before changing the active game again, produce one complete animation test that
contains all of the following:

1. One coherent 720 x 1280 Zen section designed as layers from the start.
2. A clean plate with hidden areas painted behind every moving object.
3. One tree with fixed trunk, articulated branches, changing leaf silhouette,
   secondary motion, and matching shadows.
4. Water whose motion follows the painted river or waterfall geometry.
5. One depth-aware atmospheric element with correct occlusion.
6. A vertical camera move demonstrating that all layers remain registered.
7. At least 20 seconds of continuous motion without exposure jumps or obvious
   synchronized repetition.
8. A Telegram Web build tested on a phone, with measured load size and FPS.

The toolchain may be Godot-native mesh animation, Spine, sprite sheets, PixiJS,
or another renderer. Approval depends on this evidence, not the tool name.

## Workflow rule

For every future Zen experiment, append the hypothesis, implementation, live
build URL or commit, observed user feedback, and final verdict here. Never
restart a closed approach because it disappeared from conversational context.
