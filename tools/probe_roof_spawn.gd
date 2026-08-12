## probe_roof_spawn.gd - FAILS when a spawned man's feet stand on a ROOF.
##
##   godot --headless --path . res://scenes/levels/demo_game.tscn -- --roof-probe
##   ... --roof-probe --demo-seed=12345
##
## Attached to the live world by game_flow.gd under `--roof-probe`; quits the tree with
## exit code 1 on any man on a roof.
extends Node

## The garrison and the ambient positioners are not all up on frame one; the demo's own
## squad move-out is at T+10s.
const SETTLE_S: float = 40.0
## Bodies that ARE ground. fsb_main_v3's mound plate is the firebase's floor (the model
## is the ground, site_planner.gd:1321), and the terrain chunks carry RaycastCollision.
const GROUND_NAMES: PackedStringArray = [
	"fb_terrain_mound", "fb_berm_ring", "RaycastCollision", "TerrainChunk",
]
## Clear air under a surface, with another solid floor below it, is a ROOM - so the
## surface over it is a roof. Under this a man is on a step, a sandbag or a berm lip.
const ROOM_HEADROOM_M: float = 1.8
## Feet to floor. Longer than a man's stride clearance, shorter than a storey.
const FOOT_REACH_M: float = 4.0
## Floor to whatever is under it. Two storeys plus the mound's own depth.
const UNDER_REACH_M: float = 14.0
## A man UNDER a roof is correctly seated however high his floor stands over the terrain -
## a hootch floor on a plinth reads identically to a roof from below. Open sky overhead is
## what separates the two.
const OVERHEAD_REACH_M: float = 5.0

var _world: Node3D = null
var _fails: int = 0
var _checked: int = 0


func _ready() -> void:
	_world = get_parent() as Node3D
	await get_tree().create_timer(SETTLE_S).timeout
	if _world == null or not is_instance_valid(_world):
		print("[ROOF-PROBE] no world - nothing measured")
		get_tree().quit(1)
		return
	_measure()


func _measure() -> void:
	print("\n=== ROOF SPAWN PROBE (seed %s) ===" % str(_world.get("mission_seed")))
	var men: Array[Node] = []
	men.append_array(AgentRegistry.allies)
	men.append_array(AgentRegistry.civilians)
	men.append_array(AgentRegistry.enemies)
	var player: Node3D = _world.get("player") as Node3D
	if player != null and is_instance_valid(player):
		men.append(player)
	for m in men:
		var body: Node3D = m as Node3D
		if body == null or not is_instance_valid(body) or not body.is_inside_tree():
			continue
		_checked += 1
		_check_one(body)
	print("[ROOF-PROBE] %d men checked, %d on roofs" % [_checked, _fails])
	if _fails == 0:
		print("*** NO MAN IS STANDING ON A ROOF. ***")
	get_tree().quit(1 if _fails > 0 else 0)


func _check_one(body: Node3D) -> void:
	var space: PhysicsDirectSpaceState3D = _world.get_world_3d().direct_space_state
	if space == null:
		return
	var feet: Vector3 = body.global_position
	var floor_hit: Dictionary = _cast(space, feet + Vector3.UP * 0.5,
		feet + Vector3.DOWN * FOOT_REACH_M, body)
	if floor_hit.is_empty():
		return   # airborne or falling: not this probe's gate
	var floor_pos: Vector3 = floor_hit.position
	var support: String = _body_name(floor_hit.collider)
	if _is_ground(support):
		return
	# A structure surface is only a roof if there is a room under it.
	var under: Dictionary = _cast(space, floor_pos + Vector3.DOWN * 0.15,
		floor_pos + Vector3.DOWN * UNDER_REACH_M, body)
	if under.is_empty():
		return
	var gap: float = floor_pos.y - (under.position as Vector3).y
	if gap < ROOM_HEADROOM_M:
		return
	var over: Dictionary = _cast(space, feet + Vector3.UP * 0.5,
		feet + Vector3.UP * OVERHEAD_REACH_M, body)
	if not over.is_empty():
		return   # he is INSIDE, under the roof, which is where he belongs
	_fails += 1
	print("  [FAIL] %s stands on '%s' at y=%.2f - %.2fm of open room under him (floor '%s')" % [
		body.name, support, floor_pos.y, gap, _body_name(under.collider)])


func _cast(space: PhysicsDirectSpaceState3D, from: Vector3, to: Vector3,
		exclude: Node3D) -> Dictionary:
	var q := PhysicsRayQueryParameters3D.create(from, to)
	q.collision_mask = 1   # world layer: terrain and placed structures both
	var rid: RID = (exclude as CollisionObject3D).get_rid() \
		if exclude is CollisionObject3D else RID()
	if rid.is_valid():
		q.exclude = [rid]
	return space.intersect_ray(q)


## The named body is not always the collider: adopted GLB structures hang their shapes
## on unnamed StaticBody3D children of the named mesh node.
func _body_name(collider: Object) -> String:
	var n: Node = collider as Node
	if n == null:
		return "?"
	var walk: Node = n
	for i in range(3):
		if walk == null:
			break
		for g in GROUND_NAMES:
			if walk.name.begins_with(g):
				return walk.name
		walk = walk.get_parent()
	return n.name


func _is_ground(nm: String) -> bool:
	for g in GROUND_NAMES:
		if nm.begins_with(g):
			return true
	return false
