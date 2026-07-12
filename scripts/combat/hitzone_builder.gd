## hitzone_builder.gd - ONE hitzone authority (beads 90gj + yd83 + trqx).
##
## HITZONE 2.0 (trqx): zones are CONVEX HULLS cut from the character's actual
## body mesh - every vertex claimed by its dominant skin bone, bones grouped
## into 11 regions (limbs split upper/lower). The hull hugs the real
## silhouette instead of a formula-fattened capsule. Measured capsules remain
## the fallback for regions with no usable skin data; the hand-placed static
## bands remain for sprite/capsule units. Gear/headgear meshes are EXCLUDED
## from harvesting (a rice hat must not be a fatal headshot); hidden gib
## donors and cap_*/head_frag_* gore meshes are skipped. An artist mesh named
## hit_<REGION> in the GLB overrides that region's auto-hull outright (and is
## hidden - it is collision, not render).
##
## Zones ride their bones every physics tick (sync) - position AND
## orientation - with optional per-zone rotation overrides from the bench.
## Per-unit overrides: data/hitzones/<unit>.tres (HitzoneTuning), authored in
## the hitzone bench: offset/rotation both shape families, inflate (hull,
## meters outward) or radius/height (capsule), damage/fatal (ADR-016
## Amendment B).
##
## Corpse honesty: call sync() BEFORE any DEAD early-return - shooting bodies
## must keep registering zones.
class_name HitzoneBuilder
extends RefCounted

const TUNING_DIR := "res://data/hitzones/"

## Region color code, shared by every overlay/bench so the language is stable.
## Legacy 4-limb names kept for the static bands + gore_dummy overlay.
const REGION_COLORS: Dictionary = {
	"HEAD": Color(1.0, 0.15, 0.15), "BODY": Color(1.0, 0.9, 0.2),
	"GUT": Color(1.0, 0.55, 0.1),
	"ARM_L_UP": Color(0.3, 0.6, 1.0), "ARM_L_LO": Color(0.45, 0.75, 1.0),
	"ARM_R_UP": Color(0.3, 0.6, 1.0), "ARM_R_LO": Color(0.45, 0.75, 1.0),
	"LEG_L_UP": Color(0.4, 0.4, 1.0), "LEG_L_LO": Color(0.55, 0.55, 1.0),
	"LEG_R_UP": Color(0.4, 0.4, 1.0), "LEG_R_LO": Color(0.55, 0.55, 1.0),
	"ARM_L": Color(0.3, 0.6, 1.0), "ARM_R": Color(0.3, 0.6, 1.0),
	"LEG_L": Color(0.4, 0.4, 1.0), "LEG_R": Color(0.4, 0.4, 1.0),
}

## Mesh-name fragments that mark gear/headgear - never harvested into hulls.
const _GEAR_NAME_HINTS: Array[String] = ["hat", "helmet", "boonie", "pith",
	"rice", "gear", "pack", "pouch", "belt", "canteen", "strap", "webbing",
	"bandolier", "glasses"]

## unit(+gut variant) -> {region: PackedVector3Array} zone-local hull points,
## harvested once per unit type - spawning 20 enemies costs one extraction.
static var _hull_cache: Dictionary = {}


## Strip the _UP/_LO segment suffix: gib donors + gore maps speak the 4-limb
## language (gib_system.gd GIB map keys ARM_L/ARM_R/LEG_L/LEG_R).
static func base_region(region: String) -> String:
	return region.trim_suffix("_UP").trim_suffix("_LO")


