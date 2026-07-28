# Devil's Advocate — Audio Pack Integration

**Date:** 2026-07-27. Every claim below carries a `file:line` or a measured command output.
Nothing here was read from a plan; all of it was read from the code and the files on disk.

---

## 0. THE HEADLINE: five of the twelve weapons in Ruling #2 ARE RETIRED BY CANON, and a probe FAILS THE BUILD if anything loads them

`tests/test_flat_damage.gd:28-31`:

```gdscript
## Retired - loading one of these is a FAIL. mp40/kar98k by ADR-016;
## car15/sks/thompson by Amendment C (no FP arms = not a gun in this game;
const RETIRED := ["mp40", "kar98k", "car15", "sks", "thompson"]
```

Ruling #2 as written says: `5.56 → m16a1, car15` · `7.62x39 → ak47, sks, rpd` · derive
`thompson, kar98k, mp40`. **Five of those twelve weapon ids are retired.** They have no
`data/weapons/*.tres`, they cannot be equipped, and the damage suite treats loading one as a failure.

Measured, `ls data/weapons/` — the 15 weapons that ACTUALLY EXIST:
`ak47 · m14 · m16a1 · m1911 · m26_grenade · m60 · m70 · m72_law · m79 · mosin · ppsh41 · rpd ·
rpg2 · rpg7 · shotgun`

Measured, the 16 ids that have `fire_*` audio on disk:
`ak47 · car15 · kar98k · m16a1 · m1911 · m60 · m72_law · m79 · mosin · mp40 · ppsh41 · rpd ·
rpg2 · rpg7 · sks · thompson`

Diff both ways:

| Has audio, NO weapon (dead) | Has weapon, NO `fire_` audio (silent gap) |
|---|---|
| car15, kar98k, mp40, sks, thompson | **m14, m70, shotgun** |

Two consequences, and both are bad:

1. **The ruling spends its most expensive resource — hand-sliced real recordings — on phantoms.**
   car15 and sks are named as *exact caliber matches*, the highest-confidence tier of the whole job.
   Neither weapon exists. thompson/kar98k/mp40 are three of the six named derivations. Roughly **half
   the coverage budget in Ruling #2 is aimed at guns the player can never hold.**
2. **`m14` and `m70` are not mentioned once in the briefing.** They are live `.tres` weapons with
   zero dedicated fire audio, so `audio_manager.gd:155` routes them to `_fallback_for()` →
   `shot_rifle.wav`. `m70` is the **87-damage sniper** (CLAUDE.md damage table) — the most lethal
   small arm in the game — and it currently sounds like the generic rifle bank. `m14` is a semi-auto
   7.62x51 battle rifle sharing that same generic bank. **The pack's 7.62x54R stock is the nearest
   thing this project will ever get to a 7.62x51 report**, and the ruling routes it exclusively to
   `mosin` — a weapon that is *already* deliberately kept at base 27 as "the VC line rifle."

**The ruling's coverage list was derived from the filenames on disk, not from the weapons the game
can equip.** That is the exact failure mode the POINTER LAW exists to catch: a list that reads as a
statement about the game but is actually a statement about a directory listing.

Corollary under **ADR-023 FOSSIL LAW**: those ~30 `.wav` files for the five retired ids
(`fire_/mech_/reload_/bolt_` × car15, kar98k, mp40, sks, thompson) are textbook fossils — assets that
read as live coverage and survive every grep. `tests/test_fossils.tscn` scans *symbols*, not assets,
so it has never seen them. **They should be deleted in this same change**, not re-recorded.

**Recommended amendment to Ruling #2 (this is a factual correction, not a re-litigation):**
- 5.56 → `m16a1` (only)
- 7.62x39 → `ak47`, `rpd`
- 7.62x54R → `mosin`, and **`m14` + `m70` as the primary derivation targets** (with treatment)
- Delete the retired-id wav sets
- `shotgun` stays out of scope (no shotgun stock in the pack), but note it is on the rifle fallback today

---

## 1. THE LICENSING TRAP — the horse has already left, and there is a live precedent that is already broken

### 1a. The broadcasts are ALREADY TRACKED IN THE PUBLIC REPO

