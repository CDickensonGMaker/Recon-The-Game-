## probe_witness.gd - THE WITNESS RULE, measured (ADR-005, decree pwu5).
##
## The claim under test: "a silent, unwitnessed kill is SILENT." That claim has been
## in the canon since the project started and was FALSE the entire time -
## take_damage() stamped the global detection beacon before the death check ran, so
## a suppressed one-shot on a lone sentry in deep jungle still shouted
## "YOU'VE BEEN MADE". Pillar 3 had no economy.
##
## This probe is the gate on that fix. It does not read comments; it kills men and
## watches the beacon.
##
## MUST run as a SCENE, not with -s: a SceneTree script gets NO autoloads, so
## GameManager/NoiseBus/CombatManager are all missing and it segfaults on the first
## perception tick. (This is the same trap that hung probe_physics_ab - bead twig.)
##   godot --headless --path . res://tools/probe_witness.tscn
extends Node

const DATA := "res://data/enemies/vc_rifleman.tres"

var _fails: int = 0


func _ready() -> void:
	await get_tree().process_frame
	print("\n=== THE WITNESS RULE ===\n")
	_check("GUNSHOT carries 150m (was 55m - stealth had no price)",
		NoiseBus.RADII[NoiseBus.NoiseType.GUNSHOT] >= 145.0,
		"radius = %.0fm" % NoiseBus.RADII[NoiseBus.NoiseType.GUNSHOT])
	await _t_silent_kill()
	await _t_witnessed_kill()
	await _t_heard_him_fall()
	await _t_far_and_looking_away()
	await _t_survivor_talks()
	await _t_corpse_discovery()
	print("")
	if _fails == 0:
		print("*** WITNESS RULE HOLDS. A silent kill is finally silent. ***")
	else:
		print("*** %d FAILURE(S) - THE STEALTH ECONOMY IS STILL A LIE ***" % _fails)
	get_tree().quit(1 if _fails > 0 else 0)


func _check(what: String, pass_: bool, detail: String = "") -> void:
	if not pass_:
		_fails += 1
	print("  [%s] %s%s" % ["PASS" if pass_ else "FAIL", what, ("   (%s)" % detail) if detail != "" else ""])


## Fresh AO: clear the static beacon and the body list between scenarios.
func _arena() -> Node3D:
	EnemyBase.last_combat_contact_ms = -1.0
	EnemyBase.unreported_corpses.clear()
	var holder := Node3D.new()
	add_child(holder)
	return holder


func _made() -> bool:
	return EnemyBase.last_combat_contact_ms > 0.0


func _man(holder: Node3D, at: Vector3, facing: Vector3 = Vector3.FORWARD) -> EnemyBase:
	var e: EnemyBase = EnemyBase.spawn_enemy(holder, at, DATA)
	e.facing_dir = facing.normalized()
	e.alert_tier = EnemyBase.AlertTier.RELAXED
	e.awareness = 0.0
	return e


## The whole point. One man, alone in the jungle, one shot to the head, nobody
## within a klick. The AO must learn NOTHING.
func _t_silent_kill() -> void:
	print("\n-- 1. LONE SENTRY, ONE SHOT, NOBODY WATCHING --")
	var h := _arena()
	var man := _man(h, Vector3(0, 0, 0))
	await get_tree().process_frame
	man.take_damage(999, Enums.DamageType.PHYSICAL, null, "HEAD")
	await get_tree().process_frame
	_check("the AO is NOT alerted by an unwitnessed kill", not _made(),
		"beacon=%.0f" % EnemyBase.last_combat_contact_ms)
	_check("the body is logged as a liability", EnemyBase.unreported_corpses.size() == 1,
		"%d unreported corpse(s)" % EnemyBase.unreported_corpses.size())
	h.queue_free()
	await get_tree().process_frame


