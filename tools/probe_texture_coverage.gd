## probe_texture_coverage.gd - AN ASSET THAT RENDERS UNTEXTURED IS NOT FINISHED ART.
##
## Sibling of probe_orphaned_art.gd. That probe asks "does anything instantiate this
## model?"; this one asks "when it IS instantiated, does it have a texture on it?"
##
## Instantiates every mesh scene under res://assets/, walks each MeshInstance3D
## surface, and resolves the material the renderer will actually use:
##     surface_override_material -> mesh.surface_get_material -> (none = engine default)
## and reports every surface with no albedo/base-color texture bound.
##
##   godot --headless --path . res://tools/probe_texture_coverage.tscn
extends Node

const SCAN_ROOT: String = "res://assets/"
const MESH_EXT: Array[String] = ["glb", "gltf", "obj", "dae", "fbx", "blend"]
const TOP_OFFENDERS: int = 100

## Assets that are untextured BY DESIGN. Vertex-coloured, shader-driven, or pure
## collision/marker geometry. Keep this SHORT - an allowlist is where bald art hides.
const ALLOWED_SUBSTR: Array[String] = []

class Finding:
	var path: String
	var category: String
	var surfaces_total: int = 0
	var surfaces_bald: int = 0
	var surfaces_white: int = 0
	var no_material: int = 0

var _fails: int = 0
var _findings: Array[Finding] = []
var _broken_refs: Array[String] = []
var _load_errors: Array[String] = []


func _ready() -> void:
	await get_tree().process_frame
	print("\n=== TEXTURE COVERAGE: what renders bald? ===\n")

	var assets: Array[String] = []
	_collect(SCAN_ROOT, assets)
	assets.sort()

	if assets.is_empty():
		print("  [FAIL] no mesh assets found - the probe is looking in the wrong place")
		get_tree().quit(1)
		return

	for a in assets:
		_audit(a)

	_scan_broken_refs(SCAN_ROOT)
	_scan_broken_refs("res://scenes/")

	_report(assets.size())
	get_tree().quit(1 if _fails > 0 else 0)


func _audit(path: String) -> void:
	for s in ALLOWED_SUBSTR:
		if path.contains(s):
			return
	var res: Resource = ResourceLoader.load(path)
	if res == null:
		_load_errors.append(path)
		return
	if not (res is PackedScene):
		return
	var inst: Node = (res as PackedScene).instantiate()
	if inst == null:
		_load_errors.append(path)
		return

	var f := Finding.new()
	f.path = path
	f.category = _categorise(path)
	_walk(inst, f)
	inst.queue_free()

	if f.surfaces_bald > 0 or f.no_material > 0:
		_findings.append(f)


func _walk(n: Node, f: Finding) -> void:
	if n is MeshInstance3D:
		var mi: MeshInstance3D = n as MeshInstance3D
		var mesh: Mesh = mi.mesh
		if mesh != null:
			for i in mesh.get_surface_count():
				f.surfaces_total += 1
				var mat: Material = mi.get_active_material(i)
				if mat == null:
					f.no_material += 1
					continue
				if not _has_albedo(mat):
					f.surfaces_bald += 1
					if _is_untinted(mat):
						f.surfaces_white += 1
	for c in n.get_children():
		_walk(c, f)


## True only if the renderer will sample a real albedo/base-color image for this
## surface. A ShaderMaterial is opaque to inspection - counted as textured so the
## probe never accuses a shader it cannot read (see the CANNOT-DETECT list).
func _has_albedo(mat: Material) -> bool:
	if mat is ShaderMaterial:
		return true
	if mat is BaseMaterial3D:
		return (mat as BaseMaterial3D).albedo_texture != null
	return true


## A textureless surface carrying a deliberate PSX flat colour is authored art:
## pagoda.glb's Stone / White_Wall / Red_Lacquer are hand-picked and finished. A
## textureless surface still sitting on EXACTLY pure white never is - nobody authors
## (1,1,1) as a look, it is what a stub material defaults to. Only pure white counts.
##
## An earlier saturation-and-value test called any pale colour a placeholder and
## libelled every white-plaster wall in the village as broken art.
func _is_untinted(mat: Material) -> bool:
	if not (mat is BaseMaterial3D):
		return false
	var c: Color = (mat as BaseMaterial3D).albedo_color
	return is_equal_approx(c.r, 1.0) and is_equal_approx(c.g, 1.0) and is_equal_approx(c.b, 1.0)


## Broken ext refs: a .import/.tscn/.tres naming a source that is gone. Godot logs
## these at load and then renders the fallback, which is exactly the bald-white the
## Summoner saw in play.
func _scan_broken_refs(dir_path: String) -> void:
	var d := DirAccess.open(dir_path)
	if d == null:
		return
	d.list_dir_begin()
	var n: String = d.get_next()
	while n != "":
		var full: String = dir_path + n
		if d.current_is_dir():
			if not n.begins_with("."):
				_scan_broken_refs(full + "/")
		elif n.ends_with(".import") or n.ends_with(".tscn") or n.ends_with(".tres"):
			_check_refs(full)
		n = d.get_next()
	d.list_dir_end()


