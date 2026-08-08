## ai_stress_arena.gd - Combat AI Stress Test Arena
## A 120m sandbox where US and VC/NVA squads fight autonomously. Built on the
## same primitives as Gore Lab, but scoped for sustained squad-vs-squad battles
## and honest telemetry. Visual quality is secondary to tactical readability.
class_name AIStressArena
extends Node3D

## Minimal TerrainManager stand-in for the arena. DamageSystem is an autoload and
## expects a terrain_manager when explosions try to deform terrain; the arena has no
## heightmap, so this stub absorbs the calls without warning.
class TerrainManagerStub extends Node:
	var cell_size: float = 1.0
	var chunk_size: float = 32.0
	var heightmap = null

	func get_height_at(_world_pos: Vector3) -> float:
		return 0.0

	func modify_terrain(_world_pos: Vector3, _radius_meters: float, _crater_func: Callable) -> void:
		pass


## Flat ground for the vegetation layers: every cell is placeable, no slope. The arena
## has no real heightmap, so JunglePatchLayer samples this.
class FlatHeightmap:
	func sample_world(_x: float, _z: float) -> float:
		return 0.0

	func get_normal_world(_x: float, _z: float) -> Vector3:
		return Vector3.UP


## A GameplayGrid whose origin sits at the arena CENTRE. The base grid maps world x=0
## to cell 0 and clamps negatives, but the arena spans -ARENA/2..+ARENA/2, so every
## negative coordinate would collapse onto cell 0. Shifting the sample by world_size*0.5
## puts the whole span on the grid. Vegetation density is stamped directly (this grid is
## authored by _stamp_veg_*, never by build_from_terrain), so grid_to_world is overridden
## to match for any future reader.
class ArenaGrid extends GameplayGrid:
	func world_to_grid(world_pos: Vector3) -> Vector2i:
		var off: float = world_size * 0.5
		return Vector2i(
			clampi(int((world_pos.x + off) / cell_size_meters), 0, grid_size - 1),
			clampi(int((world_pos.z + off) / cell_size_meters), 0, grid_size - 1))

	func grid_to_world(grid_pos: Vector2i) -> Vector3:
		var off: float = world_size * 0.5
		return Vector3(
			(grid_pos.x + 0.5) * cell_size_meters - off,
			0.0,
			(grid_pos.y + 0.5) * cell_size_meters - off)


## The fire-support rig — inert GameWorld host, flat terrain, and the destructible fort
## segment — now lives in FireSupportBench (ADR-023: one rig, shared by this arena and the
## support-fire range). Reference them as FireSupportBench.DestructibleFortification etc.


const ARENA: float = 200.0
const WALL_H: float = 4.0
const LAB_GRENADES: int = 25
## Spare magazines the bench hands the player. A stress test is a long fight and
## the 3 mags a normal equip grants run dry before the first wave is decided.
const LAB_SPARE_MAGS: int = 12

## --- FORTIFICATION + SAPPER + FIRE-SUPPORT TESTBED (war-room decree 2026-07-20) ---
## A forward wire+sandbag line the sappers breach, a tunnel mouth to satchel, a placed
## (unmanned, DEFERRED) MG nest, and a callable FieldDirector for every fire tier.
const FORT_LINE_X: float = -30.0        ## the line runs along Z at this X (player side is west)
const FORT_LINE_Z0: float = 18.0
const FORT_LINE_Z1: float = 52.0
const FORT_SEG_LEN: float = 2.6
## How many distinct meshes of each kind to lift, so the line is not one mesh repeated.
const FORT_MESH_VARIANTS: int = 4
const ARENA_SAPPER_COUNT: int = 3
const SAPPER_AUTO_DELAY: float = 10.0   ## first wave crosses on its own so he sees it happen
## THE SIEGE AT THE WIRE. Full d50 strength on demand, so the mass assault can be
## watched in isolation instead of waiting on the campaign's night roll. Distances are
## the campaign geometry scaled into this 200 m box - the ring must clear the
## materialize range or every cell becomes bodies on the frame it spawns.
## His ruling 2026-08-04: "send 30 people at a time" - survival waves, chained
## for as long as he lasts (_on_siege_ended relaunches after a breather).
const SIEGE_STRENGTH: int = 30
const WAVE_BREATHER_S: float = 15.0
const SIEGE_RING_MIN: float = 70.0
const SIEGE_RING_MAX: float = 95.0
const SIEGE_MATERIALIZE_M: float = 35.0
const SIEGE_RALLY_M: float = 90.0
const SIEGE_MORTAR_STANDOFF: float = 130.0
## ENEMY INDIRECT FIRE, independent of the siege. Volleys walk onto the player's
## position at the moment of firing - flight time plus dispersion is what makes
## moving the answer. SiegeDirector.fire_mortar_volley is the one implementation;
## this only sets the cadence.
const MORTAR_INTERVAL_MIN: float = 38.0
const MORTAR_INTERVAL_MAX: float = 65.0
const MORTAR_SPREAD_M: float = 25.0
const MORTAR_FIRST_DELAY: float = 45.0
const TUNNEL_POS: Vector3 = Vector3(-15.0, 0.0, 45.0)

## Ruined-building / rubble GLBs shipped by bead sra5. Village and central contact
## zone draw from these for hard urban cover instead of gray primitive boxes.
const RUIN_DIR: String = "res://assets/world/building models/structures/ruins/"
const VILLAGE_RUINS: Array[String] = [
	"ruinset_street_row", "ruinset_compound", "ruinset_courtyard",
	"ruin_house_shell", "ruin_house_half", "destroyed_bunker",
	"wall_u_ruin",
]
const CONTACT_RUBBLE: Array[String] = [
	"wall_remnant", "wall_corner_tall", "rubble_heap_tall",
	"rubble_pile_medium", "brick_pile", "bomb_crater", "rubble_field_wide",
]

## Squad structure for the arena. Names are MOS strings that map through
## SquadSystem helpers to weapons and bodies.
const US_SQUAD_MOS: Array[String] = [
	"POINTMAN", "RTO", "MEDIC", "RIFLEMAN", "GRENADIER", "MG",
]

## US body pool for arena grunts. The old note here said us_grunt_v3 was the only clean
## single-body export and the role exports must be kept out because they carry a second
## skinned body - that second body is Base_Human, and model_actor.gd:542 hides it on
## every unit, so the caution is spent. us_grunt_v3 was retired 2026-08-04.
const ARENA_US_BODIES: Array[String] = [
	"us_grunt_rifleman", "us_grunt_pointman", "us_grunt_mg",
	"us_grunt_grenadier", "us_grunt_marksman", "us_grunt_rto",
]

## VC/NVA enemy data resources. Each squad gets a mix.
const VC_PATHS: Array[String] = [
	"res://data/enemies/vc_rifleman.tres",
	"res://data/enemies/vc_rifleman.tres",
	"res://data/enemies/vc_sapper.tres",
	"res://data/enemies/nva_regular.tres",
	"res://data/enemies/nva_rpg.tres",
	"res://data/enemies/vc_rifleman.tres",
]

## Force configuration. Defaults give a 3x6 = 18-per-side start (a reinforced
## Vietnam patrol, both sides kept even for a fair stress test). Tunable in the
## inspector; keep men_per_squad * squads_active in the 16-18 band per side.
@export var us_squads_active: int = 3
@export var vc_squads_active: int = 3
@export var men_per_squad: int = 6
## Reinforcement WAVES held in reserve per side. Each wave lands 16 + 1d10 men
## (see _wave_size); reserves gate how many such waves can still arrive.
@export var us_reserve_squads: int = 2
@export var vc_reserve_squads: int = 2
@export var round_max_seconds: float = 300.0  ## 5 minute hard cap
@export var spawn_player: bool = true
@export var spawn_hud: bool = true
## The instrumentation layer: per-man state labels, LOS lines, and the telemetry
## block. OFF by default so the arena plays as a firefight rather than reading as a
## dashboard; [F3] brings it back mid-run when something needs diagnosing.
@export var debug_readouts: bool = false
## Periodic VC mortar volleys onto the player. [L] calls one in on demand.
@export var enemy_mortars: bool = true
## If true, every agent is seeded with a nearest-enemy target and pushed into COMBAT
## on spawn. Used by headless probes and quick sanity checks. Overrides patrol_mode.
@export var hot_start: bool = false
## THE headline scenario. When true (and not hot_start), both sides START in
## PATROL/IDLE at opposite ends of the map and must DEVELOP contact: US advance in
## MOVE_TO toward the centre, VC walk patrol routes toward it, and both transition
## patrol -> alert -> combat naturally through perception (US via contact_conf,
## VC via the arena spotting feed into the awareness accumulator + return fire).
@export var patrol_mode: bool = true
## Independent arena content layers - all default OFF, so the arena boots as a bare
## walled room (floor + walls + combatants). Flip either on to stage a firefight with
## physical cover and/or dense vegetation, so a newly-wired system's reaction to each
## can be isolated. ps2_perf_probe.gd turns both on for the full perf-bench scene.
@export var spawn_cover: bool = false          ## firebase, fortifications, village, ridge, wrecks, cover clusters
@export var spawn_vegetation: bool = false     ## tree lines, planted rice/palms, dense jungle, ground plants
## Night lighting + flares/campfires + the live profiling overlay. Default OFF; the
## perf probe sets it ON. Scene content is the two toggles above, not this flag.
@export var bench_dressing: bool = false
## Lab gore crank: force EVERY death to pop regions + every head hit to burst, so all
## model rigs (US/VC/NVA variants) can be confirmed to gib. Reset on leaving the arena.
@export var force_gib: bool = true

## --- TUNING LEVERS (arena-local, do not leak into campaign) ---
## AI health scaling. Controls how long AI-vs-AI fights last.
## 1.0 = campaign feel. The bench must never tune the game with levers the game
## doesn't have (drift council D2); raise it per-run in the inspector only.
@export var ai_hp_multiplier: float = 1.0
## Multiplier on damage dealt by the player only. Keeps player gunfeel separate
## from AI-vs-AI durability.
@export var player_damage_multiplier: float = 1.0
## Scales reinforcement cadence. Higher = reserves arrive faster.
@export var reserve_rate_multiplier: float = 1.0
## THE firefight-length dial (C2). Pushed into GameSettings.ai_vs_ai_cone_mult on _ready. 1.0 = fair,
## lethal baseline; 2.5-3.0 = Star Wars troopers, long firefights. AI-vs-player is never affected.
@export var ai_vs_ai_cone_mult: float = 1.0
## Fraction of max HP at which all arena VC/NVA switch to wounded retreat.
@export var ai_retreat_hp: float = 0.35
## Symmetry-probe mode: forces identical weapon/HP/accuracy on both sides and strips the enemy-only
## retreat + self-preservation bias, so the mirror-match probe measures the fire model, nothing else.
@export var mirror_mode: bool = false
## Spawn-jitter seed. Probes vary it per round; combat spread itself draws from the global stream.
@export var rng_seed: int = 20260714
## The weapon both sides share in mirror_mode. A TIGHT rifle (sub-cap cone) so any off-center aim
## bias shows up instead of hiding under the 1.2 deg cap - that makes the probe a real regression
## guard: reintroduce an enemy-only bias and the ratio breaks the band.
const MIRROR_WEAPON: String = "res://data/weapons/mosin.tres"
const MIRROR_HP: int = 80
const MIRROR_ACC: float = 0.7

## Central contact objective both sides move toward in patrol_mode.
const CONTACT_POINT: Vector3 = Vector3(0.0, 1.0, 0.0)
## Patrol-mode spotting feed (arena-local). Core enemy perception exempts allies
## as candidates until COMBAT (the buddy-rule that guards player stealth), so in an
## AI-vs-AI patrol the VC would never awareness-ramp on the US. This feeds a visible
## US contact into the EXISTING awareness accumulator so the ramp is real and the
## VC promote themselves to COMBAT through their own state machine at awareness>=1.
const SPOT_RANGE: float = 72.0
const SPOT_GAIN: float = 0.85  ## per second of sustained LOS; beats AWARENESS_DECAY (0.25)
const SPOT_CONE_DOT: float = -0.17  ## cos(~100deg): generous frontal arc, sentry scan fills the rest

## Vegetation/sight grid, read by enemy_base._sight_cap() and player.gd via the
## "game_world" group. Density is stamped where foliage is planted (see _stamp_veg_*),
## so wherever the eye sees jungle the AI's sight cap is genuinely reduced.
var gameplay_grid: GameplayGrid = null

## Grid resolution: ARENA(200m) / 64 cells = 3.125m cells. Fine enough that a clump
## stamps several cells; coarse enough to stay cheap.
const GRID_CELLS: int = 64
## Concealment values. enemy_base's concealment-cover fallback uses a STRICT veg > 0.6
## test, so anything meant to conceal must exceed 0.6 (0.65), never sit at it.
const VEG_HEAVY: float = 0.95    ## tree-line canopy -> sight cap ~50m (near SIGHT_CAP_JUNGLE)
const VEG_CONCEAL: float = 0.65  ## grass/bamboo: conceals a man, clears the >0.6 fallback
const VEG_PALM: float = 0.5      ## scattered palms: mild sight reduction, no hard concealment
const VEG_RICE: float = 0.2      ## paddy: token cover only

var player: CharacterBody3D = null
var _rng := RandomNumberGenerator.new()
var _nav_region: NavigationRegion3D = null
var _patrol_active: bool = false  ## resolved in _ready: patrol_mode and not hot_start

