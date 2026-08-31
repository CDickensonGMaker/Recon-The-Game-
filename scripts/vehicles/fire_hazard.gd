## fire_hazard.gd - Napalm burn area: damages bodies inside it over time.
class_name FireHazard
extends Area3D

## Preloaded rather than referenced by class_name: global classes are not
## registered until the editor rescans, so a fresh script would fail every
## headless run until someone opened the editor.
const BURNING := preload("res://scripts/combat/burning.gd")

@export var damage_per_second: float = 25.0
@export var duration: float = 15.0
@export var hazard_radius: float = 10.0

## ADR-026 caps real-time lights at 8 on screen, 0 shadow-casting. Burning ground
## draws against that budget so napalm reads as a light source at night; a napalm
## run lays 9 patches, so the pool is capped and the rest keep the glow quad alone.
const MAX_FIRE_LIGHTS: int = 4
const FIRE_LIGHT_ENERGY: float = 6.0
const FIRE_LIGHT_FADE_S: float = 3.0
static var _fire_lights: int = 0

## Secondary fires are the ones a non-incendiary blast starts by chance. Capped
## separately so a napalm run (9 patches) is never squeezed out by grenade fires.
const MAX_SECONDARY_FIRES: int = 6
static var active: Array[FireHazard] = []
var is_secondary: bool = false

var _tick_timer: float = 0.0
var _life: float = 0.0
var _light: OmniLight3D = null
var _light_checked: bool = false
var _flicker: float = 1.0


## Build one patch and drop it, so the FIRST napalm canister of a mission does not
## pay the flame/smoke sheet loads mid-flight. Measured cold on a fresh arena
## (tools/probe_raid_cost.tscn, 2026-08-31): create_at cost 68.013 ms the first time
## against a warm cost under 1 ms - the sheets it pulls through GunFX._sheet_mat
## ("sheets/fire_loop_sheet") are not the ones the explosion path loads, so warming
## GunFX alone still left 27.497 ms on the first burn. Idempotent.
static var _warmed: bool = false


static func warm(parent: Node) -> void:
	if _warmed or parent == null or not is_instance_valid(parent):
		return
	_warmed = true
	var h: FireHazard = create_at(parent, Vector3(0.0, -1000.0, 0.0), 4.0, 0.01)
	if h != null and is_instance_valid(h):
		active.erase(h)
		h.queue_free()


static func create_at(parent: Node, pos: Vector3, radius: float = 10.0, dur: float = 15.0) -> FireHazard:
	SpawnLedger.note("fire_hazard")
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
	active.append(hazard)
	hazard._build_visual(radius)
	# Scorch outlives the fire: parented to the WORLD, FIFO-capped by GunFX.
	GunFX._scorch(parent, pos, radius / 1.2)
	return hazard


## Burning ground: an additive glow quad plus, for the first MAX_FIRE_LIGHTS
## hazards alight, one non-shadow OmniLight inside the ADR-026 budget.
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
	# anim_speed defaults to 0, which freezes the flipbook on one static frame -
	# the fire must ADVANCE, and the offset only staggers where each starts.
	fproc.anim_speed_min = 1.0
	fproc.anim_speed_max = 1.0
	fproc.anim_offset_max = 1.0   # desync the loops or the field breathes in unison
	flames.process_material = fproc
	# Alpha, not additive: the sheet's soot is baked around the flame and
	# additive blending would erase it (black adds to nothing).
	var fmat := GunFX._sheet_mat("napalm_flame_mat", "sheets/fire_loop_sheet", 4, 4, false)
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
		GunFX._sheet_mat("napalm_smoke_mat", "sheets/smoke_loop_sheet", 4, 4, false))
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
	gmat.albedo_texture = GunFX._fx_tex("particles/fire_glow")
	gmat.albedo_color = Color(1.0, 0.62, 0.28, 0.6)
	gmat.emission_enabled = true
	gmat.emission = Color(1.0, 0.4, 0.0)
	gmat.emission_energy_multiplier = 2.4
	glow.material_override = gmat
	glow.rotation_degrees.x = -90.0
	glow.position.y = 0.12
	add_child(glow)


func _physics_process(delta: float) -> void:
	_life += delta
	if _life >= duration:
		queue_free()
		return

	# Claimed on the first tick, not in create_at: damage_per_second is assigned by
	# the caller AFTER construction, and the 0-dps shader-warm hazard must not take
	# a light from the pool.
	if not _light_checked:
		_light_checked = true
		if damage_per_second > 0.0 and _fire_lights < MAX_FIRE_LIGHTS:
			_fire_lights += 1
			_light = OmniLight3D.new()
			_light.light_color = Color(1.0, 0.52, 0.20)
			_light.omni_range = hazard_radius * 2.6
			_light.shadow_enabled = false
			_light.position.y = 1.0
			add_child(_light)
	if _light != null:
		_flicker = lerpf(_flicker, randf_range(0.68, 1.0), clampf(delta * 7.0, 0.0, 1.0))
		var fade: float = clampf((duration - _life) / FIRE_LIGHT_FADE_S, 0.0, 1.0)
		_light.light_energy = FIRE_LIGHT_ENERGY * _flicker * fade
	_tick_timer += delta
	if _tick_timer < 0.5:
		return
	_tick_timer = 0.0
	# A hazard that does no damage does not set men alight. game_world.gd:230
	# spawns a 0-dps FireHazard purely to warm the shaders at level load, right
	# where the squad spawns - without this guard it ignites the whole squad on
	# the first frame of the main game.
	var lights_men: bool = damage_per_second > 0.0
	for body in get_overlapping_bodies():
		if body.has_method("take_damage"):
			body.take_damage(int(damage_per_second * 0.5), Enums.DamageType.FIRE, null)
		# Catching fire is not the same as standing in it: Burning rides the man
		# out of the strip and keeps burning him, so a runner does not escape by
		# clearing the radius.
		if lights_men and body is Node3D:
			var lit: Node = body.get_node_or_null("Burning")
			if lit != null:
				lit.call("refresh")
			else:
				var b: Node3D = BURNING.new()
				b.name = "Burning"
				body.add_child(b)
				b.call("setup", body)


func _exit_tree() -> void:
	active.erase(self)
	if _light != null:
		_fire_lights = maxi(0, _fire_lights - 1)
		_light = null


## Is anything already alight within `dist` of here? Stops a secondary fire from
## stacking on top of the napalm or WP patch that just lit the same ground.
static func burning_near(pos: Vector3, dist: float) -> bool:
	for h in active:
		if is_instance_valid(h) and h.global_position.distance_to(pos) < dist:
			return true
	return false


static func secondary_count() -> int:
	var n: int = 0
	for h in active:
		if is_instance_valid(h) and h.is_secondary:
			n += 1
	return n
