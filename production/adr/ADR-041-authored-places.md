# ADR-041: The scene is a PLAN, not a prefab — authored places without a second placement path

**Date:** 2026-09-06 · **Status:** ACCEPTED as canon; **POST-DEMO — BUILD NOTHING**
(Summoner ruling, mid-council: *"i guess this is post demo work."*) ·
**Extends:** ADR-039 clause 1 (one builder, many places) from AREAS down to SITES ·
**Depends on:** ADR-010 (one seed), ADR-023 (fossil law), ADR-028 (the protected foundation) ·
**Corrects:** ADR-039 §3's citation of "ADR-020 §4" (stale — see §6) ·
**War Room:** `production/war_room/2026-09-06_authored_places/`

---

## Context

The Summoner asked a direct architecture question:

> *"would it be better to make the village and temple stamps in godot as scene and than in the map it
> makes a flat zone for the places? that way i can make sure the spawns are right etc?"*

It arrives on the back of a day in which **every expensive defect closed was a PLACEMENT defect** —
invisible in Blender, obvious in Godot with a baked navmesh. Sixteen chow-hall work markers off the
navmesh, so the cook could not stand at his own stove. Every bunker work marker at exactly the player
capsule's radius from its own wall, zero margin. Furniture in the world with no building around it. The
instinct behind the question is therefore correct and evidence-backed: **things authored where they are
seen are right; things computed where they are not seen drift.**

It also arrives with the RPG pivot on the page. ADR-039 §3 accepted, as the price of never fracturing the
world build, that *"the world can never be composed"* — while the same decree asks for *"the descent as a
chain of self-contained vignette LOCATIONS ... Do Lung Bridge is the model — **a PLACE that says
everything, not a cutscene**"* (`production/war_room/2026-09-06_rpg_pivot/briefing.md:71-74`). **That
tension is what this ADR resolves.** Without a legal authoring mechanism, item 13 of the pivot is
unbuildable.

## Decision

### 1 · THE GOVERNING LAW

> ## **THE SCENE IS A PLAN, NOT A PREFAB.**
>
> An authored site is **markers, spawn points and a layout** handed to the one builder. The planner
> keeps **WHERE** and **WHETHER**; the authored artifact decides only **WHAT SITS INSIDE ITS OWN
> FOOTPRINT**. A site scene may never construct terrain, never choose its own world position, and never
> reach for a placement entry point from its own file.

This is ADR-039 clause 1 read one level down. Clause 1 says an outdoor AREA is a plan, never a scene.
This ADR says a SITE is a plan too — and authoring is a way of **writing the plan by hand** rather than
drawing it from a seed. The builder is untouched. The protected foundation (ADR-028) is untouched.

> **THE ANTI-CREEP RULE, stated so it can still say no in two years:**
> **An authored scene may compose only what fits inside ONE `clear_and_flatten()` disc that the planner
> chose, and it MAY NOT KNOW ITS OWN WORLD POSITION.** If it needs to know where the river is, where the
> firebase is, or what the terrain does outside its own footprint, it is an outdoor AO wearing a costume
> and it fails ADR-039 clause 1.

Deliberately the same shape as ADR-039 clause 4's existing test for interiors.

### 2 · THE PROBE VERDICT — what actually trips, and the safe shape

`tests/test_placement_paths.gd` enforces three rules. An authored `.tscn` **does not trip any of them**,
with one exception, precisely named:

> **The only way an authored site fails the probe: give the scene a script under `res://scripts` or
> `res://terrain` that calls `place_structure(` / `place_prop(` / `stamp_village(` / `stamp_vc_camp(` /
> `stamp_lz(` / `place_firebase_main(`.** That file is not in `CALLER_MANIFEST` and fails as *"a SECOND
> placement path (ADR-028)"* (`tests/test_placement_paths.gd:12-68`).

**The safe shape: the authored scene carries NO script, or a script that is a pure data reader.** All
instancing stays inside `site_planner.gd`. That is exactly `scenes/world/firebase_main.tscn`'s shape.

**But passing this probe is NOT evidence of one path, and the ADR records why** (truth law):

- **`PLACEMENT_CALLS` does not include `load(...).instantiate()`.** A genuine second placement path
  written as a bare `load(path).instantiate()` + `add_child()` in another file is **invisible to this
  probe**. It polices *names*, not the *act*.
