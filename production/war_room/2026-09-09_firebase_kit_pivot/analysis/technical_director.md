# TECHNICAL DIRECTOR — what the firebase-as-stamped-kit pivot COSTS, and whether it can be done
# without the demo ever going dark

**Council:** 2026-09-09 firebase kit pivot · **Arbiter:** the Overseer · **Lens:** technical direction
**Method:** static read of the shipped code, the shipped manifests and tonight's PERF_LEDGER rows.
**No game was run. No process was touched. No file outside this one was written.**

---

## 0 · WHAT I COULD NOT MEASURE, SAID FIRST

Measurement-first means naming the holes before the findings.

1. **I did not time `place_firebase_main()`.** Caleb is in the build (pid 13196); a headless boot runs
   the real `plan_demo_world` → `build_patrol_world` and would have competed for the same CPU and the
   same log. **Every wall-clock claim below is either quoted from the ledger with its date, or marked
   UNVERIFIED.** In particular: the double scene instantiation in §1.7 is a *structural* finding with
   file:line, not a timed one. **Its millisecond cost is UNVERIFIED.**
2. **I did not open `firebase_v3.2.blend`.** It is on the Blender agent's boundary list. Every claim
   about what is inside it comes from `tools/gen_firebase_v3.py`, from
   `assets/.../firebase/kit/firebase_set.json` and from `firebase_v3_destructibles.json`.
   **The claim that every `place()`-instanced building carries a real object transform in the blend is
   READ OFF THE GENERATOR (`gen_firebase_v3.py:503-518`), not off the blend. UNVERIFIED against the
   file.** It is the single assumption the whole extraction phase rests on and it should be checked
   with a 20-line script before a single hour of P1 is spent.
3. **I did not bench a kit-stamped compound.** No draw-call, no frame-time, no load-time number for the
   *after* state exists anywhere. Every perf claim about the kit is a direction, not a magnitude.

---

## 1 · THE CURRENT LOAD PATH, PRICED

### 1.1 The function itself is small. The path behind it is not.

`place_firebase_main()` — `scripts/world/site_planner.gd:1645-1734`.
**90 lines, 34 of them comment, 56 lines of code.**

That number is a trap and it is why this pivot keeps getting under-costed. Measured across the whole
file (script: enumerate `func` starts, diff to the next start):

| | lines | share of `site_planner.gd` (2,758 lines) |
|---|---|---|
| `place_firebase_main` itself | 90 | 3.3% |
| **the firebase LOAD PATH** (28 functions reachable from it) | **1,205** | **43.7%** |
| **ALL firebase-specific code in the file** (35 functions, incl. plan/garrison/markers) | **1,752** | **63.5%** |

For calibration against ADR-041 §12, whose 20–31h buys village + temple:
`stamp_village()` is **120 lines** (`:288-407`) and `_stamp_village_props()` is **46** (`:408-453`).
**The firebase load path is 7.3× the code surface of the entire village stamper.**

### 1.2 What it does, in order (every step file:line)

| # | Step | Where | What it costs |
|---|---|---|---|
| 1 | 7×7 = **49 `get_height_at()` samples** across the footprint → mean seat Y | `:1648-1653` | trivial |
| 2 | `clear_and_flatten()` on `FSB_CLEAR_DISCS` — **one 140 m disc** | `:1673-1674`, discs at `:1061-1063` | stages a `ClearingSystem` zone |
| 3 | `modify_terrain(center, 215 m, lerp→seat_norm)` — the level seat | `:1686-1688` | heightmap edit + chunk rebuild |
| 4 | `_grid.update_region(center, 215 m)` | `:1690-1691` | grid rebuild over a 430 m square |
| 5 | `_audit_one_ground(center, seat_y)` — **57-line audit, every boot** | `:1692`, def `:2053` | pure diagnostic |
| 6 | `load(FSB_MAIN_PATH).instantiate()` — **5,812 nodes** | `:1693-1694` | the real one |
| 7 | `MaterialBudget.structure(root)` | `:1696` | whole-tree material walk |
| 8 | seat: `root.global_position = origin` with `origin.y = seat_y` | `:1698-1702` | — |
| 9 | **`_repair_glb_colliders(root)`** — 107 lines, three full tree walks | `:1703`, def `:1819` | see §1.3 |
| 10 | **`_wire_parapet_destructibles(root)`** — 90 lines | `:1704`, def `:2183` | see §1.4 |
| 11 | `_wire_claymores(root, center)` — 50 lines | `:1705`, def `:2521` | tree walk |
| 12 | `Ladder.build_from_markers(root)` — **must run AFTER the seat** | `:1709` | the §8.1 hazard, already bitten once |
| 13 | `SirenTower.build_from_markers(root)` — matches `fb_tower_i` by prefix | `:1712` | `siren_tower.gd:57` |
| 14 | `_animate_fsb_baked_cast(root)` — 82 lines, the baked cast's clips | `:1715`, def `:724` | |
| 15 | `_wire_m101_rigs(root)` — 26 lines | `:1716`, def `:847` | |
| 16 | `_audit_frozen_bodies(root)` — **41-line audit, every boot** | `:1717`, def `:806` | pure diagnostic |
| 17 | `fsb_gate_metrics(center)` → gate_pos / gate_out / spawn_pos | `:1718` | forces §1.7 |
| 18 | `_stamp_radio(spawn_pos)` then `_stamp_hooch_radios(root)` | `:1723-1724` | 21 + 45 lines |
| 19 | **`_fold_interior_props(root)`** — order-critical, must follow 18 | `:1727` | `InteriorPropFold` |
| 20 | `_fsb_rect` + site dict `{"nodes": [root], ...}` | `:1728-1733` | **one root. See §2.4.** |

Ordering constraints that are load-bearing and stated in the source: **veg clear before sculpt**
(`:1668-1672`), **ladders after the seat** (`:1707-1709`), **hooch radios before the interior fold**
(`:1725-1726`). Any kit assembly must reproduce all three or re-break bugs that are already closed.

### 1.3 The runtime repair, with tonight's counts

