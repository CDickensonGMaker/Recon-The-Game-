## probe_firebase_site.gd - STAMP THE FSB KIT ALPHA PLAN AND MEASURE IT (ADR-043, ADR-015).
##
## Run: godot --headless --path . res://tools/probe_firebase_site.tscn
##      set PROBE_PLAN to stamp a different plan out of data/site_plans/.
##
## Four questions, one boot, numbers for each. It exists because "it looks fine" closes
## nothing (ADR-015), and because every defect this kit was built to kill fails by DEFAULT:
## an unrecognised part is bulletproof, an unwired collider is walk-through, a garrison with
## an unmet demand is an empty base, and none of them raises an error.
##
##   1. GROUND    relief of the terrain under every placed part, and across the pad core.
##   2. STEEL     every part's colliders and shapes, its ballistics group, its Destructible.
##   3. MEN       posts, occupations, unmet demands, and the gate's perimeter demand.
##   4. WALK      a baked navmesh, a path from outside the wire, and the same path after the
##                gate tower is blown - which is the only hole a sapper can make in this
##                perimeter and therefore the measurement that says the gate means something.
extends Node

## Shared with tools/shot_firebase_site.gd so the numbers below and the pictures it takes
## describe the SAME hill.
const SitePick = preload("res://tools/firebase_site_pick.gd")

const SEED_VAL: int = 4242
const SITE_RADIUS: float = 40.0
const PAD_SAMPLES: int = 15
const CORE_FRACTION: float = 0.9
## His ask was that placing a part "plants a flat area for the building to exist". Anything
## looser than this is not a flat area, it is a gentler hill.
const FLAT_TOL_M: float = 0.05
## Footprint radius each part's ground is sampled over. Measured off the GLBs.
const FOOT_R: Dictionary = {
	"fb_bunker_fighting": 2.1, "fb_bunker_mg": 2.7, "fb_FoxholeSandbags": 1.2,
	"fb_sandbag_heavy": 1.2, "fb_sandbag_light": 1.1, "fb_gate_assembly": 5.5,
	"fb_emplacement_m101": 6.7,
}

var _failures: int = 0
var _world: GameWorld = null
var _planner: SitePlanner = null
var _nav: NavBaker = null


func _fail(msg: String) -> void:
	print("FAIL: ", msg)
	_failures += 1


func _ready() -> void:
	var plan_name: String = OS.get_environment("PROBE_PLAN")
	if plan_name == "":
		plan_name = "fsb_kit_alpha"
	var plan: SitePlan = SitePlan.load_from(plan_name)
	if plan == null:
		_fail("no plan '%s' in %s" % [plan_name, SitePlan.DIR])
		_finish()
		return
	var reg: KitRegistry = KitRegistry.load_kit()
	var why: String = plan.validate(reg)
	if why != "":
		_fail("plan is not fit to stamp: %s" % why)
		_finish()
		return
	print("[SITE] plan '%s': %d part(s), pad r=%.0f strength=%.2f shoulder=%.0f"
		% [plan.plan_name, plan.parts.size(), plan.flatten_radius, plan.flatten_strength,
			plan.flatten_shoulder])

	var world_scene: PackedScene = load("res://scenes/levels/game_world.tscn")
	_world = world_scene.instantiate()
	_world.mission_seed = SEED_VAL
	_world.spawn_player_on_ready = false
	add_child(_world)
	var waited: float = 0.0
	while not _world.is_world_ready and waited < 240.0:
		await get_tree().create_timer(0.5).timeout
		waited += 0.5
	if not _world.is_world_ready:
		_fail("world timeout")
		_finish()
		return

	var rng := RandomNumberGenerator.new()
	rng.seed = SEED_VAL
	_planner = SitePlanner.new(_world.gameplay_grid, _world.terrain_manager,
		_world.vegetation_manager, _world)
	var pick: Dictionary = SitePick.pick(_planner, _world.terrain_manager, rng, SITE_RADIUS,
		plan.flatten_radius)
	var centre: Vector3 = pick.get("centre", Vector3.ZERO)
	print("[SITE] hilltop pick: %+.2f m above the ground 54 m out, %.2f m of relief across "
		% [float(pick.get("prominence", 0.0)), float(pick.get("relief", 0.0))]
		+ "the pad before levelling")
	if centre == Vector3.ZERO:
		_fail("no site with a %.0f m footprint on this map" % SITE_RADIUS)
		_finish()
		return
	print("[SITE] centre %s (seed %d) - the render pass uses the same seed and lands here too"
		% [str(centre.round()), SEED_VAL])

	var before: Array = _relief(centre, plan.flatten_radius)
	print("[GROUND] BEFORE: min %.2f max %.2f RELIEF %.2f m across the %.0f m pad"
		% [before[0], before[1], before[1] - before[0], plan.flatten_radius * 2.0])

	var t0: int = Time.get_ticks_msec()
	var site: Dictionary = _planner.stamp_site_plan(plan, centre, reg)
	var stamp_ms: int = Time.get_ticks_msec() - t0
	await get_tree().physics_frame
	if site.is_empty():
		_fail("the stamp was refused - read the [PLAN] lines above")
		_finish()
		return
	var compound: Node3D = (site.get("nodes", []) as Array)[0] as Node3D
	print("[SITE] stamped in %d ms" % stamp_ms)

	_check_ground(plan, centre, compound)
	_check_steel(plan, reg, compound)
	_check_men(plan, reg, site)
	await _check_walk(plan, centre, compound)

	_finish()


