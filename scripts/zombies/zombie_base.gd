## zombie_base.gd - the undead actor for VC Zombies.
##
## WRITTEN FRESH, NOT EXTENDED FROM EnemyBase, and that is the whole design note.
## EnemyBase is a goal-driven soldier: it scores ENGAGE against SEEK_COVER and
## FLANK, tracks suppression, weighs force ratio and routs at a break threshold.
## A zombie wants NONE of that. Subclassing it would mean disabling nine systems
## and inheriting their per-frame cost on every one of fifty bodies.
##
## What is inherited instead is the CHARACTER contract, which is where the value
## actually is: ModelActor for visuals, HitzoneBuilder for zones, GibSystem for
## dismemberment. Those are shared verbatim, so a zombie comes apart exactly like
## a man because it IS the same body (tools/make_zombies.py clones us_base_v3).
##
## THEY ALWAYS KNOW WHERE YOU ARE. No LOS test, no perception, no awareness ramp.
## That is the genre, and it is also what keeps the think loop cheap enough to run
## fifty of them: a zombie's whole brain is "path at the player, swing when close,
## tear the boards when something is in the way".
class_name ZombieBase
extends CharacterBody3D

signal died(zombie: ZombieBase)

## Think rate. Soldiers run 6.7 Hz (THINK_INTERVAL 0.15); a zombie re-deciding
## more than four times a second is spending CPU to reach the same conclusion.
const THINK_INTERVAL: float = 0.25
const GRAVITY: float = 24.0

## Clip preference, most-wanted first. play_first() takes the first that EXISTS,
## so the Mixamo zombie clips take over the moment they land in the shared library
## and the fallbacks stop being reached - with no edit here.
const ANIM_WALK: Array[String] = ["zombie_walk", "walking_unarmed", "walk_forward"]
const ANIM_RUN: Array[String] = ["zombie_run", "running_unarmed", "run_forward"]
const ANIM_CRAWL: Array[String] = ["zombie_crawl", "wounded_crawl"]
const ANIM_ATTACK: Array[String] = ["zombie_attack", "zombie_punching", "grenade_throw"]
const ANIM_TEAR: Array[String] = ["zombie_scratch_idle", "zombie_attack", "digging"]
const ANIM_FLINCH: Array[String] = ["zombie_reaction_hit", "zombie_stumbling", "stumble_hit"]

## Five idles and three rises are in the shared library, and the whole reason to
## have pulled them is that a crowd all playing loop 0 in lockstep is the single
## clearest tell that they came out of a spawner. One is dealt per zombie at setup.
const IDLE_POOL: Array[String] = [
	"zombie_idle", "zombie_idle_b", "zombie_idle_c", "zombie_idle_d", "zombie_idle_e",
]
const RISE_POOL: Array[String] = [
	"zombie_stand_up", "zombie_stand_up_b", "zombie_stand_up_c",
]

## This man's dealt idle, then the fallbacks for a library that predates the pull.
var _idle_clips: Array[String] = ["zombie_idle", "idle_unarmed", "idle"]
var _rise_clip: String = "zombie_stand_up"

## The profile the wave director deals. Kept a plain Dictionary rather than a
## Resource so a round can scale HP without authoring 40 .tres files.
var profile: Dictionary = {
	"speed": 1.15,          ## m/s. A walker is SLOWER than the player's walk.
	"hp": 120,
	"damage": 22,
	"attack_range": 1.7,
	"attack_cd": 1.2,
	"gait": "walk",         ## walk | run | crawl
	"points_kill": 60,
	"points_hit": 10,
}

var health: int = 120
var target: Node3D = null
var round_number: int = 1

var _dead: bool = false
var _think_t: float = 0.0
var _attack_cd: float = 0.0
var _actor: ModelActor = null
var _hitzone_sync: Array = []
var _nav: NavigationAgent3D = null
var _blocker: Node3D = null          ## the barricade in the way, if any
var _removed: Array = []
var _last_hit_dir: Vector3 = Vector3.FORWARD
var _gait_playing: String = ""


func setup(actor: ModelActor, prof: Dictionary, rnd: int = 1) -> void:
	_actor = actor
	round_number = rnd
	for k in prof:
		profile[k] = prof[k]
	health = int(profile["hp"])
	# Dealt from the wave's rng where one is passed, so a seeded round rebuilds the
	# same crowd (ADR-010); a bench spawning one by hand still gets variety.
	var pick: int = int(prof.get("variant_roll", randi()))
	_idle_clips = [IDLE_POOL[pick % IDLE_POOL.size()], "idle_unarmed", "idle"]
	_rise_clip = RISE_POOL[pick % RISE_POOL.size()]