```
$ git ls-files "assets/audio/Radio Vietnam"
assets/audio/Radio Vietnam/Radio_Vietnam_GOOD_MORNING_long_run.ogg          (42.9 MB)
assets/audio/Radio Vietnam/Radio_Vietnam_July_ApolloLanding_W_Ads_1969.ogg  ( 8.5 MB)
assets/audio/Radio Vietnam/Radio_Vietnam_Light_Rains_and_Baseball_w_Adds.ogg( 7.5 MB)
assets/audio/Radio Vietnam/Radio_Vietnam_Night_Beat_December_REAL_RADIO_edited.ogg (35.1 MB)
assets/audio/Radio Vietnam/Radio_Vietnam_Nixion_Inaguration_Janurary_1969.ogg( 2.3 MB)
$ git check-ignore -v "assets/audio/Radio Vietnam/Radio_Vietnam_GOOD_MORNING_long_run.ogg"
(no rule matches)
```

**96 MB of AFVN broadcast — with period advertisements, network jingles, and, by their own filenames,
music — is tracked and pushed to a public repo right now.** Ruling #3 gitignores a Vietnamese folk LP
on licensing grounds. That is defensible in isolation, but as a *policy* it is inconsistent: the folk
LP is one commercial recording; `Night_Beat_December_REAL_RADIO_edited.ogg` is 52 minutes of somebody
else's broadcast including whatever songs were on it that night.

I am **not** asking to re-open Ruling #4 (broadcasts untouched, bit for bit — understood and
respected). I am saying the *stated rationale* for Ruling #3 does not survive contact with
`git ls-files`, and the Council should either (a) accept the folk gitignore as a **shipping-hygiene**
decision rather than a legal one, or (b) put the broadcasts to the Summoner as the same question.
Silently applying a licensing standard to the new files that the existing files fail is how a repo
ends up with a rule nobody can explain in six months.

### 1b. The precedent exists AND IT IS ALREADY BROKEN — this is the trap, verbatim

`.gitignore:27-28`:

```
# 55MB YouTube-sourced dev ambience - license-unclear, replace for release (bead xu94)
assets/audio/ambience/jungle_day.mp3
```

Now measure what a fresh clone actually gets:

```
$ git ls-files assets/audio/ambience/
assets/audio/ambience/jungle_day.mp3.import      <-- TRACKED
                                                 <-- the .mp3 itself: IGNORED
```

`scripts/levels/game_world.gd:265-266`:

```gdscript
if ResourceLoader.exists("res://assets/audio/ambience/jungle_day.mp3"):
    var mp3 := load("res://assets/audio/ambience/jungle_day.mp3") as AudioStreamMP3
```

**A fresh clone ships a tracked `.import` sidecar pointing at a `source_file` that does not exist,
with no `.godot/` cache (also ignored). The guard is `ResourceLoader.exists()`, the cast is `as
AudioStreamMP3` — a failed load yields `null` and the `as` cast swallows it. There is no
`push_warning`, no error, nothing. A cloner gets a jungle with no jungle ambience and is never told.**

That is exactly the failure the query asks about, already shipped, already live. The folk-music plan
reproduces it one-for-one — except `radio_prop.gd:57` is even quieter about it (see §3d).

And the comment on that rule cites **"bead xu94"**. Beads were **RETIRED 2026-07-22** (CLAUDE.md,
Task Tracking). The one pointer in the rule is a dead pointer to a retired tracker. This is a live
POINTER LAW violation sitting inside the very firewall we are about to extend — and CLAUDE.md's DRIFT
rule says **when you touch a file and find a claim that is no longer true, you correct it in the same
change.** We are about to touch `.gitignore`. Fix line 27 in the same edit.

### 1c. What MUST be documented, or this becomes the next DRIFT incident

The DRIFT law names five prior incidents, and one of them is *"a `.gitignore` comment justifying an
untracked 133 MB truth source as regenerable from `us_grunt_v2.blend`, a file that does not exist."*
We are one careless line away from writing the sixth. Non-negotiable conditions:

1. **`.import` sidecars for the ignored music MUST be ignored too.** Ignore the whole directory
   (`assets/audio/music/`), not just the media extension. A tracked `.import` with a missing source
   is strictly worse than nothing: it makes the editor's import scan noisy on clone and makes
   `ResourceLoader.exists()` unreliable. **Fix `jungle_day.mp3.import` the same way** — `git rm
   --cached` it.
