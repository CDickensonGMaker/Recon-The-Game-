# SYSTEMS / AUDIO DESIGNER — Audio Pack Integration

War Room 2026-07-27. Lens: does the swap produce believable firefights (Pillar 1) and atmosphere
(Pillar 2)? Read the code, not the plan. Every number below is measured or a `file:line`.

---

## 0. MEASURED GROUND TRUTH (probed this session)

### 0.1 The existing placeholder family

`python wave` dump of `assets/audio/sfx/weapons/`:

| file | dur | rate | ch | peak | rms |
|---|---|---|---|---|---|
| `fire_ak47_1/2/3.wav` | 0.750 s | 48000 | 1 | −0.7 dB | −23.2 / −24.5 / −24.3 |
| `fire_ak47_dist.wav` | 1.600 s | 48000 | 1 | −1.9 dB | −21.8 |
| `fire_m60_1.wav` | 0.750 s | 48000 | 1 | −0.7 | −22.8 |
| `fire_ppsh41_1.wav` | 0.750 s | 48000 | 1 | −0.7 | −26.6 |
| `fire_m1911_1.wav` | 0.750 s | 48000 | 1 | −0.7 | −23.7 |
| `mech_ak47.wav` | 0.300 s | 48000 | 1 | −3.1 | −23.5 |
| `reload_ak47.wav` | 2.400 s | 48000 | 1 | −2.9 | −28.1 |
| `bolt_mosin.wav` | 1.500 s | 48000 | 1 | −2.5 | −25.0 |
| `crack_1.wav` | 0.350 s | 48000 | 1 | −0.9 | −19.1 |
| `../shot_rifle.wav` (fallback) | 0.220 s | 22050 | 1 | −0.7 | −16.6 |
| `../shot_smg.wav` | 0.180 s | 22050 | 1 | −0.7 | −15.5 |
| `../shot_pistol.wav` | 0.160 s | 22050 | 1 | −0.7 | −15.1 |

Format of record for the weapons folder: **48000 Hz / mono / 16-bit PCM**. The incoming pack is
44100 / 2ch. Conversion is mandatory (see §5.3).

### 0.2 The mix chain (`assets/audio/default_bus_layout.tres`)

Nobody in this council has cited this file and it changes three of the answers:

- **`Weapons` bus carries a Compressor**: `threshold −12.0`, `gain +3.0`, `attack_us 5000` (**5 ms**),
  `release 120 ms`.
- **`WeaponsTail` bus carries a Reverb at 100 % wet**: `dry 0.0`, `wet 1.0`, `room_size 0.75`,
  `predelay 40 ms`, `damping 0.6`.
- **`Master` carries a Limiter**: `ceiling −0.8`, `threshold −1.0`.

Consequences:
1. The synth placeholders were authored *into* a −12 dB-threshold compressor. Real recordings have a
   far higher crest factor. Peak-normalising them to the same −0.7 dB will make them trigger that
   compressor **less** than the placeholders did, and every gun will land **quieter and thinner**
   than what it replaced. This is the single most likely way this swap regresses Pillar 1 while
   every file "looks correct". Normalise by RMS, then control peaks (§5).
2. `_p_tail` (`audio_manager.gd:41`, routed to `WeaponsTail` at `:92`) plays into **pure reverb**.
   The room is supplied by the bus. Therefore the tail layer must be fed **dry (Isolated)** material.
   Feeding it Full-Sound-derived material double-rooms the shot.
3. Nothing may sit at 0 dBFS. `m60`/`m70`/`mosin` carry `fire_volume_db = 2.0`
   (`m60.tres:33`, `m70.tres:32`, `mosin.tres:32`) and the Master limiter at −0.8 would clamp
   exactly the guns intended to feel biggest.

### 0.3 Live fire rates (`data/weapons/*.tres`, `weapon_data.gd:13` default 600 rpm)

