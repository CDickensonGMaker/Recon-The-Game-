class_name Ladder
extends Node3D

## Climbable ladder. Ported from CatacombsOfGore (scripts/world/ladder.gd +
## player_controller.gd:1076-1193) rather than written fresh, because that version already
## paid for four constraints that are not obvious until a ladder refuses to work:
##
## 1. move_and_slide CANNOT climb a ladder. It collides with the rungs and stalls. The climb
##    writes global_position.y directly and leaves the physics solver alone.
## 2. NEVER end the climb on body_exited. Snapping the climber onto the rail moves him out of
##    the trigger that just caught him, which cancels the climb on its first frame. Dismount
##    is the climber's decision; the trigger only ever starts one.
## 3. Stand him off the rail by FACE_OFFSET or the body sits inside the rungs.
## 4. Zero his velocity every frame or he launches when he steps off.
##
## Geometry comes from marker pairs baked into the GLB - `ladder_bottom*` / `ladder_top*` -
## so a model gains a ladder by gaining two empties, with no scene work. The marker's local
## +Z is its facing (gen_firebase.py:40-42, never re-derive) and points away from the
## structure, which is the side the climber stands on.

const FACE_OFFSET: float = 0.55   ## how far off the rail the body stands, clear of the rungs
const DISMOUNT_LIP: float = 0.30  ## step up at the top so he lands ON the platform
const DISMOUNT_IN: float = 0.95   ## and inboard, so he does not slide straight back off
const PAIR_RANGE: float = 6.0     ## a top marker further than this is a different ladder

## ---------------------------------------------------------------------------
## THE WEDGE, MEASURED 2026-09-09 (Summoner: "i got stuck between a ladder and
## sandbags getting off the ladder").
##
## The three constants above were ported from CatacombsOfGore with the rest of this
## file (see note above) and NEVER RE-MEASURED against this tower. Measured against
## fsb_main_v3.glb's own -colonly meshes with the player capsule (r 0.40, h 1.80):
##
##   ladder_bottom / .001 / .003 - the BOTTOM step-off resolves 0.094m clear, i.e.
##     PENETRATING the tower shell by 0.31m. That is 3 of the 4 ladders in the game,
##     every single time he steps off the bottom.
##   the same three TOP OUT with 0.07m of margin.
##   .002's step-off penetrates the mound by 0.12m.
##
## Sweeping FACE_OFFSET does not fix it - the obstruction is ~1m deep
## (0.55 -> 0.09, 0.70 -> 0.00, 0.85 -> 0.00, 1.20 -> 0.29, 1.50 -> 0.52) - so there
## is no constant that works, only a test.
##
## REFUTED in the same measurement, so nobody re-derives it: NO SANDBAG IS INVOLVED.
## The nearest sandbag mesh of any family measured 3.91m from any ladder waypoint (it
## was fb_sbg_seg_026; that family left the bake on 2026-09-10 when the parapet became
## kit parts, and test_ladder_dismount still passes against the kit wire). What he read
## as sandbags is the tower's own parapet - deck 9.77, wall band 9.8->10.65, roof 11.84
## - and he tops out 0.20m above the deck in a 1.5m slot. The asset is fine.
##
## WHY TIGHT BECOMES WEDGED rather than merely awkward: site_planner.gd:1823-1832
## forces backface_collision = true on every concave shape in the compound, applied
## to every StaticBody3D at :1884-1891. A body written inside one of those has no
## face to escape through in EITHER direction. And the player has no unstick
## watchdog, though enemy_base.gd:206-232 and ally_base.gd:56-83 both give one to
## every AI.
##
## THE RULE THIS ESTABLISHES: never write a climber into geometry. Resolve the point
## against the world first, and if nothing is clear, DO NOT LEAVE THE LADDER.
## Guarded by tests/test_ladder_dismount.tscn, which goes red on 3 ladders the
## moment the resolver is reverted.
## ---------------------------------------------------------------------------

## Must match player.tscn's CapsuleShape3D (:9-11) and Player.STAND_HEIGHT. A ladder
## cannot ask the climber for these - it must resolve a point BEFORE anyone stands
## there - so they are duplicated here deliberately and named so a drift is findable.
const CLIMBER_RADIUS: float = 0.40
const CLIMBER_HEIGHT: float = 1.80
## Search: 8 compass bearings x rings of 0.25m out to 1.5m, then the same again
## lifted, because a blocked step-off is usually blocked by a shell one step thick.
const SEARCH_STEP_M: float = 0.25
const SEARCH_RINGS: int = 6
const SEARCH_LIFT_M: float = 0.25
const SEARCH_LIFTS: int = 2
## A resolved point must have ground under it or the search can answer with mid-air.
const FLOOR_PROBE_M: float = 2.5
## Returned when the world offers nowhere to stand. Callers MUST test is_finite().
const NO_CLEAR_POINT := Vector3.INF

