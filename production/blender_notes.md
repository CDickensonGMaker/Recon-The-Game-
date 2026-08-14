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

### The three wrecks, as shipped 2026-08-14 (fix pass; supersedes the 08-13 figures)

Built headless (Blender 5.0.1, `-b --factory-startup`). Never touched a live window.
Pipeline lives beside the assets: **`assets/us/aircraft/build_wrecks.py`** +
**`wrecklib.py`**, re-runnable from an empty scene —
`blender -b --factory-startup -P build_wrecks.py -- a1|huey|f4|all [--norender] [--dry] [--tag=X]`.
**`--dry` writes the .blend/.glb into the render directory instead of over the shipped
asset**, so a change is judged from its renders before anything ships; `--tag` suffixes the
render filenames so the new pass sits beside the one it is being judged against. Use both.

| | donor | visual tris | dims X/Y/Z (m) | GLB |
|---|---|---|---|---|
| `a1_skyraider_crashed` | `a1_skyraider.glb` (11,870) | 5,130 | 18.70 / 15.20 / 3.41 | 0.27 MB |
| `huey_crashed` | `huey_v3.glb` (60,354) | 5,976 | 20.01 / 19.95 / 4.16 | 0.53 MB |
| `f4_phantom_crashed` | `f4_phantom.glb` (1,024) | 2,560 | 16.07 / 25.00 / 3.06 | 0.40 MB |

**2026-08-14 fix pass — what changed and why (Caleb's verdicts: A-1 SOLID, F-4 DECENT,
HUEY FAILS).**

* **Thrown flat pieces stood ON END.** A door and a rotor blade shipped as sign-boards at
  the edge of the scatter while every seating number read healthy — clearance measures
  CONTACT and is blind to orientation. New `wrecklib` primitives do the surgery and the
  proof: `principal_axes` / `plate_tilt` (angle of the thin axis from +Z), `lay_flat`,
  `bend_mid(toward=)`, `place_at`, `cut_at`, and the gate `assert_lying_flat`, which is
  wired into `finish(flat_debris=...)` and **fails the build**. Measured now: door 3.8°,
  rotor fragment 5.5°, thrown blade 3.3°, all against a 25° limit, contact 50-74%.
* **`split_faces` cannot cut a low-poly part mid-span, and it fails silently.** A rotor
  blade is one six-face box over 7.3 m, so every long face has its centre at mid-span:
  asking for a 3.9 m stub returned a 7.79 m stub AND a 7.23 m fragment. `cut_at` does a
  real `bisect_plane`. Ref obs 3's "one blade snapped short at the hub" is now actually
  built: a 3.9 m drooping stub plus a separated fragment lying in the dirt.
* **The Huey mound read as a donut ring.** Flank ridges carried full height the whole
  length and closed behind the tail. `build_mound` gained `ridge_rear` / `ridge_fwd` /
  `rear_fade` so they die out aft. Measured: the rear 40° of rim now carries ZERO berm.
* **All three mounds read round.** `lobes` (bearing harmonics on the taper radius) and
  `rim_noise` (a toe that only ever pulls inward, so the taper can never end in a cliff)
  plus `rim_report`, which normalises radius by the FITTED ELLIPSE and counts bulges —
  raw min/max scores a 5.2 x 7.2 ellipse at 0.72 and passes it. Applied to all three; the
  A-1 and F-4 got light values only, and the A-1 was proven pixel-identical first.
* **THE HUEY MOUND MUST STAY UNDER THE WRECK'S OWN HEIGHT.** The A-1 and Phantom are long
  airframes that cover their own scar. A crushed Huey cabin is 1.5 m of low dark heap, so
  a 1.9 m ejecta pile simply stood in front of it and the dirt became the subject. Its
  berm is 0.92 with `nose_gain` 1.05; do not raise it to match the other two.
* **F-4 "intake sparkle" was the CANOPY.** `F4_Canopy_Glass.003` ships
  `Transmission 0.9 / Alpha 0.35` on a `BLENDED` material — refraction fireflies at 28
  samples, and a see-through canopy shipping into a PSX scene. Replaced with an opaque
  crazed material. Checked and ruled out first: gloss (flattened, speckle persisted) and
  z-fighting (zero surfaces within 1.5 mm across every pair).
