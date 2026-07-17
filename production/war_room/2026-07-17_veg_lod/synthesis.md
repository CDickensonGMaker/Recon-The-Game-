# DECREE — NEAR-3D-SOLID / FAR-IMPOSTOR-CARD VEGETATION LOD

**Arbiter:** recon-overseer · **Date:** 2026-07-17 · **Sight:** two code-reading lenses (JunglePatchLayer
internals; VegetationManager + BillboardVegetation + streaming).

## GROUND TRUTH (recon-confirmed)
- **Zero collision on ANY vegetation.** Every veg node is a bare `MultiMeshInstance3D`. Only the terrain
  has a collider, and it is **mask 0 (raycast-pick only, no physical response)**. You walk through every
  tree. **"Real cover you can hide behind" does not exist — this is the gap.**
- **Four independent visual layers:** (1) JunglePatchLayer — merged composite patches, own 2-stage
  visibility LOD (full mesh 0-46m → *reduced-real* `_far` mesh 46-80m), LIVE canopy; (2) BillboardVegetation
  — procedural 5-plane PNG cross-billboards, 80-350m; (3) VegManager grass + (4) GroundClutter — near
  ground clutter. The `_far` twin is a **reduced real mesh, NOT a card**.
- **Caleb's assets are INDIVIDUAL species** (`bamboo_a.glb` + `bamboo_a_card.glb`) — a finer granularity
  than the merged patches, and the cards are proper impostor GLBs (a better far-field than the procedural
  PNG billboards).
- Fossils flagged: VegManager `_generate_chunk_vegetation`/`_generate_chunk_grass` (dead duplicates of
  `_materialize_*`) — do not wire to them.

## THE DECISION

**Target architecture (Caleb's direction):** an individual-tree LOD — **NEAR = real 3D species SOLID,
COLLIDABLE** (hide behind it, Pillar 3); **FAR = the species impostor CARD**, no collision; hard PS2
distance snap. This supersedes the procedural billboard far-field and adds the collision the merged
patches never had.

**Cover vs concealment (Pillar 3 honesty).** Only **cover-givers** get a collider: trees (broadleaf,
banana), bamboo, palms, big bushes, and the deadfall solids (fallen_log, felled_tree/trunk, tree_stump).
**Grass, fern, vine, moss, rice, liana, saplings get NO collider** — they are concealment (they cut
sight via the veg-density grid), not cover. A tree that reads as cover MUST stop a bullet in the near
ring; a fern must not fake it.

**Collision budget (the 32k-node hazard, named).** Colliders are **bounded to a tight near ring** and use
a **cheap primitive** (a `CylinderShape3D` trunk, not the mesh), created as `StaticBody3D` per near
cover-instance and **torn down with the chunk**. Near-count stays sane by ring radius + a per-chunk cap.
Tradeoff named: near solids + colliders cost more CPU/nodes than a merged patch, bought back by the far
ring being cheap cards and the collidable set being small.

**Replace vs augment — PHASED, because the visual swap needs eyes.**
- **This pass ships the MECHANISM as a self-contained, headless-proven component** (`TreeCoverLayer`):
  near solid MultiMesh + per-instance trunk collider, far card MultiMesh, species-correct, chunk-lifecycled.
  Its probe proves the Pillar-3 win (cover bodies exist) and the far-card path — **headless, no look-check
  needed to prove collision + wiring.**
- **Making it the LIVE canopy — retiring the merged-patch render and the procedural billboards (fossil
  law) — is GATED on a windowed look-check** (near reads solid, far reads as jungle, the swap does not
  pop). That check needs the machine clear (Blender + the 4.6.2 editor closed, 4.7 only). **Ripping the
  working render without eyes on the new look would be reckless** — so the switchover waits for the flag.

## TRADEOFFS (no free lunch)
- Near collidable solids cost more than merged patches (draw calls + collider bodies) — bounded by the
  tight ring + cheap trunk shapes + a per-chunk cap. The far card ring is the GPU win (jungle was 71% of
  the frame; cards ≪ reduced-real `_far` meshes).
- Individual scatter loses the hand-authored patch *composition*; regained by density-driven per-species
  selection off the same terrain-type grid the patches used.
- The card far-field replaces the procedural billboards — one impostor path, not two (fossil law), but the
  switch-over is look-check-gated.

## GUARD-RAILS
- Pillar 3 (cover real + honest) · Pillar 2 (near solid / far jungle / no pop — look-check) · ADR-026
  (hard snap, short fog-walled draw) · ADR-013 (chunk-resident) · fossil law (delete the superseded path
  at switchover) · asset boundary (scripts + .glb imports OK; **no .blend edits** — flag Caleb).

## SHIPPED THIS PASS
`TreeCoverLayer` component + ratcheting headless probe (near solids carry collision = cover exists; far
uses cards; species map; 0 errors). Switchover to live canopy + retirement of the old paths: **flagged,
look-check-gated.**
