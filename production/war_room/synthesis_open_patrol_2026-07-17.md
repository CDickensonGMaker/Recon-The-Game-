# SYNTHESIS — THE OPEN PATROL SIMULATOR (2026-07-17)
## Ratification package for the Summoner. NO CODE until he blesses it.

**The decree (near-verbatim):** combine what works in the AI stress test with the game world.
Remove the whole briefing part. The game is an open simulator with no player-facing mission
tracking. Form up, leave the base, squad goes on patrols; find enemy camps, patrols, villages
along the way. A logic gate tracks when the player leaves a distance from the firebase — a
"location" spawns that they are pointed toward to patrol around; the path there is the player's.
Foot only for the slice. Villages and camps fairly close to the firebase or people get bored.
**Clarifications:** the world is ALWAYS living as decreed before (the gate is a pacing pointer
selecting from the living world, not a spawner-on-demand); the mission/operations layer is
condemned — default DELETE under fossil law, extract only what the patrol loop needs; north star:
"i just wanna leave the camp and go find problems."

**Council:** technical-director + systems-designer (drift audits, reused), game-designer (patrol
loop/pacing), devil's advocate (sacrifice list). All analyses in `analysis/`. Arbiter: Overseer.

---

## THE ONE FINDING THAT ORDERS EVERYTHING
**The briefing is the ignition key for the only populated world that exists** (DA #1):
villages/civilians/paddies/ambient patrols/camps/weather all stamp inside
`MissionGenerator.plan()+build()`, which is fused to the offer dict the briefing produces. The hub
world is "No objectives, no enemies." Meanwhile the game-designer finds **the patrol sim IS the
hub world made live**, and the ambient-life corridor spawner already exists — keyed to the wrong
two anchors. Therefore: POPULATE FIRST, BURY THE BRIEFING LAST.

## (a) IMPLEMENTATION PLAN — build order

**W1 — THE POPULATED PATROL WORLD (precondition, protected-foundation improve-in-place).**
Make `enter_hub()`'s world THE world: extract build()'s population pass (sites, civilians, ambient
ecology, paddies, weather/time draw re-homed from the offer roll) to run seeded off the operation
seed with no offer dict. Density bands (code-grounded, game-designer): wire radius 120m ·
first-sign 150–300m · **villages 280–450m** (first ville 2–3.5 min — the "bored" number) · patrol
locations 350–550m · camps 400–540m. Implement bands as a radial-band constraint on the ONE live
`SitePlanner.find_site` path; **LocationPlanner doctrine crowned, file killed** (its rings are the
right idea, off-map at 1280m scale, second-doctrine ban, ADR-023 deletion with its test).
Re-anchor the corridor spawner (mission_generator.gd:557-609) to wire→location. 4–6 villages +
2–3 camps saturate the AO.

**W2 — THE PATROL FRAME.** New small `PatrolDirector` (attached in enter_hub; polling template
hub_controller.gd:38-63): AT-BASE → WIRE-CROSSED (gate fires once/excursion, location =
hash(op_seed, patrol_count), sector-biased away from visited) → MOVEMENT-TO-CONTACT → DISCOVERY
(no completion event — the world just IS there) → DRIFT → RETURN (re-cross inward = patrol AAR +
commit point + gate re-arms). The pointer is DIEGETIC ONLY: grease-pencil circle + "SWEEP NW" on
the topo sheet (ADR-022 language, never checks off, replaced not completed) + compass + repeatable
point-man bark + ONE gate toast concession. **The floating objective-marker system dies** (it IS a
quest tracker; HARDCORE already proves the game plays without it). MissionDirector SURVIVES
HEADLESS renamed FieldDirector (toast bus 40+ emitters, escalation, fire support, flags —
it is the field OS, not a tracker). New **FieldHUD** (toast + compass + squad strip — the hub
currently renders every bark INVISIBLE, DA #3). Death → field AAR → wake at the firebase,
consequences committed (Pillar 5 currently lives entirely inside the mission frame, DA #4).
Per-patrol resets for revives/hunter-pool/supply/fire-support (DA #10: object lifetime did these).
CampaignState commit bracket re-pointed at walk-out/return (DA #6). Squad patrol FEEL: allies
string into staggered file on sustained bearing, POINTMAN 10–15m ahead — reuse the enemy column
math, no new orders.

**W3 — THE BURIAL (fossil law, pull the key last).** Delete fully: HubBriefing, BriefingScreen,
MissionSelectScreen, MissionOffers, TOC briefing prompt + "GET BRIEFED FIRST" gate +
board-the-bird flow, show_select/show_briefing/launch_accepted, the dead menu wire
(game_flow.gd:128, ADR-008 already convicted it), insertion_ride + exfil bird chain (foot-only;
helis parked). WITH: SCHEMA_VERSION bump migrating offers/accepted_offer/checkpoint_offer out of
saves + CONTINUE rewrite (currently routes checkpoint_offer into start_mission — dead-ends, DA
#11). Intel W80: sink died with the briefing — see Q2. Bead 7nxd folds in: the TOC becomes
scenery; replace-model-when-Caleb's-art-lands, function-free.

**W4 — ONE WORLD, ONE BENCH.** qjf0: arena becomes a thin wrapper over the shared build (it
currently derives 0% of world/sites/forces from it, impersonates the "game_world" group, defaults
1.5× HP, copies night literals — tech-director D1/D2). Zero the arena HP default or surface it
on-screen. Land **dlox structural probe** (seed-scan + placement-entry-point manifest + arena-on-
shared-build assert). Kill terrain_lab (old-era). Seed ConvoySpawner. Delete dormant streaming
machinery (≤2km law, mhfv remnant).

**PARKED-FOR-LW (flagged UNFINISHED, never FOSSIL — deleting them deletes the Living War epic's
spine):** result pipeline (retargeted minimally in W2 as the patrol AAR), DynamicMissionFactory
(retarget to pointed locations post-slice), plant/rescue sensors (future pointed-location
content), threat/AA layer (retarget to patrol outcomes or park visibly).

## (b) THE 5-BEAD RESTRUCTURE — PROPOSED ONLY (Summoner froze it: "but wait tho")
| Domain bead | Absorbs (carriers → serving the decree) |
|---|---|
| **SYSTEMS** | patrol pivot W1–W4, x0r1 worldbuild phases, u4h2 PERF, e1q6 playtest debt, c3ea audit, p85y fossils, gryl HUD (→FieldHUD), yu8b/imue git+art drift process |
| **COMBAT** | 0623 AI doctrine, 8l06 presentation, etvy weapons/ADS, yg6j destructible jungle |
| **ART** | s2fs jungle look, 7nxd TOC scenery, environment/props, f4a1 backlog art items |
| **ANIMATIONS** | 00qp anim carrier + squad-file/patrol locomotion + station work anims |
| **MODELS** | lpib character-art P0, 36pk viewmodels, re-exports, officer variants |
Not executed. Ships on his word only.

## (c) LAB SCENES EXCEPTION (tech-director) — REQUESTED
KEEP as instruments: gore_lab, gun_range, ps2_perf_probe, overnight_bench, viewmodel/hitzone
editors, patrol_lab, sight_lab, windowed_confirm probes (the 28-file fleet already boots the REAL
game_world — the right pattern dominates). KILL: terrain_lab (old-era RTS camera + construction
systems) + the dead menu wire. The arena stays but becomes a wrapper (W4).

## (d) ADR AMENDMENTS — drafted for ratification, nothing silently edited
1. **NEW ADR-029 (draft): THE OPEN PATROL SIMULATOR** — the loop, the wire gate, the diegetic-
   pointer law (no quest tracker ever), density bands, foot-only slice, AAR-at-the-wire commit.
2. **ADR-008 amended:** TOC-briefing + board-the-bird conditions SUPERSEDED by ADR-029; firebase-
   as-home survives; legacy select path deletion becomes law (was already convicted).
3. **ADR-006 amended:** payout moment debrief → patrol AAR at the wire; ±25 grammar unchanged.
4. **ADR-021/022:** already aligned in spirit (patrol to learn the ground IS the game now);
   amend mission-offer references; canonize the grease-pencil pointer as THE pointer.
5. **ADR-028:** no amendment; W1 is its improve-in-place step; note phase order.

## (e) RECORD — this file + 4 analyses archived; accounting debt from the village-assault wave
carried in synthesis_village_assault_2026-07-17.md (unrequested heli scope; WIP-bundled commit —
remedy still his call). This council ran the full ritual: live lenses, no cross-talk, DA heard.

## QUESTIONS FOR THE SUMMONER (with recommendations)
- **Q1** Rank/XP clock: completed patrol excursions increment member["missions"]? **Rec: yes** —
  the promotion tutorial keeps its clock (DA #7).
- **Q2** Intel points: retarget (intel sharpens/extends the next pointed location) or delete the
  whole 6-site chain? **Rec: retarget** — it is the LW hook and the patrol loop's one economy.
- **Q3** TOC (7nxd): scenery only now, replace model when your art lands? **Rec: yes.**
- **Q4** Ratify the 5-bead restructure as tabled? (Frozen until your word.)
- **Q5** Lab exception (c)? **Rec: yes.**
- **Q6** Bless the W1→W4 order and W1's density bands? (The bands are tunable numbers, not law.)
