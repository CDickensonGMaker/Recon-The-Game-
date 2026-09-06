## probe_explosion_bloom.gd - item 10, THE OTHER HALF: "post-satchel orange blow-out".
##
## The scorch decal half was measured and fixed (tests/probe_scorch_decal.tscn). The
## FLASH was never measured at all - the recorded evidence named _scorch only.
##
## What actually fills the screen: GunFX._spawn_explosion_visual layer 1, an additive
## (BLEND_MODE_ADD) QuadMesh with emission_energy_multiplier 9.0 and albedo alpha 1.0,
## standing 0.6m off the ground, whose peak width is
##     FLASH_QUAD_M x root scale x FLASH_PEAK_SCALE
## and whose alpha does not know where the camera is. This walks a real Camera3D at the
## player's own FOV in to the blast and reports, through the real viewport projection,
## what fraction of the screen that quad covers at each distance.
##
##   godot --headless --path . res://tools/probe_explosion_bloom.tscn
extends Node

## The player's hip FOV (weapon_holder BASE_FOV) and eye height.
const PLAYER_FOV: float = 75.0
const EYE_Y: float = 1.7
## Standoffs that matter: 3m is a tunnel mouth he satchelled and turned around at, 8m
## is a bunker he blew from behind the next revetment, 30m is a proper standoff.
const DISTANCES: Array[float] = [3.0, 5.0, 8.0, 15.0, 30.0]
## The classes a satchel actually sets off: its own burst, plus the structure it kills
## (Destructible.BLAST_FOR maps bunker/hut to explosion_mortar) and the collapse pop.
const KINDS: Array[String] = ["explosion_grenade", "explosion_mortar", "explosion_heavy"]
## Screen-height fraction, times alpha, above which the frame reads as a blow-out
## rather than a flash. A flash you look at is fine; a flash you are inside is the
## defect he reported.
const BLOWOUT_CEILING: float = 0.60

var _failures: int = 0
var _cam: Camera3D = null


func _fail(msg: String) -> void:
	print("FAIL: %s" % msg)
	_failures += 1


func _ready() -> void:
	_run()


func _run() -> void:
	print("=== EXPLOSION BLOOM PROBE (item 10, the flash half) ===")
	_cam = Camera3D.new()
	_cam.fov = PLAYER_FOV
	_cam.near = 0.01
	add_child(_cam)
	_cam.current = true
	await get_tree().process_frame

	var vp: Vector2 = Vector2(get_viewport().get_visible_rect().size)
	print("  viewport %dx%d, camera FOV %.0f" % [int(vp.x), int(vp.y), PLAYER_FOV])
	print("  flash quad %.2fm x peak scale %.1f x ORDNANCE_VISUAL_MULT %.1f" % [
		GunFX.FLASH_QUAD_M, GunFX.FLASH_PEAK_SCALE, GunFX.ORDNANCE_VISUAL_MULT])
	print("")

	for kind in KINDS:
		var root_scale: float = GunFX.rendered_width_m(kind) / (2.2 * 1.05)
		var peak_w: float = GunFX.FLASH_QUAD_M * root_scale * GunFX.FLASH_PEAK_SCALE
		print("  %-18s root scale %5.1f -> peak flash %6.2fm wide" % [kind, root_scale, peak_w])
		for dist in DISTANCES:
			var at := Vector3(0.0, 0.0, -dist)
			_cam.global_position = Vector3(0.0, EYE_Y, 0.0)
			_cam.look_at(at, Vector3.UP)
			await get_tree().process_frame
			var quad: MeshInstance3D = _spawn_and_find(kind, at)
			if quad == null:
				_fail("%s at %.0fm: no flash quad found" % [kind, dist])
				continue
			var mat := quad.material_override as StandardMaterial3D
			var alpha: float = mat.albedo_color.a if mat != null else 1.0
			var cover: float = _screen_cover(quad.global_position, peak_w, vp)
			# The frame cannot be more than full: coverage over 100% is a useful
			# diagnostic of how far outside the screen the quad reaches, but the LOAD on
			# the eye is the painted fraction times how opaque it is.
			var load_read: float = minf(cover, 1.0) * alpha
			var verdict: String = "ok"
			if load_read > BLOWOUT_CEILING:
				verdict = "BLOW-OUT"
			print("      %5.1fm  screen height %5.0f%%  alpha %.2f  ->  %5.0f%%  %s" % [
				dist, cover * 100.0, alpha, load_read * 100.0, verdict])
			if load_read > BLOWOUT_CEILING:
				_fail("%s at %.0fm fills %.0f%% of screen height at alpha %.2f"
					% [kind, dist, cover * 100.0, alpha])
			_clear()
		print("")

	if _failures == 0:
		print("=== PASS ===")
	else:
		print("=== FAIL (%d) ===" % _failures)
	get_tree().quit(0 if _failures == 0 else 1)


## Fire one explosion and hand back its additive flash quad - the newest explosion
## root's own MeshInstance3D child, which is layer 1 and nothing else.
func _spawn_and_find(kind: String, at: Vector3) -> MeshInstance3D:
	GunFX.play_explosion_3d(self, at, kind)
	for i in range(get_child_count() - 1, -1, -1):
		var n: Node = get_child(i)
		if not (n is Node3D) or n is Camera3D or n is Decal:
			continue
		for c in n.get_children():
			if c is MeshInstance3D:
				return c as MeshInstance3D
	return null


## Screen-height fraction a billboard of this width covers, measured through the real
## camera projection - not trigonometry retyped here. A billboard always faces the
## camera, so its corners are camera-right and camera-up from its centre.
func _screen_cover(centre: Vector3, width_m: float, vp: Vector2) -> float:
	var up: Vector3 = _cam.global_transform.basis.y * (width_m * 0.5)
	var top: Vector3 = centre + up
	var bottom: Vector3 = centre - up
	# Behind the camera, or straddling it: it owns the whole frame.
	if _cam.is_position_behind(top) or _cam.is_position_behind(bottom):
		return 1.0
	var a: Vector2 = _cam.unproject_position(top)
	var b: Vector2 = _cam.unproject_position(bottom)
	return absf(a.y - b.y) / vp.y


func _clear() -> void:
	for i in range(get_child_count() - 1, -1, -1):
		var n: Node = get_child(i)
		if n is Camera3D:
			continue
		remove_child(n)
		n.queue_free()
	GunFX.reset_session()
