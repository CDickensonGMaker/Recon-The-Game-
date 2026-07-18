## test_mission_scope.gd - state must not survive a mission boundary.
extends Node
var _fail := 0
func _bad(m: String) -> void: print("FAIL: %s" % m); _fail += 1
func _ready() -> void:
	# Dirty every leak the audit found.
	var d1 := FieldDirector.new()
	d1.fire_menu_open = true
	d1.free()
	EnemyBase._cover_claims[Vector3i(1, 2, 3)] = {"enemy": null}
	GunFX._sting_cooldown_until = Time.get_ticks_msec() + 25000
	# apply_damage() no-ops without a terrain_manager, which would make the two
	# assertions below vacuous. Populate the autoload's arrays directly - they are
	# exactly what survives _teardown_world() (probe_smoke_all proved it with a
	# real world: 1 scar decal + 1 damage zone lived into the next mission).
	DamageSystem.damage_zones.append({"pos": Vector3(10, 0, 10), "radius": 4.0})
	var decal := Decal.new()
	DamageSystem.add_child(decal)
	DamageSystem.scar_decals.append(decal)
	SpriteLibrary.manifest("US Army and Co", "us_grunt", "m16a1", "run_forward")
	await get_tree().process_frame

	print("  before: fire_menu=%s claims=%d scars=%d zones=%d sting_cd=%s sheets=%d" % [
		FieldDirector.any_fire_menu_open, EnemyBase._cover_claims.size(),
		DamageSystem.scar_decals.size(), DamageSystem.damage_zones.size(),
		GunFX._sting_cooldown_until > 0, SpriteLibrary._textures.size()])

	MissionScope.reset()
	await get_tree().process_frame

	if FieldDirector.any_fire_menu_open: _bad("any_fire_menu_open survived - kit keys stay dead")
	if EnemyBase._cover_claims.size() != 0: _bad("%d cover claims survived" % EnemyBase._cover_claims.size())
	if DamageSystem.scar_decals.size() != 0: _bad("%d scar decals survived" % DamageSystem.scar_decals.size())
	if DamageSystem.damage_zones.size() != 0: _bad("%d damage zones survived" % DamageSystem.damage_zones.size())
	if GunFX._sting_cooldown_until != 0: _bad("sting cooldown survived - CONTACT drum muted next mission")
	if SpriteLibrary._manifests.size() != 0: _bad("sprite cache survived")

	print("  after:  fire_menu=%s claims=%d scars=%d zones=%d sting_cd=%s sheets=%d" % [
		FieldDirector.any_fire_menu_open, EnemyBase._cover_claims.size(),
		DamageSystem.scar_decals.size(), DamageSystem.damage_zones.size(),
		GunFX._sting_cooldown_until > 0, SpriteLibrary._textures.size()])
	print("PASS: mission scope" if _fail == 0 else "FAIL: %d" % _fail)
	get_tree().quit(0 if _fail == 0 else 1)
