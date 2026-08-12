# Ally Cover Root-Cause — AI Architect analysis, 2026-08-12

Bench: `scripts/levels/support_fire_range.gd` `--cover-probe`. 5-man squad, 10-man assault.
ANALYSIS ONLY. No file was edited.

---

## 0. The one-line verdict

Nothing here is architecturally broken. Two **permanent latches** and one **geometry
mismatch** conspire so that from ~t+5s of any firefight, `SEEK_COVER` is scored `-1.0`
(doctrinally forbidden) for the rest of that contact, and the only thing that could
re-open it — `suppression_level` — decays 3x faster than the probe samples it.

---

## 1. WHY IS ALLY `suppression_level` ZERO?

### The path is LIVE, not dead. Every link traced:

| Link | Where | Status |
|---|---|---|
| Enemy squeezes | `scripts/enemies/enemy_base.gd:2226` `_fire_at_target()` | live |
| Projectile early-out | `enemy_base.gd:2265-2275` — a weapon with `projectile_data_path` **returns before suppression** | not hit here; `data/weapons/ak47.tres` has no `projectile_data_path`, so the assault runs the hitscan branch |
| Muzzle discipline early-out | `enemy_base.gd:2222-2229` — a squadmate in the lane `return`s **before** the suppression call | live, eats some shots on a 10-man line |
| Callsite | `enemy_base.gd:2302` `_suppress_player_if_near(origin, final_aim, result)` | **called on every hitscan shot** |
| Ally loop | `enemy_base.gd:2942-2947` — iterates `AgentRegistry.allies`, calls `apply_suppression` | live |
| Registration | `ally_base.gd:347` `AgentRegistry.register(self, AgentRegistry.Kind.ALLY)` | live |
| Sink | `ally_base.gd:1771-1772` `apply_suppression()` | live |

### Magnitude

`enemy_base.gd:2952-2961` + `:2927` + `:2964`:
`s = 0.34 * (1 - d/2.2)` where `d` is the perpendicular distance from the round's line
to the ally's chest. **Cylinder radius is fixed at 2.2m in WORLD space.**

Scatter is **angular**, and it is capped hard:
`ai_marksmanship.gd:92` — for an AI-vs-AI shot, `cap = PLAYER_CONE_CAP_DEG * max(1.0, ai_vs_ai_cone_mult)`
= `1.0 * 1.0` = **1.0 degree**, because `game_settings.gd:22` defaults `ai_vs_ai_cone_mult = 1.0`
and only `ai_stress_arena.gd:311` ever overwrites it — the support-fire range never does.

A 1.0° cone at the bench's engagement ranges:

| range | max lateral at cap | typical (`_apply_cone` mag ~0.36x, `ai_marksmanship.gd:49`) |
|---|---|---|
| 31m | 0.54m | 0.19m |
| 40m | 0.70m | 0.25m |
| 72m | 1.26m | 0.45m |

**All of these are INSIDE the 2.2m cylinder.** So the correct reading is the opposite of
"never triggers at these ranges": at these ranges an enemy round aimed at an ally is
*almost always* a near-miss or a hit, and each one is worth **0.19–0.34** suppression.
The 1.0° AI-vs-AI cap makes the near-miss test *more* generous at range, not less.

### So why does the probe read 0.00?

Three multiplying reasons, in order of weight:

1. **The instrument is blind.** `support_fire_range.gd:1088-1102` samples at T+3/10/20/30s —
   gaps of 3, 7, 10, 10 seconds. `ally_base.gd:645-646` decays at `SUPPRESSION_DECAY = 0.3`/s
   (`ally_base.gd:259`), so a **full 1.0 pin is gone in 3.3 seconds**. Any spike is
   mathematically guaranteed to have decayed to exactly 0.00 by the next sample unless it
   happened in the ~1s before it. `suppression_level` is a sub-second quantity being read
   on a 10-second stride.
2. **The enemy barely fired.** 10/10 attackers dead, closest 31.2m from the arc, 6 of 10
   down inside 10s. They spawn at `ENEMY_LINE_Z = -72.0` (`support_fire_range.gd:48`) against
   allies at z≈+8; enemy `preferred_range` is 15m (`enemy_base.gd:14`/`:327`). They spent the
   whole fight closing and died doing it. Low incoming volume, on a 0.3/s drain.
3. **Nothing accumulates across a lull.** There is no memory term. `_threat_estimate()`
   (`ally_base.gd:952-954`) is `suppression_level * 0.7 + hurt * 0.5` — a pure instantaneous
   read. Between bursts a man's threat estimate is **zero** even though he is in a firefight.

### The proof that it is real-but-transient, in the probe's own output

`[DOCTRINE] ... ally 0.1` man-seconds. `support_fire_range.gd:583-586` only accumulates that
counter when `a.suppression_level > 0.3` AND the man is ADVANCING/FLANKING. A non-zero 0.1
means at least one ally **did** cross 0.3 suppression during the run. The number is real,
tiny, and invisible to the sampler.

