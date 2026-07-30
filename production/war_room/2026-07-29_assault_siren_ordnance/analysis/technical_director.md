# TECHNICAL DIRECTOR — siege siren + upgraded explosion/heavy-weapon audio

Engine and architecture consequences. Every claim carries a `file:line` pointer or names the probe
that produced it (POINTER LAW). Measured 2026-07-29 against the working tree.

The prior occupant of this file (ADR-026 "PS2 budget", 2026-07-16) was moved to
`production/war_room/archive/2026-07-16_ps2_budget/analysis/technical_director.md`.

---

## 0. What I measured (so nothing here is a reading)

One throwaway `SceneTree` probe was run headless against `SitePlanner.FSB_MAIN_PATH`
(`scenes/world/firebase_main.tscn`) and then deleted. Its output is the ground truth for §3:

```
[TOWER] fb_tower_i             MeshInstance3D  local -77.1, 2.3,  -4.2
[TOWER] fb_tower_i_001         MeshInstance3D  local -43.7, 3.2,  48.1
[TOWER] fb_tower_i_002         MeshInstance3D  local  72.0, 2.6, -23.2
[TOWER] fb_tower_i_003         MeshInstance3D  local -26.0, 3.4, -57.3
[TOWER] fb_tower_i_178..181    StaticBody3D    (the four -colonly hulls, same XZ)
[TOWER] tower_los_point        Node3D          local -77.1,11.2,  -4.2
[TOWER] tower_los_point_0012   Node3D          local -77.1,11.2,  -4.2   <-- DUPLICATE
[TOWER] tower_los_point_001    Node3D          local -43.7,12.1,  48.1
[TOWER] tower_los_point_002    Node3D          local  72.0,11.5, -23.2
[TOWER] tower_los_point_003    Node3D          local -26.0,12.3, -57.3
```

All ten are **flat children of the `fsb_main_v3` root**, present in the instantiated scene tree.
Nothing is merged away. Note the runtime names: glTF import turns Blender's `.001` into `_001`, so
`fb_tower_i.001` is `fb_tower_i_001` at runtime — never search for the dotted form.

---

## 1. THE VOICE POOL RISK — what actually happens to the mix during a siege

### The pool, as built
24 `AudioStreamPlayer3D` (`audio_manager.gd:21`, built `:78-89`), plus a separate 6-voice step pool
(`:98-112`) that deliberately cannot evict gunfire, plus 4 never-stolen 2D player slots (`:148-159`).

### The arbitration, as written
- `_acquire_voice` (`:291-310`): idle voice first; otherwise steal the lowest-`_voice_prio` voice that
  is **not** transient-locked (`TRANSIENT_LOCK_MS = 60`, `:22`); steal only if `mine >= best_prio`;
  otherwise **return −1 and drop the shot silently** (`:310`).
- Gunshot priority is `1000.0 / (1.0 + d)` (`:287`) — near beats far, monotonically.
- Explosion priority is `1e6` (`:387`), and if `_acquire_voice` returns −1 the explosion **hard-takes
  voice 0 anyway** (`:376-378`), bypassing the transient lock.

### The three answers

**(a) Explosions starve gunfire, categorically — not the other way round.** `1e6` is above every
possible gunshot priority (max 1000 at d=0), and the `idx = 0` fallback means an explosion is
*incapable* of being dropped. Today each explosion holds a voice for **2.8 s** (measured:
`explosion_grenade.wav` = 48 000 Hz mono 16-bit, 2.8 s, 268 844 B). A mortar volley is **3 shells
fired in one frame** (`siege_director.gd:50` `MORTAR_VOLLEY = 3`, loop `:284-287`) on a 20–25 s cadence
(`:270`) for up to 480 s (`:40`). Steady state during a siege is therefore **3 of 24 voices (12.5%)
pinned by the volley alone**, before RPGs, satchels, grenades and `ambient_war`'s own arty
(`ambient_war.gd:55-70`). Lengthen the tail to 6 s and the same volley pins those three voices for
more than twice as long, and consecutive volleys begin to overlap.

