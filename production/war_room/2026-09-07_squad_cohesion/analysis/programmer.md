# PROGRAMMER / TECHNICAL DIRECTOR — SQUAD COHESION
**War Room 2026-09-07 · Phase 2, Individual Sight · no cross-talk**
Every claim below carries a `file:line`. Where I could not find a pointer, I say so — that is the finding.

---

## PART 1 — THE AUDIT: what already does a cohesion-like job

### 1.1 The symbol search, first
`grep -ri` over `scripts/`: **`cohesion` = 0 hits. `regroup` = 0. `squad_state` = 0. `morale` = 2 hits,
neither of them a system** (`agent_registry.gd:11` is a prose comment; `enemy_base.gd:2699` is a comment
labelling the rout ladder). `panic` = 13 hits, **none on a soldier** — `burning.gd`, `civilian.gd`,
`animal_routine.gd` only. `nerve` = 31 hits and **is a real system** (§1.4).

So nothing is named cohesion. That does **not** mean nothing does the job. Six systems do.

### 1.2 `SquadCoordinator` — the tactical-coherence engine, shipped 2026-08-24, WIRED BOTH SIDES
`scripts/ai/squad_coordinator.gd` (242 lines, static registry, `RefCounted`, no node lifecycle).
Cleared by `MissionScope.reset()` (`scripts/main/mission_scope.gd:25`). Probe:
`tests/test_squad_coordinator.gd`.

What it actually does, per `(side, squad)` key:
- **Exposure tokens** (`:141-172`) — the *right to be out of cover*. `d.exposure_tokens` men may hold one
  at a time (US default 3, `doctrine_data.gd:26`); a held token renews, a fresh grant needs a free slot,
  the **active element**, and a `grant_stagger_ms` gap so element moves start across thinks instead of as
  one wave. TTL'd (`token_ttl_ms` 6000) so a dead holder cannot starve the pool.
- **The suppressor slot** (`:194-242`) — exactly ONE base-of-fire man per squad, re-elected every
  `SUPPRESSOR_REFRESH_MS` 1200 ms, scored: MG +4, covered +2, passive element +1, incumbency +1.
- **Covering-fire census** (`:93-113`) — one write per trigger pull, 1500 ms window, per squad.
  The header records that this **replaced a global static pair** that counted an ambient patrol 400 m
  away as "my squad is covering me" (`ally_base.gd:186-189`).
- **Two-element bounding overwatch** (`:126-136`) — registration-order parity assigns each man to element
  0/1; elements alternate on `bound_period_ms` (6000). Degrades gracefully under attrition by design.
- **Shared suppress point** (`:180-191`) — the squad's last-known contact position, TTL 8 s.

**Wired, not dead.** 12 call sites in `scripts/allies/ally_base.gd` (`:1067, :1071, :1128-1131,
:1173, :1197, :1211-1214, :1217, :1629, :2075, :2321`) and 9 in `scripts/enemies/enemy_base.gd`
(`:1496, :1550, :1576, :1602-1605, :1607, :1612, :1895, :2415, :2995`). It changes behaviour: a picked
`ADVANCE`/`FLANK` is **downgraded to `ENGAGE_TARGET`** when the token is refused
(`ally_base.gd:1197-1199`, `enemy_base.gd:1607-1610`), and the elected suppressor's goal is
**overwritten** to `SUPPRESS_TARGET` (`ally_base.gd:1211-1215`).

**This is squad cohesion, built, running, and unnamed.**

### 1.3 Squad break — ONE authority, both sides, wired
`EnemySquad.break_state(live, peak, avg_courage, base_ratio)` (`scripts/enemies/enemy_squad.gd:118-122`):
`threshold = clamp(0.45 + (0.5 - courage) * 0.4, 0.20, 0.80)`, `broken = live/peak < threshold`.
Elite holds to 29 %, green breaks at 61 %.
- Enemy: `EnemySquad.is_broken(squad_id)` on a 1 s TTL cache (`:125-161`), fed to the scorer at
  `enemy_base.gd:1580`.
- Ally: `SquadSystem._update_break()` (`scripts/squad/squad_system.gd:554-584`) calls **the same pure
  function**, sets `squad_broken` on every living member, toasts *"SQUAD COMBAT INEFFECTIVE - BREAKING
  CONTACT"* and fires the `fall_back` VO. Called every physics frame, self-throttled to 1 s
  (`squad_system.gd:540`).
- Effect: `+0.7 RETREAT` in the shared scorer (`combat_goals.gd:165`); on the ally side it also forces
  cover-first (`ally_base.gd:220`), **forbids closing** (`ally_base.gd:227-228`), widens the hold band
  (`ally_base.gd:1538`) and blocks MG-post seeking (`ally_base.gd:906`).
- Probe: `tests/test_squad_break.gd` (6 sub-tests incl. `_test_one_break_authority`).

