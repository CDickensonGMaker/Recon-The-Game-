## test_art_contract.gd - the attach-point and material contract.
##
## Run: godot --headless --path . res://tests/test_art_contract.tscn
## Re-bless the hat baseline (ONLY after eyes-on approval of a new seat):
##   godot --headless --path . res://tests/test_art_contract.tscn -- --bless
##
## THE HAT. Its position is BAKED at export by tools/make_civilians.py
## (HAT_NUDGE / HAT_DZ) - there is no runtime socket to inspect, so nothing in
## the engine could ever notice it drifting. It has been hand-corrected twice
## (0abdf2fb, 32ccc84f) and regressed twice, because the only instrument was
## somebody's eye in a playtest. This locks the measured seat: any re-export that
## moves the hat turns this red, and re-blessing is a deliberate act.
##
## Measurement is in HEAD-BONE space, normalised by the skull span
## (mixamorig_Head -> mixamorig_HeadTop_End - the same ruler hitzone_builder.gd
## uses), so it is scale-invariant. civ_kid has a 1.28m frame and would break any
## absolute-metres threshold.
##
## THE STRAPS. Canvas gear with no albedo texture renders at its raw albedo.
## Every canvas strap on the rig samples a *_canvas_od texture except one, whose
## material was authored pure white.
extends Node

const BASELINE_PATH := "res://tests/art_contract_baseline.json"

const HATTED: Array[String] = [
	"civ_farmer_m", "civ_farmer_m_b", "civ_farmer_m_c",
	"civ_farmer_f", "civ_farmer_f_b", "civ_farmer_f_c",
	"civ_elder", "civ_elder_b",
]

## Fractions of skull span. A hat that drifts more than this off its blessed
## seat is visible on the model.
const SEAT_TOL: float = 0.05

## Units whose straps must not render white.
const STRAPPED: Array[String] = ["us_grunt_rifleman", "us_grunt_pointman"]
## Above this on every channel with no albedo texture = it renders white.
const WHITE_LIMIT: float = 0.85

var failures: int = 0
var checks: int = 0
var bless: bool = false


func _ready() -> void:
	bless = OS.get_cmdline_user_args().has("--bless")
	await _hat_seat()
	_strap_materials()
	if failures > 0:
		print("FAIL: test_art_contract - %d failure(s) across %d checks" % [failures, checks])
	else:
		print("PASS: test_art_contract - %d checks" % checks)
	get_tree().quit(1 if failures > 0 else 0)


