## audio_manager.gd - Global weapon/explosion audio: a pooled 3D voice bank, a
## dedicated player-weapon 2D bank, bus routing, an ambience duck, and
## convention-based per-weapon stream resolution.
##
## Streams are resolved BY CONVENTION from a weapon id (see WeaponData.id):
##   res://assets/audio/sfx/weapons/fire_<id>_1..3.wav   (round-robin near report)
##   res://assets/audio/sfx/weapons/fire_<id>_dist.wav   (distant report)
##   res://assets/audio/sfx/weapons/mech_<id>.wav        (action layer, 2D)
##   res://assets/audio/sfx/weapons/reload_<id>.wav
##   res://assets/audio/sfx/weapons/bolt_<id>.wav
## Missing files fall back to a class bank (rifle/smg/pistol) so partial coverage
## never crashes. Drop a real recording at the same path to replace a synth render.
##
## Headless-safe: every play path no-ops under the headless display server, and
## _exit_tree tears every voice down, so the test suite stays silent and fast.
extends Node

const WPATH := "res://assets/audio/sfx/weapons/"
const XPATH := "res://assets/audio/sfx/explosions/"

const GUNSHOT_VOICES: int = 24
const TRANSIENT_LOCK_MS: int = 60          ## a voice this young is never stolen
const DISTANT_BAND_M: float = 85.0
const DISTANT_JITTER_M: float = 6.0
const FAR_SHOOTER_THROTTLE_MS: int = 70    ## same distant shooter firing faster -> drop
const FAR_SHOOTER_DIST_M: float = 60.0

var _headless: bool = false
var _bus_weapons: int = 0
var _bus_tail: int = 0
var _bus_amb: int = 0

# 3D pooled voices (NPCs, world). RefCounted book-keeping alongside each player.
var _voices: Array[AudioStreamPlayer3D] = []
var _voice_started: PackedInt64Array = PackedInt64Array()
var _voice_prio: PackedFloat32Array = PackedFloat32Array()

# Dedicated player-weapon 2D slots - never stolen, always a full transient.
var _p_near: AudioStreamPlayer = null
var _p_tail: AudioStreamPlayer = null
var _p_mech: AudioStreamPlayer = null
var _p_dist: AudioStreamPlayer = null

# Caches. id -> Array[AudioStream] for round-robin; id -> next index.
var _fire_cache: Dictionary = {}
var _single_cache: Dictionary = {}
var _rr: Dictionary = {}
var _last_shot_ms: Dictionary = {}

# Ambience duck.
var _duck_until_ms: int = 0
const DUCK_DB: float = 8.0

# Fallback class banks (used when a weapon has no dedicated render yet).
var _fallback: Dictionary = {}


func _ready() -> void:
	_headless = DisplayServer.get_name() == "headless"
	_bus_weapons = _bus("Weapons", "SFX")
	_bus_tail = _bus("WeaponsTail", "SFX")
	_bus_amb = _bus("Ambience", "Master")
	if _headless:
		return
	_build_voice_pool()
	_build_step_pool()
	_build_player_slots()
	_load_fallbacks()


func _bus(bus_name: String, fallback: String) -> int:
	var idx: int = AudioServer.get_bus_index(bus_name)
	if idx < 0:
		idx = AudioServer.get_bus_index(fallback)
	return maxi(idx, 0)


func _build_voice_pool() -> void:
	for i in range(GUNSHOT_VOICES):
		var p := AudioStreamPlayer3D.new()
		p.bus = AudioServer.get_bus_name(_bus_weapons)
		p.max_distance = 350.0
		p.unit_size = 16.0
		p.attenuation_filter_cutoff_hz = 5000.0  # cheap per-voice air absorption
		add_child(p)
		_voices.append(p)
		_voice_started.append(0)
		_voice_prio.append(0.0)


## ---------- NPC FOOTSTEPS ----------
## Own tiny pool so 60 walking men can never evict a gunshot voice. Steps are
## an ear-tracking tool: the AI already hears the PLAYER through NoiseBus, so
## the player gets the symmetric cue back.
const STEP_DIRT := preload("res://assets/audio/sfx/step_dirt.wav")
const STEP_GRASS := preload("res://assets/audio/sfx/step_grass.wav")
const STEP_WATER := preload("res://assets/audio/sfx/step_water.wav")
const STEP_VOICES: int = 6
const STEP_AUDIBLE_M: float = 28.0
var _step_voices: Array[AudioStreamPlayer3D] = []
var _step_grid: GameplayGrid = null


