extends SceneTree
## Two things Caleb asked to be SURE of, so they get measured, not asserted:
##   1. do the props actually stick to the body when he MOVES? (a prop that rides
##      the rest pose but not the animation is a prop lying on the floor mid-stride)
##   2. do civilians gib? in a war civilians die too, and a farmer who cannot lose
##      an arm is a mannequin.
##      godot --headless --path . -s res://tools/probe_civilian.gd

const PROPS := {
	"civ_farmer_m_b": ["rice_sickle", "mixamorig_RightHand"],
	"civ_farmer_m_c": ["rice_basket_back", "mixamorig_Spine2"],
	"civ_farmer_f_b": ["carry_pole", "mixamorig_Spine2"],
	"civ_kid_b":      ["rice_bundle", "mixamorig_LeftHand"],
}

func _initialize() -> void:
	for unit in PROPS.keys():
		var prop_name: String = PROPS[unit][0]
		var bone_name: String = PROPS[unit][1]
		var holder := Node3D.new()
		root.add_child(holder)
		var m := ModelActor.new()
		holder.add_child(m)
		if not m.setup(unit):
			print("%s: SETUP FAILED" % unit)
			continue
		await process_frame
		var skel: Skeleton3D = m.skeleton()
		var prop: MeshInstance3D = null
		for n in _walk(m):
			if n is MeshInstance3D and String(n.name) == prop_name:
				prop = n
		if prop == null:
			print("\n%s: *** %s NOT IN THE GLB ***" % [unit, prop_name])
			continue
		var bi: int = skel.find_bone(bone_name)

		# 1. does it TRACK THE BONE through an animation?
		var ap: AnimationPlayer = m.find_child("AnimationPlayer", true, false)
		var clip := "walk_forward"
		var worst: float = 0.0
		if ap != null and ap.has_animation(clip):
			ap.play(clip)
			var anim: Animation = ap.get_animation(clip)
			# Measure the offset in the BONE'S OWN SPACE. In WORLD space the offset
			# rotates with the bone, so a perfectly welded prop looks like it is
			# sliding around - that is a broken ruler, not a broken prop.
			var base_off: Vector3 = Vector3.ZERO
			for i in range(8):
				ap.seek(anim.length * float(i) / 8.0, true)
				await process_frame
				await process_frame
				var bone_g: Transform3D = (skel.global_transform
					* skel.get_bone_global_pose(bi))
				var off: Vector3 = bone_g.affine_inverse() * prop.global_position
				if i == 0:
					base_off = off
				else:
					worst = maxf(worst, off.distance_to(base_off))
		var skin_ok: bool = prop.skin == null
		var att: bool = prop.get_parent() is BoneAttachment3D
		print("\n=== %s ===" % unit)
		print("  %-18s attached=%s  rigid=%s  drift over a walk cycle: %.4f m  %s"
			% [prop_name, str(att), str(skin_ok), worst,
			   "WELDED TO HIM" if worst < 0.005 else "*** SLIPPING ***"])

		# 2. gibs
		var donors: int = 0
		var caps: int = 0
		var civ_mat: int = 0
		for n in _walk(m):
			var mi := n as MeshInstance3D
			if mi == null:
				continue
			var nm := String(mi.name)
			if nm.begins_with("grunt_") or nm.begins_with("head_frag_"):
				donors += 1
				var mat: Material = mi.mesh.surface_get_material(0)
				if mat != null and String(mat.resource_name).begins_with("civ"):
					civ_mat += 1
			elif nm.begins_with("cap_"):
				caps += 1
		print("  gib donors: %d   wound caps: %d   donors wearing CIVILIAN cloth: %d"
			% [donors, caps, civ_mat])
		holder.queue_free()
		await process_frame
	quit()

func _walk(n: Node) -> Array[Node]:
	var out: Array[Node] = [n]
	for c in n.get_children():
		out.append_array(_walk(c))
	return out
