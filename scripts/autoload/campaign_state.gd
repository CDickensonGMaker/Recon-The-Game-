## campaign_state.gd - persistent campaign layer: AA threat level with decaying
## modifiers, team XP, roster, mission history. Saved to user://.
extends Node

## Bump when the on-disk shape changes, and add a branch to _migrate().
const SAVE_VERSION: int = 1
const DEFAULT_SAVE_PATH := "user://campaign.cfg"
const TEST_SAVE_PATH := "user://campaign_test.cfg"
const BASE_THREAT: float = 0.35

## Resolved in _ready() BEFORE load_campaign(): the headless suite passes
## `-- --test-save` so tests can never touch the player's real campaign.
var save_path: String = DEFAULT_SAVE_PATH

## Mid-mission writes are held in memory until the debrief commits them - a
## mission is ALL-OR-NOTHING. Squad code mutates LIVE references into `roster`,
## so an un-deferred save mid-mission would persist a KIA without the team_xp,
## missions_played and mission log that must land with it.
var _defer_saves: bool = false
var _dirty: bool = false

var threat_level: float = BASE_THREAT
var threat_modifiers: Array = []  ## [{delta: float, missions_left: int, reason: String}]
var team_xp: int = 0
var roster: Array = []            ## SquadMember dicts
var missions_played: int = 0
var mission_log: Array = []       ## trimmed result dicts
var iron_man: bool = false
var player_data: Dictionary = {"mos": "RIFLEMAN"}
var intel_points: int = 0  ## looted docs/captures sharpen the next briefing
## Tunnel mouths the player has satchelled, as world positions rounded to the
## metre. ADR-029 Amendment B: the world remembers a world verb. Never surfaced
## as a count, a panel or a marker - only as ground that is no longer there.
var collapsed_tunnels: Array = []
## Armorer's rack fouling, weapon id -> condition 0-100. A weapon you rack dirty
## is still dirty when you draw it again; swapping is never a free clean.
var rack_condition: Dictionary = {}
## The cost of a firebase breach: what a sapper's satchel took out of the depot,
## as an ordnance-kind -> count dict. Read and CONSUMED by FieldDirector on the
## next walk-out (persistent, not permanent - it is one patrol's short allotment).
var depot_loss: Dictionary = {}




## The living squadmate of a MOS owns his role's skill. Used at world-gen, before
## SquadSystem has spawned any AllyBase - reads the persistent roster directly.
## In-mission, prefer SquadRoster.skill_level(member_by_mos(mos).member, skill).
func roster_skill(mos: String, skill: String) -> int:
	for m in roster:
		var d: Dictionary = m
		if str(d.get("mos", "")) == mos and bool(d.get("alive", true)):
			return int((d.get("skills", {}) as Dictionary).get(skill, 0))
	return 0


func _ready() -> void:
	if is_test_run():
		save_path = TEST_SAVE_PATH
		# Never inherit a previous run's leftovers - the suite must start clean.
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE_PATH))
	load_campaign()


## True when launched by run_all_tests.ps1 (`-- --test-save`).
static func is_test_run() -> bool:
	return OS.get_cmdline_user_args().has("--test-save")


func effective_threat() -> float:
	var total: float = threat_level
	for m in threat_modifiers:
		total += float(m.delta)
	return clampf(total, 0.0, 1.0)


func threat_label() -> String:
	var t := effective_threat()
	if t < 0.25:
		return "LOW"
	elif t < 0.5:
		return "MODERATE"
	elif t < 0.75:
		return "HIGH"
	return "CRITICAL"


func add_threat_modifier(delta: float, missions: int, reason: String) -> void:
	threat_modifiers.append({"delta": delta, "missions_left": missions, "reason": reason})


