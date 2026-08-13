## ambient_encounters.gd - The walking dice (his decree 2026-08-07): distance
## travelled outside the wire is the pacing engine - every ROLL_EVERY_M walked,
## one roll may stage ONE ambient encounter. Three kinds: VC leaning on the
## ville, a friendly element passing through, a friendly element stuck in a
## real firefight. Never two at once, never during the siege, never at night,
## never inside the first ten minutes, and the pilot chain counts as a live
## encounter (the exclusivity gate is two-way with PilotRecovery).
##
## Sites and routes are seed-fixed at attach, drawn AFTER every existing plan
## draw (the ambient-AA split, mission_generator.gd:822-843); the dice and the
## player-relative picks are unseeded ambient life, the documented exemption
## (demo_game.gd:9-11, pilot_recovery.gd:35-37).
class_name AmbientEncounters
extends Node

## ---- Pacing knobs, the Summoner's to retune ----
## Meters walked outside the wire per dice roll. Standing still rolls nothing.
const ROLL_EVERY_M: float = 65.0
const EVENT_CHANCE: float = 0.35
## Same find-your-feet hold as CampMortar.HOLD_FIRE_S / PilotRecovery.HOLD_FIRE_S.
const HOLD_S: float = 600.0
## Gap after one encounter ends before the dice arm again.
const COOLDOWN_S: float = 240.0
## Per-type ceiling for the one demo day. No reset - the demo is one day.
const DAY_CAPS: Dictionary = {"harass": 1, "patrol": 2, "contact": 1}
const MAX_LIVE_S: Dictionary = {"harass": 300.0, "patrol": 360.0, "contact": 420.0}

## The parapet reaches 96.1m radius (demo_game.gd:413-418) - outside this is
## "outside the wire" for the walk meter.
const WIRE_M: float = 110.0

const HARASS_MEN: int = 3
const PATROL_MEN: int = 4
const CONTACT_ALLIES: int = 3
const CONTACT_VC: int = 3

## Harass fires only when the ville is walkable-close but not underfoot.
const HARASS_NEAR_M: float = 40.0
const HARASS_FAR_M: float = 160.0
## The firefight's draw is AUDIO: it stages inside earshot, outside a stroll.
const CONTACT_MIN_M: float = 110.0
const CONTACT_MAX_M: float = 200.0
const PATROL_SPAWN_MIN_M: float = 70.0
const PATROL_SPAWN_MAX_M: float = 130.0
const SPAWN_HIDE_TRIES: int = 6
## Beyond this from every man, a despawn cannot be seen.
const DESPAWN_M: float = 220.0
const HARASS_ABANDON_M: float = 260.0
const RTB_ARRIVE_M: float = 15.0
const COWER_M: float = 30.0
const PATROL_MIN_LIVE_S: float = 60.0

const VC_CONTACT_DATA: Array[String] = [
	"res://data/enemies/vc_rifleman.tres",
	"res://data/enemies/vc_rifleman.tres",
	"res://data/enemies/vc_farmer.tres",
]

var director: FieldDirector = null
var world: GameWorld = null

## Seed-fixed at attach.
var _village: Vector3 = Vector3.ZERO
var _harass_anchor: Vector3 = Vector3.ZERO
var _route_a: Array[Vector3] = []
var _route_b: Array[Vector3] = []
var _contact_sites: Array[Vector3] = []
var _group_seed: int = 0

## Unseeded on purpose: the dice are ambient life, not replayable layout
## (same exemption as AmbientWar/AirTraffic, demo_game.gd:9-11).
var _dice := RandomNumberGenerator.new()

var _elapsed: float = 0.0
var _poll: float = 0.0
var _walked: float = 0.0
var _cool: float = 0.0
var _last_pos: Vector3 = Vector3.ZERO
var _counts: Dictionary = {"harass": 0, "patrol": 0, "contact": 0}
var _serial: int = 0

var _live: String = ""
var _live_since: float = 0.0
var _rtb: bool = false
var _lg: LazyGroup = null
var _fp: FriendlyPatrolGroup = null
var _vc_tag: String = ""
var _cowed: Array[Civilian] = []


