## field_director.gd - Owns MissionState, tracked enemy spawning (kills are
## counted from EnemyBase.died), objective completion and mission end states.
class_name FieldDirector
extends Node

signal mission_failed(result: Dictionary)
signal toast(text: String)

var state := MissionState.new()
var world: GameWorld
var _ended: bool = false
var _live_enemies: Array[EnemyBase] = []


var _detect_baseline_ms: float = 0.0

func setup(game_world: GameWorld) -> void:
	add_to_group("mission_director")   # enemies report contact through this
	# Ignore any COMBAT contact from a previous mission (the beacon is static).
	_detect_baseline_ms = float(Time.get_ticks_msec())
	EnemyBase.last_combat_contact_ms = -1.0
	EnemyBase.unreported_corpses.clear()   # bodies do not haunt the next mission
	world = game_world
	state.start_time_ms = Time.get_ticks_msec()
	if not GameManager.player_died.is_connected(_on_player_died):
		GameManager.player_died.connect(_on_player_died)


## Spawn an enemy seated on terrain and wire its death into mission counters.
func spawn_tracked_enemy(pos: Vector3, data_path: String, group_tag: String = "") -> EnemyBase:
	var seated := pos
	if world and world.terrain_manager:
		seated.y = world.terrain_manager.get_height_at(pos) + 0.5
	var parent: Node = world if world != null else get_parent()
	var enemy: EnemyBase = EnemyBase.spawn_enemy(parent, seated, data_path)
	# Same group_tag -> same fireteam. hash gives a stable per-group id; lone
	# spawns (empty tag) stay -1 (no coordination).
	enemy.squad_id = hash(group_tag) if not group_tag.is_empty() else -1
	enemy.died.connect(_on_enemy_died.bind(group_tag))
	_live_enemies.append(enemy)
	# CONTACT LEDGER (ADR-006): a group must be registered the moment it spawns,
	# or there is nothing for the debrief to score as avoided.
	state.register_group(enemy.squad_id if enemy.squad_id >= 0 else enemy.get_instance_id())
	return enemy


## An enemy went loud on the player - his whole group is spent (see MissionState).
func report_contact(group_id: int) -> void:
	if _ended:
		return
	state.report_detected(group_id)


## A noncombatant Civilian died. Routed here (the patrol ledger owner) so the count
## rides the per-patrol MissionState; surfacing and any scoring stay the Summoner's
## call (ADR-006 re-host), so nothing consumes this today.
func record_noncombatant_death() -> void:
	if state != null:
		state.record_civilian_death()


func _on_enemy_died(enemy: EnemyBase, _group_tag: String) -> void:
	state.record_kill()
	_live_enemies.erase(enemy)
	# Escalation is driven by DETECTION, not by the kill - see _check_detection().
	# A silent, unwitnessed kill leaves the AO cold; that is what makes stealth
	# an economy.


## Hunter escalation: after first contact, patrols move in looking for you.
## Finite pool - you can bleed the AO dry.
var _escalation_active: bool = false
var _hunter_timer: float = 0.0
var _hunter_pool: int = 12


## Raise the alarm the first time the player is DETECTED (any enemy in COMBAT).
func _check_detection() -> void:
	if _escalation_active:
		return
	if EnemyBase.last_combat_contact_ms > _detect_baseline_ms:
		_escalation_active = true
		_hunter_timer = randf_range(70.0, 110.0)
		toast.emit("YOU'VE BEEN MADE - THEY'RE MOVING TO CONTACT")


func _process_escalation(delta: float) -> void:
	_check_detection()
	if not _escalation_active or _hunter_pool <= 0 or _ended or world == null or world.player == null:
		return
	_hunter_timer -= delta
	if _hunter_timer > 0.0:
		return
	# The longer you are in the field, the harder the AO leans on you.
	var field_mult: float = 1.0
	if state != null:
		var mins: float = state.elapsed_seconds() / 60.0
		field_mult = clampf(1.0 - (mins - 15.0) * 0.02, 0.6, 1.0)  # -2%/min past 15min, floor 0.6
	_hunter_timer = randf_range(100.0, 160.0) * field_mult
	var count: int = mini(_hunter_pool, randi_range(2, 4))
	_hunter_pool -= count
	var a: float = randf_range(0.0, TAU)
	var base: Vector3 = world.player.global_position + Vector3(cos(a), 0, sin(a)) * randf_range(180.0, 230.0)
	base.x = clampf(base.x, 60.0, world.map_size - 60.0)
	base.z = clampf(base.z, 60.0, world.map_size - 60.0)
	for i in range(count):
		var pos := base + Vector3(randf_range(-6, 6), 0, randf_range(-6, 6))
		var hunter := spawn_tracked_enemy(pos, "res://data/enemies/nva_regular.tres", "hunters")
		hunter.add_to_group("hunters")
		# They come looking: seed their search at your last position.
		hunter.last_known_target_pos = world.player.global_position
		hunter.target_last_seen_time = 0.0
		hunter._set_tier(EnemyBase.AlertTier.ALERT)
	toast.emit("MOVEMENT IN THE TREES - THEY'RE LOOKING FOR YOU")


func live_enemy_count(group_tag: String = "") -> int:
	if group_tag.is_empty():
		return _live_enemies.size()
	var count: int = 0
	for e in _live_enemies:
		if is_instance_valid(e) and e.is_in_group(group_tag):
			count += 1
	return count


func fail_mission(reason: String) -> void:
	if _ended:
		return
	_ended = true
	mission_failed.emit(state.build_result(false, reason))


func _on_player_died() -> void:
	fail_mission("KIA")


## CAS: press T while aiming at ground -> Skyraider run (budget-limited).
const SKYRAIDER_SCENE := preload("res://scenes/vehicles/skyraider.tscn")  # A-1, dive-bomb
const F4_SCENE := preload("res://scenes/vehicles/f4_phantom.tscn")  # F-4, fast horizontal flyby

var cas_budget: int = 0
var _cas_cooldown: float = 0.0


