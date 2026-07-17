## test_world_alive.gd - World-generation proof. No mission, no director, no
## spawner. Just the bare world: terrain, water, vegetation, paddy stamper.
## The test prints what the WORLD itself produced (paddy fields, village anchors,
## water bodies, rivers, creeks) and flies a free-drone camera around the AO for
## 60 real-time seconds so a human can verify it visually.
##
## Why no mission: we need to prove the world can generate all the proper items
## before piling a mission layer on top. Mission plan/build filters by objective
## kind, which masks the world's true output.
##
## VISUAL TEST MODE: this scene also exposes the whole AO at a glance —
## disables fog, hides billboard sprites so 3D trees show at all ranges,
## and renders a top-down minimap with markers for paddy fields, village
## anchors, water bodies, and the current drone position. These are
## TEST-ONLY visual aids; nothing here is wired into the main game.
##
## Run: godot --path . res://tests/test_world_alive.tscn
extends Node

const CivilianScript := preload("res://scripts/world/civilian.gd")
const EnemyBaseScript := preload("res://scripts/enemies/enemy_base.gd")
const PaddyStamperScript := preload("res://scripts/world/paddy_stamper.gd")
const LocationPlannerScript := preload("res://scripts/world/location_planner.gd")
const MissionDirectorScript := preload("res://scripts/missions/mission_director.gd")
const MissionGeneratorScript := preload("res://scripts/missions/mission_generator.gd")
# These mission preloads are kept available for diagnostic prints only;
# the test no longer drives a mission (intentional — see file header).

# Visual-test state. _apply_visual_test_setup() runs once after the world
# is built; the minimap is held here so _process can push live drone state.
var _minimap: Control = null
var _visual_test: bool = true

var elapsed: float = 0.0
var last_log: float = 0.0
var camera: Camera3D


func _ready() -> void:
	_run()