* **F-4 loose fin.** The tail group was left out of the fuselage crush and buckle, so the
  fin's root stood clear of the spine it is bolted to, and `rigid()` then leaned it about
  its own CENTROID. It now rides the crush and pivots about its ROOT. Same defect fixed on
  the Huey's exhaust stack, which was hanging 1.6 m over the ground behind the cabin.
* **`matte()`** flattens metallic/roughness/transmission to diffuse. Two traps it exists to
  handle: a LINKED input ignores `default_value` (cut the link), and zeroing Metallic turns
  a metal's SPECULAR albedo into a diffuse one, so base colour is scaled 0.45 or the part
  ends up brighter than the gloss removed. Called for the F-4 only. **The A-1's `A1_Spinner`
  (0.9) and `Napalm_Aluminum` (0.85) and the Huey's `huey_metal` (0.75) still carry high
  metallic** — untouched deliberately, because the A-1 was signed off and no sparkle was
  visible on either. Apply the same call if it shows in Godot.
* **Side effect to know about:** `matte()` cuts the F-4's metallic/roughness MAP, so
  `f4_phantom_crashed.glb` no longer embeds `tmpxc1gk1yi.png` (0.92 -> 0.40 MB). The
  previously extracted `f4_phantom_crashed_tmpxc1gk1yi.png` + `.import` in this folder are
  now **orphans** — Godot re-extracts on import and will not reference them again.

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

**Colliders:** `{base}_{i:03d}-colonly` per part — A-1 10 (7 trimesh / 3 box), Huey 33
(27/6), F-4 18 (10/8). Trimesh for the mound (walkable) and for thin plates whose box
hull would be a huge invisible block; box for compact solids.

**Sockets (exact names, verified present after a clean-scene re-import):**
`fire_socket_1..3` + `pilot_anchor` on each. Every fire socket is asserted **within 2.5 m
of wreck geometry** (measured 0.20-1.95 m) — Caleb's ruling is that danger lives inside
the flames only, so a socket out on the approach ground would send the rescue AI into
fire. `pilot_anchor` is swept, not placed by hand: 4-6.5 m off the hull surface, >= 6 m
from every fire socket, on ground measured flat. Results (re-measured 2026-08-14, unchanged
by the fix pass): A-1 6.32 m / 12.07 m, Huey 6.48 m / 8.83 m, F-4 6.47 m / 10.61 m, all at
ground z 0.00. Fire-socket range to nearest wreck surface now 0.20-2.04 m.

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

---

## 2026-08-14 · Crashed-aircraft wrecks: the debris gate is now DERIVED, and what it found

`assets/us/aircraft/build_wrecks.py` + `wrecklib.py`. Huey rebuilt and re-exported;
**A-1 and F-4 not touched** (their `.glb` verified byte-identical by md5 afterwards).

**What was wrong.** `finish(flat_debris=...)` took a hand-typed list of three names.
The Huey scene exports **32 pieces**. Everything outside those three names was
unmeasured, and the pass was signed off on renders that still showed a plank on end.

**The replacement: `wrecklib.assert_debris_grounded()`** (`wrecklib.py`, after
`assert_lying_flat`). It enumerates every exported non-collider mesh except the mound,
clusters them by real surface contact (`touch_clusters`, AABB reject then
`closest_point_on_mesh` ≤ 0.30 m), and judges each piece by what is holding it up:

| classification | rule |
|---|---|
| any cluster | must reach the ground (min clearance ≤ 0.10 m) or it is FLOATING |
| lone piece | plate must lie ≤ 25° from flat · ≥ 25% of verts within 0.10 m of ground |
| lone piece, aspect ≥ 6 | plan heading must clear every render azimuth by ≥ 22° |
| member of a grounded assembly | exempt from tilt — a tail fin at 76° is bolted to a boom |

Huey clusters came out **[22, 7, 1, 1, 1]** — the hulk, the boom assembly, and exactly the
three thrown pieces. The classification is correct and nothing named it.

