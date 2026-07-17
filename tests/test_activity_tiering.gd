## test_activity_tiering.gd - ADR-026 Part B guard-rails (bead ps28).
## The hot-set budgets EXPENSIVE COGNITION only. This probe holds the three pillar
## guard-rails so they cannot silently regress:
##   1. HOT-SET MATH: cap 12, ceiling 16, promote-on-death, disengage-release.
##   2. WITNESS HEARTBEAT (ADR-005): perception + corpse discovery run BEFORE the
##      tier branch in _think() - a cold unit still witnesses, or silent kills break.
##   3. FAIRNESS EXEMPT: the muzzle flash/tracer telegraph lives in the tier-agnostic
##      fire path, not the hot-only brain - a cold unit that fires still telegraphs.
## Run: godot --headless --path . res://tests/test_activity_tiering.tscn
extends Node

const EnemySquadScript := preload("res://scripts/enemies/enemy_squad.gd")


## Minimal stand-in: the hot-set roster only needs get_instance_id() + is_dead().
class FakeFighter extends Node:
	var dead: bool = false
	func is_dead() -> bool:
		return dead


var _keep: Array[FakeFighter] = []   ## hold refs so instance_from_id() stays valid


func _ready() -> void:
	print("=== ACTIVITY TIERING guard-rails (bead ps28) ===")
	var failures: int = 0

	failures += _test_hotset_math()
	failures += _test_witness_before_branch()
	failures += _test_fairness_tier_agnostic()

	if failures == 0:
		print("PASS: hot-set math + witness heartbeat + fairness guard-rails hold")
	else:
		print("=== %d FAILURE(S) ===" % failures)
	get_tree().quit(1 if failures > 0 else 0)


func _make(n: int) -> Array[FakeFighter]:
	var out: Array[FakeFighter] = []
	for i in n:
		var f := FakeFighter.new()
		add_child(f)
		_keep.append(f)
		out.append(f)
	return out


func _test_hotset_math() -> int:
	var fails: int = 0
	EnemySquadScript.clear()
	EnemySquadScript.tiering_enabled = true
	var men: Array[FakeFighter] = _make(20)

	# CAP: 20 want in, only HOT_CAP get slots.
	var granted: int = 0
	for m in men:
		if EnemySquadScript.request_hot(m):
			granted += 1
	if granted != EnemySquadScript.HOT_CAP:
		printerr("FAIL: %d granted, expected HOT_CAP=%d" % [granted, EnemySquadScript.HOT_CAP])
		fails += 1
	if EnemySquadScript.hot_count() > EnemySquadScript.HOT_CEILING:
		printerr("FAIL: hot_count %d exceeds HOT_CEILING %d" % [EnemySquadScript.hot_count(), EnemySquadScript.HOT_CEILING])
		fails += 1

	# A cold man is denied while the roster is full.
	var cold: FakeFighter = men[15] if not EnemySquadScript.is_hot(men[15]) else men[19]
	if EnemySquadScript.is_hot(cold):
		printerr("FAIL: expected a cold fighter with a full roster")
		fails += 1
	if EnemySquadScript.request_hot(cold):
		printerr("FAIL: cold fighter promoted into a full roster (cap breached)")
		fails += 1

	# PROMOTE-ON-DEATH: a hot man dies -> the cold man promotes on his next request.
	var hot_victim: FakeFighter = null
	for m in men:
		if EnemySquadScript.is_hot(m):
			hot_victim = m
			break
	hot_victim.dead = true
	if not EnemySquadScript.request_hot(cold):
		printerr("FAIL: cold fighter did not promote after a hot man died")
		fails += 1
	if EnemySquadScript.hot_count() != EnemySquadScript.HOT_CAP:
		printerr("FAIL: roster off-cap after promote-on-death: %d" % EnemySquadScript.hot_count())
		fails += 1

	# DISENGAGE-RELEASE: releasing a slot frees it for another cold man.
	var to_release: FakeFighter = null
	var still_cold: FakeFighter = null
	for m in men:
		if EnemySquadScript.is_hot(m) and m != cold:
			to_release = m
		elif not EnemySquadScript.is_hot(m) and not m.dead:
			still_cold = m
	EnemySquadScript.release_hot(to_release)
	if EnemySquadScript.is_hot(to_release):
		printerr("FAIL: release_hot did not free the slot")
		fails += 1
	if still_cold != null and not EnemySquadScript.request_hot(still_cold):
		printerr("FAIL: freed slot did not accept a waiting cold fighter")
		fails += 1

	# A/B SWITCH: tiering off => everyone is hot (pre-tiering baseline).
	EnemySquadScript.tiering_enabled = false
	if not EnemySquadScript.is_hot(men[19]):
		printerr("FAIL: tiering_enabled=false must make every fighter hot")
		fails += 1
	EnemySquadScript.tiering_enabled = true
	EnemySquadScript.clear()
	if fails == 0:
		print("  [OK] hot-set math: cap/ceiling/promote-on-death/release/AB")
	return fails


## The witness calls must sit BEFORE the tier branch in _think(), or the hot-set
## would blind cold units (ADR-005 loud-kill beacon). Source-level ratchet.
func _test_witness_before_branch() -> int:
	var body: String = _think_body()
	if body.is_empty():
		printerr("FAIL: could not isolate enemy_base._think() body")
		return 1
	var fails: int = 0
	var branch: int = body.find("AlertTier.COMBAT")
	for call_name in ["_update_perception(", "_check_corpse_discovery("]:
		var at: int = body.find(call_name)
		if at < 0 or branch < 0 or at > branch:
			printerr("FAIL: %s must run before the tier branch (witness heartbeat gated)" % call_name)
			fails += 1
	if fails == 0:
		print("  [OK] witness heartbeat runs before the tier branch (ADR-005)")
	return fails


## The flash/tracer telegraph must NOT live in the hot-only brain. It fires from
## _execute()/_fire_at_target for every unit, so a cold shooter still telegraphs.
func _test_fairness_tier_agnostic() -> int:
	var src: String = FileAccess.get_file_as_string("res://scripts/enemies/enemy_base.gd")
	var fails: int = 0
	var full: String = _func_body(src, "func _think_full_combat()")
	if full.find("muzzle_flash") >= 0 or full.find("play_shot_3d") >= 0:
		printerr("FAIL: telegraph emitted inside the hot-only brain - cold units would fire silently")
		fails += 1
	var fire: String = _func_body(src, "func _fire_at_target(")
	if fire.find("muzzle_flash") < 0 and fire.find("play_shot_3d") < 0:
		printerr("FAIL: could not confirm the telegraph lives in the tier-agnostic fire path")
		fails += 1
	if fails == 0:
		print("  [OK] fairness telegraph is tier-agnostic (fires from the shared path)")
	return fails


func _think_body() -> String:
	var src: String = FileAccess.get_file_as_string("res://scripts/enemies/enemy_base.gd")
	return _func_body(src, "func _think()")


## Return the text of a function from its signature to the next top-level `func `.
func _func_body(src: String, signature: String) -> String:
	var start: int = src.find(signature)
	if start < 0:
		return ""
	var next: int = src.find("\nfunc ", start + signature.length())
	if next < 0:
		next = src.length()
	return src.substr(start, next - start)
