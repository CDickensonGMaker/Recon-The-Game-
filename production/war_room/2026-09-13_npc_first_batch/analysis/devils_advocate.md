# DEVIL'S ADVOCATE — NPC first batch (2026-09-13)

Time-boxed 25 min. Read code, not the plan, per the briefing's own rule.

## 1. Where each item breaks, and the caller

**Item 1 (`_resolve_target` role-aware).**
- `scripts/vehicles/heli_lift.gd:307-358` `_deliver()` sets `man.working_point_pos = bunk` for
  every replacement dropped at the pad, where `bunk` is chosen by a **best-effort** 12-try
  golden-angle walk (`:336-340`) that gives up and accepts a collision if all 12 fail, and is
  identical to `man.home` (`:343-344`). Item 1's premise — "working_point_pos is exclusive by
  construction" — is true for `mission_generator._build_firebase_garrison` (per-index ring,
  `:1200-1204`) and for village dealing (`:1312-1319`), but **false** for this path. Under item 1,
  `off_duty`/`detail` sit/talk/rest correctly routes to this bunk — but the bunk itself can
  collide with another replacement's bunk. Not a new break by item 1 alone, but item 1 is the
  premise item 3 relies on, and it does not hold here.
- `scripts/allies/garrison_defender.gd:118-155` `stand_down()` never sets `civ.home`.
  `Civilian.spawn()` (`civilian.gd:411`) sets `home = pos`, i.e. the **ally's last combat stand**
  (a foxhole/bunker lip on the wire), not his hooch bunk. Under item 1, `sleep`/`walk_home` →
  `home` (correct new routing) sends this reborn civilian to sleep **at his fighting position**
  every dawn after a night he survives — ADR-035 §6 ships stand-down but never restores the
  quarters assignment. Item 1 makes this MORE visible, not less: everything else now goes to a
  named place, so this one man sleeping at a bunker reads as the anomaly, not as part of a
  uniformly-broken system.

**Item 2 (re-pick on `action_for` change).**
- `civilian.gd:1216-1231` `_bt_tick`, tests pinning `last_pick_hour`
  (`test_group_walk.gd:45`, `test_offview_liveness.gd:51`) lose the seam they pin. The plan says
  "moved with the change" but does not say what replaces it — if the harness does not gain an
  equivalent freeze (e.g. writing `_bt_bb["scheduled_action"]` directly), the BT free-runs to
  whatever `action_for(real_hour)` says and the test may pass by construction instead of testing
  the frozen-value case it was built to catch.
- Comparing `action_for(...)` every tick (not gated by `_box_timer`'s 0.5s poll, unlike nav
  region refresh at `:536-540`) means up to ~40 garrison + village civilians each do a
  `hash(who)` + ~10 float compares **every physics frame** instead of once per sim hour. Probably
  cheap in isolation, but this file's own comments (`:464-476`) show the project is already
  counting single-digit-millisecond costs across 36+ garrison men mid-siege; the plan states the
  cost is "pure, cheap" but names no budget and the probe (item 5) measures correctness, not frame
  cost.

**Item 3 (jitter only where shared).**
- Directly regresses the heli-replacement path above: removing `WORK_JITTER_M` from
  `working_point_pos` assumes exclusivity that `heli_lift.gd:336-341` does not guarantee. Before
  item 3, a colliding bunk pair still got a 1.5m name-hash spread as an accidental safety net;
  after item 3, two replacements whose bunks tie (or whose 12-try walk both failed toward the
  same nav-clamped point via `_bunk_on_nav`) stand exactly on top of each other with **zero**
  correction. This is a case the batch's own probe (item 5) would need to sample specifically
  (post-heli-drop) to catch, and nothing in item 5's spec calls out a heli-drop moment.

**Item 4 (animation cache key = `want + scheduled_action`).**
- `civilian.gd:606-607`: `sit`, `talk`, `rest` all collapse to `want == "seated"`.
  `_play_garrison`'s off-duty branch (`:712-716`) calls `off_duty_chain(role, _idle_seed)`, which
  is a pure function of `role` and `_idle_seed` **only** — it never reads `want` or the schedule
  action. Off-duty's own schedule (`civilian_schedules.gd:263-285`) transits
  `TALK(12.5-14.5) → REST(14.5-16.5) → … → TALK(18.5-20.5)`: three action changes, same `want`,
  same `off_duty_chain` output every time. Under the new cache key
  (`want + "|" + scheduled_action`), every one of those transitions is a cache miss and forces a
  full re-dress — replaying the identical clip from frame 0. That is a visible twitch, on every
  off-duty man (6 of the curated 17, plus every hooch/rest-marker fallthrough), at three points in
  the demo evening, for **zero visual change**. This is new noise the batch introduces while
  chasing "wrong clip" — it is not the reported symptom, but it is a regression against "settle
  and hold." The gun-crew-arty and mess-hall branches have the same shape (chain keyed on
  `_idle_seed` alone, `civilian.gd:782-792`, `810-848`) but their schedule actions don't cross a
  same-`want` boundary the way off-duty's does, so the exposure is narrower there.
