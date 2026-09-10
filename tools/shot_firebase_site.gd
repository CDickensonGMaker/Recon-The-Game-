## shot_firebase_site.gd - PHOTOGRAPH THE STAMPED FIREBASE AT EYE HEIGHT.
##
## Run (NOT headless - rendering needs a graphics context):
##   godot --path . --resolution 320x240 res://tools/shot_firebase_site.tscn
##   SHOT_DIR   where the PNGs land (default: user://firebase_shots)
##   PROBE_PLAN which plan to stamp (default: fsb_kit_alpha)
##
## The frames are rendered by a SubViewport at 1600x900, NOT by the game window, so the
## window can stay 320x240 in a corner and nothing takes over his screen. A SubViewport with
## own_world_3d false renders the parent viewport's World3D - the same terrain, the same
## compound, the same light.
##
## EYE HEIGHT IS THE POINT. player.gd's camera sits at 1.62 m and this uses the same figure:
## a firebase photographed from 40 m up is a diagram, and every placement defect this kit
## exists to catch (a wall you cannot see over, a bunker facing a cut, a gate that reads as a
## fence) is invisible from there.
extends Node

const SitePick = preload("res://tools/firebase_site_pick.gd")

const SEED_VAL: int = 4242
const SITE_RADIUS: float = 40.0
const EYE_H: float = 1.62
const SHOT_W: int = 1600
const SHOT_H: int = 900
## Frames to let streaming, vegetation and the PSX pass settle before each capture.
const SETTLE: int = 30

var _world: GameWorld = null
var _vp: SubViewport = null
var _cam: Camera3D = null


func _ready() -> void:
	# NOTHING ON HIS SCREEN. The window has to exist (a graphics context does), but it does
	# not have to be seen or focused: park it off the top-left corner and refuse focus. Not
	# minimised - a minimised window can stop presenting frames on Windows and the captures
	# come back black.
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true)
	DisplayServer.window_set_position(Vector2i(-480, -420))

	var plan_name: String = OS.get_environment("PROBE_PLAN")
	if plan_name == "":
		plan_name = "fsb_kit_alpha"
	var out_dir: String = OS.get_environment("SHOT_DIR")
	if out_dir == "":
		out_dir = "user://firebase_shots"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))

	var plan: SitePlan = SitePlan.load_from(plan_name)
	if plan == null:
		print("[SHOT] no plan '%s'" % plan_name)
		get_tree().quit(1)
		return

	var world_scene: PackedScene = load("res://scenes/levels/game_world.tscn")
	_world = world_scene.instantiate()
	_world.mission_seed = SEED_VAL
	_world.spawn_player_on_ready = false
	add_child(_world)
	var waited: float = 0.0
	while not _world.is_world_ready and waited < 240.0:
		await get_tree().create_timer(0.5).timeout
		waited += 0.5
	if not _world.is_world_ready:
		print("[SHOT] world timeout")
		get_tree().quit(1)
		return

	var rng := RandomNumberGenerator.new()
	rng.seed = SEED_VAL
	var planner := SitePlanner.new(_world.gameplay_grid, _world.terrain_manager,
		_world.vegetation_manager, _world)
	var pick: Dictionary = SitePick.pick(planner, _world.terrain_manager, rng, SITE_RADIUS,
		plan.flatten_radius)
	var centre: Vector3 = pick.get("centre", Vector3.ZERO)
	print("[SHOT] site %s (same seed and same picker as the probe)" % str(centre.round()))
	var site: Dictionary = planner.stamp_site_plan(plan, centre, KitRegistry.load_kit())
	if site.is_empty():
		print("[SHOT] the stamp was refused")
		get_tree().quit(1)
		return
	var compound: Node3D = (site.get("nodes", []) as Array)[0] as Node3D

	_vp = SubViewport.new()
	_vp.size = Vector2i(SHOT_W, SHOT_H)
	_vp.own_world_3d = false
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_vp.transparent_bg = false
	add_child(_vp)
	_cam = Camera3D.new()
	_cam.fov = 70.0
	_cam.far = 900.0
	_vp.add_child(_cam)
	_cam.current = true
	# The terrain and vegetation stream against a camera. Point them at this one or the
	# chunks under the shot never load and the firebase stands on nothing.
	_world.terrain_manager.set_camera(_cam)
	_world.vegetation_manager.set_camera(_cam)

	var gate: Node3D = _part(compound, "fb_gate_assembly")
	var gun: Node3D = _part(compound, "fb_emplacement_m101")
	var road: Vector3 = Vector3.FORWARD
	if gate != null:
		road = gate.global_transform.basis.z
		road.y = 0.0
		road = road.normalized()
		if (gate.global_position + road).distance_to(centre) \
				< gate.global_position.distance_to(centre):
			road = -road

	var gate_at: Vector3 = gate.global_position if gate != null else centre
	var gun_at: Vector3 = gun.global_position if gun != null else centre
	# Three frames a man walking up the road actually gets, in order.
	var shots: Array = [
		# MEASURED, twice: at 62 m and again at 30 m the frame is jungle. The pad stands 8 m
		# above the approach, so the crest hides its own wire until about 20 m out and the
		# bamboo fills anything wider. 22 m on the road axis is where the wall becomes a
		# wall - and that is a fact about the SITE, not about the camera.
		["01_approach", gate_at + road * 22.0, gate_at + Vector3(0.0, 2.4, 0.0)],
		["02_gate", gate_at + road * 8.0, gate_at + Vector3(0.0, 2.2, 0.0)],
		["03_inside", gate_at - road * 16.0 + road.cross(Vector3.UP) * 4.0,
			gun_at + Vector3(0.0, 1.2, 0.0)],
	]
	for s_any in shots:
		var s: Array = s_any
		var eye: Vector3 = s[1]
		eye.y = _world.floor_y(eye) + EYE_H
		var look: Vector3 = s[2]
		_cam.global_position = eye
		_cam.look_at(look, Vector3.UP)
		for _i in range(SETTLE):
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var img: Image = _vp.get_texture().get_image()
		var path: String = "%s/%s.png" % [out_dir, str(s[0])]
		var err: int = img.save_png(path)
		print("[SHOT] %-12s eye %s -> %s (err %d)"
			% [str(s[0]), str(eye.round()), ProjectSettings.globalize_path(path), err])

	print("[SHOT] done")
	get_tree().quit(0)


static func _part(compound: Node3D, pid: String) -> Node3D:
	for c in compound.get_children():
		var n := c as Node3D
		if n != null and str(n.get_meta("part_id", "")) == pid:
			return n
	return null
