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
				fire_menu_open = true
				fire_menu_changed.emit(true)
				toast.emit("ON THE HORN - SEND YOUR FIRE MISSION")
				_radio_vo("on_the_horn")
		else:
			fire_menu_open = false
			fire_menu_changed.emit(false)
	if fire_menu_open and GameManager.can_player_act():
		if Input.is_action_just_pressed("slot_1"):
			request_fire_support("bombs")
		elif Input.is_action_just_pressed("slot_2"):
			request_fire_support("napalm")
		elif Input.is_action_just_pressed("slot_3"):
			request_fire_support("arty")
		elif Input.is_action_just_pressed("slot_4"):
			request_fire_support("mortar")
		elif Input.is_action_just_pressed("wheel_up") or Input.is_action_just_pressed("wheel_down"):
			pass  # keep wheel for kit even with menu open
		elif Input.is_action_just_pressed("pop_flare"):
			pass
		elif Input.is_action_just_pressed("throw_smoke"):
			request_fire_support("spooky")  # 5 = Spooky while menu is open
		elif Input.is_action_just_pressed("cbu_strike"):
			request_fire_support("cbu")  # 6 = CBU cluster run
	if Input.is_action_just_pressed("mortar_strike") and GameManager.can_player_act():
		request_fire_support("mortar")
	if Input.is_action_just_pressed("supply_drop") and GameManager.can_player_act():
		request_supply_drop()


## Unified call-for-fire: budgets per mission, all RTO-gated.
signal fire_menu_changed(open: bool)
static var any_fire_menu_open: bool = false  ## input guard for kit keys
var fire_menu_open: bool = false:
	set(value):
		fire_menu_open = value
		any_fire_menu_open = value
var fire_support: Dictionary = {"bombs": 0, "napalm": 0, "arty": 0, "mortar": 2, "spooky": 0, "cbu": 0}
const DANGER_CLOSE_M: float = 45.0
const RTO_RADIO_RANGE: float = 10.0  ## must be this close to the living RTO to use the radio
const DANGER_CLOSE_CONFIRM_S: float = 5.0  ## confirm window; a stale pend must never pre-confirm
var _pending_danger_close: String = ""  ## the call awaiting a danger-close confirm press
var _pending_dc_at_ms: int = 0  ## when the pend was raised (Time.get_ticks_msec)
## How many men an escaped informer brings back, and what they are.
const INFORMER_RESPONSE: int = 4
const INFORMER_RESPONSE_DATA: String = "res://data/enemies/vc_rifleman.tres"
var _informer_answered: bool = false


func request_fire_support(kind: String) -> void:
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
	var target := _cas_ground_target()
	if target == Vector3.ZERO:
		toast.emit("NO TARGET - AIM AT THE GROUND")
		return
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
	_close_net()  # call is going out - off the horn
	fire_support[kind] = int(fire_support[kind]) - 1
	# FO/FAC is the RADIOMAN's skill, not the player's.
	var _rto := squad_system.member_by_mos("RTO") if squad_system != null else null
	var _fo: int = SquadRoster.skill_level(_rto.member, "fo_fac") if _rto != null else 0
	_cas_cooldown = maxf(10.0, 25.0 - 2.0 * float(_fo))
	match kind:
		"bombs":
			_launch_cas(target, CASAirplane.Ordnance.BOMB)
			toast.emit("FAST MOVER INBOUND - SNAKE EYE (%d left)" % fire_support[kind])
			_radio_vo("snake_eye")
		"napalm":
			_launch_flyby(target, CASAirplane.Ordnance.NAPALM)
			toast.emit("FAST MOVER - NAPALM RUN INBOUND - GET BACK (%d left)" % fire_support[kind])
			_radio_vo("napalm_run")
		"arty":
			toast.emit("BATTERY FIRE MISSION - SHOT OUT (%d left)" % fire_support[kind])
			_radio_vo("arty_barrage")
			# fo_fac tightens the sheaf: a green radioman scatters wide, a veteran walks
			# it onto the target (lerp 1.0 -> 0.45 across 8 skill levels).
			var scat: float = lerpf(1.0, 0.45, clampf(float(_fo) / 8.0, 0.0, 1.0))
			for i in range(6):
				get_tree().create_timer(4.0 + float(i) * 0.7).timeout.connect(
					_arty_impact.bind(target + Vector3(randf_range(-18, 18) * scat, 0, randf_range(-18, 18) * scat), i % 3 == 0))
		"mortar":
			_run_mortar_mission(target, _fo)
		"spooky":
			SpookyGunship.call_in(world, world.terrain_manager, target)
			toast.emit("SPOOKY ON STATION - 30 SECONDS OF RAIN (%d left)" % fire_support[kind])
			_radio_vo("spooky")
		"cbu":
			_launch_flyby(target, CASAirplane.Ordnance.CBU)
			toast.emit("FAST MOVER - CLUSTER RUN INBOUND - DANGER CLOSE (%d left)" % fire_support[kind])
			_radio_vo("cbu_cluster")
	# Learn-by-doing: the radioman gets better at calling fire the more he does it.
	if _rto != null:
		var fp: int = SquadRoster.credit_use(_rto.member, "fo_fac", 2)
		if fp > 0 and _rto.has_method("on_skill_up"):
			_rto.on_skill_up("fo_fac", fp)


func _launch_cas(target: Vector3, ordnance: CASAirplane.Ordnance) -> void:
	var plane: CASAirplane = SKYRAIDER_SCENE.instantiate()
	world.add_child(plane)
	var run_dir := Vector3.ZERO
	if world.player:
		run_dir = target - world.player.global_position
	plane.call_strike(world.terrain_manager, target, ordnance, run_dir)


