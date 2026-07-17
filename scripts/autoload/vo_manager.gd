## vo_manager.gd - routes bark/toast events to the VO library in assets/audio/vo/.
##
## Casting:
##   radio  -> joe ("joe the radio man voice" folder) - ALL comms traffic
##   squad  -> john (main NPC bark voice) / ryan (rookie alternate, by member hash)
##   medic  -> norman
##   enemy  -> vi_* Vietnamese voices, picked per-enemy so a soldier keeps his voice
##
## Text toasts stay on screen as subtitles - VO is additive, never a replacement.
## Missing wavs no-op silently (the library is user-curated and regenerable).
extends Node

const VO_ROOT := "res://assets/audio/vo"
const RADIO_DIR := "joe the radio man voice"
const SQUAD_DIRS: Array[String] = ["john", "ryan"]
const MEDIC_DIR := "norman"
const ENEMY_DIRS: Array[String] = ["vi_vais1000", "vi_25hours", "vi_vivos"]

## line_id -> seconds until that line may play again (anti-spam; radio also
## refuses to talk over itself entirely).
const LINE_COOLDOWN_S: float = 4.0

var _cache: Dictionary = {}          # path -> AudioStream (or null after a failed load)
var _line_next_ok: Dictionary = {}   # line key -> msec when it may fire again
var _radio: AudioStreamPlayer = null      # in-ear: player holding the handset
var _radio3d: AudioStreamPlayer3D = null  # the PRC-25 on the RTO's back


func _ready() -> void:
	_radio = AudioStreamPlayer.new()
	_radio.bus = "Voice" if AudioServer.get_bus_index("Voice") >= 0 else "Master"
	_radio.volume_db = -2.0
	add_child(_radio)
	_radio3d = AudioStreamPlayer3D.new()
	_radio3d.bus = _radio.bus
	_radio3d.max_distance = 26.0  # a radio speaker, not a voice - audible near the RTO
	_radio3d.unit_size = 4.0
	add_child(_radio3d)


## RTO radio traffic. Diegetic sourcing: the chatter comes FROM the radio -
## positional at the RTO's backpack (`source_pos`) so it fades with distance in a
## firefight. Only when the player is ON THE NET (handset in hand) is it in-ear 2D.
func play_radio(line_id: String, source_pos: Variant = null) -> void:
	if _radio.playing or _radio3d.playing:
		return  # one net, one voice - never talk over an active transmission
	var stream := _load(RADIO_DIR, "radio_%s" % line_id)
	if stream == null or _on_cooldown("radio_" + line_id):
		return
	if MissionDirector.any_fire_menu_open or not (source_pos is Vector3):
		_radio.stream = stream
		_radio.play()
	else:
		_radio3d.global_position = source_pos
		_radio3d.stream = stream
		_radio3d.play()


## Squad field bark, positional at the speaking soldier. `member` picks the voice
## (medic -> norman; others split john/ryan by a stable name hash).
func play_squad(line_id: String, member: Dictionary = {}, pos: Variant = null) -> void:
	var dir := MEDIC_DIR if str(member.get("mos", "")) == "MEDIC" \
		else SQUAD_DIRS[abs(hash(str(member.get("name", "x")))) % SQUAD_DIRS.size()]
	_play_field(dir, "squad_%s" % line_id, pos)


## Enemy Vietnamese callout, positional at the enemy. Voice is stable per speaker.
func play_enemy(line_id: String, speaker: Node3D) -> void:
	if speaker == null or not is_instance_valid(speaker):
		return
	var dir: String = ENEMY_DIRS[abs(speaker.get_instance_id()) % ENEMY_DIRS.size()]
	_play_field(dir, "enemy_%s" % line_id, speaker.global_position)


func _play_field(dir: String, fname: String, pos: Variant) -> void:
	var stream := _load(dir, fname)
	if stream == null or _on_cooldown(dir + "/" + fname):
		return
	if pos is Vector3:
		var p := AudioStreamPlayer3D.new()
		p.stream = stream
		p.max_distance = 45.0
		p.unit_size = 6.0
		p.bus = "Voice" if AudioServer.get_bus_index("Voice") >= 0 else "Master"
		add_child(p)
		p.global_position = pos
		p.play()
		p.finished.connect(p.queue_free)
	else:
		var p2 := AudioStreamPlayer.new()
		p2.stream = stream
		p2.bus = "Voice" if AudioServer.get_bus_index("Voice") >= 0 else "Master"
		add_child(p2)
		p2.play()
		p2.finished.connect(p2.queue_free)


func _on_cooldown(key: String) -> bool:
	var now := Time.get_ticks_msec()
	if int(_line_next_ok.get(key, 0)) > now:
		return true
	_line_next_ok[key] = now + int(LINE_COOLDOWN_S * 1000.0)
	return false


func _load(dir: String, fname: String) -> AudioStream:
	var path := "%s/%s/%s.wav" % [VO_ROOT, dir, fname]
	if _cache.has(path):
		return _cache[path]
	var stream: AudioStream = null
	if ResourceLoader.exists(path):
		stream = load(path) as AudioStream
	_cache[path] = stream  # cache misses too - curated library, don't re-stat disk
	return stream
