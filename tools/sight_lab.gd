## sight_lab.gd - THE CALIBRATION BENCH. The one check no code can make.
##
## From the Blender window, and independently from the War Room council:
##
##   "Stand in patch_tangle and look 45 m. The AI is TOLD that's all it can see in
##    heavy jungle. If the art doesn't actually hide a man at that range, the game is
##    lying to the player - he thinks he's concealed and gets shot through a bush."
##
## This cannot be probed. Foliage carries NO COLLISION (correctly - it must block
## sight, never bullets), so a raycast sails straight through every leaf in the game.
## Concealment is a NUMBER (`GameplayGrid.vegetation_density`), and the art is a
## PROMISE that the number is honest. Only an eye can audit that promise.
##
## So this bench makes the audit take thirty seconds instead of never happening:
## it drops you inside a field of one patch type and stands three men at the exact
## distances that patch's density class CLAIMS. If you can see the man standing on
## the number, the art is lying and the density table must come down (or the patch
## must get thicker).
##
##   godot --path . res://tools/sight_lab.tscn     (or: sight_lab.bat)
##
## KEYS
##   [ / ]   cycle the patch filling the field
##   WASD    walk    MOUSE  look    SHIFT  run
##   H       hide/show the men (see the raw foliage)
##   ESC     quit
extends Node3D

const TILE: float = 12.0        ## patches are 12m tiles
const FIELD: int = 9            ## 9x9 tiles = 108m of jungle around you
const PATCH_DIR := "res://assets/world/vegetation/patches/"

## name, density class, and the vegetation_density the GRID gives that class.
## cap = lerp(140, 45, density) - the exact lerp enemy_base._sight_cap() uses.
const CLASSES: Array = [
	["patch_tangle",      "wall",   0.95],   # "MAX THICK: cut through it"
	["patch_thicket",     "wall",   0.95],   # "no sightlines - where an ambush lives"
	["patch_bamboo_wall", "wall",   0.95],
	["patch_grove",       "dense",  0.95],   # "THICK MIX: canopy + bamboo + bush"
	["patch_secondary",   "dense",  0.95],   # "SECONDARY GROWTH: riot of light"
	["patch_elephant",    "dense",  0.95],   # "elephant grass sea"
	["patch_canopy",      "medium", 0.70],   # "closed canopy, lianas"
	["patch_vine_hall",   "medium", 0.70],
	["patch_understory",  "light",  0.50],   # "PRIMARY: big boles, BARE FLOOR"
	["patch_scrub",       "light",  0.50],
	["patch_clearing",    "open",   0.30],
	["patch_grassfield",  "open",   0.30],   # "chest-high - crouch and vanish"
]

var _idx: int = 0
var _field: Node3D = null
var _men: Array[Node3D] = []
var _hud: Label = null
var _cam: Camera3D = null
var _yaw: float = 0.0
var _pitch: float = 0.0
var _show_men: bool = true


func _ready() -> void:
	_build_ground()
	_build_cam()
	_build_hud()
	_load_class(0)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


## The lerp the AI actually uses. THIS is the promise the art has to keep.
static func sight_cap(density: float) -> float:
	return lerpf(140.0, 45.0, clampf(density, 0.0, 1.0))


func _build_ground() -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(400, 2, 400)
	col.shape = box
	col.position = Vector3(0, -1, 0)
	body.add_child(col)
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(400, 400)
	mi.mesh = pm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.13, 0.15, 0.10)
	mi.material_override = mat
	body.add_child(mi)
	add_child(body)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, 35, 0)
	sun.light_energy = 1.0
	add_child(sun)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.45, 0.55, 0.45)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.5, 0.55, 0.45)
	e.ambient_light_energy = 0.7
	env.environment = e
	add_child(env)


func _build_cam() -> void:
	_cam = Camera3D.new()
	_cam.fov = 75.0          # the game's base FOV - the calibration must use it
	_cam.position = Vector3(0, 1.7, 0)   # eye height
	_cam.far = 500.0
	_cam.current = true
	add_child(_cam)


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	_hud = Label.new()
	_hud.position = Vector2(18, 14)
	_hud.add_theme_font_size_override("font_size", 15)
	_hud.add_theme_color_override("font_color", Color(0.95, 0.96, 0.9))
	_hud.add_theme_color_override("font_outline_color", Color.BLACK)
	_hud.add_theme_constant_override("outline_size", 5)
	layer.add_child(_hud)

	# The crosshair - you are auditing what you can see DOWN THE SIGHTS.
	var cross := Label.new()
	cross.text = "+"
	cross.add_theme_font_size_override("font_size", 22)
	cross.add_theme_color_override("font_color", Color(0.4, 1.0, 0.4))
	cross.anchor_left = 0.5
	cross.anchor_top = 0.5
	cross.position = Vector2(-7, -16)
	layer.add_child(cross)


