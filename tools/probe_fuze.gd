## probe_fuze.gd - does the warhead refuse to arm inside its safety distance?
## Two SEPARATE lanes so neither shot eats the other's wall:
##   lane A: wall 3m out  (inside the 5m arming distance) -> must NOT detonate
##   lane B: wall 30m out (fully armed)                   -> must blow a man down
##   godot --headless --path . res://tools/probe_fuze.tscn
extends Node3D

const LANE_A: float = 0.0
const LANE_B: float = 20.0


func _ready() -> void:
	_floor()
	_wall(Vector3(LANE_A, 1.5, -3.0))
	_wall(Vector3(LANE_B, 1.5, -30.0))
	await get_tree().create_timer(0.3).timeout
	var pdata: ProjectileData = load("res://data/projectiles/rpg2_rocket.tres")
	print("PG-2: speed %.0f m/s, arms at %.1fm, aoe %.1fm, self-destruct %s" % [
		pdata.speed, pdata.arming_distance, pdata.aoe_radius, pdata.self_destruct])

	# --- lane A: point blank into a wall 3m away, a man standing right beside it
	var man_near: Node = EnemyBase.spawn_enemy(self, Vector3(LANE_A + 1.2, 1.0, -2.3),
		"res://data/enemies/vc_rifleman.tres")
	await get_tree().create_timer(0.5).timeout
	var hp0: int = man_near.current_hp
	var r1: ProjectileBase = CombatManager.spawn_projectile(pdata, null, Vector3(LANE_A, 1.5, 0.0), Vector3(0, 0, -1))
	print("    rocket spawned: %s" % ("yes" if r1 != null else "NULL - pool refused"))
	for i in range(6):
		await get_tree().create_timer(0.05).timeout
		if is_instance_valid(r1) and r1.is_active:
			print("    t+%.2fs pos %s traveled %.2fm armed=%s" % [
				0.05 * float(i + 1), str(r1.global_position.snapped(Vector3(0.1, 0.1, 0.1))),
				r1.traveled, r1.is_armed()])
	await get_tree().create_timer(1.2).timeout
	var near_dmg: int = hp0 - (man_near.current_hp if is_instance_valid(man_near) else 0)
	var near_dead: bool = not is_instance_valid(man_near) or man_near.is_dead()
	print("  LANE A (3m, UNARMED): man 1m from impact took %d dmg, dead=%s" % [near_dmg, near_dead])

	# --- lane B: the same rocket at a man 30m out
	var man_far: Node = EnemyBase.spawn_enemy(self, Vector3(LANE_B + 1.2, 1.0, -29.3),
		"res://data/enemies/vc_rifleman.tres")
	await get_tree().create_timer(0.5).timeout
	var hp1: int = man_far.current_hp
	CombatManager.spawn_projectile(pdata, null, Vector3(LANE_B, 1.5, 0.0), Vector3(0, 0, -1))
	await get_tree().create_timer(2.0).timeout
	var far_dmg: int = hp1 - (man_far.current_hp if is_instance_valid(man_far) else 0)
	var far_dead: bool = not is_instance_valid(man_far) or man_far.is_dead()
	print("  LANE B (30m, ARMED):  man 1m from impact took %d dmg, dead=%s" % [far_dmg, far_dead])

	# The contract: an UNARMED strike does no blast damage at all; an ARMED one
	# puts real explosive damage into a man a metre away. (Whether 62 is enough
	# to finish a 70hp man is an ADR-016 lethality question, not a fuze one.)
	var ok: bool = near_dmg <= 0 and not near_dead and far_dmg >= 40
	if ok:
		print("PASS: drop-safe inside the arming distance (%.0f dmg), detonates beyond it (%d dmg)" % [
			near_dmg, far_dmg])
	else:
		print("FAIL: near dmg=%d dead=%s (want zero blast) | far dmg=%d (want a real detonation)" % [
			near_dmg, near_dead, far_dmg])
	get_tree().quit(0 if ok else 1)


func _wall(pos: Vector3) -> void:
	var b := StaticBody3D.new()
	b.collision_layer = 1
	b.collision_mask = 0
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(6, 3, 0.4)
	cs.shape = box
	b.add_child(cs)
	add_child(b)
	b.global_position = pos


func _floor() -> void:
	var f := StaticBody3D.new()
	f.collision_layer = 1
	f.collision_mask = 0
	var fcs := CollisionShape3D.new()
	var fbox := BoxShape3D.new()
	fbox.size = Vector3(80, 0.2, 80)
	fcs.shape = fbox
	fcs.position = Vector3(10, -0.1, -30)
	f.add_child(fcs)
	add_child(f)
