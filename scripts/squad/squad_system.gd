## squad_system.gd - the player-led squad (SQUAD_SIZE) in every mission: spawning from the
## persistent roster, orders (F1-F4), medic revive chain, role effects, barks,
## casualty persistence.
class_name SquadSystem
extends Node

signal squad_changed

const REVIVES_PER_MISSION: int = 2
const REVIVE_CHANNEL_SECONDS: float = 5.0
## Player-led squad for the village assault: 5 specialists + riflemen (SquadRoster.SQUAD_SIZE).
const SQUAD_SIZE: int = 8

var world: GameWorld
var director: FieldDirector
var members: Array[AllyBase] = []
var weapons_free: bool = true
var revives_left: int = REVIVES_PER_MISSION

var _reviving: bool = false
var _revive_timer: float = 0.0
var _downed_clock: float = 0.0
var _health: HealthSystem = null
var _bark_cooldown: float = 0.0
var _point_warned: Dictionary = {}
var _thumper_cooldown: float = 0.0
var _roster_rng := RandomNumberGenerator.new()
## The ally grenadier fires the same round the player does, so centre, rim and
## radius all come from data/projectiles/m79_he.tres - the same record
## ProjectileBase reads. The fallbacks apply ONLY when that fails to load.
const FALLBACK_THUMPER_DAMAGE: int = 150
const FALLBACK_THUMPER_RADIUS: float = 6.0
## ADR-016 Amendment F: the rim is 0.15 of centre. ProjectileBase derives it the
## same way; the two must not drift.
const RIM_FRACTION: float = 0.15
static var _m79_he: ProjectileData = null
## One-shot: the squad auto-goes-loud with the player's first shot. Any manual
## F4/N toggle takes over and disarms the automatic.
var _auto_flip_armed: bool = true


func setup(game_world: GameWorld, mission_director: FieldDirector, spawn_pos: Vector3) -> void:
	world = game_world
	director = mission_director
	_roster_rng.seed = int(director.state.seed_value) + 67890
	var roster: Array = SquadRoster.ensure_roster(int(director.state.seed_value) + 12345)
	var squad_n: int = mini(SQUAD_SIZE, roster.size())
	for i in range(squad_n):
		var m: Dictionary = roster[i]
		var a := TAU * float(i) / float(squad_n)
		var pos := spawn_pos + Vector3(cos(a), 0, sin(a)) * 3.5
		pos.y = world.terrain_manager.get_height_at(pos) + 0.5
		var ally := AllyBase.spawn_ally(world, pos)
		ally.member = m
		ally.director = director  ## toast channel for promotion barks
		var mos: String = str(m.mos)
		var unit: String = _pick_unit_for_mos(mos)
		var weapon: String = MOS_WEAPON.get(mos, "m16a1")
		if mos == "MG":
			ally.fire_rate_mult = 1.6
		# spawn_ally() already ran _setup_visual(), so this rebuilds it.
		ally.set_sprite(unit, weapon)
		# Explicit: he wears his roster face/helmet whether or not set_sprite
		# rebuilt (the default-body draw early-returns and would keep bench paint).
		ally.dress_visual()
		ally.file_slot = i + 1
		ally.point_slot = mos == "POINTMAN"
		ally.died.connect(_on_member_died)
		members.append(ally)
	# Ally doctrine (Pillar 3+4): the squad walks out weapons-tight and goes loud
	# with the player. Each man still defends himself if engaged (AllyBase).
	weapons_free = false
	for a in members:
		a.weapons_free = false
	# Medic revive hook.
	if world.player:
		_health = world.player.get_node_or_null("HealthSystem") as HealthSystem
		if _health:
			_health.revive_handler = self


## Every MOS carries a weapon. Rifle roles draw a random v3 grunt body so the squad
## looks like a mixed fireteam instead of seven identical action figures. Specialist
## roles (MG/GRENADIER/MARKSMAN/RTO) keep deterministic bodies for silhouette clarity.
const MOS_WEAPON: Dictionary = {
	"POINTMAN":  "m16a1",
	"RTO":       "m16a1",
	"MEDIC":     "m16a1",
	"MG":        "m60",
	"GRENADIER": "m79",
	"MARKSMAN":  "m70",
	"RIFLEMAN":  "m16a1",
}

