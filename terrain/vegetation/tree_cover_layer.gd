class_name TreeCoverLayer
extends Node3D

## Near-solid-collidable / far-impostor-card vegetation LOD (bead: veg-LOD).
## NEAR ring = the real 3D species SOLID as a MultiMesh, plus a cheap trunk collider
## per COVER instance so the player can physically hide behind it (Pillar 3). FAR ring
## = the species impostor CARD, no collision. Hard PS2 distance snap via visibility_range.
##
## This is the instancing+collision MECHANISM. Deriving the per-chunk scatter from the
## terrain grid (and retiring the merged-patch / procedural-billboard paths, fossil law)
## is the look-check-gated switchover - do NOT wire it live without eyes on the new look.

const SOLID_DIR := "res://assets/world/vegetation/"
const CARD_DIR := "res://assets/world/vegetation/cards/"

## Cover-givers ONLY: a solid a bullet stops and a body hides behind. Value = trunk
## collider radius (m). Everything NOT listed (grass, fern, vine, moss, rice, bush,
## sapling, liana) is CONCEALMENT - it cuts sight via the veg grid, never a collider.
const COVER_TRUNK := {
	"broadleaf_a": 0.30, "broadleaf_b": 0.30, "broadleaf_c": 0.30,
	"banana_a": 0.26, "banana_b": 0.26,
	"bamboo_a": 0.34, "bamboo_b": 0.34, "bamboo_c": 0.34,
	"jungle_palm_a1": 0.30, "jungle_palm_a2": 0.30, "jungle_palm_a3": 0.30,
	"jungle_palm_b1": 0.30, "jungle_palm_b2": 0.30, "jungle_palm_b3": 0.30,
	"fallen_log_a": 0.45, "fallen_log_b": 0.45,
	"felled_tree": 0.40, "felled_trunk": 0.36, "tree_stump": 0.34,
}

## World-geometry layer: bullets and the player capsule test this, so a trunk stops both.
const COVER_COLLISION_LAYER: int = 1
const TRUNK_HEIGHT: float = 3.0

## Deterministic per-chunk cover-collider cap. The AO is resident (ADR-013), so an uncapped
## trunk-per-instance would build 17k+ StaticBody3D across the map and blow Jolt's body limit.
## Capping PER CHUNK (not globally) keeps it deterministic - a global cap would drop bodies by
## chunk load order (ADR-010 violation). The player-keyed pooled ring (bead 503b) supersedes
## this cap with coherent near-player cover; until then this ships bounded cover without a crash.
const MAX_TRUNKS_PER_CHUNK: int = 150

@export var near_distance: float = 65.0   ## solid render + collision ring (arena parity)
@export var view_distance: float = 350.0  ## card render ring (fog transmittance <=10%)

## visibility_range is per-NODE against the transformed AABB (godot#79471 - the
## docs say origin and are wrong). Chunk-sized nodes quantize both rings by
## +/-181m - that WAS the invisible-jungle bug. 64m buckets bound the error to
## +/-45m without exploding the node count.
const BUCKET: float = 64.0
const RANGE_MARGIN: float = 8.0   ## hysteresis on the hard PS2 snap

var _solid_mesh: Dictionary = {}   ## name -> Mesh
var _card_mesh: Dictionary = {}    ## name -> Mesh (only species with a card)
var _chunk_nodes: Dictionary = {}  ## coord -> Array[Node] (MMIs + StaticBodies)
## coord -> PackedVector3Array of placed WORLD origins (probe truth; MultiMesh
## transform read-back is blind headless in this build)
var chunk_origins: Dictionary = {}
var _loaded: bool = false


func _ready() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--card-dist="):
			view_distance = maxf(near_distance, float(a.split("=")[1]))
			print("[TreeCover] --card-dist lever: view_distance=%.0f" % view_distance)


## Load the solid + card mesh for each species name (idempotent). A missing card is
## fine - deadfall/moss are solid-only (always near or culled).
func load_species(names: Array) -> void:
	for n: String in names:
		if not _solid_mesh.has(n):
			var sm: Mesh = _extract_mesh(SOLID_DIR + n + ".glb")
			if sm != null:
				_solid_mesh[n] = sm
		if not _card_mesh.has(n):
			var cm: Mesh = _extract_mesh(CARD_DIR + n + "_card.glb")
			if cm != null:
				_card_mesh[n] = cm
	_loaded = true


