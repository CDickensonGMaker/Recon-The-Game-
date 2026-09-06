## litter_team.gd - two bearers, a casualty and the litter between them.
##
## THE DRIVER OWNS ALL THREE BODIES. `litter_carry_front`/`_rear` are 2.40s and
## `litter_load_front`/`_rear` are 1.07s, matched pairs measured in place off
## anim_library.glb (<=0.012m of hip drift). Nothing in this project phase-locks two
## actors, so the pattern is enemy_base.gd's casualty haul scaled to three: one node
## sets every clip with `restart: true` on the same frame and writes every position.
## Two NavigationAgents will never hold a 1.8m gap and the stretcher would scissor.
##
## The bearers and the casualty are `puppet` Civilians - their BT and their clip
## chain are both suppressed, or the schedule re-issues a pose over the driver and
## the casualty sits up on the stretcher.
class_name LitterTeam
extends Node3D

## The standalone litter prop, exported by tools/gen_fb_interior.py.
## `available()` gates the whole feature on it existing.
const LITTER_PROP: String = "res://assets/us/props/interior/fb_litter.glb"

const BEARER_GAP: float = 1.8      ## metres, front bearer to rear bearer
const LITTER_Y: float = 0.55       ## metres, litter deck above the bearers' feet
const CARRY_SPEED: float = 1.0     ## metres/sec, a loaded litter is a slow walk
const RETURN_SPEED: float = 1.4    ## metres/sec, walking back empty
const LOAD_S: float = 1.07         ## length of litter_load_front / _rear
const WAIT_S: float = 6.0          ## beat at the cot before the next casualty

enum Phase { LOAD, CARRY, UNLOAD, RETURN, WAIT }

var _front: Civilian = null
var _rear: Civilian = null
var _casualty: Civilian = null
var _litter: Node3D = null

var _cot: Vector3 = Vector3.ZERO
var _ward: Vector3 = Vector3.ZERO
var _phase: Phase = Phase.LOAD
var _phase_t: float = 0.0
var _pos: Vector3 = Vector3.ZERO
var _dir: Vector3 = Vector3.FORWARD


## True when the litter prop has been exported. The team is not seeded without it.
static func available() -> bool:
	return ResourceLoader.exists(LITTER_PROP)


## `men` is [front bearer, rear bearer, casualty]. `cot` is where the casualty is
## picked up and `ward` where he is delivered; both are ground positions. The
## caller constructs and parents - a static factory here would self-reference the
## class_name, which does not resolve until the editor rescans a new file.
func setup(world: Node, men: Array[Civilian], cot: Vector3, ward: Vector3) -> bool:
	if men.size() < 3 or not available():
		return false
	name = "LitterTeam"
	_front = men[0]
	_rear = men[1]
	_casualty = men[2]
	_cot = cot
	_ward = ward
	world.add_child(self)
	return true


func _ready() -> void:
	for man in [_front, _rear, _casualty]:
		if man != null and is_instance_valid(man):
			man.puppet = true
	var packed: PackedScene = load(LITTER_PROP) as PackedScene
	if packed != null:
		_litter = packed.instantiate() as Node3D
		if _litter != null:
			add_child(_litter)
	_pos = _cot
	var to_ward: Vector3 = _ward - _cot
	to_ward.y = 0.0
	_dir = to_ward.normalized() if to_ward.length() > 0.1 else Vector3.FORWARD
	_enter(Phase.LOAD)


## Every clip change goes through here so all three bodies land on frame 0 together.
## `restart` is what makes the lock; without it a body already holding the clip keeps
## its own phase and the pair scissors.
func _play(front: String, rear: String, casualty: String) -> void:
	_play_on(_front, front)
	_play_on(_rear, rear)
	_play_on(_casualty, casualty)


func _play_on(man: Civilian, clip: String) -> void:
	if man == null or not is_instance_valid(man):
		return
	var actor := man.actor as ModelActor
	if actor != null:
		actor.play(clip, true)


func _enter(p: Phase) -> void:
	_phase = p
	_phase_t = 0.0
	match p:
		Phase.LOAD, Phase.UNLOAD:
			_play("litter_load_front", "litter_load_rear", "laying_idle")
		Phase.CARRY:
			_play("litter_carry_front", "litter_carry_rear", "laying_idle")
		Phase.RETURN:
			_play("walk_forward", "walk_forward", "laying_idle")
		Phase.WAIT:
			_play("kneeling_idle", "idle_unarmed_3", "laying_idle")
	# The casualty and the litter ride the walk out and sit at the cot between runs;
	# neither belongs in the empty return leg.
	var loaded: bool = p != Phase.RETURN
	if _casualty != null and is_instance_valid(_casualty):
		_casualty.visible = loaded
	if _litter != null:
		_litter.visible = loaded


func _physics_process(delta: float) -> void:
	if _front == null or not is_instance_valid(_front):
		queue_free()
		return
	_phase_t += delta
	match _phase:
		Phase.LOAD:
			if _phase_t >= LOAD_S:
				_face(_ward)
				_enter(Phase.CARRY)
		Phase.CARRY:
			if _advance(_ward, CARRY_SPEED, delta):
				_enter(Phase.UNLOAD)
		Phase.UNLOAD:
			if _phase_t >= LOAD_S:
				_face(_cot)
				_enter(Phase.RETURN)
		Phase.RETURN:
			if _advance(_cot, RETURN_SPEED, delta):
				_face(_ward)
				_enter(Phase.WAIT)
		Phase.WAIT:
			if _phase_t >= WAIT_S:
				_enter(Phase.LOAD)
	_write_bodies()


func _face(at: Vector3) -> void:
	var to: Vector3 = at - _pos
	to.y = 0.0
	if to.length() > 0.1:
		_dir = to.normalized()


## Step the team toward `dest`. Returns true on arrival.
func _advance(dest: Vector3, speed: float, delta: float) -> bool:
	var to: Vector3 = dest - _pos
	to.y = 0.0
	var d: float = to.length()
	if d <= 0.25:
		return true
	_dir = to / d
	_pos += _dir * minf(speed * delta, d)
	return false


## The three bodies and the prop are written from ONE position and ONE facing, so
## the formation cannot drift. Ground height comes from the front bearer's own
## floor so the team walks the mound, not the terrain under it - and not the roof
## over it, which is what surface_y's top-down ray returned.
func _write_bodies() -> void:
	var yaw: float = atan2(_dir.x, _dir.z)
	var ground: Vector3 = _pos
	var world := get_parent() as GameWorld
	if world != null:
		ground.y = world.floor_y(_pos)
	_seat(_front, ground, yaw)
	_seat(_rear, ground - _dir * BEARER_GAP, yaw)
	var deck: Vector3 = ground - _dir * (BEARER_GAP * 0.5)
	deck.y += LITTER_Y
	_seat(_casualty, deck, yaw)
	if _litter != null:
		_litter.global_position = deck
		_litter.global_rotation.y = yaw


func _seat(man: Civilian, pos: Vector3, yaw: float) -> void:
	if man == null or not is_instance_valid(man):
		return
	man.global_position = pos
	man.velocity = Vector3.ZERO
	var actor := man.actor as ModelActor
	if actor != null:
		actor.global_rotation.y = yaw
