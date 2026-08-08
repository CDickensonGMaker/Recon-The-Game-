# RECONgame — THE BIBLE (index of record)

> **STATUS BANNER — as of 2026-07-19.** This Bible was written 2026-07-08 and is **outranked by
> `production/adr/` and `production/GAME_GUIDE.md`** (ADR-014). Where it disagrees with an ADR, the ADR
> wins. Sections below carrying `⛔ SUPERSEDED` describe a loop ADR-029 deleted — read them as history.
> Unbannered sections are still 2026-07-08 opinion unless they cite `file:line`.

**Purpose:** the strict, canonical spec every decision must obey. `DESIGN.md` is the vision;
this Bible is the *enforced detail* per section. **Precedence (ADR-014): ADR → `GAME_GUIDE.md` → this
Bible → `DESIGN.md`.** Where code contradicts the Bible and no ADR governs, that is a finding — file a
bead; never a silent drift in either direction. The Bible does not outrank an ADR or shipped, probed code.

**Law:** every section obeys the 5 Pillars (see `00_PILLARS`). No section may violate a Pillar.

**Companion docs:** `../../DESIGN.md` (vision; it has **no M0–M8 roadmap and no numbered sections** —
every `DESIGN.md §N` pointer in this Bible is dead, see the note under the section map),
`../GAME_GUIDE.md` (the document of record), `../adr/` (the decisions, with evidence).

> **Three former companions were DELETED ON PURPOSE, 2026-07-23 (Summoner):** `STATE_OF_PROJECT.md`,
> `MISSION_DESIGN_RESEARCH.md`, `RECON_ADAPTATION.md`. They were frozen against a game that no longer
> exists and were spoiling the output of work that read them. Do not restore them, do not cite them,
> and treat any surviving reference to them elsewhere in this repo as dead. See CLAUDE.md.

**Cinematic Direction (reference only — no ADR; cinematics are a standalone Blender FMV
production, not a game-side system):** late-1998-to-2003 prerendered military cinematics
(Medal of Honor 1999, MoH Underground, Hidden & Dangerous, Operation Flashpoint, Rainbow Six
Rogue Spear, Delta Force, Half-Life intro, RE prerendered, MGS, FF8 FMVs, C&C Tiberian Sun,
Ghost Recon 2001). Eevee Next, 640×480 or 720×480, 24 fps. Slow dolly/crane/locked tripod,
4–10 s shot pacing, restrained acting, three-light rig, muted palette, atmosphere over spectacle.
Five archetypes: Operation Briefings / Insertion / Combat Intros / After-Action / Death Sequences.
ADR-024 was deleted 2026-07-20 by the Summoner (never built against); these bullets are the
surviving reference. Cinematic work is tracked in beads, not in canon.
`../../ROADMAP.md` (sequenced build order + asset track).

**Status legend:** ✅ canon written · 🌱 seeded (this file has the canon bullets, expand to own doc) · ⬜ stub (expand next session)

---

## Section map

| # | Section | File | Status | Covers |
|---|---------|------|--------|--------|
| 00 | Pillars & Laws | `00_PILLARS.md` | 🌱 | the 5 pillars, the test-every-decision law, fairness rules |
| 01 | Game Loop | `01_GAME_LOOP.md` | ⛔ | **SUPERSEDED by ADR-029** — the operation-style front door, offer card and debrief screen are deleted; the loop is the open patrol |
| 02 | Gunplay & Damage | `02_GUNPLAY_DAMAGE.md` | ⬜ | weapons, ballistics, RECON dice, hitzones, falloff, 3-situation asymmetry, stoppages |
| 03 | Detection & Enemy AI | `03_AI_DETECTION.md` | ⬜ | 4 alert tiers, accumulator, NoiseBus, hybrid FSM, archetypes, cover, EnemySquad, escalation |
| 04 | Squad (the RPG) | `04_SQUAD.md` | ⬜ | MOS verbs (Point/RTO/Medic…), 5 orders, revive chain, permadeath, buddy rules |
| 05 | Campaign & Roster | `05_CAMPAIGN_ROSTER.md` | ✅ | operation styles (SF/Army/Marines), HQ tent, province/war-state, 100 bios, persistence, XP economy |
| 06 | Mission Generation | `06_MISSION_GEN.md` | ⬜ | site pass, contact deck, intensity curve, rolls. **The "taxonomy / 2–4 objectives" framing is dead (ADR-029)** — one type, `"PATROL"` (`scripts/missions/mission_generator.gd:856`) |
| 07 | Insertion & Exfil | `07_INSERT_EXFIL.md` | ⛔ | **SUPERSEDED by ADR-029** — no Huey ride, no exfil step; `scripts/missions/insertion_ride.gd` is deleted |
| 08 | World & Terrain | `08_WORLD_TERRAIN.md` | 🌱 | TerrainEngine FPS profile, site stamps, **roads**, firebase realism, **barbwire/hazards**, sight caps |
| 09 | Characters & Art | `09_CHARACTERS_ART.md` | ✅ | 3D + FP viewmodel pipeline, **faction models, soldier variety, slimmer topology**, civilians, sprites |
| 10 | UI & Audio | `10_UI_AUDIO.md` | ⬜ | diegetic-first HUD, barks, jungle beds, weapon synth bank, radio VO |
| 11 | Support & Fire Missions | `11_SUPPORT_FIRE.md` | ⬜ | RTO-gated arty (spot→correct), TACAIR, illum, enemy mortars |

