extends Node3D

## Support Fire Range — the fire-support + destruction bench (ADR-031 PROPOSED). Player +
## one RTO on a flat field of destructible trees and fort segments, with every fire-support
## tier on tap via the shared FireSupportBench rig (the same rig the AI arena uses, ADR-023).
## Purpose: verify (a) every support effect fires + telegraphs and (b) it destroys.
## Keys: T open the net · 1 bombs / 2 napalm / 3 arty / 4 mortar / 5 spectre / 6 CBU /
## 7 willy-pete · LMB send while a call is placed · RMB back out.
## Run: godot --path . res://scenes/levels/support_fire_range.tscn
## NOT the worst-case PERF rig — that is the AI arena (18v18 + this same bench). Measure the
## napalm+AC-47+firefight single-frame spike THERE, on the Intel-UHD floor, before P4/P5 ship.

const FIELD := 200.0

var player: CharacterBody3D = null
var _director: FieldDirector = null
var _toast: Label = null
var _toast_t: float = 0.0


func _ready() -> void:
	_build_ground()
	_build_light()
	_spawn_player_and_rto()
	if player != null:
		_director = FireSupportBench.wire(self, player, FIELD)
		_director.toast.connect(_on_toast)
	_build_target_field()
	_build_hint()


func _build_ground() -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(FIELD, 1.0, FIELD)
	shape.shape = box
	shape.position = Vector3(0.0, -0.5, 0.0)
	body.add_child(shape)
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(FIELD, FIELD)
	mi.mesh = pm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.28, 0.30, 0.18)
	mi.material_override = mat
	body.add_child(mi)
	add_child(body)


func _build_light() -> void:
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55.0, -35.0, 0.0)
	sun.light_energy = 1.1
	sun.shadow_enabled = false   # ADR-026: no dynamic shadow on the bench
	add_child(sun)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_SKY
	e.sky = Sky.new()
	e.sky.sky_material = ProceduralSkyMaterial.new()
	e.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	e.ambient_light_energy = 0.6
	env.environment = e
	add_child(env)


func _spawn_player_and_rto() -> void:
	var scene: PackedScene = load("res://scenes/player/player.tscn") as PackedScene
	if scene == null:
		return
	player = scene.instantiate() as CharacterBody3D
	add_child(player)
	player.set("allow_photo_mode", false)
	player.global_position = Vector3(0.0, 1.0, 6.0)
	GameManager.player = player
	var cam := player.get_node_or_null("Head/Camera3D") as Camera3D
	if cam != null:
		cam.current = true
	# The RTO: a commandable radioman carrying the PRC-25, within the 10m leash so the net
	# is always up. Same pattern as the arena — no bespoke entity.
	var rto: AllyBase = AllyBase.spawn_ally(self, player.global_position + Vector3(2.0, 0.0, 1.0))
	if rto == null:
		return
	rto.add_to_group("radioman")
	rto.member = {"nick": "SPARKS", "mos": "RTO"}
	rto.set_sprite("us_grunt_rto", "m16a1", "US")
	rto.set_order(AllyBase.OrderMode.FOLLOW)
	var handset := RadioHandset.attach_to(rto)
	if handset != null:
		player.call("bind_radio_handset", handset)


## Trees the player fells, and fort segments a blast tears out — the destruction targets.
func _build_target_field() -> void:
	for row in range(4):
		var z: float = -20.0 - float(row) * 12.0
		for col in range(6):
			var x: float = -30.0 + float(col) * 12.0
			FellableTree.create(self, Vector3(x, 0.0, z))
	var wall := BoxMesh.new()
	wall.size = Vector3(3.0, 2.0, 1.0)
	FireSupportBench.spawn_fort(self, Vector3(-8.0, 0.0, -14.0), wall, Vector3(3.0, 2.0, 1.0), "sandbag", 110)
	FireSupportBench.spawn_fort(self, Vector3(8.0, 0.0, -14.0), wall, Vector3(3.0, 2.0, 1.0), "sandbag", 110)


func _build_hint() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var hint := Label.new()
	hint.text = "SUPPORT FIRE RANGE   T net  |  1 bombs 2 napalm 3 arty 4 mortar 5 spectre 6 CBU 7 WP  |  LMB send  RMB back"
	hint.position = Vector2(16.0, 12.0)
	layer.add_child(hint)
	_toast = Label.new()
	_toast.position = Vector2(16.0, 40.0)
	layer.add_child(_toast)


## Willy Pete has no menu slot (menu is 1-6); the bench binds it to 7 directly, reusing the
## whole arm-and-place flow (LMB commits, RMB backs out — FieldDirector owns that input).
func _unhandled_input(event: InputEvent) -> void:
	if _director == null:
		return
	if event is InputEventKey and (event as InputEventKey).pressed and not (event as InputEventKey).echo:
		if (event as InputEventKey).keycode == KEY_7:
			_director.arm_fire_mission("wp")


func _on_toast(text: String) -> void:
	if _toast != null:
		_toast.text = text
		_toast_t = 4.0


func _process(delta: float) -> void:
	if _toast_t > 0.0:
		_toast_t -= delta
		if _toast_t <= 0.0 and _toast != null:
			_toast.text = ""
