## test_fake_lights.gd - ADR-026 Part A #1 verification probe.
## Two obligations, in tension, and this probe holds both:
##   1. THE LIGHT DIED. muzzle_flash() and the explosion visual spawn ZERO
##      OmniLight3D. Re-adding one is a canon violation, not a look tweak.
##   2. THE POP DID NOT. Each still spawns self-lit (UNSHADED + emissive)
##      billboard geometry that reads without any scene light, and the flash
##      outlives one frame at our worst measured framerate. Fairness Law:
##      every shot telegraphs.
##   3. IllumFlare KEEPS its real light - it does stealth gameplay work
##      (is_lit() strips night concealment) and is exempt by decree.
## Run: godot --headless --path . res://tests/test_fake_lights.tscn
extends Node

## Worst measured framerate on the reference machine (Intel UHD, 1280x720).
const WORST_FRAME_SECONDS: float = 1.0 / 25.0

var _failures: int = 0
var _checks: int = 0


func _ready() -> void:
	_run()


func _ok(label: String, cond: bool) -> void:
	_checks += 1
	if cond:
		print("  OK   %s" % label)
	else:
		_failures += 1
		print("  FAIL %s" % label)


func _count_lights(n: Node) -> int:
	var total: int = 1 if n is OmniLight3D or n is SpotLight3D else 0
	for c in n.get_children():
		total += _count_lights(c)
	return total


func _selflit_quads(n: Node) -> int:
	var total: int = 0
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		var mat: Material = mi.material_override
		if mat == null and mi.mesh != null:
			mat = mi.mesh.surface_get_material(0)
		if mat is BaseMaterial3D:
			var bm := mat as BaseMaterial3D
			if bm.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED and bm.emission_enabled:
				total += 1
	for c in n.get_children():
		total += _selflit_quads(c)
	return total


func _run() -> void:
	print("=== ADR-026 #1 FAKE LIGHTS ===")
	var host := Node3D.new()
	add_child(host)

	# --- 1. muzzle flash -----------------------------------------------------
	GunFX.muzzle_flash(host, Vector3(0, 1.5, 0))
	var flash: Node = host.get_child(0) if host.get_child_count() > 0 else null
	_ok("muzzle_flash spawns a visual at all", flash != null)
	if flash != null:
		_ok("muzzle_flash spawns 0 real-time lights", _count_lights(flash) == 0)
		_ok("muzzle_flash keeps >=2 self-lit quads (core + spikes)",
			_selflit_quads(flash) >= 2)
	_ok("flash outlives one frame at 25 fps",
		GunFX.FLASH_SECONDS > WORST_FRAME_SECONDS)
	_ok("flash cap cannot silence a visible shooter", GunFX.MAX_FLASHES >= 32)

	# --- 2. explosion --------------------------------------------------------
	var ehost := Node3D.new()
	add_child(ehost)
	GunFX.play_explosion_3d(ehost, Vector3(0, 0, -5.0))
	var boom: Node = ehost.get_child(0) if ehost.get_child_count() > 0 else null
	_ok("explosion spawns a visual at all", boom != null)
	if boom != null:
		_ok("explosion spawns 0 real-time lights", _count_lights(boom) == 0)
		_ok("explosion keeps its self-lit fireball", _selflit_quads(boom) >= 1)

	# --- 3. the gameplay light that must survive -----------------------------
	var fhost := Node3D.new()
	add_child(fhost)
	var flare: IllumFlare = IllumFlare.pop(fhost, Vector3(20, 0, 20))
	_ok("IllumFlare KEEPS a real light (strips night concealment)",
		flare != null and _count_lights(flare) >= 1)
	_ok("IllumFlare.is_lit still answers inside its circle",
		IllumFlare.is_lit(Vector3(20, 0, 20)))

	# --- 4. NEGATIVE CONTROL -------------------------------------------------
	# A probe that has never failed proves nothing. Build the exact shape this
	# probe exists to reject - a flash root with an OmniLight bolted on - and
	# assert the detector catches it. If this line ever passes silently, the
	# checks above are decorative.
	var fake := Node3D.new()
	add_child(fake)
	var decoy := MeshInstance3D.new()
	decoy.mesh = QuadMesh.new()
	fake.add_child(decoy)
	fake.add_child(OmniLight3D.new())
	_ok("NEGATIVE CONTROL: detector sees a planted OmniLight",
		_count_lights(fake) == 1)
	_ok("NEGATIVE CONTROL: detector rejects an unlit quad as self-lit",
		_selflit_quads(fake) == 0)

	print("=== %d checks, %d FAIL ===" % [_checks, _failures])
	get_tree().quit(1 if _failures > 0 else 0)
