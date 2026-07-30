## squad_system.gd - the player-led squad (SQUAD_SIZE) in every mission: spawning from the
## persistent roster, orders (F1-F4), medic revive chain, role effects, barks,
## casualty persistence.
class_name SquadSystem
extends Node

## DOC'S BAG, counted in BANDAGES. He spends them patching men up and the PLAYER can walk
## over and take from it, so the same number gates both. Running it dry is meant to be one
## of the reasons you go home (Summoner, 2026-07-30) - do not make it self-refilling.
const MEDIC_BANDAGES: int = 6
## What Doc carries besides the two he can spend reviving: the rest of the bag. Laying the
## box down puts ten on the ground for the whole squad AND the player.
const MEDIC_BOX_STOCK: int = 1
const GRENADIER_BOX_STOCK: int = 1
## How far ahead of a man his box lands, so it does not spawn inside him.
const BOX_DROP_M: float = 1.2
const REVIVE_CHANNEL_SECONDS: float = 5.0
## Player-led squad for the village assault: 5 specialists + riflemen (SquadRoster.SQUAD_SIZE).
const SQUAD_SIZE: int = 8

var world: GameWorld
var director: FieldDirector
var members: Array[AllyBase] = []
var weapons_free: bool = true
var medic_bandages: int = MEDIC_BANDAGES
## Boxes each specialist still has to lay. One apiece per mission - a box is a decision,
## not a consumable, and an infinite supply of them is an infinite supply of everything.
var medic_boxes: int = MEDIC_BOX_STOCK
var grenadier_boxes: int = GRENADIER_BOX_STOCK

var _reviving: bool = false
var _revive_timer: float = 0.0
var _downed_clock: float = 0.0
var _health: HealthSystem = null
var _bark_cooldown: float = 0.0
var _point_warned: Dictionary = {}
var _thumper_cooldown: float = 0.0
var _roster_rng := RandomNumberGenerator.new()
## MEDIC RESUPPLY. He sets a crate down on a clock OR when a real firefight ends, whichever
## comes first, and the clock restarts either way - the two are one cadence, not two.
const RESUPPLY_INTERVAL_S: float = 1200.0
## What counts as "a large firefight": this many of the squad in contact at once. Two men
## trading shots at a scout is not a reason to break out the crate.
const LARGE_FIREFIGHT_MEN: int = 3
var _resupply_clock: float = 0.0
var _combat_peak: int = 0
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
		# Same seat as the player: terrain height alone buries the squad under the
		# firebase mound when the spawn point sits inside the base.
		pos.y = world.surface_y(pos) + 0.5
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
		if mos == "RTO":
			_wire_rto_radio(ally)
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


## The squad RTO carries a live PRC-25: put him in group "radioman" so RadioMenu
## opens, build his handset rig (shared RadioHandset.attach_to), and bind it to the
## player's FP viewmodel/cord. The fire-support proximity path (field_director) is
## separate and already worked - this is what lets the player grab the handset.
func _wire_rto_radio(rto: AllyBase) -> void:
	rto.add_to_group("radioman")
	var handset: RadioHandset = RadioHandset.attach_to(rto)
	if handset != null and world != null and world.player != null:
		world.player.call("bind_radio_handset", handset)


## Benches and probes build a SquadSystem with no FieldDirector; the toast net
## is optional there, the squad AI is not — every bark routes through this.
func _toast(text: String) -> void:
	if director != null:
		director.toast.emit(text)


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
		_drop_ammo_box()
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
	_toast("SQUAD: WEAPONS %s" % ("FREE" if free else "TIGHT - HOLD FIRE"))
	VOManager.play_squad("weapons_free" if free else "weapons_tight")


func _order_all(mode: AllyBase.OrderMode, pos: Vector3, toast_text: String) -> void:
	for a in members:
		if is_instance_valid(a) and not a.is_dead():
			a.set_order(mode, pos)
	_toast(toast_text)


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
	if member_by_mos("MEDIC") == null:
		return false
	if medic_bandages > 0:
		return true
	# Dry, but standing next to bandages: Doc takes one rather than watching a man bleed.
	return _medic_restock()


## Doc pulls a bandage out of any medical box within reach. This is why running him dry is
## a state you can DO something about instead of a mission-long penalty.
func _medic_restock() -> bool:
	var medic := member_by_mos("MEDIC")
	if medic == null:
		return false
	var box: FieldCache = FieldCache.nearest(medic, FieldCache.Kind.MEDICAL, 6.0)
	if box == null or box.draw(1) <= 0:
		return false
	medic_bandages += 1
	_toast("DOC RESUPPLIED FROM THE MEDICAL BOX")
	return true