func _build_step_pool() -> void:
	for i in range(STEP_VOICES):
		var p := AudioStreamPlayer3D.new()
		p.bus = AudioServer.get_bus_name(_bus_weapons)
		p.max_distance = STEP_AUDIBLE_M
		p.unit_size = 3.0
		add_child(p)
		_step_voices.append(p)


func play_step_3d(pos: Vector3, crouched: bool = false) -> void:
	if _headless:
		return
	var cam: Camera3D = get_viewport().get_camera_3d()
	if cam == null:
		return
	var audible: float = STEP_AUDIBLE_M * (0.5 if crouched else 1.0)
	if cam.global_position.distance_to(pos) > audible:
		return
	for p in _step_voices:
		if p.playing:
			continue
		# Surface lookup only for steps that actually play (pool-rate, not NPC-rate).
		if _step_grid == null or not is_instance_valid(_step_grid):
			var gw: Node = get_tree().get_first_node_in_group("game_world")
			_step_grid = gw.get("gameplay_grid") if gw != null else null
		var stream: AudioStream = STEP_DIRT
		if _step_grid != null:
			if _step_grid.is_water(pos):
				stream = STEP_WATER
			else:
				var t: int = _step_grid.get_terrain_type(pos)
				if t == GameplayGrid.TerrainType.GRASSLAND:
					stream = STEP_GRASS
				elif t == GameplayGrid.TerrainType.RICE_PADDY:
					stream = STEP_WATER
		p.stream = stream
		p.volume_db = -18.0 if crouched else -12.0
		p.pitch_scale = randf_range(0.85, 1.15)
		p.global_position = pos
		p.play()
		return


func _build_player_slots() -> void:
	_p_near = _mk2d(_bus_weapons)
	_p_tail = _mk2d(_bus_tail)
	_p_mech = _mk2d(_bus_weapons)
	_p_dist = _mk2d(_bus_weapons)


func _mk2d(bus: int) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = AudioServer.get_bus_name(bus)
	add_child(p)
	return p


func _load_fallbacks() -> void:
	for key in ["rifle", "smg", "pistol"]:
		var s := _try_load("res://assets/audio/sfx/shot_%s.wav" % key)
		if s:
			_fallback[key] = s


func _try_load(path: String) -> AudioStream:
	if not ResourceLoader.exists(path):
		return null
	return load(path) as AudioStream


# --------------------------------------------------------------------------
# stream resolution (by convention, cached)
# --------------------------------------------------------------------------


func _fire_variants(wid: String) -> Array:
	if _fire_cache.has(wid):
		return _fire_cache[wid]
	var arr: Array = []
	for v in [1, 2, 3]:
		var s := _try_load(WPATH + "fire_%s_%d.wav" % [wid, v])
		if s:
			arr.append(s)
	_fire_cache[wid] = arr
	return arr


func _single(wid: String, kind: String) -> AudioStream:
	var key := kind + ":" + wid
	if _single_cache.has(key):
		return _single_cache[key]
	var s := _try_load(WPATH + "%s_%s.wav" % [kind, wid])
	_single_cache[key] = s
	return s


func _fallback_for(wid: String) -> AudioStream:
	var n := wid.to_lower()
	if n.contains("1911") or n.contains("pistol"):
		return _fallback.get("pistol", null)
	if n.contains("ppsh") or n.contains("smg"):
		return _fallback.get("smg", null)
	return _fallback.get("rifle", null)


func _next_fire(wid: String) -> AudioStream:
	var arr := _fire_variants(wid)
	if arr.is_empty():
		return _fallback_for(wid)
	var i: int = int(_rr.get(wid, 0))
	_rr[wid] = (i + 1) % arr.size()
	return arr[i]


# --------------------------------------------------------------------------
# public API (GunFX delegates here; also called directly)
# --------------------------------------------------------------------------


