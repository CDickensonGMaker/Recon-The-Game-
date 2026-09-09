# DEVIL'S ADVOCATE — the firebase kit pivot

**2026-09-09 · Law 2: no free lunches. Every claim below carries `file:line` or a number I took myself.**
**Nothing here was reasoned where it could be measured. Where I could not measure, I say so.**

---

## THE ONE-PARAGRAPH CASE

The firebase **is already a stamped kit** — 23 master families in a dictionary, placed by a
`place(master, pos, bearing)` function, including the trench module the intent doc calls "the
genuinely missing part." The pivot therefore does not buy modular parts; it buys **moving an
existing stamping loop from Python into Godot**, at the cost of invalidating an 80-entry exact-name
destructible manifest that the demo's entire payoff — the siege — measures its perimeter from, and
throwing away a batching fold that shipped four hours ago. Meanwhile **not one of the five things he
saw would be fixed by it**, including the one he named as its benefit. And ADR-041 says BUILD
NOTHING, by name, over every file this would touch.

---

## 1 · THE STRONGEST ARGUMENT THAT THE FIREBASE SHOULD NOT BE REBUILT

### 1.1 — THE KIT ALREADY EXISTS. This reframes the whole council.

`tools/gen_firebase.py:856-878` is a **23-entry master dictionary**:

```
FAMILIES = { fb_bunker_mg, fb_bunker_fighting, fb_sleeping_bunker, fb_tower, fb_berm_arc,
             fb_trench_run, fb_wire_belt, fb_gate_gap, fb_claymore, fb_gun_pit, fb_howitzer,
             fb_mortar_pit, fb_gp_tent, fb_hootch, fb_toc, fb_mess, fb_aid_station,
             fb_helipad, fb_supply_dump, fb_latrine, fb_sandbag_stack, fb_water_point,
             fb_burn_barrel }
```

`tools/gen_firebase_v3.py:1041-1045` builds **all 23 as separate objects** ("masters"), parked at
`(0,0,-900)`. `tools/gen_firebase_v3.py:503-522` is `place(master, pos, bearing, rng, jitter, claim,
must_fit)` — a **stamper with collision-aware free-spot search** (`free_spot`, `:489-502`) and a
per-family footprint table (`footprint_r`, `:482-488`). Lines `1065-1186` are the layout: stamp
bunkers round the perimeter, stamp trenches, stamp the gate, stamp gun pits, stamp the TOC, stamp
hooches, stamp towers, stamp the helipad.

**That is the architecture he is asking for, already built, already shipping.** The difference the
pivot proposes is that the stamping loop runs in GDScript against a Godot editor instead of in
Python against Blender.

> **Nobody should cost this pivot as "build modular parts." The parts exist. The pivot's real
> deliverable is a change of AUTHORING SURFACE, and it must be justified on that alone.**

### 1.2 — THE INTENT DOC'S HEADLINE MISSING PART IS NOT MISSING

`production/FIREBASE_REWORK_INTENT.md:103`:

> *"What is genuinely missing is the **trench module**. A trench is cut ground plus revetment,
> duckboard and firestep — the cut half already exists, the parts half does not."*

**REFUTED.** `tools/gen_firebase.py:503-514`:

```python
def fam_trench_run(bm, rng):
    """Walkable connecting trench, 1.4 m deep, revetted cheeks, duckboards."""
    ln, wd, dp = 6.0, 1.25, 1.4
    box(bm, (0, 0, -dp / 2.0), (ln, wd, dp), "fb_earth")                  # the cut
    for sy in (-1, 1):
        for i in range(8):
            box(..., "fb_timber")                                          # revetted cheeks
        berm(bm, ...)                                                      # spoil berm both sides
    box(bm, (0, 0, -dp + 0.05), (ln - 0.2, wd - 0.3, 0.10), "fb_timber")   # duckboard
```

Revetment: built. Duckboard: built. Depth 1.4 m: built. And it **ships** — I counted **16
`fb_trench` nodes** in `fsb_main_v3.glb` (8 runs × mesh + collider).

The one honestly missing element is the *firestep*, which is a step box. **Correct the intent doc on
contact (NO MORE DRIFT); do not let a council price a module that exists.**

### 1.3 — WHAT IS EMBEDDED IN THE MONOLITH PATH, COUNTED

**17 commits** land on `fsb_main_v3.glb` or its exporter: `f89d3ccf 9eb6c270 a4cf04a9 00e031a2
ab63f90d aba5ca53 c907cb04 1c517cf8 fbc2877d 918c64d0 5a3f2e6b 5ed4b181 b67fda5e 8e1129c7 6387c3e3
15d91d06 3d4b6093`.

Tooling, measured: `gen_firebase_v3.py` **1,212 lines** · `reexport_firebase_v3.py` **115 lines** ·
plus `gen_firebase.py` (the 23 families), `fb_kit.py`, `gen_firebase_layout.py`,
`gen_firebase_textures.py`, `refit_firebase_veg.py`, `merge_chowhall_to_firebase.py`,
`rename_fb_ammo_crate_colonly.py`.

Godot-side machinery keyed on the single root, all in `scripts/world/site_planner.gd`:
`place_firebase_main` · `_repair_glb_colliders` (`:1820`) · `_force_backface_collision` (`:1806`) ·
`_remesh_collider` · `_tag_fsb_ballistics` · `_audit_floating_colliders` ·
`_wire_parapet_destructibles` (`:2183`) · `_wire_structure_destructibles` (`:2046`) ·
`_fold_interior_props` (`:1790`) · `_stamp_hooch_radios` · `fsb_mound_height` (`:998`) ·
`_mound_manifest` (`:979`) · `_fsb_marker_origin` (`:1078`) · `fsb_garrison_plan` (`:1402`) · plus
the tables `FSB_MARKER_KEYS` (`:1087`), `FSB_GARRISON_POSTS` (`:1100`), `FSB_GARRISON_QUARTERS`
(`:1121`), `FSB_WORK_OCCUPATION` (`:1152`), `EARTHWORK_FAMILIES` (`:1134`), `FSB_PLATEAU_FALLOFF`
(`:962`), `MOUND_COLLIDER_PREFIX` (`:1765`), `REMESH_COLLIDER_PREFIXES` (`:1769`),
`INTERIOR_PROP_PREFIX` (`:1787`), `FSB_PARAPET_MESH_PREFIX` (`:2169`), `FSB_PARAPET_GROUP` (`:2172`).

**ADR-041 §6 already priced a fraction of this:** *"~200 lines of seating machinery behind a 13-line
scene. Anyone costing Tier B must cost that, not the 13 lines."*

### 1.4 — WHAT SHIPPED TONIGHT THAT IS BUILT AROUND THE SINGLE EXPORT

