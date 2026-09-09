## test_tree_cover_lod.gd - the canopy is REAL 3D AT EVERY DISTANCE, and it collides.
##
## THIS TEST CHANGED SIDES on 2026-09-09. It used to REQUIRE that far-range vegetation be
## an impostor card ("far_mmi != species_with_card" was a FAILURE). The Summoner retired
## every 2D-made-3D terrain piece - "all 3d blender models only in game", barbwire the one
## exemption - so the thing this file used to protect is the thing it now forbids.
##
## What it proves headless:
##   1. Every species the layer draws loads a REAL model from disk.
##   2. NO mesh the layer draws is a plane in disguise. Triangle count cannot tell a model
##      from a card - a card can carry 184 triangles (that is how fallen_log_a passed for
##      years). NORMAL DISTRIBUTION can. See _flatness for the two measures and for the
##      trap that the first version of this gate walked straight into.
##   3. ONE MultiMeshInstance3D per species, none of them range-gated to start partway out -
##      i.e. there is no second, cheaper tier hiding behind a distance.
##   4. Cover-givers carry a real trunk collider (Pillar 3: you can hide behind them);
##      concealment species carry none; teardown frees everything.
## Ratcheting - stays in the suite.
## Run: godot --headless --path . res://tests/test_tree_cover_lod.tscn
extends Node

const TreeCoverLayerScript := preload("res://terrain/vegetation/tree_cover_layer.gd")

## Cover-givers get a trunk collider; concealment gets none. fallen_log_a is a cover-giver
## and is ALSO the known-flat one - see _flatness below, it is asserted flat on purpose so
## this test records the outstanding art debt instead of hiding it.
const COVER := ["broadleaf_a", "bamboo_a", "jungle_palm_a1"]
const COVER_KNOWN_FLAT := ["fallen_log_a"]
const CONCEAL := ["fern_a", "bush_a", "grass_tuft_a"]

## THE TWO MEASURES, and the measured gaps they sit in (tools/probe_far_ring_meshes.gd,
## 2026-09-09, all 27 live canopy species + the retired cards + the known-flat logs):
##
##   distinct FACINGS   live canopy 20..84 | fallen logs 7,8 | cards 1,2
##   dominant PLANE %   live canopy 5..33  | fallen logs 82,87 | cards 50..100
##
## Either one failing is enough to call a mesh flat - they catch different lies, and this
## is an OR, not an AND. AABB thinness is deliberately NOT a gate: it is reported for
## information and nothing more.
const MIN_FACINGS: int = 14
const DOMINANT_PLANE_MAX_PCT: float = 45.0


func _ready() -> void:
	print("=== TREE COVER: real 3D at every distance, and it collides ===")
	var failures: int = 0

	var layer: Node3D = TreeCoverLayerScript.new()
	add_child(layer)
	# Bodies exist only inside the pooled ring; anchor it on the scatter.
	layer.ring_center_override = Vector3.ZERO
	var species: Array = COVER + COVER_KNOWN_FLAT + CONCEAL
	layer.load_species(species)

	# 1. Every species loads a real model from disk (proves assets + imports are good).
	for n: String in species:
		if not layer._solid_mesh.has(n):
			printerr("FAIL: model did not load for %s" % n)
			failures += 1

	# 2. NO CARD MAY COME BACK. Every mesh the layer will draw must be volumetric.
	for n: String in (COVER + CONCEAL):
		var f: Dictionary = _flatness(layer._solid_mesh[n] as Mesh)
		if bool(f["flat"]):
			printerr("FAIL: '%s' is a PLANE, not a model - only %d distinct facings, %.1f%% of its area on one plane (aspect %.3f). A card must never be the far LOD (Summoner 2026-09-08)."
					% [n, int(f["facings"]), float(f["dominant_pct"]), float(f["thin"])])
			failures += 1
	# The recorded debt: this one IS flat and is still planted as cover with a 0.45 m
	# collider. If it ever comes back volumetric, this line fails and gets deleted.
	if layer._solid_mesh.has("fallen_log_a"):
		var lf: Dictionary = _flatness(layer._solid_mesh["fallen_log_a"] as Mesh)
		if not bool(lf["flat"]):
			printerr("FAIL(GOOD NEWS): fallen_log_a is no longer flat (%d facings, %.1f%%) - the owed volumetric log has landed. Move it into COVER and delete COVER_KNOWN_FLAT."
					% [int(lf["facings"]), float(lf["dominant_pct"])])
			failures += 1

	# Scatter: 2 of each cover species (+ log), 2 of each concealment species.
	var scatter: Array = []
	var cover_instances: int = 0
	for n: String in (COVER + COVER_KNOWN_FLAT):
		for i in 2:
			scatter.append({"name": n, "xf": Transform3D(Basis(), Vector3(i * 4.0, 0.0, 0.0))})
			cover_instances += 1
	for n: String in CONCEAL:
		for i in 2:
			scatter.append({"name": n, "xf": Transform3D(Basis(), Vector3(i * 4.0, 0.0, 20.0))})

	layer.generate_for_chunk(Vector2i(0, 0), scatter)

	# 4. COVER EXISTS: one trunk collider per cover instance, none for concealment.
	var colliders: int = layer.collider_count()
	if colliders != cover_instances:
		printerr("FAIL: %d colliders, expected %d (one per cover instance, none for concealment)"
				% [colliders, cover_instances])
		failures += 1

	# The collider is a real StaticBody with a Cylinder trunk shape (stops a bullet/body).
	var body: StaticBody3D = null
	for c: Node in layer.get_children():
		if c is StaticBody3D:
			body = c
			break
	if body == null:
		printerr("FAIL: no StaticBody3D cover body created")
		failures += 1
	else:
		var cs: CollisionShape3D = body.get_child(0) as CollisionShape3D
		if cs == null or not (cs.shape is CylinderShape3D):
			printerr("FAIL: cover body has no CylinderShape3D trunk")
			failures += 1
		if body.collision_layer == 0:
			printerr("FAIL: cover body is on no collision layer - nothing would hit it")
			failures += 1

	# 3. ONE tier. One MMI per species, and none of them begins partway out - a node with
	#    visibility_range_begin > 0 is by construction a second, cheaper thing swapped in
	#    at a distance, which is the whole pattern that was retired.
	var mmi_total: int = 0
	var range_gated: int = 0
	for c: Node in layer.get_children():
		var mmi := c as MultiMeshInstance3D
		if mmi == null:
			continue
		mmi_total += 1
		if mmi.visibility_range_begin > 0.0:
			range_gated += 1
	var species_used: int = species.size()
	if mmi_total != species_used:
		printerr("FAIL: %d MultiMeshInstance3D, expected %d (exactly one per species)"
				% [mmi_total, species_used])
		failures += 1
	if range_gated != 0:
		printerr("FAIL: %d MMI start partway out - a second LOD tier is back. The far ring is the SAME model (Summoner 2026-09-08)."
				% range_gated)
		failures += 1

	# TEARDOWN frees everything.
	layer.clear_chunk(Vector2i(0, 0))
	if layer.collider_count() != 0:
		printerr("FAIL: colliders survived clear_chunk (chunk-lifecycle leak)")
		failures += 1

	if failures == 0:
		print("  cover colliders=%d  canopy MMIs=%d  range-gated tiers=%d" % [
			cover_instances, mmi_total, range_gated])
		print("PASS: one real model per species at every distance, cover collides, no cards")
	else:
		print("=== %d FAILURE(S) ===" % failures)
	get_tree().quit(1 if failures > 0 else 0)


