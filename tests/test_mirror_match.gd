## test_mirror_match.gd - ADR-015 symmetry probe for the unified AI accuracy model (Track C).
## Runs ONE arena round in mirror_mode (identical weapon/HP/accuracy both sides, no retreat bias) so
## the ONLY thing under test is whether the ally and enemy fire paths are symmetric. Prints one
## machine-readable line; a shell driver runs it N times and aggregates the US:VC kill ratio (a fixed,
## symmetric fire model trends to ~1:1). One round per process avoids autoload state leaking between
## arena instances.
## Run: godot --headless --path . res://tests/test_mirror_match.tscn
extends Node3D

const ArenaScript := preload("res://scripts/levels/ai_stress_arena.gd")
const ROUND_SECONDS: float = 90.0

var _arena: Node3D = null
var _elapsed: float = 0.0


func _ready() -> void:
	randomize()  # vary the global spread stream each process run
	_arena = ArenaScript.new()
	_arena.set("mirror_mode", true)
	_arena.set("hot_start", true)
	_arena.set("spawn_player", false)
	_arena.set("spawn_hud", false)
	_arena.set("bench_dressing", false)
	_arena.set("us_squads_active", 3)
	_arena.set("vc_squads_active", 3)
	_arena.set("men_per_squad", 6)
	_arena.set("us_reserve_squads", 0)
	_arena.set("vc_reserve_squads", 0)
	_arena.set("round_max_seconds", ROUND_SECONDS)
	_arena.set("rng_seed", randi())
	_arena.set("ai_vs_ai_cone_mult", 1.0)  # fair baseline
	add_child(_arena)


func _process(delta: float) -> void:
	if _arena == null:
		return
	_elapsed += delta
	var ended: bool = bool(_arena.get("_round_ended"))
	if ended or _elapsed >= ROUND_SECONDS + 8.0:
		var uk: int = int(_arena.get("_us_kills"))  # VC killed by US
		var vk: int = int(_arena.get("_vc_kills"))  # US killed by VC
		print("MIRROR_RESULT %d %d" % [uk, vk])
		get_tree().quit(0)
