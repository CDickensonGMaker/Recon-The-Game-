# Audio Architect — Defects 1 & 7 (Playtest 2026-08-11)

Diagnosis only; no code or assets touched. Audio files probed with a read-only
python script in the session scratchpad (16-bit PCM envelope/peak analysis, 20
segments per file). Every claim carries a pointer.

---

## DEFECT 1 — Huey flyby crunches/clips the mix

### Evidence

**The bus chain.** `assets/audio/default_bus_layout.tres`:
- Master (bus/0) carries ONE effect: `AudioEffectLimiter`, `ceiling_db = -0.8`,
  `threshold_db = -1.0` (`default_bus_layout.tres:3-5, 21-22`).
- `Vehicles` bus (bus/11, `default_bus_layout.tres:87-92`) sends to `SFX` (bus/1)
  which sends to Master. **Neither Vehicles nor SFX has any effect or trim** — all
  buses sit at `volume_db = 0.0`. The only compressor in the project is on the
  `Weapons` bus (`:35-36`) and does not touch vehicle audio.
- `AudioEffectLimiter` is the **deprecated** Godot limiter (deprecated 4.3 in
  favour of `AudioEffectHardLimiter`): a zero-lookahead soft-clip stage. Driven a
  few dB over threshold it audibly distorts — "crunch" is its documented failure
  sound. It is doing exactly what Caleb heard: crushing, not transparently limiting.

**The per-Huey source.** `scripts/vehicles/helicopter.gd`:
- Every helicopter builds its own `AudioStreamPlayer3D` on the `Vehicles` bus
  (`helicopter.gd:97-109`) playing the shared
  `assets/audio/sfx/aircraft/heli_rotor_loop.wav` (`:88`).
- Settings: `max_distance = 900` (`:89,103`), `unit_size = 55.0` (`:90,104`) —
  i.e. effectively full level inside ~55 m and only gentle rolloff beyond —
  `max_db = 0.0` (`:105`), and `volume_db` lerped up to **+2.0 dB** at full RPM
  (`ROTOR_DB_FULL`, `:92,122`).
- At full RPM every ship's `pitch_scale` is the identical `0.80 + 0.28*1.0 = 1.08`
  (`:121`) — same file, same pitch, so N ships sum **coherently**, worst case
  +20·log10(N) dB, not +10·log10(N).

**The source file is already hot.** Probe of `heli_rotor_loop.wav`: 48 kHz mono,
3.000 s, **peak −1.1 dBFS, RMS ≈ −10 dB** sustained across the whole loop. One
ship at +2 dB `volume_db` already grazes 0 dBFS at the limiter input.

**How many at once.** `scripts/ai/air_traffic.gd`:
- `FORMATION_SIZES = {"huey": [6, 9], ...}` (`air_traffic.gd:39`),
  `FORMATION_CHANCE = 0.85` (`:42`) — a demo "transit" flyby is **6–9 Hueys**.
- Echelon spacing is tight: 45–70 m lateral, 8–12 m alt, 15–30 m trail *per slot*
  (`:45-47`), at ~30 m AGL cruise (`helicopter.gd:11`). When the pack crosses the
  wire, 2–4 ships sit inside their 55 m `unit_size` simultaneously and the rest
  are barely attenuated under `max_distance = 900`.
- The demo schedules these packs repeatedly: `demo_game.gd:154-166`
  (`[3.0,"huey","transit"]`, `[14.0,"huey","lz_cycle"]`, `[48.0,"huey","transit"]`,
  then `AIR_ROTATION` is half Hueys) plus siege beats (`demo_game.gd:211,237-239`)
  and the ending gun orbit (`demo_game.gd:478`).

### Root cause

Summed overload into a crude limiter. Each Huey's rotor loop runs ~−1 dBFS peak
/ −10 dB RMS at up to +2 dB gain with a 55 m full-volume radius and `max_db` no
lower than 0; a formation is 6–9 of them playing the **same file at the same
pitch**, so the Vehicles→SFX→Master sum arrives **+10 to +19 dB over** the Master
limiter's −1 dB threshold. The limiter is the deprecated soft-clip
`AudioEffectLimiter`, which turns that overdrive into sustained audible crunch.
Three co-factors, one mechanism: (1) per-source level too hot for N-source
content, (2) no headroom trim or dynamics on the Vehicles bus, (3) a distortion-
prone limiter as the only safety.

### Proposed fix

1. **Give the fleet headroom at the source** — `scripts/vehicles/helicopter.gd`:
   - `ROTOR_DB_FULL: 2.0 → -8.0` and `ROTOR_DB_IDLE: -14.0 → -22.0` (`:91-92`),
   - `max_db: 0.0 → -6.0` (`:105`),
   - `unit_size: 55.0 → 30.0` (`:90`) so proximity actually shapes the flyby.
   - Optional flavour: derive per-ship pitch jitter once in `_build_rotor_audio`
     (e.g. `randf_range(-0.03, 0.03)` added to the `:121` formula) to break the
     coherent sum — worth ~6–9 dB on a 9-ship pack by itself.
2. **Trim the bus** — `assets/audio/default_bus_layout.tres`: set the `Vehicles`
   bus `volume_db` to `-6.0` (`:91`) so Spectre/CAS/Chinook (`spectre_gunship.gd:142`,
   `cas_airplane.gd:100`) inherit the same headroom without per-script edits.
