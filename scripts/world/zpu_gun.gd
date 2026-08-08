## zpu_gun.gd - The camp's ZPU AA gun (S28). Fires visible/audible bursts at any
## aircraft overhead; the actual kill is a CHANCE ROLL handed to PilotRecovery,
## and only against a transiting Skyraider (one airframe, one event - the S28
## tripwire). No crew animations: the unmanned-bunker precedent.
##
## Silencing mirrors CampMortar (camp_mortar.gd): crew dead OR gun destroyed,
## latched for the day. A destroyed gun banks the existing AA payoff -
## `aa_killed` already has a reader at campaign_state.gd:249.
##
## `ambient` mode (attach_ambient) is the same gun as pure atmosphere: distant
## tracer streams from the deep jungle. No mesh, no crew, no kill roll, and it
## must stay that way - only the camp gun is real.
class_name ZpuGun
extends Node3D

const MODEL: String = "res://assets/world/building models/structures/emplacements_real/zpu_aa_gun.glb"
const WEAPON: String = "res://data/weapons/aircraft_20mm.tres"
## Horizontal reach. An overflight crosses the whole AO; this keeps the gun a
## CAMP sound, not a map-wide one.
const ENGAGE_M: float = 420.0
const BURST_ROUNDS: int = 4
const ROUND_GAP_S: float = 0.13
const GAP_MIN_S: float = 1.6
const GAP_MAX_S: float = 3.4
## Deliberate scatter: the bursts are the AO's theatre, the kill is the roll.
const MISS_M: float = 14.0
const KILL_CHANCE: float = 0.35
## Ambient cadence (owner-retunable): long quiet stretches so the map's corners
## speak occasionally, never over the camp gun.
const AMB_GAP_MIN_S: float = 7.0
const AMB_GAP_MAX_S: float = 16.0
const AMB_ENGAGE_CHANCE: float = 0.55

var director: FieldDirector = null
var tube: Destructible = null
var crew_tag: String = ""
## Atmosphere-only mode (decree 2026-08-07): no crew, no Destructible, no kill
## roll, no NoiseBus - a distant tracer stream and nothing else.
var ambient: bool = false
var burst_rounds: int = BURST_ROUNDS
var round_gap_s: float = ROUND_GAP_S
var gap_min_s: float = GAP_MIN_S
var gap_max_s: float = GAP_MAX_S

var _target: Node3D = null
var _muzzle_h: float = 1.6
var _poll: float = 0.0
var _burst_gap: float = 0.0
var _crew_seen: bool = false
var _silenced: bool = false
var _rolled: Dictionary = {}
var _pass_roll: Dictionary = {}
static var _wd: WeaponData = null
## Unseeded on purpose: AA fire timing is ambient life, not replayable layout
## (same exemption as AmbientWar/AirTraffic, demo_game.gd:9-11).
var _rng := RandomNumberGenerator.new()


static func attach(world: Node, field_director: FieldDirector, pos: Vector3,
		face_toward: Vector3, tag: String) -> ZpuGun:
	var mesh: Mesh = _first_mesh()
	if mesh == null:
		push_warning("[ZPU] %s carries no mesh - the gun does not stand" % MODEL)
		return null
	var zg := ZpuGun.new()
	zg.name = "ZpuGun"
	zg.director = field_director
	zg.crew_tag = tag
	zg._muzzle_h = maxf(1.2, mesh.get_aabb().size.y)
	world.add_child(zg)
	zg.add_to_group("zpu_guns")
	zg.global_position = pos
	zg.tube = FireSupportBench.spawn_lifted(world, mesh, pos, "zpu_aa_gun",
		Destructible.hp_for("sandbag_wall"))
	var flat := Vector3(face_toward.x - pos.x, 0.0, face_toward.z - pos.z)
	if flat.length() > 1.0:
		zg.tube.global_rotation.y = atan2(flat.x, flat.z)
	zg._burst_gap = zg._rng.randf_range(GAP_MIN_S, GAP_MAX_S)
	print("[ZPU] standing at the camp, tag '%s'" % tag)
	return zg


## One class, one mode: an ambient point is a ZpuGun with everything that makes
## it a GUN switched off - no mesh, no Destructible, no crew, no director, so
## silenced() can never latch and the siege deference never applies. Burst
## character rolls per point so different corners of the map sound different.
static func attach_ambient(world: Node, pos: Vector3) -> ZpuGun:
	var zg := ZpuGun.new()
	zg.name = "AmbientZpu"
	zg.ambient = true
	zg.gap_min_s = AMB_GAP_MIN_S
	zg.gap_max_s = AMB_GAP_MAX_S
	zg.burst_rounds = zg._rng.randi_range(3, 6)
	zg.round_gap_s = zg._rng.randf_range(0.11, 0.17)
	world.add_child(zg)
	zg.add_to_group("zpu_guns")
	zg.global_position = pos
	zg._burst_gap = zg._rng.randf_range(zg.gap_min_s, zg.gap_max_s)
	return zg