func _run() -> void:
	var world_scene: PackedScene = load("res://scenes/levels/game_world.tscn")
	var world: GameWorld = world_scene.instantiate()
	world.mission_seed = 7777
	world.spawn_player_on_ready = false
	add_child(world)
	var wait: float = 0.0
	while not world.is_world_ready and wait < 180.0:
		await get_tree().create_timer(0.5).timeout
		wait += 0.5
	if not world.is_world_ready:
		print("FAIL: world timeout")
		get_tree().quit(1)
		return

	# LOCATION-FIRST: pick firebase + villages + camps BEFORE anything else
	# gets queried. Then lift the heightmap around each location so the
	# ground beneath them is high and dry. Re-run the water system against
	# the lifted heightmap so creeks/lakes form AROUND the locations, not
	# under them.
	var map_size_for_planner: float = world.terrain_manager.map_size
	var locations: Array = LocationPlannerScript.plan_locations(7777, map_size_for_planner)
	print("=== LOCATION-FIRST PASS (seed=7777) ===")
	for loc in locations:
		var lp = loc as LocationPlannerScript.PlannedLocation
		var size_str: String = ""
		if lp.kind == "village":
			match lp.size:
				LocationPlannerScript.VillageSize.SMALL: size_str = " SMALL"
				LocationPlannerScript.VillageSize.MEDIUM: size_str = " MEDIUM"
				LocationPlannerScript.VillageSize.LARGE: size_str = " LARGE"
		print("  %s%s at (%.0f, %.0f)" % [lp.kind, size_str, lp.center.x, lp.center.z])
	LocationPlannerScript.apply_lifts(world.terrain_manager.heightmap, locations)
	# Re-run water system against lifted heightmap.
	var water_node: Node = world.get_node_or_null("WaterSystem")
	if water_node != null and water_node.has_method("generate_water_bodies"):
		water_node.generate_water_bodies()
	# Gameplay grid depends on the heightmap + water; rebuild it too so the
	# paddy stamper sees the lifted ground.
	if world.gameplay_grid != null and world.gameplay_grid.has_method("build_from_terrain"):
		world.gameplay_grid.build_from_terrain()

	# World-only generation proof. NO mission, NO director, NO build().
	# Run the paddy stamper directly against the world's terrain + grid so
	# paddy fields + village anchors materialize as nodes under `world`,
	# then read back what the world actually produced.
	var paddy_result: Dictionary = PaddyStamperScript.stamp(
		7777, world.gameplay_grid, world.terrain_manager, world
	)
	var paddies: Array = paddy_result.get("paddies", [])
	var anchors: Array = paddy_result.get("village_anchors", [])
	var centroids: Array[Vector3] = paddy_result.get("paddy_centroids", [])

	var water: Node = water_node
	var water_bodies: int = 0
	var river_count: int = 0
	if water != null and "water_bodies" in water:
		water_bodies = (water.water_bodies as Dictionary).size()
	# Rivers are stored as WaterBodyData too, just with type=CREEK or RIVER.
	# Count those from the body dict (separate from the hydrology map's raw
	# polylines, which the test does not need to read).
	if water != null and "water_bodies" in water:
		for wb in (water.water_bodies as Dictionary).values():
			if wb is Resource and "type" in wb and (wb.type == 1 or wb.type == 2):
				river_count += 1

	var gw: Node = get_tree().get_root().get_node_or_null("GameWorld")
	var terrain_cells: int = 0
	if gw != null and gw.has_node("TerrainManager"):
		terrain_cells = (gw.get_node("TerrainManager") as Node).terrain_manager.map_size * (gw.get_node("TerrainManager") as Node).terrain_manager.map_size

	print("=== WORLD GENERATION PROOF (seed=7777, no mission, location-first) ===")
	print("  planned locations:  %d (1 firebase + %d villages + %d camps)" % [
		locations.size(),
		locations.filter(func(l): return (l as LocationPlannerScript.PlannedLocation).kind == "village").size(),
		locations.filter(func(l): return (l as LocationPlannerScript.PlannedLocation).kind == "camp").size()
	])
	print("  paddy_fields:    %d" % paddies.size())
	print("  village_anchors: %d (hard floor = 8)" % anchors.size())
	print("  paddy_centroids: %d" % centroids.size())
	print("  water_bodies:    %d" % water_bodies)
	print("  rivers:          %d" % river_count)
	if anchors.size() < 8:
		print("  WARNING: village_anchors (%d) < hard floor (8). AO is paddy-poor; raise ground_y or expand paddy classification." % anchors.size())

	# Build a synthetic "plan" dict for the minimap. Keyed off the world's
	# actual outputs, not a mission's filtered subset.
	var sites: Array = []
	# Planned locations (from LocationPlanner) — these are the locations the
	# world is BUILT AROUND, drawn first so they read as the "anchor" points.
	for loc in locations:
		var lp2 = loc as LocationPlannerScript.PlannedLocation
		sites.append({"kind": lp2.kind, "center": lp2.center})
	# Paddy anchor groups (village-anchor locations from PaddyStamper).
	for a in anchors:
		sites.append({"kind": "paddy_anchor", "center": a.get("center", Vector3.ZERO)})
	# Individual paddy centroids.
	for c in centroids:
		sites.append({"kind": "paddy", "center": c})
	var p: Dictionary = {
		"village_anchors": anchors,
		"paddy_centroids": centroids,
		"sites": sites,
		"water_bodies": (water.water_bodies as Dictionary).values() if water != null and "water_bodies" in water else [],
	}

	# Visual-test setup: kill fog + billboards (no camera dep). The minimap
	# is built after the camera so it can read the initial position.
	# This block is test-only; the main game uses real fog and billboards.
	if _visual_test:
		_disable_fog_and_billboards(world)

	# Free-flying observer camera. FPS-standard controls:
	#   WASD = move (in camera-local axes)
	#   Q/E  = down/up
	#   Shift = 3x sprint
	#   Mouse = look
	# The camera spawns 100m above the AO center and looks at it on entry.
	camera = Camera3D.new()
	camera.fov = 75.0
	camera.far = 2000.0
	camera.near = 0.5
	camera.make_current()
	world.add_child(camera)
	if world.has_method("_wire_cameras"):
		(world as GameWorld)._wire_cameras(camera)

	# Spawn at AO center, 100m up.
	var map_size: float = 1280.0
	if gw != null and gw.has_node("TerrainManager"):
		map_size = (gw.get_node("TerrainManager") as Node).terrain_manager.map_size
	var ao_center: Vector3 = Vector3(map_size * 0.5, 0.0, map_size * 0.5)
	var ground_y: float = world.terrain_manager.get_height_at(ao_center)
	camera.global_position = Vector3(ao_center.x, ground_y + 100.0, ao_center.z)
	_firebase_anchor = ao_center
	# Forward-biased look so the drone enters in a banked look-down (not colinear with up).
	var look_dir: Vector3 = Vector3(0.0, -1.0, 0.4).normalized()
	camera.look_at(camera.global_position + look_dir, Vector3.UP)
	_fly_yaw = atan2(look_dir.x, look_dir.z)
	_fly_pitch = asin(clampf(look_dir.y, -1.0, 1.0))

	# Enable mouse capture for FPS-standard look.
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	set_process(true)
	set_process_input(true)

	# Visual-test minimap: build it now that the camera is alive and the
	# drone's initial position/yaw are set.
	if _visual_test:
		_build_minimap_overlay(p)

	print("FLY-CAM ACTIVE — drone controls: W/S forward/reverse, A/D strafe+roll, Space/Ctrl throttle, Q/E instant up/down, Shift sprint, Mouse look, R recenter above AO center, F freeze sim. Spawn: 100m above AO center, looking down. seed=7777, NO MISSION.")
	print("AO center ground_y=%.1f, ao_center=%s" % [ground_y, ao_center])

	# Run for 60 real-time seconds. The sim clock runs at 60x (1s real = 1m sim),
	# so we'll see 1 in-sim hour of activity.
	var run_s: float = 60.0
	var t: float = 0.0
	while t < run_s:
		await get_tree().create_timer(1.0).timeout
		t += 1.0
		if t - last_log >= 2.0:
			last_log = t
			_log_snapshot(t)

	print("=== OBSERVATION WINDOW CLOSED ===")
	_summary()
	get_tree().quit(0)


