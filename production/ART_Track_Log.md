# ART MISSING — master list from AUDIT #3 (2026-07-11)

Everything below is verified absent (or stand-in) as of audit #3. Ordered by impact within each
category. `[bead]` = tracked. Blender split per workflow: Caleb poses/models, Claude stages/exports.

## 1. CHARACTERS (the biggest gap — ~55%)
- ~~**Civilians / villagers**~~ — **DONE 2026-07-12** (commit 5949b50). `civ_farmer_m` 1.62 /
  `civ_farmer_f` 1.52 / `civ_elder` 1.55 / `civ_kid` 1.26, barefoot under conical hats, plus
  `us_pilot_white` / `us_pilot_black`. Built on the v3 gear-cut base by `tools/make_civilians.py`,
  so they inherit the 100-clip library and the gib contract. Villages no longer need capsules. [4o7e]
- **RTO + PRC-25 radio backpack** — needed twice: worn by the RTO ally AND the handset reused as the
  player's FP support-call viewmodel. [i1vu, w8ep]
- **Slim-base remake of the 8 v1-rig characters** (us_grunt, us_grunt_black, us_medic, vc1/2/3/5/6)DONE. Us Grunt v3 is the source of truth for Us models as well as the workflow for making multiple variants of models. 
- **Headgear library** — pith helmet, boonie, straw conical (VC), USMC utility cover, bare-head hair
  variants. [qcsb] Half way done
- **US visual variety** — helmet/torso/arm variants so the fireteam isn't clones. [qrzf] Needs to be addressed
- **NVA gunner for ZPU #2** + finalized sights mirrored. [htxn] Not finished yet. Animation will apply for both factions as it will be mannable by everyone, as well as another gun the player can mount. 
- **Gore stump painting** on gore_tex (gib cells exist, cells unpainted). [yp0g] Gib exists, haven't seen it in too many playtests lately but its based on damage done and we haven't been going crazy with the damage yet. 

## 2. WEAPONS — FP models still on stand-ins
- **SKS** — shows a Kar98k. Enemy-common weapon, worst offender (capture hands you a WW2 rifle). Model made, working on getting the arm models and animations in one pass. Saving time and workflows.*
- **M79** — shows an MP40. Model already built in weapons_us.blend, needs FP hold + export. Model made, working on getting the arm models and animations in one pass. Saving time and workflows.*
- **CAR-15** — shows a Thompson. I think we have the v1 m16 model and the faux fps down the sights aiming. 
- **FP radio handset** — blocks Batch 6 close. [of80] Were mid wiring up the loop for this. I have a placeholder phone model when you grab the phone as I have to do the phone animation with the arm rigs. In the middle of confirming the radio support loop. I also made a AC 47 spooky gun ship thats almost done instead of the square block we have. 
- **M26 FP hold finalize + export** (model done, staged). [rzlk] Model made, working on getting the arm models and animations in one pass. Saving time and workflows.*
- **MX-991 flashlight two-prop export** (tunnel rat). [awip] I thought I had exported this? but theres going to be some animations i want to add too. 
- **MuzzlePoint verify per arms scene** — zero current viewmodels expose one in Godot. [vi32] Why is that? the models have them. 
- Period models if ratified: BAR, Kar98k(return), Nagant. [ycib]

## 3. ANIMATIONS (Caleb posing queue — priority order) I haven't worked on these animations too much but I think we can do them all soon. We also need to add a few more "seeking cover" animations or fix when the models switch from crouched to the leaning against the wall. I saw them taking cover a good 10m before they were actually to the building and than they slowly made their way to the wall. 
1. **mg family** 8-clip set — unblocks vc_sapper + PIGMAN (two units rifle-holding LMGs)
2. **launcher family** 8-clip set — nva_rpg rifle-holds the tube, worst visual read in combat
3. **bolt family** 8-clip set — mosin/m70 carriers
4. **pistol family** 8-clip set — lowest (no AI carries one yet)
5. **Family reloads** where the motion differs most: mg belt / bolt cycle / launcher muzzle-load
6. **Missing base clips:** grenade_throw, surrender_idle (hands-up), wounded_crawl,
   death_from_the_left (deaths currently favor one side), stumble_hit, heli_board/heli_exit
7. **Per-gun FP idle/fidget/inspect** (HL1-style; specs in fp_arms/IDLE_ANIM_SPEC.md). [4uuu]

## 4. VEHICLES / AIRCRAFT
- **C-47 Spooky** — still a stretched-box placeholder in-game. [y8ho] Just finished making the model, I need help animating the blade rotors which I think i have everything parented up etc. I also need to make a few guns that stick out of it. 
- **Ordnance mounting** — 8 bomb/napalm/rocket-pod props exist, none attached to the F-4 or dropped. Thats something well have to do during the dedicated vehicles. 
- a4_skyhawk unwired (modeled, no scene). It should be in the game we have it already. 

## 5. STRUCTURES / WORLD
- **Building interiors (CQB kit)** — 0%; every building is a shell. Gated epic.
- **Tunnel interior kit** — entrance+ladder, corridors, rooms, props. [u0e0]
- **Roads** — LIVE (as of 2026-07-24): `RoadNetwork.new(...)` builds the hub-and-spoke net (`scripts/missions/mission_generator.gd:562`) and carves the corridor through vegetation (`scripts/missions/mission_generator.gd:680`); guarded by `tests/test_roads.gd`.
- ~64 modeled+measured structures sit unplaced (placement/wiring work, not art). Alot of these models are old rips from the spring1944 opensource game we were using as holders or bad makes of things I had tried using those old models from a fwe months ago with the REALVIETNAMRTS project. Even our newer current firebase is okay but I need to spend like a full day making a more detailed firebase and I think I should do that too with the villages and make more finished buildings so they can be fleshed out. Also adding more geometry to the villages will be a win and allow some close quarters battles and more places for the players to have to clear out. 

## 6. UI ART
- Topo paper texture, medal/ribbon icons, MACV-SOG patch PNG, offer-card thumbnails. [fmc8 adjacent] There needs to be a whole day spent fixing and refining the whole UI/UX. its all total placeholder right now and worth something to spend our deep dive of a week learning more about the pros and cons of UI UX experiences in a deep research. 

## 7. AUDIO (the emptiest bucket — ~10%)
- **Every weapon SFX is procedural-synth placeholder** — real foley set needed (or the synth bank
  bead 9qp6 ships first as bridge).
- **VO barks** — Vietnamese + US callouts for the bark system (lngs); voice_studio.py pipeline ready.
- More ambience beds (only jungle_day.mp3 is real; night/rain/river missing).
I just got a bunch more radio bits I edited with audacity mixing ai generated radio broadcasts and real broadcasts from the time mixed with radio ads and a radio hiss that covers the dead parts. 

## 8. TEXTURE OPTIMIZATION (the real 85MB)
- **ar5c**: crop/downscale the 3600×5700 faction sheets per-character in Blender, re-point UVs,
  re-export. NOTE (audit #3 proven): the loose `*_better textures.png` are LIVE external deps of the
  GLB imports — do not delete from disk; shrink them at the source. If this will help game performance its something will ahve to do soon but wont this change the way textures appear on units? also noticed that units legs appear thru their pants texture when they move sometimes. is that something we did wrong?
- kar98 stand-in texture set (~40MB) dies automatically when the real SKS lands.
- `.blend1` backups in art_source/characters/variants/ (~300MB untracked) — safe local cleanup.
