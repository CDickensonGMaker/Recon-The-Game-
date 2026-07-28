# Lead Programmer / Godot Specialist — Audio Pack Integration

**Lens:** correctness and the SILENT failure modes. Every claim below cites `file:line` or a command.
Read: `scripts/props/radio_prop.gd`, `scripts/autoload/audio_manager.gd`, the live `.import` sidecars,
`scripts/world/site_planner.gd`, `assets/audio/default_bus_layout.tres`, `.gitignore`.

---

## 1. Import files — the exact contract, and what lies

### 1a. The WAV contract (measured, not assumed)

`assets/audio/sfx/weapons/fire_ak47_1.wav.import` — verbatim `[params]` (`:13-24`):

```
force/8_bit=false
force/mono=true
force/max_rate=false
force/max_rate_hz=44100
edit/trim=false
edit/normalize=false
edit/loop_mode=0
edit/loop_begin=0
edit/loop_end=-1
compress/mode=0
```

Header: `importer="wav"`, `type="AudioStreamWAV"`, `uid="uid://3bkjrvbn5oi2"` (`:3-5`).
**Every new weapon `.wav` must land on exactly this param block.** The three load-bearing values:

- **`edit/loop_mode=0` (loop OFF).** This is the one that can kill the game. `AudioManager`'s voice
  pool acquires only voices where `not _voices[i].playing` (`audio_manager.gd:235-237`). A gunshot
  imported with `loop_mode=1` never stops, never frees its voice, and after 24 shots
  (`GUNSHOT_VOICES: int = 24`, `:21`) **all world gunfire goes permanently silent.** No error, no
  warning, no crash. This is a single integer in a sidecar file nobody reviews.
- **`force/mono=true`.** The pack is 2ch (briefing "measured ground truth"). It gets collapsed.
  You **cannot** keep a stereo player-report: `_next_fire()` (`:152-158`) feeds the SAME stream to
  both `play_shot_3d` → `AudioStreamPlayer3D` (`:192`, `:216-230`) and `play_shot_player` →
  2D `AudioStreamPlayer` (`:261-270`). One file, one import, one channel count. A stereo stream in
  an `AudioStreamPlayer3D` is downmixed anyway. **Keep mono. Do not "improve" this.**
- **`compress/mode=0`** = PCM, no decode latency. Correct for short one-shots; leave it.
  (`1` = IMA-ADPCM, `2` = QOA in 4.3+ — both add decode cost per transient for no gain at this size.)

**Git status: the `.import` files ARE tracked.** `git check-ignore` on
`assets/audio/sfx/weapons/fire_ak47_1.wav.import` returns rc=1 (not ignored), and `git ls-files`
lists both the `.wav` and the `.wav.import`. `.godot/` is ignored (`.gitignore:2`), so the sidecar is
tracked and the *imported binary* is not. That split is the whole reason `--headless --import` is a
required step for anyone but the machine that did the import.

### 1b. What happens when a `.wav` lands with no `.import`

`audio_manager.gd:111-114`:

```gdscript
func _try_load(path: String) -> AudioStream:
	if not ResourceLoader.exists(path):
		return null
	return load(path) as AudioStream
```

Do **not** treat `ResourceLoader.exists()` as proof of loadability. It resolves through the import
remap and asks the registered format loaders whether they recognise the path; for an un-imported
`.wav` there is no remap and no runtime loader bound to the raw extension. It can return `false` for
a file that is plainly sitting on disk, and in the editor the answer flips as soon as a scan
regenerates the sidecar. **Whether it returns true or false does not matter to the outcome**, because
both branches produce the same thing: `null`.

And `null` is swallowed. `_fire_variants()` (`:122-131`) appends only non-null streams and caches the
(possibly empty) array. `_next_fire()` (`:152-158`) sees `arr.is_empty()` and returns
`_fallback_for(wid)` (`:143-149`) — the generic `shot_rifle.wav` class bank. **The M16 fires and you
hear a rifle. It just isn't the M16.** No warning, no print, no red suite. The briefing calls this
out at line 48 and it is the correct top concern.

> **RECOMMENDATION (highest value/line-count ratio in this entire wave):** make the fallback loud
> once per id. Three lines in `_next_fire()` — a `Dictionary` of already-warned ids, a
> `push_warning("AudioManager: %s has no fire_ renders, using class bank" % wid)` on first fall-through.
> That converts the project's flagship silent failure into a line in `get_debug_output()`, which is
> the only verification surface we actually have (see §5). It documents behaviour, not history, so it
> is COMMENT DISCIPLINE-clean.

