# SYSTEMS CARTOGRAPHER — Combat AI As-Built Map + Bounce Diagnosis
Council of 2026-08-24 (AI doctrine). READ-ONLY survey; every claim carries a file:line.
All line numbers verified against the working tree on 2026-08-24.

---

## 1. THE BRAINS — as-built map

### 1.1 Inventory

| system | file | thinks at | goals/verbs | shared with | diverged from |
|---|---|---|---|---|---|
| **Enemy man** (NVA/VC) | `scripts/enemies/enemy_base.gd` (3065 ln) | 6.7 Hz (`THINK_INTERVAL 0.15` :31), LOD 0.3s @>80m, 0.6s @>150m (:37-52) | 9-verb scored FSM: ENGAGE, SEEK_COVER, SUPPRESS, FLANK, ADVANCE, RETREAT, INVESTIGATE, HOLD (+assault override) | CombatGoals, CombatPosture, AIMarksmanship, NavRouter, cover claim broker, HitzoneBuilder | alert tiers, hunt, tunnel/spider/medic/camp roles, hot-set tiering — all enemy-only |
| **Squad-mate / any US soldier** | `scripts/allies/ally_base.gd` (2174 ln) | 6.7 Hz fixed — **no LOD** (:21, :753-755) | same scorer, but ally shell adds commitment layer + orders (FOLLOW/HOLD/MOVE_TO/RESCUE :265), cord, defense zone | same five shared modules | own targeting, own covering-fire census, own dwell/cooldown constants, no INVESTIGATE/hunt, no alert tiers |
| **Enemy squad layer** | `scripts/enemies/enemy_squad.gd` | static registry, polled at think rate | shared target/intel, breadcrumb trail, sectored hunt, covering-fire census (:186-191), engagement census (:206-219), grenade broker, break state (:119-123), hot-set cap 50 (:42) | break math reused by allies (squad_system.gd:462) | everything else enemy-only |
| **Ally squad layer** | `scripts/squad/squad_system.gd` | 1 s break cadence (:452) | orders, roster, formation slots, break flag pushed onto men (:466-468) | `EnemySquad.break_state` — the ONE break authority (:441-444) | no shared-target/intel, no hunt, no fire census (that lives as statics in AllyBase :188-190) |
| **Garrison defender** | `scripts/allies/garrison_defender.gd` + `scripts/missions/field_director.gd:1612-1637` | n/a — **promotes Civilian → AllyBase 1:1** (garrison_defender.gd:26-107) | HOLD + `defense_zone` r=8 (:73-75) | reuses AllyBase whole — explicitly "NO third combat brain" (:6) | none. This is the healthy pattern. |
| **Siege press** | `scripts/missions/siege_director.gd:576-614` | PRESS_CYCLE rotation | rotates `siege_press` **by squad** — one squad rushes while the rest shoot (:584-598) | feeds `CombatGoals.Context.assault_press` only (enemy_base.gd:1518) | **the only base-of-fire + maneuver in the game, enemy-only, siege-only** |
| **Camp director** | `scripts/enemies/camp_director.gd` | hourly role rotation | writes `camp_role`/`work_pos` only — no combat authority | — | — |
| **Civilian BT** | `scripts/ai/bt/` (BTNode/Selector/Action) | civilian.gd only | non-combat | — | a second AI *architecture* (behaviour tree) living beside the FSMs, civilians only |
| **Zombie** | `scripts/zombies/zombie_base.gd` | 4 Hz (:25) | side-mode chase brain | — | fully separate, out of Vietnam scope |

**Verdict on count: TWO combat brains (EnemyBase, AllyBase) over ONE shared decision core.**
The 2026-07-23/24 posture merge centralised the *what* (CombatGoals scores, CombatPosture
posture, AIMarksmanship cone, NavRouter legs, one cover-claim broker
`EnemyBase._cover_claims` used by both — ally side at ally_base.gd:1723-1725). What never
merged is the *shell*: perception, targeting, commitment, squad intel, and the goal→state
executors are two parallel implementations.