**Fill order (next sessions):** 00 → 01 → 02 → 03 → 04 → 06 → the rest. 05 and 09 are written now
(they hold the 2026-07-08 campaign + asset notes).

> **DEAD POINTER, corrected 2026-07-19:** this line used to send you to a `DESIGN.md §4.x` source.
> `DESIGN.md` has no numbered sections at all — its headings are prose (`## Pillars`, `## The Player
> Loop`, `## Technology Stack`). Every `DESIGN.md §N` / `DESIGN §N` citation in `production/bible/` and
> `production/adr/` resolves to nothing. Expand a ⬜ section from `production/adr/` + the code + its
> beads, never from a `§` pointer.

---

## 00 · Pillars & Laws (🌱 seed — promote to `00_PILLARS.md`)

> **RULED BY THE SUMMONER, 2026-07-19.** Two texts had competed since the project began: this Bible's
> five and the five under `## Pillars` in `DESIGN.md:67-94`. Neither was a superset — the Bible carried
> **Atmosphere**, which DESIGN.md never had, and DESIGN.md carried **Player as Participant, Not
> Director** (`:84-86`), which the enforced set had silently dropped.
>
> That dropped pillar was load-bearing. Its text — *"they do not puppeteer every soldier; the squad has
> its own AI intent"* — is the constraint the squad was built in violation of, and the Summoner's
> playtest verdict on 2026-07-19 was its symptom: *"it felt like I was driving him."* The law that would
> have prevented it was sitting in the file nobody enforced.
>
> **The ruling: merge, keeping what each set uniquely held.** Participant-not-Director folds into Pillar
> 4, where it binds the AI work. Pillar 1 carries **both halves** — AI behaviour and weapon feel, neither
> subordinate to the other — by explicit ruling; where they compete for a session, that is a judgment
> call, not a precedence rule. `DESIGN.md:67-94` is superseded by this section and carries a pointer to it.

The five below. **Test every decision against these; the Arbiter guards them.**
1. **Believable firefights** — AI that fights like soldiers *and* weapons that kill like weapons, neither subordinate. Squads spread, use cover, suppress and manoeuvre; HLL lethality; death from *situation* (ambush asymmetry, exposure, volume of fire), never bullet sponges. The stress-test arena is the gate: if soldiers cannot fight believably in a deliberately ugly arena, beautiful terrain will not save the game.
2. **Atmosphere** — dense jungle, weather, night, audio; the AO feels like a war is happening around you.
3. **Freedom** — open AO; objectives are places/things; any route, any order, loud or quiet; stealth is an economy, never a gate; nothing on rails. The seeded world generates the tactical problems, so the stories come from what happened here, not from authored setpieces.
4. **The squad is the RPG — and you are IN it, not above it.** Named persistent teammates with MOS roles who improve, get wounded, rotate home, and die for real; minimal stats, maximal attachment. **You are a member of the squad, not its puppeteer** — you suggest movement, call targets, request support, and the squad holds its own AI intent. A design that has you positioning individual men violates this pillar.
   > **PROVISIONAL — under playtest review (Summoner, 2026-07-19).** Pillar 4's second clause is the one
   > pillar he has flagged as open: *"pillar 4 is open to changing as i play test more. if it makes more
   > sense to try to be more tactical with the troopers i will take it that way."* The tension is real —
   > more direct control reads as more tactical, and it also pulls toward rank/progression unlocks
   > (bead `RECONgame-ct72`). Do not treat the anti-puppeteer clause as settled law until he rules from
   > play. The other four pillars are not provisional.