**Verdict Q1: the path is correct and it fires. The value is real, sub-second, and both the
game logic and the probe read it as zero. This needs a MEMORY/decay fix, not a plumbing fix.**

---

## 2. WHY DO ALLIES STOP TAKING COVER?

### The scoring path, end to end

`ally_base._evaluate_goals()` (`ally_base.gd:801`) → builds `CombatGoals.Context`
(`ally_base.gd:865-896`) → `CombatGoals.pick()` (`combat_goals.gd:160`).

The gate is `ally_base.gd:882`:
```
c.uses_cover = wants_cover_first(nerve) or has_cover
```
and `combat_goals.gd:97`:
```
scores[Enums.AIGoal.SEEK_COVER] = cover if c.uses_cover else -1.0
```
**Confirmed: `-1.0` is literal. A false `uses_cover` makes SEEK_COVER unpickable, since
`pick()` starts `best_score` at 0.0 (`combat_goals.gd:168`).**

### When does `uses_cover` go false and stay false?

`wants_cover_first` (`ally_base.gd:136-140`):
```
if _cover_fail_count >= 2: return false
return squad_broken or has_cover or suppression_level > ANCHOR_SUPPRESS \
    or (_contact_time < 5.0 and nerve < 0.75)
```
Term by term, for a man with no cover on this bench:

- `squad_broken` — false (1 casualty in 5).
- `has_cover` — false (that is why he is asking).
- `suppression_level > 0.25` — **effectively never true at a think tick.** Suppression is a
  sub-second spike (§1); `_evaluate_goals` re-plans on a ~1s dwell (`ally_base.gd:828`). The
  clause added today can only fire if a burst lands inside the same ~1s window as a goal
  re-plan with the man already off cover. **The Arbiter's re-entry clause is, in practice,
  inert. CONFIRMED.**
- `_contact_time < 5.0` — `_contact_time` increments every think while a target exists and
  resets **only** on target loss (`ally_base.gd:802-809`). In a continuous 30s firefight it
  crosses 5.0 once, at t+5s, and never comes back.

So from **t+5s of first contact, `uses_cover` is permanently false** and SEEK_COVER is
permanently `-1.0`. That is the whole answer to "why do they stop taking cover" — they are
not choosing to stop, the verb is deleted from their vocabulary.

### Even if the gate were open, cover would still lose

With `uses_cover = true`, `combat_goals.gd:90-96`:
```
cover = threat_level*0.7 + self_preservation*0.3
      + 0.2                              (no cover)
      + 0.4*(1 - aggression*0.7)         ONLY while contact_time < 6.0
```
`threat_level` is `_threat_estimate()` = 0 in every lull (§1). After t+6s the `+0.4` term
also expires. So cover flatlines at roughly `0.3*self_preservation + 0.2` ≈ **0.35**.

Against it, `combat_goals.gd:78-87`:
```
engage = 0.5 + 0.3 (eyes_on) + 0.2 (inside preferred band) = 1.0
```
and the `elif` open-ground penalty on `:85` **also** expires at `contact_time >= 5.0`.
Then `pick()` multiplies the incumbent by `ALLY_INCUMBENT_MULT = 1.6` (`ally_base.gd:270`,
`combat_goals.gd:166`) → incumbent ENGAGE scores **1.6 vs cover's 0.35**.

**Cover cannot win again for the remainder of the contact under any input the bench
produces. Three independent clauses all expire at the 5-6s mark, all keyed on the same
never-resetting `_contact_time`.**

---

## 3. WHAT DOES `cover_fail_count` MEAN HERE?

### The search

`ally_base._find_cover_point()` (`ally_base.gd:1550-1589`), called from `:1409` inside
`_execute_seeking_cover`, throttled to 1Hz (`:1406-1408`); every miss does
`_cover_fail_count += 1` (`ally_base.gd:1416`).

The candidate set is `EnemyBase.COVER_SEARCH_OFFSETS` (`enemy_base.gd:124-128`):
12 points — cardinals at 3m and 6m, diagonals at ±2.2m. **Maximum reach: 6 metres.**
A candidate qualifies only if a ray from `candidate + UP*1.3` toward the threat hits
world/static geometry (mask `1 | 32`) within `COVER_BLOCKER_MAX_M = 2.5` (`enemy_base.gd:131`,
used at `ally_base.gd:1569`). Effective envelope: **cover must sit within ~8.5m, and only
if it lies on the threat bearing from a point within 6m.**

### The bench geometry

- Allies spawn at `player + Vector3(-3 + i*2, 0, 2 + (i%2)*1.5)` with player at `(0,1,6)`
  (`support_fire_range.gd:212`, `:238-241`) → **allies at z ≈ +8.0 to +9.5**.
