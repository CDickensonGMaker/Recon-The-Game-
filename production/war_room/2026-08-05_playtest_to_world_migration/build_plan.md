# THE BUILD PLAN — 2026-08-05 — HIS SEVEN RULINGS, ORDERED

Reconvened after the Summoner ruled all seven decisions plus a design correction on collider
promotion. Everything below was verified by reading code. **Where a ruling rests on a belief the code
does not support, that is stated plainly and first.**

**His stated purpose, which outranks feature count:** *"the demo is to show off a few very fleshed
out systems with decent art while i continue to work on the main project but to get people excited
and hyped about whats there."* **DEPTH OVER BREADTH.** Three of the seven are scoped down below on
that authority.

---

## 0. THE FIVE THINGS THAT CHANGE THE PLAN BEFORE IT STARTS

### 0.1 His collider correction is ALREADY HOW THE GAME WORKS — and it collapses two rulings into one

*"it should be just like with the explosives, the object knows its got a collider as a bullet or
something comes towards it… so its on call."*

**Confirmed, and it goes further than he knows.** Since ADR-033 there are **no permanent tree
colliders anywhere**. Chunks store candidate *data*; a pool of 1,280 bodies is lent out to whatever
is wanted right now (`tree_cover_layer.gd:281-333`). Two things make a tree "wanted":
1. **It is within 70 m of the player** (`RING_RADIUS`, `:37`) — a bubble that travels with him.
2. **It is inside a live threat zone** — a time-boxed corridor an explosive stamped on the world
   (`:90-115`).

So: **colliders are already on-call, and the player already carries a permanent 70 m on-call bubble.**

**The consequence for ruling 1 (fallen trees are cover) is the single most important finding in this
plan.** The right implementation is not "give the log a collider." It is **make the log a candidate**
— a data record that the existing ring bodies when something comes near. The collider mechanism is
not merely available, it is **already configured for exactly these meshes**:
`TreeCoverLayer.COVER_TRUNK` (`:20-28`) already carries `fallen_log_a: 0.45 · fallen_log_b: 0.45 ·
felled_tree: 0.40 · felled_trunk: 0.36 · tree_stump: 0.34`.

**And that dissolves most of ruling 6.** He asked whether persistent scarring would lag. Once a
felled log is a candidate rather than a node, **persistence is data and colliders are transient** —
exactly the ledger-and-stream answer, arrived at by the engine's own architecture rather than by a
new system. **CONFIRMED, not refuted.**

### 0.2 The tool that makes the tree assets already specifies this design — it was never wired

`tools/make_felled_tree.py`, its own docstring, unedited:

> `fallen — an instance in a shared MultiMesh + a capsule collider … What it LEAVES is cheap and
> permanent — and what it leaves is COVER. Drop a tree across open ground and there is now a log to
> crawl behind that was not there before. That is the whole reason to build any of this.`

`felled_trunk.glb` and `tree_stump.glb` **both exist on disk**. Ruling 1 is not a new feature. **It
is finishing a pipeline whose assets, collider radii and design intent all shipped, and whose Godot
side stopped at the visual.** That is a large de-risk and it should be said to him in those words.

### 0.3 Ruling 2's premise is wrong, and the real answer is not a bigger number

`MAX_DEFORMS_PER_MISSION = 40`'s own comment says it *"bounds chunk-rebuild spikes under sustained
ordnance."* **It does not.** `TERRAIN_DEFORMS_PER_FRAME = 1` already bounds the spike completely — a
thousand blasts still cost one rebuild per frame. The 40 is a **cumulative total-work ceiling**, and
it bounds **no memory at all** (the heightmap is a fixed array written in place).

What one crater actually costs, traced (`terrain_manager.gd:284-319` → `:70-85` → `:200-229`):
a **whole 256 m × 256 m chunk rebuild** — 4,225 vertices, 8,192 triangles, ~24,576 `SurfaceTool`
calls **in GDScript**, then `create_trimesh_shape()` for collision, then a **full vegetation
re-scatter of that chunk**. Synchronous, main thread.

**So an 8–12 round artillery barrage schedules 8–12 consecutive frames each carrying a full chunk
rebuild.** That is very likely the direct cause of his 2026-08-05 conviction *"its def laggy with
everything going on."*

**His ruling "whatever doesnt break the game" therefore does not resolve to a number. It resolves to
a measurement, and possibly to fixing the dig instead of the cap.** Probe named in Phase 0.