## Called by GameFlow at debrief time.
func on_mission_end(result: Dictionary) -> void:
	# The mission is over: writes go through again, and the save_campaign() at the
	# bottom of this function commits everything the op changed.
	_defer_saves = false
	_dirty = false
	missions_played += 1
	# Decay modifiers.
	var kept: Array = []
	for m in threat_modifiers:
		m.missions_left = int(m.missions_left) - 1
		if int(m.missions_left) > 0:
			kept.append(m)
	threat_modifiers = kept
	# Outcome nudges the baseline: loud missions attract attention, clean work cools the AO.
	var kills: int = int(result.get("kills", 0))
	if kills >= 12:
		threat_level = clampf(threat_level + 0.05, 0.1, 0.9)
	elif bool(result.get("success", false)) and kills <= 3:
		threat_level = clampf(threat_level - 0.03, 0.1, 0.9)
	# ANTI-AA payoff: completing an ANTI-AA op, or killing AA opportunistically.
	if bool(result.get("is_anti_aa", false)) and bool(result.get("success", false)):
		add_threat_modifier(-0.25, 3, "AA BATTERY DESTROYED")
	elif int(result.get("aa_killed", 0)) > 0:
		add_threat_modifier(-0.08 * float(result.aa_killed), 2, "AA SITE DESTROYED")
	# Log (trimmed).
	mission_log.append({
		"type": str(result.get("mission_type", "?")),
		"success": bool(result.get("success", false)),
		"kills": kills,
		"seed": int(result.get("seed", 0)),
	})
	if mission_log.size() > 40:
		mission_log = mission_log.slice(mission_log.size() - 40)
	save_campaign()


## Called by GameFlow when a mission starts. Everything written between here and
## commit_mission() stays in memory.
func begin_mission() -> void:
	_defer_saves = true
	_dirty = false


## Called at the debrief (or on abort). Flushes whatever the mission changed.
func commit_mission() -> void:
	_defer_saves = false
	if _dirty:
		_dirty = false
		save_campaign()


func save_campaign() -> void:
	if _defer_saves:
		_dirty = true
		return
	var cfg := ConfigFile.new()
	cfg.set_value("campaign", "version", SAVE_VERSION)
	cfg.set_value("campaign", "threat_level", threat_level)
	cfg.set_value("campaign", "threat_modifiers", threat_modifiers)
	cfg.set_value("campaign", "team_xp", team_xp)
	cfg.set_value("campaign", "roster", roster)
	cfg.set_value("campaign", "missions_played", missions_played)
	cfg.set_value("campaign", "mission_log", mission_log)
	cfg.set_value("campaign", "iron_man", iron_man)
	cfg.set_value("campaign", "player_data", player_data)
	cfg.set_value("campaign", "intel_points", intel_points)
	cfg.set_value("campaign", "collapsed_tunnels", collapsed_tunnels)
	cfg.set_value("campaign", "rack_condition", rack_condition)
	cfg.set_value("campaign", "depot_loss", depot_loss)
	var err: int = cfg.save(save_path)
	if err != OK:
		push_error("[SAVE] could not write %s (err %d) - campaign progress lost" % [save_path, err])


func load_campaign() -> void:
	var cfg := ConfigFile.new()
	var err: int = cfg.load(save_path)
	if err != OK:
		# ERR_FILE_NOT_FOUND is the normal first-boot path. Anything else means the
		# file exists and is unreadable. Keep a copy before we overwrite it.
		if err != ERR_FILE_NOT_FOUND:
			var bak := save_path + ".bak"
			if FileAccess.file_exists(save_path):
				DirAccess.copy_absolute(save_path, bak)
			push_error("[SAVE] %s failed to load (err %d). Backed up to %s; starting fresh." % [save_path, err, bak])
		return

	var file_version: int = int(cfg.get_value("campaign", "version", 0))
	if file_version > SAVE_VERSION:
		push_error("[SAVE] %s is version %d, this build understands %d. Refusing to load rather than corrupt it." % [
			save_path, file_version, SAVE_VERSION])
		return
	if file_version < SAVE_VERSION:
		_migrate(cfg, file_version)
	threat_level = float(cfg.get_value("campaign", "threat_level", BASE_THREAT))
	threat_modifiers = cfg.get_value("campaign", "threat_modifiers", [])
	team_xp = int(cfg.get_value("campaign", "team_xp", 0))
	roster = cfg.get_value("campaign", "roster", [])
	missions_played = int(cfg.get_value("campaign", "missions_played", 0))
	mission_log = cfg.get_value("campaign", "mission_log", [])
	iron_man = bool(cfg.get_value("campaign", "iron_man", false))
	player_data = cfg.get_value("campaign", "player_data", {"mos": "RIFLEMAN"})
	intel_points = int(cfg.get_value("campaign", "intel_points", 0))
	collapsed_tunnels = cfg.get_value("campaign", "collapsed_tunnels", []) as Array
	rack_condition = cfg.get_value("campaign", "rack_condition", {}) as Dictionary
	depot_loss = cfg.get_value("campaign", "depot_loss", {}) as Dictionary
	# Persist a migrated save immediately - otherwise the migrate warning fires on
	# EVERY boot until the next natural save.
	if file_version < SAVE_VERSION:
		save_campaign()


