# BRIEFING — World-Build Unification PHASE 2 (density / render / look)

**Convened:** 2026-07-17 · **Arbiter:** recon-overseer · **Summoner:** Caleb (approved; "keep doing what we're doing")

## Where we are
Phase 1 shipped (resident + deterministic world; ADR-028). Pre-check proved seed 47225 is an all-highland
map (floor 132m) the classifier already zones **~75% jungle** — so the sparse/no-3D-jungle look is a
RENDER/DENSITY problem, not open zoning. Phase 2 is that render/density fix. STOP after Phase 2 for a
batched windowed look+FPS confirm (do NOT pop a window).

## Phase 2 scope (Summoner's order)
1. MERGE the parallel veg systems into ONE source of truth (ADR-028): JunglePatchLayer, VegManager's
   cached tree/grass placer, GroundClutter, TreeCoverLayer. Fossil-law everything retired; shrink baseline.
2. WIRE TreeCoverLayer LIVE as the LOD tier: near = real 3D collidable hideable cover, far = impostor card.
3. ZONING rewrite (terrain_zoning.gd, keep it the ONE pure classifier per 6od4): dense jungle DEFAULT,
   varied with clearings/paddies/villages/treelines. Not uniform-heavy, not sparse-open.
4. FIX the paddy gate: RELATIVE elevation (local relief / percentile), not absolute 50m. 47225's floor is
   132m so nothing is ever below the 50m gate -> 0 paddies today (the "0 rice cells" P0).

## Ground truth the council must weigh (verified in code)
- **The classifier is ALREADY unified.** `GameplayGrid._determine_terrain_type:283` AND
  `VegetationManager._determine_terrain_type:297` both call `TerrainZoning.classify(height,wx,wz,seed)`.
  So a zoning rewrite changes AI sight (vegetation_density -> enemy_base sight cap) AND visuals together.
- **`classify()` is a PURE function of (height, x, z, seed)** and gates lowland on ABSOLUTE `height<50`.
  Relative elevation needs the map's relief (min/max or percentile) fed in without breaking ADR-010.
- **TreeCoverLayer is a self-contained MECHANISM, wired to NOTHING live.** near-solid MultiMesh +
  per-instance CylinderShape trunk collider (cover-givers only) + far card. Its near-solid renders
  `broadleaf_a/b/c` = Caleb's DARK-PYRAMID broken .blends.
- **The standing veg_lod decree (2026-07-17)** ratified that making TreeCoverLayer the LIVE canopy —
  retiring the merged-patch render + procedural billboards — is GATED on a windowed look-check, because
  ripping the working render for dark-pyramid broadleaf "without eyes on the new look would be reckless."
- BillboardVegetation: no live source; already gone (stale test refs only).
- GroundClutter (Phase 1) is now resident bucketed, 12,784 buckets worst-case, FPS unverified headless.

## THE CRUX for the council
The Summoner wants TreeCoverLayer wired LIVE now; the standing decree + the broken broadleaf say the
render switchover needs his eyes. **How do we wire the mechanism live + land the Pillar-3 collider win +
the far-card LOD, WITHOUT shipping a dark-pyramid world and WITHOUT touching .blend?** Options to weigh:
keep JunglePatch as the near VISUAL while TreeCoverLayer supplies colliders+cards; OR full switchover
flagged as look-broken pending Caleb; OR use patch meshes as the "solid" source; OR a config flag that
selects render path so the switchover is one line once the .blend clears.

## Questions
- **Merge/programmer:** the ONE-veg-system structure. Who owns it, what each chunk builds, what gets
  DELETED (JunglePatchLayer? the _materialize_vegetation lone-tree path? does GroundClutter fold in?).
- **Tech-art/design:** the dense-default-with-clearings zoning model + target histogram; the dark-pyramid
  gating resolution; the relative paddy gate mechanism.
- **TD/devil:** perf (per-instance colliders at scale — the 32k-collider hazard, bounded how?),
  determinism (relative elevation into pure classify), the LOD snap, what breaks (arena, saves, the AI
  sight cap now reading a denser world).

## Guardrails
GATE (stabilization/decree-item, exempt) · fossil law · comment discipline · scoped commits · NO push ·
NO .blend edits (flag broadleaf) · 4.7 only · headless only (windowed confirm batched, deferred).
