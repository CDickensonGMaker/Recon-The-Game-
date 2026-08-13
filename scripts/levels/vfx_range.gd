extends Node3D

## vfx_range.gd - VFX bench. Every explosion kind, back to back, no radio net and
## no wait. Built to answer one question the support-fire range cannot: when a
## sheet looks frozen in-engine, is the SHEET wrong or is the PARTICLE SYSTEM
## failing to advance it?
##
## So the scene shows the same texture two ways, side by side:
##   LEFT  - a script-driven flipbook quad. It steps uv1_offset by hand every
##           frame, so it CANNOT fail to animate. This is the control.
##   RIGHT - the real GunFX.play_explosion_3d path the game actually uses.
## Left rolling + right frozen => the particle animation wiring is the bug, not
## the art. Both frozen => the sheet itself is wrong.
##
## Keys: 1-6 fire a kind · SPACE cycle · A auto-cycle on/off · F toggle a burning
## FireHazard · G grid of every raw sheet · N the REAL napalm run (9 drops) ·
## V cycle vantage (god cam / player eye 210m / player eye 100m) · R home god cam
## Run: godot --path . res://scenes/levels/vfx_range.tscn
##
## ROLE (war_room/2026-08-13_napalm_scale/): this is the GEOMETRY and
## COMPOSITION lab, in clean air. Size RULINGS happen on support_fire_range
## (real dispatch, world fog, night); the world is the final bench (ADR-015).

const KINDS: Array[String] = [
	"explosion_grenade", "explosion_40mm", "explosion_rocket",
	"explosion_mortar", "explosion_heavy", "explosion_napalm",
]
const AUTO_PERIOD: float = 2.2
## The control quad plays this sheet. 6x6 = the napalm sheet's grid.
const CTRL_SHEET := "res://assets/textures/fx/sheets/napalm_explosion_sheet.png"
const CTRL_H: int = 6
const CTRL_V: int = 6
## Napalm reads ~60m per drop (the run of 9 is the spectacle); the 512m outline
## stays as an absolute ruler so "covers the square" is visible, never trusted.
const DEMO_SQUARE_M: float = 512.0
const CAM_POS := Vector3(0.0, 300.0, 900.0)
const CAM_ROT := Vector3(-17.0, 0.0, 0.0)
const SHOT_POS := Vector3(0.0, 0.0, 0.0)      # centred IN the square
const CTRL_POS := Vector3(-560.0, 150.0, 0.0)
const CTRL_SIZE: float = 200.0
## Side-by-side row (key 0). Spacing was sized when napalm read ~513m; kept
## wide - the row is a composition strip, not a ruler (see _fire_all caveat).
const ROW_X0: float = -1550.0
const ROW_SPACING: float = 620.0
const ROW_Z: float = -900.0
const CAM_ROW := Vector3(0.0, 900.0, 2100.0)
const CAM_ROW_ROT := Vector3(-19.0, 0.0, 0.0)
## The vantages a size must be seen from before anyone calls it ruled. The god
## cam manufactured the 8/12 mis-ruling - ~950m out it shows a fireball at a
## quarter of the screen the 210m ground eye gives it. The demo's early beat
## lands 210m from the fsb centre (demo_game.gd NAPALM_RANGE_M); the siege
## beats read from the parapet at ~100m.
const VANTAGES: Array[Dictionary] = [
	{"name": "GOD CAM - composition only, NOT for size rulings",
		"pos": Vector3(0.0, 300.0, 900.0), "rot": Vector3(-17.0, 0.0, 0.0), "fov": 70.0},
	{"name": "PLAYER EYE 210m - the demo's early napalm beat",
		"pos": Vector3(0.0, 1.7, 210.0), "rot": Vector3.ZERO, "fov": 75.0},
	{"name": "PLAYER EYE 100m - the siege parapet",
		"pos": Vector3(0.0, 1.7, 100.0), "rot": Vector3.ZERO, "fov": 75.0},
]
## The real-canopy yardstick at the strike line: his 8/4 ruling sizes napalm
## "above the treelines", so the treeline is IN FRAME. Tallest shipped tree is
## broadleaf_c at 13.4m (data/veg_break_bands.json).
const TREELINE_Z: float = -30.0
const TREELINE_SPAN: float = 300.0
const TREELINE_STEP: float = 14.0

