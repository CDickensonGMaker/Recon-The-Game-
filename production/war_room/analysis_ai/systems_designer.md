# SYSTEMS DESIGNER — AI Goal Doctrine (Commitment Model, Numbers)

War Room: AI GOALS & BEHAVIOR DOCTRINE, both factions — 2026-07-10
Lens: the numbers. Dwell times, interrupt classes, hysteresis, LOS debouncing, cover dispersion.
All values sanity-checked against the existing enemy_base formulas so both brains converge on ONE doctrine.

---

## (a) DIAGNOSIS — per Summoner item, with file:line evidence

### 1. Strafe animation overused
**Root cause is a single line of intent mapping, not the AI.**
`scripts/visuals/sprite_state_map.gd:66-71` — the COMBAT branch of `intent_for()`:
```
COMBAT: firing -> "fire"; speed > 0.3 -> "strafe"; else "aim"
```
ANY movement above 0.3 m/s in COMBAT plays the strafe clip. Combat movement is near-constant:
- Enemy combat move speed = `move_speed * 0.5` = ~2.0 m/s (`enemy_base.gd:1129-1130`), strafe impulse re-rolled every 0.8-2.0s (`enemy_base.gd:1089-1092`).
- Ally combat move speed = `move_speed * 0.6` = ~2.7 m/s (`ally_base.gd:469-470`), strafe re-rolled every 1.5-3.0s (`ally_base.gd:433-436`).

So ~100% of combat locomotion resolves to "strafe" regardless of actual direction. Forward range-closing, backing up, rushing — all read as strafing. There is no run/aim-walk branch in COMBAT at all. `MODEL_CLIP` maps "strafe" -> `strafe` (aliased to `run_left` on v2 rigs, `sprite_state_map.gd:110`), so the v2 grunt literally side-shuffles while moving forward.

### 2. Model rotation off
**Two rotation authorities compound.**
- `enemy_base.gd:1030-1035` (`_update_aim`): `look_at(global_position + flat_aim)` rotates the **CharacterBody3D itself**.
- `enemy_base.gd:338` (`_update_sprite`): `sprite_actor.set_facing(facing_dir)` — and `model_actor.gd:246-251` sets the **child's local** `rotation.y = atan2(facing.x, facing.z)` from a **world-space** direction.
When the parent body has been yawed by `look_at`, the child's local rotation is applied ON TOP of the parent's yaw — the model's world facing is the SUM of both yaws. Off by up to 2x the aim yaw. AllyBase has the identical pair (`ally_base.gd:387-390` look_at + `ally_base.gd:196` set_facing).
- Compounding: sign convention. Aligning a -Z-authored model to facing `f` needs `rotation.y = atan2(-f.x, -f.z)`; the code's `atan2(f.x, f.z)` aligns **+Z** with facing. Comment at `model_actor.gd:250` says "authored facing -Z". If the Mixamo-style rigs are actually +Z-authored the formula is right and the comment is wrong — verify per-rig; either way this is masked/doubled by the parent look_at.
- Thrash: `enemy_base.gd:1361` (`_move_toward`) sets `facing_dir = move direction` **every frame**, while `_update_aim:1035` sets `facing_dir = current_aim_dir` only when `has_line_of_sight`. When LOS strobes, facing flips between velocity and aim at think cadence — the visible "facing wrong way from where they shoot".

### 3. Squad (allies) seek cover more than anything
**A guaranteed release-reacquire loop plus a gate with no dwell.**
- `ally_base.gd:346-349`: any contact (`has_line_of_sight or target_last_seen_time < 6.0`) + `not has_cover` + `_cover_fail_count < 2` -> SEEK_COVER. Evaluated EVERY think tick (6.7Hz), no goal timer, no hysteresis (`ally_base.gd:333-357` — the whole brain).
- The loop: reach cover (`ally_base.gd:498-507`, arrival at <1.4m — already 1.4m off-center) -> COMBAT -> covered movement still drifts (residual `move_dir * 0.1` + strafe term, `ally_base.gd:448-459`) -> at >2.5m `_release_cover()` (`ally_base.gd:456-457`) -> `has_cover = false` -> next think re-enters SEEK_COVER -> claims the next-nearest point -> repeat forever. Cover-seeking is structurally the squad's dominant activity.
- `_cover_fail_count` is **never reset** on allies (declared :93, incremented :523, no reset anywhere) — enemies reset it on contact end (`enemy_base.gd:829`). So an ally who fails 2 searches is locked out of cover for life; one who succeeds loops forever. Both are wrong.
- No equivalent of enemy `_contact_time` (`enemy_base.gd:809`) — the enemy cover-first doctrine expires after 5-6s of contact (`enemy_base.gd:854,864`); the ally version never expires within a contact.

