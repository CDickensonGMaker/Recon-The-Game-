## test_smoke_all.gd - exercise every surface the 24-test suite never touches,
## and convert audit CLAIMS into executed PROOF. Named probe_* so run_all_tests
## skips it (it is a diagnostic, not a gate).
##
## Run: godot --headless --path . res://tests/test_smoke_all.tscn -- --test-save
extends Node

var _pass: int = 0
var _fail: int = 0


func _ok(name: String, msg: String = "") -> void:
	_pass += 1
	print("  OK   %-46s %s" % [name, msg])


func _bad(name: String, msg: String) -> void:
	_fail += 1
	print("  FAIL %-46s %s" % [name, msg])


func _ready() -> void:
	_run()


func _run() -> void:
	print("=== A. UI SCREENS (no test instantiates Barracks/Settings/ServiceRecord) ===")
	await _probe_screens()

	print("\n=== B. STATIC STATE LEAKS ACROSS MISSIONS ===")
	_probe_fire_menu_static()

	print("\n=== C. DETERMINISM / SEED REPLAY (R88) ===")
	_probe_personality_unseeded()

	print("\n=== D. WORLD-DEPENDENT PROBES ===")
	await _probe_world_things()

	print("\n=== SMOKE SUMMARY: %d OK / %d FAIL ===" % [_pass, _fail])
	get_tree().quit(0)


# ---------------------------------------------------------------- A. screens
func _probe_screens() -> void:
	var screens: Array = [
		["MainMenuScreen", MainMenuScreen],
		["DebriefScreen", DebriefScreen],
		["BarracksScreen", BarracksScreen],
		["SettingsScreen", SettingsScreen],
		["ServiceRecordScreen", ServiceRecordScreen],
	]
	for entry in screens:
		var label: String = str(entry[0])
		var scr: Object = entry[1]
		var inst: Node = (scr as Script).new() if scr is Script else null
		if inst == null:
			# class_name refs resolve to the class, not a Script, in some contexts
			_bad(label, "could not instantiate")
			continue
		add_child(inst)
		await get_tree().process_frame
		var kids: int = inst.get_child_count()
		if kids == 0:
			_bad(label, "_ready() built no children - blank screen")
		else:
			_ok(label, "%d child nodes" % kids)
		inst.queue_free()
		await get_tree().process_frame


# ------------------------------------------------------- B. static leakage
func _probe_fire_menu_static() -> void:
	# Simulate: open the fire menu, then die/exfil (director freed), then next
	# mission constructs a fresh FieldDirector.
	FieldDirector.any_fire_menu_open = false
	var d1 := FieldDirector.new()
	d1.fire_menu_open = true                     # player pressed T
	if not FieldDirector.any_fire_menu_open:
		_bad("fire_menu static set", "setter did not propagate")
		d1.free()
		return
	d1.free()                                    # mission ends with menu open

	# The mission boundary is _teardown_world(), which calls MissionScope.reset()
	# (game_flow.gd:116). Constructing a bare FieldDirector skips it and tests a
	# path the game never takes: a fresh director declares
	# `var fire_menu_open: bool = false` and GDScript does not run the setter for
	# a member initializer, so the static survives a construction it never sees.
	MissionScope.reset()

	var d2 := FieldDirector.new()              # next mission
	if FieldDirector.any_fire_menu_open:
		_bad("any_fire_menu_open reset on new mission",
			"STILL TRUE across MissionScope.reset() -> equipment_manager.gd:62 blocks all slot keys, player.gd:528 blocks smoke. SOFTLOCK until T pressed twice.")
	else:
		_ok("any_fire_menu_open reset on new mission")
	d2.free()


