# Systems-Designer Analysis — Wave 4 (Track B2/B3): low_posture crouch locomotion

Read from code, not the plan. Files: `sprite_state_map.gd` (full funnel), `enemy_base.gd`
(_update_sprite 356-402, _update_state_for_goal 1118-1140, _execute_suppressed/advancing 1321-1449,
suppression math 1991/2110/2116), `ally_base.gd` (_update_sprite 240-283, _execute_combat 485-564,
_release_cover/_change_state 685-708), `04_AI_LOCOMOTION.md` doctrine.

---

## 1. Is `suppression_level >= 0.35` the right key? — NO, not by itself. It's the P0.

### The suppression ladder as it actually exists in code
- SUPPRESSED **state** flips at `> 0.7` (enemy_base 1121; also the map's `SUPPRESSED -> "cover"`).
- Enemy keeps **firing** until `< 0.8` (1297). Ally **ceasefires** at `>= 0.5` (ally 548).
- `_suppression_move_mult()` (1554-1562) throttles ground speed *continuously from 0*:
  `0.35 -> ~0.58x`, `0.5 -> 0.4x`, `>=0.85 -> 0.05x` (the "crawl" it claims but has no clip for).
- **Suppression accrues FAST and in big steps.** A stagger/near-miss adds **+0.5 in one hit**
  (2116) and forces SUPPRESSED; a bullet adds `dmg/max_hp*0.5`; `apply_suppression()` (2110) stacks
  on top. An advancing man who takes *one* incoming burst is at/over 0.35 within a fraction of a second.

### Why 0.35 alone breaks the aggression
The proposed clause is `low_posture = suppression >= 0.35 OR cautious-approach`. The **OR fires
regardless of AIState**. So the enemy `_execute_advancing` bounding rush — which by definition
sprints *into* fire at `1.3x` (line 1425), the single clearest expression of the aggression Caleb
liked — crosses 0.35 on the first cracked round and flips `low_posture = true`. The plan's stated
guardrail ("ADVANCING with NO suppression -> false") **only covers the zero-suppression case**, and an
advancing man is never at zero suppression for long. **The guardrail as written does not guard the
one push it names.**

That alone would be a design regression. But it compounds with a funnel-law violation (see §3):
`sprint` is in the remap set, so the boosted 1.3x bound gets remapped to `crouch_fwd` — a slow clip
under a fast body. Either it **glides** (violates Law 1, MOVEMENT OWNS THE LEGS) or `set_locomotion_speed`
cranks the crouch clip into an absurd waddle-sprint. The rush is dead either way.

### The fix is kinematic, not a tuned number
Crouch-walk is SLOW *art*. Posture must agree with SPEED or it reads as a lie. The correct gate is not
"which intent" but "is he actually moving slow enough for a crouch to read":

- **Only remap when `speed <= WALK_SPEED_MAX (2.6)`.** Above that, keep the standing clip.
- This is self-enforcing: a genuinely pinned man is *already* throttled below 2.6 by
  `_suppression_move_mult` (0.58*4.2 = ~2.4 at supp 0.35), so he crouches. A man sprinting a bound
  (>4.6) or running-and-gunning (>3.2) stays upright *by physics*, not by a policy flag someone can
  mis-tune. The bounding advance is preserved by construction, under fire or not.

With the speed ceiling in place, `>= 0.35` becomes *acceptable* for the slow bands — but I'd still
raise it slightly and add hysteresis (see §5) because a decaying suppression value grazing a single
threshold near a firefight flickers crouch<->stand.

---

## 2. Does the cautious clause capture "low & careful" WITHOUT catching an assault? — Mostly, and it
self-limits in a good way, but it silently orphans a clip.

`cautious = (SEEKING_COVER / ADVANCING / FLANKING) AND alert_tier <= SUSPICIOUS`.

- **ADVANCING at alert <= SUSPICIOUS is nearly a null set.** ADVANCE is the `ENGAGE`-family goal; you
  do not run a bounding advance toward a contact you're merely SUSPICIOUS of. `_update_state_for_goal`
  (1131) reaches ADVANCING only via `AIGoal.ADVANCE`, which implies an engagement -> alert COMBAT.
  So the cautious clause's ADVANCING sub-case **effectively never fires** — which is *correct*: it
  means "creeping toward a known contact" crouch comes only from SEEKING_COVER/FLANKING-while-suspicious,
  the true stalking read. The aggressive advance's only route to crouch is the suppression clause,
  which §1's speed ceiling now handles honestly. Good.

- **The orphan (Fossil-Law finding).** The existing lateral sneak (`sneaking -> sneak_l/r ->
  cover_sneak_left/right`) triggers on `SEEKING_COVER AND alert <= SUSPICIOUS` (enemy 373-374). The
  new cautious clause is `(SEEKING_COVER/...) AND alert <= SUSPICIOUS` — **the same condition**. If
  the post-filter remaps `sneak_l/r -> crouch_l/r`, then every time `sneak_l/r` is produced,
  `low_posture` is *also* true, so `cover_sneak_left/right` becomes **unreachable**. This change would
  *create a fresh fossil* — exactly what ADR-023's probe exists to catch. **Do not put `sneak_l/r` in
  the remap set.** `cover_sneak` is *already* a crouched lateral-sneak read; leaving it standing keeps
  it alive and avoids wiring two clips to one situation.

---

## 3. Where the aggression lives, and whether the design leaves it intact

| Aggression | Code | Intact under this design? |
|---|---|---|
| Enemy bounding advance (sprint the rush 1.3x, pause-burst-bound) | `_execute_advancing` 1395-1449, sprint at 1425 | **Only with the §1 speed ceiling.** As written (sprint in remap + supp>=0.35 OR) it is GUTTED. |
| Enemy move-and-gun | `_execute_combat` COMBAT branch -> run/aim_walk/strafe | run (>3.2) stays standing via ceiling; aim_walk/strafe crouch only when throttled slow. Reads fine. |
| Ally go-getter push (nerve>=0.7 closes to 0.9x range, strafes + fires) | `_execute_combat` 498-556 | Intact. Allies move at `move_speed*0.6` (~2.5, walk band) and fire only `supp<0.5`; a crouched return-fire at supp 0.4 reads as tactical, not passive. Cover poses use `_anim_override` early-return (264-267) so covered allies are untouched by low_posture. |

**Verdict: aggression survives IF AND ONLY IF the post-filter is kinematic (speed<=2.6 ceiling) and
`sprint`+`sneak_l/r` are excluded from the remap set.** With the plan's literal wording it does not.

---

## 4. Post-filter swap vs branch-per-state — post-filter is correct, but it must be KINEMATIC.

Post-filter in `intent_for` is the right doctrine and coherent with canon: 04_AI_LOCOMOTION and
ADR-023 say new locomotion is a change to *the funnel*, never scattered `play()` calls. One function,
one contract, the three laws stay in one place. Branching per-state would duplicate the standing->crouch
decision into COMBAT / SEEKING_COVER / FLANKING / ADVANCING / RETREATING and re-derive the kinematic
bands 5x — that's how the bands drift out of sync and the funnel rots.

But the post-filter must obey **Law 1 (MOVEMENT OWNS THE LEGS)** as hard as the standing path does. The
clean form:

```
# after the standing intent resolves, before return:
if low_posture and speed <= WALK_SPEED_MAX and intent in \
        {"walk","aim_walk","strafe_l","strafe_r","run","retreat","patrol","arrive"}:
    if intent == "retreat":          intent = "crouch_back"
    elif absf(lateral) > 0.6:        intent = "crouch_l" if lateral > 0.0 else "crouch_r"
    elif speed <= 0.5:               intent = "crouch_idle"
    else:                            intent = "crouch_fwd"
```

Note: `sprint` and `sneak_l/r` are **deliberately absent** from the set (§1, §2). The `speed <= 2.6`
gate makes `run` a no-op in practice (run only fires >3.2) — belt and suspenders, and it means a fast
man is *never* crouched.

**Glide/pop risk:** low with the ceiling (speeds already agree). Two residual risks:
- **Threshold flicker** as suppression decays past 0.35 while fresh hits bump it back — handled by
  hysteresis (§5); the existing 180ms candidate-stability filter (enemy 377-388, ally 269-280) also
  absorbs sub-frame blips but is display-only, so don't rely on it alone.
- **Stand<->crouch transition pop** at the band edges — the crouch clips are loops, not one-shots, so
  the swap is a clip cut, not a glide. Acceptable for now; a blend is art-wishlist, not P0.

---

## 5. Thresholds I'd actually set

- **low_posture suppression key: enter 0.40, exit 0.25 (hysteresis).** 0.40 sits clearly below the
  0.5 behavioral shelf (ally ceasefire / `_suppression_move_mult` knee) and 0.7 SUPPRESSED, so crouch
  reads as "taking meaningful fire" not "a round went by." The 0.25 exit stops flicker as suppression
  decays through a firefight. (If a single constant is preferred, 0.35 + a ~450ms `low_posture` latch —
  mirroring the enemy `_arrive_until_ms` pattern at 391-398 — is the fallback.)
- **Post-filter speed ceiling: `WALK_SPEED_MAX` = 2.6 m/s.** Above it, no remap. THIS is the real
  guardrail — kinematic, un-mis-tunable.
- **Lateral crouch split: `absf(lateral) > 0.6`** (slightly under strafe's 0.7 so a hard strafe still
  reaches crouch_l/r).
- **crouch_idle at `speed <= 0.5`** (mirrors the COMBAT still-band).
- **Excluded from remap, as law: `sprint`, `sneak_l`, `sneak_r`.** Sprint = earned boosted movement
  (rush/rout); sneak = already a low pose whose clip (`cover_sneak_*`) must not be orphaned.

## 6. B3 cover exit — sound; prefer the time-bounded transient.

`cover_to_stand` via a self-clearing `_cover_exit_until_ms` honored in `_update_sprite` is the right
shape and matches the enemy's existing `_arrive_until_ms` transient (391-398). Prefer it over another
sticky `_anim_override` string precisely because the "frozen crouch statue" leak IS an override that
never cleared; a time-bounded stamp is leak-proof by construction. `_change_state` (704-705) and
`_release_cover` (692) already null `_anim_override`, so the transient composes cleanly. Play the
one-shot on `_release_cover()` only when `alive AND had_cover`, and let normal flow resume at the window.

## The single named sacrifice

**Responsiveness of posture change.** The 0.40/0.25 hysteresis + speed ceiling means a man does NOT
snap to crouch the instant a round cracks — he crouches once fire is *sustained enough* to throttle him
and cross 0.40. A player who expects an enemy to flinch-drop on the first near-miss will see a beat of
stand-and-take-it first. That beat is the price of protecting the aggression, and it is the correct
trade: a twitchy crouch that fires on every stray round would erase the stand-and-push exactly as the
guardrail fears.

## P0

**Post-filter as specified (sprint in the remap set + `low_posture = suppression>=0.35 OR ...` with no
speed gate) guts the enemy bounding advance and violates MOVEMENT-OWNS-THE-LEGS.** Suppression crosses
0.35 within one incoming burst (stagger = +0.5 instant, 2116), and an advancing man is always in
incoming fire, so his 1.3x sprint bound (1425) gets remapped to a slow crouch clip -> glide or
waddle-sprint. The plan's guardrail only covers the zero-suppression case and therefore misses it.
**Fix: kinematic speed ceiling (remap only when `speed <= 2.6`) + drop `sprint` and `sneak_l/r` from
the remap set.** The `sneak_l/r` exclusion also prevents this change from orphaning `cover_sneak_*`
(a fresh ADR-023 fossil).
