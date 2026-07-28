extends Node3D
## Diegetic field radio. Each radio runs a virtual timeline that advances whether the
## player is present or not, so walking up means tuning into something already in
## progress. The playlist emits three songs then one broadcast, repeating.
##
## Two radii, two jobs: `activation_distance` decides whether a stream exists at all,
## `hear_distance` decides how far it carries. The gap between them is deliberate
## headroom so the stream is already running and correctly positioned before it
## becomes audible.

const MANIFEST_PATH: String = "res://assets/audio/Radio Vietnam/radio_manifest.json"
const SONGS_PER_BROADCAST: int = 3
const PROXIMITY_POLL_SEC: float = 0.5

@export_dir var broadcast_dir: String = "res://assets/audio/Radio Vietnam"
@export_dir var music_dir: String = "res://assets/audio/Radio Vietnam/music"
@export_file("*.obj", "*.glb") var model_path: String = "res://assets/world/props/radio/radio.obj"
@export var hear_distance: float = 25.0
@export var activation_distance: float = 125.0
@export var volume_db: float = -4.0

var _player: AudioStreamPlayer3D = null
var _sequence: PackedStringArray = PackedStringArray()
var _starts: PackedFloat64Array = PackedFloat64Array()
var _cycle_length: float = 0.0
var _offset: float = 0.0
var _active: bool = false
var _current: int = -1


func _ready() -> void:
	_build_mesh()
	_build_sequence()
	_build_player()
	if _cycle_length <= 0.0:
		push_warning("RadioProp: no tracks found under %s or %s" % [broadcast_dir, music_dir])
		return
	var timer := Timer.new()
	timer.wait_time = PROXIMITY_POLL_SEC
	timer.timeout.connect(_poll_proximity)
	add_child(timer)
	timer.start(randf_range(0.05, PROXIMITY_POLL_SEC))


func _build_mesh() -> void:
	if model_path.is_empty() or not ResourceLoader.exists(model_path):
		return
	var res: Resource = load(model_path)
	if res is Mesh:
		var mi := MeshInstance3D.new()
		mi.mesh = res as Mesh
		add_child(mi)
	elif res is PackedScene:
		add_child((res as PackedScene).instantiate())


func _build_player() -> void:
	_player = AudioStreamPlayer3D.new()
	_player.max_distance = hear_distance
	_player.unit_size = 6.0
	_player.volume_db = volume_db
	_player.bus = "SFX" if AudioServer.get_bus_index("SFX") != -1 else "Master"
	add_child(_player)
	_player.finished.connect(_on_finished)


## Deterministic per-radio playlist. The seed is the radio's own position, so the
## order survives a reload and two radios in earshot never play in unison.
func _build_sequence() -> void:
	var manifest: Dictionary = _read_manifest()
	if manifest.is_empty():
		return
	var music: Array[String] = _tracks(music_dir, manifest.get("music", {}) as Dictionary)
	var casts: Array[String] = _tracks(broadcast_dir, manifest.get("broadcast", {}) as Dictionary)
	if music.is_empty() and casts.is_empty():
		return

	var rng := RandomNumberGenerator.new()
	rng.seed = _position_seed()
	_shuffle(music, rng)
	_shuffle(casts, rng)

	var lengths: Dictionary = {}
	for kind: String in ["music", "broadcast"]:
		for track: String in (manifest.get(kind, {}) as Dictionary):
			var dir: String = music_dir if kind == "music" else broadcast_dir
			lengths[dir.path_join(track)] = float((manifest[kind] as Dictionary)[track])

	var groups: int = _group_count(music.size(), casts.size())
	var mi: int = 0
	var bi: int = 0
	var clock: float = 0.0
	for g in range(groups):
		if not music.is_empty():
			for s in range(SONGS_PER_BROADCAST):
				var path: String = music[mi % music.size()]
				mi += 1
				_sequence.append(path)
				_starts.append(clock)
				clock += float(lengths.get(path, 0.0))
		if not casts.is_empty():
			var cast_path: String = casts[bi % casts.size()]
			bi += 1
			_sequence.append(cast_path)
			_starts.append(clock)
			clock += float(lengths.get(cast_path, 0.0))
	_cycle_length = clock
	if _cycle_length > 0.0:
		_offset = fposmod(float(_position_seed() % 100000) * 0.7654321, _cycle_length)


## Smallest whole number of song+broadcast groups that consumes both lists evenly, so
## the sequence loops without a seam.
func _group_count(music_count: int, cast_count: int) -> int:
	if music_count == 0 or cast_count == 0:
		return maxi(music_count, cast_count)
	var g: int = 1
	while g < 10000:
		if (SONGS_PER_BROADCAST * g) % music_count == 0 and g % cast_count == 0:
			return g
		g += 1
	return cast_count


func _read_manifest() -> Dictionary:
	if not ResourceLoader.exists(MANIFEST_PATH) and not FileAccess.file_exists(MANIFEST_PATH):
		return {}
	var fh: FileAccess = FileAccess.open(MANIFEST_PATH, FileAccess.READ)
	if fh == null:
		return {}
	var parsed: Variant = JSON.parse_string(fh.get_as_text())
	fh.close()
	return parsed as Dictionary if parsed is Dictionary else {}


## Manifest entries whose audio is actually present. Music is gitignored (commercial
## recording, public repo), so a fresh clone legitimately has broadcasts only.
func _tracks(dir: String, entries: Dictionary) -> Array[String]:
	var found: Array[String] = []
	var missing: int = 0
	for track: String in entries:
		var path: String = dir.path_join(track)
		if ResourceLoader.exists(path):
			found.append(path)
		else:
			missing += 1
	if missing > 0:
		push_warning("RadioProp: %d of %d tracks in %s are absent (untracked assets?)"
			% [missing, entries.size(), dir])
	found.sort()
	return found


func _shuffle(items: Array[String], rng: RandomNumberGenerator) -> void:
	for i in range(items.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var tmp: String = items[i]
		items[i] = items[j]
		items[j] = tmp


func _position_seed() -> int:
	var p: Vector3 = global_position
	return abs(hash(Vector3i(roundi(p.x), roundi(p.y), roundi(p.z))))


func _poll_proximity() -> void:
	var listener: Node3D = _listener()
	if listener == null:
		return
	var near: bool = global_position.distance_to(listener.global_position) <= activation_distance
	if near and not _active:
		_activate()
	elif not near and _active:
		_deactivate()


func _listener() -> Node3D:
	var p: Node = GameManager.player if GameManager != null else null
	if p is Node3D:
		return p as Node3D
	return get_viewport().get_camera_3d()


func _activate() -> void:
	_active = true
	_tune()


func _deactivate() -> void:
	_active = false
	_current = -1
	_player.stop()
	_player.stream = null


## Where the timeline is now, seeked into mid-track.
func _tune() -> void:
	if _cycle_length <= 0.0:
		return
	var now: float = fposmod(_offset + Time.get_ticks_msec() / 1000.0, _cycle_length)
	var idx: int = _index_at(now)
	if idx < 0:
		return
	var into: float = now - float(_starts[idx])
	if idx != _current:
		var stream: AudioStream = load(_sequence[idx]) as AudioStream
		if stream == null:
			return
		_player.stream = stream
		_current = idx
	_player.play(maxf(into, 0.0))


func _index_at(t: float) -> int:
	var lo: int = 0
	var hi: int = _starts.size() - 1
	while lo < hi:
		var mid: int = (lo + hi + 1) >> 1
		if float(_starts[mid]) <= t:
			lo = mid
		else:
			hi = mid - 1
	return lo


func _on_finished() -> void:
	if _active:
		_tune()
