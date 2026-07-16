# 04 — AI Locomotion Doctrine (posture → intent → clip)

**Status:** DOCTRINE (2026-07-16). The de-facto ruleset lived only in code
(`scripts/visuals/sprite_state_map.gd`); this file makes it canon of record. Where this text and the code
disagree, file a bead — do not silently amend either.

## The one funnel

Everything a unit is doing collapses to a single **intent** string, and the intent maps to one **clip**.
Two static functions in `SpriteStateMap` are the whole contract:

1. `intent_for(state, is_crippled, is_surrendered, is_firing, speed, lateral, sneaking, low_posture) -> intent`
   — AI state + flags + kinematics → one intent word.
2. `clip_for(is_model, faction, unit, weapon, intent) -> clip`
   — intent → an actual clip the rig is guaranteed to have.

Nothing else picks animations. New locomotion behaviour is a change to this funnel, never a bespoke
`play()` call scattered in an AI script.

## The four laws the funnel encodes

1. **MOVEMENT OWNS THE LEGS.** A moving man must never play a stationary pose — he would glide. In COMBAT
   the muzzle flash and tracers sell the shooting; the planted `fire` clip is reserved for `speed <= 0.5`.
   Still = `aim`; slow + lateral = `strafe`; slow forward = `aim_walk`; fast = `run`.
2. **POSTURE IS EARNED BY SITUATION, NOT CHOSEN FREELY.** `sprint` is boosted movement only
   (`speed > SPRINT_SPEED_MIN 4.6`, i.e. the rush or the rout — base enemy move is 4.0–4.4). `sneak`
   requires the `sneaking` flag AND a cautious, unshot approach (SEEKING_COVER / FLANKING / ADVANCING).
   Stand-and-push is the default; caution is the exception. **Wiring caution too eagerly kills the
   aggression the Summoner liked — gate crouch/sneak strictly on genuine caution or suppression.**

3. **LOW POSTURE IS THE SLOW, CAUTIOUS/PINNED GAIT — AND THE DEFAULT IS UPRIGHT (Track B2).** The
   `low_posture` flag swaps standing locomotion → the `walk_crouching_*` family (`crouch_fwd/l/r/back`,
   `crouch_idle`, `crouch_aim`) via `_to_crouch`. It is guarded THREE ways so a fast push can never be
   dragged low:
   - **Kinematic backstop (funnel):** the swap only happens at `speed <= LOW_POSTURE_SPEED_MAX 2.6`. A
     rush or rout (`sprint`, >2.6) stays upright by physics regardless of the flag.
   - **Caller gate (where the signals live):** `_is_low_posture()` keys STRICTLY on caution/pin and
     returns false while firing. Enemy: `SUPPRESSED` OR (`SEEKING_COVER/ADVANCING/FLANKING` AND
     `alert_tier <= SUSPICIOUS`). Ally (no alert tiers / no SUPPRESSED): `suppression_level >= 0.6` OR
     (`SEEKING_COVER` AND no LOS). Suppression is deliberately NOT a locomotion key at the 0.35–0.70
     band — it spikes on a single hit mid-assault and would gut the aggression; the >0.7 SUPPRESSED
     state already owns heavy fire.
   - **Move-side coupling:** while low_posture, planar speed is capped at `CROUCH_SPEED_CAP 1.9` (in both
     bases, between `_execute` and `move_and_slide`) so the crouch clip reads as a crouch, not a skate.
     "Move low" therefore actually means "move slow" — which is correct, because only cautious approaches
     are ever low_posture.

   **Cover exit (B3):** `_release_cover()` opens a self-clearing `_cover_exit_until_ms` window that plays
   `cover_to_stand` — living men only (corpses/downed are guarded), debounced 1.5s against cover-thrash.
4. **NEVER RETURN A CLIP THE RIG LACKS.** Sprites carry only what was rendered, so every sprite intent is
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
| *any* + low_posture | slow (≤2.6) forward / lateral / still | crouch_fwd / crouch_l·r / crouch_idle |
| *any* + low_posture | slow backward (retreat) / aiming still | crouch_back / crouch_aim |
| *any* + low_posture | FAST (>2.6, rush/rout) | *unchanged — stays upright* |

## Known gaps (art wishlist, honestly flagged)

- **No aimed-walk clip** — `aim_walk` reuses `walk_forward` (model) / falls through the chain (sprite).
- ~~**No forward-sneak loop**~~ — RESOLVED by B2: a cautious slow forward approach now plays
  `walk_crouching_forward` via `low_posture` (was: fell back to a standing walk).
- **No surrender / flinch clip** — both fall back to `kneeling_pointing` / `rifle_aiming_idle`.
- **True prone/crawl is DEFERRED (new art).** The suppression code already claims it "pins men to a crawl"
  (`enemy_base.gd:1564`) against a clip that does not exist — honor that later, do not fake it now.
- ~~**`walk_crouching_*` low-posture set ships but is wired to NOTHING**~~ — **DISCHARGED (Track B2,
  2026-07-16).** The `low_posture` flag now wires `walk_crouching_forward/backward/left/right` +
  `idle_crouching`/`idle_crouching_aiming` through `_to_crouch` (Law 3). The 8 diagonals stay available in
  the merged library but get no dedicated intent — the standing side has no diagonal intents either, so
  this is parity, not an orphan. `cover_sneak_*` stays wired via the untouched `sneak_l/r` lateral path
  (no fossil created). Verified by `tests/test_low_posture.tscn` (clips play on a real rig).

## Related
- **Pillars:** 1 (gunplay reads honestly — a moving man is moving) · 2 (atmosphere — tactical, not goofy).
- **Beads / plan:** Track B1 (kill the unison ally-roll — `falling_to_roll` always wins position #1 in
  `ally_base.gd`), B2 (wire the crouch-walk set), `00qp` (shared 91-clip `anim_library.glb`).
- **File of record:** `scripts/visuals/sprite_state_map.gd`.
