# AI ARCHITECT — Squad Anchoring Analysis

**Ruling under examination (Summoner, 2026-08-12):** *"im also seeing my ai squadmates move around too
much in firefights. they shoud be anchoring more and just trying to shoot and cover instead of advancing
or moving around as much as they are"*

**Scope:** the player's own squad — `AllyBase` (`scripts/allies/ally_base.gd`, 1858 lines). Analysis only,
no code edited. Every claim below carries a `file:line` (POINTER LAW).

**Verified as of 2026-08-12** against working-tree source.

---

## 0. Executive summary

Allies do not "mill about" because of goal flutter. The commitment machinery the 2026-08-04 verdict added
(`ALLY_COVER_DWELL_MS` 8000, `ALLY_GOAL_COOLDOWN_MS` 3000, `ALLY_INCUMBENT_MULT` 1.6 —
`ally_base.gd:264-266`) is real, wired, and working. **The movement he is seeing happens entirely INSIDE a
single stable goal.** `_execute_combat` writes a movement vector every frame from a range band and a random
strafe, and neither is gated by any dwell, cooldown, or incumbent multiplier. A man can hold
`ENGAGE_TARGET` for the whole fight and still walk 8 metres a leg, forever.

Three constants do most of the damage, and one of them is a single number:

| Rank | Cause | Pointer | Measured |
|---|---|---|---|
| 1 | `preferred_range = 12.0` on every ally, vs 22–32 m on the NVA they fight | `ally_base.gd:10` | permanent forward pull; an ally is "too far" at 11 m and pushes |
| 2 | Random strafe at full combat speed whenever uncovered | `ally_base.gd:1200-1226`, `:1274` | 2.69 m/s, 67 % duty, 1.5–3.0 s legs → 4–8 m of lateral drift per leg |
| 3 | Cover-first is a one-shot 5–6 s window that never re-arms | `ally_base.gd:136-139`, `:799-804`, `combat_goals.gd:85,95` | after 6 s of contact an uncovered ally is **doctrinally forbidden** from seeking cover |
| 4 | Lost-LOS branch abandons cover and jogs at FULL speed | `ally_base.gd:1292-1299` | 5.6 m/s toward the enemy, `has_cover` not consulted |
| 5 | The "under effective fire → go firm" gate exists but can almost never fire | `ally_base.gd:833-837`, `:811-816` vs `enemy_base.gd:2963` | needs ≥2 near-misses inside ~1 s; suppression rarely clears 0.4 |

---

## 1. Every code path that can move an ally in a firefight

`_physics_process` (`:616`) → `_think()` every `THINK_INTERVAL 0.15` s (`:21`, `:648-655`) →
`_execute(capped_delta)` **every frame** (`:657`). Think decides WHAT; execute writes velocity.

`_execute` dispatch: `:1030-1048`.

