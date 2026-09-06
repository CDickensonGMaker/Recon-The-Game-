## squad_system.gd - the player-led squad (SQUAD_SIZE) in every mission: spawning from the
## persistent roster, orders (F1-F4), medic revive chain, role effects, barks,
## casualty persistence.
class_name SquadSystem
extends Node

## DOC'S BAG, counted in BANDAGES. He spends them patching men up and the PLAYER can walk
## over and take from it, so the same number gates both. Running it dry is meant to be one
## of the reasons you go home (Summoner, 2026-07-30) - do not make it self-refilling.
const MEDIC_BANDAGES: int = 6
## THE GUNNER'S SPARE BELTS, counted in 100-ROUND BELTS (ruling A4, 2026-08-24: ~8 draws).
## Same law as Doc's bag: the player takes from it, it never self-refills beyond the ammo
## box, and his corpse gives up whatever is left.
const MG_BELTS: int = 8
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
var mg_belts: int = MG_BELTS
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
		var a := TAU * float(i) / float(squad_n)
		var pos := spawn_pos + Vector3(cos(a), 0, sin(a)) * 3.5
		_stand_up_member(roster[i], pos, i + 1)
	# SPAWN PEN PROBE (his playtest 2026-08-04: squad "stuck by collision boxes").
	# Four 0.6m test moves per man; 4/4 blocked = he spawned inside a pen. The ring
	# sits around an INDOOR cot, so wall/prop colliders are the prime suspect.
	for a3 in members:
		var probe := a3 as AllyBase
		if probe == null:
			continue
		var blocked: int = 0
		for dirv: Vector3 in [Vector3(0.6, 0, 0), Vector3(-0.6, 0, 0),
				Vector3(0, 0, 0.6), Vector3(0, 0, -0.6)]:
			if probe.test_move(probe.global_transform, dirv):
				blocked += 1
		print("[SQUAD] spawn %s at (%.1f, %.1f, %.1f) - %d/4 dirs blocked" % [
			str(probe.member.get("mos", "?")), probe.global_position.x,
			probe.global_position.y, probe.global_position.z, blocked])
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


## THE ONE PLACE A SQUADMATE IS STOOD UP. setup() walks the roster through here at dawn
## and the replacement bird walks its FNGs through the same door - there is no second
## spawn path for a squad member to drift away from (ADR-023).
##
## floor_y, from the BUNK'S authored height: surface_y's top-down ray put the whole squad
## on the hootch ROOF, off the navmesh, where no order could ever move them (his playtest,
## 2026-08-04: "my squad never follows me").
func _stand_up_member(m: Dictionary, pos: Vector3, slot: int) -> AllyBase:
	pos.y = world.floor_y(pos) + 0.5
	var ally := AllyBase.spawn_ally(world, pos)
	ally.member = m
	ally.director = director  ## toast channel for promotion barks
	var mos: String = str(m.mos)
	# MOS-weighted courage (decree 2026-08-03 §2.11 item 2): the flat ambient roll let
	# the RTO play hero ~25% of the time and skip the cover trip (ally_base.gd:106-109).
	# The RTO/MEDIC caps sit under the 0.75 go-getter bar, so the men the squad cannot
	# afford to spend always take cover first.
	var band: Vector2 = MOS_COURAGE.get(mos, Vector2(0.25, 0.85)) as Vector2
	ally.courage = _roster_rng.randf_range(band.x, band.y)
	var unit: String = _pick_unit_for_mos(mos)
	var weapon: String = MOS_WEAPON.get(mos, "m16a1")
	if mos == "MG":
		ally.fire_rate_mult = 1.6
	# spawn_ally() already ran _setup_visual(), so this rebuilds it.
	ally.set_sprite(unit, weapon)
	# Explicit: he wears his roster face/helmet whether or not set_sprite
	# rebuilt (the default-body draw early-returns and would keep bench paint).
	ally.dress_visual()
	ally.file_slot = slot
	ally.point_slot = mos == "POINTMAN"
	ally.died.connect(_on_member_died)
	if mos == "RTO":
		_wire_rto_radio(ally)
	members.append(ally)
	return ally


