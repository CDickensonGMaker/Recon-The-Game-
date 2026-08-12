# Huey v3 — merged, exported, wired. 2026-08-08

---

## 2026-08-10 CREW PASS — in his live window, **NOT SAVED, NOT EXPORTED**

Everything in this section was measured in `huey_v3.blend` on 2026-08-10 and independently
re-verified, not taken from an agent's report. His standing order holds: *"ill tell you when
we export."*

**His rulings this session:** gun stays the **infantry M60 on a BUNGEE mount**, not an M60D ·
**transport flies clean** (no door gunners) · **pax stay on the troop seats** · gunner stool
**"split the difference"** at ~0.30 m above the floor.

| defect found | state now |
|---|---|
| right gunner stool pad floated **152 mm above its own post**; left "stool" was a solid 0.535 m column 115 mm too tall; left gunner raised 92 mm to compensate | one spec both sides, pad z 0.965–1.010, post 0.710–0.965, sockets `seat_gunner_l/r` at (±0.960, 2.384, 1.010) |
| both gunners played `sitting` — a **passenger** clip (the "looks like they are complaining" slouch) | own action `m60_gunner_base_seated`; head-forward-of-hips 0.37 m → 0.06–0.12 m; feet planted 0.707–0.713 vs the 0.710 floor across all 143 frames; `gun_ik` chain 4→**2** so it no longer folds Spine2 |
| pilots' hips sat **0.196 m behind the seat back** | hips y=5.238, mid seat-pan; head clears the seat-back top by 0.177 |
| **the collective was physically unreachable** — modelled at z≈0.91, *below* the 1.02–1.07 seat pan; needed 0.657 m of reach against a 0.559 m arm | assembly raised +0.19 (grip z=1.100), post lengthened 0.710→1.100 with its base still on the floor; both hands now **1.7 mm** from their sockets (was 0.381 m / 0.637 m) |
| rigid pintle post (actually a floor pedestal, z 0.71–1.20) | **bungee mount**: ceiling anchor (±1.30, 2.39, 1.95), 0.646 m elastic cord, + brass/link catch bag. Net **+28 tris**. `traverse` dropped 1.213→1.093 with the gunner |

**Node contract re-verified intact:** `pintle_X_traverse` (yaw) → `GunPivot` (elevation, local X)
→ `m60` → `MuzzlePoint` still **+Y (+0.549)**. Godot rotates traverse/GunPivot at runtime — this
is the live-target "free will" aim. `M60_MG_huey` untouched at 2,212 verts, shared by both pintles.

**DO NOT "fix" the collective asymmetry.** Each collective sits 0.36 m to *its own pilot's left*
(the +0.55 pilot's at +0.19, the −0.55 pilot's at −0.91). Confirmed from an unrelated footage clip.
A mirror pass across x=0 destroys it.

**Open after this pass:** nothing is saved · the six `*_BAKED` gunner clips are stale (baked
before the seat/body/gun/grip moves) and need re-baking before any export · the gun rides
0.15–0.18 below Spine2, a tuning call for his eye · the gunner's head sits at 69% of the door
aperture rather than the footage's midpoint, which is the direct consequence of his
"split the difference" ruling and is **not** a bug to re-open.

**Consequence of "transport flies clean":** `seat_system._scan_sockets` walks an 11-seat contract
and **generates** any missing socket from `FALLBACK_LAYOUT`. A transport with no `seat_gunner_l/r`
will invent two at (±1.15, 1.30, −2.70) — outside the airframe — and `PASSENGER_SEATS:32` uses
them as overflow. Recommendation: keep the two `seat_gunner_*` empties in the transport GLB and
omit only the crew and the pintles.

---

Supersedes the 2026-08-05 close-out. Both open items from that document are CLOSED.
Every number below was measured headlessly on 2026-08-08; nothing here is re-derived
from the 8/5 read.

## What is live

`scenes/vehicles/huey.tscn` now instances **`assets/us/vehicles/huey_v3.glb`**, Model
**unrotated**. `assets/us/vehicles/huey.glb` (v1) is untouched on disk and no longer
wired — the four shipped `heli_*.glb` staged clips still bake v1 geometry, so it stays.

