# ADR-043: The modular world kit — parts that carry their own data, placed in the engine that renders them

**Date:** 2026-09-09 · **Status:** ACCEPTED by direct Summoner decree, **AUTHORISED — NEAR-TERM**
**Extends:** ADR-041 (authored places) from villages/temples to the firebase, and thaws the parts of its
FROZEN list this work needs · **Depends on:** ADR-028 (one world build path), ADR-039 (zones, one
builder), ADR-010 (one seed), ADR-023 (fossil law), ADR-042 (the naming contract) ·
**War Room:** `production/war_room/2026-09-09_firebase_kit_pivot/`

---

## Context

The Summoner ruled this mid-council, in his own words, in this order:

> *"i do think the best move is to dissect all the whole parts that weve made the firebase out of and
> than make the world firebase in godot with the terrain editor tool and model placing thing i purposed
> ... that means we need individual model builds with the work points and animations saved to those
> locations and certian npcs thatll spawn with certian building combos etc and that way we can remove
> people falling thru berms and stuff that weve made and itll look more intergrated into the world."*

and then, settling the timing question the council had been asked to answer with evidence:

> *"but even before that we should make a modular world building tool kit"* ·
> *"and turn the firebase into model pieces we can build sets with"* ·
> *"so i actually would want to make a better bunker"* ·
> *"and we need a better hq that doesnt have floating lightbulbs"* · *"and a better gate house."*

**"Even before that" means before the post-demo progression work.** ADR-041 ruled authored places
POST-DEMO / BUILD NOTHING on 2026-09-06; **this ADR is the Summoner thawing that, by name, for the
firebase and for a general kit.** ADR-041's anti-creep rule, its ten contracts and its determinism
hazards all survive intact and bind this work.

### The justification of record — and what it is NOT

**IT IS THE LIGHTBULB.** A single misplaced bulb in the HQ cannot be moved without re-exporting a 43 MB
monolith. In this session, a `-colonly` suffix in the wrong position on **one ammo crate** required a
Blender re-export and a permission prompt against his live art source. `fb_aid_station` matches zero
nodes because the asset was renamed to `medical_complex` inside the bake. `fb_sbg_seg_046_001` is a
Blender `.001` duplicate shipping invulnerable among 80 destructible twins. **Each is a five-second
edit trapped behind a forty-minute pipeline.** In a kit, a bulb is a placed object.

**IT IS NOT THE FIVE PLAYTEST DEFECTS.** The council measured every one and records, so that this ADR
can never be cited for them: **the kit fixes none of the five.** The ladder wedge was a missing
clearance test. The stacking is that no NPC avoids any other NPC. The Huey is a missing stagger. The
convoys he parked himself. The roads are built, painted, and invisible for two arithmetic reasons.

**IT IS NOT WW1.** The franchise is post-demo-launch by his own ruling. The binding test is stated here
so it can still say no: **the Vietnam work must be worth it on its own merits; if it is, the second war
is a bonus; if it is not, WW1 rescues nothing.**

**AND IT IS NOT "REMOVE PEOPLE FALLING THRU BERMS" — that benefit is FALSE AS STATED**, and §5 records
what is actually required.

## Decision

### 1 · THE GOVERNING LAW, extending ADR-041's

> ## **A PART CARRIES ITS OWN DATA. A PLACE IS A LIST OF PARTS. THE GROUND IS NEVER COMPOSED.**
>
> A part declares its own work points, its own crew, its own clips and its own footprint. A site is a
> **plan** naming parts and transforms — never a composed `.tscn`, never a second placement path. The
> planner still keeps WHERE and WHETHER. ADR-041's anti-creep rule is unchanged: **an authored artifact
> may not know its own world position.**

### 2 · THE ONE PATH IS NOT TOUCHED, AND THE MIGRATION SHRINKS THE INPUT

**Not a flag. Not a parallel builder. Not a parked-but-built scene** — which ADR-041 forbids by name
and of which `FieldDirector.SLEEP_POST_LAUNCH` is a live specimen.

> **Per family, in ONE commit: re-export the monolith MINUS family F, stamp F from the kit under the
> same wrapper root, delete the repair code that existed for F's baked form.**

One path whose input set shrinks by one family per commit. **Revert is one command
(`reexport_firebase_v3.py`), not a code revert.** The game is playable at every commit by construction:
a family not yet migrated is simply still in the bake.

