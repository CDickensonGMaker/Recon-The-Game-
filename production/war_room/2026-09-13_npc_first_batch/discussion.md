# DISCUSSION — NPC first batch (2026-09-13)

Three architects, no cross-talk: `analysis/systems_designer.md`, `analysis/lead_programmer.md`,
`analysis/devils_advocate.md`. Verdicts per briefing item, then where they agree and disagree.

| Item | Systems designer | Lead programmer | Devil's advocate |
|---|---|---|---|
| 1 role-aware `_resolve_target` | AMEND: `sit/talk -> post` regresses `sentry_night` 13:30-16:30 (`civilian_schedules.gd:132-135`) — his post is the wire, not a seat; needs the same exception list `rest` has | AGREE; the "once per man" missing-content report has no ledger to live in — scope it or it is per-tick spam | AMEND: `heli_lift.gd:307-358` bunks are best-effort, not exclusive; `garrison_defender.gd:149-155` `stand_down` never restores `home`, so a revived man's `sleep` is at the wire (pre-existing, item 1 executes it more faithfully) |
| 2 re-pick on change | AGREE, but MUST ship with item 4's generation guard — faster re-picks make F07 fire more often alone | AGREE; cost is ~10 float compares + one hash per tick; midnight / `set_time` / `sleep_advance` / pause / 38x all clean, no double entry | AMEND: breakfast sittings at 38x are ~38 s real; `last_pick_hour` deletion needs a named seam or `test_group_walk` / `test_offview_liveness` pass by accident |
| 3 jitter only where shared | AGREE in principle | AMEND: with the 1.5 m slack gone, `WORK_ARRIVE_M 0.7` vs nav-clamp slop can leave a man RUNNING forever; `CAPTURE_M 3.5` still captures gun crews | REFUSE as written: heli bunks are not exclusive; zero jitter there removes the only collision net on that path |
| 4 animation key + `_anim_gen` | AMEND: key needs `role` (two off_duty men, same `want`, different chains) | AMEND: key needs `role`, must EXCLUDE `_chow_seated` (a latch); riskiest edit is `desync_loop` re-seeking on a key miss whose clip did not change — a visible pop | REFUSE as written: action-blind chains (off_duty, gun_crew_arty, mess queue) get spurious re-dresses at every schedule transition |
| 5 census probe | AGREE; add a sample inside 13:30-16:30 | AGREE; iterate `AgentRegistry` (villagers AND garrison), read `scheduled_action()` vs `active_action`, `actor.current_action`; reuse `probe_roof_spawn.gd` unchanged | AMEND: T+40 s is ~06.9 h — misses supper and stand-to; scope must include `AllyBase` |

## Convergence (from different doors — the strongest signal)

- **All three: `role` belongs in the animation key.** Two independently found the off_duty case, one the mess/gun case.
- **All three: item 2 is sound at the clock edges** (LP walked every edge; DA found no double entry at midnight/pause; SD's only condition is that it ships with the gen guard).
- **Two of three (LP, DA): the riskiest edit is the re-dress path.** LP: `desync_loop` on an unchanged clip pops. DA: spurious re-dresses replay from frame 0. The Arbiter checked the code: `ModelActor.play()` at `model_actor.gd:1201-1202` is a no-op when the clip is unchanged (`if clip == _current_clip and not restart: return true`), so a same-clip re-dress does NOT replay — the DA's frame-0 claim is refuted for `play()`. LP's point stands: `desync_loop()` (`:1246-1256`) re-seeks and rerolls `speed_scale` unconditionally. So the pop is real and it lives in `desync_loop`, not `play()`. Resolution: gate `desync_loop` on the clip string actually changing.
- **Two of three (SD, DA): the census must sample more than one hour.**

## Disagreements, resolved by reading the code

1. **Zero jitter (item 3).** DA refuses because heli bunks are not exclusive. True — but the heli path sets `working_point_pos = home = bunk` (`heli_lift.gd:344-345`), so the rule "spread only when the destination is `home`" keeps the spread for exactly those men with no special case. LP's stall: `_step_toward` (`civilian.gd:999-1013`) already has a 1.0 m dead zone in which velocity decays to zero, so TODAY a man rests ~0.8 m short of any target and `WORK_ARRIVE_M 0.7` is rarely reached (the animation keys on `active_action`, not on BT SUCCESS, which is why nobody noticed). Zero jitter therefore does not create a new stall class — it exposes the existing one, and the fix is proportional slow-down inside 1 m instead of a dead zone, so a man can actually stop on the marker.
2. **`sit/talk` at post (item 1).** SD is right. The occupation list for post-bound off-duty actions is explicit: `off_duty`, `mess_hall`, `gun_crew`, `gun_crew_arty`, `radioman`, `medic`, `patient`. Sentries and the detail go home to loaf.
3. **`last_pick_hour` (item 2).** DA wants a named seam. The seam is `_bt_bb["scheduled_action"]`: the re-pick compares `action_for()` against it. `test_group_walk` pins `scheduled_action` to `walk_paddy` on a farmer at the wall-clock hour — under the new rule the schedule would overwrite it on the next tick whenever the wall hour is not a walk_paddy hour. The test moves with the change: it pins the clock to a farmer walk_paddy hour (05:30) instead of pinning a cache field that no longer exists.
4. **The missing-content report (item 1).** LP: no ledger exists. Resolution: the census probe is the report; the resolver only falls back to home. No new runtime spam.

## What the Arbiter's read missed (accepted)

- **DA: `friendly_patrol_group.gd:82-93` sends every man in an ambient element to the identical waypoint** — `AllyBase`, outside the five defects, and the strongest single candidate for "bodies stacked" during the day-out segment. Bounded (per-man file slot along the leg direction), it joins this batch as item 6 and the census overlap check covers allies to gate it.
- **DA: `stand_down` never restores `home`.** Two-line snapshot (`garrison_home` meta) in `promote`/`stand_down` — the first N4 step, taken now.
- **SD: the 1.8 m station ring only fires for the curated `men=2` posts** (`GUN_POINT_001`, `FOOTPRINT_002/004/007`) — the briefing's "two servers on one cook_range" does not occur. The MG-mount gunner/loader ring is real and is N3 work, recorded.
- **LP: `WORK_ARRIVE_M` vs the `_step_toward` dead zone** (above).