- **`SEEDED_FILES` is a fixed six-file whitelist** (`:30-37`). A new `scripts/world/village_site.gd`
  calling bare `randf()` — to jitter a chicken — **passes rule 2** while breaking ADR-010. ADR-039 §2
  already named this hole; this ADR names the concrete way authoring would walk into it.

> **BINDING: any script that ever lands on an authored site is added to `SEEDED_FILES` in the same
> change, or the determinism guard is a no-op for it.**

### 3 · A COMPOSED `.tscn` THROUGH `place_structure()` IS FORBIDDEN — THE TEN CONTRACTS

This is not stylistic. `place_structure()` (`scripts/world/site_planner.gd:190-266`) is a **per-model
factory keyed on one filename** (`:191`). For a composite `village_a.tscn` that key is `"village_a"`, and
**every branch degrades to a warning and a wrong default**:

1. `CollisionTable.get_entry()` — **miss**; falls back to `box 3×2×3, footprint 4×4`
   (`collision_table.gd:204-210`), with one `push_warning` ever, then silence.
2. `_destructible_kind_for()` — no prefix match → `""`. **The whole village becomes one indestructible
   `StaticBody3D`**, losing the destructibility restored nine days ago.
3. `set_meta("model_name")` — becomes `"village_a"`. **Load-bearing**: the tree auto-renames duplicates,
   so twelve huts in one scene become `nha_tranh_01`, `nha_tranh_012`… and every `CollisionTable` lookup
   **breaks silently** (`:203-205`).
4. `CollisionTable.is_soft()` — no authored material, filename guess fails → **HARD**.
5. `tag_ballistics()` then walks the **whole subtree** and marks every collider `hard_surface`. **Every
   thatch wall becomes bulletproof** — the exact 2026-07-12 defect, re-created wholesale (`:221-224`).
6. `nav_blockers` + box — **one 3m carve for a 60m village.** The navmesh runs flat through every hut.
7. The `hard_surface`/`soft_cover` de-duplication (`:253-257`) — skipped.
8. `AgentRegistry.register()` — *"an unregistered `Destructible` is one nothing can ever hit"*.
9. `_apply_visibility_range()` — this one *does* recurse and survives.
10. `CampaignState.tunnel_is_collapsed()` → `queue_free()`. **ADR-029 Amendment B, the world remembers.**
    A tunnel mouth the player satchelled last patrol must not exist; **a hand-placed tunnel node
    resurrects it.**

**And this bug class already shipped and was fixed nine days ago.** `site_planner.gd:165-171`:

> *"THE VILLAGE HUTS WERE INDESTRUCTIBLE (playtest 2026-08-28, fixed 2026-09-06) ... a hut inside
> `fsb_main_v3.glb` could be blown down and the identical hut stamped into a village by this function
> could not. **Two tables would drift again, so there is ONE.**"*

**The probes go blind to it too.** `tests/test_site_stamp.gd:79-87` checks each node in `village.nodes`
for being >4m off ground. If the site dict lists only a composite root, **one node is checked and every
floating hut inside is unmeasured.** A green suite would certify a broken village.

### 4 · WHAT IS LEGAL — THE THREE TIERS

| Tier | What is authored | What stays generated | Status |
|---|---|---|---|
| **A · MARKERS** | Spawn / role / work markers in a thin `.tscn` beside the model | Everything else | **Already legal, already shipping** |
| **B · CLUSTERS** | A multi-building cluster composed **in Blender**, exported as one contract-named GLB, plus a marker `.tscn` | Where clusters go, how many, rotation | **Legal under this ADR; UNBUILT** |
| **C · THE AO** | *Nothing* | Site positions, paddies, roads, terrain, vegetation | **ADR-039 clause 1 — not negotiable** |

**Tier A is the Summoner's actual ask, and he already ruled it legal himself.**
`site_planner.gd:805-816` records his decree of 2026-07-29 verbatim — *"we make the main firebase a real
scene in godot and give me spawn markers that i can place"* — with the crucial property stated: *"those
markers live in the SCENE, not in the GLB, so re-exporting the GLB from Blender can never delete them.
**Anything hand-placed in the compound belongs in that scene for the same reason.**"*