func _process(delta: float) -> void:
	if _ended:
		return
	_cas_cooldown = maxf(0.0, _cas_cooldown - delta)
	_process_escalation(delta)
	_gate_poll += delta
	if _gate_poll >= 0.5:
		_gate_poll = 0.0
		_poll_wire_gate()
		_poll_firebase_threat()
		_maybe_launch_sappers()
		_advance_route_tasking()
		if patrol_out and world != null and world.player != null:
			state.mark_covered(world.player.global_position)
	# Fire-support menu (T opens, 1-5 selects while open, Y = mortar shortcut).
	if Input.is_action_just_pressed("cas_strike") and GameManager.can_player_act():
		_pending_danger_close = ""  # opening/closing the net always clears a stale confirm
		if not fire_menu_open:
			# The radio rides the RTO's back: you must be near a LIVING one. The same
			# check gates the shortcuts inside request_fire_support - nothing bypasses it.
			var err := _radio_check()
			if err != "":
				toast.emit(err)
			else:
				_open_net()
		else:
			_close_net()
	if fire_menu_open and GameManager.can_player_act():
		if Input.is_action_just_pressed("slot_1"):
			arm_fire_mission("bombs")
		elif Input.is_action_just_pressed("slot_2"):
			arm_fire_mission("napalm")
		elif Input.is_action_just_pressed("slot_3"):
			arm_fire_mission("arty")
		elif Input.is_action_just_pressed("slot_4"):
			arm_fire_mission("mortar")
		elif Input.is_action_just_pressed("wheel_up") or Input.is_action_just_pressed("wheel_down"):
			pass  # keep wheel for kit even with menu open
		elif Input.is_action_just_pressed("pop_flare"):
			pass
		elif Input.is_action_just_pressed("throw_smoke"):
			arm_fire_mission("spectre")  # 5 = Spectre while menu is open
		elif Input.is_action_just_pressed("cbu_strike"):
			arm_fire_mission("cbu")  # 6 = CBU cluster run
		# The rifle is slung on the net (weapon_holder.gd), so fire/aim are free to
		# mean send/withdraw for as long as a call is armed.
		if armed_kind != "":
			_update_placement()
			if Input.is_action_just_pressed("fire"):
				commit_fire_mission()
			elif Input.is_action_just_pressed("aim"):
				cancel_fire_mission()
	if Input.is_action_just_pressed("mortar_strike") and GameManager.can_player_act():
		arm_fire_mission("mortar")
	if Input.is_action_just_pressed("supply_drop") and GameManager.can_player_act():
		request_supply_drop()
	# PROACTIVE NET KICK (Stage-1 handoff): if the RTO is killed while the player is on
	# the net, drop him off it THIS frame - he should learn the radio is dead now, not
	# on his next press. Routes through _close_net (the mirror-safe seam), and closing
	# the net makes fire_menu_open false, so this self-limits to one shot.
	if fire_menu_open:
		var rto_live: AllyBase = squad_system.member_by_mos("RTO") \
			if (squad_system != null and is_instance_valid(squad_system)) else null
		if rto_live == null or rto_live.is_dead():
			_close_net()
			toast.emit("THE RADIO'S DEAD - YOU'VE LOST THE NET")


## Unified call-for-fire: budgets per mission, all RTO-gated.
signal fire_menu_changed(open: bool)
static var any_fire_menu_open: bool = false  ## input guard for kit keys
var fire_menu_open: bool = false:
	set(value):
		fire_menu_open = value
		any_fire_menu_open = value


## THE NET IS ONE STATE. The player owns the truth (player.holding_handset); this
## menu is its mirror. The [T] key and dispatch/hang-up drive the player, and the
## player calls set_fire_menu_mirror back to move THIS flag. That funnel is what
## keeps "handset in hand" and "fire options visible" from ever disagreeing.
func _open_net() -> void:
	var pl: Node = world.player if world != null else null
	if pl != null and pl.has_method("set_on_net"):
		pl.set_on_net(true)  # raises the handset (if wired) -> mirrors this menu open
	else:
		set_fire_menu_mirror(true)  # no player (probe harness): open directly
	# Only crow "on the horn" if the net actually opened - the player can refuse the
	# grab (cord out of reach) and give its own "too far" bark.
	if fire_menu_open:
		toast.emit("ON THE HORN - SEND YOUR FIRE MISSION")
		_radio_vo("on_the_horn")


## Terminal mirror, called ONLY from the player's _enter_net/_exit_net. Sets the flag
## and emits - it must never call back into the player, or the two states ping-pong.
func set_fire_menu_mirror(open: bool) -> void:
	if fire_menu_open == open:
		return
	fire_menu_open = open
	if not open:
		clear_armed()
	fire_menu_changed.emit(open)
var fire_support: Dictionary = {"bombs": 0, "napalm": 0, "arty": 0, "mortar": 2, "spectre": 0, "cbu": 0}

## Off-map gun geometry: how long a round is in the air, and where it comes from.
const SHELL_FLIGHT_S: float = 4.0
const SHELL_APEX_M: float = 260.0
const SHELL_STANDOFF_M: float = 300.0

const MORTAR_SHELL: String = "res://data/projectiles/mortar_81mm.tres"
const ARTY_SHELL: String = "res://data/projectiles/arty_105mm.tres"

const DANGER_CLOSE_M: float = 45.0
const RTO_RADIO_RANGE: float = 10.0  ## must be this close to the living RTO to use the radio
const DANGER_CLOSE_CONFIRM_S: float = 5.0  ## confirm window; a stale pend must never pre-confirm
var _pending_danger_close: String = ""  ## the call awaiting a danger-close confirm press
var _pending_dc_at_ms: int = 0  ## when the pend was raised (Time.get_ticks_msec)
## How many men an escaped informer brings back, and what they are.
const INFORMER_RESPONSE: int = 4
const INFORMER_RESPONSE_DATA: String = "res://data/enemies/vc_rifleman.tres"
var _informer_answered: bool = false


## THE ARMED CALL. Picking a mission does not send it: it puts a footprint on the
## ground that the player walks onto the target and then commits. Arming spends
## nothing, so backing out costs him nothing either.
var armed_kind: String = ""
var armed_target: Vector3 = Vector3.ZERO
var armed_dir: Vector3 = Vector3.FORWARD
var _preview: FirePreview = null


func arm_fire_mission(kind: String) -> void:
	# Every gate the dispatch runs, in the same order, so a call that cannot go out
	# is refused BEFORE he spends time aiming it.
	var err := _radio_check()
	if err != "":
		_close_net()
		toast.emit(err)
		return
	if int(fire_support.get(kind, 0)) <= 0:
		toast.emit("%s: NONE AVAILABLE" % kind.to_upper())
		return
	if _cas_cooldown > 0.0:
		toast.emit("NET BUSY - STAND BY")
		return
	# You place a call ON the horn. The [Y] shortcut skips the menu, never the radio.
	if not fire_menu_open:
		_open_net()
		if not fire_menu_open:
			return
	armed_kind = kind
	_pending_danger_close = ""   # a fresh placement is not a confirm of the last one
	_update_placement()
	toast.emit("%s - PLACE IT, LMB TO SEND, RMB TO BACK OUT" % kind.to_upper())


func commit_fire_mission() -> void:
	if armed_kind == "":
		return
	if armed_target == Vector3.ZERO:
		toast.emit("NO TARGET - AIM AT THE GROUND")
		return
	request_fire_support(armed_kind, armed_target, armed_dir)


func cancel_fire_mission() -> void:
	if armed_kind == "":
		return
	toast.emit("%s - CALL WITHDRAWN" % armed_kind.to_upper())
	clear_armed()


## Nothing armed may outlive the net. A stale arm surviving a hang-up would let a
## later LMB send a call from a radio he is no longer holding.
func clear_armed() -> void:
	armed_kind = ""
	armed_target = Vector3.ZERO
	_pending_danger_close = ""
	if _preview != null and is_instance_valid(_preview):
		_preview.clear_plan()


