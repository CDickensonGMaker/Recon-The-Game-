## mission_generator.gd - seed + type -> MissionPlan (positions/flavor, pure),
## then build() stamps sites, sensors, and enemy groups into a GameWorld (NS09).
class_name MissionGenerator
extends RefCounted

enum MissionType { PATROL, VILLAGE_RAID, FIREBASE_DEFENSE, ANTI_AA, RESCUE }

const TYPE_NAMES := {
	MissionType.PATROL: "PATROL",
	MissionType.VILLAGE_RAID: "VILLAGE RAID",
	MissionType.FIREBASE_DEFENSE: "FIREBASE DEFENSE",
	MissionType.ANTI_AA: "ANTI-AA SWEEP",
	MissionType.RESCUE: "POW RESCUE",
}

const CODENAME_A: Array[String] = ["SILVER", "IRON", "JUNGLE", "DUSTY", "BROKEN", "SHADOW", "COPPER", "MIDNIGHT", "RED", "LONG"]
const CODENAME_B: Array[String] = ["LANCE", "TIGER", "ARROW", "SABRE", "HAMMER", "SERPENT", "TALON", "BUFFALO", "DAGGER", "PYTHON"]

## Vietnam enemy set. Each archetype's sprite holds the weapon its .tres names.
const ENEMY_DATA: Array[String] = [
	# Weighted by repetition: the pool is sampled uniformly, so a bare list of five
	# archetypes would put an RPG in one hand out of five. Local Force are the
	# bulk; the rocketeer is the exception you remember.
	"res://data/enemies/vc_farmer.tres",
	"res://data/enemies/vc_farmer.tres",
	"res://data/enemies/vc_farmer.tres",
	"res://data/enemies/vc_rifleman.tres",
	"res://data/enemies/vc_rifleman.tres",
	"res://data/enemies/nva_regular.tres",
	"res://data/enemies/nva_regular.tres",
	"res://data/enemies/vc_sapper.tres",
	"res://data/enemies/nva_rpg.tres",
]


const WEATHER_TABLE: Array[String] = ["CLEAR", "CLEAR", "CLEAR", "CLOUDY", "CLOUDY", "RAIN", "RAIN", "FOG", "MONSOON", "CLEAR"]
const TIME_TABLE: Array[String] = ["DAY", "DAY", "DAY", "DAY", "DAWN", "DUSK", "NIGHT", "NIGHT", "DAY", "DUSK"]

## R79: 0-2 complications per mission. Each has a real mechanical bite (applied
## in build()), not just flavor text - see offer cards / briefing for the tell.
const COMPLICATIONS: Array[String] = [
	"BAD INTEL", "REINFORCED GARRISON", "NO AIR SUPPORT", "HEAVY FOG ROLLING IN", "AA THREAT SPIKE",
]


## Derived on its own draw stream (offset seed) so offer cards/briefings can
## show complications without touching plan()'s exact draw-order contract.
static func complications_for(seed_value: int) -> Array[String]:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value + 7919
	var roll: float = rng.randf()
	var count: int = 0
	if roll > 0.55:
		count = 1
	if roll > 0.85:
		count = 2
	var pool: Array[String] = COMPLICATIONS.duplicate()
	var picked: Array[String] = []
	for _i in range(count):
		if pool.is_empty():
			break
		var idx: int = rng.randi() % pool.size()
		picked.append(pool[idx])
		pool.remove_at(idx)
	return picked


## Codename derivable without a world (briefing screens) - MUST match plan()'s
## first two rng draws.
static func codename_for(seed_value: int) -> String:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return "OPERATION %s %s" % [CODENAME_A[rng.randi() % CODENAME_A.size()], CODENAME_B[rng.randi() % CODENAME_B.size()]]