**The mechanical test any proposed phase must pass, adopted from the Devil's Advocate:**
> *does this phase's deliverable change what the player sees in the demo build? If no, it is
> parked-but-built, and it is refused.*

Three facts make this legal rather than aspirational:
- `FSB_MAIN_PATH` is **`res://scenes/world/firebase_main.tscn`** (`site_planner.gd:946`) — a 13-line
  scene instancing the GLB and carrying hand-placed markers, on his 2026-07-29 ruling, whose own
  comment already settles ADR-028: *"the build instances this scene exactly where it used to instance
  the GLB."* **The docking point exists.**
- `SitePlanner._wire_m101_rigs()` (`:846-866`) already performs the swap once, in production — find the
  baked node by name, hide it (never free it, its `-colonly` colliders stay live), instance a separate
  kit GLB at `baked.global_transform`, warn on zero matches. **Its limit is named: it swaps VISUALS
  only, which is why shrinking the export is the honest version.**
- **14 systems survive a kit unchanged and there is exactly ONE hard break.** Siege breach scan,
  perimeter measure, sapper targeting, nav collider seeding, blast bus, bunk spawn, helipads, screen
  doors, ladders and siren all read **GROUPS or name PREFIXES, never the root.** The break is
  `nav_baker.gd:204` taking `nodes[0]` — one line, fixed by a single `Node3D` wrapper.

> **ADR-042's naming contract, which looked like this pivot's biggest liability, is what makes it
> survivable: names are portable, roots are not.**

### 3 · TWO VERBS, NOT ONE — STAMP and DRAW

The GLB is **5,810 nodes, 4,572 of them scene roots, only 423 with children — a flat bag.**

| tier | verb | contents |
|---|---|---|
| **1** | **STAMP** | ~15 classes, ~78 placements: hootch ×22, supply_dump ×11, fighting_bunker ×8, latrine ×6, gun_pit ×6, mg_bunker ×4, tower ×4, sleeping_bunker ×3, gp_tent ×3, water_point ×3, burn_barrel ×3, helipad ×2, toc/mess/medical/gate_gap ×1 |
| **2** | **DRAW** (polyline) | sbg_seg ×81, sandbag_parapet ×32, claymore ×17, bunker_steps ×12, trench_run ×8 |
| **3** | sealed inside its part | 545 interior props, 300 `MC_*`, 229 `prop_*`, 216 `m101_*` |

**BINDING: DRAW reuses `RoadNetwork._seat_and_resample`.** A second polyline resampler is the
divergent-systems failure this project already names.

### 4 · THE PART CONTRACT

```gdscript
class_name SitePart extends Resource
@export var part_id: StringName          # "hooch", "mortar_pit", "gate_house"
@export var model: PackedScene
@export var footprint: Vector2           # feeds CollisionTable + NavBaker
@export var stations: Array[Dictionary]  # [{local, work_type, role}]
@export var crew: Array[Dictionary]      # [{role, occupation, n}]
@export var demands: Array[StringName]
@export var supplies: Array[StringName]
@export var clips: Dictionary            # work_type -> clip name
@export var terrain_op: StringName       # flatten | cut | none
```

**Building combos emit POST REQUESTS into the existing `fsb_garrison_plan()` list. `Civilian.spawn`
stays the one door (ADR-028). There is no second spawn authority.**