`_repair_glb_colliders()` (`:1819-1925`) is the function whose own header says it deletes itself:

> *"When the re-exported GLB lands both counts come back 0 and this whole function is deleted (ADR-023)
> — which is why it reports counts instead of passing silently."* (`:1815-1817`)

Counts from **tonight's** headless boots, both states, `PERF_LEDGER.md:2028-2036`:

| repair | cards build | real-model build |
|---|---|---|
| box hulls replaced (`fb_veg_`, `fb_sbg_seg_`) → re-meshed as trimesh | **86** | 86 |
| concave shapes forced double-sided (inward winding) | **1,985** | **1,984** |
| ballistic tags applied | **1,254 soft / 1,182 hard** | 1,254 soft / **1,181** hard |
| parapet segments wired | **81** (80 manifest + 1 stray adopted) | identical |
| structures on the blast bus | 11 bunker · 9 sandbag_stack · 4 tower · 4 bunker_mg | identical |
| parapet radii from centre | **49.4 – 96.0 m** | identical |

**That is 2,071 collider mutations plus 2,436 ballistic tag decisions, on the main thread, every boot,
to patch an export.** Add the two audits that run unconditionally (`_audit_one_ground` 57 lines,
`_audit_frozen_bodies` 41, `_audit_floating_colliders` 73 at `:1877`, `_audit_parapet_spread` 24 at
`:2261`) — **195 lines of pure diagnostics on the shipping load path.**

**CORRECTION TO THE BRIEFING (No More Drift).** The briefing and `FIREBASE_REWORK_INTENT.md:35` list
*"545 visibility ranges"* among the load-time repairs. **That is wrong twice.** `place_firebase_main`
**never calls `_apply_visibility_range`** — its only two callers are `place_structure:220` and
`place_prop:464` (grep-verified; ADR-041 §7.1 says the same). The 545 figure is **545 `fb_int_` interior
prop nodes folded into MultiMeshes** by `InteriorPropFold` (`:1773-1786`), which is a *fix that shipped
tonight*, not a repair. The firebase draws every structure at any distance, with no 230 m cull, today.

### 1.4 The parapet pass is a reconciliation, not a wiring

`_wire_parapet_destructibles()` (`:2183-2272`) does not just read a manifest. It runs a **two-way
census** because the manifest and the GLB disagree:
- 80 manifest entries → `find_child` → wire (`:2197-2205`)
- then a full tree walk for `fb_sbg_seg_*` meshes the manifest never claimed (`:2211-2219`)
- a stray **co-located within 5 cm of its manifest twin** is a Blender `.001` duplicate → hidden,
  colliders disabled (`:2243-2249`)
- a stray **standing apart** is a real wall → adopted with its twin's kind and hp (`:2251-2258`)

Tonight's boot: **1 stray adopted, 0 hidden.** The `fb_sbg_seg_046_001` defect named in
`FIREBASE_REWORK_INTENT.md:39` is *currently being handled at runtime* by this code.

### 1.5 Why the walls are the specific proof of the thesis

`_wire_parapet_segment()` (`:2304-2363`) carries the sentence this whole council exists because of:

> *"THE MESH NODE'S ORIGIN IS NOT THE WALL. fsb_main_v3 is a flat scene and **80 of the 81 parapet nodes
> carry NO node transform** — the geometry is baked into vertices — so `mi.global_position` is the model
> root for all of them, i.e. the compound centre."* (`:2311-2314`)

The workaround is `_mesh_center()` (`:2297-2303`): read the baked AABB. And `_audit_parapet_spread()`
(`:2273-2296`) exists solely to shout if that workaround ever fails — *"PARAPET COLLAPSED TO A POINT."*

**A stamped segment has a transform by construction. `_mesh_center`, `_audit_parapet_spread`, and the
whole class of "the sappers all targeted 256,256" bug delete themselves.** This is the strongest
technical argument in the pivot and it is not rhetorical — it is 31 lines of workaround plus a 24-line
watchdog that stop existing.

### 1.6 The classification surface is 214 families for 23 part types

`tools/firebase_ballistics_baseline.json:2` — **`"families": 214`**, against **23 part types** in
`assets/.../firebase/kit/firebase_set.json`. Every one of those 214 is a name that
`_tag_fsb_ballistics` must either match against `FSB_SOFT_PREFIXES` (`:1934-1971`, a 40-entry hand-grown
list) or default to **hard = bulletproof**. That is ADR-042's bug class at its worst site in the project.

**A kit classifies once per master — 23 decisions, authored where the mesh is made.** The open set
becomes closed.

### 1.7 THE FIREBASE SCENE IS INSTANTIATED TWICE PER WORLD BUILD

Found while tracing, not looked for. `_ensure_fsb_markers()` (`:1320-1401`):

```
:1322   var scene: PackedScene = load(FSB_MAIN_PATH)
:1323   var inst := scene.instantiate() as Node3D
...     [walks the whole tree for FSB_MARKER_KEYS, work_* prefixes and EARTHWORK_FAMILIES]
:1401   inst.free()
```

It is guarded by a static cache (`:1321`), so it runs **once per process** — but it runs **before**
`place_firebase_main`, because `fsb_gate_metrics()` calls it (`:1578`) and
`mission_generator.gd:519` (`plan_patrol_world`) and `:722` (`plan_demo_world`) call
`fsb_gate_metrics` at **plan time**, to derive `gate_pos`, `gate_out`, `insertion_lz` and `exfil_lz`
(`mission_generator.gd:519-525`).

**So a full 5,812-node, 44.6 MB scene is built and thrown away purely to read ~500 marker positions,
and then built again for real at `mission_generator.gd:886`.**

- **UNVERIFIED: the millisecond cost.** I did not time it and will not while he is playing.
- **It is free to fix regardless of the pivot** and it is the cheapest thing in this document:
  the generator already writes marker data to disk (`legacy_garrison_markers()`,
  `gen_firebase_v3.py:822`; `STATION_PLAN`, `:709`). Emitting a `fsb_markers.json` at export and
  reading THAT would delete 82 lines and one whole-scene instantiate.

