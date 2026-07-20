# Game Designer — Squad Feel (Pillar 4: the squad is the RPG)

Pointers: `scripts/allies/ally_base.gd:9` (move_speed=4.5), `:96-97` (follow_distance=5.0,
max_follow_distance=15.0 — declared, zero reads, FOSSIL), `:113-118` (file_slot/point_slot/
_follow_offset), `:195-210` `_execute_idle` (formation math, the 2.0 m/s single-boundary flip),
`:581-621` (`_execute_idle`/`_settle` — settle is pure velocity decay to 0, no idle behavior),
`:863-868` `_move_toward`. `scripts/player/player.gd:5-7` (WALK 5.0, SPRINT 8.0, CROUCH 2.5).

## The mechanism behind "fidgety"

`_execute_idle` picks a slot from ONE boundary: `pv.length() > 2.0` → staggered file (point man
+12m, others `-dir*(3.5*file_slot) ± 1.1` lateral); else → personal ring slot
(`_follow_offset`, radius 2.5–4.5m, set once in `_ready`). Crouch speed is exactly 2.5 — already
above the 2.0 line, so crouch-patrol lives in file mode, correct. The break is brush drag /
pathing noise ticking player velocity across 2.0 repeatedly with no hysteresis: each crossing
swaps a man's target between a ring point ~3m from the player and a file point up to ~30m away
(file_slot 8 → `3.5*8=28m` behind, offset by ±1.1 lateral). `dist > follow_distance` (a flat
5.0m for BOTH shapes) then fires every think tick (0.15s), so the man runs at full `move_speed`
toward a target that itself keeps teleporting. That reads as fidgeting, not walking — it IS a
targeting bug wearing a movement bug's clothes.

`max_follow_distance` at `:97` is never read anywhere — pure fossil, flag for the fossil probe.

## 1. Base move_speed + catch-up band

**Base ally move_speed: 5.8** (16% over player WALK 5.0 — enough that a man visibly closes ground
when he's lagged behind on patrol, not close enough that walking-pace squadmates look like they're
speed-walking past the player).

**Catch-up band:** trigger at `dist_to_slot > 8.0m` (past the ordinary deadzone — see below).
Inside the band, multiply move_speed by **1.35×, capped at 7.8** (just under player SPRINT 8.0 —
allies must never visibly outrun the player's own sprint; that reads as them being faster than the
squad leader, which breaks the "unit" read). Cap is a hard clamp, not a lerp target, so a badly
lagged man accelerates to 7.8 and holds — no burst-then-slide.

**What caps catch-up:** the 7.8 clamp, AND contact — `_body_gate_open`/state already forces
COMBAT/SEEKING_COVER to own movement the instant there's a target, so catch-up only ever governs
uncontested repositioning, never a firefight sprint.

## 2. Hysteresis on the shape flip

Enter-file: **3.2 m/s**. Exit-file: **1.5 m/s**. Deadband = 1.7 m/s, straddling nothing crouch
(2.5) or walk (5.0) can bounce across on its own — crouch-patrol (2.5) sits mid-band and can never
re-trigger file mode by noise; only a real acceleration through 3.2 does. Walk (5.0) sits solidly
above enter; a full stop settles below 1.5 inside one or two physics frames of deceleration, not
mid-band limbo.

**Ease, don't snap.** Add a `_formation_blend: float` (0=ring, 1=file) that ramps at `1.0 / 1.5`
per second (1.5s full transition) and lerps the SLOT POSITION itself between the ring point and
the file point every frame. This is the actual fix for the 28m teleport — hysteresis alone stops
the flip-flop, but a single flip that DOES occur still needs to not be a snap-30m-away. A blended
slot means the target itself walks smoothly from ring to file over 1.5s while the man chases a
moving point, not a teleported one.

## 3. The deadzone — this is the whole ruling

Split the single 5.0m `follow_distance` into two numbers plus a state:

- **Ring deadzone (halted): 2.5m.** Matches the ring's own native spread (2.5–4.5m radius) — a
  man anywhere within 2.5m of his personal point is "in formation," full stop.
- **File deadzone (moving): 3.0m.** Slightly tighter — a moving line reads sloppy faster than a
  static cluster, so the tolerance shrinks a little to keep the silhouette of "a file" legible
  at a glance.

