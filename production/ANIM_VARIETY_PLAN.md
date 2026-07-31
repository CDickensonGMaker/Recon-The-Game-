# ANIMATION VARIETY — the posture-state matrix (Summoner's brief, 2026-07-30)

**PARKED, NOT STARTED.** Captured at the end of the 2026-07-30 Mixamo session so it
survives. Nothing below is built. The gate is his: *"i need to verify all the animations
we're making so i shouldn't go super crazy."* **Verification of the 39 clips already added
comes first** — see `ANIM_WISHLIST.md` for what landed and what is wired.

---

## HIS BRIEF, VERBATIM

> "we should have calm, concerned, alert, and combat states for people walking as well as
> cover seeking, stealthy, covering fire, cowering from fire while under cover etc"

> "for hq allies, living civilians and resting enemies ... as well as more patroling and
> walking animations ... to make everything more varied"

## WHAT HE IS ASKING FOR

Not more clips — **the same clip in more emotional registers.** A man walking calm, the
same man walking concerned, alert, and in contact. Today locomotion has ONE register: the
state map picks `walk_forward` whether he is strolling a firebase or closing on a treeline.
That single fact is why the world reads samey no matter how many clips get added.

### The matrix

| Register | Walking | Standing | In cover |
|---|---|---|---|
| **Calm** | stroll, weapon slung | loafing (`smoking`, `idle_unarmed_*`) | n/a |
| **Concerned** | slower, head turning (`sentry_scan` over the walk) | `nervous_scan` | peeking |
| **Alert** | weapon up, deliberate | `idle_aiming` | `cover_peek` |
| **Combat** | fast, weapon up | `firing_rifle` | `cover_kneel_brace` |

Plus the situational reads he named: **cover-seeking** (the move TO cover, which today is
just a run), **stealthy** (`crouched_sneaking_*` exists, unwired to any register),
**covering fire**, and **cowering under fire while in cover** — the last is the one with no
art and no code at all.

## HOW IT GETS BUILT — mechanically, from what we own

`tools/make_ambient_variants.py` (**WRITTEN BUT NEVER RUN** — see its header) implements
three transforms that need no new performance and no human pose:

1. **SPLICE** — upper body of A onto lower body of B, split at the waist (`Spine2` and up
   from the donor; `Hips`/`Spine`/`Spine1`/legs stay with the locomotion clip, so root
   motion and footfalls are never touched). `sentry_scan` over `walk_forward` IS
   "walking concerned". Donors of different length are resampled onto the target's phase.
2. **PHASE** — the same cycle started at 1/3 and 2/3. Five men on one walk clip march in
   lockstep and read as one animation; the same five phase-offset read as five men. **This
   is the cheapest variety win in the whole plan** and it costs no new motion at all.
3. **RETIME** — baked slow/fast variants (a trudge and a brisk walk are the same walk).
   Playback rate alone cannot do it, because the engine drives rate from ground speed
   (`_CLIP_SPEED`, `model_actor.gd`).

**The loop-seam rule** the script enforces: phase and retime are only clean on a clip whose
first pose equals its last. It MEASURES the seam per clip and refuses anything over 12°,
printing what it skipped — a phase shift on a seamed clip moves the pop into the middle of
the cycle, where it is worse than at the ends. (This is wishlist item B3, arriving as a
gate rather than as a chore.)

## THE ENGINE HALF — the part no generator can do

Clips are the easy half. The registers have to be SELECTABLE, and today they are not:
`sprite_state_map.gd` maps an intent to one clip with no notion of emotional register.
The work is a register input on the state map (derivable from existing state — `alert_tier`,
`suppression_level`, `has_line_of_sight` are all already tracked) and a clip table with a
register axis. **That is a War Room item, not a quiet edit** — it touches every man in the
game.

## ORDER, WHEN IT REOPENS

1. Verify the 39 clips already added (his gate).
2. PHASE variants — biggest read for zero risk, no new motion.
3. Register axis on the state map — the War Room item; unlocks everything else.
4. SPLICE variants per register, once there is something to select them.
5. `cower_under_fire` — the one genuine gap with neither art nor code.
