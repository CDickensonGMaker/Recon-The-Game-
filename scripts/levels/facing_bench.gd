extends Node3D

## facing_bench.gd - FACE THE MODEL AGAINST THE DIRECTION IT ACTUALLY TRAVELS.
##
## The project convention is forward = Blender +Y == Godot -Z, and `look_at()`
## points a node's -Z down its travel vector. A model exported nose-to-+Z
## therefore flies backwards, and reading that off part names is guesswork.
##
## So this bench does not argue about axes. It MOVES a capsule down the real
## travel vector with a green cone on its FRONT and a red slab on its BACK, and
## puts the model on the same heading. Whatever the model does next to that
## capsule is what it will do in the game.
##
## Yaw the model until its nose points the same way as the green cone, then
## press ENTER. The bench writes every choice to
## `production/model_facing.json` as `path -> yaw degrees`, which is the input
## for baking the correction into the GLBs.
##
## Keys: A/D yaw -15/+15 · Q/E yaw -90/+90 · W/S pitch · F flip 180 · Z zero
##       N/P next/prev model · ENTER record · SPACE pause travel · R reset cam
##       [ / ] camera orbit · - / = camera distance
## Run: godot --path . res://scenes/levels/facing_bench.tscn

const OUT_PATH := "res://production/model_facing.json"
const TRAVEL_SPEED: float = 9.0
const LOOP_M: float = 70.0

## Everything with a heading. Add to this list; the bench needs no other change.
const MODELS: Array[String] = [
	"res://assets/us/aircraft/a1_skyraider.glb",
	"res://assets/us/aircraft/a4_skyhawk.glb",
	"res://assets/us/aircraft/f4_phantom.glb",
	"res://assets/us/aircraft/ac47_spooky.glb",
	"res://assets/us/aircraft/a1_skyraider_crashed.glb",
	"res://assets/us/vehicles/huey_v3.glb",
]

var _idx: int = 0
var _model: Node3D = null
var _pivot: Node3D = null
var _capsule: Node3D = null
var _travel: float = 0.0
var _paused: bool = false
var _yaw: float = 0.0
var _pitch: float = 0.0
var _choices: Dictionary = {}
var _label: Label = null
var _cam: Camera3D = null
var _orbit: float = 0.0
var _dist: float = 34.0
var _lift: float = 0.0    ## height that clears the model of the ground plane
var _span: float = 12.0   ## model's largest dimension; drives framing
var _sep: float = 8.0     ## lateral gap between model and reference capsule
var _follow: bool = false ## static camera by default; the model flies past you
var _loop: float = LOOP_M
var _lineup: Node3D = null ## true-scale size comparison (L)


func _ready() -> void:
	_build_world()
	_build_capsule()
	_build_ui()
	_load_existing()
	_spawn(_idx)


func _build_world() -> void:
	var g := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(8000, 8000)
	g.mesh = pm
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.17, 0.20, 0.16)
	g.material_override = gm
	add_child(g)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 35, 0)
	sun.light_energy = 1.2
	add_child(sun)

	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	sky.sky_material = ProceduralSkyMaterial.new()
	e.sky = sky
	e.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	e.ambient_light_energy = 0.85
	env.environment = e
	add_child(env)

	# Centre stripe down the travel line, so the heading is readable even when
	# the capsule is at the far end of its run.
	var stripe := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.5, 0.05, LOOP_M * 2.0)
	stripe.mesh = bm
	var sm := StandardMaterial3D.new()
	sm.albedo_color = Color(0.9, 0.9, 0.35)
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	stripe.material_override = sm
	stripe.position.y = 0.03
	add_child(stripe)

	_cam = Camera3D.new()
	_cam.fov = 62.0
	_cam.far = 4000.0
	_cam.current = true
	add_child(_cam)
	_place_cam()