| id | rpm | cycle = 60/rpm | `fire_volume_db` |
|---|---|---|---|
| `ppsh41` | 900 | **66.7 ms** | 0.0 (default) |
| `m16a1` | 750 | 80.0 ms | 0.0 |
| `rpd` | 650 | 92.3 ms | 1.0 |
| `ak47` | 600 (default) | 100.0 ms | 0.5 |
| `m60` | 550 | 109.1 ms | 2.0 |
| `m1911` | 300 | 200 ms | 0.5 |
| `m14` | 240 | 250 ms | 0.0 |
| `shotgun` | 70 | 857 ms | 2.0 |
| `mosin` | 35 | 1714 ms | 2.0 |
| `m70` | 32 | 1875 ms | 2.0 |

### 0.4 What is actually on disk vs what is actually a weapon — THREE FINDINGS

**(a) Five weapons with a full audio set are RETIRED. Loading them FAILS the suite.**
`tests/test_flat_damage.gd:31`:
```
const RETIRED := ["mp40", "kar98k", "car15", "sks", "thompson"]
```
with `:28-30` giving the reason (`mp40`/`kar98k` by ADR-016; `car15`/`sks`/`thompson` by
Amendment C — no FP arms = not a gun in this game). There is no `.tres` for any of them in
`data/weapons/`. **Three of the six derivations put to this council — `thompson`, `kar98k`,
`mp40` — are for weapons that do not exist.** Deriving audio for them is not a downgrade risk, it
is zero-value work on content the test suite forbids. Their 25 wavs (`fire_*_1..3`, `fire_*_dist`,
`mech_*`, `reload_*`, `bolt_kar98k`) are **fossils under ADR-023 and should be deleted in this
same change**, not left as the pack's "coverage".

**(b) Three LIVE weapons have NO audio at all**: `m14`, `m70`, `shotgun`. There is no
`fire_m14_*`, `fire_m70_*`, `fire_shotgun_*`, no `mech_`, no `reload_`, no `bolt_m70`. They fall
silently to the class bank at `audio_manager.gd:143-149` → `shot_rifle.wav`, a 0.220 s 22 kHz
placeholder. **The M70 is the sniper rifle and it currently shares its report with every rifle in
the game.** The derivation budget is being spent on retired guns while live ones are unvoiced.

**(c) Two fossils inside `audio_manager.gd` itself.**
- `_p_dist` (`:42`, built `:94`, torn down `:388`) is **never assigned a stream and never played**.
  A whole player slot that does nothing. Delete it.
- `crack_1.wav` / `crack_2` / `crack_3` have **zero references anywhere in `scripts/`**. Their
  intended driver, `WeaponData.is_supersonic` (`weapon_data.gd:84`), is exported and read by
  nothing but `tests/test_ballistics.gd:102`. This is UNFINISHED, not FOSSIL — see §6.

---

## 1. Three single-report variants from one take

### 1.1 The rule: no synthetic pitch variants. Ever.

`audio_manager.gd:224` (3D) and `:269` (2D player) already apply
`pitch_scale = 1.0 + randf_range(-pv, pv)` with `pv = wd.fire_pitch_variance`, default `0.04`
(`weapon_data.gd:79`) = ±4 % ≈ ±0.7 semitone, **re-rolled on every single shot**. Baking a pitch
offset into the file to manufacture "variants" stacks a fixed offset under a random one and produces
the textbook *same-sample-wobbling* artifact. The runtime already owns pitch. The files must supply
what the runtime cannot: **different envelopes and different spectra from different real shots.**

### 1.2 The recipe (per caliber, Isolated files only)

| variant | source | character | why it differs for real |
|---|---|---|---|
| `fire_<id>_1` | **Single**, Isolated | cleanest transient, longest usable decay | the reference shot |
| `fire_<id>_2` | **shot #2 of Double Tap**, Isolated | fired into the room's still-decaying energy; different shoulder/muzzle position | genuinely different early reflections and a marginally softer attack |
| `fire_<id>_3` | **a MID-burst shot of Burst**, Isolated (shot 2 or 3 — never the first, never the last) | densest and dullest; carries the preceding shot's tail baked in; naturally the SHORTEST | hot chamber, gas-system state, mic compression |