## 3D positional gunshot for NPCs/allies. `data` is a WeaponData (preferred) or
## a String id/path (back-compat). Distance-layered near vs distant report.
func play_shot_3d(pos: Vector3, data: Variant, volume_db: float = 0.0) -> void:
	if _headless:
		return
	var wid := _id_of(data)
	var listener := _listener_pos()
	var d: float = listener.distance_to(pos)

	var wd: WeaponData = data as WeaponData
	var max_d: float = wd.audio_max_distance if wd else 350.0
	if d > max_d:
		return

	# Far-shooter throttle: a distant MG is a texture, not 11 discrete events.
	var owner_key: int = int(pos.x) * 73856093 ^ int(pos.z) * 19349663
	var now := Time.get_ticks_msec()
	if d > FAR_SHOOTER_DIST_M:
		var last: int = int(_last_shot_ms.get(owner_key, 0))
		if now - last < FAR_SHOOTER_THROTTLE_MS:
			return
		_last_shot_ms[owner_key] = now

	var band: float = DISTANT_BAND_M + randf_range(-DISTANT_JITTER_M, DISTANT_JITTER_M)
	var stream: AudioStream
	if d < band:
		stream = _next_fire(wid)
	else:
		stream = _dist_stream(wid)
		if stream == null:
			stream = _next_fire(wid)  # no distant render -> near, air-filtered by voice
	if stream == null:
		stream = _fallback_for(wid)
	if stream == null:
		return

	var vol: float = volume_db + (wd.fire_volume_db if wd else 0.0)
	var pv: float = wd.fire_pitch_variance if wd else 0.04
	_play_voice(pos, stream, vol, pv, d, wd)


func _dist_stream(wid: String) -> AudioStream:
	var key := "fire_dist:" + wid
	if _single_cache.has(key):
		return _single_cache[key]
	var s := _try_load(WPATH + "fire_%s_dist.wav" % wid)
	_single_cache[key] = s
	return s


func _play_voice(pos: Vector3, stream: AudioStream, vol: float, pv: float, d: float, wd: WeaponData) -> void:
	var idx := _acquire_voice(pos, d)
	if idx < 0:
		return
	var p := _voices[idx]
	p.stream = stream
	p.global_position = pos
	p.volume_db = vol
	p.pitch_scale = 1.0 + randf_range(-pv, pv)
	if wd:
		p.max_distance = wd.audio_max_distance
		p.unit_size = wd.audio_unit_size
	_voice_started[idx] = Time.get_ticks_msec()
	_voice_prio[idx] = 1000.0 / (1.0 + d)
	p.play()


func _acquire_voice(_pos: Vector3, d: float) -> int:
	# 1. any idle voice
	for i in range(_voices.size()):
		if not _voices[i].playing:
			return i
	# 2. steal the lowest-priority voice that is NOT transient-locked
	var now := Time.get_ticks_msec()
	var best: int = -1
	var best_prio: float = 1e9
	var mine: float = 1000.0 / (1.0 + d)
	for i in range(_voices.size()):
		if now - _voice_started[i] < TRANSIENT_LOCK_MS:
			continue
		if _voice_prio[i] < best_prio:
			best_prio = _voice_prio[i]
			best = i
	# only steal if the new shot is at least as important
	if best >= 0 and mine >= best_prio:
		return best
	return -1  # drop the shot (silence beats a clipped transient)


## 2D player-weapon shot: always crisp, dedicated slot, never stolen.
func play_shot_player(data: Variant) -> void:
	if _headless or _p_near == null:
		return
	var wid := _id_of(data)
	var wd: WeaponData = data as WeaponData
	var stream := _next_fire(wid)
	if stream == null:
		stream = _fallback_for(wid)
	if stream == null:
		return
	var pv: float = wd.fire_pitch_variance if wd else 0.04
	_p_near.stream = stream
	_p_near.volume_db = -2.0 + (wd.fire_volume_db if wd else 0.0)
	_p_near.pitch_scale = 1.0 + randf_range(-pv, pv)
	_p_near.play()
	# Mechanical action layer, if present.
	var mech := _single(wid, "mech")
	if mech:
		_p_mech.stream = mech
		_p_mech.volume_db = -8.0
		_p_mech.play()
	# Tail/echo layer - the crack's decay is what gives a rifle weight and reads
	# the environment.
	if _p_tail != null:
		var tail: AudioStream = _single(wid, "tail")
		if tail == null:
			tail = stream   # reuse the report, quieter/lower, as a slap-back
		_p_tail.stream = tail
		_p_tail.volume_db = -16.0
		_p_tail.pitch_scale = 0.72
		_p_tail.play()
	duck_ambience()