## v0 (unversioned) had no `version` key and no sprite fields on the roster.
## Nothing structural changed, so v0 loads as-is. The branch exists so the NEXT
## shape change has somewhere to live instead of silently half-loading.
func _migrate(_cfg: ConfigFile, from_version: int) -> void:
	push_warning("[SAVE] migrating campaign save v%d -> v%d" % [from_version, SAVE_VERSION])


## SaveData contract (SaveManager slots). Mirrors exactly what the cfg persists,
## so the two stores can never disagree about what campaign state IS.
func to_dict() -> Dictionary:
	return {
		"threat_level": threat_level,
		"threat_modifiers": threat_modifiers.duplicate(true),
		"team_xp": team_xp,
		"roster": roster.duplicate(true),
		"missions_played": missions_played,
		"mission_log": mission_log.duplicate(true),
		"iron_man": iron_man,
		"player_data": player_data.duplicate(true),
		"intel_points": intel_points,
		"collapsed_tunnels": collapsed_tunnels,
		"rack_condition": rack_condition.duplicate(true),
		"depot_loss": depot_loss.duplicate(true),
	}


func from_dict(d: Dictionary) -> void:
	if d.is_empty():
		return
	threat_level = float(d.get("threat_level", BASE_THREAT))
	threat_modifiers = d.get("threat_modifiers", [])
	team_xp = int(d.get("team_xp", 0))
	roster = d.get("roster", [])
	missions_played = int(d.get("missions_played", 0))
	mission_log = d.get("mission_log", [])
	iron_man = bool(d.get("iron_man", false))
	player_data = d.get("player_data", {"mos": "RIFLEMAN"})
	intel_points = int(d.get("intel_points", 0))
	collapsed_tunnels = d.get("collapsed_tunnels", []) as Array
	rack_condition = d.get("rack_condition", {}) as Dictionary
	depot_loss = d.get("depot_loss", {}) as Dictionary


func reset_campaign() -> void:
	# A wipe must hit the disk even if a mission is mid-flight (Iron Man death).
	_defer_saves = false
	_dirty = false
	threat_level = BASE_THREAT
	threat_modifiers = []
	team_xp = 0
	roster = []
	missions_played = 0
	mission_log = []
	# iron_man is a PLAYER SETTING, not campaign progress - do NOT clear it here,
	# or an Iron Man death silently disables the very mode that caused the wipe.
	player_data = {"mos": "RIFLEMAN"}
	intel_points = 0
	collapsed_tunnels = []
	rack_condition = {}
	depot_loss = {}
	save_campaign()


## A weapon never drawn is a fresh weapon.
func rack_condition_of(weapon_id: String) -> float:
	return float(rack_condition.get(weapon_id, 100.0))


func store_rack_condition(weapon_id: String, condition: float) -> void:
	rack_condition[weapon_id] = clampf(condition, 0.0, 100.0)
	save_campaign()


## Record a satchelled tunnel mouth so the next patrol finds it still collapsed.
func remember_collapsed_tunnel(world_pos: Vector3) -> void:
	var key := Vector3(roundf(world_pos.x), roundf(world_pos.y), roundf(world_pos.z))
	if not collapsed_tunnels.has(key):
		collapsed_tunnels.append(key)
		save_campaign()


## True if this mouth was blown on an earlier patrol. Tolerant to the metre so a
## re-generated world places the entrance close enough to still match.
func tunnel_is_collapsed(world_pos: Vector3) -> bool:
	for c in collapsed_tunnels:
		if (c as Vector3).distance_to(world_pos) < 3.0:
			return true
	return false
