## nav_router.gd - The ONE navmesh routing path, shared by EnemyBase and AllyBase
## (ADR-023: allies steered straight into walls for want of this, while enemies
## routed around them on the same baked mesh).
##
## Owns the per-agent nav state - which baked box the body stands in, the target
## clamp cache, the one-shot fallback warning - and answers one question: which way
## do I step to reach `to`. Locomotion stays with the caller: speed, suppression,
## facing and the velocity lerp differ per class and do NOT belong here.
class_name NavRouter
extends RefCounted

var agent: NavigationAgent3D = null
var box: int = -1          ## index into NavBaker._live_boxes, refreshed at think rate
var lab_nav: bool = false  ## a scene-baked region covering the whole level
var label: String = "agent"

## map_get_closest_point is a full polygon search, so it is re-run only when the
## raw target moves, never once per physics tick.
var _clamp_src: Vector3 = Vector3.ZERO
var _clamp_out: Vector3 = Vector3.ZERO
var _clamp_valid: bool = false
var _warned: bool = false


func setup(nav_agent: NavigationAgent3D, tree: SceneTree, who: String) -> void:
	agent = nav_agent
	lab_nav = tree != null and tree.get_first_node_in_group("lab_navmesh") != null
	label = who


## Which baked box the body stands in. Think rate, never per frame.
func refresh_box(at: Vector3) -> void:
	box = NavBaker.box_index_at(at) if WorldConfig.NAV_ENABLED else -1


## The UNNORMALISED step vector from `from` toward `to`.
##
## Nav applies only when BOTH endpoints sit inside the SAME baked region. Outside
## one, direct steering is the INTENDED behaviour and not a fallback - the same-box
## test also stops an agent chasing a target outside his region having his path
## clamped to the region edge, where is_navigation_finished() fires and he stops.
func step(from: Vector3, to: Vector3) -> Vector3:
	var direct: Vector3 = to - from
	var use_nav: bool = WorldConfig.NAV_ENABLED and box >= 0 and NavBaker.box_contains(box, to)
	if lab_nav:
		use_nav = true
	if agent == null or not use_nav:
		return direct
	# A map RID is valid the instant it is created, but every query against it
	# errors until the server has run its first synchronization. Queries in that
	# window also return "no path", which reads as is_navigation_finished().
	var map: RID = agent.get_navigation_map()
	if not map.is_valid() or NavigationServer3D.map_get_iteration_id(map) <= 0:
		return direct
	# Clamp the target onto the mesh. Off-mesh points (a cover point on a berm, an
	# LP behind a wall, an agent on an eroded vertex) reach is_navigation_finished()
	# while still metres from the original target.
	if not _clamp_valid or to.distance_squared_to(_clamp_src) > 1.0:
		_clamp_src = to
		var clamped: Vector3 = NavigationServer3D.map_get_closest_point(map, to)
		_clamp_out = clamped if to.distance_to(clamped) < 4.0 else to
		_clamp_valid = true
	if agent.target_position.distance_squared_to(_clamp_out) > 9.0:
		agent.target_position = _clamp_out   # each restake is a map_get_path()
	if not agent.is_navigation_finished():
		return agent.get_next_path_position() - from
	if OS.is_debug_build() and direct.length_squared() > 25.0 and not _warned:
		_warned = true
		push_warning("[NAV] %s inside baked region %d, %.1fm to target, no path - falling back to direct steering" % [
			label, box, direct.length()])
	return direct