| # | Path | Entry | Trigger | Re-eval | Hysteresis / dwell |
|---|---|---|---|---|---|
| 1 | **Range-band creep** (advance / back off) | `:1215-1222` | `COMBAT` + raw LOS + `dist` outside `[pref*0.6, pref*0.9 or 1.2]` | **every frame** | **NONE** |
| 2 | **Random strafe** | `:1200-1203`, `:1224-1226` | `COMBAT` + raw LOS, unconditional | re-roll every 1.5–3.0 s | none beyond the re-roll timer |
| 3 | **Cover re-anchor** | `:1254-1259` | `has_cover` and drifted > 1.5 m off `current_cover` | every frame | 1.5 m deadband (this one is healthy) |
| 4 | **Lost-LOS hunt** | `:1292-1299` | `COMBAT` + `has_line_of_sight == false` | every frame | 3 s to bail to IDLE (`:1301-1303`) |
| 5 | **SEEKING_COVER rush** | `:1375-1395` | goal `SEEK_COVER` | rush completes; goal dwell capped 4 s (`:824`) | cover search throttled 1 Hz (`:1399-1400`) |
| 6 | **SEEKING_COVER duck-and-dodge** | `:1410-1418` | no cover point found this second | every frame | 2 s exit (`:1422`) |
| 7 | **ADVANCING** | `:1310-1337` | scorer picks `ADVANCE` | every frame | exit band 0.8 inside entry 0.9/1.2 (`:1322`) — correct, no flap |
| 8 | **FLANKING** | `:976-997` | scorer picks `FLANK_TARGET` | offset **re-derived every tick** (`:993`) | none; 14 m lateral goal (`:973`) |
| 9 | **RETREATING** | `:1002-1012` | scorer picks `RETREAT` | every frame | none |
| 10 | **Formation / leash** | `:1094-1132` | `IDLE` + `OrderMode.FOLLOW` | every frame | deadzone 2.5 m (halt) / 3.0 m (file); slot rate-limited 12 m/s (`:1125`) |
| 11 | **Radio leash / net-plant** | `:1071-1093` | `net_planted` / `radio_leash` | every frame | 8.0 m / 1.2 m |
| 12 | **RTO cord pull** | `:1230-1236` | MOS == RTO and > 8 m from player | every frame | outranks everything; **releases cover** (`:1235`) |
| 13 | **Defense-zone pull** | `:1240-1246` | outside `defense_zone_radius` | every frame | releases cover (`:1245`) |
| 14 | **RESCUE** | `:1151-1157` | `OrderMode.RESCUE` | every frame | 2.2 m |
| 15 | **Unstick sidestep** | `:59-79` | wants to move but < 0.3 m progress in 1 s | 1 s | 0.6 s sidestep, 3 flips → `_rescue_snap` |
| 16 | **Micro-idle amble** | `:1167-1182` | inside the formation deadzone | 1.5–4 s | 0.45 m/s — cosmetic, not the complaint |

Paths 1, 2 and 4 are the ones that run in the *normal* firefight case and have no commitment whatsoever.

---

## 2. Where the churn actually is

### 2.1 The verdict on the five candidate hypotheses

- **(a) Think interval re-picks cover every tick with no commitment timer — NO.** Cover search is throttled
  to 1 Hz (`:1398-1400`), and once claimed, `_cover_hold_start_ms` + `ALLY_COVER_DWELL_MS` 8000 hold the man
  on the rock through `_evaluate_goals` (`:842-853`). This was fixed on 2026-08-04 and it holds.
- **(b) Cover scoring flip-flops between two near-equal points — NO.** A claimed point is only released by
  `_release_cover()` (`:1584`), whose callers are the cord pull (`:1235`), the zone pull (`:1245`),
  `_change_state` leaving the fight (`:1618-1619`), and death (`:1772`). There is no score-driven
  re-selection loop.
- **(c) Formation logic fighting combat logic — PARTIALLY REAL, and it is path 4's fault, not formation's.**
  `_execute_idle`'s follow slot (`:1094-1132`) only runs in `IDLE`. But `_execute_combat` drops to `IDLE`
  after 3 s without LOS (`:1301-1303`), and `_change_state` then **releases the cover claim**
  (`:1611-1619`). In jungle, LOS is intermittent; each 3 s blackout hands the man to the formation code,
  which runs him back to a 2.5–4.5 m ring around the player (`:1100`, `:345`) at up to `move_speed * 1.35`
  (`:1129-1130`). He then re-acquires and starts the whole cover trip again — from a worse position.
- **(d) A separation/spacing rule pushing allies off cover — NO.** There is no ally separation force.
  `NavigationAgent3D.avoidance_enabled = false` is explicit (`:1849`). Crowding is handled at *claim* time
  only (`EnemyBase._crowding_cost`, `:1518-1519`), never as a per-frame push.
- **(e) No "under effective fire → go firm" gate — EFFECTIVELY TRUE.** See §3.

### 2.2 The real numbers

**Combat move speed.** `move_speed 5.6` (`:9`) × `COMBAT_SPEED_MULT 0.48` (`:185`) = **2.688 m/s** while in
COMBAT with LOS (`:1274-1275`). The lost-LOS branch and the formation branch use `_move_toward` with
`speed_mult` 1.0 → **5.6 m/s** (`:1624-1631`).

