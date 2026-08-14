# RECONgame Blender conventions (project-specific)

Blender-universal lessons live in `~/.claude/architect_knowledge/blender_lessons.md`,
not here. This file is RECONgame's own conventions and asset-specific history.

---

## 2026-08-13 · CRASHED-AIRCRAFT FORM STUDY — read before touching any wreck asset

Gathered before modelling the three wrecks (`a1_skyraider_crashed`, `huey_crashed`,
`f4_phantom_crashed`). Sources: AP news footage of a recovered downed helicopter
(YouTube `8zuRYKMNiZM`), a WWII fighter crash-site walkaround (YouTube `_O5_RDHxPB0`),
NTSB wreckage-examination language, UH-1 tail-boom separation reports, aircraftwrecks.com
F-4D site. Ten observations, each of which changed a modelling decision:

1. **A crashed helicopter is a LOW DARK HEAP, not a helicopter lying down.** In the AP
   footage the wreck barely tops the wheels of the recovery truck beside it — call it
   1.5-2.0 m against a 4.4 m flying height. Cabin roof and greenhouse are down on the
   floor. **Crush the Huey cabin to ~50% height; the boom is the only long straight
   element left.**
2. **A UH-1 tail boom parts at its ATTACH FITTINGS, never mid-boom.** NTSB: the four
   attach points to the aft fuselage bulkhead (upper two are the fatigue pair); in one
   case "a piece of the aft fuselage bulkhead ... approximately 100 feet from the tail
   boom", fuselage inverted, boom at rest ~140 ft away. **Model a clean ring break at the
   fuselage/boom joint with a torn bulkhead ring on the stub.**
3. **Main rotor blades diverge and strike/sever the boom.** Reported boom damage is
   "multiple impact marks and punctures consistent with main rotor blade strikes", boom
   section 135 ft downrange. **One blade snapped short at the hub, one drooping to the
   dirt, and the boom notched where the blade went through.**
4. **A propeller turning under power bends AFT — never forward, never straight.** NTSB
   examination language: "multiple aft bends ... bent aft approximately 45°", "strongly
   twisted toward low pitch", tips "curled with rotational scoring", chordwise scoring.
   A stopped prop stays straight. These are burning fresh crashes, so **every Skyraider
   blade sweeps back ~45° with a second bend and a curled tip.**
5. **Impact ejecta settles on the crater RIM, thickest in the direction of travel,** and
   wreckage scatters concentrated downrange (documented crater 24 ft x 15 ft = 7.3 x 4.6 m).
   **The dirt mound is ASYMMETRIC — a berm heaviest ahead of and beside the airframe —
   never a symmetric dome. A symmetric dome is what makes a wreck read as "plane on a bump".**
6. **The first ground scar sits ~40 ft (12 m) BEHIND the main wreckage.** The wreck lies in
   its own plough furrow with the berm crowding its flanks; nose/engine/inboard leading
   edges are the buried parts and the tail rides highest.
7. **Torn aluminium skin is never a clean plate.** Every surviving panel in the fighter
   walkaround is a crumpled, irregular-edged sheet with visible rivet lines, lying nearly
   flat and half-buried, 0.3-1.2 m across. **Debris = flattish bent sheets, not tidy boxes.**
8. **Fixed-wing failure is at the wing ROOT and leaves a ragged stub.** The separated wing
   keeps its planform (it is a stiff box) and lands largely intact, on edge or inverted.
   **Jitter the cut seam on BOTH halves; keep the thrown wing's shape.**
9. **Jets fragment far more than prop aircraft** — the F-4D site left only turbine blades,
   one piece of fuselage structure and an unburned gear leg, "high speed impact in which
   the fuel vaporizes resulting in a flash fire only". A game prop must not go that far:
   **the readable compromise is the Phantom fuselage in TWO large pieces (nose/cockpit
   snapped off the engine bays), everything else small.**
