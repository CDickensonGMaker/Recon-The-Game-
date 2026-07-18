## mission_generator.gd - seed + type -> MissionPlan (positions/flavor, pure),
## then build() stamps sites, sensors, and enemy groups into a GameWorld (NS09).
class_name MissionGenerator
extends RefCounted

const ARMORERS_BENCH := preload("res://scripts/levels/armorers_bench.gd")
const PaddyStamperScript := preload("res://scripts/world/paddy_stamper.gd")
const WorkingPointResolverScript := preload("res://scripts/world/working_point_resolver.gd")
const CivilianSchedulesScript := preload("res://scripts/ai/civilian_schedules.gd")
const CivilianScript := preload("res://scripts/world/civilian.gd")
const EnemyBaseScript := preload("res://scripts/enemies/enemy_base.gd")
const PatrolGeneratorScript := preload("res://scripts/enemies/patrol_generator.gd")
const AmbushPlannerScript := preload("res://scripts/enemies/ambush_planner.gd")
const SquadLeaderScript := preload("res://scripts/enemies/squad_leader.gd")
const CampDirectorScript := preload("res://scripts/enemies/camp_director.gd")
const AirTrafficScript := preload("res://scripts/ai/air_traffic.gd")
const AmbientWarScript := preload("res://scripts/ai/ambient_war.gd")
const WeatherDirectorScript := preload("res://scripts/world/weather_director.gd")
const ConvoySpawnerScript := preload("res://scripts/missions/convoy_spawner.gd")
const DynamicMissionFactoryScript := preload("res://scripts/missions/dynamic_mission_factory.gd")

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

## 0-2 per mission. Each has a real mechanical effect, applied in build().
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
	# Terrain-first: stamp rice paddy polygons and group them into village
	# anchors BEFORE any mission-type plan. Each _plan_* may consult the anchors.
	# Determinism: PaddyStamper draws from (mission_seed + 1009) — a separate
	# stream from the primary rng so reordering _plan_* calls does not move
	# paddy positions.
	var paddy_result: Dictionary = PaddyStamperScript.stamp(
		seed_value, world.gameplay_grid, world.terrain_manager, world
	)
	p["paddy_fields"] = paddy_result.paddies
	p["village_anchors"] = paddy_result.village_anchors
	p["paddy_centroids"] = paddy_result.paddy_centroids
	# Pass the centroids through to the planner so its _reserved list sees them
	# and find_site's extra_reject arg can keep firebases away from paddies.
	for c: Vector3 in paddy_result.paddy_centroids:
		planner._reserved.append(c)
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
	# complications_for draws from a derived stream (seed_value + 7919). Call it
	# AFTER the type is decided so the stream is stable across mission-type
	# reorders — pre-match, an early-return would skip it.
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


