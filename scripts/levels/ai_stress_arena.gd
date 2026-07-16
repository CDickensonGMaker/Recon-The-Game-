## ai_stress_arena.gd - Combat AI Stress Test Arena
## A 120m sandbox where US and VC/NVA squads fight autonomously. Built on the
## same primitives as Gore Lab, but scoped for sustained squad-vs-squad battles
## and honest telemetry. Visual quality is secondary to tactical readability.
class_name AIStressArena
extends Node3D

## Minimal TerrainManager stand-in for the arena. DamageSystem is an autoload and
## expects a terrain_manager when explosions try to deform terrain; the arena has no
## heightmap, so this stub absorbs the calls without warning.
class TerrainManagerStub extends Node:
	var cell_size: float = 1.0
	var chunk_size: float = 32.0
	var heightmap = null

	func get_height_at(_world_pos: Vector3) -> float:
		return 0.0

	func modify_terrain(_world_pos: Vector3, _radius_meters: float, _crater_func: Callable) -> void:
		pass


const ARENA: float = 120.0
const WALL_H: float = 4.0
const LAB_GRENADES: int = 25

## Squad structure for the arena. Names are MOS strings that map through
## SquadSystem helpers to weapons and bodies.
const US_SQUAD_MOS: Array[String] = [
	"POINTMAN", "RTO", "MEDIC", "RIFLEMAN", "GRENADIER", "MG",
]

## US body pool for arena grunts. us_grunt_v3 is the only clean single-body export;
## the role-specific exports carry a second skinned body and must not be added until
## that is exported out of them.
const ARENA_US_BODIES: Array[String] = ["us_grunt_v3"]

## VC/NVA enemy data resources. Each squad gets a mix.
const VC_PATHS: Array[String] = [
	"res://data/enemies/vc_rifleman.tres",
	"res://data/enemies/vc_rifleman.tres",
	"res://data/enemies/vc_sapper.tres",
	"res://data/enemies/nva_regular.tres",
	"res://data/enemies/nva_rpg.tres",
	"res://data/enemies/vc_rifleman.tres",
]

## Force configuration. Defaults give an 18v18 start with reserves for a 3-5m fight.
@export var us_squads_active: int = 3
@export var vc_squads_active: int = 3
@export var men_per_squad: int = 6
@export var us_reserve_squads: int = 2
@export var vc_reserve_squads: int = 2
@export var round_max_seconds: float = 300.0  ## 5 minute hard cap
@export var spawn_player: bool = true
@export var spawn_hud: bool = true
## If true, every agent is seeded with a nearest-enemy target and pushed into COMBAT
## on spawn. Used by headless probes and quick sanity checks; the normal scene lets
## forces move-to-contact for an emergent start.
@export var hot_start: bool = false

## --- TUNING LEVERS (arena-local, do not leak into campaign) ---
## AI health scaling. Controls how long AI-vs-AI fights last.
@export var ai_hp_multiplier: float = 1.5
## Multiplier on damage dealt by the player only. Keeps player gunfeel separate
## from AI-vs-AI durability.
@export var player_damage_multiplier: float = 1.0
## Scales reinforcement cadence. Higher = reserves arrive faster.
@export var reserve_rate_multiplier: float = 1.0
## THE firefight-length dial (C2). Pushed into GameSettings.ai_vs_ai_cone_mult on _ready. 1.0 = fair,
## lethal baseline; 2.5-3.0 = Star Wars troopers, long firefights. AI-vs-player is never affected.
@export var ai_vs_ai_cone_mult: float = 1.0
## Fraction of max HP at which all arena VC/NVA switch to wounded retreat.
@export var ai_retreat_hp: float = 0.35
## Symmetry-probe mode: forces identical weapon/HP/accuracy on both sides and strips the enemy-only
## retreat + self-preservation bias, so the mirror-match probe measures the fire model, nothing else.
@export var mirror_mode: bool = false
## Spawn-jitter seed. Probes vary it per round; combat spread itself draws from the global stream.
@export var rng_seed: int = 20260714
## The weapon both sides share in mirror_mode. A TIGHT rifle (sub-cap cone) so any off-center aim
## bias shows up instead of hiding under the 1.2 deg cap - that makes the probe a real regression
## guard: reintroduce an enemy-only bias and the ratio breaks the band.
const MIRROR_WEAPON: String = "res://data/weapons/mosin.tres"
const MIRROR_HP: int = 80
const MIRROR_ACC: float = 0.7

var player: CharacterBody3D = null
var _rng := RandomNumberGenerator.new()
var _nav_region: NavigationRegion3D = null

## Live agents, grouped by squad index.
var _us_squads: Array[Array] = []   # Array[Array[AllyBase]]
var _vc_squads: Array[Array] = []   # Array[Array[EnemyBase]]

## Reserve counters and cooldowns.
var _us_reserves_left: int = 0
var _vc_reserves_left: int = 0
var _us_reinforce_cd: float = 0.0
var _vc_reinforce_cd: float = 0.0
const REINFORCE_INTERVAL_MIN: float = 25.0
const REINFORCE_INTERVAL_MAX: float = 40.0

## Telemetry
var _sim_time: float = 0.0
var _hud: Label = null
var _round_ended: bool = false
var _us_kills: int = 0
var _vc_kills: int = 0
var _state_history: Dictionary = {}

## 30s summary log state
var _last_telemetry_log: float = -999.0
var _us_rounds_fired: int = 0
var _vc_rounds_fired: int = 0
var _us_retreats: int = 0
var _vc_retreats: int = 0
var _us_suppressed_seconds: float = 0.0
var _vc_suppressed_seconds: float = 0.0

