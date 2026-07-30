# DEVIL'S ADVOCATE — the siren + explosion-synth + real-recordings plan

**Written 2026-07-29. Everything below is verified against code on disk; every claim carries a
pointer (POINTER LAW). Where I could not find a pointer, I say so — that is the finding.**
(This file previously held the 2026-07-16 ADR-026 analysis; superseded, archived in git history.)

Plan under attack:
1. Looping motor-driven air-raid siren on the 4 firebase watch towers, triggered by
   `SiegeDirector.siege_began`.
2. Rebuild the procedural explosion synth "for more weight".
3. Add real CC0/public-domain recordings as a curated layer beside the synth.

---

## 0. THE HEADLINE — the export preset ships every unlicensed byte on the disk

This is the single most dangerous thing in the repo, and this plan pours more audio into it.

`export_presets.cfg:9-11`:

```
export_filter="all_resources"
include_filter=""
exclude_filter="tests/*, art_source/*, tools/*, screenshots/*, *.md"
```

**Not one audio path is excluded.** Now read what is sitting inside `res://` right now:

- `assets/audio/ambience/jungle_day.mp3` — **55.8 MB**, and `.gitignore:27-28` says in its own words:
  *"55MB YouTube-sourced dev ambience - license-unclear, replace for release (bead xu94)"*.
  It is not a dead file: `scripts/levels/game_world.gd:269-273` **loads it at runtime** and prefers it
  over the synth bed. `game_world.gd:266-267` even carries the comment *"Dev asset, license unclear"*.
- `assets/audio/Radio Vietnam/music/` — **28 files / 14 tracks**, and `.gitignore:30-38` says:
  *"converted from the commercial LP 'Music of Viet Nam' (various artists). This repo is public and we
  hold no distribution right."* `scripts/props/radio_prop.gd:16` points the in-game radio straight at
  that folder.

`.gitignore` protects **the public GitHub repo**. It does **nothing** for a Godot export. Both of these
directories are inside `res://`, `export_filter="all_resources"` sweeps them into the `.pck`, and
`binary_format/embed_pck=true` (`export_presets.cfg:26`) welds them into the shipped `.exe`.

So the project's current state is: **the two assets whose licences were explicitly written down as
unsafe are both wired live into gameplay and both ship.** The team believed `.gitignore` was the
containment. It is not.

And the repo asserts the opposite in writing. `LICENSE:1-7`:

> *"This repository, including its source code, game design documents, art assets, **audio**, and all
> other original content, is proprietary."*

That sentence is **already false** and this plan makes it more false. Under the POINTER LAW / NO MORE
DRIFT rule (`CLAUDE.md:234-252`), a claim that is no longer true must be corrected on contact. This one
is not a stale comment — it is the legal claim the project makes about itself.

**Nothing about the siren or the explosion synth should be built before this is closed.** It is a
30-minute fix (an `exclude_filter` entry + a ledger) and it is the only part of this session that is
unambiguously worth doing today.

---

## 1. THE GATE — is this work parked?

`CLAUDE.md:395-402` is unambiguous:

> **PLAYTEST R4 is the standing session entry gate — resolve it FIRST, before anything else.** … *"It
> is discharged only by a verified playtest by the Summoner (ADR-015) — never by a probe, never by an
> agent's reading. Until he has verified it, gated feature work stays parked."*

Corroborated at `production/GAME_GUIDE.md:317` and `production/OVERSEER_CHARTER.md:95, 134, 150`
("Feature gate: ACTIVE"). I found **no record anywhere on disk of R4 being discharged.** The tracker
that held it (`bd`) is retired (`CLAUDE.md:385-393`), so the gate now has **no live status field at
all** — which means it reads as ACTIVE and must be treated as ACTIVE.

The charter names the exemptions (`OVERSEER_CHARTER.md:113`): *"bug fixes, presentation for
already-shipped systems, standing-decree items, and evidence-gathering probes/measurements."*

