# AI PROGRAMMER — Code Architecture Analysis (AI Goal Doctrine, both factions)

War Room session 2026-07-10 · briefing: `production/war_room/briefing_ai_goals.md`
Lens: code architecture. All claims verified at file:line against working tree.

---

## (a) DIAGNOSIS — per Summoner item, with file:line evidence

### Item 2 (taking it first — it is the hardest bug and it is fully solved): enemy facing is wrong by a DIRECTION-DEPENDENT angle, caused by TWO rotation authorities compounding

**The chain:**

1. `enemy_base.gd:1034` — `_update_aim()` calls `look_at(global_position + flat_aim)` on the **CharacterBody3D itself**. Godot's `look_at` points the node's **−Z** at the target, so the body's yaw becomes `θp = atan2(−aim.x, −aim.z)`.
2. `enemy_base.gd:338` — `_update_sprite()` calls `sprite_actor.set_facing(facing_dir)` with a **world-space** vector every frame.
3. `model_actor.gd:246-251` — `set_facing` sets `rotation.y = atan2(facing.x, facing.z)` — the **local** rotation of the ModelActor, which is a **child of the already-rotated body** (`add_child(ma)` at `enemy_base.gd:302`).

Local child yaw `θc = atan2(aim.x, aim.z) = θp + π`. World model yaw = `θp + θc = 2·θp + π`. **The error is twice the bearing of the aim direction measured from world −Z:**

| aim direction (world) | model visually faces | error |
|---|---|---|
| −Z | −Z | 0° (correct) |
| +X | +Z | 90° |
| +Z | −Z | **180°** |
| −X | +Z (mirrored) | 90° |

**Why the Summoner sees it on ENEMIES specifically:** in `gore_lab.gd` enemies spawn at z ∈ [−19,−12] and fight **toward +Z** (player side z=4.5) — the worst quadrant, ≈180° off. Allies fight toward −Z — near the zero-error direction, so they read roughly right. This exactly reproduces "enemy model rotation is off a lot" while nobody reported allies moonwalking. Additional garnish: `gore_lab.gd:255` sets `e.rotation.y = randf_range(0, TAU)` at spawn, so pre-contact (before the first `look_at`) each enemy's facing is off by a random constant too.

**On the authoring convention:** the `model_actor.gd:250` comment says "authored facing −Z", but `atan2(x, z)` is the formula that points a node's **+Z** at the facing vector. Evidence says the rigs are actually **+Z-authored** (glTF convention) and the formula is correct *in isolation*: allies following the player (body yaw = 0, never `look_at`-ed pre-contact, facing = velocity at `ally_base.gd:191-196`) walk forward, not backward. So the standalone math is fine — **the compounding with the parent's `look_at` is the entire bug.** Not a lag problem; `facing_dir = current_aim_dir` (`enemy_base.gd:1035`) settles in ~0.2–0.4s at aim_speed 5–8, which is fine.

**Exact fix (one line, model_actor.gd:251):**

```gdscript
# was: rotation.y = atan2(_facing.x, _facing.z)      # LOCAL — compounds with body look_at
global_rotation.y = atan2(_facing.x, _facing.z)      # WORLD — parent rotation cancels automatically
```

`global_rotation.y` makes `set_facing`'s contract genuinely world-space, which is what both callers already believe they are passing (`enemy_base.gd:338`, `ally_base.gd:196`). Keep the body `look_at` (`enemy_base.gd:1034`, `ally_base.gd:390`) — hitzone capsules (`enemy_base.gd:347-354`) and `transform.basis.x` strafe vectors (`enemy_base.gd:1120`, `ally_base.gd:449`) depend on body orientation. Add a calibration constant `const AUTHORED_YAW_OFFSET := 0.0` next to it (set to `PI` if any future rig really is −Z-authored) and verify once in the lab with the debug vision lines. Fix the stale comment.

### Item 1: strafe animation overuse — `intent_for` maps ALL combat movement to "strafe", and both executors strafe far too often

**Animation side** — `sprite_state_map.gd:66-71`:

```gdscript
Enums.AIState.COMBAT:
    if is_firing: return "fire"
    if speed > 0.3: return "strafe"     # <- EVERY combat movement above 0.3 m/s
    return "aim"
```

