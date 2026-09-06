## probe_aid_station.gd - THE MEDICAL TENT IS MANNED AND MOVING (item 26).
##
## Caleb, playtest 2026-08-27: "all units inside are T-posed, no animations, and
## no wounded/dead present."
##
## Two independent failures, both measured 2026-09-06 and both asserted here:
##
## 1. THE T-POSE. fsb_main_v3.glb's AnimationPlayer carries 13 clips of 386 tracks
##    each; every clip keys all ten skinned rigs but only ONE rig's values vary.
##    The old driver played twelve clips at once on twelve sibling players sharing
##    the same skeletons - last writer wins, nine rigs pinned at bind pose.
##    NEGATIVE CONTROL: the raw scene, before the driver runs, must have every med
##    rig AT rest. If the "after" state matched the "before" state this probe would
##    be measuring nothing.
##
## 2. THE EMPTY WARD. fsb_garrison_plan seeded the aid station off work type
##    "medic", which the GLB does not carry (488 work markers, zero "medic"), so
##    med_pool was always empty, the seed never ran, and the med_* types sat 27th
##    in a work budget that runs out at "rest": zero medic and zero patient posts
##    in a 34-post plan.
##
## Run: godot --headless --path . res://tests/probe_aid_station.tscn
extends Node

const MED_RIGS: Array[String] = ["PSXRig_med_tend_medic0", "PSXRig_med_tend_medic1",
	"PSXRig_med_tend_medic2", "PSXRig_med_or_patient",
	"PSXRig_med_work_medofficer_0", "PSXRig_med_work_medofficer_1",
	"PSXRig_med_work_medofficer_2"]

var _failures: int = 0


func _fail(msg: String) -> void:
	print("FAIL: ", msg)
	_failures += 1


