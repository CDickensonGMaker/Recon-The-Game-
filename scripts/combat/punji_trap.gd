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

var _armed: bool = false
var _scan_timer: float = 0.0
var _sprung: bool = false


static func place(parent: Node, terrain: Node, world_pos: Vector3, facing: float = 0.0) -> PunjiTrap:
	var trap := PunjiTrap.new()
	parent.add_child(trap)
	var gy: float = world_pos.y
	if terrain != null and terrain.has_method("get_height_at"):
		gy = terrain.get_height_at(world_pos)
	trap.global_position = Vector3(world_pos.x, gy, world_pos.z)
	trap.rotation.y = facing
	var scene: PackedScene = load(MODEL_PATH)
	if scene:
		trap.add_child(scene.instantiate())
	# brief arming delay so it can never spring on the frame it spawns
	trap.get_tree().create_timer(1.0).timeout.connect(func() -> void: trap._armed = true)
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


func _spring(victim: Node) -> void:
	_sprung = true
	if victim.has_method("take_damage"):
		victim.take_damage(DAMAGE, Enums.DamageType.PHYSICAL, null)
	if victim.has_method("apply_wound"):
		victim.apply_wound("LIMB_LEG")
	# a stifled cry - draws nearby enemies to the noise (NoiseBus VOICE is an AI event)
	NoiseBus.emit_noise(NoiseBus.NoiseType.VOICE, global_position, 1, 12.0)