## Debug labels (reused pattern from Gore Lab)
var _dbg_labels: Dictionary = {}
var _dbg_mesh: MeshInstance3D = null
var _dbg_im: ImmediateMesh = null


func _ready() -> void:
	_rng.seed = rng_seed
	GibSystem.gib_lifetime_s = 25.0
	# The arena is the tuning lab for the one firefight-length dial (C2).
	GameSettings.ai_vs_ai_cone_mult = ai_vs_ai_cone_mult

	# Plug a terrain stub into the autoload so grenades don't spam warnings.
	var terrain_stub := TerrainManagerStub.new()
	terrain_stub.name = "ArenaTerrainStub"
	DamageSystem.add_child(terrain_stub)
	DamageSystem.set_terrain_manager(terrain_stub)

	_build_environment()
	_bake_navmesh()

	# The navigation server needs at least one physics frame to register the
	# baked region before agents can resolve paths on it. Give it two frames so
	# the map RID is valid and the mesh is merged.
	await get_tree().physics_frame
	await get_tree().physics_frame

	_spawn_player()
	_spawn_initial_forces()
	if hot_start:
		_hot_start_combat()
	# Scale HP and wire kill counting after all agents have finished _ready().
	call_deferred("_finish_agent_setup")
	_build_hud()
	_build_debug_vis()
	_wire_telemetry()

	print("[AI STRESS ARENA] ready - %d US squads + %d reserves vs %d VC squads + %d reserves" % [
		us_squads_active, us_reserve_squads, vc_squads_active, vc_reserve_squads])


func _process(delta: float) -> void:
	if _round_ended:
		return
	_sim_time += delta

	_update_reinforcements(delta)
	_update_telemetry(delta)
	_update_debug_vis()
	_check_round_end()


## ---------- ENVIRONMENT ----------

func _build_environment() -> void:
	_build_floor()
	_build_walls()
	_build_firebase()
	_build_village()
	_build_central_ridge()
	_build_tree_lines()
	_build_wrecked_cover()
	_build_cover_clusters()
	_plant_vegetation()


func _build_floor() -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.add_to_group("nav_source")
	var mi := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(ARENA, ARENA)
	mi.mesh = plane
	var sm := ShaderMaterial.new()
	sm.shader = load("res://terrain/shaders/lab_grid.gdshader")
	mi.material_override = sm
	body.add_child(mi)
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(ARENA, 0.2, ARENA)
	cs.shape = box
	cs.position.y = -0.1
	body.add_child(cs)
	add_child(body)


func _build_walls() -> void:
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


func _build_firebase() -> void:
	# SW corner perimeter: sandbag wall segments.
	var origin := Vector3(-45.0, 0.0, 45.0)
	var segments: Array[Vector3] = [
		Vector3(-30, 0, 0), Vector3(-15, 0, 0), Vector3(0, 0, 0), Vector3(15, 0, 0),
		Vector3(0, 0, -15), Vector3(0, 0, -30),
	]
	for offset in segments:
		var pos := origin + offset
		pos.y = 0.6
		_sandbag_wall(Vector3(4.0, 1.2, 1.0), pos)

	# Two fighting holes near the wall.
	_fighting_hole(origin + Vector3(-20, 0, -20))
	_fighting_hole(origin + Vector3(10, 0, -20))

	# A simple resupply/landing zone platform.
	_platform(origin + Vector3(-5, 0, -45), Vector3(12, 0.2, 8))


func _build_village() -> void:
	var origin := Vector3(35.0, 0.0, -35.0)
	# 4 simple buildings.
	for i in range(4):
		var x := float(i % 2) * 18.0
		var z := float(i / 2) * 18.0
		var pos := origin + Vector3(x, 0.0, z)
		_building(pos, Vector3(_rng.randf_range(5.0, 8.0), 3.2, _rng.randf_range(5.0, 8.0)))

	# Paths and sandbag positions around the village.
	for offset in [Vector3(-10, 0, -10), Vector3(25, 0, -10), Vector3(-10, 0, 25), Vector3(25, 0, 25)]:
		_sandbag_wall(Vector3(3.0, 1.0, 0.8), origin + offset + Vector3(0, 0.5, 0))


func _build_central_ridge() -> void:
	# A low winding berm across the middle of the arena. It is partial cover:
	# crouched men hide, standing men can see/shoot over it. Gaps force flanking
	# and prove the navigation/LOS systems can route around obstacles.
	var ridge_z: float = 0.0
	var segments: Array[Dictionary] = [
		{"x0": -55.0, "x1": -14.0, "z": 0.0},
		{"x0":  -4.0, "x1":   4.0, "z": 0.0},
		{"x0":  14.0, "x1":  55.0, "z": 0.0},
	]
	for seg in segments:
		var length: float = float(seg["x1"]) - float(seg["x0"])
		var mid: float = (float(seg["x0"]) + float(seg["x1"])) * 0.5
		# Meander the Z so it is not a straight shooting gallery.
		var z_off: float = _rng.randf_range(-2.0, 2.0)
		_berm_segment(Vector3(mid, 0.0, float(seg["z"]) + z_off), Vector3(length, 1.3, 3.5))

	# Two short cross-berms to create corner cover and break up diagonal fire lanes.
	_berm_segment(Vector3(-20.0, 0.0, -12.0), Vector3(10.0, 1.0, 2.5), 0.4)
	_berm_segment(Vector3(20.0, 0.0, 12.0), Vector3(10.0, 1.0, 2.5), -0.4)


