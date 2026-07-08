# RECON RPG → REAL-TIME FPS ADAPTATION

**Date:** 2026-07-07 (Phase 3)
**Primary source:** RECON (1982, Joe F. Martin, RPG Inc.) — the 43-page rulebook at `Downloads\recon rpg.pdf`, fully extracted (text dump in scratchpad). Page refs are PDF pages.
**Secondary:** web research on Revised RECON (1986, Palladium) — see §14 edition notes.
**Frame:** decisions already locked — HLL lethality, fail-forward + Pacific Assault medic, diegetic-first detection UI, fireteam with orders, stealth-as-economy, province campaign + generated AOs.

---

## 1. The thesis: RECON already *is* this game

Three properties of the 1982 rules map almost verbatim onto the design we converged on in Phases 1–2:

1. **"When in doubt, roll against your Alertness"** — the game is a perception economy, not a combat engine. Our detection accumulator (Phase 2 §5) is the real-time version of RECON's Alertness roll.
2. **The XP system scores avoidance:** +25 per contact successfully avoided, −25 per contact detected, minus every point of St the team lost (KIA = ×2), divided among the team (p.20–21). RECON invented our "stealth is an economy, never a gate" commendation math in 1982. We adopt it nearly unchanged as the mission debrief score.
3. **Lethality:** ~101 average St, rifle hit = 4d10 to a rolled hit location, brain = fatal, <0 St = dead, "there are no miraculous cures." Hell of Duty's dice-notation damage system (1d6+45 etc.) is *already architecturally RECON* — we swap in RECON's actual dice.

The book's real procedural engine is not a mission table (this edition has none — see §10) but the **contact/LZ/ville/visibility tables** — which are exactly the layers a mission generator needs: insertion complications, ambient encounters, environment rolls, settlement population, enemy quality.

---

## 2. Attributes → player & NPC stat model

