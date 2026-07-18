## test_grunt_dresser.gd - the skin/face pairing law, probed.
##   1. After dress(), EVERY grunt_face_skin surface on the man carries the SAME
##      uv1_offset, and it is the offset of the face cell dress() reported -
##      skin tone and face are one material and can never mismatch.
##   2. Materials are per-instance: two men dressed with different faces keep
##      different offsets (no shared-material octuplets).
##   3. Role lock: spawn(role) returns that unit; roles() excludes base rigs.
##   4. Radio law: RADIO_FORBIDDEN units refuse radio:true.
##   5. Helmet swap: stock helmet hidden, variant hangs off a HelmetSocket.
##   6. Seed determinism: same seed -> same unit + loadout.
## Run: godot --headless --path . res://tests/test_grunt_dresser.tscn
extends Node3D

var _failures: int = 0


func _ready() -> void:
	await get_tree().process_frame
	_run()


func _fail(msg: String) -> void:
	print("FAIL: %s" % msg)
	_failures += 1


func _run() -> void:
	var pool: Array[String] = GruntRandomizer.roles()
	print("roles on disk: %s" % str(pool))
	if pool.is_empty():
		_fail("GruntRandomizer.roles() is empty - no US units found")
		_finish()
		return
	for banned in GruntRandomizer.NON_ROLES:
		if pool.has(banned):
			_fail("base rig %s leaked into the role list" % banned)

	_check_face_consistency_all_roles(pool)
	_check_legacy_face_only()
	_check_material_isolation(pool[0])
	_check_role_lock(pool)
	_check_radio_law()
	_check_determinism()
	_finish()


## 1. Every role: dress, then every face surface shares the reported cell offset.
func _check_face_consistency_all_roles(pool: Array[String]) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1968
	for unit in pool:
		var got: Dictionary = GruntRandomizer.spawn(self, rng, unit)
		if got.is_empty():
			_fail("%s: spawn failed" % unit)
			continue
		var actor: ModelActor = got["actor"]
		var face: int = int(got["loadout"].get("face", -1))
		if face < 0 or face >= GruntDresser.FACE_COLS * GruntDresser.FACE_ROWS:
			_fail("%s: face index %d out of atlas range" % [unit, face])
		var expected := Vector3(
			(face % GruntDresser.FACE_COLS) / float(GruntDresser.FACE_COLS),
			int(face / float(GruntDresser.FACE_COLS)) % GruntDresser.FACE_ROWS
				/ float(GruntDresser.FACE_ROWS), 0.0)
		var offsets: Array[Vector3] = _face_offsets(actor)
		if offsets.is_empty():
			_fail("%s: no face-material surfaces after dress - dresser cannot reach this unit's skin (face randomize is a NO-OP)" % unit)
		for off in offsets:
			if not off.is_equal_approx(expected):
				_fail("%s: face surface offset %s != cell %d offset %s - SKIN/FACE MISMATCH" % [unit, off, face, expected])
				break
		var helmet: String = String(got["loadout"].get("helmet", ""))
		if not helmet.is_empty():
			_check_helmet(actor, unit)
		print("  %-20s face=%2d surfaces=%d helmet=%s OK-so-far" % [unit, face, offsets.size(), helmet])
		actor.queue_free()


## 1b. Legacy body (no stock-helmet contract): dress_actor slides the face but
## hangs NO helmet - the welded pot stays, nothing is hidden bare.
func _check_legacy_face_only() -> void:
	const LEGACY := "us_grunt_v2"
	if not ModelActor.model_exists(LEGACY):
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = 60
	var actor := ModelActor.new()
	add_child(actor)
	if not actor.setup(LEGACY):
		_fail("legacy: setup failed on %s" % LEGACY)
		return
	var out: Dictionary = GruntRandomizer.dress_actor(actor, rng)
	if _face_offsets(actor).is_empty():
		_fail("legacy %s: face did not slide (face-only dressing broken)" % LEGACY)
	if not String(out.get("helmet", "x")).is_empty():
		_fail("legacy %s: dresser hung helmet '%s' on a body with no stock-helmet contract"
			% [LEGACY, String(out.get("helmet", ""))])
	var skel: Skeleton3D = actor.skeleton()
	if skel != null and skel.find_child("HelmetSocket", false, false) != null:
		_fail("legacy %s: HelmetSocket attached without the contract" % LEGACY)
	print("  legacy face-only OK (%s keeps his welded pot)" % LEGACY)
	actor.queue_free()