| Shipped tonight | Bound to the monolith how | Measured |
|---|---|---|
| **The last vegetation cards** (`3d4b6093`) | `refit_firebase_veg.py` recovers per-instance transforms from **fused vertex blocks** inside the bake — `scatter_veg` merges every instance of a species into ONE object, so a Umeyama fit per block is the only way to know where a plant stands | **349 instances, max residual 0.0000 m.** This tool has no meaning outside one baked file. |
| **The interior-prop fold** (`d904fd70`) | `InteriorPropFold.apply(root)` gathers **across all eleven hooches at once** | **545 props → 69 MultiMeshes, 1,010 surfaces → 132.** See §3.2. |
| **Parapet adoption + siege wiring** | `firebase_v3_destructibles.json`: **80 exact-name segments**, `segment_len 6.0`, `hp 140`, each with a **baked model-local position** (`fb_sbg_seg_000` at `[95.575, 3.002, 2.935]`, box `[6.6, 0.37, 1.17]`) | `SiegeDirector` measures the wall radius **per bearing bin** off `FSB_PARAPET_GROUP` (`siege_director.gd:659, 687`); `_scan_breaches` (`:407`) reads a dead segment as a HOLE. |
| **Collider naming fixes** (`34249d13`, `5bead05a`, `fc538238`, `d29a7860`) | Every one is a name-prefix fix inside the bake | A tent + the mess hall were bulletproof; a hanging light bulb stopped rifle rounds; the TOC roof was walkable floor. |
| **Chow-hall / medical / stray-prop work** | Merged into the bake by `merge_chowhall_to_firebase.py` | 16 markers moved in the asset (`8e1129c7`). |

> **The parapet manifest is the load-bearing one.** It is a table of 80 EXACT NAMES and 80 BAKED
> POSITIONS in model-local space. Dissect the compound and every name and every position in it is
> invalidated in the same stroke — and the demo's payoff, the 45-man siege, measures its perimeter
> and its breaches from that group. `recon-destructible-export-contract` states it:
> *"Re-exporting the firebase without re-running `gen_firebase_v3.py` breaks all 80 parapet segments
> AND blinds SiegeDirector."*

---

## 2 · THE PRECEDENT THAT SHOULD SCARE US

**This project's track record on "we'll migrate it incrementally" is bad, and it is documented in its
own commit titles.**

1. **`1c517cf8` — "The firebase is exported for the first time since 2026-07-26."** Content built in
   Blender took **over a month** to reach the game. The game shipped, was playtested and was audited
   against a stale export for that entire window.
2. **`15d91d06` — "The firebase re-export had no recipe, and the one on file was wrong."** *Today.*
   The recipe for the pipeline we have **right now** was wrong on file. A pipeline nobody has built
   yet will not fare better.
3. **`c907cb04` — "The firebase exporter could not be imported."** The tool itself broke.
4. **The deletion that never comes.** `site_planner.gd:1735-1738` states its own retirement condition
   in the source: *"When the re-exported GLB lands both counts come back 0 and this whole function is
   deleted (ADR-023)."* The source-side fixes have been in the exporter since **2026-08-02**
   (`:1801`), a full re-export ran **tonight** — and `_repair_glb_colliders`,
   `_force_backface_collision` and `_remesh_collider` are all still in the loader, still running every
   boot. **This is ADR-023's failure mode, in the file that cites ADR-023.**
5. **Both governing ADRs open with sections titled "stale claims corrected on contact"** — ADR-039 §9
   (three) and ADR-041 §9 (two). The 2026-09-07 demo audit refuted **eleven** standing claims in one
   pass, including **two broken instruments** and a two-epoch-stale `OVERSEER_CHARTER`. This project's
   documented, repeated failure is that **the map goes stale faster than it gets corrected.** A second
   placement path doubles the map.
6. **ADR-041 §11's own conclusion**, written three days ago about a smaller version of this idea:
   *"A 1-in-61 seed-dependent papercut with a one-line fix can never buy a new mechanism."*

> **The honest expectation, from this project's own record: a firebase kit migration leaves the
> monolith AND the kit both live for weeks, with two tables that drift — the exact thing
> `site_planner.gd:165-171` records as already fixed once: *"Two tables would drift again, so there
> is ONE."***

---

## 3 · THE TRAP IN "THE PARTS ARE PROVEN" — AND THE DRAW-CALL FINDING

**The parts are proven INSIDE the bake.** Here is what each loses on extraction, measured.

### 3.1 — The compound, counted (`fsb_main_v3.glb`, 44.6 MB on disk)

| | |
|---|---:|
| nodes | **5,810** |
| nodes carrying a mesh | **4,437** |
| distinct meshes | **2,274** |
| surfaces on distinct meshes | **2,457** |
| **instance-weighted surfaces** (upper bound on draw calls, nothing culled) | **5,753** |
| materials | **159** |
| embedded images / bytes | **30 / 20.74 MB** |
| triangles | **342,219** |
| mesh nodes with **no node transform** (baked into vertices) | **618** |

Frame budget for context (`PERF_LEDGER` 2026-08-14, cited in ADR-039 §6): the assault frame is
**324,000 primitives / 1,764 draw calls / 33.2 ms GPU with ~2.6 fps of margin**, GPU-led at every
measured phase. `ADR-026 Amendment C`: **Intel UHD is the permanent bench.** 5,753 is an upper bound
the frustum never pays in full — but it is the pool the culler works from, and it is 3.3× the whole
shipped frame's call count.

### 3.2 — THE DRAW-CALL ARGUMENT, and it is stronger than "200 instances = 200 calls"

The naive form of this objection is wrong and I will not make it: the monolith is **not** one draw
call. It is 4,437 mesh nodes. Splitting it into parts does not by itself multiply surfaces.

**The real argument is that stamping destroys the one batching win the project has, and it shipped
four hours ago.**

`scripts/world/interior_prop_fold.gd` (commit `d904fd70`, 13:15 today) folds **545 `fb_int_` props
into 69 MultiMeshes: 1,010 surfaces → 132.** Its own header states the mechanism:

> *"545 nodes cull individually, **69 MultiMeshes each span all eleven hooches** and draw whole."*

That fold is legal **only because all eleven hooches' props live under one root at the same time.**
Under a stamped kit:

- **Fold per stamped hooch** → each hooch holds ~50 props drawn from 69 types, so most MultiMeshes
  hold **one instance**. A one-instance MultiMesh is a MeshInstance3D with extra steps: **zero
  batching win, and you have still given up the per-node frustum culling.** The fold's own
  measurement says folding at the old range **COSTS +50 draw calls** for exactly that reason. Per
  part, it is a straight loss on both counts.
- **Fold across N stamped roots afterwards** → a new cross-instance gather that must run after
  placement, find parts it did not create, strip their prop nodes and rebuild the MultiMeshes. New
  engineering, and it re-loses culling over an even wider span.

**878 surfaces are at stake** (1,010 − 132) on the interior props alone, on a permanent Intel UHD
bench, in a frame with 2.6 fps of margin.

