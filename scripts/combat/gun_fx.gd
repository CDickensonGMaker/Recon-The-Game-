## gun_fx.gd - Tight 2000s-FPS shot feedback (RTCW/MoHAA school): self-lit muzzle
## flash quads, impact puffs, positional gunshot audio. Budgeted (perf-first).
##
## ADR-026 Part A #1: flashes and explosions are FAKE - emissive/additive sprites,
## never a real-time OmniLight per event. Adding one back here is a canon violation.
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
	_explosion_nodes.clear()
	_linger_nodes.clear()
	_blood_tex.clear()  # static cache would otherwise hold textures to process exit (leak scan)
	if _sting_player != null and is_instance_valid(_sting_player):
		_sting_player.stop()
		_sting_player.queue_free()
	_sting_player = null


## Contact drum sting, throttled. Parented to get_tree().current_scene, which
## SURVIVES _teardown_world() - so it must be TRACKED here for MissionScope to
## cut, or a sting fired before exfil keeps playing over the debrief screen.
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
static var _explosion_nodes: Array[Node3D] = []
## Muzzle flashes are the shooter's mandatory telegraph (Fairness Law) and are
## exempt from the ADR-026 light cap - they are unshaded quads, not lights. This
## bound only stops a runaway leak; it must never be low enough to silence a
## shooter the player could see.
const MAX_FLASHES: int = 64
const MAX_IMPACTS: int = 12
const MAX_EXPLOSIONS: int = 6   ## concurrent explosion visuals
const MAX_DECALS: int = 48   ## bullet holes, FIFO-recycled


static func shot_stream_for(weapon_name: String) -> AudioStream:
	var n := weapon_name.to_lower()
	if n.contains("1911") or n.contains("pistol"):
		return SHOT_PISTOL
	if n.contains("ppsh") or n.contains("smg"):
		return SHOT_SMG
	return SHOT_RIFLE


## 3D positional gunshot (NPCs/allies). `data` is a WeaponData (preferred) or a
## String id/path. Delegates to AudioManager's pooled, distance-layered voices.
## `parent` is ignored (AudioManager owns the voice nodes) but kept for callers.
static func play_shot_3d(_parent: Node, pos: Vector3, data: Variant, volume_db: float = 0.0) -> void:
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


## Visual scale per ordnance class (ADR-016 lethality decree: an RPG must READ
## bigger than a grenade; arty bigger than both).
const _KIND_SCALE: Dictionary = {
	"explosion_grenade": 1.0,
	"explosion_40mm": 0.8,
	"explosion_rocket": 1.4,
	"explosion_heavy": 1.9,
}


static func play_explosion_3d(parent: Node, pos: Vector3, kind: String = "explosion_grenade") -> void:
	AudioManager.play_explosion_3d(pos, kind)
	_spawn_explosion_visual(parent, pos, float(_KIND_SCALE.get(kind, 1.0)))


## ---------- SHARED FX RESOURCES (built once; per-event nodes reference them,
## so no material/pipeline compile ever happens mid-firefight) ----------
static var _fx_tex_cache: Dictionary = {}
static var _fx_res_cache: Dictionary = {}


static func _fx_tex(rel: String) -> Texture2D:
	if not _fx_tex_cache.has(rel):
		_fx_tex_cache[rel] = load("res://assets/textures/fx/%s.png" % rel)
	return _fx_tex_cache[rel]


## Flipbook particle material: BILLBOARD_PARTICLES is the one BaseMaterial3D
## mode that plays a sheet over particle lifetime.
static func _sheet_mat(key: String, rel: String, h: int, v: int, additive: bool) -> StandardMaterial3D:
	if _fx_res_cache.has(key):
		return _fx_res_cache[key]
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = _fx_tex(rel)
	m.particles_anim_h_frames = h
	m.particles_anim_v_frames = v
	m.particles_anim_loop = false
	if additive:
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		# The rendered sheets tonemap toward tan; warm them back to fire here.
		m.albedo_color = Color(1.0, 0.72, 0.42)
		m.emission_enabled = true
		m.emission = Color(1.0, 0.6, 0.2)
		m.emission_energy_multiplier = 3.0
	_fx_res_cache[key] = m
	return m


