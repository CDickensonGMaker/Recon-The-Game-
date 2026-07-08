## game_flow.gd - Persistent root: menu -> select -> briefing -> world -> debrief
## loop (NS18/NS21). Swaps a single current_screen child; owns mission context.
class_name GameFlow
extends Node

var current_screen: Node = null
var world: GameWorld = null
var director: MissionDirector = null
var mission_hud: MissionHUD = null
var session_rng := RandomNumberGenerator.new()
var current_offer: Dictionary = {}
var _debrief_pending: bool = false


func _ready() -> void:
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
	GameManager.player = null
	GameManager.is_paused = false
	get_tree().paused = false


func show_menu() -> void:
	_teardown_world()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	var menu := MainMenuScreen.new()
	menu.start_pressed.connect(show_select)
	_swap_screen(menu)


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
	var loading := ReconUI.make_screen_root()
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.add_child(ReconUI.make_label("INSERTING...", 30, ReconUI.AMBER))
	loading.add_child(center)
	_swap_screen(loading)
	_run_mission(offer)


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
	var built: Dictionary = MissionGenerator.build(world, director, plan)
	world.spawn_player_at(plan.insertion_lz)
	if world.hud != null:
		world.hud.managed_by_flow = true

	mission_hud = MissionHUD.new()
	world.add_child(mission_hud)
	mission_hud.setup(world, director, built.sensors, built.exfil_zone, plan)

	_swap_screen(null)
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	director.toast.emit("%s - %s" % [plan.codename, plan.type_name])


func _on_mission_ended(result: Dictionary) -> void:
	if _debrief_pending:
		return
	_debrief_pending = true
	CampaignState.on_mission_end(result)
	_show_debrief_delayed(result)


func _show_debrief_delayed(result: Dictionary) -> void:
	await get_tree().create_timer(3.0).timeout
	_debrief_pending = false
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_teardown_world()
	var debrief := DebriefScreen.new()
	debrief.set_result(result)
	debrief.continue_pressed.connect(show_menu)
	_swap_screen(debrief)