**Inside the deadzone, replace `_settle()` (velocity→0, a statue) with a micro-patrol behavior:**
roll a random point within 1.2m of the slot, walk to it over 2–4s at a SLOW pace (move_speed×0.4),
hold an idle/scan pose (reuse `SpriteStateMap` idle intents already in the state map — no new
clips) for 1.5–3.0s, repeat with a new roll. This is cheap (reuses existing anim intents, existing
`_move_toward`, no new systems) and is the literal difference between "alive man checking his
sector" and "NPC parked on a point." Raycast the micro-target the way `_find_cover_point` already
does (`ally_base.gd:802-826`) so a bored man never scan-walks into a hut wall or a squadmate.

**Deadzone COLLAPSE conditions** (converge hard, because sometimes the unit must actually BE a
unit):
- **Contact:** already structurally forced — `target != null` routes to COMBAT/SEEKING_COVER,
  which owns movement outright and bypasses `_execute_idle` entirely. No new code needed; just
  confirm the ring/file deadzone logic lives ONLY inside the FOLLOW+IDLE branch, never leaks into
  combat states.
- **Player halt, sustained:** if player speed stays under the 1.5 m/s exit threshold for **3.0s
  continuous** (a real stop, not a beat between paces), tighten ring deadzone to **1.2m** — the
  squad visibly closes ranks around a player who has actually stopped (checking a map, a body,
  giving an order). Reset the timer the instant player speed exceeds exit threshold.
- **Player sprint:** explicitly do **NOT** collapse the deadzone on sprint — widen it instead, to
  **4.0m**, and let the catch-up band (item 1) do the closing work at its own pace. Tightening on
  sprint is exactly the "stuck onto the player" feeling the Summoner flagged; the correct read
  during a panic-sprint is a man visibly working to keep up, not a laser-locked leash.

## 4. What each number sacrifices

- **move_speed 5.8 / cap 7.8:** sacrifices "always-there" safety. A player who sprints
  continuously with no contact WILL open a gap the squad cannot instantly close (catch-up caps
  below player SPRINT). That is the intended cost of Pillar 3 (freedom) meeting Pillar 4 (squad
  as unit, not leash) — but it means a panicked solo sprint really can strand the squad, and there
  is no rally/recall command visible in this file to pull them back short of the player physically
  stopping and waiting inside the catch-up trigger. Name this: **the squad has no active
  recall — only passive re-approach.**
- **Hysteresis 1.5–3.2 + 1.5s blend:** sacrifices instant responsiveness. A player who stop-starts
  right at the boundary gets a squad that is visibly "still walking into file" for up to 1.5s after
  he's already stopped, or vice-versa. This reads as human lag, which is the point, but it is real
  latency between player intent and squad shape and will feel "late" to a player expecting a snap.
- **Deadzone 2.5m/3.0m + micro-patrol:** sacrifices formation precision. In tight interiors (huts,
  trench lines, the firebase itself) a 2.5m wander radius is enough to put a man in a doorway or
  overlapping a teammate's ring if raycast-clearing the micro-target isn't actually wired in. This
  is the single highest implementation-risk number in the set — ship it WITHOUT the raycast clear
  and you get men wandering through walls, which is worse than the statue bug it replaces.
- **Halt-collapse 3.0s / 1.2m:** sacrifices any "spread out and hold" beat during a long peaceful
  stop — the squad always re-clusters after 3s idle, so a player can't order a loose loiter without
  an explicit HOLD order overriding FOLLOW. Acceptable; HOLD already exists for that (`:100` OrderMode).
- **Sprint-widen 4.0m:** sacrifices tight escort during a no-contact panic sprint specifically —
  named as intended above, but worth the Summoner's eyes because it is the number most likely to
  read as "the AI is bad at its job" if he's fleeing something on-screen even without an active
  `target`.

## 5. The one value that needs the Summoner's eyes first

**The ring deadzone radius (2.5m) and its micro-patrol behavior.** Every other number here is
math derived from existing constants (WALK/SPRINT/CROUCH, the existing 2.0 m/s boundary, the
existing ring spread). The deadzone radius is not derivable — it is the direct numeric encoding of
his own words, *"shouldn't be stuck too much... doing their own thing... but we work as a unit,"*
and only his eyes on a live squad standing around him can say whether 2.5m reads as "alive" or
reads as "sloppy and scattered." Ship it, watch one halt-and-hold beat with him, adjust ±1m on the
spot — this is a playtest-tunable number, not an armchair one.
