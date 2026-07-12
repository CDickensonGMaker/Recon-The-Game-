## probe_buckshot.gd - how much of the pattern actually LANDS on a man?
## Reproduces the shipping pellet geometry (weapon_holder._fire_pellet_cluster:
## 9 pellets, deterministic star, half-angle per axis) and casts it at a real
## vc_rifleman standing at each range - counting pellets that strike a hitzone
## and the damage the aggregate would do. This is the "does the spread grab him"
## question, answered in numbers instead of vibes.
##   godot --headless --path . res://tools/probe_buckshot.tscn
extends Node3D

const RANGES: Array[float] = [5.0, 10.0, 15.0, 20.0, 25.0, 30.0, 40.0, 50.0]


func _ready() -> void:
	var floor_body := StaticBody3D.new()
	floor_body.collision_layer = 1
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(20, 0.2, 200)
	cs.shape = box
	cs.position = Vector3(0, -0.1, -80)
	floor_body.add_child(cs)
	add_child(floor_body)

	var wd: WeaponData = load("res://data/weapons/shotgun.tres")
	print("ITHACA: %d pellets x %d dmg, cone %.1f deg, full dmg to %.0fm (x%.2f at %.0fm)" % [
		wd.pellet_count, wd.base_damage, wd.pellet_spread_deg,
		wd.effective_range, wd.min_damage_mult, wd.max_range])
	print("range  pellets_on_man  zones            raw    vs torso    verdict")

	for r in RANGES:
		var man: Node = EnemyBase.spawn_enemy(self, Vector3(0, 1.0, -r), "res://data/enemies/vc_rifleman.tres")
		await get_tree().create_timer(0.8).timeout
		# Aim at his chest, exactly as a player would.
		var eye := Vector3(0, 1.6, 0)
		var chest: Vector3 = (man as Node3D).global_position + Vector3(0, 1.25, 0)
		var aim: Vector3 = (chest - eye).normalized()
		var right: Vector3 = aim.cross(Vector3.UP).normalized()
		var up: Vector3 = right.cross(aim).normalized()
		var cone: float = deg_to_rad(wd.pellet_spread_deg * 0.5)

		var star: Array[Vector2] = [Vector2.ZERO]
		for i in range(4):
			var a: float = TAU * float(i) / 4.0
			star.append(Vector2(cos(a), sin(a)) * 0.4)
		for i in range(4):
			var a2: float = TAU * (float(i) + 0.5) / 4.0
			star.append(Vector2(cos(a2), sin(a2)))

		var space := get_world_3d().direct_space_state
		var hits: int = 0
		var zones: Dictionary = {}
		var mult_sum: float = 0.0
		for p in range(wd.pellet_count):
			var o: Vector2 = star[p % star.size()] * cone
			var dir: Vector3 = (aim + right * tan(o.x) + up * tan(o.y)).normalized()
			var q := PhysicsRayQueryParameters3D.create(eye, eye + dir * 200.0, 1 | 64)
			q.collide_with_areas = true
			var h: Dictionary = space.intersect_ray(q)
			if h.is_empty() or not (h.collider is Hitzone):
				continue
			var hz := h.collider as Hitzone
			hits += 1
			mult_sum += hz.get_damage_multiplier()
			var zn: String = hz.get_zone_name()
			zones[zn] = int(zones.get(zn, 0)) + 1
		var falloff: float = wd.damage_multiplier_at(r)
		var raw: int = int(float(wd.base_damage * hits) * falloff)
		var avg_mult: float = (mult_sum / float(hits)) if hits > 0 else 0.0
		var applied: int = int(float(raw) * avg_mult)
		var verdict: String = "MISS"
		if applied >= 70:
			verdict = "kills a 70hp man"
		elif applied >= 35:
			verdict = "wounds hard"
		elif applied > 0:
			verdict = "peppered"
		print("%4.0fm      %d/%d        %-16s %4d   %5d      %s" % [
			r, hits, wd.pellet_count, str(zones), raw, applied, verdict])
		if is_instance_valid(man):
			man.queue_free()
		await get_tree().process_frame
	get_tree().quit(0)
