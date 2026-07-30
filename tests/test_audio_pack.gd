## test_audio_pack.gd - verification probe for the 2026-07-27 audio pack swap.
## Guards the three silent failure modes the War Room named:
##   1. A wrong filename resolves to nothing and audio_manager falls back to the
##      class bank without a word (audio_manager.gd:143-149).
##   2. A looping gunshot never frees its pooled voice, so world gunfire dies after
##      24 shots (audio_manager.gd:233-252).
##   3. A stereo source in the 3D voice pool phase-cancels and mislocalises.
## Also asserts radio_manifest.json still agrees with the audio on disk - the
## manifest exists so the radio need not load 96 MB of ogg to walk its timeline,
## and a stale manifest would desynchronise every radio silently.
## Run: godot --headless --path . res://tests/test_audio_pack.tscn
extends Node

const WPATH: String = "res://assets/audio/sfx/weapons/"
const MANIFEST: String = "res://assets/audio/Radio Vietnam/radio_manifest.json"
const BROADCAST_DIR: String = "res://assets/audio/Radio Vietnam"
const MUSIC_DIR: String = "res://assets/audio/Radio Vietnam/music"

## Variant counts are the SHIPPED truth, not an aspiration. mosin/m70/m14 carry one
## near-report because the pack holds exactly one genuine 7.62x54R take (measured:
## all six candidate slices cross-correlate 0.99-1.00). Raising a count here without
## new source audio means somebody cloned a sample.
const REBUILT := {
	"m16a1": 3, "ak47": 3, "rpd": 3, "ppsh41": 3, "m60": 3, "car15": 3, "sks": 3,
	"mosin": 1, "m70": 1, "m14": 1,
}
## Retired by ADR-016 / test_flat_damage.gd. No .tres, no audio.
## car15, thompson and sks came back 2026-07-29 (Summoner) and are off this list.
const RETIRED := ["mp40", "kar98k"]
## Kept on its synth render: .45 ACP is subsonic and the pack has no pistol stock.
## thompson joins m1911 on synth: .45 ACP is subsonic and the pack has no
## pistol/SMG stock, so a derivation would be a downgrade.
const PLACEHOLDER_KEPT := {"m1911": 3, "thompson": 3}
const EXPECT_RATE: int = 48000

var _fail: int = 0


func _ready() -> void:
	_check_rebuilt()
	_check_retired_deleted()
	_check_placeholder_kept()
	_check_manifest_truth()
	_check_sequence_math()
	if _fail == 0:
		print("TEST PASS: audio pack")
	else:
		print("TEST FAIL: audio pack (%d problems)" % _fail)
	get_tree().quit(0 if _fail == 0 else 1)


func _bad(msg: String) -> void:
	_fail += 1
	push_error("audio pack: " + msg)
	print("  FAIL " + msg)


func _wav(path: String) -> AudioStreamWAV:
	if not ResourceLoader.exists(path):
		_bad("missing " + path)
		return null
	var s: AudioStream = load(path) as AudioStream
	if s == null:
		_bad("not an AudioStream: " + path)
		return null
	var w: AudioStreamWAV = s as AudioStreamWAV
	if w == null:
		_bad("not imported as AudioStreamWAV: " + path)
		return null
	if w.loop_mode != AudioStreamWAV.LOOP_DISABLED:
		_bad("loop enabled (voice never frees): " + path)
	if w.stereo:
		_bad("stereo source in 3D voice pool: " + path)
	if w.mix_rate != EXPECT_RATE:
		_bad("mix_rate %d != %d: %s" % [w.mix_rate, EXPECT_RATE, path])
	if w.get_length() <= 0.02:
		_bad("empty/near-empty stream: " + path)
	return w