## A shallow, muddy water disc sitting in an old crater bowl.
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
		if rng.randf() < 0.6:
			var contact_pos := _passable_near(world, rng, cursor, 20.0, 60.0)
			p.enemy_groups.append({"pos": contact_pos, "count": rng.randi_range(2, 4), "tag": "patrol_contact_%d" % i, "lazy": true})
	# Optional bonus: locate the cache, or photograph it - 50/50.
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
	# Village center is the first paddy-anchored village center produced by
	# PaddyStamper at the top of plan(). terrain-first: the village sits on a
	# paddy margin, not on a random find_site() punt. The corresponding
	# working_points are stamped on the village site for the activity system
	# (separate PR) to read.
	var anchors: Array = p.get("village_anchors", [])
	if anchors.is_empty():
		push_error("MissionGenerator: VILLAGE_RAID with zero paddy-anchored villages; AO is paddy-poor and plan() cannot satisfy this mission type.")
		var lz_in_zero: Vector3 = planner.find_site(rng, 16.0, 200.0)
		var lz_out_zero: Vector3 = planner.find_site(rng, 16.0, 200.0)
		p["insertion_lz"] = lz_in_zero
		p["exfil_lz"] = lz_out_zero
		p["village_center"] = Vector3.ZERO
		p["start_pad"] = _passable_near(world, rng, lz_in_zero, 450.0, 750.0)
		p["sites"] = [{"kind": "lz", "center": lz_in_zero}, {"kind": "lz", "center": lz_out_zero}, {"kind": "lz", "center": p.start_pad}]
		p["intel"] = "VILLAGE_RAID aborted: AO has no paddy terrain. Load a different seed."
		return
	var anchor: Dictionary = anchors[0]
	var village: Vector3 = anchor.center
	var village_working_points: Array[NodePath] = anchor.working_points
	var lz_in: Vector3 = planner.find_site(rng, 16.0, 200.0)
	var lz_out: Vector3 = planner.find_site(rng, 16.0, 200.0)
	p["insertion_lz"] = lz_in
	p["exfil_lz"] = lz_out
	p["village_center"] = village
	p["village_working_points"] = village_working_points
	var defender_count: int = rng.randi_range(6, 10)
	p.enemy_groups.append({"pos": village, "count": defender_count, "tag": "village_defenders", "lazy": false, "spread": 22.0})
	# 50/50 target variant: hidden arms cache vs captured APC.
	var target_is_vehicle: bool = rng.randf() < 0.5
	p["village_target"] = "vehicle" if target_is_vehicle else "cache"
	var target_title := "DESTROY THE CAPTURED APC" if target_is_vehicle else "DESTROY WEAPONS CACHE"
	p.objectives.append({"kind": "plant", "pos": Vector3.ZERO, "title": target_title, "index": 0, "required": true})  # pos resolved at build
	# CLEARING IS OPTIONAL (ADR-006, Pillar 3: stealth is never gated).
	p.objectives.append({"kind": "kill", "title": "CLEAR THE VILLAGE (OPTIONAL)", "index": 1, "required": false, "tag": "village_defenders", "count": defender_count, "fraction": 0.8})
	p["start_pad"] = _passable_near(world, rng, lz_in, 450.0, 750.0)
	p["sites"] = [{"kind": "village", "center": village, "working_points": village_working_points}, {"kind": "lz", "center": lz_in}, {"kind": "lz", "center": lz_out}, {"kind": "lz", "center": p.start_pad}]
	p["fire_support"] = {"bombs": 1, "napalm": 1, "mortar": 2}
	p["intel"] = "VC squad garrisons the ville. Arms cache concealed nearby. %d-%d fighters estimated." % [defender_count - 2, defender_count + 3]




## Patrol nodes must hang on real AO features (ADR-021) - a route that connects
## things is a route the player can learn, predict and ambush.
static func _patrol_anchors(world: GameWorld, p: Dictionary, rng: RandomNumberGenerator) -> Array[Vector3]:
	var pool: Array[Vector3] = []
	for s in p.get("sites", []):
		var site: Dictionary = s
		if site.has("center"):
			pool.append(site.center as Vector3)
	for key in ["village_center", "firebase_center", "camp_center", "insertion_lz", "exfil_lz"]:
		if p.has(key):
			pool.append(p[key] as Vector3)
	# Fill out with passable ground spread across the AO so the circuit spans the
	# map instead of hugging the objective.
	var centre: Vector3 = p.get("insertion_lz", Vector3.ZERO)
	var guard: int = 0
	while pool.size() < 10 and guard < 40:
		guard += 1
		var cand: Vector3 = _passable_near(world, rng, centre, 120.0, 480.0)
		var ok: bool = true
		for e in pool:
			if e.distance_to(cand) < 60.0:   # nodes must be far enough apart to be legs
				ok = false
				break
		if ok:
			pool.append(cand)
	return pool

