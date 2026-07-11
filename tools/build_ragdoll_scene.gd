## build_ragdoll_scene.gd - author the shared Mixamo physical skeleton ONCE
## (research/ragdoll.md section 1) and save it as a reusable PackedScene.
## Every character shares Mixamo bone names, so this one scene fits all rigs.
## 13 bones, Cone joints at ball sockets / Hinge at knees+elbows, capsules
## computed from the actual bone rest geometry, layer=1 mask=1 (corpse vs
## world only - research section 5).
## Run: godot --headless --path . -s tools/build_ragdoll_scene.gd
@tool
extends SceneTree

const OUT := "res://scenes/characters/ragdoll_mixamo.tscn"

## bone -> [child_bone_for_length, joint, radius, mass]
const BONES := {
	"mixamorig_Hips":         ["mixamorig_Spine", "none", 0.12, 10.0],
	"mixamorig_Spine":        ["mixamorig_Spine1", "cone", 0.11, 8.0],
	"mixamorig_Spine1":       ["mixamorig_Spine2", "cone", 0.11, 8.0],
	"mixamorig_Spine2":       ["mixamorig_Neck", "cone", 0.11, 8.0],
	"mixamorig_Head":         ["mixamorig_HeadTop_End", "cone", 0.10, 5.0],
	"mixamorig_LeftArm":      ["mixamorig_LeftForeArm", "cone", 0.06, 3.0],
	"mixamorig_RightArm":     ["mixamorig_RightForeArm", "cone", 0.06, 3.0],
	"mixamorig_LeftForeArm":  ["mixamorig_LeftHand", "hinge", 0.05, 2.0],
	"mixamorig_RightForeArm": ["mixamorig_RightHand", "hinge", 0.05, 2.0],
	"mixamorig_LeftUpLeg":    ["mixamorig_LeftLeg", "cone", 0.08, 7.0],
	"mixamorig_RightUpLeg":   ["mixamorig_RightLeg", "cone", 0.08, 7.0],
	"mixamorig_LeftLeg":      ["mixamorig_LeftFoot", "hinge", 0.06, 4.0],
	"mixamorig_RightLeg":     ["mixamorig_RightFoot", "hinge", 0.06, 4.0],
}


func _init() -> void:
	var packed: PackedScene = load("res://assets/models/characters/us_grunt_v2.glb")
	var inst: Node = packed.instantiate()
	var skel: Skeleton3D = inst.find_child("Skeleton3D", true, false) as Skeleton3D
	if skel == null:
		print("FAIL: no Skeleton3D")
		quit(1)
		return

	var sim := PhysicalBoneSimulator3D.new()
	sim.name = "RagdollSim"

	var made: int = 0
	for bone_name: String in BONES.keys():
		var spec: Array = BONES[bone_name]
		var bi: int = skel.find_bone(bone_name)
		var ci: int = skel.find_bone(str(spec[0]))
		if bi < 0:
			print("  SKIP %s (bone missing)" % bone_name)
			continue
		var head: Vector3 = skel.get_bone_global_rest(bi).origin
		var tail: Vector3 = head + Vector3.UP * 0.25
		if ci >= 0:
			tail = skel.get_bone_global_rest(ci).origin
		var length: float = maxf(0.12, head.distance_to(tail))

		var pb := PhysicalBone3D.new()
		pb.name = String(bone_name).replace("mixamorig_", "")
		pb.bone_name = bone_name
		# WEIGHT (Caleb: "bounces around crazy"): heavier bodies, strong damping,
		# zero bounce - a corpse thuds and settles, it does not pinball.
		pb.mass = float(spec[3]) * 1.6
		pb.linear_damp = 2.2
		pb.angular_damp = 7.0
		pb.can_sleep = true
		var pmat := PhysicsMaterial.new()
		pmat.friction = 1.2
		pmat.bounce = 0.0
		pb.set("physics_material_override", pmat)
		pb.collision_layer = 1
		pb.collision_mask = 1
		match str(spec[1]):
			"cone":
				pb.joint_type = PhysicalBone3D.JOINT_TYPE_CONE
				pb.set("joint_constraints/swing_span", deg_to_rad(40.0))
				pb.set("joint_constraints/twist_span", deg_to_rad(25.0))
			"hinge":
				pb.joint_type = PhysicalBone3D.JOINT_TYPE_HINGE
				pb.set("joint_constraints/angular_limit_enabled", true)
				pb.set("joint_constraints/angular_limit_lower", deg_to_rad(-5.0))
				pb.set("joint_constraints/angular_limit_upper", deg_to_rad(120.0))
			_:
				pb.joint_type = PhysicalBone3D.JOINT_TYPE_NONE

		# node at the bone head, +Y toward the child; capsule spans the bone
		var y: Vector3 = (tail - head).normalized()
		var x: Vector3 = y.cross(Vector3.FORWARD)
		if x.length_squared() < 0.01:
			x = y.cross(Vector3.RIGHT)
		x = x.normalized()
		var z: Vector3 = x.cross(y).normalized()
		pb.transform = Transform3D(Basis(x, y, z), head)

		var col := CollisionShape3D.new()
		var cap := CapsuleShape3D.new()
		cap.radius = float(spec[2])
		cap.height = maxf(length, cap.radius * 2.1)
		col.shape = cap
		col.position = Vector3(0, length * 0.5, 0)
		pb.add_child(col)
		sim.add_child(pb)
		made += 1
		print("  %s len=%.2f r=%.2f joint=%s" % [pb.name, length, float(spec[2]), str(spec[1])])

	# ownership so PackedScene.pack captures the whole subtree
	for pb in sim.get_children():
		pb.owner = sim
		for c in pb.get_children():
			c.owner = sim

	var out := PackedScene.new()
	if out.pack(sim) != OK:
		print("FAIL: pack")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute("res://scenes/characters")
	var err := ResourceSaver.save(out, OUT)
	print("%s: %d physical bones -> %s" % ["SAVED" if err == OK else "FAIL", made, OUT])
	inst.free()
	quit(0 if err == OK else 1)
