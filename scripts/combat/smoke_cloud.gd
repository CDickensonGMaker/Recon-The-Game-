## smoke_cloud.gd - concealment volume: blocks AI sight lines through it.
class_name SmokeCloud
extends Node3D

static var active_clouds: Array[SmokeCloud] = []

@export var max_radius: float = 8.0
@export var duration: float = 25.0
@export var smoke_color: Color = Color(0.8, 0.35, 0.8)  ## goofy grape marking smoke

var _age: float = 0.0
var _puffs: GPUParticles3D
var _overlay: ColorRect


static func blocks_sight(from: Vector3, to: Vector3) -> bool:
	for cloud in active_clouds:
		if not is_instance_valid(cloud):
			continue
		var r: float = cloud.current_radius()
		if r < 1.0:
			continue
		# Segment-sphere intersection.
		var c := cloud.global_position + Vector3(0, 1.5, 0)
		var ab := to - from
		var t: float = clampf((c - from).dot(ab) / maxf(0.001, ab.length_squared()), 0.0, 1.0)
		if (from + ab * t).distance_to(c) <= r:
			return true
	return false


func current_radius() -> float:
	return max_radius * clampf(_age / 3.0, 0.1, 1.0) * (1.0 if _age < duration - 5.0 else clampf((duration - _age) / 5.0, 0.0, 1.0))


static func spawn_at(parent: Node, pos: Vector3, color: Color = Color(0.75, 0.75, 0.72)) -> SmokeCloud:
	var cloud := SmokeCloud.new()
	cloud.smoke_color = color
	parent.add_child(cloud)
	cloud.global_position = pos
	return cloud


## Billowing puff cluster. The whole node is UNIFORM-scaled to
## current_radius()/max_radius each frame, so the rendered cloud tracks the
## gameplay sphere exactly: at full scale, emission radius + max puff reach
## sums to max_radius. Rendering LARGER than blocks_sight() is a Fairness
## violation (reads concealed where the AI still sees).
func _ready() -> void:
	active_clouds.append(self)
	_puffs = GPUParticles3D.new()
	_puffs.amount = 28
	_puffs.lifetime = 4.0
	_puffs.local_coords = true
	var proc := ParticleProcessMaterial.new()
	proc.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	proc.emission_sphere_radius = max_radius * 0.62
	proc.direction = Vector3.UP
	proc.spread = 180.0
	proc.initial_velocity_min = 0.1
	proc.initial_velocity_max = 0.5
	proc.gravity = Vector3(0, 0.15, 0)
	proc.scale_min = 0.7
	proc.scale_max = 1.0
	proc.color = Color(smoke_color.r, smoke_color.g, smoke_color.b, 0.9)
	proc.color_ramp = GunFX._smoke_fade_ramp()
	_puffs.process_material = proc
	# quad 2.0 * scale 1.0 => half-extent ~1.0 * (max_radius*0.38) puff size cap
	_puffs.draw_pass_1 = GunFX._fx_quad("cloud_puff_quad_%d" % int(max_radius),
		max_radius * 0.76, GunFX._sheet_mat("cloud_puff_mat", "sheets/smoke_loop_sheet", 4, 4, false))
	_puffs.position = Vector3(0, 1.5, 0)
	add_child(_puffs)

	# Camera-inside overlay: standing IN the cloud must read as blind, both
	# because it is true (blocks_sight crosses you) and because peeking out of
	# smoke with a clear screen would be free wallhack-lite.
	var layer := CanvasLayer.new()
	add_child(layer)
	_overlay = ColorRect.new()
	_overlay.color = Color(smoke_color.r * 0.9, smoke_color.g * 0.9, smoke_color.b * 0.9, 0.0)
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_overlay)


func _physics_process(delta: float) -> void:
	_age += delta
	if _age >= duration:
		active_clouds.erase(self)
		queue_free()
		return
	var r := current_radius()
	# UNIFORM scale only: the mechanic sphere is round, and non-uniform scale
	# skews particle billboards.
	var s: float = maxf(0.05, r / max_radius)
	scale = Vector3.ONE * s
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	if cam != null and _overlay != null:
		var d: float = cam.global_position.distance_to(global_position + Vector3(0, 1.5, 0))
		var inside: float = clampf((r - d) / maxf(r * 0.35, 0.5), 0.0, 1.0)
		_overlay.color.a = 0.88 * inside


func _exit_tree() -> void:
	active_clouds.erase(self)
