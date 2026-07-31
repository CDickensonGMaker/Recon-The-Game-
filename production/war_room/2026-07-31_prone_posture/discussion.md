# THE DEBATE — prone posture (2026-07-31)

Owner ruling: **build prone, full War Room first.** Four architects summoned in parallel, no
cross-talk. Verdicts as they land.

---

## GODOT SPECIALIST / ANIMATION — verdict

**The state map can carry prone WITHOUT a rewrite.** `clip_for()` (`sprite_state_map.gd:204`) is
a flat intent lookup, and crouch is already a *post-hoc remap* — `_to_crouch()`
(`sprite_state_map.gd:99-122`) driven by the enum that already exists,
`CombatPosture.Posture {STAND, CROUCH}` (`combat_posture.gd:9`). **Prone is a third enum value,
not a cross product.** The handoff's "register axis" warning is about calm/concerned/alert/combat,
which multiplies every intent by four. Prone adds `_to_prone()` and ~2 dictionary rows.

**Measured off the glTF directly** (not guessed): transitions **1.833 s / 55 keys** each ·
`prone_idle` **4.967 s** · `prone_firing_rifle` **0.867 s**. **All in-place** — zero horizontal
hip travel, a pure 0.311 m vertical drop.

- Prone-side seams are **exact** (0.82° / 1.54°).
- **The CROUCH seams are 23° off, all in the arms** (LeftHand 97.6°) — visible arm swing under
  the 0.18 s crossfade.
- **Loop modes need ZERO changes.** All five clips are already correct.

**`wounded_crawl` is NOT prone movement** — hips at 0.385 m vs prone 0.149 m, 36° apart. It is a
hands-and-knees casualty crawl. **No prone locomotion clip exists.**

**`ModelActor` has no finished signal** — use the timed-window pattern (`enemy_base.gd:1853-1856`).

**The rule that must not be broken:** a prone pose is reachable ONLY through a completed
transition, and the latch and its window are written in one statement, always.

---

## LEAD PROGRAMMER / TECHNICAL DIRECTOR — verdict

**Blast radius is not where it looks.** `decide()` has exactly **two** callers —
`enemy_base.gd:409` and `ally_base.gd:378` — and both are `_is_low_posture() -> bool` doing
`== Posture.CROUCH`. A third value returns **false**, so a prone man is classified *standing*.
Neither errors.

**The real radius is the eleven `_low_posture` consumers downstream:** clip selection,
`CROUCH_SPEED_CAP`, footstep volume, the stumble guard (`enemy_base.gd:2263`), the crouch-death
pick (`enemy_base.gd:2596`, `ally_base.gd:1451`). **All eleven silently do the standing thing.**
Fix the RETURN TYPE — do not merely widen the enum.

**Hardest technical problem: there is no prone locomotion clip.** `_CLIP_SPEED`
(`model_actor.gd:943-954`) has no prone entry, so `set_locomotion_speed` resets to 1.0 and a
moving prone man ice-skates. **Prone must be stationary — an art constraint, not a design choice.**
Compounding it: the AI collision capsule is 1.8 m, built once at `enemy_base.gd:2695-2699` and
**never mutated** — crouch does not resize it today either.

**The silent breaker:** hitzones are bone-driven and need no code change
(`hitzone_builder.gd:217-232`) — so nobody will inspect them. But `test_fossils.gd:240-245` scans
const/signal/func only, **not enum members**, so an unused `PRONE` is invisible to the fossil probe.

**And a live defect that will be blamed on this change: THE PLAYER ALREADY GOES PRONE**
(`player.gd:1179`). `_build_static` uses hardcoded bands (`hitzone_builder.gd:582`), so his fatal
HEAD zone floats at 1.65 m over a 0.35 m body.

---

## CONVERGENCE SO FAR (independent, different doors)

Both architects arrived at **prone is STATIONARY-ONLY** from opposite directions — the animator by
measuring hip travel and finding no prone locomotion clip, the programmer by finding `_CLIP_SPEED`
has no prone entry and a moving prone man would ice-skate. That is the strongest signal this
process produces, and it settles the biggest open design question before the systems designer has
even reported.

*Awaiting: systems designer, devil's advocate.*