### 1.2 Where friendly and enemy AI duplicate the same job with different code
(the named project disease — each row is a divergence, not a design decree, unless marked)

1. **Target acquisition.** Enemy: scored (`_target_score` enemy_base.gd:1318-1327 —
   proximity, attacker ×2.5, incumbent ×1.3 stickiness, ghost decay, crowding penalty via
   engagement census), re-scored every `RETARGET_INTERVAL 2.0s` (:1305), 8 s memory.
   Ally: **pure nearest-enemy, re-picked every 0.15 s think, zero stickiness, zero
   crowding** (`_find_target` ally_base.gd:880-917).
2. **Covering-fire census.** Enemy: per-squad dict, 1500 ms window
   (enemy_squad.gd:14,176-191). Ally: **one static global pair for every US man on the
   map**, 1200 ms (ally_base.gd:188-190, read :1061-1063) — an ambient patrol firing 400 m
   away counts as "my squad is covering me".
3. **Goal commitment.** Ally: `ALLY_COVER_DWELL_MS 8000`, `ALLY_GOAL_COOLDOWN_MS 3000`,
   incumbent ×1.6 (ally_base.gd:347-349) — added 8/4 and **explicitly withheld from the
   enemy**: "Ally-only hysteresis; enemy scoring is untouched (divergent-systems law)"
   (:343-346). Enemy: 1.0 s dwell (enemy_base.gd:1453), incumbent ×1.5
   (combat_goals.gd:51), **no switch cooldown, no cover dwell at all**.
4. **Local force ratio.** Two mirrored hand-copies: enemy_base.gd:1532-1548 (tree-group
   scan) vs ally_base.gd:1102-1120 (AgentRegistry scan).
5. **Suppression memory.** Ally carries `incoming_pressure` (decay 0.06/s,
   ally_base.gd:340-341) precisely because "suppression_level is an INSTANT: it decays in
   ~3.3s ... a man forgets he is in a firefight" (:337-339) — but then feeds the scorer
   the raw instant anyway (`c.suppression = suppression_level` :1041). Enemy has **no
   pressure memory at all** (enemy_base.gd:1502).
6. **SUPPRESSED executor.** Enemy: pure freeze, never fires (:1819-1825). Ally: slow
   aimed return fire (:1542-1553). (This one is decreed.)
7. **Think LOD.** Enemy scales 0.15→0.6 s by player distance (:37-52); ally always 0.15 s
   (ally_base.gd:753) — perf and behaviour divergence.
8. Duplicated verbatim-ish code pairs: `_update_unstick`, `_rescue_snap`,
   `_refresh_separation`, `_tempo`, `_shot_pressure_mult`, prone latch, turn-rate,
   muzzle/fire path — maintained twice.
9. **Alert/perception.** Enemy: 4-tier alert, awareness accumulator, FOV cones, noise,
   witness rule (:96-110, 1143-1238). Ally: none — instant omnidirectional acquisition
   inside the sight cap (:880-917). Partly a design asymmetry, but it means "US caution"
   cannot exist: an ally is never surprised, never scanning, never suspicious.

### 1.3 Inter-agent coordination — does any pair of men ever coordinate?
- **Shared knowledge, yes:** enemy squads designate targets, share last-known, lay/read
  breadcrumbs, and run the sectored expanding hunt (enemy_squad.gd:244-453). That is
  intel-sharing, not manoeuvre coordination.
- **Fire-and-move, almost none.** `has_covering_fire` is a passive census — "did anyone
  else fire in the last 1.2–1.5 s" — feeding a +0.2 ADVANCE bonus (combat_goals.gd:127).
  **No man is ever ASSIGNED to suppress while a named other man moves.** The bounding
  advance is individual (`_find_bound_point` enemy_base.gd:2097-2121, executed
  :1894-1966); two bounders never alternate deliberately. All visible "teamwork" is
  emergent from the census + the shared cover broker + the grenade broker.
- **The one real exception:** the siege press rotates by squad — a designated support
  squad never rushes, one squad crosses while the others shoot
  (siege_director.gd:584-598). Squad-level base-of-fire + maneuver EXISTS in the codebase,
  but only there, only enemy, only under siege.

