## test_siege.gd - ADR-035's gate probe. Every check targets a mechanism the War
## Room proved was BROKEN or ABSENT in the rev.1 design, because those are the only
## places this feature can silently not work:
##
##   1. THE LEDGER. EnemySquad._strength counts nodes in the `enemies` group, so a
##      dormant cell reads as zero men. Reusing it would replenish `live` as cells
##      arrived and the break would never fire - every siege ending on the stopwatch.
##   2. THE THRESHOLD. break_state had no threshold parameter; 0.575 was reachable
##      only through avg_courage 0.1875, which makes every besieger a coward.
##   3. THE REAP. EnemyBase had no despawn path at all and _execute_retreating has no
##      destination, so survivors became permanent full-cost ghosts.
##   4. THE BLIND CLOCK. target_last_seen_time never advanced for a man holding no
##      target, so INVESTIGATE never expired and the hunt anchor walked him through
##      the compound and 130m out the far side.
##
## Run: godot --headless --path . res://tests/test_siege.tscn
extends Node

var _failures := 0


func _ready() -> void:
	_check_ledger_counts_dormant()
	_check_break_threshold_band()
	_check_cells_are_homogeneous_and_sized()
	await _check_reap_frees_survivors()
	_check_withdrawal_disarms_satchels()
	_check_blind_clock_runs_without_target()
	_check_run_pool_carries()
	if _failures == 0:
		print("test_siege: PASS")
	else:
		print("test_siege: %d FAILURES" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


func _fail(msg: String) -> void:
	print("FAIL: ", msg)
	_failures += 1


## 1 ------------------------------------------------------------------ THE LEDGER.
## A dormant cell must report its paper strength. The negative control is the shipped
## squad ledger, which answers zero for the same men - that difference IS the bug.
func _check_ledger_counts_dormant() -> void:
	var d := _bare_director(Vector3(20000, 0, 0))
	d._attach_siege()
	d.siege.open_siege(24)

	if d.siege.live_strength() != 24:
		_fail("a fully dormant 24-man siege counted %d live - the ledger cannot see unmaterialized men"
			% d.siege.live_strength())

	# NEGATIVE CONTROL: the group the squad ledger would scan is empty, so the
	# rejected design really would have read this assault as zero strength.
	var in_group := 0
	for c in d.siege.cells:
		for m in c.men:
			if is_instance_valid(m):
				in_group += 1
	if in_group != 0:
		_fail("dormant cells put %d bodies in the world - they are supposed to hold none" % in_group)

	# Materializing must not change the total: the same men, now real.
	for c in d.siege.cells:
		c.materialize()
	if d.siege.live_strength() != 24:
		_fail("after materializing, strength read %d instead of 24 - the count double-books"
			% d.siege.live_strength())
	d.queue_free()


## 2 -------------------------------------------------------------- THE THRESHOLD.
## The break must land inside the decreed 40-50% band, and it must get there through
## the base_ratio rather than by making the men cowards.
func _check_break_threshold_band() -> void:
	var courage := 0.5
	var at_40: Dictionary = EnemySquad.break_state(60, 100, courage, SiegeDirector.BREAK_BASE_RATIO)
	var at_50: Dictionary = EnemySquad.break_state(50, 100, courage, SiegeDirector.BREAK_BASE_RATIO)
	if bool(at_40.broken):
		_fail("the siege broke at only 40%% killed - below the decreed band")
	if not bool(at_50.broken):
		_fail("the siege had NOT broken at 50%% killed - above the decreed band")

	# NEGATIVE CONTROL: the shipped default must be untouched by the new parameter,
	# or every ambush and camp fight in the game silently retunes.
	var shipped: Dictionary = EnemySquad.break_state(50, 100, courage)
	if bool(shipped.broken):
		_fail("the DEFAULT break now fires at 50%% killed - the siege ratio leaked into every fight")
	if absf(float(shipped.threshold) - EnemySquad.BREAK_RATIO) > 0.001:
		_fail("the default threshold moved to %.3f - shipped fights are retuned" % float(shipped.threshold))


## 3 ------------------------------------------------- cells are 3-6 of ONE type.
func _check_cells_are_homogeneous_and_sized() -> void:
	var d := _bare_director(Vector3(21000, 0, 0))
	d._attach_siege()
	d.siege.open_siege(50)
	var total := 0
	for c in d.siege.cells:
		total += c.strength
		if c.strength < SiegeDirector.CELL_MIN or c.strength > SiegeDirector.CELL_MAX:
			_fail("a cell fielded %d men - outside the ruled %d-%d"
				% [c.strength, SiegeDirector.CELL_MIN, SiegeDirector.CELL_MAX])
		if c.data_path.is_empty():
			_fail("a cell has no type - a homogeneous cell must hold exactly one EnemyData")
	if total != 50:
		_fail("cells account for %d of 50 rolled men - the assault loses men to rounding" % total)
	d.queue_free()


## 4 --------------------------------------------------------------- THE REAP.
## The finding all four architects reached independently: nothing in this codebase
## removes a LIVING enemy. A broken siege must return the roster to where it started.
func _check_reap_frees_survivors() -> void:
	var d := _bare_director(Vector3(22000, 0, 0))
	d._attach_siege()
	var before: int = d._live_enemies.size()
	d.siege.open_siege(12)
	for c in d.siege.cells:
		c.materialize()
	if d._live_enemies.size() <= before:
		_fail("materializing 12 men did not put anyone on the roster")

	d.siege._break_siege("broken")
	if d.siege._reaping.is_empty():
		_fail("the break collected nobody to withdraw - survivors are simply abandoned")

	# The timeout is the backstop that guarantees termination even if a man never
	# reaches his rally. Drive it rather than waiting 90 real seconds.
	d.siege._process_reap(SiegeDirector.REAP_TIMEOUT_S + 1.0)
	await get_tree().process_frame
	await get_tree().process_frame
	if d._live_enemies.size() != before:
		_fail("after the reap %d men are still on the roster - these are the permanent ghosts"
			% (d._live_enemies.size() - before))
	if not d.siege._reaping.is_empty():
		_fail("the reap left %d men in its own queue - it never terminates"
			% d.siege._reaping.size())

	# A withdrawal is NOT a casualty: nothing may have scored these men as kills.
	if d.state.kills != 0:
		_fail("the reap scored %d kills - withdrawing men were counted as killed" % d.state.kills)
	d.queue_free()


## 5 ------------------------------------------ a withdrawing sapper must not blow.
## SapperCharge tests its OWN target_pos, so a man walking out across his old aim
## point detonates on the way - and _detonate clears the objective the reap just set.
func _check_withdrawal_disarms_satchels() -> void:
	var d := _bare_director(Vector3(23000, 0, 0))
	d._attach_siege()
	d.siege.open_siege(8)
	var carried := 0
	for c in d.siege.cells:
		if c.data_path == SiegeDirector.SAPPER_DATA:
			c.materialize()
			for m in c.men:
				for ch in m.get_children():
					if ch is SapperCharge:
						carried += 1
	if carried == 0:
		_fail("no sapper carried a charge before the break - check 5 proves nothing")

	d.siege._break_siege("broken")
	var still_armed := 0
	for m in d.siege._reaping:
		if not is_instance_valid(m):
			continue
		for ch in m.get_children():
			if ch is SapperCharge:
				still_armed += 1
	if still_armed > 0:
		_fail("%d withdrawing sappers still carry a live satchel - they will detonate on the way out"
			% still_armed)
	d.queue_free()


## 6 -------------------------------------------------------- THE BLIND CLOCK.
## The live defect behind attackers walking through the compound: with no target the
## LOS pass returned early and never advanced the blind clock, so INVESTIGATE never
## expired. Verifies the clock RUNS for a man who holds nobody.
func _check_blind_clock_runs_without_target() -> void:
	var e := EnemyBase.spawn_enemy(self, Vector3(24000, 0, 0), SiegeDirector.REGULAR_DATA)
	e.target = null
	e.target_last_seen_time = 0.0
	e._update_line_of_sight()
	if e.target_last_seen_time <= 0.0:
		_fail("a man holding NO target did not advance his blind clock - INVESTIGATE never expires")
	var first := e.target_last_seen_time
	e._update_line_of_sight()
	if e.target_last_seen_time <= first:
		_fail("the blind clock stalled after one tick - it must keep running")
	e.queue_free()


## 7 ------------------------------- the run pool carries; a wipe ends the run.
func _check_run_pool_carries() -> void:
	var d := _bare_director(Vector3(25000, 0, 0))
	d._attach_siege()
	d.siege.open_siege(30)
	for c in d.siege.cells:
		c.materialize()
	# Kill four men, then break: night 2 must field the survivors, not a fresh d50.
	var killed := 0
	for c in d.siege.cells:
		for m in c.men:
			if killed >= 4:
				break
			if is_instance_valid(m):
				m.take_damage(99999, Enums.DamageType.EXPLOSIVE, null)
				killed += 1
	var survivors: int = d.siege.live_strength()
	d.siege._break_siege("broken")
	if d.siege.run_strength != survivors:
		_fail("night 2 would field %d men, not the %d who survived night 1"
			% [d.siege.run_strength, survivors])
	if d.siege.run_peak != 30:
		_fail("the run peak drifted to %d - it must stay fixed at the rolled strength"
			% d.siege.run_peak)
	if d.siege.nights_run != 1:
		_fail("a broken siege counted %d nights of the run" % d.siege.nights_run)

	# A WIPE ends the run outright - there is nobody left to come back.
	var w := _bare_director(Vector3(26000, 0, 0))
	w._attach_siege()
	w.siege.open_siege(6)
	w.siege._break_siege("wiped")
	if w.siege.nights_run < SiegeDirector.MAX_RUN_NIGHTS:
		_fail("a wiped assault left the run open - night 2 would arrive with nobody")
	d.queue_free()
	w.queue_free()


## A FieldDirector with just enough world to roll and spawn. Hand-built, never
## through GameFlow (game_flow.gd already starts an operation - a second one builds
## two worlds and doubles every count).
func _bare_director(center: Vector3) -> FieldDirector:
	for prior in get_tree().get_nodes_in_group("mission_director"):
		prior.remove_from_group("mission_director")
	var d := FieldDirector.new()
	add_child(d)
	d.add_to_group("mission_director")
	var w := GameWorld.new()
	# No terrain at all, so spawn_tracked_enemy skips the terrain seat instead of
	# sampling an empty heightmap out of bounds.
	w.build_terrain_on_ready = false
	add_child(w)
	var pl := CharacterBody3D.new()
	w.add_child(pl)
	pl.global_position = center
	w.player = pl
	d.world = w
	d.fsb_center = center
	d.siege_aim = center + Vector3(0, 0, 8)
	d.patrol_gate_pos = center + Vector3(0, 0, 60)
	d.patrol_gate_out = Vector3.BACK
	d.patrol_count = 1
	return d