## Bench dressing + profiling instrument (only live when bench_dressing).
var _jungle_layer: JunglePatchLayer = null
var _sun: DirectionalLight3D = null
var _clutter_root: Node3D = null       ## grass/rice multimeshes, toggled as one
var _lights_root: Node3D = null        ## campfires + illum flares, toggled as one
var _perf_overlay: ArenaPerfOverlay = null
var _debug_vis_enabled: bool = true
var _flare_cd: float = 0.0
const FLARE_INTERVAL: float = 18.0

## Live agents, grouped by squad index.
var _us_squads: Array[Array] = []   # Array[Array[AllyBase]]
var _vc_squads: Array[Array] = []   # Array[Array[EnemyBase]]

## Reserve counters and cooldowns.
var _us_reserves_left: int = 0
var _vc_reserves_left: int = 0
var _us_reinforce_cd: float = 0.0
var _vc_reinforce_cd: float = 0.0
const REINFORCE_INTERVAL_MIN: float = 25.0
const REINFORCE_INTERVAL_MAX: float = 40.0

## Telemetry
var _sim_time: float = 0.0
var _hud: Label = null
var _round_ended: bool = false
var _us_kills: int = 0
var _vc_kills: int = 0

## 30s summary log state
var _last_telemetry_log: float = -999.0
var _us_rounds_fired: int = 0
var _vc_rounds_fired: int = 0
var _us_retreats: int = 0
var _vc_retreats: int = 0
var _us_suppressed_seconds: float = 0.0
var _vc_suppressed_seconds: float = 0.0

## Debug labels (reused pattern from Gore Lab)
var _dbg_labels: Dictionary = {}
var _dbg_mesh: MeshInstance3D = null
var _dbg_im: ImmediateMesh = null

## Fortification / sapper / fire-support testbed state.
var _forts: Array[Node3D] = []          ## live Destructible fort segments
var _fort_mesh_pool: Dictionary = {}    ## kind -> Array[Mesh] lifted from the shipped GLBs
var _field_director: FieldDirector = null  ## the bench director (FireSupportBench.wire)
var _siege: SiegeDirector = null           ## [J] drives a full-strength assault at the wire
var _sapper_auto_t: float = SAPPER_AUTO_DELAY
var _mortar_t: float = MORTAR_FIRST_DELAY
var _sapper_auto_done: bool = false
var _toast_label: Label = null          ## r4bk: the RTO net's calls must be VISIBLE
var _toast_t: float = 0.0


func _ready() -> void:
	_rng.seed = rng_seed
	_patrol_active = patrol_mode and not hot_start
	# Mirror mode isolates the fire path: identical sides. Activity-tiering only
	# touches EnemyBase (VC), not AllyBase (US), so leaving it on would tier one
	# side and void the symmetry premise. Neutralize it for that probe only.
	# These three are STATICS on shipped systems. The arena is a lab, not a mission, and
	# a lab that edits the game and walks away is how a demo run inherits arena values
	# without anything saying so - _exit_tree puts every one of them back.
	_prev_tiering = EnemySquad.tiering_enabled
	_prev_gib_lifetime = GibSystem.gib_lifetime_s
	_prev_cone_mult = GameSettings.ai_vs_ai_cone_mult
	_prev_player_dmg = GameSettings.player_outgoing_damage_mult
	GameSettings.player_outgoing_damage_mult = player_damage_multiplier
	if mirror_mode:
		EnemySquad.tiering_enabled = false
	GibSystem.gib_lifetime_s = 25.0
	GibSystem.force_all_gibs = force_gib  # crank gore in the lab so every rig's gib can be confirmed
	# The arena is the tuning lab for the one firefight-length dial (C2).
	GameSettings.ai_vs_ai_cone_mult = ai_vs_ai_cone_mult

	# enemy_base/player resolve the sight grid from this group; build it before any
	# environment (the veg planters stamp into it) and before any agent spawns.
	add_to_group("game_world")
	_build_gameplay_grid()

	# Plug a terrain stub into the autoload so grenades don't spam warnings.
	var terrain_stub := TerrainManagerStub.new()
	terrain_stub.name = "ArenaTerrainStub"
	DamageSystem.add_child(terrain_stub)
	DamageSystem.set_terrain_manager(terrain_stub)

	_build_environment()
	_bake_navmesh()

	# The navigation server needs at least one physics frame to register the
	# baked region before agents can resolve paths on it. Give it two frames so
	# the map RID is valid and the mesh is merged.
	await get_tree().physics_frame
	await get_tree().physics_frame

	_spawn_player()
	_wire_fire_support()
	_spawn_initial_forces()
	if hot_start:
		_hot_start_combat()
	# Scale HP and wire kill counting after all agents have finished _ready().
	call_deferred("_finish_agent_setup")
	_build_hud()
	_build_debug_vis()
	set_debug_vis_active(debug_readouts)
	_wire_telemetry()
	if bench_dressing and spawn_hud:
		_perf_overlay = ArenaPerfOverlay.new()
		add_child(_perf_overlay)
		_perf_overlay.setup(self, _jungle_layer, _clutter_root, _lights_root, _sun)

	print("[AI STRESS ARENA] ready - mode=%s | %d US squads + %d wave(s) vs %d VC squads + %d wave(s)" % [
		"PATROL" if _patrol_active else ("HOT" if hot_start else "MOVE-TO-CONTACT"),
		us_squads_active, us_reserve_squads, vc_squads_active, vc_reserve_squads])


func _process(delta: float) -> void:
	if _round_ended:
		return
	_sim_time += delta
	_update_sandbox(delta)

	# Time each arena-owned manager so the overlay can name a CPU spike's subsystem.
	# The overlay (a child) reads these the same frame, right after this runs.
	var t0: int = Time.get_ticks_usec()
	if _patrol_active:
		_update_patrol_contact(delta)
	var t1: int = Time.get_ticks_usec()
	_update_reinforcements(delta)
	var t2: int = Time.get_ticks_usec()
	_update_telemetry(delta)
	var t3: int = Time.get_ticks_usec()
	_update_debug_vis()
	var t4: int = Time.get_ticks_usec()
	if bench_dressing:
		_update_flares(delta)
	_check_round_end()

	if _perf_overlay != null:
		_perf_overlay.report_cpu_bucket("patrol", float(t1 - t0) / 1000.0)
		_perf_overlay.report_cpu_bucket("reinforce", float(t2 - t1) / 1000.0)
		_perf_overlay.report_cpu_bucket("telemetry", float(t3 - t2) / 1000.0)
		_perf_overlay.report_cpu_bucket("debug_vis", float(t4 - t3) / 1000.0)
		_report_ai_buckets(delta)


var _ai_bucket_t: float = 0.0
var _ai_bucket_frames: int = 0
var _ai_bucket_prev: Array[int] = [0, 0, 0, 0]


## Physics-side AI split (think/move/hitzone/anim) as a 1Hz per-frame average of
## the usec the agents accumulate on CombatManager inside _physics_process.
func _report_ai_buckets(delta: float) -> void:
	_ai_bucket_t += delta
	_ai_bucket_frames += 1
	if _ai_bucket_t < 1.0:
		return
	var now_c: Array[int] = [CombatManager.ai_usec_think, CombatManager.ai_usec_move,
		CombatManager.ai_usec_hitzone, CombatManager.ai_usec_anim]
	var names: Array[String] = ["ai/think", "ai/move", "ai/hitzone", "ai/anim"]
	var f: float = float(maxi(1, _ai_bucket_frames))
	for i in names.size():
		_perf_overlay.report_cpu_bucket(names[i], float(now_c[i] - _ai_bucket_prev[i]) / 1000.0 / f, true)
	_ai_bucket_prev = now_c
	_ai_bucket_t = 0.0
	_ai_bucket_frames = 0


## Keep an illum flare or two burning over the contact zone so the many-lights night
## load is sustained (each flare is an OmniLight; they drift down and expire in 25s).
func _update_flares(delta: float) -> void:
	_flare_cd -= delta
	if _flare_cd > 0.0:
		return
	_flare_cd = FLARE_INTERVAL
	var pos: Vector3 = CONTACT_POINT + Vector3(
		_rng.randf_range(-20.0, 20.0), 0.0, _rng.randf_range(-20.0, 20.0))
	IllumFlare.pop(_lights_root, pos)
	if _perf_overlay != null:
		_perf_overlay.note_event("flare pop")


## Live attribution toggle (overlay F5): freeze + hide every agent so the AI/physics
## CPU cost and the skinned-character draw cost drop out of the numbers at once.
func set_characters_active(active: bool) -> void:
	for us in [true, false]:
		for squad in (_us_squads if us else _vc_squads):
			for a in squad:
				if not is_instance_valid(a):
					continue
				a.visible = active
				a.set_process(active)
				a.set_physics_process(active)


## Live attribution toggle (overlay F6): hide the LOS/state debug overlay and stop
## rebuilding it, so its per-frame ImmediateMesh + Label3D cost drops out.
func set_debug_vis_active(active: bool) -> void:
	_debug_vis_enabled = active
	if _dbg_mesh != null:
		_dbg_mesh.visible = active
		if not active and _dbg_im != null:
			_dbg_im.clear_surfaces()
	for key_v: Variant in _dbg_labels:
		var l: Label3D = _dbg_labels[key_v]
		if is_instance_valid(l):
			l.visible = active


## ---------- ENVIRONMENT ----------

func _build_environment() -> void:
	_clutter_root = Node3D.new()
	_clutter_root.name = "GroundClutter"
	add_child(_clutter_root)
	_lights_root = Node3D.new()
	_lights_root.name = "BenchLights"
	add_child(_lights_root)
	_build_floor()
	_build_walls()
	# Bare walled room; each content layer below is an independent toggle (see exports).
	if bench_dressing:
		MissionWeather.is_night = true
		_build_night_env()
	if spawn_cover:
		_build_firebase()
		_build_fortifications()
		_place_tunnel_entrance()
		_build_village()
		_build_central_ridge()
		_build_wrecked_cover()
		_build_cover_clusters()
	if spawn_vegetation:
		_build_tree_lines()
		_plant_vegetation()
		_build_jungle()
		_scatter_ground_plants()
	if bench_dressing:
		_build_campfires()


## Dim moon: reads MissionWeather.TIMES["NIGHT"] - the SHARED preset, so a
## weather retune can never silently un-sync the bench (drift council D1).
func _build_night_env() -> void:
	var night: Dictionary = MissionWeather.TIMES["NIGHT"]
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.02, 0.03, 0.05)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.45, 0.55, 0.75)
	env.ambient_light_energy = float(night.ambient)
	env.fog_enabled = true
	env.fog_light_color = Color(0.10, 0.14, 0.22)
	env.fog_density = 0.006
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.name = "WorldEnvironment"
	we.environment = env
	add_child(we)

	var sun := DirectionalLight3D.new()
	sun.name = "SunLight"
	sun.rotation_degrees = Vector3(float(night.sun_x), 40.0, 0.0)
	sun.light_energy = float(night.energy)
	sun.light_color = night.sun_color
	# Ship parity (ADR-026 Amendment A): game_world ships the sun shadowless. The F6
	# overlay toggle turns this on to MEASURE the ~12ms shadow cost; it is not a shipped cost.
	sun.shadow_enabled = false
	add_child(sun)
	_sun = sun


## Plant real dense jungle across the whole play area by driving JunglePatchLayer with a
## synthetic all-HEAVY_JUNGLE tile grid on the flat stub. The layer node is offset to the
## arena's SW corner so its 0..chunk_size local tiles land on the -ARENA/2..+ARENA/2 span.
func _cli_float(prefix: String, fallback: float) -> float:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with(prefix):
			return float(a.substr(prefix.length()))
	return fallback


func _build_jungle() -> void:
	_jungle_layer = JunglePatchLayer.new()
	_jungle_layer.name = "JunglePatchLayer"
	# Bench A/B hook: --fill_chance= / --view_distance= override the defaults so the
	# jungle FPS levers (ADR-026 Amendment A) can be measured without editing the scene.
	_jungle_layer.fill_chance = _cli_float("--fill_chance=", 0.95)
	_jungle_layer.view_distance = _cli_float("--view_distance=", _jungle_layer.view_distance)
	_jungle_layer.position = Vector3(-ARENA * 0.5, 0.0, -ARENA * 0.5)
	add_child(_jungle_layer)
	_jungle_layer._load_patches()
	if not _jungle_layer.enabled:
		push_warning("[ARENA] jungle patch layer failed to load - no dense jungle")
		return
	var bundles := 25
	var bundle_m: float = ARENA / float(bundles)
	var terrain := PackedByteArray()
	terrain.resize(bundles * bundles)
	terrain.fill(JunglePatchLayer.T_HEAVY_JUNGLE)
	# CLEARED FIELDS OF FIRE (his ruling 2026-08-04: "if we could have a cleared
	# treeline a little bit it would be a bit easier to tell whats going on a more
	# faux firebase"). Open grass around the firebase corner, a light-jungle
	# transition band, then the heavy stuff - the fight arrives ACROSS open ground.
	for j in range(bundles):
		for i in range(bundles):
			var wx: float = -ARENA * 0.5 + (float(i) + 0.5) * bundle_m
			var wz: float = -ARENA * 0.5 + (float(j) + 0.5) * bundle_m
			var d: float = Vector2(wx, wz).distance_to(Vector2(FIREBASE_ORIGIN.x, FIREBASE_ORIGIN.z))
			if d < CLEAR_RADIUS_M:
				terrain[j * bundles + i] = JunglePatchLayer.T_GRASSLAND
			elif d < CLEAR_RADIUS_M + 14.0:
				terrain[j * bundles + i] = JunglePatchLayer.T_LIGHT_JUNGLE
	_jungle_layer.generate_for_chunk(Vector2i(0, 0), terrain, bundles, bundle_m,
			FlatHeightmap.new(), ARENA)
	# Wherever the eye sees jungle the AI's sight cap must drop to match: heavy
	# density outside the clearing, honest open ground inside it.
	_stamp_veg_rect(Rect2(-ARENA * 0.5, -ARENA * 0.5, ARENA, ARENA), VEG_HEAVY)
	_stamp_veg_rect(Rect2(FIREBASE_ORIGIN.x - CLEAR_RADIUS_M, FIREBASE_ORIGIN.z - CLEAR_RADIUS_M,
			CLEAR_RADIUS_M * 2.0, CLEAR_RADIUS_M * 2.0), VEG_RICE)
	_plant_fellable_treeline()