Never slice the **first** shot of Burst/Double-Tap — it is acoustically the Single take again and
will read as a duplicate. Never slice the **last** — it carries the operator's release and the
tail-off. If a caliber's burst shots are too crowded to isolate (fast source cadence), take variant 3
from **Spray shot 5+** instead, which has the most heat/mic-compression divergence from the Single.

The three variants come out at **different lengths** (long / medium / short). That is not sloppy —
it is the point. Round-robin (`audio_manager.gd:152-158`) reading three files with different decay
lengths and densities is what stops a firefight sounding like a loop.

### 1.3 Legal non-pitch variation, if two shots genuinely won't separate

- ±1.5 dB level trim per variant (micro-dynamics under round-robin; well inside the compressor's
  operating range so it does not read as a volume bug).
- Different amounts of environment tail retained before the fade-out.
- Nothing else. No pitch, no time-stretch, no reverse-layered "sweetener".

### 1.4 If a caliber yields only ONE usable shot — ship ONE file

`_fire_variants` (`:122-131`) builds an array from whatever exists and `_next_fire` (`:152-158`)
round-robins over `arr.size()`. A 1-element array is legal and costs nothing. **One honest sample
plus ±4 % runtime pitch beats three fakes.** Copying the same file to `_2` and `_3` is strictly
worse than not creating them — it burns disk and RAM to produce byte-identical output, and it
recreates exactly the defect that makes the current placeholders read as synthetic (measured: all
three ak47 variants are the same 0.750 s / −0.7 dB shape).

### 1.5 Slice boundaries — mandatory, or you will hear it

- Start **3 ms before** the transient, at a **zero crossing**, with a **2 ms linear fade-in**.
  A hard cut into a rising transient is a click at full scale.
- **Exponential fade-out over the final 25 ms to true digital silence.** This is not cosmetic:
  `_acquire_voice` **steals playing voices** (`:250-251`) and `p.play()` restarts a live stream, so
  any sample that does not end at zero will pop when it is cut. The synth placeholders always decay
  to zero; hand-trimmed recordings will not unless you make them.
- **DC-block / 20 Hz high-pass every file.** Up to 24 voices sum on one bus (`:21`); a small DC
  offset multiplied 24× shifts the whole Weapons bus into the compressor.

---

## 2. Near-report duration — the voice pool sets it, not taste

### 2.1 The arithmetic

`GUNSHOT_VOICES = 24` (`:21`). Every 3D shot takes a voice for the **whole length of the stream**.
Voices held by one sustained shooter = `duration / cycle`.

**At the current 0.750 s placeholder length:**

| id | cycle | voices held by ONE shooter |
|---|---|---|
| `ppsh41` | 66.7 ms | **11.2** |
| `m16a1` | 80 ms | **9.4** |
| `rpd` | 92.3 ms | **8.1** |
| `ak47` | 100 ms | **7.5** |
| `m60` | 109 ms | **6.9** |

**Two to three close-range automatic weapons exhaust the entire pool today.** When it is exhausted,
`_acquire_voice` returns `-1` and `play_shot_3d` **drops the shot outright** (`:252`, comment:
"silence beats a clipped transient"). That is a live Pillar-1 defect that predates this pack: the
bigger the firefight, the more shots go silent, and `FAR_SHOOTER_THROTTLE_MS` (`:25`) does not help
because it only engages past `FAR_SHOOTER_DIST_M = 60.0` (`:26`).

Importing longer, richer real recordings **makes this worse**. Importing correctly-budgeted ones
fixes it for free.

### 2.2 The rule

> **Near report duration ≤ 3.0 × (60 / `fire_rate`), hard cap 600 ms.**

