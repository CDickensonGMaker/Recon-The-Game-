## hitzone_builder.gd - ONE hitzone authority (beads 90gj + yd83).
##
## Zones are MEASURED from the rig's actual bone spans (skull height, shoulder
## width, limb lengths - the gore-dummy pattern, promoted here) and ride their
## bones every physics tick, so hitboxes track the animation instead of
## floating as static bands. The hand-placed capsule constants that used to
## live in enemy_base/ally_base are now only the no-rig fallback (sprite and
## capsule units).
##
## Per-unit overrides: data/hitzones/<unit>.tres (HitzoneTuning), authored in
## the hitzone bench. Applied on top of the measured values at build time.
##
## Corpse honesty: call sync() BEFORE any DEAD early-return - shooting bodies
## must keep registering zones.
class_name HitzoneBuilder
extends RefCounted

const TUNING_DIR := "res://data/hitzones/"

## Region color code, shared by every overlay/bench so the language is stable.
const REGION_COLORS: Dictionary = {
	"HEAD": Color(1.0, 0.15, 0.15), "BODY": Color(1.0, 0.9, 0.2),
	"GUT": Color(1.0, 0.55, 0.1), "ARM_L": Color(0.3, 0.6, 1.0),
	"ARM_R": Color(0.3, 0.6, 1.0), "LEG_L": Color(0.4, 0.4, 1.0),
	"LEG_R": Color(0.4, 0.4, 1.0),
}


