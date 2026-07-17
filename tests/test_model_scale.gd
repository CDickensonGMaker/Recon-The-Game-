## test_model_scale.gd - ADR-002 rendered-scale probe (the suite's eyes).
## Born from playtest R2's speck soldiers: ModelActor measured raw mesh-space
## AABBs (ignoring armature/export compensation), reported k=0.028 on a correct
## ~1.7m export, and shrank every character 30x. Green tests coexisted with an
## invisible army because nothing asserted RENDERED size. This does.
##   1. Every character .glb that ModelActor can load must stand within 5% of
##      ModelActor.target_height(unit) AFTER normalization, measured in instance
##      space (the same space the player's eyes use). That is the unit's OWN
##      authored height, not the roster standard: a child is 1.26m on spec, and a
##      ruler that demands 1.7132 of him is measuring the wrong contract.
##   2. Feet must sit at the actor's origin (bottom of AABB ~ 0).
## Run: godot --headless --path . res://tests/test_model_scale.tscn
extends Node3D

const TOLERANCE := 0.05  # +/-5% of target height


func _ready() -> void:
	await get_tree().process_frame
	_run()


func _run() -> void:
	var failures: int = 0
	var checked: int = 0
	var units: Array[String] = ModelActor.all_units()
	if units.is_empty():
		print("FAIL: no characters found in any faction folder")
		get_tree().quit(1)
		return
	units.sort()

	for unit in units:
		var actor := ModelActor.new()
		add_child(actor)
		if not actor.setup(unit):
			print("  %s: no model / failed setup - skipped" % unit)
			actor.queue_free()
			continue
		var h_probe: float = _instance_height(actor)
		if h_probe <= 0.001:
			print("  %-16s no mesh content (animation library?) - skipped" % unit)
			actor.queue_free()
			continue
		checked += 1
		var h: float = h_probe
		var foot: float = _instance_foot(actor)
		var target: float = ModelActor.target_height(unit)
		var ok_h: bool = absf(h - target) <= target * TOLERANCE
		var ok_f: bool = absf(foot) <= 0.08
		print("  %-16s rendered %.3fm (target %.3f) foot_y=%+.3f %s" % [
			unit, h, target, foot, "OK" if (ok_h and ok_f) else "<-- FAIL"])
		if not ok_h:
			print("FAIL: %s renders %.3fm, authored for %.3fm - the speck-soldier/giant class (n2ij)" % [
				unit, h, target])
			failures += 1
		if not ok_f:
			print("FAIL: %s feet float at y=%.3f" % [unit, foot])
			failures += 1
		actor.queue_free()

	if checked == 0:
		print("FAIL: zero models checked - probe is blind")
		failures += 1
	if failures == 0:
		print("PASS: model scale probe (%d characters, each against its authored height)" % checked)
	else:
		print("FAIL: model scale probe had %d failure(s)" % failures)
	get_tree().quit(1 if failures > 0 else 0)


## Rendered height, measured from the POSED SKELETON in world space.
##
## This must never go back to merging MeshInstance3D AABBs. A skinned mesh's
## get_aabb() is its BIND POSE, in mesh space, and it does not see the skeleton
## normalization that decides what the player actually looks at. Measured
## 2026-07-16: civ_elder bind AABB = 2.950m with feet at -1.423, while its
## skeleton stands at exactly 1.550m with feet at 0.000 - on spec. The ruler was
## wrong by 90%, not the art.
func _instance_height(actor: Node3D) -> float:
	var s: Vector2 = _skeleton_span(actor)
	return s.y - s.x


func _instance_foot(actor: Node3D) -> float:
	var s: Vector2 = _skeleton_span(actor)
	return s.x - actor.global_position.y


## Returns (lowest_bone_y, highest_bone_y) in world space.
func _skeleton_span(root: Node3D) -> Vector2:
	var skel: Skeleton3D = root.find_child("Skeleton3D", true, false) as Skeleton3D
	if skel == null or skel.get_bone_count() == 0:
		return Vector2.ZERO
	var lo: float = INF
	var hi: float = -INF
	for i in skel.get_bone_count():
		var p: Vector3 = (skel.global_transform * skel.get_bone_global_pose(i)).origin
		lo = minf(lo, p.y)
		hi = maxf(hi, p.y)
	return Vector2(lo, hi)
