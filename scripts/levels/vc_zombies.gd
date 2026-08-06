## vc_zombies.gd - VC ZOMBIES. The mode root.
##
## Builds THE DEPOT, stands up the economy and the wave clock, drops the player in
## the dispatch office with a pistol and 500 points, and gets out of the way.
##
## Everything this scene owns is mode-local. The campaign must not inherit a points
## counter, a round clock or a horde it never asked for, which is why ZombieEconomy
## is a node here rather than an autoload.
extends Node3D

const ARMORY: Array[String] = ["m16", "ak", "shotgun", "m60", "rpg"]
## Held-use key. Resolved against the project's InputMap at boot rather than
## hardcoded, so this follows a rebind.
const USE_ACTIONS: Array[String] = ["interact", "use", "ui_accept"]

@export var spawn_player: bool = true
@export var spawn_hud: bool = true
@export var rng_seed: int = 20260805

var map: ZombieMapDepot = null
var economy: ZombieEconomy = null
var director: ZombieWaveDirector = null
var player: CharacterBody3D = null

var _use_action: String = ""
var _focus: ZombieInteractable = null
var _focus_barricade: ZombieBarricade = null
var _label: Label = null
var _prompt: Label = null


func _ready() -> void:
	add_to_group("game_world")
	_resolve_use_action()

	economy = ZombieEconomy.new()
	economy.name = "ZombieEconomy"
	add_child(economy)

	map = ZombieMapDepot.new()
	map.name = "Depot"
	add_child(map)
	map.build(rng_seed)

	# Navigation needs physics frames to register the freshly baked region before
	# any agent can resolve a path on it. Spawning the first wave before that
	# lands leaves the whole round standing still at the ring.
	await get_tree().physics_frame
	await get_tree().physics_frame

	_spawn_player()
	_build_hud()

	director = ZombieWaveDirector.new()
	director.name = "WaveDirector"
	add_child(director)
	director.setup(self, rng_seed)
	director.round_began.connect(_on_round_began)
	director.wave_count_changed.connect(func(_a: int, _b: int) -> void: _refresh_hud())
	economy.points_changed.connect(func(_p: int, _d: int, _r: String) -> void: _refresh_hud())
	director.begin()

	print("[VC ZOMBIES] depot up - %d spawn point(s), %d barricade(s), %d door(s)" % [
		get_tree().get_nodes_in_group("zombie_spawns").size(),
		get_tree().get_nodes_in_group("zombie_barricades").size(),
		get_tree().get_nodes_in_group("zombie_doors").size()])


func _resolve_use_action() -> void:
	for a in USE_ACTIONS:
		if InputMap.has_action(a):
			_use_action = a
			return
	push_warning("[VC ZOMBIES] no interact action in the InputMap (tried %s) - "
		% ", ".join(USE_ACTIONS) + "falling back to the E key")


func _spawn_player() -> void:
	if not spawn_player:
		return
	var scene: PackedScene = load("res://scenes/player/player.tscn")
	player = scene.instantiate() as CharacterBody3D
	add_child(player)
	player.set("allow_photo_mode", false)
	player.global_position = map.player_start() + Vector3.UP
	GameManager.player = player
	var cam := player.get_node_or_null("Head/Camera3D") as Camera3D
	if cam != null:
		cam.current = true

	if not spawn_hud:
		return
	var hud: HUD = load("res://scenes/ui/hud.tscn").instantiate() as HUD
	add_child(hud)
	hud.setup(player.get_node("HealthSystem"),
		player.get_node("Head/Camera3D/WeaponHolder"),
		player.get_node("EquipmentManager"),
		player.get_node("Head/Camera3D/GrenadeHandler"))


func _process(delta: float) -> void:
	_update_focus()
	_update_use(delta)
	_refresh_hud()


## The nearest thing in reach. Nearest rather than look-at because a boarded
## window is a wide object you stand beside, and a crosshair test makes rebuilding
## under pressure feel broken.
func _update_focus() -> void:
	_focus = null
	_focus_barricade = null
	if player == null or not is_instance_valid(player):
		return
	var best: float = 1e9
	for n in get_tree().get_nodes_in_group("zombie_interactables"):
		var it := n as ZombieInteractable
		if it == null or not is_instance_valid(it) or not it.in_range(player):
			continue
		if it.prompt().is_empty():
			continue
		var d: float = it.global_position.distance_to(player.global_position)
		if d < best:
			best = d
			_focus = it
	for n in get_tree().get_nodes_in_group("zombie_barricades"):
		var b := n as ZombieBarricade
		if b == null or not is_instance_valid(b) or not b.can_rebuild():
			continue
		var d: float = b.global_position.distance_to(player.global_position)
		if d < 2.4 and d < best:
			best = d
			_focus = null
			_focus_barricade = b


func _update_use(delta: float) -> void:
	var held: bool = Input.is_key_pressed(KEY_E) if _use_action.is_empty() \
		else Input.is_action_pressed(_use_action)
	if not held:
		if _focus != null:
			_focus.release()
		if _focus_barricade != null:
			_focus_barricade.cancel_rebuild()
		return
	if _focus_barricade != null:
		_focus_barricade.rebuild(delta, player)
	elif _focus != null:
		_focus.try_use(player, delta)


func _on_round_began(n: int, strength: int) -> void:
	print("[VC ZOMBIES] ROUND %d - %d coming" % [n, strength])


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	layer.name = "ZombieHUD"
	add_child(layer)
	_label = Label.new()
	_label.position = Vector2(24, 24)
	_label.add_theme_font_size_override("font_size", 22)
	layer.add_child(_label)
	_prompt = Label.new()
	_prompt.anchor_left = 0.5
	_prompt.anchor_right = 0.5
	_prompt.anchor_top = 0.62
	_prompt.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.add_theme_font_size_override("font_size", 18)
	layer.add_child(_prompt)


func _refresh_hud() -> void:
	if _label == null or economy == null or director == null:
		return
	_label.text = "ROUND %d\n%d\nkills %d" % [
		maxi(1, director.round_number), economy.points, economy.kills]
	if _prompt == null:
		return
	if _focus_barricade != null:
		_prompt.text = "Hold [E] - REBUILD  (%d/%d)" % [
			_focus_barricade.boards_left, _focus_barricade.board_count]
	elif _focus != null:
		_prompt.text = _focus.prompt()
	else:
		_prompt.text = ""
