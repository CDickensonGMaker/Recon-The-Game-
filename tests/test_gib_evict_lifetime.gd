## test_gib_evict_lifetime.gd - a gib evicted by the live cap must not leave its
## despawn timer pointing at freed memory.
##
## _spawn_frag/_spawn_gib arm a gib_lifetime_s despawn timer per body, and the
## MAX_LIVE_FRAGS / MAX_LIVE_GIBS eviction directly above frees the oldest bodies
## while those timers are still pending. Both spawners are STATIC, so the timer
## callback has no self to disconnect from when the body dies: it always fires. A
## lambda that CAPTURES the body therefore calls into a freed Object, which GDScript
## rejects before the body runs ("Lambda capture at index 0 was freed"). Resolving the
## body by instance id instead is the only guard that works from inside.
##
## This is not cosmetic: a firefight evicts gibs in bursts, so the errors arrive in
## bursts too (6-26 per run measured), and the runner counts any ERROR: line as fatal.
## That is what made test_firefight_len flake at 25% of runs.
## Run: godot --headless --path . res://tests/test_gib_evict_lifetime.tscn
extends Node3D

const OVERFLOW: int = 8
const SHORT_LIFETIME_S: float = 1.0

var _failures: int = 0


func _ready() -> void:
	print("=== GIB EVICT LIFETIME probe (despawn timer vs the live cap) ===")
	await _run()


func _fail(msg: String) -> void:
	print("FAIL: %s" % msg)
	_failures += 1


func _donor() -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.2, 0.2, 0.2)
	mi.mesh = bm
	add_child(mi)
	return mi


func _run() -> void:
	var restore: float = GibSystem.gib_lifetime_s
	GibSystem.gib_lifetime_s = SHORT_LIFETIME_S
	GibSystem.clear_gibs()

	var src := _donor()
	var frag_n: int = GibSystem.MAX_LIVE_FRAGS + OVERFLOW
	var gib_n: int = GibSystem.MAX_LIVE_GIBS + OVERFLOW
	for i in frag_n:
		GibSystem._spawn_frag(src, Transform3D(Basis(), Vector3(i, 2, 0)), Vector3.UP, self)
	for i in gib_n:
		GibSystem._spawn_gib(src, Transform3D(Basis(), Vector3(i, 2, 20)), Vector3.UP, 1.0, self)

	# The caps must actually have bitten, or nothing was freed and this proves nothing.
	if GibSystem._live_frags.size() > GibSystem.MAX_LIVE_FRAGS:
		_fail("frag cap did not bite: %d live > cap %d" % [GibSystem._live_frags.size(), GibSystem.MAX_LIVE_FRAGS])
	if GibSystem._live_gibs.size() > GibSystem.MAX_LIVE_GIBS:
		_fail("gib cap did not bite: %d live > cap %d" % [GibSystem._live_gibs.size(), GibSystem.MAX_LIVE_GIBS])
	print("  spawned %d frags / %d gibs; %d / %d survive the cap (%d + %d evicted with timers pending)" % [
		frag_n, gib_n, GibSystem._live_frags.size(), GibSystem._live_gibs.size(),
		frag_n - GibSystem._live_frags.size(), gib_n - GibSystem._live_gibs.size()])

	# Past the despawn deadline: every pending timer fires, including the evicted ones.
	await get_tree().create_timer(SHORT_LIFETIME_S * 2.5).timeout

	for b in GibSystem._live_frags:
		if is_instance_valid(b):
			_fail("a frag outlived its despawn timer")
			break
	for b in GibSystem._live_gibs:
		if is_instance_valid(b):
			_fail("a gib outlived its despawn timer")
			break

	GibSystem.gib_lifetime_s = restore
	GibSystem.clear_gibs()
	_finish()


func _finish() -> void:
	if _failures == 0:
		print("PASS: evicted gibs despawn without calling into freed memory")
	else:
		print("=== %d FAILURE(S) ===" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)