## THE REPLACEMENT BIRD PUTS MEN IN THE SQUAD (Summoner, 2026-08-28: "i like replacements
## by bird"). HeliLift calls this at the pad, once the wheels are down and the men have
## stepped off. The dicts are already on CampaignState.roster - this is the body, not the
## paperwork - and each man inherits the squad's current weapons posture so an arrival
## during a stand-to does not walk in weapons-tight while everyone else is firing.
func receive_replacements(fresh: Array, at: Vector3) -> int:
	if world == null or not is_instance_valid(world) or fresh.is_empty():
		return 0
	var n: int = 0
	for entry in fresh:
		var m: Dictionary = entry as Dictionary
		if m.is_empty():
			continue
		var a: float = TAU * float(n) / float(maxi(1, fresh.size()))
		var ally: AllyBase = _stand_up_member(m, at + Vector3(cos(a), 0.0, sin(a)) * 2.4,
			members.size() + 1)
		if ally == null:
			continue
		ally.weapons_free = weapons_free
		n += 1
	if n > 0:
		_toast("%d REPLACEMENT%s ON THE GROUND - GET THEM SQUARED AWAY"
			% [n, "" if n == 1 else "S"])
	return n


## Every MOS carries a weapon. Rifle roles draw a random v3 grunt body so the squad
## looks like a mixed fireteam instead of seven identical action figures. Specialist
## roles (MG/GRENADIER/MARKSMAN/RTO) keep deterministic bodies for silhouette clarity.
## Courage band per MOS, sampled by the roster RNG (ADR-010: same seed, same men).
## ally_base.wants_cover_first: >= 0.75 skips the cover trip; < 0.35 anchors on his rock.
const MOS_COURAGE: Dictionary = {
	"POINTMAN":  Vector2(0.5, 0.95),
	"RTO":       Vector2(0.1, 0.55),
	"MEDIC":     Vector2(0.15, 0.6),
	"MG":        Vector2(0.45, 0.95),
	"GRENADIER": Vector2(0.3, 0.8),
	"MARKSMAN":  Vector2(0.3, 0.8),
	"RIFLEMAN":  Vector2(0.25, 0.9),
}

const MOS_WEAPON: Dictionary = {
	"POINTMAN":  "m16a1",
	"RTO":       "m16a1",
	"MEDIC":     "m16a1",
	"MG":        "m60",
	"GRENADIER": "m79",
	"MARKSMAN":  "m70",
	"RIFLEMAN":  "m16a1",
}

## us_grunt_v3 was RETIRED 2026-08-04. It was the July base body and it was the fallback
## in five places, so any lookup that missed quietly handed back the old model. The six
## role bodies below are the whole allied US cast now.
const WEAPON_BODY_POOLS: Dictionary = {
	"m16a1": ["us_grunt_pointman", "us_grunt_rifleman"],
	"m60":   ["us_grunt_mg"],
	"m79":   ["us_grunt_grenadier"],
	"m70":   ["us_grunt_marksman"],
}

## A medic who spawns as a rifleman is a medic nobody can pick out of a firefight -
## and us_medic.glb existed for weeks while MEDIC fell through to the generic pool.
const DETERMINISTIC_MOS_BODY: Dictionary = {
	"RTO":   "us_grunt_rto",
	"MEDIC": "us_medic",
}

## Every miss lands here. It must be a body that ships.
const FALLBACK_BODY: String = "us_grunt_rifleman"


static func weapon_for_mos(mos: String) -> String:
	return MOS_WEAPON.get(mos, "m16a1")


static func pick_body_for_mos(mos: String, rng: RandomNumberGenerator) -> String:
	if DETERMINISTIC_MOS_BODY.has(mos):
		return str(DETERMINISTIC_MOS_BODY[mos])
	var weapon: String = weapon_for_mos(mos)
	var pool: Array = WEAPON_BODY_POOLS.get(weapon, [FALLBACK_BODY]) as Array
	if pool.is_empty():
		return FALLBACK_BODY
	return str(pool[rng.randi_range(0, pool.size() - 1)])


func _pick_unit_for_mos(mos: String) -> String:
	return pick_body_for_mos(mos, _roster_rng)


## The squad RTO carries a live PRC-25: put him in group "radioman" so the player's
## [F] passes the handset instantly, build his handset rig (shared
## RadioHandset.attach_to), and bind it to the player's FP viewmodel/cord. The
## fire-support proximity path (field_director) is separate and already worked -
## this is what lets the player grab the handset.
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