## Build zones on `body`. Returns bone-sync entries
## [[hz, bone_idx, offset, aim_bone_idx, rot_basis]..] (empty when the static
## fallback was used); feed them to sync() each physics tick.
## with_gut=false collapses GUT into a hips-to-neck BODY zone (allies have no
## GUT damage handling).
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

	var hulls: Dictionary = _hulls_for(model, skel, with_gut)
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

	# HEAD: hull from skull verts, else sphere centered mid-skull.
	var skull: float = span.call("mixamorig_Head", "mixamorig_HeadTop_End", 0.24, 0.18, 0.45)
	_zone(body, skel, entries, tuning, Hitzone.ZoneType.HEAD, "HEAD",
		skull * 0.72, -1.0, "mixamorig_Head", "mixamorig_HeadTop_End", Vector3.ZERO,
		layer, mask, groups, hulls.get("HEAD", PackedVector3Array()))

	var shoulder_half: float = span.call("mixamorig_LeftArm", "mixamorig_RightArm", 0.44, 0.24, 0.7) * 0.5
	if with_gut:
		# TORSO: capsule fallback radius from real shoulder width (Caleb: the
		# old chest-length cap starved it to a rail).
		var chest_len: float = span.call("mixamorig_Spine", "mixamorig_Neck", 0.4, 0.25, 0.7)
		var body_r: float = clampf(shoulder_half * 1.15, 0.15, 0.24)
		_zone(body, skel, entries, tuning, Hitzone.ZoneType.TORSO, "BODY",
			body_r, chest_len + body_r * 0.8, "mixamorig_Spine", "mixamorig_Neck", Vector3.ZERO,
			layer, mask, groups, hulls.get("BODY", PackedVector3Array()))
		# GUT: spans hips->spine, capsule nudged down so belly AND groin are
		# covered (a gut shot is a gut shot).
		var gut_len: float = span.call("mixamorig_Hips", "mixamorig_Spine", 0.2, 0.18, 0.5) + 0.14
		var gut_r: float = clampf(shoulder_half * 1.0, 0.13, 0.22)
		_zone(body, skel, entries, tuning, Hitzone.ZoneType.GUT, "GUT",
			gut_r, gut_len, "mixamorig_Hips", "mixamorig_Spine", Vector3(0, -0.07, 0),
			layer, mask, groups, hulls.get("GUT", PackedVector3Array()))
	else:
		# No GUT consumer: one BODY zone covers hips -> neck.
		var trunk_len: float = span.call("mixamorig_Hips", "mixamorig_Neck", 0.55, 0.4, 0.9)
		var trunk_r: float = clampf(shoulder_half * 1.15, 0.15, 0.24)
		_zone(body, skel, entries, tuning, Hitzone.ZoneType.TORSO, "BODY",
			trunk_r, trunk_len + trunk_r * 0.6, "mixamorig_Hips", "mixamorig_Neck", Vector3.ZERO,
			layer, mask, groups, hulls.get("BODY", PackedVector3Array()))

	# LIMBS split upper/lower (trqx): 2 zones per arm and leg, each spanning
	# one bone segment joint-to-joint. Radii are fallback-capsule only - hull
	# zones take their shape from the mesh.
	for side in ["Left", "Right"]:
		var tag: String = "L" if side == "Left" else "R"
		var segs: Array = [
			["ARM_%s_UP" % tag, "mixamorig_%sArm" % side, "mixamorig_%sForeArm" % side, 0.28, 0.22, 0.05, 0.09],
			["ARM_%s_LO" % tag, "mixamorig_%sForeArm" % side, "mixamorig_%sHand" % side, 0.27, 0.20, 0.045, 0.08],
			["LEG_%s_UP" % tag, "mixamorig_%sUpLeg" % side, "mixamorig_%sLeg" % side, 0.42, 0.26, 0.07, 0.12],
			["LEG_%s_LO" % tag, "mixamorig_%sLeg" % side, "mixamorig_%sFoot" % side, 0.43, 0.20, 0.055, 0.10],
		]
		for s in segs:
			var seg_len: float = span.call(s[1], s[2], s[3], float(s[3]) * 0.5, float(s[3]) * 1.6)
			_zone(body, skel, entries, tuning, Hitzone.ZoneType.LIMB, s[0],
				clampf(seg_len * float(s[4]), float(s[5]), float(s[6])), seg_len,
				s[1], s[2], Vector3.ZERO, layer, mask, groups,
				hulls.get(s[0], PackedVector3Array()))
	return entries


