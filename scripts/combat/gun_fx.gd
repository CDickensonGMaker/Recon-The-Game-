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
	_blood_tex.clear()  # static cache would otherwise hold textures to process exit (leak scan)
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
	_expire(root, 1.4, func() -> void:
		_active_explosions -= 1
		root.queue_free())


## Self-contained expiry: a Timer CHILD of `node` (dies with it - a scene-tree
## timer lambda would dangle if the node is freed first, e.g. mission teardown,
## and the engine error-spams "Lambda capture was freed"). [test_site_stamp fix]
static func _expire(node: Node, seconds: float, cb: Callable) -> void:
	var t := Timer.new()
	t.one_shot = true
	t.wait_time = seconds
	node.add_child(t)
	t.timeout.connect(cb)
	t.start()


## Cached radial falloff texture for the muzzle flash - built once, hot white
## core fading to transparent, so the flash reads as a burst, not a square.
static var _flash_tex: GradientTexture2D = null

static func _get_flash_tex() -> GradientTexture2D:
	if _flash_tex == null:
		var grad := Gradient.new()
		grad.offsets = PackedFloat32Array([0.0, 0.25, 0.6, 1.0])
		grad.colors = PackedColorArray([
			Color(1.0, 0.98, 0.85, 1.0),   # white-hot core
			Color(1.0, 0.8, 0.35, 0.9),    # orange body
			Color(1.0, 0.5, 0.1, 0.35),    # red-orange fringe
			Color(1.0, 0.4, 0.0, 0.0),     # transparent edge
		])
		_flash_tex = GradientTexture2D.new()
		_flash_tex.gradient = grad
		_flash_tex.fill = GradientTexture2D.FILL_RADIAL
		_flash_tex.fill_from = Vector2(0.5, 0.5)
		_flash_tex.fill_to = Vector2(0.5, 0.0)
		_flash_tex.width = 64
		_flash_tex.height = 64
	return _flash_tex


static func _flash_mat() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.albedo_texture = _get_flash_tex()
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.7, 0.2)
	mat.emission_energy_multiplier = 4.0
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	return mat