### 1c. The worse failure: **replacing content in place**

The `path=` field in the sidecar (`fire_ak47_1.wav.import:6`) hashes the **source path**, not the
source bytes. So dropping a new recording onto `fire_ak47_1.wav` requires **no `.import` change at
all** — the sidecar stays valid, git shows one modified binary, everything looks clean.

But `.godot/imported/fire_ak47_1.wav-<hash>.sample` and its `.md5` still hold the **old synth
placeholder**, and the import pipeline only runs on an editor scan or an explicit import pass. Launch
the game via `run_project` without reimporting and **you hear the placeholder you just deleted**, and
you conclude the swap failed — or, worse, you A/B it against a stale cache and conclude a good
derivation "sounds worse than the placeholder" and keep the placeholder per ruling 2. **A stale
import cache can corrupt the Summoner's own listening test.**

### 1d. The correct way to force generation — and what not to trust

House rule, already recorded twice in canon (`production/GAME_GUIDE.md:310-311`,
`.claude/agents/recon-overseer.md:89-90`, `ADR-023-amendment-A:83`):

```
godot --headless --path . --import
```

- **`--check-only` false-positives on autoloads** — never use it as the gate here.
- `--editor --quit` misses parse errors and is not a reliable import trigger.
- A stale `.godot` class cache is fixed by `--headless --import`.
- If imports still misbehave after 4.7's first-open reimport, delete `.godot/` and reopen
  (`~/.claude/architect_knowledge/godot_4.7_features.md:106`). That is a 10-minute reimport of the
  whole project — schedule it, don't discover it.

**Sequencing law for this wave:** land files → `--headless --import` → *then* `run_project`. Any
listening test performed between step 1 and step 2 is testing the cache, not the pack.

### 1e. OGG (and MP3) in 4.7 — yes, they need an `.import`, and it differs

`assets/audio/Radio Vietnam/Radio_Vietnam_GOOD_MORNING_long_run.ogg.import`:

```
importer="oggvorbisstr"   type="AudioStreamOggVorbis"   uid="uid://bj82465lcd78u"
[params]
loop=false   loop_offset=0   bpm=0   beat_count=0   bar_beats=4
```

`assets/audio/ambience/jungle_day.mp3.import` is the same shape with `importer="mp3"` /
`type="AudioStreamMP3"`. Differences that matter:

| | WAV | OGG / MP3 |
|---|---|---|
| Result type | `AudioStreamWAV` (in-memory sample) | `AudioStreamOggVorbis` / `AudioStreamMP3` (stream) |
| Channels | forced by `force/mono` | **untouched — stays stereo** |
| Compression | `compress/mode` | n/a (already compressed) |
| Loop | `edit/loop_mode=0` | **`loop=false`** |

**`loop=false` is load-bearing for the radio.** `radio_prop.gd:53` connects `_player.finished` and
`:66-68` is the ONLY thing that advances the playlist. Import one broadcast with `loop=true` and
`finished` never fires — **that one track plays forever and the other four, plus every folk song,
never play again.** Same class of bug as §1a, same invisibility: the radio is still making noise, so
nothing reads as broken.

The 14-track LP can ship as `.mp3` directly (`jungle_day.mp3` proves the importer works) or be
converted to `.ogg`. `.ogg` is smaller and avoids MP3 encoder-delay padding; either is correct for
music. **Do not convert the 5 broadcasts** — ruling 4, bit-for-bit.

---

## 2. Radio prop redesign

### 2a. Does the current `_load_tracks()` recurse? — NO, and that answer is doubly safe

`radio_prop.gd:30-44`. `DirAccess.list_dir_begin()` + `get_next()` is **flat**: it enumerates the
entries of one directory only. Subdirectory *names* come back as entries, but two independent guards
reject them:

1. `not dir.current_is_dir()` (`:37`) — true only for files, evaluated against the entry
   `get_next()` just returned. Correct usage; a subfolder named `music` never reaches the load.
2. Even without guard 1, `"music".get_extension()` is `""`, which fails `== "ogg"`.

So a `music/` subfolder under `Radio Vietnam` is **neither skipped by accident nor scooped up as a
broadcast**. Both mechanisms work today. The mix cannot be silently wrong via recursion.

### 2b. Two `@export_dir`, and the music tree should be a SIBLING, not a subfolder