10. **Fresh burn = soot on metal and bare churned earth. No rust, no overgrowth.** Scorch
    concentrates at the engine and along the wing-root fuel spill and fades aft.

### The three wrecks, as shipped 2026-08-13

Built headless (Blender 5.0.1, `-b --factory-startup`). Never touched a live window.
Pipeline lives beside the assets: **`assets/us/aircraft/build_wrecks.py`** +
**`wrecklib.py`**, re-runnable from an empty scene —
`blender -b --factory-startup -P build_wrecks.py -- a1|huey|f4|all [--norender]`.

| | donor | visual tris | dims X/Y/Z (m) | GLB |
|---|---|---|---|---|
| `a1_skyraider_crashed` | `a1_skyraider.glb` (11,870) | 5,130 | 18.70 / 15.20 / 3.66 | 0.26 MB |
| `huey_crashed` | `huey_v3.glb` (60,354) | 5,960 | 22.02 / 20.89 / 4.16 | 0.51 MB |
| `f4_phantom_crashed` | `f4_phantom.glb` (1,024) | 2,560 | 16.21 / 25.00 / 3.67 | 0.92 MB |

**Naming contract (new prefix pair, and the reason it had to be new).** The
`recon-destructible-export` skill's `FSB_SOFT_PREFIXES` are firebase-only, and the world
path (`place_structure` -> `CollisionTable.is_soft(model_name)`,
`site_planner.gd:164`) tags the WHOLE subtree from ONE per-FILE material — it cannot
express a per-part split at all (that is the skill's own §4 gap). So every mesh AND its
collider carries one of:

* **`wreck_hard_*`** — stops rounds: engine, fuselage/cockpit structure, nose section,
  transmission, floors, mast, exhaust, **and the earth mound**.
* **`wreck_soft_*`** — shoot-through: wings, tail surfaces, boom, doors, skids, rotor and
  propeller blades, intakes, tanks, canopy, panels, ordnance.

Ballistics reads the COLLIDER name and destruction reads the MESH name, so putting the
prefix on both covers both systems with one string. **Code side (not done here, by
instruction): one prefix added to the soft list plus a per-part tagger called from
`place_structure`.** Until that lands these ship uniformly HARD, because
`CollisionTable.MATERIALS["a1_skyraider_crashed"] = Mat.METAL` (`collision_table.gd:298`)
and METAL is not in `SOFT_MATS`.

**Colliders:** `{base}_{i:03d}-colonly` per part — A-1 10 (7 trimesh / 3 box), Huey 32
(26/6), F-4 18 (10/8). Trimesh for the mound (walkable) and for thin plates whose box
hull would be a huge invisible block; box for compact solids.

**Sockets (exact names, verified present after a clean-scene re-import):**
`fire_socket_1..3` + `pilot_anchor` on each. Every fire socket is asserted **within 2.5 m
of wreck geometry** (measured 0.20-1.95 m) — Caleb's ruling is that danger lives inside
the flames only, so a socket out on the approach ground would send the rescue AI into
fire. `pilot_anchor` is swept, not placed by hand: 4-6.5 m off the hull surface, >= 6 m
from every fire socket, on ground measured flat. Results: A-1 6.32 m / 12.07 m,
Huey 6.48 m / 8.83 m, F-4 6.47 m / 10.61 m, all at ground z 0.00.

**Origin/scale:** origin at footprint centre, mound toe at z=0 (that is what
`place_structure` drops onto terrain height), nose = Blender +Y == Godot -Z, **asserted on
the re-imported GLB**, not on the donor.

**COLLISION TABLE IS NOW STALE for all three** (`collision_table.gd:75`) — the A-1 entry
is `box (14.0, 2.6, 12.1)`, `footprint (15.0, 13.5)`, and its own comment admits it was
ESTIMATED, never measured. Measured above-ground heights are 3.19 / 3.21 / 3.23 m and the
footprints are much wider because of the thrown wing and debris. `huey_crashed` and
`f4_phantom_crashed` have **no entry at all**, which means `get_entry` falls back to a
3x2x3 box with a loud warning (`:194`).

**DRIFT CORRECTED:** the brief for this job stated `a1_skyraider.glb` is exported nose-+Z
and wrong. It is **not** — measured on import, the nose sits at +Y (prop mean y +0.778),
i.e. Godot -Z, which is the convention. That was fixed on 2026-08-12 by the facing bake
(see `recon-aircraft-facing-and-scale`); the claim survived past its own repair.

**Mound craft, because it took six passes.** Derived from `bomb_crater.glb`'s mesh and
material, welded and subdivided once (1,536 tris), then sculpted to a plough profile:
flank spoil ridges, a pile ahead of the nose, an open entry furrow behind, and **a slot
along the hull so earth comes up the SIDES rather than closing over the top**. Without
the slot the fuselage measured 60% buried and 0.4 m proud, and the aeroplane vanished;
with it, 0.96-1.20 m of hull stands clear on the A-1. Slopes: median 26-27°, p95 35-39°,
only 4-20 of 1,536 faces over the 45° agent limit — walkable.

**Known and left (needs Caleb or code, not art):** the mound assumes flat ground under it;
`place_structure` does not flatten terrain for this path (`pilot_recovery.gd:99` calls it
directly), so on a slope the mound toe will float or sink on one side. The edges taper to
zero to minimise it.

**The failure mode these exist to prevent:** the superseded `a1_skyraider_crashed.glb`
(2026-08-07) was an INTACT airframe with a full ordnance load still on the pylons, one wing
moved sideways, and no ground at all — 11,862 tris of flying aeroplane. It read as a parked
plane, which is exactly what Caleb rejected. **A wreck is a silhouette problem: crush the
height, break the line, and put earth over the bottom third.**

## Huey (`assets/us/vehicles/huey_v3.blend`, `huey_v3_transport.blend`)

**2026-08-05 - full airframe reshape to match the `Bell Huey.fbx` study.**

- Pinned dims (verified, both files): length 12.77 · half-width 1.310 (2.62 total,
  correct to real UH-1H - the study's 1.439 is ~10% wide, deliberately NOT matched) ·
  lowest z 0.000 · main rotor 14.63 · tail rotor 2.59 · nose = +Y, boom = -Y.
- **Study overlay contract:** `REF_Bell_Huey`, `REF_Top_Rotor`, `REF_Back_Rotor`,
  `REF_Inside1` live ONLY in `huey_v3.blend`, `display_type='WIRE'`,
  `hide_render=True`, x centred on 0, nose-aligned to our fuselage (y=6.385),
  lowest z 0.000. A prior pass had them parked at x≈+12 (beside, not overlaid) -
  re-check this position on any resave, it silently drifts if a script re-imports.
  Never merge, copy, or ship this geometry.
- **Roofline:** single continuous loft (`fuselage_fwd` nose-to-y=-0.815,
  `fuselage_aft` = the preserved boom, y<=-0.815 unchanged) sampled directly off
  `REF_Bell_Huey` via per-station raycasts (roof = topmost hit straight down,
  belly = bottommost hit straight up, half-width = farthest horizontal hit,
  scaled by `1.310/measured_max_hw`). Roof holds 2.45-2.73 continuous, no dome -
  **3.198 is the tail FIN, not the fuselage top; do not build the body to it.**
  A small mast fairing (cone, ~0.24 m tall) sits on the roof peak - that is the
  only place "ours" is meant to exceed the study's line.
- **Cargo doors:** cut with a Boolean DIFFERENCE box that spans the FULL fuselage
  width in X (must exit the solid on both sides or it leaves a spurious cap -
  see the Blender-universal ledger) at y 1.995-4.335, z 0.65-1.99. Belly at that
  Y-range sampled ~0.32-0.43 - well clear of the door's z0, so the door does not
  clip the belly. `door_frame_l/r` in both files already matched this footprint.
- **Rotor node contract (owned by `scripts/vehicles/helicopter.gd`):**
  `main_rotor_node` default `"New_Blade_1"`, `tail_rotor_node` default
  `"New_TailBlade_2_002"` - `find_child()` by that literal name, then
  `rotate_y`/`rotate_x` in code every frame. Built ours to match those defaults
  exactly (empty pivot on the mast/shaft axis, parenting the blade + hub +
  flybar meshes) so `huey.tscn` needs no export string changes. Never bake a
  spin AnimationPlayer - the code comment says it fights the imported one.
  Blade droop: 4 degrees, a rest-pose bend applied to blade mesh verts only
  (never on the pivot/spin node).
- **Tri budget:** airframe alone (fuselage+tail fin+elevator+fairing+both
  rotors), reported separately from interior/guns - measured 3360 tris both
  files, well under the ~10k soft ceiling.
- Interior (seats, benches, racks, floor, transmission bulkhead/hump, skids,
  pintles) untouched in this pass - do not reshape it without a fresh War Room
  ruling; it was declared final ("shape correct Huey with blade animations that
  fits around the declared interior").

## 2026-08-06 · VC/NVA gear variant library (headgear + packs)

New file `assets/nva_vc/props/nva_vc_gear_variants.blend` + exported GLBs in
`assets/nva_vc/props/headgear/` and `assets/nva_vc/props/packs/`, manifest
`assets/nva_vc/props/nva_vc_gear.json`. Built by editing donors only (no
procedural geometry): `pith_helmet` (nva_rifleman.glb) tightened by a uniform
k=0.60 scale (measured brim-to-skull clearance -> ~0, matching the M1's own
measured min clearance of 0.0002 m), band transplanted from
`helmet_plain_band` (m1_plain.glb) and radius-scaled 0.90 to the pith's rim.
`rice_hat` tightened more gently (k=0.85 - a real nón lá sits with an
intentional air gap, not helmet-tight). Packs are the `gear_armory.blend`
ruck kit (`ruck_body`/`flap`/`pocket_0-2`/`frame_l-r-bar`/`buckle_l-r`),
recentred by translation onto `mixamorig:Spine1`, placed ~2 cm clear of
`grunt_torso`'s own back surface (measured, not eyeballed - a first attempt
put the pack on the CHEST because "+Y = front" was assumed from mesh volume,
not confirmed by render; see the universal ledger entry).

**Socket contract chosen: IDENTITY**, not the US helmets.json's non-identity
rotation. Every headgear/pack mesh here is authored with vertices expressed
directly in `(rig.matrix_world @ bone.matrix).inverted()` space, so a plain
BoneAttachment3D with zero extra transform reproduces the fitted position.
This is NOT bit-compatible with `assets/us/props/helmets/helmets.json`'s
socket matrix - do not copy one convention onto the other's asset family.

**Known gap - packs are not yet wired to `vc_nva_dresser.gd`.** Its
`GEAR_TOGGLES` only toggles visibility of meshes already welded into the body
(substring match on `pack_worn`/`pack_roll`); there is no `_rehang_pack()`
mirroring `_rehang_headgear()`. This library's meshes carry the right
substrings but need that function written before they reach runtime.

**Two variants explicitly NOT built, reported instead of generated:**
`pith_net` (no US helmet net mesh exists anywhere in the project - checked
`helmets.json`'s parts lists and grepped the whole `assets/us` tree) and
`pack_rice_tube` (no donor, no reference supplied).

## 2026-08-07 (later same day) · VC/NVA gear batch 3 - band/strap defect,
## texture root cause, pack_rpg placement, foliage rebuild

Headless only, on `nva_vc_gear_variants.blend`, same discipline as batch 2 -
`nva_vc_soldiers.blend` stayed open in Caleb's live window the whole
session, never touched, never opened via any bridge. Scripts:
`tools/fix_nva_gear_bands.py`, `tools/fix_nva_gear_textures.py`,
`tools/fix_pack_rpg.py`, `tools/build_nva_gear_foliage.py` (all four
re-runnable from an empty starting point per the pipeline law).
**`pith_plain/faded/worn/star`'s DOME geometry, `rice_hat_plain`,
`rice_hat_frayed` and `pack_rice_tube` were RULED APPROVED and never
touched in this pass** - only their bands (a different mesh) and, for the
packs, a shared material were in scope.

**Strap-reading-as-broken-geometry, found and fixed.** Every pith/cap
`*_band` object (`pith_plain_band`/`pith_faded_band`/`pith_worn_band`/
`pith_star_band`/`pith_net_band`/`cap_cloth_band`/`pith_foliage_band` - 7
objects, the last one missed on the first pass and caught by re-checking
the rebuild's own numbers) was a 338-vert disordered triangle fan. Its
bounding box looked plausible by range comparison alone; a SIDE-ON render
was what showed the real shape - a vertical hoop crossing the crown front-
to-back, not a horizontal ring at the base. **Bounding-box comparison is
not enough to validate a ring's orientation - render it from the side.**
Rebuilt each as a proper 20-tri ring hugging the dome's own 10-point
fluted base rim (derived from the dome's OWN lowest two distinct Y rings,
not resampled into a plain circle), offset ~4mm out / 1cm down. Net tri
change per prop: -120 (was riding on 140 wasted tris). One dome
(`cap_cloth`) has a shorter crown with a different rim-ring height
(+0.0094m vs the pith family's +0.0115m) - a hardcoded offset produced a
**0-face band silently** on the first pass; fixed by deriving the second
ring height from the mesh's own two lowest distinct Y values instead of a
constant, and the fix is in the reusable function, not a one-off patch.

**Texture root cause, systemic not per-prop.** `pack_canvas` material -
shared by 9 unrelated props (`pack_ammo`/`pack_frame`/`pack_roll`/
`pack_rpg`/`pack_ruck_full`/`pack_ruck_light`/`pack_satchel`/
`chest_rig_ak`/`bandolier_ammo`) - had its Base Color Image Texture node
wired to `pith_worn_cover.png`, the PITH HELMET's own cover sheet.
`chest_rig_worn` had the same root defect by a different path (pointed
directly at the `pith_worn_cover` MATERIAL). **Not a UV problem** - a
wrong SOURCE IMAGE on a shared material, which is exactly why it read
identically across 9+1 unrelated props at once instead of looking like 10
separate mistakes. Repointed `pack_canvas` to `canvas_od` (the same real
canvas sheet the APPROVED `pack_rice_tube`'s `webbing_canvas` material
already used correctly - the working pattern was sitting right next to the
broken one the whole time). Gave `chest_rig_worn` its own material
(`chest_rig_worn_cover`: `canvas_od` + a darker tint) instead of a
wholesale borrow. Also repointed `pith_band_cover` (all 7 bands, above)
off the same pith cover PNG onto a flat dark vinyl/leather colour - a
helmet trim band is a different material from the dome fabric and didn't
need a bespoke image at this size.

**`pack_rpg` was not an outlier, it was disconnected.** The 520-tri count
looked like a budget problem in the manifest; measuring the ACTUAL
geometry found the launcher tube (`BluedSteelVC.001`, 208 tris) and PG-7V
warhead (`WarheadOD`, 264 tris) sitting **~2 metres away in Z** from their
own canvas sling (`pack_canvas`, 48 tris) in the same object's local
space - a rendering framing artifact made this look like "the steel parts
just aren't visible" rather than "they are two metres off-screen" until
per-material vertex bounding boxes were dumped. Rigidly repositioned the
gun cluster onto the sling (no reshaping) using a small numeric SWEEP over
placement offsets against a `closest_point_on_mesh` fit-check (the same
technique that placed the RPG cleanly also applies to any future
"two chunks that look unrelated" prop - sweep offsets and measure, don't
eyeball one placement and call it done). Once joined, the 520-tri count is
judged proportionate (a tube + conical warhead is a materially more complex
form than a canvas rucksack) and was left alone.

**Foliage rebuilt from the project's own vegetation library, not
procedurally.** `pith_foliage`'s old crown (3 flat ~12-tri quad "leaves")
replaced with 6 sprigs SAMPLED from `assets/world/vegetation/` (READ-ONLY -
imported into memory, never edited, never re-exported): a random
contiguous 16-26 face patch is cut from each source plant's own mesh (a
real branch-tip cluster, not a procedural stand-in), recentred, and scaled
to a fixed target diagonal size rather than an arbitrary multiplier (two
different source patches can have wildly different raw sizes - normalising
to a target size, not a multiplier, is the fix that actually made them
visible; the first two placement passes used raw multipliers on unknown
source sizes and the sprigs rendered as near-invisible specks).
Two NEW pack variants for the same reason (Caleb: "decorate backpacks and
helmets with them"): `pack_frame_foliage`, `pack_ruck_light_foliage`, base
pack mesh unchanged + 3 sprigs each. All placements were tuned by
SWEEPING body-clearance samples across the pack's own local Y/Z range
first (clearance is worst near the neck/shoulder curve, best low on the
back) rather than guessed - the first two placement attempts (guessed)
produced WORSE fit-check numbers than the original broken RPG placement,
in one case; a coordinate axis's "outward" direction is not intuitable
from its bounding-box range alone, sample it.
**Honest limitation, not fixed this pass:** the sampled patches from
`bush_a/b/c_low.glb` read as thin blade/frond slivers rather than a full
leafy clump at gameplay-camera distance - a bushier read needs denser
source geometry or a bigger tri spend per sprig than was justified here.

## 2026-08-07 · VC/NVA gear batch 2 - both gaps closed, new `chest` category

Built headless via `tools/build_nva_gear_batch2.py` on
`assets/nva_vc/props/nva_vc_gear_variants.blend` ONLY - a live Blender window
had `nva_vc_soldiers.blend` open the whole session; never touched, never
opened via any bridge. Blender 5.0 at
`C:\Program Files\Blender Foundation\Blender 5.0\blender.exe` (headless
`-b --factory-startup -P <script>` - no MCP).

**`pith_net` gap closed.** Reference (enemymilitaria.com, IMA-USA NVA pith
helmet listings) is unanimous: these were a hard shell covered in a **green
oilcloth net/scrim**, homemade wartime construction - a SHELL glued or tied
over the dome, never a knotted cord net. Built as pith_worn's own dome+band
(duplicated verbatim - already correctly fitted, zero new placement risk) +
a second shell offset 6mm outward along the dome's own vertex normals,
textured with a procedural alpha diamond-lattice so the helmet colour shows
through the gaps, + 6 loose rim tabs for the "cloth petal" silhouette break
the references describe. 292 tris / 662 verts across 4 parts.

**`pack_rice_tube` gap closed.** No reference was ever supplied and none was
needed - WebSearch found ample photographic/dimensional reference in one
pass (enemymilitaria.com): ~5.5 ft (1.68 m) long, ~5 in (0.127 m) diameter
cotton tube of dried rice, issued per soldier, worn bandolier-style. Built as
one continuous tapered/pinched tube ("sausage link" ties) looped over the
right shoulder and down the back, tied-off coil at the hip. **Do not wait on
"no reference supplied" for an iconic period item - WebSearch a specific
noun phrase (here: the collector-market name for the object) before
reporting a gap.**

**NEW `socket_chest` (mixamorig:Spine2).** A `Chest` EMPTY already sat on
this exact bone in the file (local Y=-0.130) - a leftover from an earlier
pass, unused by anything, and it told me where chest-worn gear belongs
before I had to derive it. Added `chest_rig_ak` (3+2 pouch AK/SKS mag rig,
reference: mooremilitaria.com / AWM C153520 / phillosoph.blogspot.com),
`chest_rig_worn` (same mesh, weathered texture - the pith family's
plain/faded/worn/star trick applied to a new item), and `bandolier_ammo`
(10-pocket cartridge bandolier, reference: vietnam-surplus.com /
cartridgecollectors.org - opposite diagonal from the chest rig for variety).

**Socket convention, reused not reinvented:** every new mesh's vertices are
baked into the bone's local space via
`(rig.matrix_world @ pose_bone.matrix).inverted() @ world_vertex`, matching
batch 1 exactly. **Verified before building anything**, not assumed: forward-
transformed the EXISTING `pack_worn_ruck_light` and `pith_worn` vertices
through this same matrix and confirmed they land in plausible world
positions (pack on the back at Y=0.06-0.26 against a measured back surface
of Y=0.10 at that height; helmet above the measured head position). This
caught nothing wrong here, but it is the cheap insurance the 2026-08-06
"+Y=front" mis-placement (see the batch-1 entry above) should have had from
the start.

**Fit-checked quantitatively, not eyeballed** (`find_nearest` against
`vc_guerilla_joined`, penetration = `(vert - nearest).dot(normal) < 0`):
`chest_rig_ak` 0/120 verts inside the body; `bandolier_ammo` 14/92 touch
within 6mm (neckline contact, negligible); `pack_rice_tube` first pass had
47/184 verts up to 6.7cm inside at the shoulder curve and hip - the
diagonal path's straight tube segments cut the corner across the rounded
shoulder joint. **Two rounds of nudging the path waypoints outward** (not a
blind clearance bump - each round re-ran the same numeric check and reported
the worst-offending world coordinate first, so the fix targeted the actual
joint rather than guessing) got it to 26/184 within 1.8cm, max 1.84cm -
plausible soft-cloth resting contact, not clipping.

**Idempotency bug caught and fixed on this project's own pipeline law:** the
first build script had no cleanup step. A second run (after tuning the rice
tube's path) silently renamed every new object to `.001` and left the STALE
first-pass geometry in the file under the real names - the verification
script then measured the OLD geometry and reported no improvement, because
it was reading the wrong objects. Fixed by adding `purge_prior_batch2()` to
the top of `main()` (removes every named batch-2 object/material/image, then
`bpy.data.orphans_purge()` twice to catch mesh data `new_from_object()` names
after its SOURCE, not the new object). The script is now safely re-runnable
from the file batch 1 left behind, per the project's pipeline law.

**Visual verification note:** Workbench `MATERIAL` shading renders new
materials in a flat DEFAULT GREY indistinguishable from the body unless a
distinct `material.diffuse_color` is set first - a placement render that
"shows nothing new" is not evidence of a missing object, check object count
and world bbox before concluding that.

---

## 2026-08-08 · US pilots: gib contract completed, and how the pilot line is actually built

**Source of truth for BOTH pilots is `assets/us/characters/us_base_v3.blend`**, not the
94 MB `us_pilot_white.blend` / `us_pilot_black.blend` (2026-07-12, stale fossils — nothing
exports from them; do not open them expecting current work).

- `us_pilot_white` <- rig **`PSXRig_pointman.001`** (x=10.459), a whole-unit duplicate of the
  pointman made when the original `us_pilot_body` bind was destroyed. Its body is HEALTHY:
  263 v, raw dims 1.611 x 0.265 x 1.800, per-index vertex hash `114757d248d3` — **identical to
  every other body in the file**. The pancake described in memory `us-pilot-body-broken-bind`
  is gone; that object no longer exists and `PSXRig_pilot` is not in the file.
- `us_pilot_black` <- rig **`PSXRig_pilot_black`** (x=15.0). Same body hash.
- Both pilot rigs carry only **2 of 41 posed bones** (siblings carry 34). Harmless *for export*
  — `export_pilots_medics.py` forces `pose_position='REST'` on every unit — but they read as
  T-pose-only in the studio file. Not "fixed": the file is deliberately parked in T-pose.

**What was wrong (measured, 2026-08-08):** `PSXRig_pointman.001` carried **no split gib donors
at all** and exactly one cap, `cap_head_pilot`, whose `matrix_parent_inverse` cancelled the
rig's X and parked it at world x=0 — **10.46 m off the man**. `us_pilot_white.glb` therefore
shipped 0/5 `grunt_<region>` and 1/5 `cap_<region>`: that man could not lose a limb.

**The repair, and where it lives.** `us_base_v3.blend` is READ ONLY, so the graft happens
inside the export session, in `tools/export_pilots_medics.py`:
- `GIB_DONOR_RIG = {"us_pilot_white": "PSXRig_pointman"}` — object-level copies of all 16
  contract pieces, parent-inverse and local matrix carried over from the donor, armature
  modifier repointed. No vertex coordinate is written. Justified because every donor mesh in
  this lineup is **bit-identical per-index across all five rigs** (hashes above).
- Grafted copies are named `<part>_GRAFT`, with `_GRAFT` added to `SUFFIXES`. Naming them
  bare collides with the stock `PSXRig`'s own bare `grunt_*`, and Blender silently mints
  `grunt_forearm_l.001` — which the exporter's collision guard then aborts on.
- Graft gate: each piece's **rig-relative** centre must match the donor's to 1e-4 m. Do NOT
  gate on distance from the rig centre — a T-pose forearm sits 0.60 m out legitimately.
- `build_head_frags()` now runs for these five units too (it did not before): pilots, medics
  and surgeon all shipped `head_frag x0`, so `dismember_head_burst()` returned false and none
  of them could lose a head.
- **Face atlas sync**: the split `grunt_head` keeps whatever atlas it was cut with, and the
  black variants were cut from the white line — `us_pilot_black` and `us_medic_black` both had
  `face_atlas_mat` on the severed head while their bodies used `face_atlas_black_mat`. Measured
  at the head donor's UV island u[0.004..0.097] v[0.005..0.144]: `face_atlas_v5` mean RGB
  (0.404,0.279,0.194) vs `face_atlas_v5_black` (0.172,0.099,0.067) — same 1296x1132 layout,
  2.3x darker. The exporter now repoints the head donor to the joined body's atlas, generically,
  **before** `build_head_frags` (which copies the head's mesh data, materials and all).
- `ALIAS = {"belt_holster_pilot_NEW": "belt_holster"}` — no SUFFIX rule could canonicalise it,
  so white shipped `belt_holster_pilot_NEW` while black shipped `belt_holster`.

**Run one unit at a time:** `blender -b -P tools/export_pilots_medics.py -- us_pilot_white`.

**Known, NOT fixed, needs Caleb:**
- **Gibbed pilot limbs read as jungle fatigue, not flight suit.** The split donors use
  `us_grunt_mat` (`ref_factions`, 3600x5700) while the joined pilot body uses `us_pilot_mat`
  (`pilot_kit_sheet`). This is not a material repoint: the joined pilot body was **re-unwrapped**
  for the flight suit (UV hash `dd3fbf661a77` vs the grunt's `feaf111934c2`), while the split
  pieces still carry the grunt UVs. Fixing it means transplanting UVs, not swapping a material.
  Pre-existing on `us_pilot_black` since 2026-08-04.
- That same `us_grunt_mat` dependency is why `us_pilot_white.glb` went 5.4 -> 14.1 MB: the
  donors drag in the 3600x5700 grunt atlas. The rest of the US cast already pays this.
- **Loadout asymmetry:** white wears full webbing (`web_*` x12, bandolier); black wears none.
  Both wear `helmet_sph4`, `belt_holster`, `m1911_world`.
- `m1911_world` sits 0.758 m off centreline at hip height on BOTH pilots — identical on both,
  so not a regression, but it is not in the holster either. Per
  `pilot-holster-pistol-never-hides` the holster is a closed pouch and the pistol never hides.
