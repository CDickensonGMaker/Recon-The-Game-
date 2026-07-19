## test_weapon_projectile_contract.gd - the ratchet that makes the RPG-7 class of
## bug impossible (2026-07-19).
##
## ROOT CAUSE it guards: rpg7.tres and m72_law.tres both pointed
## projectile_data_path at rpg2_rocket.tres. Nothing bound a weapon's record to
## the round it actually fires, so the RPG-7 detonated for the RPG-2's 250
## instead of its decreed 290, and the LAW flew at the RPG-2's 84 m/s instead of
## its declared 145. Two files diverging silently for as long as they existed.
##
## THE INVARIANTS (ADR-016: the weapon .tres carries the value OF RECORD, so the
## projectile is the one that must agree):
##   1. Every non-empty projectile_data_path resolves to a real ProjectileData.
##   2. projectile.base_damage == weapon.base_damage
##   3. projectile.speed == weapon.projectile_speed
##   4. Every weapon .tres DECLARES ads_rotation explicitly. A missing line is
##      indistinguishable at runtime from a deliberate Vector3.ZERO, and zero
##      makes the viewmodel swing the full hip_rotation on every ADS raise
##      (weapon_holder.gd:771 lerps hip_rotation -> ads_rotation).
##   5. hip_rotation and ads_rotation stay within MAX_ADS_SWING degrees per axis
##      or the weapon visibly spins through the transition.
##   6. ads_fov is a real per-weapon value at or below the 75.0 hip FOV (ADR-004).
##
## Run: godot --headless --path . res://tests/test_weapon_projectile_contract.tscn
extends Node

const WEAPON_DIR: String = "res://data/weapons/"
## Widest authored swing on main is m79/shotgun at ~9.4 degrees. 90 is the hard
## rail from the ADS decree; the assert exists to catch a sign flip or a stray
## 180, not to police taste.
const MAX_ADS_SWING: float = 90.0
const HIP_FOV: float = 75.0


func _ready() -> void:
	_run()


func _run() -> void:
	var failures: int = 0
	var weapons_checked: int = 0
	var projectiles_checked: int = 0

	var names: PackedStringArray = ResourceLoader.list_directory(WEAPON_DIR)
	if names.is_empty():
		print("FAIL: no weapon resources found under %s" % WEAPON_DIR)
		failures += 1

	for fname: String in names:
		if not fname.ends_with(".tres"):
			continue
		var path: String = WEAPON_DIR + fname
		var wd: WeaponData = load(path) as WeaponData
		if wd == null:
			print("FAIL: %s did not load as WeaponData" % fname)
			failures += 1
			continue
		weapons_checked += 1

		# --- 1-3. the weapon and the round it fires must agree ---------------
		if wd.projectile_data_path != "":
			var pd: ProjectileData = load(wd.projectile_data_path) as ProjectileData
			if pd == null:
				print("FAIL: %s projectile_data_path '%s' did not load as ProjectileData" \
					% [wd.id, wd.projectile_data_path])
				failures += 1
			else:
				projectiles_checked += 1
				if pd.base_damage != wd.base_damage:
					print("FAIL: %s fires %s doing %d, but its record is %d" \
						% [wd.id, pd.id, pd.base_damage, wd.base_damage])
					failures += 1
				if absf(pd.speed - wd.projectile_speed) > 0.001:
					print("FAIL: %s declares projectile_speed %.1f but %s flies at %.1f" \
						% [wd.id, wd.projectile_speed, pd.id, pd.speed])
					failures += 1

		# --- 4. ads_rotation must be authored, not inherited from the script --
		var text: String = FileAccess.get_file_as_string(path)
		if not text.contains("ads_rotation"):
			print("FAIL: %s declares no ads_rotation - it silently inherits Vector3.ZERO and swings %.1f degrees on ADS" \
				% [wd.id, wd.hip_rotation.length()])
			failures += 1

		# --- 5. the transition must not spin ---------------------------------
		var swing: Vector3 = (wd.ads_rotation - wd.hip_rotation).abs()
		if swing.x > MAX_ADS_SWING or swing.y > MAX_ADS_SWING or swing.z > MAX_ADS_SWING:
			print("FAIL: %s swings (%.1f, %.1f, %.1f) degrees hip->ADS, over the %.0f rail" \
				% [wd.id, swing.x, swing.y, swing.z, MAX_ADS_SWING])
			failures += 1

		# --- 6. ADS narrows the view (ADR-004) -------------------------------
		if wd.ads_fov <= 0.0 or wd.ads_fov > HIP_FOV:
			print("FAIL: %s ads_fov %.1f is not a usable value at or below the %.1f hip FOV" \
				% [wd.id, wd.ads_fov, HIP_FOV])
			failures += 1

	print("weapons checked: %d, weapon->projectile pairs checked: %d" \
		% [weapons_checked, projectiles_checked])
	if weapons_checked < 15:
		print("FAIL: only %d weapons enumerated - the armory is 15+; the scan is broken" % weapons_checked)
		failures += 1
	if projectiles_checked < 4:
		print("FAIL: only %d projectile pairs enumerated - m79/rpg2/rpg7/m72_law all carry one" % projectiles_checked)
		failures += 1

	if failures == 0:
		print("PASS: weapon/projectile contract clean")
	else:
		print("FAILURES: %d" % failures)
	get_tree().quit(1 if failures > 0 else 0)
