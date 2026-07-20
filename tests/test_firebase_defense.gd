## test_firebase_defense.gd - the firebase night-defense encounter (war-room decree
## 2026-07-20). Six mechanisms, each with a NEGATIVE CONTROL keyed to the exact
## mutation that must break it - this suite has been burned repeatedly by probes that
## passed against both the fix AND its absence, so every check names what breaks it:
##
##  1. GARRISON PROMOTION is gated on a real assault (2+ on the wire), not a lone
##     wanderer (peacetime control), and a promoted defender RETURNS FIRE.
##  2. A sapper's per-unit stealth makes him harder to spot at night than a normal
##     soldier at the SAME range, and a flare over him restores the pickup.
##  3. The assault carries a LOUD charging element behind the SILENT sappers.
##  4. A breach docks the live mortars AND shorts the NEXT allotment across a
##     save/load round-trip (persistent), consumed once.
##  5. The firebase crisis RE-FIRES on a genuinely new wave (control: the old
##     constant key fires once), without spamming within a wave.
##  6. Killing the RTO mid-call kicks the player off the net THIS frame.
##
## Run: godot --headless --path . res://tests/test_firebase_defense.tscn
extends Node3D

const CivScript := preload("res://scripts/world/civilian.gd")
const FactoryScript := preload("res://scripts/missions/dynamic_mission_factory.gd")
const SAPPER_DATA := "res://data/enemies/vc_sapper.tres"
const NORMAL_DATA := "res://data/enemies/nva_regular.tres"

var _failures: int = 0


## A stub player carrying just the net seam: set_on_net is the single truth, and it
## mirrors to the director exactly as the real player.gd does (never the reverse).
class StubPlayer extends CharacterBody3D:
	var holding_handset: bool = false
	var director: FieldDirector = null
	func set_on_net(want: bool) -> void:
		if want == holding_handset:
			return
		holding_handset = want
		if director != null and is_instance_valid(director):
			director.set_fire_menu_mirror(want)


func _ready() -> void:
	MissionWeather.sight_mult = 1.0
	SimClock.paused = true
	call_deferred("_run")


func _run() -> void:
	print("=== PROBE: FIREBASE NIGHT DEFENSE ===")
	await _check_promotion_gate()
	await _check_defender_returns_fire()
	await _check_sapper_stealth()
	_check_assault_is_coordinated()
	_check_silence_invariant()
	await _check_breach_cost_and_persistence()
	await _check_crisis_refires()
	await _check_rto_kick()
	print("")
	if _failures == 0:
		print("test_firebase_defense: PASS")
		get_tree().quit(0)
	else:
		push_error("FIREBASE DEFENSE: %d assertion(s) failed." % _failures)
		print("test_firebase_defense: %d FAILURES" % _failures)
		get_tree().quit(1)


func _expect(ok: bool, what: String) -> void:
	print(("  PASS  " if ok else "  FAIL  ") + what)
	if not ok:
		_failures += 1


# ---------------------------------------------------------------- helpers

func _bare_director(center: Vector3) -> FieldDirector:
	for prior in get_tree().get_nodes_in_group("mission_director"):
		prior.remove_from_group("mission_director")
	var d := FieldDirector.new()
	add_child(d)
	d.add_to_group("mission_director")
	var w := GameWorld.new()
	add_child(w)
	w.terrain_manager = null
	var pl := StubPlayer.new()
	pl.director = d
	w.add_child(pl)
	pl.global_position = center
	w.player = pl
	d.world = w
	var ss := SquadSystem.new()
	add_child(ss)
	var rto := AllyBase.new()
	ss.add_child(rto)
	rto.member = {"mos": "RTO", "nick": "SPARKS", "name": "Doyle"}
	rto.global_position = pl.global_position
	ss.members.append(rto)
	d.squad_system = ss
	d.fsb_center = center
	d._sapper_aim = center + Vector3(0, 0, 8)
	d.patrol_gate_pos = center + Vector3(0, 0, 60)
	d.patrol_gate_out = Vector3.BACK
	return d


func _spawn_garrison(parent: Node, pos: Vector3) -> Civilian:
	var civ: Civilian = CivScript.spawn(parent, pos, null, false, CivScript.GARRISON_MEN, true)
	civ.occupation = "sentry"
	civ.working_point_pos = pos
	civ.add_to_group("firebase_garrison")
	return civ


func _free_group(tag: String) -> void:
	for n in get_tree().get_nodes_in_group(tag):
		(n as Node).queue_free()


# ---- 1. Promotion gate + peacetime negative control -----------------------

