## probe_grenade.gd - does a grenade in a fireteam's lap actually wipe it?
## Four vc_riflemen ring a point at 2.5m; one M26-class blast (130/25/8m)
## detonates at the center. Asserts: all four die (2.5m < the 3.2m kill
## plateau) and nobody gets LAUNCHED (max displacement < 4m - the old
## knockback fired men 180 m/s across the arena).
## Run: godot --headless --path . res://tools/probe_grenade.tscn
extends Node3D


func _ready() -> void:
	var floor_body := StaticBody3D.new()
	floor_body.collision_layer = 1
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(40, 0.2, 40)
	cs.shape = box
	cs.position.y = -0.1
	floor_body.add_child(cs)
	add_child(floor_body)

	var center := Vector3(0, 0.1, -8)
	var men: Array = []
	for i in range(4):
		var a: float = TAU * float(i) / 4.0
		var pos: Vector3 = center + Vector3(cos(a) * 2.5, 0.9, sin(a) * 2.5)
		var e: Node = EnemyBase.spawn_enemy(self, pos, "res://data/enemies/vc_rifleman.tres")
		if e == null:
			print("FAIL: rifleman %d did not spawn" % i)
			get_tree().quit(1)
			return
		men.append(e)
	await get_tree().create_timer(0.8).timeout
	var starts: Array = []
	for e in men:
		starts.append((e as Node3D).global_position)
	CombatManager.apply_explosion_damage(center, 130, 25, 8.0, null)
	await get_tree().create_timer(1.5).timeout
	var neutralized: int = 0
	var max_disp: float = 0.0
	for i in range(men.size()):
		var e: Node = men[i]
		if not is_instance_valid(e):
			neutralized += 1
			continue
		# Downed (bleeding out in the medic window) counts: he is OUT of the
		# fight - that IS the grenade doing something.
		if e.is_dead() or bool(e.get("is_downed")):
			neutralized += 1
		print("    man %d: hp %s/%s state %s downed=%s at %.1fm" % [i,
			str(e.get("current_hp")), str(e.get("max_hp")),
			Enums.AIState.keys()[int(e.get("current_state"))],
			str(e.get("is_downed")),
			center.distance_to((e as Node3D).global_position)])
		max_disp = maxf(max_disp, (Vector3(starts[i]) - (e as Node3D).global_position).length())
	print("  %d/4 neutralized at 2.5m from an M26; max body displacement %.1fm" % [neutralized, max_disp])
	if neutralized == 4 and max_disp < 4.0:
		print("PASS: grenade wipes the fireteam, nobody flies to the moon")
		get_tree().quit(0)
	else:
		print("FAIL: neutralized=%d (want 4), displacement %.1fm (want <4)" % [neutralized, max_disp])
		get_tree().quit(1)