## scatter: Array of {name: String, xf: Transform3D}. Builds, for this chunk:
##   - one near-solid MultiMesh per species (visibility 0..near_distance)
##   - one far-card MultiMesh per species that has a card (near_distance..view_distance)
##   - one trunk StaticBody per COVER instance (bullet/body collision)
func generate_for_chunk(coord: Vector2i, scatter: Array) -> void:
	clear_chunk(coord)
	var groups: Dictionary = {}   ## [name, bucket_x, bucket_z] -> Array[Transform3D]
	var origins := PackedVector3Array()
	for e: Dictionary in scatter:
		var nm: String = String(e.get("name", ""))
		if not _solid_mesh.has(nm):
			continue
		var xf: Transform3D = e.get("xf", Transform3D.IDENTITY)
		var key: Array = [nm, int(floor(xf.origin.x / BUCKET)), int(floor(xf.origin.z / BUCKET))]
		if not groups.has(key):
			groups[key] = []
		(groups[key] as Array).append(xf)
		origins.append(xf.origin)

	var nodes: Array[Node] = []
	var trunks: int = 0  # per-chunk collider budget (see MAX_TRUNKS_PER_CHUNK)
	for key: Array in groups:
		var nm: String = key[0]
		var xforms: Array = groups[key]
		# Bucket node origin = member centroid, so the node's transformed AABB
		# (what visibility_range actually measures) hugs the real instances.
		var centroid := Vector3.ZERO
		for xf: Transform3D in xforms:
			centroid += xf.origin
		centroid /= float(xforms.size())
		var local: Array = []
		for xf: Transform3D in xforms:
			local.append(Transform3D(xf.basis, xf.origin - centroid))
		# NEAR: the real solid.
		nodes.append(_multimesh(_solid_mesh[nm], local, 0.0, near_distance, centroid, true))
		# FAR: the impostor card (if this species has one). Cards never cast.
		if _card_mesh.has(nm):
			nodes.append(_multimesh(_card_mesh[nm], local, near_distance, view_distance, centroid, false))
		# COVER: a trunk collider per instance (cover-givers only), capped per chunk.
		if COVER_TRUNK.has(nm):
			var r: float = float(COVER_TRUNK[nm])
			for xf: Transform3D in xforms:
				if trunks >= MAX_TRUNKS_PER_CHUNK:
					break
				nodes.append(_trunk_body(xf.origin, r))
				trunks += 1

	for node: Node in nodes:
		add_child(node)
	_chunk_nodes[coord] = nodes
	chunk_origins[coord] = origins


func clear_chunk(coord: Vector2i) -> void:
	chunk_origins.erase(coord)
	if not _chunk_nodes.has(coord):
		return
	for node: Node in _chunk_nodes[coord]:
		if is_instance_valid(node):
			node.queue_free()
	_chunk_nodes.erase(coord)


func clear_all() -> void:
	for coord: Vector2i in _chunk_nodes.keys():
		clear_chunk(coord)


## Colliders present in the near ring right now (cover exists). For the probe.
func collider_count() -> int:
	var n: int = 0
	for coord: Vector2i in _chunk_nodes:
		for node: Node in _chunk_nodes[coord]:
			if node is StaticBody3D:
				n += 1
	return n


func _multimesh(mesh: Mesh, xforms: Array, vis_begin: float, vis_end: float,
		origin: Vector3, solid: bool) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, xforms[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.position = origin
	if not solid:
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if vis_begin > 0.0:
		mmi.visibility_range_begin = vis_begin
		mmi.visibility_range_begin_margin = RANGE_MARGIN
	mmi.visibility_range_end = vis_end
	mmi.visibility_range_end_margin = RANGE_MARGIN
	# HARD PS2 snap (ADR-026), NOT a fade: VISIBILITY_RANGE_FADE_SELF alpha-dithers the mesh
	# across the fade margin, so trees near the near/card LOD boundaries render SEE-THROUGH.
	# That was the "opacity" - the arena instances raw GLBs with no range and reads solid.
	mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
	return mmi


func _trunk_body(pos: Vector3, radius: float) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = COVER_COLLISION_LAYER
	body.collision_mask = 0   ## static cover reacts to nothing; things test IT
	var shape := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = radius
	cyl.height = TRUNK_HEIGHT
	shape.shape = cyl
	body.add_child(shape)
	body.position = pos + Vector3(0.0, TRUNK_HEIGHT * 0.5, 0.0)
	return body


## First MeshInstance3D's mesh (with its own materials) from a GLB; null if absent.
func _extract_mesh(path: String) -> Mesh:
	if not ResourceLoader.exists(path):
		return null
	var packed: PackedScene = load(path) as PackedScene
	if packed == null:
		return null
	var root: Node = packed.instantiate()
	var mesh: Mesh = _first_mesh(root)
	root.queue_free()
	return mesh


func _first_mesh(node: Node) -> Mesh:
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		return (node as MeshInstance3D).mesh
	for c: Node in node.get_children():
		var m: Mesh = _first_mesh(c)
		if m != null:
			return m
	return null
