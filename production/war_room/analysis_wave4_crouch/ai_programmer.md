# Wave 4 (B2/B3) — AI/Gameplay-Programmer analysis: `low_posture` funnel + `cover_to_stand` exit

Read: `sprite_state_map.gd` (full), `model_actor.gd` 165-219/400-695, `enemy_base.gd`
355-410/1594-1611 + field decls, `ally_base.gd` 240-320/560-724, `test_ally_cover_roll.gd`.

---

## Q1 — Is an 8th param `low_posture: bool = false` on `intent_for` safe for both callers + the sprite billboard + any third caller?

**Safe. No third caller.** `grep intent_for` over the whole repo returns exactly two live call
sites — `enemy_base.gd:376` and `ally_base.gd:268` — plus docs/prior-analysis prose. `civilian.gd`
does NOT call `intent_for` (it drives clips directly via `play_first`), so it is untouched. The
prior `analysis_ai/ai_programmer.md:282` already established the same two-caller/no-third-caller
map when `lateral`/`sneaking` were added; this is the identical pattern.

**Sprite billboard path is safe by construction.** The "billboard path" is
`clip_for(is_model=false) -> resolve() -> CHAINS`, driven by the same intent STRING. A defaulted
`false` means the sprite caller (if any survived ADR-001) never produces a crouch intent, and even
if it did, `resolve()` walks the chain and lands on `rifle_aiming_idle` — it can never return a clip
the renderer lacks. **Provided** the 5 new intents each get a CHAIN entry ending at
`rifle_aiming_idle` (see Q5). Positionally the new param goes LAST, after `sneaking`, so no existing
call breaks.

---

## Q2 — Post-filter swap vs. the 180ms STABILITY FILTER + ARRIVE BEAT. Thrash / glide / T-pose?

**Post-filter placement is correct.** Remapping the resolved intent *inside* `intent_for` (just
before return) means the caller's stability filter sees `crouch_fwd` as an ordinary candidate
intent and debounces it exactly like any other. This is strictly better than a branch-by-branch
rewrite: it reuses the whole quantisation the standing side already trusts (still / |lateral|>0.6 /
forward / retreat) and touches one function, not five branches.

**Thrash — the real risk, and it is NOT clip thrash, it is STALE-LATCH freeze.** The 180ms filter
resets `_cand_since` every time the candidate flips. If `low_posture` chatters faster than 180ms at
its threshold (suppression oscillating around 0.35, re-evaluated every 0.15s think tick), `run` and
`crouch_fwd` alternate, neither ever accrues 180ms, and `_last_intent` sticks on whatever last
committed — the man is frozen on a stale clip, not thrashing. **Fix belongs on the CALLER side, not
the funnel:** give `low_posture` hysteresis — enter at `>= 0.35`, exit at `< 0.20`, or a
short min-hold latch. Cheap, and it keeps the guardrail honest.

**GLIDE — this is the P0 (see below).** `set_locomotion_speed()` scales playback by
`mps / _CLIP_SPEED[clip]`, clamped `[0.6, 1.4]`. `_CLIP_SPEED` (model_actor.gd:666-674) has **NO
crouch entries** → `ref = 0.0` → `speed_scale = 1.0`. So a `walk_crouching_forward` clip authored
at ~1.2 m/s, played on a man still moving at run speed (the funnel is DISPLAY-ONLY and does not
touch `move_speed`), skates. Even if we add the clip to `_CLIP_SPEED`, the 1.4 clamp caps it at
1.2*1.4 = 1.68 m/s of foot speed against a 4.2 m/s glide. **Wiring the clip without coupling
`move_speed` produces a man ice-skating in a crouch.** The pillar text "crouch-walk is SLOW" is a
KINEMATICS claim, not a presentation one.

**T-pose — no.** `_merge_shared_library()` (model_actor.gd:188-218) MERGES all 100 library clips
into every PSXRig-contract rig, so `walk_crouching_*` exists on every modern rig. If a rig somehow
lacks it AND lacks an alias, `play()` returns `false` and `_current_clip` is unchanged — Godot
holds the previous pose. Never a T-pose. (See Q4 for the alias safety net.)

---

## Q3 — B3 cover-exit transient: is a self-clearing `_cover_exit_until_ms` the right pattern, and where exactly?

**Yes — it mirrors the already-proven `_leap_until_ms` / `_arrive_until_ms` pattern.** Checked at
the TOP of `_update_sprite` (below the DEAD/surrender/downed early-return, above the stability
filter and above the ally `_anim_override` block), it plays `cover_to_stand` and `return`s. Because
`play()` no-ops when `clip == _current_clip and not restart`, calling it every frame plays the
one-shot once and holds its last frame until the window expires — no restart, no stutter. Size the
window from the actual clip: `clip_length("cover_to_stand")`, exactly as the leap does
(ally_base.gd:578).

**Where to SET it — precise hook points:**
- **Ally:** inside `_release_cover()` (`ally_base.gd:685-692`). Capture `var had := has_cover` at the
  top; after the existing body, `if had and current_state != Enums.AIState.DEAD:
  _cover_exit_until_ms = now + len`. This one function is reached by BOTH the `_change_state`
  was-fighting→not edge (line 705) and the direct calls at 855. It is the single choke point.