### 1.4 Suppressing fire (the verb) vs suppression (the state) — MEASURED ABSENT
`SUPPRESS_TARGET` is scored (combat_goals.gd:101-108) but **has no executor on either
side**. Enemy maps it to the COMBAT state (enemy_base.gd:1582-1583); ally's
`_apply_combat_goal` drops it through the default arm to COMBAT too (ally_base.gd:1155-
1156). `_execute_combat` on both sides fires **only when `has_line_of_sight` is true, at
the target's body** (enemy_base.gd:1754,1795-1801; ally_base.gd:1393,1479-1481). There is
no code path that puts sustained fire on a known POSITION (a treeline, a window, last-
known cover) without LOS. The ally comment "SUPPRESS rides the COMBAT state: the
difference is WHERE the rounds go (see _execute_combat)" (ally_base.gd:1140-1141) is
**drift — _execute_combat never reads current_goal**. So the game has suppression as a
*received* state (near-miss cracks: `NEAR_MISS_RADIUS 2.2`, `SUPPRESS_ON_MISS 0.34`,
combat_manager.gd:372-387, fanned by `suppress_along_shot` from player :539(weapon_holder),
ally :1938, enemy :2365) but **no deliberate suppressING fire anywhere**. When a man's goal
is SUPPRESS and his target ducks, he stops shooting and walks toward last-known
(enemy_base.gd:1803-1816) — the exact opposite of the verb.

---

## 2. THE BOUNCE — numerically

### 2.1 Every path that flips a goal or pulls a man off cover

**A. Scorer re-plans (gated).**
- Enemy: dwell gate 1.0 s (enemy_base.gd:1453), incumbent ×1.5 (combat_goals.gd:51,166).
  Minimum flip period 1.0 s; challenger needs +50%.
- Ally: dwell 1.0 s (:993), plus cooldown 3000 ms on non-survival switches (:1079-1082),
  incumbent ×1.6 (:1053), cover commitment 8000 ms (:1013-1024).

**B. Class-A interrupts (ungated — these are the bounce engine).**
- `take_damage` sets `goal_timer = 99.0` on BOTH sides (enemy_base.gd:2494,
  ally_base.gd:1984). **Every hit re-opens the scorer at the next think, ≤150 ms later.
  No interrupt cooldown exists.** Under sustained fire a man re-plans at wound cadence,
  and each re-plan can hand him a cover-releasing verb.
- Watching a squadmate die within 10 m: `w.goal_timer = 99.0` (enemy_base.gd:1090) —
  every nearby casualty forces a full re-plan on every COMBAT witness.
- Ally pin-lift: `goal_timer = 99.0` the think the pin decays (:988-989) — every
  suppression cycle ends in a forced re-plan.

**C. Cover-release side doors (bypass ALL hysteresis — the dwell only defends against
the scorer, never against these).**
- Enemy `_set_goal`: any transition to FLANK / ADVANCE / RETREAT / INVESTIGATE / HOLD
  releases the claim (:1554-1558).
- Enemy target-null path: target dies/expires → early-return to INVESTIGATE or HOLD
  (:1464-1485) → next `_set_goal` releases cover + plays `cover_to_stand`. **Killing one
  of a squad's targets makes his engagers stand up out of cover mid-firefight to hunt.**
  Re-acquisition then runs on the 2.0 s `RETARGET_INTERVAL` / 8 s `TARGET_MEMORY` clocks
  (:1305-1306).
- Enemy drift release: >2.5 m from the claimed point while in COMBAT → release (:1772).
  Strafe shuffle (:1777-1783) + separation push (:1785) + back-up band (:1757-1759) can
  walk him over that line.
- Ally `_change_state`: leaving {COMBAT, SEEKING_COVER, SUPPRESSED} for IDLE **or
  ADVANCING** releases (:1845-1853 — ADVANCING is deliberately not "still_fighting").
