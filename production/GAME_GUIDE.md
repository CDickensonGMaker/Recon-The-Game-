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

## 3 · The game loop (as ratified, ADR-008)

### Campaign spine — the walkable firebase hub
`MAIN MENU → NEW CAMPAIGN / CONTINUE → pick operation → LIVE FIREBASE (walkable hub) → TOC briefing →
board the bird → MISSION → exfil → wheels-down back at base (HARD checkpoint) → repeat`

Ratified retroactively **with binding conditions** (not yet met as of 2026-07-10):
1. The TOC briefing must present the **RECON 7-element briefing** (insertion, fire support, enemy intel
   with rolled accuracy, terrain & weather, objectives, special rules, extraction). The campaign path
   currently skips BriefingScreen entirely.
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

The **⚠ lines are the audit's verified deviations** — each is beaded; fixing them is the build order (§8).

### 4.1 Gunplay & damage (Pillars 1, ADR-003/004)
- **One grammar: RECON dice** (M16 5d10, AK 4d10, .50 2d100…). Default primary: **M16**.
- **Locational model (code truth, ratified):** HEAD = fatal · TORSO ×2.0 · GUT ×1.75 + bleed · LIMB ×0.75.
  Player HP 100; enemy HP 65–85. Bleed-out timer = the medic deadline. Pain-quota stagger for hit feedback.
- **ADS: per-weapon `ads_fov`** (base 75, M16 ≈ 60, binocs 18). M60/RPD hip-fire; RPG-2 sight-raise.
  The old "FOV locked at 75, DO NOT CHANGE" law is amended (ADR-004).
- Weapon condition degrades per shot; fouling → jams (kept, weapon-weight it — ADR-009). Cleaning kits [0].
- Three-situation asymmetry (undetected initiator wins the opening; the ambushed side is penalized until
  in cover) is the design's lethality engine — RECON_ADAPTATION.md is the numbers source.
- ⚠ **4 legacy WW2 flat-damage .tres remain; vc_rifleman fires a Mosin 1d10+68 that one-shots the player
  at all ranges while elite NVA fire PPSh (avg 16.5).** Delete/convert; descriptions must match loadouts.
- ⚠ No gating FPS number exists; last measured 19–25 FPS with `rendering_method` unset (ADR-015/§8.2).

### 4.2 Detection & stealth (Pillar 3, ADR-005/006)
- Four tiers RELAXED→SUSPICIOUS→ALERT→COMBAT; visibility accumulator; NoiseBus with typed radii
  (suppressed = unidentifiable misc ~3m); believed-position aiming; breadcrumb search; sentry boredom.
- **Witness rule (law, NOT yet implemented):** the global COMBAT beacon stamps ONLY on witnessed contact.
  An unwitnessed silent kill is silent. Noise is the honest price — GUNSHOT radius goes 55m→~150m.
- Escalation ladder: finite-pool QRF, walking mortars on last-known, patrol doubling, alarm carriers
  with radio/flare (killable counterplay). Civilians inform on a timer.
- **Scoring pays avoidance:** +25/contact avoided, −25/detected (replaces kills×10 — ADR-006). Loud stays
  viable; it stops being the optimal XP strategy.
- ⚠ **`take_damage()` still stamps the COMBAT beacon before the death check (enemy_base.gd:1497) — a
  silent one-shot kill still triggers "YOU'VE BEEN MADE". Comments claiming this is fixed LIE. Bead o18o
  is open. This is build-order item #1.**
- ⚠ Debrief currently tracks zero contacts; VILLAGE_RAID demands 80% body count (becomes optional).
- ⚠ The "being noticed" detection pip (DESIGN §4.10) is unshipped after two decrees.

### 4.3 Enemy AI (Pillar 1/2)
- Hybrid: goal-scoring FSM combat brain inside a MoHAA-style situation-priority stack; personality maps
  per archetype (Local Force breaks / NVA doesn't); think/execute split (THINK_INTERVAL 0.15, verified);
  suppression; grenades ("LUU DAN!" telegraph); sappers at the wire.
- Open keystones: EnemySquad coordinator (gpvb), smart patrol/search/teamwork (0623), detection-driven
  ambience (r6qe).
- ⚠ `MAX_THINK_TIME` frame budget is declared and never used — wire it (perf day).

### 4.4 The squad (Pillar 4)
- 5-man persistent fireteam, MOS = verbs: **Point** (trap/ambush warnings), **RTO** (the net — lose him,
  lose CAS/mortars/resupply), **Medic** (revive chain, 2/mission, 30s clock), Pigman, Grenadier.
- Orders: FOLLOW / HOLD / MOVE-TO / FIRE-TOGGLE on **F1–F4** + secondary **C/H/X/N** (dual-bind law,
  ADR-012). Buddy rules: never break player stealth, never block trails/muzzles, no kill-stealing.
- Learn-by-doing squad XP + debrief pool spend (St/Ag/Al + skills). Permadeath; wounded heal ~2 St/day;
  veterans rotate; replacements arrive. **Loss is still costless (instant free rookies) — campaign-layer
  debt, ADR-006 adjacent.**
- ⚠ Squad-key input verified clean in code twice, never verified on Caleb's keyboard — R3 checklist item.

### 4.5 Fire support (ADR-011)
- RTO-gated (10m leash, ALL verbs), budgets rolled at briefing, danger-close double-press protocol,
  spotting-round → walk-in corrections; enemy mortars use the same system. Verified genuinely fixed.
- ⚠ Danger-close must also check the PLAYER's distance (currently squad-only).

### 4.6 Missions & generation (M6 target)
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
  none today), a pause menu (Esc currently pauses to nothing), tier consequences stated in the
  settings UI checkboxes.

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
- ⚠ `ModelActor._aabb_of` measures mesh space → speck soldiers (observed k 0.02–0.20). Build item #2.
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
  the declared next major focus (fmc8)** — milestone 0 is the Player-State layer (§8.3).
