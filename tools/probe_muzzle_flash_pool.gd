## probe_muzzle_flash_pool.gd - ADR-015 evidence for the muzzle-flash pool.
##
## THE CLAIM UNDER TEST: after warm-up, GunFX.muzzle_flash() constructs ZERO nodes and
## ZERO mesh resources per round fired, holds the same MAX_FLASHES ceiling, and looks
## exactly the same doing it.
##
## THIS PROBE FAILS AGAINST THE PRE-POOL CODE, on purpose. Before pooling, EVERY round
## minted a Node3D + 2 MeshInstance3D + 2 QuadMesh + a Timer - 4 nodes and 2 mesh
## resources a shot, capped only at 96 concurrent. Section A fires a wave, lets it die,
## and fires the SAME wave again: pre-pool the second wave shows 4 new nodes and 2 new
## meshes per round, pooled it shows 0. Section A is the measurement; everything after
## it exists because a pool that is cheap and WRONG is worse than the old code.
##
##   C  the ceiling still holds - a 300-round burst never puts more than MAX_FLASHES
##      flash roots on screen and never builds more than MAX_FLASHES entries.
##   D  the LOOK did not change - size jitter is still written into QuadMesh.size and
##      NOT into node scale. That is not pedantry: _muzzle_mat() does not set
##      billboard_keep_scale, so a BILLBOARD_ENABLED quad DISCARDS node scale and the
##      jitter would silently vanish. Node scale must read exactly 1.
##   E  the 2026-09-08 BORE fix survives reuse, in both directions. An entry fired WITH
##      a direction must fall back to the billboard roll when the next caller passes
##      none. A pool that leaves the last shot's aimed basis on a reused node would
##      entrench the aimed path and look wrong for every direction-less caller.
##   F  NEGATIVE CONTROL. A probe that has never failed proves nothing: build the exact
##      shape the old code built, by hand, and assert the census counts it.
##
## Frame-time is NOT claimed here. This probe measures allocations, which is what it can
## see; the fps number waits for a run on the Intel UHD bench.
##
##   godot --headless --path . res://tools/probe_muzzle_flash_pool.tscn
extends Node

## One wave is a third of the ceiling - big enough that a per-round allocation is
## unmissable, small enough that the cap never truncates the wave.
const WAVE: int = 32
## Long enough for the longest flash life (MUZZLE_OBSERVED_SECONDS at bench_mult 1.0 =
## 0.09s) plus the queue_free the PRE-POOL code needs to actually drop its nodes.
const SETTLE_SECONDS: float = 0.5

var _fails: int = 0
## instance_id -> true, for everything ever seen alive under a host. Godot instance ids
## carry a validator, so a freed node's id is never handed to a later object - which is
## what makes "new since last census" mean "constructed since last census".
var _seen_nodes: Dictionary = {}
var _seen_meshes: Dictionary = {}


func _ready() -> void:
	await _run()
	print("")
	if _fails == 0:
		print("[FLASH POOL] PASS - 0 nodes and 0 mesh resources constructed per round")
	else:
		printerr("[FLASH POOL] FAIL - %d problem(s)" % _fails)
	get_tree().quit(0 if _fails == 0 else 1)


func _ok(label: String, cond: bool) -> void:
	if cond:
		print("  ok   %s" % label)
	else:
		_fails += 1
		printerr("  FAIL %s" % label)


## Nodes and mesh resources under `root` that this probe has never seen alive before.
## Returns [new_nodes, new_meshes].
func _census(root: Node) -> Array[int]:
	var new_nodes: int = 0
	var new_meshes: int = 0
	var stack: Array[Node] = []
	stack.append(root)
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n != root:
			var nid: int = n.get_instance_id()
			if not _seen_nodes.has(nid):
				_seen_nodes[nid] = true
				new_nodes += 1
		if n is MeshInstance3D:
			var m: Mesh = (n as MeshInstance3D).mesh
			if m != null:
				var mid: int = m.get_instance_id()
				if not _seen_meshes.has(mid):
					_seen_meshes[mid] = true
					new_meshes += 1
		for c in n.get_children():
			stack.append(c)
	var out: Array[int] = []
	out.append(new_nodes)
	out.append(new_meshes)
	return out


func _live_flashes(root: Node) -> int:
	var total: int = 0
	for c in root.get_children():
		if c is Node3D and (c as Node3D).visible:
			total += 1
	return total


func _fire(host: Node3D, n: int, bore: Vector3 = Vector3.ZERO) -> void:
	for i in n:
		GunFX.muzzle_flash(host, Vector3(float(i) * 0.5, 1.5, 0.0), false, bore)