const WEAPON_BODY_POOLS: Dictionary = {
	"m16a1": ["us_grunt_v3", "us_grunt_pointman", "us_grunt_rifleman"],
	"m60":   ["us_grunt_mg"],
	"m79":   ["us_grunt_grenadier"],
	"m70":   ["us_grunt_marksman"],
}

const DETERMINISTIC_MOS_BODY: Dictionary = {
	"RTO": "us_grunt_rto",
}


static func weapon_for_mos(mos: String) -> String:
	return MOS_WEAPON.get(mos, "m16a1")


static func pick_body_for_mos(mos: String, rng: RandomNumberGenerator) -> String:
	if DETERMINISTIC_MOS_BODY.has(mos):
		return str(DETERMINISTIC_MOS_BODY[mos])
	var weapon: String = weapon_for_mos(mos)
	var pool: Array = WEAPON_BODY_POOLS.get(weapon, ["us_grunt_v3"]) as Array
	if pool.is_empty():
		return "us_grunt_v3"
	return str(pool[rng.randi_range(0, pool.size() - 1)])


func _pick_unit_for_mos(mos: String) -> String:
	return pick_body_for_mos(mos, _roster_rng)


func member_by_mos(mos: String) -> AllyBase:
	for a in members:
		if is_instance_valid(a) and not a.is_dead() and str(a.member.get("mos", "")) == mos:
			return a
	return null


## ---------- ORDERS ----------

func _unhandled_input(event: InputEvent) -> void:
	if not GameManager.can_player_act() or director == null or director.is_ended():
		return
	if event.is_action_pressed("squad_follow"):
		_order_all(AllyBase.OrderMode.FOLLOW, Vector3.ZERO, "SQUAD: ON ME")
	elif event.is_action_pressed("squad_hold"):
		_order_all(AllyBase.OrderMode.HOLD, Vector3.ZERO, "SQUAD: HOLD POSITION")
	elif event.is_action_pressed("squad_move"):
		var target := _aim_ground_point()
		if target != Vector3.ZERO:
			_order_all(AllyBase.OrderMode.MOVE_TO, target, "SQUAD: MOVE THERE")
	elif event.is_action_pressed("squad_fire_toggle"):
		_auto_flip_armed = false
		_set_weapons_free(not weapons_free)


func _set_weapons_free(free: bool) -> void:
	weapons_free = free
	for a in members:
		if is_instance_valid(a):
			a.weapons_free = free
	director.toast.emit("SQUAD: WEAPONS %s" % ("FREE" if free else "TIGHT - HOLD FIRE"))
	VOManager.play_squad("weapons_free" if free else "weapons_tight")
	squad_changed.emit()


func _order_all(mode: AllyBase.OrderMode, pos: Vector3, toast_text: String) -> void:
	for a in members:
		if is_instance_valid(a) and not a.is_dead():
			a.set_order(mode, pos)
	director.toast.emit(toast_text)
	squad_changed.emit()


func _aim_ground_point() -> Vector3:
	if world.player == null:
		return Vector3.ZERO
	var cam: Camera3D = world.player.get_node("Head/Camera3D")
	var origin: Vector3 = cam.global_position
	var dir: Vector3 = -cam.global_transform.basis.z
	for i in range(1, 40):
		var p := origin + dir * (float(i) * 5.0)
		var ground: float = world.terrain_manager.get_height_at(p)
		if p.y <= ground:
			return Vector3(p.x, ground, p.z)
	return Vector3.ZERO


## ---------- MEDIC REVIVE CHAIN ----------

func can_revive() -> bool:
	return revives_left > 0 and member_by_mos("MEDIC") != null


func begin_revive(_health_system: HealthSystem) -> void:
	_reviving = true
	_revive_timer = 0.0
	_downed_clock = 0.0
	revives_left -= 1
	director.toast.emit("MAN DOWN! DOC IS MOVING TO YOU (%d revives left)" % revives_left)
	var _vo_doc := member_by_mos("MEDIC")
	if _vo_doc != null:
		VOManager.play_squad("man_down", {}, _vo_doc.global_position)
		VOManager.play_squad("doc_moving", _vo_doc.member, _vo_doc.global_position)


