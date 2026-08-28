# PLAYTEST FINDINGS - 2026-08-28

## QUEUE
Ordered. Tag = who does the work. `[x]` = fixed this run (2026-08-28), unverified by you.

**P0 - CRASHES (both fixed, both need your eye)**
1. [x] [CODE] Air support crash. `_danger_close_to_squad` cast a freed squad member. Fixed + `members` now self-prunes.
2. [x] [CODE] Gun crew crash. Promoted garrison man was queue_free'd but left in `_members`. Fixed at the node's own exit.

**P1 - BLOCKS THE SIEGE RUN**
3. [ ] [SCENE-LAYOUT] Bunker collision - cannot enter ANY bunker. Collider shape/layer on the fsb bunker mesh.
4. [ ] [CODE] NPCs fall through the ground (burn ground, Huey dismount). Spawn/dismount height authority.
5. [ ] [CODE] Huey pilots leave the aircraft; empty Huey flies off. Pilots must be exempt from the disembark set.
6. [ ] [CODE] NPC squads spawn on the hooch ROOF. Same class as 4 - top-down ray vs authored floor_y.
7. [x] [CODE] Map screen fired the weapon on click. Map now declares itself a menu; trigger/grenade/knife/medkit all gated.
8. [ ] [CODE] Own squad opened fire inside the wire with no enemy. Needs a repro + a target-acquisition trace.
34. [x] [CODE] Pause menu - built (ESC). RESUME / QUIT TO DESKTOP.

**P2 - MISSION LEGIBILITY (your two questions)**
Q2/NEW. [ ] [CODE] **A sweep only banks when you re-enter the wire** (`field_director.gd:1821 _bank_patrol`). Nothing in the field ever tells you the objective is satisfied - the route report is cosmetic and prints only after you are home. You did the mission; the game never said so. Needs a field-side acknowledgement.
Q1/24. [ ] [CODE] `WorkingPointResolver.resolve()` (`working_point_resolver.gd:20-28`) drops any working point whose NodePath misses, or whose site dict has no `root`, on a bare `continue` with no warning. Prime suspect for "far under 75% of place-nodes fire" AND for NPCs sitting where there is nothing to sit on. Probe first: count dropped vs resolved.
24. [ ] [CODE] Work markers need an ACTIVITY TYPE so a man only plays a clip the marker can support.

**P3 - SYSTEMS / UX**
9.  [x] [CODE] Satchel now sets a charge on a 30-second fuse with the count on the HUD. Mouth de-registers on set, so nobody drops down a lit hole.
10. [ ] [CODE] Post-satchel orange blow-out + scorch decal flip-flopping between two states on movement.
28. [ ] [CODE] Squad does not crouch when you crouch, and stands on top of you.
29. [ ] [CODE] Squadmate muzzle flash detaches from the muzzle (socket offset).
33. [ ] [CODE] Friendly-unit warning before you fire.
22. [ ] [CODE] Squad struggles to path into the hooches (navmesh at the doorways).
35. [?] [DESIGN-CALL-CALEB] Real convoy that forms up and drives out. Big; not launch scope unless you say so.
23. [?] [DESIGN-CALL-CALEB] Player locker with one universal inventory pool across all lockers.

**P4 - ART / LAYOUT (no Blender this run - queued only)**
16. [ ] [SCENE-LAYOUT] Artillery pits: floating shells, and nobody mans the gun. *(Half of this was code: `_capture()` never appended the man to `_captured`, so the whole crew performance was dead at runtime. Fixed. The floating shells are still layout.)*
13. [ ] [BLENDER] Mortar pits are untextured white boxes, badly placed into the dirt mounds.
11. [ ] [BLENDER] Finish the HQ.
15. [ ] [BLENDER] Firebase gate rework.
12. [ ] [SCENE-LAYOUT] Tighten berms + sandbags around the firebase.
17. [ ] [SCENE-LAYOUT] Sandbags around the hooches.
14. [ ] [SCENE-LAYOUT] No more weird craters inside the firebase.
18. [ ] [SCENE-LAYOUT] More wooden plank walkways to tie the map together.
26. [ ] [SCENE-LAYOUT]+[CODE] Medical tent: see-through, everyone T-posed, no wounded. Whole tent needs setting up.
19. [ ] [SCENE-LAYOUT] Chairs not facing tables.
20. [ ] [SCENE-LAYOUT] Radio lies wrong on the table.
21. [ ] [SCENE-LAYOUT] Every hooch has the identical interior - randomize.
32. [ ] [SCENE-LAYOUT] Villages: animals inside huts, tables through walls, NPCs stuck in walls.
30. [ ] [BLENDER] Helmets still have black spots instead of camo.
31. [ ] [BLENDER] VC faces blown up too large. MEASURE the head UV island first (the last attempt was rejected for guessing).
25. [ ] [BLENDER] NPC arms clip into their own bodies on idles.
27. [ ] [BLENDER] Mess hall animations not playing.

