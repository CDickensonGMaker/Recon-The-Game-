# Devil's Advocate — Wave 4 (`low_posture` crouch-walk)

Read the code, not the plan. Numbers below are grepped from source, not the briefing.

---

## 1. THE AGGRESSION KILL — 0.35 is catastrophically too low (SHARPEST HOLE)

The briefing keys `low_posture` on `suppression_level >= 0.35`. This is a direct hit on the exact
aggression Caleb liked. Here is why, from the suppression math:

**Where the SUPPRESSED line actually is:** `enemy_base.gd:1121` — a unit only enters `AIState.SUPPRESSED`
at `suppression_level > 0.7`. The whole design deliberately treats **0.35–0.70 as "still fighting
upright, not yet pinned."** That band is COMBAT / ADVANCING / FLANKING — the stand-and-push. The 0.35
key carves a brand-new **"crouch-walk band" (0.35–0.70) that lives entirely inside active combat,
below the pin line.** Every firefight lives in that band.

**How trivially 0.35 is crossed mid-push:**
- **Getting shot once:** `take_damage` adds `amount/max_hp * 0.5` (line 1991). A torso hit (27 base ×2.5
  zone = 67) on a 75-HP enemy = `67/75*0.5 = 0.45` suppression **from a single bullet.** Even a raw
  27 body hit = 0.18.
- **Pain stagger:** any hit `>= max_hp/3` (~25) calls `apply_stagger(1.0)` → **+0.5 suppression AND forces
  SUPPRESSED** (lines 2000, 2114-2117). Most torso/gut hits clear that bar.
- **Sustained fire near him:** `apply_suppression_in_area` (weapon_holder:437). Full-auto = 0.08/shot in
  a 3 m radius; buckshot 0.35; any projectile weapon **0.45** (`_calc_suppress_amount`, lines 876-882).
  A rocket/CAS airstrike dumps **1.0** (cas_airplane:140).

So: a charging enemy the player merely **returns fire at** parks in the 0.35–0.70 band within ~1 second
and stays there for the whole exchange (decay is only 0.3/s, `SUPPRESSION_DECAY` line 197). He is still
in `ADVANCING`/`COMBAT` state — the guardrail "COMBAT while HOSTILE with NO suppression → stand" **almost
never fires, because a real push always draws return fire = always has suppression.** Result: the
aggressive stand-and-push swaps to slow crouch-walk **precisely when the player shoots back.** That is
the aggression, killed by construction.

**Fix — raise the gate to the pin line and stop double-defining suppression posture.** Two options,
best first:
- **Drop the suppression key from locomotion entirely.** Posture-under-heavy-fire is ALREADY handled:
  `>0.7` → SUPPRESSED → intent `cover` → kneel. `low_posture` should key ONLY on genuine caution:
  `SEEKING_COVER/FLANKING/ADVANCING AND alert_tier <= SUSPICIOUS AND not firing`. Suppression gets you
  the kneel at 0.7; it should not get you a crouch-crawl at 0.35.
- If a suppression-driven crouch is wanted, gate it at **`>= 0.7` AND `not firing` AND `speed <=
  WALK_SPEED_MAX`** — i.e. only a slow, not-shooting, genuinely-pinned man crouch-moves. Never in the
  0.35–0.70 fighting band.

---

## 2. ALLIES HAVE NO `alert_tier` — the SUSPICIOUS gate that protects enemies doesn't exist for them

Grep confirms `ally_base.gd` has **no `alert_tier` field** (courage/has_line_of_sight/last_known only).
The enemy caution clause `alert_tier <= SUSPICIOUS` is the ONLY thing that stops an *engaged* enemy from
crouching — and allies can't use it. The briefing's ally rule is
`suppression >= 0.35 OR (moving to last-known WITHOUT LOS)`. Both halves misfire:

- **Second clause fires constantly.** `_execute_combat` line 557-559: *"Lost sight — move toward target"*
  → moving to `last_known_target_pos` WITHOUT LOS. In jungle, LOS flickers every few metres, so this is
  the normal state of a maneuvering ally, not a rare "careful advance." Allies would crouch-walk most of
  the time they move in contact.
