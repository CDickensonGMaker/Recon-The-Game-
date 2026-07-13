# FP Idle / Fidget / Inspect Animation Spec — RECONgame

How classic FPS games gave weapons **alive hands** with per-gun idle sets, and the concrete
plan to take RECONgame's viewmodels from "AI prototype" to "real game." Author on the same
**30 fps grid** as `ANIM_TIMING.md` (1f = 0.033s, 30f = 1.0s).

Companion docs: `ANIM_TIMING.md` (keyframe craft rules), `VIEWMODEL_ANIM_SPEC.md` (clip
contract + Godot binding). This doc **adds** the idle/fidget/inspect layer they deferred.

---

## TL;DR — the decisions (autonomous, per project laws)

1. **Your instinct is exactly right.** GoldSrc weapons carried **2–3 idle clips each**: a base
   idle, a second subtle idle variant, and a rarer characterful **fidget**. This was not decoration —
   it is *the* trick that made HL1 hands feel alive. We copy it.
2. **Cadence: fire a fidget every ~12–20s of true idle**, then return to the base loop. HL1 used
   10–15s; we go slightly longer for a slower tactical game so it never feels twitchy.
3. **The baked/procedural line moves — but it moves by INTENT, not by "more baked."**
   Keep **input-driven** motion procedural (mouse-lag sway, velocity bob — must follow input).
   **Bake intent-driven** motion (hands deliberately checking the rifle, tapping a mag, hefting an
   MG). Noise can't fake intent; that's the whole "alive vs dead" gap. This *extends* ANIM_TIMING's
   "keep sway procedural" rule rather than contradicting it.
4. **Per weapon we build:** `idle` (base loop, exists) + `fidget` (short settle) + `check`
   (weapon-identity beat) + `inspect` (on-demand showcase). 3 new clips. The `check` clip is where
   each gun's personality lives.
5. **Inspect is the one place you're allowed to show off** — it only plays on player input, so it
   can be long and flourishy; the auto-fidgets must stay short because the player sees them thousands
   of times.

---

## 1. How the classics actually did it

### Half-Life 1 / GoldSrc — the canonical system (this is our template)

GoldSrc weapons ran a server-side `WeaponIdle()` that fires on a timer and randomly picks which
idle sequence to send. Two real examples from the HL SDK:

**MP5 — 2 idles, 50/50, re-roll every 10–15s:**
```cpp
// RANDOM_LONG(0,1): case 0 -> MP5_LONGIDLE, case 1 -> MP5_IDLE1
SendWeaponAnim(iAnim);
m_flTimeWeaponIdle = gpGlobals->time + RANDOM_FLOAT(10, 15);
```

**Gauss — 3 idles, weighted, fidget is the rare one:**
```cpp
if (m_flTimeWeaponIdle > UTIL_WeaponTimeBase()) return;   // gate: nothing until timer expires
float flRand = RANDOM_FLOAT(0, 1);
if (flRand <= 0.5)  { iAnim = GAUSS_IDLE;   m_flTimeWeaponIdle = base + RandomFloat(10,15); } // 50%
else if (flRand <= 0.75){ iAnim = GAUSS_IDLE2; m_flTimeWeaponIdle = base + RandomFloat(10,15);}// 25%
else                { iAnim = GAUSS_FIDGET; m_flTimeWeaponIdle = base + 3; }                  // 25%
```

**What this tells us, concretely:**
- **2–3 idle clips per weapon** was the standard. Base idle + subtle variant + fidget. Exactly your
  ~2–3 belief.
- **Weighting:** the boring idles dominate (~75% combined), the characterful fidget is the ~25% spice.
  You want it to feel like a treat, not a tic.
- **Timer gate:** `if (m_flTimeWeaponIdle > now) return;` — the idle machine does nothing until its
  timer expires. Any real action (fire/reload/draw) stomps the current anim and resets the timer, so
  fidgets **never interrupt gameplay** — they only surface in genuine downtime.