**THE DEFECT THE TILT NUMBER COULD NOT SEE.** `wreck_soft_rotor_thrown` and
`wreck_soft_rotor_frag` measured **3.3° and 5.5°** from flat with bbox heights of 0.45 m
and 0.40 m — provably on the ground — while their plan headings were **52.0° and 37.4°**
against the threequarter camera's **azimuth 40°**. A flat 7 m blade viewed down its own
long axis projects to a vertical bar. Renders `huey_v2_*` were read as showing a standing
plank and that reading was fair. Fixed by re-heading the throws to **120° and 65°**, the
only headings clear of all four render azimuths (0/40/90/150) by ≥ 25°. Camera angles now
live in one place, `wrecklib.VIEWS` / `VIEW_AZ`, read by both `render_views()` and the gate.

Also: `wreck_soft_door_thrown` residual tilt 4.0° → 2.0° and bury 0.05 → 0.09 m;
contact **74% → 90%**, clearance now −0.09..0.17 m (was −0.05..0.26, and 0.26 m of daylight
under a 2.5 m panel reads as hovering).

**`verify_roundtrip()` now asserts the export contract on the re-imported GLB**, not just
the socket names: every mesh AND collider carries a `wreck_hard_`/`wreck_soft_` prefix ·
each `fire_socket_*` ≤ 2.5 m from wreck geometry · `pilot_anchor` 4–7 m off the hull in plan
and ≥ 8 m from every fire socket. All three wrecks passed as shipped, so the asserts are safe.

### OPEN — found by the new gate, deliberately NOT fixed (out of scope: do not touch A-1/F-4)

Both are run in **report-only** mode (`debris_gate="report"`, the default) so their builds
still complete; the Huey is `"strict"`. Flip them when those wrecks are next rebuilt, and
delete `assert_lying_flat()` at that point — it is retained ONLY for these two.

- **F-4 `wreck_soft_pylon_l` is FLOATING** — a cluster of one, lowest point **0.15 m above
  the ground**, 90° tilt, 0% contact. It is in the shipped `f4_phantom_crashed.glb`.
- **F-4 `wreck_soft_tailfin`** — a lone 2.9 m plate at **88.7°**, 25% contact: planted like a
  signpost. The code comment claims it was leaned about its root to stay against the spine;
  the clustering says it touches nothing.
- **F-4 `wreck_soft_gunpod`** — 12% contact, and heading 69° is only 21° off a render azimuth.
- **F-4 `wreck_hard_nose`** — 5% contact, clearance 2.62 m at its high end.
- **A-1** — all four thrown pieces are low-contact: `wing_thrown` **1%**, `canopy` 11%,
  `panel_1` 21%, `ord_mk82` 22%. `panel_1` also sits at 56.7°.

---

## 2026-08-14 · A-1 Skyraider reference study (before modelling `a1_skyraider_v2`)

Sources, all Wikimedia Commons, each read for a specific angle:
- `20180512_A-1H_Skyraider_Dyess_AFB_Air_Show_2018_4.jpg` — **left side, on the ground, USAF SEA camo**
  ("Wiley Coyote", AF 39606). The master profile: cowl-vs-fuselage depth, canopy step, fin planform.
- `..._2018_6.jpg` — **head-on, taxiing.** Cowl diameter vs fuselage width, wing crank, gear track.
- `..._2018_1.jpg` — **in flight, low side-3/4 from below.** Outer-panel dihedral, stab planform.
- `Douglas_A-1_Skyraider_(19888890798).jpg` — **underside 3/4, SEA camo, "6T 509".** Wing planform,
  grey belly demarcation, pylon row.
- `Douglas_A-1_Skyraider_(20082405451).jpg` — "NAKED FANNY", **fully loaded underside.** The 15-station
  pylon row, centreline tank, MERs.
- `Douglas_A-1J_Skyraider_at_the_Royal_Thai_Air_Force_Museum_in_2012.jpg` — **static left profile**,
  wings folded down, camo demarcation readable.
- `Douglas_A-1J_Skyraider_of_the_6th_SOS_..._1968.jpg` — **6th SOS SEA, in flight** (the Sandy mission).
- `Douglas_AD-6_Skyraider_of_VA-42_..._1956.jpg` — Navy grey, below-side, belly + fin shape.
- `Douglas_A-1_Skyraider_drops_napalm_in_Southeast_Asia_...jpg` — the ordnance the demo needs.
- en.wikipedia.org/wiki/Douglas_A-1_Skyraider — dims; thisdayinaviation.com — prop 13 ft 6 in (4.115 m).