5. **Fail forward** — detection escalates, failure mutates, a dead mission generates the next story. Death matters and soldiers do not respawn as the same person, but this is not a sadism simulator: the medic tries, and the squad endures. Never reload-and-memorize.

**Fairness law** (of record in `../adr/ADR-005-detection-beacon-witness-rule.md` and `../../CLAUDE.md`; the old
`DESIGN §4.2` pointer is dead)**:** alert ≠ accuracy; AI accuracy ramps with player exposure; first shot at an unaware player is a near-miss; muzzle flash / tracers / vocalizations always telegraph.

**Tonal north star:** the **grunt-infantry film canon — Platoon · Hamburger Hill · Apocalypse Now** (plus
Men of Valor / SOCOM flavor; the old `DESIGN §1` pointer is dead — see `DESIGN.md` "Tone" and "One-Sentence Pitch"). Attrition, dread, moral weight, boredom-then-terror, the squad
as your only anchor. Worn and unglamorous — you are a line grunt, not a clean-kit operator. (SF/Marines = DLC.)

**Process law:** finished work closes its bead with a one-line resolution; the Bible is amended by explicit decision, never by drift.

---

## 01 · Game Loop — ⛔ SUPERSEDED BY ADR-029 (kept as history, 2026-07-19)

> The Operation-Style front door was **never built and is now out of scope**: launch is ONE faction, the
> Army grunt (`05` below), and ADR-029 removed the front-door screen stack entirely. Below is the
> 2026-07-08 proposal, retained only to explain the vocabulary in older docs.

**NEW front door (2026-07-08 decision, pending War Room):** the *first* choice each campaign is
**Operation Style** — Special Forces / Regular Army / Marines. It sets: soldier model set, starting
kit + requisition, MOS mix, mission-offer weighting, and flavor. This wraps the existing loop; it is a
**loop-structure change** and must pass a War Room gate before build (see `ROADMAP.md`). Canon detail: `05`.

---

## 08 · World & Terrain — Roads (🌱 seed — promote to `08_WORLD_TERRAIN.md`)

**Roads give vehicles a reason.** Dirt roads run from the **firebase** to nearby **villages/outposts**,
so driving has a destination and the convoy car-bomb event has a road to stage on.
- **Tech (borrowed from RealVietnamRTS, copied-in — never edit the RTS):** `road_network.gd`
  (waypoint graph, road types dirt-trail→PSP, states intact/damaged/**cratered**/blocked, `find_path()`)
  + `road_segment_node.gd` (path-following mesh strip + vehicle speed bonus).
- **Generation:** a road pass in `site_planner.gd` after sites stamp — route `firebase.center → site.center`
  through the `GameplayGrid`, avoiding WATER/CLIFF (same query `find_site` uses). Endpoints live in `placed_sites[]`.
- **Visual:** muddy **laterite (red-clay)** road material; **tire-track decals** scattered along it via the
  `ground_clutter.gd` pattern — random offset/yaw, **color-matched to the mud so they blend, colors kept consistent**.
- **Later:** explosions crater the road (DamageSystem hook), slowing/blocking convoys. Bead: `RECONgame` ROADS.

Other 08 canon (barbwire hazard, sight caps, firebase realism, FPS terrain profile) still to write.

---

## ⛔ SUPERSEDED BY ADR-029 — the offer/briefing/exfil loop (kept as history, 2026-07-19)

> **This whole block describes a loop that no longer exists in the game.** ADR-029 replaced it with the
> **open patrol simulator**: no briefing UI, no offer card, no objective counter, no exfil step. The
> generator produces exactly one mission type — `"PATROL"` (`scripts/missions/mission_generator.gd:856`).
> Read below only to understand where the old vocabulary in other docs came from. **Do not build from it.**
> The `DESIGN §2` citations it carried are dead pointers (`DESIGN.md` has no numbered sections).

**Campaign layer (the "open world"):** persistent province map (villages, firebases,
VC/NVA zones, trails, a war state that shifts with outcomes). From the **HQ tent / firebase hub**:
pick an operation (weighted offers + forced events) → manage roster → spend team XP → loadout.

**Mission loop:** `BRIEFING (7 RECON elements, intel-accuracy rolled) → INSERT (Huey on chosen
route) → PLAY (open 1–1.5km AO, 2–4 live objectives, detection/escalation, squad orders, fire support) →
EXFIL (player-triggered, archetype weighted by heat, boarding dash) → DEBRIEF (RECON scoring, XP, roster
consequences, war-state update)`. Mission grammar: quiet approach → recon ring → objective spike → lull →
escalation → heat-scaled exfil → boarding catharsis.