func _check(ok: bool, msg: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("  FAIL: " + msg)


func _hat_seat() -> void:
	var baseline: Dictionary = {}
	if FileAccess.file_exists(BASELINE_PATH):
		var txt: String = FileAccess.get_file_as_string(BASELINE_PATH)
		var parsed: Variant = JSON.parse_string(txt)
		if parsed is Dictionary:
			baseline = parsed
	var measured: Dictionary = {}

	for unit in HATTED:
		var ps: PackedScene = load(ModelActor.model_path(unit))
		if ps == null:
			_check(false, "%s: model will not load." % unit)
			continue
		var root: Node3D = ps.instantiate()
		add_child(root)
		var skel: Skeleton3D = _find_skel(root)
		if skel == null:
			_check(false, "%s: no Skeleton3D." % unit)
			root.queue_free()
			continue
		# Bone globals are stale until the skeleton is forced and the tree ticks.
		skel.force_update_all_bone_transforms()
		await get_tree().process_frame
		await get_tree().process_frame

		var hat: MeshInstance3D = _find_mesh(root, "hat_conical_worn")
		var hi: int = skel.find_bone("mixamorig_Head")
		var ti: int = skel.find_bone("mixamorig_HeadTop_End")
		_check(hat != null, "%s: no hat_conical_worn mesh." % unit)
		_check(hi >= 0 and ti >= 0, "%s: head bones missing." % unit)
		if hat == null or hi < 0 or ti < 0:
			root.queue_free()
			continue

		# A rigid, bone-parented hat. If it ever gains a skin it stops tracking
		# the head; if it stops matching HitzoneBuilder's gear hints it becomes a
		# fatal headshot hurtbox - a rice hat that can be sniped.
		_check(hat.skin == null,
			"%s: hat_conical_worn is skinned; worn gear must be rigid and bone-parented." % unit)
		_check(_matches_gear_hint(hat.name),
			"%s: hat name '%s' matches no HitzoneBuilder gear hint - it would be harvested into the HEAD hurtbox." % [unit, hat.name])

		var head_g: Transform3D = skel.global_transform * skel.get_bone_global_pose(hi)
		var top_g: Transform3D = skel.global_transform * skel.get_bone_global_pose(ti)
		var skull: float = head_g.origin.distance_to(top_g.origin)
		_check(skull > 0.01, "%s: degenerate skull span." % unit)
		if skull <= 0.01:
			root.queue_free()
			continue

		var aabb: AABB = hat.get_aabb()
		var local: Vector3 = head_g.affine_inverse() * (hat.global_transform * aabb.get_center())
		var dy: float = local.y / skull
		var dz: float = local.z / skull
		measured[unit] = {"dy": dy, "dz": dz}

		if baseline.has(unit):
			var b: Dictionary = baseline[unit]
			var ddy: float = absf(dy - float(b["dy"]))
			var ddz: float = absf(dz - float(b["dz"]))
			_check(ddy <= SEAT_TOL,
				"%s: hat moved %.3f skull-spans vertically (%.1fcm) from its blessed seat. Re-export changed HAT_NUDGE/HAT_DZ." % [unit, ddy, ddy * skull * 100.0])
			_check(ddz <= SEAT_TOL,
				"%s: hat moved %.3f skull-spans fore/aft (%.1fcm) from its blessed seat." % [unit, ddz, ddz * skull * 100.0])
		elif not bless:
			_check(false, "%s: no blessed hat seat on record. Run with -- --bless after eyes-on approval." % unit)
		root.queue_free()

	if bless:
		var f := FileAccess.open(BASELINE_PATH, FileAccess.WRITE)
		f.store_string(JSON.stringify(measured, "\t"))
		f.close()
		print("  BLESSED hat seats for %d units -> %s" % [measured.size(), BASELINE_PATH])


func _strap_materials() -> void:
	for unit in STRAPPED:
		var p: String = ModelActor.model_path(unit)
		if not ResourceLoader.exists(p):
			continue
		# Through ModelActor, not the raw PackedScene: the runtime gear-tint pass
		# is part of the contract and must be what the player actually sees.
		var ma := ModelActor.new()
		add_child(ma)
		if not ma.setup(unit):
			_check(false, "%s: ModelActor.setup failed." % unit)
			ma.queue_free()
			continue
		for mi in _all_mesh(ma):
			if not mi.name.begins_with("web_"):
				continue
			for s in range(mi.mesh.get_surface_count()):
				var eff: Material = mi.get_surface_override_material(s)
				if eff == null:
					eff = mi.mesh.surface_get_material(s)
				var bm := eff as BaseMaterial3D
				if bm == null:
					continue
				if bm.get_texture(BaseMaterial3D.TEXTURE_ALBEDO) != null:
					continue
				var c: Color = bm.albedo_color
				_check(not (c.r > WHITE_LIMIT and c.g > WHITE_LIMIT and c.b > WHITE_LIMIT),
					"%s/%s: material '%s' has no albedo texture and albedo #%s - it renders WHITE on an olive-drab man." % [unit, mi.name, bm.resource_name, c.to_html(false)])
		ma.queue_free()


func _matches_gear_hint(nm: String) -> bool:
	var low: String = nm.to_lower()
	for hint in HitzoneBuilder._GEAR_NAME_HINTS:
		if low.contains(hint):
			return true
	return false


func _all_mesh(n: Node) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
		out.append(n as MeshInstance3D)
	for c in n.get_children():
		out.append_array(_all_mesh(c))
	return out


func _find_mesh(n: Node, nm: String) -> MeshInstance3D:
	for mi in _all_mesh(n):
		if mi.name == nm:
			return mi
	return null


func _find_skel(n: Node) -> Skeleton3D:
	if n is Skeleton3D:
		return n as Skeleton3D
	for c in n.get_children():
		var s: Skeleton3D = _find_skel(c)
		if s != null:
			return s
	return null
