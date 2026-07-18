## probe_penetration.gd - PENETRATION, measured (Caleb: "prove the penetration
## coding you said existed").
##
## WHAT IT PROVES (bullet_system.gd): a round that strikes something in the
## `soft_cover` group KEEPS GOING at x0.8 energy, at most `soft_left = 2` times.
## Everything else stops it dead. So a hooch wall is CONCEALMENT, not cover - and the
## THIRD layer of thatch is what finally eats the bullet.
##
## WHY THIS PROBE HAD TO EXIST: the system had never been exercised. Exactly ONE thing
## in the whole game was in the `soft_cover` group (site_planner.gd:120, by a filename
## heuristic), and `hard_surface` had ZERO members. A feature nothing can trigger is a
## feature you do not have.
##
##   godot --headless --path . res://tools/probe_penetration.tscn
extends Node

const DATA := "res://data/enemies/vc_rifleman.tres"

var _fails: int = 0
var _dmg: int = 0        ## damage the man behind the panels actually took


func _ready() -> void:
	await get_tree().process_frame
	print("\n=== PENETRATION ===\n")

	var wd: WeaponData = load("res://data/weapons/m16a1.tres") as WeaponData
	if wd == null:
		print("  [FAIL] no m16a1.tres")
		get_tree().quit(1)
		return
	print("  M16A1: base %d, torso x2.5 -> %d at point blank\n" % [
		wd.base_damage, int(wd.base_damage * 2.5)])

	var base: int = await _shoot_through(wd, 0, true)
	_check("no cover: the round arrives whole", base > 0, "%d damage" % base)
	if base <= 0:
		# THE CONTROL LANE IS THE GUARD. If a bare man 12m away takes no damage, the
		# gun is not firing - and then EVERY "the cover stopped it" check below would
		# pass for the wrong reason. A green test that proves nothing is worse than a
		# red one. (The first run of this probe did exactly that: 2 false PASSes,
		# because CombatManager.bullet_system does not exist - it is .bullets.)
		print("")
		print("  *** ABORT: the control shot did no damage. The gun is not firing.")
		print("      Every 'stopped' check below would be a FALSE PASS. ***")
		get_tree().quit(1)
		return

	var s1: int = await _shoot_through(wd, 1, true)
	_check("ONE layer of thatch: the round GOES THROUGH", s1 > 0, "%d damage" % s1)
	_check("...at reduced energy (x0.8)", s1 < base and s1 >= int(base * 0.7),
		"%d vs %d = x%.2f" % [s1, base, float(s1) / maxf(1.0, float(base))])

	var s2: int = await _shoot_through(wd, 2, true)
	_check("TWO layers: still through, weaker again (x0.64)", s2 > 0 and s2 < s1,
		"%d damage (x%.2f of bare)" % [s2, float(s2) / maxf(1.0, float(base))])

	var s3: int = await _shoot_through(wd, 3, true)
	_check("THREE layers: THE BUDGET IS SPENT - the round STOPS", s3 == 0,
		"%d damage got through" % s3)

	var hard: int = await _shoot_through(wd, 1, false)
	_check("SANDBAG (hard cover): the round STOPS", hard == 0,
		"%d damage got through" % hard)

	print("")
	print("  no cover %3d  |  1 thatch %3d  |  2 thatch %3d  |  3 thatch %3d  |  sandbag %3d" % [
		base, s1, s2, s3, hard])
	# ============ THE FILENAME FOOTGUN (war room 2026-07-12) ============
	# A structure's BALLISTICS used to be decided by substring-matching the GLB
	# filename (site_planner._SOFT_NAME_HINTS). Verified on the real assets:
	#   barracks_bunker  -> SOFT (matched "rack")   A BUNKER
	#   quonset_hut      -> SOFT (matched "hut")    CORRUGATED STEEL
	#   bomb_crater      -> SOFT (matched "crate")  A HOLE IN THE GROUND
	# Material is authored data now. This lane makes sure it stays that way.
	print("
-- THE FILENAME FOOTGUN: material is AUTHORED, not guessed --")
	var must_stop: Array[String] = ["barracks_bunker", "quonset_hut",
		"bomb_crater", "sandbag_bunker", "mg_nest"]
	var must_pass: Array[String] = ["thatched_hut", "hootch", "tent", "gate_fence"]
	var bad: int = 0
	for m in must_stop:
		if CollisionTable.is_soft(m):
			bad += 1
			print("      *** %s IS STILL SOFT COVER ***" % m)
	_check("a BUNKER, a HALFTRACK and a STEEL HUT all STOP the round", bad == 0,
		"%d of %d still shootable through" % [bad, must_stop.size()])
	var soft_ok: int = 0
	for m in must_pass:
		if CollisionTable.is_soft(m):
			soft_ok += 1
	_check("...and a thatch hooch is still CONCEALMENT, not cover",
		soft_ok == must_pass.size(), "%d/%d soft" % [soft_ok, must_pass.size()])

	print("")
	if _fails == 0:
		print("*** PENETRATION IS REAL. A hooch is concealment. A bunker is a bunker. ***")
	else:
		print("*** %d FAILURE(S) ***" % _fails)
	get_tree().quit(1 if _fails > 0 else 0)


## Stand a man at 12m behind `layers` panels and put one round through his chest.
## Returns the damage that actually reached him (0 = the cover stopped it).
func _shoot_through(wd: WeaponData, layers: int, soft: bool) -> int:
	var holder := Node3D.new()
	add_child(holder)

	for k in range(layers):
		var body := StaticBody3D.new()
		body.collision_layer = 1
		body.collision_mask = 0
		# THE GROUPS ARE THE WHOLE MECHANISM. bullet_system reads these - not the
		# mesh, not the material, not the name.
		body.add_to_group("soft_cover" if soft else "hard_surface")
		var col := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = Vector3(2.0, 2.0, 0.2)
		col.shape = shape
		body.add_child(col)
		body.position = Vector3(0, 1.2, -6.0 - float(k) * 0.7)
		holder.add_child(body)

	var man: EnemyBase = EnemyBase.spawn_enemy(holder, Vector3(0, 0, -12), DATA)
	await get_tree().process_frame
	await get_tree().process_frame   # hitzones need a synced frame

	_dmg = 0
	var before: int = man.current_hp
	# Fire down the lane at chest height. The REAL BulletSystem, the real hitzones.
	CombatManager.bullets.fire(wd, self, Vector3(0, 1.2, 0), Vector3(0, 0, -1),
		0xFFFFFFFF, [], false)

	# Let it fly the 12m and resolve.
	for i in range(30):
		await get_tree().physics_frame
	var got: int = maxi(0, before - man.current_hp)

	holder.queue_free()
	await get_tree().process_frame
	return got


func _check(what: String, ok: bool, detail: String = "") -> void:
	if not ok:
		_fails += 1
	print("  [%s] %s%s" % ["PASS" if ok else "FAIL", what, ("   (%s)" % detail) if detail != "" else ""])
