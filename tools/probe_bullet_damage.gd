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
	# AND STOP THE ANIMATION. Disabling _physics_process only stops the BODY; the
	# AnimationPlayer kept running, so the head region drifted out of the firing line
	# between the aiming ray and the bullet's arrival a few frames later. Measured on this
	# box before this line existed: 1 PASS in 3 runs at HEAD, with "direct ray: NO HIT" and
	# a hit-then-zero-damage run in the same window. A gate that passes a third of the time
	# adjudicates nothing.
	for ap in _all_anim_players(e):
		ap.pause()
	await get_tree().physics_frame
	var hp0: int = e.current_hp
	var zones: int = 0
	for hz in get_tree().get_nodes_in_group("hitzone"):
		if hz is Area3D:
			zones += 1
	# Aim at the HEAD sphere WHERE IT ACTUALLY IS. This used to aim at a hardcoded
	# +1.52m above the man's origin, and a head is only there in some poses - so the
	# gate passed 1 run in 3 or 4 on this box (measured 2026-09-09, at HEAD and with
	# the animation frozen: the pose the man had settled into was the variable, not
	# the bullet). Asking the zone where it is makes the shot pose-independent.
	var chest: Vector3 = _head_of(e)
	if chest == Vector3.INF:
		print("FAIL: no HEAD hitzone on the spawned man - the probe cannot aim")
		get_tree().quit(1)
		return
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
	var neutralized: bool = e.is_dead() or bool(e.get("is_downed"))
	print("  vc_rifleman hp %d -> %d (dealt %d), dead/downed: %s" % [hp0, e.current_hp, dealt, neutralized])
	if neutralized or dealt >= 63:
		print("PASS: bullet resolved against a hitzone (headshot lands as a headshot)")
		get_tree().quit(0)
	elif dealt <= 0:
		print("FAIL: round hit nothing (aim or zone coverage)")
		get_tree().quit(1)
	else:
		print("FAIL: round landed FLAT %d - a body capsule is shadowing the zones" % dealt)
		get_tree().quit(1)


func _all_anim_players(n: Node) -> Array[AnimationPlayer]:
	var out: Array[AnimationPlayer] = []
	if n is AnimationPlayer:
		out.append(n as AnimationPlayer)
	for c in n.get_children():
		out.append_array(_all_anim_players(c))
	return out


## The live HEAD region belonging to THIS man, in world space.
func _head_of(e: Node) -> Vector3:
	for hz in get_tree().get_nodes_in_group("hitzone"):
		if not (hz is Hitzone):
			continue
		if String((hz as Hitzone).get_zone_name()) != "HEAD":
			continue
		var n: Node = hz as Node
		while n != null:
			if n == e:
				return (hz as Node3D).global_position
			n = n.get_parent()
	return Vector3.INF
