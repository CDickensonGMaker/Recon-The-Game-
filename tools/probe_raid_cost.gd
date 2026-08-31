## probe_raid_cost.gd - WHAT DOES A RAID ACTUALLY COST THE CPU?
##
## The crucible's FIRES phase cannot answer this: the arena fights on its own, so
## FIRES frame times carry its spawns and mid-run model loads too. Measured
## 2026-08-31 with --raid-only, BASELINE came in at 45.42 ms avg / 36 hitches and
## FIRES at 41.57 / 30 - the raid phase was CHEAPER than the quiet one, which means
## a frame-time instrument cannot see the ordnance at all.
##
## So time the raid path DIRECTLY, in usec, against the arena's live population and
## real colliders. Attribution, not frame feel.
##
## Run: <godot> --headless --path . res://tools/probe_raid_cost.tscn -- --test-save
extends Node

const ArenaScene := preload("res://scenes/levels/ai_stress_arena.tscn")
const SETTLE_S: float = 8.0
const SAMPLES: int = 12

var _arena: Node = null


func _ready() -> void:
	_arena = ArenaScene.instantiate()
	_arena.set("spawn_player", true)
	_arena.set("spawn_hud", false)
	_arena.set("hot_start", false)
	add_child(_arena)
	await get_tree().process_frame
	await get_tree().create_timer(SETTLE_S).timeout

	print("\n=== RAID COST PROBE (headless CPU usec) ===")
	print("population: enemies=%d allies=%d civilians=%d props=%d" % [
		AgentRegistry.enemies.size(), AgentRegistry.allies.size(),
		AgentRegistry.civilians.size(), AgentRegistry.props.size()])

	var centre := Vector3(0.0, 0.0, -30.0)
	var tm: TerrainManager = _arena.get("terrain") as TerrainManager

	# --- 0. THE COLD PATH. The FIRST explosion in a world measured 65.040 ms while
	# steady state is 0.142. Name which subsystem pays it instead of preloading blind.
	_cold(centre, tm)

	# --- 1. THE BLAST RESOLUTION, per call, at each ordnance's real parameters.
	# This is what every bomblet and every canister runs on impact.
	_time_blast("CBU bomblet  (55/15, r5.0)", centre, 55, 15, FirePlan.CBU_BOMBLET_BLAST_M)
	_time_blast("napalm can   (90/30, r30.0)", centre, 90, 30, FirePlan.NAPALM_BLAST_M)
	_time_blast("arty shell   (120/40, r14.0)", centre, 120, 40, FirePlan.ARTY_BLAST_M)

	# --- 2. THE DISPENSER OPEN: CBU_BOMBLETS projectiles born in ONE call.
	# Sampled: single shots of this varied 5.96-11.74 ms for the identical call.
	var from := centre + Vector3.UP * 60.0
	await _time_open(tm, from, centre)

	print("\nnodes now %d" % int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)))
	print("PROBE done")
	get_tree().quit(0)


## First-call cost of each subsystem the blast path touches, in the order a cold
## world meets them. Whichever line is large IS the 65 ms.
func _cold(centre: Vector3, tm: TerrainManager) -> void:
	var ss: PhysicsDirectSpaceState3D = get_tree().root.get_world_3d().direct_space_state
	var t: int = Time.get_ticks_usec()
	var q := PhysicsRayQueryParameters3D.create(centre + Vector3.UP * 3.0, centre)
	ss.intersect_ray(q)
	print("%-30s %8.3f ms" % ["  cold: first raycast", float(Time.get_ticks_usec() - t) / 1000.0])

	t = Time.get_ticks_usec()
	TreeBreakSystem.apply_blast(centre, 5.0)
	print("%-30s %8.3f ms" % ["  cold: TreeBreakSystem", float(Time.get_ticks_usec() - t) / 1000.0])

	t = Time.get_ticks_usec()
	CombatManager.apply_suppression_in_area(centre, 12.0, 0.5)
	print("%-30s %8.3f ms" % ["  cold: suppression", float(Time.get_ticks_usec() - t) / 1000.0])

	t = Time.get_ticks_usec()
	FireHazard.create_at(get_tree().current_scene, centre + Vector3(200.0, 0.0, 200.0), 4.0, 3.0)
	print("%-30s %8.3f ms" % ["  cold: FireHazard.create_at", float(Time.get_ticks_usec() - t) / 1000.0])

	t = Time.get_ticks_usec()
	GunFX.play_explosion_3d(get_tree().current_scene, centre + Vector3(200.0, 0.0, 210.0), "explosion_grenade")
	print("%-30s %8.3f ms" % ["  cold: GunFX explosion", float(Time.get_ticks_usec() - t) / 1000.0])

	var data: ProjectileData = load("res://data/projectiles/cbu_bomblet.tres") as ProjectileData
	t = Time.get_ticks_usec()
	if data:
		Ballistics.fire_arc(data, centre + Vector3.UP * 40.0, centre, 2.0, tm, func(_i: Vector3) -> void: pass)
	print("%-30s %8.3f ms" % ["  cold: first fire_arc", float(Time.get_ticks_usec() - t) / 1000.0])