- ⚠ Invisible today: condition/consumables/stamina/breath (no HUD), detection pip, save feedback.

---

## 5 · The RECON tabletop backbone (what we keep fidelity to)

`RECON_ADAPTATION.md` is the numbers source of record: damage dice per caliber, detection/sight-cap
ratios (tuned up from tabletop, ratios kept), the ±25 contact scoring, XP pool economy, 7-element
briefing, hot-LZ outcome tables. Where realtime needs diverge (suppression, morale — RECON lacks both),
the divergence is named in an ADR, never silent.

---

## 6 · Scope law (what we are NOT building)

| Ruling | Items |
|---|---|
| **KILLED** | 8-directional sprite render matrix (ADR-001) · operation-style front door at launch (single faction) |
| **PARKED** | hunger (ADR-009) · SF/Marines (DLC) |
| **FROZEN (post-core)** | coop · interior/tunnel mode · driveable vehicles · capture/POW epic · battle director · RPG shop · ride-or-walk |
| **SHRUNK** | 100 bios → 20 great ones · HQ interactions stay walk-up-simple |

A frozen epic thaws only by explicit decree — a bead in `bd ready` is not a thaw.

---

## 7 · Corrections to stale law (for the CLAUDE.md / head-honcho rewrite)

The next project prompt must **not** carry these forward (all verified false 2026-07-10):
1. ~~"8-directional billboard sprite characters (CULTIC-style)"~~ → 3D PSX models are the renderer (ADR-001).
2. ~~HEAD 4×/TORSO 1.5×/LIMB 0.6×, `[1,6,45]` examples, enemy HP 60–80, Thompson default~~ → RECON dice
   only; HEAD fatal/TORSO 2.0/GUT 1.75+bleed/LIMB 0.75; enemy HP 65–85; M16 default (ADR-003).
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

## 8 · Build order (the standing decree, 2026-07-10)

0. **PLAYTEST R3 is the session entry point (ida9)** — nothing NEW ships until it verifies a2qb/r4bk.
1. **Stealth restoration bundle (THE one build):** real witness guard + delete the lying comments +
   GUNSHOT 55→150m + ±25 contact scoring + optional village clear. Close o18o with a headless probe.
2. **Trust-restoration day (measured):** `rendering_method` A/B → set it · ModelActor instance-space AABB
   fix (k≈0.9 accept) · streaming OFF ≤2km · decal FIFO cap · wire MAX_THINK_TIME. Close 8pbo + n2ij(1,2)
   with before/after numbers.
3. **Player-State HUD layer (fmc8 milestone 0):** condition/consumables/stamina/breath + detection pip +
   save/load feedback + pause menu + prompt-key truth.
4. **Damage data finish:** WW2 .tres out, vc_rifleman→SKS, descriptions honest, CLAUDE.md law rewritten.
5. **Hub conditions:** RECON 7-element briefing in the TOC + Huey ride restored.
6. **Jungle feel pass:** wind sway, undergrowth, composition — priced by #2's numbers.
7. **Law & ledger cleanup:** GameEnums (722 dead lines) + dead RTS code purged · roadmaps consolidated ·
   PLAYER_MANUAL corrected (9 known gaps).

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

> You are the **RECONgame Director** — guardian of a hardcore Vietnam tactical FPS (Godot 4.6, strict
> GDScript). Your constitution, in priority order: **the 5 Pillars → production/adr/ → this GAME_GUIDE →
> production/bible/ → DESIGN.md**. Task truth is beads (`bd prime` at session start); dated reports are
> history, not law. Enforce: the Fairness Law, the r4bk law (no feature without a HUD affordance), the
> witness rule, one damage grammar (RECON dice), the 1.7132m scale contract, the ≤2km no-streaming rule,
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