Since recursion is a non-issue, the deciding factor is **licensing hygiene (ruling 3)**. A music
subfolder inside the tracked `assets/audio/Radio Vietnam/` tree means gitignoring a directory nested
under files that are tracked — which works, but puts a commercial LP one careless `git add -f` or one
`!` negation away from a public repo. A sibling tree is one unambiguous line:

```gitignore
# Commercial LP — licensed recording, public repo (owner ruling 2026-07-27)
assets/audio/music/radio/
```

**Ignore the whole directory including the `.import` sidecars.** Never track an `.import` whose
`source_file` is ignored — Godot then has a sidecar pointing at a file no clone has, and the uid it
declares (`:5`) resolves to nothing.

**Consequence that must be handled, not discovered:** a fresh clone / any build machine has **zero
music files**. The radio must degrade to broadcast-only without error, and the probe must score that
as PASS-with-note, not FAIL — otherwise the suite is red for everyone except Caleb's disk. The design
below handles it in the selection function.

Never infer the two lists by "subfolder vs not". Two explicit `@export_dir` exports: the intent is
visible in the inspector, and either directory can move without touching code.

### 2c. The RAM problem nobody has hit yet

`radio_prop.gd:12` holds `_tracks: Array[AudioStream]` and `:38-40` **eagerly `load()`s every file at
`_ready()`**. `du -sh "assets/audio/Radio Vietnam"` = **92 MB**, all resident for the whole session,
loaded on the main thread during world build (`site_planner.gd:922` → `:935-943`). Add a 14-track LP
and this becomes a ~200 MB always-resident block plus a longer boot hitch, for a prop the briefing
explicitly calls *incidental*.

The redesign stores **paths**, loads one stream at a time, and lets the previous one drop. Godot 4's
resource cache is weak-referenced, so reassigning `_player.stream` releases the old stream and RSS
stays bounded to one track. This is a side-effect win of the rewrite, not extra work.

### 2d. The script

One script. Strict typing. No comment narration. No UI, no signal, no telegraph.

```gdscript
extends Node3D
## Diegetic field radio: interleaves folk music with broadcast recordings as positional 3D audio.

const MUSIC_PER_BROADCAST: int = 3
const AUDIO_EXTS: Array[String] = ["ogg", "mp3", "wav"]

@export_dir var broadcast_dir: String = "res://assets/audio/Radio Vietnam"
@export_dir var music_dir: String = "res://assets/audio/music/radio"
@export_file("*.obj", "*.glb") var model_path: String = "res://assets/world/props/radio/radio.obj"
@export var hear_distance: float = 25.0
@export var volume_db: float = -4.0
@export var shuffle: bool = true

var _player: AudioStreamPlayer3D = null
var _music: Array[String] = []
var _broadcast: Array[String] = []
var _music_cursor: int = 0
var _broadcast_cursor: int = 0
var _slot: int = 0
var _last_path: String = ""


func _ready() -> void:
	_build_mesh()
	_music = _scan(music_dir)
	_broadcast = _scan(broadcast_dir)
	if shuffle:
		_music.shuffle()
		_broadcast.shuffle()
	_build_player()
	_advance()


func _build_mesh() -> void:
	var res: Resource = load(model_path)
	if res is Mesh:
		var mi := MeshInstance3D.new()
		mi.mesh = res as Mesh
		add_child(mi)
	elif res is PackedScene:
		add_child((res as PackedScene).instantiate())


func _scan(dir_path: String) -> Array[String]:
	var out: Array[String] = []
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		return out
	dir.list_dir_begin()
	var fname: String = dir.get_next()
	while fname != "":
		if not dir.current_is_dir():
			var clean: String = fname
			if clean.ends_with(".import") or clean.ends_with(".remap"):
				clean = clean.get_basename()
			if AUDIO_EXTS.has(clean.get_extension().to_lower()):
				var path: String = dir_path.path_join(clean)
				if not out.has(path):
					out.append(path)
		fname = dir.get_next()
	dir.list_dir_end()
	return out


func _build_player() -> void:
	_player = AudioStreamPlayer3D.new()
	_player.max_distance = hear_distance
	_player.unit_size = 6.0
	_player.volume_db = volume_db
	_player.bus = "SFX" if AudioServer.get_bus_index("SFX") != -1 else "Master"
	add_child(_player)
	_player.finished.connect(_advance)


func _take(list: Array[String], cursor: int) -> Array:
	var path: String = list[cursor]
	var next: int = cursor + 1
	if next >= list.size():
		next = 0
		if shuffle and list.size() > 1:
			list.shuffle()
			if list[0] == path:
				list[0] = list[list.size() - 1]
				list[list.size() - 1] = path
	return [path, next]


func _next_path() -> String:
	var want_broadcast: bool = _slot % (MUSIC_PER_BROADCAST + 1) == MUSIC_PER_BROADCAST
	_slot += 1
	var use_broadcast: bool = (want_broadcast and not _broadcast.is_empty()) or _music.is_empty()
	if use_broadcast:
		if _broadcast.is_empty():
			return ""
		var b: Array = _take(_broadcast, _broadcast_cursor)
		_broadcast_cursor = int(b[1])
		return String(b[0])
	var m: Array = _take(_music, _music_cursor)
	_music_cursor = int(m[1])
	return String(m[0])


func _advance() -> void:
	var attempts: int = maxi(_music.size() + _broadcast.size(), 1)
	for _i in range(attempts):
		var path: String = _next_path()
		if path.is_empty():
			break
		var stream: AudioStream = load(path) as AudioStream
		if stream == null:
			push_warning("RadioProp: unplayable stream %s" % path)
			continue
		_last_path = path
		_player.stream = stream
		_player.play()
		return
	push_warning("RadioProp: no playable audio in %s or %s" % [music_dir, broadcast_dir])
```

