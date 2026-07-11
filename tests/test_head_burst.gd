## test_head_burst.gd - HEAD BURST engine path probe (bead rc55).
## The us_grunt_v2 rig now SHIPS real head_frag_* chunks (tools/make_head_frags.py
## cuts grunt_head into 6-9 bisect fragments, gore interiors, rigid Head skin).
## Asserts:
##   0. REAL rig: us_grunt_v2 carries >= 6 head_frag_* meshes and
##      dismember_head_burst returns TRUE without any fabricated frags.
##   1. Fallback: a rig stripped of its frags -> false (callers fall back to
##      the one-piece dismember("HEAD") pop).
##   2. Fabricated fragments (engine-path isolation) -> true; frags hidden on
##      the rig; N RigidBody3D fragments flying; one-piece head donor hidden.
##   3. Frag FIFO cap holds (MAX_LIVE_FRAGS).
## Run: godot --headless --path . res://tests/test_head_burst.tscn
extends Node3D


func _ready() -> void:
	await get_tree().process_frame
	_run()


func _make_actor() -> ModelActor:
	var holder := Node3D.new()
	add_child(holder)
	var model := ModelActor.new()
	holder.add_child(model)
	model.setup("us_grunt_v2")
	return model


## Remove the shipped head_frag_* meshes from a live rig (fallback/fabrication
## cases need a frag-less skeleton). Returns how many were stripped.
func _strip_frags(model: ModelActor) -> int:
	var stripped: int = 0
	for n in _walk(model.instance_root()):
		var mi := n as MeshInstance3D
		if mi != null and String(mi.name).begins_with("head_frag_"):
			mi.get_parent().remove_child(mi)
			mi.free()
			stripped += 1
	return stripped


func _count_frags(model: ModelActor) -> int:
	var count: int = 0
	for n in _walk(model.instance_root()):
		var mi := n as MeshInstance3D
		if mi != null and mi.mesh != null and String(mi.name).begins_with("head_frag_"):
			count += 1
	return count


func _run() -> void:
	var failures: int = 0

	# --- 0. REAL rig: shipped fragments burst without fabrication
	var m0: ModelActor = _make_actor()
	var real_frags: int = _count_frags(m0)
	print("  us_grunt_v2 ships %d head_frag_* meshes" % real_frags)
	if real_frags < 6:
		print("FAIL: real rig ships %d fragments (rc55 wants >= 6)" % real_frags)
		failures += 1
	var before0: int = _count_rigid_bodies()
	if not GibSystem.dismember_head_burst(m0, Vector3.FORWARD, self):
		print("FAIL: burst refused the REAL us_grunt_v2 rig (shipped frags)")
		failures += 1
	else:
		var spawned0: int = _count_rigid_bodies() - before0
		if spawned0 < real_frags:
			print("FAIL: real burst spawned %d bodies (want >= %d)" % [spawned0, real_frags])
			failures += 1
		else:
			print("  REAL burst OK: %d flying pieces from shipped fragments" % spawned0)

	# --- 1. no fragments -> false (strip the shipped ones first)
	var m1: ModelActor = _make_actor()
	var stripped: int = _strip_frags(m1)
	if GibSystem.dismember_head_burst(m1, Vector3.FORWARD, self):
		print("FAIL: burst claimed success on a rig with no head_frag_* meshes")
		failures += 1
	else:
		print("  no-frag fallback OK (returns false after stripping %d)" % stripped)

	# --- 2. fabricate fragments, burst (engine-path isolation)
	var m2: ModelActor = _make_actor()
	_strip_frags(m2)
	var skel: Skeleton3D = m2.skeleton()
	var frag_count: int = 6
	for i in range(frag_count):
		var mi := MeshInstance3D.new()
		mi.name = "head_frag_%02d" % (i + 1)
		var box := BoxMesh.new()
		box.size = Vector3(0.05, 0.05, 0.05)
		mi.mesh = box
		skel.add_child(mi)
	var before_bodies: int = _count_rigid_bodies()
	if not GibSystem.dismember_head_burst(m2, Vector3.FORWARD, self):
		print("FAIL: burst refused a rig WITH fragments")
		failures += 1
	else:
		var spawned: int = _count_rigid_bodies() - before_bodies
		# helmet gear may add a piece; at least frag_count must fly
		if spawned < frag_count:
			print("FAIL: only %d rigid bodies spawned (want >= %d)" % [spawned, frag_count])
			failures += 1
		else:
			print("  burst spawned %d flying pieces OK" % spawned)
		var visible_frags: int = 0
		for n in _walk(m2.instance_root()):
			var mi2 := n as MeshInstance3D
			if mi2 != null and String(mi2.name).begins_with("head_frag_") and mi2.visible:
				visible_frags += 1
		if visible_frags > 0:
			print("FAIL: %d fragments still visible on the rig after burst" % visible_frags)
			failures += 1
		var head_donor: MeshInstance3D = m2.instance_root().find_child("grunt_head", true, false) as MeshInstance3D
		if head_donor != null and head_donor.visible:
			print("FAIL: one-piece head donor visible after burst (double head)")
			failures += 1

	# --- 3. FIFO cap
	for round_i in range(3):
		var mx: ModelActor = _make_actor()
		_strip_frags(mx)
		var skx: Skeleton3D = mx.skeleton()
		for i in range(8):
			var mi3 := MeshInstance3D.new()
			mi3.name = "head_frag_%02d" % (i + 1)
			var box2 := BoxMesh.new()
			box2.size = Vector3(0.04, 0.04, 0.04)
			mi3.mesh = box2
			skx.add_child(mi3)
		GibSystem.dismember_head_burst(mx, Vector3.FORWARD, self)
	var live: int = 0
	for f in GibSystem._live_frags:
		if is_instance_valid(f):
			live += 1
	if live > GibSystem.MAX_LIVE_FRAGS:
		print("FAIL: %d live frags exceed cap %d" % [live, GibSystem.MAX_LIVE_FRAGS])
		failures += 1
	else:
		print("  frag FIFO holds (%d <= %d)" % [live, GibSystem.MAX_LIVE_FRAGS])

	if failures == 0:
		print("PASS: head burst engine path (real rig + fallback + burst + FIFO) OK")
	else:
		print("FAIL: head burst probe had %d failure(s)" % failures)
	get_tree().quit(1 if failures > 0 else 0)


func _count_rigid_bodies() -> int:
	var n: int = 0
	for c in get_children():
		if c is RigidBody3D:
			n += 1
	return n


func _walk(root: Node) -> Array[Node]:
	var out: Array[Node] = []
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		out.append(n)
		for c in n.get_children():
			stack.push_back(c)
	return out
