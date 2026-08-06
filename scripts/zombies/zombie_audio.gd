## zombie_audio.gd - the mode's sound, built entirely from what already ships.
##
## Mode-local, like ZombieEconomy: the campaign must not inherit a round siren.
##
## THE RADIO IS THE BEST ASSET IN THE REPO FOR THIS.
## `assets/audio/Radio Vietnam/` holds five REAL 1969 AFVN broadcasts - the Apollo
## landing, Nixon's inauguration, a baseball report. A cheerful 1969 announcer
## playing out of a radio in a dark Ohio lot while the dead come through the fence
## is free atmosphere and it is unmistakably this project rather than a Treyarch
## tribute.
##
## Only the ENGLISH broadcasts are used. The same folder holds 14 traditional
## Vietnamese music tracks; they are wonderful and they belong to RECON, not to a
## rust-belt parking lot. Setting beats availability.
##
## THE GAP, STATED PLAINLY: there are NO zombie vocals in this repo - no moans, no
## screams, no horde bed, no wet impacts. Mixamo supplies motion and never audio.
## Until roughly a dozen CC0 files exist the horde is SILENT, and that is the
## single largest hole in the mode. Nothing below closes it.
class_name ZombieAudio
extends Node

const SFX := "res://assets/audio/sfx/"
const RADIO_DIR := "res://assets/audio/Radio Vietnam/"

const AMB_INSECTS := SFX + "night_insects_loop.wav"
const AMB_WIND := SFX + "wind_loop.wav"
const SIREN_START := SFX + "alarm/siren_spinup.wav"
const SIREN_CLEAR := SFX + "alarm/siren_allclear.wav"
const SIREN_ALERT := SFX + "alarm/siren_alert_loop.wav"
const BREATH := SFX + "player/breath_hold.wav"

## English-language 1969 broadcasts only - see the header.
const BROADCASTS: Array[String] = [
	"Radio_Vietnam_July_ApolloLanding_W_Ads_1969.ogg",
	"Radio_Vietnam_Nixion_Inaguration_Janurary_1969.ogg",
	"Radio_Vietnam_Light_Rains_and_Baseball_w_Adds.ogg",
	"Radio_Vietnam_Night_Beat_December_REAL_RADIO_edited.ogg",
	"Radio_Vietnam_GOOD_MORNING_long_run.ogg",
]

## From this round on, the alert loop runs under everything and never stops. The
## point at which the map stops being quiet between waves.
const ALERT_FROM_ROUND: int = 10

var _insects: AudioStreamPlayer = null
var _wind: AudioStreamPlayer = null
var _alert: AudioStreamPlayer = null
var _stinger: AudioStreamPlayer = null
var _radio: AudioStreamPlayer3D = null
var _rng := RandomNumberGenerator.new()


func setup(seed_value: int = 20260805) -> void:
	_rng.seed = seed_value
	_insects = _bed(AMB_INSECTS, -14.0)
	_wind = _bed(AMB_WIND, -18.0)
	_alert = _bed(SIREN_ALERT, -12.0)
	if _alert != null:
		_alert.stop()
	_stinger = AudioStreamPlayer.new()
	_stinger.bus = "Ambience" if AudioServer.get_bus_index("Ambience") >= 0 else "Master"
	add_child(_stinger)


## A looping ambience bed. Returns null (quietly) if the file is not on disk -
## a missing ambience must never take the mode down with it.
func _bed(path: String, db: float) -> AudioStreamPlayer:
	if not ResourceLoader.exists(path):
		push_warning("[ZAUDIO] missing %s" % path)
		return null
	var p := AudioStreamPlayer.new()
	p.stream = load(path)
	p.volume_db = db
	p.bus = "Ambience" if AudioServer.get_bus_index("Ambience") >= 0 else "Master"
	# WAVs do not carry a loop flag by default and would play once, leaving the
	# map silent after a few seconds with nothing to indicate why.
	var wav := p.stream as AudioStreamWAV
	if wav != null:
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_end = wav.data.size() / 2
	add_child(p)
	p.play()
	return p


## The practical radio, placed in the world so it attenuates and occludes. Being
## a 3D source is the whole trick - walking away from it is what makes the lot
## feel like a place you are leaving.
func place_radio(host: Node3D, at: Vector3) -> void:
	var pick: String = RADIO_DIR + BROADCASTS[_rng.randi() % BROADCASTS.size()]
	if not ResourceLoader.exists(pick):
		push_warning("[ZAUDIO] missing broadcast %s" % pick)
		return
	_radio = AudioStreamPlayer3D.new()
	_radio.name = "LotRadio"
	_radio.stream = load(pick)
	_radio.volume_db = -6.0
	_radio.unit_size = 6.0
	_radio.max_distance = 34.0
	_radio.bus = "Ambience" if AudioServer.get_bus_index("Ambience") >= 0 else "Master"
	host.add_child(_radio)
	_radio.global_position = at
	_radio.play()


## Cutting the radio is worth more than adding anything. Used when the round turns.
func kill_radio() -> void:
	if _radio != null and is_instance_valid(_radio) and _radio.playing:
		_radio.stop()


func on_round_began(n: int) -> void:
	_sting(SIREN_START)
	if n >= ALERT_FROM_ROUND and _alert != null and not _alert.playing:
		_alert.play()
	# From the alert round on the announcer does not come back. The lot has
	# stopped being somewhere with a radio in it.
	if n >= ALERT_FROM_ROUND:
		kill_radio()


func on_round_cleared(_n: int) -> void:
	_sting(SIREN_CLEAR)


func _sting(path: String) -> void:
	if _stinger == null or not ResourceLoader.exists(path):
		return
	_stinger.stream = load(path)
	_stinger.play()