func _ready() -> void:
	await _check_cast_animates()
	_check_ward_is_manned()
	await _check_ward_bodies()
	if _failures == 0:
		print("probe_aid_station: PASS")
	else:
		print("probe_aid_station: %d FAILURES" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


## A rig is in bind pose when every bone pose equals its bone rest. That is what a
## T-posed mixamorig_* skeleton IS, and it is the exact thing Caleb saw.
static func _bones_off_rest(root: Node3D, rig: String) -> int:
	var r := root.find_child(rig, true, false) as Node3D
	if r == null:
		return -1
	var sk := r.find_child("Skeleton3D", true, false) as Skeleton3D
	if sk == null:
		return -1
	var off: int = 0
	for b in range(sk.get_bone_count()):
		if not sk.get_bone_pose(b).is_equal_approx(sk.get_bone_rest(b)):
			off += 1
	return off


func _check_cast_animates() -> void:
	var sc: PackedScene = load(SitePlanner.FSB_MAIN_PATH)

	# NEGATIVE CONTROL: untouched, every med rig sits in bind pose.
	var raw := sc.instantiate() as Node3D
	add_child(raw)
	await get_tree().process_frame
	for rig in MED_RIGS:
		var off: int = _bones_off_rest(raw, rig)
		if off < 0:
			_fail("negative control: rig %s is not in the firebase scene" % rig)
		elif off != 0:
			_fail("negative control is broken: %s is already posed (%d bones off rest) before any driver ran - this probe cannot prove the fix" % [rig, off])
	raw.queue_free()

	# THE FIX: the placement driver, run exactly as place_firebase_main runs it.
	var live := sc.instantiate() as Node3D
	add_child(live)
	SitePlanner._animate_fsb_baked_cast(live)
	# Two frames: one for the players to enter the tree, one for them to write bones.
	await get_tree().process_frame
	await get_tree().process_frame
	var moving: int = 0
	for rig in MED_RIGS:
		var off2: int = _bones_off_rest(live, rig)
		if off2 <= 0:
			_fail("%s is STILL in bind pose after the driver ran (%d bones off rest) - the T-pose Caleb reported" % [rig, off2])
		else:
			moving += 1
	print("  cast: %d/%d medical rigs animating" % [moving, MED_RIGS.size()])
	live.queue_free()


func _check_ward_is_manned() -> void:
	var plan: Dictionary = SitePlanner.fsb_garrison_plan(Vector3.ZERO)
	var medics: int = 0
	var patients: int = 0
	for p_any in (plan.get("posts", []) as Array):
		var p: Dictionary = p_any
		var occ: String = str(p.occupation)
		if occ == "medic":
			medics += int(p.men)
		elif occ == "patient":
			patients += int(p.men)
	print("  ward: %d medic posts, %d patient posts (ward_wounded=%d)" % [
		medics, patients, CampaignState.ward_wounded])
	if medics < 2:
		_fail("the aid station has %d medics - a surgical team of fewer than two mimes surgery" % medics)
	if patients < 1:
		_fail("the aid station has %d wounded - 'no wounded/dead present' (2026-08-27)" % patients)

	# NEGATIVE CONTROL for the seed: the work type the OLD code keyed on must
	# genuinely be absent, or the bug named above was never the bug.
	SitePlanner._ensure_fsb_markers()
	var plain_medic: int = 0
	var med_any: int = 0
	for e_any in SitePlanner._fsb_work_markers:
		var wt: String = str((e_any as Array)[1])
		if wt == "medic":
			plain_medic += 1
		elif wt.begins_with("med"):
			med_any += 1
	print("  markers: work_medic=%d, work_med_*=%d" % [plain_medic, med_any])
	if plain_medic != 0:
		_fail("negative control is broken: the GLB DOES carry %d work_medic markers, so the old seed was not dead code" % plain_medic)
	if med_any < 10:
		_fail("only %d work_med_* markers - the aid station layout is gone" % med_any)


## 3. THE PLAN IS NOT THE GAME. A post the planner emits still has to become a body
## on a mattress, so this builds the real demo world - the same two calls game_flow
## and test_range make - and counts what is actually standing and lying in the wire.
## A cot patient is a PUPPET (gravity and the BT would drag him onto the floor) and
## he rides COT_DECK_Y above his own floor, so both are asserted, not assumed.
func _check_ward_bodies() -> void:
	var world_scene: PackedScene = load("res://scenes/levels/game_world.tscn")
	var world: GameWorld = world_scene.instantiate()
	world.spawn_player_on_ready = false
	add_child(world)
	var waited: int = 0
	while DamageSystem.terrain_manager == null and waited < 1800:
		await get_tree().process_frame
		waited += 1
	if DamageSystem.terrain_manager == null:
		_fail("terrain never came up - cannot check the ward has real bodies in it")
		world.queue_free()
		return
	var ss := SquadSystem.new()
	ss.name = "ProbeSquad"
	add_child(ss)
	ss.set_physics_process(false)
	ss.set_process(false)
	var director := FieldDirector.new()
	director.name = "ProbeFieldDirector"
	add_child(director)
	director.setup(world)
	director.squad_system = ss
	var plan: Dictionary = MissionGenerator.plan_demo_world(world, 20260906)
	MissionGenerator.build_patrol_world(world, director, plan)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var patients: int = 0
	var medics: int = 0
	var bad: int = 0
	for n_any in get_tree().get_nodes_in_group("firebase_garrison"):
		var man := n_any as Civilian
		if man == null:
			continue
		if man.occupation == "medic":
			medics += 1
			continue
		if man.occupation != "patient":
			continue
		patients += 1
		if not man.puppet:
			_fail("cot patient is not a puppet - gravity and the BT will stand him up")
			bad += 1
		# THE FLOOR IS PROBED FROM BELOW HIM, not from above. floor_y starts its ray
		# 0.4m over the point it is given, so probing at a man already lying on a cot
		# hands back his own cot as "the floor" and a perfectly seated body reads as a
		# 0.00m lift. Starting 0.7m under him clears the mattress and finds the tent.
		var lift: float = man.global_position.y \
			- world.floor_y(man.global_position + Vector3.DOWN * 0.7)
		print("    patient lift=%.3fm (cot deck is %.2f)" % [lift, MissionGenerator.COT_DECK_Y])
		if absf(lift - MissionGenerator.COT_DECK_Y) > 0.15:
			_fail("cot patient rides %.2fm above the tent floor, not %.2f - he is on the dirt, not the mattress"
				% [lift, MissionGenerator.COT_DECK_Y])
			bad += 1
	print("  bodies: %d live patients, %d live medics in the wire (%d bad)" % [patients, medics, bad])
	if patients < 1:
		_fail("the ward plan seated wounded but NO patient body reached the world")
	if medics < 2:
		_fail("the ward plan seated a surgical team but only %d medic bodies reached the world" % medics)
	world.queue_free()

