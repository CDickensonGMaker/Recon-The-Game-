## gun_crew_performance.gd - the staged artillery/mortar crew loop at one pit.
## LitterTeam's driver shape on a fixed position: real garrison Civilians are
## puppeted at their stations and their crew clips re-issued together on one
## clock, because gun_gunner/gun_loader/gun_agunner/gun_ammo_bearer (and the
## mortar trio) are ONE authored scene split per man, not independent loops -
## free-running they drift out of sync within minutes.
##
## The crew are SOLDIERS (ruling 2026-08-04): GarrisonDefender.promote releases
## them through release_man() at stand-to, so the performance never keeps four
## men miming through a ground assault. Membership assembles itself - every
## gun_crew_arty man joins from Civilian.build_bt(), so the crew reforms after a
## dawn stand-down without the spawner knowing this node exists.
class_name GunCrewPerformance
extends Node3D

## Clip seats by distance from the pit center, nearest first. The near marker
## sits 0.3-0.8m off the piece (measured in fsb_main_v3.glb, 2026-08-07); today's
## pits carry 3 markers, so the a-gunner seat waits for a 4-marker export.
const GUN_SEATS: Array[String] = ["gun_gunner", "gun_loader", "gun_ammo_bearer",
	"gun_agunner"]
const MORTAR_SEATS: Array[String] = ["mortar_gunner", "mortar_dropper",
	"mortar_runner"]
## Shortest clip of each set (anim_library.glb, probed 2026-08-07: gun
## 27.300-27.400s, mortar 26.633-26.667s). Restarting on the SHORTEST keeps every
## man cycling; these clips import play-once, and past its end a man freezes.
const GUN_LOOP_S: float = 27.3
const MORTAR_LOOP_S: float = 26.633
## Membership radius. The first registrant anchors the driver on HIS marker, which
## can be an edge station: intra-pit markers span up to 6.8m plus <=1m of spawn
## wobble each side, while the nearest marker of ANY neighbouring pit is >=14.3m
## out (both measured in fsb_main_v3.glb, 2026-08-07). 9.0 swallows the first and
## cannot reach the second.
const PIT_RADIUS: float = 9.0
## The piece stands at the pit center, so its search stays tighter than the join.
const PIECE_SEARCH_M: float = 8.0
## _bt_settle holds a working man up to WORK_JITTER_M + WORK_ARRIVE_M (~3.1m) off
## his marker; capture must reach past that or the crew never assembles.
const CAPTURE_M: float = 3.5
const TICK_S: float = 0.25
## The piece. fsb_main_v3.glb ships STATIC howitzers (0 animations, probed
## 2026-08-07), so this binds nothing until the artillery-placement export lands
## the fb_emplacement_m101 rig near the pit (ART_GAPS_2026-08-07.md).
const PIECE_CLIP: String = "M101Rig"

var kind: String = "gun"
var _members: Array[Civilian] = []
var _captured: Array[Civilian] = []
var _seats: Dictionary = {}
var _playing: bool = false
var _loop_t: float = 0.0
var _tick_t: float = 0.0
var _piece: AnimationPlayer = null
var _piece_extras: Array[AnimationPlayer] = []
var _piece_searched: bool = false


func _ready() -> void:
	add_to_group("gun_crew_performances")


func register_man(civ: Civilian) -> void:
	if civ == null or _members.has(civ):
		return
	_members.append(civ)
	if civ.role == "mortar" or civ.role == "gun":
		kind = civ.role
	var sum: Vector3 = Vector3.ZERO
	var n: int = 0
	for m in _members:
		if m != null and is_instance_valid(m):
			sum += m.working_point_pos
			n += 1
	if n > 0:
		global_position = sum / float(n)


## The one exit every door uses: schedule roll-over, stand-to promotion
## (GarrisonDefender.promote), a hit, death. Never leaves puppet latched.
func release_man(civ: Civilian) -> void:
	_captured.erase(civ)
	_seats.erase(civ)
	if civ != null and is_instance_valid(civ) and civ.state != Civilian.CivState.GONE:
		civ.puppet = false
		civ.crew_driver = null
		civ._last_clip = ""
	if _captured.is_empty():
		_stop_piece()
		_playing = false


func _physics_process(delta: float) -> void:
	_tick_t -= delta
	if _tick_t <= 0.0:
		_tick_t = TICK_S
		_evaluate()
	if not _playing:
		return
	_loop_t += delta
	var period: float = MORTAR_LOOP_S if kind == "mortar" else GUN_LOOP_S
	if _loop_t >= period:
		_loop_t = fmod(_loop_t, period)
		_issue_clips()


func _evaluate() -> void:
	for i in range(_members.size() - 1, -1, -1):
		var m: Civilian = _members[i]
		if m == null or not is_instance_valid(m) or m.state == Civilian.CivState.GONE:
			_members.remove_at(i)
			release_man(m)
		elif _captured.has(m) and m.state != Civilian.CivState.WANDER:
			release_man(m)
	var on_duty: bool = CivilianSchedules.action_for("gun_crew_arty", _sim_hour()) \
		== CivilianSchedules.ACTION_WORK
	if not on_duty:
		_release_all()
		return
	var joined: bool = false
	for m in _members:
		if not _captured.has(m) and _eligible(m):
			_capture(m)
			joined = true
	if _captured.is_empty():
		return
	if joined or not _playing:
		_playing = true
		_loop_t = 0.0
		_assign_seats()
		_issue_clips()


