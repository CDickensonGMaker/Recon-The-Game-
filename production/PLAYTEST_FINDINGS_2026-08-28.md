# PLAYTEST FINDINGS - 2026-08-28

## QUEUE
Ordered. Tag = who does the work. `[x]` = fixed this run (2026-08-28), unverified by you.

**P0 - CRASHES (both fixed, both need your eye)**
1. [x] [CODE] Air support crash. `_danger_close_to_squad` cast a freed squad member. Fixed + `members` now self-prunes.
2. [x] [CODE] Gun crew crash. Promoted garrison man was queue_free'd but left in `_members`. Fixed at the node's own exit.

**BOMBING RAID LAG - FIXED AND MEASURED 2026-08-31, NEEDS YOUR EYE**
R1. [x] [CODE] **"Did we de-lag the bombing raids?" - we had not, and now we have.** The raid had
never been benched on its own: FIRES always ran on top of WAVE, so the 8/14 "air-support stutter
KILLED" record was a claim no probe had made (both stale lines corrected - `DEMO_SHIP_BACKLOG.md`
and `WHEN_YOU_RETURN_2026-08-15.md`). Benched alone, the raid's real cost was **~121 ms in one
frame on the FIRST bomb of a mission** - `GunFX`'s FX material/texture caches build lazily on first
use, and `FireHazard` pulls sheets the explosion path does not, so the first napalm canister paid
both while every canister after it was free. Second, **4.2 ms avg / 8.5 ms max per CBU dispenser**
spent birthing 16 bomblets in a single call. Fixed: warm the caches at world build
(`game_world.gd:56-57`), and spread the bomblet births 4 per frame
(`cas_airplane.gd` `BOMBLETS_PER_FRAME`). Measured before -> after: first-raid cold **121.5 -> 14.6 ms**,
dispenser worst single-frame block **4.57 -> 1.16 ms avg, 8.52 -> 2.11 ms max**, and **16 bomblets
born before AND after** (frame shape `16` -> `4/4/4/4`) so nothing was thinned. `NAPALM_STAGGER` /
`CBU_STAGGER` untouched. **REFUTED in passing:** the blast loop and its 8 raycasts per body, blamed
earlier the same day on inspection alone, measures 0.07-0.14 ms per call - it was never the spike.
Numbers and the full method: `PERF_LEDGER.md` 2026-08-31. **What is NOT proven: this is headless CPU
truth. Call a napalm run and a CBU run in the demo and tell me whether the first strike still hitches
- that is the only thing that closes this.**

**P1 - BLOCKS THE SIEGE RUN**

> **COLLISION PASS - FIRST MEASUREMENT, 2026-08-30. THE "1441 FLOATING COLLIDERS" NUMBER IS NOT
> A LEAD; IT WAS A BROKEN INSTRUMENT.** `site_planner._audit_floating_colliders` measured
> `shape_bottom - terrain.get_height_at()`. But **inside the firebase the MODEL is the ground** -
> the same boot prints `kept 1 mound collider(s) - the MODEL is the ground` and `terrain sits
> under the model everywhere (worst +0.00m)`, and fsb_main_v3 is authored with y=0 at the mound
> TOE rising to 14.5m. So every bunker, gun and prop **correctly standing on the compound floor**
> was counted as airborne, along with ceiling bulbs that belong up there. Composition, measured:
> `fb=636, fb_int=277, m101=141, MC=139, StaticBody3D=96, grunt=32, OFF0/1/2=30 each, PSXRig=12`;
> the worst offenders are hanging bulbs (+7.8m) and the medical-tent casualty figures' gib parts
> (+6.8m). **The line now says what it actually measures** (`>3m above the TERRAIN HEIGHTMAP -
> not above their own floor`) and prints the family histogram, so the number can never be
> misread as a bug count again. A TRUE datum needs a downward cast from each shape's bottom, and
> that cannot be fired at this callsite: a body added this frame is not in the physics space
> until the next physics step (the trap `game_flow.gd:647` documents), so the cast hits nothing
> and returns the terrain delta anyway - **tried and measured this run: 1417 of 1441 unchanged**,
> and deferring the audit behind `await physics_frame` made it print nothing at all. **Moving
> this audit to a post-physics callsite is task one of the collision pass.**
>
> **THE HEIGHT AUTHORITY FOR ITEMS 4 AND 6 IS ALREADY CORRECT - THE QUESTION IS WHO USES IT.**
> `GameWorld.floor_y()` (`scripts/levels/game_world.gd:442`) probes a SHORT reach from just above
> the caller's known Y. `GameWorld.surface_y()` (`:404`) fires an 18m ray from above and takes the
> FIRST hit - **which is the ROOF over any covered point.** Its own comment records that this is
> exactly what stood the garrison and the whole squad on the rooftops in your 2026-08-04 playtest
> (authored markers sit 2.8-3.2m above their floor, the hootch roof at 2.88m). Items 4 and 6 are
> the same bug class: a caller using `surface_y` or raw `get_height_at` where it needs `floor_y`.
> **Not yet triaged, named so the next run starts here:** `marching_cell.gd:242`,
> `squad_system.gd:322`, `litter_team.gd:172`, `air_traffic.gd:520` (`_ground_at`).
> **The pass was NOT started beyond this measurement.**

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