func _time_blast(label: String, centre: Vector3, maxd: int, mind: int, radius: float) -> void:
	var best: int = 1 << 30
	var worst: int = 0
	var total: int = 0
	for i in range(SAMPLES):
		var t0: int = Time.get_ticks_usec()
		CombatManager.apply_explosion_damage(centre, maxd, mind, radius, null)
		var us: int = Time.get_ticks_usec() - t0
		total += us
		best = mini(best, us)
		worst = maxi(worst, us)
	var avg: float = float(total) / float(SAMPLES) / 1000.0
	print("%-30s avg %7.3f ms   min %7.3f   max %7.3f" % [
		label, avg, float(best) / 1000.0, float(worst) / 1000.0])


## The dispenser open. Two things must be reported together, or the frame-spread
## fix reads as a fake win: the WORST SINGLE-FRAME BLOCK (the largest contiguous
## run of main-thread work the split imposes on one frame - which is the whole call
## when it is synchronous, and one chunk when it is spread), AND the total bomblets
## actually born, so a "saving" that is really a silent loss cannot hide.
func _time_open(tm: TerrainManager, from: Vector3, centre: Vector3) -> void:
	var best: int = 1 << 30
	var worst: int = 0
	var total: int = 0
	var born_total: int = 0
	var shape: PackedStringArray = []
	for i in range(SAMPLES):
		var t0: int = Time.get_ticks_usec()
		CASAirplane._open_cluster_at(get_tree(), tm, Vector3.RIGHT, from, centre)
		var us: int = Time.get_ticks_usec() - t0
		total += us
		best = mini(best, us)
		worst = maxi(worst, us)
		# Let any spread finish before the next sample, so blocks never overlap.
		for f in range(8):
			await get_tree().process_frame
	var avg: float = float(total) / float(SAMPLES) / 1000.0
	print("%-30s avg %7.3f ms   min %7.3f   max %7.3f   (worst single-frame block)" % [
		"CBU one can (open)", avg, float(best) / 1000.0, float(worst) / 1000.0])

	# ONE isolated can, counted frame by frame. A spread that drops bomblets would
	# read as a saving here, so the count is reported beside the milliseconds.
	# The arena dispatches its OWN fire support; a CBU of its own landing inside the
	# count window reads as extra births (observed: 32 for a 16-bomblet can). Gag the
	# director for the window so the number belongs to this call alone.
	var fd: FieldDirector = _arena.get("_field_director") as FieldDirector
	if fd != null:
		fd._cas_cooldown = 9999.0
	await get_tree().process_frame
	CASAirplane._open_cluster_at(get_tree(), tm, Vector3.RIGHT, from, centre)
	born_total = _bomblets_this_frame()
	shape = PackedStringArray([str(born_total)])
	for f in range(10):
		await get_tree().process_frame
		var n: int = _bomblets_this_frame()
		if n > 0:
			shape.append(str(n))
			born_total += n
	print("%-30s %d bomblets born (authored %d)   frame shape: %s" % [
		"  births", born_total, FirePlan.CBU_BOMBLETS, "/".join(shape)])


## SpawnLedger only CLEARS its counts when note() is next called, so a frame in
## which nothing spawned still reports the previous frame's numbers. Reading it
## without this guard made a 16-bomblet can report 44 births across 11 idle frames
## - the same stale-read class that made the 2026-08-14 attribution run blame the
## airstrike for a burst that was men. Trust the counts only on their own frame.
func _bomblets_this_frame() -> int:
	if SpawnLedger._frame != Engine.get_process_frames():
		return 0
	return int(SpawnLedger._counts.get("cbu_bomblet", 0))