- **Enemy:** inside `_release_cover()` (`enemy_base.gd:1594-1602`), same guard. But note
  `_release_cover()` is also called on the DEATH paths (`enemy_base.gd:2137, 2187`) — the
  `current_state != DEAD` guard is **mandatory** here or a dying man stands up out of cover before
  the death clip latches. Capture `had_cover` before the function sets `has_cover = false`.

**Important scoping note on the "frozen crouch statue" leak:** that leak is an ALLY-ONLY bug — it is
the `_anim_override` crouch-hold outliving the fight (already patched at `_change_state:698-705`).
The ENEMY has no cover-hold override at all; it drives cover purely through the funnel
(`SUPPRESSED -> "cover"`). So for the enemy, `cover_to_stand` is a nicety (a clean stand-up beat),
NOT a leak fix. Don't let the B3 wording imply the enemy has a statue to fix — it doesn't.

---

## Q4 — Fossil Law: does wiring `walk_crouching_*` fully DISCHARGE it? Do the 4 diagonals need mapping?

**Nuance the briefing should hear.** The fossil probe (`test_fossils`) scans **GDScript symbols**
(consts / funcs / signals), not GLB clip-name strings. `walk_crouching_forward_left` is a string in
a `.glb`, referenced by nothing — it is not, and never was, tracked by the fossil register. So
neither wiring nor not-wiring the diagonals FAILS THE BUILD. This is an ADR-023 *hygiene* question,
not a probe question.

**Do NOT wire the 4 crouch diagonals as new intents.** The STANDING funnel has no diagonal intent
either — `run_forward_left/right`, `run_backward_left/right` live only in `_CLIP_SPEED`; the intent
vocabulary quantises to still / lateral / forward / back and nothing else. Adding `crouch_fwd_l`
etc. would make crouch RICHER than the standing locomotion it shadows — inconsistent and
over-built. The crouch diagonals stay **consciously unfinished, in exact parity with the standing
diagonals** — that is precedent, not a new fossil.

**To discharge honestly and kill the "orphan that reads as load-bearing" risk, do the cheap thing:**
add `MODEL_ALIASES` entries mapping each crouch diagonal to its cardinal
(`walk_crouching_forward_left -> ["walk_crouching_forward", ...]`), same as the existing
`run_left -> [strafe, run_forward]` degrade rows. That (a) documents the deliberate quantisation in
code, (b) gives any future caller a graceful landing, (c) covers v1/v2 rig generations that baked
their own library. Wave-4 scope (cardinals + `idle_crouching` + `cover_to_stand`) is then fully
wired and the diagonals are explicitly-degraded, not silently orphaned.

**Also verify** `cover_sneak_left/right` (the existing lateral sneak) is untouched — the briefing
guardrail says keep it. Confirmed: `sneak_l/r -> cover_sneak_left/right` in `MODEL_CLIP:119` and the
sneaking branch (`sprite_state_map.gd:84-88`) are outside the low_posture post-filter's remap set as
long as `sneak_l/sneak_r` are INCLUDED in the "standing-locomotion intent" list that triggers the
crouch remap — decide deliberately: sneak already IS a low posture, so **exclude sneak_l/sneak_r
from the remap** (double-crouching a sneaker is a no-op at best, a clip fight at worst).

---

## Q5 — Do the crouch clips exist on SPRITE renderers, or must chains fall through?

**Models: yes, via the merged shared library** (`_merge_shared_library`, model_actor.gd:188). Every
PSXRig-contract rig receives all 100 `anim_library.glb` clips including the full crouch set, so
`MODEL_CLIP` can map straight to `walk_crouching_forward` / `idle_crouching` and the rig is
guaranteed to have it.

**Sprites: no.** The dead sprite renderer (ADR-001) never got crouch art. `SpriteLibrary.has_clip`
(used by `resolve()`, sprite_state_map.gd:47) will miss every crouch clip, so the CHAIN falls
through. Each new crouch intent MUST get a CHAIN entry, e.g.
`"crouch_fwd": ["walk_crouching_forward", "kneeling_pointing", "rifle_aiming_idle"]`,
`"crouch_idle": ["idle_crouching", "kneeling_pointing", "rifle_aiming_idle"]` — always terminating
at `rifle_aiming_idle`. Then models get the real crouch clip and any surviving sprite degrades to a
kneel/idle. Add all 5 to both `MODEL_CLIP` and `CHAINS`.

---

## P0 / RISKS SUMMARY
- **P0 — glide.** The funnel is display-only; swapping in a crouch clip WITHOUT (a) adding
  `walk_crouching_*` + `idle_crouching` to `_CLIP_SPEED` and (b) actually throttling the unit's
  `move_speed` while `low_posture` produces a man skating in a crouch. This is a systems/gameplay
  coupling, not a pure wiring task. B2 is not done until move-speed is coupled.
- **P1 — stale-latch freeze** at the `low_posture` threshold. Needs caller-side hysteresis
  (enter 0.35 / exit 0.20 or a min-hold), or the 180ms stability filter freezes on a stale clip.
- **P1 — enemy death path.** `enemy_base.gd:2137/2187` route through `_release_cover()`; the
  `_cover_exit_until_ms` set MUST be guarded `current_state != DEAD` or a corpse stands up.
- **P2 — hygiene.** Alias the 4 crouch diagonals to their cardinals; exclude `sneak_l/r` from the
  remap set. No new fossil either way (clips aren't probe-tracked).
