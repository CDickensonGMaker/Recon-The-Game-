## probe_crucible.gd - THE STRESS CRUCIBLE (DEMO_TIGHT_40 Block 3; his spec
## 2026-08-14: "use the stress test and fill it with planes and units and
## explosions and combat"). Boots the AI arena demo-shaped (player + HUD), then
## walks five phases while sampling EVERY frame: worst ms, 1% low, average, and
## the render CPU/GPU split - the numbers PERF_LEDGER has never had.
##
##   BASELINE (quiet arena) -> COMBAT (hot 18v18) -> WAVE (+siege +sappers)
##   -> FIRES (napalm run / arty barrage / CBU cycling = the planes)
##   -> EVERYTHING (all of it + mortars + illum + a second wave)
##
## GPU truth needs a REAL renderer:  godot --path . res://tools/probe_crucible.tscn
## Headless still yields honest CPU frame numbers; the report names its mode.
## Exit is ALWAYS 0: this is a measurement instrument, not a gate - the gating
## FPS number is proposed FROM these numbers and ratified by the Summoner.
extends Node

const ArenaScene := preload("res://scenes/levels/ai_stress_arena.tscn")
const PHASE_S: float = 30.0
const PHASES: Array[String] = ["BASELINE", "COMBAT", "WAVE", "FIRES", "EVERYTHING"]

var _arena: Node = null
var _phase_i: int = -1
var _phase_t: float = 0.0
var _fire_t: float = 0.0
var _fire_i: int = 0
var _samples: Dictionary = {}       ## phase -> Array[float] frame ms
var _rcpu: Dictionary = {}          ## phase -> [sum, n]
var _rgpu: Dictionary = {}
var _sampling: bool = false
var _headless: bool = false


func _ready() -> void:
	_headless = DisplayServer.get_name() == "headless"
	_arena = ArenaScene.instantiate()
	_arena.set("spawn_player", true)
	_arena.set("spawn_hud", true)
	_arena.set("hot_start", false)
	_arena.set("bench_dressing", true)   # night: the demo's siege is a night fight
	add_child(_arena)
	await get_tree().process_frame
	await get_tree().create_timer(6.0).timeout   # world build + nav settle
	var vp_rid: RID = get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(vp_rid, true)
	print("\n=== CRUCIBLE (%s renderer) - %d phases x %.0fs ===\n" % [
		"DUMMY/headless - GPU column meaningless" if _headless else "REAL", PHASES.size(), PHASE_S])
	_next_phase()


func _next_phase() -> void:
	_phase_i += 1
	if _phase_i >= PHASES.size():
		_report()
		return
	var phase: String = PHASES[_phase_i]
	_samples[phase] = [] as Array[float]
	_rcpu[phase] = [0.0, 0]
	_rgpu[phase] = [0.0, 0]
	_phase_t = PHASE_S
	match phase:
		"COMBAT":
			_arena.call("_hot_start_combat")
		"WAVE":
			_arena.call("_launch_arena_siege")
			_arena.call("_launch_arena_sappers")
		"FIRES":
			_fire_t = 0.0
			_fire_i = 0
		"EVERYTHING":
			_arena.call("_call_mortars_on_player")
			_arena.call("_launch_arena_siege")
	_sampling = true
	print("[CRUCIBLE] phase %s begins" % phase)


## The planes and the explosions: cycle the real dispatch (napalm run = the
## airframe + 9 canisters, arty = 8-12 shell barrage, CBU = 3 dispensers).
const FIRE_CYCLE: Array[String] = ["napalm", "arty", "cbu"]
const FIRE_EVERY_S: float = 9.0


func _tick_fires(delta: float) -> void:
	var phase: String = PHASES[_phase_i]
	if phase != "FIRES" and phase != "EVERYTHING":
		return
	_fire_t -= delta
	if _fire_t > 0.0:
		return
	_fire_t = FIRE_EVERY_S
	var d: FieldDirector = _arena.get("_field_director") as FieldDirector
	if d == null:
		return
	d._cas_cooldown = 0.0
	var kind: String = FIRE_CYCLE[_fire_i % FIRE_CYCLE.size()]
	_fire_i += 1
	var at := Vector3(randf_range(-40.0, 40.0), 0.0, randf_range(-60.0, -20.0))
	d.request_fire_support(kind, at, Vector3.RIGHT)


func _process(delta: float) -> void:
	if not _sampling:
		return
	var phase: String = PHASES[_phase_i]
	(_samples[phase] as Array).append(delta * 1000.0)
	var vp_rid: RID = get_viewport().get_viewport_rid()
	var c: float = RenderingServer.viewport_get_measured_render_time_cpu(vp_rid)
	var g: float = RenderingServer.viewport_get_measured_render_time_gpu(vp_rid)
	(_rcpu[phase] as Array)[0] += c
	(_rcpu[phase] as Array)[1] += 1
	(_rgpu[phase] as Array)[0] += g
	(_rgpu[phase] as Array)[1] += 1
	_tick_fires(delta)
	_phase_t -= delta
	if _phase_t <= 0.0:
		_sampling = false
		_next_phase()


func _report() -> void:
	print("\n=== CRUCIBLE REPORT (%s) ===" % ("HEADLESS - CPU frame truth only" if _headless else "REAL RENDERER"))
	print("%-11s %7s %8s %8s %8s %9s %9s" % [
		"phase", "frames", "avg ms", "1% ms", "worst", "rCPU ms", "rGPU ms"])
	for phase in PHASES:
		var arr: Array = _samples.get(phase, [])
		if arr.is_empty():
			continue
		var ms: Array[float] = []
		var total: float = 0.0
		for v in arr:
			ms.append(float(v))
			total += float(v)
		ms.sort()
		var avg: float = total / float(ms.size())
		var p99: float = ms[mini(int(float(ms.size()) * 0.99), ms.size() - 1)]
		var worst: float = ms[ms.size() - 1]
		var rc: Array = _rcpu[phase]
		var rg: Array = _rgpu[phase]
		var rcm: float = (rc[0] as float) / maxf(1.0, float(rc[1] as int))
		var rgm: float = (rg[0] as float) / maxf(1.0, float(rg[1] as int))
		print("%-11s %7d %8.2f %8.2f %8.2f %9.2f %9.2f" % [
			phase, ms.size(), avg, p99, worst, rcm, rgm])
		print("%-11s %7s %7.0ffps %6.0ffps %6.0ffps" % [
			"", "", 1000.0 / maxf(avg, 0.001), 1000.0 / maxf(p99, 0.001),
			1000.0 / maxf(worst, 0.001)])
	print("\nGate proposal comes from EVERYTHING's 1%% low. Grep this log for")
	print("[NAV-FALLBACK] to count designed pathing fallbacks under load.")
	get_tree().quit(0)
