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

const VC := "res://data/enemies/vc_rifleman.tres"
const NVA := "res://data/enemies/nva_regular.tres"
const WAVE: Array[String] = [VC, VC, VC, NVA]
const WAVE_RESPAWN_S: float = 8.0

var player: CharacterBody3D = null
var dummy: GoreDummy = null
var _hud: Label = null
var _spawned: int = 0
var _drag_bone: PhysicalBone3D = null  # the HEAD - pinned to the player (Caleb: attach, don't pull)
var _drag_joint: PinJoint3D = null
var _enemies: Array[Node] = []
var _wave: int = 0
var _wave_pending: bool = false
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	GibSystem.gib_lifetime_s = 25.0  # gibs linger for inspection (game default 12)
	_rng.seed = 20260710
	_build_range()
	_build_cover()
	_build_lighting()
	_spawn_player()
	_spawn_dummy()
	_spawn_wave()
	_build_hud()
	print("[GORE LAB] combat bench ready - live VC/NVA waves + the gib dummy. Frags on [3].")


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
	# spawn BEHIND the big hard block at (-9, 2) - 3m of cover between you and
	# the enemy side; step out to engage
	player.global_position = Vector3(-9.0, 1.0, 4.5)
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

	# Shotgun on slot [2] for the pellet-cluster bench (Caleb is building the
	# real model; kar98k viewmodel stands in until then).
	var shotty: WeaponData = load("res://data/weapons/shotgun.tres")
	if shotty != null:
		weapon_holder.secondary_weapon = shotty
		weapon_holder.secondary_ammo = [shotty.magazine_size, 8]


func _spawn_dummy() -> void:
	dummy = GoreDummy.new()
	add_child(dummy)
	dummy.global_position = DUMMY_POS
	if player != null:
		dummy.look_at(Vector3(player.global_position.x, dummy.global_position.y, player.global_position.z), Vector3.UP)
	dummy.died.connect(_on_dummy_died)
	_spawned += 1


## Cover at the combat lab's four deliberate heights (0.5 prone / 1.0 crouch /
## 1.5 standing chest / 2.5 full LOS block) so the AI has real geometry to use
## and you have maneuvering room.
func _build_cover() -> void:
	var heights: Array[float] = [0.5, 1.0, 1.5, 2.5]
	var tints: Array[Color] = [
		Color(0.80, 0.84, 0.88), Color(0.72, 0.78, 0.84),
		Color(0.64, 0.72, 0.80), Color(0.52, 0.60, 0.70),
	]
	for i in range(26):
		var idx: int = _rng.randi() % heights.size()
		var hgt: float = heights[idx]
		var w: float = _rng.randf_range(0.8, 2.4)
		var d: float = _rng.randf_range(0.8, 2.4)
		var pos := Vector3(_rng.randf_range(-19.0, 19.0), hgt * 0.5, _rng.randf_range(-19.0, 19.0))
		if Vector2(pos.x, pos.z).length() < 4.0:
			continue  # keep the middle open
		var b := _cover_box(Vector3(w, hgt, d), pos, tints[idx])
		b.rotation.y = _rng.randf_range(0.0, TAU)
	# two hard blocks for real LOS breaks
	_cover_box(Vector3(6.0, 3.0, 1.0), Vector3(-9.0, 1.5, 2.0), tints[3])
	_cover_box(Vector3(1.0, 3.0, 6.0), Vector3(8.0, 1.5, -6.0), tints[3])


func _cover_box(size: Vector3, pos: Vector3, color: Color) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mi.material_override = mat
	body.add_child(mi)
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	body.add_child(cs)
	add_child(body)
	body.global_position = pos
	return body


