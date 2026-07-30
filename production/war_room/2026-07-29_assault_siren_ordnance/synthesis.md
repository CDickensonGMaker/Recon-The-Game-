# DECREE — Firebase Assault Siren + Ordnance Voice (2026-07-29)

Arbiter: RECONgame Overseer. Council: sound designer, technical director, ux designer,
devil's advocate — summoned in parallel, no cross-talk. Analyses in `analysis/`.
Summoner's gate rulings are binding and were not re-litigated.

## The Summoner's rulings (taken before any build)

1. **Sourcing — BOTH.** Upgrade the synth *and* add a curated real-recording layer.
2. **Siren voice — MOTOR-DRIVEN AIR-RAID WAIL.** Readability beat historical typicality.

---

## THE FINDING THAT OUTRANKS THE QUERY

**Licence-unclear audio already ships in the exported build.** Verified by the Arbiter
directly, not relayed:

`export_presets.cfg:9-11` is `export_filter="all_resources"` with
`exclude_filter="tests/*, art_source/*, tools/*, screenshots/*, *.md"` — **no audio
exclusion**. `.gitignore` governs GitHub; it has no bearing on what Godot packs.

So both of these are inside the `.pck`:

| Asset | The repo's own words |
|---|---|
| `assets/audio/ambience/jungle_day.mp3` (55 MB), loaded live at `game_world.gd:269` | `.gitignore:27-28` — *"YouTube-sourced dev ambience - license-unclear, replace for release"* |
| `assets/audio/Radio Vietnam/music/` (14 tracks) | `.gitignore:30-38` — *"we hold no distribution right"* |

Both were gitignored **specifically** for licensing, and the build re-includes them.
`LICENSE:1-7` asserts all audio is original and proprietary; that is already false.

The 2026-07-27 decree (D6) already designed a broadcast-only radio as the intended
fallback when the music is absent, so **excluding these from export matches existing
design intent rather than breaking anything.**

**AWAITING SUMMONER'S RULING** — build configuration is his call, not the council's.
Recommended one-line change to `exclude_filter`:
```
tests/*, art_source/*, tools/*, screenshots/*, *.md, assets/audio/ambience/jungle_day.mp3, assets/audio/Radio Vietnam/music/*
```

---

## What was actually still synthetic

The query asked to *"find anything we've procedurally generated"*. The honest answer
corrects a first-pass reading:

Rifles and MGs are **real recordings**, integrated 2026-07-27 (Snake's Authentic Gun
Sounds). That session ruled explicitly: *"Launchers (m79, m72_law, rpg2, rpg7) are OUT OF
SCOPE — the pack has no launcher audio."*

**This session lands exactly on the gap that one left open** — the launchers, all four
explosion classes, and the 22.05 kHz placeholder bed from `gen_placeholder_audio.py`.

---

## D1 — The size ladder is the fix (SOUND DESIGNER, upheld)

The council's strongest single finding, and it was not in the DSP.

`gun_fx.gd:110-115` ranks ordnance for the **eyes** (`_KIND_SCALE`: 40mm 0.8 → grenade 1.0
→ rocket 1.4 → heavy 1.9). `audio_manager.gd:382-385` gave every class the identical
`+6 dB / 600 m / unit_size 30`. **A 40 mm grenade and a 500 lb bomb were the same loudness
across the same radius.** The ladder existed; the ears never got it.

SHIPPED — `_KIND_AUDIO` in `audio_manager.gd`:

| kind | volume_db | max_distance | unit_size | duck_ms |
|---|---|---|---|---|
| `explosion_40mm` | +1 | 340 m | 16 | 180 |
| `explosion_grenade` | +4 | 460 m | 24 | 240 |
| `explosion_rocket` | +6 | 620 m | 32 | 300 |
| `explosion_heavy` | +9 | 1100 m | 52 | 520 |

## D2 — Explosions get distance layering and variants

Guns had `_dist` renders past 85 m (`audio_manager.gd:247-254`); explosions had none —
one near-field file at all ranges to 600 m. SHIPPED: `_dist` render per class, crossover
at 190 m, plus 3 decorrelated variants per class (a 3-round mortar volley was the
identical waveform three times a second).

## D3 — Renderer rebuild