I checked the obvious follow-on and it is **not** a bug: `_voice_prio` is never cleared when a voice
finishes, but step 1 of `_acquire_voice` returns any non-playing voice before step 2 is reached, so a
stale `1e6` is only ever read off a voice that is genuinely still playing. No staleness defect.

**(b) The transient lock is the real cliff, and it is arithmetic, not opinion.** If more than 24
shots are issued inside any 60 ms window, **every** voice is transient-locked, `best` stays −1, and
every further shot in that window drops. 24 shots / 60 ms = **400 rounds/s**. `LIVE_CAP = 50`
(`siege_director.gd:36`); AK/RPD/M60 at 550–650 rpm is ~10 rounds/s each, so **~40 men on automatic
saturates the lock**. The assault is authored to put exactly that many men on one 60° sector
(`:19`, `:36`). **The siege is the one scene in this game that reaches the cliff.**

Two throttles blunt it and neither closes it: `play_shot_3d` culls beyond `audio_max_distance`
(`:234-236`) and throttles far shooters to one shot per 70 ms (`:25`, `:241-245`) — but the throttle
key is `int(pos.x) * 73856093 ^ int(pos.z) * 19349663` (`:239`), i.e. **keyed to a whole-metre
position, not to a shooter**. A charging man crosses metre boundaries several times a second, so the
throttle leaks exactly when the men are moving, which during an assault is always.

**(c) A `-1` return is INAUDIBLE, and that is worse than clipping here.** The comment at `:310`
("silence beats a clipped transient") is right for one shot and wrong for a siege: the artifact is
**men visibly firing with no sound**, and it lands preferentially on the far ring (300–500 m,
`siege_director.gd:20-21`) because priority falls as `1/d`. The mass attack thins acoustically at the
exact moment the volley lands.

### The unbudgeted second path (this is not in the 24)
`GunFX.impact()` creates a **fresh, uncapped** `AudioStreamPlayer3D` per bullet impact
(`gun_fx.gd:518-526`) — the `MAX_IMPACTS` cap at `:490` guards only the particle visual, and the audio
node is created *outside* that `if`. `gun_fx.gd:621-628` does the same per flesh hit. At siege peak
that is dozens of `new()` + `add_child()` + signal-connect + `queue_free()` per second on the main
thread, entirely outside AudioManager's budget. **If we are touching heavy-weapon audio, this is the
path that will hurt, not the siren.**

### Prescription (voice pool)
1. **Reserve an explosion sub-pool.** 4 dedicated voices, exactly as `_build_step_pool` (`:104-112`)
   already reserves 6 for footsteps and for the same stated reason. Explosions then cannot evict
   gunfire and gunfire cannot evict explosions. This is the one change that makes longer tails safe.
2. **Raise `GUNSHOT_VOICES` 24 → 32** (`:21`). The frame is call-bound/GPU-bound
   (`PERF_LEDGER.md:698`, `:704`); mixing voices live on the audio thread. Eight more voices raises
   the lock cliff from 400 to ~530 rounds/s.
3. **Key the far-shooter throttle to the shooter, not to the metre** (`:239`) — pass the emitter's
   `instance_id`. Free, and it restores a throttle that currently stops working under movement.
4. **Cap the per-impact node churn** at `gun_fx.gd:518` behind the same `MAX_IMPACTS` gate the visual
   uses, or route impacts through a small pooled bank.

---

## 2. THE SIREN — correct architecture

### It must not touch the one-shot pool. Stated as a rule
The 24-voice bank is a **transient allocator**: it steals, it drops (`:310`), and it rewrites
`stream` / `max_distance` / `unit_size` on every acquisition (`:279-285`). A looping, always-on source
in that bank would be stolen mid-wail by the first explosion (`1e6` beats everything), and would
itself occupy a voice for the whole siege. Both directions are wrong. **Dedicated nodes, owned by the
firebase, are the only correct shape.**

