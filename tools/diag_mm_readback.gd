extends SceneTree
## Is MultiMesh.get_instance_transform trustworthy in this engine build?

func _init() -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = BoxMesh.new()
	mm.instance_count = 3
	var want := Transform3D(Basis(Vector3.UP, 1.0), Vector3(123.0, 45.0, 678.0))
	mm.set_instance_transform(1, want)
	var got: Transform3D = mm.get_instance_transform(1)
	print("[MM] set origin %s  get origin %s" % [str(want.origin), str(got.origin)])
	var buf: PackedFloat32Array = mm.buffer
	print("[MM] buffer size %d (expect 36 for 3x TRANSFORM_3D)" % buf.size())
	if buf.size() >= 24:
		print("[MM] buffer instance1 origin row: %.1f %.1f %.1f" % [buf[15], buf[19], buf[23]])
	print("[MM] readback %s" % ("OK" if got.origin.is_equal_approx(want.origin) else "BROKEN"))
	quit(0)