# ---- Drone observer ----------------------------------------------------------
## Drone-style 6-DOF observer. The camera is a free-flying body with no
## gravity, no ground stick, and no fixed up axis — yaw is your heading,
## pitch is your nose attitude, roll is what you bank into. Controls:
##   W/S     forward / reverse (along camera forward, even when pitched)
##   A/D     strafe left/right AND roll into the turn
##   Q/E     raw down/up (no throttle decay — instant altitude change)
##   Space   throttle up   (vertical speed ramps up, persists when released)
##   Ctrl    throttle down (vertical speed ramps down/past 0 into descent)
##   Shift   3x boost on horizontal motion
##   Mouse   look (yaw + pitch; roll eases back to level on its own)
##   ESC     release / recapture mouse
##   R       re-center above the firebase (handy when you've drifted far)
##   F      freeze sim (pause the sim clock; world stops moving but you fly on)

var _fly_yaw: float = 0.0
var _fly_pitch: float = 0.0
var _fly_roll: float = 0.0
var _fly_v_speed: float = 0.0
var _fly_roll_target: float = 0.0
const _FLY_BASE_SPEED: float = 22.0
const _FLY_SPRINT_MUL: float = 3.0
const _FLY_LOOK_SENSITIVITY: float = 0.0022
const _FLY_ROLL_MAX: float = 0.7
const _FLY_ROLL_EASE: float = 4.0
const _FLY_V_ACCEL: float = 12.0
const _FLY_V_MAX: float = 18.0
var _fly_paused: bool = false
var _firebase_anchor: Vector3 = Vector3.ZERO


