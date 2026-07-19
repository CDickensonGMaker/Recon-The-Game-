## test_playtest_bundle.gd - guards the 2026-07-19 playtest bundle.
## Run: godot --headless --path . res://tests/test_playtest_bundle.tscn
##
## Each block names the defect it locks down. The assertions are written to FAIL
## on the pre-fix code, not merely to pass on the post-fix code.
extends Node3D

var failures: int = 0


func _ready() -> void:
	_run()


func _fail(msg: String) -> void:
	print("FAIL: %s" % msg)
	failures += 1


func _run() -> void:
	_t_fire_menu_hides_empty()
	_t_lazy_group_carries_camp_life()
	_t_informer_needs_line_of_sight()
	_t_informer_handler_exists()
	await _t_trap_is_destructible()
	_t_nameplate_projects()
	_t_flinch_is_wired()
	# --fast skips the world harness so a negative control is seconds, not minutes.
	if not "--fast" in OS.get_cmdline_user_args():
		await _t_director_in_a_real_world()

	if failures == 0:
		print("PASS: playtest bundle (7 items) OK")
		get_tree().quit(0)
	else:
		print("FAIL: %d failures" % failures)
		get_tree().quit(1)


## ITEM 1 / r4bk. A row the player can never press is not information. Pre-fix the
## menu always rendered all six rows, dimmed.
func _t_fire_menu_hides_empty() -> void:
	var src: String = FileAccess.get_file_as_string("res://scripts/ui/mission_hud.gd")
	if not src.contains("if count <= 0:"):
		_fail("fire menu still renders rows with no stock")


## ITEM 3. Village/camp garrisons spawn from a LazyGroup long after
## _attach_camp_directors has run, so nothing gave them a schedule, stations or a
## route - and the authored spread was dropped so they huddled at the 12m default.
func _t_lazy_group_carries_camp_life() -> void:
	var lg := LazyGroup.new()
	if not ("work_stations" in lg) or not ("paddy_centroids" in lg):
		_fail("LazyGroup carries no camp-life payload - woken garrisons stay dumb")
	var cd_src: String = FileAccess.get_file_as_string("res://scripts/enemies/camp_director.gd")
	if not cd_src.contains("static func attach"):
		_fail("CampDirector.attach missing - the lazy path cannot stand one up")
	var src: String = FileAccess.get_file_as_string("res://scripts/missions/lazy_group.gd")
	if not src.contains("CampDirector.attach"):
		_fail("LazyGroup.force_spawn never attaches a CampDirector")
	var gen: String = FileAccess.get_file_as_string("res://scripts/missions/mission_generator.gd")
	if not gen.contains("lg.spread"):
		_fail("authored group spread still dropped - every lazy group huddles at 12m")
	lg.queue_free()


## ITEM 6 / ADR-005. The informer was the one perception system that never learned
## the witness rule: proximity alone started his clock.
func _t_informer_needs_line_of_sight() -> void:
	var src: String = FileAccess.get_file_as_string("res://scripts/world/civilian.gd")
	if not src.contains("has_line_of_sight"):
		_fail("informer clock still starts on proximity with no LOS test (ADR-005)")
	if src.contains("NoiseBus.NoiseType.GUNSHOT, _saw_player_at"):
		_fail("informer still fakes a 120m GUNSHOT - launders detection past ADR-005")


## ITEM 6 / truth law. The comment claimed a director handler read the flags.
## Nothing did. Either the handler exists or the claim must not.
func _t_informer_handler_exists() -> void:
	var d := FieldDirector.new()
	if not d.has_method("on_informer_escaped"):
		_fail("no on_informer_escaped handler - the informer alarm still goes nowhere")
	d.queue_free()


## ITEM 5. The trap was a plain Node3D: no body, no health, nothing to shoot. A
## body alone would still be unshootable - bullet_system resolves damage through
## Hitzones or group membership, and a trap is in neither.
func _t_trap_is_destructible() -> void:
	var trap := PunjiTrap.new()
	add_child(trap)
	# Everything below resolves at runtime so a reverted trap FAILS this probe
	# rather than refusing to parse it.
	if not trap.has_method("take_damage") or not trap.has_method("_build_hurtbox"):
		_fail("trap has no take_damage/hurtbox - it cannot join the damage grammar")
		trap.queue_free()
		return
	trap.call("_build_hurtbox")
	await get_tree().process_frame

	var zone: Hitzone = null
	for c in trap.get_children():
		if c is Hitzone:
			zone = c as Hitzone
	var want_layer: int = int(trap.get("TRAP_HURTBOX_LAYER"))
	if zone == null:
		_fail("trap has no Hitzone - rounds pass straight through it")
	elif zone.collision_layer != want_layer:
		_fail("trap hurtbox on layer %d, not the player-fire layer %d"
			% [zone.collision_layer, want_layer])
	# The layer must actually be inside the player's fire mask or none of it lands.
	if (want_layer & (1 | 32 | 64 | 512)) == 0:
		_fail("trap layer is outside the player's fire mask - unshootable")

	var max_hp: int = int(trap.get("MAX_HP"))
	trap.call("take_damage", int(max_hp / 3.0), Enums.DamageType.PHYSICAL, null, "BODY")
	if bool(trap.call("is_dead")):
		_fail("trap died to a third of its HP")
	trap.call("take_damage", max_hp, Enums.DamageType.PHYSICAL, null, "BODY")
	if not bool(trap.call("is_dead")):
		_fail("trap survived %d damage - still indestructible" % max_hp)
	if trap in AgentRegistry.props:
		_fail("destroyed trap still on the props roster - blast would keep finding it")


