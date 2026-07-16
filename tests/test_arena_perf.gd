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
		_samples.append(Engine.get_frames_per_second())

	if _elapsed >= WARMUP + SAMPLE:
		_finish()


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
	get_tree().quit(0)