static func _plan_firebase(world: GameWorld, rng: RandomNumberGenerator, planner: SitePlanner, p: Dictionary) -> void:
	# extra_reject keeps the firebase center ≥200m from any paddy centroid — a
	# firebase plowed into a rice pan is a helipad in the mud, tactically stupid.
	var paddy_centroids: Array[Vector3] = p.get("paddy_centroids", [])
	var firebase: Vector3 = planner.find_site(rng, 44.0, 200.0, paddy_centroids)
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
				var v: Dictionary = _build_village_site(world, director, planner, site, rng, str(p.get("time", "DAY")))
				built_sites.append(v)
				cache_node = v.cache
				if str(p.get("village_target", "cache")) == "vehicle":
					var cache_pos: Vector3 = (v.cache as Node3D).global_position
					(v.cache as Node3D).queue_free()
					cache_node = DestructibleVehicle.create(world,
						"res://assets/building models/vehicles/m113_apc.glb",
						cache_pos, rng.randf_range(0, 360), world.terrain_manager)
			"firebase":
				# stamp_firebase is DEAD (task 6b: fsb_main.glb is the one firebase).
				# The offer flow that plans this kind is condemned tonight (W3).
				push_warning("MissionGenerator: 'firebase' site kind is retired - fsb_main.glb is the firebase")
			"lz":
				# The staging pad is a friendly outpost, not bare dirt.
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
				plant.plant_seconds = 4.0 / (1.0 + 0.15 * float(CampaignState.roster_skill("GRENADIER", "demolitions")))
				plant.is_trapped = rng.randf() < 0.3
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

	_spawn_enemy_groups(world, director, p, rng)

	# Village raids and firebase defense get a spider hole or two.
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

	# Opportunistic AA near the LZs at high campaign threat. These draws are
	# CONDITIONAL ON CAMPAIGN STATE, so they MUST use their own rng stream - taking
	# them from the shared `rng` shifts everything generated after them and the same
	# seed builds a different AO at threat 0.4 vs 0.6.
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

	# Ambient life along the insertion->objective corridor (not on firebase defense).
	if p.has("start_pad"):
		var corridor_a: Vector3 = p.insertion_lz
		var corridor_b: Vector3 = p.exfil_lz
		if p.objectives.size() > 0 and p.objectives[0].has("pos") and p.objectives[0].pos != Vector3.ZERO:
			corridor_b = p.objectives[0].pos
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
		if rng.randf() < 0.5:
			var tc: Vector3 = planner.find_site(rng, 15.0, 150.0)
			if tc != Vector3.ZERO:
				built_sites.append(planner.stamp_temple_ruin(tc, rng))

		# Pre-existing B-52 craters, some gone stagnant with rainwater.
		for _oc in range(rng.randi_range(2, 4)):
			var oc_t: float = rng.randf()
			var oc_center: Vector3 = corridor_a.lerp(corridor_b, oc_t)
			var oc_pos: Vector3 = _passable_near(world, rng, oc_center, 30.0, 220.0)
			if oc_pos == Vector3.ZERO:
				continue
			DamageSystem.apply_damage(oc_pos, DamageSystem.DamageType.LARGE_EXPLOSION, rng.randf_range(0.8, 1.3))
			if rng.randf() < 0.4:
				_spawn_crater_water(world, oc_pos, rng)

		for pi in range(rng.randi_range(2, 3)):
			var t_frac: float = rng.randf_range(0.2, 0.8)
			var mid: Vector3 = corridor_a.lerp(corridor_b, t_frac)
			var ppos := _passable_near(world, rng, mid, 40.0, 140.0)
			var lg_p := LazyGroup.new()
			lg_p.enemy_count = rng.randi_range(2, 4)
			lg_p.group_tag = "ambient_patrol_%d" % pi
			lg_p.activation_range = 140.0
			lg_p.setup(director, int(p.seed) + 31 * pi)
			# Each patrol draws its OWN circuit (rng advances), so no two walk the same line.
			lg_p.patrol_circuit = EnemyBase.make_patrol_circuit(
				_patrol_anchors(world, p, rng), rng, rng.randi_range(5, 8))
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

	# NAV MUST bake last: after every stamp and after the craters have mutated the
	# heightmap, so the nav surface matches the final terrain.
	var nav_baker: NavBaker = null
	if WorldConfig.NAV_ENABLED:
		nav_baker = NavBaker.new()
		nav_baker.name = "NavBaker"
		world.add_child(nav_baker)
		nav_baker.setup(world.terrain_manager)
		nav_baker.queue_sites(built_sites, _enemy_anchors(p))

	# L1-L3 living-world systems: CampDirector, Convoy, AirTraffic, AmbientWar,
	# WeatherDirector, WorldSim. None of them have to wait for nav to bake; they
	# read positions and signals, not the navigation surface.
	_wire_systems(world, director, p, built_sites)

	exfil.fallback_pos = fb

	var watchdog := TerrainWatchdog.new()
	world.add_child(watchdog)
	watchdog.setup(world.terrain_manager)

	return {"exfil_zone": exfil, "sensors": sensors, "sites": built_sites}