## The clearing geometry shared by the jungle carve and the treeline planter.
const FIREBASE_ORIGIN := Vector3(-62.0, 0.0, 62.0)   # _build_firebase's origin
const CLEAR_RADIUS_M: float = 38.0


## Real BREAKABLE trees on the clearing's rim - the destructible treeline he asked
## for (2026-08-04), now on the S29 segmented system: registered in TreeBreakSystem,
## no standing colliders, a blast breaks them at the band nearest the burst height.
const TREELINE_SPECIES: Array[String] = ["broadleaf_a", "broadleaf_b", "jungle_palm_a2"]


func _plant_fellable_treeline() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260804
	var layer := TreeCoverLayer.new()
	layer.name = "TreelineCover"
	add_child(layer)
	layer.load_species(TREELINE_SPECIES)
	var scatter: Array = []
	for i in range(26):
		var ang: float = rng.randf_range(-PI * 0.55, PI * 0.10)   # the arc facing the arena
		var r: float = CLEAR_RADIUS_M + rng.randf_range(0.0, 10.0)
		var pos := FIREBASE_ORIGIN + Vector3(cos(ang) * r, 0.0, sin(ang) * r)
		if absf(pos.x) > ARENA * 0.5 - 6.0 or absf(pos.z) > ARENA * 0.5 - 6.0:
			continue
		var nm: String = TREELINE_SPECIES[rng.randi_range(0, TREELINE_SPECIES.size() - 1)]
		var basis := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(0.85, 1.2))
		scatter.append({"name": nm, "xf": Transform3D(basis, pos)})
	layer.generate_for_chunk(Vector2i(0, 0), scatter)
	print("[ARENA] breakable treeline: %d trees on the clearing rim" % scatter.size())


## Ground density between the patch tiles, MultiMesh-instanced from Caleb's OWN individual
## plant GLBs (real low-poly geometry, materials preserved - NOT procedural sprite cards).
## One MultiMesh per variant = one draw call each; a short visibility range keeps the far
## field cheap. Instances stay identifiable pieces so destructible foliage stays possible.
const GROUND_PLANTS: Array[String] = [
	"fern_a", "fern_b", "fern_c",
	"elephant_grass_a", "elephant_grass_b", "elephant_grass_c",
	"bush_a", "bush_b", "bush_c",
	"grass_tuft_a", "grass_tuft_b", "grass_tuft_c",
	"tall_grass_a", "tall_grass_b", "tall_grass_c",
	"broadleaf_a", "broadleaf_b", "broadleaf_c",
]
const GROUND_PLANT_COUNT: int = 110
const GROUND_PLANT_VIEW: float = 65.0


func _scatter_ground_plants() -> void:
	var half: float = ARENA * 0.5 - 5.0
	var swayed: int = 0
	for variant in GROUND_PLANTS:
		var mesh: Mesh = GroundClutter.load_glb_mesh("res://assets/world/vegetation/" + variant + ".glb")
		if mesh == null:
			continue
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = mesh
		mm.instance_count = GROUND_PLANT_COUNT
		for i in GROUND_PLANT_COUNT:
			var pos := Vector3(_rng.randf_range(-half, half), 0.0, _rng.randf_range(-half, half))
			var basis := Basis(Vector3.UP, _rng.randf_range(0.0, TAU))
			var s: float = _rng.randf_range(0.85, 1.35)
			basis = basis.scaled(Vector3(s, s, s))
			mm.set_instance_transform(i, Transform3D(basis, pos))
		var mmi := MultiMeshInstance3D.new()
		mmi.name = "ground_" + variant
		mmi.multimesh = mm
		# Wind: ride vegetation_sway on the plant's OWN texture, but only where the model
		# carries the R/G sway mask (COLOR). No mask -> the whole plant would slide, so
		# that one keeps its static GLB material instead.
		if _sway_material_for(mesh) != null:
			mmi.material_override = _sway_material_for(mesh)
			swayed += 1
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mmi.visibility_range_end = GROUND_PLANT_VIEW
		mmi.visibility_range_end_margin = 10.0
		mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		_clutter_root.add_child(mmi)
	print("[AI STRESS ARENA] ground plants scattered - %d/%d variants sway in wind"
			% [swayed, GROUND_PLANTS.size()])


## A vegetation_sway material bound to this mesh's own albedo texture, or null if the
## mesh has no per-vertex sway mask (COLOR) - in which case wind would slide the roots.
func _sway_material_for(mesh: Mesh) -> ShaderMaterial:
	if mesh.get_surface_count() == 0:
		return null
	var arrays: Array = mesh.surface_get_arrays(0)
	var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	if colors == null or colors.is_empty():
		return null
	var src := mesh.surface_get_material(0) as BaseMaterial3D
	var tex: Texture2D = src.albedo_texture if src != null else null
	return GroundClutter.make_sway_material(tex, 0.16, 0.05)


func _build_campfires() -> void:
	var village := Vector3(55.0, 0.0, -55.0)
	for offset in [Vector3(-8, 0, -4), Vector3(10, 0, 6), Vector3(0, 0, 14), Vector3(20, 0, -8)]:
		_add_bench_campfire(village + offset)
	# Two flares already burning over the contact zone at boot.
	IllumFlare.pop(_lights_root, CONTACT_POINT + Vector3(-12, 0, 8))
	IllumFlare.pop(_lights_root, CONTACT_POINT + Vector3(14, 0, -10))


func _add_bench_campfire(pos: Vector3) -> void:
	var fire := Node3D.new()
	_lights_root.add_child(fire)
	fire.global_position = pos + Vector3(0, 0.3, 0)
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
	particles.initial_velocity_max = 2.0
	particles.scale_amount_min = 0.15
	particles.scale_amount_max = 0.4
	particles.color = Color(1.0, 0.55, 0.2)
	fire.add_child(particles)


## ---------- GAMEPLAY GRID (vegetation / sight) ----------

func _build_gameplay_grid() -> void:
	gameplay_grid = ArenaGrid.new(ARENA, GRID_CELLS)
	# Open ground everywhere (base grid fills 0.5); veg is stamped on top by the planters.
	# 0.0 -> the AI's sight cap is the full SIGHT_CAP_OPEN (140m) outside foliage.
	gameplay_grid.vegetation_density.fill(0.0)


## Raise density to `value` in a world-space disc, taking the MAXIMUM so overlapping
## foliage never lowers an already-dense cell.
func _stamp_veg_circle(center: Vector3, radius: float, value: float) -> void:
	if gameplay_grid == null:
		return
	var cell: float = gameplay_grid.cell_size_meters
	var gc: Vector2i = gameplay_grid.world_to_grid(center)
	var r_cells: int = int(ceil(radius / cell))
	for dz in range(-r_cells, r_cells + 1):
		for dx in range(-r_cells, r_cells + 1):
			if Vector2(float(dx) * cell, float(dz) * cell).length() > radius:
				continue
			var gx: int = gc.x + dx
			var gz: int = gc.y + dz
			if gx < 0 or gz < 0 or gx >= gameplay_grid.grid_size or gz >= gameplay_grid.grid_size:
				continue
			var idx: int = gz * gameplay_grid.grid_size + gx
			if value > gameplay_grid.vegetation_density[idx]:
				gameplay_grid.vegetation_density[idx] = value


## Raise density to `value` across a world-space XZ rectangle (max-blend).
func _stamp_veg_rect(rect: Rect2, value: float) -> void:
	if gameplay_grid == null:
		return
	var lo: Vector2i = gameplay_grid.world_to_grid(Vector3(rect.position.x, 0.0, rect.position.y))
	var hi: Vector2i = gameplay_grid.world_to_grid(
		Vector3(rect.position.x + rect.size.x, 0.0, rect.position.y + rect.size.y))
	for gz in range(mini(lo.y, hi.y), maxi(lo.y, hi.y) + 1):
		for gx in range(mini(lo.x, hi.x), maxi(lo.x, hi.x) + 1):
			if gx < 0 or gz < 0 or gx >= gameplay_grid.grid_size or gz >= gameplay_grid.grid_size:
				continue
			var idx: int = gz * gameplay_grid.grid_size + gx
			if value > gameplay_grid.vegetation_density[idx]:
				gameplay_grid.vegetation_density[idx] = value


func _build_floor() -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.add_to_group("nav_source")
	var mi := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(ARENA, ARENA)
	mi.mesh = plane
	if bench_dressing:
		# The lab_grid shader is unshaded and blazing white - it ignores the moonlight
		# and destroys the night look. The bench uses a dark, LIT jungle-floor material
		# so the dim moon + campfires + flares actually read on the ground.
		var gm := StandardMaterial3D.new()
		gm.albedo_color = Color(0.06, 0.07, 0.05)
		gm.roughness = 1.0
		mi.material_override = gm
	else:
		var sm := ShaderMaterial.new()
		sm.shader = load("res://terrain/shaders/lab_grid.gdshader")
		mi.material_override = sm
	body.add_child(mi)
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(ARENA, 0.2, ARENA)
	cs.shape = box
	cs.position.y = -0.1
	body.add_child(cs)
	add_child(body)


func _build_walls() -> void:
	var half: float = ARENA * 0.5
	for w in [
		[Vector3(0, WALL_H * 0.5, -half), Vector3(ARENA, WALL_H, 0.4)],
		[Vector3(0, WALL_H * 0.5, half), Vector3(ARENA, WALL_H, 0.4)],
		[Vector3(-half, WALL_H * 0.5, 0), Vector3(0.4, WALL_H, ARENA)],
		[Vector3(half, WALL_H * 0.5, 0), Vector3(0.4, WALL_H, ARENA)],
	]:
		var wall := StaticBody3D.new()
		wall.collision_layer = 1
		wall.collision_mask = 0
		wall.add_to_group("nav_source")
		var wmi := MeshInstance3D.new()
		var wm := BoxMesh.new()
		wm.size = w[1]
		wmi.mesh = wm
		var wmat := StandardMaterial3D.new()
		wmat.albedo_color = Color(0.55, 0.58, 0.62)
		wmi.material_override = wmat
		wall.add_child(wmi)
		var wcs := CollisionShape3D.new()
		var wbox := BoxShape3D.new()
		wbox.size = w[1]
		wcs.shape = wbox
		wall.add_child(wcs)
		add_child(wall)
		wall.position = w[0]


func _build_firebase() -> void:
	# SW perimeter (US home end): sandbag wall segments.
	var origin := Vector3(-62.0, 0.0, 62.0)
	var segments: Array[Vector3] = [
		Vector3(-30, 0, 0), Vector3(-15, 0, 0), Vector3(0, 0, 0), Vector3(15, 0, 0),
		Vector3(0, 0, -15), Vector3(0, 0, -30),
	]
	for offset in segments:
		var pos := origin + offset
		pos.y = 0.6
		_sandbag_wall(Vector3(4.0, 1.2, 1.0), pos)

	# Two fighting holes near the wall.
	_fighting_hole(origin + Vector3(-20, 0, -20))
	_fighting_hole(origin + Vector3(10, 0, -20))

	# A simple resupply/landing zone platform.
	_platform(origin + Vector3(-5, 0, -33), Vector3(12, 0.2, 8))

	# His two ORIGINAL hand-built bunkers (exported 2026-08-04), slits toward the
	# arena interior (-Z front at yaw 0, interior is NE of this corner). Graceful
	# no-op until the editor has imported the fresh GLBs.
	for spec in [
			["res://assets/world/building models/structures/firebase/kit/fb_bunker_mg.glb",
				origin + Vector3(-12.0, 0.0, -10.0)],
			["res://assets/world/building models/structures/firebase/kit/fb_bunker_fighting.glb",
				origin + Vector3(14.0, 0.0, -8.0)]]:
		var path: String = str((spec as Array)[0])
		if not ResourceLoader.exists(path):
			print("[ARENA] bunker GLB not imported yet: %s" % path)
			continue
		var packed := load(path) as PackedScene
		if packed == null:
			continue
		var b := packed.instantiate() as Node3D
		add_child(b)
		b.global_position = (spec as Array)[1] as Vector3
		b.rotation.y = -PI * 0.25
		b.add_to_group("nav_source")


func _build_village() -> void:
	# VC home end: a ruined hamlet built from the shipped ruins GLBs (bead sra5),
	# with a couple of intact blockhouses for hard corners.
	var origin := Vector3(55.0, 0.0, -55.0)
	for i in range(2):
		var x := float(i) * 20.0
		var pos := origin + Vector3(x, 0.0, 18.0)
		_building(pos, Vector3(_rng.randf_range(5.0, 8.0), 3.2, _rng.randf_range(5.0, 8.0)))

	# Ruined buildings scattered across the hamlet footprint.
	var ruin_spots: Array[Vector3] = [
		Vector3(-14, 0, -6), Vector3(6, 0, -12), Vector3(24, 0, -2),
		Vector3(-6, 0, 6), Vector3(16, 0, 10), Vector3(30, 0, 20),
		Vector3(2, 0, 24), Vector3(-18, 0, 16),
	]
	for i in range(ruin_spots.size()):
		var model: String = VILLAGE_RUINS[i % VILLAGE_RUINS.size()]
		_place_ruin(model, origin + ruin_spots[i], _rng.randf_range(0.0, TAU), _rng.randf_range(1.1, 1.7))

	# Paths and sandbag positions around the hamlet.
	for offset in [Vector3(-10, 0, -10), Vector3(25, 0, -10), Vector3(-10, 0, 25), Vector3(25, 0, 25)]:
		_sandbag_wall(Vector3(3.0, 1.0, 0.8), origin + offset + Vector3(0, 0.5, 0))


