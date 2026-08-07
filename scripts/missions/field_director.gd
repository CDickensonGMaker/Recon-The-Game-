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
	restore_field_marks()
	evidence = EvidenceLedger.new(world.mission_seed if world != null else 0)
	if not NoiseBus.noise_emitted.is_connected(_on_noise_evidence):
		NoiseBus.noise_emitted.connect(_on_noise_evidence)
	if not GameManager.player_died.is_connected(_on_player_died):
		GameManager.player_died.connect(_on_player_died)


## Every shot the player fires is a bearing somebody could have taken. Team 1 (enemy)
## noise is ignored: the ledger records what the PLAYER left, not what the AO did.
func _on_noise_evidence(type: int, pos: Vector3, _radius: float, source_team: int) -> void:
	if evidence != null:
		evidence.on_noise(type, pos, source_team, float(Time.get_ticks_msec()) * 0.001)


## Spawn an enemy seated on terrain and wire its death into mission counters.
func spawn_tracked_enemy(pos: Vector3, data_path: String, group_tag: String = "") -> EnemyBase:
	var seated := pos
	if world and world.terrain_manager:
		# surface_y, not terrain height: a man spawned inside the firebase must land on
		# the mound he is standing on, not at its buried toe (game_world.surface_y).
		seated.y = world.surface_y(pos) + 0.5
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


## SimClock is an autoload with no class_name (sim_clock.gd:5) - absent from both
## Engine.has_singleton and ClassDB, so it is reachable only by node path. 1 is the
## out-of-tree fallback for unit tests.
func _sim_day() -> int:
	if not is_inside_tree():
		return 1
	var clock: Node = get_node_or_null(^"/root/SimClock")
	if clock == null:
		return 1
	return int(clock.sim_day)


## Take a LIVING man off the roster and out of the world. `died` never fires, so
## nothing counts him as a kill - a withdrawal is not a casualty (ADR-035 §4).
func despawn_tracked_enemy(enemy: EnemyBase) -> void:
	if enemy == null or not is_instance_valid(enemy):
		return
	_live_enemies.erase(enemy)
	enemy.despawn()


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
	_live_enemies.erase(enemy)
	# Escalation is driven by DETECTION, not by the kill - see _check_detection().
	# A silent, unwitnessed kill leaves the AO cold; that is what makes stealth
	# an economy.
	# The AAR is the PATROL's book: only kills by the player or his own squad, made
	# while he is outside the wire, bank into it. Garrison, air and siege kills are
	# the base's business, not his (playtest 2026-08-04: a phantom "7 kills" AAR).
	if not patrol_out:
		return
	var killer: Node3D = enemy.last_friendly_attacker()
	if killer == null:
		return
	var killer_ally := killer as AllyBase
	if killer.is_in_group("player") or (killer_ally != null and killer_ally.squad_member):
		state.record_kill()


## Hunter escalation: after first contact, patrols move in looking for you.
## Finite pool - you can bleed the AO dry.
var _escalation_active: bool = false
var _hunter_timer: float = 0.0
var _hunter_pool: int = 12
## What the player LEFT BEHIND. Hunters read this instead of his transform: an enemy
## handed the player's live position is telepathic, and it reads as the game cheating.
var evidence: EvidenceLedger = null


## Raise the alarm the first time the player is DETECTED (any enemy in COMBAT).
##
## `last_combat_contact_ms` is a GLOBAL STATIC (`enemy_base.gd:272`) - it rises when ANY
## enemy anywhere goes loud, including an ambient patrol trading with a friendly patrol the
## player never saw. On the seven-minute slice that was nearly unreachable; across a
## thirty-minute day with ambient cells walking the roads it fires a "YOU'VE BEEN MADE"
## with NOTHING BEHIND IT - the hunter spawn below already refuses to send anyone without
## an evidence fix, so the toast was a promise the system would not keep.
##
## So the alarm now requires what the hunters require: something the PLAYER left behind.
func _check_detection() -> void:
	if _escalation_active:
		return
	if EnemyBase.last_combat_contact_ms <= _detect_baseline_ms:
		return
	if evidence == null or evidence.best_fix(float(Time.get_ticks_msec()) * 0.001).is_empty():
		return
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
	# THE LEAD. Hunters walk to a DATED FIX of something the player did - a shot heard,
	# a body left - not to the player. By the time they arrive he has moved, and that
	# gap is the whole feature. With no evidence there is no lead and nobody is sent:
	# a genuinely quiet patrol is never hunted, which is what finally makes ADR-006's
	# "+25 for a contact avoided" mechanical instead of a number in a debrief.
	var now_s: float = float(Time.get_ticks_msec()) * 0.001
	if evidence == null:
		return
	evidence.prune(now_s)
	var fix: Dictionary = evidence.best_fix(now_s)
	if fix.is_empty():
		return
	var lead: Vector3 = fix.pos as Vector3

	_hunter_timer = randf_range(100.0, 160.0) * field_mult
	var count: int = mini(_hunter_pool, randi_range(2, 4))
	_hunter_pool -= count
	var a: float = randf_range(0.0, TAU)
	var base: Vector3 = lead + Vector3(cos(a), 0, sin(a)) * randf_range(180.0, 230.0)
	base.x = clampf(base.x, 60.0, world.map_size - 60.0)
	base.z = clampf(base.z, 60.0, world.map_size - 60.0)
	for i in range(count):
		var pos := base + Vector3(randf_range(-6, 6), 0, randf_range(-6, 6))
		var hunter := spawn_tracked_enemy(pos, "res://data/enemies/nva_regular.tres", "hunters")
		# The tag is a squad_id hash, not a node group - the group is what
		# live_enemy_count("hunters") actually counts, so both must be set.
		hunter.add_to_group("hunters")
		# They search the LEAD, and they are allowed to be wrong about it.
		hunter.last_known_target_pos = lead
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
	# Marks survive a KIA: the tour keeps its map knowledge (Pillar 5 - keeping
	# them removes the reload-and-remap incentive).
	bank_field_marks()
	var result: Dictionary = state.build_result(false, reason)
	# Read straight off state at the bank point (mission_state.gd contract): the AAR
	# names noncombatant deaths, compute_score never reads the key.
	result["civilian_deaths"] = state.civilian_deaths
	mission_failed.emit(result)


func _on_player_died() -> void:
	fail_mission("KIA")


