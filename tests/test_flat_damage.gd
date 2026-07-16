## test_flat_damage.gd - ADR-016 verification probe (Summoner decree 2026-07-10).
## Locks in the flat-base damage grammar that replaced RECON dice:
##   1. get_damage() is DETERMINISTIC - same value on every call, per weapon.
##   2. Every weapon carries its decreed flat value (derived from the retired
##      dice averages) - a regression here is an unratified retune.
##   3. No legacy dice grammar survives: base_damage is an int on every
##      WeaponData/ProjectileData in data/.
##   4. Shots-to-kill sanity vs the HP bands of record (player 100, enemy 65-85)
##      through the hitzone multipliers (TORSO 2.5 / GUT 2.25 / LIMB 1.0 -
##      ADR-016 Amendment D).
## Run: godot --headless --path . res://tests/test_flat_damage.tscn
extends Node

## The decreed values (ADR-016 Amendment H — the great flattening, 2026-07-16).
## Change ONLY with an ADR amendment. Base = 27 for every rifle/SMG/pistol;
## MG class = 42 (27+15, M60 AND RPD); sniper = 87 (27+60, M70 only — the
## Mosin stays base 27 as the VC line rifle vc_rifleman carries).
const EXPECTED := {
	"m16a1": 27, "m14": 27, "m60": 42,
	"ak47": 27, "rpd": 42,
	"ppsh41": 27, "m1911": 27, "mosin": 27, "m70": 87,
	"m79": 150, "m26_grenade": 190, "m72_law": 250, "rpg2": 250, "rpg7": 290,
	"shotgun": 35,  # BUCKSHOT (Amendment E + Summoner devastator retune) - 9 x 35
}
## Heavy classes that one-shot the player torso BY DECREE (Amendment H) — exempt
## from the base-class no-one-shot rail below, exactly as the shotgun is.
const HEAVY_ONESHOT := ["m60", "rpd", "m70", "shotgun"]
## Retired - loading one of these is a FAIL. mp40/kar98k by ADR-016;
## car15/sks/thompson by Amendment C (no FP arms = not a gun in this game;
## vc_rifleman now fires the Mosin his model carries).
const RETIRED := ["mp40", "kar98k", "car15", "sks", "thompson"]

## Values of record: ADR-016 Amendment D (2026-07-11, Summoner: "weapons
## should be more punishing"). Duplicated here ON PURPOSE - retuning the law
## without amending the ADR turns this suite red.
const ZONE_MULTS := {"TORSO": 2.5, "GUT": 2.25, "LIMB": 1.0}
const HP_BANDS := {"player": 100, "enemy_lo": 65, "enemy_hi": 85}


func _ready() -> void:
	_run()


func _run() -> void:
	var failures: int = 0

	# --- 1+2. deterministic AND on-decree -----------------------------------
	for wid: String in EXPECTED.keys():
		var wd: WeaponData = load("res://data/weapons/%s.tres" % wid) as WeaponData
		if wd == null:
			print("FAIL: %s did not load as WeaponData" % wid)
			failures += 1
			continue
		var first: int = wd.get_damage()
		for _i in range(100):
			if wd.get_damage() != first:
				print("FAIL: %s damage is non-deterministic" % wid)
				failures += 1
				break
		if first != int(EXPECTED[wid]):
			print("FAIL: %s flat damage %d != decreed %d" % [wid, first, int(EXPECTED[wid])])
			failures += 1

	# --- 3. the dice grammar is dead ----------------------------------------
	for wid: String in RETIRED:
		if ResourceLoader.exists("res://data/weapons/%s.tres" % wid):
			print("FAIL: retired weapon %s.tres still exists" % wid)
			failures += 1
	var proj: ProjectileData = load("res://data/projectiles/rpg2_rocket.tres") as ProjectileData
	if proj == null:
		print("FAIL: rpg2_rocket.tres did not load as ProjectileData")
		failures += 1
	elif proj.get_damage() != 250:
		print("FAIL: rpg2_rocket flat damage %d != decreed 250" % proj.get_damage())
		failures += 1

	# --- 3.5 the live locational law matches this ADR record -----------------
	if absf(float(Hitzone.MULTIPLIERS[Hitzone.ZoneType.TORSO]) - float(ZONE_MULTS["TORSO"])) > 0.001 \
			or absf(float(Hitzone.MULTIPLIERS[Hitzone.ZoneType.GUT]) - float(ZONE_MULTS["GUT"])) > 0.001 \
			or absf(float(Hitzone.MULTIPLIERS[Hitzone.ZoneType.LIMB]) - float(ZONE_MULTS["LIMB"])) > 0.001:
		print("FAIL: Hitzone.MULTIPLIERS drifted from the ADR-016 Amendment D record")
		failures += 1

	# --- 4. shots-to-kill matrix (sanity + printed record) ------------------
	# HEAD is fatal by rule (hitzone.is_fatal_zone), so only body zones matter.
	var tm: float = float(ZONE_MULTS["TORSO"])
	print("  STK matrix (torso x%.2f), point blank:" % tm)
	for wid: String in ["m16a1", "ak47", "mosin", "ppsh41", "m1911"]:
		var dmg: int = int(EXPECTED[wid])
		var torso: int = int(float(dmg) * tm)
		var stk_p: int = int(ceil(100.0 / float(torso)))
		var stk_lo: int = int(ceil(65.0 / float(torso)))
		var stk_hi: int = int(ceil(85.0 / float(torso)))
		print("    %-8s %2d dmg -> torso %3d | player %d hits, enemy %d-%d hits" % [
			wid, dmg, torso, stk_p, stk_lo, stk_hi])
	# HLL-lethality guards: rifles must down an enemy in <=2 torso hits and the
	# player in <=3; nothing one-shots the player's torso (situation kills, not stats).
	for wid: String in ["m16a1", "ak47", "m14"]:
		var torso: int = int(float(EXPECTED[wid]) * tm)
		if int(ceil(85.0 / float(torso))) > 2:
			print("FAIL: %s needs >2 torso hits vs 85hp enemy - not HLL-lethal" % wid)
			failures += 1
		if int(ceil(100.0 / float(torso))) > 3:
			print("FAIL: %s needs >3 torso hits vs player - not HLL-lethal" % wid)
			failures += 1
	for wid: String in EXPECTED.keys():
		if wid in ["m79", "m26_grenade", "m72_law", "rpg2", "rpg7"]:
			continue  # explosives resolve through AOE, not a torso ray
		if wid in HEAVY_ONESHOT:
			continue  # MG/sniper/buckshot are the execution weapons - they one-shot
			          # the player torso by decree; the rail binds only the base-27 class
		if int(float(EXPECTED[wid]) * tm) >= 100:
			print("FAIL: %s one-shots the player's torso (the old Mosin bug class)" % wid)
			failures += 1

	if failures == 0:
		print("PASS: ADR-016 flat damage grammar (%d weapons) OK" % EXPECTED.size())
	else:
		print("FAIL: flat damage suite had %d failure(s)" % failures)
	get_tree().quit(1 if failures > 0 else 0)
