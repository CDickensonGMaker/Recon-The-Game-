# Systems Architect — Defects 2 & 3 (2026-08-11 sweep)

Read-only diagnosis. Every claim cites file:line. No code was edited, nothing was run.

---

## DEFECT 2 — Dropoff troops pile at the LZ edge

### The flow that actually runs in the demo

- `demo_game.gd:155` — `[14.0, "huey", "lz_cycle"]` → `air_traffic.gd:729-755` `_dispatch_lz_cycle`
  → `HeliLift.attach(heli, _friendly_director())` (`air_traffic.gd:755`).
- Pax are minted and seated at dispatch (`heli_lift.gd:228-254`), delivery fires on touchdown:
  `heli.landed` → `_on_landed` (`heli_lift.gd:257-272`) → `_deliver` (`heli_lift.gd:275-326`).
- Demo mode converts EXTRACT to ROTATE (`heli_lift.gd:149-152`), so the same landing runs
  `_deliver()` **and** `_extract()` back to back (`heli_lift.gd:266-270`).

### Root cause — three converging placement defects, one shared point

**(a) The unload ring is 1.5 m around ONE point.** `_deliver` calls
`seats.unseat_all(door)` with `door = seats.door_staging_pos()` (`heli_lift.gd:279-280`).
`unseat_all` (`seat_system.gd:378-386`) places every occupant on a fixed ring of **radius
1.5 m** around that single point: `exit_center + Vector3(cos(ring),0,sin(ring)) * 1.5`.
Up to 12 bodies inside a 3 m disc, ~0.9 m apart — that IS the pile, at the door staging
point 2.5 m off the left door (`seat_system.gd:473-480`, `EXIT_PUSH_M` `:89`), i.e. "the
edge of the LZ". No ground-cast either — the player path uses `_exit_ground`
(`seat_system.gd:564-575`), `unseat_all` never does.

**(b) The extraction stick converges on the SAME point.** ROTATE also runs `_extract`
(`heli_lift.gd:333-357`), which calls `board_squad` — and `board_squad` sends **every**
boarder to the one `door_staging_pos()` (`seat_system.gd:391-410`, `var staging` at `:392`,
`board_target = staging` at `:406`). A Civilian with `board_target` set walks straight at it
(`civilian.gd:375-377`) and stops when the step vector drops under 1 m
(`civilian.gd:658-671`, `if dir.length() > 1.0`), so up to 6 outbound men stack within ~1 m
of the exact point where the 3-6 inbound men were just ringed. They then queue there for the
staggered `_board_one` arrival gate (`seat_system.gd:416-444`, `BOARD_STAGGER_S`,
`BOARD_NEAR_M`). Civilians have **no avoidance** — `nav.avoidance_enabled = false`
(`civilian.gd:224`) — so nothing pushes overlapping bodies apart, ever.

**(c) `unseat_all` dumps the PILOTS too — contract drift.** `heli_lift.gd:119` asserts
"They are never unseated: _on_landed only empties SeatSystem.PASSENGER_SEATS", but
`unseat_all` iterates `SEAT_NAMES` (`seat_system.gd:380`), which includes
`seat_pilot_l/r` (`seat_system.gd:19-24`), and `_crew_ship` really does seat two pilots
(`heli_lift.gd:120-140`). So every delivery ejects the aircrew onto the ring with the pax.
Worse: `_deliver`'s camp-life handoff loop only touches `_pax` (`heli_lift.gd:282-314`), so
the pilots keep `_placed_for_hour == false` — their first tick runs
`place_for_current_hour()` (`civilian.gd:330-333`), which **hard-teleports**
(`civilian.gd:993-1004`) them to their default `home` = their mint position near the ship's
spawn point at the world edge. Two extra bodies in the pile until they blink away, and the
ship flies home crewless either way.

