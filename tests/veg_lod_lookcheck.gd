## veg_lod_lookcheck.gd - WINDOWED look-check for TreeCoverLayer (bead xih4).
## Renders a dense lane of vegetation from 3m to 80m so one frame shows the NEAR
## solids transitioning to the FAR impostor cards. Saves a screenshot and quits.
## This validates the LOOK/LOD (solid near, card far, no pop, scale) in isolation -
## the terrain-driven scatter + live switchover come only if this passes.
## Run (4.7 windowed): Godot_v4.7 --path . res://tests/veg_lod_lookcheck.tscn -- --shot=<path>
extends Node3D

const TreeCoverLayerScript := preload("res://terrain/vegetation/tree_cover_layer.gd")

# Cover-givers + concealment, a representative jungle mix.
const SPECIES := [
	"broadleaf_a", "broadleaf_b", "jungle_palm_a1", "jungle_palm_b2", "bamboo_a", "bamboo_b",
	"fern_a", "fern_b", "bush_a", "elephant_grass_a", "banana_a",
]

var _shot: String = ""
var _t: float = 0.0
var _shot_done: bool = false


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot="):
			_shot = a.substr(7)

	# Daylight so the geometry reads clearly for the look assessment.
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.55, 0.68, 0.85)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.7, 0.75, 0.8)
	env.ambient_light_energy = 0.6
	env.fog_enabled = true
	env.fog_density = 0.008
	env.fog_light_color = Color(0.6, 0.7, 0.85)
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45.0, 35.0, 0.0)
	sun.light_energy = 1.1
	add_child(sun)

	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(200, 200)
	ground.mesh = pm
	var gmat := StandardMaterial3D.new()
	gmat.albedo_color = Color(0.28, 0.30, 0.20)
	ground.material_override = gmat
	add_child(ground)

	var cam := Camera3D.new()
	cam.position = Vector3(0.0, 1.7, -2.0)
	cam.rotation_degrees = Vector3(-3.0, 180.0, 0.0)  # yaw 180: Godot cams face -Z, veg is at +Z
	cam.far = 200.0
	add_child(cam)
	cam.make_current()

	var layer: Node3D = TreeCoverLayerScript.new()
	add_child(layer)
	layer.load_species(SPECIES)

	# Dense lane: rows every ~2.2m from z=3..80, jittered, species by a seeded pick.
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var scatter: Array = []
	var z: float = 3.0
	while z < 80.0:
		var n: int = 7
		for i in n:
			var x: float = -28.0 + (float(i) + rng.randf()) * (56.0 / float(n))
			var nm: String = SPECIES[rng.randi() % SPECIES.size()]
			var xf := Transform3D(Basis().rotated(Vector3.UP, rng.randf() * TAU), Vector3(x, 0.0, z + rng.randf() * 1.5))
			scatter.append({"name": nm, "xf": xf})
		z += 2.2
	layer.generate_for_chunk(Vector2i(0, 0), scatter)
	print("[LOOKCHECK] scatter=%d instances, colliders=%d" % [scatter.size(), layer.collider_count()])


func _process(delta: float) -> void:
	_t += delta
	if _t > 1.5 and not _shot_done:
		_shot_done = true
		if not _shot.is_empty():
			var tex: ViewportTexture = get_viewport().get_texture()
			var img: Image = tex.get_image() if tex != null else null
			if img != null:
				img.save_png(_shot)
				print("[LOOKCHECK] wrote ", _shot)
		get_tree().quit(0)