func _check_rebuilt() -> void:
	for wid: String in REBUILT:
		var want: int = REBUILT[wid]
		for i in range(1, want + 1):
			_wav(WPATH + "fire_%s_%d.wav" % [wid, i])
		# The variant AFTER the shipped count must not exist - a stale synth
		# placeholder sitting beside a real recording would round-robin against it.
		var stale: String = WPATH + "fire_%s_%d.wav" % [wid, want + 1]
		if ResourceLoader.exists(stale):
			_bad("stale extra variant beside real audio: " + stale)
		var dist: AudioStreamWAV = _wav(WPATH + "fire_%s_dist.wav" % wid)
		if dist != null and dist.get_length() < 0.3:
			_bad("distant report too short to read as distance: " + wid)
	print("  checked %d rebuilt weapons" % REBUILT.size())


func _check_retired_deleted() -> void:
	for wid: String in RETIRED:
		for prefix: String in ["fire_%s_1", "fire_%s_dist", "mech_%s", "reload_%s", "bolt_%s"]:
			var path: String = WPATH + (prefix % wid) + ".wav"
			if ResourceLoader.exists(path):
				_bad("fossil audio for retired weapon (ADR-023): " + path)
	print("  checked %d retired weapons purged" % RETIRED.size())


func _check_placeholder_kept() -> void:
	for wid: String in PLACEHOLDER_KEPT:
		for i in range(1, int(PLACEHOLDER_KEPT[wid]) + 1):
			if not ResourceLoader.exists(WPATH + "fire_%s_%d.wav" % [wid, i]):
				_bad("placeholder was removed without a replacement: %s_%d" % [wid, i])


## The manifest is only useful if it is TRUE. Compare every entry against the
## stream Godot actually imported.
func _check_manifest_truth() -> void:
	var fh: FileAccess = FileAccess.open(MANIFEST, FileAccess.READ)
	if fh == null:
		_bad("cannot open " + MANIFEST)
		return
	var parsed: Variant = JSON.parse_string(fh.get_as_text())
	fh.close()
	if not (parsed is Dictionary):
		_bad("manifest is not a JSON object")
		return
	var manifest: Dictionary = parsed as Dictionary
	var checked: int = 0
	var absent: int = 0
	for kind: String in ["broadcast", "music"]:
		var dir: String = BROADCAST_DIR if kind == "broadcast" else MUSIC_DIR
		var entries: Dictionary = manifest.get(kind, {}) as Dictionary
		if entries.is_empty():
			_bad("manifest section empty: " + kind)
			continue
		for name: String in entries:
			var path: String = dir.path_join(name)
			if not ResourceLoader.exists(path):
				# Music is gitignored by licence; absence is legal, drift is not.
				absent += 1
				if kind == "broadcast":
					_bad("broadcast named in manifest is missing: " + path)
				continue
			var s: AudioStream = load(path) as AudioStream
			if s == null:
				_bad("manifest track will not load: " + path)
				continue
			var ogg: AudioStreamOggVorbis = s as AudioStreamOggVorbis
			if ogg != null and ogg.loop:
				_bad("ogg loops - playlist can never advance: " + path)
			if absf(s.get_length() - float(entries[name])) > 1.0:
				_bad("manifest length %.1f != actual %.1f: %s"
					% [float(entries[name]), s.get_length(), path])
			checked += 1
	print("  manifest verified against %d streams (%d absent by licence)" % [checked, absent])


## The radio's timeline is arithmetic; if the group count is wrong the sequence has a
## seam and every radio jumps. Verify the invariant directly.
func _check_sequence_math() -> void:
	var prop: Node = load("res://scripts/props/radio_prop.gd").new()
	if prop == null:
		_bad("radio_prop.gd will not instantiate")
		return
	for pair: Array in [[14, 5, 70], [3, 1, 1], [0, 5, 5], [14, 0, 14]]:
		var got: int = prop.call("_group_count", pair[0], pair[1])
		if got != pair[2]:
			_bad("_group_count(%d,%d) = %d, expected %d" % [pair[0], pair[1], got, pair[2]])
	# Both lists must be consumed a whole number of times, or the loop has a seam.
	var g: int = prop.call("_group_count", 14, 5)
	if (3 * g) % 14 != 0 or g % 5 != 0:
		_bad("group count %d does not consume both playlists evenly" % g)
	prop.free()
	print("  timeline sequence math verified")
