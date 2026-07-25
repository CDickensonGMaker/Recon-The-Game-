## mg_emplacement.gd - A fixed, pintle-mounted M60 post that ONE intent occupies:
## the player (a rifleman who mounted a gun) OR a promoted AI gun crew. It owns
## the mount geometry, the gunner stand, the traverse arc and the occupancy flag;
## the occupant owns its own body, camera and weapon. Never both at once.
##
## The node's local -Z is DOWNRANGE (the arc centre): the sandbag lip, the pintle
## and the gunner all face it. `create()` yaws the node so -Z points at `face`.
##
## Deliberately NOT built on SeatSystem (that is the UH-1 monolith - it would
## auto-generate 11 heli sockets and force a sitting clip). Fossil Law: the two
## mounts fail differently, so the glue is minimal and local here.
class_name MGEmplacement
extends StaticBody3D

const SANDBAG_MODEL: String = "res://assets/world/building models/structures/emplacements_real/mg_nest_sandbag.glb"
const PINTLE_MODEL: String = "res://assets/world/building models/structures/emplacements_real/m60_pintle.glb"

## Traverse arc, half-angles off the downrange centre. Generous so it reads as a
## sector to hold, not a wall the mouse hits (the clamp has no per-frame HUD tell).
const YAW_SPAN_DEG: float = 45.0
const PITCH_MIN_DEG: float = -22.0
const PITCH_MAX_DEG: float = 26.0
const REACH: float = 3.0            ## how close the player stands to see the verb

var _face_dir: Vector3 = Vector3.FORWARD
var _stand: Marker3D = null

## Who mans it now, or null. _occupant_is_ai routes the self-heal: an AI gunner is
## a normal AllyBase (no frozen physics to restore), the player restores itself.
var occupant: Node3D = null
var _occupant_is_ai: bool = false


## Stand an emplacement at `pos`, its arc centred on the horizontal `face`.
static func create(parent: Node, pos: Vector3, face: Vector3) -> MGEmplacement:
	var emp := MGEmplacement.new()
	var f := Vector3(face.x, 0.0, face.z)
	emp._face_dir = f.normalized() if f.length() > 0.01 else Vector3.FORWARD
	parent.add_child(emp)
	emp.global_position = pos
	# Yaw so local -Z is downrange: rotating (0,0,-1) by y gives (-sin y, 0, -cos y).
	emp.rotation.y = atan2(-emp._face_dir.x, -emp._face_dir.z)
	return emp


func _ready() -> void:
	collision_layer = 1   # world cover: stops rounds and bodies
	collision_mask = 0
	add_to_group("mg_emplacements")
	add_to_group("nav_source")
	_build()


func _build() -> void:
	# Sandbag cover, kept BELOW the gunner's muzzle line so the crew fires over it.
	var cover_size := Vector3(2.0, 1.0, 0.8)
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = cover_size
	cs.shape = box
	cs.position = Vector3(0.0, cover_size.y * 0.5, -0.35)
	add_child(cs)

	if ResourceLoader.exists(SANDBAG_MODEL):
		var bag := (load(SANDBAG_MODEL) as PackedScene).instantiate() as Node3D
		if bag != null:
			add_child(bag)
			bag.position = Vector3(0.0, 0.0, -0.35)
	if ResourceLoader.exists(PINTLE_MODEL):
		var pintle := (load(PINTLE_MODEL) as PackedScene).instantiate() as Node3D
		if pintle != null:
			add_child(pintle)
			pintle.position = Vector3(0.0, 0.9, -0.3)

	_stand = Marker3D.new()
	_stand.name = "GunnerStand"
	add_child(_stand)
	_stand.position = Vector3(0.0, 0.0, 0.6)   # behind the lip, feet on the ground


func _physics_process(_delta: float) -> void:
	# Self-heal (mirrors SeatSystem.occupant()): a freed or dead occupant releases
	# the post so a replacement can take it - no dangling flag, no corpse holding it.
	if occupant == null:
		return
	if not is_instance_valid(occupant):
		_clear_occupant()
		return
	if _occupant_is_ai and occupant.has_method("is_dead") and bool(occupant.call("is_dead")):
		_clear_occupant()


func is_occupied() -> bool:
	if occupant != null and not is_instance_valid(occupant):
		_clear_occupant()
	return occupant != null


## World point the gunner's feet snap to.
func gunner_stand_pos() -> Vector3:
	return _stand.global_position if _stand != null else global_position


## Where a dismounting player is placed - a step back off the gun.
func dismount_position() -> Vector3:
	return gunner_stand_pos() + global_transform.basis.z * 1.4


## Horizontal downrange direction the arc centres on.
func arc_center_dir() -> Vector3:
	var f := -global_transform.basis.z
	f.y = 0.0
	return f.normalized() if f.length() > 0.01 else _face_dir


func yaw_center() -> float:
	var d := arc_center_dir()
	return atan2(-d.x, -d.z)


## Arc limits in radians (the player reads these so the clamp lives in one place).
func yaw_span_rad() -> float:
	return deg_to_rad(YAW_SPAN_DEG)


func pitch_min_rad() -> float:
	return deg_to_rad(PITCH_MIN_DEG)


func pitch_max_rad() -> float:
	return deg_to_rad(PITCH_MAX_DEG)


## The player claims the post and drives its own mount (weapon, camera, clamp).
func man_by_player(player: Node) -> bool:
	if is_occupied() or player == null or not player.has_method("man_mg"):
		return false
	occupant = player as Node3D
	_occupant_is_ai = false
	player.call("man_mg", self)
	return true


func dismount_player() -> void:
	if not _occupant_is_ai:
		_clear_occupant()


## A promoted gun crew mans the post: pinned to the stand, the Pig in his hands
## (weapon AND sprite), facing his sector. He keeps his OWN AllyBase intent -
## acquire and fire are his, never the player's (Pillar 4).
func man_by_ai(ally: Node) -> bool:
	if is_occupied() or ally == null:
		return false
	occupant = ally as Node3D
	_occupant_is_ai = true
	var stand: Vector3 = gunner_stand_pos()
	(ally as Node3D).global_position = stand
	(ally as Node3D).reset_physics_interpolation()
	ally.set("post_anchor", stand)
	ally.set("post_leash", 1.0)
	ally.set("current_aim_dir", arc_center_dir())
	# The MG nameplate must match the gun: fire the Pig (42 dmg) AND look like it.
	ally.set("weapon_data", load("res://data/weapons/m60.tres"))
	if ally.has_method("set_sprite"):
		var unit: String = str(ally.get("sprite_unit"))
		ally.call("set_sprite", unit, "m60")
	return true


func _clear_occupant() -> void:
	occupant = null
	_occupant_is_ai = false
