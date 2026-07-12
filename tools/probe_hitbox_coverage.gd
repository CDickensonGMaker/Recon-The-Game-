## probe_hitbox_coverage.gd - DOES THE MAN HAVE HOLES IN HIM?
##
## The real risk of tight, mesh-cut hitzones is not that they are "too small" -
## it is SEAMS: a round that visually strikes the body but passes between two
## zone hulls and hits NOTHING. (Bohemia's own fire-geometry guidance warns the
## components must not overlap - which is exactly what opens gaps.)
##
## Method: skin the render mesh to the rest skeleton (the renderer's own maths),
## bake it as a trimesh StaticBody on its own layer, then fire a dense ray grid
## at the man and compare, per ray:
##   hits mesh + hits a zone = COVERED
##   hits mesh, hits NO zone = HOLE      (you shot him and the game shrugged)
##   hits a zone, misses mesh = OVERHANG (you hit air and the game said "hit")
##   godot --headless --path . -s res://tools/probe_hitbox_coverage.gd [unit]
extends SceneTree

const MESH_LAYER: int = 1 << 10   # 1024 - the rendered body, for comparison only
const ZONE_LAYER: int = 64        # the real hurtbox layer
const STEP: float = 0.012         # 1.2cm ray grid - finer than a bullet cares


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var units: Array = args if args.size() > 0 else ["us_grunt_v2", "vc_guerilla"]
	for u in units:
		await _probe(str(u))
	quit(0)


func _probe(unit: String) -> void:
	var holder := Node3D.new()
	root.add_child(holder)
	var model := ModelActor.new()
	holder.add_child(model)
	if not model.setup(unit):
		print("%s: setup FAILED" % unit)
		holder.queue_free()
		return
	await process_frame
	var skel: Skeleton3D = model.skeleton()
	var entries: Array = HitzoneBuilder.build(holder, model, ZONE_LAYER, 0, ["probe"], true)
	# The zones live at the origin until they are ridden onto the bones (the
	# game syncs every physics tick). No clip is played: an unposed skeleton
	# sits at REST, which is the same pose the mesh below is skinned to - so
	# mesh and zones are compared in the SAME pose, apples to apples.
	HitzoneBuilder.sync(model, entries)
	await process_frame

	# The rendered body as physics geometry: every triangle, skinned to rest.
	var tris := PackedVector3Array()
	var to_world: Transform3D = skel.global_transform
	var stack: Array[Node] = [model.instance_root() as Node]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for c in n.get_children():
			stack.push_back(c)
		var mi := n as MeshInstance3D
		if mi == null or not mi.visible or mi.mesh == null or mi.skin == null:
			continue
		var xf: Array = HitzoneBuilder._bind_rest_xforms(mi.skin, skel)
		for s in range(mi.mesh.get_surface_count()):
			var arr: Array = mi.mesh.surface_get_arrays(s)
			var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
			var bones: PackedInt32Array = arr[Mesh.ARRAY_BONES]
			var weights = arr[Mesh.ARRAY_WEIGHTS]
			if verts.is_empty() or bones.is_empty() or idx.is_empty():
				continue
			var infl: int = bones.size() / verts.size()
			var skinned := PackedVector3Array()
			skinned.resize(verts.size())
			for vi in range(verts.size()):
				var bw: float = -1.0
				var bb: int = -1
				for j in range(infl):
					var w: float = float(weights[vi * infl + j])
					if w > bw:
						bw = w
						bb = bones[vi * infl + j]
				var v: Vector3 = verts[vi]
				if bb >= 0 and bb < xf.size():
					v = (xf[bb] as Transform3D) * v
				skinned[vi] = to_world * v
			for i in range(0, idx.size(), 3):
				tris.append(skinned[idx[i]])
				tris.append(skinned[idx[i + 1]])
				tris.append(skinned[idx[i + 2]])
	if tris.is_empty():
		print("%s: no skinned triangles" % unit)
		holder.queue_free()
		return
	var body := StaticBody3D.new()
	body.collision_layer = MESH_LAYER
	body.collision_mask = 0
	var cs := CollisionShape3D.new()
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(tris)
	cs.shape = shape
	body.add_child(cs)
	root.add_child(body)
	await process_frame

	var space: PhysicsDirectSpaceState3D = root.get_world_3d().direct_space_state
	# Two firing angles: face-on (front seams, e.g. hip line) and side-on
	# (limb-to-torso seams, where an arm hull meets the chest hull).
	for view in ["FRONT", "SIDE"]:
		var covered: int = 0
		var holes: int = 0
		var overhang: int = 0
		var hole_bands: Dictionary = {}   # 10cm band -> count
		var x: float = -0.75
		while x <= 0.75:
			var y: float = 0.02
			while y <= 1.85:
				var from: Vector3
				var to: Vector3
				if view == "FRONT":
					from = Vector3(x, y, 3.0)
					to = Vector3(x, y, -3.0)
				else:
					from = Vector3(3.0, y, x)
					to = Vector3(-3.0, y, x)
				var qm := PhysicsRayQueryParameters3D.create(from, to, MESH_LAYER)
				var hit_mesh: bool = not space.intersect_ray(qm).is_empty()
				var qz := PhysicsRayQueryParameters3D.create(from, to, ZONE_LAYER)
				qz.collide_with_areas = true
				qz.collide_with_bodies = false
				var hit_zone: bool = not space.intersect_ray(qz).is_empty()
				if hit_mesh and hit_zone:
					covered += 1
				elif hit_mesh and not hit_zone:
					holes += 1
					var band: int = int(y * 10.0)
					hole_bands[band] = int(hole_bands.get(band, 0)) + 1
				elif hit_zone and not hit_mesh:
					overhang += 1
				y += STEP
			x += STEP
		var on_body: int = covered + holes
		var pct: float = 100.0 * float(covered) / maxf(1.0, float(on_body))
		print("\n=== %s [%s] ===" % [unit, view])
		print("  body rays: %d   COVERED %.1f%%   HOLES %.1f%% (%d rays)   overhang %d rays" % [
			on_body, pct, 100.0 - pct, holes, overhang])
		if holes > 0:
			var keys: Array = hole_bands.keys()
			keys.sort()
			for b in keys:
				var cnt: int = int(hole_bands[b])
				if cnt < 4:
					continue
				var bar: String = "#".repeat(mini(40, cnt / 2))
				print("    y %.1f-%.1fm  %4d rays through nothing  %s" % [
					float(b) * 0.1, float(b) * 0.1 + 0.1, cnt, bar])
	body.queue_free()
	holder.queue_free()