### 3.3 — MULTIMESH CANNOT RESCUE THE DESTRUCTIBLE PARTS, AND THE PROJECT ALREADY KNOWS IT

Nobody should answer §3.2 with "Godot 4.7 MultiMesh will batch the kit." It cannot, and the fold's own
header says why it was allowed at all:

> *"Nothing here matches a `FSB_STRUCTURE_KINDS` or `FSB_SOFT_PREFIXES` prefix, so the destructible
> contract sees no change."*

A `MultiMeshInstance3D` is one mesh and N transforms. **There is no `queue_free()` for instance 37.**
Destruction requires an individually removable node, an `AgentRegistry` registration, a `Destructible`
script and its own collider. So **every destructible thing in the compound is permanently excluded
from MultiMesh batching**: the 80 parapet segments, the bunkers, the hooches, the tents, the supply
dumps. The fold only ever reached the props precisely because props are not destructible.

> **The kit's parts are, by definition, the destructible ones. They are exactly the set instancing
> cannot help. This is the single strongest technical argument against the pivot and I have found no
> counter to it.**

### 3.4 — MATERIALS AND TEXTURES: what the shared atlas is worth, measured

| family | mesh nodes | surfaces | distinct materials |
|---|---:|---:|---:|
| `fb_hootch` | 836 | 1,320 | **3** |
| `fb_hwall` | 484 | 484 | **2** |
| `fb_sandbag` | 302 | 302 | 7 |
| `fb_sbg_seg` (parapet) | 162 | 162 | **2** |
| `fb_int` (incl. `-colonly` twins) | 1,090 | 1,555 | 35 |

**159 materials serve 4,437 mesh nodes.** `fb_earth`, `fb_timber`, `fb_sandbag`, `fb_corrugated`,
`fb_canvas`, `fb_psp`, `fb_mud` are shared across nearly every family. Godot's resource cache dedupes
**per file** — N part GLBs produce N copies of each shared material and each shared texture unless a
post-import material-remap pass is written. That pass does not exist and nobody has costed it.

**And the texture payload is already sick, which makes duplication expensive.** I hashed all 30
embedded images:

- **`recovered_ref_factions` (8.63 MB) and `better textures` (8.63 MB) are BYTE-IDENTICAL.**
- **8.68 MB of the 20.74 MB texture payload (42%) is duplicate bytes** already.
- **Both violate the standing 1 MB texture budget by 8.6×** (`CLAUDE.md`, Summoner's law 2026-08-18:
  *"No embedded image in a shipped GLB may exceed 1MB"*). Also on disk as
  `fsb_main_v3_better textures.png`, **9,051,883 bytes**.
- `fb_crate` and `fb_ammo_crate_stack_fb_crate` are likewise identical.

**A live defect, unrelated to the pivot, fixable tonight** (`python
tools/shrink_oversized_textures.py --apply`) — and the thing that would multiply worst across N part
files.

### 3.5 — WHAT ELSE EACH PART LOSES ON EXTRACTION

- **Its own contract-compliant name.** `recon-destructible-export-contract`: *"Both defaults fail
  silently and in the dangerous direction: unrecognised = bulletproof AND indestructible, with no
  error."* And *"Ballistics reads the COLLIDER name; destruction reads the MESH name."* **30+ new GLBs
  is 30+ new chances to ship an invulnerable building with no error** — the ADR-042 bug class, which
  produced four separate defects today alone (`34249d13`, `5bead05a`, `fc538238`, `d29a7860`).
- **The `-colonly` asymmetry.** `assert_colonly_terminal` (`gen_firebase_v3.py:964`) exists because
  `us_fb_ammo_crate_stack-colonly_P2` shipped as a visible mesh. Per-part export re-opens that gate
  30+ times.
- **Its origin.** 618 mesh nodes carry **no node transform at all**; their geometry sits in
  world-space vertices. Every one needs an origin computed and its vertices rebased before it can be a
  part — and getting that wrong is the *"80 of 81 wall segments seated at the model root"* bug the
  briefing already blames on the bake.
- **Its seat on the mound.** `fsb_mound_height()` (`site_planner.gd:998`) + `FSB_PLATEAU_FALLOFF`
  (`:962`) + `fsb_main_v3_mound.json` exist so the compound floor is a known function. A stamped part
  needs that per-part, and `place_structure` re-samples terrain height per building
  (`site_planner.gd:246-248`) — which is the **terrain**, not the mound. See §5.
- **`_apply_visibility_range`.** ADR-041 §7.1: the 230 m structure cull is applied at
  `place_structure:220` and `place_prop:463`, and **`place_firebase_main` never calls it.** Honest
  note: **this one is a point FOR the kit**, and it is worth one line either way.

---

## 4 · THE FIVE OBSERVATIONS — WHICH ONES THE PIVOT WOULD NOT FIX

**Answer: all five. The pivot fixes none of the five things he actually saw.**

### (1) Stuck between a ladder and sandbags — NOT FIXED. Made worse.

`scripts/world/ladder.gd:133-136`:
```gdscript
func dismount_point() -> Vector3:
	var p: Vector3 = _top - _face * DISMOUNT_IN     # DISMOUNT_IN = 0.95  (:24)
	p.y = _top.y + DISMOUNT_LIP                     # DISMOUNT_LIP = 0.30 (:23)
	return p
```
and `scripts/player/player.gd:1455`: `global_position = _ladder.call("dismount_point")`.

**The player is teleported 0.95 m inboard of the top marker with no clearance test, writing
`global_position` directly** — off the physics solver, which the class header (`:6-14`, constraint 1)
says is deliberate and unavoidable: *"move_and_slide CANNOT climb a ladder ... The climb writes
global_position.y directly and leaves the physics solver alone."* If sandbags sit within 0.95 m
inboard, he is written into them. **A hardcoded step with no destination test.**

A kit reproduces this exactly — the markers ride on the part (`build_from_markers`, `:36-60`). **And a
kit adds a NEW failure:** `PAIR_RANGE = 6.0` (`:25`) pairs each `ladder_bottom*` with its **nearest**
`ladder_top*`. Stamp two towers within 6 m and a bottom marker pairs with the wrong part's top. This
bug **cannot** exist in a single authored bake and **can** exist under stamping.

**Real fix:** shape-cast the dismount point and fall back to the rail, or move the marker. Bug fix,
exempt under the ADR-015 gate. ~1 h.

### (2) NPCs stacking at work points — NOT FIXED. Wrong system diagnosed.

The 2026-08-24 fix (`5ed4b181`) lives in `scripts/enemies/camp_director.gd:137-140` — *"ONE MAN PER
STATION (his ruling 2026-08-24). The `% size()` wrap stacked..."* — and **camp_director serves the
village / VC camp**, not the firebase.

