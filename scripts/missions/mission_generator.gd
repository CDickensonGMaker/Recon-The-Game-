## mission_generator.gd - seed + type -> MissionPlan (positions/flavor, pure),
## then build() stamps sites, sensors, and enemy groups into a GameWorld (NS09).
class_name MissionGenerator
extends RefCounted

enum MissionType { PATROL, VILLAGE_RAID, FIREBASE_DEFENSE }

const TYPE_NAMES := {
	MissionType.PATROL: "PATROL",
	MissionType.VILLAGE_RAID: "VILLAGE RAID",
	MissionType.FIREBASE_DEFENSE: "FIREBASE DEFENSE",
}

const CODENAME_A: Array[String] = ["SILVER", "IRON", "JUNGLE", "DUSTY", "BROKEN", "SHADOW", "COPPER", "MIDNIGHT", "RED", "LONG"]
const CODENAME_B: Array[String] = ["LANCE", "TIGER", "ARROW", "SABRE", "HAMMER", "SERPENT", "TALON", "BUFFALO", "DAGGER", "PYTHON"]

const ENEMY_DATA: Array[String] = [
	"res://data/enemies/german_rifleman.tres",
	"res://data/enemies/german_smg.tres",
]


## PLAN: deterministic per (world seed, mission seed, type). Positions only.
static func plan(world: GameWorld, seed_value: int, type: MissionType) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var planner := SitePlanner.new(world.gameplay_grid, world.terrain_manager, world.vegetation_manager, world)
	var p := {
		"seed": seed_value,
		"type": type,
		"type_name": str(TYPE_NAMES[type]),
		"codename": "OPERATION %s %s" % [CODENAME_A[rng.randi() % CODENAME_A.size()], CODENAME_B[rng.randi() % CODENAME_B.size()]],
		"objectives": [],
		"enemy_groups": [],
		"sites": [],
		"cas_budget": 0,
	}
	match type:
		MissionType.PATROL:
			_plan_patrol(world, rng, planner, p)
		MissionType.VILLAGE_RAID:
			_plan_village(world, rng, planner, p)
		MissionType.FIREBASE_DEFENSE:
			_plan_firebase(world, rng, planner, p)
	return p


static func _passable_near(world: GameWorld, rng: RandomNumberGenerator, origin: Vector3, min_r: float, max_r: float, attempts: int = 60) -> Vector3:
	var map_size: float = world.terrain_manager.map_size
	for _i in range(attempts):
		var a: float = rng.randf_range(0.0, TAU)
		var r: float = rng.randf_range(min_r, max_r)
		var p := origin + Vector3(cos(a) * r, 0.0, sin(a) * r)
		p.x = clampf(p.x, 80.0, map_size - 80.0)
		p.z = clampf(p.z, 80.0, map_size - 80.0)
		if world.gameplay_grid.is_position_passable(p) and not world.gameplay_grid.is_water(p):
			return p
	return origin  # degenerate but never invalid


static func _plan_patrol(world: GameWorld, rng: RandomNumberGenerator, planner: SitePlanner, p: Dictionary) -> void:
	var lz_in: Vector3 = planner.find_site(rng, 16.0, 150.0)
	p["insertion_lz"] = lz_in
	var checkpoint_count: int = rng.randi_range(3, 4)
	var cursor := lz_in
	var index: int = 0
	for i in range(checkpoint_count):
		cursor = _passable_near(world, rng, cursor, 150.0, 300.0)
		p.objectives.append({"kind": "reach", "pos": cursor, "title": "CHECKPOINT %s" % char(65 + i), "index": index, "required": true})
		index += 1
		# Off-route contact near some checkpoints.
		if rng.randf() < 0.6:
			var contact_pos := _passable_near(world, rng, cursor, 20.0, 60.0)
			p.enemy_groups.append({"pos": contact_pos, "count": rng.randi_range(2, 4), "tag": "patrol_contact_%d" % i, "lazy": true})
	# Optional bonus cache.
	var cache_pos := _passable_near(world, rng, cursor, 80.0, 160.0)
	p["cache_pos"] = cache_pos
	p.objectives.append({"kind": "reach", "pos": cache_pos, "title": "LOCATE VC CACHE (BONUS)", "index": index, "required": false})
	index += 1
	p["exfil_lz"] = planner.find_site(rng, 16.0, 150.0)
	p["sites"] = [{"kind": "lz", "center": lz_in}, {"kind": "lz", "center": p.exfil_lz}, {"kind": "vc_props", "center": cache_pos}]
	p["intel"] = "Local Force elements reported along the route. Expect trail watchers."


static func _plan_village(world: GameWorld, rng: RandomNumberGenerator, planner: SitePlanner, p: Dictionary) -> void:
	var village: Vector3 = planner.find_site(rng, 26.0, 200.0)
	var lz_in: Vector3 = planner.find_site(rng, 16.0, 200.0)
	var lz_out: Vector3 = planner.find_site(rng, 16.0, 200.0)
	p["insertion_lz"] = lz_in
	p["exfil_lz"] = lz_out
	p["village_center"] = village
	var defender_count: int = rng.randi_range(6, 10)
	p.enemy_groups.append({"pos": village, "count": defender_count, "tag": "village_defenders", "lazy": false, "spread": 22.0})
	p.objectives.append({"kind": "plant", "pos": Vector3.ZERO, "title": "DESTROY WEAPONS CACHE", "index": 0, "required": true})  # pos resolved at build from stamped cache
	p.objectives.append({"kind": "kill", "title": "CLEAR THE VILLAGE", "index": 1, "required": true, "tag": "village_defenders", "count": defender_count, "fraction": 0.8})
	p["sites"] = [{"kind": "village", "center": village}, {"kind": "lz", "center": lz_in}, {"kind": "lz", "center": lz_out}]
	p["cas_budget"] = 1
	p["intel"] = "VC squad garrisons the ville. Arms cache concealed nearby. %d-%d fighters estimated." % [defender_count - 2, defender_count + 3]