2. **The gitignore rule must carry a live pointer**, per POINTER LAW: what the files are, where they
   came from, who has them, and that they are *deliberately absent*, e.g.
   `# Commercial folk LP (owner's local copy) - absent from clones ON PURPOSE. The radio degrades to
   broadcast-only and says so at scripts/props/radio_prop.gd:<line>.` No bead ids. No "replace for
   release" with no owner.
3. **Every doc that describes the radio must state the clone behaviour.** Today
   `production/AI_LIVING_WORLD_ROADMAP.md:20` and `production/CALEB_TODO_7_22_updated.md:165` both
   describe the radio. If either ends up saying "the radio plays period folk music" without the
   caveat, that sentence becomes a lie in the map the moment someone clones. **The claim "the radio
   plays music" must never appear in this repo without "on the owner's machine" beside it.**
4. **The code must be LOUD, not silent.** `radio_prop.gd` must `push_warning` when the music
   directory is missing or empty — not only when *all* tracks are missing (see §3d, where I show the
   current guard cannot possibly fire).

**Named sacrifice:** every future contributor, and every future agent session run against a fresh
clone, plays a different game than the owner does. The radio is "incidental and discovered" by
design, which means **nobody will notice the music is gone.** That is the whole point of a trap.

---

## 2. THE GUN SWAP IS A DOWNGRADE RISK — and one specific loss is a Pillar-1 violation

### 2a. Stereo → this is the single most likely silent defect in the job (see §4 for the mechanism)

Measured on the current placeholders:

```
fire_ak47_1.wav     1 ch  48000 Hz  0.750 s  16 bit
fire_ak47_dist.wav  1 ch  48000 Hz  1.600 s  16 bit
fire_m16a1_1.wav    1 ch  48000 Hz  0.750 s  16 bit
reload_ak47.wav     1 ch  48000 Hz  2.400 s  16 bit
bolt_mosin.wav      1 ch  48000 Hz  1.500 s  16 bit
```

**Everything shipping today is MONO.** The briefing measures the pack as **44100 Hz / 2ch**. The
existing bank was authored mono *for a positional voice pool*. That is not an accident of the synth —
it is the correct format for `AudioStreamPlayer3D`. Swapping in 2ch files changes the format contract
of the entire bank, and nothing in the code checks it.

### 2b. Range echo baked in fights the game's own environment

`audio_manager.gd:83` sets `attenuation_filter_cutoff_hz = 5000.0` per voice as "cheap per-voice air
absorption." `audio_manager.gd:339-362` runs an ambience duck. The distance-band split at
`:189-196` picks near vs distant renders. **This mix already models the environment.** A civilian
range recording arrives with a concrete-and-berm slapback and an open-sky tail baked in, unremovable.
Put that under a triple-canopy jungle and the player hears a firing line, not an ambush.

The briefing's own measurement makes this concrete and it is being read optimistically:
*"Full Sound is 2.3-2.4x longer with a lower mean — it is the dry shot plus environmental tail."*
That environment is **the range**, not the AO. Assigning Full Sound to the distant layer means
**every distant contact in the game inherits the acoustics of an American shooting range.** The
current `fire_*_dist.wav` placeholder was rendered *for* this mix. It is not obviously worse.

Worse, on the near/player path: `audio_manager.gd:280-286` builds the tail by **reusing the near
stream** at `pitch_scale = 0.72`, `-16 dB` — because there are literally zero `tail_*` files on disk
(measured: `ls assets/audio/sfx/weapons/ | grep -c "^tail_"` → **0**). If Full Sound (echo already
baked) ever lands in the `fire_*_1..3` slots, the player gets range-echo **plus a pitched-down
smeared copy of the same range echo**. That is mud, and it will read as "the new guns sound worse"
with no obvious cause.

### 2c. One take repeated three times is worse than three synth variants

The briefing states plainly: *"The pack ships one take per caliber per fire-mode... there is no set
of three alternate single-shot takes, so `fire_<id>_1..3` must be built by slicing discrete shots out
of the multi-shot files."*

`_next_fire()` (`audio_manager.gd:152-158`) round-robins the three variants specifically to defeat
machine-gun sameness, and `_play_voice()` adds `pitch_scale` jitter on top. Three slices from **one
continuous burst, one microphone, one position, one magazine** are far more correlated than three
independent synth renders. Sustained automatic fire is exactly where the ear detects looping, and
`rpd`/`m60` are the weapons that fire longest. **The realism gain is per-shot; the loss is
per-burst — and bursts are what a firefight is made of.**