## Doc's box goes down WHERE HE TREATED SOMEONE, once per mission. An order was the wrong
## trigger: a medical box is not a decision, it is the bag he opened over a casualty, and
## leaving it there turns a place where something happened into a place worth finding again.
## No toast - the player discovers it, or he does not.
func _drop_medical_box() -> void:
	if medic_boxes <= 0:
		return
	var host: Node = get_tree().current_scene
	var medic := member_by_mos("MEDIC")
	if host == null or medic == null or not is_instance_valid(medic):
		return
	medic_boxes -= 1
	var at: Vector3 = medic.global_position - medic.global_transform.basis.z * BOX_DROP_M
	FieldCache.deploy(host, at, FieldCache.Kind.MEDICAL)


## The AMMO box stays on the order, and the difference is the point: laying out ammunition
## IS a decision - it is what a squad does when it has chosen to hold ground - where a
## medical box is just where the wounded man was.
func _drop_ammo_box() -> void:
	if grenadier_boxes <= 0:
		return
	var host: Node = get_tree().current_scene
	var gren := member_by_mos("GRENADIER")
	if host == null or gren == null or not is_instance_valid(gren):
		return
	grenadier_boxes -= 1
	var at: Vector3 = gren.global_position - gren.global_transform.basis.z * BOX_DROP_M
	FieldCache.deploy(host, at, FieldCache.Kind.AMMO)
	_toast("AMMO BOX DOWN")


## Hand ONE bandage to whoever asked. Doc gives until his bag is empty, and then the only
## bandages left in the world are the ones in a box or the ones back at the firebase.
func take_medic_bandage() -> bool:
	if medic_bandages <= 0:
		return false
	medic_bandages -= 1
	return true


func medic_bandage_count() -> int:
	return medic_bandages


func begin_revive(_health_system: HealthSystem) -> void:
	_reviving = true
	_revive_timer = 0.0
	_downed_clock = 0.0
	medic_bandages -= 1
	_toast("MAN DOWN! DOC IS MOVING TO YOU (%d bandages left)" % medic_bandages)
	# THE BAG COMES OFF HIS SHOULDER WHERE HE WORKS. Not on an order - this is the moment
	# he actually opens it, and it leaves something on the ground the player finds later.
	_drop_medical_box()
	var _vo_doc := member_by_mos("MEDIC")
	if _vo_doc != null:
		VOManager.play_squad("man_down", {}, _vo_doc.global_position)
		VOManager.play_squad("doc_moving", _vo_doc.member, _vo_doc.global_position)


## Getting shot while downed burns revive window (health_system routes body
## hits on a downed player here instead of killing him outright).
func pressure_revive(seconds: float) -> void:
	_downed_clock += seconds


func _process_revive(delta: float) -> void:
	if not _reviving or _health == null:
		return
	var medic := member_by_mos("MEDIC")
	_downed_clock += delta
	if medic == null or _downed_clock >= HealthSystem.DOWNED_BLEED_SECONDS:
		_reviving = false
		if medic != null:
			medic.set_order(AllyBase.OrderMode.FOLLOW)  # never leave RESCUE latched
		_toast("DOC DIDN'T MAKE IT TO YOU.")
		_health.force_death()
		return
	var player := world.player
	medic.set_order(AllyBase.OrderMode.RESCUE, player.global_position)
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
			_toast("DOC: YOU'RE GOOD - ON YOUR FEET!")
			VOManager.play_squad("on_your_feet", medic.member, medic.global_position)
	else:
		_revive_timer = 0.0


## ---------- ROLE EFFECTS + BARKS ----------

func _physics_process(delta: float) -> void:
	_bark_cooldown = maxf(0.0, _bark_cooldown - delta)
	_thumper_cooldown = maxf(0.0, _thumper_cooldown - delta)
	_resupply_clock += delta
	if _resupply_clock >= RESUPPLY_INTERVAL_S:
		_medic_resupply()
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
	_update_break()


## ---- squad strength & break (4utx) ----------------------------------------
## Same rule both sides: the threshold, the courage modulation and the 1s cadence
## all come from EnemySquad.break_state - there is ONE break authority, and the
## player's squad is judged by it exactly as an NVA squad is. What differs is only
## the effect: allies have no RETREAT goal, so the flag biases the goals they DO
## have (cover-first, no closing, wider stand-off) in AllyBase.
var squad_broken: bool = false
var _peak_strength: int = 0
var _break_ms: float = -1e9