- **Allies never enter SUPPRESSED.** Ally `_execute` dispatches only IDLE/COMBAT/SEEKING_COVER (lines
  429-435); there is no `>0.7 → SUPPRESSED` transition in `_evaluate_goals`. So for allies the 0.35
  suppression key is the *only* suppression posture they get — and with no upper kneel behavior, a
  suppressed ally just **crouch-walks through the entire fight.** Ambient fire (supp 0.35, decays 0.4/s)
  while merely FOLLOWing the player = a squad that crouch-shuffles behind you. Timid, constant, wrong.

**Fix:** allies need an explicit caution predicate that is NOT "no LOS" — e.g. `low_posture` only when
`SEEKING_COVER` (real cover trip) or MOVE_TO order into known-contact, never on transient LOS loss, and
suppression gated at the same raised threshold as §1.

---

## 3. Conflict with SUPPRESSED-as-cover: no double-handle at 0.7, but semantics are now overloaded

At `>0.7` the man is SUPPRESSED → intent `cover` → kneel, velocity lerped to ~0 (`_execute_suppressed`,
1321-1323). `cover` is NOT a standing-locomotion intent, and a pinned man isn't moving, so the post-filter
won't remap it — **no direct double-handle.** The problem is subtler: `low_posture` invents a SECOND
suppression-posture semantic (0.35 = crouch-walk locomotion) that contradicts the design's existing one
(0.70 = kneel-in-place). And **0.35 is already an overloaded magic number** — it's the SEEKING_COVER
hysteresis EXIT (ally line 401 `supp_gate`, enemy 401). Reusing it for a third meaning (crouch-walk on/off)
means one number now flips three behaviors, and any future retune of the cover-hysteresis silently moves
the crouch line. Keep the crouch threshold a distinct, higher constant.

---

## 4. Cover-thrash re-triggers `cover_to_stand` into a stutter

B3 plays a one-shot `cover_to_stand` on `_release_cover()` inside a `_cover_exit_until_ms` window.
`_release_cover` fires on **every goal transition** (enemy 1103; ally 705). Cover-thrash — the documented
past bug where goals oscillate and a man leaves/re-enters cover 5× in 3 s — calls `_release_cover` 5×,
retriggering the `cover_to_stand` transition (~0.5-1 s clip) every ~0.6 s. It never completes: a man
**forever half-rising.** Worse with a `stand_to_cover` on the re-entry → stand↔cover clip flip-flop, the
jittering statue B3 was meant to prevent, reincarnated at the exit. The window guards the *frozen-crouch
leak* but NOT the *re-trigger storm.*

**Fix:** debounce the exit — refuse to replay `cover_to_stand` if one played within ~800 ms, and only arm
the window if he actually stayed out of cover past the transition. The transient must be edge-triggered on
a real exit, not re-armed on every `_release_cover` call.

---

## 5. THE SINGLE NAMED SACRIFICE

**Posture stops signaling nerve.** Today an upright man advancing through fire reads as *disciplined /
deadly*; a crouching man reads as *breaking / cautious*. Universal crouch-under-fire collapses that
distinction — **everyone ducks at 0.35, so you can no longer tell a man pushing under fire from a man
losing his nerve.** Concretely it defangs the wave-2 bet: the deadlier VC that was supposed to *push and
flank aggressively* now crouch-crawls the instant the player returns fire — the VC you can **suppress into
timidity with a few auto rounds.** The coupled bet inverts: allies self-preserving only reads as smart if
the enemy is still a charging threat; make the enemy duck too and both sides just crouch-shuffle. We trade
**"charging through fire is a readable, scary thing"** for **"suppression is a soft-CC any return fire
applies to everyone."**

---

## P0

**P0 (design-regression, matches the wave's own guardrail):** shipping `low_posture` keyed at
`suppression_level >= 0.35` will regress the aggressive stand-and-push Caleb *explicitly* liked, because
the 0.35–0.70 band is where every firefight lives and any return fire parks units there. This violates
the wave's stated guardrail ("crouch must be the EXCEPTION"). Do not merge the suppression key until the
threshold is raised to the SUPPRESSED line (≥0.7) or dropped from locomotion entirely (§1), and the ally
path is given a real caution predicate (§2).