## Wire the 20-step living-world systems at mission start. Each system is best-
## effort: a missing camp, a zero-route convoy, an empty sky, all no-op cleanly.
## Returns nothing - the world just gets richer.
static func _wire_systems(world: GameWorld, director: MissionDirector,
		p: Dictionary, built_sites: Array) -> void:
	# WorldSim: register all spawned enemies so the region grid can LOD them.
	if WorldSim != null:
		WorldSim.clear_if_needed()
		for e in director._live_enemies:
			if e == null or not is_instance_valid(e):
				continue
			WorldSim.register({
				"kind": "enemy",
				"position": e.global_position,
				"velocity": Vector3.ZERO,
				"faction": "VC",
				"schedule": {},
			})

	# CampDirector on every VC cluster: firebase defenders (if any), corridor
	# village guards, and the village-raid defenders. Each camp swaps roles by
	# SimClock.hour_advanced. We collect the garrison from director._live_enemies
	# by tag because the spawn path already exists.
	_attach_camp_directors(world, director, p)

	# Convoy: pick a random route between insertion and objective, schedule it
	# to spawn 2 sim-hours from "now" via ConvoySpawner.
	_schedule_one_convoy(world, p, int(p.get("seed", 0)))

	# AirTraffic + AmbientWar: their _ready() hooks listen to SimClock; just
	# instantiating them seeds the schedule.
	var at := AirTrafficScript.new()
	at.name = "AirTraffic"
	world.add_child(at)
	var aw := AmbientWarScript.new()
	aw.name = "AmbientWar"
	world.add_child(aw)

	# WeatherDirector: read p.weather, apply it. Day-advance re-rolls.
	var wd := WeatherDirectorScript.new()
	wd.name = "WeatherDirector"
	world.add_child(wd)
	var env: WorldEnvironment = world.get_node_or_null("WorldEnvironment")
	wd.setup(String(p.get("weather", "CLEAR")), env)

	# DynamicMissionFactory: hook to the convoy.ambushed signal so the player
	# can be offered an ESCORT when a convoy is ambushed.
	var dmf := DynamicMissionFactoryScript.new()
	dmf.name = "DynamicMissionFactory"
	world.add_child(dmf)
	dynamic_factory_ref = dmf

	# Reset SimClock to the mission's start hour. Mission params are p["time"].
	if SimClock != null:
		var t: String = String(p.get("time", "DAWN"))
		var hour: float = 6.0
		match t:
			"DAWN": hour = 6.0
			"DAY": hour = 10.0
			"DUSK": hour = 18.0
			"NIGHT": hour = 22.0
		SimClock.set_time(SimClock.sim_day, hour)


## Reference to the DynamicMissionFactory created by _wire_systems, so the
## ConvoySpawner can wire its `ambushed` signal into it. Static, so the
## spawner reads the same one.
static var dynamic_factory_ref: Node = null


## Used by ConvoySpawner when it instantiates a Convoy. Connects the convoy's
## ambushed signal to the mission factory so the player gets a dynamic offer.
static func _wire_convoy_to_factory(convoy: Node) -> void:
	if convoy != null and dynamic_factory_ref != null \
			and dynamic_factory_ref.has_signal("offer_generated") \
			and convoy.has_signal("ambushed"):
		convoy.ambushed.connect(dynamic_factory_ref._on_convoy_ambushed)