**Ten form observations that must survive into the mesh:**

1. **The cowl is bigger than the fuselage in BOTH directions.** Head-on, the cowl drum is visibly
   wider than the fuselage behind it; in profile its top line sits ABOVE the spine and its bottom
   line hangs BELOW the belly. The aeroplane reads as a cockpit bolted onto a barrel. Any model
   where the cowl blends smoothly into the fuselage is not a Skyraider.
2. **Under the cowl there is a second, deeper mass** — the oil-cooler / carburettor duct fairing,
   running from the cowl lip aft to about the wing leading edge. It is the deepest thing on the
   forward fuselage and it is what makes the nose look heavy.
3. **The cooling inlet is an ANNULUS around a small blunt spinner**, not a solid nose. There is a
   real dark gap between spinner base and cowl lip; that dark ring reads even at 50 m.
4. **4-blade prop, 4.115 m diameter = 2.5x the cowl diameter** and 27% of the wingspan. It is
   enormous relative to the airframe. The old asset's 5.1 m prop is 24% oversize.
5. **Cranked wing.** Inner panel (root → fold, ~38% semi-span) is flat; outer panels carry ~7°
   dihedral. Head-on this shows as a distinct upward break, not a smooth curve.
6. **Straight leading edge, tapered trailing edge.** LE is near-perpendicular to the centreline;
   all the taper is in the TE. Tips are squared with a rounded outboard corner. Root chord ~3.5 m,
   tip ~1.5 m.
7. **Canopy is a short single-seat greenhouse sat HIGH and FAR FORWARD**, its top level with the
   cowl top. Behind it the spine drops steeply, then runs long and slim to the tail. That
   forward-biased mass is half the silhouette.
8. **Tall broad fin with a long root.** The fin root chord runs nearly a third of the fuselage and
   fairs forward into a dorsal fillet; the rudder trailing edge overhangs the tail cone and is the
   aftmost point of the aircraft. Stabiliser is mounted LOW on the fuselage, well below the fin.
9. **Fifteen stub pylons.** Two heavy inboard + centreline, then a row of small stubs marching out
   to near the tip. Even clean, the stub row is visible from below and it is part of the identity.
10. **SEA camo is BIG blobs with wavy edges, grey belly, wavy demarcation up the fuselage sides** —
    tan FS30219 / medium green FS34102 / dark green FS34079 over light grey FS36622. Patch size is
    metres, not centimetres. A dark antiglare panel sits on the deck ahead of the windscreen.

**Dimensional targets (A-1H/J):** length 11.84 m · span 15.25 m · height 4.78 m (three-point, gear
DOWN, nose-up ~12°) · prop 4.115 m · wing area 37.19 m² · 15 hardpoints · 4 x 20 mm in the wings.

**Note on the height figure:** 4.78 m is the published three-point ground height. This asset is
built LEVEL with the gear UP (it is a CAS overflight model; `cas_airplane.gd` never lands it), so
the correct comparison is fin-top-above-belly, not 4.78 m. Recorded so the next reader does not
"fix" the model to a number that does not apply to its attitude.

---

## 2026-08-14 · `a1_skyraider_v2` shipped — new variant, old asset untouched

`assets/us/aircraft/a1_skyraider_v2.glb` + `.blend`. Built entirely from
`tools/build_a1_skyraider_v2.py` (re-runnable from an empty scene, headless only) and gated by
`tools/verify_a1_skyraider_v2.py`, which asserts the contract on the SHIPPED GLB.
`a1_skyraider.glb` verified byte-identical afterwards by md5. No `.blend1`
(`preferences.filepaths.save_version = 0` is set in the build script).

**Frame contract.** Nose at Blender +Y = **Godot −Z**, real metres, all node transforms identity
except `A1_Prop`'s translation. Origin = centre of mass: x on the centreline, y at the wing
quarter chord, **z on the fuselage centreline — NOT the ground line.**

*That is a deliberate deviation from the commission, and here is the pointer.* `cas_airplane.gd:355`
spawns the strafe muzzle at `global_position + Vector3(0, -1.2, 0)` and calls it "slightly under the
fuselage", and `collision_table.gd:72` carries `y_offset: 0.30` on a 5.1 m box. Both assume a centred
origin. With a ground-line origin the gun run would fire from 1.2 m under the aeroplane.
**The ground line is at local z −1.600** (the prop tip) — add that to park it.

