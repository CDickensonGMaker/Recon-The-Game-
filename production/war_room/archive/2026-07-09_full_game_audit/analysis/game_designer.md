# GAME DESIGNER — Independent Analysis (Full Game Audit, 2026-07-09)

**Lens:** the player's experience. What does one session feel like? What does mission ten feel like?
All claims grounded in file:line. Branch `overnight-claude`.

---

## The loop as actually built (verified, not aspirational)

Menu → 3 seeded offers (`mission_select.gd:14-45`) → 7-element briefing (`briefing.gd:15-59`) → Huey
insertion ride (`game_flow.gd:183-187`) → open AO with 1-4 objectives + ambient patrols/villages/craters
(`mission_generator.gd:463-518`) → detection-gated hunter escalation (`mission_director.gd:57-96`) →
exfil with wave-off/shoot-down/fallback drama (`exfil_zone.gd:160-193`) → scored debrief
(`debrief.gd:21-31`) → team XP banked, roster consequences committed (`game_flow.gd:197-213`).

**Verdict on fun:** the *mission* arc is genuinely fun-shaped. Quiet walk → contact spike → escalation →
exfil catharsis is real and emergent, and the exfil can go wrong in dramatic, fail-forward ways
(bird shot down → "FALLBACK LZ IS YOUR ONLY WAY OUT", `exfil_zone.gd:172-180`). The *campaign* arc is a
flat line: nothing changes after mission 3 except numbers going up on your side only.

---

## (a) Top 5 strengths

1. **The exfil is the best moment in the game.** LZ compromise roll while the bird is inbound, 35%
   shoot-down, wave-off, fallback-LZ-is-final, door-seat climb-out as the closing shot
   (`exfil_zone.gd:61-71, 129-146, 160-193`). This is DESIGN §2's "boarding catharsis" actually shipped.
2. **Stealth is an economy, not a gate.** Escalation triggers only on *detection* (any enemy reaching
   COMBAT), never on a silent kill — "a silent, unwitnessed kill leaves the AO cold"
   (`mission_director.gd:47-71`). Finite hunter pool (12) means you can bleed the AO dry
   (`mission_director.gd:59-61`). Ghost play pays +75 at debrief (`debrief.gd:16-18`). Pillar 3 in code.
3. **Learn-by-doing squad XP is a real attachment engine.** `credit_use` choke-point with promotion
   barks at the moment of the deed (`squad_roster.gd:66-84`), earned rank PVT→SSG by missions survived
   (`squad_roster.gd:124-134`), KIA memorial with rank + confirmed kills (`squad_system.gd:261-268`),
   no blank recruits (`squad_roster.gd:40-58`). The *systems* half of Pillar 4 is the best-designed
   thing in the project.
4. **The RTO is a load-bearing character.** All fire support gated on a *living* RTO within 10m — the
   radio is on his back (`mission_director.gd:166-179, 215`); his `fo_fac` skill tightens the sheaf
   1.0→0.45 and he levels by calling missions (`mission_director.gd:249-279`). Losing one man deletes
   verbs. This is "the squad is the RPG" done with mechanics, not lore.
5. **The walk is alive.** Ambient villages with informer civilians, chickens as noise traps, wandering
   patrols on the insertion corridor, arclight craters with stagnant water, 50% temple-ruin POI, night
   campfires as readable beacons (`mission_generator.gd:463-518, 556-616`). Mid-mission sag is largely
   already solved; a patrol walk has texture.

---

## (b) Top 5 weaknesses — ranked by player-facing damage

1. **The squad is silent — and 162 recorded voice lines sit on disk unwired.**
   Every bark is a HUD toast string (`squad_system.gd:240-256`, `mission_director.gd` throughout).
   Meanwhile `assets/audio/vo/` contains 5 full squad voice sets (contact/man-down/frag-out/on-me/...,
   ~25 lines each) plus a complete RTO radio-procedure set (fire_mission/shot_splash/danger_close/
   dustoff...) — and **zero GDScript references any of them** (grep `vo/` across `*.gd`: no hits; only
   `tools/voice_studio.py` knows the filenames). The single biggest felt absence in the game
   (WIRING_STATUS.md:37 agrees) has its assets already produced. Attachment to named men who never
   speak does not form; toasts read as debug output, not as Doc and Pig.
2. **No campaign arc and no difficulty curve — the game sags at mission ~6, permanently.**
   Nothing scales with `missions_played`: enemy counts are fixed rolls per type
   (`mission_generator.gd:126-250`), the offer card's "ENEMY: LIGHT/MODERATE/HEAVY" is cosmetic — the
   `strength` field is rolled at `mission_select.gd:41` and **never read by `plan()`** (grep: only UI
   files touch it). The one campaign dial, AA threat, only adds AA sites near LZs
   (`mission_generator.gd:446-461`). Your squad compounds skill forever against a flat enemy. There is
   no province, no war state, no calendar, no ending, nothing to win — the offer screen at mission 20
   is the offer screen at mission 1. The mission is a great 25 minutes; the campaign is not yet a game.
