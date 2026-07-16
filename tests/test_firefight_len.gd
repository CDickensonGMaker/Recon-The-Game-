## test_firefight_len.gd - ADR-015 probe for the C2 firefight-length dial + the Fairness Law guard.
## TWO assertions, one run:
##   (A) FAIRNESS: with the trooper dial cranked, a shot AIMED AT THE PLAYER is NOT widened (stays
##       inside the 1.2 deg cap) and the first such shot is a telegraphed near-miss (>= 5 deg). The
##       widen only ever reaches AI-vs-AI. This is a direct assertion on AIMarksmanship, so it runs
##       headless with no player node needed.
##   (B) LENGTH: one mirror arena round at the dial value passed on the cmdline; prints kills so a
##       shell driver can confirm a higher dial => fewer kills in the window => longer firefights.
## Run: godot --headless --path . res://tests/test_firefight_len.tscn -- <cone_mult>
extends Node3D

const ArenaScript := preload("res://scripts/levels/ai_stress_arena.gd")
const SAMPLE_AT: float = 60.0
const MAX_SECONDS: float = 90.0
const SAMPLES: int = 4000

var _arena: Node3D = null
var _elapsed: float = 0.0
var _cone_mult: float = 1.0
var _fairness_failures: int = 0


func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() > 0:
		_cone_mult = maxf(1.0, args[0].to_float())
	print("=== Firefight-Length + Fairness Probe (dial = %.1f) ===" % _cone_mult)
	_run_fairness_assertions()
	randomize()
	_arena = ArenaScript.new()
	_arena.set("mirror_mode", true)
	_arena.set("hot_start", true)
	_arena.set("spawn_player", false)
	_arena.set("spawn_hud", false)
	_arena.set("us_squads_active", 3)
	_arena.set("vc_squads_active", 3)
	_arena.set("men_per_squad", 6)
	_arena.set("us_reserve_squads", 0)
	_arena.set("vc_reserve_squads", 0)
	_arena.set("round_max_seconds", MAX_SECONDS)
	_arena.set("rng_seed", randi())
	_arena.set("ai_vs_ai_cone_mult", _cone_mult)
	add_child(_arena)


## Direct assertion on the shared model: the dial reaches AI-vs-AI ONLY, never the player.
func _run_fairness_assertions() -> void:
	GameSettings.ai_vs_ai_cone_mult = _cone_mult
	GameSettings.difficulty = 1  # NORMAL -> enemy_spread_mult 1.0, isolate the dial
	var base: Vector3 = Vector3.FORWARD
	# A pre-cap spread far above 1.2 so the cap governs both branches.
	var big: float = 20.0
	var max_player_dev: float = 0.0
	var max_ai_dev: float = 0.0
	var max_firstshot_dev: float = 0.0
	for i in SAMPLES:
		var pa: Vector3 = AIMarksmanship.aim_with_spread(base, big, true, 1.0, false)
		max_player_dev = maxf(max_player_dev, rad_to_deg(base.angle_to(pa)))
		var aa: Vector3 = AIMarksmanship.aim_with_spread(base, big, false, 1.0, false)
		max_ai_dev = maxf(max_ai_dev, rad_to_deg(base.angle_to(aa)))
		var fs: Vector3 = AIMarksmanship.aim_with_spread(base, big, true, 1.0, true)
		max_firstshot_dev = maxf(max_firstshot_dev, rad_to_deg(base.angle_to(fs)))
	var player_cap: float = AIMarksmanship.PLAYER_CONE_CAP_DEG
	print("  player-target max deviation: %.2f deg (cap %.2f, dial ignored)" % [max_player_dev, player_cap])
	print("  ai-target max deviation:     %.2f deg (cap widened by dial %.1f)" % [max_ai_dev, _cone_mult])
	print("  first-shot-at-player max dev: %.2f deg (telegraphed near-miss)" % max_firstshot_dev)
	# Player cone is never widened by the dial - allow a hair for the elevation-basis math.
	if max_player_dev > player_cap + 0.05:
		_fairness_failures += 1
		print("  FAIL: player cone %.2f exceeded the fixed cap %.2f - the dial LEAKED to the player" % [max_player_dev, player_cap])
	# With a dial > 1, AI-vs-AI must actually be able to exceed the player cap (proves the widen works).
	if _cone_mult > 1.5 and max_ai_dev <= player_cap + 0.05:
		_fairness_failures += 1
		print("  FAIL: dial %.1f did not widen the AI-vs-AI cone" % _cone_mult)
	# First shot at the player is a deliberate telegraphed miss.
	if max_firstshot_dev < 5.0:
		_fairness_failures += 1
		print("  FAIL: first shot at player was not a >=5 deg near-miss")


func _process(delta: float) -> void:
	if _arena == null:
		return
	_elapsed += delta
	var ended: bool = bool(_arena.get("_round_ended"))
	if ended or _elapsed >= MAX_SECONDS + 8.0:
		var uk: int = int(_arena.get("_us_kills"))
		var vk: int = int(_arena.get("_vc_kills"))
		var dur: float = float(_arena.get("_sim_time"))
		print("FIREFIGHT_RESULT mult=%.1f duration=%.1f total_kills=%d" % [_cone_mult, dur, uk + vk])
		print("\n%s: %d fairness failure(s)" % ["PASS" if _fairness_failures == 0 else "FAIL", _fairness_failures])
		get_tree().quit(_fairness_failures)