## CAS: press T while aiming at ground -> Skyraider run (budget-limited).
const SKYRAIDER_SCENE := preload("res://scenes/vehicles/skyraider.tscn")  # A-1, dive-bomb
const F4_SCENE := preload("res://scenes/vehicles/f4_phantom.tscn")  # F-4, fast horizontal flyby

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
		elif Input.is_action_just_pressed("illum_strike"):
			arm_fire_mission("illum")  # 7 = illumination round
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
	print("[NETDBG] _open_net: pl=%s has_set_on_net=%s" % [pl, pl != null and pl.has_method("set_on_net")])
	if pl != null and pl.has_method("set_on_net"):
		pl.set_on_net(true)  # raises the handset (if wired) -> mirrors this menu open
	else:
		set_fire_menu_mirror(true)  # no player (probe harness): open directly
	print("[NETDBG] _open_net done: fire_menu_open=%s" % fire_menu_open)
	# Only crow "on the horn" if the net actually opened - the player can refuse the
	# grab (cord out of reach) and give its own "too far" bark.
	if fire_menu_open:
		toast.emit("ON THE HORN - SEND YOUR FIRE MISSION")
		_radio_vo("on_the_horn")


## Terminal mirror, called ONLY from the player's _enter_net/_exit_net. Sets the flag
## and emits - it must never call back into the player, or the two states ping-pong.
func set_fire_menu_mirror(open: bool) -> void:
	print("[NETDBG] mirror(%s) was=%s" % [open, fire_menu_open])
	if fire_menu_open == open:
		return
	fire_menu_open = open
	_set_rto_planted(open)
	if not open:
		clear_armed()
	fire_menu_changed.emit(open)
var fire_support: Dictionary = {"bombs": 0, "napalm": 0, "arty": 0, "mortar": 2, "spectre": 0,
	"cbu": 0, "illum": 2}

## An 81mm illumination round: it hangs high under a parachute and lights the ground
## for a minute-plus. IllumFlare's own 25s/30m are HAND-flare values - a 30m circle
## against a company crossing 300-500m is a spotlight, not battlefield illumination.
const ILLUM_HEIGHT_M: float = 140.0
const ILLUM_DURATION_S: float = 75.0
const ILLUM_RADIUS_M: float = FirePlan.ILLUM_LIGHT_M  # the one table owns the figure

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


## EVERY dispatched call marks its impact area (decree 2026-08-04) - the same
## FirePlan footprint the placement flow draws, standing on the target from the
## moment the call goes out until the ordnance is down. This is what the bench's
## direct keys and the shortcut paths see, since they never arm a placement.
## Seconds per kind ~ last impact: shells ride the volley spread + SHELL_FLIGHT_S,
## air rides spawn-to-release + fall, spectre holds its whole time on station.
const DISPATCH_MARK_S: Dictionary = {"bombs": 10.0, "napalm": 6.0, "arty": 15.0,
	"mortar": 11.0, "spectre": 30.0, "cbu": 6.0, "wp": 8.0, "illum": 5.0}


func _mark_dispatch(kind: String, target: Vector3, run_dir: Vector3) -> void:
	if world == null or not is_instance_valid(world):
		return
	var mark := FirePreview.new()
	mark.name = "DispatchMark"
	mark.terrain = world.terrain_manager
	world.add_child(mark)
	var dir: Vector3 = run_dir.normalized() if run_dir.length() > 0.01 else Vector3.FORWARD
	mark.show_plan(kind, target, dir, fo_skill(), false)
	# Threat corridor (decree 2026-08-04): the strike promotes real trunk colliders
	# in its footprint for its duration, so contact fuzes have canopy to strike.
	if kind != "illum":
		var fp: Dictionary = FirePlan.footprint(kind, fo_skill())
		var reach: float = maxf(float(fp.get("radius", 0.0)),
			maxf(float(fp.get("along", 0.0)), float(fp.get("across", 0.0))) * 0.5) + 8.0
		var dur: float = float(DISPATCH_MARK_S.get(kind, 8.0)) + 5.0
		TreeCoverLayer.threat_zone(get_tree(), target, reach, dur)
		if kind == "bombs" or kind == "napalm" or kind == "cbu":
			TreeCoverLayer.threat_corridor(get_tree(), target - dir * 80.0, target + dir * 80.0,
				float(fp.get("across", 30.0)) * 0.5 + 8.0, dur)
	get_tree().create_timer(float(DISPATCH_MARK_S.get(kind, 8.0))).timeout.connect(func() -> void:
		if is_instance_valid(mark):
			mark.queue_free())


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
	_mark_dispatch(kind, target, _run_axis(target, run_dir))
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
			_radio_vo("arty_barrage")
			_battery_telegraph(target)
			# fo_fac tightens the sheaf: a green radioman scatters wide, a veteran walks
			# it onto the target (lerp 1.0 -> 0.45 across 8 skill levels).
			var scat: float = FirePlan.sheaf_scale(_fo)
			# 8-12 rounds on a golden-angle spiral (decree 2026-08-04: a real barrage,
			# never a grid): successive rounds never neighbour each other and the
			# pattern never repeats. Timing is a gun line, not a metronome.
			var rounds: int = randi_range(FirePlan.ARTY_ROUNDS_MIN, FirePlan.ARTY_ROUNDS_MAX)
			toast.emit("BATTERY FIRE MISSION - %d ROUNDS - SHOT OUT (%d left)" % [rounds, fire_support[kind]])
			var spiral_phase: float = randf() * TAU
			var t_acc: float = 0.0
			for i in range(rounds):
				var ang: float = spiral_phase + float(i) * 2.399963  # golden angle
				var rad: float = FirePlan.ARTY_SHEAF_M * scat * sqrt(float(i) + 0.5) / sqrt(float(rounds))
				var round_pos: Vector3 = target + Vector3(cos(ang), 0.0, sin(ang)) * rad \
					+ Vector3(randf_range(-3.0, 3.0), 0.0, randf_range(-3.0, 3.0))
				t_acc += randf_range(0.35, 1.0)
				get_tree().create_timer(t_acc).timeout.connect(
					func() -> void: _fire_shell(ARTY_SHELL, round_pos, _arty_impact))
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
		"wp":
			_run_wp_mission(target)
		"illum":
			_run_illum_mission(target)
	# Learn-by-doing: the radioman gets better at calling fire the more he does it.
	if _rto != null:
		var fp: int = SquadRoster.credit_use(_rto.member, "fo_fac", 2)
		if fp > 0 and _rto.has_method("on_skill_up"):
			_rto.on_skill_up("fo_fac", fp)


