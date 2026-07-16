# Systems Designer — Track C: Unified AI Accuracy Model

Read the CODE (enemy_base.gd, ally_base.gd, ai_stress_arena.gd, game_settings.gd, ADR-010). Not the plan.

## Root-cause confirmation (systems lens)

The 2:1 is FOUR one-sided enemy handicaps stacked on a cone that is otherwise symmetric (both cap at
1.2°). Ranked by real steady-state contribution:

1. **`aim_error` — the killer, and it does NOT live in the fire path.** enemy_base.gd:1200-1204
   accumulates a persistent ±(1-char_accuracy)*0.1 rad DC bias EVERY physics frame in `_update_aim`,
   consumed at fire (1789 `current_aim_dir + aim_error`). At char_accuracy 0.7 that is ~±1.7° — the
   enemy's 1.2° cone is centred up to 1.7° OFF the target. Allies (ally_base.gd:741
   `final_aim = current_aim_dir`) have ZERO bias — cone dead-centred. **A cap on the cone does nothing
   to a bias applied OUTSIDE the cone.** This alone explains most of 2:1.
2. **First-shot near-miss** (1824-1831): guaranteed 5-9° miss every new engagement. Enemy-only.
3. **Exposure ramp** (1795, `_exposure_spread_mult` 169-171): up to 3× cone early. Enemy-only. Only
   bites sub-cap guns.
4. **Situational `accuracy_modifier`** (129, set at 1277-1309 by range/strafe/stillness) and the
   archetype `base_accuracy_modifier` (265, ×1.6/×1.35 at 2121/2135) — enemy-only spread WIDENERS,
   mostly inert at the cap. Allies have no situational term at all.

Two crucial facts the plan got backwards or missed:

- **The arena's `base_accuracy_modifier *= 2.5` (ai_stress_arena.gd:743) is an enemy NERF, inert at
  cap** — `enemy_spread_mult` doc at game_settings.gd:23 confirms higher = worse aim. It is NOT an
  enemy advantage. Delete it.
- **ADR-010:16 explicitly exempts bullet spread from determinism**: *"Per-frame draws (bullet spread,
  hit FX) remain timing-dependent by design… same seed = same world, NOT same bullet holes."* Both
  fire paths already draw from the global seeded stream. **The shared model must keep doing exactly
  that — no `rng` parameter, no second seed** (ADR-010 bans a second seed, decision bullet 1). The
  briefing's suggested `rng` arg would over-promise a determinism ADR-010 deliberately declines.

## The unified model

### Q1 — ONE shared function

New file `scripts/combat/ai_marksmanship.gd`, `class_name AIMarksmanship extends RefCounted`,
static-only. Corrected signature (drop `rng`, add `is_player_target` for the C2 gate):

```gdscript
class_name AIMarksmanship
extends RefCounted
## Shared AI cone + audience-profile spread. ONE spread path for both sides (Fossil Law).
## Draws from the GLOBAL seeded stream by design (ADR-010:16 — spread is non-deterministic).

const CONE_CAP_DEG: float = 1.2
const BLOOM_PER_SHOT: float = 0.06
const BLOOM_CAP: float = 0.8
const EXPOSURE_PEAK: float = 2.0

## acc01 0->1 tightens the cone: 1.6x at 0, 0.4x at 1.
static func _skill_mult(acc01: float) -> float:
	return 1.6 - clampf(acc01, 0.0, 1.0) * 1.2

static func _cone_deg(base_spread_deg: float, acc01: float, shots_fired: int, moving: bool) -> float:
	var s: float = base_spread_deg * _skill_mult(acc01) \
		* (1.0 + minf(float(shots_fired) * BLOOM_PER_SHOT, BLOOM_CAP))
	return s * 1.5 if moving else s

static func _apply_cone(aim: Vector3, spread_deg: float) -> Vector3:
	var spread: float = deg_to_rad(spread_deg)
	var e_right: Vector3 = aim.cross(Vector3.UP).normalized()
	var e_up: Vector3 = e_right.cross(aim).normalized()
	var ang: float = randf() * TAU
	var mag: float = minf(absf(randfn(0.0, 0.45)), 1.0) * spread
	return (aim + e_right * tan(cos(ang) * mag) + e_up * tan(sin(ang) * mag)).normalized()

static func _first_shot_nudge(aim: Vector3) -> Vector3:
	var miss: float = deg_to_rad(randf_range(5.0, 9.0))
	var dir: float = randf_range(0.0, TAU)
	var a: Vector3 = aim
	a.x += cos(dir) * miss
	a.y += absf(sin(dir)) * miss * 0.5 + 0.02
	return a.normalized()

static func compute_final_aim(
		base_aim: Vector3,
		base_spread_deg: float,
		accuracy01: float,
		shots_fired: int,
		moving: bool,
		is_player_target: bool,
		exposure_t: float,
		force_first_miss: bool) -> Vector3:
	var s: float = _cone_deg(base_spread_deg, accuracy01, shots_fired, moving)
	# Fairness ramp is PLAYER-ONLY (the council's open question, answered): AI-vs-AI never
	# gets it, so a mirror is symmetric and the player still gets the warning volley.
	if is_player_target:
		s *= 1.0 + EXPOSURE_PEAK * (1.0 - exposure_t * exposure_t)
	# The trooper dial WIDENS THE CAP, never the pre-cap spread (a spread mult is inert at cap).
	# AI-vs-player keeps the fixed 1.2 cap -> lethality untouched (Fairness Law).
	var cap: float = CONE_CAP_DEG
	if not is_player_target:
		cap *= GameSettings.ai_vs_ai_cone_mult()
	var aim: Vector3 = _apply_cone(base_aim, minf(s, cap))
	if force_first_miss and is_player_target:
		aim = _first_shot_nudge(aim)
	return aim
```

