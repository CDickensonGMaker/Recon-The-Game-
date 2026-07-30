## siege_director.gd - The night assault on the firebase (ADR-035). Owns cadence,
## the assault's strength ledger, the attack sector, the ranging mortars, the break
## and THE REAP. It spawns nothing itself: every body comes from
## FieldDirector.spawn_tracked_enemy through a MarchingCell, so the single spawn
## authority is untouched.
class_name SiegeDirector
extends Node

## Per-night probability by the threat tier the player earned. Named as a constant
## because a rate that is not written down ships as whatever number gets typed
## first - the deleted SAPPER_CHANCE is what this replaces.
const NIGHT_CHANCE: Dictionary = {"LOW": 0.05, "MODERATE": 0.15, "HIGH": 0.30, "CRITICAL": 0.45}
const MAX_RUN_NIGHTS: int = 3

## A roll of 1-11 is a PROBE, not a siege: 2d6 sappers can exceed a low d50, and a
## three-man "siege" reads as a broken feature rather than a quiet night.
const PROBE_MAX: int = 11

const SECTOR_DEG: float = 60.0
const RING_MIN: float = 300.0
const RING_MAX: float = 500.0
const CELL_MIN: int = 3
const CELL_MAX: int = 6
const SAPPER_DATA: String = "res://data/enemies/vc_sapper.tres"
const REGULAR_DATA: String = "res://data/enemies/nva_regular.tres"

## The assault breaks at 42.5% killed - inside the decreed 40-50% band. Passed as
## break_state's base_ratio: reaching it through the courage term instead would
## make every besieger individually cowardly (ADR-035 §4).
const BREAK_BASE_RATIO: float = 0.575

## Simultaneous MATERIALIZED men. The cells defer body cost, they do not delete it -
## one axis onto one objective means every cell crosses the ring inside a minute.
## Set to the d50 ceiling by the Summoner's ruling 2026-07-28: a capped assault
## trickles in and never reads as the mass attack the roll describes.
const LIVE_CAP: int = 50

## A siege is decided inside the night (600 real seconds, sim_clock.gd:17) and must
## be triggered early enough in NIGHT that this fits before dawn.
const MAX_DURATION_S: float = 480.0

const RALLY_M: float = 350.0
const REAP_RADIUS_M: float = 600.0
const REAP_TIMEOUT_S: float = 90.0

const MORTAR_SHELL: String = "res://data/projectiles/mortar_81mm.tres"
const MORTAR_DISPERSION_START: float = 50.0
const MORTAR_DISPERSION_END: float = 12.0
const MORTAR_WALK_S: float = 180.0
const MORTAR_VOLLEY: int = 3
const MORTAR_TUBE_STANDOFF: float = 700.0
const MORTAR_DAMAGE: int = 140
const MORTAR_MIN_DAMAGE: int = 40
const MORTAR_BLAST_M: float = 18.0

signal siege_began(strength: int, is_probe: bool)
signal siege_ended(reason: String, killed: int, strength: int)

var director: FieldDirector = null
var fsb_center: Vector3 = Vector3.ZERO
var objective: Vector3 = Vector3.ZERO

var active: bool = false
var is_probe: bool = false
var sector_bearing: float = 0.0
var cells: Array[MarchingCell] = []

## Assault geometry in metres. The constants above are authored for a kilometres-wide
## AO; a 200 m test chamber would spawn every cell outside its own walls, so a host
## with a smaller map overrides these after setup(). Distances only - the roll, the
## cell sizes and the break ratio are NOT tunable from outside.
var ring_min: float = RING_MIN
var ring_max: float = RING_MAX
var rally_m: float = RALLY_M
var mortar_standoff_m: float = MORTAR_TUBE_STANDOFF
var cell_materialize_m: float = MarchingCell.MATERIALIZE_M