**Why it is shaped that way — each point is a bug that would otherwise be silent:**

- **`.import` / `.remap` stripping in `_scan()`.** In the **editor** `DirAccess` sees `x.ogg` *and*
  `x.ogg.import`; in an **exported build** the source files are not in the PCK at all and the
  listing surfaces the remapped entries. Stripping the suffix and de-duplicating makes one scan
  correct in both worlds. Without it: works perfectly for the whole of development, **radio dead
  silent in the shipped build**, and nobody finds out until a player says so. This is the single
  nastiest trap in a directory-scanning prop.
- **`_advance()` is a bounded `for`, not recursion.** The naive "on failure, call myself" version
  stack-overflows the moment every file fails to load (e.g. after a bad import pass). Bounded by the
  total track count, it degrades to one warning.
- **`_next_path()` is separable and side-effect-light.** That is a testability requirement, not
  taste: it is the only way to prove the 3:1 pattern without waiting ~40 real minutes for whole
  tracks to finish (§5).
- **Empty-list degradation is explicit.** No music (fresh clone, CI) → broadcasts only. No
  broadcasts → music only. Neither divides by zero nor spins.
- **Reshuffle on wrap, with an anti-repeat swap at the seam.** Without it the 5 broadcasts settle
  into a fixed 5-cycle a long session can memorise. With a naive reshuffle you get the same track
  twice back to back.
- **Bus stays `SFX` (`_build_player`).** A `Music` bus exists (`default_bus_layout.tres:69`), but
  routing here would put Nixon's inauguration behind a music slider. It is a diegetic world source.
  Also note the ambience duck targets `Ambience` (`audio_manager.gd:339-344`), so gunfire will not
  duck the radio on either bus — that is existing behaviour and out of scope.
- **No `_cursor = 0` reset.** The old `_start()` (`:55-60`) hard-reset the cursor; see §3.
- **Nothing is emitted, printed, or displayed about what is playing.** Ruling 4 satisfied.

**Rejected alternatives, named:**

- *Ratio jitter (2–4 songs per broadcast) to hide the schedule* — **violates ruling 1**, which is
  binding. Not proposed.
- *`AudioStreamInteractive` / `AudioStreamPlaylist`* (4.7 has resume-position transitions,
  `godot_4.7_features.md:34-35`) — would move playlist logic into a resource authored in the editor
  and out of the one script. Rejected: more moving parts, a new authored asset to keep in sync, and
  it buys nothing the code above lacks.
- *Threaded prefetch* — worth considering as a follow-up, not mainline. A synchronous `load()` of a
  42 MB Ogg inside the `finished` callback will hitch a frame at every track change.
  `ResourceLoader.load_threaded_request(next_path)` right after `play()`, collected in `_advance()`,
  removes it at the cost of two more state vars. **Recommend measuring the hitch first** — if it is
  invisible on a ~1 s transition between tracks, do not pay the complexity.

---

## 3. Continuity — "discovered" is already free; do almost nothing

**Yes, it is free, and the code says so.** `AudioStreamPlayer3D.max_distance` (`radio_prop.gd:48`,
25.0 m) governs **attenuation only**. Playback is not gated on listener distance: the stream keeps
advancing, `get_playback_position()` keeps climbing, and `finished` still fires on schedule while the
player is 800 m away in the jungle. Walk away for twelve minutes, walk back, and you arrive
**mid-song at a point nobody chose** — which is exactly the requested feel, at zero cost.

