extends Node3D

## THE TEST RANGE. His ask 2026-08-05: "make me a small test range that uses the same in
## game world terrain code but its just me and the rto guy wiht un limited shots of stuff
## and terrain of everything thats in the game and demo."
##
##   godot --path . res://scenes/levels/test_range.tscn
##
## Same world code as the shipped game, nothing simulated on top. It runs the REAL builder
## (plan_demo_world -> build_patrol_world), so the firebase, villages, temples, VC camps,
## trails, paddies and jungle are the ones the demo ships - not a bench approximation.
##
## The support-fire bench cannot do this: FireSupportBench.wire() installs a BenchTerrain
## stub and points DamageSystem at it, so every dig is a silent no-op and no vegetation
## manager is ever wired. That is why ordnance there never craters and never fells a tree.
##
##   [T] net · 1 bombs 2 napalm 3 arty 4 mortar 5 spectre 6 CBU   - all unlimited
##   [G] airburst 6m over whatever you are looking at
##
## [G] earns its place: a GROUND burst fells a tree ENTIRE by design, and only a burst
## above the base picks a joint. Without it he can shell the treeline all day and never
## once see the segmented break he came here to judge.

const AIRBURST_KEY: Key = KEY_G
const AIRBURST_HEIGHT_M: float = 6.0
const AIRBURST_REACH_M: float = 70.0
const RESTOCK: int = 9        ## topped up every frame - he never counts rounds here

var world: GameWorld = null
var player: CharacterBody3D = null
var _director: FieldDirector = null


func _ready() -> void:
	var packed: PackedScene = load("res://scenes/levels/game_world.tscn") as PackedScene
	world = packed.instantiate() as GameWorld
	add_child(world)

	var waited: int = 0
	while DamageSystem.terrain_manager == null and waited < 1800:
		await get_tree().process_frame
		waited += 1
	if DamageSystem.terrain_manager == null:
		push_error("[TEST RANGE] terrain never came up")
		return
	print("[TEST RANGE] terrain up (%d frames). canopy=%s  damage_veg=%s"
		% [waited, WorldConfig.USE_TREE_COVER, DamageSystem.vegetation_manager != null])

	_build_director()
	# THE REAL WORLD, the same two calls game_flow makes. The demo plan is the compact
	# one - everything inside a walk, which is what a range wants.
	var plan: Dictionary = MissionGenerator.plan_demo_world(world, 20260805)
	var built: Dictionary = MissionGenerator.build_patrol_world(world, _director, plan)
	# THE COLLIDER RACE (game_flow:610): build_patrol_world add_child()s the firebase
	# colliders synchronously, and PhysicsServer3D will not answer a raycast against them
	# until the next physics step - so the spawn probe below would drop him through it.
	await get_tree().physics_frame
	await get_tree().physics_frame
	print("[TEST RANGE] world built: %d site(s)" % (built.get("sites", []) as Array).size())

	# NO AIR TRAFFIC ON A RANGE. build_patrol_world stands up AirTraffic, which runs the
	# garrison replacement lift - that is the squads he saw spawn off to his right and jog
	# into the firebase, and on a range it is pure noise between him and the treeline.
	var at_node: Node = world.get_node_or_null("AirTraffic")
	if at_node != null:
		at_node.queue_free()
		print("[TEST RANGE] AirTraffic removed - no replacement lifts, no flyovers")

	_spawn_player_and_rto(plan)

	# THE FIRE MENU IS THE HUD'S. MissionHUD listens to director.fire_menu_changed and
	# draws the "ON THE NET - FIRE MISSION" panel; without it [T] opens a net with no
	# menu on screen and the range cannot be used the way the demo is.
	var hud := MissionHUD.new()
	hud.name = "RangeHUD"
	world.add_child(hud)
	hud.setup(world, _director, plan)
	print("[TEST RANGE] MissionHUD up - [T] draws the fire menu")
	print("[TEST RANGE] [T] net · 1 bombs 2 napalm 3 arty 4 mortar 5 spectre 6 CBU (unlimited) · [G] airburst")


