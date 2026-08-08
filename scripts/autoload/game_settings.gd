## game_settings.gd - persisted user settings: sensitivity, volume,
## difficulty, HARDCORE mode, PSX look.
extends Node

const PATH := "user://settings.cfg"

var mouse_sensitivity: float = 0.002
var master_volume_db: float = 0.0
var sfx_volume_db: float = 0.0
var ambience_volume_db: float = 0.0
var music_volume_db: float = -3.0
var difficulty: int = 1  ## 0 EASY / 1 NORMAL / 2 HARD
var hardcore: bool = false  ## no compass/markers (mission_hud) + HARD save tier (save_manager)
var psx_look: bool = false  ## PS1 render treatment; applied by PsxLook autoload
## Manual render-scale rung, one of RENDER_SCALE_STEPS. PsxLook.apply() is the
## ONLY writer of viewport scaling_3d_scale; when psx_look is ON it overrides this.
var render_scale: float = 1.0

## THE firefight-length dial (C2). Widens the AI-vs-AI cone cap so troopers spray and fights last.
## 1.0 = fair, lethal baseline (a mirror match trends ~1:1). 2.5-3.0 = "Star Wars trooper" volume of
## fire. It only ever scales the non-player cone cap - AI-vs-player lethality is untouched.
var ai_vs_ai_cone_mult: float = 1.0

## Scales damage the PLAYER DEALS. Keeps his gunfeel independent of AI durability, so
## AI HP can be raised to watch a long AI-vs-AI fight without his rifle going soft.
## NOT to be confused with player_damage_mult() below, which is the OPPOSITE direction -
## damage he TAKES, off the difficulty setting. Two names, two directions; read twice.
var player_outgoing_damage_mult: float = 1.0

const DIFFICULTY_NAMES: Array[String] = ["EASY", "NORMAL", "HARD"]

const RENDER_SCALE_STEPS: Array[float] = [1.0, 0.75, 0.5]
const RENDER_SCALE_NAMES: Array[String] = ["FULL", "75%", "50%"]


func _ready() -> void:
	load_settings()
	apply_audio()


## Enemy accuracy scale per difficulty (spread multiplier - higher = worse aim).
func enemy_spread_mult() -> float:
	return [1.5, 1.0, 0.7][clampi(difficulty, 0, 2)]


## Damage the player takes.
func player_damage_mult() -> float:
	return [0.7, 1.0, 1.3][clampi(difficulty, 0, 2)]


func render_scale_index() -> int:
	for i in RENDER_SCALE_STEPS.size():
		if is_equal_approx(render_scale, RENDER_SCALE_STEPS[i]):
			return i
	return 0


func apply_audio() -> void:
	_set_bus("Master", master_volume_db)
	_set_bus("SFX", sfx_volume_db)
	_set_bus("Ambience", ambience_volume_db)
	_set_bus("Music", music_volume_db)


func _set_bus(bus_name: String, db: float) -> void:
	var idx: int = AudioServer.get_bus_index(bus_name)
	if idx >= 0:
		AudioServer.set_bus_volume_db(idx, db)
	elif bus_name == "Master":
		AudioServer.set_bus_volume_db(0, db)


func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("settings", "mouse_sensitivity", mouse_sensitivity)
	cfg.set_value("settings", "master_volume_db", master_volume_db)
	cfg.set_value("settings", "sfx_volume_db", sfx_volume_db)
	cfg.set_value("settings", "ambience_volume_db", ambience_volume_db)
	cfg.set_value("settings", "music_volume_db", music_volume_db)
	cfg.set_value("settings", "difficulty", difficulty)
	cfg.set_value("settings", "hardcore", hardcore)
	cfg.set_value("settings", "psx_look", psx_look)
	cfg.set_value("settings", "render_scale", render_scale)
	cfg.save(PATH)


func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	mouse_sensitivity = float(cfg.get_value("settings", "mouse_sensitivity", 0.002))
	master_volume_db = float(cfg.get_value("settings", "master_volume_db", 0.0))
	sfx_volume_db = float(cfg.get_value("settings", "sfx_volume_db", 0.0))
	ambience_volume_db = float(cfg.get_value("settings", "ambience_volume_db", 0.0))
	music_volume_db = float(cfg.get_value("settings", "music_volume_db", -3.0))
	difficulty = int(cfg.get_value("settings", "difficulty", 1))
	hardcore = bool(cfg.get_value("settings", "hardcore", false))
	psx_look = bool(cfg.get_value("settings", "psx_look", false))
	render_scale = RENDER_SCALE_STEPS[clampi(
		RENDER_SCALE_STEPS.find(float(cfg.get_value("settings", "render_scale", 1.0))),
		0, RENDER_SCALE_STEPS.size() - 1)]