func _ready() -> void:
	add_to_group("zombies")
	# THE ENEMY LAYERS, THE ENEMY GROUP AND THE ENEMY ROSTER, all on purpose: every
	# weapon, explosion and hitzone query in the game already targets those. Being
	# only a "zombie" made the horde invisible to two whole damage paths - blast
	# damage walks AgentRegistry.enemies (combat_manager.gd:191), and claymores and
	# melee walk the group - so the RPG on the wall did nothing to it. Nothing in
	# the campaign sees this: zombies exist only inside this mode's own scene.
	add_to_group("enemies")
	AgentRegistry.register(self, AgentRegistry.Kind.ENEMY)
	collision_layer = 4
	collision_mask = 1
	_build_body_shape()
	_nav = get_node_or_null("NavigationAgent3D")
	if _nav == null:
		_nav = NavigationAgent3D.new()
		_nav.name = "NavigationAgent3D"
		_nav.radius = 0.35
		_nav.path_desired_distance = 0.6
		_nav.target_desired_distance = float(profile["attack_range"]) * 0.8
		_nav.avoidance_enabled = false   # 50 avoidance agents is the frame budget
		add_child(_nav)
	if _actor != null:
		_hitzone_sync = HitzoneBuilder.build(self, _actor, 64, 8, ["hitzone"], true)


## The body a zombie stands on the ground with.
##
## A CharacterBody3D with no shape does not fall over - it falls THROUGH, forever,
## and every other signal reads healthy while it does: the round fills, the count
## is right, the audit passes, and the horde is 400 m below the map. The hitzones
## HitzoneBuilder hangs off the skeleton are Areas and collide with nothing.
func _build_body_shape() -> void:
	for c in get_children():
		if c is CollisionShape3D:
			return
	var cs := CollisionShape3D.new()
	cs.name = "Body"
	var cap := CapsuleShape3D.new()
	# The cast is 1.674 m tall; the capsule sits on the floor, not through it.
	cap.height = 1.7
	cap.radius = 0.35
	cs.shape = cap
	cs.position = Vector3(0.0, 0.85, 0.0)
	add_child(cs)


func _physics_process(delta: float) -> void:
	if _dead:
		return
	var capped: float = minf(delta, 0.066)
	_attack_cd = maxf(0.0, _attack_cd - capped)
	_think_t += capped
	if _think_t >= THINK_INTERVAL:
		_think_t = 0.0
		_think()
	_execute(capped)
	if _actor != null and not _hitzone_sync.is_empty():
		HitzoneBuilder.sync(_actor, _hitzone_sync)


## Pick a target and a path. That is the entire brain.
func _think() -> void:
	if target == null or not is_instance_valid(target):
		target = _nearest_player()
	if target == null:
		return
	_blocker = _barricade_in_the_way()
	if _nav != null:
		_nav.target_position = target.global_position