## AN AUTHORED STRIKE, not a called one. The fire-support tiers exist for the PLAYER to spend
## through the radio; this is the demo's arc spending one for spectacle - a napalm strip laid
## across the treeline behind the assault, which the Summoner named as the biggest visual beat
## left on the table. It deliberately does NOT touch `fire_support` stock: the player's tubes
## and sorties are his, and an authored set-piece must never quietly bill him for one.
##
## Everything downstream is the shipped path - same F-4, same run axis, same canisters, same
## FireHazard burn - so this can never drift from what the radio does.
## THE GUN-RUN DISCIPLINE (his ruling, 2026-07-30): "i want to be able to be killed by the
## air but i dont need a warning. but also dont deliberately gun run where the player is
## unless they call in a danger close run."
##
## So the bullet MASK stays lethal to everyone - a strafing run is as indiscriminate as any
## other fire in this war, and a round that finds you is a round that found you. The
## discipline is in the AIMING: nothing the player did not personally ask for is allowed to
## lay its beaten path across him. `danger_close` is his own call and waives this.
const GUN_STANDOFF_M: float = 120.0
## Bearings tried, in order, when the authored axis would sweep the player.
const GUN_AXIS_STEPS: int = 12


func _has_guns(o: CASAirplane.Ordnance) -> bool:
	return o == CASAirplane.Ordnance.GUNS or o == CASAirplane.Ordnance.GUNS_NAPALM


## Closest the beaten path comes to the player. The path is not the target point: rounds are
## aimed ahead of the aircraft, so it is the segment the gun window walks along `axis`.
func _beaten_path_miss(at: Vector3, axis: Vector3) -> float:
	if world == null or world.player == null or not is_instance_valid(world.player):
		return INF
	var p: Vector3 = (world.player as Node3D).global_position
	var dir: Vector3 = axis.normalized()
	var worst: float = INF
	for i in range(9):
		# SAMPLE WHERE THE ROUNDS LAND, not where the aircraft is. The strafe aims
		# STRAFE_LEAD_M ahead of the airframe, so the beaten path is the gun window shifted
		# forward by that much. Sampling the window itself was off by 160m and would clear an
		# axis whose impacts walk straight through the compound.
		var t: float = lerpf(CASAirplane.STRAFE_OPEN_M, CASAirplane.STRAFE_CLOSE_M,
			float(i) / 8.0) + CASAirplane.STRAFE_LEAD_M
		var s: Vector3 = at + dir * t
		worst = minf(worst, Vector2(s.x - p.x, s.z - p.z).length())
	return worst


## An axis whose beaten path clears the player, or ZERO if no bearing does.
func _gun_axis_clear_of_player(at: Vector3, axis: Vector3) -> Vector3:
	if _beaten_path_miss(at, axis) >= GUN_STANDOFF_M:
		return axis
	for i in range(1, GUN_AXIS_STEPS):
		var a: Vector3 = axis.rotated(Vector3.UP, TAU * float(i) / float(GUN_AXIS_STEPS))
		if _beaten_path_miss(at, a) >= GUN_STANDOFF_M:
			return a
	return Vector3.ZERO


func authored_strike(at: Vector3, ordnance: CASAirplane.Ordnance,
		run: Vector3 = Vector3.ZERO, danger_close: bool = false) -> void:
	if world == null:
		return
	var axis: Vector3 = _run_axis(at, run)
	if _has_guns(ordnance) and not danger_close:
		var clear: Vector3 = _gun_axis_clear_of_player(at, axis)
		if clear != Vector3.ZERO:
			axis = clear
		elif ordnance == CASAirplane.Ordnance.GUNS_NAPALM:
			# No bearing keeps the rounds off him. Keep the spectacle, drop the guns.
			ordnance = CASAirplane.Ordnance.NAPALM
			print("[CAS] no clear gun axis %.0fm off the player - napalm only" % GUN_STANDOFF_M)
		else:
			print("[CAS] gun run refused: no axis clears the player by %.0fm" % GUN_STANDOFF_M)
			return
	_launch_flyby(at, ordnance, axis)


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
## shortcut) it falls back to the sight line - which the overfly guard below then
## rotates off his head. EVERY aircraft launch resolves through here.
func _run_axis(target: Vector3, run: Vector3) -> Vector3:
	var axis: Vector3 = run
	if axis.length() <= 0.01:
		if world != null and world.player != null and is_instance_valid(world.player):
			axis = target - world.player.global_position
		else:
			return Vector3.ZERO
	axis.y = 0.0
	if axis.length() < 0.01:
		return Vector3.ZERO
	return _no_overfly_axis(target, axis.normalized())


## NO AIRCRAFT APPROACHES OVER THE PLAYER'S HEAD - not even danger close (decree
## 2026-08-04). The run's ground track (the line through the target along the run
## axis: spawn, approach, pass, climb-out all lie on it) must miss him laterally by
## OVERFLY_MISS_M. A violating axis rotates by the SMALLEST angle that complies;
## when the target itself is nearer him than the miss distance no line through it
## can comply, and broadside (perpendicular to his bearing) is the best possible.
const OVERFLY_MISS_M: float = 40.0


func _track_miss(target: Vector3, axis: Vector3) -> float:
	if world == null or world.player == null or not is_instance_valid(world.player):
		return INF
	var p: Vector3 = (world.player as Node3D).global_position
	var d := Vector2(axis.x, axis.z).normalized()
	var to_p := Vector2(p.x - target.x, p.z - target.z)
	return absf(to_p.x * d.y - to_p.y * d.x)


func _no_overfly_axis(target: Vector3, axis: Vector3) -> Vector3:
	if _track_miss(target, axis) >= OVERFLY_MISS_M:
		return axis
	for i in range(1, 13):
		var ang: float = float(i) * (TAU / 24.0)
		for s in [1.0, -1.0]:
			var cand: Vector3 = axis.rotated(Vector3.UP, ang * s)
			if _track_miss(target, cand) >= OVERFLY_MISS_M:
				return cand
	# Target closer to him than OVERFLY_MISS_M: broadside maximises the miss.
	var p: Vector3 = (world.player as Node3D).global_position
	var to_target := Vector3(target.x - p.x, 0.0, target.z - p.z)
	if to_target.length() < 1.0:
		to_target = Vector3.FORWARD
	var broadside := Vector3(-to_target.z, 0.0, to_target.x).normalized()
	return broadside if axis.dot(broadside) >= 0.0 else -broadside


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
## ANY RADIOMAN IS THE NET (his ruling 2026-08-05: "make it so all radiomen are valid call
## options and the menu is universal" — "that does feul that feeling of a larger war too").
## The net used to be ONE man on ONE roster: your squad's RTO and nobody else, so standing
## next to a firebase radioman with a live PRC-25 on his back got you nothing. Nearest
## living man in "radioman" wins, wherever he came from. This is the ONE authority for
## "whose radio am I on" — do not re-derive it from a squad roster.
func nearest_radioman() -> Node3D:
	var pl: Node3D = world.player if world != null else null
	if pl == null:
		return null
	var best: Node3D = null
	var best_d: float = INF
	for r in get_tree().get_nodes_in_group("radioman"):
		var n := r as Node3D
		if n == null or not is_instance_valid(n):
			continue
		if n.has_method("is_dead") and n.call("is_dead"):
			continue
		var d: float = pl.global_position.distance_to(n.global_position)
		if d < best_d:
			best_d = d
			best = n
	return best