### 1.4 Nerve drift — a real, moving morale system on the ally side only
`ally_base.gd:120-127, 154-177`. `_nerve_drift` starts 0, **falls 0.12 per squadmate down within 25 m**
(`:154-156`, driven from `:2326-2331`), floors at **-0.30**, recovers **0.02/s and only in a lull**
(`:817-819` — the recovery branch is the `else` of the suppression branch).
`effective_courage() = clamp(courage + drift + RALLY_BONUS, 0, 1)`, where the +0.10 rally bonus applies
only when the player is within 6 m **and between the man and the threat** (`:159-177`). The comment at
`:131-134` records the fix: a proximity-only bonus was permanently on and made the coward branch
unreachable.
That number is then **the ally's whole temperament** — written straight into `c.aggression` /
`c.self_preservation` (`ally_base.gd:1157-1160`), and it gates `wants_cover_first` and
`may_close_distance`.
**This is a morale system with an unusual name.** The enemy has no equivalent: the local `nerve` at
`enemy_base.gd:2705` is a *force-ratio* term inside the rout ladder, not a persistent state.

### 1.5 Suppression — the one shared ledger, symmetric, fully wired
`scripts/ai/combat_posture.gd` (137 lines) is the single contract for both factions: crouch at 0.6,
pin at 0.7, fire ceiling 0.85, prone latch 0.85 enter / 0.6 exit with three independent exits, cover
multiplies accrual **and** recovery (CoH doctrine, `:22-26`), 4 s pin-mercy widening for the *shooter*
(`:31-32`), and a decay-recency throttle so the fear gate holds between bursts (`:47-52`).
Delivery is per-bullet: `CombatManager._crack_past` (`scripts/autoload/combat_manager.gd:415-424`)
walks `AgentRegistry.allies` on every shot, and `apply_suppression_in_area` (`:434-460`) is explicitly
faction-blind and includes the player.
Allies carry a second scalar, `incoming_pressure` (`ally_base.gd:351-354`), because
`suppression_level` decays in ~3.3 s and a decision sampled between bursts would see zero — the scorer
reads `max(suppression_level, incoming_pressure)` (`:1152`).

### 1.6 Local force ratio — shipped, and the most expensive cohesion-shaped term in the frame
`ally_base.gd:1236-1253` and `enemy_base.gd:1619-1635`: an **O(allies + enemies) distance scan, per
man, per think**, 25 m band. Feeds `+0.15 ADVANCE` at 2:1, `RETREAT = max(retreat, 0.5)` below 0.6,
and a `numbers` multiplier on retreat (`combat_goals.gd:151, 167-171`). Note the ally version walks
`AgentRegistry`; the enemy version calls `get_tree().get_nodes_in_group()` **twice per think per man**,
allocating two arrays each time.

### 1.7 Formation and spacing — built, wired, unnamed
- Ally follow: a per-man ring offset rolled once at 2.5–4.5 m (`ally_base.gd:480-481`); the huddle
  **strings into a staggered file** above player speed 3.2 and collapses below 1.5 (`:264-265,
  :1420-1443`), point man 12 m ahead (`:1438-1439`), lateral ±1.1 m, 3.5 m per file slot. The slot
  itself is rate-limited at 12 m/s so a shape flip does not teleport it (`:266-268, :1444-1450`).
  `file_slot`/`point_slot` are assigned in `squad_system.gd:131-132`.
- Combat separation: `COMBAT_SPACING_M` 3.0 push + `PLAYER_SPACING_M` 1.6 (`ally_base.gd:2238-2276`),
  explicitly "a nudge added to whatever the follow slot already wanted".
- Catch-up teleport: `squad_system.gd:686-758` — at most 2 men/tick, unseen, non-combat, nav-clamped.
- Enemy mirror: `patrol_file_slot` (`enemy_base.gd:2364-2377`), assigned by `camp_director.gd:82`,
  `lazy_group.gd:100`, `ai_stress_arena.gd:1834`.
- Civilians: `scripts/ai/group_walk.gd` (56 lines) — a lead + slot fan, writes no velocity.

### 1.8 THE HOLE: the ally side has **no** information sharing
The enemy squad shares everything — designated target, last-known, a 20-crumb trail with water
breaking sign, a 12 s knowledge TTL, sectored expanding hunt nets with re-anchor, and a
`SHARE_RANGE * 2` wake (`enemy_squad.gd:217-431`, consumed by `enemy_base._squad_sync():1051-1070`).

**`AllyBase._find_target()` (`ally_base.gd:949-1001`) shares nothing.** Each man scores the nearest
enemy inside his own `SightCap`, with stickiness and an aim-settle beat. `_call_contact()`
(`:1006-1020`) computes a bearing off his own facing and **plays a VO line — that is all it does. It
writes no data anywhere.** A man who sees nothing learns nothing from the man beside him who is firing.

That asymmetry is the single largest cohesion gap in the codebase, and it is invisible in the docs.

### 1.9 Orders — instant, free, unconditional
`SquadSystem._unhandled_input` (`:277-292`) → `_order_all` (`:303-311`): one loop, `set_order()` on
every living member, one toast, one VO ack from the first living man. **No latency, no per-man
acknowledgement, no refusal, no propagation model.** `set_order` (`ally_base.gd:329-331`) writes two
variables. Four verbs (ADR-012), dual-bound, all four keys spent.

### 1.10 Compute tiering (for the perf question)
- `EnemySquad` hot-set: `HOT_CAP` 50 / `HOT_CEILING` 64, `is_hot/request_hot/release_hot`
  (`enemy_squad.gd:41-93`). **Enemy only** — `AllyBase` has no hot gate.