static func _plain_mat(key: String, tex_rel: String) -> StandardMaterial3D:
	if _fx_res_cache.has(key):
		return _fx_res_cache[key]
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	if tex_rel != "":
		m.albedo_texture = _fx_tex(tex_rel)
	_fx_res_cache[key] = m
	return m


static func _fx_quad(key: String, size: float, mat: Material) -> QuadMesh:
	if _fx_res_cache.has(key):
		return _fx_res_cache[key]
	var q := QuadMesh.new()
	q.size = Vector2(size, size)
	q.material = mat
	_fx_res_cache[key] = q
	return q


static func _fx_proc(key: String, build: Callable) -> ParticleProcessMaterial:
	if _fx_res_cache.has(key):
		return _fx_res_cache[key]
	var p := ParticleProcessMaterial.new()
	build.call(p)
	_fx_res_cache[key] = p
	return p


static func _smoke_fade_ramp() -> GradientTexture1D:
	if _fx_res_cache.has("smoke_ramp"):
		return _fx_res_cache["smoke_ramp"]
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.15, 0.75, 1.0])
	g.colors = PackedColorArray([
		Color(1, 1, 1, 0.0), Color(1, 1, 1, 0.9), Color(1, 1, 1, 0.55), Color(1, 1, 1, 0.0),
	])
	var t := GradientTexture1D.new()
	t.gradient = g
	_fx_res_cache["smoke_ramp"] = t
	return t


## One-shot GPU burst on shared resources. local_coords=true so scaling the
## root scales the whole effect (velocities included) without minting a
## per-event process material.
static func _burst(root: Node3D, amount: int, lifetime: float, proc: ParticleProcessMaterial, mesh: Mesh, y: float = 0.0) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = amount
	p.lifetime = lifetime
	p.local_coords = true
	p.process_material = proc
	p.draw_pass_1 = mesh
	p.position.y = y
	root.add_child(p)
	p.emitting = true
	return p


## Lingering smoke has its OWN cap: it lives ~3.5s, so under a barrage it would
## otherwise saturate MAX_EXPLOSIONS and silence the flashes (siege arty bug).
const MAX_LINGER: int = 8
static var _linger_nodes: Array[Node3D] = []

const MAX_SCORCH: int = 12
static var _scorch_decals: Array[Decal] = []