**This is the single best pre-pivot win available, it is inside the demo's own load path, and it does
not need the kit.** It is also exactly the shape the kit forces anyway (per-part marker data), so it is
work that carries forward 100%.

---

## 2 · BLAST RADIUS OF REMOVING `fsb_main_v3.glb`

Grepped: `fsb_main_v3` (22 files), `fb_` prefixes, `firebase_main`, `place_firebase_main`.
Verdict column: **SURVIVES** = works on a kit assembly with no code change · **REWORK** = needs code ·
**DIES** = the mechanism has no kit equivalent.

### 2.1 SURVIVES UNCHANGED — everything that reads a GROUP or sweeps the whole world

This is the good news and it is bigger than expected. **The systems built latest are the kit-safe ones.**

| System | Pointer | Why it survives |
|---|---|---|
| **Siege breach scan** | `siege_director.gd:407` | iterates `get_nodes_in_group(FSB_PARAPET_GROUP)`, reads `d.global_position`. Kit parts join the group; positions get *better*. |
| **Siege perimeter measure** | `siege_director.gd:659-680` | same group, bins by bearing. Kit-safe. |
| **Sapper wall targeting** | via the same group + `Destructible` | a stamped segment is a better target than a baked one. |
| **Nav collider seeding** | `nav_baker.gd:490` → `FSB_NAV_GEOM_GROUP` | the group exists *precisely because* reparented shapes leave the model root (`site_planner.gd:2174-2180`). Already root-independent. |
| **Blast bus / AgentRegistry** | `:2354`, `:2499` | registration is per-`Destructible`, not per-root. |
| **Player bunk spawn** | `game_flow.gd:164-176` | whole-world name sweep for `spawn_bunk*` / `prop_sleep*`. |
| **Helipads / air traffic** | `air_traffic.gd:77` `FSB_PAD_PREFIXES` | prefix match anywhere in the tree. Its own comment already records surviving one rename. |
| **Blast-proof ground** | `combat_manager.gd:300` `["fb_terrain_mound","fb_berm_ring"]` | prefix, tree-wide. |
| **Nav ground / ignore prefixes** | `nav_baker.gd:476, 573, 607-614` | prefix lists, tree-wide. |
| **Screen doors** | `SCREEN_DOOR.wire_all(root)` `:2265` | recursive from root — survives IF the kit shares one wrapper root (§2.4). |
| **Ladders, siren tower** | `:1709`, `:1712` | `build_from_markers(root)`, recursive. Same condition. |
| **Topo map / minimap** | `topo_map.gd:190`, `test_world_minimap.gd:109` | key on `site["kind"] == "firebase_main"`. Untouched. |
| **`_fsb_rect` keepout** | `:55-56`, `mission_generator.gd:526`, `:729` | derived from `center` + `FSB_HALF` constants, not from the model. |
| **Village hut destructibility** | `_destructible_kind_for` `:180-189` | already consolidated to ONE table (`:165-171`). Kit-neutral. |

**Count: 14 systems survive. That is the load-bearing finding of §2.** The project's own consolidation
work over the last six weeks — groups instead of roots, prefixes instead of exact names, one
destructible table instead of two — has already paid most of the kit's integration bill in advance.

### 2.2 REWORK — bounded, each with a named fix

| System | Pointer | Break | Fix |
|---|---|---|---|
| **`_repair_glb_colliders`** | `:1819-1925` | 86 re-meshes + 1,985 winding flips assume ONE tree of ONE export | **DELETE per family as that family migrates.** Masters export with correct collision class and winding. This is the function that was always going to die. |
| **Parapet manifest reconciliation** | `:2183-2272` | `find_child(name)` on the monolith root; the `.001` stray logic exists only because of the bake | shrinks to a stamp loop over `firebase_v3_destructibles.json`; strays impossible |
| **`_tag_fsb_ballistics`** | `:1926-1972` + `FSB_SOFT_PREFIXES` `:1934-1971` | 214-family open set | 23 closed decisions, authored on the master. **Keep the ratchet probe** (`tools/probe_firebase_penetration.gd`) or the migration is unmeasured. |
| **`_ensure_fsb_markers` / `_fsb_marker_origin` / `fsb_garrison_plan` / `_arty_pits`** | `:1320-1401`, `:1078-1084`, `:1402-1576`, `:1268-1302` | **484 lines** built on *model-local marker positions + one origin offset*. A kit's markers are already world-space at stamp time. | re-base to world space at stamp. **This is the largest single rework in the document.** |
| **`fsb_gate_metrics`** | `:1577-1596` | derives gate + LZ from `SOCKET_A/B/FACE_OUT` marker locals | the gate becomes a stamped `fb_gate_gap` part carrying its own markers — *better*, but every plan-time consumer (`mission_generator.gd:519-525`, `:722`) must read them from the layout data, not from an instantiate |
| **`_fold_interior_props`** | `:1790-1804`, `InteriorPropFold` | folds 545 baked copies of 69 meshes | a kit **never bakes the copies**: 11 hooches × 1 interior set become 11 instances of one scene. The fold that shipped tonight becomes unnecessary — but it is a fix that must not be deleted until the last hooch migrates. |
| **`MaterialBudget.structure(root)`** | `:1696` | one call on one root | N calls, or one on the wrapper |
| **`_animate_fsb_baked_cast` / `_audit_frozen_bodies` / `_wire_m101_rigs`** | `:724`, `:806`, `:847` | walk the root for baked figures and M101 skins | survive under a wrapper root; the baked cast is itself a monolith artefact and should migrate to spawned NPCs, not stamped figures |

### 2.3 DIES — the two that have no kit equivalent

**1. `fb_terrain_mound` — THE FLOOR.** This is the irreversible one.

`_repair_glb_colliders:1838-1844` **keeps** the mound collider, with a ruling in the source:

> *"KEPT, not stripped (ruling 2026-07-29). This trimesh IS the walkable ground now."*

and `place_firebase_main:1675-1685` states the other half:

> *"THE MODEL IS THE GROUND (ruling 2026-07-29). The terrain is levelled to the mound's TOE and stops
> there — it does NOT reproduce the mound any more... 'i want that mesh mound because it showed
> destroyed earth and mud, so just moving the world terrain up doesn't fix a lot of problems.' A 4m
> heightmap cannot draw any of that at any setting."*

**Everything the player stands on inside the wire is one ~300 m trimesh baked into the monolith.**
Deleting the monolith deletes the floor. There are exactly three ways out and all three are HIS call:

- **(a) Reverse the 2026-07-29 ruling** and let the terrain reproduce the mound. The machinery already
  exists and is *live*: `fsb_mound_height()` (`:998-1043`, 46 lines) is a line-for-line port of
  `gen_firebase_v3.py::platform_z`, reading `fsb_main_v3_mound.json`. It was not deleted — it was
  turned off. Cost: cheap. Price: the craters and mud go, which is the exact thing he rejected.
- **(b) Keep the mound as ONE kit part** — a `fb_ground_<site>.glb` stamped like anything else. The
  compound stops being a monolith; the *ground* stays authored per site. Cheapest honest answer, and
  it is what "a firebase that fits the hill it is on" costs the least to reach.
- **(c) Build real cut-ground modules** (the trench/berm/crater modules of the tool proposal) so the
  ground is assembled from parts. This is the full vision and the most expensive thing in this
  document.

**2. The 488-vs-23 work-marker mismatch does not "die" — it is CLOSED BY CONSTRUCTION, and the data
already exists.** `FIREBASE_REWORK_INTENT.md`'s open question 3 asks whether work markers should move
onto the parts. **They already did, in July, and nobody wired it.**

`tools/gen_firebase_v3.py:709-740` — `STATION_PLAN`, keyed by part family, 19 entries:
```
"fb_gun_pit":   [("gun", 2, 2.2, 3.6), ("ammo", 2, 4.2, 5.4)],
"fb_toc":       [("radio", 3, 3.2, 4.6), ("plot", 2, 2.4, 3.2)],
"fb_mess":      [("cook", 3, 2.8, 4.0), ("mess", 6, 4.4, 6.2)],
...
```
and `assets/.../firebase/kit/firebase_set.json` — **23 parts, each with `tris`, `size`, `solid`,
`enterable` and a `markers` array carrying `work_type` and `face`.** That file is the kit manifest
Caleb is asking for. It is dated 2026-07-26 and **nothing in `scripts/` reads it** (grep: three hits,
all docs and `tools/gen_firebase.py:932` which WRITES it).

**A part that carries three `work_gun` markers cannot produce 488 markers for a 23-man garrison,
because the marker count becomes a function of the parts stamped.**

### 2.4 THE ONE HARD BREAK: `site["nodes"]` is a single root

`nav_baker.gd:202-207`:
```
func _queue_firebase(site: Dictionary) -> void:
    var nodes: Array = site.get("nodes", [])
    var root: Node3D = (nodes[0] as Node3D) if nodes.size() > 0 else null
    if root == null:
        push_error("[NAV] firebase site has no root node - falling back to a terrain-only
            bake, which paths men straight through the bunkers")
```

**One root, index zero.** Same shape at `:1730` (`"nodes": [root]`). And ADR-041 §3 contract 3 already
names the sibling hazard: Godot auto-renames duplicate node names, so N stamped `fb_bunker_fighting_i`
siblings become `fb_bunker_fighting_i2`, `..._i3` — and **`SiegeDirector`, `SirenTower`, `NavBaker` and
`_tag_fsb_ballistics` all match by `begins_with`, so they survive the rename. `find_child(exact_name)`
does not.** The two exact-name consumers are `_wire_parapet_destructibles:2199` and `:2229`.

**MITIGATION, and it is the whole architectural answer:** stamp every kit part as a child of ONE
`Node3D` wrapper named `fsb_main`, and return `{"nodes": [wrapper]}`. Every recursive walk, every
`find_child(..., recursive=true)`, every prefix match and `nav_baker._queue_firebase` then work
**unchanged**. The wrapper costs one line and converts §2.4 from a break into a non-event.

That is why my phase order below never changes the site dictionary's shape.

### 2.5 What the pivot UNBLOCKS, which is not in the briefing

**ADR-036 "The fall of the firebase" is blocked on exactly this.** Its §1 blocker 1
(`ADR-036:34-36`): *"**The firebase is ONE node.** `site_planner.place_firebase_main` instantiates
`fsb_main_v3.glb` and returns `"nodes": [root]`. Every installation this ADR names is baked geometry
inside a single GLB. **There is nothing to register, nothing to damage, nothing to lose.**"* And
blocker 2: the TOC — *"the fatal objective, the whole stake"* — exists only as a Blender family surfacing
under the alias `FOOTPRINT_003` and consumed as a radioman spawn post.

**A stamped TOC is a node with an identity, an HP pool and a position. ADR-036 §1 blockers 1 and 2 both
close as a side effect of this pivot.** No other work in the backlog closes them. That is a second
payer alongside the WW1 battlefields, and it is a payer inside *this* game.

---

## 3 · THE INCREMENTAL PATH — and what ADR-028 actually permits

### 3.1 The law question, answered directly

**Does ADR-028's one-build-path law permit a second path during migration? NO — and it does not need to.**

ADR-028's binding text is about a second *world-build path*: *"No future work may rebuild, replace,
re-fragment, or add a parallel world-build/veg/placement system."* `tests/test_placement_paths.gd:12-20`
enforces it by name-matching six entry points against a two-file `CALLER_MANIFEST`.

Two shapes are available and only one is legal:

- **ILLEGAL: a flag.** `if USE_KIT: stamp_kit() else: load_monolith()`, both branches live, shipped.
  This is precisely what ADR-041's FROZEN-FILES section forbids **by name**: *"a parked-but-built
  authored scene shipped behind a flag 'so it is ready' is not permitted — the
  `FieldDirector.SLEEP_POST_LAUNCH` precedent proves that is exactly how post-launch work gets built
  during launch scope."* It is also two live placement paths, which is the ADR-028 violation itself.