- `enemy_base._update_think_lod` (`:41-56`): think 0.15 / 0.3 / 0.6 s by player distance, re-evaluated
  every 2 s. **`AllyBase` has no think LOD** — flat `THINK_INTERVAL` 0.15 (`ally_base.gd:25`). With 8
  men that is correct, not a defect.

---

## PART 2 — THE PERF PRICE, HONESTLY

### 2.1 The brief's premise is a month stale, and I have to say so (NO DRIFT)
The brief says the project is **CPU-bound in the AI**, citing the ADR-026 bench (14.0 → 23.1 fps).
That row is **2026-07-20** (`ADR-026:121-122`). It was **overturned on 2026-08-14** by the crucible on
the named floor box (`production/PERF_LEDGER.md:1125-1150`, `tools/probe_crucible.tscn`):

> "**The GPU is the wall on the UHD floor.** 43.5 ms of GPU at a QUIET night arena — 21 fps before one
> AI thinks — growing to 94 ms under load. The 2026-07 'CPU-bound' verdict came from a bench that
> assumed the frame after graphics cuts."

Real-renderer EVERYTHING phase: **130.5 ms frame, of which 94.4 ms is GPU and 4.3 ms is render-CPU**;
the headless game thread at the same phase is 43.6 ms. The CPU curve is real and it matters — the
30-man siege wave alone doubles the game thread 10 → 19 ms — but *the AI is no longer the wall.*

### 2.2 Inside the AI, `_think` is the cheapest bucket there is
`PERF_LEDGER.md:295-303`, 65–67 live units, headless:

| bucket | ms/physics-frame |
|---|---:|
| think | **1.20** |
| move_and_slide | 8.78 |
| hitzone sync | 9.87 |
| anim/execute remainder | 17.63 |
| **SUM** | **37.5** |

Think is **~3 %** of the AI wall. The ledger's own words: *"the wall is the BODY."*

### 2.3 What that means for cohesion, priced
- **Logic that lives in `_think` and moves no bodies buys from the 3 % bucket.** A squad-scoped scalar
  recomputed once per squad per second is *unmeasurable* — `SquadSystem._update_break` already does
  exactly that shape and has never appeared in a bench row.
- **The shape to copy is `SquadCoordinator`:** O(1) dict upsert per man per think, plus a TTL-lazy
  recompute at *query* time over ≤ squad size, at ~1 Hz. That is why it costs nothing today.
- **The shape to refuse is `_local_force_ratio`:** per-man O(n) scans. At 65 men that is ~4,200 distance
  checks per think cycle, already shipping twice (once per side). A per-squad coherence solve written
  that way would double it. Written coordinator-style — one census per *squad*, not per *man* — it costs
  roughly 1/8th of that on the player's squad and can never be worse than what already runs.
- **Buddy spacing checks are the O(n²) trap, and this repo already tripped it.** `_grenadier_tick` walks
  every enemy against every other enemy and had to be throttled to 0.4 s for that exact reason
  (`squad_system.gd:528-534`).
- **Formation maintenance is the genuinely expensive one**, because it makes men *walk more*, and
  `move_and_slide` + hitzone sync + anim is ~94 % of the AI wall. Every metre of extra formation
  correction is bought from the most expensive bucket in the frame.
- **Order-propagation latency is free** (a timestamp and a queue drained at think rate) and is the
  cheapest "cohesion you can feel" in the whole design space.

### 2.4 Ruling on the tick
**It rides `THINK_INTERVAL` 0.15 for per-man writes and a ~1 s TTL-lazy recompute for squad-wide state.
It gets no tick of its own, no node, and no autoload.** Reasons, in order:
1. `SquadCoordinator` already proves the pattern works headless with no lifecycle
   (`squad_coordinator.gd:6-12`).
2. `MissionScope.reset()` already clears it — a new static registry must register there or it leaks
   state across missions and poisons probes.
3. **ADR-025 is SUPERSEDED and its `WorldSim` tier scheduler is condemned** (`ADR-025:1-19`). Do not
   build a new LOD/tick authority under a cohesion banner; that is the exact drift ADR-025 was killed
   for. Three names for one idea is what ADR-023 forbids.

---

## PART 3 — THE MANDATORY FIVE

### Q1. Real mechanic, or a re-skin of suppression/morale we already have?
**Mechanically it is a RE-SKIN — and a fairly complete one.** Exposure tokens, the suppressor slot, the
covering-fire census, bounding elements, the break threshold, nerve drift and force ratio *already*
implement "the squad fights as a unit or it doesn't", on both sides, guarded by two probes.

**Two things are genuinely absent, and only one of them is a design question:**
1. **Ally-side information sharing** (§1.8) — a code hole, not a design gap.
2. **A name, a number, and a player-facing surface.** Today the only cohesion signal that reaches the
   player is one toast and one VO line at the break.

So: *the mechanism is built and unnamed; the **mechanic** — something the player perceives and plays
against — does not exist.* Different work, different gate rulings.

### Q2. If real, what is the player-visible verb? (r4bk binds)
**I argue for NO new verb and no fifth key.** ADR-012 spends F1–F4 + C/H/X/N and neither binding may be
removed. The verbs his own shape needs already exist:
- The **shatter** is the ambush — no verb, it happens to you.
- The **recovery** is `FOLLOW / ON ME` (F1/C) and `HOLD` (F2/H, which already drops the ammo box,
  `squad_system.gd:283`). Consolidating on the leader *is* the drill.