## ITEM 7. The plate was anchored once in _ready and never positioned again, so it
## sat in a corner regardless of where the man was. Assert it TRACKS - a probe that
## only checks the label text passes on the broken build.
func _t_nameplate_projects() -> void:
	var plate := SquadNameplate.new()
	add_child(plate)
	if not plate.has_method("_track"):
		_fail("nameplate has no per-frame projection - it is still statically anchored")
		plate.queue_free()
		return
	var src: String = FileAccess.get_file_as_string("res://scripts/ui/squad_nameplate.gd")
	if not src.contains("unproject_position"):
		_fail("nameplate never unprojects - it cannot sit above the man")
	if not src.contains("is_position_behind"):
		_fail("nameplate does not guard against points behind the eye")
	if src.contains("PRESET_CENTER"):
		_fail("nameplate still uses the anchor preset that pinned it to the corner")

	# The head anchor must sit above the man's feet by roughly his authored height
	# (ADR-002), and must be derived from the contract - not a HUD-local constant.
	var probe := Node3D.new()
	add_child(probe)
	probe.global_position = Vector3(10, 5, 10)
	# Resolved at runtime, never as a static reference: a missing symbol must fail
	# this probe, not refuse to parse it.
	if not plate.has_method("head_anchor"):
		_fail("no head_anchor - the plate has no above-the-man anchor")
	else:
		var anchor: Vector3 = plate.call("head_anchor", probe)
		var lift: float = anchor.y - probe.global_position.y
		if lift < 1.5 or lift > 2.4:
			_fail("head anchor lifts %.2fm - not a man's crown" % lift)
		if not is_equal_approx(anchor.x, probe.global_position.x):
			_fail("head anchor drifts off the man in X")
	probe.queue_free()
	plate.queue_free()


## ITEM 4. A survived hit stalled the trigger and changed nothing on the body -
## the comment said "Flinch" and no pose moved. This asserts the MACHINE: the
## modifier decays, the concurrency cap exists, and the damage path calls it.
## Whether the punch READS as a flinch is an eyes verdict and is NOT claimed here.
func _t_flinch_is_wired() -> void:
	var eb: String = FileAccess.get_file_as_string("res://scripts/enemies/enemy_base.gd")
	if not eb.contains("\"flinch\""):
		_fail("damage path never calls flinch - a survived hit still moves nothing")
	var ma: String = FileAccess.get_file_as_string("res://scripts/visuals/model_actor.gd")
	if not ma.contains("MAX_CONCURRENT_FLINCH"):
		_fail("no flinch concurrency cap - theater with no budget")
	if not ma.contains("perceivable"):
		_fail("flinch not gated on perceivability - it pays for men nobody can see")

	var fm := FlinchModifier.new()
	if not fm.has_method("punch"):
		_fail("FlinchModifier has no punch")
		fm.free()
		return
	if not fm.is_spent():
		_fail("a fresh flinch is already punching")
	fm.punch(Vector3.FORWARD, 1.0)
	if fm.is_spent():
		_fail("flinch spent immediately - it would never be seen")
	fm.free()


## ITEM 1, behavioural. FieldDirector.world is typed GameWorld, so the budget and
## danger-close checks are only honest against a real one.
func _t_director_in_a_real_world() -> void:
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
		_fail("world timeout - could not verify the director")
		return

	var d := FieldDirector.new()
	world.add_child(d)
	d.setup(world)
	var squad := SquadSystem.new()
	world.add_child(squad)
	squad.setup(world, d, world.player.global_position + Vector3(4, 0, 0))
	d.squad_system = squad
	await get_tree().create_timer(0.8).timeout

	# The defect the owner hit: five of six verbs permanently reading NONE AVAILABLE.
	# Guarded, not called blind - a missing grant must FAIL here, not abort the
	# coroutine and skip every assertion below it.
	if not d.has_method("_grant_fire_support"):
		_fail("no _grant_fire_support - the budget is still never granted")
	else:
		d.call("_grant_fire_support")
		var stocked: int = 0
		for k in d.fire_support.keys():
			if int(d.fire_support[k]) > 0:
				stocked += 1
		if stocked < 3:
			_fail("only %d verbs on call after a grant - the net still reads empty" % stocked)
		if int(d.fire_support.get("mortar", 0)) < 3:
			_fail("mortar stock %d, expected >=3" % int(d.fire_support.get("mortar", 0)))

	# ADR-011 required amendment: the confirm must see the PLAYER himself. The squad
	# is held out of the check here on purpose - with squadmates 4m away the squad
	# loop answers true regardless and the assertion would prove nothing.
	var kept_squad: SquadSystem = d.squad_system
	d.squad_system = null
	var on_his_head: Vector3 = world.player.global_position + Vector3(5, 0, 0)
	if not d._danger_close_to_squad(on_his_head):
		_fail("danger-close ignores the player: 5m from his own feet needs no confirm")
	if d._danger_close_to_squad(world.player.global_position + Vector3(900, 0, 900)):
		_fail("danger-close fires 900m away - the check is not distance-bound")
	d.squad_system = kept_squad

	# And the whole chain still dispatches.
	var before: int = int(d.fire_support.get("mortar", 0))
	d.request_fire_support("mortar")
	await get_tree().create_timer(0.2).timeout
	if d._pending_danger_close == "mortar":
		d.request_fire_support("mortar")
		await get_tree().create_timer(0.2).timeout
	if int(d.fire_support.get("mortar", 0)) >= before:
		_fail("mortar mission never dispatched - the fire-support chain is broken")
