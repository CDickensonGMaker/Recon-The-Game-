# PLACEMENT PIPELINE MAP — the post-export re-verification checklist

**Written 2026-08-04 (Overseer), for the firebase GLB re-export he is about to make.**
Purpose: when the new `fsb_main_v3.glb` lands, run down this sheet instead of re-diagnosing
rooftop spawns and the squad pen from scratch. Every pointer verified against the tree this
day. ANALYSIS ONLY — nothing here was changed against the current geometry (W-12 items 5/6
are re-judged on the NEW base, not patched on the old one).

**Architectural fact that frames everything:** the world never instances the GLB directly.
`SitePlanner.FSB_MAIN_PATH = "res://scenes/world/firebase_main.tscn"` (`site_planner.gd:659`)
wraps it. The hand-authored `spawn_bunk_01/02` markers live in the **.tscn**
(`scenes/world/firebase_main.tscn:9,12`) — a re-export cannot delete them, but it CAN move
the hootch out from under them, and nothing checks (`game_flow.gd:140-170` uses them raw,
no floor probe).

---

## 1. The pipeline, stage by stage

### Stage A — marker harvest (site_planner.gd)
- `_ensure_fsb_markers()` `site_planner.gd:887-927` — instances the scene ONCE into a
  `static var` cache. Curated markers resolve by **exact name** via
  `find_child(key, true, false)`; a missing/renamed marker is a silent `continue` (:894-895).
- `FSB_MARKER_KEYS` `:780-788` — the 16 exact names: `SOCKET_A_001`, `SOCKET_B_001`,
  `FACE_OUT_001`, `mg_fire_point_001`, `bunker_los_point_001`, `tower_los_point_001`,
  `GUN_POINT_001`, `USSupplyDepot_001/_007`, `FOOTPRINT_001/002/003/004/007`,
  `APPROACH_001/002`. **The `_001`/`_007` ordinals are part of the contract** — a Blender
  renumber silently reshuffles which building is which, or drops posts entirely.
- Work markers: full-tree sweep of every Node3D named `work_*` (`:902-920`). Suffix strip
  at `:916-919` removes one trailing `_<int>` only (glTF import turns Blender `.001` into
  `_001` before this runs). Sorted X-then-Z (`:921-926`) — marker positions decide job
  assignment order deterministically.

### Stage B — the garrison plan (site_planner.gd)
- `fsb_garrison_plan(center)` `:932-1028`. Curated posts from `FSB_GARRISON_POSTS`
  (`:793-807`, 13 posts / 15 men); missing marker = post skipped, never relocated.
- **AUTHORED Y IS KEPT** (`:940-944`, the 2026-08-04 roof fix) — the marker's Y IS the
  floor it stands on. This is the single strongest geometry assumption in the pipeline.
- Budget: `FSB_GARRISON_MAX_MEN 40` (`:863`) − 15 curated = 25, clamped to
  `FSB_WORK_POST_CAP 24` (`:873`). Round-robin **by work TYPE** in `FSB_WORK_PRIORITY`
  order (`:848-855`); an unknown type appends to the tail and maps to `off_duty`
  (`:823-841` occupation map) — **no warning**.
- Aid station seeds only if ≥2 `work_medic*` markers exist (`:982-989`); litter team wants
  a 3rd (`:996-1000`). Quarters round-robin over `FOOTPRINT_001/002/004/007` (`:811-813`).
- Gate: midpoint of `SOCKET_A_001`/`SOCKET_B_001`, outward agreed with `FACE_OUT_001`
  (`fsb_gate_metrics` `:1031-1045`). Missing sockets default to `Vector3.ZERO` — the gate
  **silently collapses onto the compound origin** and the whole ADR-029 wire loop
  (`field_director.gd` `patrol_gate_pos`, `WIRE_GATE_M 120` / `WIRE_RETURN_M 95`) aims at
  the middle of the base. Zero output when it happens.

### Stage C — seating (who turns a marker into a standing man)
- `GameWorld.surface_y(at)` `scripts/levels/game_world.gd:404-423` — TOP-DOWN ray from
  `terrain+18m` (`SURFACE_PROBE_UP` `:428`) to `terrain−2m`, **mask 1, first hit wins ⇒
  hits roofs**. Miss prints `[SURFACE_Y] no collider found probing down from ...`.
- `GameWorld.floor_y(at, reach=3.0)` `:436-445` — SHORT probe `at+0.4m` down `reach`,
  mask 1; **requires the caller's Y to be meaningful** (the authored marker height).
  Falls back to `surface_y` SILENTLY on a miss — markers re-authored at y=0, or a marker
  >3.4m above its floor, put the garrison back on the roofs with no log line.
