## test_model_actor_animations.gd - per-unit animation contract probe.
## Iterates every character GLB on disk and proves the shared animation library
## resolves the canonical combat clips. Logs every failure with the unit name so
## export contract breakers are easy to find.
## Run: godot --headless --path . res://tests/test_model_actor_animations.tscn
extends Node3D

const REQUIRED_CLIPS: Array[String] = ["idle", "run_forward", "firing_rifle", "death_forward"]
const LOOP_CLIPS: Array[String] = ["idle", "run_forward"]
const ONE_SHOT_CLIPS: Array[String] = ["death_forward"]

var _failures: int = 0


func _ready() -> void:
	await get_tree().process_frame
	_run()


func _bad(unit: String, msg: String) -> void:
	print("FAIL [%s]: %s" % [unit, msg])
	_failures += 1


func _run() -> void:
	print("=== ModelActor Animation Contract Probe ===")

	var units: Array[String] = ModelActor.all_units()
	print("  units on disk: %d" % units.size())
	if units.is_empty():
		_bad("(global)", "no .glb units found")
		_finish()
		return

	# Preload shared library once and report its size as a sanity check.
	var lib: AnimationLibrary = ModelActor._load_shared_library()
	if lib == null:
		_bad("(global)", "shared anim library did not load")
		_finish()
		return
	print("  shared library clips: %d" % lib.get_animation_list().size())

	for unit in units:
		_test_unit(unit)

	_finish()


func _test_unit(unit: String) -> void:
	var actor := ModelActor.new()
	add_child(actor)

	if not actor.setup(unit):
		_bad(unit, "setup() returned false (no .glb or failed to load)")
		actor.queue_free()
		return

	# Contract: PSXRig/Skeleton3D must exist for library track paths to resolve.
	var inst: Node3D = actor.instance_root()
	if inst == null:
		_bad(unit, "instance_root() is null after setup")
		actor.queue_free()
		return

	var skel: Skeleton3D = inst.get_node_or_null("PSXRig/Skeleton3D") as Skeleton3D
	if skel == null:
		_bad(unit, "missing PSXRig/Skeleton3D contract node")
		actor.queue_free()
		return

	var anim: AnimationPlayer = actor.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if anim == null:
		_bad(unit, "no AnimationPlayer found")
		actor.queue_free()
		return

	var clip_count: int = actor.clip_names().size()
	if clip_count == 0:
		_bad(unit, "AnimationPlayer has zero clips")
		actor.queue_free()
		return

	# Required canonical clips must resolve (directly or via alias).
	for clip in REQUIRED_CLIPS:
		if not actor.play(clip, true):
			_bad(unit, "cannot play required clip '%s'" % clip)

	# Loop-mode contract. play() may resolve aliases (e.g. death_forward -> death_from_the_front),
	# so check the actual clip name that was played.
	for clip in LOOP_CLIPS:
		if not actor.play(clip, true):
			continue  # already reported
		var actual: String = _resolved_clip(actor, anim, clip)
		if actual.is_empty():
			continue
		var a: Animation = anim.get_animation(actual)
		if a != null and a.loop_mode != Animation.LOOP_LINEAR:
			_bad(unit, "loop clip '%s' (resolved '%s') has loop_mode %d, expected LOOP_LINEAR" % [clip, actual, a.loop_mode])

	for clip in ONE_SHOT_CLIPS:
		if not actor.play(clip, true):
			continue
		var actual: String = _resolved_clip(actor, anim, clip)
		if actual.is_empty():
			continue
		var a: Animation = anim.get_animation(actual)
		if a != null and a.loop_mode == Animation.LOOP_LINEAR:
			_bad(unit, "one-shot clip '%s' (resolved '%s') is unexpectedly looping" % [clip, actual])

	# Skeleton motion contract: run_forward must actually move Hips.
	var hips: int = skel.find_bone("mixamorig_Hips")
	if hips >= 0:
		if actor.play("run_forward", true):
			anim.advance(0.25)
			var pos: Vector3 = skel.get_bone_pose_position(hips)
			if pos.is_equal_approx(Vector3.ZERO):
				_bad(unit, "run_forward does not move mixamorig_Hips (track path dead?)")
	else:
		_bad(unit, "missing mixamorig_Hips bone")

	print("  %s: OK (%d clips)" % [unit, clip_count])
	actor.queue_free()


## Return the real clip name that play() resolved, or "" if unavailable.
## Respects the alias fallback used by ModelActor.play().
func _resolved_clip(actor: ModelActor, anim: AnimationPlayer, clip: String) -> String:
	if anim.has_animation(clip):
		return clip
	if clip.contains("__"):
		var base: String = clip.split("__")[0]
		if anim.has_animation(base):
			return base
	for alias in SpriteStateMap.MODEL_ALIASES.get(clip, []):
		var s: String = str(alias)
		if anim.has_animation(s):
			return s
	return ""


func _finish() -> void:
	print("\n%s: %d failure(s)" % ["PASS" if _failures == 0 else "FAIL", _failures])
	get_tree().quit(0 if _failures == 0 else 1)