func _update_break() -> void:
	var now: float = float(Time.get_ticks_msec())
	if now - _break_ms < EnemySquad.STRENGTH_TTL_MS:
		return
	_break_ms = now
	var live: int = 0
	var courage_sum: float = 0.0
	for a in members:
		if a != null and is_instance_valid(a) and not a.is_dead():
			live += 1
			courage_sum += a.courage
	_peak_strength = maxi(_peak_strength, live)
	var bs: Dictionary = EnemySquad.break_state(live, _peak_strength,
		courage_sum / float(maxi(1, live)))
	var was: bool = squad_broken
	squad_broken = bool(bs.broken)
	for a in members:
		if a != null and is_instance_valid(a) and not a.is_dead():
			a.squad_broken = squad_broken
	if squad_broken != was:
		_toast("SQUAD COMBAT INEFFECTIVE - BREAKING CONTACT" if squad_broken \
			else "SQUAD BACK IN THE FIGHT")


var _point_scan_timer: float = 0.0
var _grenadier_timer: float = 0.0


## Alertness (attribute) sets the base radius; the POINT man's Detect Ambush SKILL
## extends it, so a trained scout calls movement much earlier. Read-only - the HUD
## reads the same number the scan uses, so the two can never disagree.
func point_scan_radius() -> float:
	var point := member_by_mos("POINTMAN")
	if point == null:
		return 0.0
	var det: int = SquadRoster.skill_level(point.member, "detect_ambush")
	return 30.0 + float(int(point.member.get("al", 100))) * 0.15 + float(det) * 8.0


func _point_scan() -> void:
	var point := member_by_mos("POINTMAN")
	if point == null:
		return
	var radius: float = point_scan_radius()
	for lg in get_tree().get_nodes_in_group("lazy_groups"):
		var group := lg as LazyGroup
		if group == null or _point_warned.has(group.get_instance_id()):
			continue
		if point.global_position.distance_to(group.global_position) <= radius:
			_point_warned[group.get_instance_id()] = true
			var pp: int = SquadRoster.credit_use(point.member, "detect_ambush", 2)  # learn-by-doing
			if pp > 0:
				point.on_skill_up("detect_ambush", pp)
			_toast("%s: HOLD UP - MOVEMENT AHEAD" % SquadRoster.call_name(point.member))
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
			_toast("%s: TRAP! WATCH YOUR STEP - SPIKES" % SquadRoster.call_name(point.member))


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
			_toast("%s: THUMPER OUT!" % SquadRoster.call_name(thumper.member))
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
		if is_instance_valid(a) and not a.is_dead() and a.current_state in [Enums.AIState.COMBAT, Enums.AIState.ADVANCING, Enums.AIState.SUPPRESSED]:
			in_combat += 1
	if in_combat > 0 and _last_combat_count == 0:
		_bark_cooldown = 8.0
		var caller: AllyBase = null
		for a in members:
			if is_instance_valid(a) and not a.is_dead():
				caller = a
				break
		if caller:
			_toast("%s: CONTACT!" % SquadRoster.call_name(caller.member))
			VOManager.play_squad("contact_front" if randf() < 0.5 else "contact", caller.member, caller.global_position)
	# Peak, not current: a firefight is judged by how many men it pulled in at its worst,
	# and that number is gone by the time the shooting stops.
	_combat_peak = maxi(_combat_peak, in_combat)
	if in_combat == 0 and _last_combat_count > 0:
		if _combat_peak >= LARGE_FIREFIGHT_MEN:
			_medic_resupply()
		_combat_peak = 0
	_last_combat_count = in_combat


## The medic puts a crate down at his feet and calls it. Restarts the clock whichever
## reason fired, so a firefight resupply does not leave a timer about to fire again.
func _medic_resupply() -> void:
	_resupply_clock = 0.0
	var medic: AllyBase = member_by_mos("MEDIC")
	if medic == null or get_tree() == null:
		return
	var host: Node = get_tree().current_scene
	if host == null:
		return
	MedicalCrate.drop(host, medic.global_position)
	_toast("%s: BANDAGES OVER HERE!" % SquadRoster.call_name(medic.member))
	VOManager.play_squad("bandages_over_here", medic.member, medic.global_position)


## ---------- CASUALTIES ----------

func _on_member_died(ally: AllyBase) -> void:
	var m: Dictionary = ally.member
	m["alive"] = false
	if director != null:
		director.state.flags["squad_kia"] = (director.state.flags.get("squad_kia", []) as Array) + [str(m.name)]
	var nick: String = SquadRoster.earned_nick(m)
	_toast("KIA: %s %s%s - %d confirmed" % [SquadRoster.rank_for(m), str(m.name),
		(" \"%s\"" % nick) if nick != "" else "", int(m.get("kills", 0))])
	CampaignState.save_campaign()


func on_mission_end() -> void:
	for a in members:
		if is_instance_valid(a) and not a.is_dead():
			a.member["missions"] = int(a.member.get("missions", 0)) + 1
			if SquadRoster.christen(a.member):
				_toast("THE MEN HAVE STARTED CALLING %s \"%s\"" % [
					str(a.member.get("name", "")), str(a.member.get("nick", ""))])
	CampaignState.save_campaign()
