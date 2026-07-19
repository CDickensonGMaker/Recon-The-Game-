## gore_lab.gd - COMBAT BENCH: player (+optional squad) vs auto-respawning
## VC/NVA waves on a cover field, with AI state/vision debug overlays.
## Lab keys must not collide with gameplay keys.
class_name GoreLab
extends Node3D

const ARENA: float = 44.0
const WALL_H: float = 4.0
const LAB_GRENADES: int = 25

const VC := "res://data/enemies/vc_rifleman.tres"
const NVA := "res://data/enemies/nva_regular.tres"
const SAPPER := "res://data/enemies/vc_sapper.tres"
const WAVE: Array[String] = [VC, VC, VC, VC, NVA, NVA, SAPPER]
const WAVE_RESPAWN_S: float = 8.0

var player: CharacterBody3D = null
var _hud: Label = null
var _enemies: Array[Node] = []
var _allies: Array[Node] = []
## AI debug vis: lab-only - reads AI fields, changes nothing.
var _dbg_labels: Dictionary = {}   # instance_id -> Label3D
var _dbg_mesh: MeshInstance3D = null
var _dbg_im: ImmediateMesh = null
var _wave: int = 0
var _wave_pending: bool = false
var _rng := RandomNumberGenerator.new()

## 0 = solo bench; set 5 for squad runs.
const ALLY_COUNT: int = 0


func _ready() -> void:
	GibSystem.gib_lifetime_s = 25.0  # gibs linger for inspection (game default 12)
	_rng.seed = 20260710
	_build_range()
	_build_cover()
	_build_lighting()
	_plant_vegetation()
	_bake_navmesh()
	_spawn_player()
	_spawn_allies()
	_spawn_wave()
	_build_hud()
	_build_debug_vis()
	var side: String = "SOLO" if ALLY_COUNT == 0 else "%d-man squad" % ALLY_COUNT
	print("[GORE LAB] combat bench ready - %s vs 7-man waves. Frags [3], medkit [4]+[F]." % side)


func _build_range() -> void:
	var floor_body := StaticBody3D.new()
	floor_body.collision_layer = 1
	floor_body.collision_mask = 0
	floor_body.add_to_group("nav_source")
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

	# Perimeter walls: without them grenades roll off the collision floor into the void.
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
		wall.add_to_group("nav_source")
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


## Vegetation hugs the arena walls: the cover field (+-19) and the wave spawn
## lanes must stay clear.
const VEG_DIR := "res://assets/world/vegetation/"
const PALM_VARIANTS: Array[String] = [
	"jungle_palm_a1", "jungle_palm_a2", "jungle_palm_a3",
	"jungle_palm_b1", "jungle_palm_b2", "jungle_palm_b3",
]
## Wall-margin ring: between the inner wall face (+-21.8) and the cover field.
const PALM_SPOTS: Array[Vector3] = [
	Vector3(-18.0, 0.0, -20.3), Vector3(-7.0, 0.0, -20.6),
	Vector3(3.5, 0.0, -20.2), Vector3(14.0, 0.0, -20.5),
	Vector3(-14.0, 0.0, 20.5), Vector3(-3.0, 0.0, 20.2),
	Vector3(8.0, 0.0, 20.6), Vector3(18.0, 0.0, 20.3),
	Vector3(-20.5, 0.0, 9.0), Vector3(20.4, 0.0, -5.0),
]

var _sway_mats: Dictionary = {}  # material name -> shared ShaderMaterial


func _plant_vegetation() -> void:
	if not ResourceLoader.exists(VEG_DIR + PALM_VARIANTS[0] + ".glb"):
		push_warning("[GORE LAB] vegetation GLBs missing - run tools/make_jungle_vegetation.py")
		return
	var planted: int = 0
	for i in range(PALM_SPOTS.size()):
		var variant: String = PALM_VARIANTS[i % PALM_VARIANTS.size()]
		var packed: PackedScene = load(VEG_DIR + variant + ".glb") as PackedScene
		if packed == null:
			continue
		var palm := packed.instantiate() as Node3D
		if palm == null:
			continue
		add_child(palm)
		palm.global_position = PALM_SPOTS[i]
		palm.rotation.y = _rng.randf_range(0.0, TAU)
		_apply_sway(palm)
		_add_trunk_collider(palm)
		planted += 1
	var fans: int = _plant_grass()
	print("[GORE LAB] vegetation planted: %d palms, %d grass fans (sway shader live)" % [planted, fans])