func _build_central_ridge() -> void:
	# A low winding berm across the middle of the arena. It is partial cover:
	# crouched men hide, standing men can see/shoot over it. Gaps force flanking
	# and prove the navigation/LOS systems can route around obstacles.
	var segments: Array[Dictionary] = [
		{"x0": -88.0, "x1": -14.0, "z": 0.0},
		{"x0":  -4.0, "x1":   4.0, "z": 0.0},
		{"x0":  14.0, "x1":  88.0, "z": 0.0},
	]
	for seg in segments:
		var length: float = float(seg["x1"]) - float(seg["x0"])
		var mid: float = (float(seg["x0"]) + float(seg["x1"])) * 0.5
		# Meander the Z so it is not a straight shooting gallery.
		var z_off: float = _rng.randf_range(-3.0, 3.0)
		_berm_segment(Vector3(mid, 0.0, float(seg["z"]) + z_off), Vector3(length, 1.3, 3.5))

	# Cross-berms create corner cover and break up diagonal fire lanes.
	_berm_segment(Vector3(-32.0, 0.0, -18.0), Vector3(12.0, 1.0, 2.5), 0.4)
	_berm_segment(Vector3(32.0, 0.0, 18.0), Vector3(12.0, 1.0, 2.5), -0.4)
	_berm_segment(Vector3(-24.0, 0.0, 24.0), Vector3(10.0, 1.0, 2.5), -0.3)
	_berm_segment(Vector3(24.0, 0.0, -24.0), Vector3(10.0, 1.0, 2.5), 0.3)


func _build_tree_lines() -> void:
	# North and south tree lines with gaps. They provide concealment and force
	# fire teams to use the cleared flanks or push through intermittent cover.
	for side in [-1, 1]:
		var z_base: float = float(side) * 84.0
		for i in range(9):
			var x: float = -88.0 + float(i) * 22.0
			if i == 4:
				continue  # deliberate lane through the tree line
			_tree_clump(Vector3(x + _rng.randf_range(-4.0, 4.0), 0.0, z_base + _rng.randf_range(-6.0, 6.0)))

	# Elephant-grass strips along the flanks for hiding/low movement.
	_elephant_grass_strip(Rect2(-92, -88, 184, 8))
	_elephant_grass_strip(Rect2(-92, 80, 184, 8))


func _build_wrecked_cover() -> void:
	# Central contact zone: broken walls, rubble and fallen logs that create
	# short-range fire-and-maneuver positions without a flat shootout.
	for offset in [Vector3(-14, 0, -14), Vector3(14, 0, 14), Vector3(-14, 0, 14), Vector3(14, 0, -14)]:
		_fallen_log(offset + Vector3(_rng.randf_range(-3.0, 3.0), 0.0, _rng.randf_range(-3.0, 3.0)), _rng.randf_range(0.0, TAU))
		_wrecked_wall(offset + Vector3(_rng.randf_range(-4.0, 4.0), 0.0, _rng.randf_range(-4.0, 4.0)), _rng.randf_range(0.0, TAU))

	# Rubble and wall remnants (bead sra5) give the centre urban hard cover to
	# fight through. Kept off the exact centre line so the ridge gap stays a lane.
	var rubble_spots: Array[Vector3] = [
		Vector3(-20, 0, 8), Vector3(18, 0, -10), Vector3(-10, 0, -22),
		Vector3(22, 0, 20), Vector3(-26, 0, -6), Vector3(8, 0, 26),
		Vector3(-8, 0, 20), Vector3(26, 0, -20),
	]
	for i in range(rubble_spots.size()):
		var model: String = CONTACT_RUBBLE[i % CONTACT_RUBBLE.size()]
		_place_ruin(model, rubble_spots[i], _rng.randf_range(0.0, TAU), _rng.randf_range(1.0, 1.5))

	# Bamboo clusters around the ridge gaps for close-concealment approaches.
	for pos in [Vector3(-10, 0, 0), Vector3(10, 0, 0)]:
		_bamboo_clump(pos + Vector3(_rng.randf_range(-2.0, 2.0), 0.0, _rng.randf_range(-2.0, 2.0)))


func _build_cover_clusters() -> void:
	# Scatter rocks and small sandbags along the flanks and firebase/village
	# approaches. Keep the central ridge and contact zone clear for wrecked cover.
	for i in range(34):
		var pos := Vector3(_rng.randf_range(-92.0, 92.0), 0.0, _rng.randf_range(-92.0, 92.0))
		if absf(pos.x) < 34.0 and absf(pos.z) < 34.0:
			continue  # leave the central ridge/contact zone to wrecked cover
		if pos.distance_to(Vector3(-62.0, 0.0, 62.0)) < 16.0:
			continue  # firebase LZ
		if pos.distance_to(Vector3(55.0, 0.0, -55.0)) < 20.0:
			continue  # village
		var h: float = _rng.randf_range(0.6, 1.6)
		var w: float = _rng.randf_range(1.2, 3.0)
		var d: float = _rng.randf_range(1.2, 3.0)
		var rock := StaticBody3D.new()
		rock.collision_layer = 1
		rock.collision_mask = 0
		rock.add_to_group("nav_source")
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(w, h, d)
		mi.mesh = bm
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.45, 0.42, 0.38)
		mi.material_override = mat
		rock.add_child(mi)
		var cs := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = Vector3(w, h, d)
		cs.shape = shape
		rock.add_child(cs)
		add_child(rock)
		rock.global_position = pos + Vector3(0, h * 0.5, 0)


func _berm_segment(center: Vector3, size: Vector3, twist: float = 0.0) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.add_to_group("nav_source")
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.42, 0.40, 0.35)
	mi.material_override = mat
	body.add_child(mi)
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	body.add_child(cs)
	add_child(body)
	body.global_position = center + Vector3(0, size.y * 0.5, 0)
	body.rotation.y = twist


func _tree_clump(pos: Vector3) -> void:
	var variants: Array[String] = ["jungle_palm_b1", "jungle_palm_b2", "broadleaf_a", "broadleaf_b", "broadleaf_c"]
	var variant: String = variants[_rng.randi_range(0, variants.size() - 1)]
	var path: String = "res://assets/world/vegetation/" + variant + ".glb"
	if not ResourceLoader.exists(path):
		return
	var packed: PackedScene = load(path)
	var tree := packed.instantiate() as Node3D
	if tree == null:
		return
	add_child(tree)
	tree.global_position = pos
	tree.rotation.y = _rng.randf_range(0.0, TAU)
	tree.scale = Vector3.ONE * _rng.randf_range(0.85, 1.25)
	_add_trunk_collider(tree)
	# Canopy conceals: stamp heavy density so a man in this clump has a ~50m sight cap.
	_stamp_veg_circle(pos, 9.0, VEG_HEAVY)


func _fallen_log(pos: Vector3, rot: float) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.add_to_group("nav_source")
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.height = _rng.randf_range(3.0, 5.0)
	cm.top_radius = 0.45
	cm.bottom_radius = 0.45
	mi.mesh = cm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.35, 0.30, 0.25)
	mi.material_override = mat
	body.add_child(mi)
	var cs := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.height = cm.height
	cyl.radius = cm.top_radius
	cs.shape = cyl
	body.add_child(cs)
	add_child(body)
	body.global_position = pos + Vector3(0, cm.top_radius, 0)
	body.rotation.z = PI * 0.5
	body.rotation.y = rot


func _wrecked_wall(pos: Vector3, rot: float) -> void:
	_sandbag_wall(Vector3(_rng.randf_range(2.0, 4.0), _rng.randf_range(0.8, 1.4), 0.7), pos)
	var body: Node = get_child(get_child_count() - 1)
	if body != null:
		body.rotation.y = rot


func _bamboo_clump(pos: Vector3) -> void:
	var variants: Array[String] = ["bamboo_a", "bamboo_b", "bamboo_c"]
	for i in range(4):
		var variant: String = variants[i % variants.size()]
		var path: String = "res://assets/world/vegetation/" + variant + ".glb"
		if not ResourceLoader.exists(path):
			continue
		var packed: PackedScene = load(path)
		var shoot := packed.instantiate() as Node3D
		if shoot == null:
			continue
		add_child(shoot)
		shoot.global_position = pos + Vector3(_rng.randf_range(-1.5, 1.5), 0.0, _rng.randf_range(-1.5, 1.5))
		shoot.rotation.y = _rng.randf_range(0.0, TAU)
		shoot.scale = Vector3.ONE * _rng.randf_range(0.9, 1.3)
		_add_trunk_collider(shoot)
	# Concealment for the whole thicket (incl. the ridge-gap clumps at +/-10,0 that sit
	# right on the contact approaches, so the sight cap bites where units actually fight).
	_stamp_veg_circle(pos, 5.0, VEG_CONCEAL)


func _elephant_grass_strip(rect: Rect2) -> void:
	var mesh: Mesh = GroundClutter.load_glb_mesh("res://assets/world/vegetation/elephant_grass_a.glb")
	if mesh == null:
		return
	_varray_multimesh(mesh, rect, 80, Color(0.45, 0.55, 0.25))
	_stamp_veg_rect(rect, VEG_CONCEAL)


func _sandbag_wall(size: Vector3, pos: Vector3) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.add_to_group("nav_source")
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.55, 0.50, 0.40)
	mi.material_override = mat
	body.add_child(mi)
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	body.add_child(cs)
	add_child(body)
	body.global_position = pos


func _fighting_hole(pos: Vector3) -> void:
	# L-shaped dirt parapet.
	for offset in [Vector3(-1.5, 0.4, 0), Vector3(1.5, 0.4, 0), Vector3(0, 0.4, -1.5)]:
		_sandbag_wall(Vector3(1.0, 0.8, 0.6), pos + offset + Vector3(0, 0.4, 0))


func _platform(pos: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.add_to_group("nav_source")
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.35, 0.38, 0.32)
	mi.material_override = mat
	body.add_child(mi)
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	body.add_child(cs)
	add_child(body)
	body.global_position = pos + Vector3(0, size.y * 0.5, 0)


func _building(pos: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.add_to_group("nav_source")
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.62, 0.55, 0.45)
	mi.material_override = mat
	body.add_child(mi)
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	body.add_child(cs)
	add_child(body)
	body.global_position = pos + Vector3(0, size.y * 0.5, 0)


func _plant_vegetation() -> void:
	# Rice patches in SE/NW fields.
	var rice_dir := "res://assets/world/vegetation/"
	for patch in ["rice_a", "rice_b"]:
		var mesh: Mesh = GroundClutter.load_glb_mesh(rice_dir + patch + ".glb")
		if mesh == null:
			continue
		for rect in [Rect2(-92, -92, 34, 34), Rect2(58, 58, 34, 34)]:
			_varray_multimesh(mesh, rect, 55, Color(0.55, 0.65, 0.35))
			_stamp_veg_rect(rect, VEG_RICE)

	# Palm clusters at firebase and village edges.
	var palm_variants: Array[String] = ["jungle_palm_a1", "jungle_palm_a2", "jungle_palm_a3"]
	for base in [Vector3(-62, 0, 62), Vector3(55, 0, -55)]:
		for i in range(6):
			var variant: String = palm_variants[i % palm_variants.size()]
			if not ResourceLoader.exists("res://assets/world/vegetation/" + variant + ".glb"):
				continue
			var packed: PackedScene = load("res://assets/world/vegetation/" + variant + ".glb")
			var palm := packed.instantiate() as Node3D
			if palm == null:
				continue
			add_child(palm)
			palm.global_position = base + Vector3(_rng.randf_range(-10, 10), 0, _rng.randf_range(-10, 10))
			palm.rotation.y = _rng.randf_range(0.0, TAU)
			_add_trunk_collider(palm)
			_stamp_veg_circle(palm.global_position, 4.0, VEG_PALM)


func _varray_multimesh(mesh: Mesh, rect: Rect2, count: int, tint: Color) -> void:
	var mmi := MultiMeshInstance3D.new()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.instance_count = count
	mm.mesh = mesh
	mmi.multimesh = mm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = tint
	mmi.material_override = mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if _clutter_root != null:
		_clutter_root.add_child(mmi)
	else:
		add_child(mmi)
	for i in range(count):
		var pos := Vector3(
			_rng.randf_range(rect.position.x, rect.position.x + rect.size.x),
			0.0,
			_rng.randf_range(rect.position.y, rect.position.y + rect.size.y))
		var basis := Basis(Vector3.UP, _rng.randf_range(0.0, TAU))
		var s: float = _rng.randf_range(0.9, 1.4)
		basis = basis.scaled(Vector3(s, s, s))
		mm.set_instance_transform(i, Transform3D(basis, pos))


func _add_trunk_collider(palm: Node3D) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.add_to_group("nav_source")
	var cs := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 0.3
	cyl.height = 3.0
	cs.shape = cyl
	cs.position.y = 1.5
	body.add_child(cs)
	palm.add_child(body)


