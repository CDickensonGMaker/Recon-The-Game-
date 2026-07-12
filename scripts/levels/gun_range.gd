## gun_range.gd - THE RANGE: every gun in the armory, targets at every range.
##
## A 600m lane with docile VC standing at 25/50/75/100/150/200/250/300/400/500m,
## wearing the LIVE hitzones (mesh hulls + the real damage law). Built to answer
## the questions the arena cannot: where does each rifle actually hit at 300m,
## what does the zero feel like, where does buckshot stop mattering, how far can
## a Mosin reach.
##
## Every hit prints to the range board: distance, zone, damage, and what was
## left of him. Dead targets re-stand after a few seconds.
##
## KEYS (no gameplay collisions - e6qc law)
##   [ / ]  cycle the weapon through the whole armory (11 FP arms)
##   H      hitzone wireframes on/off
##   R      re-stand every target, clear the board
##   B      toggle bullet-drop cheat sheet (per-weapon zero + holdover)
##
## Run: gun_range.bat  /  godot --path . res://scenes/levels/gun_range.tscn
class_name GunRange
extends Node3D

## The true armory (ADR-016 Amendment C: the FP arms ARE the player's guns).
const ARMORY: Array[String] = [
	"m16a1", "m14", "m60", "ak47", "rpd", "ppsh41",
	"mosin", "m70", "shotgun", "m1911", "rpg2",
]
## Where the men stand. Vietnam engagement bands, plus two long ones so the
## drop is undeniable.
const TARGET_RANGES: Array[float] = [25.0, 50.0, 75.0, 100.0, 150.0, 200.0, 250.0, 300.0, 400.0, 500.0]
const LANE_W: float = 40.0
const RESPAWN_S: float = 4.0

var player: CharacterBody3D = null
var _holder: WeaponHolder = null
var _weapon_idx: int = 0
var _targets: Dictionary = {}   # range(float) -> GoreDummy
var _board: Label = null
var _sheet: Label = null
var _log: Array[String] = []
var _zone_im: ImmediateMesh = null
var _zones_visible: bool = false
var _sheet_visible: bool = true


func _ready() -> void:
	GibSystem.gib_lifetime_s = 20.0
	_build_lane()
	_build_lighting()
	_spawn_player()
	for r in TARGET_RANGES:
		_spawn_target(r)
	_build_hud()
	_equip(0)
	print("[GUN RANGE] %d targets, %d guns. [ ] weapon | H zones | R reset | B drop sheet" % [
		TARGET_RANGES.size(), ARMORY.size()])


## ---------------------------------------------------------------- the lane
func _build_lane() -> void:
	var floor_body := StaticBody3D.new()
	floor_body.collision_layer = 1
	floor_body.collision_mask = 0
	floor_body.add_to_group("nav_source")
	var mi := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(LANE_W, 1200.0)
	mi.mesh = plane
	var sm := ShaderMaterial.new()
	sm.shader = load("res://terrain/shaders/lab_grid.gdshader")
	mi.material_override = sm
	floor_body.add_child(mi)
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(LANE_W, 0.2, 1200.0)
	cs.shape = box
	cs.position.y = -0.1
	floor_body.add_child(cs)
	add_child(floor_body)
	floor_body.position.z = -560.0

	# Range markers: a post + a floating number every 50m, so you always know
	# how far the man you just missed was standing.
	for d in range(50, 551, 50):
		var post := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.25, 2.2, 0.25)
		post.mesh = bm
		var pm := StandardMaterial3D.new()
		pm.albedo_color = Color(0.85, 0.75, 0.25)
		post.material_override = pm
		add_child(post)
		post.position = Vector3(-6.0, 1.1, -float(d))
		var lbl := Label3D.new()
		lbl.text = "%dm" % d
		lbl.font_size = 128
		lbl.pixel_size = 0.004
		lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		lbl.no_depth_test = true
		lbl.fixed_size = false
		lbl.modulate = Color(1.0, 0.9, 0.4)
		lbl.outline_size = 24
		add_child(lbl)
		lbl.position = Vector3(-6.0, 2.9, -float(d))