Closing distance (`enemy_base.gd:1104`), backing up (:1100), the covered micro-shuffle (:1116-1122, target speed ≈ 4.2·0.5·0.15 ≈ 0.32 m/s — hovers right at the 0.3 threshold, flickering strafe/aim), and actual strafing all resolve to the `strafe` clip. `MODEL_CLIP` (`sprite_state_map.gd:90-99`) maps it to the `strafe` clip, aliased to `run_left` on v2 rigs (`:110`) — so squaddies visibly crab-walk any time they drift in COMBAT.

**Behavior side** — the executors really do strafe most of the time:
- `enemy_base.gd:1091` — `strafe_direction = [-1.0, 0.0, 0.0, 1.0].pick_random()` → strafing **50%** of combat time, re-rolled every 0.8–2.0s.
- `ally_base.gd:435` — `[-1.0, 0.0, 1.0].pick_random()` → strafing **67%** of the time. The ally strafe weight is 0.4 vs range-band moves that are often zero inside the comfort band (`ally_base.gd:442-450`), so pure-lateral motion dominates.

**Intent policy fix (the doctrine piece — see (b)2):** strafe must be chosen by *geometry* (velocity lateral to facing) not by *state*, and the behavioral strafe probability drops.

### Item 3: ally seek-cover obsession — an unbounded cover-first gate plus three feedback loops

`ally_base.gd:333-357` `_evaluate_goals()` is 3 branches with **no dwell, no hysteresis, no contact-time cap**:

1. **No time cap on cover-first** — `ally_base.gd:346-350`: in contact and `not has_cover and _cover_fail_count < 2` → SEEK_COVER, forever. The enemy version has an escape window: `_contact_time < 5.0` (`enemy_base.gd:854`) and `_contact_time < 6.0` (:864). The ally will chase cover for the entire firefight.
2. **Drift-release loop** — `ally_base.gd:456-457`: in COMBAT with cover, if he shuffles >2.5m from `current_cover`, `_release_cover()` → `has_cover = false` → next think (0.15s later!) re-enters SEEK_COVER (:347), finds the closest point (often the cell he just left, `:559-563`), rushes, leaps, COMBAT, shuffles, releases… `_cover_fail_count` never increments because searches *succeed* (:523 only counts dry searches), so the "2 strikes" hatch never opens.
3. **IDLE dump loop** — `ally_base.gd:536-538`: SEEKING_COVER exits to IDLE after `state_timer > 2.0` even mid-contact; the next `_evaluate_goals` immediately flips back to SEEK_COVER. Visible as follow-jog/cover-sprint stutter.
4. **Suppression flip-flop** — `ally_base.gd:335`: single threshold 0.6, no band. `take_damage` adds +0.3 (:709), decay is 0.4/s (:83) → a man under fire crosses 0.6 in both directions repeatedly, toggling SEEKING_COVER/COMBAT at think rate.

### Item 4: goal churn on LOS change — raw LOS in scores, thin gates, and a units bug

- `enemy_base.gd:848` — `if has_line_of_sight: engage_score += 0.3` consumes the **raw per-think LOS bit**. One foliage blink moves ENGAGE by 0.3 — bigger than the 15% incumbent bonus (:910-911) on a ~0.8 score — so LOS flicker alone flips goals.
- The 0.5s gate (`enemy_base.gd:820`) is the only dwell, and it is uniform: a man 1s into a cover rush can be yanked to ENGAGE because LOS returned.
- **Latent LOD units bug** — `enemy_base.gd:817`: `goal_timer += THINK_INTERVAL` (constant 0.15) but `_think()` runs at `_think_interval_current` (0.15/0.3/0.6 by distance, :45-60). At 0.6s LOD the "0.5s" gate is really 2.0s of wall time, while `_contact_time += _think_interval_current` (:837) counts real seconds — two clocks in the same function disagree. Any dwell layer must tick with `_think_interval_current`.
- Ally side: **nothing at all** — `ally_base.gd:333-357` re-decides from scratch every 0.15s.

### Item 5: wave 2 spawns in the open