### 2d. THE PILLAR-1 OBJECTION — I will say it plainly

**One caliber sample serving an AK-47 and an RPD makes them the same gun to the ear, and that is a
real tactical information loss.**

- An RPD is a belt-fed light machine gun at ~650 rpm. An AK-47 is a 30-round assault rifle.
- Their canon damage differs by a factor that matters: **AK 27, RPD 42** (CLAUDE.md, ADR-016
  Amendment H — "MG class = 42").
- `play_shot_3d()` throttles far shooters at `FAR_SHOOTER_THROTTLE_MS = 70` beyond
  `FAR_SHOOTER_DIST_M = 60.0` (`audio_manager.gd:25-26, 183-187`) — **"a distant MG is a texture, not
  11 discrete events."** So at range the RPD's *rate* is deliberately flattened. Rate was the last
  remaining cue. Take timbre away too and **a distant RPD and a distant AK become acoustically
  indistinguishable.**

Pillar 1 is *believable firefights — AI that fights like soldiers AND weapons that kill like
weapons.* A soldier under fire identifies the threat by ear before he ever sees it: *that's an RPD,
get down and don't cross that lane* versus *that's one rifleman.* In this game the sound is the
**only** cue the player gets for a 55%-higher-damage weapon at distance. Collapsing them is not a
cosmetic compromise. **It is the deletion of a tactical information channel, in service of a
provenance claim (this is genuinely 7.62x39) that no player can ever hear.**

The Summoner's ruling ends *"If a derivation sounds worse than its placeholder, KEEP THE
PLACEHOLDER. Never ship a downgrade for coverage."* **A shared sample that erases weapon
identification IS a downgrade** — it just isn't audible one shot at a time, only in a firefight. The
ruling's own escape hatch covers this case; it must be applied at the level of *the firefight*, not
the sample.

Concretely: give the RPD **heavy** differentiation from the AK — mechanical/receiver layer via
`mech_rpd.wav`, a distinct slower-decaying `fire_rpd_dist.wav`, meaningful pitch/body separation —
or **keep the RPD placeholder.** Same caliber, different gun. The pack cannot know that; only we can.

### 2e. The A/B test that will lie to you

`play_shot_player()` (`:256-288`) uses dedicated 2D slots — *"always crisp, dedicated slot, never
stolen"* — with a `mech` layer and a `tail` layer. `play_shot_3d()` uses the pooled
`AudioStreamPlayer3D` bank with air filtering, distance banding, voice stealing and the far-shooter
throttle. **These are two different mixes of the same file.** Anyone who evaluates the swap by
picking up the gun and firing is auditioning the 2D path only, and will approve stock that sounds
thin, phasey, or misplaced coming from an ally three metres away. **Every A/B must include an NPC
firing the same weapon at 10 m, 50 m, and 100 m.**

---

## 3. THE 3:1 INTERLEAVE — the arithmetic, honestly

Measured with `ffprobe`:

| Broadcast | Duration |
|---|---|
| `GOOD_MORNING_long_run` | 4319.9 s = **72.0 min** |
| `Night_Beat_December_REAL_RADIO_edited` | 3134.5 s = **52.2 min** |
| `July_ApolloLanding_W_Ads_1969` | 1156.0 s = **19.3 min** |
| `Light_Rains_and_Baseball_w_Adds` | 817.9 s = **13.6 min** |
| `Nixion_Inaguration_Janurary_1969` | 325.0 s = **5.4 min** |
| **Total / mean** | **9753.3 s = 162.6 min / 32.5 min mean** |

Take folk songs at ~3 min (180 s), the generous middle of the 2–4 min estimate.

**One 3:1 cycle = 3 × 180 s music + 1 broadcast.**

| Broadcast drawn | Cycle length | Music share **by time** |
|---|---|---|
| Nixon (best case) | 865 s | **62.4 %** |
| Light Rains | 1358 s | 39.8 % |
| Apollo | 1696 s | 31.8 % |
| Night Beat | 3675 s | 14.7 % |
| GOOD MORNING (worst case) | 4860 s | **11.1 %** |
| **At the mean broadcast** | **2490 s** | **21.7 %** |