| id | cycle | **target duration** | voices/shooter |
|---|---|---|---|
| `ppsh41` | 66.7 ms | **200 ms** | 3.0 |
| `m16a1` | 80 ms | **240 ms** | 3.0 |
| `ak47` | 100 ms | **260 ms** | 2.6 |
| `rpd` | 92.3 ms | **280 ms** | 3.0 |
| `m60` | 109 ms | **320 ms** | 2.9 |
| `m1911` | 200 ms | **220 ms** | 1.1 |
| `m14` | 250 ms | **400 ms** | 1.6 |
| `shotgun` | 857 ms | **450 ms** | 0.5 |
| `mosin` / `m70` | 1714/1875 ms | **600 ms** | 0.35 |

A six-shooter close firefight then costs ≈ 18 of 24 voices, leaving headroom for impacts and the
`play_explosion_3d` top-priority path (`:318-329`). **This is a 40 % cut from the current 0.750 s
and it is the difference between a firefight that keeps every round and one that silently drops
them.**

### 2.3 What the ear actually needs, and what it doesn't

Within 250 ms of a rifle report you have the muzzle blast, the crack, the first-order reflections and
the start of the decay. That is 100 % of the weapon's *identity*. Everything after 250 ms is *room* —
and room is exactly what the `WeaponsTail` reverb bus (`dry 0.0 / wet 1.0 / room 0.75 / predelay 40`)
generates for free at `:279-286`, and what `fire_<id>_dist` carries honestly for far shooters. **Do
not pay 8 voices per gunner for information the bus is already synthesising.**

### 2.4 The player's own gun: a separate, non-obvious problem

`_p_near` is a **single** `AudioStreamPlayer` (`:39`). `play_shot_player` sets `.stream` and calls
`.play()` (`:267-270`), which **restarts** it. On the player's own full-auto weapon there is
therefore **no shot overlap at all, ever** — each round hard-cuts the previous one at the cycle
interval. Real automatic fire is a wash of overlapping decays; the player's M16 currently cannot
produce one at any sample length.

Two options for the Arbiter:
- **(A) Author to it — no code.** Keep the near sample short enough that its natural decay is
  substantially complete inside the cycle. The §2.2 table does not achieve this (240 ms vs an 80 ms
  cycle), so the player's own auto fire will still be an attack-only chatter.
- **(B) Ping-pong `_p_near`.** Replace the single slot with a 2- or 3-element array and alternate on
  each shot. ~6 lines in `_build_player_slots` (`:90-95`) and `play_shot_player` (`:256-270`). This
  is what actually produces overlapping tails and is the single highest-value code change in this
  whole integration for Pillar 1.

I recommend **(B)**, and I note the sacrifice: it is a code change in a script the swap could
otherwise leave untouched, and three concurrent player-gun voices slightly thicken the player's own
mix relative to NPC fire.

### 2.5 The 0.72 tail layer (`:279-286`)

`_p_tail` reuses the **same stream** at `pitch_scale = 0.72` (−5.7 semitones) and `−16.0 dB`, into
the 100 %-wet reverb bus. A 260 ms sample plays for 260/0.72 = **361 ms**.

On a *synth* report this is a cheap weight trick. On a *real* report, a −5.7-semitone copy is
recognisably a different, larger weapon. **However** — measured from the bus layout — it is at
−16 dB and **fully wet**, so what reaches the mix is a diffuse low rumble bed, not a discrete second
event. **Verdict: KEEP the 0.72 layer, but audition it per weapon; if any gun reads as two guns,
drop that layer to −20 dB rather than removing it.** Removing it removes the weight the reports need.

One real bug here: `pitch_scale = 0.72` is applied **unconditionally** at `:285`, including when a
genuine `tail_<id>.wav` exists (`:280`). If anyone ever authors a real tail file it will be pitched
down too. One-line fix at `:285`:
```gdscript
_p_tail.pitch_scale = 1.0 if tail != stream else 0.72
```

And the load-bearing consequence of §0.2: **if a `tail_<id>.wav` is authored, it must be cut from
the ISOLATED (dry) material, not the Full Sound file.** The `WeaponsTail` bus is 100 % wet reverb;
feeding it a recording that already contains its own room double-rooms every shot.