---

## SOURCE NOTES — (Caleb, demo runs the night of 8/27)

Source: Caleb's spoken notes, ~3 pages. Never reached the siege — blocked by the crashes below.
Status legend: [ ] open · [x] fixed · [?] needs his call

## A. CRASHES — game-breaking, top of queue
1. [x] **Air support crash.** Called air support → crash. Errors: `radio net field director danger close to squad`, **"trying to call freed object"**. Ambient napalm ray was firing at the same time nearby — possible interaction.
2. [x] **Gun crew crash.** `Invalid Node3D` in gun-crew performance code. Happened while a mortar round was impacting the base.

## B. BLOCKERS / BROKEN GAMEPLAY
3. [ ] **Bunker collision is off** — player cannot enter ANY bunker.
4. [ ] **NPCs falling through the ground** — through the firebase burn ground; Huey passengers falling through on dismount. Some walked fine, some fell.
5. [ ] **Huey pilots leave the aircraft.** Pilots + all pax got out and ran away; the empty Huey then flew off. Pilots must stay in the Huey.
6. [ ] **All NPC squads spawn on the roof of their hooch.** (Known, still live.)
7. [x] **Map screen still fires the weapon** on click. Disconnect fire input while the map is open.
8. [ ] **Own squad opened fire inside the firebase** with no visible enemy — unexplained.
9. [x] **Satchel on tunnel = no timer.** Detonates instantly and kills the squad. Needs a 30-second on-screen countdown.
10. [ ] **Post-satchel visual glitch.** After the tunnel blew, the scene went orange/blown-out; on movement the scorch decal shrank to a tiny hole and lighting lightened — then flip-flopped between the two states continuously.

## C. QUESTIONS FROM CALEB (answer, don't file)
- Q1. **When do NPCs start their routines?** He expected ~75% of place-nodes to be working.
- Q2. **What makes a sweep mission complete?** He believes he did what was asked; it never registered as finished.

## D. FIREBASE — build & layout
11. [ ] **Finish the HQ.** (Unbuilt.)
12. [ ] **Tighten berms + sandbags around the firebase.**
13. [ ] **Mortar pits are untextured white boxes**, and are placed badly — intersecting the dirt mounds.
14. [ ] **No more weird craters in the firebase.**
15. [ ] **Firebase gate** needs rework — must look better.
16. [ ] **Artillery gun pits: floating shells everywhere**, and nobody ever manned the gun.
17. [ ] **Sandbags around the hooches** need fixing.
18. [ ] Add **more wooden plank walkways** around the map to tie it together.

## E. HOOCH INTERIORS
19. [ ] **Chairs not facing tables** — interior furniture orientation wrong.
20. [ ] **Radio lies wrong on the table.**
21. [ ] **Every hooch has the identical interior** — needs randomization.
22. [ ] **Squad struggles to path into the hooches.**
23. [?] **IDEA — player locker.** Give the player a locker in the hooches; any locker is accessible and shares one universal inventory pool.

## F. AI / ANIMATION / ROUTINES
24. [ ] **NPCs sit where there is nowhere to sit** at work markers. Work markers need to be specific about which activity is legal at each one (incl. leisure activities).
25. [ ] **NPC arms clip into their own bodies** during idle animations.
26. [ ] **Medical tent is completely see-through**; all units inside are **T-posed**, no animations, and no wounded/dead present. Whole tent needs setting up properly.
27. [ ] **No mess hall animations** playing.
28. [ ] **Squad AI does not crouch when the player crouches**, and mostly stands right on top of the player.
29. [ ] **Muzzle flash detaches from the gun** on squadmates' weapons — appears offset away from the muzzle.

## G. ART / TEXTURE DEFECTS
30. [ ] **Helmets still have black spots** — not camo. Consistent defect since day one.
31. [ ] **VC face textures wrong** — faces blown up too large, need shrinking. (See prior rejected fix: measure the head UV island.)

## H. VILLAGES
32. [ ] Villages need tightening: **animals inside huts**, **tables intersecting walls**, **NPCs stuck inside walls**.

## I. SYSTEMS / UX
33. [ ] **Warn the player about friendly units** (friendly-fire warning).
34. [x] **Pause menu for the demo** — does not exist.
35. [?] **Real convoy** that links up and drives out of the firebase. Caleb: "would be huge."

## J. CONFIRMED WORKING
- Squad follows the player.
- Squad teleport/catch-up works better now.