## Ride the bones - position AND orientation. Each zone aims its Y axis down
## the REAL joint-to-joint line (elbow->hand, knee->foot, spine->neck),
## computed live per tick - bone local axes are NOT trustworthy across export
## generations (Spine1's basis lay sideways on the v2 rig and turned the chest
## capsule horizontal). An angled limb keeps its zone in any pose. The bench's
## per-zone rotation override (entry[4]) composes on top of the joint basis.
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
		var rot: Basis = entry[4] if entry.size() > 4 else Basis.IDENTITY
		if not is_instance_valid(hz):
			continue
		var anchor: Vector3 = skel.global_transform * skel.get_bone_global_pose(bi).origin
		var origin: Vector3 = anchor
		var basis := Basis.IDENTITY
		if aim_bi >= 0:
			var to: Vector3 = skel.global_transform * skel.get_bone_global_pose(aim_bi).origin
			# MIDPOINT-SPANNING: the zone bridges the two joints exactly,
			# in every pose - anchor-centered zones flared their far half.
			origin = (anchor + to) * 0.5
			var y: Vector3 = to - anchor
			if y.length_squared() > 0.0001:
				y = y.normalized()
				var ref: Vector3 = Vector3.FORWARD if absf(y.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT
				var x: Vector3 = y.cross(ref).normalized()
				basis = Basis(x, y, x.cross(y))
		basis = basis * rot
		hz.global_transform = Transform3D(basis, origin + basis * off)


## ---- mesh hull harvesting (trqx) -------------------------------------------

## Harvest per-region hull point clouds from the unit's body meshes, once per
## unit type. Points are zone-local (same frame sync() rebuilds each tick) and
## scaled to world units (ModelActor's k-rescale is baked in - us_medic k=2.3
## must not ship half-size hulls).
static func _hulls_for(model: ModelActor, skel: Skeleton3D, with_gut: bool) -> Dictionary:
	var key: String = str(model.unit) + ("|g" if with_gut else "|ng")
	if _hull_cache.has(key):
		return _hull_cache[key]
	var out: Dictionary = {}
	var root: Node3D = model.instance_root()
	if root != null:
		var frames: Dictionary = _rest_frames(skel, with_gut)
		var k: float = skel.global_transform.basis.get_scale().x
		var pts: Dictionary = {}
		var overrides: Array = []
		var stack: Array = [root]
		while not stack.is_empty():
			var n: Node = stack.pop_back()
			for c in n.get_children():
				stack.push_back(c)
			var mi := n as MeshInstance3D
			if mi == null or mi.mesh == null:
				continue
			var nm: String = String(mi.name).to_lower()
			if nm.begins_with("hit_"):
				overrides.append(mi)
				continue
			if not mi.visible:
				continue  # hidden gib donors stay out of the silhouette
			if nm.begins_with("cap_") or nm.begins_with("head_frag_"):
				continue
			var is_gear: bool = false
			for h in _GEAR_NAME_HINTS:
				if nm.contains(h):
					is_gear = true
					break
			if is_gear or mi.skin == null:
				continue
			_harvest(mi, skel, _bind_regions(mi.skin, skel, with_gut), frames, pts, "", k)
		# Artist overrides win outright, whatever the tree order: hit_<REGION>
		# mesh IS the zone. Hidden - it is collision authoring, not render.
		for o in overrides:
			var omi := o as MeshInstance3D
			var forced: String = String(omi.name).substr(4).to_upper()
			if frames.has(forced):
				pts[forced] = []
				_harvest(omi, skel, PackedStringArray(), frames, pts, forced, k)
				omi.visible = false
		for region in pts:
			var condensed: PackedVector3Array = _condense(pts[region])
			if condensed.size() >= 4:
				out[region] = condensed
	_hull_cache[key] = out
	return out


## Dominant-bone vertex claim: each vertex joins the region of its heaviest
## skin weight. forced != "" routes every vertex to that region (hit_ meshes).
static func _harvest(mi: MeshInstance3D, skel: Skeleton3D, bind_regions: PackedStringArray,
		frames: Dictionary, pts: Dictionary, forced: String, k: float) -> void:
	var to_skel: Transform3D = skel.global_transform.affine_inverse() * mi.global_transform
	for s in range(mi.mesh.get_surface_count()):
		var arrays: Array = mi.mesh.surface_get_arrays(s)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var bones: PackedInt32Array = PackedInt32Array()
		var weights = arrays[Mesh.ARRAY_WEIGHTS]
		if forced.is_empty():
			bones = arrays[Mesh.ARRAY_BONES]
			if bones.is_empty() or weights == null or verts.is_empty():
				continue
		var influences: int = (bones.size() / verts.size()) if (forced.is_empty() and verts.size() > 0) else 0
		for vi in range(verts.size()):
			var region: String = forced
			if region.is_empty():
				var best_w: float = -1.0
				var best_b: int = -1
				for j in range(influences):
					var w: float = float(weights[vi * influences + j])
					if w > best_w:
						best_w = w
						best_b = bones[vi * influences + j]
				if best_b < 0 or best_b >= bind_regions.size():
					continue
				region = bind_regions[best_b]
			if region.is_empty() or not frames.has(region):
				continue
			var frame: Transform3D = frames[region]
			var local: Vector3 = frame.affine_inverse() * (to_skel * verts[vi])
			# Plain Array on purpose: Packed*Array is copy-on-write - appending
			# through a Dictionary cast mutates a temporary, not the stored one.
			if not pts.has(region):
				pts[region] = []
			(pts[region] as Array).append(local * k)


## Skin bind slot -> region name (ARRAY_BONES indices are skin-relative, NOT
## skeleton bone indices - mapping through bind names is the honest path).
static func _bind_regions(sk: Skin, skel: Skeleton3D, with_gut: bool) -> PackedStringArray:
	var regions := PackedStringArray()
	for i in range(sk.get_bind_count()):
		var bn: String = sk.get_bind_name(i)
		if bn.is_empty():
			var bi: int = sk.get_bind_bone(i)
			bn = skel.get_bone_name(bi) if bi >= 0 and bi < skel.get_bone_count() else ""
		regions.append(_bone_region(bn, with_gut))
	return regions


static func _bone_region(bone_name: String, with_gut: bool) -> String:
	var b: String = bone_name.trim_prefix("mixamorig_")
	if b == "Head" or b.begins_with("HeadTop"):
		return "HEAD"
	if b == "Neck" or b == "Spine1" or b == "Spine2" or b.ends_with("Shoulder"):
		return "BODY"
	if b == "Hips" or b == "Spine":
		return "GUT" if with_gut else "BODY"
	for side in ["Left", "Right"]:
		var tag: String = "L" if side == "Left" else "R"
		if b == side + "Arm":
			return "ARM_%s_UP" % tag
		if b == side + "ForeArm" or b.begins_with(side + "Hand"):
			return "ARM_%s_LO" % tag
		if b == side + "UpLeg":
			return "LEG_%s_UP" % tag
		if b == side + "Leg" or b == side + "Foot" or b.begins_with(side + "Toe"):
			return "LEG_%s_LO" % tag
	return ""  # weapon bones, sockets, IK helpers - not body


## Region -> rest-pose zone frame (skeleton space), mirroring sync()'s
## joint-pair framing so harvested points land exactly where the live zone
## will carry them.
static func _rest_frames(skel: Skeleton3D, with_gut: bool) -> Dictionary:
	var frames: Dictionary = {}
	var pairs: Array = [["HEAD", "mixamorig_Head", "mixamorig_HeadTop_End"]]
	if with_gut:
		pairs.append(["BODY", "mixamorig_Spine", "mixamorig_Neck"])
		pairs.append(["GUT", "mixamorig_Hips", "mixamorig_Spine"])
	else:
		pairs.append(["BODY", "mixamorig_Hips", "mixamorig_Neck"])
	for side in ["Left", "Right"]:
		var tag: String = "L" if side == "Left" else "R"
		pairs.append(["ARM_%s_UP" % tag, "mixamorig_%sArm" % side, "mixamorig_%sForeArm" % side])
		pairs.append(["ARM_%s_LO" % tag, "mixamorig_%sForeArm" % side, "mixamorig_%sHand" % side])
		pairs.append(["LEG_%s_UP" % tag, "mixamorig_%sUpLeg" % side, "mixamorig_%sLeg" % side])
		pairs.append(["LEG_%s_LO" % tag, "mixamorig_%sLeg" % side, "mixamorig_%sFoot" % side])
	for p in pairs:
		var ai: int = skel.find_bone(p[1])
		var bi: int = skel.find_bone(p[2])
		if ai < 0 or bi < 0:
			continue
		var a: Vector3 = skel.get_bone_global_rest(ai).origin
		var b: Vector3 = skel.get_bone_global_rest(bi).origin
		var origin: Vector3 = (a + b) * 0.5
		var basis := Basis.IDENTITY
		var y: Vector3 = b - a
		if y.length_squared() > 0.0001:
			y = y.normalized()
			var ref: Vector3 = Vector3.FORWARD if absf(y.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT
			var x: Vector3 = y.cross(ref).normalized()
			basis = Basis(x, y, x.cross(y))
		frames[p[0]] = Transform3D(basis, origin)
	return frames


## Quantize to a 1.5cm grid + dedupe: PSX-region point clouds condense to a
## few dozen hull candidates - GJK stays cheap, silhouette fidelity intact.
static func _condense(raw: Array) -> PackedVector3Array:
	var seen: Dictionary = {}
	var out := PackedVector3Array()
	for p in raw:
		var v: Vector3 = p
		var cell := Vector3i((v / 0.015).round())
		if seen.has(cell):
			continue
		seen[cell] = true
		out.append(v)
	return out


## Hull shape with an outward inflate margin (meters) - the fairness pad.
static func _hull_shape(points: PackedVector3Array, inflate: float) -> ConvexPolygonShape3D:
	var shape := ConvexPolygonShape3D.new()
	if absf(inflate) < 0.0005:
		shape.points = points
		return shape
	var c := Vector3.ZERO
	for p in points:
		c += p
	c /= float(points.size())
	var out := PackedVector3Array()
	for p in points:
		var d: Vector3 = p - c
		out.append(p + (d.normalized() * inflate if d.length() > 0.0001 else Vector3.ZERO))
	shape.points = out
	return shape


static func _zone(body: Node3D, skel: Skeleton3D, entries: Array, tuning: HitzoneTuning,
		zone_type: Hitzone.ZoneType, region: String, radius: float, height: float,
		bone: String, aim_bone: String, bone_offset: Vector3, layer: int, mask: int,
		groups: Array[String], hull: PackedVector3Array = PackedVector3Array()) -> void:
	# Measured baselines, stashed so the bench can compute save-deltas.
	var base_radius: float = radius
	var base_height: float = height
	var base_offset: Vector3 = bone_offset
	# Bench overrides win over measurement, key by key (radius/height absolute,
	# offset is a delta on the measured bone offset).
	var ov: Dictionary = {}
	if tuning != null and tuning.zones.has(region):
		ov = tuning.zones[region]
		radius = float(ov.get("radius", radius))
		height = float(ov.get("height", height))
		bone_offset = bone_offset + Vector3(ov.get("offset", Vector3.ZERO))
	var rot_deg: Vector3 = Vector3(ov.get("rotation", Vector3.ZERO))
	var inflate: float = float(ov.get("inflate", 0.0))
	var hz := Hitzone.new()
	hz.zone_type = zone_type
	# Damage overrides (ADR-016 Amendment B): per-unit multiplier / fatality.
	if ov.has("damage"):
		hz.damage_mult_override = maxf(0.0, float(ov["damage"]))
	if ov.has("fatal"):
		hz.fatal_override = 1 if bool(ov["fatal"]) else 0
	hz.set_owner_entity(body)
	hz.set_meta("region", region)
	hz.set_meta("base_radius", base_radius)
	hz.set_meta("base_height", base_height)
	hz.set_meta("base_offset", base_offset)
	hz.set_meta("rot_deg", rot_deg)
	var bi: int = skel.find_bone(bone)
	var col := CollisionShape3D.new()
	if hull.size() >= 4:
		col.shape = _hull_shape(hull, inflate)
		hz.set_meta("hull_points", hull)
		hz.set_meta("inflate", inflate)
	elif height > 0.0:
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
		entries.append([hz, bi, bone_offset, skel.find_bone(aim_bone),
			Basis.from_euler(rot_deg * (PI / 180.0))])


## Legacy static bands - sprite/capsule units only (coarse 4-limb layout).
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
## 3 axis rings; hulls: the shape's own debug line mesh (cached per zone -
## get_debug_mesh() allocates; the cache is cleared when the bench re-inflates).
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
	elif shape is ConvexPolygonShape3D:
		var wire: PackedVector3Array
		if hz.has_meta("wire_pts"):
			wire = hz.get_meta("wire_pts")
		else:
			wire = PackedVector3Array()
			var dbg: Mesh = shape.get_debug_mesh()
			if dbg != null and dbg.get_surface_count() > 0:
				wire = dbg.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
			hz.set_meta("wire_pts", wire)
		for i in range(0, wire.size() - 1, 2):
			im.surface_set_color(color)
			im.surface_add_vertex(xf * wire[i])
			im.surface_set_color(color)
			im.surface_add_vertex(xf * wire[i + 1])
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
