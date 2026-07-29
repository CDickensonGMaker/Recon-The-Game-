## evidence_ledger.gd - what the player LEFT BEHIND, as the enemy could know it.
##
## Hunter teams converge on THIS, never on the player's transform and never on his
## planned route. An enemy that walks to a route the player picked in private is
## telepathic, and it reads as the game cheating - the same objection that killed the
## falsified-map proposal on 2026-07-28.
##
## Every fix is DATED and DECAYS. A fix is where something happened, not where the
## player is; by the time anyone acts on it he has moved, and that gap is the feature.
class_name EvidenceLedger
extends RefCounted

## Weight a fresh fix carries, by what produced it. Gunfire is loud but vague; a body
## is quiet but damning and does not move.
const WEIGHT_GUNSHOT: float = 1.0
const WEIGHT_EXPLOSION: float = 1.4
const WEIGHT_BODY: float = 2.0
const WEIGHT_BURNED: float = 1.6

## Seconds for a fix to decay to nothing. Bodies and burned huts outlast noise: they
## are still there to be found tomorrow, a sound is gone the moment it stops.
const DECAY_NOISE_S: float = 240.0
const DECAY_PHYSICAL_S: float = 900.0

## Metres of error a fix carries. Nobody triangulates a rifle shot in triple canopy.
const SCATTER_NOISE_M: float = 55.0
const SCATTER_PHYSICAL_M: float = 8.0

## Fixes closer together than this merge instead of stacking, so one long firefight is
## one strong lead rather than two hundred weak ones.
const MERGE_M: float = 40.0

var fixes: Array[Dictionary] = []   ## {pos, weight, born_s, decay_s}

var _rng := RandomNumberGenerator.new()


func _init(seed_value: int = 0) -> void:
	_rng.seed = hash(seed_value * 6151 + 17)


func record(pos: Vector3, weight: float, decay_s: float, scatter_m: float, now_s: float) -> void:
	var p := pos
	if scatter_m > 0.0:
		var a: float = _rng.randf_range(0.0, TAU)
		var d: float = _rng.randf_range(0.0, scatter_m)
		p += Vector3(cos(a) * d, 0.0, sin(a) * d)
	for f in fixes:
		if (f.pos as Vector3).distance_to(p) <= MERGE_M:
			f.weight = minf(float(f.weight) + weight, WEIGHT_BODY * 3.0)
			f.born_s = now_s
			f.decay_s = maxf(float(f.decay_s), decay_s)
			return
	fixes.append({"pos": p, "weight": weight, "born_s": now_s, "decay_s": decay_s})


func on_noise(type: int, pos: Vector3, source_team: int, now_s: float) -> void:
	if source_team != 0:
		return
	match type:
		NoiseBus.NoiseType.GUNSHOT:
			record(pos, WEIGHT_GUNSHOT, DECAY_NOISE_S, SCATTER_NOISE_M, now_s)
		NoiseBus.NoiseType.EXPLOSION:
			record(pos, WEIGHT_EXPLOSION, DECAY_NOISE_S, SCATTER_NOISE_M, now_s)


func on_body_left(pos: Vector3, now_s: float) -> void:
	record(pos, WEIGHT_BODY, DECAY_PHYSICAL_S, SCATTER_PHYSICAL_M, now_s)


func on_structure_burned(pos: Vector3, now_s: float) -> void:
	record(pos, WEIGHT_BURNED, DECAY_PHYSICAL_S, SCATTER_PHYSICAL_M, now_s)


func prune(now_s: float) -> void:
	var live: Array[Dictionary] = []
	for f in fixes:
		if now_s - float(f.born_s) < float(f.decay_s):
			live.append(f)
	fixes = live


## Current strength of a fix: full weight when fresh, nothing when expired.
func strength(f: Dictionary, now_s: float) -> float:
	var age: float = now_s - float(f.born_s)
	var life: float = maxf(1.0, float(f.decay_s))
	return float(f.weight) * clampf(1.0 - age / life, 0.0, 1.0)


## The lead a hunter would act on, or an empty dict when the trail is cold.
func best_fix(now_s: float) -> Dictionary:
	var best: Dictionary = {}
	var best_s: float = 0.0
	for f in fixes:
		var s: float = strength(f, now_s)
		if s > best_s:
			best_s = s
			best = f
	return best


func total_strength(now_s: float) -> float:
	var sum: float = 0.0
	for f in fixes:
		sum += strength(f, now_s)
	return sum
