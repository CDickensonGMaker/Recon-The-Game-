extends Node3D
const VIEWMODEL := preload("res://scenes/weapons/m16a1_arms_viewmodel.tscn")
func _ready() -> void:
	var vm: Node3D = VIEWMODEL.instantiate()
	add_child(vm)
	await get_tree().process_frame
	var anim: AnimationPlayer = vm.find_child("AnimationPlayer", true, false) as AnimationPlayer
	var a: Animation = anim.get_animation("fire")
	var hits: Array = []
	for i in range(a.get_track_count()):
		var p := String(a.track_get_path(i))
		if p.contains("eject") or p.contains("port_cover") or p.contains("charge_handle"):
			hits.append("%s [%s]" % [p, a.track_get_type(i)])
	print("PROBE fire-clip tracks touching eject/port/charge: %d" % hits.size())
	for h in hits:
		print("   " + h)
	var ej: Node3D = vm.find_child("eject_M16A1", true, false) as Node3D
	if ej:
		print("PROBE eject parent=%s" % ej.get_parent().name)
		var seen: Array = []
		for f in [0.0, 0.5, 1.0]:
			anim.play("fire"); anim.seek(a.length * f, true)
			await get_tree().process_frame
			seen.append(ej.global_transform.origin)
		print("PROBE eject world pos t0=%s  t50=%s  t100=%s" % seen)
		print("PROBE eject travel = %.4f m" % (seen[1] - seen[0]).length())
		print("PROBE eject local basis -X (port faces) = %s" % [ej.global_transform.basis.x])
	get_tree().quit()