**"3 music : 1 broadcast" by COUNT delivers roughly 1 : 3.6 by TIME.** The ratio is not merely
diluted — **it is inverted.** In the worst draw the player hears three songs and then **72 minutes**
of talk before the next one.

Ruling #4 stands and I am not proposing a cut. But nobody should be surprised later, so state it
now: **the folk LP is not "the radio's music layer." It is a rare event between long broadcasts.**
14 songs at ~3 min ≈ 42 minutes of music against 163 minutes of broadcast — the library itself is
**1 : 3.9 by duration** before any interleave rule is applied. The ratio ruling is, in practice, a
choice about *ordering*, not about *proportion*, and it cannot change the proportion.

Now stack the geometry on top, and it gets sharper:

### 3a. The radio is a 25-metre bubble at the firebase — ONE instance, and the player walks away from it

`scripts/world/site_planner.gd:932-943`:

```gdscript
const RADIO_SCENE: String = "res://scenes/props/radio.tscn"
## Drop a diegetic field radio near the TOC spawn so the player boots to the broadcast.
func _stamp_radio(near: Vector3) -> void:
    ...
    var spot: Vector3 = near + Vector3(1.5, 0.0, 0.0)
```

Called once, at `site_planner.gd:922`, inside the main-firebase stamp. **The world contains exactly
one radio, 1.5 m from the player's boot spawn.** `radio_prop.gd:7` sets `hear_distance: float = 25.0`
→ `_player.max_distance = hear_distance` (`:48`).

The core loop (ADR-029) is: **boot at `fsb_main` → out the wire gate → patrol → come back.** So the
radio is audible for the first minute of the session and again when the player returns. **The entire
middle of the session — the patrol, which is the game — happens outside the bubble.**

Meanwhile the `AudioStreamPlayer3D` keeps playing while inaudible: Godot does not pause a 3D voice
beyond `max_distance`, it attenuates it. `_on_finished` (`:66-68`) keeps advancing the cursor in real
time. So the playlist runs the whole patrol with nobody listening.

**Combine that with the table above.** The player boots into whatever is playing. If it is GOOD
MORNING he has a 72-minute window in which to hear no music at all; a typical patrol departs and
returns inside that window. **A realistic estimate is that a player can complete several full
sessions without ever hearing a single folk song.**

That is not an argument against Ruling #1 or #4 — "organic and discovered" is precisely served by
music being rare and unscheduled. **It is a warning about expectations.** If the folk LP is
integrated and then judged by "did the radio feel musical," the honest answer will be *no*, and the
cause will be arithmetic and geometry, not the interleave code.

Two things follow that do **not** violate any ruling:
- **The music-scarcity problem is a PLACEMENT problem, not a playlist problem.** More radios (a
  village hootch, a VC camp, an ARVN post) multiply the chance of stumbling into music without
  touching a single broadcast byte, and "you found a radio playing in a hut" is *maximally*
  discovered. Ruling #4 constrains the files; it says nothing about how many props exist.
- **Interleave state must be per-prop, not global**, if more radios ever appear.

### 3b. Shuffle plus interleave is not what the current code does

`radio_prop.gd:43-44` shuffles ONE flat array; `_on_finished` walks it modulo its size. A 3:1
interleave needs **two independent lists with two cursors**. Merging music and broadcasts into one
shuffled array produces runs — four songs, then two broadcasts back to back — which is neither the
ruling nor "organic." Naming it because the one-line fix (`_tracks.shuffle()`) looks like it already
solves ordering, and it does not.

### 3c. The playlist restarts on every world load

`_ready()` → `_start()` → `_cursor = 0` (`:59`). Combined with `shuffle`, every fresh session starts
at a random track's **beginning**. The player who boots into a 72-minute broadcast hears the same
"GOOD MORNING VIETNAM" opening seconds every time it is drawn. That undercuts "organic and
discovered" more than any ratio does. A random *start offset* would fix it — but Ruling #4 forbids
start-offsets on broadcasts. **The music tracks are not covered by that ruling** and can start
mid-track; this is the one lever available that does not touch the broadcasts.

### 3d. The "no tracks" warning CANNOT FIRE once music is added — and this is the licensing trap's detonator

`radio_prop.gd:55-60`:

