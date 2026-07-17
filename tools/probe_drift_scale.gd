extends SceneTree
## DRIFT COUNCIL probe (ADR-015 evidence for the test_model_scale "pre-existing
## n2ij" alibi, and for x1bs gear-donor double-render).
##
## test_model_scale measures the AABB of EVERY MeshInstance3D - visible or not.
## ModelActor deliberately does NOT trust the AABB (its own comment: "the mesh
## AABB measures the BIND pose, which the current exports bake ~2x larger").
## So: does civ_elder RENDER at 2.950m, or does only its bind-pose AABB say so?
##
## Prints, per unit: what the TEST sees (all-mesh AABB), what the PLAYER sees
## (visible-mesh AABB), and what the SKELETON says (rest span) - plus each unit's
## own target. Where these disagree, the test is measuring a ghost.
##
## Run: godot --headless --path . --script res://tools/probe_drift_scale.gd

func _initialize() -> void:
	print("unit             target  TEST(all)  PLAYER(vis)  SKEL(rest)  gib_k   verdict")
	print("---------------------------------------------------------------------------")
	var units: Array[String] = ModelActor.all_units()
	units.sort()
	for unit in units:
		var actor := ModelActor.new()
		get_root().add_child(actor)
		if not actor.setup(unit):
			actor.queue_free()
			continue
		var all_h: float = _aabb_h(actor, false)
		var vis_h: float = _aabb_h(actor, true)
		var skel_h: float = _skel_span(actor)
		var tgt: float = ModelActor.target_height(unit)
		if all_h <= 0.001:
			actor.queue_free()
			continue
		# The player's eye sees the SKINNED mesh, which follows the REST skeleton.
		var verdict := "ok"
		if absf(skel_h - tgt) > tgt * 0.05:
			verdict = "REAL SCALE BUG"
		elif absf(all_h - tgt) > tgt * 0.05:
			verdict = "TEST ARTIFACT (bind-pose AABB; rig is correct)"
		print("%-16s %.3f   %7.3f    %7.3f      %7.3f   %.2f   %s" % [
			unit, tgt, all_h, vis_h, skel_h, actor.gib_scale, verdict])
		actor.queue_free()

	# ---- x1bs: what meshes does a grunt actually ship, and which are hidden? ----
	for unit in ["us_grunt_v3", "civ_kid", "civ_kid_b", "civ_elder", "vc_guerilla"]:
		if not ModelActor.model_exists(unit):
			continue
		var a := ModelActor.new()
		get_root().add_child(a)
		a.setup(unit)
		print("\n=== %s meshes (x1bs) ===" % unit)
		# SKINNED (skin != null) = welded into the body chain, the v2-era gear.
		# RIGID (skin == null, bone-parented) = the v3 *_worn gear that left the
		# hurtbox. If BOTH are visible, the man wears the item twice.
		var vis: Array[String] = []
		var hid: Array[String] = []
		for n in _walk(a):
			var mi := n as MeshInstance3D
			if mi == null or mi.mesh == null:
				continue
			var kind: String = "SKINNED" if mi.skin != null else "rigid  "
			var meta: String = str(mi.get_meta_list())
			var row: String = "%s %s meta=%s" % [kind, String(mi.name), meta]
			if mi.visible:
				vis.append(row)
			else:
				hid.append(row)
		vis.sort()
		print("  VISIBLE (%d):" % vis.size())
		for r in vis:
			print("    " + r)
		print("  HIDDEN (%d) - names only: %d donors" % [hid.size(), hid.size()])
		a.queue_free()
	quit()


## `visible_only=false` reproduces exactly what test_model_scale measures.
## Transforms accumulate LOCALLY from `root` down: global_transform is invalid
## inside SceneTree._initialize (nodes are not "inside tree" yet), and the actor
## sits at the origin, so root-relative == world here.
func _aabb_h(root: Node3D, visible_only: bool) -> float:
	var out := AABB()
	var first := true
	var stack: Array = [[root, Transform3D.IDENTITY]]
	while not stack.is_empty():
		var e: Array = stack.pop_back()
		var n: Node = e[0]
		var xf: Transform3D = e[1]
		var n3 := n as Node3D
		var here: Transform3D = xf
		if n3 != null and n != root:
			here = xf * n3.transform
		for c in n.get_children():
			stack.push_back([c, here])
		var mi := n as MeshInstance3D
		if mi == null or mi.mesh == null:
			continue
		if visible_only and not mi.visible:
			continue
		var a: AABB = here * mi.get_aabb()
		if first:
			out = a
			first = false
		else:
			out = out.merge(a)
	return out.size.y


## What ModelActor itself trusts: the REST skeleton span, scaled into actor space.
func _skel_span(actor: ModelActor) -> float:
	var skel: Skeleton3D = actor.skeleton()
	if skel == null:
		return 0.0
	var top: int = skel.find_bone("mixamorig_HeadTop_End")
	var toe: int = skel.find_bone("mixamorig_LeftToeBase")
	if toe < 0:
		toe = skel.find_bone("mixamorig_LeftFoot")
	if top < 0 or toe < 0:
		return 0.0
	# accumulate local transforms skeleton -> actor (same reason as above)
	var t := Transform3D.IDENTITY
	var n: Node3D = skel
	while n != null and n != actor:
		t = n.transform * t
		n = n.get_parent() as Node3D
	return absf((t * skel.get_bone_global_rest(top).origin).y
			- (t * skel.get_bone_global_rest(toe).origin).y)


func _walk(n: Node) -> Array[Node]:
	var out: Array[Node] = [n]
	for c in n.get_children():
		out.append_array(_walk(c))
	return out