Trunk blend: `assets/us/vehicles/huey_v3.blend`, **114 objects**.

## OPEN #1 — RESOLVED. v3 is the trunk; the doors came across.

Verified by full object-set + per-object transform diff of both files before merging:
the ONLY divergence was the object sets. **Zero common objects differed** in location,
rotation, scale, vertex/poly count, parent, world bounds or materials.

Merged in from `huey_v3_transport.blend` (six objects, not the four the 8/5 read
listed — the rails were missed):

| object | type | tris |
|---|---|---|
| `door_l`, `door_r` | MESH | 12 each |
| `door_rail_l`, `door_rail_r` | MESH | 12 each |
| `door_l_socket`, `door_r_socket` | EMPTY | — |

Four duplicate `huey_hull.00N` materials the append dragged in were remapped onto the
original `huey_hull` and removed.

**`huey_v3_transport.blend` is now a strict subset of the trunk and is DEAD.** Do not
author into it. It is left on disk only until Caleb says to delete it.

## OPEN #2 — the `Cube` / `Cube.001` panels were ALREADY renamed

They are **`cabin_panel_aft_l`** and **`cabin_panel_aft_r`** — same 0.075 × 1.015 × 1.153
boxes, same places (x 0.631–0.706 and −0.794–−0.718, y 1.968–2.983, z 0.699–1.852).
Some pass between 8/5 and now renamed them and the 8/5 doc went stale. They were still
material-less; they now carry `huey_hull`. **They still want Caleb's eye** — the name is
a measured guess from where they sit (aft cabin, inboard of the door frames, floor to
ceiling), not something he ruled.

`REF_Inside1` is **not** drifted either — it measures x −1.230…1.470, overlaid correctly.
That 8/5 warning is also stale.

## THE LANDMINE — defused, and it was bigger than diagnosed

`huey-backwards-run-diagnosis` landmine 3 said: huey.tscn mounts Model flipped 180°, so
real `seat_*` empties would invert every occupant. True, and there was a **second, worse**
fault in the blend itself.

**Convention under test** (name it or it drifts — this repo has three):
- *Vehicle asset law*: nose Blender +Y → Godot −Z, the same forward
  `helicopter.gd:_process_flying` steers with `atan2(-dir.x, -dir.z)`.
- *Seat socket*: occupant faces the socket's local **+Z**, up is local **+Y**
  (`scripts/vehicles/seat_system.gd:9-11`).

**Fault A — the scene flip.** v1's nose was Godot **+Z**, so `huey.tscn` carried
`Transform3D(-1,0,0, 0,1,0, 0,0,-1, …)` on Model to point it down −Z. v3's nose is already
−Z. The flip is **removed**; Model is identity. Left in, it would have negated the X and Z
of every socket basis and seated the whole load backwards.

**Fault B — the seat empties' own rotation, in the blend.** All twelve `seat_*` empties
were authored `rot_euler = (90°, 0, ±90/180)`. Measured empirically by exporting probe
empties to `.gltf` and reading the node quaternions: **an `rx=90` empty exports with Godot
local +Z = (0, −1, 0) — straight DOWN.** Every seated man would have faced the floor lying
on his side. Nothing in the 8/5 read caught this because nothing had exported the sockets
yet. Fix: **zero the X euler on all twelve.** The authored Z euler was already correct.

Proof, in-engine, `res://tools/probe_huey_frame.tscn` (rewritten from the v1-only probe):

```
[SeatSystem] Huey: all 10 seat_* sockets found in the model - fallback table retired
Model.transform = [X: (1,0,0), Y: (0,1,0), Z: (0,0,1), O: (0,0,0)]
fuselage_fwd centre z = -2.785 | fuselage_aft centre z = 3.600      <- nose is -Z
seat_pilot_l    pos=(0.55, 1.125, -5.185)   face=(0,0,-1) up=(0,1,0)
seat_gunner_l   pos=(0.96, 1.13, -2.384)    face=(1,0,0)  up=(0,1,0)
seat_gunner_r   pos=(-0.96, 1.13, -2.384)   face=(-1,0,0) up=(0,1,0)
seat_pax_1..4   face=(1,0,0)   seat_pax_5..7 face=(-1,0,0)
PASS: huey_v3 frame + seat socket contract OK
```

