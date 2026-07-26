## spectre_gunship.gd - AC-130 "Spectre": orbits the target pouring down a mixed
## battery. Two guns with two rhythms is the whole identity of the aircraft:
##
##   20mm Vulcan - saturation. A continuous sheet of tracer into a wide beaten
##     zone. Individual rounds are not modelled; a burst lands as one small blast.
##   40mm Bofors - punch. Real shells on real arcs, slow enough to hear coming and
##     to count, each one a shell the pool will not recycle out from under you.
class_name SpectreGunship
extends Node3D

const AIRFRAME_SCENE: PackedScene = preload("res://assets/us/aircraft/ac47_spooky.glb")
## Night orbit bird, heard more than seen: cull the airframe past ~1200m.
const VIS_END_M: float = 1200.0
const VIS_MARGIN_M: float = 80.0

const ORBIT_RADIUS: float = 160.0
const ORBIT_ALT: float = 130.0
const DURATION: float = 30.0

const VULCAN_INTERVAL: float = 0.35
const VULCAN_ROUNDS_PER_BURST: int = 3
const VULCAN_DAMAGE: int = 60

const BOFORS_INTERVAL: float = 1.2
## The 40mm walks the inner half of the zone - the heavy gun is aimed, the Vulcan
## saturates.
const BOFORS_ZONE_FRAC: float = 0.55
const BOFORS_SHELL: String = "res://data/projectiles/spectre_40mm.tres"
const BOFORS_BLAST_M: float = 5.0
const BOFORS_DAMAGE: int = 120

var target: Vector3
var terrain: TerrainManager
var _angle: float = 0.0
var _age: float = 0.0
var _vulcan_timer: float = 0.0
var _bofors_timer: float = 0.6
var _drone: AudioStreamPlayer3D


static func call_in(parent: Node, terrain_manager: TerrainManager, target_pos: Vector3) -> SpectreGunship:
	var ship := SpectreGunship.new()
	ship.terrain = terrain_manager
	ship.target = target_pos
	parent.add_child(ship)
	ship.global_position = target_pos + Vector3(ORBIT_RADIUS, ORBIT_ALT, 0)
	return ship


func _ready() -> void:
	var airframe := AIRFRAME_SCENE.instantiate() as Node3D
	airframe.name = "Airframe"
	# The GLB's nose points +Z (cockpit +Z, tail fins -Z); the node flies
	# along -Z via look_at, so the model mounts flipped 180 about Y.
	airframe.rotation.y = PI
	add_child(airframe)
	var stack: Array[Node] = [airframe]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		var mi := n as MeshInstance3D
		if mi != null:
			mi.visibility_range_end = VIS_END_M
			mi.visibility_range_end_margin = VIS_MARGIN_M
		for c in n.get_children():
			stack.push_back(c)
	var anim := airframe.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if anim != null and anim.has_animation("prop_spin"):
		anim.get_animation("prop_spin").loop_mode = Animation.LOOP_LINEAR
		anim.play("prop_spin")
	var drone_stream := load("res://assets/audio/sfx/rotor_loop.wav") as AudioStreamWAV
	if drone_stream:
		drone_stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		@warning_ignore("integer_division")
		drone_stream.loop_end = drone_stream.data.size() / 2
		_drone = AudioStreamPlayer3D.new()
		_drone.stream = drone_stream
		_drone.pitch_scale = 0.5
		_drone.volume_db = 6.0
		_drone.max_distance = 600.0
		_drone.unit_size = 45.0
		add_child(_drone)
		_drone.play()


func _physics_process(delta: float) -> void:
	_age += delta
	if _age >= DURATION:
		var out_dir := Vector3(1, 0.2, 0.3).normalized()
		global_position += out_dir * 60.0 * delta
		look_at(global_position + out_dir, Vector3.UP)
		if _age > DURATION + 8.0:
			queue_free()
		return
	# Left pylon turn: the angle runs backwards so the port side - where an
	# AC-47's miniguns point - faces the orbit centre while the nose leads.
	_angle -= delta * 0.35
	var desired := target + Vector3(cos(_angle) * ORBIT_RADIUS, ORBIT_ALT, sin(_angle) * ORBIT_RADIUS)
	global_position = global_position.lerp(desired, delta * 2.0)
	look_at(global_position + Vector3(sin(_angle), 0.0, -cos(_angle)), Vector3.UP)

	_vulcan_timer -= delta
	if _vulcan_timer <= 0.0:
		_vulcan_timer = VULCAN_INTERVAL
		_fire_vulcan()

	_bofors_timer -= delta
	if _bofors_timer <= 0.0:
		_bofors_timer = BOFORS_INTERVAL
		_fire_bofors()


## A point inside the beaten zone, uniformly distributed over the disc.
func _zone_point(frac: float) -> Vector3:
	var a := randf_range(0.0, TAU)
	var r := sqrt(randf()) * FirePlan.SPECTRE_BEATEN_M * frac
	var p := target + Vector3(cos(a) * r, 0.0, sin(a) * r)
	if terrain:
		p.y = terrain.get_height_at(p)
	return p


func _fire_vulcan() -> void:
	var impact := _zone_point(1.0)
	for i in range(VULCAN_ROUNDS_PER_BURST):
		var jitter := Vector3(randf_range(-2, 2), 0, randf_range(-2, 2))
		BulletTracer.spawn_tracer(get_tree().current_scene, global_position, impact + jitter, Color(1.0, 0.25, 0.15))
	@warning_ignore("integer_division")
	CombatManager.apply_explosion_damage(impact, VULCAN_DAMAGE, VULCAN_DAMAGE / 3, FirePlan.SPECTRE_VULCAN_KILL_M, null, 0.2)
	GunFX.impact(get_tree().current_scene, impact, Vector3.UP, false)
	NoiseBus.emit_noise(NoiseBus.NoiseType.GUNSHOT, impact, 0, 80.0)


func _fire_bofors() -> void:
	var data: ProjectileData = load(BOFORS_SHELL) as ProjectileData
	if data == null:
		return
	var impact := _zone_point(BOFORS_ZONE_FRAC)
	var flight: float = maxf(0.6, global_position.distance_to(impact) / data.speed)
	Ballistics.fire_arc(data, global_position, impact, flight, terrain, func(at: Vector3) -> void:
		@warning_ignore("integer_division")
		CombatManager.apply_explosion_damage(at, BOFORS_DAMAGE, BOFORS_DAMAGE / 4, BOFORS_BLAST_M, null)
		GunFX.play_explosion_3d(get_tree().current_scene, at, "explosion_40mm")
		NoiseBus.emit_noise(NoiseBus.NoiseType.EXPLOSION, at, 0))