- **Fidget re-check is short (3s):** after a fidget the weapon re-evaluates quickly; after a plain
  idle it waits the full 10–15s. Net: fidgets cluster loosely, base idle carries the dead air.

**QC declaration** (how the clips were tagged in the model):
```
$sequence "idle1"  "idle1"  loop fps 30 ACT_VM_IDLE   5   // higher weight = plays more often
$sequence "idle2"  "idle2"  loop fps 30 ACT_VM_IDLE   3
$sequence "fidget" "fidget"       fps 30 ACT_VM_FIDGET 1   // note: NOT loop — one-shot, returns to idle
```
The trailing number is the activity **weight**. `ACT_VM_IDLE` loops; the fidget is a non-looping
one-shot that plays through once and drops back to idle.

### Counter-Strike 1.6 / Source

Same GoldSrc bones. Idles declared `$sequence idle ... fps 30 loop activity ACT_VM_IDLE`. Source
(HL2/CS:S) formalized the split into two activities: **`ACT_VM_IDLE`** (looping base) and
**`ACT_VM_FIDGET`** (one-shot spice), so animators could author fidgets as first-class clips picked
by the same weighted-random timer. CS itself shipped fairly minimal fidgets; the *system* is what
matters and it's identical to what we'll build.

### Half-Life 2 / Source

Added the **additive** idea that modern engines lean on: a subtle breathing/idle offset stored as a
delta from the rest pose and layered *on top* of whatever base clip is playing, so you don't
re-author breathing into every idle. RECONgame already does the equivalent procedurally (see §3).

### Call of Duty (2000s → Modern Warfare's "Active Idle")

CoD's big leap was replacing the old **"deck of a ship" sway** (big rhythmic wander) with **Active
Idle**: small, realistic muscle micro-movements while standing still. Animation Director Mark
Grigsby, IW:
> "Back in the day we saw a lot of idle [animations] that moved more like you were on the deck of a
> ship, swaying back and forth."
> "When you look around, we wanted to do a little bit of leading with the head, and then the gun
> travels behind."
> "When you go up the stairs, we added a bit of movement on the weapon to make it look like it's
> not bolted to the camera."

Two takeaways RECONgame should steal:
- **The hand leads, the gun trails** (already ANIM_TIMING craft-rule #1 — CoD confirms it at the
  idle layer too, not just in actions).
- **"Not bolted to the camera"** — the gun should have a hair of independent inertia during
  look/traverse. This is procedural (§3), not baked.

CoD-era **weapon inspect** is the on-demand showcase: a longer keyframed clip the player triggers to
admire the gun. Ask-a-Game-Dev's rule for it: *a short snappy but boring inspect beats a long fancy
one, because the player watches it thousands of times.* Keep flourish for the FIRST-draw check, not
the repeatable inspect.

---

## 2. Anatomy of a good per-gun idle set

Three layers, from most-often-seen to rarest:

| Layer | Frequency | Amplitude | Character | Baked? |
|---|---|---|---|---|
| **Base idle (breathing)** | always (loop) | tiny: 1–2cm vertical, ~4–6s cycle | none — just "alive" | additive baked OR procedural |
| **Fidget** (settle) | ~every 12–20s | small: weapon tilts 3–8°, hands shift a few cm | light: re-grip, thumb the safety | baked one-shot |
| **Check** (identity) | rarer than fidget | medium: tilt inboard 10–20°, a hand leaves the grip and returns | strong: check chamber, tap mag, heft weight | baked one-shot |
| **Inspect** (showcase) | on player input only | large: rotate gun 20–40° toward camera, long holds | max: deliberate examination | baked one-shot |

**What reads as "alive hands" vs "dead prototype":**
- *Dead:* weapon perfectly locked to camera, or a single mechanical sway loop. The eye pattern-locks
  in seconds and it screams asset-flip.
- *Alive:* micro-breathing always present + unpredictable deliberate beats (a thumb tap, a chamber
  glance) at irregular intervals + the gun trailing the camera by a frame or two on look.