`FALLBACK_LAYOUT` (`seat_system.gd:37-49`) is now dead for the Huey — the probe prints
"fallback table retired". Its coordinates assume nose = −Z with `Door_Left = +X`, which
still describes v3, but nothing reads it any more.

## Measured export — `assets/us/vehicles/huey_v3.glb`, 1.16 MB

Parsed straight out of the GLB in the glTF/Godot frame (no Blender re-import, which would
re-apply the axis conversion and hide the truth): `verify_glb.py`, scratchpad.

| measure | v3 | target / v1 |
|---|---|---|
| nodes / meshes / materials | 110 / 73 / 23 | — |
| tris | 41,364 | v1 = 1,446 |
| baked animations | **0** | v1 shipped 6 rotor tracks |
| full bbox (rotor tip to rotor tip) | 14.630 × 4.410 × 14.215 | main rotor 14.63 ✔ |
| airframe bbox | 2.845 W × 3.003 H × **12.900** L | fuselage 12.77 + tail fin ✔ |
| fuselage alone, nose to tail | **12.770** | 12.77 ✔ exact |
| lowest point | **y = 0.000** | v1 = −0.12 (sunk) |
| origin | on the airframe (fuselage y-symmetric about 0) | v1 ~7.8 m off |
| `New_Blade_1` | FOUND, (0, 4.28, −2.55) | `helicopter.gd:18` |
| `New_TailBlade_2_002` | FOUND, (0, 1.321, 6.535) | `helicopter.gd:19` |
| `Huey_Copy` | **ABSENT — by design** | see below |
| meshes with no material | **none** | 47 were white before this pass |
| `REF_*` nodes | **none** | study overlays excluded from export |

**The recentre band-aid is now inert.** `helicopter.gd`'s `fuselage_node` export default
was `"Huey_Copy"`; it is now `""`, and the recentre block is guarded so an empty string
skips it. **The block is NOT deleted — `chinook.tscn:12` sets `fuselage_node = "Fuselage"`
and still needs it.** For the Huey it is dead.

**Destructible contract: nothing applies, deliberately.** The Huey is instanced from
`huey.tscn` by `air_traffic.gd:15`, never through `site_planner.place_structure`, so
neither `FSB_SOFT_PREFIXES` nor `FSB_STRUCTURE_KINDS` ever sees its mesh names. Giving any
part an `fb_*` prefix would buy nothing and would be a lie in the map.

## Probes run, all green

```
res://tools/probe_huey_frame.tscn   PASS: huey_v3 frame + seat socket contract OK
res://tests/test_seat_system.tscn   PASS: 11-socket contract, clips, stagger, restore
                                          (auto_generated=false — real sockets, first time)
res://tests/test_huey_sim.tscn      PASS: huey flight cycle OK
res://tests/test_air_fleet.tscn     PASS x4: materialises, parented, landed on the pad, departed
res://tests/test_asset_probe.tscn   huey_v3.glb largest=14.63m ok
```

`test_asset_probe` still reports 4 failures — the four `heli_*.glb` staged clips at 67.30 m.
**Pre-existing and out of scope**: those bake v1 geometry and re-staging is ruled to a later
pass (8/5 ruling 2). Untouched.

## STILL NEEDS CALEB — ranked

1. ~~**41,364 tris, and 36,168 of them are guns.**~~ **CLOSED 2026-08-09/10.** The heavy
   10,552-tri `m60_pintle.glb` donor is gone. `pintle_l_m60` / `pintle_r_m60` now share one
   mesh datablock `M60_MG_huey` at **1,180 tris**, 1.098 m, grafted from
   `assets/weapons/world/m60.glb` and matching the FP viewmodel's `M60NEW_*`. Measured in
   his live window 2026-08-10. `rack_m16_1..3` also came down to **754 tris each**.
   **Still open, ruled 2026-08-10:** the mounted gun is the INFANTRY M60 — it carries a
   buttstock (90 verts aft of the trigger) and a pistol grip. A Huey door gun is an **M60D**:
   spade grips, no stock, aircraft ring sight. Caleb ruled *build the M60D by reusing the FP
   gun's parts* rather than modelling new ones. The ring sight built on 8/9 was welded into
   the old mesh and is GONE — it needs rebuilding on the new gun.
