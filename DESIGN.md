# DESIGN.md — Vietnam Mission FPS (working title)

**Date:** 2026-07-07 (Phase 4 synthesis)
**Companion docs:** `STATE_OF_PROJECT.md` (what exists / decisions log) · `MISSION_DESIGN_RESEARCH.md` (RTCW/MoHAA architecture + pacing rules) · `RECON_ADAPTATION.md` (rules layer)
**Status: AWAITING APPROVAL — no implementation until Caleb signs off on this document.**

---

## 1. Vision

A **hardcore Vietnam War tactical sandbox**: Arma/OFP bones, SOCOM/Vietcong/Men of Valor flavor, FNV-style persistent campaign layer, CoD/MoHAA audio-visual punch delivered by systems (an AI director), never by rails. Repeatable generated missions — briefing → insertion → 2–4 objectives in an open AO → exfil → debrief — on dense jungle terrain, with an AI fireteam you order, maintain, and lose.

**Pillars (every decision is tested against these):**
1. **Outstanding gunplay** — HLL lethality; death comes from *situation* (ambush asymmetry, exposure, volume of fire), not bullet sponges.
2. **Atmosphere** — dense jungle, weather, night, audio. The AO feels like a war is happening around you.
3. **Freedom** — open AO, objectives are places/things in the world, any route, any order, loud or quiet. Stealth is an economy, never a gate. Nothing is on rails.
4. **The squad is the RPG** — named persistent teammates with MOS roles who improve, get wounded, rotate home, and die for real. Minimal stats, maximal attachment.
5. **Fail forward** — detection escalates, failure mutates, death of the mission generates the next story. Never reload-and-memorize.

---

## 2. The game loop

### Campaign layer (between missions — the "open world")
Persistent **province map**: villages, firebases, NVA/VC-controlled zones, trail networks, a war state that shifts with mission outcomes. From the firebase hub:
1. **Pick an operation** — generated mission offers (weighted by war state) + occasional forced events (firebase defense when a zone gets hot).
2. **Squad management** — roster of named soldiers with St/Ag/Al + MOS + skills; wounded heal at 2 St/day on the calendar; veterans near skill-cap rotate stateside; dead are gone; green replacements arrive.
3. **Spend team XP** (RECON pool economy) on skills/attributes. **Loadout** by MOS + requisition.

### Mission loop (the game)
```
BRIEFING  — 7 elements (RECON): insertion, fire support, enemy intel (accuracy rolled —
            may be wrong), terrain & weather roll, objectives, special rules, extraction.
            Player picks LZ + ingress route on the AO map.
INSERT    — Huey ride on the chosen route (live AA layer, later milestone; abstracted in slice).
            Hot-LZ outcomes emerge from simulation; shoot-down mutates mission to crash-site E&E.
PLAY      — open AO, 1–1.5km: 2–4 objectives live simultaneously, ambient contact layer,
            detection/escalation ladder, squad orders, fire support via RTO.
EXFIL     — player-triggered radio call; archetype (hold-LZ / gauntlet / quiet walk-on)
            weighted by heat. Boarding dash. ABORT to emergency exfil always available.
DEBRIEF   — RECON scoring (+avoided/−detected contacts, −St lost, objective credit),
            XP pool, roster consequences, war-state update.
```
Mission grammar enforced by the generator (research doc §9): quiet approach → recon ring → objective spike → lull → escalation across objectives → heat-scaled exfil → boarding catharsis.

---

## 3. Architecture overview (four layers)