var _idx: int = 0
var _auto: bool = true
var _auto_t: float = 0.0
var _label: Label = null
var _hint: Label = null
var _ctrl_mat: StandardMaterial3D = null
var _ctrl_t: float = 0.0
var _ctrl_playing: bool = false
var _ctrl_dur: float = 0.7
var _ctrl_h: int = CTRL_H
var _ctrl_v: int = CTRL_V
var _sheet_cache: Dictionary = {}
var _hazard: Node = null
var _grid: Node3D = null
var _poles: Node3D = null
var _cam: Camera3D = null
var _vantage_i: int = 0
var _vantage_lbl: Label = null


func _ready() -> void:
	_build_world()
	_build_demo_square()
	_build_treeline()
	_build_yardsticks()
	_build_control_quad()
	_build_ui()
	_apply_vantage()
	_fire(KINDS[0])


func _apply_vantage() -> void:
	var v: Dictionary = VANTAGES[_vantage_i]
	_cam.position = v["pos"] as Vector3
	_cam.rotation_degrees = v["rot"] as Vector3
	_cam.fov = float(v["fov"])
	if _vantage_lbl != null:
		_vantage_lbl.text = "VIEW: %s   (V cycles)" % str(v["name"])


## Real shipped tree art in a band behind the strike line - the canopy the
## Summoner's "above the treelines" ruling measures against, one MultiMesh per
## variant. Deterministic yaw; a yardstick must not reshuffle between runs.
func _build_treeline() -> void:
	var variants: Array[String] = ["broadleaf_a", "broadleaf_b", "broadleaf_c"]
	var idx: int = 0
	for variant in variants:
		var mesh: Mesh = GroundClutter.load_glb_mesh("res://assets/world/vegetation/%s.glb" % variant)
		if mesh == null:
			continue
		var xforms: Array[Transform3D] = []
		var x: float = -TREELINE_SPAN + float(idx) * TREELINE_STEP
		while x <= TREELINE_SPAN:
			xforms.append(Transform3D(Basis(Vector3.UP, fposmod(x * 0.7, TAU)),
				Vector3(x, 0.0, TREELINE_Z)))
			x += TREELINE_STEP * float(variants.size())
		if xforms.is_empty():
			idx += 1
			continue
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = mesh
		mm.instance_count = xforms.size()
		for i in range(xforms.size()):
			mm.set_instance_transform(i, xforms[i])
		var mmi := MultiMeshInstance3D.new()
		mmi.name = "treeline_" + variant
		mmi.multimesh = mm
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mmi)
		idx += 1
	_sign(Vector3(-60.0, 20.0, TREELINE_Z), "TREELINE - tallest 13.4m", Color(0.55, 1.0, 0.55))


## Human and height references: sizes are measurements here, not impressions.
func _build_yardsticks() -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.92, 0.92, 0.86)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var man := MeshInstance3D.new()
	var cap := CapsuleMesh.new()
	cap.radius = 0.25
	cap.height = 1.8
	man.mesh = cap
	man.material_override = mat
	man.position = Vector3(6.0, 0.9, 180.0)
	add_child(man)
	_sign(Vector3(6.0, 3.2, 180.0), "MAN 1.8m", Color(0.8, 0.9, 1.0))
	var pole := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.4
	cm.bottom_radius = 0.4
	cm.height = 50.0
	pole.mesh = cm
	pole.material_override = mat
	pole.position = Vector3(40.0, 25.0, 0.0)
	add_child(pole)
	for h in range(10, 51, 10):
		_sign(Vector3(40.0, float(h), 0.0), "- %dm" % h, Color(1.0, 1.0, 0.6))


