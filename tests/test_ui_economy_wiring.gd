## test_ui_economy_wiring.gd - UI/economy wiring probe (2026-07-25 decree).
##   1. Grenade cook -> HUD fuse ring (grenade_cooking + get_cook_progress), and the
##      ring clears the frame cooking stops (throw and in-hand burst share the path).
##   2. downed_started -> HUD downed clock + downed_ended clears it.
##   3. SECURE interaction: prompt names it, [F] calls secure(), intel banks ONCE.
##   4. Debrief AAR names noncombatant deaths when > 0, stays silent at 0.
## Run: godot --headless --path . res://tests/test_ui_economy_wiring.tscn
extends Node3D

var failures: int = 0


class ReviveStub extends Node:
	func can_revive() -> bool:
		return true

	func begin_revive(_hs: HealthSystem) -> void:
		pass


func _ready() -> void:
	print("=== UI/ECONOMY WIRING ===")
	await get_tree().process_frame
	await _test_cook_ring()
	await _test_downed_tell()
	await _test_secure_interaction()
	await _test_debrief_civilian_line()
	if failures == 0:
		print("PASS: cook ring / downed tell / SECURE / AAR civilian line all wired")
	else:
		print("=== %d FAILURE(S) ===" % failures)
	get_tree().quit(1 if failures > 0 else 0)


func _fail(msg: String) -> void:
	printerr("FAIL: " + msg)
	failures += 1


func _test_cook_ring() -> void:
	var hud: HUD = (load("res://scenes/ui/hud.tscn") as PackedScene).instantiate() as HUD
	add_child(hud)
	var gh := GrenadeHandler.new()
	add_child(gh)
	await get_tree().process_frame
	# The same wiring setup() makes, without dragging the full player kit in.
	hud.grenade_handler = gh
	gh.grenade_cooking.connect(hud._on_grenade_cooking)

	gh.is_cooking = true
	gh.cook_timer = 0.0
	gh._process(1.0)  # one cook frame: emits grenade_cooking(1.0)
	var ap: ActionProgress = hud.action_progress
	if ap == null or not ap.is_active:
		_fail("cook frame did not raise the HUD ring")
	elif ap.current_action != ActionProgress.ActionType.COOK:
		_fail("ring raised with action %d (want COOK)" % ap.current_action)
	elif absf(ap.progress - 0.25) > 0.01:
		_fail("ring progress %.2f after 1s of a 4s fuse (want 0.25)" % ap.progress)
	else:
		print("  cook -> fuse ring OK (COOK, 25%% at 1s)")

	gh.is_cooking = false  # the throw (or the in-hand burst) - same clear path
	await get_tree().process_frame
	if ap != null and ap.is_active and ap.current_action == ActionProgress.ActionType.COOK:
		_fail("ring survived the end of the cook")
	else:
		print("  cook end -> ring cleared OK")
	hud.queue_free()
	gh.queue_free()


func _test_downed_tell() -> void:
	var hud: HUD = (load("res://scenes/ui/hud.tscn") as PackedScene).instantiate() as HUD
	add_child(hud)
	var hs := HealthSystem.new()
	add_child(hs)
	var stub := ReviveStub.new()
	add_child(stub)
	await get_tree().process_frame
	hud.health_system = hs
	hs.downed_started.connect(hud._on_downed_started)
	hs.downed_ended.connect(hud._on_downed_ended)
	hs.revive_handler = stub

	hs.take_damage(999)
	if not hs.is_downed:
		_fail("stub revive handler did not intercept death (no downed state to test)")
	elif not hud.bleed_container.visible:
		_fail("downed_started did not show the death-clock container")
	elif not str(hud.bleed_label.text).begins_with("YOU ARE DOWN"):
		_fail("downed label reads '%s' (want the YOU ARE DOWN clock)" % hud.bleed_label.text)
	else:
		print("  downed_started -> '%s' OK" % hud.bleed_label.text)

	hs.revive()
	if hud.bleed_container.visible:
		_fail("downed_ended did not clear the downed clock")
	else:
		print("  downed_ended -> cleared OK")
	hud.queue_free()
	hs.queue_free()
	stub.queue_free()


func _test_secure_interaction() -> void:
	# player.gd carries no class_name: keep the var Variant so the duck calls below
	# stay legal under strict typing (test_radio_handset does the same dance).
	var player: Variant = (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	add_child(player)
	var dir := DirAccess.open("res://data/enemies")
	var data_path: String = ""
	for f in dir.get_files():
		if f.ends_with(".tres"):
			data_path = "res://data/enemies/" + f
			break
	var e: EnemyBase = EnemyBase.spawn_enemy(self, Vector3(1.5, 0, 0), data_path)
	await get_tree().physics_frame
	await get_tree().physics_frame

	e._become_downed()
	var prompt: String = player.field_interact_prompt()
	if prompt != "[F] SECURE THE PRISONER":
		_fail("prompt over a downed man reads '%s'" % prompt)
	else:
		print("  prompt OK: %s" % prompt)

	var intel0: int = CampaignState.intel_points
	player._try_field_interact()
	if not e.is_in_group("captured"):
		_fail("[F] did not secure the downed man (not in captured group)")
	elif e._downed_bleed_s < 1000.0:
		_fail("secure did not pin the bleed clock (%.1fs)" % e._downed_bleed_s)
	elif CampaignState.intel_points != intel0 + 1:
		_fail("secure banked %d intel (want exactly +1)" % (CampaignState.intel_points - intel0))
	else:
		print("  [F] -> secure() OK (captured, stabilized, +1 intel)")

	# A secured man must not be bankable twice (he stays in the surrendered group).
	player._try_field_interact()
	if CampaignState.intel_points != intel0 + 1:
		_fail("second [F] double-banked the same prisoner (intel +%d)" % (CampaignState.intel_points - intel0))
	else:
		print("  repeat [F] -> no double-dip OK")
	CampaignState.intel_points = intel0
	(player as Node).queue_free()
	e.queue_free()


func _test_debrief_civilian_line() -> void:
	var with_deaths := DebriefScreen.new()
	with_deaths.set_result({"success": false, "reason": "KIA", "mission_type": "PATROL",
		"seed": 1, "civilian_deaths": 2})
	add_child(with_deaths)
	await get_tree().process_frame
	if not _any_label_contains(with_deaths, "NONCOMBATANTS KILLED: 2"):
		_fail("AAR shows no NONCOMBATANTS KILLED line for civilian_deaths=2")
	else:
		print("  AAR names 2 noncombatant deaths OK")
	with_deaths.queue_free()

	var clean := DebriefScreen.new()
	clean.set_result({"success": true, "mission_type": "PATROL", "seed": 1})
	add_child(clean)
	await get_tree().process_frame
	if _any_label_contains(clean, "NONCOMBATANTS"):
		_fail("AAR shows a noncombatant line on a clean patrol")
	else:
		print("  clean AAR stays silent OK")
	clean.queue_free()


func _any_label_contains(root: Node, needle: String) -> bool:
	if root is Label and str((root as Label).text).contains(needle):
		return true
	for c in root.get_children():
		if _any_label_contains(c, needle):
			return true
	return false
