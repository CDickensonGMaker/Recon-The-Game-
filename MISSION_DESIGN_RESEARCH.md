# MISSION DESIGN RESEARCH — RTCW & MoHAA → Godot Randomized Mission Generator

**Date:** 2026-07-07 (Phase 2)
**Sources:** iortcw GPL source (SP game code), OpenMoHAA source, RTCW/MoHAA modding docs, design retrospectives, GDC material (FEAR, TLOU, BioShock Infinite, L4D finale docs), Vietcong (2003) reviews/design commentary.
**License note:** All findings are architectural/design concepts described in our own words. No GPL code was copied and none may ever be — we reimplement concepts in original GDScript.
**Frame:** Everything below is filtered through the project vision — Arma/OFP tactical sandbox, open AOs, stealth optional, escalation not fail states, AI fireteam, HLL lethality. RTCW/MoHAA contribute *systems architecture*, not linear level design.

---

## 1. The big convergence: both engines are the same architecture

Studied independently, RTCW and MoHAA reduce to the same four pillars — which is strong evidence this is the right shape for our generator:

1. **A cooperative-coroutine sequencing layer** (RTCW: interruptible per-entity action stacks; MoHAA: Morpheus green threads with `waittill`/`notify`). Scripts are resumable lists of blocking commands.
2. **Objectives as a tiny replicated data store** (RTCW: a bitmask on the player + `objectivemet n`; MoHAA: config-string slots with hidden/current/completed status feeding the compass). Game logic knows indices; UI owns text/markers.
3. **A perception-driven alert-state AI** orthogonal to behavior (RTCW: RELAXED→QUERY→ALERT→COMBAT; MoHAA: visibility accumulator → CURIOUS → ATTACK), fed by typed noise events with per-weapon radii.
4. **Pre-placed, dormant, trigger-woken populations** (RTCW deliberately *removed* runtime spawn-from-thin-air; MoHAA spawns only out of sight). Waves = dormant pools released in sequence.

**The killer fact for us: GDScript natively provides the hardest part.** Morpheus `thread`/`waitthread`/`waittill` map 1:1 to calling an async func without `await` / `await func()` / `await signal`. What Ridah and 2015 Inc. built by hand in C, we get from the language.

---

## 2. Mission sequencing layer (the runtime)

