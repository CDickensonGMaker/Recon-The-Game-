## test_fire_mission.gd - the placed fire mission, and the rounds that answer it.
##
## Two things shipped together and this probe holds both:
##   1. A call is SIGHTED before it is sent. Picking one arms a footprint and spends
##      nothing; LMB sends it, RMB withdraws it. Nothing may spend on the way in.
##   2. The ordnance is REAL. Before this, every fire mission was a create_timer and
##      an instant blast at a point - nothing flew. Now a shell is solved onto the
##      spot the sheaf picked, and the pool may not recycle it out of the air.
##
## Run: godot --headless --path . res://tests/test_fire_mission.tscn
extends Node

var _fails: int = 0


## Flat ground for the rig. A real heightmap indexes 0..map_size and reads out of
## bounds for the coordinates a probe uses; this answers for any point and never
## allocates. Same trick ai_stress_arena uses for its fire-support host.
class FlatTerrain extends TerrainManager:
	func _ready() -> void:
		pass

	func get_height_at(_world_pos: Vector3) -> float:
		return 0.0

	func get_normal_at(_world_pos: Vector3) -> Vector3:
		return Vector3.UP

	func modify_terrain(_c: Vector3, _r: float, _m: Callable) -> void:
		pass


class Rig:
	var player: CharacterBody3D
	var director: FieldDirector
	var squad: SquadSystem
	var rto: AllyBase
	var world: GameWorld
	var terrain: FlatTerrain


func _ready() -> void:
	print("=== FIRE MISSION: place it, then send it ===")
	await get_tree().physics_frame
	await _test_arming_spends_nothing()
	await _test_cancel_spends_nothing()
	await _test_commit_spends_exactly_one()
	await _test_danger_close_still_gates_the_send()
	await _test_broadside_axis()
	await _test_hangup_clears_the_arm()
	await _test_no_rto_refuses_the_arm()
	_test_footprints_match_the_ordnance()
	_test_ballistics_lands_on_the_point()
	await _test_pool_never_recycles_a_live_warhead()
	_test_spooky_is_gone()

	if _fails == 0:
		print("=== FIRE MISSION PASS ===")
	else:
		print("=== FIRE MISSION FAIL (%d) ===" % _fails)
	get_tree().quit(1 if _fails > 0 else 0)


func _ok(cond: bool, msg: String) -> void:
	if cond:
		print("  PASS: %s" % msg)
	else:
		print("  FAIL: %s" % msg)
		_fails += 1


## `height` and `pitch` are the only levers this probe has on RANGE, and range is
## what danger close measures. Standing him on a 200m shelf and looking shallow puts
## the mark far from every friendly; standing him on the deck and looking down puts
## it at his own boots. Neither moves the RTO, whose 10m leash is what makes the
## radio work at all - moving HIM would fail the call for the wrong reason.
func _make_rig(rto_alive: bool = true, pitch: float = -45.0, height: float = 200.0) -> Rig:
	var r := Rig.new()
	r.player = load("res://scenes/player/player.tscn").instantiate() as CharacterBody3D
	add_child(r.player)
	r.player.set_physics_process(false)
	r.player.global_position = Vector3(0.0, height, 0.0)
	await get_tree().physics_frame
	var head: Node3D = r.player.get_node("Head") as Node3D
	head.rotation_degrees.x = pitch
	await get_tree().physics_frame

	r.terrain = FlatTerrain.new()
	add_child(r.terrain)

	r.world = GameWorld.new()
	r.world.player = r.player
	r.world.map_size = 2000.0
	r.world.terrain_manager = r.terrain

	r.director = FieldDirector.new()
	r.director.name = "ProbeFieldDirector"
	add_child(r.director)
	r.director.setup(r.world)
	r.director._hunter_pool = 0
	r.director.set_process(false)   # the probe drives the seams, not the input poll
	r.director.fire_support = {"bombs": 9, "napalm": 9, "arty": 9, "mortar": 9, "spectre": 9, "cbu": 9}

	r.squad = SquadSystem.new()
	r.squad.set_physics_process(false)
	r.squad.set_process(false)
	add_child(r.squad)

	if rto_alive:
		r.rto = AllyBase.spawn_ally(self, r.player.global_position + Vector3(2.0, 0.0, 0.0))
		r.rto.set_physics_process(false)
		r.rto.add_to_group("radioman")
		r.rto.member = {"nick": "SPARKS", "mos": "RTO"}
		r.squad.members.append(r.rto)
	r.director.squad_system = r.squad
	await get_tree().physics_frame
	return r


func _tear_down(r: Rig) -> void:
	if r.world != null and is_instance_valid(r.world):
		r.world.free()
	for n in [r.rto, r.squad, r.director, r.terrain, r.player]:
		if n != null and is_instance_valid(n):
			n.queue_free()
	_clear_projectiles()
	await get_tree().physics_frame


func _clear_projectiles() -> void:
	if CombatManager.projectile_pool != null:
		CombatManager.projectile_pool.clear_all()
	if CombatManager.bullets != null:
		CombatManager.bullets.clear_all()


