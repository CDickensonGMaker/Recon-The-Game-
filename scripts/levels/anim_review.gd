class_name AnimReview
extends Node3D

## DEV animation review room. Every clip on a man, named, plus a row of men driven
## through the REAL state map so the wiring is exercised and not just the library.
## Run: godot --path . res://scenes/levels/anim_review.tscn
##
## WHY A NEW ROOM AND NOT THE ARENA. The AI stress arena stays a sterile debugging
## bench by standing ruling (2026-07-26) - ADR-028 Phase 3 is CUT, and hanging an
## animation viewer on it would be re-proposing that by the back door. And the
## observation room is the arena plus the instrument: a FIREFIGHT to watch. Neither
## can show you a camp cook, a prone transition or a death from the left on demand.
## This is a bench in the same family as gun_range / gore_lab / sapper_room.
##
## It reuses ObservationTools for the time controls (slow-motion is how you judge an
## animation). Its OBSERVER mode needs GameManager.player and there is none here, so
## the room carries its own free-fly camera.
##
## KEYS (chosen to miss ObservationTools' own: O I \ [ ] - = 0 and WASD/QE/Shift)
##   , .  page the clip wall          M  next character model
##   N    next driver bank            B  toggle wall / drivers
##   R    restart every driver        F  faster / slower driver step
##   WASD + QE + Shift  fly           Right-mouse drag  look

const WALL_COLS: int = 8
const WALL_ROWS: int = 3
const WALL_SPACING: Vector3 = Vector3(2.2, 0.0, 2.6)
const DRIVER_SPACING: float = 3.0
const DEFAULT_STEP_S: float = 1.6

## The unit whose rig is read for the clip wall. Every character shares Mixamo bone
## names, so any of them can show any clip - but the WALL is built from what THIS rig
## actually carries, never from the library's table of contents. A clip the library
## has and the rig does not is exactly the bug worth seeing.
var _unit_ids: Array[String] = []
var _unit_i: int = 0

var _wall: Node3D = null
var _drivers: Node3D = null
var _cam: Camera3D = null

var _clips: PackedStringArray = PackedStringArray()
var _page: int = 0
var _wall_actors: Array[ModelActor] = []
var _wall_labels: Array[Label3D] = []

var _bank_i: int = 0
var _step_s: float = DEFAULT_STEP_S
var _step_t: float = 0.0
var _driver_actors: Array[ModelActor] = []
var _driver_labels: Array[Label3D] = []
var _driver_idx: Array[int] = []

var _look: Vector2 = Vector2(0.0, -0.15)
var _looking: bool = false


## Each bank is a list of [caption, intent]. The intent goes through the REAL
## SpriteStateMap so a mapping mistake shows up here as a wrong or missing pose -
## the wall alone would only prove the clip exists.
const BANKS: Array = [
	["EIGHT-WAY RUN", [
		["run fwd", "run"], ["run fwd-left", "run@fl"], ["run left", "run@l"],
		["run back-left", "run@bl"], ["run back", "run@b"], ["run back-right", "run@br"],
		["run right", "run@r"], ["run fwd-right", "run@fr"]]],
	["EIGHT-WAY WALK", [
		["walk fwd", "walk"], ["walk fwd-left", "walk@fl"], ["walk left", "walk@l"],
		["walk back-left", "walk@bl"], ["walk back", "walk@b"], ["walk back-right", "walk@br"],
		["walk right", "walk@r"], ["walk fwd-right", "walk@fr"]]],
	["EIGHT-WAY SPRINT", [
		["sprint fwd", "sprint"], ["sprint fwd-left", "sprint@fl"], ["sprint left", "sprint@l"],
		["sprint back-left", "sprint@bl"], ["sprint back", "sprint@b"],
		["sprint back-right", "sprint@br"], ["sprint right", "sprint@r"],
		["sprint fwd-right", "sprint@fr"]]],
	["CROUCH SET", [
		["crouch idle", "crouch_idle"], ["crouch aim", "crouch_aim"],
		["crouch fwd", "crouch_fwd"], ["crouch fwd-left", "crouch_fwd@fl"],
		["crouch left", "crouch_l"], ["crouch right", "crouch_r"],
		["crouch back", "crouch_back"]]],
	["PRONE - the 7/31 latch", [
		["going down", "to_prone"], ["prone hold", "prone_idle"],
		["prone aim", "prone_aim"], ["prone FIRING", "prone_fire"],
		["getting up", "from_prone"]]],
	["DEATH ARC - every bearing", [
		["shot from FRONT", "death_forward"], ["shot from BACK", "death_back"],
		["shot from LEFT", "death_left"], ["shot from RIGHT", "death_right"],
		["HEADSHOT front", "death_hs_front"], ["HEADSHOT back", "death_hs_back"]]],
	["TURN IN PLACE", [
		["turn left", "turn_l"], ["turn right", "turn_r"], ["idle", "idle"]]],
	["THE REST OF THE FUNNEL", [
		["idle", "idle"], ["aim", "aim"], ["fire", "fire"], ["cover hunker", "cover"],
		["retreat", "retreat"], ["crippled crawl", "crippled"], ["surrender", "surrender"],
		["arrive", "arrive"], ["sneak left", "sneak_l"], ["sneak right", "sneak_r"]]],
]

