## probe_scorch_decal.gd - item 10, the scorch decal flip-flop.
##
## A Decal paints what is inside its BOX. GunFX._scorch built every mark 0.4m deep
## whatever its width, so a satchel's 20m scorch on ground that rolls more than 20cm
## had most of its own footprint outside its own projection - the mark snapped on and
## off as the camera moved and as the ground rose through the slab. The same box with
## no normal fade also sprayed the burn up every parapet and bunker face it touched.
##
## THE MEASUREMENT is geometric and does not need a renderer: stand the mark on real
## sloped ground, then sample the ground under the decal's own footprint and ask how
## much of it falls inside the decal's own box. A mark that does not contain the dirt
## it is burned into is a mark that flickers.
##   godot --headless --path . res://tests/probe_scorch_decal.tscn
extends Node

## Ground drop across the test patch. Gentle - about 11 degrees over 20m. If the fix
## only worked on flat ground it would not be a fix.
const SLOPE_RISE_M: float = 4.0
const PATCH_M: float = 20.0
## Where the satchel went off. 8.0 is the satchel's own scale_mult band.
const BLAST_SCALE: float = 8.0
## Samples across the footprint.
const GRID: int = 9

var _failures: int = 0


func _fail(msg: String) -> void:
	print("FAIL: %s" % msg)
	_failures += 1


func _ready() -> void:
	_run()


func _run() -> void:
	print("=== SCORCH DECAL PROBE (item 10) ===")
	# A ramp, not a plane: a box rotated about Z so the ground under the mark rises.
	var ramp := StaticBody3D.new()
	ramp.collision_layer = 1
	ramp.collision_mask = 0
	var cs := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = Vector3(PATCH_M * 3.0, 1.0, PATCH_M * 3.0)
	cs.shape = b
	ramp.add_child(cs)
	add_child(ramp)
	ramp.global_position = Vector3(0, -0.5, 0)
	ramp.rotation.z = atan2(SLOPE_RISE_M, PATCH_M)
	await get_tree().physics_frame

	var space: PhysicsDirectSpaceState3D = get_viewport().world_3d.direct_space_state
	var origin := Vector3.ZERO
	var down := PhysicsRayQueryParameters3D.create(
		origin + Vector3(0, 20, 0), origin + Vector3(0, -20, 0), 1)
	var oh: Dictionary = space.intersect_ray(down)
	if oh.is_empty():
		_fail("no ground under the blast point - the probe has nothing to burn")
		_finish()
		return
	var burn_at: Vector3 = oh.position as Vector3

	GunFX._scorch(self, burn_at, BLAST_SCALE)
	await get_tree().process_frame

	var d: Decal = null
	for c in get_children():
		if c is Decal:
			d = c as Decal
	if d == null:
		_fail("_scorch produced no Decal at all")
		_finish()
		return
	print("  decal size %.1f x %.2f x %.1f m at y %.2f" % [
		d.size.x, d.size.y, d.size.z, d.global_position.y])

	# 1. COVERAGE. How much of the ground under the mark is inside the mark's box?
	var half: float = d.size.x * 0.5
	var top: float = d.global_position.y + d.size.y * 0.5
	var bottom: float = d.global_position.y - d.size.y * 0.5
	var inside: int = 0
	var total: int = 0
	var worst: float = 0.0
	for gx in range(GRID):
		for gz in range(GRID):
			var fx: float = -half + 2.0 * half * float(gx) / float(GRID - 1)
			var fz: float = -half + 2.0 * half * float(gz) / float(GRID - 1)
			var at: Vector3 = d.global_position + Vector3(fx, 0.0, fz)
			var r := PhysicsRayQueryParameters3D.create(
				at + Vector3(0, 30, 0), at + Vector3(0, -30, 0), 1)
			var h: Dictionary = space.intersect_ray(r)
			if h.is_empty():
				continue
			total += 1
			var gy: float = (h.position as Vector3).y
			if gy <= top and gy >= bottom:
				inside += 1
			else:
				worst = maxf(worst, absf(gy - d.global_position.y))
	if total == 0:
		_fail("no ground found under the decal footprint - the probe is blind")
		_finish()
		return
	var cover: float = float(inside) / float(total)
	print("  ground inside the projection box: %d of %d samples (%.0f%%), worst miss %.2fm" % [
		inside, total, cover * 100.0, worst])
	if cover < 0.99:
		_fail("%.0f%% of the burn's own footprint is outside its own projection box "
			% (cover * 100.0)
			+ "(box %.2fm deep, ground moves %.2fm across it) - that is the flip-flop"
			% [d.size.y, worst])

	# 2. IT PAINTS THE GROUND, NOT THE WALLS. Without a normal fade the same box
	#    sprays the burn up every parapet face inside it.
	if d.normal_fade <= 0.0:
		_fail("normal_fade is %.2f - the scorch paints every wall inside its box"
			% d.normal_fade)
	else:
		print("  normal_fade %.2f - the burn stays on surfaces facing up" % d.normal_fade)

	# 3. IT FADES OUT INSTEAD OF POPPING.
	if not d.distance_fade_enabled:
		_fail("distance fade is off - the mark vanishes at a hard radius")
	else:
		print("  fades from %.0fm over %.0fm" % [d.distance_fade_begin, d.distance_fade_length])

	_finish()


func _finish() -> void:
	if _failures == 0:
		print("=== PASS ===")
	else:
		print("=== FAIL (%d) ===" % _failures)
	get_tree().quit(0 if _failures == 0 else 1)
