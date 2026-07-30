# Making troops look like they are loading a Huey

Research + build notes, 2026-07-29 overnight. Source of truth for the beat is
`tools/huey_embark_loop.py` (re-runnable); output is
`assets/us/vehicles/huey_embark_staging.blend`, 800 frames.

## What actually makes it read right

**1. They sit on the cabin FLOOR with their legs hanging out the door.**
This is the iconic Vietnam Huey silhouette and it is the single biggest win. Troops
sat on the deck with feet dangling outside — partly weight, partly because the ship
flew low and fast and everyone wanted out quickly. It also solves an animation
problem for free: perching men on the bench needs a climb-up, which reads as a fake
vertical slide. Sitting on the lip turns the whole height change into **one sit**.

**2. You load from the SIDES, never the nose or tail.** (Caleb's ruling, and correct.)
The rotor disc dips toward the nose as the ship settles, and the tail rotor is
invisible when spinning. Men run out to a lane abeam their door, then turn in
perpendicular. Three men to a door.

**3. Cargo doors SLIDE AFT on a rail. They do not swing.** I had them rotating 80°,
which is wrong. In Vietnam the doors were very often **removed entirely** — worth
knowing for the "doors shut so the player cannot read the outcome" idea, because a
doorless slick is equally period-correct and cheaper.

**4. Crouched movement under the disc**, not upright walking. `walk_crouching_forward`
from the shared library.

## Build state

Working: side-lane approach, crouch-walk in, three men per door, sit on the lip with
legs outboard (**verified 6/6**: hips ~1.66, toes 1.02 below the 1.505 floor and
outboard of the hips), men ride the airframe on liftoff, doors slide shut before
liftoff, per-man random kit assembly (22–24 pieces, seed 1969), everyone armed.

Still crude:
- The rise from ground to floor lip is still **linear** — there is no plant-a-hand,
  step-on-the-skid beat. This is the next thing to author and the footage shows it.
- No crew chief reaching down to haul men in.
- Men do not shuffle inboard after sitting; a real stick compresses toward the middle.

## Footage findings — read before spending more time on mocap

**We Were Soldiers "Flying high"** (`1_Lc3EQkyDU`): the boarding beat is real but the
0:19–0:50 window is a **fast-cut montage — 13 cuts** — and MediaPipe loses identity at
every cut. Two continuous shots exist:
- **24.2–27.3s** one man climbing in, medium, side-on — the best take
- **32.6–35.1s** wide, side-on, several men — best *staging* reference

**Isolating a single shot is what matters, not resolution:**

| source | presence | contested | joint confidence |
|---|---|---|---|
| whole 0:19–0:50 window | 14–20% | 15–20% | all 18 below threshold |
| 32.6–35.1 wide | 75% | 21% | all 18 below threshold |
| **24.2–27.3 climb-in** | **82%** | **3%** | no warning |

**And it still failed.** The clean-looking 82% take retargeted onto PSXRig as a
collapsed, splayed heap. 360p + dark uniforms overlapping against a dark cabin gives
the detector enough to assert a confident 2D skeleton while the depth is garbage, and
depth is what the retarget eats. Same class as the game-viewmodel footage.

**So: this footage is beats/staging reference only.** Do not spend more time trying to
mocap it. The two paths that work are hand-keying off it, or Caleb filming himself
(his own footage has tracked 90%+ every time).

YouTube would only serve **360p** on both links — `web`/`web_safari` return images only,
`tv` is DRM'd, `android` works but SABR leaves format 18. Untried links from Caleb:
`cvGJYWRjybM`, `43tzd08z2UQ`.

## Traps hit building this (all silent, all cost a pass)

- `CHILD_OF` with no explicit inverse threw men 24m out of the map when the ride
  constraint engaged. Set `inverse_matrix` from the target's world matrix.
- Sampling a rig's start position **after** stripping its object curves returns a stale
  static transform. Read it first.
- The LZ scene leaves men constrained to the airframe — `constraints.clear()` before
  adding your own, or it double-applies.
- `rig.matrix_world = Matrix.Translation(p)` **wipes the glTF rest orientation** and
  lays every man on his back. Set `.location`.
- Deleting the whole `Hips.location` channel folds the man flat (head z 0.02) — that
  channel carries hip HEIGHT as well as travel. Strip X/Z, keep Y, exactly as
  `tools/export_anim_library.py` does.
- Waypoint paths must be **LINEAR**; Bezier handles overshoot between widely spaced
  keys and threw a man 10m into the air.
- `capture_kit()` re-imports the grunt GLB, which brings back the unlinked-white
  `MitchellCamo` / `Webbing` / `bandolier_tex` materials. Recolour after importing.

## Seat markers

`seat_pax_*` / `seat_gunner_*` sat **0.025m above the cabin floor** while the bench top
is **0.445m** above it — that is why everyone looked sunk into the airframe. Raised to
local z 1.72 in `huey_lz_staging.blend`. **The shipped `huey.glb` the game reads is a
different file and probably has the same defect** — check before wiring the seat system.

Sources:
- [Smithsonian — The Huey Defined America's Presence in Vietnam](https://www.smithsonianmag.com/smithsonian-institution/anniversary-fall-saigon-honoring-huey-helicopter-180955099/)
- [Smithsonian Air & Space — Huey](https://www.smithsonianmag.com/air-space-magazine/huey-1023487/)
- [Vietnam Helicopters Museum — UH-1H](https://www.vietnamhelicopters.org/uh-1h-huey/)