**`A1_Prop` is the whole propeller-and-spinner assembly, at IDENTITY rotation**, translation
`(0, 0.13, −4.9875)` in Godot space. `rotor_spin.gd:76` turns a `PROP_HINTS` node about
`Vector3.BACK` = its local Z; with identity rotation that local Z IS the thrust line, so it spins
correctly with no clip and no code change. The verifier asserts the node rotation is absent/identity
by parsing the GLB JSON, and asserts that **no other node trips a `PROP_HINTS`/`MAIN_HINTS`/
`TAIL_HINTS` string** — `A1_Col_Aft-colonly` is named to stay clear of `tailrotor`/`tailblade`.
No baked action ships, so `RotorSpin` takes the runtime path.

**Facing, measured not assumed.** Old `a1_skyraider.glb`: `A1_Propeller` at Godot z **+0.48..+1.08**,
`A1_Skyraider_Body` back to z **−11**. Nose at +Z — **the shipping asset points backwards** and
`scenes/vehicles/skyraider.tscn:9-11` says so but applies no correction. v2: `A1_Prop` at Godot z
**−5.55..−4.87**, `A1_Col_Aft-colonly` at **+3.66..+6.36**. Conforming.

**Numbers.** 1,908 visible tris (+84 collider) · 7 objects · 10 flat materials, all metallic 0.0,
**no textures at all** (matches the fleet: huey_v3 ships 32 flat Principled materials and one 256px
image). Span 15.250 (real 15.25) · length 11.870 (real 11.84) · prop 4.121 (real 4.115) ·
wing area 38.2 m² (real 37.19) · fin top 3.360 m above the belly.

**On the 4.78 m height figure: it does not apply to this asset and must not be "fixed" to.**
4.78 m is the published THREE-POINT ground height — tailwheel down, nose up ~12°, gear extended.
This model is level with the **gear UP** (it is a CAS overflight airframe; `cas_airplane.gd` never
lands it), so the comparable figure is fin-top-above-belly.

### What the Godot adopter still has to do (NOT done here — out of lane)
1. Point `scenes/vehicles/skyraider.tscn:4` at `a1_skyraider_v2.glb` and **delete the stale
   facing comment at :9-11** — v2 needs no flip.
2. `collision_table.gd:72` `"a1_skyraider"` box (14.0, 5.1, 12.1) / y_offset 0.30 is sized for the
   old airframe. v2 measures span 15.25, length 11.87, height 3.80 with a centred origin. Either
   retune the box or let the three shipped `-colonly` meshes serve (they cover hull, wing and
   empennage and span the airframe in plan — the verifier asserts that).

### Traps this build hit, so the next aircraft does not
- **Colliders render.** Six renders were judged against white collision boxes standing in front of
  the airframe before anyone noticed. `hide_render = True` on every collider at creation; glTF
  exports them anyway.
- **Silhouette errors that only a photo measurement catches.** The fin was wrong twice — first too
  broad in chord, then raked 45° at the leading edge when the real one rakes **29°**. Both were
  fixed by scaling off the Dyess AFB side photo at a derived 82.4 px/m (aircraft length 11.84 m
  spans 975 px) and cropping the tail to 118.7 px/m. Eyeballing a fin against a photo does not work;
  measuring one does.
- **A canopy whose base floats above the spine reads as a roll bar.** Bury the lower edge in the
  fuselage.
- **Camo by Voronoi seed needs the wobble amplitude well UNDER the seed spacing**, or big blobs
  fragment into a checkerboard. Seeds must also not line up in y or the wings paint as spanwise
  stripes. Landed on ~1.9 m spacing along the fuselage, ~1.4 m across the wing, wobble 0.45+0.15.
- **An upward-facing polygon must never take the grey underside colour.** Without that rule the
  wing upper surface crosses the demarcation line and paints a white blob mid-wing.

---

## 2026-08-14 · F-4 Phantom II reference study (before any modelling)

**Sources, and what each one gave.** Everything below was MEASURED off the drawing, not eyeballed.