func fo_skill() -> int:
	var rto: AllyBase = squad_system.member_by_mos("RTO") \
		if (squad_system != null and is_instance_valid(squad_system)) else null
	return SquadRoster.skill_level(rto.member, "fo_fac") if rto != null else 0


## Is any man of ours inside the footprint, not merely near its centre? A napalm
## strip reaches 40m down the run - measuring to the mark alone would clear a call
## that burns the point man.
func armed_danger_close() -> bool:
	if armed_kind == "" or armed_target == Vector3.ZERO:
		return false
	return _danger_close_to_squad(armed_target, FirePlan.reach(armed_kind, fo_skill()))


func _update_placement() -> void:
	if armed_kind == "":
		return
	armed_target = _cas_ground_target()
	armed_dir = _broadside_axis()
	if _preview == null or not is_instance_valid(_preview):
		if world == null or not is_instance_valid(world):
			return
		_preview = FirePreview.new()
		_preview.name = "FirePreview"
		_preview.terrain = world.terrain_manager
		world.add_child(_preview)
	if armed_target == Vector3.ZERO:
		_preview.clear_plan()
		return
	_preview.show_plan(armed_kind, armed_target, armed_dir, fo_skill(), armed_danger_close())


## The aircraft crosses his front rather than flying up his line of sight: in over
## the right shoulder, out to the left. Screen-horizontal, so the strip's length is
## the thing he is actually judging.
func _broadside_axis() -> Vector3:
	if world == null or world.player == null or not is_instance_valid(world.player):
		return Vector3.FORWARD
	var cam: Camera3D = world.player.get_node_or_null("Head/Camera3D")
	if cam == null:
		return Vector3.FORWARD
	var right: Vector3 = cam.global_transform.basis.x
	right.y = 0.0
	if right.length() < 0.01:
		return Vector3.FORWARD
	return -right.normalized()


## `at`/`run` come from a placed preview. Left at ZERO the call still aims itself
## down the crosshair, which is what the probe harnesses and the shortcuts rely on.
func request_fire_support(kind: String, at: Vector3 = Vector3.ZERO, run: Vector3 = Vector3.ZERO) -> void:
	# The net stays open through soft failures and through the danger-close confirm.
	# It closes only on dispatch - closing earlier makes the confirm press unreachable.
	var err := _radio_check()  # RTO alive + within 10m - also gates the Y/O shortcuts
	if err != "":
		_close_net()
		toast.emit(err)
		return
	if int(fire_support.get(kind, 0)) <= 0:
		toast.emit("%s: NONE AVAILABLE" % kind.to_upper())
		return
	if _cas_cooldown > 0.0:
		toast.emit("NET BUSY - STAND BY")
		return
	var target := at if at != Vector3.ZERO else _cas_ground_target()
	if target == Vector3.ZERO:
		toast.emit("NO TARGET - AIM AT THE GROUND")
		return
	var run_dir: Vector3 = run
	# Danger close: a second press of the SAME call, within a short window, is
	# required. A stale or different-kind pend must never pre-confirm.
	var pend_fresh: bool = _pending_danger_close == kind \
		and (Time.get_ticks_msec() - _pending_dc_at_ms) < int(DANGER_CLOSE_CONFIRM_S * 1000.0)
	if _danger_close_to_squad(target) and not pend_fresh:
		_pending_danger_close = kind
		_pending_dc_at_ms = Time.get_ticks_msec()
		toast.emit("DANGER CLOSE - MEN NEAR THE TARGET - PRESS %s AGAIN TO CONFIRM" % kind.to_upper())
		_radio_vo("danger_close")
		return
	_pending_danger_close = ""
	clear_armed()
	_close_net()  # call is going out - off the horn
	fire_support[kind] = int(fire_support[kind]) - 1
	# FO/FAC is the RADIOMAN's skill, not the player's.
	var _rto := squad_system.member_by_mos("RTO") if squad_system != null else null
	var _fo: int = SquadRoster.skill_level(_rto.member, "fo_fac") if _rto != null else 0
	_cas_cooldown = maxf(10.0, 25.0 - 2.0 * float(_fo))
	match kind:
		"bombs":
			_launch_cas(target, CASAirplane.Ordnance.BOMB, run_dir)
			toast.emit("FAST MOVER INBOUND - SNAKE EYE (%d left)" % fire_support[kind])
			_radio_vo("snake_eye")
		"napalm":
			_launch_flyby(target, CASAirplane.Ordnance.NAPALM, run_dir)
			toast.emit("FAST MOVER - NAPALM RUN INBOUND - GET BACK (%d left)" % fire_support[kind])
			_radio_vo("napalm_run")
		"arty":
			toast.emit("BATTERY FIRE MISSION - SHOT OUT (%d left)" % fire_support[kind])
			_radio_vo("arty_barrage")
			# fo_fac tightens the sheaf: a green radioman scatters wide, a veteran walks
			# it onto the target (lerp 1.0 -> 0.45 across 8 skill levels).
			var scat: float = FirePlan.sheaf_scale(_fo)
			for i in range(6):
				var round_pos: Vector3 = target + Vector3(
					randf_range(-FirePlan.ARTY_SHEAF_M, FirePlan.ARTY_SHEAF_M) * scat, 0.0,
					randf_range(-FirePlan.ARTY_SHEAF_M, FirePlan.ARTY_SHEAF_M) * scat)
				var deform: bool = i % 3 == 0
				get_tree().create_timer(float(i) * 0.7).timeout.connect(
					func() -> void: _fire_shell(ARTY_SHELL, round_pos, _arty_impact.bind(deform)))
		"mortar":
			_run_mortar_mission(target, _fo)
		"spectre":
			SpectreGunship.call_in(world, world.terrain_manager, target)
			toast.emit("SPECTRE ON STATION - 30 SECONDS OF RAIN (%d left)" % fire_support[kind])
			_radio_vo("spooky")  # the recorded line is radio_spooky.wav - asset name, not the aircraft
		"cbu":
			_launch_flyby(target, CASAirplane.Ordnance.CBU, run_dir)
			toast.emit("FAST MOVER - CLUSTER RUN INBOUND - DANGER CLOSE (%d left)" % fire_support[kind])
			_radio_vo("cbu_cluster")
	# Learn-by-doing: the radioman gets better at calling fire the more he does it.
	if _rto != null:
		var fp: int = SquadRoster.credit_use(_rto.member, "fo_fac", 2)
		if fp > 0 and _rto.has_method("on_skill_up"):
			_rto.on_skill_up("fo_fac", fp)


func _launch_cas(target: Vector3, ordnance: CASAirplane.Ordnance, run: Vector3 = Vector3.ZERO) -> void:
	var plane: CASAirplane = SKYRAIDER_SCENE.instantiate()
	world.add_child(plane)
	plane.call_strike(world.terrain_manager, target, ordnance, _run_axis(target, run))


## F-4 fast horizontal flyby (napalm/CBU): in low, pickle on the pass, climb out.
func _launch_flyby(target: Vector3, ordnance: CASAirplane.Ordnance, run: Vector3 = Vector3.ZERO) -> void:
	var plane: CASAirplane = F4_SCENE.instantiate()
	world.add_child(plane)
	plane.call_flyby(world.terrain_manager, target, ordnance, _run_axis(target, run))


