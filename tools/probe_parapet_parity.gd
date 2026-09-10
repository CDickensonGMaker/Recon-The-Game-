## probe_parapet_parity.gd - THE WIRE, BEFORE AND AFTER THE KIT RE-SKIN (ADR-043 §2 P4).
##
## Run: godot --headless --path . res://tools/probe_parapet_parity.tscn
##
## His ruling, 2026-09-10: *"re-skin the perimeter with the kit wall."* The bake's 80
## `fb_sbg_seg_*` meshes come out of the monolith and 224 `fb_sandbag_heavy` parts go in from
## `data/site_plans/fsb_main_parapet.json`. That is a swap of the ONE structure the siege
## measures itself against, so it gets measured, not asserted.
##
## THE SAME PROBE RUNS ON BOTH STATES. Stash the change and run it for the before; run it again
## after. Every number below is a comparison, and the ones that must not move say so.
##
##   1. THE GROUP     `fsb_parapet` is the siege's only runtime map of where the wire is
##                    (`siege_director.gd:427,679`). Empty group = no perimeter, no breach.
##   2. THE RING      radius span and angular coverage from the compound centre. A re-tile
##                    that moved the wire, or left a hole in it, shows up here and nowhere
##                    else - a count can be right while the shape is wrong.
##   3. THE STEEL     every wall on the blast bus, with a shape, kind `sandbag_wall`, 140 hp.
##                    `sapper_charge.gd:79` targets by KIND, so the kind is the contract.
##   4. THE BALLISTICS every collider in a ballistics group. ADR-042's bug class fails by
##                    DEFAULT: an untagged collider is `hard_surface` and nothing says so.
extends Node

const SEED_VAL: int = 4242
## The wire is a closed ring around the compound. Every 10 degree sector must contain at least
## one wall or there is a gap a man walks through.
const SECTORS: int = 36
## The gateway the bake itself carried, measured on the pre-migration export by
## tools/extract_parapet_plan.py's own geometry: 19.4 m at bearing 149. The gate house sits in
## it; it is the base's entrance, not a defect. Anything WIDER is a hole the re-tile opened.
const BASELINE_HOLE_M: float = 19.4
const HOLE_TOL_M: float = 1.0

var _failures: int = 0


func _fail(msg: String) -> void:
	print("FAIL: ", msg)
	_failures += 1