func _process_revive(delta: float) -> void:
	if not _reviving or _health == null:
		return
	var medic := member_by_mos("MEDIC")
	_downed_clock += delta
	if medic == null or _downed_clock >= HealthSystem.DOWNED_BLEED_SECONDS:
		_reviving = false
		director.toast.emit("DOC DIDN'T MAKE IT TO YOU.")
		_health.force_death()
		return
	var player := world.player
	medic.set_order(AllyBase.OrderMode.MOVE_TO, player.global_position)
	var dist: float = medic.global_position.distance_to(player.global_position)
	if dist <= 2.8:
		var medic_skill: int = SquadRoster.skill_level(medic.member, "medic")
		var channel: float = maxf(2.5, REVIVE_CHANNEL_SECONDS - float(medic_skill) * 0.4)
		_revive_timer += delta
		if _revive_timer >= channel:
			_reviving = false
			_health.revive()
			var mp: int = SquadRoster.credit_use(medic.member, "medic", 3)  # learn-by-doing
			if mp > 0:
				medic.on_skill_up("medic", mp)
			medic.set_order(AllyBase.OrderMode.FOLLOW)
			director.toast.emit("DOC: YOU'RE GOOD - ON YOUR FEET!")
			VOManager.play_squad("on_your_feet", medic.member, medic.global_position)
	else:
		_revive_timer = 0.0


## ---------- ROLE EFFECTS + BARKS ----------

func _physics_process(delta: float) -> void:
	_bark_cooldown = maxf(0.0, _bark_cooldown - delta)
	_thumper_cooldown = maxf(0.0, _thumper_cooldown - delta)
	if _auto_flip_armed and not weapons_free and WeaponHolder.session_shots > 0:
		_auto_flip_armed = false
		_set_weapons_free(true)
	_process_revive(delta)
	# Point scan on a 0.4s cadence, NOT 60Hz - it walks every lazy group + trap.
	_point_scan_timer += delta
	if _point_scan_timer >= 0.4:
		_point_scan_timer = 0.0
		_point_scan()
	# Same 0.4s gate for the grenadier: _grenadier_tick walks every enemy against
	# every OTHER enemy (an O(n^2) cluster search) - it must not run at 60Hz.
	_grenadier_timer += delta
	if _grenadier_timer >= 0.4:
		_grenadier_timer = 0.0
		_grenadier_tick()
	_contact_barks()


var _point_scan_timer: float = 0.0
var _grenadier_timer: float = 0.0


func _point_scan() -> void:
	var point := member_by_mos("POINTMAN")
	if point == null:
		return
	# Alertness (attribute) sets the base radius; the POINT man's Detect Ambush SKILL
	# extends it, so a trained scout calls movement much earlier.
	var det: int = SquadRoster.skill_level(point.member, "detect_ambush")
	var radius: float = 30.0 + float(int(point.member.get("al", 100))) * 0.15 + float(det) * 8.0
	for lg in get_tree().get_nodes_in_group("lazy_groups"):
		var group := lg as LazyGroup
		if group == null or _point_warned.has(group.get_instance_id()):
			continue
		if point.global_position.distance_to(group.global_position) <= radius:
			_point_warned[group.get_instance_id()] = true
			var pp: int = SquadRoster.credit_use(point.member, "detect_ambush", 2)  # learn-by-doing
			if pp > 0:
				point.on_skill_up("detect_ambush", pp)
			director.toast.emit("%s: HOLD UP - MOVEMENT AHEAD" % str(point.member.nick))
			VOManager.play_squad("movement_ahead", point.member, point.global_position)
	# Punji/trap spotting: harder than spotting men (60% radius), called out once.
	for t in get_tree().get_nodes_in_group("punji_traps"):
		var trap := t as Node3D
		if trap == null or _point_warned.has(trap.get_instance_id()):
			continue
		if point.global_position.distance_to(trap.global_position) <= radius * 0.6:
			_point_warned[trap.get_instance_id()] = true
			var tp: int = SquadRoster.credit_use(point.member, "detect_ambush", 2)
			if tp > 0:
				point.on_skill_up("detect_ambush", tp)
			director.toast.emit("%s: TRAP! WATCH YOUR STEP - SPIKES" % str(point.member.nick))


