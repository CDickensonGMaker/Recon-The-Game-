## mission_generator.gd - THE OPEN PATROL WORLD (ADR-029): one operation seed ->
## plan_patrol_world (pure positions) -> build_patrol_world (stamps Caleb's
## firebase, villages, camps, ambient ecology into a GameWorld).
class_name MissionGenerator
extends RefCounted

const ARMORERS_BENCH := preload("res://scripts/levels/armorers_bench.gd")
const PaddyStamperScript := preload("res://scripts/world/paddy_stamper.gd")
const WorkingPointResolverScript := preload("res://scripts/world/working_point_resolver.gd")
const CivilianSchedulesScript := preload("res://scripts/ai/civilian_schedules.gd")
const CivilianScript := preload("res://scripts/world/civilian.gd")
const LitterTeamScript := preload("res://scripts/world/litter_team.gd")
const PatrolGeneratorScript := preload("res://scripts/enemies/patrol_generator.gd")
const AmbushPlannerScript := preload("res://scripts/enemies/ambush_planner.gd")
const CampDirectorScript := preload("res://scripts/enemies/camp_director.gd")
const AirTrafficScript := preload("res://scripts/ai/air_traffic.gd")
const AmbientWarScript := preload("res://scripts/ai/ambient_war.gd")
const ConvoySpawnerScript := preload("res://scripts/missions/convoy_spawner.gd")
const DynamicMissionFactoryScript := preload("res://scripts/missions/dynamic_mission_factory.gd")

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
	"res://data/enemies/vc_ak.tres",
	"res://data/enemies/vc_ak.tres",
	"res://data/enemies/vc_mg.tres",
	"res://data/enemies/vc_medic.tres",
	"res://data/enemies/nva_regular.tres",
	"res://data/enemies/nva_regular.tres",
	"res://data/enemies/nva_rifleman.tres",
	"res://data/enemies/nva_rifleman.tres",
	"res://data/enemies/nva_mg.tres",
	"res://data/enemies/nva_marksman.tres",
	"res://data/enemies/nva_officer.tres",
	"res://data/enemies/nva_medic.tres",
	"res://data/enemies/vc_sapper.tres",
	"res://data/enemies/nva_rpg.tres",
]


## Men who never leave the camp, so a sited ambush can never empty it.
const AMBUSH_CAMP_FLOOR: int = 2

## VC camps for the main (non-demo) patrol world. Bumped from 3 (Summoner
## 2026-07-30: "the AO is huge... too little enemy areas"). CAMP_CAPS is the
## outer band radius per camp index (last value repeats for any camp past its
## length); the first stays close (the close-camp promise), later ones push
## further into the AO instead of clustering in the same narrow 400-540m ring.
const CAMP_COUNT: int = 5
const CAMP_CAPS: Array[float] = [480.0, 540.0, 620.0, 680.0, 720.0]

const WEATHER_TABLE: Array[String] =["CLEAR", "CLEAR", "CLEAR", "CLOUDY", "CLOUDY", "RAIN", "RAIN", "FOG", "MONSOON", "CLEAR"]
const TIME_TABLE: Array[String] = ["DAY", "DAY", "DAY", "DAY", "DAWN", "DUSK", "NIGHT", "NIGHT", "DAY", "DUSK"]

## Base name derivable without a world - MUST consume the first two rng draws
## (conditions_for skips exactly two). No "operation" language (Summoner decree
## 2026-07-18): the world is a firebase and a tour, not a mission board.
static func codename_for(seed_value: int) -> String:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var _a: int = rng.randi()  # draw 1 of the 2-draw name contract (conditions_for skips 2)
	return "FSB %s" % CODENAME_B[rng.randi() % CODENAME_B.size()]


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


## THE WIRE IS LAW (council 2026-07-18): nothing this sampler places may land
## inside the firebase. The keep-out is default-on - at plan time the base does
## not exist yet, so passability can never reject base-interior points; the
## geometric rect is the only guard. Set at every plan/build entry.
static var _fsb_keepout := Rect2()

static func _set_fsb_keepout(fsb_center: Vector3) -> void:
	_fsb_keepout = Rect2(fsb_center.x - SitePlanner.FSB_HALF.x,
		fsb_center.z - SitePlanner.FSB_HALF.y,
		SitePlanner.FSB_HALF.x * 2.0, SitePlanner.FSB_HALF.y * 2.0)


## Widest terrain damage a first-sign crater can do: LARGE profile radius at the
## max intensity roll, plus the spawn-ring margin. Derived, never a bare number -
## the profile retune bead must not silently under-cover this. The +40 protects
## the ground the player and bench stand on: spawn is 22m outside the wire and
## the small core rect no longer puts distance between the wire and the band.
const FIRST_SIGN_INTENSITY_MAX: float = 1.3

static func _crater_keepout_grow() -> float:
	var cells: int = int(DamageSystem.DAMAGE_PROFILES[DamageSystem.DamageType.LARGE_EXPLOSION].radius_cells * FIRST_SIGN_INTENSITY_MAX)
	return float(cells) * WorldConfig.CELL_SIZE + 40.0


## Returns Vector3.ZERO (unreachable as a valid result - x/z clamp to >=80) when
## no candidate clears both passability and the keep-out. Callers must handle:
## decorations drop, load-bearing sites retry outward, spawns skip.
static func _passable_near(world: GameWorld, rng: RandomNumberGenerator, origin: Vector3, min_r: float, max_r: float, attempts: int = 60, keepout_grow: float = 0.0) -> Vector3:
	var map_size: float = world.terrain_manager.map_size
	var keepout: Rect2 = _fsb_keepout.grow(keepout_grow) if _fsb_keepout.size != Vector2.ZERO else Rect2()
	for _i in range(attempts):
		var a: float = rng.randf_range(0.0, TAU)
		var r: float = rng.randf_range(min_r, max_r)
		var p := origin + Vector3(cos(a) * r, 0.0, sin(a) * r)
		p.x = clampf(p.x, 80.0, map_size - 80.0)
		p.z = clampf(p.z, 80.0, map_size - 80.0)
		if keepout.size != Vector2.ZERO and keepout.has_point(Vector2(p.x, p.z)):
			continue
		if world.gameplay_grid.is_position_passable(p) and not world.gameplay_grid.is_water(p):
			return p
	# The fallback obeys the same bounds contract as a real candidate. An off-map
	# point reaches modify_region as a reversed Rect2i and the edit silently drops.
	var fallback := Vector3(clampf(origin.x, 80.0, map_size - 80.0), origin.y,
		clampf(origin.z, 80.0, map_size - 80.0))
	if keepout.size != Vector2.ZERO and keepout.has_point(Vector2(fallback.x, fallback.z)):
		return Vector3.ZERO
	return fallback


