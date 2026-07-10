# ADR-013: World streaming policy: small maps load whole, streaming is for 3km+
**Date:** 2026-07-10 · **Status:** Accepted (War Room audit #2) · **Supersedes/Amends:** TerrainEngine header doctrine ("large maps (3km x 3km) / streams chunks around camera", `terrain/core/terrain_manager.gd:3-4`, `terrain/core/heightmap_storage.gd:3-4`); amends the Full Game Audit #2 decree (build order item 2) into standing law

## Context

The TerrainEngine was copied into RECONgame from a project designed around 3km×3km streamed worlds, and it
kept that design's assumptions: `terrain_manager.gd:3-4` still advertises "large maps (3km x 3km) / streams
chunks around camera", and its export defaults (`map_size=3000, load_distance=3, unload_distance=5`,
terrain_manager.gd:17-24) are 3km-era numbers. The shipping game is not that game. The AO of record is
**1280m per side** — `scripts/levels/world_config.gd:7-11` sets `MAP_SIZE=1280, CHUNK_SIZE=256, CELL_SIZE=4.0,
LOAD_DISTANCE=2, UNLOAD_DISTANCE=3`, wired into TerrainManager at `scripts/levels/game_world.gd:78-82`. That is
a **5×5 = 25-chunk world**, and `_load_initial_chunks_async` (terrain_manager.gd:209-227) loads the *entire*
grid up front behind the loading screen. Bead 8pbo's probe confirms all 25 chunks resident and flat at steady
state.

Streaming then runs anyway. `_process` calls `_stream_chunks_around_camera()` every frame
(terrain_manager.gd:79-80, 231-238). Crossing a 256m chunk boundary does two things at once: (1)
`_unload_distant_chunks` (terrain_manager.gd:304+) frees every chunk beyond Chebyshev distance 3 — **768m** —
including its vegetation (terrain_manager.gd:324-327); on a 1280m open AO with hillside sightlines the far
edge of the map is visible, so whole 256m squares of terrain and jungle visibly vanish and reappear. (2)
`_load_chunks_around` (terrain_manager.gd:242-257) reloads every newly-in-range chunk **synchronously in a
single frame** — each `_load_chunk` (261+) is a full SurfaceTool mesh build (`terrain_chunk.gd:51-129`), a
`create_trimesh_shape()` collision cook (`terrain_chunk.gd:236-252`), *and*
`vegetation_manager.generate_for_chunk` (terrain_manager.gd:278), with **no time budget**. On the measured
19–25 FPS baseline (bead 8pbo) the hitch reads as the world lurching.

This is the mechanism behind playtest R2's "terrain jumps crossing cell boundaries" (bead n2ij). Note there is
no terrain LOD in the engine at all — `terrain_chunk.gd` builds one full-res mesh per chunk — so the pop is
not an LOD seam; it is binary chunk existence. The bitter irony: the same file already contains the correct
pattern. The explosion-rebuild path runs through a deferred queue with an 8ms/frame budget
(`REBUILD_BUDGET_MS := 8.0`, terrain_manager.gd:52; `_process_rebuild_queue`, 84-95). The streaming path never
learned that lesson. On the current map, streaming saves nothing — the initial load already paid for all 25
chunks (~200k terrain tris, which the probe shows the GPU holds flat) — and only causes the bug: it unloads
terrain the load screen bought, then re-buys it with a main-thread hitch. This is the exact synchronous-world-
streaming bug class that killed the Catacombs project; the council kills it here by policy, not tuning.

## Decision

**On any map ≤ 2km per side, chunk streaming is DISABLED. The world loads whole, once, behind the loading
screen, and stays resident for the mission.**

- `_stream_chunks_around_camera()` MUST NOT run when `map_size <= 2000.0`. Implementation may skip the call in
  `_process` or set `unload_distance >= chunks_per_side`; either way the observable contract is: **after
  `terrain_ready`, chunk count never changes until mission teardown** (testable: assert `chunks.size() == 25`
  is invariant across a full traverse of the 1280m AO).
- The current AO of record remains 1280m / 5×5 chunks per `world_config.gd`. Changing `MAP_SIZE` above 2000m
  is an ADR-level decision, not a tuning tweak.
