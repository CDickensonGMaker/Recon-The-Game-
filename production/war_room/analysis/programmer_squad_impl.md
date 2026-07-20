## Lead Programmer / Godot Specialist — ally_base.gd squad-feel implementation

Scope: `scripts/allies/ally_base.gd` only. `scripts/enemies/enemy_base.gd` is owned by a
parallel agent — read for reference, no edits proposed. `scripts/player/player.gd` untouched
(`WALK_SPEED: float = 5.0`, confirmed `scripts/player/player.gd:5`).

---

### 1. Strict-typing hazards, per change

**A. move_speed 4.5 -> ~5.8 + catch-up band**
- `move_speed` stays `float`; no inference risk on the literal change itself.
- `player.gd` has **no `class_name`** (confirmed: no `class_name` line in the file) — nothing in the
  codebase can reference `Player.WALK_SPEED` as a global identifier. Both the ally code and the probe
  must reach `WALK_SPEED` via `GameManager.player` (an instance, already used at `ally_base.gd:85,584`)
  or via `preload("res://scripts/player/player.gd").WALK_SPEED` (a script-resource const lookup) — never
  a bare `Player` global symbol.
- Catch-up band must be a *scalar multiplier on move_speed inside `_move_toward`/`_execute_idle`*,
  never a second raw velocity write — `_move_toward` (:863-867) already uses `lerpf(velocity.x, direction.x * move_speed, delta * 8.0)`. Compute the multiplier as
  `var catchup_mult: float = clampf(dist / SOME_RANGE, 1.0, CATCHUP_MAX)` — use `clampf`, not `clamp`
  (bare `clamp()` on floats returns `Variant` under strict typing and fails inference on `var x: float = clamp(...)`).
- Restrict the multiplier to the FOLLOW branch only: compute it locally inside the
  `OrderMode.FOLLOW` arm of `_execute_idle` (:583-609) and pass it into `_move_toward` as an
  explicit `float` parameter, or bump a local `float` and call a dedicated
  `_move_toward(pos, delta, speed_mult)`. Do NOT mutate `move_speed` itself — every combat/unstick
  caller (`_move_toward` default arg, `_update_unstick`, `_execute_combat`, `_execute_seeking_cover`)
  reads the same field, so a global overwrite leaks catch-up speed into a firefight.

**B. Formation hysteresis on player-velocity threshold (:596)**
- `pv.length() > 2.0` — `pv` is already `Vector3` (typed at :592/:594), `.length()` returns `float`,
  fine. Hysteresis needs a **latched bool**, not a stateless re-check: `var _formation_moving: bool = false`.
  Enter/exit consts: `const FORMATION_ENTER_SPD: float = 3.2`, `const FORMATION_EXIT_SPD: float = 1.5`.
  Logic: `if not _formation_moving and pv.length() > FORMATION_ENTER_SPD: _formation_moving = true`
  `elif _formation_moving and pv.length() < FORMATION_EXIT_SPD: _formation_moving = false`. No `clampf`
  hazard here, but the two consts MUST satisfy `ENTER > EXIT` — that inequality is exactly what the
  probe checks (see §5).
- **Eased shape transition**: interpolate the *slot itself* (the huddle-arc offset vs. the staggered-file
  offset), not a boolean snap. Use a `float` blend var `_formation_blend: float = 0.0` driven toward
  `1.0 if _formation_moving else 0.0` via `move_toward(_formation_blend, target, delta * RATE)` — note
  `move_toward` (the *global* float function, not `Vector3.move_toward`) returns `float` cleanly, safe
  under strict typing (`var x: float = move_toward(a, b, c)` infers fine — it's `lerpf`/`clamp` that are
  the trap, not `move_toward`). Then `slot = huddle_slot.lerp(file_slot_pos, _formation_blend)` —
  `Vector3.lerp` is a method on a typed `Vector3` so it returns `Vector3`, no inference issue.

**C. Deadzone + micro-idle replacing `_settle()` (:605-609, :619-621)**
- `dist := global_position.distance_to(slot)` already typed via `:=` inference from a `float`-returning
  method — fine, no change needed.