## THE LEDGER. peak is fixed when the run is rolled, never observed - EnemySquad's
## own _strength counts nodes in the `enemies` group, and a dormant cell has none,
## so its ratio would be replenished by every arriving cell and the break would
## never fire (ADR-035 §4).
var run_strength: int = 0        ## d50, rolled ONCE PER RUN
var run_peak: int = 0
var nights_run: int = 0
var _rolled_this_night: bool = false
var _elapsed: float = 0.0
var _mortar_timer: float = 0.0
var _reaping: Array[EnemyBase] = []
var _reap_clock: Dictionary = {}   ## instance_id -> seconds under withdrawal
var _rng := RandomNumberGenerator.new()
var _poll: float = 0.0
var _last_sim_day: int = -1


func setup(field_director: FieldDirector, center: Vector3, aim: Vector3) -> void:
	director = field_director
	fsb_center = center
	objective = aim if aim != Vector3.ZERO else center
	_rng.seed = hash(Vector2i(int(center.x), int(center.z))) ^ 0x51E6E
	sector_bearing = _rng.randf_range(0.0, TAU)


func _physics_process(delta: float) -> void:
	_poll += delta
	if _poll < 0.5:
		return
	var step: float = _poll
	_poll = 0.0
	_process_reap(step)
	if active:
		_run_siege(step)
	else:
		_maybe_open(step)


## ---------- CADENCE ----------

func _maybe_open(_step: float) -> void:
	if director == null or fsb_center == Vector3.ZERO:
		return
	var day: int = _sim_day()
	if day != _last_sim_day:
		_last_sim_day = day
		_rolled_this_night = false
	if not MissionWeather.is_night:
		# Dawn closes the run's window: a night that never opened breaks the chain.
		if _rolled_this_night and not active:
			nights_run = 0
		_rolled_this_night = false
		return
	if _rolled_this_night or nights_run >= MAX_RUN_NIGHTS:
		return
	if director.patrol_count < 1:
		return
	_rolled_this_night = true
	var chance: float = float(NIGHT_CHANCE.get(CampaignState.threat_label(), 0.0))
	if _rng.randf() < chance:
		open_siege()


## Public so a probe drives the assault without fighting the RNG gate.
func open_siege(forced_strength: int = 0) -> void:
	if active or director == null or fsb_center == Vector3.ZERO:
		return
	if run_strength <= 0 or nights_run == 0:
		# d50 is rolled ONCE PER RUN. Nights 2-3 come with the survivors the reap
		# collected, so breaking them on night 1 can end the run outright.
		run_strength = forced_strength if forced_strength > 0 else _rng.randi_range(1, 50)
		run_peak = run_strength
	elif forced_strength > 0:
		run_strength = forced_strength
	if run_strength <= 0:
		nights_run = 0
		return
	active = true
	nights_run += 1
	is_probe = run_strength <= PROBE_MAX
	_elapsed = 0.0
	_mortar_timer = 0.0
	# Nights 2 and 3 attack where the last night worked.
	if nights_run == 1:
		sector_bearing = _rng.randf_range(0.0, TAU)
	_build_cells()
	siege_began.emit(run_strength, is_probe)


## Sappers are 2d6 of the strength, clamped so a probe cannot field more sappers
## than it has men. Cells are homogeneous: while dormant a cell holds ONE EnemyData
## reference rather than six.
func _build_cells() -> void:
	var sappers: int = mini(_rng.randi_range(1, 6) + _rng.randi_range(1, 6), run_strength)
	var regulars: int = run_strength - sappers
	_spawn_cells_for(sappers, SAPPER_DATA, "siege_sappers", true)
	_spawn_cells_for(regulars, REGULAR_DATA, "siege_assault", false)


func _spawn_cells_for(count: int, data: String, tag: String, charges: bool) -> void:
	var remaining: int = count
	while remaining > 0:
		var size: int = mini(remaining, _rng.randi_range(CELL_MIN, CELL_MAX))
		if remaining - size > 0 and remaining - size < CELL_MIN:
			size = remaining
		remaining -= size
		var half: float = deg_to_rad(SECTOR_DEG) * 0.5
		var a: float = sector_bearing + _rng.randf_range(-half, half)
		var r: float = _rng.randf_range(ring_min, ring_max)
		var at: Vector3 = fsb_center + Vector3(cos(a) * r, 0.0, sin(a) * r)
		var cell := MarchingCell.new()
		cell.carries_charge = charges
		cell.materialize_m = cell_materialize_m
		add_child(cell)
		cell.setup(director, at, objective, size, data, tag, int(_rng.randi()))
		cells.append(cell)


