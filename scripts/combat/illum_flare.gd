## illum_flare.gd - Pop flare (W54): drifting light that strips night
## concealment in its circle. Works both ways - you're lit too.
class_name IllumFlare
extends Node3D

static var active_flares: Array[IllumFlare] = []

const DURATION: float = 25.0
const LIGHT_RADIUS: float = 30.0

var _age: float = 0.0


static func is_lit(pos: Vector3) -> bool:
	for f in active_flares:
		if is_instance_valid(f) and Vector2(pos.x - f.global_position.x, pos.z - f.global_position.z).length() < LIGHT_RADIUS:
			return true
	return false


static func pop(parent: Node, pos: Vector3) -> IllumFlare:
	var flare := IllumFlare.new()
	parent.add_child(flare)
	flare.global_position = pos + Vector3(0, 40.0, 0)
	return flare


func _ready() -> void:
	active_flares.append(self)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.95, 0.8)
	light.light_energy = 3.5
	light.omni_range = LIGHT_RADIUS * 1.4
	add_child(light)
	NoiseBus.emit_noise(NoiseBus.NoiseType.IMPACT, global_position, 0)


func _physics_process(delta: float) -> void:
	_age += delta
	global_position.y -= 1.2 * delta  # slow drift down
	global_position.x += 0.4 * delta
	if _age >= DURATION:
		active_flares.erase(self)
		queue_free()


func _exit_tree() -> void:
	active_flares.erase(self)