## His buddy is standing right there, LOOKING AT HIM. That is a witness.
## NOTE: facing_dir must be set in the SAME frame as the kill - the AI's own think
## tick overwrites it every physics step, and an earlier version of this probe
## "failed" purely because the buddy had idly turned away. The code was right; the
## test was lying. (Measure, then act, then measure again.)
func _t_witnessed_kill() -> void:
	print("
-- 2. HIS BUDDY IS WATCHING (10m, eyes on) --")
	var h := _arena()
	var victim := _man(h, Vector3(0, 0, 0))
	var buddy := _man(h, Vector3(0, 0, 10))
	await get_tree().process_frame
	buddy.facing_dir = Vector3(0, 0, -1)   # eyes on him, THIS frame
	victim.take_damage(999, Enums.DamageType.PHYSICAL, null, "HEAD")
	await get_tree().process_frame
	_check("the witness raises the alarm", _made())
	_check("no phantom corpse logged (it WAS seen)", EnemyBase.unreported_corpses.is_empty(),
		"%d unreported" % EnemyBase.unreported_corpses.size())
	h.queue_free()
	await get_tree().process_frame


## Back turned, but close enough that a body hitting the dirt is LOUD.
func _t_heard_him_fall() -> void:
	print("
-- 2b. BACK TURNED, BUT 5m AWAY (he hears it) --")
	var h := _arena()
	var victim := _man(h, Vector3(0, 0, 0))
	var buddy := _man(h, Vector3(0, 0, 5))
	await get_tree().process_frame
	buddy.facing_dir = Vector3(0, 0, 1)    # looking AWAY
	victim.take_damage(999, Enums.DamageType.PHYSICAL, null, "HEAD")
	await get_tree().process_frame
	_check("a man at 5m HEARS his buddy drop, facing or not", _made())
	h.queue_free()
	await get_tree().process_frame


## THE SHOT THAT BUYS YOU THE MISSION. There are enemies in the AO - just not
## looking, and not close. This is the case Pillar 3 exists for, and it has never
## once worked in this project until now.
func _t_far_and_looking_away() -> void:
	print("
-- 2c. HIS BUDDY IS 60m OFF, FACING AWAY (the shot you WANT) --")
	var h := _arena()
	var victim := _man(h, Vector3(0, 0, 0))
	var buddy := _man(h, Vector3(0, 0, 60))
	await get_tree().process_frame
	buddy.facing_dir = Vector3(0, 0, 1)    # looking away, and far
	victim.take_damage(999, Enums.DamageType.PHYSICAL, null, "HEAD")
	await get_tree().process_frame
	_check("STILL SILENT - the AO does not learn", not _made())
	_check("but the body is a liability now", EnemyBase.unreported_corpses.size() == 1)
	h.queue_free()
	await get_tree().process_frame


## Shoot a man and fail to kill him and he WILL tell everyone. That is the price
## of a bad shot, and it must still be paid.
func _t_survivor_talks() -> void:
	print("\n-- 3. YOU SHOT HIM AND HE LIVED --")
	var h := _arena()
	var man := _man(h, Vector3(0, 0, 0))
	await get_tree().process_frame
	man.take_damage(5, Enums.DamageType.PHYSICAL, null, "ARM_L")  # a graze
	await get_tree().process_frame
	_check("a survivor is alive to talk", not man.is_dead(), "hp=%d" % man.current_hp)
	_check("...and he DOES", _made())
	h.queue_free()
	await get_tree().process_frame


## The delayed price. The kill was clean - but you left him lying in the trail.
func _t_corpse_discovery() -> void:
	print("\n-- 4. SOMEONE WALKS UP ON THE BODY --")
	var h := _arena()
	var man := _man(h, Vector3(0, 0, 0))
	# Far away, facing the other way: cannot witness the kill itself.
	var finder := _man(h, Vector3(0, 0, 300), Vector3(0, 0, 1))
	await get_tree().process_frame
	man.take_damage(999, Enums.DamageType.PHYSICAL, null, "HEAD")
	await get_tree().process_frame
	_check("the kill itself is still silent", not _made())
	# Now he wanders up on it and looks at it.
	finder.global_position = Vector3(0, 0, 12)
	finder.facing_dir = Vector3(0, 0, -1)
	await get_tree().process_frame
	finder._check_corpse_discovery()
	await get_tree().process_frame
	_check("finding the body RAISES THE ALARM", _made())
	_check("the body is consumed (he only finds it once)",
		EnemyBase.unreported_corpses.is_empty(),
		"%d left" % EnemyBase.unreported_corpses.size())
	h.queue_free()
	await get_tree().process_frame
