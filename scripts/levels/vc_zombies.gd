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

## THE USE KEY IS E, HARDCODED, AND THAT IS DELIBERATE.
##
## The project's `interact` action is bound to F (project.godot:253), while E is
## bound to `lean_right`. This mode has no leaning - his ruling: "in this game
## mode you cannot lean so it makes holding E the true interaction button" - so E
## is free and it is the key every prompt in here names.
##
## Repointing the global `interact` action instead would be worse: InputMap is
## global and the rebind would follow him back into the campaign.
const USE_KEY: Key = KEY_E

@export var spawn_player: bool = true
@export var spawn_hud: bool = true
@export var rng_seed: int = 20260805

var map: ZombieMapLot = null
var night: ZombieNight = null
var body_light: SpotLight3D = null
var economy: ZombieEconomy = null
var director: ZombieWaveDirector = null
var player: CharacterBody3D = null

var _focus: ZombieInteractable = null
var _focus_barricade: ZombieBarricade = null
var _label: Label = null
var _prompt: Label = null


func _ready() -> void:
	add_to_group("game_world")

	economy = ZombieEconomy.new()
	economy.name = "ZombieEconomy"
	add_child(economy)

	map = ZombieMapLot.new()
	map.name = "Lot"
	add_child(map)
	map.build(rng_seed)

	night = ZombieNight.new()
	night.name = "Night"
	add_child(night)
	night.apply_night(self, rng_seed)
	_light_the_lot()

	# Navigation needs physics frames to register the freshly baked region before
	# any agent can resolve a path on it. Spawning the first wave before that
	# lands leaves the whole round standing still at the ring.
	await get_tree().physics_frame
	await get_tree().physics_frame

	_spawn_player()
	_build_hud()
	_audit_spawn_points()

	director = ZombieWaveDirector.new()
	director.name = "WaveDirector"
	add_child(director)
	director.setup(self, rng_seed)
	director.round_began.connect(_on_round_began)
	director.wave_count_changed.connect(func(_a: int, _b: int) -> void: _refresh_hud())
	economy.points_changed.connect(func(_p: int, _d: int, _r: String) -> void: _refresh_hud())
	director.begin()

	print("[VC ZOMBIES] the lot is up - %d spawn point(s), %d breach(es), %d gate(s)" % [
		get_tree().get_nodes_in_group("zombie_spawns").size(),
		get_tree().get_nodes_in_group("zombie_barricades").size(),
		get_tree().get_nodes_in_group("zombie_doors").size()])
	_report_first_wave()


## PROOF OF LIFE. "Round 1 - 6 coming" only says the director INTENDED to spawn;
## the silent-lot bug printed exactly that line while producing nobody. This
## reports what actually stood up, which is the thing worth knowing.
func _report_first_wave() -> void:
	await get_tree().create_timer(6.0).timeout
	if director == null or not is_instance_valid(director):
		return
	print("[VC ZOMBIES] 6s in - %d alive, %d still to spawn"
		% [director.alive.size(), director.left_to_spawn()])


## Lamps go where the player has to WALK, not where the map is prettiest: the lot,
## the gates and the yard. Lit ground is the safe ground, so its shape is a level
## design decision - the dark stretches between these are the route choices.
func _light_the_lot() -> void:
	# the lot itself - two rows, so the start is legible on round 1
	night.place_lamp_row(self, Vector3(32, 0, 66), Vector3(70, 0, 66), 3)
	night.place_lamp_row(self, Vector3(32, 0, 90), Vector3(70, 0, 90), 3)
	# the gates, so an opening always reads as an opening
	for g in ZombieMapLot.GATES:
		night.place_lamp(self, (g["at"] as Vector3) + Vector3(2.0, 0.0, 2.0), false)
	# hangar and yard: sparser and faultier, so bought ground feels less safe than
	# the ground you started on
	night.place_lamp(self, Vector3(88, 0, 68), true)
	night.place_lamp(self, Vector3(112, 0, 84), false)
	night.place_lamp(self, Vector3(96, 0, 30), true)
	night.place_lamp(self, Vector3(40, 0, 34), false)
	night.place_lamp(self, Vector3(62, 0, 44), true)


## EVERY SPAWN POINT MUST STAND ON THE NAVMESH, AND THIS IS CHECKED OUT LOUD.
##
## The first layout's ground plane was exactly the compound footprint while spawns
## are pushed OUTSIDE the perimeter, so all fourteen sat in the void. Nothing ever
## spawned and the map was silent. Nothing failed, nothing warned - the round just
## never filled, which reads to the player as a broken game and to me as a broken
## director. This is the guard for that whole class of bug.
func _audit_spawn_points() -> void:
	var map_rid: RID = get_world_3d().navigation_map
	# The map must have SYNCHRONISED before it can be queried. Querying earlier
	# returns garbage and the server says so ("query failed because it was made
	# before first map synchronization") - which made this audit's first run
	# report all 14 points stranded when every one of them was fine. An audit that
	# cries wolf is worse than no audit.
	NavigationServer3D.map_force_update(map_rid)
	await get_tree().physics_frame
	await get_tree().physics_frame

	var points: Array[Node] = get_tree().get_nodes_in_group("zombie_spawns")
	var stranded: Array[String] = []
	for n in points:
		var s := n as Node3D
		if s == null:
			continue
		var closest: Vector3 = NavigationServer3D.map_get_closest_point(
			map_rid, s.global_position)
		# A point off the mesh snaps to a far-away edge. On the mesh it barely moves.
		if closest.distance_to(s.global_position) > 3.0:
			stranded.append("%s @ %.0f,%.0f" % [s.name, s.global_position.x,
				s.global_position.z])
	if stranded.is_empty():
		print("[VC ZOMBIES] all %d spawn point(s) sit on navmesh" % points.size())
		return
	push_warning(("[VC ZOMBIES] %d of %d spawn point(s) are OFF the navmesh and can "
		+ "never produce a zombie: %s. The ground plane must extend past anything "
		+ "the horde spawns behind.") % [stranded.size(), points.size(),
		", ".join(stranded)])


func _spawn_player() -> void:
	if not spawn_player:
		return
	var scene: PackedScene = load("res://scenes/player/player.tscn")
	player = scene.instantiate() as CharacterBody3D
	add_child(player)
	player.set("allow_photo_mode", false)
	# No leaning in this mode (his ruling), which is what frees E to be the use key.
	player.set("allow_lean", false)
	body_light = ZombieNight.attach_body_light(player)
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
	var held: bool = Input.is_key_pressed(USE_KEY)
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