func _execute(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= GRAVITY * delta

	# A barricade between them and the player is chewed through, not walked round.
	# The board IS the pacing mechanism - see ZombieBarricade.
	if _blocker != null and is_instance_valid(_blocker):
		var to_block: float = global_position.distance_to(_blocker.global_position)
		if to_block <= float(profile["attack_range"]) + 0.4:
			velocity.x = 0.0
			velocity.z = 0.0
			move_and_slide()
			_face(_blocker.global_position)
			_tear(_blocker)
			return

	if target == null or not is_instance_valid(target):
		_play_gait(_idle_clips, "idle")
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		return

	var dist: float = global_position.distance_to(target.global_position)
	if dist <= float(profile["attack_range"]):
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		_face(target.global_position)
		_swing()
		return

	var to: Vector3 = _step_direction()
	velocity.x = to.x * float(profile["speed"])
	velocity.z = to.z * float(profile["speed"])
	move_and_slide()
	_face(global_position + to)
	match String(profile["gait"]):
		"run": _play_gait(ANIM_RUN, "run")
		"crawl": _play_gait(ANIM_CRAWL, "crawl")
		_: _play_gait(ANIM_WALK, "walk")


## Navmesh first, straight line as the fallback. A zombie that stops because the
## nav map has not finished baking reads as a broken spawn, and on a wave map that
## is every zombie for the first two seconds.
func _step_direction() -> Vector3:
	if _nav != null and _nav.is_target_reachable() and not _nav.is_navigation_finished():
		var nxt: Vector3 = _nav.get_next_path_position()
		var d: Vector3 = nxt - global_position
		d.y = 0.0
		if d.length() > 0.05:
			return d.normalized()
	var straight: Vector3 = target.global_position - global_position
	straight.y = 0.0
	return straight.normalized() if straight.length() > 0.05 else Vector3.ZERO


func _swing() -> void:
	if _attack_cd > 0.0:
		return
	_attack_cd = float(profile["attack_cd"])
	if _actor != null:
		_actor.play_first(ANIM_ATTACK, true)
		_gait_playing = ""
	if target != null and is_instance_valid(target) and target.has_method("take_damage"):
		target.call("take_damage", int(profile["damage"]),
			Enums.DamageType.PHYSICAL, self)


func _tear(board: Node3D) -> void:
	if _attack_cd > 0.0:
		return
	_attack_cd = float(profile["attack_cd"])
	if _actor != null:
		_actor.play_first(ANIM_TEAR, true)
		_gait_playing = ""
	if board.has_method("tear"):
		board.call("tear", 1, self)


## The nearest barricade that still stands between this zombie and its target.
## Cheap because the group is small (one entry point per opening, not per plank).
func _barricade_in_the_way() -> Node3D:
	if target == null:
		return null
	var best: Node3D = null
	var best_d: float = 1e9
	for n in get_tree().get_nodes_in_group("zombie_barricades"):
		var b := n as Node3D
		if b == null or not is_instance_valid(b):
			continue
		if b.has_method("is_open") and bool(b.call("is_open")):
			continue
		var d: float = global_position.distance_to(b.global_position)
		# Only a board this zombie is actually walking into counts. Without the
		# approach test every zombie in the map picks the same nearest board and
		# the horde converges on one window.
		if d > 6.0 or d >= best_d:
			continue
		var to_board: Vector3 = (b.global_position - global_position).normalized()
		var to_target: Vector3 = (target.global_position - global_position).normalized()
		if to_board.dot(to_target) < 0.30:
			continue
		best = b
		best_d = d
	return best


func _nearest_player() -> Node3D:
	var p: Node = GameManager.player
	if p != null and is_instance_valid(p) and p is Node3D:
		return p as Node3D
	return null


func _face(at: Vector3) -> void:
	var d: Vector3 = at - global_position
	d.y = 0.0
	if d.length() < 0.01:
		return
	if _actor != null:
		_actor.set_facing(d.normalized())


## Restart-free gait switching: play_first() re-triggering every frame would hold
## the clip on frame 0 and the horde would moonwalk.
func _play_gait(clips: Array[String], key: String) -> void:
	if _gait_playing == key or _actor == null:
		return
	_gait_playing = key
	_actor.play_first(clips, true)


## THE SAME DAMAGE CONTRACT EVERY OTHER BODY IN THIS GAME USES.
##
## `amount` arrives ALREADY multiplied by the struck zone - the shooter does that
## (weapon_holder.gd:666, bullet_system.gd:165) - and `zone` is one of the four
## law names HEAD/BODY/GUT/LIMB. Multiplying again here is how a zombie ended up
## taking a different number from a man for the identical shot.
func take_damage(amount: int, _damage_type: Enums.DamageType = Enums.DamageType.PHYSICAL,
		attacker: Node = null, zone: String = "BODY") -> int:
	if _dead:
		return 0
	if attacker != null and attacker is Node3D:
		_last_hit_dir = (global_position - (attacker as Node3D).global_position).normalized()

	# One bullet of any kind pops a head, at any range, in any round. The fatal
	# authority is shared with soldiers (Hitzone.zone_name_is_fatal); what is
	# zombie-only is that the burst is GUARANTEED, where a man rolls 0.25 for it.
	if Hitzone.zone_name_is_fatal(zone):
		amount = health + 999

	health -= amount
	ZombieEconomy.award_hit(attacker, int(profile["points_hit"]))
	if health <= 0:
		_die(zone, attacker)
	elif _actor != null:
		_actor.play_first(ANIM_FLINCH, true)
		_gait_playing = ""
	return amount


## The region-resolved gore channel, mirroring EnemyBase.on_zone_hit.
##
## Limb dismemberment CANNOT key on the zone string: the four-name law only ever
## says "LIMB", and the GIB map speaks ARM_L/ARM_R/LEG_L/LEG_R. The old code
## passed "LIMB" straight to GibSystem, so no zombie ever lost an arm while every
## soldier did.
func on_zone_hit(region: String, amount: int, dir: Vector3) -> void:
	if _actor == null:
		return
	var limb: String = HitzoneBuilder.base_region(region)
	if limb in ["ARM_L", "ARM_R", "LEG_L", "LEG_R"] \
			and amount >= GibSystem.LIMB_POP_HIT and not _removed.has(limb):
		if GibSystem.dismember(_actor, limb, dir, get_tree().current_scene):
			_removed.append(limb)


func _die(zone: String, attacker: Node) -> void:
	if _dead:
		return
	_dead = true
	set_physics_process(false)
	AgentRegistry.unregister(self)
	collision_layer = 0
	collision_mask = 0
	ZombieEconomy.award_kill(attacker, int(profile["points_kill"]), zone == "HEAD")

	if _actor != null:
		var burst: bool = false
		if zone == "HEAD":
			burst = GibSystem.dismember_head_burst(_actor, _last_hit_dir,
				get_tree().current_scene)
			if not burst:
				burst = GibSystem.dismember(_actor, "HEAD", _last_hit_dir,
					get_tree().current_scene)
		if not burst:
			_actor.play_any_death()
	died.emit(self)


## A body freed without dying - a despawn, a scene teardown - must leave the
## roster too, or the next round's explosions walk freed nodes.
func _exit_tree() -> void:
	AgentRegistry.unregister(self)


func is_dead() -> bool:
	return _dead


func despawn() -> void:
	queue_free()
