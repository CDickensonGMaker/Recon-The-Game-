## test_ladder_dismount.gd - A LADDER MAY NEVER PUT THE PLAYER INSIDE GEOMETRY.
##
## Summoner, playtest 2026-09-09: "and i got stuck between a ladder and sandbags
## getting off the ladder."
##
## MEASURED CAUSE (War Room 2026-09-09, analysis/lead_programmer.md). The climb state
## machine wrote global_position with ZERO clearance test, off three constants
## (FACE_OFFSET / DISMOUNT_LIP / DISMOUNT_IN) ported wholesale from CatacombsOfGore
## and never re-measured against this tower. Against fsb_main_v3.glb's own -colonly
## meshes with the player capsule (r 0.40, h 1.80):
##
##   ladder_bottom / .001 / .003 - BOTTOM step-off 0.094m clear, i.e. PENETRATING the
##     tower shell by 0.31m. Three of the four ladders in the game, EVERY TIME.
##   the same three TOP OUT with 0.07m of margin.
##   .002's step-off penetrates the mound by 0.12m.
##
## No constant fixes it - the obstruction is ~1m deep, so sweeping FACE_OFFSET goes
## 0.55 -> 0.09, 0.70 -> 0.00, 0.85 -> 0.00, 1.20 -> 0.29, 1.50 -> 0.52.
##
## REFUTED and recorded so nobody re-derives it: NO SANDBAG IS INVOLVED. The nearest
## sandbag mesh of any family is fb_sbg_seg_026, 3.91m from any ladder waypoint. What
## he read as sandbags is the tower's own parapet. THE ASSET IS FINE.
##
## WHAT THIS ASSERTS - the invariant, not the workaround: every point a Ladder will
## hand the player must (a) fit his capsule and (b) have ground under it. It goes RED
## on three ladders the instant Ladder._resolve_standing is reverted, because the
## nominal points those ladders resolve FROM are blocked today. It does NOT assert
## that the nominal points stay blocked - if the asset is ever fixed, the invariant
## is still the thing worth guarding.
##
## The filename is load-bearing: run_all_tests.ps1:27 globs test_*.tscn only, so a
## probe_-named copy of this file would gate nothing.
##
## Run: godot --headless --path . res://tests/test_ladder_dismount.tscn
extends Node

## fsb_main_v3.glb is the only GLB in the project carrying ladder markers, and it
## carries four pairs. A run that finds fewer has lost ladders to export drift, and
## a probe that then passed would be certifying an empty set.
const EXPECTED_LADDERS: int = 4

## Ladder ends that have no landing surface under this probe's partial repair.
## Measured 2026-09-09: exactly one (Ladder_1's top). This is a RATCHET, not a
## blessing - it exists so the number can never grow unnoticed, and it should be
## driven to 0 by the investigation logged in the playtest list, not raised.
const BASELINE_NO_LANDING: int = 1

var _failures: int = 0


func _fail(msg: String) -> void:
	print("FAIL: ", msg)
	_failures += 1


