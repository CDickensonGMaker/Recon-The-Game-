# Devil's Advocate — Track C: AI Accuracy Unify

## The one objection most likely to make the fix fail its probe

**`aim_error` is not the cone — it is the cone's CENTER. Unifying the cone formula does not touch it.**

`enemy_base.gd:1789` fires along `(current_aim_dir + aim_error).normalized()`. `aim_error` is a
persistent 3-axis wobble built at `:1200-1204` as `(1-char_accuracy)*0.1 rad` (≈±1.7° at char_accuracy
0.7). The 1.2° cap at `:1799` clamps **only `total_spread`** — the cone RADIUS. It never sees
`aim_error`. So the enemy's tight 1.2° cone is aimed up to ~1.7° off the target's chest; the ally
(`ally_base.gd:741`, `final_aim = current_aim_dir`) puts an identical cone dead on the sternum.

**Consequence for the probe:** you can extract a perfect shared symmetric spread model, delete both
inline formulas, satisfy Fossil Law — and the mirror match will STILL trend ~2:1, because the bias
term you unified was never the driver. A cone-only fix that ships and stays 2:1 is the predicted
failure. The center-offset (`aim_error`) and the first-shot near-miss (`:1824-1831`, guaranteed 5–9°)
must be equalized/removed for AI-vs-AI, not just the cone width. If the council's probe passes only
because it also happened to zero `aim_error`, say so explicitly — otherwise the next agent "re-tunes
the cone" chasing a ghost.

## The 2:1 is multi-causal — the cone is the SMALLEST of the four causes

Ranked by likely contribution, all enemy-only, all surviving the shared 1.2° cap:
1. **`aim_error` center-offset** (≈±1.7°, `:1789`/`:1200`). Dominant. Not a cone term.
2. **First-shot near-miss** (`:1824-1831`), forced 5–9° miss every fresh engagement — a free first
   round to every ally in every duel. Ally has none.
3. **Behavioral, not accuracy at all:** the arena forces `d_retreats_when_hurt=true` at 35% HP
   (`ai_stress_arena.gd:745-746`) and `char_self_preservation += 0.12` (`:748`) on **VC only**. A
   wounded VC turns and breaks contact — and gets shot in the back by a US line that does not retreat.
   This alone can produce a lopsided kill count with pinpoint cones on both sides. **Unifying the cone
   will not touch it.** A true mirror requires deleting these three enemy-only lines for the probe.
4. **Exposure ramp** (`:1795`, up to 3× early) — inert at the cap for the US gun, but bites the VC
   Mosin (0.6°) which sits under the cap. Asymmetric because the weapons differ (next point).

## The arena is not a mirror — a probe run here proves nothing

- **Mixed weapons.** VC roster (`ai_stress_arena.gd:40-46`) = `vc_rifleman` (Mosin 0.6°), `vc_sapper`,
  `nva_regular`, `nva_rpg` (launcher). US all carry `us_grunt_v3`'s gun. Different `base_spread`,
  different `elevation_for`/ballistics, a launcher on one side. Even with a unified formula, unequal
  `weapon_data.base_spread` inputs yield unequal cones. A launcher-armed sapper is not a rifleman.
- **HP is symmetric** (both `× ai_hp_multiplier`, `:727`/`:738`) — good — but reaction is not: enemies
  gate first fire behind `has_reacted` + a `-0.4..-0.7s` re-acquire **startle** (`:797-798`) with no
  ally analogue (ally only has `_aim_settle` 0.45–0.9s, `:351`, which merely delays, never restarts).

**Demand a dedicated symmetric mirror map** (identical weapon both sides, no retreat, no
self-preservation delta, aim_error/near-miss off, matched reaction) as the ACTUAL C1 probe. Testing
the fix in `ai_stress_arena` conflates cone, weapon, retreat, and reaction, and will report a residual
ratio that no cone change can close. That residual is the trap that burns the next session.

## Fossil Law trap — what is safe to delete vs what is load-bearing