### The nodes
Four `AudioStreamPlayer3D`, one per tower, seated at the `tower_los_point` markers — head height
~11.2–12.3 m local, the right emitter height for a siren and free line-of-sight falloff over the berm.

```
stream                        = AudioStreamWAV, loop_mode set IN THE .import SIDECAR (see §4)
bus                           = "Alarm"                (new; see below)
attenuation_model             = ATTENUATION_INVERSE_DISTANCE
unit_size                     = 60.0
max_db                        = 0.0        # default is +3.0 — clamp the near-field boost
volume_db                     = -2.0
max_distance                  = 900.0
attenuation_filter_cutoff_hz  = 2000.0     # the low howl carries; the top end does not
attenuation_filter_db         = -24.0
doppler_tracking              = DOPPLER_TRACKING_DISABLED
max_polyphony                 = 1          # one continuous source, never retriggered
```

**Why those numbers.** Inverse-distance gives −20·log10(d / unit_size) dB. With `unit_size = 60`:
0 dB at 60 m, **−16.5 dB at 400 m, −20 dB at 600 m**, −23.5 dB at 900 m where `max_distance` cuts it.
Against the shipped beds — jungle at −14 dB (`game_world.gd:284`), distant war at −20 dB (`:297`),
night insects at −12 dB (`:389`) — the siren sits *above* the bed at 400 m and *level with* it at
600 m. That is "audible through jungle at 400–600 m" without being a wall of sound.

At the tower base the naive inverse curve would add +12 dB. **`max_db = 0.0` is what stops it being
deafening** — Godot's default `max_db = 3.0` lets a source boost above `volume_db` inside `unit_size`.
Result: the base reads at `volume_db` = −2 dB, loud and diegetic, not clipped. This is the single most
important property line here and the one most easily forgotten, because it is a *clamp*, not a level.

**Do not stack four full-level sirens.** The towers are only ~150 m apart at the widest (measured:
(−77.1, −4.2) to (72.0, −23.2) = 149 m). Standing in the compound the listener is inside `unit_size`
of all four, so four sources sum to roughly +6 dB over one. Either drop `volume_db` to −8, or
(better) **detune each tower** — `pitch_scale` 0.97 / 0.99 / 1.01 / 1.03 plus a per-tower phase offset
via `play(randf() * length)`. The beating between four slightly detuned sirens is also the correct
period sound.

### The bus — a new one, and NOT the two obvious candidates

**Do not put it on `Weapons`.** That bus carries an `AudioEffectCompressor`, `threshold = -12.0`,
`gain = 3.0`, `release_ms = 120` (`assets/audio/default_bus_layout.tres`, sub-resource `comp`, applied
at `bus/2/effect/0`). A *sustained* loud source on a compressor tuned for transients holds the gain
reduction down permanently and **pumps every gunshot in the game** for as long as the siren runs.
This is the worst available choice and it is not visible from reading the GDScript.

**Do not put it on `Ambience`.** `duck_ambience()` (`audio_manager.gd:397-402`) writes an **absolute**
volume onto the Ambience bus (`base - DUCK_DB`, 8 dB) on **every player shot** (`:345`) and every
explosion (`:389`, 260 ms hold), then ramps back in `_process` (`:409-420`). A siren on Ambience would
be ducked 8 dB by the very gunfire it is announcing — quiet precisely when it matters. It would also
fight `GameSettings.ambience_volume_db` (`game_settings.gd:41`), which is the user's *ambience*
slider, not an alarm slider.

**Prescription: add `Alarm`, sending to `SFX`.** SFX already sits under the user's `sfx_volume_db`
(`game_settings.gd:40`) and under the Master limiter (`bus/0/effect/0`), so the siren is
volume-controlled and cannot clip the master. `Alarm` carries no effects of its own. Append it to
`assets/audio/default_bus_layout.tres` as `bus/10` — appending keeps every existing index stable, and
`AudioManager._bus()` resolves by *name* with a fallback (`:71-75`), so nothing breaks either way.
Do not renumber.

