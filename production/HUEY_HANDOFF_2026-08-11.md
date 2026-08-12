# HUEY HANDOFF — 2026-08-11

**File: `assets/us/vehicles/huey_v3.blend`, SAVED, 77.0 MB. NOTHING EXPORTED — his standing hold:
*"dont export until i say."* None of the work below is in the game yet.**

Every number here was measured in his live window today. Where a claim was checked and found false,
it says so.

---

## 1 · HIS RULINGS TODAY (these are law now)

| Ruling | His words / substance |
|---|---|
| **The film is the source of truth** | *"the film is the real source of truth since its historical footage so that is what we will defer to in everything."* Source: youtube `43tzd08z2UQ`. Read + contact sheets filed in `production/research/huey_loading/`. |
| **Low-poly M60 everywhere** | *"I WANT THE LOW POLY m60 in the game everywhere it should be... we need consistency."* Done — see [[recon-m60-consistency-decree]]. |
| **Troops ride the floor/lip facing OUTBOARD** | Not the centre bench. Legs over the skid. Per the film and his own 7/29 notes. |
| **Transport flies with NO cargo doors** | Every loaded ship in the footage has the bay wide open. |
| **All six disembark variants survive** | Do not cut to two. |
| **Gunship carries troops too**, same seating minus doors | Required moving the seating into a shared collection. |
| **No more shape/design changes** to the Hueys | Said mid-session after too much churn. |
| **The mocap/contact-sheet workflow stays** | *"we made some great animations from this work flow so we will continue to use it that way."* Read the footage, don't capture it — 640x360 archival is a staging source only. |

---

## 2 · DONE AND VERIFIED

- **M60**: both door guns + the NPC world gun on the 10,552-tri `M60_lowpoly_huey`. 8 stale M60
  datablocks purged. Grips/`MuzzlePoint` re-seated from his hand-placed bench; both muzzles verified
  OUTBOARD. `assets/weapons/world/m60.glb` replaced (backup `m60.glb.prelowpoly.bak`).
- **Six gunner clips re-baked** against the new grips — verified constraints-MUTED, flat **0.0191 m**
  hand-to-grip across 1,056 samples.
- **Bungee cords** re-fitted, re-parented to `pintle_X_traverse`; gaps 12-17 mm -> **1-3 mm**, and
  exact through +/-45 deg yaw because the ceiling anchor sits on the traverse axis.
- **Floors** tapered to fit inside the hull. `floor_cockpit` had **186 mm** of overhang through the
  tapering nose. Now min gap 12.0 / 10.8 mm the whole span, seam matched.
- **Period palette**: `huey_hull` (one flat olive on 67 meshes) split into OD exterior / interior /
  deck / seat olive / cushion / panel black / metal / rotor / webbing. Interior later LIFTED because
  my first values were near-black and you could not see through the canopy.
- **Doors**: all 14 door objects parked+hidden in `DOORS_PARKED` (originals AND the `PV_` preview
  copies — I missed the PV set first time, which is why he still saw doors). Door **frames** are
  restored to the airframe; they are structural.
- **Seating moved to the lip**: `seat_pax_1..8` at **(+/-1.05, y, 0.865)** facing outboard; rows
  y = 4.442 / 3.984 / 3.525 / 3.067; 1-4 at +X, 5-8 at -X. `PV_` sockets synced.
- **Seating shared**: `Center Bench` + `seat_pax_*` + `webbing_strap_*` moved to
  `CABIN_SEATING_SHARED`, so the gunship inherits them. `INT_TRANSPORT` is now empty.
- **CODE — `scripts/vehicles/seat_system.gd`**: `SEAT_NAMES` and `PASSENGER_SEATS` extended to
  **`seat_pax_8`**; `FALLBACK_LAYOUT` rewritten to the lip positions in Godot space
  (`(+/-1.05, 0.865, -y)`, yaw +/-90). This is the only code change today.
- **Pilots**: his own holster placement applied to all four (bone `Hips`, loc ~(-0.111, 0.028,
  0.080), rot (8.2, 2.5, 0.7), scale POSITIVE 1.0) and his helmet placement (bone `Head`,
  loc (-0.0010, -0.0961, 0.0135), rot (-101.47, -5.91, 0.75)).
- **`pilot_flips_switches_overhead` reseated**: hips 4.814 -> **5.238** (his 8/10 mid-pan spec),
  flat across all 90 frames, done by shifting Hips location fcurves so no other channel moved.
- **His arm fix preserved** as action **`pilot_grip_controls_CALEB`** (fake user) + JSON backup
  `assets/us/vehicles/pilot_ARMFIX_caleb_2026-08-11.json`. Auto-key was OFF — it was a volatile
  pose and one frame change would have destroyed it.
- **His skid strut fix**: he reshaped the four struts himself (0.25-0.35 m). Rails/crossmembers
  untouched. All 8 share `huey_od_exterior`.

---

## 3 · BROKEN OR OWED — START HERE