func _release_all() -> void:
	for i in range(_captured.size() - 1, -1, -1):
		release_man(_captured[i])


func _eligible(civ: Civilian) -> bool:
	if civ.puppet or civ.state != Civilian.CivState.WANDER:
		return false
	if civ.board_target != Vector3.ZERO or not civ.is_physics_processing():
		return false
	return Vector2(civ.global_position.x - civ.working_point_pos.x,
		civ.global_position.z - civ.working_point_pos.z).length() <= CAPTURE_M


func _capture(civ: Civilian) -> void:
	civ.puppet = true
	civ.crew_driver = self
	civ.velocity = Vector3.ZERO
	civ.global_position = civ.working_point_pos
	var to: Vector3 = global_position - civ.global_position
	to.y = 0.0
	# The man ON the piece faces downrange with it; everyone else works toward it.
	if to.length() < 1.0:
		to = _downrange()
	if to.length() > 0.05 and civ.actor != null and is_instance_valid(civ.actor):
		civ.actor.set_facing(to.normalized())


func _downrange() -> Vector3:
	var far_wp: Vector3 = global_position
	var best: float = 0.0
	for m in _members:
		if m == null or not is_instance_valid(m):
			continue
		var d: float = Vector2(m.working_point_pos.x - global_position.x,
			m.working_point_pos.z - global_position.z).length()
		if d > best:
			best = d
			far_wp = m.working_point_pos
	var out: Vector3 = global_position - far_wp
	out.y = 0.0
	return out


func _assign_seats() -> void:
	_seats.clear()
	var order: Array[Civilian] = []
	for m in _captured:
		order.append(m)
	order.sort_custom(func(a: Civilian, b: Civilian) -> bool:
		return _anchor_d(a) < _anchor_d(b))
	var seats: Array[String] = MORTAR_SEATS if kind == "mortar" else GUN_SEATS
	for i in range(order.size()):
		_seats[order[i]] = seats[i % seats.size()]


func _anchor_d(civ: Civilian) -> float:
	return Vector2(civ.working_point_pos.x - global_position.x,
		civ.working_point_pos.z - global_position.z).length()


## Every clip lands on frame 0 together - restart is what makes the lock
## (litter_team.gd learned this first).
func _issue_clips() -> void:
	for m in _captured:
		if m == null or not is_instance_valid(m) or m.state == Civilian.CivState.GONE:
			continue
		var clip: String = str(_seats.get(m, ""))
		if clip != "" and m.actor != null and is_instance_valid(m.actor):
			m.actor.play(clip, true)
	_play_piece()


func _play_piece() -> void:
	if kind != "gun":
		return
	if not _piece_searched:
		_bind_piece()
	if _piece == null:
		return
	_piece.play(PIECE_CLIP)
	_piece.seek(0.0, true)
	for x in _piece_extras:
		if not is_instance_valid(x):
			continue
		var clip: String = str(x.get_meta("crew_clip", ""))
		if clip != "":
			x.play(clip)
			x.seek(0.0, true)


func _stop_piece() -> void:
	if _piece != null and is_instance_valid(_piece):
		_piece.stop()
	for x in _piece_extras:
		if is_instance_valid(x):
			x.stop()


## One AnimationPlayer plays ONE animation, and the shell/brass are separate
## animations beside M101Rig in the same import - so they ride sibling players
## sharing the piece's library and root.
func _bind_piece() -> void:
	_piece_searched = true
	var world: Node = get_parent()
	if world == null:
		return
	for n in world.find_children("*", "AnimationPlayer", true, false):
		var p := n as AnimationPlayer
		if p == null or not p.has_animation(PIECE_CLIP):
			continue
		var holder := p.get_parent() as Node3D
		if holder == null:
			continue
		if Vector2(holder.global_position.x - global_position.x,
				holder.global_position.z - global_position.z).length() > PIECE_SEARCH_M:
			continue
		_piece = p
		break
	if _piece == null:
		return
	for nm in _piece.get_animation_list():
		var s: String = String(nm)
		if not s.begins_with("MC_"):
			continue
		var extra := AnimationPlayer.new()
		extra.root_node = _piece.root_node
		for lib in _piece.get_animation_library_list():
			extra.add_animation_library(lib, _piece.get_animation_library(lib))
		extra.set_meta("crew_clip", s)
		_piece.get_parent().add_child(extra)
		_piece_extras.append(extra)


## SimClock is an AUTOLOAD with no class_name (sim_clock.gd:5); 12.0 is the
## out-of-tree fallback for unit tests, same as civilian.gd.
func _sim_hour() -> float:
	var clock: Node = get_node_or_null(^"/root/SimClock")
	if clock == null:
		return 12.0
	return float(clock.sim_hour)
