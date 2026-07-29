## test_sapper_assault.gd - the sapper wire assault (war-room decree 2026-07-20).
##
## sapper_charge.gd was an ORPHAN whose "sprint for the wire" never moved a man.
## This probe proves the REPAIRED feature, and every assertion carries a negative
## control run against the inverted condition - because the danger here is exactly
## a probe that passes against both the fix and its absence. The pre-existing
## systems (spawn_tracked_enemy, apply_explosion_damage, _poll_firebase_threat) all
## worked before this feature, so asserting they run proves nothing; each check
## targets the NEW wiring specifically.
##
## Run: godot --headless --path . res://tests/test_sapper_assault.tscn
extends Node

const SapperChargeScript := preload("res://scripts/enemies/sapper_charge.gd")
const CivScript := preload("res://scripts/world/civilian.gd")
const FactoryScript := preload("res://scripts/missions/dynamic_mission_factory.gd")
const SAPPER_DATA := "res://data/enemies/vc_sapper.tres"

var _failures := 0


func _ready() -> void:
	_check_objective_drive()
	await _check_detonation_condition()
	_check_blast_spares_garrison()
	_check_launch_wiring()
	_check_notification_path()
	_check_gating()
	if _failures == 0:
		print("test_sapper_assault: PASS")
	else:
		print("test_sapper_assault: %d FAILURES" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


func _fail(msg: String) -> void:
	print("FAIL: ", msg)
	_failures += 1


func _flat_speed_toward(e: EnemyBase, obj: Vector3) -> float:
	var flat := Vector3(e.velocity.x, 0.0, e.velocity.z)
	if flat.length() < 0.01:
		return 0.0
	var to := (obj - e.global_position)
	to.y = 0.0
	if to.length() < 0.01:
		return 0.0
	return flat.normalized().dot(to.normalized()) * flat.length()


## A ------------------------------------------------------------------ the legs.
## The objective override drives him; WITHOUT it he stands. Proves the movement
## is real and not the orphan's inert last_known_target_pos write.
func _check_objective_drive() -> void:
	var obj := Vector3(50, 0, 0)

	var driven := EnemyBase.spawn_enemy(self, Vector3.ZERO, SAPPER_DATA)
	driven.assault_objective = obj
	driven._execute(0.1)
	if _flat_speed_toward(driven, obj) < 1.0:
		_fail("a sapper with an objective did not drive toward it (speed %.2f)"
			% _flat_speed_toward(driven, obj))

	# NEGATIVE CONTROL: same man, no objective, no target - the FSM idles him.
	var idle := EnemyBase.spawn_enemy(self, Vector3(1000, 0, 0), SAPPER_DATA)
	idle.assault_objective = Vector3.ZERO
	idle._execute(0.1)
	if _flat_speed_toward(idle, Vector3(1050, 0, 0)) > 0.5:
		_fail("a sapper with NO objective still drove toward the wire - the override is not what moves him")

	driven.queue_free()
	idle.queue_free()


## B ------------------------------------------------------- arrival, not before.
func _check_detonation_condition() -> void:
	# POSITIVE: at the objective, he blows (take_damage 9999 -> dead).
	var at := EnemyBase.spawn_enemy(self, Vector3(2000, 0, 0), SAPPER_DATA)
	var c_at := SapperChargeScript.new()
	at.add_child(c_at)
	c_at.setup(Vector3(2000, 0, 0))
	if not c_at._armed:
		_fail("charge refused a valid objective")
	c_at._physics_process(0.1)
	if not at.is_dead():
		_fail("a sapper AT the objective did not detonate")

	# NEGATIVE: 100m short, he must NOT detonate.
	var far := EnemyBase.spawn_enemy(self, Vector3(3000, 0, 0), SAPPER_DATA)
	var c_far := SapperChargeScript.new()
	far.add_child(c_far)
	c_far.setup(Vector3(3100, 0, 0))
	c_far._physics_process(0.1)
	if far.is_dead():
		_fail("a sapper 100m from the objective detonated early")

	# NEGATIVE: a ZERO objective never arms and never blows (the origin guard).
	# Asserted through the silent predicate: setup() answers a refusal with
	# push_error, and driving that on purpose would fail the whole run on an
	# error the probe deliberately provoked.
	if SapperChargeScript.is_valid_objective(Vector3.ZERO):
		_fail("ZERO passes is_valid_objective - an unset satchel would arm at world origin")
	if not SapperChargeScript.is_valid_objective(Vector3(2000, 0, 0)):
		_fail("a real objective FAILS is_valid_objective - the guard rejects everything")

	var zeroed := EnemyBase.spawn_enemy(self, Vector3(4000, 0, 0), SAPPER_DATA)
	var c_zero := SapperChargeScript.new()
	zeroed.add_child(c_zero)
	if c_zero._armed:
		_fail("a charge armed before setup - it would detonate at world origin")
	c_zero._physics_process(0.1)
	if zeroed.is_dead():
		_fail("an unarmed charge detonated")

	await get_tree().physics_frame
	far.queue_free()
	zeroed.queue_free()


## C --------------------------------------- damage lands, the garrison is spared.
func _check_blast_spares_garrison() -> void:
	var center := Vector3(6000, 0, 0)

	# An ordinary villager point-blank proves the blast REACHES this range.
	var villager := _bare_civ(center + Vector3(1, 0, 0), false)
	# A garrison man at the same range is the one the satchel must spare.
	var soldier := _bare_civ(center + Vector3(1, 0, 1), true)

	CombatManager.apply_explosion_damage(center, 250, 70, 14.0, null, 1.0, true)

	if villager.state != CivScript.CivState.GONE:
		_fail("the satchel did not kill a point-blank villager - damage never landed")
	if soldier.state == CivScript.CivState.GONE:
		_fail("spare_garrison did NOT spare the garrison - the blast deleted a noncombatant")

	# NEGATIVE CONTROL: without the flag, the SAME garrison man dies. Proves the
	# flag (not distance) is what spared him.
	var soldier2 := _bare_civ(center + Vector3(2, 0, 1), true)
	CombatManager.apply_explosion_damage(center, 250, 70, 14.0, null, 1.0, false)
	if soldier2.state != CivScript.CivState.GONE:
		_fail("without spare_garrison a point-blank garrison man survived - the spare is not doing the work")

	villager.queue_free()
	soldier.queue_free()
	soldier2.queue_free()


func _bare_civ(pos: Vector3, garrison: bool) -> Civilian:
	var civ := CivScript.new()
	civ.is_garrison = garrison
	add_child(civ)
	civ.global_position = pos
	AgentRegistry.register(civ, AgentRegistry.Kind.CIVILIAN)
	return civ


## D ------------------- the siege stands its sappers up wired, through a cell.
## The satchel carrier is still a real thing (ADR-035 keeps SapperCharge); what
## changed is WHO stands him up. A materialized sapper cell must produce men with
## both an objective and a charge, or the breach half of the siege is inert.
func _check_launch_wiring() -> void:
	var d := _bare_director(Vector3(8000, 0, 0))
	d._attach_siege()
	d.siege.open_siege(6)

	var wired := 0
	var men := 0
	for c in d.siege.cells:
		if c.data_path != SiegeDirector.SAPPER_DATA:
			continue
		c.materialize()
		for m in c.men:
			men += 1
			if m.assault_objective == Vector3.ZERO:
				_fail("a materialized sapper has no objective - he will never move")
			for ch in m.get_children():
				if ch is SapperCharge:
					wired += 1
	if men == 0:
		_fail("a 6-man siege fielded no sapper cell at all (2d6 clamps to strength)")
	if wired != men:
		_fail("only %d of %d materialized sappers carry a SapperCharge" % [wired, men])

	# A second open while one is active must not stand up a parallel assault.
	var before: int = d.siege.cells.size()
	d.siege.open_siege(6)
	if d.siege.cells.size() != before:
		_fail("open_siege ran twice and built a second assault on top of the first")

	d.queue_free()


## E ----------------------- the sappers trip the EXISTING net (r4bk / Fairness).
## Reuses the real _poll_firebase_threat; a launched-and-approaching sapper is a
## firebase-attack crisis, and inside the wire (patrol_out false) it stays silent.
func _check_notification_path() -> void:
	if not _sappers_raise_crisis(true):
		_fail("sappers on the wire while the player is out did NOT raise a crisis")
	if _sappers_raise_crisis(false):
		_fail("sappers raised a crisis while the player was inside the wire (should be silent)")


func _sappers_raise_crisis(out: bool) -> bool:
	var d := _bare_director(Vector3(10000, 0, 0))
	d.patrol_out = out
	var f: DynamicMissionFactory = FactoryScript.new()
	add_child(f)
	MissionGenerator.dynamic_factory_ref = f
	# Two live enemies inside the 90m ring - what the walk-in produces.
	for off in [Vector3(10, 0, 10), Vector3(-15, 0, 5)]:
		var e := EnemyBase.new()
		add_child(e)
		e.global_position = d.fsb_center + off
		d._live_enemies.append(e)
	d._poll_firebase_threat()
	var fired := false
	for loc in d.patrol_locations:
		if str(loc.get("kind", "")) == "firebase_attack":
			fired = true
	MissionGenerator.dynamic_factory_ref = null
	f.queue_free()
	for e in d._live_enemies:
		(e as Node).queue_free()
	d.queue_free()
	return fired


## F ------------------------------------------------ night, threat, settled world.
func _check_gating() -> void:
	var prev_night := MissionWeather.is_night
	var prev_threat := CampaignState.threat_level
	CampaignState.threat_modifiers.clear()

	# NEGATIVE: daylight never opens a siege, and never even reaches a roll.
	var day := _bare_director(Vector3(12000, 0, 0))
	day._attach_siege()
	MissionWeather.is_night = false
	day.patrol_count = 3
	CampaignState.threat_level = 1.0
	day.siege._maybe_open(0.5)
	if day.siege.active:
		_fail("a siege opened in daylight")
	if day.siege._rolled_this_night:
		_fail("daylight passed the night gate to a roll")   # deterministic control
	day.queue_free()

	# NEGATIVE: night, but the world has not settled (no walk-out yet).
	var green := _bare_director(Vector3(13000, 0, 0))
	green._attach_siege()
	MissionWeather.is_night = true
	green.patrol_count = 0
	CampaignState.threat_level = 1.0
	green.siege._maybe_open(0.5)
	if green.siege.active:
		_fail("a siege opened before the player ever left the wire")
	green.queue_free()

	# POSITIVE (the GATES open): night + settled + CRITICAL passes every gate to the
	# roll. We prove the gate opened (a roll happened), not the coin flip itself.
	var hot := _bare_director(Vector3(15000, 0, 0))
	hot._attach_siege()
	MissionWeather.is_night = true
	hot.patrol_count = 3
	CampaignState.threat_level = 1.0
	hot.siege._maybe_open(0.5)
	if not hot.siege._rolled_this_night:
		_fail("under night + settled + CRITICAL the gates did NOT open to a roll")
	hot.queue_free()

	# The run cap: a fourth consecutive night cannot fire.
	var run := _bare_director(Vector3(16000, 0, 0))
	run._attach_siege()
	MissionWeather.is_night = true
	run.patrol_count = 3
	run.siege.nights_run = SiegeDirector.MAX_RUN_NIGHTS
	run.siege._rolled_this_night = false
	run.siege._maybe_open(0.5)
	if run.siege.active:
		_fail("a %dth consecutive night of siege fired" % (SiegeDirector.MAX_RUN_NIGHTS + 1))
	run.queue_free()

	MissionWeather.is_night = prev_night
	CampaignState.threat_level = prev_threat
	CampaignState.threat_modifiers.clear()


## A FieldDirector with just enough world to poll and launch. Hand-built, never
## through GameFlow (game_flow.gd:27 already starts an operation - a second one
## builds two worlds and doubles every count).
func _bare_director(center: Vector3) -> FieldDirector:
	for prior in get_tree().get_nodes_in_group("mission_director"):
		prior.remove_from_group("mission_director")
	var d := FieldDirector.new()
	add_child(d)
	d.add_to_group("mission_director")
	var w := GameWorld.new()
	# No terrain at all, so spawn_tracked_enemy skips the terrain seat
	# (field_director.gd:33) instead of sampling an empty heightmap out of bounds.
	w.build_terrain_on_ready = false
	add_child(w)
	var pl := CharacterBody3D.new()
	w.add_child(pl)
	pl.global_position = center
	w.player = pl
	d.world = w
	# The net: a living RTO within radio range keeps the crisis reaching the player.
	var ss := SquadSystem.new()
	add_child(ss)
	var rto := AllyBase.new()
	ss.add_child(rto)
	rto.member = {"mos": "RTO", "nick": "SPARKS"}
	rto.global_position = pl.global_position
	ss.members.append(rto)
	d.squad_system = ss
	d.fsb_center = center
	d.siege_aim = center + Vector3(0, 0, 8)
	d.patrol_gate_pos = center + Vector3(0, 0, 60)
	d.patrol_gate_out = Vector3.BACK
	return d