```gdscript
func _start() -> void:
    if _tracks.is_empty():
        push_warning("RadioProp: no .ogg tracks found in %s" % tracks_dir)
```

The guard checks whether **the whole list** is empty. The five broadcasts are tracked in git and will
always be present. **Therefore, on a fresh clone with the music gitignored, `_tracks` is not empty,
the warning does not fire, and the radio plays broadcasts forever with zero indication that an entire
layer is missing.** Ruling #4 also forbids any UI or telegraph — so there is no in-game signal
either, by design.

This is §1b happening a second time, in the same session, in the same subsystem. The **music list
needs its own emptiness check with its own warning**, or the absence is undetectable by anyone
without the owner's disk.

### 3e. `.ogg`-only filter: the folk LP is **14 mp3s**

`radio_prop.gd:37`:

```gdscript
if not dir.current_is_dir() and fname.get_extension().to_lower() == "ogg":
```

The briefing says **"Vietnamese folk music LP (14 mp3s)."** Dropped in as-is, **every one is silently
skipped** — and per §3d the warning cannot fire because the broadcasts fill the list. The radio would
play exactly as it does today, the integration would look "done," and nothing anywhere would say
otherwise. Either transcode to `.ogg` or extend the filter — but note this is **the single most
likely way this job ships broken while appearing to succeed**, and it is one string comparison.

---

## 4. STEREO IN A 3D VOICE — the mechanism, and why it will not be caught in testing

`audio_manager.gd:77-88`, the pool:

```gdscript
for i in range(GUNSHOT_VOICES):          # 24
    var p := AudioStreamPlayer3D.new()
    p.max_distance = 350.0
    p.unit_size = 16.0
    p.attenuation_filter_cutoff_hz = 5000.0
```

`AudioStreamPlayer3D` positions a **point source**. Its whole model is: one signal, attenuated and
panned by the listener-relative vector. A **two-channel** stream is not a point source — it is a
pre-baked stereo image with its own left/right decorrelation from the recording room.

What actually goes wrong, in order of likelihood:

1. **Phase cancellation / thin, hollow reports.** The two channels of a room-mic'd gunshot carry
   *different early reflections*. When the 3D path collapses them toward a single positioned source,
   those decorrelated reflections partially cancel. The result is a shot that is quieter, thinner and
   phasier than the file sounds in any audio editor. **It will not read as "broken" — it reads as
   "the new guns sound weak,"** which invites exactly the wrong fix (turn up `fire_volume_db`,
   which amplifies the cancellation artefact along with the shot).
2. **Localisation smear.** The baked stereo width fights the positional pan. A shot from an NPC on
   the player's hard left arrives with the file's own right-channel content still in the right ear.
   In a game whose Pillar 1 is believable firefights, **"which direction was that from" is the single
   most important thing a gunshot communicates.** Degrading it degrades the pillar directly.
3. **Cost.** 24 voices decoding 2-channel data instead of 1 is roughly double the mixer work in the
   worst case (a firefight — precisely when the frame budget is already worst). Given the standing
   perf pressure (Forward+ decree, 14→23 fps history), this is not free.

**It is silent.** No error, no warning, no test. `_try_load` (`:111-114`) only checks existence. There
is no channel-count assertion anywhere in the codebase.

**The mitigation is cheap and must be mandatory:** the WAV importer exposes `force/mono`. Every
weapon `.wav` `.import` must carry it, or — better, because it removes the possibility of forgetting
— **the files must be converted to mono 48 kHz on disk before import**, matching the existing mono
48 kHz bank exactly. That is one `ffmpeg -ac 1 -ar 48000` per file.

**And it must be verified by a probe, not by ear.** Per ADR-015 and the standing lesson *"every rig
MUST have a probe that EXERCISES it"*: a test that walks
`assets/audio/sfx/weapons/*.wav`, reads the RIFF header, and **fails on any channel count ≠ 1**. It
is a dozen lines, it runs headless, and it makes this entire class of defect impossible to
reintroduce. Without it, the next person to drop a "better" recording in re-breaks it in silence.

**Note the asymmetry that makes this a trap:** the 2D player path (`_p_near`, `_p_tail`, `_p_mech`,
`_p_dist` — `AudioStreamPlayer`, `:97-101`) handles stereo *correctly and pleasingly*. **Your own gun
will sound great. Everyone else's will sound wrong.** A tester firing his own weapon will approve it
100 % of the time.