r4bk is then satisfied by **presentation on a shipped system**: a state line in the squad strip
(`mission_hud.gd:249-290`), which already polls at 2 Hz and already renders per-man OK/HIT/CRIT/KIA.
~30 lines, and gate-exempt (Part 5).

If the council insists on a resource, note that ADR-018 §2's silent-behavioural r4bk exemption is
**already spent once** on squad XP. Claiming it a second time is not a precedent, it is a pattern.

### Q3. What does it cost? Name the sacrifice.
1. **Refusal is the sacrifice.** Any cohesion gate on orders means the player presses a key and nothing
   happens. `squad_coordinator.gd:11-12` states the current law verbatim: *"Orders are REFUSABLE by
   construction: the coordinator only shapes goal picks; survival verbs are never routed through it."*
   A cohesion resource that gates *player* orders inverts that — refusal by mandate. Pillar 3.
2. **The siege regression is a priced, historical cost.** `combat_goals.gd:16-19` records that an
   unpressed ADVANCE tops out at 0.61 against an incumbent ENGAGE of 1.19, which is why *"a night
   assault has always stalled at the wire"*. Any new multiplier on ADVANCE must exempt `assault_press`
   (ADR-035) or the demo's climax stalls again. We have shipped this bug once already.
3. **Perf:** small if it rides the coordinator's shape (§2.3), real if it moves bodies.
4. **Fossil debt:** Part 6. A second break authority is a permanent tax on every future reader.
5. **State hygiene:** every new squad-scoped static must be cleared in `MissionScope.reset()` or probes
   inherit last mission's squad.

### Q4. Where does it collide with an existing ADR?
| ADR | Collision |
|---|---|
| **ADR-012** | Four prime keys spent, dual-bound, neither binding removable. No key free for a cohesion verb. |
| **ADR-021** | The follow phase *"may never be enforced."* A system that refuses the player's orders is enforcement pointed the other way. |
| **ADR-018 §2** | The silent-behavioural r4bk exemption is already claimed once, for squad XP. |
| **ADR-023** | If cohesion subsumes the break, the break must DIE, not coexist. |
| **ADR-025** | SUPERSEDED; its `WorldSim` tier scheduler is condemned. No new tick authority. |
| **ADR-035** | `assault_press` must be exempt from any new movement gate, or the siege stalls at the wire (`combat_goals.gd:16-19`, `squad_coordinator.gd:143-147`). |
| **ADR-015** | The gate — Part 5. |
| **ADR-040** | The near-miss fires on *the shooter entering combat*, not on player unawareness — so it cannot carry the weight point 6 puts on it. |

### Q5. The Summoner's six points, by number
1. **PARTIALLY REFUTED (as a citation), CONFIRMED (as intent).** Pillar 1's text of record is
   *"Believable firefights — AI that fights like soldiers AND weapons that kill like weapons, neither
   subordinate"* (`CLAUDE.md:21`, `bible/BIBLE.md:85-101`). **Brothers in Arms is not named anywhere in
   canon.** The inheritances actually named in code are *Company of Heroes* (suppression ledger,
   base of fire — `combat_posture.gd:22`, `squad_coordinator.gd:203`), MoHAA (situation stack,
   `GAME_GUIDE.md:163`) and Quake 3 (think/execute). His feel-target is compatible with Pillar 1 but it
   is **not already canon** — adopting it is a new decree, not a citation.
2. **CONFIRMED, and it is built.** The ambient war layer runs: `scripts/ai/ambient_war.gd` (239 lines),
   `scripts/ai/air_traffic.gd` (887 lines), air beats walking the compass in the demo arc
   (`GAME_GUIDE.md:433`). The grand war is already ambient and the fight is already squad-sized.
3. **CONFIRMED for the DOCS, REFUTED for the CODE.** No ADR covers tactical coherence — correct, I
   checked all 46 files in `production/adr/`. But the machinery shipped **2026-08-24** without an ADR
   (§1.2). The gap is documentation and player-facing surface, not AI capability. *He is right that
   nobody wrote it down and wrong that it does not exist.*
4. **CONFIRMED, and more strongly than he states it.** Nothing in the ally brain waits for an order.
   `_evaluate_goals` runs every 0.15 s on its own authority (`ally_base.gd:826-829`); orders only write
   `order_mode`/`order_pos` (`:329-331`) and are consulted in the movement branch, never in the combat
   branch. Reaction is `lerpf(0.95, 0.30, char_reaction)` seconds — **0.30–0.95 s, no order needed**
   (`ally_base.gd:991-995`). SOP-driven react-to-contact is as-built. The player commanding the
   *recovery* is exactly what F1/F2 already do.
5. **CONFIRMED.** The enemy chooses the fight: hunter teams converge on the `EvidenceLedger` lead and
   never on the player's transform (`field_director.gd:112-182`), `scripts/enemies/ambush_planner.gd`
   exists, and the demo arc opens with *their* probe on the wire (`demo_game.gd:26-69`).
