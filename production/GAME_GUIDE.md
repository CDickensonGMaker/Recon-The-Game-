# RECONGAME — THE GAME GUIDE

**The document of record. If any doc, comment, or memory contradicts this guide, this guide wins —
and the contradiction gets a bead.** Amended only by explicit decision (War Room or Summoner), never by drift.

**Ratified:** 2026-07-10, Full Game Audit #2 (six-architect council; decree at
`war_room/archive/2026-07-10_drift_audit/synthesis.md` after this session archives).
**Companions:** `production/adr/` (the decisions, with evidence) · `production/bible/` (per-system canon
detail) · `DESIGN.md` (the founding vision, M0–M8) · beads (task truth — never markdown).

---

## 1 · What this game is

A **hardcore Vietnam War mission-based tactical FPS** in **Godot 4.7 stable** (GDScript, strict typing;
upgraded from 4.6.2 on 2026-07-10 — new-feature opportunities tracked in
`~/.claude/architect_knowledge/godot_4.7_features.md` + bead 91vy):
randomized insertion → 2–4 generated objectives in an open 1–1.5km AO → exfil → debrief → a persistent
campaign that remembers. Arma/OFP sandbox bones, SOCOM/Vietcong/Men of Valor flavor, the RECON RPG (1982)
tabletop rules as the numbers backbone, Hell Let Loose lethality, an AI fireteam you order, maintain, and
lose. PSX-era low-poly 3D aesthetic (CULTIC-adjacent), modern sleek tactical UI (Delta Force/R6/Ghost
Recon direction).

**You are a line grunt, not an operator.** Tonal north star: **Platoon · Hamburger Hill · Apocalypse
Now** — attrition, dread, moral weight, boredom-then-terror, the squad as your only anchor. Worn, muddy,
unglamorous. Launch scope is ONE faction: the US Army grunt. SF (MACV-SOG) and Marines are post-launch
DLC forks (Bible 05).

### The Five Pillars (test every decision; the Arbiter guards them)
1. **Outstanding gunplay** — HLL lethality; death comes from *situation* (ambush asymmetry, exposure,
   volume of fire), never bullet sponges.
2. **Atmosphere** — dense jungle, weather, night, audio. The AO feels like a war is happening around you.
3. **Freedom** — open AO; objectives are places/things in the world; any route, any order, loud or quiet.
   Stealth is an economy, never a gate. Nothing is on rails. Ever.
4. **The squad is the RPG** — named persistent teammates with MOS roles who improve, get wounded, rotate
   home, and die for real. Minimal stats, maximal attachment.
5. **Fail forward** — detection escalates, failure mutates, death of the mission generates the next
   story. Never reload-and-memorize.

### The Fairness Law (binding, DESIGN §4.2)
Alert ≠ accuracy · AI accuracy ramps with player exposure · first shot at an unaware player is a
near-miss · muzzle flash / tracers / vocalizations always telegraph.

### The r4bk Law (binding, learned twice)
**A feature without a visible HUD affordance does not exist.** Simulation without presentation is
unfinished work, not shipped work.

---

## 2 · Canon hierarchy (ADR-014)

| Class | Documents | Rule |
|---|---|---|
| **CANON** | this guide · `production/adr/` · `production/bible/` · `DESIGN.md` (vision) · `PLAYER_MANUAL.md` (must track the input map) | Amended by explicit decision only. Code contradicting canon = a bead, never a shrug. |
| **LOG** | dated reports: PROGRESS/WAVE/NIGHTSHIFT/OVERNIGHT/CODE_AUDIT/WIRING_STATUS/CALEB_TODO | Disposable snapshots. Never cite as authority. Archive freely. |
| **DEAD** | `war_room/archive/` · superseded roadmaps | History. Councils may learn from it; nobody obeys it. |

- **One roadmap:** `ROADMAP.md` only. ROADMAP_NEXT / ROADMAP_WAVE2 / WAVE3_REPORT are LOG → fold and archive.
- **Task truth lives in beads** (`bd ready`), never in markdown checklists.
- **CLAUDE.md** stays minimal (session law + coding patterns) and MUST match the ADRs. A stale CLAUDE.md
  is a drift *generator* — it is injected into every model session. See §7 for the current corrections it needs.

---

## 3 · The game loop (as ratified, ADR-008 → **amended by ADR-017, THE LIVING WAR, 2026-07-12**)