- **Irregularity is the magic.** The random 12–20s re-roll + weighted clip choice means the player
  can't predict the next beat, so it reads as a person, not a machine. A fixed-interval fidget is
  almost as dead as none.
- **Follow-through sells it** (ANIM_TIMING rule #6): after a mag-tap the fingers lag 1–3f; after the
  hand returns to grip the weapon micro-settles. Hard stops kill it.
- **Interruptibility is non-negotiable:** any fidget/check must yield instantly to fire/reload/ADS.
  A fidget that eats a trigger-pull is worse than no fidget.

**How they blend:** base idle loops underneath; a fidget/check is a **one-shot that temporarily
replaces** the base loop, then cross-fades back (2–4f blend). Procedural sway (§3) rides on **top of
all of it** so even during a fidget the gun still answers the mouse. Breathing is additive so it
never fights the base pose.

---

## 3. Baked vs procedural — where the line is for RECONgame

ANIM_TIMING says "keep sway procedural, optionally bake a subtle breathing loop additive underneath."
That's correct and stays. You want **more baked hand life** — that's also correct. These don't
conflict once you split by **what drives the motion:**

| Motion | Driver | Belongs in | Why |
|---|---|---|---|
| Mouse-lag sway / gun trailing look | **player input** | **CODE (procedural)** | Must follow the mouse in realtime; a baked clip can't. |
| Positional bob (walk/run) | **velocity** | **CODE (procedural)** | Must scale to actual speed; already handled by `weapon_holder`. |
| Breathing micro-cycle (1–2cm) | **time** | either — **additive baked OR procedural** | No intent; a sine is fine. Bake only if you want lung-rhythm character. |
| **Grip re-settle, thumb safety, tap mag** | **intent** | **BAKED (fidget)** | Deliberate human action. Noise physically cannot produce it. |
| **Check chamber / work bolt / heft MG** | **intent** | **BAKED (check)** | Weapon identity. This is the alive-vs-dead payload. |
| **Inspect / showcase** | **player input** | **BAKED (inspect)** | Authored performance, triggered on demand. |

**The one-line rule:** *If it has to react to the player, code it. If it shows intent, bake it.*
The "more baked life" you want lives entirely in the **intent** rows — and those were exactly the
clips the classics hand-authored per gun. So: keep sway/bob/breathing where ANIM_TIMING put them,
and **add the three baked intent clips** below. Nothing is contradicted; the plan just grows the
right layer.

---

## 4. RECONgame per-weapon idle spec (buildable)

**New clip contract** (adds to the `VIEWMODEL_ANIM_SPEC.md` set; same names on every weapon):

| Clip | Type | Trigger | Loop? | Interruptible |
|---|---|---|---|---|
| `idle` | base breathing loop | default state (exists) | yes | — |
| `fidget` | short settle | idle-timer, weighted ~60% | no (one-shot → `idle`) | yes, instantly |
| `check` | weapon-identity beat | idle-timer, weighted ~40% | no (one-shot → `idle`) | yes, instantly |
| `inspect` | on-demand showcase | player input (Inspect key) | no (one-shot → `idle`) | yes, instantly |

**Idle-machine logic (port of HL1, drive from GDScript):**
- Gate: run only when truly idle — not moving, not ADS, not firing, not reloading, not switching.
- On entering true-idle, set `next_fidget = now + rand(12.0, 20.0)`.
- When `now >= next_fidget`: roll `r = randf()`; `r < 0.60 → fidget`, else `check`. Play one-shot,
  blend back to `idle` (2–4f). After a `fidget` set the next timer short-ish `rand(6,12)`; after a
  `check` set it long `rand(15,25)` (mirrors HL's short-after-fidget behavior → loose clustering).
- **Any** real action resets the timer and stomps the clip. `inspect` bypasses the timer (input-driven)
  but obeys the same interrupt rule.

**Per-weapon clip table** (frames on 30fps grid; the `check` column is where identity lives):

### Rifle set — M14 / M16 / AK / Mosin
Share `idle` + `fidget` verbatim; author a **distinct `check`** per gun (the personality beat).

| Weapon | `idle` (loop) | `fidget` (settle) | `check` (identity) | `inspect` (showcase) | Notes |
|---|---|---|---|---|---|
| **M14** | 150f / 5.0s, 1–2cm breath | 30–40f: thumb the safety, muzzle dips 2–3cm, re-grip | 60–75f: tilt inboard ~15°, pat/seat the 20-rd mag, glance, return | 120–150f: rotate to camera ~30°, tilt to read receiver, hold 6–8f, return | wood-rifle weight; unhurried |
| **M16** | 150f / 5.0s | 30–40f: pat forward-assist, settle grip | 60–72f: tap forward-assist, check mag seated, thumb selector | 120–150f: cant to show carry handle, tap dust cover | crisper, lighter than M14 |
| **AK** | 150f / 5.0s | 30–40f: characteristic slight rock, re-grip | 60–75f: pat the mag, glance at selector lever, small rock-settle | 120–150f: tilt to show selector sweep, heft | heavier trailing than M16 |
| **Mosin** | 150f / 5.0s | 36–45f: cheek-weld settle, stock re-shoulder | 66–80f: thumb the bolt handle (don't cycle), press stock to shoulder, sight-line settle | 130–160f: cant to read the bolt/receiver, longer holds | bolt gun = slowest, most deliberate; identity overlaps `bolt_cycle` — keep `check` gentle so it's clearly *not* a cycle |

### Distinct-hold weapons — M60 / RPD / RPG / PPSh
Different grips → author fresh `idle`/`fidget`/`check`. Apply ANIM_TIMING **law #5** (heavier =
+30–50% frames, more sag, bigger overshoot).

| Weapon | Hold | `idle` (loop) | `fidget` | `check` (identity) | `inspect` | Notes |
|---|---|---|---|---|---|---|
| **M60** | support hand on carry handle/barrel | 180f / 6.0s, more sag (2–3cm) | 45–55f: heft the weight — sag then re-shoulder | 90–110f: adjust the belt/feed, re-heft, muzzle sags then rises | 160–200f: hoist and cant to show feed tray, slow | LMG: slowest, saggiest; amplitude +40% |
| **RPD** | support hand under drum | 180f / 6.0s | 45–55f: pat the drum, re-grip | 84–100f: tap drum seated, adjust carry, heft | 150–190f: cant to show drum | slightly lighter than M60 |
| **RPG** | over-shoulder tube | 180f / 6.0s, heaviest sag | 45–60f: shift the tube weight on shoulder | 90–110f: glance down the tube, re-shoulder the launcher | 160–200f: tilt tube to inspect warhead/sight, slow, big holds | very slow, weighty; smallest angular range (tube is long/heavy) |
| **PPSh** | support hand on drum/foregrip | 120f / 4.0s (faster breath) | 24–34f: brisk SMG grip re-settle | 48–60f: pat the drum, quick chamber glance | 100–130f: snappy cant to show drum, shorter holds | SMG = snappiest, smallest amplitude, fastest cadence |

**Amplitude ladder (keep it subtle — subtlety reads as competence):**
- `idle` breath: 1–2cm vertical (SMG faster cycle, MG saggier).
- `fidget`: weapon tilt 3–8°, muzzle dip 2–4cm, a hand shifts a few cm.
- `check`: weapon tilt inboard 10–20°, one hand leaves grip to tap/check and returns (follow-through
  1–3f), muzzle travels 4–8cm.
- `inspect`: rotate toward camera 20–40°, deliberate holds 6–10f, the only clip allowed real flourish.

**Cadence per archetype (tune the idle-timer ranges):**
- Rifles/bolt: `fidget` 12–20s, `check` rarer (weight 40%, long re-arm 15–25s). Contemplative.
- LMG/RPG: stretch to 15–25s — heavy weapons "rest" more, move less often but bigger when they do.
- PPSh/SMG: tighten to 8–16s — light, twitchy, restless hands.

**Build order (cheapest high-value first):**
1. M14 `fidget` + `check` — proves the idle-machine end to end on the weapon that already has `idle`.
2. Wire the GDScript idle-timer + weighted picker + interrupt/reset. Verify fidgets never eat inputs.
3. `check` for M16 / AK / Mosin (reuse M14 `fidget`).
4. `inspect` pass across the rifle set (one flourish clip each).
5. Distinct-hold sets: M60 → RPD → PPSh → RPG.

---

## 5. Godot binding notes

- Same clip names on every weapon's `AnimationPlayer` (the contract from `VIEWMODEL_ANIM_SPEC.md`).
  The idle-machine controller is written **once** and every weapon reuses it — identical pattern to
  the existing signal-bound clip system.
- `fidget`/`check`/`inspect` are **one-shots**: on finish, blend (2–4f) back to `idle`. Use
  `AnimationPlayer` blend times or an `AnimationTree` OneShot node so procedural sway keeps riding on
  top throughout.
- Procedural sway/bob/breath stay in `weapon_holder` untouched — they layer over whatever idle clip
  is active (that's the whole point of keeping them additive/procedural).
- Interrupt discipline: the idle-machine only owns the animation when the weapon is in true-idle;
  the moment `weapon_fired` / `reload_started` / `switch_started` / ADS / movement fires, gameplay
  clips take priority and the idle timer resets. This mirrors HL's `if (m_flTimeWeaponIdle > now)
  return;` gate.
- Add one input action (e.g. `weapon_inspect`) to trigger `inspect`; ignore it while any gameplay
  clip is active.

---

## Sources

- Half-Life SDK `WeaponIdle()` (Gauss — 50/25/25 idle/idle2/fidget, 10–15s / 3s timers): https://github.com/alliedmodders/hlsdk/blob/master/dlls/gauss.cpp
- Half-Life SDK MP5 `WeaponIdle()` (2 idles, `RANDOM_FLOAT(10,15)` re-roll): https://www.oocities.org/vs49688/hlsdk2/sdk/weapon_mp5.htm
- HL weapon-animation issues (RPG fidget too short, Gauss idle broken — shows the timer/anim coupling): https://github.com/ValveSoftware/halflife/issues/2495
- GoldSrc QC `$sequence` / fps / loop / `ACT_VM_IDLE` weighting: https://the303.org/tutorials/gold_qc.htm
- Source `ACT_VM_IDLE` / `ACT_VM_FIDGET` viewmodel activities: https://developer.valvesoftware.com/wiki/Activity_List
- CS:Source idle animation authoring (Wikibooks): https://en.wikibooks.org/wiki/Animating_Weapons_for_Counter-Strike_Source/Idle_Animation
- CoD Modern Warfare "Active Idle" — Grigsby dev quotes (ship-deck sway, head-leads-gun, not-bolted-to-camera): https://blog.activision.com/call-of-duty/2019-07/Modern-Warfare-Initial-Intel-Detailing-Advancements-in-Animation-and-Authenticity
- CoD MW Active Idle / reload detail (Charlie INTEL): https://www.charlieintel.com/modern-warfare/call-of-duty-modern-warfare-additional-details-on-weapons-active-idle-reload-and-more-55049/
- Ask-a-Game-Dev on weapon inspect design ("short & snappy beats fancy; watched thousands of times"): https://www.tumblr.com/askagamedev/710519014238175232/why-do-so-many-fps-games-now-have-inspect
- Additive idle / breathing masked-by-speed, keyframe-for-handling vs procedural-for-sway (MoCap Online guides): https://mocaponline.com/blogs/mocap-news/first-person-animation-guide , https://mocaponline.com/blogs/mocap-news/animation-layers-guide
- Procedural weapon animation (sway/breath as engine nodes over a small baked set): https://sreitich.github.io/fpp-animation/
- CGCookie — 10 tips for FPS weapon animation in Blender (keyframe handling, snappy over fancy): https://cgcookie.com/posts/how-great-first-person-animations-are-made-10-tips-for-animating-fps-characters-in-blender
