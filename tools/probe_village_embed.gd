## probe_village_embed.gd - IS THIS PROP/ANIMAL STUCK IN A WALL?
##
## Item 32: animals inside huts, tables intersecting walls, NPCs stuck in walls.
## site_planner.gd's _stable_animals (:574) and _furnish_interior (:617) place props
## straight off each building's own prop_*/home_* marker with no overlap rejection - a
## marker authored inside a wall puts the prop inside the wall. This asks the physics
## server directly whether the SPAWNED prop/animal node's own footprint overlaps solid
## world geometry, in the live stamped village - not the per-asset .glb in isolation,
## which cannot see two neighbouring buildings placed close enough to collide.
##
##   godot --headless --path . res://tools/probe_village_embed.tscn
extends Node

const CHECK_RADIUS_M: float = 0.22
const SAMPLE_UP_M: float = 0.15

func _ready() -> void:
	await get_tree().process_frame
	print("\n=== VILLAGE PROP/ANIMAL EMBED ===\n")
	var scene: PackedScene = load("res://scenes/levels/demo_game.tscn") as PackedScene
	add_child(scene.instantiate())
	var spins: int = 0
	while spins < 400 and get_tree().get_nodes_in_group(&"nav_baker").is_empty():
		spins += 1
		await get_tree().create_timer(0.1).timeout
	await get_tree().create_timer(6.0).timeout

	var space: PhysicsDirectSpaceState3D = get_viewport().world_3d.direct_space_state
	var sphere := SphereShape3D.new()
	sphere.radius = CHECK_RADIUS_M

	# find every AnimalRoutine-driven node and every prop the interior furnisher placed.
	# Both are plain Node3D added directly under a village site's node tree - walk the
	# whole tree and match by group/script rather than guessing a name convention.
	var stack: Array[Node] = [get_tree().root]
	var checked: int = 0
	var embedded: int = 0
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for c in n.get_children():
			stack.append(c)
		if not (n is Node3D):
			continue
		var nm: String = String(n.name)
		# Static village dressing only - NOT a civilian's carried prop (rice_basket_back,
		# rice_sickle, carry_pole, rice_bundle: probe_civilian.gd's PROPS dict), which rides a
		# moving NPC and will legitimately brush past geometry as it walks.
		var is_candidate: bool = (nm.begins_with("cooking_hearth") or nm.begins_with("produce_mat")
			or nm.begins_with("rice_basket_full") or nm.begins_with("flour_sacks")
			or nm.begins_with("veg_basket") or nm.begins_with("water_jars")
			or nm.begins_with("clay_bowls") or nm.begins_with("market_table")
			or nm.begins_with("firewood") or nm.begins_with("chicken_coop")
			or nm == "pig" or nm.begins_with("pig.") or nm.begins_with("pig2")
			or nm == "cow" or nm.begins_with("cow.") or nm.begins_with("cow2")
			or nm.begins_with("water_buffalo"))
		if not is_candidate:
			continue
		checked += 1
		var p: Vector3 = (n as Node3D).global_position + Vector3(0, SAMPLE_UP_M, 0)
		var q := PhysicsShapeQueryParameters3D.new()
		q.shape = sphere
		q.transform = Transform3D(Basis.IDENTITY, p)
		q.collision_mask = 1
		var hits: Array[Dictionary] = space.intersect_shape(q, 4)
		var names: Array = []
		for h in hits:
			var col := h.get("collider") as Node
			if col == null:
				continue
			var pn: String = String(col.get_parent().name) if col.get_parent() != null else "-"
			if pn.begins_with("Chunk_") or String(col.name) == "RaycastCollision":
				continue  # the ground itself is not an embed
			names.append("%s/%s" % [pn, col.name])
		if not names.is_empty():
			embedded += 1
			print("  EMBEDDED  %-28s at (%7.1f,%6.1f,%7.1f)  inside: %s" % [
				nm.left(28), p.x, p.y, p.z, ", ".join(names)])

	print("\n%d of %d village props/animals embedded in solid geometry" % [embedded, checked])
	get_tree().quit(1 if embedded > 0 else 0)
