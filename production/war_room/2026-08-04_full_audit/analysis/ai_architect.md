# AI-ARCHITECT — FULL AUDIT 2026-08-04

Independent sight. Every pointer verified against the working tree at HEAD `1795b519` this session.
Nothing from the 8/4 wiring has ever run; every "as wired" claim below is a READ, not a measurement.

---

## 1. Enemy AI (`scripts/enemies/enemy_base.gd`, 2,875 lines)

### Genuinely sophisticated

- **The witness rule is the crown jewel and it is guard-railed correctly.** Perception + corpse
  discovery run on EVERY unit at every activity tier — the tiering comment says so and the code does
  it (`enemy_base.gd:804-807`). `_can_witness` (`:970-983`) is a real check: sight cap via the shared
  grid (`:921-922`), facing cone outside COMBAT, smoke, then a real ray. `_witness_check` (`:990-1027`)
  gives clean kills a genuine payoff: no witness → the body goes on `unreported_corpses` AND into the
  evidence ledger as a liability (`:1023-1027`), later found by `_check_corpse_discovery`
  (`:1030-1051`) which re-anchors a squad hunt on the body. This is a complete stealth economy, not a
  flag.
- **Hot-set think budgeting is honest, not cosmetic.** Only the rolling hot-set runs targeting/LOS
  (`:815-819`); cold fighters adopt the squad's shared contact as a dict read (`:846-864`) — and the
  cheap path still pays the witness tax (`:861`: a cold man fires only at what he can `_can_witness`),
  which closes the classic "whole camp deadeyes one spotted player" hole. Hot slots are released on
  down and on death (`:2591`, `:2647`). Distance think-LOD on top (`:37-52`, 0.15s→0.6s).
- **Down-not-dead + enemy medics are theater done right.** `_become_downed` (`:2594+`) strips weapon,
  target, cover; IRON LAW he never re-fights (`:2495-2496` docstring); the medic drags AWAY from
  `last_known_target_pos`, never a peek at the player's true position (`:2560-2566`). The static
  `downed_pool` is cleared between missions (`scripts/main/mission_scope.gd:28`), and
  `unreported_corpses` likewise (`field_director.gd:22`) — the static-leak hygiene actually exists.