## ---------- THE RUNNING FIGHT ----------

func _run_siege(step: float) -> void:
	_elapsed += step
	_walk_mortars(step)
	_light_check()
	_enforce_live_cap()
	if _elapsed >= MAX_DURATION_S:
		_break_siege("dawn")
		return
	var live: int = live_strength()
	if live <= 0:
		_break_siege("wiped")
		return
	var bs: Dictionary = EnemySquad.break_state(live, run_peak, _avg_courage(), BREAK_BASE_RATIO)
	if bool(bs.broken):
		_break_siege("broken")


func live_strength() -> int:
	var n: int = 0
	for c in cells:
		if is_instance_valid(c):
			n += c.live_strength()
	return n


func killed_count() -> int:
	return maxi(0, run_peak - live_strength())


func _avg_courage() -> float:
	var sum: float = 0.0
	var n: int = 0
	for c in cells:
		if not is_instance_valid(c) or not c.materialized:
			continue
		for m in c.men:
			if is_instance_valid(m) and not m.is_dead() and m.enemy_data != null:
				sum += m.enemy_data.courage
				n += 1
	return sum / float(n) if n > 0 else 0.5


## Light reveals what the dark hid - scoped to the lit circle, so an illum round
## cannot materialize the whole assault at once.
func _light_check() -> void:
	for c in cells:
		if is_instance_valid(c):
			c.materialize_if_lit()


## The cells defer the spike; this bounds it. A deferred cell is logged, never
## silently dropped - a silent cap reads as "we fielded everything" when we did not.
func _enforce_live_cap() -> void:
	var materialized_men: int = 0
	for c in cells:
		if is_instance_valid(c) and c.materialized:
			materialized_men += c.live_strength()
	if materialized_men < LIVE_CAP:
		return
	for c in cells:
		if is_instance_valid(c) and not c.materialized and c.is_physics_processing():
			c.set_physics_process(false)
			print("[Siege] cell of %d held at the ring - live cap %d reached"
				% [c.strength, LIVE_CAP])


## ---------- THE RANGING WALK ----------

func _walk_mortars(step: float) -> void:
	_mortar_timer -= step
	if _mortar_timer > 0.0:
		return
	_mortar_timer = _rng.randf_range(20.0, 25.0)
	var t: float = clampf(_elapsed / MORTAR_WALK_S, 0.0, 1.0)
	fire_mortar_volley(objective, lerpf(MORTAR_DISPERSION_START, MORTAR_DISPERSION_END, t))


## One volley onto `at`, dispersed by `spread` metres. The ranging walk above is the
## campaign caller; a bench calls this directly to put enemy indirect fire on the
## map without opening an assault. Shells fly from the tube on the attack bearing,
## so they arrive from the enemy's side and not out of the defenders' own position.
func fire_mortar_volley(at: Vector3, spread: float) -> void:
	if director == null:
		return
	var tube: Vector3 = fsb_center + Vector3(cos(sector_bearing), 0.0,
		sin(sector_bearing)) * mortar_standoff_m
	# The thump from the tube line, then the whistle over the impact point. The
	# gap between them is the only warning the defenders get, and it is the
	# reason a ranging round is survivable.
	AudioManager.play_mortar_tube(tube)
	AudioManager.play_incoming(at)
	for i in range(MORTAR_VOLLEY):
		var impact: Vector3 = at + Vector3(_rng.randf_range(-spread, spread), 0.0,
			_rng.randf_range(-spread, spread))
		director._fire_shell(MORTAR_SHELL, impact, _mortar_impact, tube)


