## probe_scene_census.gd - WHAT IS IN THE WORLD, counted, by type (perf audit 2026-09-10).
##
## Run: godot --headless --path . res://tools/probe_scene_census.tscn
##
## The perf ledger has frame times and draw-call totals; nothing in it says WHAT those draw
## calls are. This walks the built demo world and counts every renderable, collider, agent and
## per-frame script by class, with triangle and instance totals, so the frame cost can be
## attributed to a structure instead of a feeling. Headless: no GPU, so it counts what would be
## SUBMITTED, not what is drawn after culling - the culling itself is per-instance CPU work, so
## the raw count matters on its own.
extends Node

const SEED_VAL: int = 29072026


func _ready() -> void:
	var scene: PackedScene = load("res://scenes/levels/demo_game.tscn") as PackedScene
	add_child(scene.instantiate())
	var spins: int = 0
	while spins < 600 and get_tree().get_nodes_in_group(&"nav_baker").is_empty():
		spins += 1
		await get_tree().create_timer(0.1).timeout
	await get_tree().create_timer(12.0).timeout

	var by_class: Dictionary = {}
	var mi_n: int = 0
	var mi_tris: int = 0
	var mi_surfaces: int = 0
	var mi_no_range: int = 0
	var mmi_n: int = 0
	var mmi_instances: int = 0
	var mmi_tris_total: int = 0
	var mmi_no_range: int = 0
	var shapes: int = 0
	var concave: int = 0
	var lights: int = 0
	var light_shadows: int = 0
	var decals: int = 0
	var phys_scripts: int = 0
	var proc_scripts: int = 0
	var nav_agents: int = 0
	var char_bodies: int = 0
	var skeletons: int = 0
	var anim_players: int = 0
	var particles: int = 0
	var audio: int = 0
	var total: int = 0
	var top_meshes: Dictionary = {}
	var stack: Array[Node] = [get_tree().root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for c in n.get_children():
			stack.append(c)
		total += 1
		var cls: String = n.get_class()
		by_class[cls] = int(by_class.get(cls, 0)) + 1
		if n.has_method("_physics_process") and n.get_script() != null:
			var scr: Script = n.get_script() as Script
			if scr != null and scr.has_method("_physics_process") or _script_declares(scr, "_physics_process"):
				phys_scripts += 1
			if _script_declares(scr, "_process"):
				proc_scripts += 1
		if n is MeshInstance3D:
			var mi := n as MeshInstance3D
			if mi.mesh != null and mi.visible and mi.is_visible_in_tree():
				mi_n += 1
				var t: int = 0
				for s in range(mi.mesh.get_surface_count()):
					mi_surfaces += 1
					t += _surface_tris(mi.mesh, s)
				mi_tris += t
				if mi.visibility_range_end <= 0.0:
					mi_no_range += 1
				var key: String = mi.mesh.resource_path.get_file() if mi.mesh.resource_path != "" else String(mi.name)
				var rec: Array = top_meshes.get(key, [0, 0])
				rec[0] += 1
				rec[1] += t
				top_meshes[key] = rec
		elif n is MultiMeshInstance3D:
			var mmi := n as MultiMeshInstance3D
			if mmi.multimesh != null and mmi.is_visible_in_tree():
				mmi_n += 1
				var cnt: int = mmi.multimesh.visible_instance_count if mmi.multimesh.visible_instance_count >= 0 else mmi.multimesh.instance_count
				mmi_instances += cnt
				var per: int = 0
				if mmi.multimesh.mesh != null:
					for s in range(mmi.multimesh.mesh.get_surface_count()):
						per += _surface_tris(mmi.multimesh.mesh, s)
				mmi_tris_total += per * cnt
				if mmi.visibility_range_end <= 0.0:
					mmi_no_range += 1
		elif n is CollisionShape3D:
			shapes += 1
			if (n as CollisionShape3D).shape is ConcavePolygonShape3D:
				concave += 1
		elif n is Light3D:
			lights += 1
			if (n as Light3D).shadow_enabled:
				light_shadows += 1
		elif n is Decal:
			decals += 1
		elif n is NavigationAgent3D:
			nav_agents += 1
		elif n is CharacterBody3D:
			char_bodies += 1
		elif n is Skeleton3D:
			skeletons += 1
		elif n is AnimationPlayer:
			anim_players += 1
		elif n is GPUParticles3D or n is CPUParticles3D:
			particles += 1
		elif n is AudioStreamPlayer3D:
			audio += 1

	print("\n=== SCENE CENSUS (demo world, headless) ===")
	print("[CENSUS] nodes total %d" % total)
	print("[CENSUS] MeshInstance3D visible %d, surfaces %d, tris %d, %d with NO visibility range"
		% [mi_n, mi_surfaces, mi_tris, mi_no_range])
	print("[CENSUS] MultiMeshInstance3D %d, instances %d, instanced tris %d, %d with NO visibility range"
		% [mmi_n, mmi_instances, mmi_tris_total, mmi_no_range])
	print("[CENSUS] CollisionShape3D %d (%d concave trimesh)" % [shapes, concave])
	print("[CENSUS] lights %d (%d with shadows), decals %d, particles %d, audio3d %d"
		% [lights, light_shadows, decals, particles, audio])
	print("[CENSUS] CharacterBody3D %d, NavigationAgent3D %d, Skeleton3D %d, AnimationPlayer %d"
		% [char_bodies, nav_agents, skeletons, anim_players])
	print("[CENSUS] scripts with _physics_process %d, with _process %d" % [phys_scripts, proc_scripts])
	var keys: Array = top_meshes.keys()
	keys.sort_custom(func(a, b): return int(top_meshes[a][1]) > int(top_meshes[b][1]))
	print("[CENSUS] top MeshInstance3D sources by triangles:")
	for i in range(mini(15, keys.size())):
		var k: String = keys[i]
		print("   %-40s x%-5d %8d tris" % [k, int(top_meshes[k][0]), int(top_meshes[k][1])])
	var ck: Array = by_class.keys()
	ck.sort_custom(func(a, b): return int(by_class[a]) > int(by_class[b]))
	print("[CENSUS] top node classes:")
	for i in range(mini(18, ck.size())):
		print("   %-28s %6d" % [ck[i], int(by_class[ck[i]])])
	get_tree().quit(0)


static func _script_declares(scr: Script, fn: String) -> bool:
	if scr == null:
		return false
	var s: Script = scr
	while s != null:
		for m in s.get_script_method_list():
			if str(m.get("name", "")) == fn:
				return true
		s = s.get_base_script()
	return false


static func _surface_tris(mesh: Mesh, s: int) -> int:
	var arrays: Array = mesh.surface_get_arrays(s)
	if arrays.is_empty():
		return 0
	var idx: Variant = arrays[Mesh.ARRAY_INDEX]
	if idx != null and (idx as PackedInt32Array).size() > 0:
		return (idx as PackedInt32Array).size() / 3
	var v: Variant = arrays[Mesh.ARRAY_VERTEX]
	if v == null:
		return 0
	return (v as PackedVector3Array).size() / 3