## Weather/time rolls: draws 3 and 4 in the seed sequence (after codename's 2).
static func conditions_for(seed_value: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	rng.randi()
	rng.randi()
	return {
		"weather": WEATHER_TABLE[rng.randi() % WEATHER_TABLE.size()],
		"time": TIME_TABLE[rng.randi() % TIME_TABLE.size()],
	}


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
		"weather": WEATHER_TABLE[rng.randi() % WEATHER_TABLE.size()],
		"time": TIME_TABLE[rng.randi() % TIME_TABLE.size()],
		"objectives": [],
		"enemy_groups": [],
		"sites": [],
		"fire_support": {"mortar": 1},
	}
	match type:
		MissionType.PATROL:
			_plan_patrol(world, rng, planner, p)
		MissionType.VILLAGE_RAID:
			_plan_village(world, rng, planner, p)
		MissionType.FIREBASE_DEFENSE:
			_plan_firebase(world, rng, planner, p)
		MissionType.ANTI_AA:
			_plan_anti_aa(world, rng, planner, p)
		MissionType.RESCUE:
			_plan_rescue(world, rng, planner, p)
	p["complications"] = complications_for(seed_value)
	return p


static func _plan_rescue(world: GameWorld, rng: RandomNumberGenerator, planner: SitePlanner, p: Dictionary) -> void:
	var camp: Vector3 = planner.find_site(rng, 22.0, 200.0)
	var lz_in: Vector3 = planner.find_site(rng, 16.0, 200.0)
	var lz_out: Vector3 = planner.find_site(rng, 16.0, 200.0)
	p["insertion_lz"] = lz_in
	p["exfil_lz"] = lz_out
	p["camp_center"] = camp
	var guard_count: int = rng.randi_range(5, 8)
	p.enemy_groups.append({"pos": camp, "count": guard_count, "tag": "pow_guards", "lazy": false, "spread": 16.0})
	p.objectives.append({"kind": "rescue", "pos": camp, "title": "FREE THE POW", "index": 0, "required": true})
	p["start_pad"] = _passable_near(world, rng, lz_in, 450.0, 750.0)
	p["sites"] = [{"kind": "pow_camp", "center": camp}, {"kind": "lz", "center": lz_in}, {"kind": "lz", "center": lz_out}, {"kind": "lz", "center": p.start_pad}]
	p["fire_support"] = {"napalm": 1, "mortar": 1}
	p["intel"] = "Downed aviator held at a jungle camp. %d guards estimated. Bring him home." % guard_count


static func _plan_anti_aa(world: GameWorld, rng: RandomNumberGenerator, planner: SitePlanner, p: Dictionary) -> void:
	var lz_in: Vector3 = planner.find_site(rng, 16.0, 200.0)
	var lz_out: Vector3 = planner.find_site(rng, 16.0, 200.0)
	p["insertion_lz"] = lz_in
	p["exfil_lz"] = lz_out
	var site_count: int = rng.randi_range(2, 3)
	var aa_centers: Array = []
	for i in range(site_count):
		var c: Vector3 = planner.find_site(rng, 12.0, 180.0)
		aa_centers.append(c)
		p.objectives.append({"kind": "plant", "pos": c, "title": "DESTROY AA GUN %s" % char(65 + i), "index": i, "required": true, "aa_index": i})
		p.enemy_groups.append({"pos": c, "count": rng.randi_range(3, 4), "tag": "aa_crew_%d" % i, "lazy": false, "spread": 10.0})
	p["aa_centers"] = aa_centers
	p["start_pad"] = _passable_near(world, rng, lz_in, 450.0, 750.0)
	p["sites"] = [{"kind": "lz", "center": lz_in}, {"kind": "lz", "center": lz_out}, {"kind": "lz", "center": p.start_pad}]
	for c in aa_centers:
		p.sites.append({"kind": "aa_site", "center": c})
	p["fire_support"] = {"mortar": 1}
	p["is_anti_aa"] = true
	p["intel"] = "Enemy AA battery is bleeding our birds. Satchel every gun. %d sites plotted." % site_count