- **The `assault_driven` contract** (`:59-79`) is a hard-won distinction (the 7/29 "nobody fought but
  me" bug) and it is now documented as a units-contract comment, which is what comments are for.
- **Cover as a brokered resource**: static claim table + crowding cost (`:1926-1951`), shared with
  allies (`ally_base.gd:1304-1308` calls `EnemyBase._claim_cover`). One broker, both sides.
- **One scorer, both sides**: `CombatGoals` (`scripts/ai/combat_goals.gd:1-14`) is the single
  nine-verb brain; enemies feed real squad facts into it (`enemy_base.gd:1416-1417`).

### Vestigial / risk

- **`last_combat_contact_ms` is still a GLOBAL static** (`enemy_base.gd:272`, stamped `:1160`). The
  8/4 wiring de-fanged its worst consumer (the YOU'VE-BEEN-MADE toast now also requires an evidence
  fix, `field_director.gd:122-131`) but the static remains a repo-wide "somebody, somewhere is loud"
  bit that any future reader will mistake for "the player is in contact." Fossil-law candidate:
  scope it per-squad or rename it to say what it is.
- **`MAX_UNREPORTED_CORPSES: 48`** (`:966`) — added 8/4, never run. The FIFO forgets the OLDEST body;
  fine, but the eviction does not remove the ledger entry `on_body_left` created, so the hunt net can
  hold evidence for a corpse the witness system has forgotten. Not a bug, an asymmetry — noted so
  nobody "fixes" one side blind.
- `_execute_*` is a 900-line state-execution block (`:1497-2130`) — big but live; no fossils found in
  the paths I walked. The one dead-weight smell is historical and already registered by the fossil
  probe baseline; nothing new to add.

**Verdict on sophistication:** this is the deepest, most defensible system in the project. The
witness rule + evidence ledger + hunt net is a chain no player will see drawn, and it is real.

---

## 2. Hunt net + siege director — skeptical read of never-run code

### Hunt net (`scripts/missions/field_director.gd:102-174`)

- The 8/3 double-gate complaint is now a SINGLE consistent gate: both the alarm (`:122-131`) and the
  spawn (`:151-157`) require an `EvidenceLedger.best_fix`. Coherent.
- **THE POOL HAS NO TOP-UP. The briefing to me said "pool top-up as wired 8/4" — the codebase says
  otherwise.** `_hunter_pool` is initialized to 12 (`:106`), gated (`:136`) and decremented
  (`:161-162`), and those are ALL repo hits (`grep -rn _hunter_pool scripts/` → 3 lines, this
  session). Nothing refills it — not at the day/night seam, not from the siege reap, not per
  sim-day. Over the 30-minute demo day the AO can field at most 12 hunters, in 2-4 man waves,
  100-160s apart; after ~4 waves the hunt net is permanently inert for the rest of the day and the
  night. "Bleed the AO dry" is doctrine for a patrol (`:103`), but across a full DAY ending in a
  45-man siege, a dry hunt net at 14:00 means the entire afternoon has no reactive pressure. The
  codebase beats the document: **there is no top-up. If one was decreed, it did not ship.**
- Escalation never re-arms per phase either: `_escalation_active` latches true once (`:129`) and
  only the pool bounds it. Acceptable — but it means the §2.8 "night = 45 − hunters_killed"
  arithmetic has no code to hook: `hunters_killed` has ZERO repo hits (grep this session).
  **§2.8's day-feeds-night subtraction is unshipped**; `SIEGE_STRENGTH` is a flat 45
  (`demo_game.gd:68`, consumed `:364`).

### Siege director (`scripts/missions/siege_director.gd`) — the 8/4 thaw, read hostile

- **The freeze latch fix is real but the room arithmetic double-spends.** `_enforce_live_cap`
  (`:448-461`) counts only MATERIALIZED men; `_thaw_held_cells` (`:467-479`) releases held cells
  against `room = LIVE_CAP − materialized_men`. A released cell resumes MARCHING (physics on,
  `materialized == false`) and is invisible to that count for its entire approach — at 2.2 m/s
  (`marching_cell.gd:16`) from the ~190m demo ring to the 120m demo materialize radius
  (`demo_game.gd:387`) that is ~30s; from the full-game ring to 80m it is ~50-90s. `_physics_process`
  re-runs the cap every 0.5s (`:153-158`), and on every tick the SAME room releases the NEXT held
  cell (the released one is skipped by the `is_physics_processing()` test but never subtracted from
  room). **Every held cell whose strength fits the headroom is released against the same slots; the
  cap is breached by up to the sum of held-cell strengths when they arrive.** Compounding it:
  proximity `materialize()` (`marching_cell.gd:89-90`) has NO cap check — the only cap-checked door
  is `materialize_if_lit` via `_light_check` (`:421-430`). The freeze branch then cannot claw it
  back: a materialized cell can never be held (`:458` requires `not c.materialized`).
- **Mitigations that keep this from being a demo-day fire:** LIVE_CAP is 50 (`:36`) and the demo's
  total paper strength tops out at 45 (probe 11 → `reinforce(34)`, `demo_game.gd:391-400`), so in
  the DEMO the freeze branch can never fire and `_thaw_held_cells` is UNREACHABLE — the 8/4 fix is
  armor on a path the demo cannot enter. It goes live only in the full game (night-2 survivors +
  reinforcement stacking past 50). So: not a demo blocker, but the fix has never run AND cannot run
  in the demo, which means the first time it executes will be in front of the full game.
- **Starvation is closed by arithmetic, verify by measurement:** `THAW_HEADROOM: 6` (`:446`) equals
  `CELL_MAX: 6` (`:23`), so no held cell can be permanently too big for the room once the gate
  (`:453-455`) opens. Good. But if materialized strength stalls in the (LIVE_CAP−6, LIVE_CAP) band
  — a stalemate where the garrison stops killing — held cells never thaw, `live_strength()` keeps
  answering paper strength (`marching_cell.gd:55-57`), the break ratio (`:384-386`) never moves, and
  the siege runs to `MAX_DURATION_S` (:377, acknowledged in the `:433-441` comment). That is a
  bounded failure (dawn break at 480s), not a hang — acceptable, but it is the exact shape the 8/3
  council called the one-way freeze latch, now one band narrower.
- `reinforce()` (`:243-263`) correctly grows peak with strength and splits squads — the
  probe-becomes-assault branch (`demo_game.gd:391-400`) is the demo's ONLY path to 45 men and has
  never run. It is three constants and a call; the risk is not the code, it is that nobody has ever
  watched 45 men cross 190m under the 0.5s poll.

> **MEASUREMENT M-AI-1 (siege cap, full game):** force `run_strength = 50 + reinforce(20)` in the
> support-fire test room, log `materialized_men` each 0.5s poll, assert it never exceeds
> LIVE_CAP + CELL_MAX. Expected today: breach up to the sum of concurrently-marching thawed cells.
> **MEASUREMENT M-AI-2 (demo assault):** run the demo to SIEGE_AT_S once and read the
> `[Siege] reinforced +34` line plus a body count at the ring. This is minutes of a playtest the
> project already owes (M-1..M-5).

---

## 3. §2.11 ruled items 1-4 — WHAT ACTUALLY SHIPPED: **NONE OF THE FOUR**

Checked in code this session, not the backlog:

1. **Feed `squad_broken`/`force_ratio` to the shared scorer — NOT SHIPPED.** The ally Context feed
   (`ally_base.gd:781-801`) still sets neither `c.squad_broken` nor `c.force_ratio`; both default to
   the "no squad support known" case (`combat_goals.gd:52-53`). The enemy passes both
   (`enemy_base.gd:1416-1417`). Partial credit exists — `SquadSystem._update_break` does push the
   flag onto each man (`squad_system.gd:387-408`) and it biases the ally GATES
   (`ally_base.gd:106-117`) — but the scorer's own broken/ratio terms never fire for allies. The
   decreed ~2 lines are still unwritten.
2. **MOS-weighted courage — NOT SHIPPED.** `courage = randf()` flat (`ally_base.gd:295`); `mos` is
   read nowhere in ally AI (only the roster dict comment at `:166`). The RTO still plays hero ~25%
   of the time.
3. **Concealment term in the cover search — NOT SHIPPED. This is the Vietcong gap and it is intact.**
   `_find_cover_point` (`ally_base.gd:1286-1310`) accepts a candidate only on a BLOCKED physics ray
   (`:1298-1303`); no grid read, no concealment term — while the ally already owns a lazy
   `_sight_grid()` accessor (`:661-668`) and uses it for target acquisition (`:692`). The sim pays
   for grass (`sight_cap.gd`, `gameplay_grid.gd` per the 8/3 synthesis §2.11) and the ally brain
   still cannot see the reward. The O(1) read is one function away from where it is needed.
4. **Player-placed thumper — NOT SHIPPED.** `_grenadier_tick` (`squad_system.gd:456-489`) is still a
   fully automatic cluster scan (3+ enemies within 12m, 30-80m band, 14s cooldown). No input action,
   no aim path.

**The 8/4 commit was the rescope (arc, siege, air, viewmodel accumulator, hunters gate) — it did not
touch the ally bar.** All four §2.11 rulings are open work wearing a RULED stamp.

---

## 4. The capability-not-gun doctrine — the verb arithmetic NOW

| Verb | Owner | Spendable or automatic (pointer) |
|---|---|---|
| Trap/ambush-spot | POINTMAN | AUTOMATIC (`squad_system.gd:440-453`, passive scans) |
| Call-for-fire | RTO | **SPENDABLE** (player radio + finite allotment) |
| Revive + bandages | MEDIC | AUTOMATIC trigger, spendable AMMO (6 bandages `:10`, boxes on HOLD `:182`) |
| Sustained fire | MG | AUTOMATIC (`fire_rate_mult = 1.6` at spawn, `:80-81` — a stat, not a verb) |
| Cluster thumper | GRENADIER | AUTOMATIC (`:456-489`) |

Still **one spendable verb of five** — the 8/3 measurement stands unchanged.

**`_hand_off_radio` (`squad_system.gd:582-604`) changed the arithmetic, in a way nobody has priced:**
the handoff REASSIGNS the MOS of the nearest living man (`heir.member["mos"] = "RTO"`, `:601`).
Every verb resolves through `member_by_mos` (`:166-170`), so:
- The radio verb now SURVIVES the RTO's death at full quality — losing the RTO no longer costs the
  one spendable verb. The 8/3 insight ("losing a man must cost you a verb you were using") is now
  LESS true than it was, not more.
- **The game silently deletes a DIFFERENT verb instead, chosen by proximity.** If Doc is nearest the
  body, `member_by_mos("MEDIC")` returns null from that frame on → `can_revive()` false
  (`:224-230`) → the player's entire fail-forward chain is gone, without a death animation, because
  of where a man happened to be standing. Same for MG (sustained fire + the 1.6 rate mult persists
  on a man now labeled RTO — the label moved, the gun did not) and GRENADIER (thumper dead,
  `_grenadier_tick:459-460`). The heir also keeps his old weapon and body — an "RTO" carrying an
  M60 with no handset rig visual until `_wire_rto_radio` attaches one (`:602`).
- The roster save (`CampaignState.save_campaign()` on death, `:566`) persists the reassignment —
  the squad can arrive at mission 2 with two RTOs on paper and no medic, permanently.

This is not a bug in the handoff's own terms (his 8/3 ruling was verbatim "they turn into the RTO
guy") — but the COST side was never ruled: **which verb dies when the radio is picked up.** Cheapest
honest fix is preference-ordering the heir search (RIFLEMAN first, specialists last) — ~4 lines,
turns "the game deletes a random verb" into "riflemen carry the radio unless nobody is left," which
is also doctrine. Decision Queue item, glossed: *"When the radioman dies, the nearest man becomes
the new radioman even if he is Doc — should riflemen pick it up first so you never silently lose
the medic?"*

---

## 5. The parallel-systems sprawl — counted

Live systems that DECIDE (not render), with sizes measured this session:

1. Enemy goal-FSM — `enemy_base.gd` 2,875
2. Ally FSM — `ally_base.gd` 1,587 (+ `garrison_defender.gd` 186)
3. Squad verb layer — `squad_system.gd` 613
4. Enemy squad authority (break/hot-set/shared contact) — `enemy_squad.gd`
5. Siege director + marching cells — 776 + 170
6. Hunt net + evidence ledger — `field_director.gd:102-174` + `evidence_ledger.gd`
7. LazyGroup ambient circuits — `lazy_group.gd` 107 (spawned `mission_generator.gd:813-826`)
8. Camp life — `camp_director.gd` 156 (stood up by LazyGroup on wake)
9. Garrison occupations — site_planner work-marker round-robin (fed by the marker parse M-1 gates)
10. Civilians + schedules — `civilian.gd` 909 + `civilian_schedules.gd` 308 (+ BT kit `scripts/ai/bt/`)
11. Litter team — `litter_team.gd` 192
12. Air traffic — `air_traffic.gd` 764
13. Ambush planner — `ambush_planner.gd` 147
14. Friendly patrols + convoys — 156 + 166
15. Ambient war (audio-only theater) — `ambient_war.gd` 239

Fifteen. The ~14 estimate was accurate. The consolidation already paid for is real: ONE goal scorer
(`combat_goals.gd`), ONE break authority (`EnemySquad.break_state`, used by allies at
`squad_system.gd:399-400`), ONE cover broker, ONE spawn authority (`spawn_tracked_enemy`).

**Two systems doing the same job with different rules — concrete unification candidates:**

- **A) LazyGroup vs MarchingCell — the same idea, two rulebooks.** Both are "group is one node until
  bodies are needed." LazyGroup wakes on PLAYER proximity (120-140m, `lazy_group.gd:8`), never
  emits noise while dormant, never returns to dormancy; MarchingCell wakes on OBJECTIVE distance or
  light, emits footstep noise while dormant (`marching_cell.gd:79-84`), reports paper strength to a
  ledger. A dormant LazyGroup is invisible to the witness/evidence economy; a dormant MarchingCell
  is audible. UNIFY: one virtual-group class with pluggable wake conditions.
  COST: ~2 days + re-verifying the siege ledger contract (ADR-035 §2) and every
  `mission_generator` spawn site; the siege's paper-strength accounting is subtle and newly
  patched — touching it before it has EVER run would be malpractice. FULL GAME work, after M-AI-1.
