## gore_lab.gd - GORE TEST SITE: verify the us_grunt_v2 gib rigging with live fire.
##
## One us_grunt_v2 dummy on a gridded range, you with the M16 (the shipped
## default loadout). Shoot limbs - they pop and the gore caps become stumps;
## shoot the head - it kills, the head pops, the helmet flies (bone-attached
## gear separating is the whole point of the rig contract). Dummy respawns 3s
## after death. Bench rules are exaggerated (every limb hit pops) - the console
## prints what the LIVE GORE_WORKFLOW thresholds would have done.
##
## No custom keybinds (e6qc law: lab commands must not collide with gameplay
## keys) - everything is shoot-driven and auto-respawning.
##
## Run: godot --path . res://scenes/levels/gore_lab.tscn
class_name GoreLab
extends Node3D

const ARENA: float = 24.0
const DUMMY_POS := Vector3(0, 0.1, -6.0)
const RESPAWN_S: float = 3.0

var player: CharacterBody3D = null
var dummy: GoreDummy = null
var _hud: Label = null
var _spawned: int = 0


func _ready() -> void:
	_build_range()
	_build_lighting()
	_spawn_player()
	_spawn_dummy()
	_build_hud()
	print("[GORE LAB] ready - shoot limbs/head; dummy respawns. Watch the caps + helmet.")


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
	player.global_position = Vector3(0, 1.0, 8.0)
	GameManager.player = player

	# The REAL game HUD (same wiring as game_world.gd) - the lab must read
	# exactly like the shipped game, not a mock.
	var hud: HUD = load("res://scenes/ui/hud.tscn").instantiate() as HUD
	add_child(hud)
	var health_system: HealthSystem = player.get_node("HealthSystem")
	var weapon_holder: WeaponHolder = player.get_node("Head/Camera3D/WeaponHolder")
	var equipment_manager: EquipmentManager = player.get_node("EquipmentManager")
	var grenade_handler: GrenadeHandler = player.get_node("Head/Camera3D/GrenadeHandler")
	hud.setup(health_system, weapon_holder, equipment_manager, grenade_handler)


func _spawn_dummy() -> void:
	dummy = GoreDummy.new()
	add_child(dummy)
	dummy.global_position = DUMMY_POS
	if player != null:
		dummy.look_at(Vector3(player.global_position.x, dummy.global_position.y, player.global_position.z), Vector3.UP)
	dummy.died.connect(_on_dummy_died)
	_spawned += 1


func _on_dummy_died() -> void:
	var timer: SceneTreeTimer = get_tree().create_timer(RESPAWN_S)
	timer.timeout.connect(func() -> void:
		if is_instance_valid(dummy):
			dummy.queue_free()
		_spawn_dummy())


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 1
	add_child(layer)
	# Lab status rides top-right so the REAL game HUD owns its normal corners.
	_hud = Label.new()
	_hud.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_hud.position = Vector2(-620, 12)
	_hud.custom_minimum_size = Vector2(600, 0)
	_hud.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_hud.add_theme_font_size_override("font_size", 13)
	_hud.add_theme_color_override("font_color", Color(0.92, 0.9, 0.8, 0.85))
	layer.add_child(_hud)


func _process(_delta: float) -> void:
	if _hud == null:
		return
	var removed: String = "none"
	var hp_txt: String = "-"
	if is_instance_valid(dummy):
		var r: Array[String] = dummy.regions_removed()
		if not r.is_empty():
			removed = ", ".join(r)
		hp_txt = "%d/%d" % [dummy.hp, GoreDummy.MAX_HP]
	_hud.text = "GORE LAB - us_grunt_v2 rig verification
M16: shoot ARMS / LEGS -> limb pops off, cap shows | HEAD -> kill + helmet flies
HP %s   removed: %s   dummy #%d
bench rules exaggerated; console prints the live-threshold verdict" % [hp_txt, removed, _spawned]