func _run() -> void:
	print("=== MUZZLE FLASH POOL (allocations per round) ===")
	GunFX.reset_session()

	# --- A. the measurement -------------------------------------------------
	var host := Node3D.new()
	add_child(host)

	_fire(host, WAVE)
	var cold: Array[int] = _census(host)
	print("  wave 1 (cold): %d nodes, %d mesh resources for %d rounds  =  %.2f nodes + %.2f meshes/round"
		% [cold[0], cold[1], WAVE, float(cold[0]) / WAVE, float(cold[1]) / WAVE])
	_ok("wave 1 built the pool it needed (%d rounds -> %d nodes)" % [WAVE, cold[0]],
		cold[0] >= WAVE)

	await get_tree().create_timer(SETTLE_SECONDS).timeout

	_fire(host, WAVE)
	var warm: Array[int] = _census(host)
	print("  wave 2 (warm): %d nodes, %d mesh resources for %d rounds  =  %.2f nodes + %.2f meshes/round"
		% [warm[0], warm[1], WAVE, float(warm[0]) / WAVE, float(warm[1]) / WAVE])
	_ok("ZERO nodes constructed per round after warm-up (got %d)" % warm[0], warm[0] == 0)
	_ok("ZERO mesh resources constructed per round after warm-up (got %d)" % warm[1],
		warm[1] == 0)

	await get_tree().create_timer(SETTLE_SECONDS).timeout

	# --- C. the ceiling -----------------------------------------------------
	var burst := Node3D.new()
	add_child(burst)
	_fire(burst, 300)
	var live: int = _live_flashes(burst)
	_ok("a 300-round burst puts at most MAX_FLASHES (%d) flashes on screen, got %d"
		% [GunFX.MAX_FLASHES, live], live <= GunFX.MAX_FLASHES)
	_ok("a 300-round burst builds at most MAX_FLASHES entries, got %d"
		% burst.get_child_count(), burst.get_child_count() <= GunFX.MAX_FLASHES)
	var burst_census: Array[int] = _census(burst)
	print("  burst: %d new nodes, %d new meshes for 300 rounds (ceiling %d entries)"
		% [burst_census[0], burst_census[1], GunFX.MAX_FLASHES])

	await get_tree().create_timer(SETTLE_SECONDS).timeout

	# --- D. the look --------------------------------------------------------
	GunFX.reset_session()
	var look := Node3D.new()
	add_child(look)
	GunFX.muzzle_flash(look, Vector3(0, 1.5, 0))
	var flash: Node3D = null
	if look.get_child_count() > 0:
		flash = look.get_child(0) as Node3D
	_ok("a flash is a Node3D", flash != null)
	if flash == null:
		return
	_ok("subtree shape is core, spikes, Timer - the shape test_fake_lights.gd walks",
		flash.get_child_count() == 3
			and flash.get_child(0) is MeshInstance3D
			and flash.get_child(1) is MeshInstance3D
			and flash.get_child(2) is Timer)
	_ok("the flash is VISIBLE while it lives", flash.visible)

	var core := flash.get_child(0) as MeshInstance3D
	var spikes := flash.get_child(1) as MeshInstance3D
	var lo: float = 0.85 * GunFX.MUZZLE_OBSERVED_SCALE
	var hi: float = 1.25 * GunFX.MUZZLE_OBSERVED_SCALE
	var core_mesh := core.mesh as QuadMesh
	var spike_mesh := spikes.mesh as QuadMesh
	var cs: Vector2 = core_mesh.size
	var ss: Vector2 = spike_mesh.size
	_ok("core jitter is in the MESH: size %.3f in [%.3f, %.3f]" % [cs.x, 0.5 * lo, 0.5 * hi],
		cs.x >= 0.5 * lo - 0.001 and cs.x <= 0.5 * hi + 0.001 and is_equal_approx(cs.x, cs.y))
	_ok("spike jitter is in the MESH: size %.3f in [%.3f, %.3f]" % [ss.x, lo, hi],
		ss.x >= lo - 0.001 and ss.x <= hi + 0.001)
	# The one that catches a "clever" pooling rewrite: _muzzle_mat sets no
	# billboard_keep_scale, so node scale is DISCARDED by BILLBOARD_ENABLED. Jitter moved
	# onto scale renders every flash the same size and no probe of the numbers would say so.
	_ok("node scale is exactly 1 on both quads (billboard discards scale)",
		core.scale.is_equal_approx(Vector3.ONE) and spikes.scale.is_equal_approx(Vector3.ONE))
	_ok("both quads are self-lit (UNSHADED + emission)",
		_selflit(core) and _selflit(spikes))
	_ok("no real-time light anywhere in the flash (ADR-026 A.1)", _count_lights(flash) == 0)

	var life: float = maxf(GunFX.FLASH_SECONDS, GunFX.MUZZLE_OBSERVED_SECONDS)
	var t := flash.get_child(2) as Timer
	_ok("lifetime is unchanged: %.3fs == maxf(FLASH_SECONDS, MUZZLE_OBSERVED_SECONDS)"
		% t.wait_time, is_equal_approx(t.wait_time, life))
	_ok("flash outlives one frame at 25 fps (Fairness Law telegraph)",
		GunFX.FLASH_SECONDS > 1.0 / 25.0)

	await get_tree().create_timer(SETTLE_SECONDS).timeout
	_ok("the entry is HIDDEN and returned to the pool when it expires", not flash.visible)

	# --- E. the bore fix must survive reuse, in BOTH directions -------------
	GunFX.reset_session()
	var bore_host := Node3D.new()
	add_child(bore_host)

	GunFX.muzzle_flash(bore_host, Vector3.ZERO, false, Vector3.RIGHT)
	var b1: Node3D = bore_host.get_child(0) as Node3D
	var sp1 := b1.get_child(1) as MeshInstance3D
	var m1 := sp1.material_override as BaseMaterial3D
	_ok("with a bore, the spike uses the BILLBOARD_DISABLED aimed material",
		m1 != null and m1.billboard_mode == BaseMaterial3D.BILLBOARD_DISABLED)
	_ok("with a bore, the spike's long axis (local X) lies down the barrel",
		sp1.transform.basis.x.normalized().dot(Vector3.RIGHT) > 0.99)

	await get_tree().create_timer(SETTLE_SECONDS).timeout

	# Same entry, no direction. Pooling must NOT leave the aimed basis or the aimed
	# material behind - the 8 direction-less call shapes are a separate, unruled problem
	# and this probe exists partly to stop the pool from quietly entrenching it.
	GunFX.muzzle_flash(bore_host, Vector3.ZERO, false, Vector3.ZERO)
	var b2: Node3D = bore_host.get_child(0) as Node3D
	## Pre-pool, b1 was queue_freed during the settle above, so this is the line that
	## says "these are the same object" WITHOUT dereferencing a dead handle.
	_ok("the SAME pooled entry was reused for the second shot",
		is_instance_valid(b1) and b2 == b1)
	var sp2 := b2.get_child(1) as MeshInstance3D
	var m2 := sp2.material_override as BaseMaterial3D
	_ok("with NO bore, the reused spike falls back to BILLBOARD_ENABLED",
		m2 != null and m2.billboard_mode == BaseMaterial3D.BILLBOARD_ENABLED)
	_ok("with NO bore, the reused spike carries a pure screen-space Z roll, not the old aim",
		absf(sp2.transform.basis.z.normalized().dot(Vector3.BACK)) > 0.999)

	# --- F. NEGATIVE CONTROL ------------------------------------------------
	# Build, by hand, exactly what one pre-pool round built. If the census cannot see
	# this, every zero above is decorative.
	var decoy_host := Node3D.new()
	add_child(decoy_host)
	var decoy := Node3D.new()
	decoy_host.add_child(decoy)
	for i in 2:
		var mi := MeshInstance3D.new()
		mi.mesh = QuadMesh.new()
		decoy.add_child(mi)
	decoy.add_child(Timer.new())
	var seen: Array[int] = _census(decoy_host)
	_ok("NEGATIVE CONTROL: census sees one pre-pool round as 4 nodes + 2 meshes (got %d + %d)"
		% [seen[0], seen[1]], seen[0] == 4 and seen[1] == 2)
	var again: Array[int] = _census(decoy_host)
	_ok("NEGATIVE CONTROL: an unchanged subtree censuses as 0 new (got %d + %d)"
		% [again[0], again[1]], again[0] == 0 and again[1] == 0)


func _selflit(mi: MeshInstance3D) -> bool:
	var mat: Material = mi.material_override
	if mat == null and mi.mesh != null:
		mat = mi.mesh.surface_get_material(0)
	if mat is BaseMaterial3D:
		var bm := mat as BaseMaterial3D
		return bm.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED and bm.emission_enabled
	return false


func _count_lights(n: Node) -> int:
	var total: int = 1 if n is OmniLight3D or n is SpotLight3D else 0
	for c in n.get_children():
		total += _count_lights(c)
	return total
