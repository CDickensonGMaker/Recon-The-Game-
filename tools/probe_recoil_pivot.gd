## probe_recoil_pivot.gd - measure each gun's geometry relative to the viewmodel
## root (the origin weapon_holder.gd's punch rotation pivots about) in the
## rifle_idle pose. Prints, per gun, in root-local metres (Godot -Z = forward):
## muzzle z, gun AABB z range, and the muzzle-rise vs stock-drop lever ratio a
## +pitch punch produces about that origin.
## Run: godot --headless --path . res://tools/probe_recoil_pivot.tscn
extends Node

const TRES: Dictionary = {
	"m16a1": "res://data/weapons/m16a1.tres",
	"shotgun": "res://data/weapons/shotgun.tres",
	"ak47": "res://data/weapons/ak47.tres",
	"ppsh41": "res://data/weapons/ppsh41.tres",
	"m14": "res://data/weapons/m14.tres",
}
const SCENES: Dictionary = {
	"m16a1": "res://scenes/weapons/m16a1_arms_viewmodel.tscn",
	"shotgun": "res://scenes/weapons/ithaca_arms_viewmodel.tscn",
	"ak47": "res://scenes/weapons/ak47_arms_viewmodel.tscn",
	"ppsh41": "res://scenes/weapons/ppsh_arms_viewmodel.tscn",
	"m14": "res://scenes/weapons/m14_arms_viewmodel.tscn",
}


func _ready() -> void:
	for gun: String in SCENES:
		_probe(gun, str(SCENES[gun]))
	get_tree().quit(0)


func _probe(gun: String, scene_path: String) -> void:
	var packed := load(scene_path) as PackedScene
	if packed == null:
		print("FAIL %s: cannot load %s" % [gun, scene_path])
		return
	var inst: Node3D = packed.instantiate() as Node3D
	add_child(inst)
	var ap := inst.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if ap != null and ap.has_animation("rifle_idle"):
		ap.play("rifle_idle")
		ap.seek(0.0, true)
	var root_inv: Transform3D = inst.global_transform.affine_inverse()
	var muzzle := inst.find_child("MuzzlePoint", true, false) as Node3D
	var mz: Vector3 = Vector3.INF
	if muzzle != null:
		mz = root_inv * muzzle.global_transform.origin
	var zmin: float = INF
	var zmax: float = -INF
	var ymin: float = INF
	var ymax: float = -INF
	for mi: MeshInstance3D in _gun_meshes(inst):
		var aabb: AABB = mi.get_aabb()
		var to_root: Transform3D = root_inv * mi.global_transform
		for i in range(8):
			var p: Vector3 = to_root * (aabb.position + Vector3(
				aabb.size.x * float(i & 1),
				aabb.size.y * float((i >> 1) & 1),
				aabb.size.z * float((i >> 2) & 1)))
			zmin = minf(zmin, p.z)
			zmax = maxf(zmax, p.z)
			ymin = minf(ymin, p.y)
			ymax = maxf(ymax, p.y)
	print("%s | muzzle z=%.3f y=%.3f | gun z[%.3f .. %.3f] y[%.3f .. %.3f]" % [
		gun, mz.z, mz.y, zmin, zmax, ymin, ymax])
	for sight_name in ["SightRear", "SightFront"]:
		var s := inst.find_child(sight_name, true, false) as Node3D
		if s != null:
			var sp: Vector3 = root_inv * s.global_transform.origin
			print("  %s z=%.3f y=%.3f" % [sight_name, sp.z, sp.y])
	_punch_math(gun, mz, Vector3(mz.x, mz.y, zmax), maxf(zmax, 0.0))
	inst.queue_free()


## Full-strength punch (punch_amt = 1) through the SAME math weapon_holder
## ships: pitch about the node origin (before), then plus punch_pivot_comp
## (after). Prints each point's vertical travel and the rise/drop ratio.
func _punch_math(gun: String, muzzle: Vector3, stock: Vector3, pivot_z: float) -> void:
	var wd: WeaponData = load(TRES[gun]) as WeaponData
	if wd == null:
		print("FAIL %s: weapon tres would not load" % gun)
		return
	var pitch: float = 3.5 * wd.recoil_vertical / 2.5
	var rot0: Vector3 = wd.hip_rotation
	var rot1: Vector3 = rot0 + Vector3(pitch, 0.0, 0.0)
	var b0 := Basis.from_euler(Vector3(
		deg_to_rad(rot0.x), deg_to_rad(rot0.y), deg_to_rad(rot0.z)))
	var b1 := Basis.from_euler(Vector3(
		deg_to_rad(rot1.x), deg_to_rad(rot1.y), deg_to_rad(rot1.z)))
	var comp: Vector3 = WeaponHolder.punch_pivot_comp(rot1, pitch, pivot_z)
	var mz_old: float = (b1 * muzzle - b0 * muzzle).y
	var st_old: float = (b1 * stock - b0 * stock).y
	var mz_new: float = mz_old + comp.y
	var st_new: float = st_old + comp.y
	print("  punch %.2f deg | BEFORE muzzle dy=%+.4f stock dy=%+.4f ratio=%.2f | AFTER muzzle dy=%+.4f stock dy=%+.4f ratio=%.2f" % [
		pitch, mz_old, st_old, _ratio(mz_old, st_old), mz_new, st_new, _ratio(mz_new, st_new)])


## Muzzle rise over stock drop; a stock that also rises reports INF-like 99.
func _ratio(mz_dy: float, st_dy: float) -> float:
	if st_dy >= 0.0:
		return 99.0 if mz_dy > 0.0 else 0.0
	return maxf(mz_dy, 0.0) / -st_dy


## Gun meshes only - arms/hands would smear the AABB rearward past the butt.
func _gun_meshes(inst: Node3D) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	var stack: Array[Node] = [inst]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for c in n.get_children():
			stack.append(c)
		var mi := n as MeshInstance3D
		if mi == null:
			continue
		var nm: String = mi.name.to_lower()
		if nm.contains("arm") or nm.contains("hand") or nm.contains("finger") \
				or nm.contains("sleeve") or nm.contains("glove"):
			continue
		out.append(mi)
	return out
