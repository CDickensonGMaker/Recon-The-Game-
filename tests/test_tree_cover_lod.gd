## test_tree_cover_lod.gd - near-solid-collidable / far-card veg LOD (bead: veg-LOD).
## Proves the Pillar-3 win headless: NEAR cover-giver instances carry a real trunk
## collider (you can hide behind them), FAR uses impostor cards, concealment species
## get NO collider, species+card meshes load from disk (also verifies the re-exported
## cards import), and teardown frees everything. Ratcheting - stays in the suite.
## Run: godot --headless --path . res://tests/test_tree_cover_lod.tscn
extends Node

const TreeCoverLayerScript := preload("res://terrain/vegetation/tree_cover_layer.gd")

# Cover-givers (get colliders + cards) and concealment (no collider). fallen_log_a is
# a cover-giver that is SOLID-ONLY (no card) - it must collide but have no far card.
const COVER := ["broadleaf_a", "bamboo_a", "jungle_palm_a1"]  # each has a card
const COVER_NOCARD := ["fallen_log_a"]                         # cover, solid-only
const CONCEAL := ["fern_a", "bush_a", "grass_tuft_a"]          # no collider, has card


func _ready() -> void:
	print("=== TREE COVER LOD (near solid+collider / far card) ===")
	var failures: int = 0

	var layer: Node3D = TreeCoverLayerScript.new()
	add_child(layer)
	var species: Array = COVER + COVER_NOCARD + CONCEAL
	layer.load_species(species)

	# Meshes must actually load from disk (proves the assets + imports are good).
	for n: String in species:
		if not layer._solid_mesh.has(n):
			printerr("FAIL: solid mesh did not load for %s" % n)
			failures += 1
	for n: String in (COVER + CONCEAL):
		if not layer._card_mesh.has(n):
			printerr("FAIL: card mesh did not load for %s (re-export/import broken?)" % n)
			failures += 1
	if layer._card_mesh.has("fallen_log_a"):
		printerr("FAIL: fallen_log_a is solid-only and must have no card")
		failures += 1

	# Scatter: 2 of each cover species (+ log), 2 of each concealment species.
	var scatter: Array = []
	var cover_instances: int = 0
	for n: String in (COVER + COVER_NOCARD):
		for i in 2:
			scatter.append({"name": n, "xf": Transform3D(Basis(), Vector3(i * 4.0, 0.0, 0.0))})
			cover_instances += 1
	for n: String in CONCEAL:
		for i in 2:
			scatter.append({"name": n, "xf": Transform3D(Basis(), Vector3(i * 4.0, 0.0, 20.0))})

	layer.generate_for_chunk(Vector2i(0, 0), scatter)

	# COVER EXISTS: one trunk collider per cover instance, none for concealment.
	var colliders: int = layer.collider_count()
	if colliders != cover_instances:
		printerr("FAIL: %d colliders, expected %d (one per cover instance, none for concealment)" % [colliders, cover_instances])
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

	# NEAR solids vs FAR cards: near MMI per species; far MMI only for species with a card.
	var near_mmi: int = 0
	var far_mmi: int = 0
	for c: Node in layer.get_children():
		if c is MultiMeshInstance3D:
			if (c as MultiMeshInstance3D).visibility_range_begin > 0.0:
				far_mmi += 1
			else:
				near_mmi += 1
	var species_used: int = COVER.size() + COVER_NOCARD.size() + CONCEAL.size()
	var species_with_card: int = COVER.size() + CONCEAL.size()
	if near_mmi != species_used:
		printerr("FAIL: %d near solid MMIs, expected %d (one per species)" % [near_mmi, species_used])
		failures += 1
	if far_mmi != species_with_card:
		printerr("FAIL: %d far card MMIs, expected %d (only species with a card)" % [far_mmi, species_with_card])
		failures += 1

	# TEARDOWN frees everything.
	layer.clear_chunk(Vector2i(0, 0))
	if layer.collider_count() != 0:
		printerr("FAIL: colliders survived clear_chunk (chunk-lifecycle leak)")
		failures += 1

	if failures == 0:
		print("  cover colliders=%d  near_solids=%d  far_cards=%d" % [cover_instances, near_mmi, far_mmi])
		print("PASS: near solids collide (cover exists), far uses cards, concealment has no collider")
	else:
		print("=== %d FAILURE(S) ===" % failures)
	get_tree().quit(1 if failures > 0 else 0)