`gore_lab.gd:237` — `Vector3(_rng.randf_range(-16.0, 16.0), 1.0, _rng.randf_range(-19.0, -12.0))` — uniform random over the far strip, blind to the 26 cover boxes built at `:156-174`. The boxes' positions are known at build time and simply not recorded. Fix is spawn-time array math, zero raycasts (see (b)5).

### Item 6: round-start corner bunching

`enemy_base.gd:1444-1448` and the ally copy `ally_base.gd:559-563` sort candidates by `distance_squared_to` (closest-first) and take the first claimable. The broker (`_claim_cover`, `enemy_base.gd:1374-1382`) only refuses the **same 2m cell** (`COVER_CELL = 2.0`, :102). Five men starting from the same formation arc all rank the same corner first, and the corner's neighbouring cells are all claimable → five adjacent claims on one rock. The search has no crowding term; the broker has no spacing radius. Fix in (b)4.

---

## (b) MY DOCTRINE PIECE — the shared commitment layer + concrete mechanics

### 1. `GoalCommit` — one small shared class, NOT duplicated lines

**Recommendation: a single `RefCounted` helper, `scripts/ai/goal_commit.gd` (~45 lines), one instance per soldier.** Not a static singleton (per-man state), not 20 duplicated lines (the whole council ask is that doctrine tuning hits both factions in one place; two copies will drift exactly the way ally cover-first already drifted from enemy cover-first). No inheritance change, no rewrite: each brain keeps its own scorer and calls three methods.

```gdscript
## goal_commit.gd — per-soldier goal commitment: dwell + interrupt classes.
class_name GoalCommit
extends RefCounted

enum Interrupt { NONE, SOFT, HARD }

const DWELL: Dictionary = {              # min seconds a goal must run
    Enums.AIGoal.SEEK_COVER: 2.5,        # finish the rush to cover
    Enums.AIGoal.ADVANCE: 2.5,           # finish the bound
    Enums.AIGoal.FLANK_TARGET: 3.0,      # a flank read as a flank
    Enums.AIGoal.ENGAGE_TARGET: 1.5,
    Enums.AIGoal.SUPPRESS_TARGET: 2.0,
    Enums.AIGoal.RETREAT: 2.0,
    Enums.AIGoal.INVESTIGATE: 1.5,
    Enums.AIGoal.HOLD_POSITION: 0.5,
}

var goal: int = Enums.AIGoal.NONE
var age: float = 0.0
var reseek_cooldown: float = 0.0         # cover re-entry lockout (see #3)

func tick(dt: float) -> void:            # dt = the CALLER's real think interval
    age += dt
    reseek_cooldown = maxf(0.0, reseek_cooldown - dt)

func can_switch(to: int, interrupt: int) -> bool:
    if goal == Enums.AIGoal.NONE or to == goal:
        return true
    if interrupt == Interrupt.HARD:
        return true
    var dwell: float = float(DWELL.get(goal, 1.5))
    if interrupt == Interrupt.SOFT:
        dwell *= 0.5
    return age >= dwell

func commit(to: int) -> void:
    if to != goal:
        age = 0.0
    goal = to

func complete() -> void:                 # executor reached its objective: free to re-plan
    age = 999.0
```

**Interrupt classification (computed by each brain per think, passed in):**

| Class | Conditions | Rationale |
|---|---|---|
| **HARD** (switch now) | took damage since last think · suppression crossed 0.7 upward · target died/invalidated · executor called `complete()` (reached cover / bound done / arrived) | Real events. A committed man who ignores bullets looks broken, not committed. |
| **SOFT** (half dwell) | LOS state *stably* changed (debounced, below) · retarget picked a different target (`_find_best_target`) | Meaningful but not urgent. |
| **NONE** (full dwell) | routine score jitter, threat_level drift | This is the churn we are killing. |

**Wiring — enemy (`enemy_base.gd:816-921`), ~6 changed lines:**
- Replace `goal_timer += THINK_INTERVAL` / `if goal_timer < 0.5` (:817-820) with `_commit.tick(_think_interval_current)` — **this also fixes the LOD units bug** in (a)4.
- After the score loop (:914-917): `if best_goal != current_goal and _commit.can_switch(best_goal, _interrupt_class()): _set_goal(best_goal)`; `_set_goal` (:923) additionally calls `_commit.commit(new_goal)`.
- Executors call `_commit.complete()` at natural completion points: cover reached (`enemy_base.gd:1181`), bound reached (:1268), pause elapsed.