**Tier B puts the composition in Blender, not in the `.tscn`, because that is where the naming contract
lives.** `_wire_structure_destructibles()` (`:2046-2070`) walks a composed GLB root and adopts every
child mesh onto a `Destructible` **by name prefix**. A cluster exported with `nha_tranh_*` / `nha_san_*`
meshes therefore inherits destructibility, ballistics and the blast bus **through the one path, for
free**. This is the mechanism the firebase already uses, generalised — not a new one.

**If a Tier-B site is ever instanced directly rather than through `place_structure`, it must do for
itself what `place_firebase_main()` does** (`:1431-1515`): seat, repair colliders, cull interiors, wire
destructibles, build ladders **after** seating, and hand its own root to the nav baker.

### 5 · SPAWNS: AUTHOR THE POSITIONS, SEED THE OCCUPANCY

The Summoner's stated purpose is *"that way i can make sure the spawns are right."* Granted — with one
guard that keeps Pillar 5 intact.

> **He authors WHICH POSITIONS ARE GOOD. The seed chooses WHICH ARE OCCUPIED, and by how many.**

A fully hand-placed enemy set makes the second playthrough a memorised fight — *"never
reload-and-memorize."* Authoring the *positions* and seeding the *occupancy* gives a firefight with a
deliberate shape and a different answer every run. This is ADR-020 §1's guarantee-not-rail move applied
to geometry: the player is promised good ground, never a fixed script.

**AND HAND-PLACED DOES NOT MEAN CORRECT.** Nothing snaps a marker to walkable ground.
`_collect_stations` (`:648-664`) records `global_position` verbatim; `NavRouter.nearest_mesh_point`
(`scripts/ai/nav_router.gd:63-77`) returns the point **unchanged** unless a baked box covers it. The
chow-hall fix that actually shipped was **not code** — commit `8e1129c7` moved 16 of 48 markers in the
source asset after measuring each against the bake.

> **BINDING: any authored-site work ships a marker-vs-navmesh probe in the same change** — assert every
> spawn and `work_*` marker is within agent clearance of a baked polygon, fail the build otherwise —
> **or it has merely moved the chow-hall defect into a new file.**

### 6 · THE FLATTEN IS PER-SCENE AND BLENDED — NEVER MANDATORY

**A flat pad in rolling terrain reads as a game asset dropped on a map.** A village beside paddies is
honest flat ground; a temple on a slope should follow the slope.

Measured, so the cost is known rather than assumed: **`clear_and_flatten()` does not flatten.** It stages
a `ClearingSystem` zone whose `CLEARED` stage carries **`height_flattening: 0.7`**, applied as a lerp
toward the disc mean (`terrain/systems/clearing_system.gd:37-39, 140-148`). **~30% of the relief
survives, with a falloff toward the rim.** Procedural stamping does not care, because `place_structure`
re-samples terrain height **per building** (`:246-248`). **An authored cluster with fixed local
transforms does care** — on a partly-rolling pad, props at the rim float or sink.

> **BINDING: an authored site ships with its own declared flatten profile — radius, strength and blend
> shoulder — or it does not ship.** A site that silently demands `flattening = 1.0` is requesting a
> pancake, and pancakes are refused.

The firebase is the honest price list for seating an authored place on generated ground: a Blender
generator, a mound manifest (`fsb_main_v3_mound.json`), a ported height function (`fsb_mound_height()`,
`:868-897`), a measured falloff constant (`FSB_PLATEAU_FALLOFF = 0.107`), a real sculpt ordered *after*
the veg clear (`:1455-1474`), and a diagnostic tool. **~200 lines of seating machinery behind a 13-line
scene.** Anyone costing Tier B must cost that, not the 13 lines.

### 7 · TWO THINGS THAT WILL BE ASSUMED AND ARE FALSE

1. **The 230m structure cull is NOT inherited by a directly-instanced scene.**
   `STRUCTURE_VISIBILITY_END = 230.0` is applied by `_apply_visibility_range`, called from exactly two
   places: `place_structure:220` and `place_prop:463`. **`place_firebase_main` never calls it**
   (verified across `:1479-1515`). A directly-instanced village draws every hut, fence and prop at any
   distance, in a project the ledger already calls call-bound (`:1551-1560`: firebase interiors were
   *"45% of the compound's draw calls for 4% of its geometry"*). Remedy is one line — but it must be
   written, not assumed. **FPS impact UNVERIFIED; not benched.**
