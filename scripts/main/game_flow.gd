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


func _ready() -> void:
	add_to_group("game_flow")
	session_rng.randomize()
	show_menu()


func _swap_screen(screen: Node) -> void:
	if current_screen != null:
		current_screen.queue_free()
	current_screen = screen
	if screen != null:
		add_child(screen)


func _teardown_world() -> void:
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
	menu.new_pressed.connect(show_operation_select)
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
	if bool(offer.get("from_hub", false)):
		plan.erase("start_pad")  # you already boarded at the firebase - wheels-down at the LZ
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

func show_operation_select() -> void:
	var root := ReconUI.make_screen_root()
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	center.add_child(col)
	col.add_child(ReconUI.make_header("CHOOSE YOUR OPERATION", 30))
	col.add_child(ReconUI.make_label("EACH OPERATION IS A FIREBASE AND ITS AO. MISSIONS ARE PICKED AT THE TOC.", 13, ReconUI.DIM))
	col.add_child(ReconUI.make_divider())
	for i in range(3):
		var op_seed: int = session_rng.randi() % 100000
		var op_name: String = "OPERATION %s" % MissionGenerator.codename_for(op_seed)
		var region: String = MissionOffers.TERRAIN_HINTS[session_rng.randi() % MissionOffers.TERRAIN_HINTS.size()]
		var card := ReconUI.make_card_button("%s\n%s" % [op_name, region], 16, 64.0)
		card.pressed.connect(func() -> void: _begin_operation(op_seed, op_name))
		col.add_child(card)
	var back := ReconUI.make_button("BACK", 16)
	back.pressed.connect(show_menu)
	col.add_child(back)
	_swap_screen(root)


func _begin_operation(op_seed: int, op_name: String) -> void:
	SaveManager.hub_snapshot = {
		"operation_seed": op_seed, "operation_name": op_name,
		"offers": [], "accepted_offer": {}, "checkpoint_offer": {},
	}
	enter_hub()


func continue_campaign() -> void:
	var slot := SaveManager.latest_slot()
	if slot < 0:
		show_operation_select()
		return
	load_from_slot(slot)


func load_from_slot(slot: int) -> void:
	var s: SaveData = SaveManager.load_game(slot)
	if s == null:
		show_menu()
		return
	SaveManager.apply(s)
	if int(SaveManager.hub_snapshot.get("operation_seed", 0)) == 0:
		show_operation_select()
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
	_swap_screen(null)
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	SaveManager.save_game(SaveManager.AUTOSAVE_SLOT, "FIREBASE")
