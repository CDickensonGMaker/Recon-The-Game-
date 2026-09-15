## way_station.gd - the VC's use of the village as a PLACE, 130 m past the ville on the far
## bank (AO sheet §1.4, ADR-041 thawed 2026-09-15). The plan chose WHERE (p.way_station);
## this reads the ledger's BAND at runtime and stamps the population that band means:
##   quiet   - a lean-to and rice sacks; nobody. A woodcutter's shelter.
##   wary    - two men and a cache under the sacks (a FieldCache the [F] verb already reads).
##   hostile - a four-man picket covering F1, the village's own ford.
## The shelter is stamped once; the men are a LazyGroup re-stamped when the band moves, so
## the place is read, never announced (ADR-038 §2a: the band names a subject, never a count
## the player sees). Population goes through MissionGenerator.place_event_prop / LazyGroup -
## no second builder.
class_name WayStation
extends Node

const HmLedgerS := preload("res://scripts/world/hm_ledger.gd")
const SHELTER_MODEL: String = "res://assets/world/building models/structures/village/lean_to_01.glb"
const SACKS_MODEL: String = "res://assets/civilians/props/market/flour_sacks.glb"
const BASKET_MODEL: String = "res://assets/civilians/props/market/rice_basket_full.glb"
const GROUP_TAG: String = "way_station"
const WARY_MEN: int = 2
const HOSTILE_MEN: int = 4
## The hostile picket stands this far off F1 on the way-station's side, an ambush covering
## the crossing rather than men in a hut.
const PICKET_OFF_FORD_M: float = 28.0
const POLL_S: float = 5.0

var world: GameWorld = null
var director: FieldDirector = null
var center: Vector3 = Vector3.ZERO
var village: Vector3 = Vector3.ZERO
var covers: Vector3 = Vector3.ZERO
var band: StringName = &""
var _men: LazyGroup = null
var _cache: FieldCache = null
var _poll: float = 0.0


static func attach(game_world: GameWorld, field_director: FieldDirector, plan: Dictionary) -> WayStation:
	var ws := WayStation.new()
	ws.name = "WayStation"
	ws.world = game_world
	ws.director = field_director
	ws.center = plan.center
	ws.village = plan.village
	ws.covers = plan.get("covers", plan.center)
	game_world.add_child(ws)
	ws.add_to_group("way_station")
	ws._stamp_shelter()
	ws.restamp()
	return ws


func _stamp_shelter() -> void:
	var yaw: float = rad_to_deg(atan2(village.x - center.x, village.z - center.z))
	MissionGenerator.place_event_prop(world, SHELTER_MODEL, center, yaw)
	var side := Vector3(cos(deg_to_rad(yaw)), 0.0, -sin(deg_to_rad(yaw)))
	MissionGenerator.place_event_prop(world, SACKS_MODEL, center + side * 2.2, yaw + 90.0)
	MissionGenerator.place_event_prop(world, BASKET_MODEL, center - side * 1.8, yaw - 40.0)


func current_band() -> StringName:
	return CampaignState.hearts.band(HmLedgerS.place_key(village))


## Re-read the band and stamp what it means. Idempotent on an unchanged band.
func restamp() -> void:
	var want: StringName = current_band()
	if want == band:
		return
	band = want
	_clear_population()
	match band:
		HmLedgerS.BAND_WARY:
			_men = _stand_men(center, WARY_MEN, 6.0)
			var under: Vector3 = center
			under.y = world.floor_y(center + Vector3.UP * 0.5)
			_cache = FieldCache.deploy(world, under, FieldCache.Kind.AMMO)
		HmLedgerS.BAND_HOSTILE:
			var toward: Vector3 = (center - covers)
			toward.y = 0.0
			var picket: Vector3 = covers + toward.normalized() * PICKET_OFF_FORD_M
			picket.y = world.terrain_manager.get_height_at(picket)
			_men = _stand_men(picket, HOSTILE_MEN, 9.0)
	print("[WAY-STATION] %s: %s" % [band, _population_line()])


func _stand_men(at: Vector3, count: int, spread: float) -> LazyGroup:
	var lg := LazyGroup.new()
	lg.enemy_count = count
	lg.group_tag = GROUP_TAG
	lg.spread = spread
	lg.setup(director, director.state.seed_value + hash(GROUP_TAG))
	world.add_child(lg)
	lg.global_position = at
	return lg


func _clear_population() -> void:
	if _men != null and is_instance_valid(_men):
		_men.queue_free()
	_men = null
	for n in get_tree().get_nodes_in_group(GROUP_TAG):
		if n is EnemyBase and is_instance_valid(n):
			(n as Node).queue_free()
	if _cache != null and is_instance_valid(_cache):
		_cache.queue_free()
	_cache = null


func _population_line() -> String:
	match band:
		HmLedgerS.BAND_WARY:
			return "two men and a cache under the sacks"
		HmLedgerS.BAND_HOSTILE:
			return "a picket of four covering the ford"
	return "a lean-to and rice sacks, nobody"


func _process(delta: float) -> void:
	_poll -= delta
	if _poll > 0.0:
		return
	_poll = POLL_S
	restamp()