1. **Province/strategic layer** — data + UI only (map screen, war state, roster, calendar). No 3D simulation.
2. **AO generation** — TerrainEngine (forked into this repo) generates the 1–1.5km mission area from a seed derived from the province location + mission roll: biome/region preset (Highland Forest / Jungle / Swamp / paddy lowland), rivers, trails (GameplayGrid), then the **site pass** stamps objective compounds, villes, LZs, trap/ambush markers using the RealVietnamRTS structure library.
3. **Mission generation** — taxonomy RAID / SECURITY / TRANSPORTATION → 2–4 objectives (DESTROY, RETRIEVE, ASSASSINATE, RESCUE, RECON, HOLD — no duplicates, RECON only first, ≤1 HOLD) → population plan (archetype tiers by region: Local Force / Main Force / NVA), dormant groups, patrol routes, alarm carriers, contact deck, escalation menu, exfil node + fallback LZ, weather/moon roll, intel-accuracy roll.
4. **Tactical runtime** — MissionDirector (event bus + await-based sequencing), MissionState (objective bitmask + accums + manpower pool + heat), NoiseBus, alert-tier AI, squad system, support calls, scoring logger.

---

## 4. System specs (condensed — details live in the research docs)

### 4.1 Terrain (FPS profile — additions to the fork, config-driven)
Eye-height camera; near-chunk blocking collision + tree trunk capsules (nearest chunks only); navmesh baking enabled per-chunk near AI (the code exists, commented out); near-player foliage density up + undergrowth layer, billboards pushed out; near-camera terrain detail tier; ground-texture elevation fade removed for FPS profile; fixed mission seed; **sight caps from vegetation density** (RECON ratios, tuned up: open ~500m, forest ~90m, jungle ~45m) scaled globally by the weather/moon roll.

### 4.2 Detection & stealth (MISSION_DESIGN_RESEARCH §5 + RECON §5)
Four tiers RELAXED→SUSPICIOUS→ALERT→COMBAT; visibility accumulator (stance/motion/foliage modifiers, reaction-time gate, query escalation memory, believed-position aiming, breadcrumb search); NoiseBus with typed radii/priorities (suppressed = unidentifiable `misc` noise); alert propagation local (vis-sharing, corpse discovery, alarm runners with radio/flare — killable counterplay); sentry boredom oscillation on RELAXED. Escalation menu on HQ alarm: finite-pool QRF, walking mortars on last-known position (audible warning), patrol doubling, objective hardening. Civilians inform on a timer if they see you and walk away. Undetected play pays at debrief and at exfil. **Fairness rules:** alert ≠ accuracy; exposure-ramped AI accuracy; first shot at an unaware player is a near-miss; muzzle flash/tracers/vocalizations always telegraph.

### 4.3 Gunplay & damage (RECON §6–7 + HoD systems)
Projectile ballistics for rifles+ (resurrect HoD's pooled projectile subsystem), hitscan acceptable ≤ pistol ranges. Weapon data from RealVietnamRTS `vietnam_weapon_data.gd` (30+ Vietnam weapons) mapped into HoD's WeaponData resources; RECON posture/range modifier *shape* for spread; stance + movement penalties ("worst modifier only"); per-magazine stoppage roll (weapon-weighted); diegetic ammo (no exact counter; mag-check action). **Three-situation asymmetry:** undetected initiator gets full effectiveness for the opening engagement; the ambushed side (AI and player) suffers a heavy effectiveness penalty until in cover — this is where HLL lethality comes from. Damage: RECON dice (AK 4d10, 5.56 5d10, .50 2d100…) vs ~2d100 St pools; ~10 hitzones with wound effects (arm = handling penalty, leg = no sprint/limp, larynx = no callouts, brain/head = fatal); bleed-out timer retained (medic deadline); pain-quota stagger for hit feedback.

### 4.4 Enemy AI
Hybrid architecture (decided): HoD's goal-scoring FSM as the COMBAT brain, wrapped in the MoHAA situation-priority stack (idle/suspicious/combat/grenade/pain/dead with suspend-resume) + personality maps per archetype. Archetype resources (Local Force / Main Force regular / NVA / sapper / sniper) seeded from RTS `vietnam_unit_data.gd` + RECON quality tiers (kit density: grenades 1-in-3, MG 1-in-10, RPG 1-in-20 for NVA). Cover claims (fixes HoD's stub), navmesh steering (finally wire NavigationAgent3D), turret-retarget ladder for defenders, pre-placed dormant populations + out-of-sight QRF spawners, leashes everywhere, think/perception time-slicing, brain LOD. Enemies do *jobs* (contact deck: supply parties, medics, tax collector, prisoner escort) — the war exists without the player.