- **`McDonnell_Douglas_F-4E_Phantom_II_3-view_line_drawing_(manual).png`** (Wikimedia Commons, PD, from
  the aircraft manual) — **a DIMENSIONED three-view**: 19.2 m length · 11.71 m span · 4.98 m ground-to-
  fin-top · 8.41 m across the wing-fold stations · 5.0 m stabilator span · 7.09 m wheelbase · 5.46 m
  main-gear track. Scale derived, not assumed: the 19.2 m dimension line spans 1921 px and the span
  spans 1167 px, so the **top view is 100.05 px/m** (the two agree to 0.4%); the side view fin-top-to-
  ground spans 483 px, so the **side view is 97.0 px/m**. The two views are at DIFFERENT scales -
  measuring the side view with the top view's scale puts every waterline out by 3%.
- `McDonnell_F-4C_Phantom_IIs_of_the_558th_TFS_in_flight_over_Vietnam,_in_December_1968.jpg` -
  **rear-3/4 from above, SEA camo, tail code XT.** The single best angle for this aeroplane: the
  canted-surface X, the patch size, the grey underside, the centreline tank.
- `McDonnell_F-4D-29-MC_Phantom_II.jpg` - **forward-3/4 close-up.** Radome droop, the splitter-plate
  bleed gap, the intake ramp, the tandem canopy framing.
- `390th_Tactical_Fighter_Squadron_F-4Cs_flying_over_Vietnam.jpg` - **low side/below, pre-camo grey.**
  Stabilator anhedral and the store train read cleanly against the sky.
- en.wikipedia.org/wiki/McDonnell_Douglas_F-4_Phantom_II - the design reasons: outer panels angled up
  **12 deg** to buy 5 deg effective dihedral, stabilator **23 deg anhedral** to clear the exhaust,
  the **dogtooth** leading edge for high-alpha control.
- Hill Aerospace Museum / Museum of Flight - **F-4C: 58 ft 3.75 in (17.77 m) long, 38 ft 4.875 in
  (11.71 m) span, 16 ft 3 in (4.95 m) high.**

**Ten form observations that must survive into the mesh:**

1. **"45 deg wing sweep" is the QUARTER-CHORD figure and is wrong as a leading edge.** Measured off
   the top view the inner-panel LE rakes **51.5 deg** and the outer panel **54 deg**. Build a 45 deg
   LE and the planform stops being a Phantom.
2. **The dogtooth and the dihedral break are the SAME station: y = +/-4.205 m** (half of the drawing's
   8.41 m fold dimension), which is **71.8% of semi-span** - the outer panel is only 1.65 m long. The
   sawtooth is a **0.28 m FORWARD step of the leading edge** at that station: measured LE 11.30 m
   inboard of it, 11.02 m outboard.
3. **The engine nozzles exit at ~80% of the length and the last 3.9 m is a SLIM BOOM.** Fuselage
   half-width measured aft: 1.16 m at the wing TE, **0.68 m at 15.4 m, 0.44 m at 16.4 m.** Both
   stabilators and the whole fin mount on that thin boom. Carry the wide fuselage to the tail and it
   reads as an A-7.
4. **The intakes are the widest thing on the forward aircraft.** Half-width goes 0.64 m (bare
   fuselage) to **1.41 m at station 6.8 m** - each intake box adds 0.77 m per side. They are tall
   slabs with a splitter plate standing off the fuselage on a visible bleed gap.
5. **The radome droops, and it is measurable.** Radome axis sits ~0.55 m BELOW the fuselage centreline
   while the belly line stays flat. Under it runs a shallow chin fairing (the M61 bay on the E, the
   seeker fairing on the D) from station 1.6 to 4.6 - that lobe is why the nose looks heavy.
6. **Stabilator:** LE sweep **46.6 deg** (measured (16.6, 0.58) to (18.6, 2.47)), span **4.92 m**,
   **23 deg anhedral**, mounted LOW on the boom well below the fin root. One-piece slab, no elevator.
7. **Fin:** leading edge raked **~62 deg from vertical**, root chord ~4.6 m starting at station
   13.7 m, tip chord ~1.0 m. Fin TE and stabilator TE both land at 19.2 m - they define the tail.
   A near-vertical fin turns it into an F-105.
