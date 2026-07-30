# SOUND DESIGNER — War Room analysis

Brief: (a) motor-driven rising/falling air-raid siren on the firebase watch towers; (b) better
explosion + heavy-weapon SFX. Ruled: upgrade the procedural synth AND add a curated real-recording
layer.

Method: read code only. Every claim below carries a `file:line`. Date of reading: 2026-07-29.

---

## 0. THE HEADLINE, BEFORE THE DSP

The single largest reason explosions sound weak is **not** in `render_explosion()`. It is two lines
of playback:

- `gen_weapon_audio.py:307` — `D.normalize(out, 0.96)`. **Every ordnance class is peak-normalised
  to the identical amplitude.** A 500 lb Snakeye and a hand grenade leave the renderer at the same
  peak.
- `audio_manager.gd:382-385` — `volume_db = 6.0`, `max_distance = 600.0`, `unit_size = 30.0`,
  **hardcoded, identical for every `kind`.** A grenade and an artillery shell have the same
  loudness and the same audible radius in the world.

So the *size ladder does not exist in the audio at all*. `gun_fx.gd:112-115` has a `_KIND_SCALE`
ladder (1.0 / 0.8 / 1.4 / 1.9) — but it feeds **only the visual** (`_spawn_explosion_visual`,
`gun_fx.gd:121`). The eyes get the ladder; the ears do not. That mismatch is what the Summoner is
hearing when he says explosions are weak: the fireball is huge and the sound is a pop.

Fix this before touching a single filter coefficient. It is ~12 lines and it is most of the win.

---

## 1. WHY THE CURRENT EXPLOSION RENDER IS WEAK — DSP DIAGNOSIS

All references `gen_weapon_audio.py:270-307` (`render_explosion`) and `weapon_voices.py:204-218`
(`EXPLOSIONS`).

### 1.1 The render length is fixed at 2.8 s for all four classes — and the reverb cannot fit
`:274` — `n = int(D.SR * 2.8)`. `explosion_heavy` declares `tail=("open", 2.6)` (`weapon_voices.py:216`),
but the `"open"` IR preset is only **2.20 s long with decay 0.52** (`weapon_voices.py:227`), rendered at
`scale=1.0` (`gen_weapon_audio.py:303`). An IR with a 0.52 s decay constant is 40 dB down in 1.2 s.

**There is no environment in this project capable of producing an artillery roll.** The longest
possible reverberant answer decays inside ~1.5 s and is then truncated by a 2.8 s buffer whose first
0.5 s is already spent on the dry event. Artillery "rolling away down the valley" is physically
un-renderable with the current presets. That is the missing-layer complaint, exactly.

### 1.2 No ground slap, no discrete terrain returns
The **only** reflection in the render is the FFT convolution at `:304`, whose pre-delay is 6 ms
(jungle) or 22 ms (open) — a single smooth smear. A real HE burst gives you:
- the direct wave,
- a **ground-bounce** 5–25 ms later (near-perfect mirror, slightly darkened),
- then **discrete returns** off treelines, the berm, and hillsides at 100–700 ms.

Those discrete returns are what the ear reads as *scale and place*. `BLAM ... blam .. blam` is a big
shell in a valley; a smooth smear is a firework. **This layer is 100% absent.**

### 1.3 The low end is a pure sine, decays in a fifth of a second, and for `explosion_heavy` is below reproduction
`:281-284`:
```python
sweep  = p["f_low"] * (1.0 + 0.6 * np.exp(-t / 0.06))
rumble = np.sin(phase) * D.expdecay(n, 0.22, ...) * p["rumble"]
```
Three separate defects:
- **`tau = 0.22 s`, hardcoded for every class.** The low band is 40 dB down by ~1.0 s. There is no
  chest, because the chest layer is over before the reverb has started.
- **It is a pure sine.** Real blast overpressure reaching you through air and soil is a narrow band
  of *noise* plus strong non-linear harmonic content. A pure sine is the thinnest possible low end.
- **`explosion_heavy` has `f_low = 38.0`** (`weapon_voices.py:216`). 38 Hz is below the usable range
  of laptop speakers, most headphones, and every TV. The layer meant to carry the heaviest ordnance
  in the game **is inaudible on the majority of playback systems**. Without harmonic generation
  there is nothing left to hear.
- The sweep is **upward-resolving** (`1 + 0.6*exp(-t/0.06)` starts 60% HIGH and falls to f_low over
  60 ms) — that is a 60 ms chirp, far too fast to read as anything but a click artefact. A real
  fireball's radiated pitch falls over ~0.3–0.5 s as it expands.

### 1.4 The broadband body is shorter for an artillery shell than for a rifle
`:277` — `gas = noise * expdecay(n, p["blast_tau"] * 4.0, ...)`.

Compare `muzzle_blast` (`:69`), which uses **`blast_tau * 22.0`**. So:
- grenade: `blast_tau` 0.0016 → gas tau **6.4 ms**
- heavy:   `blast_tau` 0.0060 → gas tau **24 ms**

An M16 report (`0.00032 * 22` = 7.0 ms) has a *longer* relative gas window than a 155 mm shell. The
multiplier `4.0` is simply wrong — it was tuned for a bang, not a detonation. Real HE roars broadband
for 200–600 ms before handing to the environment. **This is why the explosion "ends" instantly.**

