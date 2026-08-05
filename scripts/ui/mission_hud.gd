## mission_hud.gd - Mission layer HUD: compass strip, objective markers,
## toast queue (NS20). Sits alongside the base combat HUD.
class_name MissionHUD
extends CanvasLayer

const NAMEPLATE := preload("res://scripts/ui/squad_nameplate.gd")

var world: GameWorld
var director: FieldDirector

var _compass: Label
var _toast_box: VBoxContainer
var _marker_box: Control
var _markers: Dictionary = {}  # ally -> Label


var topo_map: TopoMap


func setup(game_world: GameWorld, mission_director: FieldDirector, _plan: Dictionary) -> void:
	world = game_world
	director = mission_director
	director.toast.connect(show_toast)
	director.fire_menu_changed.connect(_on_fire_menu_changed)
	add_to_group("mission_hud")
	_build()
	# W41: topo map (M to toggle).
	topo_map = TopoMap.new()
	add_child(topo_map)
	topo_map.setup(world, director)
	add_child(NAMEPLATE.new())


func _build() -> void:
	_marker_box = Control.new()
	_marker_box.set_anchors_preset(Control.PRESET_FULL_RECT)
	_marker_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_marker_box)

	var compass_panel := ReconUI.make_panel()
	compass_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	compass_panel.position = Vector2(-70, 4)
	compass_panel.custom_minimum_size = Vector2(140, 0)
	add_child(compass_panel)
	_compass = ReconUI.make_label("", 16, ReconUI.AMBER)
	_compass.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	compass_panel.add_child(_compass)

	_toast_box = VBoxContainer.new()
	_toast_box.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_toast_box.position.y = 40.0
	_toast_box.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(_toast_box)


	# PT8: right-side slot slider (appears on wheel/key switch, fades out).
	_slot_slider = VBoxContainer.new()
	_slot_slider.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	_slot_slider.position = Vector2(-190, -70)
	_slot_slider.add_theme_constant_override("separation", 4)
	_slot_slider.modulate.a = 0.0
	add_child(_slot_slider)
	var equip := world.player.get_node_or_null("EquipmentManager") as EquipmentManager
	if equip:
		equip.slot_changed.connect(func(_i: int, _t: Enums.SlotType) -> void: _show_slot_slider())


var squad: SquadSystem = null
var _squad_poll: float = 0.0




## Fire-support menu (T): lists what's on call with budgets.
var _fire_menu: VBoxContainer


var _fire_panel: PanelContainer


func _on_fire_menu_changed(open: bool) -> void:
	if _fire_panel == null:
		_fire_panel = ReconUI.make_panel()
		_fire_panel.set_anchors_preset(Control.PRESET_CENTER_LEFT)
		_fire_panel.position = Vector2(40, -110)
		_fire_menu = VBoxContainer.new()
		_fire_menu.add_theme_constant_override("separation", 4)
		_fire_panel.add_child(_fire_menu)
		add_child(_fire_panel)
	_fire_panel.visible = open
	if not open:
		return
	for c in _fire_menu.get_children():
		c.queue_free()
	_fire_menu.add_child(ReconUI.make_header("ON THE NET - FIRE MISSION", 16))
	var fs: Dictionary = director.fire_support
	var rows := [
		["1", "CAS - SNAKE EYE BOMBS", "bombs"],
		["2", "CAS - NAPALM RUN", "napalm"],
		["3", "ARTILLERY BARRAGE", "arty"],
		["4", "MORTAR FIRE MISSION", "mortar"],
		["5", "SPECTRE GUNSHIP", "spectre"],
		["6", "CAS - CLUSTER (CBU)", "cbu"],
		["7", "ILLUMINATION ROUND", "illum"],
	]
	# Only what is actually on call. A row you can never press is not information.
	var any: bool = false
	for row in rows:
		var count: int = int(fs.get(row[2], 0))
		if count <= 0:
			continue
		any = true
		_fire_menu.add_child(ReconUI.make_label(
			"[%s] %-22s x%d" % [row[0], row[1], count], 14, ReconUI.OLIVE))
	if not any:
		_fire_menu.add_child(ReconUI.make_label("NOTHING ON CALL - BATTALION HAS NOTHING FOR YOU", 14, ReconUI.DIM))
	else:
		_fire_menu.add_child(ReconUI.make_label("PRESS NUMBER TO SIGHT IT - LMB SENDS, RMB BACKS OUT. [T] OFF NET", 11, ReconUI.DIM))
	_fire_placement = ReconUI.make_label("", 15, ReconUI.OLIVE)
	_fire_menu.add_child(_fire_placement)


## The armed call's line: what is sighted, how far out, and whether our own men are
## standing in it. Danger close has to be readable BEFORE the send, not after.
var _fire_placement: Label