6. **REFUTED IN PART.** Three faults:
   (a) *"gating which orders function"* collides with Pillar 3 and inverts the coordinator's own
   refusability law (Q3.1);
   (b) the Fairness Law near-miss **cannot** be the recovery window as stated — ADR-040 already records
   that it fires on the shooter entering combat, not on the player being unaware, so it is not a window
   the player's cohesion state can open or close without changing that trigger;
   (c) the *shatter/restore* half needs **no new state at all** — `_nerve_drift` already falls 0.12 per
   nearby casualty and recovers only in a lull, and `squad_broken` already latches the collapse. The
   resource he describes is ~90 % built. **The idea survives; the mechanism he proposed for it mostly
   does not need building, and the order-gate half should not be built at all.**

---

## PART 4 — CHEAPEST AND MOST EXPENSIVE SHAPES

### CHEAPEST (reuses everything, adds no state; ~40 lines + ~30 HUD lines)
**Derive, don't store.** `SquadSystem._update_break()` already runs a 1 s pass over ≤8 members and
already computes live/peak and mean courage (`squad_system.gd:554-584`). In that same pass, publish one
derived scalar from numbers *already being computed*:

    cohesion01 = f( strength_ratio , mean effective_courage() , coordinator token + suppressor census )

No new scan, no new tick, no new authority, and `squad_broken` becomes its top rung rather than a rival.
Then one HUD line in the squad strip and a bark set. **Cost: one extra pass over ≤8 men per second.
Unmeasurable against a 1.20 ms think budget.**

**The one code hole worth filling alongside it (§1.8):** give the ally side the enemy's
`report_contact` / `shared_target` / `has_fresh_intel` — identical dict shape, three O(1) writes per
think, and `_call_contact` would finally do something besides play a sound. That is the cheapest thing
in this document that would actually change how a firefight *reads*.

### MOST EXPENSIVE
A true per-squad coherence solve: formation-graph maintenance under fire, per-man buddy spacing/LOS
checks each think (**O(n²)** — the `_grenadier_tick` trap), order propagation with per-man ack queues
and re-issue, plus a restore drill the player physically performs while men reposition. The logic is
survivable; **the extra body movement is not free**, and it buys from the ~94 % bucket. Expect real
frame time, a new probe, and a new bench row before it can be believed.

---

## PART 5 — THE GATE, RULED HONESTLY

**The demo playthrough gate (ADR-015 / GAME_GUIDE §8.0) is UNDISCHARGED. Exempt: bug fixes,
presentation for shipped systems, standing-decree items, evidence probes.**

| Work | Side of the gate | Why |
|---|---|---|
| Cohesion as a new resource that gates orders | **GATED — feature epic.** No argument. | New state, new player-facing rule, new verb pressure. |
| Ally squad intel sharing (§1.8) | **GATED.** I want to call it a parity bug; honesty says a man who never had a sense is not *broken*, he is *unbuilt*. | New AI capability, however cheap. |
| A cohesion/strength line in the squad strip | **EXEMPT — presentation for a shipped system.** | `squad_broken` and the break math shipped 2026-08-03 with a probe; the HUD already polls at 2 Hz (`mission_hud.gd:249-290`). |
| An ADR that writes down `SquadCoordinator` | **EXEMPT — documentation, not code.** | A shipped system with no ADR is the POINTER LAW's own disease. Highest-value zero-risk item in the session. |
| A probe measuring cohesion-shaped cost on the demo scene | **EXEMPT — evidence-gathering probe.** | Note the three ship-order perf poses (THE WALK · ONE DIG · THE BARRAGE) have still never been taken (`PERF_LEDGER.md:1115-1121`). |

**I found no bug in this space.** The nearest thing to a defect is the r4bk hole: the break state has a
toast that fades and a VO line, and after that the player has no way to know his squad is combat
ineffective. That is presentation for a shipped system, and it is exempt.

---

## PART 6 — ADR-023, THE FOSSIL LAW: what must DIE

If cohesion subsumes anything, the predecessor is deleted **in the same change**:

1. **If cohesion becomes the authority on collapse**, then `SquadSystem.squad_broken`,
   `AllyBase.squad_broken` and the ally call into `EnemySquad.break_state` must be **deleted**, and
   `squad_broken` re-expressed as a derived read (`cohesion01 < threshold`). Two break authorities is
   precisely the lie ADR-023 names — and `test_squad_break.gd` has a sub-test literally called
   `_test_one_break_authority`.
2. **`_nerve_drift` and cohesion may not both be pools.** Either cohesion is the squad-level *aggregate
   of* nerve (keep nerve, delete nothing), or it is a parallel pool (then `_nerve_drift`,
   `NERVE_LOSS_PER_CASUALTY`, `NERVE_RECOVER_PER_S`, `on_squadmate_down` and `effective_courage` die).
   **Naming which is a decree-level call and must not be left to the implementer.**
3. **Nothing may be added beside the coordinator's censuses.** `has_covering_fire`, the exposure token
   pool and the suppressor slot **are** the mechanical cohesion. A second number that also decides who
   leaves cover would be the third census in this codebase — the first two were merged for exactly this
   reason (`enemy_squad.gd:13-14`, `ally_base.gd:186-189`).
4. Any new squad-scoped static registry **registers in `MissionScope.reset()`**
   (`mission_scope.gd:25`) in the same change, or it is born a leak.

---

## SUMMARY (the programmer's seat)