---

## 5. WHAT ELSE SILENTLY BREAKS

### 5a. Failure is silent by design — the header says so

`audio_manager.gd:10-12`: *"Missing files fall back to a class bank (rifle/smg/pistol) so partial
coverage never crashes."* `_fallback_for` (`:143-149`) sends anything that isn't `1911`/`pistol`/
`ppsh`/`smg` to `"rifle"`. **A single typo in a filename produces a weapon that sounds like a generic
rifle and reports nothing.** With 16 ids × 5 conventions there are ~80 filenames to get right.
Convention resolution + silent fallback = **a swap that can be 30 % complete and look 100 % complete.**

Mandatory: a probe that, for **every `data/weapons/*.tres` id**, asserts `fire_<id>_1..3` and
`fire_<id>_dist` resolve — i.e. that `_fire_variants()` returns non-empty and `_dist_stream()` is
non-null. Run it now, before the swap, and it immediately red-flags `m14`, `m70` and `shotgun`.

### 5b. `.wav` is hardcoded — a dropped `.ogg` is invisible

`:127` `"fire_%s_%d.wav"` · `:138` `"%s_%s.wav"` · `:211` `"fire_%s_dist.wav"` · `:313` explosions.
**Every path is `.wav`.** Real recordings often arrive as `.wav` (fine) but the moment anyone
compresses one to `.ogg` to save space, it resolves to nothing and falls through to the rifle bank
without a word. Worth a line in the header comment at minimum.

### 5c. `tail_<id>.wav` is an undocumented convention with zero files

`:280` `var tail: AudioStream = _single(wid, "tail")` — measured: **zero `tail_*` files exist.** The
header comment (`:5-10`) documents `fire_`, `mech_`, `reload_`, `bolt_` and **not** `tail_`. So an
entire supported layer is invisible to anyone reading the documentation, and the fallback branch
(reuse the near stream at 0.72 pitch) is the only path ever taken. Under COMMENT DISCIPLINE this is
the *legitimate* kind of comment — a convention contract the code cannot show — and it is missing.
**This audio job is the moment to add it**, since the pack's Full Sound layer is the obvious first
real `tail_` candidate and would remove the pitched-down-copy hack in §2b entirely.

### 5d. `_p_mech` is one slot serving three layers — long real recordings will cut each other off

`_p_mech` is used by the mech layer in `play_shot_player` (`:274-276`), by `play_bolt_player`
(`:290-297`), and by `play_reload_player` (`:300-307`). One `AudioStreamPlayer`; assigning `.stream`
and calling `play()` kills whatever was there.

Today's placeholders are short (`reload_ak47.wav` = **2.4 s**, `bolt_mosin.wav` = **1.5 s**).
**Authentic reload/cycling recordings are typically longer and more detailed** — that is the whole
appeal of the pack. Every shot fired during a reload truncates the reload audio; on a bolt gun, the
`bolt` and `mech` layers collide on the same slot within the same cycle. This is pre-existing, but
**the pack makes it audible for the first time.** ADR-018 already touched reload timing; if the new
reload assets are longer than the animation, they are cut mid-file with no warning.

### 5e. 48 kHz vs 44.1 kHz across one bank

Existing bank: **48 000 Hz** (measured). Pack: **44 100 Hz** (briefing). Godot resamples, so nothing
breaks — but a partially-swapped bank straddles two rates, and any weapon that keeps its placeholder
per the "keep the placeholder" clause stays at 48 k. Combined with `pitch_scale` jitter
(`fire_pitch_variance`, `:224`) the resampling quality difference is another way a derivation can
sound subtly worse than its neighbour for reasons nobody traces to the file. Normalise to 48 kHz on
conversion — same `ffmpeg` pass as the mono fix.

### 5f. The radio loads ~96 MB of Ogg during worldgen

`_load_tracks()` (`:30-45`) calls `load()` on **every** file in the directory inside `_ready()`, and
`_ready()` fires when `_stamp_radio` adds the node **during firebase stamping** — mid-worldgen, on
the main thread. Ogg Vorbis streams are held compressed in memory, so ~96 MB resident today; adding
14 mp3s pushes it higher, and `AudioStreamMP3` also holds the full compressed buffer. **A 42 MB
single file is a real allocation spike at the worst moment.** Not fatal, but it is a load-time cost
that grows with every track added, and the growth is invisible until someone profiles worldgen.

