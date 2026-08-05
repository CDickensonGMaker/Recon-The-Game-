## probe_structure_ballistics.gd - do WORLD BUILDINGS obey the penetration grammar?
## The gun range's pen row proved the groups work on hand-built panels; this proves
## them on the real structure pipeline: a man INSIDE a thatch hut (nha_tranh_01.glb,
## GLB's own nested -col trimesh) must be killable through the wall, and a man
## behind bunker.glb (authored box, hard) must not be touchable. Structures are
## built exactly as SitePlanner.place_structure builds them: CollisionTable decides
## the material, SitePlanner.tag_ballistics stamps the groups.
##   godot --headless --path . res://tools/probe_structure_ballistics.tscn
extends Node3D

const STRUCT_DIR: String = "res://assets/world/building models/structures/"


func _ready() -> void:
	_floor()
	var hut: StaticBody3D = _place(STRUCT_DIR + "village/nha_tranh_01.glb", Vector3(0, 0, 0))
	var bunker: StaticBody3D = _place(STRUCT_DIR + "bunker.glb", Vector3(40, 0, 0))
	await get_tree().create_timer(0.4).timeout

	var m16: WeaponData = load("res://data/weapons/m16a1.tres")
	var hut_man: Node = EnemyBase.spawn_enemy(self, Vector3(0, 0.2, 0),
		"res://data/enemies/vc_rifleman.tres")
	var bunker_man: Node = EnemyBase.spawn_enemy(self, Vector3(40, 0.2, 5.0),
		"res://data/enemies/vc_rifleman.tres")
	await get_tree().create_timer(0.8).timeout

	# Prove the shot axis actually crosses a tagged wall (a doorway would let the
	# round through untested). World-only ray, then report what stands in the way.
	var chest: Vector3 = (hut_man as Node3D).global_position + Vector3(0, 1.25, 0)
	var eye := Vector3.ZERO
	var wall_ok: bool = false
	for dir in [Vector3(-12, 0, 0), Vector3(12, 0, 0), Vector3(0, 0, -12), Vector3(0, 0, 12)]:
		eye = chest + (dir as Vector3)
		eye.y = 1.5
		var blocker: Object = _world_blocker(eye, chest)
		if blocker is Node and (blocker as Node).is_in_group("soft_cover"):
			print("  hut wall on the line: %s (soft_cover)" % (blocker as Node).name)
			wall_ok = true
			break
	if not wall_ok:
		print("FAIL: no soft_cover wall found on any axis into the hut")
		get_tree().quit(1)
		return

	var hp0: int = hut_man.current_hp
	for _i in range(4):
		CombatManager.bullets.fire(m16, null, eye, (chest - eye).normalized(), 1 | 32 | 64, [], false)
		await get_tree().create_timer(0.25).timeout
	await get_tree().create_timer(0.5).timeout
	var hut_dead: bool = not is_instance_valid(hut_man) or hut_man.is_dead()
	var hut_dmg: int = hp0 - (0 if hut_dead else int(hut_man.current_hp))
	print("  4x M16 through the HUT WALL -> %d damage (dead: %s)" % [hut_dmg, hut_dead])

	var chest2: Vector3 = (bunker_man as Node3D).global_position + Vector3(0, 1.25, 0)
	var eye2 := Vector3(40, 1.2, -10.0)
	var blocker2: Object = _world_blocker(eye2, chest2)
	var bunker_named: String = (blocker2 as Node).name if blocker2 is Node else "NOTHING"
	var bunker_hard: bool = blocker2 is Node and (blocker2 as Node).is_in_group("hard_surface")
	print("  bunker on the line: %s (hard_surface: %s)" % [bunker_named, bunker_hard])
	var hp1: int = bunker_man.current_hp
	for _j in range(2):
		CombatManager.bullets.fire(m16, null, eye2, (chest2 - eye2).normalized(), 1 | 32 | 64, [], false)
		await get_tree().create_timer(0.25).timeout
	await get_tree().create_timer(0.5).timeout
	var bunker_dmg: int = hp1 - (bunker_man.current_hp if is_instance_valid(bunker_man) else 0)
	print("  2x M16 into the BUNKER -> %d damage (must be 0)" % bunker_dmg)

	var ok: bool = hut_dead and bunker_hard and bunker_dmg == 0
	if ok:
		print("PASS: thatch is concealment (man inside the hut is dead), the bunker is cover (0 dmg)")
	else:
		print("FAIL: hut dmg=%d dead=%s (want dead)  bunker hard=%s dmg=%d (want true/0)" % [
			hut_dmg, hut_dead, bunker_hard, bunker_dmg])
	get_tree().quit(0 if ok else 1)


## First world-layer collider between two points, ignoring hitzones.
func _world_blocker(from: Vector3, to: Vector3) -> Object:
	var q := PhysicsRayQueryParameters3D.create(from, to, 1)
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return null
	return hit.collider


## The place_structure contract in miniature: root body layer 1, GLB visual,
## authored box when the table carries no mesh collision, tag_ballistics over the
## whole subtree so nested -col bodies answer.
func _place(model_path: String, at: Vector3) -> StaticBody3D:
	var model_name: String = model_path.get_file().get_basename()
	var entry: Dictionary = CollisionTable.get_entry(model_name)
	var body := StaticBody3D.new()
	body.name = model_name
	body.collision_layer = 1
	body.collision_mask = 0
	var scene: PackedScene = load(model_path)
	body.add_child(scene.instantiate())
	if not bool(entry.get("mesh", false)):
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = entry.box
		shape.shape = box
		shape.position = Vector3(0, float(entry.y_offset), 0)
		body.add_child(shape)
	SitePlanner.tag_ballistics(body, CollisionTable.is_soft(model_name))
	add_child(body)
	body.global_position = at
	return body


func _floor() -> void:
	var f := StaticBody3D.new()
	f.collision_layer = 1
	f.collision_mask = 0
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(120, 0.2, 80)
	cs.shape = box
	cs.position = Vector3(20, -0.1, 0)
	f.add_child(cs)
	add_child(f)