2. **`_l` names are on the aircraft's RIGHT.** `pintle_l`, `seat_gunner_l`, `door_l`,
   `door_rail_l`, `door_sill_l` all sit at Godot **+X**, which is starboard when the nose is
   −Z. Internally consistent across the whole file, so nothing is broken today, and
   `seat_system.door_staging_pos()` just stages off that side. But "left door gunner" code
   written later will be wrong. **Rename, or write the inversion down as the convention?**
3. **Doors export CLOSED and nothing slides them.** `door_l`/`door_r` seal the cabin, which
   hides the interior he built. They are separate nodes; sliding aft = translate **Godot +Z**.
   Their sockets `door_l_socket`/`door_r_socket` are both at (0, 0.72, −2.003) — on the
   centreline, coincident, with nothing parented to them, so they are markers only.
   **Open by default, removed entirely (common in-theatre), or wire a slide?**
4. **`cabin_panel_aft_l/r`** — named from measurement, not from his intent. See OPEN #2.
5. **Interior materials.** 47 meshes (floor, both seat groups, skids, cyclics, collectives,
   pedals, console, bench, stools, rack, webbing) had NO material and would have shipped
   **default white**. All now carry `huey_hull` (0.16, 0.19, 0.13 — dark olive) so nothing
   ships white. A real pass wants olive floor / black cushions / canvas straps.
6. **`seat_pax_8` exists in the GLB but the code contract is `seat_pax_1..7`**
   (`seat_system.gd:19-25`). It is found by nothing and simply ignored. Add an 8th pax seat
   to the contract, or delete the empty?
7. **CollisionTable box is 0.5 m short at the tail.** `collision_table.gd:58` is
   `Vector3(3, 3, 12)`; v3 measures 2.845 × 3.003 × 12.90. Near-perfect otherwise (v1 at
   17.46 m badly overflowed it). Not changed — a collision edit needs a playtest.

## ~~THE CREW CLIPS CANNOT REACH THE GAME~~ — DELIVERED 2026-08-10

**Resolved the same day.** Seven clips were carried into `anim_library.blend` with
`tools/sync_clips_into_library.py --bones-only` (the `--bones-only` flag is mandatory for staged
crew actions — their object curves are the man's PLACEMENT in the staging scene and would
teleport every carrier), then re-exported with `tools/export_anim_library.py`.

`assets/shared/anim_library.glb`: **202 → 209 clips**, 17.24 MB. Verified by parsing the GLB —
each new clip carries 123 channels over all 41 bones:

| clip | keys | moving channels | duration |
|---|---|---|---|
| `m60_gunner_idle_l` / `_r` | 96 | 29 | 3.20 s |
| `m60_gunner_scan_l` / `_r` | 120 | 29 | 4.00 s |
| `m60_gunner_fire_l` / `_r` | 48 | 29 | 1.60 s |
| `pilot_flips_switches_overhead` | 90 | 12 | 3.00 s |

The six gunner clips were **re-baked first** against the corrected rig — the previous bakes
predated the seat drop, body re-pose, gun drop and wrist fix. Proof they hold the new pose
independently of the live rig: replayed with all IK/copy-rotation constraints MUTED, they still
give hips 1.066–1.093, feet planted 0.708–0.712 on the 0.710 floor, and support-hand
palm·WORLD_DOWN of 0.964–0.988 (the stale bakes read −0.865).

**`seat_system.gd` now points at the real clip**: `PILOT_CLIP_PANEL` = `pilot_flips_switches_overhead`,
`PILOT_PANEL_S` 4.03 → **3.00**. `tests/test_seat_system.tscn` **PASS** (it caught a stale Godot
import first — the engine served 202 clips until `--import` was forced; re-run it after any
library export). `tests/test_huey_sim.tscn` **PASS**.

