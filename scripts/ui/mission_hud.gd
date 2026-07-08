## mission_hud.gd - Mission layer HUD: compass strip, objective markers,
## toast queue (NS20). Sits alongside the base combat HUD.
class_name MissionHUD
extends CanvasLayer

var world: GameWorld
var director: MissionDirector
var sensors: Array = []
var exfil_zone: ExfilZone

var _compass: Label
var _toast_box: VBoxContainer
var _marker_box: Control
var _markers: Dictionary = {}  # sensor -> Label


var topo_map: TopoMap


func setup(game_world: GameWorld, mission_director: MissionDirector, sensor_list: Array, exfil: ExfilZone, _plan: Dictionary) -> void:
	world = game_world
	director = mission_director
	sensors = sensor_list
	exfil_zone = exfil
	director.toast.connect(show_toast)
	add_to_group("mission_hud")
	_build()
	# W41: topo map (M to toggle).
	topo_map = TopoMap.new()
	add_child(topo_map)
	topo_map.setup(world, director, sensors, exfil)


func _build() -> void:
	_marker_box = Control.new()
	_marker_box.set_anchors_preset(Control.PRESET_FULL_RECT)
	_marker_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_marker_box)

	_compass = ReconUI.make_label("", 16, ReconUI.AMBER)
	_compass.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_compass.position.y = 8.0
	_compass.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_compass)

	_toast_box = VBoxContainer.new()
	_toast_box.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_toast_box.position.y = 40.0
	_toast_box.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(_toast_box)

	_prompt = ReconUI.make_label("", 20, Color(0.95, 0.9, 0.6))
	_prompt.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_prompt.position.y = -120.0
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_prompt)


var _prompt: Label
var squad: SquadSystem = null
var _squad_strip: Label
var _squad_poll: float = 0.0


func set_prompt(text: String) -> void:
	if _prompt:
		_prompt.text = text


func _update_squad_strip(delta: float) -> void:
	if squad == null:
		return
	_squad_poll += delta
	if _squad_poll < 0.5:
		return
	_squad_poll = 0.0
	if _squad_strip == null:
		_squad_strip = ReconUI.make_label("", 13, ReconUI.OLIVE)
		_squad_strip.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
		_squad_strip.position = Vector2(12, -160)
		add_child(_squad_strip)
	var lines: Array[String] = []
	for a in squad.members:
		if not is_instance_valid(a):
			continue
		var m: Dictionary = a.member
		var status := "KIA"
		if not a.is_dead():
			var hp_frac: float = float(a.current_hp) / float(a.max_hp)
			status = "OK" if hp_frac > 0.6 else ("HIT" if hp_frac > 0.25 else "CRIT")
		lines.append("%s %s [%s]" % [str(m.get("nick", "?")), str(m.get("mos", "")), status])
	var fire_mode := "FREE" if squad.weapons_free else "TIGHT"
	_squad_strip.text = "SQUAD (%s)\n%s" % [fire_mode, "\n".join(lines)]


func show_toast(text: String) -> void:
	var l := ReconUI.make_label(text, 17, Color(0.95, 0.85, 0.5))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast_box.add_child(l)
	var tween := create_tween()
	tween.tween_interval(3.5)
	tween.tween_property(l, "modulate:a", 0.0, 1.0)
	tween.tween_callback(l.queue_free)


const DIRS: Array[String] = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]


func _process(_delta: float) -> void:
	if world == null or world.player == null:
		return
	_update_squad_strip(_delta)
	var cam: Camera3D = world.player.get_node_or_null("Head/Camera3D")
	if cam == null:
		return
	# Compass: camera yaw -> 8-way heading + degrees.
	var fwd := -cam.global_transform.basis.z
	var heading: float = fposmod(rad_to_deg(atan2(fwd.x, -fwd.z)), 360.0)
	var idx: int = int(roundf(heading / 45.0)) % 8
	_compass.text = "<<  %s  %03d  >>" % [DIRS[idx], int(heading)]

	_update_markers(cam)


func _update_markers(cam: Camera3D) -> void:
	var targets: Array = []
	for s in sensors:
		if s is ObjectiveSensor and is_instance_valid(s) and not (s as ObjectiveSensor).is_complete():
			targets.append(s)
	if exfil_zone != null and is_instance_valid(exfil_zone) and director.state.is_exfil_unlocked():
		targets.append(exfil_zone)

	# Prune dead markers.
	for key in _markers.keys():
		if not targets.has(key):
			(_markers[key] as Label).queue_free()
			_markers.erase(key)

	for t in targets:
		var node := t as Node3D
		if not _markers.has(t):
			var title := "EXFIL"
			if t is ObjectiveSensor:
				title = (t as ObjectiveSensor).title
			var l := ReconUI.make_label(title, 13, Color(0.5, 0.9, 0.5))
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			_marker_box.add_child(l)
			_markers[t] = l
		var label := _markers[t] as Label
		var pos: Vector3 = node.global_position + Vector3(0, 3, 0)
		var behind: bool = cam.is_position_behind(pos)
		label.visible = not behind
		if not behind:
			var screen: Vector2 = cam.unproject_position(pos)
			var dist: float = world.player.global_position.distance_to(node.global_position)
			var title2 := "EXFIL" if t is ExfilZone else (t as ObjectiveSensor).title
			label.text = "v %s %dm" % [title2, int(dist)]
			label.position = screen - Vector2(label.size.x * 0.5, 0)