## A dead ally is queue_free'd 45s later (ally_base.gd:2273) and nothing ever took
## him out of this array, so `members` accumulated dangling references for the rest
## of the mission. Any consumer that dereferences an element before validating it
## reads freed memory - field_director._danger_close_to_squad did exactly that.
func _prune_freed() -> void:
	for i in range(members.size() - 1, -1, -1):
		if not is_instance_valid(members[i]):
			members.remove_at(i)


## Squad-level calls only (an order, a break) - anything a MAN perceives is spoken
## by that man from ally_base.gd instead.
func _first_living() -> AllyBase:
	for a in members:
		if is_instance_valid(a) and not a.is_dead():
			return a
	return null


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
		_order_all(AllyBase.OrderMode.FOLLOW, Vector3.ZERO, "SQUAD: ON ME", "on_me")
	elif event.is_action_pressed("squad_hold"):
		_order_all(AllyBase.OrderMode.HOLD, Vector3.ZERO, "SQUAD: HOLD POSITION")
		_drop_ammo_box()
	elif event.is_action_pressed("squad_move"):
		var target := _aim_ground_point()
		if target != Vector3.ZERO:
			_order_all(AllyBase.OrderMode.MOVE_TO, target, "SQUAD: MOVE THERE", "moving")
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


func _order_all(mode: AllyBase.OrderMode, pos: Vector3, toast_text: String,
		ack_line: String = "") -> void:
	for a in members:
		if is_instance_valid(a) and not a.is_dead():
			a.set_order(mode, pos)
	_toast(toast_text)
	var ack: AllyBase = _first_living()
	if ack_line != "" and ack != null:
		VOManager.play_squad(ack_line, ack.member, ack.global_position)


func _aim_ground_point() -> Vector3:
	if world.player == null:
		return Vector3.ZERO
	var cam: Camera3D = world.player.get_node("Head/Camera3D")
	var origin: Vector3 = cam.global_position
	var dir: Vector3 = -cam.global_transform.basis.z
	for i in range(1, 40):
		var p := origin + dir * (float(i) * 5.0)
		var ground: float = world.surface_y(p)
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


## The gunner pulls a belt off any AMMO box within reach, capped at his carry -
## Doc's restock, pointed at the ammo box.
func _gunner_restock() -> bool:
	if mg_belts >= MG_BELTS:
		return false
	var gunner := member_by_mos("MG")
	if gunner == null:
		return false
	var box: FieldCache = FieldCache.nearest(gunner, FieldCache.Kind.AMMO, 6.0)
	if box == null or box.draw(1) <= 0:
		return false
	mg_belts += 1
	_toast("GUNNER PULLED A BELT FROM THE AMMO BOX")
	return true


## Dry, but standing next to an ammo box: he takes one rather than turning the
## player away (can_revive's law).
func can_hand_belt() -> bool:
	if mg_belts > 0:
		return true
	return _gunner_restock()


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


## Hand ONE full belt to whoever asked. The gunner gives until his back is bare.
func take_mg_belt() -> bool:
	if mg_belts <= 0:
		return false
	mg_belts -= 1
	return true


func mg_belt_count() -> int:
	return mg_belts


func begin_revive(_health_system: HealthSystem) -> void:
	_reviving = true
	_revive_timer = 0.0
	_downed_clock = 0.0
	medic_bandages -= 1
	_toast("MAN DOWN - DOC IS MOVING TO YOU (%d BANDAGES LEFT)" % medic_bandages)
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
			medic.set_performance("")
		_toast("DOC DIDN'T MAKE IT TO YOU")
		_health.force_death()
		return
	var player := world.player
	medic.set_order(AllyBase.OrderMode.RESCUE, player.global_position)
	var dist: float = medic.global_position.distance_to(player.global_position)
	if dist <= 2.8:
		var medic_skill: int = SquadRoster.skill_level(medic.member, "medic")
		var channel: float = maxf(2.5, REVIVE_CHANNEL_SECONDS - float(medic_skill) * 0.4)
		medic.set_performance("medic_treat_give")
		_revive_timer += delta
		if _revive_timer >= channel:
			_reviving = false
			medic.set_performance("")
			_health.revive()
			var mp: int = SquadRoster.credit_use(medic.member, "medic", 3)  # learn-by-doing
			if mp > 0:
				medic.on_skill_up("medic", mp)
			medic.set_order(AllyBase.OrderMode.FOLLOW)
			_toast("DOC: YOU'RE GOOD - ON YOUR FEET!")
			VOManager.play_squad("on_your_feet", medic.member, medic.global_position)
	else:
		# He walked off mid-channel: release the pose or he carries it across the map.
		medic.set_performance("")
		_revive_timer = 0.0


