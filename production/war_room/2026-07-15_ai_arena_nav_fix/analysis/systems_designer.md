# Analysis — systems-designer (loop + beacon consistency)
**Reading:** the 2026-07-15 synthesis (`2026-07-15_arena_handoff_review/synthesis.md`) and the open children of 0623.

## Where this fix sits in the build order
Per the 2026-07-15 synthesis, **Phase A** (telemetry) and **Phase B** (model + cover + vegetation) are done. **Phase C** (tuning: accuracy dial, HP split, survival, suppression) is in progress. The arena is the shipping firefight laboratory; the firefight feel is being tuned for survival/suppression/withdrawal, not kill rates.

The NAV warning is **a Phase B cleanup** that was on the 2026-07-14 hand-off list as item 5 ("NAV error downgraded from push_error to push_warning"). The hand-off said "NAV warning is now a warning, not a blocker, but still appears once for an initial VC spawn" — exactly what the user just saw.

The fix is **upstream of any tuning** because:
- A false-positive warning hides real nav failures during tuning. If a tuning pass introduces a pathing bug (e.g., a new cover point off-mesh that the agent cannot reach), the warning will be drowned in false positives.
- The hunt wedge system (decree 2026-07-12) projects last-known-positions onto the navmesh to compute the sectored expanding net. The same off-mesh-target case applies. Clamping in `_move_toward()` helps the hunt reach its search points.

## Beacon consistency (ADR-005)
The detection beacon doctrine (ADR-005) does not directly interact with this fix. The fix is in the pathing layer, not the perception layer. But the suppression/withdrawal tuning (item 6 of 0623) does interact: a suppression-pinned agent that fails to reach its cover point will be stuck in the open, taking more suppression, and the firefight will be too lethal. The clamp helps pinned agents reach cover, which is the survival-first doctrine.

## Scope consistency
- The fix is **not** a Pillar-1 (gunplay) change. It does not affect damage, accuracy, lethality, or weapon feel.
- The fix is **not** a Pillar-2 (atmosphere) change.
- The fix is **not** a Pillar-3 (freedom) change.
- The fix **is** a Pillar-4 (squad is the RPG) enabler: a squad that can reliably reach its cover/patrol/LKP targets will live longer, lose fewer men, and be more readable as a tactical unit.
- The fix **is** a Pillar-5 (fail forward) enabler: an agent that reaches its LKP after LOS-loss can resume its behavior; an agent that gets stuck is a fossil waiting for the player to clean up.

## Loop consistency
The arena's loop is:
- spawn → idle (sentry scan) → SUSPICIOUS (noise heard) → ALERT (contact) → COMBAT → suppressed → retreat → break contact → re-anchor → resume.

The nav path underpins **every movement in this loop**. If `_move_toward()` is unreliable, the agent gets stuck, the loop stalls, and the player's perception is "the AI is dumb" — exactly the opposite of the AI North Star.

## What I would NOT touch
- I would NOT touch the arena's `ai_hp_multiplier`, `ai_accuracy_mult`, `ai_retreat_hp`, or `reserve_rate_multiplier`. Those are tuning levers per Phase C, and changing them is outside 0623.1's scope.
- I would NOT touch the `is_navigation_finished() -> direct steering` fallback. That fallback is the safety net for unreachable targets; the clamp just makes the "reachable" case cover more ground.
- I would NOT add a new `target = clamp_target(target)` at the call site. The clamp belongs in `_move_toward()` because that's where nav is consulted; making it a per-call-site concern would scatter the logic.

## Tradeoff
- **Single chokepoint fix vs. per-call-site fix:** chokepoint is the right choice. All nav-routed movement flows through `_move_toward()`; if a future goal (e.g., the unused `current_goal = PATROL` stub in `enemy_base.gd`) calls `_move_toward()`, the clamp is automatic.
- **Arena-only fix vs. structural fix:** structural fix wins. The bug is in the agent; the arena is just where the user noticed it. Any future lab scene (e.g., a per-faction weapon range, a stealth ambush test) would re-introduce the warning without the structural fix.

## Verdict
**APPROVE the lead-programmer's fix as a structural improvement to the pathing layer.** This is **not** a tuning change; it is a reliability change that makes future tuning safer (real nav failures are no longer drowned in false positives). The fix fits the AI North Star and the systems-design pattern of "one chokepoint, no per-call-site duplication."

**Ask the council:** does this fix need to wait for **any** tuning bead (0623.5/7/8) to close, or is it safe to ship independently? My read: ship it now. The fix is additive, structural, and helps every future tuning pass.