func _grenadier_tick() -> void:
	if _thumper_cooldown > 0.0 or not weapons_free:
		return
	var thumper := member_by_mos("GRENADIER")
	if thumper == null:
		return
	# Cluster: 3+ live enemies within 12m of each other, 30-80m from thumper.
	var enemies := get_tree().get_nodes_in_group("enemies")
	for e in enemies:
		var enemy := e as EnemyBase
		if enemy == null or enemy.is_dead():
			continue
		var d: float = thumper.global_position.distance_to(enemy.global_position)
		if d < 30.0 or d > 80.0:
			continue
		var cluster: int = 0
		for e2 in enemies:
			var other := e2 as EnemyBase
			if other and not other.is_dead() and other.global_position.distance_to(enemy.global_position) < 12.0:
				cluster += 1
		if cluster >= 3:
			_thumper_cooldown = 14.0
			var impact: Vector3 = enemy.global_position
			director.toast.emit("%s: THUMPER OUT!" % str(thumper.member.nick))
			VOManager.play_squad("thumper_out", thumper.member, thumper.global_position)
			get_tree().create_timer(1.2).timeout.connect(func() -> void:
				if world == null or not is_instance_valid(world) or not is_instance_valid(thumper):
					return
				CombatManager.apply_explosion_damage(
					impact, _thumper_damage(), _thumper_rim(), _thumper_radius(), thumper)
				GunFX.play_explosion_3d(world, impact)
				NoiseBus.emit_noise(NoiseBus.NoiseType.EXPLOSION, impact, 0))
			return


static func _thumper_round() -> ProjectileData:
	if _m79_he == null:
		_m79_he = load("res://data/projectiles/m79_he.tres") as ProjectileData
	return _m79_he


static func _thumper_damage() -> int:
	var round_data: ProjectileData = _thumper_round()
	return round_data.base_damage if round_data != null else FALLBACK_THUMPER_DAMAGE


static func _thumper_rim() -> int:
	return maxi(1, int(float(_thumper_damage()) * RIM_FRACTION))


static func _thumper_radius() -> float:
	var round_data: ProjectileData = _thumper_round()
	return round_data.aoe_radius if round_data != null else FALLBACK_THUMPER_RADIUS


var _last_combat_count: int = 0


func _contact_barks() -> void:
	if _bark_cooldown > 0.0:
		return
	var in_combat: int = 0
	for a in members:
		if is_instance_valid(a) and not a.is_dead() and a.current_state == Enums.AIState.COMBAT:
			in_combat += 1
	if in_combat > 0 and _last_combat_count == 0:
		_bark_cooldown = 8.0
		var caller: AllyBase = null
		for a in members:
			if is_instance_valid(a) and not a.is_dead():
				caller = a
				break
		if caller:
			director.toast.emit("%s: CONTACT!" % str(caller.member.nick))
			VOManager.play_squad("contact_front" if randf() < 0.5 else "contact", caller.member, caller.global_position)
	_last_combat_count = in_combat


## ---------- CASUALTIES ----------

func _on_member_died(ally: AllyBase) -> void:
	var m: Dictionary = ally.member
	m["alive"] = false
	director.state.flags["squad_kia"] = (director.state.flags.get("squad_kia", []) as Array) + [str(m.name)]
	director.toast.emit("KIA: %s %s (%s) - %d confirmed" % [SquadRoster.rank_for(m), str(m.name), str(m.nick), int(m.get("kills", 0))])
	CampaignState.save_campaign()
	squad_changed.emit()


func on_mission_end() -> void:
	for a in members:
		if is_instance_valid(a) and not a.is_dead():
			a.member["missions"] = int(a.member.get("missions", 0)) + 1
	CampaignState.save_campaign()