3. **Replace the crusher** — swap Master's `AudioEffectLimiter` sub-resource
   (`default_bus_layout.tres:3-5`) for `AudioEffectHardLimiter`
   (`ceiling_db = -0.8`, default release) — the 4.x lookahead brickwall. This is
   a .tres-only change; `player.gd:1901-1906` only appends a lowpass to Master by
   index-at-end, so effect order is unaffected.

### What it sacrifices

- The wall-of-Hueys will be *felt* less: absolute loudness was doing emotional
  work in the flyby beat. The fix trades raw level for clean level; if the pass
  feels tame, the answer is the pitch-jitter + doppler texture, not gain.
- `HardLimiter` adds ~small lookahead latency on the whole mix (imperceptible for
  gameplay, but it is a real change to every sound in the game — a full-mix
  listen is owed after the swap).
- Values above are engineering estimates from measured levels; the final ±2 dB
  belongs to Caleb's ears in a live flyby, which no probe can replace.

---

## DEFECT 7 — AK-47 plays a bolt-rack after EVERY shot

### Hypothesis (a): rack baked into the fire samples — **REFUTED**

Probed all three fire variants (`assets/audio/sfx/weapons/fire_ak47_1..3.wav`,
48 kHz mono, 0.900 s each, peaks −4.2/−3.3/−3.8 dBFS): every one is a single
front-loaded report decaying monotonically to silence (variant 2 is digital-zero
after 0.54 s, variant 3 after 0.68 s). **No second transient cluster in any
variant.** The recordings are clean — do not touch them (and never run
`tools/gen_weapon_audio.py` without args; `gen_weapon_audio.py:640,662` shows it
would re-emit `mech_*.wav` over real files).

### Hypothesis (b): code chains a mechanical sample — **CONFIRMED, with a twist**

- The player fire path layers a "mech" sample on **every shot**:
  `scripts/autoload/audio_manager.gd:329-334` — after the near report,
  `_single(wid, "mech")` loads `mech_<id>.wav` and plays it at −8 dB on the
  dedicated `_p_mech` slot. The stream convention is documented at
  `audio_manager.gd:8`.
- The twist is the **content** of `mech_ak47.wav`. The Jul 8 synth mech renders
  are all 28,844 bytes (~0.3 s: `mech_m60`, `mech_mosin`, …). But `mech_ak47.wav`
  is **102,080 bytes / 1.063 s, timestamped 2026-07-29 20:35 — the same minute as
  the Snake-pack fire_ak47 files** (dir listing, `assets/audio/sfx/weapons/`).
  A real recording was dropped at the mech path (exactly the substitution the
  header at `audio_manager.gd:12` invites), and that recording is a **full
  charging-handle rack cycle**: probe shows it *starting quiet* (−17 dB), then a
  0.55 s clatter train of −6…−3.6 dB transients whose **loudest hit lands at
  t≈0.48 s** — right when the fire report has already decayed ~20 dB. That is the
  audible "shk-shk" after every round.
- **Why the M16 sounds fine with the same code path:** `mech_m16a1.wav` (same
  size/date) is front-loaded — its biggest transients sit at t=0.00 s and
  t≈0.32 s and it is 40 dB down by 0.58 s — so it hides under the report's decay
  instead of outliving it.
- NPC AK fire is unaffected (3D path `audio_manager.gd:226-262` never plays a
  mech layer), consistent with the defect being heard on the player's own gun.
- A proper home for a rack sound already exists and is reload/bolt-only:
  `play_bolt_player` (`audio_manager.gd:348-355`, invoked via
  `gun_fx.gd:93-94`) and `reload_ak47.wav` (366 KB real recording, same dir).

### Root cause

`mech_ak47.wav` is a real bolt-rack recording sitting at the per-shot mech-layer
path; `audio_manager.gd:330-334` faithfully plays it after every trigger pull.
The code is behaving as designed — the asset is miscast.

### Proposed fix

Move `assets/audio/sfx/weapons/mech_ak47.wav` out of the per-shot slot:
rename it to `bolt_ak47.wav` (the empty-reload/bolt convention slot,
`audio_manager.gd:10,351` — no `bolt_ak47.wav` currently exists, so nothing is
overwritten). Then either leave the AK with no per-shot mech layer (`_single`
returns null and line 330's `if mech:` skips cleanly — zero code change), or
regenerate a short synth clatter for it alone via
`python tools/gen_weapon_audio.py` **with an explicit single-weapon arg only**,
matching the ~0.3 s Jul-8 profile (`tools/weapon_voices.py:71` shows the intended
per-shot mech is spring-twang scale, not a rack). Audit `mech_car15.wav`
(102,078 bytes, same Jul-29 batch) for the same miscast before closing.

### What it sacrifices

- With no mech layer the player AK loses a little close-up mechanical sparkle the
  M16 keeps; the synth-regen option restores it at the cost of one deliberate,
  carefully-argued run of the landmine tool (real fire recordings must NOT be in
  its emit set — verify the arg form against `gen_weapon_audio.py:640` first).
- The rack recording is preserved (as `bolt_ak47.wav`) rather than deleted —
  honouring "real gun recordings are sacred" — but it changes what an empty
  reload sounds like, which Caleb should hear once before it ships.
