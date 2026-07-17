## spooky_gunship.gd - AC-47 "Spooky": orbits the target area for DURATION
## seconds pouring tracer fire into it.
class_name SpookyGunship
extends Node3D

const ORBIT_RADIUS: float = 160.0
const ORBIT_ALT: float = 130.0
const DURATION: float = 30.0
const BURST_INTERVAL: float = 0.35

var target: Vector3
var terrain: TerrainManager
var _angle: float = 0.0
var _age: float = 0.0
var _burst_timer: float = 0.0
var _drone: AudioStreamPlayer3D


static func call_in(parent: Node, terrain_manager: TerrainManager, target_pos: Vector3) -> SpookyGunship:
	var spooky := SpookyGunship.new()
	spooky.terrain = terrain_manager
	spooky.target = target_pos
	parent.add_child(spooky)
	spooky.global_position = target_pos + Vector3(ORBIT_RADIUS, ORBIT_ALT, 0)
	return spooky


func _ready() -> void:
	# Silhouette placeholder: stretched box until a C-47 model exists (art list).
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(18.0, 3.0, 3.5)
	mesh.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.15, 0.15, 0.14)
	mesh.material_override = mat
	add_child(mesh)
	var drone_stream := load("res://assets/audio/sfx/rotor_loop.wav") as AudioStreamWAV
	if drone_stream:
		drone_stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		drone_stream.loop_end = drone_stream.data.size() / 2
		_drone = AudioStreamPlayer3D.new()
		_drone.stream = drone_stream
		_drone.pitch_scale = 0.55
		_drone.volume_db = 6.0
		_drone.max_distance = 500.0
		_drone.unit_size = 40.0
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

	_burst_timer -= delta
	if _burst_timer <= 0.0:
		_burst_timer = BURST_INTERVAL
		_fire_burst()


func _fire_burst() -> void:
	var a := randf_range(0.0, TAU)
	var r := sqrt(randf()) * 25.0
	var impact := target + Vector3(cos(a) * r, 0.0, sin(a) * r)
	if terrain:
		impact.y = terrain.get_height_at(impact)
	for i in range(3):
		var jitter := Vector3(randf_range(-2, 2), 0, randf_range(-2, 2))
		BulletTracer.spawn_tracer(get_tree().current_scene, global_position, impact + jitter, Color(1.0, 0.25, 0.15))
	for e in get_tree().get_nodes_in_group("enemies"):
		var enemy := e as EnemyBase
		if enemy and not enemy.is_dead() and enemy.global_position.distance_to(impact) < 4.0:
			enemy.take_damage(60, Enums.DamageType.PHYSICAL, null)
	var player := GameManager.player as Node3D
	if player and player.global_position.distance_to(impact) < 3.0 and player.has_method("take_damage"):
		player.take_damage(50, Enums.DamageType.PHYSICAL, null)  # danger close is real
	GunFX.impact(get_tree().current_scene, impact, Vector3.UP, false)
	NoiseBus.emit_noise(NoiseBus.NoiseType.GUNSHOT, impact, 0, 80.0)
