# PHASE 2 — TECHNICAL-DIRECTOR + DEVIL'S-ADVOCATE (perf / determinism / breakage)

Read from CODE, not the plan. Verdict at bottom of chat; this is the full record.

---

## 0. THE LOAD-BEARING FACT THE DECREE GOT WRONG

The veg_lod decree (`2026-07-17_veg_lod/synthesis.md:33-38`) says colliders are **"bounded to a
tight near ring"** with a "per-chunk cap". **That bound does not exist in the code.**

`tree_cover_layer.gd:82-85`:
```gdscript
if COVER_TRUNK.has(nm):
    var r: float = float(COVER_TRUNK[nm])
    for xf: Transform3D in xforms:
        nodes.append(_trunk_body(xf.origin, r))   # one StaticBody per instance, UNCONDITIONAL
```
Every cover instance in the chunk gets a `StaticBody3D`. The `visibility_range_begin/end` at
`:125-129` is set on the **MMI only — that is RENDER culling, not collision.** The colliders have
**no distance gate at all.** They are created in `generate_for_chunk`, stored in `_chunk_nodes`, and
only removed by `clear_chunk` (`:92-98`) — which fires on **chunk teardown**.

**In a resident world (ADR-013), chunks never tear down.** `terrain_manager.gd:71` + game_world
build all 25 chunks once and hold them for the mission. So **every trunk collider is resident and
permanent for the whole mission.** The "near ring" is a render ring; the collision set is the
*entire map*. The decree bounded a thing the mechanism does not do.

---

## 1. PER-INSTANCE COLLIDERS AT SCALE — the count, and the real bound

**World:** `world_config.gd:9` MAP_SIZE=1280, chunk 256 → **5×5 = 25 resident chunks**.
`VEGETATION_DENSITY_MULT=1.0`.

**Per-chunk cover count.** TreeCoverLayer is wired to nothing live, so the driver is the Phase-2
unknown. Two plausible drivers, both off the same grid the current systems use:
- Mirror VegManager's scatter (`vegetation_manager.gd:67`): `TREE_CANDIDATES_PER_CHUNK=1200`,
  accepted by `tree_chance` (`:47-49` — light 0.30 / medium 0.55 / heavy 0.80). A jungle-DENSE map
  (~75% jungle, heavy-dominant) → accept ≈ 0.6 → ~720 trees/chunk. Most jungle species are cover
  species (broadleaf/bamboo/palm all in `COVER_TRUNK`, `tree_cover_layer.gd:19-27`) → ~**575–720
  cover instances/chunk**.
- Denser-default zoning (the Phase-2 order) pushes acceptance up, not down.

**Resident StaticBody3D total: ~575 × 25 ≈ 14,400, and 720 × 25 ≈ 18,000; a heavy-default map
reaches 20,000–25,000.** Each body carries a `CollisionShape3D` child (`:138-143`) → **double the
node count: ~30,000–50,000 resident nodes**, plus the CylinderShape3D resources. This is the
"32k-collider hazard" the decree named — and the as-written mechanism **exceeds** it, because the
render ring it credited for the bound does not touch collision.

**CPU / physics cost of resident-all:**
- **Broadphase inflation.** PhysicsServer3D holds all ~15–25k static bodies in its BVH. Static
  bodies never integrate (no per-frame sim cost), but *every* query — the player capsule's
  `move_and_slide`, and **every bullet raycast** (gunplay is Pillar 1, high ray volume) — walks a
  BVH inflated by 25k leaves. O(log n) per query, but the constant and the tree memory balloon.
- **Load-time stall + RAM.** Instantiating 30–50k `Node`s and `add_child`-ing them into the
  SceneTree during the resident build is a node-creation storm: tens of MB of node overhead plus a
  measurable one-time hitch. On the single 98%-full disk / Intel-UHD target this is not free.
- This lands on a machine already at **19–30 FPS with jungle 71% of the frame**. Adding a
  permanent 25k-body physics world is a top-risk move, headless-unverified.