Each method <30 lines, all typed, RefCounted static-only (godot_standards).

### Q2 — exact Fossil-Law deletions

**enemy_base.gd**
- DELETE 1200-1204 (aim_error production in `_update_aim`) AND the `aim_error` var declaration. This
  is the single most important deletion — it removes the top asymmetry AND a per-frame global-RNG
  `randf_range` from the hot path. Set `base_aim = current_aim_dir` (drop `+ aim_error` at 1789).
- DELETE 1791-1799 (`total_spread` block, incl. `_exposure_spread_mult()` and `enemy_spread_mult()`).
- DELETE 1803-1810 (inline cone scatter — extracted).
- DELETE 1824-1831 (inline first-shot near-miss — now inside the shared fn, gated to player).
- DELETE method `_exposure_spread_mult` 169-171 (logic folded into the shared fn); KEEP
  `target_visible_duration`/`d_exposure_ramp` to compute `exposure_t` for the call.
Replacement:
```gdscript
var exposure_t: float = clampf(target_visible_duration / maxf(d_exposure_ramp, 0.1), 0.0, 1.0)
var moving: bool = Vector3(velocity.x, 0.0, velocity.z).length() > 0.5
var is_player: bool = _target_is_player()  # helper: target == GameManager.player
var final_aim: Vector3 = AIMarksmanship.compute_final_aim(
	current_aim_dir,
	weapon_data.base_spread * 1.3 * accuracy_modifier,   # situational modifier folded into base
	char_accuracy, shots_fired, moving, is_player, exposure_t, not _first_shot_fired)
if not _first_shot_fired:
	_first_shot_fired = true
```
KEEP hold-over (1811-1822), muzzle discipline, projectile-vs-hitscan (shooter-specific, as directed).
The enemy's situational `accuracy_modifier` is folded into `base_spread_deg` so enemy texture
survives — but see the residual-asymmetry note below.

**ally_base.gd**
- DELETE 745-761 (spread compute + inline cone). KEEP 741, hold-over 762-764, raycast.
Replacement:
```gdscript
var sa: int = SquadRoster.skill_level(member, "small_arms") if not member.is_empty() else 0
var acc01: float = clampf(skill + 0.04 * float(sa), 0.0, 1.0)
var moving: bool = Vector3(velocity.x, 0.0, velocity.z).length() > 0.5
var final_aim: Vector3 = AIMarksmanship.compute_final_aim(
	current_aim_dir, weapon_data.base_spread * 1.2, acc01,
	shots_fired, moving, _target_is_player(), 1.0, false)
```
Allies almost never target the player, so they take the symmetric AI-vs-AI path; no fairness ramp, no
first-shot miss (both were already absent — no behaviour lost).

### Q3 — reconcile the two accuracy scalars into ONE `accuracy01`

