## probe_npc_census.gd - the NPC census. Every villager and garrison man: where his schedule says
## he should be against where he stands, what he plays, whom he overlaps, whether he is on a roof.
##
##   godot --headless --path . res://scenes/levels/demo_game.tscn -- --npc-census --test-save
##   ... --demo-seed=N
##
## Attached to the live world by game_flow.gd under `--npc-census`. Holds the garrison's
## stand-to off for the whole run (FieldDirector.stand_to_held - a promoted man leaves the
## civilian roster and the census would count an empty camp). Samples once at T+SETTLE_S
## (spawn state), then jumps the sim clock to each of SAMPLE_HOURS with the clock PAUSED and gives
## the men JUMP_SETTLE_S to walk. Quits with exit 1 on any man far from a post his action binds
## him to - WRONG-TARGET when he is not even aiming at it, STUCK when he is and cannot get
## there - any overlapping pair of live bodies, or any man on a roof. A post whose marker sits
## off the navmesh is named per row and counted apart: content, not a man in the wrong place.
extends Node

const RoofS := preload("res://tools/probe_roof_spawn.gd")
const CivilianS := preload("res://scripts/world/civilian.gd")

const SETTLE_S: float = 40.0
const JUMP_SETTLE_S: float = 75.0
const SAMPLE_HOURS: Array[float] = [10.5, 14.5, 19.7]
## A post-bound man further than this from his post, while standing still, is in the wrong place.
const WRONG_PLACE_M: float = 2.0
## Two live bodies closer than this in XZ and Y are inside each other.
const OVERLAP_XZ_M: float = 0.45
const OVERLAP_Y_M: float = 0.5
## Under this he is standing; over it he is still walking to wherever he is going.
const WALKING_MPS: float = 0.3

## Which actions bind a man to his working point - the decree table of 2026-09-13, encoded
## independently of civilian._resolve_target so the census can disagree with the resolver.
const POST_ACTIONS: Array[StringName] = [&"work", &"cook", &"fish", &"walk_paddy"]
const OFF_DUTY_AT_POST: Array[StringName] = [&"rest", &"sit", &"talk"]
const POST_OFF_DUTY_OCCUPATIONS: Array[String] = [
	"off_duty", "mess_hall", "gun_crew", "gun_crew_arty", "radioman", "medic", "patient",
]

var _world: Node3D = null
var _wrong: int = 0
var _stuck: int = 0
var _overlaps: int = 0
var _roofs: int = 0
var _offmesh: int = 0
var _arrived: int = 0
var _away: int = 0
var _samples: int = 0
## Within this of the resolved post he has ARRIVED (Civilian.WORK_ARRIVE_M). The gate that
## matters: the absence of a stuck flag counts a man who is merely moving (2026-09-13).
const ARRIVED_M: float = 0.7


func _ready() -> void:
	_world = get_parent() as Node3D
	# A stand-to turns the garrison into defenders and empties the civilian roster mid-run
	# (2026-09-13: 40 men promoted between samples one and two). The census measures camp
	# life, so it holds the alarm off for its whole run - the moment the director exists.
	var held: bool = false
	var waited: float = 0.0
	while waited < SETTLE_S:
		await get_tree().create_timer(1.0).timeout
		waited += 1.0
		if not held:
			var director: FieldDirector = _find_director()
			if director != null:
				director.stand_to_held = true
				held = true
				print("[NPC-CENSUS] stand-to held at T+%.0fs" % waited)
	if not held:
		print("[NPC-CENSUS] no FieldDirector found - a stand-to can empty the camp mid-sample")
	if _world == null or not is_instance_valid(_world):
		print("[NPC-CENSUS] no world - nothing measured")
		get_tree().quit(1)
		return
	_sample("spawn %.2fh" % float(SimClock.sim_hour))
	# The clock holds still between jumps so a sample reads one schedule window, not a smear
	# of the 38x demo clock crossing two boundaries while the men are still walking.
	SimClock.paused = true
	for h in SAMPLE_HOURS:
		SimClock.set_time(SimClock.sim_day, h)
		await get_tree().create_timer(JUMP_SETTLE_S).timeout
		if _world == null or not is_instance_valid(_world):
			break
		_sample("%.1fh" % h)
	print("[NPC-CENSUS] %d samples: %d wrong-target, %d stuck, %d overlaps, %d roofs, %d posts off the mesh (content, not counted) | post-bound rows: %d ARRIVED, %d AWAY" % [
		_samples, _wrong, _stuck, _overlaps, _roofs, _offmesh, _arrived, _away])
	if _wrong == 0 and _stuck == 0 and _overlaps == 0 and _roofs == 0:
		print("*** EVERY MAN IS WHERE HIS SCHEDULE PUT HIM, ALONE, ON A FLOOR. ***")
	get_tree().quit(1 if (_wrong + _stuck + _overlaps + _roofs) > 0 else 0)