func _build_tree_lines() -> void:
	# North and south tree lines with gaps. They provide concealment and force
	# fire teams to use the cleared flanks or push through intermittent cover.
	for side in [-1, 1]:
		var z_base: float = float(side) * 50.0
		for i in range(7):
			var x: float = -45.0 + float(i) * 15.0
			if i == 3:
				continue  # deliberate lane through the tree line
			_tree_clump(Vector3(x + _rng.randf_range(-3.0, 3.0), 0.0, z_base + _rng.randf_range(-5.0, 5.0)))

	# Elephant-grass strips along the flanks for hiding/low movement.
	_elephant_grass_strip(Rect2(-55, -52, 110, 6))
	_elephant_grass_strip(Rect2(-55, 46, 110, 6))


func _build_wrecked_cover() -> void:
	# Central contact zone: broken walls and fallen logs that create short-range
	# fire-and-maneuver positions without turning the fight into a flat shootout.
	for offset in [Vector3(-8, 0, -8), Vector3(8, 0, 8), Vector3(-8, 0, 8), Vector3(8, 0, -8)]:
		_fallen_log(offset + Vector3(_rng.randf_range(-2.0, 2.0), 0.0, _rng.randf_range(-2.0, 2.0)), _rng.randf_range(0.0, TAU))
		_wrecked_wall(offset + Vector3(_rng.randf_range(-3.0, 3.0), 0.0, _rng.randf_range(-3.0, 3.0)), _rng.randf_range(0.0, TAU))

	# Bamboo clusters around the ridge gaps for close-concealment approaches.
	for pos in [Vector3(-10, 0, 0), Vector3(10, 0, 0)]:
		_bamboo_clump(pos + Vector3(_rng.randf_range(-2.0, 2.0), 0.0, _rng.randf_range(-2.0, 2.0)))


func _build_cover_clusters() -> void:
	# Scatter rocks and small sandbags along the flanks and firebase/village
	# approaches. Keep the central ridge and contact zone clear for wrecked cover.
	for i in range(18):
		var pos := Vector3(_rng.randf_range(-55.0, 55.0), 0.0, _rng.randf_range(-55.0, 55.0))
		if absf(pos.x) < 12.0 and absf(pos.z) < 12.0:
			continue  # leave the central ridge/contact zone to wrecked cover
		if pos.distance_to(Vector3(-45.0, 0.0, 45.0)) < 12.0:
			continue  # firebase LZ
		if pos.distance_to(Vector3(35.0, 0.0, -35.0)) < 14.0:
			continue  # village
		var h: float = _rng.randf_range(0.6, 1.6)
		var w: float = _rng.randf_range(1.2, 3.0)
		var d: float = _rng.randf_range(1.2, 3.0)
		var rock := StaticBody3D.new()
		rock.collision_layer = 1
		rock.collision_mask = 0
		rock.add_to_group("nav_source")
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(w, h, d)
		mi.mesh = bm
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.45, 0.42, 0.38)
		mi.material_override = mat
		rock.add_child(mi)
		var cs := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = Vector3(w, h, d)
		cs.shape = shape
		rock.add_child(cs)
		add_child(rock)
		rock.global_position = pos + Vector3(0, h * 0.5, 0)


func _berm_segment(center: Vector3, size: Vector3, twist: float = 0.0) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.add_to_group("nav_source")
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.42, 0.40, 0.35)
	mi.material_override = mat
	body.add_child(mi)
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	body.add_child(cs)
	add_child(body)
	body.global_position = center + Vector3(0, size.y * 0.5, 0)
	body.rotation.y = twist


func _tree_clump(pos: Vector3) -> void:
	var variants: Array[String] = ["jungle_palm_b1", "jungle_palm_b2", "broadleaf_a", "broadleaf_b", "broadleaf_c"]
	var variant: String = variants[_rng.randi_range(0, variants.size() - 1)]
	var path: String = "res://assets/world/vegetation/" + variant + ".glb"
	if not ResourceLoader.exists(path):
		return
	var packed: PackedScene = load(path)
	var tree := packed.instantiate() as Node3D
	if tree == null:
		return
	add_child(tree)
	tree.global_position = pos
	tree.rotation.y = _rng.randf_range(0.0, TAU)
	tree.scale = Vector3.ONE * _rng.randf_range(0.85, 1.25)
	_add_trunk_collider(tree)


func _fallen_log(pos: Vector3, rot: float) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.add_to_group("nav_source")
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.height = _rng.randf_range(3.0, 5.0)
	cm.top_radius = 0.45
	cm.bottom_radius = 0.45
	mi.mesh = cm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.35, 0.30, 0.25)
	mi.material_override = mat
	body.add_child(mi)
	var cs := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.height = cm.height
	cyl.radius = cm.top_radius
	cs.shape = cyl
	body.add_child(cs)
	add_child(body)
	body.global_position = pos + Vector3(0, cm.top_radius, 0)
	body.rotation.z = PI * 0.5
	body.rotation.y = rot


func _wrecked_wall(pos: Vector3, rot: float) -> void:
	_sandbag_wall(Vector3(_rng.randf_range(2.0, 4.0), _rng.randf_range(0.8, 1.4), 0.7), pos)
	var body: Node = get_child(get_child_count() - 1)
	if body != null:
		body.rotation.y = rot


