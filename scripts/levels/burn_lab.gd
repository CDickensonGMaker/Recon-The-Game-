extends Node3D

## burn_lab.gd - Men on fire, up close, with nothing else in the way.
##
## The support range could not answer "is the burn animation right?" - the fire
## is 500m of napalm and the men are specks inside it. This is six bodies on a
## bare floor with a camera on them, so the CLIP CHAIN can actually be read.
##
## The burn loop is spliced from proven library clips (there is no burn clip in
## the 216): stumble_hit -> falling_to_roll -> wounded_crawl. Burning.clip()
## owns that choice; this lab drives the actor from it exactly the way
## enemy_base._update_sprite() does, so what you see here is what fires in game.
##
## Keys: 1-6 toggle that man alight · A all · X put everyone out · R respawn
##       T slow motion · SPACE pause the burn clock · [ ] orbit · - = zoom
## Run: godot --path . res://scenes/levels/burn_lab.tscn

const BURNING := preload("res://scripts/combat/burning.gd")

## Rifle-armed bodies only: a marksman or a crew-served gunner carries a weapon
## the burn clips do not account for, and the borrowed clips are all unarmed or
## rifle poses.
const UNITS: Array[String] = [
	"nva_regular", "nva_officer", "nva_sapper",
	"vc_guerilla", "vc_guerilla_mosin", "us_grunt_rifleman",
]
const SPACING: float = 2.4

var _men: Array[Node3D] = []
var _actors: Array[ModelActor] = []
var _was_burning: Array[bool] = []
var _dead: Array[bool] = []
var _label: Label = null
var _cam: Camera3D = null
var _orbit: float = 0.0
var _dist: float = 11.0
var _paused: bool = false


func _ready() -> void:
	_build_world()
	_build_ui()
	_spawn_all()


func _build_world() -> void:
	# Floor with a REAL collider. A PlaneMesh alone is scenery: anything the
	# physics engine touches drops straight through it.
	var floor_body := StaticBody3D.new()
	floor_body.collision_layer = 1      # world
	add_child(floor_body)
	var g := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(120, 120)
	g.mesh = pm
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.19, 0.21, 0.17)
	g.material_override = gm
	floor_body.add_child(g)
	var col := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(120, 1.0, 120)
	col.shape = bs
	col.position.y = -0.5
	floor_body.add_child(col)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, 30, 0)
	sun.light_energy = 1.1
	add_child(sun)

	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	sky.sky_material = ProceduralSkyMaterial.new()
	e.sky = sky
	e.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	e.ambient_light_energy = 0.7
	e.glow_enabled = false
	env.environment = e
	add_child(env)

	_cam = Camera3D.new()
	_cam.fov = 60.0
	_cam.current = true
	add_child(_cam)
	_place_cam()


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	_label = Label.new()
	_label.position = Vector2(20, 16)
	_label.add_theme_font_size_override("font_size", 18)
	layer.add_child(_label)


func _spawn_all() -> void:
	for m in _men:
		if is_instance_valid(m):
			m.queue_free()
	_men.clear()
	_actors.clear()
	_was_burning.clear()
	_dead.clear()

	var x0: float = -(float(UNITS.size()) - 1.0) * SPACING * 0.5
	for i in UNITS.size():
		var holder := Node3D.new()
		holder.position = Vector3(x0 + float(i) * SPACING, 0.0, 0.0)
		add_child(holder)

		var unit: String = UNITS[i]
		var actor: ModelActor = null
		if ModelActor.model_exists(unit):
			var ma := ModelActor.new()
			holder.add_child(ma)
			if ma.setup(unit):
				actor = ma
				ma.play("idle")
			else:
				ma.queue_free()
		if actor == null:
			push_warning("[BURN LAB] no model for '%s' - slot left empty" % unit)

		_men.append(holder)
		_actors.append(actor)
		_was_burning.append(false)
		_dead.append(false)

		var l := Label3D.new()
		l.text = "%d  %s" % [i + 1, unit]
		l.position = Vector3(0, 2.35, 0)
		l.font_size = 44
		l.pixel_size = 0.006
		l.outline_size = 14
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.no_depth_test = true
		holder.add_child(l)
	_refresh()