func _find_director() -> FieldDirector:
	for n in AgentRegistry.civilians:
		var civ: Civilian = n as Civilian
		if civ != null and is_instance_valid(civ) and civ.director != null:
			return civ.director
	var found: Array[Node] = get_tree().root.find_children("*", "FieldDirector", true, false)
	return found[0] as FieldDirector if not found.is_empty() else null


func _sample(label: String) -> void:
	_samples += 1
	print("\n=== NPC CENSUS [%s] seed %s | clock %.2fh %s ===" % [label,
		str(_world.get("mission_seed")), float(SimClock.sim_hour),
		"PAUSED" if SimClock.paused else "running"])
	var space: PhysicsDirectSpaceState3D = _world.get_world_3d().direct_space_state
	var bodies: Array[Node3D] = []
	var wrong_here: int = 0
	var stuck_here: int = 0
	var walking: int = 0
	var skipped: int = 0
	var arrived_here: int = 0
	var away_here: int = 0
	for n in AgentRegistry.civilians:
		var civ: Civilian = n as Civilian
		if civ == null or not is_instance_valid(civ) or not civ.is_inside_tree():
			continue
		bodies.append(civ)
		var why: String = ""
		if civ.state != CivilianS.CivState.WANDER:
			why = "state %d" % civ.state
		elif civ.puppet:
			why = "puppet"
		elif civ.board_target != Vector3.ZERO:
			why = "boarding"
		elif not civ.is_physics_processing():
			why = "no physics"
		elif civ.lod_tier == CivilianS.LOD_FAR:
			why = "far"
		if why != "":
			skipped += 1
			print("  %-28s %-12s %-14s (skipped: %s) at (%.1f, %.1f, %.1f)" % [civ.name,
				civ.occupation, civ.role, why, civ.global_position.x, civ.global_position.y,
				civ.global_position.z])
			continue
		var sched: StringName = civ.scheduled_action()
		var d_post: float = _xz(civ.global_position, civ.working_point_pos)
		var d_home: float = _xz(civ.global_position, civ.home)
		var d_tgt: float = _xz(civ.global_position, civ._wander_target)
		var speed: float = Vector2(civ.velocity.x, civ.velocity.z).length()
		var clip: String = civ.actor.current_action if civ.actor != null else "-"
		var bound: bool = _post_bound(civ, sched)
		var flag: String = ""
		# The resolver sends him to the post's nearest MESH point, not the raw marker. A
		# marker off the mesh by more than the tolerance is content to fix, not a man in
		# the wrong place - named, counted apart, not failed.
		var post_nav: Vector3 = Vector3.ZERO
		if bound and civ.working_point_pos != Vector3.ZERO:
			post_nav = civ._router.nearest_mesh_point(civ.working_point_pos)
			var d_nav: float = _xz(civ.global_position, post_nav)
			if d_nav <= ARRIVED_M:
				arrived_here += 1
			elif d_nav > WRONG_PLACE_M:
				away_here += 1
		if bound and civ.working_point_pos != Vector3.ZERO and d_post > WRONG_PLACE_M:
			var aiming: bool = _xz(civ._wander_target, post_nav) <= 1.0
			if aiming and _xz(civ.global_position, post_nav) <= WRONG_PLACE_M:
				flag = "post off-mesh by %.1fm" % _xz(post_nav, civ.working_point_pos)
				_offmesh += 1
			elif not aiming:
				flag = "WRONG-TARGET"
				wrong_here += 1
			elif speed > WALKING_MPS:
				flag = "walking"
				walking += 1
			else:
				# Off the mesh (a quarters spot inside a carved footprint), off the floor, or no
				# route at all: the three ways a man aimed at his post stands still. The route is
				# asked of the map directly, from where he stands to where the resolver sent him -
				# under two points is the server's own "no path".
				var map: RID = civ.get_world_3d().navigation_map
				var mesh_pt: Vector3 = NavigationServer3D.map_get_closest_point(map,
					civ.global_position)
				var route: int = NavigationServer3D.map_get_path(map, civ.global_position,
					post_nav, true).size()
				# A map route with a man who does not walk it is either the agent calling itself
				# finished, or the body sliding against something the mesh never carved.
				var agent: NavigationAgent3D = civ._router.agent
				var fin: String = "no agent" if agent == null else (
					"agent FINISHED %.1fm short" % _xz(civ.global_position, agent.target_position)
					if agent.is_navigation_finished() else "agent pathing %d pts"
					% agent.get_current_navigation_path().size())
				# The floor is a slide contact every frame; what stops him is the steepest contact.
				# Reported by angle from up, against the body's own climb limit, so a 50-degree
				# sandbag skirt (floor to a flat-normal test, wall to the physics) is named.
				var wall: String = "no contact"
				var steepest: float = -1.0
				var limit: float = rad_to_deg(civ.floor_max_angle)
				for ci in range(civ.get_slide_collision_count()):
					var hit: KinematicCollision3D = civ.get_slide_collision(ci)
					if hit == null:
						continue
					var deg: float = rad_to_deg(hit.get_angle())
					if deg > steepest:
						steepest = deg
						var col: Object = hit.get_collider()
						wall = "%s '%s' at %.0f deg (limit %.0f)" % [
							"BLOCKED by" if deg > limit else "on",
							(col as Node).name if col is Node else "?", deg, limit]
				# What the mover is actually handed: the router's step for this man toward his own
				# target (the same call _step_toward makes), the speed the tree gave him, and
				# whether the target sits inside his baked box (outside it the router steers direct).
				var step: Vector3 = civ._router.step(civ.global_position, civ._wander_target)
				var inbox: bool = civ._router.box >= 0 \
					and NavBaker.box_contains(civ._router.box, civ._wander_target)
				# The agent advances past a path point only when the man is within
				# path_desired_distance of it in THREE dimensions; a mesh that sits under or over
				# his feet keeps him on the first point forever while his XZ step reads as arrived.
				var nxt: String = "-"
				if agent != null:
					var np: Vector3 = agent.get_next_path_position()
					nxt = "next xz %.2fm dy %+.2fm" % [_xz(civ.global_position, np),
						np.y - civ.global_position.y]
				# A body that slides to zero on a flat floor with nothing in front of it is INSIDE
				# something: ask the space what overlaps his capsule, excluding himself.
				var inside: String = "inside nothing"
				var col_node: CollisionShape3D = civ.get_node_or_null("CollisionShape3D") as CollisionShape3D
				if col_node != null and col_node.shape != null:
					var q := PhysicsShapeQueryParameters3D.new()
					q.shape = col_node.shape
					q.transform = col_node.global_transform
					q.collision_mask = 1
					q.exclude = [civ.get_rid()]
					var hits: Array[Dictionary] = space.intersect_shape(q, 6)
					if not hits.is_empty():
						var names: PackedStringArray = []
						for hd in hits:
							var o: Object = hd.get("collider")
							names.append((o as Node).name if o is Node else "?")
						inside = "inside %s" % ", ".join(names)
				# The body's own answer to "what stops a 10 cm step toward the target?"
				var probe: String = "10cm step free"
				var ahead := Vector3(step.x, 0.0, step.z)
				if ahead.length() > 0.001:
					var kc := KinematicCollision3D.new()
					if civ.test_move(civ.global_transform, ahead.normalized() * 0.1, kc):
						var c: Object = kc.get_collider()
						# The blocker's top over his feet decides whether the bake called it a
						# step (agent_max_climb) while the body calls it a wall.
						var top: float = -99.0
						if c is CollisionObject3D:
							for ch in (c as Node).get_children():
								var cs := ch as CollisionShape3D
								if cs != null and cs.shape != null:
									var bb: AABB = cs.global_transform * cs.shape.get_debug_mesh().get_aabb()
									top = maxf(top, bb.end.y)
						probe = "10cm step HITS '%s' normal.y %.2f contact %+.2fm top %+.2fm" % [
							(c as Node).name if c is Node else "?", kc.get_normal().y,
							kc.get_position().y - civ.global_position.y,
							top - civ.global_position.y]
				flag = "STUCK (off-mesh %.2fm dy %+.2fm, %s, %s, %s, %s, step %.2fm, speed %.2f, inbox %s, %s, %s, %s)" % [
					_xz(civ.global_position, mesh_pt), mesh_pt.y - civ.global_position.y,
					"on floor" if civ.is_on_floor() else "OFF FLOOR y=%.2f" % civ.global_position.y,
					"NO ROUTE" if route < 2 else "route %d pts" % route, fin, wall,
					Vector2(step.x, step.z).length(), float(civ._bt_bb.get("speed", -1.0)),
					str(inbox), nxt, inside, probe]
				stuck_here += 1
		print("  %-28s %-12s %-14s %-10s->%-10s post %5.1fm home %5.1fm tgt %5.1fm tier %d box %2d v %.2f %-22s %s" % [
			civ.name, civ.occupation, civ.role, String(sched), String(civ.active_action),
			d_post, d_home, d_tgt, civ.lod_tier, civ._router.box, speed, clip, flag])
	for n in AgentRegistry.allies:
		var ally: Node3D = n as Node3D
		if ally == null or not is_instance_valid(ally) or not ally.is_inside_tree():
			continue
		if ally.has_method("is_dead") and bool(ally.call("is_dead")):
			continue
		# A parked body (pre-warmed, hidden, not ticking) is not in the world yet.
		if not ally.visible or not ally.is_physics_processing():
			continue
		bodies.append(ally)
		print("  %-28s ally squad=%-5s order=%-2s at (%.1f, %.1f, %.1f)" % [ally.name,
			str(ally.get("squad_member")), str(ally.get("order_mode")),
			ally.global_position.x, ally.global_position.y, ally.global_position.z])
	var overlaps_here: int = _count_overlaps(bodies)
	var roofs_here: int = 0
	if space != null:
		for b in bodies:
			var verdict: String = RoofS.roof_verdict(space, b)
			if verdict != "":
				roofs_here += 1
				print("  [ROOF] %s %s" % [b.name, verdict])
	_wrong += wrong_here
	_stuck += stuck_here
	_overlaps += overlaps_here
	_roofs += roofs_here
	_arrived += arrived_here
	_away += away_here
	print("[NPC-CENSUS %s] %d bodies (%d skipped: far/puppet/boarding/fled), %d wrong-target, %d stuck, %d still walking, %d overlaps, %d roofs | post-bound: %d ARRIVED, %d AWAY" % [
		label, bodies.size(), skipped, wrong_here, stuck_here, walking, overlaps_here, roofs_here,
		arrived_here, away_here])


