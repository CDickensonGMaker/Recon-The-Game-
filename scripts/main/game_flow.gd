## game_flow.gd - Persistent root: menu -> select -> briefing -> world -> debrief
## loop (NS18/NS21). Swaps a single current_screen child; owns mission context.
class_name GameFlow
extends Node

var current_screen: Node = null
var world: GameWorld = null
var director: MissionDirector = null
var mission_hud: MissionHUD = null
var squad: SquadSystem = null
var session_rng := RandomNumberGenerator.new()
var current_offer: Dictionary = {}
var _debrief_pending: bool = false

## THE WAY OUT (audit L1). Esc paused the tree and showed nothing; Barracks lived
## only on the main menu, so XP earned in a campaign could not be spent without
## killing the process. GameFlow owns the pause menu because GameFlow is the only
## thing that knows where you are and what leaving means.
var _pause_menu: PauseMenu = null
var _in_world: bool = false     ## a mission or the hub is loaded
var _in_mission: bool = false   ## ...and it is a MISSION (not the hub)


func _ready() -> void:
	add_to_group("game_flow")
	process_mode = Node.PROCESS_MODE_ALWAYS   # Esc must work while paused
	session_rng.randomize()
	show_menu()


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


## Barracks OVER the paused world: spend XP without leaving the campaign. The
## world stays loaded underneath; BACK returns to the pause menu.
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
	SaveManager.save_to_slot(SaveManager.latest_slot() if SaveManager.latest_slot() >= 0 else 0)
	_close_pause()


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
	menu.start_pressed.connect(show_select)  # legacy path (seed-replay dev tool)
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


func show_select() -> void:
	var select := MissionSelectScreen.new()
	select.roll_offers(session_rng)
	select.offer_chosen.connect(show_briefing)
	select.back_pressed.connect(show_menu)
	_swap_screen(select)


func show_briefing(offer: Dictionary) -> void:
	current_offer = offer
	var briefing := BriefingScreen.new()
	briefing.set_offer(offer)
	briefing.deploy_pressed.connect(func() -> void: start_mission(current_offer))
	briefing.back_pressed.connect(show_select)
	_swap_screen(briefing)


func start_mission(offer: Dictionary) -> void:
	# Godot auto-randomizes the GLOBAL rng at startup, and most gameplay draws
	# from it: enemy personality (enemy_base.gd:180 pick_random), the crippled and
	# surrender rolls, whether the exfil bird is SHOT DOWN (exfil_zone.gd:67),
	# whether you CRASH on insertion (insertion_ride.gd:166-179), hunter
	# escalation timing, ordnance dispersion. Seeding it per mission makes all of
	# that reproducible from the seed the debrief prints.
	#
	# Honest scope: this makes generation and spawn deterministic. Per-frame draws
	# (bullet spread) still depend on execution order, which depends on frame
	# timing. Same seed = same world, same enemies, same events - not the same
	# bullet holes.
	seed(hash(int(offer.get("mission_seed", 0))))
	SaveManager.context = "mission"
	CampaignState.begin_mission()
	# HARD-tier wheels-down checkpoint (Phase D): the world is seed-deterministic,
	# so offer + carried state is a complete resume point. Written at launch.
	if bool(offer.get("from_hub", false)) and SaveManager.tier() == SaveManager.Tier.HARD:
		SaveManager.hub_snapshot["checkpoint_offer"] = offer.duplicate(true)
		SaveManager.save_game(5, "CHECKPOINT")
	var loading := ReconUI.make_screen_root()
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 20)
	col.add_child(ReconUI.make_label("INSERTING...", 30, ReconUI.AMBER))
	var tip := ReconUI.make_label(LOADING_TIPS[randi() % LOADING_TIPS.size()], 13, ReconUI.DIM)
	tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(tip)
	center.add_child(col)
	loading.add_child(center)
	_swap_screen(loading)
	_run_mission(offer)


