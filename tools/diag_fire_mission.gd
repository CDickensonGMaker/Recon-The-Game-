## diag_fire_mission.gd - end-to-end truth probe for the RTO fire-support chain (ADR-011).
## Reports the state of every link; asserts nothing. Diagnostic, not a guard.
## Run: godot --headless --path . res://tools/diag_fire_mission.tscn
extends Node


func _ready() -> void:
	_run()


func _run() -> void:
	CampaignState.reset_campaign()

	var world_scene: PackedScene = load("res://scenes/levels/game_world.tscn")
	var world: GameWorld = world_scene.instantiate()
	world.mission_seed = 616
	add_child(world)
	var elapsed: float = 0.0
	while not world.is_world_ready and elapsed < 180.0:
		await get_tree().create_timer(0.5).timeout
		elapsed += 0.5
	if not world.is_world_ready:
		print("DIAG: world timeout")
		get_tree().quit(1)
		return

	var director := FieldDirector.new()
	world.add_child(director)
	director.setup(world)
	var toasts: Array[String] = []
	director.toast.connect(func(t: String) -> void:
		toasts.append(t)
		print("  [TOAST] %s" % t))

	var squad := SquadSystem.new()
	world.add_child(squad)
	squad.setup(world, director, world.player.global_position + Vector3(4, 0, 0))
	director.squad_system = squad
	await get_tree().create_timer(1.0).timeout

	print("=== LINK 1: does the squad carry a living RTO? ===")
	var rto: AllyBase = squad.member_by_mos("RTO")
	print("  member_by_mos('RTO') = %s" % ("null" if rto == null else str(rto.member.get("name", "?"))))
	if rto != null:
		var d: float = world.player.global_position.distance_to(rto.global_position)
		print("  RTO distance from player = %.2fm (leash is %.1fm)" % [d, FieldDirector.RTO_RADIO_RANGE])
		print("  RTO fo_fac skill level = %d" % SquadRoster.skill_level(rto.member, "fo_fac"))

	print("=== LINK 2: does the radio leash pass? ===")
	var err: String = director._radio_check()
	print("  _radio_check() = '%s'" % err)

	print("=== LINK 3: what budget does the player actually have? ===")
	print("  director.fire_support = %s" % [director.fire_support])
	var available: Array[String] = []
	for k in director.fire_support.keys():
		if int(director.fire_support[k]) > 0:
			available.append(str(k))
	print("  verbs with stock: %s" % [available])
	print("  verbs that will answer NONE AVAILABLE: %d of %d"
		% [director.fire_support.size() - available.size(), director.fire_support.size()])

	print("=== LINK 4: does the aim ray find ground? ===")
	var tgt: Vector3 = director._cas_ground_target()
	print("  _cas_ground_target() = %s%s" % [tgt, "  <-- ZERO means NO TARGET" if tgt == Vector3.ZERO else ""])

	print("=== LINK 5: dispatch a mortar mission for real ===")
	var before: int = int(director.fire_support.get("mortar", 0))
	toasts.clear()
	director.request_fire_support("mortar")
	await get_tree().create_timer(0.2).timeout
	# Danger-close raises a pend on the first press; a second press confirms it.
	if director._pending_danger_close == "mortar":
		print("  (danger-close pend raised - pressing again to confirm)")
		director.request_fire_support("mortar")
		await get_tree().create_timer(0.2).timeout
	var after: int = int(director.fire_support.get("mortar", 0))
	print("  mortar budget %d -> %d (%s)" % [before, after,
		"DISPATCHED" if after < before else "NOT DISPATCHED"])
	print("  toasts: %s" % [toasts])

	print("=== LINK 6: did rounds actually land? ===")
	await get_tree().create_timer(14.0).timeout
	print("  (see impact toasts above; mortar mission runs on a delay)")

	get_tree().quit(0)
