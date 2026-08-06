## zombie_night.gd - darkness, street lamps, and the body light.
##
## The mode's whole read is "Nazi Zombies meets Left 4 Dead", and both of those are
## games about a small pool of light with things outside it. So this owns three
## things and they only work together:
##
##   1. a genuinely DARK night - dark enough that unlit ground is a threat
##   2. STREET LAMPS as islands of safety, some of them failing
##   3. a BODY LIGHT on the player - a GoPro on the chest, not a torch in the hand
##
## The body light is what makes the darkness playable instead of merely annoying:
## you always have a cone, it always points roughly where you look, and it is
## never bright enough to make the lamps pointless.
##
## PERF: every light here is SHADOWLESS. ADR-026 Amendment A ships the world's own
## sun shadowless because shadow passes measured ~12 ms; a dozen shadow-casting
## lamps would be far worse than that. Darkness here is cheap by construction.
class_name ZombieNight
extends Node3D

const KIT: String = "res://assets/world/props/psx_kit/"
## The pole is a shipped prop, not invented geometry. Only the lamp HEAD is a
## primitive, because a light fixture is a light fixture.
const POLE_PROP: String = KIT + "industrial/metalpipe.glb"

const LAMP_HEIGHT: float = 5.2
const LAMP_RANGE: float = 15.0
const LAMP_ENERGY: float = 3.2
const LAMP_COLOR := Color(1.0, 0.82, 0.55)      ## sodium orange
const LAMP_ANGLE_DEG: float = 62.0

## One lamp in four is dying. A row of perfect lamps reads as a car park; one
## strobing at the far end reads as a place something went wrong.
const FLICKER_SHARE: float = 0.25

var _flickerers: Array[Dictionary] = []
var _rng := RandomNumberGenerator.new()


func _process(delta: float) -> void:
	for f in _flickerers:
		var light: SpotLight3D = f["light"]
		var glow: MeshInstance3D = f["glow"]
		if not is_instance_valid(light):
			continue
		f["t"] = float(f["t"]) - delta
		if f["t"] > 0.0:
			continue
		# Uneven on/off dwell - a clean square wave reads as a disco, not a fault.
		var on: bool = not light.visible
		light.visible = on
		if is_instance_valid(glow):
			glow.visible = on
		f["t"] = _rng.randf_range(0.04, 0.22) if not on else _rng.randf_range(0.5, 3.5)


## The night sky. Deliberately not pitch black - a black screen is not scary, it
## is broken. Enough moon to read a silhouette, never enough to identify it.
func apply_night(host: Node3D, seed_value: int = 20260805) -> void:
	_rng.seed = seed_value

	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.015, 0.018, 0.028)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.36, 0.44, 0.62)
	env.ambient_light_energy = 0.055
	env.fog_enabled = true
	env.fog_light_color = Color(0.07, 0.09, 0.13)
	env.fog_density = 0.012
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	# Glow is what sells a sodium lamp in fog. Without it the lamps are bright
	# discs; with it they are sources.
	env.glow_enabled = true
	env.glow_intensity = 0.55
	env.glow_bloom = 0.12
	var we := WorldEnvironment.new()
	we.name = "NightEnvironment"
	we.environment = env
	host.add_child(we)

	var moon := DirectionalLight3D.new()
	moon.name = "Moon"
	moon.rotation_degrees = Vector3(-58.0, 38.0, 0.0)
	moon.light_energy = 0.10
	moon.light_color = Color(0.55, 0.66, 0.95)
	moon.shadow_enabled = false
	host.add_child(moon)