### 4.5 Squad (the RPG)
2–4 AI teammates; MOS roles = verbs: **Point** (trap/ambush warnings, hand signals), **RTO** (exfil + arty/air calls — lose him, lose the verbs), **Medic** (Pacific-Assault revive chain: limited per-wound treatment, channel time, must reach you), Pigman/Grenadier/Sniper/Demo as roster variety. Orders from slice one: FOLLOW / HOLD / MOVE-TO / ENGAGE / HOLD-FIRE (point-command + 4 keys). Behavior-tree framework (from RTS) for squadmates. Buddy rules: never break player stealth (perception-exempt while undetected), never block doors/trails/muzzle lines, honest enemy threat distribution, effective-but-not-kill-stealing, barks as the primary detection/status UI. Squad deaths permanent; drag-to-cover + tags beat; roster consequences.

### 4.6 Missions, objectives, triggers, sequences
MissionState objective bitmask + sensor scenes per objective type; exfil gated on required mask; every completion flips world state visibly. MissionTrigger (Area3D, full RTCW/MoHAA property set); ScriptedSequence = await-chains with interrupt semantics; name-based Directory indirection so the generator stamps prefab behaviors onto spawned NPCs; accum counters with guard-aborts (no expression language). Concurrent objective watchers (open AO), linear only within an objective.

### 4.7 Support & fire missions
RTO-gated. Artillery: call → spotting round on coarse scatter → corrections walk in (delay per volley) — FO skill tightens; same system drives enemy mortars. TACAIR: minutes-scale, smoke-marked runs. Availability rolled at briefing by mission type/region. Illumination flares both ways at night.

### 4.8 Insertion/exfil (live systems)
Briefing LZ/route choice; generator pre-places AA/MG threats (intel-accuracy roll reveals some); AI-piloted Huey on the chosen route (player in the door, can shoot); Hot-LZ outcome distribution calibrated by RECON's table; shoot-down → crash-site E&E mutation. Exfil archetypes + prep phase + fallback-LZ ladder + boarding dash (MISSION_DESIGN_RESEARCH §11). Slice abstracts the flight; the mission data model treats insertion as a first-class phase from day one.

### 4.9 Characters on screen (CULTIC-style pipeline)
8-directional billboard sprites rendered from 3D models: Blender batch rig renders the RTS rigged infantry GLBs (US + VC; NVA variant recolor) from 8 yaw angles × animation states (idle, walk, run, crouch, aim, fire, reload, flinch, death ×2, prone) → sprite sheets → `Sprite3D`/shader with camera-relative frame selection. AI FSM states map 1:1 to sprite states — this is why the architecture fits sprites. Perf win funds jungle density.

### 4.10 UI / audio
Diegetic-first: barks, hand signals, enemy voice lines, wildlife going quiet; minimal HUD (compass strip + selected objective, ammo-by-mag icon, health/bleed state, squad status pips, one subtle "being noticed" directional pip sharpened by Al/perk). Briefing/debrief screens. Audio is load-bearing, not polish (stealth is audio): weapon reports with distance filtering, jungle ambience beds, radio procedure VO (text-to-placeholder first), the RTS `sound_profile` IDs as the sourcing shopping list.

---