**What already works (do not rebuild):** the delivered men DO get dispersal targets —
`_deliver` hands each a per-man bunk on a 10-22 m ring around `fsb_center` keyed off his
`_idle_seed` (`heli_lift.gd:294-300`), his occupation (`:293`), and the schedule BT walks
him there via the one settle implementation (`civilian.gd:875-887` resolve,
`_bt_settle` `:1083-1099`, `_resolve_target` `:1007-1014`). The walk-off layer exists; the
pile forms at the *unload/boarding* layer, where the dispersal is a 1.5 m ring plus a single
shared staging point, and persists because the ROTATE extract queue re-fills the same spot
and avoidance is off. Note the settle jitter is only `WORK_JITTER_M = 1.5`
(`civilian.gd:1070-1071`) — anywhere two targets coincide, so do the men.

### Proposed fix

1. **`seat_system.gd` `unseat_all` (:378-386)** — passengers only, fanned, grounded:
   - Iterate `PASSENGER_SEATS`, not `SEAT_NAMES` (honours the `heli_lift.gd:119` contract
     and fixes (c) without touching HeliLift).
   - Per-index fan on the door side instead of the fixed 1.5 m ring: radius
     `2.5 + 0.9 * i`, angle spread across ~140° centred on the door normal
     (`sock.global_transform.basis.z`, same math as `door_staging_pos` `:473-480`),
     and run each exit point through the existing `_exit_ground` (`:564-575`).
2. **`seat_system.gd` `board_squad` (:391-410)** — per-man staging slots: `staging +
   side * 1.4 * i` (side = door lateral), so the extraction queue is a stick line abeam
   the door, not one point. `_board_one`'s 8 m `BOARD_NEAR_M` gate (`:426`) already
   tolerates the offsets.
3. **Optional polish, `heli_lift.gd:294-300`** — clamp each bunk through
   `NavigationServer3D.map_get_closest_point` (precedent: `nav_router.gd:84-88`) so a bunk
   hashed into a hootch footprint doesn't strand a man pressing a wall.

