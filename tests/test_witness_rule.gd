## test_witness_rule.gd - behavioral ADR-005 guard (W0 preservation probe).
##   (a) a kill NOBODY sees raises no alarm: bystanders stay RELAXED for 5s and the
##       body joins the unreported_corpses ledger;
##   (b) a kill with a witness in LOS escalates the witness (ALERT, awareness>=0.75,
##       anchored on the killer) and leaves NO unreported corpse;
##   (c) a patroller routed past the body 20s later still discovers it: the ledger
##       shrinks and he goes ALERT anchored on the corpse.
## Survives any internal rewiring of perception - it asserts outcomes, not call sites.
## Run: godot --headless --path . res://tests/test_witness_rule.tscn
extends Node3D

const ENEMY_DATA := "res://data/enemies/vc_rifleman.tres"

var _failures: int = 0


func _ready() -> void:
	print("=== WITNESS RULE probe (ADR-005) ===")
	await _run()


func _run() -> void:
	EnemySquad.clear()
	EnemyBase.unreported_corpses.clear()
	_make_floor()

	# Bystanders: both beyond the 140m open sight cap of the victim at the origin.
	var bystander: EnemyBase = EnemyBase.spawn_enemy(self, Vector3(200, 1, 0), ENEMY_DATA)
	var far_control: EnemyBase = EnemyBase.spawn_enemy(self, Vector3(0, 1, 250), ENEMY_DATA)
	var victim: EnemyBase = EnemyBase.spawn_enemy(self, Vector3(0, 1, 0), ENEMY_DATA)
	await get_tree().create_timer(1.0).timeout

	# (a) SILENT KILL: no living enemy can see it happen.
	# Death-clip corpse (pre-popped limb): a settled ragdoll freezes a layer-1 Hips
	# collider at body+1.0m - the exact witness-ray endpoint - which blocks (c).
	victim._removed.append("ARM_L")
	victim.take_damage(10, Enums.DamageType.PHYSICAL, null, "HEAD")
	var corpse_pos: Vector3 = victim.global_position
	var kill_ms: float = float(Time.get_ticks_msec())
	if not victim.is_dead():
		_fail("(a) victim survived the headshot")
	if EnemyBase.unreported_corpses.size() != 1:
		_fail("(a) clean kill did not join the corpse ledger (size=%d)" % EnemyBase.unreported_corpses.size())
	await get_tree().create_timer(5.0).timeout
	if bystander.alert_tier != EnemyBase.AlertTier.RELAXED:
		_fail("(a) bystander escalated to tier %d off a kill he could not see" % bystander.alert_tier)
	if far_control.alert_tier != EnemyBase.AlertTier.RELAXED:
		_fail("(a) far control escalated to tier %d off a kill he could not see" % far_control.alert_tier)
	if _failures == 0:
		print("  [OK] (a) silent kill: camp stays RELAXED, body on the ledger")

	# (b) WITNESSED KILL: the bystander has eyes on this one at 50m, open ground.
	var killer := Node3D.new()
	add_child(killer)
	killer.global_position = Vector3(140, 1, 0)
	killer.add_to_group("allies")
	var victim2: EnemyBase = EnemyBase.spawn_enemy(self, Vector3(150, 1, 0), ENEMY_DATA)
	await get_tree().create_timer(0.5).timeout
	var pre_b: int = _failures
	bystander.facing_dir = Vector3(-1, 0, 0)
	victim2.take_damage(10, Enums.DamageType.PHYSICAL, killer, "HEAD")
	if bystander.alert_tier != EnemyBase.AlertTier.ALERT:
		_fail("(b) witness did not escalate (tier=%d)" % bystander.alert_tier)
	if bystander.awareness < 0.75:
		_fail("(b) witness awareness %.2f (want >=0.75)" % bystander.awareness)
	if bystander.last_known_target_pos.distance_to(killer.global_position) > 1.5:
		_fail("(b) witness not anchored on the killer (lkp=%s)" % bystander.last_known_target_pos)
	if EnemyBase.unreported_corpses.size() != 1:
		_fail("(b) witnessed kill changed the ledger (size=%d, want the 1 from phase a)" % EnemyBase.unreported_corpses.size())
	if _failures == pre_b:
		print("  [OK] (b) witnessed kill: witness ALERT + anchored, no ledger entry")

	# (c) CORPSE DISCOVERY, 20s after the silent kill: a man routed past the body finds it.
	var wait_left: float = maxf(0.0, 20.0 - (float(Time.get_ticks_msec()) - kill_ms) / 1000.0)
	await get_tree().create_timer(wait_left).timeout
	var pre_c: int = _failures
	var patroller: EnemyBase = EnemyBase.spawn_enemy(self, Vector3(15, 1, 0), ENEMY_DATA)
	patroller.facing_dir = Vector3(-1, 0, 0)
	patroller._home_facing = Vector3(-1, 0, 0)
	patroller._scan_phase = 0.0
	var t: float = 0.0
	while not EnemyBase.unreported_corpses.is_empty() and t < 10.0:
		await get_tree().create_timer(0.25).timeout
		t += 0.25
	print("  corpse discovered after %.2fs in range" % t)
	if not EnemyBase.unreported_corpses.is_empty():
		_fail("(c) patroller walked past the body and never found it")
	if patroller.alert_tier < EnemyBase.AlertTier.ALERT:
		_fail("(c) discovery did not raise the finder to ALERT (tier=%d)" % patroller.alert_tier)
	if patroller.last_known_target_pos.distance_to(corpse_pos) > 2.0:
		_fail("(c) finder not anchored on the corpse (lkp=%s)" % patroller.last_known_target_pos)
	if _failures == pre_c:
		print("  [OK] (c) late corpse discovery: ledger shrank, finder ALERT on the body")

	print("\n%s: %d failure(s)" % ["PASS" if _failures == 0 else "FAIL", _failures])
	get_tree().quit(0 if _failures == 0 else 1)


func _make_floor() -> void:
	var floor_body := StaticBody3D.new()
	floor_body.collision_layer = 1
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(700, 1, 700)
	cs.shape = box
	floor_body.add_child(cs)
	add_child(floor_body)
	floor_body.global_position = Vector3(0, -0.5, 0)


func _fail(msg: String) -> void:
	_failures += 1
	print("FAIL %s" % msg)
