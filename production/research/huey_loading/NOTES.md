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

---

## 2026-08-11 — FOOTAGE READ, his source: youtube 43tzd08z2UQ

Downloaded per the documented workflow (`--extractor-args "youtube:player_client=android"`,
whole file, trimmed locally). **640x360, 11m52s, 24fps** — SABR leaves only format 18, so this is
a STAGING source, not a mocap source ([[artillery-footage-not-mocap-source]]). Contact sheets
saved beside this file: `overview_000-120s.png`, `board_beats_133-141s.png`,
`board_beats_141-149s.png`.

### The boarding sequence, read frame by frame (t=141-149s)

| beat | what the men do |
|---|---|
| approach | run IN from abeam, **crouched under the disc**, rucks on, weapons carried low |
| mount | step up onto the **SKID**, hand on the door frame — this is the beat we never authored |
| pivot | turn outboard on the lip |
| sit | drop onto the **cabin floor / door lip**, legs hanging OUT over the skid |
| ride | seated facing OUTBOARD, boots outside the airframe, all the way through liftoff |

### THREE THINGS THE FOOTAGE SETTLES

1. **The doors are GONE, not ajar.** Every loaded ship in this sequence flies with the cargo
   bay wide open — no door in the aperture at all. The 7/29 note already said Vietnam slicks
   very often had the doors removed. Our transport is currently set 40% ajar, which is the one
   configuration the footage never shows.
2. **Troops do NOT sit on the bench facing inboard.** They sit on the floor / door lip facing
   OUTBOARD with their legs hanging over the skid. This is the iconic silhouette and it is what
   "the troops don't fit in the cabin" actually is — we are seating 8 men on a centre bench at
   hips z 1.22 against sockets at z 1.245, when the period staging puts them on the deck at the
   aperture. The 7/29 note reached the same conclusion independently and it is still not built.
3. **The missing beat is the SKID STEP.** 7/29 flagged the ground-to-lip rise as "still linear —
   no plant-a-hand, step-on-the-skid beat." That is exactly what reads as "running out" instead
   of "hopping off". Disembark is the same beat reversed: swing legs off the lip, drop past the
   skid, move off crouched.

### Marking reference seen in the same footage
White block **"ARMY"** on the tail boom · serial on the vertical fin · medevac ships carry a
**red cross on a white square** on the cabin door and nose · door gunners run the M60 on a mount
with the belt hanging free to a catch bag.

---

## 2026-08-12 — re-read at 3 and 8 fps, and the mount beat is NOT IN THE FOOTAGE

Source re-pulled (`43tzd08z2UQ`, format 18, 640x360, 26 MB). New sheets beside this file:
`board_fine_141_150.png` (3 fps over the boarding window) and `board_mount_143_146.png`
(8 fps, cropped to the door).

**THE FINDING: the camera cuts away at the exact moment of the mount.** At 3 fps the men reach
the doorway, and the very next usable frame already has them seated. The 8 fps crop confirms it —
frames at 143.0-143.9 s show men moving right-to-left *past the nose*, then the shot cuts and
returns with the stick already aboard. **There is no frame of a man stepping up onto the skid.**

That is why the step-up/enter beat was "never fully solved" across two sessions: we kept going
back to footage that does not contain it. **Stop looking for it here.** The mount must be
constructed from library motion against measured geometry, not copied.

### The seated pose, read precisely off rows 3-4 of `board_mount_143_146.png`

- Hips on the **deck edge**, thighs flat along the cabin floor.
- Knees at the **sill**, lower legs hanging **vertically outside** the airframe.
- **Boots swing FREE — they do not rest on the skid.** The skid is well below the boots.
  "Legs over the skid" means dangling above it, with **no foot contact at all**.
- Torsos upright, several leaning back against the bulkhead; weapons held vertical between the
  knees or laid across the lap. Rucks stay on.
- Doors absent on every ship in the sequence, confirming the 8/11 read.

**Consequence for the animation:** the seated clip has NO foot contact to solve — only a hip/thigh
contact on the deck at the lip. Solving feet onto the skid would be wrong and is what makes the
pose read stiff.

### Clips pulled for the beat (Mixamo MCP, 2026-08-12)

| file | Mixamo | frames | hips travel (cm, Mixamo axes) | use |
|---|---|---|---|---|
| `hop_off_heli.fbx` | (8/11) | 1..76, 2.50 s | vert **-86.6**, fwd +249.2 | the drop — matches the 0.865 lip almost exactly |
| `hop_off_heli_alt.fbx` | (8/11) | 1..89, 2.93 s | vert **-80.9**, fwd +187.4 | drop variant, shorter travel |
| `board_heli_sit_down.fbx` | `Stand To Sit` 123430901 | — | — | the enter beat the footage never shows |
| `disembark_heli_rise.fbx` | `Sit To Stand` 123390901 | — | — | rising off the lip before the drop |

Note Mixamo FBX hips travel is in **centimetres**; house library clips are in metres.