## The line the aircraft flies. A placed call hands one down - it comes in over the
## player's right shoulder and runs left, so the strip lies BROADSIDE across his
## view and he can read its length at a glance. Without a placement (a probe, a
## shortcut) it falls back to the old run down the line of sight.
func _run_axis(target: Vector3, run: Vector3) -> Vector3:
	if run.length() > 0.01:
		return run
	if world != null and world.player != null and is_instance_valid(world.player):
		return target - world.player.global_position
	return Vector3.ZERO


## An informer reached his people. They come looking from the far side, ALERT but
## not in contact - they know roughly where you were, not where you are. Normal
## perception decides whether they find you, so the beacon is still earned (ADR-005).
func on_informer_escaped(from_pos: Vector3, last_seen: Vector3) -> void:
	if _informer_answered:
		return
	_informer_answered = true
	state.flags["informer_transformed"] = true
	state.flags["informer_last_pos"] = from_pos
	var away: Vector3 = (from_pos - last_seen)
	away.y = 0.0
	if away.length() < 1.0:
		away = Vector3(1, 0, 0)
	away = away.normalized()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(from_pos) ^ int(Time.get_ticks_msec())
	for i in range(INFORMER_RESPONSE):
		var arc: float = deg_to_rad(rng.randf_range(-50.0, 50.0))
		var dir: Vector3 = away.rotated(Vector3.UP, arc)
		var pos: Vector3 = last_seen + dir * rng.randf_range(90.0, 140.0)
		if world != null and world.terrain_manager != null:
			pos.y = world.terrain_manager.get_height_at(pos)
		var e := spawn_tracked_enemy(pos, INFORMER_RESPONSE_DATA, "informer_response")
		if e != null and is_instance_valid(e):
			# witnessed=false: the word reached them, but nobody has EYES on the
			# player. They sweep his last reported spot and earn contact or don't.
			e._set_tier(EnemyBase.AlertTier.ALERT, false)
			e.last_known_target_pos = last_seen


## The radio is a man: a LIVING RTO within RTO_RADIO_RANGE. Returns "" when usable,
## else the toast to show. MUST be called by every fire request, not just the net
## toggle, or the shortcut keys bypass the leash.
func _radio_check() -> String:
	var rto: AllyBase = squad_system.member_by_mos("RTO") if (squad_system != null and is_instance_valid(squad_system)) else null
	if rto == null:
		return "NO RADIO - RTO IS DOWN"
	var pl: Node3D = world.player if world != null else null
	if pl != null and pl.global_position.distance_to(rto.global_position) > RTO_RADIO_RANGE:
		return "TOO FAR FROM THE RADIO - GET TO YOUR RTO (%dm)" % int(RTO_RADIO_RANGE)
	return ""


## Radio VO is diegetic: it comes from the PRC-25 on the RTO's back, positionally.
func _radio_vo(line_id: String) -> void:
	var rto: AllyBase = squad_system.member_by_mos("RTO") if (squad_system != null and is_instance_valid(squad_system)) else null
	var src: Variant = null
	if rto != null:
		src = rto.global_position
	VOManager.play_radio(line_id, src)


## Off the horn. Routes through the player so the HANDSET LOWERS with the menu -
## they are one state. Called on the [T] toggle, on dispatch (the call is going out),
## and on a radio-check failure.
func _close_net() -> void:
	var pl: Node = world.player if world != null else null
	if pl != null and pl.has_method("set_on_net"):
		pl.set_on_net(false)  # stows the handset -> mirrors this menu closed
	else:
		set_fire_menu_mirror(false)  # no player (probe harness): close directly


## True if any living friendly - INCLUDING THE PLAYER - is within DANGER_CLOSE_M
## of the aim point (gates the confirm). ADR-011 required amendment: dropping a
## snake-eye on your own head must cost the same second press as dropping it on
## your men.
## `reach` extends the warning out to the edge of the footprint: a man 40m down the
## run is under a napalm strip even though he is nowhere near its mark.
func _danger_close_to_squad(target: Vector3, reach: float = 0.0) -> bool:
	var near: float = DANGER_CLOSE_M + reach
	if world != null and world.player != null and is_instance_valid(world.player):
		if world.player.global_position.distance_to(target) <= near:
			return true
	if squad_system == null or not is_instance_valid(squad_system):
		return false
	for a in squad_system.members:
		var ally := a as AllyBase
		if ally != null and is_instance_valid(ally) and not ally.is_dead():
			if ally.global_position.distance_to(target) <= near:
				return true
	return false


func _arty_impact(pos: Vector3, deform: bool) -> void:
	if world == null:
		return
	var ground := pos
	ground.y = world.terrain_manager.get_height_at(pos)
	CombatManager.apply_explosion_damage(ground, 200, 60, FirePlan.ARTY_BLAST_M, null)
	if deform:  # crater cap: 2 of 6 rounds deform
		DamageSystem.apply_damage(ground, DamageSystem.DamageType.MEDIUM_EXPLOSION, 0.9)
	GunFX.play_explosion_3d(get_tree().current_scene, ground)
	NoiseBus.emit_noise(NoiseBus.NoiseType.EXPLOSION, ground, 0)


func _run_mortar_mission(target: Vector3, fo: int = 0) -> void:
	toast.emit("FIRE MISSION - SPOT ROUND OUT (%d left)" % fire_support["mortar"])
	_radio_vo("mortar_mission")
	# fo_fac tightens the sheaf and, for a veteran radioman (fo>=5), adds a 4th round.
	var scat: float = FirePlan.sheaf_scale(fo)
	var rounds: int = 3 + (1 if fo >= 5 else 0)
	# The spot round is a RANGING shot: it strays further than the sheaf on purpose,
	# which is why it lands outside the ring the player was shown.
	var spot: Vector3 = target + Vector3(
		randf_range(-FirePlan.MORTAR_SPOT_M, FirePlan.MORTAR_SPOT_M) * scat, 0.0,
		randf_range(-FirePlan.MORTAR_SPOT_M, FirePlan.MORTAR_SPOT_M) * scat)
	_fire_shell(MORTAR_SHELL, spot, _mortar_impact.bind(0.5))
	for i in range(rounds):
		var round_pos: Vector3 = target + Vector3(
			randf_range(-FirePlan.MORTAR_SHEAF_M, FirePlan.MORTAR_SHEAF_M) * scat, 0.0,
			randf_range(-FirePlan.MORTAR_SHEAF_M, FirePlan.MORTAR_SHEAF_M) * scat)
		get_tree().create_timer(3.0 + float(i)).timeout.connect(
			func() -> void: _fire_shell(MORTAR_SHELL, round_pos, _mortar_impact.bind(1.0)))