- The deadzone can reuse the existing `follow_distance: float = 5.0` field (already `> 0`, already the
  exact boundary at :606) — no new const required to satisfy the invariant, but rename its *role* in
  the branch: outside it -> `_move_toward`, inside it -> new `_micro_idle(delta)` instead of `_settle(delta)`.
  `_settle` itself should NOT be deleted if HOLD (:611) and MOVE_TO (:616) still call it for their own
  "arrived" case — check whether they should also switch to `_micro_idle`; if not touched, `_settle`
  remains live code, not a fossil (still called from two sites).

**D. Sight cap via new `scripts/ai/sight_cap.gd`**
- `class_name SightCap extends RefCounted` (no scene tree needed — matches `IllumFlare.is_lit` and
  `MissionWeather.sight_mult`, both `static`, both callable with **zero instance/autoload lookup**:
  `MissionWeather` (`scripts/world/mission_weather.gd:4,8`) exposes `static var sight_mult: float`;
  `IllumFlare` (`scripts/combat/illum_flare.gd:3,14`) exposes `static func is_lit(pos: Vector3) -> bool`.
  Neither is an autoload — they are plain `class_name` classes read via their static members, exactly
  like `EnemyBase._sight_cap` already does at `enemy_base.gd:688-689`. A static func in `SightCap` can
  touch both safely: no node, no `get_tree()`, no null risk.
- `grid.get_vegetation(world_pos: Vector3) -> float` is a real (non-static) method on
  `GameplayGrid` (`terrain/core/gameplay_grid.gd:2,348`) — the caller must pass an *instance*, hence the
  `grid` parameter typed `GameplayGrid` (nullable, no `@export`/no `class_name` static-cache trap here
  since it's a plain parameter type, not a new resource type).
- `class_name` + stale `.godot` cache: a **brand-new** `class_name SightCap` file will not resolve by
  bare name until Godot rescans (`.godot/global_script_class_cache.cfg`). In-editor this is automatic on
  focus-regain; **headless test runs launched immediately after creating the file may fail to resolve
  `SightCap` as an identifier** the first time. Mitigate by referencing it once via `load()`/opening the
  editor once before running `tests/`, or simply expect and re-run once if the first headless run throws
  `Identifier "SightCap" not declared`.

**Exact function:**
```gdscript
## sight_cap.gd - shared AI sight-distance model (weather x vegetation x flare).
class_name SightCap
extends RefCounted

const OPEN: float = 140.0
const JUNGLE: float = 45.0


static func at(grid: GameplayGrid, from_pos: Vector3, look_pos: Vector3) -> float:
	var mult: float = MissionWeather.sight_mult
	if mult < 0.9 and IllumFlare.is_lit(look_pos):
		mult = maxf(mult, 0.9)
	if grid == null:
		return OPEN * mult
	var veg: float = maxf(grid.get_vegetation(from_pos), grid.get_vegetation(look_pos))
	return lerpf(OPEN, JUNGLE, clampf(veg, 0.0, 1.0)) * mult
```
This is a byte-for-byte port of `EnemyBase._sight_cap` (`enemy_base.gd:687-694`), just parameterized
instead of reading `self`/`_grid`. **Flag for the enemy_base.gd-owning agent (not mine to touch):** once
this file exists, `EnemyBase._sight_cap` becomes a duplicate of the same model — a live fossil risk
under ADR-023 unless a follow-up bead retargets it to call `SightCap.at(_grid, global_position, at)`
too. Two copies of one sight formula is exactly the divergent-systems failure mode already flagged for
this project.

---

### 2. Where AllyBase acquires the grid

AllyBase has no `_grid` field today and no `_ready()`-time world lookup. **Do not copy EnemyBase's
`_ready()`-time fetch verbatim** (`enemy_base.gd:285-287`) — that pattern already silently fails forever
if `game_world` isn't in its group yet at spawn (no retry), and this project's allies are explicitly
spawned pre-`SquadSystem`-assignment (`_setup_visual`'s `call_deferred("dress_visual")` comment at
`ally_base.gd:227-229` documents that exact ordering hazard already). A **lazy, cached, retrying fetch**
is safer:

```gdscript
var _grid: GameplayGrid = null

func _get_grid() -> GameplayGrid:
	if _grid == null:
		var gw: Node = get_tree().get_first_node_in_group("game_world")
		if gw != null and "gameplay_grid" in gw:
			_grid = gw.gameplay_grid
	return _grid
```

Call `_get_grid()` from `_find_target()` (think-cadence, 0.15s — group lookup is cheap, this is not a
per-frame cost). It latches once non-null and costs nothing extra after that; until then it retries
every think tick instead of being permanently null because `_ready()` ran one frame too early. Note the
`gw.gameplay_grid` dynamic-property access on a statically-`Node`-typed `gw` is the same pattern already
compiling clean in `enemy_base.gd:286-287` — GDScript strict mode treats unresolved member access on
`Object`-derived static types as a runtime `Variant` lookup (warning, not error), so this is safe to
replicate as-is.

---

### 3. New per-instance state (placement + types)

Group these with the existing squad/formation fields near `_follow_offset` (`ally_base.gd:116-118`),
not scattered — that block is already the file's "formation" neighborhood:

```gdscript
var _grid: GameplayGrid = null
var _formation_moving: bool = false
var _formation_blend: float = 0.0
const FORMATION_ENTER_SPD: float = 3.2
const FORMATION_EXIT_SPD: float = 1.5
const FORMATION_BLEND_RATE: float = 2.5   ## 1/seconds to fully ease the shape
var _idle_drift_dir: Vector3 = Vector3.ZERO
var _idle_look_timer: float = 0.0
```
No comment narrating *why* hysteresis exists beyond the units/contract line already modeled by the
file's own style (compare `_stuck_pos`/`_stuck_t` at :48-50, which carry zero history-narration). Do not
add a "## was a bare threshold before" tombstone — COMMENT DISCIPLINE forbids it outright and it is the
exact pattern that hid the `ALERT_RANGE` fossil previously.

---

### 4. THE PROBE

New file: `tests/test_squad_feel_invariants.gd` (mirrors `tests/test_flat_damage.gd`'s
`extends Node` / `_ready -> _run` / `get_tree().quit(code)` shape; headless-runnable via a matching
`.tscn`, same convention as every other `tests/*.gd`).

```gdscript
## test_squad_feel_invariants.gd - negative-controlled invariant probe for the
## ally move-speed/hysteresis/deadzone/sight-cap changes. Structural only.
## Run: godot --headless --path . res://tests/test_squad_feel_invariants.tscn
extends Node

## player.gd has no class_name - pull WALK_SPEED off the script resource itself.
const PlayerScript: GDScript = preload("res://scripts/player/player.gd")


func _ready() -> void:
	_run()

func _run() -> void:
	var failures: int = 0
	var ally := AllyBase.new()
	var player_walk_speed: float = float(PlayerScript.WALK_SPEED)

	# 1. ally must out-walk the player's WALK_SPEED, or catch-up is impossible.
	if ally.move_speed <= player_walk_speed:
		print("FAIL: ally move_speed %.2f <= player WALK_SPEED %.2f" % [ally.move_speed, player_walk_speed])
		failures += 1

	# 2. hysteresis band must be a real band, not a re-labeled single threshold.
	if AllyBase.FORMATION_ENTER_SPD == AllyBase.FORMATION_EXIT_SPD:
		print("FAIL: formation enter/exit thresholds are equal - no hysteresis")
		failures += 1
	if AllyBase.FORMATION_ENTER_SPD <= AllyBase.FORMATION_EXIT_SPD:
		print("FAIL: formation ENTER (%.2f) must be > EXIT (%.2f)" % [AllyBase.FORMATION_ENTER_SPD, AllyBase.FORMATION_EXIT_SPD])
		failures += 1

	# 3. deadzone radius must exist and be positive.
	if ally.follow_distance <= 0.0:
		print("FAIL: formation deadzone radius %.2f is not positive" % ally.follow_distance)
		failures += 1

	# 4. sight cap must respond to weather - NOT a hardcoded constant.
	var grid: GameplayGrid = null
	var open_dist: float = SightCap.at(grid, Vector3.ZERO, Vector3.FORWARD * 50.0)
	MissionWeather.sight_mult = 0.4
	var fogged_dist: float = SightCap.at(grid, Vector3.ZERO, Vector3.FORWARD * 50.0)
	MissionWeather.sight_mult = 1.0  # restore - static var leaks across the whole process
	if is_equal_approx(open_dist, fogged_dist):
		print("FAIL: SightCap.at() did not change under a weather sight_mult swing (flat constant?)")
		failures += 1

	ally.queue_free()

	if failures == 0:
		print("PASS: squad feel invariants OK")
	else:
		print("FAIL: squad feel invariant suite had %d failure(s)" % failures)
	get_tree().quit(1 if failures > 0 else 0)
```

**What this CANNOT prove:** whether the squad *feels* better — arrival timing, whether the eased
formation shape reads as natural rather than sluggish/rubber-banded, whether the micro-idle drift looks
alive vs. twitchy, whether the catch-up band's magnitude is tuned right, or whether sight-cap numbers
actually change contact ranges in a way a playtester notices. Those are judgment calls that only a real
playtest (per this project's own fresh-player-testing law and PLAYTEST gate discipline) can answer. The
probe is a tripwire against regression/deletion of the mechanism, not a feel gate.

One test-authoring risk to flag: `AllyBase.new()` off-tree calls `_ready()` when added to the tree, but
this probe never adds it to the tree (mirrors how `test_flat_damage.gd` avoids scene setup entirely) —
so `_grid`/`_follow_offset` etc. stay at declared defaults, which is exactly what's needed to check
`follow_distance` and the class consts without spinning up `GameManager.player`/`AgentRegistry`. Do not
`add_child()` the probe ally; that would drag in the full squad/registry dependency chain this probe is
designed to avoid.

---

### 5. Breakage a careless implementer will miss

- **`_find_target`'s `closest_dist: float = 60.0` (:459) is doing double duty** — it's simultaneously
  "the sight ceiling" AND "the running nearest-distance tracker" in one variable
  (`if dist < closest_dist: closest_dist = dist; closest_enemy = ...` at :469-472). Once sight cap is
  per-candidate (`SightCap.at(_grid, global_position, enemy_pos)` varies by each enemy's vegetation/flare
  state), that trick breaks — you cannot use a per-enemy cap as both a filter and a shrinking best-so-far.
  Restructure to two variables: `var best_dist: float = INF` (running min) and, per enemy, compute
  `var cap: float = SightCap.at(_grid, global_position, enemy_pos)` then `if dist <= cap and dist < best_dist: ...`.
  A naive find-and-replace of `60.0` for a `SightCap.at(...)` call **inside the existing single-variable
  pattern will silently break "nearest enemy within sight" into "nearest enemy within the LAST enemy
  iterated's sight cap"**, or worse, always use the first candidate's cap for every subsequent compare.
- **Global `move_speed` mutation temptation**: the catch-up band must not write `move_speed` directly —
  every state (`_execute_combat` :682-686, `_execute_seeking_cover` :749-750, `_update_unstick` :57-58)
  reads that same field every frame. A catch-up bump that forgets to revert next frame (e.g. sets
  `move_speed = 8.0` on enter, never resets) permanently speeds up combat movement and strafe, which the
  Devil's Advocate will immediately clock as a stealth/pacing regression outside the stated FOLLOW-only
  scope.
- **`_settle()` is still called from HOLD (:611) and MOVE_TO's arrived branch (:616)** — if the deadzone/
  micro-idle change only touches the FOLLOW arm (per the brief) but `_settle` behavior itself is edited
  in place rather than forked into `_micro_idle`, HOLD and MOVE_TO silently inherit the micro-idle drift
  too, moving allies who are supposed to hold a fixed order position. Fork, don't edit `_settle` in place,
  unless HOLD/MOVE_TO drift is an intended part of this change (brief doesn't say so).
- **`_body_gate_open()` (:421-436) treats `velocity.length_squared() > 0.01` as "trying to move -> stays
  hot."** A micro-idle that intentionally applies a tiny nonzero drift velocity inside the deadzone will
  now **permanently pin the body-gate hot** for every idling ally in formation (drift velocity almost
  certainly exceeds `0.01` squared-length) — defeating the WA-A2 gate's entire point of letting settled
  allies go cold. Keep idle-drift velocity near-zero (well under `sqrt(0.01) ≈ 0.1 m/s`) or the perf
  contract this gate exists for (`CombatManager.bodies_gated`) silently regresses to "no ally in
  formation ever gates."
- **`SightCap` static helper touching `MissionWeather.sight_mult` mid-mission-teardown**: `MissionWeather._exit_tree()` (`mission_weather.gd:196`) resets `sight_mult = 1.0` on teardown, which is fine — but because `sight_mult` is a bare `static var` with no owning-instance guard, any ally think-tick that fires between one mission's teardown and the next mission's `setup()` call will read a stale-but-valid `1.0` (harmless) rather than crash — worth knowing this fails safe, not worth defending against.