**Sacrificed:** a wider fan can place a man off the pad's baked nav box (the ground-cast +
clamp bounds it); `unseat_all` narrowing to passengers means any future crew-bailout flow
needs its own explicit unseat; the stick line is a few more metres of walk per extracted man
inside the 35 s ground window (`heli_lift.gd` ground time budget — verify against
`lz_cycle`'s dwell before widening past ~1.4 m spacing).

---

## DEFECT 3 — Squad never catches up when the player leaves the base

### Root cause — a latch, a speed deficit, and blind steering; no catch-up mechanism exists

**(a) The demo gate order latches the whole squad OUT of FOLLOW for up to 210 s.**
`demo_game.gd:301-353`: at T+10 s every member gets `OrderMode.MOVE_TO` the gate (`:330`).
Release back to FOLLOW requires **every living member** within 8 m of the gate
(`:334-344`, `arrived < alive` → return) or a 210 s timeout (`GATE_ORDER_MAX_S` `:306`).
One man strangled by compound pathing holds all eight in MOVE_TO — and in MOVE_TO an ally
walks to `order_pos` and settles (`ally_base.gd:1096-1100`); he does not follow anybody.
The file's own comment admits it: "The opening beat is hostage to compound pathing"
(`demo_game.gd:350-351`). Player walks out the wire inside that window → the squad stands
at the gate behind him, exactly as playtested.

**(b) Even in FOLLOW, catch-up loses to sprint.** Follow is `_execute_idle`'s FOLLOW branch
(`ally_base.gd:1028-1093`): move at `move_speed * CATCHUP_MULT` = **5.6 × 1.35 = 7.56 m/s**
(`ally_base.gd:9`, `:159`, `_move_toward` `:1585-1592`) once the slot lag exceeds
`max_follow_distance = 10.0` (`:148`). Player `SPRINT_SPEED = 8.0` (`player.gd:6`), winded
pace 7.0 (`player.gd:74`). During the 5.6 s burst the gap **grows**; winded, it closes at
0.56 m/s — 90 s to claw back 50 m, assuming a straight line. There is no distance at which
anything stronger than the 1.35× multiplier engages.

**(c) Outside the base, steering goes blind.** `nav_router.gd:53-63`: pathfinding applies
only when agent and target sit in the **same baked nav box**; the player beyond the
perimeter fails `box_contains` and the ally falls to direct steering
(`return direct`, `:63`) — a straight line into the berm/wire, with only a 0.6 s
alternating sidestep unstick (`ally_base.gd:60-72`) to save him.

**(d) No teleport exists.** Repo-wide grep for teleport/catch-up: the only movement
catch-up is `CATCHUP_MULT` (`ally_base.gd:159`); nothing relocates a lagging ally.

### Proposed fix (direction pre-approved by Caleb: invisible teleport catch-up)

**Insertion point:** `SquadSystem._physics_process` (`squad_system.gd:397-419`) — a
squad-level `_catchup_tick()` on a 1 s cadence (pattern precedent: the 0.4 s
`_point_scan_timer` gate `:407-411`). Squad-level, not per-ally: one place owns the rule,
and it can stagger members so eight men never pop in the same frame.

Per living member, teleport when ALL of:
- `order_mode == OrderMode.FOLLOW` and `squad_member` (`ally_base.gd:174`) — the demo's
  MOVE_TO latch is untouched (but see companion fix below);
- out of combat: `a.target == null` and `a.target_last_seen_time > ~5.0`
  (`ally_base.gd:23-27`) — never teleport a man out of, or into, a fight;
- distance to player > **TELEPORT_M ≈ 40 m** (4× `max_follow_distance`), OR > 25 m AND
  off-screen;
- off-screen check (cheap, no raycast):
  `get_viewport().get_camera_3d().is_position_behind(a.global_position)` — a man behind
  the camera plane can never be seen popping; skip the frustum test, the behind-plane test
  is one dot product;
- player not seated in a vehicle: `GameManager.player` has `enter_seat`
  (`seat_system.gd:300-302`) — gate on the player's seated state so the squad never
  chases a Huey (SeatSystem.seat_of is per-ship; simplest is a player-side flag check);
- the ally himself is not mid-board/seated (`seat_of` via any ship would have his physics
  off anyway — a seated body never trips the distance gate because it isn't processing,
  `seat_system.gd:307-308`).

Placement: `player_pos + behind * (6.0 + 1.5 * file_slot)` (behind = player's `basis.z`
flattened, same math as the radio leash slot, `ally_base.gd:1040-1043`), clamped by
`NavigationServer3D.map_get_closest_point` (precedent `nav_router.gd:86`), then a downward
ray for ground Y (precedent `seat_system.gd:564-575`), then
`reset_physics_interpolation()` — mandatory, interpolation is on project-wide
(`seat_system.gd:344-345`), or the man streaks across the map. Also reset the follower's
slot smoothing (`_slot_valid = false`, `ally_base.gd:1082-1086`) so he doesn't sprint at a
stale `_slot_smooth` 40 m behind.

**Companion fix (the case Caleb actually hit):** the gate-order latch. Release each man to
FOLLOW **individually** on his own arrival (`demo_game.gd:334-349`), and add a third
expiry: release-all the moment the player himself passes the gate radius — the beat's
purpose ("your squad leaving without you", `demo_game.gd:297-299`) is over once he has
left. Without this, the teleport (gated on FOLLOW) correctly refuses to fire during the
opening and the defect window survives.

**Sacrificed:** teleporting hides the real pathing failures (c) instead of fixing them —
they stay hidden until a system that can't teleport (extraction boarders, litter teams)
walks the same ground; a rear-view player can still catch a pop at the 25 m off-screen
tier (the behind-plane test bounds it to "was not on screen this frame", not "was not
seen"); and a man teleported out of a trailing position abandons any dropped
casualty/rescue geometry behind him (RESCUE order is excluded, but the corpse he was
walking past is not). No free lunches.

---

## Verification notes for the Arbiter

- Defect 2's fix is testable without launching: the exit fan and staging slots are pure
  math in `seat_system.gd`; the existing seat contract test
  (`seat_system.gd:92` comment re: the thaw) is the place a fan assertion belongs.
- Defect 3's teleport gate touches `demo_game.gd`'s opening beat — the M-4 print at
  `demo_game.gd:352-353` already logs arrival counts; keep it, it becomes the regression
  canary for the individual-release change.
- Drift found in passing (FOSSIL/POINTER law): `heli_lift.gd:119` ("They are never
  unseated") is FALSE against `seat_system.gd:378-386` — correct the comment or the code
  in the same change that fixes the fan.