func _build_lighting() -> void:
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -30, 0)
	sun.light_energy = 1.15
	sun.shadow_enabled = false
	add_child(sun)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.80, 0.85, 0.92)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.78, 0.80, 0.85)
	e.ambient_light_energy = 0.95
	env.environment = e
	add_child(env)


## ------------------------------------------------------------- the shooter
func _spawn_player() -> void:
	var scene: PackedScene = load("res://scenes/player/player.tscn")
	player = scene.instantiate() as CharacterBody3D
	add_child(player)
	player.global_position = Vector3(0.0, 1.0, 2.0)
	GameManager.player = player
	var hud: HUD = load("res://scenes/ui/hud.tscn").instantiate() as HUD
	add_child(hud)
	_holder = player.get_node("Head/Camera3D/WeaponHolder") as WeaponHolder
	hud.setup(player.get_node("HealthSystem"), _holder,
		player.get_node("EquipmentManager"), player.get_node("Head/Camera3D/GrenadeHandler"))


## Hand the shooter the next gun in the armory - same seam a captured weapon
## uses, so what you test IS what you would pick up off a body.
func _equip(idx: int) -> void:
	_weapon_idx = wrapi(idx, 0, ARMORY.size())
	var wd: WeaponData = load("res://data/weapons/%s.tres" % ARMORY[_weapon_idx])
	if wd == null or _holder == null:
		return
	_holder.equip_captured_weapon(wd)
	_holder.spare_magazines = 99   # the range never runs you dry
	_flash_board("== %s ==  zero %.0fm  |  %d dmg  |  %.0f m/s" % [
		wd.display_name, wd.zero_range, wd.base_damage, wd.projectile_speed])


## -------------------------------------------------------------- the targets
func _spawn_target(dist: float) -> void:
	var d := GoreDummy.new()
	d.unit_id = "vc_guerilla"
	d.idle_only = true          # he stands still: this is an AIM test
	add_child(d)
	# Stagger left/right, widening with range: on one line the near men hide
	# the far ones. Every target keeps clear air and its own sight picture.
	var i: int = TARGET_RANGES.find(dist)
	var side: float = -1.0 if i % 2 == 0 else 1.0
	d.global_position = Vector3(side * (2.0 + dist * 0.02), 0.0, -dist)
	d.rotation.y = PI          # facing the firing line
	# His range, floating over his head. WORLD-scaled, not fixed_size: a
	# screen-locked label puts all ten on top of each other at the vanishing
	# point (one green mush) and paints over the men you are trying to shoot.
	# Scaling the glyphs with distance keeps them legible AND in their lane.
	var tag := Label3D.new()
	tag.text = "%dm" % int(dist)
	tag.font_size = 64
	tag.pixel_size = 0.0035 + dist * 0.00006
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.modulate = Color(0.55, 1.0, 0.55)
	tag.outline_size = 16
	tag.position = Vector3(0, 2.2 + dist * 0.012, 0)
	d.add_child(tag)
	_targets[dist] = d
	d.hit_taken.connect(func(zone: String, amount: int, hp_left: int) -> void:
		_log_hit(dist, zone, amount, hp_left))
	d.died.connect(func() -> void:
		_log_line("%4.0fm  >>> DOWN <<<" % dist)
		get_tree().create_timer(RESPAWN_S).timeout.connect(func() -> void:
			if is_instance_valid(_targets.get(dist)):
				(_targets[dist] as Node).queue_free()
			_spawn_target(dist)))


func _reset_targets() -> void:
	for dist in _targets.keys():
		var t: Node = _targets[dist]
		if is_instance_valid(t):
			t.queue_free()
	_targets.clear()
	for r in TARGET_RANGES:
		_spawn_target(r)
	_log.clear()
	GibSystem.clear_gibs()


## --------------------------------------------------------------- the board
func _log_hit(dist: float, zone: String, amount: int, hp_left: int) -> void:
	_log_line("%4.0fm  %-9s %3d dmg   hp %d" % [dist, zone, amount, hp_left])


