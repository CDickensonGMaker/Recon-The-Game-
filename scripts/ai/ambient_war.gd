## ambient_war.gd - distant war audio/visual events that play in the background
## regardless of the player. On each SimClock.hour_advanced, roll 1-3 events for
## the hour. Each: position 200-800m from the player, positional audio; the
## explosion-type kinds add a FAKE emissive fireball + smoke column (GunFX, no
## real light - ADR-026). Audio lifetime 5-30 seconds; the flash self-expires.
class_name AmbientWar
extends Node

## A fired event: {kind, position, lifetime_s, born_ms, shooters, thump, ...}
var _active: Array = []
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
const KINDS: Array = ["artillery", "mortar", "tracers", "burning", "gunship_attack"]

## ---- THE DISTANT FIREFIGHT ----
## A firefight is two parties ANSWERING each other, and that exchange is the whole
## atmosphere. Every source retriggers its own one-shot on a burst clock: a handful of
## rounds inside a second, then silence long enough to wonder, then the other side
## replies from a slightly different bearing.
const FIRE_CAP: int = 2                      ## engagements allowed to be shooting at once
const PARTY_SPREAD_M: float = 40.0           ## how far the two sides sit apart
const BURST_MIN: int = 3
const BURST_MAX: int = 8
const MG_BURST_MIN: int = 6
const MG_BURST_MAX: int = 14
const SHOT_GAP_S: float = 0.11               ## inside a burst
const MG_SHOT_GAP_S: float = 0.075
const LULL_MIN_S: float = 2.0
const LULL_MAX_S: float = 6.0
## Past 400m a rifle has no crack left, only a dull slap off the treeline.
const DIST_CUTOFF_HZ: float = 900.0
const THUMP_MIN_S: float = 10.0
const THUMP_MAX_S: float = 20.0
## The last quarter of an engagement goes ragged rather than stopping mid-burst.
const RAGGED_FRAC: float = 0.75

const WPATH: String = "res://assets/audio/sfx/weapons/"
## The 7/27 pack ships a measured distant report per weapon; this used one generic
## shot_distant.wav for every gun in the war.
const VC_VOICES: Array[String] = ["ak47", "sks", "mosin", "ppsh41"]
const US_VOICES: Array[String] = ["m16a1", "m14", "car15"]
const MG_VOICES: Array[String] = ["rpd", "m60"]


func _ready() -> void:
	if SimClock != null:
		var cb := Callable(self, "_on_hour")
		if not SimClock.hour_advanced.is_connected(cb):
			SimClock.hour_advanced.connect(cb)


func _on_hour(_sim_hour: int) -> void:
	_roll_events()


func _roll_events() -> void:
	# 1-3 events per hour. The player position is queried lazily; if no player
	# exists (e.g. unit tests), we use the origin.
	var player := GameManager.player as Node3D
	var center: Vector3 = Vector3.ZERO
	if player != null:
		center = player.global_position
	var n: int = rng.randi_range(1, 3)
	for i in range(n):
		var kind: String = KINDS[rng.randi() % KINDS.size()]
		var bearing: float = rng.randf_range(0.0, TAU)
		# 400m floor: at 200m the theater reads as a REAL engagement with no
		# enemy (playtest 07-29: a gunship visibly strafing nothing). Distant
		# war is a horizon, not a neighbor.
		var dist: float = rng.randf_range(400.0, 800.0)
		var pos: Vector3 = center + Vector3(cos(bearing), 0.0, sin(bearing)) * dist
		# A firefight needs long enough to have a RHYTHM. At 5 s it can only be one burst,
		# which is the shape that read as "one distant pop and nothing".
		var life_s: float = rng.randf_range(14.0, 40.0)
		var firing: bool = _firing_count() < FIRE_CAP
		var e: Dictionary = {
			"kind": kind,
			"position": pos,
			"lifetime_s": life_s,
			"born_ms": Time.get_ticks_msec(),
			"firing": firing,
			"shooters": _build_shooters(kind, pos) if firing else [],
			"thump": _make_source(_thump_stream(kind), pos) if firing else null,
			"next_thump_s": rng.randf_range(THUMP_MIN_S, THUMP_MAX_S),
		}
		_active.append(e)
		if not firing:
			# A silent engagement is still an event (the flash, the hush duck), but it is
			# NOT the war being heard. Say so rather than letting the cap read as coverage.
			print("[AmbientWar] %s at %.0fm held silent - %d firefights already sounding"
				% [kind, dist, FIRE_CAP])
		_spawn_visual(kind, pos)


func _firing_count() -> int:
	var n: int = 0
	for e in _active:
		if bool((e as Dictionary).get("firing", false)):
			n += 1
	return n


## One positioned voice. Retriggered on a burst clock rather than played once - the old
## version called play() a single time per event, and the 5-30 s "lifetime" only decided
## when the finished node was freed. A whole distant engagement was ONE gunshot.
func _make_source(stream: AudioStream, pos: Vector3) -> AudioStreamPlayer3D:
	if stream == null:
		return null
	var src := AudioStreamPlayer3D.new()
	src.stream = stream
	src.unit_size = 220.0
	src.max_distance = 1200.0
	src.volume_db = -8.0
	# Past 400 m a rifle has no crack left. The low-pass is what turns a shot into the
	# flat slap off a treeline that you feel before you place it.
	src.attenuation_filter_cutoff_hz = DIST_CUTOFF_HZ
	add_child(src)
	src.global_position = pos
	return src