static func _attach_camp_directors(world: GameWorld, director: MissionDirector,
		p: Dictionary) -> void:
	# Group enemies by their group_tag. Each non-empty group with >=2 members
	# becomes a CampDirector centered on the group's mean position.
	var by_tag: Dictionary = {}
	for e in director._live_enemies:
		if e == null or not is_instance_valid(e):
			continue
		# We don't have direct access to group_tag on EnemyBase, so use squad_id
		# (set by spawn_tracked_enemy from group_tag hash) as a proxy.
		var tag: int = e.squad_id
		if tag < 0:
			continue
		if not by_tag.has(tag):
			by_tag[tag] = []
		by_tag[tag].append(e)
	var camp_idx: int = 0
	for tag in by_tag.keys():
		var members: Array = by_tag[tag]
		if members.size() < 2:
			continue
		var mean_pos: Vector3 = Vector3.ZERO
		for m in members:
			if m is Node3D:
				mean_pos += (m as Node3D).global_position
		mean_pos /= float(members.size())
		var cd := CampDirectorScript.new()
		cd.name = "CampDirector_%d" % camp_idx
		var crng := RandomNumberGenerator.new()
		crng.seed = int(p.get("seed", 0)) + camp_idx * 17
		# A garrison inside a village works its market props (uiho living camp).
		for s in p.get("sites", []):
			var sd: Dictionary = s
			if str(sd.get("kind", "")) == "village" and sd.has("work_stations") \
					and mean_pos.distance_to(sd.center as Vector3) <= 70.0:
				cd.work_stations = sd.get("work_stations", [])
				break
		world.add_child(cd)
		# setup() assigns guards and applies the schedule NOW - without it the
		# garrison stands in the spawn ring until the first hour tick.
		cd.setup(mean_pos, members, crng)
		camp_idx += 1
		# Patrol route for the camp's first 3 soldiers, generated procedurally.
		var paddy_centroids: Array[Vector3] = p.get("paddy_centroids", [])
		var route: Array[Vector3] = PatrolGeneratorScript.generate(
			world.gameplay_grid, mean_pos, 5, paddy_centroids, cd.rng)
		if route.size() >= 2:
			cd.set_patrol_anchor(route[1])
			# Assign the first 3 men a patrol route via EnemyBase.patrol_route.
			for i in range(mini(3, members.size())):
				var m = members[i]
				if m != null and is_instance_valid(m) and m is EnemyBaseScript:
					m.patrol_route = route
					m.patrol_file_slot = i
		# Run the AmbushPlanner against this camp. If it returns a site, store
		# it on the director's state so the player can be offered a STRIKE.
		var plan: Dictionary = AmbushPlannerScript.plan(cd, world.gameplay_grid, paddy_centroids, cd.rng)
		if not plan.is_empty():
			director.state.flags["ambush_sites"] = \
				director.state.flags.get("ambush_sites", []) + [plan]


static func _schedule_one_convoy(world: GameWorld, p: Dictionary, seed: int) -> void:
	# Pick a 2-point route near the insertion LZ. In a real mission the route
	# would be authored; for ambient flavor we draw a random 200-400m leg.
	var spawner := ConvoySpawnerScript.new()
	spawner.name = "ConvoySpawner"
	spawner.rng.seed = seed + 8888
	world.add_child(spawner)
	var origin: Vector3 = p.get("insertion_lz", Vector3.ZERO)
	var dest: Vector3 = origin + Vector3(spawner.rng.randf_range(200.0, 400.0), 0.0, spawner.rng.randf_range(-200.0, 200.0))
	var route: Array[Vector3] = [origin, dest]
	# Schedule 2 sim-hours from now. Day rolls over if we cross 24:00.
	var cur_hour: float = SimClock.sim_hour if SimClock != null else 0.0
	var fire_day: int = SimClock.sim_day if SimClock != null else 1
	if cur_hour + 2.0 >= 24.0:
		fire_day += 1
	var fire_hour: float = fposmod(cur_hour + 2.0, 24.0)
	spawner.schedule(fire_day, fire_hour, "truck", route, ["truck_m35"])


static func _seat(world: GameWorld, pos: Vector3) -> Vector3:
	return Vector3(pos.x, world.terrain_manager.get_height_at(pos), pos.z)


## Flickering campfire - a beacon you can read at range at night.
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
	var flicker := Timer.new()
	flicker.wait_time = 0.12
	flicker.autostart = true
	fire.add_child(flicker)
	flicker.timeout.connect(func() -> void: light.light_energy = randf_range(1.4, 2.2))


## Chickens scatter loudly when anyone gets close - live noise traps.
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


