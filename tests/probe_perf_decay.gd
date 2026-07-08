## probe_perf_decay.gd - NOT a test (name is probe_*, so run_all_tests.ps1 skips it).
##
## An MCP run of the real project showed FPS decaying monotonically while the
## player stood still: 39 -> 33 -> 28 -> 26 -> 19 -> 15 -> 14 -> 14, with
## "[BillboardVegetation] Generated ... for chunk (1,4)" printed FIVE times and
## "[TerrainChunk] Chunk (0,4) mesh built" three times. Chunks are being
## streamed out and back in, and something is accumulating.
##
## This probe runs the real GameWorld windowed and samples engine counters so we
## can tell WHAT accumulates (nodes? orphans? draw calls? memory?) rather than
## guessing.
##
## Run:  godot --path . res://tests/probe_perf_decay.tscn
extends Node

const SAMPLE_INTERVAL: float = 4.0
const RUN_SECONDS: float = 56.0

var _world: GameWorld = null
var _t: float = 0.0
var _elapsed: float = 0.0
var _first: Dictionary = {}


func _ready() -> void:
	var scene: PackedScene = load("res://scenes/levels/game_world.tscn")
	_world = scene.instantiate()
	_world.mission_seed = 4242
	add_child(_world)
	print("PROBE: waiting for world...")


func _process(delta: float) -> void:
	if _world == null or not _world.is_world_ready:
		return
	_elapsed += delta
	_t += delta
	if _t < SAMPLE_INTERVAL:
		if _elapsed >= RUN_SECONDS:
			_finish()
		return
	_t = 0.0
	_sample()
	if _elapsed >= RUN_SECONDS:
		_finish()


func _sample() -> void:
	var tm: TerrainManager = _world.terrain_manager
	var loaded: int = tm.chunks.size() if tm != null else -1

	# How many MultiMesh/billboard child nodes exist under the vegetation systems?
	var veg_children: int = _count_descendants(_world.vegetation_manager)
	var chunk_children: int = _count_descendants(tm)

	var s := {
		"fps": Engine.get_frames_per_second(),
		"nodes": Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
		"orphans": Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT),
		"objects": Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),
		"draws": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		"prims": Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),
		"mem_mb": Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0,
		"vidmem_mb": Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0,
		"chunks": loaded,
		"veg_kids": veg_children,
		"chunk_kids": chunk_children,
	}
	if _first.is_empty():
		_first = s.duplicate()

	print("PROBE t=%4.0fs fps=%3.0f nodes=%5d orphans=%3d objs=%4d draws=%4d prims=%9d mem=%6.1fMB vram=%6.1fMB chunks=%2d veg_kids=%4d chunk_kids=%4d" % [
		_elapsed, s.fps, s.nodes, s.orphans, s.objects, s.draws, s.prims,
		s.mem_mb, s.vidmem_mb, s.chunks, s.veg_kids, s.chunk_kids])


func _count_descendants(n: Node) -> int:
	if n == null:
		return -1
	var total: int = 0
	for c in n.get_children():
		total += 1 + _count_descendants(c)
	return total


func _finish() -> void:
	print("--- PROBE DELTA over %.0fs ---" % _elapsed)
	var last := {
		"fps": Engine.get_frames_per_second(),
		"nodes": Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
		"orphans": Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT),
		"objects": Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),
		"draws": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		"mem_mb": Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0,
		"vidmem_mb": Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0,
	}
	for k in ["fps", "nodes", "orphans", "objects", "draws", "mem_mb", "vidmem_mb"]:
		print("  %-10s %10.1f -> %10.1f   (%+.1f)" % [k, float(_first.get(k, 0)), float(last[k]), float(last[k]) - float(_first.get(k, 0))])
	get_tree().quit(0)
