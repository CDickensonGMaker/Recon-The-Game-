## test_antenna_sway.gd - the RTO's PRC-25 whip must actually bend.
##
## assets/shaders/antenna_sway.gdshader and scripts/visuals/antenna_sway.gd both
## existed, both were finished, and NEITHER was connected to anything: the shader
## was assigned to no mesh and the script was attached to no node. The wiring
## audit found antenna_sway.gd reachable only from an art probe. The whip has
## always been a rigid rod.
##
## GruntDresser._rig_antenna is the seam. This probe holds it.
## Run: godot --headless --path . res://tests/test_antenna_sway.tscn
extends Node

const AntennaSwayScript := preload("res://scripts/visuals/antenna_sway.gd")
const SHADER_PATH: String = "res://assets/shaders/antenna_sway.gdshader"


func _ready() -> void:
	print("=== ANTENNA SWAY (r4bk / wiring) ===")
	var failures: int = 0
	failures += _test_assets_exist()
	failures += _test_dresser_rigs_the_antenna()
	failures += _test_spring_responds_to_acceleration()
	failures += _test_constant_speed_does_not_bend_it()
	failures += _test_tip_travel_is_clamped()

	if failures == 0:
		print("PASS: the whip is driven")
	else:
		print("=== %d FAILURE(S) ===" % failures)
	get_tree().quit(1 if failures > 0 else 0)


func _test_assets_exist() -> int:
	var fails: int = 0
	if load(SHADER_PATH) == null:
		printerr("FAIL: %s missing - nothing can bend the whip" % SHADER_PATH)
		fails += 1
	var src: String = FileAccess.get_file_as_string(
		"res://scripts/visuals/grunt_dresser.gd")
	if not src.contains("_rig_antenna"):
		printerr("FAIL: GruntDresser no longer rigs the antenna - the whip is rigid again")
		fails += 1
	if fails == 0:
		print("  shader present, dresser has the seam")
	return fails


## The seam must run on the radio path specifically, not merely exist.
func _test_dresser_rigs_the_antenna() -> int:
	var src: String = FileAccess.get_file_as_string(
		"res://scripts/visuals/grunt_dresser.gd")
	var call_at: int = src.find("_rig_antenna(root)")
	var radio_at: int = src.find('key == "radio" and on')
	if call_at < 0 or radio_at < 0:
		printerr("FAIL: _rig_antenna is never called from the radio branch")
		return 1
	if absi(call_at - radio_at) > 200:
		printerr("FAIL: _rig_antenna call is not on the radio branch")
		return 1
	print("  rigged when a man is dressed with a radio")
	return 0


## The physics claim in the script's own header: the whip is driven by the
## carrier's ACCELERATION. Starting from rest must deflect the tip.
func _test_spring_responds_to_acceleration() -> int:
	var rig := _make_rig()
	var whip: AntennaSway = rig[0]
	var body: CharacterBody3D = rig[1]

	body.velocity = Vector3(6.0, 0.0, 0.0)      # slammed from rest
	for i in range(6):
		whip._physics_process(1.0 / 60.0)
	var moved: float = whip._angle.length()
	rig[2].queue_free()
	if moved <= 0.0001:
		printerr("FAIL: hard acceleration moved the tip %.5f m - the whip is dead" % moved)
		return 1
	print("  acceleration deflects the tip (%.4f m)" % moved)
	return 0


## The other half of that claim, and the reason it is acceleration-driven: a real
## whip has CAUGHT UP at constant speed. Driving off velocity would leave it
## permanently bent backwards, as if running in a gale.
func _test_constant_speed_does_not_bend_it() -> int:
	var rig := _make_rig()
	var whip: AntennaSway = rig[0]
	var body: CharacterBody3D = rig[1]

	body.velocity = Vector3(6.0, 0.0, 0.0)
	whip._prev_velocity = body.velocity          # already at speed, zero accel
	for i in range(180):                         # three seconds of steady running
		whip._physics_process(1.0 / 60.0)
	var resting: float = whip._angle.length()
	rig[2].queue_free()
	if resting > 0.001:
		printerr("FAIL: at constant speed the tip sits %.4f m off centre - bent in a gale"
			% resting)
		return 1
	print("  constant speed leaves it settled (%.4f m)" % resting)
	return 0


func _test_tip_travel_is_clamped() -> int:
	var rig := _make_rig()
	var whip: AntennaSway = rig[0]
	var body: CharacterBody3D = rig[1]

	# Reversing EVERY frame cancels itself out and never loads the spring - the
	# first draft of this test peaked at 0.011 m against a 0.22 m clamp and so
	# asserted nothing. Hold each direction long enough for the tip to swing out.
	var worst: float = 0.0
	for i in range(240):
		body.velocity = Vector3(120.0 if (i / 10) % 2 == 0 else -120.0, 0.0, 0.0)
		whip._physics_process(1.0 / 60.0)
		worst = maxf(worst, whip._angle.length())
	var limit: float = whip.max_tip_travel
	rig[2].queue_free()
	if worst < limit * 0.9:
		printerr("FAIL: tip only reached %.4f m of its %.4f m clamp - the clamp is untested"
			% [worst, limit])
		return 1
	if worst > limit + 0.0001:
		printerr("FAIL: tip travelled %.4f m past its %.4f m clamp" % [worst, limit])
		return 1
	print("  tip pinned at the %.3f m clamp under sustained reversal" % worst)
	return 0


## A carrier body with a whip under it, materialised so activate() binds.
func _make_rig() -> Array:
	var body := CharacterBody3D.new()
	add_child(body)
	var whip: AntennaSway = AntennaSwayScript.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.01, 1.07, 0.01)
	whip.mesh = mesh
	var mat := ShaderMaterial.new()
	mat.shader = load(SHADER_PATH) as Shader
	whip.material_override = mat
	body.add_child(whip)
	whip.activate()
	return [whip, body, body]