@export var climb_speed: float = 2.6

var _bottom: Vector3 = Vector3.ZERO
var _top: Vector3 = Vector3.ZERO
var _face: Vector3 = Vector3.BACK
var _climber: Node3D = null
var _area: Area3D = null


## Build one Ladder per `ladder_bottom*` marker under `root`, pairing each with its nearest
## `ladder_top*`. Returns how many were built.
static func build_from_markers(root: Node3D) -> int:
	if root == null:
		return 0
	var bottoms: Array[Node3D] = []
	var tops: Array[Node3D] = []
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for c in n.get_children():
			stack.append(c)
		if not (n is Node3D):
			continue
		var nm: String = String(n.name)
		if nm.begins_with("ladder_bottom"):
			bottoms.append(n as Node3D)
		elif nm.begins_with("ladder_top"):
			tops.append(n as Node3D)

	var built: int = 0
	for b in bottoms:
		var best: Node3D = null
		var best_d: float = PAIR_RANGE
		for t in tops:
			var d: float = Vector2(b.global_position.x - t.global_position.x,
				b.global_position.z - t.global_position.z).length()
			if d < best_d:
				best_d = d
				best = t
		if best == null:
			push_warning("[Ladder] %s has no ladder_top within %.1f m - skipped" % [b.name, PAIR_RANGE])
			continue
		var lad := Ladder.new()
		lad.name = "Ladder_%d" % built
		root.add_child(lad)
		# Local +Z of the bottom marker is its facing, and faces away from the structure.
		lad.setup(b.global_position, best.global_position, b.global_transform.basis.z)
		built += 1
	return built


func setup(bottom_pos: Vector3, top_pos: Vector3, face_dir: Vector3) -> void:
	_bottom = bottom_pos
	_top = top_pos
	var f := Vector3(face_dir.x, 0.0, face_dir.z)
	_face = f.normalized() if f.length() > 0.01 else Vector3.BACK
	global_position = _bottom
	_build_trigger()


func _build_trigger() -> void:
	var height: float = maxf(1.0, _top.y - _bottom.y)
	_area = Area3D.new()
	_area.name = "ClimbTrigger"
	_area.collision_layer = 0
	_area.collision_mask = 2          # layer 2 = player (RECON physics layer table)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.4, height, 1.4)
	shape.shape = box
	_area.add_child(shape)
	add_child(_area)
	# Centred on the standing side, not on the rungs, so he catches it walking up to it.
	var mid: Vector3 = (_bottom + _top) * 0.5 + _face * FACE_OFFSET
	_area.global_position = mid
	_area.body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	if _climber != null or body == null:
		return
	if not body.is_in_group("player"):
		return
	if not body.has_method("start_climbing"):
		return
	_climber = body
	body.call("start_climbing", self)


## Deliberately no _on_body_exited. See note 2 in the header.

func bottom_y() -> float:
	return _bottom.y


func top_y() -> float:
	return _top.y


## World point the climber's body is held at for a given height.
func rail_point(y: float) -> Vector3:
	var p: Vector3 = _bottom + _face * FACE_OFFSET
	p.y = y
	return p


## The raw geometric top-out point, BEFORE any clearance test. Kept separate so the
## probe can measure the nominal against the resolved and prove the resolver moved.
func nominal_dismount_point() -> Vector3:
	var p: Vector3 = _top - _face * DISMOUNT_IN
	p.y = _top.y + DISMOUNT_LIP
	return p


## The raw geometric bottom step-off point, BEFORE any clearance test. This is where
## player.gd used to drop him unconditionally, and on 3 of the 4 ladders in the game
## it is 0.31m inside the tower shell.
func nominal_step_off_point() -> Vector3:
	var p: Vector3 = rail_point(_bottom.y)
	p.y = _bottom.y
	return p


## Where he ends up when he tops out: up onto the deck and inboard off the rail, and
## then resolved against the world so he is never written into geometry.
## Returns NO_CLEAR_POINT when the deck offers nowhere to stand - the caller must
## test is_finite() and keep him on the ladder rather than teleport him into a wall.
func dismount_point() -> Vector3:
	return _resolve_standing(nominal_dismount_point())