## Put a real round in the air onto `impact`. The gun is off the map, so the shell
## is spawned high on the bearing from the firebase and solved onto the point the
## sheaf already picked - the ring the player placed is what the rounds cover.
func _fire_shell(shell_path: String, impact: Vector3, terminal: Callable) -> void:
	if world == null or not is_instance_valid(world):
		return
	var data: ProjectileData = load(shell_path) as ProjectileData
	if data == null:
		return
	var ground: Vector3 = impact
	ground.y = world.terrain_manager.get_height_at(impact) if world.terrain_manager != null else impact.y
	var azimuth: Vector3 = ground - fsb_center
	if fsb_center == Vector3.ZERO:
		azimuth = Vector3(0.6, 0.0, -0.8)
	var from: Vector3 = Ballistics.firing_point(ground, azimuth, SHELL_APEX_M, SHELL_STANDOFF_M)
	Ballistics.fire_arc(data, from, ground, SHELL_FLIGHT_S, world.terrain_manager, terminal)


## RTO-called resupply: pop smoke, the bird drops a crate on it.
var supply_used: bool = false


func request_supply_drop() -> void:
	var err := _radio_check()  # living RTO within 10m - shortcut can't bypass the leash
	if err != "":
		toast.emit(err)
		return
	if supply_used:
		toast.emit("RESUPPLY ALREADY FLOWN")
		return
	if world == null or world.player == null:
		return
	# Needs your smoke on the ground nearby.
	var smoke_pos := Vector3.ZERO
	for cloud in SmokeCloud.active_clouds:
		if is_instance_valid(cloud) and cloud.global_position.distance_to(world.player.global_position) < 20.0:
			smoke_pos = cloud.global_position
			break
	if smoke_pos == Vector3.ZERO:
		toast.emit("POP SMOKE [5] FIRST - THE BIRD NEEDS A MARK")
		return
	supply_used = true
	toast.emit("RESUPPLY INBOUND ON YOUR SMOKE - 20 SECONDS")
	get_tree().create_timer(20.0).timeout.connect(func() -> void:
		_drop_supply_crate(smoke_pos))


func _drop_supply_crate(pos: Vector3) -> void:
	# `world` can be gone: the player may board the exfil bird inside the 20s delay.
	if world == null or not is_instance_valid(world):
		return
	var crate := StaticBody3D.new()
	crate.collision_layer = 1
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.2, 1.0, 1.2)
	col.shape = box
	col.position = Vector3(0, 0.5, 0)
	crate.add_child(col)
	var mesh := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(1.2, 1.0, 1.2)
	mesh.mesh = bm
	mesh.position = Vector3(0, 0.5, 0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.35, 0.4, 0.28)
	mesh.material_override = mat
	crate.add_child(mesh)
	crate.add_to_group("supply_crates")
	world.add_child(crate)
	var ground := pos
	ground.y = world.terrain_manager.get_height_at(pos)
	crate.global_position = ground
	toast.emit("CRATE DOWN - [E] TO RESUPPLY")


func _mortar_impact(pos: Vector3, intensity: float) -> void:
	if world == null:
		return
	var ground := pos
	ground.y = world.terrain_manager.get_height_at(pos)
	CombatManager.apply_explosion_damage(ground, int(140 * intensity), 40, FirePlan.MORTAR_BLAST_M, null)
	if intensity >= 1.0:
		DamageSystem.apply_damage(ground, DamageSystem.DamageType.SMALL_EXPLOSION, intensity)
	GunFX.play_explosion_3d(get_tree().current_scene, ground)
	NoiseBus.emit_noise(NoiseBus.NoiseType.EXPLOSION, ground, 0)


var squad_system: SquadSystem = null


## March the camera ray onto the terrain surface. No range cap: a target always
## resolves, falling back to the far aim point when the ray clears the horizon.
func _cas_ground_target() -> Vector3:
	if world == null or world.player == null:
		return Vector3.ZERO
	var cam: Camera3D = world.player.get_node("Head/Camera3D")
	var origin: Vector3 = cam.global_position
	var dir: Vector3 = -cam.global_transform.basis.z
	const MAX_REACH_M: float = 5000.0
	const STEP_M: float = 12.0
	var prev: Vector3 = origin
	var t: float = STEP_M
	while t <= MAX_REACH_M:
		var p: Vector3 = origin + dir * t
		if p.y <= world.terrain_manager.get_height_at(p):
			var lo: Vector3 = prev
			var hi: Vector3 = p
			for _i in range(8):
				var mid: Vector3 = (lo + hi) * 0.5
				if mid.y <= world.terrain_manager.get_height_at(mid):
					hi = mid
				else:
					lo = mid
			return Vector3(hi.x, world.terrain_manager.get_height_at(hi), hi.z)
		prev = p
		t += STEP_M
	var far: Vector3 = origin + dir * MAX_REACH_M
	return Vector3(far.x, world.terrain_manager.get_height_at(far), far.z)


## ---------- THE WIRE GATE (ADR-029 draft, W2) ----------
## Crossing ~120m walking distance from the gate marker starts an excursion and
## points the patrol at a LIVING location in the push direction. Re-crossing
## inward is the commit moment: the AAR banks, the gate re-arms. No objective,
## no tracker - a penciled circle and a bark.

const WIRE_GATE_M: float = 120.0
const WIRE_RETURN_M: float = 95.0

const FSB_THREAT_M: float = 90.0    ## enemies this close to the compound are on the wire
const FSB_THREAT_MEN: int = 2

## SAPPER ASSAULT (war-room decree 2026-07-20). A night probe on the wire, capped
## at ONE per operation (the friendly-patrol crisis is 2; a base assault is louder,
## so it takes a smaller share of the same budget). Rolled once per night, chance
## by the threat tier the player earned. Notification is emergent: the sappers walk
## in through the 90m ring and trip _poll_firebase_threat - no second toast path.
const SAPPER_DATA: String = "res://data/enemies/vc_sapper.tres"
const SAPPER_COUNT: int = 3
const SAPPER_RING_MIN: float = 300.0
const SAPPER_RING_MAX: float = 500.0
const SAPPER_CHANCE: Dictionary = {"LOW": 0.0, "MODERATE": 0.2, "HIGH": 0.45, "CRITICAL": 0.7}

## THE COORDINATED PUSH. Behind the silent sappers, a LOUD fireteam charges the wire:
## they fire, telegraph with tracers and voices, and pull the garrison's eyes while the
## sappers slip in quiet. They reuse the hunter pattern (ALERT, aimed at the compound),
## NOT the sapper drive - a driven man never fires, and this element must go loud.
const ASSAULT_DATA: String = "res://data/enemies/nva_regular.tres"
const ASSAULT_ELEMENT: int = 4

## A satchel at the bench breaches the munitions dump. It costs the player mortars in
## hand now, and shorts his next allotment (persisted through CampaignState.depot_loss).
const BREACH_MORTAR_LOSS: int = 3
const BREACH_ARTY_LOSS: int = 1

var _sapper_aim: Vector3 = Vector3.ZERO       ## the bench, just inside the wire
var _sapper_launched: bool = false            ## hard cap: one assault per operation
var _sapper_rolled_night: bool = false        ## one roll per night, reset at dawn
var _garrison_stood_to: bool = false          ## the garrison has been promoted to defenders
var _firebase_breached: bool = false          ## the depot is already gone - one breach per op

