extends Node3D
func _ready() -> void:
	var cam := Camera3D.new(); add_child(cam); cam.global_position = Vector3(0,2,12); cam.current = true
	await get_tree().process_frame
	var e := EnemyBase.spawn_enemy(self, Vector3(0,0,-40), "res://data/enemies/nva_rpg.tres")
	await get_tree().process_frame
	print("rpg enemy: sprite=%s weapon=%s proj=%s" % [
		"yes" if e.sprite_actor != null else "NO",
		e.weapon_data.id if e.weapon_data else "<none>",
		e.weapon_data.projectile_data_path if e.weapon_data else "-"])
	var pd: ProjectileData = load(e.weapon_data.projectile_data_path)
	var p := CombatManager.spawn_projectile(pd, e, Vector3(0,1.2,-40), Vector3(0,0,1), null)
	if p == null: print("FAIL: spawn returned null"); get_tree().quit(1); return
	print("  spawned: layer=%d mask=%d active=%d radius=%.2f" % [p.collision_layer, p.collision_mask, CombatManager.projectile_pool.get_active_count(), (p.collision_shape.shape as SphereShape3D).radius])
	print("  mesh assigned: %s   trail: %s" % [p.mesh_instance.mesh != null, p.trail != null])
	var start := p.global_position
	for i in range(30):
		p._physics_process(1.0/60.0)
	var d := start.distance_to(p.global_position)
	print("  travelled %.2fm in 0.5s (speed %.0f m/s, drop %.3fm)" % [d, pd.speed, start.y - p.global_position.y])
	if d < 30.0: print("FAIL: rocket barely moved"); get_tree().quit(1); return
	if p.mesh_instance.mesh == null: print("FAIL: invisible rocket"); get_tree().quit(1); return
	if p.collision_mask == 0: print("FAIL: mask 0, cannot hit anything"); get_tree().quit(1); return
	print("PASS: rpg projectile")
	get_tree().quit(0)