func play_bolt_player(data: Variant) -> void:
	if _headless or _p_mech == null:
		return
	var s := _single(_id_of(data), "bolt")
	if s:
		_p_mech.stream = s
		_p_mech.volume_db = -4.0
		_p_mech.play()


func play_reload_player(data: Variant) -> void:
	if _headless or _p_mech == null:
		return
	var s := _single(_id_of(data), "reload")
	if s:
		_p_mech.stream = s
		_p_mech.volume_db = -5.0
		_p_mech.play()


## Audio size ladder. GunFX._KIND_SCALE ranks these for the EYES; without the
## same ladder for the ears a satchel charge and a 40mm grenade were the same
## loudness over the same 600 m. Keys: volume_db, max_distance, unit_size, duck_ms.
const _KIND_AUDIO: Dictionary = {
	"explosion_40mm":    {"db": 1.0, "max_d": 340.0, "unit": 16.0, "duck": 180},
	"explosion_grenade": {"db": 4.0, "max_d": 460.0, "unit": 24.0, "duck": 240},
	"explosion_rocket":  {"db": 6.0, "max_d": 620.0, "unit": 32.0, "duck": 300},
	"explosion_mortar":  {"db": 7.0, "max_d": 800.0, "unit": 40.0, "duck": 380},
	"explosion_heavy":   {"db": 9.0, "max_d": 1100.0, "unit": 52.0, "duck": 520},
}


## The tube thump and the whistle. Both are POSITIONAL: the thump belongs at the
## tube hundreds of metres out, the whistle above the impact point, and the gap
## between them is the warning the player gets.
const MORTAR_TUBE := "res://assets/audio/sfx/weapons/mortar_tube.wav"
const SHELL_INCOMING := "res://assets/audio/sfx/weapons/shell_incoming.wav"


func play_mortar_tube(pos: Vector3) -> void:
	_play_oneshot_3d(pos, MORTAR_TUBE, -2.0, 1400.0, 60.0)


## Played at the impact point while the shell is still in the air.
func play_incoming(pos: Vector3) -> void:
	_play_oneshot_3d(pos, SHELL_INCOMING, -4.0, 420.0, 34.0)


## The ballistic crack of an enemy round passing the player - the Fairness Law
## telegraph (bible 03_AI_DETECTION: the crack precedes lethality). Positional
## at the passing point; crack_1..3.wav round-robin.
var _crack_streams: Array = []
var _cracks_loaded: bool = false


func play_crack_3d(pos: Vector3) -> void:
	if _headless:
		return
	if not _cracks_loaded:
		_cracks_loaded = true
		for v in [1, 2, 3]:
			var s := _try_load(WPATH + "crack_%d.wav" % v)
			if s:
				_crack_streams.append(s)
	if _crack_streams.is_empty():
		return
	var i: int = int(_rr.get("crack", 0))
	_rr["crack"] = (i + 1) % _crack_streams.size()
	var idx := _acquire_voice(pos, 0.0)
	if idx < 0:
		return
	var p := _voices[idx]
	p.stream = _crack_streams[i]
	p.global_position = pos
	p.volume_db = -2.0
	p.pitch_scale = randf_range(0.92, 1.08)
	p.max_distance = 60.0
	p.unit_size = 10.0
	_voice_started[idx] = Time.get_ticks_msec()
	_voice_prio[idx] = 5e5
	p.play()


func _play_oneshot_3d(pos: Vector3, path: String, db: float,
		max_d: float, unit: float) -> void:
	if _headless:
		return
	var key := "one:" + path
	var s: AudioStream
	if _single_cache.has(key):
		s = _single_cache[key]
	else:
		s = _try_load(path)
		_single_cache[key] = s
	if s == null:
		return
	if _listener_pos().distance_to(pos) > max_d:
		return
	var idx := _acquire_voice(pos, 0.0)
	if idx < 0:
		return
	var p := _voices[idx]
	p.stream = s
	p.global_position = pos
	p.volume_db = db
	p.pitch_scale = randf_range(0.96, 1.04)
	p.max_distance = max_d
	p.unit_size = unit
	_voice_started[idx] = Time.get_ticks_msec()
	_voice_prio[idx] = 5e5
	p.play()

