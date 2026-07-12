## gib_system.gd - dismemberment v1 (GORE_WORKFLOW Phase 3: the 3-step pop).
##
## No mesh cutting, ever. The us_grunt_v2 rig contract (Bible 09 / bead 1xqs):
## per-region skinned meshes (grunt_<region>) + gore cap meshes (cap_<region>)
## baked INSIDE the character glb, gear bone-attached so it separates cleanly.
## Removal = collapse the region's bone chain (pose scale ~0) + hide the region
## mesh; the cap underneath becomes the stump. The gib = the region mesh
## re-spawned as a RigidBody3D with an impulse.
##
## Live-game trigger thresholds live in GORE_WORKFLOW (LIMB >= ~45 single-hit,
## HEAD kill >= ~60). This system just performs the pop; callers own the rules.
## The gore_lab bench calls it on every limb hit to verify rigs.
class_name GibSystem
extends Object

const MAX_LIVE_GIBS: int = 12
## Seconds a gib lies around. The gore lab raises this so rigs can be inspected.
static var gib_lifetime_s: float = 12.0

## Region contract: bone chain root to collapse, region meshes to hide/spawn,
## bone-attached gear meshes that fly off as their own gib (helmet money shot).
const REGIONS: Dictionary = {
	"HEAD": {
		"bone": "mixamorig_Neck",
		"meshes": ["grunt_head"],
		"gear": ["helmet_camo_shell", "helmet_bugjuice"],
		"caps": ["cap_head"],
	},
	"ARM_L": {
		"bone": "mixamorig_LeftForeArm",
		"meshes": ["grunt_forearm_l"],
		"gear": [],
		"caps": ["cap_forearm_l"],
	},
	"ARM_R": {
		"bone": "mixamorig_RightForeArm",
		"meshes": ["grunt_forearm_r"],
		"gear": [],
		"caps": ["cap_forearm_r"],
	},
	"LEG_L": {
		"bone": "mixamorig_LeftUpLeg",
		"meshes": ["grunt_leg_l"],
		"gear": [],
		"caps": ["cap_leg_l"],
	},
	"LEG_R": {
		"bone": "mixamorig_RightUpLeg",
		"meshes": ["grunt_leg_r"],
		"gear": [],
		"caps": ["cap_leg_r"],
	},
}

static var _live_gibs: Array[Node] = []


## Pop a region off a ModelActor-rendered character. Returns false when the rig
## lacks the contract pieces (old models, capsules) - caller just skips gore.
static func dismember(model: ModelActor, region: String, hit_dir: Vector3, gib_parent: Node) -> bool:
	if model == null or not model.has_visual():
		return false
	if not REGIONS.has(region):
		return false
	var spec: Dictionary = REGIONS[region]
	var skel: Skeleton3D = model.skeleton()
	var root: Node3D = model.instance_root()
	if skel == null or root == null:
		return false

	# 1. collapse the bone chain - every skinned mesh AND bone-attached gear on
	#    that chain vanishes together (children bones inherit the scale). The
	#    SeveredBonesModifier re-applies this AFTER any ragdoll sim each frame,
	#    or a blown-off head comes back the moment physics takes the skeleton.
	var bone_idx: int = skel.find_bone(str(spec["bone"]))
	if bone_idx < 0:
		print("[GORE] %s: rig has no bone '%s' - OFF-CONTRACT" % [model.unit, spec["bone"]])
		return false
	skel.set_bone_pose_scale(bone_idx, Vector3.ONE * 0.0001)
	var sever_mod: SeveredBonesModifier = skel.find_child("SeveredBones", false, false) as SeveredBonesModifier
	if sever_mod == null:
		sever_mod = SeveredBonesModifier.new()
		sever_mod.name = "SeveredBones"
		skel.add_child(sever_mod)
	sever_mod.sever(bone_idx)
	skel.move_child(sever_mod, skel.get_child_count() - 1)  # AFTER any ragdoll sim

	# 2. spawn the gibs: region meshes, then gear as its own lighter piece.
	var spawned: bool = false
	# Place the gib at the limb's CURRENT animated pose: the mesh's vertices are
	# authored at REST, so the gib root gets the delta (current pose x inverse
	# rest) - rest-space geometry lands where the animated limb actually is.
	var pose_delta: Transform3D = skel.get_bone_global_pose(bone_idx) * skel.get_bone_global_rest(bone_idx).affine_inverse()
	var gib_at: Transform3D = skel.global_transform * pose_delta
	for mesh_name: String in spec["meshes"]:
		var mi: MeshInstance3D = root.find_child(str(mesh_name), true, false) as MeshInstance3D
		if mi == null or mi.mesh == null:
			print("[GORE] %s: region mesh '%s' missing - OFF-CONTRACT" % [model.unit, mesh_name])
			continue
		mi.visible = false
		_spawn_gib(mi.mesh, gib_at, hit_dir, 3.5, gib_parent, model.gib_scale)
		spawned = true
	for gear_name: String in spec["gear"]:
		var gm: MeshInstance3D = root.find_child(str(gear_name), true, false) as MeshInstance3D
		if gm == null or gm.mesh == null:
			continue
		var gxf: Transform3D = gm.global_transform
		gm.visible = false
		_spawn_gib(gm.mesh, gxf, hit_dir + Vector3.UP * 0.6, 2.2, gib_parent)

	# 2.5 reveal the stump cap - caps ship hidden (setup hides them with the
	# donors; off-joint-skinned caps floated beside living VC otherwise).
	for cap_name: String in spec.get("caps", []):
		var cm: MeshInstance3D = root.find_child(str(cap_name), true, false) as MeshInstance3D
		if cm != null:
			cm.visible = true

	# 3. blood burst at the stump (Phase-1 pipeline).
	var stump: Vector3 = skel.global_transform * skel.get_bone_global_pose(bone_idx).origin
	GunFX.blood(gib_parent, stump, -hit_dir.normalized(), hit_dir.normalized())
	return spawned


