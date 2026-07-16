# THE DECREE — Track C: AI Accuracy Unify + Firefight-Length Lever (2026-07-16)

Three architects (systems, game-designer/fairness, devil's-advocate) read code independently and
CONVERGED. Strongest signal the process produces. Arbiter's weaving:

## Root cause of the US 2:1 (agreed, ranked)
The cone is NOT the cause. Both sides already cap at 1.2°, so cone WIDTH is symmetric. The 2:1 is
enemy-only handicaps that survive the cap:
1. **`aim_error`** — enemy_base.gd:1200-1204 builds a persistent ±(1-char_accuracy)*0.1 rad (~±1.7°)
   DC bias, consumed at :1789. Centers the enemy cone OFF-target. Allies (ally_base.gd:741) have none.
   **A cap cannot fix a bias applied OUTSIDE the cone.** #1 driver.
2. **First-shot near-miss** — enemy_base.gd:1824-1831, guaranteed 5-9° miss per engagement. Enemy-only.
3. **Enemy-only RETREAT behavior** (devil's advocate) — arena forces VC `d_retreats_when_hurt=true`
   + self-pres +0.12 (ai_stress_arena.gd:744-747): wounded VC break contact, get shot in the back by
   a US line that never retreats. NOT accuracy — a behavioral bias the mirror probe MUST neutralize.
4. **Exposure ramp** (enemy_base.gd:1795) — up to 3× cone early; enemy-only; bites sub-cap guns.
5. **Arena `base_accuracy_modifier *= 2.5`** (ai_stress_arena.gd:743) — the plan calls this an enemy
   ADVANTAGE; it is BACKWARDS. It is a spread WIDENER (higher = worse aim, per game_settings.gd:23),
   an enemy NERF, inert at the cap. A fossil dial. DELETE.

## The decree

**1. ONE shared model** — new `scripts/combat/ai_marksmanship.gd`, `class_name AIMarksmanship extends
RefCounted`, static-only. Two functions: `cone_spread_deg(...)` (the unified spread curve) and
`aim_with_spread(...)` (cone application + cap + audience profile). Both fire paths call them.

**2. Fossil-Law deletions** (same change): enemy_base.gd aim_error var + producer (1200-1204), consume
site (1789 `+ aim_error`), total_spread block (1791-1799), inline cone (1803-1810), inline first-shot
(1824-1831), `_exposure_spread_mult` (169-171). ally_base.gd spread+cone (745-761). arena 2.5× (743)
+ `ai_accuracy_mult` export (72). `enemy_spread_mult` removed from the fire path. KEEP hold-over,
launcher ballistics (:1817-1821 — deleting it resurrects the 8×-high rocket bug), muzzle discipline,
projectile-vs-hitscan.

**3. Fairness terms PLAYER-TARGET-ONLY** (the council's open question, answered from GAME_GUIDE.md:40-42
— the Fairness Law protects the *unaware player*, an AI has no startle to protect). First-shot near-miss
and exposure ramp fire ONLY when `is_player_target`. This makes the mirror clean AND gives C2 its home:
the AI-vs-AI branch.

**4. ONE dial (C2)** — `GameSettings.ai_vs_ai_cone_mult` (default 1.0). It scales the CONE CAP for
non-player targets only. A pre-cap spread multiplier is inert at the cap (proven by the dead 2.5×); the
CAP multiplier is what actually lowers hit probability and lengthens firefights. 1.0 = fair baseline
(mirror ~1:1); 2.5-3.0 = "Star Wars trooper" long firefights. AI-vs-player stays pinned at 1.2° →
lethality + Fairness Law untouched. Pure arithmetic, zero new RNG draws (ADR-010:16 — spread is
non-deterministic by design; NO rng param, NO second seed).

**5. Unified accuracy scalar** — enemy `char_accuracy` → accuracy01 direct; ally
`clampf(skill + 0.04*small_arms, 0, 1)`. Mirror is only symmetric if the arena seeds BOTH sides'
accuracy01 from ONE identical band — the arena mirror_mode does this.

## The guardrail invariant (code, allowed as a real constraint)
The wide-miss cap multiplier is applied ONLY on the `not is_player_target` branch; the player branch
uses the fixed 1.2° cap. The first-shot mercy near-miss is added ONLY on the `is_player_target` branch.
One target-keyed switch, never two formulas (Fossil-Law risk named).

## RESOLVED DISAGREEMENT — C2 mechanism
Game-designer wanted an added cone-CENTER OFFSET; systems wanted a CAP widen. Both survive the cap
(the shared worry). Arbiter picks CAP-WIDEN: one symmetric number, doesn't reintroduce the center-bias
concept we are deleting as the asymmetry source, trivially reasoned. IF the firefight-length probe
shows cap-widen is too weak (randfn centers on 0, so many shots still land near-center), escalate to a
minimum-offset floor — decided by measurement, not taste.

## SACRIFICES NAMED (no free lunch)
- **Weapon identity by damage is already gone (wave 2); now accuracy is also symmetric-by-formula** —
  weapon character lives only in base_spread/fire-rate/handling.
- **A permanent target-keyed fork in the fire path** — must stay ONE param switch or it decays into
  two formulas again (the exact fossil we are killing).
- **Simulation honesty spent for pacing** — a watchful player may notice "they hit me but miss each
  other." Accepted: it is suppression theater, Pillar 2 (atmosphere) over strict realism.
- **Wider AI-vs-AI fire = more stray rounds in a bystander's lane** — the dial makes the world slightly
  more dangerous to a player standing IN an AI-vs-AI firefight, though no AI aiming AT the player is
  affected. Accepted as realism (a stray round is a stray round).
- **Residual: enemy situational `accuracy_modifier` folded into base_spread has no ally counterpart** —
  mostly cap-inert; verify with the probe, add ally parity only if mirror stays >1.2:1.

---

## MEASURED RESULTS (ADR-015 probes, headless Godot 4.7)

### Mirror-match symmetry (`tests/test_mirror_match.tscn`) — the regression guard
Identical weapon/HP/accuracy both sides, enemy-only retreat stripped. US:VC kill ratio, aggregated:
- **Mosin (tight 0.6deg, discriminating — committed probe config):** BEFORE 1.554 (US 87:VC 56, 143
  kills) -> **AFTER 1.027 (US 77:VC 75, 152 kills).** BEFORE fails the 0.8-1.25 band; AFTER passes,
  centered. The probe now *fails on the old code and passes on the new* = a real guard.
- **M16 (mid 1.6deg, conservative):** BEFORE 1.195 -> AFTER 0.976 (168 kills). Same direction; the
  cap masks more of the bias, hence a weaker signal — why the committed probe uses the tight rifle.

### Fairness Law (`tests/test_firefight_len.tscn`, 4000-sample direct assertion)
At dial 1.0 AND dial 3.0:
- **Player-target cone max deviation = 1.20deg at BOTH dials** — the firefight dial NEVER widens a
  shot at the player. Guardrail holds.
- AI-target cone: 1.20deg -> **3.60deg** at dial 3.0 — the widen reaches AI-vs-AI only.
- First shot at the player = telegraphed >=5deg near-miss. PASS both dials.

### Firefight length (`tests/test_firefight_len.tscn`, 3-run avg, 18v18 mirror)
- **dial 1.0:** 59.6s avg duration, 27.3 kills -> 0.46 kills/s.
- **dial 3.5:** 76.2s avg duration, 27.0 kills -> 0.35 kills/s (+28% duration, -23% kill rate; 2/3
  rounds ran the full 90s without a wipe vs 1/3 at dial 1.0). The dial measurably lengthens
  AI-vs-AI firefights while player lethality is provably untouched.

### The dials Caleb turns
- **`GameSettings.ai_vs_ai_cone_mult`** (default 1.0) — THE firefight-length lever. Also exposed on the
  arena inspector as `AIStressArena.ai_vs_ai_cone_mult` (pushed into GameSettings on _ready).
- Arena symmetry harness: `AIStressArena.mirror_mode` + `rng_seed`.

### Note on the "2:1"
The plan/context framed the arena's US 2:1 as an accuracy asymmetry and called the arena's 2.5x an
enemy *advantage*. Code says otherwise: the 2.5x is an enemy *spread widener* (nerf), inert at the cap;
the real fire-model asymmetry, isolated in the mirror, was ~1.2-1.55:1 (enemy aim_error + first-shot +
exposure). The full-arena 2:1 stacked that on top of enemy-only retreat behavior + mixed weapons +
(pre-wave-2) damage. This change removes the fire-model asymmetry and the mislabeled 2.5x nerf.

### Out of scope / flagged
- `tests/test_fossils.tscn` is RED with 18 NEW fossils — ALL pre-existing branch debt (world_sim
  materialize/dematerialize/update_player, sim_clock/convoy/dynamic_mission_factory signals,
  ambush_planner/squad_leader/paddy_stamper consts). NONE from Track C. These are the LOD-sim + living
  world stubs the plan defers to Track F / next session. Filed, not fixed.
