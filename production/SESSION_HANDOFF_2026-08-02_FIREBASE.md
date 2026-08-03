# SESSION HANDOFF — 2026-08-02 (Wyrm) · FIREBASE REWORK

**Pick up here tomorrow.**

## THE TRUTH SOURCE — read this first
`assets/world/building models/structures/firebase/kit/firebase_v3.1_RECOVERED_medical.blend`
is **THE firebase**. Ruled by Caleb 8/2: *"this firebase scene is the truth source of the
firebase. all others are old and stale."* 58.92 MB, 1,574 objects, 27 collections, saved at wrap.

**Every other firebase .blend in that folder is stale** — `firebase_v3.1.blend` (7/31),
`firebase_v3.blend`, `firebase_v2.1`, `firebase_v2_layout`, `firebase_kit_review*`, and all
`.blend1` beside them.

### THE LIVE TRAP — fix before the next export
`tools/gen_firebase_v3.py:912` still defaults `blend` to **`firebase_v3.1.blend`** (stale), and
`:1104` to `firebase_v3.blend`. An export run today builds the GLB from the OLD firebase, saves
over the stale file, and reports success. Silent until the game loads without the medical
complex. Fix the default, or rename the truth source into the canonical name and archive the
stripped one — the rename is cleaner, since the pipeline and docs all reference `firebase_v3.1`.

## WHY THE RECOVERED FILE EXISTS
On 7/31 21:41 an export saved over `firebase_v3.1.blend` and **stripped all 21 collections and
the `medical_complex`** (29,448 verts / 40 children). Recovered 8/2 from the `.blend1` rolling
backup. `.blend1` is overwritten on the next save of its parent — **copy it to a real filename
before touching anything** when work goes missing. A .blend smaller than its own .blend1 is the
tell; so is `len(bpy.data.collections) == 0`.

`fb_toc_i` and `fb_aid_station_i` are **absent on purpose** — Caleb deleted both. The medical
complex replaced the aid station; a rebuilt HQ bunker replaces the TOC. Do not restore them.

## SHIPPED THIS SESSION

### Collision / winding — the big one
**Every structure in the firebase wound inward.** Signed volume negative on 19 of 19 families.
Godot's `ConcavePolygonShape3D` collides on the FRONT FACE ONLY, so every trimesh collider only
blocked from the inside, and `fb_terrain_mound` (6,992 faces, 100% down) was **walk-through from
above** — the fall-through Caleb reported.
- `gen_firebase.py:146` `box()` winding reversed (math-verified: −8.0 → +8.0 on a unit cube)
- `gen_firebase_v3.py` `terrain_mound()` and `berm()` windings reversed
- `site_planner.gd::_force_backface_collision` — runtime stopgap, forces `backface_collision`
  on every concave shape in the shipped GLB. **Verified in game: 331 shapes.** Self-deleting:
  reports 0 once the re-export lands, then the whole function goes (ADR-023).

### Bunkers — 12 placed, all rebuilt from two approved prototypes
- Flanking embrasures cut into the side walls (was one 50° frontal slit; now front 55° + two
  flanks ~25°), plus timber head-planking closing a **0.57 m hole above every lintel**.
- `fam_bunker_fighting` emitted NO station at all — 7 bunkers were unmannable scenery. Now
  3× `work_bunker` + `bunker_los_point` each. `fam_bunker_mg` gained `work_mg` (its
  `mg_fire_point` carried the type as a custom property, which the export DROPS).
- Prototypes live in `WORKBENCH_bunkers` (`WB_bunker_rifle`, `WB_bunker_m60` + real
  `m60_pintle`). 8 fighting + 4 MG cloned to the line, markers parented.
- **Steps** to every doorway, risers ≤ 0.236 m (`MAX_STEP` 0.24). **Revetment** banked around
  each, crest capped just under the firing sill.
- Sandbag parapet **morphed** around the bunkers: 22 segments trimmed, 4,959 faces removed,
  **all 81 destructible segments survive** (emptying one silently drops it off the blast bus).
- Berm sealed to the mound: 108 floating bearings → **0**, crest untouched.
- **Field of fire verified 12/12 clear** against parapet, berm and new bags.

### Artillery
4 M101 emplacements placed ~90° apart from the recovered `work_gun` clusters, **baked crew
stripped** (59 objects, 4 `PSXRig_*` armatures) per Caleb's ruling that base NPCs man them.
24 `work_gun` posts built from the gun's own `station_*` empties. All four fire **outward**
(local forward is −Y, so bearing = `rotz + 90`; the old howitzers were pointing inward).
`MC_pit_floor` is **17,600 tris each** — 70k across four guns, first thing to decimate.

