## test_site_plan_roundtrip.gd - THE KIT'S ONE PATH, END TO END (ADR-043 §2).
##
## Writes a plan, reads it back off disk, stamps it into a real world, and asserts the parts
## are where the plan said and that the compound is the shape NavBaker needs. It is the probe
## that has to exist before any part master is authored, because the fossil law's objection to
## the kit in July was never about the parts - gen_firebase.py:1-13 refused to ship them as
## "24 files with one consumer". This proves the consumer works.
##
## What it deliberately does NOT assert: that any particular part exists. Only seven of the
## manifest's twenty-three families have a .glb today, and a probe that named one would go red
## on the art rather than on the code.
##
## Run: godot --headless --path . res://tests/test_site_plan_roundtrip.tscn
extends Node

const SEED_VAL: int = 4242
const PLAN_NAME: String = "_probe_roundtrip"
## Local placement is exact - a part that lands further than this from its planned offset means
## the transform chain is wrong, not that the ground moved.
const TOL_M: float = 0.01
## Placed parts that ship with no collider. It was 1 until 2026-09-09, when
## tools/add_kit_colliders.py cut a -colonly twin per solid mesh into all five of the July
## review exports that had none. IT IS 0 NOW AND IT STAYS 0. Raising it is the forbidden move.
const NO_COLLIDER_BASELINE: int = 0

## How flat "flat" is. His ask was that placing a model "plants a flat area for the building
## to exist"; at strength 1.0 the pad's core must be level to inside this, or flatten_pad()
## is doing what clear_and_flatten() did - which is to say, not flattening.
const FLAT_TOL_M: float = 0.05
## Where the pad is measured: a 13x13 lattice, plus the ground directly under every placed
## part. A centre sample alone would pass on any surface that happens to cross the middle at
## the right height.
const PAD_SAMPLES: int = 13
## The CORE is what has to be flat. Measured to the declared radius the pad reads 0.31 m of
## relief and always will: the outermost ring IS the lip where the shoulder ramp starts, and
## sample_world() interpolates bilinearly across that boundary cell. A pad with no lip is a
## cliff, which is the other half of his ask ("integrated into the world"), so the rim is
## reported and the core is asserted.
const CORE_FRACTION: float = 0.9

var _failures: int = 0


func _fail(msg: String) -> void:
	print("FAIL: ", msg)
	_failures += 1


