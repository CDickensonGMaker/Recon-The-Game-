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

**The A-1 and F-4 rows below are SUPERSEDED (2026-08-14, v2 re-derivation — see the entry
at the top of this file for the shipping figures). The Huey row is current.**

| | donor | visual tris | dims X/Y/Z (m) | GLB |
|---|---|---|---|---|
| ~~`a1_skyraider_crashed`~~ | ~~`a1_skyraider.glb` (11,870)~~ | ~~5,130~~ | ~~18.70 / 15.20 / 3.41~~ | ~~0.27 MB~~ |
| `huey_crashed` | `huey_v3.glb` (60,354) | 5,976 | 20.01 / 19.95 / 4.16 | 0.53 MB |
| ~~`f4_phantom_crashed`~~ | ~~`f4_phantom.glb` (1,024)~~ | ~~2,560~~ | ~~16.07 / 25.00 / 3.06~~ | ~~0.40 MB~~ |

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

## 2026-08-14 (later) · A-1 and F-4 wrecks RE-DERIVED from the v2 donors; gate is now HARD

`build_wrecks.py` + `wrecklib.py`, headless only. **The Huey was not touched** —
`huey_crashed.glb` / `.blend` verified byte-identical by md5 before and after, as were
`a1_skyraider_v2`, `f4_phantom_v2`, `ac47_spooky_v2`, `a1_skyraider` and `f4_phantom`.
New standalone gate: **`assets/us/aircraft/verify_wrecks.py`**, which asserts the contract
on the SHIPPED files from a clean scene (`blender -b --factory-startup -P verify_wrecks.py
-- all`). All three pass.

| | donor | visual tris | dims X/Y/Z (m) | parts | colliders | GLB |
|---|---|---|---|---|---|---|
| `a1_skyraider_crashed` | `a1_skyraider_v2.glb` (1,908) | 3,652 | 18.79 / 15.20 / 2.65 | 14 | 14 (10 tri / 4 box) | 0.29 MB |
| `f4_phantom_crashed` | `f4_phantom_v2.glb` (2,060) | 3,644 | 20.22 / 21.03 / 2.36 | 15 | 15 (11 / 4) | 0.30 MB |
| `huey_crashed` | UNTOUCHED | 5,976 | 19.62 / 19.95 / 4.16 | 33 | 33 | 0.53 MB |

**Every prior conviction comes back clean, and both wrecks now run the gate STRICT**
(`debris_gate` defaults to `"strict"`; the report-only mode is gone from both call sites).
F-4 `pylon_l` floating 0.15 m, `tailfin` at 88.7°, `gunpod` 12%, `nose` 5%; A-1
`wing_thrown` 1%, `canopy` 11%, `panel_1` 21% + 56.7°, `ord_mk82` 22% — all of those
pieces are either gone with the old donor or now measure 41-100% contact. **`assert_lying_flat()`
is DELETED**; nothing calls it, and a superseded check that still runs is a fossil.

### The v2 donors are three meshes, not a part tree — so parts are found, not named

`a1_skyraider_v2.glb` ships `A1_Airframe / Stores / Markings / Prop`; `f4_phantom_v2.glb`
ships `F4_Airframe / Stores / Markings`. New `wrecklib` primitives:

* **`weld()`** — **a donor `.glb` is not the mesh its author built.** The glTF exporter
  splits every vertex whose normal or material differs per face, so a flat-shaded airframe
  arrives as a soup of one-quad islands: `F4_Airframe` imports as 3,082 verts / ~500
  "components" and welds to 842 verts / **20 real parts**. Without the weld, `part_split`
  finds nothing AND every per-vertex random displacement (`crumple`, `dent`, `tear_seam`)
  gives coincident duplicates different offsets and shreds the panel. Same defect
  `build_mound` hit on `bomb_crater`, same fix.
* **`components()` / `part_split()`** — split whole connected components by a predicate on
  their own bbox. Coordinate predicates alone cut a bomb in half; this can only take
  complete parts. Every wing, fin, intake trunk, nozzle, stabilator, tank and bomb in both
  wrecks is found this way. **No donor part name is referenced anywhere any more.**
* **`join_objs()`** — decals ride the wing they are painted on, bombs ride their pylon.
  **`bpy.ops.object.join()` SILENTLY SKIPS a source whose mesh has zero vertices** and
  returns FINISHED; the emptied `A1_Stores` donor survived under its own name and only
  `finish()`'s unprefixed-mesh gate caught it. `join_objs` now deletes empties itself and
  asserts every source is gone.
* **`drape_on_mound()`** — fits a least-squares plane to the mound *under the piece's own
  footprint* and lays it along that, clamped to 14°. `lay_flat` levels against the HORIZON,
  which is right only on billiard-table ground: on a 20-30° plough flank a "provably flat"
  panel touches at one corner and leaves a metre of daylight (F-4 wing 11%, canopy 12%).
* **`soil()` / `spatter()`** — see below.
* **`assert_texture_names()`**, called from `export_glb()`.

### The re-extracting texture is fixed AT SOURCE

`f4_phantom.glb` (the old donor) embeds its metal map as **`tmpwamani3w.jpg`** — a Python
tempfile name baked into the third-party asset — so Godot regenerated
`f4_phantom_crashed_tmpwamani3w.jpg` on every import. The v2 donors carry **no images at
all**, so the only embedded image in either wreck is now `fb_earth` (the mound), and Godot
extracts `a1_skyraider_crashed_fb_earth.png` / `f4_phantom_crashed_fb_earth.png` — the
`ac47_spooky_v2_planecamo.png` pattern. The stale `f4_phantom_crashed_tmpwamani3w.jpg`
+ `.import` are **deleted**. `f4_phantom_tmpwamani3w.jpg` / `_tmpxc1gk1yi.png` stay: they
belong to the intact `f4_phantom.glb`, which is still in the project.
**The guard, so it cannot come back:** `assert_texture_names()` fails the export if any
image datablock is named `tmp*` or is not `[a-z0-9_]+`, and prints the exact filenames
Godot will produce.

### Five defects found by measuring, each of which the build ran happily through

1. **A rotation about the wrong axis.** `rigid(fin, rot_deg=(34,0,7))` was supposed to lean
   the F-4's fin; a fin plate lies in the x=0 plane, so an X euler RAKES it fore-and-aft
   and leaves it dead upright — measured plate tilt **90.0°** after the "lean". `ry` is the
   axis that knocks a fin over (now 36°, tilt 54°). Same class on both attached wings:
   `rx` pitches the CHORD, `ry` droops the TIP.
2. **…and then 10° of the correct rotation buried the wing.** `build_mound`'s slot is only
   as wide as the hull, so past ±1.7 m the ground climbs into the berm: a 10° droop over a
   7.3 m half-span dropped the tip 1.5 m and the whole starboard wing vanished under the
   spoil. Now 4°.
3. **Seating an aeroplane on the group minimum seats it on its drop tank.** `sink()` uses
   the lowest point of everything given to it, and the F-4's centreline tank hangs 0.8 m
   below the keel — the fuselage floated **0.58 m proud** of the scar it was supposed to be
   ploughed into. New `sink_ref(objs, ref, z)` takes the datum from the KEEL. Both wrecks
   now throw the centreline tank clear as debris, which is also the better read.
4. **Build the mound BEFORE seating the hull.** Sinking to a fixed world z first makes the
   burial depth whatever the mound profile happens to work out at — it came out at 0.02 m
   of hull standing proud. Now: dig the scar, sample the slot floor under the hull, seat
   the keel `HULL_BURY` (0.04 m) under it. Measured hull proud: A-1 1.08-1.42 m, F-4
   0.56-0.90 m. **And exclude the mound from the sink list** — `meshes()` now contains it,
   and sinking the ground with the aeroplane leaves every clearance exactly where it was.
5. **The burial report was sampling the wrong ground.** It read the mound at WORLD x=0,
   which after `zero_to_ground()` is the FOOTPRINT centre — a thrown wing drags that
   metres off the fuselage and out onto the flank berm. Now samples the hull's own
   centreline. (The 0.96-1.20 m figures in the 08-13 entry below were measured that way.)

### Two render-instrument lessons

* **A clipping render is not evidence about a material.** The thrown wing was read as
  "white paper" twice; its exported `baseColorFactor` was **0.213** neutral grey. Sun
  energy 3.2 on `Standard` clipped it. `render_views()` now sets **AgX explicitly** and the
  sun to 2.4 — and the answer came from the GLB's own material JSON, not from the picture.
* **The real fix was still a modelling one.** An uninterrupted 15 m² flat plane reads as a
  placed prop whatever its albedo. `soil()` darkens the light paint (FS36622 underside grey
  and the white insignia — ×0.32, and both face the SKY once a wing lands inverted) and
  `spatter()` mottles ~45% of thrown-debris faces with mud, keyed on face position so a
  re-run is identical.

### Other decisions worth knowing

* Both thrown wings land **INVERTED** (ref obs 8: "on edge or inverted"). Upright, a wing
  comes to rest on its own pylons and bombs with the panel 0.4 m clear of the dirt — 17%
  contact. Inverted it lies on its skin with the racks in the air. `lay_flat(flip=True)`.