- Ally blind timer: in COMBAT with no LOS for ~1.5-3 s → IDLE (:1500-1502) → release.
  (Note `state_timer` is incremented twice per frame on the blind branch — :1206 and
  :1500 — so the advertised 3 s is really ~1.5 s.) In jungle, LOS blinks constantly.
- Ally dwell is an 8 s ABSOLUTE CEILING, not a renewable hold: `_cover_hold_start_ms` is
  written once at arrival (:1580), read at :1020, **never refreshed** — grep confirms
  exactly 3 references. After 8 s on one rock the commitment arm never re-engages until
  he leaves and re-arrives. So the 8/4 fix guarantees the FIRST 8 seconds and then
  returns the man to the churn for the rest of the fight.
- Cord/zone pulls drop cover instantly (RTO :1427-1431, defense zone :1436-1441) — by
  decree.

**D. Ungated cheap-combat flips.** Fighters outside the 50-man hot set run `_cheap_goal`:
ENGAGE ↔ HOLD flipped **instantly, zero hysteresis**, whenever the squad's shared target
reference blinks (enemy_base.gd:951-955). In a 45-man siege that is most of the force.

**E. Ally target thrash.** Because targeting is nearest-wins every 0.15 s
(ally_base.gd:880-917), two enemies alternating in range flip an ally's target at up to
6.7 Hz. Each flip resets `_aim_settle` (0.3-0.95 s, :912-915), fires a contact bark
(:916), swings `current_aim_dir`, and re-aims the movement bands — reads as a man
spinning between threats.

### 2.2 Worst-case flip arithmetic (from the shipped constants)
- Think 6.7 Hz; dwell 1.0 s ⇒ nominal flip floor 1000 ms. With a hit landing (interrupt
  B) the floor is **one think = 150 ms**. A man taking a round a second re-plans every
  ~150-1000 ms all fight; the ally 3000 ms cooldown exempts SEEK_COVER and RETREAT
  (:1080), which are precisely the visible dart-away verbs.
- **Suppression flicker drives score churn between bursts.** Decay is
  0.3/s × recovery mult — ×3.0 behind cover, ×0.7 open (enemy_base.gd:278,848-851;
  combat_posture.gd:25-26). A covered man sheds 0.9/s; one crack gives him only
  0.34 × 0.35 = 0.12 (combat_manager.gd:373 × combat_posture.gd:24). Enemy fire pauses
  0.4-1.2 s between bursts (enemy_base.gd:1801). So `suppression` crosses the 0.25
  `under_unanswered_fire` gate (combat_goals.gd:74) roughly **once per burst cycle
  (~1-2 Hz)**, toggling ADVANCE ×0.15 ↔ ×1.0 (:131) and FLANK ×0.4 ↔ ×1.0 (:116) — up to
  a 6.7× score swing on consecutive thinks. The FEAR doctrine is wired to a signal that
  evaporates faster than the fire that causes it; the ally memory built to fix exactly
  this (`incoming_pressure`, :337-341) is not fed to the scorer (:1041).
- Full enemy mill cycle in a multi-contact fight: seek cover (search 1 Hz, rush ≤4 s cap
  :1458) → engage → target dies or 8 s memory expires → INVESTIGATE (cover released,
  stand-up one-shot) → hunt → re-acquire ≤2 s → threat high (no cover +0.2, :1433-1434)
  → seek cover again. **~10-15 s per lap of visible milling, per man, indefinitely.**

### 2.3 Top 3 mechanical causes of visible bouncing
1. **Ungated Class-A interrupts.** `goal_timer = 99.0` on every hit, every witnessed
   casualty, every pin-lift (enemy_base.gd:2494,1090; ally_base.gd:1984,988) with no
   interrupt debounce — in a firefight the dwell/cooldown machinery from 8/4 is almost
   never actually in force. The commitment law exists; the interrupts hold it open.
2. **Cover release wired to routine transitions, and the ally dwell is a one-shot 8 s
   ceiling.** Target death → INVESTIGATE/HOLD strips cover (enemy_base.gd:1464-1485 +
   1554-1558); ally LOS-blink → IDLE (~1.5-3 s, :1500-1502) and any ADVANCE/FLANK pick
   (:1845-1853) strips cover; `_cover_hold_start_ms` never refreshes (:1580). There is no
   "stay on the rock until the FIGHT ends" anywhere — cover is leased per-goal, and goals
   are short-lived (see 1 and 3).