## The reference: a capsule that MOVES. Green cone = front = direction of
## travel = Godot -Z. Red slab = back. This is the ground truth the model is
## judged against.
func _build_capsule() -> void:
	_capsule = Node3D.new()
	add_child(_capsule)

	var body := MeshInstance3D.new()
	var cm := CapsuleMesh.new()
	cm.radius = 1.0
	cm.height = 5.0
	body.mesh = cm
	body.rotation_degrees.x = 90.0     # lie it along Z, the travel axis
	var bmat := StandardMaterial3D.new()
	bmat.albedo_color = Color(0.55, 0.58, 0.62)
	body.material_override = bmat
	body.position.y = 1.2
	_capsule.add_child(body)

	var nose := MeshInstance3D.new()
	var nc := CylinderMesh.new()
	nc.top_radius = 0.0
	nc.bottom_radius = 1.1
	nc.height = 3.2
	nose.mesh = nc
	nose.rotation_degrees.x = -90.0    # point it down -Z
	var nmat := StandardMaterial3D.new()
	nmat.albedo_color = Color(0.15, 1.0, 0.25)
	nmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	nose.material_override = nmat
	nose.position = Vector3(0, 1.2, -4.1)
	_capsule.add_child(nose)

	var tail := MeshInstance3D.new()
	var tb := BoxMesh.new()
	tb.size = Vector3(2.6, 2.6, 1.0)
	tail.mesh = tb
	var tmat := StandardMaterial3D.new()
	tmat.albedo_color = Color(1.0, 0.15, 0.15)
	tmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	tail.material_override = tmat
	tail.position = Vector3(0, 1.2, 3.2)
	_capsule.add_child(tail)

	_sign(Vector3(0, 6.2, -6.5), "FRONT\ndirection of travel", Color(0.4, 1.0, 0.4), _capsule)
	_sign(Vector3(0, 6.2, 4.6), "BACK", Color(1.0, 0.45, 0.45), _capsule)


func _sign(pos: Vector3, text: String, col: Color, parent: Node) -> void:
	var l := Label3D.new()
	l.text = text
	l.position = pos
	l.font_size = 64
	l.pixel_size = 0.012
	l.modulate = col
	l.outline_size = 20
	l.outline_modulate = Color(0, 0, 0, 1)
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	parent.add_child(l)


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	_label = Label.new()
	_label.position = Vector2(22, 18)
	_label.add_theme_font_size_override("font_size", 20)
	layer.add_child(_label)


func _load_existing() -> void:
	if not FileAccess.file_exists(OUT_PATH):
		return
	var f := FileAccess.open(OUT_PATH, FileAccess.READ)
	if f == null:
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if parsed is Dictionary:
		_choices = parsed as Dictionary


func _spawn(i: int) -> void:
	if _pivot != null and is_instance_valid(_pivot):
		_pivot.queue_free()
	_idx = wrapi(i, 0, MODELS.size())
	var path: String = MODELS[_idx]

	_pivot = Node3D.new()
	add_child(_pivot)
	var packed: PackedScene = load(path) as PackedScene
	if packed == null:
		push_warning("[FACING] could not load %s" % path)
		_yaw = 0.0
		_refresh()
		return
	_model = packed.instantiate() as Node3D
	_pivot.add_child(_model)

	# Models arrive with their pivot anywhere - often mid-fuselage - so half the
	# airframe sits under y=0 and the ground plane bisects it. Measure the real
	# bounds and lift it clear, then frame the shot to the model's own size:
	# these range from a 12m Huey to a 152m Spooky and one fixed camera cannot
	# serve both.
	var box: AABB = _aabb_of(_model)
	_lift = 1.5 - box.position.y if box.size != Vector3.ZERO else 0.0
	var span: float = maxf(box.size.x, maxf(box.size.y, box.size.z))
	_span = maxf(span, 4.0)
	_dist = clampf(_span * 2.3, 18.0, 900.0)
	_sep = maxf(_span * 0.85, 8.0)
	_loop = maxf(_span * 3.0, 60.0)
	_travel = -_loop
	_fit_capsule(_span)

	_yaw = float(_choices.get(path, 0.0))
	_pitch = 0.0
	_refresh()


