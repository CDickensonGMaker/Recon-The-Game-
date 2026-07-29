## illum_flare.gd - pop flare: drifting light that strips night
## concealment in its circle. Works both ways - you're lit too.
class_name IllumFlare
extends Node3D

static var active_flares: Array[IllumFlare] = []

## Hand-flare values. A mortar illumination round overrides both through pop() -
## it burns longer and lights a sector rather than a circle you could throw across.
const DURATION: float = 25.0
const LIGHT_RADIUS: float = 30.0
const DRIFT_M_PER_S: float = 1.2

var duration: float = DURATION
var light_radius: float = LIGHT_RADIUS
var drift: float = DRIFT_M_PER_S

var _age: float = 0.0


static func is_lit(pos: Vector3) -> bool:
	for f in active_flares:
		if is_instance_valid(f) and Vector2(pos.x - f.global_position.x, pos.z - f.global_position.z).length() < f.light_radius:
			return true
	return false


static func pop(parent: Node, pos: Vector3, burn: float = DURATION,
		radius: float = LIGHT_RADIUS, height: float = 40.0) -> IllumFlare:
	var flare := IllumFlare.new()
	flare.duration = burn
	flare.light_radius = radius
	# A round that hangs 3x higher must fall no faster, or it lands before it burns.
	flare.drift = DRIFT_M_PER_S * (height / 40.0) * (DURATION / maxf(1.0, burn))
	parent.add_child(flare)
	flare.global_position = pos + Vector3(0, height, 0)
	return flare


func _ready() -> void:
	active_flares.append(self)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.95, 0.8)
	light.light_energy = 3.5
	light.omni_range = light_radius * 1.4
	add_child(light)
	NoiseBus.emit_noise(NoiseBus.NoiseType.IMPACT, global_position, 0)


func _physics_process(delta: float) -> void:
	_age += delta
	global_position.y -= drift * delta
	global_position.x += 0.4 * delta
	if _age >= duration:
		active_flares.erase(self)
		queue_free()


func _exit_tree() -> void:
	active_flares.erase(self)
