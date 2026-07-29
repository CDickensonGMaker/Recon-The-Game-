## fire_hazard.gd - Napalm burn area: damages bodies inside it over time.
class_name FireHazard
extends Area3D

@export var damage_per_second: float = 25.0
@export var duration: float = 15.0
@export var hazard_radius: float = 10.0

var _tick_timer: float = 0.0
var _life: float = 0.0


static func create_at(parent: Node, pos: Vector3, radius: float = 10.0, dur: float = 15.0) -> FireHazard:
	var hazard := FireHazard.new()
	hazard.hazard_radius = radius
	hazard.duration = dur
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = radius
	shape.shape = sphere
	hazard.add_child(shape)
	hazard.collision_layer = 0
	hazard.collision_mask = 2 | 4  # player + enemies (allies share layer 2)
	parent.add_child(hazard)
	hazard.global_position = pos
	hazard._build_visual(radius)
	# Scorch outlives the fire: parented to the WORLD, FIFO-capped by GunFX.
	GunFX._scorch(parent, pos, radius / 1.2)
	return hazard


## Burning ground (ADR-026: zero real lights - the "glow" is an additive quad).
## Flame coverage must reach the FULL damage radius: a gap the player reads as
## safe lane that still burns is a Fairness violation.
func _build_visual(radius: float) -> void:
	var flames := GPUParticles3D.new()
	flames.amount = clampi(int(radius * 2.6), 8, 32)
	flames.lifetime = 1.4
	flames.local_coords = true
	var fproc := ParticleProcessMaterial.new()
	fproc.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	fproc.emission_ring_axis = Vector3.UP
	fproc.emission_ring_height = 0.2
	fproc.emission_ring_radius = radius * 0.9
	fproc.emission_ring_inner_radius = 0.0
	fproc.direction = Vector3.UP
	fproc.spread = 5.0
	fproc.initial_velocity_min = 0.1
	fproc.initial_velocity_max = 0.4
	fproc.gravity = Vector3.ZERO
	fproc.scale_min = 0.7
	fproc.scale_max = 1.3
	fproc.anim_offset_max = 1.0   # desync the loops or the field breathes in unison
	flames.process_material = fproc
	var fmat := GunFX._sheet_mat("napalm_flame_mat", "sheets/flame_sheet", 5, 5, true)
	fmat.particles_anim_loop = true
	flames.draw_pass_1 = GunFX._fx_quad("napalm_flame_quad", 2.0, fmat)
	flames.position.y = 0.7
	add_child(flames)

	var smoke := GPUParticles3D.new()
	smoke.amount = 10
	smoke.lifetime = 4.5
	smoke.local_coords = false   # pillar drifts in world space, not with parent
	var sproc := ParticleProcessMaterial.new()
	sproc.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	sproc.emission_sphere_radius = radius * 0.4
	sproc.direction = Vector3.UP
	sproc.spread = 8.0
	sproc.initial_velocity_min = 1.8
	sproc.initial_velocity_max = 3.0
	sproc.gravity = Vector3(0, 0.6, 0)
	sproc.scale_min = 2.0
	sproc.scale_max = 3.5
	sproc.color = Color(0.08, 0.07, 0.06)   # napalm burns BLACK and oily
	sproc.color_ramp = GunFX._smoke_fade_ramp()
	smoke.process_material = sproc
	smoke.draw_pass_1 = GunFX._fx_quad("napalm_smoke_quad", 2.6,
		GunFX._sheet_mat("napalm_smoke_mat", "sheets/puff_sheet", 4, 2, false))
	smoke.position.y = 1.5
	add_child(smoke)

	var glow := MeshInstance3D.new()
	var gq := QuadMesh.new()
	gq.size = Vector2(radius * 2.0, radius * 2.0)
	glow.mesh = gq
	var gmat := StandardMaterial3D.new()
	gmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	gmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	gmat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	gmat.albedo_texture = GunFX._fx_tex("particles/circle_05")
	gmat.albedo_color = Color(1.0, 0.45, 0.1, 0.35)
	gmat.emission_enabled = true
	gmat.emission = Color(1.0, 0.4, 0.0)
	gmat.emission_energy_multiplier = 1.6
	glow.material_override = gmat
	glow.rotation_degrees.x = -90.0
	glow.position.y = 0.12
	add_child(glow)


func _physics_process(delta: float) -> void:
	_life += delta
	if _life >= duration:
		queue_free()
		return
	_tick_timer += delta
	if _tick_timer < 0.5:
		return
	_tick_timer = 0.0
	for body in get_overlapping_bodies():
		if body.has_method("take_damage"):
			body.take_damage(int(damage_per_second * 0.5), Enums.DamageType.FIRE, null)
