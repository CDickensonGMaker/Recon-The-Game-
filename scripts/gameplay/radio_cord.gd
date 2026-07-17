class_name RadioCord
extends MeshInstance3D
## The PRC-25's handset cord, drawn every frame between the radio and whoever is
## holding the handset.
##
## THERE IS NO STATIC CORD MESH - it is always procedural, stowed or held, so the
## two cases can never disagree with each other.
##
## It is a spline through THREE points: CordPort (radio, Spine2) -> CordGuide
## (LeftShoulder) -> the handset. The guide is NOT decoration: a straight line
## from a radio on his BACK to a hand in FRONT of him passes clean through his
## chest. The markers are bone-attached, so the routing survives turning and death.
##
## Sag is proportional to slack, which makes the cord the player's TENSION READOUT
## with no UI at all.

## Where the cord leaves the radio. Bone-attached to Spine2 on the RTO.
@export var port: Node3D
## The shoulder the cord runs over. Bone-attached to LeftShoulder on the RTO.
@export var guide: Node3D
## The handset's cord boss - on the RTO when stowed, on the player's hand when held.
@export var endpoint: Node3D

## Full stretch, in metres. Past this the handset is ripped out of the player's hand.
@export var cord_length: float = 3.0
## How far the slack cord bellies downward at maximum slack.
@export var max_sag: float = 0.35
@export var radius: float = 0.006
@export_range(3, 8) var sides: int = 5
@export_range(6, 24) var segments: int = 14

var _mesh: ImmediateMesh = null
var _last_a: Vector3 = Vector3.INF
var _last_b: Vector3 = Vector3.INF
var _last_g: Vector3 = Vector3.INF


func _ready() -> void:
	_mesh = ImmediateMesh.new()
	mesh = _mesh
	# the cord is thin and always near the camera - it must not be culled by its own AABB
	custom_aabb = AABB(Vector3(-8, -8, -8), Vector3(16, 16, 16))


## How stretched the cord is, 0 (slack) to 1 (dead taut). Read by RadioHandset.
func tension() -> float:
	if port == null or endpoint == null:
		return 0.0
	var d: float = _path_length()
	return clampf(d / maxf(cord_length, 0.001), 0.0, 1.0)


func _path_length() -> float:
	if port == null or endpoint == null:
		return 0.0
	var a: Vector3 = port.global_position
	var b: Vector3 = endpoint.global_position
	if guide == null:
		return a.distance_to(b)
	var g: Vector3 = guide.global_position
	return a.distance_to(g) + g.distance_to(b)


func _process(_delta: float) -> void:
	if port == null or endpoint == null:
		visible = false
		return
	visible = true
	var a: Vector3 = port.global_position
	var b: Vector3 = endpoint.global_position
	var g: Vector3 = guide.global_position if guide != null else (a + b) * 0.5

	# nothing moved -> do not rebuild the mesh. An RTO standing still costs nothing.
	if a.is_equal_approx(_last_a) and b.is_equal_approx(_last_b) and g.is_equal_approx(_last_g):
		return
	_last_a = a
	_last_b = b
	_last_g = g
	_rebuild(a, g, b)


func _rebuild(a: Vector3, g: Vector3, b: Vector3) -> void:
	# slack = how much cord is NOT being used. All of it becomes sag.
	var used: float = a.distance_to(g) + g.distance_to(b)
	var slack: float = clampf(1.0 - used / maxf(cord_length, 0.001), 0.0, 1.0)
	var sag: float = max_sag * slack

	var pts: PackedVector3Array = PackedVector3Array()
	for i in range(segments + 1):
		var t: float = float(i) / float(segments)
		# quadratic Bezier through the shoulder guide - the guide PULLS the curve over
		# his shoulder instead of letting it cut through his chest
		var p: Vector3 = a.lerp(g, t).lerp(g.lerp(b, t), t)
		# catenary-ish belly, biggest in the middle, zero at both anchors
		p.y -= sag * sin(t * PI)
		pts.append(p)

	_mesh.clear_surfaces()
	_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES, get_active_material(0))
	for i in range(segments):
		_ring_quad(pts, i)
	_mesh.surface_end()


func _ring_quad(pts: PackedVector3Array, i: int) -> void:
	var p0: Vector3 = pts[i]
	var p1: Vector3 = pts[i + 1]
	var dir: Vector3 = (p1 - p0)
	if dir.length_squared() < 1e-8:
		return
	dir = dir.normalized()
	var up: Vector3 = Vector3.UP
	if absf(dir.dot(up)) > 0.99:
		up = Vector3.RIGHT
	var side: Vector3 = dir.cross(up).normalized()
	var other: Vector3 = dir.cross(side).normalized()

	for s in range(sides):
		var a0: float = TAU * float(s) / float(sides)
		var a1: float = TAU * float(s + 1) / float(sides)
		var o0: Vector3 = (side * cos(a0) + other * sin(a0)) * radius
		var o1: Vector3 = (side * cos(a1) + other * sin(a1)) * radius
		var v00: Vector3 = p0 + o0
		var v01: Vector3 = p0 + o1
		var v10: Vector3 = p1 + o0
		var v11: Vector3 = p1 + o1
		var n0: Vector3 = o0.normalized()
		var n1: Vector3 = o1.normalized()
		_mesh.surface_set_normal(n0); _mesh.surface_add_vertex(to_local(v00))
		_mesh.surface_set_normal(n1); _mesh.surface_add_vertex(to_local(v01))
		_mesh.surface_set_normal(n1); _mesh.surface_add_vertex(to_local(v11))
		_mesh.surface_set_normal(n0); _mesh.surface_add_vertex(to_local(v00))
		_mesh.surface_set_normal(n1); _mesh.surface_add_vertex(to_local(v11))
		_mesh.surface_set_normal(n0); _mesh.surface_add_vertex(to_local(v10))
