# CALEB'S LIST — everything on YOUR plate (2026-07-10)

Everything code-side is built or tracked here; this is the hands-on Blender/eyes work only you can do,
roughly in dependency order. Companion: `BLENDER_ASSET_LIST.md` (full asset detail).

## 000. SPAWN-UNDER-FIREBASE — hardened 2026-07-30, still needs your eyes

You reported spawning under the firebase in the main game despite two authored `spawn_bunk` markers
by a hooch (`scenes/world/firebase_main.tscn`), and ruled: **regardless of seed, the firebase needs a
flat area that seats it properly — that shouldn't depend on luck.**

**Done:** `plan_firebase_main_center()` (`scripts/world/site_planner.gd`) now scores the FULL 7x7
footprint height range for every candidate site, not just the 6 clear-disc centers — flatness now
dominates the site pick, seed-independent. This is a real hardening fix for the general problem, not
a targeted patch.

**Not yet confirmed fixed:** your default seed (47225) was already documented in the code's own history
as the "lucky, flat" case — so this hardening may not be what's actually causing today's specific bug.
More likely cause: the two `spawn_bunk` markers were placed/eyeballed while testing the **demo** build
(seed 29072026, 512m map), and the main game boots a different seed/location where the mesh floor
under them sits differently. **Please check in-editor**: load the MAIN (non-demo) game, walk to the
hooch, and see if the mesh floor there is higher than where the markers sit. If so it's a marker-height
nudge, not a further code fix.

**UPDATE 2026-07-30, same thread:** you asked whether the fix needs to be world-agnostic since every
player gets a different generated world. Answer: for THIS bug specifically, no — the firebase model
(hooch, floor, roof, the two markers) is a fixed asset that moves as one rigid block every time; only
its overall placement varies per seed, never its internal geometry. So the marker's height relative to
the hooch floor is constant across every player's world, and a one-time nudge in `firebase_main.tscn`
fixes it permanently everywhere. I almost "fixed" this with a runtime raycast instead, but reverted it
— probing down from above an INTERIOR authored point risks hitting the hooch ROOF first, not the floor
(a failure mode this codebase already hit and documented at `game_world.gd:426-428`, which is why
`spawn_player_at`'s `seat_on_surface=false` path exists and deliberately skips raycasting for exactly
this case). The seed-VARYING part of this problem is the terrain seam at the model's edge, which the
flatness-scoring fix above already covers. No code changes needed for the interior spawn itself — just
your marker-height check.

**ACTUAL ROOT CAUSE FOUND 2026-07-30:** you reported the main game buries the player, squad, AND
garrison allies, while demo doesn't. Traced it — squad (`squad_system.gd:73`) and garrison
(`mission_generator.gd:911`) were already correctly using the safe `world.surface_y()` seat (fixed in
an earlier session for this exact bug class). The PLAYER wasn't: `game_flow.gd`'s `enter_hub()` had an
unconditional re-seat right after `spawn_player_at()` placed him correctly, using bare
`terrain_manager.get_height_at()` instead of `surface_y()` — it ran on EVERY boot regardless of
whether a save was actually being restored, clobbering the correct bunk-marker seat a few frames later
with the exact "buries anyone inside the firebase" height. **Fixed**: swapped to `surface_y()`, matching
squad/garrison. Also added a `push_warning` in `surface_y()` itself (`game_world.gd`) for the case
where its own raycast finds nothing and silently falls back to bare terrain height — that fallback was
invisible before; now your console will show it if it ever happens to squad or garrison too.

**STILL BROKEN after that fix — you confirmed still spawning below the firebase.** Ran a proper
3-way parallel investigation instead of guessing again (every write to player Y, a full demo-vs-main
boot diff, and a firebase-collider/physics-timing check). Found two more real bugs, both fixed
2026-07-30:

1. **A second, untouched reseat loop** — `game_world.gd:_physics_process()`, runs every ~2 seconds
   for the entire life of the world, was STILL using raw `terrain_manager.get_height_at()` (the same
   bug class as the one already fixed in `enter_hub()`, just a second occurrence in a different
   file, missed the first time). Per the "ONE GROUND" ruling, terrain under the firebase sits at the
   mound's TOE, well below the real interior floor — so if the player ever fell too far, this
   "safety net" would catch him and permanently replant him at toe height instead of the real floor,
   which reads exactly as "spawned below the firebase" even after the one-time enter_hub fix (that
   fix only touches the SPAWN MOMENT, never this ongoing loop). **Fixed**: swapped to `surface_y()`.

2. **A real physics race**, confirmed by grep (zero `await`/`process_frame` calls anywhere in the
   chain): the firebase's own colliders (its baked mound/floor body, remeshed vegetation/parapet
   trimeshes) get added via `add_child()` in `build_patrol_world()`, and the very next thing that
   happens is the `surface_y()` raycasts that seat the player/squad/garrison — same frame, no yield.
   Godot's `PhysicsServer3D` doesn't guarantee a just-added collider is raycast-queryable until the
   next physics step, so that first raycast could miss the firebase's own floor entirely and fall
   through to whatever terrain WAS already registered. **Fixed**: added two `await get_tree().
   physics_frame` yields in `enter_hub()` right after `build_patrol_world()` returns, before any
   seating happens, with the existing re-entrancy guard re-checked after each.

