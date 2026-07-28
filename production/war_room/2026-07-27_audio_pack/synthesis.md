# DECREE — Audio Pack Integration (2026-07-27)

Arbiter: RECONgame Overseer. Council: systems/audio, lead programmer/Godot, devil's advocate.
Analyses in `analysis/`. Summoner rulings in `briefing.md` are binding and were not re-litigated.

## The finding that reshaped the job

**Two architects, working independently with no cross-talk, returned the same P0.** Verified by the
Arbiter before acting (`data/weapons/` directory listing + `tests/test_flat_damage.gd:31`):

`car15`, `sks`, `thompson`, `kar98k`, `mp40` are **RETIRED BY CANON**. No `.tres` exists for any of
them; `test_flat_damage.gd:31` names them in a `RETIRED` list and fails the suite if one loads. The
Summoner's mapping named **five weapons the game cannot equip** — two of the three "exact caliber
match" targets and three of the six derivations.

Independently verified: `grep` for each retired id across `scripts/`, `data/`, `scenes/` outside
`tests/` returns **zero hits**. Nothing spawns them.

Meanwhile `m14` and `m70` are LIVE with **zero** fire audio, falling through `audio_manager.gd:149`
to the generic `shot_rifle.wav` class bank — the 87-damage sniper currently sounds like every other
rifle.

**Ruling of the Arbiter:** canon outranks a list of filenames. The Summoner's ruling was derived from
the filenames on disk, not the shipping roster; his *intent* — exact caliber matches, derive the
rest, never ship a downgrade — is served by applying it to the **live** roster. This is not a
re-litigation of his decision; it is that decision applied to the weapons that exist. Flagged to him
in the report.

## Measured ground truth (Arbiter's own probes — not architect claims)

1. **Isolated == Full Sound transient, bit for bit.** Spectral centroid of the first 120 ms matches to
   2 Hz (5.56: 6631 vs 6629). Full Sound is the same take plus environmental tail. Confirms the layer
   split: Isolated → near report, Full Sound → distant report.
2. **7.62x54R is ONE shot copy-pasted.** Pairwise correlation of all six candidate slices across
   Single / Double Tap / Burst is **0.99–1.00**. There is exactly one genuine 7.62x54R take in the
   pack. Fabricating three "variants" from it would be a lie in the asset.
3. **7.62x39 yields three genuinely distinct takes** (mutual correlation 0.36 / −0.06 / −0.13);
   **5.56 yields three** (0.77 / 0.11 / 0.07). Each chosen slice is the last shot of its file, so each
   has 0.69–1.12 s of free decay.
4. **Caliber identity is spectrally clean:** 7.62x54R 5048 Hz < 7.62x39 6063 Hz < 5.56 6631 Hz.
   That ordering is the principled basis for every derivation.
5. **Mono downmix of the stereo sources clips** (peaks to +2.3 dBFS). Normalisation is mandatory, not
   optional.
6. House contract is **mono / 48000 Hz / pcm_s16le**; every existing weapon wav matches it.
7. **SimClock runs at 60x real time** (`sim_clock.gd:17`). The radio timeline must use REAL seconds —
   sim time would pass a 52-minute broadcast in 52 real seconds.

## Decisions

### D1 — Weapon mapping (live roster only)
| Weapon | Source | Treatment | Variants |
|---|---|---|---|
| m16a1 | 5.56 Isolated | none (exact) | 3 |
| ak47 | 7.62x39 Isolated | none (exact) | 3 |
| rpd | 7.62x39 Isolated | −4% pitch, +2 dB @150 Hz | 3 |
| mosin | 7.62x54R Isolated | none (exact) | **1** — only one genuine take exists |
| m70 | 7.62x54R | −3% pitch, +2 dB @120 Hz | 1 |
| m14 | 7.62x54R | +2% pitch | 1 |
| m60 | 7.62x39 | −8% pitch, +3 dB @120 Hz | 3 |
| ppsh41 | 7.62x39 | +15% pitch, HPF 300 Hz | 3 |
| m1911 | — | **KEEP PLACEHOLDER** | — |

`m60` is sourced from 7.62x39 rather than the ballistically closer 7.62x54R **because it fires at
550 rpm and x54R has only one genuine take** — a single sample at 550 rpm combs audibly. Three real
takes pitched down beat one correct-calibre clone. Named as a tradeoff, not hidden.

`m1911` keeps its placeholder: .45 ACP is subsonic and there is no pistol stock in this pack. The
Summeror pre-authorised keeping a placeholder over shipping a downgrade.

### D2 — Devil's advocate objection, upheld in part
An AK and an RPD firing identical samples is a real loss of tactical information (Pillar 1 — you
should tell weapons apart by ear). Mitigated by the −4%/+2 dB@150 treatment and independent
round-robin phase. Honest limit: they share a cartridge and in reality do sound close.

### D3 — Near-report duration is a VOICE-POOL decision
Pool is 24 (`audio_manager.gd:21`) and `:252` **silently drops** shots when exhausted. Near duration
= `clamp(3 x cycle_time, 240 ms, 600 ms)` from each weapon's `fire_rate`. Distant = 700 ms.

### D4 — Levels
RMS-normalise to −23 dBFS **first**, then peak-limit to −1.0 dBFS. Peak-matching alone would make
every real gun quieter than the synth it replaces through the Weapons bus.

### D5 — Import sidecars are load-bearing (all three are silent killers)
`edit/loop_mode=0` on every wav (a looping gunshot never frees its voice and world gunfire dies after
24 shots) · `loop=false` on every ogg (`finished` is the only thing advancing the playlist) ·
`force/mono=true`. **In-place replacement does not invalidate `.godot/imported/` — the sidecar hashes
the source PATH, not the bytes.** Must run `--headless --import` after landing files, never
`--check-only`.

### D6 — Radio: virtual timeline (Summoner ruling)
Per-radio deterministic playlist seeded by position hash; timeline advances as arithmetic against
real elapsed time; audio only exists within a 125 m activation radius (`@export`), audibility stays
at `hear_distance` 25 m. Track lengths come from a generated manifest so the prop does **not** eagerly
load 92 MB of ogg at `_ready()` (programmer's finding). Prop loads exactly one stream, on activation,
and seeks with `play(from_position)`.

Music absent from a fresh clone (gitignored per licensing ruling) must warn **once**, not fail
silently — this is the exact drift shape the POINTER LAW exists to prevent (`jungle_day.mp3`
precedent: gitignored asset, tracked `.import`, silent absence).

### D7 — Fossil law (ADR-023)
Delete the fire/dist/mech/reload/bolt wavs + `.import` sidecars for all five retired weapons. Zero
references verified. Recoverable from git history if a weapon is ever revived.

## What is sacrificed (no free lunches)
- `mosin`, `m70`, `m14` get ONE near-report variant. Honest to the source; slow-firing weapons carry
  it, but it is thinner coverage than the other guns.
- `rpd` and `ak47` remain close by ear. Real, but a Pillar-1 cost.
- `m1911` and `shotgun` keep synth placeholders; launchers untouched (no source in pack).
- The 3:1 interleave is 3:1 by COUNT, not by TIME: broadcasts average 32.5 min against 1.57 min per
  song, so the radio is roughly 80% broadcast by time. The Summoner has ruled this is a feature and
  the broadcasts stay whole; recorded here as a measured fact, not an objection.