- The friendly sandbag arc sits at z ≈ **-0.8 to +1.2** (`support_fire_range.gd:25-29`).
  That is **7.0–10.3m in front of the squad** — outside the 6m ring for every man, and the
  6m forward candidate lands at z≈2-3.5, leaving the bag 2.3–3.8m further on: only the
  frontmost ally can squeeze under `COVER_BLOCKER_MAX_M = 2.5`.
- The ONE reachable piece is the rear bag at `(1.5, 0, 10.5)` (`support_fire_range.gd:32`),
  1–2.5m behind the squad. The claim broker (`ally_base.gd:1508` `_claim_scored`) gives it to
  exactly one man. **This is precisely the probe's "1 HELD, 4 NO CLAIM" at T+3s.**
- The tree field is at z ≤ -10 (`support_fire_range.gd:266-276`) — 18–25m forward. Not
  remotely in range.
- The concealment fallback (`ally_base.gd:1575-1588`) needs `MEDIUM_JUNGLE`/`HEAVY_JUNGLE`
  from `_sight_grid()`; the bench is a flat plane (`support_fire_range.gd:120-126`) with no
  such terrain, so the fallback returns ZERO too.

### The latch

`ally_base.gd:1416` increments once per failed 1Hz search; `ally_base.gd:137-138` then
**hard-disables cover forever at 2**, and `_cover_fail_count` is reset only at
`_contact_time == 0.0` (`ally_base.gd:804-806`) — i.e. only when the man loses his target
entirely. Two seconds of bad geometry buys a **permanent** cover lockout for the rest of the
firefight. Two men (RTO, TEX) took it.

**Verdict Q3: the search is not broken. It is a 6m leash on a bench whose nearest cover is
8-10m away, wired to a latch that never clears.**

---

## 4. DID TODAY'S CHANGES HELP? — blunt

| Change | Verdict |
|---|---|
| `preferred_range` 12.0 → 22.0 (`ally_base.gd:10`) | **HARMFUL.** It widens the ENGAGE in-band bonus (`combat_goals.gd:81`) to 11–26.4m, so a man standing in the open at 22m now scores the full `engage = 1.0`, and it raises the `dist > preferred*advance_band` threshold (`ally_base.gd:1220`) so he no longer closes toward the sandbag arc/tree line where the only cover is. It parks the squad in the open, at range, permanently. This is the single change most responsible for "dying that fast." |
| strafe pool `[-1,0,1]` → `[-1,0,0,0,1]`, leg 1.5-3.0s → 0.8-2.0s | **HARMFUL on this bench.** 60% of legs are now stand-still. Against a **1.0-degree** AI-vs-AI cone cap (`ai_marksmanship.gd:92`) a stationary ally is a guaranteed hit. Faster legs partly offset, but the zero-weighting does not. |
| `ANCHOR_SUPPRESS = 0.25` gating advance (`:1220`) and strafe (`:1229`) | **INERT.** Both read `suppression_level` at a physics tick against a value that is 0.00 almost always (§1). It fires occasionally and briefly — a stutter, not an anchor. |
| `SUPPRESSION_DECAY` 0.4 → 0.3 (`:259`) | **Right direction, an order of magnitude too small.** Full-scale decay went 2.5s → 3.3s. The goal dwell is 1s and the cover dwell is 8s (`ALLY_COVER_DWELL_MS`, `:268`). Suppression still cannot survive to the next decision. |
| `wants_cover_first` + `suppression_level > ANCHOR_SUPPRESS` (`:139`) | **INERT — confirmed, as the charge suspected.** See §2. |
| lost-LOS hold with cover + `target_last_seen_time < 3.0`; hunt at `COMBAT_SPEED_MULT` | **HELPED, keep it.** Independent of suppression; stops the jog-out-of-cover thrash. |
| `adv-under-fire ally 0.1` as evidence the advance gate worked | **The metric proves nothing.** `support_fire_range.gd:583-586` requires `a.suppression_level > 0.3` to count at all; with suppression pinned near zero the counter is structurally ~0 whether or not the gate exists. Do not credit the gate from this number. (It *does* prove suppression is non-zero sometimes — see §1.) |

Net: one genuinely good change (lost-LOS hold), two inert ones, two harmful ones. The
session moved the squad **further from cover** and **made it stand still**.

---

## 5. RECOMMENDATION — minimum change

Ordered by ratio of effect to risk. All ally-side only; the shared `combat_goals.gd` and the
enemy brain are untouched, honouring the divergent-systems law.

**R1 — Give a man a MEMORY of being shot at. (the root fix)**
`ally_base.gd` — add alongside `suppression_level` (`:258`):
```
var incoming_pressure: float = 0.0          # slow-decay memory of taking fire
const PRESSURE_DECAY: float = 0.06          # ~16s to forget a full pin
```
- In `apply_suppression()` (`ally_base.gd:1771-1772`) also do
  `incoming_pressure = minf(1.0, incoming_pressure + amount * 0.8)`.