## 2. Two men, two faces, one GLB: offsets must differ per instance.
func _check_material_isolation(unit: String) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var a := ModelActor.new()
	var b := ModelActor.new()
	add_child(a)
	add_child(b)
	if not a.setup(unit) or not b.setup(unit):
		_fail("isolation: setup failed on %s" % unit)
		return
	GruntDresser.dress(a, rng, {"face": 3, "helmet": false})
	GruntDresser.dress(b, rng, {"face": 42, "helmet": false})
	var off_a: Array[Vector3] = _face_offsets(a)
	var off_b: Array[Vector3] = _face_offsets(b)
	if off_a.is_empty() or off_b.is_empty():
		_fail("isolation: no face surfaces on %s" % unit)
	elif off_a[0].is_equal_approx(off_b[0]):
		_fail("isolation: both instances share offset %s - material not duplicated (octuplet bug)" % off_a[0])
	else:
		print("  isolation: %s vs %s OK (per-instance materials)" % [off_a[0], off_b[0]])
	a.queue_free()
	b.queue_free()


## 3. Locking a role returns exactly that unit, across seeds.
func _check_role_lock(pool: Array[String]) -> void:
	var rng := RandomNumberGenerator.new()
	for i in 3:
		rng.seed = 100 + i
		var role: String = pool[i % pool.size()]
		var got: Dictionary = GruntRandomizer.spawn(self, rng, role)
		if got.is_empty() or String(got["unit"]) != role:
			_fail("role lock: asked %s got %s" % [role, str(got.get("unit", "nothing"))])
		if not got.is_empty():
			(got["actor"] as Node).queue_free()
	print("  role lock OK")


## 4. A forbidden unit asked for a radio must come back radio=false.
func _check_radio_law() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for unit in ModelActor.RADIO_FORBIDDEN:
		if not ModelActor.model_exists(unit):
			continue
		var actor := ModelActor.new()
		add_child(actor)
		if not actor.setup(unit):
			actor.queue_free()
			continue
		var out: Dictionary = GruntDresser.dress(actor, rng, {"radio": true, "helmet": false})
		if bool(out.get("radio", false)):
			_fail("radio law: %s accepted a radio it cannot carry" % unit)
		actor.queue_free()
	print("  radio law OK")


## 5. Stock helmet hidden, a variant hangs on the head bone.
func _check_helmet(actor: ModelActor, unit: String) -> void:
	var root: Node3D = actor.instance_root()
	var stock: MeshInstance3D = null
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for c in n.get_children():
			stack.push_back(c)
		if n is MeshInstance3D and String(n.name).contains(GruntDresser.STOCK_HELMET):
			stock = n as MeshInstance3D
	if stock == null:
		_fail("%s: no stock helmet mesh (%s)" % [unit, GruntDresser.STOCK_HELMET])
		return
	if stock.visible:
		_fail("%s: stock helmet still visible under the variant (double helmet)" % unit)
	var skel: Skeleton3D = actor.skeleton()
	var socket: Node = skel.find_child("HelmetSocket", false, false) if skel != null else null
	if socket == null or socket.get_child_count() == 0:
		_fail("%s: helmet variant not attached (no HelmetSocket child)" % unit)
	# dress() is NOT re-entrant: a second call would stack a second socket and
	# GibSystem finds the socket by name. One dress per actor, exactly one socket.
	var sockets: int = 0
	if skel != null:
		for c in skel.get_children():
			if String(c.name).begins_with("HelmetSocket"):
				sockets += 1
	if sockets > 1:
		_fail("%s: %d HelmetSockets stacked - dress() called twice on one actor" % [unit, sockets])


## 6. Same seed, no role lock -> identical unit + loadout.
func _check_determinism() -> void:
	var l1: Dictionary = _seeded_loadout(31337)
	var l2: Dictionary = _seeded_loadout(31337)
	if l1.is_empty() or str(l1) != str(l2):
		_fail("determinism: seed 31337 gave %s then %s" % [str(l1), str(l2)])
	else:
		print("  determinism OK: %s" % str(l1))


func _seeded_loadout(seed_v: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var got: Dictionary = GruntRandomizer.spawn(self, rng)
	if got.is_empty():
		return {}
	(got["actor"] as Node).queue_free()
	return got["loadout"]


func _face_offsets(actor: ModelActor) -> Array[Vector3]:
	var out: Array[Vector3] = []
	var root: Node3D = actor.instance_root()
	if root == null:
		return out
	var stack: Array[Node] = [root]
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
			var is_face: bool = false
			for prefix in GruntDresser.FACE_MATERIALS:
				if m.resource_name.begins_with(prefix):
					is_face = true
					break
			if not is_face:
				continue
			var bm := m as BaseMaterial3D
			if bm != null:
				out.append(bm.uv1_offset)
	return out


func _finish() -> void:
	if _failures == 0:
		print("PASS: grunt dresser law holds (skin/face pairing, isolation, role lock, radio, helmet, seed)")
		get_tree().quit(0)
	else:
		print("FAILED: %d violations" % _failures)
		get_tree().quit(1)
