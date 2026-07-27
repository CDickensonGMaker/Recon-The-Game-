## game_flow.gd - Persistent root: menu -> select -> briefing -> world -> debrief
## loop (NS18/NS21). Swaps a single current_screen child; owns mission context.
class_name GameFlow
extends Node

var current_screen: Node = null
var world: GameWorld = null
var director: FieldDirector = null
var mission_hud: MissionHUD = null
var squad: SquadSystem = null
var _debrief_pending: bool = false

## THE WAY OUT (audit L1). GameFlow owns the pause menu because GameFlow is the
## only thing that knows where you are and what leaving means.
var _pause_menu: PauseMenu = null
var _in_world: bool = false     ## a mission or the hub is loaded
var _in_mission: bool = false   ## ...and it is a MISSION (not the hub)


func _ready() -> void:
	add_to_group("game_flow")
	process_mode = Node.PROCESS_MODE_ALWAYS   # Esc must work while paused
	# Boot lands in the patrol, not on the menu. The menu stays reachable at
	# Esc -> QUIT TO MENU. Swap this call back to show_menu() to restore it.
	start_default_operation()


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("pause") or not _in_world:
		return
	get_viewport().set_input_as_handled()
	if _pause_menu != null:
		_close_pause()
	else:
		_open_pause()


func _open_pause() -> void:
	if _pause_menu != null:
		return
	GameManager.pause_game()
	_pause_menu = PauseMenu.new()
	add_child(_pause_menu)
	_pause_menu.build(_in_mission)
	_pause_menu.resume_pressed.connect(_close_pause)
	_pause_menu.barracks_pressed.connect(_pause_barracks)
	_pause_menu.save_pressed.connect(_pause_save)
	_pause_menu.abandon_pressed.connect(_pause_abandon)
	_pause_menu.quit_to_menu_pressed.connect(_pause_quit)


func _close_pause() -> void:
	if _pause_menu != null:
		_pause_menu.queue_free()
		_pause_menu = null
	GameManager.resume_game()


## Barracks OVER the paused world: check the roster without leaving the campaign.
## The world stays loaded underneath; BACK returns to the pause menu.
func _pause_barracks() -> void:
	if _pause_menu != null:
		_pause_menu.teardown()
	var barracks := BarracksScreen.new()
	barracks.process_mode = Node.PROCESS_MODE_ALWAYS
	barracks.back_pressed.connect(func() -> void:
		barracks.queue_free()
		if _pause_menu != null:
			_pause_menu.build(_in_mission))
	add_child(barracks)


func _pause_save() -> void:
	var slot: int = SaveManager.latest_slot() if SaveManager.latest_slot() >= 0 else 0
	var ok: bool = SaveManager.save_game(slot, "MANUAL")
	_close_pause()
	var hud: Node = get_tree().get_first_node_in_group("mission_hud")
	if hud != null and hud.has_method("show_toast"):
		hud.call("show_toast", "SAVED" if ok else "SAVE FAILED")


## Abandoning is a DEBRIEF, not a delete (Pillar 5: fail forward). Route through
## the director's own abort so the roster consequences are the real ones.
func _pause_abandon() -> void:
	_close_pause()
	if director != null and director.has_method("fail_mission"):
		director.fail_mission("ABANDONED")


func _pause_quit() -> void:
	_close_pause()
	show_menu()


func _swap_screen(screen: Node) -> void:
	if current_screen != null:
		current_screen.queue_free()
	current_screen = screen
	if screen != null:
		add_child(screen)


func _teardown_world() -> void:
	if _pause_menu != null:
		_pause_menu.queue_free()
		_pause_menu = null
	_in_world = false
	_in_mission = false
	if world != null:
		world.queue_free()
		world = null
	director = null
	mission_hud = null
	squad = null
	GameManager.player = null
	GameManager.is_paused = false
	get_tree().paused = false
	MissionScope.reset()
	# Whatever the mission changed (KIA, replacements, intel) commits here or not
	# at all. on_mission_end() has already run for a completed op.
	CampaignState.commit_mission()


func show_menu() -> void:
	_teardown_world()
	SaveManager.context = "menu"
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	var menu := MainMenuScreen.new()
	menu.continue_pressed.connect(continue_campaign)
	menu.new_pressed.connect(start_default_operation)
	menu.barracks_pressed.connect(show_barracks)
	menu.record_pressed.connect(show_service_record)
	menu.settings_pressed.connect(show_settings)
	_swap_screen(menu)


func show_barracks() -> void:
	var barracks := BarracksScreen.new()
	barracks.back_pressed.connect(show_menu)
	_swap_screen(barracks)


func show_service_record() -> void:
	var record := ServiceRecordScreen.new()
	record.back_pressed.connect(show_menu)
	_swap_screen(record)


func show_settings() -> void:
	var settings := SettingsScreen.new()
	settings.back_pressed.connect(show_menu)
	_swap_screen(settings)