func _check_promotion_gate() -> void:
	print("-- 1a. promotion is gated on a real assault, not a lone wanderer --")

	# POSITIVE: two enemies on the wire -> the garrison stands to.
	var d := _bare_director(Vector3(2000, 0, 0))
	d.patrol_out = true
	for i in range(3):
		_spawn_garrison(d.world, d.fsb_center + Vector3(float(i) * 2.0, 0, 3.0))
	await get_tree().process_frame
	var g_before: int = get_tree().get_nodes_in_group("firebase_garrison").size()
	for off in [Vector3(10, 0, 0), Vector3(-12, 0, 4)]:
		var e := EnemyBase.new()
		add_child(e)
		e.global_position = d.fsb_center + off
		d._live_enemies.append(e)
	d._poll_firebase_threat()
	await get_tree().process_frame
	var promoted: int = get_tree().get_nodes_in_group("garrison_promoted").size()
	_expect(g_before == 3, "3 garrison men stood the wire before the assault (got %d)" % g_before)
	_expect(promoted == 3, "all 3 garrison men PROMOTED to defenders under a real assault (got %d)" % promoted)
	_expect(get_tree().get_nodes_in_group("firebase_garrison").size() == 0,
		"no Civilian garrison left behind after promotion")
	# The promoted men are defenders, not the player's squad.
	var any := get_tree().get_nodes_in_group("garrison_promoted")
	if any.size() > 0:
		var a := any[0] as AllyBase
		_expect(a != null and not a.squad_member, "a promoted defender is NOT in the player's squad")
		_expect(a != null and a._is_garrison_defender(), "a promoted defender holds a post (leash armed)")
	_free_group("garrison_promoted")
	for e in d._live_enemies:
		(e as Node).queue_free()
	d.queue_free()
	await get_tree().process_frame

	print("-- 1a NEGATIVE CONTROL: one lone enemy must NOT stand the garrison to --")
	var d2 := _bare_director(Vector3(2600, 0, 0))
	d2.patrol_out = true
	for i in range(3):
		_spawn_garrison(d2.world, d2.fsb_center + Vector3(float(i) * 2.0, 0, 3.0))
	await get_tree().process_frame
	var lone := EnemyBase.new()
	add_child(lone)
	lone.global_position = d2.fsb_center + Vector3(8, 0, 0)
	d2._live_enemies.append(lone)
	d2._poll_firebase_threat()
	await get_tree().process_frame
	_expect(get_tree().get_nodes_in_group("garrison_promoted").size() == 0,
		"a LONE wanderer did not promote the garrison (peacetime holds)")
	_expect(get_tree().get_nodes_in_group("firebase_garrison").size() == 3,
		"the garrison is still 3 passive Civilians with one enemy about")
	lone.queue_free()
	_free_group("firebase_garrison")
	d2.queue_free()
	await get_tree().process_frame


# ---- 1b. A promoted defender returns fire ---------------------------------

func _check_defender_returns_fire() -> void:
	print("-- 1b. a promoted defender RETURNS FIRE on an attacker --")
	SimClock.sim_hour = 10.0   # DAY - a clean 140m cap so the 30m enemy is unambiguously seen
	var d := _bare_director(Vector3(3200, 0, 0))
	var civ := _spawn_garrison(d.world, d.fsb_center + Vector3(0, 0, 2))
	await get_tree().process_frame
	var defender: AllyBase = GarrisonDefender.promote(civ, d, d.fsb_center)
	_expect(defender != null, "the garrison man promoted to a defender")
	if defender == null:
		d.queue_free()
		return
	defender.courage = 1.0   # a steady man goes to the fight, not to cover (isolates 'fires')
	defender.skill = 0.5
	var enemy := EnemyBase.spawn_enemy(d.world, defender.global_position + Vector3(0, 0, 30), NORMAL_DATA)
	await get_tree().process_frame
	defender._think()
	_expect(defender.target == enemy, "the defender acquired the attacker")
	_expect(defender.current_state == Enums.AIState.COMBAT, "the defender went to COMBAT")
	defender._aim_settle = 0.0
	defender._execute_combat(0.1)
	_expect(defender.shots_fired > 0, "the defender RETURNED FIRE (shots_fired=%d)" % defender.shots_fired)
	enemy.queue_free()
	defender.queue_free()
	d.queue_free()
	await get_tree().process_frame


# ---- 2. Sapper stealth vs the alert garrison at night ----------------------