## Load-bearing fallback: first point along `dir` from `gate` that clears the
## keep-out, then sample around it; the pure-geometry point is the last resort.
static func _outward_site(world: GameWorld, rng: RandomNumberGenerator, gate: Vector3,
		dir: Vector3, start_d: float, jitter: float, keepout_grow: float) -> Vector3:
	var map_size: float = world.terrain_manager.map_size
	var keepout: Rect2 = _fsb_keepout.grow(keepout_grow)
	var base: Vector3 = gate + dir * start_d
	for try_dir in [dir, Vector3(-dir.z, 0.0, dir.x)]:
		var d: float = start_d
		while d < 900.0:
			base = gate + (try_dir as Vector3) * d
			base.x = clampf(base.x, 80.0, map_size - 80.0)
			base.z = clampf(base.z, 80.0, map_size - 80.0)
			if not keepout.has_point(Vector2(base.x, base.z)):
				var found: Vector3 = _passable_near(world, rng, base, 0.0, jitter, 90, keepout_grow)
				return found if found != Vector3.ZERO else base
			d += 30.0
	return base



## Patrol nodes must hang on real AO features (ADR-021) - a route that connects
## things is a route the player can learn, predict and ambush.
##
## THE KEEP-OUT BINDS ROUTES, NOT ONLY SPAWNS (Fairness Law): the player's seat sits
## 22m outside the wire (site_planner.gd:504), so a waypoint there walks a patrol onto
## him before he is on his feet. Same rect the spawn sampler uses, same clearance the
## village and camp placers use - one keep-out concept, three consumers.
static func _patrol_anchors(world: GameWorld, p: Dictionary, rng: RandomNumberGenerator) -> Array[Vector3]:
	var pool: Array[Vector3] = []
	var route_keepout: Rect2 = _fsb_keepout.grow(SitePlanner.FSB_SITE_CLEARANCE) \
		if _fsb_keepout.size != Vector2.ZERO else Rect2()
	for s in p.get("sites", []):
		var site: Dictionary = s
		if not site.has("center"):
			continue
		var sc: Vector3 = site.center
		if route_keepout.size != Vector2.ZERO and route_keepout.has_point(Vector2(sc.x, sc.z)):
			continue
		pool.append(sc)
	# Fill out with passable ground spread across the AO so the circuit spans the
	# map instead of hugging the objective.
	var centre: Vector3 = p.get("insertion_lz", Vector3.ZERO)
	var guard: int = 0
	while pool.size() < 10 and guard < 40:
		guard += 1
		var cand: Vector3 = _passable_near(world, rng, centre, 120.0, 480.0, 60,
			SitePlanner.FSB_SITE_CLEARANCE)
		if cand == Vector3.ZERO:
			continue
		var ok: bool = true
		for e in pool:
			if e.distance_to(cand) < 60.0:   # nodes must be far enough apart to be legs
				ok = false
				break
		if ok:
			pool.append(cand)
	return pool

## Wire the 20-step living-world systems at mission start. Each system is best-
## effort: a missing camp, a zero-route convoy, an empty sky, all no-op cleanly.
## Returns nothing - the world just gets richer.
static func _wire_systems(world: GameWorld, director: FieldDirector,
		p: Dictionary, _built_sites: Array) -> void:
	# SimClock is an autoload, so last patrol's flight schedule outlives the world
	# that seeded it. Clear before anything re-seeds.
	if SimClock != null:
		SimClock.clear_schedules()

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

	# Set the clock to the mission's start hour BEFORE anything schedules against it.
	# The convoy fires 2 sim-hours from "now"; computed here it lands in the future,
	# not stranded in the past by a later clock jump (which killed it on DAY/DUSK/NIGHT).
	if SimClock != null:
		var t: String = String(p.get("time", "DAWN"))
		var hour: float = 6.0
		match t:
			"DAWN": hour = 6.0
			"DAY": hour = 10.0
			"DUSK": hour = 18.0
			"NIGHT": hour = 22.0
		SimClock.set_time(SimClock.sim_day, hour)

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

	# DynamicMissionFactory: hook to the convoy.ambushed signal so the player
	# can be offered an ESCORT when a convoy is ambushed.
	var dmf := DynamicMissionFactoryScript.new()
	dmf.name = "DynamicMissionFactory"
	world.add_child(dmf)
	dynamic_factory_ref = dmf


## Reference to the DynamicMissionFactory created by _wire_systems, so the
## ConvoySpawner can wire its `ambushed` signal into it. Static, so the
## spawner reads the same one.
static var dynamic_factory_ref: Node = null


## Used by ConvoySpawner when it instantiates a Convoy. Connects the convoy's
## ambushed signal to the factory so the crisis becomes a pointed location.
static func _wire_convoy_to_factory(convoy: Node) -> void:
	if convoy != null and dynamic_factory_ref != null \
			and convoy.has_signal("ambushed"):
		convoy.ambushed.connect(dynamic_factory_ref._on_convoy_ambushed)


## Market props a garrison at this position would work (uiho living camp).
static func _stations_near(p: Dictionary, pos: Vector3) -> Array:
	for s in p.get("sites", []):
		var sd: Dictionary = s
		if str(sd.get("kind", "")) == "village" and sd.has("work_stations") \
				and pos.distance_to(sd.center as Vector3) <= 70.0:
			return sd.get("work_stations", [])
	return []