func _check_refs(path: String) -> void:
	var fa := FileAccess.open(path, FileAccess.READ)
	if fa == null:
		return
	var text: String = fa.get_as_text()
	var re := RegEx.new()
	re.compile('res://[^"\\]\\n]+')
	for m in re.search_all(text):
		var ref: String = m.get_string()
		if ref.begins_with("res://.godot/"):
			continue
		if ref.ends_with("/"):
			continue
		if not ResourceLoader.exists(ref) and not FileAccess.file_exists(ref):
			var entry: String = "%s -> %s" % [path, ref]
			if not entry in _broken_refs:
				_broken_refs.append(entry)


func _categorise(path: String) -> String:
	var p: String = path.to_lower()
	if p.contains("building models") or p.contains("/structures/"):
		return "BUILDINGS"
	if p.contains("/vegetation/") or p.contains("/foliage/"):
		return "VEGETATION"
	if p.contains("/characters/") or p.contains("/civilians/") or p.contains("/nva_vc/") or p.contains("/us/"):
		return "CHARACTERS"
	if p.contains("/weapons/") or p.contains("/viewmodels/") or p.contains("/arms/"):
		return "WEAPONS"
	if p.contains("/props/") or p.contains("/ordnance/") or p.contains("/vehicles/") or p.contains("/aircraft/"):
		return "PROPS"
	return "OTHER"


func _report(scanned: int) -> void:
	print("  %d mesh asset(s) scanned under %s" % [scanned, SCAN_ROOT])
	print("  %d asset(s) with at least one untextured surface" % _findings.size())
	print("  %d broken res:// reference(s)" % _broken_refs.size())
	print("  %d asset(s) failed to load/instantiate" % _load_errors.size())
	print("")

	var by_cat: Dictionary = {}
	for f in _findings:
		if not by_cat.has(f.category):
			by_cat[f.category] = []
		(by_cat[f.category] as Array).append(f)

	var order: Array[String] = ["BUILDINGS", "PROPS", "CHARACTERS", "VEGETATION", "WEAPONS", "OTHER"]
	for cat in order:
		if not by_cat.has(cat):
			continue
		var list: Array = by_cat[cat]
		list.sort_custom(func(a: Finding, b: Finding) -> bool:
			return (a.surfaces_bald + a.no_material) > (b.surfaces_bald + b.no_material))
		var bald_sum: int = 0
		var white_sum: int = 0
		for f in list:
			bald_sum += (f as Finding).surfaces_bald + (f as Finding).no_material
			white_sum += (f as Finding).surfaces_white + (f as Finding).no_material
		print("  --- %s: %d asset(s), %d untextured surface(s), %d of them untinted white/grey ---" % [
			cat, list.size(), bald_sum, white_sum])
		var shown: int = mini(list.size(), TOP_OFFENDERS)
		for i in shown:
			var f: Finding = list[i]
			print("      %-58s  %d/%d bald, %d white%s" % [
				f.path.replace(SCAN_ROOT, ""), f.surfaces_bald + f.no_material,
				f.surfaces_total, f.surfaces_white + f.no_material,
				("  (%d no material at all)" % f.no_material) if f.no_material > 0 else ""])
		if list.size() > shown:
			print("      ... and %d more in this category (true total above)" % (list.size() - shown))
		print("")

	if not _broken_refs.is_empty():
		print("  --- BROKEN res:// REFERENCES: %d ---" % _broken_refs.size())
		for i in mini(_broken_refs.size(), TOP_OFFENDERS):
			print("      %s" % _broken_refs[i])
		if _broken_refs.size() > TOP_OFFENDERS:
			print("      ... and %d more" % (_broken_refs.size() - TOP_OFFENDERS))
		print("")

	if not _load_errors.is_empty():
		print("  --- FAILED TO LOAD: %d ---" % _load_errors.size())
		for i in mini(_load_errors.size(), TOP_OFFENDERS):
			print("      %s" % _load_errors[i])
		print("")

	_check("no asset renders with an untextured surface", _findings.is_empty(),
		"%d asset(s)" % _findings.size())
	_check("no broken res:// reference", _broken_refs.is_empty(),
		"%d ref(s)" % _broken_refs.size())

	print("")
	if _fails == 0:
		print("*** EVERY SURFACE HAS A TEXTURE. ***")
	else:
		print("*** %d FAILURE(S) - art is rendering bald ***" % _fails)


func _collect(dir_path: String, out: Array[String]) -> void:
	var d := DirAccess.open(dir_path)
	if d == null:
		return
	d.list_dir_begin()
	var n: String = d.get_next()
	while n != "":
		var full: String = dir_path + n
		if d.current_is_dir():
			if not n.begins_with("."):
				_collect(full + "/", out)
		else:
			var stripped: String = n.trim_suffix(".import")
			if stripped.get_extension().to_lower() in MESH_EXT:
				var real: String = dir_path + stripped
				if not real in out:
					out.append(real)
		n = d.get_next()
	d.list_dir_end()


func _check(what: String, ok: bool, detail: String = "") -> void:
	if not ok:
		_fails += 1
	print("  [%s] %s%s" % ["PASS" if ok else "FAIL", what, ("   (%s)" % detail) if detail != "" else ""])