func _build_director() -> void:
	var ss := SquadSystem.new()
	ss.name = "RangeSquad"
	add_child(ss)
	ss.set_physics_process(false)   # a roster holder, not a live squad: setup() would
	ss.set_process(false)           # spawn a squad whose loops fault with no mission
	_director = FieldDirector.new()
	_director.name = "RangeFieldDirector"
	add_child(_director)
	_director.setup(world)
	_director.squad_system = ss
	_director._hunter_pool = 0       # nothing escalates; he is here to shoot, not be hunted


func _spawn_player_and_rto(plan: Dictionary) -> void:
	var scene: PackedScene = load("res://scenes/player/player.tscn") as PackedScene
	if scene == null:
		return
	player = scene.instantiate() as CharacterBody3D
	add_child(player)
	player.set("allow_photo_mode", false)
	# Outside the wire of the firebase the builder just placed, facing the treeline.
	var fsb: Vector3 = plan.get("fsb_center", Vector3.ZERO)
	var at: Vector3 = fsb + Vector3(0.0, 0.0, SitePlanner.FSB_HALF.y + 30.0)
	var hm: Object = DamageSystem.terrain_manager.get("heightmap")
	at.y = (float(hm.sample_world(at.x, at.z)) + 1.2) if hm != null else 2.0
	player.global_position = at
	GameManager.player = player
	var cam := player.get_node_or_null("Head/Camera3D") as Camera3D
	if cam != null:
		cam.current = true

	# ONLY IF THE WORLD DID NOT ALREADY MAKE ONE. build_patrol_world stands up the firebase
	# garrison, and adding a second radioman on top of it put a duplicate squad in the
	# range. Any radioman is a valid net now (field_director.nearest_radioman), so if the
	# world supplied one, use his - just walk to him.
	var existing: Array = get_tree().get_nodes_in_group("radioman")
	if not existing.is_empty():
		print("[TEST RANGE] world already fielded %d radioman/men - not spawning another"
			% existing.size())
		return
	var rto: AllyBase = AllyBase.spawn_ally(self, at + Vector3(2.0, 0.0, 1.0))
	if rto == null:
		push_warning("[TEST RANGE] no RTO - every fire mission will be refused")
		return
	rto.add_to_group("radioman")
	rto.member = {"nick": "SPARKS", "mos": "RTO"}
	rto.set_sprite("us_grunt_rto", "m16a1", "US")
	rto.set_order(AllyBase.OrderMode.FOLLOW)
	var handset := RadioHandset.attach_to(rto)
	if handset != null:
		player.call("bind_radio_handset", handset)
	(_director.squad_system as SquadSystem).members.append(rto)


## Unlimited by RESTOCK rather than by a huge number: the HUD still reads a count and the
## radio still runs every gate, so nothing about the call path is faked - he just never
## runs out.
func _process(_delta: float) -> void:
	if _director == null:
		return
	for k in _director.fire_support:
		if int(_director.fire_support[k]) < RESTOCK:
			_director.fire_support[k] = RESTOCK


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.is_echo()):
		return
	if (event as InputEventKey).keycode != AIRBURST_KEY or player == null:
		return
	var cam := player.get_node_or_null("Head/Camera3D") as Camera3D
	if cam == null:
		return
	# Where he is LOOKING, at canopy height: the joint nearest that height is the one that
	# breaks, which is the entire thing he is here to judge.
	var at: Vector3 = player.global_position + (-cam.global_transform.basis.z) * AIRBURST_REACH_M
	var hm: Object = DamageSystem.terrain_manager.get("heightmap") if DamageSystem.terrain_manager != null else null
	if hm != null:
		at.y = float(hm.sample_world(at.x, at.z)) + AIRBURST_HEIGHT_M
	DamageSystem.apply_damage(at, DamageSystem.DamageType.MEDIUM_EXPLOSION, 1.0)
	var veg: Node = DamageSystem.vegetation_manager
	print("[TEST RANGE] airburst %.0f,%.0f,%.0f (%.0fm up) - fell registry %d"
		% [at.x, at.y, at.z, AIRBURST_HEIGHT_M,
			((veg._fell_registry as Array).size() if veg != null else -1)])