**The strafe (path 2).** `strafe_direction = [-1.0, 0.0, 1.0].pick_random()` on a `randf_range(1.5, 3.0)`
timer (`:1200-1203`). That is a **2-in-3 chance of moving** and a leg of 1.5–3.0 s. The blend at `:1226` is
`move_dir = (move_dir + strafe_vec * 0.4).normalized()` — **normalised**, so even when the range band wants
nothing (`move_dir == ZERO`, the man is at ideal range) the strafe alone produces a **unit** vector and he
slides sideways at the full 2.688 m/s. **4.0–8.1 m of lateral travel per leg, indefinitely.**

**DIVERGENCE, allies vs enemies, in the same function.** `enemy_base.gd:1728-1729` uses
`[-1.0, 0.0, 0.0, 1.0]` (comment: *"More likely to stop"*) on `randf_range(0.8, 2.0)`. Enemies stop 50 % of
the time in short legs; allies stop 33 % of the time in legs up to 50 % longer. And `enemy_base.gd:1755-1758`
degrades the strafe to a non-normalised `+ strafe_vec * 0.1` micro-shuffle while covered; the ally version
normalises first and then damps by `*0.1` afterwards (`:1259`), which lands in roughly the same place — but
the **uncovered** case is where allies are strictly twitchier than the enemies they fight.

**The range band (path 1).** `preferred_range = 12.0` (`:10`) — set nowhere else in the codebase.
The band is `advance if dist > pref * (0.9 | 1.2)`, `back off if dist < pref * (0.6 | 1.0)` (`:1210-1222`).
Against `nva_rifleman` 26.0, `nva_regular` 22.0, `nva_mg` 32.0, `nva_marksman` 55.0
(`data/enemies/*.tres:12`): **the NVA are content at the range where every ally in the squad is still
pushing.** A firefight opening at 25 m has the whole squad walking in ~13 m before anyone is satisfied —
that IS the "advancing" half of the complaint, and it is not the `ADVANCE` goal doing it. It is the range
band inside `ENGAGE_TARGET`, which no dwell timer touches.

Note also `enemy_base.gd:1739-1741`: an enemy that is too far advances at **half magnitude**
(`* 0.5`) and only past `pref * 1.3`. The ally version pushes at full magnitude past `pref * 0.9`.

**Cover-first is a one-shot window (path 3 of the table in §0).** `wants_cover_first()` (`:136-139`) returns
`squad_broken or (_contact_time < 5.0 and nerve < 0.75)`. `_contact_time` accumulates while a target exists
and resets **only** when `target == null` (`:799-804`). It feeds `c.uses_cover` (`:877`), and
`combat_goals.gd:97` scores `SEEK_COVER = -1.0` when `uses_cover` is false. Independently,
`combat_goals.gd:95-96` drops the `+0.4 * (1 - aggression*0.7)` fresh-contact bonus at `contact_time >= 6.0`,
and `:85-86` stops penalising a coverless `ENGAGE` at the same moment.

Worked scores, ally at 12 m, eyes on, no cover, nerve 0.5, threat ~0:

| | t < 5 s | t > 6 s |
|---|---|---|
| `ENGAGE_TARGET` | 1.0 × 0.55 = **0.55** | **1.00** |
| `SEEK_COVER` | 0.15 + 0.2 + 0.26 = **0.61** | **-1.0 (forbidden)** |

So: an ally gets exactly one 5-second window to find cover. If `_find_cover_point` (`:1542`) comes up dry
twice — `_cover_fail_count >= 2` at `:137` and `combat_goals.gd:95` — or if the window simply expires, **he
is locked out of cover for the remainder of that contact and stands in the open strafing.** That is a
faithful description of what the Summoner is watching.

**Lost-LOS hunt (path 4).** `:1292-1299` does not read `has_cover` at all. A man who is holding a claimed
rock and loses the sightline for one think tick walks off it toward `last_known_target_pos` at **5.6 m/s** —
faster than he moves when he *can* see the enemy. The cord check above it (`:1294-1297`) is the only guard,
and it applies to the RTO alone. `has_line_of_sight` here is the **raw** raycast + terrain result
(`:771-782`), not the debounced `contact_conf` the goal layer is careful to use (`:859`, `:864`). Doctrine
elsewhere in this file is explicit that goals must read the debounced value (`:30-31`); the execute layer
does not.