## Build zones on `body`. Returns bone-sync entries [[hz, bone_idx, offset]..]
## (empty when the static fallback was used); feed them to sync() each tick.
## with_gut=false collapses GUT into a hips-to-neck BODY capsule (allies have
## no GUT damage handling).
static func build(body: Node3D, model: ModelActor, layer: int, mask: int,
		groups: Array[String], with_gut: bool = true) -> Array:
	var skel: Skeleton3D = model.skeleton() if model != null else null
	if skel == null:
		_build_static(body, layer, mask, groups, with_gut)
		return []

	var tuning: HitzoneTuning = null
	if model != null and not model.unit.is_empty():
		var tpath: String = TUNING_DIR + model.unit + ".tres"
		if ResourceLoader.exists(tpath):
			tuning = load(tpath) as HitzoneTuning

	var entries: Array = []
	var bw := func(bone: String) -> Vector3:
		var bi: int = skel.find_bone(bone)
		return (skel.global_transform * skel.get_bone_global_rest(bi).origin) if bi >= 0 else Vector3.ZERO

	# Span measurement with missing-bone honesty: a rig missing either bone
	# (v1 rigs lack mixamorig_HeadTop_End) returns the fallback instead of
	# measuring against the world origin, and every span is clamped to a human
	# window - a bad rig can never balloon a zone (the r=1.245 head bug).
	var span := func(bone_a: String, bone_b: String, fallback: float, lo: float, hi: float) -> float:
		if skel.find_bone(bone_a) < 0 or skel.find_bone(bone_b) < 0:
			return fallback
		var a: Vector3 = bw.call(bone_a)
		var b: Vector3 = bw.call(bone_b)
		return clampf(a.distance_to(b), lo, hi)

	# HEAD: sphere centered mid-skull (the joint-pair midpoint).
	var skull: float = span.call("mixamorig_Head", "mixamorig_HeadTop_End", 0.24, 0.18, 0.45)
	_zone(body, skel, entries, tuning, Hitzone.ZoneType.HEAD, "HEAD",
		skull * 0.72, -1.0, "mixamorig_Head", "mixamorig_HeadTop_End", Vector3.ZERO, layer, mask, groups)

	var shoulder_half: float = span.call("mixamorig_LeftArm", "mixamorig_RightArm", 0.44, 0.24, 0.7) * 0.5
	if with_gut:
		# TORSO: radius from real shoulder width (Caleb: the old chest-length
		# cap starved it to a rail - "the torso doesn't have anything"). The
		# capsule height stretches to fit the radius when the chest is short.
		var chest_len: float = span.call("mixamorig_Spine", "mixamorig_Neck", 0.4, 0.25, 0.7)
		# x1.15: arm-socket bones sit inboard of the visual shoulders on this
		# rig - measured half-width reads ~0.15 on a ~0.18 chest.
		var body_r: float = clampf(shoulder_half * 1.15, 0.15, 0.24)
		_zone(body, skel, entries, tuning, Hitzone.ZoneType.TORSO, "BODY",
			body_r, chest_len + body_r * 0.8, "mixamorig_Spine", "mixamorig_Neck", Vector3.ZERO, layer, mask, groups)
		# GUT: spans hips->spine, nudged down so the belly AND groin are
		# covered (a gut shot is a gut shot).
		var gut_len: float = span.call("mixamorig_Hips", "mixamorig_Spine", 0.2, 0.18, 0.5) + 0.14
		var gut_r: float = clampf(shoulder_half * 1.0, 0.13, 0.22)
		_zone(body, skel, entries, tuning, Hitzone.ZoneType.GUT, "GUT",
			gut_r, gut_len, "mixamorig_Hips", "mixamorig_Spine", Vector3(0, -0.07, 0), layer, mask, groups)
	else:
		# No GUT consumer: one BODY capsule covers hips -> neck.
		var trunk_len: float = span.call("mixamorig_Hips", "mixamorig_Neck", 0.55, 0.4, 0.9)
		var trunk_r: float = clampf(shoulder_half * 1.15, 0.15, 0.24)
		_zone(body, skel, entries, tuning, Hitzone.ZoneType.TORSO, "BODY",
			trunk_r, trunk_len + trunk_r * 0.6, "mixamorig_Hips", "mixamorig_Neck", Vector3.ZERO, layer, mask, groups)

	# ARMS/LEGS: capsules spanning the full limb joint-to-joint (midpoint
	# centered by sync - an anchor-centered capsule flared its far half out
	# past the hip on bent knees).
	for side in ["Left", "Right"]:
		var tag: String = "L" if side == "Left" else "R"
		var arm_len: float = span.call("mixamorig_%sArm" % side, "mixamorig_%sHand" % side, 0.55, 0.3, 0.9)
		_zone(body, skel, entries, tuning, Hitzone.ZoneType.LIMB, "ARM_%s" % tag,
			maxf(0.06, arm_len * 0.14), arm_len, "mixamorig_%sArm" % side, "mixamorig_%sHand" % side, Vector3.ZERO, layer, mask, groups)
		var leg_len: float = span.call("mixamorig_%sUpLeg" % side, "mixamorig_%sFoot" % side, 0.85, 0.4, 1.1)
		_zone(body, skel, entries, tuning, Hitzone.ZoneType.LIMB, "LEG_%s" % tag,
			maxf(0.07, leg_len * 0.13), leg_len, "mixamorig_%sUpLeg" % side, "mixamorig_%sFoot" % side, Vector3.ZERO, layer, mask, groups)
	return entries