- **B) Camp life three ways.** `camp_director.gd` (enemy camps), the garrison occupation round-robin
  (site_planner), and `civilian_schedules.gd` all map "time/station → clip + position" with three
  different data shapes. The chow-hall wiring (OPEN) is about to add a fourth consumer. UNIFY the
  data shape (station/schedule record), not the drivers. COST: ~1 day, best done AS the chow-hall
  wiring rather than after it, or the fourth dialect ships. FULL GAME, but the cheap moment is now.
- **C) Ally vs enemy perception.** Enemy: awareness ramp, FOV cone, noise, witness. Ally: distance +
  sight-cap only (`ally_base.gd:671-699` — no facing cone, no noise subscription). Allies are
  omnidirectional detectors at cap range. This is a RULES divergence inside one fight, invisible in
  code review, visible on the day an enemy sneaks up behind the squad and five men snap-lock him.
  Not a full unification — port the facing-cone term only. COST: ~2 hours. DEMO-adjacent.
- **NOT candidates:** `ambient_war` (pure theater, zero decisions binding on real agents),
  air_traffic (separate physical domain), litter team (consumes the casualty ledger, decides
  nothing about combat).

The blindspot memory stands: what keeps 15 systems safe is the four shared authorities. Every new
system that computes its own break/cover/target/spawn instead of calling those four is the failure
mode to flag in review — the siege director came CLOSE (its own courage average `:401-411`, its own
ledger) and justified each divergence in comments; that is the standard.

