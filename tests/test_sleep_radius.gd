## test_sleep_radius.gd - the sleep-radius invariant (War Room 2026-09-14, ruling 1).
## A man past TerrainWatchdog.SUSPEND_DIST has physics off and therefore no ears, so every
## radius the NoiseBus can emit must fall short of that ring, and the sticky COMBAT ceiling
## (AILod.STICKY_MAX_M) must sit inside it too. Pure: no world, no clock. Quits 0/1.
extends Node

var _fail: int = 0


func _check(ok: bool, msg: String) -> void:
	if ok:
		print("  PASS: %s" % msg)
	else:
		print("  FAIL: %s" % msg)
		_fail += 1


func _ready() -> void:
	print("\n=== SLEEP RADIUS ===")
	_radii()
	_rings()
	_clamp()
	if _fail == 0:
		print("=== SLEEP RADIUS PASS ===")
	else:
		print("=== SLEEP RADIUS FAILED (%d) ===" % _fail)
	get_tree().quit(1 if _fail > 0 else 0)


func _radii() -> void:
	var ring: float = TerrainWatchdog.SUSPEND_DIST
	for type in NoiseBus.RADII.keys():
		var r: float = float(NoiseBus.RADII[type]) * NoiseBus.RADIUS_MULTIPLIER_MAX
		_check(r < ring, "noise type %d carries %.0f m, under the %.0f m ring" % [int(type), r, ring])
	_check(NoiseBus.loudest_radius() < ring,
		"loudest radius %.0f m is under the ring" % NoiseBus.loudest_radius())
	for wid in MissionWeather.WEATHER.keys():
		var mult: float = float((MissionWeather.WEATHER[wid] as Dictionary).get("noise", 1.0))
		_check(mult <= NoiseBus.RADIUS_MULTIPLIER_MAX,
			"weather %s noise x%.2f is within RADIUS_MULTIPLIER_MAX" % [str(wid), mult])


func _rings() -> void:
	_check(AILod.STICKY_MAX_M < TerrainWatchdog.SUSPEND_DIST,
		"sticky COMBAT ceiling %.0f m is inside the %.0f m ring" % [
			AILod.STICKY_MAX_M, TerrainWatchdog.SUSPEND_DIST])
	_check(TerrainWatchdog.RESUME_DIST < TerrainWatchdog.SUSPEND_DIST,
		"resume %.0f m is inside suspend %.0f m (hysteresis)" % [
			TerrainWatchdog.RESUME_DIST, TerrainWatchdog.SUSPEND_DIST])


func _clamp() -> void:
	var heard: Array[float] = []
	var ear := func(_t: int, _p: Vector3, radius: float, _team: int, _src: Node) -> void:
		heard.append(radius)
	NoiseBus.noise_emitted.connect(ear)
	var prior: float = NoiseBus.radius_multiplier
	NoiseBus.radius_multiplier = 4.0
	NoiseBus.emit_noise(NoiseBus.NoiseType.GUNSHOT, Vector3.ZERO)
	NoiseBus.emit_noise(NoiseBus.NoiseType.GUNSHOT, Vector3.ZERO, 0, 500.0)
	NoiseBus.radius_multiplier = prior
	NoiseBus.noise_emitted.disconnect(ear)
	_check(heard.size() == 2, "two emits reached the ear")
	for r in heard:
		_check(r < TerrainWatchdog.SUSPEND_DIST,
			"an over-loud emit (x4, and a 500 m override) is clamped to %.0f m" % r)