### 0.4 Ruling 4 rests on a system that does not exist

*"thats the hearts and minds invisible factions sytem at work."*

**It is decreed and not built.** `ProvinceState`, `allegiance`, `sympathy`, per-village standing, VC
support level — **zero hits repo-wide in any `.gd`**. ADR-017 and ADR-019 are pure decree.

What *does* exist and can carry his ruling:
- **`EvidenceLedger`** (`field_director.gd:119`) — hunters already walk to a dated fix of *a thing the
  player left behind* (`:132-141`, `:156-168`). A burned village is exactly that shape: a position, a
  timestamp, a weight. **In-patrol retaliation, zero new machinery.**
- **`CampaignState.threat_level` + `add_threat_modifier()`** (`campaign_state.gd:22, 222`) — a
  persistent, save-loaded, decaying float that `SiegeDirector` already reads for night-assault
  probability (`siege_director.gd:12, :191`). **The only path that survives a save.**

Also found, both live defects: `_bank_patrol` (`field_director.gd:1768-1791`) **never copies
`civilian_deaths`** into the result, so the count is silently discarded on every *successful* patrol —
it only ever surfaces if the player dies. And `player.gd:249` calls `on_atrocity_witnessed`, which
`Civilian` **does not implement** — a permanent no-op behind a `has_method` guard.

### 0.5 Ruling 5 collides with a standing law — and his own wording resolves it

The 2026-08-04 standing law: **"No PROCEDURAL GEOMETRY GENERATION… no `make_*.py` generator scripts."**
The trees were built by exactly such a generator (`tools/make_jungle_flora.py`).

His ruling 5 wording — *"just take an existing tree and fragment more parts of it"* — **is the
resolution.** Segmentation must be **mesh surgery on the existing GLB** (import, cut, separate,
export), never a re-run of the generator with new parameters. Under that reading the two are
compatible and no decree is needed. **Stated so nobody later "fixes" it by editing the generator.**

---

## PHASE 0 — MEASURE (nothing is built until these three numbers exist)

Binding: no FPS delta is accepted unless the draw-call/primitive delta has the right sign and
plausible magnitude (PERF_LEDGER, 2026-07-26). Detectability floor **~3 FPS / ~2.4 ms**.

| # | Probe | Cost | What it decides |
|---|---|---|---|
| **P0-A** | **THE WALK.** Boot the demo, walk out the wire into the jungle. `[PERF] FPS=` already prints every 2 s (`game_world.gd:481`). **Zero code.** | ~4 min | The baseline this project has **never taken**. Every FPS row on file is a stationary camera in a cleared firebase (`PERF_LEDGER.md:972-975`). Rule #1 is about walking. |
| **P0-B** | **ONE DIG.** Time `_rebuild_chunk_immediate` (`terrain_manager.gd:70-85`) around a single crater. | ~10 min | **Answers ruling 2.** If one dig is ~20 ms the cap can go to hundreds. If it is ~150 ms, the answer is not a bigger cap — it is a cheaper dig, and we have found his lag. |
| **P0-C** | **THE BARRAGE.** Stand in a village, call artillery, catch the worst single frame. Ship config, Intel-UHD floor. | ~5 min | **This is the ADR-031 gate, open since 2026-07-25.** Formally discharges it. |

**Everything in Phase 1+ is exempt from the ADR-031 gate except Phase 4 (structure destruction),
which P0-C releases.**

---

## PHASE 1 — THE LANDMINES (cheap, and they protect every judgement he makes afterwards)

