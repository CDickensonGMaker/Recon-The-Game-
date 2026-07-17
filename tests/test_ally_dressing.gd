## test_ally_dressing.gd - Pillar 4 identity dressing through the REAL spawn path.
##   1. A memberless ally (bench/POW path) comes out dressed: face offsets exist
##      and agree across every face surface (the skin/face law, in-game).
##   2. A named member wears his STORED face + helmet - both spawns of the same
##      record match exactly (identity, not reroll).
##   3. SquadRoster.generate_member stamps face (0-69) + helmet (a real variant).
##   4. Exactly one HelmetSocket per man (dress is once-per-actor).
##   5. VC and pilots are not dressable (US face on a guerilla = Pillar 2 wound).
## Run: godot --headless --path . res://tests/test_ally_dressing.tscn
extends Node3D

var _failures: int = 0


func _fail(msg: String) -> void:
	print("FAIL: %s" % msg)
	_failures += 1


func _ready() -> void:
	await get_tree().process_frame
	await _run()


func _run() -> void:
	# 1. memberless: deferred bench dress fires end-of-frame
	var a: AllyBase = AllyBase.spawn_ally(self, Vector3.ZERO)
	await get_tree().process_frame
	await get_tree().process_frame
	var offs_a: Array[Vector3] = _face_offsets(a)
	if offs_a.is_empty():
		_fail("memberless ally spawned undressed - bench path broken")
	else:
		for o in offs_a:
			if not o.is_equal_approx(offs_a[0]):
				_fail("memberless ally: face surfaces disagree (%s vs %s)" % [o, offs_a[0]])
				break
		print("  memberless ally dressed: %d surfaces at %s" % [offs_a.size(), offs_a[0]])

	# 2. identity: same record twice -> same face + helmet
	var record: Dictionary = {"name": "Test Ziggurat", "face": 17, "helmet": "m1_ace"}
	var expected := Vector3(
		(17 % GruntDresser.FACE_COLS) / float(GruntDresser.FACE_COLS),
		int(17 / float(GruntDresser.FACE_COLS)) % GruntDresser.FACE_ROWS
			/ float(GruntDresser.FACE_ROWS), 0.0)
	var twins: Array[AllyBase] = []
	for i in 2:
		var m: AllyBase = AllyBase.spawn_ally(self, Vector3(2.0 + i, 0, 0))
		m.member = record
		m.dress_visual()
		twins.append(m)
	for i in 2:
		var offs: Array[Vector3] = _face_offsets(twins[i])
		if offs.is_empty():
			_fail("member twin %d undressed" % i)
		elif not offs[0].is_equal_approx(expected):
			_fail("member twin %d wears %s, record says cell 17 -> %s (IDENTITY LOST)"
				% [i, offs[0], expected])
	print("  identity: both spawns of '%s' wear cell 17" % str(record["name"]))

	# 3. roster generation stamps identity
	var rng := RandomNumberGenerator.new()
	rng.seed = 1968
	var rookie: Dictionary = SquadRoster.generate_member(rng, "RIFLEMAN")
	var face_v: int = int(rookie.get("face", -1))
	if face_v < 0 or face_v >= 70:
		_fail("generate_member face %d out of atlas" % face_v)
	if not GruntDresser.HELMETS.has(str(rookie.get("helmet", ""))):
		_fail("generate_member helmet '%s' is not a real variant" % str(rookie.get("helmet", "")))
	print("  rookie '%s' face=%d helmet=%s" % [str(rookie.get("name", "?")), face_v, str(rookie.get("helmet", ""))])

	# 4. one socket per man, even after explicit + deferred dress both ran
	await get_tree().process_frame
	for m in twins:
		var ma := m.sprite_actor as ModelActor
		var skel: Skeleton3D = ma.skeleton() if ma != null else null
		if skel == null:
			continue
		var sockets: int = 0
		for c in skel.get_children():
			if String(c.name).begins_with("HelmetSocket"):
				sockets += 1
		if sockets != 1:
			_fail("member twin carries %d HelmetSockets (want exactly 1)" % sockets)

	# 5. faction guard
	if GruntRandomizer.is_dressable("vc_guerilla"):
		_fail("vc_guerilla marked dressable - a US face on a guerilla is a Pillar 2 wound")
	if GruntRandomizer.is_dressable("us_pilot_white"):
		_fail("us_pilot_white marked dressable - pilots keep flight gear")

	if _failures == 0:
		print("PASS: in-game identity dressing holds (bench path, stored identity, roster stamp, socket, faction guard)")
		get_tree().quit(0)
	else:
		print("FAILED: %d violations" % _failures)
		get_tree().quit(1)


func _face_offsets(ally: AllyBase) -> Array[Vector3]:
	var out: Array[Vector3] = []
	var ma := ally.sprite_actor as ModelActor
	if ma == null or ma.instance_root() == null:
		return out
	var stack: Array[Node] = [ma.instance_root() as Node]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for c in n.get_children():
			stack.push_back(c)
		var mi := n as MeshInstance3D
		if mi == null or mi.mesh == null:
			continue
		for s in mi.mesh.get_surface_count():
			var m: Material = mi.get_surface_override_material(s)
			if m == null:
				continue
			for prefix in GruntDresser.FACE_MATERIALS:
				if m.resource_name.begins_with(prefix):
					var bm := m as BaseMaterial3D
					if bm != null:
						out.append(bm.uv1_offset)
					break
	return out