## Firebase-attack crisis re-fire (bug fix 2026-07-20). The old constant fsb hash made
## the DynamicMissionFactory dedup fire the crisis ONCE per operation, ever. A per-wave
## key lets a genuinely NEW assault re-announce; an active latch stops the 0.5s spam.
var _fsb_threat_active: bool = false
var _fsb_wave: int = 0
var _fsb_clear_polls: int = 0
const FSB_CLEAR_POLLS: int = 20   ## ~10s of SUSTAINED quiet (0.5s poll) re-arms a new wave

## Radio wording per crisis kind. A crisis the player is never told about does
## not exist (r4bk), and the only channel that carries it is the RTO's net.
const CRISIS_CALL: Dictionary = {
	"firebase_attack": "SIX: THE FIREBASE IS IN CONTACT",
	"village": "SIX: A VILLAGE IS CALLING FOR HELP",
	"vc_camp": "S2: CAMP LOCATION CONFIRMED",
	"pinned_patrol": "SIX: FRIENDLY ELEMENT PINNED",
	"ambushed_convoy": "SIX: CONVOY AMBUSHED",
}

var patrol_gate_pos := Vector3.ZERO
var patrol_gate_out := Vector3.FORWARD
var fsb_center := Vector3.ZERO
var patrol_locations: Array[Dictionary] = []   ## {pos: Vector3, kind: String}
var patrol_location := Vector3.ZERO
var patrol_location_kind: String = ""
var patrol_out: bool = false
var patrol_count: int = 0
var _visited_locations: Array[Vector3] = []
var _gate_poll: float = 0.0

## THE ROUTE (patrol-contract, ADR-029 Amendment C — PROPOSED). The player's own
## grease-pencil PLAN: an ordered line of waypoints (world XZ). It is INPUT to the
## ONE location selector (_pick_patrol_location) and to the re-tasking cadence
## (_advance_route_tasking) — never a second picker, never a spawner, never a
## checkable objective. A PackedVector3Array cannot carry a per-waypoint completion
## flag, so the §4 "waypoints never check off" guarantee is structural, not policed.
## Empty = no plan: selection falls back to push-direction (walking IS a 1-point route).
var patrol_route: PackedVector3Array = PackedVector3Array()
var _route_idx: int = 0
const WAYPOINT_REACH_M: float = 40.0
const ROUTE_ANCHOR_MAX_M: float = 260.0   ## a living feature within this of the next mark anchors the sweep


## The P2 map-pencil populates this; the spine feeds it programmatically. Resets the
## walk-through to the first mark.
func set_patrol_route(points: PackedVector3Array) -> void:
	patrol_route = points
	_route_idx = 0


## The next unwalked mark, or ZERO when there is no plan / the plan is walked out.
func _route_anchor() -> Vector3:
	if patrol_route.is_empty() or _route_idx < 0 or _route_idx >= patrol_route.size():
		return Vector3.ZERO
	return patrol_route[_route_idx]


## The nearest unvisited LIVING feature to a mark (never spawns one). Empty when no
## stamped feature sits within ROUTE_ANCHOR_MAX_M — then the mark itself is the area.
func _nearest_location_to(anchor: Vector3) -> Dictionary:
	var best: Dictionary = {}
	var best_d: float = ROUTE_ANCHOR_MAX_M
	for loc in patrol_locations:
		var pos: Vector3 = loc.pos
		if _visited_locations.has(pos):
			continue
		var d: float = Vector2(pos.x - anchor.x, pos.z - anchor.z).length()
		if d < best_d:
			best_d = d
			best = loc
	if not best.is_empty():
		_visited_locations.append(best.pos as Vector3)
	return best


## Walk the player through their planned marks. Reaching the current mark advances to
## the next and re-tasks command's sweep onto the living feature nearest it (or the
## mark itself). THE NET IS THE CHANNEL: off the net the word never reaches him.
func _advance_route_tasking() -> void:
	if not patrol_out or patrol_route.is_empty() or world == null or world.player == null:
		return
	if _route_idx >= patrol_route.size():
		return
	var mark: Vector3 = patrol_route[_route_idx]
	var d: float = Vector2(world.player.global_position.x - mark.x,
		world.player.global_position.z - mark.z).length()
	if d > WAYPOINT_REACH_M:
		return
	state.waypoints_reached += 1
	_route_idx += 1
	if _route_idx >= patrol_route.size():
		return
	if _radio_check() != "":
		return
	var picked: Dictionary = _pick_patrol_location()
	patrol_location = picked.get("pos", Vector3.ZERO)
	patrol_location_kind = str(picked.get("kind", ""))
	rebark_patrol()


func setup_patrol(built: Dictionary) -> void:
	patrol_gate_pos = built.gate_pos
	patrol_gate_out = built.gate_out
	fsb_center = built.get("center", Vector3.ZERO)
	var bench: Node = built.get("bench", null) as Node
	if bench is Node3D:
		_sapper_aim = (bench as Node3D).global_position
	patrol_locations.clear()
	for s in (built.sites as Array):
		var sd: Dictionary = s
		if str(sd.get("kind", "")) in ["village", "vc_camp"]:
			patrol_locations.append({"pos": sd.center as Vector3, "kind": str(sd.kind)})


func _poll_wire_gate() -> void:
	if patrol_gate_pos == Vector3.ZERO or world == null or world.player == null:
		return
	var d: float = Vector2(world.player.global_position.x - patrol_gate_pos.x,
		world.player.global_position.z - patrol_gate_pos.z).length()
	if not patrol_out and d > WIRE_GATE_M:
		patrol_out = true
		patrol_count += 1
		CampaignState.begin_mission()
		var picked: Dictionary = _pick_patrol_location()
		patrol_location = picked.get("pos", Vector3.ZERO)
		patrol_location_kind = str(picked.get("kind", ""))
		# Intel economy (Q2 default): looted documents buy S2's read on WHAT is out
		# there - one point per walk-out, the map circle stays a circle either way.
		if CampaignState.intel_points > 0 and patrol_location != Vector3.ZERO:
			CampaignState.intel_points -= 1
			var kind_name: String = "VC CAMP" if patrol_location_kind == "vc_camp" else "VILLAGE"
			toast.emit("S2 INTEL: %s REPORTED %s" % [kind_name,
				_bearing_name(patrol_location - patrol_gate_pos)])
		_grant_fire_support()
		rebark_patrol()
	elif patrol_out and d < WIRE_RETURN_M:
		patrol_out = false
		_bank_patrol()


