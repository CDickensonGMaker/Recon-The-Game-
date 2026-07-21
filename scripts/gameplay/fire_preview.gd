## fire_preview.gd - the footprint a fire mission will cover, drawn on the ground
## before the call goes out.
##
## The outline is built from FirePlan, so it is the ordnance's real reach and not
## a decorative ring. Every vertex is seated on the terrain, so on broken ground
## the shape bends over the hill instead of floating through it - which is the
## whole point: the far lip of a napalm strip on a reverse slope is exactly the
## part a player misjudges.
class_name FirePreview
extends Node3D

const RING_SEGMENTS: int = 48
const EDGE_STEP_M: float = 4.0
const GROUND_OFFSET: float = 0.15
const REBUILD_HZ: float = 15.0

const CLEAR_COLOR := Color(0.95, 0.72, 0.25)
const DANGER_COLOR := Color(0.95, 0.22, 0.15)

var terrain: TerrainManager = null

var _mesh: MeshInstance3D
var _im: ImmediateMesh
var _mat: StandardMaterial3D
var _accum: float = 0.0
var _pulse: float = 0.0

var _kind: String = ""
var _fo: int = 0
var _centre: Vector3 = Vector3.ZERO
var _dir: Vector3 = Vector3.FORWARD
var _danger: bool = false
var _live: bool = false


func _ready() -> void:
	_im = ImmediateMesh.new()
	_mesh = MeshInstance3D.new()
	_mesh.mesh = _im
	_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_mat = StandardMaterial3D.new()
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat.vertex_color_use_as_albedo = true
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	# The mark reads through the canopy - a footprint you cannot see behind a tree
	# is a footprint you place wrong.
	_mat.no_depth_test = true
	_mat.render_priority = 1
	_mesh.material_override = _mat
	add_child(_mesh)
	visible = false


## Point the preview at a placement. Cheap enough to call every frame - the mesh
## itself only rebuilds at REBUILD_HZ.
func show_plan(kind: String, centre: Vector3, dir: Vector3, fo: int, danger: bool) -> void:
	_kind = kind
	_centre = centre
	_dir = dir
	_fo = fo
	_danger = danger
	_live = true
	visible = true


func clear_plan() -> void:
	_live = false
	visible = false
	if _im != null:
		_im.clear_surfaces()


func _process(delta: float) -> void:
	if not _live or _im == null:
		return
	_pulse += delta
	_accum += delta
	if _accum < 1.0 / REBUILD_HZ:
		return
	_accum = 0.0
	_rebuild()


func _rebuild() -> void:
	_im.clear_surfaces()
	var fp: Dictionary = FirePlan.footprint(_kind, _fo)
	if fp.is_empty():
		return
	var col: Color = DANGER_COLOR if _danger else CLEAR_COLOR
	col.a = (0.55 + 0.45 * sin(_pulse * 6.0)) if _danger else 0.85
	var pts: PackedVector3Array = _outline(fp)
	if pts.size() < 2:
		return
	_im.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
	_im.surface_set_color(col)
	for p in pts:
		_im.surface_add_vertex(_seat(p))
	_im.surface_end()
	_cross(col, 2.0)


## The aim mark at the centre: a small cross, so a footprint the size of a village
## still tells you what point you actually placed.
func _cross(col: Color, arm: float) -> void:
	var side: Vector3 = _dir.cross(Vector3.UP).normalized()
	_im.surface_begin(Mesh.PRIMITIVE_LINES)
	_im.surface_set_color(col)
	_im.surface_add_vertex(_seat(_centre - _dir * arm))
	_im.surface_add_vertex(_seat(_centre + _dir * arm))
	_im.surface_add_vertex(_seat(_centre - side * arm))
	_im.surface_add_vertex(_seat(_centre + side * arm))
	_im.surface_end()


func _outline(fp: Dictionary) -> PackedVector3Array:
	match String(fp.shape):
		"circle":
			return _ellipse_points(float(fp.radius), float(fp.radius))
		"ellipse":
			return _ellipse_points(float(fp.along) * 0.5, float(fp.across) * 0.5)
		"rect":
			return _rect_points(float(fp.along) * 0.5, float(fp.across) * 0.5)
	return PackedVector3Array()


## `half_along` runs down the line of flight, `half_across` at right angles to it.
func _ellipse_points(half_along: float, half_across: float) -> PackedVector3Array:
	var side: Vector3 = _dir.cross(Vector3.UP).normalized()
	var out := PackedVector3Array()
	for i in range(RING_SEGMENTS + 1):
		var a: float = TAU * float(i) / float(RING_SEGMENTS)
		out.append(_centre + _dir * (cos(a) * half_along) + side * (sin(a) * half_across))
	return out


func _rect_points(half_along: float, half_across: float) -> PackedVector3Array:
	var side: Vector3 = _dir.cross(Vector3.UP).normalized()
	var corners: Array[Vector3] = [
		_centre + _dir * half_along + side * half_across,
		_centre - _dir * half_along + side * half_across,
		_centre - _dir * half_along - side * half_across,
		_centre + _dir * half_along - side * half_across,
	]
	var out := PackedVector3Array()
	for i in range(corners.size() + 1):
		var a: Vector3 = corners[i % corners.size()]
		var b: Vector3 = corners[(i + 1) % corners.size()]
		# Walk the edge rather than jumping corner to corner: a straight line between
		# two seated corners cuts through any ground that rises between them.
		var steps: int = maxi(1, int(a.distance_to(b) / EDGE_STEP_M))
		for s in range(steps):
			out.append(a.lerp(b, float(s) / float(steps)))
		if i == corners.size():
			break
	out.append(corners[0])
	return out


func _seat(p: Vector3) -> Vector3:
	var seated := p
	seated.y = (terrain.get_height_at(p) if terrain != null else p.y) + GROUND_OFFSET
	return to_local(seated) if is_inside_tree() else seated
