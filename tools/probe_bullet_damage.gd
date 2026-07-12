## probe_bullet_damage.gd - does a fired round actually reach the hitzones?
## Spawns a REAL vc_rifleman (70hp, body capsule on the enemies layer), fires
## one M16 BulletSystem round at his chest from 6m with the player's fire
## mask, and asserts the arrival damage carried the TORSO x2.5 multiplier
## (28 x 2.5 = 70 = dead in one). With a body layer wrongly in the mask the
## capsule shadows the zones and the same round lands flat 28 (the "shooting
## people and they aren't dying" bug).
## Run: godot --headless --path . res://tools/probe_bullet_damage.tscn
extends Node3D


func _ready() -> void:
	var floor_body := StaticBody3D.new()
	floor_body.collision_layer = 1
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(30, 0.2, 30)
	cs.shape = box
	cs.position.y = -0.1
	floor_body.add_child(cs)
	add_child(floor_body)

	var e: Node = EnemyBase.spawn_enemy(self, Vector3(0, 1.0, -6.0), "res://data/enemies/vc_rifleman.tres")
	if e == null:
		print("FAIL: vc_rifleman did not spawn")
		get_tree().quit(1)
		return
	await get_tree().create_timer(0.8).timeout  # zones built, model settled
	(e as Node3D).set_physics_process(false)    # hold still for the range shot
	var hp0: int = e.current_hp
	var zones: int = 0
	for hz in get_tree().get_nodes_in_group("hitzone"):
		if hz is Area3D:
			zones += 1
	var chest: Vector3 = (e as Node3D).global_position + Vector3(0, 1.25, 0)
	print("  enemy at %s, %d hitzones live, aiming at %s" % [(e as Node3D).global_position, zones, chest])
	var q := PhysicsRayQueryParameters3D.create(Vector3(0, chest.y, 0), chest + Vector3(0, 0, -2), 1 | 32 | 64)
	q.collide_with_areas = true
	var pre: Dictionary = get_world_3d().direct_space_state.intersect_ray(q)
	if pre.is_empty():
		print("  direct ray: NO HIT")
	else:
		print("  direct ray hit: %s (zone %s)" % [pre.collider,
			str((pre.collider as Hitzone).get_zone_name()) if pre.collider is Hitzone else "-"])
	var wd: WeaponData = load("res://data/weapons/m16a1.tres")
	CombatManager.bullets.fire(wd, null, Vector3(0, chest.y, 0),
		(chest - Vector3(0, chest.y, 0)).normalized(), 1 | 32 | 64, [], false)
	await get_tree().create_timer(0.5).timeout
	var dealt: int = hp0 - e.current_hp
	print("  vc_rifleman hp %d -> %d (dealt %d; flat M16 = 28, torso x2.5 = 70)" % [hp0, e.current_hp, dealt])
	if dealt >= 63:  # x2.25 gut graze or better - the multiplier reached the round
		print("PASS: bullet resolved against a hitzone (multiplier applied)")
		get_tree().quit(0)
	elif dealt <= 0:
		print("FAIL: round hit nothing (aim or zone coverage)")
		get_tree().quit(1)
	else:
		print("FAIL: round landed FLAT %d - a body capsule is shadowing the zones" % dealt)
		get_tree().quit(1)