# ---------------------------------------------------------------- 1. GROUND
func _check_ground(plan: SitePlan, centre: Vector3, compound: Node3D) -> void:
	var after: Array = _relief(centre, plan.flatten_radius)
	var core: Array = _relief(centre, plan.flatten_radius * CORE_FRACTION)
	print("[GROUND] AFTER:  min %.2f max %.2f RELIEF %.2f m across the %.0f m pad"
		% [after[0], after[1], after[1] - after[0], plan.flatten_radius * 2.0])
	print("[GROUND] CORE:   min %.2f max %.2f RELIEF %.2f m across the inner %.0f m"
		% [core[0], core[1], core[1] - core[0], plan.flatten_radius * CORE_FRACTION * 2.0])
	if core[1] - core[0] > FLAT_TOL_M:
		_fail("the pad core carries %.2f m of relief, tolerance %.2f m"
			% [core[1] - core[0], FLAT_TOL_M])

	# UNDER EVERY PART, over the part's OWN footprint. A 3 m sample under a 13 m gun
	# emplacement measures the middle of it and calls the rim flat.
	var worst: float = -1.0
	var worst_id: String = ""
	var worst_seat: float = 0.0
	var worst_seat_id: String = ""
	var checked: int = 0
	for child in compound.get_children():
		var part := child as Node3D
		if part == null or not part.has_meta("part_id"):
			continue
		var pid: String = str(part.get_meta("part_id"))
		var r: float = float(FOOT_R.get(pid, 2.0))
		var foot: Array = _relief(part.global_position, r)
		var relief: float = foot[1] - foot[0]
		var seat: float = part.global_position.y - foot[0]
		checked += 1
		if relief > worst:
			worst = relief
			worst_id = pid
		if absf(seat) > absf(worst_seat):
			worst_seat = seat
			worst_seat_id = pid
		if relief > FLAT_TOL_M:
			_fail("ground under '%s' at %s carries %.2f m of relief"
				% [pid, str(part.global_position.round()), relief])
	print("[GROUND] %d part(s) measured over their own footprint: WORST RELIEF %.3f m ('%s')"
		% [checked, worst, worst_id])
	print("[GROUND] worst seat error %.3f m ('%s') - part origin vs the ground under it"
		% [worst_seat, worst_seat_id])


func _relief(centre: Vector3, radius: float) -> Array:
	return SitePick.relief(_world.terrain_manager, centre, radius, PAD_SAMPLES)


