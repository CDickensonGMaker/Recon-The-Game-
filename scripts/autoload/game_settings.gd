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
## THE DEFAULT IS THE RATIFIED ADR-026 PART A.4 VALUE, NOT 1.0. project.godot:329 sets
## rendering/scaling_3d/scale=0.75, but PsxLook.apply() runs at every boot and writes
## THIS variable over it - so a 1.0 default here silently shipped full-resolution frames
## from 2026-08-07 to 2026-09-08 while the ADR and every perf row said 0.75. Keep this
## const equal to project.godot's scaling_3d/scale; tests/test_render_scale.gd binds them.
const DEFAULT_RENDER_SCALE: float = 0.75
## Bumped when a shipped default changes in a way an old settings.cfg would mask. A cfg
## written before this rung adopts the new default instead of pinning the stale one.
const SETTINGS_VERSION: int = 2
## Boots the pre-2026-09-08 render state (full-res frames + the as-imported foliage and
## sandbag materials) for a before/after at player eye. MaterialBudget reads the same flag.
const PERF_BEFORE_FLAG := "--perf-before"
var render_scale: float = DEFAULT_RENDER_SCALE

## Vsync quantises frame delivery to display half-steps. At 24-35 fps on a 60Hz panel that
## is the sluggish FEEL, separate from throughput. Off is the bench state; players keep it.
var vsync: bool = true

## Every launcher flag in this project must be readable from EITHER side of the `--`
## separator. `get_cmdline_args()` stops at `--` and `get_cmdline_user_args()` starts after
## it (proved 2026-09-08), so a flag written on the wrong side vanished silently - which is
## exactly how `--print-fps` produced two logs with no measurement in them, twice in one day.
static func has_flag(f: String) -> bool:
	return OS.get_cmdline_args().has(f) or OS.get_cmdline_user_args().has(f)


## The value half of a `--name=value` flag, or "" when the flag is absent or bare. Bare
## `--name` and absent `--name` are DIFFERENT states and callers must be able to tell them
## apart, so ask has_flag() for presence and this for the value.
static func flag_value(name: String) -> String:
	var all: PackedStringArray = OS.get_cmdline_args()
	all.append_array(OS.get_cmdline_user_args())
	var prefix: String = name + "="
	for a: String in all:
		if a.begins_with(prefix):
			return a.substr(prefix.length())
	return ""

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
	if has_flag(PERF_BEFORE_FLAG):
		render_scale = 1.0
		print("[PERF] --perf-before: render scale forced to 1.0, material budget off")
	## --psx / --no-psx: the PSX treatment is the game's own art direction and it has
	## shipped OFF since 2026-08-07 because its default-on was gated on "perf numbers"
	## (psx_look.gd header, SHIP_AUDIT S5) - and the instrument that would have produced
	## them was lying from that same day until 2026-09-08. A flag, not a settings write:
	## a bench must never leave state behind that follows him into normal play.
	if has_flag("--psx"):
		psx_look = true
		print("[PSX] --psx: PSX treatment FORCED ON for this run")
	elif has_flag("--no-psx"):
		psx_look = false
		print("[PSX] --no-psx: PSX treatment FORCED OFF for this run")
	apply_audio()
	apply_vsync()
	if has_flag("--print-fps"):
		_watch_for_the_printer()


func apply_vsync() -> void:
	DisplayServer.window_set_vsync_mode(
		DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED)


## The instrument check. FpsPrinter attaches deep inside GameFlow.enter_hub; if the flag
## never reaches that code, or the hub is never entered, the run produces a log full of
## boot spam and NO measurement - and nothing says so. This makes that state loud.
func _watch_for_the_printer() -> void:
	await get_tree().create_timer(30.0).timeout
	if get_tree() == null:
		return
	if get_tree().get_nodes_in_group("fps_printer").is_empty():
		push_error("[FPS] --print-fps was passed but NO FpsPrinter attached after 30s - "
			+ "this log contains no measurement. Do not quote numbers from it.")
		printerr("[FPS] INSTRUMENT FAILED TO ATTACH - log carries no measurement.")


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
	cfg.set_value("settings", "vsync", vsync)
	cfg.set_value("settings", "version", SETTINGS_VERSION)
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
	vsync = bool(cfg.get_value("settings", "vsync", true))
	## A cfg from before SETTINGS_VERSION 2 carries the old 1.0 default as if it were a
	## choice. Adopt the ratified default instead - otherwise the fix ships to new players
	## only, and the one machine that benches this game keeps rendering at full res.
	if int(cfg.get_value("settings", "version", 1)) < 2:
		render_scale = DEFAULT_RENDER_SCALE
		return
	render_scale = RENDER_SCALE_STEPS[clampi(
		RENDER_SCALE_STEPS.find(float(cfg.get_value(
			"settings", "render_scale", DEFAULT_RENDER_SCALE))),
		0, RENDER_SCALE_STEPS.size() - 1)]