## Battalion allots the patrol its steel as you cross the wire outbound. The count
## is a battalion decision; the RTO's fo_fac buys QUALITY (scatter, cooldown, the
## veteran's 4th round) per ADR-011, and one extra tube for a man who has called
## enough of them. Air is thin on a routine patrol - it is what escalation buys you.
##
## ESCALATION IS THE AO'S THREAT TIER, the same LOW/MODERATE/HIGH/CRITICAL string
## the player reads in the barracks and on the main menu (campaign_state.gd
## threat_label, shown at barracks.gd:45 and main_menu.gd:92). Loud patrols raise
## it and clean ones cool it (campaign_state.gd on_mission_end), so the air is
## bought with the player's own noise. Comparing the LABEL, not a threshold float,
## keeps the number that gates the ordnance and the number he is shown identical.
func _grant_fire_support() -> void:
	var rto: AllyBase = squad_system.member_by_mos("RTO") \
		if (squad_system != null and is_instance_valid(squad_system)) else null
	var fo: int = SquadRoster.skill_level(rto.member, "fo_fac") if rto != null else 0
	var tier: String = CampaignState.threat_label()
	fire_support = {
		"bombs": 1, "napalm": 0, "arty": 1,
		"mortar": 3 + (1 if fo >= 6 else 0), "spectre": 0, "cbu": 0,
	}
	if tier in ["HIGH", "CRITICAL"]:
		fire_support["napalm"] = 1
		fire_support["cbu"] = 1
	if tier == "CRITICAL":
		fire_support["spectre"] = 1
	# A breached depot short-changes THIS allotment (persistent, consumed here - the
	# loss is one patrol's, not forever). Without this read, Fork B is cosmetic: the
	# hard-assign above wipes any docked stock.
	var loss: Dictionary = CampaignState.depot_loss
	if not loss.is_empty():
		for kind in loss.keys():
			fire_support[str(kind)] = maxi(0, int(fire_support.get(str(kind), 0)) - int(loss[kind]))
		CampaignState.depot_loss = {}
		CampaignState.save_campaign()
		toast.emit("DEPOT HIT LAST NIGHT - BATTALION SENT WHAT IT COULD")
	if rto != null:
		toast.emit("%s HAS THE HORN - [T] FOR THE NET" % str(rto.member.get("nick", "RTO")))
	if tier in ["HIGH", "CRITICAL"]:
		toast.emit("AO IS %s - BATTALION RELEASED AIR TO US" % tier)


## The one toast concession + the point man's voice. Repeatable from the map.
func rebark_patrol() -> void:
	if patrol_location == Vector3.ZERO:
		return
	var dist_m: int = int(patrol_gate_pos.distance_to(patrol_location))
	toast.emit("SIX WANTS US SWEEPING %s - %dM OUT" % [
		_bearing_name(patrol_location - patrol_gate_pos), dist_m])
	if squad_system != null and is_instance_valid(squad_system):
		var point: AllyBase = squad_system.member_by_mos("POINTMAN")
		if point != null:
			VOManager.play_squad("movement_ahead", point.member, point.global_position)


## A live crisis raised by DynamicMissionFactory. It joins the ring at the front,
## and if the patrol is ALREADY outside the wire it retargets the sweep on the
## spot. THE NET IS THE CHANNEL: off the net the word never reaches him and the
## sweep does not move - the location simply keeps until the next walk-out. No
## marker ever appears from nothing (Fairness Law).
func raise_crisis(loc: Dictionary) -> void:
	var pos: Vector3 = loc.get("pos", Vector3.ZERO)
	if loc.is_empty() or pos == Vector3.ZERO:
		return
	patrol_locations.push_front(loc)
	if not patrol_out or world == null or world.player == null:
		return
	if _radio_check() != "":
		return
	patrol_location = pos
	patrol_location_kind = str(loc.get("kind", ""))
	_visited_locations.append(pos)
	var from: Vector3 = world.player.global_position
	toast.emit("%s - %s, %dM" % [
		str(CRISIS_CALL.get(patrol_location_kind, "SIX: TROUBLE IN THE AO")),
		_bearing_name(pos - from), int(from.distance_to(pos))])
	_radio_vo("on_the_horn")


## Enemies closing on the compound while the patrol is out. The garrison cannot
## call this in itself - they are noncombatant Civilians (mission_generator.gd:744).
func _poll_firebase_threat() -> void:
	if fsb_center == Vector3.ZERO or not patrol_out:
		return
	var near: int = 0
	for e in _live_enemies:
		if not is_instance_valid(e) or e.is_dead():
			continue
		if Vector2(e.global_position.x - fsb_center.x,
				e.global_position.z - fsb_center.z).length() <= FSB_THREAT_M:
			near += 1
	if near >= FSB_THREAT_MEN:
		_fsb_clear_polls = 0
		# The garrison answers the wire whether or not the net carries the word.
		_garrison_stand_to()
		if not _fsb_threat_active:
			# A genuinely NEW assault. Bump the wave so the factory (which dedups on the
			# entity id) sees a fresh crisis instead of the once-per-op ghost the old
			# constant hash produced. The active latch below blocks the 0.5s re-emit.
			_fsb_threat_active = true
			_fsb_wave += 1
			var dmf: Node = MissionGenerator.dynamic_factory_ref
			if dmf is DynamicMissionFactory:
				var base_key: int = hash(Vector2i(int(fsb_center.x), int(fsb_center.z)))
				(dmf as DynamicMissionFactory).emit_location(&"friendly_firebase_under_attack",
					base_key ^ (_fsb_wave * 0x9E3779B1), {"position": fsb_center})
		return
	# Threat thinning. Re-arm only after a SUSTAINED clear, never on the in/out edge -
	# a man loitering on the ring must not spam a fresh crisis each time he crosses it.
	if _fsb_threat_active:
		_fsb_clear_polls += 1
		if _fsb_clear_polls >= FSB_CLEAR_POLLS:
			_fsb_threat_active = false
			_fsb_clear_polls = 0


## The garrison stands to and fights. Each firebase Civilian hands off 1:1 to an
## AllyBase holding his post (GarrisonDefender.promote). Idempotent: the first real
## assault promotes them, later polls are no-ops. Called ONLY from a genuine assault
## (launch_sapper_assault) or a confirmed multi-man threat on the wire - never for a
## lone wanderer - so the garrison stays passive noncombatants until the base is hit.
func _garrison_stand_to() -> void:
	if _garrison_stood_to:
		return
	_garrison_stood_to = true
	var promoted: int = 0
	for n in get_tree().get_nodes_in_group("firebase_garrison"):
		var civ := n as Civilian
		if civ == null:
			continue
		if GarrisonDefender.promote(civ, self, fsb_center) != null:
			promoted += 1
	if promoted > 0:
		toast.emit("STAND TO - THE WIRE'S IN CONTACT")


## A satchel breached the munitions dump. The cost lands: the player loses the mortars
## he is carrying now (immediate legibility), and the depot is short for his NEXT
## walk-out (persisted through CampaignState, consumed by _grant_fire_support). One
## depot, one breach - a second sapper cannot destroy what is already gone.
func on_firebase_breach(_at: Vector3) -> void:
	if _firebase_breached:
		return
	_firebase_breached = true
	fire_support["mortar"] = 0
	fire_support["arty"] = maxi(0, int(fire_support.get("arty", 0)) - BREACH_ARTY_LOSS)
	CampaignState.depot_loss = {"mortar": BREACH_MORTAR_LOSS, "arty": BREACH_ARTY_LOSS}
	CampaignState.save_campaign()
	toast.emit("THE MUNITIONS DUMP IS GONE - MORTARS DOWN, NEXT PATROL RUNS LIGHT")