## W84: field-manual wisdom on the way in.
const LOADING_TIPS: Array[String] = [
	"\"WHEN IN DOUBT, TRUST YOUR ALERTNESS.\" - RECON FIELD MANUAL, 1982",
	"CROUCH IN THE GREEN. THE JUNGLE HIDES THE PATIENT MAN.",
	"YOUR FIRST SHOT TELLS EVERYONE WHERE YOU ARE. MAKE IT COUNT.",
	"F1 ON ME. F2 HOLD. F3 MOVE THERE. F4 HOLD FIRE. YOUR SQUAD LISTENS.",
	"DOC CAN ONLY PATCH YOU TWICE. DON'T MAKE HIM RUN.",
	"NO RADIO, NO AIR. KEEP YOUR RTO BREATHING.",
	"THE POINT MAN SEES THE AMBUSH FIRST - IF YOU LET HIM WALK POINT.",
	"AK FIRE DOESN'T MARK YOU AS AMERICAN. THINK ABOUT IT.",
	"POP SMOKE [5] SO THE BIRD KNOWS WHERE YOU ARE.",
	"CLAYMORES [6]: FRONT TOWARD ENEMY.",
	"MORTARS [Y] NEED A SPOTTING ROUND. WALK THEM ON.",
	"HOT LZ? THE FALLBACK LZ IS FINAL. DON'T BE LATE.",
	"AN INFORMER ONLY NEEDS 25 SECONDS. STOP HIM OR MOVE FAST.",
	"LOOT THE DEAD [E]. DOCUMENTS SHARPEN TOMORROW'S BRIEFING.",
]


func _run_mission(offer: Dictionary) -> void:
	world = (load("res://scenes/levels/game_world.tscn") as PackedScene).instantiate() as GameWorld
	world.mission_seed = int(offer.world_seed)
	world.spawn_player_on_ready = false
	add_child(world)
	while not world.is_world_ready:
		await get_tree().create_timer(0.25).timeout
		if world == null:
			return

	director = MissionDirector.new()
	world.add_child(director)
	director.setup(world)
	director.mission_completed.connect(_on_mission_ended)
	director.mission_failed.connect(_on_mission_ended)

	var plan: Dictionary = MissionGenerator.plan(world, int(offer.mission_seed), int(offer.type) as MissionGenerator.MissionType)
	# THE BIRD FLIES (ADR-008 condition 2, audit L2). This used to erase start_pad
	# for every hub launch - and every reachable launch IS a hub launch - so the
	# InsertionRide (boarding, flight, AA fire, shoot-down, crash E&E) never ran
	# once in the shipped game, and the whole AA-threat economy had no consumer.
	# The ride IS the insertion; you board at the firebase and you fly in.
	var built: Dictionary = MissionGenerator.build(world, director, plan)
	# Ride in on the Huey when the plan has a start pad (all types but firebase).
	var spawn: Vector3 = plan.insertion_lz
	if plan.has("start_pad"):
		spawn = plan.start_pad
	world.spawn_player_at(spawn)
	if world.hud != null:
		world.hud.managed_by_flow = true

	mission_hud = MissionHUD.new()
	world.add_child(mission_hud)
	mission_hud.setup(world, director, built.sensors, built.exfil_zone, plan)

	# Weather + time of day from the briefing roll (W42/W43).
	var weather := MissionWeather.new()
	world.add_child(weather)
	weather.setup(world, str(plan.get("weather", "CLEAR")), str(plan.get("time", "DAY")))
	if MissionWeather.is_night:
		world.start_night_ambience()

	# The squad rides with you (W13).
	squad = SquadSystem.new()
	world.add_child(squad)
	squad.setup(world, director, spawn)
	mission_hud.squad = squad
	director.squad_system = squad

	if plan.has("start_pad"):
		var ride := InsertionRide.new()
		world.add_child(ride)
		ride.setup(world, director, plan.start_pad, plan.insertion_lz)
		ride.prompt_changed.connect(mission_hud.set_prompt)

	WeaponHolder.session_shots = 0
	WeaponHolder.session_hits = 0
	CampaignState.intel_points = 0  # briefing intel is spent going in (W80)
	_swap_screen(null)
	_in_world = true
	_in_mission = true    # Esc now opens a real pause menu with a way out
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	director.toast.emit("%s - %s" % [plan.codename, plan.type_name])


func _on_mission_ended(result: Dictionary) -> void:
	if _debrief_pending:
		return
	_debrief_pending = true
	if squad != null and is_instance_valid(squad):
		squad.on_mission_end()
	# W75: marksmanship into the report.
	result["shots"] = WeaponHolder.session_shots
	result["hits"] = WeaponHolder.session_hits
	# W25: debrief score banks as team XP.
	CampaignState.team_xp += maxi(0, DebriefScreen.compute_score(result))
	CampaignState.on_mission_end(result)
	SaveManager.hub_snapshot["checkpoint_offer"] = {}  # mission resolved - checkpoint spent
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


