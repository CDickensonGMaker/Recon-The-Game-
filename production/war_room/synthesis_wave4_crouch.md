# Decree — Wave 4 (Track B2/B3): tactical crouch locomotion

**Arbiter synthesis, 2026-07-16.** Three architects (systems-designer, ai-programmer, devil's-advocate),
independent, no cross-talk, **all three returned the SAME P0**: keying `low_posture` on
`suppression_level >= 0.35` REGRESSES the exact aggression Caleb liked. Suppression jumps +0.45–0.5 on a
single hit/stagger (enemy_base ~1991/2116); an advancing man who merely gets shot at parks in the
0.35–0.70 band all fight, still ADVANCING/COMBAT — so the swap to slow crouch fires precisely when the
player returns fire, and the plan's guardrail ("COMBAT + no suppression → stand") never triggers because
no-suppression never lasts. Convergence from three doors = strongest signal the process gives.

## The corrected design (all three fixes woven)

1. **DROP the suppression band from the locomotion key** (devil's-advocate). Kneel-at-0.7 (SUPPRESSED →
   `cover`/`idle_crouching`) already owns heavy fire. `low_posture` fires ONLY on genuine caution:
   - **Enemy:** `not firing AND ( state==SUPPRESSED  OR  (state ∈ {SEEKING_COVER,ADVANCING,FLANKING}
     AND alert_tier <= SUSPICIOUS) )`. A confirmed (alert COMBAT/ALERT) or firing assault → false → stand-push.
   - **Ally:** `not firing AND ( suppression_level >= 0.6  OR  (state==SEEKING_COVER AND no LOS) )`.
     Allies default aggressive (Caleb liked the US push); crouch only when heavily pinned or moving
     eyes-off to cover. (Allies have no alert_tier / no SUPPRESSED state — grep-confirmed.)
2. **Kinematic backstop** (systems-designer): the intent post-filter remaps to crouch ONLY when
   `speed <= LOW_POSTURE_SPEED_MAX (2.6)`. A rushing/routing man (`sprint`, >2.6) stays upright BY
   PHYSICS. `sprint` and the lateral `sneak_l/r` (cover_sneak) are excluded → no orphaned cover_sneak
   (would have been a fresh ADR-023 fossil).
3. **Movement coupling** (ai-programmer): the funnel is DISPLAY-ONLY — swapping crouch clips onto a
   full-speed man ice-skates (`set_locomotion_speed` clamps at 1.4×). So when `_low_posture` is active,
   cap planar velocity at `CROUCH_SPEED_CAP (1.9 m/s)` between `_execute` and `move_and_slide`. This is
   the piece that makes "move low" actually mean "move slow" — safe because low_posture is caution-only,
   so ONLY cautious approaches slow down; the aggressive assault (fast, firing, confirmed) is untouched.
   B2 is therefore NOT pure wiring — the velocity cap is required and is named.

## B3 cover-exit
Self-clearing `_cover_exit_until_ms` transient (mirrors the proven `_leap_until_ms` pattern, no
`_anim_override` leak / "frozen crouch statue"). Set in `_release_cover` when the man actually held
cover AND is alive (guard `state != DEAD`, enemy also `not is_downed` — death paths route through
release; an unguarded corpse would stand up). Debounced (`COVER_EXIT_DEBOUNCE_MS 1500`) so cover-thrash
can't stutter a perpetual half-rise. Checked at top of `_update_sprite`, plays `cover_to_stand`, returns.

## Fossil Law
Wiring the 4 cardinals + `idle_crouching`/`idle_crouching_aiming` DISCHARGES the built-ahead
`walk_crouching_*` set (ADR-023). Diagonals are NOT given new intents (the standing side has no
diagonal intents either — parity; clips are not GDScript symbols, so not in the fossil register).
cover_sneak stays wired via the untouched `sneak_l/r`. No new fossil, no orphan.

## The single named sacrifice
**Posture stops signalling nerve as finely.** With suppression dropped from the key, you can no longer
read "a man pushing THROUGH fire" vs "a man breaking" from his stance alone at the 0.35–0.70 band — he
stands and pushes until he either fully breaks (SUPPRESSED, 0.7) or is cautiously approaching. We trade
that fine-grained fear-tell to protect the aggression Caleb explicitly liked. Accepted: aggression is a
pillar-adjacent Summoner preference; posture-nerve nuance is not.