| RECON (2d100 each) | Real-time translation |
|---|---|
| **Strength (St)** = hit points AND movement rate AND carry AND grenade range (p.8) | Split into: HP pool (per-character, ~60–140 like 2d100), sprint speed & **stamina** (finally gives HoD its missing stamina system a data source), carry weight (encumbrance slows movement — p.9's 1 ft/lb rule becomes a movement-speed multiplier), grenade throw range |
| **Agility (Ag)** | Weapon handling: ADS speed, reload speed, recoil recovery, climbing/vault speed, melee takedown success |
| **Alertness (Al)** | Perception both ways: how fast the character's detection accumulator fills *on others* (squad spotting/callouts) and modifiers to being noticed (silent movement). For the player: drives the "sixth sense" pip sensitivity and point-man-style warnings |
| 4-F rule (St+Ag+Al ≤ 100 → reroll) | Squad recruit generation floor — no useless replacements |
| 0 St = unconscious, <0 = dead | Downed state (revivable) vs dead — matches the Pacific Assault medic chain exactly |

Player character gets fixed baseline attributes; **squadmates roll theirs** (visible on the roster — a 130-St pigman is a tank, a 91-St rookie is fragile). Attributes improve via XP (§12).

## 3. Percentile skills → real-time resolution

The universal "roll 2d100 under skill%" becomes, by context:
- **Shooting:** skill% → base spread/sway. RECON's Base Per Cent Effectiveness (roll 2d100 per weapon class, +5/level in a specific weapon) → per-character per-weapon-class proficiency that scales cone-of-fire, sway amplitude, and recoil control. The **99% cap** = a floor on minimum spread; nobody becomes a laser.
- **Timed actions** (demolitions, first aid, lockpicking, defuse): skill% → action speed and failure chance on the hold-to-complete bar. Demolitions without skill = "50% chance it detonates as intended" (p.29) → unskilled charges can fizzle or misfire — a real reason to bring the demo man.
- **Passive checks** (detect ambush, detect mines, tracking): skill% → range/probability of the automatic warning (point man's hand signal fires when his roll would have succeeded).
- **Unfamiliar weapons** (p.25): no proficiency → −10/−15 effective handling (worse sway/reload fumbles), improving +5 per mission of use. Picking up an AK mid-mission is possible but sloppy — and (p.23) an AK's **sound signature doesn't give you away as American**. Keep that: firing enemy-caliber weapons confuses AI sound identification.

## 4. MOS classes → squad roles + player perks

RECON's 9 MOSs (p.10–11) — with the rule that **only one character per MOS gets its bonuses** — is our squad-composition system (and slots straight onto the Vietcong role model from Phase 2 §7):

| MOS | In-game role |
|---|---|
| **Point** (Al 60+; +5 Al at point, exclusive Detect Ambush/Mines/Tracking) | The ambush/trap detector — hand-signal warnings ahead of the player. His Al & skills = warning range/reliability |
| **RTO** | Radioman — REQUIRED for exfil call, resupply, arty (FO) and air (FAC) support. If he dies, you lose those verbs → protect-the-RTO emergent gameplay |
| **Medic** (removes 5 St/skill-level per wound, 1 CR per St, both immobile; each wound once) | The revive/bandage chain: heal amount = skill level, channel time proportional, interruptible, per-wound-once → can't infinitely re-heal. This IS the Pacific Assault system with tuning knobs |
| **Pigman** (MG; +3 rds sustained) | Suppression role — higher sustained-fire before accuracy/overheat penalty |
| **Grenadier** (+5 GL/shotgun) | M-79 role |
| **Sniper** (rifle 60+, +5 at 50+ yds, never full-auto) | Long-range overwatch role |
| **Demolitions** | Charges/claymores/defuse — objective interactions faster & reliable |
| **Intel** | Interrogation/documents — bonus intel extraction at objectives (reveals map info) |
| **Heavy Weapons** (St 80+ to carry mortar) | 60mm mortar team option for big missions |

**Player picks a primary + secondary MOS** as the between-mission "build" — this is the minimal-RPG layer. Squad selection = covering the MOSs you didn't take. Missing MOS = missing verb (no RTO = no fire support; no medic = bandages only).

## 5. Alertness & stealth → the detection system's authentic numbers

Phase 2 gave us the architecture (accumulator + tiers + NoiseBus); RECON supplies Vietnam-authentic values:

- **Terrain sight caps** (p.25/39): open/paddy **600 yds**, forest/scrub **100 yds**, jungle/elephant grass **30 yds**. → TerrainEngine biome drives a global `sight_cap` per position (GameplayGrid vegetation density lookup). This single rule makes jungle the stealth resource and makes the AO's open spaces genuinely dangerous — HLL treeline terror, by the book.
- **Weather & moon rolls** (1d10 each, p.25): the mission generator rolls weather + moon phase at briefing; the visibility table (clear day 600 → heavy rain ~25 → fog 15 yds; night by moon phase) scales `sight_cap` globally. **Night + new moon + rain = a genuinely different mission.** Starlight scope negates night caps for its user (sniper MOS gear).
- **Movement-rate table** (p.36) → detection profile per stance: run (loud, full speed), walk (½), quiet walk (¼ speed, low noise), night quiet walk (1/5), crawl (1/10, minimal). Direct mapping to NoiseBus footstep radii and awareness-gain multipliers. Sprinting at night risks stumbling (Ag check → trip prone) — keep as a rare stumble event, it's fantastic.
- **Silent movement loop** (p.6, 36): your noise roll fails → *sentry's* Al decides if he reacts. Real-time: footstep noise events roll against each hearer's `sound_awareness` — already specced; RECON confirms sentries should NOT investigate every noise.
- **Muzzle flash reveals position at night** (p.25) → firing at night spikes your visibility accumulator contribution to everyone with LOS; suppressors damp it. **Firing blind = 1%** → AI suppressive fire into concealment is possible but rarely lethal (matches our foliage-blocks-sight-not-bullets rule).
- **Suppressor audibility in feet** (p.25/40): 9mm SMG heard at **30 ft**, and the sound *isn't identifiable as gunfire* — hearers get a curiosity check, not an alert. → suppressed weapons emit `misc` noise (priority 1) at ~10m instead of `gunshot` (priority 7) at 50m. Sten/Hi-Standard loadouts become real infiltration tools.
- **Point-blank suppressed head shot = instant kill** (≤5 ft, p.25) + **sentry removal** (p.32: silent approach to 3 ft, Ag roll = silent kill; failure = target gets initiative *and may yell*) → the melee/CQB takedown system: approach undetected, contextual takedown with success chance from Ag+skill; failure = struggle + the victim's scream is an `urgent_voice` noise event. Risk-reward exactly as written.
- **Illumination flares** (p.25): 6-CR (30s) light, 20-yd circle, defenders inside lose night vision and fire blind outward → flares as AI escalation response AND player tool; being inside light = massive visibility spike, standing outside it looking in = advantage.

## 6. Combat tables → gunplay & AI accuracy modifiers

RECON's posture/range modifier tables (p.39) become the shared modifier model for BOTH player weapon spread and AI hit probability:

- **Range bands per weapon class** (pistol/SMG useless past 30 yds; rifles full table to 500; shotgun ≤20) → per-class effective-range falloff curves. Cross-check with RealVietnamRTS's `vietnam_weapon_data.gd` ranges (realism-tuned) — RTS data for hard numbers, RECON for the *shape*.
- **Shooter posture:** prone/braced 0 → kneeling → standing → running → full-auto worst (−20…−45) → stance-driven spread/sway multipliers. **"If doing two things, use only the worse modifier"** — elegant: running-and-spraying is one big penalty, not stacked.
- **Target posture:** standing easiest → prone/behind-object hardest (and switches to the upper-body-only hit chart) → AI hit probability vs the player rewards going prone; hits on a prone target roll the upper-body location chart (head/chest/arms only — prone is safer overall but head-weighted. Authentic and chilling).
- **Rate of fire caps** (p.39: AR 5/CR full-auto = ~1 aimed round/sec at 5s CR; MG 7, pigman 10) → these aren't cyclic rates; they're *effective aimed fire* rates. Use for AI fire discipline pacing (bursts, pauses) — matches the exposure-ramp accuracy design.
- **Weapon Check** (p.25 — MD calls it, fail Al = empty mag or jam) → the jam/stoppage system: small per-magazine stoppage chance, weighted by weapon (VC bolt guns vs M-16 early-war reputation), cleared with a half-reload-length action. The *Alertness* flavor (did YOU keep track?) survives as: HUD never shows exact round count (diegetic ammo — weight-check a mag), unless a perk sharpens it.

## 7. Hit locations & damage → the damage model

Direct extension of HoD's existing hitzone system:

- **Zones from the 2d100 chart** (p.40): Brain 2% of body-facing hits = instant death; head-parts (eyes/nose/jaw/larynx); chest 20%; abdomen 15%; groin 4%; limbs subdivided (shoulder/upper arm/elbow/forearm/wrist/hand). → Extend HoD's 6 hitzones to ~10 (head-fatal, head-wound, chest, abdomen, groin, per-limb upper/lower): the sub-zones give us **wound effects**:
  - **Hand/arm hits degrade weapon handling** (p.9: −1% per damage point to that hand) → arm wounds = sway/reload penalties
  - **Leg/foot hits halve movement** (punji rule, p.28) → leg wounds = limp, no sprint
  - Larynx/jaw → can't call out (squadmate can't bark warnings!)
- **Damage dice** (p.40): AK/SKS 4d10 (avg 22), M-14/M-60 4d10+5, 5.56 5d10 (tumbling round, avg 27.5), .45 4d10, 9mm 3d10+5, .50 **2d100**, 12ga point-blank 2d100. Against ~101-St humans: 2–4 torso rifle hits down a man; any head hit ~fatal. This is *slightly less* lethal than HoD's current tuning (Thompson 46–51/hit) — RECON's model gives more **wounded states** (the medic economy needs wounded men, not corpses). **Adopt RECON dice + zone multipliers tuned so: brain instant, chest 2–3 rifle hits, limbs wound-and-degrade.** Flak vest reduces chest/abdomen by 5/hit (marginal, authentic — armor is NOT protection in this game).
- **Bleed-out:** book has none (0 = unconscious). Keep HoD's bleed-out timer — it's our tension mechanic and the medic's deadline.
- **Explosives** (pp.27–29, 41–43): grenade 2d100 at 1 yd, ÷distance in yards; claymore 2d100+20 in a 12×8-yd triangle; mortars/arty with fatal-radius rings by caliber; WP burns 3 CRs; structures matrix (what ordnance destroys bamboo/wood/brick/concrete + cover values Full/Reduced/Concussion) → drives destructible buildings (RealVietnamRTS `building_data.gd` destruction states) and the cover-vs-caliber model.

## 8. Support calls → the RTO verb set

Pages 29–30 + 43 give complete, game-ready fire-support procedures:

- **Artillery (FO skill):** call grid → first rounds land on a *coarse* grid roll (inaccurate) → correct fire in ~15s steps (3-CR delay) walking onto target. Bad call = rounds land where you called them (danger close is real). → The radioman support-call minigame: map-click, spotting round, correction clicks, accuracy driven by FO skill. Both a player verb AND the enemy escalation mortar system (same code, enemy FO).
- **TACAIR (FAC skill):** response in minutes not seconds — only useful when pinned/planned; smoke grenade marks for a precise first run. Strafing/napalm/bomb damage tables included (20mm = auto-fatal per hit; napalm 2d100+20 along the run).
- **Gunships:** rocket/minigun/GL runs.
- Mission generator hooks: support availability rolled at briefing by mission type/region (deep SOG insert = maybe nothing; big op = priority arty + air on call). **No RTO alive = none of it works.**

## 9. Insertion tables → the live insertion layer

The LZ tables (p.36) are the insertion-complication system we designed in Phase 1 — with authentic outcomes:

- **Helicopter LZ table:** cold LZ / tight LZ (rappel in) / **VC spotter with bamboo telegraph** (invisible tail who signals guerrillas until dealt with — a *fantastic* generated complication: the AO's alert level creeps up until the team finds him) / VC spotter with rifle (potshots) / hot LZ.
- **Hot LZ table:** outcomes from light damage/wounded crew through *abort to alternate LZ* through **chopper downed, crew dead/injured** → maps 1:1 to our live AA design: outcomes emerge from simulation (AA sites, route), and the *distribution* of RECON's table calibrates how often each should happen. Chopper down = crash-site E&E mission mutation (already decided).
- **Airborne/HALO and SCUBA/PBR insertion** rules exist (scatter on the DZ grid, injury %, underwater nav) → later-milestone insertion variants (night HALO SOG inserts, riverine ops with the PBR rules p.16).
- **Extraction:** McGuire/STABO rig references (extraction without landing) → exfil variants for canopy/no-LZ situations; "fewer contacts on withdrawal, tapering" (p.6) → post-objective spawn-weighting rule (with our Phase 2 heat system layered on).

## 10. Contact tables → the ambient AO population layer

**This edition has NO mission-generation table** — its generator is the *contact system*, and that's actually the more valuable thing for us: it populates the world between objectives. Design translation — the AO generator seeds, along patrol/trail/river graph edges:

- **Jungle path contacts** (p.37): possible ambush site → generator marks real ambush-suitable geometry (and sometimes populates it — 1-in-10 = prepared ambush, 1d10+2 enemies); noises up trail; *sudden quiet* (jungle SFX layer mutes = diegetic warning); distant gunfire (fake or real war-ambience); weather change; civilian/animal/guerrilla/ville sub-rolls.
- **Guerrilla contact table** (1d10 enemies): medics with wounded, propaganda team, **tax collector with escort**, guards with a prisoner (emergent rescue opportunity!), supply unit eating, unit bathing, patrol ahead, **patrol behind you**, mine/boobytrap/ambush. → The generator's wandering-encounter deck: small vulnerable enemy groups doing *jobs*, not waiting to fight. This is what makes the AO feel like a war is happening — Boiling Point energy, by 1982 tables.
- **Civilian contacts:** woodcutters, hunters (might shoot!), refugees, bandits/smugglers, deserters-or-VC ambiguity, old woman with chickens... with the killer rule: **on a 10, civilians inform local guerrillas within 1d10×6 minutes** → civilians as a live stealth factor: let them see you and walk away, and the region's alert level rises on a timer. No civilian-killing mechanic needed for it to create the dilemma — avoidance is the skill.
- **Ville table** (3d10 hootches, 2d10 papa-sans, 4d10 mama-sans, 4d10+5 kids; deserted-burned / deserted-ambush / friendly / indifferent / hostile / villagers-freeze): → village site generator (RealVietnamRTS village .glbs) + attitude state affecting intel (rumors), informing risk, and whether guerrillas cache/ambush there. **Rumors table** (may be true, mistaken, or lies; Intel MOS detects lies) → village intel-gathering verb feeding map reveals.
- **Animals** (monkeys bolting, bird flocks, snakes, boar...): ambience + tells (wildlife going quiet near enemies — our Phase 2 "tension in the valleys" content, straight from the book).
- **Enemy quality table** (p.37): **Local Force** (militia: base stats only) / **Main Force** (+5% skills, 1-in-3 grenades, 1-in-10 MG) / **NVA** (+10%, RPG 1-in-20) → our three archetype tiers with authentic kit-density ratios. Region on the province map determines the mix — border/trail regions roll NVA, pacified regions roll Local Force.

## 11. Traps, mines & area denial

p.28 provides the full system: boobytraps (tripwire) vs mines (pressure), Al roll to spot (point man's job), Ag+Disposal to defuse (failure = detonation **+ a contact roll for who heard it**), punji pits (2d10 to the foot, movement halved), claymore doctrine (RON perimeter: outer tripwire ring, inner command ring). →
- Trap placement = generator layer on trails/approaches (density by region VC control)
- Point man MOS = the counter; spotted traps get marked diegetically
- **Player claymores** for ambushes and LZ defense (exfil prep phase — CoD4 template, RECON rules)
- Punji/trap wounds create the medic-economy pressure without firefights

## 12. Experience & progression → the campaign layer

Adopt the team-pool XP system (pp.20–21) as the debrief screen, nearly verbatim:
```
+ 10/15/20 per Local/Main Force/NVA enemy operating in the AO (danger pay — placed by generator)
+ 25 per contact successfully avoided        (stealth economy)
− 25 per contact detected                    (excluding hot LZ & mission-required)
+ skill-use incidents (10 small arms / 15 non-weapon / 20 HtH)
− every St of damage the team took (KIA = 2× his St)
÷ team size = each member's share
```
Spend between missions: +1 skill level (HtH 50 / non-weapon 100 / small arms 150 / heavy 200) or **100 pts = +1 St/Ag/Al**. 99% cap; near-cap veterans "rotate stateside" → a **roster retirement mechanic**: your best men eventually go home (alive, a win!) — beautiful permadeath-lite pressure that generates roster turnover without death.
- Healing **2 St/day** (p.21) → wounded squadmates are unavailable/degraded for N campaign days → the war-state calendar matters; short-handed missions happen (already decided).
- Mercenary economy (pay, living expenses, gear prices p.35) → optional later flavor; requisition (free kit by mission type) is the Vietnam-campaign model. The **gear price list doubles as a loadout-point system** if we want one.

## 13. Turn-based-only mechanics → real-time equivalents

| RECON mechanic | Why it doesn't transfer | Real-time equivalent |
|---|---|---|
| 5s combat round, simultaneous declared fire | continuous time | RoF caps → AI fire-discipline pacing; posture modifiers → continuous spread model |
| 2d100 roll-under per shot | per-shot dice | spread/sway cone sampled per round (same distribution, expressed spatially) |
| MD calls "weapon check" | no MD | per-magazine stoppage probability + diegetic ammo (no exact counter) |
| Hand-to-hand action ladder (1d10 slash/parry/riposte...) | turn minigame | contextual takedown (success by Ag+skill) + short struggle animation on failure; victim may scream (noise event) |
| Grenade scatter on numbered 10×10 grid | dice-grid abstraction | physics throw + skill-driven aim assist/arc display quality |
| MD-narrated terrain, bean-scatter maps | tabletop | TerrainEngine + AO generator |
| Progressive-revelation Al rolls (MD decides when) | MD judgment | the accumulator + point-man automatic checks + scripted reveal triggers |
| XP for "incidents" logged by players | honor system | automatic event logging → debrief screen |
| Safecracking 3-number minigame | too tabletop | timed hold interaction, Intel skill scales speed (or drop) |
| No suppression mechanic in book | (gap, not clash) | KEEP HoD's suppression system — it's needed for MG roles & modern feel |
| No enemy morale | (gap) | Add light morale: Local Force breaks/flees when mauled, NVA doesn't — quality-tier property |

## 14. Edition notes (Revised RECON 1986 / Deluxe 1999 — web research)

Our PDF is the 1982 original (miniatures-derived; RPG rules matured in the 1983 2nd ed digest). Palladium's Revised (152pp, Wujcik) expanded it massively. What the later editions add that we should steal (structure only — 1982 numbers remain primary):

1. **The three-situation firefight model** — the community's most-praised RECON mechanic: every small-arms engagement is classified as **STAND-UP WAR** (both ready), **TURKEY SHOOT** (you ambush them — the only time full skill applies), or **AMBUSHED** (caught — firing while running for cover at −80). All cover/posture/surprise modifiers compress into these three states. → FPS translation: this is the *engagement-opening asymmetry layer* on top of our exposure-ramp accuracy: whoever initiates from undetected gets full effectiveness for the opening seconds; the ambushed side (AI **and player**) suffers a massive effectiveness penalty until they reach cover/recover. It's why ambushes in RECON are lethal and why setting them up is the game. Also drives the squad HOLD-FIRE order's value: a coordinated first volley is a Turkey Shoot.
2. **Mission taxonomy: RAID / SECURITY / TRANSPORTATION** — the generator's top level. RAID = damage a target (DESTROY, ASSASSINATE, HOLD); SECURITY = intel, fight only opportunistically (RECON, RETRIEVE, wire tap); TRANSPORTATION = get something from A to B undetected (RESCUE, snatch, dead drop, cross-AO movement). Category sets the AO's default posture, scoring weights, and support availability.
3. **Briefing skeleton — 7 standard elements:** insertion method, fire support availability, enemy movement intel, terrain & weather, objectives, special rules, extraction procedure — **and briefing intel may be deliberately false** (quality by source). → the briefing screen spec, verbatim. Intel accuracy as a rolled mission property feeds our AA-site-reveal and patrol-marking systems.
4. **Sentry alertness fluctuation table** (−5 to −30 boredom cycles) → RELAXED-tier NPCs oscillate their perception multiplier on slow cycles (bored sentry ≠ fresh sentry). Ready-made stealth-AI texture; trivially added to the accumulator.
5. **Terrain region tables** (Highland Forest ~100ft daytime visibility / Jungle / Swamp) + **1d100 village-disposition table** (deserted-burned → tribal loyal-to-SF-hostile-to-ARVN → recently-VC-aligned) → region presets for TerrainEngine biome + our ville generator's attitude roll.
6. **Tunnel complex generator** (from Hearts & Minds, retained by Palladium) → later-milestone tunnel objective sites (we have the RTS tunnel entrance/spider-hole models).
7. **Helicopter Combat Table** (every landing/low pass over hostile ground risks a problem; VC ambush LZs, mined treetops) → corroborates the Hot LZ system; insertion risk applies per low pass, not once.
8. **Lethality architecture cross-check (important):** the Revised *RPG* rules have **no instant-kill mechanism** — damage 2d10–5d10+15 vs St, "one bullet will rarely kill you." The hit-location instant-kill layer lives in the **original miniatures rules** (our PDF's chart, §7). RECON's lethal reputation actually comes from **ambush asymmetry + automatic-weapon volume + heavy weapons**, not per-bullet damage. This resolves our §15.1 tuning question: adopt RECON dice (wounded-friendly) + the miniatures hit-location fatals (brain/head) + the three-situation asymmetry — lethality emerges from *situation*, exactly like Hell Let Loose.
9. **Tone (community consensus):** the original's non-heroic framing — disposable characters "just trying to stay alive," fast replacement chargen as the answer to lethality — is what made it memorable (and Palladium's Hollywood sanitization is the recurring gripe). Our permadeath-lite roster + rotate-stateside retirement carries that DNA; keep the grim-grunt tone, not action-hero.
10. Progression cross-check: Revised XP = 35 pts → +5% skill, shallow by design. Matches our flat, minimal-RPG intent.

---

## 15. What Phase 4 must reconcile
1. Damage retuning: RECON dice (wound-friendly) vs HoD current (kill-friendly) — recommend RECON dice + bleed-out, so the medic loop matters.
2. RECON's 30-yd jungle sight cap vs fun engagement ranges — likely tune caps up slightly for gameplay (45–60m jungle) while keeping the *ratios*.
3. Which MOSs exist at first-slice (Point, RTO, Medic minimum — they're the mission-loop verbs) vs later (SCUBA, Heavy Weapons, Intel).
4. Contact-table cadence in real space: encounters per km² per alert level (RECON is per-time-interval on a march; we need per-area densities).
5. XP incident values vs pacing (auto-logged events will fire far more often than tabletop bookkeeping — normalize).