## Layered explosion (ADR-026: FAKE light — every layer is unshaded sprite
## geometry). scale_mult sizes ordnance classes; AmbientWar horizon events pass
## big scale + lifetime holds so it reads at 200-800m.
static func _spawn_explosion_visual(parent: Node, pos: Vector3, scale_mult: float = 1.0, lifetime_mult: float = 1.0) -> void:
	if parent == null:
		return
	# Prune freed explosions so a teardown that frees one early can't leak the
	# count and silence ALL future explosions (the cap-leak bug).
	# Param stays untyped: a freed object cannot convert to Node, so typing it
	# throws on exactly the entries this filter exists to drop.
	_explosion_nodes = _explosion_nodes.filter(func(n: Variant) -> bool: return is_instance_valid(n))
	if _explosion_nodes.size() >= MAX_EXPLOSIONS:
		return
	var root := Node3D.new()
	parent.add_child(root)
	root.global_position = pos
	root.scale = Vector3.ONE * scale_mult
	_explosion_nodes.append(root)

	# 1. flash core: emissive billboard pop (the probe's self-lit contract).
	var quad := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(1.2, 1.2)
	quad.mesh = qm
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.albedo_texture = _get_flash_tex()
	mat.albedo_color = Color(1.0, 0.85, 0.5, 1.0)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.55, 0.15)
	mat.emission_energy_multiplier = 9.0
	quad.material_override = mat
	quad.position.y = 0.6
	root.add_child(quad)

	# 2. fireball: 3 desynced flipbook particles.
	var fire_proc := _fx_proc("expl_fire_proc", func(p: ParticleProcessMaterial) -> void:
		p.direction = Vector3.UP
		p.spread = 25.0
		p.initial_velocity_min = 0.6
		p.initial_velocity_max = 1.6
		p.gravity = Vector3(0, 1.2, 0)
		p.scale_min = 0.8
		p.scale_max = 1.3
		p.lifetime_randomness = 0.25
		p.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
		p.emission_sphere_radius = 0.35)
	var fire_mesh := _fx_quad("expl_fire_quad", 2.2,
		_sheet_mat("expl_fire_mat", "sheets/fireball_sheet", 4, 4, true))
	_burst(root, 3, 0.7 * lifetime_mult, fire_proc, fire_mesh, 0.7)

	# 3. shock ring: flat additive disc, tween-expanded.
	var ring := MeshInstance3D.new()
	var ring_mesh := QuadMesh.new()
	ring_mesh.size = Vector2(1.0, 1.0)
	ring.mesh = ring_mesh
	var ring_mat := StandardMaterial3D.new()
	ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	ring_mat.albedo_texture = _fx_tex("particles/circle_05")
	ring_mat.albedo_color = Color(1.0, 0.8, 0.5, 0.7)
	ring_mat.emission_enabled = true
	ring_mat.emission = Color(1.0, 0.7, 0.3)
	ring_mat.emission_energy_multiplier = 2.0
	ring.material_override = ring_mat
	ring.rotation_degrees.x = -90.0
	ring.position.y = 0.15
	root.add_child(ring)

	# 4. dirt column.
	var dirt_proc := _fx_proc("expl_dirt_proc", func(p: ParticleProcessMaterial) -> void:
		p.direction = Vector3.UP
		p.spread = 14.0
		p.initial_velocity_min = 5.0
		p.initial_velocity_max = 9.0
		p.gravity = Vector3(0, -9.0, 0)
		p.scale_min = 0.5
		p.scale_max = 1.1
		p.lifetime_randomness = 0.3
		p.color = Color(0.42, 0.35, 0.24)
		p.color_ramp = _smoke_fade_ramp())
	_burst(root, 8, 1.0 * lifetime_mult, dirt_proc,
		_fx_quad("expl_dirt_quad", 1.4, _plain_mat("expl_dirt_mat", "particles/dirt_01")), 0.2)

	# 5. debris chunks.
	var debris_proc := _fx_proc("expl_debris_proc", func(p: ParticleProcessMaterial) -> void:
		p.direction = Vector3.UP
		p.spread = 55.0
		p.initial_velocity_min = 5.0
		p.initial_velocity_max = 11.0
		p.gravity = Vector3(0, -20.0, 0)
		p.scale_min = 0.06
		p.scale_max = 0.16
		p.color = Color(0.3, 0.25, 0.18))
	_burst(root, 12, 0.9 * lifetime_mult, debris_proc,
		_fx_quad("expl_debris_quad", 1.0, _plain_mat("expl_debris_mat", "")), 0.3)

	# 6. lingering smoke: own root + own cap so barrages keep their flashes.
	_linger_nodes = _linger_nodes.filter(func(n: Variant) -> bool: return is_instance_valid(n))
	if _linger_nodes.size() < MAX_LINGER:
		var linger_root := Node3D.new()
		parent.add_child(linger_root)
		linger_root.global_position = pos
		linger_root.scale = Vector3.ONE * scale_mult
		_linger_nodes.append(linger_root)
		var linger_proc := _fx_proc("expl_linger_proc", func(p: ParticleProcessMaterial) -> void:
			p.direction = Vector3.UP
			p.spread = 30.0
			p.initial_velocity_min = 0.7
			p.initial_velocity_max = 1.6
			p.gravity = Vector3(0, 0.5, 0)
			p.scale_min = 1.0
			p.scale_max = 1.8
			p.lifetime_randomness = 0.35
			p.color = Color(0.30, 0.28, 0.24)
			p.color_ramp = _smoke_fade_ramp()
			p.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
			p.emission_sphere_radius = 0.5)
		var linger_mesh := _fx_quad("expl_linger_quad", 2.6,
			_sheet_mat("expl_linger_mat", "sheets/puff_sheet", 4, 2, false))
		_burst(linger_root, 6, 3.2 * lifetime_mult, linger_proc, linger_mesh, 0.8)
		_expire(linger_root, 4.4 * lifetime_mult, func() -> void:
			linger_root.queue_free())

	# 7. scorch decal.
	_scorch(parent, pos, scale_mult)

	var tw := root.create_tween()
	tw.set_parallel(true)
	tw.tween_property(quad, "scale", Vector3(3.0, 3.0, 3.0), 0.3 * lifetime_mult).from(Vector3(0.6, 0.6, 0.6))
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.35 * lifetime_mult)
	tw.tween_property(ring, "scale", Vector3(4.5, 4.5, 4.5), 0.35 * lifetime_mult).from(Vector3(0.4, 0.4, 0.4))
	tw.tween_property(ring_mat, "albedo_color:a", 0.0, 0.35 * lifetime_mult)
	_expire(root, 1.6 * lifetime_mult, func() -> void:
		root.queue_free())