## R72: a shallow, muddy water disc sitting in an old crater bowl.
static func _spawn_crater_water(world: GameWorld, pos: Vector3, rng: RandomNumberGenerator) -> void:
	var disc := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	var r: float = rng.randf_range(3.0, 5.0)
	cyl.top_radius = r
	cyl.bottom_radius = r
	cyl.height = 0.05
	disc.mesh = cyl
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.22, 0.28, 0.2, 0.8)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.roughness = 0.15
	mat.metallic = 0.1
	disc.material_override = mat
	world.add_child(disc)
	var ground_y: float = world.terrain_manager.get_height_at(pos)
	disc.global_position = Vector3(pos.x, ground_y + 0.05, pos.z)


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
	# Optional bonus: locate the cache, or photograph it (W64) - 50/50.
	var cache_pos := _passable_near(world, rng, cursor, 80.0, 160.0)
	p["cache_pos"] = cache_pos
	if rng.randf() < 0.5:
		p.objectives.append({"kind": "photo", "pos": cache_pos, "title": "PHOTOGRAPH VC CACHE (BONUS)", "index": index, "required": false})
	else:
		p.objectives.append({"kind": "reach", "pos": cache_pos, "title": "LOCATE VC CACHE (BONUS)", "index": index, "required": false})
	index += 1
	p["exfil_lz"] = planner.find_site(rng, 16.0, 150.0)
	p["start_pad"] = _passable_near(world, rng, lz_in, 450.0, 750.0)
	p["sites"] = [{"kind": "lz", "center": lz_in}, {"kind": "lz", "center": p.exfil_lz}, {"kind": "lz", "center": p.start_pad}, {"kind": "vc_props", "center": cache_pos}]
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
	# 50/50 target variant: hidden arms cache vs captured APC (objective variety).
	var target_is_vehicle: bool = rng.randf() < 0.5
	p["village_target"] = "vehicle" if target_is_vehicle else "cache"
	var target_title := "DESTROY THE CAPTURED APC" if target_is_vehicle else "DESTROY WEAPONS CACHE"
	p.objectives.append({"kind": "plant", "pos": Vector3.ZERO, "title": target_title, "index": 0, "required": true})  # pos resolved at build
	p.objectives.append({"kind": "kill", "title": "CLEAR THE VILLAGE", "index": 1, "required": true, "tag": "village_defenders", "count": defender_count, "fraction": 0.8})
	p["start_pad"] = _passable_near(world, rng, lz_in, 450.0, 750.0)
	p["sites"] = [{"kind": "village", "center": village}, {"kind": "lz", "center": lz_in}, {"kind": "lz", "center": lz_out}, {"kind": "lz", "center": p.start_pad}]
	p["fire_support"] = {"bombs": 1, "napalm": 1, "mortar": 2}
	p["intel"] = "VC squad garrisons the ville. Arms cache concealed nearby. %d-%d fighters estimated." % [defender_count - 2, defender_count + 3]