func _dist_voice(wid: String) -> AudioStream:
	return load(WPATH + "fire_%s_dist.wav" % wid) as AudioStream


func _thump_stream(kind: String) -> AudioStream:
	var name: String = "explosion_mortar_dist" if kind == "mortar" else "explosion_heavy_dist"
	var s := load("res://assets/audio/sfx/explosions/%s.wav" % name) as AudioStream
	return s if s != null else load("res://assets/audio/sfx/explosion.wav") as AudioStream


## Two parties, 15-40 m apart, one on each side of the war. The exchange IS the atmosphere:
## a single source firing alone reads as a man shooting at nothing.
func _build_shooters(kind: String, pos: Vector3) -> Array:
	var out: Array = []
	var a: float = rng.randf_range(0.0, TAU)
	var gap: float = rng.randf_range(15.0, PARTY_SPREAD_M)
	var sides: Array = [
		{"pool": VC_VOICES, "at": pos},
		{"pool": US_VOICES, "at": pos + Vector3(cos(a), 0.0, sin(a)) * gap},
	]
	for s in sides:
		var side: Dictionary = s
		var pool: Array[String] = side["pool"]
		# A gunship pass is one side pouring fire, not a duel - give it the MG voice.
		var mg: bool = kind == "gunship_attack" or rng.randf() < 0.3
		var wid: String = MG_VOICES[rng.randi() % MG_VOICES.size()] if mg \
			else pool[rng.randi() % pool.size()]
		var src: AudioStreamPlayer3D = _make_source(_dist_voice(wid), side["at"])
		if src == null:
			continue
		out.append({
			"src": src,
			"mg": mg,
			"rounds": 0,
			"next_s": rng.randf_range(0.0, 1.5),   # the two sides do not open together
		})
	return out


## Advance one party's burst clock. A burst is a handful of rounds inside a second, then a
## lull long enough that the next one makes you look up.
func _tick_shooter(sh: Dictionary, step: float, ragged: bool) -> void:
	var src := sh["src"] as AudioStreamPlayer3D
	if src == null or not is_instance_valid(src):
		return
	sh["next_s"] = float(sh["next_s"]) - step
	if float(sh["next_s"]) > 0.0:
		return
	var mg: bool = bool(sh["mg"])
	if int(sh["rounds"]) <= 0:
		var lo: int = MG_BURST_MIN if mg else BURST_MIN
		var hi: int = MG_BURST_MAX if mg else BURST_MAX
		if ragged:
			hi = maxi(lo, hi / 2)
		sh["rounds"] = rng.randi_range(lo, hi)
	src.pitch_scale = rng.randf_range(0.94, 1.06)
	src.play()
	sh["rounds"] = int(sh["rounds"]) - 1
	if int(sh["rounds"]) > 0:
		sh["next_s"] = MG_SHOT_GAP_S if mg else SHOT_GAP_S
	else:
		var lull: float = rng.randf_range(LULL_MIN_S, LULL_MAX_S)
		sh["next_s"] = lull * (1.6 if ragged else 1.0)


## Distant war gets a horizon flash: reuse the shared explosion visual (fake
## emissive fireball + smoke, self-expiring) enlarged so it reads at 200-800m.
## Shares GunFX's MAX_EXPLOSIONS budget - tolerable: 1-3 rolls per sim-hour, each
## flash frees in a few seconds. tracers stay audio-only (no distant streak VFX).
func _spawn_visual(kind: String, pos: Vector3) -> void:
	if kind == "tracers":
		return
	GunFX._spawn_explosion_visual(self, pos, 12.0, 2.5)


## Drive every live firefight, then expire the finished ones. The roster only ever grew
## before, and every entry it held was a live audio source.
func _process(delta: float) -> void:
	var now: int = Time.get_ticks_msec()
	for i in range(_active.size() - 1, -1, -1):
		var e: Dictionary = _active[i]
		var life: float = float(e.get("lifetime_s", 0.0))
		var age_s: float = float(now - int(e.get("born_ms", now))) / 1000.0
		if age_s < life:
			if bool(e.get("firing", false)):
				_tick_engagement(e, delta, age_s > life * RAGGED_FRAC)
			continue
		_free_sources(e)
		_active.remove_at(i)


## `ragged` in the last quarter: bursts shorten and lulls stretch, so a firefight peters
## out the way one does instead of being cut off mid-magazine.
func _tick_engagement(e: Dictionary, step: float, ragged: bool) -> void:
	for s in (e.get("shooters", []) as Array):
		_tick_shooter(s as Dictionary, step, ragged)
	var thump := e.get("thump") as AudioStreamPlayer3D
	if thump == null or not is_instance_valid(thump):
		return
	e["next_thump_s"] = float(e.get("next_thump_s", 0.0)) - step
	if float(e["next_thump_s"]) > 0.0:
		return
	e["next_thump_s"] = rng.randf_range(THUMP_MIN_S, THUMP_MAX_S)
	thump.pitch_scale = rng.randf_range(0.92, 1.05)
	thump.play()


func _free_sources(e: Dictionary) -> void:
	for s in (e.get("shooters", []) as Array):
		var src := (s as Dictionary).get("src") as AudioStreamPlayer3D
		if src != null and is_instance_valid(src):
			src.queue_free()
	var thump := e.get("thump") as AudioStreamPlayer3D
	if thump != null and is_instance_valid(thump):
		thump.queue_free()


func get_active() -> Array:
	return _active