func _load_class(i: int) -> void:
	_idx = wrapi(i, 0, CLASSES.size())
	var spec: Array = CLASSES[_idx]
	var pname: String = str(spec[0])
	var density: float = float(spec[2])
	var cap: float = sight_cap(density)

	if _field != null:
		_field.queue_free()
	_field = Node3D.new()
	add_child(_field)
	_men.clear()

	# Tile the field. Same jitter the real layer uses (jungle_patch_layer.gd:296)
	# so what you audit is what ships - including the scale jitter that Phase 1's
	# trunk colliders must account for.
	var scene: PackedScene = load(PATCH_DIR + pname + ".glb") as PackedScene
	if scene == null:
		push_warning("[SIGHT LAB] missing %s" % pname)
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	var half: int = FIELD / 2
	for gz in range(-half, half + 1):
		for gx in range(-half, half + 1):
			var t := scene.instantiate() as Node3D
			_field.add_child(t)
			t.position = Vector3(float(gx) * TILE + rng.randf_range(-1.5, 1.5),
				0.0, float(gz) * TILE + rng.randf_range(-1.5, 1.5))
			t.rotation.y = rng.randf_range(0.0, TAU)
			var s: float = rng.randf_range(0.92, 1.10)
			t.scale = Vector3(s, s, s)

	# THE MEN. One at HALF the cap, one ON the cap, one at 1.5x.
	# The man ON THE NUMBER is the whole test: the AI says it can see him from
	# exactly there. If YOU can see him, the art is telling the truth.
	for d in [cap * 0.5, cap, cap * 1.5]:
		var man := GoreDummy.new()
		man.unit_id = "vc_guerilla"
		man.idle_only = true
		_field.add_child(man)
		man.global_position = Vector3(0, 0, -float(d))
		man.rotation.y = PI
		var tag := Label3D.new()
		tag.text = "%dm" % int(d)
		tag.font_size = 64
		tag.pixel_size = 0.0035 + float(d) * 0.00008
		tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		tag.modulate = Color(1.0, 0.4, 0.35) if is_equal_approx(float(d), cap) \
			else Color(0.6, 0.75, 0.6)
		tag.outline_size = 14
		tag.position = Vector3(0, 2.3, 0)
		man.add_child(tag)
		_men.append(man)
	_refresh()


func _refresh() -> void:
	var spec: Array = CLASSES[_idx]
	var density: float = float(spec[2])
	var cap: float = sight_cap(density)
	var s := "SIGHT CALIBRATION BENCH   [ / ] patch   H men   WASD+mouse   ESC quit\n\n"
	s += "  PATCH ......... %s   (%d/%d)\n" % [str(spec[0]), _idx + 1, CLASSES.size()]
	s += "  density class . %s\n" % str(spec[1])
	s += "  vegetation_density the grid gives it .... %.2f\n" % density
	s += "\n"
	s += "  >>> THE AI IS TOLD IT CAN SEE YOU AT %.0f m IN THIS. <<<\n" % cap
	s += "\n"
	s += "  The RED man is standing at exactly %.0f m.\n" % cap
	s += "  CAN YOU SEE HIM?\n\n"
	s += "     YES  -> the art is LYING. He thinks he's hidden and gets shot\n"
	s += "             through a bush. Thicken the patch, or lower the density.\n"
	s += "     NO   -> the number is honest. This patch keeps its promise.\n"
	if not _show_men:
		s += "\n  (men hidden - looking at the raw foliage)"
	_hud.text = s


func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var m := e as InputEventMouseMotion
		_yaw -= m.relative.x * 0.0022
		_pitch = clampf(_pitch - m.relative.y * 0.0022, -1.4, 1.4)
		_cam.rotation = Vector3(_pitch, _yaw, 0.0)
		return
	if not (e is InputEventKey) or not e.is_pressed() or e.is_echo():
		return
	match (e as InputEventKey).keycode:
		KEY_BRACKETLEFT:
			_load_class(_idx - 1)
		KEY_BRACKETRIGHT:
			_load_class(_idx + 1)
		KEY_H:
			_show_men = not _show_men
			for m in _men:
				if is_instance_valid(m):
					m.visible = _show_men
			_refresh()
		KEY_ESCAPE:
			get_tree().quit()


func _process(delta: float) -> void:
	var dir := Vector3.ZERO
	if Input.is_key_pressed(KEY_W): dir.z -= 1.0
	if Input.is_key_pressed(KEY_S): dir.z += 1.0
	if Input.is_key_pressed(KEY_A): dir.x -= 1.0
	if Input.is_key_pressed(KEY_D): dir.x += 1.0
	var sp: float = 12.0 if Input.is_key_pressed(KEY_SHIFT) else 4.5
	var basis := Basis(Vector3.UP, _yaw)
	_cam.position += basis * dir.normalized() * sp * delta
	_cam.position.y = 1.7
