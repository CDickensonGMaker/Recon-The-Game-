## probe_eject.gd - can Godot actually drive shell ejection off the authored gun
## clips? Answers four questions with facts instead of confidence:
##   1. Is `eject_*` reachable at runtime, and is it a Node3D or a Skeleton3D bone?
##   2. Does it MOVE during the fire clip (i.e. is it animated, or authored static)?
##   3. Are the imported animations writable - can a Call Method track be added?
##   4. Does the `jam` clip exist and how long is it?
## Run: godot --path . res://tests/probe_eject.tscn
extends Node3D

const VIEWMODEL := preload("res://scenes/weapons/m16a1_arms_viewmodel.tscn")


func _ready() -> void:
	var vm: Node3D = VIEWMODEL.instantiate()
	add_child(vm)
	await get_tree().process_frame

	var anim: AnimationPlayer = vm.find_child("AnimationPlayer", true, false) as AnimationPlayer
	print("PROBE animation_player=%s" % (anim != null))
	if anim:
		print("PROBE clips=%s" % [anim.get_animation_list()])
		for c in ["fire", "jam", "charge_handle", "reload", "reload_empty"]:
			if anim.has_animation(c):
				var a: Animation = anim.get_animation(c)
				print("PROBE clip %-14s len=%.3fs tracks=%d read_only=%s"
					% [c, a.length, a.get_track_count(), a.resource_path.is_empty() == false])

	# 1+2. the ejection marker
	var ej: Node = vm.find_child("eject_M16A1", true, false)
	print("PROBE eject node found=%s class=%s" % [ej != null, ej.get_class() if ej else "-"])

	var skel: Skeleton3D = vm.find_child("*Skeleton*", true, false) as Skeleton3D
	if skel == null:
		for n in vm.find_children("*", "Skeleton3D", true, false):
			skel = n as Skeleton3D
			break
	if skel:
		var idx: int = skel.find_bone("eject_M16A1")
		print("PROBE skeleton=%s bones=%d eject_bone_idx=%d" % [skel.name, skel.get_bone_count(), idx])
		if idx >= 0 and anim and anim.has_animation("fire"):
			# 2. sample the bone across the fire clip
			var a: Animation = anim.get_animation("fire")
			var samples: Array = []
			for f in [0.0, 0.25, 0.5, 0.75, 1.0]:
				anim.play("fire")
				anim.seek(a.length * f, true)
				await get_tree().process_frame
				var t: Transform3D = skel.get_bone_global_pose(idx)
				samples.append(t.origin)
			var moved: float = 0.0
			for i in range(1, samples.size()):
				moved = maxf(moved, (samples[i] - samples[0]).length())
			print("PROBE eject bone travel across fire clip = %.4f m -> %s"
				% [moved, "ANIMATED" if moved > 0.001 else "STATIC (a mount point)"])
			print("PROBE eject bone rest pos = %s" % [samples[0]])

	# 3. can we add a Call Method track at runtime?
	if anim and anim.has_animation("fire"):
		var a: Animation = anim.get_animation("fire")
		var before: int = a.get_track_count()
		var ti: int = a.add_track(Animation.TYPE_METHOD)
		var ok: bool = ti >= 0 and a.get_track_count() > before
		print("PROBE add method track at runtime = %s (path=%s)"
			% [ok, a.resource_path if not a.resource_path.is_empty() else "<embedded, not saved>"])
		if ok:
			a.remove_track(ti)

	print("PROBE done")
	get_tree().quit()
