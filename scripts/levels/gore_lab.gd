## gore_lab.gd - COMBAT BENCH: squad-vs-squad on a covered range.
##
## Your 5-man squad (one pigman) vs a 7-man VC/NVA wave, on the combat-lab
## cover field, with the full gore stack, HLL AI doctrine, and floating AI
## state text + vision lines so you can SEE what every brain is doing.
## Fresh enemy wave 8s after the last man drops; fallen allies replaced
## between waves. Frags on [3], medkit [4] + hold [F].
##
## No custom keybinds (e6qc law: lab commands must not collide with gameplay
## keys) - everything is shoot-driven and auto-respawning.
##
## Run: godot --path . res://scenes/levels/gore_lab.tscn
class_name GoreLab
extends Node3D

const ARENA: float = 44.0
const WALL_H: float = 4.0
const LAB_GRENADES: int = 25

const VC := "res://data/enemies/vc_rifleman.tres"
const NVA := "res://data/enemies/nva_regular.tres"
const SAPPER := "res://data/enemies/vc_sapper.tres"
## 5 vs 7 (Caleb): four riflemen, two NVA regulars, one belt-fed sapper.
const WAVE: Array[String] = [VC, VC, VC, VC, NVA, NVA, SAPPER]
const WAVE_RESPAWN_S: float = 8.0

var player: CharacterBody3D = null
var _hud: Label = null
var _enemies: Array[Node] = []
var _allies: Array[Node] = []
## AI debug vis (Caleb): floating state text above every head + live vision
## lines. Lab-only - reads AI fields, changes nothing.
var _dbg_labels: Dictionary = {}   # instance_id -> Label3D
var _dbg_mesh: MeshInstance3D = null
var _dbg_im: ImmediateMesh = null
var _wave: int = 0
var _wave_pending: bool = false
var _rng := RandomNumberGenerator.new()

const ALLY_COUNT: int = 5  # the full squad (Caleb)


func _ready() -> void:
	GibSystem.gib_lifetime_s = 25.0  # gibs linger for inspection (game default 12)
	_rng.seed = 20260710
	_build_range()
	_build_cover()
	_build_lighting()
	_spawn_player()
	_spawn_allies()
	_spawn_wave()
	_build_hud()
	_build_debug_vis()
	print("[GORE LAB] combat bench ready - 5-man squad vs 7-man waves. Frags [3], medkit [4]+[F].")


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


## Your fireteam (Caleb: "with more allies on my side this combat will feel
## more rounded out"). Fights with no SquadSystem: targeting rides
## CombatManager.active_enemies; FOLLOW rides GameManager.player. One pigman.
func _spawn_allies() -> void:
	for i in range(ALLY_COUNT):
		if _alive_allies() >= ALLY_COUNT:
			break
		# arc around the player spawn (-9, 4.5), tucked behind the hard block
		var pos := Vector3(-11.5 + float(i) * 1.3, 1.0, 5.8 + 0.6 * float(i % 2))
		var a := AllyBase.spawn_ally(self, pos)
		if a == null:
			continue
		a.set_order(AllyBase.OrderMode.FOLLOW)
		if i == 0:
			a.fire_rate_mult = 1.6  # the pig's rate; v2 grunt model like the rest (Caleb)
		_allies.append(a)


func _alive_allies() -> int:
	var n: int = 0
	for a in _allies:
		if is_instance_valid(a) and not a.is_dead():
			n += 1
	return n


## Live enemy fireteam at the far end - the combat-feel overlay. A fresh wave
## walks in after the last man drops.
func _spawn_wave() -> void:
	_wave += 1
	_wave_pending = false
	# Wave 1 spawns RELAXED (the sneaking bench). REINFORCEMENT waves arrive
	# ALERT with a rough fix on the battle - men walking INTO a known firefight
	# don't stroll in daydreaming (Caleb: wave 2 got deleted at spawn while its
	# perception ladder was still waking up). Entries staggered so seven men
	# don't materialize as one volley target.
	var idx: int = 0
	for data_path in WAVE:
		var pos := Vector3(_rng.randf_range(-16.0, 16.0), 1.0, _rng.randf_range(-19.0, -12.0))
		var delay: float = 0.0 if _wave == 1 else 0.6 * float(idx)
		idx += 1
		var dp: String = data_path
		if delay <= 0.0:
			_spawn_wave_man(dp, pos)
		else:
			get_tree().create_timer(delay).timeout.connect(func() -> void:
				_spawn_wave_man(dp, pos))
	print("[GORE LAB] wave %d inbound: %d men%s" % [_wave, WAVE.size(),
		"" if _wave == 1 else " (ALERT - they heard the battle)"])


func _spawn_wave_man(data_path: String, pos: Vector3) -> void:
	var e := EnemyBase.spawn_enemy(self, pos, data_path)
	if e == null:
		return
	_enemies.append(e)
	e.rotation.y = _rng.randf_range(0.0, TAU)
	if _wave > 1 and is_instance_valid(player):
		e.alert_tier = EnemyBase.AlertTier.ALERT
		e.last_known_target_pos = player.global_position + \
			Vector3(_rng.randf_range(-6.0, 6.0), 0.0, _rng.randf_range(-6.0, 6.0))


func _alive_enemies() -> int:
	var n: int = 0
	for e in _enemies:
		if is_instance_valid(e) and not e.is_dead():
			n += 1
	return n


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


## ---------- AI DEBUG VIS ----------

