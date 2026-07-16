# War Room Decree — Vegetation as Cover + Concealment (Wave 6, Track D)

**Date:** 2026-07-16 · **Arbiter:** recon-overseer · **Council:** systems-designer, godot-specialist/technical-director, devil's-advocate (parallel, code-read, no cross-talk).

## The matter
The AI stress arena had **no GameplayGrid**, so `enemy_base._sight_cap()` returned a flat 140m and the veg-concealment cover fallback (`enemy_base.gd:1397`) was dead code. Foliage concealed nothing; only tree trunks blocked a ray. Wire a grid + density so where you SEE jungle, sight is actually capped; prove it.

## Convergent findings (all three architects, independently)
1. **The origin-offset trap is THE risk.** `GameplayGrid.world_to_grid` (line 324) is 0-origin and `clampi`s negatives to cell 0; the arena is centre-origin (-100..+100). Left unfixed, every negative coord silently samples cell 0. Fix: a `GameplayGrid` subclass overriding `world_to_grid` (and `grid_to_world` for consistency) with a `world_size*0.5` offset. All readers (`get_vegetation`/`get_cover`/`is_water`/`get_terrain_type`) route through `world_to_grid`, so one override shifts them all. Do NOT add an `_init` unless it `super()`s (base fills the arrays).
2. **The mask "inconsistency" is a NON-ISSUE.** Trunks are layer 1; LOS mask `1`, cover mask `1|32`, bullet mask `1|32|64` all contain bit 1. The 32/64 bits are hurtbox layers, irrelevant to static vegetation. **Do not fabricate a fix.** (Plan/scout error.)
3. **Group join is safe.** Only `enemy_base.gd:290` and `player.gd:469` read group `game_world`, both duck-typed on `.gameplay_grid`. Nothing calls GameWorld methods off the group.
4. **Couple density-stamp to visual placement** (systems-designer): stamping in the same call that plants each mesh makes the mesh the single source — no second table to desync, and Fairness-Law-clean by construction (AI's sight advantage exists only where foliage is visibly drawn).
5. **Concealment threshold is strict `> 0.6`** — anything meant to conceal must exceed it (use 0.65, never 0.6).
6. **Hollow-proof caveat** (systems + devil): keep the central contact zone OPEN so the patrol→combat transition still develops (protects `test_arena_patrol`); put a concealment zone where units actually fight — the ridge-gap bamboo at (±10,0).

## Decree (built)
- `ArenaGrid` subclass, centre-origin, `vegetation_density.fill(0.0)` (open = 140m cap).
- Density stamped by each planter: tree-line clumps 0.95 (→ ~50m cap), elephant grass + bamboo 0.65 (conceals, clears the fallback), palms 0.5, rice 0.2. Ridge-gap bamboo sits on the contact approaches.
- Trunk colliders (already wired) verified to block bullet + LOS rays.
- Minimal D4 readout on the HUD: cover veg-density avg + LOS clear/blocked/blk%.
- Probe `tests/test_veg_cover.gd`: open 0.00→140.0m; jungle 0.95→**49.8m**; trunk blocks bullet+sight, open lane clear; 31% ray-sweep cover. PASS.

## Named sacrifice (the Arbiter's, drawn from all three)
**The arena's existing firefight-tuning baseline is invalidated.** Every prior cone_mult / mirror-ratio / TTK number was measured with sight uncapped at 140m; a real cap shifts engagement ranges and the telemetry must be re-baselined. Deeper: `ArenaGrid` is a lab-only *second* density-authoring surface — we prove foliage cover is **consumed** correctly, never that the production `build_from_terrain`/riparian **writer** authors it correctly.

## Deferred (beaded, not built overnight)
- **D3 destructibility proof** → `RECONgame-4xp5` (minimal arena destroy-cover proof; full 16k-tree contract stays in `eaqv`/`en75`/`2v3t`; design-blocked by `vtiz` concealment readout).
- **D4 full lab instrumentation** → `RECONgame-x2xq` (kill-distance histogram, per-zone breakdown, sight_lab, CSV; ties `752e`/`lmll`).