## ---------------- THE FIREBASE HUB LOOP (Phase B) ----------------
## menu -> pick an OPERATION -> live at its firebase -> get briefed in the TOC ->
## board the bird -> mission (the ride disguises the world load) -> exfil ->
## back at the firebase. CONTINUE restores you to the hub from the newest save.

## The single fixed operation the game boots into. The operation-select screen is
## retired (fossil law): NEW GAME drops you straight at the firebase hub. One seed
## per operation (ADR-010) - the same firebase and AO every launch.
const DEFAULT_OPERATION_SEED: int = 47225

func start_default_operation() -> void:
	_begin_operation(DEFAULT_OPERATION_SEED,
		"OPERATION %s" % MissionGenerator.codename_for(DEFAULT_OPERATION_SEED))


func _begin_operation(op_seed: int, op_name: String) -> void:
	SaveManager.hub_snapshot = {
		"operation_seed": op_seed, "operation_name": op_name,
		"offers": [], "accepted_offer": {}, "checkpoint_offer": {},
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
	# HARD-tier resume: an unresolved checkpoint re-runs its mission from wheels-down
	# (deterministic seed = same world), carrying the saved loadout/condition/hunger.
	var checkpoint: Dictionary = SaveManager.hub_snapshot.get("checkpoint_offer", {})
	if not checkpoint.is_empty():
		start_mission(checkpoint)
		return
	enter_hub()


func launch_accepted() -> void:
	var offer: Dictionary = SaveManager.hub_snapshot.get("accepted_offer", {})
	if offer.is_empty():
		return
	offer["from_hub"] = true
	SaveManager.hub_snapshot["accepted_offer"] = {}
	SaveManager.hub_snapshot["offers"] = []  # fresh board when you get back
	start_mission(offer)


func enter_hub() -> void:
	_teardown_world()
	SaveManager.context = "hub"
	var op_seed: int = int(SaveManager.hub_snapshot.get("operation_seed", 0))
	var op_name: String = str(SaveManager.hub_snapshot.get("operation_name", "OPERATION"))
	var loading := ReconUI.make_screen_root()
	var lc := CenterContainer.new()
	lc.set_anchors_preset(Control.PRESET_FULL_RECT)
	lc.add_child(ReconUI.make_label("RETURNING TO %s..." % op_name, 26, ReconUI.AMBER))
	loading.add_child(lc)
	_swap_screen(loading)
	world = (load("res://scenes/levels/game_world.tscn") as PackedScene).instantiate() as GameWorld
	world.mission_seed = op_seed
	world.spawn_player_on_ready = false
	add_child(world)
	while not world.is_world_ready:
		await get_tree().create_timer(0.25).timeout
		if world == null:
			return
	director = MissionDirector.new()
	world.add_child(director)
	director.setup(world)
	director.state.seed_value = op_seed
	var hub: Dictionary = MissionGenerator.build_hub(world, op_seed)
	var spawn: Vector3 = (hub.center as Vector3) + Vector3(4, 0, 6)
	world.spawn_player_at(spawn)
	if world.hud != null:
		world.hud.managed_by_flow = true
	squad = SquadSystem.new()
	world.add_child(squad)
	squad.setup(world, director, spawn)
	director.squad_system = squad
	var weather := MissionWeather.new()
	world.add_child(weather)
	weather.setup(world, "CLEAR", "DAY")
	var hc := HubController.new()
	world.add_child(hc)
	hc.setup(world, self, hub.tent, hub.huey, op_name)
	SaveManager.apply_pending_player(world.player)
	# Hot chow is free. YOUR RIFLE IS NOT (Summoner's decree, 2026-07-13): weapon
	# condition persists across missions and is only restored by working the
	# armorer's bench - it costs time, and it cannot be done in the field.
	if world.player != null:
		world.player.set("hunger", 100.0)
		var wh: Node = world.player.get_node_or_null("Head/Camera3D/WeaponHolder")
		if wh != null and wh.has_method("refresh_after_load"):
			wh.call("refresh_after_load")
	_swap_screen(null)
	_in_world = true
	_in_mission = false   # the hub: Esc offers Barracks, SAVE and QUIT TO MENU
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	SaveManager.save_game(SaveManager.AUTOSAVE_SLOT, "FIREBASE")
