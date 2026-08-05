## zombie_barricade.gd - a boarded opening the dead tear down and the player rebuilds.
##
## THE NAV PROBLEM, AND WHY THIS DESIGN AVOIDS IT ENTIRELY.
## Nothing in this project re-bakes the navmesh when a structure dies
## (siege_director.gd:64-67, citing nav_baker.gd:16-18), and the siege's barbwire is
## one merged ring that cannot be broken at all. So "zombies smash a hole in the wall
## and flood in" is not buildable without new nav machinery.
##
## It does not need to be. The navmesh here is baked with every opening ALREADY OPEN
## and never changes. What stands in the gap is a PHYSICAL blocker and nothing else:
## the horde paths straight at the opening, walks into wood, and chews through it
## (ZombieBase._barricade_in_the_way). Tearing the last board changes no navigation
## state, because the navigation was always open. Rebuilding changes none either.
##
## That is the whole trick, and it is why this reads as the genre while touching
## none of the engine's nav baking.
class_name ZombieBarricade
extends Node3D

signal board_torn(remaining: int, by: Node)
signal breached()
signal board_rebuilt(remaining: int, by: Node)

## Points the player earns per plank replaced. The rebuild has to PAY or nobody
## ever turns their back on the room to do it.
const REBUILD_REWARD: int = 10
## Seconds of held interact per plank.
const REBUILD_TIME: float = 0.6

@export var board_count: int = 6
## Openings vary: a ward window is not a double door. Set per instance.
@export var opening_size: Vector2 = Vector2(1.6, 1.5)
@export var barricade_id: String = ""

var boards_left: int = 0
var _planks: Array[Node3D] = []
var _blocker: StaticBody3D = null
var _rebuild_t: float = 0.0


func _ready() -> void:
	add_to_group("zombie_barricades")
	boards_left = board_count
	_build_planks()
	_build_blocker()
	_refresh()


## The planks are generated rather than authored: an opening is a rectangle and a
## plank is a box across it, so a hand-placed set would be twelve near-identical
## scenes to maintain. Materials come from the world kit at assemble time.
func _build_planks() -> void:
	var w: float = opening_size.x
	var h: float = opening_size.y
	for i in board_count:
		var plank := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(w * 1.05, 0.11, 0.045)
		plank.mesh = bm
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.33, 0.24, 0.15).lerp(Color(0.22, 0.16, 0.10),
			float(i) / maxf(1.0, float(board_count)))
		mat.roughness = 1.0
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		plank.material_override = mat
		# Stagger the run and tilt each one - a perfectly stacked ladder of boards
		# reads as a fence, not as something nailed up in a hurry.
		var t: float = (float(i) + 0.5) / float(board_count)
		plank.position = Vector3(randf_range(-0.05, 0.05), (t - 0.5) * h, 0.0)
		plank.rotation.z = deg_to_rad(randf_range(-6.0, 6.0))
		add_child(plank)
		_planks.append(plank)


## One collider for the whole opening, disabled the moment the last plank goes.
## Per-plank colliders would let a zombie squeeze between two boards.
func _build_blocker() -> void:
	_blocker = StaticBody3D.new()
	_blocker.name = "BoardBlocker"
	_blocker.collision_layer = 1
	_blocker.collision_mask = 0
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(opening_size.x, opening_size.y, 0.2)
	cs.shape = box
	_blocker.add_child(cs)
	add_child(_blocker)
	# NOT a nav_source. Adding it would carve the opening out of the navmesh and
	# reintroduce the exact rebake problem this design exists to avoid.


func is_open() -> bool:
	return boards_left <= 0


func tear(count: int = 1, by: Node = null) -> void:
	if is_open():
		return
	boards_left = maxi(0, boards_left - count)
	_refresh()
	board_torn.emit(boards_left, by)
	if boards_left == 0:
		breached.emit()


## Held-interact rebuild. Returns true on the frame a plank actually goes back up.
func rebuild(delta: float, by: Node = null) -> bool:
	if boards_left >= board_count:
		return false
	_rebuild_t += delta
	if _rebuild_t < REBUILD_TIME:
		return false
	_rebuild_t = 0.0
	boards_left += 1
	_refresh()
	board_rebuilt.emit(boards_left, by)
	if ZombieEconomy.current != null:
		ZombieEconomy.current._add(REBUILD_REWARD, "rebuild")
	return true


func cancel_rebuild() -> void:
	_rebuild_t = 0.0


func can_rebuild() -> bool:
	return boards_left < board_count


func _refresh() -> void:
	for i in _planks.size():
		_planks[i].visible = i < boards_left
	if _blocker != null:
		# The gap is passable the instant the boards are gone, and solid again the
		# instant one goes back up.
		_blocker.process_mode = Node.PROCESS_MODE_INHERIT
		for c in _blocker.get_children():
			var cs := c as CollisionShape3D
			if cs != null:
				cs.disabled = is_open()