## Every position/route below draws the plan RNG appended after ALL existing
## build draws (called last in build_patrol_world) - the ambient-AA contract.
static func attach(game_world: GameWorld, field_director: FieldDirector,
		p: Dictionary, rng: RandomNumberGenerator) -> AmbientEncounters:
	var ae := AmbientEncounters.new()
	ae.name = "AmbientEncounters"
	ae.director = field_director
	ae.world = game_world
	var villages: Array = p.get("village_centers", [])
	if not villages.is_empty():
		ae._village = villages[0] as Vector3
		ae._harass_anchor = MissionGenerator._passable_near(game_world, rng,
			ae._village, 6.0, 22.0, 60)
	var anchors: Array[Vector3] = MissionGenerator._patrol_anchors(game_world, p, rng)
	ae._route_a = EnemyBase.make_patrol_circuit(anchors, rng, rng.randi_range(4, 6))
	ae._route_b = EnemyBase.make_patrol_circuit(anchors, rng, rng.randi_range(4, 6))
	var fsb: Vector3 = p.fsb_center as Vector3
	var out_v: Vector3 = ((p.gate_pos as Vector3) - fsb)
	out_v.y = 0.0
	out_v = out_v.normalized() if out_v.length() > 0.1 else Vector3.FORWARD
	# Bearings sit between the village flank (2.35) and the camp flank (-2.35),
	# clear of the ambient-AA bearings (0.9 / 2.9 / -1.35).
	for b: float in [1.6, -0.7, 0.35]:
		var site: Vector3 = MissionGenerator._passable_near(game_world, rng,
			fsb + out_v.rotated(Vector3.UP, b) * 155.0, 15.0, 60.0, 60,
			SitePlanner.FSB_SITE_CLEARANCE)
		if site != Vector3.ZERO:
			ae._contact_sites.append(site)
	ae._group_seed = rng.randi()
	game_world.add_child(ae)
	ae.add_to_group("ambient_encounters")
	print("[AMBIENT-ENC] armed: ville %s, %d contact sites, routes %d/%d" % [
		"yes" if ae._harass_anchor != Vector3.ZERO else "no",
		ae._contact_sites.size(), ae._route_a.size(), ae._route_b.size()])
	return ae


## Shared exclusivity surface - PilotRecovery.request_down reads this, and
## _pilot_busy() reads its twin, so the AO holds one ambient event at a time.
func encounter_active() -> bool:
	return _live != ""


func _physics_process(delta: float) -> void:
	_elapsed += minf(delta, 0.066)
	_poll += delta
	if _poll < 0.5:
		return
	_poll = 0.0
	if _cool > 0.0:
		_cool = maxf(0.0, _cool - 0.5)
	var player: Node3D = GameManager.player as Node3D
	if player == null or not is_instance_valid(player):
		return
	if _live != "":
		# _try_roll refuses to START one during the assault, but a LIVE encounter had no
		# such gate - a contact opened at 1370s runs MAX_LIVE_S past 1790s, straight through
		# the 45-man siege, competing with it for men and for the player's attention.
		if director != null and is_instance_valid(director) \
				and director.siege != null and is_instance_valid(director.siege) \
				and director.siege.active:
			_finish()
			return
		_tick_live(player)
		return
	_track_walk(player)
	if _walked < ROLL_EVERY_M:
		return
	_walked = 0.0
	_try_roll(player)


## The walk meter. Per-sample step is capped so a teleport or a Huey ride can
## never bank a roll's worth of "walking" in one poll.
func _track_walk(player: Node3D) -> void:
	var pos: Vector3 = player.global_position
	if _last_pos == Vector3.ZERO:
		_last_pos = pos
		return
	var step: float = Vector2(pos.x - _last_pos.x, pos.z - _last_pos.z).length()
	_last_pos = pos
	if step > 8.0 or director == null or director.fsb_center == Vector3.ZERO:
		return
	var out: float = Vector2(pos.x - director.fsb_center.x,
		pos.z - director.fsb_center.z).length()
	if out > WIRE_M:
		_walked += step