## ---------- THE OPEN PATROL WORLD (ADR-029 draft) ----------
## One operation seed -> the populated AO around Caleb's firebase. plan is pure
## positions (probe-able twice); build stamps. Density bands are WALKING distance,
## measured from the GATE marker: first-sign 150-300m, villages 280-450m, camps
## 400-540m, one location per quadrant - "leave the camp and go find problems."

static func plan_patrol_world(world: GameWorld, op_seed: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = op_seed + 4242
	var planner := SitePlanner.new(world.gameplay_grid, world.terrain_manager, world.vegetation_manager, world)
	var cond: Dictionary = conditions_for(op_seed)
	var p := {
		"seed": op_seed,
		"codename": codename_for(op_seed),
		"weather": cond.weather, "time": cond.time,
		"sites": [], "enemy_groups": [], "objectives": [],
		"fire_support": {"mortar": 1},
	}
	var paddy_result: Dictionary = PaddyStamperScript.stamp(
		op_seed, world.gameplay_grid, world.terrain_manager, world)
	p["paddy_fields"] = paddy_result.paddies
	p["village_anchors"] = paddy_result.village_anchors
	p["paddy_centroids"] = paddy_result.paddy_centroids
	for c: Vector3 in paddy_result.paddy_centroids:
		planner._reserved.append(c)
	var fsb_center: Vector3 = planner.plan_firebase_main_center(rng)
	var gm: Dictionary = SitePlanner.fsb_gate_metrics(fsb_center)
	var gate: Vector3 = gm.gate_pos
	p["fsb_center"] = fsb_center
	p["gate_pos"] = gate
	p["gate_out"] = gm.gate_out
	p["insertion_lz"] = gm.spawn_pos
	p["exfil_lz"] = gm.spawn_pos
	planner._fsb_rect = Rect2(fsb_center.x - SitePlanner.FSB_HALF.x,
		fsb_center.z - SitePlanner.FSB_HALF.y,
		SitePlanner.FSB_HALF.x * 2.0, SitePlanner.FSB_HALF.y * 2.0)

	# One village per quadrant - paddy-anchored where the terrain offers one.
	var villages: Array[Vector3] = []
	var anchors: Array = (p.village_anchors as Array).duplicate()
	for q in range(4):
		var q_ang: float = TAU * float(q) / 4.0 + TAU / 8.0
		var found := Vector3.ZERO
		for ai in range(anchors.size() - 1, -1, -1):
			var anchor: Dictionary = anchors[ai]
			var ac: Vector3 = anchor.center
			var d: float = Vector2(ac.x - gate.x, ac.z - gate.z).length()
			var ang: float = atan2(ac.z - gate.z, ac.x - gate.x)
			if d >= 240.0 and d <= 470.0 and absf(angle_difference(ang, q_ang)) <= TAU / 8.0 + 0.2:
				found = ac
				p.sites.append({"kind": "village", "center": ac,
					"working_points": anchor.working_points})
				anchors.remove_at(ai)
				break
		if found == Vector3.ZERO:
			for _try in range(3):
				var cand: Vector3 = planner.find_site(rng, 26.0, 60.0, [], gate, 280.0, 450.0)
				if cand == Vector3.ZERO:
					continue
				var cang: float = atan2(cand.z - gate.z, cand.x - gate.x)
				if absf(angle_difference(cang, q_ang)) <= TAU / 8.0 + 0.35:
					found = cand
					break
			if found == Vector3.ZERO:
				found = _passable_near(world, rng,
					gate + Vector3(cos(q_ang), 0, sin(q_ang)) * 360.0, 0.0, 80.0)
			p.sites.append({"kind": "village", "center": found})
		villages.append(found)
	p["village_centers"] = villages

	# Camps: deeper band, spread; the first stays <=480 (the close-camp promise).
	var camps: Array[Vector3] = []
	for ci in range(3):
		var cap: float = 480.0 if ci == 0 else 540.0
		var cand: Vector3 = planner.find_site(rng, 14.0, 120.0, [], gate, 400.0, cap)
		if cand == Vector3.ZERO:
			var ang2: float = TAU * float(ci) / 3.0 + 0.5
			cand = _passable_near(world, rng,
				gate + Vector3(cos(ang2), 0, sin(ang2)) * 440.0, 0.0, 70.0)
		camps.append(cand)
		p.sites.append({"kind": "vc_camp", "center": cand})
	p["camp_centers"] = camps

	# First-sign ring: old craters, every quadrant, inside 300m.
	var signs: Array[Vector3] = []
	for q2 in range(4):
		var qa: float = TAU * float(q2) / 4.0 + TAU / 8.0
		for _s in range(rng.randi_range(1, 2)):
			var base: Vector3 = gate + Vector3(cos(qa), 0, sin(qa)) * rng.randf_range(170.0, 280.0)
			signs.append(_passable_near(world, rng, base, 0.0, 40.0))
	p["first_signs"] = signs

	# Garrisons: the nearest village lives (the living camp shows), the rest wake.
	var nearest := Vector3.ZERO
	var nearest_d: float = 1.0e9
	for v in villages:
		var dv: float = v.distance_to(gate)
		if dv < nearest_d:
			nearest_d = dv
			nearest = v
	for vi in range(villages.size()):
		p.enemy_groups.append({"pos": villages[vi], "count": rng.randi_range(4, 7),
			"tag": "village_defenders_%d" % vi, "lazy": villages[vi] != nearest, "spread": 20.0})
	for ci2 in range(camps.size()):
		p.enemy_groups.append({"pos": camps[ci2], "count": rng.randi_range(4, 6),
			"tag": "camp_garrison_%d" % ci2, "lazy": true, "spread": 14.0})
	return p


static func build_patrol_world(world: GameWorld, director: MissionDirector, p: Dictionary) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(p.seed) + 777
	var planner := SitePlanner.new(world.gameplay_grid, world.terrain_manager, world.vegetation_manager, world)
	director.state.mission_type = "PATROL"
	director.state.seed_value = int(p.seed)
	var built_sites: Array[Dictionary] = []
	var fsb: Dictionary = planner.place_firebase_main(p.fsb_center as Vector3)
	built_sites.append(fsb)
	for site in p.sites:
		match str(site.kind):
			"village":
				built_sites.append(_build_village_site(world, director, planner, site, rng,
					str(p.get("time", "DAY")), Vector2i(2, 4)))
			"vc_camp":
				built_sites.append(planner.stamp_vc_camp(site.center, rng))
	for s: Vector3 in (p.first_signs as Array):
		DamageSystem.apply_damage(s, DamageSystem.DamageType.LARGE_EXPLOSION, rng.randf_range(0.8, 1.3))
		if rng.randf() < 0.4:
			_spawn_crater_water(world, s, rng)
	_spawn_enemy_groups(world, director, p, rng)

	# Walking patrols between the wire and the locations - the ground the player
	# crosses is the ground they cross.
	for pi in range(rng.randi_range(2, 3)):
		var villages2: Array = p.get("village_centers", [])
		var target: Vector3 = villages2[pi % villages2.size()] if villages2.size() > 0 else (p.gate_pos as Vector3)
		var mid: Vector3 = (p.gate_pos as Vector3).lerp(target, rng.randf_range(0.3, 0.7))
		var ppos := _passable_near(world, rng, mid, 30.0, 120.0)
		var lg_p := LazyGroup.new()
		lg_p.enemy_count = rng.randi_range(2, 4)
		lg_p.group_tag = "ambient_patrol_%d" % pi
		lg_p.activation_range = 140.0
		lg_p.setup(director, int(p.seed) + 31 * pi)
		lg_p.patrol_circuit = EnemyBase.make_patrol_circuit(
			_patrol_anchors(world, p, rng), rng, rng.randi_range(5, 8))
		world.add_child(lg_p)
		lg_p.global_position = _seat(world, ppos)

	# The armorer's bench (ADR-018), just inside the wire.
	var bench: Node3D = ARMORERS_BENCH.new()
	world.add_child(bench)
	var bench_pos: Vector3 = (fsb.spawn_pos as Vector3) - (fsb.gate_out as Vector3) * 10.0
	bench_pos.y = world.terrain_manager.get_height_at(bench_pos)
	bench.global_position = bench_pos

	var nav_baker: NavBaker = null
	if WorldConfig.NAV_ENABLED:
		nav_baker = NavBaker.new()
		nav_baker.name = "NavBaker"
		world.add_child(nav_baker)
		nav_baker.setup(world.terrain_manager)
		var nav_sites: Array[Dictionary] = []
		for bs in built_sites:
			if str(bs.get("kind", "")) != "firebase_main":
				nav_sites.append(bs)
		nav_baker.queue_sites(nav_sites, _enemy_anchors(p))

	_wire_systems(world, director, p, built_sites)

	var watchdog := TerrainWatchdog.new()
	world.add_child(watchdog)
	watchdog.setup(world.terrain_manager)

	return {"sites": built_sites, "spawn_pos": fsb.spawn_pos, "gate_pos": fsb.gate_pos,
		"gate_out": fsb.gate_out, "center": fsb.center, "bench": bench}


## One village build: stamp + civilians + stations + night fire + chickens.
## Shared by the offer flow and the patrol world - ONE implementation.
static func _build_village_site(world: GameWorld, director: MissionDirector,
		planner: SitePlanner, site: Dictionary, rng: RandomNumberGenerator,
		time_str: String, civ_range: Vector2i = Vector2i(3, 5)) -> Dictionary:
	var wp: Array[NodePath] = []
	if site.has("working_points"):
		wp = (site.working_points as Array[NodePath])
	var v: Dictionary = planner.stamp_village(site.center, rng, wp)
	site["root"] = world
	site["work_stations"] = v.get("work_stations", [])
	var wp_positions: Array[Vector3] = WorkingPointResolverScript.resolve(site)
	for st in (v.get("work_stations", []) as Array):
		wp_positions.append((st as Dictionary).get("pos", Vector3.ZERO) as Vector3)
	var civ_count: int = rng.randi_range(civ_range.x, civ_range.y)
	var informer_idx: int = rng.randi() % civ_count if rng.randf() < 0.5 else -1
	for ci in range(civ_count):
		var ca := rng.randf_range(0.0, TAU)
		var cpos: Vector3 = site.center + Vector3(cos(ca), 0, sin(ca)) * rng.randf_range(2.0, 12.0)
		cpos.y = world.terrain_manager.get_height_at(cpos) + 0.5
		var civ: Civilian = Civilian.spawn(world, cpos, director, ci == informer_idx)
		civ.occupation = CivilianSchedulesScript.pick_occupation(rng)
		if wp_positions.size() > 0:
			civ.working_point_pos = wp_positions[rng.randi() % wp_positions.size()]
		civ.build_bt()
	if time_str in ["NIGHT", "DUSK", "DAWN"]:
		_add_campfire(world, site.center + Vector3(2, 0, 2))
	# chickens: live noise traps
	for _ck in range(rng.randi_range(2, 4)):
		var ka := rng.randf_range(0.0, TAU)
		var kpos: Vector3 = site.center + Vector3(cos(ka), 0, sin(ka)) * rng.randf_range(3.0, 10.0)
		kpos.y = world.terrain_manager.get_height_at(kpos) + 0.3
		_add_chicken(world, kpos)
	return v


static func _spawn_enemy_groups(world: GameWorld, director: MissionDirector,
		p: Dictionary, rng: RandomNumberGenerator) -> void:
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


## Jungle thickening rings + the GameplayGrid honesty mirror (asr5/y5ad law):
## the AI sight cap must see the same bushes the player does.
static func apply_veg_boosts(world: GameWorld, near_pos: Vector3, sites: Array) -> void:
	if world.vegetation_manager == null:
		return
	var veg_centers: Array = [{"pos": near_pos, "radius": 60.0, "chance_floor": 0.95, "count_boost": 3}]
	for s in sites:
		var site: Dictionary = s
		if str(site.get("kind", "")) == "village" and site.has("center"):
			veg_centers.append({"pos": site.center, "radius": 72.0, "chance_floor": 0.9,
				"count_boost": 4, "bush_bias": true})
	world.vegetation_manager.set_density_centers(veg_centers)
	if world.gameplay_grid != null:
		for c in veg_centers:
			var cd: Dictionary = c
			world.gameplay_grid.boost_vegetation(cd.pos as Vector3, float(cd.radius), 0.55)