func _check_sapper_stealth() -> void:
	print("-- 2. a sapper is harder to spot at night; a flare restores it --")
	SimClock.sim_hour = 21.0   # NIGHT: open cap 140*0.4 = 56m
	var eye := AllyBase.spawn_ally(self, Vector3.ZERO)
	await get_tree().process_frame
	# 45m: inside a normal soldier's night cap (56), OUTSIDE a sapper's (56*0.6=33.6),
	# and back inside once a flare lifts the cap (126*0.6=75.6).
	var d: float = 45.0

	var normal := EnemyBase.spawn_enemy(self, Vector3(0, 0, d), NORMAL_DATA)
	await get_tree().process_frame
	eye._find_target()
	_expect(eye.target == normal, "at 45m in the dark, a NORMAL soldier is picked up")
	normal.queue_free()
	await get_tree().process_frame

	var sapper := EnemyBase.spawn_enemy(self, Vector3(0, 0, d), SAPPER_DATA)
	await get_tree().process_frame
	eye._find_target()
	_expect(eye.target == null, "at the SAME 45m, the stealthier sapper is NOT picked up (his dark)")

	# Flare over the sapper -> the cap lifts and he is seen again (the counter-play).
	var flare: IllumFlare = IllumFlare.pop(self, sapper.global_position)
	await get_tree().process_frame
	_expect(IllumFlare.is_lit(sapper.global_position), "flare is lit over the sapper")
	eye._find_target()
	_expect(eye.target == sapper, "a flare over the sapper RESTORES the pickup at 45m")
	if is_instance_valid(flare):
		flare.queue_free()
	sapper.queue_free()
	eye.queue_free()
	await get_tree().process_frame


# ---- 3. Coordinated: silent sappers + a loud charging element --------------

func _check_assault_is_coordinated() -> void:
	print("-- 3. the assault is a SILENT sapper tip + a LOUD charging element --")
	var d := _bare_director(Vector3(4200, 0, 0))
	d.launch_sapper_assault(FieldDirector.SAPPER_COUNT)
	var sappers := get_tree().get_nodes_in_group("sapper_assault")
	var chargers := get_tree().get_nodes_in_group("firebase_assault")
	_expect(sappers.size() == FieldDirector.SAPPER_COUNT,
		"%d silent sappers form the tip (got %d)" % [FieldDirector.SAPPER_COUNT, sappers.size()])
	_expect(chargers.size() == FieldDirector.ASSAULT_ELEMENT,
		"%d loud chargers follow (got %d)" % [FieldDirector.ASSAULT_ELEMENT, chargers.size()])
	if sappers.size() > 0:
		var s := sappers[0] as EnemyBase
		_expect(s != null and s.silent_infiltrator, "the sapper tip is SILENT (never fires)")
	if chargers.size() > 0:
		var c := chargers[0] as EnemyBase
		_expect(c != null and not c.silent_infiltrator, "the charging element is LOUD (fires and telegraphs)")
		_expect(c != null and c.alert_tier == EnemyBase.AlertTier.ALERT,
			"the chargers advance ALERT, aimed at the compound")
	_free_group("sapper_assault")
	_free_group("firebase_assault")
	d.queue_free()


# ---- Silence is an INVARIANT (not an accident of the move override) --------

func _check_silence_invariant() -> void:
	print("-- silence invariant: a sapper never fires even with the objective cleared --")
	var sapper := EnemyBase.spawn_enemy(self, Vector3(5200, 0, 0), SAPPER_DATA)
	sapper.assault_objective = Vector3.ZERO   # the override is GONE - only the flag remains
	var mark := StubPlayer.new()
	add_child(mark)
	mark.global_position = sapper.global_position + Vector3(0, 0, 10)
	sapper.target = mark
	sapper.has_line_of_sight = true
	sapper._fire_at_target()
	_expect(sapper.shots_fired == 0, "a silent sapper did NOT fire (shots_fired=%d)" % sapper.shots_fired)
	# CONTROL: the same body with the flag OFF takes the shot - proving the FLAG is the
	# cause, and that this harness can produce a shot at all.
	sapper.silent_infiltrator = false
	sapper._fire_at_target()
	_expect(sapper.shots_fired > 0, "with the flag off, the SAME body fires (flag is the cause)")
	mark.queue_free()
	sapper.queue_free()


# ---- 4. Breach cost: live dock + persistent next-patrol penalty ------------