## Swap the imported GLB materials for the shared vegetation_sway shader.
func _apply_sway(root: Node3D) -> void:
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for c in n.get_children():
			stack.push_back(c)
		var mi := n as MeshInstance3D
		if mi == null or mi.mesh == null:
			continue
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		for s in range(mi.mesh.get_surface_count()):
			var src := mi.mesh.surface_get_material(s) as BaseMaterial3D
			if src == null:
				continue
			var key: String = src.resource_name
			if not _sway_mats.has(key):
				var leaf: bool = key.findn("leaf") != -1
				var flutter: float = 0.09 if leaf else 0.015
				var scissor: float = 0.4 if leaf else 0.05
				_sway_mats[key] = GroundClutter.make_sway_material(
					src.albedo_texture, 0.35, flutter, scissor)
			var sway: ShaderMaterial = _sway_mats[key]
			mi.set_surface_override_material(s, sway)


## Thin static cylinder so bullets/grenades/men respect the trunk.
func _add_trunk_collider(palm: Node3D) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.add_to_group("nav_source")
	var cs := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 0.3
	cyl.height = 3.0
	cs.shape = cyl
	cs.position.y = 1.5
	body.add_child(cs)
	palm.add_child(body)


## Four swaying grass strips, one along each wall (6-tri star-fans, MultiMesh).
func _plant_grass() -> int:
	var fan_mesh: Mesh = GroundClutter.load_glb_mesh(VEG_DIR + "grass_fan.glb")
	if fan_mesh == null:
		return 0
	var tex: Texture2D = load("res://terrain/textures/clutter/grassland_2.png") as Texture2D
	var mat: ShaderMaterial = GroundClutter.make_sway_material(tex, 0.18, 0.05)
	var half: float = ARENA * 0.5
	## Rect2: (x, z, width, depth) strips just inside the walls.
	var strips: Array[Rect2] = [
		Rect2(-half + 0.6, -half + 0.6, ARENA - 1.2, 2.2),
		Rect2(-half + 0.6, half - 2.8, ARENA - 1.2, 2.2),
		Rect2(-half + 0.6, -half + 2.8, 2.2, ARENA - 5.6),
		Rect2(half - 2.8, -half + 2.8, 2.2, ARENA - 5.6),
	]
	var total: int = 0
	for strip in strips:
		var mmi := MultiMeshInstance3D.new()
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.instance_count = 90
		mm.mesh = fan_mesh
		mmi.multimesh = mm
		mmi.material_override = mat
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mmi)
		for i in range(mm.instance_count):
			var pos := Vector3(
				_rng.randf_range(strip.position.x, strip.position.x + strip.size.x),
				0.0,
				_rng.randf_range(strip.position.y, strip.position.y + strip.size.y))
			var basis := Basis(Vector3.UP, _rng.randf_range(0.0, TAU))
			var s: float = _rng.randf_range(0.9, 1.6)
			basis = basis.scaled(Vector3(1.2 * s, 0.9 * s, 1.2 * s))
			mm.set_instance_transform(i, Transform3D(basis, pos))
		total += mm.instance_count
	return total


## Bake a NavigationRegion3D over the arena's static colliders. MUST run after
## cover + vegetation so trunks and boxes are carved out of the walkable surface.
func _bake_navmesh() -> void:
	var region := NavigationRegion3D.new()
	region.add_to_group("lab_navmesh")
	var nm := NavigationMesh.new()
	nm.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	# The default source mode parses the REGION's own children (none here) -
	# 0 polys. Parse the arena bodies tagged nav_source instead.
	nm.geometry_source_geometry_mode = NavigationMesh.SOURCE_GEOMETRY_GROUPS_WITH_CHILDREN
	nm.geometry_source_group_name = "nav_source"
	nm.agent_radius = 0.45
	nm.agent_height = 1.8
	nm.agent_max_climb = 0.3
	region.navigation_mesh = nm
	add_child(region)
	region.bake_navigation_mesh(false)  # sync at boot - the arena is small
	print("[GORE LAB] navmesh baked: %d polys" % region.navigation_mesh.get_polygon_count())


func _spawn_player() -> void:
	var scene: PackedScene = load("res://scenes/player/player.tscn")
	player = scene.instantiate() as CharacterBody3D
	add_child(player)
	# behind the big hard block at (-9, 2): 3m of cover, step out to engage
	player.global_position = Vector3(-9.0, 1.0, 4.5)
	GameManager.player = player

	var hud: HUD = load("res://scenes/ui/hud.tscn").instantiate() as HUD
	add_child(hud)
	var health_system: HealthSystem = player.get_node("HealthSystem")
	var weapon_holder: WeaponHolder = player.get_node("Head/Camera3D/WeaponHolder")
	var equipment_manager: EquipmentManager = player.get_node("EquipmentManager")
	var grenade_handler: GrenadeHandler = player.get_node("Head/Camera3D/GrenadeHandler")
	hud.setup(health_system, weapon_holder, equipment_manager, grenade_handler)

	equipment_manager.add_grenade(LAB_GRENADES - equipment_manager.get_grenade_count())

	var shotty: WeaponData = load("res://data/weapons/shotgun.tres")
	if shotty != null:
		weapon_holder.secondary_weapon = shotty
		weapon_holder.secondary_ammo = [shotty.magazine_size, 8]