## Ride the bones - position AND orientation. Each capsule aims its Y axis
## down the REAL joint-to-joint line (elbow->hand, knee->foot, spine->neck),
## computed live per tick - bone local axes are NOT trustworthy across export
## generations (Spine1's basis lay sideways on the v2 rig and turned the chest
## capsule horizontal). An angled limb keeps its zone in any pose.
## Offsets are zone-space (Y = along the limb). Call every physics tick,
## BEFORE any DEAD early-return.
static func sync(model: ModelActor, entries: Array) -> void:
	if model == null or entries.is_empty():
		return
	var skel: Skeleton3D = model.skeleton()
	if skel == null:
		return
	for entry in entries:
		var hz: Area3D = entry[0]
		var bi: int = entry[1]
		var off: Vector3 = entry[2]
		var aim_bi: int = entry[3]
		if not is_instance_valid(hz):
			continue
		var anchor: Vector3 = skel.global_transform * skel.get_bone_global_pose(bi).origin
		var origin: Vector3 = anchor
		var basis := Basis.IDENTITY
		if aim_bi >= 0:
			var to: Vector3 = skel.global_transform * skel.get_bone_global_pose(aim_bi).origin
			# MIDPOINT-SPANNING: the capsule bridges the two joints exactly,
			# in every pose - anchor-centered zones flared their far half.
			origin = (anchor + to) * 0.5
			var y: Vector3 = to - anchor
			if y.length_squared() > 0.0001:
				y = y.normalized()
				var ref: Vector3 = Vector3.FORWARD if absf(y.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT
				var x: Vector3 = y.cross(ref).normalized()
				basis = Basis(x, y, x.cross(y))
		hz.global_transform = Transform3D(basis, origin + basis * off)


static func _zone(body: Node3D, skel: Skeleton3D, entries: Array, tuning: HitzoneTuning,
		zone_type: Hitzone.ZoneType, region: String, radius: float, height: float,
		bone: String, aim_bone: String, bone_offset: Vector3, layer: int, mask: int, groups: Array[String]) -> void:
	# Measured baselines, stashed so the bench can compute save-deltas.
	var base_radius: float = radius
	var base_height: float = height
	var base_offset: Vector3 = bone_offset
	# Bench overrides win over measurement, key by key (radius/height absolute,
	# offset is a delta on the measured bone offset).
	if tuning != null and tuning.zones.has(region):
		var ov: Dictionary = tuning.zones[region]
		radius = float(ov.get("radius", radius))
		height = float(ov.get("height", height))
		bone_offset = bone_offset + Vector3(ov.get("offset", Vector3.ZERO))
	var hz := Hitzone.new()
	hz.zone_type = zone_type
	hz.set_owner_entity(body)
	hz.set_meta("region", region)
	hz.set_meta("base_radius", base_radius)
	hz.set_meta("base_height", base_height)
	hz.set_meta("base_offset", base_offset)
	var bi: int = skel.find_bone(bone)
	var col := CollisionShape3D.new()
	if height > 0.0:
		var cap := CapsuleShape3D.new()
		cap.radius = radius
		cap.height = height
		col.shape = cap
	else:
		var sphere := SphereShape3D.new()
		sphere.radius = radius
		col.shape = sphere
	hz.add_child(col)
	hz.collision_layer = layer
	hz.collision_mask = mask
	for g in groups:
		hz.add_to_group(g)
	body.add_child(hz)
	if bi >= 0:
		entries.append([hz, bi, bone_offset, skel.find_bone(aim_bone)])


## Legacy static bands - sprite/capsule units only.
static func _build_static(body: Node3D, layer: int, mask: int, groups: Array[String], with_gut: bool) -> void:
	var bands: Array = [
		[Hitzone.ZoneType.HEAD, "HEAD", Vector3(0, 1.65, 0), 0.15, -1.0],
		[Hitzone.ZoneType.LIMB, "ARM_L", Vector3(0.35, 1.0, 0), 0.12, 0.5],
		[Hitzone.ZoneType.LIMB, "ARM_R", Vector3(-0.35, 1.0, 0), 0.12, 0.5],
		[Hitzone.ZoneType.LIMB, "LEG_L", Vector3(0.12, 0.4, 0), 0.12, 0.8],
		[Hitzone.ZoneType.LIMB, "LEG_R", Vector3(-0.12, 0.4, 0), 0.12, 0.8],
	]
	if with_gut:
		bands.append([Hitzone.ZoneType.TORSO, "BODY", Vector3(0, 1.3, 0), 0.3, 0.35])
		bands.append([Hitzone.ZoneType.GUT, "GUT", Vector3(0, 0.9, 0), 0.28, 0.3])
	else:
		bands.append([Hitzone.ZoneType.TORSO, "BODY", Vector3(0, 1.1, 0), 0.3, 0.6])
	for b in bands:
		var hz := Hitzone.new()
		hz.zone_type = b[0]
		hz.set_owner_entity(body)
		hz.set_meta("region", b[1])
		var col := CollisionShape3D.new()
		var h: float = b[4]
		if h > 0.0:
			var cap := CapsuleShape3D.new()
			cap.radius = b[3]
			cap.height = h
			col.shape = cap
		else:
			var sphere := SphereShape3D.new()
			sphere.radius = b[3]
			col.shape = sphere
		col.position = b[2]
		hz.add_child(col)
		hz.collision_layer = layer
		hz.collision_mask = mask
		for g in groups:
			hz.add_to_group(g)
		body.add_child(hz)


## ---- wireframe drawing (shared by the bench + lab overlay) -----------------
## Appends one zone's wireframe into an already-begun ImmediateMesh surface
## (Mesh.PRIMITIVE_LINES). Capsules: two ring circles + 4 struts; spheres:
## 3 axis rings.
static func draw_zone_wire(im: ImmediateMesh, hz: Area3D) -> void:
	var col_node: CollisionShape3D = null
	for c in hz.get_children():
		if c is CollisionShape3D:
			col_node = c
			break
	if col_node == null or col_node.shape == null:
		return
	var color: Color = REGION_COLORS.get(str(hz.get_meta("region", "BODY")), Color.WHITE)
	var xf: Transform3D = col_node.global_transform
	var shape: Shape3D = col_node.shape
	if shape is SphereShape3D:
		var r: float = (shape as SphereShape3D).radius
		_wire_circle(im, xf, Vector3.ZERO, r, 0, color)
		_wire_circle(im, xf, Vector3.ZERO, r, 1, color)
		_wire_circle(im, xf, Vector3.ZERO, r, 2, color)
	elif shape is CapsuleShape3D:
		var cap := shape as CapsuleShape3D
		var half: float = maxf(0.0, cap.height * 0.5 - cap.radius)
		# Rings at cylinder ends AND cap crowns + 8 struts, so stubby capsules
		# read as volumes instead of a coincident ring pair.
		_wire_circle(im, xf, Vector3(0, half, 0), cap.radius, 1, color)
		_wire_circle(im, xf, Vector3(0, -half, 0), cap.radius, 1, color)
		_wire_circle(im, xf, Vector3(0, half + cap.radius * 0.7, 0), cap.radius * 0.7, 1, color)
		_wire_circle(im, xf, Vector3(0, -half - cap.radius * 0.7, 0), cap.radius * 0.7, 1, color)
		for i in range(8):
			var a: float = TAU * float(i) / 8.0
			var p := Vector3(cos(a) * cap.radius, 0, sin(a) * cap.radius)
			im.surface_set_color(color)
			im.surface_add_vertex(xf * (p + Vector3(0, half, 0)))
			im.surface_set_color(color)
			im.surface_add_vertex(xf * (p + Vector3(0, -half, 0)))


static func _wire_circle(im: ImmediateMesh, xf: Transform3D, center: Vector3, r: float, axis: int, color: Color) -> void:
	var segments: int = 20
	for i in range(segments):
		var a0: float = TAU * float(i) / float(segments)
		var a1: float = TAU * float(i + 1) / float(segments)
		var p0: Vector3
		var p1: Vector3
		match axis:
			0:  # YZ ring
				p0 = center + Vector3(0, cos(a0) * r, sin(a0) * r)
				p1 = center + Vector3(0, cos(a1) * r, sin(a1) * r)
			1:  # XZ ring
				p0 = center + Vector3(cos(a0) * r, 0, sin(a0) * r)
				p1 = center + Vector3(cos(a1) * r, 0, sin(a1) * r)
			_:  # XY ring
				p0 = center + Vector3(cos(a0) * r, sin(a0) * r, 0)
				p1 = center + Vector3(cos(a1) * r, sin(a1) * r, 0)
		im.surface_set_color(color)
		im.surface_add_vertex(xf * p0)
		im.surface_set_color(color)
		im.surface_add_vertex(xf * p1)