8. **Waterlines, gear down, above the ground line:** belly **1.30** · spine aft of the canopy
   **2.80** · canopy top **3.40** · fin top **4.98**. So the fuselage centreline is at 2.05 and
   **fin-top-above-belly is 3.68 m** - THAT is the comparable figure for a gear-up level model, not
   the published 4.95-5.0 m, which is a three-point ground height. Same trap as the A-1's 4.78 m.
9. **The canopy is only ~0.6 m proud of the spine, and the spine STEPS DOWN behind it.** The F-4 has
   no bubble; it has a long tandem greenhouse whose top is barely above the deck behind it.
10. **SEA camo patches are METRES across** - on the 558th TFS photo one patch covers a third of the
    fin - with wavy edges, a light grey underside and a wavy demarcation up the fuselage sides. The
    **radome is BLACK**, and there is a dark antiglare deck ahead of the windscreen.

**Variant, and why this build is the F-4E-proportioned airframe at 19.2 m.** The commission asked for
F-4C/D reference but specified **19.2 m / 11.71 m / 5.0 m, which are the F-4E's numbers** - the
F-4C/D is **17.76 m**, the whole 1.45 m difference being the lengthened gun/radar nose. The only
DIMENSIONED drawing available is the F-4E one, so building the C/D would mean inventing where 1.45 m
comes out of a measured nose. Three further reasons the E is the right call here and not a
compromise: the commissioned dimensions are the E's; `collision_table.gd:131` already sizes
`f4_phantom` as a 19.4 m box; and `cas_airplane.gd` flies a **GUNS** ordnance mode
(`_guns_hot()`, `_fire_strafe_burst()` at :355) - the F-4E carries the M61 internally, the C/D needs
a centreline SUU-16 pod. Everything the brief lists as identity (canted stabilator, canted outer
panels, chin intakes, drooped radome, tandem canopy, sawtooth) is common to all F-4s.
`build_f4_phantom_v2.py` exposes **`NOSE_CUT`** so an F-4C/D is a one-constant change.

**No spinning part exists on this airframe and that is the contract.** `cas_airplane.gd:104` calls
`RotorSpin.attach()` on every fixed-wing model. `rotor_spin.gd:25` spins any node whose lowered name
contains `prop` / `spinner` / `blade` (also `mainrotor`/`rotor_hub`/`new_blade`/`rotor_flybar`/
`new_rotor`, and `tailrotor`/`tailblade`/`new_tailblade`), and `:20` plays any action named
`prop_spin` / `A1_PropellerAction*` / `rotor_spin`. A jet must trip NONE of them: no node may be
called anything with those substrings (note `F4_Col_Aft-colonly`, not `..._Tail...`), and no action
may ship. The verifier asserts both.

## 2026-08-14 · `f4_phantom_v2` shipped — new variant, old asset untouched

`assets/us/aircraft/f4_phantom_v2.glb` + `.blend`. Built entirely from
`tools/build_f4_phantom_v2.py` (re-runnable from an empty scene, headless only) and gated by
`tools/verify_f4_phantom_v2.py`, which asserts the contract on the SHIPPED GLB. `f4_phantom.glb`
and its `.import` verified byte-identical afterwards by md5. No `.blend1`
(`preferences.filepaths.save_version = 0` is set in the build script).

**Numbers.** **2,060 visible tris** (+96 collider) · 6 objects · 10 flat materials, all metallic 0.0,
**no textures at all**. Span **11.710** (real 11.71) · length **19.230** (real 19.20) · stabilator
span **4.920** (real 4.92) · wing area **48.8 m²** (real 49.24) · fin top **3.910 m** above the
airframe belly · outer panel dihedral **12.8°** measured (12° designed) · stabilator anhedral 23° ·
dogtooth a 0.280 m forward step at x ±4.205.

**Frame contract.** Nose at Blender +Y = **Godot −Z**, real metres, **every node at identity** — no
translation, no rotation, no scale on any of the six. Origin = centre of mass: x on the centreline,
**y at the wing quarter MAC (station 10.233 of 19.2)**, z on the fuselage centreline at the wing —
**NOT the ground line**, for the same reason as the A-1: `cas_airplane.gd:355` spawns the strafe
muzzle at `global_position + Vector3(0, -1.2, 0)`. The airframe belly is 0.98 m below the origin, so
that muzzle sits 0.22 m clear under the skin. **The ground line is at local z −2.050** — add it to
park the jet gear-down.