- **LEGAL, and the right engineering: MIGRATE THE INPUT, NOT THE CODE.**
  `place_firebase_main` stays the one entry point. What changes is *what it assembles*.
  For each part family F, in one commit:
  1. re-export the monolith **minus family F** (`tools/reexport_firebase_v3.py` is one command, and the
     generator already has `refresh_family_meshes(names)` at `:796` and `clear_collision()` at `:977`);
  2. `place_firebase_main` stamps family F from the kit under the same wrapper root;
  3. delete the repair/audit code that existed only for F's baked form.

  **At no point are there two paths. There is one path whose input set shrinks by one family per
  commit, and the game is playable at every single one.** This is the strangler shape, done through
  the asset rather than through a branch — which is the only version of it this project's laws allow.

**BINDING, and it is a real hole:** a new `stamp_fsb_kit(` is **not** in
`test_placement_paths.PLACEMENT_CALLS` (`:12-15`), so the probe would not police it at all. **Add it to
`PLACEMENT_CALLS` in the same change that creates it**, or the migration builds an unpoliced entry
point inside the file the whole law is written around.

### 3.2 The phase order — playable at every commit

Ordered by **blast radius ascending**, not by what is most interesting.

| P | Phase | Playable after? | Why here |
|---|---|---|---|
| **P0** | **Marker data to disk.** Emit `fsb_markers.json` at export; `_ensure_fsb_markers` reads it. Delete the throwaway instantiate (§1.7). | YES | Pure win, needs no ruling, carries forward 100%, and it is inside the DEMO's load path. **The only phase I would consider pre-demo, and only as a bug fix under the ADR-015 exemption.** |
| **P1** | **Extraction, no game change.** Script the blend → `firebase_layout.json`: every `place()`-instanced object's family, position, yaw. Verify §0.2's assumption first. | YES (nothing shipped) | Everything downstream is priced off what this finds. If the transforms are NOT there, the whole plan changes and we learn it for 3h instead of 40. |
| **P2** | **Kit master export.** 23 masters, contract-named per `recon-destructible-export`, `-colonly` twins terminal, per-part `work_*` markers from `STATION_PLAN`, one closed ballistic class per master. **Nothing consumes them yet.** | YES | Art work, reviewable in isolation, zero runtime risk. |
| **P3** | **The stamper + the wrapper.** `place_firebase_main` builds a `Node3D` wrapper, adds the monolith root under it, returns `{"nodes":[wrapper]}`. **No parts stamped yet.** | YES — and this commit is the whole §2.4 fix | One structural commit, provable by the existing boot diff (`[FSB]` lines must be byte-identical). |
| **P4** | **PARAPET FIRST.** 80 stamped segments from `firebase_v3_destructibles.json`; monolith re-exported without `fb_sbg_seg_*`. | YES | **The positions already exist.** `firebase_v3_destructibles.json` carries `pos` + `box` + `kind` + `hp` for all 80 — and today the code reads only name/kind/hp (`:2192-2205`), so `pos` is unused data already on disk. Yaw derives from the perimeter path or from `box[0]` along consecutive positions. **Deletes:** the `.001` stray reconciliation (62 lines), `_mesh_center`'s reason to exist, `_audit_parapet_spread` (24 lines), 80 of the 86 box-hull re-meshes. |
| **P5** | **Emplacements + towers + bunkers** (11 bunker, 4 bunker_mg, 4 tower, 9 sandbag_stack, 6 gun pits, 2 mortar pits). GLB masters for 5 of these already exist in `kit/`. | YES | Each family independently revertible; `FSB_STRUCTURE_KINDS` (`:2385-2402`) already names them. |
| **P6** | **Marker/garrison re-base.** `_ensure_fsb_markers` → per-part markers in world space; `fsb_garrison_plan`, `_arty_pits`, `fsb_gate_metrics` read the layout. **484 lines rewritten.** | YES, but this is the risky commit | Must come AFTER P4/P5 so parts are already carrying markers, and BEFORE P7 so the hooches' 88 `hooch_sleep` markers migrate with their building. |
| **P7** | **Buildings + interiors** — 11 hooches, TOC, chow hall, medical complex, 5 latrines, GP tents, supply dump, water point. Interior sets become instanced scenes, not baked copies. | YES | The 545/69 duplication dies here. `InteriorPropFold` stays live until the last one migrates, then deletes. |
| **P8** | **THE GROUND.** `fb_terrain_mound` + `fb_berm_ring`. **HIS RULING REQUIRED — §2.3 (a)/(b)/(c).** | **THE ONLY PHASE THAT CAN LEAVE THE GAME UNWALKABLE** | Last, alone, and behind a decision. |
| **P9** | **Delete the corpses (ADR-023).** `_repair_glb_colliders`, the audits, `FSB_SOFT_PREFIXES`' 40-entry list, `_mesh_center`, `_audit_parapet_spread`. | YES | The fossil law's half of the job. If P9 does not happen, the pivot has *added* code, not replaced it. |

**Why not "walls first because they have no transform" as the brief suggests?** Because the brief has
it backwards on the mechanism. The walls have no transform **in the GLB** — but their transforms are
**already on disk** in `firebase_v3_destructibles.json`, unread. They are the *cheapest* family to
migrate, not the hardest, and they are also the family with the loudest proof (the siege breaches or it
does not). So the conclusion — walls first — is right; the reason in the brief is not.

### 3.3 The probes that must ship WITH the migration, not after

ADR-041 §5 makes this binding for authored sites and it binds harder here.

1. **Marker-vs-navmesh probe** — every `work_*` and spawn marker within agent clearance of a baked
   polygon. The chow-hall lesson (`commit 8e1129c7`: 16 of 48 markers moved in the *asset*, not the
   code) is the reason. Without it, P6 moves the chow-hall defect into a new file.
