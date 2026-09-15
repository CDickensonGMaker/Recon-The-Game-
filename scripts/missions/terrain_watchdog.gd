## terrain_watchdog.gd - Re-seats bodies that fall through the terrain, and
## freezes physics+brain on NPCs past SUSPEND_DIST (they cannot see or hear
## you from there anyway).
class_name TerrainWatchdog
extends Node

const POLL_SECONDS: float = 2.0
const UNDER_DEPTH: float = 5.0
const SUSPEND_DIST: float = 240.0
const RESUME_DIST: float = 210.0  # hysteresis

## Bodies visited per physics tick. One pass over ~100 men takes ~9 ticks (0.15 s at 60 Hz),
## well inside POLL_SECONDS; the whole-list scan was the worst physics step of a quiet walk
## (58.1 ms, his 2026-09-14 log) because every live man cost a floor_y ray in one step.
const SLICE_MAX: int = 12
## A woken civilian whose schedule moved while he slept is stood at his post only when the
## walk he missed is longer than this; nearer than that he just walks.
const WAKE_SNAP_M: float = 30.0

const RESEAT_REPORT_MAX: int = 20

## Suspended men as of the last completed pass - the third ring's census figure.
static var asleep: int = 0

var world: GameWorld
var _timer: float = 0.0
var _reseats: int = 0
var _queue: Array[Node] = []
var _cursor: int = 0
var _pass_asleep: int = 0


func setup(game_world: GameWorld) -> void:
	world = game_world


## Ledger span for this script's whole physics step - the 2026-09-11 audit read 100+ of 150
## physics steps over 20 ms mid-assault with the named spans summing to ~3 ms of them.
## The step name is per script on purpose: a shared virtual name would let a subclass's
## body be dispatched from its parent's wrapper.
func _physics_process(delta: float) -> void:
	StallLedger.begin("phys.terrain_watchdog")
	_physics_step_terrain_watchdog(delta)
	StallLedger.end()


func _physics_step_terrain_watchdog(delta: float) -> void:
	if world == null:
		return
	_timer += delta
	if _cursor >= _queue.size():
		if _timer < POLL_SECONDS:
			return
		_timer = 0.0
		_queue.clear()
		for group in ["enemies", "allies", "civilians"]:
			_queue.append_array(get_tree().get_nodes_in_group(group))
		_cursor = 0
		_pass_asleep = 0
	var player := GameManager.player as Node3D
	var stop: int = mini(_queue.size(), _cursor + SLICE_MAX)
	while _cursor < stop:
		var node: Node = _queue[_cursor]
		_cursor += 1
		# The snapshot outlives a man freed mid-pass; the cast itself faults on a freed object.
		if not is_instance_valid(node):
			continue
		var body := node as CharacterBody3D
		if body == null:
			continue
		if body.has_method("is_dead") and body.is_dead():
			continue
		# A parked (dormant) man or one whose physics somebody ELSE turned off - a rider glued
		# to a seat - is not this ring's to sleep, wake or re-seat.
		if not body.can_process() \
				or (not body.has_meta("suspended") and not body.is_physics_processing()):
			continue
		_visit(body, player)
	if _cursor >= _queue.size():
		asleep = _pass_asleep


func _visit(body: CharacterBody3D, player: Node3D) -> void:
	if player != null and not _exempt(body, player):
		var dist: float = body.global_position.distance_to(player.global_position)
		var suspended: bool = body.has_meta("suspended")
		if not suspended and dist > SUSPEND_DIST:
			body.set_meta("suspended", true)
			body.set_physics_process(false)
			body.visible = false
			_pass_asleep += 1
			return
		elif suspended and dist < RESUME_DIST:
			_resume(body)
		elif suspended:
			_pass_asleep += 1
			return
	elif body.has_meta("suspended"):
		_resume(body)
	# Fall-through re-seat. floor_y for the reason spelled out at _resume: this branch
	# runs every 2s on every live body, so surface_y here re-roofs a man forever,
	# no matter how clean his spawn was.
	var ground_y: float = world.floor_y(body.global_position)
	if body.global_position.y < ground_y - UNDER_DEPTH:
		# Counted, not silent: a live man being teleported is either a real
		# fall-through or this branch mis-reading a floor, and the two are
		# indistinguishable without the number.
		_reseats += 1
		if _reseats <= RESEAT_REPORT_MAX:
			print("[WATCHDOG] re-seat #%d: %s %+.1fm to %.1f" % [
				_reseats, body.name, ground_y + 0.5 - body.global_position.y, ground_y + 0.5])
		body.global_position.y = ground_y + 0.5
		body.velocity = Vector3.ZERO


## Never suspended: the player's own squad (it follows orders far from him - an ambient
## friendly patrol is not his and must LOD like anyone else), a sapper (he IS the siege),
## and a man in COMBAT inside the sticky ceiling (the ADR-005 witness chain must finish).
func _exempt(body: CharacterBody3D, player: Node3D) -> bool:
	var ally := body as AllyBase
	if ally != null:
		return ally.squad_member
	var enemy := body as EnemyBase
	if enemy == null:
		return false
	if enemy.silent_infiltrator:
		return true
	return enemy.alert_tier == EnemyBase.AlertTier.COMBAT \
		and enemy.global_position.distance_to(player.global_position) <= AILod.STICKY_MAX_M


func _resume(body: CharacterBody3D) -> void:
	body.remove_meta("suspended")
	body.set_physics_process(true)
	# A spider-hole ambusher must STAY hidden until he triggers at 7m:
	# never blanket-restore visible on resume.
	var hidden_hole: bool = body.get("is_spider_hole") and not body.get("_spider_triggered")
	body.visible = not hidden_hole
	# floor_y(), not surface_y(): surface_y probes from high above and takes
	# the FIRST hit, which under a roof is the roof - this is the one path
	# that actively teleports a live man onto one. floor_y probes from just
	# above him and still falls back to surface_y outdoors, so the
	# one-ground law is unchanged where there is nothing overhead.
	body.global_position.y = world.floor_y(body.global_position) + 0.5
	var civ := body as Civilian
	if civ != null:
		_wake_snap(civ)


## A sleeping civilian ticks no schedule, so the hour moves past his post while he stands
## where he fell asleep. If the schedule's answer changed and nobody can see him, he is
## stood at the post (the civilian's own LOD_FAR wake does the same at 300 m - a ring the
## watchdog's 240 m sleep never lets it reach).
func _wake_snap(civ: Civilian) -> void:
	# A man who never ticked stands himself at his post on his first tick (and a replacement
	# is only handed his bunk after it); a puppet or a boarding man is somebody else's.
	if civ.scheduled_action() == &"" or civ.puppet or civ.board_target != Vector3.ZERO:
		return
	var due: StringName = CivilianSchedules.action_for(civ.occupation, SimClock.sim_hour,
		String(civ.name))
	if due == civ.scheduled_action() or CombatManager.perceivable(civ):
		return
	var from: Vector3 = civ.global_position
	civ.place_for_current_hour()
	if from.distance_to(civ.global_position) <= WAKE_SNAP_M:
		civ.global_position = from