2. **NavBaker gives an authored site a TERRAIN-ONLY bake.** `WorldConfig.NAV_SITE_KINDS:40` already
   contains `village` and `temple`, so `should_bake` passes — but `queue_sites`
   (`scripts/world/nav_baker.gd:121-141`) has two routes: `firebase_main` → the real-collider path;
   **everything else → a plain box fed to `_add_structures`, which iterates only the `nav_blockers`
   group.** An authored scene root is in no group and carries no meta, so **the mesh runs straight
   through every hut**. `nav_baker.gd:34-41` says exactly this about the firebase: *"worse than no
   navmesh, because it would look deliberate."* The fix is to route authored kinds to the already-public
   `queue_site_with_colliders()` (`:186-188`), and to extend `_clear_of_firebase`'s overlap handling to
   N collider-rooted sites — untreated overlap *"severed every path between them."*

### 8 · DETERMINISM: AUTHORING HELPS, WITH THREE NAMED HAZARDS

An authored layout is **more** deterministic — it removes the hut-count draw, `_scatter_huts`,
`_dry_point` and per-hut model/rotation draws (`:288-354`), and shortens the shared stream. Hazards:

1. **`_ready()` fires before the seat.** `place_structure` adds to the tree at `:245` and sets
   `global_position` at `:247`; anything caching a world position in `_ready()`/`@onready` reads it **at
   the origin**. `:1489-1491` records this exact bug for `Ladder`. **LAW for authored sites:
   instantiate → seat → THEN wire.**
2. **A script with bare `randf`**, uncovered by `SEEDED_FILES` — see §2.
3. **`AnimationPlayer` autoplay** starts at instance time, so two identical worlds diverge in visual
   phase. Project convention is manual (`_play_idle`, `:667-675`). Leave `autoplay` empty; drive from code.

### 9 · TWO STALE CLAIMS CORRECTED ON CONTACT (NO MORE DRIFT)

1. **ADR-039 §3 cites a section that does not contain its argument.** It says *"The reconciliation is §4
   of ADR-020"* — but **ADR-020 §4 is the Ambience Law**, about how often ambient events fire at the
   firebase. It says nothing about stamping or dressing places. The argument is sound; the pointer is
   wrong. **Re-point it to ADR-020 §1-§2** (the rail/guarantee distinction and authored-dense placement),
   which is what actually licenses authored ground.
2. **`scripts/world/site_layouts.gd:2` is false.** Its header claims *"Offsets in meters relative to site
   center; rotation in degrees."* **The file contains zero offsets** — it is a model-pool and manifest
   file, not a layout file. The authored-layout ambition was written into a comment and never built.

### 10 · ADR-020 IS NOT THE OBSTACLE, AND SAYING SO MATTERS

Hand-authoring geometry **does not violate Pillar 3**. ADR-020's binding test asks *"can the player turn
around and LEAVE, right now?"* — an authored hut layout takes nothing away. The player enters from any
bearing, skips it, burns it, or never finds it. **ADR-020 governs EVENTS — who holds the stick during a
set-piece — not who placed the geometry.** Every example in its §3 table is an event; its §1 blesses
hand-work by name (*"AUTHORED-DENSE"*).

The real constraint was never the pillars. It is ADR-028's one-path law, and §1-§4 are how it is satisfied.

## 11 · THE MEASURED DEFECT, AND WHY IT IS NOT THIS ADR'S JUSTIFICATION

Item 32 (*"animals inside huts, tables through walls, NPCs stuck in walls"*,
`production/PLAYTEST_FINDINGS_2026-08-28.md:354, 590`) is **ACCEPTED-OPEN**, not a defect awaiting this
ADR. Measured this session by `tools/probe_village_embed.gd` (commit `6387c3e3`): the first pass reported
61/112 embedded and **was almost entirely a broken instrument** (`RaycastCollision`, an engine-wide false
positive); the filtered pass found **exactly 1 real embed out of 61, seed-dependent** — one
`chicken_coop` inside a neighbouring hut's wall.