Ruling, item by item:

| Item | Verdict |
|---|---|
| **Export-filter / licence fix (§0)** | **NOT GATED.** Bug fix. Do it. |
| **Explosion synth rebuild** | **NOT GATED.** Presentation for an already-shipped system (`audio_manager.gd:368`; 4 renders already on disk). Legitimate — *if* it gets an acceptance gate (§5). |
| **The tower siren** | **GATED. This is a new feature.** No ADR, no line in `DEMO_SHIP_BACKLOG.md`, no line in `CALEB_TODO_7_22_updated.md`. It is not presentation for a shipped system; it is a new signal→node→audio path that does not exist. |
| **Real recordings as a new curated layer** | **HALF-GATED.** Replacing an existing synth render at an existing path is presentation (precedent: the 2026-07-27 gun-pack swap, `test_audio_pack.gd:1-11`). Adding a *new layer alongside* the synth is a new system. |

Against the standing decrees:

- **Period-HUD decree** — deferred to final polish, never a blocker. Not violated; irrelevant here.
- **DEMO ship gate** (his words, `DEMO_SHIP_BACKLOG.md:7-9`): *"More Hueys and jets flying around. At
  least a few Huey landings with troops disembarking… The base attack has parts of the base blow up.
  The VC attempt to overrun the firebase."* Ordered: **allies first, then the air spectacle, then
  everything else** (`DEMO_SHIP_BACKLOG.md:4-5`). A siren is not in A, not in B, not in C. **C2** —
  *"parts of the base must blow up… the wiring to the blast bus is the gap"* — is where this session's
  hours belong if the goal is the demo.
- **The one open AUDIO ask he actually made** is `DEMO_SHIP_BACKLOG.md` **D3**: *"Ambient war audio.
  One one-shot per event; a distant engagement should be a volley. His note: the fire rate should
  either be faster or a less occurring event."* This plan does not touch it. We would be building
  audio he did not ask for while the audio he *did* ask for stays open.

**Honest verdict, even though it kills most of the session: the siren is gated feature work with no
sponsor. Build §0, then D3, then C2. Ask him about the siren; do not build it on our own authority.**

---

## 2. THE REAL-RECORDING TRAP — an agent that cannot listen

The plan hands a deaf worker a download button. The existing pipeline already knows this and says so
out loud — `gen_weapon_audio.py:371-373`: *"report mode: numbers, because I cannot listen to these."*
That machinery (`spectral_report`, `_acceptance`) is **weapons-only** (`gen_weapon_audio.py:434-439`).
Nothing numeric guards explosions, ambience, or anything new.

`tests/test_audio_pack.gd` guards **only** `res://assets/audio/sfx/weapons/` (`:14`, `:79-91`). Drop a
file into `explosions/` or a new `sirens/` folder and **every check in this repo is silent.**

### Failure modes and the cheap numeric check that catches each

