# War Room Briefing — Audio Pack Integration (2026-07-27)

## The query

Two real-recording audio packs land in the project. Replace synth placeholders and extend the
diegetic field radio.

1. **Vietnamese folk music LP** (14 mp3s) → radio prop music layer, interleaved 3 music : 1 broadcast.
2. **Snake's Authentic Gun Sounds** (5.56 / 7.62x39 / 7.62x54R + reload/cycling recordings) →
   replace `fire_<id>_1..3` / `fire_<id>_dist` / `reload_` / `bolt_` synth placeholders.

## Summoner's rulings — BINDING, not open for re-litigation

1. Radio mix: **3 folk songs, then 1 broadcast**, repeating.
2. Gun swap: **exact caliber matches PLUS derivation for the rest.** 5.56 → m16a1, car15.
   7.62x39 → ak47, sks, rpd. 7.62x54R → mosin. Derive m60, ppsh41, thompson, m1911, kar98k, mp40
   from nearest-fit with pitch/EQ treatment. **If a derivation sounds worse than its placeholder,
   KEEP THE PLACEHOLDER.** Never ship a downgrade for coverage. Launchers (m79, m72_law, rpg2, rpg7)
   are OUT OF SCOPE — the pack has no launcher audio.
3. **Licensing:** the LP is a commercial recording, the repo is public. Imported music stays OUT of
   git tracking (gitignore), like the untracked art.
4. **Broadcast integrity (ruling issued mid-session):** the 5 existing broadcast `.ogg` files are
   left **bit for bit untouched** — he edited them personally and they are deliberate easter eggs.
   Play them WHOLE: no start-offset, no segmenting, no early fade. The length imbalance is a
   FEATURE. No UI, indicator, or telegraph of what is playing or what is next. The radio is not a
   core system — it is incidental, and it must feel **organic and discovered**, never like a curated
   soundtrack on a schedule.

## Measured ground truth (probed this session, not assumed)

- Existing weapon sfx are **synth placeholders**: every `fire_*_[1-3].wav` is byte-identical in size
  (72044 B) and every `fire_*_dist.wav` is 153644 B. 16 weapon ids covered.
- Gun pack sources: all 44100 Hz / 2ch / 16-bit.
- **Isolated vs Full Sound are the SAME take.** Peaks match exactly per pair (556 Single: -3.6 dB in
  both). Full Sound is 2.3-2.4x longer with a lower mean — it is the dry shot **plus environmental
  tail**. Therefore: Isolated → near report layer, Full Sound → distant/tail layer. This was the
  brief's hypothesis and it is now MEASURED.
- The pack ships **one take per caliber per fire-mode** (Single / Double Tap / Burst / Spray). There
  is no set of three alternate single-shot takes, so `fire_<id>_1..3` must be built by slicing
  discrete shots out of the multi-shot files.

## Constraints the council must respect

- Canon: 5 Pillars (esp. #1 believable firefights, #2 atmosphere), ADR-015 verification law, ADR-023
  fossil law (replacement means DELETING the placeholder, not shelving it), COMMENT DISCIPLINE,
  POINTER LAW, strict GDScript typing.
- `scripts/autoload/audio_manager.gd` resolves streams purely by filename convention. A wrong
  filename silently falls back to a class bank — failure is SILENT.
- Radio must stay ONE script (`scripts/props/radio_prop.gd`). Evolution, not a new manager.

## Questions put to the council

1. Layer assignment and slicing: how to get three convincing single-report variants per caliber from
   one take without them reading as the same sample three times.
2. Which derivations (m60, ppsh41, thompson, m1911, kar98k, mp40) are defensible from this stock, and
   which should keep their placeholder.
3. Radio continuity: what makes the playlist feel "discovered" rather than scheduled, given the
   broadcasts must play whole and nothing may be telegraphed.
4. What silently breaks — the failure modes of a convention-resolved audio swap.
