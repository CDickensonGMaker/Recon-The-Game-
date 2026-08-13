## probe_fire_parity.gd - the 2026-08-04 explosion decree, measured.
## Boots the shared FireSupportBench rig, rings a fresh target field (S29 segmented
## trees registered in TreeBreakSystem + a Destructible fort) per weapon, fires
## arty / mortar / wp / napalm / cbu / spectre / illum through the REAL
## request_fire_support path, and prints per weapon: trees felled, fort destroyed,
## DamageSystem destruction calls (craters/veg-clears), FireHazards alive, and -
## for the air strips - every canister release (position vs the airframe,
## velocity) plus the visual scale ladder after ORDNANCE_VISUAL_MULT.
## Run: godot --headless --path . res://tools/probe_fire_parity.tscn
extends Node3D

const TREE_RING := 8
const TREE_R := 6.0
const RUN_DIR := Vector3(0, 0, -1)

var _director: FieldDirector = null
var _player: CharacterBody3D = null
var _watch_canisters: bool = false
var _seen_canisters: Array[ProjectileBase] = []
var _release_count: int = 0
var _failures: int = 0


func _ready() -> void:
	var floor_body := StaticBody3D.new()
	floor_body.collision_layer = 1
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(600, 0.2, 600)
	cs.shape = box
	cs.position.y = -0.1
	floor_body.add_child(cs)
	add_child(floor_body)

	_player = CharacterBody3D.new()
	add_child(_player)
	_player.global_position = Vector3(0, 1, 0)
	var rto: AllyBase = AllyBase.spawn_ally(self, Vector3(2, 0, 1))
	if rto == null:
		print("FAIL: no RTO - the net cannot come up")
		get_tree().quit(1)
		return
	rto.add_to_group("radioman")
	rto.member = {"nick": "SPARKS", "mos": "RTO"}
	_director = FireSupportBench.wire(self, _player, 600.0)

	print("[SCALE] ORDNANCE_VISUAL_MULT = %.1f" % GunFX.ORDNANCE_VISUAL_MULT)
	for kind: String in GunFX._KIND_SCALE:
		print("[SCALE] %s: class %.1f -> visual root scale %.1f" % [kind,
			float(GunFX._KIND_SCALE[kind]),
			float(GunFX._KIND_SCALE[kind]) * GunFX.ORDNANCE_VISUAL_MULT])

	await _run_weapon("arty", Vector3(90, 0, 0), 16.0)
	await _run_weapon("mortar", Vector3(-90, 0, 0), 14.0)
	await _run_weapon("wp", Vector3(0, 0, 90), 10.0)
	await _run_weapon("napalm", Vector3(0, 0, -90), 12.0)
	await _run_weapon("cbu", Vector3(90, 0, -90), 12.0)
	await _run_weapon("spectre", Vector3(-90, 0, 90), 36.0)
	await _run_weapon("illum", Vector3(-90, 0, -90), 8.0)

	if _failures == 0:
		print("PASS: all seven support fires destroy, burn, light, and drop from the rack")
	else:
		print("FAIL: %d parity failures" % _failures)
	get_tree().quit(_failures)


