## probe_ally_muzzle_fx.gd - item 29. A squadmate's muzzle flash must hang on the
## model's rendered muzzle, not on the ballistic ray origin. The two diverge
## whenever the aim leads the body's facing, which is most of a firefight.
## Measures the ACTUAL flash node GunFX drops into the scene.
## Run: godot --headless --path . res://tests/probe_ally_muzzle_fx.tscn
extends Node

const TOL_M: float = 0.05

var _fails: int = 0


func _ready() -> void:
	print("=== ALLY MUZZLE FX PROBE (item 29) ===")
	await get_tree().process_frame
	var ally: AllyBase = AllyBase.spawn_ally(self, Vector3.ZERO)
	ally.set_sprite("us_grunt_rifleman", "m16a1")
	ally.weapon_data = load("res://data/weapons/m16a1.tres") as WeaponData
	ally.weapons_free = true
	await get_tree().process_frame
	await get_tree().process_frame

	var actor: Node3D = ally.sprite_actor
	if actor == null or not actor.has_method("set_facing"):
		print("[SKIP] no ModelActor on the ally - nothing to measure")
		get_tree().quit(1)
		return
	# Body faces +Z, the man shoots +X: 90 degrees of divergence, the exact case
	# that tore the flash off the gun.
	actor.call("set_facing", Vector3(0, 0, 1))
	var aim := Vector3(1, 0, 0)
	ally.current_aim_dir = aim

	var target := CharacterBody3D.new()
	add_child(target)
	target.global_position = aim * 40.0
	ally.target = target
	ally.target_visible_duration = 10.0

	var ballistic: Vector3 = ally.get_muzzle_position(aim)
	var visual: Vector3 = ally.get_muzzle_visual(aim)
	var spread: float = ballistic.distance_to(visual)
	print("[PROBE] ballistic=%s visual=%s divergence=%.3fm" % [str(ballistic), str(visual), spread])
	if spread < 0.2:
		_fail("facing/aim did not diverge - the probe cannot tell the two apart")

	var before: Array[Node] = get_children()
	ally.call("_fire_at_target")
	await get_tree().process_frame
	var flash: Node3D = null
	for c in get_children():
		if c in before:
			continue
		var n3 := c as Node3D
		if n3 != null and n3.get_child_count() > 0 and n3.get_child(0) is MeshInstance3D:
			flash = n3
			break
	if flash == null:
		_fail("no muzzle flash node was spawned - the ally never fired")
	else:
		var at: Vector3 = flash.global_position
		var d_vis: float = at.distance_to(visual)
		var d_bal: float = at.distance_to(ballistic)
		print("[PROBE] flash at %s  d(visual)=%.3f  d(ballistic)=%.3f" % [str(at), d_vis, d_bal])
		if d_vis > TOL_M:
			_fail("flash is %.3fm off the model's muzzle (item 29: it hangs in the air)" % d_vis)
		if d_bal <= TOL_M:
			_fail("flash sits on the ballistic origin - the fix is not in effect")

	print("=== %s ===" % ("PASS" if _fails == 0 else "FAIL (%d)" % _fails))
	get_tree().quit(0 if _fails == 0 else 1)


func _fail(msg: String) -> void:
	_fails += 1
	print("[FAIL] %s" % msg)