* **Long debris gets flattened, not tilted.** 6° of residual tilt on a 4 m F-4 canopy lifts
  one end 0.42 m and took contact to 14%. Canopies are now crushed to 0.18-0.34 of height
  (a canopy off a crash is a smashed frame) and thrown with 0-8° of tilt.
* **`pick_pilot_anchor` used a 6 m fire clearance while `verify_roundtrip` asserts 8 m.**
  Two thresholds for one rule; the sweep's scoring term happened to carry it every time.
  Now 8 m in both.
* F-4 soot was radius 4.2 / core 0.42 and covered the whole spine — the Phantom read as a
  black smear with camo edges. Now 2.8 / 0.28 (13% of faces).
* Part names changed with the donor: the F-4 gains `nozzle_l/r`, loses `gunpod`,
  `pylon_*`, `tank_r`, `stab_aft`; the A-1 gains `tailfin`, `stab_l/r`, `tank_thrown`.
  Nothing in Godot reads a wreck's part names (only the model name, via `CollisionTable`).

### OPEN, for the code owner — `collision_table.gd:86-88` is now stale again

Measured on the re-imported GLBs (Godot X/Y/Z = Blender X/Z/Y):

* `a1_skyraider_crashed` — entry `box (18.7, 3.2, 15.2)`, footprint `(19.7, 16.2)`.
  **Measured 18.79 wide / 1.93 above ground / 15.20 long.** Height is over-tall by 1.3 m.
* `f4_phantom_crashed` — entry `box (16.2, 3.2, 25.0)`, footprint `(17.2, 26.0)`.
  **Measured 20.22 / 1.45 / 21.03.** Too narrow by 4 m, 4 m too long, 1.75 m too tall.
* `huey_crashed` — entry `(22.0, 3.2, 20.9)` vs measured 19.62 / 3.21 / 19.95. Close.

Each wreck ships per-part `-colonly` meshes that cover it properly, so the box only
matters wherever `get_entry` is used for footprint reservation.

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

### ~~OPEN~~ CLOSED 2026-08-14 by the v2 re-derivation above — kept for the failure record

Both wrecks were rebuilt from the v2 donors, both now run the gate **strict**, and
`assert_lying_flat()` is deleted. The list below is what report-only mode found on the
superseded (old-donor) files; every one of these pieces is either gone with its donor or
now measures 41-100% ground contact.

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

---

## 2026-08-14 · C-47 / AC-47D **PURE-REFERENCE** form study — written BEFORE any geometry (v3 bake-off)

`ac47_spooky_v3` is built from reference only: **no donor, no base model, nothing imported.**
`ac47_spooky.glb` and `ac47_spooky_v2.glb` are untouched (md5-asserted by the verifier). The
study below is deeper than the v2 one because v2 could lean on his mesh for the forms it kept;
this build has to derive every one of them.

**Sources, and what each gave.**
- **NASA 3-view line drawing** `File:Douglas C-47 Skytrain 3-view line drawing.gif` (Wikimedia
  Commons, PD, 2919x1939) — **the measuring instrument, measured programmatically**, not by eye:
  thresholded, flood-filled into connected components so each view is isolated and no view can
  leak into another's min/max scan, then scanned column-by-column. Scales derived per view.
- thisdayinaviation.com (C-47B specs) — 95 ft 6 in span · 63 ft 9 in length · **wing area 988.9
  sq ft (91.87 m2)** · **LE swept aft 15.5 deg** · **5 deg dihedral outboard of the nacelles** ·
  **trailing edges unswept** · centre section straight · 2 deg incidence.
- en.wikipedia.org/wiki/Douglas_AC-47_Spooky — 3 x 7.62 mm miniguns in the **fifth and sixth
  windows** and the cargo door, all to port; crew 7-8; 19.63 m / 28.96 m / 5.16 m.
- theaviationist.com (2024-10-25) — **"two guns pointing out the last two windows aft of the port
  wing, and one out of the open cargo door"**; SUU-11BA pods; pilot's surplus gunsight in the
  left-hand cockpit window; flares kicked out the open cargo door by the loadmaster.
- theaviationist + gmodelart SEA-camo reference — **FS 34079 Forest Green / FS 34102 Medium Green
  / FS 30219 Dark Tan over FS 17038 BLACK undersides** for night gunships (the usual FS 36622
  light grey underside was replaced with black in-theatre for AC-47 / AC-119).
- ww2aircraft.net — C-47 cargo door **85 x 68 in (2.16 x 1.73 m)**, two-piece, port, aft of the wing.
- YouTube `r1LyyRzpsow` "C-47 Skytrain Walkaround, CAF Arizona" (partial pull, contact sheet at
  4 s intervals) — the only 3-D check on the nose, cowl and undersling forms. Confirmed the nose
  "whale" plan-taper, the cowl ring proportions, the exhaust stack low and outboard, the
  half-exposed wheel and the yellow prop tips.

### Sixteen form observations, each of which changed a modelling decision

1. **The drawing's SIDE view is drawn TAIL-DOWN and every station read off it is wrong until it is
   de-rotated.** Fitted the cabin-window centres (they are separate black blobs, so they can be
   found exactly) and got **9.63 deg nose-up**. Un-corrected, the fin reads 0.5 m too tall and the
   crown reads as sloping when it is nearly level. This is the single biggest trap in the drawing.