| # | Failure | Symptom in game | Cheap numeric check |
|---|---|---|---|
| 1 | **Stereo source in the 3D pool** | Phase-cancels and mislocalises — named in `test_audio_pack.gd:8-9` as a known bug class; caught at `:69-70` for weapons only | `wave.getnchannels() != 1` → reject. `audio_dsp.write_wav` is hardcoded mono (`audio_dsp.py:240-243`), so the whole synth library is mono and a stereo import is an instant mismatch |
| 2 | **Sample-rate mismatch** | Godot resamples; pitch survives, the transient smears | `getframerate() != 48000` → reject or resample. `test_audio_pack.gd:31,71-72` already demands 48000 for weapons. The *fallback* bank is **22050** (`gen_placeholder_audio.py:9`) — the library is already inconsistent |
| 3 | **Bit depth / float WAV / WAVE_FORMAT_EXTENSIBLE** | Godot's wav importer refuses or truncates | `getsampwidth() != 2` → convert. `write_import` hardcodes 16-bit PCM (`gen_weapon_audio.py:345-354`) |
| 4 | **3 s of silence then a bang at the end** | Explosion fires ~3 s late, forever, and reads as an engine lag bug | `argmax(abs(x))/sr > 0.05` → reject/trim; also `mean(abs(x[:0.25s])) < 1e-4` |
| 5 | **Trailing silence** | Voice held in the 24-slot pool (`audio_manager.gd:21`) long after it is inaudible; starves gunfire | duration to last sample above −60 dBFS; if `total − that > 0.3 s`, trim |
| 6 | **DC offset** | Cumulative thump, wasted headroom, click on start/stop | `abs(mean(x)) > 0.002` → high-pass at 20 Hz (free: `audio_dsp.highpass`) |
| 7 | **Loudness inconsistent with the synth library** | One real explosion 9 dB louder than the four synth ones; the mix falls apart | integrated RMS + true peak per file; require RMS within ±2 dB of the synth median. The synth normalises to a **known** peak (`normalize(out, 0.96)`, `gen_weapon_audio.py:307`); a download does not |
| 8 | **Crest-factor collapse (pre-mastered/limited source)** | "Loud" but no transient — mush | `_acceptance`'s own rule: `crest < 7 dB` → reject (`gen_weapon_audio.py:408-409`) |
| 9 | **Spectral tilt — all bass, no bite** | The "more weight" trap in one line: the render becomes a kick drum | `_acceptance` again: `low(40–250 Hz) > 78 %` or `mid+hi < 30 %` → reject (`gen_weapon_audio.py:410-413`) |
| 10 | **Loop-point click (the siren)** | Ticks once per revolution, forever; everyone blames the engine | `abs(x[0] − x[-1]) > 0.02` **and** first-difference discontinuity at the seam > 4σ of local slope → reject or crossfade |
| 11 | **Loop length ≠ whole number of siren periods** | Pitch sweep audibly restarts mid-cycle | autocorrelate; dominant period must divide file length within 1 % |
| 12 | **Clipped source (flat tops at 0 dBFS)** | Distortion baked in; worsens after Godot attenuation | count runs of `abs(x) >= 0.999` longer than 3 samples; > 20 runs → reject |
| 13 | **Room/reverb baked into a "dry" file** | A "jungle" explosion arrives with a concrete-carpark tail | `decay_ms > 90` on the near-field render → reject (`gen_weapon_audio.py:414-415`) |
| 14 | **Wrong content entirely** (a 40 mm labelled 105 mm; a car alarm labelled air-raid siren) | Nothing catches this. Ever. | **No numeric check exists.** Ears only. This is the irreducible cost of item 3 |
| 15 | **Missing/incorrect `.import` sidecar** | Loops when it should not; `force/mono` unset; a fresh clone imports differently | assert the sidecar exists and contains `force/mono=true` and the intended `edit/loop_mode`; template at `gen_weapon_audio.py:328-355` |

**Item 14 is the one that matters.** Checks 1–13 are cheap and I can write them, and they still cannot
tell a good explosion from a bad one. Anyone selling the acceptance gate as *judgement* is wrong — it
is a floor.

**A structural landmine for the siren specifically:** `write_import` takes `loop: bool = False`
(`gen_weapon_audio.py:328`) and `emit()` **never passes it** (`:363`). Every sidecar this pipeline has
written says `edit/loop_mode=0` (`:351`). A looping siren cannot come out of the existing emitter
without a change — and a careless change means the *next* full run of `gen_weapon_audio.py` stamps
loop=1 sidecars across the gunshots, which is precisely what `test_audio_pack.gd:67-68` exists to catch
("loop enabled (voice never frees)").

---

## 3. THE LICENCE TRAP

The plan says "CC0/public domain". Reality:

- **Freesound is a mixed pool.** CC0, CC-BY, CC-BY-NC and Sampling+ sit side by side, per-file, and the
  licence lives in metadata a downloader routinely drops. **CC-BY-NC is fatal for a Steam release**;
  CC-BY is survivable only if attribution is actually published.
