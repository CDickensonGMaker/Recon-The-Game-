# DECREE — CONCEALMENT + OPACITY (improving the protected foundation, ADR-028)

**Arbiter:** recon-overseer · **Date:** 2026-07-17 · **Council:** perception + fairness architects
(analyses in `analysis/phase2c_perception.md`, `phase2c_fairness.md`). **Summoner:** Caleb.

## The report
Caleb, ~150m out CROUCHING IN A BUSH, was detected + focus-fired + INSTAKILLED by the whole camp in
~1s. Three failures at once (Pillar 3 + Fairness Law).

## Diagnosis (both architects converged)
1. **No player concealment.** The bush he hid in doesn't exist in the AI's field: `_sight_cap`
   (`enemy_base.gd:649-656`) reads `GameplayGrid.get_vegetation`, a 12m biome grid — a decorative
   bush/clutter prop is finer than 12m, so it's invisible to the AI. Crouch reduced only the awareness
   RATE (`:811-818`), never the CAP, so a crouched-but-inside-cap player still gets seen.
2. **Whole-camp fire = blind cold fighters.** Not a propagation bug (each man sights independently) — the
   killer is `_think_cheap_combat` forging LOS: `has_line_of_sight = target != null` (`:589`), so cold
   fighters who CANNOT see the player pour precision fire on the squad-shared target.
3. **Instant death = the exposure ramp was DEAD.** The Fairness Law ramp exists but the fixed 1.2° player
   spread cap (`ai_marksmanship.gd:75`) clipped it: any weapon with a natural cone > 1.2° (AK ~1.7°)
   fired the same lethal cone fresh AND converged. No range falloff at 150m. First-shot mercy survived,
   but N men × instant accurate fire = dead.

## THE FIX (shipped; keeps tiered-AI + witness guardrails; all combat probes green)
- **A — crouch/prone conceals at range.** `_update_perception`: for a STATIONARY crouched/prone player,
  tighten the sight cap (`cap *= 0.6` crouch, `*= 0.4` prone). A crouched-still player in a grassland
  bush (cap ~111m) now caps at ~67m — invisible at 150m. Moving cancels it (you break your own hide).
- **B — cold fighters fire only at what they WITNESS.** `has_line_of_sight = target != null and
  _can_witness(last_known_target_pos)` — unseen men suppress/investigate, not deadeye-fire. Kills the
  camp-wide blind focus-fire.
- **C — the player spread cap BREATHES with the ramp.** `aim_with_spread` player branch: `cap *=
  exposure_spread_mult(exposure_t)` — fresh 3.6° (opening volley whiffs at 150m) → converged 1.2°
  (lethal). Getting seen is no longer instant death. Proven: `probe_concealment` — fresh cone 2.93× the
  converged cone.

## OPACITY (the "see-through trees")
The near-solid tree materials are opaque (same as the arena, which reads solid) — not the bug.
`TreeCoverLayer` set `VISIBILITY_RANGE_FADE_SELF`, which alpha-dithers trees to semi-transparent across
the LOD fade bands (near→card cross-fade at ~46m, cull at 80m). The arena instances raw GLBs with no LOD
range → no fade → solid. Fix: `VISIBILITY_RANGE_FADE_DISABLED` — hard PS2 snap (ADR-026), no fade,
trees read solid. Deleted the now-orphaned `fade_margin` (fossil law).

## Sacrificed (named)
A makes a stationary croucher hard to see even in the open past ~84m (the honest heavier fix is stamping
bush/clutter concealment into the grid at prop scale — beaded). B trades instant camp light-up for a
correct few-beat convergence. C means fresh AI fire is inaccurate at ALL ranges (a CQB camp can be
face-tanked ~2s) — tunable via `EXPOSURE_PEAK` / per-archetype ramp. Hard LOD snap = a visible tree
pop at the boundary (PS2-correct per ADR-026).

## Verify
`probe_concealment` PASS (ramp alive, converged still lethal). Guardrails green: test_ai_fairness,
test_flat_damage, test_activity_tiering, test_arena_patrol, test_ai_stress_arena. 0 SCRIPT ERROR.
Real test = Caleb's eyes: crouch in a bush at range, the camp should NOT instakill you. Windowed re-check
(look-only, Blender open) after.