3. **Losing a man costs nothing, so permadeath can't hurt.** `ensure_roster` instantly back-fills 5
   living members with free rookies at the next barracks/mission (`squad_roster.gd:88-118`). No wounded
   state, no healing calendar (DESIGN §2's 2 St/day is absent), no replacement delay, no bios — the
   roster dict is name/nick/stats only (`squad_roster.gd:22-33`; the 100-bios bead is open). The KIA
   memorial toast is well-crafted, but the *mechanical* consequence of Doc dying is: a new Doc, free,
   immediately, with rolled skills. Pillar 4's "maximal attachment" loop does not close — grief needs
   a price and a face, and there is neither yet.
4. **The briefing — the loop's front door — is blank or wrong for 2 of 5 mission types.** The match in
   `briefing.gd:21-33` covers only PATROL / VILLAGE_RAID / FIREBASE_DEFENSE. ANTI-AA and RESCUE fall
   through: element 5 prints an empty objectives line and element 2 claims "FIRE SUPPORT: NONE" even
   though rescue carries napalm+mortar (`mission_generator.gd:132`) and anti-AA carries mortar
   (`mission_generator.gd:153`). A player deploying on the game's two most flavorful missions gets a
   seven-element order with a hole where the mission should be. Trust in the briefing is the RECON
   fantasy; this quietly breaks it.
5. **Five mission types, but two grammars — and one type fights Pillar 3.** PATROL = touch 3-4
   checkpoints; VILLAGE_RAID / ANTI_AA / RESCUE = walk to one site, fight one group, press F; FIREBASE =
   survive waves. Objective *sensors* are varied (reach/plant/kill/photo/rescue/survive,
   `mission_generator.gd:336-408`), but DESIGN §3's 2-4 *concurrent* objectives, RAID/SECURITY/
   TRANSPORTATION taxonomy, and contact-deck jobs are still M6 futures. Worse, VILLAGE_RAID's required
   "CLEAR THE VILLAGE" demands killing 80% of defenders (`mission_generator.gd:233`) — a mandatory
   body-count on a nominally open-approach mission. You cannot ghost a raid; stealth gets you to the
   cache and then the design orders you to go loud. That's a fail-state-shaped gate on the freedom pillar.

Honorable mention: orders are squad-wide only (`squad_system.gd:97-101` — `_order_all`), no per-man or
fireteam split; and the open playtest beads (Huey seating, squad controls) sit exactly on the two
systems the player touches most.

---

## (c) The ONE next build: wire the VO bark layer (squad voices + RTO radio procedure)

**What:** a ~1-file `VOManager` (or extension of `audio_manager.gd`, which already has the pooled-3D-
voice infrastructure at `audio_manager.gd:78-88`) mapping existing bark *events* to the existing wav
*sets*: assign each roster member a voice folder at generation, play `squad_contact.wav` where
`_contact_barks()` toasts (`squad_system.gd:240-256`), `squad_movement_ahead.wav` on the point-man
warning (`squad_system.gd:184-201`), `squad_man_down/doc_moving/on_your_feet` through the revive chain
(`squad_system.gd:119-167`), and the full `radio_*` set through `request_fire_support()`
(`mission_director.gd:219-279`).

**Why this over everything else:**
- **Highest fun-per-effort in the codebase.** The expensive halves — line authoring, recording (Piper),
  event detection — are all done. Every bark already fires as a toast; this is routing, not design.
  Days, not weeks.
- **It compounds three pillars at once.** Atmosphere (a war you *hear*), squad-RPG (Doc has a voice
  before he has a face — voice is the cheapest attachment tech there is, cheaper than the character art
  that's still in the Blender queue), and the fire-support fantasy (radio procedure VO turns the T-menu
  from a weapon picker into a *ritual* — DESIGN §4.10 calls audio "load-bearing, not polish").
- **It de-risks everything after it.** Every playtest until launch will be run with ears; feedback on
  gunplay feel, detection fairness, and squad behavior is contaminated while the game is silent.
- The alternatives ranked: the campaign arc (#2) is the bigger *design* hole but is M8-scale work
  deserving its own decree; the squad-loss economy (#3) is next and pairs naturally with the 100-bios
  bead; the briefing fix (#4) is an hour and should just be done in passing, it doesn't need a decree.

---

## (d) Pillar scorecard (1-5, player-experience lens)

| # | Pillar | Score | One line |
|---|--------|:-:|----------|
| 1 | Outstanding gunplay | **3** | Hitzones/falloff/stagger/hitmarker/blood are wired (WIRING_STATUS:17) and lethality is situational, but the feel pass is an open keystone (`wbtd`), flesh-hit sound is placeholder (`gun_fx.gd:197`), and weapons are hitscan pending the ballistics pool — solid skeleton, not yet "outstanding." |
| 2 | Atmosphere | **3** | Weather/time rolls, night ambience, campfires, chickens, crater water, and temple ruins give the AO real texture (`mission_generator.gd:463-518`), but the world is *silent* where it matters — no VO, no positional ambience (bead open), placeholder meshes — atmosphere is currently visual-only and half-volume. |
| 3 | Freedom | **4** | Open AO, any route, detection-not-kills escalation (`mission_director.gd:47-71`), abort-anywhere emergency exfil (`mission_director.gd:154-162`), fallback-LZ ladder — genuinely rail-free; docked one point for VILLAGE_RAID's mandatory 80% kill-count (`mission_generator.gd:233`) and briefings that don't brief two mission types. |
| 4 | The squad is the RPG | **3** | The deepest *systems* in the project (learn-by-doing, ranks, memorial, RTO leash) but the attachment loop doesn't close: no voices (wavs unwired), no bios (bead open), no wounds, and KIA is refunded with a free instant rookie (`squad_roster.gd:88-118`) — mechanically, men are still ammunition. |
| 5 | Fail forward | **3** | Emergency exfil, LZ compromise mutation, revive chain, and non-wipe KIA all fail forward *within* a mission; but failure generates no next story — a failed op logs 4 fields (`campaign_state.gd:117-122`) and vanishes, POW-lost is just -100 points, and player KIA is a plain fail screen, not a crash-site E&E or capture mutation (DESIGN §2's "failure mutates" is still aspiration). |

**Overall:** the mission loop is a good 25-minute game today; the product risk is entirely in the
*repetition* layer — silence, flat campaign, and costless loss. All three are addressable without new
art, and the first one is already sitting in `assets/audio/vo/` waiting for a `load()`.
