# GROUND VEHICLE FLEET REVIEW — 2026-08-14

**Review half only. Nothing was built, exported, or modified.** The only files this
commission wrote are this document and the renders under
`C:\Users\caleb\AppData\Local\Temp\claude\C--Users-caleb\0201f774-4017-48d5-924a-0296e7efee35\scratchpad\vehicles\`.

**Mode: HEADLESS.** Blender 5.0.1 (`a3db93c5b259`), `-b --factory-startup`. No live
window was touched.

**The bar this fleet is measured against** is the v2 aircraft class —
`tools/build_f4_phantom_v2.py` / `build_a1_skyraider_v2.py`: 2,060 visible tris, 10 flat
materials, **zero textures**, every node at identity, real dimensions verified against
published figures, nose at Blender +Y, `-colonly` colliders that span the solid airframe,
and a re-runnable build script gated by a verifier
(`production/blender_notes.md:895-950`).

**Not one ground vehicle in this project meets any part of that contract.**

---

## THE ONE NUMBER THAT DESCRIBES THE WHOLE FLEET

Every ground vehicle was assembled from unmodified Blender primitives — `Cube`, `Cylinder`,
`Torus` — scaled into place. The triangles are not merely plentiful; **they are in the wrong
objects.**

| Model | Total tris | Tris in TORI (donuts) | Tris in all bodywork boxes |
|---|---|---|---|
| `m151_mutt_gun_jeep` | 8,376 | **3,456 = 41.3%** (steering wheel + 2 tow hooks) | 456 = **5.4%** (38 objects) |
| `m113_apc` | 18,808 | **12,672 = 67.4%** (11 lift rings / tow hooks / cable) | 396 = **2.1%** (33 objects) |
| `m35_deuce_truck` | 16,600 | **11,520 = 69.4%** (10 tyres) | 804 = **4.8%** (67 objects) |

The M113's **entire armoured hull is a 12-triangle box.** Five decorative lift rings on its
roof carry 5,760 triangles between them — **480× the hull.**

This is not a tri-count complaint. `recon-tri-budgets-are-style-not-perf` is the standing
ruling and it is correct: geometry count is not the FPS limiter here
(`production/PERF_LEDGER.md:98-100`). The indictment is **distribution**. A model that spends
67% of its geometry on donuts and 2% on its hull cannot have a silhouette, because nothing was
ever spent on the silhouette. That is exactly why the jeep reads badly.

The measurable cost lever the same ruling names — **materials and draw calls** — is also blown:
the M113 ships **26 materials**, 18 of them `.001`–`.009` duplicates of two colours. A convoy of
six vehicles can carry ~150 material slots.

---

## RANKED, WORST FIRST

| # | Asset | Verdict | One-line reason |
|---|---|---|---|
| 1 | **`m151_mutt_gun_jeep`** | **REBUILD** | Drives **90° sideways** in game, its body is a bare 12-tri slab with no tub, and 41% of its triangles are two tow hooks and a steering wheel — and it **leads every convoy in the game**. |
| 2 | **`m35_deuce_truck`** | **REBUILD** | Drives **180° backwards**, is **17% short / 27% low** against a real deuce, its cab is **half the width of its own bed**, and its tarp is a photographic burlap texture that renders as a **wicker basket**. |
| 3 | **`m113_apc`** | **REBUILD (least urgent)** | Facing is correct and the boxy silhouette reads, but it is **+25% wide / +11% long**, its tracks are **⅓ the real width**, it has no trim vane, a shovel floats in mid-air 0.32 m off the hull, and 26 materials ship for two colours. |
| 4 | **`us_artillery_m101`** | **SPLIT, then REBUILD the gun** | Not a vehicle asset at all — the towed howitzer is welded into a **13.4 m staged emplacement scene** with 4 rigged crew, sandbag wall and pit dirt, carrying a **3600×5700** texture. The gun cannot be spawned on its own. |
| 5 | **`water_buffalo`** | **IMPROVE** | **Has one horn and it is detached**, floating clear of the head with unapplied scale [2.63, 4.32, 4.32]; **1.20 m tall against a real 1.5–1.9 m**. A hornless buffalo is a cow. |
| 6 | **`zpu_aa_gun`** | **IMPROVE (facing only)** | Silhouette and dimensions are good (+2.7% L / +1.6% W vs real ZPU-2). Barrels point **−Y**, nonconforming — already on record, and flipping it changes what game code sees. |
| 7 | **`ox_cart_01`** | **PASSES** | 240 tris, correct dimensions, proper `-col`, palette-atlas materials. The best-built wheeled thing in the project. Two small notes below. |
| 8 | **`USJeep.obj`** | **FOSSIL — surface, do not delete** | Spring-RTS import, RTS units, no materials bound, **zero code references**. Ironically the best jeep BODY in the repo. |
| 9 | **`USM4A3Sherman.obj`** | **FOSSIL — surface, do not delete** | Spring-RTS import at 37 units long, no materials, zero references, and a WWII tank that has no place in this game. |

---

## INVENTORY (full sweep)

Swept 771 mesh/model files under `assets/`. Everything wheeled, tracked or towed:

| Asset | Path | File | Objects | Tris (vis / col) | Materials / textures | Facing | Collision |
|---|---|---|---|---|---|---|---|
| `m151_mutt_gun_jeep` | `assets/us/vehicles/m151_mutt_gun_jeep.glb` | 528 KB | 77 | 8,376 / 0 | 9 flat / **0** | nose **+X** ✗ | table box only |
| `m113_apc` | `assets/us/vehicles/m113_apc.glb` | 1,185 KB | 83 | 18,808 / 0 | **26** flat / 0 | nose **+Y** ✓ | table box only |
| `m35_deuce_truck` | `assets/us/vehicles/m35_deuce_truck.glb` | **7,958 KB** | 113 | 16,600 / 0 | 12 / **8 × 1024²** | nose **−Y** ✗ | table box only |
| `us_artillery_m101` | `assets/us/artillery/us_artillery_m101.glb` | **14,263 KB** | 124 | 28,592 / 0 | 10 / 7 (incl. 3600×5700) | scene | none |
| `zpu_aa_gun` | `assets/world/…/emplacements_real/zpu_aa_gun.glb` | 227 KB | 6 | 2,272 / 1,080 | 8 flat / 0 | barrels **−Y** ✗ | `-col` mesh |
| `ox_cart_01` | `assets/world/…/village/ox_cart_01.glb` | 186 KB | 6 | 697 / 240 | 6 / 3 atlas | length **+Y** ✓ | `-col` mesh |
| `water_buffalo` | `assets/world/animals/water_buffalo.glb` | 528 KB | 3 | 960 / 0 | 2 flat / 0 | n/a | table box |
| `USJeep.obj` | `assets/us/vehicles/USJeep.obj` | 150 KB | 1 | 1,666 / 0 | **0 bound** | n/a | unused |
| `USM4A3Sherman.obj` | `assets/us/vehicles/USM4A3Sherman.obj` | 349 KB | 1 | 4,066 / 0 | **0 bound** | n/a | unused |

**Searched for and NOT FOUND in this project:** M151A1C recoilless variant · M548 · M577
command track · M88 · Gama Goat (M561) · M274 Mule · **M149 "Water Buffalo" water trailer**
(the only `water_buffalo` in the tree is the animal) · any trailer of any kind · bicycles ·
sampans · ARVN/NVA trucks (ZIL-157, GAZ-63) · any enemy ground vehicle whatsoever. The VC/NVA
side has no ground vehicles at all — only the ZPU emplacement.

`m29_mortar.glb` was examined and excluded: man-portable, not wheeled or towed.

---

## REAL-WORLD DIMENSIONS OF RECORD

Verified this session; the rebuild commissions inherit these numbers and their sources.

| Vehicle | Length | Width | Height | Other | Source |
|---|---|---|---|---|---|
| **M151 / M151A2 MUTT** | **3.371 m** (132.7 in) | **1.633 m** (64.3 in) | **1.803 m** top up · **1.350 m** reduced | wheelbase **2.159 m** (85 in) · curb 1,100 kg | en.wikipedia.org/wiki/M151_jeep |
| **M113 / M113A1** | **4.863 m** (15 ft 11.5 in) | **2.686 m** (8 ft 9.7 in) | **2.5 m** (8 ft 2 in) | 12.3 t · **5 road wheels/side** · ground clearance 0.434 m (A1) · 2 crew + 11–15 pax | en.wikipedia.org/wiki/M113_armored_personnel_carrier |
| **M35A2 deuce-and-a-half** | **6.98 m** (274¾ in) no winch · **7.0 m** with | **2.36 m** (93 in) · 2.4 m equipped | **2.82 m** (111 in) to cab roof · 2.8 m equipped | cargo bed **2.4 × 3.6 m** · tyres **9.00×20** · dual-wheel tandem, 10 wheels · curb 5,900–7,300 kg | en.wikipedia.org/wiki/M35_series_2½-ton_6x6_cargo_truck |
| **M101A1 105 mm howitzer** | **5.94 m** travelling | **2.21 m** | **1.73 m** | barrel 2.31 m L/22 · 2,260 kg · split trail, steel wheels w/ pneumatic tyres · elev −5°…+65°, trav ±23° | en.wikipedia.org/wiki/M101_howitzer |
| **ZPU-2** | **3.54 m** | **1.92 m** | **1.83 m** | 639 kg in action · twin 14.5 mm · late carriage folds its wheels clear in firing position | militaryfactory.com ZPU-2 (armor_id=193) |
| **Water buffalo** (swamp type, *Bubalus bubalis*) | 2.4–3.0 m body | ~0.9–1.0 m | **1.5–1.9 m at the withers** | horns are the silhouette — long, swept back, crescent | general zoological reference |

---

# 1 · M151 MUTT GUN JEEP — REBUILD

**`assets/us/vehicles/m151_mutt_gun_jeep.glb`** · 8,376 tris · 77 objects · 9 materials · no textures

Renders:
- `…\scratchpad\vehicles\m151_mutt_gun_jeep_front.png`
- `…\scratchpad\vehicles\m151_mutt_gun_jeep_side.png`
- `…\scratchpad\vehicles\m151_mutt_gun_jeep_3qtr.png`
- `…\scratchpad\vehicles\_probe_m151_matid.png` (material-ID pass, used to identify parts rather than guess at them)

The Summoner said "the jeep is pretty bad." Here is exactly why, with the numbers.

### Defect 1 — it drives sideways, and it leads every convoy

Measured part positions in the shipped GLB: `Grille` at Blender **x +1.85**, `Front_Bumper`
**x +1.90**, both headlights **x +1.85**, `Taillight_L/R` at **x −1.35**. The nose points down
**Blender +X**.

The ratified convention is **forward = Blender +Y = Godot −Z**
(`recon-vehicle-facing-convention`; proof asset `m60_pintle.glb`). `DestructibleVehicle.create`
(`scripts/vehicles/destructible_vehicle.gd:7-33`) applies **no facing correction of any kind** —
it loads the GLB and sets `rotation_degrees.y` from `atan2(dir.x, dir.z)`
(`scripts/missions/convoy_spawner.gd:35`, `scripts/vehicles/convoy.gd:111`). So the model's local
−Z is driven down the route. **The jeep's local −Z is its left flank.** It crabs sideways down
every road it is on.

The collision table agrees, and proves it independently: `collision_table.gd:57` gives
`m151_mutt_gun_jeep` a box of `(1.8, 1.8, 3.5)` — 1.8 wide, 3.5 **deep**. The model is
**3.652 wide and 1.740 deep** in exactly those Godot axes. **The box is rotated 90° against
its own model.**

This is not a background asset. `mission_generator.gd:372` hardcodes
`var out: Array = ["m151_mutt_gun_jeep"]` — **the gun jeep is the first vehicle of every
convoy the generator produces**, and 60% of the time it is the tail vehicle too
(`:375-376`). The worst model in the fleet is the one the player meets first, driving sideways.

### Defect 2 — there is no body

`Body` is **one 12-triangle cube**, scale `[1.5, 0.75, 0.35]` (3.0 × 1.5 × 0.7 m). `Hood`,
`Grille`, `Floor_Pan`, all four fenders, both bumpers, the dashboard, all four windshield
members and all six seat pieces are also 12-triangle cubes — **38 of them, 456 triangles
total, 5.4% of the model.**

The M151's entire visual identity is its **unitised sheet-steel body tub** — the flat vertical
side panels running unbroken from behind the front fenders to the tail, with a crisp top
edge line, and the fenders pressed into that same shell. The model has none of it: the deck is
a plank, you see daylight the length of the vehicle underneath it, and the fenders are separate
floating slabs. **In the side render it reads as a dune buggy chassis, not a jeep.**

Meanwhile `Steering_Wheel` = **1,152 triangles** (a default torus) and `Tow_Hook_L`/`_R` =
**1,152 triangles each**. Those three donuts are **41.3% of the whole model** — 7.6× the
triangle budget of every body panel put together. In the 3/4 render the two tow hooks read as
big black rings hanging off the bumper.

### Defect 3 — the windshield does not reach its own frame

Measured: `Windshield_Glass` spans y **−0.30…+0.30** (0.60 m wide). `Windshield_Post_L/R`
stand at y **±0.635…±0.665**. **There is a 0.335 m air gap on each side between the glass and
the posts it is supposed to sit in.** The glass covers 44% of its frame's span and 34% of the
vehicle's width. Clearly visible in the front render as a small pale panel floating inside an
oversized empty frame.

Same class of error on the headlights: `Grille` spans y ±0.275; `Headlight_L/R` sit at
y **±0.50**, and the fenders start at y ±0.55. **Both headlights hang in the 0.275 m gap
between the grille edge and the fender, attached to nothing.**

### Defect 4 — dimensions

| | Model (measured) | Real M151A2 | Error |
|---|---|---|---|
| Length | **3.652** | 3.371 | **+8.3%** |
| Width | **1.740** | 1.633 | **+6.6%** |
| Height (rollbar top) | 1.475 | 1.803 top up / 1.350 reduced | in range |
| Height (antenna tip) | 1.682 | — | — |
| Wheelbase | 2.100 | 2.159 | −2.7% ✓ |
| Track | 1.500 | ~1.377 | +8.9% |
| Tyre diameter | 0.700 | ~0.78 (7.00-16) | −10% |

Origin is at ground level between the axles, tyres touching z = 0. That part is right.

### Defect 5 — hygiene

**Unapplied scale on 40 of 77 objects.** Nine materials, four of which are pointless splits
(`Red_L`/`Red_R` are the same colour; `LightLens_L`/`LightLens_R` are the same colour). UVs are
untouched primitive defaults — 14 unique coordinates on the cubes, 637 on the tori. No
`-colonly` collider ships.

### THE FIX ALREADY EXISTS AND WAS NEVER EXPORTED

**`assets/us/vehicles/m151_rigged.blend` (2026-07-29) is a corrected jeep sitting on disk.**
Measured this session:

- Size `[1.740, 3.652, 1.682]` — length now on **Y**.
- `Grille` at y **+1.825…+1.875**, `Front_Bumper` **+1.875…+1.925**, `Taillight_L/R` at
  y **−1.34**. **Nose is +Y. Conforming.**
- Adds 12 empties the shipped GLB does not have: `M151_ROOT`, `MuzzlePoint`, `GunPivot`,
  `STEER_PIVOT`, `WHEEL_FL/FR/RL/RR`, and seats `seat_driver` / `seat_passenger` /
  `seat_gunner` / `seat_rear`.
- Adds 6 actions: `GunPivotAction`, `STEER_PIVOTAction`, `WHEEL_*Action`.
- Headlight and taillight L/R naming is correct against the frame (`Headlight_L` at −x = the
  vehicle's left).

The shipped GLB is dated **2026-05-25**. The facing fix was done on **2026-07-29** and never
made it into an export. Every sideways-driving jeep in the game since July is a **shipping
step that was skipped**, not a modelling problem.

*(The same is true of the M35 — see §2. Neither `.blend` is a substitute for a rebuild: they
carry the identical primitive-soup geometry, and `m151_rigged.blend` inherits the 1,152-tri
tow-hook donuts unchanged. But if a stopgap is ever wanted before the rebuild lands, exporting
these two blends fixes both facing bugs on its own.)*

### REBUILD SPEC — what the new M151 must nail

**Frame contract** (copy the v2 aircraft pattern exactly):
nose at **Blender +Y** = Godot −Z · +Z up · real metres · **every object at identity, all
transforms applied** · origin on the **ground line, on the centreline, midway between the
axles** (so `y_offset` can go to 0 and the model parks flat) · re-runnable build script
`tools/build_m151_mutt_v2.py` gated by `tools/verify_m151_mutt_v2.py`.

**Dimensions to build to:** length **3.371** · width **1.633** · wheelbase **2.159** ·
track ~**1.377** · tyre OD **0.78** (7.00-16) · rollbar top ~**1.60** · windscreen-up
height **1.803**.

**Silhouette identity — the five features that make it an M151 and not "a jeep":**

1. **THE ONE-PIECE BODY TUB.** This is the whole asset. Flat vertical side panels, unbroken
   from the rear of the front fender to the tail, with a single crisp horizontal top edge and
   a closed floor. It must read as a stamped steel shell, not a deck on a frame. Nothing else
   on this list matters if this is missing — and it is the thing that is missing today.
2. **THE HORIZONTAL GRILLE.** Verified this session and it is the detail everyone gets wrong:
   *"Due to copyright and trademark issues, the M151 did not feature Jeep's distinctive seven
   vertical slot grille, instead, a horizontal grille was used"* (Wikipedia, M151 jeep).
   Build **horizontal slats**, recessed in a flat vertical panel that spans the full width
   between the fenders. Do not build a seven-slot Willys grille.
3. **HEADLIGHTS INSIDE THE GRILLE PANEL, NOT BESIDE IT** — round, recessed into the same flat
   front panel, inboard of the fender crowns and structurally attached to the panel. On an
   **M151A2** add the **large combination turn-signal / blackout lights on the front fenders**;
   the fenders were reshaped to take them and that bulge is the A2's tell versus the flat-fendered
   A1.
4. **THE FLAT-TOP FENDER LINE** running forward from the windshield base to the grille panel,
   with the wheel arch cut into the tub side — one continuous form with the body, not four
   floating slabs.
5. **THE FULL-WIDTH FOLD-DOWN WINDSCREEN FRAME** — glass filling its frame edge to edge
   (~1.35 m), hinged at the cowl, with the two A-posts as the frame's own sides. Not a small
   pane inside a large empty rectangle.

**Gun-mount variant this one carries:** a **centre-rear pedestal M60** (`Gun_Pedestal` at
y −0.4 on the centreline, `Gun_Swivel` at z 1.02, muzzle forward). That is the field-expedient
pedestal gun jeep, and it is the right variant to keep — build the pedestal into the rear tub
floor with a proper base plate, a traversing ring, and the M60 on a cradle. **Do not** build
it as an M151A1C recoilless-rifle jeep; nothing in the project asks for one.

**Materials:** collapse 9 → **4 or 5 flat materials, no textures** (olive drab · dark metal ·
rubber · glass · lens), matching the F-4 v2 contract. Merge the duplicate `Red_L`/`Red_R` and
`LightLens_L`/`LightLens_R`.

**Geometry budget:** the F-4 v2 ships a whole fighter in **2,060 tris**. A jeep should land
well under that — **~700–1,100 tris** with the body tub, fenders, grille, windscreen frame,
seats, rollbar, wheels and the pedestal M60. Wheels as 10–12-sided cylinders. **No tori
anywhere.** The steering wheel is an 8-segment ring or a flat disc; the tow hooks are boxes.

**Collision:** ship `-colonly` meshes per the aircraft pattern, and either retune
`collision_table.gd:57` to `(1.633, 1.803, 3.371)` or drop the box and let the colliders serve.
As it stands the box is 90° out and must not survive the rebuild unchanged.

---

# 2 · M35 DEUCE-AND-A-HALF — REBUILD

**`assets/us/vehicles/m35_deuce_truck.glb`** · 16,600 tris · 113 objects · 12 materials ·
**8 textures at 1024²** · **7.96 MB** (6.7× the next-largest vehicle)

Renders: `m35_deuce_truck_front.png` · `_side.png` · `_3qtr.png`

### Defect 1 — it drives backwards

`Grille` at Blender y **−3.28**, headlights **−3.28**, cab **−2.75…−1.65**, cargo bed running
back to **+2.13**. **Nose is −Y**, i.e. Godot **+Z**. Convention is nose −Z. **180° out** —
the deuce reverses down every convoy route at full speed.

### Defect 2 — the cab is half the width of the truck

Measured `CabBody` **1.05 m wide**. Measured `CargoBed` **2.10 m wide**. On a real M35 the cab
is essentially full body width. In the front render the bed's front wall is visible sticking
out on **both sides past the cab**, and the truck reads as a toy. The windscreen is **0.85 m**
against a real ~1.7 m two-pane unit, sunk in a recess. This is the single most damaging
silhouette error in the model.

### Defect 3 — the tarp is a wicker basket

`hessian_230` — a photographic **burlap/hessian** texture at 1024×1024 — is mapped to the
cargo cover. In every render it reads unmistakably as **woven wicker**, not olive-drab canvas.
This is the photograph-as-texture bug class from `recon-gear-fitting-laws`, and it is visible
from any distance.

Worse, the frame is on the **outside**: `Canvas_Top` spans z **2.113…2.143** while
`BowRail_±0.93` spans z **2.212…2.242** — **the bow rails sit 7 cm above the tarp**, so the
truck wears a bright metal cage over its own cover. On a real deuce the bows are underneath and
invisible.

`Canvas_Top` is also **off-centre**: x **−0.934…+1.010**, a 7.6 cm overhang to one side.

### Defect 4 — tyres wearing an asphalt photograph

All ten tyre objects carry the material **`worn_asphalt`**. They render brown and mottled, like
mud or wood. Ten tyres × 1,152 tris (tori) = **11,520 triangles, 69.4% of the entire truck**,
spent on donuts wearing a road-surface photo.

### Defect 5 — dimensions, wrong in every axis

| | Model | Real M35A2 | Error |
|---|---|---|---|
| Length | **5.778** | 6.98 | **−17.2%** (1.20 m short) |
| Width | **2.100** | 2.36 | **−11.0%** |
| Height, cab roof | **2.050** | 2.82 | **−27.3%** |
| Height, tarp top | 2.146 | ~2.9–3.0 | −26% |
| Height, antenna tip | 3.300 | — | — |
| Cargo bed | 2.10 × 3.69 | **2.4 × 3.6** | width −12.5%, length ✓ |
| Bed floor height | **0.824** | ~1.37 | **−40%** |

The truck is uniformly undersized. Against the 1.7132 m datum in the renders, the bed side
wall tops out level with a grunt's chest; on a real deuce it is above his head. It reads as a
three-quarter-ton, not a two-and-a-half.

The whole model also sits **0.05 m below the ground line** (bbox min z = −0.050).

### Defect 6 — hygiene

**Unapplied scale on 67 of 113 objects.** `TailLight_-0.45` at y −2.304…−2.274 vs
`TailLight_0.45` at −2.194…−2.164 — **the two tail lights are 11 cm apart fore-and-aft.** The
mirrors are 5 cm apart in height. Eight 1024² textures ship for what the v2 fleet does with
flat colour.

### The fix, again, is half-done on disk

**`assets/us/vehicles/m35_rigged.blend` (2026-07-29)**: `Grille` at y **+3.254…+3.304**,
`CargoBed_Tailgate` at **−2.21**. **Nose +Y. Conforming.** It adds `TAILGATE_PIVOT`, wheel-spin
actions, and 12 seat empties (`seat_driver`, `seat_passenger`, `seat_troop_l_1..5`,
`seat_troop_r_1..5`). The shipped GLB (2026-05-20) carries the 11 wheel empties but not the
tailgate, not the seats, not the actions, and not the facing fix.

One naming defect to fix in the rebuild rather than inherit: in `m35_rigged.blend`
`CargoBed_LeftWall` sits at **+x** and `CargoBed_RightWall` at **−x**. With forward = +Y and
up = +Z, the vehicle's right is +X. **The L/R naming is inverted.** (The M151's is correct.)

### REBUILD SPEC — what the new M35 must nail

Build to **6.98 × 2.36 × 2.82** (cab roof), cargo bed **2.4 × 3.6 m**, tyres **9.00×20**
(~1.05 m OD), **dual-wheel tandem rear — 10 wheels**, bed floor at ~1.37 m. Nose **+Y**,
identity transforms, ground-line origin.

**Silhouette identity:**

1. **A FULL-WIDTH CAB.** ~2.1–2.2 m across, shoulder to shoulder with the bed, with the
   full-width two-pane windscreen. Fixing only this transforms the read.
2. **THE VERTICAL-BAR GRILLE** set between two big round fender-mounted headlight pods, with
   the flat narrow bumper below and the brush guard bars. The current front is a blank slab.
3. **THE LONG FLAT HOOD** with its distinct side louvre panels running back to the windscreen
   base, and the two flat front fenders standing proud either side of it.
4. **THE BOW-AND-TARP TOP AS ONE SMOOTH FORM** — bows *inside*, tarp *outside*, no metal cage
   on top. Flat olive canvas, **no photographic burlap**.
5. **THE RIBBED STEEL BED SIDES** with the troop-seat hinge line, and the drop tailgate. Not
   wood planks.

**Materials:** collapse 12 materials and 8 × 1024² textures to **5–6 flat materials, no
textures**. That alone takes the GLB from 7.96 MB to a few hundred KB.
**Budget: ~900–1,400 tris.** No tori.

**Collision:** `collision_table.gd:151` box `(2.1, 3.3, 5.8)` was measured off *this* model, so
it inherits the same −17% error and its 3.3 height includes the radio antenna. Retune to the
real envelope or ship `-colonly` meshes.

---

# 3 · M113 APC — REBUILD (least urgent of the three)

**`assets/us/vehicles/m113_apc.glb`** · 18,808 tris · 83 objects · **26 materials** · no textures

Renders: `m113_apc_front.png` · `_side.png` · `_3qtr.png`

**This is the best of the three convoy vehicles.** Facing conforms (headlights at y +2.74,
ramp at −2.45 → nose **+Y** ✓). The boxy hull, sloped glacis, five road wheels per side and
the .50-cal cupola all read correctly in the renders. It is a recognisable M113 at a glance,
which is more than the other two manage.

### Defect 1 — it is 25% too wide, and the tracks are a third of their real width

| | Model | Real M113A1 | Error |
|---|---|---|---|
| Overall width | **3.366** | 2.686 | **+25.3%** |
| Hull width alone | **2.716** | (2.686 is the *total*) | hull alone exceeds the real total |
| Overall length | **5.515** | 4.863 | **+13.4%** |
| Hull length | 5.400 | 4.863 | **+11.0%** |
| Height, no antenna | 2.942 | 2.5 (ACAV w/ shields ~2.9) | acceptable for ACAV |
| Height, antenna tip | 3.798 | — | — |
| Track width | **0.120** | **~0.381** | **−68%** |
| Road wheels/side | 5 | 5 | ✓ |

The tracks are 12 cm wide belts hung 0.19 m outboard of the hull with the road wheels (0.15 m
wide) sticking out past them. In the 3/4 render they read as **bicycle chains**. Meanwhile the
hull box on its own is already wider than a real M113 is in total. The correct relationship is
the opposite of what is built: the hull sides sit essentially flush with the **outer** face of
a 0.38 m track, and hull + track = 2.686 m all-in.

The hull also **overhangs the running gear by 0.73 m at the nose** (hull front y +2.95, drive
sprocket front y +2.217).

### Defect 2 — the front has no M113 identity, and a shovel floats in mid-air

From dead ahead the vehicle is a **plain vertical rectangle with two white discs and one tow
ring**. Missing: the **trim vane** folded on the glacis (the M113's single most recognisable
front feature — it is what lets it swim), the two final-drive housing bulges low on the front,
the rectangular headlight brush guards, and the second tow shackle.

`Shovel` spans x **1.690…1.710**. The hull's outer face is at x **1.367** and the track's outer
face at **1.656**. **The shovel hangs 0.32 m clear of the hull and 0.03 m clear of the track —
attached to nothing, floating in space.** Visible in the side and 3/4 renders.

### Defect 3 — the ACAV kit is a fragment, and 5 giant donuts sit on the roof

The Vietnam ACAV kit is a **.50 cupola gunshield ring plus two M60 positions with shields at
the left and right rear**. What ships: three shield pieces (`ACAV_Shield_L.001`, `_L.002`,
`_R`) all clustered on **one side** of the cupola between x −0.005 and +0.718, forming a
partial arc rather than a ring — and `M60_Ammo_L` / `M60_Ammo_R` ammo cans on the roof
**with no M60s and no shields**.

Five `Lift_Ring_*` objects are 1,152-triangle tori. Two of them
(`Lift_Ring_-8_15`, `.001`) carry **unapplied scale [7.85, 7.22, 1.0]** and measure
**1.178 × 1.083 m** — metre-wide flat rings lying on the hull roof where a real lift ring is
~0.1 m. In the renders they read as a pale grey halo around the forward hatch. All eleven tori
together are **67.4% of the model's geometry**.

`Rear_Ramp` does exist (2.07 × 1.51 m plate on the rear face) — I checked before claiming it
missing — but it is a flat slab with no personnel door, no hydraulic cylinders and no ramp
detail.

### Defect 4 — 26 materials for two colours

`OD_Green` + `.002` + `.003`; `Track_Dark` + `.001`…`.009`; `Gun_Metal` + `.002`; six
identical `Glass_*`. Per `recon-tri-budgets-are-style-not-perf`, **material count is the
measured cost lever on this project**, not triangles. Twenty-six slots on one APC, in a convoy
that can hold two of them, is the real expense here.

### REBUILD SPEC

Build to **4.863 × 2.686 × 2.5**, **track 0.381 wide with the hull flush to its outer face**,
5 road wheels per side, ground clearance 0.434 m. Nose **+Y**, identities, ground-line origin.

**Silhouette identity:** the **trim vane** on the glacis · the **hull as one continuous
aluminium box** with its sloped glacis and vertical sides carrying the real rib/filler lines ·
the **full-height rear ramp with its personnel door** and the two ramp cylinders · the
**commander's cupola with the complete ACAV shield ring** · and the **two rear M60 positions
with their own shields** so it reads as a Vietnam ACAV rather than a stock A1.

**Materials:** 26 → **5–6 flat, no textures.** **Budget: ~1,200–1,800 tris.** No tori.
Retune `collision_table.gd:56` `(2.7, 2.2, 5.0)` — currently 0.67 m narrower and 0.51 m
shorter than the model it wraps — or ship `-colonly` meshes.

---

# 4 · M101 105 mm HOWITZER — SPLIT, THEN REBUILD THE GUN

**`assets/us/artillery/us_artillery_m101.glb`** · 28,592 tris · 124 objects · **14.3 MB**

Renders: `us_artillery_m101_front.png` · `_side.png` · `_3qtr.png`

**This is not a vehicle asset; it is a staged emplacement scene.** Bounding box
**13.37 × 13.37 × 4.78 m** — that is the pit, the sandbag revetment, ammo crate stacks and
four rigged crewmen (`PSXRig_gunner`, `_loader`, `_agunner`, `_ammo`), all welded into one GLB
with 14 actions and an `M101Rig`. The towed howitzer inside it cannot be spawned, towed, placed
or reused on its own.

It ships a **3600 × 5700** grunt texture — by a wide margin the largest image in the fleet — plus
a 960×896 face atlas, for an asset whose gun is the point.

The gun itself reads acceptably in the renders: barrel, shield, split trail, wheels. **Real
M101A1 for the rebuild: 5.94 m travelling × 2.21 m wide × 1.73 m high, barrel 2.31 m L/22,
2,260 kg, split trail on steel wheels with pneumatic tyres, elevation −5°…+65°,
traverse ±23°.**

**Caveat on the renders, stated so nobody convicts on it:** the crew appear T-posed, bare-
chested and one floats above the pit, and a shell hangs in mid-air. That is a **rest-pose
artefact of my headless import** — the actions were not evaluated and the grunt texture did not
bind. Per `recon-anim`/`blender-pose-position-rest-reads-as-broken` and
`unkeyed-pose-is-volatile`, that is not evidence of a defect and I am not scoring it as one.

**Recommendation:** split the gun into its own asset (`us_m101_howitzer.glb`, nose/muzzle +Y,
real dims, flat materials, ~600–900 tris, `-colonly`) and leave the staged scene as the
firebase set-piece it already is. Not urgent; it is not in a convoy and nothing spawns it.

---

# 5 · WATER BUFFALO — IMPROVE

**`assets/world/animals/water_buffalo.glb`** · 960 tris · 2 flat materials

Renders: `water_buffalo_front.png` · `_side.png` · `_3qtr.png`

**Naming note first:** this is the **animal**. It is not the M149 "Water Buffalo" 400-gallon
water trailer. The M149 does not exist in this project.

**Defect 1 — one horn, and it is detached.** The GLB contains `buffalo_horn_R` and **no
`buffalo_horn_L`**. The one horn carries **unapplied scale [2.632, 4.317, 4.317]**, is
bone-parented, and in the rest pose sits roughly 2 m clear of the animal — plainly visible in
`water_buffalo_side.png` as a curved grey shape floating in empty air beside the 1.7132 m
datum. The head itself has no horns on it.

The long swept-back crescent horns **are** the water buffalo's silhouette. Without them the
model reads as a generic cow — and it does, in the render.

**Defect 2 — undersized.** Measured **2.790 L × 0.537 W × 1.202 H** (after excluding the
glTF importer's bone-display `Icosphere`s, which are viewport furniture and in no exported
file). A real swamp buffalo stands **1.5–1.9 m at the withers** and is ~0.9–1.0 m across the
body. Against the datum in the render, its back is below a man's waist. It is ~25–35% short
and about half the correct width.

**Fix:** model both horns into the head mesh (or fix the bone parenting and apply the scale),
rescale to ~1.6 m at the withers and ~0.95 m across. The 960-tri body is otherwise fine.

---

# 6 · ZPU-2 AA GUN — IMPROVE (facing only)

**`assets/world/…/emplacements_real/zpu_aa_gun.glb`** · 2,272 visible + 1,080 `-col` tris ·
8 flat materials · **227 KB**

Renders: `zpu_aa_gun_front.png` · `_side.png` · `_3qtr.png`

**The best-proportioned military model in this review.** Twin barrels, seat, shield with a red
star, wheeled carriage with the wheels raised and outriggers down. Reads correctly at a glance.

| | Model | Real ZPU-2 | Error |
|---|---|---|---|
| Length | 3.635 | 3.54 | +2.7% |
| Width | 1.950 | 1.92 | +1.6% |
| Height | 1.392 | 1.83 | −24% (barrels are at zero elevation; not comparable) |

**One defect, already on record:** barrels point **Blender −Y** — nonconforming
(`recon-vehicle-facing-convention` names this asset explicitly). It ships a proper `-col`
mesh, which most of the fleet does not. Per the existing ruling, retro-flipping it **changes
what game code sees** and must be surfaced as a decision rather than quietly baked.

---

# 7 · OX CART — PASSES

**`assets/world/…/village/ox_cart_01.glb`** · 240 visible + 240 `-col` tris · 186 KB

Renders: `ox_cart_01_front.png` · `_side.png` · `_3qtr.png`

**The best-built wheeled asset in the project, and by a distance.** 240 triangles for a cart
with spoked wheels and shafts. Proper `-col` mesh. Palette-atlas materials
(`vil_timber` / `vil_bamboo` 256² + a 17×1 `jungle_palette` strip) — this is exactly the
discipline the vehicle fleet lacks. `collision_table.gd:33` `(1.85, 1.2, 3.96)` matches the
measured cart `1.848 × 1.199 × 3.961` to the millimetre.

Two observations, neither a defect against the family:

- **The four baked `_veg_` meshes and the `-col` twin are KIT-WIDE conventions, not an ox-cart
  problem.** I verified against `haystack_01`, `village_well_01`, `drying_rack_01` and
  `fence_run_01` — every one carries the same `X` + `X-col` pair and 2–5 `_veg_` bush/grass/moss
  meshes. Village props deliberately bring their own ground dressing. Not my lane; noted only so
  the next reader does not "fix" it.
- **UVs run u −1.532…0.668, v −1.532…0.725** — outside 0..1. Harmless under REPEAT wrap; worth
  a glance if the village atlas ever gets repacked.
- The cart rendered black on my Cycles bench. That is my bench, not the asset: the `-col` twin
  is geometrically coincident with the visible mesh and Cycles self-shadows it to black. The
  textures are not black (measured pixel means: `vil_timber` 0.298, `vil_bamboo` 0.426,
  `jungle_palette` 0.351).

---

# 8–9 · LEGACY SPRING-RTS IMPORTS — SURFACE, DO NOT DELETE

`assets/us/vehicles/USJeep.obj` (1,666 tris) and `assets/us/vehicles/USM4A3Sherman.obj`
(4,066 tris). Renders: `USJeep_legacy_*.png`, `USM4A3Sherman_legacy_*.png`.

Both are Spring-RTS `.obj` imports in **RTS units, not metres** — the jeep measures 8.4 units
long, the Sherman **37.1**. Neither binds its sibling texture
(`us_jeep_s3o_USJeep.png`, `us_m24_tank_usm24.png`, `us_halftrack_USM3A1Halftrack.png` are all
orphans in the same folder). **Zero code references to either.** The Sherman is a WWII tank
with no place in this game.

Under the FOSSIL LAW these are surfaced, not deleted — a decision for the Summoner.

**But one of them is worth looking at before the jeep rebuild starts.** `USJeep_legacy_3qtr.png`
shows a Willys MB with a **proper one-piece body tub**, integrated fenders, a full-width
windscreen frame with glass that fills it, a creased hood and folded rear panels — in **1,666
triangles**, one fifth of what the M151 spends. It is the wrong vehicle (WWII Willys, not an
M151) and it cannot ship as-is, but it is a free, already-in-repo study of the exact form the
M151 is missing. **The project already contains a better-built jeep body than the jeep it
ships.**

---

## CROSS-FLEET FINDINGS

1. **Two of the three convoy vehicles drive the wrong way, and both fixes are already sitting
   unexported on disk.** `m151_rigged.blend` and `m35_rigged.blend`, both 2026-07-29, both
   nose-+Y and conforming; both shipped GLBs predate them (2026-05-25 / 2026-05-20). This is a
   **missed export step**, not a modelling failure. Verified by part position, not by node name.

2. **No ground vehicle in the fleet ships a `-colonly` collider.** All three convoy vehicles
   rely entirely on the `collision_table.gd` box, and **all three boxes disagree with their
   models** — the M151's by 90°, the M113's by 0.67 m in width, the M35's by inheriting the
   model's own −17% error and its antenna height.

3. **The primitive-soup signature is fleet-wide**: unmodified `Torus` / `Cylinder` / `Cube`
   objects, unapplied scale on 40/77 (M151), 8/83 (M113) and 67/113 (M35) objects, duplicate
   `.001`-suffixed materials, and asymmetric or L/R-inverted part naming in every one. These
   were assembled by script from primitives and never touched again.

4. **The enemy has no ground vehicles at all.** No NVA/VC truck, no bicycle, no sampan, no
   ox-drawn logistics beyond the village cart. If the open-patrol world ever wants a supply
   route to ambush, there is nothing to put on it.

5. **A verifier gate is the missing machine.** The v2 aircraft each have one
   (`tools/verify_a1_skyraider_v2.py`, `tools/verify_f4_phantom_v2.py`) asserting facing,
   dimensions, material count and collider coverage **on the shipped GLB**. Had an equivalent
   existed for ground vehicles, the M151's 90° facing error could not have shipped for three
   months, and the unexported `.blend` fixes would have been caught the day they were made.
   **Every rebuild commission should land its verifier with it.**

---

## METHOD

- **Blender 5.0.1**, headless, `--factory-startup`. Scripts in the session scratchpad:
  `measure_vehicles.py` (per-object tris/materials/UVs/transforms),
  `measure2.py` (evaluated world bounds, mast-excluded heights, `huey_v3.glb` as a
  known-conforming control), `probe_nose.py` (facing by measured part position),
  `probe_empties.py`, `probe_col.py` (village kit family check), `probe_tex2.py` (texture
  pixel means), `render_vehicles.py`.
- **Facing was determined by measuring the world position of named parts** (grille, headlights,
  tail lights, ramp), never inferred from a node name. `huey_v3.glb` was measured alongside as a
  control on the glTF→Blender axis mapping.
- **Every render carries a 1.7132 m grunt datum** (`ModelActor.TARGET_HEIGHT_M`,
  `GAME_SCALE_STANDARD.md:8`), a **green cone at +Y** (the ratified forward direction) and a
  **red slab at −Y**, so scale and facing are readable straight off the image.
- The glTF importer's bone-display `Icosphere`s were excluded from all bounds — they are
  viewport furniture and appear in no exported file.
- All 27 renders were viewed. Cycles, 40 samples, 1000×640, `Standard` view transform.

**Renders:**
`C:\Users\caleb\AppData\Local\Temp\claude\C--Users-caleb\0201f774-4017-48d5-924a-0296e7efee35\scratchpad\vehicles\{name}_{front|side|3qtr}.png`

---

## SOURCES

- [M151 jeep — Wikipedia](https://en.wikipedia.org/wiki/M151_jeep)
- [M113 armored personnel carrier — Wikipedia](https://en.wikipedia.org/wiki/M113_armored_personnel_carrier)
- [M35 series 2½-ton 6x6 cargo truck — Wikipedia](https://en.wikipedia.org/wiki/M35_series_2%C2%BD-ton_6x6_cargo_truck)
- [M101 howitzer — Wikipedia](https://en.wikipedia.org/wiki/M101_howitzer)
- [ZPU-2 Twin-Barreled Towed AA Gun System — MilitaryFactory](https://www.militaryfactory.com/armor/detail.php?armor_id=193)
