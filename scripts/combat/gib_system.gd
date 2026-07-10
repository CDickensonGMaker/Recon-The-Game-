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
	},
	"ARM_L": {
		"bone": "mixamorig_LeftForeArm",
		"meshes": ["grunt_forearm_l"],
		"gear": [],
	},
	"ARM_R": {
		"bone": "mixamorig_RightForeArm",
		"meshes": ["grunt_forearm_r"],
		"gear": [],
	},
	"LEG_L": {
		"bone": "mixamorig_LeftUpLeg",
		"meshes": ["grunt_leg_l"],
		"gear": [],
	},
	"LEG_R": {
		"bone": "mixamorig_RightUpLeg",
		"meshes": ["grunt_leg_r"],
		"gear": [],
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
	#    that chain vanishes together (children bones inherit the scale).
	var bone_idx: int = skel.find_bone(str(spec["bone"]))
	if bone_idx < 0:
		print("[GORE] %s: rig has no bone '%s' - OFF-CONTRACT" % [model.unit, spec["bone"]])
		return false
	skel.set_bone_pose_scale(bone_idx, Vector3.ONE * 0.0001)

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
		_spawn_gib(mi.mesh, gib_at, hit_dir, 3.5, gib_parent)
		spawned = true
	for gear_name: String in spec["gear"]:
		var gm: MeshInstance3D = root.find_child(str(gear_name), true, false) as MeshInstance3D
		if gm == null or gm.mesh == null:
			continue
		var gxf: Transform3D = gm.global_transform
		gm.visible = false
		_spawn_gib(gm.mesh, gxf, hit_dir + Vector3.UP * 0.6, 2.2, gib_parent)

	# 3. blood burst at the stump (Phase-1 pipeline).
	var stump: Vector3 = skel.global_transform * skel.get_bone_global_pose(bone_idx).origin
	GunFX.blood(gib_parent, stump, -hit_dir.normalized(), hit_dir.normalized())
	return spawned


## A skinned mesh re-instanced WITHOUT its skeleton renders at bind pose in the
## rig's own space, so parenting the gib at the skeleton's global transform puts
## it exactly where the limb stood (v1: rest-pose placement, good enough at
## PSX fidelity) and inherits the export-compensation + ADR-002 normalization.
static func _spawn_gib(mesh: Mesh, at: Transform3D, dir: Vector3, force: float, parent: Node) -> void:
	var body := RigidBody3D.new()
	body.collision_layer = 0
	body.collision_mask = 1  # world only - gibs never block bullets or feet
	body.mass = 2.0

	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	body.add_child(mi)

	var aabb: AABB = mesh.get_aabb()
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = aabb.size.max(Vector3.ONE * 0.02)
	cs.shape = shape
	cs.position = aabb.get_center()
	body.add_child(cs)

	parent.add_child(body)
	body.global_transform = at
	var d: Vector3 = dir.normalized()
	body.linear_velocity = d * force + Vector3.UP * 2.8 + Vector3(randf() - 0.5, 0.0, randf() - 0.5)
	body.angular_velocity = Vector3(randf() - 0.5, randf() - 0.5, randf() - 0.5) * 8.0

	_live_gibs.append(body)
	while _live_gibs.size() > MAX_LIVE_GIBS:
		var oldest: Node = _live_gibs.pop_front()
		if is_instance_valid(oldest):
			oldest.queue_free()
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
