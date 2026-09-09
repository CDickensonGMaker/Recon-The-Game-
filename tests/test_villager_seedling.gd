## test_villager_seedling.gd - a villager working a paddy holds what he is planting.
##
##   godot --headless --path . res://tests/test_villager_seedling.tscn
##
## His ask, 2026-09-09: "even when villagers are doing the work animation in the rice
## fields give them a plant in their hand." The clip was already right - civilian.gd
## VILLAGE_ACTION_CLIPS[&"work"] plays `plant_seeds` - and the hands were empty on 8
## of the 10 variants, because only civ_farmer_f_c and civ_kid_b carry a welded
## rice_bundle out of make_civilians.py.
##
## THE GATE IS PARITY, NOT PLAUSIBILITY. The runtime attach must land the bundle where
## HIS BAKE puts it, measured in LeftHand bone space so the rig's pose cannot flatter
## the result. Both sides are read fresh: the reference off civ_farmer_f_c.glb, the
## measurement off a spawned Civilian. A hardcoded expected vector would only prove
## this file agrees with itself.
##
## CONTROL LANE: the same assert also proves the naive fix is wrong. rice_bundle.glb's
## verts are in rig REST-POSE WORLD space, so attaching it with an identity transform -
## which is exactly what _set_shovel does for the bone-local e-tool - puts it ~1.4 m
## from the fist. The probe fails if that identity error would pass.
extends Node

const BAKED_UNIT: String = "civ_farmer_f_c"
const TOL: float = 0.001

var failures: int = 0


func _ready() -> void:
	var ref: Vector3 = _reference()
	if ref == Vector3.INF:
		print("FAIL: cannot read the baked placement from %s" % BAKED_UNIT)
		get_tree().quit(1)
		return
	print("reference (his bake, LeftHand space): %v" % ref)

	# 1. a bare variant gains one, in the right place
	var civ: Civilian = Civilian.spawn(self, Vector3.ZERO, null, false, ["civ_farmer_m"])
	civ._set_seedling(true)
	var skel: Skeleton3D = civ.actor.skeleton()
	var mine: Vector3 = _bundle_in_bone_space(skel)
	if mine == Vector3.INF:
		print("FAIL: no seedling attached to a bare villager")
		failures += 1
	else:
		var d: float = mine.distance_to(ref)
		print("attached (runtime): %v   delta=%.6f m" % [mine, d])
		if d > TOL:
			print("FAIL: seedling is %.4f m off his baked placement (tol %.3f)" % [d, TOL])
			failures += 1
		# CONTROL: the identity attach the shovel uses must NOT land here.
		var naive: float = _bundle_local_centre().distance_to(ref)
		if naive <= TOL:
			print("FAIL: control lane dead - an identity attach also passes, so this")
			print("      probe cannot tell the correct transform from no transform")
			failures += 1
		else:
			print("control: identity attach would miss by %.4f m" % naive)
		if mine.length() > 0.35:
			print("FAIL: seedling sits %.3f m from the hand bone - that is not a grip" % mine.length())
			failures += 1
		var att: Node = _socket(skel)
		if att == null:
			print("FAIL: seedling is not on a BoneAttachment3D")
			failures += 1
		elif not String((att as BoneAttachment3D).bone_name).ends_with("LeftHand"):
			print("FAIL: seedling on %s - the right hand is the sickle's"
				% (att as BoneAttachment3D).bone_name)
			failures += 1

	# 2. it is released
	civ._set_seedling(false)
	await get_tree().process_frame
	if _socket(skel) != null:
		print("FAIL: seedling survived _set_seedling(false)")
		failures += 1

	# 3. a variant that already carries one does not get a second
	var baked: Civilian = Civilian.spawn(self, Vector3.ZERO, null, false, ["civ_farmer_f_c"])
	baked._set_seedling(true)
	var n: int = _count_bundles(baked.actor.skeleton())
	if n != 1:
		print("FAIL: civ_farmer_f_c carries %d bundle(s) - his bake plus ours" % n)
		failures += 1
	else:
		print("civ_farmer_f_c: 1 bundle, his own - not doubled")

	# THE E-TOOL, same file, same mechanism. _set_shovel sets bone_idx BEFORE the socket
	# enters the tree, which is how the seedling's socket lost its bone_name. Measure the
	# shipped prop rather than assume either way.
	var dig: Civilian = Civilian.spawn(self, Vector3.ZERO, null, false, ["civ_farmer_m"])
	dig._set_shovel(true)
	var dskel: Skeleton3D = dig.actor.skeleton()
	var sock: Node = _named(dskel, "ShovelSocket")
	if sock == null:
		print("NOTE: no shovel socket - e-tool not checked")
	else:
		var sb: BoneAttachment3D = sock as BoneAttachment3D
		var rh: int = dskel.find_bone("mixamorig_RightHand")
		if rh < 0:
			rh = dskel.find_bone("mixamorig:RightHand")
		var off: float = INF
		var smi: MeshInstance3D = _any_mesh(sb)
		if smi != null:
			var bx: Transform3D = dskel.global_transform * dskel.get_bone_global_pose(rh)
			off = (bx.affine_inverse() * (smi.global_transform * smi.get_aabb().get_center())).length()
		print("e-tool: socket bone_idx=%d (RightHand=%d) bone_name=%s offset_from_fist=%.3f m"
			% [sb.bone_idx, rh, sb.bone_name, off])
		if sb.bone_idx != rh or off > 0.6:
			print("FAIL: the e-tool is not in the digger's fist - bone_idx/offset above")
			failures += 1

	if failures == 0:
		print("PASS: villager seedling - parity with the baked placement, control lane live")
	get_tree().quit(1 if failures > 0 else 0)


