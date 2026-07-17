# BRIEFING — NEAR-3D-SOLID / FAR-IMPOSTOR-CARD VEGETATION LOD

**Convened:** 2026-07-17 · **Arbiter:** recon-overseer · **Directed by Caleb (in-scope despite the
stabilize freeze — it finishes the core veg system and is the GPU-side FPS lever).**

> Caleb: *"the player needs real trees and bushes to hide behind but things from afar can use the
> impostor cards."*

## THE INTENT
- **NEAR = the real 3D SOLID models, COLLIDABLE** — the player physically hides behind trees/bushes.
  This serves **Pillar 3** (cover/sightlines), not just looks.
- **FAR = impostor CARDS** — cheap, no collision, camera-facing.
- **Distance-based LOD swap** between them.

## THE ASSETS (confirmed on disk)
- **47 near SOLID glbs** (`assets/world/vegetation/*.glb`): 40 species + 7 deadfall/ground cover solids
  (`fallen_log_a/b`, `felled_tree`, `felled_trunk`, `tree_stump`, `moss_a/b` — **solid-only, no card**).
- **40 FAR cards** (`cards/<name>_card.glb`, re-exported 14:46 today, verified non-empty; tex in
  `cards/tex/`): one per species. Deadfall/ground has none (always near or culled).
- **~25 patch composites + `_far` twins** (`patches/*.glb`): the merged patch meshes the veg system
  stamps **today**.

## THE KNOWN GAP (to confirm via recon)
Patch trees are baked, merged MultiMeshes with **ZERO collision** — so *"real cover you can hide behind"*
does not exist today. That is the actual gap this build closes.

## THE DESIGN QUESTION (for the council — recon in flight)
1. **Replace vs augment the patch composites?** Fossil law: if per-species instance LOD replaces the
   merged-patch stamp, the dead path must be deleted, not left beside it. But the patches are the whole
   current veg render — a wholesale swap is large. Does the near/far ride on the existing per-bundle
   scatter (TYPE_PROPS plant counts) and swap the *stamp* (merged patch → per-species solid/card
   MultiMesh), or is it a parallel near ring?
2. **Collision cost vs cover fidelity.** A collider per near solid is the 32k-node hazard THE_PLAN named.
   Mitigations to weigh: only **cover-givers** get colliders (trees/bamboo/palms/big bushes/logs/stumps —
   NOT grass/fern/vine/moss/rice, which are concealment, not cover); a cheap single trunk collider
   (cylinder/capsule/box), not the mesh; **bound the collidable ring tight** (near count sane) so collider
   count is bounded; consider PhysicsServer3D bodies over StaticBody nodes (no 32k scene nodes).
3. **Swap distances.** R_near (collidable solids) vs R_far (cards) vs the fog wall (~90m) and the existing
   `near_distance=46` / `view_distance=80`. Hard PS2 snap (ADR-026) — no smooth cross-fade.
4. **The GPU win.** Cards are far cheaper than merged far-patches; the jungle was 71% of the frame.
   Note the headless-measurable geometry/draw-call delta.

## GUARD-RAILS / LAWS
- Pillar 3 (cover is real, sightlines honest — a tree that looks like cover must stop a bullet in the near
  ring) · Pillar 2 (near reads solid, far reads as jungle, swap doesn't pop) · ADR-026 (hard LOD snaps,
  short fog-walled draw, ≤ the budget) · ADR-013 (≤2km, chunk-resident) · fossil law · comment discipline.
- **Asset boundary:** may edit veg SCRIPTS + scene wiring + the exported `.glb` imports; **must NOT
  re-bake or edit the `.blend` SOURCES** (Caleb's domain — he's in Blender). Flag him if a source needs it.
- **No windowed Godot** without flagging (Blender + a 4.6.2 editor are open — the look-check waits for a
  clear machine, 4.7 only).

## LENSES
- **technical-director / lead-programmer** — the instancing + collision architecture, collider-count
  budget, replace-vs-augment, chunk streaming of colliders (recon).
- **game-designer / level-designer** — cover honesty (Pillar 3), what counts as cover vs concealment,
  the swap read (Pillar 2).
- **devil's-advocate** — the collider-count blowup, near/far pop, double-draw if augmenting, the
  "tree you can see but not hide behind / hide behind but can't see" fairness trap.
