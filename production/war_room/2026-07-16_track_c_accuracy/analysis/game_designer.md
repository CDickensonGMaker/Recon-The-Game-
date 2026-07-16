# GAME-DESIGNER Analysis — Track C: AI Accuracy Unify + Firefight Lever

Lens: fairness + gunfeel. Pillar 1 — *death from situation (ambush, exposure, volume of fire),
never bullet sponges.* Read from code, not plan.

## Code confirmed
- Enemy fire path `enemy_base.gd:1789` centers the cone on `current_aim_dir + aim_error`, where
  `aim_error` (`:1200-1204`) is a slowly-lerped random vector of magnitude `(1-char_accuracy)*0.1 rad`
  (≈±1.7° at char_accuracy 0.7). The 1.2° cap (`:1799`) tightens the CONE but does nothing to the
  OFF-CENTER — the tight cone is aimed up to 1.7° beside the man. That off-center is the 2:1.
- Ally fire path `ally_base.gd:741` centers on `current_aim_dir` with NO offset term — dead-centered.
- First-shot near-miss `:1824-1831`: guaranteed 5–9° whiff on each new target. Enemy-only.
- Exposure ramp `_exposure_spread_mult()` `:169-171`: up to 3× cone at fresh exposure; a spread
  MULTIPLIER, so it is eaten by the 1.2° cap for base rifles and only bites sub-cap guns (Mosin 0.6°,
  M70 0.4°). Enemy-only.
- Fairness Law (GAME_GUIDE §40-42) is stated in PLAYER terms: "first shot at an unaware **player**,"
  "ramps with **player** exposure." DESIGN.md has no literal §4.2 text — GAME_GUIDE is the canon line.

## Q1 — C2 "Star Wars trooper" dial: mechanism, default, magnitude

**Feel target.** "Bullet sponge" = rounds CONNECT and the target eats them (or connect and do nothing).
"Suppression theater" = rounds visibly MISS — crack past, kick dirt, chew the treeline — while any
round that *does* land stays HLL-lethal. So the C2 rule is absolute: **the widen may only lower hit
PROBABILITY, never per-hit damage, and the misses must be VISIBLE** (tracers + impact FX near, not on,
the target). That is the volume-of-fire fantasy, on-pillar.

**Offset, not multiplier — this is the load-bearing call.**
- A **spread multiplier** on `total_spread` widens the cone around a still-correct center, then hits
  `minf(...,1.2)`. For every base rifle it is INERT at the cap — this is exactly why the arena's 2.5×
  does nothing (briefing §5). A multiplier is the WRONG tool for a firefight-length lever.
- An **added cone-center offset** (the `aim_error` mechanism) survives the cap: cone stays tight, but
  its center wanders off the man. This is what actually creates misses and what reads as "spraying in
  his general direction." **C2 must be an offset, re-rolled/wandering per engagement — not a
  multiplier.** (A multiplier only shapes scatter texture; keep the cap, leave it be.)

**Default = 1.0 on the SHARED baseline offset, not on "today."** Today is asymmetric (enemy 1.7° / ally
0°) and that asymmetry IS the bug. Unify both sides onto one shared symmetric offset — set the baseline
to the *cleaner* end (~0.5–0.7° residual wander of a trained-but-imperfect shooter, NOT 1.7°). Express
the dial as a MULTIPLIER on that baseline offset: `ai_firefight_spread: float = 1.0`. At 1.0, both AI
sides shoot the same small offset → the mirror trends ~1:1 (that is C1). Turn it up and firefights
lengthen (that is C2 — same knob past 1). Be honest in the decree: **1.0 is the new fair baseline, not
current behavior** — it de-handicaps the enemy and slightly de-buffs the ally on purpose.

**Magnitude band (100m intuition: 1° ≈ 1.75m; a man ≈ 0.5m wide):**
- ~0.3° = edge of guaranteed hit (baseline ×~0.5) — knife-fight lethal.
- **1.0 baseline (~0.5–0.7°)** — frequent hits, occasional miss; clean ~1:1 mirror.
- **×2.5–3.0 (~1.5–2.0°) — the "trooper" band:** mostly misses at range, must close to kill.
  Noticeably longer firefights, reads as suppression. Above ~×4 it tips into farce (never resolves) —
  cap the dial so misses always read as *suppressing*, never as *incompetent*.

## Q2 — Fairness terms: player-only or symmetric?

**First-shot near-miss → PLAYER-TARGET-ONLY (a).** Its entire purpose is to protect a *human's*
startle-and-orient window — the warning crack that lets a player whip the camera and read the threat.
An AI has no reflex to protect; AI-vs-AI it is just a guaranteed opening whiff no one experiences,
diluting lethality for no reader. Gating it player-only makes the mirror CLEAN (strip it → pure shared
model → 1:1) and makes **C2 fall out naturally: the AI-vs-AI branch is simply "shared symmetric model +
firefight dial," with none of the player-mercy terms.** Two branches, one target-is-player switch —
not two copied formulas.

**Exposure ramp → keep in the SHARED model (both sides, symmetric).** Unlike the near-miss, "spotted →
sprays wide → settles → tightens" is honest ballistics with atmospheric value even AI-vs-AI, and being
symmetric it does not skew the mirror. It also barely bites at the cap, so it is cheap either way.
(If the council wants the absolute cleanest 1:1 it can go player-only too — it won't break the mirror
either way — but I'd keep it shared for the settling-in texture.)

## Q3 — Guardrail invariant (one line, a real constraint under Comment Discipline)

```gdscript
# INVARIANT: firefight-spread offset is 0 whenever target is in group "player";
# AI-vs-player hit chance is set by the shared Fairness model ALONE. Never widen against the player.
assert(firefight_widen == 0.0 or not target.is_in_group("player"))
```

Mirror guard on the mercy term: the 5–9° near-miss is added ONLY inside
`if target.is_in_group("player")`. The two guards are complementary — the player never sees the widen,
the AI never sees the mercy.

## Q4 — The sacrifice (no free lunch)

1. **A permanent target-keyed fork in the fire path.** One shared model with a target-conditional term
   is right; the risk is it decays into two duplicated formulas — the exact Fossil-Law failure this
   track is fixing. Discipline required: one parameter switch, not a copied path.
2. **Simulation honesty is spent for pacing.** AI-vs-AI is now *deliberately* less accurate than
   AI-vs-player. A watchful player WILL notice "they hit me but keep missing each other." In a
   hardcore-realism game the world is no longer one physics — that is a genuine cost, paid for firefight
   length and player fairness.
3. **Friendly AI reads as less competent.** Widening AI-vs-AI slows ally kills → the player carries more
   of the fight (on-pillar: you're the operator) but allies feel weaker, and a too-high dial turns
   distant firefights into unresolving ammo theater — "bullet sponge by other means." The band must stay
   where misses read as *suppression* (close to kill), never *farce*.
