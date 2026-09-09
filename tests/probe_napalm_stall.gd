## probe_napalm_stall.gd - THE AMBIENT NAPALM FRAME, BY NAME.
##
## WHY THIS EXISTS. The Summoner, mid-session 2026-09-09 night, after saying the rest of
## the build felt smoother: "when the ambient napalm hits tho it still stutters really
## bad." His own log carries the event and the cost, and both are quoted in
## production/PERF_LEDGER.md:
##     [DEMO] air beat: NAPALM at 256,466 (210m out on bearing 90 deg)
##     [PERF] FPS=36 / 35 / 13 / 1 / 25 / 38
## - a one-frame collapse to FPS=1, with 145 `[TreeCover]` lines printed across the same
## window. That is the frame this probe reproduces and attributes.
##
## WHAT IT RUNS. The real thing, not a model of it: `FieldDirector.authored_strike(...,
## Ordnance.NAPALM, ...)` launches a real F-4 that flies a real pass and pickles
## FirePlan.NAPALM_DROPS (9) real canisters, each of which runs the real
## apply_explosion_damage -> TreeBreakSystem.apply_blast -> FireHazard -> GunFX ->
## DamageSystem chain. Fired at the SAME 210 m standoff the demo's ambient beat uses.
##
## NOT A QUIET BENCH. His standing ruling on tools/bench_canopy.tscn - "cuz its just
## terrain with no action so its not really gauging anything" - applies to any frame
## number taken on empty ground. So the strike lands only after LOAD_MEN real enemies are
## on the field through the real spawn path, and the strip is laid on the treeline they
## are in.
##
## WHAT IT CLAIMS AND WHAT IT DOES NOT. It claims WHERE THE MILLISECONDS WENT, measured by
## StallLedger in this process's own clock, per frame. It claims NOTHING about fps or GPU:
## GPU ms reads zero headless and the fps verdict is the Summoner's walk.
##
## Run: godot --headless --path . res://tests/probe_napalm_stall.tscn
extends Node

const OP_SEED: int = 47225
const READY_TIMEOUT_S: float = 240.0
const WARMUP_S: float = 6.0
const LOAD_MEN: int = 24
const STRIKE_RANGE_M: float = 210.0    ## the demo's own ambient beat standoff
const WATCH_S: float = 14.0            ## airframe transit + 9-canister ripple + fall window
const SAMPLE_HZ: float = 20.0

## THE STAGGER CONTRACT (his ruling 2026-09-09, "stagger the trees falling for a few
## seconds after the explosions"). These are shape assertions, not millisecond ones - a
## millisecond figure is a machine's mood, a call count is a contract.
##
## 1. Trunks must still be STANDING AND WAITING for at least this many samples after the
##    strip lands. Revert the stagger and every claimed trunk falls in the frame its
##    canister lands, pending_falls() never rises above 0, and this fails.
const MIN_PENDING_SAMPLES: int = 8
## 2. The spread must be REAL seconds, not one frame of queue.
const MIN_SPREAD_S: float = 1.0
## 3. TreeCoverLayer.load_species must be asked ONCE PER SPECIES, never once per felled
##    trunk. Revert the dedupe in _spawn_broken and this equals the trunk count.
const MAX_LOAD_SPECIES: int = 40   ## the project ships 27 breakable species
## 4. An 88 m NAPALM crater spans four 256 m chunks. Their vegetation re-derive must be
##    SPREAD, not done in the frame the canister lands - that single frame measured
##    terrain.crater 122.2 ms of a 125.43 ms idle step before this shipped.
const MIN_VEG_DEFERRED_SAMPLES: int = 1   ## the drain empties in ~2 frames; a 20Hz sampler
##    catches it once or twice, so the HARD gate on this cut is the has_method check below

var _flow: GameFlow = null
var _world: Node = null
var _tbs: Node = null
var _fails: PackedStringArray = []


func _fail(msg: String) -> void:
	_fails.append(msg)
	print("[NAPALM] FAIL: %s" % msg)


