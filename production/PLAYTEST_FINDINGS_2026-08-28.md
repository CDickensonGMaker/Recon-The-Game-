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
8. [~] [CODE] Own squad opened fire inside the wire with no enemy. **HIS HYPOTHESIS, 2026-08-28 (logged, NOT built against):** *"im assuming the squad firing in the firebase was enemies maybe underneath the berm cuz i saw nva falling thru the berm earlier."* If that is right this is **item 4, not an AI bug** - NVA under the terrain, and the squad correctly engaging an enemy it can see through the ground. It also implicates the sight system (`scripts/ai/sight_cap.gd`) not testing terrain occlusion. **What is measured so far:** the whole compound floor is ONE concave collider (demo boot prints `[FSB] kept 1 mound collider(s) - the MODEL is the ground`), it is authored ONE-SIDED and is patched at runtime by `site_planner._force_backface_collision` (`site_planner.gd:1567-1583` - the shipped GLB winds inward, verified 2026-08-02), and the same boot reports `1441 collider(s) floating >3m off the ground`. That is the right neighbourhood for a body falling through. Leave for the collision pass; do not "fix" the squad AI.
34. [x] [CODE] **PAUSE MENU - FIXED AND MEASURED, 2026-08-28.** His repro: *"when i pause in the demo, i dont see any menu i just get a paused screen with a image of a soldier in the river. but no options, save, load, exit etc."* **`tests/probe_pause_menu.tscn` builds the real menu the way `GameFlow._open_pause` does and prints every control global rect. Before: the PanelContainer came back at `(-190, -180)` size 362x362 on a 1280x720 viewport - off the top-left corner. After: `(459, 179)`, fully on screen.** ROOT CAUSE: `Control.position` is PARENT-relative, not anchor-relative, so `panel.position = Vector2(-190, -180)` after `set_anchors_preset(PRESET_CENTER)` CANCELS the preset. The identical pattern reads as centred all over the HUD only because those controls are positioned while their parent is still zero-sized. The panel now sits in a full-rect `CenterContainer`, which cannot drift. Also repaired: a mangled `_ready()` had swallowed the `CursorSet.hook_buttons` call (comments and blank lines do not close an indented block), so it ran before a single button existed - it is now the last line of `build()`. **This was never demo-only: the campaign pause menu was equally off-screen and nobody had looked.** *(Original note follows.)* **Pause menu - the 8/27 "fix" was a second PauseMenu class and it BROKE THE BOOT.** A full pause screen already existed (`scripts/ui/screens/pause_menu.gd`: RESUME / BARRACKS / ABANDON / RESTART DAY, wired to ESC at `game_flow.gd:54-60`). Last run added a rival `scripts/ui/pause_menu.gd` with the same `class_name PauseMenu`; the headless boot reported `Parse Error: Class "PauseMenu" hides a global script class` and every dependent script - `player.gd`, `squad_system.gd`, `game_flow.gd`, `mission_hud.gd` - failed to compile. **The duplicate is deleted** (fossil law), QUIT TO DESKTOP is added to the one real menu, and boot is now clean. **Why the real menu did not appear in your playtest is still undiagnosed** - it needs a repro, and it is NOT closed.

**P2 - MISSION LEGIBILITY (your two questions)**
Q2/NEW. [x] [CODE] **A sweep now finishes IN THE FIELD** - your ruling, built. Killing the enemies at the location, closing the tunnel, or stripping the stash ends that sweep on the spot; your point man calls it whether or not the radio works, the map takes a dated SWEPT mark, and over a live net Six OFFERS the next place by bearing and distance with "OR BRING THEM IN. YOUR CALL." No pin, nothing ticks off, and walking home is still legal. `_bank_patrol()` is untouched and still the one AAR at the wire - a walk-out can finish many sweeps and banks exactly once. (`field_director.gd` `_poll_sweep` / `_finish_sweep` / `_set_patrol_location`.)
Q2b. [x] [CODE] **The surface stash can be blown up - your ruling, built.** `place_structure` now builds `weapons_cache` AS a `Destructible` (HP 80 - one satchel, one LAW, or a grenade placed right; blast `explosion_mortar`, because a stash going up is the ordnance cooking off), registers it on the blast bus, and on death it calls `report_stash_cleared` - so destroying the surface stash FINISHES A SWEEP exactly the way stripping the tunnel cache does. Proved by `tests/probe_surface_cache.tscn`. **NEW HOLE FOUND WHILE IN THERE - logged, not silently widened:** the village huts placed by this same function are ALSO not destructible. `nha_tranh_` / `nha_san_` / `nha_ruong_` are listed in `site_planner.FSB_STRUCTURE_KINDS`, but that list is only ever walked by `_wire_structure_destructibles`, which runs on the FIREBASE GLB and never on the AO. Every hut in every village is indestructible today.
Q1/24. **REFUTED BY MEASUREMENT, 2026-08-28.** The resolver is not the culprit. Instrumented `WorkingPointResolver.resolve()` with a drop ledger and booted the demo world headless: **`[WORKPOINTS] offered 0, resolved 0 - dropped: 0 of every kind`**. Nothing is dropped because **nothing is ever offered**: `working_points` is written in exactly one place, `mission_generator.gd:547`, and that line lives in `plan_patrol_world` - the open-patrol world that is deferred post-launch. `plan_demo_world` never writes it. In the build that ships, village work targets come only from `work_stations`. The ledger stays in (a drop is now loud and counted) but the under-75% cause is elsewhere - **next probe: the firebase STATION system, which emits no diagnostics at all.**
24. [ ] [CODE] Work markers need an ACTIVITY TYPE so a man only plays a clip the marker can support. Still open, still the likely cause of men sitting on nothing.