---

## 3. `fire_<id>_dist` — the distant report

### 3.1 What the engine already does, so don't do it twice

- Every pooled voice runs `attenuation_filter_cutoff_hz = 5000.0` (`:83`) — the comment calls it
  "cheap per-voice air absorption".
- The near→dist swap happens at `DISTANT_BAND_M = 85.0` ± `DISTANT_JITTER_M = 6.0` (`:23-24`,
  applied `:189-194`). The jitter is good design — it stops a hard audible ring at exactly 85 m.
- The dist stream plays on the **same pooled 3D voice, same Weapons bus, no reverb** (`:190-204` →
  `_play_voice`). Its room must therefore come from the file. This is the opposite of the tail layer
  and the two must not be treated alike.

**Therefore the dist file's own low-pass must sit well BELOW 5 kHz or the engine's filter dominates
and the near/far swap will be inaudible.**

### 3.2 The recipe

Source: the **Full Sound** file (measured: same take + environmental tail).

1. **DC block / HPF 60–80 Hz**, 12 dB/oct — kills mic and handling rumble that turns to mud when
   several distant shooters sum.
2. **Soften, do not remove, the direct transient.** 8–12 ms fade-in over the attack and −6 to −9 dB
   on the first 15 ms. A distant gun still has an onset; it just is not a *snap*. Removing the onset
   entirely gives you a "whoomph" with no location and the 3D panner has nothing to work with.
3. **Low-pass at 1.6–2.2 kHz, 12 dB/oct.** This is the distance cue and it must beat the engine's
   5 kHz. Steeper than 12 dB/oct starts sounding like a telephone rather than like air.
4. **+2 to +3 dB shelf at 150–250 Hz** (ground-coupled thump), **−4 dB at 800 Hz–1.5 kHz** (the band
   where near-field bite lives).
5. **No added reverb.** The Full Sound take already has the real tail and the Weapons bus is dry.
6. **Length: 600–700 ms.** See §3.3 — this is the constraint, not an aesthetic choice.
7. Exponential fade to digital silence over the last 40 ms (voice-steal click, §1.5).
8. **Do not remove the supersonic crack by hand** — for a shooter 85 m+ away firing *away* from the
   listener there is no crack at the listener at all, and the Full Sound take will not contain one
   pointed at the mic anyway. Leave what the recording has.

### 3.3 The dist duration is a voice-pool decision, and the current file is a pool-killer

`FAR_SHOOTER_THROTTLE_MS = 70` (`:25`) caps one distant firing position at 1000/70 = **14.3 events
per second** (`:183-187`).

- Current `fire_*_dist.wav` = **1.600 s** → 14.3 × 1.6 = **22.9 voices**.
  **A single distant machine gun consumes 95 % of the 24-voice pool.** Everything else in the
  firefight — including the player's allies at 10 m — starts getting dropped at `:252`.
- Proposed **700 ms** → 10.0 voices. Better, still heavy.
- Proposed **700 ms + `FAR_SHOOTER_THROTTLE_MS` raised 70 → 130** → 7.7/s × 0.7 = **5.4 voices**.

Recommend both. The sacrifice, named: distant automatic fire loses per-round articulation and
becomes a rolling texture at ≈ 460 perceived rpm. `audio_manager.gd:180`'s own comment already
declares that the intent — *"a distant MG is a texture, not 11 discrete events"* — the constant
simply does not deliver it at 1.6 s stream lengths.

### 3.4 Level at the crossover

Do not make the dist file quieter to "sound far". Distance is already handled by the attenuation
curve and by `wd.audio_max_distance` / `audio_unit_size` (`:225-227`). The far-ness must come from
the **spectrum**. A level step at the 85 m band would be audible as a bug when the player walks
across it. Match dist true-peak to within ~2 dB of near — measured placeholders do exactly this
(−1.9 vs −0.7) and that part of the current setup is correct.