func _radio_check() -> String:
	var rto: Node3D = nearest_radioman()
	if rto == null:
		return "NO RADIO - YOUR RADIO MAN IS DOWN"
	var pl: Node3D = world.player if world != null else null
	if pl != null and pl.global_position.distance_to(rto.global_position) > RTO_RADIO_RANGE:
		return "TOO FAR FROM THE RADIO - GET TO A RADIO MAN (%dm)" % int(RTO_RADIO_RANGE)
	return ""


## Radio VO is diegetic: it comes from the PRC-25 on the RTO's back, positionally.
func _radio_vo(line_id: String) -> void:
	# Diegetic: the voice comes out of the PRC-25 you are actually speaking through, which
	# is whichever radioman the net picked - not always your own squad's man.
	var rto: Node3D = nearest_radioman()
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


func _set_rto_planted(planted: bool) -> void:
	var rto: AllyBase = squad_system.member_by_mos("RTO") \
		if (squad_system != null and is_instance_valid(squad_system)) else null
	if rto != null and is_instance_valid(rto) and not rto.is_dead():
		rto.net_planted = planted


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


## Every round craters (destruction-parity decree 2026-08-04: arty must destroy
## like napalm). DamageSystem queues the digs and drains them
## WorldConfig.TERRAIN_DEFORMS_PER_FRAME at a time, and caps craters per 64m cell
## (MAX_DEFORMS_PER_CELL), so re-shelling one patch stops digging while fresh
## ground still does. A barrage is bounded by the ground it walks over.
func _arty_impact(pos: Vector3) -> void:
	if world == null:
		return
	# Contact fuse (decree 2026-08-04): the round burst WHERE it stopped - a canopy or
	# structure contact stays an airburst, never re-seated to the dirt. Only a burst at
	# the floor digs a crater.
	var floor_y: float = world.terrain_manager.get_height_at(pos)
	var ground := Vector3(pos.x, maxf(pos.y, floor_y), pos.z)
	CombatManager.apply_explosion_damage(ground, 260, 90, FirePlan.ARTY_BLAST_M, null)
	if ground.y - floor_y <= 2.0:
		DamageSystem.apply_damage(Vector3(pos.x, floor_y, pos.z),
			DamageSystem.DamageType.MEDIUM_EXPLOSION, 0.9)
	GunFX.play_explosion_3d(get_tree().current_scene, ground, "explosion_heavy")
	NoiseBus.emit_noise(NoiseBus.NoiseType.EXPLOSION, ground, 0)


## The friendly battery telegraphs like the enemy's (decree 2026-08-04, siege
## pattern siege_director.gd:663-664): tube thump from the gun line, whistle over
## the impact - the gap between them is the warning.
func _battery_telegraph(target: Vector3) -> void:
	AudioManager.play_mortar_tube(fsb_center)
	AudioManager.play_incoming(target)


func _run_mortar_mission(target: Vector3, fo: int = 0) -> void:
	toast.emit("FIRE MISSION - SPOT ROUND OUT (%d left)" % fire_support["mortar"])
	_radio_vo("mortar_mission")
	_battery_telegraph(target)
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


## WHITE PHOSPHORUS - a small BARRAGE that burns an area (decree 2026-08-04: "that
## should be a small barrage that burns an area"). Several rounds on mortar arcs,
## each a white smoke bloom + burning ground over the beaten zone. Self-lit smoke
## only (no real light, ADR-026).
func _run_wp_mission(target: Vector3) -> void:
	toast.emit("WILLY PETE - BATTERY OF %d - SHOT OUT (%d left)"
		% [FirePlan.WP_ROUNDS, int(fire_support.get("wp", 0))])
	_radio_vo("mortar_mission")
	_battery_telegraph(target)
	for i in range(FirePlan.WP_ROUNDS):
		var round_pos: Vector3 = target + Vector3(
			randf_range(-FirePlan.WP_SPREAD_M, FirePlan.WP_SPREAD_M), 0.0,
			randf_range(-FirePlan.WP_SPREAD_M, FirePlan.WP_SPREAD_M))
		get_tree().create_timer(float(i) * 0.9).timeout.connect(
			func() -> void: _fire_shell(MORTAR_SHELL, round_pos, _wp_impact))


## The siege's strategic verb: deciding WHEN to light the wire. Night sight is 56m
## open / 18m jungle and they come from 300-500m, so without this the fight is
## muzzle flashes. The round does no damage - it only takes the dark away, from both
## sides (IllumFlare strips concealment for whoever stands in it).
func _run_illum_mission(target: Vector3) -> void:
	toast.emit("ILLUMINATION - SHOT OUT (%d left)" % int(fire_support.get("illum", 0)))
	_radio_vo("mortar_mission")
	_battery_telegraph(target)
	_fire_shell(MORTAR_SHELL, target, _illum_burst)


func _illum_burst(pos: Vector3) -> void:
	if world == null or not is_instance_valid(world):
		return
	IllumFlare.pop(world, pos, ILLUM_DURATION_S, ILLUM_RADIUS_M, ILLUM_HEIGHT_M)
	NoiseBus.emit_noise(NoiseBus.NoiseType.IMPACT, pos, 0)
	# Light reveals what the dark was hiding - but only what it actually reaches.
	if siege != null and is_instance_valid(siege):
		siege._light_check()


## THE GARRISON LIGHTS ITS OWN WIRE. Illum has only ever reached the world through the
## player's allotment above or a thrown hand flare, so an assault crossing two hundred metres
## of dark was muzzle flashes unless he happened to spend a round on it - and night sight is
## 56m open. A firebase under attack fires its own illum without being asked.
##
## It does NOT touch `fire_support` stock. His tubes are his, and a set-piece must never
## quietly bill him for one (same contract as authored_strike).
## Burn is shorter than the player's round on purpose: the dark between them is the dread,
## and a permanently lit compound is a lit STAGE.
const GARRISON_ILLUM_BURN_S: float = 55.0