## ---------------- 1. arming is free ----------------
func _test_arming_spends_nothing() -> void:
	print("-- 1. sighting a mission spends nothing --")
	var r: Rig = await _make_rig()
	var before: Dictionary = r.director.fire_support.duplicate(true)
	r.director.arm_fire_mission("mortar")
	_ok(r.director.armed_kind == "mortar", "the call is armed (armed_kind=%s)" % r.director.armed_kind)
	_ok(r.director.armed_target != Vector3.ZERO, "a target was placed on the ground")
	_ok(r.director.fire_support == before, "the allotment is UNTOUCHED by arming")
	_tear_down(r)


## ---------------- 2. backing out is free ----------------
func _test_cancel_spends_nothing() -> void:
	print("-- 2. withdrawing costs nothing --")
	var r: Rig = await _make_rig()
	var before: Dictionary = r.director.fire_support.duplicate(true)
	r.director.arm_fire_mission("arty")
	r.director.cancel_fire_mission()
	_ok(r.director.armed_kind == "", "the arm is cleared")
	_ok(r.director.fire_support == before, "the allotment is UNTOUCHED by a withdrawal")
	_tear_down(r)


## ---------------- 3. the send is what costs ----------------
func _test_commit_spends_exactly_one() -> void:
	print("-- 3. the send spends exactly one --")
	var r: Rig = await _make_rig()
	r.director.arm_fire_mission("mortar")
	_ok(not r.director.armed_danger_close(), "the mark is well clear of our own men")
	var before: int = int(r.director.fire_support["mortar"])
	r.director.commit_fire_mission()
	_ok(int(r.director.fire_support["mortar"]) == before - 1,
		"one mortar mission spent (%d -> %d)" % [before, int(r.director.fire_support["mortar"])])
	_ok(r.director.armed_kind == "", "the arm cleared on dispatch")
	_ok(not r.director.fire_menu_open, "the call going out took him off the horn")
	_tear_down(r)


## ---------------- 4. danger close still bites ----------------
func _test_danger_close_still_gates_the_send() -> void:
	print("-- 4. a man in the footprint still costs a second press --")
	# On the deck, looking down: the mark lands ~10m in front of his boots. Danger
	# close measures in 3D, so he has to be standing ON the ground he is shelling.
	var r: Rig = await _make_rig(true, -10.0, 0.0)
	r.director.arm_fire_mission("mortar")
	_ok(r.director.armed_danger_close(), "the placement reads DANGER CLOSE with the mark on our own position")
	var before: int = int(r.director.fire_support["mortar"])
	r.director.commit_fire_mission()
	_ok(int(r.director.fire_support["mortar"]) == before,
		"the FIRST press spent nothing - it asked for a confirm")
	_ok(r.director.armed_kind == "mortar", "the call stays armed through the confirm")
	r.director.commit_fire_mission()
	_ok(int(r.director.fire_support["mortar"]) == before - 1,
		"the SECOND press sent it (%d -> %d)" % [before, int(r.director.fire_support["mortar"])])
	_tear_down(r)

	# Negative control: with the men clear, ONE press is enough. Without this, a
	# probe that always double-presses would pass against a broken danger-close.
	var c: Rig = await _make_rig()   # shallow look: the mark is 200m out
	c.director.arm_fire_mission("mortar")
	var cbefore: int = int(c.director.fire_support["mortar"])
	_ok(not c.director.armed_danger_close(), "control: men clear reads NOT danger close")
	c.director.commit_fire_mission()
	_ok(int(c.director.fire_support["mortar"]) == cbefore - 1, "control: one press sent it")
	_tear_down(c)


## ---------------- 5. the run crosses his front ----------------
func _test_broadside_axis() -> void:
	print("-- 5. the fast mover crosses his view, it does not fly up his sight line --")
	var r: Rig = await _make_rig()
	r.director.arm_fire_mission("napalm")
	var cam: Camera3D = r.player.get_node("Head/Camera3D") as Camera3D
	var fwd: Vector3 = -cam.global_transform.basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	var dot: float = absf(fwd.dot(r.director.armed_dir))
	_ok(dot < 0.01, "the run axis is perpendicular to his facing (|dot|=%.4f)" % dot)
	_tear_down(r)


## ---------------- 6. no arm outlives the net ----------------
func _test_hangup_clears_the_arm() -> void:
	print("-- 6. hanging up drops the armed call --")
	var r: Rig = await _make_rig()
	r.director.arm_fire_mission("cbu")
	_ok(r.director.armed_kind == "cbu", "armed before the hang-up")
	r.director.set_fire_menu_mirror(false)
	_ok(r.director.armed_kind == "", "the arm died with the net - no stale call to send")
	_tear_down(r)


## ---------------- 7. no radio, no call ----------------
func _test_no_rto_refuses_the_arm() -> void:
	print("-- 7. no living RTO in reach refuses the arm --")
	var r: Rig = await _make_rig(false)
	var before: Dictionary = r.director.fire_support.duplicate(true)
	r.director.arm_fire_mission("arty")
	_ok(r.director.armed_kind == "", "arming refused with no RTO")
	_ok(r.director.fire_support == before, "and nothing was spent")
	_tear_down(r)


