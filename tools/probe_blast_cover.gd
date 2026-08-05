## probe_blast_cover.gd - does ORDNANCE defeat hard cover ~50% while bullets never do?
## Summoner ruling 2026-08-04: "the rpg thumper grenades and any bombs and stuff can
## penetrate sandbags and bunkers 50 percent of the time or something like that."
## Four lanes, each a man behind a wall (plain StaticBody3D so the cover cannot be
## destroyed mid-count - a live Destructible sandbag at hp 110 dies to the first M26,
## which is the separate, correct interaction this probe is NOT measuring):
##   A: hard wall vs 20 M26 blasts (chance 0.5)      -> expect 4..16 damaging
##   B: hard wall vs 20 RPG-7 blasts (chance 0.75)   -> expect 10..20 damaging
##   C: soft wall vs 5 M26 blasts (always defeats)   -> expect 5/5 damaging
##   D: hard wall vs 4 M16 rounds                    -> expect 0 damage, always
##   godot --headless --path . res://tools/probe_blast_cover.tscn
extends Node3D

const LANE_X: Array[float] = [0.0, 60.0, 120.0, 180.0]
const BIG_HP: int = 5000


func _ready() -> void:
	_floor()
	_wall(Vector3(LANE_X[0], 1.5, -8.0), false)
	_wall(Vector3(LANE_X[1], 1.5, -8.0), false)
	_wall(Vector3(LANE_X[2], 1.5, -8.0), true)
	_wall(Vector3(LANE_X[3], 1.5, -8.0), false)
	var men: Array[Node] = []
	for x in LANE_X:
		men.append(EnemyBase.spawn_enemy(self, Vector3(x, 0.2, -11.0),
			"res://data/enemies/vc_rifleman.tres"))
	await get_tree().create_timer(0.8).timeout
	# Statues, not soldiers: a live EnemyBase relocates after the first hit and the
	# count then measures his pathfinding, not the cover roll.
	for m in men:
		m.current_hp = BIG_HP
		(m as Node).set_physics_process(false)

	var a_hits: int = await _blast_trials(men[0], LANE_X[0], 20, 190, 50)
	print("  A: 20x M26 vs HARD wall  -> %d/20 damaging (want 4..16, chance 0.50)" % a_hits)
	var b_hits: int = await _blast_trials(men[1], LANE_X[1], 20, 290, 70)
	print("  B: 20x RPG-7 vs HARD wall -> %d/20 damaging (want 10..20, chance 0.75)" % b_hits)
	var c_hits: int = await _blast_trials(men[2], LANE_X[2], 5, 190, 50)
	print("  C: 5x M26 vs SOFT wall   -> %d/5 damaging (want 5 - thatch never stops blast)" % c_hits)

	var m16: WeaponData = load("res://data/weapons/m16a1.tres")
	var d_hp0: int = men[3].current_hp
	var chest: Vector3 = (men[3] as Node3D).global_position + Vector3(0, 1.25, 0)
	var eye := Vector3(LANE_X[3], 1.4, 0.0)
	for _i in range(4):
		CombatManager.bullets.fire(m16, null, eye, (chest - eye).normalized(), 1 | 32 | 64, [], false)
		await get_tree().create_timer(0.2).timeout
	await get_tree().create_timer(0.5).timeout
	var d_dmg: int = d_hp0 - int(men[3].current_hp)
	print("  D: 4x M16 vs HARD wall   -> %d damage (must be 0 - bullets keep the hard stop)" % d_dmg)

	var ok: bool = a_hits >= 4 and a_hits <= 16 and b_hits >= 10 and c_hits == 5 and d_dmg == 0
	print(("PASS" if ok else "FAIL")
		+ ": ordnance defeats hard cover on the roll, soft always, bullets never")
	get_tree().quit(0 if ok else 1)


## One blast per trial 3m in front of the wall; a trial is damaging if hp dropped.
func _blast_trials(man: Node, x: float, n: int, dmg_max: int, dmg_min: int) -> int:
	var hits: int = 0
	for _i in range(n):
		man.current_hp = BIG_HP
		CombatManager.apply_explosion_damage(Vector3(x, 0.6, -5.0), dmg_max, dmg_min, 8.0, null)
		await get_tree().physics_frame
		if int(man.current_hp) < BIG_HP:
			hits += 1
	return hits


func _wall(pos: Vector3, soft: bool) -> void:
	var b := StaticBody3D.new()
	b.name = "thatch_wall" if soft else "bunker_wall"
	b.collision_layer = 1
	b.collision_mask = 0
	b.add_to_group("soft_cover" if soft else "hard_surface")
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(10, 3.0, 0.4)
	cs.shape = box
	b.add_child(cs)
	add_child(b)
	b.global_position = pos


func _floor() -> void:
	var f := StaticBody3D.new()
	f.collision_layer = 1
	f.collision_mask = 0
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(260, 0.2, 60)
	cs.shape = box
	cs.position = Vector3(90, -0.1, -8)
	f.add_child(cs)
	add_child(f)