const TIER_COLORS: Array[Color] = [
	Color(0.5, 0.9, 0.5),   # RELAXED - green
	Color(0.95, 0.9, 0.4),  # SUSPICIOUS - yellow
	Color(1.0, 0.6, 0.2),   # ALERT - orange
	Color(1.0, 0.25, 0.25), # COMBAT - red
]


func _build_debug_vis() -> void:
	_dbg_im = ImmediateMesh.new()
	_dbg_mesh = MeshInstance3D.new()
	_dbg_mesh.mesh = _dbg_im
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.no_depth_test = true
	_dbg_mesh.material_override = m
	add_child(_dbg_mesh)


func _dbg_label_for(agent: Node3D) -> Label3D:
	var key: int = agent.get_instance_id()
	if _dbg_labels.has(key) and is_instance_valid(_dbg_labels[key]):
		return _dbg_labels[key]
	var l := Label3D.new()
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.fixed_size = true
	l.pixel_size = 0.0006
	l.font_size = 30
	l.outline_size = 8
	l.position = Vector3(0, 2.15, 0)
	agent.add_child(l)
	_dbg_labels[key] = l
	return l


func _name_of(n: Node) -> String:
	if n == null or not is_instance_valid(n):
		return "-"
	if n.is_in_group("player"):
		return "PLAYER"
	if n.is_in_group("allies"):
		return "ALLY"
	if n is GoreDummy:
		return "DUMMY"
	return "VC"


func _update_debug_vis() -> void:
	_dbg_im.clear_surfaces()
	var lines: Array = []  # [from, to, color]

	for e in _enemies:
		if not is_instance_valid(e):
			continue
		var lbl := _dbg_label_for(e)
		if e.is_dead():
			lbl.text = "DEAD"
			lbl.modulate = Color(0.5, 0.5, 0.5, 0.6)
			continue
		var tier: int = clampi(int(e.alert_tier), 0, 3)
		var state_name: String = Enums.AIState.keys()[int(e.current_state)]
		var goal_name: String = Enums.AIGoal.keys()[int(e.current_goal)]
		lbl.text = "%s | %s\n%s  tgt:%s%s\ncov:%s sup:%.1f exp:x%.1f" % [
			EnemyBase.AlertTier.keys()[tier], state_name, goal_name,
			_name_of(e.target), " (LOS)" if e.has_line_of_sight else "",
			"Y" if e.has_cover else "n", e.suppression_level, e._exposure_spread_mult()]
		lbl.modulate = TIER_COLORS[tier]
		if e.target != null and is_instance_valid(e.target):
			var from: Vector3 = e.global_position + Vector3.UP * 1.5
			if e.has_line_of_sight:
				lines.append([from, e.target.global_position + Vector3.UP * 1.0, Color(1.0, 0.2, 0.2, 0.85)])
			elif e.last_known_target_pos != Vector3.ZERO:
				lines.append([from, e.last_known_target_pos + Vector3.UP * 1.0, Color(1.0, 0.6, 0.2, 0.35)])

	for a in _allies:
		if not is_instance_valid(a):
			continue
		var lbl := _dbg_label_for(a)
		if a.is_dead():
			lbl.text = "KIA"
			lbl.modulate = Color(0.5, 0.5, 0.5, 0.6)
			continue
		var state_name: String = Enums.AIState.keys()[int(a.current_state)]
		var order_name: String = AllyBase.OrderMode.keys()[int(a.order_mode)]
		lbl.text = "ALLY | %s\n%s  tgt:%s%s  cov:%s wf:%s" % [
			state_name, order_name, _name_of(a.target),
			" (LOS)" if a.has_line_of_sight else "", "Y" if a.has_cover else "n",
			"Y" if a.weapons_free else "HOLD"]
		lbl.modulate = Color(0.45, 0.75, 1.0)
		if a.target != null and is_instance_valid(a.target) and a.has_line_of_sight:
			lines.append([a.global_position + Vector3.UP * 1.5,
				a.target.global_position + Vector3.UP * 1.0, Color(0.3, 0.7, 1.0, 0.75)])

	if lines.is_empty():
		return
	_dbg_im.surface_begin(Mesh.PRIMITIVE_LINES)
	for ln in lines:
		_dbg_im.surface_set_color(ln[2])
		_dbg_im.surface_add_vertex(ln[0])
		_dbg_im.surface_set_color(ln[2])
		_dbg_im.surface_add_vertex(ln[1])
	_dbg_im.surface_end()


func _process(_delta: float) -> void:
	_update_debug_vis()
	# wave respawn: last man down -> fresh fireteam after a breather
	if not _wave_pending and _alive_enemies() == 0 and not _enemies.is_empty():
		_wave_pending = true
		var t: SceneTreeTimer = get_tree().create_timer(WAVE_RESPAWN_S)
		t.timeout.connect(func() -> void:
			_enemies = _enemies.filter(func(e: Node) -> bool: return is_instance_valid(e))
			_allies = _allies.filter(func(a: Node) -> bool: return is_instance_valid(a))
			_spawn_allies()  # replace the fallen between waves
			if is_instance_valid(player):
				var em: EquipmentManager = player.get_node("EquipmentManager")
				if em.get_grenade_count() < 5:
					em.add_grenade(5 - em.get_grenade_count())
			_spawn_wave())
	if _hud == null:
		return
	_hud.text = "COMBAT BENCH - wave %d | enemies: %d | squad: %d/5
frag [3] | medkit [4] + hold [F] | AI labels: state | goal | target" % [
		_wave, _alive_enemies(), _alive_allies()]
