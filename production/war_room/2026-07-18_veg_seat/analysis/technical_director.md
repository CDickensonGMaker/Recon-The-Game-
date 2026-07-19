# TECHNICAL-DIRECTOR — veg seat + view distance (2026-07-18 evening)

Read: briefing; ground_clutter.gd; tree_cover_layer.gd; vegetation_manager.gd
(generate_for_chunk/_rematerialize/_build_scatter/set_density_centers); terrain_manager.gd
(modify_terrain/_rebuild_chunks_in_region/_rebuild_chunk_immediate/_process_rebuild_queue);
game_world.gd (_on_terrain_ready); game_flow.gd (enter_hub); site_planner.gd
(place_firebase_main/clear_and_flatten/stamp_village); clearing_system.gd
(_apply_stage_changes); damage_system.gd (apply_damage); godot_4.7_features.md.

---

## 1. FIX A — region_rebuilt + per-subcell clutter re-scatter: AGREE, with three amendments

### 1a. Which path actually runs on modify_terrain — and a fossil found

`modify_terrain` (terrain_manager.gd:313) → `_rebuild_chunks_in_region` (line 323) →
`_rebuild_chunk_immediate` **directly and synchronously** (line 343). The deferred
`_rebuild_queue` / `REBUILD_BUDGET_MS` machinery (lines 44–87) is **dead: nothing in the
repo ever appends to `_rebuild_queue`** (grep: only declaration, drain, and pop). The
comment at line 66 — "Explosion/clearing rebuilds stay live … _rebuild_chunk_immediate" —
describes a queue that is never fed; rebuilds are all synchronous today. That comment is a
tombstone hiding a fossil (ADR-023 candidate: delete the queue or wire it; do not leave it).

**Emission point**: emit from `modify_terrain`, after `_rebuild_chunks_in_region`, carrying
the **cell-accurate `affected: Rect2i` converted to a world-space Rect2** — NOT from
`_rebuild_chunk_immediate` (would fire once per chunk with chunk-sized rects, and would
double-fire if the dead queue is ever revived), and NOT the chunk-aligned rect (a 215m
flatten touches a 3×3 chunk block = 768m square = ~576 subcells, while the true affected
cell rect is ~430m = ~196 subcells; the honest rect is 3× cheaper).

### 1b. The flatten storm is real — deferral is CORRECTNESS, not just perf

Counted from code, one patrol-world build fires `modify_terrain`:
- `place_firebase_main`: 1 (R=215 plateau) + 5 (`FSB_CLEAR_DISCS`, R=58–60, each
  `clear_and_flatten` → `ClearingSystem.set_zone_stage(CLEARED)` → `_apply_stage_changes`
  → `modify_terrain`, clearing_system.gd:173) = **6 calls**, all overlapping the same rect;
- villages: 1 per `stamp_village` (site_planner.gd:212), ~2–4;
- first-sign craters: 4–8 × `DamageSystem.apply_damage` → `modify_terrain`
  (damage_system.gd:127, within MAX_DEFORMS budget).

**Total ≈ 12–18 emissions per build**, 6 of them hammering the identical FSB subcells. A
synchronous handler would re-scatter the ~196-subcell FSB region up to 6×.

Worse than the waste: inside `clear_and_flatten` the order is `modify_terrain` FIRST, then
`_veg.clear_area`, then `_grid.update_region` (site_planner.gd:110–116). A handler that
re-scatters synchronously on the signal reads `gameplay_grid` **before** the veg/water
update for that very disc — `_accept` (ground_clutter.gd:146) would keep jungle-only
mushrooms/logs on freshly cleared ground. **Amendment 1: coalesce — accumulate dirty
subcell Vector2i's into a set on each emission, flush once via `call_deferred` (guarded by
a pending flag).** All build-time emissions happen in one synchronous stretch of
`build_patrol_world` (game_flow.gd:273 — no awaits inside), so one deferred flush lands the
frame after, still behind the "BACK TO OPERATION…" loading screen. Cost of one flush:
~200–400 unique subcells × 8 layers ≈ 2–3k tiny bucket rebuilds, ~9–26 candidates each with
1 height sample ≈ 30–80 ms, once, hidden. Runtime crater: 1–4 subcells, sub-millisecond.