**Wiring — ally (`ally_base.gd:333-357`), ~5 changed lines:** identical `tick`/`can_switch(…)` guard around the three branch outcomes; `complete()` at `ally_base.gd:507` (leap into cover). The ally's THINK_INTERVAL is constant 0.15 so `tick(THINK_INTERVAL)` is exact.

Cost: one dict lookup + float compare per think. Zero per-frame work, zero raycasts.

### 2. LOS debounce — score on *stable* LOS, never the raw bit

Both files already carry the timer needed: `target_last_seen_time`. Add one accumulator for the other edge (`_los_seen_time`, += think interval while LOS true, reset on false). Doctrine values:

- **LOS-GAINED is stable** after **0.3s** continuous LOS (2 thinks at close LOD).
- **LOS-LOST is stable** after **1.2s** continuous loss (matches the exposure-drain philosophy at `enemy_base.gd:768-779`; a foliage blink is ~0.15–0.45s).

Concretely: `enemy_base.gd:848` becomes `if target_last_seen_time < 1.2:` (engage credit persists through blinks); `:878` flank trigger `not has_line_of_sight` becomes `target_last_seen_time > 1.2`; grenade/regain-LOS logic unchanged (it already uses `target_last_seen_time < 3.0`, :1151). Ally `:346` already uses `target_last_seen_time < 6.0` — keep. Only *stable* transitions count as SOFT interrupts. Raise incumbent hysteresis 1.15 → **1.25** (`enemy_base.gd:911`) now that dwell carries the main load — belt and suspenders against equal-score dither.

### 3. Ally cover-first gate — fight FROM cover, not FOR cover

Restructure `ally_base.gd:333-357` (shape preserved, still ~3 branches):

```gdscript
func _evaluate_goals() -> void:
    _commit.tick(THINK_INTERVAL)
    var interrupt: int = _interrupt_class()          # same table as enemies

    # Suppression band with hysteresis: enter >0.7, exit <0.35.
    if suppression_level > 0.7:
        _try_goal(Enums.AIGoal.SEEK_COVER, GoalCommit.Interrupt.HARD)
        return
    if current_goal == Enums.AIGoal.SEEK_COVER and suppression_level > 0.35 \
            and not has_cover:
        return                                        # stay committed inside the band

    if target and weapons_free and (has_line_of_sight or target_last_seen_time < 6.0):
        _contact_time += THINK_INTERVAL               # NEW field, mirrors enemy :809
        var want_cover: bool = not has_cover \
            and _contact_time < 5.0 \                 # cover-first WINDOW, then fight where you stand
            and _cover_fail_count < 2 \
            and _commit.reseek_cooldown <= 0.0        # re-entry lockout, kills the loop
        _try_goal(Enums.AIGoal.SEEK_COVER if want_cover else Enums.AIGoal.ENGAGE_TARGET, interrupt)
        return

    _contact_time = 0.0
    _cover_fail_count = 0
    _try_goal(Enums.AIGoal.HOLD_POSITION, interrupt)  # follow
```

Plus the three loop-breakers in the executors:

1. **Re-seek lockout:** `_commit.reseek_cooldown = 6.0` set inside `_release_cover()` (`ally_base.gd:567`) and on SEEK_COVER abandonment. A man may not re-enter SEEK_COVER within 6s of leaving cover — regardless of which loop tried to send him. Bypass only when the HARD suppression branch fires (>0.7).
2. **Steer back instead of drift-release:** `ally_base.gd:456-457` — at `dist_to_cover > 1.2` set `move_dir = (current_cover - global_position).normalized()` (walk back onto the point); release only at `> 4.0` (a real displacement). Same change at `enemy_base.gd:1113` — the enemy has the identical latent loop.
3. **Delete the IDLE dump:** `ally_base.gd:536-538` becomes `_change_state(COMBAT if target else IDLE)` — a man who failed to find cover fights uncovered (duck-dodge already happened at :525-533); he does not jog back to formation mid-firefight.