## REVERSED 2026-08-30 - SLEEP IS POST-LAUNCH. THE SECTION BELOW IS HISTORY, NOT LAW.

**His words, verbatim (2026-08-30):** *"lets have the sleep be a post launch idea"*

**BINDING. The sleeping mechanic is POST-LAUNCH. It is not a demo feature and it is not a launch
feature.** His 2026-07-30 sleep-loop decree AND its 2026-08-28 amendment (below) now BOTH read
POST-LAUNCH. Recorded in the scope table at `production/GAME_GUIDE.md` (PARKED row) so a future
session cannot resurrect it as launch scope.

**NOT REVERTED - PARKED DORMANT.** Ripping fc1af4c0 out would take two genuine fixes with it: the
night roll that a clock jump would have skipped (`SiegeDirector.roll_night_for_sleep`) and the
`WeaponHolder.session_shots/hits` reset at the bank. The machinery stays built and probed and
thaws on **one const**:

> `FieldDirector.SLEEP_POST_LAUNCH` — `scripts/missions/field_director.gd`

While it is `true`: the rack offers **no verb at all** (`sleep_station.gd` `prompt()` returns "",
`refusal()` returns "NOT YET"), the wire crossing banks the run again, and the dead are read
where they were read before 8/28. There is no second switch anywhere.

### WHERE THE DEAD ARE READ - MEASURED, not reasoned (`tests/probe_the_reading.tscn`)

The 8/28 change moved the naming ceremony INTO the sleep screen and narrowed the dawn read to
`GameFlow.demo_mode`. With sleep parked that would have left **the campaign banking nothing and
naming nobody** - a silent regression against your own 8/28 ruling *"game will read the dead
roster at the end of the play."* Restored and proven:

| Path | Where the dead are read | Measured |
|---|---|---|
| **DEMO** | dawn, when the siege ends (`_on_siege_ended`) | `siege end named ["CPL VOSS"], repeat named []` |
| **CAMPAIGN** | the wire bank (`_poll_wire_gate` inbound -> `_bank_patrol`) | `wire-inward named ["PFC HALVORSEN", "SGT REYES"] (banked=true), second crossing named []` |
| **POST-LAUNCH** | the sleep screen takes it over on the const flip | rack today: `prompt="", refusal="NOT YET", can_sleep=false` while standing on it |

**Exactly one reading per path, and a man is named exactly once** - `_dead_read` dedupes, which is
what the empty "repeat"/"second crossing" columns prove.

**THE sim_day/sim_hour SAVE GAP IS NOW POST-LAUNCH ONLY.** The tour clock is absent from the
campaign save, but nothing on the launch path renders a day number to the player - `sim_day` is
read only by schedulers (`air_traffic.gd:598`, `convoy_spawner.gd:68`, `siege_director.gd:173`)
and by a demo debug print. Sleep was the thing that would have made the calendar player-facing.
**Not fixed, deliberately. It thaws with sleep.**

---

## HISTORY - RULED AND BUILT, SLEEP ENDS THE RUN (Summoner, 2026-08-28; REVERSED 8/30 above)

**His words, verbatim:** *"i think we add the sleeping mechanic and thats how you finish a run
or something and during the sleep part is when we get read off the names of those who died.
that way were keeping the player from potentially being attacked and its stopping them to read
off names. that makes more sense. so looking at the catacombs of gore game we use the same idea
at really any hooch or should we make a player specific hooch (which again can lead to post demo
launch work of making more earnable customized hooch items)"*

**COUNCIL VERDICT ON HIS OPEN QUESTION: PLAYER-SPECIFIC. One authored rack, `spawn_bunk_01`.**
Both lenses landed there independently. The measured case against "any hooch": `game_flow.gd`'s
own comments record that the `prop_sleep` pool contains **village cots 142m OUTSIDE the wire**
(the nearest-to-centre sort exists only to stop one winning) and that **8 hooch visuals stand
against 4 `-colonly` bodies** - so a verb offered on all 68 cots drops him through the floor on
half of them and lets him bank a patrol from inside a VC village. It also cannot carry the
earnable decor he wants post-demo: you cannot earn a poncho liner for "any hooch."
The UX lens named the image that decides it: **the names are read while he lies in a room of
empty cots that belonged to the men being named.** Nothing else in the build delivers Pillar 4
by geometry. **Named tradeoff, taken:** the cross-compound walk at 04:00, wounded, to end a run -
and it is the walk through the densest space in the game, which is the atmosphere argument.
**Rejected on his behalf:** a player *room*. One of six identical racks, not officer's quarters.

**FOR HIM, POST-DEMO (not built, per his own scope):** the squad hooch, six racks, his among
them, the others emptying as men die; the parked player locker (item 23) belongs at the foot of
this rack; a "rack anywhere" lesser verb that passes time but banks nothing, so a wrecked hooch
can never lock him out of ending a run.

**BUILT THIS RUN, unverified by you:**