Cohesion is **~80 % built and 0 % named**. The tactical half shipped 2026-08-24 without an ADR; the
morale half ships as `_nerve_drift` and the break threshold. The one real code hole is that our own men
share no information with each other while the enemy shares everything. The perf objection in the brief
is stale — think is 1.20 ms of a 37.5 ms AI wall, and since 2026-08-14 the wall is the GPU anyway — so
frame time is **not** the reason to refuse this. The reasons to refuse the *gating* half are Pillar 3,
ADR-021, the siege regression already recorded in `combat_goals.gd:16-19`, and the gate.

---

# PHASE 3 — RESPONSE TO THE REFRAME

**His words:** *"i just want realistic feeling and looking combat coming from both the allied npcs and
the enemy npcs. right now its like 60 percent there, but not as smooth looking as a call of duty 1 or
brothers in arms."*

## A. THE WIRING AUDIT (code side only — the clip/blend-time audit is the technical artist's)

### A.1 The verdict up front: animation is NOT the same shape as cohesion
Cohesion was *built and unnamed*. **Animation is built, named, documented, and hysteresis-damped.**
There is **no AnimationTree and no AnimationNodeStateMachine anywhere in the character path** — grep for
`AnimationTree` returns zero hits on characters (only prop/vehicle `AnimationPlayer` lookups). But that
absence is not the defect the brief expected: what exists instead is a deliberate one-player funnel with
most of what a state machine would have given us.

**The pipeline, exactly as built:**

| Stage | Where | What it does |
|---|---|---|
| AI state + flags | `ally_base._update_sprite():687`, `enemy_base._update_sprite():596` | called every frame from `_execute`, **not** from `_think` — the comment at `enemy_base.gd:592-594` says why: think is LOD-throttled to 0.6 s past 150 m and "animation would run at 1.6 fps" |
| Intent funnel | `sprite_state_map.intent_for():37` | one string from state + crippled/surrender/firing/speed/lateral/sneak/low-posture/prone/turn-rate/forward |
| Octant refine | `_with_octant():90`, `OCTANT_CLIPS` | full 8-way locomotion for run/sprint/walk/crouch — **the crabbing bug is already fixed** |
| **Stability filter** | `ally_base.gd:757-766`, `enemy_base.gd:670-679` | **an intent must win continuously for 180 ms before the clip commits.** `fire` and `death*` bypass |
| Clip map | `MODEL_CLIP` + `MODEL_ALIASES` + `WEAPON_FAMILY` | intent to clip, with generation aliases and a `__family` weapon-hold suffix that degrades to the rifle hold |
| Playback | `model_actor.play():1004` | `_anim.play(clip, **0.18**)` — a 0.18 s crossfade, **plus cycle-phase preservation** across loop-to-loop switches so feet do not teleport to frame 0 |
| Rate match | `set_locomotion_speed():1079` | playback rate = ground speed / authored clip speed, clamped 0.6–1.4, from a real `_CLIP_SPEED` table |
| Facing | `model_actor.set_facing():966` | `lerp_angle(yaw, target, 1 - exp(-12*dt))` — **frame-rate-independent damped turn at the ONE yaw owner.** Not snapped. |

### A.2 Does the 6–7 Hz think tick twitch the body? **No. It is damped five times over.**
This was the brief's leading hypothesis and the code refutes it:
1. `goal_timer < 1.0` early-out — a goal holds ~1 s minimum (`enemy_base.gd:1500`, `ally_base.gd:1090`).
2. Incumbent hysteresis x1.5 enemy / **x1.6 ally** (`ALLY_INCUMBENT_MULT`, `ally_base.gd:391`).
3. Challenger gate: must beat the multiplied incumbent by 1.15 **and hold it 2 consecutive thinks**
   (`combat_goals.gd:29-31, 178-206`).
4. `ALLY_GOAL_COOLDOWN_MS = 3000` on the ally side (`ally_base.gd:390`).
5. The 180 ms intent stability filter, which is **longer than `THINK_INTERVAL` (150 ms)** — so an intent
   that flips every think can never commit the clip.

**A goal change does not hard-cut a clip.** The pattern the brief hoped was missing is in the house
three times over. This hypothesis is REFUTED.

### A.3 Rotation, path following, avoidance — all already smoothed
- **Yaw:** damped, `1 - exp(-12*dt)` (~12 rad/s time constant), at the single owner, in GLOBAL space so
  the parent body's own `look_at` cannot compound it (`model_actor.gd:964-980`).
- **Turn-in-place IS wired:** `_update_turn_rate` on both sides (`enemy_base.gd:573`, `ally_base.gd:642`),
  `TURN_RATE_MIN` 0.8 rad/s (~46 deg/s), intents `turn_l`/`turn_r` to `turn_left`/`turn_right`.
- **Velocity:** `lerpf(velocity, target, delta * 8.0)` (`ally_base._move_toward():2029-2030`) — ~0.125 s
  acceleration ramp, so no instant starts.
- **Avoidance jitter: cannot occur.** `nav.avoidance_enabled = false`, explicitly, with the comment
  *"RVO is a second silent no-op"* (`ally_base.gd:2410`). Separation is the spacing push instead.