2. **Ballistics parity ratchet** — `tools/probe_firebase_penetration.gd` exists and ratchets
   (ADR-042:164). Extend it to assert soft/hard counts per family across the migration, or a family
   ships bulletproof and nothing errors (ADR-042's whole thesis).
3. **`[FSB]` boot-line diff** — the ledger already uses it as the migration instrument
   (`PERF_LEDGER.md:2028-2036`). Every phase must publish its before/after table.
4. **Per-part float check** — `test_site_stamp.gd:79-87` checks each node in `site["nodes"]`. With one
   wrapper root it checks ONE node and every floating part goes unmeasured (ADR-041 §3's exact
   warning). **Extend it to walk the wrapper's children, in the P3 commit.**

---

## 4 · COST IN HOURS

### 4.1 What this is calibrated against, stated so it can be argued with

**Anchor:** ADR-041 §12 — **20–31h total (14–19h engineering + 6–12h Caleb authoring)** for
**village + temple**, direct-instance shape.

**Two independent methods, deliberately not reconciled until the end:**

- **Method A — code-surface ratio.** ADR-041's anchor buys stamping for `stamp_village` (120 lines) +
  `_stamp_village_props` (46) = **166 lines**. The firebase's equivalent surface is **1,752 lines**
  (§1.1) = **10.6×**. But roughly half the firebase's lines are *repair and audit that DELETES* rather
  than *stamping that must be written*, so I discount to **3.5×** → **49–67h engineering**.
- **Method B — bottom-up per phase.** Below → **43–64h engineering.**

**They agree within 12%.** I am reporting the union: **43–67h engineering.** Where they disagree I take
the higher, because every schedule in this project's history has been low.

### 4.2 Per phase

| P | Phase | Eng hours | Caleb hours | Confidence |
|---|---|---|---|---|
| P0 | marker data to disk, kill the double instantiate | **2–3** | 0 | **HIGH** — I have read both ends |
| P1 | blend extraction → `firebase_layout.json` | **3–5** | 0 | MEDIUM — rests on §0.2 |
| P2 | 23 kit masters exported, contract-named, `-colonly`, markers | **6–10** | **4–8** review | **LOW — my softest number.** See §4.3 |
| P3 | wrapper root + site-dict shape + probe extension | **2–3** | 0 | HIGH |
| P4 | parapet: 80 stamped, monolith minus `fb_sbg_seg_` | **5–7** | 1 | HIGH — data on disk |
| P5 | emplacements/towers/bunkers/stacks (6 families) | **7–10** | 2–3 | MEDIUM |
| P6 | marker + garrison re-base (484 lines) | **8–11** | 1 | MEDIUM — biggest single rework |
| P7 | buildings + interiors (11 hooches + 8 singletons) | **8–12** | 3–5 | MEDIUM |
| P9 | fossil deletion + ADR/doc correction | **2–3** | 0 | HIGH |
| | **SUBTOTAL, ground excluded** | **43–64** | **11–17** | **54–81h total** |
| P8a | ground option (b): mound as one stamped part | **4–6** | 2–4 | MEDIUM |
| P8c | ground option (c): trench/berm/crater modules + the morph tool | **20–34** | **10–20** | **GUESS.** See §4.3 |

**Recommended envelope — kit only, ground as option (b): 47–70h engineering, 13–21h his = 60–91h.**
**Full vision with the terrain tool (option c): 67–104h engineering, 23–41h his = 90–145h.**

Against ADR-041's 20–31h for two villages, that is **2–3× for the kit alone and 3–5× for the full
vision** — and the full-vision number is the one that also buys WW1 battlefields and closes ADR-036.

### 4.3 WHERE I AM GUESSING, NAMED

- **P2, the 23 masters (6–10h eng, 4–8h his).** This is the softest number in the document. It could be
  **3h** if the blend's part objects are already clean, separable and correctly named — the generator's
  `refresh_family_meshes()` (`:796`) and `make_collision()` (`:919`) suggest they might be. It could be
  **20h** if every master needs origin repair, `-colonly` twins built by hand, and per-part material
  slot re-mapping (the 9-slot fixed order at `gen_firebase.py:61-77` is load-bearing and a re-slot
  silently shifts every face). **Nobody can price it without opening the blend, which I did not.**
- **P8c, the terrain tool (20–34h).** A pure guess, and I say so. `FIREBASE_REWORK_INTENT.md:92-100`
  is right that `DamageSystem.modify_terrain()` and `ClearingSystem` already exist and that edit-time
  cost does not matter — but "expose existing machinery as an authoring tool" has, in my experience of
  this codebase's own history, never been the small job it looked like. The 691-line `TerrainEngine`
  figure is a size, not a difficulty. **This number should not be used to plan anything.**
- **Every hour above assumes the migration is done by someone who has read this analysis.** A phase
  order discovered mid-flight costs double.

---

## 5 · DEMO RISK

### 5.1 The probability, and the honest framing of it

**If the pivot starts before the demo ships, probability the demo breaks: near certain, and P8 is why.**
**If it starts after, probability any single commit leaves the demo broken: LOW — with two exceptions.**

The phase order in §3.2 is constructed so that every commit is a playable build, and the mechanism that
guarantees it is not discipline, it is structure: **the monolith remains the fallback for every family
that has not yet migrated, and a family that migrates badly is reverted by re-exporting the monolith
with that family back in.** That is a one-command revert (`tools/reexport_firebase_v3.py`), not a code
revert. **That property is worth more than any estimate in §4.**

The two exceptions:

- **P6 (marker/garrison re-base) is the one non-atomic commit.** 484 lines rewritten, and the systems
  downstream of it — garrison occupation, artillery crews, aid-station seeding, the gate, the insertion
  LZ, the player's own spawn — all read from it. It cannot be split by family because the marker
  *origin* changes for all of them at once. **This is where I would expect a broken build.**
- **P8 is the irreversible one. See §5.2.**

### 5.2 THE SINGLE LARGEST IRREVERSIBLE STEP

**Deleting `fb_terrain_mound` from the export.**

Not because it is hard — because of what depends on it and how silently it fails:

- It **is the floor.** `:1838-1844` keeps it deliberately, `:1675-1685` states that the terrain stops at
  the mound's toe (~3.4 m below the compound), and `game_flow.gd:192-200` records what happened the
  *last* time the floor moved: *"Every cot inside the wire failed the test and the spawn walked out to
  candidate 69 of 72, a village 142 m away: 'i was spawned outside at a village there.'"*
- It is **nav ground** (`nav_baker.gd:573`), **blast-proof** (`combat_manager.gd:300`) and the
  reference surface for `_audit_one_ground` (`:2053`) and `probe_roof_spawn.gd:16`.
- The failure mode is not a crash. It is **the player standing on the terrain seat 3.4 m below the
  world, inside the mound, with every building's feet above his head.** That reads as a total loss of
  the compound and it is exactly the "people falling through berms" complaint, amplified.
- **And re-exporting the mound back in does not restore the state**, because by P8 the terrain will have
  been sculpted to a different profile. That is what makes it irreversible where P4–P7 are not.

**Mitigation, and it is cheap:** P8 must land as **two** commits — first the terrain reproduces the
mound (`fsb_mound_height()` at `:998` is already the ported function and already reads the manifest;
it is turned off, not absent), *verified with the player standing on it*, and only then is the mound
stripped from the GLB. Two grounds for one commit is a known, survivable state — it is literally what
the code did before 2026-07-29. Zero grounds for one commit is not.

### 5.3 The risk nobody has priced: PERF is unmeasured in the "after" direction

`place_firebase_main` **never applies the 230 m structure cull** (§1.3 correction; ADR-041 §7.1). Today
that is survivable because the compound is ~19 merged draw sources. **A stamped kit is N nodes, and
each one is a separate draw source unless it is culled or instanced.** ADR-026's bench is Intel UHD and
`PERF_LEDGER.md:1418-1437` voids every render-scale row taken 2026-08-07..2026-09-08.

**UNVERIFIED, and it is the pivot's biggest unpriced technical risk:** whether a stamped compound draws
more or fewer calls than the monolith. Arguments exist both ways — instancing and per-part frustum
culling say fewer; loss of the merged-per-species bake (`PERF_LEDGER.md:2073-2078`) says more.
**Nobody has measured it. P3 should ship with a draw-call baseline so P4 onward has an A/B.**

---

## 6 · TRADEOFFS — LAW 2

### 6.1 What is sacrificed IF WE DO THIS

1. **60–91 hours that do not exist before launch** — 2–3× ADR-041's anchor for two villages, on a
   project whose scope law is *launch = ONE faction*.
2. **The procedural variety inside each family.** `parapet_segments()` (`gen_firebase_v3.py:322-353`)
   gives every one of the 80 walls its own `rng.randint` bag seed. **Eighty stamped instances of one
   master are eighty identical walls.** The chord error is negligible (a 6.6 m segment on a ~96 m ring
   sags 5.7 cm — computed from `box[0]=6.6` and the measured 49.4–96.0 m radii), so the *shape* is fine.
   The *sameness* is the price, and it is the Men-of-Valor smell ADR-041 already names.
3. **Blender stops being where the compound is authored.** Every craft convention in
   `firebase_kit_phase1_read.md` §3 — the 9 fixed material slots, the 160 px/m texel density, the
   box-projection UVs at 1.6 m tile, base-centre origins on Z=0 — is a Blender convention. Godot-side
   assembly does not break them, but it means two authoring surfaces for one place, and the naming
   contract (ADR-042) has to hold across both.
4. **`gen_firebase_v3.py` (1,212 lines, 37 functions) becomes a kit exporter or a fossil.** ADR-023
   forbids leaving it standing as neither. That is a decision, not a cleanup.
5. **A migration window in which the compound is HALF baked and HALF stamped.** Every `[FSB]` count in
   the ledger changes at every phase, so the boot-line diff — the project's best firebase instrument —
   is noisier for the whole migration than it is today.
6. **The demo's own load path gets touched.** Even P0, the free win, edits a function
   `plan_demo_world` calls. Under ADR-015 that is a bug fix; it is still a change to shipping code.

### 6.2 What is sacrificed IF WE DO NOT

1. **ADR-036 never happens.** Its blockers 1 and 2 (`ADR-036:34-47`) are *"the firebase is ONE node"*
   and *"the TOC does not exist as an entity."* Nothing else in the backlog closes them. **The fall of
   the firebase — a whole design pillar, already written and accepted — stays permanently unbuildable.**
2. **~1,205 lines of load-time repair are paid forever**, and 195 of them are pure audits. Every boot:
   86 collider re-meshes, 1,984 winding flips, 2,435 ballistic decisions against a 214-family open set,
   an 80-entry manifest reconciliation with duplicate handling. **The code says it is temporary
   (`:1815-1817`) and it has been temporary since July.**
3. **ADR-042's worst site is never closed.** 214 families against a 40-entry hand-grown prefix list,
   defaulting to bulletproof. Every re-export can silently add a family. `fb_aid_station` matching zero
   nodes, `fb_hwall` shipping 242 bulletproof plywood panels, the chow hall merged in under names no
   contract knew — **all three were found by hand, months apart, and the mechanism that produced them
   is untouched.**
4. **`fb_sbg_seg_046_001` and its class.** A Blender `.001` duplicate, invulnerable among 80
   destructible twins — currently handled by 62 lines of runtime reconciliation that only works because
   somebody thought of it. **The next duplicate in a family without that code ships invulnerable.**
5. **The 488-vs-23 mismatch is permanent**, and so is a compound authored for a garrison several times
   the one that fills it — 68 `prop_sleep` cots, 88 `hooch_sleep` markers, 37 bunker fire points, for
   40 men (`FSB_GARRISON_MAX_MEN`, `:1229`).
6. **The WW1 battlefields have no path.** ADR-039 says a WW1 zone is exactly what zones are for; the
   comic adaptation needs one; and cut ground + trench modules is the only shape that produces it. Not
   building the tool does not defer that — it removes it.
7. **Every future firebase is this firebase.** The demo ships one. Early Access ships one. The moment
   the world needs a second, it is another 5,812-node bake or it is this pivot, later, with more code
   depending on the monolith than there is today.

### 6.3 The tradeoff nobody names, and it is the real one

**Doing this well costs 60–91 hours. Doing it badly costs the demo.** The difference between the two is
entirely in §3.2's ordering discipline and §3.3's four probes — the cheapest items in the plan and,
by this project's own record (`PERF_LEDGER.md`'s broken-instrument register; the chow-hall markers that
shipped broken; *"a green validator can pass empty work"*), **the ones most likely to be skipped.**