## Instance a ruins GLB (bead sra5) and wrap it in a footprint box collider so it
## is hard cover, blocks LOS, and bakes into the navmesh. Interiors read as solid
## (footprint collision only) - fine for a stress lab; walkable interiors are future work.
func _place_ruin(model: String, pos: Vector3, yaw: float, scale_mult: float) -> void:
	var path: String = RUIN_DIR + model + ".glb"
	if not ResourceLoader.exists(path):
		return
	var packed: PackedScene = load(path)
	if packed == null:
		return
	var ruin := packed.instantiate() as Node3D
	if ruin == null:
		return
	add_child(ruin)
	ruin.global_position = pos
	ruin.rotation.y = yaw
	ruin.scale = Vector3.ONE * scale_mult
	_add_aabb_collider(ruin)


## Compute the visual AABB across a node's MeshInstance3D descendants and add a
## StaticBody3D box collider matching that footprint, tagged for nav baking.
func _add_aabb_collider(root: Node3D) -> void:
	var aabb := AABB()
	var found: bool = false
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		var mi := n as MeshInstance3D
		if mi != null and mi.mesh != null:
			var local: AABB = mi.get_aabb()
			# Transform the mesh AABB into root space so a multi-part ruin sums up.
			var xform: Transform3D = root.global_transform.affine_inverse() * mi.global_transform
			var world_box: AABB = xform * local
			if not found:
				aabb = world_box
				found = true
			else:
				aabb = aabb.merge(world_box)
		for c in n.get_children():
			stack.append(c)
	if not found or aabb.size.length() < 0.1:
		return
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.add_to_group("nav_source")
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	# Shrink the footprint slightly so agents can hug the wall without clipping.
	box.size = Vector3(maxf(0.3, aabb.size.x - 0.2), maxf(0.3, aabb.size.y), maxf(0.3, aabb.size.z - 0.2))
	cs.shape = box
	cs.position = aabb.position + aabb.size * 0.5
	body.add_child(cs)
	root.add_child(body)


func _bake_navmesh() -> void:
	var region := NavigationRegion3D.new()
	_nav_region = region
	region.add_to_group("lab_navmesh")
	var nm := NavigationMesh.new()
	nm.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nm.geometry_source_geometry_mode = NavigationMesh.SOURCE_GEOMETRY_GROUPS_WITH_CHILDREN
	nm.geometry_source_group_name = "nav_source"
	# Snapped to the 0.25 voxel grid - the baker quantizes these anyway and warns otherwise.
	nm.agent_radius = 0.5
	nm.agent_height = 2.0
	nm.agent_max_climb = 0.25
	region.navigation_mesh = nm
	add_child(region)
	region.bake_navigation_mesh(false)
	print("[AI STRESS ARENA] navmesh baked: %d polys" % region.navigation_mesh.get_polygon_count())


## ---------- FORCES ----------

func _spawn_player() -> void:
	if not spawn_player:
		return
	var scene: PackedScene = load("res://scenes/player/player.tscn")
	player = scene.instantiate() as CharacterBody3D
	add_child(player)
	player.set("allow_photo_mode", false)  # a stray P must not drone off mid-firefight
	player.global_position = Vector3(-35.0, 1.0, 35.0)  # firebase overlook
	GameManager.player = player

	# The player camera renders the scene; make it current explicitly so a boot
	# never lands on the grey no-camera void.
	var cam := player.get_node_or_null("Head/Camera3D") as Camera3D
	if cam != null:
		cam.current = true

	# God mode comes up the way he left it (default ON), [F7] toggles.
	_load_lab_prefs()
	_set_god_mode(_god_on)

	_spawn_player_rto()

	if not spawn_hud:
		return
	var hud: HUD = load("res://scenes/ui/hud.tscn").instantiate() as HUD
	add_child(hud)
	var health_system: HealthSystem = player.get_node("HealthSystem")
	var weapon_holder: WeaponHolder = player.get_node("Head/Camera3D/WeaponHolder")
	var equipment_manager: EquipmentManager = player.get_node("EquipmentManager")
	var grenade_handler: GrenadeHandler = player.get_node("Head/Camera3D/GrenadeHandler")
	hud.setup(health_system, weapon_holder, equipment_manager, grenade_handler)

	equipment_manager.add_grenade(LAB_GRENADES - equipment_manager.get_grenade_count())
	# Deferred: WeaponHolder._equip resets spares to 3 as it seats the starting weapon,
	# so stocking inside this frame would be overwritten by it.
	call_deferred("_stock_player_ammo", weapon_holder)


func _stock_player_ammo(weapon_holder: WeaponHolder) -> void:
	if weapon_holder == null or not is_instance_valid(weapon_holder):
		return
	weapon_holder.primary_ammo[1] = LAB_SPARE_MAGS
	weapon_holder.secondary_ammo[1] = LAB_SPARE_MAGS
	weapon_holder.spare_magazines = LAB_SPARE_MAGS
	weapon_holder.magazine_changed.emit(weapon_holder.current_ammo, LAB_SPARE_MAGS)


## The player's RTO: one commandable radioman who carries the PRC-25, follows the
## player alone (his own AllyBase order, not a squad order), and hands the player
## his handset. NOT part of the autonomous _us_squads, so ordering him never touches
## the arena's other men. Reuses the existing ally/RTO - no bespoke entity.
func _spawn_player_rto() -> void:
	if player == null:
		return
	var pos: Vector3 = player.global_position + Vector3(2.5, 0.0, 1.5)
	var rto: AllyBase = AllyBase.spawn_ally(self, pos)
	if rto == null:
		return
	rto.add_to_group("radioman")
	rto.member = {"nick": "SPARKS", "mos": "RTO"}
	rto.set_sprite("us_grunt_rto", "m16a1", "US")
	rto.set_order(AllyBase.OrderMode.FOLLOW)
	var handset := RadioHandset.attach_to(rto)
	if handset != null:
		player.call("bind_radio_handset", handset)
	print("[AI STRESS ARENA] player RTO spawned (commandable, PRC-25 %s)"
			% ("wired" if handset != null else "MISSING"))


## ---------- FORTIFICATION TESTBED ----------

func _build_fortifications() -> void:
	_load_fort_meshes()
	# A forward wire+sandbag line, alternating segments, that the sappers breach.
	var z: float = FORT_LINE_Z0
	var i: int = 0
	while z <= FORT_LINE_Z1 + 0.01:
		var pos := Vector3(FORT_LINE_X, 0.0, z)
		_spawn_fort(pos, "sandbag_wall" if i % 2 == 0 else "wire")
		z += FORT_SEG_LEN
		i += 1
	# Two bunkers anchor the line as tougher demolition targets (sapper variety), and a
	# watchtower behind it - the tallest thing a satchel has to be able to bring down.
	_spawn_fort(Vector3(FORT_LINE_X - 2.0, 0.0, FORT_LINE_Z0 + 4.0), "bunker")
	_spawn_fort(Vector3(FORT_LINE_X - 2.0, 0.0, FORT_LINE_Z1 - 4.0), "bunker_mg")
	_spawn_fort(Vector3(FORT_LINE_X - 6.0, 0.0, (FORT_LINE_Z0 + FORT_LINE_Z1) * 0.5), "tower")
	# Two mannable M60 posts, both facing downrange (east) where the sappers cross:
	# the NORTH nest stands up its own AI gun crew, the SOUTH nest waits for the
	# player - one testbed, both manning paths (Phase 4).
	_place_mg_nest(Vector3(FORT_LINE_X - 1.2, 0.0, FORT_LINE_Z1 + 2.5), true)
	_place_mg_nest(Vector3(FORT_LINE_X - 1.2, 0.0, FORT_LINE_Z0 - 2.5), false)
	print("[AI STRESS ARENA] fortifications: %d destructible segments + 2 mannable M60 nests" % _forts.size())


## Lift each kind's art ONCE. The lifter instantiates a 300 MB GLB per call, so the 14-segment
## line must not call it 14 times.
func _load_fort_meshes() -> void:
	_fort_mesh_pool.clear()
	for spec in FireSupportBench.TARGET_KINDS:
		var kind: String = str(spec["kind"])
		if not Destructible.HP_FOR.has(kind):
			continue
		var meshes: Array[Mesh] = FireSupportBench.lift_meshes(
			str(spec["prefix"]), FORT_MESH_VARIANTS, str(spec["src"]))
		if meshes.is_empty():
			push_warning("[AI STRESS ARENA] no '%s' art - that fort kind is missing from the line"
				% str(spec["prefix"]))
			continue
		_fort_mesh_pool[kind] = meshes


## One fort piece. The art MUST be the firebase's own, lifted through FireSupportBench: a
## bench that proves a stand-in breaks has proved nothing about the thing that has to break.
func _spawn_fort(pos: Vector3, kind: String) -> void:
	var meshes: Array[Mesh] = _fort_mesh_pool.get(kind, [] as Array[Mesh])
	if meshes.is_empty():
		return
	# Vary the piece so a 14-segment line is not one mesh repeated (deterministic: index,
	# never Time - ADR-010).
	var mesh: Mesh = meshes[_forts.size() % meshes.size()]
	var fort: Destructible = FireSupportBench.spawn_lifted(
		self, mesh, pos, kind, Destructible.hp_for(kind))
	fort.add_to_group("nav_source")
	fort.add_to_group("arena_fortification")
	_forts.append(fort)


## A real mannable M60 post (MGEmplacement builds its own sandbag/pintle/stand).
## man_with_ai stands up a promoted gun crew on it; otherwise it waits for [F].
func _place_mg_nest(pos: Vector3, man_with_ai: bool = false) -> void:
	var emp := MGEmplacement.create(self, pos, Vector3(1.0, 0.0, 0.0))
	if man_with_ai:
		_spawn_mg_gunner(emp)


## Stand up an AI gun crew and put it on the gun. It is a normal AllyBase holding
## its own post + intent (Pillar 4) - the emplacement just gives it the M60 and
## points it at its sector; acquire and fire stay the man's own.
func _spawn_mg_gunner(emp: MGEmplacement) -> void:
	var ally := AllyBase.spawn_ally(self, emp.gunner_stand_pos())
	ally.squad_member = false
	var rng := RandomNumberGenerator.new()
	rng.seed = absi(hash(Vector2i(int(emp.global_position.x), int(emp.global_position.z))))
	ally.member = SquadRoster.generate_member(rng, "MG")
	if _field_director != null:
		ally.director = _field_director
	ally.set_order(AllyBase.OrderMode.HOLD, emp.gunner_stand_pos())
	emp.man_by_ai(ally)


func _place_tunnel_entrance() -> void:
	# One VC tunnel mouth in the "tunnel_entrances" group: HOLD interact with a satchel
	# on the belt collapses it (player.gd:427 _tick_satchel_hold). The player already
	# carries 2 satchels by default (player.gd:91), so the verb is available on boot.
	var entrance := Node3D.new()
	entrance.name = "ArenaTunnelMouth"
	if ResourceLoader.exists(SiteLayouts.TUNNEL_MODEL):
		var packed: PackedScene = load(SiteLayouts.TUNNEL_MODEL)
		var vis := packed.instantiate() as Node3D
		if vis != null:
			entrance.add_child(vis)
	add_child(entrance)
	entrance.global_position = TUNNEL_POS
	entrance.add_to_group("tunnel_entrances")


## ---------- FIRE SUPPORT ----------

func _wire_fire_support() -> void:
	if player == null:
		return
	_field_director = FireSupportBench.wire(self, player, ARENA)
	_field_director.toast.connect(_on_director_toast)
	print("[AI STRESS ARENA] fire support wired via FireSupportBench - RTO net live")
	if spawn_cover:
		_wire_siege()
	if OS.get_cmdline_user_args().has("--mg-probe"):
		call_deferred("_probe_mg_mount")


## Stand up a SiegeDirector aimed at the fortification line. The assault comes in on
## bearing 0 (east), the axis the arena sappers already cross, so the wire, the two
## M60 nests and the breach are all in the same sector. Cadence is NOT wired - the
## night roll belongs to the campaign; here it opens only on [J].
func _wire_siege() -> void:
	var wire_center := Vector3(FORT_LINE_X, 0.0, (FORT_LINE_Z0 + FORT_LINE_Z1) * 0.5)
	_siege = SiegeDirector.new()
	_siege.name = "ArenaSiegeDirector"
	add_child(_siege)
	_siege.setup(_field_director, wire_center, wire_center)
	_siege.set_physics_process(false)   # no _maybe_open on the bench: [J] is the only trigger
	_siege.sector_bearing = 0.0
	_siege.ring_min = SIEGE_RING_MIN
	_siege.ring_max = SIEGE_RING_MAX
	_siege.rally_m = SIEGE_RALLY_M
	_siege.mortar_standoff_m = SIEGE_MORTAR_STANDOFF
	_siege.cell_materialize_m = SIEGE_MATERIALIZE_M
	_siege.siege_began.connect(_on_siege_began)
	_siege.siege_ended.connect(_on_siege_ended)
	print("[AI STRESS ARENA] siege wired at the wire line - press [J] for %d attackers" % SIEGE_STRENGTH)