func garrison_illum(at: Vector3) -> void:
	if world == null or not is_instance_valid(world):
		return
	# The tube thumps from inside the compound - the defenders' own mortar, not the enemy's.
	AudioManager.play_mortar_tube(fsb_center)
	IllumFlare.pop(world, at, GARRISON_ILLUM_BURN_S, ILLUM_RADIUS_M, ILLUM_HEIGHT_M)
	NoiseBus.emit_noise(NoiseBus.NoiseType.IMPACT, at, 0)
	if siege != null and is_instance_valid(siege):
		siege._light_check()


func _wp_impact(pos: Vector3) -> void:
	if world == null or not is_instance_valid(world):
		return
	# Contact fuse: the flash bursts where it stopped; the burning phosphorus falls,
	# so the fire patch always carpets the floor beneath the burst.
	var floor_y: float = world.terrain_manager.get_height_at(pos)
	var ground := Vector3(pos.x, maxf(pos.y, floor_y), pos.z)
	GunFX.play_explosion_3d(get_tree().current_scene, ground)
	CombatManager.apply_explosion_damage(ground, 40, 20, FirePlan.WP_BLAST_M, null)
	FireHazard.create_at(get_tree().current_scene, Vector3(pos.x, floor_y, pos.z),
		FirePlan.WP_BURN_M, FirePlan.WP_BURN_S)
	NoiseBus.emit_noise(NoiseBus.NoiseType.EXPLOSION, ground, 0)
	var smoke := CPUParticles3D.new()
	smoke.one_shot = true
	smoke.amount = 48
	smoke.lifetime = 3.5
	smoke.explosiveness = 0.4
	smoke.direction = Vector3.UP
	smoke.spread = 55.0
	smoke.initial_velocity_min = 2.0
	smoke.initial_velocity_max = 6.0
	smoke.gravity = Vector3(0.0, 1.2, 0.0)
	smoke.scale_amount_min = 1.2
	smoke.scale_amount_max = 3.0
	smoke.color = Color(0.95, 0.95, 0.92, 0.9)
	get_tree().current_scene.add_child(smoke)
	smoke.global_position = ground + Vector3(0.0, 1.0, 0.0)
	smoke.emitting = true
	get_tree().create_timer(6.0).timeout.connect(func() -> void:
		if is_instance_valid(smoke):
			smoke.queue_free())


## Put a real round in the air onto `impact`. The gun is off the map, so the shell
## is spawned high on the bearing from the firebase and solved onto the point the
## sheaf already picked - the ring the player placed is what the rounds cover.
## `source` is the gun's side of the map: the shell travels source -> impact. Left
## ZERO the round is BATTALION's and flies out from the firebase, which is why an
## enemy tube must pass its own origin or its shells arrive from inside the wire.
func _fire_shell(shell_path: String, impact: Vector3, terminal: Callable,
		source: Vector3 = Vector3.ZERO) -> void:
	if world == null or not is_instance_valid(world):
		return
	var data: ProjectileData = load(shell_path) as ProjectileData
	if data == null:
		return
	var ground: Vector3 = impact
	ground.y = world.terrain_manager.get_height_at(impact) if world.terrain_manager != null else impact.y
	var azimuth: Vector3 = ground - (source if source != Vector3.ZERO else fsb_center)
	if source == Vector3.ZERO and fsb_center == Vector3.ZERO:
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
	# Contact fuse: burst where it stopped; only a floor burst digs.
	var floor_y: float = world.terrain_manager.get_height_at(pos)
	var ground := Vector3(pos.x, maxf(pos.y, floor_y), pos.z)
	CombatManager.apply_explosion_damage(ground, int(140 * intensity), 40, FirePlan.MORTAR_BLAST_M, null)
	if intensity >= 1.0 and ground.y - floor_y <= 2.0:
		DamageSystem.apply_damage(Vector3(pos.x, floor_y, pos.z),
			DamageSystem.DamageType.SMALL_EXPLOSION, intensity)
	GunFX.play_explosion_3d(get_tree().current_scene, ground, "explosion_mortar")
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


## ---------- THE WIRE GATE (ADR-029, W2) ----------
## Crossing ~120m walking distance from the gate marker starts an excursion and
## points the patrol at a LIVING location in the push direction. Re-crossing
## inward is the commit moment: the AAR banks, the gate re-arms. No objective,
## no tracker - a penciled circle and a bark.

const WIRE_GATE_M: float = 120.0
const WIRE_RETURN_M: float = 95.0

const FSB_THREAT_M: float = 90.0    ## enemies this close to the compound are on the wire
const FSB_THREAT_MEN: int = 2

## A satchel at the bench breaches the munitions dump. It costs the player mortars in
## hand now, and shorts his next allotment (persisted through CampaignState.depot_loss).
const BREACH_MORTAR_LOSS: int = 3
const BREACH_ARTY_LOSS: int = 1

## The siege aims here: the bench, just inside the wire (ADR-036 will promote this to
## a set of real installations; today it is the one thing in the compound that exists
## as a placed node).
var siege_aim: Vector3 = Vector3.ZERO
var siege: SiegeDirector = null
var _granted_day: int = -1                    ## one fire-support allotment per sim day
var _garrison_stood_to: bool = false          ## the garrison has been promoted to defenders
var _firebase_breached: bool = false          ## the depot is already gone - one breach per op

## Firebase-attack crisis re-fire (bug fix 2026-07-20). The old constant fsb hash made
## the DynamicMissionFactory dedup fire the crisis ONCE per operation, ever. A per-wave
## key lets a genuinely NEW assault re-announce; an active latch stops the 0.5s spam.
var _fsb_threat_active: bool = false
var _fsb_wave: int = 0
var _fsb_clear_polls: int = 0
const FSB_CLEAR_POLLS: int = 20   ## ~10s of SUSTAINED quiet (0.5s poll) re-arms a new wave
## Alarm stand-to all-clear: ~90s of EMPTY wire (0.5s poll) sends the men back to
## their jobs. Only for non-siege stand-tos - a live siege owns its dawn stand-down.
var _alarm_clear_polls: int = 0
const ALARM_CLEAR_POLLS: int = 180

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
var _siren: SirenTower = null
var patrol_locations: Array[Dictionary] = []   ## {pos: Vector3, kind: String}
## The printed base sheet: surveyed cartography, stamped once at world-build and never
## reconciled against the live world (Summoner ruling 2026-07-28 - an accurate survey,
## Arma model). VC camps and LZs are never surveyed and never appear here.
## Below this footprint a hamlet is too small to have been surveyed and stays off the paper.
const SURVEYED_VILLAGE_MIN_R: float = 26.0
var surveyed_sites: Array[Dictionary] = []     ## {pos: Vector3, kind: String, radius: float}