## A 512m outline on the ground - the demo map's footprint, as an absolute
## ruler. "Napalm covers the square" is then something you can SEE, not a number
## you have to take on trust.
func _build_demo_square() -> void:
	var h: float = DEMO_SQUARE_M * 0.5
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.25, 0.25)
	var bars: Array = [
		[Vector3(0, 0.4, -h), Vector3(DEMO_SQUARE_M, 0.8, 3.0)],
		[Vector3(0, 0.4, h), Vector3(DEMO_SQUARE_M, 0.8, 3.0)],
		[Vector3(-h, 0.4, 0), Vector3(3.0, 0.8, DEMO_SQUARE_M)],
		[Vector3(h, 0.4, 0), Vector3(3.0, 0.8, DEMO_SQUARE_M)],
	]
	for b: Array in bars:
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = b[1] as Vector3
		mi.mesh = bm
		mi.material_override = mat
		mi.position = b[0] as Vector3
		add_child(mi)
	_sign(Vector3(0, 22, h + 26), "DEMO SQUARE - 512m", Color(1.0, 0.4, 0.4))


func _build_world() -> void:
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(6000, 6000)
	ground.mesh = pm
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.16, 0.19, 0.13)   # jungle-ish, so soot has to read against it
	ground.material_override = gm
	add_child(ground)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52, 38, 0)
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
	# No glow: era look dies under bloom, and bloom would also mask a dull sheet.
	e.glow_enabled = false
	env.environment = e
	add_child(env)

	_cam = Camera3D.new()
	_cam.position = CAM_POS
	_cam.rotation_degrees = CAM_ROT
	_cam.fov = 70.0
	_cam.far = 12000.0       # the 0-key row view sits ~3km out; do not clip it away
	_cam.current = true
	add_child(_cam)


## The control: a hand-stepped flipbook that cannot silently fail to animate.
func _build_control_quad() -> void:
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(CTRL_SIZE, CTRL_SIZE)
	mi.mesh = q
	_ctrl_mat = StandardMaterial3D.new()
	_ctrl_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ctrl_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ctrl_mat.albedo_texture = load(CTRL_SHEET) as Texture2D
	# Show ONE cell and slide the window over the sheet by hand each frame.
	_ctrl_mat.uv1_scale = Vector3(1.0 / float(CTRL_H), 1.0 / float(CTRL_V), 1.0)
	mi.material_override = _ctrl_mat
	mi.position = CTRL_POS
	add_child(mi)
	_sign(CTRL_POS + Vector3(0, CTRL_SIZE * 0.62, 0),
		"CONTROL\nthis square MUST animate", Color(0.5, 1.0, 0.5))
	_sign(SHOT_POS + Vector3(0, 62, 0),
		"GAME PATH\nexplosions fire here", Color(1.0, 0.75, 0.3))


## In-world signage, so the scene explains itself instead of needing a legend.
func _sign(pos: Vector3, text: String, col: Color) -> void:
	var l := Label3D.new()
	l.text = text
	l.position = pos
	l.font_size = 96
	l.pixel_size = 0.02
	l.modulate = col
	l.outline_size = 24
	l.outline_modulate = Color(0, 0, 0, 1)
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(l)


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	_label = Label.new()
	_label.position = Vector2(24, 20)
	_label.add_theme_font_size_override("font_size", 26)
	layer.add_child(_label)
	_hint = Label.new()
	_hint.position = Vector2(24, 56)
	_hint.add_theme_font_size_override("font_size", 16)
	_hint.text = ("1-6 kind  |  SPACE next  |  A auto-cycle  |  N REAL napalm run (9 drops)  |  "
		+ "V vantage  |  F fire hazard  |  G raw sheet grid  |  0 FIRE ALL side by side  |  R home god cam\n"
		+ "LEFT quad = hand-stepped control (must animate).  "
		+ "RIGHT = real GunFX particle path.  CLEAN AIR - size rulings live on support_fire_range.")
	layer.add_child(_hint)
	_vantage_lbl = Label.new()
	_vantage_lbl.position = Vector2(24, 100)
	_vantage_lbl.add_theme_font_size_override("font_size", 18)
	layer.add_child(_vantage_lbl)