## ---------- ROLE EFFECTS + BARKS ----------

func _physics_process(delta: float) -> void:
	_prune_freed()
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
	_catchup_timer += delta
	if _catchup_timer >= CATCHUP_TICK_S:
		_catchup_timer = 0.0
		_catchup_tick()
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
		if squad_broken:
			var caller: AllyBase = _first_living()
			# global_position on a man who is not in the tree returns identity AND prints an
			# engine error, so the fall-back call would place itself at the world origin.
			# Reachable for real during teardown, when a member is freed between the roster
			# scan and this line.
			if caller != null and caller.is_inside_tree():
				VOManager.play_squad("fall_back", caller.member, caller.global_position, true)


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


## ---- FOLLOW catch-up teleport ----
const CATCHUP_TICK_S: float = 1.0
const CATCHUP_TELEPORT_M: float = 40.0
const CATCHUP_UNSEEN_M: float = 25.0
const CATCHUP_CALM_S: float = 5.0
const CATCHUP_MAX_PER_TICK: int = 2
const CATCHUP_CLAMP_MAX_M: float = 12.0
const CATCHUP_BASE_GAP_M: float = 6.0
const CATCHUP_SLOT_STEP_M: float = 1.5
var _catchup_timer: float = 0.0


## A FOLLOW man the player cannot see and cannot catch by walking (CATCHUP_MULT
## loses to sprint) is MOVED behind him. Never fires in combat, on a seated man,
## or while the player is seated; at most CATCHUP_MAX_PER_TICK per tick so eight
## men never pop the same frame.
func _catchup_tick() -> void:
	if not GameManager.can_player_act():
		return
	if world == null or world.player == null or not is_instance_valid(world.player):
		return
	var p: CharacterBody3D = world.player
	if p.get("is_seated") == true:
		return
	var cam: Camera3D = get_viewport().get_camera_3d()
	var back: Vector3 = p.global_transform.basis.z
	back.y = 0.0
	var behind: Vector3 = back.normalized() if back.length() > 0.1 else Vector3.BACK
	var moved: int = 0
	for a in members:
		if a == null or not is_instance_valid(a) or a.is_dead():
			continue
		if not a.squad_member or a.order_mode != AllyBase.OrderMode.FOLLOW:
			continue
		if a.target != null or a.target_last_seen_time <= CATCHUP_CALM_S:
			continue
		if not a.is_physics_processing():  # seated: SeatSystem froze him
			continue
		var dist: float = a.global_position.distance_to(p.global_position)
		var unseen: bool = cam != null and cam.is_position_behind(a.global_position)
		if dist <= CATCHUP_TELEPORT_M and not (dist > CATCHUP_UNSEEN_M and unseen):
			continue
		var dest: Vector3 = p.global_position \
			+ behind * (CATCHUP_BASE_GAP_M + CATCHUP_SLOT_STEP_M * float(a.file_slot))
		dest = _catchup_ground(a, dest)
		a.global_position = dest
		a.velocity = Vector3.ZERO
		a.reset_physics_interpolation()
		a.reset_follow_slot()
		moved += 1
		if moved >= CATCHUP_MAX_PER_TICK:
			return