### 2.1 MissionDirector autoload (= MoHAA's `level` object)
- Event bus: `notify(event: StringName, data)` + `await wait_till(event)` + `wait_till_timeout(event, secs)` + `wait_till_any(events)`. All three wait variants are genuinely needed.
- Variable scopes to replicate: `mission.*` (this mission), `campaign.*` (persists across missions — MoHAA's `game.`), per-entity, per-sequence-local. Implement as dictionaries on MissionState / CampaignState autoloads.
- Lifecycle events: `prespawn` (generation/precache) → `spawn` (player exists, gameplay begins) → mission steps → `debrief`.

### 2.2 Missions as data, not code
The generator emits, per mission:
- `Array[ObjectiveDef]` (see §3)
- `Array[Step]` resources interpreted by a generic async runner — MoveToAreaStep, DestroyTargetStep, KillGroupStep, RetrieveStep, DefendStep, TimerStep, ProtectWatchdogStep…
- Placed content: NPC spawn records (archetype + overrides + patrol path), trigger volumes, dormant wave pools, alarm objects, exfil node.

**Important sandbox deviation from both source games:** RTCW/MoHAA run steps *linearly* (section_1 → section_2). Our AO is open — objectives are live simultaneously and completable in any order. So the runner is not one linear thread: it's **one concurrent watcher-coroutine per objective** plus a top-level gate (`all objectives met → exfil unlocks`). The linear-gating lesson still applies *within* an objective (approach → interact → consequence) and to the mission spine (insert → objectives → exfil).

### 2.3 Scripted sequences (used sparingly — director beats, not corridors)
- `ScriptedSequence` node: array of action Resources (MoveTo, PlayAnim/SpriteState, Bark, Wait, SetAlertTier, Trigger(other), WakeGroup, Accum ops, MeetObjective, FailForward), executed by awaiting each in order.
- Keep RTCW's two contract properties: a new event on the same actor **interrupts** the running stack (with optional backup/restore), and every action has a `first_call` entry hook.
- **Name-based indirection is the generator's glue:** every scriptable node registers a `script_name` in a Directory autoload; actions reference names, not NodePaths. The generator stamps prefab event-blocks ("alarm runner", "door guard", "mortar crew") onto any spawned NPC by string substitution.
- RTCW's `wait <ms> [moverange]` nuance: waiting AI defends a leash circle around its anchor (dodges, repositions, returns). Scripted guards stay alive-feeling.
- **Accumulators:** 8 ints per entity + guard-abort conditionals (`abort_if_less_than` etc.) shipped a 15-hour campaign. Implement as a counter dictionary on MissionState with guard actions. Do NOT build an expression language — austerity keeps generator templates composable and verifiable.
- Entity notify convention: every NPC/door/mover gets a `Notifier` with `movedone`, `animdone`, `died`, `alerted` signals → sequences `await npc.notifier.movedone` exactly like `waittill movedone`.

---

## 3. Objective system

### 3.1 State model
- `MissionState` autoload: `objectives_needed: int`, `objectives_met: int` (bitmask), signals `objective_met(idx)`, `objective_changed(def)`, `mission_failed_forward(reason)`.
- `ObjectiveDef` Resource: `id, type, text, world_pos/target, status (HIDDEN/CURRENT/COMPLETED), compass_priority`. HUD compass/markers/toasts subscribe to signals only — clean logic/UI split (MoHAA).
- MoHAA rule kept: **exactly one CURRENT compass objective at a time** (player-selectable in our open AO — nearest by default).
- **Exfil gate = RTCW's changelevel rule:** the exfil interaction refuses until the required-objective mask is full ("objectives not complete" toast). Optional objectives set bits outside the required mask. This single rule makes any random objective set feel like a mission.

### 3.2 Objective types = completion sensors
Each type is a small scene the generator drops and wires to `objective_met`:
| Type | Sensor | Notes |
|---|---|---|
| DESTROY | target prop `died` + planted-charge interaction (3–8s hold-to-complete exposure window) | Best all-round; explosion = payoff + noise event |
| RETRIEVE | item pickup in innermost defended structure | natural "now get out" pivot |
| ASSASSINATE | named NPC `died` | fun lives in the target's generated *routine* (patrol loop + bodyguards); intel identifies him |
| RESCUE | reach POW + free interaction → **rescuee joins squad on the normal squad AI stack** | never bespoke escort AI |
| RECON | LOS/photograph check on N points, dwell timer | objective #1 only; front-loads stealth, teaches the map |
| HOLD | survive waves at point for T | at most one per mission; needs the wave director |
Banned for procgen: moving escort (failed even hand-scripted in MoHAA), disguise/undercover (bespoke social rules; wrong fiction for US-in-Vietnam anyway), pure "reach location" as a headline (it's connective tissue).

### 3.3 Mix + consequence rules
- 2–4 objectives, **no duplicate types**, ≤1 HOLD, RECON only first.
- **Every completion visibly changes world state** (this is what makes generated objectives feel authored): destroyed AA gun → heli exfil unlocks/safer; officer killed → patrols disorganized (or vengeful sweep); stolen codebook → enemy mortar fire on you stops; blown ammo dump → less enemy suppression ammo. Cheap systemically, huge perceived authorship.
- Interaction = vulnerability: plant/search/free actions are hold-to-complete with the weapon down. Both games use this beat as the objective's tension spike.

---

## 4. Trigger system

One configurable `MissionTrigger` (Area3D) covering both engines' zoo:
`once/count`, `cooldown` (re-arm wait), `delay` (fuse), `armed` (+ `activate()` for dormant-until-woken), `edge_triggered`, `activator_mask` (player / any hostile / NPC / vehicle), `require_use` (interact inside volume), targets = list of `(script_name, event)` pairs and/or `director.notify(event, activator)`.
Specializations: checkpoint trigger (MoHAA's `trigger_save` — autosave with a location label), sound/music trigger, `alertentity`-style wake trigger.
Generator placement: AO graph edges/chokepoints (trail junctions, compound gates, river crossings) for wave releases, checkpoint saves, tension escalation, radio-chatter beats.

---

## 5. AI perception & the alert-state ladder

### 5.1 Four tiers (orthogonal to behavior, drives perception multipliers + sprite animation sets)
**RELAXED → SUSPICIOUS (query/curious) → ALERT → COMBAT**
- FOV scaling per tier: ×1.0 / ×1.5 / ×1.5 / ×2.0 (base 90°); 360° awareness of a currently-tracked target at ALERT+; FOV floors high once an AI has ever fought.
- COMBAT decays to ALERT when contact is lost — **never back to RELAXED** (permanent suspicion). Combat chase give-up ~8s without contact.
- Tier transitions fire script events first, and sequences may **veto** them (RTCW's `deny`) — needed for briefing-camp scenes and any authored beat.

### 5.2 Vision: accumulator, not boolean (MoHAA), gated by reaction time (RTCW)
- Per potential target: `awareness += dt × f(range_norm, fov_centrality, exposure) / notice_time_scale` when the LOS trace passes; decay 0.25/s otherwise. ~0.5 → SUSPICIOUS look; 1.0 → confirmed → COMBAT.
- LOS = ray to 3–5 sample points on target (head/center/feet/sides) so partial cover reads correctly. Head-orientation cone, not body facing.
- **Player stance/motion multiplier** on the accumulator: crouched/still/prone in foliage is noticed slower — this is the stealth sim.
- **Foliage = soft concealment**: blocks sight rays (or heavily scales awareness gain), never blocks bullets — HLL-consistent, and it makes jungle the stealth resource. Sight distance capped by environment (fog/night/rain missions globally tune stealth like MoHAA's farplane clamp).
- **Reaction-time integrator** (RTCW): a confirmed target still doesn't "count" until continuously sighted for `reaction_time` (0.3–1.0s per archetype; scaled down when close, halved once battle-hardened).
- **QUERY escalation memory** (RTCW's best stealth mechanic): first suspicious sighting = ~1.0s grace + investigate; 2nd within 60s = 0.5s; 3rd+ = straight to COMBAT. Firing during someone's query = instant COMBAT. Kills peek-a-boo cheese.
- **Believed position, never transform:** AI aims/searches at last-seen position + velocity lead; 5s post-LOS memory; 3 breadcrumb positions at 1s intervals for organic "search where you went, not where you are."

### 5.3 Hearing: one global NoiseBus
`NoiseBus.emit_noise(type, pos, radius_override, source_team)`. Data table (converted to meters, MoHAA ratios):
| type | radius | priority |
|---|---|---|
| grenade landing | 10m | 8 |
| gunshot (rifle/SMG) | 50m | 7 |
| explosion | 100m | 6 |
| bullet impact nearby | 10m | 5 |
| urgent voice / scream | 38m | 4 |
| voice | 25m | 3 |
| footstep (sprint) | 13m | 2 |
| misc (door, brush movement) | ~5–10m | 1 |
Suppressed/knife ≈ 1–2m. Per-listener: `hearing_scale`, occlusion multiplier through terrain/structures (×0.5–0.9), reaction chance = `sound_awareness × distance falloff` vs a roll (distant gunfire *sometimes* pulls guards — organic, not deterministic), random 0.2–0.5s reaction delay. Investigation walks to the **noise origin**, not the player. An AI investigating priority 7 ignores new priority 2.

### 5.4 Alert propagation (all local — no global alarm variable)
1. Vis-record sharing between same-team NPCs within ~10m (with an "informing buddy" bark/gesture when hostility transfers).
2. Tier contagion: seeing an ALERT friend → ALERT; seeing a COMBAT friend or a **corpse** → investigate → ALERT (corpses are a stealth resource/liability; body-moving becomes optional player craft).
3. Squad enemy-sharing within `enemy_share_range` after a short delay.
4. **Alarm carriers as counterplay** (both games): designated NPCs with an `alarm_node` (radio in the commo hut, flare, whistle) run there instead of fighting and fire `alarm_event` on arrival. Killing the runner or pre-destroying the radio (damageable prop → free optional objective, counted by accum) cancels HQ escalation. The "race the runner" mini-game falls out of pure data.

### 5.5 What the alarm does (Vietnam escalation menu — never mission failure)
On HQ alarm, the director rolls from an escalation menu weighted by remaining mission length and the AO's manpower pool:
- QRF squad inbound 90–180s from an off-map edge (finite pool, MGSV model — loud players can genuinely exhaust local forces; never Far Cry 2 infinite respawn)
- **Mortars walking onto the player's last-known position** — audible tube *thunk* gives 4–6s to displace; teaches movement, punishes camping
- Patrols double on trails; objective hardens (documents start burning = soft timer; target officer retreats to his bunker)
All pressure the player plays *through*. Undetected completion pays: QRF never spawns, exfil quieter, commendation/XP bonus. **Stealth is an economy, not a gate** (RTCW Forest = the canonical failure; RTCW Norway's alarm-= -more-enemies = the praised version).

### 5.6 Fairness rules (mandatory at HLL lethality + randomized placement)
- Anti-Sniper-Town: first shot at an unaware player is a near-miss crack; muzzle flash and report always render; enemies vocalize before flanking.
- Alerted ≠ aimbot: alert tiers widen search/FOV/aggression, **never accuracy**.
- **Exposure-ramped accuracy** (RTCW): `acc = base + 0.4 × ramp(time_continuously_visible / (0.5 + 3.5×(1−difficulty)))` expressed as directional aim error. First shots miss; sustained exposure kills; repositioning resets your death clock. Difficulty tunes ramp time — never damage.
- Pain-quota stagger for hit feedback: damage accrues into a quota draining at `rate×(1+difficulty)`; over threshold → stagger anim + aim reset + growing cooldown; point-blank damage discounted (no stunlock-rushing). Maps directly to sprite hit-flinch frames.

---

## 6. AI behavior architecture

### 6.1 Three-layer pattern (MoHAA) grafted onto Hell of Duty's existing FSM
**Situation × Personality × Behavior-FSM:**
1. **Situation** (priority stack with suspend/resume): IDLE < SUSPICIOUS < COMBAT < GRENADE-NEARBY < PAIN < DEAD. Higher-priority situations suspend and later *resume* the current one — this interrupt stack is what makes AI look responsive without behavior-tree spaghetti.
2. **Personality map** (per archetype resource): situation → concrete behavior. COMBAT → turret | cover | rush | MG | flank; IDLE → idle | patrol | runner | sentry. HoD's existing goal-scoring (ENGAGE/SEEK_COVER/FLANK/RETREAT…) survives as the COMBAT-situation brain.
3. **Behavior states** with `begin/end/suspend/resume/first_call` hooks.
- HoD already has think(6.7Hz)/execute(frame) separation — keep, extend the budget model (§8).
- The **turret retarget ladder** (side-step small/large → face-step → new node → suppress last-known-pos → run home if past leash → "fake enemy" fire at last known spot) is cheap and reads as smart — ideal default for defenders.
- Sprite-state mapping: every behavior state + situation pair resolves to an 8-dir sprite animation state (idle/walk/run/aim/fire/flinch/death). The FSM architecture is *why* billboard sprites work — no blend trees needed.

### 6.2 Cover done right (fixes HoD's stub)
Cover/concealment markers with flags {cover, concealment, corner_L, corner_R, low_wall, sniper} + **claim tokens** (one owner; claim-revoked → re-plan). Selection validates: actually blocks LOS to current enemy's believed position, not past the enemy, within leash. Generator stamps CoverPoints on placed props/structures at AO build time; TerrainEngine trees/berms contribute concealment points.

### 6.3 The tuning surface: one archetype Resource
Merged RTCW `aiDefaults` + MoHAA `AISpawnPoint` field set (defaults converted to meters, tuned later):
```
# perception
sight_distance (jungle: 25–40m day / 10–15m night), fov_deg 90, hearing_scale 1.0,
occlusion_hearing_mult 0.7, sound_awareness 1.0, notice_time_scale 1.0,
reaction_time 0.3–1.0s, inner_detection_radius 8–12m, grenade_awareness 0.2
# combat
aim_accuracy (0.2 militia / 0.4 NVA regular / 0.6 sniper), aim_skill, aggression,
tactical, camper, engage_min 3m, engage_max 25m (sniper 150m+), grenades 0–2,
pain_threshold_scale, suppression_resistance
# movement/social
walk/run/crouch speeds, yaw_speed, leash_radius 15m, squad_interval 3m,
enemy_share_range 25m, alarm_node/alarm_event, patrol_path, wait_for_trigger
# identity
faction, starting_tier (RELAXED garrison / ALERT patrol), personality map
(type_idle/type_attack), sprite_set, voice_set, drops
```
Per-instance overrides in spawn records. Generator difficulty-tunes by **swapping archetypes and overriding 2–3 floats**, never code. VC militia vs NVA regular vs NVA sapper vs sniper = four data files (seeded from RealVietnamRTS's `vietnam_unit_data.gd`).

---

## 7. Friendly squad AI (Vietcong model + modern buddy rules)

1. **Roles with mechanical identity:** medic (bandage/revive — he *is* the lives system), radioman (exfil/support calls — he *is* the mission UI), machine-gunner (suppression), **point man** (detects ambushes/traps ahead, hand signals). 2–4 slots.
2. **Player-paced, not leader-paced:** the point man reacts to *player* movement — signals when the player pushes toward danger. Fixes Vietcong's #1 complaint (slow forced-follow).
3. **Squadmates never break player stealth** (TLOU Ellie rule): while the player is undetected, squadmates are exempt from enemy perception and snap to cover along the player's route. Accept the realism cost — being spotted through your AI's pathing is the worst buddy failure that exists.
4. **Never block, never body-check** (Elizabeth rules): doorway/trail yielding, slide out of the player's movement vector, teleport on large out-of-view desync, never occupy the player's cover node or muzzle line.
5. **Honest threat distribution:** enemy target selection weights all combatants near-equally (modest player bias max). MoHAA's everyone-shoots-the-player is fatal to squad fiction at HLL lethality.
6. **Effective but not kill-stealing:** squad reliably suppresses and finishes wounded/flankers; holds fire on the assassination target/objective defenders until the player engages.
7. **Barks are the intelligence multiplier** (FEAR's core lesson — perceived AI ≈ vocalization): contact direction calls, "moving!", ammo checks, trap warnings, post-fight muttering. Barks double as valley content between encounters and as the diegetic detection UI.
8. **Death is meaningful, not mission-fatal:** squaddie deaths permanent for the mission (drag-to-cover beat, tags), cost end rating and the persistent roster — never "mission failed."

---

## 8. Spawning, population & performance

1. **Pre-place the full population at AO build time; most groups dormant** (process off, hidden, no collision), woken by triggers/alarm/objective progress (`alertentity` pattern). Check overlap before waking; defer if blocked. Deterministic, save-friendly, waves for free. RTCW *removed* its spawn-from-thin-air action — treat that as a shipped-game verdict.
2. Spawner nodes only for QRF/waves: `once | wave(min/max interval, max_alive, total_budget)`, **out-of-sight-only placement** (reject if in any camera frustum + LOS — MoHAA's `func_spawnoutofsight`), enter via map edge/structures and *run* to the fight (Runner behavior).
3. **Hard perf contract:**
   - Active-brain cap per fight pocket ~8–12; reinforcements enter as others die (`max_alive`).
   - Brain LOD: unseen NPCs >60m freeze perception/pathing (RequireThink); `force_active` flag for scripted actors.
   - Perception time-slicing: full scans 10–20Hz staggered; NPC-vs-player checks every frame with jitter; pairwise recheck ≥200ms; think 20Hz staggered, re-entry capped. (RTCW ran 30 AI on 2001 hardware like this.)
   - Corpse budget 5–8 with fade (sprites make corpses cheap — can be more generous, but budget anyway).
   - **Every NPC has a leash** anchoring it to its beat zone — no cross-map trains. QRF squads get *moving* leashes.
4. **Finite manpower pool per AO** — the mission's enemy budget. All spawning draws it down. Slow trickle on very long timers permissible (Hocking's improvisation point) but the pool visibly exhausts.

---

## 9. Pacing grammar (what the generator enforces)

**The mission grammar:**
`INSERT (calm) → APPROACH (tension: chatter, point-man beats, 60–120s contact-free) → [RECON ring → OBJECTIVE spike → consequence/lull] × 2–4, escalating → COMPLETION flips map state → EXFIL (heat-scaled archetype) → BOARD (catharsis)`

Generator validation rules:
- **R-curve:** score segments 0–10 intensity against a template (insert 0–1, approach 1–2, first contact 4–6, lull, objective assaults 6–9 escalating, exfil 8–10, resolution 0). Reject layouts with two peaks ≥7 and no valley ≤3 between.
- **Quiet approach guaranteed** after insertion. Fill valleys with *tension not threat* (Davies' metrics): distant mortars, wildlife going silent, corpses, abandoned camps, squad chatter.
- **Calm-before-objective:** an overwatch/recon node (ridge, treeline edge) 50–100m before each compound with no spawns in it — safe observation ring, then concentric security density inward.
- **Escalate across objectives** (+1 density/quality tier per objective), but the finale is *dramatic* (tempo, time pressure), not statistically hardest.
- **Beat vocabulary:** QUIET / COMBAT_POCKET (leashed defenders, chokepoint) / STEALTH-OPTIONAL compound / DEFEND / rare SETPIECE. Never two SETPIECEs adjacent; ≤1 failure-watchdog active per beat; checkpoint after every COMBAT_POCKET and before DEFEND.
- **Rare inversion beat** (1-in-N missions): a move/survive segment (crossing paddies under MG fire with smoke, walking barrage on a fixed axis) — the Omaha lesson, rationed.

---

## 10. Failure, death & checkpointing (fail forward — a generated mission is disposable)

1. **No quicksave.** Checkpoints at mission-graph nodes only: insertion complete, each objective complete, exfil called. A firefight is always played to its conclusion.
2. **Player down ≠ reload:** wounded state → squadmate drag-to-cover → medic revive (limited, medic must survive and reach you). The squad *is* the checkpoint system — their survival becomes self-interested. Chain exhausted → mission lost.
3. **ABORT is always on the radio menu:** emergency exfil at a fallback LZ, banking partial credit for completed objectives + "extraction under fire" epilogue. Failed-forward missions generate campaign texture (reputation, wounded roster), not repetition.
4. **Permadeath-lite roster:** squadmates persist across missions (names, kills, traits); deaths permanent; losses feed the next generation (short-handed insertion, green replacement). Player character = campaign anchor (death = mission lost + roster/war-state consequences).
5. **Never regenerate the same mission for retry.** Next mission is a new roll — optionally a narrative follow-up ("second attempt, target reinforced"). The generator's whole value is that failure produces novelty, not memorization.

---

## 11. Exfil design (first-class generated node)

Archetypes (rolled, then **weighted by heat** — alarms raised, manpower remaining, time since last contact; exit difficulty is the *receipt* for how you played):
- **(a) Hold the LZ:** radio call starts a 2–4min bird timer; waves from 2–3 telegraphed axes; lull-spike-lull crescendo rhythm (L4D finale grammar); **30–60s prep phase first** (claymores, MG arc, squad sectors, position the wounded — the CoD4 "One Shot One Kill" template).
- **(b) Gauntlet:** moving extraction (riverboat downstream, sprint to the convoy) under pursuit pressure.
- **(c) Quiet window:** finished clean → tense but uncontested walk-on. Weight (c) by stealth performance — the mission's noise economy pays off at the end.
Rules:
- **Completion flips the map:** after the final objective (esp. DESTROY), patrols converge on the noise and roadblocks appear on trails the player *used* (track them) — ingress becomes hostile egress, forcing a new route. MoHAA's infiltration-reversal made systemic.
- **Timed windows are player-triggered** (radioman call), never mission-start. Missing the window ≠ failure: bird breaks off, fallback LZ 300–600m away activates (harder, darker, mortared). Fail-forward ladder.
- **The boarding dash is its own beat:** last 10s — smoke pops, door gunner suppresses, squad boards by role with covering fire, player last. The emotional freeze-frame the whole mission builds toward, and fully systematizable.
- LZ site constraints for the generator: open clearing/paddy/hilltop/crater field; ≥2 enemy approach axes but not 360° exposure; ≥1 hard-cover cluster + 1 elevation feature; ≥150m from the final objective (post-objective lull).

---

## 12. Mapping onto existing Hell of Duty code

| Research system | Existing HoD hook | Work |
|---|---|---|
| Alert tiers + accumulator vision | `enemy_base.gd` has LOS checks, last-seen, reaction delay, INVESTIGATE goal | Insert tier variable + accumulator + query memory above the goal layer |
| NoiseBus | `CombatManager.apply_suppression_in_area` shows the broadcast pattern | New autoload; weapons emit on fire; footsteps from player/NPC movement |
| Behavior layers | Goal-scoring think/execute FSM | Wrap as COMBAT-situation brain inside the situation priority stack |
| Cover claims | Cover points generated but unused | Implement claim tokens + LOS validation (finally consumes them) |
| Sequencer | — (none) | New: MissionDirector + Step runner + ScriptedSequence (`await`-based, small) |
| Objectives/triggers | `GameManager.level_complete` (unlistened) | Replace with MissionState bitmask + sensor scenes + MissionTrigger |
| Squad | `ally_base.gd` (follow/engage/cover) | Add roles, orders (already decided: follow/hold/move-to/engage/hold-fire), never-break-stealth + yielding rules, barks |
| Exposure accuracy + pain quota | flinch + suppression exist | Replace flat accuracy with ramp; add damage-quota stagger |
| Dormant populations | `EnemyBase.spawn_enemy()` factory | Add dormant mode + wake; generator emits spawn records |

---

## 13. Constants crib sheet (starting values, tune later)
Sight budget ~50 checks/s; pairwise recheck ≥200ms (player every frame ±40–80ms jitter); reaction 0.3–1.0s (halved <10m, halved battle-hardened); post-LOS memory 5s; breadcrumbs 3×1s; query grace 1.0s→0.5s→0 within 60s; combat→alert timeout 8s; hearing delay 0.2–0.5s; audible/impact stimulus freshness 2s/1s; think 20Hz max 4/frame; awareness decay 0.25/s; accuracy ramp +0.4 over `0.5+3.5×(1−difficulty)`s; QRF arrival 90–180s; mortar warning 4–6s; exfil bird 2–4min; prep 30–60s; LZ ≥150m from final objective; quiet approach 60–120s.

---

## Sources
iortcw (github.com/iortcw/iortcw) `SP/code/game/` — ai_cast*, g_script*, g_alarm, g_trigger; OpenMoHAA (github.com/openmoh/openmohaa) `code/fgame/` — actor*, scriptthread, trigger, spawners, navigate; Surface Group & Loffy's Domain RTCW scripting docs; mohaaaa.co.uk + ModDB Morpheus docs; Orkin "Three States and a Plan" (FEAR, GDC 2006); GDC Vault: TLOU Ellie buddy AI, BioShock Infinite Elizabeth postmortem; Valve L4D finale design docs; Level Design Book (pacing); Pete Ellis pacing series; MGSV alert/Revenge system docs; Far Cry 2 retrospectives + Hocking "Fault Tolerance"; Vietcong (2003) reviews; MoH Wiki / RTCW Steam community threads (Sniper's Last Stand, Forest stealth, Norway alarms); CoD4 "One Shot, One Kill" breakdowns.