func _update_placement_line() -> void:
	if _fire_placement == null or not is_instance_valid(_fire_placement) or director == null:
		return
	if director.armed_kind == "":
		_fire_placement.text = ""
		return
	if director.armed_target == Vector3.ZERO:
		_fire_placement.text = "NO TARGET - AIM AT THE GROUND"
		_fire_placement.add_theme_color_override("font_color", ReconUI.DIM)
		return
	var fp: Dictionary = FirePlan.footprint(director.armed_kind, director.fo_skill())
	var range_m: int = int(world.player.global_position.distance_to(director.armed_target))
	var label: String = String(fp.get("label", director.armed_kind.to_upper()))
	if director.armed_danger_close():
		_fire_placement.text = "%s  %dm  - DANGER CLOSE - MEN IN THE FOOTPRINT" % [label, range_m]
		_fire_placement.add_theme_color_override("font_color", Color(0.95, 0.22, 0.15))
	else:
		_fire_placement.text = "%s  %dm  - LMB TO SEND" % [label, range_m]
		_fire_placement.add_theme_color_override("font_color", ReconUI.OLIVE)


## PT8: slot slider - the kit at a glance, current slot highlighted.
var _slot_slider: VBoxContainer
var _slider_tween: Tween


func _show_slot_slider() -> void:
	if _slot_slider == null or world == null or world.player == null:
		return
	for c in _slot_slider.get_children():
		c.queue_free()
	var equip := world.player.get_node_or_null("EquipmentManager") as EquipmentManager
	var wh := world.player.get_node_or_null("Head/Camera3D/WeaponHolder") as WeaponHolder
	var hs := world.player.get_node_or_null("HealthSystem") as HealthSystem
	if equip == null:
		return
	var target_slot: int = equip.pending_slot if equip.pending_slot >= 0 else equip.current_slot
	var names := [
		"1 %s" % (wh.primary_weapon.display_name if wh and wh.primary_weapon else "RIFLE"),
		"2 %s" % (wh.secondary_weapon.display_name if wh and wh.secondary_weapon else "PISTOL"),
		"3 FRAG x%d" % (equip.grenade_count),
		"4 MEDKIT x%d" % (hs.health_packs if hs else 0),
	]
	# Field items are direct-key, not selectable slots, so they cannot highlight -
	# but he still carries 3 flares, 2 claymores and 2 satchels, and until now the
	# HUD never said so (r4bk: an item with no affordance does not exist).
	var pl := world.player
	names.append("5 FLARE x%d" % int(pl.get("flare_count") if pl.get("flare_count") != null else 0))
	names.append("6 CLAYMORE x%d" % int(pl.get("claymore_count") if pl.get("claymore_count") != null else 0))
	names.append("SATCHEL x%d" % int(pl.get("satchel_count") if pl.get("satchel_count") != null else 0))
	for i in range(names.size()):
		var row := ReconUI.make_label(str(names[i]), 15,
			Color(0.1, 0.1, 0.08) if i == target_slot else Color(0.75, 0.74, 0.66))
		if i == target_slot:
			var bgr := ColorRect.new()
			bgr.color = Color(0.55, 0.58, 0.36)
			bgr.show_behind_parent = true
			bgr.set_anchors_preset(Control.PRESET_FULL_RECT)
			row.add_child(bgr)
		_slot_slider.add_child(row)
	_slot_slider.modulate.a = 1.0
	if _slider_tween:
		_slider_tween.kill()
	_slider_tween = create_tween()
	_slider_tween.tween_interval(1.6)
	_slider_tween.tween_property(_slot_slider, "modulate:a", 0.0, 0.4)


## W66: red wedge on a ring around center pointing at incoming fire.
func show_damage_direction(rel_angle: float) -> void:
	var pip := ReconUI.make_label("▲", 30, Color(0.95, 0.25, 0.15))
	pip.set_anchors_preset(Control.PRESET_CENTER)
	var radius: float = 130.0
	pip.position = Vector2(sin(rel_angle), -cos(rel_angle)) * radius - Vector2(10, 16)
	pip.rotation = rel_angle
	add_child(pip)
	var tween := create_tween()
	tween.tween_interval(0.15)
	tween.tween_property(pip, "modulate:a", 0.0, 0.55)
	tween.tween_callback(pip.queue_free)


var _squad_panel: PanelContainer
var _squad_header: Label
var _squad_rows: VBoxContainer


const STATUS_COLOR := {
	"OK": Color(0.6, 0.82, 0.5),
	"HIT": Color(0.88, 0.75, 0.3),
	"CRIT": Color(0.9, 0.45, 0.25),
	"KIA": Color(0.5, 0.5, 0.5),
}