---

## 3. Is there a suppression / pinned response for allies?

**The machinery exists on both sides and is genuinely shared. The ally side is calibrated so that it
almost never triggers.**

What exists:
- `suppression_level` + `apply_suppression` (`:257`, `:1763-1764`) — same shape as `enemy_base.gd:2573-2574`.
- Near-miss suppression is faction-aware: `enemy_base.gd:2940-2947` presses every ally within
  `NEAR_MISS_RADIUS 2.2` of a passing round (`:2926`), and `CombatManager.apply_suppression_in_area`
  (`combat_manager.gd:324-331`) is explicitly faction-blind for blast.
- Heavy pin → `SUPPRESSED` freeze at `CombatPosture.SUPPRESS_PIN 0.7`, checked **outside** the goal dwell
  (`:811-816`), executing as a true anchor: velocity lerped to zero, slow aimed return fire only at a
  visible target (`:1343-1354`). This is exactly the behaviour he is asking for.
- Lighter band → `SEEK_COVER` at `> 0.6` (exit `0.35`, with hysteresis) (`:833-837`).
- Prone latch shared via `CombatPosture` (`:286-290`).

Why it never fires:
- `SUPPRESS_ON_MISS = 0.34` **maximum**, scaled by `1 - d/2.2` (`enemy_base.gd:2960-2963`). A round passing
  1.1 m away contributes 0.17.
- Ally `SUPPRESSION_DECAY = 0.4`/s (`:258`) — **faster than the enemy's 0.3** (`enemy_base.gd:274`). Another
  unflagged divergence, and it runs the wrong way for the man who is supposed to be pinned.
- Therefore reaching the 0.6 cover gate needs ~2 near-misses inside 2.2 m within ~0.5 s; reaching the 0.7 pin
  needs ~3. Ordinary sustained AI fire at 20–30 m does not cluster that tightly.
- Steady-state ally suppression under real incoming fire sits around **0.2–0.4** — above
  `combat_goals.gd:74`'s `under_unanswered_fire` threshold of 0.25 (which correctly throttles ADVANCE and
  FLANK) but **below every gate that would stop his feet.**

There is no "rounds are landing near me → go firm" response at the 0.25–0.6 band. `_is_low_posture`
(`:442-446`, and Law 3 of `bible/04_AI_LOCOMOTION.md`) deliberately excludes that band from *locomotion* —
correctly, to protect aggression — but nothing else covers it either. **This is the missing behaviour and
it is the root of the complaint.**

Also: ally combat velocity (`:1274-1275`) has **no** `_suppression_move_mult()` term. The enemy's does
(`enemy_base.gd:1764-1765`). A suppressed ally moves at full combat speed.

---

## 4. Recommendation — the minimum change

Five edits, all in `scripts/allies/ally_base.gd`, all constants or small conditionals. No new system, no new
state, no player micromanagement. Ordered by value per line changed.

### R1 — Raise `preferred_range` from 12 to 22 m. *(1 line, largest single win)*
**`ally_base.gd:10`** → `var preferred_range: float = 22.0`

Matches `nva_regular` (22.0) and sits under `nva_rifleman` (26.0). Removes the permanent forward pull: at
typical 20–30 m contact ranges the range band produces **zero** movement instead of a 13 m walk-in. Also
lifts `ADVANCE`'s `dist > pref * 1.5` trigger (`combat_goals.gd:123`) from 18 m to 33 m, and `SUPPRESS`'s
`dist > pref` bonus (`:104`) from 12 m to 22 m — so the scorer starts preferring *shooting* over *closing*
at exactly the ranges he is fighting at.
**Cost:** allies fight further out; hit rate drops somewhat at 22 m; the squad reads as less "with you" when
the player pushes. Cheap to tune back — it is one number.

### R2 — Bring the strafe to the enemy's calibration, and kill it while under fire. *(2 lines)*
**`ally_base.gd:1202-1203`** →
```
strafe_direction = [-1.0, 0.0, 0.0, 0.0, 1.0].pick_random()
strafe_timer = randf_range(0.8, 2.0)
```
Stop duty goes 33 % → **60 %**, legs 1.5–3.0 s → 0.8–2.0 s. Median lateral travel per fight drops ~65 %.
(Enemies use `[-1,0,0,1]` / 0.8–2.0 — this lands allies marginally *stiller* than the enemy, which is what
"anchoring more" means.)