## One roll per night, one launch per operation, chance by the earned threat tier.
## Reset at dawn so a quiet night is not the last word. The gates are separated from
## the spawn so a probe can prove the GATING (this) and the ASSAULT independently.
func _maybe_launch_sappers() -> void:
	if not MissionWeather.is_night:
		_sapper_rolled_night = false   # a fresh chance each night
		return
	if _sapper_launched or _sapper_rolled_night:
		return
	if patrol_count < 1 or fsb_center == Vector3.ZERO:
		return   # the world must have settled - he has walked out at least once
	_sapper_rolled_night = true
	var chance: float = float(SAPPER_CHANCE.get(CampaignState.threat_label(), 0.0))
	if randf() < chance:
		launch_sapper_assault(SAPPER_COUNT)


## Stand up the assault: sappers on the ring, each carrying a satchel aimed at the
## bench just inside the wire. Public so a probe can drive it without the RNG gate.
func launch_sapper_assault(count: int) -> void:
	if _sapper_launched or fsb_center == Vector3.ZERO:
		return
	_sapper_launched = true
	var aim: Vector3 = _sapper_aim if _sapper_aim != Vector3.ZERO else fsb_center
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(Vector2i(int(fsb_center.x), int(fsb_center.z))) ^ 0x5A9927
	var bearing: float = rng.randf_range(0.0, TAU)
	for i in range(count):
		var a: float = bearing + rng.randf_range(-0.35, 0.35)
		var r: float = rng.randf_range(SAPPER_RING_MIN, SAPPER_RING_MAX)
		var pos: Vector3 = fsb_center + Vector3(cos(a) * r, 0.0, sin(a) * r)
		var sapper: EnemyBase = spawn_tracked_enemy(pos, SAPPER_DATA, "sapper_assault")
		sapper.add_to_group("sapper_assault")
		var charge := SapperCharge.new()
		sapper.add_child(charge)
		charge.setup(aim)
	# The coordinated push: a loud fireteam charges behind the silent sappers. Kept in
	# its OWN group so the sapper wiring stays 3, and spawned ALERT + aimed at the
	# compound so they advance and go loud when the garrison opens up (the fight
	# bootstraps from the sentries firing first, which wakes this element into COMBAT).
	for j in range(ASSAULT_ELEMENT):
		var aa: float = bearing + rng.randf_range(-0.5, 0.5)
		var ar: float = rng.randf_range(SAPPER_RING_MIN + 40.0, SAPPER_RING_MAX + 60.0)
		var apos: Vector3 = fsb_center + Vector3(cos(aa) * ar, 0.0, sin(aa) * ar)
		var trooper: EnemyBase = spawn_tracked_enemy(apos, ASSAULT_DATA, "firebase_assault")
		trooper.add_to_group("firebase_assault")
		trooper.last_known_target_pos = fsb_center
		trooper.target_last_seen_time = 0.0
		trooper._set_tier(EnemyBase.AlertTier.ALERT)
	# Steel is on the way - the garrison stands to and mans the wire.
	_garrison_stand_to()


func _pick_patrol_location() -> Dictionary:
	# A LIVE CRISIS OUTRANKS THE STANDING RING - it is taken before the bearing
	# scan runs, which is the only thing that makes push_front mean anything.
	for c in patrol_locations:
		if not c.has("trigger_state"):
			continue
		var cpos: Vector3 = c.pos
		if _visited_locations.has(cpos):
			continue
		_visited_locations.append(cpos)
		return c
	# THE ROUTE IS THE SELECTOR'S INPUT (ADR-029 Amendment C — PROPOSED). With a plan,
	# the sweep anchors to the LIVING feature nearest the next mark; a bare mark points
	# at itself (a pointer, never a spawn). No plan → fall through to push-direction.
	var anchor: Vector3 = _route_anchor()
	if anchor != Vector3.ZERO:
		var routed: Dictionary = _nearest_location_to(anchor)
		if not routed.is_empty():
			return routed
		return {"pos": anchor, "kind": "area"}
	# Push direction = where he chose to walk out, relative to the gate.
	var pdir: Vector3 = world.player.global_position - patrol_gate_pos
	pdir.y = 0.0
	pdir = patrol_gate_out if pdir.length() < 1.0 else pdir.normalized()
	var best: Dictionary = {}
	var best_d: float = 1.0e9
	for loc in patrol_locations:
		var pos: Vector3 = loc.pos
		if _visited_locations.has(pos):
			continue
		var to: Vector3 = pos - patrol_gate_pos
		to.y = 0.0
		if to.normalized().dot(pdir) >= 0.707 and to.length() < best_d:
			best_d = to.length()
			best = loc
	if best.is_empty():
		for loc2 in patrol_locations:
			var pos2: Vector3 = loc2.pos
			if _visited_locations.has(pos2):
				continue
			if pos2.distance_to(patrol_gate_pos) < best_d:
				best_d = pos2.distance_to(patrol_gate_pos)
				best = loc2
	if best.is_empty() and patrol_locations.size() > 0:
		_visited_locations.clear()  # the ring is walked - it starts over
		best = patrol_locations[patrol_count % patrol_locations.size()]
	if not best.is_empty():
		_visited_locations.append(best.pos as Vector3)
	return best


## The AAR at the wire (ADR-006 amendment): consequences commit, ledger resets,
## a completed patrol IS the rank clock (Q1 default).
func _bank_patrol() -> void:
	var result: Dictionary = state.build_result(true, "PATROL")
	result["shots"] = WeaponHolder.session_shots
	result["hits"] = WeaponHolder.session_hits
	CampaignState.team_xp += maxi(0, DebriefScreen.compute_score(result))
	CampaignState.on_mission_end(result)
	if squad_system != null and is_instance_valid(squad_system):
		squad_system.on_mission_end()
	CampaignState.commit_mission()
	toast.emit("BACK INSIDE THE WIRE - PATROL %d LOGGED, %d KILLS" % [
		patrol_count, int(result.get("kills", 0))])
	patrol_location = Vector3.ZERO
	patrol_location_kind = ""
	_route_idx = 0   # the plan holds; the next walk-out re-walks it from the first mark
	# Fresh ledger for the next walk-out; live groups re-register on spawn.
	state = MissionState.new()
	state.mission_type = "PATROL"
	state.seed_value = patrol_count  # unique per excursion; the op seed owns the world
	state.start_time_ms = Time.get_ticks_msec()


func _bearing_name(dir: Vector3) -> String:
	var heading: float = fposmod(rad_to_deg(atan2(dir.x, -dir.z)), 360.0)
	var names: Array[String] = ["NORTH", "NORTHEAST", "EAST", "SOUTHEAST",
		"SOUTH", "SOUTHWEST", "WEST", "NORTHWEST"]
	return names[int(roundf(heading / 45.0)) % 8]


func is_ended() -> bool:
	return _ended