- The plan's own question ("must `role` be in the key?") is answered backwards: the fix needed is
  the opposite — the key needs to be **coarser** for chains that don't read the action (off-duty),
  not finer.

**Item 5 (probe_npc_census).**
- Sample #1 at T+40s real-time, at 38x and `START_HOUR = 6.5`
  (`demo_game.gd:44,49`), lands at sim-hour ≈ 6.5 + 40·38/3600 ≈ **6.92h**. None of F02/F03/F07
  fire there: the mess sittings are 06.0-08.7 (breakfast, close but the window is `sitting*0.4h`
  offsets so a 6.92h sample can miss all three breakfast sittings by design) and 19.5-20.7
  (supper — the one "the demo shows," per `civilian_schedules.gd:200-201`); off-duty's SIT/TALK/
  REST churn is 07.5-20.5. "again after a sim-hour boundary" is not specified as WHICH boundary —
  if it is simply the next integer crossing, the second sample is ~7h, still missing supper,
  stand-to, and the off-duty churn windows entirely. **The probe as specced can pass green while
  every symptom the owner reported (dusk, stand-to) goes unsampled.**
- Overlap threshold (<0.45m XZ) undercounts: two 0.3m-radius capsules read as visibly clipped at
  up to ~0.6m center separation. A near-miss from the heli-drop bunk collision (item 3's new
  exposure) could sit at 0.5-0.6m and pass the overlap check while still reading as "inside each
  other" to the owner.

## 2. Symptoms the batch does NOT fix — ranked by likelihood of being what the owner saw

**#1 — Bodies stacked: `scripts/missions/friendly_patrol_group.gd:82-93` `_advance_route()`.**
Every man in the element (`AllyBase`, not `Civilian`) is given
`set_order(AllyBase.OrderMode.MOVE_TO, route[_wp])` — the **identical XZ point**, no formation
offset, no per-man jitter, no name-hash spread of any kind. This is wholly outside the five
defects (none of which touch `AllyBase` or this file). An ambient patrol converging on a
waypoint is a guaranteed stack at every leg, for the life of the element. Spawned via
`ambient_encounters.gd` during "the day out" segment of the demo arc
(`demo_game.gd:26` comment: "dawn spawn -> the day out -> dusk return"), which is exactly the
25-minute window the owner would be walking through. This is the single strongest outside-batch
candidate for "people standing inside one another" — more central than any Civilian jitter
defect, because it has **no** anti-stack mechanism at all, versus Civilian's WORK_JITTER_M which
at least exists today.

**#2 — Wrong clip in the wrong place: `scripts/allies/garrison_defender.gd:149-155` `stand_down()`.**
`home` is never restored. A defender who survives a night's stand-to comes back as a Civilian
whose `home` is his fighting position — a foxhole, a bunker lip, a spot on the 8m-leash defense
zone (`:75-76`) — not his quarters. Every subsequent `sleep`/`walk_home` (both current code and
item 1's proposed mapping) puts `sleeping_laying` at that spot. Given the demo's stand-to is at
night and the reported symptoms were seen "across playthroughs," a multi-night or repeated-demo
session would show a soldier bedding down at a bunker line — a clean instance of "same clip in
the wrong place" that survives this batch untouched, and that item 1 will now execute more
faithfully (routing IS correct; the input, `home`, is wrong).

**#3 — Men on roofs: explicitly out of scope (F01/N2), and probably already mostly fixed.**
`game_world.gd:440-457` `floor_y()`'s own comment dates the rooftop fix to 2026-08-04/08-12 and
names the exact 18cm miscalibration that caused it. `terrain_watchdog.gd:68-73` already re-seats
on wake via `floor_y`, not `surface_y`. `probe_roof_spawn.gd` is a standing gate, not new. If the
owner still saw roofs recently, the likely remaining source is a path this batch does not touch
either: `heli_lift.gd` disembark (the probe's own header names six men failing on a helipad on
2026-09-09 — a solved case, but the shape (a spawn path outside `floor_y`) could recur for any
future drop point that seats by `surface_y` or raw marker Y instead of `floor_y`). Rank this
third — most likely a symptom from an OLDER build the owner is describing from memory, not a live
gap this batch should have caught, since roofs are explicitly deferred to N2 per the briefing.

**#4 — Bodies stacked (secondary): `heli_lift.gd:336-341` bunk assignment**, per item 3 above —
real, but narrower in scope (only fires on a resupply/replacement drop) than #1.

## 3. The demo-clock interaction

At `DAY_RATIO = 38` (`demo_game.gd:49`), a 0.4h mess sitting = 0.4 × 3600 / 38 ≈ **37.9 real
seconds** — matches the briefing's estimate. But the supper sitting (19.5-20.7h,
`civilian_schedules.gd:206-207`) sits **after** `NIGHT_HOUR = 19.0` (`:245`), where the clock
drops to `NIGHT_RATIO = 20.0` (`:56`). At 20x, that same 0.4h window is **72 real seconds** — the
window the owner would actually see is roughly double the daytime estimate, not 38s. This matters
because it changes the answer to "do diners now walk to the hall and back in the window": the
Arbiter's own worst case is nearly 2x more forgiving at supper than at breakfast.

