## zombie_wave_director.gd - the round clock for VC Zombies.
##
## WHY THIS IS NOT SiegeDirector. The siege already runs chained survival waves
## (ai_stress_arena.gd:88-89) and its spawn-ring / deferred-materialize / live-cap
## hold-and-thaw pattern is exactly right for a horde - that pattern is borrowed
## here wholesale. Its CODE is not, because it spawns nothing itself: every body
## goes through FieldDirector.spawn_tracked_enemy via a MarchingCell carrying an
## EnemyData, and it reads CampaignState for the night roll. Reusing the class
## would drag the campaign's whole spawn authority into a game mode that has no
## campaign. The ideas are free; the wiring was never going to be.
##
## WHAT IS DELIBERATELY ABSENT, and each is a thing SiegeDirector does:
##   * no break. BREAK_BASE_RATIO routs an assault at ~42.5% killed. The dead do
##     not rout, so a round ends only when the last one is down.
##   * no reap. Withdrawing survivors are despawned there; here nothing withdraws.
##   * no mortars, no illum, no press rotation, no squads.
class_name ZombieWaveDirector
extends Node

signal round_began(round_number: int, strength: int)
signal round_cleared(round_number: int)
signal zombie_spawned(zombie: ZombieBase)
signal wave_count_changed(alive: int, left_to_spawn: int)

## Simultaneous LIVE bodies. The siege caps at 50 men; zombies are cheaper per
## body (no cover scoring, no LOS, no suppression) but there are more of them, so
## the ceiling stays here rather than being raised on a hunch. Measure before
## moving it.
const LIVE_CAP: int = 42
const SPAWN_INTERVAL: float = 0.55
const ROUND_BREATHER_S: float = 9.0

## Round 1 is six shamblers so the first minute teaches the loop. Growth is linear
## while it is still readable, then the cap does the work - past ~30 the pressure
## comes from HP and speed, not from more bodies the frame budget cannot draw.
const BASE_COUNT: int = 6
const COUNT_PER_ROUND: int = 3
const MAX_COUNT: int = 90

const BASE_HP: int = 130
const HP_PER_ROUND: int = 45
## Past this round HP compounds instead of stepping, so the curve keeps biting
## without the early rounds becoming bullet sponges.
const HP_SOFT_CAP_ROUND: int = 10
const HP_COMPOUND: float = 1.09

## They are SLOW. That is the ruling and it is the whole feel - the threat is the
## mass and the geometry, never the footspeed. The player walks faster than this.
const WALKER_SPEED: Vector2 = Vector2(0.95, 1.30)
const RUNNER_SPEED: Vector2 = Vector2(2.60, 3.20)
## Runners do not exist until the player has learned the shamble.
const RUNNER_FIRST_ROUND: int = 6
const RUNNER_SHARE_MAX: float = 0.35
## The rotted are the heavies: the advanced-decay bodies, slower still, more HP.
const ROTTED_FIRST_ROUND: int = 4
const ROTTED_SHARE_MAX: float = 0.30

var round_number: int = 0
var active: bool = false
var alive: Array[ZombieBase] = []

var _to_spawn: int = 0
var _spawn_t: float = 0.0
var _breather: float = 0.0
var _rng := RandomNumberGenerator.new()
var _spawn_points: Array[Node3D] = []
var _host: Node = null


func setup(host: Node, seed_value: int = 20260805) -> void:
	_host = host
	_rng.seed = seed_value


func _physics_process(delta: float) -> void:
	if not active:
		return
	_prune()
	if _to_spawn > 0:
		_spawn_t -= delta
		if _spawn_t <= 0.0 and alive.size() < LIVE_CAP:
			_spawn_t = SPAWN_INTERVAL
			_spawn_one()
		return
	if not alive.is_empty():
		return
	# Round cleared. The breather is the only quiet in the mode - it is where the
	# player spends, rebuilds, and decides.
	_breather -= delta
	if _breather <= 0.0:
		start_round(round_number + 1)


func begin() -> void:
	active = true
	start_round(1)


func stop() -> void:
	active = false


func start_round(n: int) -> void:
	round_number = n
	_to_spawn = strength_for(n)
	_spawn_t = 0.0
	_breather = ROUND_BREATHER_S
	if n > 1:
		round_cleared.emit(n - 1)
	round_began.emit(n, _to_spawn)
	wave_count_changed.emit(alive.size(), _to_spawn)


## How many of this round are still queued to stand up.
func left_to_spawn() -> int:
	return _to_spawn