---

## 4. Derivations — honest confidence, and where I say KEEP THE PLACEHOLDER

Stock: 5.56 · 7.62x39 · 7.62x54R. Launchers out of scope per the briefing.

### 4.1 `m60` — 7.62x51 NATO belt-fed MG

- **Source:** 7.62x54R (Mosin) **Isolated Single**.
- **Why:** 7.62x54R and 7.62x51 are acoustic near-twins — same .30 bullet, near-identical case
  capacity and chamber pressure (174 gr @ ~800 m/s vs 147 gr @ ~840 m/s). This is the closest
  cartridge match available in the pack by a very wide margin.
- **Treatment:** pitch **−4 to −6 %** only (heavier receiver and reciprocating mass read lower);
  low-shelf **+3 dB @ 120 Hz** for the Pig's chest thump; trim to **320 ms** (§2.2); rely on the
  existing `mech_m60.wav` layer (`:273-276`, plays at −8 dB) to supply the gas-system clatter a bolt
  rifle's recording cannot.
- **Confidence: HIGH.** The M60's identity in play is carried by its 550 rpm cadence and
  `fire_volume_db = 2.0` (`m60.tres:33`) far more than by its timbre. **Ship it.**

### 4.2 `ppsh41` — 7.62x25 Tokarev SMG, 900 rpm

- **Source:** 7.62x39 **Isolated**, variant 3 sliced from Spray.
- **Treatment:** pitch **+12 to +18 %**; high-pass **250–350 Hz** to strip the rifle's low boom;
  −3 dB around 200 Hz; trim hard to **200 ms**.
- **Confidence: MEDIUM.** Pitching a rifle up ~15 % into an SMG is a standard, defensible cheat, and
  at a 66.7 ms cycle the ear reads **cadence** before timbre — the PPSh's real signature is its
  buzzsaw rate, which the game already supplies. The risk is that 7.62x39's low end is so dominant
  that rifle body survives the high-pass.
- **Verdict: BUILD IT, THEN A/B IT AGAINST THE PLACEHOLDER BEFORE COMMITTING.** I put it at ~60/40
  to win. This is the one item on the list that genuinely needs the Summoner's ears, not an
  architect's opinion.

### 4.3 `m1911` — .45 ACP pistol

- **Source:** none exists in this pack.
- **Why not:** all three stock cartridges are **supersonic, 50–60 kpsi rifle rounds** whose report is
  dominated by a ballistic crack and a high-pressure muzzle blast. .45 ACP is **~21 kpsi and
  subsonic** — no crack whatsoever, a flat low pop with almost no HF snap. The project's own data
  already asserts this: `tests/test_ballistics.gd:102` requires `m1911.is_supersonic == false`.
  Deriving from a rifle leaves you choosing between shipping a crack the ballistics model says does
  not exist, or filtering so violently that nothing recognisable survives.
- **Confidence: LOW.** **VERDICT: KEEP THE PLACEHOLDER.** A purpose-built synth .45 pop is a better
  .45 than a mutilated 7.62. This is the clearest "worse than placeholder" case on the list, and the
  Summoner explicitly authorised this answer.

### 4.4 `thompson`, `kar98k`, `mp40` — **MOOT: these weapons do not exist**

`tests/test_flat_damage.gd:31` lists all three in `RETIRED`; loading any of them **fails the suite**
(`:28-30`). There is no `.tres` for any of them in `data/weapons/`. `car15` and `sks` are in the
same list and in the same condition.

**Do not derive audio for them. Delete their 25 placeholder wavs** (`fire_{car15,kar98k,mp40,sks,
thompson}_{1,2,3,dist}`, `mech_*`, `reload_*`, `bolt_kar98k`) **and their `.import` siblings** as
part of this change, per ADR-023 — a full audio set for a weapon the suite forbids is a textbook
fossil: it reads as live coverage and it survives every grep.