| # | Item | Lift or build | Unblocks |
|---|---|---|---|
| **1.1** | **Crater ceiling.** Set from P0-B. Correct the wrong comment at `damage_system.gd:79-81` in the same change (NO-DRIFT). If P0-B is bad, the real fix is to make `_rebuild_chunk_immediate` rebuild only the affected sub-region, or to move `build_mesh` off `SurfaceTool`. | Lift if the number is fine; **design build** if the dig is the problem | His trust in his own tuning for the rest of the demo |
| **1.2** | **Scar-decal budget.** One real `Decal` node per blast, parented to the **DamageSystem autoload**, **never freed during play** (`damage_system.gd:263-287`, freed only by `clear_all_damage`, whose only caller is world teardown). Each destroyed structure adds another (`destructible.gd:97`). Needs a distance-keyed cap or a shared decal atlas. | Design build (small) | **Phase 4** — otherwise levelling a village spawns a decal per hut, forever |
| **1.3** | **`_in_veg_hole` is a linear scan over every hole ever recorded** (`vegetation_manager.gd:387-392`), run **per candidate plant on every chunk re-scatter** (`:548`). Every crater makes every future rebuild slower. Bucket it spatially. | Design build (small) | **Ruling 6.** This — not memory — is the honest "would it lag" answer for persistent damage |
| **1.4** | **Stop the arena writing on the game.** `EnemySquad.tiering_enabled = false` (`ai_stress_arena.gd:304`, static, never restored — **ADR-026 Part B tiering off for the rest of the process**) · `GibSystem.gib_lifetime_s` 12→25 (`:305`) · `GameSettings.ai_vs_ai_cone_mult` (`:308`, zero effect at defaults, hygiene). | Straight lift | Trustworthy measurement in every later phase |
| **1.5** | **Delete the arena hook in shipped bullet code** — `bullet_system.gd:172-176` duck-types `get_player_damage_mult()`; only provider is `ai_stress_arena.gd:2031-2032` (ADR-023). | Straight lift | — |
| **1.6** | **Drift pass** — `site_planner.gd:1479-1484` (pre-fix problem statement above its own fix) · `:1491-1492`/`:1536-1537` (SiegeDirector does not read a breach) · `ai_stress_arena.gd:1954-1955` · `damage_system.gd:79-81` · dead `site_planner.gd:140 _is_soft_cover()` · `DEMO_SHIP_BACKLOG` "group-based" line (already corrected). | Straight lift | — |

---

## PHASE 2 — THE FELL REGISTRY (rulings 1 and 6, one change)

**What he gets, in his words:** blow a tree down and there is a log lying there you can get behind,
it stays there for the rest of the patrol, and it costs nothing when nobody is near it.

| # | Item | Detail | Class |
|---|---|---|---|
| **2.1** | **The fell registry.** A manager-level, chunk-independent array — the sibling of `_veg_holes` (`vegetation_manager.gd:384`) — holding `{species, final Transform3D, chunk_coord}`, appended in `_fell_tree_visual` (`:459`) once the tween's hinge basis is **baked to its final value**, and consulted by `_build_scatter` (`:507-551`) so every rebuild re-emits the log as a normal scatter instance. | The log becomes a `COVER_TRUNK` candidate → lands in `_chunk_trunks` → **bodied and parked automatically by the existing pooled ring**. Three wins in one change: on-call collider, survives chunk rebuild, and the resident-node leak disappears. | **Design build**, small — this is the "small rewrite of the candidate model" the council named, now with a named shape |
| **2.2** | **The lying-log collider shape.** `COVER_TRUNK` bodies are **upright cylinders** of `TRUNK_HEIGHT = 3.0`, offset by half-height with no rotation (`tree_cover_layer.gd:32, :360-364`). A horizontal log needs a rotated capsule or a low box, or the collider stands up where the visual lies down. | **Honest option A (cheap):** accept an upright post at the log's midpoint — the convention already used for pre-placed `fallen_log_a/b`. You cannot crawl along it. **Option B (right):** a second shape family + per-candidate orientation. The bench already does B (`fellable_tree.gd:129-140`). | **Design build.** Recommend B; A is the fallback if P0 says no |
| **2.3** | **Kill `FALLEN_MAX = 24` FIFO** (`vegetation_manager.gd:482-485`). Once a log is cover, a FIFO frees the log a man is lying behind because of a blast 200 m away — a direct violation of ADR-031 §4 ("permanence is sacred inside the firefight radius"). Registry entries are cheap data; cap by distance from the player, not by insertion order. | | Straight lift once 2.1 lands |
| **2.4** | **Raise `FELL_MAX_PER_BLAST = 5`** (`:446`). A napalm strike clears **60 m** of vegetation and animates **five** trees falling; the rest vanish silently. That popping is the tell he will notice. Cost is now per-*visual*, not per-collider, so this is a tween budget. | | Lift; number is his |
| **2.5** | **Ballistic tag on the log** — `fellable_tree.gd:129` has no material group, so rounds hitting the one object built as prone cover fall through to a filename heuristic. | | Straight lift |

**Dependency:** 2.1 blocks 2.2, 2.3, 2.4. **1.3 should land first** or the registry makes the veg-hole
scan worse.

---

## PHASE 3 — ON-CALL PROMOTION FOR BULLETS (his correction)