Full reasoning and the 3-agent findings are in the approved plan at
`~/.claude/plans/abstract-giggling-pike.md`.

**STILL BROKEN — but now we have proof of the actual cause, from your console log (2026-07-30).**
Both fixes above are real and correct but insufficient, because the problem was never the seating
*logic* — it's that **there is no collider at all under the interior floor near the hooch spawn
markers.** Evidence, straight from your log:

```
[SPAWN-TRUTH] asked spawn.y=193.56 | surface_y(spawn) now=189.18 | player landed at y=194.56 | seated=false
[SPAWN-TRUTH] seed=47225 spawn=1021,734 physics_y=189.18 array_y=189.18 delta=-0.00 top_hit=RaycastCollision player_y=190.17
```

The second line is a PRE-EXISTING probe (`game_flow.gd:_report_spawn_truth`, not written tonight)
that fires a single raycast down the ENTIRE column at the spawn XZ, from y=400 to y=-100.
`physics_y` (what it hit) and `array_y` (raw terrain height) are identical — `delta=-0.00` — and the
hit collider's name (`top_hit`) is `RaycastCollision`, the generic name Godot gives a **terrain
chunk's** collision body. That means across that whole 500m vertical probe, the ray hit nothing but
bare terrain — no firebase geometry at all. The marker sits at y=193.56; the only solid thing
registered in the physics world at that XZ is terrain at y=189.18, over 4m below.

**This is not a timing race and not a wrong-height-source bug — both of those are real and are now
fixed, but neither one applies here, because there is nothing to correctly find.** The firebase's
interior floor near this specific hooch has no collision mesh reachable in the running game. No
GDScript reseat/raycast logic can fix that; it needs the collision geometry itself checked.

**Needs your eyes in-editor/Blender, not more code:** open `firebase_main.tscn` (or the source
`fsb_main_v3.glb`/Blender file), select the hooch near the two `spawn_bunk` markers (world XZ
~1021,734 relative to a firebase centered near there — 39m from fsb centre per the `[SPAWN]` log),
and check whether that specific floor section has a collision shape at all. Given `[FSB] kept 1
mound collider(s) - the MODEL is the ground` in the boot log, it's possible the single kept mound
collider covers only the OUTER earthworks and never included this interior floor patch, or this
floor's collider was dropped/miscategorized during export. If you can tell me the mesh name for that
floor patch (or whether it has a collider in Blender at all), I can check whether
`site_planner.gd:_repair_glb_colliders()`'s repair pass is even looking at the right prefix for it —
right now it only touches `fb_terrain_mound` and `fb_veg_`/`fb_sbg_seg_` prefixes, nothing else, so
if the floor uses a different naming pattern it would silently pass through untouched either way.

**CORRECTED 2026-07-30, later same night — the "no collider" read above was wrong. Two real, live
bugs found and fixed, no Blender check needed for this specific cause (may still be worth doing as
a backstop, see below).** Ran a 3-agent read-only investigation instead of guessing again. The
`top_hit=RaycastCollision` in the log above IS the mound/terrain doing its job correctly — the
firebase's own ground-fit step (`site_planner.gd:place_firebase_main`) sculpts and audits terrain
against the mound on every boot ("`[FSB] ground: 129 samples ... worst +0.00m`" — terrain never
pokes through). The player spawns correctly (194.56, matching the 193.56 marker). What actually
drops him ~4.4m is **later terrain modification calls rebuilding the collider under/beside him
after he's already standing there**:

1. `TerrainManager.modify_terrain()` — called by the firebase's own `FSB_CLEAR_DISCS` flatten
   (`site_planner.gd:1037-1051`) and separately by authored "first-sign" craters
   (`terrain/systems/damage_system.gd:185`) — triggers `_rebuild_chunk_immediate()`
   (`terrain_manager.gd:70-85`), which frees the chunk's old collider and adds a new one
   **with no physics-frame guard**. The existing "COLLIDER RACE" fix (`game_flow.gd:600-611`)
   only guards the FIRST placement, before spawn — any later `modify_terrain` call (a crater
   authored moments after boot, near the firebase) is unguarded. Log proof: `[TerrainChunk]
   Chunk (3,3) mesh built` fires repeatedly AFTER both `[SPAWN-TRUTH]` lines — chunk (3,2) sits
   directly under the firebase, (3,3) is the adjacent chunk inside the 215m flatten radius.
   **Fixed**: `game_world.gd:_flush_terrain_dirty()` now re-seats the player (via `surface_y()`)
   immediately if a rebuilt region contains him — same pattern already used there for
   water/gameplay-grid re-seating after a terrain edit.