## Combined bounds of every visual under `root`, in root-local space.
func _aabb_of(root: Node3D) -> AABB:
	var out := AABB()
	var seeded := false
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for c in n.get_children():
			stack.append(c)
		if n is VisualInstance3D:
			var vi := n as VisualInstance3D
			var b: AABB = vi.get_aabb()
			if b.size == Vector3.ZERO:
				continue
			var rel: Transform3D = root.global_transform.affine_inverse() * vi.global_transform
			var wb: AABB = rel * b
			out = wb if not seeded else out.merge(wb)
			seeded = true
	return out


## The reference capsule must stay legible beside a 12m Huey AND a 152m gunship.
func _fit_capsule(span: float) -> void:
	if _capsule == null:
		return
	var s: float = clampf(span * 0.09, 0.6, 12.0)
	_capsule.scale = Vector3(s, s, s)


func _process(delta: float) -> void:
	if not _paused:
		_travel += maxf(TRAVEL_SPEED, _span * 0.9) * delta
		if _travel > _loop:
			_travel = -_loop
	# Travel down -Z: the same axis look_at() drives in the game.
	var z: float = -_travel
	if _capsule != null:
		_capsule.position = Vector3(_sep, _lift, z)
	if _pivot != null and is_instance_valid(_pivot):
		_pivot.position = Vector3(-_sep, _lift, z)
		_pivot.rotation_degrees = Vector3(_pitch, _yaw, 0.0)
	_place_cam()


func _place_cam() -> void:
	if _cam == null or (_lineup != null and is_instance_valid(_lineup)):
		return   # lineup owns the camera while it is up
	var a: float = deg_to_rad(_orbit)
	var eye_y: float = _lift + _span * 0.45
	# STATIC by default: a camera that follows the model makes a moving model
	# look parked, which is exactly the thing this bench has to prove. Standing
	# still and letting it fly past is the confirmation. C toggles follow for
	# close inspection.
	var z: float = (-_travel) if _follow else 0.0
	_cam.position = Vector3(sin(a) * _dist, eye_y, z + cos(a) * _dist)
	_cam.look_at(Vector3(0, _lift + _span * 0.12, z), Vector3.UP)


func _refresh() -> void:
	var path: String = MODELS[_idx]
	var saved: String = ("%.0f" % float(_choices[path])) if _choices.has(path) else "-"
	_label.text = ("[%d/%d]  %s\nyaw %.0f   pitch %.0f   (recorded: %s)\n"
		% [_idx + 1, MODELS.size(), path.get_file(), _yaw, _pitch, saved]
		+ "A/D yaw 15  Q/E yaw 90  W/S pitch  F flip  Z zero  |  "
		+ "N/P model  ENTER record  SPACE pause  C camera %s  [ ] orbit  - = zoom\n"
			% ("FOLLOW" if _follow else "STATIC")
		+ "L = true-scale lineup of every model beside a 1.8m man\n"
		+ "Aim the model's NOSE the way it FLIES - it should lead, like the GREEN cone.")


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match (event as InputEventKey).keycode:
		KEY_A: _yaw = wrapf(_yaw - 15.0, -180.0, 180.0)
		KEY_D: _yaw = wrapf(_yaw + 15.0, -180.0, 180.0)
		KEY_Q: _yaw = wrapf(_yaw - 90.0, -180.0, 180.0)
		KEY_E: _yaw = wrapf(_yaw + 90.0, -180.0, 180.0)
		KEY_F: _yaw = wrapf(_yaw + 180.0, -180.0, 180.0)
		KEY_W: _pitch = wrapf(_pitch + 5.0, -180.0, 180.0)
		KEY_S: _pitch = wrapf(_pitch - 5.0, -180.0, 180.0)
		KEY_Z:
			_yaw = 0.0
			_pitch = 0.0
		KEY_N: _spawn(_idx + 1)
		KEY_P: _spawn(_idx - 1)
		KEY_SPACE: _paused = not _paused
		KEY_C: _follow = not _follow
		KEY_L: _toggle_lineup()
		KEY_BRACKETLEFT: _orbit -= 15.0
		KEY_BRACKETRIGHT: _orbit += 15.0
		KEY_MINUS: _dist = minf(_dist + 6.0, 400.0)
		KEY_EQUAL: _dist = maxf(_dist - 6.0, 8.0)
		KEY_R:
			_orbit = 0.0
			_dist = 34.0
		KEY_ENTER, KEY_KP_ENTER: _record()
	_refresh()