func _process(delta: float) -> void:
	if camera == null:
		return
	# Visual-test minimap: push live drone state each frame. The minimap's
	# setter triggers queue_redraw so the marker tracks the camera.
	if _minimap != null and is_instance_valid(_minimap):
		_minimap.set_drone_state(camera.global_position, _fly_yaw)
	if _fly_paused and SimClock != null:
		# Stop sim time but keep the camera flying. The clock is the only
		# thing we touch here; the world keeps rendering so you can still
		# look around a frozen AO.
		pass
	# --- Orientation: ease roll back toward its target (zero unless A/D held) ---
	_fly_roll = lerpf(_fly_roll, _fly_roll_target, clampf(_FLY_ROLL_EASE * delta, 0.0, 1.0))
	# Free pitch — no clamp. The user can look straight up or straight down.

	# --- Build the camera's forward/right vectors from yaw + pitch + roll ---
	var fwd: Vector3 = Vector3(
		sin(_fly_yaw) * cos(_fly_pitch),
		sin(_fly_pitch),
		cos(_fly_yaw) * cos(_fly_pitch)
	).normalized()
	var world_up: Vector3 = Vector3.UP
	# Apply roll: rotate the right vector around the forward axis.
	var right_base: Vector3 = fwd.cross(world_up).normalized()
	if right_base.length_squared() < 0.001:
		right_base = Vector3.RIGHT
	var right: Vector3 = right_base.rotated(fwd, _fly_roll).normalized()
	var up: Vector3 = right.cross(fwd).normalized()

	# --- Throttle (Space / Ctrl) drives a persistent vertical velocity ---
	if Input.is_key_pressed(KEY_SPACE):
		_fly_v_speed = clampf(_fly_v_speed + _FLY_V_ACCEL * delta, -_FLY_V_MAX, _FLY_V_MAX)
	elif Input.is_key_pressed(KEY_CTRL):
		_fly_v_speed = clampf(_fly_v_speed - _FLY_V_ACCEL * delta, -_FLY_V_MAX, _FLY_V_MAX)
	else:
		# No throttle input — bleed the vertical speed back toward zero so
		# the drone settles into a hover when you stop asking it to climb.
		var bleed: float = _FLY_V_ACCEL * 0.6 * delta
		if _fly_v_speed > bleed:
			_fly_v_speed -= bleed
		elif _fly_v_speed < -bleed:
			_fly_v_speed += bleed
		else:
			_fly_v_speed = 0.0

	# --- Horizontal translation: W/S along forward, A/D strafe ---
	var h_speed: float = _FLY_BASE_SPEED * (1.0 if not Input.is_key_pressed(KEY_SHIFT) else _FLY_SPRINT_MUL)
	var move: Vector3 = Vector3.ZERO
	if Input.is_key_pressed(KEY_W):
		move += fwd
	if Input.is_key_pressed(KEY_S):
		move -= fwd
	if Input.is_key_pressed(KEY_A):
		move -= right
		# Bank left — pitch the nose down a touch and roll the body left so
		# the turn feels like a real aircraft, not a slider.
		_fly_roll_target = _FLY_ROLL_MAX * 0.6
	elif Input.is_key_pressed(KEY_D):
		move += right
		_fly_roll_target = -_FLY_ROLL_MAX * 0.6
	else:
		_fly_roll_target = 0.0
	# Q/E are instant altitude keys — they bypass the throttle and feel
	# like a trim wheel, not a momentum-driven climb.
	var trim: float = 0.0
	if Input.is_key_pressed(KEY_E):
		trim += 1.0
	if Input.is_key_pressed(KEY_Q):
		trim -= 1.0

	if move.length_squared() > 0.0:
		camera.global_position += move.normalized() * h_speed * delta
	camera.global_position += up * trim * h_speed * 0.6 * delta
	camera.global_position += up * _fly_v_speed * delta

	# Floor: don't punch through the terrain. A drone is allowed to kiss the
	# ground, not bury itself in it.
	var ground: float = -100.0
	var gw := get_tree().get_root().get_node_or_null("GameWorld")
	if gw != null and gw.has_node("TerrainManager"):
		ground = gw.get_node("TerrainManager").get_height_at(camera.global_position) + 1.0
	if camera.global_position.y < ground:
		camera.global_position.y = ground
		_fly_v_speed = maxf(0.0, _fly_v_speed)

	# --- Apply orientation. look_at with the rolled up vector so the camera
	#     banks through turns instead of staying level like a security cam. ---
	var look_target: Vector3 = camera.global_position + fwd
	camera.look_at(look_target, up)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var mm: InputEventMouseMotion = event
		_fly_yaw -= mm.relative.x * _FLY_LOOK_SENSITIVITY
		_fly_pitch -= mm.relative.y * _FLY_LOOK_SENSITIVITY
		# Free pitch: no clamp. A drone can look straight up at the sky
		# or pitch over to look at the ground beneath it.
	elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event is InputEventKey and event.pressed and event.keycode == KEY_R:
		# Re-center above the firebase. Useful after you've drifted far.
		if _firebase_anchor != Vector3.ZERO:
			var ground: float = 0.0
			if get_tree().get_root().get_node_or_null("GameWorld") != null:
				var gw := get_tree().get_root().get_node("GameWorld")
				if gw.has_node("TerrainManager"):
					ground = gw.get_node("TerrainManager").get_height_at(_firebase_anchor)
			camera.global_position = Vector3(_firebase_anchor.x, ground + 60.0, _firebase_anchor.z)
			_fly_v_speed = 0.0
	elif event is InputEventKey and event.pressed and event.keycode == KEY_F:
		# Freeze / unfreeze the sim. The world stops advancing but you fly on.
		_fly_paused = not _fly_paused
		if SimClock != null:
			SimClock.set_process(not _fly_paused)