## Nav-clamp ONLY inside a baked box - the nearest-point query on open country
## returns the FAR firebase mesh and would teleport the man back to the wire.
func _catchup_ground(a: AllyBase, dest: Vector3) -> Vector3:
	if WorldConfig.NAV_ENABLED and NavBaker.box_index_at(dest) >= 0 and a.nav_agent != null:
		var map: RID = a.nav_agent.get_navigation_map()
		if map.is_valid() and NavigationServer3D.map_get_iteration_id(map) > 0:
			var clamped: Vector3 = NavigationServer3D.map_get_closest_point(map, dest)
			if dest.distance_to(clamped) < CATCHUP_CLAMP_MAX_M:
				dest = clamped
	var w3d: World3D = a.get_world_3d()
	if w3d != null:
		var query := PhysicsRayQueryParameters3D.create(
			dest + Vector3.UP * 2.0, dest + Vector3.DOWN * 8.0, 1)
		var hit: Dictionary = w3d.direct_space_state.intersect_ray(query)
		if not hit.is_empty():
			var hp: Vector3 = hit.position
			dest.y = hp.y + 0.5
			return dest
	dest.y = world.floor_y(dest) + 0.5
	return dest


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
		var caller: AllyBase = _first_living()
		if caller:
			_toast("%s: CONTACT!" % SquadRoster.call_name(caller.member))
	# Peak, not current: a firefight is judged by how many men it pulled in at its worst,
	# and that number is gone by the time the shooting stops.
	_combat_peak = maxi(_combat_peak, in_combat)
	if in_combat == 0 and _last_combat_count > 0:
		var last_man: AllyBase = _first_living()
		if last_man != null:
			VOManager.play_squad("clear", last_man.member, last_man.global_position)
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


## ---------- CASUALTIES ----------

func _on_member_died(ally: AllyBase) -> void:
	var m: Dictionary = ally.member
	m["alive"] = false
	if director != null:
		director.state.flags["squad_kia"] = (director.state.flags.get("squad_kia", []) as Array) + [str(m.name)]
	var nick: String = SquadRoster.earned_nick(m)
	_toast("KIA: %s %s%s - %d confirmed" % [SquadRoster.rank_for(m), str(m.name),
		(" \"%s\"" % nick) if nick != "" else "", int(m.get("kills", 0))])
	if str(m.get("mos", "")) == "RTO":
		_hand_off_radio(ally)
	CampaignState.save_campaign()


## THE RADIO IS AN OBJECT, NOT A MAN (his ruling, 2026-08-03: "IF the RTO guy dies we
## should be able to have someone else pick it up. than they turn into the RTO guy. so
## when the squads dead no more radio").
##
## Everything downstream resolves the net through `member_by_mos("RTO")` - the radio
## check, the VO source, the allotment, the fire request. So the handoff is done by
## REASSIGNING THE MOS rather than by teaching eight call sites about a handset: the man
## who takes it IS the RTO, at full quality, with no sloppy-rounds penalty.
##
## This supersedes ADR-011's "the radio is a man" for the squad's own net. Fire support
## still dies - it dies with the SQUAD, which is the point.
func _hand_off_radio(fallen: AllyBase) -> void:
	# A dead man left in the radioman group is a lie the group probe cannot see through.
	if fallen.is_in_group("radioman"):
		fallen.remove_from_group("radioman")
	# THE MEDIC NEVER INHERITS (his ruling 2026-08-04, Q1: "medics cant pick up radio, and
	# riflemen should be first to pick it up"). A medic-heir silently deletes revive for the
	# rest of the run - the radio is not worth the aid bag. Riflemen first; any other
	# non-medic specialist only when no rifleman is left standing.
	var heir: AllyBase = null
	var fallback: AllyBase = null
	var best: float = 1.0e9
	var best_fallback: float = 1.0e9
	for a in members:
		if not is_instance_valid(a) or a.is_dead() or a == fallen:
			continue
		var mos: String = str(a.member.get("mos", ""))
		if mos == "RTO":
			return   # a second radioman is already carrying it
		if mos == "MEDIC":
			continue
		# Nearest living man to the body: he is the one who could actually reach it.
		var d: float = a.global_position.distance_to(fallen.global_position)
		if mos == "RIFLEMAN":
			if d < best:
				best = d
				heir = a
		elif d < best_fallback:
			best_fallback = d
			fallback = a
	if heir == null:
		heir = fallback
	if heir == null:
		_toast("THE RADIO IS GONE - NOBODY LEFT TO CARRY IT")
		return
	heir.member["mos"] = "RTO"
	_wire_rto_radio(heir)
	_toast("%s HAS THE RADIO NOW" % SquadRoster.call_name(heir.member))


func on_mission_end() -> void:
	for a in members:
		if is_instance_valid(a) and not a.is_dead():
			a.member["missions"] = int(a.member.get("missions", 0)) + 1
			if SquadRoster.christen(a.member):
				_toast("THE MEN HAVE STARTED CALLING %s \"%s\"" % [
					str(a.member.get("name", "")), str(a.member.get("nick", ""))])
	CampaignState.save_campaign()