func _burn_of(i: int) -> Node:
	if i < 0 or i >= _men.size() or not is_instance_valid(_men[i]):
		return null
	return _men[i].get_node_or_null("Burning")


func _toggle(i: int) -> void:
	var b: Node = _burn_of(i)
	if b != null:
		b.queue_free()
		if i < _actors.size() and _actors[i] != null:
			_actors[i].play("idle")
		return
	var n: Node3D = BURNING.new()
	n.name = "Burning"
	_men[i].add_child(n)
	n.call("setup", _men[i])
	_dead[i] = false
	_was_burning[i] = true


func _process(_delta: float) -> void:
	# Drive the actor from Burning.clip(), the same way enemy_base does, so this
	# lab tests the real chain rather than a lookalike.
	for i in _men.size():
		if i >= _actors.size() or _actors[i] == null:
			continue
		var b: Node = _burn_of(i)
		var lit: bool = b != null and bool(b.call("is_burning"))
		if lit:
			# "" means he has dropped and the ragdoll owns the skeleton - playing
			# any clip now would fight the physics for the same bones.
			var want: String = String(b.call("clip"))
			if want != "":
				if not _actors[i].play(want):
					_actors[i].play(String(b.call("clip_alt")))
		elif _was_burning[i] and not _dead[i]:
			_dead[i] = true
		_was_burning[i] = lit
	_place_cam()
	_refresh()


func _place_cam() -> void:
	var a: float = deg_to_rad(_orbit)
	_cam.position = Vector3(sin(a) * _dist, 2.1, cos(a) * _dist)
	_cam.look_at(Vector3(0, 1.0, 0), Vector3.UP)


func _refresh() -> void:
	var rows: PackedStringArray = []
	for i in UNITS.size():
		var b: Node = _burn_of(i)
		var style: String = "-"
		var state: String = "DEAD" if (i < _dead.size() and _dead[i]) else "-"
		if b != null and bool(b.call("is_burning")):
			style = String(b.call("style_name"))
			var c: String = String(b.call("clip"))
			state = c if c != "" else "down, burning"
		rows.append("%d %-18s %-11s %s" % [i + 1, UNITS[i], style, state])
	_label.text = ("BURN LAB   1-6 toggle · A all · X out · R respawn · T slow %s · SPACE %s\n"
		% [str(Engine.time_scale), "paused" if _paused else "running"]
		+ "style is rolled per man at ignition - light the same man twice to re-roll\n"
		+ "  DROP        running_unarmed, then down\n"
		+ "  ROLL+CRAWL  running_unarmed -> falling_to_roll -> wounded_crawl\n"
		+ "  COWER       a few steps -> crouching, folds up and takes it\n"
		+ "\n".join(rows))


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	var k := (event as InputEventKey).keycode
	if k >= KEY_1 and k <= KEY_6:
		_toggle(k - KEY_1)
		return
	match k:
		KEY_A:
			for i in _men.size():
				if _burn_of(i) == null:
					_toggle(i)
		KEY_X:
			for i in _men.size():
				if _burn_of(i) != null:
					_toggle(i)
		KEY_R: _spawn_all()
		KEY_T: Engine.time_scale = 1.0 if Engine.time_scale < 1.0 else 0.25
		KEY_SPACE:
			_paused = not _paused
			for i in _men.size():
				var b: Node = _burn_of(i)
				if b != null:
					b.set_process(not _paused)
		KEY_BRACKETLEFT: _orbit -= 15.0
		KEY_BRACKETRIGHT: _orbit += 15.0
		KEY_MINUS: _dist = minf(_dist + 2.0, 40.0)
		KEY_EQUAL: _dist = maxf(_dist - 2.0, 4.0)