func _process(delta: float) -> void:
	# Control flipbook: step the UV window by hand, in sync with the shot that
	# just fired and over the same duration the game particle lives, so the two
	# sides are comparable frame for frame.
	if _ctrl_mat != null and _ctrl_playing:
		_ctrl_t += delta
		var total: int = _ctrl_h * _ctrl_v
		var frac: float = clampf(_ctrl_t / maxf(_ctrl_dur, 0.01), 0.0, 1.0)
		var f: int = mini(int(frac * float(total)), total - 1)
		var col: int = f % _ctrl_h
		var row: int = f / _ctrl_h
		_ctrl_mat.uv1_offset = Vector3(float(col) / float(_ctrl_h),
			float(row) / float(_ctrl_v), 0.0)
		if frac >= 1.0:
			_ctrl_playing = false

	if _auto:
		_auto_t -= delta
		if _auto_t <= 0.0:
			_auto_t = AUTO_PERIOD
			_next()


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	var k := event as InputEventKey
	match k.keycode:
		KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6:
			_auto = false
			_idx = k.keycode - KEY_1
			_fire(KINDS[_idx])
		KEY_SPACE:
			_auto = false
			_next()
		KEY_A:
			_auto = not _auto
			_auto_t = 0.0
		KEY_F:
			_toggle_hazard()
		KEY_G:
			_toggle_grid()
		KEY_N:
			_auto = false
			_fire_run()
		KEY_V:
			_vantage_i = (_vantage_i + 1) % VANTAGES.size()
			_apply_vantage()
		KEY_0:
			_auto = false
			_fire_all()
		KEY_R:
			_vantage_i = 0
			_apply_vantage()


func _next() -> void:
	_idx = (_idx + 1) % KINDS.size()
	_fire(KINDS[_idx])


func _fire(kind: String) -> void:
	var caveat: String = "   [ONE drop - the game fires %d, key N]" % FirePlan.NAPALM_DROPS \
		if kind == "explosion_napalm" else ""
	_label.text = "%s        (%d/%d)%s" % [kind, _idx + 1, KINDS.size(), caveat]
	_arm_control(kind)
	GunFX.play_explosion_3d(self, SHOT_POS, kind)


## The REAL napalm pattern - drop count, spacing and release ripple come from
## FirePlan/CASAirplane so this cannot drift from the shipping run, and every
## drop lays its burn carpet, exactly as cas_airplane._drop_napalm_strip does.
## Run axis is X: broadside to the player-eye vantages, per the broadside law.
func _fire_run() -> void:
	_label.text = "NAPALM RUN - %d drops on %.0fm spacing, the real pattern" % [
		FirePlan.NAPALM_DROPS, FirePlan.NAPALM_SPACING]
	_arm_control("explosion_napalm")
	for i in range(FirePlan.NAPALM_DROPS):
		@warning_ignore("integer_division")
		var off: float = float(i - FirePlan.NAPALM_DROPS / 2) * FirePlan.NAPALM_SPACING
		var pos: Vector3 = SHOT_POS + Vector3(off, 0.0, 0.0)
		get_tree().create_timer(float(i) * CASAirplane.NAPALM_STAGGER).timeout.connect(func() -> void:
			if not is_instance_valid(self):
				return
			GunFX.play_explosion_3d(self, pos, "explosion_napalm")
			FireHazard.create_at(self, pos, FirePlan.NAPALM_BLAST_M, FirePlan.NAPALM_BURN_S))