*(Recorded for a hypothetical revival only: `kar98k` from 7.62x54R at −2 % would be near-perfect —
7.92×57 Mauser and 7.62×54R are acoustic twins. `mp40`/`thompson` share the `m1911` problem and
would also keep their placeholders.)*

### 4.5 THE DERIVATIONS THE COUNCIL WAS NOT ASKED FOR, AND SHOULD DO INSTEAD

These are **live weapons with zero audio files**, currently falling through
`_fallback_for` (`:143-149`) to the 0.220 s / 22 kHz `shot_rifle.wav`:

| id | derivation | confidence |
|---|---|---|
| **`m70`** (Winchester M70, .30-06 bolt sniper, `m70.tres`) | 7.62x54R **Isolated Single**, essentially **untreated** — pitch −2 %, trim to 600 ms. Both are full-power .30-cal bolt-action rifles. This is not a derivation, it is very nearly an exact match. | **VERY HIGH** |
| **`m14`** (7.62x51 NATO, semi, 240 rpm) | Same source and treatment as `m60` (§4.1) minus the low shelf; keep more ring — 400 ms — since the cycle is 250 ms. | **HIGH** |
| **`shotgun`** (Ithaca 37, 12 ga) | No plausible source. **Keep the fallback / placeholder.** | — |

**The sniper rifle currently sounds exactly like every other rifle in the game.** Fixing `m70` and
`m14` from 7.62x54R is higher-value for Pillar 1 than every retired-weapon derivation combined, and
it is *less* risky than the `ppsh41` derivation the council was asked about.

---

## 5. Level normalisation

### 5.1 True peak

- **`fire_<id>_1..3`: −1.0 dBTP.** Matches the measured placeholder family (−0.7) within 0.3 dB, so
  the existing mix balance and every `fire_volume_db` offset in `data/weapons/` stay valid.
  Worst-case player path is `−2.0 + fire_volume_db` (`:268`), max `0.0` for the +2.0 guns → −1.0 at
  the player, just under the Master limiter's −0.8 ceiling. **Do not normalise to 0 dBFS**: the
  +2.0 dB weapons would then be the only ones the limiter squashes, inverting the intended weight.
- **`fire_<id>_dist`: −3.0 dBTP** (placeholder measured −1.9). A touch under near so the 85 m
  crossover never steps *up* in level.
- **`mech_` / `reload_` / `bolt_`: −3.0 dBTP.** Measured placeholders are −3.1 / −2.9 / −2.5 and
  they play at −8.0 / −5.0 / −4.0 dB (`:275`, `:306`, `:296`).

### 5.2 RMS — this is the one that actually matters

Peak-matching a real recording to a synth placeholder makes it **quieter**, because the real one has
a much higher crest factor and triggers the Weapons-bus compressor (`threshold −12`, `gain +3`) less.
Normalise by loudness first:

- **Whole-file RMS: −22 to −25 dBFS.** The measured placeholder family sits at −22.8 to −26.6.
- **The 50 ms window containing the peak: −9 to −12 dBFS RMS.** This is what drives the compressor
  and therefore what determines perceived size.
- **Order of operations: set RMS to target first; then, if true peak exceeds §5.1, control it with a
  1–2 ms transient shave (brickwall/soft-clip on the attack only) — never by pulling the whole file
  down.** Pulling the file down to fix one 1 ms peak is precisely how every gun ends up smaller than
  the synth it replaced.
- `fire_volume_db` (0.0 → +2.0 across the roster) exists to carry per-weapon size. **Normalise every
  file to the same reference and let those offsets do their job** — do not bake relative loudness
  into the files as well, or the M60 gets its +2 dB twice.

### 5.3 Format, and the silent failure it hides

**48000 Hz / mono / 16-bit PCM.** The pack is 44100 / 2ch. Convert **before** import.

