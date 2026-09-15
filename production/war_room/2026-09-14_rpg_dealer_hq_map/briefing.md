# BRIEFING — 2026-09-14: the 3x map, the dealer, the HQ chain, the Huey crash, scripted events, the observatory

**Summoner:** Caleb. **Arbiter:** the RECON Overseer. **Branch:** `RPG-build` for game state; perf /
combat / base-sim on `BaseGame-V1` first, merged forward (memory `recon-branch-policy-2026-09-13`).
**Entry gate:** THE DEMO PLAYTHROUGH (ADR-015) — still open; everything here is either demo-shaped
build under his explicit direction, a bug fix, or evidence-gathering.

## His words, verbatim (the order he gave them)

**Scope:** *"make there be a black market dealer with a chain of quests and the HQ with a chain of
quests. This is where we show off the hearts and minds system as well as that being integrated to
the enemy presence etc."*

**Map:** 3x area — 512 m → ~890 m square (he picked "3x area, ~900 m side"). Intel UHD is the bench;
demo target 45 min; Steam eventual. Study Ghost Recon / SOCOM / Medal of Honor / Far Cry ("a more
war based idea") for how larger maps with lots going on are handled; write the technique and WHY.
Perf: *"the goal of better performance is somewhere we're really getting"* — do not regress the 9/14
numbers (mean 37.5 / median 34 / p95 68 fps on `perf_walk`). Paired A/Bs only; bench the game, not
the scenery.

**Design steer (mid-flight):** *"with making things like the comic book having a more focused areas
for the stories and quests is important and also being able to make cut scenes and stuff or scripted
events that trigger at certain points (which is something we still havent really done yet either,
read the comic and try to make some scripted events from the vietnam war side. just the more im
working on this project and rpg focused games immersive sim focused game the level of open world
does need to be controlled to a degree to guarantee that sense of fun vs freedom"*

**Huey crash ruling:** *"there should be a dice roll if 1 or 2 pilots and 1-4 soldiers survive the
crash for the player to lead back to the firebase. make sure this whole system is wired up to a
sensible existing system and connected into the game for the demo."*

**Observatory + audibility:** *"i think the main thing that makes the vietnam hell let loose game
fun is to hear the enemy walking around in the jungle, but also the same for you. I would be curious
to see in a tool we make with godot exactly how the enemy AI works related to alertness, stealth,
finding bodies, how civilians react. basically i need a visual tool i can see the entire Hearts and
Minds system at work"* — addendum: it must also show *"the general npc ai thought process etc"*.

**Firebase art list (afternoon, verbatim):** *"can we headlessly fix the HQ bunker and spend some time
making it proper"* · *"thats the main art issue on the firebase, and than just having to add more
ambient floorboard paths around the firebase and fixing the gate (its floating and not realistic)
and i need to fix the bunkers by hand maybe"*. Order: TOC → gate → floorboards; bunkers his hand.

## The questions the council must answer

1. **MAP.** 890 m square, 3x area. Which technique (distance-tiered sim, chunk streaming, sleep-by-
   distance, cull/impostor, near-player event scheduling) and WHY, against ADR-013 (≤2 km never
   streams), ADR-026, the behavioural LOD already built (promote 80 / demote 105), and the 9/14 fps.
   Every 512 assumption named (WorldConfig.MAP_SIZE, DEMO_MAP_SIZE, site_planner AO room/margins,
   siege form-up off the map, EdgeFence, reinforce pre-warm at z≈865, terrain chunks, veg scatter,
   nav bake, clutter subcells, terrain_watchdog). Is the 3x map MORE JUNGLE or ROOM FOR AUTHORED
   PLACES with controlled routes (his steer says the latter — ADR-041: the scene is a plan)?
2. **AUTHORED PLACES for the 45-min demo.** Which set (firebase, village, crash site, dealer's corner,
   ambush stream, ...) and what is deliberately closed off, without rails (Pillar 3).
3. **THE DEALER.** A US supply sergeant / REMF at the firebase. What he trades, what he asks, how his
   asks conflict with HQ's, how what he moves reaches the village / the enemy (H&M ledger = deeds,
   never counted, ADR-038 §2a), what it costs in HQ standing. Against the 9/13 decree.
4. **THE HQ CHAIN.** The TOC's taskings; how village trust changes intel, where the VC can base,
   patrol density, ambush odds — through the ledger's bands, felt not read.
5. **THE HUEY CRASH.** Spectacle → HQ tasking. A slick takes ZPU fire in view, trails fire, goes in;
   wreck = `huey_crashed.glb`; survivors by seeded roll (pilots 1–2, pax 1–4); survivors follow the
   player home via an EXISTING follower system; arrival closes the tasking; VC hunt the site by H&M /
   presence. Fixed point in the demo arc, not random. Air FF ruling and aircraft facing/scale memory.
6. **SCRIPTED EVENTS / CUTSCENES.** A small reusable trigger → staged-beat system (cutscenes stay
   standalone FMV per memory). Which 2–4 Vietnam-side beats from the Reboot comic (Issues 1–4 only),
   cited by issue/page, against the HQ/dealer chains and H&M. Gore = the viewer's psychological state.
7. **THE OBSERVATORY.** In-engine visual tool: alertness tiers, LOD tier, senses, noise heard,
   last-known, witness chain, civilian reaction, ledger with causes, per-NPC "thought process" pane,
   map pane (follow-up). Reads the state the AI acts on; zero cost when off.
8. **JUNGLE AUDIBILITY.** Hear them before you see them; the player's noise is a real stimulus.
   Extend what exists (NoiseBus); pool AudioStreamPlayer3D; both branches.

## Constraints in force

The 5 Pillars · `production/adr/` (ADR-002 scale, -005 witness, -010 one seed, -013 no streaming
≤2 km, -015 verification, -016 one damage grammar, -026 perf, -038 H&M felt, -041 authored places,
-043 kit, -044 progression spine) · `GAME_GUIDE.md` §6 scope (ONE faction; KILLED/PARKED/FROZEN lists)
· the 9/13 H&M decree (`../2026-09-13_rpg_45min_hearts_and_minds/synthesis.md`) · Fairness Law ·
r4bk Law · Truth law · NO MORE DRIFT · no procedural geometry · his fps numbers.
