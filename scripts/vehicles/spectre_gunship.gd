## spectre_gunship.gd - AC-130 "Spectre": orbits the target pouring down a mixed
## battery. Two guns with two rhythms is the whole identity of the aircraft:
##
##   20mm Vulcan - saturation. A continuous sheet of tracer into a wide beaten
##     zone. Individual rounds are not modelled; a burst lands as one small blast.
##   40mm Bofors - punch. Real shells on real arcs, slow enough to hear coming and
##     to count, each one a shell the pool will not recycle out from under you.
class_name SpectreGunship
extends Node3D

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
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(29.0, 4.0, 4.5)
	mesh.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.13, 0.13, 0.12)
	mesh.material_override = mat
	add_child(mesh)
	var drone_stream := load("res://assets/audio/sfx/rotor_loop.wav") as AudioStreamWAV
	if drone_stream:
		drone_stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
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
		global_position += Vector3(1, 0.2, 0.3).normalized() * 60.0 * delta
		if _age > DURATION + 8.0:
			queue_free()
		return
	_angle += delta * 0.35
	var desired := target + Vector3(cos(_angle) * ORBIT_RADIUS, ORBIT_ALT, sin(_angle) * ORBIT_RADIUS)
	global_position = global_position.lerp(desired, delta * 2.0)
	look_at(target, Vector3.UP)

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
		CombatManager.apply_explosion_damage(at, BOFORS_DAMAGE, BOFORS_DAMAGE / 4, BOFORS_BLAST_M, null)
		GunFX.play_explosion_3d(get_tree().current_scene, at, "explosion_40mm")
		NoiseBus.emit_noise(NoiseBus.NoiseType.EXPLOSION, at, 0))