2. **The three views are at three different scales** — plan **63.00 px/m**, front **63.07**, side
   **61.72** (after de-rotation, matched to the plan's length). Derive px/m per view. The plan and
   front agreeing to 0.1% is what makes both trustworthy.
3. **The drawing is 19.634 m long** — i.e. it is drawn to Wikipedia's AC-47D 19.63, not to the
   fleet's 19.43. The 1.05% disagreement recorded for v2 is real and is in the DRAWING too.
   Resolved by scaling every longitudinal station by **0.98961** so length lands exactly on 19.43;
   vertical and lateral come off the span, which is exact.
4. **The crown is one continuous curve whose APEX IS OVER THE COCKPIT** (+1.39 m above the cabin
   window line at s 3.35) and then declines almost dead flat aft: +1.17 at s 8.5, +1.03 at 15.5,
   +0.90 at 18.5. **Essentially the whole tail taper comes off the BELLY** (-1.74 at s 8 to -0.30
   at s 19.3). A C-47 in profile is a straight-topped, upswept-bottomed tube — build the taper into
   the keel, not the spine, or it reads as a Dakota-shaped airliner.
5. **The fuselage is TALLER THAN WIDE**: max depth **2.905 m** (s 8.5), max width **2.55 m** —
   ratio 1.14. Head-on it is an upright oval with the wing hung through its lower third.
6. **The cockpit glazing wraps INTO the nose contour; there is no stepped greenhouse.** Panes
   occupy s 1.85-3.30 at z +0.55..+0.95, under a crown at +1.28..+1.39 — a 0.35-0.45 m fairing of
   solid skin above the glass, and the front view shows six panes carried right across the full
   fuselage width and over the centreline. Model it as a band ON the fuselage surface.
7. **Wing: the centre section is straight and unswept out to |x| 3.66 m.** The panel joint is
   literally drawn on the plan as a line at y +/-3.655 running the full chord. Root chord **4.37 m**,
   LE s 4.87, TE s 9.24, and the **TE is unswept** the whole way out (9.24 -> 9.14 over 8 m).
   Outboard the LE sweeps aft **14.5 deg measured**, against the published 15.5 — and unlike the
   F-4 case that published figure IS a leading-edge figure, so the two agree.
8. **Dihedral 5.4 deg measured** (published 5), starting at the panel joint, not at the root. Taken
   from the front view's two separately-drawn outer-panel outlines: lower surface -4.74 at |x| 3.6
   to -3.85 at |x| 13.0.
9. **The nacelles are slung UNDER the wing and BELOW the fuselage centreline, and that undersling
   is the front-view identity.** Nacelle centreline x **+/-2.82 m**, cowl **1.35 m** diameter
   (an R-1830 in a NACA cowl, and the drawing agrees to the centimetre), thrust line **1.20 m below
   the fuselage centreline** and **0.64 m below the wing chord plane**. Widely-spaced or in-line
   engines turn a Dakota into a bomber.
10. **Prop-tip clearance must be measured at THRUST-LINE height, not at the widest fuselage
    station.** At +/-2.82 with a 3.51 m disc the inboard tip reaches x 1.065, and the fuselage
    half-width is 1.09 — which "proves" an interference that does not exist. At the thrust line,
    1.20 m below the fuselage centre, the section is only ~0.72 m half-wide, so the real clearance
    is **~0.35 m** and the blade sweeps past the lower flank. Same class as the F-4 pitot-boom trap.
11. **The nacelle runs s 2.95 (cowl lip) to 6.5 (tapered point)** — 3.5 m — max width 1.38 at
    s 3.5-5.0, and its BOTTOM deepens aft to -2.57 because the main wheel lives in it. **The wheels
    stay half-exposed when retracted**; the drawing carries both the stowed wheel and a dashed
    extended one.
12. **The fin is modest and rounded, 2.48 m above the crown** (top +3.58 at s 17.9 against a crown
    of +1.10), with a **dorsal fillet that starts at s ~12.7** and visibly lifts the spine line
    before the fin proper begins. The rudder TE rakes forward going up. Not a tall airliner fin.
13. **The tailplane is small and low**: span **8.54 m** (29.3% of the wingspan), root chord 2.88 m,
    LE swept 25-26 deg, TE at s 19.38 **level with the rudder TE**, mounted at z -0.06 — i.e.
    essentially ON the cabin window line, low on the tail cone, with only ~2 deg of dihedral.
14. **Both gunship sources resolve to the SAME two stations, which is the strongest fix in the
    study.** The drawing's window ladder is 7 cabin windows at **1.015 m pitch starting s 4.41**.
    Wikipedia's "fifth and sixth windows" gives 8.47 and 9.49. TheAviationist's "the last two
    windows aft of the port wing" gives the same pair, because the wing root TE is at 9.24 and the
    seventh window at 10.50 is swallowed by the cargo door. **Gun stations 8.47 / 9.49 / 10.90.**
15. **The cargo door position is fixed by the drawing's passenger door.** The NASA drawing is a
    DC-3, so it carries the 1.16 x 1.49 m passenger door at s 11.33-12.49; the C-47's 2.16 x 1.73 m
    cargo door is the same aperture extended forward, so **s 10.33-12.49, sill z -1.20**.
16. **In the FRONT view the near-horizontal element 3.6 m below the fin top spanning +/-4.09 m is
    the TAILPLANE, not the wing.** Reading it as the wing puts the wing 0.9 m too high on the
    fuselage and turns a low-wing transport into a mid-wing. The give-away is that +/-4.09 matches
    the plan's tailplane half-span of 4.27 and nothing on the wing.

**Datum used throughout:** s = metres aft of the nose; z measured from the **cabin window line**,
which is the one horizontal datum both the side and front views agree on.

---

## 2026-08-14 · `ac47_spooky_v3` shipped — PURE REFERENCE, no donor. Three AC-47s now ship side by side

`assets/us/aircraft/ac47_spooky_v3.glb` (160 KB) + `.blend`, built by
`tools/build_ac47_spooky_v3.py` (re-runnable from an empty scene, headless only) and gated by
`tools/verify_ac47_spooky_v3.py` — **VERIFY PASS, 0 failures.** No `.blend1`.

**This is the bake-off variant.** v2 matured HIS mesh; v3 imports nothing at all and derives every
station from the reference study above. The verifier md5-asserts **both** older files after every
run: `ac47_spooky.glb` `5ee96aabf0d59ebe613e09189f63c3e2` and `ac47_spooky_v2.glb`
`cd5b77d7afc5cbbe50d140d8898f6f27`. Both are untouched; all three are for him to compare.

**Numbers.** **2,752 visible tris** (+120 collider) · 9 mesh nodes + 3 socket empties + 3 colliders ·
**9 flat materials, all metallic 0.0, NO TEXTURES AT ALL** (the a1/f4 pattern — v2 is the fleet's
one textured airframe because it carries his `planecamo` wrap).
span **29.110** (real 29.11) · length **19.430** (real 19.43) · fuselage **2.550 wide x 2.905 deep**
(real 2.55 x 2.905 — taller than wide by 13.9%) · tailplane **8.540** (real 8.54) · props
**3.514** (real 3.51) · wing area **95.6 m2** gross against a published 91.87 (+4.0%, the one
dimension that is out; the drawing's own planform gives 95.6 and the published figure is probably net).

**Frame contract, same as the rest of the fleet.** Nose at Blender +Y = **Godot -Z**, real metres,
**every node at identity** except the two prop translations and the three muzzle empties. Origin =
centre of mass: x centreline, y wing quarter chord (s 5.9625 of 19.634 drawing-frame), z fuselage
centreline at the wing. **Ground line at local z -3.008** — the SWEPT prop arc, 0.423 m below the
static bbox floor of -2.585, because the blades are clocked 90/210/330 so none sits at bottom dead
centre. Belly-to-fin-top **5.320 m**; the published 5.16 m is ground-to-fin-top with the tail DOWN
and must not be "fixed" to.

**The port battery.** Three 7.62 mm miniguns at s **8.47 / 9.49 / 10.90**, depressed **12 deg**,
muzzles 0.55 m proud. Godot muzzle coordinates: `gun_muzzle_1` **(-1.788, 0.123, 2.481)** ·
`_2` **(-1.787, 0.123, 3.486)** · `_3` **(-1.775, 0.123, 4.886)**. **Bore convention is v2's,
unchanged** — Blender local +Y, i.e. `-muzzle.global_transform.basis.z` in Godot — so
`spectre_gunship`'s adoption works against either variant with the same code. Cargo door
**2.16 x 1.73 m** at s 10.33-12.49 (the real C-47 figure, not v2's 1.28 m compromise), two-piece,
port only. Seven cabin windows at 1.015 m pitch; the port side ships four windows, two gun ports
and no seventh (the door aperture eats it).

**Paint: the SEA night-gunship scheme, per-face, no texture.** FS 30219 tan / FS 34102 medium green /
FS 34079 forest green over **FS 17038 BLACK undersides** — the in-theatre replacement for FS 36622
light grey on AC-47/AC-119 night aircraft, and the single most Spooky-specific thing on the model.
Voronoi seeds 2.8 m apart under a 0.95 m wobble (ratio 0.34, under the 0.4 chequerboard threshold).
The demarcation is **a fraction of the LOCAL fuselage depth, not a fixed z**: a constant-z line runs
off the bottom of an upswept C-47 tail cone and leaves the last four metres unpainted. Exhaust and
gun-gas soot use one extra material and are the only "character" painted on.

### Where the pure-reference build beat the donor-derived v2, and where it did not

* **Nacelles at the drawing's +/-2.82 m, not +/-3.15.** v2 had to move its engines 0.33 m outboard
  because his prop is 3.56 m and his nose is fatter, and it measured tip clearance at the widest
  fuselage station. v3 owns both, and sweeping the clearance over HEIGHT (the engines hang 1.20 m
  below the fuselage centreline) gives **0.105 m** at the tightest point with the engines exactly
  where the drawing puts them. This is the front-view identity and v3 has it outright.
* **A full-size 2.16 x 1.73 m cargo door.** v2's is **1.28 m tall** because his belly starts climbing
  at s 11.8 where a real C-47's runs parallel to 13.6, so the door had to be moved onto the hull he
  drew. v3 built the hull to the drawing, so the door is the real one at the real station.
* **Decals cannot sink, by construction.** v2 ray-cast his faceted flank, needed a `need_flat=True`
  normal guard, snapped its grid to his vertex rings and still carried a per-panel sagitta lift that
  could not reach zero on a diagonally triangulated hull. v3 has an ANALYTIC skin (`skin_x(s, z)`),
  so every decal vertex is placed 30 mm outside a surface the faceted mesh is everywhere inside —
  gated as "0 of 137 decal vertices sunk" and it is a theorem, not a tuning.
* **Where v2 is better, honestly: the paint.** v2 carries HIS hand-painted `planecamo` 600x600 wrap
  and its UVs. v3's camo is per-face flat colour, so its blobs are quantised to polygon boundaries
  and can never be finer than the mesh. It reads well (the wing had to go from a 2 m to a 1 m
  spanwise station pitch before the top view stopped looking like rectangles) but it is a different,
  blockier idiom. If he wants his painted camo, v2 is the one that has it.
* **Also v2's, not v3's: his forms.** The faceted chunky section, his cockpit greenhouse and his
  raked fin are his authorship. v3 replaced them with the drawing's, which is more C-47 and less
  his. That is the whole question the bake-off is asking.

### What the Godot adopter still has to do (NOT done here — out of lane)

Identical to v2's list, and every item is unchanged because v3 honours the same contract:
1. `spectre_gunship.gd:11` -> whichever variant he picks, and **DELETE `:117-120`** — that block
   sets `airframe.rotation.y = PI` on a comment claiming the GLB's nose points +Z. It has not since
   the 2026-08-12 facing bake. All three variants are nose-+Y and need no flip.
2. Feed the muzzle empties into `_fire_vulcan` (`:217` synthesises a muzzle from the target direction
   with no reference to the model).
3. `:131-134` works as-is: v3 ships the `prop_spin` clip it plays by name (one slotted action, both
   props, 3.0 rev/s at 24 fps). Attaching `RotorSpin` also works — the two props are the only nodes
   matching `PROP_HINTS`, each with its origin on its hub at identity rotation.
4. `collision_table.gd` — three `-colonly` meshes ship and the verifier asserts they span the
   airframe in plan.
5. `ac47_spooky_v3.glb.import` does not exist yet; Godot writes it on the next editor open.

### Traps this build hit

- **A fan cap sits at its ring's own station.** Capping the fuselage loft's first ring at s 0.14
  instead of closing to a point at s 0 cost **0.139 m of overall length** on a model whose length is
  a hard contract. Nothing else noticed.
- **Two mirrored lofts that both include the x = 0 section duplicate it.** 7 doubles on the wing and
  7 on the tailplane, plus two buried caps, for nothing. One loft tip-to-tip through the fuselage.
- **A paint rule keyed on POSITION leaks onto other parts.** The port gun-soot rule had no normal
  clause and painted a black rectangle across the aft half of the port wing's upper surface. Every
  scalar the build printed stayed green; only the top-view render showed it.
- **The fin's leading-edge rake is the silhouette.** First pass raked it 52 deg from vertical against
  the drawing's 34 and produced a shark fin, exactly as the A-1 build warned. Take the rake from the
  side view's own upper silhouette where it leaves the crown, not from a table you like the look of.
- **The verifier was measuring an animated propeller.** See the universal ledger — it convicted a
  correct file twice.

---

## 2026-08-14 · AC-47D "Spooky" reference study (before touching `ac47_spooky.glb`)

**This asset is different from the A-1 and F-4 jobs: `ac47_spooky.glb` is the Summoner's OWN model.**
The commission is to mature it, not to replace it. Everything below is a measurement against
reference, so that "keep" and "fix" are decisions with numbers behind them rather than taste.

**Sources, and what each one gave.**
- NASA 3-view line drawing, `File:Douglas_C-47_Skytrain_3-view_line_drawing.gif` (Wikimedia Commons,
  public domain, NASA Photo ID EG-0016-01, 2919x1939) — **the measuring instrument.** Side view read
  at **71.3 px/m** (nose-to-rudder 1385 px over 19.43 m), plan view at **43.4 px/m** (span 1267 px
  over 29.11 m). Every station below is off this drawing.
- en.wikipedia.org/wiki/Douglas_AC-47_Spooky — AC-47D dims (length 19.63 m, span 28.96 m,
  height 5.16 m, wing area 91.7 m2), 2 x R-1830, **3 x 7.62 mm GAU-2/M134**, crew 7 incl. 2 gunners,
  32 x Mk 24 flares; guns fire "through two rear window openings and the side cargo door, all on the
  left (pilot's) side".
- vietnam.warbirdsresourcegroup.org/ac47-design.html + theaviationist.com (2024-10-25) — the mount
  story: **SUU-11/A gun pods on locally fabricated mounts** first, **Emerson MXU-470/A** later. The
  two window guns sit in the **5th and 6th windows**, i.e. the last two aft of the port wing; the
  third is in the **aft cargo door**.
- ww2aircraft.net "Dimensions of cargo door on C-47" — **cargo door 85 in wide (2.16 m) x 68 in tall
  (1.73 m)**, two-piece (forward third / aft two-thirds), port side, aft of the wing.
- theaviationzone.com/douglas-ac-47 + militaryfactory.com — corroborate the three-gun port battery.

**Eight form observations that must survive into the mesh.**

1. **The props are mounted CLOSE IN, and that is the DC-3's whole front-view identity.** Plan view
   puts the nacelle centrelines at **x = +/-2.88 m** — with a 3.51 m (11 ft 6 in) Hamilton Standard
   23E50 the inboard prop tip passes about **0.25 m** from the fuselage side. An AC-47 with widely
   spaced engines reads as a bomber. *(The base model has them at +/-6.1 m — see the fix list.)*
2. **The fuselage is TALLER THAN WIDE**, not a flat slab: ~2.6 m across, ~2.9 m deep. Head-on it is
   an upright oval with the wing hung under it.
3. **The wing centre section is straight and unswept out to about +/-3.7 m**, carrying both nacelles;
   only outboard of that does the leading edge sweep and the dihedral start. Root chord **4.42 m**,
   tip chord ~1.5 m, rounded tips.
4. **The tailplane is small: span ~8.7 m** (measured 380 px at 43.4 px/m), root chord ~3.2 m — under
   30% of the wingspan. It sits **low on the tail cone**, not on top of it, and its trailing edge is
   nearly level with the rudder trailing edge.
5. **The fin is modest and rounded**, about **2.8 m above the aft fuselage centreline**, with a long
   dorsal fillet running forward. It is not a tall swept airliner fin.
6. **The main wheels stay half-exposed under the nacelles when retracted.** This is a DC-3 signature
   visible from every angle below the horizon and it costs about 60 tris.
7. **The port side is the gunship side and it must read as one.** Cargo door aft of the wing
   (2.16 x 1.73 m), two gun-port windows immediately forward of it at roughly 1 m pitch, and short
   barrel clusters standing proud of the skin, **depressed about 12 deg** so the pylon turn puts the
   beaten zone under the left wing. Everything else on the aircraft is symmetric; this is not.
8. **Station layout off the side view** (s = m aft of the nose, total 19.43): windscreen 1.6 ·
   prop disc 2.3-2.6 · wing LE root 5.16 · cabin windows at ~0.98 m pitch from 4.3 · wing TE root
   ~10.5 (incl. fillet) · cargo door 11.4-13.6 · stab LE 16.1 · fin LE 16.5 · rudder TE 19.43.

**Dimensional targets used for `ac47_spooky_v2`:** length **19.43 m** and span **29.11 m** (the
commission's C-47B/DC-3 figures). Wikipedia's AC-47D entry gives 19.63 / 28.96 — a 1.0% and 0.5%
disagreement. The commission's numbers win because the rest of the fleet was built to the same
source style; the variance is recorded here so nobody "fixes" the model to the other pair.

### What the base model measured, and the keep/fix ruling

Measured by importing the shipped `ac47_spooky.glb` and baking every node transform into vertex data
(the file carries non-uniform object scales up to 68x, so bbox-from-node-scale would have lied).

| feature | his base | real | delta | ruling |
|---|---|---|---|---|
| overall length | 22.757 | 19.43 | **+17.1%** | FIX |
| span | 29.408 | 29.11 | +1.0% | fix (free, also centres it) |
| fuselage width | 3.631 | ~2.60 | **+40%** | FIX |
| fuselage height | 2.664 | ~2.90 | -8% | keep |
| nacelle / prop station | +6.27 / -5.96 | +/-2.88 | **+115%, and 0.31 m ASYMMETRIC** | FIX |
| prop diameter | 3.64 | 3.51 | +3.7% | keep |
| tailplane span | 12.855 | ~8.7 | **+48%** | FIX |
| fin above aft centreline | 4.18 | ~2.8 | **+49%** | FIX |
| wing root chord | 4.518 | 4.42 | +2.2% | keep |
| visible tris | 2,483 | - | - | keep (budget class) |

**Facing and scale: MEASURED, and the memory note is now out of date.** `ac47_spooky.glb` already
carries the 2026-08-12 correction baked in as a parent node — `AirframeRoot` with rotation
`[0,1,0,0]` (180 deg about Y) and scale **0.1498**. After that root the shipped nose is at Blender
+Y = **Godot -Z**, which is the fleet convention **already satisfied**. The commission's "nose +Z,
10x scale" describes the file *before* that bake; the true residual scale error is **zero** and the
true residual facing error is **zero**. What is left is the 17% length error, which is proportion,
not transform.

**Therefore `spectre_gunship.gd:117-120` is a live double-flip.** It sets `airframe.rotation.y = PI`
on the strength of a comment that says "the GLB's nose points +Z". It does not any more, so the
gunship currently flies its airframe **backwards**. Out of lane to fix here; recorded for the adopter.


---

## 2026-08-14 · `ac47_spooky_v2` shipped — HIS model matured, old asset untouched

`assets/us/aircraft/ac47_spooky_v2.glb` + `.blend`, built by
`tools/build_ac47_spooky_v2.py` (re-runnable from an empty scene, headless only) and gated by
`tools/verify_ac47_spooky_v2.py` — **VERIFY PASS, 0 failures.** No `.blend1`.

**The pipeline is different from the A-1 and F-4 and that is the point.** Those two build an
airframe from nothing. This one **imports `ac47_spooky.glb`**, bakes its node transforms into vertex
data, applies six measured corrections and adds the battery. His facets, his forms, his camo texture
and his UV wrap are carried through untouched. The verifier asserts the source GLB is still
**byte-identical** (md5 `5ee96aabf0d59ebe613e09189f63c3e2`) after every run.

**Kept, deliberately:** the faceted chunky fuselage section · the swept tapered wing with raked tips ·
the tall raked fin planform · the cockpit greenhouse · the nacelle and prop blade forms · the
**`planecamo` 600x600 texture and its UVs** (367 unique UVs survive the merge — asserted) · the prop
diameter (3.556 m vs a real 3.51, +1.3%) · the wing root chord (4.518 vs 4.42, +2.2%) · the tailplane
sitting high on the tail cone and forward of the fin, which is his layout, not a C-47's.

**Fixed, with the measured factor:** length 22.757 -> **19.430** · fuselage width 3.631 -> **2.600** ·
tailplane span 12.855 -> **8.700** · fin 4.18 -> **3.01 m** above the aft centreline · nacelles
+6.31/-5.93 (0.38 m ASYMMETRIC) -> **+/-3.150 symmetric** · span 29.408 -> **29.110** and centred ·
**78 zero-area faces deleted** (38 in each nacelle, 2 in the cockpit cap — invisible, and their
removal lets the QC gate stay a hard failure).

**How the length was taken out, and why not uniformly.** A piecewise y warp, identity forward of the
wing trailing edge (s 8.535) and x0.766 aft of it, applied to the **FUSELAGE ONLY**. The wing,
nacelles and props keep their y exactly — the wing is a separate object that interpenetrates the
fuselage and shares no welded boundary, so warping the body does not distort his planform. The fin
and tailplane are **TRANSLATED, not warped** (+3.327 and +1.404): warping them too would have taken
23% out of their chords on top of the span fix and left a toy empennage.

**Numbers.** 2,617 visible tris (+96 collider) — his base was 2,483, so the battery cost **134**.
9 meshes + 3 empties · 2 flat materials, both metallic 0.0, one texture. Span **29.110** (real 29.11) ·
length **19.430** (real 19.43) · fuselage **2.600** (real ~2.60) · tailplane **8.700** (real ~8.7) ·
props **3.556 / 3.560** (real 3.51). **Nacelles are at +/-3.150, not the drawing's 2.88** — driven by
clearance, not by taste: his prop is 3.56 m and his nose is fatter, and 3.15 leaves the inboard tip
**0.247 m** clear of the skin, which is the real aeroplane's ~0.25 m. Both build and verifier compute
that gap at the PROP STATION rather than at the widest fuselage station.

**Frame contract.** Nose at Blender +Y = **Godot -Z**, real metres, **every node at identity** except
the two prop translations and the three muzzle empties. Origin = centre of mass: x centreline,
y wing quarter chord, z fuselage centreline at the wing. **Ground line at local z -2.335** — the
SWEPT prop arc, not the static bbox (-2.314): no blade sits at bottom dead centre in the rest pose,
but the disc sweeps there.

**The port battery.** Three 7.62 mm miniguns, mount + barrel cluster, at s 9.55 / 10.45 / 11.95,
**depressed 12 deg**, muzzles standing 0.80 m proud of the skin. Godot muzzle coordinates:
`gun_muzzle_1` **(-1.840, 0.268, 4.404)** · `_2` **(-1.851, 0.268, 5.304)** ·
`_3` **(-1.822, 0.268, 6.804)**. Each empty is oriented so its **Godot local -Z is the bore**, i.e.
`-muzzle.global_transform.basis.z` — asserted at 12.0 deg down and 0.978 to port. Two-piece cargo
door (2.16 x **1.28** m) and two 0.46 m gun ports as dark panels, plus half-exposed main wheels.

**On the published 5.16 m height: it does not apply and must not be "fixed" to.** That is the
ground-to-fin-top figure with the **tail down on its gear**. This model is level and gear up, so the
comparable figure is fin-top-above-the-aft-centreline, **3.01 m** (real ~2.8).

### What the Godot adopter still has to do (NOT done here — out of lane)
1. **`spectre_gunship.gd:11` -> `ac47_spooky_v2.glb`, and DELETE `:117-120`.** That block sets
   `airframe.rotation.y = PI` on the strength of a comment reading "the GLB's nose points +Z".
   **It does not, and has not since the 2026-08-12 facing bake** — `ac47_spooky.glb` already carries
   an `AirframeRoot` with rotation `[0,1,0,0]`, so the gunship is currently flying its airframe
   **backwards**. v2 needs no flip either. This is a live defect on the SHIPPING asset, not just v2.
2. **Feed the muzzle empties into `_fire_vulcan`.** `spectre_gunship.gd:217` currently synthesises
   `global_position + inward * 3.2 + Vector3(0, -0.9, 0)` — a muzzle derived from the target
   direction with **no reference to the model at all**, 3.2 m out and 0.9 m down. The three empties
   are 1.84 m out and 0.27 m **up**, and they carry the bore direction. Round-robin them per round
   and the tracer rope leaves the guns instead of a point in space.
3. `:131-134` can stay as it is — v2 ships the `prop_spin` clip it asks for by name (one slotted
   action, both props, 3.0 rev/s). Attaching `RotorSpin` instead also works: the props are the only
   nodes matching `PROP_HINTS`, each with its origin ON its hub at identity rotation.
4. Retune or drop any `collision_table.gd` box for `ac47_spooky` — three `-colonly` meshes ship and
   the verifier asserts they span the airframe in plan.

### Traps this build hit, so the next one does not
- **A memory note about a facing/scale defect can outlive the defect.** The commission said "10x
  scale, nose +Z". Measured: the shipped GLB already carries the corrective root (scale 0.1498,
  180 deg about Y) and its facing is **conforming**. The residual error was 17% of LENGTH, which is
  proportion and needs modelling. **Import and measure before believing any note about a file.**
- **A 3-blade prop's hub is not its bbox centre, and a tip-centroid solver diverges.** Bucketing
  vertices into three 120 deg sectors does not line the buckets up with the blades, so two "tips"
  come off one blade; the solve read the disc as **4.68 m** across instead of 3.56. **His own
  `Prop_Center_rotation` empties carry the hub** — read the file's authored data instead of solving.
- **Measure the part BEFORE you merge it.** Post-merge, "widest vertex aft of the wing" answered
  with the WING (tailplane read 29.11 m) and "fuselage centreline" answered with the wing hanging
  under it (fuselage read 4.38 m). Both queries were syntactically fine and confidently wrong.
- **Same class, second bite:** the verifier then measured fuselage width at `y ~ 0`, which on a
  quarter-chord origin is mid-WING, and read 2.18 m. **A width query must name its band.**
- **A decal on a low-poly hull must use HIS facet lines as its grid.** His cabin flank is a RIDGE at
  y 0.97 with long triangles running to y +5.11 and y -4.35. A regular grid chorded across it and
  the cargo door sank **0.144 m** into the skin — and *refining the regular grid made it worse*,
  because a finer regular grid still straddles the crease. Snapping the grid to his own vertex rings
  cut it to 0.04. Restrict those rings to the panel's own band, or the door inherits a cut at every
  ring on the aeroplane and blows out to 216 tris.
- **A per-row lift turns a door into a staircase.** Pushing each row out by its own sagitta made the
  door read as a stack of crates in close-up. One uniform lift for the whole panel, sized for its
  worst row, reads as a door. It cannot reach zero on a diagonally-triangulated flank.
- **`ray_cast` on a faceted hull needs a normal check.** At z +0.10 the port ray landed on
  near-tangent facets and the skin station swung 0.37 m over 0.3 m of height; at z +0.30 the same
  scan is flat (normals -0.96..-0.99). `skin_x(..., need_flat=True)` asserts it now.
- **Compute a translation delta ONCE.** `edit(fin, lambda p: p.y + (target - bounds([fin])[0].y))`
  re-evaluates the bounds inside the per-vertex loop and gives every vertex a different shift. It
  produced the right total length anyway, which is what made it dangerous.
- **His hull, not the drawing, decides where a door goes.** His belly starts climbing at s 11.8
  where a real C-47's runs parallel to s 13.6, so the battery sits 0.5 m forward of the drawing's
  stations and the door is 1.28 m tall rather than 1.73. Every corner is ray-verified against the
  skin, so that compromise cannot silently drift.

## 2026-08-14 · `m151_mutt_gun_jeep_v2` shipped — new variant, originals untouched

`assets/us/vehicles/m151_mutt_gun_jeep_v2.glb` (101 KB) + `.blend`. Built entirely from
`tools/build_m151_v2.py` (re-runnable from an empty scene, headless only) and gated by
`tools/verify_m151_v2.py`, which asserts the contract on the SHIPPED GLB — **VERIFY PASS,
0 failures**. `m151_mutt_gun_jeep.glb` (2026-05-25) and `m151_rigged.blend` (2026-07-29)
are untouched, mtimes intact. No `.blend1` (`filepaths.save_version = 0` in the build).

**Numbers.** **1,828 visible tris** (+24 collider) · 11 mesh nodes + 4 socket empties ·
**7 flat materials, all metallic 0.0, no textures at all** · length **3.371** (real 3.371) ·
width **1.633** (real 1.633) · height **1.765** (real 1.803 top-up, −2.1%) · wheelbase
**2.159** · track **1.346** · tyre OD **0.780**. Every linear dimension is exact except
height, which is driven by the pedestal M60 rather than a canvas top.

**Distribution is the point, not the count.** Body 1,000 tris (**54.7%**); wheels+spare 564
(31%); gun+mount 272; windscreen 84. The shipped jeep spent **41.3% on two tow hooks and a
steering wheel** and 5.4% on all bodywork. **No tori anywhere** — the steering wheel is a
10-segment ring, the tow eyes are boxes. The verifier asserts body >= 40% of visible tris.

**ORIGIN: the GROUND LINE**, on the centreline, at the longitudinal centre of the
bumper-to-bumper envelope. This is NOT the aircraft convention (centre of mass) and the
consumers decided it:
- `destructible_vehicle.gd:30-31` sets `global_position = (x, terrain.get_height_at(p), z)`
  — the node origin is dropped ONTO the terrain surface. A centred origin buries the jeep.
- `collision_table.gd:57` gives it `box (1.8, 1.8, 3.5)` with **`y_offset 0.9`** — a box
  half its own height above the node, i.e. exactly a box resting on a ground-line origin.

The axle midpoint lands **+0.041 m** forward of that origin, so "midway between the axles"
and "longitudinal centre" agree to 4 cm.

**`collision_table.gd:57` NEEDS NO CHANGE.** Measured: 1.633 W x 1.765 H x 3.371 L fits
inside (1.8, 1.8, 3.5) on every axis. **The authored box was always correct — it was written
for a conforming jeep, and only the MODEL was 90 degrees out.** The verifier asserts the fit
and asserts `y_offset == box.y / 2`.

**Wheels are separate nodes** `m151_wheel_fl/fr/rl/rr`, mesh centred on the hub, identity
rotation and scale, translation to the hub. Godot local **X is the spin axis**, local **Y
the steer axis**. `M151_Gun` is likewise a node at the traverse pivot (0, −0.45, 1.560) with
`MuzzlePoint` as its child, so a future mount can yaw and pitch it. Everything else — body,
windscreen, gun mount, spare, both colliders — is at **full identity**. **+X is the vehicle's
RIGHT**; the verifier checks the L/R suffixes BY POSITION, because `m35_rigged.blend` has
that pair inverted and it must not be inherited.

**Kept from `m151_rigged.blend`:** the nose-+Y facing convention (confirmed by measurement,
not by trusting it), the socket names `seat_driver` / `seat_passenger` / `seat_gunner` /
`MuzzlePoint`, and the material vocabulary (OliveDrab / MetalDark / Rubber / Glass / lens).
**Its geometry was NOT usable** — measured this session it is the same primitive soup as the
shipped GLB: 8,376 tris, 38 twelve-tri cubes, 3 default tori at 41.3%, unapplied scale on 40
of 77 objects. Only the facing had been fixed.

**Dropped deliberately, and why:** `Rollbar_Post_L/R` + `Rollbar_Top` (the ROPS bar is a
late-1970s retrofit; no Vietnam-era reference carries one) · `Radio_Antenna` (a whip put the
old model 1.682 m tall — an antenna in the bbox is exactly the defect the review named on the
M35 and M113, and it would push this model past the 1.8 collision box) · `seat_rear` and the
rear bench (removed on a pedestal gun jeep; shipping the empty would be a lie in the map) ·
`Red_L`/`Red_R` and `LightLens_L`/`LightLens_R` merged to one material each.

**Materials: 7, not the review's suggested 4-5.** OliveDrab · MetalDark · Rubber · Glass ·
LensAmber · LensRed · Canvas. Zero duplicates, zero textures. Amber vs red lenses earn
separate slots because they are the vehicle's face and tail, and the amber/red split is what
the facing probe measures. Canvas is the seat cushions, which read tan against OD in every
reference photo.

### Reference of record (gathered before modelling, per the standing law)
- YouTube M151A1 detail walkaround (`yt-dlp` + `ffmpeg` 4x3 contact sheets, 12.5 min, 24
  frames) — the only source that gave rear-quarter and tub-interior angles.
- `en.wikipedia.org/wiki/M151_jeep` — 132.7 / 64.3 / 71 in top up, 53 in reduced, 85 in
  wheelbase; **"the M151 did not feature Jeep's distinctive seven vertical slot grille,
  instead, a horizontal grille was used"**; unitary body-and-frame; the M151A2's **large
  combination turn-signal / blackout lights on the front fenders**.
- `warwheels.net` M151A2 data sheet — **wheel tread 53 in (1.346 m)**, ground clearance
  9.4 in, tyres **7.00x16**. This is the number the review did not have (it estimated 1.377).

**Reference overrode the brief on one point.** The commission said "spare tire on the tail".
Every walkaround angle carries it **upright INSIDE the body on the LEFT, immediately behind
the driver**, breaking the body line by ~0.40 m. Built that way. It also keeps the spare
inboard of the tub wall — the shipped jeep measured **1.740 m wide (+6.6%)** because its
spare and mirror hung outside the body, and my first pass repeated the mirror half of that
exact mistake (1.695 m) before the width assertion caught it.

### What the Godot adopter still has to do (NOT done here — out of lane)
1. Point the convoy roster at the new asset. `convoy_spawner.gd:108` builds the path as
   `VEHICLE_MODEL_DIR + name + ".glb"`, so `mission_generator.gd:372,376` only needs the
   string changed to `"m151_mutt_gun_jeep_v2"`. **No facing correction is needed and none
   exists to remove** — `destructible_vehicle.gd:7-33` applies none.
2. **THE TRAP:** `DestructibleVehicle.create` calls `CollisionTable.get_entry(basename)`.
   `m151_mutt_gun_jeep_v2` has **no entry**, so `collision_table.gd:204-210` falls through to
   a **3x2x3 default box with a push_warning** — a jeep with a 3 m nav carve. Add a
   `"m151_mutt_gun_jeep_v2"` key duplicating `:57`'s `(1.8, 1.8, 3.5) / 0.9`, and a
   `Mat.METAL` entry at `:306`. Verified as still fitting; do not resize it.
3. `tests/test_roads.gd:392` lists convoy model basenames that must resolve to a file — add
   the v2 name there when the roster changes, or the guard stops covering what ships.

### THE GROUND-VEHICLE GATE NOW EXISTS — `tools/verify_m151_v2.py`
The review's cross-fleet finding 5 was that no ground vehicle had a verifier and that is why
a sideways jeep shipped for three months. This one is **written to be copied**: everything it
knows lives in a `SPEC` dict at the top, so the M35 and M113 verifiers are a copy with a new
SPEC and no other edit. It asserts facing by part position, real dimensions, ground-line
origin, wheel naming BY POSITION, wheelbase/track, glTF node translations (not just the
imported objects), collider coverage, fit inside the authored `collision_table` box, zero
textures, no `.001` duplicate materials, no `rotor_spin.gd:25` hint words in any node name,
no default tori, no n-gons, no loose verts, and the tri-distribution rule.

**Negative-tested before being trusted** (per the standing "run a new gate against something
you already know" law): pointed at the OLD `m151_mutt_gun_jeep.glb` with its own lens
material names, the facing probe reports head-to-tail separation of **+3.230 m on X and
0.000 m on Y** and FAILS. The gate catches the exact defect it was written for.

**A done-but-unexported `.blend` is invisible to every GLB check.** The July facing fix was
never exported and no check in this project could see it, because they all read GLBs. The
tell is a `.blend` newer than its sibling export — `m35_rigged.blend` (2026-07-29) vs
`m35_deuce_truck.glb` (2026-05-20) is still in that state today.

---

## 2026-08-14 · The three crashed aircraft: SOLID PAINT pass (materials only, no geometry)

Caleb, verbatim: *"can you make the planes that crashed have a more solid color? so they read
better?"* The A-1 was the worst case — its SEA camo read as a chequered log from every angle.

**Measured cause, not taste.** Dumped the shipped GLBs' material tables
(`assets/us/aircraft/build_wrecks.py`, `wrecklib.py`): `a1_sea_tan` base colour **0.393 linear**
against `a1_sea_green_dark` **0.036** — a 10x albedo span across three blobs on one 11 m
fuselage — and the tan sat within a few percent of the earth mound's own value, so the airframe
DISSOLVED into the dirt in patches while the dark green blobs read as unrelated objects. Camo
works at 300 m in the air; it is the wrong tool on a 15 m prop that must read as an aeroplane in
one glance.

**What shipped.** One solid muted base per airframe, thrown pieces included, plus one lighter
value on the control surfaces so the mass is not dead flat. Linear, with the sRGB chip value:

| | base | lit panel | trim | insignia |
|---|---|---|---|---|
| A-1, Huey | `0.062 0.062 0.032` **#464632** | `0.084 0.084 0.045` **#52523C** | **#242424** | **#4D4D4C** |
| F-4 | `0.048 0.056 0.034` **#3E4334** | `0.065 0.076 0.046` **#484E3D** | **#242424** | **#4D4D4C** |

Materials per wreck fell 13 → 9 (A-1), 7 → 5 (Huey), 13 → 9 (F-4). Tri counts UNCHANGED
(3652 / 5976 / 3644) — the pass touches `material_index` and base colours and nothing else.

### Four things this pass learned, each of which changed a number

* **KILLING THE CAMO EXPOSED THE SAME DEFECT WEARING SOOT.** `scorch()`'s dither is 50/50 in its
  falloff band, and on a low-poly sunlit wing a 50% chequer of soot against paint is exactly the
  read that was just removed. The lever is the CORE, not the radius: faces closer than
  `radius*core` are solid, the rest dither. All three went to `core` 0.70-0.72 (was 0.28-0.34) on
  a slightly smaller radius — solid burn at the seat, a narrow broken edge, no static.
* **SOOT HAS TO BE DARKER THAN THE PAINT IT SITS ON.** At the old `SOOT` 0.055 the char was
  within 10% of the F-4's new base and the fire seats vanished. Now 0.032 (`wrecklib.SOOT`).
* **THE BRIGHTEST THING ON THE F-4 SITE WAS THE CANOPY.** `wreck_canopy_crazed` measured
  luminance **0.107** against a 0.053 airframe, and being near-neutral it took the render sky's
  blue — a slate slab beside the hulk pulling the eye off the aeroplane. Now 0.065/0.070/0.062.
* **THE BLUE CHANNEL DECIDES WHETHER A GREY-GREEN READS AS SLATE.** The render sky is
  0.42/0.46/0.52, so any near-neutral paint takes a blue cast in every shadowed facet. Holding
  blue at ~0.6 of green keeps the Phantom green in the shade; at 0.044/0.058 it looked naval.

### Pipeline changes
* NEW `wrecklib.unify_paint(objs, subs, name, colour)` — collapses every material matching `subs`
  onto ONE solid base per FACE. Geometry, part names, sockets, colliders and every gate untouched;
  a slot left with no faces is not written by the glTF exporter, so the camo materials simply
  stop shipping.
* NEW `wrecklib.set_base(subs, colour)` — absolute base colour, for trim and insignia.
* **DELETED `wrecklib.soil()`** (fossil law): its only callers are gone, because `underside_grey`
  and the store greys are now absorbed into the base rather than multiplied by a guessed factor.
  Its lesson is carried in `set_base`'s docstring.

### Gates, on the shipped files
`build_wrecks.py -- all` green for all three: `assert_debris_grounded` STRICT (13/32/14 pieces,
no convictions), `assert_texture_names` (only `fb_earth` embeds), round-trip re-import
(`wreck_hard_`/`wreck_soft_` prefixes on every mesh AND collider, 3 fire sockets ≤ 1.55 m off the
wreck, `pilot_anchor` 6.17/6.48/6.40 m off the hull and ≥ 8.64 m from any fire, nose +Y).
`verify_wrecks.py` → **ALL WRECKS PASS**. Donor md5s byte-identical before and after.

### Two pre-existing defects this pass found and did NOT fix (out of a materials lane)
1. **`a1 wreck_soft_wing_r` renders as fine grey static along its inboard span.** Coincident
   surfaces: the gate measures clearance **-1.28 .. 0.71 m with 85% contact**, i.e. the wing skin
   is flush inside the mound over most of its area, and Cycles picks between the two coplanar
   surfaces per sample. Present identically in the pre-change renders. It will z-fight in Godot
   too. Fixing it is a burial-depth change and re-opens the debris gate.
2. **The Huey build reports `2 embedded` textures including `huey_crashed_fb_crate.png`.** The
   gate lists loaded IMAGE DATABLOCKS with users, not what the exporter wrote — the shipped GLB
   embeds only `fb_earth` (verified by `verify_wrecks.py` reading the file). Pre-existing;
   `assert_texture_names` is measuring the scene when the question is about the file.

---

## 2026-08-14 · `m35_deuce_truck_v2` shipped — new variant, originals untouched

`assets/us/vehicles/m35_deuce_truck_v2.glb` (112 KB) + `.blend`. Built entirely from
`tools/build_m35_v2.py` (re-runnable from an empty scene, headless only) and gated by
`tools/verify_m35_v2.py` — **VERIFY PASS, 0 failures** on the shipped GLB.
`m35_deuce_truck.glb` (2026-05-20, 7.96 MB) and `m35_rigged.blend` (2026-07-29) are
untouched, mtimes intact. No `.blend1` (`filepaths.save_version = 0` in the build).

**7.96 MB to 112 KB. 16,600 tris to 2,170. 12 materials + 8 x 1024 textures to 7 flat
materials and zero textures.**

**Numbers.** 2,170 visible tris (+24 collider) · 12 mesh nodes + 13 socket empties ·
length **6.980** (real 6.980) · width **2.438** (real 2.438) · height **3.000** to the
tarp crown, cab roof 2.820 (real 2.82) · wheelbase **3.912** · bogie **1.118** ·
front track **1.645** · tyre OD **1.054** · bed floor 3.658 x 2.438 at z **1.270**.
**Every linear dimension is exact.**

**Distribution.** Body 792 (36.5%) · CargoBed 368 · Tarp 118 · Windscreen 132 —
**bodywork 58.9%**. Six wheel nodes 760 = **35.0%**. The shipped truck spent **69.4% on
ten tyre tori** and 4.8% on all 67 bodywork boxes. The verifier asserts bodywork >= 45%.

**ORIGIN: the GROUND LINE**, centreline, longitudinal centre of the bumper-to-tailgate
envelope — the M151 v2 decision, same two consumers (`destructible_vehicle.gd:30-31`
drops the node origin onto terrain; `collision_table.gd:154` carries `y_offset 1.60`,
which is half a 3.2 m box, i.e. a box resting on a ground-line origin).

**SIX wheel nodes, not ten.** `m35_wheel_fl/fr` are single tyres; `m35_wheel_ml/mr/rl/rr`
are **DUAL PAIRS in one mesh**. On a real deuce a dual pair is bolted to one hub and
turns as one body, so one node per hub is the physically correct split — and it is what
lets a 6x6 with ten tyres cost 760 tris. The verifier asserts the split by measuring each
node's mesh half-width (0.114 single / 0.269 dual), not by trusting the name.

**+X is the vehicle's RIGHT and the verifier checks every wheel's L/R suffix BY POSITION**,
because `m35_rigged.blend` has that pair inverted (`FrontLeft_Tire` at x +0.6..+0.9) and it
must not be inherited.

### What `m35_rigged.blend` (2026-07-29) actually measured

Measured this session, and it settles the question: **its facing IS fixed and its geometry
is worthless.** 113 mesh objects, **16,600 tris — the same primitive soup as the shipped
GLB**: ten 1,152-tri default tori (11,520 = **69.4%**), 67 twelve-tri cubes (804 = 4.8%),
**unapplied scale on 67 of 113 objects**, size `[2.100, 5.778, 3.300]` with the 3.30 being
a radio antenna. `Grille` at y +3.254..+3.304, `CargoBed_Tailgate` at −2.213 → nose
**+Y, conforming**. It adds 25 empties (11 wheel, `TAILGATE_PIVOT`, `tail_point`,
12 seats) and 11 wheel/tailgate actions the shipped GLB does not have.

**Kept from it:** the nose-+Y convention (confirmed by measurement, not trusted), the
socket vocabulary `seat_driver` / `seat_passenger` / `seat_troop_l_1..5` /
`seat_troop_r_1..5` / `TAILGATE_PIVOT`, and the material vocabulary.
**Its L/R naming is inverted on the WHEELS and the BED WALLS but CORRECT on the SEATS** —
`seat_driver` sits at x −0.3, which IS the vehicle's left with +Y forward, i.e. left-hand
drive. So the seats were rebuilt at the same signs and the wheels were not.
**Dropped:** the 11 wheel empties (superseded by the wheel mesh nodes, which carry the
pivot themselves), `tail_point` and `RadioAntenna` — nothing in `scripts/` reads any of
these (grepped), and an antenna inside the bbox is the exact defect the review named.

### Reference of record (gathered before modelling, per the standing law)

Two YouTube walkarounds via `yt-dlp` + `ffmpeg` 4x3 contact sheets; videos deleted after,
sheets kept in the session scratchpad (`ref/m35_sheetA|C|D.png`, `ref/zoom_*.png`).
The Pit Stop For Patriots M35A2 (`eESnIpzfS-c`, 94 s) is the one that paid: 12 frames
covering dead-front, both front three-quarters, side, rear, the dual tandem in near-profile
and the bed interior. Eight observations, all of which changed a number or a decision:

1. **The cab is essentially bed-width.** In every frame the cab sides and the bed sides
   read as one line. Built at CAB_HW 1.100 against a bed HW of 1.219 — **90%**. The
   shipped truck was 1.05 m wide against a 2.10 m bed: **50%**, and that single ratio is
   why it read as a toy.
2. **The nose is TWO ROUND-TOPPED FENDERS with a long flat hood between them**, and the
   fender crowns sit *below* the hood top. Built: hood top 1.68 rear to 1.60 front, fender
   crown 1.55 inner to 1.14 outer over a 1.04 skirt.
3. **The grille is a dark mesh panel with SEPARATED VERTICAL BARS**, recessed between the
   fenders, with a separate bar brush guard in front of it — one horizontal rail plus four
   uprights running down to the bumper. Confirmed in words by truck-encyclopedia
   ("the radiator grille was meshed with separated bars").
4. **THE BONNET HAS NO LOUVRES.** truck-encyclopedia: *"The bonnet lacked louvres, opening
   in the centre along a twin hinged system"*, and the walkaround hood side is a smooth
   flat panel. **The review's rebuild spec asked for "distinct side louvre panels"
   (`VEHICLE_REVIEW_2026-08-14.md:364`) and that is wrong** — the CCKW has them, the deuce
   does not. Not built. Reference overrode the brief, as the M151's spare tyre did.
5. **The Vietnam-era cab is a SOFT TOP** — solid metal doors, canvas roof, folding
   two-pane windscreen. Built that way, in `M35_Canvas` so the roof reads different from
   the steel, with the crown at exactly the published 2.82 m.
6. **The bed side is a ribbed panel with a strong horizontal belt rail, a top rail, and
   evenly spaced vertical stakes** — not planks, not an open rack. Six ribs a side.
7. **Bogie spacing measured, not quoted.** No source I could reach publishes the M35's
   wheelbase and the two that mention one disagree (142 in at generalequipment.info vs the
   commonly repeated 154 in). Measured off the near-profile tandem frame with the
   9.00x20 tyre OD as the scale datum: **rear axle centres 1.076 tyre-OD apart -> 1.134 m,
   i.e. the 44 in tandem**; and **the bed runs 1.39 tyre-OD aft of the last axle -> 1.47 m**,
   which is only consistent with the **154 in (3.912 m)** wheelbase, not 142. Built to
   3.912 / 1.118, and the rear overhang comes out 1.559 m against the measured 1.47.
8. **The tail lamps are on the bed's rear CORNERS, not on the tailgate.** Built on the
   corner posts so they do not travel with a dropped gate. (The shipped truck's two tail
   lights are **11 cm apart fore-and-aft**; these are at identical y and the verifier
   asserts the lamp clusters are laterally balanced to 0.05 m.)

Published dimensions of record: `en.wikipedia.org/wiki/M35_series_2½-ton_6×6_cargo_truck`
(274-3/4 in / 96 in / 111-112 in, bed 8 ft x 12 ft, 9.00x20, dual tandem) ·
`truck-encyclopedia.com/coldwar/us/M35-truck.php` (274-3/4 / 93 / 111 in, soft-top cab, no
louvres, meshed grille) · `generalequipment.info/M35A2.htm` (**bed floor 50 in = 1.27 m**,
9.00x20 8-ply).

**On the two published widths.** 93 in (2.36) and 96 in (2.44) both appear. **The 8 ft bed
settles it** — a 2.438 m bed cannot sit on a 2.36 m truck. Built to **2.438**, and the bed
is the widest point, with the cab and fenders at 2.20 inboard of it. The review's table
carries 2.36; that is the chassis figure, not the envelope.

**The commission brief's dimensions were wrong and were not used**: it gave 6.71 x 2.39 x
2.9. Every source says 6.98 long, and the review's own spec (`:352`) says 6.98 x 2.36 x
2.82. Built to the sources.

### THE TARP IS ONE SKIN AND THERE ARE NO BOW OBJECTS

The shipped truck's `BowRail_±0.93` spans z 2.212-2.242 over a `Canvas_Top` at 2.113-2.143
— **the bows sit 7 cm ABOVE the cover**, so the truck wears a bright metal cage over its
own tarp. Under a fitted tarp the bows are inside and invisible, so the only honest
low-poly answer is to model **the arc the bows make and nothing else**: `TARP_PROFILE` is
that arc, `M35_Tarp` is one 118-tri skin with a laced-shut rear flap, and **there is no
geometry above the bed rail for a future edit to get wrong.** The verifier asserts that
no vertex of any other mesh rises above the tarp crown, and that the tarp is centred on
x=0 (the shipped `Canvas_Top` runs x −0.934..+1.010, a 7.6 cm overhang to one side).

**No `hessian_230`.** The photographic burlap that renders as wicker, and the
`worn_asphalt` road-surface photo on all ten tyres, are gone with every other texture.

### What the Godot adopter still has to do (NOT done here — out of lane)

1. `mission_generator.gd:374` — change `"m35_deuce_truck"` to `"m35_deuce_truck_v2"`.
   `convoy_spawner.gd:108` builds the path from the name, so nothing else changes, and
   **no facing correction is needed and none exists to remove**.
2. **THE TRAP, and it is worse than the M151's.** `collision_table.gd:154` reads
   `"m35_deuce_truck": box (2.1, 3.3, 5.8), y_offset 1.60`. **That box was measured off
   the OLD truck and inherits its −17% length and −11% width, so a correctly sized deuce
   cannot fit inside it** — 2.438 > 2.1 and 6.980 > 5.8. Unlike the M151's, this entry
   is NOT already correct. Add:
   `"m35_deuce_truck_v2": {"box": Vector3(2.50, 3.20, 7.10), "y_offset": 1.60, "footprint": Vector2(3.6, 8.2), "scale": 1.0}`
   and a `Mat.METAL` entry at `:309`. Note `y_offset 1.60` is already exactly half of
   **3.2**, not of the 3.3 in the file — the authored offset was written for a 3.2 box and
   the box height is the number that is 5 cm out with itself.
   **Without an entry, `collision_table.gd:204-210` falls through to a 3x2x3 default box
   with a `push_warning` — a 7 m truck with a 3 m nav carve.**
3. `tests/test_roads.gd:392` lists convoy model basenames that must resolve to a file —
   add the v2 name when the roster changes, or the guard stops covering what ships.

### THE GATE — `tools/verify_m35_v2.py`, and it was negative-tested

Copied from `tools/verify_m151_v2.py` with a new SPEC, which is exactly what that file was
written for. New checks this one adds and the M151's should inherit: the **cab-to-bed width
ratio** (> 0.82), **nothing standing proud of the tarp crown**, **tarp centred on x=0**,
**dual-pair vs single wheel by measured mesh half-width**, **three axles in front-to-back
order** with wheelbase measured front-axle-to-bogie-centre, and it **reads
`collision_table.gd` live** — if the `m35_deuce_truck_v2` key exists it asserts the model
fits that entry, and if it does not it prints the exact line to add and asserts the model
fits the box this asset requires. The gate grows teeth the moment the adopter wires it.

**Negative-tested against the shipped truck before being trusted**
(`-- --glb assets/us/vehicles/m35_deuce_truck.glb --legacy`, which swaps in that model's own
lens material names so the facing probe reads something real): **VERIFY FAIL, 188 failures.**
It reports headlamps at y **−3.329** and tail lamps at **+2.289** — a head-to-tail separation
of **−5.618 m**, i.e. the truck is 180 degrees out — plus length −17.2%, width −13.9%,
height +10.0%, a bbox floor at **z −0.050** (below the ground line), all **ten 1,152-tri
tori**, and all **8 embedded textures** by name. The gate catches every defect it was
written for.

### Four things this build learned, each caught by a measurement, not by reading the code

1. **A 10-sided tyre does not touch the ground.** Its lowest vertex sits at
   sin(−72 deg) = −0.951 r, so the truck floated **26 mm** and the ground-line assertion
   convicted it. 12 divides 360 into a bottom vertex for free, which is why the M151
   never needed a phase term; 10 does not. `tyre()` now phases the ring by tau/4.
2. **COINCIDENT SURFACES ARE THE LOW-POLY EQUIVALENT OF Z-FIGHTING AND THEY LOOK LIKE
   DIRT.** Three separate pairs in this model rendered as a grid of black speckles down
   the bed side — rib-vs-rail, then rib-vs-panel after the first fix, then hood-vs-fender
   at the nose. Fixed by putting the bed side on **three distinct planes and no two the
   same**: panel 1.189, ribs 1.209, rails 1.219. Same defect class as the A-1 wreck's
   buried wing (`:1544-1548`). **A build QC that checks n-gons, doubles and loose verts
   cannot see it. Only a render can.**
3. **`Shell.box()` given an inverted range builds the solid inside out, silently.** The
   hood-crease strip was written `z 1.640 -> 1.600`; the "top" corner ring came out below
   the bottom one and all twelve faces pointed inward, rendering as a bright flipped-normal
   slab beside each headlight. Nothing in the QC pass could see it. `box()` now asserts
   `hi > lo` on all three axes.
4. **A hand-wound end cap is a coin flip, so stop flipping it.** The tarp's two end caps
   and both fender caps were all inverted on the first pass and every one rendered as a
   black wedge. `Shell.cap(pts, outward, tag)` computes Newell's normal and reverses the
   point list if it disagrees with the direction the cap is supposed to face.
   **And underneath that was a worse bug the caps merely exposed:** the tarp's
   cross-section list reversed BOTH halves, so the section ran −0.66, −1.02, −1.22, **0.0**,
   +0.66 — a self-intersecting bowtie. The swept skin still bridged cleanly, which is
   exactly why it looked almost right; only the caps showed it. `build_tarp()` now asserts
   the section is monotonic in x.

**One cosmetic nit left, measured and not fixed:** the front fender's end cap is a small
bright triangle beside each headlight in the dead-front render. It is a correctly wound,
correctly lit facet at a grazing angle to the sun, not a normals or coincidence fault
(verified — `cap()` forces its winding and the coplanar probe finds no unshared coplanar
pair there). About 6 px in a 1000 px render; invisible at convoy distance. Left for the
Summoner to judge rather than self-iterated on.

**Renders (final geometry):**
`C:\Users\caleb\AppData\Local\Temp\claude\C--Users-caleb\0201f774-4017-48d5-924a-0296e7efee35\scratchpad\vehicles\m35v2_{side,front,threequarter,rear_quarter,datum}.png`