`render_explosion()` rebuilt to eight layers: shock front · gas fireball · non-linear sub
(settles onto a floor rather than decaying to zero) · **ground slap** · **discrete terrain
returns** · **fragment whizz** · debris fall · environment tail. New `"valley"` IR preset
(5.6 s / decay 1.35) — the longest previous preset was 2.2 s, so an artillery roll was
physically un-renderable.

**Two live bugs found and fixed:**
- `bark_hz` on all four explosion entries is read only by `muzzle_blast()`, which
  `render_explosion()` never calls. Four dead tuning knobs — ADR-023 fossil, deleted.
- `debris` was applied twice (`:291` count, `:300` gain) so frag energy went as debris².
  At `explosion_40mm`'s 0.35 that is 0.12 — the layer had all but vanished.

## D4 — Brightness was firework-bright, and the gate proves it now

The Arbiter measured a real blast recorded at four ranges (BigSoundBank 1808/1807/1806/1023):
spectral centroid **652 Hz at 10 m, 362 Hz at 150 m, 247 Hz at 250 m**, 73–91 % of energy
below 250 Hz. **A detonation is dark.** Previous values ran 5200–8400 Hz.

`render_explosion` had **no numeric gate at all** — `_acceptance()` covered weapons only.
SHIPPED: `_acceptance_explosions()`, run by `--report --explosions`. Nine metrics plus
ladder cross-checks and variant decorrelation. Final state **ALL PASS**:

| class | centroid | low | t60 | late>400 ms | crest |
|---|---|---|---|---|---|
| grenade | 899 Hz | 67.9 % | 1.65 s | 2.5 % | 11.9 dB |
| rocket | 520 Hz | 77.3 % | 2.37 s | 12.2 % | 13.3 dB |
| 40 mm | 1170 Hz | 37.9 % | 1.26 s | 1.7 % | 13.0 dB |
| heavy | 199 Hz | 91.3 % | 5.49 s | 58.3 % | 10.5 dB |

**Two thresholds were corrected against measurement rather than tuned around**, and this is
recorded because the reasoning matters more than the numbers:
- `late` is class-aware. A 40 mm HE genuinely has no roll; holding it to the artillery
  threshold would mean faking one.
- `low` ceiling is 0.93 for classes ≥ 4 s, 0.90 below. The 0.90 figure was invented before
  any real blast had been measured. The real 250 m recording measures **91.2 % low**;
  synthesised heavy now sits at 91.3 % / 199 Hz. Holding artillery to the small-ordnance
  ceiling would have tuned the truth out of it.

## D5 — Siren architecture (TECHNICAL DIRECTOR, upheld)

**The critical unknown was resolved by headless probe, not assumption:** the towers are
four real `fb_tower_i` `MeshInstance3D` children of the `fsb_main_v3` root. Nothing merged,
fully addressable.

**But the markers are wrong** — the GLB ships FIVE `tower_los_point*` for four towers, two
sharing a position. `SirenTower.build_from_markers` therefore keys off the tower **meshes**
and dedupes by XZ, and must never use `FSB_MARKER_KEYS`.

Dedicated `AudioStreamPlayer3D` per tower, never the 24-voice one-shot pool: `unit_size 60`,
`max_distance 900`, `volume_db −2`, and **`max_db = 0.0`** — the clamp is what stops it
deafening at the tower base, since Godot's default `+3` lets a listener inside `unit_size`
boost above unity and four towers stack. The four are detuned (1.0 / 0.988 / 1.014 / 0.997)
so they do not sum coherently.

**Bus: new `Alarm` → `SFX`.** NOT `Weapons` — its compressor (threshold −12, gain +3) would
pump every gunshot in the game under a sustained source. NOT `Ambience` — `duck_ambience()`
writes an absolute −8 dB on every shot and explosion, which would mute the siren *exactly*
when it matters.

Built at `site_planner.gd` immediately after `Ladder.build_from_markers(root)` — identical
precedent, identical post-seat ordering reason (world positions must be read at final height).

## D6 — Trigger and termination (UX DESIGNER and DEVIL'S ADVOCATE, merged)

The two architects conflicted and the Arbiter merged them; the merge is stronger than either.