The firebase garrison gets its posts from `SitePlanner.fsb_garrison_plan`
(`site_planner.gd:1402-1460`), a **round-robin by work TYPE** over `_fsb_work_markers`, capped by
`FSB_WORK_POST_CAP`. Different code, never given the exclusivity fix.

The live cause is already named and still open — `PLAYTEST_FINDINGS_2026-08-28.md` item 24:
> *"[ ] [CODE] Work markers need an ACTIVITY TYPE so a man only plays a clip the marker can support.
> **Still open, still the likely cause of men sitting on nothing.**"*

with item Q1/24 adding: *"the firebase STATION system, which **emits no diagnostics at all**."*

**Stamping geometry does not give a marker an activity type, and it does not add a diagnostic.** The
intent doc's honest claim here is that markers riding on parts would make the *488 markers / 23
staffed* mismatch impossible — but 488/23 is an **over-supply of markers**, the opposite failure from
men stacking on one.

### (3) Huey dropoff worse than the Blender review — NOT FIXED. Not geometry at all.

Standing measurement (`recon-staged-scenes-are-not-clip-banks`): the Blender review scene's Huey
passengers carry **5 fcurves each, all object location/rotation, ZERO bone channels.** What he
remembers as perfect was an **object-animated staging scene**, not a skeletal clip bank. Nothing in
the firebase asset is on either side of that.

Shipping side: `scripts/vehicles/heli_lift.gd:39-40` holds six `disembark_heli*` clips; `:338` guards
against stacking a step-off onto a clip that already carries one. The live defects are code, both
still `[ ]` in `PLAYTEST_FINDINGS`:
- item 4 — *"NPCs fall through the ground (burn ground, **Huey dismount**). Spawn/dismount height authority."*
- item 5 — *"Huey pilots leave the aircraft; empty Huey flies off. Pilots must be exempt from the disembark set."*

### (4) Convoys — NOT FIXED, and **HE ALREADY PARKED IT HIMSELF.**

`PLAYTEST_FINDINGS_2026-08-28.md` item 35, verbatim:
> **35. [PARKED - POST DEMO] Real convoy that forms up and drives out. Your ruling 2026-08-28: "and
> same with the convoy." Build nothing.**

**Surface this to him before any work is planned.** He may be reversing his own ruling — that is his
right, Law 3 — but it must be an explicit reversal, not a silent one.

And it is not in the demo regardless: `_schedule_one_convoy` is called from
`mission_generator.gd:259`, inside the **patrol** planner; `plan_demo_world` (`:697-910`) never calls
it. Nothing about the firebase's assembly touches either fact.

### (5) No dirt roads — NOT FIXED. Content never built, and outside the compound entirely.

`scripts/world/road_network.gd` is 458 lines of `RefCounted` A*. I listed **every** function in it.
Its entire visible output is:
- `clear_corridor()` (`:383`) — thins vegetation bundles in a 5 m half-width corridor
  (`ROAD_HALF_WIDTH_M = 5.0`, `:36`);
- `_stamp_dust()` (`:394-405`) — `ClearingSystem.stamp_ground_line(...)`, a **ground-texture** stamp.

**No mesh, no decal, no road material is built anywhere in the project.** The only other place a road
is drawn is the topo map (`ui/topo_map.gd:13`). `mission_generator.gd:912-914` says it in its own
words: *"The only write a road performs: vegetation bundles thinned along the corridor."*

**And in the demo he is walking there is no road network at all.** `route_roads_and_ambushes(world, p)`
is called at `mission_generator.gd:213` — inside `plan_patrol_world`. `plan_demo_world` never calls it
and never sets `p["roads"]`.

**Classification: (c) content never built.** A firebase kit is not a road.

> ### THE OVERSELL, NAMED
> If the decree says "the kit pivot addresses his five observations," that claim is **false on all
> five**, and I will have failed if it ships unchallenged. What the pivot could honestly claim is that
> it would have *prevented* some of the ASSEMBLY defects in `FIREBASE_REWORK_INTENT.md`'s own table.
> **That is a different list, and it is a list of things already fixed.**

---

## 5 · "REMOVE PEOPLE FALLING THRU BERMS" — REFUTED AS A BENEFIT OF THE PIVOT

Two measured causes. **Neither is fixed by stamping. Both are cheap.**

### CAUSE A — THE BERM HAS NO BOTTOM. It is an open shell with no volume.

`tools/gen_firebase_v3.py:271-300`, `berm()`, builds `fb_berm_ring` as **exactly two quad strips per
station** — inner→crest and crest→outer:

```python
for quad in ((ci[i], cc[i], cc[j], ci[j]), (cc[i], co[i], co[j], cc[j])):
    bm.faces.new(quad).material_index = idx
```

**There is no bottom face and there are no end caps.** It is a tent of triangles over the ground with
open air underneath. Its collider is a `ConcavePolygonShape3D`, which **has no interior by
definition**. `site_planner.gd:1806-1818` `_force_backface_collision` sets `backface_collision = true`
on every concave shape because the shipped GLB winds inward — that makes both *faces* solid but gives
the shell **no volume**.

The same is true of the compound floor: `fb_terrain_mound` is **kept, not stripped**
(`site_planner.gd:1849-1852`) — *"This trimesh IS the walkable ground now."*

**So any body that ends up beneath that shell is not embedded in a wall — it is in open space below a
roof, and it walks around under the compound.** Which is exactly his own hypothesis, already on record
in `PLAYTEST_FINDINGS_2026-08-28.md` item 8:

> *"im assuming the squad firing in the firebase was enemies maybe underneath the berm cuz **i saw nva
> falling thru the berm earlier**."*

**A stamped `fb_berm_arc` module built by this same `berm()` code has the identical open shell.** The
kit changes who places it. It does not give it a bottom.

**Fix: cap the sweep.** Add the bottom skirt (inner-base → outer-base) in `berm()`, same for
`terrain_mound()`. Order of ~10 lines in the exporter plus a re-export — the re-export path that
`15d91d06` documented and `3d4b6093` exercised **today**.

### CAUSE B — THE HEIGHT AUTHORITY, and it is nearly closed already

Inside the compound the model is the ground and the terrain sits under it — the boot prints *"terrain
sits under the model everywhere (worst +0.00m)"*, and the mound rises to **14.5 m** at the crest
(`PLAYTEST_FINDINGS`, collision-pass note). **Any spawner that asks
`terrain_manager.get_height_at()` instead of `GameWorld.floor_y()` seats a man up to 14.5 m under the
berm.** That is `PLAYTEST_FINDINGS` item 4, still `[ ]`.

Of the four callsites named for triage, **three are already on `floor_y`**:
- `scripts/enemies/marching_cell.gd:245` — `global_position.y = director.world.floor_y(...)` ✓
- `scripts/squad/squad_system.gd:111, 757` — `pos.y = world.floor_y(pos) + 0.5` ✓
- `scripts/world/litter_team.gd:173` — `ground.y = world.floor_y(_pos)` ✓
- `scripts/ai/air_traffic.gd:539-544` `_ground_at` — deliberately `surface_y`, correct for aircraft
  (*"must return the HIGHEST solid thing at p"*).