## Point the control quad at the SAME sheet this kind uses, and run it over the
## same duration as the game particle, so the two sides line up frame for frame.
func _arm_control(kind: String) -> void:
	var rel: String = "napalm_explosion_sheet"
	_ctrl_h = 6
	_ctrl_v = 6
	if kind == "explosion_mortar":
		rel = "mortar_burst_sheet"
		_ctrl_h = 4
		_ctrl_v = 4
	if not _sheet_cache.has(rel):
		_sheet_cache[rel] = load("res://assets/textures/fx/sheets/%s.png" % rel) as Texture2D
	_ctrl_mat.albedo_texture = _sheet_cache[rel]
	_ctrl_mat.uv1_scale = Vector3(1.0 / float(_ctrl_h), 1.0 / float(_ctrl_v), 1.0)
	# _burst() uses lifetime 0.7 * _KIND_LIFE; napalm holds longest.
	_ctrl_dur = 0.7 * (2.6 if kind == "explosion_napalm" else 1.0)
	_ctrl_t = 0.0
	_ctrl_playing = true


## Every kind at once, in a row, against 10m reference poles. Sizes cannot be
## judged by cycling one at a time - the eye has nothing to compare against and
## every explosion looks "big". Side by side is the only honest test.
func _fire_all() -> void:
	_label.text = "ALL KINDS - each pole is 10m.  Napalm shown as ONE DROP - the game fires 9 (key N)"
	_arm_control("explosion_napalm")
	# Pull back far enough that a 525m row of blasts fits in one frame.
	_cam.position = CAM_ROW
	_cam.rotation_degrees = CAM_ROW_ROT
	if _poles == null or not is_instance_valid(_poles):
		_build_poles()
	for i in KINDS.size():
		GunFX.play_explosion_3d(self, _row_pos(i), KINDS[i])


func _row_pos(i: int) -> Vector3:
	return Vector3(ROW_X0 + float(i) * ROW_SPACING, 0.0, ROW_Z)


## 10m poles: an absolute ruler in the shot, so "bigger" is a measurement and
## not an impression.
func _build_poles() -> void:
	_poles = Node3D.new()
	add_child(_poles)
	for i in KINDS.size():
		var mi := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.5
		cm.bottom_radius = 0.5
		cm.height = 10.0
		mi.mesh = cm
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.95, 0.95, 0.95)
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mi.material_override = m
		mi.position = _row_pos(i) + Vector3(0, 5, 0)
		_poles.add_child(mi)
		var l := Label3D.new()
		l.text = KINDS[i].replace("explosion_", "")
		l.position = _row_pos(i) + Vector3(0, 12, 0)
		l.font_size = 72
		l.pixel_size = 0.05
		l.outline_size = 20
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.no_depth_test = true
		_poles.add_child(l)


func _toggle_hazard() -> void:
	if _hazard != null and is_instance_valid(_hazard):
		_hazard.queue_free()
		_hazard = null
		return
	_hazard = FireHazard.create_at(self, Vector3(-2, 0, 14), 6.0, 9999.0)


## Every sheet laid out flat and unanimated, so the source art can be judged
## in-engine without the particle system in the way.
func _toggle_grid() -> void:
	if _grid != null and is_instance_valid(_grid):
		_grid.queue_free()
		_grid = null
		return
	_grid = Node3D.new()
	add_child(_grid)
	var sheets: Array[String] = [
		"napalm_explosion_sheet", "fire_loop_sheet", "fire_core_sheet",
		"smoke_loop_sheet", "mortar_burst_sheet", "muzzle_flash_sheet",
	]
	var x: float = -34.0
	for s in sheets:
		var mi := MeshInstance3D.new()
		var q := QuadMesh.new()
		q.size = Vector2(13, 13)
		mi.mesh = q
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.albedo_texture = load("res://assets/textures/fx/sheets/%s.png" % s) as Texture2D
		mi.material_override = m
		mi.position = Vector3(x, 24, -6)
		_grid.add_child(mi)
		x += 14.0