# ---------------------------------------------------------------- 2. STEEL
## Every part must be HITTABLE (a shape a round and a body can find) and, if it declares a
## kind, ON THE BLAST BUS (a Destructible with hp and shapes). Adoption empties the part
## node - mesh and shapes both move onto a Destructible sibling - so this counts BOTH sides
## and attributes them by the part_id meta the stamper now writes.
func _check_steel(plan: SitePlan, reg: KitRegistry, compound: Node3D) -> void:
	var want_kind: Dictionary = {}
	var want_count: Dictionary = {}
	for entry_any in plan.parts:
		var pid: String = str((entry_any as Dictionary).get("id", ""))
		want_kind[pid] = reg.destructible_kind(pid)
		want_count[pid] = int(want_count.get(pid, 0)) + 1

	# Destructibles, by the part they came from.
	var d_by_part: Dictionary = {}
	var untagged: PackedStringArray = PackedStringArray()
	var shapeless: PackedStringArray = PackedStringArray()
	var total_d: int = 0
	var total_shapes: int = 0
	var stack: Array[Node] = [_world]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for c in n.get_children():
			stack.append(c)
		var d := n as Destructible
		if d == null:
			continue
		total_d += 1
		var pid: String = str(d.get_meta("part_id", "?"))
		var rec: Array = d_by_part.get(pid, [0, 0, 0]) as Array
		rec[0] = int(rec[0]) + 1
		var shapes: int = 0
		for c in d.get_children():
			if c is CollisionShape3D and not (c as CollisionShape3D).disabled:
				shapes += 1
		rec[1] = int(rec[1]) + shapes
		rec[2] = int(rec[2]) + d.hp
		total_shapes += shapes
		d_by_part[pid] = rec
		if shapes == 0 and not shapeless.has(pid):
			shapeless.append(pid)
		if not d.is_in_group("hard_surface") and not d.is_in_group("soft_cover"):
			if not untagged.has(pid):
				untagged.append(pid)

	# Shapes still living on the part nodes (parts with no destructible kind keep theirs).
	var part_shapes: Dictionary = {}
	var part_bodies: Dictionary = {}
	for child in compound.get_children():
		var part := child as Node3D
		if part == null or not part.has_meta("part_id"):
			continue
		var pid: String = str(part.get_meta("part_id"))
		var s: Array[Node] = [part]
		var bodies: int = 0
		var shapes: int = 0
		while not s.is_empty():
			var n: Node = s.pop_back()
			for c in n.get_children():
				s.append(c)
			var co := n as CollisionObject3D
			if co == null:
				continue
			bodies += 1
			if not co.is_in_group("hard_surface") and not co.is_in_group("soft_cover"):
				if not untagged.has(pid):
					untagged.append(pid)
			for c in co.get_children():
				if c is CollisionShape3D and not (c as CollisionShape3D).disabled:
					shapes += 1
		part_bodies[pid] = int(part_bodies.get(pid, 0)) + bodies
		part_shapes[pid] = int(part_shapes.get(pid, 0)) + shapes
		total_shapes += shapes

	print("[STEEL] %-22s %5s %5s %8s %8s %6s" % ["part", "n", "kind", "destr.", "shapes", "hp"])
	var ids: Array = want_count.keys()
	ids.sort()
	for id_any in ids:
		var pid: String = String(id_any)
		var rec: Array = d_by_part.get(pid, [0, 0, 0]) as Array
		var shapes: int = int(rec[1]) + int(part_shapes.get(pid, 0))
		print("[STEEL] %-22s %5d %5s %8d %8d %6d"
			% [pid, int(want_count[pid]), "-" if str(want_kind[pid]) == "" else
				str(want_kind[pid]), int(rec[0]), shapes,
				int(rec[2]) / maxi(1, int(rec[0]))])
		if shapes == 0:
			_fail("'%s' has NO collision shape anywhere - a round passes through it and so "
				% pid + "does a man")
		if str(want_kind[pid]) != "" and int(rec[0]) < int(want_count[pid]):
			_fail("%d x '%s' declare kind '%s' but only %d Destructible(s) exist - the rest "
				% [int(want_count[pid]), pid, str(want_kind[pid]), int(rec[0])]
				+ "are INDESTRUCTIBLE and nothing raised an error")
	print("[STEEL] %d Destructible(s), %d live collision shape(s) in the compound"
		% [total_d, total_shapes])
	if not shapeless.is_empty():
		_fail("Destructible(s) with no shape: %s" % ", ".join(shapeless))
	if not untagged.is_empty():
		_fail("collider(s) in NEITHER hard_surface nor soft_cover: %s - ballistics has no "
			% ", ".join(untagged) + "material for them")
	else:
		print("[STEEL] every collider carries a ballistics group (hard_surface / soft_cover)")

	# LINE OF SIGHT OUT. An embrasure that cannot see out is a bunker nobody can fight from
	# (KIT_PART_CONTRACT section 3). A bunker's fighting front is its local +Z.
	var blocked: int = 0
	var seen: int = 0
	for child in compound.get_children():
		var part := child as Node3D
		if part == null or not part.has_meta("part_id"):
			continue
		var pid: String = str(part.get_meta("part_id"))
		if not pid.begins_with("fb_bunker"):
			continue
		seen += 1
		# The fighting front is local +Z (measured: the mg bunker's m60_pintle sits at
		# z=+1.55). Cast from just outside the front face, at embrasure height.
		var fwd: Vector3 = part.global_transform.basis.z.normalized()
		var eye: Vector3 = part.global_position + Vector3(0.0, 1.2, 0.0) + fwd * 2.6
		var to: Vector3 = eye + fwd * 45.0
		var q := PhysicsRayQueryParameters3D.create(eye, to)
		q.collision_mask = 1
		var hit: Dictionary = _world.get_world_3d().direct_space_state.intersect_ray(q)
		var reach: float = 45.0 if hit.is_empty() else eye.distance_to(hit.position as Vector3)
		var what: String = "open ground" if hit.is_empty() else str((hit.collider as Node).name)
		print("[STEEL] %-18s at %s sees %5.1f m out along its embrasure (%s)"
			% [pid, str(part.global_position.round()), reach, what])
		if reach < 25.0:
			blocked += 1
	if blocked > 0:
		_fail("%d of %d bunker(s) cannot see 25 m past their own embrasure" % [blocked, seen])