func _log_line(s: String) -> void:
	_log.push_front(s)
	while _log.size() > 12:
		_log.pop_back()


func _flash_board(s: String) -> void:
	_log_line(s)


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 1
	add_child(layer)
	_board = Label.new()
	_board.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_board.position = Vector2(-560, 12)
	_board.custom_minimum_size = Vector2(540, 0)
	_board.add_theme_font_size_override("font_size", 14)
	_board.add_theme_color_override("font_color", Color(0.6, 1.0, 0.6))
	_board.add_theme_color_override("font_outline_color", Color.BLACK)
	_board.add_theme_constant_override("outline_size", 3)
	layer.add_child(_board)
	_sheet = Label.new()
	_sheet.position = Vector2(14, 120)
	_sheet.add_theme_font_size_override("font_size", 13)
	_sheet.add_theme_color_override("font_color", Color(1.0, 0.92, 0.6))
	_sheet.add_theme_color_override("font_outline_color", Color.BLACK)
	_sheet.add_theme_constant_override("outline_size", 3)
	layer.add_child(_sheet)

	_zone_im = ImmediateMesh.new()
	var zm := MeshInstance3D.new()
	zm.mesh = _zone_im
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.no_depth_test = true
	zm.material_override = m
	add_child(zm)


## The honest cheat sheet: where THIS gun's round sits relative to the sights
## at each range, from the same maths the bullet flies (zero elevation minus
## gravity drop). Positive = above the crosshair, negative = below.
func _drop_sheet(wd: WeaponData) -> String:
	if wd == null:
		return ""
	var lines: Array[String] = []
	lines.append("%s   zero %.0fm   %.0f m/s" % [wd.display_name, wd.zero_range, wd.projectile_speed])
	lines.append("range   impact vs point of aim")
	var theta: float = wd.zero_elevation()
	for d in [50.0, 100.0, 150.0, 200.0, 250.0, 300.0, 400.0, 500.0]:
		if d > wd.max_range:
			continue
		var t: float = d / maxf(1.0, wd.projectile_speed)
		var h: float = d * tan(theta) - 0.5 * 9.8 * t * t
		var tag: String = "on the sights"
		if h > 0.03:
			tag = "%+.0f cm HIGH" % (h * 100.0)
		elif h < -0.03:
			tag = "%+.0f cm low   %s" % [h * 100.0,
				"(hold at the collar)" if h > -0.5 else "(hold over the head)"]
		lines.append("%4.0fm   %s" % [d, tag])
	lines.append("")
	lines.append("[ ] gun   H zones   R reset   B this sheet")
	return "\n".join(lines)


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_BRACKETLEFT:
			_equip(_weapon_idx - 1)
		KEY_BRACKETRIGHT:
			_equip(_weapon_idx + 1)
		KEY_H:
			_zones_visible = not _zones_visible
		KEY_R:
			_reset_targets()
		KEY_B:
			_sheet_visible = not _sheet_visible


func _process(_delta: float) -> void:
	_zone_im.clear_surfaces()
	if _zones_visible:
		_zone_im.surface_begin(Mesh.PRIMITIVE_LINES)
		_zone_im.surface_set_color(Color(0, 0, 0, 0))
		_zone_im.surface_add_vertex(Vector3.ZERO)
		_zone_im.surface_set_color(Color(0, 0, 0, 0))
		_zone_im.surface_add_vertex(Vector3.ZERO)
		for hz in get_tree().get_nodes_in_group("hitzone"):
			if hz is Area3D and is_instance_valid(hz):
				HitzoneBuilder.draw_zone_wire(_zone_im, hz as Area3D)
		_zone_im.surface_end()
	if _board != null:
		_board.text = "GUN RANGE - %s (%d/%d)\n%s" % [
			ARMORY[_weapon_idx], _weapon_idx + 1, ARMORY.size(), "\n".join(_log)]
	if _sheet != null:
		_sheet.visible = _sheet_visible
		if _sheet_visible and _holder != null:
			_sheet.text = _drop_sheet(_holder.current_weapon)
