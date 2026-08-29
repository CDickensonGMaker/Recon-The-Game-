## sleep_station.gd - THE RACK. Sleep is how a run ends (Summoner, 2026-08-28, extending his
## own 2026-07-30 sleep-loop decree).
##
## HIS WORDS: "i think we add the sleeping mechanic and thats how you finish a run or
## something and during the sleep part is when we get read off the names of those who died.
## that way were keeping the player from potentially being attacked and its stopping them to
## read off names."
##
## WHAT THIS IS NOT: a save point, a shrine, or a place he can be locked out of. If his rack
## is rubble or he is nowhere near it, he can still sack out where he stands - it just is not
## his rack. A run-ender he can be denied would be a fail-state, and Pillar 5 forbids those.
##
## HIS RACK, NOT ANY COT (War Room 2026-08-28). `GameFlow.player_rack` is the authored
## `spawn_bunk_*` marker he was seated on at boot - the same place, every time, so the run
## starts where it ends. The 68 `prop_sleep` cots in fsb_main_v3 are deliberately NOT
## stations: half of them sit in hooch visuals with no collision body under them, and a
## verb offered on all 68 would be a verb that drops him through the floor on most of them.
class_name SleepStation
extends RefCounted

## How close to the marker counts as being at his rack. Matches the prompt's range exactly -
## the prompt/verb contract (player.gd) forbids a line that promises what will not fire.
const RACK_REACH_M: float = 2.5

## Hours a sleep advances the clock. HIS NUMBER, verbatim from 2026-07-30: "itll advance the
## clock 8 hours forward."
const SLEEP_HOURS: float = 8.0

## If the night comes for him he does not sleep it through. He goes under and is SHAKEN AWAKE
## in the dark with the siren already going - so the clock moves only this far.
const WAKE_HOURS: float = 3.5

## Nobody sacks out with enemy this close to him. Not a combat-lock (the game has none and
## should not grow one) - a legibility gate, so the verb can never be the thing that skips a
## fight the player is standing in.
const NO_SLEEP_ENEMY_M: float = 90.0


## The rack position, or ZERO if this world authored none.
static func rack_pos() -> Vector3:
	return GameFlow.player_rack


## Is he at his own rack right now?
static func at_rack(player: Node3D) -> bool:
	var r: Vector3 = rack_pos()
	if r == Vector3.ZERO or player == null or not is_instance_valid(player):
		return false
	return player.global_position.distance_to(r) <= RACK_REACH_M


## Why he cannot sleep, or "" if he can. THE PROMPT REFUSES WITH A REASON - a dead prompt
## teaches nothing, and a verb that silently does nothing reads as a bug (r4bk law).
static func refusal(player: Node3D) -> String:
	var d: FieldDirector = _director()
	if d == null or not is_instance_valid(d):
		return "NOT HERE"
	# THE DEMO IS ONE AUTHORED DAY and its arc runs on accumulated REAL seconds
	# (demo_game.gd `_clock`, PROBE_AT_S 1395 / SIEGE_AT_S 1440), which a sim-clock jump
	# cannot move. A verb whose whole job is ending the day would only desync sim-hour from
	# the authored beat and re-arm the fire-support allotment the 20x night was bought to
	# protect (demo_game.gd:50-56). Same one-line shape as siege_director.gd's demo guard.
	if GameFlow.demo_mode:
		return "NOT TONIGHT - THE DAY ISN'T DONE"
	if d.siege != null and is_instance_valid(d.siege) and d.siege.active:
		# A mid-siege bank would reset MissionState with 45 men on the wire and fly a
		# replacement lift into a running assault. It would also be the one thing this
		# verb must never be: a way to skip a fight he is standing in.
		return "NOT WHILE THEY'RE ON THE WIRE"
	if d.patrol_out:
		return "NOT OUT HERE - GET BACK INSIDE THE WIRE"
	var hs: Node = player.get("health_system") as Node if player != null else null
	if hs != null and is_instance_valid(hs) and bool(hs.get("is_downed")):
		# Sleep is not a way to heal through a death.
		return "YOU'RE IN NO SHAPE"
	if _enemy_near(player):
		return "NOT WITH THEM THIS CLOSE"
	return ""


## The [F] line. Empty when he is nowhere near a rack - the verb does not exist out in the AO.
static func prompt(player: Node3D) -> String:
	if not at_rack(player):
		return ""
	var why: String = refusal(player)
	if not why.is_empty():
		return "[F] %s" % why
	# HOLD, NEVER TAP. An accidental tap that ends a run is the worst bug this verb can ship,
	# and the consequence is stated in the prompt itself because r4bk means the affordance
	# names what it DOES (War Room 2026-08-28, UX lens).
	return "[HOLD F] SACK OUT - ENDS THE PATROL"


static func can_sleep(player: Node3D) -> bool:
	return at_rack(player) and refusal(player).is_empty()


static func _director() -> FieldDirector:
	var t: SceneTree = Engine.get_main_loop() as SceneTree
	if t == null:
		return null
	return t.get_first_node_in_group("mission_director") as FieldDirector


static func _enemy_near(player: Node3D) -> bool:
	var t: SceneTree = Engine.get_main_loop() as SceneTree
	if t == null or player == null or not is_instance_valid(player):
		return false
	var here: Vector3 = player.global_position
	for n in t.get_nodes_in_group("enemies"):
		var e := n as Node3D
		if e == null or not is_instance_valid(e):
			continue
		if e.has_method("is_dead") and bool(e.call("is_dead")):
			continue
		if e.global_position.distance_to(here) <= NO_SLEEP_ENEMY_M:
			return true
	return false
