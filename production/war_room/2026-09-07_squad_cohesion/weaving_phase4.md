# PHASE 4 — THE WEAVING (NOT A DECREE)

**2026-09-07. Seven architects. The Summoner rules; this synthesis stops short of judgment on purpose.**

## What his reframe did

He moved the question from *should cohesion exist* to *why does correct behaviour look wrong*. That is the
same move as his Brothers in Arms finding: the felt problem was real, the named system was not the one at
fault. Phase 2 proved the decisions are real. Phase 3 asked why they read at 60%.

## The verdict the room converged on

**The animation ARCHITECTURE is not the defect, and it is better than the reference games'.** Verified in
code by three architects independently and spot-checked by the Arbiter: a 0.18 s crossfade with cycle-phase
preservation (`model_actor.gd:1028-1038`), playback rate matched to authored clip speed, 8-way octant
locomotion, measured turn-in-place, a frame-rate-independent damped yaw, an additive spine flinch that never
steals the clip, five separate goal-churn dampers and a 180 ms intent stability filter **longer than the
think interval**. Call of Duty 1 had none of this.

**Two mechanisms explain the gap, and both are cheap.**

### 1 · THE PARITY GAP — the player's own squad is the unfinished half
The enemy has body beats the ally does not have **at all**. `grep flinch|stumble_hit scripts/allies/ally_base.gd`
returns **nothing**; `enemy_base.gd:623,2653-2654` has both. The arrival plant (`run_to_stop`), the stumble,
the grenade windup and the spine flinch are enemy-only. **Every clip exists and is already mapped.**
The player watches his own squad more than anything else in the game, and his own squad is the half with no
performance beats.

### 2 · THE CADENCE GAP — this project already diagnosed it, for the siege only
`siege_director.gd:615-618`, verbatim:

> *"THE PRESS ROTATES BY SQUAD, not by man. Scattering the press across individuals put a third of every
> squad walking while the men beside them held — **which reads as indecision, not as fire and movement.**"*

`data/ai/doctrine_us.tres` ships `exposure_tokens = 3`, `grant_stagger_ms = 600` — three of five to eight men
breaking cover 0.6 s apart. **That is the exact pattern the siege comment condemns, still running in the
squad fight.** The siege is insulated: `doctrine_assault_press.tres` is a separate file, so tuning the patrol
dial cannot touch the climax.

And the reference finding that explains both: **Brothers in Arms and CoD1 look smooth because they moved
less.** BiA's enemies were near-stationary by design; movement was front-loaded into one scripted run.
Neither game solved locomotion quality — they avoided the problem. Stillness is what makes motion read.

## The disagreement that did NOT resolve

**Does any of this need new CLIPS?** The technical artist says yes and names three: rifle-ready start poses
measured **76° apart** across the game's most-played transition, `aim_walk` falling back to the patrol walk,
and hip sway stripped by the exporter. The game designer, combat-reference analyst and programmer all say the
missing 40% is not clips. **This is the live fight and it is an art-day question, so it is the Summoner's.**

Second live fight: the **upper-body aim layer**. The technical artist calls it zero art-days and the single
biggest visual return available. The programmer calls it GATED and names the leak: *"an AnimationTree rewrite
will arrive dressed as a blend-time tweak."*

## Two honest self-corrections, recorded

- **The programmer retracted his own Phase 2 evidence.** The `ai_usec_anim` bucket is a misnomer — it
  measures the execute span, not animation. Godot's track evaluation, pose update and skinning sit in none of
  the four buckets. **Nobody in this project has ever measured what character animation costs.** He refused to
  let his own 1.20 ms think figure be used to call blend trees free.
- **The UX designer retracted the audio ruling he built Phase 2 on.** Barks are hard-capped at 45 m
  (`vo_manager.gd:103`) against a 140 m open-ground sight cap. The player can see a man he cannot hear.

## Arbiter's own corrections this session (NO MORE DRIFT)

1. **`GAME_GUIDE.md` §8.1 item 3 was false and is corrected in place.** "EnemyBase has no dresser call at all
   — every VC/NVA man is a clone" — the dresser **is** built and **is** called (`enemy_base.gd:470` →
   `_dress_visual` → `VcNvaDresser.dress`, `:511-516`). True on 2026-08-06, false now. The open half is
   whether the variety READS, which only a playtest settles.
2. **`production/research/squad_mechanics.md`** carried a stale "verified baseline"; notice added.
3. **A truth-law violation in shipping code**, flagged not fixed: `ally_base.gd:1712` clears the animation
   override with the comment *"the pin hunker outranks any latched cover pose"* — **there is no pin hunker.**
   `cover_kneel_brace` exists in the library and nothing plays it. The comment claims behaviour that does not
   exist, which ADR-015's truth law forbids.
4. **`ANIM_VARIETY_PLAN.md` is refuted** on its central claim that cower is "the one genuine gap with neither
   art nor code." The art exists.

## The instrument the room agrees is missing

Nobody can close "smoother" under ADR-015. Three probes were proposed and they are complementary, all
gate-exempt, all zero art-days:

- **The stillness census** (game designer) — in the arena, what fraction of visible men are moving and for
  how long. Falsifiable prediction on the record: **>40% moving, median under 1.5 s**, against CoD1's ~20-30%
  and 2-4 s. If it comes back CoD1-like, the cadence thesis dies and the answer is clips.
- **The churn probe** (programmer) — instrument `ModelActor.play()`; acceptance is zero committed dwells below
  the 180 ms floor.
- **The resolver log** (Devil's Advocate) — log every alias hop and family miss across one run; the output is a
  ranked list of named defects with counts.

**All three architects independently conceded the same limit: no probe proves it LOOKS better. The honest
closing rule is the gate's own two keys — a probe proves no regression, his eyes prove the feel.**

## Standing at the end of Phase 4

Nothing is decreed. Nothing is built. The perf baseline and THE WALK / ONE DIG / THE BARRAGE still have never
been run, and the demo playthrough gate is still undischarged.
