## claymore.gd - Player-placed directional mine (W58). "FRONT TOWARD ENEMY."
class_name Claymore
extends Node3D

const TRIGGER_RANGE: float = 9.0
const TRIGGER_HALF_ANGLE_DEG: float = 35.0

var _armed: bool = false
var _scan_timer: float = 0.0


static func place(parent: Node, pos: Vector3, facing: Vector3) -> Claymore:
	var mine := Claymore.new()
	parent.add_child(mine)
	mine.global_position = pos
	if facing.length() > 0.1:
		mine.look_at(pos + Vector3(facing.x, 0, facing.z).normalized(), Vector3.UP)
	# Real M18A1 model (Caleb, 2026-07-10). Green-box fallback kept for safety.
	var scene: PackedScene = load("res://assets/world/props/claymore.glb")
	if scene != null:
		mine.add_child(scene.instantiate())
	else:
		var vis := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.22, 0.14, 0.04)
		vis.mesh = box
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.15, 0.2, 0.12)
		vis.material_override = mat
		vis.position = Vector3(0, 0.1, 0)
		mine.add_child(vis)
	mine.get_tree().create_timer(2.0).timeout.connect(func() -> void: mine._armed = true)
	return mine


func _physics_process(delta: float) -> void:
	if not _armed:
		return
	_scan_timer += delta
	if _scan_timer < 0.5:
		return
	_scan_timer = 0.0
	var forward := -global_transform.basis.z
	for e in get_tree().get_nodes_in_group("enemies"):
		var enemy := e as EnemyBase
		if enemy == null or enemy.is_dead():
			continue
		var to_enemy := enemy.global_position - global_position
		if to_enemy.length() > TRIGGER_RANGE:
			continue
		var flat := Vector3(to_enemy.x, 0, to_enemy.z).normalized()
		if forward.dot(flat) >= cos(deg_to_rad(TRIGGER_HALF_ANGLE_DEG)):
			_detonate()
			return


func _detonate() -> void:
	CombatManager.apply_explosion_damage(global_position + -global_transform.basis.z * 4.0, 160, 50, 8.0, null)
	DamageSystem.apply_damage(global_position, DamageSystem.DamageType.SMALL_EXPLOSION, 0.6)
	NoiseBus.emit_noise(NoiseBus.NoiseType.EXPLOSION, global_position, 0)
	GunFX.play_explosion_3d(get_tree().current_scene, global_position)
	queue_free()
