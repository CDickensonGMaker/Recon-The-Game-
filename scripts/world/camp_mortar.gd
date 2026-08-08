## camp_mortar.gd - The enemy camp's harassing mortar (S27). Owns WHEN the camp's
## tube fires and whether it still can; the shells themselves fly through
## SiegeDirector.fire_mortar_volley from the pit's own position - one shell
## system, never a second (ADR-023).
##
## Silencing (his ruling): the crew dead OR the tube destroyed, latched for the
## day - no re-crewing. SiegeDirector._camp_mortar_silenced reads this node's
## group to cancel the night ranging walk.
class_name CampMortar
extends Node

## No fire while the player finds his feet (his ruling: nothing in the first
## ~10 minutes of the demo day). Real seconds, like the arc clock.
const HOLD_FIRE_S: float = 600.0
## Random gap between volleys - "you can never predict what charlies thinking".
const GAP_MIN_S: float = 120.0
const GAP_MAX_S: float = 420.0

var director: FieldDirector = null
var pit: MortarPit = null
var tube: Destructible = null
## The crew's spawn group. Empty group before the LazyGroup wakes means the crew
## is unspawned, not dead - _crew_seen separates the two.
var crew_tag: String = ""

var _elapsed: float = 0.0
var _next_fire: float = 0.0
var _poll: float = 0.0
var _crew_seen: bool = false
var _silenced: bool = false
## Unseeded on purpose: harassment timing is ambient life, not replayable layout
## (same exemption as AmbientWar/AirTraffic, demo_game.gd:9-11).
var _rng := RandomNumberGenerator.new()


static func attach(world: Node, field_director: FieldDirector, mortar_pit: MortarPit,
		tag: String) -> CampMortar:
	var cm := CampMortar.new()
	cm.name = "CampMortar"
	cm.director = field_director
	cm.pit = mortar_pit
	cm.crew_tag = tag
	cm.tube = _lift_tube(world, mortar_pit)
	world.add_child(cm)
	cm.add_to_group("camp_mortars")
	cm._next_fire = HOLD_FIRE_S + cm._rng.randf_range(0.0, GAP_MAX_S)
	return cm


## Swap the pit's M29 for a Destructible carrying the same mesh, so a grenade or
## satchel on the tube is a real answer. HP borrows the parapet datum - the one
## HP table stays the authority and no new number is invented.
static func _lift_tube(world: Node, mortar_pit: MortarPit) -> Destructible:
	var m29: Node3D = mortar_pit.get_node_or_null(^"M29") as Node3D
	if m29 == null:
		return null
	var mesh: Mesh = null
	var stack: Array[Node] = [m29]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for c in n.get_children():
			stack.append(c)
		var mi := n as MeshInstance3D
		if mi != null and mi.mesh != null:
			mesh = mi.mesh
			break
	if mesh == null:
		return null
	var d: Destructible = FireSupportBench.spawn_lifted(world, mesh,
		m29.global_position, "mortar_tube", Destructible.hp_for("sandbag_wall"))
	d.global_rotation = m29.global_rotation
	## The Destructible is a damage proxy: the animated GLB keeps the visual so
	## the fire clip reads; the proxy's copy stays hidden until it turns to rubble.
	_set_proxy_visible(d, false)
	return d


static func _set_proxy_visible(d: Destructible, on: bool) -> void:
	if d == null or not is_instance_valid(d):
		return
	for c in d.get_children():
		var mi := c as MeshInstance3D
		if mi != null:
			mi.visible = on


func silenced() -> bool:
	if _silenced:
		return true
	if tube != null and is_instance_valid(tube) and tube.is_destroyed():
		_silence("tube destroyed")
		var m29: Node3D = pit.get_node_or_null(^"M29") as Node3D if pit != null and is_instance_valid(pit) else null
		if m29 != null:
			m29.visible = false
		_set_proxy_visible(tube, true)
	elif _crew_gone():
		_silence("crew dead")
	return _silenced


func _crew_gone() -> bool:
	if crew_tag.is_empty() or get_tree() == null:
		return false
	var men: Array[Node] = get_tree().get_nodes_in_group(crew_tag)
	for m in men:
		var e := m as EnemyBase
		if e != null and is_instance_valid(e) and not e.is_dead():
			_crew_seen = true
			return false
	return _crew_seen


func _silence(reason: String) -> void:
	_silenced = true
	set_physics_process(false)
	print("[CampMortar] silenced (%s) - no more fire today, night walk cancelled" % reason)


func _physics_process(delta: float) -> void:
	_elapsed += minf(delta, 0.066)
	_poll += delta
	if _poll < 1.0:
		return
	_poll = 0.0
	if silenced() or director == null or not is_instance_valid(director):
		return
	if director.fsb_center == Vector3.ZERO or _elapsed < _next_fire:
		return
	# The assault's own ranging walk owns the night's mortars; harassment is the day's.
	if director.siege != null and is_instance_valid(director.siege) and director.siege.active:
		return
	_next_fire = _elapsed + _rng.randf_range(GAP_MIN_S, GAP_MAX_S)
	_fire()


func _fire() -> void:
	if director.siege == null:
		director._attach_siege()
	if director.siege == null or pit == null or not is_instance_valid(pit):
		return
	director.siege.fire_mortar_volley(director.fsb_center,
		SiegeDirector.MORTAR_DISPERSION_START, pit.global_position)
	pit.play_fire_anim()
	director.toast.emit("INCOMING - MORTARS ON THE COMPOUND")
	print("[CampMortar] harassment volley at %.0fs from the camp pit" % _elapsed)