---

## 6. MARKSMAN — still absent, and now the absence is annotated

`MOS_ORDER` is still the five slots (`squad_roster.gd:64`); MARKSMAN has a weapon (`m70` in
`MOS_WEAPON`, `squad_system.gd:114`), a body (`us_grunt_marksman`, `:122`), a display name (`:79`)
and a comment stating he "is drawn only as an alternate" (`:62-63`) — **but no alternate-draw code
exists anywhere in `squad_roster.gd`** (grep this session: MARKSMAN appears at `:62`, `:79` only;
`ensure_roster` replaces KIA with rookies, no alternate path). The comment describes a mechanism
that was never built — that is a POINTER-LAW violation living in the source, one notch from a
fossil. Either build the alternate draw (KIA specialist → chance the replacement is a marksman;
~10 lines in `ensure_roster`) or delete the promise from the comment.

---

## STRONGEST (ranked)

1. **The witness rule + evidence ledger + hunt-net chain** (`enemy_base.gd:970-1051` →
   `evidence_ledger` → `field_director.gd:146-174`) — a complete, closed stealth economy where
   clean kills, left bodies and noise all have distinct prices. DEMO + FULL GAME.
2. **The consolidation spine**: one goal scorer, one break authority, one cover broker, one spawn
   authority (`combat_goals.gd:1-14`, `squad_system.gd:399`, `enemy_base.gd:1942`,
   `marching_cell.gd:117`) — the structural answer to the 14-system blindspot, already paid for.
   FULL GAME.
