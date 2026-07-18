# Phase 2c — FAIRNESS/SYSTEMS analysis: the 150m camp instakill

Read of CODE (not plan): `enemy_base.gd`, `ai_marksmanship.gd`, `weapon_data.gd`,
`ak47.tres`, `game_settings.gd`, `enemy_squad.gd`, `test_ai_fairness.gd`, ADR-005.

## Verdict up front
The Fairness Law (exposure ramp) **exists and is unit-tested in isolation, but is
NEGATED in the live fire path by the 1.2° player cone cap being applied AFTER the
ramp multiply.** The only surviving fairness term is a single first-shot near-miss
per man. With a whole camp (HOT_CAP = 12 precise shooters + cold sprayers who are
*also* clipped to the same cap), shots #2+ from every man land at the full 1.2° cap
immediately, at any range, with zero ramp. That is the instakill.

## 1. What determines a hit at 150m
`_fire_at_target()` (enemy_base.gd:1870) →
- `exposure_t = clampf(target_visible_duration / d_exposure_ramp, 0, 1)` (`:1879`) — 0 on
  fresh contact (`target_visible_duration` reset to 0 on new target, `:973`/`:980`).
- `cone_spread_deg(base_spread, char_accuracy, shots_fired, moving, accuracy_modifier)`
  (ai_marksmanship.gd:25).
- `aim_with_spread(..., is_player_target=true, exposure_t, force_first_miss)` (`:72`).

Inside `aim_with_spread`:
```
if is_player_target:
    s *= exposure_spread_mult(exposure_t) * GameSettings.enemy_spread_mult()
aim = _apply_cone(base_aim, minf(s, cap))   # cap = PLAYER_CONE_CAP_DEG = 1.2
```
Range-based accuracy falloff: **NONE.** The cone is angular, so a shot is 1.2° at 5m or
150m; at 150m that is ~±3.1m max, ~±1.4m typical (`randfn(0,0.45)` center-weighted).

## 2. Is the exposure ramp actually applied to shots AT THE PLAYER? — NO (clipped)
AK47 (`ak47.tres`): `base_spread = 2.2`. Pre-ramp cone at "good range, still":
`2.2 × 1.25(BASE_SPREAD_MULT) × ~0.8(accuracy_modifier) × ~0.76(skill, char_accuracy 0.7)
× 1.0(bloom) ≈ 1.67°`. That already **exceeds the 1.2° cap before the ramp is even
applied.**
- Fresh: `s = 1.67 × 3.0 = 5.0°` → `minf(5.0, 1.2) = 1.2°`.
- Converged: `s = 1.67 × 1.0 = 1.67°` → `minf(1.67, 1.2) = 1.2°`.
**Fresh and converged fire the IDENTICAL 1.2° cone.** The ramp (`exposure_spread_mult`,
x3 fresh → x1 converged) is dead for any weapon whose base cone > 1.2/3 = 0.4° — i.e.
every enemy rifle. `test_ai_fairness.gd` only asserts `exposure_spread_mult` in
isolation (m0=3, m1=1, monotone); it never tests the cap clip, so the law passes its
probe while being inert in play. This is the ADR-005-class "dead fairness code" resurfacing.

Second manifestation: `_think_cheap_combat`'s comment (enemy_base.gd:575, 599) claims a
cold man "sprays, he does not snipe" because exposure never ramps → exposure_t=0. But
exposure_t=0 → mult 3.0 → **still clipped to 1.2°.** Cold sprayers are just as accurate
as the hot set. The comment lies; the cap defeats it too.

## 3. Lethality at 150m — 2 hits kill, no falloff
`ak47.tres`: `effective_range = 250`, `max_range = 400`. `damage_multiplier_at(150)` =
1.0 (150 < 250) → **no falloff at 150m.** Flat base 27 (ADR-016). TORSO ×2.5 = 67, GUT
×2.25 = 60. Player HP 100 → **any 2 torso/gut hits = dead.** With up to 12 hot shooters +
cold men all at 1.2°, each firing 5-round bursts after a ~0.35s reaction, ~20–30 rounds
crack downrange in the first second; per-shot hit chance on a crouched torso ≈ 5–8%, so
2 hits inside ~1s is the expected outcome. That is the instakill, and it is an *aggregate*
of the whole camp, not one deadeye.

## 4. Spot-to-engage grace
`_execute_combat` reaction gate (`:1339`): `BASE_REACTION_TIME(0.25) × (2 − char_reaction)`
≈ 0.35s, then fire. The extra "startle" delay (`:876-880`) only triggers within 15m — at
150m there is none. Detection itself IS gradual (awareness accumulator, `_update_perception`),
but the moment COMBAT is reached `awareness=1.0`, FOV=360, and the ramp that should buy the
spotted player a window is the very thing being clipped. So effectively:
detection → ~0.35s → accurate fire, minus one near-miss per man.

## 5. AI-vs-AI vs AI-vs-player asymmetry
Correctly separated (`aim_with_spread:76-83`): the firefight widen
(`ai_vs_ai_cone_mult`) is on the `else` branch; first-shot mercy + ramp are on the player
branch. The asymmetry is NOT that the ramp is ally-only — it is that the ramp is *clipped
to nothing* on the player branch by the shared 1.2° cap.

## Minimal fix — make the player cap breathe with exposure
In `AIMarksmanship.aim_with_spread`, scale the CAP by the same ramp so the widening is not
clipped away:
```gdscript
if is_player_target:
    var ramp: float = exposure_spread_mult(exposure_t)   # 3.0 fresh -> 1.0 converged
    s *= ramp * GameSettings.enemy_spread_mult()
    cap *= ramp                                          # <-- the cap breathes with exposure
```
- Fresh contact: cap = 1.2 × 3 = 3.6° → at 150m ~±9.4m max / ~±4m typical → the camp's
  opening volley near-totally misses.
- Converged (after `d_exposure_ramp`, NVA 2.2s / farmer 3.5s): cap = 1.2° → lethal as
  today. The intended "spotted player gets a window to react/break contact" is restored.
- Bonus: cold sprayers (exposure_t stuck at 0) finally get cap 3.6° → they genuinely
  spray, matching their own comment.
- Keeps `test_ai_fairness` green (it never touches the cap) and `test_flat_damage` green
  (damage untouched — this is a spread fix, not a damage nerf; ADR-016 flat-27 intact).

## What is sacrificed (no free lunch)
- For the ramp window (~2.2–3.5s per fresh acquisition) enemy fire on the player is very
  inaccurate **at ALL ranges, including a point-blank CQB ambush** — a spider-hole/close
  camp can be face-tanked for ~2s after it lights up. This is the deliberate price of the
  Fairness Law; it makes loud CQB softer than a realist might want. Tunable via
  `EXPOSURE_PEAK` (currently 2.0) and per-archetype `exposure_ramp_time` if the CQB window
  feels too generous.
- Difficulty still bites: `enemy_spread_mult` scales `s` (converged cone below cap on HARD)
  and player_damage_mult is untouched.
- Alternative rejected: adding range accuracy falloff or cutting base damage — the cone is
  already range-invariant lateral spread, and cutting 27 violates ADR-016. The defect is
  strictly the ramp being clipped, so fix it exactly there.