static func _attach_camp_directors(world: GameWorld, director: FieldDirector,
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
		var paddy_centroids: Array[Vector3] = p.get("paddy_centroids", [])
		var cd := CampDirectorScript.attach(world, mean_pos, members,
			int(p.get("seed", 0)) + camp_idx * 17,
			_stations_near(p, mean_pos), paddy_centroids)
		if cd == null:
			continue
		cd.name = "CampDirector_%d" % camp_idx
		camp_idx += 1


static func _schedule_one_convoy(world: GameWorld, p: Dictionary, p_seed: int) -> void:
	# The convoy drives the longest road in the network - the one carrying the most
	# ground, and so the one most worth ambushing.
	var spawner := ConvoySpawnerScript.new()
	spawner.name = "ConvoySpawner"
	spawner.rng.seed = p_seed + 8888
	world.add_child(spawner)
	spawner.ambush_sites = p.get("ambush_sites", [])
	var route: Array[Vector3] = []
	if world.road_network != null:
		for pt in world.road_network.longest_route():
			route.append(pt)
	if route.size() < 2:
		return  # no road, no convoy - a truck does not drive through jungle
	# Schedule 2 sim-hours from now. Day rolls over if we cross 24:00.
	var cur_hour: float = SimClock.sim_hour if SimClock != null else 0.0
	var fire_day: int = SimClock.sim_day if SimClock != null else 1
	if cur_hour + 2.0 >= 24.0:
		fire_day += 1
	var fire_hour: float = fposmod(cur_hour + 2.0, 24.0)
	# Model names are asset basenames under ConvoySpawner.VEHICLE_MODEL_DIR - they must
	# resolve to real .glb files (asserted by tests/test_roads.gd).
	spawner.schedule(fire_day, fire_hour, "truck", route, _convoy_composition(spawner.rng))


## Summoner, 2026-07-28: "convoys of vehicles roll in groups of 3 to 6". A convoy is not
## six identical deuces - a gun jeep leads, trucks carry the load, a gun vehicle brings
## up the rear. Every basename here must exist under ConvoySpawner.VEHICLE_MODEL_DIR.
const CONVOY_MIN: int = 3
const CONVOY_MAX: int = 6


static func _convoy_composition(rng: RandomNumberGenerator) -> Array:
	var total: int = rng.randi_range(CONVOY_MIN, CONVOY_MAX)
	var out: Array = ["m151_mutt_gun_jeep"]
	for i in range(total - 2):
		out.append("m35_deuce_truck" if rng.randf() < 0.75 else "m113_apc")
	if total >= 2:
		out.append("m151_mutt_gun_jeep" if rng.randf() < 0.6 else "m113_apc")
	return out


static func _seat(world: GameWorld, pos: Vector3) -> Vector3:
	return Vector3(pos.x, world.terrain_manager.get_height_at(pos), pos.z)


## Flickering campfire - a beacon you can read at range at night.
## ADR-026 Part A #1: the fire is FAKE. Self-lit additive billboards carry the read
## at range; a real OmniLight would spend the <=8 light budget on atmosphere.
static func _add_campfire(world: GameWorld, pos: Vector3) -> void:
	var fire := Node3D.new()
	world.add_child(fire)
	fire.add_to_group("campfire")
	fire.global_position = _seat(world, pos) + Vector3(0, 0.3, 0)

	var glow := MeshInstance3D.new()
	var glow_mesh := QuadMesh.new()
	glow_mesh.size = Vector2(3.2, 3.2)
	glow.mesh = glow_mesh
	var glow_mat: StandardMaterial3D = _firelight_mat(Color(1.0, 0.6, 0.25, 0.30), 2.2)
	glow.material_override = glow_mat
	fire.add_child(glow)

	var flame := MeshInstance3D.new()
	var flame_mesh := QuadMesh.new()
	flame_mesh.size = Vector2(0.7, 0.9)
	flame.mesh = flame_mesh
	var flame_mat: StandardMaterial3D = _firelight_mat(Color(1.0, 0.82, 0.45, 0.9), 6.0)
	flame.material_override = flame_mat
	flame.position = Vector3(0, 0.35, 0)
	fire.add_child(flame)

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
	flicker.timeout.connect(func() -> void:
		var t: float = sin(float(Time.get_ticks_msec()) * 0.017)
		flame_mat.emission_energy_multiplier = 6.0 + 1.4 * t
		glow_mat.emission_energy_multiplier = 2.2 + 0.5 * t)


## Unshaded additive billboard - reads as firelight with no scene light present.
static func _firelight_mat(tint: Color, energy: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.albedo_color = tint
	mat.emission_enabled = true
	mat.emission = Color(tint.r, tint.g, tint.b)
	mat.emission_energy_multiplier = energy
	return mat


## Chickens scatter loudly when anyone gets close - live noise traps.
static func _add_chicken(world: GameWorld, pos: Vector3) -> void:
	var chicken := Node3D.new()
	world.add_child(chicken)
	chicken.global_position = _seat(world, pos) + Vector3(0, 0.05, 0)
	var scene: PackedScene = load("res://assets/world/animals/chicken.glb")
	var visual: Node3D = scene.instantiate() as Node3D
	chicken.add_child(visual)
	var ap := visual.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if ap != null:
		for anim_name in ap.get_animation_list():
			if String(anim_name).to_lower().contains("idle"):
				ap.get_animation(anim_name).loop_mode = Animation.LOOP_LINEAR
				ap.play(anim_name)
				break
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
					flee.y = 0.0
					# Land ON the ground: a flat flee vector on a village slope
					# left chickens hovering, and each scare stacked +0.1m.
					var dest: Vector3 = chicken.global_position + flee.normalized() * 8.0
					dest.y = world.terrain_manager.get_height_at(dest) + 0.05
					var tween := chicken.create_tween()
					tween.tween_property(chicken, "global_position", dest, 1.2)
					tween.tween_callback(func() -> void: chicken.remove_meta("spooked"))
					return)


## Where the fighting will be. NavBaker bakes a site only if someone is near it.
static func _enemy_anchors(p: Dictionary) -> Array[Vector3]:
	var out: Array[Vector3] = []
	for g in p.get("enemy_groups", []):
		var d: Dictionary = g
		out.append(d.get("pos", Vector3.ZERO))
	return out


## ---------- THE OPEN PATROL WORLD (ADR-029, Accepted 2026-08-04) ----------
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
		"sites": [], "enemy_groups": [],
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
	_set_fsb_keepout(fsb_center)

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
			if _fsb_keepout.grow(SitePlanner.FSB_SITE_CLEARANCE).has_point(Vector2(ac.x, ac.z)):
				continue  # a paddy anchor under the wire is not a village site
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
				# Load-bearing: a village must exist per quadrant (pacing contract,
				# villages[pi % size] downstream) - retry outward, never drop.
				found = _outward_site(world, rng, gate,
					Vector3(cos(q_ang), 0, sin(q_ang)), 360.0, 80.0,
					SitePlanner.FSB_SITE_CLEARANCE)
			p.sites.append({"kind": "village", "center": found})
		villages.append(found)
	p["village_centers"] = villages

	# Camps: deeper band, spread; the first stays <=480 (the close-camp promise).
	# The AO is 1280m across (WorldConfig.MAP_SIZE) but the old 400-540m band only
	# ever used a narrow ring close to the wire - CAMP_COUNT/CAMP_CAPS widen that
	# so the back half of a huge map isn't just empty jungle.
	var camps: Array[Vector3] = []
	for ci in range(CAMP_COUNT):
		var cap: float = CAMP_CAPS[mini(ci, CAMP_CAPS.size() - 1)]
		var cand: Vector3 = planner.find_site(rng, 14.0, 120.0, [], gate, 400.0, cap)
		if cand == Vector3.ZERO:
			var ang2: float = TAU * float(ci) / float(CAMP_COUNT) + 0.5
			cand = _outward_site(world, rng, gate,
				Vector3(cos(ang2), 0, sin(ang2)), 440.0, 70.0,
				SitePlanner.FSB_SITE_CLEARANCE)
		camps.append(cand)
		p.sites.append({"kind": "vc_camp", "center": cand})
	p["camp_centers"] = camps

	# Temple shrines: 1-2 per AO, deeper than the villages and off every road
	# (roads only connect villages). A failed find drops the shrine - the site
	# is a quiet payoff (player.gd:602 SEARCH THE SHRINE), never load-bearing.
	var shrine_count: int = 1 + (1 if rng.randf() < 0.4 else 0)
	for _si in range(shrine_count):
		var s_pos: Vector3 = planner.find_site(rng, 10.0, 150.0, [], gate, 320.0, 560.0)
		if s_pos != Vector3.ZERO:
			p.sites.append({"kind": "temple", "center": s_pos})

	# ROADS. Planned here because a road is PURE DERIVED POSITION - it routes over the
	# finished GameplayGrid and seats on the finished terrain, writing nothing. That
	# keeps plan_patrol_world side-effect free, and it means the ambush planner below
	# can already see the traffic lines. The corridor clearing (the one write a road
	# performs) happens in build_patrol_world, not here.
	#
	# The hub is the wire gate and the spokes are the villages. VC camps are
	# deliberately unconnected: a paved road to a Viet Cong base camp is absurd, and
	# the planner scores distance to traffic rather than requiring it.
	var roads := RoadNetwork.new(world.gameplay_grid, world.terrain_manager)
	roads.build(gate, villages)
	p["roads"] = roads

	# First-sign craters: four sectors fanned across the gate's OUTWARD half-plane
	# (ADR-029 amendment 2026-07-18) - the inward compass is the player's own base,
	# and a crater must clear the wire by its own blast radius. Signs are
	# decoration: a sector that cannot clear the keep-out yields nothing.
	var signs: Array[Vector3] = []
	var out_ang: float = atan2((gm.gate_out as Vector3).z, (gm.gate_out as Vector3).x)
	var crater_grow: float = _crater_keepout_grow()
	for q2 in range(4):
		var qa: float = out_ang + deg_to_rad(-67.5 + 45.0 * float(q2))
		for _s in range(rng.randi_range(1, 2)):
			var base: Vector3 = gate + Vector3(cos(qa), 0, sin(qa)) * rng.randf_range(170.0, 280.0)
			var s_pos: Vector3 = _passable_near(world, rng, base, 0.0, 40.0, 90, crater_grow)
			if s_pos == Vector3.ZERO:
				s_pos = _passable_near(world, rng, base, 0.0, 100.0, 90, crater_grow)
			if s_pos != Vector3.ZERO:
				signs.append(s_pos)
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
	# The garrison IS the ambush party. AmbushPlanner sites 4-6 of a camp's men on
	# cover-scored ground within 200m; the camp keeps the rest. One garrison roll,
	# two placements - the AO does not gain men, it moves them onto chosen ground.
	var ambush_sites: Array[Dictionary] = []
	var site_keepout: Rect2 = _fsb_keepout.grow(SitePlanner.FSB_SITE_CLEARANCE)
	for ci2 in range(camps.size()):
		var garrison: int = rng.randi_range(6, 9)
		var arng := RandomNumberGenerator.new()
		arng.seed = op_seed + 5171 * (ci2 + 1)
		var ambush: Dictionary = AmbushPlannerScript.plan(camps[ci2], garrison,
			world.gameplay_grid, p.paddy_centroids, arng, site_keepout, roads)
		if not ambush.is_empty():
			var party: int = mini(int(ambush.soldiers), garrison - AMBUSH_CAMP_FLOOR)
			ambush["soldiers"] = party
			ambush_sites.append(ambush)
			p.enemy_groups.append({"pos": ambush.trigger_pos, "count": party,
				"tag": "camp_ambush_%d" % ci2, "lazy": true, "spread": 8.0})
			garrison -= party
		p.enemy_groups.append({"pos": camps[ci2], "count": garrison,
			"tag": "camp_garrison_%d" % ci2, "lazy": true, "spread": 14.0})
	p["ambush_sites"] = ambush_sites
	return p


## DEMO GAME (War Room 2026-07-29): the authored 512m-slice plan. Same dict
## contract as plan_patrol_world - build_patrol_world stamps it unchanged - but
## sites are placed by BEARING from the centered firebase because the patrol
## planner's 240-560m bands cannot fit a small map. Lives HERE because only
## this file and site_planner.gd may drive the stamps (test_placement_paths).
static func plan_demo_world(world: GameWorld, op_seed: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = op_seed + 4242
	var planner := SitePlanner.new(world.gameplay_grid, world.terrain_manager, world.vegetation_manager, world)
	var p := {
		"seed": op_seed,
		"codename": "DEMO",
		# mission_weather seeds the sim clock from this string (mission_weather.gd:51), so it
		# must agree with DemoGame.START_HOUR's period or the boot lighting lies about the arc.
		"weather": "CLEAR", "time": "DAWN",
		"sites": [], "enemy_groups": [],
		"fire_support": {"mortar": 1},
	}
	var paddy_result: Dictionary = PaddyStamperScript.stamp(
		op_seed, world.gameplay_grid, world.terrain_manager, world, 0)
	p["paddy_fields"] = paddy_result.paddies
	p["village_anchors"] = paddy_result.village_anchors
	p["paddy_centroids"] = paddy_result.paddy_centroids
	for c: Vector3 in paddy_result.paddy_centroids:
		planner._reserved.append(c)

	# The demo IS the firebase: dead center of the slice.
	var half: float = world.map_size * 0.5
	var fsb_center := Vector3(half, 0.0, half)
	fsb_center.y = world.terrain_manager.get_height_at(fsb_center)
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
	_set_fsb_keepout(fsb_center)

	# Authored sites, BEARING-LOCKED off the gate: the player spawns just outside
	# the gate, so both sites sit on the flanks ~135 degrees away - walkable in
	# the exploration window, never on top of the spawn (07-29 playtest: he woke
	# inside a village hut).
	var out_v: Vector3 = (gm.gate_out as Vector3).normalized()
	var v_dir: Vector3 = out_v.rotated(Vector3.UP, 2.35)
	var t_dir: Vector3 = out_v.rotated(Vector3.UP, -2.35)
	var village := _passable_near(world, rng,
		fsb_center + v_dir * 185.0, 15.0, 60.0, 90,
		SitePlanner.FSB_SITE_CLEARANCE)
	if village == Vector3.ZERO:
		village = fsb_center + v_dir * 165.0
		village.y = world.terrain_manager.get_height_at(village)
	p.sites.append({"kind": "village", "center": village})
	var demo_villages: Array[Vector3] = [village]
	p["village_centers"] = demo_villages
	var temple := _passable_near(world, rng,
		fsb_center + t_dir * 170.0, 15.0, 60.0, 90,
		SitePlanner.FSB_SITE_CLEARANCE)
	if temple != Vector3.ZERO:
		p.sites.append({"kind": "temple", "center": temple})

	# RUINS IN THE JUNGLE (his ask, 2026-08-06: "some random temples and ruins"). One temple
	# was the whole of it, so every bearing but that flank was empty ground.
	#
	# stamp_temple_shrine ALREADY answers this: it draws mostly from the ruined prasat pool
	# (prasat_ruin_01..10) and only 28% of the time from the intact set, so more temple sites
	# IS more scattered ruins - no new site kind, no new art. Each one also joins
	# `temple_shrines`, which is what the player's [F] SEARCH THE SHRINE reads, so every extra
	# ruin is another thing to find rather than scenery.
	#
	# Bearings walk the compass away from the two authored flanks. The gate arc is deliberately
	# skipped: the walk out already carries the first-sign craters, and a ruin on that bearing
	# would be tripped over rather than discovered. Radii stay inside 230m - the slice is 512m,
	# so the firebase sits 256m from every edge and anything further has no passable ground left.
	## Radii are pulled IN from the first pass (205/150/185): on the shipped DEMO_SEED those
	## put two of the three outside anything passable and only one ruin landed. The village
	## and the camp both carry a second, shorter attempt for exactly this reason - a bearing
	## that fails at range usually succeeds nearer the base - so these do too.
	var ruin_bearings: Array[float] = [1.15, -0.55, 3.05]
	var ruin_radii: Array[float] = [175.0, 140.0, 160.0]
	var extra_ruins: int = 0
	for i in range(ruin_bearings.size()):
		var r_dir: Vector3 = out_v.rotated(Vector3.UP, ruin_bearings[i])
		var spot: Vector3 = _passable_near(world, rng,
			fsb_center + r_dir * ruin_radii[i], 18.0, 95.0, 120,
			SitePlanner.FSB_SITE_CLEARANCE)
		if spot == Vector3.ZERO:
			# Second attempt, closer in and wider. A jungle ruin 40m nearer the wire is still
			# a thing found off the path; no ruin at all is the failure that matters.
			spot = _passable_near(world, rng,
				fsb_center + r_dir * (ruin_radii[i] - 40.0), 18.0, 110.0, 120,
				SitePlanner.FSB_SITE_CLEARANCE)
		if spot == Vector3.ZERO:
			continue
		p.sites.append({"kind": "temple", "center": spot})
		extra_ruins += 1
	print("[DEMO] jungle ruins: %d of %d placed (plus the authored temple)"
		% [extra_ruins, ruin_bearings.size()])

	# THE 200m LANDMARK. The demo used to declare zero first-signs, so the walk out was
	# the one stretch with nothing in it - and under the 2026-08-03 rescope that stretch
	# is exactly where the five-minute rule is won or lost. Two to three craters on the
	# outbound bearing, at the patrol planner's own 150-300m band, consumed by the
	# existing loop in build_patrol_world.
	var signs: Array[Vector3] = []
	var sign_ang: float = atan2(out_v.z, out_v.x)
	for si in range(rng.randi_range(2, 3)):
		var sa: float = sign_ang + deg_to_rad(rng.randf_range(-35.0, 35.0))
		var sbase: Vector3 = gate + Vector3(cos(sa), 0.0, sin(sa)) * rng.randf_range(150.0, 300.0)
		var spos: Vector3 = _passable_near(world, rng, sbase, 0.0, 40.0, 90, _crater_keepout_grow())
		if spos == Vector3.ZERO:
			spos = _passable_near(world, rng, sbase, 0.0, 100.0, 90, _crater_keepout_grow())
		if spos != Vector3.ZERO:
			signs.append(spos)
	p["first_signs"] = signs
	var roads := RoadNetwork.new(world.gameplay_grid, world.terrain_manager)
	roads.build(gate, demo_villages)
	p["roads"] = roads

	# Light daytime presence only - the siege brings the real enemy at night.
	p.enemy_groups.append({"pos": village, "count": rng.randi_range(3, 4),
		"tag": "village_defenders_0", "lazy": false, "spread": 18.0})
	var treeline := _passable_near(world, rng,
		fsb_center + Vector3(0.2, 0.0, 1.0).normalized() * 190.0, 20.0, 80.0, 60,
		SitePlanner.FSB_SITE_CLEARANCE)
	if treeline != Vector3.ZERO:
		p.enemy_groups.append({"pos": treeline, "count": rng.randi_range(3, 5),
			"tag": "treeline_watchers", "lazy": true, "spread": 12.0})
	var no_ambush: Array[Dictionary] = []
	p["ambush_sites"] = no_ambush

	# THE ENEMY CAMP (his rescope, 2026-08-03: "there is at least one village and one enemy
	# camp"). The demo used to declare zero camps. It sits on the OPPOSITE flank from the
	# village and further out, so the two are a day's walk apart rather than one loop, and
	# the temple at 170m on this bearing becomes a landmark on the way to it.
	var camps: Array[Vector3] = []
	var camp := _passable_near(world, rng,
		fsb_center + t_dir * 300.0, 20.0, 70.0, 90,
		SitePlanner.FSB_SITE_CLEARANCE)
	if camp == Vector3.ZERO:
		camp = _passable_near(world, rng,
			fsb_center + t_dir * 265.0, 20.0, 110.0, 90,
			SitePlanner.FSB_SITE_CLEARANCE)
	if camp != Vector3.ZERO:
		p.sites.append({"kind": "vc_camp", "center": camp})
		camps.append(camp)
	else:
		push_warning("[DEMO] no passable ground for the enemy camp - the day has one site only")
	p["camp_centers"] = camps
	return p


static func build_patrol_world(world: GameWorld, director: FieldDirector, p: Dictionary) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(p.seed) + 777
	var planner := SitePlanner.new(world.gameplay_grid, world.terrain_manager, world.vegetation_manager, world)
	director.state.mission_type = "PATROL"
	director.state.seed_value = int(p.seed)
	_set_fsb_keepout(p.fsb_center as Vector3)
	var built_sites: Array[Dictionary] = []
	var fsb: Dictionary = planner.place_firebase_main(p.fsb_center as Vector3)
	built_sites.append(fsb)
	_build_firebase_garrison(world, director, fsb.center as Vector3, rng)
	for site in p.sites:
		match str(site.kind):
			"village":
				built_sites.append(_build_village_site(world, director, planner, site, rng,
					str(p.get("time", "DAY")), Vector2i(2, 4)))
			"vc_camp":
				built_sites.append(planner.stamp_vc_camp(site.center, rng))
			"temple":
				built_sites.append(planner.stamp_temple_shrine(site.center, rng))
	for s: Vector3 in (p.first_signs as Array):
		DamageSystem.apply_damage(s, DamageSystem.DamageType.LARGE_EXPLOSION,
			rng.randf_range(0.8, FIRST_SIGN_INTENSITY_MAX))
		if rng.randf() < 0.4:
			_spawn_crater_water(world, s, rng)
	_spawn_enemy_groups(world, director, p, rng)

	# Walking patrols between the wire and the locations - the ground the player
	# crosses is the ground they cross.
	for pi in range(rng.randi_range(2, 3)):
		var villages2: Array = p.get("village_centers", [])
		var target: Vector3 = villages2[pi % villages2.size()] if villages2.size() > 0 else (p.gate_pos as Vector3)
		var mid: Vector3 = (p.gate_pos as Vector3).lerp(target, rng.randf_range(0.3, 0.7))
		var ppos := _passable_near(world, rng, mid, 30.0, 120.0, 60,
			SitePlanner.FSB_SITE_CLEARANCE)
		if ppos == Vector3.ZERO:
			continue  # a patrol that can only stand inside the wire does not spawn
		var lg_p := LazyGroup.new()
		lg_p.enemy_count = rng.randi_range(2, 4)
		lg_p.group_tag = "ambient_patrol_%d" % pi
		lg_p.activation_range = 140.0
		lg_p.setup(director, int(p.seed) + 31 * pi)
		lg_p.patrol_circuit = EnemyBase.make_patrol_circuit(
			_patrol_anchors(world, p, rng), rng, rng.randi_range(5, 8))
		world.add_child(lg_p)
		lg_p.global_position = _seat(world, ppos)

	_spawn_friendly_patrols(world, director, p, rng)

	# The armorer's bench (ADR-018), just inside the wire.
	var bench: Node3D = ARMORERS_BENCH.new()
	world.add_child(bench)
	var bench_pos: Vector3 = (fsb.spawn_pos as Vector3) - (fsb.gate_out as Vector3) * 10.0
	bench_pos.y = world.terrain_manager.get_height_at(bench_pos)
	bench.global_position = bench_pos

	# The mortar pit: sandbag nest + M29 + crew-station markers garrison AI can
	# claim (scenes/world/mortar_pit.tscn). Set square to the gate axis so the
	# tube fires over the perimeter, not down the entrance road.
	var gate_dir: Vector3 = (fsb.gate_out as Vector3)
	var pit_dir: Vector3 = Vector3(gate_dir.z, 0.0, -gate_dir.x).normalized()
	var pit_pos: Vector3 = (fsb.center as Vector3) + pit_dir * 10.0
	pit_pos.y = world.terrain_manager.get_height_at(pit_pos)
	MortarPit.create(world, pit_pos, pit_dir)

	# ROADS. The network was ROUTED in the plan pass (pure positions); this is where it
	# becomes part of the world. Two things happen and nothing else: the world gets its
	# authority reference, and the corridor is thinned - vegetation bundles only, never
	# height, never terrain_type, never water. Deliberately before _wire_systems, which
	# schedules the convoy that drives these roads.
	world.road_network = p.get("roads", null) as RoadNetwork
	if world.road_network != null:
		world.road_network.clear_corridor(world.vegetation_manager,
			world.terrain_manager.chunk_size, world.terrain_manager.heightmap)

	var nav_baker: NavBaker = null
	if WorldConfig.NAV_ENABLED:
		nav_baker = NavBaker.new()
		nav_baker.name = "NavBaker"
		world.add_child(nav_baker)
		nav_baker.setup(world.terrain_manager)
		# The firebase is no longer excluded. It was skipped here AND its kind was absent
		# from WorldConfig.NAV_SITE_KINDS - two closed gates, so the one place the player's
		# squad and the garrison actually live had no navmesh under it. NavBaker gives it a
		# box big enough to hold a 300m compound and sources its geometry from the GLB's real
		# colliders, so the men path around the bunkers they used to walk into.
		nav_baker.queue_sites(built_sites, _enemy_anchors(p))

	_wire_systems(world, director, p, built_sites)

	var watchdog := TerrainWatchdog.new()
	world.add_child(watchdog)
	watchdog.setup(world)

	return {"sites": built_sites, "spawn_pos": fsb.spawn_pos, "gate_pos": fsb.gate_pos,
		"gate_out": fsb.gate_out, "center": fsb.center, "bench": bench}


## Other Americans are out here. TWO fireteams, no more: the AO must stay enemy-
## dense, and every friendly is a full-AI body outside EnemySquad's hot-set budget
## (enemy_squad.gd:37 tiers enemies only). Dormant at the same 140m as the VC
## ambient patrols, so they cost nothing until the player is near them.
const FRIENDLY_PATROLS: int = 2
const FRIENDLY_PATROL_MEN: int = 4

## The director is carried only to satisfy LazyGroup's activation guard
## (lazy_group.gd:50). Friendlies are deliberately NOT routed through
## spawn_tracked_enemy - that would file them in _live_enemies and register them
## as contact groups in the ADR-006 ledger.
static func _spawn_friendly_patrols(world: GameWorld, director: FieldDirector,
		p: Dictionary, rng: RandomNumberGenerator) -> void:
	var gate: Vector3 = p.gate_pos as Vector3
	var villages: Array = p.get("village_centers", [])
	for pi in range(FRIENDLY_PATROLS):
		var target: Vector3 = villages[pi % villages.size()] if villages.size() > 0 else gate
		var mid: Vector3 = gate.lerp(target, rng.randf_range(0.35, 0.75))
		var ppos: Vector3 = _passable_near(world, rng, mid, 40.0, 150.0, 60,
			SitePlanner.FSB_SITE_CLEARANCE)
		if ppos == Vector3.ZERO:
			continue
		var fp := FriendlyPatrolGroup.new()
		fp.enemy_count = FRIENDLY_PATROL_MEN
		fp.group_tag = "friendly_patrol_%d" % pi
		fp.activation_range = 140.0
		fp.spread = 6.0
		fp.setup(director, int(p.seed) + 97 * (pi + 1))
		fp.route = EnemyBase.make_patrol_circuit(
			_patrol_anchors(world, p, rng), rng, rng.randi_range(5, 8))
		world.add_child(fp)
		fp.global_position = _seat(world, ppos)


## The men who live inside the wire. Same schedule machinery as the villages -
## occupation + SimClock hour - pointed at US models and military posts read from
## the fsb_main GLB markers. They are NOT combatants and NOT squad members: they
## carry no EnemyBase/AllyBase and never enter the squad roster.
##
## This is the ONE place that spawns inside _fsb_keepout, deliberately: the
## keep-out guards site placement, and the garrison is the intended exception.
static func _build_firebase_garrison(world: GameWorld, director: FieldDirector,
		center: Vector3, rng: RandomNumberGenerator) -> void:
	var plan: Dictionary = SitePlanner.fsb_garrison_plan(center)
	var quarters: Array = plan.get("quarters", [])
	var men: Array[Civilian] = []
	var qi: int = 0
	for entry in (plan.get("posts", []) as Array):
		var post: Dictionary = entry
		var post_pos: Vector3 = post.pos
		if str(post.occupation) == "gun_crew":
			_place_firebase_mg(world, center, post_pos)
		# The litter team is a scripted three-body performance, not three men at three
		# stations: LitterTeam owns their positions and their clips. They are spawned
		# here and handed over whole, and never get a working point or a BT.
		if str(post.occupation) == "litter":
			var bearers: Array[Civilian] = []
			for li in range(3):
				var lpos: Vector3 = post_pos
				lpos.y = world.floor_y(lpos) + 0.5
				var lman: Civilian = Civilian.spawn(world, lpos, director, false,
					CivilianScript.GARRISON_MEN, true)
				lman.occupation = "litter"
				lman.add_to_group("firebase_garrison")
				bearers.append(lman)
			var ward: Vector3 = post.get("ward", post_pos)
			ward.y = world.floor_y(ward)
			var cot_g: Vector3 = post_pos
			cot_g.y = world.floor_y(cot_g)
			var team: Node = LitterTeamScript.new()
			if not team.setup(world, bearers, cot_g, ward):
				team.free()
			continue
		# EVERY MAN GETS HIS OWN STATION. A post with men=2 used to give both the SAME
		# working_point_pos and a random 1-3.5m spawn ring, so two of them could roll onto the
		# same spot - and once stood-to, GarrisonDefender hands both the identical post anchor
		# and they walk right back into each other. That is the rifleman standing inside the
		# marksman (2026-07-29). Stations are spread by INDEX around the post, not rolled.
		var men_n: int = maxi(1, int(post.men))
		for mi in range(men_n):
			var a: float = TAU * float(mi) / float(men_n) + rng.randf_range(-0.3, 0.3)
			var r: float = 1.8 if men_n > 1 else rng.randf_range(0.0, 1.0)
			var station: Vector3 = post_pos + Vector3(cos(a), 0.0, sin(a)) * r
			var pos: Vector3 = station
			# THE MOUND IS THE FLOOR, not the terrain (2026-07-29) - and the ROOF is not the
			# floor either (2026-08-04): the plan now carries the marker's AUTHORED height and
			# floor_y probes a short reach down from it, so a post inside a tent seats on the
			# tent floor instead of surface_y's first-hit ROOF. Every BT arrive check is 3-D
			# within ~1.6m, so a wrong-height working point is a man walking at it forever.
			pos.y = world.floor_y(pos) + 0.5
			# The aid station gets the surgeon, not whoever the pool rolled
			# (Civilian.models_for). Every other post still draws from GARRISON_MEN.
			var man: Civilian = Civilian.spawn(world, pos, director, false,
				CivilianScript.models_for(str(post.occupation)), true)
			man.occupation = str(post.occupation)
			man.role = str(post.get("role", ""))
			var wp: Vector3 = station
			wp.y = world.floor_y(wp)
			man.working_point_pos = wp
			if quarters.size() > 0:
				var q: Vector3 = quarters[qi % quarters.size()]
				q.y = world.floor_y(q)
				man.home = q
				qi += 1
			man.add_to_group("firebase_garrison")
			men.append(man)
	for man in men:
		man.build_bt()


## One mannable M60 post per firebase gun_crew post, floor-seated from the plan's
## authored marker height and set one step downrange so the sandbags sit on the
## perimeter and the crew mills behind. GarrisonDefender.promote mans it when the wire is
## hit; the player can man it any time via player._nearby_mg_emplacement.
static func _place_firebase_mg(world: GameWorld, center: Vector3, post_pos: Vector3) -> void:
	var outward: Vector3 = post_pos - center
	outward.y = 0.0
	outward = outward.normalized() if outward.length() > 0.1 else Vector3.FORWARD
	var gun_pos: Vector3 = post_pos + outward * 1.0
	gun_pos.y = world.floor_y(gun_pos)
	MGEmplacement.create(world, gun_pos, outward)


## One village build: stamp + civilians + stations + night fire + chickens.
## Shared by the offer flow and the patrol world - ONE implementation.
static func _build_village_site(world: GameWorld, director: FieldDirector,
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
	# Demo: ALWAYS an informer (ruled 2026-08-03 §2.6 - a coin flip on the demo's central
	# idea is a dice roll on the shop window). Demo short-circuits BEFORE the randf so the
	# full game's draw order is untouched (ADR-010).
	var informer_idx: int = rng.randi() % civ_count \
		if (GameFlow.demo_mode or rng.randf() < 0.5) else -1
	var villagers: Array[Civilian] = []
	for ci in range(civ_count):
		var ca := rng.randf_range(0.0, TAU)
		var cpos: Vector3 = site.center + Vector3(cos(ca), 0, sin(ca)) * rng.randf_range(2.0, 12.0)
		cpos.y = world.terrain_manager.get_height_at(cpos) + 0.5
		var civ: Civilian = Civilian.spawn(world, cpos, director, ci == informer_idx)
		civ.village_center = site.center
		civ.occupation = CivilianSchedulesScript.pick_occupation(rng)
		if wp_positions.size() > 0:
			civ.working_point_pos = wp_positions[rng.randi() % wp_positions.size()]
		villagers.append(civ)
	_assign_households(villagers, rng)
	for civ in villagers:
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


## Partition a village's villagers into travelling parties who share a hut and a
## working point. A household IS the group: same home, same destination, so the
## schedule alone walks them out together. Odd villagers are left solo (-1).
##
## Summoner, 2026-07-28: "the villagers travel in packs of 3 to 6 on their routes
## between villages." Note the range alone is not enough - the loop guard and the
## remainder rule both had 2 baked into them, so a village would have quietly kept
## producing pairs while the constant claimed otherwise.
const PARTY_MIN: int = 3
const PARTY_MAX: int = 6


static func _assign_households(civs: Array[Civilian], rng: RandomNumberGenerator) -> void:
	var i: int = 0
	var gid: int = 0
	while civs.size() - i >= PARTY_MIN:
		var left: int = civs.size() - i
		# Never strand a sub-minimum tail: if splitting would leave fewer than PARTY_MIN
		# behind, take the whole remainder as one party instead.
		var size: int = rng.randi_range(PARTY_MIN, PARTY_MAX)
		size = mini(size, left)
		if left - size > 0 and left - size < PARTY_MIN:
			size = left
		var members: Array = []
		for k in range(i, i + size):
			members.append(civs[k])
		var head: Civilian = civs[i]
		for m in members:
			var c: Civilian = m as Civilian
			c.group_id = gid
			c.group_members = members
			c.home = head.home
			c.working_point_pos = head.working_point_pos
			c.is_group_lead = (c == head)
		i += size
		gid += 1


static func _spawn_enemy_groups(world: GameWorld, director: FieldDirector,
		p: Dictionary, rng: RandomNumberGenerator) -> void:
	for group in p.enemy_groups:
		if bool(group.get("lazy", false)):
			var lg := LazyGroup.new()
			lg.enemy_count = int(group.count)
			lg.group_tag = str(group.tag)
			lg.spread = float(group.get("spread", 12.0))
			lg.paddy_centroids = p.get("paddy_centroids", [] as Array[Vector3])
			lg.work_stations = _stations_near(p, group.pos as Vector3)
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
