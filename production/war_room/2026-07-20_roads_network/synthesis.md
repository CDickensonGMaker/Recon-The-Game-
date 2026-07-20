# THE DECREE — THE ROADS NETWORK

**2026-07-20 · Arbiter: Overseer · Council: technical-director, game-designer,
systems-designer, ux-designer, devil's-advocate · Branch: audit-fixes**

## THE RULING

Roads are built. But **not as the Summoner framed them, and the council was unanimous
about why.** Two of his framings were overturned on evidence:

1. **`ROAD_NEAR_M` must NOT become an enforced requirement.** Enforcing it as the
   header documents would have made the game strictly worse. See "What we refused".
2. **"Build the roads network" is not the feature.** *"There is traffic in this AO"*
   is. A road with nothing on it is scenery. The wave is not done until a truck
   drives down it — so a truck drives down it.

### What was built

**`RoadNetwork` (`scripts/world/road_network.gd`) — ONE authority, derived not
authored.** The governing rule, and the answer to the fifteen-parallel-world-builds
failure: **a road is DERIVED FROM THE WORLD, NEVER AN INPUT TO IT.** RoadNetwork reads
the finished GameplayGrid and routes A* over its existing cost field. It cannot
disagree with the world because it has no opinions of its own — exactly the shape
`paddy_stamper.gd` already uses (a reader, not a writer).

- A* over the grid cost field, slope-penalised, contour-following.
- Hub-and-spoke: the wire gate to each village. **VC camps are deliberately
  unconnected** — a paved road to a Viet Cong base camp is absurd.
- Braiding via a cost discount on existing road cells, so junctions **emerge**. There
  is no junction code.
- **Fords, never bridges.** A bridge is a chokepoint with no alternative crossing,
  which is a rail (Pillar 3). Water costs a large-but-finite 24.0 so a road crosses
  at the narrowest point rather than detouring a kilometre.

### The seam

`scripts/missions/mission_generator.gd:538` (plan pass) routes the network — pure
derived positions, no side effects, which is why the ambush planner four lines later
can already see it. `mission_generator.gd:669` (build pass) hands it to the world and
thins the corridor. Those are the only two places roads enter the world build.

## WHAT WE REFUSED, AND WHY

### 1. `TerrainType.ROAD` — rejected on a 30-site blast radius

The technical director enumerated it: 4 silent bugs, 2 behaviour bugs, 1 build-breaker,
and **two hard blockers that are not negotiable**:

- **Ordering.** `TerrainZoning.configure()` runs at world-build step 2. The sites a
  road connects do not exist until step 7. The mask would be empty at classify time.
- **`tests/test_one_classifier.gd` fails on contact.** A road member in GameplayGrid's
  enum alone diverges from VegetationManager's parallel 6-member enum — which is bead
  `6od4`, the exact defect that was just closed.

Two silent bugs deserve naming because they would have shipped invisibly:
`patrol_generator.gd:73` uses `MOVEMENT_COSTS.get(tt, 99.0)`, so an unregistered ROAD
would have been **impassable to every VC patrol**; and `_apply_riparian_belt` would
have repainted any road within 22m of water back to jungle, precisely at the river
crossings. **`test_one_classifier` passes on the shipped build** — verified.

### 2. Terrain grading — refused

Roads are **seated, never graded**. A graded roadbed crossing a carved channel can dam
it, and `_carve_riverbed` cuts only 1.8m. The devil's advocate then found something
worse, which is recorded below.

### 3. `TRAFFIC_NEAR_M` as a hard gate — refused, and this is the load-bearing ruling

The systems designer proved the trap is **structural, not probabilistic**: camps sit
400-540m from the gate, the road's own termini (villages) sit at 240-470m. **The camp
band lies outside the road band by construction.** A hard "road within 80m" gate would
return an empty plan for roughly one camp in three, every seed — and **the loss is
invisible**, because a rejected ambush silently returns its men to the camp garrison
and no headcount changes. The AO would just quietly get duller.

So it is a **multiplicative score term** (`× 0.55 → 1.0`) that cannot zero a site.
Roads can only *move* an ambush onto better ground, never delete one. The constant is
renamed **`TRAFFIC_NEAR_M`** — because roads vs. patrol circuits was a false choice,
and both designers reached that independently. What the planner wants is *distance to
a line that things move along*.

## WHAT IT COSTS — named, per the second law

- **The road is not yet a surface.** It reads as a **canopy gap** (the UX designer's
  top-ranked legibility cue, and free) but has no distinct ground material, ruts, or
  telegraph poles. Walk onto it and it is thinner jungle, not laterite.
- **Frame time is UNMEASURED and I will not invent a number.** Headless reports GPU-ms
  as 0, and windowed runs were forbidden this session. The honest *bound*: roads add
  **zero draw calls** — no meshes, no new shader uniform — and `clear_corridor` lowers
  vegetation instance counts along ~1.5km of corridor. Direction of the change is
  negative; magnitude is unknown until a desktop bench.
- **A* runs 4× at load** (once per village) over 65k cells, behind the loading screen.
  Not measured against a budget.
- **No mines, no civilians, no ox carts.** Cut deliberately: shipping roads and mines
  together means a playtest cannot tell which one is wrong.
- **Roads do not reach VC camps** — by design, but it means the ambush traffic term is
  a nudge, not a strong pull, on camp-sited ambushes.

