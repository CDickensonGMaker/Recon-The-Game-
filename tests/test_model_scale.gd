## test_model_scale.gd - ADR-002 rendered-scale probe (the suite's eyes).
## Born from playtest R2's speck soldiers: ModelActor measured raw mesh-space
## AABBs (ignoring armature/export compensation), reported k=0.028 on a correct
## ~1.7m export, and shrank every character 30x. Green tests coexisted with an
## invisible army because nothing asserted RENDERED size. This does.
##   1. Every character .glb that ModelActor can load must stand
##      TARGET_HEIGHT_M (1.7132m) +/- 5% AFTER normalization, measured in
##      instance space (the same space the player's eyes use).
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
		var target: float = ModelActor.TARGET_HEIGHT_M
		var ok_h: bool = absf(h - target) <= target * TOLERANCE
		var ok_f: bool = absf(foot) <= 0.08
		print("  %-16s rendered %.3fm (target %.3f) foot_y=%+.3f %s" % [
			unit, h, target, foot, "OK" if (ok_h and ok_f) else "<-- FAIL"])
		if not ok_h:
			print("FAIL: %s renders %.3fm - the speck-soldier/giant class (n2ij)" % [unit, h])
			failures += 1
		if not ok_f:
			print("FAIL: %s feet float at y=%.3f" % [unit, foot])
			failures += 1
		actor.queue_free()

	if checked == 0:
		print("FAIL: zero models checked - probe is blind")
		failures += 1
	if failures == 0:
		print("PASS: model scale probe (%d characters at %.4fm)" % [checked, ModelActor.TARGET_HEIGHT_M])
	else:
		print("FAIL: model scale probe had %d failure(s)" % failures)
	get_tree().quit(1 if failures > 0 else 0)


## Height of the actor's rendered content in the actor's own space -
## the same measurement a player's eye makes against the 1.7m player camera.
func _instance_height(actor: Node3D) -> float:
	var bb := _world_aabb(actor)
	return bb.size.y


func _instance_foot(actor: Node3D) -> float:
	var bb := _world_aabb(actor)
	return bb.position.y - actor.global_position.y


func _world_aabb(root: Node3D) -> AABB:
	var out := AABB()
	var first := true
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for c in n.get_children():
			stack.push_back(c)
		var mi := n as MeshInstance3D
		if mi == null or mi.mesh == null:
			continue
		var a: AABB = mi.global_transform * mi.get_aabb()
		if first:
			out = a
			first = false
		else:
			out = out.merge(a)
	return out
