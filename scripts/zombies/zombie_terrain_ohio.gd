## zombie_terrain_ohio.gd - the ground the lot sits on.
##
## OHIO, NOT VIETNAM. Low rolling farmland with soft rises and long sightlines -
## the opposite of the project's usual terrain, which is why this does NOT use
## TerrainManager. That engine is built for 3000 m maps with hydrology and jungle
## zoning (terrain_manager.gd:18-28); pointing it at a 150 m rust-belt lot would
## mean fighting its generator for every feature it wants to add and this map
## does not want.
##
## Built from a 25 x 25 height grid, which is his "small 25x25 terrain area".
##
## THE COMPOUND PAD STAYS FLAT, ON PURPOSE. Every wall, gate, breach and prop in
## ZombieMapLot is authored at y=0. Rolling ground underneath them would leave
## walls floating at the crests and buried in the dips. So relief is pushed OUT
## to the apron - the ground the horde crosses to reach you - and fades to dead
## flat before it reaches the wire. You get Ohio on the approach and a buildable
## lot in the middle.
class_name ZombieTerrainOhio
extends Node3D

## Height samples across the ground. His number.
const GRID: int = 25

## Ohio relief is SMALL. Anything taller reads as hills, and hills are not Ohio -
## they also start occluding the horde, which this mode cannot afford at night.
const RELIEF_M: float = 1.9
## Long, low undulation. Two octaves only: a big roll and a gentle break-up.
const OCTAVE_LOW: float = 2.4
const OCTAVE_HIGH: float = 6.0
const HIGH_MIX: float = 0.28

## Where the flattening starts and ends, as a margin outside the compound rect.
## Inside the compound: dead flat. Beyond FADE_OUT: full relief.
const FADE_IN: float = 2.0
const FADE_OUT: float = 26.0

const ASPHALT := Color(0.16, 0.16, 0.15)
const DIRT := Color(0.20, 0.17, 0.12)
const GRASS := Color(0.15, 0.17, 0.11)

var _rng := RandomNumberGenerator.new()
var _heights: PackedFloat32Array = PackedFloat32Array()
var _size := Vector2(150.0, 120.0)
var _pad := Rect2(25, 20, 100, 76)


## `size` is the whole ground; `pad` is the compound rect that must stay flat.
func build(size: Vector2, pad: Rect2, seed_value: int = 20260805) -> void:
	_size = size
	_pad = pad
	_rng.seed = seed_value
	_sample()
	_build_mesh()


func _sample() -> void:
	_heights.resize(GRID * GRID)
	# Phase offsets so the same seed gives the same field but different seeds do
	# not merely slide one hill around.
	var pa: float = _rng.randf_range(0.0, TAU)
	var pb: float = _rng.randf_range(0.0, TAU)
	for j in GRID:
		for i in GRID:
			var u: float = float(i) / float(GRID - 1)
			var v: float = float(j) / float(GRID - 1)
			var low: float = sin(u * OCTAVE_LOW + pa) * cos(v * OCTAVE_LOW * 0.8 + pb)
			var high: float = sin(u * OCTAVE_HIGH + pb) * cos(v * OCTAVE_HIGH + pa)
			var h: float = (low * (1.0 - HIGH_MIX) + high * HIGH_MIX) * RELIEF_M
			_heights[j * GRID + i] = h * _flatten_weight(u, v)


## 0 inside the compound (dead flat), 1 well outside it (full relief).
func _flatten_weight(u: float, v: float) -> float:
	var x: float = u * _size.x
	var z: float = v * _size.y
	# Distance OUTSIDE the pad rect; zero anywhere within it.
	var dx: float = maxf(maxf(_pad.position.x - x, x - (_pad.position.x + _pad.size.x)), 0.0)
	var dz: float = maxf(maxf(_pad.position.y - z, z - (_pad.position.y + _pad.size.y)), 0.0)
	var d: float = sqrt(dx * dx + dz * dz)
	return smoothstep(FADE_IN, FADE_OUT, d)


func height_at(world: Vector3) -> float:
	var u: float = clampf(world.x / _size.x, 0.0, 1.0) * float(GRID - 1)
	var v: float = clampf(world.z / _size.y, 0.0, 1.0) * float(GRID - 1)
	var i: int = clampi(int(u), 0, GRID - 2)
	var j: int = clampi(int(v), 0, GRID - 2)
	var tu: float = u - float(i)
	var tv: float = v - float(j)
	var h00: float = _heights[j * GRID + i]
	var h10: float = _heights[j * GRID + i + 1]
	var h01: float = _heights[(j + 1) * GRID + i]
	var h11: float = _heights[(j + 1) * GRID + i + 1]
	return lerpf(lerpf(h00, h10, tu), lerpf(h01, h11, tu), tv)


func _build_mesh() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var step := Vector2(_size.x / float(GRID - 1), _size.y / float(GRID - 1))

	for j in GRID - 1:
		for i in GRID - 1:
			var p00 := _vert(i, j, step)
			var p10 := _vert(i + 1, j, step)
			var p01 := _vert(i, j + 1, step)
			var p11 := _vert(i + 1, j + 1, step)
			# WINDING MATTERS: a down-facing trimesh floor is walked straight
			# through. This order gives +Y normals; do not "tidy" it.
			_tri(st, p00, p01, p10)
			_tri(st, p10, p01, p11)

	st.generate_normals()
	var mesh: ArrayMesh = st.commit()

	var mi := MeshInstance3D.new()
	mi.name = "OhioGroundMesh"
	mi.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 1.0
	mi.material_override = mat

	var body := StaticBody3D.new()
	body.name = "OhioGround"
	body.collision_layer = 1
	body.collision_mask = 0
	body.add_to_group("nav_source")
	body.add_child(mi)
	var cs := CollisionShape3D.new()
	cs.shape = mesh.create_trimesh_shape()
	body.add_child(cs)
	add_child(body)
	var aabb: AABB = mesh.get_aabb()
	print("[OHIO] ground: %d surface(s), %d verts, aabb %.0fx%.0f, y %.2f..%.2f"
		% [mesh.get_surface_count(), mesh.surface_get_array_len(0),
		aabb.size.x, aabb.size.z, aabb.position.y, aabb.position.y + aabb.size.y])


func _vert(i: int, j: int, step: Vector2) -> Dictionary:
	var x: float = float(i) * step.x
	var z: float = float(j) * step.y
	var h: float = _heights[j * GRID + i]
	# Asphalt on the flat pad, dirt on the shoulder, grass out in the field -
	# the colour follows the SAME weight that flattens the ground, so the lot
	# always looks like a lot and the approach always looks like a field.
	var w: float = _flatten_weight(float(i) / float(GRID - 1), float(j) / float(GRID - 1))
	var col: Color = ASPHALT.lerp(DIRT, minf(1.0, w * 2.0)).lerp(GRASS, w)
	return {"p": Vector3(x, h, z), "c": col}


func _tri(st: SurfaceTool, a: Dictionary, b: Dictionary, c: Dictionary) -> void:
	for v in [a, b, c]:
		st.set_color(v["c"])
		st.add_vertex(v["p"])