**The bound that actually works.** You cannot get a "tight near ring" for free in a resident world,
because the ring is keyed to the **player**, and a player-keyed ring needs a per-move update. Two
honest options, each with a named cost:
- **(A) Resident-all + cheap shape.** Keep it simple, eat 15–25k static bodies. Cost: the physics
  world above; bulletproof determinism (no per-frame state); no `_process`. Viable *only* if a
  headless body-count + bullet-ray bench proves the broadphase holds on the UHD target.
- **(B) Player-keyed collider pool (recommended).** A small fixed pool (~a 46m ring ≈ 60–150 trunks
  at jungle density) that **repositions existing bodies** to the nearest cover instances as the
  player crosses cells — rebuilt on a **coarse cadence (cell-cross / ~4 Hz think), NEVER per-frame,
  and NEVER create/free per update** (that churns the PhysicsServer and the GC). Cost: reintroduces
  a periodic update loop — the exact per-frame cost Phase 1 just *removed* from GroundClutter — so
  it must be throttled and pooled, not a naive `_process` rebuild. This is the only model that
  bounds resident collision without a 25k-body world.

Either way: **the decree's stated bound is not implemented, and shipping resident-all silently is
the trap.** Pick A or B explicitly and bench it headless before wiring live.

---

## 2. DENSER ZONING vs AI FAIRNESS (ADR-005)

`enemy_base.gd:72-73` SIGHT_CAP_OPEN=140, SIGHT_CAP_JUNGLE=45. `:649-656`:
`lerpf(140, 45, clampf(veg,0,1)) * weather`. Heavy jungle density 0.95
(`gameplay_grid.gd:293`) → cap ≈ **49.75m**; gallery forest (`:160` up to 0.95) same. A
dense-DEFAULT map parks nearly the whole AO at the ~45–50m floor.

**Is this a Fairness Law violation? No — and it's mostly intended.** ADR-005 fairness protects the
*player* from an unfair AI (no aimbot-through-foliage; alert ≠ accuracy; telegraphed shots). A
**blinder** AI does not violate fairness — jungle *is* concealment (Pillar 3). `_can_witness`
(`:698-701`) gates on the cap and a real ray; `has_line_of_sight` (`gameplay_grid.gd:463-468`)
adds a deterministic 30% per-cell block in heavy jungle. All of that makes the AI see *less*, which
is fair.

**The real risk is GAMEPLAY, not fairness:**
- **Uniform-heavy collapses engagement variety.** If zoning is all-jungle, every witness range is
  ~48m everywhere, firefights degenerate to sub-48m knife-fights, and stealth becomes trivial. The
  fix is exactly the briefing's word — **dense-with-CLEARINGS**. Keep a real fraction of
  GRASSLAND/CLEAR/PADDY (low veg) so sightlines vary. This is a **distribution requirement, not a
  sight-cap floor** — 45m is already the floor and needs no change.
- **Concealment-cover fallback degenerates.** `enemy_base.gd:1450-1454`: `veg > 0.6` → auto soft
  cover (quality 0.4). If the whole map is >0.6, **every enemy is always "in cover"** and never
  needs to move to cover — the cover-seeking behavior (a Pillar-1 tactical read) flattens. Flag for
  the AI lens.

**No sight-cap floor needed. The floor that IS needed is a floor on the fraction of LOW-density
terrain in the zoning histogram** — guarantee clearings/paddies/treelines so the map is not one
48m-cap smear.

---

## 3. DETERMINISM — the relative-elevation ceiling (ADR-010)

`terrain_zoning.gd` today: `classify(height, wx, wz, seed)` is a **pure function**; the only mutable
state is `static _noise` cached by `_noise_seed`, self-healing on seed change (`:67-74`) AND reset
via `reset()` (`:41-44`, the Phase-1 cross-mission fix). Clean.

Phase 2 makes `LOWLAND_MAX_H` (`:23`) **relative** — a ceiling derived from the map's relief
(min/max or percentile). **Three ADR-010 holes to close:**

