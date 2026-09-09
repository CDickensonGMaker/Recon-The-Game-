## stall_bench.gd - UNATTENDED STALL BENCH. Reproduces the drop the Summoner sees and
## says what was in it, by name, without needing his hands on the controls.
##
## Why headless is legitimate here, when it is NOT legitimate for an FPS claim: the
## stalls under investigation are main-thread and physics-thread CPU work - crater digs,
## chunk mesh rebuilds, Jolt body swaps, spawns, nav bakes. None of that is the GPU, and
## GPU ms reads zero headless anyway. This bench claims NOTHING about frame rate or GPU;
## it claims WHERE THE MILLISECONDS WENT. The FPS verdict stays the Summoner's walk.
##
## Run: godot --headless --path . res://tests/stall_bench.tscn
## Phases, each reported separately so a cause can be pinned to the thing that caused it:
##   QUIET  - the world just standing there. This is the BASELINE tax.
##   CRATER - explosions dug into the terrain near the player. The raid.
## Every number printed is measured by StallLedger in this process's own clock, per
## frame. No Performance monitor bucket-max is quoted as a per-frame cost.
extends Node

const OP_SEED: int = 47225
const READY_TIMEOUT_S: float = 240.0
const WARMUP_S: float = 6.0
const QUIET_S: float = 8.0
const SPAWN_MEN: int = 30
const CRATERS: int = 6
const CRATER_GAP_S: float = 1.2

var _flow: GameFlow = null
var _world: Node = null


func _ready() -> void:
	StallLedger.enable()
	add_child(FrameSentinel.make(true))
	add_child(FrameSentinel.make(false))
	_flow = GameFlow.new()
	add_child(_flow)
	await get_tree().process_frame
	_flow._begin_operation(OP_SEED, "OPERATION STALL BENCH")
	var waited: float = 0.0
	while waited < READY_TIMEOUT_S:
		if _flow.world != null and _flow.world.is_world_ready and _flow.world.player != null:
			break
		await get_tree().create_timer(0.5).timeout
		waited += 0.5
	if _flow.world == null or _flow.world.player == null:
		print("[STALLBENCH] FAIL: world never became ready in %.0fs" % READY_TIMEOUT_S)
		get_tree().quit(1)
		return
	_world = _flow.world
	print("[STALLBENCH] world ready after %.1fs, seed %d" % [waited, OP_SEED])
	await get_tree().create_timer(WARMUP_S).timeout

	await _phase_quiet()
	await _phase_spawn()
	await _phase_craters()
	print("[STALLBENCH] done")
	get_tree().quit(0)


func _phase_quiet() -> void:
	StallLedger.reset_window()
	await get_tree().create_timer(QUIET_S).timeout
	print("[STALLBENCH] ---- PHASE QUIET (%.0fs, nothing happening) ----" % QUIET_S)
	print(StallLedger.report())
	_print_monitors()


## The siege's arrival cost, without the siege: real men, spawned through the real path,
## one per tick, so the per-man build (model instance + shared anim library merge + 11
## convex hitzone hulls + a Jolt body) is measured where it actually lands.
func _phase_spawn() -> void:
	StallLedger.reset_window()
	var p: Node3D = _world.player as Node3D
	if p == null:
		print("[STALLBENCH] SKIP spawn: no player")
		return
	var base: Vector3 = p.global_position
	for i in range(SPAWN_MEN):
		var ang: float = float(i) * 0.9
		var at: Vector3 = base + Vector3(cos(ang) * 25.0, 0.0, sin(ang) * 25.0)
		var man: Node = EnemyBase.spawn_enemy(_world, at, "res://data/enemies/vc_rifleman.tres")
		if man == null:
			print("[STALLBENCH] spawn %d returned null" % i)
			break
		await get_tree().physics_frame
	await get_tree().create_timer(3.0).timeout
	print("[STALLBENCH] ---- PHASE SPAWN (%d men, one per physics tick) ----" % SPAWN_MEN)
	print(StallLedger.report())
	_print_monitors()


## Craters walked outward from the player, the way a fire mission actually lands: each one
## is a real DamageSystem dig, so it drives the same heightmap edit -> chunk rebuild ->
## collision rebuild -> clutter re-scatter chain the game runs during a raid.
func _phase_craters() -> void:
	StallLedger.reset_window()
	var p: Node3D = _world.player as Node3D
	if p == null:
		print("[STALLBENCH] SKIP craters: no player")
		return
	var base: Vector3 = p.global_position
	for i in range(CRATERS):
		var ang: float = float(i) * 1.7
		var at: Vector3 = base + Vector3(cos(ang) * (12.0 + float(i) * 4.0), 0.0,
			sin(ang) * (12.0 + float(i) * 4.0))
		DamageSystem.apply_damage(at, DamageSystem.DamageType.LARGE_EXPLOSION, 1.0)
		await get_tree().create_timer(CRATER_GAP_S).timeout
	print("[STALLBENCH] ---- PHASE CRATER (%d large explosions) ----" % CRATERS)
	print(StallLedger.report())
	_print_monitors()


func _print_monitors() -> void:
	## Printed for completeness and EXPLICITLY LABELLED: these three are Godot's
	## one-second bucket MAXIMA out of main.cpp, not per-frame costs. They are here to be
	## compared against the per-frame spans above, not to be quoted on their own.
	print("[STALLBENCH]   godot 1s-bucket maxima: idle %.2fms physics %.2fms nav %.2fms | bodies %d pairs %d" % [
		Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
		Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
		Performance.get_monitor(Performance.TIME_NAVIGATION_PROCESS) * 1000.0,
		int(Performance.get_monitor(Performance.PHYSICS_3D_ACTIVE_OBJECTS)),
		int(Performance.get_monitor(Performance.PHYSICS_3D_COLLISION_PAIRS))])