static func _plan_firebase(world: GameWorld, rng: RandomNumberGenerator, planner: SitePlanner, p: Dictionary) -> void:
	var firebase: Vector3 = planner.find_site(rng, 44.0, 200.0)
	p["firebase_center"] = firebase
	p["insertion_lz"] = firebase  # you start inside the wire
	p["exfil_lz"] = firebase
	var wave_count: int = 3
	p.objectives.append({"kind": "survive", "title": "HOLD THE FIREBASE", "index": 0, "required": true, "waves": wave_count, "per_wave_min": 5, "per_wave_max": 8})
	p["sites"] = [{"kind": "firebase", "center": firebase}]
	p["cas_budget"] = 3
	p["ally_count"] = 5
	p["intel"] = "Main Force battalion probing the wire tonight. %d assault waves expected. Air support on station." % wave_count


## BUILD: stamp sites, create sensors, spawn/dormant enemy groups.
## Returns {"exfil_zone": ExfilZone, "sensors": Array, "sites": Array[Dictionary]}
static func build(world: GameWorld, director: MissionDirector, p: Dictionary) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(p.seed) + 777
	var planner := SitePlanner.new(world.gameplay_grid, world.terrain_manager, world.vegetation_manager, world)
	director.state.mission_type = str(p.type_name)
	director.state.seed_value = int(p.seed)

	var built_sites: Array[Dictionary] = []
	var cache_node: Node3D = null
	for site in p.sites:
		match str(site.kind):
			"village":
				var v: Dictionary = planner.stamp_village(site.center, rng)
				built_sites.append(v)
				cache_node = v.cache
			"firebase":
				built_sites.append(planner.stamp_firebase(site.center, rng))
			"lz":
				built_sites.append(planner.stamp_lz(site.center))
			"vc_props":
				planner.place_structure(SiteLayouts.CACHE_MODEL, site.center, rng.randf_range(0, 360))
				planner.place_structure(SiteLayouts.TUNNEL_MODEL, site.center + Vector3(4, 0, 3), 0.0)

	var sensors: Array = []
	for obj in p.objectives:
		match str(obj.kind):
			"reach":
				var reach := ReachZone.new()
				reach.objective_index = int(obj.index)
				reach.title = str(obj.title)
				reach.required = bool(obj.required)
				world.add_child(reach)
				reach.global_position = _seat(world, obj.pos)
				reach.register(director)
				sensors.append(reach)
			"plant":
				var plant := PlantCharge.new()
				plant.objective_index = int(obj.index)
				plant.title = str(obj.title)
				world.add_child(plant)
				var plant_pos: Vector3 = obj.pos
				if cache_node != null:
					plant_pos = cache_node.global_position
				plant.global_position = _seat(world, plant_pos)
				plant.register(director)
				plant.charge_planted.connect(_on_charge_planted.bind(cache_node))
				sensors.append(plant)
			"kill":
				var kc := KillCountObjective.new()
				kc.objective_index = int(obj.index)
				kc.title = str(obj.title)
				kc.group_tag = str(obj.tag)
				kc.total_count = int(obj.count)
				kc.required_fraction = float(obj.get("fraction", 0.8))
				world.add_child(kc)
				kc.register(director)
				sensors.append(kc)
			"survive":
				pass  # SurviveWaves attached in NS12

	for group in p.enemy_groups:
		if bool(group.get("lazy", false)):
			var lg := LazyGroup.new()
			lg.enemy_count = int(group.count)
			lg.group_tag = str(group.tag)
			lg.setup(director, int(p.seed) + hash(str(group.tag)))
			world.add_child(lg)
			lg.global_position = _seat(world, group.pos)
		else:
			var spread: float = float(group.get("spread", 12.0))
			for i in range(int(group.count)):
				var a := rng.randf_range(0.0, TAU)
				var r := rng.randf_range(3.0, spread)
				var pos: Vector3 = group.pos + Vector3(cos(a) * r, 0.0, sin(a) * r)
				var data: String = ENEMY_DATA[rng.randi() % ENEMY_DATA.size()]
				var enemy := director.spawn_tracked_enemy(pos, data, str(group.tag))
				enemy.add_to_group(str(group.tag))

	var exfil := ExfilZone.new()
	world.add_child(exfil)
	exfil.global_position = _seat(world, p.exfil_lz)
	exfil.register(director)

	var watchdog := TerrainWatchdog.new()
	world.add_child(watchdog)
	watchdog.setup(world.terrain_manager)

	return {"exfil_zone": exfil, "sensors": sensors, "sites": built_sites}


static func _seat(world: GameWorld, pos: Vector3) -> Vector3:
	return Vector3(pos.x, world.terrain_manager.get_height_at(pos), pos.z)


## Planted demo charge detonates: real crater + the cache prop dies.
static func _on_charge_planted(at_position: Vector3, cache_node: Node3D) -> void:
	DamageSystem.apply_damage(at_position, DamageSystem.DamageType.MEDIUM_EXPLOSION, 1.0)
	CombatManager.apply_explosion_damage(at_position, 120, 30, 8.0, null)
	if cache_node != null and is_instance_valid(cache_node):
		cache_node.queue_free()