**Still a fossil:** the fake `pilot_flips_switches` is now referenced by nothing and should be
deleted from `anim_library.blend` — but that costs another ~9-minute library export, so it is
flagged rather than done.

## The original finding, kept for the record — measured 2026-08-10

Fixing a crew animation inside `huey_v3.blend` changes **nothing in-engine**. The pilot and pax
clips ship from `assets/shared/anim_library.glb` (17.7 MB, 202 animations, 2026-08-05), authored
from `assets/shared/anim_library.blend`. Parsed straight out of the GLB JSON:

| clip | in `huey_v3.blend` | in shipped `anim_library.glb` |
|---|---|---|
| `cockpit_controls`, `cockpit_idle`, `cockpit_dead`, `sitting`, `board_heli`, `disembark_heli*` | yes | **yes** |
| `pilot_flips_switches_overhead` (90 f, 410 fcurves) | **yes** | **NO — stranded** |
| all 18 `m60_gunner_{idle,scan,fire}_{l,r}_*` clips | **yes** | **NO — stranded** |

`huey_v3.blend` is being used as a clip bank, which is exactly what
[[recon-staged-scenes-are-not-clip-banks]] forbids. Every crew clip authored on 8/9–8/10 is
stranded in the vehicle source. **The delivery step is: move them into `anim_library.blend`
and re-export that**, not re-export the Huey.

### `pilot_flips_switches` is a fake, and the game plays it on every touchdown

`seat_system.gd:56` sets `PILOT_CLIP_PANEL := "pilot_flips_switches"` and `:60`
`PILOT_PANEL_S := 4.03`, so on touchdown every Huey runs a 4-second "panel run".
Verified in the shipped GLB (not just the blend): `pilot_flips_switches` and `cockpit_idle`
have **123 channels each pointing at an identical accessor graph** — same samplers, same
input/output accessors, different name only. `cockpit_controls` differs, so the comparison is
sound. **The panel beat has never once been visible in game.**

The real clip was authored — `pilot_flips_switches_overhead`, and today's footage pass confirms
the beat is an **OVERHEAD reach**, not a forward one. It is sitting in `huey_v3.blend` unwired.
Fix is two steps: carry the clip into `anim_library.blend` + re-export, then point
`PILOT_CLIP_PANEL` at it and re-measure `PILOT_PANEL_S` (90 frames, not 4.03 s).
`tools/unit_registry.py:37` also lists `pilot_flips_switches` in `SKIP_ACTIONS`.

## Explicitly NOT done

- **Pilot / gunner / pax animations** — 8/5 ruling 3, and they wait on his eye on the merge.
  Reference pack: `production/research/huey_pilot_motion/NOTES.md`.
- **Re-staging the four `heli_*.glb` clips / four `huey_*_staging.blend` files** — 8/5 ruling 2.
  Untouched. They still bake v1 geometry, which is the only reason `huey.glb` still exists.
- **Exterior detailing** — 8/5 ruling 1.
- **M60 combat wiring** — 8/5 ruling 4, geometry and hierarchy only.

---

## 2026-08-11 — M60 CONSISTENCY + GUNNER REWORK (his rulings, work done in his live window, SAVED)

**His ruling:** *"I WANT THE LOW POLY m60 in the game everywhere it should be... we need consistency."*

### Why it was raised, and the measurement that settled it

The Huey door guns were the ODD ONE OUT, not the heavy ones. Measured 8/11:

| Site | tris before | tris after |
|---|---|---|
| Player FP `m60_fp.glb` | 11,728 | unchanged |
| Ground mounts `m60_pintle.glb` (`mg_emplacement.gd:16`) | 10,652 | unchanged |
| **Huey door guns** | **1,180** | **10,552** |
| **NPC world `assets/weapons/world/m60.glb`** | **1,180** | **10,552** |

The 8/9–8/10 pass had swapped the Huey guns to the 1,180-tri **world/NPC** model — the asset distant
AI carry — on the one weapon the player sits directly behind. `m60_pintle.glb` contains mesh
`Cylinder.004` at **10,552 tris**, byte-identical in name and count to
`D:\Downloads\low-poly-m60\source\m60.blend`, so the "download" was already the shipped ground-mount
gun. **Note: `C:\Users\caleb\Downloads\low-poly-m60` is an EMPTY shell** left by the 8/8 debloat; the
real file lives on the flash drive.