static func _scorch(parent: Node, pos: Vector3, scale_mult: float) -> void:
	var d := Decal.new()
	var s: float = 2.4 * scale_mult
	d.size = Vector3(s, 0.4, s)
	d.texture_albedo = _fx_tex("particles/scorch_0%d" % (randi() % 3 + 1))
	d.modulate = Color(0.1, 0.09, 0.08)
	d.albedo_mix = 0.85
	parent.add_child(d)
	d.global_position = pos + Vector3(0, 0.05, 0)
	d.rotate_y(randf_range(0.0, TAU))
	for i in range(_scorch_decals.size() - 1, -1, -1):
		if not is_instance_valid(_scorch_decals[i]):
			_scorch_decals.remove_at(i)
	_scorch_decals.append(d)
	while _scorch_decals.size() > MAX_SCORCH:
		var old: Variant = _scorch_decals.pop_front()
		if is_instance_valid(old):
			(old as Decal).queue_free()


## Self-contained expiry: a Timer CHILD of `node`, so it dies with it. A
## scene-tree timer lambda would dangle if the node is freed first (e.g. mission
## teardown) and the engine error-spams "Lambda capture was freed".
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


## Shared muzzle-flame materials - flashes differ by mesh size and roll, NOT by
## material; this runs twice per shot, never mint a StandardMaterial3D here.
static func _muzzle_mat(key: String, tex_rel: String) -> StandardMaterial3D:
	if _fx_res_cache.has(key):
		return _fx_res_cache[key]
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.albedo_texture = _fx_tex(tex_rel)
	mat.albedo_color = Color(1.0, 0.82, 0.45)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.7, 0.2)
	mat.emission_energy_multiplier = 6.0
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_fx_res_cache[key] = mat
	return mat


## Muzzle flash: real muzzle-flame sprites - round star core + elongated flame
## spike, random roll + size jitter so no two shots read identical.
##
## FLASH_SECONDS is a FAIRNESS floor, not a look knob: the flash is the shooter's
## mandatory telegraph, so it must survive at least one rendered frame at our
## worst measured framerate (~25 fps = 40ms/frame). Never shorten it for perf.
const FLASH_SECONDS: float = 0.06