func _ready() -> void:
	var reg: KitRegistry = KitRegistry.load_kit()
	var ids: Array[String] = reg.placeable_ids()
	print("[PLAN] kit knows %d part(s), %d placeable: %s"
		% [reg.parts.size(), ids.size(), ", ".join(ids)])
	if ids.is_empty():
		_fail("no placeable parts in the kit - the registry found no .glb beside the manifest")
		_finish(null)
		return

	# Stations are the half of the data model that a second war depends on, so assert the
	# manifest actually carries some. A registry that silently produced zero would let the
	# rest of this probe pass while the part contract was dead.
	var with_stations: int = 0
	for id in reg.parts.keys():
		if not (reg.stations_for(String(id)) as Array).is_empty():
			with_stations += 1
	print("[PLAN] %d part(s) carry work stations" % with_stations)
	if with_stations == 0:
		_fail("no part in the manifest carries a work station - the part contract is empty")

	# THE PART CONTRACT'S OPEN DOORS (ADR-043 §4). None of these is consumed by anything yet -
	# the combo resolver is post-demo work - and that is exactly why they need a probe. A field
	# nothing reads is a field that quietly stops being populated, and the cost of discovering
	# that after forty parts are authored is a second migration.
	for id_any in reg.parts.keys():
		var e: Dictionary = reg.parts[id_any]
		for field in ["crew", "demands", "supplies", "stations", "props"]:
			if not e.has(field):
				_fail("part '%s' has no '%s' field - the part contract lost a door"
					% [String(id_any), String(field)])
				break
		# Work types must arrive as bare strings. The moment one is an enum or an int, the
		# vocabulary is back in code and a second war cannot add work_firestep without
		# editing site_planner.gd.
		for st_any in (e.get("stations", []) as Array):
			var st: Dictionary = st_any
			if not (st.get("work_type", null) is String):
				_fail("part '%s' has a non-string work_type - the vocabulary left the data"
					% String(id_any))
				break

	var plan := SitePlan.new()
	plan.plan_name = PLAN_NAME
	plan.flatten_radius = 24.0
	# 1.0, deliberately. ADR-041 makes the declared strength BINDING and warns that a site
	# silently demanding 1.0 is asking for a pancake - so this probe ASKS for one, out loud,
	# and measures whether it gets one. A partial strength would prove nothing: the old
	# clear_and_flatten path also moved the ground a little.
	plan.flatten_strength = 1.0
	plan.flatten_shoulder = 8.0
	# Choose parts the authored contract says ARE structures. Picking blind off the palette is
	# how the first version of this test passed while the whole compound was invulnerable:
	# it placed three parts, asserted their POSITIONS, and never once asked whether anything
	# could be shot or blown up.
	var structural: Array[String] = []
	for id in ids:
		if reg.destructible_kind(id) != "":
			structural.append(id)
	if structural.is_empty():
		_fail("no placeable part declares a destructible kind - a stamped compound would be "
			+ "entirely invulnerable, which is ADR-042's bug class")
		_finish(null)
		return
	var offsets: Array[Vector3] = [
		Vector3(0.0, 0.0, 0.0), Vector3(9.0, 0.0, -4.0), Vector3(-7.5, 0.0, 6.0)]
	for i in range(offsets.size()):
		plan.add_part(structural[i % structural.size()], offsets[i], float(i) * 45.0)
	if not plan.save():
		_fail("could not save the plan")
		_finish(null)
		return

	var reloaded: SitePlan = SitePlan.load_from(PLAN_NAME)
	if reloaded == null:
		_fail("could not read the plan back")
		_finish(null)
		return
	if reloaded.parts.size() != plan.parts.size():
		_fail("round-trip lost parts: wrote %d, read %d"
			% [plan.parts.size(), reloaded.parts.size()])
	if not is_equal_approx(reloaded.flatten_radius, plan.flatten_radius):
		_fail("round-trip lost the flatten profile")
	for i in range(mini(plan.parts.size(), reloaded.parts.size())):
		var a: Dictionary = plan.parts[i]
		var b: Dictionary = reloaded.parts[i]
		if str(a["id"]) != str(b["id"]):
			_fail("part %d id changed across the round-trip" % i)
		if (a["pos"] as Vector3).distance_to(b["pos"] as Vector3) > TOL_M:
			_fail("part %d moved across the round-trip" % i)

	# A plan naming a part the kit has no model for must be REFUSED, not half-stamped.
	var bad := SitePlan.new()
	bad.plan_name = "_probe_bad"
	bad.add_part("fb_part_that_does_not_exist", Vector3.ZERO)
	if bad.validate(reg) == "":
		_fail("validate() accepted a plan naming a part with no model")

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
	var centre: Vector3 = planner.find_site(rng, 40.0)
	if centre == Vector3.ZERO:
		_fail("no site found for the plan")
		_finish(world)
		return

	# THE GROUND BEFORE. Same lattice, same points, so the after-number is a comparison and
	# not an assertion floating on its own.
	var before: Array = _sample_pad(world.terrain_manager, centre, reloaded.flatten_radius)
	print("[PLAN] ground BEFORE: min %.2f max %.2f range %.2f m over a %.0f m pad"
		% [before[0], before[1], before[1] - before[0], reloaded.flatten_radius * 2.0])

	var site: Dictionary = planner.stamp_site_plan(reloaded, centre, reg)
	await get_tree().physics_frame
	if site.is_empty():
		_fail("stamp_site_plan returned nothing")
		_finish(world)
		return

	var nodes: Array = site.get("nodes", []) as Array
	if nodes.size() != 1:
		_fail("site.nodes has %d entries - NavBaker takes nodes[0] and needs exactly one root"
			% nodes.size())
		_finish(world)
		return
	var compound: Node3D = nodes[0] as Node3D
	if compound == null:
		_fail("site.nodes[0] is not a Node3D")
		_finish(world)
		return

	var seen: int = 0
	for child in compound.get_children():
		var part := child as Node3D
		if part == null or not part.has_meta("part_id"):
			continue
		var want: Vector3 = (reloaded.parts[seen] as Dictionary)["pos"]
		if part.position.distance_to(want) > TOL_M:
			_fail("part %d ('%s') sits at %s, plan said %s"
				% [seen, str(part.get_meta("part_id")), part.position, want])
		seen += 1
	if seen != reloaded.parts.size():
		_fail("stamped %d part node(s), the plan has %d" % [seen, reloaded.parts.size()])

	# The compound must be SEATED, or every part is at world origin and the plan's local
	# offsets are the only thing keeping them near each other.
	if compound.global_position.distance_to(Vector3(centre.x, compound.global_position.y, centre.z)) > 1.0:
		_fail("the compound is not seated at the site centre")

	# THE ASSERTION THIS TEST WAS MISSING, AND THE REASON IT WENT RED.
	#
	# The first stamped compound put 5 meshes in the world and NOTHING on the blast bus:
	# sappers could not breach it, bullets could not penetrate it, and the siege would have
	# run against a base nothing could touch. The test passed anyway, because it only ever
	# checked where the parts sat.
	#
	# A Destructible with no CollisionShape3D is the same defect wearing a different hat - it
	# is registered, it reports a kind, and there is nothing in the world to hit. Assert the
	# SHAPE, not just the node.
	var kinds_wanted: Dictionary = {}
	for entry_any in reloaded.parts:
		var k: String = reg.destructible_kind(str((entry_any as Dictionary)["id"]))
		if k != "":
			kinds_wanted[k] = true
	var destructibles: Array[Node] = []
	var stack: Array[Node] = [world]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for c in n.get_children():
			stack.append(c)
		if n is Destructible:
			destructibles.append(n)
	print("[PLAN] %d Destructible(s) in the world after the stamp" % destructibles.size())
	if destructibles.is_empty():
		_fail("NOTHING is destructible after stamping %d structural part(s) - the compound "
			% reloaded.parts.size()
			+ "is bulletproof and indestructible, which is exactly ADR-042's silent failure")
	# COUNT THEM, not just "some". Non-empty passed while ONE of three parts was wired: the
	# other two still carried Blender workbench mesh names, so structure_meshes matched
	# nothing and two buildings were silently invulnerable. Every part that declares a kind
	# owes a Destructible.
	var want_destructible: int = 0
	for entry_any in reloaded.parts:
		if reg.destructible_kind(str((entry_any as Dictionary)["id"])) != "":
			want_destructible += 1
	if destructibles.size() < want_destructible:
		_fail("%d part(s) declare a destructible kind but only %d Destructible(s) exist - the "
			% [want_destructible, destructibles.size()]
			+ "rest are invulnerable, and nothing raised an error")
	for d_any in destructibles:
		var d := d_any as Destructible
		var shapes: int = 0
		for c in d.get_children():
			if c is CollisionShape3D:
				shapes += 1
		if shapes == 0:
			_fail("Destructible '%s' (kind '%s') has NO collision shape - nothing can hit it"
				% [d.name, d.kind])
		if not kinds_wanted.has(d.kind):
			_fail("Destructible '%s' has kind '%s', which no placed part declared"
				% [d.name, d.kind])
		if d.hp <= 0:
			_fail("Destructible '%s' has hp %d" % [d.name, d.hp])

	# THE RATCHET. Five of the seven July review exports carry no collider at all - they were
	# never meant to ship, which gen_firebase.py's own header says in as many words. That is
	# an art gap for P3, not a code regression, so it warns rather than erroring. It must not
	# be allowed to GROW, and it must be driven to zero as the proof pieces land.
	var lame: int = (site.get("no_collider", PackedStringArray()) as PackedStringArray).size()
	print("[PLAN] %d placed part(s) with no collider (baseline %d)" % [lame, NO_COLLIDER_BASELINE])
	if lame > NO_COLLIDER_BASELINE:
		_fail("%d placed part(s) ship with no collider, baseline is %d - a part lost its collision"
			% [lame, NO_COLLIDER_BASELINE])

	# THE GROUND AFTER - the number his ask is actually about.
	var after: Array = _sample_pad(world.terrain_manager, centre, reloaded.flatten_radius)
	var core: Array = _sample_pad(world.terrain_manager, centre,
		reloaded.flatten_radius * CORE_FRACTION)
	print("[PLAN] ground AFTER:  min %.2f max %.2f range %.2f m over a %.0f m pad"
		% [after[0], after[1], after[1] - after[0], reloaded.flatten_radius * 2.0])
	print("[PLAN] ground CORE:   min %.2f max %.2f range %.2f m over the inner %.0f m"
		% [core[0], core[1], core[1] - core[0],
			reloaded.flatten_radius * CORE_FRACTION * 2.0])
	if core[1] - core[0] > FLAT_TOL_M:
		_fail("the pad core is not flat: %.2f m of relief across it, tolerance %.2f m"
			% [core[1] - core[0], FLAT_TOL_M])

	# AND UNDER EACH BUILDING, which is the thing that actually has to stand level. A part
	# that hangs off a lip has men falling through the berm, which is the defect he named.
	for child in compound.get_children():
		var part := child as Node3D
		if part == null or not part.has_meta("part_id"):
			continue
		var foot: Array = _sample_pad(world.terrain_manager, part.global_position, 3.0)
		var seat_gap: float = absf(part.global_position.y - foot[0])
		print("[PLAN] under %-22s ground min %.2f max %.2f range %.2f m, part seated %.2f m above it"
			% [str(part.get_meta("part_id")), foot[0], foot[1], foot[1] - foot[0], seat_gap])
		if foot[1] - foot[0] > FLAT_TOL_M:
			_fail("ground under '%s' has %.2f m of relief" % [str(part.get_meta("part_id")),
				foot[1] - foot[0]])

	# THE NPC HALF (ADR-043 §4). crew/demands/supplies were read and consumed by NOTHING
	# until 2026-09-09, and the generated manifest carried none of them - so the door was
	# open onto an empty room. Assert a stamped plan actually produces posts.
	var garrison: Array = site.get("garrison", []) as Array
	var men: int = 0
	for g_any in garrison:
		var g: Dictionary = g_any
		men += int(g.get("men", 0))
		if str(g.get("occupation", "")) == "":
			_fail("a garrison post arrived with no occupation")
			break
		if not (g.get("pos", null) is Vector3):
			_fail("a garrison post arrived with no position")
			break
	print("[PLAN] garrison: %d post(s), %d man/men" % [garrison.size(), men])
	var any_crew: bool = false
	for entry_any in reloaded.parts:
		if not reg.crew_for(str((entry_any as Dictionary)["id"])).is_empty():
			any_crew = true
			break
	if any_crew and garrison.is_empty():
		_fail("parts in this plan declare crew and the stamp produced NO posts - the NPC "
			+ "half of the part contract is wired to nothing")

	# THE COMBO RULE, proven both ways in the same booted world. His ask was "certian npcs
	# thatll spawn with certian building combos", and a rule that only ever says yes is not
	# a rule. The gate house demands `perimeter`; alone on open ground there is nothing to
	# guard and no guard is posted, and beside a sandbag wall that supplies `perimeter`
	# the same part brings its man.
	if reg.contract_gap("fb_gate_assembly") == "" and reg.contract_gap("fb_sandbag_heavy") == "":
		var lone := SitePlan.new()
		lone.plan_name = "_probe_combo_lone"
		lone.add_part("fb_gate_assembly", Vector3.ZERO)
		var lone_site: Dictionary = planner.stamp_site_plan(lone,
			centre + Vector3(90.0, 0.0, 0.0), reg)
		var lone_posts: Array = lone_site.get("garrison", []) as Array
		if not lone_posts.is_empty():
			_fail("the gate house posted %d man/men with nothing supplying 'perimeter' - "
				% lone_posts.size() + "the combo rule is not being applied")
		var pair := SitePlan.new()
		pair.plan_name = "_probe_combo_pair"
		pair.add_part("fb_gate_assembly", Vector3.ZERO)
		pair.add_part("fb_sandbag_heavy", Vector3(6.0, 0.0, 0.0))
		var pair_site: Dictionary = planner.stamp_site_plan(pair,
			centre + Vector3(-90.0, 0.0, 0.0), reg)
		var pair_posts: Array = pair_site.get("garrison", []) as Array
		if pair_posts.is_empty():
			_fail("the gate house posted nobody even beside a part supplying 'perimeter'")
		print("[PLAN] combo rule: gate alone %d post(s), gate + wall %d post(s)"
			% [lone_posts.size(), pair_posts.size()])

	var stations: Array = site.get("stations", []) as Array
	print("[PLAN] site carries %d station(s) from part manifests" % stations.size())
	for st_any in stations:
		var st: Dictionary = st_any
		if str(st.get("type", "")) == "":
			_fail("a station arrived with no work_type")
			break

	_finish(world)