## Ambient poses have no intent - they are played by name off the role chains. Shown
## as a bank of raw clip names so the camp, the village and the working party can be
## judged without waiting for the right sim hour.
const AMBIENT_BANK: Array = ["AMBIENT / ROLE POSES", [
	["camp guard", "sentry_scan"], ["camp guard b", "crouch_scan"], ["nervous", "nervous_scan"],
	["cook", "kneeling_idle"], ["sleeping", "sleeping_laying"], ["dying/downed", "laying_breathless"],
	["medic treating", "medic_treat_give"], ["patient", "medic_treat_receive"],
	["digging", "digging"], ["filling sandbag", "plant_seeds"],
	["hauling crate", "cargo_carry"], ["unloading", "cargo_unload_stack"],
	["smoking", "smoking"], ["drinking", "sitting_drinking"], ["stretch", "neck_stretch"],
	["talking (US only)", "sitting_talking"], ["arguing (US only)", "standing_arguing"],
	["briefing (US only)", "briefing_group"], ["stumble", "stumble_hit"],
	["planting charge", "plant_charge"]]]


## CREW BANKS. A crew is judged as a crew or not at all: these rows are placed at
## their station offsets and restarted together on one cycle, so the four men hold
## phase for the whole performance instead of being paged one at a time.
##
## The gun_* set was MEASURED in place off anim_library.glb (2026-08-02): 27.30-27.40s
## each, 0.000-0.024m of hip drift. They carry no root motion, so the offsets below are
## the ONLY thing setting the men apart - they are a first read of an M60 pit, not an
## authored layout, and they are the thing to correct once the crew has been seen.
## Format: [caption, clip, station offset]. Cycle is the longest clip in the bank.
const CREW_BANKS: Array = [
	["MG CREW (gun pit) - UNWIRED, judging before wiring", 27.4, [
		["gunner", "gun_gunner", Vector3(0.0, 0.0, 0.0)],
		["loader", "gun_loader", Vector3(1.0, 0.0, -0.4)],
		["a-gunner", "gun_agunner", Vector3(-1.0, 0.0, -0.4)],
		["ammo bearer", "gun_ammo_bearer", Vector3(0.2, 0.0, -1.6)]]],
	["LITTER TEAM", 2.4, [
		["front", "litter_carry_front", Vector3(0.0, 0.0, 0.0)],
		["rear", "litter_carry_rear", Vector3(0.0, 0.0, -1.8)]]],
	["LITTER LOAD", 1.07, [
		["load front", "litter_load_front", Vector3(0.0, 0.0, 0.0)],
		["load rear", "litter_load_rear", Vector3(0.0, 0.0, -1.8)]]],
]


func _ready() -> void:
	_unit_ids = ModelActor.all_units()
	_build_ground()
	_build_camera()
	_wall = Node3D.new()
	_wall.name = "ClipWall"
	add_child(_wall)
	_drivers = Node3D.new()
	_drivers.name = "Drivers"
	add_child(_drivers)
	_read_clips()
	_build_wall()
	_build_bank()
	add_child(ObservationTools.new())
	_hud()


func _read_clips() -> void:
	# Read the clip list off a REAL instanced rig, not off the library file: what the
	# man in the game can play is the only list worth reviewing.
	var probe := ModelActor.new()
	add_child(probe)
	if _unit_ids.is_empty() or not probe.setup(_unit_ids[_unit_i]):
		push_warning("[ANIM REVIEW] no character model resolved - the wall will be empty")
		_clips = PackedStringArray()
	else:
		_clips = probe.clip_names()
	probe.queue_free()
	var sorted: Array[String] = []
	for c in _clips:
		sorted.append(String(c))
	sorted.sort()
	_clips = PackedStringArray(sorted)