`shuffle` (`:9`, `:43-44`) already prevents "same track first, every boot". Between the two, the
Summoner's brief is met by the *existing* architecture.

**What actually needs to change: one deletion.** `_start()` sets `_cursor = 0` at `:59`. It is
redundant (the var already initialises to `0` at `:13`) and it is a live restart hazard: if the prop
is ever respawned, pooled, or re-`_ready()`d by a future streaming pass, that line guarantees a
restart from the top. The rewrite above drops it. `site_planner.gd:922` / `:935-943` stamps the radio
exactly once as a child of the world parent, and I found **no `queue_free()` path that reaches it**
today — so this is prophylaxis, not a live bug, and it costs one line to be permanently safe.

**What must NOT be added:** a distance gate that stops/starts the player "to save CPU". It would
convert free organic continuity into a scheduled restart on every approach — the precise thing ruling
4 forbids — and one Ogg decode is not a measurable cost against this project's real budget.

**What is sacrificed (no free lunches):** a fixed 3:1 ratio *is* a schedule, and a patient player can
clock it. The only thing hiding it is that the tracks are wildly uneven in length — 42 MB vs 2.3 MB —
so the slot cadence maps to very irregular wall-clock spacing. Ruling 4 calls the imbalance a
feature; it is also the camouflage. Anything that normalises track lengths would expose the pattern.

---

## 4. Fossil law (ADR-023) — what must die, and what would linger and lie

**Per-file, because ruling 2 makes this a partial replacement.**

1. **A deleted `.wav` takes its `.wav.import` with it, in the same change.** `git rm` both. The
   sidecar is tracked (`git ls-files`, §1a), so removing only the audio leaves in HEAD, forever, an
   `.import` whose `source_file=` (`:10`) names a file that does not exist. The editor prunes such
   orphans on a local scan; **git does not**, and the next clone gets a sidecar declaring a `uid`
   (`:5`) for nothing.
2. **A replaced-in-place `.wav` KEEPS its `.import` unchanged** — the `path=` hash derives from the
   source path, not the bytes (§1c). Do not delete and regenerate it; that churns a uid for no
   reason. Just reimport.
3. **Never hand-write or copy a `uid`.** Two `.import` files carrying the same uid silently resolve
   one resource to the other — a failure with no error message anywhere.
4. **`.uid` sidecars are not part of this.** 355 are tracked, but they belong to `.gd`, `.gdshader`
   and `.ogv`; there is **no `.uid` next to any `.wav`** (checked). Imported audio carries its uid
   *inside* the `.import`. Do not create `.wav.uid` files.
5. **Local-only stale artifacts:** `.godot/imported/*.sample`, the paired `*.md5`, and
   `.godot/uid_cache.bin`. All under `.gitignore:2`, so they never poison a clone — but they poison
   **this** machine, which is where the listening test happens. `--headless --import` fixes the
   normal case; deleting `.godot/` and reopening is the hammer (`godot_4.7_features.md:106`).
6. **A deliberately-kept placeholder is NOT a fossil — but an undocumented one is a lie.** Ruling 2
   allows keeping a placeholder where a derivation is worse. That decision must be written down per
   weapon id in the tracking docs, or the next agent reads a 72044-byte synth file as a missed swap
   and "fixes" it. This is exactly the POINTER LAW case.
7. **`tests/test_fossils.tscn` will not catch any of this.** It hunts unreferenced symbols, not
   orphan sidecars. **Recommend ~10 lines added to the asset probe** (`tests/test_asset_probe.gd`
   pattern, `:30-45`): sweep every `*.import` under `assets/audio/` and fail if its `source_file`
   is absent from disk. It ratchets, it is mechanical, and it makes item 1 impossible to forget.

---

## 5. The probe (ADR-015) — proving streams LOAD and PLAY, not that files exist

**The hard constraint:** `audio_manager.gd:59` sets `_headless` from `DisplayServer.get_name()`, and
`:63-64` returns before building the voice pool or loading fallbacks. **Every public play path
returns immediately under headless** (`:169`, `:257`, `:291`, `:301`, `:311`, `:340`). A headless run
can therefore prove *nothing* about AudioManager. Verification must go through
`mcp__godot__run_project` + `mcp__godot__get_debug_output`, i.e. a real windowed run with a real
audio driver, reading `print()` / `push_warning()` output.

