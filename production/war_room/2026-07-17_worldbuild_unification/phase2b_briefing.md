# BRIEFING — PHASE 2B: make the roamed AO VISIBLY feel like the arena (Caleb's Rule #1)

**Convened:** 2026-07-17 · **Arbiter:** recon-overseer · **Summoner:** Caleb (greenlit).

## The gate (Caleb's eyes, not geometry counts)
The windowed run looked like an EMPTY OPEN WORLD — no visible vegetation models, not fun to walk, did
NOT feel like Vietnam. The AI stress arena DOES. **Rule #1: "fun to walk around is always rule #1."**

## Diagnosis (accepted)
- The bench booted BARE `game_world` (no `MissionGenerator.build`) → no villages/enemies/paddies/activity.
  The real loop populates the AO; the bench didn't. Flawed test.
- Core cause: the game runs `JUNGLE_PATCH` (merged composite patches) which read as near-nothing; the
  arena instances Caleb's INDIVIDUAL 3D species GLBs (broadleaf/bamboo/palm/elephant_grass —
  `ai_stress_arena._scatter_ground_plants` + `_bamboo_clump` etc.). That individual-model layer is what
  reads as jungle. Phase-2 already built the twin: `VegetationManager.CanopySource.TREE_COVER` +
  `_build_scatter` → `TreeCoverLayer` (near-solid + far-card).
- Spawn alignment is FINE: `enter_hub` spawns at `build_hub`'s `find_site` center + (4,0,6). No desync.
  The firebase is Caleb's Blender drop-in — do NOT polish the procedural one.

## Build target: ONE windowed look on a REAL POPULATED AO with 3D veg live
1. **Flip veg to TREE_COVER** (individual 3D models). The Jolt crash was COLLIDERS (17,087 StaticBody3D >
   10,240 Jolt limit) — the RENDER (near-solid MMI + far-card MMI) is what the look needs and has no
   physics. broadleaf_a/b/c = dark pyramids until Caleb's .blend (1m4q) — flip anyway (~23 other species
   render fine); flag him.
2. **Populated AO**: the look runs `MissionGenerator.build` (villages + rice paddies + enemies +
   civilians + activity), NOT bare game_world.
3. **Build behind the loading screen**: whole AO (incl. 12,726 clutter buckets + veg + population) built
   before the player sees/controls anything — no visible resettle. (Note: game_world._on_terrain_ready
   spawns the player BEFORE clutter.setup — a candidate resettle source.)

## Questions for the council
- **Perf/programmer:** collider strategy for the look — a bounded GLOBAL cap (e.g. < 8000, ships render +
  partial cover, no Jolt crash) NOW with the player-keyed pooled ring (503b) right after, OR build the
  pooled ring now? Which gets the VISIBLE look fastest without crashing Jolt and without permanently
  dropping cover? Does the TREE_COVER RENDER alone (~17k MMI nodes, no colliders) lag/crash? Is
  reordering game_world to build clutter BEFORE player spawn the right resettle fix, and is there other
  post-reveal building (MissionGenerator.build order in start_mission)?
- **Game/level/tech-art:** the populated-AO windowed path — a dedicated bench that runs
  game_world(TREE_COVER) + MissionDirector + MissionGenerator.plan/build on a chosen seed, or drive
  GameFlow.start_mission? Which SEED gives dense-jungle + villages + rice paddies + activity (47225 is
  RIVER_VALLEY/inhabited, now 82% jungle + 5.5% paddy — good enough, or pick better)? Does
  MissionGenerator.build actually place villages/paddies/civilians on it? Pillar-2 reconciliation.

## Guardrails
GATE/fossil/comment laws · scoped commits · NO push · NO .blend (flag broadleaf) · 4.7 only · headless
where possible, but the REAL gate is Caleb's eyes (look-only, Blender open, FPS invalid) · FLAG before the windowed run.