func _current_unit() -> String:
	if _unit_ids.is_empty():
		return ""
	return _unit_ids[_unit_i % _unit_ids.size()]


func _build_ground() -> void:
	var mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(120.0, 120.0)
	mesh.mesh = plane
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.22, 0.24, 0.20)
	mesh.material_override = mat
	add_child(mesh)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52.0, -35.0, 0.0)
	sun.light_energy = 1.1
	add_child(sun)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.42, 0.50, 0.58)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.55, 0.58, 0.62)
	e.ambient_light_energy = 0.7
	env.environment = e
	add_child(env)


func _build_camera() -> void:
	_cam = Camera3D.new()
	_cam.fov = 70.0
	_cam.global_position = Vector3(0.0, 4.5, 14.0)
	_cam.current = true
	add_child(_cam)


## ---------------------------------------------------------------- the clip wall

func _page_count() -> int:
	var per: int = WALL_COLS * WALL_ROWS
	return maxi(1, int(ceil(float(_clips.size()) / float(per))))


func _build_wall() -> void:
	for c in _wall.get_children():
		c.queue_free()
	_wall_actors.clear()
	_wall_labels.clear()
	var per: int = WALL_COLS * WALL_ROWS
	var start: int = _page * per
	var unit_id: String = _current_unit()
	for i in range(per):
		var idx: int = start + i
		if idx >= _clips.size():
			break
		var col: int = i % WALL_COLS
		var row: int = i / WALL_COLS
		var pos := Vector3((float(col) - float(WALL_COLS - 1) * 0.5) * WALL_SPACING.x,
			0.0, -6.0 - float(row) * WALL_SPACING.z)
		var holder := Node3D.new()
		holder.position = pos
		_wall.add_child(holder)
		var actor := ModelActor.new()
		holder.add_child(actor)
		if unit_id.is_empty() or not actor.setup(unit_id):
			continue
		actor.play(String(_clips[idx]), true)
		_wall_actors.append(actor)
		var label := _label(String(_clips[idx]), Color(0.95, 0.95, 0.85))
		label.position = Vector3(0.0, 2.15, 0.0)
		holder.add_child(label)
		_wall_labels.append(label)


## ------------------------------------------------------------------ the drivers

func _bank() -> Array:
	if _bank_i > BANKS.size():
		return CREW_BANKS[_bank_i - BANKS.size() - 1]
	if _bank_i == BANKS.size():
		return AMBIENT_BANK
	return BANKS[_bank_i]


func _bank_count() -> int:
	return BANKS.size() + 1 + CREW_BANKS.size()


## Crew banks carry their cycle length in slot 1 and their rows in slot 2; the
## intent and ambient banks carry rows in slot 1.
func _is_crew() -> bool:
	return _bank_i > BANKS.size()


func _bank_rows() -> Array:
	var bank: Array = _bank()
	return bank[2] as Array if _is_crew() else bank[1] as Array


func _build_bank() -> void:
	for c in _drivers.get_children():
		c.queue_free()
	_driver_actors.clear()
	_driver_labels.clear()
	_driver_idx.clear()
	var rows: Array = _bank_rows()
	var unit_id: String = _current_unit()
	# A crew holds its station offsets and restarts on the clip's own cycle, so the
	# men stay in phase for the whole performance. Every other bank keeps the row.
	var crew: bool = _is_crew()
	_step_s = float((_bank() as Array)[1]) if crew else DEFAULT_STEP_S
	for i in range(rows.size()):
		var pos := Vector3((float(i) - float(rows.size() - 1) * 0.5) * DRIVER_SPACING, 0.0, 4.0)
		if crew:
			pos = (rows[i] as Array)[2] as Vector3 + Vector3(0.0, 0.0, 4.0)
		var holder := Node3D.new()
		holder.position = pos
		_drivers.add_child(holder)
		var actor := ModelActor.new()
		holder.add_child(actor)
		if unit_id.is_empty() or not actor.setup(unit_id):
			continue
		_driver_actors.append(actor)
		_driver_idx.append(i)
		var label := _label("", Color(0.75, 0.95, 1.0))
		label.position = Vector3(0.0, 2.15, 0.0)
		holder.add_child(label)
		_driver_labels.append(label)
	_step_t = 0.0
	_apply_bank(true)