Note the radio prop does **not** check headless — it will happily call `play()` under the dummy
driver. Do not rely on that; run it real.

### Leg A — loadability + import-contract assertion (catches §1 in full)

A probe scene that, for all 16 weapon ids × the convention in `audio_manager.gd:5-10`, and for every
file in both radio directories:

- `load(path)` and **assert non-null**. Never `ResourceLoader.exists()` — §1b explains why that is
  not a proof.
- For `AudioStreamWAV`: assert `loop_mode == AudioStreamWAV.LOOP_DISABLED` (catches the
  voice-pool-killer, §1a), `mix_rate == 44100`, `stereo == false` (the `force/mono` contract),
  `get_length() > 0.0`.
- For `AudioStreamOggVorbis` / `AudioStreamMP3`: assert **`loop == false`** (catches the
  playlist-freezer, §1e) and `get_length() > 0.0`.
- Print every length. **This is also the stale-cache detector:** every placeholder near-report is
  72044 B and every `_dist` is 153644 B (briefing, measured). Minus the 44-byte header at 16-bit
  44.1 kHz that is **0.8163 s mono / 0.4082 s stereo** near, **1.7415 s / 0.8707 s** dist. A file
  that still reports a placeholder length after the swap **is the old sample being served from
  `.godot/imported/`**, not a bad recording. (Confirm mono vs stereo on the placeholders from the
  first probe run rather than assuming; either way the equality test is what matters.)

Leg A also proves the negative that matters most: **there is no id for which `_fire_variants()`
returns empty**, i.e. no weapon silently drops to the class bank — without touching AudioManager's
private methods, because the probe resolves by the same published convention.

### Leg B — the radio actually plays (not merely loads)

`run_project`, then from the probe:

- Assert `_player.playing == true`.
- Sample `_player.get_playback_position()` at ~0.5 s and ~2.0 s and assert it is **strictly
  increasing and > 0**. A stream that loaded but produces no audio (bad codec, zero-length, dummy
  driver) sits at 0.0. This is the difference between "the resource exists" and "the rig runs".
- Print the resolved *count* of each list (`_music.size()`, `_broadcast.size()`). Zero music on a
  fresh clone is **PASS-with-note**, not FAIL (§2b).

### Leg C — the 3:1 pattern, without waiting 40 minutes

Do **not** seek, truncate or early-fade a broadcast to speed this up — ruling 4 forbids it and a
probe that violates canon is worse than no probe. Instead call `_next_path()` twelve times on a
detached instance and assert the pattern is `M M B` per the counter — three music paths then one
broadcast path, three cycles, with the broadcast cursor visiting three distinct files and no
list restarting at index 0 mid-run. This is why `_next_path()` is separable (§2d). It proves the mix
law in milliseconds and leaves the audio untouched.

### Leg D — the human leg, which nothing replaces

ADR-015 leg 3: **verified playtest observation.** Ruling 2's "if a derivation sounds worse, keep the
placeholder" is a judgement only the Summoner can make, and per §1c it is only valid **after**
`--headless --import` has run. Sequence it explicitly in the decree: land → import → run → listen.

### What the probe still cannot prove

Whether a derivation sounds *good*. Whether the mono collapse hurt a particular take. Whether the
3:1 cadence reads as organic after two hours. Those are ears, not code — name them as such rather
than letting a green probe imply them.

---

## Summary of concrete recommendations

1. Add a one-shot `push_warning` on class-bank fallback in `audio_manager.gd:_next_fire()`. Three
   lines; converts the project's flagship silent failure into observable output.
2. Rewrite `radio_prop.gd` as §2d: two `@export_dir`, path-based lazy loading, `.import`/`.remap`
   suffix stripping, bounded `_advance()`, separable `_next_path()`, no cursor reset.
3. Music tree at `assets/audio/music/radio/`, gitignored whole (sidecars included), NOT a subfolder
   of the tracked broadcast dir.
4. Enforce the import contract per §1a / §1e — `edit/loop_mode=0` on every wav, `loop=false` on
   every ogg/mp3, `force/mono=true`, `compress/mode=0`.
5. Never listen before `godot --headless --path . --import`. Never gate on `--check-only`.
6. Delete `.wav` and `.wav.import` together; record every deliberately-kept placeholder by weapon id.
7. Add the orphan-`.import` sweep to the asset probe so item 6 is mechanical.
8. Probe legs A–D; treat zero music files as PASS-with-note.