func _try_roll(player: Node3D) -> void:
	if _elapsed < HOLD_S or _cool > 0.0:
		return
	if MissionWeather.is_night:
		return
	if director == null or not is_instance_valid(director):
		return
	if director.siege != null and is_instance_valid(director.siege) and director.siege.active:
		return
	if _pilot_busy():
		return
	if _dice.randf() >= EVENT_CHANCE:
		return
	var eligible: Array[String] = []
	if _harass_eligible(player):
		eligible.append("harass")
	if _patrol_eligible():
		eligible.append("patrol")
	if _contact_site_for(player) != Vector3.ZERO:
		eligible.append("contact")
	if eligible.is_empty():
		return
	var kind: String = eligible[_dice.randi() % eligible.size()]
	match kind:
		"harass":
			_start_harass()
		"patrol":
			_start_patrol(player)
		"contact":
			_start_contact(player)


func _pilot_busy() -> bool:
	for n in get_tree().get_nodes_in_group("pilot_recovery"):
		if n is PilotRecovery and (n as PilotRecovery).encounter_active():
			return true
	return false


func _harass_eligible(player: Node3D) -> bool:
	if int(_counts.harass) >= int(DAY_CAPS.harass) or _harass_anchor == Vector3.ZERO:
		return false
	var d: float = Vector2(player.global_position.x - _village.x,
		player.global_position.z - _village.z).length()
	return d >= HARASS_NEAR_M and d <= HARASS_FAR_M


func _patrol_eligible() -> bool:
	return int(_counts.patrol) < int(DAY_CAPS.patrol) \
		and (not _route_a.is_empty() or not _route_b.is_empty())


func _contact_site_for(player: Node3D) -> Vector3:
	if int(_counts.contact) >= int(DAY_CAPS.contact):
		return Vector3.ZERO
	for site in _contact_sites:
		var d: float = Vector2(player.global_position.x - site.x,
			player.global_position.z - site.z).length()
		if d >= CONTACT_MIN_M and d <= CONTACT_MAX_M:
			return site
	return Vector3.ZERO


## A point the player cannot currently see, using the one LOS authority
## (combat_manager.gd:361). There is no repo-wide "spawn out of view" helper;
## this composes the existing ray rather than inventing a second sight system.
func _hidden_near(center: Vector3, min_r: float, max_r: float) -> Vector3:
	var player: Node3D = GameManager.player as Node3D
	var best: Vector3 = Vector3.ZERO
	for _i in range(SPAWN_HIDE_TRIES):
		var cand: Vector3 = MissionGenerator._passable_near(world, _dice, center,
			min_r, max_r, 40)
		if cand == Vector3.ZERO:
			continue
		best = cand
		if player == null:
			break
		if not CombatManager.has_line_of_sight(
				player.global_position + Vector3.UP * 1.6,
				cand + Vector3.UP * 1.5, []):
			break
	return best


func _begin(kind: String) -> void:
	_live = kind
	_live_since = _elapsed
	_rtb = false
	_counts[kind] = int(_counts[kind]) + 1
	_serial += 1


func _finish() -> void:
	print("[AMBIENT-ENC] %s ended at %.0fs" % [_live, _elapsed])
	_live = ""
	_lg = null
	_fp = null
	_vc_tag = ""
	_release_cowed()
	_cool = COOLDOWN_S


## ---- VC harassing villagers -------------------------------------------------

func _start_harass() -> void:
	_begin("harass")
	_lg = LazyGroup.new()
	_lg.enemy_count = HARASS_MEN
	_lg.group_tag = "village_harass_%d" % _serial
	_lg.activation_range = 120.0
	_lg.spread = 6.0
	_lg.setup(director, _group_seed + 13 * _serial)
	world.add_child(_lg)
	_lg.global_position = MissionGenerator._seat(world, _harass_anchor)
	print("[AMBIENT-ENC] harass staged at the ville (%s)" % _lg.group_tag)


