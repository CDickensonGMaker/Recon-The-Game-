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
var _samples: int = 0


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
	print("[NPC-CENSUS] %d samples: %d wrong-target, %d stuck, %d overlaps, %d roofs, %d posts off the mesh (content, not counted)" % [
		_samples, _wrong, _stuck, _overlaps, _roofs, _offmesh])
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
		if bound and civ.working_point_pos != Vector3.ZERO and d_post > WRONG_PLACE_M:
			# The resolver sends him to the post's nearest MESH point, not the raw marker. A
			# marker off the mesh by more than the tolerance is content to fix, not a man in
			# the wrong place - named, counted apart, not failed.
			var post_nav: Vector3 = civ._router.nearest_mesh_point(civ.working_point_pos)
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
				# Off the mesh (a quarters spot inside a carved footprint) or off the floor: the
				# two ways a man aimed at his post stands still with the route in front of him.
				var mesh_pt: Vector3 = NavigationServer3D.map_get_closest_point(
					civ.get_world_3d().navigation_map, civ.global_position)
				flag = "STUCK (off-mesh %.2fm, %s)" % [_xz(civ.global_position, mesh_pt),
					"on floor" if civ.is_on_floor() else "OFF FLOOR y=%.2f" % civ.global_position.y]
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
	print("[NPC-CENSUS %s] %d bodies (%d skipped: far/puppet/boarding/fled), %d wrong-target, %d stuck, %d still walking, %d overlaps, %d roofs" % [
		label, bodies.size(), skipped, wrong_here, stuck_here, walking, overlaps_here, roofs_here])


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