## A sodium lamp on a pole: shipped pipe, emissive head, a cone down and an omni
## pool at the base so the light has a footprint you can stand in.
func place_lamp(host: Node3D, at: Vector3, flicker: bool = false) -> void:
	var root := Node3D.new()
	root.name = "StreetLamp"
	host.add_child(root)
	root.global_position = at

	if ResourceLoader.exists(POLE_PROP):
		var packed: PackedScene = load(POLE_PROP)
		if packed != null:
			var pole := packed.instantiate() as Node3D
			if pole != null:
				root.add_child(pole)
				# The pipe prop is authored short; stretch it into a lamp standard.
				pole.scale = Vector3(1.0, LAMP_HEIGHT, 1.0)

	var head := MeshInstance3D.new()
	head.name = "LampHead"
	var bm := BoxMesh.new()
	bm.size = Vector3(0.55, 0.16, 0.34)
	head.mesh = bm
	var glow_mat := StandardMaterial3D.new()
	glow_mat.albedo_color = LAMP_COLOR
	glow_mat.emission_enabled = true
	glow_mat.emission = LAMP_COLOR
	glow_mat.emission_energy_multiplier = 6.0
	glow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	head.material_override = glow_mat
	head.position = Vector3(0.0, LAMP_HEIGHT, 0.0)
	root.add_child(head)

	var spot := SpotLight3D.new()
	spot.name = "LampCone"
	spot.light_color = LAMP_COLOR
	spot.light_energy = LAMP_ENERGY
	spot.spot_range = LAMP_RANGE
	spot.spot_angle = LAMP_ANGLE_DEG
	spot.spot_attenuation = 1.4
	spot.shadow_enabled = false
	spot.position = Vector3(0.0, LAMP_HEIGHT - 0.2, 0.0)
	spot.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	root.add_child(spot)

	if flicker:
		_flickerers.append({"light": spot, "glow": head, "t": _rng.randf_range(0.0, 2.0)})


## Scatter lamps along a run of ground, a quarter of them faulty.
func place_lamp_row(host: Node3D, from: Vector3, to: Vector3, count: int) -> void:
	for i in count:
		var t: float = (float(i) + 0.5) / float(count)
		place_lamp(host, from.lerp(to, t), _rng.randf() < FLICKER_SHARE)


## THE BODY LIGHT. Mounted on the HEAD bone's height but driven like a chest rig:
## it lags the camera slightly, so whipping round leaves the beam trailing for a
## beat. That lag is the entire character of the thing - a light welded to the
## camera reads as a screen effect, a light that has to catch up reads as
## something strapped to a body.
class BodyLight extends SpotLight3D:
	const FOLLOW: float = 7.0
	const SWAY: float = 0.9

	var _cam: Camera3D = null
	var _aim: Basis = Basis.IDENTITY
	var _bob: float = 0.0

	func bind(cam: Camera3D) -> void:
		_cam = cam
		_aim = cam.global_transform.basis

	func _process(delta: float) -> void:
		if _cam == null or not is_instance_valid(_cam):
			return
		# Damped chase toward where the player is looking.
		_aim = _aim.slerp(_cam.global_transform.basis, clampf(FOLLOW * delta, 0.0, 1.0))
		_bob += delta * 2.1
		var sway: Basis = Basis.from_euler(Vector3(
			sin(_bob * 0.7) * deg_to_rad(SWAY),
			sin(_bob) * deg_to_rad(SWAY * 1.3), 0.0))
		global_transform = Transform3D(_aim * sway, _cam.global_position
			+ Vector3(0.0, -0.25, 0.0))


## Strap a light to the player. Returns it so the mode can toggle or dim it.
static func attach_body_light(player: Node3D) -> SpotLight3D:
	var cam := player.get_node_or_null("Head/Camera3D") as Camera3D
	if cam == null:
		push_warning("[NIGHT] no Head/Camera3D on the player - no body light")
		return null
	var light := BodyLight.new()
	light.name = "BodyLight"
	# Wide and short. A narrow long beam turns the game into a laser pointer; a
	# wide short one lights the room you are standing in and nothing beyond it,
	# which is the L4D read.
	light.spot_range = 22.0
	light.spot_angle = 42.0
	light.spot_attenuation = 1.1
	light.light_energy = 4.2
	light.light_color = Color(0.94, 0.96, 1.0)
	# The ONE shadow-caster in the mode. A body light with no shadows lights the
	# far wall through the crate in front of you and the darkness stops meaning
	# anything - this is the light whose occlusion the player actually reads.
	light.shadow_enabled = true
	light.shadow_bias = 0.04
	# Parented to the SCENE, not the camera: BodyLight drives its own transform
	# and a parent transform would fight the damping.
	player.get_tree().current_scene.add_child(light)
	light.bind(cam)
	return light