## 5. Decisions made autonomously in Phase 3/4 (flagged per your "no questions until coding" rule)
1. **Damage tuning:** RECON dice + hit-location fatals + bleed-out (wounded-friendly so the medic economy works; headshots/ambushes stay instantly lethal). Not HoD's current 2-shot-everything numbers.
2. **Sight caps tuned up** from RECON's tabletop values (30yd jungle → ~45m) keeping the ratios.
3. **First-slice MOSs:** Point, RTO, Medic (the mission-loop verbs). Others later.
4. **Mission taxonomy:** RAID / SECURITY / TRANSPORTATION over the six objective types.
5. **First slice mission:** RAID with one DESTROY objective (VC weapons cache), day, clear weather, Local Force enemies.
6. **Suppression and light morale kept** (RECON lacks both; we need them — Local Force breaks, NVA doesn't).
7. **Sprite pipeline runs as a parallel art track**; capsules remain placeholders through M2 so systems work is never blocked by art.

---

## 6. Milestone roadmap

**M0 — Housekeeping (small)**
Commit HoD as-is (first commit ever). Prune: `fps_controller.gd`, one of the dual weapon-switch systems, orphaned tilemap pipeline (keep the projectile pool — M5 uses it). Fix jump binding. Fork TerrainEngine into the repo under `terrain/`.

**M1 — Walkable jungle (perf checkpoint)**
TerrainEngine FPS profile: eye-height camera, blocking collision on near chunks + trunk capsules, near-foliage density pass, near-camera mesh detail tier, fixed seed, sight-cap query. HoD player controller walking a generated 1km AO at target framerate on modest hardware. **Go/no-go perf gate before anything else is built on top.**

**M2 — THE SLICE (smallest playable mission, end to end)**
Briefing screen (static text, LZ pick stub) → spawn at LZ → one DESTROY objective (weapons cache in a generated ville site, RTS building models, pre-placed Local Force enemies using current HoD AI + capsules) → plant charge (hold-to-complete) → exfil zone → debrief screen with RECON scoring (contacts avoided/detected counted crudely). Minimal MissionDirector/MissionState/MissionTrigger. *Proves the loop: generate → insert → objective → exfil → score.*

**M3 — Detection & AI overhaul**
Alert tiers + accumulator + NoiseBus + believed-position/search + navmesh wiring + cover claims + archetype resources (3 tiers) + dormant populations/leashes + escalation ladder (QRF from finite pool, mortars on last-known). Sentry boredom. Fairness rules. *The stealth-vs-loud economy becomes real.*

**M4 — Squad**
Fireteam of 3 (Point/RTO/Medic) on BT framework: orders (5 commands), never-break-stealth + yielding rules, medic revive chain (fail-forward death model in), point-man warnings, text-stub barks, RTO exfil call. Roster screen stub with rolled St/Ag/Al.

**M5 — Gunplay pass (pillar #1 gets its milestone)**
Vietnam weapon set from RTS data (M16, CAR-15, AK-47, M60, M79, M1911 + SKS/RPD enemies), projectile ballistics via the pool, RECON damage dice + expanded hitzones + wound effects, three-situation asymmetry, stoppages, recoil/handling feel pass, muzzle flash/tracers/impacts, **first real audio pass (weapons + jungle bed)**.

**M6 — Mission generator proper**
Taxonomy + 2–4 objectives (all six types), site pass (compounds, villes with attitude, trap/ambush markers), contact deck (ambient jobs: supply parties, patrols, civilians who inform), intensity-curve validation, weather/moon/intel rolls, exfil archetypes + prep + fallback ladder, support calls (arty minigame), heat system. *Replayability arrives.*

**M7 — Live insertion**
Huey ride-in on chosen route, door-gun, AA/MG sites in the world, hot-LZ emergence, shoot-down → crash-site E&E mutation, extraction bird + boarding dash + smoke.

**M8 — Campaign layer**
Province map + war state, persistent roster (XP pool spend, healing calendar, rotate-stateside, replacements), mission offers by region, firebase hub screen, Iron Man unlockable. Sprite pipeline lands by here at the latest (parallel track: P1 Blender render rig, P2 in-engine sprite states, P3 replace capsules).

Beyond: night ops + starlight scope + flares, PBR/riverine insertion, tunnels, mortar MOS, big-battle mission types (firebase defense with the AI director at full volume), Vietnamese language/VO, flyable Huey.

---

## 7. Approval gate

This document + the three research docs are the complete Phase 1–4 deliverable. **Next step on your word: M0.** Say "approved" (or mark up what to change) and coding starts.