**`ally_base.gd:1224`** → gate the strafe on not being under fire:
```
if strafe_direction != 0.0 and suppression_level < 0.25:
```
A man with rounds cracking past stops dancing. `0.25` is already the project's "under unanswered fire"
threshold (`combat_goals.gd:74`) — reusing it avoids inventing a sixth suppression constant.
**Cost:** allies present a more static target and will take marginally more hits; the `strafe_l/r` clips get
less screen time.

### R3 — The go-firm gate: anchor at 0.25, don't wait for 0.6. *(2 lines)*
**`ally_base.gd:1215`** → `if dist > preferred_range * advance_band and suppression_level < ANCHOR_SUPPRESS:`
with a new `const ANCHOR_SUPPRESS: float = 0.25` beside `SUPPRESSION_DECAY` (`:258`).

This is the missing behaviour named in §3, expressed in two lines: **an ally taking effective fire stops
closing the range and fights from where he is.** He keeps aiming, keeps firing (the fire gate is
`suppression_level < 0.5`, `:1283`), keeps his cover re-anchor (`:1254-1259`), and keeps the whole
0.6 → cover and 0.7 → pin ladder above him. He simply stops walking toward the muzzle flashes.

Optionally pair with **`ally_base.gd:258`** → `SUPPRESSION_DECAY: float = 0.3` to match the enemy and stop
allies shrugging off fire faster than the men shooting at them.
**Cost:** an ally pinned at a bad range stays at that bad range; the squad loses some of its ability to
close and finish a broken enemy element. Mitigated by R5.

### R4 — Do not abandon cover when the sightline blinks. *(3 lines)*
**`ally_base.gd:1292-1299`**, at the top of the `else:` branch:
```
else:
    if has_cover and target_last_seen_time < 3.0:
        _settle(delta)
        state_timer += delta
        ...
```
i.e. a covered man whose target ducks **holds the rock** and lets `_think` re-acquire, exactly as the
already-shipped commitment law at `:1189-1194` does for a *dead* target. Same doctrine, the other branch.
Additionally cap the hunt speed: **`ally_base.gd:1299`** → `_move_toward(last_known_target_pos, delta, COMBAT_SPEED_MULT)`
so losing sight cannot make a man move *faster* than seeing.
**Cost:** allies are slower to re-establish contact on a manoeuvring enemy; a genuinely displaced enemy gets
a few more seconds unmolested.

### R5 — Re-arm the cover window instead of locking it out. *(2 lines)*
**`ally_base.gd:136-139`** →
```
func wants_cover_first(nerve: float) -> bool:
    if _cover_fail_count >= 2:
        return false
    return squad_broken or has_cover or suppression_level > 0.25 \
        or (_contact_time < 5.0 and nerve < 0.75)
```
The lockout at 5 s exists to stop a man cover-hunting forever, and that concern is legitimate — but a man
being **shot at** must always be allowed to want cover, however long the fight has run. `suppression_level >
0.25` re-opens the door on evidence, not on a clock. The `_cover_fail_count >= 2` escape hatch is untouched,
so a man on ground with no cover still stops hunting.
**Cost:** more cover trips late in long fights — which is movement, but *purposeful* movement toward a rock,
and it terminates in an 8-second anchored dwell (`:264`, `:842-853`). This is the one recommendation that
adds motion; it is included because without it R3 can freeze a man in the open.

### Explicitly NOT recommended
- Do not lengthen `ALLY_COVER_DWELL_MS` / `ALLY_GOAL_COOLDOWN_MS` / `ALLY_INCUMBENT_MULT` (`:264-266`). They
  are not the problem and raising them makes allies unresponsive to real threat changes.
- Do not add a formation pull into combat states. Pillar 4 forbids the player positioning individual men;
  the fix for the IDLE-drag (§2.1c) is R4, which stops the drop to IDLE happening in the first place.