- Decay it beside line `:645-646` at `PRESSURE_DECAY`.
- `_threat_estimate()` (`:952-954`) → `clampf(maxf(suppression_level, incoming_pressure) * 0.7 + hurt * 0.5, 0, 1)`.
- `wants_cover_first` (`:139`) → test `maxf(suppression_level, incoming_pressure) > ANCHOR_SUPPRESS`.

This alone un-inerts every gate the Arbiter added today, keeps `SEEK_COVER` scoring ~0.7-0.9
instead of 0.35 through a live firefight, and needs no change to the shared scorer.
Leave `SUPPRESSION_DECAY` at 0.3 — the *pin* should stay twitchy; it is the *memory* that
must be long.

**R2 — Un-latch the two permanent locks.**
- `ally_base.gd:137` — replace `if _cover_fail_count >= 2: return false` with a
  time-boxed lockout: record `_cover_fail_ms = Time.get_ticks_msec()` at `:1416`, and treat
  the lockout as expired after 10000ms. A man who could not find cover 10 seconds ago is
  allowed to look again; a man thrashing is still throttled.
- `ally_base.gd:802-806` — additionally zero `_contact_time` on a *cover state change*
  (i.e. when `_release_cover()` runs mid-contact), so the fresh-contact cover window at
  `:140` / `combat_goals.gd:85,95` re-opens when a man is newly exposed, not only when he
  loses his target entirely.

**R3 — Let the search reach the cover that exists.**
`ally_base.gd:1560` — stop borrowing `EnemyBase.COVER_SEARCH_OFFSETS` (6m max). Add an
ally-local second ring, tried only when the near ring returns nothing:
```
const COVER_SEARCH_FAR: Array[Vector3] = [
    Vector3(9,0,0), Vector3(-9,0,0), Vector3(0,0,9), Vector3(0,0,-9),
    Vector3(6.4,0,6.4), Vector3(-6.4,0,6.4), Vector3(6.4,0,-6.4), Vector3(-6.4,0,-6.4),
    Vector3(13,0,0), Vector3(-13,0,0), Vector3(0,0,13), Vector3(0,0,-13),
]
```
12 extra rays at 1Hz per man off-cover is a negligible budget (`CombatManager.rays_cover`
already meters it). This is what turns "4 NO CLAIM" into men on the sandbag arc.

**R4 — Revert the two harmful edits.**
- `ally_base.gd:10` `preferred_range` → **14.0** (not back to 12.0; 14 keeps the squad
  inside the arc-to-treeline band without parking it in the open at 22m).
- `ally_base.gd` strafe pool → `[-1.0, 0.0, 1.0]`, keep today's shorter
  `randf_range(0.8, 2.0)` leg. Standing still against a 1.0° cone is a death sentence.

### What is sacrificed

- **Rate of fire.** A squad that actually re-seeks cover shoots less. Expect the 10/10 enemy
  kill count on this bench to fall; that is the *correct* trade for Pillar 1's "squads spread,
  use cover" but the Summoner will notice his men killing slower.
- **Cover thrash risk returns.** R2's time-boxed lockout and R2's `_contact_time` reset both
  re-open doors the 2026-08-04 commitment work deliberately shut ("the friendly AI is super
  squierly"). The 8s `ALLY_COVER_DWELL_MS` and the 1.6 incumbent are the brakes; if thrash
  returns, lengthen the R2 lockout to 15s before touching those.
- **R3 lengthens cover rushes to 13m** — men will visibly sprint further, and the 4s cap at
  `ally_base.gd:830-831` may cut a long rush mid-run. Watch for men abandoning rushes.
- **Pillar 4 is respected**: none of this asks the player to position a man. R1 is a
  perception fix, R2/R3 are search fixes, R4 is a constant revert. The squad still holds its
  own intent — it just gets to have the intent it was written to have.

### The one thing NOT recommended

Do not "fix" `combat_goals.gd:95` (`contact_time < 6.0`) or `:85`. It is shared with the
enemy brain and was lifted verbatim from `EnemyBase._evaluate_goals` (`combat_goals.gd:10-12`).
Changing it moves the enemy side too. R1 achieves the same result by feeding the scorer an
honest `threat_level`, which is exactly the seam `ally_base.gd:950-952` says was left open
for this ("Replace it with a measured term if the ally brain ever needs parity").

### One instrument fix for the bench owner (not mine to make)

`support_fire_range.gd:1088-1102` samples suppression on a 10s stride against a 3.3s decay.
Whoever owns that file should track `max(suppression_level)` per man across the window and
report the peak, not the instant. Until then "supp=0.00" is not evidence of anything.
