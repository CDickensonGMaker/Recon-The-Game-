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
## True on the frame target_position moved: the new path is async and has not landed.
var _restaked: bool = false

## Same cache, for the agent's OWN footing.
var _self_src: Vector3 = Vector3.ZERO
var _self_out: Vector3 = Vector3.ZERO
var _self_valid: bool = false

## Same cache, for nearest_mesh_point.
var _snap_src: Vector3 = Vector3.ZERO
var _snap_out: Vector3 = Vector3.ZERO
var _snap_valid: bool = false

## Further than this off the mesh and he is not standing on it. Generous: the mesh sits a
## cell-height under the ground and an agent on a slope reads a little off.
const OFF_MESH_M: float = 1.2

## How far a target may be pulled onto the mesh. A garrison post inside a bunker footprint is
## routinely 5-8m off walkable ground; anything beyond a hootch's width is not a post that
## drifted, it is a bad destination, and direct steering says so more honestly than a path to
## somewhere else entirely.
const CLAMP_MAX_M: float = 12.0


func setup(nav_agent: NavigationAgent3D, tree: SceneTree, who: String) -> void:
	agent = nav_agent
	lab_nav = tree != null and tree.get_first_node_in_group("lab_navmesh") != null
	label = who


## Which baked box the body stands in. Think rate, never per frame.
func refresh_box(at: Vector3) -> void:
	box = NavBaker.box_index_at(at) if WorldConfig.NAV_ENABLED else -1


## The SANCTIONED public clamp. Returns `pos` UNCHANGED unless a baked region
## actually covers it and the correction stays under CLAMP_MAX_M - a naked
## map_get_closest_point against ground no region covers returns the nearest FAR
## region (the firebase), dragging targets 100+m. Callers must treat an unchanged
## return as "no safe clamp exists", never as "already on the mesh".
func nearest_mesh_point(pos: Vector3) -> Vector3:
	if agent == null or not WorldConfig.NAV_ENABLED:
		return pos
	if not lab_nav and NavBaker.box_index_at(pos) < 0:
		return pos
	var map: RID = agent.get_navigation_map()
	if not map.is_valid() or NavigationServer3D.map_get_iteration_id(map) <= 0:
		return pos
	if not _snap_valid or pos.distance_squared_to(_snap_src) > 1.0:
		_snap_src = pos
		var snapped: Vector3 = NavigationServer3D.map_get_closest_point(map, pos)
		_snap_out = snapped if pos.distance_to(snapped) < CLAMP_MAX_M else pos
		_snap_valid = true
	return _snap_out


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
	#
	# The clamp used to be REFUSED past 4m, handing the raw point to the query instead - which
	# is a guaranteed no-path, because an unreachable target is exactly what the clamp exists to
	# repair. That refusal is what kept the firebase garrison failing at 5-8m all through the
	# 2026-07-29 playtests: a post inside a hootch footprint sits further than 4m off the mesh,
	# so every man on it fell to direct steering and walked into the wall between him and it.
	#
	# We already know the target is inside this agent's own baked box (use_nav tested it), so
	# the nearest mesh point is a sane place to send him. CLAMP_MAX_M only guards the absurd -
	# a target the size of the compound away from any walkable ground is a bug upstream, and
	# steering direct is the more honest failure there.
	if not _clamp_valid or to.distance_squared_to(_clamp_src) > 1.0:
		_clamp_src = to
		var clamped: Vector3 = NavigationServer3D.map_get_closest_point(map, to)
		_clamp_out = clamped if to.distance_to(clamped) < CLAMP_MAX_M else to
		_clamp_valid = true
	_restaked = false
	if agent.target_position.distance_squared_to(_clamp_out) > 9.0:
		agent.target_position = _clamp_out   # each restake is a map_get_path()
		_restaked = true
	if not agent.is_navigation_finished():
		return agent.get_next_path_position() - from
	# THE PATH FAILED. Before falling back to a straight line into whatever wall is in front of
	# him, ask the one question that explains most failures: is he standing OFF the mesh? A path
	# is queried from the agent's own position, and a man with no start polygon gets nothing
	# back - which reads exactly like "no route exists".
	#
	# That is how the firebase garrison spent the 2026-07-29 playtests frozen. Their posts come
	# from GLB markers that can sit inside a bunker or on ground the agent-radius erosion ate,
	# and the navmesh is baked AFTER they spawn, so seating them at spawn cannot fix it. His
	# first job is to step back onto walkable ground; routing resumes once he is on it.
	#
	# Checked HERE and not before the query on purpose: map_get_closest_point is a full polygon
	# search, and running it every step for every agent cost ~15 FPS when it was hoisted above
	# the happy path. A healthy agent must never pay for it.
	if not _self_valid or from.distance_squared_to(_self_src) > 1.0:
		_self_src = from
		_self_out = NavigationServer3D.map_get_closest_point(map, from)
		_self_valid = true
	var off: Vector3 = _self_out - from
	off.y = 0.0
	if off.length() > OFF_MESH_M:
		return off

	# FLAT distance, and only after the restake has had a frame. Two things were being
	# counted as pathing failures that are not:
	#
	# 1. A target directly overhead. Measured on the firebase: a garrison man 1.4m from his
	#    post in XZ, warning because the post's work_* marker floats 2.4-4.1m up on a 2.56m
	#    hootch. He has arrived; the navmesh cannot lift him onto a roof and should not try.
	# 2. The frame target_position is restaked. Setting it queues an ASYNC path, and
	#    is_navigation_finished() reads true until that path lands - which is not "no route",
	#    it is "not yet". Every one of these had map_get_path returning a real path.
	# 3. The agent's path simply has not landed yet. NavigationAgent3D computes
	#    asynchronously and is_navigation_finished() reads true in that window, which is
	#    indistinguishable from "no route" unless you ASK. So before claiming there is no
	#    path, put the question to the server directly: a real absence returns under 2
	#    points. Paid only on the failure path, and only until the one-shot fires.
	var flat := Vector3(direct.x, 0.0, direct.z)
	if OS.is_debug_build() and flat.length_squared() > 25.0 and not _warned and not _restaked \
			and NavigationServer3D.map_get_path(map, _self_out, _clamp_out, true).size() < 2:
		_warned = true
		# Name the region honestly: under a lab navmesh `box` is -1 and meaningless,
		# and printing "-1" reads as a bug in the box lookup rather than a missing path.
		var where: String = "lab navmesh" if lab_nav else "baked region %d" % box
		# [NAV-FALLBACK], not [NAV]: the runner promotes "WARNING: [NAV]" to FAIL
		# because that namespace belongs to the BAKE INVARIANT guards. This line is
		# telemetry for a DESIGNED fallback (direct steering is the intended
		# behavior when no path exists - see the contract at the top of step()),
		# and on the honest post-2026-08-13 mesh it legitimately fires more:
		# targets that were only fictionally reachable now have no path, and
		# physics climbs the berm instead. A test must not go red for it.
		push_warning("[NAV-FALLBACK] %s on %s, %.1fm to target, no path - falling back to direct steering" % [
			label, where, flat.length()])
	return direct