**Half of this already exists on disk and no game code reads it:** `firebase_set.json` (2026-07-26) is
**23 parts with markers carrying `work_type`, `prop_class`, `door_width`, `face` and local `pos``;
`firebase_v3_destructibles.json` carries all **80 wall positions** (the code reads only name/kind/hp);
`gen_firebase_v3.py:709 STATION_PLAN` carries per-part stations for **19 families**; and
`gen_firebase_v3.py:503-522` is already a collision-aware `place(master, pos, bearing)` stamper.

> **The kit was killed in July by the fossil law for having no consumer** — `gen_firebase.py:1-13`,
> *"24 files with one consumer, which ADR-023 would correctly come for."* **BINDING, because it cuts
> both ways: the consumer (the tool + `stamp_site_plan`) ships BEFORE the part masters multiply, or
> ADR-023 comes for them again.**

**DOORS THAT MUST STAY OPEN** for the post-demo solo-player pivot, whose primitives are the same:
`stations`/`crew` are **data on the part, never code in the planner**; `demands`/`supplies` are
**strings, not enums**, so a new NPC role never needs a code change; **a part must be placeable with no
firebase around it**, or villages and temples cannot reuse the kit and ADR-041 Tier B stays unbuilt.

### 5 · THE TOOL: an in-game dev mode writing a JSON site plan

**An `EditorPlugin` is refused, and the fact is decisive rather than stylistic.**
`scenes/levels/game_world.tscn` is **six lines and one empty `Node3D`**; every world node is built in
code at runtime; `TerrainEngine` is not `@tool`; the project has **three `@tool` scripts, all data
Resources, and no `addons/` directory.** **In the editor there is no heightmap, no navmesh, no
vegetation — nothing to brush.** `@tool`-ing the foundation would be *a second execution context for
the world build — ADR-028's named prohibition wearing a costume.*

Precedent exists twice: `tools/cursor_editor.gd` is a game-process authoring tool writing JSON into
`res://`, and the **free-fly camera already ships** (`player.gd:1576-1613`).

**Output is a JSON site plan** — part ids, local transforms, an ordered terrain-op array, markers, and
a declared flatten profile (ADR-041 §6 makes the profile BINDING). **Never a composed `.tscn`**, whose
ten broken contracts ADR-041 §3 enumerates. The decisive argument: **the split already exists** —
`plan_demo_world()` returns a Dictionary that `build_patrol_world()` stamps unchanged. *The tool writes
that dict by hand instead of rolling it.*

**Two constraints recorded now so they are not discovered in week three:**
1. **A TRENCH CANNOT BE A TERRAIN CUT.** `CELL_SIZE = 4.0`; the code already says it in his words at
   `site_planner.gd:1680` — *"A 4m heightmap cannot draw any of that at any setting."* 1 m cells are
   **×16 on every heightmap cost**, refused on the Intel UHD bench. **The cut is a SEAT; the trench is
   a MESH.** And `fb_trench_run` today is `tris=240, size=[6.0, 2.85, 0.45], enterable=FALSE` — 0.45 m
   tall, a parapet spoil lip. **The trench module is genuinely missing.**
2. **Half the edit cost is vegetation and the tool may switch it off.** Of the 81.5 ms rebuild,
   **42.5 ms is `terrain.veg_generate`.** Null the veg manager during a stroke, regen on mouse-up.

**BINDING (ADR-041 §2 hole, closed here): `res://tools` is NOT scanned by
`tests/test_placement_paths.gd:38`.** A tool script calling `place_structure(` would pass the probe
silently. **That scan is extended to `res://tools` in the same change that lands the tool**, and any
tool script that draws randomness joins `SEEDED_FILES`.

### 6 · THE ACCEPTANCE TEST IS THREE PIECES, NOT A KIT

**A better bunker · a better HQ with no floating bulbs · a better gate house.** Build the tool far
enough to produce those three and no further. **The gate house is built LAST because it is the one that
proves the data model:** a gate brings a guard post, a work point, an animation, an NPC who belongs
there, a road arriving, and **a gap in the wire that both the defensive doctrine and the sapper breach
chain read.** If a part can carry that, it can carry anything.

> **BEFORE ANY BULB IS CHASED:** establish whether the bulbs float in the **source bake** or whether
> tonight's interior-prop fold (545 props → 69 MultiMeshes, commit `d904fd70`) moved them. The
> 2026-08-30 audit measured *"hanging bulbs (+7.8 m)"* as **correctly** above the terrain heightmap,
> because inside the firebase **the model is the ground**. Measure a bulb against its own ceiling.

### 7 · THE GROUND IS A SEPARATE, IRREVERSIBLE DECISION — AND IT IS THE ONE THAT FIXES THE BERM

**"Remove people falling thru berms" is FALSE as a benefit of the kit, and this ADR says so.** `berm()`
sweeps `fb_berm_ring` as **two quad strips — no bottom face, no end caps.** A `ConcavePolygonShape3D`
has no interior; forcing backface collision makes both faces solid but **gives the shell no volume**. A
stamped `fb_berm_arc` from the same code has the identical hole **with 81 seams instead of 1.** The
compound's ground **IS the model**, one-sided, force-flipped ~1,900× at boot, and the navmesh bakes onto
it — which is why NPCs fall too.

