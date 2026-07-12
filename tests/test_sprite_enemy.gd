## test_sprite_enemy.gd - a real EnemyBase, spawned from a .tres, wearing sprites.
## Run: godot --headless --path . res://tests/test_sprite_enemy.tscn -- --test-save
extends Node3D

const VC := "res://data/enemies/vc_rifleman.tres"
const NVA := "res://data/enemies/nva_regular.tres"
const GERMAN := "res://data/enemies/german_rifleman.tres"

var _fail: int = 0


func _bad(msg: String) -> void:
	print("FAIL: %s" % msg)
	_fail += 1


## Rigs ship different clip-name generations (v1 death_forward == v2
## death_from_the_front); ModelActor.play resolves via MODEL_ALIASES and
## reports the resolved name. Accept either generation - direction semantics
## survive because aliases never cross directions.
func _clip_matches(want: String, got: String) -> bool:
	if got == want:
		return true
	for alias in SpriteStateMap.MODEL_ALIASES.get(want, []):
		if got == str(alias):
			return true
	return false


func _ready() -> void:
	var cam := Camera3D.new()
	add_child(cam)
	cam.global_position = Vector3(0, 1.7, 10)
	cam.look_at(Vector3(0, 1, 0))
	cam.current = true
	await get_tree().process_frame

	await _test_spawn_has_sprite()
	await _test_capsule_fallback()
	await _test_ballistic_origin_is_camera_independent()
	await _test_directional_death()
	await _test_corpse_animates_with_physics_off()
	_test_sprite_ballistics_agree()

	print(SpriteLibrary.stats())
	if _fail == 0:
		print("PASS: sprite enemy integration")
		get_tree().quit(0)
	else:
		print("FAIL: %d assertion(s)" % _fail)
		get_tree().quit(1)


func _spawn(path: String, pos: Vector3 = Vector3.ZERO) -> EnemyBase:
	var e := EnemyBase.spawn_enemy(self, pos, path)
	await get_tree().process_frame
	await get_tree().process_frame
	return e


func _test_spawn_has_sprite() -> void:
	var e := await _spawn(VC)
	if e.sprite_actor == null:
		_bad("vc_rifleman has no SpriteActor (sprite_unit=%s)" % e.enemy_data.sprite_unit)
		return
	if not e.sprite_actor.has_visual():
		_bad("visual actor has no mesh/texture")
		return
	if e.mesh != null:
		_bad("capsule mesh was built alongside the visual")
	print("  vc_rifleman -> %s  is_model=%s  clip=%s" % [
		e.enemy_data.sprite_unit, e._visual_is_model, e.sprite_actor.current_action])
	if not _clip_matches("rifle_aiming_idle", str(e.sprite_actor.current_action)):
		_bad("idle clip is %s" % e.sprite_actor.current_action)
	if not e._visual_is_model:
		_bad("vc_rifleman should default to the 3D model (vc_guerilla_mosin.glb exists)")
	e.queue_free()
	await get_tree().process_frame


## The WW2 holdovers and half-rendered units must keep the capsule, not vanish.
func _test_capsule_fallback() -> void:
	if not ResourceLoader.exists(GERMAN):
		print("  (german_rifleman.tres already deleted - skipping fallback check)")
		return
	var e := await _spawn(GERMAN, Vector3(4, 0, 0))
	if e.sprite_actor != null:
		_bad("german_rifleman got a SpriteActor")
	if e.mesh == null:
		_bad("german_rifleman has neither sprite nor capsule - invisible enemy")
	else:
		print("  german_rifleman -> capsule fallback, ok")
	e.queue_free()
	await get_tree().process_frame


func _test_ballistic_origin_is_camera_independent() -> void:
	var e := await _spawn(VC, Vector3(0, 0, 0))
	e.sprite_actor.set_facing(Vector3(0, 0, 1))
	e.sprite_actor._process(0.0)
	var aim := Vector3(0, 0, 1)
	var a: Vector3 = e.get_muzzle_position(aim)
	var va: Vector3 = e.get_muzzle_visual(aim)

	var cam := SpriteActor.camera(get_tree())
	cam.global_position = Vector3(-9, 1.7, 3)
	cam.look_at(Vector3(0, 1, 0))
	SpriteActor._cam_frame = -1
	e.sprite_actor._process(0.0)
	var b: Vector3 = e.get_muzzle_position(aim)
	var vb: Vector3 = e.get_muzzle_visual(aim)

	if a.distance_to(b) > 0.001:
		_bad("hitscan origin moved %.3fm when the camera moved" % a.distance_to(b))
	# A sprite's visual muzzle is camera-relative (Y-billboard); a MODEL's is
	# world-fixed. Only assert the sprite case.
	if not e._visual_is_model and va.distance_to(vb) < 0.001:
		_bad("sprite tracer origin ignored the camera")
	print("  muzzle: ballistic %s stable | visual %s -> %s" % [a, va, vb])

	# restore
	cam.global_position = Vector3(0, 1.7, 10)
	cam.look_at(Vector3(0, 1, 0))
	SpriteActor._cam_frame = -1
	e.queue_free()
	await get_tree().process_frame


