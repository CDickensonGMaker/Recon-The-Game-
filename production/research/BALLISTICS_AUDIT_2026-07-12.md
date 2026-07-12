# Ballistics & Firefight Audit — 2026-07-12
**Asked:** *"full deep dive into our projectile and shooting systems. How did 2000s games do it, how
do Arma and HLL do it? Are my projectiles set to match their gun equivalents? Are they flying fast
enough? Full audit of the firefights."*
**Instrument:** `tools/probe_ballistics.gd` (numbers below are measured off the shipping data, not
estimated).

---

## PART 1 — How the lineage solved it

### The 2000s: hitscan was the default, simulation was the outlier
- **Quake 3 / arena shooters:** instant rays for bullets, projectiles only for rockets/plasma. Zero
  travel, zero drop. Netcode-friendly, deliberately unrealistic.
- **Half-Life / CS 1.6 / Source:** hitscan + a spread cone + per-weapon range falloff. CS added
  **material penetration** (wall-banging) with power loss per surface — the era's one nod to
  ballistics. No travel time, no drop, ever.
- **Call of Duty / MoHAA / RTCW:** hitscan with falloff and penetration tables. CoD's "feel" came
  from recoil, sound and hit feedback — not from the bullet.
- **The simulation branch (our ancestors):** **Operation Flashpoint (2001)** — real projectiles with
  muzzle velocity, gravity, time of flight. **Ghost Recon (2001)** — projectile drop. **Red
  Orchestra (2006)** — projectiles + **sight zeroing** + drop, the milsim template. **BF1942/BF2** —
  projectiles with drop and deviation.
- The 2000s lesson: hitscan for arcade pace; projectiles the moment you want *range to matter*.

### Modern milsim: Arma 3 and Hell Let Loose
- **Arma 3** — full external ballistics: per-ammo **muzzle velocity**, **air friction** (drag; a
  5.56 sheds ~35-40% of its speed by 300m), gravity, optional wind/Coriolis, **sight zeroing** in
  100m steps, **material penetration** by thickness, and damage by hit zone/armor. Weapon
  dispersion is *tiny* (**~0.03–0.07°**); the variance a player feels comes from **sway, stance,
  fatigue and recoil** — things he can control or wait out.
- **Hell Let Loose** — projectiles with travel and drop, no wind/drag modelling; rifles zeroed
  (drop shows past ~200m); TTK 1–2 hits; heavy suppression. Crucially: **a settled, aimed first
  shot lands exactly on the sights.** Randomness lives in *sway* and *recoil*, never in an
  invisible per-shot dice roll.
- **The modern law, shared by both:** *bullets are deterministic; the human is the noise source.*

---

## PART 2 — What we have (and it's a lot)
Real projectiles (BulletSystem: muzzle spawn, gravity, **segment raycast per tick** so a 948 m/s
round cannot tunnel a hitzone), per-weapon travel speed, tracer-is-the-bullet, range falloff,
mesh-hull hitzones with locational damage, limb over-penetration, suppression on near-misses,
data-driven tracers, and (as of today) an ADS shot that leaves along the sightline. That is already
past 2000s standard and structurally in Arma/HLL's family.

## PART 3 — FINDINGS