# ---------------------------------------------------------------- 3. MEN
func _check_men(plan: SitePlan, reg: KitRegistry, site: Dictionary) -> void:
	var garrison: Array = site.get("garrison", []) as Array
	var by_occ: Dictionary = {}
	var men: int = 0
	for g_any in garrison:
		var g: Dictionary = g_any
		var occ: String = str(g.get("occupation", ""))
		men += int(g.get("men", 0))
		by_occ[occ] = int(by_occ.get(occ, 0)) + int(g.get("men", 0))
		if occ == "":
			_fail("a garrison post arrived with no occupation")
		if not (g.get("pos", null) is Vector3):
			_fail("a garrison post arrived with no position")
	var occs: Array = by_occ.keys()
	occs.sort()
	var parts_str: PackedStringArray = PackedStringArray()
	for o_any in occs:
		parts_str.append("%s x%d" % [String(o_any), int(by_occ[o_any])])
	print("[MEN] %d post(s), %d men: %s" % [garrison.size(), men, ", ".join(parts_str)])
	if garrison.is_empty():
		_fail("the compound posts NOBODY - the crew half of the part contract is dead")

	# Posts must stand where the plan put the parts, not at the world origin.
	# XZ ONLY. find_site() returns a centre with y=0 while the compound is seated at the pad
	# height, so a straight distance_to() compares a post against a point 184 m underground
	# and reports every one of them as adrift. That is what this check did on its first run.
	var far: int = 0
	var c: Vector3 = site.get("center", Vector3.ZERO)
	for g_any in garrison:
		var g: Dictionary = g_any
		var p: Vector3 = g.get("pos", Vector3.ZERO)
		if Vector2(p.x - c.x, p.z - c.z).length() > 40.0:
			far += 1
	if far > 0:
		_fail("%d post(s) stand further than 40 m from the site centre in XZ" % far)

	# THE GATE'S DEMAND. It demands 'perimeter' and posts a guard only when something else in
	# the SAME plan supplies it. Name the suppliers, then say whether the guard turned up.
	var suppliers: PackedStringArray = PackedStringArray()
	for entry_any in plan.parts:
		var pid: String = str((entry_any as Dictionary).get("id", ""))
		if reg.supplies_for(pid).has("perimeter") and not suppliers.has(pid):
			suppliers.append(pid)
	var gate_posts: int = 0
	for g_any in garrison:
		if str((g_any as Dictionary).get("part", "")) == "fb_gate_assembly":
			gate_posts += int((g_any as Dictionary).get("men", 0))
	print("[MEN] gate demands %s; supplied in this plan by: %s"
		% [str(reg.demands_for("fb_gate_assembly")), ", ".join(suppliers)])
	print("[MEN] gate posts %d guard(s)" % gate_posts)
	if gate_posts == 0:
		_fail("the gate posted nobody even though %d part kind(s) supply 'perimeter'"
			% suppliers.size())

	# THE NEGATIVE CONTROL, in the same booted world. A rule that only ever says yes is not
	# a rule: the same gate, alone on open ground 120 m away, must post nobody.
	var lone := SitePlan.new()
	lone.plan_name = "_probe_gate_alone"
	lone.add_part("fb_gate_assembly", Vector3.ZERO)
	var lone_site: Dictionary = _planner.stamp_site_plan(lone,
		(site.get("center", Vector3.ZERO) as Vector3) + Vector3(120.0, 0.0, 0.0), reg)
	var lone_posts: Array = lone_site.get("garrison", []) as Array
	print("[MEN] control: the same gate alone on open ground posts %d" % lone_posts.size())
	if not lone_posts.is_empty():
		_fail("the gate posted %d man/men with nothing supplying 'perimeter' - the combo "
			% lone_posts.size() + "rule is not being applied")
	var lone_nodes: Array = lone_site.get("nodes", []) as Array
	if not lone_nodes.is_empty() and is_instance_valid(lone_nodes[0] as Node):
		(lone_nodes[0] as Node).queue_free()


