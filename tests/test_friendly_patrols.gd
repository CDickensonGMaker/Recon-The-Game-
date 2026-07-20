## test_friendly_patrols.gd - ambient US patrols exist, walk, and call for help.
##
## The AO had exactly one friendly combat element (the player's squad), so
## &"friendly_patrol_pinned" (dynamic_mission_factory.gd:17) was a mapped state
## with no producer. This probe covers the producer AND the r4bk delivery path.
##
## Every assertion carries a negative control - the condition inverted - because a
## test that passes against both the fix and its absence proves nothing.
## Run: godot --headless --path . res://tests/test_friendly_patrols.tscn
extends Node

const FactoryScript := preload("res://scripts/missions/dynamic_mission_factory.gd")
const PatrolScript := preload("res://scripts/missions/friendly_patrol_group.gd")

var _failures: int = 0
var _toasts: Array[String] = []


func _ready() -> void:
	_check_us_side_not_squad()
	_check_they_move()
	_check_break_authority_shared()
	_check_pinned_fires_once()
	_check_no_call_when_healthy()
	_check_no_call_without_contact()
	_check_one_caller_at_a_time()
	_check_reaches_player()
	_check_off_the_net_is_silent()
	_check_foe_ratio_is_local()
	_check_ambient_patrol_lods()
	if _failures == 0:
		print("test_friendly_patrols: PASS")
	else:
		print("test_friendly_patrols: %d FAILURES" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


func _fail(msg: String) -> void:
	print("FAIL: ", msg)
	_failures += 1


func _on_toast(text: String) -> void:
	_toasts.append(text)


## A patrol with its men already standing. Built by hand rather than through
## GameFlow: GameFlow._ready() already starts the default operation
## (game_flow.gd:27), so a probe that also begins one builds TWO worlds and
## doubles every population count.
func _make_patrol(men: int, at: Vector3 = Vector3(300, 0, 300)) -> FriendlyPatrolGroup:
	PatrolScript.clear_static()
	var fp: FriendlyPatrolGroup = PatrolScript.new()
	fp.enemy_count = men
	fp.spread = 3.0
	fp.group_tag = "friendly_patrol_test"
	fp.setup(null, 1234)
	add_child(fp)
	fp.global_position = at
	fp._spawn_men()
	fp._spawned = true
	return fp


## They are US-side and armed, but they are not HIS - not in SquadSystem.members
## and not taking the squad's follow order.
func _check_us_side_not_squad() -> void:
	var fp := _make_patrol(4)
	if fp.living_count() != 4:
		_fail("patrol spawned %d men, wanted 4" % fp.living_count())
	var ss := SquadSystem.new()
	add_child(ss)
	for man in fp._men:
		var a: AllyBase = man
		if not a.is_in_group("allies"):
			_fail("a friendly patrolman is not in group 'allies' - the player's bullets would not know him")
		if a.squad_member:
			_fail("a friendly patrolman reports squad_member = true")
		if ss.members.has(a):
			_fail("a friendly patrolman entered SquadSystem.members")
		if a.order_mode == AllyBase.OrderMode.FOLLOW:
			_fail("a friendly patrolman is on FOLLOW - he is in the player's follow chain")
		if str(a.member.get("name", "")).is_empty():
			_fail("a friendly patrolman has no roster identity - the nameplate cannot name him")
	# NEGATIVE CONTROL: a man spawned the ordinary way MUST still default to the
	# squad's follow chain, or this probe is passing because allies never follow.
	var plain: AllyBase = AllyBase.spawn_ally(self, Vector3.ZERO)
	if not plain.squad_member:
		_fail("NEGATIVE CONTROL: a plain ally defaulted to squad_member = false")
	if plain.order_mode != AllyBase.OrderMode.FOLLOW:
		_fail("NEGATIVE CONTROL: a plain ally did not default to FOLLOW")
	plain.queue_free()
	ss.queue_free()
	fp.queue_free()


## They walk. The element steps to the next leg when its lead reaches the current
## one - the route is not decoration.
func _check_they_move() -> void:
	var fp := _make_patrol(3, Vector3(100, 0, 100))
	fp.route = [Vector3(100, 0, 100), Vector3(160, 0, 100), Vector3(160, 0, 160)]
	fp._wp = 0
	# The lead is standing ON waypoint 0, so the element must advance to 1.
	fp._men[0].global_position = Vector3(100, 0, 100)
	fp._advance_route()
	if fp._wp != 1:
		_fail("patrol did not advance to the next leg on arrival (wp = %d)" % fp._wp)
	for man in fp._men:
		var a: AllyBase = man
		if a.order_pos != fp.route[1]:
			_fail("a patrolman was not re-ordered onto the new leg")
	# NEGATIVE CONTROL: a lead far from the waypoint must NOT advance the leg, or
	# the element would teleport through its route regardless of walking.
	var before: int = fp._wp
	fp._men[0].global_position = Vector3(0, 0, 0)
	fp._advance_route()
	if fp._wp != before:
		_fail("NEGATIVE CONTROL: patrol advanced its leg without anyone reaching it")
	fp.queue_free()


## ONE break authority. The patrol must AGREE with EnemySquad.break_state for the
## same inputs - not carry a second copy of the threshold.
func _check_break_authority_shared() -> void:
	var src: String = FileAccess.get_file_as_string(
		"res://scripts/missions/friendly_patrol_group.gd")
	if not src.contains("EnemySquad.break_state("):
		_fail("the patrol does not call EnemySquad.break_state - that is a second break copy")
	if src.contains("BREAK_RATIO") and not src.contains("EnemySquad.BREAK_RATIO"):
		_fail("the patrol names its own break threshold")
	# Behavioral, not textual: drive a real patrol across the boundary and confirm
	# the flag matches the shared authority at the same live/peak.
	var fp := _make_patrol(4)
	fp._last_contact_ms = float(Time.get_ticks_msec())
	for man in fp._men:
		(man as AllyBase).courage = 0.5
	# 4/4 = 1.0 -> holds.
	fp._break_ms = -1e9
	fp._update_break()
	if EnemySquad.break_state(4, 4, 0.5).broken:
		_fail("authority says a full element breaks - the fixture is wrong")
	if fp._men[0].squad_broken:
		_fail("a full-strength patrol reported broken")
	# Kill 3 of 4: 1/4 = 0.25 < 0.45 -> breaks, on the shared rule.
	for i in range(3):
		(fp._men[i] as AllyBase).current_state = Enums.AIState.DEAD
	fp._break_ms = -1e9
	fp._update_break()
	if not EnemySquad.break_state(1, 4, 0.5).broken:
		_fail("authority says a quarter-strength element holds - the fixture is wrong")
	if not fp._men[3].squad_broken:
		_fail("a patrol at 25%% strength did not break on the shared authority")
	fp.queue_free()


## A rig with just enough world to answer the radio and carry a toast.
func _rig(rto_dist: float) -> FieldDirector:
	for prior in get_tree().get_nodes_in_group("mission_director"):
		prior.remove_from_group("mission_director")
	var d := FieldDirector.new()
	add_child(d)
	d.add_to_group("mission_director")
	var w := GameWorld.new()
	add_child(w)
	var pl := CharacterBody3D.new()
	w.add_child(pl)
	pl.global_position = Vector3(500, 0, 0)
	w.player = pl
	d.world = w
	var ss := SquadSystem.new()
	add_child(ss)
	var rto := AllyBase.new()
	ss.add_child(rto)
	rto.member = {"mos": "RTO", "nick": "SPARKS"}
	rto.global_position = pl.global_position + Vector3(rto_dist, 0, 0)
	ss.members.append(rto)
	d.squad_system = ss
	d.patrol_gate_pos = Vector3.ZERO
	d.patrol_gate_out = Vector3.FORWARD
	d.patrol_out = true
	_toasts.clear()
	d.toast.connect(_on_toast)
	return d


## Drive a patrol to broken-and-in-contact and count the emissions.
func _pin(fp: FriendlyPatrolGroup) -> void:
	fp._last_contact_ms = float(Time.get_ticks_msec())
	for i in range(fp._men.size() - 1):
		(fp._men[i] as AllyBase).current_state = Enums.AIState.DEAD
	fp._break_ms = -1e9
	fp._update_break()


func _check_pinned_fires_once() -> void:
	var d := _rig(1.0)
	var f: DynamicMissionFactory = FactoryScript.new()
	add_child(f)
	MissionGenerator.dynamic_factory_ref = f
	var fp := _make_patrol(4)
	_pin(fp)
	if not fp.is_pinned():
		_fail("a broken patrol in contact did not report pinned")
	var got: int = d.patrol_locations.size()
	if got != 1:
		_fail("pinned raised %d locations, wanted exactly 1" % got)
	if str(d.patrol_locations[0].get("kind", "")) != "pinned_patrol":
		_fail("the pinned call did not arrive as kind 'pinned_patrol'")
	# The _seen dedupe: hammering the condition must not re-offer the same element.
	for i in range(5):
		fp._break_ms = -1e9
		fp._update_break()
	if d.patrol_locations.size() != 1:
		_fail("the same patrol called for help %d times" % d.patrol_locations.size())
	# ISOLATION: the assertion above passes on DynamicMissionFactory._seen alone,
	# so it cannot see the patrol's OWN latch. Wipe the factory's memory and drive
	# the condition again - anything emitted now came from this element re-calling.
	f._seen.clear()
	for i in range(5):
		fp._break_ms = -1e9
		fp._update_break()
	if d.patrol_locations.size() != 1:
		_fail("the patrol re-called with the factory's dedupe cleared - it has no latch of its own")
	f.queue_free()
	fp.queue_free()
	d.queue_free()


## NEGATIVE CONTROL for the whole feature: a patrol that is FINE says nothing.
func _check_no_call_when_healthy() -> void:
	var d := _rig(1.0)
	var f: DynamicMissionFactory = FactoryScript.new()
	add_child(f)
	MissionGenerator.dynamic_factory_ref = f
	var fp := _make_patrol(4)
	fp._last_contact_ms = float(Time.get_ticks_msec())
	for i in range(6):
		fp._break_ms = -1e9
		fp._update_break()
	if fp.is_pinned():
		_fail("NEGATIVE CONTROL: a full-strength patrol reported itself pinned")
	if d.patrol_locations.size() != 0:
		_fail("NEGATIVE CONTROL: a healthy patrol raised %d crises" % d.patrol_locations.size())
	f.queue_free()
	fp.queue_free()
	d.queue_free()


## NEGATIVE CONTROL: attrition WITHOUT contact is not a call for help. A patrol
## that walked into a minefield is not pinned, and must not summon the player.
func _check_no_call_without_contact() -> void:
	var d := _rig(1.0)
	var f: DynamicMissionFactory = FactoryScript.new()
	add_child(f)
	MissionGenerator.dynamic_factory_ref = f
	var fp := _make_patrol(4)
	fp._last_contact_ms = -1e9   # nobody has seen an enemy
	for i in range(fp._men.size() - 1):
		(fp._men[i] as AllyBase).current_state = Enums.AIState.DEAD
	for i in range(6):
		fp._break_ms = -1e9
		fp._update_break()
	if fp.is_pinned():
		_fail("NEGATIVE CONTROL: a patrol broken with no enemy contact reported pinned")
	if d.patrol_locations.size() != 0:
		_fail("NEGATIVE CONTROL: attrition alone raised a crisis")
	f.queue_free()
	fp.queue_free()
	d.queue_free()


## PACING: two patrols in trouble at once produce ONE call, not two. Three loud
## rescues in a row is the pacing failure this latch forbids.
func _check_one_caller_at_a_time() -> void:
	var d := _rig(1.0)
	var f: DynamicMissionFactory = FactoryScript.new()
	add_child(f)
	MissionGenerator.dynamic_factory_ref = f
	PatrolScript.clear_static()
	var a := _make_patrol_keep_static(4, Vector3(300, 0, 300))
	var b := _make_patrol_keep_static(4, Vector3(700, 0, 700))
	_pin(a)
	_pin(b)
	if d.patrol_locations.size() != 1:
		_fail("two pinned patrols raised %d crises, wanted 1" % d.patrol_locations.size())
	if a.is_pinned() and b.is_pinned():
		_fail("both patrols held the net at once")
	f.queue_free()
	a.queue_free()
	b.queue_free()
	d.queue_free()


func _make_patrol_keep_static(men: int, at: Vector3) -> FriendlyPatrolGroup:
	var fp: FriendlyPatrolGroup = PatrolScript.new()
	fp.enemy_count = men
	fp.spread = 3.0
	fp.setup(null, 99)
	add_child(fp)
	fp.global_position = at
	fp._spawn_men()
	fp._spawned = true
	return fp


## r4bk: the crisis must reach the PLAYER-VISIBLE layer, not just a data array.
func _check_reaches_player() -> void:
	var d := _rig(1.0)
	var f: DynamicMissionFactory = FactoryScript.new()
	add_child(f)
	MissionGenerator.dynamic_factory_ref = f
	var fp := _make_patrol(4)
	_pin(fp)
	var spoke: bool = false
	for t in _toasts:
		if t.contains("FRIENDLY ELEMENT PINNED"):
			spoke = true
	if not spoke:
		_fail("the pinned call never reached the player - toasts were %s" % str(_toasts))
	if d.patrol_location == Vector3.ZERO:
		_fail("the sweep was never retargeted onto the pinned element")
	f.queue_free()
	fp.queue_free()
	d.queue_free()


## FAIRNESS LAW: off the net, the word is DELAYED, not deleted. Nothing is
## announced, but the location keeps for the next walk-out.
func _check_off_the_net_is_silent() -> void:
	var d := _rig(50.0)   # RTO is 50m away - outside the 10m tether
	var f: DynamicMissionFactory = FactoryScript.new()
	add_child(f)
	MissionGenerator.dynamic_factory_ref = f
	var fp := _make_patrol(4)
	_pin(fp)
	for t in _toasts:
		if t.contains("FRIENDLY ELEMENT PINNED"):
			_fail("off the net, the pinned call was announced anyway")
	if d.patrol_location != Vector3.ZERO:
		_fail("off the net, the sweep was retargeted without the word reaching him")
	if d.patrol_locations.size() != 1:
		_fail("off the net the location was DELETED, not delayed - it must keep")
	f.queue_free()
	fp.queue_free()
	d.queue_free()


## enemy_base.gd:1217 - the foes half of the local force ratio had no distance
## check while its own comment says "Local on purpose". An ambient patrol across
## the AO would have deflated the ratio for every VC in the map.
func _check_foe_ratio_is_local() -> void:
	var e: EnemyBase = EnemyBase.new()
	add_child(e)
	e.global_position = Vector3(200, 0, 200)
	var near: AllyBase = AllyBase.spawn_ally(self, Vector3(210, 0, 200))   # 10m
	var with_near: float = e._local_force_ratio()
	var far: AllyBase = AllyBase.spawn_ally(self, Vector3(600, 0, 600))    # ~565m
	var with_far: float = e._local_force_ratio()
	if not is_equal_approx(with_near, with_far):
		_fail("an ally %dm away changed the LOCAL force ratio (%f -> %f)" % [
			565, with_near, with_far])
	# NEGATIVE CONTROL: a man who IS local must still move the ratio, or this
	# passes because the foes loop counts nobody at all.
	var near2: AllyBase = AllyBase.spawn_ally(self, Vector3(205, 0, 205))
	if is_equal_approx(e._local_force_ratio(), with_near):
		_fail("NEGATIVE CONTROL: an ally 7m away did not change the local force ratio")
	near.queue_free()
	near2.queue_free()
	far.queue_free()
	e.queue_free()


## terrain_watchdog.gd - the ally suspension exemption was written for a squad
## that follows the player. An ambient patrol is not his and must LOD, or it runs
## full AI across the AO (allies are outside EnemySquad's hot-set, enemy_squad.gd:37).
func _check_ambient_patrol_lods() -> void:
	var wd := TerrainWatchdog.new()
	add_child(wd)
	wd.setup(TerrainManager.new())
	var pl := CharacterBody3D.new()
	add_child(pl)
	pl.global_position = Vector3.ZERO
	var prior: Node = GameManager.player
	GameManager.player = pl

	# Both men stand 400m out - well past SUSPEND_DIST (240m).
	var ambient: AllyBase = AllyBase.spawn_ally(self, Vector3(400, 0, 0))
	ambient.squad_member = false
	var squaddie: AllyBase = AllyBase.spawn_ally(self, Vector3(400, 0, 0))
	squaddie.squad_member = true

	wd._timer = TerrainWatchdog.POLL_SECONDS + 1.0
	wd._physics_process(0.016)

	if not ambient.has_meta("suspended"):
		_fail("an ambient patrolman 400m from the player was NOT suspended - he runs full AI across the AO")
	# NEGATIVE CONTROL: the player's own squad must KEEP its exemption. It follows
	# orders far from him, and suspending it would freeze men he sent away.
	if squaddie.has_meta("suspended"):
		_fail("NEGATIVE CONTROL: a squad member was suspended - the squad lost its exemption")

	GameManager.player = prior
	ambient.queue_free()
	squaddie.queue_free()
	pl.queue_free()
	wd.queue_free()