static func _plan_firebase(world: GameWorld, rng: RandomNumberGenerator, planner: SitePlanner, p: Dictionary) -> void:
	var firebase: Vector3 = planner.find_site(rng, 44.0, 200.0)
	p["firebase_center"] = firebase
	p["insertion_lz"] = firebase  # you start inside the wire
	p["exfil_lz"] = firebase
	var wave_count: int = 3
	p.objectives.append({"kind": "survive", "title": "HOLD THE FIREBASE", "index": 0, "required": true, "waves": wave_count, "per_wave_min": 5, "per_wave_max": 8})
	p["sites"] = [{"kind": "firebase", "center": firebase}]
	p["fire_support"] = {"bombs": 2, "napalm": 1, "arty": 2, "mortar": 3, "spooky": 1, "cbu": 1}
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
	var fs: Dictionary = p.get("fire_support", {"mortar": 1})
	for k in fs.keys():
		director.fire_support[k] = int(fs[k])

	if bool(p.get("is_anti_aa", false)):
		director.state.flags["is_anti_aa"] = true

	# R79: mission complications - real mechanical effects, not just flavor.
	var comps: Array = p.get("complications", [])
	director.state.flags["complications"] = comps
	if "NO AIR SUPPORT" in comps:
		for k2 in director.fire_support.keys():
			if k2 != "mortar":
				director.fire_support[k2] = 0
	if "REINFORCED GARRISON" in comps:
		director._hunter_pool += 6
	if "HEAVY FOG ROLLING IN" in comps:
		p["weather"] = "FOG"
	if "AA THREAT SPIKE" in comps:
		CampaignState.add_threat_modifier(0.25, 1, "complication: AA threat spike")

	var built_sites: Array[Dictionary] = []
	var cache_node: Node3D = null
	var aa_guns: Array[Node3D] = []
	for site in p.sites:
		match str(site.kind):
			"pow_camp":
				# Small guard camp: two hootches + cage spot (RescueObjective adds the cage).
				planner.clear_and_flatten(site.center, 18.0)
				planner.place_structure("res://assets/building models/structures/firebase/hootch.glb", site.center + Vector3(-8, 0, -4), 20.0)
				planner.place_structure("res://assets/building models/structures/firebase/hootch.glb", site.center + Vector3(7, 0, -6), -35.0)
				planner.place_structure("res://assets/building models/structures/vc_nva/tunnel_entrance_hidden.glb", site.center + Vector3(0, 0, 9), 0.0)
			"aa_site":
				var aa: Dictionary = planner.stamp_aa_site(site.center, rng)
				built_sites.append(aa)
				aa_guns.append(aa.gun)
			"village":
				var v: Dictionary = planner.stamp_village(site.center, rng)
				built_sites.append(v)
				cache_node = v.cache
				# W47: villagers (one may be an informer). W56: night cooking fire.
				var civ_count: int = rng.randi_range(3, 5)
				var informer_idx: int = rng.randi() % civ_count if rng.randf() < 0.5 else -1
				for ci in range(civ_count):
					var ca := rng.randf_range(0.0, TAU)
					var cpos: Vector3 = site.center + Vector3(cos(ca), 0, sin(ca)) * rng.randf_range(2.0, 12.0)
					cpos.y = world.terrain_manager.get_height_at(cpos) + 0.5
					Civilian.spawn(world, cpos, director, ci == informer_idx)
				if str(p.get("time", "DAY")) in ["NIGHT", "DUSK", "DAWN"]:
					_add_campfire(world, site.center + Vector3(2, 0, 2))
				# W78: chickens - live noise traps.
				for _ck in range(rng.randi_range(2, 4)):
					var ka := rng.randf_range(0.0, TAU)
					var kpos: Vector3 = site.center + Vector3(cos(ka), 0, sin(ka)) * rng.randf_range(3.0, 10.0)
					kpos.y = world.terrain_manager.get_height_at(kpos) + 0.3
					_add_chicken(world, kpos)
				if str(p.get("village_target", "cache")) == "vehicle":
					# Swap the cache for a captured APC at the same spot.
					var cache_pos: Vector3 = (v.cache as Node3D).global_position
					(v.cache as Node3D).queue_free()
					cache_node = DestructibleVehicle.create(world,
						"res://assets/building models/vehicles/m113_apc.glb",
						cache_pos, rng.randf_range(0, 360), world.terrain_manager)
			"firebase":
				built_sites.append(planner.stamp_firebase(site.center, rng))
			"lz":
				# PT6: the staging pad is a friendly outpost, not bare dirt.
				if p.has("start_pad") and (site.center as Vector3).distance_to(p.start_pad) < 1.0:
					built_sites.append(planner.stamp_outpost(site.center, rng))
				else:
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
				# Target: AA gun (by index), else the village cache/APC.
				var plant_target: Node3D = cache_node
				var plant_pos: Vector3 = obj.pos
				if obj.has("aa_index") and int(obj.aa_index) < aa_guns.size():
					plant_target = aa_guns[int(obj.aa_index)]
				if plant_target != null:
					plant_pos = plant_target.global_position
				plant.global_position = _seat(world, plant_pos)
				# W28: Demolitions skill plants faster.
				plant.plant_seconds = 4.0 / (1.0 + 0.15 * float(CampaignState.roster_skill("GRENADIER", "demolitions")))
				plant.is_trapped = rng.randf() < 0.3  # W52
				plant.register(director)
				plant.charge_planted.connect(_on_charge_planted.bind(plant_target))
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
			"photo":
				var photo := PhotoObjective.new()
				photo.objective_index = int(obj.index)
				photo.title = str(obj.title)
				photo.required = bool(obj.required)
				world.add_child(photo)
				photo.global_position = _seat(world, obj.pos)
				photo.register(director)
				sensors.append(photo)
			"rescue":
				var rescue := RescueObjective.new()
				rescue.objective_index = int(obj.index)
				rescue.title = str(obj.title)
				world.add_child(rescue)
				rescue.global_position = _seat(world, obj.pos)
				rescue.register(director)
				rescue.setup_camp(world)
				sensors.append(rescue)
			"survive":
				var sw := SurviveWaves.new()
				sw.objective_index = int(obj.index)
				sw.title = str(obj.title)
				sw.wave_count = int(obj.get("waves", 3))
				sw.per_wave_min = int(obj.get("per_wave_min", 5))
				sw.per_wave_max = int(obj.get("per_wave_max", 8))
				sw.lull_seconds = float(obj.get("lull", 20.0))
				sw.initial_delay = float(obj.get("initial_delay", 12.0))
				world.add_child(sw)
				sw.global_position = _seat(world, p.firebase_center)
				sw.register(director)
				sw.start(world, int(p.seed) + 4444)
				sensors.append(sw)

	# Squad spawning is owned by SquadSystem (W13) - GameFlow attaches it.

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

	# R64/R66: village raids and firebase defense get a nasty surprise or two.
	if int(p.type) == MissionType.VILLAGE_RAID or int(p.type) == MissionType.FIREBASE_DEFENSE:
		var anchor: Vector3 = p.get("village_center", p.get("firebase_center", p.insertion_lz))
		for i in range(rng.randi_range(1, 2)):
			var a3 := rng.randf_range(0.0, TAU)
			var hole_pos: Vector3 = anchor + Vector3(cos(a3), 0, sin(a3)) * rng.randf_range(8.0, 20.0)
			var hole := director.spawn_tracked_enemy(hole_pos, ENEMY_DATA[rng.randi() % ENEMY_DATA.size()], "spider_hole")
			hole.is_spider_hole = true
	if int(p.type) == MissionType.FIREBASE_DEFENSE:
		var mortar_pos: Vector3 = _passable_near(world, rng, p.firebase_center, 90.0, 160.0)
		EnemyMortarTeam.spawn(world, mortar_pos, director, int(p.seed) + 555, ENEMY_DATA)

	# W04: at HIGH campaign threat, opportunistic AA positions appear near the LZs.
	# 4b: these draws are CONDITIONAL ON CAMPAIGN STATE. Taking them from the
	# shared `rng` shifted everything generated afterwards, so the same seed built
	# a different AO at threat 0.4 vs 0.6. Give them their own stream.
	var aa_rng := RandomNumberGenerator.new()
	aa_rng.seed = int(p.seed) + 31337
	if not bool(p.get("is_anti_aa", false)) and CampaignState.effective_threat() >= 0.5:
		var aa_count: int = 1 if CampaignState.effective_threat() < 0.75 else 2
		var anchors := [p.insertion_lz, p.exfil_lz]
		for i in range(aa_count):
			var near: Vector3 = anchors[i % anchors.size()]
			var pos := _passable_near(world, aa_rng, near, 150.0, 260.0)
			var aa2: Dictionary = planner.stamp_aa_site(pos, aa_rng)
			built_sites.append(aa2)
			(aa2.gun as DestructibleVehicle).destroyed.connect(func(_v: DestructibleVehicle) -> void:
				director.state.flags["aa_killed"] = int(director.state.flags.get("aa_killed", 0)) + 1
				director.toast.emit("AA GUN DESTROYED - THE NEXT BIRD THANKS YOU"))
			for j in range(2):
				var crew := director.spawn_tracked_enemy(pos + Vector3(2.0 + float(j) * 2.0, 0, 1.5), ENEMY_DATA[aa_rng.randi() % ENEMY_DATA.size()], "aa_opportunistic")
				crew.add_to_group("aa_opportunistic")

	# PT4: ambient life so the walk is never dead - extra villages + patrols
	# along the insertion->objective corridor (not on firebase defense).
	if p.has("start_pad"):
		var corridor_a: Vector3 = p.insertion_lz
		var corridor_b: Vector3 = p.exfil_lz
		if p.objectives.size() > 0 and p.objectives[0].has("pos") and p.objectives[0].pos != Vector3.ZERO:
			corridor_b = p.objectives[0].pos
		# 1-2 ambient villages (no objectives; a few civvies, maybe a lazy defender pair).
		for _av in range(rng.randi_range(1, 2)):
			var vc: Vector3 = planner.find_site(rng, 24.0, 150.0)
			if vc == Vector3.ZERO:
				continue
			var av_site: Dictionary = planner.stamp_village(vc, rng)
			built_sites.append(av_site)
			for ci in range(rng.randi_range(2, 3)):
				var ca2 := rng.randf_range(0.0, TAU)
				var cpos2: Vector3 = vc + Vector3(cos(ca2), 0, sin(ca2)) * rng.randf_range(2.0, 10.0)
				cpos2.y = world.terrain_manager.get_height_at(cpos2) + 0.5
				Civilian.spawn(world, cpos2, director, rng.randf() < 0.3)
			if rng.randf() < 0.5:
				var lg_v := LazyGroup.new()
				lg_v.enemy_count = 2
				lg_v.group_tag = "ambient_village_guard"
				lg_v.setup(director, int(p.seed) + hash(vc))
				world.add_child(lg_v)
				lg_v.global_position = _seat(world, vc + Vector3(10, 0, 5))
		# Ancient temple ruin POI, ~50% of missions (landmark + shrine loot).
		if rng.randf() < 0.5:
			var tc: Vector3 = planner.find_site(rng, 15.0, 150.0)
			if tc != Vector3.ZERO:
				built_sites.append(planner.stamp_temple_ruin(tc, rng))

		# R72: old B-52 arclight craters, scattered before you ever touched down -
		# some have gone stagnant with rainwater.
		for _oc in range(rng.randi_range(2, 4)):
			var oc_t: float = rng.randf()
			var oc_center: Vector3 = corridor_a.lerp(corridor_b, oc_t)
			var oc_pos: Vector3 = _passable_near(world, rng, oc_center, 30.0, 220.0)
			if oc_pos == Vector3.ZERO:
				continue
			DamageSystem.apply_damage(oc_pos, DamageSystem.DamageType.LARGE_EXPLOSION, rng.randf_range(0.8, 1.3))
			if rng.randf() < 0.4:
				_spawn_crater_water(world, oc_pos, rng)

		# 2-3 wandering patrols along the corridor.
		for pi in range(rng.randi_range(2, 3)):
			var t_frac: float = rng.randf_range(0.2, 0.8)
			var mid: Vector3 = corridor_a.lerp(corridor_b, t_frac)
			var ppos := _passable_near(world, rng, mid, 40.0, 140.0)
			var lg_p := LazyGroup.new()
			lg_p.enemy_count = rng.randi_range(2, 4)
			lg_p.group_tag = "ambient_patrol_%d" % pi
			lg_p.activation_range = 140.0
			lg_p.setup(director, int(p.seed) + 31 * pi)
			world.add_child(lg_p)
			lg_p.global_position = _seat(world, ppos)

	var exfil := ExfilZone.new()
	exfil.use_bird = true
	exfil.complete_on_enter = false
	exfil.world = world
	world.add_child(exfil)
	exfil.global_position = _seat(world, p.exfil_lz)
	exfil.register(director)
	director.exfil_zone = exfil
	# Fallback (final) LZ: pre-planned secondary 300-600m from the primary.
	var fb := _passable_near(world, rng, p.exfil_lz, 300.0, 600.0)
	planner.stamp_lz(fb)

	# NAV: after every stamp (built_sites is complete, including the opportunistic
	# AA sites) and after the R72 pre-existing craters have already mutated the
	# heightmap - so the nav surface matches the final terrain for free.
	var nav_baker: NavBaker = null
	if WorldConfig.NAV_ENABLED:
		nav_baker = NavBaker.new()
		nav_baker.name = "NavBaker"
		world.add_child(nav_baker)
		nav_baker.setup(world.terrain_manager)
		nav_baker.queue_sites(built_sites, _enemy_anchors(p))

	exfil.fallback_pos = fb

	var watchdog := TerrainWatchdog.new()
	world.add_child(watchdog)
	watchdog.setup(world.terrain_manager)

	return {"exfil_zone": exfil, "sensors": sensors, "sites": built_sites}