## `--mg-probe`: drive the whole mounted-M60 path with no hands - mount, inspect,
## fire - and print what the mount ACTUALLY produced. Exists because reading the
## source ruled out the scene, the .tres and the GLB and still explained nothing.
func _probe_mg_mount() -> void:
	await get_tree().process_frame
	var wh: WeaponHolder = player.get_node_or_null("Head/Camera3D/WeaponHolder") as WeaponHolder
	var cam: Camera3D = player.get_node_or_null("Head/Camera3D") as Camera3D
	if wh == null:
		print("[MG-PROBE] FAIL: no WeaponHolder on the player")
		get_tree().quit()
		return
	print("[MG-PROBE] pre-mount: weapon=%s model=%s ammo=%d" % [
		wh.current_weapon.id if wh.current_weapon else "<none>",
		"yes" if wh.weapon_model != null else "NO", wh.current_ammo])

	var emp: MGEmplacement = null
	for e in get_tree().get_nodes_in_group("mg_emplacements"):
		var m := e as MGEmplacement
		if m != null and not m.is_occupied():
			emp = m
			break
	if emp == null:
		print("[MG-PROBE] FAIL: no free emplacement in the scene")
		get_tree().quit()
		return
	print("[MG-PROBE] mounting %s at %s" % [emp.name, emp.gunner_stand_pos()])
	var ok: bool = emp.man_by_player(player)
	await get_tree().process_frame
	await get_tree().process_frame

	print("[MG-PROBE] man_by_player=%s is_manning=%s" % [ok, player.get("is_manning_mg")])
	print("[MG-PROBE] weapon=%s ammo=%d spare=%d mode=%d" % [
		wh.current_weapon.id if wh.current_weapon else "<none>",
		wh.current_ammo, wh.spare_magazines,
		wh.current_weapon.firing_mode if wh.current_weapon else -1])
	print("[MG-PROBE] weapon_model=%s" % ("yes" if wh.weapon_model != null else "NO - INVISIBLE GUN"))
	if wh.weapon_model != null:
		var mp: Node3D = wh.weapon_model.find_child("MuzzlePoint", true, false) as Node3D
		print("[MG-PROBE]   model_pos=%s muzzle=%s cam=%s" % [
			wh.weapon_model.global_position,
			mp.global_position if mp != null else "<no MuzzlePoint>",
			cam.global_position if cam != null else "<no cam>"])

	var before: int = wh.current_ammo
	var shots_before: int = WeaponHolder.session_shots
	for i in range(5):
		wh.can_fire = true
		wh.fire_timer = 0.0
		wh._try_fire()
		await get_tree().physics_frame
	print("[MG-PROBE] fired 5x -> ammo %d->%d, session_shots %d->%d" % [
		before, wh.current_ammo, shots_before, WeaponHolder.session_shots])
	print("[MG-PROBE] jammed=%s reloading=%s switching=%s" % [
		wh.is_jammed, wh.is_reloading, wh.is_switching])
	get_tree().quit()


## [J]. Re-arms a spent run so the assault can be watched as many times as he wants.
func _launch_arena_siege() -> void:
	if _siege == null or _siege.active:
		return
	_siege.nights_run = 0
	_siege.run_strength = 0
	_siege.set_physics_process(true)
	_siege.open_siege(SIEGE_STRENGTH)


var _siege_wave: int = 0


func _on_siege_began(strength: int, is_probe: bool) -> void:
	_siege_wave += 1
	var cell_sizes: Array[int] = []
	for c in _siege.cells:
		cell_sizes.append(c.strength)
	print("[AI STRESS ARENA] WAVE %d: %d attackers in %d cells %s%s" % [
		_siege_wave, strength, cell_sizes.size(), str(cell_sizes), " (PROBE)" if is_probe else ""])
	_on_director_toast("WAVE %d: %d ATTACKERS IN %d CELLS" % [_siege_wave, strength, cell_sizes.size()])
	_assign_defense_zones()
	if _siege_wave == 1:
		_random_illum_tick()


## DEFENSIVE ZONES (his decree 2026-08-05): "no one was trying to defend the
## firebase we had... the usual contact on defense is hold and fight." The moment
## a wave steps off, every living US man is assigned a sector on the wire and
## HOLDS it - the AllyBase zone doctrine forbids hunting off the firebase.
const DEFENSE_ZONE_RADIUS: float = 16.0

## Shipped-system statics the arena overrides for the lab, restored in _exit_tree.
var _prev_tiering: bool = true
var _prev_gib_lifetime: float = 12.0
var _prev_cone_mult: float = 1.0
var _prev_player_dmg: float = 1.0


func _assign_defense_zones() -> void:
	var z_len: float = FORT_LINE_Z1 - FORT_LINE_Z0
	var anchors: Array[Vector3] = [
		Vector3(FORT_LINE_X, 0.0, FORT_LINE_Z0 + z_len * 0.25),
		Vector3(FORT_LINE_X, 0.0, FORT_LINE_Z0 + z_len * 0.5),
		Vector3(FORT_LINE_X, 0.0, FORT_LINE_Z0 + z_len * 0.75),
	]
	var n: int = 0
	for squad in _us_squads:
		for a in squad:
			if a == null or not is_instance_valid(a) or a.is_dead():
				continue
			if a.defense_zone_radius > 0.0:
				n += 1
				continue   # already manning his sector from an earlier wave
			a.defense_zone = anchors[n % anchors.size()]
			a.defense_zone_radius = DEFENSE_ZONE_RADIUS
			# Man the line: run to the sector; combat + the zone keep him there.
			if a.order_mode != AllyBase.OrderMode.RESCUE:
				a.set_order(AllyBase.OrderMode.MOVE_TO,
					a.defense_zone + Vector3(_rng.randf_range(-6.0, 6.0), 0.0, _rng.randf_range(-6.0, 6.0)))
			n += 1
	if n > 0:
		print("[AI STRESS ARENA] defense zones assigned: %d men on 3 wire sectors" % n)


## SURVIVAL CHAIN (his ruling 2026-08-04: "as many enemy assault waves as i can
## last... send 30 people at a time"). A broken wave breathes, then the next one
## steps off - it ends when HE ends.
func _on_siege_ended(reason: String, killed: int, strength: int) -> void:
	print("[AI STRESS ARENA] WAVE %d END - %s | %d of %d killed" % [_siege_wave, reason, killed, strength])
	if _player_gone():
		_on_director_toast("WAVE %d TOOK YOU - %d WAVES HELD" % [_siege_wave, _siege_wave - 1])
		return
	_on_director_toast("WAVE %d BROKE: %s - %d/%d KILLED. NEXT WAVE IN %ds" % [
		_siege_wave, reason.to_upper(), killed, strength, int(WAVE_BREATHER_S)])
	get_tree().create_timer(WAVE_BREATHER_S).timeout.connect(func() -> void:
		if not _player_gone() and _siege != null and is_instance_valid(_siege) and not _siege.active:
			_launch_arena_siege())


func _player_gone() -> bool:
	return player == null or not is_instance_valid(player) \
		or (player.has_method("is_dead") and bool(player.call("is_dead")))


## RANDOM ILLUMINATION (his ruling 2026-08-04: "give me random illumination
## rounds"). While waves run, an 81mm illum pops over a random patch of the
## fight every 20-45s - the real _illum_burst theatre, no stock spent.
func _random_illum_tick() -> void:
	if _player_gone():
		return
	if _siege != null and is_instance_valid(_siege) and _siege.active \
			and _field_director != null and is_instance_valid(_field_director):
		var wire_center := Vector3(FORT_LINE_X, 0.0, (FORT_LINE_Z0 + FORT_LINE_Z1) * 0.5)
		var ang: float = randf() * TAU
		var r: float = randf_range(15.0, 65.0)
		_field_director._fire_shell(FieldDirector.MORTAR_SHELL,
			wire_center + Vector3(cos(ang) * r, 0.0, sin(ang) * r),
			_field_director._illum_burst)
	get_tree().create_timer(randf_range(20.0, 45.0)).timeout.connect(_random_illum_tick)


func _on_director_toast(text: String) -> void:
	if _toast_label != null:
		_toast_label.text = text
		_toast_t = 4.0


## ---------- SAPPER ASSAULT ----------

## Stand up a sapper wave in the open, each carrying a live SapperCharge aimed at the
## wire line. They cross through contact (EnemyBase.assault_objective) and breach the
## fortifications where they detonate. Repeatable on demand (K); one wave auto-launches
## SAPPER_AUTO_DELAY after boot so the first breach is witnessed.
func _launch_arena_sappers() -> void:
	var aim_z: float = (FORT_LINE_Z0 + FORT_LINE_Z1) * 0.5
	var base := Vector3(FORT_LINE_X + 55.0, 1.0, aim_z)
	for i in range(ARENA_SAPPER_COUNT):
		var off := Vector3(_rng.randf_range(-5, 5), 0.0, float(i - 1) * 7.0)
		var sapper := EnemyBase.spawn_enemy(self, base + off, SiegeDirector.SAPPER_DATA)
		if sapper == null:
			continue
		sapper.squad_id = -1  # lone: a squad hunt_point must never steer a driven man
		sapper.add_to_group("arena_sapper")
		var nav_agent := sapper.get_node_or_null("NavigationAgent3D") as NavigationAgent3D
		if nav_agent != null and _nav_region != null:
			nav_agent.set_navigation_map(_nav_region.get_navigation_map())
		var aim := Vector3(FORT_LINE_X, 0.6, aim_z + off.z * 0.5)
		var charge := SapperCharge.new()
		sapper.add_child(charge)
		charge.setup(aim)
	if _field_director != null:
		_field_director.toast.emit("SAPPERS ON THE WIRE - THREE DAC CONG CROSSING")


func _update_sandbox(delta: float) -> void:
	if _toast_t > 0.0:
		_toast_t -= delta
		if _toast_t <= 0.0 and _toast_label != null:
			_toast_label.text = ""
	if not spawn_player:
		return
	if enemy_mortars and _siege != null:
		_mortar_t -= delta
		if _mortar_t <= 0.0:
			_mortar_t = randf_range(MORTAR_INTERVAL_MIN, MORTAR_INTERVAL_MAX)
			_call_mortars_on_player()
	if _sapper_auto_done:
		return
	_sapper_auto_t -= delta
	if _sapper_auto_t <= 0.0:
		_sapper_auto_done = true
		_launch_arena_sappers()


## The tube is ranging on the player, not on a fixed point - the volley is aimed
## where he stands when the rounds leave, so standing still is what kills.
func _call_mortars_on_player() -> void:
	if _siege == null or player == null or not is_instance_valid(player):
		return
	_siege.fire_mortar_volley(player.global_position, MORTAR_SPREAD_M)
	_on_director_toast("INCOMING - MORTARS")


func _spawn_initial_forces() -> void:
	_us_reserves_left = us_reserve_squads
	_vc_reserves_left = vc_reserve_squads
	_us_reinforce_cd = 0.0
	_vc_reinforce_cd = 0.0

	# hot_start is an immediate-combat sanity mode: spawn near the centre so contact
	# is instant. Patrol / move-to-contact use opposite ends with a wide no-contact gap.
	var us_bases: Array[Vector3]
	var vc_bases: Array[Vector3]
	if hot_start:
		us_bases = [Vector3(-40, 1.0, 40), Vector3(-25, 1.0, 25), Vector3(-40, 1.0, 20)]
		vc_bases = [Vector3(35, 1.0, -35), Vector3(45, 1.0, -25), Vector3(25, 1.0, -45)]
	else:
		us_bases = [Vector3(-70, 1.0, 70), Vector3(-55, 1.0, 80), Vector3(-80, 1.0, 55)]
		vc_bases = [Vector3(70, 1.0, -70), Vector3(80, 1.0, -55), Vector3(55, 1.0, -80)]

	for i in range(us_squads_active):
		var center: Vector3 = us_bases[i % us_bases.size()] + Vector3(_rng.randf_range(-4, 4), 0, _rng.randf_range(-4, 4))
		# Patrol: everyone advances toward the centre so contact must develop.
		# Non-patrol: squad 0 holds the firebase, the rest push a forward line.
		var order: AllyBase.OrderMode
		var order_pos: Vector3
		if _patrol_active:
			order = AllyBase.OrderMode.MOVE_TO
			order_pos = CONTACT_POINT + Vector3(_rng.randf_range(-14, 14), 0, _rng.randf_range(-14, 14))
		elif i == 0:
			order = AllyBase.OrderMode.HOLD
			order_pos = center
		else:
			order = AllyBase.OrderMode.MOVE_TO
			order_pos = Vector3(-20.0 + float(i) * 8.0, 1.0, 10.0)
		_spawn_us_squad(center, order, order_pos, men_per_squad)

	for i in range(vc_squads_active):
		var center: Vector3 = vc_bases[i % vc_bases.size()] + Vector3(_rng.randf_range(-5, 5), 0, _rng.randf_range(-5, 5))
		_spawn_vc_squad(center, i, men_per_squad, _patrol_active)


func _spawn_us_squad(center: Vector3, order: AllyBase.OrderMode, order_pos: Vector3, count: int) -> void:
	var squad: Array[AllyBase] = []
	var rng := RandomNumberGenerator.new()
	rng.seed = _rng.seed + _us_squads.size() * 97
	for i in range(count):
		var mos: String = US_SQUAD_MOS[i % US_SQUAD_MOS.size()]
		var pos := center + _ring_offset(i)
		var ally := AllyBase.spawn_ally(self, pos)
		if ally == null:
			continue
		var body: String = ARENA_US_BODIES[rng.randi_range(0, ARENA_US_BODIES.size() - 1)]
		ally.set_sprite(body, SquadSystem.weapon_for_mos(mos), "US")
		ally.set_order(order, order_pos)
		if mos == "MG":
			ally.fire_rate_mult = 1.6
		squad.append(ally)
	_us_squads.append(squad)


## Concentric rings of 8 so a wave of up to 26 men spreads out instead of stacking.
func _ring_offset(i: int) -> Vector3:
	var ring: int = i / 8
	var slot: int = i % 8
	var r: float = 3.0 + float(ring) * 3.0
	var ang: float = float(slot) * TAU / 8.0 + float(ring) * 0.4
	return Vector3(cos(ang) * r, 0.0, sin(ang) * r)