- **Nav tolerances:** `path_desired_distance = 0.7`, `target_desired_distance = 1.0`
  (`ally_base.gd:2407-2408`); `NavRouter` re-stakes the agent target only when it moves **> 3 m**
  (`distance_squared_to > 9.0`, `nav_router.gd:115-118`) because each restake is a `map_get_path()`.
  **This is the one honest stutter suspect I found**: following a moving player, the path goes stale up
  to 3 m before it re-stakes, and the corrective step lands as a direction change. It is a candidate,
  not a proven defect — I have not measured it.

### A.4 What IS missing — and it is a PARITY hole, not an architecture hole
The enemy has three body one-shots the **ally does not have at all**:

| Beat | Enemy | Ally |
|---|---|---|
| **Arrival plant** (`run_to_stop`) — run/sprint to idle/aim/cover plays a 450 ms plant | `_arrive_until_ms`, `enemy_base.gd:266, 682-690` | **ABSENT.** grep: no `_arrive_until_ms` in `ally_base.gd` |
| **Stumble on a solid non-lethal hit** (`stumble_hit`, 500 ms) | `_stumble_until_ms`, `enemy_base.gd:189, 622-625, 2664` | **ABSENT** |
| **Grenade windup** (`grenade_throw`, 1000 ms) | `_throw_until_ms`, `enemy_base.gd:188, 627-630, 2518` | **ABSENT** (the ally grenadier fires the M79 from `squad_system._grenadier_tick` with no body clip) |
| Spine flinch modifier | `enemy_base.gd:2653-2654` | **ABSENT** — `grep flinch` finds no ally caller |

**The clips already exist and are already mapped** (`MODEL_CLIP` has `"arrive": "run_to_stop"`;
`stumble_hit` and `grenade_throw` are played by name on the enemy side). **The player watches his own
squad more than anyone else in the game, and his own squad is the half missing the performance beats.**
That is very likely a large share of his "60 percent there".

### A.5 Anything built and bypassed?
- **No.** I found no AnimationTree lying unused, no blend time set to 0, no unreachable state.
- The nearest thing: `_report_missing_family()` (`model_actor.gd:993-1000`) records that
  **`mg`, `bolt`, `launcher` and `pistol` have NO weapon-family clips in the shipped library** — the RPD
  gunner and the RPG man hold their weapons like rifles. That is an ART gap, legibly logged, and it is
  the technical artist's column, not mine.
- **There is no animation LOD of any kind.** No `callback_mode`, no `AnimationMixer.active` toggling, no
  `VisibleOnScreenNotifier`, no distance gate on the AnimationPlayer. Every man animates at full rate at
  every distance. `_update_sprite` (the *decision*) is gated by `_body_hot`, but the player itself keeps
  evaluating.

## B. THE PERF PRICE — and a correction to my own Phase 2 evidence

### B.1 The bucket table NEVER MEASURED ANIMATION. I have to say this plainly.
`ai_usec_anim` is a **misnomer**. Its accumulation is
`CombatManager.ai_usec_anim += (t_move - t_sync) - usec_think` (`enemy_base.gd:864`): the wall-clock span
from *after hitzone sync* to *before `move_and_slide`*, minus think. That span is
`_update_decay` + `_update_think_lod` + **`_execute`** — i.e. the AI's own executor code, including the
`_update_sprite` *decision*. **Godot's animation track evaluation, skeleton pose update and skinning run
in the engine's own step and are inside NONE of the four buckets.**

So the 17.63 ms row is **EXECUTE**, not animation. **Nobody in this project has ever measured what
character animation costs.** I cannot say "blend trees are cheap" from that table and neither can anyone
else — and I will not let my own Phase 2 number be used to say it.

### B.2 What I can say honestly
- **Blending itself is cheap.** A crossfade is a second track sample and a lerp. Adding per-transition
  blend times to the existing `_anim.play(clip, t)` call costs nothing measurable.
- **More BONES and more ANIMATED ACTORS are not cheap**, and 45 men at the climax is already the load.
  Skinning is also a **GPU** cost, and since 2026-08-14 the GPU is the wall on the floor box
  (`PERF_LEDGER.md:1141-1145`: 43.5 ms GPU at a *quiet* arena, 94.4 ms at EVERYTHING).
- **Additive aim layers and hit-reaction layers add per-frame bone work per man**, and there is no LOD to
  shed it. On a 45-man climax that is the shape that bites.
- **Animation LOD does not exist and is the known cheap win.** Distance/visibility-gated animation rate
  (or `AnimationMixer.active = false` beyond the sight cap) is the standard lever, it is code-only, and
  the sight cap already gives us the honest distance at which a man cannot be resolved.

### B.3 The acceptance probe — the Devil's Advocate is HALF right
He is right that **"smooth" is not an acceptance criterion.** He is wrong that therefore nothing can
close. Two probes, both objective, both cheap:

1. **`tests/probe_anim_churn.tscn` — the clip-change counter.** Instrument `ModelActor.play()` with a
   per-actor committed-change counter and a dwell histogram; run the 18v18 arena 60 s headless.
   **Acceptance: ZERO committed clip dwells below the 180 ms stability floor** (any is a bypass leak — a
   direct `play()` that skipped the filter, which is exactly the fossil class we would create by adding
   more one-shots), **and a median locomotion dwell above ~0.6 s.** This falls out of code we already
   have and it catches the regression class this work most plausibly introduces.