### 4. Goals flip because LOS changed
- Enemy: `_evaluate_goals()` gate is only `goal_timer < 0.5` (`enemy_base.gd:820`) + 15% incumbent bonus (`enemy_base.gd:910-911`). But raw boolean `has_line_of_sight` swings ENGAGE by +0.3 on a base of 0.5 (`enemy_base.gd:847-849`) — a **60% swing** — and FLANK by +0.3 (`enemy_base.gd:877-879`) in the opposite direction. One foliage blink flips the winner despite the 15% bonus: **the hysteresis is smaller than the single-tick input swing.** The exposure clock already has proper debouncing (3x drain, `enemy_base.gd:773-779`) but the GOAL layer consumes the raw boolean.
- Ally: no gate, no bonus, nothing (`ally_base.gd:333-357`); the 6.0s seen-window boundary and the suppression 0.6 line both flip state at think rate.

### 5. Wave 2 spawns in the open
`scripts/levels/gore_lab.gd:237`: `pos = Vector3(rand(-16,16), 1.0, rand(-19,-12))` — uniform random, no cover-adjacency test. Cover boxes are known to the lab (`_build_cover`, :162-173). Pure spawn-placement; fix in lab code, not the AI.

### 6. Round start: squad stacks one corner of cover
- Candidate scoring is **pure distance**: `enemy_base.gd:1444-1445` and the ally clone `ally_base.gd:559-560` sort by `distance_squared_to` and take the first claimable.
- The claim broker only blocks the exact 2m cell (`COVER_CELL = 2.0`, `_cover_key` at `enemy_base.gd:1368-1369`; `_claim_cover` :1374-1382). Adjacent cells 2m apart are free.
- All five men stand near each other at round start, so their 12-point search patterns (`COVER_SEARCH_OFFSETS`, `enemy_base.gd:103-107` — rings at 3m and 6m only) generate nearly identical candidate sets. Result: five men in five adjacent cells of the same corner. Working as coded, wrong as doctrine.

---

## (b) THE DOCTRINE — commitment model, concrete numbers

### B1. Contact Confidence — the LOS debouncer (replaces the raw boolean in goal scoring)

One new float per brain, integrated at think rate from the SAME ray that already runs (`_update_line_of_sight`). Zero new raycasts.

```
var _los_confidence: float = 0.0   # 0..1

# in _update_line_of_sight(), after computing new_los:
if new_los:
    _los_confidence = minf(1.0, _los_confidence + dt / 0.3)   # full in 0.3s of sight
else:
    _los_confidence = maxf(0.0, _los_confidence - dt / 2.0)   # empty in 2.0s blind
# dt = _think_interval_current (enemy) / THINK_INTERVAL (ally)
```

**Rates, checked against the exposure clock:** exposure builds over `d_exposure_ramp` (2.5s default) and drains at 3x — fully forgiven in ~0.83s of broken LOS (`enemy_base.gd:773-779`). Confidence drains in 2.0s — deliberately ~2.4x slower: **the accuracy layer forgives before the intent layer does.** A player who breaks LOS gets his safety window back fast (Fairness Law intact), but the enemy does not change his PLAN for 2 seconds (smoothness). Same raw ray, two integrators.

