## probe_ballistics.gd - THE FIREFIGHT AUDIT: what our rounds actually do.
## Per weapon, at real engagement ranges: time of flight, gravity drop below
## the point of aim (we have NO sight zero - the bullet leaves along the
## crosshair ray and only falls), and the ADS dispersion cone the shooter
## cannot control. Cone is reported as the SQUARE the uniform per-axis RNG
## actually draws from - a man's chest is ~0.45m wide.
##   godot --headless --path . -s res://tools/probe_ballistics.gd
extends SceneTree

const RANGES: Array[float] = [25.0, 50.0, 100.0, 200.0, 300.0, 400.0]
const GRAVITY: float = 9.8  # BulletSystem.GRAVITY
## Real muzzle velocities for the reference column (m/s, period-correct).
const REAL_MV: Dictionary = {
	"m16a1": 948, "m14": 853, "m60": 853, "ak47": 715, "rpd": 735,
	"ppsh41": 500, "mosin": 865, "m70": 890, "m1911": 253, "shotgun": 400,
	"m79": 76, "rpg2": 84, "rpg7": 115, "m72_law": 145,
}


func _initialize() -> void:
	var ids: Array[String] = ["m16a1", "m14", "m60", "ak47", "rpd", "ppsh41",
		"mosin", "m70", "m1911", "shotgun"]
	print("\n=== MUZZLE VELOCITY vs REALITY ===")
	print("weapon        game     real     verdict")
	for id in ids:
		var wd: WeaponData = load("res://data/weapons/%s.tres" % id)
		if wd == null:
			continue
		var real: float = float(REAL_MV.get(id, 0))
		var off: float = ((wd.projectile_speed / maxf(1.0, real)) - 1.0) * 100.0
		print("%-12s %6.0f   %6.0f   %+.0f%%%s" % [id, wd.projectile_speed, real, off,
			"   <-- OFF" if absf(off) > 8.0 else "   ok"])

	print("\n=== FLIGHT: time + drop below point of aim (no sight zero, no drag) ===")
	print("weapon        range   TOF      drop     verdict")
	for id in ids:
		var wd: WeaponData = load("res://data/weapons/%s.tres" % id)
		if wd == null:
			continue
		for r in RANGES:
			if r > wd.max_range:
				continue
			var t: float = r / maxf(1.0, wd.projectile_speed)
			var drop: float = 0.5 * GRAVITY * t * t
			var verdict: String = "ok"
			if drop > 0.35:
				verdict = "MISSES A STANDING MAN LOW"
			elif drop > 0.15:
				verdict = "chest -> gut/legs"
			print("%-12s %5.0fm  %.3fs   %.2fm   %s" % [id, r, t, drop, verdict])

	print("\n=== ADS DISPERSION: the cone the player cannot control ===")
	print("(per-axis uniform RNG -> a SQUARE; chest ~0.45m wide, head ~0.20m)")
	print("weapon        ads_deg   50m      100m     200m     300m")
	for id in ids:
		var wd: WeaponData = load("res://data/weapons/%s.tres" % id)
		if wd == null:
			continue
		var ads_deg: float = wd.get_spread(1.0)
		var line: String = "%-12s %6.2f " % [id, ads_deg]
		for r in [50.0, 100.0, 200.0, 300.0]:
			var half: float = tan(deg_to_rad(ads_deg)) * r
			line += "  %6.2fm" % (half * 2.0)  # full square width
		print(line)
	print("\n(width = the full square a perfectly aimed shot can land in, before")
	print(" skill/stance/recoil. Reference: Arma rifle dispersion ~0.03-0.07 deg;")
	print(" HLL/Arma both put the FIRST settled ADS shot exactly on the sights.)")
	quit(0)
