## marching_cell.gd - A fireteam that walks as ONE node and becomes bodies only on
## contact (ADR-035 §2). 3-6 men of a single type.
##
## The measured reason this exists: AI think is ~1.2ms of a 38-40ms wall
## (PERF_LEDGER.md:295-304). The body - move_and_slide, hitzone sync, anim - is the
## other ~94%. A hivemind that shares thinking banks nothing; one that shares BODIES
## banks everything. The pattern is LazyGroup's, kept deliberately: spawns route
## through FieldDirector.spawn_tracked_enemy so the single spawn authority holds.
class_name MarchingCell
extends Node3D

## Metres from the objective at which a dormant cell becomes men. Must clear the
## night sight cap (56m open, from EnemyBase.SIGHT_CAP_OPEN x the 0.4 NIGHT
## darkness multiplier) or the player watches bodies appear out of nothing.
const MATERIALIZE_M: float = 80.0
const MARCH_SPEED: float = 2.2
const NOISE_INTERVAL: float = 6.0
## Cadence of the dormant march. A cell holds no body, so nothing needs a frame.
const STEP_INTERVAL: float = 0.25

var strength: int = 4
var data_path: String = ""
var objective: Vector3 = Vector3.ZERO
var group_tag: String = "siege"
## Sapper cells carry satchels; the assault element does not. Set by the caller so
## this class never has to know which EnemyData means "sapper".
var carries_charge: bool = false
## Overridden by SiegeDirector so a small test chamber does not materialize every
## cell on the frame it spawns.
var materialize_m: float = MATERIALIZE_M
## When set, the materialize ring is measured from HERE instead of the march
## objective (the siege passes fsb_center; the objective is the bench aim inside
## the wire). ZERO = objective-measured, the bench/chamber default.
var materialize_center: Vector3 = Vector3.ZERO
var director: FieldDirector = null
var men: Array[EnemyBase] = []
var materialized: bool = false

var _step_timer: float = 0.0
var _noise_timer: float = 0.0
var _rng := RandomNumberGenerator.new()


func setup(field_director: FieldDirector, at: Vector3, aim: Vector3, count: int,
		data: String, tag: String, rng_seed: int) -> void:
	director = field_director
	global_position = at
	objective = aim
	strength = count
	data_path = data
	group_tag = tag
	_rng.seed = rng_seed
	_noise_timer = _rng.randf_range(0.0, NOISE_INTERVAL)


## Men still in the fight. A DORMANT cell answers with its full paper strength -
## the siege ledger must count men who have not materialized yet, or the break
## ratio is computed against an assault that is still arriving (ADR-035 §2/§4).
## Mid-stagger the unspawned remainder still counts for the same reason.
func live_strength() -> int:
	if not materialized:
		return strength
	var n: int = _spawn_left
	for m in men:
		if is_instance_valid(m) and not m.is_dead():
			n += 1
	return n


func is_spent() -> bool:
	return materialized and live_strength() == 0


func _physics_process(delta: float) -> void:
	if materialized:
		if _spawn_left > 0:
			_spawn_tick()
		else:
			set_physics_process(false)
		return
	_step_timer += delta
	if _step_timer < STEP_INTERVAL:
		return
	var step: float = _step_timer
	_step_timer = 0.0

	_noise_timer -= step
	if _noise_timer <= 0.0:
		_noise_timer = NOISE_INTERVAL
		# Heard before seen. A company crossing the dark is the dread, and with no
		# bodies to make footfalls this is the only thing that carries it.
		NoiseBus.emit_noise(NoiseBus.NoiseType.FOOTSTEP, global_position, 0)

	var to: Vector3 = objective - global_position
	to.y = 0.0
	var d: float = to.length()
	# The pop ring is measured from materialize_center when set (the siege sets
	# fsb_center), NOT from the march objective: the objective is the bench aim
	# ~32m INSIDE the wire, so an objective-measured ring dips inside the
	# compound on anti-gate bearings and bodies appear inside the wire the
	# overrun call cannot see (audit 2026-08-13 D-2).
	if materialize_center != Vector3.ZERO:
		var toc: Vector3 = materialize_center - global_position
		toc.y = 0.0
		d = toc.length()
	if d <= materialize_m:
		materialize()
		return
	global_position += to.normalized() * MARCH_SPEED * step
	_seat_on_terrain()


## Light reveals what the dark was hiding. Scoped to the LIT CIRCLE by the caller,
## never to the whole assault - an illum round must not be a button that
## materializes every cell at once (ADR-035 §2 contract 2).
func materialize_if_lit() -> bool:
	if materialized:
		return false
	if not IllumFlare.is_lit(global_position):
		return false
	materialize()
	return true


