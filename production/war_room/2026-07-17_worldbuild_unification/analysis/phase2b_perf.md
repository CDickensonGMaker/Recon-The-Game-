# Phase 2b — PERF/PROGRAMMER analysis (TREE_COVER flip for the windowed look)

Read: `tree_cover_layer.gd`, `vegetation_manager.gd`, `game_world.gd`, `game_flow.gd`,
`ground_clutter.gd`, `ai_stress_arena.gd`, `mission_generator.gd` (grep). Code, not the plan.

---

## 1. COLLIDER STRATEGY — cheapest render without the Jolt crash

### What actually blows up
`tree_cover_layer.gd:82-85` creates **one StaticBody3D per COVER instance**:

```gdscript
if COVER_TRUNK.has(nm):
    var r: float = float(COVER_TRUNK[nm])
    for xf: Transform3D in xforms:
        nodes.append(_trunk_body(xf.origin, r))   # <-- 17,087 of these on the 1280m AO
```

Each `_trunk_body` (`:134-145`) is a `StaticBody3D + CollisionShape3D + CylinderShape3D`.
17,087 static bodies > Jolt's 10,240-body ceiling → engine error. That is the ONLY thing
that crashes.

### The render alone is NOT a Jolt problem and NOT even 17k nodes
- `generate_for_chunk` groups instances **by species** into `by_name` (`:64-71`) and emits
  **one MultiMeshInstance3D per species per ring** (`_multimesh`, `:77`/`:80`). Solid + card =
  ~2 MMIs × ~12 species × ~25 chunks ≈ **a few hundred MMI nodes**, not 17k. The 17k is the
  trunk StaticBody count, full stop.