## [min_y, max_y] of the terrain over a square lattice covering `radius` around `centre`.
## Reads the heightmap, not a raycast: a raycast hits the BUILDING and reports the roof,
## which is how "hanging bulbs at +7.8 m" got measured as CORRECT once already.
func _sample_pad(tm: Node, centre: Vector3, radius: float) -> Array:
	var lo: float = 1.0e9
	var hi: float = -1.0e9
	for iz in range(PAD_SAMPLES):
		for ix in range(PAD_SAMPLES):
			var fx: float = float(ix) / float(PAD_SAMPLES - 1) * 2.0 - 1.0
			var fz: float = float(iz) / float(PAD_SAMPLES - 1) * 2.0 - 1.0
			if Vector2(fx, fz).length() > 1.0:
				continue
			var h: float = tm.get_height_at(
				Vector3(centre.x + fx * radius, 0.0, centre.z + fz * radius))
			lo = minf(lo, h)
			hi = maxf(hi, h)
	return [lo, hi]


func _finish(world: Node) -> void:
	# The probe's own plan file is not content. Leaving it behind would put a fixture in
	# data/site_plans where the tool writes real ones.
	var p: String = SitePlan.path_for(PLAN_NAME)
	if FileAccess.file_exists(p):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
	if _failures == 0:
		print("test_site_plan_roundtrip: PASS")
	else:
		print("test_site_plan_roundtrip: %d FAILURE(S)" % _failures)
	if world != null and is_instance_valid(world):
		world.queue_free()
	get_tree().quit(1 if _failures > 0 else 0)
