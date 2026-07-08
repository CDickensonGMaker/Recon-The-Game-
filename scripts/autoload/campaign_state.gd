## campaign_state.gd - Persistent campaign layer (W01): AA threat level with
## decaying modifiers, team XP, roster, mission history. Saved to user://.
extends Node

signal threat_changed(effective: float)

const DEFAULT_SAVE_PATH := "user://campaign.cfg"
const TEST_SAVE_PATH := "user://campaign_test.cfg"
const BASE_THREAT: float = 0.35

## Resolved in _ready() BEFORE load_campaign(). The headless suite passes
## `-- --test-save` so tests can never touch the player's real campaign
## (test_campaign_state / test_xp_spend / test_squad / test_firebase_sim /
## test_huey_ride all call reset_campaign(), and test_full_loop runs three
## real missions to debrief).
var save_path: String = DEFAULT_SAVE_PATH

var threat_level: float = BASE_THREAT
var threat_modifiers: Array = []  ## [{delta: float, missions_left: int, reason: String}]
var team_xp: int = 0
var roster: Array = []            ## SquadMember dicts (W14)
var missions_played: int = 0
var mission_log: Array = []       ## trimmed result dicts
var iron_man: bool = false
var player_data: Dictionary = {"mos": "RIFLEMAN", "st": 100, "ag": 100, "al": 100, "skills": {}}
var intel_points: int = 0  ## W80: looted docs/captures sharpen the next briefing


func player_skill(skill: String) -> int:
	return int((player_data.get("skills", {}) as Dictionary).get(skill, 0))


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
	threat_changed.emit(effective_threat())


## Called by GameFlow at debrief time (W02 plumbing).
func on_mission_end(result: Dictionary) -> void:
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
	# ANTI-AA payoff (W03): completing an ANTI-AA op, or killing AA opportunistically (W04).
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
	threat_changed.emit(effective_threat())
	save_campaign()


func save_campaign() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("campaign", "threat_level", threat_level)
	cfg.set_value("campaign", "threat_modifiers", threat_modifiers)
	cfg.set_value("campaign", "team_xp", team_xp)
	cfg.set_value("campaign", "roster", roster)
	cfg.set_value("campaign", "missions_played", missions_played)
	cfg.set_value("campaign", "mission_log", mission_log)
	cfg.set_value("campaign", "iron_man", iron_man)
	cfg.set_value("campaign", "player_data", player_data)
	cfg.set_value("campaign", "intel_points", intel_points)
	var err: int = cfg.save(save_path)
	if err != OK:
		push_error("[SAVE] could not write %s (err %d) - campaign progress lost" % [save_path, err])


func load_campaign() -> void:
	var cfg := ConfigFile.new()
	var err: int = cfg.load(save_path)
	if err != OK:
		# ERR_FILE_NOT_FOUND is the normal first-boot path. Anything else means
		# the file exists and is unreadable - say so, don't silently overwrite it.
		if err != ERR_FILE_NOT_FOUND:
			push_error("[SAVE] %s exists but failed to load (err %d) - starting fresh, existing file will be overwritten on next save" % [save_path, err])
		return
	threat_level = float(cfg.get_value("campaign", "threat_level", BASE_THREAT))
	threat_modifiers = cfg.get_value("campaign", "threat_modifiers", [])
	team_xp = int(cfg.get_value("campaign", "team_xp", 0))
	roster = cfg.get_value("campaign", "roster", [])
	missions_played = int(cfg.get_value("campaign", "missions_played", 0))
	mission_log = cfg.get_value("campaign", "mission_log", [])
	iron_man = bool(cfg.get_value("campaign", "iron_man", false))
	player_data = cfg.get_value("campaign", "player_data", {"mos": "RIFLEMAN", "st": 100, "ag": 100, "al": 100, "skills": {}})
	intel_points = int(cfg.get_value("campaign", "intel_points", 0))


func reset_campaign() -> void:
	threat_level = BASE_THREAT
	threat_modifiers = []
	team_xp = 0
	roster = []
	missions_played = 0
	mission_log = []
	# iron_man is a PLAYER SETTING, not campaign progress. It used to be cleared
	# here, which meant an Iron Man death silently disabled the mode that caused
	# the wipe - the next campaign was not Iron Man unless you re-ticked the box.
	player_data = {"mos": "RIFLEMAN", "st": 100, "ag": 100, "al": 100, "skills": {}}
	intel_points = 0
	save_campaign()
