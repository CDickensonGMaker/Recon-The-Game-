# Perf / Gameplay-Programmer Analysis — GroundClutter residency

Read from CODE: `ground_clutter.gd`, `jungle_patch_layer.gd`, `vegetation_manager.gd`,
`game_world.gd::_on_terrain_ready`.

## What the current clutter actually costs (measured from the code)

- `LAYERS` sums to **408 instances** (160+90+70+30+22+10+12+14) across **8 MultiMeshInstance3D**
  (one per texture, because each layer is a distinct PNG → distinct material → cannot share a MM).
- `_process` polls at 2 Hz (`_poll < 0.5`), and only re-scatters when the player has moved
  `RESCATTER_DIST = 22 m` from `_last_center`. `_scatter` re-rolls **all 408** transforms against a
  fresh RNG seeded by `hash(cell)` of the 22 m grid cell. Instances that fail the water / `jungle_only`
  test are **parked at y = -500** (still counted, still in the buffer).
- So GPU draws ≤ 8 draw calls / ≤ 408 instances, all inside a **45 m ring** that teleports with the
  player. On-screen density budget = 408 / (π·45²) = 408 / 6362 = **0.0641 inst/m²**.

The frame cost of the ring itself is small (it is not the 71% jungle). The defects are: (1) the ring
**re-randomizes** every 22 m → pop-in / crawl, and (2) it is a **second bespoke worldbuild system**
living outside the chunk lifecycle, which is exactly what this session is unifying.

---

## Q1 — Bucketing to be resident with a working near-LOD

MultiMesh has no per-instance visibility_range; `visibility_range_*` is on the *node*. A single moving
MM therefore only gives you "cull the whole ring." To get resident content with a real near cutoff you
must bucket into sub-cells, each a MMI with its own `visibility_range_end`, exactly like
`JunglePatchLayer._make_bucket` (subcell 36 m, near 46, far 80, FADE_SELF, margin 14).

### The governing tension (name it up front)
`visibility_range` culls a bucket by **bucket-centre distance**, not per-instance. A bucket of side `S`
whose centre is within `R` still draws instances out to `R + S·0.707`. So:
- **small S** → tight cull (draw ≈ old ring) but **many nodes**;
- **large S** → few nodes but you draw a fat slab (regresses the frame).

And clutter's 8 distinct textures mean **up to 8 MMI per populated sub-cell** — that is the node bomb,
not the sub-cell grid. JunglePatch dodges this because every patch shares ONE palette atlas + ONE
`_material`, so a sub-cell needs only as many nodes as distinct patch *meshes* present.

### Concrete numbers

Effective draw radius ≈ `R + 0.707·S`. To match the old 45 m ring (≈408 drawn), aim for eff ≈ 50 m.

**Recommended bucket geometry:**
- `subcell_meters = 32`
- `visibility_range_end = 42`, `end_margin = 8` (FADE_SELF) → fades out by ~50 m. Eff radius ≈ 42 + 23 = ~55 m.
- **No far twin** (clutter is ground cover; there is nothing to degrade to — near-only, as directed).

**Drawn instances (near bucket only):** buckets within ~42 m of the camera ≈ π·42² / 32² ≈ 5.4 sub-cells;
at 0.0641 inst/m² and 32² m² per sub-cell that is ≈ **350–560 instances / ~5–8 draw calls** — i.e. the
old ring, ±30%. GPU is unchanged. This is the whole point: **GPU draw stays ≈ the old moving ring.**

**Node count** — this is where the design choice bites:

| Residency scope | Sub-cells | ×layers | Total MMI | Draw/frame |
|---|---|---|---|---|
| Map-resident, 25 chunks (1280 m), **8 textures** | 25·(256/32)²=1600 | ×~1.5 populated avg | **~2400** | ~7 |
| Map-resident, 25 chunks, **textures atlased 8→2** | 1600 | ×~1.0 | **~1600** | ~7 |
| **Chunk-streamed (like JunglePatch), ~9 near chunks, 8 textures** | 9·64=576 | ×~1.5 | **~850** | ~7 |
| Chunk-streamed, 9 chunks, atlased 8→2 | 576 | ×~1.0 | **~575** | ~7 |

**Resident instance count:** map-resident = 1280²·0.0641 ≈ **105 k** transforms (~7 MB, fine for memory,
but 2400 AABBs walked by the culler). Chunk-streamed = 9·256²·0.0641 ≈ **37,700** transforms (~2.4 MB),
of which only ~408 ever draw.

