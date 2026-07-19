# DEVIL'S ADVOCATE — patrol-world vegetation: floating cards + missing 3D jungle
Session 2026-07-18_veg_seat. I read the code, not the plan, and I ran the numbers myself.

## Verdict summary
Root cause A **stands, now MEASURED** (I ran the diag; briefing's ~7m was rounded up from 6.07m).
Root cause B **stands as a fact, but FIX B answers the wrong complaint** — it fixes "invisible",
not "2D cards". Two claims in the briefing are wrong in detail but benign; one attribution gap
and three next-desyncs are unexamined.

---

## 1. Do the root causes explain the Summoner's report?

### A: clutter floats — CONFIRMED, and I measured the magnitude
Order of operations, verified in code:
1. `game_world.gd:139-181` `_on_terrain_ready`: water (:151), gameplay_grid (:160),
   **GroundClutter built at :176-178** — samples `get_height_at` per plant
   (`ground_clutter.gd:134,137`) and bakes it into MultiMesh transforms. This runs before
   `world_ready`/`is_world_ready`.
2. `game_flow.gd:262-273` `enter_hub` waits on `is_world_ready`, THEN
   `build_patrol_world` (:273) → `place_firebase_main` → **the R=215 flatten**
   (`site_planner.gd:553` via `modify_terrain`), plus the FSB clear discs and village
   foundations, which ALSO move ground (`clear_and_flatten` → ClearingSystem CLEARED stage,
   `height_flattening: 0.7`, `clearing_system.gd:42,169-173` → `modify_terrain`), plus sign
   craters (`damage_system.gd:127`).
3. Nothing re-seats clutter: `terrain_manager.gd:11-12` emits only
   `terrain_ready`/`chunk_unloaded`. Confirmed — no other signal, no clutter listener.

**The magnitude claim, measured.** I ran `tools/diag_preflatten_delta.tscn` headless
(Godot 4.7, seed 47225):

```
[PREFLAT] fsb center 943,687  seat(mean)=199.69
[PREFLAT] pre-flatten relief inside full-seat r171: 189.01..205.76 (spread 16.76)
[PREFLAT] cells that will DROP >2m to the seat (clutter floats there): 142 of 641 (22%)
[PREFLAT] max clutter float possible: 6.07 m
```

Eye level on the seat is 199.69 + 1.7 = 201.39. Quad bases sit at old ground height
(`ground_clutter.gd:137`, base = old_h − y_sink). Old ground reaches 205.76 → quad bases up
to **4.4m above the player's eye**, and 22% of the full-seat disc floats >2m. The plateau is
where the player spends the whole hub loop; NEAR_END 42m guarantees these are drawn in his
face. **"2D cards floating above eye level" is arithmetically satisfied.** The briefing's
"~7m" should be corrected to the measured 6.07m (this seed) — direction and severity stand.
Where old ground was BELOW seat (189m), clutter is instead **buried** — invisible, no report.

**One wrong-but-benign comment in the code**: `ground_clutter.gd:10-11,119,139` claims
"visibility_range culls a whole bucket by its CENTRE / measures from the bucket origin" and
sets `mmi.position` with **y=0** while instances carry world heights (~200m) in their local
transforms. Godot measures visibility range to the **transformed-AABB center**, not the node
origin (docs say "origin" and are wrong — godot issue #79471, proposal #13779). If it were
node-origin, every bucket on the 200m plateau would be >200m from the camera and clutter
would render NOWHERE — the Summoner's sighting itself falsifies that. AABB-center semantics
make the current culling work by accident. FIX A's bucket refactor should seat bucket node
origins at terrain height anyway so the code stops depending on an undocumented behavior.

### The re-seat claim for TreeCover — VERIFIED true in code
`_rebuild_chunk_immediate` (`terrain_manager.gd:89-104`) → `_load_chunk:250` →
`vegetation_manager.generate_for_chunk:232` → `_rematerialize:430-433` (TREE_COVER branch) →
`_build_scatter:485` samples `heightmap.sample_world` **at rebuild time** →
`tree_cover_layer.generate_for_chunk:68`. Every height-mutating path in the build goes
through `modify_terrain` (FSB flatten :553, CLEARED discs/villages `clearing_system.gd:173`,
craters `damage_system.gd:127`), so TreeCover solids AND far cards re-seat everywhere.
The `clear_chunk` race (`tree_cover_layer.gd:102-108`): `queue_free` is deferred while new
nodes are added immediately → **at most one frame of double-draw, entirely behind the
loading screen; bookkeeping is correct (dict entry erased then rewritten), no orphans.**
Verified: nodes are all tracked in `_chunk_nodes[coord]`. Not the symptom.

### Veg boosts do NOT reintroduce stale heights — VERIFIED
`enter_hub` order: `build_patrol_world` at `game_flow.gd:273` (all flattens inside),
`apply_veg_boosts` at :316 → `set_density_centers` (`vegetation_manager.gd:508-529`) →
`generate_for_chunk` on affected chunks → `_build_scatter:485` samples the by-then-mutated
heightmap. Boost re-scatter uses CURRENT heights. Clean. (It reuses the cached
`_chunk_terrain` CLASSIFICATION from pre-flatten heights — deliberate, since clear_area
already stamped CLEAR bundles; not a float source.)

### Attribution gap — the unexamined assumption
Nobody has proven the floating things Caleb saw are GroundClutter. Clutter is the only
build-time height sampler that never re-seats among the veg systems, and the measured 6.07m
float fits the report — but the confirmation test is one windowed toggle
(`GroundClutter.visible = false`, look) and it was never run. Ship FIX A with that check in
the blessing run, or we may fix a real bug and leave the reported one standing (see the
crater-under-hut and floating-water candidates in §3, which also produce "hovering things").

## 2. What FIX B sacrifices — and whether 350 is measured

**The fog arithmetic is real, not vibe**: CLEAR weather `fog_density = 0.0065`
(`mission_weather.gd:13`, `game_world.gd:69`); transmittance e^(−0.0065·350) = 0.102 ≈ 10%.
CLEAR is the thinnest fog in the table, so 350m cards are ≥90% fog-tinted in every weather.
The patrol world uses MissionWeather (`game_flow.gd:311-313`); WeatherDirector's
`fog_density = 0.0` branch belongs to the other flow — not a hole here.

**The perf number is a vibe.** Instance math (map 1280m → 25 chunks, 99,770 instances,
0.061/m²): card ring 46→350m ≈ up to ~23k card instances in range vs ~800-1,200 today —
**~28×**. Mitigations already in code: the sun has `shadow_enabled = false`
(`game_world.gd:45`) so there is NO shadow-pass explosion, and distant cards are small on
screen so fill grows far slower than 28×. It is probably survivable — but "probably" is
exactly what ADR-026 exists to forbid. **Cheapest measured experiment**: plumb one CLI lever
(`--card-dist=F`) into TreeCoverLayer, reuse the `ps2_perf_probe.gd` SUMMARY harness
(it already A/Bs windowed GPU-ms, `scripts/levels/ps2_perf_probe.gd:1-14`) at the wire
spawn, and have Caleb run it twice: 80 vs 350. Two SUMMARY lines. One evening. If UHD tanks,
350→200 keeps 27% transmittance — the dial-back is one number, as the briefing says.

**What is actually sacrificed — the look.** Symptom B is "the 3D jungle is not appearing";
FIX B's answer is *28× more 2D cards*. The arena benchmark the Summoner loves runs raw GLB
solids to 65m (`ai_stress_arena.gd:448 GROUND_PLANT_VIEW = 65.0`) plus a merged canopy;
FIX B keeps solids at 46m (`tree_cover_layer.gd:40`) and fills 46–350m with flat cutouts,
hard-snapped (FADE_DISABLED, :141). That risks amplifying the aesthetic half of symptom A
("2D cards") while curing the invisibility half of symptom B. The cheap lever nobody priced:
`near_distance` 46→65 to match the arena's solid ring (~2× solid instances, colliders
unchanged — the trunk cap `MAX_TRUNKS_PER_CHUNK:38` is per-chunk and range-independent).
Rule #1 says Caleb's eyes judge; `tests/veg_lod_lookcheck.gd` (screenshot harness) is the
existing vehicle for the look gate. FIX B must not be blessed headless.

## 3. The NEXT desyncs — build-time height samplers that never re-seat

1. **Water — the loudest one.** `water_system.generate_water_bodies`
   (`terrain/water/water_system.gd:78-115`) runs at `game_world.gd:151-157`, PRE-flatten,
   and bakes **one combined water mesh** (:105) plus the `is_water` lookup grid (:108).
   Nothing rebuilds it — no terrain listener, single call site. Any creek/pond inside the
   R=215 flatten or a village CLEARED disc now floats above or drowns under the moved
   ground, and `is_water`/grid answers lie there forever. The FSB site scoring avoids water
   at the disc centers only (`site_planner.gd:519-523`) — the 171m full-seat ring is not
   checked. Same divergent-systems signature as clutter, fourth instance.
2. **GameplayGrid.** Built pre-flatten (`game_world.gd:160-165`); `update_region` runs only
   for clear discs/villages (`site_planner.gd:116`) and veg updates (`game_world.gd:334`).
   The R=215 plateau flatten and every sign crater update NOTHING
   (`place_firebase_main:553` never touches the grid). Slope/water/passability in the
   120–215m ring around the FSB and at every crater are stale for the whole session — this
   feeds `_passable_near` spawn queries and AI sight. Data desync, not a visual, which makes
   it the most dangerous of the three.
3. **Sign craters under built villages.** Craters fire at `mission_generator.gd:563-565`
   AFTER villages are stamped (:556-562), guarded only by the FSB keep-out
   (`_passable_near:116-123` — `_crater_keepout_grow` guards the wire, nothing guards
   villages). Crater band 170–280m from the gate; village band 240–470m. In the overlap, a
   crater detonates under already-seated huts (`place_structure` seats once,
   `site_planner.gd:182-183`) → floating hut over a crater. Seed-dependent, live today.
   Low-stakes cousins: armorer's bench (`mission_generator.gd:592-594`) and crater-water
   discs (:83-84) are seated correctly at build but never re-seat under RUNTIME craters —
   decoration risk only. NPCs are safe: TerrainWatchdog re-seats bodies
   (`terrain_watchdog.gd:54-58`) and gravity handles floaters.
4. Housekeeping, fossil-law: the terrain shader has no `heightmap` uniform —
   `game_world.gd:312-314` uploads a texture into nothing (grep `terrain.gdshader`: zero
   hits). Dead parameter; delete with the next terrain touch. Also `clear_and_flatten`'s
   name promised flattening for weeks before ClearingSystem stage params made it true —
   the briefing itself half-tripped on names ("clear_and_flatten discs" listed as a flatten
   separate from the stamps; they are the same ClearingSystem path).

## 4. The probe — what independent check survives headless

Placed-origin arrays written by the placer are a self-graded exam: the system can faithfully
record a wrong placement. Independent channels that DO work headless:
1. **Physics raycast** — chunk trimesh collision is built by a different pipeline
   (`terrain_chunk.build_mesh` + `create_raycast_collision`, `terrain_manager.gd:255-257`)
   and physics rays work headless (proven daily by `[SPAWN-TRUTH]`,
   `game_flow.gd:230-244`). Two-step probe: (a) instrument validity — at N random points
   assert `heightmap.sample_world` ≈ physics-ray hit ±ε, and the first hit is a terrain
   chunk; (b) placement honesty — ray down at each sampled placed origin, assert
   |hit.y − placed_y| ≤ 0.5. Terrain truth and placement truth fail separately.
2. **Scene-tree census vs the arrays** — `instance_count` reads are valid headless
   (briefing's own instrument finding); assert per-bucket/per-chunk instance counts equal
   the stored array lengths, so the record at least matches what exists in-tree.
3. **The honest residual**: MultiMesh transform readback is blind headless, so no headless
   probe can see PIXELS. The probe proves data seating; only the windowed look-check (or
   Caleb) proves the look. Write that limitation into the probe header so a green run is
   never miscited as "the jungle looks right".

## Tradeoffs the decree must name (Law 2)
- FIX A must re-run `_accept` against the UPDATED grid at re-scatter time, or re-seated
  grass tufts keep growing through FSB floors inside the clear discs; and runtime veg-clears
  that move no terrain (`clear_area` without a crater) still emit no signal — clutter
  presence desyncs there by design. Say so.
- FIX B sacrifices mid-range 3D-ness for coverage: a card field to the fog line, hard snaps
  kept. It is a visibility fix wearing a jungle-look costume. Price `near_distance` 65
  alongside it, and gate both on Caleb's eyes.
- The probe certifies seating, not beauty. Rule #1 is still settled in a window.