**Root cause, found in council and recorded so nobody re-derives it:** `_near_building()`
(`site_planner.gd:556-566`) approximates every building as a **circle** of radius
`maxf(fp.x, fp.y) * 0.5 + PROP_BUILDING_MARGIN`. That circle **under-covers the rectangle's diagonal
corners.** For `nha_ruong_02` (footprint 13.3 × 9.1, `collision_table.gd:26`) the clearance circle is
6.65 + 1.2 = **7.85m**, while the building's own corner reaches **8.06m** from its origin. A prop landing
on the diagonal at 7.9m is *inside the hut* and passes the check. `chicken_coop` is zoned `edge`
(`site_layouts.gd:88`) — exactly that band.

**The fix is `fp.length() * 0.5` (the half-diagonal) instead of `maxf(fp.x, fp.y) * 0.5`, plus the prop's
own radius.** One line, on the one placement path. **NOT AUTHORISED HERE** — it is placement-code surgery
in a ship window. Recorded, not built.

> **Therefore: authoring is justified by ATMOSPHERE and AUTHORED PLACES (Pillar 2, ADR-039 item 13),
> never by item 32.** A 1-in-61 seed-dependent papercut with a one-line fix can never buy a new
> mechanism. Any future proposal citing item 32 as the reason to author a village is refused on this
> paragraph.

## Consequences

**Bought.** A memorable place becomes buildable — the Do Lung Bridge of ADR-039 item 13 — without a
second placement path, without a second builder, and without touching the protected foundation. The
Summoner gets the hand-placed spawns he asked for, on the mechanism his own 2026-07-29 ruling already
established. ADR-039 §3's *"the world can never be composed"* is narrowed to its true scope: **the GROUND
can never be composed; a PLACE can.**

**Sacrificed — no free lunches.**

- **Variety is capped at the number of files somebody felt like making.** Author one village and every
  village in every AO is that village — the *Men of Valor* smell the project is organised against. Tier
  B (clusters, procedurally arranged) is a mitigation, not a cure.
- **Replay freshness erodes.** A composed place is a memorised route by the second run. §5's
  seeded-occupancy guard protects the *fight*, not the *layout*.
- **Content debt multiplies.** Every authored place wants dressing, and art is already the binding
  constraint.
- **The seating bill is paid later, by whoever tries to un-flatten it.** Fixed local transforms assume a
  plane; changing the flatten profile afterwards means re-authoring the scene.
- **Two probes must be extended or they will certify broken work** — `test_site_stamp.gd`'s per-node
  float check and the missing marker-vs-navmesh assert. These are the steps most likely to be skipped,
  and skipping them is exactly how the chow-hall markers shipped broken.

## 12 · PRICE (recorded for the thaw; NOT authorised)

Village + temple only, in the direct-instance shape. **Engineering 14–19h · Caleb's authoring 6–12h ·
total 20–31h.** Irreducible core is steps 1–3; steps 4–5 are the ones that will be tempted away.

| # | Step | Hours |
|---|---|---|
| 1 | `stamp_authored_site()`: instance → hard-seat → per-child ballistics/destructible off `CollisionTable` → `_apply_visibility_range` → `_collect_stations` → site dict listing **every building** in `nodes` | 4–6 |
| 2 | Hard-flatten profile: a `modify_terrain` seat with blended shoulder, ordered after the veg clear | 1.5–2 |
| 3 | NavBaker: route authored kinds to `queue_site_with_colliders`; extend overlap handling to N sites | 2–3 |
| 4 | **Marker-vs-navmesh probe** (the chow-hall lesson made mechanical) | 2 |
| 5 | Extend `test_site_stamp.gd` / `test_village_props.gd` for composites | 1.5–2 |
| 6 | Integration + fixing what the probes find | 3–4 |
| 7–8 | Caleb authoring village + temple (temple must re-instate `_stamp_temple_vegetation`, `:498-519`) | 6–12 |

## FROZEN FILES (the scope wall's enforcement surface)

**Nothing in this ADR is authorised. These paths are FROZEN against it until the Summoner thaws them by
explicit decree.** A change justified by "authored places", "the village scene", "the temple scene",
"hand-placed spawns" or "the flatten profile" is a scope-wall breach, regardless of size.