## Resolve through the REAL state map, so a wrong MODEL_CLIP row or a missing octant
## shows here rather than in a firefight three days from now.
func _apply_bank(restart: bool) -> void:
	var rows: Array = _bank_rows()
	var ambient: bool = _bank_i >= BANKS.size()
	for n in range(_driver_actors.size()):
		var row: Array = rows[_driver_idx[n] % rows.size()]
		var caption: String = str(row[0])
		var key: String = str(row[1])
		var clip: String = key if ambient else SpriteStateMap.clip_for(true, "m16", key)
		var played: bool = _driver_actors[n].play(clip, restart)
		_driver_labels[n].text = "%s\n%s\n%s" % [caption, clip, "" if played else "*** NOT ON THIS RIG ***"]
		_driver_labels[n].modulate = Color(1.0, 0.45, 0.4) if not played else Color(0.75, 0.95, 1.0)


func _label(text: String, col: Color) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.font_size = 44
	l.pixel_size = 0.005
	l.modulate = col
	l.outline_size = 12
	return l


func _process(delta: float) -> void:
	_fly(delta)
	if _driver_actors.is_empty():
		return
	# Deaths and the two prone transitions are ONE-SHOTS: without a restart they play
	# once and the man stands frozen in a corpse pose for the rest of the session.
	_step_t += delta
	if _step_t >= _step_s:
		_step_t = 0.0
		_apply_bank(true)


func _fly(delta: float) -> void:
	if _cam == null:
		return
	var dir := Vector3.ZERO
	var b: Basis = _cam.global_transform.basis
	if Input.is_key_pressed(KEY_W): dir -= b.z
	if Input.is_key_pressed(KEY_S): dir += b.z
	if Input.is_key_pressed(KEY_A): dir -= b.x
	if Input.is_key_pressed(KEY_D): dir += b.x
	if Input.is_key_pressed(KEY_E): dir += Vector3.UP
	if Input.is_key_pressed(KEY_Q): dir -= Vector3.UP
	if dir.length_squared() > 0.0:
		var boost: float = 4.0 if Input.is_key_pressed(KEY_SHIFT) else 1.0
		_cam.global_position += dir.normalized() * 6.0 * boost * delta


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_RIGHT:
		_looking = (event as InputEventMouseButton).pressed
	elif event is InputEventMouseMotion and _looking and _cam != null:
		var mm := event as InputEventMouseMotion
		_look.x -= mm.relative.x * 0.005
		_look.y = clampf(_look.y - mm.relative.y * 0.005, -1.4, 1.4)
		_cam.rotation = Vector3(_look.y, _look.x, 0.0)
	elif event is InputEventKey and (event as InputEventKey).pressed and not (event as InputEventKey).echo:
		match (event as InputEventKey).keycode:
			KEY_COMMA:
				_page = (_page - 1 + _page_count()) % _page_count()
				_build_wall()
				_hud()
			KEY_PERIOD:
				_page = (_page + 1) % _page_count()
				_build_wall()
				_hud()
			KEY_M:
				if not _unit_ids.is_empty():
					_unit_i = (_unit_i + 1) % _unit_ids.size()
					_read_clips()
					_page = 0
					_build_wall()
					_build_bank()
					_hud()
			KEY_N:
				_bank_i = (_bank_i + 1) % _bank_count()
				_build_bank()
				_hud()
			KEY_B:
				_wall.visible = not _wall.visible
				_drivers.visible = not _drivers.visible
			KEY_R:
				_apply_bank(true)
			KEY_F:
				_step_s = 0.6 if _step_s >= DEFAULT_STEP_S else DEFAULT_STEP_S
				_hud()


func _hud() -> void:
	var unit: String = _unit_ids[_unit_i] if not _unit_ids.is_empty() else "<none>"
	print("[ANIM REVIEW] unit=%s  clips=%d  page %d/%d  bank='%s'  step=%.1fs"
		% [unit, _clips.size(), _page + 1, _page_count(), str(_bank()[0]), _step_s])
	print("  , .  page wall   M model   N bank   B toggle   R restart   F speed")
	print("  WASD/QE fly, Shift boost, right-drag look. ObservationTools: \\ pause  [ ] time  - = sim")