func _ready() -> void:
	StallLedger.enable()
	add_child(FrameSentinel.make(true))
	add_child(FrameSentinel.make(false))
	_flow = GameFlow.new()
	add_child(_flow)
	await get_tree().process_frame
	_flow._begin_operation(OP_SEED, "OPERATION NAPALM STALL")
	var waited: float = 0.0
	while waited < READY_TIMEOUT_S:
		if _flow.world != null and _flow.world.is_world_ready and _flow.world.player != null:
			break
		await get_tree().create_timer(0.5).timeout
		waited += 0.5
	if _flow.world == null or _flow.world.player == null:
		print("[NAPALM] FAIL: world never became ready in %.0fs" % READY_TIMEOUT_S)
		get_tree().quit(1)
		return
	_world = _flow.world
	_tbs = get_node_or_null("/root/TreeBreakSystem")
	if _tbs == null:
		print("[NAPALM] FAIL: TreeBreakSystem autoload missing - nothing to measure")
		get_tree().quit(1)
		return
	print("[NAPALM] world ready after %.1fs, seed %d, %d trunks registered"
		% [waited, OP_SEED, int(_tbs.call("registered_count"))])
	await get_tree().create_timer(WARMUP_S).timeout

	await _load_the_field()
	await _phase_napalm()
	await _phase_equivalence()
	await _phase_far_strike()
	_verdict()


## Real men through the real spawn path, so the strike is measured against a field that
## has something in it. Not scored - this is the LOAD, not the subject.
func _load_the_field() -> void:
	var p: Node3D = _world.player as Node3D
	var base: Vector3 = p.global_position
	var made: int = 0
	for i in range(LOAD_MEN):
		var ang: float = float(i) * 0.9
		var at: Vector3 = base + Vector3(cos(ang) * 30.0, 0.0, sin(ang) * 30.0)
		if EnemyBase.spawn_enemy(_world, at, "res://data/enemies/vc_rifleman.tres") != null:
			made += 1
		await get_tree().physics_frame
	## Count what LANDED, never what was asked for: a spawn call that returned null is not
	## load, and a probe that reports its attempts has measured nothing.
	print("[NAPALM] field loaded: %d/%d men actually on the ground" % [made, LOAD_MEN])
	if made < LOAD_MEN / 2:
		_fail("only %d of %d men spawned - this is closer to a quiet bench than a live"
			% [made, LOAD_MEN] + " field, and no cost below should be read as player load")
	await get_tree().create_timer(3.0).timeout


