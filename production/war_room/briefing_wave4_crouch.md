# War Room Briefing — Wave 4 (Track B2/B3): tactical crouch locomotion

## Query
Wire a `low_posture` flag into the AI locomotion funnel so units under fire / suppressed / cautiously
approaching known contact swap standing locomotion → the existing `walk_crouching_*` clip family, and
play `cover_to_stand` when leaving cover. **The guardrail:** crouch-walk is SLOW; wiring it too eagerly
kills the aggressive stand-and-push Caleb explicitly LIKED. Crouch must be the EXCEPTION, not the rule.

## Pillars in play
- P1 outstanding gunplay (a moving man reads honestly; death from situation)
- P2 atmosphere (tactical, not goofy)
- The coupled bet (plan through-line): deadlier VC (wave 2) is only good if allies self-preserve
  believably — going low under fire IS that self-preservation on screen — BUT only if aggression still reads.

## Confirmed facts (from code + GLB, this session)
- `anim_library.glb` = 100 clips. Present: `walk_crouching_forward/backward/left/right` + 4 diagonals,
  `idle_crouching`, `idle_crouching_aiming`, `cover_to_stand`(+`_2`), `stand_to_cover`x3,
  `crouching_turn_90_left/right`. So NO new art — pure wiring.
- The funnel = `scripts/visuals/sprite_state_map.gd`: `intent_for(state, is_crippled, is_surrendered,
  is_firing, speed, lateral, sneaking=false) -> intent`, then `clip_for(is_model,...) -> clip`
  (MODEL_CLIP for models, resolve()/CHAINS fallback for sprites).
- `walk_crouching_*` is wired to NOTHING today (built-ahead-of-wiring, ADR-023). `idle_crouching` /
  `cover_to_stand` also unwired in the intent map (only civilian.gd + gore_dummy reference some).
- Callers: enemy `enemy_base.gd:376`, ally `ally_base.gd:268`. Both compute speed+lateral; enemy also
  passes `sneaking = (SEEKING_COVER and alert_tier <= SUSPICIOUS)`.
- Signals available: enemy `suppression_level` (0-1; SUPPRESSED state flips at >0.7), `alert_tier`
  (RELAXED/SUSPICIOUS/ALERT/COMBAT). Ally `suppression_level`, `has_line_of_sight`, `courage`,
  `_anim_override`. Existing `sneaking`→`sneak_l/r`→`cover_sneak_*` lateral sneak is UNTOUCHED.

## Proposed design (stress-test this against the pillars + guardrail)
1. Add `low_posture: bool` param to `intent_for` (defaulted false → sprite billboard + any third caller
   unaffected). POST-FILTER: if `low_posture` and the resolved intent is a standing-locomotion intent
   (run/sprint/walk/aim_walk/patrol/sneak_l/sneak_r/arrive/retreat), remap by kinematics to a NEW crouch
   intent: still→`crouch_idle`(idle_crouching); |lateral|>0.6→`crouch_l/r`(walk_crouching_left/right);
   else→`crouch_fwd`(walk_crouching_forward); retreat→`crouch_back`(walk_crouching_backward). Add these
   5 intents to MODEL_CLIP + sprite CHAINS (chains end safe at rifle_aiming_idle).
2. Caller computes `low_posture` where the guardrail lives:
   - Enemy: `low_posture = suppression_level >= 0.35 OR (cautious approach: SEEKING_COVER/ADVANCING/
     FLANKING AND alert_tier <= SUSPICIOUS)`.
   - Ally: `low_posture = suppression_level >= 0.35 OR (moving to last-known WITHOUT LOS: careful advance)`.
   - **GUARDRAIL:** ADVANCING/COMBAT while HOSTILE (alert COMBAT) with NO suppression → low_posture FALSE
     → run/walk stand-push. Aggression preserved by construction.
3. B3 cover exit: dedicated self-clearing transient `_cover_exit_until_ms`; on `_release_cover()` while
   alive+had cover, play one-shot `cover_to_stand`, honored in `_update_sprite` until the window, then
   normal flow resumes (avoids the known "frozen crouch statue" leak).

## Return (terse, <200 words each)
- Does this preserve the aggression Caleb liked? Where could crouch leak into an aggressive push?
- Fossil Law: does this genuinely DISCHARGE walk_crouching, or leave it half-wired / orphan cover_sneak?
- Funnel integrity: right to post-filter in intent_for vs branch-by-branch? Any glide/pop risk?
- The single named sacrifice.
- Any P0 you see. Write full analysis to production/war_room/analysis_wave4_crouch/<role>.md.