### Second helipad
Had zero work markers; 4 added by mirroring the authored offsets off the pad that had them.

### Props
`fb_field_chair` was **8 disconnected shells with a 122 mm air gap** — legs authored along Y so
a 14° tilt laid them flat. Fixed to `(0.035, 0.035, 0.46)` at z 0.23, verified headless.
New: `fb_food_tray`, `fb_tray_stack`.

## IN FLIGHT — the chow hall
`WORKBENCH_chowhall` @ (0, −240): **47 meshes, 62 markers, 2,268 tris.**
Caleb's spec: *"an open aired tent with a dedicated cooking section and than tables for people
to sit at and eat"*, **one wall permitted** to frame it.

**BUILD ORDER IS LAW** (he corrected me on this — I briefed it backwards):
1. Outline on the ground · 2. ALL PROPS inside it · 3. **HARD GATE, he rules** · 4. only then
"make the shapes legit" (walls, roof, frame sized to the contents).

Built: kitchen (2 ranges, crate prep), serving counter (2 folding tables, 4 mermites), tray
stack at the left end, wash drum, bussing table, one back wall. Chow line as a **traverse**:
5 `work_queue` @ 0.70 m → `work_mess` serve → `work_trayreturn`.

**Open at wrap** — dining tables + seat markers, so the whole loop reads. Marker names awaiting
his ruling: **`work_queue`**, **`work_trayreturn`**, proposed **`work_eat`**. The Godot side
must match exactly.

### Reference read from his footage (CriticalPast mess line, frames pulled with ffmpeg)
- Food sits in **large round open pots on a long trestle table**; servers stand behind in white
  T-shirts working **long-handled ladles and tongs**.
- **The tray is held, never set down** — flat, two hands, waist-to-chest, presented to each
  server, then a sideways shuffle.
- **The tray genuinely fills as it travels** — his progressive-fill idea is literally what the
  footage shows. Food: mashed potato, green beans, meat patty, sliced white bread, cake square.
  Author `fb_food_tray` as `tray_base` + `food_01..04` as SEPARATE named meshes so Godot toggles
  visibility per station.
- **End of the loop is a rack of galvanised wash cans**, not a bussing table.
- Men eat seated AND standing, often with their hands.

## TWO THINGS THAT NEED A DECISION TOMORROW
1. **The file tripled: 18.69 → 58.92 MB.** The agent appended `PSXRig` plus **177 actions and
   118 images** for animation authoring. On a disk at 97% full that is a real cost. Decide:
   keep the rig in-file for authoring, or link it and purge. There are also **81 orphan meshes**
   to purge.
2. **`WORKBENCH_hq_bunker` is EMPTY.** Its object was deleted during the props-first re-order —
   my scope-change message ("leave the HQ alone") landed after it had already stripped. **The
   mesh data survives as the orphan `hq_bunker_layout_mesh`**, so it is recoverable, and it was
   only a 204-tri layout. Its design notes: built UP not dug in (Caleb: *"the hq building has
   stairs that go under the bunker... we should have them going up"*), steps climbing to the
   door, raised revetted pad like the medical complex.

## STILL OPEN (not started)
- **Hooch rework** — brief written, `WORKBENCH_hooch` not created. From his two photos: heavier
  free-standing revetment 1.5–1.8 m with rounded returns, screen infill from revetment top to
  eave, partly-closed gable ends carrying the door, overhanging tin roof, tight row spacing.
- Tiered lower firebase (own gate, convoy staging, motor pool) — ruled 8/2, not begun.
- Godot side: nothing consumes `work_bunker`, `work_gun`, `work_queue`, `work_trayreturn`.
  `work_gun` deliberately maps to nothing (`site_planner.gd:819`) because the only consumer
  would spawn 20 M60s. Needs a howitzer-crew occupation and a bunker-rifleman occupation.
- `fb_bunker_fighting_i.007` (gate flanker, 207.9°) sits too low: no revetment fits (−0.15 m)
  and its first tread is 0.39 m, above the step limit. Raise ~0.5 m and re-run the pass.
- Orphan `hq_door` / `hq_door_approach` empties still parented to `medical_complex` near
  (58, 4.3), pointing at a building that no longer exists.

## METHOD NOTE — worth keeping
Ray-probing thin or curved geometry from bounding-box guesses gives **false readings**. It
produced three false alarms in one session ("81 parapet segments floating", then 54, then
"11 bunkers in open air") — none real. Use `mathutils.bvhtree.BVHTree.FromPolygons` +
`find_nearest` for exact standoff. Note `fb_berm_ring` is an OPEN ribbon, so
`closest_point_on_mesh` cannot build for it at all.