func _test_directional_death() -> void:
	# Enemy faces +Z. Its basis.x is world +X only if the node is rotated; it is
	# not, so basis.x == +X. Shoot from +X => hit dir points -X... we assert on
	# the CLIP, which is what matters.
	# Unrotated node: basis.x == +X, and the enemy faces -Z (Vector3.FORWARD),
	# so +X is his RIGHT (cross(forward, up) = +X). A round from +X must play
	# death_from_right.
	var cases := [[Vector3(6, 0, 0), "death_from_right"], [Vector3(-6, 0, 0), "death_forward"]]
	for case in cases:
		var shot_from: Vector3 = case[0]
		var want_clip: String = str(case[1])
		var e := await _spawn(VC, Vector3(0, 0, 0))
		var attacker := Node3D.new()
		add_child(attacker)
		attacker.global_position = shot_from
		e.take_damage(9999, Enums.DamageType.PHYSICAL, attacker)
		await get_tree().process_frame
		var clip: String = e.sprite_actor.current_action if e.sprite_actor != null else "<none>"
		var dot: float = e.last_hit_dir.dot(Vector3.RIGHT)
		print("  shot from %s -> last_hit_dir.x=%+.2f -> clip=%s" % [shot_from, dot, clip])
		if not clip.begins_with("death"):
			_bad("death did not play a death clip, got %s" % clip)
		elif not _clip_matches(want_clip, clip):
			_bad("shot from %s should play %s, played %s (death direction inverted)" % [shot_from, want_clip, clip])
		# SpriteActor tracks finished/_m; a model just plays the clip. Either way
		# the clip name must be a death clip (asserted above).
		if not e._visual_is_model and not e.sprite_actor.finished and e.sprite_actor._m != null and e.sprite_actor._m.loop:
			_bad("death clip loops")
		attacker.queue_free()
		e.queue_free()
		await get_tree().process_frame


## _die() calls set_physics_process(false). If frame advance lived in
## _physics_process the corpse would freeze on frame 0 forever.
func _test_corpse_animates_with_physics_off() -> void:
	var e := await _spawn(VC, Vector3(0, 0, 0))
	var attacker := Node3D.new()
	add_child(attacker)
	attacker.global_position = Vector3(0, 0, -5)
	e.take_damage(9999, Enums.DamageType.PHYSICAL, attacker)
	await get_tree().process_frame
	if e.is_physics_processing():
		_bad("dead enemy still physics-processing")
	if e._visual_is_model:
		# Model: AnimationPlayer drives the corpse; assert a death clip is playing
		# and that it kept its own _process alive with physics off.
		print("  corpse (model): physics=%s clip=%s" % [e.is_physics_processing(), e.sprite_actor.current_action])
		if not str(e.sprite_actor.current_action).begins_with("death"):
			_bad("corpse is not playing a death clip: %s" % e.sprite_actor.current_action)
	else:
		var f0: int = e.sprite_actor.sprite.frame
		for i in range(200):
			e.sprite_actor._process(1.0 / 60.0)
		var f1: int = e.sprite_actor.sprite.frame
		print("  corpse (sprite): physics=%s frame %d -> %d finished=%s" % [
			e.is_physics_processing(), f0, f1, e.sprite_actor.finished])
		if f1 == f0:
			_bad("corpse frame never advanced - death animation frozen")
		if not e.sprite_actor.finished:
			_bad("death clip never reached its last frame")
	attacker.queue_free()
	e.queue_free()
	await get_tree().process_frame


## The sprite holds a weapon. The ballistics must agree with it.
func _test_sprite_ballistics_agree() -> void:
	# vc_rifleman fires the Mosin his model visibly carries (ADR-016 Amendment C
	# armory truth: SKS retired - no FP arms, and the export IS a Mosin).
	var pairs := [[VC, "mosin"], [NVA, "ppsh41"]]
	for pair in pairs:
		var data: EnemyData = load(str(pair[0]))
		var want: String = str(pair[1])
		if str(data.sprite_weapon) != want:
			_bad("%s sprite_weapon=%s, expected %s" % [pair[0], data.sprite_weapon, want])
		if not str(data.weapon_path).contains(want):
			_bad("%s weapon_path=%s does not match the sprite's %s" % [pair[0], data.weapon_path, want])
		var wd: WeaponData = load(str(data.weapon_path))
		if wd == null:
			_bad("%s weapon_path does not load" % pair[0])
		else:
			print("  %s: sprite holds %s, ballistics say %s (%s)" % [
				data.display_name, data.sprite_weapon, wd.id, wd.display_name])
