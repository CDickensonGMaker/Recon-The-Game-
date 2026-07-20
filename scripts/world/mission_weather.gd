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
	"CLEAR": {"fog": 0.0065, "fog_color": Color(0.75, 0.78, 0.7), "light": 1.0, "sight": 1.0, "noise": 1.0, "rain": 0.0},
	"CLOUDY": {"fog": 0.009, "fog_color": Color(0.7, 0.72, 0.68), "light": 0.75, "sight": 0.9, "noise": 1.0, "rain": 0.0},
	"RAIN": {"fog": 0.012, "fog_color": Color(0.6, 0.64, 0.62), "light": 0.55, "sight": 0.7, "noise": 0.75, "rain": 0.5},
	"MONSOON": {"fog": 0.022, "fog_color": Color(0.5, 0.55, 0.54), "light": 0.4, "sight": 0.45, "noise": 0.5, "rain": 1.0},
	"FOG": {"fog": 0.035, "fog_color": Color(0.72, 0.73, 0.68), "light": 0.6, "sight": 0.35, "noise": 0.9, "rain": 0.0},
}

const TIMES := {
	"DAY": {"sun_x": -50.0, "energy": 1.0, "sun_color": Color(1, 0.98, 0.9), "ambient": 0.9},
	"DAWN": {"sun_x": -10.0, "energy": 0.65, "sun_color": Color(1.0, 0.7, 0.45), "ambient": 0.5},
	"DUSK": {"sun_x": -8.0, "energy": 0.55, "sun_color": Color(1.0, 0.55, 0.35), "ambient": 0.45},
	"NIGHT": {"sun_x": -35.0, "energy": 0.08, "sun_color": Color(0.6, 0.7, 0.95), "ambient": 0.15},
}

var _rain: GPUParticles3D
var _rain_audio: AudioStreamPlayer = null
var _squalls: bool = false          # RAIN = comes in waves; MONSOON = constant
var _squall_timer: float = 0.0
static var rain_active: bool = false
var _world: GameWorld


## SimClock.Period is ordered DAWN, DAY, DUSK, NIGHT. Index by that enum's value.
const PERIOD_TO_TIME_ID: Array[String] = ["DAWN", "DAY", "DUSK", "NIGHT"]
## Sim-hour to start the mission at for each briefing time_id, so the clock and the
## briefing roll agree. Without this the first period transition would contradict
## the briefing - a NIGHT insert would snap to DAY.
const TIME_ID_START_HOUR := {"DAWN": 5.5, "DAY": 10.0, "DUSK": 17.5, "NIGHT": 21.0}
const TIME_EASE_SECONDS: float = 6.0

var _weather: Dictionary = {}


func setup(world: GameWorld, weather_id: String, time_id: String) -> void:
	_world = world
	_weather = WEATHER.get(weather_id, WEATHER["CLEAR"])
	var w: Dictionary = _weather

	SimClock.sim_hour = float(TIME_ID_START_HOUR.get(time_id, 10.0))
	_apply_time(time_id)
	SimClock.time_period_changed.connect(_on_time_period_changed)

	var env_node := world.get_node_or_null("WorldEnvironment") as WorldEnvironment if world != null else null
	if env_node and env_node.environment:
		var env := env_node.environment
		env.fog_enabled = true
		env.fog_density = float(w.fog)
		env.fog_light_color = w.fog_color

	NoiseBus.radius_multiplier = float(w.noise)

	if float(w.rain) > 0.0:
		_spawn_rain(float(w.rain))
		_start_rain_audio()
		if weather_id == "RAIN":
			# Squalls: the downpour comes in waves. Opens raining, then breaks -
			# and the jungle slowly finds its voice again until the next cell hits.
			_squalls = true
			_squall_timer = randf_range(50.0, 110.0)
		_set_raining(true)
	else:
		rain_active = false