## Every model at once, at TRUE relative scale, beside a 1.8m man.
##
## The per-model auto-fit above deliberately frames each aircraft to fill the
## view, which is right for judging facing and useless for judging size - it
## makes a 8m Skyhawk and a 29m gunship look identical. Nothing can be compared
## without a shared ruler in the same shot.
func _toggle_lineup() -> void:
	if _lineup != null and is_instance_valid(_lineup):
		_lineup.queue_free()
		_lineup = null
		if _pivot != null and is_instance_valid(_pivot):
			_pivot.visible = true
		_capsule.visible = true
		_place_cam()
		return

	_lineup = Node3D.new()
	add_child(_lineup)
	if _pivot != null and is_instance_valid(_pivot):
		_pivot.visible = false
	_capsule.visible = false

	# 1.8m man: the only absolute scale anyone reads instantly.
	var man := MeshInstance3D.new()
	var mb := BoxMesh.new()
	mb.size = Vector3(0.5, 1.8, 0.35)
	man.mesh = mb
	var mm := StandardMaterial3D.new()
	mm.albedo_color = Color(1.0, 0.9, 0.2)
	mm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	man.material_override = mm
	man.position = Vector3(0.0, 0.9, 0.0)
	_lineup.add_child(man)
	_sign(Vector3(0.0, 4.0, 0.0), "1.8m man", Color(1.0, 0.95, 0.4), _lineup)

	var x: float = 6.0
	var tallest: float = 2.0
	for path in MODELS:
		var packed: PackedScene = load(path) as PackedScene
		if packed == null:
			continue
		var inst := packed.instantiate() as Node3D
		_lineup.add_child(inst)
		var box: AABB = _aabb_of(inst)
		var wide: float = maxf(box.size.x, 1.0)
		x += wide * 0.5 + 4.0
		inst.position = Vector3(x, -box.position.y, 0.0)
		tallest = maxf(tallest, box.size.y)
		var l := Label3D.new()
		l.text = "%s\n%.1fm span  %.1fm long" % [path.get_file().get_basename(),
			box.size.x, box.size.z]
		l.position = Vector3(x, box.size.y + 4.0, 0.0)
		l.font_size = 56
		l.pixel_size = 0.02
		l.outline_size = 18
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.no_depth_test = true
		_lineup.add_child(l)
		x += wide * 0.5 + 4.0

	# Frame the whole row from the side.
	_cam.position = Vector3(x * 0.5, tallest * 1.9 + 14.0, x * 0.95 + 30.0)
	_cam.look_at(Vector3(x * 0.5, tallest * 0.4, 0.0), Vector3.UP)


func _record() -> void:
	_choices[MODELS[_idx]] = _yaw
	var f := FileAccess.open(OUT_PATH, FileAccess.WRITE)
	if f == null:
		push_warning("[FACING] cannot write %s" % OUT_PATH)
		return
	f.store_string(JSON.stringify(_choices, "\t"))
	f.close()
	print("[FACING] %s -> yaw %.0f  (%d recorded)"
		% [MODELS[_idx].get_file(), _yaw, _choices.size()])