### 3a. THE TWO LIP-SIT CLIPS ARE BROKEN (top item)
`sit_lip_outboard_a` / `_b` put the man **PRONE**, not seated. Two independent measures agree:
body height **0.30 m** and body spanning **1.80 m across X**. A seated man is ~1.2 m tall with a
~0.5 m footprint. They were transplanted from the 7/29 staging in a frame rotated ~90 deg from the
`TR_pax` carriers. I tried correcting by rotating Hips -90 X and the numbers did not move.
**Fix: re-transplant directly from `us_pax_1..6Action` in
`assets/us/vehicles/huey_embark_staging.blend`, bones-only, in the carriers' own frame.**

**`mount_skid_step` and `disembark_heli` are GOOD** — upright, 0.30 m footprint, correct.

### 3b. Five disembark variants not re-authored
`disembark_heli_b/_c/_d/_e/_f` still read as walk-outs. He ruled all six survive.
The base `disembark_heli` WAS diagnosed as **mislabelled** — it travelled 2.2 m *inward* from
outside the aircraft, i.e. an embark clip — and was rebuilt as the skid beat reversed.

### 3c. Wrong grunts on the pax (a LOOK problem, not an animation one)
`TR_pax_1..8` bodies are `us_grunt_joined.001`, 585 v, textured **`recovered_ref_factions`** — a
reference photo, i.e. they came through the lossy game-export path. Nine ruck parts bone-parented
rigidly to `Spine2` float 0.17-0.23 m off the back. **Both are the same root cause**, named in his
own 7/19 rule: *"DO NOT append US grunts from the game-export glbs — gear bone-parent breaks on
join."* Fix = rebuild from `us_base_v3.blend` `SQUAD` (6 loadouts, `PSXRig_<loadout>`, ~45 children
each), applying his Z-FIGHT hide list. **He correctly pointed out this does NOT block the animation
work** — `ModelActor` swaps the body at runtime; the clips live on the PSXRig skeleton.

### 3d. Not started
Period markings (ARMY on the tail boom, serial on the fin, medevac red cross — all seen in the
footage; greenfield: needs a lettering texture, decal quads and a Godot randomiser) ·
`cockpit_dead` has the same 371 mm seating fault as the overhead clip, untouched ·
gunner helmets disagree with each other (`GS_gunner_l` -0.0673 vs `_r` -0.0897 in Y) ·
transport door-open sequencing is moot now the doors are gone.

---

## 4 · TRAPS I HIT TODAY — DO NOT REPEAT THESE

1. **Never join into a shared mesh datablock.** I welded a holster+helmet into `us_grunt_joined`
   while it was shared, contaminating all four pilots' bodies (642 -> 1904 v). Recovered by
   appending the clean mesh from a copy of the saved file. Make it single-user FIRST.
2. **Re-baking a constrained chain**: record `pb.matrix` with constraints live, then write it back
   with constraints MUTED **in hierarchy order parent->child** with an update after each bone.
   Iterating `rig.pose.bones` in storage order solves children against unplaced parents — a hand
   ended up 1.70 m off and four clips were corrupted.
3. **`bpy.data.libraries.load` cannot read the currently-open file.** Copy the .blend aside and
   append from the copy.
4. **Muzzle detection: use cross-sections, never the bounding box.** `M60_lowpoly_huey` has its
   muzzle at **-Y** (15.8 x 18.2 mm) and stock at +Y (44.5 x 31.3 mm); the old world gun had muzzle
   at **-X**. A "furthest vertex along the long axis" heuristic put both `MuzzlePoint`s on the
   BUTTSTOCK, firing into the cabin.
5. **Measure deformed vs deformed.** Comparing a depsgraph-evaluated body to raw (undeformed) gear
   verts produced a fake "25 items floating" report. Evaluate both.
6. **The two door-gun mounts are a 180 deg YAW, not a mirror** (det +1.000 both sides, X_l = -X_r).
   The same GunPivot-local transform gives correctly outboard guns on both sides. Never symmetry-pass.
7. **`PV_` preview copies are separate objects.** Hiding/parking the originals does not hide the
   preview set — that is why he kept seeing doors.
8. **Scene fps was 24 while every clip ships at 30.** Corrected to 30; anything reviewed at 24 is
   25% slow.
9. **Do not stage review clips on his production rigs.** Repeatedly reassigning actions across the
   four pilots (including putting `cockpit_dead` on a flying pilot) is what he meant by
   *"you keep changing things... that dont need to be changed."* Stage on copies.

---

## 5 · SCENE STATE FOR THE NEXT SESSION

Collections: `AIRFRAME_SHARED` · `INT_GUNSHIP` (24: pintles/stools) · `INT_TRANSPORT` (EMPTY) ·
`CABIN_SEATING_SHARED` (12) · `DOORS_PARKED` (10, hidden) · `PREVIEW_SIDE_BY_SIDE` (the transport at
x+18) · `CREW_PREVIEW` · `WB_GUNNER_BENCH` (x-20, his posed gunner bench) ·
`WB_PILOT_BENCH` (x-30, `WBP_pilot` + copilot station, rest pose, 0 constraints).

Staged for review at the transport: pax 1-3 `sit_lip_outboard_a`, pax 4-6 `_b`, pax 7
`mount_skid_step`, pax 8 `disembark_heli`. fps 30, range 1-143. All eight rig objects sit AT their
sockets. **He was looking at the gunship at the origin — the troops are 18 m away.**
