# ART WORKLIST — from the 8/27 playtest
Caleb's own bench. Code items stripped out; this is Blender / texture / scene-layout only.
Source: production/PLAYTEST_FINDINGS_2026-08-28.md

## TIER 1 — BREAKS THE ILLUSION ON SIGHT (do these first)
1. **Mortar pits are untextured white boxes.** (item 13) Texture pass. Also reposition —
   they currently intersect the dirt mounds.
2. **Medical tent is see-through.** (item 26) Backface/normals or a missing material on the
   canvas. Nothing else in the tent matters until you can't see through it.
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
17. **Medical tent units are T-POSED** — no clips bound at all. (item 26)
18. **No mess hall animations playing.** (item 27)
    NOTE: 17 and 18 may be a CODE binding failure, not missing clips. Check whether the
    clips exist in the library before authoring anything new.

## DO NOT TOUCH
- grunt_*/cap_* meshes. Those ARE the gib meshes. Never strip them.

## NOT ART — leave these to code
Muzzle flash detaching from the gun (29), squad not crouching (28), bunker collision (3),
NPCs falling through ground (4), roof spawns (6), pilots leaving the Huey (5).