2. **This is also why your squad ended up UNDER the firebase model.** `TerrainWatchdog`
   (`scripts/missions/terrain_watchdog.gd`) polls `allies`/`enemies`/`civilians` every 2s to catch
   anyone who falls through terrain — but its catch logic used raw `terrain.get_height_at()`, not
   `surface_y()`. Since the mound model sits ABOVE raw terrain by design (one-ground law), the
   watchdog wasn't failing to catch your squad — it was actively "rescuing" them to a height
   BELOW the mound floor, every 2 seconds. **Fixed**: watchdog now takes the `GameWorld` and uses
   `surface_y()` for both its fall-through catch and its resume-from-suspension reseat
   (`mission_generator.gd:836` updated to `watchdog.setup(world)`).

Full reasoning: `~/.claude/plans/why-does-the-demo-fuzzy-narwhal.md`. **Not yet verified in-engine
by you** — please boot the main game, watch the `[SPAWN-TRUTH]` lines and any `[TerrainChunk]
... mesh built` rebuilds after them, and watch the squad for at least one 2s watchdog cycle while
inside the wire. If you STILL see anyone under the model after this, the earlier "check for a
literally-missing collider in Blender near the hooch" step above is the next thing to try — this
fix explains a transient collider swap, not a permanently-absent one, so it's not ruled out, just
no longer the leading theory.

## 0000. VC CAMP DENSITY — bumped 2026-07-30

You said the main AO (1280m, `WorldConfig.MAP_SIZE`) felt too sparse with only 3 VC camps clustered in
a narrow 400-540m ring around the firebase. Bumped to **5 camps** in `mission_generator.gd`
(`CAMP_COUNT`/`CAMP_CAPS`), with the outer band widening per camp (480/540/620/680/720m) instead of
clustering everyone in the same ring — should actually use the back half of the AO now. Garrison/ambush
spawning already loops off `camps.size()`, so nothing else needed to change to support more camps.

## 00. FRANCHISE NAMING — RULED 2026-07-30: "Tour of Hell"

You floated "Hell of Duty: Vietnam" (Hell Let Loose x Call of Duty pun, 90s-underground-comix-homage
spirit) as a ship name and franchise umbrella (Vietnam/Korea/WWI titles sharing TerrainEngine). War
Room flagged tone-mismatch + franchise-scale trademark exposure; you pushed back that a naming pun is
a different animal than Palworld-style mechanical cloning (fair distinction) and independently landed
on an alternative that hits the same tone. **Adopted: "Tour of Hell"** — era-tagged per title
(*Tour of Hell: Vietnam* first, then Korea/WWI). "Tour" is real military vocabulary (tour of duty),
ties to Pillar 4 (the squad rotates home, dies for real), and travels cleanly across all three eras.
Full reasoning: `production/war_room/2026-07-30_franchise_naming/synthesis.md` (pre-pivot; this
entry is the current ruling).

**Project name stays RECON internally** (7/28 decree not touched) — "Tour of Hell" is the external
brand direction. Say the word if you want RECON itself renamed too.

**Waiting on you:** nothing blocking. Optional next step whenever: quick trademark screen on "Tour of
Hell" before final commit, just for due diligence — lower stakes than the CoD-pun case, not zero.

**UPDATE 2026-07-30:** you brought two "Tour of Hell: Vietnam" key-art pieces
(`TOUROFHELL1.png`/`2.png` from `Desktop/recon game image ideas/`) — image 1 (helicopter, map,
"Born to Kill" helmet) went in as the **main menu** background (`assets/ui/menu_bg.png`), image 2
(firebase road, "FIREBASE HELL — DEATH SMILES AT EVERYONE" sign) went in as a **dedicated loading
screen** background (`assets/ui/loading_bg.png`), used only by `game_flow.gd::enter_hub()` — every
other screen (barracks, debrief, pause, settings, service record) still shares `screen_bg.png`
untouched. **Please eyeball the main menu in-editor**: the art bakes its own "TOUR OF HELL: VIETNAM"
title top-left, so I dropped the code-drawn giant "RECON" title in `main_menu.gd` to avoid a double
title and moved the button column down to y=220 to clear the art — that y-offset is an estimate off
the 600x600 mockup's proportions, not a measured value, so it may need nudging once you see it at
actual game resolution.

## 0. ONE RULING WAITING ON YOU (added 2026-07-27, overnight coupling audit)

**Do headshots kill your squad and you, or only the enemy?**

Right now a headshot is instantly fatal to an **enemy** only. Allies and the player take the ×4.0 head
multiplier but no instant-kill, so it depends on range: an ally (80 HP) dies to a point-blank M16
headshot (108 dmg) but **survives one at distance** (70 dmg). An enemy never survives either.

The rule ADR-016 wrote down ("HEAD = fatal") even has a function whose job is to say so —
`Hitzone.is_fatal_zone()` — and **no damage code calls it**; the enemy just re-types the rule by hand.
Pick one:
1. **Everyone dies to headshots** — matches ADR-016 as written and your "both factions use the same
   systems" ruling. Hardest and most consistent.
