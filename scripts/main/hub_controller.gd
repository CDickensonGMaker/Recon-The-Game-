## hub_controller.gd - Runs the firebase hub: the HQ-tent briefing prompt, the
## board-the-bird prompt once a mission is accepted, and the hub's own prompt
## label (the hub has no MissionHUD). Polling pattern copied from
## insertion_ride._poll_board - distance scan + [E], no Area3D coupling.
class_name HubController
extends Node

const TENT_RANGE: float = 5.0
const BIRD_RANGE: float = 6.0

var world: GameWorld
var flow: Node  # GameFlow
var tent: Node3D
var huey: Node3D
var operation_name: String = ""

var _prompt: Label = null
var _briefing_open: bool = false


func setup(game_world: GameWorld, game_flow: Node, hub_tent: Node3D, hub_huey: Node3D, op_name: String) -> void:
	world = game_world
	flow = game_flow
	tent = hub_tent
	huey = hub_huey
	operation_name = op_name
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	_prompt = ReconUI.make_label("", 18, ReconUI.AMBER)
	_prompt.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_prompt.position = Vector2(-200, -120)
	_prompt.custom_minimum_size = Vector2(400, 0)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	layer.add_child(_prompt)


func _physics_process(_delta: float) -> void:
	if _briefing_open or world == null or world.player == null or not GameManager.can_player_act():
		if _prompt != null and _briefing_open:
			_prompt.text = ""
		return
	var p: Vector3 = world.player.global_position
	var accepted: Dictionary = SaveManager.hub_snapshot.get("accepted_offer", {})

	if tent != null and is_instance_valid(tent) and p.distance_to(tent.global_position) <= TENT_RANGE:
		_prompt.text = "ENTER THE TOC - GET BRIEFED [E]"
		if Input.is_action_just_pressed("interact"):
			_open_briefing()
		return
	if not accepted.is_empty() and huey != null and is_instance_valid(huey) \
			and p.distance_to(huey.global_position) <= BIRD_RANGE:
		_prompt.text = "%s ACCEPTED - BOARD THE BIRD [E]" % str(accepted.get("codename", "MISSION"))
		if Input.is_action_just_pressed("interact"):
			_prompt.text = ""
			if flow != null and flow.has_method("launch_accepted"):
				flow.call("launch_accepted")
		return
	if accepted.is_empty() and huey != null and is_instance_valid(huey) \
			and p.distance_to(huey.global_position) <= BIRD_RANGE:
		_prompt.text = "GET BRIEFED AT THE TOC FIRST"
		return
	_prompt.text = ""


func _open_briefing() -> void:
	_briefing_open = true
	_prompt.text = ""
	# Fresh board each visit if none rolled yet (seeded: operation + missions flown).
	var offers: Array = SaveManager.hub_snapshot.get("offers", [])
	if offers.is_empty():
		var rng := RandomNumberGenerator.new()
		rng.seed = int(SaveManager.hub_snapshot.get("operation_seed", 0)) * 31 + CampaignState.missions_played
		offers = MissionOffers.roll(rng)
		SaveManager.hub_snapshot["offers"] = offers
	var panel := HubBriefing.new()
	add_child(panel)
	panel.open(operation_name, offers)
	panel.accepted.connect(func(offer: Dictionary) -> void:
		_briefing_open = false
		SaveManager.hub_snapshot["accepted_offer"] = offer
		SaveManager.save_game(SaveManager.AUTOSAVE_SLOT, "FIREBASE"))
	panel.closed.connect(func() -> void: _briefing_open = false)
