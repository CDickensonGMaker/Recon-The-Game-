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

const ARENA: float = 44.0
const WALL_H: float = 4.0
const DUMMY_POS := Vector3(0, 0.1, -6.0)
const RESPAWN_S: float = 10.0   # long enough to walk up and inspect the result
const LAB_GRENADES: int = 25

var player: CharacterBody3D = null
var dummy: GoreDummy = null
var drag_body: GoreDummy = null
var _hud: Label = null
var _spawned: int = 0
var _drag_bone: PhysicalBone3D = null


func _ready() -> void:
	GibSystem.gib_lifetime_s = 25.0  # gibs linger for inspection (game default 12)
	_build_range()
	_build_lighting()
	_spawn_player()
	_spawn_dummy()
	_spawn_drag_body()
	_build_hud()
	print("[GORE LAB] ready - shoot limbs/head, frag with [3]; dummy respawns %.0fs." % RESPAWN_S)


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

	# Perimeter walls - grenades bounce and roll; without these they leave the
	# collision floor and fall into the void.
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

	# Explosion-gib testing needs ordnance: top the player up well past field load.
	equipment_manager.add_grenade(LAB_GRENADES - equipment_manager.get_grenade_count())


func _spawn_dummy() -> void:
	dummy = GoreDummy.new()
	add_child(dummy)
	dummy.global_position = DUMMY_POS
	if player != null:
		dummy.look_at(Vector3(player.global_position.x, dummy.global_position.y, player.global_position.z), Vector3.UP)
	dummy.died.connect(_on_dummy_died)
	_spawned += 1


## The drag-test casualty: an unconscious man already down - walk up, [F] to
## grab, walk to pull him, [F] to let go. Proves the ragdoll IS the draggable
## body (the medic drag-to-cover beat).
func _spawn_drag_body() -> void:
	drag_body = GoreDummy.new()
	drag_body.unconscious = true
	add_child(drag_body)
	drag_body.global_position = Vector3(6.0, 0.1, -2.0)


## Polled, not _unhandled_input: the player's own interact raycast consumes
## the event before the lab would see it. Polling cannot be shadowed.
func _try_toggle_grab() -> void:
	if _drag_bone != null:
		_drag_bone = null
		print("[GORE LAB] released the body")
		return
	# grab the nearest ragdolled body's hips within reach
	var best: PhysicalBone3D = null
	var best_d: float = 2.6
	for b in [drag_body, dummy]:
		if not is_instance_valid(b) or b.model == null or not b.model.has_ragdoll():
			continue
		var hips: PhysicalBone3D = b.model.ragdoll_bone("Hips")
		if hips == null or player == null:
			continue
		var d: float = hips.global_position.distance_to(player.global_position)
		if d < best_d:
			best_d = d
			best = hips
			b.model.wake_ragdoll()
	if best != null:
		_drag_bone = best
		print("[GORE LAB] grabbed the body - walk to drag, [F] to release")


func _on_dummy_died() -> void:
	var timer: SceneTreeTimer = get_tree().create_timer(RESPAWN_S)
	timer.timeout.connect(func() -> void:
		if is_instance_valid(dummy):
			dummy.queue_free()
		_spawn_dummy()
		# keep the frag supply topped up between dummies
		if is_instance_valid(player):
			var em: EquipmentManager = player.get_node("EquipmentManager")
			if em.get_grenade_count() < 5:
				em.add_grenade(5 - em.get_grenade_count()))


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


func _physics_process(_delta: float) -> void:
	if Input.is_action_just_pressed("interact"):
		_try_toggle_grab()
	if _drag_bone == null:
		return
	if not is_instance_valid(_drag_bone) or player == null:
		_drag_bone = null
		return
	# pull the hips toward a point at your heels - the body trails as you walk
	var anchor: Vector3 = player.global_position + (-player.global_transform.basis.z) * 0.9
	anchor.y = _drag_bone.global_position.y * 0.5 + (player.global_position.y - 0.7) * 0.5
	var to_anchor: Vector3 = anchor - _drag_bone.global_position
	if to_anchor.length() > 3.5:
		_drag_bone = null  # yanked free
		print("[GORE LAB] grip lost")
		return
	_drag_bone.linear_velocity = (to_anchor * 6.0).limit_length(4.5)


func _process(_delta: float) -> void:
	if _hud == null:
		return
	var removed: String = "none"
	var hp_txt: String = "-"
	var clip: String = "-"
	if is_instance_valid(dummy):
		var r: Array[String] = dummy.regions_removed()
		if not r.is_empty():
			removed = ", ".join(r)
		hp_txt = "%d/%d" % [dummy.hp, GoreDummy.MAX_HP]
		clip = dummy.current_clip()
	var drag_txt: String = "DRAGGING - [F] release" if _drag_bone != null else "[F] near a downed body: grab + drag"
	_hud.text = "GORE LAB - us_grunt_v2 rig verification
M16: ARMS / LEGS -> limb pops | HEAD -> kill + helmet flies | frag [3] -> multi-gib
HP %s   removed: %s   clip: %s   dummy #%d
%s
bench rules exaggerated; console prints the live-threshold verdict" % [hp_txt, removed, clip, _spawned, drag_txt]