## Cover heights: 0.5 prone / 1.0 crouch / 1.5 standing chest / 2.5 full LOS block.
var _cover_spots: Array[Vector3] = []


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
		# Min spacing: overlapping rotated boxes make wedge pockets that pin capsules.
		var crowded: bool = false
		for existing in _cover_spots:
			if Vector2(pos.x - existing.x, pos.z - existing.z).length() < 3.5:
				crowded = true
				break
		if crowded:
			continue
		var b := _cover_box(Vector3(w, hgt, d), pos, tints[idx])
		b.rotation.y = float(_rng.randi() % 4) * PI * 0.5  # axis-aligned: no wedge corners
		_cover_spots.append(pos)
	# two hard blocks for real LOS breaks
	_cover_box(Vector3(6.0, 3.0, 1.0), Vector3(-9.0, 1.5, 2.0), tints[3])
	_cover_box(Vector3(1.0, 3.0, 6.0), Vector3(8.0, 1.5, -6.0), tints[3])
	_cover_spots.append(Vector3(8.0, 0.0, -6.0))


func _cover_box(size: Vector3, pos: Vector3, color: Color) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.add_to_group("nav_source")
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


## Allies fight with no SquadSystem: targeting rides AgentRegistry.enemies,
## FOLLOW rides GameManager.player.
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
			a.fire_rate_mult = 1.6  # the pig's rate
		_allies.append(a)


func _alive_allies() -> int:
	var n: int = 0
	for a in _allies:
		if is_instance_valid(a) and not a.is_dead():
			n += 1
	return n


func _spawn_wave() -> void:
	_wave += 1
	_wave_pending = false
	# Wave 1 spawns RELAXED (the sneaking bench); reinforcement waves arrive ALERT
	# with a rough fix on the battle. Entries staggered, and cover-adjacent (~3m of
	# a cover piece on the north half) so nobody materializes in the wide open.
	var north_cover: Array[Vector3] = []
	for c in _cover_spots:
		if c.z < -4.0:
			north_cover.append(c)
	var idx: int = 0
	for data_path in WAVE:
		var pos := Vector3(_rng.randf_range(-16.0, 16.0), 1.0, _rng.randf_range(-19.0, -12.0))
		if not north_cover.is_empty():
			var spot: Vector3 = north_cover[_rng.randi() % north_cover.size()]
			pos = spot + Vector3(_rng.randf_range(-3.0, 3.0), 1.0, _rng.randf_range(-3.0, -0.5))
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
	_zone_im = ImmediateMesh.new()
	var zm := MeshInstance3D.new()
	zm.mesh = _zone_im
	zm.material_override = m
	add_child(zm)


## H toggles hitzone wireframes (must not collide with a bound gameplay key).
var _zone_im: ImmediateMesh = null
var _zones_visible: bool = false

func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo and key.keycode == KEY_H:
		_zones_visible = not _zones_visible


func _update_zone_vis() -> void:
	if _zone_im == null:
		return
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
		var exp_t: float = clampf(e.target_visible_duration / maxf(e.d_exposure_ramp, 0.1), 0.0, 1.0)
		lbl.text = "%s | %s\n%s  tgt:%s%s\ncov:%s sup:%.1f exp:%.2f" % [
			EnemyBase.AlertTier.keys()[tier], state_name, goal_name,
			_name_of(e.target), " (LOS)" if e.has_line_of_sight else "",
			"Y" if e.has_cover else "n", e.suppression_level, exp_t]
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
		lbl.text = "ALLY c%.1f s%.1f | %s\n%s  tgt:%s%s  cov:%s wf:%s" % [
			a.courage, a.skill, state_name, order_name, _name_of(a.target),
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
	_update_zone_vis()
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
	var squad_str: String = "" if ALLY_COUNT == 0 else " | squad: %d/%d" % [_alive_allies(), ALLY_COUNT]
	_hud.text = "COMBAT BENCH - wave %d | enemies: %d%s
frag [3] | medkit [4] + hold [F] | AI labels: state | goal | target | H hitzones" % [
		_wave, _alive_enemies(), squad_str]