2. **Enemies only, made official** — amend ADR-016 to say so and fix the comment in `bullet_system.gd`
   that currently claims it applies to everyone. No gameplay change.
3. **Route all three through `is_fatal_zone()`** so there is ONE implementation, then pick 1 or 2.

Full detail + numbers: `production/ARCHITECTURE_COUPLING_READ_2026-07-26.md` §2.5.

## 0a. AUDIO — one thing to know, nothing blocked (added 2026-07-27)

Real gun recordings and the folk-music radio are IN and verified. Two notes, no ruling needed unless
you disagree:

**Five of the weapons you named for the gun swap do not exist in the game.** You said 5.56 → m16a1 +
**car15**, and 7.62x39 → ak47 + **sks** + rpd, then derivations for **thompson / kar98k / mp40**.
All five of those were retired by ADR-016 Amendment C — there is no `.tres` for any of them and
`tests/test_flat_damage.gd:31` fails the build if one loads. That list came from the filenames sitting
in the sfx folder, not from the weapons the game can equip. So I applied your rule to the **live**
roster instead and spent the budget on **m14 and m70, which had no audio at all** and were sounding
like a generic rifle — the m70 is your 87-damage sniper.

**But your art log says you are actively modelling the SKS and CAR-15** (`ART_Track_Log.md` §2). So
they are probably coming BACK. That is fine and costs nothing: the SKS is 7.62x39 (same source as the
AK) and the CAR-15 is 5.56 (same source as the M16). **The day either lands as a real weapon, say the
word and it gets real audio in about five minutes.** I deleted their old synth placeholders under the
fossil law rather than leave dead files pretending to be live ones.

**`m1911` kept its synth placeholder on purpose** — the pack has no pistol stock, .45 ACP is
subsonic, and you said not to ship a downgrade for the sake of coverage. Same for the shotgun and all
four launchers: no source exists.

## 0b. YOUR NEW ART IS IN NO COMMIT (added 2026-07-27)

`git status assets/` = **531 untracked files, 44 deleted**. The whole regenerated village set
(`nha_tranh_*`, `nha_san_*`, `nha_ruong_*`, `village_well_01`, `dinh_01`, `chua_01`…) and
`fsb_main_v3.glb` exist **only on this disk**. The old `thatched_hut.glb` / `stilt_house.glb` /
`well.glb` / `fsb_main.glb` are deleted from the working tree but still live in git history, so the
repo and your disk currently disagree about what the village is.

Three test/tool files were pointing at the deleted assets. **Fixed on disk, deliberately NOT
committed** — committing them before the assets would break a fresh clone:
`tests/test_nav_path.gd` (this was one of the two suite REGRESSIONS — it goes green with the fix),
`tests/test_asset_probe.gd` (your `fsb_main_v3` edit preserved), `tools/probe_penetration.gd`.

**Commit the assets and these three files together.** Until you do, the art exists in exactly one
place.

## 1. CHARACTERS (the big one)
- [x Done but need NVA models and more US variety] **Finish the better-body remake for ALL units** — the slimmer base, then rebuild:
      us_grunt, us_grunt_black, us_medic, vc1_farmer, vc2_mainforce, vc3_sapper, vc5_nva, vc6_heavy
- [WIP] **Set weapon + arm models right on every unit** — gun attach nodes / hand alignment in the
      character rigs (your words: "align all the weapons up right")
- [ x] **Radioman (RTO)** — grunt + PRC-25 backpack + handset on a cord (the 10m radio leash +
      the FP handset raise both wait on this asset)
- [x] Civilians (men/women/kids) — DONE 2026-07-12: civ_farmer_m/f, civ_elder, civ_kid + US pilots (black/white). `tools/make_civilians.py`
- [ Grunt Spawner Should be Made, we need to test this. I noticed that the custom helments I made havent been appearing.] Modular kit when ready: helmet/torso/arm variants for roster variety 

## 2. HELICOPTER FLESH-OUT (Need to spend a real day doing all of this.
- [ ] Interior: real seats, floor, door frames (walkable cabin)
- [ ] **Name the sockets in the glb**: `SeatDoorLeft`, `SeatDoorRight`, `SeatPilot`, `SeatCopilot` —
      code already looks for them and falls back to guessed offsets when missing
- [ ] Door-gunner position (M60 mount point)
- [ ] Confirm nose orientation after my 180° flip looks right in flight

## 3. FIRST-PERSON (in process of working on the movable weapon parts and the animations related to that)
- [ ] **Verify the arms placement** (my fix is a math guess — in-game eyes needed; tell me
      high/low/close and I nudge). Then: do the hands feel right at 75 FOV?
- [x] ~~Remaining viewmodels: M60, RPD, PPSh, RPG-2~~ **DONE 2026-07-10 night** — plus
      Ithaca 37, M70 sniper, Colt 45: ALL hand-set + exported (ppsh/m60/rpg2/rpd/ithaca/
      m70/colt45`_fp.glb`, rifle_idle + MuzzlePoint contract, pose jsons captured)