| Side | Source today | -> `accuracy01` in [0,1] |
|------|--------------|--------------------------|
| Enemy | `char_accuracy` 0.5-0.9 (211-212) | pass directly |
| Ally | `skill` randf 0-1 (71) + roster `small_arms` (746) | `clampf(skill + 0.04*sa, 0, 1)` — roster tightening folded IN, so it is ONE input not a second multiplier |

Both then run the identical `_skill_mult` curve. **For a mirror to trend 1:1 the INPUTS must match**:
enemy `char_accuracy` averages ~0.70 (0.5-0.9); ally `skill` is `randf()` ~0.50 (0-1). Equal curve on
unequal inputs is still unequal. **The arena must seed both sides' accuracy01 from ONE identical
`randf_range` in `_finish_agent_setup`** (e.g. roll each fighter's skill/char_accuracy from the same
0.5-0.9 band). This is where a residual imbalance would otherwise hide — name it explicitly.

### Q4 — the ONE dial, and the arena's 2.5×

- **Dial: `GameSettings.ai_vs_ai_cone_mult()` — default 1.0.** This is the Star-Wars-trooper lever
  (C2). It scales the CONE CAP (not pre-cap spread) and ONLY for non-player targets. 1.0 = normal;
  2.5 = troopers, long firefights. Symmetric across both sides -> mirror stays ~1:1 while BOTH get less
  lethal AI-vs-AI. AI-vs-player is fixed at 1.2° -> lethality and Fairness Law untouched. This is the
  correct mechanism because a *spread* multiplier is inert at the cap; a *cap* multiplier actually
  lengthens firefights.
- **DELETE ai_stress_arena.gd:743 (`e.base_accuracy_modifier *= ai_accuracy_mult`) and the
  `ai_accuracy_mult = 2.5` export (72).** It is a one-sided enemy nerf, inert at cap — a fossil dial.
  Replace with the symmetric `ai_vs_ai_cone_mult` (the arena can expose it if per-run tuning is wanted).
- **DELETE `GameSettings.enemy_spread_mult()` from the fire path (1796).** Enemy-only, inert at cap.
  If a difficulty knob for AI-vs-player is still wanted, it should scale the player-target CAP the same
  way — but that is a separate, out-of-scope difficulty decision; for Track C, remove it from the path.

### Q5 — typing / Godot 4.7 / RNG

- **No `rng` param.** ADR-010:16 declares bullet spread non-deterministic by design and bans a second
  seed (decision bullet 1). Keep global `randf`/`randfn`/`randf_range` — matches both current paths and
  is canon-correct. Correcting the briefing here.
- Deleting `aim_error` removes the only PER-FRAME global-RNG call in the aim system (fire is per-shot,
  not per-frame — acceptable hot-path cost). Net RNG churn goes DOWN.
- `class_name AIMarksmanship extends RefCounted`, static-only, no instance/@onready. `randfn`, `tan`,
  `TAU`, Vector3 `cross/normalized` all fine in 4.7. Use `minf/maxf/clampf` per the typing law; all
  params and returns typed; each method <30 lines.
- Retunes to name (no free lunch): enemy `*1.3` vs ally `*1.2` base factor — unify to ONE (recommend
  1.25); enemy bloom 0.08/shot vs shared 0.06, ally was 0.05 additive-in-deg — unify to 0.06 mult.
  These are deliberate, small, and make the paths identical.

## Residual asymmetry (named — no free lunch)

Folding enemy `accuracy_modifier` (situational: range/strafe/stillness) into `base_spread_deg` keeps
enemy texture but means allies, which have no situational term, are NOT a perfect mirror. It is mostly
inert at the cap so its steady-state effect is small, but a true 1:1 requires either neutralising it in
the mirror arena or giving allies parity logic. Recommend: leave it (per "leave shooter-specific bits
in place"), verify with the probe, and only add ally parity if the probe still shows >1.2:1.

## THE RECORD (ADR-015 probes)

- Fossil probe: assert neither enemy_base.gd nor ally_base.gd contains inline `randfn(0.0, 0.45)` cone
  math — both must route through `AIMarksmanship`.
- Behaviour probe: mirror arena (equal accuracy01 inputs, `ai_vs_ai_cone_mult`=1.0) trends within
  ~1.2:1 over N kills; and first AI shot at an unaware player lands as a miss (Fairness Law).