**Remaining exposure is the Huey dismount seat and the enemy/burn spawners — not a re-architecture.**

### VERDICT ON HIS STATED BENEFIT

> **"Remove people falling thru berms" is a bottom face on one swept mesh plus a handful of one-line
> height-authority swaps. It is not a reason to rebuild the firebase. It is a reason to spend two
> hours tonight.**
>
> **If the council lets this benefit stand unchallenged, the pivot is sold on a promise a ten-line
> change already keeps.**

---

## 6 · THE SCOPE-WALL BREACH, NAMED PLAINLY

### What this pivot breaks if started now

**ADR-041 is ACCEPTED, POST-DEMO, BUILD NOTHING (his own ruling: *"i guess this is post demo work"*).
Its FROZEN FILES section names every file this pivot must touch:**

| Frozen path (ADR-041) | Why the pivot cannot avoid it |
|---|---|
| `scripts/world/site_planner.gd` — `place_structure`, `clear_and_flatten`, **`place_firebase_main`** | The stamper and the seat |
| `scripts/world/site_layouts.gd` — the offset/layout tables its header claims | A kit layout IS that table |
| `terrain/systems/clearing_system.gd` — `height_flattening` and the stage table | Terrain morph/cut |
| `scripts/world/nav_baker.gd` — `queue_sites` routing and `_clear_of_firebase` | N collider-rooted sites where there was 1 |
| `scripts/missions/mission_generator.gd` — `plan_demo_world`'s site list | Stamped parts must be planned |
| `scenes/world/` — *"no new site `.tscn` under this ADR"* | Every kit part scene |

**ADR-039's FROZEN FILES adds `terrain/core/terrain_manager.gd` and `terrain/core/terrain_chunk.gd`** —
and a terrain morph/cut tool is a `terrain_manager` change.

**ADR-015, THE GATE.** The demo playthrough is open; feature epics are blocked. Exempt: *bug fixes,
presentation for shipped systems, standing-decree items, evidence probes.* **A new authoring tool and
a new placement path are none of the four.**

**ADR-028.** One placement path. A Godot-side stamper that instantiates parts is a second placement
path unless it routes through `place_structure` — and **ADR-041 §3 proves in ten numbered contracts
that routing a composite through `place_structure` degrades every one of them**, including *"the whole
village becomes one indestructible `StaticBody3D`"* and *"every thatch wall becomes bulletproof."*

**ADR-039 §3.** *"The world can never be composed."* Narrowed by ADR-041 to *the GROUND can never be
composed; a PLACE can* — and a terrain morph/cut tool composes **the ground**.

### THE LEAK MECHANISM, FORBIDDEN BY NAME IN BOTH ADRs

ADR-041, closing line of FROZEN FILES (ADR-039 carries the identical clause):

> **"AND THE LEAK MECHANISM FORBIDDEN BY NAME: a *parked-but-built* authored scene shipped behind a
> flag 'so it is ready' is not permitted — the `FieldDirector.SLEEP_POST_LAUNCH` precedent (ADR-039)
> proves that is exactly how post-launch work gets built during launch scope."**

**Every phasing this council is likely to propose walks straight into it.** The tells, so the Arbiter
can refuse them by name:

- *"Phase 1: dissect the parts into individual GLBs now, wire them after the demo."* — **parked-but-built.**
- *"Add a `kit/` folder of part scenes, unreferenced, so it's ready."* — **parked-but-built.**
- *"Ship the terrain morph tool behind a dev flag / editor-only gate."* — **parked-but-built.** This is
  literally the `SLEEP_POST_LAUNCH` shape.
- *"Build the exporter change now since we're re-exporting anyway."* — **the one to watch**, because it
  is 90% true and 10% leak.

**The test, and it is mechanical: does the phase's deliverable change what the player sees in the demo
build? If no, it is parked-but-built and it is refused.**

### THE HONEST WAYS TO AUTHORISE IT

1. **He thaws the named files by explicit decree** and accepts that the demo slips. His authority,
   Law 3 — but it must be stated as a slip, not as a free action.
2. **It stays POST-DEMO and the only thing produced now is an ADR with no code.** Recording is legal,
   and `FIREBASE_REWORK_INTENT.md:8` already does it correctly: *"POST-DEMO. Recorded as intent, not
   authorised."* **This route costs nothing and loses nothing.**
3. **The outcomes he named are taken as BUG FIXES under the gate's own exemption** — the berm bottom
   face, the ladder dismount clearance, the remaining height-authority seats, the work-marker activity
   type. **No thaw needed. This route gets him what he asked for and breaks no rule.**

---

## 6B · SPECULATIVE ARCHITECTURE — "and we go to ww1 etc."

*(Added at the Arbiter's direction. His new words tonight: "its like a rpg, tactical squad war game ...
but it sits apart from easy red 2 by not just being a sandbox but having this story, the comic story
inside of it too" and "and we go to ww1 etc." `FIREBASE_REWORK_INTENT.md:105-117` already calls the
twice-paying tool "the strongest argument for building it.")*

**I refuse it, on five measured grounds, and I name the one part of it that survives.**

### 6B.1 — THIS PROJECT ALREADY BUILT A PER-PIECE FIREBASE STAMPER AND BURIED IT

`tools/gen_firebase.py:1-13`, the header of the file that owns the 23 families:

> *"It is a shapes library first and a script second: **the kit GLBs it can write are a REVIEW
> artefact, not a shipped asset set** — nothing in the game places a firebase piece individually
> (`site_layouts.gd` has no firebase entries and **`stamp_firebase` died with `fsb_main`**), so
> **shipping 24 kit GLBs would be 24 files with one consumer, which ADR-023 would correctly come
> for.**"*

Three things verified against the tree just now:

1. **`stamp_firebase` is DEAD.** Zero hits anywhere in `scripts/`, `tools/`, `terrain/`. Its only two
   surviving mentions are tombstones: `tests/test_smoke_all.gd:133` (*"stamp_firebase died with
   fsb_main, task 6b"*) and the header above. **This project built a per-piece firebase stamper,
   decided against it, and killed it.**
2. **`site_layouts.gd` has ZERO firebase entries** — I grepped `fb_` and `firebase`: nothing. So there
   is no layout table for a firebase kit, and creating one lands squarely on ADR-041's FROZEN list
   (*"`site_layouts.gd` — adding the offset/layout tables its header claims"*).
3. **A live POINTER LAW violation in the very file the pivot would build on.** `gen_firebase.py:6`
   says *"This module is IMPORTED BY `tools/build_fsb_main.py`"* — and **`tools/build_fsb_main.py`
   does not exist.** Correct it on contact. It also means the pivot's foundation file is already
   lying about its own consumer.

> **The pivot proposes to resurrect a system this project deliberately buried, using a file whose own
> header explains why burying it was right. That is the fossil law read backwards.**

### 6B.2 — CONTENT-FIRST IS THE STANDING LAW, AND THIS IS EXACTLY WHAT IT FORBIDS

`content-first-optimize-later` (RULED 2026-08-08, his words):

> *"i do want to optimize stuff but id rather just keep making models and animations til i ahve
> everything i need"* → *"than go back and make them optimized."*
>
> **"when an optimization finding surfaces mid-content-work, record it and move on — do not propose it
> as the next action, and do not stall the content task on it."**

And the note's own framing correction, which lands directly on §3 of this analysis: *"the levers are
duplicate images/materials, draw calls, and what accidentally ships."* **Every headline benefit in the
intent doc's table is a draw-call / duplicate-material / accidentally-shipped finding.** That is the
literal list this law says to *record and move on from*.

The irony is exact and worth stating: **the two 8.63 MB byte-identical textures I found in §3.4 are
the same defect class this law was ruled over** — the memory names *"4x duplicated 3600x5700 reference
sheets = 312 MB for one image (`ref_factions.001` and `.002` literally resolve to the same file)."*
`recovered_ref_factions` is that same sheet, still in the shipped GLB, still duplicated, thirteen
months of project-time later. **He ruled: record it, keep building. He did not rule: re-architect the
base around it.**

**A generalised kit built for a war that does not exist yet is this law's worst case** — it is not even
an optimisation of content that exists; it is infrastructure for content that has never been scoped.

### 6B.3 — THE CORRECT TEST, AND HOW THE EVIDENCE RULES ON IT

> **THE TEST: the Vietnam demo must be BETTER for this change, on its own merits, measured, before
> WW1 is allowed into the conversation. If it is better, the second war is a bonus. If it is not, no
> number of future wars rescues it — a lever that is negative once is more negative twice.**

**The evidence supports the second branch, and it is not close:**

- §4 — the pivot fixes **none** of the five things he saw in the Vietnam build.
- §5 — its stated benefit (berms) is a bottom face on one swept mesh.
- §3.2/§3.3 — it costs **878 surfaces** on the interior fold, and MultiMesh cannot recover them
  because the kit's parts are the destructible ones.
- §1.1/§1.2 — its headline deliverable already exists.
- §7 — it costs 40–60 h against 10–16 h of open stranger-blockers on a demo with **no shippable exe**
  and a **passed EA date**.

**The Vietnam demo is measurably WORSE for this change tonight. So WW1 is not admissible as a
justification. It would be admissible as a bonus on a change that already stood up alone.**

### 6B.4 — PRICING AGAINST A SECOND WAR IS ITSELF A SCOPE-WALL BREACH, AND WORSE THAN THE USUAL KIND

`production/GAME_GUIDE.md:26`: **"Launch scope is ONE faction: the US Army grunt."** SF and Marines —
*the same soldiers, in the same war, in the same jungle* — are **post-launch**.

`GAME_GUIDE:330`: **"A frozen epic thaws only by explicit decree."**

**WW1 is not on the FROZEN list (`:327`) and not on the PARKED list (`:326`).** That is not permission;
it is the opposite. Those lists are populated by things that were *scoped and then deferred.* **WW1 has
never been scoped at all.** Pricing engineering against it tonight would put an unscoped second war
ahead of SF and Marines, which are scoped, deferred, and in the same conflict.

**And `GAME_GUIDE:326` hands us the leak precedent as a live specimen, not a hypothetical:**

> *"**THE SLEEP / RACK-OUT RUN-ENDER** ... The code is **built and DORMANT, not reverted**:
> `FieldDirector.SLEEP_POST_LAUNCH` (`field_director.gd:1201`) gates the rack verb off ... Do not
> resurrect sleep as launch scope; do not delete it either."*

That is the exact mechanism ADR-039 and ADR-041 forbid **by name** (§6 above) — sitting in the
GAME_GUIDE as a thing that already happened. **The project has a worked example of post-launch work
getting built during launch scope and then having to be permanently gated off.** Any WW1-justified
phasing produces a second one.

**Same paragraph, same row, independently corroborating §4(4):** *"convoy that forms up and drives out
(his ruling 2026-08-28)"* is listed **PARKED** in the GAME_GUIDE itself.

### 6B.5 — THE COST DELTA: I CANNOT PRICE IT, AND THAT IS THE ARGUMENT

The Arbiter asked me to price the extra cost of a kit generalised for two wars over one. **I cannot,
and I will not pretend to.** But I can bound the two halves, which settles the question anyway.

**What actually generalises across wars is the PLACER, and I counted it: 41 lines.**
`tools/gen_firebase_v3.py` — `place()` `:503-522` (20 lines), `free_spot()` `:489-502` (14),
`footprint_r()` `:482-488` (7). That is the entire war-agnostic core, and **it already exists and
already works.**

**What does not generalise is every single part.** All 23 families are Vietnam-specific by
construction: `fb_hootch`, `fb_gp_tent`, `fb_howitzer` (M101), `fb_helipad`, `fb_claymore`,
`fb_burn_barrel`, `fb_latrine`, `fb_wire_belt` (concertina), `fb_sandbag_stack`, `fb_bunker_mg`,
`fb_toc`, `fb_mess`, `fb_aid_station`. **A WW1 trench system shares approximately zero of them.** The
one plausible exception is `fb_trench_run` — which, per §1.2, **already exists and already ships.**

So the "pays twice" claim reduces to: **41 lines of placement arithmetic pay twice, and the entire
art bill is paid per war regardless.** That is not a franchise multiplier. That is a helper function.

**And the delta I cannot price is the one that matters:** how much *more* it costs to build a kit
"generalisable enough for a second setting" than one that just does Vietnam. Nobody can price that,
because nobody knows what WW1 needs — there is no WW1 brief, no WW1 scope, no WW1 art list, no WW1
ADR. **A generalisation with no specification is not a generalisation; it is a guess with a budget.**

> **Unpriceable is the argument, not a gap in it.** ADR-041 §12 could price village + temple only
> because both had been specified. Anything priced against WW1 tonight is priced against nothing, and
> a number priced against nothing will be quoted later as if it were measured. This project has a
> standing law about exactly that (POINTER LAW), and eleven refuted claims from one audit proving it
> is not theoretical.

### 6B.6 — WHAT SURVIVES, AND IT IS SMALL BUT REAL

**Ground I concede.** The comic adaptation is real, it is scoped as a document
(`production/CONQUEST_OF_WORMS_BIBLE.md` and `_TREATMENT.md`, both written tonight), and `9031b7f4`
records his own ruling: *"Scope: the whole comic adaptation is post-demo launch."* **He has already
scoped it correctly himself.** So the honest position is not "WW1 is fantasy" — it is:

> **WW1 is a real future, correctly parked by his own decree, and the right thing to do with a real
> parked future is to WRITE IT DOWN, not to pre-build for it.**

Which is precisely what `FIREBASE_REWORK_INTENT.md` already does and says it is doing at line 8:
*"POST-DEMO. Recorded as intent, not authorised."* **The intent doc has the right posture. The council
should not talk it out of it.**

### 6B.7 — HOW ADR-023 WOULD ANSWER "DOES A ONE-SENTENCE-OLD FRANCHISE COUNT AS A CONSUMER?"

**No, and the answer is already written in this repo, by name.**

ADR-023's operating definition (`CLAUDE.md`, THE FOSSIL LAW): *"A **fossil** — a const nobody reads, a
signal nobody connects, a function nobody calls — is not a bug. The game runs fine with it. It is
worse than a bug: **it is a lie in the map.** It reads as load-bearing and it survives every grep, and
you cannot tell it from live code."*

A kit built for a second war that has no brief is **24 files with one consumer and one aspiration** —
and `gen_firebase.py:10` has already ruled on that exact sentence: *"shipping 24 kit GLBs would be 24
files with one consumer, **which ADR-023 would correctly come for.**"* An aspiration is not a consumer.
The `unit_id` warning in the same law applies double: *"913 of 1,291 assets had zero grep hits."*

**And the triage ADR-023 mandates is decisive here.** Its three buckets are FOSSIL (superseded →
delete), UNFINISHED (built ahead of its wiring → wire or cut), MISSING FEATURE (documented, never built
→ build it). **A WW1 kit is bucket two, deliberately entered.** ADR-023's own instruction for bucket
two is *"wire or cut"* — and it cannot be wired, because the thing it would wire to does not exist.

> **ADR-023's verdict: build the kit when the second war has a brief. Not before. The brief is the
> consumer.**

---

## 7 · WHAT ELSE THE HOURS COULD BUY

**Open demo blockers** (`recon-demo-audit-2026-09-07`, `PLAYTEST_FINDINGS_2026-08-28.md`):

| Blocker | Cost | Status |
|---|---|---|
| **No onboarding at all** — controls surface nowhere, `grep PLAYER_MANUAL` = 0 hits | 4–8 h | open |
| **The siege forms up OFF THE MAP** — `RING_MIN 300`/`RING_MAX 500`, `MORTAR_TUBE_STANDOFF 700` on a **512 m** map; **1,057 `floor_y` no-collider misses** in one siege; attackers walk ~200 m on nothing | 2–6 h | open |
| **White untextured surfaces on the walked path** + **10 stray props ~900 m off** (merged AABB 996.96 m → 271.90 m if they move) — must regenerate `firebase_v3_destructibles.json` in the same change | small | open |
| Payoff at **minute 23–24** (`PROBE_AT_S 1395`/`SIEGE_AT_S 1440`), no guaranteed contact before it | **a ruling, not a build** | his |
| `__bolt` / `__mg` / `__launcher` clip families **do not exist** — every MG, bolt and RPG man in the 45-man assault holds his weapon like a rifle | 3 art-days | open |
| **`build/RECON_Demo.exe` is dated 2026-07-31** — there is no artefact to hand anyone | — | open |
| Bunker collision — **cannot enter ANY bunker** (item 3) | small | open |
| NPC squads spawn on the hooch ROOF (item 6) | small | open |
| Squad cannot path into the hooches (item 22) | small | open |
| **THE EA TARGET DATE (2026-09-06) HAS PASSED** with the entry gate undischarged | — | — |

**All five stranger-blockers: roughly 10–16 engineering hours plus 3 art-days.**

**Against that, the pivot's floor price.** ADR-041 §12 prices **village + temple only** at **14–19 h
engineering + 6–12 h of his authoring = 20–31 h**, and names the two steps *"most likely to be tempted
away"* — the marker-vs-navmesh probe and the composite float check — with the warning that skipping
them *"is exactly how the chow-hall markers shipped broken."*

**The firebase is a larger artefact than a village and a temple combined:** 23 families, 4,437 mesh
nodes, 80 exact-name destructible segments feeding the siege, 488 work markers, a mound manifest, a
ported height function, a measured falloff constant, and a re-export pipeline. **Scaling ADR-041's own
arithmetic, 40–60 h is the conservative floor** — before the interior-fold rebuild (§3.2), the per-part
contract audit (§3.5), and the material/texture dedupe (§3.4) that nobody has costed.

> **40–60 hours is every open demo blocker, three times over, spent instead on a base that already
> stands — in a build whose payoff currently forms up 200 m outside the map, and for which there is no
> shippable executable.**

---

## 8 · THE ONE ARGUMENT FOR THE PIVOT I CANNOT REFUTE

**Placement is only true where the navmesh is. This project has paid for that lesson in cash,
repeatedly, and every payment is documented.**

ADR-041's own context line, which is a *measurement*, not an opinion:

> *"every expensive defect closed was a PLACEMENT defect — invisible in Blender, obvious in Godot with
> a baked navmesh."*

The receipts:

- **Sixteen chow-hall work markers off the navmesh, so the cook could not stand at his own stove.** And
  the fix that shipped was **not code** — commit `8e1129c7` moved 16 of 48 markers in the source asset
  after measuring each against the bake. **A Blender session cannot measure against a bake.**
- Every bunker work marker at **exactly the player capsule's radius from its own wall, zero margin.**
- Furniture in the world with no building around it.
- Tonight's additions to the same ledger: **10 stray props ~900 m from the compound origin**;
  `fb_aid_station` matching **zero** nodes because the asset was renamed inside the bake;
  `fb_sbg_seg_046_001`, a `.001` duplicate sitting invulnerable among 80 destructible twins.

**Not one of those is findable in Blender.** Every one is *"this thing is in the wrong place relative
to a navmesh, a player capsule, or a collider that only exists in Godot."* Authoring where the navmesh
is would have made all of them visible at authoring time instead of six weeks later in a playtest.

**That argument is correct, it is his, it is already ratified as ADR-041, and I have no counter to it.**

**My only qualification is timing, not truth:** it is an argument for authoring **the next** place in
Godot. It is not an argument for dissecting the one that already stands, three days after the EA date
passed, while the siege forms up outside the map.

---

## 9 · WHAT I ASK THE ARBITER TO REFUSE, IN ORDER

1. **Any claim that the pivot "creates modular parts."** They exist — 23 families, a `place()` stamper,
   a shipping trench module (§1.1, §1.2). Correct `FIREBASE_REWORK_INTENT.md:103` on contact.
2. **Any claim that the pivot fixes the five observations.** It fixes none of them (§4).
3. **Any claim that it removes people falling through berms.** That is a missing bottom face plus a
   height-authority swap (§5).
4. **Any phasing whose deliverable is invisible in the demo build.** That is the leak mechanism both
   ADRs forbid by name (§6).
5. **Any cost estimate below 40 h** that has not separately costed the interior-fold rebuild, the
   per-part naming-contract audit, the material/texture dedupe, and the 80-segment manifest
   regeneration.
6. **Any use of WW1 to justify the pivot.** The test is that the Vietnam demo must be better for the
   change on its own merits; it is measurably worse (§6B.3). What generalises is a 41-line placer that
   already exists; every part is per-war regardless (§6B.5). And this project already built a
   per-piece firebase stamper and buried it — `stamp_firebase` is dead, and `gen_firebase.py:10` says
   why: *"24 files with one consumer, which ADR-023 would correctly come for"* (§6B.1, §6B.7).
   **Refuse any number priced against WW1: there is no WW1 brief to price against, and an unpriceable
   number gets quoted later as a measured one.**

## 10 · WHAT I ASK IT TO DO INSTEAD, TONIGHT

All four are bug fixes, all four exempt under ADR-015, none needs a thaw:

1. **Cap the berm and mound sweeps** (`gen_firebase_v3.py:271-300`, `terrain_mound()`) — ~10 lines plus
   a re-export. Probe: cast upward from under the berm ring; it must hit.
2. **Clearance-test `Ladder.dismount_point()`** (`ladder.gd:133-136`) — shape-cast, fall back to the
   rail. Probe fails when reverted.
3. **Shrink the two 8.63 MB textures** — `python tools/shrink_oversized_textures.py --apply`. They are
   byte-identical duplicates and both violate the 1 MB law by 8.6×.
4. **Surface item 35 to him:** he parked convoys himself on 2026-08-28 (*"and same with the convoy"*)
   and is now asking for them. It is PARKED in `GAME_GUIDE.md:326` as well as `PLAYTEST_FINDINGS`
   item 35. Only he can reverse that.
5. **Correct two live pointer-law violations found in passing** (NO MORE DRIFT, correct on contact):
   `gen_firebase.py:6` names `tools/build_fsb_main.py` as its importer and **that file does not
   exist**; `FIREBASE_REWORK_INTENT.md:103` calls the trench module *"genuinely missing"* when it
   ships 16 nodes.

**And record the pivot as an ADR with no code. `FIREBASE_REWORK_INTENT.md` already models the right
posture: recorded, not authorised.**

---

## EVIDENCE

Everything below measured or read this session.

**Measured by me, `assets/world/building models/structures/firebase/fsb_main_v3.glb`:** 5,810 nodes ·
4,437 mesh nodes · 2,274 meshes · 2,457 surfaces · **5,753 instance-weighted surfaces** · 159
materials · 342,219 triangles · 30 images / 20.74 MB · 618 mesh nodes with no node transform ·
`recovered_ref_factions` and `better textures` **byte-identical at 8.63 MB each** (MD5) · `fb_crate` /
`fb_ammo_crate_stack_fb_crate` byte-identical · family table in §3.4 · `fb_trench` = 16 nodes present.

**Measured by me, `.../firebase/kit/firebase_v3_destructibles.json`:** `segment_len 6.0`, `hp 140`,
`count 80`, 80 segments, first entry `fb_sbg_seg_000` at `[95.575, 3.002, 2.935]`, box
`[6.6, 0.37, 1.17]`.

**Read this session:** `tools/gen_firebase.py:503-514` (`fam_trench_run`), `:856-878` (`FAMILIES`, 23) ·
`tools/gen_firebase_v3.py:271-300` (`berm`, two strips, no bottom), `:322-355` (`parapet_segments`),
`:503-522` (`place`), `:964` (`assert_colonly_terminal`), `:1041-1186` (masters + layout), 1,212 lines ·
`tools/reexport_firebase_v3.py` 115 lines · `scripts/world/interior_prop_fold.gd:1-70` ·
`scripts/world/site_planner.gd:1735-1875, 1995, 2156-2261, 1402-1460, 998, 962` ·
`scripts/world/ladder.gd:6-25, 36-60, 133-136` · `scripts/player/player.gd:1455` ·
`scripts/world/road_network.gd` full function list, `:36, :383, :394-405` ·
`scripts/missions/mission_generator.gd:213, 259, 650-653, 697-910, 910-914` ·
`scripts/missions/siege_director.gd:407, 659, 687` · `scripts/enemies/camp_director.gd:137-140` ·
`scripts/enemies/marching_cell.gd:245` · `scripts/squad/squad_system.gd:111, 757` ·
`scripts/world/litter_team.gd:173` · `scripts/ai/air_traffic.gd:539-544` ·
`scripts/vehicles/heli_lift.gd:39-40, 338` · `production/PLAYTEST_FINDINGS_2026-08-28.md` QUEUE (items
3, 4, 5, 6, 8, 22, 24, 35, Q1/24, and the collision-pass note) · `production/PERF_LEDGER.md` tail ·
`production/CALEB_TODO_7_22_updated.md` tail · ADR-039 and ADR-041 in full ·
`production/FIREBASE_REWORK_INTENT.md` · memories `recon-destructible-export-contract`,
`recon-demo-audit-2026-09-07`.

**Read for §6B:** `tools/gen_firebase.py:1-13` (the kit-GLB refusal, *"24 files with one consumer"*,
*"stamp_firebase died with fsb_main"*) · `tests/test_smoke_all.gd:133` (the second tombstone) ·
`scripts/world/site_layouts.gd` (grepped `fb_` and `firebase`: **zero hits**) ·
`tools/build_fsb_main.py` (**does not exist**, though `gen_firebase.py:6` names it) ·
`production/GAME_GUIDE.md:26` (ONE faction, US Army grunt), `:326` (PARKED — convoy, and
`SLEEP_POST_LAUNCH` built-and-dormant), `:327` (FROZEN list — WW1 absent), `:330` (*"A frozen epic
thaws only by explicit decree"*) · memory `content-first-optimize-later` · commit `9031b7f4` (*"Scope:
the whole comic adaptation is post-demo launch"*) · `production/CONQUEST_OF_WORMS_BIBLE.md` and
`_TREATMENT.md` (untracked, written tonight). **Counted:** `place()` `:503-522` + `free_spot()`
`:489-502` + `footprint_r()` `:482-488` = **41 lines** of war-agnostic placer.

**Git:** 17 commits against the firebase GLB / exporter; `1c517cf8`, `15d91d06`, `c907cb04`,
`3d4b6093`, `d904fd70`, `5ed4b181`, `8e1129c7`, `34249d13`, `5bead05a`, `fc538238`, `d29a7860` cited
by title.

**NOT MEASURED, named so nobody quotes it as measured:** the frame cost of a stamped kit. No windowed
run may be taken while he is playing (pid 13196), and the project's own bench is under his ruling
*"its just terrain with no action so its not really gauging anything."* **Every draw-call figure in §3
is a STRUCTURAL surface count, not a frame measurement.** The 5,753 figure is an upper bound the
frustum never pays in full.
