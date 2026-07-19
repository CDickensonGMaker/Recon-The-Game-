## test_arena_perf.gd - headless throughput probe for the enlarged arena at full
## load. Spawns start forces + forced reinforcement waves to ~50 live units in
## active combat and samples frame rate. HEADLESS = no GPU render, so this measures
## AI/physics/logic cost only; real windowed FPS is lower and GPU-gated.
## Run: godot --headless --path . res://tests/test_arena_perf.tscn
extends Node3D

const ArenaScript := preload("res://scripts/levels/ai_stress_arena.gd")
const WARMUP: float = 4.0
const SAMPLE: float = 12.0

var _arena: Node3D
var _elapsed: float = 0.0
var _waves_forced: bool = false
var _samples: Array[float] = []
## Counter snapshot at sample-window start: [los, perc, wit, cover, bullet,
## usec think, move, hitzone, anim, physics frames, bodies run, bodies gated].
## Deltas print in _finish.
var _c0: Array[int] = []


func _ready() -> void:
	print("=== Arena Perf Probe (HEADLESS - logic only, no render) ===")
	_arena = ArenaScript.new()
	_arena.set("patrol_mode", false)
	_arena.set("hot_start", true)
	_arena.set("us_squads_active", 3)
	_arena.set("vc_squads_active", 3)
	_arena.set("men_per_squad", 6)
	_arena.set("us_reserve_squads", 0)
	_arena.set("vc_reserve_squads", 0)
	_arena.set("round_max_seconds", WARMUP + SAMPLE + 30.0)
	_arena.set("spawn_player", false)
	_arena.set("spawn_hud", false)
	_arena.set("bench_dressing", false)
	add_child(_arena)


func _process(delta: float) -> void:
	_elapsed += delta

	# After the fight is joined, force a wave each side to push toward ~50 live.
	if not _waves_forced and _elapsed >= 2.0:
		_waves_forced = true
		_arena.call("debug_spawn_wave", true)
		_arena.call("debug_spawn_wave", false)

	if _elapsed >= WARMUP:
		if _c0.is_empty():
			_c0 = _counters()
		_samples.append(Engine.get_frames_per_second())

	if _elapsed >= WARMUP + SAMPLE:
		_finish()


func _counters() -> Array[int]:
	return [CombatManager.rays_los, CombatManager.rays_perception,
		CombatManager.rays_witness, CombatManager.rays_cover, CombatManager.rays_bullet,
		CombatManager.ai_usec_think, CombatManager.ai_usec_move,
		CombatManager.ai_usec_hitzone, CombatManager.ai_usec_anim,
		int(Engine.get_physics_frames()),
		CombatManager.bodies_run, CombatManager.bodies_gated]


func _live() -> int:
	var n: int = 0
	for us in [true, false]:
		for squad in _arena.get("_us_squads" if us else "_vc_squads"):
			for a in squad:
				if is_instance_valid(a) and not a.is_dead():
					n += 1
	return n


func _finish() -> void:
	var avg: float = 0.0
	var lo: float = 99999.0
	for f in _samples:
		avg += f
		lo = minf(lo, f)
	avg /= float(maxi(1, _samples.size()))
	print("live units at sample end: %d" % _live())
	print("HEADLESS avg FPS: %.1f | min FPS: %.1f | samples: %d" % [avg, lo, _samples.size()])
	print("(headless = logic/physics/AI only; real windowed FPS is lower, GPU-gated)")

	# W0 scoreboard: ray census + physics-side AI bucket split over the sample window.
	var c1: Array[int] = _counters()
	var d: Array[int] = []
	for i in c1.size():
		d.append(c1[i] - _c0[i])
	var pf: float = float(maxi(1, d[9]))
	print("--- W0 COUNTERS (%.0fs sample, %d physics frames) ---" % [SAMPLE, d[9]])
	print("rays/s: total %.0f | perc %.0f wit %.0f los-other %.0f cover %.0f bullet %.0f" % [
		float(d[0] + d[3] + d[4]) / SAMPLE, float(d[1]) / SAMPLE, float(d[2]) / SAMPLE,
		float(d[0] - d[1] - d[2]) / SAMPLE, float(d[3]) / SAMPLE, float(d[4]) / SAMPLE])
	print("rays/physics-frame: %.2f" % (float(d[0] + d[3] + d[4]) / pf))
	print("ai buckets ms/physics-frame: think %.3f | move %.3f | hitzone %.3f | anim %.3f | sum %.3f" % [
		float(d[5]) / 1000.0 / pf, float(d[6]) / 1000.0 / pf,
		float(d[7]) / 1000.0 / pf, float(d[8]) / 1000.0 / pf,
		float(d[5] + d[6] + d[7] + d[8]) / 1000.0 / pf])
	print("ai buckets ms/s: think %.1f | move %.1f | hitzone %.1f | anim %.1f" % [
		float(d[5]) / 1000.0 / SAMPLE, float(d[6]) / 1000.0 / SAMPLE,
		float(d[7]) / 1000.0 / SAMPLE, float(d[8]) / 1000.0 / SAMPLE])
	var bodies_total: int = maxi(1, d[10] + d[11])
	print("bodies/physics-frame: run %.1f | gated %.1f | gated %.0f%%" % [
		float(d[10]) / pf, float(d[11]) / pf,
		100.0 * float(d[11]) / float(bodies_total)])
	get_tree().quit(0)