## FINDINGS THAT OUTLIVE THIS WAVE

**`test_height_authority`'s channel check D2 is VACUOUS and passes 10/10 anyway.**
`test_height_authority.gd:262` guards on `surf > 0.0`, but `hydrology_map.gd:340`
only writes `_surface_h` for LAKE/SWAMP/COASTAL, and `min_lake_depth = INF` means LAKE
never fires. **River channels keep surface 0.0, so the loop body never executes** — the
reported "worst bed-vs-surface gap: 0.00 m over 2467 points" is the signature of a
check that measured nothing. Check D1 separately reads a **stale water mask**:
`modify_terrain` never invalidates it, so a filled channel still reports 100% wet.

**This is already live, independent of roads.** The 215m firebase flatten
(`site_planner.gd:635`) runs after rivers carve and after the water map bakes. Any
river within 215m of the firebase is being filled today, unseen. Seed 42 happens to be
clean. **Roads did not cause this and do not worsen it** (they perform no height
edits), but the probe that is supposed to guard it cannot see it.

**`Convoy.report_contact` had zero callers**, so `ambushed` could never fire even with
vehicles — meaning fixing the empty-array bug alone would not have unblocked
`DynamicMissionFactory`. It now has a real caller (ambush proximity on
`waypoint_reached`), closing the chain end to end.

## THE PILLAR QUESTION, ANSWERED

**Is a road a rail?** No — but *the road we were tempted to build was one*, and the
game designer found the proof in code: `player.gd:841` divides player speed by terrain
cost for `RICE_PADDY` **and nothing else**. Heavy jungle costs the player zero speed
today. So a road that granted speed would be a **strictly dominant traversal surface** —
the war inverted, grunts on the road because it is fast, when the whole truth of
Vietnam is that the road is where you get killed.

**The road therefore pays in ORIENTATION, never velocity.** It is easy to follow, not
fast to walk. Getting lost is already a live cost here (topo sheet, no minimap). Roads
carry `COVER_VALUES` of nothing and cross open ground — dangerous ground with a human
temptation, which is correct.

**Binding rules, carried forward:**
1. **No-Speed** — a road must never be faster to walk than the bush. Cut forever, not
   deferred. Adding jungle slowdown to "balance" a road is a Pillar 1 combat decree
   smuggled in as a roads feature.
2. **Adjacency** — walkable parallel ground always exists; a road is never the only way.
3. **Derived** — roads are computed after site placement. A site never moves to fit a road.
4. **No gate** — traffic proximity is a preference, never a requirement.
5. If playtest shows players defaulting to the road, the fix is **more threat on it**,
   never a movement penalty.

## THE MAP (r4bk)

Roads print on the **base sheet** from mission start, whole, and never decay. This does
**not** violate ADR-022, and the question dissolved on contact with the code:
`topo_map.gd:33-75` already prints every river the player has never seen, with zero fog
and zero reveal. Roads are surveyed cartography — the paper, not a mark on it. ADR-022's
two-layer law governs **marks**.

Drawn in contour ink at contour weight so a road reads as **furniture, never a
destination**; saturated colour stays reserved for the player's grease pencil, and
nothing is ever marked *on* a road.

Deliberately cut: **footpaths and VC trails must NOT print** — those are earned by
walking and belong to the OBSERVED layer. The sheet under-reports the world and never
over-reports it.

## VERIFICATION

`tests/test_roads.tscn` — **17/17 PASS**. Every assertion carries a negative control
that was **run against deliberately broken code and observed to fail**:

| Mutation | Observed failure |
|---|---|
| CLIFF cost `-1.0` → `1.0` | `NEGATIVE CONTROL LEAKED: all-cliff terrain produced 2 road segment(s)` |
| `_seat()` returns raw point | `153 of 153 road point(s) off the terrain surface, worst 232.36m` |
| traffic term → hard reject | `VACUOUS COMPARISON: the roadless control yielded 0/120` + `no ambush sites planned in the real world` |
| `resume()` stops clearing latch | `resume() did not re-arm the ambush latch (1 reports, expected 2)` |

**The third mutation exposed a defect in my own probe.** The never-worse guard compared
with-roads against without-roads, but a hard gate breaks *both* arms (a null network
reports INF, which also fails the gate), so it printed `ok: roads did not reduce ambush
yield (0 -> 0)` against thoroughly broken code. A live-baseline assertion was added.
**This is the same vacuous-check disease found in `test_height_authority` D2** — a
comparison whose control arm is also broken proves nothing.

Guards green: `test_smoke_all` 10/10 · `test_height_authority` **10/10, 100% wet
channel preserved** · `test_terrain_desync` · `test_flat_damage` · `test_air_fleet` ·
`test_firebase_garrison` · `test_bench_rack` · `test_schedule_reset` ·
`test_dynamic_events` · `test_group_walk` · `test_squad_break` · `test_ambush_sites`
(controls clean) · `test_one_classifier`.

Fossils **34 → 30**. Buried: `ROAD_NEAR_M`, `Convoy.resume`, `route_finished`,
`waypoint_reached`. The 4 remaining belong to other agents' live files
(`world_sim.gd` ×3, `weapon_data.get_bore_dir`) and were not touched.
`fossil_baseline.json` NOT edited.