func _run_weapon(kind: String, at: Vector3, wait_s: float) -> void:
	# S29: a standing tree is a REGISTRY ENTRY (TreeBreakSystem), not a body.
	# Plant the ring the way TreeCoverLayer does and count consumption - a blast
	# that reaches trees removes entries, and the break queue spawns the visuals.
	var tree_layer := Node3D.new()
	tree_layer.name = "ring_" + kind
	add_child(tree_layer)
	var scatter: Array = []
	for i in range(TREE_RING):
		var a: float = TAU * float(i) / float(TREE_RING)
		scatter.append({"name": "broadleaf_a",
			"xf": Transform3D(Basis.IDENTITY, at + Vector3(cos(a) * TREE_R, 0.0, sin(a) * TREE_R))})
	TreeBreakSystem.register_chunk(tree_layer, Vector2i.ZERO, scatter)
	var trees_before: int = TreeBreakSystem.registered_count()
	var wall := BoxMesh.new()
	wall.size = Vector3(3.0, 2.0, 1.0)
	var fort: Destructible = FireSupportBench.spawn_fort(self, at + Vector3(3.0, 0.0, 0.0),
		wall, Vector3(3.0, 2.0, 1.0), "sandbag", 110)
	var zones_before: int = DamageSystem.damage_zones.size()

	_director._cas_cooldown = 0.0
	_seen_canisters.clear()
	_release_count = 0
	_watch_canisters = kind in ["napalm", "cbu"]
	print("---- [%s] fire at %v ----" % [kind.to_upper(), at])
	_director.request_fire_support(kind, at, RUN_DIR)
	await get_tree().create_timer(wait_s).timeout
	_watch_canisters = false

	var felled: int = trees_before - TreeBreakSystem.registered_count()
	var fort_dead: bool = is_instance_valid(fort) and fort.is_destroyed()
	var zones: int = DamageSystem.damage_zones.size() - zones_before
	var fires: int = _count_fire_hazards()
	print("[%s] trees felled %d/%d | fort destroyed %s | destruction calls %d | fire hazards alive %d"
		% [kind.to_upper(), felled, TREE_RING, str(fort_dead), zones, fires])

	match kind:
		"arty":
			if felled == 0 or not fort_dead or zones < FirePlan.ARTY_ROUNDS_MIN:
				_failures += 1
				print("FAIL: arty parity (want felled>0, fort dead, >=%d craters)"
					% FirePlan.ARTY_ROUNDS_MIN)
		"mortar":
			if felled == 0 or zones < 3:
				_failures += 1
				print("FAIL: mortar parity (want felled>0, >=3 destruction calls)")
		"wp":
			if fires < FirePlan.WP_ROUNDS:
				_failures += 1
				print("FAIL: WP barrage must leave %d burning patches" % FirePlan.WP_ROUNDS)
		"napalm":
			if felled == 0 or _release_count != FirePlan.NAPALM_DROPS or fires < FirePlan.NAPALM_DROPS:
				_failures += 1
				print("FAIL: napalm (want felled>0, %d canisters off the rack, %d fires)"
					% [FirePlan.NAPALM_DROPS, FirePlan.NAPALM_DROPS])
		"cbu":
			if _release_count != FirePlan.CBU_CANS or zones < FirePlan.CBU_CANS:
				_failures += 1
				print("FAIL: cbu raid (want %d dispensers and a crater per dispenser)"
					% FirePlan.CBU_CANS)
		"spectre":
			if zones < 5:
				_failures += 1
				print("FAIL: spectre chain left <5 destruction calls on the ground")
		"illum":
			var lit: bool = IllumFlare.is_lit(at)
			var lit_off: bool = IllumFlare.is_lit(at + Vector3(250, 0, 0))
			var has_light: bool = false
			var rng_m: float = 0.0
			for f in IllumFlare.active_flares:
				if not is_instance_valid(f):
					continue
				for c in f.get_children():
					if c is OmniLight3D:
						has_light = true
						rng_m = (c as OmniLight3D).omni_range
			print("[ILLUM] flares %d | real OmniLight %s range %.0fm | is_lit(target) %s | is_lit(+250m) %s"
				% [IllumFlare.active_flares.size(), str(has_light), rng_m, str(lit), str(lit_off)])
			if IllumFlare.active_flares.is_empty() or not lit or not has_light or lit_off:
				_failures += 1
				print("FAIL: illum round did not light a bounded circle over the target")

	TreeBreakSystem.unregister_layer(tree_layer)
	tree_layer.queue_free()
	if is_instance_valid(fort):
		AgentRegistry.unregister(fort)
		fort.queue_free()


## Projectiles live under the CombatManager pool, planes under the BenchWorld -
## walk the whole tree from root so neither parenting choice can hide a release.
func _physics_process(_delta: float) -> void:
	if not _watch_canisters:
		return
	var everything: Array[Node] = _all_nodes(get_tree().root)
	var plane: CASAirplane = null
	for n in everything:
		if n is CASAirplane:
			plane = n as CASAirplane
			break
	for n in everything:
		var p := n as ProjectileBase
		if p == null or not p.is_active or p in _seen_canisters:
			continue
		if p.projectile_data == null or p.projectile_data.tumble_rate <= 0.0:
			continue
		_seen_canisters.append(p)
		_release_count += 1
		var off: String = "no airframe found"
		if plane != null and is_instance_valid(plane):
			off = "%.1fm from airframe (airframe alt %.1f)" % [
				p.global_position.distance_to(plane.global_position), plane.global_position.y]
		print("[RELEASE] %s #%d at %v vel %v - %s" % [
			p.projectile_data.id, _release_count, p.global_position, p.velocity, off])


func _count_fire_hazards() -> int:
	var n: int = 0
	for node in _all_nodes(get_tree().root):
		if node is FireHazard:
			n += 1
	return n


func _all_nodes(root: Node) -> Array[Node]:
	var out: Array[Node] = []
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		out.append(n)
		for c in n.get_children():
			stack.push_back(c)
	return out