- **Fires at `siege_began`**, after a 2–5 s beat (a man has to reach the crank). Cells are
  300–500 m out at 2.2 m/s — a 135–225 s runway. Triggering on materialise (80 m) would
  delete the only decision window the siege has.
- **A PROBE does not sound it.** `is_probe` (d50 ≤ 11) is 2d6 sappers; crying the siren for
  three men is how a siren stops meaning anything. The sentry's shout carries it.
- **It is NOT wired to `siege_ended`.** The Devil's Advocate proved that signal can never
  fire on several real paths — `_break_siege` is reachable only from
  `SiegeDirector._physics_process` while active, so teardown, `set_physics_process(false)`
  (`ai_stress_arena.gd:1506` does exactly this) or a pause strand it. A signal-terminated
  siren wails forever. It runs its own 45–75 s clock instead.
- **A destroyed tower goes silent.** `Destructible._do_destroy` (`destructible.gd:60-80`)
  only hides the `MeshInstance3D` and disables the collider — an audio child survives it
  untouched, so a blown tower would keep crying from its crater. `_process` checks tower
  visibility. "Parts of the base blow up" is demo ship-gate item C2.

## D7 — The headcount leak (UX DESIGNER, upheld — corrected on contact)

`_on_siege_began` toasted **`"THEY'RE COMING IN STRENGTH (%d ON THE WIRE)"`** — the literal
enemy headcount. Nobody inside that perimeter could know that number at stand-to; it is the
director's roll, not anything a man on a tower can see in the dark. The siren replaces it;
the toast is now bare `"STAND TO"`.

**FLAGGED, NOT CHANGED:** `_on_siege_ended` leaks the same way — `"%d OF %d DOWN"` at
`field_director.gd:1287,1290,1293`. That is mission-feedback copy and the Summoner's call,
not the council's.

## D8 — The landmine in the generator (Arbiter's own finding)

`python tools/gen_weapon_audio.py` with no arguments regenerated **every** id in `WEAPONS` —
silently overwriting the real 7/27 recordings with synth, the exact downgrade the Summoner
forbade. A bare run now refuses and prints the two explicit forms. Regenerating a weapon is
an intentional act.

## D9 — Attribution ledger

`assets/audio/CREDITS.txt` created — **the repo had no audio credits file of any kind.**
`.txt` deliberately: `*.md` is export-excluded, so a Markdown ledger would be absent from
the artefact it documents. Records the CC0 siren source, the synthesised inventory, and
flags two open risks — the 7/27 gun pack's licence was never recorded, and the LICENSE file
needs a carve-out clause.

---

## THE GATE — surfaced, not decided

The Devil's Advocate is correct that **PLAYTEST R4 is active** (`CLAUDE.md:395-402`,
`OVERSEER_CHARTER.md:150`) with no discharge record, and that a new siren feature is gated
work with no ADR and no backlog line.

**Arbiter's ruling:** the export/licence finding is a **bug fix** and the explosion rebuild
is **presentation** — both ungated, both shipped. The siren was **directly requested by the
Summoner in this session**, which supplies the sponsor the objection named as missing; a
gate concerning *his own* verification cannot bind against *his own* explicit instruction.
Built and wired, and the gate is reported to him rather than silently discharged.

Also honest: the Devil's Advocate is right that sound design is not the demo ship gate
(`DEMO_SHIP_BACKLOG.md:4-9` — allies → air → base blows up), and that the one audio item he
actually listed (D3, ambient-war volleys) is untouched by this session.

---

## WHAT IS SACRIFICED (no free lunches)

- **The siren carries strictly LESS information than the toast it replaces.** A number
  traded for a feeling. That is the intended direction, but it is a real loss.
- **Autonomy.** A mixed real+synth bank means future audio changes increasingly need the
  Summoner's ears. The Arbiter cannot hear; every judgement here is spectral.
- **Disk.** 91 % used, 22 GB free. Explosions grew to 5.3 MB, siren adds 5.1 MB.
- **The Huey is still silent.** `helicopter.gd` has **zero** audio references — verified.
  It is named in the demo ship gate and this session did not fix it.
- **Untouched by design:** mortar tube thump, incoming whistle, Spectre's Bofors, the
  shotgun (fires a rifle sound), `m26_grenade`, and the `_dist` layer's real-recording
  substitution. All named in `analysis/sound_designer.md`.