`fire_ak47_1.wav.import` currently carries `force/mono=true`, `compress/mode=0`, `edit/normalize=false`.
That flag lives in the **`.import` file, not the wav**. It survives only if the `.wav` is overwritten
**in place at the identical path with the `.import` left alone**. Delete the `.import`, rename the
file, or add a new id, and Godot regenerates it with `force/mono=false` — putting a **stereo stream
on an `AudioStreamPlayer3D`**, which degrades positional panning on the entire NPC voice pool. Nobody
will get an error. This is exactly the class of silent failure the briefing warns about, and it is
why the mono conversion must happen in the source file rather than being delegated to an import flag.

Leave `edit/normalize=false` — normalisation is done offline per §5.1/§5.2, and letting the importer
peak-normalise would destroy the deliberate relative levels.

---

## 6. Deferred, flagged, not proposed

The pack contains real cartridge material and the codebase has an **unfinished** supersonic-crack
feature waiting for it: `WeaponData.is_supersonic` (`weapon_data.gd:84`) is exported and read by
nothing in `scripts/`, and `crack_1..3.wav` (48 kHz, 0.350 s, −19.1 dB RMS) have **zero references
repo-wide**. The overhead crack of incoming rounds arriving *before* the report is the single
strongest "believable firefight" cue in the medium, and it is the one thing this project's audio does
not do. Under ADR-023 triage this is **UNFINISHED (built ahead of its wiring)**, not FOSSIL — wire it
or cut it, but do not let it sit through another audit. I am **not** proposing it in this change;
it is a new system and this is an asset swap. Flagging it so it is a decision rather than a
discovery.

---

## 7. Verdict summary

| item | ruling |
|---|---|
| 3 variants | Single / Double-Tap shot 2 / mid-Burst shot. **No pitch-derived variants** — `:224`/`:269` already own pitch. One honest file beats three fakes. |
| near duration | **≤ 3.0 × cycle, cap 600 ms.** 200–320 ms for autos. Current 0.750 s costs 7–11 of 24 voices per shooter and is dropping shots today at `:252`. |
| player full-auto | `_p_near` is one slot (`:39`) and hard-cuts every round. **Ping-pong it (~6 lines)** or player auto fire cannot overlap at any sample length. |
| dist | Full Sound, LPF **1.6–2.2 kHz** (must beat the engine's 5 kHz at `:83`), softened onset, **600–700 ms**, no added reverb. Raise `FAR_SHOOTER_THROTTLE_MS` 70 → 130 (`:25`). Current 1.6 s = **22.9 voices for one distant MG**. |
| `m60` | 7.62x54R, −5 % pitch, +3 dB @ 120 Hz. **HIGH — ship.** |
| `ppsh41` | 7.62x39, +15 % pitch, HPF 300 Hz, 200 ms. **MEDIUM — build and A/B before committing.** |
| `m1911` | **KEEP THE PLACEHOLDER.** Subsonic .45 has no supersonic source in this pack; `test_ballistics.gd:102` says so. |
| `thompson`/`kar98k`/`mp40` | **MOOT — retired weapons** (`test_flat_damage.gd:31`). Derive nothing; **delete their 25 fossil wavs.** |
| `m70` / `m14` | **DO THESE INSTEAD.** Live weapons, no audio, currently sharing `shot_rifle.wav`. 7.62x54R fits both. VERY HIGH / HIGH. |
| levels | RMS −22…−25 dBFS whole-file, −9…−12 in the 50 ms peak window, **then** peak to −1.0 dBTP (near) / −3.0 (dist, mech, reload, bolt). RMS first, peak second. |
| format | **48 kHz / mono / 16-bit PCM.** Convert at source — `force/mono=true` lives in the `.import` and dies if the file is renamed. |
| tail layer | Keep the 0.72 (−16 dB into a 100 %-wet reverb bus = rumble bed, not a second gun). Fix the unconditional pitch at `:285`. Any real `tail_` file must be **dry**. |
| fossils found | `_p_dist` (`:42`, `:94`, `:388`) never plays · `crack_1..3.wav` + `is_supersonic` unwired (UNFINISHED) · 25 retired-weapon wavs. |
