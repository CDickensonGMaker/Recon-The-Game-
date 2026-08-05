## gun_range.gd - Ballistics bench: docile targets at 25-500m plus a penetration
## row. Run: gun_range.bat / godot --path . res://scenes/levels/gun_range.tscn
class_name GunRange
extends Node3D

## The FP arms ARE the player's guns (ADR-016 Amendment C).
const ARMORY: Array[String] = [
	"m16a1", "m14", "m60", "ak47", "rpd", "ppsh41",
	"mosin", "m70", "shotgun", "m1911", "rpg2",
]
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
var _wd: WeaponData = null
var _tune: Label = null
var _tune_dirty: bool = false


func _ready() -> void:
	GibSystem.gib_lifetime_s = 20.0
	_build_lane()
	_build_lighting()
	_spawn_player()
	for r in TARGET_RANGES:
		_spawn_target(r)
	_build_pen_row()
	_build_hud()
	_equip(0)
	print("[GUN RANGE] %d targets, %d guns. [ ] weapon | H zones | R reset | B drop sheet" % [
		TARGET_RANGES.size(), ARMORY.size()])


func _build_lane() -> void:
	var floor_body := StaticBody3D.new()
	floor_body.collision_layer = 1
	floor_body.collision_mask = 0
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

	# Side apron under the penetration lanes — the row sits at x 34..86, past the
	# 40m main lane, and without this slab it floats over the void.
	var apron := StaticBody3D.new()
	apron.collision_layer = 1
	apron.collision_mask = 0
	var ami := MeshInstance3D.new()
	var aplane := PlaneMesh.new()
	aplane.size = Vector2(80.0, 260.0)
	ami.mesh = aplane
	var asm := ShaderMaterial.new()
	asm.shader = load("res://terrain/shaders/lab_grid.gdshader")
	ami.material_override = asm
	apron.add_child(ami)
	var acs := CollisionShape3D.new()
	var abox := BoxShape3D.new()
	abox.size = Vector3(80.0, 0.2, 260.0)
	acs.shape = abox
	acs.position.y = -0.1
	apron.add_child(acs)
	add_child(apron)
	apron.position = Vector3(60.0, 0.0, -120.0)

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


func _equip(idx: int) -> void:
	_weapon_idx = wrapi(idx, 0, ARMORY.size())
	var wd: WeaponData = load("res://data/weapons/%s.tres" % ARMORY[_weapon_idx])
	if wd == null or _holder == null:
		return
	_wd = wd
	_tune_dirty = false
	_holder.equip_captured_weapon(wd)
	_holder.spare_magazines = 99
	_flash_board("== %s ==  zero %.0fm  |  %d dmg  |  %.0f m/s" % [
		wd.display_name, wd.zero_range, wd.base_damage, wd.projectile_speed])


func _spawn_target(dist: float) -> void:
	var d := GoreDummy.new()
	d.unit_id = "vc_guerilla"
	d.idle_only = true
	add_child(d)
	# Stagger sideways, widening with range: on one line the near men hide the far ones.
	var i: int = TARGET_RANGES.find(dist)
	var side: float = -1.0 if i % 2 == 0 else 1.0
	d.global_position = Vector3(side * (2.0 + dist * 0.02), 0.0, -dist)
	d.rotation.y = PI          # facing the firing line
	# WORLD-scaled, not fixed_size: screen-locked labels pile up into one mush at
	# the vanishing point and paint over the men you are trying to shoot.
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

	_tune = Label.new()
	_tune.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_tune.position = Vector2(14, -150)
	_tune.add_theme_font_size_override("font_size", 15)
	_tune.add_theme_color_override("font_color", Color(0.6, 0.85, 1.0))
	_tune.add_theme_color_override("font_outline_color", Color.BLACK)
	_tune.add_theme_constant_override("outline_size", 3)
	layer.add_child(_tune)

	_zone_im = ImmediateMesh.new()
	var zm := MeshInstance3D.new()
	zm.mesh = _zone_im
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.no_depth_test = true
	zm.material_override = m
	add_child(zm)


