## probe_material_budget.gd - ADR-026 Part A material audit (measurement, not a fix).
## Walks every GLB in the vegetation rings and the firebase/helipad structure kits and
## reports the four PS2-budget material properties that cost fill: transparency mode,
## cull mode, shading mode, specular mode.
##   godot --headless --path . -s res://tools/probe_material_budget.gd
## Pass `--after` to apply MaterialBudget to everything first and re-count, which is the
## no-regression evidence that the code-side fix reaches the shipped meshes.
## Blended transparency on close-range SOLID geometry (sandbags) and cull_disabled on
## single-sided foliage are the two defects this instrument exists to count.
extends SceneTree

const VEG_SOLID := "res://assets/world/vegetation/"
const VEG_CARDS := "res://assets/world/vegetation/cards/"
const STRUCT_DIRS: Array[String] = [
	"res://assets/world/building models/structures/firebase/",
	"res://assets/world/building models/structures/firebase/kit/",
	"res://assets/world/building models/structures/emplacements_real/",
	"res://assets/world/building models/structures/converted/",
]

var _apply: bool = false


func _initialize() -> void:
	_apply = OS.get_cmdline_args().has("--after")
	print("\n=== MATERIAL BUDGET PROBE (ADR-026 Part A.2 / A.5) %s ===" % (
		"[AFTER: MaterialBudget applied]" if _apply else "[AS IMPORTED]"))
	_audit("VEG_CARDS", _glbs(VEG_CARDS))
	_audit("VEG_SOLID", _glbs(VEG_SOLID))
	var struct_files: Array[String] = []
	for d: String in STRUCT_DIRS:
		struct_files.append_array(_glbs(d))
	_audit("STRUCTURES", struct_files)
	quit(0)


func _glbs(dir_path: String) -> Array[String]:
	var out: Array[String] = []
	var d := DirAccess.open(dir_path)
	if d == null:
		return out
	for f: String in d.get_files():
		if f.get_extension().to_lower() == "glb":
			out.append(dir_path + f)
	out.sort()
	return out


func _audit(label: String, files: Array[String]) -> void:
	var mats: int = 0
	var blended: int = 0
	var scissor: int = 0
	var opaque: int = 0
	var hashed: int = 0
	var prepass: int = 0
	var cull_off: int = 0
	var per_pixel: int = 0
	var specular_on: int = 0
	var offenders: Array[String] = []
	for path: String in files:
		var packed: PackedScene = load(path) as PackedScene
		if packed == null:
			continue
		var root: Node = packed.instantiate()
		if _apply:
			if label == "STRUCTURES":
				MaterialBudget.structure(root)
			else:
				_apply_foliage(root)
		var found: Array[BaseMaterial3D] = []
		_collect(root, found)
		var file_blended: int = 0
		var file_cull_off: int = 0
		for m: BaseMaterial3D in found:
			mats += 1
			match m.transparency:
				BaseMaterial3D.TRANSPARENCY_DISABLED: opaque += 1
				BaseMaterial3D.TRANSPARENCY_ALPHA:
					blended += 1
					file_blended += 1
				BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR: scissor += 1
				BaseMaterial3D.TRANSPARENCY_ALPHA_HASH: hashed += 1
				BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS:
					prepass += 1
					file_blended += 1
				_: pass
			if m.cull_mode == BaseMaterial3D.CULL_DISABLED:
				cull_off += 1
				file_cull_off += 1
			if m.shading_mode == BaseMaterial3D.SHADING_MODE_PER_PIXEL:
				per_pixel += 1
			if m.specular_mode == BaseMaterial3D.SPECULAR_SCHLICK_GGX:
				specular_on += 1
		if file_blended > 0 or file_cull_off > 0:
			offenders.append("    %-52s blended=%d cull_off=%d n=%d"
				% [path.get_file(), file_blended, file_cull_off, found.size()])
		root.queue_free()
	print("\n  [%s] files=%d materials=%d" % [label, files.size(), mats])
	print("    transparency : opaque=%d scissor=%d BLENDED=%d hash=%d depth_pre_pass=%d"
		% [opaque, scissor, blended, hashed, prepass])
	print("    cull         : CULL_DISABLED=%d" % cull_off)
	print("    shading      : PER_PIXEL=%d   specular SCHLICK_GGX=%d" % [per_pixel, specular_on])
	for line: String in offenders:
		print(line)


func _apply_foliage(node: Node) -> void:
	var mi := node as MeshInstance3D
	if mi != null and mi.mesh != null:
		MaterialBudget.foliage(mi.mesh)
	for c: Node in node.get_children():
		_apply_foliage(c)


func _collect(node: Node, out: Array[BaseMaterial3D]) -> void:
	var mi := node as MeshInstance3D
	if mi != null and mi.mesh != null:
		for i in mi.mesh.get_surface_count():
			var m: Material = mi.get_active_material(i)
			var bm := m as BaseMaterial3D
			if bm != null:
				out.append(bm)
	for c: Node in node.get_children():
		_collect(c, out)