# ------------------------------------------------------ C. determinism
func _probe_personality_unseeded() -> void:
	# enemy_base.gd:180 uses Array.pick_random() -> global RNG. Two enemies from
	# the same .tres on the same mission seed should be reproducible.
	seed(4242)
	var first: Array = []
	for i in range(8):
		first.append([Enums.AIPersonality.AGGRESSIVE, Enums.AIPersonality.DEFENSIVE, Enums.AIPersonality.BALANCED].pick_random())
	seed(4242)
	var second: Array = []
	for i in range(8):
		second.append([Enums.AIPersonality.AGGRESSIVE, Enums.AIPersonality.DEFENSIVE, Enums.AIPersonality.BALANCED].pick_random())
	if first == second:
		_ok("pick_random() honours seed()", "reseedable, so a MissionRNG fix will work")
	else:
		_bad("pick_random() honours seed()", "not reproducible even after seed()")


# ------------------------------------------------------ D. world probes
func _probe_world_things() -> void:
	var scene: PackedScene = load("res://scenes/levels/game_world.tscn")
	var w1: GameWorld = scene.instantiate()
	w1.mission_seed = 777
	w1.spawn_player_on_ready = false
	add_child(w1)
	var t: float = 0.0
	while not w1.is_world_ready and t < 180.0:
		await get_tree().create_timer(0.5).timeout
		t += 0.5
	if not w1.is_world_ready:
		_bad("world boots", "timeout")
		return

	# --- B: vc camp layout varies with its rng (stamp_firebase died with fsb_main, task 6b) ---
	var p1 := SitePlanner.new(w1.gameplay_grid, w1.terrain_manager, w1.vegetation_manager, w1)
	var rngA := RandomNumberGenerator.new(); rngA.seed = 1
	var rngB := RandomNumberGenerator.new(); rngB.seed = 999999
	var center: Vector3 = p1.find_site(rngA, 14.0)
	var fbA: Dictionary = p1.stamp_vc_camp(center, rngA)
	var fbB: Dictionary = p1.stamp_vc_camp(center + Vector3(300, 0, 0), rngB)
	var offsetsA: Array = _local_offsets(fbA.nodes, center)
	var offsetsB: Array = _local_offsets(fbB.nodes, center + Vector3(300, 0, 0))
	if offsetsA == offsetsB:
		_bad("vc camp layout varies with seed",
			"identical layout for seeds 1 and 999999 (%d structures). stamp_vc_camp(center, rng) never reads rng." % offsetsA.size())
	else:
		_ok("vc camp layout varies with seed")

	# --- E: DamageSystem craters survive world teardown ---
	DamageSystem.apply_damage(center + Vector3(0, 0, 60), DamageSystem.DamageType.LARGE_EXPLOSION)
	await get_tree().process_frame
	var scars_before: int = DamageSystem.scar_decals.size()
	var zones_before: int = DamageSystem.damage_zones.size()

	# Freeing the world is only half of _teardown_world(); the other half is
	# MissionScope.reset() (game_flow.gd:116), which owns the autoload-side
	# hygiene. decal_container hangs off the AUTOLOAD, not GameWorld, so the
	# world dying cannot clear it and was never meant to.
	w1.queue_free()
	MissionScope.reset()
	await get_tree().process_frame
	await get_tree().create_timer(0.5).timeout

	var scars_after: int = DamageSystem.scar_decals.size()
	var zones_after: int = DamageSystem.damage_zones.size()
	if scars_after > 0 or zones_after > 0:
		_bad("DamageSystem cleared on world teardown",
			"%d scar decals / %d damage zones survive the full teardown (was %d/%d) - MissionScope.reset() ran and did not clear them." % [scars_after, zones_after, scars_before, zones_before])
	else:
		_ok("DamageSystem cleared on world teardown")

	# --- cover claims static ---
	var claims: int = EnemyBase._cover_claims.size()
	if claims > 0:
		_bad("EnemyBase._cover_claims cleared", "%d stale cover cells persist across missions" % claims)
	else:
		_ok("EnemyBase._cover_claims cleared", "(0 - no enemies spawned in this probe)")


func _local_offsets(nodes: Array, origin: Vector3) -> Array:
	var out: Array = []
	for n in nodes:
		var n3 := n as Node3D
		if n3 == null:
			continue
		var d: Vector3 = n3.global_position - origin
		out.append("%s@%.1f,%.1f" % [n3.name, d.x, d.z])
	out.sort()
	return out