`combat_manager.gd:378` gates promotion on `data.aoe_radius > 0.0`. Only explosives promote.

**What the gap actually is, precisely — and it is narrower than "bullets don't promote":**
the player carries a permanent 70 m collision bubble, so **every tree near him is already solid, in
both directions.** ADR-033 *explicitly accepted* "beyond 70 m, bullets do not strike trunk colliders"
as a ratified consequence. So the only real defect is **asymmetric**: an enemy firing from beyond
70 m has no solid cover of his own, so the player's return fire passes through the tree the enemy is
standing behind. **Enemy cover does not work at range; the player's always does.** That is a Pillar-1
and FEAR-doctrine problem, and it is worth fixing.

**CORRECTION TO THE BRIEFING — the dedupe does NOT save us for corridors.**
`_add_zone` dedupes only when **both** endpoints are within `ZONE_DEDUPE_M = 4.0` (`:100-105`). For a
bullet corridor the far endpoint sits up to 250 m out, where 4 m is **0.92° of aim variance** — less
than weapon spread and aim jitter. So sustained fire down "one lane" would miss the dedupe on most
rounds and pay a full `_update_ring()` each time. **"Pays only on the first round" is true for a
fixed lane and false in practice.** Correcting this plainly, as asked.

**Therefore: do not stamp a corridor per bullet.** Anchor the promotion to the **shooter**, where the
dedupe actually works because the position is stable:

| # | Item | Starting numbers (STARTING POINTS ONLY — feel is his, ADR-015) |
|---|---|---|
| **3.1** | When an AI fires **at the player**, call the existing `TreeCoverLayer.threat_zone()` on the **shooter's own position**. Stable position → the 4 m dedupe hits nearly every time → sustained fire genuinely does pay only once. Uses the shipped API unchanged. | radius **8 m**, duration **2.0 s** |
| **3.2** | Optional, only if 3.1 proves insufficient: a short corridor for the **player's** outgoing fire beyond the ring. | half-width **1.0 m**, duration **1.0 s**, reach capped at 150 m |

**A genuine positive found:** `ZONE_MAX = 16` evicts the **soonest-to-expire**, not the oldest
(`:106-113`). Short-lived bullet zones therefore evict each other and **can never displace a
long-lived shell corridor**. The existing policy already protects the barrage from bullet churn — by
accident, but correctly.

**Gaze-based promotion stays REJECTED, and this does not approach it.** Promotion here is keyed to
*a weapon being fired* and *a projectile in flight*, never to what is on screen. An off-screen blast
still promotes its corridor and still breaks the world. **Clear.**

---

## PHASE 4 — THE DESTRUCTIBLE WORLD (rulings 3 and the original M-2)

Gated on **P0-C**. Depends on **1.2** (decal budget).

| # | Item | Class |
|---|---|---|
| **4.1** | **One HP table.** Three exist and have already drifted: `fire_support_bench.gd:48-55` (wall 140 / stack 90 / bunker 260 / tower 180 / wire 60) · `site_planner.gd:1552-1558` · `support_fire_range.gd:988` (fort **110**). A fourth for huts institutionalises it. **Blocks 4.2.** | Straight lift |
| **4.2** | **Call `_wire_structure_destructibles` / `_adopt_structure` (`site_planner.gd:1561-1615`) from `place_structure` (`:162`).** Matches by mesh-name prefix, needs **no Blender re-export**, adopts the collider that already exists, adds no mesh, shares one rubble draw call, throttled at 2 levellings/frame, and rebakes nav so the hole is walkable. Lands in demo **and** patrol at once. | **Straight lift** |
| **4.3** | **Ruling 3 — temples crumble.** Once 4.2 lands this is **additional prefix rows in the HP table**. Statuary too. Cost: a stone temple that levels like a hut reads wrong; give it high HP so only heavy ordnance moves it. | Straight lift + one number |
| **4.4** | **Ballistic tags** on `tunnel_room.gd:29` and the resupply crate (`field_director.gd:1027`). | Straight lift |

**Named sacrifice, unchanged from the decree:** this buys **atmosphere and consistency, not a verb**
(ADR-031 said so first). Phase 5 is what stops it being pure spectacle.

---

## PHASE 5 — CONSEQUENCE (ruling 4, SCOPED DOWN on his depth-over-breadth order)