## Night must actually FALL. The briefing roll only picks the hour the mission opens;
## SimClock owns time after that, and every light/sight/tracer value that depends on
## the hour is re-derived here on each DAWN/DAY/DUSK/NIGHT crossing.
func _on_time_period_changed(period: int) -> void:
	if period < 0 or period >= PERIOD_TO_TIME_ID.size():
		return
	_apply_time(PERIOD_TO_TIME_ID[period], false)


## `immediate` is true only for the opening state. A period crossing eases the sun over
## a few seconds; snapping DAY->DUSK in one frame reads as a light bulb, not a sunset.
func _apply_time(time_id: String, immediate: bool = true) -> void:
	var t: Dictionary = TIMES.get(time_id, TIMES["DAY"])
	var w: Dictionary = _weather if not _weather.is_empty() else WEATHER["CLEAR"]

	## Weather only. Time-of-day darkening lives in SightCap.darkness_mult (SimClock),
	## the single time authority; folding t.sight here too would double-count night.
	sight_mult = float(w.sight)
	is_night = time_id == "NIGHT"

	if _world == null or not is_instance_valid(_world):
		return
	var ambient: float = float(t.ambient) * float(w.light)
	var energy: float = float(t.energy) * float(w.light)
	var env_node := _world.get_node_or_null("WorldEnvironment") as WorldEnvironment
	var env: Environment = env_node.environment if env_node else null
	var sun := _world.get_node_or_null("SunLight") as DirectionalLight3D

	if immediate:
		if env:
			env.ambient_light_energy = ambient
		if sun:
			sun.rotation_degrees.x = float(t.sun_x)
			sun.light_energy = energy
			sun.light_color = t.sun_color
		return

	var tw: Tween = create_tween().set_parallel(true)
	if env:
		tw.tween_property(env, "ambient_light_energy", ambient, TIME_EASE_SECONDS)
	if sun:
		tw.tween_property(sun, "rotation_degrees:x", float(t.sun_x), TIME_EASE_SECONDS)
		tw.tween_property(sun, "light_energy", energy, TIME_EASE_SECONDS)
		tw.tween_property(sun, "light_color", t.sun_color, TIME_EASE_SECONDS)


func _start_rain_audio() -> void:
	var s := load("res://assets/audio/sfx/rain_loop.wav") as AudioStreamWAV
	if s == null:
		return
	s.loop_mode = AudioStreamWAV.LOOP_FORWARD
	s.loop_end = s.data.size() / 2
	_rain_audio = AudioStreamPlayer.new()
	_rain_audio.stream = s
	_rain_audio.volume_db = -60.0
	add_child(_rain_audio)
	_rain_audio.play()


func _set_raining(on: bool) -> void:
	rain_active = on
	if _rain != null:
		_rain.emitting = on
	if _rain_audio != null:
		var tw := create_tween()
		tw.tween_property(_rain_audio, "volume_db", -10.0 if on else -60.0, 2.5 if on else 6.0)
	if _world != null and is_instance_valid(_world):
		_world.set_wildlife_ducked(on)


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
	# Squall cycle (RAIN weather): downpours come in waves; wildlife ducks during,
	# fades back slowly after (see GameWorld.set_wildlife_ducked).
	if _squalls:
		_squall_timer -= delta
		if _squall_timer <= 0.0:
			if rain_active:
				_set_raining(false)
				_squall_timer = randf_range(70.0, 150.0)   # the break between cells
			else:
				_set_raining(true)
				_squall_timer = randf_range(50.0, 110.0)   # the next downpour
	if _rain == null or _world == null or _world.player == null:
		return
	_follow_timer += delta
	if _follow_timer >= 0.15:
		_follow_timer = 0.0
		_rain.global_position = _world.player.global_position + Vector3(0, 14, 0)


func _exit_tree() -> void:
	if SimClock.time_period_changed.is_connected(_on_time_period_changed):
		SimClock.time_period_changed.disconnect(_on_time_period_changed)
	sight_mult = 1.0
	NoiseBus.radius_multiplier = 1.0
	is_night = false