**Consumers:**
- Goal scoring uses `C`, never the boolean: `engage_score += 0.3 * C` (was `+0.3 if has_line_of_sight`); `flank_score += 0.3 * (1.0 - C)` when `target_last_seen_time < 3.0`; suppress LOS term `* C`.
- FIRING keeps the raw boolean — never shoot a wall on "confidence".
- Ally contact predicate becomes `C > 0.0 or target_last_seen_time < 6.0` (the 6s memory stays for maneuver-to-regain).
- Facing priority (feeds #2): face `current_aim_dir` while `C > 0.0`; face velocity only when `C == 0.0`. Kills the aim/velocity flip-flop at its input.

### B2. Per-goal minimum dwell (commitment table — BOTH brains, same numbers)

`goal_timer` already exists on enemies (`enemy_base.gd:33,817`); allies get the identical mechanic. `_evaluate_goals()` early-outs while `goal_timer < DWELL[current_goal]` unless a Class-A interrupt fired (B3).

| Goal | Min dwell | Rationale (checked against existing timings) |
|---|---|---|
| SEEK_COVER (the rush) | **until arrival, hard cap 4.0s** | A rush COMPLETES. 6m ring at ~4.2 m/s ≈ 1.5s; cap catches unreachable points. |
| ENGAGE from cover | **3.0s** | ≥ one full burst cycle: 5-6 rds @ ~0.1-0.15s + 0.4-1.2s recovery (`enemy_base.gd:1137-1144`, `ally_base.gd:478-486`) ≈ 1.9-2.1s, plus a settle beat. |
| ENGAGE in the open | **2.0s** | Exposed men may re-decide sooner, but never sub-second. |
| ADVANCE | **per bound: rush + pause complete** | Bound ≈ 5m @ full speed ≈ 1.3s + existing 0.8-1.6s pause (`enemy_base.gd:1270`) — natural 2.1-2.9s commit. A started bound always finishes. |
| FLANK | **3.5s** | A sub-3s flank is jitter; at ~4 m/s that's ≥14m of actual arc. |
| SUPPRESS | **2.5s** | One burst cycle + recovery. |
| RETREAT | **2.0s** | Long enough to visibly break contact, short enough to rally. |
| INVESTIGATE / HOLD | **1.0s** | Cheap goals, cheap to leave. |

Cover HOLD once fighting from it: leave cover only via (i) no contact for 4.0s (C hits 0 + 2s grace), (ii) ADVANCE wins with covering fire (`EnemySquad.has_covering_fire`), or (iii) Class-A interrupt. Peek rhythm from cover (allies have the clips, `ally_base.gd:99-100`): **down 1.2-2.2s, up 0.8-1.5s** — the up window matches one burst.

Target hold: keep `RETARGET_INTERVAL = 2.0` and `TARGET_MEMORY = 8.0` (`enemy_base.gd:682-683`) and the 1.3x incumbent target stickiness (`enemy_base.gd:693-694`). Target switching already self-punishes via the exposure-clock reset (`enemy_base.gd:752-753`). No change — this subsystem is the model the goal layer should copy.

### B3. Interrupt classes (what MAY preempt a committed goal)

- **CLASS A — always preempts, ignores dwell:**
  took damage (any amount — `take_damage` already forces COMBAT, `enemy_base.gd:1713-1725`); suppression crossing **0.8** (forced SUPPRESSED, exists at `enemy_base.gd:948`); became crippled; target died or freed (`_candidate_dead`); grenade telegraph within 10m; player order (allies: `set_order`, `ally_base.gd:70-72`).
- **CLASS B — preempts only if ≥50% of dwell elapsed:**
  new candidate target at <0.5x current target distance; squad intel contradicts (shared contact >15m from ours); cover claim lost to a dead-owner purge.
- **CLASS C — NEVER preempts:**
  LOS flicker (any change shorter than the 2.0s confidence drain); incumbent score erosion; range-band changes; suppression wiggle below 0.6.

### B4. Hysteresis values

- **Enemy:** replace the flat 0.5s gate (`enemy_base.gd:820`) with the B2 dwell table. Raise incumbent bonus **1.15 -> 1.25** (`enemy_base.gd:911`). Convergence check that makes this sufficient where 15% was not: with confidence-smoothed inputs, the max score drift per 0.5s window is bounded by the drain rate — `dC <= 0.5/2.0 = 0.25` -> engage-score drift `<= 0.3 * 0.25 = 0.075`, versus an incumbent edge of `0.25 * (0.6..0.9) = 0.15-0.22`. **Hysteresis now strictly exceeds the worst single-window input swing** (before: 0.3 boolean swing vs 0.075-0.135 edge — inverted). That inequality IS the anti-dither guarantee.
- **Ally:** gets the same dwell table + Class system, plus explicit **bands** on its two flickering thresholds:
  - Suppression: enter SEEK_COVER at **> 0.6**, exit at **< 0.35** (decay 0.4/s, `ally_base.gd:83` -> the band is worth ~0.6s of guaranteed non-flicker).
  - Contact: enter COMBAT on `C > 0.5`; drop to follow only when `C == 0.0 and target_last_seen_time > 6.0`.
  - Ally does not need the full score/incumbent machinery — 3 branches + dwell + bands is enough brain (see (c)).

### B5. Cover dispersion — candidate scoring formula (both `_find_cover_point`s, `enemy_base.gd:1433-1449`, `ally_base.gd:542-564`)

Replace the pure-distance sort with a cost function; pick MINIMUM cost among LOS-blocking candidates:

```
cost(c) = dist(self, c)                        # travel
        + 4.0 * crowd(c)                       # dispersion

crowd(c) = SUM over p in _cover_claims.values() (valid, owner != self, dist(c,p) < 6.0):
             (1.0 - dist(c, p) / 6.0)          # linear falloff, R = 6m
```

**Weight math:** a candidate 2m from one existing claim (the adjacent-cell stack) pays `4.0 * (1 - 2/6) = 2.67m` equivalent travel; 2m from two claims pays 5.3m. So man #2 takes the nearest corner only if the next cluster is >2.7m farther — otherwise he fans. Five men across the lab's 26-box field spread across 3-4 clusters instead of five adjacent cells of one corner.

**Cost:** `_cover_claims` holds ≤ one entry per fighting man (~12); 12 candidates x 12 claims = 144 distance ops per search, throttled at ≤1Hz per searching man (`_cover_search_timer = 1.0`). Zero raycasts. Bound points (`_find_bound_point`, `enemy_base.gd:1407-1427`) get the same crowd term with **weight 2.0** (bounds are transient; full weight would stall advances).

**Search ring:** add one 9m ring (4 points: (±9,0,0),(0,0,±9)) to `COVER_SEARCH_OFFSETS` so late claimants have somewhere to fan TO. +4 rays per 1Hz search — inside the perf constraint (throttled, not per-frame).

### B6. Ally cover-obsession numbers (completes #3)

1. Add `_contact_time` (enemy parity): cover-first gate becomes `_contact_time < 6.0 and _cover_fail_count < 2` — the doctrine EXPIRES per contact like the enemy's (`enemy_base.gd:854,864`).
2. Reset `_cover_fail_count = 0` and `_contact_time = 0.0` when contact ends (C == 0 and seen > 6s) — mirrors `enemy_base.gd:828-829`.
3. **Re-anchor instead of release:** covered man drifting past **1.8m** from `current_cover` steers back toward it; release only on goal change or Class A/B. Delete the 2.5m auto-release loop (`ally_base.gd:456-457`, `enemy_base.gd:1113-1114` keeps release only on goal exit). This kills the reacquire loop at its root.
4. Re-validate a held point when the threat has displaced >8m: one extra ray at the next 1Hz search tick, drop cover if it no longer blocks.

### B7. Strafe/run/aim-walk thresholds (feeds #1 — I own the numbers, animation owns the clips)

Rewrite the COMBAT branch of `intent_for()` (`sprite_state_map.gd:66-71`) with velocity-direction awareness (callers pass `velocity` dot products or a lateral ratio):

```
lateral_ratio = |velocity . right| / speed      # right = facing x UP
COMBAT:
  firing                                   -> "fire"
  speed > 3.2                              -> "run"       (a rush reads as a rush)
  speed in [0.6, 3.2] and lateral > 0.7    -> "strafe"    (only genuinely lateral shuffle)
  speed in [0.6, 3.2]                      -> "walk"      (aim-walk; models: run_forward until an aimed-walk clip lands)
  else                                     -> "aim"
```

Check against actual speeds: enemy combat move ≈ 2.0 m/s, ally ≈ 2.7 m/s, rushes at 4.0-4.5 m/s. Under this table, range corrections and rushes (forward-dominant) read as walk/run; strafe fires only during the deliberate lateral shuffle — expected strafe screen-time drops from ~100% of combat locomotion to <20%. Also raise the idle deadband **0.3 -> 0.5 m/s** (the `lerpf` decel tails at :1043-1044/:416-417 sit above 0.3 for several frames and flicker move clips while standing).

### B8. Facing (feeds #2 — the rule, programmer owns the transform fix)

- **One yaw authority.** Either the body's `look_at` (`enemy_base.gd:1034`, `ally_base.gd:390`) or `ModelActor.set_facing` — never both. Recommendation: body stays unrotated; `set_facing` converts world dir to parent-local before applying (or the body rotates and `set_facing` becomes a no-op for models). Verify each rig's authored forward (+Z Mixamo vs -Z comment at `model_actor.gd:250`) with a one-off bench check per unit.
- **Facing input priority:** aim dir while `C > 0.0`; velocity otherwise (kills the `_move_toward` :1361 vs `_update_aim` :1035 fight).
- **Yaw slew rate:** cap at **540°/s in COMBAT, 180°/s otherwise** — think-tick facing changes become visible turns, not snaps.

### B9. Spawn placement (#5) — lab-side

`gore_lab.gd:237`: the lab already knows its cover boxes. Spawn each wave-2+ man at `box_pos + away_from_player_dir * (box_half_depth + 1.2m)` for a random box with `z < -8`, fall back to the current random roll if none free (claim-broker check the cell first). Zero raycasts, zero AI changes.

---

## (c) WHAT TO CUT / SIMPLIFY

1. **Cut per-man cover sectors / assigned arcs.** The crowding penalty alone produces dispersion; sector assignment is a squad-broker feature with real complexity and marginal visible gain. (Sacrifice named: no guaranteed 360° coverage — accepted, penalty-driven fan-out approximates it.)
2. **Do NOT port the full enemy goal-scorer to allies.** The ally brain stays 3-4 branches + dwell + confidence + bands. Same DOCTRINE, thinner machine. Porting the scorer doubles the tuning surface for zero player-visible gain — the Summoner sees his squad up close; predictability is a feature there.
3. **Cut the "don't take cover in the threat's lap" scoring term** (distance-to-threat penalty) from B5 v1. All candidates already pass the LOS-block ray; add the term only if the bench shows men covering at sub-6m from contact.
4. **Delete both magic `6.0` contact windows in ally_base** (:346) in favor of the confidence predicate — one number owns "in contact" instead of two.
5. **Consolidate the doctrine constants in ONE place** (a small `AIDoctrine` const block or statics on EnemyBase that AllyBase reads, like it already reads `COVER_SEARCH_OFFSETS`/`_claim_cover` at `ally_base.gd:552,562`). Two hand-copied value sets WILL diverge again — that divergence is exactly how the ally brain got here.
6. **No new animation clips required** — B7 works entirely inside the existing MODEL_CLIP/alias tables.

---

## (d) RISKS

1. **Commitment reads as stupidity if Class-A interrupts misfire.** A man finishing a 4s rush through a grenade, or holding ENGAGE while being knifed, is worse than dithering. Mitigation: damage is Class A (already wired via `take_damage` forcing COMBAT); bench-test grenade telegraph preemption specifically.
2. **Dispersion weight too hot scatters men into bad positions.** All candidates block LOS, but a 9m-ring point may cost 2+ extra seconds of exposed running. `4.0` is a bench-tune starting value; if men sprint past good cover, drop toward 2.5.
3. **2.0s intent memory can look psychic.** An enemy holding aim on a corner for 2s after the player broke LOS is honest (last-known info) but may read as wall-hack if his MODEL tracks the player's actual new position. Facing must track `last_known_target_pos`, never live target position, once raw LOS is false.
4. **Re-anchor magnetism (B6.3).** A covered man tugged back to a stale point after the threat moved looks robotic — the 1Hz revalidation ray (B6.4) is the required companion, not optional.
5. **Dwell + think-LOD interaction.** At 0.6s think interval (>150m, `enemy_base.gd:45-60`), a 2.0s dwell is only ~3 think ticks — fine; but Class-B "50% of dwell" needs `goal_timer` accumulated in real dt (it already is, via `+= THINK_INTERVAL` at :817 — note it should add `_think_interval_current`, currently a latent mismatch at LOD: `enemy_base.gd:817` adds the constant while think runs slower).
6. **Two-brain drift is the meta-risk.** Every number above exists once in this file and should exist once in code (see cut #5). If enemy and ally values are hand-copied, the next balance pass on one silently forks the doctrine again.