### F1 ✅ Muzzle velocities are period-correct. **Answer: yes, they fly fast enough.**
| weapon | game | real | weapon | game | real |
|---|---|---|---|---|---|
| M16A1 | 948 | 948 | Mosin | 865 | 865 |
| M14 | 850 | 853 | M70 | 890 | 890 |
| M60 | 853 | 853 | M1911 | 253 | 253 |
| AK-47 | 715 | 715 | PPSh | 488 | 500 |
| RPD | 735 | 735 | Ithaca | 400 | 400 |
Launchers too (M79 76, RPG-2 84, RPG-7 115, LAW 145). **Nothing to fix here.** (Only nuance: the
RPG-7's sustainer motor should accelerate it to ~294 m/s after launch; we fire it at a constant 115.)

### F2 ❌ **NO SIGHT ZERO — every rifle shoots low past 200m.** (P0)
The round leaves along the crosshair ray and only falls. Measured drop below point of aim:

| range | M16A1 | AK-47 | Mosin | verdict |
|---|---|---|---|---|
| 100m | 0.05m | 0.10m | 0.07m | fine |
| 200m | 0.22m | **0.38m** | 0.26m | chest → gut/legs |
| 300m | **0.49m** | **0.86m** | **0.59m** | **misses a standing man low** |
| 400m | **0.87m** | **1.53m** | — | **into the dirt** |

Every reference game zeroes its sights (RO, Arma, HLL). We are effectively zeroed at 0m. **In the
arena this is invisible; in the open AO — where you said most of the war happens — it makes rifles
useless past 200m and makes the AI harmless at range.** This is the single most important fix.

### F3 ❌ **ADS dispersion is 5–30× too wide, and it's a uniform square.** (P0)
The cone the player *cannot* control, at ADS, before recoil — full width of the square the RNG draws:

| weapon | ADS cone | 50m | 100m | 200m | vs a 0.45m chest |
|---|---|---|---|---|---|
| **M60** | 1.04° | 1.82m | **3.63m** | 7.26m | hopeless |
| **RPD** | 0.96° | 1.68m | 3.35m | 6.70m | hopeless |
| **PPSh** | 0.77° | 1.34m | 2.69m | 5.38m | hopeless |
| **AK-47** | 0.66° | 1.15m | 2.30m | 4.61m | 5× wider than a man |
| **M16A1** | 0.40° | 0.70m | 1.40m | 2.79m | **3× wider than a chest at 100m** |
| M14 | 0.26° | 0.45m | 0.91m | 1.82m | 2× |
| Mosin | 0.06° | 0.10m | 0.21m | 0.42m | ✅ correct |
| M70 | 0.03° | 0.06m | 0.11m | 0.22m | ✅ correct |

Arma rifle dispersion: **0.03–0.07°**. **Your bolt guns are already Arma-tight — it's the autos
that are wild.** That is exactly why the Mosin feels honest and the M16 feels like a slot machine:
*a perfectly aimed M16 shot at 50m can legally land 35cm off-center in a random direction.* It is
the last TTK lottery in the game (and it explains "sometimes fast kills, sometimes Half-Life"), and
it violates the T1 law: **same aim, same result.** Worse, the sample is a **uniform square** — the
edges are as likely as the center, which no real weapon does.

**The fix is not "make guns lasers."** It's the Arma/HLL structure: near-zero *mechanical*
dispersion, **first settled shot lands on the sights**, and all real variance comes from systems the
player reads and controls — **recoil climb, sway, stance, suppression, exposure — all of which we
already have and none of which are RNG.**

### F4 ⚠️ No air drag — bullets keep muzzle velocity forever. (P2)
Real 5.56 loses ~35–40% of its speed by 300m. Ours doesn't, so time-of-flight at 400m is ~30% short
and the trajectory is ~40% too flat. Irrelevant in the arena, real at AO ranges (leading a running
man at 300m). Tune on the open-terrain bench, not before.

### F5 ❌ The AI has neither zeroing nor sane dispersion. (P0, blocks open terrain)
Enemies aim straight at the target (same drop → they shoot low at range) and their cone is
`base_spread × 1.3 × accuracy × exposure × difficulty` — an AK man opens at **~2.9°+ before
multipliers** (≈5m at 100m). In the open, enemy fire will be *noise* — no pressure, no danger, no
firefight. The arena hides this because everything is inside 40m.

### F6 ⚠️ AI spread is applied to raw vector components on all three axes
`final_aim.x/y/z += randf_range(-s, s)` perturbs a normalized direction rather than offsetting an
angle in the aim basis — it skews toward diagonals and double-counts. The player path already does
it correctly (right/up basis). Unify.

### F7 ⚠️ Shotgun pellets are hitscan rays with a simulated delay, not BulletSystem rounds.
Inconsistent with the "hitscan is dead" decree; pellets ignore gravity. Harmless at ≤70m; worth
unifying eventually.

### F8 ⚠️ No material penetration. CS had it in 2004; Arma and HLL have it.
Rounds stop dead at any world geometry. Jungle-specific consequence: **a bamboo hooch wall stops a
7.62 round.** (Foliage is already correctly non-colliding — concealment, not cover.)

### F9 ℹ️ Suppression fires off the pre-shot lane ray, not the actual bullet path.
Minor, but means suppression doesn't track where the round really went.

---

## PART 4 — RECOMMENDED ORDER
1. **P0 — Sight zeroing** (player + AI), per-weapon `zero_range`. Unlocks every engagement past
   200m. *(shipping today)*
2. **P0 — Dispersion overhaul:** realistic mechanical cones (~0.05–0.25°), **center-weighted**
   sampling, **first settled ADS shot on the sights**; variance moves to recoil/sway/stance/
   suppression, which already exist. *(shipping today)*
3. **P0 — AI ballistics parity:** same zeroing, angular spread in the aim basis, bounded cone so
   enemy fire is *dangerous but human* at 100–300m. *(shipping today)*
4. **P2 — Air drag** (per-weapon ballistic coefficient), tuned on the open bench.
5. **P3 — Material penetration** (thin wood/bamboo/sheet metal), CS-style power loss.
6. **P4 — Shotgun pellets onto BulletSystem**; RPG-7 sustainer acceleration.