func _spawn_vc_squad(center: Vector3, squad_idx: int, count: int, patrol: bool) -> void:
	var squad: Array[EnemyBase] = []
	var squad_id: int = 1000 + squad_idx
	# One patrol route per squad, from the spawn toward the central contact zone.
	var route: Array[Vector3] = []
	if patrol:
		var mid: Vector3 = center * 0.5
		var near_centre: Vector3 = CONTACT_POINT + Vector3(_rng.randf_range(-12, 12), 0, _rng.randf_range(-12, 12))
		route = [center, mid, near_centre]
	for i in range(count):
		var dp: String = VC_PATHS[i % VC_PATHS.size()]
		var pos := center + _ring_offset(i)
		var enemy := EnemyBase.spawn_enemy(self, pos, dp)
		if enemy == null:
			continue
		enemy.squad_id = squad_id
		if patrol:
			# PATROL start: relaxed, walking the route toward contact. They ramp to
			# COMBAT through perception (arena spotting feed) or incoming fire.
			enemy.alert_tier = EnemyBase.AlertTier.RELAXED
			enemy.patrol_route = route.duplicate()
			enemy.patrol_file_slot = i
		else:
			enemy.alert_tier = EnemyBase.AlertTier.ALERT  # they know a fight is coming
			# Seed a last-known point in the central contact zone so they move toward
			# the US advance even when no player is present.
			enemy.last_known_target_pos = CONTACT_POINT + Vector3(_rng.randf_range(-10, 10), 0, _rng.randf_range(-10, 10))
			enemy.target_last_seen_time = 0.0
		# Rough facing toward the firebase (US home end).
		enemy.rotation.y = atan2(-62.0 - pos.x, 62.0 - pos.z)
		# Bind the agent to the arena's baked nav map explicitly. Without this,
		# runtime-spawned agents sometimes fail to resolve a map until a frame later.
		var nav_agent := enemy.get_node_or_null("NavigationAgent3D") as NavigationAgent3D
		if nav_agent != null and _nav_region != null:
			nav_agent.set_navigation_map(_nav_region.get_navigation_map())
		squad.append(enemy)
	_vc_squads.append(squad)


func _hot_start_combat() -> void:
	# Seed every agent with a nearest-hostile target and push both sides into COMBAT.
	# This bypasses the normal perception cold-start so headless probes can observe
	# squad behavior without a player present.
	for squad in _us_squads:
		for a in squad:
			if not is_instance_valid(a) or a.is_dead():
				continue
			var nearest := _nearest_vc(a.global_position)
			if nearest != null:
				a.target = nearest
				a.last_known_target_pos = nearest.global_position
				a.contact_conf = 1.0
				a.target_last_seen_time = 0.0
				a._change_state(Enums.AIState.COMBAT)

	for squad in _vc_squads:
		for e in squad:
			if not is_instance_valid(e) or e.is_dead():
				continue
			var nearest := _nearest_us(e.global_position)
			if nearest != null:
				e.target = nearest
				e.last_known_target_pos = nearest.global_position
				e.target_last_seen_time = 0.0
				e._set_tier(EnemyBase.AlertTier.COMBAT, false)
				e._change_state(Enums.AIState.COMBAT)


func _finish_agent_setup() -> void:
	# HP scaling, kill-count wiring, and arena tuning must run after each agent's
	# _ready() has set its base max_hp, so we defer it from _ready() and from
	# reinforcement spawns.
	for squad in _us_squads:
		for a in squad:
			if not is_instance_valid(a):
				continue
			var target_max: int = int(a.max_hp * ai_hp_multiplier)
			if a.max_hp != target_max:
				a.max_hp = target_max
				a.current_hp = target_max
			if mirror_mode:
				a.max_hp = MIRROR_HP
				a.current_hp = MIRROR_HP
				a.weapon_data = load(MIRROR_WEAPON) as WeaponData
				a.skill = MIRROR_ACC
			if not a.died.is_connected(_on_us_died):
				a.died.connect(_on_us_died)

	for squad in _vc_squads:
		for e in squad:
			if not is_instance_valid(e):
				continue
			var target_max: int = int(e.max_hp * ai_hp_multiplier)
			if e.max_hp != target_max:
				e.max_hp = target_max
				e.current_hp = target_max
			if mirror_mode:
				# Force perfect symmetry: same gun, HP, accuracy; strip the enemy-only retreat +
				# self-preservation bias so the probe reads the fire model and nothing else.
				e.max_hp = MIRROR_HP
				e.current_hp = MIRROR_HP
				e.weapon_data = load(MIRROR_WEAPON) as WeaponData
				e.char_accuracy = MIRROR_ACC
				e.d_retreats_when_hurt = false
			else:
				# Force break-contact under pressure for every arena VC/NVA.
				e.d_retreats_when_hurt = true
				e.d_retreat_hp = ai_retreat_hp
				# Slightly stiffen self-preservation so suppression drives cover/withdrawal.
				e.char_self_preservation = clampf(e.char_self_preservation + 0.12, 0.0, 0.9)
			if not e.died.is_connected(_on_vc_died):
				e.died.connect(_on_vc_died)


func _on_us_died(_ally: AllyBase) -> void:
	_vc_kills += 1


func _on_vc_died(_enemy: EnemyBase) -> void:
	_us_kills += 1


func _nearest_vc(from: Vector3) -> Node3D:
	var best: Node3D = null
	var best_d: float = 99999.0
	for squad in _vc_squads:
		for e in squad:
			if not is_instance_valid(e) or e.is_dead():
				continue
			var d := from.distance_squared_to(e.global_position)
			if d < best_d:
				best_d = d
				best = e as Node3D
	return best


func _nearest_us(from: Vector3) -> Node3D:
	var best: Node3D = null
	var best_d: float = 99999.0
	for squad in _us_squads:
		for a in squad:
			if not is_instance_valid(a) or a.is_dead():
				continue
			var d := from.distance_squared_to(a.global_position)
			if d < best_d:
				best_d = d
				best = a as Node3D
	return best


## A reinforcement wave: 16 + 1d10 men (17-26). Drawn from the arena-local stream,
## never the shared combat-spread stream. Both sides draw independently, matched in
## expectation. This is the per-wave force, replacing the old fixed reserve-squad size.
func _wave_size() -> int:
	return 16 + (_rng.randi() % 10) + 1


func _update_reinforcements(delta: float) -> void:
	var spawned: bool = false
	var interval_min: float = REINFORCE_INTERVAL_MIN / maxf(0.1, reserve_rate_multiplier)
	var interval_max: float = REINFORCE_INTERVAL_MAX / maxf(0.1, reserve_rate_multiplier)
	if _us_reserves_left > 0:
		_us_reinforce_cd -= delta
		if _us_reinforce_cd <= 0.0 and _living_us() < us_squads_active * men_per_squad * 0.5:
			_us_reserves_left -= 1
			_us_reinforce_cd = _rng.randf_range(interval_min, interval_max)
			var n: int = debug_spawn_wave(true)
			spawned = true
			print("[AI STRESS ARENA] US reinforcement wave: %d men (%d wave(s) left)" % [n, _us_reserves_left])

	if _vc_reserves_left > 0:
		_vc_reinforce_cd -= delta
		if _vc_reinforce_cd <= 0.0 and _living_vc() < vc_squads_active * men_per_squad * 0.5:
			_vc_reserves_left -= 1
			_vc_reinforce_cd = _rng.randf_range(interval_min, interval_max)
			var n: int = debug_spawn_wave(false)
			spawned = true
			print("[AI STRESS ARENA] VC reinforcement wave: %d men (%d wave(s) left)" % [n, _vc_reserves_left])

	if spawned:
		call_deferred("_finish_agent_setup")
		if _perf_overlay != null:
			_perf_overlay.note_event("wave spawn")


## Spawn one reinforcement wave for a side and return the man count. Reinforcements
## arrive ALERT and move to contact (the fight is already on). Also the probe seam
## for verifying wave size independent of the attrition trigger.
func debug_spawn_wave(is_us: bool) -> int:
	var n: int = _wave_size()
	if is_us:
		var center := Vector3(-70.0 + _rng.randf_range(-6, 6), 1.0, 70.0 + _rng.randf_range(-6, 6))
		_spawn_us_squad(center, AllyBase.OrderMode.MOVE_TO, CONTACT_POINT, n)
	else:
		var center := Vector3(70.0 + _rng.randf_range(-6, 6), 1.0, -70.0 + _rng.randf_range(-6, 6))
		_spawn_vc_squad(center, 2000 + _vc_squads.size(), n, false)
	call_deferred("_finish_agent_setup")
	return n


## Patrol-mode only. Core enemy perception (enemy_base._update_perception) exempts
## allies as candidates until COMBAT so a friendly AI never breaks player stealth;
## in an AI-vs-AI patrol that means VC would never notice US. This feeds a visible,
## in-arc US contact into the enemy's OWN awareness accumulator, so the VC ramp
## through SUSPICIOUS and promote themselves to COMBAT via their own state machine.
func _update_patrol_contact(delta: float) -> void:
	for squad in _vc_squads:
		for e in squad:
			if not is_instance_valid(e) or e.is_dead():
				continue
			if e.alert_tier == EnemyBase.AlertTier.COMBAT:
				continue
			var seen: Node3D = _spotted_us_for(e)
			if seen != null:
				e.awareness = minf(1.0, e.awareness + SPOT_GAIN * delta)
				e.last_known_target_pos = seen.global_position
				e.target_last_seen_time = 0.0


## Nearest living US ally this enemy can actually see: within SPOT_RANGE, inside a
## generous frontal arc (or point-blank), and with a clear line of sight.
func _spotted_us_for(e: EnemyBase) -> Node3D:
	var eye: Vector3 = e.global_position + Vector3.UP * 1.5
	var facing: Vector3 = Vector3(e.facing_dir.x, 0.0, e.facing_dir.z)
	if facing.length() < 0.01:
		facing = Vector3.FORWARD
	facing = facing.normalized()
	var best: Node3D = null
	var best_d: float = SPOT_RANGE
	for squad in _us_squads:
		for a in squad:
			if not is_instance_valid(a) or a.is_dead():
				continue
			var to: Vector3 = a.global_position - e.global_position
			var d: float = to.length()
			if d > best_d:
				continue
			var flat: Vector3 = Vector3(to.x, 0.0, to.z)
			var in_arc: bool = d < 10.0 or (flat.length() > 0.01 and facing.dot(flat.normalized()) > SPOT_CONE_DOT)
			if not in_arc:
				continue
			if not CombatManager.has_line_of_sight(eye, a.global_position + Vector3.UP * 1.0, [e]):
				continue
			best_d = d
			best = a as Node3D
	return best


func _living_us() -> int:
	var n: int = 0
	for squad in _us_squads:
		for a in squad:
			if is_instance_valid(a) and not a.is_dead():
				n += 1
	return n


func _living_vc() -> int:
	var n: int = 0
	for squad in _vc_squads:
		for e in squad:
			if is_instance_valid(e) and not e.is_dead():
				n += 1
	return n


func _total_us() -> int:
	return _us_squads.size() * men_per_squad


func _total_vc() -> int:
	return _vc_squads.size() * men_per_squad




## ---------- ROUND LIFECYCLE ----------

func _check_round_end() -> void:
	# A running siege is its own fight and outlives the squad round - ending the round
	# under it would tear down the assault mid-breach.
	if _siege != null and _siege.active:
		return
	if _sim_time >= round_max_seconds:
		_end_round("TIME LIMIT (5:00)")
		return
	var us_alive: int = _living_us()
	var vc_alive: int = _living_vc()
	if us_alive == 0 and _us_reserves_left == 0:
		_end_round("VC WINS")
		return
	if vc_alive == 0 and _vc_reserves_left == 0:
		_end_round("US WINS")
		return


func _end_round(result: String) -> void:
	_round_ended = true
	print("[AI STRESS ARENA] ROUND END - %s at %.1fs | US kills: %d | VC kills: %d" % [
		result, _sim_time, _us_kills, _vc_kills])
	if _hud != null:
		_hud.text += "\nROUND END: %s (press R to restart)" % result
	_print_final_summary()


func _print_final_summary() -> void:
	var us_alive: int = _living_us()
	var vc_alive: int = _living_vc()
	print("[AI STRESS ARENA] FINAL | %s | duration %.1fs | US %d alive / %d killed | VC %d alive / %d killed | reserves US:%d VC:%d" % [
		"US WINS" if vc_alive == 0 else ("VC WINS" if us_alive == 0 else "TIME LIMIT"),
		_sim_time, us_alive, _us_kills, vc_alive, _vc_kills, _us_reserves_left, _vc_reserves_left])


func _exit_tree() -> void:
	GibSystem.force_all_gibs = false  # lab-only crank; never leak into a real mission
	EnemySquad.tiering_enabled = _prev_tiering
	GibSystem.gib_lifetime_s = _prev_gib_lifetime
	GameSettings.ai_vs_ai_cone_mult = _prev_cone_mult
	GameSettings.player_outgoing_damage_mult = _prev_player_dmg
	# MissionWeather.is_night is a global static; the bench set it, the bench clears it.
	if bench_dressing:
		MissionWeather.is_night = false


## LAB GOD MODE (his order 2026-08-05: on by default, [F7] toggles, and the
## choice STAYS - persisted to user://arena_lab.cfg so every arena boot comes up
## the way he left it. Lab-only: HealthSystem.god_mode ships false everywhere else.
const LAB_CFG := "user://arena_lab.cfg"
var _god_on: bool = true


func _load_lab_prefs() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(LAB_CFG) == OK:
		_god_on = bool(cfg.get_value("lab", "god_mode", true))