func _post_bound(civ: Civilian, action: StringName) -> bool:
	if POST_ACTIONS.has(action):
		return true
	if civ.is_garrison and OFF_DUTY_AT_POST.has(action) \
			and POST_OFF_DUTY_OCCUPATIONS.has(civ.occupation):
		return true
	return false


func _count_overlaps(bodies: Array[Node3D]) -> int:
	var count: int = 0
	for i in range(bodies.size()):
		var a: Node3D = bodies[i]
		for j in range(i + 1, bodies.size()):
			var b: Node3D = bodies[j]
			if _xz(a.global_position, b.global_position) >= OVERLAP_XZ_M:
				continue
			if absf(a.global_position.y - b.global_position.y) >= OVERLAP_Y_M:
				continue
			var a_pup: bool = bool(a.get("puppet")) if a is Civilian else false
			var b_pup: bool = bool(b.get("puppet")) if b is Civilian else false
			if a_pup and b_pup:
				# Both bodies are placed by a driver (a litter team, a crew): its stage, not a stack.
				print("  [overlap, staged] %s / %s" % [a.name, b.name])
				continue
			count += 1
			print("  [OVERLAP] %s / %s at %.2fm" % [a.name, b.name,
				_xz(a.global_position, b.global_position)])
	return count


static func _xz(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()