**This is a JET and the contract is that NOTHING spins.** `cas_airplane.gd:104` attaches
`RotorSpin` to every fixed-wing model regardless of type. Correct behaviour for a Phantom is for it
to bind nothing: no node name contains `prop`/`spinner`/`blade`/`mainrotor`/`rotor_hub`/`new_blade`/
`rotor_flybar`/`new_rotor`/`tailrotor`/`tailblade` (which is why the aft collider is
`F4_Col_Aft-colonly`, not `..._Tail...`), and **no action ships**, so `rotor_spin.gd:20` finds no
`prop_spin`/`A1_PropellerAction*`/`rotor_spin` clip either. Both build and verifier assert this.

**Facing, measured not assumed.** Old `f4_phantom.glb`: `F4_GunPod_M61` at Blender y **+10.77**,
exhaust at **−8.09** — the old placeholder ALREADY faces nose-+Y, so unlike the Skyraider there is
no flip to undo. It is 1,024 tris, ships **two textures** (`tmpwamani3w`, `tmpxc1gk1yi` — off-spec
for the flat-material fleet), carries duplicate/asymmetric node names (`F4_VFin_L` and
`F4_VFin_L.001`, an `F4_Exhaust_R` with no `_L`) and has **no `-colonly` meshes at all**. Its span
of y −8.58..+10.77 confirms it was already built to F-4E length.

### What the Godot adopter still has to do (NOT done here — out of lane)
1. Point `scenes/vehicles/f4_phantom.tscn:4` at `f4_phantom_v2.glb`. No facing correction is needed
   and none is present to remove.
2. `collision_table.gd:131` `"f4_phantom"` box (11.6, 4.5, 19.4) / `y_offset` 2.29 was sized for the
   old airframe on a GROUND-LINE origin. v2 measures span 11.71, length 19.23, height 4.61 with a
   **centred** origin, so `y_offset` should go to ~0 or the box floats 2.29 m high. Either retune it
   or let the three shipped `-colonly` meshes serve — the verifier asserts they span the solid
   airframe in plan.

### Traps this build hit, so the next aircraft does not
- **A quarter-chord formula copied between opposite sign conventions.** The A-1 script computes the
  wing quarter chord as `LE − 0.25·chord` and is right, because it works in aft-NEGATIVE Blender y.
  This script works in aft-POSITIVE stations, where the same expression moves the point FORWARD half
  a chord. It put the origin on the wing root leading edge and left the model 2.4 m nose-biased. The
  tell was in the printed bounds — nose +6.87, tail −11.48 on a 19.2 m aeroplane. The verifier now
  asserts `|(nose+tail)/2| < 1.0 m`.
- **A 5 cm pitot needle silently failed the collider-coverage test.** The hull collider stopped
  0.68 m short of the airframe's forward-most VERTEX, which is the probe tip — and it should. The
  fix was not to loosen the tolerance but to measure the SOLID nose by radius about the probe axis
  (`hypot(x, z+0.60) > 0.12`) and then assert separately that the hull deliberately stops short of
  the boom. **A bbox test cannot tell a needle from a nose.**
- **Voronoi camo checkerboards above a wobble/spacing ratio of about 0.4.** The A-1 note says keep
  the wobble under the spacing; here is the number. First pass: wing seeds 1.1 m apart under a
  0.55+0.18 wobble, ratio **0.66** — the outer wing panels rendered as a tan/green chequerboard.
  Fixed at seeds 1.7 m apart, wobble 0.40+0.13, ratio **0.31**.
- **Fuselage camo seeds all on the centreline paint transverse BANDS, not blobs.** Voronoi with no
  lateral seed variation degenerates to 1-D. Spreading the seed x over 0.10..0.55 broke it up.
- **One global camera pull-back crops an overhead plan.** In a 1000x620 frame the 19.2 m length
  lands on the SHORT axis of a top view, so the distance that frames the side view beautifully cuts
  the nose and tail off the plan. `VIEWS` now carries a per-view distance multiplier (3.15 for top).
- **The published height did not apply, again.** 4.98 m is the ground-to-fin-top with the gear DOWN.
  This model is level and gear UP, so the comparable figure is fin-top-above-belly, **3.91 m**. Both
  the build and the verifier print the caveat next to the number so nobody "fixes" it.
