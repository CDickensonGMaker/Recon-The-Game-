## mortar_pit.gd - The firebase mortar pit: sandbag nest, M29 tube, ammo point,
## and named crew stations that garrison AI claims as jobs. The node's local -Z
## is DOWNRANGE (the tube's fire direction); station markers sit exactly where
## the staged crew works in assets/us/artillery/mortar_crew_staging.blend.
## (An earlier note here cited a mocap-toolkit/ path OUTSIDE this repo as the
## source of truth; the staging .blend above is the one that ships.)
##
## Occupancy mirrors MGEmplacement: one body per station, claimed and released
## by name. This node owns geometry and stations only - fire missions stay with
## the fire-support system.
class_name MortarPit
extends Node3D

const SCENE: String = "res://scenes/world/mortar_pit.tscn"

## station name -> the Node3D occupying it (null when free)
var _occupants: Dictionary = {}

const STATIONS: Array[String] = ["station_gunner", "station_dropper", "station_runner"]


func _ready() -> void:
	add_to_group("mortar_pits")
	for s in STATIONS:
		_occupants[s] = null


## Stand a pit at `pos`, tube arc centred on the horizontal `face` direction.
static func create(parent: Node, pos: Vector3, face: Vector3) -> MortarPit:
	var pit: MortarPit = (load(SCENE) as PackedScene).instantiate() as MortarPit
	parent.add_child(pit)
	pit.global_position = pos
	var flat: Vector3 = Vector3(face.x, 0.0, face.z)
	if flat.length() > 0.01:
		pit.look_at(pos + flat.normalized(), Vector3.UP)
		pit.rotate_y(PI)   # look_at points +Z at the target; downrange is -Z
	return pit


func station_position(station: String) -> Vector3:
	var m: Node3D = get_node_or_null(NodePath(station)) as Node3D
	return m.global_position if m != null else global_position


func is_free(station: String) -> bool:
	return _occupants.get(station, null) == null


## A garrison body claims a station; returns false if it is taken.
func claim(station: String, body: Node3D) -> bool:
	if not _occupants.has(station) or _occupants[station] != null:
		return false
	_occupants[station] = body
	if "defense_zone" in body:
		body.set("defense_zone", station_position(station))
	return true


func release(station: String) -> void:
	if _occupants.has(station):
		_occupants[station] = null


func free_stations() -> Array[String]:
	var out: Array[String] = []
	for s in STATIONS:
		if _occupants[s] == null:
			out.append(s)
	return out