## Where he ends up when he steps off the bottom, resolved the same way.
## Returns NO_CLEAR_POINT when nothing near the foot of the ladder is clear.
func step_off_point() -> Vector3:
	return _resolve_standing(nominal_step_off_point())


## Nearest point to `nominal` where the climber's capsule fits AND has ground under
## it. Searches 8 bearings x rings of SEARCH_STEP_M, nearest ring first, then lifts.
## The rail itself is the last candidate: it is the one place we KNOW is clear,
## because he has been standing in it for the whole climb.
func _resolve_standing(nominal: Vector3) -> Vector3:
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	if space == null:
		# No physics to ask. Return the nominal point unchanged rather than refuse a
		# dismount in a context (a headless plan pass) that has no world to be stuck in.
		return nominal
	var out: Vector3 = _face
	out.y = 0.0
	if out.length_squared() < 0.0001:
		out = Vector3.BACK
	out = out.normalized()
	var right: Vector3 = out.cross(Vector3.UP).normalized()
	# Lifts run BOTH ways, nearest first. Searching only upward was wrong and the probe
	# caught it: a top-out blocked by the tower's parapet wall band (9.8->10.65) is
	# blocked by MORE wall the higher you look, and the deck it wants is BELOW the lip.
	for dy in _lift_ladder():
		for ring in range(SEARCH_RINGS + 1):
			var d: float = float(ring) * SEARCH_STEP_M
			for bearing in range(8):
				if ring == 0 and bearing > 0:
					break  # the centre is one point, not eight
				var a: float = float(bearing) * TAU / 8.0
				var offset: Vector3 = (out * cos(a) + right * sin(a)) * d
				var feet: Vector3 = nominal + offset + Vector3(0.0, dy, 0.0)
				if _capsule_free(space, feet) and _has_floor(space, feet):
					return feet
	# Nowhere to stand. Say so honestly and let the caller keep him on the rail.
	# There is deliberately NO rail fallback here: the rail is CLEAR but it is not
	# GROUND, and returning it as a dismount point hands the player a spot in mid-air
	# at the top of a tower. That was this function's first draft and the probe failed
	# it - a wedge traded for a fall is not a fix.
	return NO_CLEAR_POINT


## Vertical offsets to try, nearest to the nominal height first, alternating down then
## up so a deck under the lip is found before a shelf above it.
func _lift_ladder() -> Array[float]:
	var lifts: Array[float] = [0.0]
	for i in range(1, SEARCH_LIFTS + 1):
		lifts.append(-float(i) * SEARCH_LIFT_M)
		lifts.append(float(i) * SEARCH_LIFT_M)
	return lifts


## Does the climber's capsule fit here, standing on these feet? Mirrors the shape and
## the 4cm of daylight Player._capsule_clips uses (player.gd:1831-1841) so the two
## agree about what "fits" means.
func _capsule_free(space: PhysicsDirectSpaceState3D, feet: Vector3) -> bool:
	var cap := CapsuleShape3D.new()
	cap.radius = CLIMBER_RADIUS
	cap.height = maxf(CLIMBER_HEIGHT - 0.04, CLIMBER_RADIUS * 2.0 + 0.01)
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = cap
	q.transform = Transform3D(Basis.IDENTITY,
		feet + Vector3(0.0, CLIMBER_HEIGHT * 0.5 + 0.02, 0.0))
	q.collision_mask = 1
	q.exclude = _climber_rids()
	return space.intersect_shape(q, 1).is_empty()


## Is there ground under these feet? Without this the search happily answers with a
## point in mid-air beside the tower, which trades a wedge for a fall.
func _has_floor(space: PhysicsDirectSpaceState3D, feet: Vector3) -> bool:
	var q := PhysicsRayQueryParameters3D.create(
		feet + Vector3(0.0, 0.1, 0.0), feet + Vector3(0.0, -FLOOR_PROBE_M, 0.0))
	q.collision_mask = 1
	q.exclude = _climber_rids()
	return not space.intersect_ray(q).is_empty()


## The climber must not collide with himself while we look for somewhere to put him.
func _climber_rids() -> Array[RID]:
	var rids: Array[RID] = []
	var body := _climber as CollisionObject3D
	if body != null and is_instance_valid(body):
		rids.append(body.get_rid())
	return rids


func release_climber() -> void:
	_climber = null


func _exit_tree() -> void:
	if _area != null and _area.body_entered.is_connected(_on_body_entered):
		_area.body_entered.disconnect(_on_body_entered)