static func _first_mesh() -> Mesh:
	var ps: PackedScene = load(MODEL) as PackedScene
	if ps == null:
		return null
	var inst: Node = ps.instantiate()
	var found: Mesh = null
	var stack: Array[Node] = [inst]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for c in n.get_children():
			stack.append(c)
		var mi := n as MeshInstance3D
		if mi != null and mi.mesh != null:
			found = mi.mesh
			break
	inst.free()
	return found


func silenced() -> bool:
	if _silenced:
		return true
	if tube != null and is_instance_valid(tube) and tube.is_destroyed():
		_silence("gun destroyed")
		if director != null and is_instance_valid(director):
			director.state.flags["aa_killed"] = int(director.state.flags.get("aa_killed", 0)) + 1
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
	_target = null
	set_physics_process(false)
	print("[ZPU] silenced (%s) - no more AA fire today" % reason)


func _physics_process(delta: float) -> void:
	_poll += delta
	if _poll >= 1.0:
		_poll = 0.0
		_think()
	if _silenced or _target == null or not is_instance_valid(_target):
		return
	_burst_gap -= minf(delta, 0.066)
	if _burst_gap <= 0.0:
		_burst_gap = _rng.randf_range(gap_min_s, gap_max_s)
		_fire_burst()


func _think() -> void:
	if silenced():
		return
	# The assault owns the night's noise budget, same deference as CampMortar.
	if director != null and director.siege != null and is_instance_valid(director.siege) \
			and director.siege.active:
		_target = null
		return
	_target = _acquire()
	if _target == null:
		return
	if ambient:
		if not _wants_pass(_target):
			_target = null
		return
	_roll_kill(_target)


## Ambient points sit out some flights entirely - one decision per airframe, so
## a point that passes stays quiet for the whole pass and the corners take turns.
func _wants_pass(t: Node3D) -> bool:
	var id: int = t.get_instance_id()
	if not _pass_roll.has(id):
		_pass_roll[id] = _rng.randf() < AMB_ENGAGE_CHANCE
	return bool(_pass_roll[id])


func _acquire() -> Node3D:
	if get_tree() == null:
		return null
	var best: Node3D = null
	var best_d: float = ENGAGE_M
	for n in get_tree().get_nodes_in_group("air_traffic"):
		var a := n as Node3D
		if a == null or not is_instance_valid(a):
			continue
		var d: float = Vector2(a.global_position.x - global_position.x,
			a.global_position.z - global_position.z).length()
		if d < best_d:
			best_d = d
			best = a
	return best


## One roll per flight, ever - a plane that survives the pass has escaped.
func _roll_kill(t: Node3D) -> void:
	var id: int = t.get_instance_id()
	if _rolled.has(id):
		return
	_rolled[id] = true
	var plane := t as CASAirplane
	if plane == null or _flight_kind(t) != "skyraider":
		return
	if not plane.in_transit() or plane.is_shot_down():
		return
	if _rng.randf() >= KILL_CHANCE:
		return
	var pr := get_tree().get_first_node_in_group("pilot_recovery") as PilotRecovery
	if pr != null:
		pr.request_down(plane)


func _flight_kind(n: Node) -> String:
	var at := get_parent().get_node_or_null(^"AirTraffic") as AirTraffic
	if at == null:
		return ""
	for f in at.get_in_flight():
		if (f as Dictionary).get("node") == n:
			return str((f as Dictionary).get("kind", ""))
	return ""


func _fire_burst() -> void:
	var tree: SceneTree = get_tree()
	if tree == null or CombatManager.bullets == null:
		return
	if _wd == null:
		_wd = load(WEAPON) as WeaponData
	if _wd == null:
		return
	# Ambient fire is scenery, not an AI perception event - a NoiseBus ping would
	# steer the ground fight toward a gun that is not really there.
	if not ambient:
		NoiseBus.emit_noise(NoiseBus.NoiseType.GUNSHOT, global_position, 0, 260.0)
	for i in range(burst_rounds):
		tree.create_timer(float(i) * round_gap_s).timeout.connect(func() -> void:
			if not is_instance_valid(self) or _silenced:
				return
			if _target == null or not is_instance_valid(_target):
				return
			_fire_round())


func _fire_round() -> void:
	var muzzle: Vector3 = global_position + Vector3.UP * _muzzle_h
	var miss := Vector3(_rng.randf_range(-1.0, 1.0), _rng.randf_range(-0.4, 0.4),
		_rng.randf_range(-1.0, 1.0)) * MISS_M
	var aim: Vector3 = (_target.global_position + miss - muzzle).normalized()
	var excl: Array = [tube] if tube != null else []
	# World-only mask: the theatre must never rake the camp fight below it.
	CombatManager.bullets.fire(_wd, self, muzzle, aim, 1, excl, true, false)
	GunFX.play_shot_3d(get_tree().current_scene, muzzle, _wd)
	GunFX.muzzle_flash(get_tree().current_scene, muzzle)
