## siren_tower.gd - The firebase alarm. One emitter per watch tower; a man on the
## tower cranks it when the perimeter reports movement, so the siren is a
## CHARACTER acting on what the sim already generates, not the director
## announcing its own roll.
##
## It is deliberately NOT wired to siege_ended. `_break_siege` is only reachable
## from SiegeDirector._physics_process while active, so scene teardown, a
## set_physics_process(false), or a pause strands the signal and a
## signal-terminated siren would wail forever. It runs its own clock instead.
class_name SirenTower
extends Node3D

const LOOP := preload("res://assets/audio/sfx/alarm/siren_alert_loop.wav")
const SPINUP := preload("res://assets/audio/sfx/alarm/siren_spinup.wav")
const SPINDOWN := preload("res://assets/audio/sfx/alarm/siren_spindown.wav")

## Audible across the AO but not deafening at the tower base. max_db is the
## clamp that does the second job - Godot's default +3 lets a listener standing
## inside unit_size boost above unity, and four towers stack.
const UNIT_SIZE: float = 60.0
const MAX_DISTANCE: float = 900.0
const VOLUME_DB: float = -2.0
const MAX_DB: float = 0.0
const AIR_CUTOFF_HZ: float = 2000.0

## Towers sit ~150 m apart and the listener is inside unit_size of all four, so
## identical streams would sum coherently. Detuning breaks the stack.
const DETUNE: Array[float] = [1.0, 0.988, 1.014, 0.997]

const RUN_MIN_S: float = 45.0
const RUN_MAX_S: float = 75.0
const SPINUP_HOLD_S: float = 14.0

var _players: Array[AudioStreamPlayer3D] = []
var _towers: Array[Node3D] = []
var _sounding: bool = false
var _stop_at_ms: int = 0
var _headless: bool = false


## Mirrors Ladder.build_from_markers: called AFTER the GLB root is seated, so
## world positions are read at their final height.
static func build_from_markers(root: Node3D) -> SirenTower:
	if root == null:
		return null
	var found: Array[Node3D] = []
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for c in n.get_children():
			stack.append(c)
		if not (n is Node3D):
			continue
		var nm: String = String(n.name)
		# The tower MESHES are the authority, not the tower_los_point markers:
		# the GLB ships five of those for four towers and two share a position.
		if nm.begins_with("fb_tower_i") and not nm.contains("colonly"):
			found.append(n as Node3D)

	var uniq: Array[Node3D] = []
	for t in found:
		var dup: bool = false
		for u in uniq:
			var a: Vector3 = t.global_position
			var b: Vector3 = u.global_position
			if Vector2(a.x - b.x, a.z - b.z).length() < 4.0:
				dup = true
				break
		if not dup:
			uniq.append(t)
	if uniq.is_empty():
		return null

	var st := SirenTower.new()
	st.name = "SirenTowers"
	root.add_child(st)
	st._install(uniq)
	return st


func _install(towers: Array[Node3D]) -> void:
	_headless = DisplayServer.get_name() == "headless"
	_towers = towers
	if _headless:
		return
	var bus: String = "Alarm"
	if AudioServer.get_bus_index(bus) < 0:
		bus = "SFX" if AudioServer.get_bus_index("SFX") >= 0 else "Master"
	for i in range(_towers.size()):
		var p := AudioStreamPlayer3D.new()
		p.bus = bus
		p.unit_size = UNIT_SIZE
		p.max_distance = MAX_DISTANCE
		p.volume_db = VOLUME_DB
		p.max_db = MAX_DB
		p.attenuation_filter_cutoff_hz = AIR_CUTOFF_HZ
		p.pitch_scale = DETUNE[i % DETUNE.size()]
		p.autoplay = false
		_towers[i].add_child(p)
		p.global_position = _towers[i].global_position + Vector3.UP * 3.2
		_players.append(p)
	set_process(false)


## `run_s <= 0` uses the natural 45-75 s cry.
func sound(run_s: float = 0.0) -> void:
	if _headless or _sounding or _players.is_empty():
		return
	_sounding = true
	var dur: float = run_s if run_s > 0.0 else randf_range(RUN_MIN_S, RUN_MAX_S)
	_stop_at_ms = Time.get_ticks_msec() + int(dur * 1000.0)
	for p in _players:
		if not is_instance_valid(p):
			continue
		p.stream = SPINUP
		p.play()
	await get_tree().create_timer(SPINUP_HOLD_S).timeout
	if not _sounding:
		return
	for p in _players:
		if is_instance_valid(p) and p.get_parent() != null:
			p.stream = LOOP
			p.play()
	set_process(true)


func silence() -> void:
	if not _sounding:
		return
	_sounding = false
	set_process(false)
	for p in _players:
		if is_instance_valid(p) and p.get_parent() != null:
			p.stream = SPINDOWN
			p.play()


func _process(_delta: float) -> void:
	if not _sounding:
		return
	# A tower whose mesh has been destroyed stops crying from its own crater.
	#
	# ASK THE DESTRUCTIBLE, not the mesh. `_do_destroy` never frees the node, so
	# `is_instance_valid` passes forever on a structure that is gone - which is why this used to
	# read a MeshInstance3D's `.visible` and infer death from it. That inference is wrong the
	# moment anything else hides a mesh (a visibility range, an LOD tier, a cull), and it is the
	# guess `Destructible.is_destroyed()` exists to replace.
	for i in range(_players.size()):
		var p: AudioStreamPlayer3D = _players[i]
		if not is_instance_valid(p):
			continue
		var t: Node3D = _towers[i] if i < _towers.size() else null
		if t == null or not is_instance_valid(t) or _structure_gone(t):
			p.stop()


## Whether the structure this siren rides is destroyed. Walks up for the Destructible, because a
## siren is mounted ON a tower rather than being one.
func _structure_gone(t: Node3D) -> bool:
	var n: Node = t
	while n != null:
		var d := n as Destructible
		if d != null:
			return d.is_destroyed()
		n = n.get_parent()
	# No Destructible anywhere above it: this tower cannot be destroyed, so it is never gone.
	return false
	if Time.get_ticks_msec() >= _stop_at_ms:
		silence()


func _exit_tree() -> void:
	_sounding = false
	for p in _players:
		if is_instance_valid(p):
			p.stop()
			p.stream = null
	_players.clear()