---

## 7 · NEW ADR, OR AMENDMENT TO ADR-041?

**BOTH — and splitting them is the substantive answer, not a hedge.**

### 7.1 The KIT is an AMENDMENT to ADR-041. Four reasons.

1. **The governing law already covers it, verbatim.** *"THE SCENE IS A PLAN, NOT A PREFAB."* ADR-041's
   Tier B (`§4`) is *"a multi-building cluster composed in Blender, exported as one contract-named GLB,
   plus a marker `.tscn`"* — status *"Legal under this ADR; UNBUILT."* The firebase kit is Tier B with
   the granularity dial turned from "cluster" to "part". Same law, same mechanism, finer grain.
2. **ADR-041's own §4 already prices this exact case:** *"If a Tier-B site is ever instanced directly
   rather than through `place_structure`, it must do for itself what `place_firebase_main()` does:
   seat, repair colliders, cull interiors, wire destructibles, build ladders after seating, and hand
   its own root to the nav baker."* **The ADR already uses the firebase as the worked example of its
   own price.** Extending it to the firebase is applying it to the thing it was measured on.
3. **The freeze is in ADR-041 and only an amendment thaws it.** `place_firebase_main` is named in
   ADR-041's FROZEN FILES list (`:307`). A new ADR authorising work on a file ADR-041 freezes creates
   **two live documents governing one function with opposite instructions** — the drift generator this
   project names in CLAUDE.md and in the POINTER LAW. An amendment corrects the freeze in place.