## THE CIRCLES (patrol-contract decree, 2026-07-28). Places the world offers this
## patrol. The player assigns the ORDER; he may also ignore them entirely - they are
## OFFERED, never REQUIRED, and skipping one is not a failure of anything.
const PATROL_CIRCLE_COUNT: int = 4
var patrol_objectives: Array[Dictionary] = []  ## {pos: Vector3, kind: String}
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
var player_route: PackedVector3Array = PackedVector3Array()
var _route_idx: int = 0
const WAYPOINT_REACH_M: float = 40.0
const ROUTE_ANCHOR_MAX_M: float = 260.0   ## a living feature within this of the next mark anchors the sweep


## The P2 map-pencil populates this; the spine feeds it programmatically. Resets the
## walk-through to the first mark.
func set_player_route(points: PackedVector3Array) -> void:
	player_route = points
	_route_idx = 0


## The next unwalked mark, or ZERO when there is no plan / the plan is walked out.
func _route_anchor() -> Vector3:
	if player_route.is_empty() or _route_idx < 0 or _route_idx >= player_route.size():
		return Vector3.ZERO
	return player_route[_route_idx]


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
	if not patrol_out or player_route.is_empty() or world == null or world.player == null:
		return
	if _route_idx >= player_route.size():
		return
	var mark: Vector3 = player_route[_route_idx]
	var d: float = Vector2(world.player.global_position.x - mark.x,
		world.player.global_position.z - mark.z).length()
	if d > WAYPOINT_REACH_M:
		return
	state.waypoints_reached += 1
	_route_idx += 1
	if _route_idx >= player_route.size():
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
		siege_aim = (bench as Node3D).global_position
	_attach_siege()
	patrol_locations.clear()
	surveyed_sites.clear()
	for s in (built.sites as Array):
		var sd: Dictionary = s
		var kind: String = str(sd.get("kind", ""))
		if kind == "firebase_main":
			_siren = sd.get("siren", null) as SirenTower
		if kind in ["village", "vc_camp"]:
			patrol_locations.append({"pos": sd.center as Vector3, "kind": kind})
		var r: float = float(sd.get("radius", 0.0))
		if kind == "village" and r >= SURVEYED_VILLAGE_MIN_R:
			var seed_value: int = world.mission_seed if world != null else 0
			surveyed_sites.append({"pos": sd.center as Vector3, "kind": kind, "radius": r,
				"name": HamletNames.name_for(seed_value, surveyed_sites.size(), r)})
	if fsb_center != Vector3.ZERO:
		surveyed_sites.append({"pos": fsb_center, "kind": "firebase_main", "radius": 0.0})
	_pick_patrol_objectives()


## A DUNGEON REWARD (Summoner, 2026-07-28): the payoff for raiding a tunnel or a large
## camp, never a pickup you walk over. Call this when such a cache is looted; it hands
## over a real intel piece only if the silent threshold has been quietly reached.
##
## What it grants is a CLAIM, not a fact - a dated third-ink mark on the sheet that the
## game will never reconcile. The camp may have moved. That is the difference between a
## lead and an objective, and it is what keeps this off ADR-022's banned "fog-of-war
## overlay that fills itself in".
## THREE POSSIBLE POSITIONS, ONE REAL (Summoner, 2026-07-30). A captured document names
## places the enemy MIGHT be, and walking them out is the patrol. Marking only true camps
## would make the sheet an objective list; two decoys make it what the doc header already
## claims it is - a CLAIM, not a fact - and it is why the mark is dated and never
## reconciled (ADR-022 forbids a fog-of-war overlay that fills itself in).
const STASH_REVEALS: int = 3
## How far a decoy sits from the real camp: far enough to be a different walk, close
## enough that the set reads as one report about one area.
const DECOY_MIN_M: float = 260.0
const DECOY_MAX_M: float = 620.0


func try_intel_stash() -> bool:
	if not CampaignState.stash_is_due():
		return false
	var known: Dictionary = {}
	for m in CampaignState.reported_marks:
		known["%d_%d" % [int(float(m.get("x", 0))), int(float(m.get("z", 0)))]] = true
	var real: Vector3 = Vector3.ZERO
	for loc in patrol_locations:
		if str(loc.get("kind", "")) != "vc_camp":
			continue
		var p: Vector3 = loc.pos as Vector3
		if known.has("%d_%d" % [int(p.x), int(p.z)]):
			continue
		real = p
		break
	if real == Vector3.ZERO:
		return false
	var marks: Array[Vector3] = [real]
	# Seeded from the real camp, never Time (ADR-010): the same document always names the
	# same three places, so a reload cannot reroll which one was true.
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(Vector2i(int(real.x), int(real.z)))
	var guard: int = 0
	while marks.size() < STASH_REVEALS and guard < 64:
		guard += 1
		var ang: float = rng.randf() * TAU
		var dist: float = rng.randf_range(DECOY_MIN_M, DECOY_MAX_M)
		var d: Vector3 = real + Vector3(cos(ang) * dist, 0.0, sin(ang) * dist)
		if world != null:
			# The AO spans 0..map_size, not a centred box - a decoy off the sheet is a
			# circle the player can never walk to.
			if d.x < 60.0 or d.z < 60.0 \
					or d.x > world.map_size - 60.0 or d.z > world.map_size - 60.0:
				continue
			if world.terrain_manager != null:
				d.y = world.terrain_manager.get_height_at(d)
		if known.has("%d_%d" % [int(d.x), int(d.z)]):
			continue
		marks.append(d)
	# Shuffled on the same seed so the true one is not always the first circle drawn.
	for i in range(marks.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var tmp: Vector3 = marks[i]
		marks[i] = marks[j]
		marks[j] = tmp
	for m in marks:
		CampaignState.reported_marks.append({"x": m.x, "z": m.z, "kind": "CAMP",
			"patrol_no": CampaignState.missions_played})
	CampaignState.consume_stash()
	toast.emit("CAPTURED DOCUMENTS - %d POSSIBLE POSITIONS MARKED (DATE UNKNOWN)" % marks.size())
	return true


## Spread the circles by distance from the wire so the order the player picks is a real
## decision: a near/far mix makes sequencing cost something, four clustered sites do not.
func _pick_patrol_objectives() -> void:
	patrol_objectives.clear()
	if patrol_locations.is_empty():
		return
	var pool: Array[Dictionary] = patrol_locations.duplicate()
	var origin: Vector3 = patrol_gate_pos if patrol_gate_pos != Vector3.ZERO else fsb_center
	pool.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return origin.distance_squared_to(a.pos as Vector3) \
			< origin.distance_squared_to(b.pos as Vector3))
	var want: int = mini(PATROL_CIRCLE_COUNT, pool.size())
	for i in range(want):
		var idx: int = int(round(float(i) * float(pool.size() - 1) / float(maxi(1, want - 1))))
		patrol_objectives.append(pool[idx])