**P3 - SYSTEMS / UX**
9.  [x] [CODE] Satchel now sets a charge on a 30-second fuse with the count on the HUD. Mouth de-registers on set, so nobody drops down a lit hole.
10. [ ] [CODE] Post-satchel orange blow-out + scorch decal flip-flopping between two states on movement.
28. [ ] [CODE] Squad does not crouch when you crouch, and stands on top of you.
29. [ ] [CODE] Squadmate muzzle flash detaches from the muzzle (socket offset).
33. [ ] [CODE] Friendly-unit warning before you fire.
22. [ ] [CODE] Squad struggles to path into the hooches (navmesh at the doorways).
35. [PARKED - POST DEMO] Real convoy that forms up and drives out. **Your ruling 2026-08-28: "and same with the convoy."** Build nothing.
23. [PARKED - POST DEMO] Player locker with one universal inventory pool across all lockers. **Your ruling 2026-08-28: "locker should be post demo scope."** Build nothing.

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

## RULED AND BUILT - REPLACEMENTS BY BIRD (Summoner, 2026-08-28)

**His words, verbatim:** *"i like replacements by bird, does the huey come to where the player is?
smallest squad you get handed back is an additional 4 more troops, largest is the full refreshed
squad. game will read the dead roster at the end of the play or something idk. shouldnt be
interupting the game in the moment. surface cache too yes. locker should be post demo scope. and
same with the convoy"*

**OPTION B is law. A and C are dead.** Built this run, unverified by you:

1. **The bird.** `AirTraffic.request_replacement_lift(n)` puts a Huey on the firebase PAD - never
   where you are standing, because `HeliLift.attach` returns null without a firebase and the pad is
   the only place boarding and unloading exist. The men ride in real seats
   (`HeliLift.Mission.REPLACE`, `scripts/vehicles/heli_lift.gd`), doors shut the whole way in, and
   they step off and join the squad at the door. **It does not repurpose the garrison path:**
   replacements are `AllyBase` on your roster, never garrison Civilians, so `garrison_strength()`
   cannot see them and the firebase population is untouched.
2. **THE 4/8 EDGE, and how it resolved.** Four or more holes: the ship brings between 4 men and
   enough to refresh you to 8 (seeded off banked campaign facts, ADR-010 - the same wipe always
   sends the same men). **Fewer than four holes: it brings all of them.** You cannot hand a man a
   seat that does not exist, and holding the sortie until the hole is "worth flying" would leave
   you permanently at 7 with the game refusing to say why. One constant governs the whole band -
   `FieldDirector.REPLACEMENT_FLOOR`. Measured over every case by
   `tests/probe_replacement_bird.tscn`; your case - two men left, six holes - hands back five.
3. **The dead are read at the end of play, never in the moment.** No popup, no mid-mission screen.
   Names are spoken at the wire on the patrol bank (`_read_the_dead`), AND at dawn when a siege
   ends - because `_bank_patrol` only fires on crossing the wire INWARD, and in the demo the siege
   IS the day, so without that second hook the whole loop was unreachable in the build that ships.
   A man is named exactly once. The AAR screen (`scripts/ui/screens/debrief.gd`) now carries the
   full butcher's bill: the dead by name, squad strength, and the KIA / ward / bags counters that
   have lived in `CampaignState` since 2026-07-30 and were **displayed nowhere**.
4. **THE FREE REFILL IS DEAD.** `SquadRoster.ensure_roster` manufactured a full squad every time it
   ran, and `barracks.gd:50` ran it ON A UI REPAINT - opening the roster board minted men and wrote
   them to disk. It now manufactures in exactly one case: an EMPTY roster, which is a new tour.
   Every man after that arrives on a bird. The board REPORTS - strength, KIA, ward, and how many
   slots are open - and fills nothing.

**REACHABILITY IN THE DEMO - honest answer.** `demo_game.gd:111` resets the campaign at boot, so
there is no next morning and the roster starts empty: you are handed a full squad, correctly.
Because of the siege hook above, **the bird IS reachable in the shipping demo** - lose men in the
night assault and the lift comes at dawn. But `EXCLUDE_DEBRIEF` is still `true`
(`demo_game.gd:26`), so **in the demo you get the names as radio traffic, not the AAR screen.** The
full butcher's-bill panel appears only in the campaign.

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