- The streaming code **stays in the codebase** for future 3km+ AOs. It is NOT deleted.
- Streaming MUST NOT be re-enabled — on any map size — until BOTH hold: (1) chunk load/unload work runs under
  a per-frame time budget like the rebuild queue's `REBUILD_BUDGET_MS` (terrain_manager.gd:52, 84-95), and
  (2) mesh build + trimesh collision cook are moved off the main thread (or otherwise amortized so no single
  frame absorbs a whole-chunk build). Re-enablement requires its own ADR with before/after frame-time
  measurements.
- The misleading 3km headers in `terrain_manager.gd:3-4` and `heightmap_storage.gd:3-4` are amended to state
  this policy (Truth law: code comments may not claim behavior the shipping config contradicts).
- Verification: this decree item closes only with a measured before/after (frame-time trace or FPS log across
  chunk-boundary crossings), per the audit's Verification law. "Streaming disabled, looks fine" does not close
  n2ij.

## Consequences

**Bought:** the R2 terrain pop and its boundary-crossing hitch are eliminated by construction, not mitigated —
the whole Catacombs bug class becomes impossible on shipping maps. One fewer per-frame system; the ~5-line fix
frees the trust-restoration day for measurement rather than tuning. The engine's honest capability envelope is
now written down: RECONgame ships 1280m AOs until someone pays the threading bill.

**Sacrificed (no free lunches):** all 25 chunks stay resident — memory and draw ceiling are permanently
whole-map on ≤2km AOs; no headroom is reclaimed when the player huddles in one corner. The 3km+ ambition is
formally deferred: any future large-AO design MUST first fund time-budgeted, threaded streaming plus (in
practice) real terrain LOD, which does not exist today. Streaming code kept-but-dormant is untested code — it
will rot until the 3km ADR revives it, and that is accepted.

**Work created:** the disable itself plus its measurement lands inside the trust-restoration day (decree build
order item 2; closes the first item of bead n2ij, contributes numbers to bead 8pbo). Header-comment amendments
ride the same change. Future work (not scheduled): threaded/budgeted streaming ADR, gated behind an actual
3km+ AO design need.

## Evidence

All verified against source this session (2026-07-10):
- `scripts/levels/world_config.gd:7-11` — `MAP_SIZE=1280, CHUNK_SIZE=256, CELL_SIZE=4.0, LOAD_DISTANCE=2, UNLOAD_DISTANCE=3`
- `scripts/levels/game_world.gd:78-82` — WorldConfig wired into TerrainManager
- `terrain/core/terrain_manager.gd:3-4`, `terrain/core/heightmap_storage.gd:3-4` — inherited 3km doctrine in headers
- `terrain/core/terrain_manager.gd:79-80, 231-238` — streaming called every frame from `_process`
- `terrain/core/terrain_manager.gd:242-257, 261-287` — synchronous per-frame chunk load: mesh + collision + vegetation, no budget
- `terrain/core/terrain_chunk.gd:51-129` (SurfaceTool mesh build), `:236-252` (`create_trimesh_shape()` cook)
- `terrain/core/terrain_manager.gd:304+, 324-327` — unload frees whole chunks + vegetation beyond Chebyshev 3 (768m)
- `terrain/core/terrain_manager.gd:52, 84-95` — the 8ms `REBUILD_BUDGET_MS` deferred queue (the pattern streaming must adopt)
- `terrain/core/terrain_manager.gd:209-227` — `_load_initial_chunks_async` loads the full grid up front
- Beads: **n2ij** (playtest R2 P1, terrain pop — first item closed by this policy), **8pbo** (perf, 19–25 FPS baseline; probe: 25 chunks, all flat)
- War Room: `production/war_room/synthesis.md` (wound #2, build order item 2), `analysis/technical_director.md` §A3, ADR candidate #3

## Related

- ADR-001 (renderer of record), ADR-002 (character scale contract) — the other two playtest-R2 visual P0s from the same audit
- ADR-010 (determinism contract) — a static, fully-resident world is trivially deterministic; streaming re-enablement must not break it
- Beads: n2ij, 8pbo
- Pillars served: **2. Atmosphere** (the world no longer pops and lurches) and, via the removed hitch on a 19–25 FPS floor, **1. Outstanding gunplay**