- Seated through `floor_y` (the 8/4 fix): squad ring `squad_system.gd:75`; garrison men,
  their working points, quarters, litter team, MG emplacement
  (`mission_generator.gd:935,942,944,965,970,974,992`).
- **Still on `surface_y` — the rooftop-spawn suspects for W-12 item 5:**
  - `field_director.gd:41-46` — **every tracked enemy** (`surface_y(pos)+0.5`).
  - `terrain_watchdog.gd:57,61-64` — LOD resume + fall-through catch **re-seats via
    surface_y**: a garrison man who LODs out past 210m and back can be re-roofed even
    after a correct spawn. This can UNDO the floor_y fix over a long session.
  - `litter_team.gd:169-179` — the team's per-frame walk ground.
  - `game_flow.gd:696` — save-restore player reseat (guarded by `had_save`).
  - `seat_system.gd:507-518` — heli dismount ground (own 10m ray, layer 1).
- `civilian.gd:801-812` `place_for_current_hour()` — **teleports to
  `working_point_pos`/`home` trusting marker Y absolutely** (no probe). Runs at spawn and
  on LOD wake. Whatever Y the plan carried is where the man stands.
- `heli_lift.gd:250-256` — delivered replacements get home/working point on a 10-22m ring
  around `fsb_center` at **pad height**, not floor-probed.

### Stage D — squad spawn
- Bunk: `game_flow.gd:137-205` — `spawn_bunk*` (.tscn, trusted raw) else nearest viable
  `prop_sleep*` (GLB, floor-rayed 0.4m up / 3.0m down, mask 1).
- Ring: `squad_system.gd:67-75` — 8 men at 3.5m radius around the bunk, each
  `floor_y(pos)+0.5`. A hootch narrower than ~7m puts part of the ring outside the wall;
  those points seat on whatever the short probe finds there.
- **Boot probe (ships):** `squad_system.gd:101-115` —
  `[SQUAD] spawn <MOS> at (x, y, z) - N/4 dirs blocked` (four 0.6m `test_move` probes).
  - Healthy: `0/4` or `1/4` per man (seed 29072026 measured 0-1/4 on 2026-08-04).
  - Sick: `4/4` = spawned inside a pen/wall.
  - **Blind spot: a roof spawn reads 0/4.** Judge roof-vs-floor by the printed Y against
    the bunk's Y, not by the blocked count.

### Stage E — nav
- `nav_router.gd:37` `CLAMP_MAX_M 12.0` — a target ≥12m off the mesh is passed RAW
  (guaranteed no-path → direct steering). `:115-121` prints the one-shot
  `[NAV] <agent> on <region>, N.Nm to target, no path - falling back to direct steering`
  (debug builds). Count these per boot; the A1 baseline was 8, post-fix expectation is ~0.
- `nav_baker.gd:42-46` — firebase bake box `FSB_HALF 185.0` (independent of
  `site_planner.FSB_HALF (149.3, 111.2)` at `:664` — **a larger compound needs BOTH
  raised**), `AGENT_RADIUS 0.5`, `AGENT_HEIGHT 1.8`.
