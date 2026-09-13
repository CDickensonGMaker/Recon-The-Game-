# THE DECREE — NPC first batch: right place, right time, right clip (2026-09-13)

**Arbiter:** Claude (Fable 5.1), for the Summoner. Council: `analysis/systems_designer.md`,
`analysis/lead_programmer.md`, `analysis/devils_advocate.md`; debate in `discussion.md`.
**Branch policy (his ruling, same day):** base-simulation fixes commit on `BaseGame-V1` and merge
forward into `RPG-build`; RPG game-state work stays on `RPG-build`. This batch is base simulation.

## The judgment

The owner's three symptoms have five source-confirmed causes inside `civilian.gd` (F02, F03, F04,
F06, F07 — `briefing.md`), one outside it that the council surfaced (`friendly_patrol_group.gd:82-93`,
every man in an ambient element ordered to the same waypoint), and one identity leak the council
surfaced (`garrison_defender.gd:149-155`, `home` not carried through stand-down). Roofs (F01) are
deferred to N2 as briefed; the council rates them the least likely live source (`floor_y` and the
watchdog already probe from the marker's own height; the roof probe is a standing gate).

## The build (six items, one change, one commit on `BaseGame-V1`)

1. **`_resolve_target` is role-aware, deterministic, and knows whether its answer is exclusive.**
   Garrison: `work/cook/fish/walk_paddy` -> `working_point_pos`; `rest/sit/talk` -> `working_point_pos`
   for `off_duty`, `mess_hall`, `gun_crew`, `gun_crew_arty`, `radioman`, `medic`, `patient` (their post
   IS the seat, pit, set or cot), else `home`; `sleep/walk_home` -> `home`; `walk_fire/walk_market`
   unchanged (home offsets). Villagers: mapping unchanged. Every `home` answer carries a name-hash
   spread (the unseeded `randf_range` at `:1364-1365` is deleted — ADR-010). The resolver writes
   `bb["target_exclusive"]` = true only when the answer is a `working_point_pos` that differs from
   `home` (heli bunks are `home == working_point`, so they keep the spread — the DA's refusal is
   satisfied without a special case). No place -> home; the census probe is the missing-content report.
2. **The schedule is re-picked when `action_for()` changes, every tick.** `last_pick_hour` is deleted
   (fossil law); the seam is `bb["scheduled_action"]`. `test_group_walk` pins the clock to a farmer
   walk_paddy hour instead of the dead field; `test_offview_liveness` drops the field;
   `test_bt_civilian` gains a continuous sweep across 19.4-20.8 that must see all three mess sittings.
3. **Spread only where the destination is shared.** `_bt_settle` applies `WORK_JITTER_M` only when
   `bb["target_exclusive"]` is false. `_step_toward`'s 1.0 m dead zone becomes proportional
   slow-down (full speed beyond 1 m, scaled inside it, stop under 0.35 m) so a man can actually reach
   `WORK_ARRIVE_M 0.7` on an exact marker — the LP's stall class, which already exists today, closes
   with it. `WORK_ARRIVE_M` stays 0.7. The stale ordering comment at `:1422-1425` is scoped to the
   shared path in the same change.
4. **The animation cache is keyed on `want | scheduled_action | role`;** `_chow_seated` stays a
   latch outside the key. `_anim_gen` bumps on every re-dress; the chow sit-down timer fires only if
   the generation matches and the man is still seated. `desync_loop()` runs only when the clip string
   actually changed (compare `actor.current_action` before/after), on every path including the
   village early returns and the chow timer — so a same-clip re-dress cannot pop, and a sitting of
   eight cannot chew in unison.
5. **`tools/probe_npc_census.gd`, attached by `--npc-census`** (same pattern as `--roof-probe`,
   `game_flow.gd:766-772`). Samples at T+40 s (spawn state, ~06.9 h at the demo's 38x), then drives
   `SimClock.set_time` to 10.5, 14.5 and 19.7 with 60 s of real settling each, and at every sample
   prints per man: name, occupation, role, scheduled vs executed action, XZ distance to post and to
   home, current clip; then counts **wrong-place** (a post-bound action > 2.0 m XZ from the post),
   **overlaps** (pairs of civilians+allies < 0.45 m XZ and < 0.5 m Y), and **roofs** (the
   `probe_roof_spawn.gd` test, extracted to a static helper so there is one roof test with two
   callers). Exit 1 on any count > 0. Run BEFORE the fixes for the failing baseline, AFTER for the
   gate. `--test-save` always; `--demo-seed` fixed.
6. **Ambient patrol men get distinct moving slots.** `friendly_patrol_group.gd`: man `i` is ordered
   to `waypoint - leg_dir * 2.5 * i + lateral * 0.8 * (i % 2 ? 1 : -1)`, a staggered file behind the
   pointman; `test_friendly_patrols` moves with it (asserts each man's `order_pos` is within the
   file's length of `route[1]`, and no two are equal).
7. **`promote`/`stand_down` carry `home`** (`garrison_home` meta). A defender who lives goes back to
   his quarters, not to the wire. First N4 step; the full identity snapshot stays N4.

## What is sacrificed (law 2)

- **Visible traffic at spawn.** Today the jitter makes every man walk ~1.5 m on frame one; with
  exact stations a man teleported to his post stands still until his schedule changes. Traffic now
  comes from real schedule boundaries — and there are more of them (fractional windows now fire).
- **Hourly variety of loafing spots.** Villagers and off-shift men stand at one name-hash spot near
  home for the whole action instead of re-rolling every hour. Determinism over variety (ADR-010).
- **Continuous-clock proof.** The census jumps the clock with `set_time`; it proves the jump path
  and the settle, not the 38x continuous demo. The continuous run stays the Summoner's playthrough.
- **Roofs are not touched.** F01 waits for N2; if he still sees a roof, the census names the man.
- **Patrol formation is a file, not doctrine.** Item 6 is spacing, not the N5 formation work
  (halt positions, arcs, trail compression). It stops the pile; it does not make a patrol.

## Gates before this batch is called done

- Headless boot of the demo scene: 0 `SCRIPT ERROR`.
- Census BEFORE > 0 on wrong-place (the cook at his hooch is the expected instance); census AFTER = 0
  wrong-place, 0 overlaps, 0 roofs at all four samples, or every remaining row named with a cause.
- `run_all_tests.ps1 -Filter` on: `test_bt_civilian`, `test_schedule_placement`, `test_group_walk`,
  `test_offview_liveness`, `test_firebase_garrison`, `test_friendly_patrols`, `test_fossils`. Serial.
- Commit on `BaseGame-V1`, merge into `RPG-build`, push NOT done (his call — the checkout is shared
  and `BaseGame-V1` tracks `origin/master`).

## Next demo blocker after this batch

N2 placement contract (F01/F08) — the census's roof row is its failing test if it ever fires; and
the 25/15 arc council (0A/0B), which is RPG-build work.

## Gate results (same day, evening) — `results.md`

Built and measured BEFORE/AFTER on the shipped seed: wrong-target 61 → 0, overlaps 64 → 25, roofs 0,
script errors 0. Four items joined the seven while running the gate (the squad's own gate order
stacked six men at one point; the resupply replacements walked toward their flight origin; the
rename had missed `gun_crew_performance.gd:97`; a wire-poll stand-to emptied the census mid-run, so the
director now carries a probe-only hold). What remains is named per row in `results.md`: 53 stuck rows
are men on the floor, on the mesh, aimed at the right post, with no route out of their quarters — the
same men stood still BEFORE. That is N2's first case, not this batch's. Three of the seven tests are
red at HEAD too (`test_group_walk`, `test_friendly_patrols`, `test_firebase_garrison` — the runner's
"was GREEN" register is stale for the last).
