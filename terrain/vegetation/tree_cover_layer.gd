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

@export var near_distance: float = 46.0   ## solid render + collision ring
@export var view_distance: float = 80.0   ## card render ring
@export var fade_margin: float = 12.0

var _solid_mesh: Dictionary = {}   ## name -> Mesh
var _card_mesh: Dictionary = {}    ## name -> Mesh (only species with a card)
var _chunk_nodes: Dictionary = {}  ## coord -> Array[Node] (MMIs + StaticBodies)
var _loaded: bool = false


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
	var by_name: Dictionary = {}   ## name -> Array[Transform3D]
	for e: Dictionary in scatter:
		var nm: String = String(e.get("name", ""))
		if not _solid_mesh.has(nm):
			continue
		if not by_name.has(nm):
			by_name[nm] = []
		by_name[nm].append(e.get("xf", Transform3D.IDENTITY))

	var nodes: Array[Node] = []
	var trunks: int = 0  # per-chunk collider budget (see MAX_TRUNKS_PER_CHUNK)
	for nm: String in by_name:
		var xforms: Array = by_name[nm]
		# NEAR: the real solid.
		nodes.append(_multimesh(_solid_mesh[nm], xforms, 0.0, near_distance))
		# FAR: the impostor card (if this species has one).
		if _card_mesh.has(nm):
			nodes.append(_multimesh(_card_mesh[nm], xforms, near_distance, view_distance))
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


func clear_chunk(coord: Vector2i) -> void:
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


func _multimesh(mesh: Mesh, xforms: Array, vis_begin: float, vis_end: float) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, xforms[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	if vis_begin > 0.0:
		mmi.visibility_range_begin = vis_begin
		mmi.visibility_range_begin_margin = fade_margin
	mmi.visibility_range_end = vis_end
	mmi.visibility_range_end_margin = fade_margin
	mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
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