- Do not touch `enemy_base.gd`. Every edit above is ally-side; the divergent-systems law here cuts the other
  way — allies are currently the *outlier*, and these changes move them toward the shipped enemy
  calibration, not away from it.

---

## 5. What is sacrificed — named plainly (no free lunches)

1. **The squad loses manoeuvre.** R1 + R3 mean allies close far less. Against an enemy that goes firm, the
   friendly half of the fight becomes a firefight of attrition the player must break himself. Flanking
   (`:976-997`) still exists but will be picked less often, because `FLANK` scores off `aggression` and
   `threat_level < 0.3` (`combat_goals.gd:111-118`) and R3 keeps men in the band where threat is non-zero.
2. **Allies can get fixed in a bad position.** R3 anchors a man where the first burst caught him. If that is
   open paddy at 30 m, he stays in open paddy at 30 m, shooting, until suppression decays or R5's cover
   window pulls him. Some men will die there who previously would have walked out. **This is the correct
   trade for Pillar 1 — real infantry do exactly this — but it will read as "why didn't he move" the first
   time the Summoner watches a man die in the open.**
3. **Squad DPS drops.** At 22 m instead of 12 m, ally hit rate falls with range falloff. Firefights get
   longer. Ammunition and casualty economy both shift; the casualty ledger will move.
4. **Less visual life.** R2 removes roughly two-thirds of the lateral motion. Combined with R1's stillness at
   the range band, allies will look *much* stiller. The `strafe_l/r` and `aim_walk` clips lose most of their
   screen time; the `cover_wall_lean_idle` / `idle_crouching_aiming` chains (`:315-318`) carry the look. If
   the result reads as statuary rather than as soldiers, the lever to give back first is R2's stop-duty
   (5-entry table → back to 4), not R1 or R3.
5. **The player carries more of the fight.** A squad that anchors and shoots wins fewer engagements on its
   own. That is arguably *correct* for Pillar 4 — you are IN the squad, not commanding it from above — but
   it raises the player's real workload without raising his click count.

---

## 6. Divergent-copy audit (the standing blindspot)

**Clean. There is exactly one ally combat brain.**

- `scripts/levels/ai_stress_arena.gd` spawns real `AllyBase` instances via `AllyBase.spawn_ally`
  (`:1336`, `:1420`, `:1750`) and only ever sets `set_order` / `set_sprite` / `defense_zone`. **No divergent
  logic — a fix in `ally_base.gd` lands in the arena automatically.**
- `scripts/allies/garrison_defender.gd` is a `RefCounted` promoter (`:11`, `:26`) whose header states the
  intent outright: *"NO third combat brain — the promoted man reuses AllyBase's shipped fire logic whole."*
  Verified: it contains no `_execute_*`, no strafe, no cover code.
- `scripts/levels/support_fire_range.gd:430,672` only calls `apply_suppression` on allies as a test stimulus.
- `strafe_direction` / `strafe_timer` exist in exactly two files: `ally_base.gd` and `enemy_base.gd`.

**The divergence that DOES exist is between the two factions**, and it is undocumented — every instance
runs against the allies:

| Behaviour | Ally | Enemy | Pointer |
|---|---|---|---|
| Strafe stop-chance | 1 in 3 | 1 in 2 | `:1202` vs `enemy_base.gd:1728` |
| Strafe leg length | 1.5–3.0 s | 0.8–2.0 s | `:1203` vs `enemy_base.gd:1729` |
| Advance threshold | `pref * 0.9`–`1.2`, full magnitude | `pref * 1.3`, half magnitude | `:1215-1220` vs `enemy_base.gd:1739-1741` |
| Suppression decay | 0.4 /s | 0.3 /s | `:258` vs `enemy_base.gd:274` |
| Suppression damps move speed | **no** | yes (`_suppression_move_mult`) | `:1274-1275` vs `enemy_base.gd:1764-1765` |
| Preferred range | 12 m (hardcoded, all men) | 18–55 m per `EnemyData` | `:10` vs `data/enemies/*.tres:12` |

The Summoner's report is, at bottom, this table: **his men are calibrated to fidget and push harder than the
men shooting at them.**
