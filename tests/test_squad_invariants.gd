## test_squad_invariants.gd - Pillar 4 mechanism probe (Summoner ruling 2026-07-19:
## allies walk a bit faster, are not glued to the player, and see the world by the
## same rules the enemy does).
##
## THIS PROBE CANNOT VERIFY SQUAD FEEL. It certifies only that the four mechanisms
## exist and are wired: the speed contract, the hysteresis band, the slot deadzone,
## and weather-responsive ally sight. Whether the squad READS as a living unit is
## the Summoner's eyes, and stays his.
## Run: godot --headless --path . res://tests/test_squad_invariants.tscn
extends Node

const PLAYER := preload("res://scripts/player/player.gd")


func _ready() -> void:
	_run()


func _run() -> void:
	var failures: int = 0
	var ally := AllyBase.new()

	# --- 1. a man must out-walk the man he is following ----------------------
	var walk: float = PLAYER.WALK_SPEED
	if ally.move_speed <= walk:
		print("FAIL: ally move_speed %.2f <= player WALK_SPEED %.2f - cannot keep up" \
			% [ally.move_speed, walk])
		failures += 1

	# --- 2. catch-up closes a gap but never outruns a sprint -----------------
	var top: float = ally.move_speed * AllyBase.CATCHUP_MULT
	if AllyBase.CATCHUP_MULT <= 1.0:
		print("FAIL: CATCHUP_MULT %.2f does not accelerate" % AllyBase.CATCHUP_MULT)
		failures += 1
	if top > PLAYER.SPRINT_SPEED:
		print("FAIL: catch-up top speed %.2f exceeds player SPRINT %.2f - reads as sliding" \
			% [top, PLAYER.SPRINT_SPEED])
		failures += 1

	# --- 3. formation hysteresis: two thresholds, crouch inside the band -----
	if AllyBase.FORMATION_ENTER_SPD <= AllyBase.FORMATION_EXIT_SPD:
		print("FAIL: formation enter %.2f <= exit %.2f - no hysteresis, shape will flip-flop" \
			% [AllyBase.FORMATION_ENTER_SPD, AllyBase.FORMATION_EXIT_SPD])
		failures += 1
	var crouch: float = PLAYER.CROUCH_SPEED
	if crouch >= AllyBase.FORMATION_ENTER_SPD or crouch <= AllyBase.FORMATION_EXIT_SPD:
		print("FAIL: player CROUCH_SPEED %.2f sits on a formation threshold (%.2f/%.2f) - a stealth patrol will oscillate" \
			% [crouch, AllyBase.FORMATION_EXIT_SPD, AllyBase.FORMATION_ENTER_SPD])
		failures += 1
	if walk <= AllyBase.FORMATION_ENTER_SPD:
		print("FAIL: player WALK %.2f never reaches file threshold %.2f - the file shape is unreachable" \
			% [walk, AllyBase.FORMATION_ENTER_SPD])
		failures += 1

	# --- 4. the slot has a deadzone, and catch-up sits outside it ------------
	if ally.follow_distance <= 0.0 or AllyBase.FILE_DEADZONE <= 0.0:
		print("FAIL: slot deadzone is zero - men correct continuously (the fidget bug)")
		failures += 1
	if ally.max_follow_distance <= maxf(ally.follow_distance, AllyBase.FILE_DEADZONE):
		print("FAIL: catch-up trigger %.2f is inside the deadzone - a man would jog in place" \
			% ally.max_follow_distance)
		failures += 1
	if AllyBase.SLOT_TRACK_SPEED <= 0.0:
		print("FAIL: SLOT_TRACK_SPEED %.2f - slot teleports on a shape flip or 180 turn" \
			% AllyBase.SLOT_TRACK_SPEED)
		failures += 1

	# --- 5. ally sight obeys the world, and by the ENEMY's numbers -----------
	# Negative control: if this were still a hardcoded constant, swinging the
	# weather could not move it.
	var saved: float = MissionWeather.sight_mult
	MissionWeather.sight_mult = 1.0
	var clear: float = SightCap.at(null, Vector3.ZERO, Vector3(50, 0, 0))
	MissionWeather.sight_mult = 0.2
	var storm: float = SightCap.at(null, Vector3.ZERO, Vector3(50, 0, 0))
	MissionWeather.sight_mult = saved
	if not (storm < clear):
		print("FAIL: ally sight %.1f in storm vs %.1f clear - sight ignores weather (atmosphere is a player buff)" \
			% [storm, clear])
		failures += 1
	if absf(clear - EnemyBase.SIGHT_CAP_OPEN) > 0.001:
		print("FAIL: ally open sight %.1f != EnemyBase.SIGHT_CAP_OPEN %.1f - the two sides have diverged" \
			% [clear, EnemyBase.SIGHT_CAP_OPEN])
		failures += 1
	if SightCap.jungle_range() >= SightCap.open_range():
		print("FAIL: jungle sight %.1f >= open sight %.1f" \
			% [SightCap.jungle_range(), SightCap.open_range()])
		failures += 1
	# The flat 60m that ignored the world must not survive anywhere in _find_target.
	var src: String = FileAccess.get_file_as_string("res://scripts/allies/ally_base.gd")
	if src.contains("var closest_dist: float = 60.0"):
		print("FAIL: ally_base still carries the flat 60m acquisition ceiling")
		failures += 1

	ally.free()
	if failures == 0:
		print("PASS: squad invariants OK (mechanisms only - FEEL is the Summoner's ruling)")
	else:
		print("FAIL: squad invariants had %d failure(s)" % failures)
	get_tree().quit(1 if failures > 0 else 0)
