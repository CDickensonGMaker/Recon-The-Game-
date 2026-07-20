## test_night_sight.gd - darkness lowers the shared AI sight ceiling; a flare lifts
## it back; day is unchanged; both sides read the identical cap.
##
## Proves the SimClock-driven darkness term in SightCap.at (sappers creep in the dark,
## a flare over them is the counter-play). Every assertion has a negative control so it
## cannot pass against both the fix and its absence.
##
## Run: godot --headless --path . res://tests/test_night_sight.tscn
extends Node3D

const ENEMY_DATA := "res://data/enemies/vc_rifleman.tres"
const DAY_HOUR: float = 10.0
const DUSK_HOUR: float = 18.0
const NIGHT_HOUR: float = 21.0

var _failures: int = 0


func _ready() -> void:
	# Isolate darkness from weather: this probe measures time-of-day alone.
	MissionWeather.sight_mult = 1.0
	SimClock.paused = true          # this probe owns the clock; no wall-time drift
	call_deferred("_run")


func _run() -> void:
	print("=== PROBE: NIGHT SIGHT (darkness lowers the cap, a flare lifts it) ===")

	# A flat floor so spawned bodies have something to stand on.
	var floor_body := StaticBody3D.new()
	floor_body.collision_layer = 1
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(400, 1, 400)
	cs.shape = box
	floor_body.add_child(cs)
	add_child(floor_body)
	floor_body.global_position = Vector3(0, -0.5, 0)

	var eye := Vector3(0, 1.6, 0)
	var look := Vector3(0, 1.6, 60)   # 60m downrange - inside every cap tested here

	# ---- 1. DAY is unchanged from today's value (regression guard) ----
	SimClock.sim_hour = DAY_HOUR
	_expect(is_equal_approx(SightCap.darkness_mult(), 1.0),
		"DAY darkness_mult is 1.0 (got %.3f)" % SightCap.darkness_mult())
	var cap_day: float = SightCap.at(null, eye, look)
	_expect(is_equal_approx(cap_day, EnemyBase.SIGHT_CAP_OPEN),
		"DAY open cap == SIGHT_CAP_OPEN %.0f (got %.1f)" % [EnemyBase.SIGHT_CAP_OPEN, cap_day])

	# ---- 2. NIGHT lowers the cap below DAY at the same spot ----
	SimClock.sim_hour = NIGHT_HOUR
	_expect(is_equal_approx(SightCap.darkness_mult(), 0.4),
		"NIGHT darkness_mult is 0.4 (got %.3f)" % SightCap.darkness_mult())
	var cap_night: float = SightCap.at(null, eye, look)
	_expect(cap_night < cap_day - 1.0,
		"NIGHT cap %.1f is BELOW DAY cap %.1f (the sapper's dark)" % [cap_night, cap_day])
	_expect(is_equal_approx(cap_night, EnemyBase.SIGHT_CAP_OPEN * 0.4),
		"NIGHT open cap == 140*0.4 = %.1f (got %.1f)" % [EnemyBase.SIGHT_CAP_OPEN * 0.4, cap_night])

	# DUSK sits between - twilight is partial, not full dark.
	SimClock.sim_hour = DUSK_HOUR
	var cap_dusk: float = SightCap.at(null, eye, look)
	_expect(cap_night < cap_dusk and cap_dusk < cap_day,
		"DUSK cap %.1f sits between NIGHT %.1f and DAY %.1f" % [cap_dusk, cap_night, cap_day])

	# ---- 3. A flare over the look-point lifts the NIGHT cap back up ----
	# NEGATIVE CONTROL first: without a flare, night stays dark (proves the lift below
	# is doing the work, not some ambient state).
	SimClock.sim_hour = NIGHT_HOUR
	var cap_night_unlit: float = SightCap.at(null, eye, look)
	_expect(cap_night_unlit < cap_day - 1.0,
		"CONTROL: NIGHT with NO flare stays dark (%.1f < %.1f)" % [cap_night_unlit, cap_day])

	var flare: IllumFlare = IllumFlare.pop(self, look)
	await get_tree().process_frame   # let the flare register in active_flares
	_expect(IllumFlare.is_lit(look), "flare is lit over the look-point")
	var cap_night_lit: float = SightCap.at(null, eye, look)
	_expect(cap_night_lit > cap_night_unlit + 1.0,
		"FLARE lifts the NIGHT cap: %.1f > unlit %.1f (the counter-play)" % [cap_night_lit, cap_night_unlit])
	_expect(is_equal_approx(cap_night_lit, EnemyBase.SIGHT_CAP_OPEN * 0.9),
		"flare lifts to 0.9 (artificial light, not sun): %.1f (got %.1f)" % [EnemyBase.SIGHT_CAP_OPEN * 0.9, cap_night_lit])
	if is_instance_valid(flare):
		flare.queue_free()
	await get_tree().process_frame

	# ---- 4. SYMMETRY: enemy and ally read the IDENTICAL cap for identical inputs ----
	# Both call sites pass (grid, own_pos, target) to the same side-free SightCap.at with
	# NO per-side scaling: enemy_base.gd:694 (_sight_cap) and ally_base.gd:545 (inline).
	# Spawn both real bodies at one spot and compare. A side that scaled its own cap
	# (the Fairness-Law violation this guards) would diverge here.
	SimClock.sim_hour = NIGHT_HOUR
	var spot := Vector3(20, 1.0, 0)
	var enemy: EnemyBase = EnemyBase.spawn_enemy(self, spot, ENEMY_DATA)
	var ally: AllyBase = AllyBase.spawn_ally(self, spot)
	await get_tree().process_frame

	# Enemy's real accessor must equal the shared authority at its OWN position (this is
	# what bites if enemy_base.gd:694 is ever changed to scale the cap).
	var enemy_cap: float = enemy._sight_cap(look)
	var authority_at_enemy: float = SightCap.at(enemy._grid, enemy.global_position, look)
	_expect(is_equal_approx(enemy_cap, authority_at_enemy),
		"enemy routes through the shared cap unmodified (%.2f == %.2f)" % [enemy_cap, authority_at_enemy])

	# Ally's line (SightCap.at(grid, ally.global_position, epos)) reproduced on the real
	# ally node, compared to the enemy at the same spot -> must be identical.
	var ally_cap: float = SightCap.at(null, ally.global_position, look)
	_expect(enemy.global_position.distance_to(ally.global_position) < 0.01,
		"symmetry premise: enemy and ally at the same spot (%.2fm apart)" % enemy.global_position.distance_to(ally.global_position))
	_expect(is_equal_approx(enemy_cap, ally_cap),
		"enemy cap == ally cap for identical inputs (%.2f == %.2f)" % [enemy_cap, ally_cap])

	print("")
	if _failures == 0:
		print("=== PROBE PASS ===")
		get_tree().quit(0)
	else:
		push_error("NIGHT SIGHT: %d assertion(s) failed." % _failures)
		print("=== PROBE FAIL (%d) ===" % _failures)
		get_tree().quit(1)


func _expect(ok: bool, what: String) -> void:
	print(("  PASS  " if ok else "  FAIL  ") + what)
	if not ok:
		_failures += 1