static func _seat(world: GameWorld, pos: Vector3) -> Vector3:
	return Vector3(pos.x, world.terrain_manager.get_height_at(pos), pos.z)


## W56: flickering campfire - a beacon you can read at range at night.
static func _add_campfire(world: GameWorld, pos: Vector3) -> void:
	var fire := Node3D.new()
	world.add_child(fire)
	fire.global_position = _seat(world, pos) + Vector3(0, 0.3, 0)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.6, 0.25)
	light.light_energy = 1.8
	light.omni_range = 14.0
	fire.add_child(light)
	var particles := CPUParticles3D.new()
	particles.amount = 14
	particles.lifetime = 1.4
	particles.direction = Vector3.UP
	particles.initial_velocity_min = 1.0
	particles.initial_velocity_max = 2.2
	particles.scale_amount_min = 0.08
	particles.scale_amount_max = 0.2
	particles.color = Color(1.0, 0.55, 0.15, 0.8)
	fire.add_child(particles)
	# Flicker.
	var flicker := Timer.new()
	flicker.wait_time = 0.12
	flicker.autostart = true
	fire.add_child(flicker)
	flicker.timeout.connect(func() -> void: light.light_energy = randf_range(1.4, 2.2))


## W78: chickens - they scatter loudly when anyone gets close. Noise traps.
static func _add_chicken(world: GameWorld, pos: Vector3) -> void:
	var chicken := Node3D.new()
	world.add_child(chicken)
	chicken.global_position = _seat(world, pos) + Vector3(0, 0.2, 0)
	var mesh := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.15
	sphere.height = 0.3
	mesh.mesh = sphere
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.9, 0.88, 0.8)
	mesh.material_override = mat
	chicken.add_child(mesh)
	var scan := Timer.new()
	scan.wait_time = 0.6
	scan.autostart = true
	chicken.add_child(scan)
	scan.timeout.connect(func() -> void:
		if chicken.has_meta("spooked"):
			return
		for body_group in ["player", "enemies", "allies"]:
			for b in chicken.get_tree().get_nodes_in_group(body_group):
				var n := b as Node3D
				if n and n.global_position.distance_to(chicken.global_position) < 3.0:
					chicken.set_meta("spooked", true)
					NoiseBus.emit_noise(NoiseBus.NoiseType.VOICE, chicken.global_position, 0, 25.0)
					var flee := (chicken.global_position - n.global_position).normalized()
					var tween := chicken.create_tween()
					tween.tween_property(chicken, "global_position",
						chicken.global_position + flee * 8.0 + Vector3(0, 0.1, 0), 1.2)
					tween.tween_callback(func() -> void: chicken.remove_meta("spooked"))
					return)