1. **Static-leak (the exact `_noise` bug again).** If the relief lands in a new `static var
   _relief`, it inherits `_noise`'s original sin: set once, `classify()` on mission 2 (different
   heightmap) runs before recompute and uses **mission 1's ceiling**. Must be **folded into
   `reset()`** and given the **same seed-guard self-heal** as `_patch_noise`, OR passed as a **5th
   pure param** to `classify()` (cleaner — keeps the function pure, no static at all).
2. **Set-order.** `classify()` must never run before the relief is configured. A zero/stale ceiling
   silently mis-zones the whole map. Add a set-order assert, or make the param mandatory.
3. **Stream-order (the subtle one).** Relief must be computed **ONCE over the full heightmap before
   ANY `classify()` call** — a fixed-sample percentile/min-max. If it's accumulated as a *running*
   min/max while chunks load, the ceiling `classify()` sees depends on **which chunk is classified
   first** → a stream-order dependence, an ADR-010 violation even though the world is "resident."
   Resident build is a fixed loop (`terrain_manager.gd:207-214`), so a one-shot full-heightmap
   relief is deterministic; a lazy/incremental one is not.

**Cleanest fix: pass relief as a param to `classify()` (no new static), computed once up front.** If
a static is unavoidable, it MUST be in `reset()` + seed-guarded + set-order-asserted.

---

## 4. WHAT BREAKS — and the single biggest risk

- **The arena (hard break).** `ai_stress_arena.gd:176,408-416,424` instantiates `JunglePatchLayer`
  directly, calls `_load_patches()`, and fills `T_HEAVY_JUNGLE`. It also runs its **own**
  GroundClutter veg (`:432-483`) and stamps its own sight grid (`:527-570`). **Fossil-law-deleting
  JunglePatchLayer this phase parse-breaks the arena** and the probes that ride it (`veg_cover`,
  `arena_patrol`, `ai_stress_arena`, `test_activity_tiering`).
- **`test_tree_cover_lod` (ratcheting probe).** Asserts near-solids carry colliders, concealment
  species don't, cards load (`test_tree_cover_lod.gd:11-15`). If collision moves to a player-ring
  pool (§1-B), `collider_count()` semantics change and the probe must be updated in lockstep — it is
  a ratchet, so a silent change turns it red.
- **Saves / determinism.** Zoning rewrite changes the map for a given seed. `test_one_classifier`
  and any seed-pinned determinism probe go red **by design** (expected, must be re-baselined WITH
  the ADR, not silently). Saves that store seed-only will silently regenerate a *different* world.
- **AI sight grid.** Denser world → lower caps everywhere → any AI-behavior probe tuned to
  open-world engagement ranges shifts pass/fail. `ai_stress_arena` witness/engagement expectations
  may move.

**SINGLE BIGGEST RISK — do NOT full-switchover this phase.** A full switchover means, in one pass:
(a) deleting JunglePatchLayer → **breaks the arena**; (b) making TreeCoverLayer the near VISUAL →
its near-solid renders the **broken dark-pyramid `broadleaf_a/b/c` .blends** (briefing:28-31,
NO .blend edits allowed) → **ships a dark-pyramid world**; (c) resident-all colliders → **15–25k
static bodies unbenched** on a 19–30 FPS machine. Three unshipped-quality landmines detonating
together, none look-checked.

**STAGE it.** This phase: wire TreeCoverLayer for **colliders + far CARDS only**, with a
**player-keyed pooled collider ring (§1-B)**, and **keep JunglePatchLayer as the live near VISUAL**.
Do NOT delete JunglePatchLayer (fossil-law retirement **defers** until the .blend is fixed AND the
windowed look-check passes — exactly what the veg_lod decree already gated). Land the Pillar-3
cover win and the far-card LOD without the dark-pyramid render and without a 25k-body world. The
full switchover is one flag flip once the .blend clears and the collider bench passes.
