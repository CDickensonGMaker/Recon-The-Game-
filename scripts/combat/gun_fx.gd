## gun_fx.gd - Tight 2000s-FPS shot feedback (RTCW/MoHAA school): muzzle flash
## light+quad, impact puffs, positional gunshot audio. Budgeted (perf-first).
class_name GunFX
extends RefCounted

const SHOT_RIFLE := preload("res://assets/audio/sfx/shot_rifle.wav")
const SHOT_SMG := preload("res://assets/audio/sfx/shot_smg.wav")
const SHOT_PISTOL := preload("res://assets/audio/sfx/shot_pistol.wav")
const IMPACT_DIRT := preload("res://assets/audio/sfx/impact_dirt.wav")
const IMPACT_HARD := preload("res://assets/audio/sfx/impact_hard.wav")
const DRY_CLICK := preload("res://assets/audio/sfx/dry_click.wav")
const EXPLOSION := preload("res://assets/audio/sfx/explosion.wav")

const COMBAT_STING := preload("res://assets/audio/sfx/combat_sting.wav")
static var _sting_cooldown_until: int = 0


## W67: contact! drum sting, throttled.
static func play_combat_sting(parent: Node) -> void:
	var now := Time.get_ticks_msec()
	if now < _sting_cooldown_until:
		return
	_sting_cooldown_until = now + 25000
	var p := AudioStreamPlayer.new()
	p.stream = COMBAT_STING
	p.volume_db = -4.0
	parent.add_child(p)
	p.play()
	p.finished.connect(p.queue_free)


static var _active_flashes: int = 0
static var _active_impacts: int = 0
const MAX_FLASHES: int = 8
const MAX_IMPACTS: int = 12


static func shot_stream_for(weapon_name: String) -> AudioStream:
	var n := weapon_name.to_lower()
	if n.contains("1911") or n.contains("pistol"):
		return SHOT_PISTOL
	if n.contains("thompson") or n.contains("mp40") or n.contains("smg"):
		return SHOT_SMG
	return SHOT_RIFLE


## 3D positional gunshot (NPCs) - fire-and-forget.
static func play_shot_3d(parent: Node, pos: Vector3, weapon_name: String, volume_db: float = 2.0) -> void:
	var p := AudioStreamPlayer3D.new()
	p.stream = shot_stream_for(weapon_name)
	p.volume_db = volume_db
	p.max_distance = 220.0
	p.unit_size = 14.0
	p.pitch_scale = randf_range(0.94, 1.06)
	parent.add_child(p)
	p.global_position = pos
	p.play()
	p.finished.connect(p.queue_free)


## 2D player-weapon shot (always crisp in your ears).
static func play_shot_2d(parent: Node, weapon_name: String) -> void:
	var p := AudioStreamPlayer.new()
	p.stream = shot_stream_for(weapon_name)
	p.volume_db = -2.0
	p.pitch_scale = randf_range(0.96, 1.04)
	parent.add_child(p)
	p.play()
	p.finished.connect(p.queue_free)


static func play_click(parent: Node) -> void:
	var p := AudioStreamPlayer.new()
	p.stream = DRY_CLICK
	parent.add_child(p)
	p.play()
	p.finished.connect(p.queue_free)


static func play_explosion_3d(parent: Node, pos: Vector3) -> void:
	var p := AudioStreamPlayer3D.new()
	p.stream = EXPLOSION
	p.volume_db = 6.0
	p.max_distance = 400.0
	p.unit_size = 25.0
	parent.add_child(p)
	p.global_position = pos
	p.play()
	p.finished.connect(p.queue_free)


## Muzzle flash: warm omni light + emissive billboard quad, 45ms.
static func muzzle_flash(parent: Node, pos: Vector3) -> void:
	if _active_flashes >= MAX_FLASHES:
		return
	_active_flashes += 1
	var root := Node3D.new()
	parent.add_child(root)
	root.global_position = pos
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.75, 0.35)
	light.light_energy = 3.0
	light.omni_range = 7.0
	root.add_child(light)
	var quad := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(0.55, 0.55)
	quad.mesh = qm
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.albedo_color = Color(1.0, 0.85, 0.4, 0.9)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.7, 0.2)
	mat.emission_energy_multiplier = 4.0
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	quad.material_override = mat
	quad.rotation_degrees = Vector3(0, 0, randf_range(0, 360))
	root.add_child(quad)
	root.get_tree().create_timer(0.045).timeout.connect(func() -> void:
		_active_flashes -= 1
		root.queue_free())


## Bullet impact: dirt/dust puff + positional thud.
static func impact(parent: Node, pos: Vector3, normal: Vector3, hard: bool = false) -> void:
	if _active_impacts < MAX_IMPACTS:
		_active_impacts += 1
		var particles := CPUParticles3D.new()
		particles.emitting = false
		particles.one_shot = true
		particles.amount = 10
		particles.lifetime = 0.45
		particles.direction = normal
		particles.spread = 35.0
		particles.initial_velocity_min = 1.5
		particles.initial_velocity_max = 3.5
		particles.gravity = Vector3(0, -6, 0)
		particles.scale_amount_min = 0.04
		particles.scale_amount_max = 0.1
		particles.color = Color(0.75, 0.7, 0.55) if hard else Color(0.45, 0.38, 0.28)
		parent.add_child(particles)
		particles.global_position = pos + normal * 0.05
		particles.emitting = true
		particles.get_tree().create_timer(0.6).timeout.connect(func() -> void:
			_active_impacts -= 1
			particles.queue_free())
	var p := AudioStreamPlayer3D.new()
	p.stream = IMPACT_HARD if hard else IMPACT_DIRT
	p.volume_db = -4.0
	p.max_distance = 40.0
	p.pitch_scale = randf_range(0.9, 1.1)
	parent.add_child(p)
	p.global_position = pos
	p.play()
	p.finished.connect(p.queue_free)