## Spawns are STAGGERED against a GLOBAL per-frame budget. A 5-6 man cell
## materializing in one frame measured 267-288ms on the crucible (2026-08-14
## hitch trace: +2,300..+2,900 nodes in the hitch frame - every man is a full
## ModelActor instantiation) and was the game's recurring worst-frame class.
## The budget is SHARED across cells because the center-true pop ring lands
## several cells on the same frame - a per-cell cap alone still burst +1,547
## nodes (measured on the post-fix crucible). The first man of a pop spawns
## inside materialize() so the pop is never an empty frame.
##
## Keyed on the RENDER frame, not the physics frame: a hitching frame runs many
## catch-up physics ticks, and a physics-keyed budget refilled on every one of
## them - 15-24 men in a single 260ms rendered frame while the budget reported
## "as designed" (crucible ledger 2026-08-15). That is a death spiral: the slow
## frame buys itself MORE spawns. This bucket is the game-wide gate; any bulk
## man-spawner (arena waves included) drips through it.
##
## TWO men a frame, measured against 1/frame on back-to-back crucibles
## (2026-08-15): 1/frame doubles the arrival window and made every phase
## average WORSE (FIRES 30->37ms avg, 61->107 hitch lines) while the per-frame
## cost barely moved - the drip frame's floor is combat load + physics
## catch-up, not the second man. Do not "optimise" this to 1 without re-running
## both configs.
const SPAWN_PER_FRAME: int = 2
static var _budget_frame: int = -1
static var _budget_left: int = 0
var _spawn_left: int = 0


static func _take_spawn_token() -> bool:
	var f: int = Engine.get_process_frames()
	if f != _budget_frame:
		_budget_frame = f
		_budget_left = SPAWN_PER_FRAME
	if _budget_left <= 0:
		return false
	_budget_left -= 1
	return true


func materialize() -> void:
	if materialized or director == null:
		return
	materialized = true
	_spawn_left = strength
	# NO first-man exemption: an illum flare materializes every lit cell in the
	# SAME frame (ADR-035 scopes the button to the lit circle, but the circle
	# holds several cells), and five exempt first men re-created the +2,800-node
	# burst the budget exists to kill (measured 2026-08-14). Men arriving over
	# the next 2-3 physics frames is ~50ms - invisible at the pop ring.
	_spawn_tick()


func _spawn_tick() -> void:
	while _spawn_left > 0 and MarchingCell._take_spawn_token():
		_spawn_one()
		_spawn_left -= 1


func _spawn_one() -> void:
	var a: float = _rng.randf_range(0.0, TAU)
	var r: float = _rng.randf_range(1.5, 5.0)
	var pos: Vector3 = global_position + Vector3(cos(a) * r, 0.0, sin(a) * r)
	var man: EnemyBase = director.spawn_tracked_enemy(pos, data_path, group_tag)
	if man == null:
		return
	man.add_to_group(group_tag)
	man.assault_objective = objective
	# Only the satchel man's legs belong to the objective. The assault element marches
	# to it and then fights - see EnemyBase.assault_driven.
	man.assault_driven = carries_charge
	if carries_charge:
		var charge := SapperCharge.new()
		man.add_child(charge)
		charge.setup(objective)
	men.append(man)


## Send every survivor out on the axis he came in on - known-traversable ground,
## because _move_toward only navmeshes inside a shared NavBaker box and a rally
## across open map is straight-line steering.
func withdraw_to(rally: Vector3) -> Array[EnemyBase]:
	# A withdrawing cell stops birthing men - the unspawned stagger remainder
	# would otherwise arrive INTO the retreat.
	_spawn_left = 0
	var leaving: Array[EnemyBase] = []
	for m in men:
		if not is_instance_valid(m) or m.is_dead():
			continue
		# A satchel outlives its carrier's orders: SapperCharge tests its own
		# target_pos, so a withdrawing sapper crossing the old aim point detonates
		# on the way out - and _detonate would clear the objective set below.
		# Disarmed and detached SYNCHRONOUSLY: queue_free is deferred, which leaves
		# the charge one more physics tick to blow.
		var charges: Array[Node] = []
		for c in m.get_children():
			if c is SapperCharge:
				charges.append(c)
		for c in charges:
			(c as SapperCharge).disarm()
			m.remove_child(c)
			c.queue_free()
		# A withdrawal owns the legs the same way the satchel does: a man pulling back does
		# not stop halfway to trade shots because something came into view.
		m.assault_objective = rally
		m.assault_driven = true
		leaving.append(m)
	return leaving


func _seat_on_terrain() -> void:
	if director == null or director.world == null:
		return
	var tm: Object = director.world.terrain_manager
	if tm == null:
		return
	# The march ends ON the firebase, so the cell rides the same surface its men will
	# stand on - terrain height alone walks it into the mound.
	global_position.y = director.world.surface_y(global_position)