func _ready() -> void:
	var world_scene: PackedScene = load("res://scenes/levels/game_world.tscn")
	var world: GameWorld = world_scene.instantiate()
	world.mission_seed = SEED_VAL
	world.spawn_player_on_ready = false
	add_child(world)
	var elapsed: float = 0.0
	while not world.is_world_ready and elapsed < 240.0:
		await get_tree().create_timer(0.5).timeout
		elapsed += 0.5
	if not world.is_world_ready:
		_fail("world timeout")
		_finish(world)
		return

	var rng := RandomNumberGenerator.new()
	rng.seed = SEED_VAL
	var planner := SitePlanner.new(world.gameplay_grid, world.terrain_manager,
		world.vegetation_manager, world)
	var centre: Vector3 = planner.plan_firebase_main_center(rng)
	var fsb: Dictionary = planner.place_firebase_main(centre)
	await get_tree().physics_frame
	if fsb.is_empty():
		_fail("place_firebase_main returned nothing")
		_finish(world)
		return

	# 1. THE GROUP.
	var wire: Array[Node] = get_tree().get_nodes_in_group(SitePlanner.FSB_PARAPET_GROUP)
	print("[WIRE] %d member(s) in group '%s'" % [wire.size(), SitePlanner.FSB_PARAPET_GROUP])
	if wire.is_empty():
		_fail("the wire group is EMPTY - the siege has no perimeter to measure or breach")
		_finish(world)
		return

	# 2. THE RING. Measured from the compound centre, which is where SiegeDirector measures
	# from, not from the site centre the planner was handed.
	var cx: float = 0.0
	var cz: float = 0.0
	for n_any in wire:
		var n3 := n_any as Node3D
		cx += n3.global_position.x
		cz += n3.global_position.z
	cx /= float(wire.size())
	cz /= float(wire.size())
	var lo: float = 1.0e9
	var hi: float = -1.0e9
	var filled: Dictionary = {}
	var y_lo: float = 1.0e9
	var y_hi: float = -1.0e9
	for n_any in wire:
		var n3 := n_any as Node3D
		var dx: float = n3.global_position.x - cx
		var dz: float = n3.global_position.z - cz
		var r: float = Vector2(dx, dz).length()
		lo = minf(lo, r)
		hi = maxf(hi, r)
		y_lo = minf(y_lo, n3.global_position.y)
		y_hi = maxf(y_hi, n3.global_position.y)
		var sector: int = int(floor((atan2(dz, dx) + PI) / TAU * float(SECTORS))) % SECTORS
		filled[sector] = true
	var gaps: Array[int] = []
	for k in range(SECTORS):
		if not filled.has(k):
			gaps.append(k)
	print("[WIRE] ring: %.1f-%.1f m from the compound centre, height span %.2f m" % [lo, hi, y_hi - y_lo])
	print("[WIRE] angular coverage: %d of %d sectors filled%s"
		% [SECTORS - gaps.size(), SECTORS, "" if gaps.is_empty() else (", EMPTY: %s" % str(gaps))])

	# THE HOLE, IN METRES, and it is measured off the walls' SPANS rather than their positions.
	#
	# A sector census cannot do this job and the migration proved it: the bake's 6 m segments
	# and the kit's 2.28 m walls put their CENTRES in different sectors while covering exactly
	# the same ground, so the census reported a sector lost that had never been covered by
	# anything but a wall's middle. Measuring centre-to-centre also flattered the bake by half
	# a segment at each end - my own first pass read the gateway 4.3 m wider than it is.
	#
	# Each wall covers an arc; merge them; the largest surviving hole is the gateway. The bake
	# ring measured 19.4 m there before this migration, which is what BASELINE_HOLE_M is.
	# THE CORNERS, NOT A GUESSED AXIS. `_adopt_structure` sets the Destructible's POSITION and
	# leaves its basis at identity - the rotation rides on the MeshInstance3D reparented under
	# it - so reading the body's own basis.x would have every wall in the base running along
	# world +X. Transform the mesh's local AABB corners instead: for a box wall those are its
	# real corners, so the arc is exact and no axis has to be assumed.
	var arcs: Array = []
	for n_any in wire:
		var mesh: MeshInstance3D = null
		for c in (n_any as Node).get_children():
			if c is MeshInstance3D:
				mesh = c as MeshInstance3D
				break
		var a_lo: float = 0.0
		var a_hi: float = 0.0
		if mesh == null:
			var p3 := n_any as Node3D
			a_lo = atan2(p3.global_position.z - cz, p3.global_position.x - cx)
			a_hi = a_lo
		else:
			var box: AABB = mesh.get_aabb()
			var first: bool = true
			var base_a: float = 0.0
			for i in range(8):
				var w: Vector3 = mesh.global_transform * (box.position + box.size * Vector3(
					float(i & 1), float((i >> 1) & 1), float((i >> 2) & 1)))
				var a: float = atan2(w.z - cz, w.x - cx)
				if first:
					base_a = a
					a_lo = a
					a_hi = a
					first = false
					continue
				# Unwrap onto the first corner's branch, or a wall straddling +/-PI reports an
				# arc that wraps the whole base and swallows every hole in it.
				a = base_a + wrapf(a - base_a, -PI, PI)
				a_lo = minf(a_lo, a)
				a_hi = maxf(a_hi, a)
		arcs.append([a_lo, a_hi])
	arcs.sort_custom(func(u, v): return u[0] < v[0])
	var merged: Array = [[arcs[0][0], arcs[0][1]]]
	for a in arcs:
		if a[0] <= float(merged[-1][1]) + 1.0e-6:
			merged[-1][1] = maxf(float(merged[-1][1]), a[1])
		else:
			merged.append([a[0], a[1]])
	var biggest: float = 0.0
	var at: float = 0.0
	for i in range(merged.size()):
		var nxt: float = float(merged[(i + 1) % merged.size()][0])
		if i == merged.size() - 1:
			nxt += TAU
		var d: float = nxt - float(merged[i][1])
		if d > biggest:
			biggest = d
			at = float(merged[i][1])
	var mean_r: float = (lo + hi) * 0.5
	print("[WIRE] largest hole: %.1f deg (~%.1f m at r=%.0f) at bearing %.0f deg - the gateway"
		% [rad_to_deg(biggest), biggest * mean_r, mean_r, rad_to_deg(at)])
	if biggest * mean_r > BASELINE_HOLE_M + HOLE_TOL_M:
		_fail("the wire's largest hole is %.1f m, baseline %.1f m - the re-tile opened the "
			% [biggest * mean_r, BASELINE_HOLE_M] + "perimeter and nothing else would say so")

	# 3. THE STEEL. Kind is the contract sapper_charge.gd:79 prioritises on.
	var kinds: Dictionary = {}
	var no_shape: int = 0
	var hp_lo: int = 1 << 30
	var hp_hi: int = 0
	for n_any in wire:
		var d := n_any as Destructible
		if d == null:
			_fail("a wire member is not a Destructible: %s" % str(n_any))
			continue
		kinds[d.kind] = int(kinds.get(d.kind, 0)) + 1
		hp_lo = mini(hp_lo, d.hp)
		hp_hi = maxi(hp_hi, d.hp)
		var shapes: int = 0
		for c in d.get_children():
			if c is CollisionShape3D:
				shapes += 1
		if shapes == 0:
			no_shape += 1
	print("[WIRE] kinds %s, hp %d..%d, %d with no collision shape" % [str(kinds), hp_lo, hp_hi, no_shape])
	if no_shape > 0:
		_fail("%d wire member(s) have no collision shape - nothing can hit them" % no_shape)
	if not kinds.has("sandbag_wall"):
		_fail("no wire member carries kind 'sandbag_wall' - sapper_charge.gd:79 prioritises by "
			+ "KIND, so the sappers will not target the wire")

	# 4. THE BALLISTICS. An untagged collider defaults to hard_surface with no error.
	var untagged: int = 0
	for n_any in wire:
		var body := n_any as CollisionObject3D
		if body == null:
			continue
		if not (body.is_in_group(&"hard_surface") or body.is_in_group(&"soft_cover")):
			untagged += 1
	print("[WIRE] %d member(s) carry no ballistics group" % untagged)
	if untagged > 0:
		_fail("%d wire member(s) have no ballistics group - they default to hard_surface and "
			% untagged + "nothing raised an error (ADR-042)")

	# THE LEFTOVERS. After the migration the bake must carry NO parapet mesh: one left behind is
	# a wall that is drawn, stops bullets through its -colonly twin, and can never be destroyed.
	var strays: int = 0
	var stack: Array[Node] = [world]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for c in n.get_children():
			stack.append(c)
		if (n is MeshInstance3D) and String(n.name).begins_with("fb_sbg_seg_"):
			strays += 1
	print("[WIRE] %d 'fb_sbg_seg_' mesh(es) left in the bake" % strays)

	_finish(world)


func _finish(world: Node) -> void:
	if _failures == 0:
		print("probe_parapet_parity: PASS")
	else:
		print("probe_parapet_parity: %d FAILURE(S)" % _failures)
	if world != null and is_instance_valid(world):
		world.queue_free()
	get_tree().quit(1 if _failures > 0 else 0)