func _tick_harass(player: Node3D) -> void:
	if _lg == null or not is_instance_valid(_lg):
		_finish()
		return
	var far: float = Vector2(player.global_position.x - _harass_anchor.x,
		player.global_position.z - _harass_anchor.z).length()
	if not _lg._spawned:
		if far > HARASS_ABANDON_M and _elapsed - _live_since > float(MAX_LIVE_S.harass):
			_lg.queue_free()
			_finish()
		return
	_force_cower()
	var alive: int = 0
	for n in get_tree().get_nodes_in_group(_lg.group_tag):
		if n is EnemyBase and not (n as EnemyBase).is_dead():
			alive += 1
	if alive == 0:
		# The cheap surface the world remembers with: the same MissionState.flags
		# bank the pilot uses (pilot_recovery.gd:203). No reputation system.
		director.state.flags["villagers_freed"] = \
			int(director.state.flags.get("villagers_freed", 0)) + 1
		director.toast.emit("THE VILLE'S CLEAR - THEY WON'T FORGET WHO CAME")
		_finish()
		return
	if far > HARASS_ABANDON_M and _elapsed - _live_since > float(MAX_LIVE_S.harass):
		for n in get_tree().get_nodes_in_group(_lg.group_tag):
			if n is EnemyBase and not (n as EnemyBase).is_dead():
				(n as EnemyBase).queue_free()
		_lg.queue_free()
		_finish()


## Menace is cheap: armed men standing in the ville while every noncombatant
## near them holds the cower pose the reactive state already owns.
func _force_cower() -> void:
	for n in get_tree().get_nodes_in_group("civilians"):
		var civ := n as Civilian
		if civ == null or not is_instance_valid(civ) or civ.is_garrison:
			continue
		if civ.state != Civilian.CivState.WANDER:
			continue
		if civ.global_position.distance_to(_lg.global_position) > COWER_M:
			continue
		civ.state = Civilian.CivState.COWER
		if not _cowed.has(civ):
			_cowed.append(civ)


func _release_cowed() -> void:
	for civ in _cowed:
		if civ != null and is_instance_valid(civ) and civ.state == Civilian.CivState.COWER:
			civ.state = Civilian.CivState.WANDER
	_cowed.clear()


## ---- Friendly squad on patrol ----------------------------------------------

func _start_patrol(player: Node3D) -> void:
	var at: Vector3 = _hidden_near(player.global_position,
		PATROL_SPAWN_MIN_M, PATROL_SPAWN_MAX_M)
	if at == Vector3.ZERO:
		return
	_begin("patrol")
	_fp = FriendlyPatrolGroup.new()
	_fp.enemy_count = PATROL_MEN
	_fp.group_tag = "ambient_friendly_walk_%d" % _serial
	_fp.activation_range = 140.0
	_fp.spread = 6.0
	_fp.setup(director, _group_seed + 29 * _serial)
	var route: Array[Vector3] = _route_a
	if _route_a.is_empty() or (_serial % 2 == 1 and not _route_b.is_empty()):
		route = _route_b
	_fp.route = route
	world.add_child(_fp)
	_fp.global_position = MissionGenerator._seat(world, at)
	director.toast.emit("FRIENDLY ELEMENT ON THE NET - PASSING TO YOUR %s"
		% PilotRecovery._bearing8(player.global_position, at))
	print("[AMBIENT-ENC] friendly patrol staged (%s)" % _fp.group_tag)


func _tick_patrol(player: Node3D) -> void:
	if _fp == null or not is_instance_valid(_fp):
		_finish()
		return
	if _fp._spawned and _fp.living_count() == 0:
		_fp.queue_free()
		_finish()
		return
	var age: float = _elapsed - _live_since
	if not _rtb and age > float(MAX_LIVE_S.patrol):
		_order_rtb(_fp)
	if age < PATROL_MIN_LIVE_S or _fp.is_pinned():
		return
	if _men_gone(_fp, player):
		_free_element(_fp)
		_finish()


## ---- Friendly squad stuck in a firefight ------------------------------------

