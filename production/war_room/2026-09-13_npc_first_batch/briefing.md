# BRIEFING — NPC first batch: right place, right time, right clip (2026-09-13)

**Branch:** `RPG-build` (new; the old line is `BaseGame-V1`, tracking `origin/master`). HEAD at
convening: `daf621cd`. Another session holds uncommitted Conquest of Worms art + tool work in the
same checkout — preserve it, never stash or reset it.

**The Summoner's handoff (2026-09-13, "complete 40-minute demo plan").** The approved goal is a ~40
minute demo: ~25 min of quests/patrols/relationship-building, then ~15 min of firebase assault. The
release order is Demo-critical first. **This council is convened on the FIRST IMPLEMENTATION BATCH
ONLY** (handoff §0B "A concrete first implementation batch", items 3–5, plus a bounded instrument for
item 2). The 25/15 arc, quests, Hearts and Minds, the crash event, save-anywhere and the big
architecture (§5) are LATER councils. Do not design them here.

**The reported symptoms (observed by the owner across playthroughs):** soldiers on building roofs
who stay there; friendly groups performing the same irrelevant animation in inappropriate places;
people standing inside one another.

## What this batch fixes — source-confirmed at HEAD by the Arbiter (2026-09-13)

| # | Defect | Where | What the code does now |
|---|---|---|---|
| F02 | Activities sent to the wrong TYPE of place | `scripts/world/civilian.gd:1355-1366` `_resolve_target` | Only `walk_paddy` / `work` / `fish` use `working_point_pos`. `cook`, `sit`, `talk`, `rest`, `sleep` go to `home + randf_range(-3,3)` (UNSEEDED global RNG — ADR-010). A firebase `mess_cook` is scheduled `cook` most of the day (`civilian_schedules.gd:222-236`) and his stove marker IS his `working_point_pos` (`mission_generator.gd:1214-1129`), so he walks to his HOOCH and `_play_garrison` plays `chow_cook_stir` there (`civilian.gd:762-775`). `off_duty` men whose `role` names a SEAT marker (`civilian.gd:88`, `off_duty_chain`) are scheduled `sit`/`talk` and go home instead of to the seat. `gun_crew` `rest` is documented "resting AT the pit" (`civilian_schedules.gd:189`) but resolves to home. `_bt_walk_fire`/`_bt_walk_market` are fixed offsets from home (`:1399-1416`). |
| F03 | Fractional schedule windows evaluated only on integer-hour change | `civilian.gd:1223` `if int(hour) != int(last_hour)` | Mess sittings start 19.5 / 19.9 / 20.3 for 0.4 h (`civilian_schedules.gd:258-263`); `sentry` 04:30/12:45, `medic` 13:15, `mess_cook` 03:30/13:30/15:30/21:30 etc. A man can miss a whole sitting or keep an action past its window. `test_bt_civilian.gd` step 7 samples h+0.5 only; `test_group_walk.gd:45` and `test_offview_liveness.gd:51` pin `last_pick_hour` by hand. |
| F04 | Generic 1.5 m jitter applied to EVERY destination | `civilian.gd:1426-1456` `_bt_settle` | `WORK_JITTER_M 1.5` name-hash offset added to every nonzero dest, then nav-projected. Firebase stations are ALREADY exclusive per man by construction (`mission_generator.gd:1208-1212`: per-index ring of 1.8 m around the post); village work points are dealt without replacement (`:1313-1319`); LZ bunks are claim-checked (`heli_lift.gd:330-345`). Two men whose stations are 3.6 m apart can jitter toward each other by up to 3.0 m. A man at a stove / seat / cot marker is pushed 1.5 m off the prop. |
| F06 | Animation cache keyed on the coarse posture, not the action | `civilian.gd:591-616` | `want` collapses sit/talk/rest → `seated`, work/cook/fish → `stooped`; `if want == _last_clip: return`. A stationary change of action never re-dresses the man. Village branch early returns (`:637-648`) bypass `desync_loop` (`:666`). |
| F07 | Delayed chow sit-down overwrites a later state | `civilian.gd:839-845` | The `CHOW_SIT_S` timer lambda checks only `is_instance_valid(actor)` — not that he is still seated, still eating, not fleeing, not walking. |