**Reuse candidate rejected:** bus `World` (`bus/5`) exists in the layout and has **zero code
references repo-wide**. It is a fossil (§6). Do not adopt a fossil as the siren's home — delete it and
add `Alarm` with a name that says what it is.

### The duck, inverted
The siren should **duck the ambience**, not be ducked by it. `AudioManager.duck_ambience()` is the
wrong tool (a 160 ms transient hold). On siren start, drop the Ambience bus a sustained ~6 dB using
the same `GameSettings.ambience_volume_db`-relative arithmetic (`audio_manager.gd:401`) and restore on
stop — **but whatever writes it must go through one owner.** Today `duck_ambience` and
`GameSettings._set_bus` both write that bus volume absolutely; a third writer is how a bus ends up
stuck 8 dB down for the rest of the session. If the siren ducks, `AudioManager` owns the arithmetic,
exactly as it owns the transient duck.

---

## 3. WHERE IT GETS INSTANTIATED AND TORN DOWN — the traced live path

### Are the towers addressable at runtime? **YES. Verified, not assumed.**
Measured in §0: four `fb_tower_i*` `MeshInstance3D`, four `-colonly` `StaticBody3D`, and five
`tower_los_point*` `Node3D` markers, all live children of the instantiated `fsb_main_v3` root. The
firebase is instantiated whole at `site_planner.gd:1038-1044`:

```
1038  var scene: PackedScene = load(FSB_MAIN_PATH)
1039  var root := scene.instantiate() as Node3D
1041  _parent.add_child(root)
1044  root.global_position = origin
```

Nothing merges or strips markers. `_repair_glb_colliders` (`:1103`) only removes and re-meshes
`fb_veg_*` / `fb_sbg_seg_*` `StaticBody3D`s (`:1099`); it never touches `Node3D` markers, and it
explicitly *keeps* `fb_terrain_mound` (`:1120-1126`).

