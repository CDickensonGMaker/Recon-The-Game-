## probe_flare_stays_put.gd - a flare must burn OVER THE POINT IT WAS POPPED.
##
## IllumFlare._ready() captured _anchor_x/_anchor_z, but pop() assigns
## global_position AFTER parent.add_child() - and add_child runs _ready
## synchronously when the parent is already in the tree. So the anchor was the
## flare's position at add_child time (its parent's origin), and the FIRST
## physics tick wrote `global_position.x = _anchor_x + swing`, teleporting the
## burning flare from where it was fired back to the world origin. Every caller
## parents to world / current_scene / _lights_root, all at or near (0,0,0), so
## in the shipped game every illum round lit the map origin.
##
## NEGATIVE CONTROL: run this against the pre-fix illum_flare.gd - "still lit
## after 2 physics frames" FAILS while "lit on the frame it pops" PASSES. That
## split is the signature of the anchor, not of the radius or the burn.
extends Node3D

var _failures: int = 0
## Far enough from the origin that a snap-back leaves the circle (LIGHT_RADIUS 30).
const POP_AT := Vector3(0, 0, 45)


func _ready() -> void:
	SimClock.paused = true
	call_deferred("_run")


func _expect(ok: bool, what: String) -> void:
	print(("  PASS  " if ok else "  FAIL  ") + what)
	if not ok:
		_failures += 1


func _run() -> void:
	print("=== PROBE: A FLARE BURNS WHERE IT WAS POPPED ===")
	var flare: IllumFlare = IllumFlare.pop(self, POP_AT)
	_expect(flare != null, "pop() returned a flare")
	if flare == null:
		get_tree().quit(1)
		return
	print("  pop point (%.1f, %.1f) | flare at (%.1f, %.1f)"
		% [POP_AT.x, POP_AT.z, flare.global_position.x, flare.global_position.z])
	_expect(IllumFlare.is_lit(POP_AT), "lit over the pop point on the frame it pops")
	_expect(not IllumFlare.is_lit(Vector3.ZERO),
		"CONTROL: the world origin, 45m away, is NOT lit by this flare")

	for _i in range(2):
		await get_tree().physics_frame
	print("  after 2 physics frames: flare at (%.1f, %.1f, %.1f)"
		% [flare.global_position.x, flare.global_position.y, flare.global_position.z])
	_expect(IllumFlare.is_lit(POP_AT), "STILL lit over the pop point after 2 physics frames")
	var drift_xz: float = Vector2(flare.global_position.x - POP_AT.x,
		flare.global_position.z - POP_AT.z).length()
	_expect(drift_xz <= IllumFlare.SWING_M * 1.5,
		"horizontal travel is canopy swing, not a teleport (%.1fm)" % drift_xz)
	_expect(flare.global_position.y < 40.0 and flare.global_position.y > 30.0,
		"the flare is descending under its canopy (y=%.1f)" % flare.global_position.y)

	flare.queue_free()
	await get_tree().process_frame
	print("")
	if _failures == 0:
		print("probe_flare_stays_put: PASS")
		get_tree().quit(0)
	else:
		push_error("FLARE ANCHOR: %d assertion(s) failed." % _failures)
		print("probe_flare_stays_put: %d FAILURES" % _failures)
		get_tree().quit(1)