4. **ADR-041 §12's price table is the calibration anchor for §4 above.** Amending it keeps the estimate
   and its anchor in one document, where the next reader can check my 3.5× discount.

**What the amendment must add that ADR-041 does not have** — because the firebase is not a village:
- a **§4-bis** for sites that do not route through `place_structure()` at all (the firebase's 1,205-line
  private path is not covered by ADR-041 §3's ten contracts, all of which assume `place_structure`);
- the **wrapper-root clause** (§2.4): one `Node3D` per authored site, `site["nodes"] = [wrapper]`, and
  `test_site_stamp.gd` extended to walk its children;
- the **migrate-the-input-not-the-code clause** (§3.1), which is the concrete legal answer to
  ADR-028 for any future monolith → kit move;
- the **P8 two-commit rule** (§5.2): terrain reproduces the ground *before* the ground leaves the model.

### 7.2 The TERRAIN MORPH/CUT TOOL needs a NEW ADR, and it is not close

ADR-041 is about authored **places**. The tool is about authored **ground**, and that is a different law.

- **ADR-039 clause 1 forbids it as written:** *"An outdoor area of operations is a PLAN, never a scene.
  Every outdoor place is produced by a `plan_*_world()` function returning the plan dictionary."*
  And ADR-039 §3 accepted, as its own stated price, *"the world can never be composed."*
- **ADR-041 deliberately preserved that.** Its Consequences narrow ADR-039 §3 to: *"the **GROUND** can
  never be composed; a PLACE can."* Its Tier C is *"the AO: authored — nothing"*, marked *"ADR-039
  clause 1 — **not negotiable**."*
- **A tool that morphs and cuts the heightmap at author time and ships the result composes the
  ground.** It is Tier C. It is the one thing ADR-041 explicitly refused to license.
- It also touches **ADR-010** (a hand-edited heightmap is not derived from `mission_seed`) and
  **ADR-013/028** (residency and the protected foundation). Those are ADR-039/028's subject matter, not
  ADR-041's.

**Therefore: a new ADR whose subject is "authored terrain, and the boundary between a seeded heightmap
and an edited one."** It must answer, at minimum: does an edited heightmap ship as data or bake into the
seed; how does ADR-010's determinism survive a hand edit; and does the tool run in the Godot editor or
as an in-game dev mode (`FIREBASE_REWORK_INTENT.md:131-133` already lists the last one as open).

### 7.3 One consequence of the split worth stating

**The kit does not need the tool.** §3.2's P0–P7 and §2.3 option (b) — the mound as one stamped part —
deliver the entire kit pivot, close ADR-036's blockers, kill the runtime repair and fix the 488-marker
mismatch, **without composing one metre of ground and without a new ADR at all.**

That is the cheap 60–91h path and it lives entirely inside an ADR-041 amendment.
The tool is a separate, larger, differently-justified decision — and its justification is WW1, not the
firebase.

---

## 8 · THE FIVE-LINE VERSION

1. `place_firebase_main` is 90 lines over **1,205 lines of load path**, 43.7% of `site_planner.gd`,
   doing **86 re-meshes + 1,984 winding flips + 2,435 ballistic decisions + an 80-entry manifest
   reconciliation, every boot**, in code whose own header says it should already be deleted.
2. **14 systems survive a kit unchanged** — everything built on groups and prefixes. **One hard break**
   (`nav_baker.gd:204`, `nodes[0]`) is fixed by a one-line wrapper root.
3. **Half the kit already exists on disk, unread**: 23 parts with markers and `work_type` in
   `firebase_set.json`, 80 wall positions in `firebase_v3_destructibles.json`, per-part work stations in
   `gen_firebase_v3.py:709`.
4. **43–67h engineering, 60–91h all-in** for the kit with the ground as a stamped part; roughly 90–145h
   for the full vision with the terrain tool. Two independent estimation methods agree within 12%.
5. **Amend ADR-041 for the kit. Write a new ADR for the terrain tool** — the tool composes ground, and
   ADR-041 §4 marks that "not negotiable" on purpose.