### Done in `huey_v3.blend` (SAVED, 42.44 MB)

- Both door guns on one shared datablock **`M60_lowpoly_huey`** (10,552 tris), scale baked into the
  vertices so object scale stays 1.0 and the marker children do not get dragged.
- **8 stale M60 datablocks deleted** (`m60_belted_v2`, `.001`, `_huey`, `M60_MG_huey` + `.001/.002/.003`,
  and the redundant unscaled import) plus the bench's old-gun object. One M60 mesh remains in the file.
- **Markers re-seated from Caleb's hand-placed bench**, mapped `hand_l -> grip_fore`,
  `hand_r -> grip_trigger`, `muzzle -> MuzzlePoint`. The `traverse -> GunPivot -> m60 -> MuzzlePoint`
  contract Godot drives at runtime is intact.
- **Both gunners hold his bench pose**, hands at **0.0191 m** from their markers (= the 2-bone IK
  residual, identical on the bench).
- **All six `_BAKED` clips re-baked** against the new grips, verified with constraints MUTED:
  min = mean = max = **0.0191 m** across 1,056 samples.
- **Bungee cords re-fitted and re-parented** to `pintle_X_traverse`. Gaps 12-17 mm -> **1-3 mm**, and
  because the ceiling anchor sits on the traverse axis, yaw is exact: unchanged across +/-45 deg.
- Staging `traverse`/`GunPivot` clips cleared off the mounts — Godot drives those at runtime.

### THE TWO MOUNTS ARE A 180 deg YAW, NOT A MIRROR

Measured: `det(GunPivot) = +1.000` both sides, `X_l = -X_r`. So the SAME GunPivot-local transform gives
correctly outboard guns on both sides. **Never run a symmetry pass across x=0 here** — it would destroy
the deliberate collective asymmetry and the `_l`-is-starboard convention.

### MUZZLE END DIFFERS BETWEEN THE TWO MESHES — the trap that nearly shipped

Cross-sections decide it, never the bounding box:
- `M60_lowpoly_huey`: **muzzle at -Y** (15.8 x 18.2 mm) / stock at +Y (44.5 x 31.3 mm)
- old world `m60.glb`: **muzzle at -X** (19.6 mm girth) / stock at +X (131.8 mm)

A naive "furthest vertex along the long axis" put both `MuzzlePoint`s on the **buttstock**, firing
into the cabin. Both are now on the bore exit and verified OUTBOARD of their guns
(`pintle_l` +1.792 vs gun +1.288; `pintle_r` -2.005 vs gun -1.395).

### `assets/weapons/world/m60.glb` REPLACED — needs an in-game look

Exported from the same mesh, rotated so **muzzle = -X** and centred at origin to match the old
convention, node name **`M60_MG`** preserved. 1,180 -> 10,552 tris, 77 KB -> 462 KB.
Backup at `assets/weapons/world/m60.glb.prelowpoly.bak`; revert is a single `cp`.

**RESIDUAL RISK, UNVERIFIED:** NPC hand alignment. The old and new guns have different proportions
(glTF Y 0.326 -> 0.255, Z 0.143 -> 0.246), so a gun centred the same way can still sit slightly wrong
in the hand. `ModelActor` attaches by bare name and there is no grip marker in the world GLB to align
to. **Look at one M60-carrying NPC in game before trusting this.**

### STILL OWED

- **`huey_v3.glb` has NOT been re-exported** — every change above is blend-only until he says export
  (his standing order). The game still flies the pre-8/11 gun.
- Helmet drop is parked at **-20 mm** on all four pilots awaiting his eye; the shipped
  `us_pilot_white.glb` sits 15 cm HIGHER than the blend, so the export has a floating helmet.
- Two pre-existing preview mismatches, unrelated to this work: `cabin_panel_aft_r` off 37 mm,
  `door_rail_l` off **1.300 m** (one of the six objects merged from the dead `huey_v3_transport.blend`).