**Verdict on Q1:** `subcell_meters = 32`, `visibility_range_end = 42` (+8 fade), **chunk-streamed** (build
in `generate_for_chunk`, clear in `clear_chunk_visuals`, exactly like the patch layer) keeps GPU draw at
the old ring, holds nodes at **~850 (JunglePatch-scale, not 10k)**, and needs **no atlas** to be sane.
Map-residency (2400 nodes) is affordable but pointless — clutter is only ever seen within 45 m, so
streaming it with terrain chunks is strictly cheaper for identical on-screen result.

---

## Q2 — The simpler option: deterministic cell cache, still-moving 8 MMs, never re-randomise

Keep the 8 MultiMeshes and the moving ring, but replace `hash(22 m cell)`-of-**player** re-rolling with
a fill keyed to fixed **world cells** (à la `_build_placement_cache`: `rng.seed = hash([cell, seed])`).
A cell that re-enters range regenerates the **byte-identical** instances → no re-randomisation, no pop-in.

| Axis | Deterministic moving cache (Q2) | Chunk-keyed buckets (Q1) |
|---|---|---|
| Frame cost | **Identical to today** — 8 draws / ≤408 inst, proven cheap | ≈ same (~7 draws / ~408 drawn) |
| Node count | **8** (constant) | ~850 streamed |
| CPU spike | rebuild 408 transforms every 22 m of travel (~sub-ms) | build once per chunk load (JunglePatch already pays this) |
| Code risk | **LOW–MED**: must map fixed instance slots → stable world cells so slots never re-roll; current per-slot RNG loop doesn't; effectively a rewrite of `_scatter` into a cell cache | **MED**: fold clutter into `VegetationManager` lifecycle + a `_make_bucket` clone |
| "Resident" honesty | **PARTIAL** — logically resident (content = f(world cell)), but nodes/instances still *move & rebuild* with the player; stays a **second bespoke system outside the chunk lifecycle** | **HONEST** — physically resident per chunk, same lifecycle/`clear_chunk_visuals`/frustum pass as the patch layer; this is the actual *unification* |

Q2 is the lower-risk frame play, but it does **not** unify worldbuild and it does **not** satisfy
"resident" in the sense the session wants — it just stops the re-randomisation. It also leaves a
parallel `_process` system that the fossil-law spirit (ADR-023) and this very session are trying to
retire.

---

## Q3 — Recommendation, bounded risk, and what is sacrificed

**Recommend Q1: chunk-keyed deterministic buckets, streamed on the terrain-chunk lifecycle**
(`subcell_meters = 32`, `visibility_range_end = 42` + 8 fade, near-only, no far twin). Move the build
into `VegetationManager._rematerialize` (after patches) / `clear_chunk_visuals`, delete `GroundClutter`'s
`_process` and the `clutter.setup(self)` call in `game_world._on_terrain_ready`. This unifies worldbuild,
kills the re-scatter, and keeps GPU at the old ring.

**Concrete perf risk & how it is bounded:**
1. **Draw-call / overdraw growth** if S too big or R too big. Bounded by `visibility_range_end` (only the
   near bucket ring draws — ~7 calls, verified by the math above) and by chunk-streaming (total nodes ≈
   loaded chunks, ~850). Guard it with a ps2_perf_probe assertion on visible MMI count.
2. **Culler cost** scales with *total* node count. Bounded by **staying chunk-streamed** — do NOT go
   map-resident "for simplicity"; 25-chunk residency triples the AABB walk for zero visible gain.
3. **The 8-texture node multiplier.** Bounded today (~850 is fine). If a future council wants map-residency
   or more layers, that is when you build the clutter atlas (8→2 MMs); not needed now.

**What is sacrificed (no free lunch):**
- **Determinism replaces guaranteed ring-fill.** The old ring force-fills a full 45 m disc around the
  player everywhere; cell-keyed fill will leave some near cells legitimately empty (CLEAR/steep/water),
  and clutter no longer "follows" you into a bare clearing. That is correct behaviour, but it is a visible
  change — thinner cover in marginal terrain.
- **Centre-cull overdraw:** S=32 draws ~1.3× the old tight ring (~530 vs 408 worst case). Accept the ~30%,
  or drop to S=24 / R=40 (eff ~57 m, ~525 drawn) at the cost of ~1.9× the nodes (~1600 streamed). I would
  ship S=32 and only tighten if the probe shows a regression.
- **Per-instance `jungle_only` / water parking moves to build-time cell tests** (`gameplay_grid.is_water`
  / `get_vegetation`), same as `_scatter` already does — no behaviour lost, but it must be ported or the
  buckets will plant grass in the paddies.
- **~2.4 MB resident transforms** and a one-time per-chunk build cost (JunglePatch already pays it).

Bottom line: Q1 costs the same on the GPU as the old ring, stays at JunglePatch node scale without an
atlas, is honestly resident, and is the unification the session is for. Q2 is a valid fallback if council
wants the smallest possible diff, but it is not residency and it leaves the second system standing.