## Impact vs point of aim at each range: positive = above the crosshair.
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
		KEY_F1:
			_nudge("recoil_vertical", -0.05)
		KEY_F2:
			_nudge("recoil_vertical", 0.05)
		KEY_F3:
			_nudge("recoil_horizontal", -0.05)
		KEY_F4:
			_nudge("recoil_horizontal", 0.05)
		KEY_F6:
			_nudge("recoil_recovery", -0.5)
		KEY_F7:
			_nudge("recoil_recovery", 0.5)
		KEY_F5:
			_save_tuning()


## Recoil tuning bench (W-10). The M16 is HIS reference feel (ruling 2026-08-04);
## jitter deg/s = shots/s x random horizontal is the number that convicted the PPSh.
const _M16_JITTER: float = 6.25

func _nudge(field: String, step: float) -> void:
	if _wd == null:
		return
	var v: float = maxf(0.0, float(_wd.get(field)) + step)
	_wd.set(field, v)
	_tune_dirty = true


func _save_tuning() -> void:
	if _wd == null:
		return
	var path: String = "res://data/weapons/%s.tres" % ARMORY[_weapon_idx]
	var err: int = ResourceSaver.save(_wd, path)
	if err == OK:
		_tune_dirty = false
		_flash_board("SAVED %s -> %s" % [_wd.display_name, path])
	else:
		_flash_board("SAVE FAILED (%d) %s" % [err, path])


func _tune_text() -> String:
	if _wd == null:
		return ""
	var jitter: float = (_wd.fire_rate / 60.0) * _wd.recoil_horizontal
	return "RECOIL TUNE  %s%s\nvert  %.2f   [F1-/F2+]\nhoriz %.2f   [F3-/F4+]\nrecov %.1f   [F6-/F7+]\njitter %.2f deg/s  (M16 ref %.2f)\nF5 save to .tres" % [
		_wd.display_name, "  *UNSAVED*" if _tune_dirty else "",
		_wd.recoil_vertical, _wd.recoil_horizontal, _wd.recoil_recovery,
		jitter, _M16_JITTER]


func _process(_delta: float) -> void:
	# Bench rule: the mag never empties - dialing recoil must not stop for reloads.
	if _holder != null and _holder.current_weapon != null:
		_holder.current_ammo = _holder.current_weapon.magazine_size
	if _tune != null:
		_tune.text = _tune_text()
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


## THE PENETRATION ROW: material panels with a man behind each. bullet_system:
## a `soft_cover` hit keeps going at x0.8 energy, at most soft_left = 2 times -
## so the THIRD soft layer stops the round. `hard_surface` stops it outright.
const PEN_X0: float = 34.0      ## first lane, right of the main range
const PEN_SPACING: float = 6.0
const PEN_PANEL_Z: float = -16.0
const PEN_MAN_Z: float = -19.0

## name, layers, soft?, doctrine
const PEN_LANES: Array = [
	["NO COVER",     0, false, "control - this is the raw number"],
	["THATCH",       1, true,  "SOFT: lead goes through"],
	["BAMBOO",       1, true,  "SOFT: lead goes through"],
	["BRUSH",        1, true,  "SOFT: concealment, not cover"],
	["CRATE",        1, true,  "SOFT: lead goes through"],
	["THATCH x2",    2, true,  "SOFT x2: through both, x0.64"],
	["THATCH x3",    3, true,  "SOFT x3: BUDGET SPENT - the 3rd layer STOPS it"],
	["SANDBAG",      1, false, "HARD: stops the round"],
	["BUNKER LOG",   1, false, "HARD: stops the round"],
]

var _pen: Array = []    ## [{name, soft, layers, doctrine, man, label, last, hits}]


