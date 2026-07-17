# RECONgame — THE BIBLE (index of record)

**Purpose:** the strict, canonical spec every decision must obey. `DESIGN.md` is the vision;
this Bible is the *enforced detail* per section. If code contradicts the Bible, the code is wrong
(or the Bible gets an amended decision — never a silent drift).

**Law:** every section obeys the 5 Pillars (see `00_PILLARS`). No section may violate a Pillar.

**Companion docs:** `../../DESIGN.md` (vision + M0–M8), `../../STATE_OF_PROJECT.md` (what exists),
`../../MISSION_DESIGN_RESEARCH.md` (AI/pacing), `../../RECON_ADAPTATION.md` (tabletop→realtime),

**Cinematic Direction (DRAFT — see ADR-024):** late-1998-to-2003 prerendered military cinematics
(Medal of Honor 1999, MoH Underground, Hidden & Dangerous, Operation Flashpoint, Rainbow Six
Rogue Spear, Delta Force, Half-Life intro, RE prerendered, MGS, FF8 FMVs, C&C Tiberian Sun,
Ghost Recon 2001). Eevee Next, 640×480 or 720×480, 24 fps. Slow dolly/crane/locked tripod,
4–10 s shot pacing, restrained acting, three-light rig, muted palette, atmosphere over spectacle.
Five archetypes: Operation Briefings / Insertion / Combat Intros / After-Action / Death Sequences.
Full text and director contract: `../adr/ADR-024-cinematic-direction.md`. **Status:** DRAFT
pending Summoner ratification.
`../../ROADMAP.md` (sequenced build order + asset track).

**Status legend:** ✅ canon written · 🌱 seeded (this file has the canon bullets, expand to own doc) · ⬜ stub (expand next session)

---

## Section map

| # | Section | File | Status | Covers |
|---|---------|------|--------|--------|
| 00 | Pillars & Laws | `00_PILLARS.md` | 🌱 | the 5 pillars, the test-every-decision law, fairness rules |
| 01 | Game Loop | `01_GAME_LOOP.md` | 🌱 | operation-style front door → campaign hub → mission loop → debrief |
| 02 | Gunplay & Damage | `02_GUNPLAY_DAMAGE.md` | ⬜ | weapons, ballistics, RECON dice, hitzones, falloff, 3-situation asymmetry, stoppages |
| 03 | Detection & Enemy AI | `03_AI_DETECTION.md` | ⬜ | 4 alert tiers, accumulator, NoiseBus, hybrid FSM, archetypes, cover, EnemySquad, escalation |
| 04 | Squad (the RPG) | `04_SQUAD.md` | ⬜ | MOS verbs (Point/RTO/Medic…), 5 orders, revive chain, permadeath, buddy rules |
| 05 | Campaign & Roster | `05_CAMPAIGN_ROSTER.md` | ✅ | operation styles (SF/Army/Marines), HQ tent, province/war-state, 100 bios, persistence, XP economy |
| 06 | Mission Generation | `06_MISSION_GEN.md` | ⬜ | taxonomy, 2–4 objectives, site pass, contact deck, **scripted events**, intensity curve, rolls |
| 07 | Insertion & Exfil | `07_INSERT_EXFIL.md` | ⬜ | Huey ride, AA/hot-LZ, exfil archetypes, **driveable vehicles**, boarding dash |
| 08 | World & Terrain | `08_WORLD_TERRAIN.md` | 🌱 | TerrainEngine FPS profile, site stamps, **roads**, firebase realism, **barbwire/hazards**, sight caps |
| 09 | Characters & Art | `09_CHARACTERS_ART.md` | ✅ | 3D + FP viewmodel pipeline, **faction models, soldier variety, slimmer topology**, civilians, sprites |
| 10 | UI & Audio | `10_UI_AUDIO.md` | ⬜ | diegetic-first HUD, barks, jungle beds, weapon synth bank, radio VO |
| 11 | Support & Fire Missions | `11_SUPPORT_FIRE.md` | ⬜ | RTO-gated arty (spot→correct), TACAIR, illum, enemy mortars |

**Fill order (next sessions):** 00 → 01 → 02 → 03 → 04 → 06 → the rest. 05 and 09 are written now
(they hold tonight's campaign + asset notes). Each ⬜ expands from its `DESIGN.md §4.x` source + its beads.

---

## 00 · Pillars & Laws (🌱 seed — promote to `00_PILLARS.md`)

The five, from `DESIGN.md §1`. **Test every decision against these; the Arbiter guards them.**
1. **Outstanding gunplay** — HLL lethality; death from *situation* (ambush asymmetry, exposure, volume of fire), not bullet sponges.
2. **Atmosphere** — dense jungle, weather, night, audio; the AO feels like a war is happening around you.
3. **Freedom** — open AO; objectives are places/things; any route, any order, loud or quiet; stealth is an economy, never a gate; nothing on rails.
4. **The squad is the RPG** — named persistent teammates with MOS roles who improve, get wounded, rotate home, and die for real. Minimal stats, maximal attachment.
5. **Fail forward** — detection escalates, failure mutates, a dead mission generates the next story. Never reload-and-memorize.

**Fairness law (DESIGN §4.2):** alert ≠ accuracy; AI accuracy ramps with player exposure; first shot at an unaware player is a near-miss; muzzle flash / tracers / vocalizations always telegraph.

**Tonal north star:** the **grunt-infantry film canon — Platoon · Hamburger Hill · Apocalypse Now** (plus
Men of Valor / SOCOM flavor from DESIGN §1). Attrition, dread, moral weight, boredom-then-terror, the squad
as your only anchor. Worn and unglamorous — you are a line grunt, not a clean-kit operator. (SF/Marines = DLC.)

**Process law:** finished work closes its bead with a one-line resolution; the Bible is amended by explicit decision, never by drift.

---

## 01 · Game Loop (🌱 seed — promote to `01_GAME_LOOP.md`)

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

**Campaign layer (the "open world," DESIGN §2):** persistent province map (villages, firebases,
VC/NVA zones, trails, a war state that shifts with outcomes). From the **HQ tent / firebase hub**:
pick an operation (weighted offers + forced events) → manage roster → spend team XP → loadout.

**Mission loop (DESIGN §2):** `BRIEFING (7 RECON elements, intel-accuracy rolled) → INSERT (Huey on chosen
route) → PLAY (open 1–1.5km AO, 2–4 live objectives, detection/escalation, squad orders, fire support) →
EXFIL (player-triggered, archetype weighted by heat, boarding dash) → DEBRIEF (RECON scoring, XP, roster
consequences, war-state update)`. Mission grammar: quiet approach → recon ring → objective spike → lull →
escalation → heat-scaled exfil → boarding catharsis.