3. **Hot-set + think-LOD + body-gate budgeting** (`enemy_base.gd:37-52`, `:811-864`, `:663`) —
   honest cheap paths that keep the witness check even when cold. DEMO (it is what makes a 45-man
   night affordable).

## WEAKEST (ranked)

1. **All four §2.11 ally rulings are unshipped** (`ally_base.gd:295`, `:781-801`, `:1298-1303`;
   `squad_system.gd:456-489`) — the Vietcong bar was RULED 8/3 and the codebase does not know it.
   The squad still cannot use grass, the RTO still plays hero, and 4/5 verbs are automatic. DEMO.
2. **The siege thaw path has never run, CANNOT run in the demo (45 < LIVE_CAP 50), and
   double-spends its room when it does run** (`siege_director.gd:448-479` + uncapped proximity
   materialize `marching_cell.gd:89-90`). The first execution will be in front of the full game.
   FULL GAME.
3. **`_hand_off_radio` silently deletes a proximity-chosen verb and persists it to the campaign
   save** (`squad_system.gd:582-604`, `:566`) — the medic can cease to exist because he stood near
   a body. DEMO (the demo's radio-is-an-object ruling routes through this exact code).

## IMPROVE (ranked by value per effort)

1. **Ship §2.11 items 1-3** — ~20 decreed lines total (`ally_base.gd:781-801` two-line Context
   feed; `:295` MOS courage table; `:1286` concealment term using the `_sight_grid()` accessor the
   file already owns at `:661`). Highest behavior-per-line available anywhere in the project.
   *Sacrifice:* squad legibility — men in grass need the nameplate check, and a broken squad
   visibly leaving reads as a bug to strangers. DEMO.
2. **Preference-order the radio heir** (~4 lines in `squad_system.gd:588-599`: RIFLEMAN first) +
   put the which-verb-dies question in the Decision Queue. Protects the entire fail-forward chain
   from a positional coin flip. *Sacrifice:* "nearest man grabs it" realism. DEMO.
3. **Hunter pool top-up at the day/night seam** (one line: reset/raise `_hunter_pool` when
   `MissionWeather.is_night` flips, `field_director.gd:106`) so the afternoon is not pressure-free
   — and it is the hook §2.8's `45 − hunters_killed` arithmetic needs anyway. *Sacrifice:* "bleed
   the AO dry" purity within a single day; cap it (e.g. +6) to keep the doctrine legible. DEMO.
4. **Reserve thaw room for marching cells** (subtract released-but-unmaterialized strength in
   `_enforce_live_cap:449-452`; ~5 lines) + cap-check proximity `materialize()`. Do it AFTER
   M-AI-1 measures the breach — the path cannot fire in the demo, so it is not demo-critical.
   *Sacrifice:* none real; the risk is touching never-run code twice instead of once. FULL GAME.
5. **Ally facing-cone perception** (~2 hours, port `enemy_base.gd:975-978` into
   `ally_base.gd:671-699`). *Sacrifice:* the squad gets genuinely surprisable — which is the bar.
   FULL GAME (demo-adjacent polish).
6. **MARKSMAN: build the alternate draw or delete the comment's promise**
   (`squad_roster.gd:62-64`). ~10 lines or 1 line. *Sacrifice (if built):* silhouette clarity of
   the fixed five; (if deleted): a finished asset stays shelved. FULL GAME.

## Measurements specified (truth unknown, do not guess)

- **M-AI-1** — siege cap breach magnitude under forced 50+20 strength (§2 above).
- **M-AI-2** — one demo run to SIEGE_AT_S: does the probe→reinforce(34) path stand up 45 men
  outside the wire, and does the 190m ring read as an assault under the 0.5s poll.
- **M-AI-3** — hunt-net cadence across the full 30-min day: log every `_process_escalation` spawn;
  measure the minute the pool dries. Confirms improvement 3's sizing.
- **M-AI-4** — ambient-road constraint from §2.5: measure min distance of `RoadNetwork.build`
  polylines (`mission_generator.gd:739-741`) from `fsb_center`; `_poll_firebase_threat`
  (`field_director.gd:1340`, `FSB_THREAT_MEN` 2 at `:969`) stands the garrison to if a 2-man
  ambient patrol wanders inside 90m. Nobody has measured the demo's actual road offsets.