## Past this the roll is the event, not the bang.
const XPL_DISTANT_M: float = 190.0


func _explosion_variants(kind: String) -> Array:
	if _fire_cache.has(kind):
		return _fire_cache[kind]
	var arr: Array = []
	for v in [1, 2, 3]:
		var s := _try_load(XPATH + "%s_%d.wav" % [kind, v])
		if s:
			arr.append(s)
	if arr.is_empty():
		var flat := _try_load(XPATH + kind + ".wav")
		if flat:
			arr.append(flat)
	_fire_cache[kind] = arr
	return arr


func play_explosion_3d(pos: Vector3, kind: String = "explosion_grenade") -> void:
	if _headless:
		return
	var prof: Dictionary = _KIND_AUDIO.get(kind, _KIND_AUDIO["explosion_grenade"])
	var d: float = _listener_pos().distance_to(pos)
	var max_d: float = float(prof["max_d"])
	if d > max_d:
		return

	var s: AudioStream = null
	if d > XPL_DISTANT_M:
		s = _single_x(kind, "dist")
	if s == null:
		var arr := _explosion_variants(kind)
		if not arr.is_empty():
			var i: int = int(_rr.get(kind, 0))
			_rr[kind] = (i + 1) % arr.size()
			s = arr[i]
	if s == null:
		s = _try_load("res://assets/audio/sfx/explosion.wav")
	if s == null:
		return

	var idx := _acquire_voice(pos, 0.0)  # explosions are top priority
	if idx < 0:
		idx = 0
	var p := _voices[idx]
	p.stream = s
	p.global_position = pos
	p.volume_db = float(prof["db"])
	p.pitch_scale = randf_range(0.95, 1.05)
	p.max_distance = max_d
	p.unit_size = float(prof["unit"])
	_voice_started[idx] = Time.get_ticks_msec()
	_voice_prio[idx] = 1e6
	p.play()
	duck_ambience(int(prof["duck"]))


func _single_x(kind: String, suffix: String) -> AudioStream:
	var key := "x:" + kind + ":" + suffix
	if _single_cache.has(key):
		return _single_cache[key]
	var s := _try_load(XPATH + "%s_%s.wav" % [kind, suffix])
	_single_cache[key] = s
	return s


# --------------------------------------------------------------------------
# ambience duck: the gun doesn't get louder; the world gets quieter.
# --------------------------------------------------------------------------


func duck_ambience(hold_ms: int = 160) -> void:
	if _headless:
		return
	_duck_until_ms = maxi(_duck_until_ms, Time.get_ticks_msec() + hold_ms)
	var base: float = GameSettings.ambience_volume_db if _has_amb_setting() else 0.0
	AudioServer.set_bus_volume_db(_bus_amb, base - DUCK_DB)


func _has_amb_setting() -> bool:
	return GameSettings != null and "ambience_volume_db" in GameSettings


func _process(_delta: float) -> void:
	if _headless or _duck_until_ms == 0:
		return
	if Time.get_ticks_msec() < _duck_until_ms:
		return
	var base: float = GameSettings.ambience_volume_db if _has_amb_setting() else 0.0
	var cur: float = AudioServer.get_bus_volume_db(_bus_amb)
	var next: float = lerpf(cur, base, 1.0 - exp(-2.5 * _delta))
	AudioServer.set_bus_volume_db(_bus_amb, next)
	if absf(next - base) < 0.06:
		AudioServer.set_bus_volume_db(_bus_amb, base)
		_duck_until_ms = 0


# --------------------------------------------------------------------------


func _id_of(data: Variant) -> String:
	if data is WeaponData:
		return (data as WeaponData).id
	var s := str(data)
	if s.ends_with(".tres"):
		return s.get_file().get_basename()
	return s.to_lower()


func _listener_pos() -> Vector3:
	var cam := get_viewport().get_camera_3d()
	return cam.global_position if cam else Vector3.ZERO


func _exit_tree() -> void:
	# Release every voice so nothing outlives teardown.
	for p in _voices:
		if is_instance_valid(p):
			p.stop()
			p.stream = null
	for p in [_p_near, _p_tail, _p_mech, _p_dist]:
		if is_instance_valid(p):
			p.stop()
			p.stream = null