## Planted demo charge detonates: real crater + the target prop dies.
static func _on_charge_planted(at_position: Vector3, cache_node: Node3D) -> void:
	if cache_node is DestructibleVehicle:
		(cache_node as DestructibleVehicle).destroy()
		return
	DamageSystem.apply_damage(at_position, DamageSystem.DamageType.MEDIUM_EXPLOSION, 1.0)
	CombatManager.apply_explosion_damage(at_position, 120, 30, 8.0, null)
	if cache_node != null and is_instance_valid(cache_node):
		cache_node.queue_free()


## Where the fighting will be. NavBaker bakes a site only if someone is near it.
static func _enemy_anchors(p: Dictionary) -> Array[Vector3]:
	var out: Array[Vector3] = []
	for g in p.get("enemy_groups", []):
		var d: Dictionary = g
		out.append(d.get("pos", Vector3.ZERO))
	for key in ["firebase_center", "camp_center", "village_center"]:
		if p.has(key):
			out.append(p[key])
	return out


## THE HUB (Phase B): the operation's home firebase - a PLACE, not a mission.
## No objectives, no enemies. Stamped deterministically from the operation seed
## so every return lands on the same base. The HQ tent (TOC) is guaranteed.
static func build_hub(world: GameWorld, operation_seed: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = operation_seed + 4242
	var planner := SitePlanner.new(world.gameplay_grid, world.terrain_manager, world.vegetation_manager, world)
	var center: Vector3 = planner.find_site(rng, 44.0)
	center.y = world.terrain_manager.get_height_at(center)
	var site: Dictionary = planner.stamp_firebase(center, rng)
	# Guaranteed, deterministic HQ tent (the random firebase extras are not reliable).
	var tent: Node3D = planner.place_structure(
		"res://assets/building models/structures/firebase/toc.glb",
		center + Vector3(8, 0, -10), 180.0)
	tent.add_to_group("hq_tent")
	# The bird waits beside the pad (clear of the parked Chinook prop).
	var huey: Node3D = (load("res://scenes/vehicles/huey.tscn") as PackedScene).instantiate()
	world.add_child(huey)
	var pad: Vector3 = site.helipad + Vector3(7, 0, 6)
	pad.y = world.terrain_manager.get_height_at(pad) + 0.5
	huey.global_position = pad
	return {"center": center, "tent": tent, "huey": huey, "helipad": site.helipad}
