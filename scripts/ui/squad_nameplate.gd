## Look-at identification for your own squad. Centre a man within LOOK_RANGE and his
## rank, name and role surface - so you can find the RTO in a firefight.
##
## ALLIES ONLY. Reading an NVA soldier's name off his chest at 5m would hand the player
## free intel and gut the stealth economy (Pillar 3).
class_name SquadNameplate
extends Control

const LOOK_RANGE: float = 5.0
## Half-angle of the cone that counts as "looking directly at him".
const LOOK_CONE_DEG: float = 12.0
## Chest height - aiming at the feet or over the helmet should not identify a man.
const TORSO_OFFSET: float = 1.35
## Clearance above the crown so the tag rides over the helmet. The man's actual
## height comes from the ADR-002 contract per unit - never hardcoded here.
const HEAD_CLEARANCE: float = 0.25
const FADE_SPEED: float = 12.0

var _name_label: Label
var _role_label: Label
var _target: Node3D = null
var _box: VBoxContainer


func _ready() -> void:
	# The tag is positioned per-frame from unproject_position, so this Control is a
	# full-rect canvas to draw into - anchoring it is what pinned it to the corner.
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)
	_box = box

	_name_label = Label.new()
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.add_theme_font_size_override("font_size", 20)
	_name_label.add_theme_color_override("font_color", Color(0.82, 0.88, 0.74))
	_name_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	_name_label.add_theme_constant_override("shadow_offset_y", 2)
	box.add_child(_name_label)

	_role_label = Label.new()
	_role_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_role_label.add_theme_font_size_override("font_size", 14)
	_role_label.add_theme_color_override("font_color", Color(0.62, 0.70, 0.55))
	_role_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	_role_label.add_theme_constant_override("shadow_offset_y", 2)
	box.add_child(_role_label)

	modulate.a = 0.0


func _process(delta: float) -> void:
	_target = _find_looked_at()
	if _target != null:
		var m: Dictionary = (_target as AllyBase).member
		var mos: String = str(m.get("mos", ""))
		_name_label.text = "%s %s" % [SquadRoster.rank_for(m), str(m.get("name", ""))]
		_role_label.text = "%s  \"%s\"" % [mos, str(m.get("nick", ""))]
		# The radioman is the man you must not lose (ADR-011) - he reads hot.
		var hot: bool = mos == "RTO"
		_role_label.add_theme_color_override("font_color",
			Color(0.95, 0.72, 0.35) if hot else Color(0.62, 0.70, 0.55))
		_track(_target)

	var want: float = 1.0 if _target != null and _is_on_screen(_target) else 0.0
	modulate.a = move_toward(modulate.a, want, FADE_SPEED * delta)


## Park the tag over the man's head in screen space. Same projection contract the
## squad markers use: never trust unproject_position for a point behind the eye.
func _track(who: Node3D) -> void:
	var cam: Camera3D = get_viewport().get_camera_3d()
	if cam == null:
		return
	var anchor: Vector3 = head_anchor(who)
	if cam.is_position_behind(anchor):
		return
	var screen: Vector2 = cam.unproject_position(anchor)
	_box.position = screen - Vector2(_box.size.x * 0.5, _box.size.y)


## Crown of the man he was authored to (ADR-002), plus helmet clearance.
static func head_anchor(who: Node3D) -> Vector3:
	var unit_id: String = ""
	var ally := who as AllyBase
	if ally != null:
		unit_id = str(ally.member.get("body", ""))
	return who.global_position \
		+ Vector3.UP * (ModelActor.target_height(unit_id) + HEAD_CLEARANCE)


func _is_on_screen(who: Node3D) -> bool:
	var cam: Camera3D = get_viewport().get_camera_3d()
	if cam == null:
		return false
	return not cam.is_position_behind(head_anchor(who))


func _find_looked_at() -> Node3D:
	var cam: Camera3D = get_viewport().get_camera_3d()
	if cam == null:
		return null
	var eye: Vector3 = cam.global_position
	var fwd: Vector3 = -cam.global_transform.basis.z

	var best: Node3D = null
	var best_ang: float = LOOK_CONE_DEG
	for a in get_tree().get_nodes_in_group("allies"):
		var ally := a as AllyBase
		if ally == null or ally.is_dead():
			continue
		var chest: Vector3 = ally.global_position + Vector3.UP * TORSO_OFFSET
		var to: Vector3 = chest - eye
		var dist: float = to.length()
		if dist > LOOK_RANGE or dist < 0.05:
			continue
		var ang: float = rad_to_deg(fwd.angle_to(to / dist))
		if ang < best_ang and _has_los(eye, chest, ally):
			best_ang = ang
			best = ally
	return best


func _has_los(from: Vector3, to: Vector3, ally: Node3D) -> bool:
	var space: PhysicsDirectSpaceState3D = ally.get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(from, to)
	q.collision_mask = 1  # world geometry only
	var hit: Dictionary = space.intersect_ray(q)
	return hit.is_empty()
