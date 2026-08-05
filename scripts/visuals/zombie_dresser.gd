## zombie_dresser.gd - turns 12 exported zombies into a crowd that does not repeat.
##
## Same trick as GruntDresser, and deliberately the same shape so the two read as
## one system: the head's UVs sit inside ONE cell of a 10x7 atlas, so sliding that
## material's `uv1_offset` by one cell deals a different face.
##
##     70 faces x 12 bodies x per-man build jitter
##
## THE ONE TRAP, inherited: `uv1_offset` is a MATERIAL property. Duplicate it per
## instance or every zombie on screen rerolls to the same face at once.
##
## WHAT IS DIFFERENT FROM THE GRUNT. Skin does NOT ride the atlas here. A grunt's
## face and hands share one material so a black face can never land on a white body;
## every zombie is the same shade of dead, so hands take their own necrotic material
## and the invariant is not needed. That means _set_face slides the HEAD only, and
## finding no atlas surface is a real failure rather than a shrug.
##
## THE FACE POOLS ARE NOT WRITTEN HERE. They come from zombie_manifest.json, which
## tools/make_zombies.py emits. GruntDresser hardcodes US_FACES and that list has
## already had to be hand-corrected once; deriving it from the builder is the fix.
class_name ZombieDresser
extends RefCounted

const ATLAS_COLS: int = 10
const ATLAS_ROWS: int = 7
const MANIFEST: String = "res://assets/zombies/characters/zombie_manifest.json"

## A horde of one silhouette reads as a spawner. These are small on purpose - the
## bodies are already 12 shapes, this only stops the repeats lining up.
const BUILD_SCALE: Vector2 = Vector2(0.94, 1.06)
## Rot is not uniform. A slight per-man albedo shift separates men standing
## shoulder to shoulder without a second texture.
const TINT_JITTER: float = 0.10

static var _manifest: Dictionary = {}
static var _manifest_loaded: bool = false
static var _no_atlas_reported: Dictionary = {}


## The manifest, loaded once. Empty dictionary if it is missing - callers fall back
## to the whole atlas rather than refusing to spawn.
static func manifest() -> Dictionary:
	if _manifest_loaded:
		return _manifest
	_manifest_loaded = true
	if not ResourceLoader.exists(MANIFEST) and not FileAccess.file_exists(MANIFEST):
		push_warning("[ZDRESS] no %s - every zombie draws the whole atlas" % MANIFEST)
		return _manifest
	var f: FileAccess = FileAccess.open(MANIFEST, FileAccess.READ)
	if f == null:
		return _manifest
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if parsed is Dictionary:
		_manifest = parsed as Dictionary
	return _manifest


## The atlas cells this unit may be dealt. Falls back to the full 70 when the unit
## is not in the manifest, so a new export is never blocked on a manifest rebuild.
static func faces_for(unit: String) -> Array:
	var m: Dictionary = manifest()
	var units: Dictionary = m.get("units", {}) as Dictionary
	var entry: Dictionary = units.get(unit, {}) as Dictionary
	var faces: Array = entry.get("faces", []) as Array
	if faces.is_empty():
		faces = []
		for i in ATLAS_COLS * ATLAS_ROWS:
			faces.append(i)
	return faces


## "walker" or "rotted" - the wave director reads this to weight a round's mix.
static func tier_of(unit: String) -> String:
	var units: Dictionary = manifest().get("units", {}) as Dictionary
	var entry: Dictionary = units.get(unit, {}) as Dictionary
	return String(entry.get("tier", "walker"))


## Dress one zombie. `rng` in, so a wave replays from its seed (ADR-010).
## NOT re-entrant - one dress per actor, guarded by the "dressed" meta.
static func dress(actor: ModelActor, rng: RandomNumberGenerator,
		opts: Dictionary = {}) -> Dictionary:
	if actor.get_meta("dressed", false):
		return {}
	actor.set_meta("dressed", true)
	var root: Node3D = actor.instance_root()
	if root == null:
		return {}

	var pool: Array = faces_for(actor.unit)
	var face: int = int(opts.get("face", pool[rng.randi() % pool.size()]))
	var tint: float = 1.0 - rng.randf() * TINT_JITTER
	_set_face(root, face, actor.unit)
	_tint_body(root, tint)

	# Build jitter is applied to the ACTOR, not the skeleton: ModelActor measures a
	# man from the skeleton to normalise his height, so scaling bones here would be
	# undone the moment it ran.
	var build: float = rng.randf_range(BUILD_SCALE.x, BUILD_SCALE.y)
	if not bool(opts.get("uniform_build", false)):
		actor.scale = Vector3.ONE * build

	return {"unit": actor.unit, "face": face, "build": build,
			"tier": tier_of(actor.unit)}


## Slide the head material to a different cell of the zombie atlas.
static func _set_face(root: Node3D, index: int, unit: String) -> void:
	var col: int = index % ATLAS_COLS
	var row: int = int(index / float(ATLAS_COLS)) % ATLAS_ROWS
	var off := Vector3(col / float(ATLAS_COLS), row / float(ATLAS_ROWS), 0.0)

	var slid: int = 0
	for mi in _all_meshes(root):
		var mesh: Mesh = mi.mesh
		if mesh == null:
			continue
		for s in mesh.get_surface_count():
			var m: Material = mi.get_active_material(s)
			if m == null:
				m = mesh.surface_get_material(s)
			var sm := m as BaseMaterial3D
			if sm == null or not _rides_face_atlas(sm):
				continue
			# DUPLICATE, or every zombie sharing this material rerolls with him.
			var mine := sm.duplicate() as BaseMaterial3D
			mine.uv1_offset = off
			mine.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
			mi.set_surface_override_material(s, mine)
			slid += 1
	# One line per unit, not per man: a 40-strong wave would bury the log.
	if slid == 0 and not _no_atlas_reported.has(unit):
		_no_atlas_reported[unit] = true
		push_warning(("[ZDRESS] '%s' has no surface sampling the zombie face atlas - "
			+ "every one of them wears the face he was exported with. Re-run "
			+ "tools/make_zombies.py, which swaps the atlas image on the base.") % unit)


## Texture identity, not resource name - the name is what drifts, and the pixels are
## what decide his face. tools/make_zombie_atlas.py keeps "face_atlas" in the
## filename precisely so this test keeps working.
static func _rides_face_atlas(m: BaseMaterial3D) -> bool:
	var tex: Texture2D = m.albedo_texture
	return tex != null and tex.resource_path.contains("face_atlas")


## Darken one man a touch, everywhere the atlas does NOT reach. Skips atlas surfaces
## so the tint cannot fight the face it was just dealt.
static func _tint_body(root: Node3D, tint: float) -> void:
	if is_equal_approx(tint, 1.0):
		return
	for mi in _all_meshes(root):
		var mesh: Mesh = mi.mesh
		if mesh == null:
			continue
		for s in mesh.get_surface_count():
			var sm := mi.get_active_material(s) as BaseMaterial3D
			if sm == null or _rides_face_atlas(sm):
				continue
			var mine := sm.duplicate() as BaseMaterial3D
			mine.albedo_color = Color(mine.albedo_color.r * tint,
				mine.albedo_color.g * tint, mine.albedo_color.b * tint,
				mine.albedo_color.a)
			mine.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
			mi.set_surface_override_material(s, mine)


static func _all_meshes(root: Node) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for c in n.get_children():
			stack.push_back(c)
		if n is MeshInstance3D:
			out.append(n as MeshInstance3D)
	return out