func _bamboo_clump(pos: Vector3) -> void:
	var variants: Array[String] = ["bamboo_a", "bamboo_b", "bamboo_c"]
	for i in range(4):
		var variant: String = variants[i % variants.size()]
		var path: String = "res://assets/world/vegetation/" + variant + ".glb"
		if not ResourceLoader.exists(path):
			continue
		var packed: PackedScene = load(path)
		var shoot := packed.instantiate() as Node3D
		if shoot == null:
			continue
		add_child(shoot)
		shoot.global_position = pos + Vector3(_rng.randf_range(-1.5, 1.5), 0.0, _rng.randf_range(-1.5, 1.5))
		shoot.rotation.y = _rng.randf_range(0.0, TAU)
		shoot.scale = Vector3.ONE * _rng.randf_range(0.9, 1.3)
		_add_trunk_collider(shoot)


func _elephant_grass_strip(rect: Rect2) -> void:
	var mesh: Mesh = GroundClutter.load_glb_mesh("res://assets/world/vegetation/elephant_grass_a.glb")
	if mesh == null:
		return
	_varray_multimesh(mesh, rect, 80, Color(0.45, 0.55, 0.25))


func _sandbag_wall(size: Vector3, pos: Vector3) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.add_to_group("nav_source")
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.55, 0.50, 0.40)
	mi.material_override = mat
	body.add_child(mi)
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	body.add_child(cs)
	add_child(body)
	body.global_position = pos


func _fighting_hole(pos: Vector3) -> void:
	# L-shaped dirt parapet.
	for offset in [Vector3(-1.5, 0.4, 0), Vector3(1.5, 0.4, 0), Vector3(0, 0.4, -1.5)]:
		_sandbag_wall(Vector3(1.0, 0.8, 0.6), pos + offset + Vector3(0, 0.4, 0))


func _platform(pos: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.add_to_group("nav_source")
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.35, 0.38, 0.32)
	mi.material_override = mat
	body.add_child(mi)
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	body.add_child(cs)
	add_child(body)
	body.global_position = pos + Vector3(0, size.y * 0.5, 0)


func _building(pos: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.add_to_group("nav_source")
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.62, 0.55, 0.45)
	mi.material_override = mat
	body.add_child(mi)
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	body.add_child(cs)
	add_child(body)
	body.global_position = pos + Vector3(0, size.y * 0.5, 0)


func _plant_vegetation() -> void:
	# Rice patches in SE/NW fields.
	var rice_dir := "res://assets/world/vegetation/"
	for patch in ["rice_a", "rice_b"]:
		var mesh: Mesh = GroundClutter.load_glb_mesh(rice_dir + patch + ".glb")
		if mesh == null:
			continue
		for rect in [Rect2(-55, -55, 25, 25), Rect2(30, 30, 25, 25)]:
			_varray_multimesh(mesh, rect, 40, Color(0.55, 0.65, 0.35))

	# Palm clusters at firebase and village edges.
	var palm_variants: Array[String] = ["jungle_palm_a1", "jungle_palm_a2", "jungle_palm_a3"]
	for base in [Vector3(-45, 0, 45), Vector3(35, 0, -35)]:
		for i in range(6):
			var variant: String = palm_variants[i % palm_variants.size()]
			if not ResourceLoader.exists("res://assets/world/vegetation/" + variant + ".glb"):
				continue
			var packed: PackedScene = load("res://assets/world/vegetation/" + variant + ".glb")
			var palm := packed.instantiate() as Node3D
			if palm == null:
				continue
			add_child(palm)
			palm.global_position = base + Vector3(_rng.randf_range(-10, 10), 0, _rng.randf_range(-10, 10))
			palm.rotation.y = _rng.randf_range(0.0, TAU)
			_add_trunk_collider(palm)


func _varray_multimesh(mesh: Mesh, rect: Rect2, count: int, tint: Color) -> void:
	var mmi := MultiMeshInstance3D.new()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.instance_count = count
	mm.mesh = mesh
	mmi.multimesh = mm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = tint
	mmi.material_override = mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)
	for i in range(count):
		var pos := Vector3(
			_rng.randf_range(rect.position.x, rect.position.x + rect.size.x),
			0.0,
			_rng.randf_range(rect.position.y, rect.position.y + rect.size.y))
		var basis := Basis(Vector3.UP, _rng.randf_range(0.0, TAU))
		var s: float = _rng.randf_range(0.9, 1.4)
		basis = basis.scaled(Vector3(s, s, s))
		mm.set_instance_transform(i, Transform3D(basis, pos))


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


func _bake_navmesh() -> void:
	var region := NavigationRegion3D.new()
	_nav_region = region
	region.add_to_group("lab_navmesh")
	var nm := NavigationMesh.new()
	nm.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nm.geometry_source_geometry_mode = NavigationMesh.SOURCE_GEOMETRY_GROUPS_WITH_CHILDREN
	nm.geometry_source_group_name = "nav_source"
	nm.agent_radius = 0.45
	nm.agent_height = 1.8
	nm.agent_max_climb = 0.3
	region.navigation_mesh = nm
	add_child(region)
	region.bake_navigation_mesh(false)
	print("[AI STRESS ARENA] navmesh baked: %d polys" % region.navigation_mesh.get_polygon_count())


## ---------- FORCES ----------

