class_name AIMarksmanship
extends RefCounted
## Shared AI cone + audience-profile spread for BOTH allies and enemies. ONE spread path
## (Fossil Law) so a mirror match trends 1:1. Spread draws from the global seeded stream by
## design: ADR-010:16 exempts bullet spread from determinism and bans a second seed, so no
## rng is passed here.

## Cone hard cap in degrees for a shot AIMED AT THE PLAYER. AI-vs-player lethality is pinned to
## this; only the AI-vs-AI branch widens it via the firefight dial.
## Summoner lethality ruling 2026-08-04 ("star wars blaster effect" convicted): cap
## 1.2 -> 1.0 deg, exposure peak 2.0 -> 1.4. First shots still telegraph (Fairness Law);
## a converged shooter kills an exposed man.
const PLAYER_CONE_CAP_DEG: float = 1.0
const BASE_SPREAD_MULT: float = 1.25
const BLOOM_PER_SHOT: float = 0.06
const BLOOM_CAP: float = 0.8
const EXPOSURE_PEAK: float = 1.4
const MOVE_PENALTY: float = 1.5


## accuracy01 0->1 tightens the cone: x1.6 at 0, x0.4 at 1.
static func _skill_mult(accuracy01: float) -> float:
	return 1.6 - clampf(accuracy01, 0.0, 1.0) * 1.2


## The unified pre-cap spread cone in degrees. situational_mult carries any per-shooter texture
## (the enemy range/strafe/stillness modifier); allies pass 1.0.
static func cone_spread_deg(weapon_base_spread_deg: float, accuracy01: float, shots_fired: int,
		moving: bool, situational_mult: float) -> float:
	var bloom: float = 1.0 + minf(float(shots_fired) * BLOOM_PER_SHOT, BLOOM_CAP)
	var s: float = weapon_base_spread_deg * BASE_SPREAD_MULT * situational_mult \
		* _skill_mult(accuracy01) * bloom
	if moving:
		s *= MOVE_PENALTY
	return s


## Center-weighted angular scatter in the aim basis. Never add raw RNG to a normalized vector's
## components: it skews to the diagonals and double-counts.
static func _apply_cone(aim: Vector3, spread_deg: float) -> Vector3:
	var spread: float = deg_to_rad(spread_deg)
	var e_right: Vector3 = aim.cross(Vector3.UP).normalized()
	var e_up: Vector3 = e_right.cross(aim).normalized()
	var ang: float = randf() * TAU
	var mag: float = minf(absf(randfn(0.0, 0.45)), 1.0) * spread
	return (aim + e_right * tan(cos(ang) * mag) + e_up * tan(sin(ang) * mag)).normalized()


## The warning crack: a deliberate 5-9 deg miss, biased high/wide.
static func _first_shot_nudge(aim: Vector3) -> Vector3:
	var miss: float = deg_to_rad(randf_range(5.0, 9.0))
	var dir: float = randf_range(0.0, TAU)
	var a: Vector3 = aim
	a.x += cos(dir) * miss
	a.y += absf(sin(dir)) * miss * 0.5 + 0.02
	return a.normalized()


## Apply the cone under the correct audience profile.
## PLAYER target  -> fixed 1.2 deg cap + exposure ramp + first-shot mercy near-miss (Fairness Law).
## AI-vs-AI target -> cap widened by GameSettings.ai_vs_ai_cone_mult (C2); NO fairness terms, so a
## mirror stays symmetric. INVARIANT: the widen and the first-shot mercy are on OPPOSITE branches of
## is_player_target - the firefight dial can never reach a shot aimed at the player.
## The Fairness Law's exposure ramp, as a value: how much the cone is widened for a
## shot at the player who has been exposed for exposure_t (0 fresh -> 1 converged).
## x(1+EXPOSURE_PEAK) fresh -> x1.0 converged, monotone decreasing.
## Extracted so the law has a surface a probe can assert. Inlined, it was untestable,
## and test_ai_fairness called a function Track C had deleted - so the probe SCRIPT
## ERRORed, never reached quit(), and hung the whole suite instead of failing.
static func exposure_spread_mult(exposure_t: float) -> float:
	var t: float = clampf(exposure_t, 0.0, 1.0)
	return 1.0 + EXPOSURE_PEAK * (1.0 - t * t)


static func aim_with_spread(base_aim: Vector3, pre_cap_spread_deg: float, is_player_target: bool,
		exposure_t: float, force_first_miss: bool) -> Vector3:
	var s: float = pre_cap_spread_deg
	var cap: float = PLAYER_CONE_CAP_DEG
	if is_player_target:
		# Fairness ramp + the difficulty knob live here, on the shot at the player. The cap
		# MUST breathe with the ramp: any weapon whose natural cone already exceeds the cap
		# (AK base 2.2 -> ~1.7 deg) fires the capped cone both fresh AND converged, so a fixed
		# cap silently clips the whole exposure ramp away - the opening volley was as lethal as
		# the converged one. Breathing the cap restores the "first shots miss, accuracy ramps".
		s *= exposure_spread_mult(exposure_t) * GameSettings.enemy_spread_mult()
		cap *= exposure_spread_mult(exposure_t)
	else:
		cap *= maxf(1.0, GameSettings.ai_vs_ai_cone_mult)
	var aim: Vector3 = _apply_cone(base_aim, minf(s, cap))
	if force_first_miss and is_player_target:
		aim = _first_shot_nudge(aim)
	return aim