### 1c. Determinism — reproducible, with one stream-shift trap worth one line

`hash([Vector2i(sx,sz), li, world.mission_seed])` (ground_clutter.gd:123) re-seeds an
identical RNG stream; same shape as the blessed `_build_scatter` seed
`hash([chunk_coord, mission_seed])` (vegetation_manager.gd:453) — ADR-010 consistent.
`_accept` reading LIVE `gameplay_grid` state is fine per briefing and IS deterministic
across builds: grid state at flush time is a pure function of (seed, build op sequence).

**The trap**: the scatter loop draws pos (2 RNG calls), then `_accept`, and only draws
basis-angle + scale for ACCEPTED candidates (`continue` at line 128 skips those draws). So
one candidate flipping acceptance (crater clears a veg cell) shifts the RNG stream for
every later candidate in that bucket — **surviving plants in a 32m bucket teleport when any
neighbor is rejected**. Not an ADR-010 violation, but visible churn around every runtime
crater. **Amendment 2: draw rotation and scale unconditionally BEFORE the accept check**
(fixed RNG consumption per candidate) — untouched plants then keep bit-identical
transforms across re-scatters. One-line reorder.

**Amendment 3 (mechanical)**: `templates` is a local in `setup()` — must become a member
for re-scatter; and the stored/probed origins must be WORLD-space (the `pos -= centre` at
line 139 is applied after; store before it, or add `centre` back — `centre.y` is 0.0 so Y
survives either way, but don't rely on that silently).

Coverage note: `DamageSystem.apply_damage` past `MAX_DEFORMS_PER_MISSION` skips
`modify_terrain` but still clears veg — clutter won't refresh there. Heights didn't change,
so nothing floats; only jungle-only clutter lingering on late-mission scorched ground.
Acceptable; name it in the decree so it isn't rediscovered as a bug.

---

## 2. FIX B — view_distance 80 → 350: AGREE ON INTENT, AMEND THE MECHANISM

### 2a. Verified semantics: per NODE, measured to the transformed AABB (not per instance, not node origin)

`visibility_range_*` is a GeometryInstance3D property — one render-instance, so a whole
per-chunk per-species MMI toggles as a unit. The reference point is the instance's
**transformed AABB**, not the node origin, and the codebase itself proves it:
`TreeCoverLayer._multimesh` never sets the MMI position (node origin = world 0,0,0) with
world-space instance transforms — if range were measured to node origin, no tree would
ever render more than 46m from the map CORNER, yet villages bless with solid trees
anywhere on the map. GroundClutter's header says the same ("visibility_range culls a whole
bucket by its CENTRE") and buckets at 32m precisely to make that centre meaningful.

### 2b. What chunk-granular ranges actually do (this is the real root cause of symptom B)

A dense species' AABB spans its 256m chunk; its centre ≈ chunk centre. Then:
- **Today (end=80)**: neighbor chunk centres are ≥128m away even standing on the shared
  edge → **neighbor cards can NEVER pass `<80`; only your own chunk's cards, in a narrow
  46–80 ring around its centre**. And your own chunk's solids (0–46 to the same centre) go
  dark near chunk corners (centre up to 181m away). "Renders nothing beyond 80m" is not a
  tuning miss — the granularity makes the band unimplementable.
- **Naive 350**: whole chunks of cards (avg ~4,000 instances, 99,770/25) snap on when
  their centre crosses 350. Pop error = chunk half-diagonal ≈ **±181m**: trees as near as
  ~170m appear as a 256m wall (fog is thin there — 10% transmittance is at 350, not 170),
  and trees out to ~530m render and cost. `FADE_DISABLED` + no `_margin` = hard pop with
  zero hysteresis → whole-chunk flicker while hovering at the contour.

### 2c. Cost on Intel UHD, numbered

In-band chunks at map interior: π·350²/256² ≈ 5.9, call it **5–9 chunks → 20–36k card
quads**, ~100–180 extra draw calls (~20 card species/chunk). Vertex cost trivial (~150k
verts). The two real drivers:
1. **Fill/discard**: alpha-scissor, nearest-filtered, cull-off quads; ~5,600/d px of
   height per metre of card at 1080p → a 6m card is ~56px at 100m, ~16px at 350m. 20–36k
   cards × ~500–1,500px avg, ÷~3 frustum ≈ **2–6× full-screen overdraw of discard quads**
   — the worst shader class for Intel's early-Z.
2. **Shadow pass — found in code**: `TreeCoverLayer._multimesh` never sets `cast_shadow`
   → defaults ON, so every card quad is re-rendered into each directional cascade.
   GroundClutter explicitly disables it (ground_clutter.gd:167); TreeCoverLayer forgot.
   At end=80 this was noise; at 350 it roughly doubles the added cost for zero visual
   gain (a 2-tri billboard's shadow is garbage anyway). **Amendment: cards get
   `SHADOW_CASTING_SETTING_OFF` regardless of anything else.**

Estimate vs the 23fps (43ms) bench: naive 350 plausibly +6–12ms → **~17–20fps**. The
briefing's A/B flag is correct and mandatory.

### 2d. The honest mechanism: subcell card buckets (GroundClutter's own pattern, ADR-028 improve-in-place)

In `generate_for_chunk`, group the card scatter per 64m subcell per species actually
present (jungle cells carry ~4–6 local species): ~16 buckets × ~5 species ≈ 64–96 card
MMIs/chunk → ~1,600–2,400 nodes total (today's whole layer is 4,725 children; this is
absorbable). Pop error drops **±181m → ±45m**, which the 350m fog band genuinely masks;
add `visibility_range_end_margin` ~8m (with FADE_DISABLED it acts as hysteresis). In-band
in-frustum draws ≈ (π(350²−46²)/4096) ÷ ~3 × ~5 species ≈ **~150 card draws**, and
genuinely-out-of-band buckets now cull, cutting rendered card instances 30–50% vs naive.

**Bonus paid for by the same change**: subcell-bucket the SOLIDS too (end=46). Today a
whole chunk's 2,782–4,018 full 3D trees render whenever you're near its centre and vanish
near its corners; honest 46m bucketing renders only 1–4 buckets of solids and wins back
frame time that likely covers the card bill. Colliders (separate StaticBodies, capped 150/
chunk) are untouched.

Order of work: (1) cards `cast_shadow` OFF + end=350 + margin, windowed A/B for the
Summoner; (2) subcell bucketing of cards (and solids) in the same bead — it is ~30 lines
inside `generate_for_chunk`, no new system, no fork. Do NOT resurrect the merged-patch
canopy (fossil law); a per-chunk far canopy sheet is a separate future bead only if the
A/B fails outright.

---

## 3. PROBE — system-owned placed-origin arrays: AGREE

Memory: TreeCover 99,770 origins as PackedVector3Array ≈ 1.2MB; clutter ~60–110k ≈ 1.3MB.
Negligible — keep them always-on, not debug-gated (a debug-only path is its own divergence).
Honesty conditions, all cheap:
1. **Fill the array in the SAME loop that fills the MultiMesh** — the array must BE the
   transform source, not parallel bookkeeping (divergent-systems law; this is exactly how
   the arena/patrol split happened).
2. Store world-space origins (GroundClutter's `pos -= centre`, see Amendment 3 above).
3. Probe runs after `build_patrol_world` AND awaits one process frame so the deferred
   clutter flush has landed — else it honestly reports the bug Fix A just fixed.
4. ±0.5m at 300m of spawn is sound: both systems seat via `heightmap.sample_world` /
   `get_height_at` (same bilinear source), and 300m covers the 215m flatten rect.
5. Right call avoiding MultiMesh readback — diag proved `get_instance_transform` returns
   identity in this headless build; never gate a probe on renderer state.

## Sacrifices named
- Fix A deferral: clutter is stale for exactly one frame after a runtime crater (invisible
  in practice, behind smoke/dirt VFX).
- Amendment 2 changes clutter layouts once (new RNG draw order) — one-time visual reshuffle
  of grass, no gameplay meaning.
- Subcell bucketing adds ~1–2k scene nodes and a small AABB bookkeeping cost per rebuild;
  bought back by honest culling of solids.
- 350m cards on Intel UHD may still cost 3–6ms after all amendments; the dial-back knob
  remains one number.