## Live enemy fireteam at the far end - the combat-feel overlay. A fresh wave
## walks in after the last man drops.
func _spawn_wave() -> void:
	_wave += 1
	_wave_pending = false
	for data_path in WAVE:
		var pos := Vector3(_rng.randf_range(-16.0, 16.0), 1.0, _rng.randf_range(-19.0, -12.0))
		var e := EnemyBase.spawn_enemy(self, pos, data_path)
		if e != null:
			_enemies.append(e)
			# SNEAKING BENCH (Caleb: no superman AI): random facing, RELAXED -
			# the detection ladder (eyes, ears, your first shot) wakes them,
			# not the spawner. The combat lab's aim-at-player line was for
			# fight-testing; here stealth is part of the feel.
			e.rotation.y = _rng.randf_range(0.0, TAU)
	print("[GORE LAB] wave %d inbound: %d men" % [_wave, WAVE.size()])


func _alive_enemies() -> int:
	var n: int = 0
	for e in _enemies:
		if is_instance_valid(e) and not e.is_dead():
			n += 1
	return n


## Polled, not _unhandled_input: the player's own interact raycast consumes
## the event before the lab would see it. Polling cannot be shadowed.
func _try_toggle_grab() -> void:
	if _drag_bone != null:
		_release_grip("released the body")
		return
	# grab the nearest ragdolled body's HEAD within reach and PIN it to the
	# player (Caleb: hard attach - the most consistent grip; the constraint
	# solver hauls the body, the spine trails out straight behind the head)
	var best: PhysicalBone3D = null
	var best_d: float = 2.6
	for b in [dummy]:
		if not is_instance_valid(b) or b.model == null or not b.model.has_ragdoll():
			continue
		var head: PhysicalBone3D = b.model.ragdoll_bone("Head")
		if head == null or player == null:
			continue
		var d: float = head.global_position.distance_to(player.global_position)
		if d < best_d:
			best_d = d
			best = head
			b.model.wake_ragdoll()
	if best != null:
		_drag_bone = best
		_drag_joint = PinJoint3D.new()
		add_child(_drag_joint)
		_drag_joint.global_position = best.global_position  # pin where he lies - no snap
		_drag_joint.node_a = player.get_path()
		_drag_joint.node_b = best.get_path()
		player.set("external_speed_mult", 0.5)  # saving a man SLOWS you (design)
		print("[GORE LAB] grabbed him by the collar - walk to drag (50 pct speed), [F] to release")


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
		_release_grip("grip lost")
		return
	# Pinned drag: the joint does the hauling. We only watch for a fumbled
	# grip (solver snagged on geometry and the head is left far behind).
	if _drag_bone.global_position.distance_to(player.global_position) > 2.5:
		_release_grip("grip lost - he snagged on something")


func _release_grip(reason: String) -> void:
	_drag_bone = null
	if _drag_joint != null and is_instance_valid(_drag_joint):
		_drag_joint.queue_free()
	_drag_joint = null
	if is_instance_valid(player):
		player.set("external_speed_mult", 1.0)
	print("[GORE LAB] %s" % reason)


func _process(_delta: float) -> void:
	# wave respawn: last man down -> fresh fireteam after a breather
	if not _wave_pending and _alive_enemies() == 0 and not _enemies.is_empty():
		_wave_pending = true
		var t: SceneTreeTimer = get_tree().create_timer(WAVE_RESPAWN_S)
		t.timeout.connect(func() -> void:
			_enemies = _enemies.filter(func(e: Node) -> bool: return is_instance_valid(e))
			_spawn_wave())
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
	var drag_txt: String = "DRAGGING (50% speed) - [F] release" if _drag_bone != null else "[F] near the downed dummy: grab + drag (slows you 50%)"
	_hud.text = "GORE LAB - combat bench (wave %d, enemies alive: %d)
M16: ARMS / LEGS -> limb pops | HEAD -> kill + helmet flies | frag [3] -> multi-gib
dummy HP %s   removed: %s   clip: %s   dummy #%d
%s" % [_wave, _alive_enemies(), hp_txt, removed, clip, _spawned, drag_txt]