### 5g. Hard cutoff at 25 m

`max_distance = 25.0` with `unit_size = 6.0` (`:48-49`). Godot's `max_distance` is a **hard cull**,
not a fade. A player pacing the wire around the 25 m boundary gets music popping in and out. Minor
today because broadcasts are speech; **music makes an abrupt cut far more noticeable.**

### 5h. Headless: the radio has no `_headless` guard

`audio_manager.gd:58-67` carefully no-ops under the headless display server — *"the test suite stays
silent and fast."* `radio_prop.gd` has **no equivalent guard**. Any headless test that stamps a
firebase constructs the radio and `load()`s 96 MB of Ogg. Given the current suite baseline (101/18/14
with 14 reds) and the standing perf sensitivity, this is worth a two-line fix while the file is open.

### 5i. `assets/audio/vo/` is already gitignored — a third precedent, and this one is honest

`.gitignore:23-24`: *"generated voice-over wavs (regenerated from voice_studio.py)"*. This one is
**correct**, and it shows what a good rule looks like: the reason is stated, and the recovery path is
named and real (a script in the repo). The folk-music rule can never say that — **the files are
unrecoverable to anyone but the owner.** Which is precisely why its comment must say *that*, loudly,
instead of imitating the shape of a rule that has a recovery path.

---

## THE LEDGER — what is sacrificed, plainly

| Decision | What it buys | What it costs |
|---|---|---|
| Gitignore the folk LP | Public repo stays clean of a commercial LP | Every clone silently plays a broadcast-only radio. No warning today (§3d). Inconsistent with 96 MB of broadcasts already tracked (§1a) |
| Real gun stock over synth | Authentic transients, provenance | Baked range acoustics under jungle canopy; one take × 3 variants; stereo→3D degradation; a bank straddling two sample rates |
| Exact caliber match as the organising principle | Defensible, honest sourcing | **AK and RPD become the same weapon to the ear** — a Pillar-1 tactical information loss the player pays for and can never hear the benefit of |
| 3 : 1 by count | Simple rule, broadcasts stay whole | **21.7 % music by time at the mean; 11.1 % worst case.** The stated ratio is inverted in practice (§3) |
| Broadcasts whole, no telegraph (Ruling #4) | Genuine easter eggs, organic discovery | Up to 72 minutes between songs; combined with a single 25 m radio at the spawn, a player may finish sessions having heard no music at all (§3a) |

## THE FIVE THINGS THAT MUST NOT SHIP WITHOUT A FIX

1. **Correct the weapon list in Ruling #2.** car15/sks/thompson/kar98k/mp40 are RETIRED
   (`tests/test_flat_damage.gd:31`) and a probe fails on them. Redirect that budget to **m14** and
   **m70**, which are live and have no fire audio at all. Delete the ~30 fossil wavs.
2. **Force every weapon `.wav` to mono 48 kHz, and add a header-reading probe that fails on ≠1
   channel.** Otherwise the 3D voice pool degrades silently and only NPC guns are affected — the one
   case testing never covers.
3. **Give the music list its own emptiness warning in `radio_prop.gd`**, and **ignore the music
   directory wholesale (media *and* `.import`)**. Then `git rm --cached
   assets/audio/ambience/jungle_day.mp3.import`, which is the same bug already shipped.
4. **Fix the `.ogg`-only filter** (`radio_prop.gd:37`) or transcode the 14 mp3s. As written, the
   entire music feature is a no-op that reports success.
5. **Correct `.gitignore:27`** — it cites retired bead `xu94`. We are editing this file; DRIFT says
   correct it on contact.

## THE ONE THING I WOULD ASK THE SUMMONER

Not a re-litigation of any ruling — a question none of them answers:

> **The AK-47 and the RPD both fire 7.62x39, and the RPD does 42 damage to the AK's 27. Should they
> sound the same?** Exact-caliber sourcing says yes. Pillar 1 says a soldier identifies an MG by ear
> before he sees it, and at range the far-shooter throttle has already flattened their rate of fire,
> so timbre is the last cue left. **If they share a sample, the player loses the ability to tell a
> machine gun from a rifleman.**