func _spawn_player() -> void:
	if not spawn_player:
		return
	var scene: PackedScene = load("res://scenes/player/player.tscn")
	player = scene.instantiate() as CharacterBody3D
	add_child(player)
	player.global_position = Vector3(-35.0, 1.0, 35.0)  # firebase overlook
	GameManager.player = player

	if not spawn_hud:
		return
	var hud: HUD = load("res://scenes/ui/hud.tscn").instantiate() as HUD
	add_child(hud)
	var health_system: HealthSystem = player.get_node("HealthSystem")
	var weapon_holder: WeaponHolder = player.get_node("Head/Camera3D/WeaponHolder")
	var equipment_manager: EquipmentManager = player.get_node("EquipmentManager")
	var grenade_handler: GrenadeHandler = player.get_node("Head/Camera3D/GrenadeHandler")
	hud.setup(health_system, weapon_holder, equipment_manager, grenade_handler)

	equipment_manager.add_grenade(LAB_GRENADES - equipment_manager.get_grenade_count())


func _spawn_initial_forces() -> void:
	_us_reserves_left = us_reserve_squads
	_vc_reserves_left = vc_reserve_squads
	_us_reinforce_cd = 0.0
	_vc_reinforce_cd = 0.0

	# US squads around firebase, mostly holding or moving to forward positions.
	var us_bases: Array[Vector3] = [
		Vector3(-40, 1.0, 40), Vector3(-25, 1.0, 25), Vector3(-40, 1.0, 20),
	]
	for i in range(us_squads_active):
		var center: Vector3 = us_bases[i % us_bases.size()] + Vector3(_rng.randf_range(-4, 4), 0, _rng.randf_range(-4, 4))
		var order := AllyBase.OrderMode.HOLD if i == 0 else AllyBase.OrderMode.MOVE_TO
		var order_pos := center if order == AllyBase.OrderMode.HOLD else Vector3(-20.0 + float(i) * 8.0, 1.0, 10.0)
		_spawn_us_squad(center, order, order_pos)

	# VC squads at village / north tree line, facing the firebase.
	var vc_bases: Array[Vector3] = [
		Vector3(35, 1.0, -35), Vector3(45, 1.0, -25), Vector3(25, 1.0, -45),
	]
	for i in range(vc_squads_active):
		var center: Vector3 = vc_bases[i % vc_bases.size()] + Vector3(_rng.randf_range(-5, 5), 0, _rng.randf_range(-5, 5))
		_spawn_vc_squad(center, i)


func _spawn_us_squad(center: Vector3, order: AllyBase.OrderMode, order_pos: Vector3) -> void:
	var squad: Array[AllyBase] = []
	var rng := RandomNumberGenerator.new()
	rng.seed = _rng.seed + _us_squads.size() * 97
	for i in range(men_per_squad):
		var mos: String = US_SQUAD_MOS[i % US_SQUAD_MOS.size()]
		var offset := Vector3(cos(float(i) * TAU / 6.0) * 3.0, 0.0, sin(float(i) * TAU / 6.0) * 3.0)
		var pos := center + offset
		var ally := AllyBase.spawn_ally(self, pos)
		if ally == null:
			continue
		var body: String = ARENA_US_BODIES[rng.randi_range(0, ARENA_US_BODIES.size() - 1)]
		ally.set_sprite(body, SquadSystem.weapon_for_mos(mos), "US")
		ally.set_order(order, order_pos)
		if mos == "MG":
			ally.fire_rate_mult = 1.6
		squad.append(ally)
	_us_squads.append(squad)


func _spawn_vc_squad(center: Vector3, squad_idx: int) -> void:
	var squad: Array[EnemyBase] = []
	var squad_id: int = 1000 + squad_idx
	for i in range(men_per_squad):
		var dp: String = VC_PATHS[i % VC_PATHS.size()]
		var offset := Vector3(cos(float(i) * TAU / 6.0) * 4.0, 0.0, sin(float(i) * TAU / 6.0) * 4.0)
		var pos := center + offset
		var enemy := EnemyBase.spawn_enemy(self, pos, dp)
		if enemy == null:
			continue
		enemy.squad_id = squad_id
		enemy.alert_tier = EnemyBase.AlertTier.ALERT  # they know a fight is coming
		# Seed VC with a last-known point in the central contact zone so they move
		# toward the US advance even when no player is present.
		enemy.last_known_target_pos = Vector3(-10.0 + float(squad_idx % maxi(1, us_squads_active)) * 8.0, 0.0, 5.0)
		enemy.target_last_seen_time = 0.0
		# Rough facing toward firebase.
		enemy.rotation.y = atan2(35.0 - pos.z, -35.0 - pos.x)
		# Bind the agent to the arena's baked nav map explicitly. Without this,
		# runtime-spawned agents sometimes fail to resolve a map until a frame later.
		var nav_agent := enemy.get_node_or_null("NavigationAgent3D") as NavigationAgent3D
		if nav_agent != null and _nav_region != null:
			nav_agent.set_navigation_map(_nav_region.get_navigation_map())
		squad.append(enemy)
	_vc_squads.append(squad)


func _hot_start_combat() -> void:
	# Seed every agent with a nearest-hostile target and push both sides into COMBAT.
	# This bypasses the normal perception cold-start so headless probes can observe
	# squad behavior without a player present.
	for squad in _us_squads:
		for a in squad:
			if not is_instance_valid(a) or a.is_dead():
				continue
			var nearest := _nearest_vc(a.global_position)
			if nearest != null:
				a.target = nearest
				a.last_known_target_pos = nearest.global_position
				a.contact_conf = 1.0
				a.target_last_seen_time = 0.0
				a._change_state(Enums.AIState.COMBAT)

	for squad in _vc_squads:
		for e in squad:
			if not is_instance_valid(e) or e.is_dead():
				continue
			var nearest := _nearest_us(e.global_position)
			if nearest != null:
				e.alert_tier = EnemyBase.AlertTier.COMBAT
				e.last_known_target_pos = nearest.global_position
				e._set_tier(EnemyBase.AlertTier.COMBAT, false)