### THE PRECEDENT ALREADY EXISTS — copy it
`site_planner.gd:1049`: `var ladders: int = Ladder.build_from_markers(root)`, run **after** the root is
seated (comment `:1047-1048`: *"Ladder caches world positions off the markers, so building before the
move would bake them at the wrong height"*). `Ladder.build_from_markers` (`scripts/world/ladder.gd:37-54`)
walks the tree, collects nodes by **name prefix**, and builds real nodes. **That is exactly the shape
the siren wants, and the same ordering constraint applies** — build after
`root.global_position = origin` at `:1044`, or every siren is at the wrong altitude.

### THE MARKER DEFECT you will walk into
`tools/gen_firebase_v3.py:726` renames `tower_los_point_001` → `tower_los_point`. The GLB therefore
carries **five** markers for **four** towers: `tower_los_point` and `tower_los_point_0012` are the
*same point* (−77.1, 11.2, −4.2 — both on tower #0). And `site_planner.gd:780` / `:796` key the
garrison sentry post off `"tower_los_point_001"`, which after import resolves to the marker at
(−43.7, 12.1, 48.1) — **tower #1, not the one the rename was aimed at.** It works (one sentry, one
tower) but it is not the tower anyone thinks it is.

**Consequence for the siren:** do NOT use `SitePlanner.FSB_MARKER_KEYS` / `_ensure_fsb_markers`
(`:854-894`) — that path is single-key `find_child` and yields one siren. **Scan by prefix
`"tower_los_point"` and dedupe by XZ position** (~1 m tolerance), which yields exactly four. Prefix
scanning also survives the next re-export, which is why `Ladder` does it that way.

### The trigger chain, end to end
```
SiegeDirector.open_siege()             siege_director.gd:142
  -> siege_began.emit(...)             siege_director.gd:164   (signal declared :56)
     -> FieldDirector._on_siege_began  field_director.gd:1274  (connected :1270)
        -> _garrison_stand_to()        field_director.gd:1275
SiegeDirector._break_siege()           siege_director.gd:335
  -> siege_ended.emit(...)             siege_director.gd:357   (signal declared :57)
     -> FieldDirector._on_siege_ended  field_director.gd:1285  (connected :1271)
        -> _garrison_stand_down()      field_director.gd:1294
```

### THE EXACT WIRING POINTS

- **Build the sirens:** `scripts/world/site_planner.gd`, immediately after
  `Ladder.build_from_markers(root)` at **`:1049`**, before the gate metrics at `:1052`. Same
  post-seat ordering, same prefix-scan idiom.
- **Publish the handle:** the site dict at **`site_planner.gd:1061-1063`** already carries
  `"nodes": [root]`. Cleanest API: parent the four players under one `Node3D` named `Sirens` under
  `root`, so `root.get_node_or_null("Sirens")` is the entire interface and nothing new is threaded
  through the dict.
- **Reach it from the director:** `FieldDirector.setup_patrol(built)` at **`field_director.gd:986-1008`**
  is the one place the built site list arrives; `built.sites` holds the `firebase_main` entry with
  `nodes[0]` = the root. Cache the `Sirens` node there, adjacent to `_attach_siege()` at **`:993`**.
- **Start:** `field_director.gd:1274-1279`, in `_on_siege_began`, next to `_garrison_stand_to()`.
- **Stop:** `field_director.gd:1285-1294`, in `_on_siege_ended`, next to `_garrison_stand_down()`.
  `_on_siege_ended` fires on **every** exit path — `"broken"`, `"wiped"`, `"dawn"`
  (`siege_director.gd:204, 208, 212`) — so there is no route where the siren outlives the siege.
- **Teardown:** the players are children of the firebase root, itself a child of the world; world
  teardown frees them. The director's cached reference **must** be `is_instance_valid`-guarded — the
  suite treats `"previously freed"` as **fatal** (`run_all_tests.ps1:83-85`).

### Which scenes can actually exercise it
- **`demo_game.gd` — YES.** `GameFlow.demo_mode` → `plan_demo_world` (`mission_generator.gd:654`) →
  `build_patrol_world` (`:733`), the same builder that runs the `site_planner` firebase stamp.
  `demo_game.gd:129 _open_siege()` drives `siege.open_siege(strength)` at `:151`.
  **This is the only live probe.**
- **`ai_stress_arena.gd` — NO.** Its `_build_firebase()` (`:734-751`) is six hand-placed sandbag
  walls, two fighting holes and a platform. There is no `fsb_main_v3`, no tower, no marker. The
  arena's `[J]` siege (`:1501-1507`, wired `:1425-1439`) will run with **no siren at all**. Per the
  arena-sterile ruling that is correct and must not be "fixed" by hand-adding a tower to the bench —
  but it does mean **the arena cannot validate this feature.**

---

## 4. EXPLOSION AUDIO — memory, import, and the PCM/OGG question

### Measured today
| file | rate | ch | bits | length | disk | imported PCM |
|---|---:|---:|---:|---:|---:|---:|
| `explosions/explosion_grenade.wav` | 48 000 | 1 | 16 | **2.80 s** | 268 844 B | ~268 800 B |
| `explosions/explosion_40mm / _heavy / _rocket` | same | same | same | same | same | same |
| `sfx/explosion.wav` (legacy) | **22 050** | 1 | 16 | **0.90 s** | 39 734 B | ~39 700 B |

Four explosion renders resident = **~1.05 MB**. All four are `compress/mode=0` (PCM), written by
`gen_weapon_audio.py:328 write_import()`, which hardcodes `compress/mode=0` at **`:349`** with the
comment *"PCM: these are short, and the transient is the point"*.

### The cost of what is being proposed
Straight-line arithmetic at 48 kHz mono 16-bit = **96 000 B/s**:

| change | files | length | resident PCM |
|---|---:|---:|---:|
| today | 4 | 2.8 s | 1.05 MB |
| longer tails only | 4 | 6.0 s | **2.25 MB** |
| + distant variants | 8 | 6.0 s | **4.50 MB** |
| + 3 near variants each (the `fire_*_1..3` round-robin convention) | 16 | 6.0 s | **9.00 MB** |

**RAM is not the problem — 9 MB is nothing on this target.** Three other things are.

**(a) There is no explosion stream cache, and this is a real defect.**
`play_explosion_3d` calls `_try_load(XPATH + kind + ".wav")` on **every single blast**
(`audio_manager.gd:371`), and `_try_load` (`:169-172`) runs `ResourceLoader.exists()` before `load()`.
Contrast the gunfire paths, which cache into `_fire_cache` / `_single_cache` (`:180-198`, `:265-271`).
`load()` hits the resource cache so the *data* is not re-read, but `ResourceLoader.exists()` is a
UID/filesystem probe on the **main thread, per explosion** — and the fallback branch at `:372-374`
runs a second one whenever the primary is missing. A 3-shell volley × three variants × a per-blast
miss is exactly the shape that reads as a hitch. **Cache explosions by `kind`, same as
`_single_cache`, BEFORE adding any new variants.** Adding 12 more files without this multiplies the
miss surface twelvefold.

**(b) The voice-hold time doubles.** Per §1: 2.8 s → 6.0 s at priority `1e6`. **Do not lengthen tails
until the explosion sub-pool exists.** This is the hard sequencing constraint in this brief.

**(c) The import format decision.**

**Recommendation: transients stay PCM; long tails and the siren move to IMA-ADPCM
(`compress/mode=2`), not OGG.** In order:

1. **The codebase already does this.** `jungle_loop.wav.import` is `compress/mode=2` and it is the
   longest resident loop in the game. There is a working precedent; OGG has none in `sfx/`.
2. **ADPCM keeps the resource type `AudioStreamWAV`.** Everything that loops here does
   `stream.loop_mode = AudioStreamWAV.LOOP_FORWARD` on a loaded WAV (`game_world.gd:276`, `:292`,
   `:384`; `mission_weather.gd:127`; `spectre_gunship.gd:75`; `main_menu.gd:100`). Switching to
   `AudioStreamOggVorbis` changes the type and every one of those idioms becomes a type error waiting
   to be copy-pasted wrong.
3. **4:1 memory** at negligible decode cost: 9 MB → ~2.3 MB.
4. OGG's advantage over ADPCM is quality-per-byte on a *decaying noise tail* — the one signal class
   where ADPCM artifacts are least audible. Not worth a second stream type.

**THE TRAP, and it is load-bearing.** Every loop site above computes the loop point as
`stream.data.size() / 2` (`game_world.gd:278`, `:294`, `:386`; `mission_weather.gd:129`;
`spectre_gunship.gd:77`; `main_menu.gd:101`). **That arithmetic assumes 16-bit PCM.** Under
`compress/mode=2` the `data` buffer is 4-bit-packed ADPCM and `size() / 2` is wrong by 4×. If the
siren WAV is imported compressed *and* the siren code copies this idiom, the loop point will be badly
wrong and it will look like a bad render rather than a bad divisor.

**Prescription:** set **`edit/loop_mode=1`** in the `.import` sidecar and never compute `loop_end` in
GDScript. `write_import()` already takes a `loop: bool` and emits `edit/loop_mode={1 if loop else 0}`
at `gen_weapon_audio.py:348` — **it just needs a `compress` parameter alongside it**, because
`compress/mode=0` is hardcoded at `:349`. Two lines, and the sidecar is the correct place for it: the
sidecar is what makes headless runs and exports work without opening the editor (`:330-332`).

---

## 5. HEADLESS SAFETY — every guard the siren must respect

`run_all_tests.ps1:121-123` launches `--headless --path <root> res://tests/<t> -- --test-save`.
Godot's `--headless` selects the **dummy display *and* dummy audio driver**, so nothing is audible;
the risks are hangs, leaks and error lines, not noise.

1. **`DisplayServer.get_name() == "headless"`** — the project idiom (`audio_manager.gd:59`, re-used
   at `game_world.gd:205`). The siren builder must check it and no-op. Build the *marker scan* if you
   like (pure `Node3D` maths, cheap); **do not create the players**, and never `play()`.
2. **Never `await player.finished` on a looping stream.** It never fires. A test that awaits it burns
   the whole `TimeoutSec = 420` box (`run_all_tests.ps1:16`) and reports exit 124 (`:129-131`) —
   indistinguishable from a hang.
3. **Stop and null on teardown.** `AudioManager._exit_tree` (`:440-449`) is the pattern: `stop()` then
   `stream = null` on every player. A live looping stream at exit produces
   `"resources still in use at exit"`, which `run_all_tests.ps1:91` classifies **BENIGN** — the test
   then reports **LEAK**, not PASS. That list must not grow (`:88-89`: *"Never add to this list to
   make a build green"*).
4. **`ResourceLoader.exists()` before `load()`** (`audio_manager.gd:169-172`). Audio assets have gone
   missing from clones before (`radio_prop.gd:138-149` exists entirely for this). A hard `preload` of
   a siren asset turns the *whole suite* red on a fresh clone; a guarded `load` degrades quietly.
5. **No `push_error`, and no warning line starting `WARNING: [NAV]`** (`run_all_tests.ps1:75-81`,
   matched with `.StartsWith()` on the trimmed line). A missing-tower `push_warning` is safe; an
   `ERROR:` is fatal to the build.
6. **`is_instance_valid` on every cached siren reference.** `"previously freed"` is an unanchored
   fatal substring (`run_all_tests.ps1:83-85`) — the commonest way a director-held node reference
   turns a green suite red at teardown.
7. **Do not touch `CampaignState`.** The suite passes `--test-save` precisely so tests do not write
   the owner's campaign (`run_all_tests.ps1:9-13`).
8. **Do not add a `Timer` or `_process` poll that runs when no siege is active.** `SiegeDirector`
   already polls at 2 Hz (`siege_director.gd:103-108`); the siren must be signal-driven, not polled.

---

## 6. FOSSIL LAW — audio corpses to bury in this change

`tests/fossil_baseline.json` currently reads `ceiling: 3, count: 3` and grandfathers only
`scripted_sequence.gd|signal|sequence_bark`, `model_actor.gd|func|ragdoll_bone`,
`model_actor.gd|func|wake_ragdoll`. **None of the items below is grandfathered** — the probe does not
see them, which is exactly the failure mode ADR-023 describes.

| # | fossil | pointer | live refs | verdict |
|---|---|---|---:|---|
| 1 | `GunFX.shot_stream_for()` | `gun_fx.gd:72-78` | **0 callers** repo-wide | **FOSSIL — delete.** Superseded by `AudioManager.play_shot_3d` (`gun_fx.gd:84`) delegating to the pooled, distance-layered path. |
| 2 | `SHOT_RIFLE` / `SHOT_SMG` / `SHOT_PISTOL` preloads | `gun_fx.gd:9-11` | referenced **only** by #1 | **FOSSIL — delete with #1.** Three preloaded 22 kHz placeholders resident for a dead function. |
| 3 | `GunFX.EXPLOSION` preload | `gun_fx.gd:15` | **0 consumers** (`play_explosion_3d` at `:119-121` delegates to `AudioManager`) | **FOSSIL — delete.** |
| 4 | bus `World` | `assets/audio/default_bus_layout.tres` `bus/5` | **0** code references | **FOSSIL — delete when `Alarm` is added.** Do not adopt it as the siren bus. |
| 5 | `assets/audio/sfx/wind_loop.wav` | generated by `gen_placeholder_audio.py:95` | **0** code references | **FOSSIL — delete asset + generator line.** |
| 6 | `assets/audio/sfx/explosion.wav` (0.9 s / 22 kHz placeholder) | `gen_placeholder_audio.py` output | **3**: `audio_manager.gd:373` (fallback), `ambient_war.gd:58` (**LIVE** — distant arty), `gun_fx.gd:15` (fossil #3) | **NOT yet a fossil — but it is the target.** The upgrade should give `ambient_war` a proper distant variant and retire this file; once `ambient_war.gd:58` and `gun_fx.gd:15` are repointed, `audio_manager.gd:372-374`'s fallback branch is the last reference and both die together. |
| 7 | `_load_fallbacks` / `_fallback_for` class bank (`shot_rifle/smg/pistol`) | `audio_manager.gd:162-167`, `:201-207`; used `:213, :256, :321` | **LIVE** | **KEEP — MISSING FEATURE, not a fossil.** `production/AUDIT_2026-07-28.md:105`: `car15`, `shotgun`, `m26_grenade` still have no dedicated render. Delete only when every weapon id has `fire_<id>_*.wav`. |
| 8 | dual footstep paths | `audio_manager.gd:95-97` (`step_dirt/grass/water`) vs `player.gd:239-240` (**`step_real.wav` for BOTH dirt and grass**) | both live | **DIVERGENT SYSTEM — flag, out of scope.** Two surface-to-sound mappings that disagree. Same audit, not caused by this work. |
| 9 | `tower_los_point` duplicate marker | `tools/gen_firebase_v3.py:726` | — | **EXPORT DEFECT — fix at source.** Five markers for four towers. Until fixed, the siren builder MUST dedupe by position (§3). |
| 10 | `gen_placeholder_audio.py` | `tools/` | generates 12 assets still loaded by live code | **NOT a fossil.** Live generator for the non-weapon SFX set (`jungle_loop`, `night_insects_loop`, `distant_war_loop`, `step_*`, `impact_*`, `dry_click`, `radio_crackle`, `rotor_loop`, `combat_sting`, `shot_distant`). |

**Note on the probe's blind spot, worth the Arbiter's attention:** items 1–5 are dead by grep and
none is in `fossil_baseline.json`. `shot_stream_for` is a `static func` whose three preloads are
"referenced" from inside its own dead body — **a dead function keeping three dead consts alive is the
same shape as the tombstone-comment defect ADR-023 already documents.** The fossil probe does not
currently catch a const referenced only by a dead function.

---

## 7. Perf statement, honestly bounded

Four extra always-on `AudioStreamPlayer3D` add four mixing voices and four per-frame listener/panning
updates. **No measurement is offered and none should be invented.** What the ledger does say: the
shipped patrol-world baseline is ~34 fps at scale 0.75 / Forward+ / seed 47225
(`PERF_LEDGER.md:683, 702`); the **only** lever above the noise floor is the canopy at +6.3 fps
(`:698`); and the frame is call-bound (`:704` — the canopy owns ~70% of draw calls while moving
primitives by ~0). Four audio voices are not in that league.

**The siren is not the audio risk in a siege. The risks are:** (a) 24 shared voices against a
400 rounds/s transient-lock cliff (§1b), (b) 3 explosion voices held 2.8 s and rising to 6 s
(§1a, §4b), (c) an uncached `ResourceLoader.exists()` per blast (§4a), and (d) an uncapped
`AudioStreamPlayer3D.new()` per bullet impact (`gun_fx.gd:518`). **All four predate this brief and all
four get worse under it.**

---

## 8. Sequencing — what must land before what

1. Explosion sub-pool + `GUNSHOT_VOICES` 24 → 32 (`audio_manager.gd:21`, `:78-89`, `:368-389`).
2. Explosion stream cache (`audio_manager.gd:371`).
3. `write_import()` gains a `compress` parameter (`gen_weapon_audio.py:328-352`).
4. **Only then** lengthen tails / add distant variants.
5. `Alarm` bus added, `World` bus deleted (`assets/audio/default_bus_layout.tres`).
6. Siren built at `site_planner.gd:1049` (prefix scan, dedupe by XZ), handle published on the site
   dict at `:1061`, cached in `field_director.gd:986-1008`, toggled at `:1274` / `:1285`.
7. Fossils 1–5 deleted in the same change (ADR-023).
8. `tools/gen_firebase_v3.py:726` fixed so the next export ships four tower markers, not five.