static func muzzle_flash(parent: Node, pos: Vector3) -> void:
	if _active_flashes >= MAX_FLASHES:
		return
	_active_flashes += 1
	var root := Node3D.new()
	parent.add_child(root)
	root.global_position = pos

	var size_jitter: float = randf_range(0.85, 1.25)
	var core := MeshInstance3D.new()
	var core_mesh := QuadMesh.new()
	core_mesh.size = Vector2(0.5, 0.5) * size_jitter
	core.mesh = core_mesh
	var core_pick: int = randi() % 2 + 4
	core.material_override = _muzzle_mat("muzzle_core_mat_%d" % core_pick, "particles/muzzle_0%d" % core_pick)
	core.rotation_degrees = Vector3(0, 0, randf_range(0.0, 360.0))
	root.add_child(core)

	var spikes := MeshInstance3D.new()
	var spike_mesh := QuadMesh.new()
	spike_mesh.size = Vector2(1.0, 0.28) * size_jitter
	spikes.mesh = spike_mesh
	spikes.material_override = _muzzle_mat("muzzle_spike_mat", "particles/muzzle_01")
	spikes.rotation_degrees = Vector3(0, 0, randf_range(0.0, 360.0))
	root.add_child(spikes)

	_expire(root, FLASH_SECONDS, func() -> void:
		_active_flashes -= 1
		root.queue_free())


## Bullet impact: dirt/dust puff + positional thud.
static func impact(parent: Node, pos: Vector3, normal: Vector3, hard: bool = false) -> void:
	if _active_impacts < MAX_IMPACTS:
		_active_impacts += 1
		var key := "impact_hard_proc" if hard else "impact_dirt_proc"
		var col := Color(0.75, 0.7, 0.55) if hard else Color(0.45, 0.38, 0.28)
		var proc := _fx_proc(key, func(p: ParticleProcessMaterial) -> void:
			p.direction = Vector3.UP
			p.spread = 35.0
			p.initial_velocity_min = 1.5
			p.initial_velocity_max = 3.5
			p.gravity = Vector3(0, -6, 0)
			p.scale_min = 0.5
			p.scale_max = 1.2
			p.color = col
			p.color_ramp = _smoke_fade_ramp())
		var root := Node3D.new()
		parent.add_child(root)
		root.global_position = pos + normal * 0.05
		# The shared material sprays +Y; aim the NODE's +Y down the surface normal.
		if absf(normal.dot(Vector3.UP)) < 0.99:
			root.look_at(root.global_position + normal, Vector3.UP)
			root.rotate_object_local(Vector3.RIGHT, -PI * 0.5)
		_burst(root, 8, 0.45, proc,
			_fx_quad("impact_quad", 0.12, _plain_mat("impact_mat", "particles/smoke_01")))
		_expire(root, 0.65, func() -> void:
			_active_impacts -= 1
			root.queue_free())
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


## Flesh hit - the cue that shooting a body feels different from shooting a wall.
## Layered: flipbook MIST puff + fine droplets + a splat decal on the surface
## BEHIND the target + persistent wound blood ON the victim (so you can see at a
## glance who is hurt).
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
		mist.amount = 5
		mist.lifetime = 0.5
		mist.direction = shot_dir if shot_dir.length() > 0.1 else normal
		mist.spread = 22.0
		mist.initial_velocity_min = 0.5
		mist.initial_velocity_max = 2.0
		mist.gravity = Vector3(0, -0.5, 0)
		mist.scale_amount_min = 0.7
		mist.scale_amount_max = 1.25
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
		drops.amount = 16
		drops.lifetime = 0.55
		drops.direction = shot_dir if shot_dir.length() > 0.1 else normal
		drops.spread = 40.0
		drops.initial_velocity_min = 3.0
		drops.initial_velocity_max = 7.0
		drops.gravity = Vector3(0, -11.0, 0)
		drops.scale_amount_min = 0.07
		drops.scale_amount_max = 0.16
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
	var s: float = randf_range(0.55, 1.05)
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
	# instance into a TYPED var is a script error in Godot 4.7.
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


## Spreading pool under a kill: 4 STANDALONE stage textures swapped as it grows
## (~3s) - a Decal cannot sample an AtlasTexture. Units can also die while the
## scene is tearing down, hence the is_inside_tree guards.
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
	for sc in _scorch_decals:
		if is_instance_valid(sc):
			sc.queue_free()
	_scorch_decals.clear()