**The fix is his own terrain proposal used as a repair: the heightfield owns collision; the mound mesh
becomes visual-only.** This is a Summoner call (see §9 Q1) and it is **the only step in this ADR that
is irreversible.**

> **BINDING: the ground phase ships as TWO commits.** `fb_terrain_mound` **is the floor**, and also nav
> ground and blast-proof, and deleting it **fails silently by putting the player 3.4 m under the
> world.** Terrain reproduces the mound first — `fsb_mound_height()` is **already ported and reads the
> manifest; it was turned off, not deleted** — **verified with him standing on it**, and only then is
> the mesh floor stripped.

### 8 · THE PHASE ORDER

P0 marker data to disk *(deletes 82 lines and a full duplicate scene build already happening in the
demo's own load path)* · P1 wrapper root + `nav_baker` one-liner + **the marker-vs-navmesh probe
ADR-041 §5 already makes BINDING** · P2 the tool, minimum viable · P3 the three proof pieces ·
**P4 PARAPET FIRST** (80 positions already on disk; deletes 62 lines) · P5 emplacements/towers/bunkers ·
P6 marker + garrison re-base *(484 lines — the one non-atomic commit)* · P7 buildings + interiors
**(benched first — see §9 R1)** · **P8 THE GROUND, two commits, behind his ruling** · P9 fossil deletion.

**43–67 h engineering, 60–91 h all-in** for the kit; **90–145 h** including the terrain morph tool.
Calibrated two ways against ADR-041 §12's 20–31 h, agreeing within 12%.

> ## STATUS 2026-09-09: P0, P1 AND P2 ARE BUILT AND PROBED. Stopped before P3 by instruction.
>
> - **P0** — `data/world/fsb_markers.json` (14 named markers, 488 work points, 10 dig-classified),
>   written by `tools/bake_fsb_markers.tscn`, read by `SitePlanner._ensure_fsb_markers`. The walk
>   survives as `bake_fsb_markers_from_scene()` with **two callers, the baker and the probe** — one
>   implementation, so a re-export cannot silently disagree with the bake.
>   Guard: `tests/test_fsb_marker_bake.tscn`.
> - **P1** — the `FirebaseCompound` wrapper (`site_planner.gd`, `place_firebase_main`), so
>   `nav_baker.gd:204`'s single-root assumption is TRUE again rather than worked around. `site.nodes[0]`
>   is now the compound. Guard: `tests/test_marker_navmesh.tscn`, which also asserts the wrapper by
>   name and measures **35 posts, 5 off-mesh, worst 1.19 m** against a ratchet.
> - **P2** — `SitePlan` (`scripts/world/site_plan.gd`), `KitRegistry` (`scripts/world/kit_registry.gd`),
>   `SitePlanner.stamp_site_plan()` (**the consumer §4 demanded ship first**), `KitEditorState`
>   (`scripts/tools/kit_editor_state.gd`) and the in-game dev mode `tools/kit_editor.tscn`.
>   Guards: `tests/test_site_plan_roundtrip.tscn`, `tests/test_kit_editor_state.tscn`.
>   **Measured: the registry knows 28 parts, 7 are placeable today, 8 carry work stations.**
>
> **0 SCRIPT ERROR on the definitive headless boot.** A note for whoever builds next: adding these
> `class_name` scripts wedged four headless probes until `--headless --import` rebuilt the class
> cache — the project's own validation law names that fix, and it applies to new global classes too.

## Consequences

**Bought.** A misplaced object becomes a five-second edit. Placement defects become visible where the
navmesh is — *"placement is only true where the navmesh is,"* already ratified, and the day that
motivated ADR-041 closed **only** placement defects. ADR-036 ("the fall of the firebase") becomes
buildable: its blocker 1 is verbatim *"the firebase is ONE node… nothing to register, nothing to
damage, nothing to lose."* And a general kit serves villages, temples, camps and a second war later.

**Sacrificed — no free lunches.**

- **R1 · THE DRAW-CALL REGRESSION, and it is the strongest objection raised.** `InteriorPropFold`
  shipped four hours before this ADR: **545 props → 69 MultiMeshes, 1,010 surfaces → 132**, and *"69
  MultiMeshes each span all eleven hooches."* **Stamp the hooches separately and each MultiMesh holds
  ~1 instance** — the batching win is gone **and** the per-node frustum culling the fold measured at
  **+50 draw calls** comes back. **878 surfaces at stake on a permanent Intel UHD bench.** MultiMesh
  cannot rescue it: **there is no `queue_free()` for instance 37, and the kit's parts are by definition
  the destructible ones.** **BINDING: P7 is benched before it is built, and the fold is not undone to
  reach it.** *(Honest both ways: `place_firebase_main` never calls `_apply_visibility_range`, so the
  comparison has never been measured in either direction.)*
- **He loses a base he can navigate without thinking**, bought by the playtesting that found these
  defects.
- **The pacing contract moves** — patrol bands measure from `GATE_POS`, demo sites are bearing-locked at
  185/170 m, and the siege's geometry (treeline ~149 m, rally 150 m, napalm 210 m) is tuned to the base
  that exists.
- **While a family is being rebuilt, the playtest that finds defects cannot run.** This is the argument
  for the strangler phasing and against any big bang.
- **The base may become a LAYOUT instead of a place.** The ring's authored 49.4–96.0 m irregularity is
  what makes it read as dug under fire. **Per-part jitter must be in v1 or it never ships, and he
  authors the first base by hand before any generator exists.**
- **Part-carried markers do NOT close the 488/23 mismatch.** They make it tunable (488 → ~150). The 23
  is arithmetic — `clamp(40 − 17, 0, 24)` — and 209 of the 488 are **19 markers × 11 duplicated
  hooches**: the kit is *undoing a duplication that already happened in Blender.*
- **Content debt multiplies**, and art is already the binding constraint.

## 9 · OPEN CALLS FOR THE SUMMONER

**Q1 · THE GROUND.** Move firebase collision onto the terrain heightfield, mound mesh visual-only?
**It is the actual fix for men falling through berms, and the kit does not fix that without it.**
**Q2 · Do the three proof pieces come out of the demo's remaining art-days, or after it?**

## Evidence

All verified 2026-09-09 unless marked. Full measurements:
`production/war_room/2026-09-09_firebase_kit_pivot/` (nine analyses, `discussion.md`, `synthesis.md`).

- `scripts/world/site_planner.gd:946` — `FSB_MAIN_PATH` is the `.tscn`, not the GLB (verified).
- `scripts/world/site_planner.gd:846-866` — `_wire_m101_rigs`, the shipped swap (verified).
- `scripts/world/site_planner.gd:935-945` — his 2026-07-29 markers-in-the-scene ruling (verified).
- `scripts/world/nav_baker.gd:204` — `nodes[0]`, the one hard break (council architect).
- `assets/.../firebase/kit/firebase_set.json` — 23 parts with `work_type`/`prop_class` markers; repo-wide
  grep for `firebase_set` returns exactly one hit, `tools/gen_firebase.py:932`, which writes it (verified).
- `tools/gen_firebase.py:1-13` — the ADR-023 refusal, *"24 files with one consumer"* (verified).
- `tools/gen_firebase_v3.py:503-522, 1041-1045, 709` — the existing stamper, masters and `STATION_PLAN`
  (council architect).
- `scenes/levels/game_world.tscn` — six lines, one empty `Node3D` (council architect).
- `tests/test_placement_paths.gd:38` — `res://tools` unscanned (council architect).
- `site_planner.gd:1680` — *"A 4m heightmap cannot draw any of that at any setting"* (council architect).
- `PERF_LEDGER.md:1582-1586` — 42.5 ms of the 81.5 ms rebuild is `veg_generate` (council architect).
- Commit `d904fd70` — the interior-prop fold, 545 → 69 MultiMeshes, 1,010 → 132 surfaces (verified).
- `ADR-036:34-47` — *"the firebase is ONE node"* (verified).
- `ADR-041` §3 (ten contracts), §5 (marker probe BINDING), §6 (flatten profile BINDING), §12 (price).

## Related

- **ADR-041** — extended and partially thawed; every one of its guards survives.
- **ADR-028 / ADR-039** — one build path and one builder, both untouched by §2.
- **ADR-023** — the fossil law, which §4's consumer-first ordering exists to satisfy.
- **ADR-042** — the naming contract; §2 records that it is what makes the migration survivable.
- **Pillars served:** 2 (Atmosphere — a base that fits its hill), 3 (Freedom — defended; authored
  geometry is not a rail, per ADR-041 §10), 5 (Fail forward).