2. **The perf half — an A/B that brackets what the buckets miss.** Same arena, 45 men, with vs without
   `AnimationPlayer` evaluation (`active = false`), windowed on the floor box, recording frame ms and
   render-CPU/GPU split via `viewport_set_measure_render_time` (already wired,
   `perf_probe.gd:47-53,300`). That produces **the first honest number for what animation costs in this
   project**, and any LOD or layering work is then measured against it.

**And the concession he is owed:** neither probe proves it *looks* better. Nothing can. The honest
closing rule is the two-key rule the gate already uses — **probe proves no regression, the Summoner's
eyes prove the feel** (ADR-015: never closed by a probe alone, never by an agent's reading).

## C. THE GATE — the line, drawn precisely

**The line: if it changes what the AI can DECIDE, or adds a second authority over the skeleton, it is
GATED. If it only changes how a decision already made is DISPLAYED, it is EXEMPT.**

| Work | Side |
|---|---|
| Ally arrival plant / stumble / throw one-shots + spine flinch (A.4) | **EXEMPT** — presentation parity for shipped behaviour; clips exist, the enemy path exists, no decision changes |
| Per-transition blend times replacing the single 0.18 s constant | **EXEMPT** — tuning a shipped display constant |
| `probe_anim_churn` + the animation A/B bench | **EXEMPT** — evidence-gathering probes |
| Animation LOD (distance/visibility gate on playback rate) | **EXEMPT — but only just.** It is a perf fix on a shipped system and it changes no decision. It must ship with the B.3 bench or it is unprovable |
| **AnimationTree / state machine rewrite** | **GATED** — a second authority over the skeleton (ADR-023) and a new system |
| **Additive aim layers, IK, new hit-reaction layers, root motion** | **GATED** — new systems with unmeasured per-man cost and no LOD to shed it |
| New clips of any kind | **GATED**, and it is art-days, which section 8.1 budgets at 13–19 of ~26 |

**THE LEAK RISK, named the way ADR-040 named its own:** ADR-040 exists because a health-pool change
would *"arrive dressed as death feel."* **Here the leak runs the other way — an AnimationTree rewrite
will arrive dressed as a blend-time tweak.** The tell is concrete and checkable: *does the change add a
node that owns the skeleton?* Touching the `0.18` inside `ModelActor.play()` is a tweak. Instantiating an
`AnimationTree` is a rewrite, however small the first commit looks. Anyone proposing the second while
calling it the first should be refused on this line.

## D. FOSSIL LAW — what dies if an AnimationTree is ever introduced

An `AnimationTree` and direct `AnimationPlayer.play()` calls **cannot coexist**: both write the same
bones, and the loser is whichever ran last that frame. Every one of these dies in the same change or the
change is not shipped:

- `ModelActor.play()` / `play_first()` / `pose_end_of()` / `play_any_death()` / `stop_anim()` /
  `set_locomotion_speed()` (`model_actor.gd:704, 711, 719, 938, 1004, 1079`) — the whole public clip API.
- Every AI call site: `ally_base.gd:509, 699, 700, 712, 745, 747, 767, 2361` and
  `enemy_base.gd:471, 617-618, 624, 629, 632, 637, 663, 666, 691, 2752, 2972, 3058, 3117`.
- The one-shot window latches that exist *only* to override the funnel: `_cover_exit_until_ms`,
  `_stumble_until_ms`, `_throw_until_ms`, `_prone_drop_until_ms`, `_prone_rise_until_ms`,
  `_arrive_until_ms`, `_anim_override`, `work_clip` — a state machine expresses these as states, and
  leaving both is the exact "two things that read as the same thing" the Summoner's law names.
- The external clip contracts: `burning.gd`'s `clip()`/`clip_alt()`, `gun_crew_performance.gd`,
  `civilian._play_garrison`, `enemy_base._play_camp_role`, the zombie path.
- And `_LOOP_PREFIXES` / `_LOOP_NAMES` / `_apply_loop_modes()` (`model_actor.gd:334-392`) exist only
  because glTF carries no loop flag and a raw AnimationPlayer needs it stamped. A tree would still need
  it — but if it does not, it must go.

**That is ~30 call sites across 8 files. Price the deletion into the estimate, or do not start.**

## E. WHICH PHASE 2 POSITIONS I CHANGE

- **CHANGED — my own perf evidence, narrowed.** In Phase 2 I said think is 1.20 ms of a 37.5 ms wall and
  used it to say cohesion logic is cheap. **That still stands for cohesion.** It does **not** transfer to
  animation, because `ai_usec_anim` is the execute span and the engine's animation and skinning work is
  in none of the four buckets. I withdraw any implication that the existing table prices animation. It
  does not. **Animation cost in this project is UNMEASURED.**
- **CHANGED — the "half-built and bypassed" hypothesis, refuted.** I expected animation to have
  cohesion's shape. It does not. The funnel is complete, documented, hysteresis-damped and honest. The
  gap is **ally/enemy parity** (A.4) and **per-transition blend tuning**, not architecture.
- **HELD.** The GPU is the wall on the floor box; the body is the expensive CPU bucket; ADR-025's tier
  scheduler stays condemned; the fossil law binds any new authority.
- **HELD.** My gate rulings from Phase 2 are unchanged. The new work sorts on the same line: display of a
  decision already made = exempt; a new decision or a new authority = gated.