**Do not build ADR-019.** The full province ledger — per-village allegiance, district manpower pools,
base rebuild and relocation — is a system, not a demo item, and none of it exists. **Build the two
hooks that make his sentence true**, and say plainly that the invisible-factions system itself is
still decree.

| # | Item | Class |
|---|---|---|
| **5.1** | `Destructible` must **retain the attacker** (`take_damage` discards `_attacker` at `:35`) and **know it belongs to a village**. The data is already there: `Civilian.village_center` (`civilian.gd:98`) is written at build time, so `site_planner` can stamp the same field on each hut's Destructible. | Design build (small) |
| **5.2** | **In-patrol retaliation:** on civilian structures destroyed, push a weighted fix into **`EvidenceLedger`** and arm `_escalation_active` (`field_director.gd:132-187`). Hunters then come **to the place he did it, on a delay** — the shape his sentence describes, using shipped machinery. Invisible: no counter, no toast, no score. | Design build (small) |
| **5.3** | **Persistent consequence:** `CampaignState.add_threat_modifier(+delta, N, "…")` (`campaign_state.gd:222`) — already consumed by `SiegeDirector` for night-assault probability and already round-trips through save. Burn a village, the nights get worse for N patrols. | Straight lift |
| **5.4** | **Bug:** `_bank_patrol` (`field_director.gd:1768-1791`) never copies `civilian_deaths`, so a successful patrol silently discards it. | Straight lift |
| **5.5** | **Unfinished, triage:** `player.gd:249` calls `on_atrocity_witnessed`, which `Civilian` does not implement — a permanent no-op behind a `has_method` guard. Wire it into 5.2 or cut it (ADR-023). | Lift or cut |

**Invisibility is preserved:** nothing above surfaces a number to the player. `threat_label()` is
already shown in the barracks and menu (`barracks.gd:45`, `main_menu.gd:92`) — that is the existing
siege tier, not allegiance, and it does not become a hearts-and-minds readout.

---

## PHASE 6 — DEFENSIVE ZONES NOW (ruling 7)

**A fossil-law problem must be solved before anything is added.** `AllyBase` already has **two**
hold-your-ground mechanisms:
- `post_anchor` / `post_leash = 8.0` (`ally_base.gd:161-164`, branch at `:1237`) — the garrison path,
  already set by `GarrisonDefender.promote` (`garrison_defender.gd:63-65`).
- `defense_zone` / `defense_zone_radius` (`:138-139`, branches at `:857, :1181-1182, :1204-1209,
  :1286`) — the arena path, 16 m.

Two authorities for one behaviour is exactly ADR-023's shape. **Adding a third caller before merging
them is how this becomes permanent.**

| # | Item | Class |
|---|---|---|
| **6.1** | **Merge `post_anchor`/`post_leash` into `defense_zone`/`defense_zone_radius`**, delete the loser, keep the richer goal-gate semantics (no ADVANCE/FLANK, footwork stops at 0.8× the rim, zone-pull, RETREAT/SEEK_COVER stay legal). **Blocks everything else in this phase.** | Design build (small), fossil-law mandatory |
| **6.2** | **Garrison holds sectors.** `GarrisonDefender.promote` already produces an `AllyBase` with a post — after 6.1 it sets a zone. The firebase's stations are the anchors. **The Civilian-class dependency does NOT block this**: promotion already converts garrison Civilians into AllyBase soldiers at stand-to. | Straight lift after 6.1 |
| **6.3** | **The gate switch (his amendment):** crossing the wire gate flips DEFEND ⇄ PATROL in both directions, at the same seam where the patrol banks (`_bank_patrol`). One doorway, one law, player and ambient squads alike. | Design build |
| **6.4** | **Enemy side.** `EnemyBase` has **no hold-ground mechanism at all** — camp guards "hold" only via a tight `make_patrol_route` (radius 16, `:2095`). Mirroring the doctrine onto `EnemyBase` is a **genuine design build**, not a lift. | Design build — **SCOPE CALL, see below** |

**DEPTH-OVER-BREADTH RECOMMENDATION: ship 6.1–6.3 for the demo, defer 6.4.** The demo's fight is the
night assault on the firebase — that is the **US** side holding ground, which 6.2 delivers. VC camp
defenders holding zones is main-game work and the player will not see it in 30 minutes.

---

## PHASE 7 — SEGMENTED TREES (ruling 5 — PLAN ONLY, as he ruled)

**Can it run headless? YES, and this is the honest assessment.**