func _poll_wire_gate() -> void:
	if patrol_gate_pos == Vector3.ZERO or world == null or world.player == null:
		return
	var d: float = Vector2(world.player.global_position.x - patrol_gate_pos.x,
		world.player.global_position.z - patrol_gate_pos.z).length()
	# Distance from the GATE alone is not "outside the wire": the compound is wide
	# enough that a walk from the LZ to the hooches trips 120m-from-the-gate without
	# ever leaving the base, and the return then BANKS a patrol never taken (his
	# playtest 2026-08-04: a phantom loop credited with the garrison's kills). An
	# excursion requires being far from the gate AND far from the compound center.
	if fsb_center != Vector3.ZERO:
		d = minf(d, Vector2(world.player.global_position.x - fsb_center.x,
			world.player.global_position.z - fsb_center.z).length())
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
		if GameFlow.demo_mode:
			# Demo-scoped exception to ADR-035's finite pool (decree 2026-08-03 §2.9, wired
			# 2026-08-04): 12 men at 2-4 a wave is ~7.7 minutes of contact and then an empty
			# AO for the rest of a 30-minute day. The full game keeps the finite pool.
			_hunter_pool = maxi(_hunter_pool, 6)
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
	# ONE ALLOTMENT PER DAY. The gate thresholds are 120m out / 95m in - a 25m band -
	# and the wire fight happens inside it, so an unlatched hard assign let a player
	# re-arm mid-siege by walking twenty-five metres.
	var day: int = _sim_day()
	if day == _granted_day:
		return
	_granted_day = day
	var rto: AllyBase = squad_system.member_by_mos("RTO") \
		if (squad_system != null and is_instance_valid(squad_system)) else null
	var fo: int = SquadRoster.skill_level(rto.member, "fo_fac") if rto != null else 0
	var tier: String = CampaignState.threat_label()
	fire_support = {
		"bombs": 1, "napalm": 0, "arty": 1,
		"mortar": 3 + (1 if fo >= 6 else 0), "spectre": 0, "cbu": 0,
		"illum": 2 + (1 if fo >= 4 else 0),
	}
	if tier in ["HIGH", "CRITICAL"]:
		fire_support["napalm"] = 1
		fire_support["cbu"] = 1
	if tier == "CRITICAL":
		fire_support["spectre"] = 1
	if GameFlow.demo_mode:
		# HIS RULING 2026-08-03: "there should be 3 bombing runs thats it." Three calls of
		# ONE kind, overruling the council's bomb/arty/mortar split - spending the first
		# teaches the other two, and a stranger learning one verb well beats three badly.
		# The night raid's napalm and the daytime bursts are SCRIPTED SPECTACLE and are
		# billed to nobody; the garrison lights its own wire without touching this stock
		# either (`garrison_illum`), so zeroing illum costs the player no light.
		fire_support = {"bombs": 3, "napalm": 0, "arty": 0, "mortar": 0,
			"spectre": 0, "cbu": 0, "illum": 0}
		print("[DEMO] fire support: 3 bombing runs, nothing else")
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
		toast.emit("%s HAS THE HORN - [T] FOR THE NET" % SquadRoster.call_name(rto.member))
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


## Enemies closing on the compound. Runs whether or not the player is outside the
## wire: a siege happens TO him at home, and gating on patrol_out meant a man in
## his own compound was never told (ADR-035 §1).
func _poll_firebase_threat() -> void:
	if fsb_center == Vector3.ZERO:
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
		_alarm_clear_polls = 0
		# The garrison answers the wire whether or not the net carries the word.
		_garrison_stand_to()
		if not _fsb_threat_active:
			# A genuinely NEW assault. Bump the wave so the factory (which dedups on the
			# entity id) sees a fresh crisis instead of the once-per-op ghost the old
			# constant hash produced. The active latch below blocks the 0.5s re-emit.
			_fsb_threat_active = true
			_fsb_wave += 1
			# Only a patrol that is OUT gets a crisis it can be re-tasked onto. Emitting
			# while he is home banks a firebase_attack location that _pick_patrol_location
			# takes first, and his next walk-out would task him to sweep his own base.
			if patrol_out:
				var dmf: Node = MissionGenerator.dynamic_factory_ref
				if dmf is DynamicMissionFactory:
					var base_key: int = hash(Vector2i(int(fsb_center.x), int(fsb_center.z)))
					(dmf as DynamicMissionFactory).emit_location(&"friendly_firebase_under_attack",
						base_key ^ (_fsb_wave * 0x9E3779B1), {"position": fsb_center})
			else:
				toast.emit(CRISIS_CALL["firebase_attack"])
		return
	# Threat thinning. Re-arm only after a SUSTAINED clear, never on the in/out edge -
	# a man loitering on the ring must not spam a fresh crisis each time he crosses it.
	if _fsb_threat_active:
		_fsb_clear_polls += 1
		if _fsb_clear_polls >= FSB_CLEAR_POLLS:
			_fsb_threat_active = false
			_fsb_clear_polls = 0
	# All-clear for an ALARM stand-to. near==0 only - one live enemy on the wire is
	# not quiet - and never while a siege runs: dawn owns that stand-down.
	if _garrison_stood_to and near == 0 and (siege == null or not siege.active):
		_alarm_clear_polls += 1
		if _alarm_clear_polls >= ALARM_CLEAR_POLLS:
			_alarm_clear_polls = 0
			_garrison_stand_down()
			toast.emit("STAND DOWN - THE WIRE'S QUIET")
	else:
		_alarm_clear_polls = 0


## The garrison stands to and fights. Each firebase Civilian hands off 1:1 to an
## AllyBase holding his post (GarrisonDefender.promote). Idempotent while stood-to;
## re-armed by _garrison_stand_down (siege dawn, or the alarm all-clear above).
## Doors in: siege, the multi-man wire poll, a delivery into a fight, and
## garrison_alarm() - a soldier who HEARS enemy fire or takes a hit answers it
## (Summoner ruling 2026-08-04: garrison men are soldiers, not civilians).
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
	# Printed unconditionally, including the zero. "Did the garrison stand to?" was the
	# central unanswerable question of the 2026-07-29 playtest, and a stand-to that promotes
	# nobody looks exactly like one that never fired.
	print("[FSB] stand to: promoted %d garrison civilian(s) to defenders" % promoted)
	if promoted > 0:
		toast.emit("STAND TO - THE WIRE'S IN CONTACT")


