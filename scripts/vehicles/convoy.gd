## convoy.gd - a group of vehicles driving a route in formation.
##
## UNPARKED 2026-07-20: the road network (RoadNetwork) now supplies real routes, so
## this drives actual ground between actual places. Routes come from
## RoadNetwork.longest_route() via ConvoySpawner - never from arbitrary points.
## The lead vehicle navigates; trailing vehicles slot 6m behind. On contact
## (any member reports a hostile), the convoy stops and emits `ambushed` so the
## mission director can spawn reinforcements or a rescue mission.
class_name Convoy
extends Node3D

signal waypoint_reached(convoy: Convoy)
signal ambushed(convoy: Convoy, position: Vector3)
signal route_finished(convoy: Convoy)

## Route waypoints (Vector3). The lead follows these in order; the trail
## chains behind at `spacing` metres.
var route: Array[Vector3] = []
## Vehicles in drive order: [0] is the lead, the rest trail.
var vehicles: Array = []   ## Array[DestructibleVehicle]
## metres between consecutive vehicles.
## How fast a vehicle swings its nose onto the direction of travel, as a lerp weight per
## second. Loose enough that a bend reads as a turn, tight enough that the column does not
## visibly lag its own road.
const TURN_RATE: float = 3.0

var spacing: float = 6.0
## m/s along the route. Trucks do 12 m/s (~43 km/h), APCs 10 m/s.
var speed: float = 12.0
## Index of the next waypoint we're steering toward.
var current_waypoint: int = 0
## Did we already trigger ambushed this leg? Don't re-emit on every frame the
## target is visible.
var _ambush_emitted: bool = false
## Stop the convoy (e.g. waiting for an obstacle to clear). -1 means go.
var stop_until_ms: float = -1.0
## Terrain to seat vehicles on. Without it a convoy drives at its spawn altitude and
## sinks into hills or flies over valleys - the route's own Y is only correct at the
## waypoints, and the ground between them is not flat.
var terrain: TerrainManager = null


func _ready() -> void:
	set_physics_process(true)


func setup(r: Array[Vector3], v: Array) -> void:
	route = r
	vehicles = v
	current_waypoint = 0


func _physics_process(delta: float) -> void:
	if route.is_empty() or vehicles.is_empty():
		return
	if stop_until_ms > 0.0:
		if _now_ms() < stop_until_ms:
			return
		# The stop has run out. Going through resume() rather than just clearing the
		# timer is what re-arms the ambush latch: a convoy hit once, halted, and sent
		# on its way must be able to report the NEXT contact.
		resume()
	var lead: Node3D = vehicles[0]
	if not is_instance_valid(lead):
		return
	if current_waypoint >= route.size():
		route_finished.emit(self)
		set_physics_process(false)
		return
	var target: Vector3 = route[current_waypoint]
	var d: Vector3 = target - lead.global_position
	d.y = 0.0
	if d.length() < 2.5:
		waypoint_reached.emit(self)
		current_waypoint += 1
		return
	# Drive lead toward the waypoint
	var step: float = speed * delta
	var dir: Vector3 = d.normalized()
	# Lead move
	var lead_pos: Vector3 = lead.global_position
	lead_pos.x += dir.x * step
	lead_pos.z += dir.z * step
	lead_pos.y = _ground_y(lead_pos)
	lead.global_position = lead_pos
	_face_along(lead, dir, delta)
	# Trail
	for i in range(1, vehicles.size()):
		var prev: Node3D = vehicles[i - 1]
		var cur: Node3D = vehicles[i]
		if not is_instance_valid(prev) or not is_instance_valid(cur):
			continue
		var back: Vector3 = cur.global_position - prev.global_position
		back.y = 0.0
		if back.length() > spacing:
			var over: float = back.length() - spacing
			var np: Vector3 = cur.global_position - back.normalized() * over
			np.y = _ground_y(np)
			cur.global_position = np
			# A truck faces the way it is being pulled. Nothing here ever touched rotation, so
			# the whole column held its spawn yaw and CRABBED sideways through every bend.
			_face_along(cur, -back.normalized(), delta)


## Turn toward `dir` rather than snapping to it: a five-ton does not pivot on the spot, and an
## instant yaw change reads as the model teleporting its nose. Yaw uses the same atan2(x, z)
## ConvoySpawner seats vehicles with, so driving and spawning agree.
func _face_along(v: Node3D, dir: Vector3, delta: float) -> void:
	if v == null or dir.length() < 0.01:
		return
	var want: float = atan2(dir.x, dir.z)
	v.rotation.y = lerp_angle(v.rotation.y, want, minf(1.0, TURN_RATE * delta))


## Vehicle reports a hostile contact. Stops the convoy + emits the ambush signal.
func report_contact(_who: Node, _target_pos: Vector3) -> void:
	if _ambush_emitted:
		return
	_ambush_emitted = true
	stop_until_ms = _now_ms() + 8000.0
	if vehicles.size() > 0 and is_instance_valid(vehicles[0]):
		ambushed.emit(self, (vehicles[0] as Node3D).global_position)


## Resume driving after a stop. Resets the ambush latch so future contacts re-fire.
func resume() -> void:
	stop_until_ms = -1.0
	_ambush_emitted = false


## Terrain height under a point, or the point's own Y when there is no terrain
## (synthetic test worlds) - never silently zero.
func _ground_y(p: Vector3) -> float:
	if terrain == null:
		return p.y
	return terrain.get_height_at(p)


func _now_ms() -> float:
	return Time.get_ticks_msec()