I cannot compute the quarters-to-chow-hall walk distance from the files read (marker positions in
`_fsb_markers`/`FSB_GARRISON_QUARTERS` are runtime-baked from the GLB, not literal coordinates in
`site_planner.gd`). **What must be measured before shipping item 1+2 together:** the actual XZ
distance from a `FSB_GARRISON_QUARTERS` entry to a `chow_diner`/`queue` work marker, at `WORK_SPEED
1.1` / `IDLE_SPEED 0.8` (`civilian.gd:1428,1472`). If any quarters-to-hall leg exceeds roughly
30m at 1.1 m/s (~27s), a diner **cannot** walk in, sit (item 4's `CHOW_SIT_S 0.83` scaled by
nothing — it's real seconds, not sim seconds, so it is unaffected by ratio) and hold before the
72s supper window closes at night, let alone the ~38s equivalent an earlier sitting run at
`DAY_RATIO` would give (mess only fires at night in this schedule, so this specific risk is
bounded to the 20x rate — but a fractional-timing fix elsewhere, e.g. `off_duty`'s SIT windows
which run at daytime `DAY_RATIO` 06.0-22.0, could still be squeezed. Off-duty's SIT window is
07.5-9.5h = 2h = 189 real seconds at 38x — generous, not a risk).

Verdict: item 2's fractional fix is **more dangerous at 38x for short (<1h) daytime windows than
at the 20x night windows** the briefing's arithmetic focuses on. Nothing in `civilian_schedules.gd`
currently has a sub-hour daytime window except the mess breakfast sittings (06.0-08.7, still
inside `DAY_RATIO`) — those are the ones actually squeezed to ~38s, and item 1+2 together make men
attempt the walk-in they previously skipped. **Whether that walk is physically possible in 38s
is unmeasured and unmeasurable from the files given** — it needs the quarters/chow-hall marker
distance, which lives in the exported GLB, not in this script tree.

## 4. What is SACRIFICED (law 2 — no free lunches)

- **Item 2 sacrifices the once-per-hour throttle** that kept `_resolve_target`/nav queries rare;
  paid in per-tick comparisons across the whole live civilian population, for a class of bug
  (missed 0.4h windows) that affects only mess sittings and a handful of garrison hand-off hours.
- **Item 3 sacrifices the jitter safety net** for every `working_point_pos` that is not, in fact,
  exclusive — trading a cosmetic 1.5m fudge for exact-station realism everywhere item 1's premise
  holds, and zero collision margin everywhere it doesn't (heli-drop bunks).
- **Item 4 sacrifices settle-and-hold** for occupations whose clip choice is action-blind
  (off-duty, and to a lesser extent gun-crew-arty/mess-hall): more re-dresses, more visible
  twitch, in exchange for correctly re-dressing the occupations that DO need it (mess-hall seated
  vs eating-standing, patient vs medic).
- **Item 1 sacrifices the "missing content is silent" convenience** for a boot report — good
  trade, but it also SILENTLY accepts `heli_lift.gd`'s non-exclusive `working_point_pos` as if it
  were exclusive, which is the free lunch nobody named: the batch assumes every `working_point_pos`
  writer honors the one-man-per-point ruling (2026-08-24), but only two of the three writers
  (`mission_generator.gd`, village dealing) do.
- **Item 5 sacrifices coverage of the actual reported moment** (dusk/night) for cheap-to-implement
  fixed-offset sampling (T+40s + "a" sim-hour boundary), which is exactly the kind of gap that
  lets the batch "ship green" while the owner's symptom survives, per this council's own
  mandate.

## 5. Cheapest failing-before/passing-after evidence

Run `tools/probe_npc_census.gd` (once it exists) at **`--demo-seed=<fixed>`**, sampling at:
1. T ≈ (19.5h − boot_hour-to-seam) worth of real seconds — i.e. compute via `_arc_hour_at`
   inverse, or simpler: force `SimClock.set_time(1, 19.4)` at boot under the probe and let it run
   90 real seconds, spanning the entire supper sitting at `NIGHT_RATIO`.
2. A second sample forced at `sim_hour ≈ 21.0` (post-`PROBE_AT_S`, the historical stand-to hour
   per `demo_game.gd` comments) to catch `GarrisonDefender.promote`/`stand_down` hand-off
   artifacts.
3. A third sample during "the day out" (sim_hour 9-11, `DAY_RATIO`) with any `FriendlyPatrolGroup`
   forced to spawn, specifically checking overlap pairs among `AllyBase` squad-member-false nodes
   — **not covered by `probe_npc_census` as specced**, since it only samples
   `garrison`/`villager` Civilians, not ambient `AllyBase` patrols. This would need a scope
   addition, not just a timing addition.

**What this would prove:** that F02/F03/F04/F06/F07 are fixed at the exact hours they fire, and
that the two upstream-state bugs (stand-down `home`, heli-drop bunk collision) are either present
or absent independent of the batch.

**What it would NOT prove:** that the owner's *specific* reported instances are gone — the owner's
memory of "roofs," "wrong clip," "stacked" may be from any of several code paths (patrol groups,
heli drops, stand-down, or genuinely F02-F07), and a green census only says these five defects are
inert at the sampled hours. It says nothing about `friendly_patrol_group.gd`, nothing about
`heli_lift.gd`'s bunk dealer, and nothing about `garrison_defender.gd`'s missing `home` restore —
all of which this council scoped OUT.

## 6. Answers to the briefing's six questions

- **Where does the shape break something that currently works?** Item 3 breaks the incidental
  jitter safety net at `heli_lift.gd:336-345` bunks (§1/§4 above). Item 4 breaks settle-and-hold
  for off-duty men at three schedule transitions per evening (§1/§4). Item 2 risks silently
  neutering `test_group_walk.gd`/`test_offview_liveness.gd` if the seam isn't replaced in kind.
- **Which occupations/roles would stand inside a prop or on a bad surface at an exact station?**
  None newly, from `fsb_garrison_plan`'s own construction — curated multi-man posts already ring
  by index (`mission_generator.gd:1200-1204`), work-marker posts are one-man-one-marker by the
  dealer. The exposure is not "inside a prop," it's "on top of another MAN," and it is
  concentrated in `heli_lift.gd`'s replacement bunks, which are not part of `fsb_garrison_plan` at
  all.
- **What does re-pick-on-change do at midnight/set_time jumps/sleep_advance/pause/38x?** Midnight
  wrap is safe (action_for's ranges already handle the `>=`/`<` wrap, and comparing actions instead
  of `int(hour)` is strictly more correct across the wrap). `SimClock.set_time` jumps (stress-night
  seat, debug) can re-trigger a mess sitting a second time if the jump lands back inside a window
  already served — a determinism/double-entry risk the plan doesn't address. Pause is safe (no
  physics ticks, no re-pick). 38x is the dangerous case for short daytime windows (§3).
- **Is the animation key enough, or must `role`/`is_garrison`/`_chow_seated` be in it?** The key is
  simultaneously too fine (off-duty, gun-crew-arty, mess-hall-queue don't read `scheduled_action`
  at all — see §1/§4) and, per the plan's own text, correctly recognizes it needs `role` for the
  cases that DO branch on it. The fix isn't "add more to the key," it's "key on the actual chain
  selector inputs per occupation," which for off-duty is `role` alone, not `want|action`.
- **What is sacrificed?** §4.
- **Single riskiest edit / cheapest probe?** See verdict below.

---
**Riskiest edit:** Item 4's cache key change (`civilian.gd:614-616` + off-duty's action-blind
chain at `:712-716`) — it is the one change most likely to make the compound look MORE restless
during the exact evening window the owner watches, in direct tension with the batch's own goal.
**Cheapest probe:** force-seat `SimClock` at 19.4h and 21.0h under `probe_npc_census` and log a
per-man clip-change counter across a fixed real-time window; a count > 1 for any off-duty man with
no `want` change is the item-4 regression, cheap because it needs no new instrumentation beyond
what item 5 already proposes to print.