func _phase_napalm() -> void:
	var d: FieldDirector = _flow.director
	if d == null:
		_fail("no FieldDirector - cannot fire the real strike")
		return
	var p: Node3D = _world.player as Node3D
	var centre: Vector3 = p.global_position
	## Same geometry as demo_game._strike_at: strip laid ACROSS the bearing.
	var bearing: float = PI * 0.5
	var outward := Vector3(cos(bearing), 0.0, sin(bearing))
	var at: Vector3 = centre + outward * STRIKE_RANGE_M
	at.y = _world.surface_y(at)
	var across := Vector3(-outward.z, 0.0, outward.x)

	var standing_before: int = int(_tbs.call("registered_count"))
	StallLedger.reset_window()
	d.authored_strike(at, CASAirplane.Ordnance.NAPALM, across)
	print("[NAPALM] strike away: NAPALM at %.0f,%.0f (%.0fm out on bearing %.0f deg)"
		% [at.x, at.z, STRIKE_RANGE_M, rad_to_deg(bearing)])

	## Sample the pending-fall queue every tick of the watch. This is the stagger's own
	## witness: a queue that is never non-empty is a queue that never staggered.
	var samples: int = int(WATCH_S * SAMPLE_HZ)
	var pending_samples: int = 0
	var peak_pending: int = 0
	var first_pending_s: float = -1.0
	var last_pending_s: float = -1.0
	var veg_deferred_samples: int = 0
	var peak_veg_deferred: int = 0
	var tm: Node = _world.terrain_manager
	for i in range(samples):
		await get_tree().create_timer(1.0 / SAMPLE_HZ).timeout
		## The crater's own deferral, watched the same way. A NAPALM crater is 88 m wide and
		## touches four 256 m chunks; if their vegetation is still re-derived in one frame
		## this never rises above zero and the assertion below fails.
		if tm != null and tm.has_method("pending_veg_regen"):
			var vq: int = int(tm.call("pending_veg_regen"))
			if vq > 0:
				veg_deferred_samples += 1
				peak_veg_deferred = maxi(peak_veg_deferred, vq)
		## has_method, not call: reverting the stagger removes pending_falls() entirely,
		## and a probe that crashes on the reverted build has not FAILED it - it has
		## failed to measure it. A build with no such queue reports zero waiting, which
		## is the honest reading and trips MIN_PENDING_SAMPLES below.
		var pend: int = int(_tbs.call("pending_falls")) if _tbs.has_method("pending_falls") else 0
		if pend > 0:
			pending_samples += 1
			peak_pending = maxi(peak_pending, pend)
			var t: float = float(i) / SAMPLE_HZ
			if first_pending_s < 0.0:
				first_pending_s = t
			last_pending_s = t

	var standing_after: int = int(_tbs.call("registered_count"))
	var felled: int = standing_before - standing_after
	var spread: float = maxf(0.0, last_pending_s - first_pending_s)

	print("[NAPALM] ---- PHASE NAPALM (1 real strip, %d canisters, %.0fm blast each) ----"
		% [FirePlan.NAPALM_DROPS, FirePlan.NAPALM_BLAST_M])
	print("[NAPALM]   trunks that actually went over: %d (registry %d -> %d)"
		% [felled, standing_before, standing_after])
	print("[NAPALM]   fall stagger: peak %d waiting, non-empty for %d/%d samples,"
		% [peak_pending, pending_samples, samples]
		+ " spread %.2fs" % spread)
	print("[NAPALM]   load_species asked %d time(s) for %d felled trunk(s)"
		% [StallLedger.count("tb.load_species"), felled])
	print("[NAPALM]   crater veg regen deferred: peak %d chunk(s) waiting, non-empty for"
		% peak_veg_deferred + " %d/%d samples" % [veg_deferred_samples, samples])
	print(StallLedger.report())
	print("[NAPALM]   godot 1s-bucket maxima (main.cpp, NOT per-frame): idle %.2fms"
		% (Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
		+ " physics %.2fms" % (Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0))

	## ---- THE CONTRACT ----
	if felled <= 0:
		_fail("the strip felled nothing, so every cost above is a control that cannot"
			+ " fail - check data/veg_break_bands.json and the treeline under the mark")
		return
	if pending_samples < MIN_PENDING_SAMPLES:
		_fail("trunks were waiting to fall in only %d sample(s) (need >= %d):"
			% [pending_samples, MIN_PENDING_SAMPLES]
			+ " the fall is not staggered, it is instantaneous")
	if spread < MIN_SPREAD_S:
		_fail("the fall spread over %.2fs (need >= %.1fs): that is a queue draining,"
			% [spread, MIN_SPREAD_S] + " not trees burning down over seconds")
	if tm == null or not tm.has_method("pending_veg_regen"):
		_fail("TerrainManager has no pending_veg_regen(): the crater's vegetation rebuild"
			+ " is not deferred at all, so all four touched chunks re-derive in one frame")
	elif veg_deferred_samples < MIN_VEG_DEFERRED_SAMPLES:
		_fail("the crater's chunk vegetation regen was queued in only %d sample(s)"
			% veg_deferred_samples + " (need >= %d): it is still landing in one frame"
			% MIN_VEG_DEFERRED_SAMPLES)
	var loads: int = StallLedger.count("tb.load_species")
	if loads > MAX_LOAD_SPECIES:
		_fail("load_species was asked %d times for %d trunks (cap %d): the per-trunk"
			% [loads, felled, MAX_LOAD_SPECIES]
			+ " re-ask is back, and with it the [TreeCover] print flood")


## ---- THE EQUIVALENCE THAT LICENSES THE SILENT FALL ----
##
## His second ruling lets a distant tree skip its fall animation. The law on it is that the
## OUTCOME must be identical - the same trunks down, the same halves lying in the same
## places, the same cover and the same sightlines - and only the presentation may differ.
##
## This proves it at the only place divergence could enter: BrokenTree itself. The same
## trunk, the same blast, the same band, run once animated and once silent, each into a
## RECORDING stand-in for the VegetationManager. The fell entries the two hand back are
## compared field by field. If the silent path ever computed its own fall bearing, skipped
## the snag half, or settled at a different instant, this fails.
##
## It is a CONTROL THAT CAN FAIL: it asserts the two runs agree AND that each produced a
## non-empty entry set, so a pair of empty results cannot pass as agreement.
class FellRecorder:
	extends Node3D
	var entries: Array = []
	var rebuilt: Array = []
	func add_fell_entries(e: Array) -> void:
		entries.append_array(e)
	func rebuild_chunk(c: Vector2i) -> void:
		rebuilt.append(c)


func _phase_equivalence() -> void:
	var tbs_script: GDScript = _tbs.get_script() as GDScript
	if tbs_script == null:
		_fail("TreeBreakSystem has no script - cannot reach BrokenTree")
		return
	## get_script_constant_map, not get(): an inner class is a script CONSTANT, and
	## GDScript.get() does not reach it - it returns null and the phase would "skip"
	## rather than fail, which is a control that cannot fail.
	var broken_tree: GDScript = tbs_script.get_script_constant_map().get("BrokenTree") as GDScript
	if broken_tree == null:
		_fail("BrokenTree class not reachable from the TreeBreakSystem script")
		return
	## A real registered trunk, so the band and transform are the game's own, not invented.
	var sample: Dictionary = _any_live_entry()
	if sample.is_empty():
		_fail("no live registered trunk to run the equivalence on")
		return

	## A control that cannot fail is not a control: on a build with no silent path at all,
	## bt.set("silent", true) is a no-op and BOTH runs animate, so they agree trivially.
	## Refuse to report agreement unless the property being tested actually exists.
	var probe_bt: Node3D = broken_tree.new()
	var has_silent: bool = false
	for prop: Dictionary in probe_bt.get_property_list():
		if String(prop.get("name", "")) == "silent":
			has_silent = true
	probe_bt.free()
	if not has_silent:
		_fail("BrokenTree has no `silent` property - there is no distant path to compare"
			+ " against, and the agreement below would be two runs of the same code")
		return

	var results: Array = []
	for is_silent in [false, true]:
		var rec := FellRecorder.new()
		_world.add_child(rec)
		var bt: Node3D = broken_tree.new()
		bt.set("silent", is_silent)
		bt.set("species", sample["species"])
		bt.set("source_xf", sample["xf"])
		bt.set("band", sample["band"])
		bt.set("layer", sample["layer"])
		bt.set("vm", rec)
		rec.add_child(bt)
		bt.global_position = (sample["xf"] as Transform3D).origin
		## Identical blast for both: same bearing in, same height up the trunk.
		var blast: Vector3 = bt.global_position + Vector3(6.0, 3.0, 0.0)
		bt.call("break_at", 3.0, blast)
		## Longer than BrokenTree.FELL_TIME either way - the silent path deliberately waits
		## the same two seconds, so a shorter wait here would measure nothing.
		await get_tree().create_timer(3.5).timeout
		results.append(rec.entries.duplicate(true))
		rec.queue_free()

	var animated: Array = results[0]
	var quiet: Array = results[1]
	print("[NAPALM] ---- PHASE EQUIVALENCE (same trunk, same blast, animated vs silent) ----")
	print("[NAPALM]   animated settled %d part(s), silent settled %d part(s)"
		% [animated.size(), quiet.size()])
	if animated.is_empty() or quiet.is_empty():
		_fail("one of the two paths settled NOTHING (animated %d, silent %d) - there is no"
			% [animated.size(), quiet.size()] + " equivalence to check and this is not a pass")
		return
	if animated.size() != quiet.size():
		_fail("the silent fall settled %d part(s) where the animated fall settled %d"
			% [quiet.size(), animated.size()])
		return
	for i in animated.size():
		var a: Dictionary = animated[i]
		var b: Dictionary = quiet[i]
		if String(a.get("name", "")) != String(b.get("name", "")):
			_fail("part %d: animated laid '%s', silent laid '%s'"
				% [i, a.get("name", ""), b.get("name", "")])
			continue
		var ax: Transform3D = a.get("xf", Transform3D.IDENTITY)
		var bx: Transform3D = b.get("xf", Transform3D.IDENTITY)
		var moved: float = (ax.origin - bx.origin).length()
		if moved > 0.01:
			_fail("part '%s' came to rest %.3fm apart depending on where the player stood"
				% [a.get("name", ""), moved])
		if not ax.basis.is_equal_approx(bx.basis):
			_fail("part '%s' came to rest at a different ANGLE on the silent path"
				% a.get("name", ""))
		if float(a.get("trunk_r", 0.0)) != float(b.get("trunk_r", 0.0)) \
				or float(a.get("trunk_h", 0.0)) != float(b.get("trunk_h", 0.0)):
			_fail("part '%s' has a different collider on the silent path - cover and"
				% a.get("name", "") + " ballistics would disagree by player distance")
	if _fails.is_empty():
		print("[NAPALM]   IDENTICAL: every part settled at the same place, angle and"
			+ " collider size on both paths")


## A blast well outside SILENT_FALL_M, to measure what the silent path actually saves.
## Reported, not asserted: a millisecond figure is a machine's mood.
func _phase_far_strike() -> void:
	var d: FieldDirector = _flow.director
	var p: Node3D = _world.player as Node3D
	if d == null or p == null:
		return
	## Aimed INWARD, toward the map centre, and clamped inside the AO: a far strike that
	## walks off the edge of the world fells nothing, and a phase that fells nothing is a
	## control that cannot fail. 450 m clears the 350 m silent line with the feather.
	var tm: Node = _world.terrain_manager
	var half: float = float(tm.get("map_size")) * 0.5 if tm != null else 256.0
	var inward: Vector3 = (Vector3(half, 0.0, half) - p.global_position)
	inward.y = 0.0
	if inward.length() < 1.0:
		inward = Vector3.FORWARD
	var at: Vector3 = p.global_position + inward.normalized() * 450.0
	at.x = clampf(at.x, 40.0, half * 2.0 - 40.0)
	at.z = clampf(at.z, 40.0, half * 2.0 - 40.0)
	at.y = _world.surface_y(at)
	var before: int = int(_tbs.call("registered_count"))
	StallLedger.reset_window()
	d.authored_strike(at, CASAirplane.Ordnance.NAPALM, Vector3(1.0, 0.0, 0.0))
	await get_tree().create_timer(WATCH_S).timeout
	var felled: int = before - int(_tbs.call("registered_count"))
	print("[NAPALM] ---- PHASE FAR STRIKE (%.0fm out at %.0f,%.0f, past the 350m silent line) ----"
		% [(at - p.global_position).length(), at.x, at.z])
	print("[NAPALM]   trunks that actually went over: %d" % felled)
	print(StallLedger.report())


func _any_live_entry() -> Dictionary:
	var cells: Dictionary = _tbs.get("_cells")
	var bands: Dictionary = _tbs.get("_bands")
	if cells == null or bands == null:
		return {}
	for cell in cells:
		for e: Dictionary in (cells[cell] as Array):
			if bool(e.get("dead", false)) or bool(e.get("doomed", false)):
				continue
			var nm: String = String(e.get("species", ""))
			if not bands.has(nm) or not is_instance_valid(e.get("layer")):
				continue
			return {"species": nm, "xf": e["xf"], "band": bands[nm], "layer": e["layer"]}
	return {}


func _verdict() -> void:
	if _fails.is_empty():
		print("[NAPALM] PASS - the strip felled trees, the fall was staggered over real"
			+ " seconds, and load_species was asked once per species")
		get_tree().quit(0)
		return
	print("[NAPALM] FAILED %d check(s):" % _fails.size())
	for f: String in _fails:
		print("[NAPALM]   - %s" % f)
	get_tree().quit(1)