## ---------------- 8. the shape is the ordnance ----------------
func _test_footprints_match_the_ordnance() -> void:
	print("-- 8. the footprint is the weapon's real reach --")
	var nap: Dictionary = FirePlan.footprint("napalm")
	var expect_len: float = float(FirePlan.NAPALM_DROPS - 1) * FirePlan.NAPALM_SPACING \
		+ 2.0 * FirePlan.NAPALM_BLAST_M
	_ok(is_equal_approx(float(nap.along), expect_len),
		"the napalm strip is as long as the rack lays it (%.1fm)" % float(nap.along))
	_ok(float(nap.along) > float(nap.across), "and it is a STRIP, not a blob")
	_ok(String(nap.shape) == "rect", "napalm draws as a rectangle")
	_ok(String(FirePlan.footprint("cbu").shape) == "ellipse",
		"cluster draws as an ellipse - its bomblets do not fill a rectangle's corners")
	_ok(String(FirePlan.footprint("spectre").shape) == "circle",
		"the gunship draws as a circle - its beaten zone is round")

	# fo_fac is the radioman's hand on the sheaf, and the player must SEE it.
	var green: float = float(FirePlan.footprint("mortar", 0).radius)
	var vet: float = float(FirePlan.footprint("mortar", 8).radius)
	_ok(vet < green, "a veteran RTO draws a TIGHTER mortar circle (%.1fm vs %.1fm)" % [vet, green])
	var green_a: float = float(FirePlan.footprint("arty", 0).radius)
	var vet_a: float = float(FirePlan.footprint("arty", 8).radius)
	_ok(vet_a < green_a, "and a tighter artillery sheaf (%.1fm vs %.1fm)" % [vet_a, green_a])

	# The ring must cover where the rounds actually go: the sheaf plus the blast.
	_ok(is_equal_approx(green, FirePlan.MORTAR_SHEAF_M + FirePlan.MORTAR_BLAST_M),
		"the mortar ring is sheaf + blast, not a decorative radius")


## ---------------- 9. the shell lands where it was promised ----------------
func _test_ballistics_lands_on_the_point() -> void:
	print("-- 9. the arc solver puts the round ON the point --")
	var g: float = 9.8
	var dt: float = 1.0 / 60.0
	for case in [
		{"from": Vector3(0, 260, -300), "to": Vector3(0, 0, 0), "t": 4.0},
		{"from": Vector3(-120, 90, 40), "to": Vector3(35, 12, -60), "t": 2.5},
		{"from": Vector3(500, 400, 500), "to": Vector3(120, 5, -80), "t": 6.0},
	]:
		var v: Vector3 = Ballistics.solve_velocity(case.from, case.to, case.t, g, dt)
		# Step it exactly as ProjectileBase does: gravity onto velocity, then move.
		var p: Vector3 = case.from
		var steps: int = int(round(float(case.t) / dt))
		for i in range(steps):
			v.y -= g * dt
			p += v * dt
		var miss: float = p.distance_to(case.to)
		_ok(miss < 0.25, "a %.1fs round lands %.3fm from its aim point" % [float(case.t), miss])


## ---------------- 10. the pool may not eat a round in flight ----------------
func _test_pool_never_recycles_a_live_warhead() -> void:
	print("-- 10. a warhead in the air is never recycled to make room --")
	var shell: ProjectileData = load("res://data/projectiles/mortar_81mm.tres") as ProjectileData
	var bullet: ProjectileData = load("res://data/projectiles/m79_he.tres") as ProjectileData
	_ok(shell != null and bullet != null, "the warhead profiles load")
	if shell == null:
		return
	_clear_projectiles()
	var warhead: ProjectileBase = CombatManager.spawn_projectile(shell, null, Vector3(0, 300, 0), Vector3.DOWN)
	_ok(warhead != null and warhead.is_active, "a shell is in the air")
	# Swamp the pool well past its cap.
	for i in range(ProjectilePool.MAX_ACTIVE_PROJECTILES * 2):
		CombatManager.spawn_projectile(bullet, null, Vector3(float(i), 5, 0), Vector3.FORWARD)
	# Identity, not liveness: an evicted round is handed straight back out as the next
	# bullet, so it is still "valid" and still "active" - it is simply no longer the
	# shell that was promised to the ground. Ask what it is CARRYING.
	var still_a_shell: bool = warhead != null and is_instance_valid(warhead) \
		and warhead.is_active and warhead.projectile_data != null \
		and warhead.projectile_data.id == "mortar_81mm"
	_ok(still_a_shell, "the shell SURVIVED the flood - it will still land where the ring was drawn")
	_clear_projectiles()
	await get_tree().physics_frame


## ---------------- 11. the corpse is buried ----------------
func _test_spooky_is_gone() -> void:
	print("-- 11. the AC-47 it replaced is deleted, not parked beside it --")
	_ok(not ResourceLoader.exists("res://scripts/vehicles/spooky_gunship.gd"),
		"spooky_gunship.gd is gone from disk")
	_ok(not ClassDB.class_exists("SpookyGunship"), "and SpookyGunship resolves to nothing")