## F-4 fast horizontal flyby (napalm/CBU): in low, pickle on the pass, climb out.
func _launch_flyby(target: Vector3, ordnance: CASAirplane.Ordnance) -> void:
	var plane: CASAirplane = F4_SCENE.instantiate()
	world.add_child(plane)
	var run_dir := Vector3.ZERO
	if world.player:
		run_dir = target - world.player.global_position
	plane.call_flyby(world.terrain_manager, target, ordnance, run_dir)


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


func _close_net() -> void:
	if fire_menu_open:
		fire_menu_open = false
		fire_menu_changed.emit(false)


## True if any living friendly - INCLUDING THE PLAYER - is within DANGER_CLOSE_M
## of the aim point (gates the confirm). ADR-011 required amendment: dropping a
## snake-eye on your own head must cost the same second press as dropping it on
## your men.
func _danger_close_to_squad(target: Vector3) -> bool:
	if world != null and world.player != null and is_instance_valid(world.player):
		if world.player.global_position.distance_to(target) <= DANGER_CLOSE_M:
			return true
	if squad_system == null or not is_instance_valid(squad_system):
		return false
	for a in squad_system.members:
		var ally := a as AllyBase
		if ally != null and is_instance_valid(ally) and not ally.is_dead():
			if ally.global_position.distance_to(target) <= DANGER_CLOSE_M:
				return true
	return false


func _arty_impact(pos: Vector3, deform: bool) -> void:
	if world == null:
		return
	var ground := pos
	ground.y = world.terrain_manager.get_height_at(pos)
	CombatManager.apply_explosion_damage(ground, 200, 60, 14.0, null)
	if deform:  # crater cap: 2 of 6 rounds deform
		DamageSystem.apply_damage(ground, DamageSystem.DamageType.MEDIUM_EXPLOSION, 0.9)
	GunFX.play_explosion_3d(get_tree().current_scene, ground)
	NoiseBus.emit_noise(NoiseBus.NoiseType.EXPLOSION, ground, 0)


func _run_mortar_mission(target: Vector3, fo: int = 0) -> void:
	toast.emit("FIRE MISSION - SPOT ROUND OUT (%d left)" % fire_support["mortar"])
	_radio_vo("mortar_mission")
	# fo_fac tightens the sheaf and, for a veteran radioman (fo>=5), adds a 4th round.
	var scat: float = lerpf(1.0, 0.45, clampf(float(fo) / 8.0, 0.0, 1.0))
	var rounds: int = 3 + (1 if fo >= 5 else 0)
	get_tree().create_timer(3.0).timeout.connect(func() -> void:
		_mortar_impact(target + Vector3(randf_range(-15, 15) * scat, 0, randf_range(-15, 15) * scat), 0.5))
	for i in range(rounds):
		get_tree().create_timer(6.0 + float(i)).timeout.connect(func() -> void:
			_mortar_impact(target + Vector3(randf_range(-8, 8) * scat, 0, randf_range(-8, 8) * scat), 1.0))


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
	CombatManager.apply_explosion_damage(ground, int(140 * intensity), 40, 10.0, null)
	if intensity >= 1.0:
		DamageSystem.apply_damage(ground, DamageSystem.DamageType.SMALL_EXPLOSION, intensity)
	GunFX.play_explosion_3d(get_tree().current_scene, ground)
	NoiseBus.emit_noise(NoiseBus.NoiseType.EXPLOSION, ground, 0)


var squad_system: SquadSystem = null


## March the camera ray onto the terrain surface.
func _cas_ground_target() -> Vector3:
	if world == null or world.player == null:
		return Vector3.ZERO
	var cam: Camera3D = world.player.get_node("Head/Camera3D")
	var origin: Vector3 = cam.global_position
	var dir: Vector3 = -cam.global_transform.basis.z
	for i in range(1, 60):
		var p := origin + dir * (float(i) * 8.0)
		var ground: float = world.terrain_manager.get_height_at(p)
		if p.y <= ground:
			return Vector3(p.x, ground, p.z)
	return Vector3.ZERO


## ---------- THE WIRE GATE (ADR-029 draft, W2) ----------
## Crossing ~120m walking distance from the gate marker starts an excursion and
## points the patrol at a LIVING location in the push direction. Re-crossing
## inward is the commit moment: the AAR banks, the gate re-arms. No objective,
## no tracker - a penciled circle and a bark.

const WIRE_GATE_M: float = 120.0
const WIRE_RETURN_M: float = 95.0

const FSB_THREAT_M: float = 90.0    ## enemies this close to the compound are on the wire
const FSB_THREAT_MEN: int = 2

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


func setup_patrol(built: Dictionary) -> void:
	patrol_gate_pos = built.gate_pos
	patrol_gate_out = built.gate_out
	fsb_center = built.get("center", Vector3.ZERO)
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
		"mortar": 3 + (1 if fo >= 6 else 0), "spooky": 0, "cbu": 0,
	}
	if tier in ["HIGH", "CRITICAL"]:
		fire_support["napalm"] = 1
		fire_support["cbu"] = 1
	if tier == "CRITICAL":
		fire_support["spooky"] = 1
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
## call this in itself - they are noncombatant Civilians (mission_generator.gd:702).
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
	if near < FSB_THREAT_MEN:
		return
	var dmf: Node = MissionGenerator.dynamic_factory_ref
	if dmf is DynamicMissionFactory:
		(dmf as DynamicMissionFactory).emit_location(&"friendly_firebase_under_attack",
			hash(Vector2i(int(fsb_center.x), int(fsb_center.z))), {"position": fsb_center})


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