## Muzzle flash: warm omni light + a radial burst with a star cross - two
## billboard quads (round core + elongated spike pair), random roll + size
## jitter so no two shots read identical. 45ms. (Was: a flat yellow square.)
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

	var size_jitter: float = randf_range(0.85, 1.25)
	var core := MeshInstance3D.new()
	var core_mesh := QuadMesh.new()
	core_mesh.size = Vector2(0.5, 0.5) * size_jitter
	core.mesh = core_mesh
	core.material_override = _flash_mat()
	core.rotation_degrees = Vector3(0, 0, randf_range(0.0, 360.0))
	root.add_child(core)

	var spikes := MeshInstance3D.new()
	var spike_mesh := QuadMesh.new()
	spike_mesh.size = Vector2(1.0, 0.16) * size_jitter
	spikes.mesh = spike_mesh
	spikes.material_override = _flash_mat()
	spikes.rotation_degrees = Vector3(0, 0, randf_range(0.0, 360.0))
	root.add_child(spikes)

	_expire(root, 0.045, func() -> void:
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
		_expire(particles, 0.6, func() -> void:
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
## Blood v2 (Phase 1, our generated textures): HLL-style layered hit -
## flipbook MIST puff + fine droplets + a splat decal on the surface BEHIND the
## target + persistent wound blood ON the victim (readability: see who is hurt).
const MAX_BLOOD_DECALS: int = 24
const MAX_BLOOD_POOLS: int = 12
static var _blood_decals: Array[Decal] = []
static var _blood_pools: Array[Decal] = []
static var _blood_tex: Dictionary = {}


static func _btex(tex_name: String) -> Texture2D:
	if not _blood_tex.has(tex_name):
		_blood_tex[tex_name] = load("res://assets/textures/fx/blood/%s.png" % tex_name)
	return _blood_tex[tex_name]


static func blood(parent: Node, pos: Vector3, normal: Vector3, shot_dir: Vector3 = Vector3.ZERO, victim: Node = null) -> void:
	if _active_impacts < MAX_IMPACTS:
		_active_impacts += 1
		var root := Node3D.new()
		parent.add_child(root)
		root.global_position = pos + normal * 0.05

		# 1. the mist: 8-frame flipbook puff that blooms and dissipates (~0.45s)
		var mist := CPUParticles3D.new()
		mist.one_shot = true
		mist.amount = 3
		mist.lifetime = 0.45
		mist.direction = shot_dir if shot_dir.length() > 0.1 else normal
		mist.spread = 25.0
		mist.initial_velocity_min = 0.4
		mist.initial_velocity_max = 1.4
		mist.gravity = Vector3(0, -0.5, 0)
		mist.scale_amount_min = 0.5
		mist.scale_amount_max = 0.9
		mist.anim_speed_min = 1.0
		mist.anim_speed_max = 1.0
		var mq := QuadMesh.new()
		mq.size = Vector2(1, 1)
		var mm := StandardMaterial3D.new()
		mm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		mm.particles_anim_h_frames = 4
		mm.particles_anim_v_frames = 2
		mm.particles_anim_loop = false
		mm.albedo_texture = _btex("blood_mist_sheet")
		mm.vertex_color_use_as_albedo = true
		mq.material = mm
		mist.mesh = mq
		root.add_child(mist)
		mist.emitting = true

		# 2. fine droplets streaking out with gravity
		var drops := CPUParticles3D.new()
		drops.one_shot = true
		drops.amount = 10
		drops.lifetime = 0.5
		drops.direction = shot_dir if shot_dir.length() > 0.1 else normal
		drops.spread = 40.0
		drops.initial_velocity_min = 2.5
		drops.initial_velocity_max = 5.5
		drops.gravity = Vector3(0, -11.0, 0)
		drops.scale_amount_min = 0.06
		drops.scale_amount_max = 0.14
		var dq := QuadMesh.new()
		dq.size = Vector2(1, 1)
		var dm := StandardMaterial3D.new()
		dm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		dm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		dm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		dm.albedo_texture = _btex("blood_droplet")
		dq.material = dm
		drops.mesh = dq
		root.add_child(drops)
		drops.emitting = true

		_expire(root, 0.8, func() -> void:
			_active_impacts -= 1
			root.queue_free())

	# 3. exit splat on whatever is behind the target (wall/floor/tree)
	if shot_dir.length() > 0.1:
		_blood_splat_behind(parent, pos, shot_dir.normalized())

	# 4. persistent wound blood on the victim - see who is hurt at a glance
	if victim != null and is_instance_valid(victim):
		blood_wound(victim, pos)

	var a := AudioStreamPlayer3D.new()
	a.stream = IMPACT_DIRT   # placeholder wet tick until a flesh sample exists
	a.volume_db = -6.0
	a.max_distance = 30.0
	a.pitch_scale = randf_range(1.3, 1.6)
	parent.add_child(a)
	a.global_position = pos
	a.play()
	a.finished.connect(a.queue_free)


## Raycast past the victim and paint the surface behind with one of our splats.
static func _blood_splat_behind(parent: Node, pos: Vector3, dir: Vector3) -> void:
	var vp := parent.get_viewport()
	if vp == null:
		return
	var w3d := vp.find_world_3d()
	if w3d == null:
		return
	var query := PhysicsRayQueryParameters3D.create(pos + dir * 0.15, pos + dir * 3.2, 1)
	var hit: Dictionary = w3d.direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return
	var d := Decal.new()
	var s: float = randf_range(0.45, 0.85)
	d.size = Vector3(s, 0.25, s)
	d.texture_albedo = _btex("blood_splat_%d" % (randi() % 3 + 1))
	d.albedo_mix = 1.0
	parent.add_child(d)
	var n: Vector3 = hit.normal
	d.global_position = hit.position + n * 0.02
	if absf(n.dot(Vector3.UP)) < 0.99:
		d.look_at(hit.position - n, Vector3.UP)
		d.rotate_object_local(Vector3.RIGHT, PI * 0.5)
	d.rotate_object_local(Vector3.UP, randf_range(0, TAU))
	# Purge entries whose nodes died with a scene reload FIRST: popping a freed
	# instance into a TYPED var is a script error in 4.7 (the gore-lab spam bug).
	for i in range(_blood_decals.size() - 1, -1, -1):
		if not is_instance_valid(_blood_decals[i]):
			_blood_decals.remove_at(i)
	_blood_decals.append(d)
	while _blood_decals.size() > MAX_BLOOD_DECALS:
		var old: Variant = _blood_decals.pop_front()
		if is_instance_valid(old):
			(old as Decal).queue_free()


## Persistent blood ON a unit while it lives (max 3 marks). 3D-model units get a
## stuck-on decal at the hit spot; sprite units blend toward a bloodied modulate.
static func blood_wound(unit: Node, world_pos: Vector3) -> void:
	if not (unit is Node3D):
		return
	var wounds: int = int(unit.get_meta("blood_wounds", 0))
	if wounds >= 3:
		return
	unit.set_meta("blood_wounds", wounds + 1)
	# unit.get() returns null when the property is absent (the PLAYER has no
	# _visual_is_model) and bool(null) is a runtime crash - compare instead.
	var is_model: bool = unit.get("_visual_is_model") == true
	if is_model:
		var d := Decal.new()
		d.size = Vector3(0.34, 0.5, 0.34)
		d.texture_albedo = _btex("blood_splat_%d" % (randi() % 3 + 1))
		d.albedo_mix = 1.0
		unit.add_child(d)
		var local := (unit as Node3D).to_local(world_pos)
		local.y = clampf(local.y, 0.4, 1.6)
		d.position = local
		# project inward toward the body core so the splat wraps the mesh
		var inward := Vector3(-local.x, 0, -local.z)
		if inward.length() < 0.05:
			inward = Vector3.FORWARD
		d.look_at(unit.global_position + Vector3(0, local.y, 0), Vector3.UP)
		d.rotate_object_local(Vector3.RIGHT, PI * 0.5)
	else:
		var actor: Variant = unit.get("sprite_actor")
		if actor is Object and (actor as Object).has_method("set_base_modulate"):
			var t: float = float(wounds + 1) / 3.0
			(actor as Object).call("set_base_modulate", Color(1.0, 1.0 - 0.35 * t, 1.0 - 0.35 * t))


## Spreading pool under a kill: 4 standalone stage textures swapped as it grows
## (~3s). Decals cannot sample AtlasTexture, and units can die while the scene is
## tearing down - both learned from test_cas_sim. Guards accordingly.
static func blood_pool(parent: Node, ground_pos: Vector3) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var d := Decal.new()
	d.size = Vector3(0.6, 0.3, 0.6)
	d.albedo_mix = 1.0
	d.texture_albedo = _btex("blood_pool_1")
	parent.add_child(d)
	if not d.is_inside_tree():
		d.queue_free()
		return
	d.global_position = ground_pos + Vector3(0, 0.05, 0)
	d.rotate_y(randf_range(0, TAU))
	for i in range(2, 5):
		_expire(d, 0.9 * float(i - 1), func() -> void:
			if is_instance_valid(d) and d.is_inside_tree():
				d.texture_albedo = _btex("blood_pool_%d" % i)
				var s: float = 0.6 + 0.35 * float(i - 1)
				d.size = Vector3(s, 0.3, s))
	for i in range(_blood_pools.size() - 1, -1, -1):
		if not is_instance_valid(_blood_pools[i]):
			_blood_pools.remove_at(i)
	_blood_pools.append(d)
	while _blood_pools.size() > MAX_BLOOD_POOLS:
		var old: Variant = _blood_pools.pop_front()
		if is_instance_valid(old):
			(old as Decal).queue_free()


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
	for i in range(_decals.size() - 1, -1, -1):
		if not is_instance_valid(_decals[i]):
			_decals.remove_at(i)
	_decals.append(d)
	while _decals.size() > MAX_DECALS:
		var old: Variant = _decals.pop_front()
		if is_instance_valid(old):
			(old as Decal).queue_free()


static func clear_decals() -> void:
	for bd in _blood_decals:
		if is_instance_valid(bd):
			bd.queue_free()
	_blood_decals.clear()
	for bp in _blood_pools:
		if is_instance_valid(bp):
			bp.queue_free()
	_blood_pools.clear()
	for d in _decals:
		if is_instance_valid(d):
			d.queue_free()
	_decals.clear()