## ---- HEAD BURST variant (bead rc55) -----------------------------------------
## If the rig ships cell-fractured head_frag_* donor meshes (Blender: 6-12
## chunks at rest pose, interiors on gore_tex), the skull bursts into flying
## fragments instead of popping as one piece. Occasional by design - the
## CALLER rolls the dice (~25% on heavy fatal headshots). Returns false when
## the rig has no fragments yet, so callers fall back to dismember("HEAD").
const MAX_LIVE_FRAGS: int = 16
static var _live_frags: Array[Node] = []


static func dismember_head_burst(model: ModelActor, hit_dir: Vector3, gib_parent: Node) -> bool:
	if model == null or not model.has_visual():
		return false
	var skel: Skeleton3D = model.skeleton()
	var root: Node3D = model.instance_root()
	if skel == null or root == null:
		return false
	var frags: Array[MeshInstance3D] = []
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for c in n.get_children():
			stack.push_back(c)
		var mi := n as MeshInstance3D
		if mi != null and mi.mesh != null and String(mi.name).begins_with("head_frag_"):
			frags.append(mi)
	if frags.is_empty():
		return false

	# Collapse the head chain exactly like dismember("HEAD").
	var spec: Dictionary = REGIONS["HEAD"]
	var bone_idx: int = skel.find_bone(str(spec["bone"]))
	if bone_idx < 0:
		return false
	skel.set_bone_pose_scale(bone_idx, Vector3.ONE * 0.0001)
	var sever_mod: SeveredBonesModifier = skel.find_child("SeveredBones", false, false) as SeveredBonesModifier
	if sever_mod == null:
		sever_mod = SeveredBonesModifier.new()
		sever_mod.name = "SeveredBones"
		skel.add_child(sever_mod)
	sever_mod.sever(bone_idx)
	skel.move_child(sever_mod, skel.get_child_count() - 1)

	# The one-piece head donor stays hidden - burst and pop are exclusive.
	for mesh_name: String in spec["meshes"]:
		var solid: MeshInstance3D = root.find_child(str(mesh_name), true, false) as MeshInstance3D
		if solid != null:
			solid.visible = false

	var pose_delta: Transform3D = skel.get_bone_global_pose(bone_idx) * skel.get_bone_global_rest(bone_idx).affine_inverse()
	var gib_at: Transform3D = skel.global_transform * pose_delta
	for f in frags:
		f.visible = false
		_spawn_frag(f.mesh, gib_at, hit_dir, gib_parent, model.gib_scale)
	# Gear (helmet) flies as its own lighter piece.
	for gear_name: String in spec["gear"]:
		var gm: MeshInstance3D = root.find_child(str(gear_name), true, false) as MeshInstance3D
		if gm != null and gm.mesh != null:
			var gxf: Transform3D = gm.global_transform
			gm.visible = false
			_spawn_gib(gm.mesh, gxf, hit_dir + Vector3.UP * 0.9, 3.0, gib_parent)
	for cap_name: String in spec.get("caps", []):
		var cm: MeshInstance3D = root.find_child(str(cap_name), true, false) as MeshInstance3D
		if cm != null:
			cm.visible = true
	var stump: Vector3 = skel.global_transform * skel.get_bone_global_pose(bone_idx).origin
	GunFX.blood(gib_parent, stump, -hit_dir.normalized(), hit_dir.normalized())
	GunFX.blood(gib_parent, stump, Vector3.UP, hit_dir.normalized())
	return true