Result: cover-seek happens **once, early** (first 5s of contact), completes, and the man then lives in ENGAGE using the existing hold/peek override machinery (`ally_base.gd:454-463`), which is already correct — it just never got to run for long.

### 4. Cover dispersion — crowding penalty in candidate scoring (both factions)

Replace the closest-first sort (`enemy_base.gd:1444-1445`, `ally_base.gd:559-560`) with a score:

```
score(c) = dist(self, c) + 0.9 * max(0.0, 6.0 - dist(c, nearest_existing_claim))
```

Lowest score wins. A candidate 2m from an existing claim eats +3.6m of virtual distance; at ≥6m separation the penalty is zero. Since `COVER_SEARCH_OFFSETS` (`enemy_base.gd:103-107`) caps candidates at a 6m ring, the penalty **reorders** but never sends men farther than today's worst case. Implementation: iterate `EnemyBase._cover_claims` keys (Vector3i cell → world = `cell * COVER_CELL`); ≤ ~12 live claims × 12 candidates = 144 distance checks at the existing 1Hz search throttle (`:1189`, `ally_base.gd:517`) — noise. Ally-only garnish (free): prefer candidates on the man's formation side — `+1.5` bonus when `(c - player_pos).normalized().dot(_follow_offset.normalized()) > 0.3`, reusing `_follow_offset` (`ally_base.gd:65`). Five men now fan across five rocks instead of five cells of one corner.

### 5. Wave spawn — cover-adjacent, zero raycasts

`gore_lab.gd`: record boxes as built, spawn behind them.

```gdscript
var _cover_spots: Array[Vector3] = []      # filled in _build_cover()

# in _build_cover(), after each _cover_box(...) incl. the two hard blocks:
_cover_spots.append(pos)                   # (skip h=0.5 prone boxes: hgt >= 1.0 only)

# in _spawn_wave(), replacing gore_lab.gd:237:
var far: Array[Vector3] = _cover_spots.filter(func(p: Vector3) -> bool: return p.z < -8.0)
var pos: Vector3
if far.size() > 0:
    var b: Vector3 = far[(idx * 7 + _wave * 3) % far.size()]     # deterministic spread, one box per man
    pos = b + Vector3(0, 0, -1) * 1.8 + Vector3(_rng.randf_range(-1.2, 1.2), 0.0, 0.0)
    pos.z = clampf(pos.z, -20.0, -9.0)
    pos.y = 1.0
else:
    pos = Vector3(_rng.randf_range(-16.0, 16.0), 1.0, _rng.randf_range(-19.0, -12.0))
```

Offset `−Z * 1.8` puts the man on the far side of his box from the player side (+Z); the stride `idx*7` spreads seven men over the box list so no two share a box. Pure array math at spawn time. Their existing ALERT arrival + bounding ADVANCE doctrine then moves them up cover-to-cover instead of dying in the open.

### 6. Animation intent policy (owned jointly with UX; here is the code contract)

`sprite_state_map.gd:56` — extend the funnel signature (defaulted params, no caller breaks until updated):

```gdscript
static func intent_for(state: int, is_crippled: bool, is_surrendered: bool,
        is_firing: bool, speed: float,
        velocity: Vector3 = Vector3.ZERO, facing: Vector3 = Vector3.ZERO) -> String
```

COMBAT branch replacing `:66-71`:

```gdscript
Enums.AIState.COMBAT:
    if is_firing: return "fire"
    if speed <= 0.5: return "aim"                       # raise dead-zone 0.3 -> 0.5 (kills shuffle flicker)
    var f := Vector3(facing.x, 0, facing.z).normalized()
    var v := Vector3(velocity.x, 0, velocity.z).normalized()
    var along: float = f.dot(v) if f.length_squared() > 0.0 else 1.0
    if along < -0.5: return "retreat"                    # backpedal reads as walk-backward
    if absf(along) < 0.5 and speed < WALK_SPEED_MAX: return "strafe"   # TRUE lateral, sub-2.6 m/s only
    return "run"                                         # closing / crossing = run, the go-to
```

