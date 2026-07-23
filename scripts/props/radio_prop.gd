extends Node3D
## Diegetic field radio: plays the "Radio Vietnam" broadcasts as positional 3D audio,
## cycling through every .ogg in the tracks folder. Drop it in the world, it plays.

@export_dir var tracks_dir: String = "res://assets/audio/Radio Vietnam"
@export_file("*.obj", "*.glb") var model_path: String = "res://assets/world/props/radio/radio.obj"
@export var hear_distance: float = 25.0
@export var volume_db: float = -4.0
@export var shuffle: bool = true

var _player: AudioStreamPlayer3D = null
var _tracks: Array[AudioStream] = []
var _cursor: int = 0

func _ready() -> void:
	_build_mesh()
	_load_tracks()
	_build_player()
	_start()

func _build_mesh() -> void:
	var res: Resource = load(model_path)
	if res is Mesh:
		var mi := MeshInstance3D.new()
		mi.mesh = res as Mesh
		add_child(mi)
	elif res is PackedScene:
		add_child((res as PackedScene).instantiate())

func _load_tracks() -> void:
	var dir: DirAccess = DirAccess.open(tracks_dir)
	if dir == null:
		return
	dir.list_dir_begin()
	var fname: String = dir.get_next()
	while fname != "":
		if not dir.current_is_dir() and fname.get_extension().to_lower() == "ogg":
			var stream: Resource = load(tracks_dir.path_join(fname))
			if stream is AudioStream:
				_tracks.append(stream as AudioStream)
		fname = dir.get_next()
	dir.list_dir_end()
	if shuffle:
		_tracks.shuffle()

func _build_player() -> void:
	_player = AudioStreamPlayer3D.new()
	_player.max_distance = hear_distance
	_player.unit_size = 6.0
	_player.volume_db = volume_db
	_player.bus = "SFX" if AudioServer.get_bus_index("SFX") != -1 else "Master"
	add_child(_player)
	_player.finished.connect(_on_finished)

func _start() -> void:
	if _tracks.is_empty():
		push_warning("RadioProp: no .ogg tracks found in %s" % tracks_dir)
		return
	_cursor = 0
	_play_current()

func _play_current() -> void:
	_player.stream = _tracks[_cursor]
	_player.play()

func _on_finished() -> void:
	_cursor = (_cursor + 1) % _tracks.size()
	_play_current()
