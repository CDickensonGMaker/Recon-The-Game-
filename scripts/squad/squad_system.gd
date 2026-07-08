## squad_system.gd - The 5-man squad in every mission (W13-W24): spawning from
## the persistent roster, orders (F1-F4), medic revive chain, role effects,
## barks, casualty persistence.
class_name SquadSystem
extends Node

signal squad_changed

const REVIVES_PER_MISSION: int = 2
const REVIVE_CHANNEL_SECONDS: float = 5.0

var world: GameWorld
var director: MissionDirector
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


func setup(game_world: GameWorld, mission_director: MissionDirector, spawn_pos: Vector3) -> void:
	world = game_world
	director = mission_director
	var roster: Array = SquadRoster.ensure_roster(int(director.state.seed_value) + 12345)
	for i in range(mini(5, roster.size())):
		var m: Dictionary = roster[i]
		var a := TAU * float(i) / 5.0
		var pos := spawn_pos + Vector3(cos(a), 0, sin(a)) * 3.0
		pos.y = world.terrain_manager.get_height_at(pos) + 0.5
		var ally := AllyBase.spawn_ally(world, pos)
		ally.member = m
		if str(m.mos) == "PIGMAN":
			ally.fire_rate_mult = 1.6
			# The Pig is a separate rendered unit: us_grunt_black holds the M60.
			# spawn_ally() already ran _setup_visual(), so this must rebuild.
			ally.set_sprite("us_grunt_black", "m60")
		_attach_name_tag(ally, "%s (%s)" % [str(m.nick), str(m.mos)])
		ally.died.connect(_on_member_died)
		members.append(ally)
	# Medic revive hook.
	if world.player:
		_health = world.player.get_node_or_null("HealthSystem") as HealthSystem
		if _health:
			_health.revive_handler = self


func _attach_name_tag(ally: Node3D, text: String) -> void:
	var tag := Label3D.new()
	tag.text = text
	tag.font_size = 22
	tag.pixel_size = 0.004
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.modulate = Color(0.7, 0.85, 0.6)
	tag.position = Vector3(0, 2.2, 0)
	ally.add_child(tag)


func member_by_mos(mos: String) -> AllyBase:
	for a in members:
		if is_instance_valid(a) and not a.is_dead() and str(a.member.get("mos", "")) == mos:
			return a
	return null


func is_rto_alive() -> bool:
	return member_by_mos("RTO") != null


## ---------- ORDERS (W15) ----------

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
		weapons_free = not weapons_free
		for a in members:
			if is_instance_valid(a):
				a.weapons_free = weapons_free
		director.toast.emit("SQUAD: WEAPONS %s" % ("FREE" if weapons_free else "TIGHT - HOLD FIRE"))


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


## ---------- MEDIC REVIVE CHAIN (W17) ----------

func can_revive() -> bool:
	return revives_left > 0 and member_by_mos("MEDIC") != null


func begin_revive(_health_system: HealthSystem) -> void:
	_reviving = true
	_revive_timer = 0.0
	_downed_clock = 0.0
	revives_left -= 1
	director.toast.emit("MAN DOWN! DOC IS MOVING TO YOU (%d revives left)" % revives_left)


## PT2: first revive of the mission patches you to FULL; the second is field-dressing.
func _revive_heal_amount(medic_skill: int) -> int:
	if revives_left == REVIVES_PER_MISSION - 1:
		return 999  # clamped to max_hp by HealthSystem.revive
	return 40 + medic_skill * 5


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
			var heal: int = _revive_heal_amount(medic_skill)
			_health.revive(heal)
			medic.set_order(AllyBase.OrderMode.FOLLOW)
			director.toast.emit("DOC: YOU'RE GOOD - ON YOUR FEET!")
	else:
		_revive_timer = 0.0


## ---------- ROLE EFFECTS + BARKS (W18/W20/W21) ----------

func _physics_process(delta: float) -> void:
	_bark_cooldown = maxf(0.0, _bark_cooldown - delta)
	_thumper_cooldown = maxf(0.0, _thumper_cooldown - delta)
	_process_revive(delta)
	_point_scan()
	_grenadier_tick()
	_contact_barks()


var _point_scan_timer: float = 0.0


func _point_scan() -> void:
	var point := member_by_mos("POINT")
	if point == null:
		return
	var radius: float = 30.0 + float(int(point.member.get("al", 100))) * 0.15
	for lg in get_tree().get_nodes_in_group("lazy_groups"):
		var group := lg as LazyGroup
		if group == null or _point_warned.has(group.get_instance_id()):
			continue
		if point.global_position.distance_to(group.global_position) <= radius:
			_point_warned[group.get_instance_id()] = true
			director.toast.emit("%s: HOLD UP - MOVEMENT AHEAD" % str(point.member.nick))


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
			get_tree().create_timer(1.2).timeout.connect(func() -> void:
				CombatManager.apply_explosion_damage(impact, 90, 25, 7.0, thumper)
				GunFX.play_explosion_3d(world, impact)
				NoiseBus.emit_noise(NoiseBus.NoiseType.EXPLOSION, impact, 0))
			return


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
	_last_combat_count = in_combat


## ---------- CASUALTIES (W24) ----------

func _on_member_died(ally: AllyBase) -> void:
	var m: Dictionary = ally.member
	m["alive"] = false
	director.state.flags["squad_kia"] = (director.state.flags.get("squad_kia", []) as Array) + [str(m.name)]
	director.toast.emit("%s IS DOWN - %s KIA" % [str(m.nick), str(m.name)])
	CampaignState.save_campaign()
	squad_changed.emit()


func on_mission_end() -> void:
	for a in members:
		if is_instance_valid(a) and not a.is_dead():
			a.member["missions"] = int(a.member.get("missions", 0)) + 1
	CampaignState.save_campaign()