The enemy fire path is RICHER than the ally's, and the extra terms are NOT fossils:
- **DELETE-safe (fairness terms, or gate PLAYER-ONLY):** `aim_error` add (`:1789`), first-shot
  near-miss (`:1824-1831`), `_exposure_spread_mult` (`:1795`), the `*(2.0-char_accuracy)` skew
  (`:1794`). These are the asymmetry. Prefer gating them to `target.is_in_group("player")` over hard
  delete — they exist to protect the player (briefing line 34) and the ally path will need the same
  player-protection when allies can be shot... but allies never shoot the player, so player-only
  gating is clean.
- **MUST STAY, do NOT mistake for the fossil:** hold-over (`:1811-1822`, ally has its own at `:764`),
  **launcher ballistics** (`:1817-1821` — the `pd.gravity_scale` rocket-arc branch the ally path lacks
  entirely because allies carry no launcher; the comment at `:1815-1816` records this fixed an "8×
  too high" rocket bug), the **projectile-vs-hitscan branch** (`:1838-1849`), and muzzle discipline
  (`:1864-1871`, ally has its own at `:780-787`). If someone "extracts the shared model" by treating
  the enemy's longer function as the duplicate to bury, they will delete the RPG's ballistics and
  resurrect the 8×-high rocket. **The shared model is the spread cone ONLY** — not the whole fire
  method. Be explicit about the extraction boundary or Fossil Law becomes the demolition order for
  live launcher code.

## C2 guardrail — the trooper dial leaks to the player two ways

1. **If applied like `GameSettings.enemy_spread_mult()` (`:1796`) — a global cone multiplier — it
   widens the cone against the PLAYER too**, violating Fairness directly. It MUST be gated per-shot on
   `target != null and target.is_in_group("player")` → skip the widen, else apply. Not a global.
2. **The subtler leak, present even with correct gating:** a wider AI-vs-AI miss means more stray
   rounds cracking through the arena. The ray sees layer 2 + hitzones (`:1857`, `collide_with_areas`),
   and `_suppress_player_if_near` (`:1875`) already presses the player on near-misses. **Widening
   AI-vs-AI fire makes the world MORE lethal and MORE suppressive to a bystanding player — the
   opposite of the dial's intent.** "Longer firefights" and "don't touch player lethality" are in
   tension the moment the player stands in a friendly-fire lane. Name it: the dial is safe for the
   ratio, not for the ambient danger.
3. **Headless null-player:** `spawn_player` can be false (`ai_stress_arena.gd:55`); `hot_start` seeds
   nearest-*enemy* targets. So in the probe, `target.is_in_group("player")` is never true and the
   AI-vs-AI branch always fires — fine, but it means the probe **cannot exercise the player-exclusion
   path**. The guardrail must be tested in a scene WITH a player, or the fairness gate ships unverified.

## ADR-010 determinism — the fix can poison the global seed stream

Both fire paths draw from the **global** RNG, not the arena's `_rng` (`ai_stress_arena.gd:77` is
unused by fire): enemy `randf()`/`randfn()`/`randf_range()` at `:1807-1808`, `:1827-1828`; ally at
`:758-759`. The near-miss branch already draws **2 conditional `randf` calls only on the first shot**
(`:1827-1828`) — per-shot draw COUNT already varies. Any refactor that changes how many RNG calls a
shot makes — or a trooper dial written as `if randf() < trooper_chance` — shifts every subsequent draw
and diverges any ADR-010 replay/determinism probe. **Rule for the fix:** the shared model must draw a
FIXED number of RNG values per shot regardless of side or dial; gate the trooper widen with a plain
arithmetic multiply (`total_spread *= dial`), never behind a fresh `randf()`. A conditional draw is the
poison.

## Verdict priority

The cone unification is the LEAST important half of C1. If the probe is the existing arena and the fix
is cone-only, it fails. Fix order that actually reaches ~1:1 in a mirror: (a) equalize weapon/HP,
(b) delete the enemy-only retreat + self-preservation deltas for the probe, (c) zero/player-gate
`aim_error` and first-shot near-miss, (d) THEN unify the cone. The cone is the finish, not the fix.
