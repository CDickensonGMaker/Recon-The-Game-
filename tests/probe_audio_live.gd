## probe_audio_live.gd - proves the audio pack actually PLAYS, not merely that files
## resolve. AudioManager no-ops entirely under the headless display server
## (audio_manager.gd:59,63), so the in-suite probe can only verify streams and
## formats. This one runs with a real driver: it drives a RadioProp through its
## activation gate and pushes weapon reports through AudioManager, then reports what
## the audio server is actually doing.
## Run: godot --path . res://tests/probe_audio_live.tscn
extends Node3D

const RADIO := preload("res://scripts/props/radio_prop.gd")

var _radio: Node3D = null
var _listener: Node3D = null
var _lines: PackedStringArray = PackedStringArray()


func _ready() -> void:
	_listener = Node3D.new()
	add_child(_listener)
	_listener.global_position = Vector3(0, 0, 300)
	if GameManager != null:
		GameManager.player = _listener

	var cam := Camera3D.new()
	_listener.add_child(cam)
	cam.current = true

	_radio = RADIO.new()
	_radio.set("model_path", "")
	add_child(_radio)
	_radio.global_position = Vector3.ZERO

	_run()


func _say(s: String) -> void:
	_lines.append(s)
	print(s)


func _run() -> void:
	await get_tree().create_timer(1.0).timeout
	_say("PROBE driver=%s headless=%s" % [AudioServer.get_driver_name(),
		DisplayServer.get_name() == "headless"])

	var seq: PackedStringArray = _radio.get("_sequence")
	var cycle: float = _radio.get("_cycle_length")
	_say("PROBE radio sequence=%d entries cycle=%.1f h offset=%.1f s"
		% [seq.size(), cycle / 3600.0, float(_radio.get("_offset"))])
	if seq.size() > 0:
		_say("PROBE first four: %s" % [", ".join([
			seq[0].get_file(), seq[1].get_file(), seq[2].get_file(), seq[3].get_file()])])

	# Outside the 125 m gate: no stream may exist.
	await get_tree().create_timer(1.0).timeout
	var p: AudioStreamPlayer3D = _radio.get("_player")
	_say("PROBE dormant@300m active=%s playing=%s stream=%s"
		% [_radio.get("_active"), p.playing, p.stream != null])

	# Step inside the gate.
	_listener.global_position = Vector3(0, 0, 40)
	await get_tree().create_timer(1.5).timeout
	var played: String = p.stream.resource_path.get_file() if p.stream != null else "<none>"
	_say("PROBE inside@40m active=%s playing=%s pos=%.1fs track=%s"
		% [_radio.get("_active"), p.playing, p.get_playback_position(), played])
	if p.playing and p.get_playback_position() > 0.5:
		_say("PROBE seek OK - tuned in mid-track, not from the top")
	elif p.playing:
		_say("PROBE NOTE - started near 0.0s (timeline landed at a track boundary)")
	else:
		_say("PROBE FAIL - inside the gate and silent")

	# Weapon reports through the real AudioManager. It builds no voices under the
	# headless driver (audio_manager.gd:63), so this section needs a real display.
	var fired: int = 0
	var weapons: PackedStringArray = PackedStringArray()
	if DisplayServer.get_name() == "headless":
		_say("PROBE weapons SKIPPED - AudioManager no-ops headless")
	else:
		weapons = PackedStringArray(["m16a1", "ak47", "rpd", "ppsh41", "m60", "mosin", "m70", "m14"])
	for wid: String in weapons:
		var path: String = "res://data/weapons/%s.tres" % wid
		if not ResourceLoader.exists(path):
			_say("PROBE weapon .tres missing: " + wid)
			continue
		var wd: Resource = load(path)
		AudioManager.play_shot_3d(Vector3(0, 0, 38), wd, 0.0)
		AudioManager.play_shot_player(wd)
		await get_tree().create_timer(0.35).timeout
		var voices: Array = AudioManager.get("_voices")
		var live: int = 0
		for v: AudioStreamPlayer3D in voices:
			if v.playing:
				live += 1
		var near: AudioStreamPlayer = AudioManager.get("_p_near")
		var stream_name: String = near.stream.resource_path.get_file() if near.stream != null else "<none>"
		_say("PROBE fire %-7s 3d_voices_live=%d player_slot=%s len=%.3fs"
			% [wid, live, stream_name, near.stream.get_length() if near.stream else 0.0])
		if near.stream != null and near.stream.resource_path.contains(wid):
			fired += 1
	if weapons.size() > 0:
		_say("PROBE weapons resolved to their own render: %d/%d" % [fired, weapons.size()])

	# Leave the gate: the voice must be released, not faded.
	_listener.global_position = Vector3(0, 0, 400)
	await get_tree().create_timer(1.2).timeout
	_say("PROBE left@400m active=%s playing=%s stream_freed=%s"
		% [_radio.get("_active"), p.playing, p.stream == null])

	_say("PROBE DONE")
	get_tree().quit(0)
