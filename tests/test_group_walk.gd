extends Node
## GroupWalk wiring probe. Asserts a household exists, shares one lead, walks in
## formation to a shared destination, promotes on the lead's death, and scatters
## when the members go reactive. Negative control: identically-scheduled SOLO
## civilians (group_id = -1) must NOT tighten into formation.
## Run: godot --headless --path . res://tests/test_group_walk.tscn

const CivScript := preload("res://scripts/world/civilian.gd")
const GenScript := preload("res://scripts/missions/mission_generator.gd")

const DEST := Vector3(60, 0, 0)
const FRAMES: int = 600
const DT: float = 1.0 / 60.0

var _fail: int = 0


func _ready() -> void:
	call_deferred("_run")


func _make(pos: Vector3, occ: String) -> Civilian:
	var c: Civilian = CivScript.new()
	c.occupation = occ
	c.home = Vector3(0, 0, 0)
	c.working_point_pos = DEST
	add_child(c)
	c.global_position = pos
	c.build_bt()
	return c


## Drive the schedule by hand: walk_paddy every frame, target = DEST. This keeps
## the probe independent of SimClock's wall time. last_pick_hour must be pinned
## to the CURRENT hour or _bt_tick's rollover refresh overwrites the hand-set
## action with whatever the farmer template says at wall time.
func _drive(civs: Array, frames: int) -> void:
	var clock: Node = get_node_or_null(^"/root/SimClock")
	var hour: float = float(clock.sim_hour) if clock != null else 12.0
	for _f in range(frames):
		for x in civs:
			var c: Civilian = x as Civilian
			if c.state != CivScript.CivState.WANDER:
				continue
			c._bt_bb["last_pick_hour"] = hour
			c._bt_bb["scheduled_action"] = &"walk_paddy"
			c._bt_bb["target_pos"] = DEST
			c._bt_tick(DT)
			c.velocity.y = 0.0
			c.global_position += c.velocity * DT


func _spread(civs: Array) -> float:
	var worst: float = 0.0
	for a in civs:
		for b in civs:
			worst = maxf(worst, (a as Civilian).global_position.distance_to(
				(b as Civilian).global_position))
	return worst


func _centroid(civs: Array) -> Vector3:
	var s := Vector3.ZERO
	for c in civs:
		s += (c as Civilian).global_position
	return s / float(civs.size())


func _check(ok: bool, msg: String) -> void:
	if ok:
		print("  PASS: %s" % msg)
	else:
		print("  FAIL: %s" % msg)
		_fail += 1


func _run() -> void:
	print("=== GROUP WALK ===")

	# 1. The spawn path partitions villagers into households.
	var pool: Array[Civilian] = []
	for i in range(5):
		pool.append(_make(Vector3(float(i) * 3.0, 0, 0), "farmer"))
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	GenScript._assign_households(pool, rng)
	var grouped: Array = []
	for c in pool:
		if c.group_id >= 0:
			grouped.append(c)
	_check(grouped.size() >= 2, "a household exists (%d of 5 villagers grouped)" % grouped.size())
	var fam: Array = []
	for c in grouped:
		if (c as Civilian).group_id == 0:
			fam.append(c)
	_check(fam.size() >= 2, "household 0 has %d members" % fam.size())

	var leads: int = 0
	for c in fam:
		if (c as Civilian).is_group_lead:
			leads += 1
	_check(leads == 1, "exactly one lead in the household (%d)" % leads)
	_check((fam[0] as Civilian).home == (fam[1] as Civilian).home,
		"members share a home")
	_check((fam[0] as Civilian).working_point_pos == (fam[1] as Civilian).working_point_pos,
		"members share a working point (a shared destination)")

	# 2. POSITIVE: they walk together and arrive together. Measure CLOSURE on the
	# paddy, not raw displacement - the formation contracts as it forms up, and
	# that contraction cancels most of the lead's advance in a centroid delta.
	var d0: float = _centroid(fam).distance_to(DEST)
	_drive(fam, FRAMES)
	var moved: float = d0 - _centroid(fam).distance_to(DEST)
	var fam_spread: float = _spread(fam)
	_check(moved > 5.0, "the household closed %.1fm on the paddy" % moved)
	_check(fam_spread < 6.0, "the household stayed together (max spread %.1fm)" % fam_spread)
	var acted: bool = true
	for c in fam:
		if (c as Civilian).active_action != &"walk_group":
			acted = false
	_check(acted, "every member reports active_action = walk_group")

	# 3. NEGATIVE CONTROL: the same men, same schedule, same destination, but
	# solo. If these also converge, the test above proves nothing.
	var solo: Array = []
	for i in range(3):
		solo.append(_make(Vector3(float(i) * 3.0, 0, 40.0), "farmer"))
	var solo_start: float = _spread(solo)
	var solo_d0: float = _centroid(solo).distance_to(DEST)
	_drive(solo, FRAMES)
	var solo_spread: float = _spread(solo)
	var solo_moved: float = solo_d0 - _centroid(solo).distance_to(DEST)
	# Proves the control is LIVE: these men walk the same distance on the same
	# schedule. Only the formation is absent.
	_check(solo_moved > 5.0, "solo civilians still walk (%.1fm closed)" % solo_moved)
	var solo_grouped: bool = false
	for c in solo:
		if (c as Civilian).active_action == &"walk_group":
			solo_grouped = true
	_check(not solo_grouped, "solo civilians never enter walk_group")
	_check(solo_spread >= solo_start - 0.5,
		"solo civilians do NOT form up (spread %.1fm -> %.1fm)" % [solo_start, solo_spread])

	# 4. Lead dies -> the household promotes a living member.
	var old_lead: Civilian = GroupWalk.lead_of(fam)
	old_lead.state = CivScript.CivState.GONE
	var new_lead: Civilian = GroupWalk.lead_of(fam)
	_check(new_lead != null and new_lead != old_lead,
		"a dead lead is replaced by a living member")
	old_lead.state = CivScript.CivState.WANDER
	old_lead.is_group_lead = false

	# 5. SCATTER: reactive states win. A fleeing member leaves the party, so the
	# survivors cannot hold formation on him.
	for c in fam:
		(c as Civilian).state = CivScript.CivState.FLEE
	var party: Array = (fam[0] as Civilian)._group_party()
	_check(party.is_empty(), "a fleeing household has no party (%d members)" % party.size())
	var held: bool = (fam[0] as Civilian)._group_walk_apply()
	_check(not held, "group walk yields to FLEE")

	if _fail > 0:
		print("=== GROUP WALK FAILED (%d) ===" % _fail)
		get_tree().quit(1)
		return
	print("=== GROUP WALK OK ===")
	get_tree().quit(0)