# ---------------------------------------------------------------- 4. WALK
func _check_walk(plan: SitePlan, centre: Vector3, compound: Node3D) -> void:
	_nav = NavBaker.new()
	add_child(_nav)
	_nav.setup(_world.terrain_manager)
	_nav.queue_site_with_colliders(centre, plan.flatten_radius + 8.0, compound)
	var waited: float = 0.0
	while _nav.regions_live < 1 and waited < 60.0:
		await get_tree().create_timer(0.25).timeout
		waited += 0.25
	if _nav.regions_live < 1:
		_fail("the navmesh never baked - nothing can walk this compound")
		return
	for _i in range(6):
		await get_tree().physics_frame

	var gate: Node3D = _find_part(compound, "fb_gate_assembly")
	var gun: Node3D = _find_part(compound, "fb_emplacement_m101")
	if gate == null or gun == null:
		_fail("the plan has no gate or no gun - this probe expects both")
		return
	# Out from the gate along its own road axis: the gate's local +Z is the road.
	var road: Vector3 = gate.global_transform.basis.z
	road.y = 0.0
	road = road.normalized()
	if (gate.global_position + road * 5.0).distance_to(centre) < gate.global_position.distance_to(centre):
		road = -road          # take the side that leads AWAY from the compound
	var outside: Vector3 = gate.global_position + road * 26.0
	outside.y = _world.floor_y(outside)
	var inside: Vector3 = gun.global_position + Vector3(0.0, 0.0, 6.0)
	inside.y = _world.floor_y(inside)

	# A) inside the wire, gun pit to gate: the compound must be walkable at all.
	var gate_in: Vector3 = gate.global_position - road * 6.0
	gate_in.y = _world.floor_y(gate_in)
	var in_path: PackedVector3Array = _path(inside, gate_in)
	print("[WALK] inside the wire, gun pit -> gate: %d hop(s), %.1f m, ends %.1f m from target"
		% [in_path.size(), _path_len(in_path), _end_gap(in_path, gate_in)])
	if _end_gap(in_path, gate_in) > 3.0:
		_fail("a man at the gun cannot walk to his own gate - the compound is not walkable")

	# B) from outside, gate SHUT. The leaves are 2.5 m of collider across the gap and they
	# are scenery, so this is what an attacker meets today.
	var shut: PackedVector3Array = _path(outside, inside)
	var shut_gap: float = _end_gap(shut, inside)
	print("[WALK] gate SHUT: outside -> gun pit ends %.1f m short of the gun" % shut_gap)

	# C) blow the gate tower. ONE Destructible owns every collider in the gate part - tower,
	# both leaves, both posts - so killing it is what opens this perimeter, and the path that
	# appears afterwards has to run through the gateway.
	var d: Destructible = _destructible_for(compound, "fb_gate_assembly")
	if d == null:
		_fail("the gate is not on the blast bus - it cannot be breached")
		return
	print("[WALK] blowing the gate: kind '%s', %d hp" % [d.kind, d.hp])
	var gate_pos: Vector3 = d.global_position
	d.take_damage(d.hp + 50, Enums.DamageType.EXPLOSIVE)
	Destructible.drain(8)
	for _i in range(4):
		await get_tree().physics_frame
	waited = 0.0
	var before_regions: int = _nav.regions_live
	while _nav.regions_live <= before_regions and waited < 30.0:
		await get_tree().create_timer(0.25).timeout
		waited += 0.25
	for _i in range(6):
		await get_tree().physics_frame

	var open: PackedVector3Array = _path(outside, inside)
	var open_gap: float = _end_gap(open, inside)
	var near_gate: float = _closest(open, gate_pos)
	print("[WALK] gate BLOWN: outside -> gun pit %d hop(s), %.1f m, ends %.1f m short, "
		% [open.size(), _path_len(open), open_gap]
		+ "passes %.1f m from the gateway" % near_gate)
	if open_gap > 4.0:
		_fail("the gate is down and there is still no way in - the breach did not re-bake")
	if near_gate > 9.0:
		_fail("the way in does not run through the gateway (%.1f m off) - the perimeter has "
			% near_gate + "another hole in it")
	if shut_gap <= open_gap + 3.0:
		push_warning("[WALK] the shut gate was no obstacle (%.1f m vs %.1f m) - either the "
			% [shut_gap, open_gap] + "wall has a gap or the leaves carry no collision")