### 1.5 `bark_hz` is a dead parameter — an ADR-023 fossil in the tuning table
`weapon_voices.py:207-217` sets `bark_hz` on all four explosions (340 / 430 / 520 / 190 Hz).
`render_explosion` (`gen_weapon_audio.py:270-307`) **never reads it.** It is a tuning knob that
turns nothing, sitting in the file whose docstring says "if a gun sounds wrong, fix it HERE"
(`weapon_voices.py:3-4`). Either wire it (recommended — it is exactly the low-mid body resonance the
render lacks) or delete it. Leaving it is a lie in the map.

### 1.6 `debris` is applied twice, and the window closes at 0.9 s
`:291` builds `int(70 * p["debris"])` ticks. `:298` scales the hiss by `p["debris"]`. Then `:300`
multiplies the whole debris bed by `p["debris"]` **again**. For `explosion_40mm` (0.35) that is
0.1225 on an already-sparse 24-tick bed — the debris is effectively inaudible.

`:292` — `at = rng.uniform(0.03, 0.9) ** 1.4`. Ceiling 0.9 s, and `**1.4` pushes the distribution
toward the front. Real frag and thrown dirt fall for **1.5–4 s**, and it is the *last* clod landing at
2.6 s that tells you how much earth went up. The window is roughly a third of what it needs to be for
heavy ordnance.

### 1.7 Brightness values are firework values
5200–8400 Hz lowpass on broadband noise (`weapon_voices.py:207-217`). An HE detonation heard at
20–100 m has its spectral centroid **well under 1 kHz**; the >5 kHz content is only frag whizz and
debris, which should be a *separate, sparse* layer, not the body of the sound. A wide white-ish band
lowpassed at 7.2 kHz reads as "firecracker/hiss". The body needs to be a stack (sub / low-mid /
frag band), not one lowpass.

### 1.8 One render per class, forever — no variants
`:272` — `_seed(xid, "expl", 0)`. A single deterministic seed. `main()` at `:457-458` emits exactly
one file per class. Weapons get **three** genuinely different renders (`:445`) precisely because
`render_near`'s docstring says one shot pitch-shifted is not three shots (`:143-144`). Explosions get
**zero**, and playback varies them by ±5% pitch only (`audio_manager.gd:383`). During a mortar walk
(`siege_director.gd:266-278`, `MORTAR_VOLLEY = 3`, `:50`) the player hears the *identical waveform*
three times a second. Repetition fatigue is instant.

### 1.9 No time-of-flight separation, at any layer
Nothing anywhere delays an explosion by propagation time. `play_explosion_3d`
(`audio_manager.gd:368-389`) plays immediately at the impact position. `MORTAR_TUBE_STANDOFF = 700.0`
(`siege_director.gd:51`) — a tube 700 m out should be heard **2.05 s** after it fires; a shell landing
340 m away arrives ~1 s after the flash. In-game there is no flash-then-report gap anywhere in the
ordnance chain, while `render_distant()` (`:186-193`) goes to real trouble to ship exactly that gap
for rifles. The bigger the ordnance, the more the missing delay costs, because big things are
usually far.

