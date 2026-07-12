## probe_brush.gd - does lead go THROUGH the bush?
## A man stands behind a thatch/bamboo wall (group "soft_cover"). We shoot him
## with the M16 and with 00 buck, and we shoot a second man behind a BUNKER wall
## (hard). Concealment must not be cover - and buckshot, nine 0.33in balls, must
## punch the brush best of all (the historical reason a point man carried one).
##   godot --headless --path . res://tools/probe_brush.tscn
extends Node3D


func _ready() -> void:
	_floor()
	_wall(Vector3(0, 1.2, -8.0), true)     # soft: thatch/bamboo
	_wall(Vector3(20, 1.2, -8.0), false)   # hard: bunker
	await get_tree().create_timer(0.4).timeout

	var m16: WeaponData = load("res://data/weapons/m16a1.tres")
	var soft_man: Node = EnemyBase.spawn_enemy(self, Vector3(0, 0.2, -12.0), "res://data/enemies/vc_rifleman.tres")
	var hard_man: Node = EnemyBase.spawn_enemy(self, Vector3(20, 0.2, -12.0), "res://data/enemies/vc_rifleman.tres")
	await get_tree().create_timer(0.8).timeout

	# M16 through the thatch
	var hp0: int = soft_man.current_hp
	var eye := Vector3(0, 1.5, 0)
	var chest: Vector3 = (soft_man as Node3D).global_position + Vector3(0, 1.25, 0)
	CombatManager.bullets.fire(m16, null, eye, (chest - eye).normalized(), 1 | 32 | 64, [], false)
	await get_tree().create_timer(0.6).timeout
	var soft_dmg: int = hp0 - (soft_man.current_hp if is_instance_valid(soft_man) else 0)
	var soft_dead: bool = not is_instance_valid(soft_man) or soft_man.is_dead()
	print("  M16 through THATCH   -> %d damage (dead: %s)" % [soft_dmg, soft_dead])

	# M16 into the bunker
	var hp1: int = hard_man.current_hp
	var eye2 := Vector3(20, 1.5, 0)
	var chest2: Vector3 = (hard_man as Node3D).global_position + Vector3(0, 1.25, 0)
	CombatManager.bullets.fire(m16, null, eye2, (chest2 - eye2).normalized(), 1 | 32 | 64, [], false)
	await get_tree().create_timer(0.6).timeout
	var hard_dmg: int = hp1 - (hard_man.current_hp if is_instance_valid(hard_man) else 0)
	print("  M16 into the BUNKER  -> %d damage (must be 0 - that is real cover)" % hard_dmg)

	var ok: bool = soft_dmg > 0 and hard_dmg == 0
	if ok:
		print("PASS: concealment is not cover (thatch %d dmg), and cover still covers (bunker %d)" % [
			soft_dmg, hard_dmg])
	else:
		print("FAIL: thatch=%d (want >0) bunker=%d (want 0)" % [soft_dmg, hard_dmg])
	get_tree().quit(0 if ok else 1)


func _wall(pos: Vector3, soft: bool) -> void:
	var b := StaticBody3D.new()
	b.name = "hooch_wall" if soft else "bunker_wall"
	b.collision_layer = 1
	b.collision_mask = 0
	if soft:
		b.add_to_group("soft_cover")
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(8, 2.4, 0.25)
	cs.shape = box
	b.add_child(cs)
	add_child(b)
	b.global_position = pos


func _floor() -> void:
	var f := StaticBody3D.new()
	f.collision_layer = 1
	f.collision_mask = 0
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(80, 0.2, 60)
	cs.shape = box
	cs.position = Vector3(10, -0.1, -15)
	f.add_child(cs)
	add_child(f)