func _path(from: Vector3, to: Vector3) -> PackedVector3Array:
	var map: RID = get_tree().root.get_world_3d().navigation_map
	return NavigationServer3D.map_get_path(map, from, to, true)


static func _path_len(p: PackedVector3Array) -> float:
	var out: float = 0.0
	for i in range(1, p.size()):
		out += p[i - 1].distance_to(p[i])
	return out


static func _end_gap(p: PackedVector3Array, target: Vector3) -> float:
	if p.is_empty():
		return 9999.0
	return Vector2(p[p.size() - 1].x - target.x, p[p.size() - 1].z - target.z).length()


static func _closest(p: PackedVector3Array, at: Vector3) -> float:
	var best: float = 9999.0
	for v in p:
		best = minf(best, Vector2(v.x - at.x, v.z - at.z).length())
	return best


static func _find_part(compound: Node3D, pid: String) -> Node3D:
	for c in compound.get_children():
		var n := c as Node3D
		if n != null and str(n.get_meta("part_id", "")) == pid:
			return n
	return null


func _destructible_for(compound: Node3D, pid: String) -> Destructible:
	var near: Node3D = _find_part(compound, pid)
	var stack: Array[Node] = [_world]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for c in n.get_children():
			stack.append(c)
		var d := n as Destructible
		if d != null and str(d.get_meta("part_id", "")) == pid:
			if near == null or d.global_position.distance_to(near.global_position) < 30.0:
				return d
	return null


func _finish() -> void:
	var p: String = SitePlan.path_for("_probe_gate_alone")
	if FileAccess.file_exists(p):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
	if _failures == 0:
		print("probe_firebase_site: PASS")
	else:
		print("probe_firebase_site: %d FAILURE(S)" % _failures)
	if _world != null and is_instance_valid(_world):
		_world.queue_free()
	get_tree().quit(1 if _failures > 0 else 0)