- [ ] **Tunnel rat viewmodel**: pistol + MX-991 flashlight two-prop export (flashlight modeled
      w/ lens LightOrigin; hold staged; needs exporter two-prop extension + Caleb final pose)
- [ ] **M26 grenade hold + export** (model done, imported to arms file with nodes)
- [ ] Engine wiring for the 7 new viewmodels: `*_arms_viewmodel.tscn` + tres (pattern = m16/ak/mosin);
      shotgun also needs `shotgun.tres` + pellet-damage decision vs ADR-016
- [ ] Per-gun idle/fidget/check animations — specs ready in `fp_arms/IDLE_ANIM_SPEC.md` +
      `IK_ANIMATION_WORKFLOW.md` (follow-the-recipe now)
- [ ] FP radio handset raise (reuses the RTO handset asset)




## 6. IN-GAME VERIFICATION PASSES (you play, I fix live via MCP)
- [ ] **The patrol loop (ADR-029)**: NEW CAMPAIGN → seated at `fsb_main` → out the wire gate on one
      diegetic pointer → find a site unguided → fair contact → squad holds → AAR banks at the gate
      (`_bank_patrol`, `scripts/missions/field_director.gd:1066`) → quit → CONTINUE puts you back at the
      firebase. No briefing UI, no board-bird, no exfil step (ADR-029).
