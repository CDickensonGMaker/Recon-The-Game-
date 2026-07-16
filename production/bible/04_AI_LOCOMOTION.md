# 04 — AI Locomotion Doctrine (posture → intent → clip)

**Status:** DOCTRINE (2026-07-16). The de-facto ruleset lived only in code
(`scripts/visuals/sprite_state_map.gd`); this file makes it canon of record. Where this text and the code
disagree, file a bead — do not silently amend either.

## The one funnel

Everything a unit is doing collapses to a single **intent** string, and the intent maps to one **clip**.
Two static functions in `SpriteStateMap` are the whole contract:

1. `intent_for(state, is_crippled, is_surrendered, is_firing, speed, lateral, sneaking) -> intent`
   — AI state + flags + kinematics → one intent word.
2. `clip_for(is_model, faction, unit, weapon, intent) -> clip`
   — intent → an actual clip the rig is guaranteed to have.

Nothing else picks animations. New locomotion behaviour is a change to this funnel, never a bespoke
`play()` call scattered in an AI script.

## The three laws the funnel encodes

1. **MOVEMENT OWNS THE LEGS.** A moving man must never play a stationary pose — he would glide. In COMBAT
   the muzzle flash and tracers sell the shooting; the planted `fire` clip is reserved for `speed <= 0.5`.
   Still = `aim`; slow + lateral = `strafe`; slow forward = `aim_walk`; fast = `run`.
2. **POSTURE IS EARNED BY SITUATION, NOT CHOSEN FREELY.** `sprint` is boosted movement only
   (`speed > SPRINT_SPEED_MIN 4.6`, i.e. the rush or the rout — base enemy move is 4.0–4.4). `sneak`
   requires the `sneaking` flag AND a cautious, unshot approach (SEEKING_COVER / FLANKING / ADVANCING).
   Stand-and-push is the default; caution is the exception. **Wiring caution too eagerly kills the
   aggression the Summoner liked — gate crouch/sneak strictly on genuine caution or suppression.**
3. **NEVER RETURN A CLIP THE RIG LACKS.** Sprites carry only what was rendered, so every sprite intent is
   a FALLBACK CHAIN ending at `rifle_aiming_idle` (which every unit has). Models carry all authored clips
   and map intent straight through `MODEL_CLIP`, with `MODEL_ALIASES` bridging clip generations (v1 `strafe`
   ↔ v2 `run_left`) and `WEAPON_FAMILY` appending the per-weapon hold suffix (`__smg`, `__bolt`, `__mg`,
   `__launcher`, `__pistol`).

## State → intent table (the current rule)

| AIState / flag | condition | intent |
|---|---|---|
| is_surrendered | — | surrender |
| is_crippled | — | crippled |
| COMBAT | still | fire / aim |
| COMBAT | slow + lateral | strafe_l / strafe_r |
| COMBAT | slow forward | aim_walk |
| COMBAT | fast | run |
| SUPPRESSED | — | cover |
| SEEKING_COVER / FLANKING / ADVANCING | boosted | sprint |
| — | sneaking + cautious | sneak / walk |
| — | otherwise | run |
| RETREATING | routed / withdrawing | sprint / retreat |
| ALERT | walk to last-known | walk / run |
| IDLE | moving / still | patrol / idle |

## Known gaps (art wishlist, honestly flagged)

- **No aimed-walk clip** — `aim_walk` reuses `walk_forward` (model) / falls through the chain (sprite).
- **No forward-sneak loop** — a cautious slow *forward* approach walks; only lateral sneak has clips.
- **No surrender / flinch clip** — both fall back to `kneeling_pointing` / `rifle_aiming_idle`.
- **True prone/crawl is DEFERRED (new art).** The suppression code already claims it "pins men to a crawl"
  (`enemy_base.gd:1564`) against a clip that does not exist — honor that later, do not fake it now.
- **`walk_crouching_*` low-posture set ships in `anim_library.glb` but is wired to NOTHING** (ADR-023
  built-ahead-of-wiring). Track B2 discharges it by adding a `low-posture` flag that swaps standing
  locomotion → crouch-walk under fire/caution/suppression. Until then it is a flagged stub, not a fossil to
  cut.

## Related
- **Pillars:** 1 (gunplay reads honestly — a moving man is moving) · 2 (atmosphere — tactical, not goofy).
- **Beads / plan:** Track B1 (kill the unison ally-roll — `falling_to_roll` always wins position #1 in
  `ally_base.gd`), B2 (wire the crouch-walk set), `00qp` (shared 91-clip `anim_library.glb`).
- **File of record:** `scripts/visuals/sprite_state_map.gd`.