3. **Decision inputs flicker at burst cadence.** Suppression instant crossing 0.25/0.6/
   0.7 gates between bursts (math above) flips the FEAR multipliers and the pin path;
   ally nearest-only retargeting flips targets at up to think rate (ally_base.gd:880-917);
   cheap-tier men flip ENGAGE↔HOLD ungated (enemy_base.gd:951-955). The scorer is fine;
   it is being fed square waves.

(Honourable mention: `SUPPRESS_TARGET` having no executor means the one verb that would
make a man USEFULLY stand still — pouring fire on a position — instead makes him advance
on lost LOS, enemy_base.gd:1803-1816.)

---

## 3. FACTION ASYMMETRY — where US vs NVA/VC actually differ today

**Data-driven (healthy, keep):** `EnemyData` (scripts/enemies/enemy_data.gd) carries
aggression, courage, determination, accuracy_modifier, exposure_ramp_time,
preferred_range, uses_cover, flanks, retreats_when_hurt, stealth, silent_infiltrator,
combat_medic. Measured spread in `data/enemies/`: NVA regular det 0.9 / acc 0.95 /
courage 0.65 / flanks true / never retreats; VC rifleman det 0.45 / acc 1.15 / courage
0.45 / no flank / retreats at 25%; vc_farmer det 0.25; nva_sapper courage 0.85 +
silent + stealth. Determination already drives the hunt length/width
(enemy_squad.gd:396-453). **The NVA/VC asymmetry is already parametric.**

**Hardcoded forks (the gap):** the US "faction" has no data block at all. Ally
temperament is `courage = randf()` (ally_base.gd:442) reshaped by MOS in SquadSystem;
US doctrine is compile-time constants scattered through AllyBase (dwell 8000, cooldown
3000, incumbent 1.6, ANCHOR_SUPPRESS 0.25, cover-first window 5-11 s :198-207, formation
constants :246-260). Enemy-only features hardcoded in EnemyBase: alert tiers, hunt,
personalities enum (:382-403), camp life, tunnel/spider-hole, medic drag. Ally-only:
orders, cord, defense zones, MG-post seeking (:825-855).

**Could one shared brain + a doctrine parameter block express both? Yes — the decision
core already IS shared.** The missing piece is a `DoctrineData` block (per faction, or
per archetype extending EnemyData) holding the values that are currently either
ally-only constants or absent:
`cover_dwell_ms` · `goal_cooldown_ms` · `incumbent_mult` (Context field exists,
combat_goals.gd:51) · `interrupt_debounce_ms` (new — cause #1) ·
`pressure_decay` + `scorer_reads_pressure` (new — cause #3) · `retarget_interval` +
`target_stickiness` (enemy has them :1305,1323; ally needs them) ·
`covering_fire_window_ms` + per-squad census scope · `suppress_verb_profile` (freeze vs
return-fire vs fire-at-position — needs the missing SUPPRESS executor first) ·
`bound_length_m` / `press_participation` (siege_director already rotates by squad) ·
`hunt_determination` (exists) · `formation` (file constants). US = long dwell, tight
census, methodical bounds, real suppressing fire; NVA = press + hunt + flanks; VC =
short determination, ambush-and-fade retreat bias. Everything on that list except the
two "new" items already exists on exactly one side of the fence — the work is moving
values across it, not inventing behaviour.

---

## Sacrifices to name (Law 2)
Unifying the shells risks the 2026-07-29 class of regression ("nobody fought") — the
enemy shell carries siege/sapper/hunt invariants the ally shell must never inherit
blindly, and vice versa (cord, zones). A doctrine block adds one more data surface to
drift-audit. Feeding the scorer a pressure memory instead of the instant will make ALL
AI more cautious — the siege press exemption (combat_goals.gd:116,131) must be re-proven
against test_ai_fairness.gd:103 and the assault decree before shipping.