- [ ] F5 quicksave / F9 quickload · rations [9] · weapon cleaning [0] when it fouls
- [ ] **Field marks (NEW 7/25 — ADR-022 Amdt A)**: click [MIDDLE MOUSE] while aiming at an
      enemy / tunnel mouth / hut / trail (stand still; binos up if it's far) → toast fires →
      open [M]: a big blue pencil circle with the word on it. Marks must survive walking back
      in through the wire AND a quit/CONTINUE. Tell me: is the circle too big/small, does MMB
      feel right? (Your ruling: T or MMB — T is CAS, so MMB it is.)
- [ ] Tiny-units hunt: play near spawns, I read the [MODEL] prints
- [ ] Squad keys: F1-F4 vs the new C/H/X/N — which works on your keyboard?
- [ ] Feel checks: locational damage (head/gut/limb), blood (mist/splats/pools/wounds-on-allies),
      VO (Joe radio from the RTO's back, barks, VC shouts), F-4 napalm pass, rain squall fade
- [ ] Terrain chunk pop — reproduce while I watch the stream (bead filed)

## 7. DECISIONS ONLY YOU CAN MAKE
- [I haven't heard too many voices but I see the text that appears on the screen which is helpful. Well have to combine those two elements together ] Final squad voice assignments (Joe=radio locked; confirm John/Ryan/Norman roles felt right)
- [ ] Male vs female VC voices (pitch-shifted male sample was sent)
- [Would be cooler to have a more realistic blood effects when shooting people. It just kinda pools on people. I would like bodies to look bloodier and to have the bloodpools spray more and than spread more. ] Blood look sign-off (darker? chunkier? bigger?) — generator = one-line tweaks

---

## NEXT UP (Friday priority order — the strict list, no beads)

> **SUMMONER DECREE 2026-07-25 — MAIN PRIORITY: the Blender→Godot gun/arms PIPELINE.** Automate the
> animate→export→working-in-Godot loop. HUD is pushed to background/later (ADR-030 deferral
> re-confirmed). Pipeline build starts once you bless the M16-rig diagnosis + fix path (see the
> landmine note below). Your #1 below (the animation pass itself) rides on this pipeline being trusted.

The ordered queue for the next working session. #1 is the big-difference item.

> **RESOLVED 2026-07-26 (headless, blessed fix path):** the M16 rig contract is RESTORED in
> `fp_arms_rifle.blend` (`tools/fix_m16_rig_contract.py` — CHILD_OF hold_R→hand.R, fittings re-seated
> as gun children at their last-good offsets, mag hand_handoff re-inversed at the grab frame, the
> gun's non-uniform scale baked out) and m16/ak/m14 `_fp.glb` re-exported + structurally validated
> (markers byte-match last-good, sight radius 0.5964). **YOUR GODOT STEPS: open the project in 4.7
> (or run `godot --headless --import`) so the three GLBs reimport, then viewmodel editor → M16 →
> press V — the ADS align should now frame real sights.** Known debt: the M14's fittings sit
> root-level in the .blend (works by name-lookup; the pipeline validator flags it).

1. **WEAPON ANIMATION PASS** (the huge one). Do the movable gun parts + arm rig + animation in ONE
   pass per weapon (your workflow-saving strategy), then:
   - Make the gun PARTS that should move for animations move (bolt / charging handle / mag / trigger /
     cylinder per weapon — parts-level list to be mined from `assets/player/arms/IDLE_ANIM_SPEC.md`,
     `IK_ANIMATION_WORKFLOW.md`, `VIEWMODEL_ANIM_SPEC.md`, `production/WEAPON_ADS_WORKFLOW.md`).
   - **Restage / parent every weapon to the ARMS** ("align all the weapons up right").
   - **ADS lined up right** — verify arms placement in-game (you call high/low/close, I nudge); hands
     feel right at 75 FOV; ADS down the sights aligned per `ads_fov`.
   - **Export properly** — the `_fp.glb` + `rifle_idle` + MuzzlePoint contract (the DONE 7 are the
     pattern); then the engine wiring `*_arms_viewmodel.tscn` + `.tres` for the 7 new viewmodels.
   - (Detail already in §3 above + `ART_Track_Log.md §2`.)
2. **RADIOS PLAY CUSTOM RADIO SONGS** — wire the radio-support loop to your new Audacity broadcast
   mixes (AI + real period broadcasts + ads + hiss). FP handset raise reuses the RTO handset asset.
3. **HUEYS** — §2 above: name the sockets (`SeatDoorLeft/Right/Pilot/Copilot`), door-gunner M60 mount,
   walkable interior (seats/floor/frames), confirm nose orientation after the 180° flip.
4. **NVA VARIANTS** — `vc5_nva`, `vc6_heavy` models + finalized ZPU gunner (mannable by both factions).
5. **FLESHED-OUT VILLAGE BUILDINGS** — more geometry + interiors for CQB; clear-out playspaces.
6. **BETTER FIREBASE LAYOUT** — the "full day" detailed FSB pass.

---

## SALVAGED FROM BEADS (pre-retirement, 2026-07-22)

Beads is retired (it was closing work as "done" that wasn't). These were YOUR own feature specs that
lived only in the tracker — preserved here so they aren't lost. Corroborated live work already appears
in the sections above; this is the extra stuff. Rule on the flagged one when you get a moment.

- **Airfield location type** — a distinct location (max 1 per AO), far from the firebase, found under
  attack.
- **VC-execute-villagers scripted event** — on approach to the 3rd village, VC are executing villagers;
  the player may choose to intervene.
- **Rank progression** — rank unlocks weapons at the armory + a loadout/backpack menu.
- **Medic revive economy** — revive rules/limits for the medic.
- **NPCs trigger traps** — enemies/civilians can set off placed traps, not just the player.
- **Trap density / concealment** — how many traps, how hidden.
- **Pointman-leads order** — squad command to send the pointman ahead.
- **Squad competency: veteran vs cherry** — units differ in skill/nerve.
- **Squad morale: FIGHT → SURVIVE at 45%** — squad shifts from fighting to surviving below a strength
  threshold.
- **[RULE: keep or cut?] Prerendered-cinematic (Blender FMV) direction** — a four-cutscene FMV plan.
  Not mentioned in either current source-of-truth doc; flag it — is this still a direction you want, or
  is it dropped?


## Vehicle dash radio (Caleb, 2026-07-25)

A tiny in-cab version of the field radio inside drivable vehicles, playing music while
you drive. Implementation is nearly free — `scripts/props/radio_prop.gd` is already
drop-anywhere (folder-scanned tracks, positional player); the cab version is the same
prop with a small mesh, short hear_distance (~6m), and its own music tracks dir
(vs. the AFVN broadcast set). GATED ON: player-drivable vehicles, which the ADR-029
foot-only slice parks — build the radio the same wave driving ships. Music tracks
are an asset ask (period-legal music/AFVN-style music blocks) — separate from the
5 spoken broadcasts.

## From ghost-code audit 2026-07-25

**ANSWERED 2026-07-25 — the "what spends Team XP?" decision** (the audit's `buy_skill` stray,
`GHOST_CODE_AUDIT_2026-07-25.md:101`): nothing spends it, because it is no longer XP. The pool is
the player's HIDDEN reputation — never a number on screen; it surfaces as earned rank
(PVT→PFC→SP4→SGT→SSG) and as more weapons on the armorer's rack. `buy_skill` is deleted; allies
learn by doing only. Ruling + pointers: `production/adr/ADR-032-player-reputation-titles.md`.

Three roadmap seeds surfaced by the audit (corrected 2026-07-25, ghost-code audit). **Corpse-drag
mechanic** — the ragdoll half already exists (`model_actor.gd:674 ragdoll_bone`, `:682 wake_ragdoll`);
the grab mechanic that would use it was never built. Roadmap item, not cleanup. **Squad-regroup
behavior** — the `AIGoal.REGROUP` enum member was cut by ruling 7/25 (never scored, set, or matched),
but the behavior it named ("isolated soldier rejoins his squad") remains a valid future feature if
squad cohesion ever needs it. ~~**Temple/shrine art gap**~~ — CLOSED 2026-07-26: the generated prasat
set ships, `stamp_temple_shrine()` places it, and the temple root joins `temple_shrines`
(`scripts/world/site_planner.gd:809-832`).

---

## FOR THE NEXT AUDIT PASS — wire up the nine unplaced temple statues (noted 2026-07-26)

**Verdict class: UNFINISHED, not FOSSIL (ADR-023) — do NOT delete these models.** They are built,
exported, and collision-tabled; the shrine stamp just never grew past the stair group.

`tools/gen_temples.py` ships **14 statues** and all 14 have `collision_table.gd` entries (`"mesh":
true`). `scripts/world/site_planner.gd` is the only placer in the project, and its statue block
(`:834-852`) names **five**: `guardian_01`, `guardian_02`, `naga`, `seated`, `lingam`.

**Nine have zero placement callers repo-wide:** `altar`, `apsara_01`, `apsara_02`, `garuda`,
`singha_01`, `singha_02`, `stele`, `stupa`, `naga_rail`.

Roster proposed to Caleb, unruled — he picks before anything is built:
- **singha** pair as an alternate stair guard, rolled against the dvarapalas so not every shrine
  reads the same
- **apsara** relief slabs set flat against the non-entrance wall faces (they are wall panels, not
  free-standing figures — placement must respect that)
- **naga_rail** flanking the approach as a balustrade run, seated off the same `fwd`/`side` basis
  the guardians already use
- **stele · altar · stupa · garuda** scattered in the courtyard inside the 14m site radius

The `fwd`/`side`/`reach` basis at `:838-842` already does the hard part — anything added should reuse
it rather than re-deriving the door direction. Reach is manifest-driven, so it scales with the
temple's footprint for free.

---

## FP VIEWMODEL ANIMATIONS — measured defect list (2026-07-26)

Full report: `production/research/viewmodel_anim_defects_2026-07-26.md`.
Data: `production/research/viewmodel_rig_audit.json`. Re-run the probe with
`blender -b assets/player/arms/fp_arms_rifle.blend -P tools/audit_viewmodel_rigs.py --`.

### Mine, next session (headless, no animation authoring)
1. ~~**PPSh retime**~~ — **DONE 2026-07-26.** You ruled the timer follows the animation and that the
   export should write it. Shipped as **ADR-034 Amendment A**: `tools/sync_weapon_timers.py` reads
   each clip's length from the exported GLB and writes `reload_time` / `empty_reload_time` /
   `jam_clear_time` into the .tres; the export driver runs it every time; the validator now FAILS on
   drift. All four guns measure exactly 1.00× — the PPSh was 0.76× / 1.30× / 3.30×.
   **You accepted the balance change: PPSh jam clear 1.1s → 3.63s** (reload 3.4 → 2.6s, empty → 4.43s).
   Worth feeling in a playtest — it is a long time to be defenceless.
2. Fold the **frozen-hand** check into `tests/test_viewmodel_contract` so a dead limb fails the build
   instead of waiting for a playtest. (The clip-vs-timer half is now covered by the validator.)
3. Marker parenting: manifest says `markers_under_gun: true` for all four, but AK's markers parent to
   `AK47` and M14's to `M14_gun` (the mesh, not the root). Correct the claim or the parenting.

### Caleb's, in Blender (animation quality is his hands — standing ruling 2026-07-26)
1. **AK broken reload** — `ak_mag_handoff` is a 132f action mounted under BOTH the 78f `reload` and
   the 133f `reload_empty`. Authored for the long hand path, so the mag rides a hand that isn't there
   during the short reload.
2. **Frozen hands** — `hand.R` measures 0.00 mm/frame for the ENTIRE clip in M16 reload,
   reload_empty and jam, and in AK reload and M14 reload; `hand.L` is dead through M14 jam and
   charge_handle. Biggest single cause of "robotic".
3. **M16 modeling / sights / ADS markers.** One measured lead: `M16A1_gun` is the only gun root with
   a non-identity object rotation — (2.642°, −0.021°, 89.893°).
4. **M16 leftovers from 2026-07-26**: 4 single-face floaters (3 facing down), 2 open sheets in the
   join, and the old hand height still present in the reload/reload_empty/jam gripping segments
   (only `m16_fp_idle` was shifted).
5. **PPSh**: prototype clips to re-author; the bolt was never split off the gun so it is static in
   every clip; hand-in-gun penetration is worst on this gun by a wide margin (140mm vs the M16's 23).

### Two things NOT to do
- **Do not blame the export.** We ship glTF, not FBX. `bake_anim_simplify_factor` / `bake_anim_step` /
  `add_leaf_bones` are FBX-only. `export_viewmodel_clips.py:324-332` already forces sampling, disables
  animation-size optimisation and bakes every part frame-by-frame. Nothing simplifies a curve.
- **Never run "apply all transforms + set origins to the 3D cursor"** on `fp_arms_rifle.blend`. It
  destroys the PPSh's 27 authored non-uniform-proportion children, `M16A1_ch_rail`'s slider origin,
  and the parent-inverses on guns already blessed.

**Still unproven for every gun:** the clips have only ever been watched on the bench. Nobody has
confirmed they play correctly in-game through `weapon_holder`'s reload path.

---

## ORPHAN CLIP WIRING — War Room 2026-08-02
Full record: `production/war_room/2026-08-02_orphan_clip_wiring/` (briefing · 4 analyses · discussion · synthesis).

**The audit.** `assets/shared/anim_library.glb` carries 163 clips. Measured against every `.gd`/
`.tscn`/`.tres`/`.json`: **32 have zero call site.** 8 more (`*__smg`) have no literal call site but
ARE reachable — `sprite_state_map.gd:403` builds `base + "__" + family` and `ppsh41 -> smg`.

**Root motion is stripped project-wide** (measured off the glTF Hips channel: `walk_forward` = 0.000m
is the control). The lone exception is `disembark_heli_*` at 0.200–0.534m.

### DONE this session
- **Cockpit wired.** `seat_system.gd` — `PILOT_CLIP` became a three-state map: `cockpit_idle` parked ·
  `pilot_flips_switches` one-shot on touchdown · `cockpit_controls` airborne. Driven off the existing
  `Helicopter.State`; the tick is independent of `player_boarding`, since a ship nobody can board still
  lands with visible pilots. `cockpit_controls` added to `model_actor.gd:_LOOP_NAMES` in the SAME change
  — it is not caught by `_LOOP_PREFIXES` and would have frozen the pilot on its last frame.
- **`anim_review.gd` was BROKEN and is fixed.** `ModelActor.setup()` takes a **unit_id**; the bench was
  handing it a **path** from `model_path()`, so `model_exists()` failed on every unit and the whole room
  came up empty. Pre-existing drift, unrelated to this session's work. Now boots at **163 clips, 7 pages**.
- **Crew banks added to the bench** (press `N`): MG CREW · LITTER TEAM · LITTER LOAD. Crew rows hold
  station offsets and restart on the clip's own cycle so the men stay in phase for the whole performance
  instead of being paged one at a time.
- **Litter team built** — `scripts/world/litter_team.gd` (new), seeded in `site_planner.gd`, spawned in
  `mission_generator.gd`, latched via a new `Civilian.puppet` flag. **DORMANT until the art lands, by
  design** (see blocker below).

### BLOCKED — needs Caleb
1. **THE LITTER PROP.** `fb_litter` exists only INSIDE
   `assets/us/characters/camp_clips/stretcher_carry.glb` (the 4-rig authoring reference — it also holds
   `MC_litter`, the prop's own motion clip, and a `PSXRig_casualty` pose that was never split into
   anim_library). It needs exporting standalone to
   `assets/world/building models/structures/firebase/kit/fb_litter.glb`. `LitterTeam.available()` gates
   the entire feature on that path existing, so the code is inert and harmless until it does — the same
   contract `heli_lift.gd:42-46` uses for the unmade boarding clips.
2. **JUMP / LANDING — cannot be done as ruled.** A routine is a man at a `work_*` marker doing a job, and
   a station never involves a jump. Jumping is TRAVERSAL and there is no traversal system:
   **`NavigationLink3D` appears zero times** repo-wide, so no NPC is ever airborne and the clips have no
   trigger. The player jumps (`player.gd:1671`) but is first-person — no third-person body to animate.
   The heli-skid slice was proposed and REFUSED: `disembark_heli_*` carries 0.2–0.53m of authored
   step-off, so bolting on `jump_down`/`hard_landing` risks a man landing twice.
   **His call: open a traversal epic, or leave `jump_up`/`jump_up_2`/`jump_down`/`jump_away`/
   `hard_landing` orphaned.**
3. **MG CREW — his visual check, then wire.** Measured: all four `gun_*` clips are IN PLACE (0.000–0.024m
   drift over 27.3s), so they will NOT drift apart — the wiring is mechanically safe and only the look is
   unproven. Cost if approved: a 4-man crew is **more than half the 7-man firebase work budget** on one
   position, and `site_planner` carries 20 `gun` markers.

### Deliberately left orphaned (do not "fix")
- `cockpit_dead` — no pilot damage model exists; wiring it means inventing a state to justify a 0.33s
  clip. ADR-023 forbids the dead hook.
- `turn_90_left/right`, `crouching_turn_90_left/right` — carry up to −161.6° of ROOT rotation
  (`sprite_state_map.gd:54-56`). Only the in-place `turn_left`/`turn_right` pair is safe to loop.
- `jump_away` (a dive, no grenade-flee behaviour to hang on) · `jumping_jacks` (no PT routine) ·
  `signal_move_up` (a beckon; looping it waves forever) · `crouched_sneaking_*`, `cover_reposition`,
  `rifle_turn`, `rifle_crouch_idle_to_walk`, `stop_walking_with_rifle`, `action_idle_to_standing_idle`,
  `strafe_2`, `salute`.

### Known gap, unrelated but recorded
`WEAPON_FAMILY` (`sprite_state_map.gd:385-391`) declares `mg`, `bolt`, `launcher` and `pistol` families
with **zero clips authored**. `model_actor.gd:877` warns once per family and falls back to the rifle hold
— the RPD gunner and the RPG man carry their weapons like rifles.