## The enemy's own ranging rounds must not break the enemy's own siege, and the
## break counts every attacker death - so this shell excludes them explicitly.
func _mortar_impact(pos: Vector3) -> void:
	if director == null or director.world == null or not is_instance_valid(director.world):
		return
	var ground: Vector3 = pos
	var tm: Object = director.world.terrain_manager
	if tm != null:
		ground.y = director.world.terrain_manager.get_height_at(pos)
	GunFX.play_explosion_3d(get_tree().current_scene, ground, "explosion_mortar")
	DamageSystem.apply_damage(ground, DamageSystem.DamageType.MEDIUM_EXPLOSION, 1.0)
	NoiseBus.emit_noise(NoiseBus.NoiseType.EXPLOSION, ground, 1)
	_blast_defenders_only(ground)


func _blast_defenders_only(at: Vector3) -> void:
	var tree: SceneTree = get_tree()
	if tree == null:
		return
	var victims: Array[Node] = []
	victims.append_array(tree.get_nodes_in_group("allies"))
	victims.append_array(tree.get_nodes_in_group("garrison_promoted"))
	victims.append_array(tree.get_nodes_in_group("civilians"))
	if GameManager.player != null and is_instance_valid(GameManager.player):
		victims.append(GameManager.player as Node)
	var seen: Dictionary = {}
	for v in victims:
		if v == null or not is_instance_valid(v) or not (v is Node3D):
			continue
		var id: int = v.get_instance_id()
		if seen.has(id):
			continue
		seen[id] = true
		var d: float = (v as Node3D).global_position.distance_to(at)
		if d > MORTAR_BLAST_M:
			continue
		var falloff: float = 1.0 - clampf(d / MORTAR_BLAST_M, 0.0, 1.0)
		var dmg: int = maxi(MORTAR_MIN_DAMAGE, int(lerpf(float(MORTAR_MIN_DAMAGE),
			float(MORTAR_DAMAGE), falloff)))
		if v.has_method("take_damage"):
			v.call("take_damage", dmg, Enums.DamageType.EXPLOSIVE, null)


## ---------- THE BREAK AND THE REAP ----------

func _break_siege(reason: String) -> void:
	if not active:
		return
	active = false
	var killed: int = killed_count()
	var survivors: int = live_strength()
	var rally: Vector3 = fsb_center + Vector3(cos(sector_bearing), 0.0,
		sin(sector_bearing)) * rally_m
	for c in cells:
		if not is_instance_valid(c):
			continue
		if c.materialized:
			for m in c.withdraw_to(rally):
				_reaping.append(m)
				_reap_clock[m.get_instance_id()] = 0.0
		c.queue_free()
	cells.clear()
	# The run's pool carries: nights 2-3 field the survivors, and a wiped assault
	# ends the run rather than re-rolling a fresh fifty.
	run_strength = survivors
	if survivors <= 0 or reason == "wiped":
		nights_run = MAX_RUN_NIGHTS
	siege_ended.emit(reason, killed, run_peak)


## Withdrawal is a real terminal state, not a bearing. Untouched, EnemyBase flees
## forever with no destination and is never freed - three nights of this leaves the
## AO full of permanent full-cost ghosts.
func _process_reap(step: float) -> void:
	if _reaping.is_empty():
		return
	var still: Array[EnemyBase] = []
	for m in _reaping:
		if not is_instance_valid(m):
			continue
		if m.is_dead():
			continue
		var id: int = m.get_instance_id()
		var t: float = float(_reap_clock.get(id, 0.0)) + step
		_reap_clock[id] = t
		var from_base: float = Vector2(m.global_position.x - fsb_center.x,
			m.global_position.z - fsb_center.z).length()
		var at_rally: bool = m.assault_objective != Vector3.ZERO \
			and m.global_position.distance_to(m.assault_objective) <= 20.0
		if at_rally or from_base >= REAP_RADIUS_M or t >= REAP_TIMEOUT_S:
			_reap_clock.erase(id)
			if director != null:
				director.despawn_tracked_enemy(m)
			else:
				m.despawn()
			continue
		still.append(m)
	_reaping = still


func _sim_day() -> int:
	var clock: Node = get_node_or_null(^"/root/SimClock")
	if clock == null:
		return 1
	return int(clock.sim_day)
