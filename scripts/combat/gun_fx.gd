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


## _sting_cooldown_until is an ABSOLUTE Time.get_ticks_msec(), so a contact sting
## fired at the end of one mission suppresses the drum for the first seconds of
## the next. Called from MissionScope.reset().
static func reset_session() -> void:
	_sting_cooldown_until = 0
	_active_flashes = 0
	_active_impacts = 0
	_active_explosions = 0
	if _sting_player != null and is_instance_valid(_sting_player):
		_sting_player.stop()
		_sting_player.queue_free()
	_sting_player = null


## W67: contact! drum sting, throttled.
## Parented to get_tree().current_scene, which is main.tscn's GameFlow root and
## SURVIVES _teardown_world(). Left untracked, a sting fired seconds before exfil
## keeps playing over the debrief screen. Tracked so MissionScope can cut it.
static var _sting_player: AudioStreamPlayer = null


static func play_combat_sting(parent: Node) -> void:
	var now := Time.get_ticks_msec()
	if now < _sting_cooldown_until:
		return
	_sting_cooldown_until = now + 25000
	var p := AudioStreamPlayer.new()
	p.stream = COMBAT_STING
	p.volume_db = -4.0
	if AudioServer.get_bus_index("Music") >= 0:
		p.bus = "Music"
	parent.add_child(p)
	p.play()
	p.finished.connect(p.queue_free)
	_sting_player = p


static var _active_flashes: int = 0
static var _active_impacts: int = 0
static var _active_explosions: int = 0
const MAX_FLASHES: int = 8
const MAX_IMPACTS: int = 12
const MAX_EXPLOSIONS: int = 6   ## concurrent explosion visuals
const MAX_DECALS: int = 48   ## bullet holes, FIFO-recycled


static func shot_stream_for(weapon_name: String) -> AudioStream:
	var n := weapon_name.to_lower()
	if n.contains("1911") or n.contains("pistol"):
		return SHOT_PISTOL
	if n.contains("thompson") or n.contains("mp40") or n.contains("ppsh") or n.contains("smg"):
		return SHOT_SMG
	return SHOT_RIFLE


## 3D positional gunshot (NPCs/allies). `data` is a WeaponData (preferred) or a
## String id/path. Delegates to AudioManager's pooled, distance-layered voices.
## `parent` is ignored (AudioManager owns the voice nodes) but kept for callers.
static func play_shot_3d(parent: Node, pos: Vector3, data: Variant, volume_db: float = 0.0) -> void:
	AudioManager.play_shot_3d(pos, data, volume_db)


## 2D player-weapon shot (dedicated, never-stolen slot).
static func play_shot_2d(_parent: Node, data: Variant) -> void:
	AudioManager.play_shot_player(data)


static func play_bolt_2d(_parent: Node, data: Variant) -> void:
	AudioManager.play_bolt_player(data)


static func play_reload_2d(_parent: Node, data: Variant) -> void:
	AudioManager.play_reload_player(data)


static func play_click(parent: Node) -> void:
	var p := AudioStreamPlayer.new()
	p.stream = DRY_CLICK
	parent.add_child(p)
	p.play()
	p.finished.connect(p.queue_free)


static func play_explosion_3d(parent: Node, pos: Vector3, kind: String = "explosion_grenade") -> void:
	AudioManager.play_explosion_3d(pos, kind)
	_spawn_explosion_visual(parent, pos)


