# Art Scene Map

This file is the art-side map of the game. The gameplay code stays the source
of truth; visual work should fit these mechanics instead of fighting them.

## Core Mechanics

- The playfield is a 720 x 1280 world.
- The tower is centered at `base_x = 360`.
- Every falling block uses the same simple physics box: about `180 x 56`.
- The carrier moves horizontally from `x = 90` to `x = 630`.
- The carrier is always `175 px` above the current tower top.
- Tap/click releases the object as a `RigidBody2D` with downward push.
- The next object appears immediately after contact, while the tower can still
  wobble.
- The camera follows the tower top: `camera.y -> top_y - 150`.
- A block fails if it misses below the tower or if a placed block tilts/sinks
  too far.

Art implication: the middle vertical lane must stay readable at all times. The
player is judging horizontal alignment, so busy art directly behind the falling
object hurts the game.

## Shared 3D-Like Stage

The game is 2D, but every location should be composed like a small stage with
depth planes:

1. Sky / far wall: screen anchored, slowest movement.
2. Far vista: mountains/city/airfield, slow parallax.
3. Midground: window, counter, garden rocks, buildings, signs.
4. Gameplay platform: pedestal/plate/cart where the tower starts.
5. Falling object lane: the tower and carrier, highest readability.
6. Foreground frame: side decorations only, never blocking the center.
7. UI: score, coins, skin button, boosts.

The central gameplay column should be kept quiet from roughly `x = 250..470`.
Details should sit mostly outside that zone or behind low-contrast areas.

## Location 0: Zen

Current objects:

- Falling blocks: smooth stones.
- Carrier: hand holding the stone.
- Base: pedestal stone.
- Background: warm garden/pagoda scene.
- Live elements: particles, petals, optional atmosphere cycle.

Desired stage:

- Far: sunset sky, mountains, distant shrine/pagoda.
- Mid: reflective water or raked sand path leading toward the center.
- Platform: circular raked-sand target or flat stone base under the tower.
- Foreground: rocks, moss, lanterns, sakura branches on left/right edges.
- Motion: petals drifting, tiny dust/motes, subtle light shimmer.

Asset split:

- `background`: full vertical scene with calm center lane.
- `foreground_left/right`: optional side rocks/lantern/sakura overlays.
- `stone_1..4`: transparent wide pebbles matching the 180x56 physics box.
- `carrier`: hand or simple zen tongs, transparent.
- `pedestal`: flat stone/plinth, transparent.

## Location 1: Diner

Current objects:

- Falling blocks: pancakes drawn in code.
- Carrier: currently no strong themed carrier.
- Base: plate.
- Background: diner wall, window, counter, stools, menu, moving cars.
- Live elements: neon pulse, cars, steam.

Desired stage:

- Far: street through the window, moving cars, day/night tint.
- Mid: diner wall, neon sign, menu, clock, window frame.
- Platform: plate on counter, not just a flat red block.
- Foreground: counter edge, stools, syrup/coffee/napkins on side zones.
- Motion: neon pulse, steam, cars, small light flicker.

Asset split:

- `diner_bg`: wall/window/city/counter composition or layered pieces.
- `pancake_1..4`: transparent wide pancakes with toppings; readable silhouette.
- `carrier`: spatula, serving hand, or diner order rail hook.
- `pedestal`: plate with shadow, transparent.
- Optional side props: coffee cup, syrup bottles, pie display.

## Location 2: Airport

Current objects:

- Falling blocks: suitcases drawn in code.
- Carrier: currently no strong themed carrier.
- Base: luggage cart.
- Background: terminal, window/runway, moving planes, travelator, passengers.
- Live elements: planes, travelator people, night lights.

Desired stage:

- Far: runway behind glass, skyline/control tower, taxiing aircraft.
- Mid: terminal hall, flight board, seating, duty free, glass reflections.
- Platform: luggage cart centered under the tower.
- Foreground: travelator and side passengers, but center lane remains open.
- Motion: planes, travelator people, blinking runway/board lights.

Asset split:

- `airport_bg`: terminal/runway base composition or layered pieces.
- `suitcase_1..4`: transparent horizontal luggage sprites matching the box.
- `carrier`: baggage clamp, conveyor drop arm, or airport worker hand.
- `pedestal`: luggage cart, transparent.
- Optional side props: sign boards, glass reflections, passenger silhouettes.

## Implementation Rules

- Do not change physics constants while doing art.
- Do not change `ssize` unless the art absolutely requires a new physical box.
- Prefer transparent PNG sprites for falling objects and carriers.
- Keep fallback code-drawn objects so the game still runs if a PNG is missing.
- Add new art in per-location folders instead of mixing every theme into
  `assets/zen`.
- Verify each location with `BT_SHOT=hold BT_SKIN=N` before deployment.
- After local visual approval, run the normal deploy script so Telegram shows the
  same build.