### 1.10 The saturation order flattens the transient the code elsewhere protects
`:286` saturates `front + gas + rumble` **together**, then `:306` saturates the whole mix **again**
after reverb. `muzzle_blast` explicitly refuses to do this (`:85-87`: "Saturating the front flattens
the transient, and the transient is the entire perception of weight"), and `render_near` refuses a
second pass (`:169-170`). The explosion path violates both rules the weapon path learned.

### 1.11 One fixed render at ALL distances
There is no `render_explosion_distant()`. Weapons have one (`:174`). At 400 m an explosion should be
almost pure low-frequency thud plus roll, with the frag/hiss band gone entirely. In-game the only
distance processing is the voice's `attenuation_filter_cutoff_hz` — and `play_explosion_3d` never
sets it, so the pool default of **5000 Hz** (`audio_manager.gd:84`) applies: an artillery shell at
600 m is the near-field render with a gentle 5 kHz shelf. It sounds like a small explosion played
quietly, which is exactly the complaint.

---

## 2. PRESCRIPTION — REBUILT `render_explosion()`

### 2.1 New / changed `EXPLOSIONS` dict keys (`weapon_voices.py:204`)

Add: `dur`, `gas_tau`, `sub_tau`, `sub_sweep`, `slap_ms`, `returns`, `return_lp`, `frag`,
`debris_end`, `peak`, `variants`. Retune `f_low`. **Wire `bark_hz` or delete it.**

| key | grenade | 40mm | rocket | **mortar** (new) | heavy | **bomb** (new) | **napalm** (new) |
|---|---|---|---|---|---|---|---|
| `dur` s | 2.2 | 1.8 | 2.4 | 5.0 | 6.5 | 8.0 | 4.5 |
| `blast_tau` s | 0.0016 | 0.0008 | 0.0011 | 0.0034 | 0.0060 | 0.0090 | **0.0** (no front) |
| `gas_tau` s | 0.16 | 0.09 | 0.22 | 0.34 | 0.45 | 0.60 | 1.60 |
| `brightness` Hz | 4200 | 5400 | 5000 | 2600 | 2000 | 1700 | 3000 |
| `bark_hz` Hz | 340 | 520 | 430 | 240 | 190 | 150 | 300 |
| `f_low` Hz | **78** | **110** | **95** | **58** | **48** (was 38) | **42** | 70 |
| `sub_tau` s | 0.55 | 0.35 | 0.90 | 1.40 | 1.80 | 2.40 | 1.10 |
| `sub_sweep` | −0.18 / 0.35 s | −0.12 / 0.25 | −0.16 / 0.30 | −0.22 / 0.45 | −0.25 / 0.50 | −0.28 / 0.60 | −0.10 / 0.8 |
| `slap_ms` ms | 8 | 6 | 9 | 14 | 22 | 28 | 18 |
| `returns` n | 2 | 1 | 2 | 4 | 5 | 6 | 3 |
| `return_lp` Hz | 700 | 900 | 900 | 1200 | 1100 | 900 | 800 |
| `frag` 0-1 | 0.85 | 0.60 | 0.55 | 0.45 | 0.30 | 0.25 | **0.0** |
| `debris` | 0.55 | 0.35 | 0.40 | 0.85 | 1.00 | 1.20 | 0.30 |
| `debris_end` s | 1.6 | 1.1 | 1.7 | 3.6 | 4.6 | 6.0 | 2.5 |
| `drive` | 2.0 | 1.8 | 2.1 | 2.3 | 2.4 | 2.5 | 1.5 |
| `env` | jungle | jungle | open | **valley** | **valley** | **valley** | open |
| `wet` | 1.4 | 0.9 | 1.6 | 2.4 | 2.6 | 2.8 | 1.8 |
| `peak` | 0.82 | 0.72 | 0.88 | 0.94 | 0.99 | 1.00 | 0.86 |
| `variants` n | 3 | 3 | 3 | 4 | 3 | 2 | 2 |

Note the `brightness` values are **halved or worse** from current. The current 7200–8400 Hz is
firecracker territory; explosions are dark.

### 2.2 New `ENVIRONMENTS` preset (`weapon_voices.py:222`)
```
"valley": (5.60, 1.35, 3000.0, 0.038, 0.22),
```
5.6 s length, 1.35 s decay constant, sparse (0.22) so the early part reads as discrete slaps, not a
wash. **Without this preset, no amount of layer work will produce artillery roll** — see §1.1.

### 2.3 Layer order and parameters for the new render

Render at `n = int(SR * p["dur"])`. `t = 0` is the detonation.

**A. Front (transient).** `friedlander(n, blast_tau)` → `highpass(90 Hz)` (currently unfiltered; the
infrasonic lobe only eats headroom). Gain **1.0**. Skip entirely when `blast_tau == 0.0` (napalm).
**Do not saturate this layer.**

**B. Gas roar (body).** `noise * expdecay(n, gas_tau, rise=0.0006)` → `lowpass(brightness, q=0.7)` →
`highpass(150 Hz)`. Gain **0.85**. This replaces `blast_tau*4.0` — see §1.4.

**C. Bark (low-mid body).** `bandpass(B_source, bark_hz, q=1.1)`, gain **0.55**. This finally uses
`bark_hz` (§1.5). It is the layer that gives the *woody thud* between the sub and the hiss.

**D. Sub, as a pair, not a sine.**
- D1 narrowband noise: `noise * expdecay(n, sub_tau, rise=0.004)` → `bandpass(f_low, q=1.2)`, gain 0.55.
- D2 tonal: `sin(phi) + 0.5*sin(2*phi) + 0.22*sin(3*phi)`, where phi integrates a **downward** sweep
  `f_low * (1 + sub_sweep * (1 - exp(-t/sweep_tau)))` (i.e. pitch *falls*), enveloped by
  `expdecay(n, sub_tau, rise=0.003)`, gain 0.65.
The 2nd and 3rd harmonics are non-negotiable: they are why a 48 Hz fundamental is audible on a
laptop (§1.3).

**E. Non-linear low tail (NEW).** `lowpass(saturate((D1+D2) * 2.6, 2.2), 240 Hz)`, gain **0.35**.
Harmonic generation from the fundamental — this is physically what soil/structure transmission does
to overpressure, and perceptually it is the "felt" component.

**F. Ground slap (NEW).** Take `(A + B + C)`, `lowpass(1800 Hz)`, place at `slap_ms/1000`, gain
**0.60**. One discrete mirror reflection. Cheap; enormous effect.

**G. Terrain returns (NEW).** For `k in range(returns)`: place `lowpass(A+B+C, return_lp)` at
`t_k = 0.11 * (k+1)**1.35 * rng.uniform(0.85, 1.2)` with gain `0.30 * 0.68**k`. Progressively darker:
`return_lp * 0.85**k`. **This is the layer that reads as SCALE.** For `heavy` that puts returns at
roughly 0.11 / 0.28 / 0.49 / 0.73 / 1.00 s — the valley answering.

**H. Frag whizz (NEW, frag ordnance only).** `int(20 * frag)` chirps in `t ∈ [0.02, 0.40]`: 4–9 ms
of noise, `bandpass` swept **downward** 6500 → 2200 Hz across each chirp (Doppler as it passes),
gain `rng.uniform(0.08, 0.22)`. Gate on `frag > 0`.

**I. Debris.** `int(120 * debris)` ticks (was 70), `at = rng.uniform(0.05, debris_end) ** 0.9` (was
`0.9 ** 1.4`), two classes: 70% bright ticks `bandpass(1500-7000, q=3)` as today, **30% low clods**
`lowpass(600 Hz)` thumps placed in the back half. **Remove the double `* p["debris"]` at `:300`.**

**J. Reverb.** `_ir(env, rng, scale = dur / 2.8)`, wet as tabled. Convolve the **dry sum
excluding F and G** (they are already reflections; convolving them doubles the smear).

**K. Saturation and level.** Saturate **B+C+D+E only** (`drive`), never A, never F/G, and **remove
the second post-reverb `saturate(out, 1.2)` at `:306`**. Normalise to per-class `peak`, not 0.96.
`fade_out(140 ms)` for the long classes (60 ms currently, which chops the roll).

### 2.4 Variants and distance
- Emit `f"{xid}_{v}.wav"` for `v in 1..variants` with `_seed(xid, "expl", v)`, jittering `f_low`
  ±6%, `gas_tau` ±12%, and re-rolling the return/debris RNG. Extend `audio_manager.play_explosion_3d`
  to round-robin exactly as `_next_fire` does (`audio_manager.gd:210-216`).
- Emit `f"{xid}_dist.wav"`: render at `dur * 1.4`, `air_absorb(x, 500.0)`, drop layers A/H entirely,
  gain-down B by 12 dB, keep D/E/G at full, wet ×1.6. Select it in `play_explosion_3d` above a
  distance band, mirroring `play_shot_3d`'s `DISTANT_BAND_M` logic (`audio_manager.gd:247-254`).

### 2.5 Playback fixes (the §0 headline), `audio_manager.gd:368-389`
Replace the hardcoded 6.0 / 600.0 / 30.0 with a per-kind table:

| kind | volume_db | max_distance | unit_size | atten_cutoff_hz | duck_ms | tof |
|---|---|---|---|---|---|---|
| explosion_40mm | +2 | 300 | 18 | 5200 | 200 | no |
| explosion_grenade | +4 | 380 | 22 | 4800 | 260 | no |
| explosion_rocket | +6 | 480 | 26 | 4600 | 300 | no |
| explosion_mortar | +9 | 900 | 40 | 3400 | 450 | **yes** |
| explosion_heavy | +11 | 1400 | 48 | 2600 | 600 | **yes** |
| explosion_bomb | +12 | 1800 | 54 | 2200 | 750 | **yes** |
| explosion_napalm | +7 | 700 | 34 | 3800 | 500 | yes |

`tof` = delay playback by `distance / 343.0` seconds when > 120 m. That one line buys the
flash-then-boom that §1.9 says is missing everywhere, and it costs a timer.

### 2.6 The curated real-recording layer
`audio_manager.gd:11-12` already documents the contract: *"Drop a real recording at the same path to
replace a synth render."* `_try_load` (`:169`) is path-based, so a real WAV at
`assets/audio/sfx/explosions/explosion_heavy_1.wav` shadows the synth with **zero code change**.
Recommendation: keep the synth as the guaranteed floor (it regenerates, it is licence-clean, it
covers every class), and curate real recordings **only** for the classes the player hears most and
loudest — `explosion_mortar`, `explosion_heavy`, `explosion_grenade`, plus the siren. Everything else
stays synth. Two rules: (1) a curated file must pass the same acceptance gate as the synth render it
replaces, or the size ladder breaks; (2) record its licence in the manifest — `game_world.gd:266-267`
already carries a "license unclear" dev-asset warning for `jungle_day.mp3`, and that is a shipping
risk we should not repeat.

---

## 3. THE AIR-RAID SIREN

### 3.1 Current state: nothing
Repo-wide grep for `siren|alarm|klaxon` across `scripts/`, `scenes/`, `assets/audio/` returns **no
audio asset and no playback path**. Every hit is the AI *detection* alarm (`enemy_base.gd:763`,
`:786`, `field_director.gd:112`, `civilian.gd:245`). There is no siren in this game.

Mount points exist: `site_planner.gd:780` names `tower_los_point_001`, and `:796` assigns a `sentry`
to it. Tower ladders are built at `site_planner.gd:1047`. Hook: `siege_began(strength, is_probe)`,
`siege_director.gd:56`.

### 3.2 The physics — why a sine is wrong
A motor-driven siren is a **rotor with N ports spinning inside a stator with N ports**. Airflow from
a blower is *chopped* — the radiated pressure is close to a duty-cycled square, not a sine. It is
therefore rich in **both odd and even harmonics**, and the timbre is a hard, brassy buzz.

`f0 = (rpm / 60) * n_ports`

Standard civil-defence units are **dual-tone**: two rotor rings with different port counts on one
shaft, so you get two fundamentals a fixed musical interval apart, beating. Use **10 and 12 ports**
(a 5:6 ratio ≈ a minor third). At 1900 rpm that is **317 Hz and 380 Hz** — the classic air-raid
colour. The wail comes from the *shaft speed* changing, so both tones sweep together and the
interval stays locked. That locked interval is the tell; two independently-swept oscillators sound
like a synth, not a siren.

The horn is a flared acoustic transformer with a cutoff near 180 Hz. It radiates almost nothing
below that and rolls off hard above ~5 kHz.

### 3.3 Synthesis recipe

**Per-chopper voice** (build twice, ports = 10 and 12, sum at 0.62 / 0.48):
```
phi   = 2*pi * cumsum(rpm(t)/60 * ports) / SR
y     = sum_{k=1..14} (1/k**0.85) * sin(k*phi + k*0.15)
y     = saturate(y * 1.6, 1.4)          # hardens toward the chopped square
```
The `k*0.15` phase skew asymmetrises the duty cycle — a zero-phase harmonic stack has an
unnaturally spiky waveform.

**Blower / air layer** (this is what separates a real siren from a synth lead):
```
air = noise * (0.6 + 0.4 * sign(sin(phi_10)))     # chopper-gated broadband
air = bandpass(air, 1400, q=0.6)                   # 400-2500 band
mix at -22 dB
```

**Motor whine**: `sin(2*pi*cumsum(rpm/60 * 2)/SR)` at **−26 dB** — the armature, 2× shaft rate. Sub-
audible on its own; its absence is felt.

**Horn body**: `mix += bandpass(mix, 900, q=0.8) * 0.25`, then `lowpass(6500, passes=2)` and
`highpass(170, passes=2)` — the flare's cutoff. The highpass matters: it keeps the siren off the
low bus where the artillery lives.

### 3.4 Envelopes, and the three files

**Three files, not one long one.** A siege runs three nights (`siege_director`, ADR firebase-siege
decree); a single fixed-length one-shot either cuts off or bloats. Three parts give arbitrary
duration for ~20 s of PCM.

| file | length | rpm curve | loop |
|---|---|---|---|
| `siren_spinup.wav` | **4.5 s** | `1900 * (1 - exp(-t/1.6))` | no |
| `siren_loop.wav` | **8.0 s** = 2 wail cycles | `1150 + 750*(0.5 - 0.5*cos(2π t/4.0))` | **yes** |
| `siren_spindown.wav` | **7.0 s** | `1900 * exp(-t/2.6)` | no |

Amplitude follows `(rpm/1900)**1.5` in all three — radiated power rises steeply with tip speed, and
this is why a real siren "arrives" rather than fades in.

**The asymmetry is the whole thing.** Spin-up reaches speed in ~4.5 s under load; coast-down takes
~7 s on rotor inertia with no load. A generator that mirrors the two ramps sounds synthetic
immediately. Also: on spin-down the **blower noise outlasts the tone** — keep the air layer's
envelope 1.5 s longer than the tonal layer, and let the tone drop out below ~250 rpm (below that the
chopper stops making a pitch and just makes wind).

Wail cycle length 4.0 s (2.0 s up, 2.0 s down) — raised cosine, so there is no corner at the top or
bottom of the sweep. Sweep range 1150→1900 rpm gives f0(10-port) **192 → 317 Hz**, a ratio of
**1.65** — right in the perfect-fifth-to-minor-sixth band that reads as "air raid" rather than
"police car" (which is faster and narrower).

### 3.5 Seamless looping — do this exactly, it is the part that goes wrong

1. **Integrate phase; never use `sin(2π f t)`.** `phi = 2π * cumsum(f)/SR` (the codebase already
   does this correctly at `gen_weapon_audio.py:82` and `:283`).
2. **Close the phase on the SHAFT, not on a chopper.** Compute the loop's total shaft phase
   `Φ = 2π * sum(rpm/60)/SR`. Let `k = round(Φ / 2π)`. Rescale the entire rpm curve by `k*2π/Φ`.
   Because both chopper phases are *integer multiples* of the shaft phase (10× and 12×), closing the
   shaft closes **every** chopper and **every** harmonic automatically. Closing a chopper instead
   does not have that property and will leave the other tone with a seam.
3. Residual assertion: `abs(Φ_final mod 2π) < 1e-3 rad`. Print it in `--report`.
4. **The noise layer cannot phase-close.** Equal-power crossfade its last 60 ms over its first 60 ms
   — noise only. **Do not crossfade the tonal layer**; phase closure already made it seamless and a
   crossfade would smear the harmonics.
5. Handoff: the spin-up's final rpm and phase must equal the loop's opening rpm and phase. Build all
   three from one rpm-curve function and one phase accumulator, then slice.
6. **Emit the sidecar with `loop_mode=1`.** `write_import` already takes a `loop` flag
   (`gen_weapon_audio.py:328`, used at `:351`) but **`emit()` never passes it** (`:358-364`) — it is
   dead plumbing. Extend `emit(subdir, name, samples, loop=False)`. The alternative — setting
   `loop_mode` in GDScript at runtime as `game_world.gd:276` / `:292` / `mission_weather.gd:127` do —
   works but scatters the fact across scripts. The sidecar is the honest fix, and it makes
   `loop_end` exact rather than `data.size()/2`.

### 3.6 Placement in the world
One `AudioStreamPlayer3D` per tower at `tower_los_point_001` (`site_planner.gd:780`):
`max_distance = 900`, `unit_size = 60`, `attenuation_filter_cutoff_hz = 3800`. Multiple towers give
real inter-tower phasing and arrival-time spread for free, which is exactly how a firebase sounds.
**Do not** route it through the pooled gunshot voices (`audio_manager.gd:78-89`) — a sustained loop
would occupy a voice for minutes and the stealing logic at `:291-310` would fight it. Give it its own
node, like the gunship drone does (`spectre_gunship.gd:78`).

Wire: `siege_began` → spin-up, then loop; `siege_ended` (`siege_director.gd:57`) → spin-down.
Duck: the siren should duck the ambience *hard* and *long* — reuse `duck_ambience()`
(`audio_manager.gd:397`) with a repeating hold, or better, give the siren its own bus so the wail
sits above the jungle without pumping it.

---

## 4. HEAVY WEAPONS AND ORDNANCE WITH NO VOICE AT ALL

`WEAPONS` keys (`weapon_voices.py:61-197`): m16a1, car15, m60, m1911, thompson, m79, m72_law, ak47,
sks, rpd, ppsh41, mosin, rpg2, rpg7, mp40, kar98k.
`data/weapons/*.tres` ids: ak47, car15, m14, m16a1, m1911, m26_grenade, m60, m70, m72_law, m79,
mosin, ppsh41, rpd, rpg2, rpg7, shotgun.

### 4.1 Shipping weapons with NO entry in the tuning table
`main()` resolves work from `list(WEAPONS.keys())` (`gen_weapon_audio.py:434`). A weapon absent from
`WEAPONS` **can never be regenerated**. Three are in that state, and two of them have orphan WAVs on
disk that no tool can reproduce:

- **`m14`** (M14 battle rifle, armory tier 1). Not in `WEAPONS`. On disk: `fire_m14_1.wav`,
  `fire_m14_dist.wav`, `reload_m14.wav` — **orphans**. Missing: `fire_m14_2.wav`,
  `fire_m14_3.wav`, `mech_m14.wav`. (Suggested entry: bore 7.62, powder 2.95 g, barrel 559 mm,
  mv 850, crack 0.94, f_low 104, brightness 8600, bark 820, drive 1.7, blast_tau 0.00052.)
- **`m70`** (Winchester Model 70, the sniper rifle, tier 3). Not in `WEAPONS`, and **not in
  `BOLT_GUNS`** either (`gen_weapon_audio.py:37` lists only kar98k and mosin) — so `bolt_m70.wav`
  is doubly unregenerable. On disk: `fire_m70_1.wav`, `fire_m70_dist.wav`, `bolt_m70.wav` — orphans.
  Missing: `fire_m70_2.wav`, `fire_m70_3.wav`, `mech_m70.wav`, `reload_m70.wav`.
- **`shotgun`** (Ithaca 37, 9-pellet 00 buck). **Nothing at all** — no table entry, no file. It falls
  through `_fallback_for` (`audio_manager.gd:201-207`) to `shot_rifle.wav`. **The shotgun in this
  game currently makes a rifle noise.** Missing: `fire_shotgun_1/2/3.wav`, `fire_shotgun_dist.wav`,
  `mech_shotgun.wav`, `reload_shotgun.wav`, and `pump_shotgun.wav` (which additionally has no
  playback path — the pump cycle is silent).
- **`m26_grenade`** is a `WeaponData` with `base_damage 190` and no sound of any kind. Missing:
  `pin_m26.wav` (spoon ping + pin), `throw_m26.wav`, `bounce_m26.wav`. Pulling a pin is silent.

### 4.2 Stale renders — table entry exists, files do not
`_fire_variants` (`audio_manager.gd:180-189`) silently collapses to whatever is on disk. Only
m1911, ppsh41, m72_law, m79, rpg2, rpg7, m60 have all three variants. **ak47, m16a1, car15, mosin,
rpd have only `_1`** — the round-robin at `:214-216` is a no-op for the two most-fired guns in the
game. Missing: `fire_{ak47,m16a1,car15,mosin,rpd}_{2,3}.wav`, `fire_car15_dist.wav`.
This is a re-run of the generator, nothing more.

### 4.3 Table entries with no weapon — probable ADR-023 fossils
`thompson`, `sks`, `mp40`, `kar98k` are in `WEAPONS` with full parameter sets and have **no `.tres`
and no rendered files**. Either they are planned (then they need `.tres`) or they are dead tuning
(then delete). Right now they read as live.

### 4.4 Ordnance with no voice — this is the bulk of the "heavy weapons sound weak" complaint

**Mortars — the entire chain is missing three sounds.**
- `mortar_tube_thump.wav` — outgoing. `siege_director.gd:287` and `field_director.gd:656`, `:662`,
  `:672`, `:682` fire shells with **no launch sound at all**. A 700 m standoff tube
  (`siege_director.gd:51`) firing silently is why the siege has no dread.
- `incoming_whistle.wav` — the descending shriek, ~2.5 s, needs to start before impact. **Zero
  warning currently exists.**
- `explosion_mortar.wav` — impacts call `play_explosion_3d` with the **default kind**
  (`field_director.gd:641`, `:700`, `:812`; `siege_director.gd:299`), i.e. `"explosion_grenade"`.
  **An 81 mm shell with `MORTAR_DAMAGE = 140` and an 18 m blast radius sounds like an M26 hand
  grenade.** This is the single worst audio-to-lethality mismatch in the build.

**Artillery / fire missions** — same three, `arty_outgoing.wav`, `arty_incoming.wav`,
`explosion_arty.wav`. `field_director.gd:809` applies 140 damage over `MORTAR_BLAST_M` and plays the
grenade sound at `:812`.

**CAS (`scripts/vehicles/cas_airplane.gd`)** — has **no engine sound whatsoever**. Missing:
`jet_pass.wav` (approach/overhead/depart), `jet_dist_loop.wav`.
- `explosion_bomb.wav` — `:189` and `:208` use `"explosion_heavy"`. Note these are the **only two
  consumers of `explosion_heavy` in the entire game**; nothing else ever plays it.
- **`:243` plays `"explosion_grenade"` for the NAPALM canister.** Napalm is a *roar with no
  detonation front* — a whoosh and a sustained fire bed. It currently sounds like a hand grenade.
  Missing: `explosion_napalm.wav`, `napalm_burn_loop.wav`.
- `cbu_bomblet.wav` — the CBU submunitions (`:26-27`) have no distinct voice.

**Spectre gunship (`scripts/vehicles/spectre_gunship.gd`)** — `:146` plays only the **impact**
(`"explosion_40mm"`). **The Bofors gun itself is silent.** Missing: `fire_bofors_40mm.wav`, and the
`brrrt` of the miniguns if they exist. Additionally `:73` loads **`rotor_loop.wav`** as its drone —
a four-engine turboprop running a helicopter rotor loop. Missing: `c130_drone_loop.wav`.

**Helicopter (`scripts/vehicles/helicopter.gd`)** — grep for audio in that file returns **nothing**.
The Huey is **completely silent**: no rotor, no turbine, no flyby, no landing. Rotors are animated in
code (`:37-38`, `MAIN_ROTOR_SPEED`, `:27`) with no sound attached. Given the DEMO ship gate names
"Huey landings with troops" as a gate item, this is a **ship blocker**. Missing:
`heli_rotor_near_loop.wav`, `heli_rotor_far_loop.wav`, `heli_flyby.wav`, `heli_startup.wav`,
`heli_shutdown.wav`, `heli_blade_slap.wav` (the transient-flare *whop* — the sound everyone
associates with a Huey, and it only happens in descent/turn).

**Emplacements.** `mg_emplacement.gd:164` loads `m60.tres` — correct, but a mounted M60 firing from
inside a sandbagged bunker wants the reflection: `fire_m60_mount_1..3.wav` (same synth, `env` forced
to a short hard IR). `mortar_pit.gd` has **no audio references at all**.

**Demolitions and destruction, all playing the grenade sound:**
- `claymore.gd:61` → default grenade. Missing `explosion_claymore.wav` (a flat, directional CRACK
  plus 700 ball bearings — a *frag-forward*, sub-light profile).
- `sapper_charge.gd:72` → explicitly `"explosion_grenade"`. Missing `explosion_satchel.wav`.
- `destructible.gd:78` → default grenade for a **vehicle** dying. Missing `vehicle_cookoff.wav`.
- `fellable_tree.gd:114` → default grenade for a **falling tree**. Missing `tree_fall.wav`. A tree
  going down should be a creak, a crack, and a long foliage crash — not an explosion.
- `player.gd:619` → default grenade.
- `squad_system.gd:389` → default grenade.

**Siren:** `siren_spinup.wav`, `siren_loop.wav`, `siren_spindown.wav` — none exist (§3.1).

### 4.5 The structural fix
Add a probe (suite-resident, in the spirit of `tests/test_fossils.tscn`) asserting
`set(WEAPONS.keys()) ⊇ {id for each data/weapons/*.tres}` and that every `id` has 3 fire variants +
dist + mech + reload on disk. That single check catches m14, m70 and shotgun today and makes the
orphan-WAV class of defect impossible to reintroduce.

---

## 5. ACCEPTANCE GATES

`_acceptance()` (`gen_weapon_audio.py:399-425`) covers **only weapons** — its rows come from
`spectral_report()` (`:376`), which calls `render_near(wid)` and indexes `WEAPONS[wid]` at `:392`.
**Explosions are completely ungated**, and so is anything we add. Two new report modes.

### 5.1 `explosion_report()` — metrics
Per render: `centroid`; band fractions `sub` (30–90 Hz), `low` (90–250), `lowmid` (250–1000),
`hi` (>4 k); `crest_db`; `t60_ms` (peak → −60 dB); `late_frac` (energy after t = 0.5 s / total);
`returns_n` (local maxima in a 20 ms-smoothed envelope between 0.08 s and 0.8 s that sit ≥6 dB above
the local floor — this directly proves layer G exists).

### 5.2 `_acceptance_x()` — thresholds

| metric | 40mm | grenade | rocket | mortar | heavy | bomb |
|---|---|---|---|---|---|---|
| centroid Hz | 550–1700 | 400–1400 | 500–1600 | 220–800 | 150–600 | 120–500 |
| `sub` (30–90) | ≥0.03 | ≥0.06 | ≥0.05 | ≥0.14 | ≥0.18 | ≥0.20 |
| `sub+low` (30–250) | 0.15–0.55 | 0.25–0.70 | 0.22–0.65 | 0.40–0.82 | 0.45–0.85 | 0.50–0.88 |
| `hi` (>4 k) | ≥0.03 | ≥0.04 | ≥0.03 | ≤0.10 | ≤0.08 | ≤0.06 |
| `crest_db` | ≥10 | ≥9 | ≥10 | ≥8 | ≥7 | ≥6.5 |
| `t60_ms` | 700–1600 | 900–2000 | 1000–2200 | 2500–4800 | 3500–7000 | 4500–8000 |
| `late_frac` | ≥0.06 | ≥0.10 | ≥0.12 | ≥0.30 | ≥0.35 | ≥0.38 |
| `returns_n` | ≥1 | ≥2 | ≥2 | ≥3 | ≥4 | ≥4 |
| peak (post-norm) | 0.72±.02 | 0.82±.02 | 0.88±.02 | 0.94±.02 | 0.99±.01 | 1.00±.01 |

### 5.3 Cross-checks (the "M16/AK ratio" analogue at `:419-424`)
These enforce the **size ladder** numerically, which is the thing that is broken today:
- `centroid(heavy) < 0.55 * centroid(grenade)` — arty must be darker. FAIL otherwise.
- `t60(heavy) > 2.5 * t60(grenade)` — arty must roll longer.
- `sub(heavy) > 3.0 * sub(40mm)` — the low ladder must be measurable.
- `rms(last 1.0 s of heavy) > 2.0 * rms(last 1.0 s of grenade)`.
- `peak(heavy) > peak(40mm)` strictly — catches any return of blanket `normalize(0.96)`.
- **Variant distinctness:** max pairwise Pearson correlation between any two variants of the same
  kind **< 0.35** (today there is only one variant, so this fails by construction until §2.4 lands —
  which is the point).
- `explosion_napalm`: `crest_db < 6.0` and `attack_time > 40 ms` — a napalm bloom that has a sharp
  transient is wrong.

### 5.4 `siren_report()` / `_acceptance_siren()`
- **Seam, level:** `abs(loop[0] - loop[-1]) < 0.02`.
- **Seam, slope:** `abs((loop[1]-loop[0]) - (loop[-1]-loop[-2])) < 0.01`. First-difference continuity
  — a phase discontinuity can pass a level check and still click. This is the one that matters.
- **Phase closure:** residual `Φ mod 2π < 0.001 rad`, asserted in the generator, printed in the report.
- **Wrapped RMS:** `rms(concat(loop,loop)[N-2400 : N+2400])` within **1.5 dB** of `rms(loop)` — no
  click, no dip, no pump across the wrap.
- **Harmonic richness:** energy above f0 ≥ **0.55** of total; count of spectral peaks ≥8 dB above the
  local median in 200 Hz–5 kHz must be **≥6**. Proves a chopped port, not a sine.
- **Wail interval:** per-50 ms f0 track across the loop; `max(f0)/min(f0)` in **1.55–1.85**.
  Below 1.55 it reads as a hum; above 1.9 it reads as a police car.
- **Wail period:** exactly **2.00 ± 0.02** complete sweep cycles in the loop file.
- **Ramp asymmetry (the realism gate):** `len(spindown) / len(spinup) ≥ 1.4`. A symmetric
  spin-up/spin-down is the signature of a synth, and a generator will produce it unless forbidden.
- **Chaining:** `abs(spinup[-1] - loop[0]) < 0.03`, **and** f0 at the last 100 ms of spin-up within
  **3%** of f0 in the first 100 ms of the loop. Proves the three files actually join.
- **Band discipline:** ≥**0.70** of energy in 200 Hz–5 kHz; **<0.05** below 120 Hz. A siren horn does
  not radiate bass — if it does, the motor layer is leaking and it will mask the artillery.
- **Crest ≤ 6 dB.** A siren is sustained; high crest means the tone is dropping out mid-wail.
- **Sidecar:** assert the emitted `.import` for `siren_loop.wav` contains `edit/loop_mode=1` — the
  flag `emit()` currently cannot set (`gen_weapon_audio.py:358-364`).

### 5.5 Wiring
Add `--report-x` and `--report-siren` alongside the existing `--report` (`:433`, `:436-440`), and
run all three in `run_all_tests.ps1` so a bad render fails the build rather than shipping quietly.

---

## 6. WHAT THIS COSTS (no free lunches)

- **Render time.** `_biquad` is a per-sample Python loop (`audio_dsp.py:43-55`). Going from 2.8 s to
  6.5–8.0 s per explosion, times 2–4 variants, times a distant render, times 7 classes, is roughly a
  **15–20× increase** in explosion render cost. It is a build-time tool, so this is patience, not
  frame budget — but it will go from seconds to a few minutes.
- **Memory.** `write_import` sets `compress/mode=0`, i.e. **uncompressed PCM** (`:354`), justified for
  short transients. An 8 s mono 48 kHz explosion is ~768 KB; the full new set runs to roughly
  **20–30 MB** of PCM. The distant/long classes should move to `compress/mode=2` (Qoa/Vorbis) — the
  transient argument does not apply to a 6-second roll. The near/short classes stay PCM.
- **The low bus gets crowded.** Siren, artillery sub, helicopter rotor and the distant-war loop
  (`game_world.gd:290`) will all compete. The siren's 170 Hz highpass (§3.3) is deliberate for this
  reason, and the artillery's sub layer will need to duck the ambience harder than the current
  `DUCK_DB = 8.0` (`audio_manager.gd:52`).
- **Real recordings cost licence risk and cannot be regenerated.** `game_world.gd:266-267` already
  carries one "license unclear" dev asset. Every curated file must be licence-logged, and every one
  must still pass §5 — otherwise the curated layer silently breaks the size ladder the synth gate
  was built to protect.
- **Time-of-flight delay (§2.5) changes gameplay feel**, not just audio. A player will see the flash
  before the boom and may read it as a bug on first contact. It is correct, it is Vietnam, and it is
  worth it — but it should ship with the mortar work, not sneak in.