## Where HIS bake puts the bundle, expressed in LeftHand space. Read off a civilian
## spawned THE SAME WAY as the one under test - ModelActor rescales the rig to the
## 1.7132 m contract, so a raw GLB import is not the same skeleton and comparing the
## two measures the import path, not the placement.
func _reference() -> Vector3:
	var civ: Civilian = Civilian.spawn(self, Vector3.ZERO, null, false, [BAKED_UNIT])
	if civ == null or civ.actor == null:
		return Vector3.INF
	var v: Vector3 = _bundle_in_bone_space(civ.actor.skeleton())
	civ.queue_free()
	return v


## The bundle's AABB centre in LeftHand bone space - pose-independent by construction.
func _bundle_in_bone_space(skel: Skeleton3D) -> Vector3:
	if skel == null:
		return Vector3.INF
	var bi: int = skel.find_bone("mixamorig_LeftHand")
	if bi < 0:
		bi = skel.find_bone("mixamorig:LeftHand")
	if bi < 0:
		return Vector3.INF
	var mi: MeshInstance3D = _bundle_mesh(skel)
	if mi == null:
		return Vector3.INF
	var world: Vector3 = mi.global_transform * mi.get_aabb().get_center()
	var bone: Transform3D = skel.global_transform * skel.get_bone_global_pose(bi)
	return bone.affine_inverse() * world


## What an identity attach would produce: the raw mesh centre, untransformed.
func _bundle_local_centre() -> Vector3:
	var packed: PackedScene = load(Civilian.SEEDLING_DONOR) as PackedScene
	var inst: Node = packed.instantiate()
	add_child(inst)
	var mi: MeshInstance3D = _bundle_mesh(inst)
	var c: Vector3 = mi.get_aabb().get_center() if mi != null else Vector3.INF
	inst.queue_free()
	return c


func _bundle_mesh(n: Node) -> MeshInstance3D:
	if n is MeshInstance3D and String(n.name).begins_with("rice_bundle"):
		return n as MeshInstance3D
	for c in n.get_children():
		var r: MeshInstance3D = _bundle_mesh(c)
		if r != null:
			return r
	return null


func _count_bundles(n: Node) -> int:
	var t: int = 1 if (n is MeshInstance3D and String(n.name).begins_with("rice_bundle")) else 0
	for c in n.get_children():
		t += _count_bundles(c)
	return t


func _socket(n: Node) -> Node:
	if n is BoneAttachment3D and String(n.name) == "SeedlingSocket":
		return n
	for c in n.get_children():
		var r: Node = _socket(c)
		if r != null:
			return r
	return null


func _skel(n: Node) -> Skeleton3D:
	if n is Skeleton3D:
		return n as Skeleton3D
	for c in n.get_children():
		var r: Skeleton3D = _skel(c)
		if r != null:
			return r
	return null


func _named(n: Node, nm: String) -> Node:
	if String(n.name) == nm:
		return n
	for c in n.get_children():
		var r: Node = _named(c, nm)
		if r != null:
			return r
	return null


func _any_mesh(n: Node) -> MeshInstance3D:
	if n is MeshInstance3D:
		return n as MeshInstance3D
	for c in n.get_children():
		var r: MeshInstance3D = _any_mesh(c)
		if r != null:
			return r
	return null
