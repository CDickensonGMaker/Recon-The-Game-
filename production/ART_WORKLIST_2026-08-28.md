# ART WORKLIST — from the 8/27 playtest
Caleb's own bench. Code items stripped out; this is Blender / texture / scene-layout only.
Source: production/PLAYTEST_FINDINGS_2026-08-28.md

> **AS OF 2026-08-28, AND NOT RE-VERIFIED SINCE.** Every defect below is what his eye saw in
> the 2026-08-27 playtest. None of it has been re-measured against the current asset tree, so
> read each line as a dated observation rather than as current fact - the same rule the
> findings table now carries at its own head. (Banner added 2026-09-06: without a date in the
> masthead this doc failed tests/test_doc_hygiene.tscn under the Pointer Law, and a worklist
> that reads as verified truth is exactly what that law exists to stop.)

## TIER 1 — BREAKS THE ILLUSION ON SIGHT (do these first)
1. **Mortar pits are untextured white boxes.** (item 13) Texture pass. Also reposition —
   they currently intersect the dirt mounds.
2. ~~**Medical tent is see-through.**~~ (item 26) **DONE** - not backface/normals: the wall-canvas
   and roof-canvas materials sat at alpha 0.30 / 0.12, node-tree AND legacy `diffuse_color`. Fixed in
   commit `b67fda5e`. The rest of item 26 (T-pose, no wounded) was CODE and closed 2026-09-06.
3. **Helmet black spots.** (item 30) Not camo. Present since day one. Atlas/UV defect —
   MEASURE the helmet UV island before touching pixels.
4. **VC face textures too large.** (item 31) Faces blown up. Prior fix was REJECTED for
   guessing — the retry MUST measure the head UV island first.
5. **Floating shells in the artillery gun pits.** (item 16) Placement only.

## TIER 2 — FIREBASE READS AS UNFINISHED
6. **Finish the HQ.** (item 11) Still unbuilt.
7. **Firebase gate.** (item 15) Needs a real rework — it looks bad.
8. **Berms + sandbags around the firebase.** (item 12) Tighten.
9. **Sandbags around the hooches.** (item 17) Same pass.
10. **Kill the weird craters inside the firebase.** (item 14)
11. **Wooden plank walkways.** (item 18) More of them, to tie the map together.
    Caleb's own note: this is the thing that makes the base read as one place.

## TIER 3 — INTERIORS
12. **Chairs don't face the tables** in the hooches. (item 19)
13. **Radio lies wrong on the hooch table.** (item 20)
14. **Every hooch has an identical interior.** (item 21) Needs variants —
    3-4 dressing sets is enough to break the pattern.

## TIER 4 — VILLAGES
15. **Village pass.** (item 32) Animals spawning inside huts, tables intersecting walls,
    NPCs stuck in walls. Layout + collision, not modelling.

## ANIMATION BENCH (blender-overseer, not modelling)
16. **NPC arms clip into their own torsos** on idle. (item 25)
17. ~~**Medical tent units are T-POSED**~~ (item 26) **DONE 2026-09-06 — NO BLENDER WORK NEEDED.**
    "No clips bound at all" was wrong: the GLB carries 13 clips that DO target all seven aid-station
    rigs. The note below was right - it was a CODE binding failure. `_animate_fsb_baked_cast` played
    twelve whole-scene clips at once on twelve players sharing one skeleton set, and every clip keys
    every rig at rest, so the last writer T-posed nine of ten. Probe: `tests/probe_aid_station.tscn`.
18. **No mess hall animations playing.** (item 27)
    NOTE: 17 and 18 may be a CODE binding failure, not missing clips. Check whether the
    clips exist in the library before authoring anything new.

## DO NOT TOUCH
- grunt_*/cap_* meshes. Those ARE the gib meshes. Never strip them.

## NOT ART — leave these to code
Muzzle flash detaching from the gun (29), squad not crouching (28), bunker collision (3),
NPCs falling through ground (4), roof spawns (6), pilots leaving the Huey (5).