func _set_god_mode(on: bool) -> void:
	_god_on = on
	if player != null and is_instance_valid(player):
		var hs := player.get_node_or_null("HealthSystem") as HealthSystem
		if hs != null:
			hs.set_god_mode(on)
	_on_director_toast("GOD MODE %s" % ("ON" if on else "OFF"))
	var cfg := ConfigFile.new()
	cfg.set_value("lab", "god_mode", on)
	cfg.save(LAB_CFG)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("reload") and _round_ended:
		_restart_round()
	if not (event is InputEventKey and (event as InputEventKey).pressed \
			and not (event as InputEventKey).echo):
		return
	# K launches a fresh sapper wave at the wire so he can watch the breach repeatedly.
	# J launches the whole siege - 30 attackers per wave, chained (survival).
	match (event as InputEventKey).physical_keycode:
		KEY_K:
			_launch_arena_sappers()
		KEY_J:
			_launch_arena_siege()
		KEY_L:
			_call_mortars_on_player()
		KEY_F7:
			_set_god_mode(not _god_on)
		KEY_F3:
			set_debug_vis_active(not _debug_vis_enabled)
			if _hud != null:
				_hud.visible = _debug_vis_enabled


func _restart_round() -> void:
	# Clear living and dead agents.
	for squad in _us_squads:
		for a in squad:
			if is_instance_valid(a):
				a.queue_free()
	for squad in _vc_squads:
		for e in squad:
			if is_instance_valid(e):
				e.queue_free()
	_us_squads.clear()
	_vc_squads.clear()
	_dbg_labels.clear()
	_sim_time = 0.0
	_us_kills = 0
	_vc_kills = 0
	_last_telemetry_log = -999.0
	_us_rounds_fired = 0
	_vc_rounds_fired = 0
	_us_retreats = 0
	_vc_retreats = 0
	_us_suppressed_seconds = 0.0
	_vc_suppressed_seconds = 0.0
	_round_ended = false
	_spawn_initial_forces()


func _wire_telemetry() -> void:
	CombatManager.bullets.bullet_spawned.connect(_on_bullet_spawned)


func _on_bullet_spawned(shooter: Node, _weapon: WeaponData) -> void:
	if shooter == null or not is_instance_valid(shooter):
		return
	if shooter.is_in_group("allies"):
		_us_rounds_fired += 1
	elif shooter.is_in_group("enemies"):
		_vc_rounds_fired += 1
	elif shooter.is_in_group("player") or (shooter.get_parent() != null and shooter.get_parent().is_in_group("player")):
		# Player shots count toward US side for arena telemetry.
		_us_rounds_fired += 1


## ---------- TELEMETRY ----------

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 1
	add_child(layer)
	_hud = Label.new()
	_hud.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_hud.position = Vector2(-620, 12)
	_hud.custom_minimum_size = Vector2(600, 0)
	_hud.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_hud.add_theme_font_size_override("font_size", 13)
	_hud.add_theme_color_override("font_color", Color(0.92, 0.9, 0.8, 0.85))
	_hud.visible = debug_readouts
	layer.add_child(_hud)

	# r4bk: the RTO net's inbound calls (and the sapper bark) must be readable, so the
	# fire-support toasts land on a bottom-centre banner instead of vanishing into stdout.
	_toast_label = Label.new()
	_toast_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_toast_label.position = Vector2(-360, -90)
	_toast_label.custom_minimum_size = Vector2(720, 0)
	_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast_label.add_theme_font_size_override("font_size", 18)
	_toast_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.5))
	_toast_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_toast_label.add_theme_constant_override("outline_size", 6)
	layer.add_child(_toast_label)


func _update_telemetry(delta: float) -> void:
	var us_alive: int = _living_us()
	var vc_alive: int = _living_vc()
	var m: int = int(_sim_time) / 60
	var s: int = int(_sim_time) % 60

	var us_states := _state_histogram(true)
	var vc_states := _state_histogram(false)

	var us_sup: float = _avg_suppression(true)
	var vc_sup: float = _avg_suppression(false)
	var us_dist: float = _avg_distance_to_target(true)
	var vc_dist: float = _avg_distance_to_target(false)

	_accum_suppression_time(delta, us_sup, vc_sup)
	_count_retreats()

	var cover_avg: float = _avg_cover_density()
	var los: Vector2i = _los_counts()
	var contacts: int = los.x + los.y
	var blk_pct: float = 100.0 * float(los.y) / float(maxi(1, contacts))

	if _hud != null:
		_hud.text = "AI STRESS ARENA - %02d:%02d / %02d:%02d\nUS  alive: %d/%d | VC  alive: %d/%d\nUS  reserves: %d | VC reserves: %d\nUS  kills: %d | VC kills: %d\nUS  sup: %.2f | VC sup: %.2f\nUS  dist: %.1fm | VC dist: %.1fm\nCOVER veg(avg): %.2f | LOS clear:%d blocked:%d (%.0f%% blk)\nUS  states: %s\nVC states: %s" % [
			m, s, int(round_max_seconds) / 60, int(round_max_seconds) % 60,
			us_alive, _total_us(), vc_alive, _total_vc(),
			_us_reserves_left, _vc_reserves_left,
			_us_kills, _vc_kills,
			us_sup, vc_sup,
			us_dist, vc_dist,
			cover_avg, los.x, los.y, blk_pct,
			str(us_states), str(vc_states)]

	# 30-second stdout summary for evidence-based tuning.
	if _sim_time - _last_telemetry_log >= 30.0:
		_last_telemetry_log = _sim_time
		print("[AI STRESS ARENA] t=%02d:%02d | US %d/%d (%d kills, %d rounds, %d retreats, %.1fs sup) | VC %d/%d (%d kills, %d rounds, %d retreats, %.1fs sup) | avg dist %.1fm" % [
			m, s,
			us_alive, _total_us(), _us_kills, _us_rounds_fired, _us_retreats, _us_suppressed_seconds,
			vc_alive, _total_vc(), _vc_kills, _vc_rounds_fired, _vc_retreats, _vc_suppressed_seconds,
			(us_dist + vc_dist) * 0.5])
		# Reset cumulative counters each print so deltas are per-bucket.
		_us_rounds_fired = 0
		_vc_rounds_fired = 0
		_us_retreats = 0
		_vc_retreats = 0
		_us_suppressed_seconds = 0.0
		_vc_suppressed_seconds = 0.0


func _accum_suppression_time(delta: float, us_sup: float, vc_sup: float) -> void:
	# Count seconds where average suppression is above the behavior threshold.
	if us_sup >= 0.5:
		_us_suppressed_seconds += delta
	if vc_sup >= 0.5:
		_vc_suppressed_seconds += delta


func _count_retreats() -> void:
	# Point-in-time sample, reset each telemetry bucket. Allies hold no RETREAT
	# goal by design (no ally rout doctrine): their break-contact truth is the
	# heavy-pin SUPPRESSED state or a broken squad.
	for squad in _us_squads:
		for agent in squad:
			if is_instance_valid(agent) and not agent.is_dead() \
					and (agent.current_state == Enums.AIState.SUPPRESSED or agent.squad_broken):
				_us_retreats += 1
	for squad in _vc_squads:
		for agent in squad:
			if is_instance_valid(agent) and not agent.is_dead() and agent.current_goal == Enums.AIGoal.RETREAT:
				_vc_retreats += 1


func _state_histogram(us: bool) -> Dictionary:
	var hist: Dictionary = {}
	var squads := _us_squads if us else _vc_squads
	for squad in squads:
		for agent in squad:
			if not is_instance_valid(agent) or agent.is_dead():
				continue
			var s: String = Enums.AIState.keys()[int(agent.current_state)]
			hist[s] = int(hist.get(s, 0)) + 1
	return hist


func _avg_suppression(us: bool) -> float:
	var total: float = 0.0
	var count: int = 0
	var squads := _us_squads if us else _vc_squads
	for squad in squads:
		for agent in squad:
			if not is_instance_valid(agent) or agent.is_dead():
				continue
			total += agent.suppression_level
			count += 1
	return total / float(maxi(1, count))


func _avg_distance_to_target(us: bool) -> float:
	var total: float = 0.0
	var count: int = 0
	var squads := _us_squads if us else _vc_squads
	for squad in squads:
		for agent in squad:
			if not is_instance_valid(agent) or agent.is_dead():
				continue
			var t: Node3D = agent.target
			if t != null and is_instance_valid(t) and not t.is_dead():
				total += agent.global_position.distance_to(t.global_position)
				count += 1
	return total / float(maxi(1, count))


## Average vegetation density under living units (0 = open, 1 = deep jungle). Proves the
## grid is live and shows how much foliage the fight is actually happening in.
func _avg_cover_density() -> float:
	if gameplay_grid == null:
		return 0.0
	var total: float = 0.0
	var count: int = 0
	for us in [true, false]:
		for squad in (_us_squads if us else _vc_squads):
			for agent in squad:
				if not is_instance_valid(agent) or agent.is_dead():
					continue
				total += gameplay_grid.get_vegetation(agent.global_position)
				count += 1
	return total / float(maxi(1, count))


## Among agents that currently have a living target, how many have a clear line of sight
## vs. a blocked one. A rising blocked count is cover (terrain/trunks/sight-cap) working.
func _los_counts() -> Vector2i:
	var clear: int = 0
	var blocked: int = 0
	for us in [true, false]:
		for squad in (_us_squads if us else _vc_squads):
			for agent in squad:
				if not is_instance_valid(agent) or agent.is_dead():
					continue
				var t: Node3D = agent.target
				if t == null or not is_instance_valid(t) or t.is_dead():
					continue
				if agent.has_line_of_sight:
					clear += 1
				else:
					blocked += 1
	return Vector2i(clear, blocked)


## ---------- DEBUG VISUALIZATION ----------

const TIER_COLORS: Array[Color] = [
	Color(0.5, 0.9, 0.5),   # RELAXED
	Color(0.95, 0.9, 0.4),  # SUSPICIOUS
	Color(1.0, 0.6, 0.2),   # ALERT
	Color(1.0, 0.25, 0.25), # COMBAT
]


func _build_debug_vis() -> void:
	_dbg_im = ImmediateMesh.new()
	_dbg_mesh = MeshInstance3D.new()
	_dbg_mesh.mesh = _dbg_im
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.no_depth_test = true
	_dbg_mesh.material_override = m
	add_child(_dbg_mesh)


func _dbg_label_for(agent: Node3D) -> Label3D:
	var key: int = agent.get_instance_id()
	if _dbg_labels.has(key) and is_instance_valid(_dbg_labels[key]):
		return _dbg_labels[key]
	var l := Label3D.new()
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.fixed_size = true
	l.pixel_size = 0.0006
	l.font_size = 24
	l.outline_size = 6
	l.position = Vector3(0, 2.3, 0)
	agent.add_child(l)
	_dbg_labels[key] = l
	return l


func _update_debug_vis() -> void:
	if _dbg_im == null or not _debug_vis_enabled:
		return
	_dbg_im.clear_surfaces()
	var lines: Array = []

	for squad in _vc_squads:
		for agent in squad:
			if not is_instance_valid(agent):
				continue
			var lbl := _dbg_label_for(agent)
			if agent.is_dead():
				lbl.text = "DEAD"
				lbl.modulate = Color(0.5, 0.5, 0.5, 0.5)
				continue
			var tier: int = clampi(int(agent.alert_tier), 0, 3)
			var state_name: String = Enums.AIState.keys()[int(agent.current_state)]
			var goal_name: String = Enums.AIGoal.keys()[int(agent.current_goal)]
			lbl.text = "%s\n%s | cov:%s sup:%.1f" % [state_name, goal_name, "Y" if agent.has_cover else "n", agent.suppression_level]
			lbl.modulate = TIER_COLORS[tier]
			if agent.target != null and is_instance_valid(agent.target):
				var from: Vector3 = agent.global_position + Vector3.UP * 1.5
				if agent.has_line_of_sight:
					lines.append([from, agent.target.global_position + Vector3.UP * 1.0, Color(1.0, 0.2, 0.2, 0.85)])
				elif agent.last_known_target_pos != Vector3.ZERO:
					lines.append([from, agent.last_known_target_pos + Vector3.UP * 1.0, Color(1.0, 0.6, 0.2, 0.35)])

	for squad in _us_squads:
		for agent in squad:
			if not is_instance_valid(agent):
				continue
			var lbl := _dbg_label_for(agent)
			if agent.is_dead():
				lbl.text = "KIA"
				lbl.modulate = Color(0.5, 0.5, 0.5, 0.5)
				continue
			var state_name: String = Enums.AIState.keys()[int(agent.current_state)]
			var order_name: String = AllyBase.OrderMode.keys()[int(agent.order_mode)]
			lbl.text = "%s\n%s | cov:%s sup:%.1f" % [state_name, order_name, "Y" if agent.has_cover else "n", agent.suppression_level]
			lbl.modulate = Color(0.45, 0.75, 1.0)
			if agent.target != null and is_instance_valid(agent.target) and agent.has_line_of_sight:
				lines.append([agent.global_position + Vector3.UP * 1.5,
					agent.target.global_position + Vector3.UP * 1.0, Color(0.3, 0.7, 1.0, 0.75)])

	if lines.is_empty():
		return
	_dbg_im.surface_begin(Mesh.PRIMITIVE_LINES)
	for ln in lines:
		_dbg_im.surface_set_color(ln[2])
		_dbg_im.surface_add_vertex(ln[0])
		_dbg_im.surface_set_color(ln[2])
		_dbg_im.surface_add_vertex(ln[1])
	_dbg_im.surface_end()
