## weather_director.gd - applies the mission's weather + time-of-day to the
## WorldEnvironment. On mission start, reads `params["weather"]` and adjusts
## fog density, sky color, audio buses; on SimClock.day_advanced, rolls new
## weather for the next day.
class_name WeatherDirector
extends Node

## CLEAR, CLOUDY, RAIN, FOG/MONSOON. Read from the mission parameters.
const WEATHER_TABLE: Dictionary = {
	"CLEAR": 0.6,
	"CLOUDY": 0.2,
	"RAIN": 0.15,
	"FOG": 0.05,
}

var current_weather: String = "CLEAR"
var world_environment: WorldEnvironment = null
var rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:
	if SimClock != null:
		var cb := Callable(self, "_on_day_advanced")
		if not SimClock.day_advanced.is_connected(cb):
			SimClock.day_advanced.connect(cb)


func setup(weather: String, env: WorldEnvironment, seed_value: int = 0) -> void:
	current_weather = weather
	world_environment = env
	if seed_value != 0:
		rng.seed = seed_value + 2617  # weather rolls fold the operation seed (ADR-010)
	_apply(current_weather)


func _on_day_advanced(_sim_day: int) -> void:
	current_weather = _roll_weather()
	_apply(current_weather)


func _roll_weather() -> String:
	var pick: float = rng.randf()
	var acc: float = 0.0
	for k in WEATHER_TABLE.keys():
		acc += float(WEATHER_TABLE[k])
		if pick <= acc:
			return k
	return "CLEAR"


func _apply(weather: String) -> void:
	if world_environment == null or world_environment.environment == null:
		return
	var e: Environment = world_environment.environment
	match weather:
		"CLEAR":
			e.fog_density = 0.0
			e.fog_light_color = Color(0.7, 0.75, 0.8)
		"CLOUDY":
			e.fog_density = 0.01
			e.fog_light_color = Color(0.55, 0.6, 0.65)
		"RAIN":
			e.fog_density = 0.025
			e.fog_light_color = Color(0.4, 0.45, 0.5)
		"FOG":
			e.fog_density = 0.06
			e.fog_light_color = Color(0.5, 0.55, 0.55)