func _finish_agent_setup() -> void:
	# HP scaling, kill-count wiring, and arena tuning must run after each agent's
	# _ready() has set its base max_hp, so we defer it from _ready() and from
	# reinforcement spawns.
	for squad in _us_squads:
		for a in squad:
			if not is_instance_valid(a):
				continue
			var target_max: int = int(a.max_hp * ai_hp_multiplier)
			if a.max_hp != target_max:
				a.max_hp = target_max
				a.current_hp = target_max
			if mirror_mode:
				a.max_hp = MIRROR_HP
				a.current_hp = MIRROR_HP
				a.weapon_data = load(MIRROR_WEAPON) as WeaponData
				a.skill = MIRROR_ACC
			if not a.died.is_connected(_on_us_died):
				a.died.connect(_on_us_died)

	for squad in _vc_squads:
		for e in squad:
			if not is_instance_valid(e):
				continue
			var target_max: int = int(e.max_hp * ai_hp_multiplier)
			if e.max_hp != target_max:
				e.max_hp = target_max
				e.current_hp = target_max
			if mirror_mode:
				# Force perfect symmetry: same gun, HP, accuracy; strip the enemy-only retreat +
				# self-preservation bias so the probe reads the fire model and nothing else.
				e.max_hp = MIRROR_HP
				e.current_hp = MIRROR_HP
				e.weapon_data = load(MIRROR_WEAPON) as WeaponData
				e.char_accuracy = MIRROR_ACC
				e.d_retreats_when_hurt = false
			else:
				# Force break-contact under pressure for every arena VC/NVA.
				e.d_retreats_when_hurt = true
				e.d_retreat_hp = ai_retreat_hp
				# Slightly stiffen self-preservation so suppression drives cover/withdrawal.
				e.char_self_preservation = clampf(e.char_self_preservation + 0.12, 0.0, 0.9)
			if not e.died.is_connected(_on_vc_died):
				e.died.connect(_on_vc_died)


func _on_us_died(_ally: AllyBase) -> void:
	_vc_kills += 1


func _on_vc_died(_enemy: EnemyBase) -> void:
	_us_kills += 1


func _nearest_vc(from: Vector3) -> Node3D:
	var best: Node3D = null
	var best_d: float = 99999.0
	for squad in _vc_squads:
		for e in squad:
			if not is_instance_valid(e) or e.is_dead():
				continue
			var d := from.distance_squared_to(e.global_position)
			if d < best_d:
				best_d = d
				best = e as Node3D
	return best


func _nearest_us(from: Vector3) -> Node3D:
	var best: Node3D = null
	var best_d: float = 99999.0
	for squad in _us_squads:
		for a in squad:
			if not is_instance_valid(a) or a.is_dead():
				continue
			var d := from.distance_squared_to(a.global_position)
			if d < best_d:
				best_d = d
				best = a as Node3D
	return best


func _update_reinforcements(delta: float) -> void:
	var spawned: bool = false
	var interval_min: float = REINFORCE_INTERVAL_MIN / maxf(0.1, reserve_rate_multiplier)
	var interval_max: float = REINFORCE_INTERVAL_MAX / maxf(0.1, reserve_rate_multiplier)
	if _us_reserves_left > 0:
		_us_reinforce_cd -= delta
		if _us_reinforce_cd <= 0.0 and _living_us() < us_squads_active * men_per_squad * 0.5:
			_us_reserves_left -= 1
			_us_reinforce_cd = _rng.randf_range(interval_min, interval_max)
			var center := Vector3(-45.0 + _rng.randf_range(-6, 6), 1.0, 45.0 + _rng.randf_range(-6, 6))
			_spawn_us_squad(center, AllyBase.OrderMode.MOVE_TO, Vector3(0.0, 1.0, 0.0))
			spawned = true
			print("[AI STRESS ARENA] US reinforcements arrived (%d reserves left)" % _us_reserves_left)

	if _vc_reserves_left > 0:
		_vc_reinforce_cd -= delta
		if _vc_reinforce_cd <= 0.0 and _living_vc() < vc_squads_active * men_per_squad * 0.5:
			_vc_reserves_left -= 1
			_vc_reinforce_cd = _rng.randf_range(interval_min, interval_max)
			var center := Vector3(45.0 + _rng.randf_range(-6, 6), 1.0, -45.0 + _rng.randf_range(-6, 6))
			_spawn_vc_squad(center, 2000 + _vc_squads.size())
			spawned = true
			print("[AI STRESS ARENA] VC reinforcements arrived (%d reserves left)" % _vc_reserves_left)

	if spawned:
		call_deferred("_finish_agent_setup")


func _living_us() -> int:
	var n: int = 0
	for squad in _us_squads:
		for a in squad:
			if is_instance_valid(a) and not a.is_dead():
				n += 1
	return n


func _living_vc() -> int:
	var n: int = 0
	for squad in _vc_squads:
		for e in squad:
			if is_instance_valid(e) and not e.is_dead():
				n += 1
	return n


func _total_us() -> int:
	return _us_squads.size() * men_per_squad


func _total_vc() -> int:
	return _vc_squads.size() * men_per_squad