Callers pass what they already have: `velocity, facing_dir` (`enemy_base.gd:343`), `velocity, facing` (`ally_base.gd:206`). **Behavior side:** enemy strafe table `[-1,0,0,1]` → `[-1,0,0,0,1]` (40%→ hold 60%) at `enemy_base.gd:1091`; ally `[-1,0,1]` → `[-1,0,0,0,1]` at `ally_base.gd:435`. Expected read: strafe drops from ~50–67% of combat locomotion to <15%, run/aim dominant — the Summoner's ask verbatim. Optional polish (1 line in ModelActor.play path): `_anim.speed_scale = clampf(speed / 4.2, 0.7, 1.3)` for run/strafe intents so feet track ground speed.

---

## (c) WHAT TO CUT / SIMPLIFY

1. **Cut the second rotation authority** — `set_facing` goes `global_rotation.y`; the model no longer cares who rotated its parent. Fix the "-Z authored" comment while there.
2. **Cut the covered micro-shuffle** — `enemy_base.gd:1116-1122` (`move_dir *= 0.15` + `strafe_vec * 0.1`): covered men go fully still (`move_dir = Vector3.ZERO`). Reads better, ends the 0.3 m/s anim flicker, and removes the drift that feeds the release loop.
3. **Cut the ally SEEKING_COVER→IDLE timeout** (`ally_base.gd:536-538`) — replaced by →COMBAT per (b)3.
4. **Cut the `goal_timer < 0.5` gate** (`enemy_base.gd:817-821`) once GoalCommit lands — redundant, and its THINK_INTERVAL units are wrong under LOD anyway.
5. **Deduplicate `_find_cover_point`** — `ally_base.gd:542-564` is a near-verbatim copy of `enemy_base.gd:1433-1449`. When the crowding score lands, land it ONCE: promote to `static func EnemyBase.find_cover_point(from: Node3D, threat: Vector3) -> Vector3` (or a tiny `CoverSearch` static class beside GoalCommit) and have both call it. Otherwise the dispersion fix gets written twice and drifts twice.
6. **Do NOT build** a full utility-AI/behavior-tree rewrite, squad-level cover assignment, or navmesh-aware cover queries. The scorers are fine; they lacked commitment, not intelligence.

---

## (d) RISKS

1. **Facing fix vs rig authoring:** if any rig is genuinely −Z-authored, the corrected world-space formula flips *that* rig 180° consistently. Constant offset, calibrated in the lab in seconds (debug vision lines at `gore_lab.gd:351-377` show true aim vs body). Ship with `AUTHORED_YAW_OFFSET` for the day a mixed-convention rig arrives.
2. **Dwell vs lethality (Fairness Law):** a man 2.5s-committed to a cover rush while taking hits looks stupid and dies unfairly. Mitigated: damage and suppression >0.7 are HARD interrupts; executor `complete()` frees him early. Tune DWELL down before adding interrupt types.
3. **Re-seek cooldown 6s:** a man shot immediately after leaving cover cannot legally re-seek. Mitigated by the HARD suppression branch bypass; if the bench shows corpses standing in the open, drop to 4s before touching anything else.
4. **Crowding penalty pushing men wide:** bounded by design — candidates stay inside the existing 6m offset ring, penalty only reorders. Zero new exposure distance.
5. **Cover-adjacent spawns → passive campers:** waves spawning behind cover may sit instead of pressing. Their ALERT arrival + bounding ADVANCE (`enemy_base.gd:1240-1293`) plus covering-fire advance credit (:892) exists precisely to move them; if wave pressure drops, raise wave `char_aggression` in the lab, not the doctrine.
6. **LOD interaction:** GoalCommit ticks real think intervals, so dwell is wall-clock-true at every LOD — but SOFT/HARD event *detection* still happens at 0.6s granularity past 150m. Acceptable: nobody sees a 160m enemy hesitate 0.45s extra. Watch it if think LOD ever coarsens further.
7. **`intent_for` signature growth:** two defaulted params, both callers updated in the same commit; sprite renderer ignores them (billboard picks frames by camera, `sprite_actor.gd:109-124`). No third caller exists (verified by grep).

**Perf ledger (constraint: think-rate only, no new per-frame raycasts):** GoalCommit = O(1) per think · LOS debounce = 1 float accumulator · crowding score = ≤144 dist checks at 1Hz per *searching* man · spawn selection = spawn-time array math · facing fix = same 1 atan2 per frame as today. New raycasts added: **zero**.
