## test_concealment.gd - proves the "getting seen at 150m is not instant death" fix:
## the AI-vs-player spread cap now BREATHES with the exposure ramp, so the opening volley
## at a freshly-spotted player scatters wide and tightens only as he stays exposed (Fairness
## Law, ADR-005). Before the fix the fixed 1.2 deg cap clipped the whole ramp - fresh and
## converged fired the identical lethal cone. Pure-function proof (no scene needed).
extends Node

## An over-cap weapon like the AK (base_spread ~2.2 -> natural cone > 1.2 deg): the exact
## case where the old fixed cap silently ate the ramp.
const BASE_SPREAD_DEG: float = 2.2
const ACC01: float = 0.6
const SAMPLES: int = 4000


func _ready() -> void:
	var fails: int = 0
	var pre_cap: float = AIMarksmanship.cone_spread_deg(BASE_SPREAD_DEG, ACC01, 0, false, 1.0)
	var fresh: float = _mean_cone_deg(pre_cap, 0.0)     # exposure_t 0 = just spotted
	var converged: float = _mean_cone_deg(pre_cap, 1.0) # exposure_t 1 = fully exposed

	print("=== CONCEALMENT / FAIRNESS RAMP ===")
	print("pre-cap cone=%.2f deg | fresh mean=%.2f deg | converged mean=%.2f deg | ratio=%.2f" % [
		pre_cap, fresh, converged, fresh / maxf(0.01, converged)])

	# 1. The ramp is ALIVE: a freshly-spotted player is shot at MUCH wider than a converged one.
	if fresh <= converged * 1.8:
		print("FAIL: exposure ramp dead - fresh cone (%.2f) not meaningfully wider than converged (%.2f)" % [fresh, converged])
		fails += 1
	else:
		print("PASS: opening volley scatters wide (%.2fx), tightens as exposure ramps" % (fresh / converged))

	# 2. Converged fire is still lethal-tight (the cap still bites at full exposure).
	if converged > AIMarksmanship.PLAYER_CONE_CAP_DEG + 0.1:
		print("FAIL: converged cone %.2f exceeds the %.2f deg player cap - AI never lands" % [
			converged, AIMarksmanship.PLAYER_CONE_CAP_DEG])
		fails += 1
	else:
		print("PASS: converged fire stays within the lethal cap (%.2f <= %.2f)" % [
			converged, AIMarksmanship.PLAYER_CONE_CAP_DEG])

	# 3. The ramp multiplier is monotone decreasing (fresh widest).
	var m0: float = AIMarksmanship.exposure_spread_mult(0.0)
	var m1: float = AIMarksmanship.exposure_spread_mult(1.0)
	if not (m0 > m1 and absf(m1 - 1.0) < 0.01):
		print("FAIL: exposure mult not fresh>converged==1 (m0=%.2f m1=%.2f)" % [m0, m1])
		fails += 1

	print("")
	if fails == 0:
		print("=== CONCEALMENT PROBE PASS ===")
		get_tree().quit(0)
	else:
		print("=== CONCEALMENT PROBE FAIL (%d) ===" % fails)
		get_tree().quit(1)


## Mean angular deviation (deg) of shots at the player from the aim line, over SAMPLES.
func _mean_cone_deg(pre_cap_deg: float, exposure_t: float) -> float:
	var base_aim := Vector3(0, 0, -1)
	var total: float = 0.0
	for i in range(SAMPLES):
		var shot: Vector3 = AIMarksmanship.aim_with_spread(base_aim, pre_cap_deg, true, exposure_t, false)
		total += rad_to_deg(base_aim.angle_to(shot))
	return total / float(SAMPLES)