- MultiMeshInstance3D is **RenderingServer only — zero Jolt bodies.** Rendering the near-solid +
  far-card with the trunk loop **skipped entirely** creates **0 physics bodies → cannot hit the
  Jolt limit no matter the instance count.** So the LOOK has zero crash risk the moment colliders
  are gated. Remaining cost of render-only is triangles/overdraw (the project's standing FPS risk),
  not a crash and not Jolt — out of scope for "get eyes on the look without crashing."

### Options
**(a) Global cap ~6000 in tree_cover_layer** — add `var _collider_total := 0` +
`const MAX_COLLIDERS := 6000`; guard the loop at `:84`:
```gdscript
for xf: Transform3D in xforms:
    if _collider_total >= MAX_COLLIDERS: break
    nodes.append(_trunk_body(xf.origin, r)); _collider_total += 1
```
and decrement in `clear_chunk` (`:95-97`) when freeing a `StaticBody3D`.
*Ships the look, zero crash (6000 < 10240).* **Landmine:** which chunks lose their trunks depends
on **chunk generation ORDER**, which is terrain load order (distance-driven), not the seed. Two
boots of the same seed can cap **different chunks** → **cover placement is non-deterministic →
ADR-010 violation.** Also leaves one spatial corner of the map with rendered-but-non-solid trees.

**(b) Per-chunk cap** — same guard, but a per-call counter (reset each `generate_for_chunk`), e.g.
`const MAX_TRUNKS_PER_CHUNK := 300`. Resident AO = 1280/256 = 5×5 = 25 chunks → ≤7,500 bodies,
safe margin under 10,240. **Order-independent → deterministic (ADR-010 clean)**, and the loss is
spread evenly (every chunk sheds only its densest overflow) instead of a dead corner. Same ~5-line
change as (a). The only care point: `cap × max_chunk_count` must stay < 10,240 if a future AO grows
the chunk count — cheap to belt-and-suspender with a global ceiling too.

**(c) Player-keyed pooled ring (bead 503b)** — the correct long-term answer: keep trunk colliders
only in a ring around the player, recycle as they move → full cover everywhere reachable, bounded
body count. But it needs per-frame player tracking + build/teardown churn logic. **Most code,
slowest to first pixels.**

### Verdict
Ship **(b) per-chunk cap NOW** — it is the same trivial diff as (a) but **deterministic** (does not
trip ADR-010) and spatially even, and it gets the windowed look on screen with zero crash risk
immediately. Do NOT ship (a): its order-dependence is a fresh determinism landmine on a project that
just wrote ADR-010. Queue **(c) bead 503b** as the follow-up that restores 100% cover density — the
per-chunk cap is a **look-gate scaffold, not the final cover model** (name the sacrifice: capped
chunks render dense trees the player's bullets/body pass through in the overflow tail).

---

## 2. BUILD-BEHIND-LOADING-SCREEN — is reordering `_on_terrain_ready` the fix?

**No. The reorder is a no-op for the shipped flow, and the shipped flow already builds behind the
loading screen.**

- `GroundClutter.setup` does **NOT depend on the player.** `setup` → `_scatter_resident`
  (`ground_clutter.gd:112-142`) reads `world.map_size`, `world.mission_seed`,
  `world.terrain_manager.get_height_at`, and `world.gameplay_grid` (via `_accept`, `:146-153`).
  No `world.player` reference anywhere. So the `_on_terrain_ready` order (player spawn `:170`
  BEFORE clutter `:174-176`) is functionally irrelevant — swapping them changes nothing.
- **More importantly, in the real game the player is not spawned in `_on_terrain_ready` at all.**
  Both live entry points set `spawn_player_on_ready = false` (`game_flow.gd:229` mission,
  `:396` hub), so the `if spawn_player_on_ready` block at `game_world.gd:166-170` **never runs**.
  The player is spawned **externally** by `world.spawn_player_at(spawn)` at `game_flow.gd:253`
  (mission) / `:408` (hub) — *after* generation.
- **The mission reveal is already gated correctly.** In `_run_mission`: loading screen goes up in
  `start_mission` (`:203`), then `await world.is_world_ready` (`:231`), then
  `MissionGenerator.plan` (`:242`) + `MissionGenerator.build` (`:248`) + `spawn_player_at` (`:253`)
  + squad/weather/HUD, and only THEN `_swap_screen(null)` at **`:284`** tears the loading screen
  down. `MissionGenerator.build` is **fully synchronous** (grep: no `await`, no `call_deferred`
  anywhere in `mission_generator.gd`), so villages/enemies are all placed before the screen drops.
  **The player never sees build happening.** Same shape in `enter_hub` (`:430`).

So the "world resettles then settles" Caleb saw is **not** a `_on_terrain_ready` ordering bug and
reordering it will not fix it. The two real candidates, both of which the TREE_COVER flip touches:
1. **Physics settle of thousands of freshly-added StaticBody3D + the player capsule** dropping onto
   them the instant the loading screen clears — Jolt resolving 6-7k new static bodies plus the
   RESEAT safety net (`game_world.gd:369-382`, re-seats the player if it ends up below ground) can
   read as a one-frame "settle." The per-chunk cap (Q1) shrinks that body count and helps here.
2. **Direct-scene-run of `game_world.tscn`** (spawn_player_on_ready defaults `true`), the only path
   that spawns the player inside `_on_terrain_ready`. Even there `_on_terrain_ready` is one
   synchronous function → a single frame is presented → no visible mid-build resettle. This is a
   dev/test path, not the mission.

**Minimal ordering fix:** none needed in `_on_terrain_ready` for the populated AO — it is already
built-before-reveal. If any settle remains after the cap lands, the lever is to spawn the player one
`physics_frame` earlier under the loading screen (already the case) or add a single
`await get_tree().physics_frame` before `_swap_screen(null)` so Jolt settles the static bodies while
the screen is still up. That is a `game_flow.gd:283` tweak, not a `game_world` reorder.

---

## 3. DETERMINISM / FOSSIL / CRASH landmines in flipping the default to TREE_COVER

- **JunglePatchLayer is NOT orphaned — do not treat it as a fossil.** `ai_stress_arena.gd:408`
  constructs `JunglePatchLayer.new()` **directly**, bypassing `VegetationManager.canopy_source`
  entirely. It stays a live consumer (bench dressing / FPS instrument). Flipping the VM default to
  TREE_COVER does not make it dead code, and deleting it would break the arena. **No fossil-law
  action, and the "two never run together" invariant holds** — the arena path and the VM canopy
  path are separate node trees.
- **Double-canopy is structurally prevented.** `VegetationManager._ready` (`:127-136`) builds
  `_tree_cover` XOR `_patch_layer`, and `_rematerialize` (`:570-579`) routes to exactly one branch.
  Flipping the default just selects the TREE_COVER arm. Clean.
- **One dead branch to notice (not a blocker):** `_update_frustum_culling` (`:168-205`) has a
  patch-culling pass guarded on `_patch_layer != null` (`:175`) and a `_chunk_instances` pass — both
  are empty under TREE_COVER, which is fine (TreeCoverLayer self-culls via `visibility_range`). But
  grass in `_chunk_grass` is still materialized under TREE_COVER (`_rematerialize:581` always calls
  `_materialize_grass`) and IS frustum-culled, so grass culling still works. No action, just
  confirming nothing goes unculled.
- **Determinism (ADR-010):** `_build_scatter` (`:587-614`) seeds `rng` from
  `hash([chunk_coord, mission_seed])` → per-chunk deterministic scatter, independent of load order.
  Good. The ONLY thing that would break determinism is a **global** collider cap (Q1 option a),
  because it drops colliders by load order. **The per-chunk cap keeps the whole path
  order-independent** — this is the second reason to pick (b) over (a).
- **No crash landmine in the flip itself** once colliders are capped: species meshes load via
  `load_species` / `_extract_mesh` (`:45-55`, `:149-158`) with `ResourceLoader.exists` guards and a
  missing-card fallback, so a missing GLB degrades gracefully rather than crashing.

---

## Bottom line
1. Add a **per-chunk trunk cap (~300)** at `tree_cover_layer.gd:84` — cheapest change, zero crash,
   deterministic. Render-only (MMIs) has no Jolt exposure at all. Pooled ring (503b) restores full
   cover later.
2. **Do not reorder `_on_terrain_ready`.** Clutter doesn't use the player, the live flow spawns the
   player after a synchronous build behind the loading screen, and the reveal is already gated. Any
   residual settle is Jolt digesting the new static bodies — shrink it with the cap, optionally add
   one `await physics_frame` before `game_flow.gd:284`'s `_swap_screen(null)`.
3. Flipping the default is **fossil-clean and determinism-clean** (given the per-chunk cap);
   JunglePatchLayer stays live via the arena and must not be deleted.
