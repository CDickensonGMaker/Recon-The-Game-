## dummy_lab.gd - STRIPPED COMBAT LAB: one VC test dummy, live hitzone wires.
##
## The combat range with everything torn out except the target: a vc_guerilla
## GoreDummy wearing the REAL HitzoneBuilder zones (mesh hulls + data/hitzones
## tuning - what you shoot here is byte-for-byte what ships on live enemies).
## Wireframes are ON at spawn so you can watch every zone ride the animation;
## the dummy respawns a few seconds after it drops.
##
## H toggles the wires (e6qc law: lab keys must not collide with gameplay keys).
##
## Run: dummy_lab.bat  /  godot --path . res://scenes/levels/dummy_lab.tscn
class_name DummyLab
extends Node3D

const ARENA: float = 24.0
const WALL_H: float = 3.0
const DUMMY_UNIT := "vc_guerilla"
const RESPAWN_S: float = 4.0

var player: CharacterBody3D = null
var _dummy: GoreDummy = null
var _hud: Label = null
var _zone_im: ImmediateMesh = null
var _zones_visible: bool = true


func _ready() -> void:
	GibSystem.gib_lifetime_s = 25.0  # gibs linger for inspection (game default 12)
	_build_range()
	_build_lighting()
	_spawn_player()
	_spawn_dummy()
	_build_overlay()
	print("[DUMMY LAB] one %s dummy wearing the live hitzones - wires ON, H toggles." % DUMMY_UNIT)


func _build_range() -> void:
	var floor_body := StaticBody3D.new()
	floor_body.collision_layer = 1
	floor_body.collision_mask = 0
	var mi := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(ARENA, ARENA)
	mi.mesh = plane
	var sm := ShaderMaterial.new()
	sm.shader = load("res://terrain/shaders/lab_grid.gdshader")
	mi.material_override = sm
	floor_body.add_child(mi)
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(ARENA, 0.2, ARENA)
	cs.shape = box
	cs.position.y = -0.1
	floor_body.add_child(cs)
	add_child(floor_body)

	# Perimeter walls so grenades stay on the collision floor.
	var half: float = ARENA * 0.5
	for w in [
		[Vector3(0, WALL_H * 0.5, -half), Vector3(ARENA, WALL_H, 0.4)],
		[Vector3(0, WALL_H * 0.5, half), Vector3(ARENA, WALL_H, 0.4)],
		[Vector3(-half, WALL_H * 0.5, 0), Vector3(0.4, WALL_H, ARENA)],
		[Vector3(half, WALL_H * 0.5, 0), Vector3(0.4, WALL_H, ARENA)],
	]:
		var wall := StaticBody3D.new()
		wall.collision_layer = 1
		wall.collision_mask = 0
		var wmi := MeshInstance3D.new()
		var wm := BoxMesh.new()
		wm.size = w[1]
		wmi.mesh = wm
		var wmat := StandardMaterial3D.new()
		wmat.albedo_color = Color(0.55, 0.58, 0.62)
		wmi.material_override = wmat
		wall.add_child(wmi)
		var wcs := CollisionShape3D.new()
		var wbox := BoxShape3D.new()
		wbox.size = w[1]
		wcs.shape = wbox
		wall.add_child(wcs)
		add_child(wall)
		wall.position = w[0]


func _build_lighting() -> void:
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52, -35, 0)
	sun.light_energy = 1.1
	sun.shadow_enabled = false
	add_child(sun)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.86, 0.88, 0.92)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.75, 0.78, 0.82)
	e.ambient_light_energy = 0.9
	env.environment = e
	add_child(env)


func _spawn_player() -> void:
	var scene: PackedScene = load("res://scenes/player/player.tscn")
	player = scene.instantiate() as CharacterBody3D
	add_child(player)
	player.global_position = Vector3(0.0, 1.0, 5.0)
	GameManager.player = player

	# The REAL game HUD - the lab must read exactly like the shipped game.
	var hud: HUD = load("res://scenes/ui/hud.tscn").instantiate() as HUD
	add_child(hud)
	var health_system: HealthSystem = player.get_node("HealthSystem")
	var weapon_holder: WeaponHolder = player.get_node("Head/Camera3D/WeaponHolder")
	var equipment_manager: EquipmentManager = player.get_node("EquipmentManager")
	var grenade_handler: GrenadeHandler = player.get_node("Head/Camera3D/GrenadeHandler")
	hud.setup(health_system, weapon_holder, equipment_manager, grenade_handler)


func _spawn_dummy() -> void:
	_dummy = GoreDummy.new()
	_dummy.unit_id = DUMMY_UNIT
	add_child(_dummy)
	_dummy.global_position = Vector3(0.0, 0.0, -5.0)
	_dummy.rotation.y = PI  # face the shooter
	_dummy.died.connect(func() -> void:
		var t: SceneTreeTimer = get_tree().create_timer(RESPAWN_S)
		t.timeout.connect(func() -> void:
			if is_instance_valid(_dummy):
				_dummy.queue_free()
			_spawn_dummy()))


func _build_overlay() -> void:
	_zone_im = ImmediateMesh.new()
	var zm := MeshInstance3D.new()
	zm.mesh = _zone_im
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.no_depth_test = true
	zm.material_override = m
	add_child(zm)

	var layer := CanvasLayer.new()
	layer.layer = 1
	add_child(layer)
	_hud = Label.new()
	_hud.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_hud.position = Vector2(-620, 12)
	_hud.custom_minimum_size = Vector2(600, 0)
	_hud.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_hud.add_theme_font_size_override("font_size", 13)
	_hud.add_theme_color_override("font_color", Color(0.92, 0.9, 0.8, 0.85))
	layer.add_child(_hud)


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo and key.keycode == KEY_H:
		_zones_visible = not _zones_visible


func _update_zone_vis() -> void:
	_zone_im.clear_surfaces()
	if not _zones_visible:
		return
	_zone_im.surface_begin(Mesh.PRIMITIVE_LINES)
	_zone_im.surface_set_color(Color(0, 0, 0, 0))
	_zone_im.surface_add_vertex(Vector3.ZERO)
	_zone_im.surface_set_color(Color(0, 0, 0, 0))
	_zone_im.surface_add_vertex(Vector3.ZERO)
	for hz in get_tree().get_nodes_in_group("hitzone"):
		if hz is Area3D and is_instance_valid(hz):
			HitzoneBuilder.draw_zone_wire(_zone_im, hz as Area3D)
	_zone_im.surface_end()


func _process(_delta: float) -> void:
	_update_zone_vis()
	if _hud == null:
		return
	var hp: int = _dummy.hp if is_instance_valid(_dummy) else 0
	var clip: String = _dummy.current_clip() if is_instance_valid(_dummy) else "-"
	_hud.text = "DUMMY LAB - %s | HP %d/%d | clip: %s | wires [H]: %s
HEAD red | BODY yellow | GUT orange | arms light blue | legs blue" % [
		DUMMY_UNIT, hp, GoreDummy.MAX_HP, clip, "ON" if _zones_visible else "off"]