- **Mislabelled CC0 is common.** Users re-upload other people's recordings under CC0 constantly. CC0
  carries **no warranty**: if the uploader had no right to grant it, the grant is void and the
  downstream shipper infringes regardless of good faith.
- **Archive.org "public domain" is a per-item claim, not a site policy.** Government recordings (AFVN,
  USAF, NARA) are generally PD in the US; user uploads on the same site are not.
- **An agent cannot verify provenance.** It can read a licence field. It cannot know whether the
  uploader was entitled to write it.

**No attribution or credits file exists for audio anywhere in this repo.** Verified — a repo-wide
search for `*licen*`, `*credit*`, `*attribut*`, `*NOTICE*` returns exactly four hits:

- `LICENSE` (the project's own, All Rights Reserved)
- `.gitattributes`
- `assets/textures/fx/particles/LICENSE.txt` — *"Kenney Particle Pack (kenney.nl) - CC0 1.0 public domain."*
- `assets/weapons/m26_grenade_low-poly/license.txt`

So the **pattern already exists** (a per-directory licence file beside the borrowed asset) — audio
simply never got one, and the audio in this tree is the riskiest material in the project. The only
provenance record for the 5 tracked Radio Vietnam broadcasts is **prose in a tracking doc**
(`ART_Track_Log.md:65, 147` — his own Audacity edits of period broadcasts mixed with AI-generated
segments). That is not a ledger and it does not travel with the build.

**The ledger that must exist before one downloaded file lands:**

`assets/audio/CREDITS.txt` — note `.txt`, because `export_presets.cfg:11` excludes `*.md`, so a
Markdown credits file **will not ship**. One row per non-original file:

| file | source URL | uploader | licence (exact name/SPDX) | licence URL | date retrieved | SHA-256 | attribution required in-game? |
|---|---|---|---|---|---|---|---|

Plus, in the same change:
1. `exclude_filter` amended to keep `assets/audio/ambience/jungle_day.mp3` and
   `assets/audio/Radio Vietnam/music/` out of the `.pck` (§0), or those files replaced.
2. `LICENSE` amended so its "audio … is proprietary" sentence stops being false.
3. A test that fails the build when a file exists under `assets/audio/` with no ledger row — otherwise
   the ledger is the next fossil (`CLAUDE.md:306` — *"a law in Markdown is just the next fossil"*).

---

## 4. THE SIREN'S EDGE CASES

`SiegeDirector` verified in full (`scripts/missions/siege_director.gd`).

**4.1 `siege_ended` can simply never fire.** `_break_siege` is reachable *only* from `_run_siege`
(`:198-213`), reachable only from `_physics_process` (`:103-113`) while `active`. Therefore:

- **Scene teardown / walking out of the AO / returning to the hub** — the node is freed mid-siege and
  `siege_ended` never emits (`:335-357`). A siren parented to a tower dies with the scene (fine). A
  siren living on the **AudioManager autoload** does not — it survives the scene change and wails over
  the hub.
- **`set_physics_process(false)`** — the arena explicitly re-enables it (`ai_stress_arena.gd:1506`),
  proving something in this project turns it off. While off, `_elapsed` stops accruing, so even the
  `MAX_DURATION_S` escape hatch (`:40`, `:203-205`) never arrives. **Siren forever.**
- **Pause.** An `AudioStreamPlayer3D` at the default `PROCESS_MODE_INHERIT` still renders audio under
  `get_tree().paused` unless explicitly stopped. Pause to read the map mid-siege → the siren screams
  over the pause menu, and `_physics_process` is halted so nothing can stop it.

**4.2 Save / quit mid-siege.** Nothing in `CampaignState` or `game_flow.gd` persists siege state —
`grep siege` over both returns only the dev-lens force-trigger (`game_flow.gd:256-268`). On reload
`active` is false and the siren is silent. That direction is safe. The unsafe direction is a siren
whose "on" state gets written into a save and restored without a matching `siege_began`.

**4.3 Destroyed towers keep screaming.** `Destructible._do_destroy` (`destructible.gd:60-80`) hides
**`MeshInstance3D`** children and disables **`CollisionShape3D`** children. It touches nothing else. An
`AudioStreamPlayer3D` child is neither, so it survives untouched: **the tower is rubble on a MultiMesh
and the siren wails on from the crater.** And note C2 of the ship gate is literally "parts of the base
must blow up" — towers *will* be exploding, by design, in the demo this work claims to serve.

**4.4 Player 800 m away.** The pooled voices cap at `max_distance = 350.0` (`audio_manager.gd:83`);
explosions get 600 (`:384`). A siren at 800 m is inaudible through any existing path, so it needs its
own player with its own `max_distance`/`unit_size` — i.e. **a new audio system**, not a reuse. That is
the **8th** parallel audio node-spawner here; the existing seven: `audio_manager` (voice pool `:80`,
step pool `:106`), `ambient_war.gd:62`, `vo_manager.gd:34,80`, `gun_fx.gd:518` and `:621`,
`game_world.gd:302`, `radio_prop.gd:58`, `spectre_gunship.gd:78`. The divergent-systems blindspot is
already at critical mass **in audio specifically**.

**4.5 Two sieges overlapping.** Cannot happen from the campaign path — `open_siege` returns early if
`active` (`:143`). But `siege_began` **already has two listeners**: `field_director.gd:1270` and
`ai_stress_arena.gd:1438`. A siren wired to the signal globally therefore **fires inside the AI stress
arena**, which the Summoner ruled must stay **sterile** (ADR-028 Ph3 CUT). Wire it in the world, never
to the bare signal.

**4.6 Four sirens, one mono file.** Four coherent copies of the same sample from points ~40–60 m apart
sum to roughly **+12 dB** with heavy comb filtering as the player crosses the compound. The mitigation
(per-tower pitch/phase offset) already exists as a pattern — `game_world.gd:307`,
`pitch_scale = randf_range(0.8, 1.5)` on the ambience ring — and forgetting it is the default outcome.

**4.7 Does it leak a node or a voice? YES, in the most likely implementation.**
- Through the **pooled voices**: a looping stream never sets `playing = false`, so `_acquire_voice`
  (`audio_manager.gd:291-310`) never sees it idle. Four sirens permanently consume 4 of 24 gunshot
  voices during the loudest event in the game. Worse, they *are* steal candidates once past
  `TRANSIENT_LOCK_MS`, so a nearby gunshot can silently kill a siren mid-wail (`:296-309`). Both
  directions are wrong. This is failure mode #2 verbatim from `test_audio_pack.gd:5-7`.
- Through `finished.connect(queue_free)` (the `gun_fx.gd:519-527` pattern): a loop **never** emits
  `finished`, so the node is never freed. Three nights of sieges → permanent orphans.
- **Runtime loop-flag mutation is a third trap already live in this codebase.**
  `game_world.gd:274-278` does `load(...) as AudioStreamWAV` then sets `loop_mode = LOOP_FORWARD` on
  it. `ResourceLoader` caches, so that is the **shared** stream instance. Any siren implemented the
  same way, on a wav that is ever also played through the pooled voices, leaks the loop flag into the
  pool at runtime — where no test can see it, because `test_audio_pack.gd:67` checks the *imported
  resource on disk*, not the live object.

**4.8 The fossil probe will fail the build if the siren is wired lazily.** `test_fossils.gd:256-261`:
a `signal` declared and emitted that **nothing connects to** is recorded as a fossil, and
`_audit_register` (`:333-357`) refuses growth past `ceiling`. A `siren_started` signal added "for
later" fails the build immediately. Correct behaviour — but it will surprise whoever adds it.

---

## 5. THE FOSSIL RISK — what must die

**The `explosion.wav` fallback: ruling = LIVE SAFETY NET. Keep it. But know what it is.**

`audio_manager.gd:371-374`:
```gdscript
var s := _try_load(XPATH + kind + ".wav")
if s == null:
    s = _try_load("res://assets/audio/sfx/explosion.wav")
```
A genuine second branch, not a fossil. But every `kind` string in the codebase is one of
`explosion_grenade` / `explosion_rocket` / `explosion_40mm` / `explosion_heavy` (`claymore.gd:61`,
`grenade.gd:113`, `projectile_base.gd:383`, `sapper_charge.gd:72`, `field_director.gd:641,700,812`,
`siege_director.gd:299`, `player.gd:619`, `squad_system.gd:389`, `cas_airplane.gd:189,208,243`,
`spectre_gunship.gd:146`, `destructible.gd:78`, `fellable_tree.gd:114`) — and **all four of those files
exist on disk.** So the fallback branch is never taken today. Under ADR-023 triage that is
**UNFINISHED**, not FOSSIL: it exists to survive a *future* missing render, which is exactly the
situation this plan creates. Keep it.

But note its provenance: `gen_placeholder_audio.py:76` writes it at **22050 Hz** (`:9`) from a
`gunshot(55 Hz)` lowpassed — a placeholder. **And the same script's `shot_rifle/smg/pistol.wav` are
LIVE**: `audio_manager.gd:162-167` loads them as the class fallback bank and `_fallback_for`
(`:201-207`) routes every weapon with no dedicated render to them — including `m1911`, which
`test_audio_pack.gd:30` deliberately keeps on placeholder. **So `gen_placeholder_audio.py` is not a
fossil either. It is the live floor of the audio system, running at less than half the sample rate the
rest of the library uses, and no test covers it.** That is a better use of this session than a siren.

**Will new files trip `test_fossils.tscn`?** No — the probe scans identifiers in
`.gd/.tscn/.tres/.cfg/.json` (`test_fossils.gd:8-14`); `.wav` files are invisible to it. **New GDScript
will trip it** (§4.8). And `.py` is *not* in `REF_EXTS`, so a Python-side reference cannot alibi a
GDScript symbol — a `const SIREN_WAV` referenced only from a tool script reads as dead.

**What must die if explosion renders are replaced:** nothing, if the replacements land at the same four
paths — that is a swap, and the fossil law is satisfied. **What must NOT happen** is the shape the
fossil law was written for: a real recording added at `explosions/explosion_heavy_real.wav` beside the
synth `explosion_heavy.wav`, with the selection logic "wired up next session."
`test_audio_pack.gd:85-87` guards exactly that for weapons — *"stale extra variant beside real audio"* —
and **there is no equivalent guard for `explosions/`.**

**The real fossil risk in this plan is the acceptance gate itself.** `_acceptance`
(`gen_weapon_audio.py:399-425`) runs only over `WEAPONS` (`:434-439`). `render_explosion` (`:270-307`)
has **no numeric gate of any kind** — and its thresholds are precisely the ones that catch "we made it
heavier": `low > 78 %` (kick-drum) and `crest < 7 dB` (mushy). **Rebuilding the explosion synth for
"weight" without extending `_acceptance` to `EXPLOSIONS` walks into the exact ditch the tool was built
to fence off, blindfolded.** If item 2 of the plan happens at all, extending `_acceptance` is not
optional — it *is* the deliverable.

---

## 6. WHAT IS SACRIFICED — plainly

- **The demo gate.** His words are on record (`DEMO_SHIP_BACKLOG.md:7-9`). Hours on a siren are hours
  not spent on **C2** — blast-bus wiring for the 80 authored parapet segments, i.e. the "base blows up"
  item, described in the backlog as *"the wiring to the blast bus is the gap"*. The siren is decoration
  on an event the player currently cannot properly *see*.
- **The one audio ask he actually made** — D3, ambient-war volleys — stays open while we build audio
  nobody requested.
- **Disk. VERIFIED, and the memory note is directionally right: `C:` is at 91 % — 22 GB free of
  238 GB.** The repo is **9.5 GB**. `assets/audio/` is already **202 MB**, of which **104 MB is
  Radio Vietnam** and **54 MB is the one unlicensed mp3** — **~78 % of this project's audio weight is
  material we may not ship.** Curated 48 kHz/16-bit mono WAV runs ~96 KB/s, so a dozen explosion takes
  plus siren loops is tens of MB; the keepers are not the threat. **The audition pile is** — fetching
  200 candidates to keep 6 is how 22 GB becomes 20. Download to the scratchpad, audit numerically, copy
  only survivors into `res://`.
- **Perf.** Small, but it lands at the worst moment. `PERF_LEDGER.md` measures this project
  **call-bound** at 24–33 FPS native (2026-07-16 entries; draw calls 164 → 56 explains the 8 FPS
  swing). Four extra `AudioStreamPlayer3D` nodes are cheap. Four extra **looping** voices during a
  50-attacker siege, beside a 24-voice pool that already drops shots under load
  (`audio_manager.gd:310` — *"drop the shot (silence beats a clipped transient)"*), are exactly the
  wrong four voices at exactly the wrong time. The siege is already the heaviest frame in the game.
- **Reversibility.** Real recordings are the one asset class here that **cannot be regenerated** —
  every other pipeline (`gen_weapon_audio.py`, `gen_firebase_v3.py`, `gen_village.py`) rebuilds from
  source deterministically. A downloaded file with a lost URL is permanent, unverifiable debt. That is
  precisely the shape of `jungle_day.mp3`, which has sat here since 2026-07-09 with a `.gitignore`
  comment as its only tombstone.
- **The mixed library — the largest hidden cost, and nobody has named it.** Real + synth in one bank
  means every future synth change must be A/B'd against a fixed real reference **by ear** — by *him*,
  since I cannot listen. The plan quietly converts audio from "I can iterate autonomously behind a
  numeric gate" into "every iteration needs the Summoner's ears."

---

## 7. IF IT IS BUILT ANYWAY — minimum conditions

1. **Fix `export_presets.cfg:11` first.** Nothing else here is safe until the `.pck` stops carrying
   material we do not own.
2. **`assets/audio/CREDITS.txt`** (not `.md` — `*.md` is excluded from the export), one row per
   non-original file with SHA-256 and retrieval date, plus a test that fails the build on an unledgered
   file under `assets/audio/`.
3. **Amend `LICENSE:1-7`** so its audio claim is true.
4. **Extend `_acceptance` to `EXPLOSIONS`** before touching `render_explosion`, and add checks 1–13
   from §2 as an `--audit <file>` mode on the same tool.
5. **The siren gets its own dedicated player**, never a pooled voice; pause-safe `process_mode`;
   explicit `stop()` on `siege_ended`, on `_exit_tree`, **and** on the owning tower's `_do_destroy`;
   per-tower pitch offset; and a watchdog that stops it if `active` has been false for >2 s regardless
   of whether `siege_ended` ever arrived.
6. **Wire it in the world, not to the bare signal** — `ai_stress_arena.gd:1438` must not inherit it.
7. **Extend `test_audio_pack.gd` to cover `explosions/` and any siren directory** — mono, 48 kHz,
   loop-mode-as-intended, no stale variants. The directory it does not cover is the directory the bug
   will be in.

---

## VERDICT

The export preset ships unlicensed audio today. The siren is gated feature work with no sponsor, an
unbounded "off" condition, and a node that outlives the tower it is bolted to. The explosion rebuild is
legitimate and cheap **only** if the acceptance gate grows to cover it. Real recordings are the only
irreversible asset class in this project, and the repo has no ledger, no attribution file, and a
LICENSE that already lies about them.

Do §0. Then ask him about the siren.