1. **The verb.** `[HOLD F] SACK OUT - ENDS THE PATROL` at his rack (`scripts/world/sleep_station.gd`,
   wired at `player.gd` `_tick_sleep_hold` / `field_interact_prompt`). HOLD, never tap - an
   accidental tap that ends a run is the worst defect this verb could ship. It **refuses with a
   reason** rather than going dead: not on the wire during a siege, not outside the wire, not
   downed, not with enemy inside 90m.
2. **The ceremony** (`scripts/ui/screens/sleep_screen.gd`). Black, then the roll call of the dead
   by name, then the butcher's bill, then the night. Nothing can shoot him and he cannot walk
   away - `GameManager.is_in_menu` gates the player's whole `_physics_process` and `_input`.
   **It is not a cutscene and neither is the wake:** control returns with the black.
3. **THE DEAD ARE READ IN EXACTLY ONE PLACE.** The radio-traffic reading shipped in 39d61ce0 at
   the wire is gone; `_read_the_dead` now has a quiet mode so the sleep screen renders the names
   itself. `_on_siege_ended`'s dawn reading is **narrowed to `GameFlow.demo_mode`** - the demo's
   authored one-day arc has no night to rack out into, and without it the whole replacement loop
   is unreachable in the build that ships. In the campaign, sleep owns the ceremony outright.
4. **Sleep drives `_bank_patrol` - it was not rebuilt.** Crossing the wire inward no longer banks;
   it ends the excursion and sets `_patrol_pending`. **The phantom-bank guard:** a man who never
   left his cot banks nothing by lying down twice (measured).
5. **The night roll is asked at the moment he lies down** (`SiegeDirector.roll_night_for_sleep`) -
   same NIGHT_CHANCE table, same earned threat tier, same MAX_RUN_NIGHTS chain. This closes the
   hole the council found: a clock JUMP skips the `is_night` poll entirely, so a naive sleep would
   have made the whole ADR-035 night assault opt-out by going to bed at dusk. On a hit the clock
   moves only 3.5h and he is **shaken awake at his own bunk, in the dark, siren going**; on a miss
   the full 8 hours and a morning. Existing beats reused, not rebuilt: `_garrison_stand_to`,
   `SirenTower`/`_sound_siren`, the STAND TO toast, the ranging mortars that start at zero.
6. **`SimClock.sleep_advance()`** - a sleep is a JUMP, not a fast-forward. It emits
   `time_period_changed` (MissionWeather listens on that signal alone, so a jump without it would
   leave the sun where he lay down) and it **burns** the bookings slept through instead of firing
   a night's worth of airframes in one frame.
7. **Sleep costs something.** He wakes hungry (`SLEEP_HUNGER_COST`). Otherwise it handed out a
   bank, a rank, a replacement lift and a fresh fire-support day for free.
8. **Found and corrected in passing (NO MORE DRIFT):** `WeaponHolder.session_shots/hits` were
   never reset at a bank, so every accuracy figure after the first was the tour's, not the
   patrol's. Fixed at `_bank_patrol`. The bank toast no longer says "BACK INSIDE THE WIRE" - it
   fires at a bunk now.

**THE FORCED DEMO SIEGE TIMER IS *NOT* RETIRED, AND SHOULD NOT BE.** The "720s wall-clock timer"
in the standing record is **stale**: `demo_game.gd` runs an authored ONE-DAY arc at
`PROBE_AT_S 1395` / `SIEGE_AT_S 1440` / `END_BACKSTOP_S 2700`, ratified by the War Room of
2026-08-03 and your own 2026-08-07 ruling that the raid ends the demo, not a stopwatch. That arc
IS the shipping demo and it is the standing session entry gate. Sleep is deliberately **refused
in demo mode** (`"[F] NOT TONIGHT - THE DAY ISN'T DONE"`): the demo arc runs on accumulated REAL
seconds, which a sim-clock jump cannot move, and a jump there would only desync the beats and
re-arm the fire-support allotment the 20x night was bought to protect. **What sleep retires is
the NEED for a forced timer in the campaign** - `SiegeDirector._maybe_open`'s per-night roll was
unreachable because nothing ever made the player present at night, and now something does.
**YOUR CALL if you want it in the demo:** it is one line in `sleep_station.gd:refusal()`.

**PROOF:** `tests/probe_sleep_loop.tscn` - PASS on all three (clock lands 21:00 d3 +8h -> 05:00 d4
with DAWN emitted; 3 bookings in the slept window fire 0 times and stay burned; no walk-out means
no night, two sleeps bank nothing, MAX_RUN_NIGHTS refuses). Headless boot of the demo scene:
**0 SCRIPT ERROR, 0 Parse Error**, `[SPAWN] authored bunk marker at (254.39, 177.64, 288.10)
(2 placed, 32m from fsb centre)`.

**STILL OPEN, named not buried:** the tour clock (`sim_day`/`sim_hour`) is not in the campaign
save, so sleep makes the calendar player-facing for the first time and a save/reload resets it.
`SimClock.set_time` still does not emit `time_period_changed` (the demo boot depends on that);
only `sleep_advance` does.

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