## Small fast fragment: sphere collider, radial spray, own FIFO so a burst
## can't flush the body-part gib budget.
static func _spawn_frag(mesh: Mesh, at: Transform3D, dir: Vector3, parent: Node,
		mesh_scale: float = 1.0) -> void:
	var body := RigidBody3D.new()
	body.collision_layer = 0
	body.collision_mask = 1
	body.mass = 0.3
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.scale = Vector3.ONE * mesh_scale
	body.add_child(mi)
	var aabb: AABB = mesh.get_aabb()
	var cs := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = maxf(0.02, aabb.size.length() * mesh_scale * 0.25)
	cs.shape = sphere
	cs.position = aabb.get_center() * mesh_scale
	body.add_child(cs)
	parent.add_child(body)
	body.global_transform = at
	var radial := Vector3(randf() - 0.5, randf() * 0.7, randf() - 0.5).normalized()
	body.linear_velocity = (dir.normalized() * 0.6 + radial).normalized() * randf_range(3.5, 7.5) + Vector3.UP * randf_range(1.0, 3.0)
	body.angular_velocity = Vector3(randf() - 0.5, randf() - 0.5, randf() - 0.5) * 14.0
	for i in range(_live_frags.size() - 1, -1, -1):
		if not is_instance_valid(_live_frags[i]):
			_live_frags.remove_at(i)
	_live_frags.append(body)
	while _live_frags.size() > MAX_LIVE_FRAGS:
		var oldest: Variant = _live_frags.pop_front()
		if is_instance_valid(oldest):
			(oldest as Node).queue_free()
	var timer: SceneTreeTimer = body.get_tree().create_timer(gib_lifetime_s)
	timer.timeout.connect(func() -> void:
		if is_instance_valid(body):
			_live_frags.erase(body)
			body.queue_free())


## A skinned mesh re-instanced WITHOUT its skeleton renders at bind pose in the
## rig's own space, so parenting the gib at the skeleton's global transform puts
## it exactly where the limb stood (v1: rest-pose placement, good enough at
## PSX fidelity) and inherits the export-compensation + ADR-002 normalization.
static func _spawn_gib(mesh: Mesh, at: Transform3D, dir: Vector3, force: float, parent: Node,
		mesh_scale: float = 1.0) -> void:
	var body := RigidBody3D.new()
	body.collision_layer = 0
	body.collision_mask = 1  # world only - gibs never block bullets or feet
	body.mass = 2.0

	# mesh_scale: donor verts are BIND-space; the man renders at REST scale.
	# Scale the MESH child, never the RigidBody (physics hates scaled bodies).
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.scale = Vector3.ONE * mesh_scale
	body.add_child(mi)

	var aabb: AABB = mesh.get_aabb()
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = (aabb.size * mesh_scale).max(Vector3.ONE * 0.02)
	cs.shape = shape
	cs.position = aabb.get_center() * mesh_scale
	body.add_child(cs)

	parent.add_child(body)
	body.global_transform = at
	var d: Vector3 = dir.normalized()
	body.linear_velocity = d * force + Vector3.UP * 2.8 + Vector3(randf() - 0.5, 0.0, randf() - 0.5)
	body.angular_velocity = Vector3(randf() - 0.5, randf() - 0.5, randf() - 0.5) * 8.0

	for i in range(_live_gibs.size() - 1, -1, -1):
		if not is_instance_valid(_live_gibs[i]):
			_live_gibs.remove_at(i)
	_live_gibs.append(body)
	while _live_gibs.size() > MAX_LIVE_GIBS:
		var oldest: Variant = _live_gibs.pop_front()
		if is_instance_valid(oldest):
			(oldest as Node).queue_free()
	var timer: SceneTreeTimer = body.get_tree().create_timer(gib_lifetime_s)
	timer.timeout.connect(func() -> void:
		if is_instance_valid(body):
			_live_gibs.erase(body)
			body.queue_free())


## MissionScope hygiene - gore must not leak across missions.
static func clear_gibs() -> void:
	for g in _live_gibs:
		if is_instance_valid(g):
			g.queue_free()
	_live_gibs.clear()