## Procedural explosion visual (was a TODO - explosions had audio + a crater but no
## FIRE): a bright flash light, an expanding emissive fireball, a rising smoke puff,
## and a dirt/debris kick. No art needed. Every explosion caller gets it through here.
static func _spawn_explosion_visual(parent: Node, pos: Vector3) -> void:
	if parent == null or _active_explosions >= MAX_EXPLOSIONS:
		return
	_active_explosions += 1
	var root := Node3D.new()
	parent.add_child(root)
	root.global_position = pos

	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.6, 0.25)
	light.light_energy = 8.0
	light.omni_range = 16.0
	root.add_child(light)

	var quad := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(1.2, 1.2)
	quad.mesh = qm
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(1.0, 0.75, 0.35, 1.0)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.55, 0.15)
	mat.emission_energy_multiplier = 6.0
	quad.material_override = mat
	quad.position.y = 0.6
	root.add_child(quad)

	var smoke := CPUParticles3D.new()
	smoke.one_shot = true
	smoke.amount = 16
	smoke.lifetime = 1.2
	smoke.direction = Vector3.UP
	smoke.spread = 40.0
	smoke.initial_velocity_min = 1.5
	smoke.initial_velocity_max = 4.0
	smoke.gravity = Vector3(0, 1.0, 0)
	smoke.scale_amount_min = 0.4
	smoke.scale_amount_max = 0.9
	smoke.color = Color(0.14, 0.13, 0.11, 0.85)
	smoke.position.y = 0.5
	root.add_child(smoke)
	smoke.emitting = true

	var debris := CPUParticles3D.new()
	debris.one_shot = true
	debris.amount = 20
	debris.lifetime = 0.8
	debris.direction = Vector3.UP
	debris.spread = 60.0
	debris.initial_velocity_min = 4.0
	debris.initial_velocity_max = 9.0
	debris.gravity = Vector3(0, -12, 0)
	debris.scale_amount_min = 0.05
	debris.scale_amount_max = 0.14
	debris.color = Color(0.4, 0.34, 0.25)
	root.add_child(debris)
	debris.emitting = true

	# Fireball expands fast then fades; the flash light decays quicker.
	var tw := root.create_tween()
	tw.set_parallel(true)
	tw.tween_property(quad, "scale", Vector3(3.0, 3.0, 3.0), 0.35).from(Vector3(0.6, 0.6, 0.6))
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.4)
	tw.tween_property(light, "light_energy", 0.0, 0.25)
	root.get_tree().create_timer(1.4).timeout.connect(func() -> void:
		_active_explosions -= 1
		root.queue_free())


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
	if AudioServer.get_bus_index("Impacts") >= 0:
		p.bus = "Impacts"
	parent.add_child(p)
	p.global_position = pos
	p.play()
	p.finished.connect(p.queue_free)


## Flesh hit: red-brown spray + wet tick. MoHAA's single biggest "shooting a body
## feels different from shooting a wall" cue. weapon_holder used to spawn NOTHING
## on flesh (only the non-flesh dirt puff).
static func blood(parent: Node, pos: Vector3, normal: Vector3) -> void:
	if _active_impacts < MAX_IMPACTS:
		_active_impacts += 1
		var ps := CPUParticles3D.new()
		ps.emitting = false
		ps.one_shot = true
		ps.amount = 14
		ps.lifetime = 0.5
		ps.direction = normal
		ps.spread = 45.0
		ps.initial_velocity_min = 2.0
		ps.initial_velocity_max = 5.0
		ps.gravity = Vector3(0, -9.8, 0)
		ps.scale_amount_min = 0.03
		ps.scale_amount_max = 0.09
		ps.color = Color(0.55, 0.05, 0.04)
		parent.add_child(ps)
		ps.global_position = pos + normal * 0.05
		ps.emitting = true
		ps.get_tree().create_timer(0.7).timeout.connect(func() -> void:
			_active_impacts -= 1
			ps.queue_free())
	var a := AudioStreamPlayer3D.new()
	a.stream = IMPACT_DIRT   # placeholder wet tick until a flesh sample exists
	a.volume_db = -6.0
	a.max_distance = 30.0
	a.pitch_scale = randf_range(1.3, 1.6)
	parent.add_child(a)
	a.global_position = pos
	a.play()
	a.finished.connect(a.queue_free)


## Persistent bullet-hole decal, oriented to the surface. FIFO-recycled and
## cleared by MissionScope so it never leaks across missions.
static var _decals: Array[Decal] = []

static func bullet_hole(parent: Node, pos: Vector3, normal: Vector3) -> void:
	var d := Decal.new()
	d.size = Vector3(0.12, 0.3, 0.12)
	d.modulate = Color(0.05, 0.04, 0.03)
	d.albedo_mix = 0.9
	parent.add_child(d)
	d.global_position = pos + normal * 0.02
	# Point the decal's -Y down the surface normal.
	if absf(normal.dot(Vector3.UP)) < 0.99:
		d.look_at(pos - normal, Vector3.UP)
		d.rotate_object_local(Vector3.RIGHT, PI * 0.5)
	_decals.append(d)
	while _decals.size() > MAX_DECALS:
		var old: Decal = _decals.pop_front()
		if is_instance_valid(old):
			old.queue_free()


static func clear_decals() -> void:
	for d in _decals:
		if is_instance_valid(d):
			d.queue_free()
	_decals.clear()