## Arena-local accessor so bullet_system can scale player damage without
## hard-coding the arena reference. Safe to call from any scene; returns 1.0
## if no arena is active.
func get_player_damage_mult() -> float:
	return player_damage_multiplier


## ---------- ROUND LIFECYCLE ----------

func _check_round_end() -> void:
	if _sim_time >= round_max_seconds:
		_end_round("TIME LIMIT (5:00)")
		return
	var us_alive: int = _living_us()
	var vc_alive: int = _living_vc()
	if us_alive == 0 and _us_reserves_left == 0:
		_end_round("VC WINS")
		return
	if vc_alive == 0 and _vc_reserves_left == 0:
		_end_round("US WINS")
		return


func _end_round(result: String) -> void:
	_round_ended = true
	print("[AI STRESS ARENA] ROUND END - %s at %.1fs | US kills: %d | VC kills: %d" % [
		result, _sim_time, _us_kills, _vc_kills])
	if _hud != null:
		_hud.text += "\nROUND END: %s (press R to restart)" % result
	_print_final_summary()


func _print_final_summary() -> void:
	var us_alive: int = _living_us()
	var vc_alive: int = _living_vc()
	print("[AI STRESS ARENA] FINAL | %s | duration %.1fs | US %d alive / %d killed | VC %d alive / %d killed | reserves US:%d VC:%d" % [
		"US WINS" if vc_alive == 0 else ("VC WINS" if us_alive == 0 else "TIME LIMIT"),
		_sim_time, us_alive, _us_kills, vc_alive, _vc_kills, _us_reserves_left, _vc_reserves_left])


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("reload") and _round_ended:
		_restart_round()


func _restart_round() -> void:
	# Clear living and dead agents.
	for squad in _us_squads:
		for a in squad:
			if is_instance_valid(a):
				a.queue_free()
	for squad in _vc_squads:
		for e in squad:
			if is_instance_valid(e):
				e.queue_free()
	_us_squads.clear()
	_vc_squads.clear()
	_dbg_labels.clear()
	_sim_time = 0.0
	_us_kills = 0
	_vc_kills = 0
	_last_telemetry_log = -999.0
	_us_rounds_fired = 0
	_vc_rounds_fired = 0
	_us_retreats = 0
	_vc_retreats = 0
	_us_suppressed_seconds = 0.0
	_vc_suppressed_seconds = 0.0
	_round_ended = false
	_spawn_initial_forces()


func _wire_telemetry() -> void:
	CombatManager.bullets.bullet_spawned.connect(_on_bullet_spawned)


func _on_bullet_spawned(shooter: Node, _weapon: WeaponData) -> void:
	if shooter == null or not is_instance_valid(shooter):
		return
	if shooter.is_in_group("allies"):
		_us_rounds_fired += 1
	elif shooter.is_in_group("enemies"):
		_vc_rounds_fired += 1
	elif shooter.is_in_group("player") or (shooter.get_parent() != null and shooter.get_parent().is_in_group("player")):
		# Player shots count toward US side for arena telemetry.
		_us_rounds_fired += 1


## ---------- TELEMETRY ----------

func _build_hud() -> void:
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


func _update_telemetry(delta: float) -> void:
	var us_alive: int = _living_us()
	var vc_alive: int = _living_vc()
	var m: int = int(_sim_time) / 60
	var s: int = int(_sim_time) % 60

	var us_states := _state_histogram(true)
	var vc_states := _state_histogram(false)

	var us_sup: float = _avg_suppression(true)
	var vc_sup: float = _avg_suppression(false)
	var us_dist: float = _avg_distance_to_target(true)
	var vc_dist: float = _avg_distance_to_target(false)

	_accum_suppression_time(delta, us_sup, vc_sup)
	_count_retreats()

	if _hud != null:
		_hud.text = "AI STRESS ARENA - %02d:%02d / %02d:%02d\nUS  alive: %d/%d | VC  alive: %d/%d\nUS  reserves: %d | VC reserves: %d\nUS  kills: %d | VC kills: %d\nUS  sup: %.2f | VC sup: %.2f\nUS  dist: %.1fm | VC dist: %.1fm\nUS  states: %s\nVC states: %s" % [
			m, s, int(round_max_seconds) / 60, int(round_max_seconds) % 60,
			us_alive, _total_us(), vc_alive, _total_vc(),
			_us_reserves_left, _vc_reserves_left,
			_us_kills, _vc_kills,
			us_sup, vc_sup,
			us_dist, vc_dist,
			str(us_states), str(vc_states)]

	# 30-second stdout summary for evidence-based tuning.
	if _sim_time - _last_telemetry_log >= 30.0:
		_last_telemetry_log = _sim_time
		print("[AI STRESS ARENA] t=%02d:%02d | US %d/%d (%d kills, %d rounds, %d retreats, %.1fs sup) | VC %d/%d (%d kills, %d rounds, %d retreats, %.1fs sup) | avg dist %.1fm" % [
			m, s,
			us_alive, _total_us(), _us_kills, _us_rounds_fired, _us_retreats, _us_suppressed_seconds,
			vc_alive, _total_vc(), _vc_kills, _vc_rounds_fired, _vc_retreats, _vc_suppressed_seconds,
			(us_dist + vc_dist) * 0.5])
		# Reset cumulative counters each print so deltas are per-bucket.
		_us_rounds_fired = 0
		_vc_rounds_fired = 0
		_us_retreats = 0
		_vc_retreats = 0
		_us_suppressed_seconds = 0.0
		_vc_suppressed_seconds = 0.0


