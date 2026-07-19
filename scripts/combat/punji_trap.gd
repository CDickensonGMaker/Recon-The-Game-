## punji_trap.gd - VC concealed spike pit. A US trooper (player or ally) who steps
## into it takes a piercing leg wound. One-shot. Mirrors Claymore's proximity-scan
## pattern (no Area3D) so it reuses the same cheap, layer-free detection style.
##
## The VC laid these, so enemies never trigger them - only the player / allies do.
class_name PunjiTrap
extends Node3D

const MODEL_PATH: String = "res://assets/building models/structures/vc_nva/punji_trap.glb"
const TRIGGER_RANGE: float = 1.4
const DAMAGE: int = 35
## Two rifle rounds, one buckshot pattern, or any blast that reaches it. Stakes and
## a lid - it does not take two magazines to ruin.
const MAX_HP: int = 30
## The zone rides the player's fire mask only (civilian.gd:22 documents the layer),
## so VC rounds cannot clear their own traps.
const TRAP_HURTBOX_LAYER: int = 512

var hp: int = MAX_HP
var _armed: bool = false
var _scan_timer: float = 0.0
var _sprung: bool = false
var _destroyed: bool = false


static func place(parent: Node, terrain: Node, world_pos: Vector3, facing: float = 0.0) -> PunjiTrap:
	var trap := PunjiTrap.new()
	trap.add_to_group("punji_traps")  # the POINT man's detect_ambush scan spots these
	parent.add_child(trap)
	var gy: float = world_pos.y
	if terrain != null and terrain.has_method("get_height_at"):
		gy = terrain.get_height_at(world_pos)
	trap.global_position = Vector3(world_pos.x, gy, world_pos.z)
	trap.rotation.y = facing
	var scene: PackedScene = load(MODEL_PATH)
	if scene:
		trap.add_child(scene.instantiate())
	trap._build_hurtbox()
	AgentRegistry.register(trap, AgentRegistry.Kind.PROP)
	# brief arming delay so it can never spring on the frame it spawns. Timer is a
	# CHILD (dies with the trap) - a scene-timer lambda dangles if the site is torn
	# down inside the window (test_site_stamp caught exactly that).
	var arm_t := Timer.new()
	arm_t.one_shot = true
	arm_t.wait_time = 1.0
	trap.add_child(arm_t)
	arm_t.timeout.connect(func() -> void: trap._armed = true)
	arm_t.start()
	return trap


func _physics_process(delta: float) -> void:
	if not _armed or _sprung:
		return
	_scan_timer += delta
	if _scan_timer < 0.2:
		return
	_scan_timer = 0.0
	var p: Node = GameManager.player
	if p != null and is_instance_valid(p) and p is Node3D \
			and (p as Node3D).global_position.distance_to(global_position) <= TRIGGER_RANGE:
		_spring(p)
		return
	for a in get_tree().get_nodes_in_group("allies"):
		if a is Node3D and (a as Node3D).global_position.distance_to(global_position) <= TRIGGER_RANGE:
			_spring(a)
			return


## One flat zone over the pit mouth. A spike pit has no anatomy, so it takes the
## TORSO multiplier and nothing else - the zone exists to make rounds FIND it,
## because bullet_system resolves damage through Hitzones or nothing.
func _build_hurtbox() -> void:
	var hz := Hitzone.new()
	hz.zone_type = Hitzone.ZoneType.TORSO
	hz.set_owner_entity(self)
	hz.collision_layer = TRAP_HURTBOX_LAYER
	hz.collision_mask = 0
	hz.add_to_group("hitzone")
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.6, 0.5, 1.6)
	shape.shape = box
	shape.position = Vector3(0, 0.25, 0)
	hz.add_child(shape)
	add_child(hz)


## Joins the one damage grammar as a receiver (ADR-003) - same verb every other
## body in the game answers to.
func take_damage(amount: int, _t: int = 0, _attacker: Node = null, _zone: String = "BODY") -> void:
	if _destroyed:
		return
	hp -= amount
	if hp <= 0:
		destroy()


## Cleared. The stakes are pulled and the ground is safe - it can never spring again.
func destroy() -> void:
	if _destroyed:
		return
	_destroyed = true
	_sprung = true
	AgentRegistry.unregister(self)
	GunFX.impact(get_tree().current_scene, global_position + Vector3.UP * 0.2, Vector3.UP, true)
	queue_free()


func is_dead() -> bool:
	return _destroyed


func _spring(victim: Node) -> void:
	_sprung = true
	if victim.has_method("take_damage"):
		victim.take_damage(DAMAGE, Enums.DamageType.PHYSICAL, null)
	if victim.has_method("apply_wound"):
		victim.apply_wound("LIMB_LEG")
	# a stifled cry - draws nearby enemies to the noise (NoiseBus VOICE is an AI event)
	NoiseBus.emit_noise(NoiseBus.NoiseType.VOICE, global_position, 1, 12.0)