**Protected behaviour (do not regress):** `place_for_current_hour` teleport-at-spawn and on LOD_FAR
wake (`:1341-1352`, guarded by `test_schedule_placement`); the group walk (`test_group_walk`); off-view
liveness (`test_offview_liveness`); the BT dispatch (`test_bt_civilian`); one-man-per-work-point
(his ruling 2026-08-24, memory `recon-work-point-exclusivity`); DIG spot-gate + shovel; the gun-crew
puppet capture (`gun_crew_performance.gd:187-204`, `CAPTURE_M`); the pad keep-out in `_bt_settle`;
ADR-010 determinism (same seed, same men, same sittings — name-hash offsets are the sanctioned tool,
never Time, never an unseeded roll); the fossil law (delete what you replace, same change); comment
discipline (no narration, no tombstones).

**Out of scope for this batch (later councils):** F01 placement contract + roof semantics (N2),
F05 body spacing (N3), F08 NavRouter typed results (N2), F09 dual distance systems (N4), F10/F11
identity + capture (N4), the arc/quest/Hearts-and-Minds design (0A/0B).

## The Arbiter's proposed shape (architects: READ THE CODE, then attack this)

1. **`_resolve_target` becomes role-aware.** Garrison (`is_garrison`): `work/cook/fish/walk_paddy` →
   `working_point_pos`; `sit/talk` → `working_point_pos` (a post or a seat marker is a real place;
   a hooch ring is not); `rest` → `working_point_pos` for `gun_crew`, `gun_crew_arty`, `radioman`,
   `medic`, `off_duty`, `patient`, else `home`; `sleep/walk_home` → `home`. Villagers: unchanged
   mapping, but the `randf_range` becomes a name-hash offset (deterministic). When a needed place is
   missing (`working_point_pos == ZERO`) fall back to home and count it once per man in a boot report
   (missing content is a finding, not a silent loaf).
2. **Fractional timing.** `_bt_tick` re-picks whenever `action_for(...)` differs from the current
   `scheduled_action` (pure, cheap: ~10 float compares + one string hash) — on every tick, or on a
   short poll. `last_pick_hour` is deleted (fossil law) and the two tests that pin it are moved with
   the change.
3. **Jitter only where the destination is SHARED.** `working_point_pos` is exclusive by construction
   → zero jitter (exact station). `home` is shared (`quarters[qi % size]`) → keep the name-hash
   spread there. `WORK_ARRIVE_M 0.7` stays.
4. **Animation revision.** Cache key = `want + "|" + scheduled_action` (+ role where it changes the
   chain). An `_anim_gen: int` bumps on every re-dress; the chow timer callback fires only if
   `gen` still matches and `_chow_seated` still holds. `desync_loop` applied on every village early
   return and in the chow timer (a sitting of 8 must not chew in unison).
5. **N0-lite instrument:** `tools/probe_npc_census.gd`, attached like `--roof-probe`
   (`game_flow.gd:766-772`), samples every garrison/villager at T+40 s and again after a sim-hour
   boundary: name, occupation, role, scheduled action, executed action, XZ distance to
   `working_point_pos`, XZ distance to `home`, current clip, overlap pairs (< 0.45 m XZ, < 0.5 m Y),
   and the roof test from `probe_roof_spawn.gd`. Prints a table and counts: wrong-place (a
   post-bound action > 2.0 m from the post), overlaps, roofs. Fails non-zero on any. This is the
   failing-before / passing-after gate for this batch (handoff item 4).

## Questions each architect must answer (in your file, with `file:line`)

- Where does the proposed shape break something that currently works? Name the caller.
- Which garrison occupations / marker roles would stand INSIDE a prop or on a bad surface at an
  exact (zero-jitter) station? Read `site_planner.gd` `fsb_garrison_plan` and the FSB work marker
  conventions before answering.
- What does the re-pick-on-change rule do at midnight, on `SimClock.set_time` jumps, on
  `sleep_advance`, under pause, and at 38x demo speed? Name any double-entry effect.
- Is the animation key enough, or must `role` / `is_garrison` / `_chow_seated` be in it?
- What is SACRIFICED by this batch (law 2 — no free lunches)?
- What is the single riskiest edit, and what is the cheapest probe that proves it did not regress?

**Output:** write your full analysis to `production/war_room/2026-09-13_npc_first_batch/analysis/<your_role>.md`.
Return to the Arbiter ONLY a verdict of ≤ 200 words: agree / amend / refuse per item 1–5, the single
riskiest edit, and the one thing you found that the Arbiter's read missed. No cross-talk with other
architects. Time box: 25 minutes. Read code, never the plan, when they disagree — the code wins.