func _ready() -> void:
	var sc: PackedScene = load(SitePlanner.FSB_MAIN_PATH)
	if sc == null:
		_fail("could not load %s" % SitePlanner.FSB_MAIN_PATH)
		_finish()
		return
	var root := sc.instantiate() as Node3D
	add_child(root)
	# Colliders enter the physics space on the frame after add_child; a shape query
	# fired before that answers "clear" about a world that is not there yet.
	await get_tree().physics_frame
	await get_tree().physics_frame

	# THE RAW SCENE IS NOT THE SHIPPED WORLD, and this probe's first draft measured the
	# raw one. Every structure in fsb_main_v3.glb winds INWARD (site_planner.gd:1818-1822,
	# measured 2026-08-02: signed volume negative for all 19 families,
	# fb_terrain_mound / fb_berm_ring 100% down-facing). A ConcavePolygonShape3D collides
	# only on its front face, so in a bare instantiate the tower decks HAVE NO TOP: a
	# downward ray passes straight through and every point above a deck reads as mid-air.
	# The first run of this probe reported "no clear point anywhere" on Ladder_1 for
	# exactly that reason, and it was the PROBE that was wrong, not the ladder.
	# place_firebase_main forces these double-sided at boot (:1884-1891) and prints the
	# count. Re-implemented here rather than called, because it is private - and a probe
	# that skips a repair the shipping path always performs measures a world nobody plays.
	var flipped: int = _force_backface_collision(root)
	print("[LADDER] %d concave shape(s) forced double-sided to match place_firebase_main" % flipped)
	await get_tree().physics_frame

	var built: int = Ladder.build_from_markers(root)
	if built != EXPECTED_LADDERS:
		_fail("built %d ladder(s), expected %d - marker drift in fsb_main_v3.glb"
			% [built, EXPECTED_LADDERS])
	if built == 0:
		_finish()
		return
	await get_tree().physics_frame

	# The space comes off the instanced root, not off self: this probe extends Node so
	# it never accidentally becomes part of the world it is measuring.
	var space: PhysicsDirectSpaceState3D = root.get_world_3d().direct_space_state
	var nominal_blocked: int = 0
	var no_landing: int = 0
	var checked: int = 0

	for child in root.get_children():
		var lad := child as Ladder
		if lad == null:
			continue
		checked += 1
		for what in ["step_off", "dismount"]:
			var nominal: Vector3 = (lad.nominal_step_off_point() if what == "step_off"
				else lad.nominal_dismount_point())
			var resolved: Vector3 = (lad.step_off_point() if what == "step_off"
				else lad.dismount_point())

			if not _capsule_free(space, nominal):
				nominal_blocked += 1

			if not resolved.is_finite():
				# NOT a wedge, and deliberately not a hard failure at the baseline count.
				# NO_CLEAR_POINT means the ladder refuses to hand him over and he stays on
				# the rail, which is SAFE - he can always climb back down. It is a lesser,
				# pre-existing defect: that end of that ladder has no landing surface.
				# Measured 2026-09-09 under the partial repair this probe performs:
				# exactly one, Ladder_1's TOP at (71.46, 10.31, -22.96), where a 5x5m grid
				# at six heights finds NOTHING solid - no deck, no wall, open air.
				# UNVERIFIED and recorded as such: this probe forces windings but does NOT
				# run _repair_glb_colliders' box-hull re-meshing, so a deck collider that
				# the shipping path CREATES would not exist here. Do not report "a tower
				# has no deck collider" off this number until that is checked.
				no_landing += 1
				continue
			if not _capsule_free(space, resolved):
				_fail("%s %s: resolved point %s is INSIDE geometry"
					% [lad.name, what, resolved])
			if not _has_floor(space, resolved):
				_fail("%s %s: resolved point %s has no ground under it - a wedge traded for a fall"
					% [lad.name, what, resolved])

	print("[LADDER] checked %d ladder(s), %d of %d nominal point(s) blocked before resolving, %d with no landing"
		% [checked, nominal_blocked, checked * 2, no_landing])
	if no_landing > BASELINE_NO_LANDING:
		_fail("%d ladder end(s) have no landing surface, baseline is %d - a ladder lost its deck"
			% [no_landing, BASELINE_NO_LANDING])
	if nominal_blocked == 0:
		# Not a failure - the asset may legitimately have been fixed - but a green run
		# with nothing blocked proves nothing about the resolver, and saying so is the
		# difference between a probe and a decoration.
		print("[LADDER] NOTE: no nominal point was blocked, so this run did not exercise the resolver")
	_finish()


func _finish() -> void:
	if _failures == 0:
		print("test_ladder_dismount: PASS")
	else:
		print("test_ladder_dismount: %d FAILURE(S)" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


## Same shape and the same 4cm of daylight Player._capsule_clips uses
## (player.gd:1831-1841) and Ladder._capsule_free mirrors, so all three agree about
## what "fits" means. Deliberately re-implemented here rather than calling the
## Ladder's own helper: a probe that asks the code under test whether it is correct
## measures nothing.
func _capsule_free(space: PhysicsDirectSpaceState3D, feet: Vector3) -> bool:
	if space == null:
		return false
	var cap := CapsuleShape3D.new()
	cap.radius = Ladder.CLIMBER_RADIUS
	cap.height = maxf(Ladder.CLIMBER_HEIGHT - 0.04, Ladder.CLIMBER_RADIUS * 2.0 + 0.01)
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = cap
	q.transform = Transform3D(Basis.IDENTITY,
		feet + Vector3(0.0, Ladder.CLIMBER_HEIGHT * 0.5 + 0.02, 0.0))
	q.collision_mask = 1
	return space.intersect_shape(q, 1).is_empty()


func _has_floor(space: PhysicsDirectSpaceState3D, feet: Vector3) -> bool:
	if space == null:
		return false
	var q := PhysicsRayQueryParameters3D.create(
		feet + Vector3(0.0, 0.1, 0.0),
		feet + Vector3(0.0, -Ladder.FLOOR_PROBE_M, 0.0))
	q.collision_mask = 1
	return not space.intersect_ray(q).is_empty()


## Mirrors SitePlanner._force_backface_collision (:1823-1834). See the note in _ready.
func _force_backface_collision(root: Node) -> int:
	var fixed: int = 0
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for c in n.get_children():
			stack.append(c)
		var body := n as StaticBody3D
		if body == null:
			continue
		for child in body.get_children():
			var cs := child as CollisionShape3D
			if cs == null:
				continue
			var concave := cs.shape as ConcavePolygonShape3D
			if concave == null or concave.backface_collision:
				continue
			concave.backface_collision = true
			fixed += 1
	return fixed
