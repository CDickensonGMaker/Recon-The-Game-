## mission_weather.gd - Weather + time-of-day for a mission (W42/W43/W70).
## Drives fog/light/rain, AI sight caps, and NoiseBus masking from the briefing
## roll. BPRTS-derived preset model, original implementation.
class_name MissionWeather
extends Node

## Global perception multiplier consumed by enemy sight caps.
static var sight_mult: float = 1.0
## R78: true during NIGHT missions - tracers/muzzle flashes read brighter.
static var is_night: bool = false

const WEATHER := {
	"CLEAR": {"fog": 0.004, "fog_color": Color(0.75, 0.78, 0.7), "light": 1.0, "sight": 1.0, "noise": 1.0, "rain": 0.0},
	"CLOUDY": {"fog": 0.007, "fog_color": Color(0.7, 0.72, 0.68), "light": 0.75, "sight": 0.9, "noise": 1.0, "rain": 0.0},
	"RAIN": {"fog": 0.012, "fog_color": Color(0.6, 0.64, 0.62), "light": 0.55, "sight": 0.7, "noise": 0.75, "rain": 0.5},
	"MONSOON": {"fog": 0.022, "fog_color": Color(0.5, 0.55, 0.54), "light": 0.4, "sight": 0.45, "noise": 0.5, "rain": 1.0},
	"FOG": {"fog": 0.035, "fog_color": Color(0.72, 0.73, 0.68), "light": 0.6, "sight": 0.35, "noise": 0.9, "rain": 0.0},
}

const TIMES := {
	"DAY": {"sun_x": -50.0, "energy": 1.0, "sun_color": Color(1, 0.98, 0.9), "sight": 1.0, "ambient": 0.9},
	"DAWN": {"sun_x": -10.0, "energy": 0.65, "sun_color": Color(1.0, 0.7, 0.45), "sight": 0.8, "ambient": 0.5},
	"DUSK": {"sun_x": -8.0, "energy": 0.55, "sun_color": Color(1.0, 0.55, 0.35), "sight": 0.75, "ambient": 0.45},
	"NIGHT": {"sun_x": -35.0, "energy": 0.08, "sun_color": Color(0.6, 0.7, 0.95), "sight": 0.4, "ambient": 0.15},
}

var _rain: GPUParticles3D
var _world: GameWorld


func setup(world: GameWorld, weather_id: String, time_id: String) -> void:
	_world = world
	var w: Dictionary = WEATHER.get(weather_id, WEATHER["CLEAR"])
	var t: Dictionary = TIMES.get(time_id, TIMES["DAY"])

	var env_node := world.get_node_or_null("WorldEnvironment") as WorldEnvironment
	if env_node and env_node.environment:
		var env := env_node.environment
		env.fog_enabled = true
		env.fog_density = float(w.fog)
		env.fog_light_color = w.fog_color
		env.ambient_light_energy = float(t.ambient) * float(w.light)
	var sun := world.get_node_or_null("SunLight") as DirectionalLight3D
	if sun:
		sun.rotation_degrees.x = float(t.sun_x)
		sun.light_energy = float(t.energy) * float(w.light)
		sun.light_color = t.sun_color

	sight_mult = float(w.sight) * float(t.sight)
	NoiseBus.radius_multiplier = float(w.noise)
	is_night = time_id == "NIGHT"

	if float(w.rain) > 0.0:
		_spawn_rain(float(w.rain))


func _spawn_rain(intensity: float) -> void:
	_rain = GPUParticles3D.new()
	_rain.amount = int(600 * intensity)
	_rain.lifetime = 0.9
	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0.1, -1, 0)
	mat.initial_velocity_min = 18.0
	mat.initial_velocity_max = 24.0
	mat.gravity = Vector3(0, -20, 0)
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = Vector3(22, 1, 22)
	_rain.process_material = mat
	var quad := QuadMesh.new()
	quad.size = Vector2(0.02, 0.5)
	var qmat := StandardMaterial3D.new()
	qmat.albedo_color = Color(0.7, 0.75, 0.8, 0.35)
	qmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	qmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	qmat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	quad.material = qmat
	_rain.draw_pass_1 = quad
	_rain.visibility_aabb = AABB(Vector3(-30, -20, -30), Vector3(60, 45, 60))
	add_child(_rain)


var _follow_timer: float = 0.0


func _process(delta: float) -> void:
	if _rain == null or _world == null or _world.player == null:
		return
	_follow_timer += delta
	if _follow_timer >= 0.15:
		_follow_timer = 0.0
		_rain.global_position = _world.player.global_position + Vector3(0, 14, 0)


func _exit_tree() -> void:
	sight_mult = 1.0
	NoiseBus.radius_multiplier = 1.0
	is_night = false
