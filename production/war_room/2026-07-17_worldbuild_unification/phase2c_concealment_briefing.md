# BRIEFING — CONCEALMENT IS BROKEN (Pillar-3 / Fairness / Rule #1)

**Convened:** 2026-07-17 · **Arbiter:** recon-overseer · **Summoner:** Caleb.

## The report (Caleb's playtest)
He was **~150m out, CROUCHING IN A BUSH thinking he was hidden**, and the **WHOLE CAMP detected him +
focus-fired + INSTAKILLED him** in ~1s. That is three failures at once, and it voids Pillar 3 (stealth
is the economy) + the Fairness Law (ADR-005: alert != accuracy; first shot at an unaware player is a
near-miss; accuracy ramps with exposure).

## The three questions to trace (READ THE CODE)
1. **Does the PLAYER get concealment from vegetation + crouch (low_posture)?** The world computes a
   `GameplayGrid.vegetation_density` and an `enemy_base` sight-cap (~140m open, ~45m dense jungle). Does
   that sight-cap + veg concealment apply to **AI-vs-PLAYER** detection, or only AI-vs-AI? Likely gap:
   the player isn't getting the concealment the system computes. Crouching (low_posture) in a bush
   should heavily cut detectability.
2. **Why did the WHOLE CAMP detect him at once?** Detection must be **PER-UNIT** (each enemy's own LOS +
   concealment + time-to-spot), not camp-wide omniscient. If one enemy spotting = all know instantly,
   that's a bug (or an over-eager shared believed-position / squad broadcast).
3. **Why INSTAKILL at 150m?** A spotted player at 150m in cover should NOT die in ~1s to the whole camp.
   Trace accuracy/lethality at range + whether there's a spot-to-engage grace (the near-miss-first rule).

## Where to look
- `scripts/enemies/enemy_base.gd` — perception (`_update_perception`/sight/witness), the sight-cap
  (grep `SIGHT_CAP`/`vegetation`/`_sight_cap`), accuracy/fire, low_posture/crouch handling, auto-cover.
- `scripts/enemies/enemy_squad.gd` / any squad coordinator — shared target / believed-position broadcast
  (the camp-wide-detection suspect).
- `terrain/core/gameplay_grid.gd` — `get_vegetation`/`get_cover`, the density the sight-cap reads.
- `scripts/player/` — does the player expose a concealment/posture state the AI reads? Is the player in
  a group/has a hurtbox the perception scans, and does that path apply veg concealment?
- ADR-005 (detection-beacon-witness-rule), ADR-006 (scoring), the Fairness Law in DESIGN.
- Load `~/.claude/architect_knowledge/GodotPrompter/skills/ai-navigation/` + `godot_standards.md`.

## The fix to propose (not just diagnose)
Crouching in veg at 150m must actually conceal; detection must be gradual + per-unit; getting seen must
not be instant death. KEEP the tiered-AI + witness guardrails (don't regress `test_activity_tiering` /
`test_ai_fairness` / `test_arena_patrol`). This is IMPROVING the protected foundation (ADR-028), never
rebuilding it.

## Deliverables
Each architect: read code, write full analysis to `analysis/phase2c_<role>.md`, return a SHORT verdict
naming the exact file:line of each of the three failures + the minimal fix. Name what's sacrificed.
