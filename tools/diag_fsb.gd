extends Node
## Headless diagnosis of the fsb_main placement at the DEFAULT operation seed.

func _ready() -> void:
	var flow := GameFlow.new()
	add_child(flow)
	await get_tree().process_frame
	flow._begin_operation(47225, "DIAG")
	var waited := 0.0
	while waited < 180.0:
		if flow.world != null and flow.world.is_world_ready and flow.world.player != null:
			break
		await get_tree().create_timer(0.5).timeout
		waited += 0.5
	await get_tree().create_timer(1.0).timeout
	var world: GameWorld = flow.world
	var tm: TerrainManager = world.terrain_manager
	var fsb: Node3D = null
	var stack: Array[Node] = [world]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n.has_meta("model_name") and str(n.get_meta("model_name")) == "fsb_main":
			fsb = n as Node3D
			break
		for c in n.get_children():
			stack.append(c)
	if fsb == null:
		print("[DIAG] fsb_main NODE MISSING ENTIRELY")
		get_tree().quit(1)
		return
	var o: Vector3 = fsb.global_position
	print("[DIAG] fsb origin: %.1f, %.1f, %.1f" % [o.x, o.y, o.z])
	var center: Vector3 = o + SitePlanner.FSB_AABB_CENTER
	print("[DIAG] terrain@center=%.1f  origin.y=%.1f  delta=%.1f" % [
		tm.get_height_at(center), o.y, tm.get_height_at(center) - o.y])
	var spawn: Vector3 = world.player.global_position
	print("[DIAG] player spawn: %.1f, %.1f, %.1f  terrain@spawn=%.1f" % [
		spawn.x, spawn.y, spawn.z, tm.get_height_at(spawn)])
	# Sample terrain vs model ground across the footprint.
	var buried: int = 0
	var above: int = 0
	for dx in range(-3, 4):
		for dz in range(-3, 4):
			var p: Vector3 = center + Vector3(float(dx) * 55.0, 0.0, float(dz) * 55.0)
			var th: float = tm.get_height_at(p)
			var rel: float = th - o.y
			if rel > 3.0:
				buried += 1
			elif rel < -3.0:
				above += 1
	print("[DIAG] footprint 49 samples: %d BURIED(terrain >3m over model ground), %d FLOATING(<-3m)" % [buried, above])
	# Visible meshes near spawn (what his eyes get).
	var vis_near: int = 0
	var vis_above_ground: int = 0
	var stack2: Array[Node] = [fsb]
	while not stack2.is_empty():
		var n2: Node = stack2.pop_back()
		for c2 in n2.get_children():
			stack2.append(c2)
		var mi := n2 as MeshInstance3D
		if mi != null and mi.visible:
			var mp: Vector3 = mi.global_position
			if Vector2(mp.x - spawn.x, mp.z - spawn.z).length() < 200.0:
				vis_near += 1
				var b: AABB = mi.global_transform * mi.get_aabb()
				if b.end.y > tm.get_height_at(mp) + 0.3:
					vis_above_ground += 1
	print("[DIAG] fsb meshes within 200m of spawn: %d, of those poking above terrain: %d" % [vis_near, vis_above_ground])
	var total: int = 0
	var total_above: int = 0
	var stack3: Array[Node] = [fsb]
	while not stack3.is_empty():
		var n3: Node = stack3.pop_back()
		for c3 in n3.get_children():
			stack3.append(c3)
		var mi3 := n3 as MeshInstance3D
		if mi3 != null and mi3.visible:
			total += 1
			var b3: AABB = mi3.global_transform * mi3.get_aabb()
			if b3.end.y > tm.get_height_at(mi3.global_position) + 0.3:
				total_above += 1
	print("[DIAG] fsb meshes TOTAL: %d, above terrain: %d" % [total, total_above])
	var d: FieldDirector = flow.director
	print("[DIAG] gate_pos: %s  dist spawn->gate: %.1f" % [str(d.patrol_gate_pos.round()), spawn.distance_to(d.patrol_gate_pos)])

	# PHYSICS TRUTH vs ARRAY TRUTH (verify-in-object-space law): the player collides
	# with baked chunk meshes, not with heightmap arithmetic. Ray from 400m down.
	for i in range(3):
		await get_tree().physics_frame
	var space := world.get_world_3d().direct_space_state
	var pts: Dictionary = {
		"spawn": spawn, "gate": d.patrol_gate_pos, "center": center,
		"corner_nw": center + Vector3(-150.0, 0.0, -150.0),
		"corner_ne": center + Vector3(150.0, 0.0, -150.0),
		"corner_sw": center + Vector3(-150.0, 0.0, 150.0),
		"corner_se": center + Vector3(150.0, 0.0, 150.0),
	}
	for k in pts:
		var p: Vector3 = pts[k]
		var q := PhysicsRayQueryParameters3D.create(
			Vector3(p.x, 400.0, p.z), Vector3(p.x, -100.0, p.z))
		var hit: Dictionary = space.intersect_ray(q)
		var py: float = -999.0
		var cname: String = "NO-HIT"
		if hit.has("position"):
			py = (hit.position as Vector3).y
			var col: Object = hit.collider
			if col is Node:
				cname = (col as Node).name
		var ay: float = tm.get_height_at(p)
		var chunk := Vector2i(int(floor(p.x / 256.0)), int(floor(p.z / 256.0)))
		print("[DIAG-PHYS] %-10s physics_y=%7.2f  array_y=%7.2f  delta=%7.2f  hit=%s  chunk=%s" % [
			k, py, ay, py - ay, cname, str(chunk)])

	# Where the player body actually SETTLES (30 physics frames of gravity).
	var start_y: float = world.player.global_position.y
	for i in range(30):
		await get_tree().physics_frame
	var settled: Vector3 = world.player.global_position
	print("[DIAG-PHYS] player start_y=%.2f settled=%.1f,%.1f,%.1f (array_y here=%.2f)" % [
		start_y, settled.x, settled.y, settled.z, tm.get_height_at(settled)])

	# WHERE report: every patrol location with bearing + distance from spawn.
	const DIRS: Array[String] = ["N","NE","E","SE","S","SW","W","NW"]
	for loc in d.patrol_locations:
		var lp: Vector3 = loc.pos
		var dv := Vector2(lp.x - spawn.x, lp.z - spawn.z)
		var bearing: float = fposmod(rad_to_deg(atan2(dv.x, -dv.y)), 360.0)
		var dir: String = DIRS[int(round(bearing / 45.0)) % 8]
		print("[DIAG-WHERE] %-9s %s %4.0fm  bearing %3.0f (%s)  at %.0f,%.0f" % [
			str(loc.kind), dir, dv.length(), bearing, dir, lp.x, lp.z])
	get_tree().quit(0)