func _log_snapshot(t: float) -> void:
	var civs: Array = get_tree().get_nodes_in_group("civilians")
	var enemies: Array = get_tree().get_nodes_in_group("enemies")
	var allies: Array = get_tree().get_nodes_in_group("allies")
	var live: int = 0
	if WorldSim != null:
		live = WorldSim.count_live()
	var sim_hour: float = SimClock.sim_hour if SimClock != null else 0.0
	print("[t=%2ds sim_h=%5.1f] civs=%d enemies=%d allies=%d worldsim_live=%d" \
			% [int(t), sim_hour, civs.size(), enemies.size(), allies.size(), live])
	# Sample what the civilians are doing.
	var civ_actions: Dictionary = {}
	for c in civs:
		if c == null or not is_instance_valid(c):
			continue
		var act: String = "?"
		if c is CivilianScript:
			act = String(c.active_action) if "active_action" in c else "?"
		civ_actions[act] = int(civ_actions.get(act, 0)) + 1
	if not civ_actions.is_empty():
		print("  civ actions: %s" % [civ_actions])
	# Camp directors? Print role of first few enemies.
	var sample: int = mini(3, enemies.size())
	for i in range(sample):
		var e = enemies[i]
		if e == null or not is_instance_valid(e):
			continue
		if e is Node3D and e is EnemyBaseScript:
			var eb = e as Node3D
			print("  enemy[%d] camp_role=%s pos=%s" % [i, str(e.get("camp_role")), eb.global_position])
	# Convoys in flight?
	var at_nodes: Array = get_tree().get_nodes_in_group("air_traffic")
	if at_nodes.size() > 0:
		print("  air-traffic nodes: %d" % at_nodes.size())
	# WorldSim roster.
	if WorldSim != null and WorldSim.entities.size() > 0:
		print("  worldsim entities: %d" % WorldSim.entities.size())


func _summary() -> void:
	var civs: Array = get_tree().get_nodes_in_group("civilians")
	var enemies: Array = get_tree().get_nodes_in_group("enemies")
	var allies: Array = get_tree().get_nodes_in_group("allies")
	print("--- SUMMARY (no mission; raw world) ---")
	print("civilians=%d enemies=%d allies=%d" % [civs.size(), enemies.size(), allies.size()])
	if WorldSim != null:
		print("worldsim: %d entities, %d live cells" % [WorldSim.entities.size(), WorldSim.count_live()])


# ============================================================================
# VISUAL TEST SETUP — test-only aids (fog off, billboards off, minimap on).
# Nothing here is wired into the main game. If you delete this whole block
# the test still functions as a smoke test.
# ============================================================================

## Strip fog and hide 2D billboard sprites. The minimap is built later
## (after the camera is alive) by _build_minimap_overlay.
func _disable_fog_and_billboards(world: Node) -> void:
	# 1) Fog off. MissionWeather sets env.fog_density from the weather table;
	# the WorldEnvironment is a child of the game world.
	var world_env := world.get_node_or_null("WorldEnvironment")
	if world_env != null and world_env.environment != null:
		world_env.environment.fog_enabled = false
		world_env.environment.fog_density = 0.0
		world_env.environment.fog_light_color = Color(1, 1, 1)
		world_env.environment.background_mode = 0  # clear color, no skybox tint
		print("VISUAL TEST: fog disabled")
	else:
		push_warning("VISUAL TEST: WorldEnvironment not found; fog may still be active")

	# 2) Hide 2D billboard sprites so the 3D tree meshes show at all ranges.
	# Pushing BILLBOARD_RANGE_MIN past BILLBOARD_RANGE_MAX forces every chunk
	# out of the billboard band.
	var bv := world.get_node_or_null("BillboardVegetation")
	if bv != null and bv is Node:
		var bb: Node = bv
		# GDScript class-level consts can be reassigned at runtime; this swaps
		# the band so 0..99999 is the only band, which the visibility filter
		# then correctly marks "out of range" for.
		bb.set("BILLBOARD_RANGE_MIN", 99999.0)
		bb.set("BILLBOARD_RANGE_MAX", 100000.0)
		print("VISUAL TEST: billboards forced out of range")
	else:
		push_warning("VISUAL TEST: BillboardVegetation not found; billboards may still show")


## Build the top-right HUD minimap and seed it with the plan + the drone's
## current position/yaw. Called from _run() once the camera is in the tree.
func _build_minimap_overlay(plan: Dictionary) -> void:
	if camera == null or not is_instance_valid(camera):
		push_warning("VISUAL TEST: camera not ready, minimap skipped")
		return
	_minimap = _build_minimap()
	add_child(_minimap)
	_minimap.set_plan(plan)
	_minimap.set_drone_state(camera.global_position, _fly_yaw)
	print("VISUAL TEST: minimap active (top-right HUD, 220x220)")


## Top-down minimap used by this test only.
const _MINIMAP_SCRIPT := preload("res://tests/test_world_minimap.gd")


func _build_minimap() -> Control:
	var panel: Control = _MINIMAP_SCRIPT.new()
	panel.name = "TestMinimap"
	panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	panel.position = Vector2(-230, 10)
	panel.size = Vector2(220, 220)
	# Mouse passes through to the 3D camera; the panel is a HUD overlay.
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return panel