### ⚠ THE LOOP CHANGED. Read ADR-017 — **then ADR-029** — before touching world/flow code.
ADR-029 (DRAFT, the open-patrol pivot) further amends the shape described below; the generator ships
`"PATROL"` as its only mission type today (`scripts/missions/mission_generator.gd`). Sections 3 and
4.6 describe the pre-029 loop and are pending the Summoner's ratification call.
The loop is no longer a hub-and-mission-select. It is a **persistent province**
(`war_room/synthesis_living_war.md`):

`NEW CAMPAIGN (rolls ONE province seed — random per campaign, fixed within it) → THE PROVINCE (data:
districts, villages, VC bases, trails, a firebase — generated once, never again) → LIVING FIREBASE
(inside the AO, running a 24h clock) → HQ BOARD (pick a mission) → WALK OUT THE WIRE **or** ride the
bird → THE AO WINDOW (1.5km, rendered from province_seed + district) → exfil → back → THE LEDGER
REMEMBERS (allegiance, VC manpower, what you blew) → repeat`

- **The province persists as DATA; the scene is rebuilt on demand** (`generate(seed)` + `apply(ledger)`).
  Determinism stops being aspirational: the two-generation hash probe is a **ship gate** (ADR-017 §8).
- **The firebase lives INSIDE the AO.** "Patrol" = you walk out the wire. No load, no ride.
- **Destruction is temporary; attrition is permanent.** Bases rebuild; men don't (ADR-019).
- Mission length is **geography, not a dial**: 20–60 min, player-paced (§4.6).

### Campaign spine — the walkable firebase hub (superseded shape, kept for context)
`MAIN MENU → NEW CAMPAIGN / CONTINUE → pick operation → LIVE FIREBASE (walkable hub) → TOC briefing →
board the bird → MISSION → exfil → wheels-down back at base (HARD checkpoint) → repeat`

Ratified retroactively **with binding conditions** (not yet met as of 2026-07-10):
1. The TOC briefing must present the **RECON 7-element briefing** (insertion, fire support, enemy intel
   with rolled accuracy, terrain & weather, objectives, special rules, extraction). There is no briefing
   layer at all today — BriefingScreen was deleted by ADR-029 and `"PATROL"` is the only mission type the
   generator produces (corrected 2026-07-25, ghost-code audit).