- `scripts/world/site_planner.gd` — `place_structure`, `stamp_village`, `stamp_temple_shrine`,
  `clear_and_flatten`, `_near_building`, `_prop_point`, `_dry_point`, `place_firebase_main`
- `scripts/world/site_layouts.gd` — adding the offset/layout tables its header claims
- `terrain/systems/clearing_system.gd` — `height_flattening` and the stage table
- `scripts/world/nav_baker.gd` — `queue_sites` routing and `_clear_of_firebase`
- `scripts/missions/mission_generator.gd` — `plan_demo_world`'s site list
- `scenes/world/` — no new site `.tscn` under this ADR
- `tests/test_placement_paths.gd` — the clause-1 rule ADR-039 §2 names as unbuilt stays unbuilt here

**AND THE LEAK MECHANISM FORBIDDEN BY NAME:** a *parked-but-built* authored scene shipped behind a flag
"so it is ready" is **not permitted** — the `FieldDirector.SLEEP_POST_LAUNCH` precedent (ADR-039) proves
that is exactly how post-launch work gets built during launch scope.

## Evidence

All file:line verified this session unless marked otherwise.

- `scripts/world/site_planner.gd:190-266` — `place_structure`, the per-model factory (verified).
- `scripts/world/site_planner.gd:165-171` — the indestructible-huts consolidation, *"two tables would
  drift again, so there is ONE"* (verified).
- `scripts/world/site_planner.gd:805-816` — the Summoner's 2026-07-29 markers-in-the-scene ruling and the
  ADR-028 clearance note. **NB: this text lives in the CALLER, not in the `.tscn`** — a `.tscn` is a
  resource file with nowhere to put a comment (verified; corrects the Arbiter's own first pointer).
- `scripts/world/site_planner.gd:2046-2070` — `_wire_structure_destructibles`, prefix-driven adoption on
  a composed root (verified).
- `scripts/world/site_planner.gd:556-566` — `_near_building`'s circle approximation (verified; the
  8.06m-vs-7.85m arithmetic derived from `collision_table.gd:26`).
- `scripts/world/site_planner.gd:118-131` — `clear_and_flatten` stages a clearing zone, not a flatten
  (verified).
- `terrain/systems/clearing_system.gd:37-39, 140-148` — `height_flattening: 0.7` (council architect;
  **not independently re-measured by the Arbiter**).
- `scenes/world/firebase_main.tscn` — 13 lines, 4 nodes, 2 `Marker3D`s (verified by direct read).
- `scripts/world/nav_baker.gd:34-41, 110-141, 186-188` — the two routes and the public collider entry
  (council architect; spot-checked at `:112`).
- `scripts/levels/world_config.gd:40` — `NAV_SITE_KINDS` contains `village` and `temple` (verified).
- `scripts/ai/nav_router.gd:63-77` — `nearest_mesh_point` returns the point unchanged off-box (council
  architect).
- `tests/test_placement_paths.gd:12-68, 30-37, 85-98` — the three rules and both holes (verified).
- `tests/test_site_stamp.gd:79-87` — the per-node 4m float check that a composite would defeat (council
  architect).
- Commit `6387c3e3` — the village embed measurement: 1 real of 61, seed-dependent (verified).
- Commit `8e1129c7` — the chow-hall fix was 16 markers moved in the asset, not code (verified).
- `production/war_room/2026-09-06_rpg_pivot/briefing.md:71-74` — Do Lung Bridge, *"a PLACE that says
  everything"* (verified).

## Related

- **ADR-028** — the protected foundation; §1 is its extension, not its exception.
- **ADR-039** — clause 1 one level down; §3's *"the world can never be composed"* narrowed to the GROUND,
  and its ADR-020 citation corrected in §9.
- **ADR-020** — §10 records that it was never the obstacle; §1-§2 are the real licence.
- **ADR-023** — the fossil law, which §3 exists to avoid re-breaking.
- **ADR-029 Amendment B** — the world remembers; contract 10 in §3.
- **Pillars served:** 2 (Atmosphere — places worth remembering), 3 (Freedom — defended, by proving
  authored geometry is not a rail), 5 (Fail forward — §5's seeded occupancy refuses the memorised fight).