## Both sides are the REAL combat AI - the gunfire the player hears is the
## real systems fighting, never a sound prop.
func _start_contact(player: Node3D) -> void:
	var site: Vector3 = _contact_site_for(player)
	if site == Vector3.ZERO:
		return
	_begin("contact")
	_fp = FriendlyPatrolGroup.new()
	_fp.enemy_count = CONTACT_ALLIES
	_fp.group_tag = "ambient_contact_us_%d" % _serial
	_fp.spread = 5.0
	_fp.setup(director, _group_seed + 41 * _serial)
	world.add_child(_fp)
	_fp.global_position = MissionGenerator._seat(world, site)
	_fp.force_spawn()
	_vc_tag = "ambient_contact_vc_%d" % _serial
	var vc_at: Vector3 = MissionGenerator._passable_near(world, _dice, site, 22.0, 35.0, 40)
	if vc_at == Vector3.ZERO:
		vc_at = site + Vector3(28.0, 0.0, 0.0)
	vc_at = MissionGenerator._seat(world, vc_at)
	var toward: Vector3 = (site - vc_at)
	toward.y = 0.0
	toward = toward.normalized() if toward.length() > 0.5 else Vector3.FORWARD
	for i in range(CONTACT_VC):
		var a: float = _dice.randf_range(0.0, TAU)
		var pos: Vector3 = vc_at + Vector3(cos(a), 0.0, sin(a)) * _dice.randf_range(2.0, 8.0)
		var enemy: EnemyBase = director.spawn_tracked_enemy(pos,
			VC_CONTACT_DATA[i % VC_CONTACT_DATA.size()], _vc_tag)
		enemy.add_to_group(_vc_tag)
		enemy.facing_dir = toward
	director.toast.emit("GUNFIRE TO THE %s - SOMEBODY'S IN IT"
		% PilotRecovery._bearing8(player.global_position, site))
	print("[AMBIENT-ENC] firefight staged at %s (%s vs %s)" % [site, _fp.group_tag, _vc_tag])


func _tick_contact(player: Node3D) -> void:
	if _fp == null or not is_instance_valid(_fp):
		_finish()
		return
	var vc_alive: int = 0
	for n in get_tree().get_nodes_in_group(_vc_tag):
		if n is EnemyBase and not (n as EnemyBase).is_dead():
			vc_alive += 1
	var us_alive: int = _fp.living_count()
	if us_alive == 0:
		# The VC that won hold their ground on their own doctrine - they are
		# tracked enemies now, the AO's business, not this event's.
		_fp.queue_free()
		_finish()
		return
	var age: float = _elapsed - _live_since
	if not _rtb and (vc_alive == 0 or age > float(MAX_LIVE_S.contact)):
		if vc_alive == 0:
			director.toast.emit("THEY'RE CLEAR - ELEMENT BREAKING CONTACT FOR HOME")
		_order_rtb(_fp)
	if _rtb and (_men_gone(_fp, player) or _lead_home(_fp)):
		_free_element(_fp)
		_finish()


## ---- Shared element handling -------------------------------------------------

## RTB read: clear the circuit so _advance_route cannot re-issue it, then walk
## every living man at the gate.
func _order_rtb(fp: FriendlyPatrolGroup) -> void:
	_rtb = true
	var none: Array[Vector3] = []
	fp.route = none
	var gate: Vector3 = director.patrol_gate_pos
	if gate == Vector3.ZERO:
		gate = director.fsb_center
	for man in fp._men:
		if man != null and is_instance_valid(man) and not man.is_dead():
			man.set_order(AllyBase.OrderMode.MOVE_TO, gate)


func _men_gone(fp: FriendlyPatrolGroup, player: Node3D) -> bool:
	for man in fp._men:
		if man == null or not is_instance_valid(man) or man.is_dead():
			continue
		if man.global_position.distance_to(player.global_position) <= DESPAWN_M:
			return false
	return true


func _lead_home(fp: FriendlyPatrolGroup) -> bool:
	var gate: Vector3 = director.patrol_gate_pos
	if gate == Vector3.ZERO:
		return false
	for man in fp._men:
		if man != null and is_instance_valid(man) and not man.is_dead():
			return man.global_position.distance_to(gate) <= RTB_ARRIVE_M
	return false


## Corpses keep their own 45s linger (ally_base.gd:1780-1781); only the living
## are lifted, and only once nobody can watch it happen.
func _free_element(fp: FriendlyPatrolGroup) -> void:
	for man in fp._men:
		if man != null and is_instance_valid(man) and not man.is_dead():
			man.queue_free()
	fp.queue_free()


func _tick_live(player: Node3D) -> void:
	match _live:
		"harass":
			_tick_harass(player)
		"patrol":
			_tick_patrol(player)
		"contact":
			_tick_contact(player)
		_:
			_live = ""
