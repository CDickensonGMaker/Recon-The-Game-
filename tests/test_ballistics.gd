## test_ballistics.gd - Locks in the gunplay data/feel pass (2026-07-08).
## Guards the three bugs that were invisible in code review:
##   1. framerate-dependent RPM (every full-auto collapsed to ~600rpm @60fps)
##   2. bolt-action *2.5 patch making the Kar98k a 10-second-per-shot weapon
##   3. dead effective_range (no damage falloff existed)
## Also asserts every weapon .tres loads with the new schema.
## Run: godot --headless --path . res://tests/test_ballistics.tscn
extends Node

const WEAPONS := [
	"m16a1", "m14", "m60", "ak47", "rpd", "ppsh41", "mosin", "m70",
	"m1911", "shotgun", "m79", "m72_law", "rpg2", "rpg7", "m26_grenade",
]


func _ready() -> void:
	_run()


func _run() -> void:
	var failures: int = 0

	# --- 1. every weapon loads with the full schema -----------------------
	var loaded: Dictionary = {}
	for wid in WEAPONS:
		var path := "res://data/weapons/%s.tres" % wid
		var wd: WeaponData = load(path) as WeaponData
		if wd == null:
			print("FAIL: %s did not load as WeaponData" % wid)
			failures += 1
			continue
		loaded[wid] = wd
		# new fields must exist and be sane
		if wd.min_damage_mult < 0.2 or wd.min_damage_mult > 1.0:
			print("FAIL: %s min_damage_mult out of range: %f" % [wid, wd.min_damage_mult])
			failures += 1
		if wd.recoil_recovery <= 0.0:
			print("FAIL: %s recoil_recovery must be > 0" % wid)
			failures += 1

	# --- 2. cadence accumulator is framerate-INDEPENDENT ------------------
	# Replicates weapon_holder's accumulator model against the authored data.
	# The old absolute-assignment model gave different counts at 60 vs 144 fps
	# and collapsed distinct RPMs onto the same value.
	for wid in ["rpd", "ak47", "m16a1", "ppsh41"]:
		if not loaded.has(wid):
			continue
		var wd: WeaponData = loaded[wid]
		var n60: int = _sim_auto(wd.get_fire_delay(), 60.0, 3.0)
		var n144: int = _sim_auto(wd.get_fire_delay(), 144.0, 3.0)
		var expected: float = wd.fire_rate / 60.0 * 3.0  # rounds in 3s
		# accumulator should land within one round of ideal at BOTH framerates
		if absf(float(n60) - expected) > 1.5:
			print("FAIL: %s @60fps fired %d, expected ~%.0f" % [wid, n60, expected])
			failures += 1
		if absi(n60 - n144) > 1:
			print("FAIL: %s cadence framerate-DEPENDENT: 60fps=%d 144fps=%d" % [wid, n60, n144])
			failures += 1
		print("  %s: %.0f rpm authored -> %d/%d rounds @60/144fps in 3s" % [wid, wd.fire_rate, n60, n144])

	# --- 3. bolt guns cycle in a usable time (the *2.5 bug made it 10s) ----
	for wid in ["mosin"]:
		if not loaded.has(wid):
			continue
		var wd: WeaponData = loaded[wid]
		var cycle: float = wd.get_fire_delay()
		if cycle > 2.5:
			print("FAIL: %s bolt cycle %.2fs is unusable (the *2.5 bug?)" % [wid, cycle])
			failures += 1
		if wd.firing_mode != Enums.FiringMode.BOLT_ACTION:
			print("FAIL: %s should be BOLT_ACTION" % wid)
			failures += 1
		print("  %s bolt cycle: %.2fs" % [wid, cycle])

	# --- 4. damage falloff wiring -----------------------------------------
	var ak: WeaponData = loaded.get("ak47")
	if ak:
		var at_eff: float = ak.damage_multiplier_at(ak.effective_range)
		var at_max: float = ak.damage_multiplier_at(ak.max_range)
		var at_close: float = ak.damage_multiplier_at(0.0)
		if not is_equal_approx(at_close, 1.0):
			print("FAIL: falloff at point-blank should be 1.0, got %f" % at_close)
			failures += 1
		if not is_equal_approx(at_eff, 1.0):
			print("FAIL: falloff at effective_range should be 1.0, got %f" % at_eff)
			failures += 1
		if not is_equal_approx(at_max, ak.min_damage_mult):
			print("FAIL: falloff at max_range should equal min_damage_mult" % [])
			failures += 1
		# monotone non-increasing across the band
		var prev: float = 1.1
		for step in range(21):
			var d: float = ak.max_range * float(step) / 20.0
			var m: float = ak.damage_multiplier_at(d)
			if m > prev + 0.0001:
				print("FAIL: falloff not monotone at %.1fm (%f > %f)" % [d, m, prev])
				failures += 1
				break
			prev = m

	# --- 5. subsonic weapons flagged correctly (no crack) -----------------
	for wid in ["m1911", "thompson"]:
		if loaded.has(wid) and loaded[wid].is_supersonic:
			print("FAIL: %s (subsonic round) marked supersonic" % wid)
			failures += 1
	for wid in ["m16a1", "ak47", "mosin"]:
		if loaded.has(wid) and not loaded[wid].is_supersonic:
			print("FAIL: %s (supersonic round) not marked supersonic" % wid)
			failures += 1

	if failures == 0:
		print("PASS: ballistics data + cadence + falloff (%d weapons) OK" % WEAPONS.size())
	else:
		print("FAIL: ballistics suite had %d failure(s)" % failures)
	get_tree().quit(1 if failures > 0 else 0)


## Faithful replica of weapon_holder._process + _fire_shot accumulator for a
## full-auto weapon with the trigger held. Fixed dt, MAX_CATCHUP_SHOTS=2.
func _sim_auto(delay: float, fps: float, seconds: float) -> int:
	var dt: float = 1.0 / fps
	var fire_timer: float = 0.0
	var shots: int = 0
	var frames: int = int(seconds * fps)
	for _i in range(frames):
		if fire_timer > 0.0:
			fire_timer -= dt
		# _handle_input: FULL_AUTO catch-up while loop (cap 2)
		var fired: int = 0
		while fire_timer <= 0.0 and fired < 2:
			fire_timer += delay
			shots += 1
			fired += 1
	return shots
