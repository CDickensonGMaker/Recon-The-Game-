## test_gib_dressing.gd - a popped head must keep the face the man was wearing.
##
## GruntDresser slides a grunt's face by duplicating the atlas material and
## setting uv1_offset as a per-surface OVERRIDE on the donor MeshInstance3D. The
## Mesh resource underneath is the shared stock cell. GibSystem clones the donor
## to build the flying piece - clone the Mesh alone and the head changes face in
## mid-air, at the exact moment the player is staring at it.
##
## NEGATIVE CONTROL (case 3): a bare Mesh clone of the same donor is built
## alongside and must show the DEFAULT cell. If it ever matches the dressed face,
## the whole comparison is vacuous and this probe says so.
##
## Run: godot --headless --path . res://tests/test_gib_dressing.tscn
extends Node3D

const FACE_CELL: int = 42

var _failures: int = 0


func _fail(msg: String) -> void:
	print("FAIL: %s" % msg)
	_failures += 1


func _ready() -> void:
	await get_tree().process_frame
	await _run()


func _run() -> void:
	var ally: AllyBase = AllyBase.spawn_ally(self, Vector3.ZERO)
	ally.member = {"name": "Gib Probe", "face": FACE_CELL, "helmet": "m1_ace"}
	ally.dress_visual()
	await get_tree().process_frame

	var ma := ally.sprite_actor as ModelActor
	var root: Node3D = ma.instance_root() if ma != null else null
	if root == null:
		_fail("no model root - probe is blind")
		_finish()
		return

	# 1. the donor wears the dressed face BEFORE anything is popped.
	var donor := root.find_child("grunt_head", true, false) as MeshInstance3D
	if donor == null:
		_fail("no grunt_head donor on %s - probe is blind" % ma.unit)
		_finish()
		return
	var worn: Array[Vector3] = _face_offsets(donor)
	var expected := Vector3(
		(FACE_CELL % GruntDresser.FACE_COLS) / float(GruntDresser.FACE_COLS),
		int(FACE_CELL / float(GruntDresser.FACE_COLS)) % GruntDresser.FACE_ROWS
			/ float(GruntDresser.FACE_ROWS), 0.0)
	if worn.is_empty():
		_fail("head donor carries no face override - dressing never reached it, probe is blind")
		_finish()
		return
	for o in worn:
		if not o.is_equal_approx(expected):
			_fail("head donor wears %s, record says cell %d -> %s" % [o, FACE_CELL, expected])
	print("  living man wears cell %d at %s (%d face surfaces)" % [FACE_CELL, expected, worn.size()])

	# 2. pop the head and read the face off the gib that flew.
	var before: int = _rigid_count()
	GibSystem.dismember(ma, "HEAD", Vector3.FORWARD, self)
	await get_tree().process_frame
	var gibs: Array[MeshInstance3D] = _gib_meshes()
	if _rigid_count() <= before:
		_fail("dismember spawned no gib body - nothing to check")
		_finish()
		return
	var found: bool = false
	for g in gibs:
		var offs: Array[Vector3] = _face_offsets(g)
		if offs.is_empty():
			continue
		found = true
		for o in offs:
			if not o.is_equal_approx(expected):
				_fail("gib wears face %s, the man wore %s - the face changed at the moment of death"
					% [o, expected])
	if not found:
		_fail("no gib carries ANY face override - the clone dropped the dressing (bead 2whe)")
	else:
		print("  gib keeps cell %d at %s" % [FACE_CELL, expected])

	# 3. negative control: the same donor cloned mesh-only, the pre-fix behaviour.
	var naked := MeshInstance3D.new()
	naked.mesh = donor.mesh
	add_child(naked)
	var naked_offs: Array[Vector3] = _face_offsets(naked)
	var naked_dressed: bool = false
	for o in naked_offs:
		if o.is_equal_approx(expected):
			naked_dressed = true
	if naked_dressed:
		_fail("NEGATIVE CONTROL DEAD: a mesh-only clone already wears cell %d, so this probe cannot tell a dressed gib from an undressed one"
			% FACE_CELL)
	else:
		print("  negative control holds: a mesh-only clone shows %d face override(s), none of them the man's"
			% naked_offs.size())

	_finish()


func _finish() -> void:
	if _failures == 0:
		print("PASS: gibs fly wearing the face the man died in")
		get_tree().quit(0)
	else:
		print("FAILED: %d violations" % _failures)
		get_tree().quit(1)


func _rigid_count() -> int:
	var n: int = 0
	for c in get_children():
		if c is RigidBody3D:
			n += 1
	return n


func _gib_meshes() -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	for c in get_children():
		if not (c is RigidBody3D):
			continue
		for g in c.get_children():
			var mi := g as MeshInstance3D
			if mi != null:
				out.append(mi)
	return out


## uv1 offsets of every face-atlas material this MeshInstance3D actually renders
## with (overrides only - the shared Mesh material is by definition undressed).
func _face_offsets(mi: MeshInstance3D) -> Array[Vector3]:
	var out: Array[Vector3] = []
	if mi.mesh == null:
		return out
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