2. The **live Huey insertion ride returns** to the campaign path (it is also the world-load mask, and the
   AA-threat economy's consumer).
3. Prompt/input truth (ADR-012): prompts name the key the code listens for.

### Mission loop (the game)
`BRIEFING (7 elements, intel-accuracy rolled) → INSERT (Huey on chosen route) → PLAY (open AO, 2–4 live
objectives, detection ladder, squad orders, fire support) → EXFIL (player-triggered, archetype weighted
by heat, ABORT always available) → DEBRIEF (RECON scoring, XP, roster consequences, war-state update)`

Mission grammar: quiet approach → recon ring → objective spike → lull → escalation across objectives →
heat-scaled exfil → boarding catharsis.

---

## 4 · Systems of record (intent → as-built truth → state)

The **⚠ lines are the audit's verified deviations.** Beads are retired (2026-07-22); the live queue
is §8 THE SHIP ORDER, and anything not on it is post-launch.

### 4.1 Gunplay & damage (Pillar 1, ADR-016/003/004)
- **One grammar: flat base × zone (ADR-016, Summoner-decreed).** Deterministic per hit; ALL variance
  from range falloff, hitzones, and the situation sim — never rolls. Flat values of record
  (ADR-016 Amendment H, the great flattening): **27 for every rifle/SMG/pistol** (M16 · M14 · AK ·
  PPSh · M1911 · Mosin) · **MG class 42** (M60 AND RPD) · **sniper 87** (M70 only) · **shotgun
  35/pellet**. Explosives: M26 190 · M79 150 · M72 LAW 250 · RPG-2 250 · RPG-7 290. Weapon identity
  lives in accuracy/fire-rate/handling/recoil, NOT damage.
  Default primary: **M16**. Guarded by `tests/test_flat_damage.tscn`.
- **Locational model (code truth, `scripts/combat/hitzone.gd` MULTIPLIERS, ADR-016 Amendment D):**
  HEAD ×4.0 (fatal bypass) · TORSO ×2.5 · GUT ×2.25 + bleed · LIMB ×1.0.
  Player HP 100; enemy HP 65–85. Bleed-out timer = the medic deadline. Pain-quota stagger for hit feedback.
- **ADS: per-weapon `ads_fov`** (base 75, M16 ≈ 60, binocs 18). M60/RPD hip-fire; RPG-2 sight-raise.
  The old "FOV locked at 75, DO NOT CHANGE" law is amended (ADR-004).
- Weapon condition degrades per shot; fouling → jams (kept, weapon-weight it — ADR-009). Cleaning kits [0].
- Three-situation asymmetry (undetected initiator wins the opening; the ambushed side is penalized until
  in cover) is the design's lethality engine. Its numbers live in ADR-016 and in
  `scripts/combat/hitzone.gd` MULTIPLIERS — the old `RECON_ADAPTATION.md` pointer is dead (file
  deleted 2026-07-23 by the Summoner; see CLAUDE.md).
- ~~⚠ 4 legacy WW2 .tres / Mosin one-shot~~ **RESOLVED with ADR-016 (2026-07-10):** MP40/Kar98k deleted,
  Mosin retuned to 32 and Thompson to 17, vc_rifleman fires its stated SKS, descriptions honest.
- ⚠ No gating FPS number exists; last measured 19–25 FPS with `rendering_method` unset. **§8 step 1
  is where it finally gets taken** — THE WALK / ONE DIG / THE BARRAGE have never been run.

### 4.2 Detection & stealth (Pillar 3, ADR-005/006)
- Four tiers RELAXED→SUSPICIOUS→ALERT→COMBAT; visibility accumulator; NoiseBus with typed radii
  (suppressed = unidentifiable misc ~3m); believed-position aiming; breadcrumb search; sentry boredom.
- **Witness rule (law, IMPLEMENTED — `enemy_base.gd:736 _can_witness` / `:756 _witness_check`, guarded
  by `tests/test_witness_rule.tscn`):** the global COMBAT beacon stamps ONLY on witnessed contact.
  An unwitnessed silent kill is silent. Noise is the honest price — GUNSHOT radius goes 55m→~150m.
- Escalation ladder: finite-pool QRF, walking mortars on last-known, patrol doubling, alarm carriers
  with radio/flare (killable counterplay). Civilians inform on a timer.
- **Scoring pays avoidance:** +25/contact avoided, −25/detected (replaces kills×10 — ADR-006). Loud stays
  viable; it stops being the optimal XP strategy.
- ~~⚠ `take_damage()` stamps the COMBAT beacon before the death check~~ **FIXED 2026-07-12 (bead pwu5),
  and PROVEN by `tools/probe_witness.tscn` (11/11).** THE WITNESS RULE is live: only a man who **lives to
  tell it** raises the alarm — he SEES you, he SURVIVES your shot, he WATCHES his buddy drop (or hears him
  fall inside 10m), or he **FINDS A BODY you left lying there** (`unreported_corpses` — bodies are finally
  a liability). An unwitnessed kill is now genuinely silent. **GUNSHOT 55m → 150m**: sound wakes the AO to
  ALERT but never to COMBAT, so a loud kill gets you made *in a few seconds, not instantly* — and those
  seconds are the game.
- ~~⚠ VILLAGE_RAID demands 80% body count~~ **FIXED 2026-07-12:** clearing the ville is now **OPTIONAL**;
  destroying the cache/APC remains the required objective. A raid can be done quietly (Pillar 3: stealth
  is never gated) — a mandatory body count contradicted "kills pay zero" outright.
- ⚠ The "being noticed" detection pip (DESIGN §4.10) is unshipped after two decrees.

### 4.3 Enemy AI (Pillar 1/2)
- Hybrid: goal-scoring FSM combat brain inside a MoHAA-style situation-priority stack; personality maps
  per archetype (Local Force breaks / NVA doesn't); think/execute split (THINK_INTERVAL 0.15, verified);
  suppression; grenades ("LUU DAN!" telegraph); sappers at the wire.
- Open keystones: EnemySquad coordinator (gpvb), smart patrol/search/teamwork (0623), detection-driven
  ambience (r6qe).
- `MAX_THINK_TIME` frame budget: the symbol does not exist anywhere in `scripts/` or `tests/` — the old
  "declared and never used" warning was itself stale. There is nothing to wire; a per-frame think budget
  would be new work, not a repair.

### 4.4 The squad (Pillar 4)
- 5-man persistent fireteam, MOS = verbs: **Point** (trap/ambush warnings), **RTO** (the net — lose him,
  lose CAS/mortars/resupply), **Medic** (revive chain, 2/mission, 30s clock), Pigman, Grenadier.
- Orders: FOLLOW / HOLD / MOVE-TO / FIRE-TOGGLE on **F1–F4** + secondary **C/H/X/N** (dual-bind law,
  ADR-012). Buddy rules: never break player stealth, never block trails/muzzles, no kill-stealing.
- **PROGRESSION — REWRITTEN BY ADR-018 (2026-07-12). The old St/Ag/Al pool spend is dead for the PLAYER.**
  - **Player stats: KILLED.** No progression may touch accuracy, recoil, sway, handling, health or
    stamina. Ever. (A player-accuracy stat is hit-point math, and Pillar 1 forbids it.)
  - **Squad XP: kept, but SILENT and BEHAVIORAL** — never a number. A veteran point man *stops and holds
    up a fist before the trip wire*; a green one walks you into it. **This is Pillar 4's teeth**: a free
    rookie must be visibly, audibly worse.
  - **Player RANK: NEW. It gates AUTHORITY, never ABILITY** — fire-support tier (60mm+smoke → 105s →
    fast movers/napalm → Arc Light), mission types you're trusted with, armory/ruck, cosmetics.
    **THE LADDER LAW: rank gates how BIG, never WHETHER.** ADR-011 stands — the RTO still gates it all.
- Permadeath; wounded heal ~2 St/day; veterans rotate; replacements arrive. **Loss is still costless
  (instant free rookies) — the debt ADR-018's silent veterancy exists to pay.**
- ⚠ Squad-key input verified clean in code twice, never verified on Caleb's keyboard — R3 checklist item.

### 4.5 Fire support (ADR-011)
- RTO-gated (10m leash, ALL verbs), budgets rolled at briefing, danger-close double-press protocol,
  spotting-round → walk-in corrections; enemy mortars use the same system. Verified genuinely fixed.
- Danger-close checks the PLAYER's distance as well as the squad's
  (`scripts/missions/field_director.gd:357-359`, `DANGER_CLOSE_M` 45m).

### 4.6 Missions & generation (M6 target)
- **MISSION LENGTH IS GEOGRAPHY, NOT A DIAL (ADR-017).** Objective count scales by type; target average
  **20–60 min, player-paced.** This amends the flat "2–4 objectives" below:

  | Type | AO window | Insertion | Objectives | Minutes |
  |---|---|---|---|---|
  | **PATROL** | contains the firebase | **walk out the wire** | 1–2 | 20–30 |
  | **VILLAGE RAID** | a few klicks out | ride or walk (player's call) | 2–3 | 30–45 |
  | **AIR ASSAULT** | across the province | Huey (the load mask) | 3–4 | 45–60 |

- Taxonomy RAID/SECURITY/TRANSPORTATION → 2–4 objectives (DESTROY, RETRIEVE, ASSASSINATE, RESCUE, RECON,
  HOLD; no dupes, RECON first-only, ≤1 HOLD); site pass stamps compounds/villes/LZs; contact deck gives
  the AO ambient jobs; weather/moon/intel rolls; exfil archetypes + fallback LZ ladder.
- As-built: a 5-type grammar v1 stands in for the full taxonomy; deterministic one-seed-per-op (ADR-010).
- ⚠ Offer labels ("ENEMY: HEAVY") are rolled and never read by the generator; `missions_played` scales
  nothing. The campaign is flat — decree carry-over.

### 4.7 Saves & persistence (Pillar 5, ADR-007)
- Versioned SaveData + SaveManager (deferred writes); tiers **REGULAR** (F5/F9 anywhere) / **HARD**
  (checkpoints only; death spends the checkpoint; same-seed resume) / **IRONMAN** (one slot).
  Mission results commit **all-or-nothing at exfil** — fail-forward, ratified.
- ⚠ Needs: atomic writes, future-version rejection, visible save/load feedback everywhere (hub has
  none today), tier consequences stated in the settings UI checkboxes. The pause menu itself exists
  (`scripts/ui/screens/pause_menu.gd`).

### 4.8 Survival (ADR-009)
- **Weapon condition: kept.** **Hunger: PARKED** (fields stay in SaveData; drain removed; returns only
  if missions exceed ~40 min). Rations [9] = condition/stamina consumable.

### 4.9 World & terrain (ADR-002/013)
- TerrainEngine fork, FPS profile: 1280m AO (5×5 × 256m chunks, all loaded), sight caps from vegetation
  (open ~500 / forest ~90 / jungle ~45m — code currently 140/45, reconcile), craterable ground.
- **Streaming policy: OFF for maps ≤2km** (the inherited 3km-era streamer synchronously popping whole
  tiles is the terrain-pop root cause). Streaming returns only time-budgeted, for 3km+ AOs.
- **Scale contract: 1.7132m characters** (`GAME_SCALE_STANDARD.md`), instance-space AABB normalization,
  acceptance k ∈ [0.8, 1.0] enforced by probe.
- ~~⚠ ModelActor mesh-space AABB → speck soldiers~~ **FIXED 2026-07-10:** instance-space measurement;
  all 9 characters render at exactly 1.7132m, guarded by `tests/test_model_scale.tscn` (the ADR-002
  rendered-scale probe). Caleb's in-game confirm pending (n2ij item 1).
- ⚠ Jungle feel fails ground truth ("a white kid in america made"): needs wind-sway shader, undergrowth
  layers, wilder composition — after the perf day prices it.

### 4.10 Characters & art (Bible 09, ADR-001/002)
- **3D PSX models are THE renderer** (sprite matrix dead — beads closed this session; sprites may return
  only as A/B-proven far-LOD). Blender 5.0 pipeline, ~3–6k tris, modular kit (helmet/torso/arms/face)
  drives roster variety; "chonky" base fix is the top art debt; FP viewmodels: one GLB per weapon,
  procedural feel in Godot, never baked.
- Export contract: feet at origin, face −Z, 1.7132m, sockets `MuzzlePoint/HandR/HandL/Head/Chest`.

### 4.11 UI & audio (Pillar 2)
- Diegetic-first: barks, VO (162 wired via VOManager — toast text = subtitles), positional radio from the
  RTO's back, wildlife silence, weather. Minimal HUD; **sleek tactical modernization (Delta Force/R6) is
  the declared next major focus (fmc8)** — but for Early Access this is scoped to **§8 step 7: one
  day of legibility, not the research week.**
- ⚠ Invisible today: condition/consumables/stamina/breath (no HUD), detection pip, save feedback.

---

## 5 · The RECON tabletop backbone (what we keep fidelity to)

> **AMENDED 2026-07-23.** This section used to name `RECON_ADAPTATION.md` as "the numbers source of
> record." **That file was deleted on purpose by the Summoner** — it was frozen against a game that no
> longer exists and was spoiling the output of work that read it. Do not restore it or cite it.

The 1982 tabletop remains the *spirit* backbone — detection/sight-cap ratios tuned up from tabletop
with the ratios kept, the ±25 contact scoring, the XP pool economy. **The numbers of record now live
only in the ADRs and the code**, and nowhere else:

- Damage — **ADR-016** (flat base × zone; the per-caliber dice it described are retired) and
  `scripts/combat/hitzone.gd` MULTIPLIERS.
- Scoring economy — **ADR-006**.
- Detection and the witness rule — **ADR-005**.

Its dead sections went with it: the 7-element briefing and the hot-LZ outcome tables described the
offer → briefing → Huey → exfil loop that **ADR-029** deleted. Where realtime needs diverge from the
tabletop (suppression, morale — RECON has neither), the divergence is named in an ADR, never silent.

---

## 6 · Scope law (what we are NOT building)

### 6.0 THE SLICE (ADR-017/018/019/020 — the build target, 2026-07-12)

The Summoner named the disease himself, in a rival game: *"expanding the content too much and not making
a good game."* **The Arbiter holds this line.** The question is never "can we have all this" — it is
**what is the smallest version that ALREADY FEELS LIKE THIS?**

> **One province. One firebase, inside the AO, running its clock. A VC organization living in that same
> province — bases, patrols, and a night attack that can come to your wire. Three mission types:
> PATROL / VILLAGE RAID / BASE ASSAULT. Village allegiance. Rank.**

**If that grips for ten hours, everything else is content bolted onto a working game. If it doesn't,
tunnels won't save it.**

| Ruling | Items |
|---|---|
| **KILLED** | 8-directional sprite render matrix (ADR-001) · operation-style front door at launch (single faction) · **player stat progression (ADR-018)** |
| **PARKED** | hunger (ADR-009) · SF/Marines (DLC) |
| **FROZEN (post-core)** | **tunnel INTERIORS** (a second game: different movement, light, combat — it eats a year. **Tunnel MOUTHS you mark and satchel are IN SCOPE TODAY.** Going down the hole is the FIRST THAW once the core is undeniable.) · supply-logistics sim · coop · driveable/flyable vehicles · riverine · capture/POW epic · full-volume battle director · RPG shop · ride-or-walk |
| **SHRUNK** | 100 bios → 20 great ones · HQ interactions stay walk-up-simple |

A frozen epic thaws only by explicit decree — a bead in `bd ready` is not a thaw.

---

## 7 · Corrections to stale law (for the CLAUDE.md / head-honcho rewrite)

The next project prompt must **not** carry these forward (all verified false 2026-07-10):
1. ~~"8-directional billboard sprite characters (CULTIC-style)"~~ → 3D PSX models are the renderer (ADR-001).
2. ~~`[1,6,45]` dice examples, enemy HP 60–80, Thompson default~~ → **flat base × zone** (ADR-016; dice
   fully retired); zone multipliers are `hitzone.gd:16-21` — HEAD ×4.0 (fatal bypass) / TORSO ×2.5 /
   GUT ×2.25 + bleed / LIMB ×1.0 (Amendment D); enemy HP 65–85; M16 default. Copy the table from
   `scripts/combat/hitzone.gd`, never from a document.
3. ~~"FOV locked at 75.0 everywhere (no ADS zoom), DO NOT CHANGE"~~ → per-weapon ADS FOV ratified (ADR-004).
4. ~~Viewmodel recipe (scale 0.03, editor fine-tune)~~ → superseded by the fp_arms GLB pipeline
   (Bible 09; `IDLE_ANIM_SPEC.md`, `rifle_pose.py`, matrix_basis bake law).
4b. ~~"Godot 4.5+/4.6"~~ → engine of record is **Godot 4.7 stable** (project.godot features already
   re-flagged; validate 4.6→4.7 gotchas via headless boot + `--headless --import`).
5. Physics-layer table, strict-typing rules, timestep cap, THINK_INTERVAL: **verified true — keep.**
6. Validation law (keep): the definitive check is a real headless boot
   (`godot --headless --path . --quit-after 300` + SCRIPT ERROR grep); `--check-only` false-positives on
   autoloads; stale `.godot` class cache fixed by `--headless --import`.

---

## 8 · Build order — THE SHIP ORDER (standing decree, 2026-08-06)

> **The 2026-07-10 build order was DELETED by the Summoner, 2026-08-06.** Every item on it was
> written for a game that shipped nothing on a date. Do not restore it, do not cite it, and treat
> a reference to it in an older doc as dead.

### THE TARGET

**STEAM EARLY ACCESS, 2026-09-06. The product is THE DEMO'S SHAPE**
(`scenes/levels/demo_game.tscn` · 512 m · `plan_demo_world` · `GameFlow.demo_mode`): one firebase,
one day, ~30 real minutes — dawn on the bunk → the day out on a small AO → dusk return → night
stand-to → probe on the wire → the assault → gunships circling, and the player lives.

**The AO is NOT bare, and none of it may be cut.** `plan_demo_world`
(`scripts/missions/mission_generator.gd:666-775`) stamps **one village** (`:716`), **one enemy
camp** (`:770`), **a temple** (`:723`), paddy fields, a road net and 2–3 landmark craters — and
**hunter teams are live** (`field_director.gd:112-182`: `_hunter_pool` 12, 2–4 per wave after first
contact, converging on the `EvidenceLedger` lead, never on the player's transform). That is the day
half of the arc.

**Deferred post-launch by the same ruling:** the 1280 m open-patrol AO · *multiple* villages and
camps · the unbounded patrol loop · village CQB interiors · tunnels · ADR-019 allegiance.
**This supersedes §6.0's 2026-07-12 slice** (PATROL / VILLAGE RAID / BASE ASSAULT + village
allegiance). That target is now the roadmap, not the product.

**The sacrifice, named:** the ADR-029 open-patrol identity ships as ROADMAP. The store page says so.

### 8.0 · THE GATE

**THE DEMO PLAYTHROUGH is the session entry gate** (replaces PLAYTEST R4, 2026-08-06). Nothing new
ships until the Summoner verifies the arc end to end (`scripts/levels/demo_game.gd:26-69`).
Discharged only by his verified playtest (ADR-015) — never by a probe, never by an agent's reading.
**PLAYTEST R4 is deferred post-launch with the open-patrol world. It was never discharged, in 30
documents — which is precisely why it is not what ships.**

### 8.1 · THE ORDER

Full detail, evidence and costing: **`production/SHIP_AUDIT_2026-08-06.md`**. Estimates are in
**ART-DAYS** at his measured velocity (**~1 large animation sequence OR 1–2 models per working
day**). Code costs him **zero art-days** — that split drives all planning.
**Budget: 13–19 art-days of ~26 available.**

1. **KNOW WHERE YOU STAND.** Run the suite and record it (last baseline 2026-07-27: 101 pass /
   18 fail / 14 error, unverified since). Then the three perf probes that have never run —
   THE WALK · ONE DIG · THE BARRAGE. **Nothing below is trustworthy until this is done, and a red
   suite IS the day.** *(This is where the long-open "gating FPS number" finally gets taken.)*
2. **STOP THE BLEEDING.** Atomic saves — `save_manager.gd:99-107` writes in place with no
   temp/rename/`.bak` and autosave rewrites slot 8 every 30 s, so a crash mid-write destroys it ·
   reject future-version saves (`:177`, `save_data.gd:43`) · close the demo save-dir leak on the
   abnormal-exit path · export hygiene (no `res://tests` dep, no live dev keys).
3. **THE BUGS HE SEES FIRST.** Spawn-under-world · enemy dressing (**`EnemyBase` has no dresser
   call at all** — every VC/NVA man is a clone in the 45-man climax, and the art is already on
   disk) · cover-seek reads (men break 10 m early) · legs clipping trousers.
4. **RECOVER WHAT IS ALREADY BUILT — before authoring anything new.** Wire the stranded M101
   artillery crew (~497 authored channels in `fb_emplacement_m101.glb`, **zero readers**, off
   behind one guard at `site_planner.gd:822-823`) · run the animation audit and the staged-GLB
   sweep. **Costs zero art-days and gives days back.**
5. **THE ONE ASSET EVERYTHING STANDS ON.** Final firebase export → regenerate
   `firebase_v3_destructibles.json` (80 exact-name segments; a re-export without it breaks all 80
   **and blinds SiegeDirector**) → verify the contract on it (skill: `recon-destructible-export`)
   → firebase interiors and animations closed.
6. **THE AO HE ASKED FOR.** More temples and scattered ruins through the jungle (plan-time, code) ·
   the 3D clutter swap replacing the alpha-scissored billboard quads in `ground_clutter.gd:99`
   (his 2026-08-04 ruling, unshipped) — **draw-call measured before it ships; this project is
   call-bound and the cards exist for that reason.**
7. **MAKE IT FEEL FINISHED.** The mounted MG must actually fire · M79 (the only reachable
   stand-in) · UI legibility — **one scoped day, NOT the research week** *(the old Player-State HUD
   milestone, scoped down to what Early Access actually needs)* · launcher/shotgun audio ·
   balance the arc.
8. **SHIP.** Three full playthroughs on the Intel UHD floor · store page, capsule art, trailer
   (**his days, and they were never budgeted**) · build · Early Access.

**Unruled, ask him early:** stretch the arc 30 → 45 min (every beat is tuned around `END_AT_S`
1800), and replay value (fixed seed, one end card — cheap existing levers are varying `DEMO_SEED`
or the arena's chained survival waves).

---

## 9 · Process law (mechanical — ADR-015)

- **GATE bead:** feature epics are `bd dep`-blocked by the standing GATE bead while playtest P1s are
  open. `bd ready` hides gated work. Exempt: bug fixes, presentation for shipped systems, decree items.
- **Verification law:** no decree item or playtest P1 closes without a probe, measurement, or verified
  playtest. "Mitigated"/"likely fixed" never closes a bead.
- **Truth law:** no code comment may claim behavior a probe hasn't verified.
- **Test-suite eyes:** the suite gains a rendered-scale probe (k assert) and a gating FPS number —
  38 green scenes coexisted with speck soldiers and popping terrain; never again.
- **War Room:** loop-structure changes and pillar-touching decisions convene a council BEFORE build.
  Session close: `bd` updated, committed, pushed (repo CLAUDE.md protocol).

---

## 10 · Seed charter for the project head-honcho agent

**INSTALLED (2026-07-10):** this seed is live as the **recon-overseer** agent
(`.claude/agents/recon-overseer.md`), whose full operating manual + live ledger is
`production/OVERSEER_CHARTER.md`. One role, two layers — the agent definition is the compressed seed
below; the charter is the manual it loads at session start.

> You are the **RECONgame Director** — guardian of a hardcore Vietnam tactical FPS (Godot 4.7
> Forward+, strict
> GDScript). Your constitution, in priority order: **the 5 Pillars → production/adr/ → this GAME_GUIDE →
> production/bible/ → DESIGN.md**. Task truth is beads (`bd prime` at session start); dated reports are
> history, not law. Enforce: the Fairness Law, the r4bk law (no feature without a HUD affordance), the
> witness rule, one damage grammar (flat base × zone — ADR-016; the dice are retired), the 1.7132m
> scale contract, the ≤2km no-streaming rule,
> perf-first (a gating FPS number), and the verification law (nothing closes without a probe,
> measurement, or verified playtest — and no comment claims what no probe proved). Never add rails,
> never gate stealth, never make loud play optimal XP. Loop-structure or pillar-touching changes convene
> the War Room first. Engine is **Godot 4.7** — before designing any Godot-facing solution, load the
> matching skill folder(s) from `~/.claude/architect_knowledge/GodotPrompter/skills/` (51 domain skills:
> state-machine, save-load, godot-optimization, procedural-generation, hud-system, input-handling,
> shader-basics, particles-vfx, ai-navigation, audio-system…) plus
> `~/.claude/architect_knowledge/godot_4.7_features.md` and `godot_standards.md`. Where GodotPrompter
> guidance conflicts with an ADR or godot_standards.md, the ADR wins. The Summoner holds final
> authority; you hold the pillars.

---

## 11 · ADR index

| ADR | Title |
|---|---|
| 001 | Renderer of record: 3D PSX models; sprite matrix killed |
| 002 | Character scale contract: 1.7132m + instance-space AABB |
| 003 | One damage grammar: RECON dice + locational overrides |
| 004 | ADS FOV policy: base 75, per-weapon ADS zoom |
| 005 | Detection beacon + witnessed-contact rule |
| 006 | Mission scoring economy: avoidance pays |
| 007 | Save architecture: tiers, slots, checkpoint economy |
| 008 | Walkable firebase hub ratified with conditions |
| 009 | Survival v1 scope: hunger parked, condition kept |
| 010 | Per-mission determinism + MissionScope registry |
| 011 | Fire-support ladder: budgets, leash, danger-close |
| 012 | Input doctrine: interact key, shared keys, squad orders |
| 013 | World streaming policy: small maps load whole |
| 014 | Documentation hierarchy: CANON / LOG / DEAD |
| 015 | Verification law + mechanical gate |
| 016 | Flat base damage × zone — dice retired (supersedes 003's dice core) |
| **017** | **The Persistent Province + the AO Window** — the loop changed (amends 008/010) |
| **018** | **Progression: rank gates AUTHORITY, never ABILITY. Player stats killed.** |
| **019** | **Hearts & Minds: village allegiance drives VC manpower. The war is the story.** |
| **020** | **The Authored Threshold: guarantees, not rails. + The Ambience Law.** |
| **021** | **Patrols: routes that rotate + THE PROMOTION IS THE TUTORIAL (follow -> lead)** |
| **022** | **The map is your memory: he marks it, and the game NEVER corrects him** |
| **023** | **THE FOSSIL LAW: delete the old system when you replace it** (Accepted; Amendment A "delete the callers" is a DRAFT) |
| 024 | Cinematic direction: late-1998–2003 prerendered military cinematics *(DRAFT)* |
| 025 | LOD-tier world simulation: awake/asleep × node/data *(DRAFT)* |
| 026 | THE PS2 BUDGET: graphics-only rendering discipline, uncapped fighters, cheap-per-unit AI *(DRAFT)* |
| 027 | THE PS2 WORLD: settlement-first generation, flowing water, smooth relief gradient *(DRAFT)* |
| **028** | **One world-build path — the arena is a slice of it, never a parallel copy** (Accepted) |
| **029** | **THE OPEN PATROL SIMULATOR** *(DRAFT)* — no briefing UI, no objective counter, no exfil step; PATROL is the only generated mission type. **Amends §3's loop and §4.6's mission table; read it before touching flow, mission, or world code.** Rides with `ADR-029-amendments-008-006.md` (DRAFT amendments to 008 and 006). |

The directory is the index of record (`production/adr/`, 31 ADRs + README). DRAFT ADRs are not law
until the Summoner ratifies them, but they are the live direction — do not build against 017's loop
without reading 029 first.
