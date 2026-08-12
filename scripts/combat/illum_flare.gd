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

## The downward cone has to reach the ground from wherever it is hung, so its range
## is driven by altitude, not by light_radius.
const SPOT_RANGE_PAD_M: float = 60.0
const SPOT_ENERGY: float = 48.0
## How low a flare is by the time it burns out.
const END_HEIGHT_M: float = 20.0
const OMNI_ENERGY: float = 12.0
## Seconds of ramp at each end - a flare catches, then dies, it does not switch.
const IGNITE_S: float = 0.6
const BURNOUT_S: float = 6.0
## Canopy swing under the parachute.
const SWING_M: float = 5.0
const SWING_HZ: float = 0.11

var duration: float = DURATION
var light_radius: float = LIGHT_RADIUS
var drift: float = DRIFT_M_PER_S

var _age: float = 0.0
var _spot: SpotLight3D = null
var _omni: OmniLight3D = null
var _halo: MeshInstance3D = null
var _core: MeshInstance3D = null
var _anchor_x: float = 0.0
var _anchor_z: float = 0.0
var _flicker: float = 1.0


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
	# Descend rate is whatever carries it from its burst height down to END_HEIGHT_M
	# over its own burn, so a round that hangs higher falls faster instead of
	# appearing to hover, and none of them reach the deck while still lit.
	var end_h: float = minf(END_HEIGHT_M, height * 0.15)
	flare.drift = maxf(0.4, (height - end_h) / maxf(1.0, burn))
	parent.add_child(flare)
	flare.global_position = pos + Vector3(0, height, 0)
	return flare


func _ready() -> void:
	active_flares.append(self)
	_anchor_x = global_position.x
	_anchor_z = global_position.z

	var altitude: float = maxf(10.0, global_position.y)

	# Cone wide enough that its footprint on the deck is light_radius across.
	_spot = SpotLight3D.new()
	_spot.light_color = Color(1.0, 0.94, 0.76)
	_spot.light_energy = 0.0
	_spot.spot_range = altitude + SPOT_RANGE_PAD_M
	_spot.spot_angle = clampf(rad_to_deg(atan(light_radius / altitude)), 12.0, 78.0)
	_spot.spot_angle_attenuation = 0.6
	_spot.spot_attenuation = 0.7
	_spot.shadow_enabled = false
	_spot.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	add_child(_spot)

	_omni = OmniLight3D.new()
	_omni.light_color = Color(1.0, 0.93, 0.72)
	_omni.light_energy = 0.0
	_omni.omni_range = light_radius * 1.5
	_omni.shadow_enabled = false
	add_child(_omni)

	_core = MeshInstance3D.new()
	var core_mesh := SphereMesh.new()
	core_mesh.radius = 0.5
	core_mesh.height = 1.0
	core_mesh.radial_segments = 6
	core_mesh.rings = 3
	_core.mesh = core_mesh
	_core.material_override = _burn_material(Color(1.0, 0.98, 0.9), false)
	_core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_core)

	# The burning head has to read from across the valley, so the halo is a
	# billboard - and billboard materials DISCARD node scale unless kept.
	_halo = MeshInstance3D.new()
	var halo_mesh := QuadMesh.new()
	halo_mesh.size = Vector2(9.0, 9.0)
	_halo.mesh = halo_mesh
	_halo.material_override = _burn_material(Color(1.0, 0.86, 0.55), true)
	_halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_halo)

	_add_trail()
	NoiseBus.emit_noise(NoiseBus.NoiseType.IMPACT, global_position, 0)


func _burn_material(tint: Color, billboard: bool) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = tint
	mat.emission_enabled = true
	mat.emission = tint
	mat.emission_energy_multiplier = 6.0
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.disable_receive_shadows = true
	if billboard:
		mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		mat.billboard_keep_scale = true
	return mat


func _add_trail() -> void:
	var smoke := CPUParticles3D.new()
	smoke.amount = 40
	smoke.lifetime = 6.0
	smoke.local_coords = false
	smoke.direction = Vector3.UP
	smoke.spread = 12.0
	smoke.initial_velocity_min = 0.4
	smoke.initial_velocity_max = 1.4
	smoke.gravity = Vector3(0.3, 0.9, 0.0)
	smoke.scale_amount_min = 1.4
	smoke.scale_amount_max = 3.6
	smoke.color = Color(0.72, 0.70, 0.66, 0.5)
	add_child(smoke)
	smoke.emitting = true


## 0 at ignition, 1 through the burn, 0 as it dies.
func _burn01() -> float:
	var ignite: float = clampf(_age / IGNITE_S, 0.0, 1.0)
	var left: float = duration - _age
	var fade: float = clampf(left / BURNOUT_S, 0.0, 1.0)
	return minf(ignite, fade)


func _physics_process(delta: float) -> void:
	_age += delta
	global_position.y -= drift * delta

	_anchor_x += 0.4 * delta
	var swing: float = sin(_age * TAU * SWING_HZ) * SWING_M
	global_position.x = _anchor_x + swing
	global_position.z = _anchor_z + cos(_age * TAU * SWING_HZ * 0.7) * SWING_M * 0.6

	_flicker = lerpf(_flicker, randf_range(0.86, 1.0), clampf(delta * 9.0, 0.0, 1.0))
	var burn: float = _burn01() * _flicker

	var altitude: float = maxf(10.0, global_position.y)
	if _spot != null:
		_spot.light_energy = SPOT_ENERGY * burn
		_spot.spot_range = altitude + SPOT_RANGE_PAD_M
		_spot.spot_angle = clampf(rad_to_deg(atan(light_radius / altitude)), 12.0, 78.0)
	if _omni != null:
		_omni.light_energy = OMNI_ENERGY * burn
	if _core != null:
		_core.scale = Vector3.ONE * maxf(0.05, burn)
	if _halo != null:
		_halo.scale = Vector3.ONE * maxf(0.05, burn)

	if _age >= duration:
		active_flares.erase(self)
		queue_free()


func _exit_tree() -> void:
	active_flares.erase(self)