static func strength_for(n: int) -> int:
	return mini(MAX_COUNT, BASE_COUNT + COUNT_PER_ROUND * maxi(0, n - 1))


static func hp_for(n: int) -> int:
	if n <= HP_SOFT_CAP_ROUND:
		return BASE_HP + HP_PER_ROUND * (n - 1)
	var hp: float = float(BASE_HP + HP_PER_ROUND * (HP_SOFT_CAP_ROUND - 1))
	return int(hp * pow(HP_COMPOUND, float(n - HP_SOFT_CAP_ROUND)))


## Spawn points are discovered from the scene, and only OPEN zones may spawn.
## A zone behind a door the player has not bought must stay silent, or the horde
## arrives from a room he has never seen.
func _refresh_spawn_points() -> void:
	_spawn_points.clear()
	for n in get_tree().get_nodes_in_group("zombie_spawns"):
		var s := n as Node3D
		if s == null or not is_instance_valid(s):
			continue
		if s.has_method("is_active") and not bool(s.call("is_active")):
			continue
		_spawn_points.append(s)


func _spawn_one() -> void:
	_refresh_spawn_points()
	if _spawn_points.is_empty():
		# Loud, because a silent no-op here reads to the player as "the round is
		# bugged" and to the developer as "the director stopped".
		push_warning("[ZWAVE] no active spawn point - round %d cannot fill" % round_number)
		return
	var point: Node3D = _spawn_points[_rng.randi() % _spawn_points.size()]
	var prof: Dictionary = _profile_for_round()
	# Drawn from the wave rng, not from randi() inside the zombie, so a seeded
	# round rebuilds the identical crowd down to which idle each man loops.
	prof["variant_roll"] = _rng.randi()
	var tier: String = String(prof["body_tier"])

	var made: Dictionary = ZombieRandomizer.spawn(_host, _rng, tier)
	if made.is_empty():
		return
	var actor: ModelActor = made["actor"]

	var z := ZombieBase.new()
	_host.add_child(z)
	actor.reparent(z)
	actor.position = Vector3.ZERO
	z.global_position = point.global_position
	z.setup(actor, prof, round_number)
	z.died.connect(_on_zombie_died)

	alive.append(z)
	_to_spawn -= 1
	zombie_spawned.emit(z)
	wave_count_changed.emit(alive.size(), _to_spawn)


## One zombie's numbers, rolled against the round's mix.
func _profile_for_round() -> Dictionary:
	var n: int = round_number
	var hp: int = hp_for(n)

	var runner_share: float = 0.0
	if n >= RUNNER_FIRST_ROUND:
		runner_share = minf(RUNNER_SHARE_MAX, 0.06 * float(n - RUNNER_FIRST_ROUND + 1))
	var rotted_share: float = 0.0
	if n >= ROTTED_FIRST_ROUND:
		rotted_share = minf(ROTTED_SHARE_MAX, 0.05 * float(n - ROTTED_FIRST_ROUND + 1))

	var roll: float = _rng.randf()
	if roll < runner_share:
		return {
			"speed": _rng.randf_range(RUNNER_SPEED.x, RUNNER_SPEED.y),
			"hp": int(hp * 0.75), "damage": 20, "attack_range": 1.7,
			"attack_cd": 0.9, "gait": "run", "body_tier": "walker",
			"points_kill": 90, "points_hit": 10,
		}
	if roll < runner_share + rotted_share:
		return {
			"speed": _rng.randf_range(WALKER_SPEED.x * 0.75, WALKER_SPEED.y * 0.8),
			"hp": int(hp * 1.9), "damage": 34, "attack_range": 1.8,
			"attack_cd": 1.5, "gait": "walk", "body_tier": "rotted",
			"points_kill": 130, "points_hit": 10,
		}
	return {
		"speed": _rng.randf_range(WALKER_SPEED.x, WALKER_SPEED.y),
		"hp": hp, "damage": 22, "attack_range": 1.7,
		"attack_cd": 1.2, "gait": "walk", "body_tier": "walker",
		"points_kill": 60, "points_hit": 10,
	}


func _on_zombie_died(z: ZombieBase) -> void:
	alive.erase(z)
	wave_count_changed.emit(alive.size(), _to_spawn)


## Bodies freed by something other than their own death - a despawn, a scene
## change - must leave the ledger or the round can never clear.
func _prune() -> void:
	var before: int = alive.size()
	var keep: Array[ZombieBase] = []
	for z in alive:
		if is_instance_valid(z) and not z.is_dead():
			keep.append(z)
	if keep.size() != before:
		alive = keep
		wave_count_changed.emit(alive.size(), _to_spawn)