func _build_pen_row() -> void:
	var sign_l := Label3D.new()
	sign_l.text = "PENETRATION ROW  >>  SHOOT THROUGH THE COVER"
	sign_l.font_size = 80
	sign_l.pixel_size = 0.012
	sign_l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sign_l.modulate = Color(1.0, 0.75, 0.3)
	sign_l.outline_size = 20
	sign_l.position = Vector3(PEN_X0 + PEN_SPACING * 4.0, 6.5, PEN_PANEL_Z - 2.0)
	add_child(sign_l)

	for i in range(PEN_LANES.size()):
		var spec: Array = PEN_LANES[i]
		var lane_x: float = PEN_X0 + PEN_SPACING * float(i)
		var nm: String = str(spec[0])
		var layers: int = int(spec[1])
		var soft: bool = bool(spec[2])

		for k in range(layers):
			_build_panel(lane_x, PEN_PANEL_Z + float(k) * 0.7, nm, soft)

		var man := GoreDummy.new()
		man.unit_id = "vc_guerilla"
		man.idle_only = true
		add_child(man)
		man.global_position = Vector3(lane_x, 0.0, PEN_MAN_Z)
		man.rotation.y = PI

		var lbl := Label3D.new()
		lbl.font_size = 48
		lbl.pixel_size = 0.006
		lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		lbl.outline_size = 14
		lbl.position = Vector3(0, 3.0, 0)
		man.add_child(lbl)

		var rec: Dictionary = {"name": nm, "soft": soft, "layers": layers,
			"doctrine": str(spec[3]), "man": man, "label": lbl, "last": 0, "hits": 0}
		_pen.append(rec)
		var idx: int = _pen.size() - 1
		man.hit_taken.connect(func(zone: String, amount: int, _hp: int) -> void:
			var r: Dictionary = _pen[idx]
			r.last = amount
			r.hits = int(r.hits) + 1
			_log_line("PEN  %-11s  %-5s  %3d dmg   (%d hits through)" % [
				r.name, zone, amount, r.hits])
			_refresh_pen(idx))
		man.died.connect(func() -> void:
			_log_line("PEN  %-11s  >>> DOWN <<<" % nm))
		_refresh_pen(idx)


func _build_panel(x: float, z: float, nm: String, soft: bool) -> void:
	var body := StaticBody3D.new()
	body.name = "panel_%s" % nm.to_lower().replace(" ", "_")
	body.collision_layer = 1     # the layer LOS and bullets test against
	body.collision_mask = 0
	# bullet_system reads these GROUPS - not the mesh, the material, or the name.
	if soft:
		body.add_to_group("soft_cover")
	else:
		body.add_to_group("hard_surface")
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.8, 2.0, 0.2)
	col.shape = shape
	body.add_child(col)
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = shape.size
	mi.mesh = bm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.72, 0.60, 0.30) if soft else Color(0.42, 0.44, 0.46)
	mi.material_override = mat
	body.add_child(mi)
	body.position = Vector3(x, 1.0, z)
	add_child(body)


func _refresh_pen(i: int) -> void:
	var r: Dictionary = _pen[i]
	var lbl := r.label as Label3D
	var hits: int = int(r.hits)
	var last: int = int(r.last)
	var soft: bool = bool(r.soft)
	var layers: int = int(r.layers)
	# soft_left = 2, so three soft layers must stop the round.
	var should_pass: bool = layers == 0 or (soft and layers <= 2)
	var verdict: String = "- no rounds yet -"
	if hits > 0:
		verdict = "PENETRATED" if should_pass else "*** BUG: got through! ***"
	elif not should_pass:
		verdict = "STOPPED (shoot it to confirm)"
	lbl.modulate = Color(0.9, 0.95, 0.6) if should_pass else Color(0.75, 0.8, 0.85)
	if hits > 0 and not should_pass:
		lbl.modulate = Color(1.0, 0.3, 0.25)
	lbl.text = "%s
%s
%s   dmg %d   hits %d" % [r.name, r.doctrine, verdict, last, hits]