## The public alarm. A garrison man heard enemy fire or took a hit (civilian.gd
## garrison branches). Stands the base to ONLY when the source is at the wire -
## the demo AO carries near-constant ambient contact, and an ungated alarm keeps
## the garrison permanently promoted (measured 2026-08-04: camp life dead).
const GARRISON_ALARM_M: float = 120.0

func garrison_alarm(at: Vector3) -> void:
	if fsb_center == Vector3.ZERO:
		return
	if Vector2(at.x - fsb_center.x, at.z - fsb_center.z).length() > GARRISON_ALARM_M:
		return
	_garrison_stand_to()


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


## Stand the siege up and hand it the compound it is coming for. Called once the
## firebase exists; SiegeDirector owns cadence from there.
func _attach_siege() -> void:
	if siege != null or fsb_center == Vector3.ZERO:
		return
	siege = SiegeDirector.new()
	add_child(siege)
	siege.setup(self, fsb_center, siege_aim if siege_aim != Vector3.ZERO else fsb_center)
	siege.siege_began.connect(_on_siege_began)
	siege.siege_ended.connect(_on_siege_ended)
	siege.siege_overrun.connect(_on_siege_overrun)


func _on_siege_began(_strength: int, probe: bool) -> void:
	_garrison_stand_to()
	if probe:
		# A probe is 2d6 sappers. Crying the siren for three men in the wire is
		# how the siren stops meaning anything - the sentry's shout carries it.
		toast.emit("MOVEMENT ON THE WIRE - STAND TO")
		return
	# The old copy read "(%d ON THE WIRE)". Nobody inside the perimeter could
	# know that number at stand-to; the count is the director's roll, not
	# anything a man on a tower can see in the dark.
	toast.emit("STAND TO")
	_sound_siren()


## They are through the wire. A man standing on the berm can see this for himself, so the
## call carries no count - it tells him the fight has moved behind him, which is the one
## thing his own eyes cannot check while he is facing out.
func _on_siege_overrun(_inside: int) -> void:
	toast.emit("THEY'RE INSIDE THE WIRE")
	_sound_siren()


## The tower sentry needs a moment to reach the crank. It also puts the wail
## AFTER the first ranging round rather than under it - SiegeDirector starts its
## mortar timer at zero, so the shells announce themselves first.
func _sound_siren() -> void:
	if _siren == null or not is_instance_valid(_siren):
		return
	await get_tree().create_timer(randf_range(2.0, 5.0)).timeout
	if _siren != null and is_instance_valid(_siren):
		_siren.sound()


## The night banks its own AAR. _bank_patrol only fires on crossing the wire inward,
## so a siege fought at home produced no butcher's bill at all - while the contact
## ledger debited him for being attacked in his sleep.
func _on_siege_ended(reason: String, killed: int, strength: int) -> void:
	match reason:
		"broken":
			toast.emit("THEY'RE BREAKING - %d OF %d DOWN, THE REST ARE PULLING BACK"
				% [killed, strength])
		"wiped":
			toast.emit("THE WIRE HELD - ALL %d ACCOUNTED FOR" % strength)
		_:
			toast.emit("FIRST LIGHT - THEY'VE MELTED AWAY (%d OF %d DOWN)" % [killed, strength])
	_garrison_stand_down()


## Dawn. The survivors go back to being men with jobs, and the dead are not replaced -
## that permanence is what makes night 2 different from night 1. Without this the first
## stand-to deletes the garrison's Civilians for the rest of the operation.
func _garrison_stand_down() -> void:
	if not _garrison_stood_to:
		return
	_garrison_stood_to = false
	for n in get_tree().get_nodes_in_group("garrison_promoted"):
		var ally := n as AllyBase
		if ally == null or ally.is_dead():
			continue
		GarrisonDefender.stand_down(ally, self)


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
## The INTEL layer rides CampaignState between excursions (ADR-022 Amendment A).
## Seed and bank are the ONLY two lines anywhere that may touch both stores - the
## selector, the tasking and the scorer never read marks (§4, probed).
func restore_field_marks() -> void:
	state.field_marks = CampaignState.field_marks.duplicate(true)
	state.pencil_marks = CampaignState.pencil_marks.duplicate(true)


func bank_field_marks() -> void:
	CampaignState.field_marks = state.field_marks.duplicate(true)
	CampaignState.pencil_marks = state.pencil_marks.duplicate(true)


## Metres from a CIRCLE at which the AAR counts it as walked. Generous on purpose:
## the man was THERE, and the sheet's own circle is a general area, not a trigger.
const CIRCLE_WALKED_M: float = 70.0


## What he planned against what he actually walked. ADR-006 pays for what was learned,
## never for what was ticked, so this REPORTS and never scores: skipping every circle
## is legal and costs nothing.
func _route_report() -> String:
	var order: Array = state.route_order
	if order.is_empty():
		return ""
	var walked: int = 0
	for idx in order:
		var oi: int = int(idx)
		if oi < 0 or oi >= patrol_objectives.size():
			continue
		var p: Vector3 = patrol_objectives[oi].pos as Vector3
		for v in _visited_locations:
			if (v as Vector3).distance_to(p) <= CIRCLE_WALKED_M:
				walked += 1
				break
	return "PLANNED %d, WALKED %d" % [order.size(), walked]


func _bank_patrol() -> void:
	bank_field_marks()
	var report: String = _route_report()
	if not report.is_empty():
		toast.emit("ROUTE: %s" % report)
	var result: Dictionary = state.build_result(true, "PATROL")
	# Same read as fail_mission():210 - it is off _base_result on purpose (mission_state.gd:18-22),
	# so every bank point must take it or that patrol's noncombatant count is discarded.
	result["civilian_deaths"] = state.civilian_deaths
	result["shots"] = WeaponHolder.session_shots
	result["hits"] = WeaponHolder.session_hits
	if CampaignState.bank_reputation(DebriefScreen.compute_score(result)):
		toast.emit("FIELD PROMOTION: %s" % CampaignState.title())
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
	restore_field_marks()


func _bearing_name(dir: Vector3) -> String:
	var heading: float = fposmod(rad_to_deg(atan2(dir.x, -dir.z)), 360.0)
	var names: Array[String] = ["NORTH", "NORTHEAST", "EAST", "SOUTHEAST",
		"SOUTH", "SOUTHWEST", "WEST", "NORTHWEST"]
	return names[int(roundf(heading / 45.0)) % 8]


func is_ended() -> bool:
	return _ended