- `nav_baker.gd:366` `NAV_IGNORE_PREFIXES = ["fb_veg_", "fb_int_"]` — colliders under
  parents with these names are EXCLUDED from the bake. **Rename either family and the
  bake ingests them, shredding the compound into navmesh islands** (the 7/29 "no path
  from 5m" failure class).
- Healthy print: `[NavBaker] bake done: box=... verts=... polys=... geom=N colliders
  cell=...` then `[NavBaker] M region(s), P polys, T ms total`. `polys == 0` is a
  `push_error`. Compare the firebase collider count across the export — a wild swing is
  the first sign of a convention break.
- Re-bake on destroy exists (`nav_baker.gd:67,193-238`, debounced 1.5s, prints
  `[NavBaker] breach: re-baking ...`) — fresh-navmesh law satisfied for breaches.

### Stage F — pads / lift
- `air_traffic.gd:64` `FSB_PAD_PREFIXES = ["PSPHelipad", "fb_helipad"]` (prefix match);
  `PAD_DISTINCT_M 12.0` de-dups co-located markers (`:59`, drop print at `:660`). Today's
  truth: three pad-named nodes, ONE position ⇒ one LZ. **The second pad he builds must sit
  >12m from the first and keep a matching prefix.** Zero pads = loud
  `push_warning("[AirTraffic] firebase carries no pad marker matching ...")`.
- `seat_system.gd:19-49` — seat sockets by EXACT name (`seat_pilot_l/r`, `seat_gunner_l/r`,
  `seat_pax_1..7`) anywhere under the vehicle; GLB empties import as plain Node3D. Door
  staging = `seat_gunner_l` + local +Z × 2.5m (`:416-423`). Boarding arrival gate is 8.0m
  XZ **to the airframe**, never the staging point (`:69`, `:367-369` — measured lesson,
  2026-08-04). Healthy: `[SEATS] boarder at the door after ~N.Ns walk - mounting` →
  `[SEATS] boarder seated in seat_pax_N`.

---

## 2. Boot instruments — healthy vs sick

Run the headless boot (or his live boot) and read these lines in order:

| Instrument | Healthy | Sick |
|---|---|---|
| One-ground audit (`site_planner.gd:_audit_one_ground`, tolerance 0.6m, reads `fsb_main_v3_mound.json`) | `[FSB] ground: 129 samples, terrain sits under the model everywhere (worst +0.00m)` | `[FSB] TERRAIN POKES THROUGH THE MODEL: ...` or `push_error` **mound manifest missing** — the `_mound.json` must ship WITH the GLB |
| Mound collider | `[FSB] kept N mound collider(s) - the MODEL is the ground` | `[FSB] the GLB carries NO mound collider - fb_terrain_mound must be on COL_TRIMESH...` — everything downstream sinks |
| Winding repair (`_force_backface_collision`) | `[FSB] 0 concave shape(s) forced double-sided` — the Blender normal-flip landed | A large count = the GLB still winds inward; the runtime repair hides it, but the export did not honor trimesh-faces-up |
| Box-hull remesh | `[FSB] replaced 0 box hull(s)` (or line absent) | A large count = generator-side collision fixes not in the export |
| Floating colliders | no `[FSB] N collider(s) floating >3m` line at all | Any such line — bad pivots/import scale (the invisible veg-slab class) |
| Interior props | `[FSB] 178 interior prop(s) culled past 40m` (count in that region) | `0` = `fb_int_` renamed ⇒ ALSO poisons the navmesh via `NAV_IGNORE_PREFIXES` |
| Claymores / parapet / ladders / towers | `[FSB] 16 claymore(s) armed...` · `[FSB] parapet: 80 destructible segment(s) on the blast bus` · no ladder/tower warnings | `no fb_claymore` silence, `no destructibles manifest`, `no ladder_bottom/ladder_top pairs`, `no fb_tower_i meshes - no alarm` |
| Surface probes | no `[SURFACE_Y]` warnings | `[SURFACE_Y] no collider found probing down from ...` = layer-1/collision loss |
| Squad pen probe | `[SQUAD] spawn <MOS> at (...) - 0/4 dirs blocked` ×8, **Y within ~1m of the bunk's Y** | `4/4` blocked (pen), or Y meters above the bunk (roof — the probe itself cannot see this) |
| Spawn truth | `[SPAWN-TRUTH] ... delta=~0 ... top_hit=fb_terrain_mound...` | large `physics_y` vs `array_y` delta (the 8/2 inverted-mound signature) |
| Nav | `[NavBaker] bake done ... geom=N colliders`, few/zero `[NAV] ... no path` warnings | `0 polygons` error, collider count swing, `[NAV] no path` flood (the A1 baseline was 8) |
| Pads | one LZ today; TWO after his dual-pad export | `[AirTraffic] firebase carries no pad marker matching ...` |
| Stand-to / lift | `[FSB] stand to: promoted N ...` · `[LIFT] inbound/delivered ... garrison N/40` | promoted count collapsing across nights, `[LIFT]` never delivering |

**Silent failures — no log line exists; check by eye or add a probe before trusting:**
1. Renamed/renumbered `FSB_MARKER_KEYS` entry (skipped post, reshuffled quarters).
2. Missing `SOCKET_A_001`/`SOCKET_B_001`/`FACE_OUT_001` — gate collapses to origin,
   patrol loop dead, zero output.
3. Renamed `work_*` type — men silently become `off_duty` statues.
4. <2 `work_medic*` markers — aid station never seeds.
5. Markers authored at y=0 — `floor_y` silently falls back to `surface_y`, roofs return.
6. `spawn_bunk_01/02` (.tscn) vs moved hootch geometry — player spawns in air/wall.

---

## 3. The export-side contract (what the new GLB must honor)

Plain words, for the Blender bench:

1. **One ground** (memory `recon-firebase-one-ground-law`): `fb_terrain_mound` stays ONE
   continuous watertight trimesh on COL_TRIMESH; interior floors have real thickness and
   collision in the same authority; **re-export `fsb_main_v3_mound.json` in the same
   action** (`gen_firebase_v3.py::write_mound_manifest` writes it) — the runtime errors
   without it. Never a manual File→Export glTF: collision twins are export-time only, a
   manual export ships NO collision at all.
2. **Trimesh faces UP** (memory `godot-trimesh-must-face-up`): walkable faces wind +Z in
   Blender. `backface_collision` defaults false — a down-facing floor is walked through
   silently. Check with the Face Orientation overlay / normal count, fix with Flip (NOT
   Shift+N on the open mound sheet). The runtime's double-side repair will mask it; the
   boot line `0 concave shape(s) forced double-sided` is the proof it was fixed at source.
3. **Names are the API.** Keep exactly: `fb_terrain_mound`, `fb_veg_*`, `fb_int_*`,
   `fb_sbg_seg_*`, `fb_tower_i*`, `fb_claymore*`, `fb_helipad*`/`PSPHelipad*`,
   `work_<type>[_NNN]`, `prop_sleep*`, `ladder_bottom*`/`ladder_top*`, and the 16
   `FSB_MARKER_KEYS` **with their current ordinals** (`SOCKET_A_001`, `FOOTPRINT_007`, …).
   The `-colonly` pairing convention (`<mesh>_{NNN}-colonly`) is load-bearing for the
   veg/parapet remesh.
4. **Markers carry their floor's Y in object space** — authored against the COLLIDER
   (`verify-in-object-space`), never eyeballed against the visual mesh, and never left at
   y=0. Every consumer trusts marker Y since the 8/4 fix. Regrade the mound ⇒ re-place the
   markers in the SAME session. `spawn_bunk_01/02` live in `firebase_main.tscn` — if the
   hootches move, those two must be re-authored by hand in Godot.
5. **The second helipad** sits >12m from the first (`PAD_DISTINCT_M`), prefix
   `fb_helipad`/`PSPHelipad`, authored Y on the pad surface (LZs use marker Y raw).
6. **Chow hall**: grab **only the `WB_chowhall` root** (memory
   `chowhall-is-welded-to-its-root`); the chow `work_*` families are already mapped in
   code and gated on M-1's histogram — run `tests/test_firebase_garrison.tscn` FIRST
   after import (the dot-suffix question dies there).
7. **Footprint growth**: if the compound outgrows today's bounds, raise BOTH
   `site_planner.FSB_HALF (149.3, 111.2)` (`:664`) and `nav_baker FSB_HALF 185.0`
   (`:44`), and check `FSB_FLATTEN_RADIUS 215` — three hardcoded twins of the mound size.
8. **Ballistic material rides the mesh-family NAME** (Summoner ruling 2026-08-04, at the
   gun range: shooting-through must work on the game world's buildings). At load,
   `site_planner._tag_fsb_ballistics` (`site_planner.gd`, after `_repair_glb_colliders`)
   puts every firebase collider in a bullet group by name prefix — soft (lead punches
   through, ×0.8/layer, 3rd layer stops): `fb_hootch`, `fb_gp_tent`, `fb_mess`,
   `fb_aid_station`, `fb_latrine`, `fb_supply_dump`, `fb_water_point`, `fb_burn_barrel`,
   `bwire_card` (list: `FSB_SOFT_PREFIXES`). **Everything else is hard** (stops the
   round): earth, sandbag, timber, bunker, tower, mound. So: a NEW canvas/plywood/tin
   structure must take one of the soft family prefixes (or its prefix must be added to
   `FSB_SOFT_PREFIXES` in the same change); renaming a family silently flips it to
   bulletproof. Boot proof: `[FSB] ballistic tags: 35 soft ... 330 hard` (2026-08-04
   shipped GLB) — a re-export whose soft count collapses to 0 renamed the tents.

---

## 4. Known pre-existing suspects NOT caused by the export (don't blame the new GLB)

- Tracked-enemy spawns and the terrain_watchdog reseat still use `surface_y`
  (`field_director.gd:41-46`, `terrain_watchdog.gd:57`) — a covered spawn point roofs a
  man no matter how clean the export is.
- MortarPit + armorer bench are placed procedurally at the mound TOE via raw
  `terrain.get_height_at` (`mission_generator.gd:828-841`) — below the compound floor by
  construction.
- `garrison_defender.stand_down` banks the defender's wandered position as tomorrow's
  post (`garrison_defender.gd:109,134-136`) — slow post drift across nights.