func _check_breach_cost_and_persistence() -> void:
	print("-- 4. a breach docks live mortars AND shorts the next allotment (persisted) --")
	CampaignState.depot_loss = {}
	var d := _bare_director(Vector3(6200, 0, 0))
	d.fire_support = {"bombs": 1, "napalm": 0, "arty": 1, "mortar": 3, "spooky": 0, "cbu": 0}
	d.on_firebase_breach(d.fsb_center)
	_expect(int(d.fire_support.get("mortar", -1)) == 0, "the breach docked the LIVE mortars to 0")
	_expect(not CampaignState.depot_loss.is_empty(), "the breach recorded a persistent depot loss")

	# Persistence: survive a full save/load round-trip.
	var snapshot: Dictionary = CampaignState.to_dict()
	CampaignState.depot_loss = {}   # wipe memory as a reload would
	CampaignState.from_dict(snapshot)
	_expect(int(CampaignState.depot_loss.get("mortar", 0)) == FieldDirector.BREACH_MORTAR_LOSS,
		"the depot loss SURVIVED the save/load round-trip")

	# Consumed on the next walk-out: the next allotment is short vs an un-breached control.
	var next_mortar: int = _granted_mortar(Vector3(6800, 0, 0))
	_expect(CampaignState.depot_loss.is_empty(), "the penalty was CONSUMED on the next allotment")
	CampaignState.depot_loss = {}
	var control_mortar: int = _granted_mortar(Vector3(7400, 0, 0))
	_expect(next_mortar < control_mortar,
		"the next patrol ran SHORT: %d mortars vs an un-breached %d" % [next_mortar, control_mortar])
	d.queue_free()
	await get_tree().process_frame


func _granted_mortar(center: Vector3) -> int:
	var d := _bare_director(center)
	CampaignState.threat_level = CampaignState.BASE_THREAT
	d._grant_fire_support()
	var m: int = int(d.fire_support.get("mortar", 0))
	d.queue_free()
	return m


# ---- 5. The crisis re-fires on a new wave (control: old key fires once) -----

func _check_crisis_refires() -> void:
	print("-- 5. a NEW firebase assault re-announces; a single wave does not spam --")
	var d := _bare_director(Vector3(9000, 0, 0))
	d.patrol_out = true
	var f: DynamicMissionFactory = FactoryScript.new()
	add_child(f)
	MissionGenerator.dynamic_factory_ref = f

	# WAVE 1: two on the wire. One announcement.
	_place_threat(d, 2)
	for _i in range(4):
		d._poll_firebase_threat()   # sustained presence must NOT spam
	var after_w1: int = _count_fb_crises(d)
	_expect(after_w1 == 1, "wave 1 announced exactly once across 4 polls (got %d)" % after_w1)

	# Clear the wire and hold it clear long enough to re-arm.
	for e in d._live_enemies:
		(e as Node).queue_free()
	d._live_enemies.clear()
	await get_tree().process_frame
	for _j in range(FieldDirector.FSB_CLEAR_POLLS + 1):
		d._poll_firebase_threat()

	# WAVE 2: a genuinely new assault. It must re-announce (a NEW factory key).
	_place_threat(d, 2)
	d._poll_firebase_threat()
	var after_w2: int = _count_fb_crises(d)
	_expect(after_w2 == 2, "a NEW wave RE-ANNOUNCED (got %d firebase crises; the old constant key gives 1)" % after_w2)

	MissionGenerator.dynamic_factory_ref = null
	f.queue_free()
	for e in d._live_enemies:
		(e as Node).queue_free()
	d.queue_free()
	await get_tree().process_frame


func _place_threat(d: FieldDirector, n: int) -> void:
	for i in range(n):
		var e := EnemyBase.new()
		add_child(e)
		e.global_position = d.fsb_center + Vector3(float(i) * 3.0 + 5.0, 0, 0)
		d._live_enemies.append(e)


func _count_fb_crises(d: FieldDirector) -> int:
	var c: int = 0
	for loc in d.patrol_locations:
		if str(loc.get("kind", "")) == "firebase_attack":
			c += 1
	return c


# ---- 6. RTO killed mid-call kicks the player off the net -------------------

func _check_rto_kick() -> void:
	print("-- 6. killing the RTO mid-call kicks the player off the net this frame --")
	var d := _bare_director(Vector3(11000, 0, 0))
	var pl := d.world.player as StubPlayer
	# On the net first (the precondition the kick acts on).
	pl.set_on_net(true)
	_expect(pl.holding_handset and d.fire_menu_open, "precondition: the player is ON the net")

	# CONTROL: with the RTO alive, a process tick must NOT kick him.
	d._process(0.1)
	_expect(pl.holding_handset and d.fire_menu_open, "a LIVING RTO leaves him on the net")

	# The RTO is killed mid-call.
	var rto := d.squad_system.members[0] as AllyBase
	rto.current_state = Enums.AIState.DEAD
	d._process(0.1)
	_expect(not pl.holding_handset, "the player was kicked off the net (holding_handset=false)")
	_expect(not d.fire_menu_open, "the fire menu closed with him")
	d.squad_system.queue_free()
	d.queue_free()
	await get_tree().process_frame
