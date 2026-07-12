## probe_physics_ab.gd - JOLT vs GODOT PHYSICS, measured on this machine.
##
## Headless ON PURPOSE: no renderer, so the number is the SOLVER and nothing
## else. The load is the game's own worst case - a firefight that just ended:
##   24 live CharacterBody3D enemies running move_and_slide + AI every tick
##   8 concurrent ragdolls (13 PhysicalBone3D each, jointed = ~104 bodies)
##   150 rigid bodies (gibs/debris) piling on the deck
## Reports mean/95th-percentile physics tick cost, which is the thing Jolt is
## supposed to move.
##   godot --headless --path . -s res://tools/probe_physics_ab.gd
extends SceneTree

const ENEMIES: int = 24
const DEBRIS: int = 150
const SETTLE_S: float = 3.0     ## let the AI wake and the bodies drop
const SAMPLE_S: float = 8.0     ## measurement window

var _samples: Array[float] = []


func _initialize() -> void:
	var engine_name: String = str(ProjectSettings.get_setting("physics/3d/physics_engine", "Godot Physics"))
	print("\n=== PHYSICS A/B: %s ===" % engine_name)
	_floor()
	# The fireteam: real enemies, real AI, real move_and_slide every tick.
	for i in range(ENEMIES):
		var x: float = float(i % 6) * 2.5 - 7.0
		var z: float = float(i / 6) * 2.5 - 20.0
		EnemyBase.spawn_enemy(root, Vector3(x, 1.0, z), "res://data/enemies/vc_rifleman.tres")
	# The debris field: gibs and wreckage the solver has to keep apart.
	for i in range(DEBRIS):
		var b := RigidBody3D.new()
		b.collision_layer = 1
		b.collision_mask = 1
		var cs := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(0.22, 0.22, 0.22)
		cs.shape = box
		b.add_child(cs)
		root.add_child(b)
		b.global_position = Vector3(
			randf_range(-8.0, 8.0), 2.0 + float(i) * 0.06, randf_range(-20.0, -4.0))
	await create_timer(1.0).timeout

	# Kill them all: every ragdoll slot fills, gore spawns, corpses settle.
	var killed: int = 0
	for e in root.get_tree().get_nodes_in_group("enemies"):
		var eb := e as EnemyBase
		if eb != null and not eb.is_dead():
			eb.take_damage(999, Enums.DamageType.PHYSICAL, null, "BODY")
			killed += 1
	print("  load: %d enemies (%d killed -> ragdolls + gore), %d rigid bodies" % [
		ENEMIES, killed, DEBRIS])

	await create_timer(SETTLE_S).timeout
	var t0: float = float(Time.get_ticks_msec())
	while float(Time.get_ticks_msec()) - t0 < SAMPLE_S * 1000.0:
		await physics_frame
		_samples.append(float(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)) * 1000.0)

	_samples.sort()
	var n: int = _samples.size()
	var sum: float = 0.0
	for s in _samples:
		sum += s
	var mean: float = sum / maxf(1.0, float(n))
	var p95: float = _samples[mini(n - 1, int(float(n) * 0.95))]
	var worst: float = _samples[n - 1]
	print("  ticks sampled     : %d" % n)
	print("  physics MEAN      : %.3f ms" % mean)
	print("  physics P95       : %.3f ms" % p95)
	print("  physics WORST     : %.3f ms" % worst)
	print("RESULT %s mean=%.3f p95=%.3f worst=%.3f" % [engine_name, mean, p95, worst])
	quit(0)


func _floor() -> void:
	var f := StaticBody3D.new()
	f.collision_layer = 1
	f.collision_mask = 0
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(60, 0.4, 60)
	cs.shape = box
	cs.position = Vector3(0, -0.2, -12)
	f.add_child(cs)
	root.add_child(f)