func _on_mission_ended(result: Dictionary) -> void:
	if _debrief_pending:
		return
	_debrief_pending = true
	if squad != null and is_instance_valid(squad):
		squad.on_mission_end()
	# W75: marksmanship into the report.
	result["shots"] = WeaponHolder.session_shots
	result["hits"] = WeaponHolder.session_hits
	# The AAR score banks as hidden reputation (ADR-032) - the only tell is the title.
	if CampaignState.bank_reputation(DebriefScreen.compute_score(result)) and director != null:
		director.toast.emit("FIELD PROMOTION: %s" % CampaignState.title())
	CampaignState.on_mission_end(result)
	# W32: Iron Man - KIA archives the whole campaign.
	if CampaignState.iron_man and not bool(result.get("success", true)) and str(result.get("reason", "")) == "KIA":
		result["iron_man_wipe"] = true
		CampaignState.reset_campaign()
	_show_debrief_delayed(result)


func _show_debrief_delayed(result: Dictionary) -> void:
	await get_tree().create_timer(3.0).timeout
	_debrief_pending = false
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_teardown_world()
	var debrief := DebriefScreen.new()
	debrief.set_result(result)
	var back_to_hub: bool = int(SaveManager.hub_snapshot.get("operation_seed", 0)) != 0 \
		and not bool(result.get("iron_man_wipe", false))
	debrief.continue_pressed.connect(enter_hub if back_to_hub else show_menu)
	_swap_screen(debrief)


## ---------------- THE OPEN PATROL WORLD (ADR-029 draft) ----------------
## menu -> NEW/CONTINUE -> live at the firebase inside the populated AO ->
## walk out the wire -> patrol. One world, one build, one operation seed.

## The single fixed operation the game boots into. The operation-select screen is
## retired (fossil law): NEW GAME drops you straight at the firebase hub. One seed
## per operation (ADR-010) - the same firebase and AO every launch.
const DEFAULT_OPERATION_SEED: int = 47225

func start_default_operation() -> void:
	# `--perf-seed=N` benches a seed other than the shipped one. Levers that exist only
	# under some conditions (campfires are NIGHT/DUSK/DAWN only) are unmeasurable at
	# 47225, which rolls DAY. Measurement override only - the shipped default is 47225.
	var op_seed: int = DEFAULT_OPERATION_SEED
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--perf-seed="):
			op_seed = int(a.get_slice("=", 1))
	_begin_operation(op_seed, MissionGenerator.codename_for(op_seed))


func _begin_operation(op_seed: int, op_name: String) -> void:
	SaveManager.hub_snapshot = {
		"operation_seed": op_seed, "operation_name": op_name,
	}
	enter_hub()


func continue_campaign() -> void:
	var slot := SaveManager.latest_slot()
	if slot < 0:
		start_default_operation()
		return
	load_from_slot(slot)


func load_from_slot(slot: int) -> void:
	var s: SaveData = SaveManager.load_game(slot)
	if s == null:
		show_menu()
		return
	SaveManager.apply(s)
	if int(SaveManager.hub_snapshot.get("operation_seed", 0)) == 0:
		start_default_operation()
		return
	enter_hub()


## The array (get_height_at) and the baked chunk mesh MUST agree at the player's
## feet, and the log proves it on every deploy - the probe suite once said "level"
## while the live player stood under the hillside (verify in object space).
func _report_spawn_truth(spawn: Vector3, op_seed: int) -> void:
	if world == null or world.player == null:
		return
	var space := world.get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(
		Vector3(spawn.x, 400.0, spawn.z), Vector3(spawn.x, -100.0, spawn.z))
	q.exclude = [world.player.get_rid()]
	var hit: Dictionary = space.intersect_ray(q)
	var phys_y: float = -999.0
	var cname: String = "NO-HIT"
	if hit.has("position"):
		phys_y = (hit.position as Vector3).y
		if hit.collider is Node:
			cname = (hit.collider as Node).name
	var arr_y: float = world.terrain_manager.get_height_at(spawn)
	print("[SPAWN-TRUTH] seed=%d spawn=%.0f,%.0f physics_y=%.2f array_y=%.2f delta=%.2f top_hit=%s player_y=%.2f" % [
		op_seed, spawn.x, spawn.z, phys_y, arr_y, phys_y - arr_y, cname,
		world.player.global_position.y])


## Re-entrancy generation. enter_hub AWAITS while the world builds, so a second
## entry that arrives mid-build (boot auto-starts a patrol in _ready, and any
## menu path can call in on top of it) used to interleave with the first: the
## older coroutine resumed past its await and added a SECOND FieldDirector.
## Two directors both poll the wire and both bank, which double-counted every
## patrol - rank and missions_played advanced twice per walk-out.
var _world_entry: int = 0


