## test_ally_cover_roll.gd - proves the ally cover-arrival no longer rolls in
## unison (RECONgame track B1). Formerly every ally played falling_to_roll on
## every cover arrival (play_first put the roll at position #1), so an 18-man
## squad rolled together in one ~1s window. The fix defaults to a per-man
## stand_to_cover variant and rations the roll with a per-man cooldown plus a
## squad-wide window.
## Run: godot --headless --path . res://tests/test_ally_cover_roll.tscn
extends Node3D

const AllyScript := preload("res://scripts/allies/ally_base.gd")
const N: int = 18


func _ready() -> void:
	print("=== Ally Cover-Roll Stagger Probe (B1) ===")
	await get_tree().process_frame
	await get_tree().process_frame
	var failures: int = 0

	var allies: Array = []
	for i in N:
		var a: Node = AllyScript.new()
		add_child(a)
		allies.append(a)
	await get_tree().process_frame
	await get_tree().process_frame

	# --- TEST A: staggered worst case ---------------------------------------
	# All 18 arrive at cover in one window under MAX roll pressure (shaken +
	# long sprint-in). The squad window must cap it at <= 1 roll.
	AllyScript._squad_last_roll_ms = -1.0e9
	var rolls_a: int = 0
	var stands_a: int = 0
	var variants: Dictionary = {}
	for a in allies:
		a.courage = 0.0
		a.set("_cover_rush_dist", 30.0)
		a.set("_last_roll_ms", -1.0e9)
		var clip: String = a._pick_cover_arrival_clip()
		if clip == "falling_to_roll":
			rolls_a += 1
		elif clip.begins_with("stand_to_cover"):
			stands_a += 1
			variants[clip] = true
	print("  staggered worst case: %d roll, %d stand_to_cover, variants=%s" % [rolls_a, stands_a, str(variants.keys())])
	if rolls_a > 1:
		failures += 1
		print("FAIL: %d allies rolled in one window (expected <= 1)" % rolls_a)
	if stands_a < N - 1:
		failures += 1
		print("FAIL: stand_to_cover did not dominate (%d/%d)" % [stands_a, N])

	# --- TEST B: counterfactual, squad budget disabled ----------------------
	# Reset the squad window before EACH man so the budget can't cap them. Under
	# the same max pressure several SHOULD roll - proving the roll path is live
	# and that the squad budget (not a dead code path) is what caps Test A.
	var rolls_b: int = 0
	for a in allies:
		a.courage = 0.0
		a.set("_cover_rush_dist", 30.0)
		a.set("_last_roll_ms", -1.0e9)
		AllyScript._squad_last_roll_ms = -1.0e9
		if a._pick_cover_arrival_clip() == "falling_to_roll":
			rolls_b += 1
	print("  budget disabled: %d/%d would roll" % [rolls_b, N])
	if rolls_b < 2:
		failures += 1
		print("FAIL: roll path looks dead - only %d rolled even with the budget off" % rolls_b)
	if rolls_b <= rolls_a:
		failures += 1
		print("FAIL: squad budget had no effect (staggered %d >= unstaggered %d)" % [rolls_a, rolls_b])

	# --- TEST C: calm default never rolls -----------------------------------
	AllyScript._squad_last_roll_ms = -1.0e9
	var rolls_c: int = 0
	var calm_variants: Dictionary = {}
	for a in allies:
		a.courage = 0.9
		a.set("_cover_rush_dist", 2.0)
		a.set("_last_roll_ms", -1.0e9)
		var clip: String = a._pick_cover_arrival_clip()
		if clip == "falling_to_roll":
			rolls_c += 1
		elif clip.begins_with("stand_to_cover"):
			calm_variants[clip] = true
	print("  calm arrivals: %d roll, distinct variants=%d %s" % [rolls_c, calm_variants.size(), str(calm_variants.keys())])
	if rolls_c != 0:
		failures += 1
		print("FAIL: %d brave, short-rush allies rolled (expected 0)" % rolls_c)
	if calm_variants.size() < 2:
		failures += 1
		print("FAIL: no per-man variant spread (only %d distinct stand_to_cover clips)" % calm_variants.size())

	print("\n%s: %d failure(s)" % ["PASS" if failures == 0 else "FAIL", failures])
	get_tree().quit(0 if failures == 0 else 1)