func _update_squad_strip(delta: float) -> void:
	if squad == null:
		return
	_squad_poll += delta
	if _squad_poll < 0.5:
		return
	_squad_poll = 0.0
	if _squad_panel == null:
		_squad_panel = ReconUI.make_panel()
		_squad_panel.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
		# Two lines per man (name over role) - the panel needs the extra height.
		_squad_panel.position = Vector2(12, -310)
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 3)
		_squad_panel.add_child(col)
		_squad_header = ReconUI.make_label("", 13, ReconUI.AMBER)
		col.add_child(_squad_header)
		_squad_rows = VBoxContainer.new()
		_squad_rows.add_theme_constant_override("separation", 2)
		col.add_child(_squad_rows)
		add_child(_squad_panel)
	var fire_mode := "WEAPONS FREE" if squad.weapons_free else "WEAPONS TIGHT"
	_squad_header.text = "SQUAD // %s" % fire_mode
	for c in _squad_rows.get_children():
		c.queue_free()
	for a in squad.members:
		if not is_instance_valid(a):
			continue
		var m: Dictionary = a.member
		var status := "KIA"
		if not a.is_dead():
			var hp_frac: float = float(a.current_hp) / float(a.max_hp)
			status = "OK" if hp_frac > 0.6 else ("HIT" if hp_frac > 0.25 else "CRIT")
		_squad_rows.add_child(ReconUI.make_label(squad_row(m, status), 12,
			STATUS_COLOR.get(status, ReconUI.OLIVE)))
		_squad_rows.add_child(ReconUI.make_label(squad_role_row(m), 10, ReconUI.DIM))
		var mos := str(m.get("mos", ""))
		if mos == "RTO":
			var rs := _radio_row(a, status == "KIA")
			_squad_rows.add_child(ReconUI.make_label(str(rs[0]), 11, rs[1]))
		elif mos == "POINTMAN" and status != "KIA":
			_squad_rows.add_child(ReconUI.make_label(
				"   scanning %dm" % int(squad.point_scan_radius()), 11, ReconUI.DIM))


## His NAME leads the readout, the role rides under it (Summoner, 2026-07-25).
static func squad_row(m: Dictionary, status: String) -> String:
	var who: String = SquadRoster.last_name(m)
	if who == "":
		who = SquadRoster.call_name(m)
	return "%-12s %s" % [who, status]


static func squad_role_row(m: Dictionary) -> String:
	var role: String = SquadRoster.mos_display(str(m.get("mos", "")))
	var nick: String = SquadRoster.earned_nick(m)
	return "   " + role + (("  \"%s\"" % nick) if nick != "" else "")


## r4bk: the radio is a MAN with a 10m tether (FieldDirector._radio_check). The
## player must see he is off the net BEFORE he presses T, not as a refusal after.
## Range constant is read off the director so the two can never disagree.
static func radio_state(alive: bool, dist_m: float) -> Array:
	if not alive:
		return ["   NO RADIO - RADIO MAN DOWN", ReconUI.ALERT]
	if dist_m <= FieldDirector.RTO_RADIO_RANGE:
		return ["   ON THE NET - [T]", STATUS_COLOR["OK"]]
	return ["   OFF THE NET - RADIO %dm" % int(dist_m), ReconUI.ALERT]


func _radio_row(rto: AllyBase, dead: bool) -> Array:
	if world == null or world.player == null or not is_instance_valid(world.player):
		return radio_state(false, 0.0)
	return radio_state(not dead,
		world.player.global_position.distance_to(rto.global_position))


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
	_update_placement_line()
	# W82: HARDCORE strips navigation aids.
	if GameSettings.hardcore:
		_compass.visible = false
		_marker_box.visible = false
		return
	_compass.visible = true
	_marker_box.visible = true
	var cam: Camera3D = world.player.get_node_or_null("Head/Camera3D")
	if cam == null:
		return
	# Compass: camera yaw -> 8-way heading + degrees.
	var fwd := -cam.global_transform.basis.z
	var heading: float = fposmod(rad_to_deg(atan2(fwd.x, -fwd.z)), 360.0)
	var idx: int = int(roundf(heading / 45.0)) % 8
	_compass.text = "<<  %s  %03d  >>" % [DIRS[idx], int(heading)]

	_update_markers(cam)


## ADR-029: objective/exfil floating markers are DELETED - a tracker in the
## world is a rail. Distant squadmates keep theirs (Pillar 4: never lose your
## team is a squad affordance, not mission tracking).
func _update_markers(cam: Camera3D) -> void:
	var targets: Array = []
	if squad != null:
		for a in squad.members:
			if is_instance_valid(a) and not a.is_dead() \
					and a.global_position.distance_to(world.player.global_position) > 20.0:
				targets.append(a)

	for key in _markers.keys():
		if not targets.has(key):
			(_markers[key] as Label).queue_free()
			_markers.erase(key)

	for t in targets:
		var node := t as Node3D
		if not _markers.has(t):
			var l := ReconUI.make_label(SquadRoster.call_name((t as AllyBase).member),
				13, Color(0.65, 0.7, 0.45))
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
			label.text = "v %s %dm" % [SquadRoster.call_name((t as AllyBase).member), int(dist)]
			label.position = screen - Vector2(label.size.x * 0.5, 0)