The pipeline is already `blender -b` (`tools/make_felled_tree.py`, `make_jungle_flora.py`), the joint
contract already has a home (`TRUNK_RADIUS = 0.32`, `TREE_REF_HEIGHT = 10.0`, `BOLE_FRACTION = 0.72`
— bare bole to 72 % of height, canopy above), and `felled_tree.glb` is authored at exactly
`TREE_REF_HEIGHT`.

**The method, obeying the no-procedural-geometry law:** import the **existing** GLB, bisect the trunk
at two heights, assign each leaf/branch cluster whole to the segment its base sits in (never cut a
leaf card in half), separate into three objects, export three GLBs. **Mesh surgery on known-good
geometry — not a generator re-run.** His "high mid and low level separations" maps onto the existing
ruling's lower trunk / upper trunk / canopy with one shared joint-height contract.

**State-swap stays the law (ADR-031): segments above the break hinge and become cover; segments below
stay standing as a snag with a shortened collider. Never fracture, never RigidBody.**

**What specifically needs his eye — say this to him, do not guess it:**
1. **The two cut heights.** `BOLE_FRACTION 0.72` gives one natural joint; the second is a judgement
   call about where a tree "should" snap.
2. **Whether the snag reads.** A bare shortened trunk with a torn top is the whole point of the
   ruling — if it looks like a telegraph pole the ruling has not been served.
3. **Whether the fallen canopy segment reads as canopy** rather than a green blob, at PSX budget.
4. **Scope:** the world's trees are the **TreeCoverLayer species meshes** (~14 cover-giving species),
   not `felled_tree.glb`. **Segment ONE archetype — broadleaf — prove it, then decide.** Doing all
   fourteen before he has seen one is the breadth mistake his demo brief forbids.

**Blocked on Phase 2.** Segmenting a decoration segments nothing. Do not dispatch the art job until a
fallen log is cover.

---

## THE DEPENDENCY GRAPH, COMPRESSED

```
P0-A/B/C  ─────────────────────────────────────────────► everything
   │
   ├─ P0-B ──► 1.1 (crater ceiling)
   └─ P0-C ──► PHASE 4 (releases the ADR-031 gate)

1.3 (veg-hole scan) ──► 2.1 (fell registry) ──► 2.2, 2.3, 2.4 ──► PHASE 7
1.2 (decal budget)  ──► PHASE 4
4.1 (one HP table)  ──► 4.2 ──► 4.3 (temples) ──► 5.1 ──► 5.2, 5.3
6.1 (merge the two hold-ground systems) ──► 6.2 ──► 6.3   [6.4 deferred]
PHASE 3 is independent — it can land any time after 1.4.
```

## SCOPED DOWN ON HIS DEPTH-OVER-BREADTH ORDER

1. **Ruling 4 → two hooks, not ADR-019.** The invisible-factions system does not exist; building it
   is a main-game epic. The hooks make his sentence true in the demo.
2. **Ruling 7 → US side only (6.1–6.3).** Enemy zones are main-game work the demo will not show.
3. **Ruling 5 → one archetype.** Prove broadleaf before touching fourteen species.

## WHAT IS SACRIFICED

- **Phase 2 makes fallen logs permanent for the patrol**, so the AO monotonically accumulates cover.
  Over a long campaign that is an **atmosphere** problem before it is a perf one — a jungle that only
  ever gets more logs stops reading as jungle. A distance-keyed recycler bounds it; ADR-031 promised
  one and **it does not exist in code.**
- **Phase 4** buys atmosphere and consistency, not a verb, and adds an unbounded permanence tax.
- **Phase 5** makes destruction consequential but leaves the real hearts-and-minds system decreed and
  unbuilt — the gap will still be there, just less visible.
- **Phase 6.1** touches shipped garrison behaviour to delete a fossil, which risks a regression in a
  system that works today, three weeks before a demo.
- **Phase 3** makes enemy cover work, which makes the player's own fights *harder* — correct under
  the FEAR doctrine, but it is a difficulty change arriving with a perf change, and the two must not
  be measured in the same run.

## CHARTER DRIFT FOUND (NO-DRIFT law)

`OVERSEER_CHARTER.md §8`, `§10.3` and the resolution at `§10` mandate the Overseer drive `bd` directly
(`bd init` / `bd prime` at session start). **`CLAUDE.md:401-408` retired `bd` on 2026-07-22 and
forbids running it.** The repo law wins; the charter is stale and must be corrected on contact.