func enter_hub() -> void:
	_world_entry += 1
	var entry: int = _world_entry
	_teardown_world()
	SaveManager.context = "hub"
	var op_seed: int = int(SaveManager.hub_snapshot.get("operation_seed", 0))
	var op_name: String = str(SaveManager.hub_snapshot.get("operation_name", "OPERATION"))
	var loading := ReconUI.make_screen_root()
	var lc := CenterContainer.new()
	lc.set_anchors_preset(Control.PRESET_FULL_RECT)
	lc.add_child(ReconUI.make_label("BACK TO %s..." % op_name, 26, ReconUI.AMBER))
	loading.add_child(lc)
	_swap_screen(loading)
	world = (load("res://scenes/levels/game_world.tscn") as PackedScene).instantiate() as GameWorld
	world.mission_seed = op_seed
	world.spawn_player_on_ready = false
	add_child(world)
	while not world.is_world_ready:
		await get_tree().create_timer(0.25).timeout
		if world == null or entry != _world_entry:
			return
	if entry != _world_entry:
		return
	director = FieldDirector.new()
	world.add_child(director)
	director.setup(world)
	director.state.seed_value = op_seed
	# THE OPEN PATROL WORLD (ADR-029 draft): the firebase and its populated AO are
	# ONE build - form up, walk out the wire, go find problems.
	var patrol_plan: Dictionary = MissionGenerator.plan_patrol_world(world, op_seed)
	var built: Dictionary = MissionGenerator.build_patrol_world(world, director, patrol_plan)
	var spawn: Vector3 = built.spawn_pos
	# Dev lens: `--spawn-at-village` drops the patrol at the nearest village edge so
	# the living world can be judged without the walk (temporary, Summoner 2026-07-18).
	if OS.get_cmdline_user_args().has("--spawn-at-village"):
		var best: Vector3 = spawn
		var best_d: float = INF
		for s in patrol_plan.sites:
			var site: Dictionary = s
			if str(site.get("kind", "")) == "village":
				var c: Vector3 = site.center
				var dist: float = Vector2(c.x - spawn.x, c.z - spawn.z).length()
				if dist < best_d:
					best_d = dist
					best = c
		if best_d < INF:
			var back: Vector3 = (spawn - best).normalized()
			spawn = best + Vector3(back.x, 0.0, back.z) * 60.0
			spawn.y = world.terrain_manager.get_height_at(spawn)
			print("[SPAWN-DEV] --spawn-at-village: dropped %.0fm from village at %.0f,%.0f" % [
				60.0, best.x, best.z])
	world.spawn_player_at(spawn)
	if world.hud != null:
		world.hud.managed_by_flow = true
	squad = SquadSystem.new()
	world.add_child(squad)
	squad.setup(world, director, spawn)
	director.squad_system = squad
	director.setup_patrol(built)
	# Death outside the wire is a field AAR, then you wake at the firebase
	# (Pillar 5) - same debrief pipeline, patrol framing.
	director.mission_failed.connect(_on_mission_ended)
	# The field HUD: toasts/barks/compass/squad strip. No objective panel exists
	# to show - the patrol world plans none.
	mission_hud = MissionHUD.new()
	world.add_child(mission_hud)
	mission_hud.setup(world, director, patrol_plan)
	mission_hud.squad = squad
	var weather := MissionWeather.new()
	world.add_child(weather)
	weather.setup(world, str(patrol_plan.weather), str(patrol_plan.time))
	if MissionWeather.is_night:
		world.start_night_ambience()
	MissionGenerator.apply_veg_boosts(world,
		(built.gate_pos as Vector3) + (built.gate_out as Vector3) * 90.0, patrol_plan.sites)
	WeaponHolder.session_shots = 0
	WeaponHolder.session_hits = 0
	SaveManager.apply_pending_player(world.player)
	# A restored position is X/Z memory, never Y truth: the world reseats terrain
	# every build, so a stale saved height puts the player under the ground (the
	# 'below the firebase, vegetation above me' bug). Re-seat to CURRENT terrain.
	if world.player != null:
		var pp: Vector3 = world.player.global_position
		world.player.global_position.y = world.terrain_manager.get_height_at(pp) + 1.0
	# Hot chow is free. YOUR RIFLE IS NOT (Summoner's decree, 2026-07-13): weapon
	# condition persists across missions and is only restored by working the
	# armorer's bench - it costs time, and it cannot be done in the field.
	if world.player != null:
		world.player.set("hunger", 100.0)
		var wh: Node = world.player.get_node_or_null("Head/Camera3D/WeaponHolder")
		if wh != null and wh.has_method("refresh_after_load"):
			wh.call("refresh_after_load")
	await get_tree().physics_frame  # settle cover colliders before reveal (no first-frame resettle)
	# Ray where the player ACTUALLY stands (post save-restore), not the planned
	# spawn - the save teleport was invisible to a spawn-point ray.
	_report_spawn_truth(world.player.global_position if world.player != null else spawn, op_seed)
	# Instruments attach to the world the player actually walks - never a world of
	# their own. `--perf-probe` samples, `--perf-cycle` runs the attribution phases.
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.has("--perf-probe"):
		var probe: Node = (load("res://tests/perf_probe.tscn") as PackedScene).instantiate()
		probe.set("cycle_systems", args.has("--perf-cycle"))
		probe.set("shadow_study", args.has("--shadow-study"))
		world.add_child(probe)
		probe.call("attach", world)
	_swap_screen(null)
	_in_world = true
	_in_mission = false   # the hub: Esc offers Barracks, SAVE and QUIT TO MENU
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	SaveManager.save_game(SaveManager.AUTOSAVE_SLOT, "FIREBASE")