func _accum_suppression_time(delta: float, us_sup: float, vc_sup: float) -> void:
	# Count seconds where average suppression is above the behavior threshold.
	if us_sup >= 0.5:
		_us_suppressed_seconds += delta
	if vc_sup >= 0.5:
		_vc_suppressed_seconds += delta


func _count_retreats() -> void:
	# Count agents currently in RETREAT state. This is a point-in-time sample,
	# reset each telemetry bucket.
	for squad in _us_squads:
		for agent in squad:
			if is_instance_valid(agent) and not agent.is_dead() and agent.current_goal == Enums.AIGoal.RETREAT:
				_us_retreats += 1
	for squad in _vc_squads:
		for agent in squad:
			if is_instance_valid(agent) and not agent.is_dead() and agent.current_goal == Enums.AIGoal.RETREAT:
				_vc_retreats += 1


func _state_histogram(us: bool) -> Dictionary:
	var hist: Dictionary = {}
	var squads := _us_squads if us else _vc_squads
	for squad in squads:
		for agent in squad:
			if not is_instance_valid(agent) or agent.is_dead():
				continue
			var s: String = Enums.AIState.keys()[int(agent.current_state)]
			hist[s] = int(hist.get(s, 0)) + 1
	return hist


func _avg_suppression(us: bool) -> float:
	var total: float = 0.0
	var count: int = 0
	var squads := _us_squads if us else _vc_squads
	for squad in squads:
		for agent in squad:
			if not is_instance_valid(agent) or agent.is_dead():
				continue
			total += agent.suppression_level
			count += 1
	return total / float(maxi(1, count))


func _avg_distance_to_target(us: bool) -> float:
	var total: float = 0.0
	var count: int = 0
	var squads := _us_squads if us else _vc_squads
	for squad in squads:
		for agent in squad:
			if not is_instance_valid(agent) or agent.is_dead():
				continue
			var t: Node3D = agent.target
			if t != null and is_instance_valid(t) and not t.is_dead():
				total += agent.global_position.distance_to(t.global_position)
				count += 1
	return total / float(maxi(1, count))


## ---------- DEBUG VISUALIZATION ----------

const TIER_COLORS: Array[Color] = [
	Color(0.5, 0.9, 0.5),   # RELAXED
	Color(0.95, 0.9, 0.4),  # SUSPICIOUS
	Color(1.0, 0.6, 0.2),   # ALERT
	Color(1.0, 0.25, 0.25), # COMBAT
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
	l.font_size = 24
	l.outline_size = 6
	l.position = Vector3(0, 2.3, 0)
	agent.add_child(l)
	_dbg_labels[key] = l
	return l


func _update_debug_vis() -> void:
	if _dbg_im == null:
		return
	_dbg_im.clear_surfaces()
	var lines: Array = []

	for squad in _vc_squads:
		for agent in squad:
			if not is_instance_valid(agent):
				continue
			var lbl := _dbg_label_for(agent)
			if agent.is_dead():
				lbl.text = "DEAD"
				lbl.modulate = Color(0.5, 0.5, 0.5, 0.5)
				continue
			var tier: int = clampi(int(agent.alert_tier), 0, 3)
			var state_name: String = Enums.AIState.keys()[int(agent.current_state)]
			var goal_name: String = Enums.AIGoal.keys()[int(agent.current_goal)]
			lbl.text = "%s\n%s | cov:%s sup:%.1f" % [state_name, goal_name, "Y" if agent.has_cover else "n", agent.suppression_level]
			lbl.modulate = TIER_COLORS[tier]
			if agent.target != null and is_instance_valid(agent.target):
				var from: Vector3 = agent.global_position + Vector3.UP * 1.5
				if agent.has_line_of_sight:
					lines.append([from, agent.target.global_position + Vector3.UP * 1.0, Color(1.0, 0.2, 0.2, 0.85)])
				elif agent.last_known_target_pos != Vector3.ZERO:
					lines.append([from, agent.last_known_target_pos + Vector3.UP * 1.0, Color(1.0, 0.6, 0.2, 0.35)])

	for squad in _us_squads:
		for agent in squad:
			if not is_instance_valid(agent):
				continue
			var lbl := _dbg_label_for(agent)
			if agent.is_dead():
				lbl.text = "KIA"
				lbl.modulate = Color(0.5, 0.5, 0.5, 0.5)
				continue
			var state_name: String = Enums.AIState.keys()[int(agent.current_state)]
			var order_name: String = AllyBase.OrderMode.keys()[int(agent.order_mode)]
			lbl.text = "%s\n%s | cov:%s sup:%.1f" % [state_name, order_name, "Y" if agent.has_cover else "n", agent.suppression_level]
			lbl.modulate = Color(0.45, 0.75, 1.0)
			if agent.target != null and is_instance_valid(agent.target) and agent.has_line_of_sight:
				lines.append([agent.global_position + Vector3.UP * 1.5,
					agent.target.global_position + Vector3.UP * 1.0, Color(0.3, 0.7, 1.0, 0.75)])

	if lines.is_empty():
		return
	_dbg_im.surface_begin(Mesh.PRIMITIVE_LINES)
	for ln in lines:
		_dbg_im.surface_set_color(ln[2])
		_dbg_im.surface_add_vertex(ln[0])
		_dbg_im.surface_set_color(ln[2])
		_dbg_im.surface_add_vertex(ln[1])
	_dbg_im.surface_end()