## Area-weighted facing histogram + AABB aspect. Returns {flat, facings, dominant_pct, thin}.
##
## READ THIS BEFORE LOOSENING ANYTHING. The first version of this gate was
## "dominant plane > 60% AND thinnest axis < 0.10", and it was BROKEN: a crossed quad -
## two perpendicular planes, the classic impostor - measures 50.0% dominant plane and an
## AABB aspect of 0.500. It fails BOTH halves and would have been waved through as a
## model. broadleaf_a_card is exactly that shape. The measure that actually separates a
## body from a picture is how many DIRECTIONS its surface faces: a crossed quad has 2, a
## flat log ribbon has 7-8, the cheapest real plant in the project has 20.
func _flatness(mesh: Mesh) -> Dictionary:
	var arrays: Array = mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var indexed: bool = idx.size() > 0
	var tris: int = (idx.size() / 3) if indexed else (verts.size() / 3)
	var facings: Array[Vector3] = []
	var area_by_facing: Array[float] = []
	var total_area: float = 0.0
	for t: int in tris:
		var i0: int = idx[t * 3] if indexed else t * 3
		var i1: int = idx[t * 3 + 1] if indexed else t * 3 + 1
		var i2: int = idx[t * 3 + 2] if indexed else t * 3 + 2
		var cross: Vector3 = (verts[i1] - verts[i0]).cross(verts[i2] - verts[i0])
		var area: float = cross.length() * 0.5
		if area <= 0.0000001:
			continue
		total_area += area
		var n: Vector3 = cross / (area * 2.0)
		var hit: int = -1
		for k: int in facings.size():
			# absf(): a plane and its own back face are ONE plane, not two facings. Without
			# this a double-sided quad scores 2 facings and reads as geometry.
			if absf(facings[k].dot(n)) > 0.985:
				hit = k
				break
		if hit < 0:
			facings.append(n)
			area_by_facing.append(area)
		else:
			area_by_facing[hit] += area
	var dominant: float = 0.0
	for a: float in area_by_facing:
		dominant = maxf(dominant, a)
	var dom_pct: float = (dominant / total_area * 100.0) if total_area > 0.0 else 100.0
	var s: Vector3 = mesh.get_aabb().size
	var longest: float = maxf(s.x, maxf(s.y, s.z))
	var thin: float = (minf(s.x, minf(s.y, s.z)) / longest) if longest > 0.0 else 0.0
	return {
		"flat": facings.size() < MIN_FACINGS or dom_pct > DOMINANT_PLANE_MAX_PCT,
		"facings": facings.size(),
		"dominant_pct": dom_pct,
		"thin": thin,
	}
