# WAR ROOM BRIEFING — Garrison men are soldiers (2026-08-04)

## The Summoner's ruling (verbatim, DECIDED — the council decides HOW, not whether)

> "Garrison men are soldiers they shoudnt be civilians. They can fight and react to
> enemies so thats not correct."

Extension, same day, verbatim:

> "and we need to make sure VC units arent lableed as civilans too in their camps."

Read together: **men who fight are soldier-class, on every side.** `Civilian` is only for
TRUE noncombatants (villagers, hearts-and-minds ADR-019). The Civilian class itself cannot
disappear — villagers are real and stay.

## Ground truth (Arbiter's pre-read, verified 2026-08-04)

- Firebase garrison men are `Civilian` (`scripts/world/civilian.gd:8-9`, extends
  CharacterBody3D) with `is_garrison = true` (`civilian.gd:94`), running the camp-life BT
  (schedules via `scripts/ai/civilian_schedules.gd`, work markers, chow three sittings).
- **They DO fight — but only through a hand-off.** `scripts/allies/garrison_defender.gd`
  (GarrisonDefender.promote/stand_down) tears the Civilian down and stands an `AllyBase`
  in his place at stand-to, demotes at dawn. Trigger is
  `field_director._garrison_stand_to()` (`_garrison_stood_to`,
  `scripts/missions/field_director.gd:985`). Outside stand-to, a garrison man IGNORES all
  noise: `civilian.gd:250-251` hard-returns `if is_garrison` in `_on_noise`. VC walk into
  the wire off-siege → the garrison keeps sweeping floors. **Verify when stand-to actually
  fires and what gap remains.**
- **Prior ruling in tension:** `heli_lift.gd:178-181` cites his 2026-07-30 ruling — heli
  pax are "garrison Civilians, not AllyBase" because AllyBase has no schedule/work-marker
  brain and the promote/demote pipeline is the one path (ADR-023). The 2026-08-04 ruling
  supersedes or refines this. Name how.
- **W-9 (DEMO_SHIP_BACKLOG, count 2):** `SeatSystem.board_squad`
  (`scripts/vehicles/seat_system.gd:332-334`) casts each body `as AllyBase` → null for
  Civilians → no MOVE_TO order → men glue-teleport aboard on the stagger timer
  (`_board_one`). The new `board_heli` clip (`heli_lift.gd:45`, shipped 2026-08-04) plays,
  but men do not walk to the bird. Civilian has NO order verb at all — its `_wander_target`
  is rewritten every BT tick from the schedule.
- **VC side:** `scripts/enemies/camp_director.gd:29` — `garrison: Array` is
  Array[EnemyBase]. VC camp life appears staged on the soldier class already
  (`enemy_base.gd:581` mirrors `_play_garrison`). AUDIT: every `Civilian.spawn` caller,
  every VC/NVA camp staging path (lazy_group.gd camp-life payload, mission_generator,
  village informer `_transform_to_vc` which swaps the MODEL but keeps the Civilian class).

## The question

How do garrison men become soldier-class without losing camp life, and what does it cost?

Options to weigh AT MINIMUM:
- (a) Migrate garrison to AllyBase (or a GarrisonSoldier subclass); port the schedule BT.
- (b) Extract a shared "person" base (move verb + combat hooks) that Civilian and AllyBase
  both extend.
- (c) Minimal bridge — give Civilian a real MOVE_TO verb + reaction hooks (react =
  trigger the EXISTING promote path, not a third combat brain); rename/retype later.
- (d) [architect's own option] — e.g. keep the promote/demote architecture and argue the
  ruling is satisfied by widening WHEN promotion fires + honest naming, or promote-on-
  boarding for W-9.

## Constraints (binding)

1. **Divergent-systems blindspot** — ~14 parallel man-systems already; do NOT mint a 15th
   lightly. ADR-023 fossil law: whatever is replaced dies in the same change.
2. **Perf** — garrison is ~40 men on a call-bound project (bodies ~94% of AI cost,
   PERF_LEDGER). AllyBase full think cost vs Civilian BT cost matters at 40 heads.
3. **Demo ships soon** (30-min one-day arc, rescoped 2026-08-03). W-9 polish vs structural
   rebuild timing. A demo-safe slice must be shippable in ~a day.
4. **TRUE civilians stay** — villagers, informers, hearts-and-minds (ADR-019).
5. Pillars: #1 believable firefights (a firebase that ignores contact violates it),
   #4 squad is the RPG (garrison is NOT the player's squad), #5 fail forward.
6. Godot 4.7 strict GDScript; no headless test suite while coding; ADR-010 determinism.

## Deliverable per architect

Full analysis to `production/war_room/2026-08-04_garrison_soldiers/analysis/<role>.md`.
Read the CODE, never the plan. Return only a SHORT verdict (≤15 lines) to the Arbiter:
chosen option, top 3 reasons with file:line evidence, what it sacrifices, demo-safe slice.
