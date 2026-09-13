# LEAD PROGRAMMER / GODOT SPECIALIST — NPC first batch (2026-09-13)

Read at HEAD: `civilian.gd` (full, 1491 lines), `sim_clock.gd`, `nav_router.gd`,
`model_actor.gd` (play/play_first/desync_loop), `gun_crew_performance.gd`,
`civilian_schedules.gd:action_for`, `site_planner.gd` (FSB_WORK_OCCUPATION,
work_dig/DIG_NEAR_M), `game_flow.gd:766-772`, `test_bt_civilian.gd` step 7,
`test_group_walk.gd:34-48`, `test_offview_liveness.gd:51-60`.

## Item 1 — `_resolve_target` role-aware

**Edit** (`civilian.gd:1355-1366`):
```gdscript
func _resolve_target(action: StringName) -> Vector3:
    if not is_garrison:
        # unchanged mapping, but deterministic offset
        if action == CivilianSchedulesS.ACTION_WALK_PADDY or action == CivilianSchedulesS.ACTION_WORK \
                or action == CivilianSchedulesS.ACTION_FISH:
            if working_point_pos != Vector3.ZERO:
                return _router.nearest_mesh_point(working_point_pos)
        var a: float = float(absi(hash(name)) % 360) * (TAU / 360.0)
        return _router.nearest_mesh_point(home + Vector3(cos(a), 0, sin(a)) * 3.0)
    # garrison
    var post_actions: Array[StringName] = [
        CivilianSchedulesS.ACTION_WORK, CivilianSchedulesS.ACTION_COOK,
        CivilianSchedulesS.ACTION_FISH, CivilianSchedulesS.ACTION_WALK_PADDY,
        CivilianSchedulesS.ACTION_SIT, CivilianSchedulesS.ACTION_TALK]
    var rest_at_post: bool = occupation in ["gun_crew", "gun_crew_arty", "radioman",
        "medic", "off_duty", "patient"]
    if action in post_actions or (action == CivilianSchedulesS.ACTION_REST and rest_at_post):
        if working_point_pos != Vector3.ZERO:
            return _router.nearest_mesh_point(working_point_pos)
        MissingContentLedger.note_once(occupation + ":" + role)  # once-per-man boot report
    return _router.nearest_mesh_point(home)  # sleep/walk_home, or missing-marker fallback
```
This is correct and matches the boot-report requirement, but **`MissingContentLedger` (or
equivalent) does not exist today** — grep for `boot report` / `note_once` returns nothing.
Item 1 quietly assumes a new small utility; scope it explicitly or the "count it once" clause
ships as a `push_warning` per-tick instead (which is a second bug: F02's own fix regressing
into log spam under the fossil/comment-discipline laws).

**What it breaks:** `place_for_current_hour()` (`:1341-1352`) calls `_resolve_target` directly
at spawn and on LOD_FAR wake — it now needs `is_garrison`/`occupation`/`role` to already be set
BEFORE first tick. Today the spawner sets those AFTER `spawn()` returns and `_placed_for_hour`
already accounts for that ordering (`:495-501`) — fine, but `_join_gun_crew()` in `build_bt()`
(`:1180-1198`) reads `working_point_pos` too, and `build_bt()` runs lazily from `_bt_tick`, i.e.
strictly after `_placed_for_hour`. No regression there, but note it for the mortar path: a
`rest`-scheduled `gun_crew_arty` man now targets his OWN `working_point_pos` (a gun_gunner/
gun_loader/etc. marker), not the pit center — `gun_crew_performance._capture` (`:198-212`)
snaps him to `civ.working_point_pos` regardless of scheduled action, so this is consistent, but
`_eligible()` (`:187-195`) gates on `CAPTURE_M` from `working_point_pos`, which item 1 does not
touch — fine.

**Test to move:** none of the four listed tests exercise `_resolve_target`'s branch logic
directly (`test_schedule_placement.gd` almost certainly does — I did not get to read it in the
time box; READ IT before landing this item, it is the one guarding `place_for_current_hour`
teleport-at-spawn, which is explicitly protected behaviour). Flagging as an open risk, not a
verified pass.

## Item 2 — fractional timing, re-pick-on-change

**Edit** (`civilian.gd:1219-1229`):
```gdscript
var picked: StringName = CivilianSchedulesS.action_for(occupation, hour, String(name))
if picked != StringName(_bt_bb.get("scheduled_action", &"")):
    _bt_bb["scheduled_action"] = picked
    _bt_bb["target_pos"] = _resolve_target(picked)
```
Delete `last_pick_hour` from `build_bt()` (`:1165`) and this block. Cost: `action_for` is a
`match` on `occupation` (string) plus one `hash(who)` — call it 200-400ns; ×~60 civilians ×
however many times `_bt_tick` runs per physics frame (once, `_physics_step_civilian` calls it
once per tick at `:547`) = well under 0.03ms/frame total. Cheap, agreed.

**Test moves, concretely:**
- `test_group_walk.gd:45` (`c._bt_bb["last_pick_hour"] = hour`) — delete the line entirely; the
  hand-set `scheduled_action` at `:46` already satisfies the new guard (it won't be overwritten
  because `action_for("farmer", hour)` at the frozen test hour returns `walk_paddy` too, per the
  comment at `:33-36` — but confirm `hour` in the test's clock matches a farmer walk_paddy window
  or the new rule WILL override the hand-set action, which is exactly the bug class the old pin
  was written to prevent, just from the opposite direction).
- `test_offview_liveness.gd:51` (`{"last_pick_hour": 3.0, "scheduled_action": &"stale"}`) — this
  test's whole point is "a live civilian must overwrite a stale pick." Under the new rule the key
  `last_pick_hour` is gone, so the dict literal just becomes dead data — replace the test's
  assertion with: seed `scheduled_action: &"stale"` (kept, since `"stale"` will never equal a
  real `action_for` result) and assert the FIRST `_bt_tick` call overwrites it. This test gets
  STRONGER under item 2, not weaker: it no longer depends on hour bookkeeping at all.
- `test_bt_civilian.gd` step 7 (`:108-117`, sampling `h+0.5` once per integer hour): I checked —
  it still passes unmodified, because it compares `civ.active_action` against
  `action_for("farmer", h+0.5)` freshly each iteration, and the new guard reacts to exactly that
  value changing. **But it does not prove F03 is fixed** — "farmer" has no sub-hour windows, so
  this test exercises only the coarse case the current code already handles. It needs a NEW test
  (or an extension) driving `mess_cook`/`sentry` sub-hour windows within one integer hour, ticking
  the BT 2-3x without advancing `int(hour)`, asserting the action changes mid-hour. Do not claim
  item 2 is proven by a green `test_bt_civilian.gd`.

## Item 3 — jitter only where shared

**Edit** (`civilian.gd:1451-1460`, `_bt_settle`): branch the jitter application on whether `dest`
came from `working_point_pos` (exclusive) or `home` (shared). Concretely, pass a `bool shared`
flag through from `_bt_tick`'s `target_pos` resolution (item 1 already knows this at resolve
time — thread it through `_bt_bb["target_shared"]` alongside `target_pos`) rather than
re-deriving it in `_bt_settle` by comparing `dest == home`, which breaks the moment a home offset
coincidentally equals a work point (rare but not impossible in a small village). Zero-jitter path
skips the `hash(name)` offset entirely and walks straight to `_router.nearest_mesh_point(dest)`.

**Breaks:** `WORK_ARRIVE_M 0.7` is unchanged per the brief, but the comment block at `:1422-1425`
states the ordering invariant "ARRIVE MUST BE SMALLER THAN JITTER, or the anti-overlap offset
cannot ever produce a step" — that invariant existed BECAUSE of jitter; removing jitter for
exclusive stations removes the reason the invariant was needed there, but it is still binding on
the shared-`home` path, where jitter survives. Comment at `:1422-1425` will read as stale for the
exclusive path once this lands — fossil law requires that comment be split or scoped in the same
change.

**Test:** none of the four named tests assert on jitter magnitude directly (I did not find
`WORK_JITTER_M` referenced in any `tests/*.gd` in the time box) — the N0-lite probe (item 5) is
therefore the ONLY guard for this item, which raises its importance: item 3 ships un-probed
without item 5 shipping in the same batch.

## Item 4 — animation cache key + `_anim_gen`

**Landmine, not a clean win.** Key = `want + "|" + scheduled_action` fixes F06's headline case
(sit/talk/rest collapsing to "seated"), but `_play_garrison` (`:699-876`) branches on THREE more
axes the new key does not carry:
- `role` (`:761` `mess_cook` branches on `role == "mess"` vs stove; `:800` `mess_hall` branches on
  `role == "queue"` vs `"chow_exit"` vs table) — same `occupation`+`scheduled_action` (`sit` or
  `work`) can select a DIFFERENT clip depending on `role` alone. Key miss: a man reassigned
  between two `role`s that both map to `work`/`sit` never re-dresses.
- `_chow_seated` (`:839-847`) — the sit-down beat is a ONE-TIME latch, not a function of
  `want`/`scheduled_action` at all; it is stateful across ticks by design. Folding it into the
  cache key is actively wrong: the key would differ before/after the latch flips even though
  `scheduled_action` never changed, forcing a spurious re-dress mid-sitting.
- `dig_ok` (`:744` `detail`+`stooped`) — two `detail` men with the same `want`/`scheduled_action`
  (`work`/stooped) but different `dig_ok` play `digging` vs `plant_seeds`. Key miss again.

**Verdict: the key must be `want + "|" + scheduled_action + "|" + role`, and `dig_ok` folded in
for the `detail` occupation specifically** (it never changes for a given man post-spawn per the
docstring at `:163-166`, so it can safely NOT be in the live key if it's truly immutable — confirm
that against `garrison_dig_ok` meta persistence across promote/stand-down, `:166`). `_chow_seated`
must stay OUT of the cache key and be handled the way it already is — a latch read at generation
time, not a component of it.

**`_anim_gen` vs `desync_loop`/crossfade — real interaction, not hypothetical:**
`play()` (`model_actor.gd:1196-1231`) already no-ops correctly (`clip == _current_clip and not
restart` → return true, no crossfade) when the resolved clip string is unchanged. The hazard is
`desync_loop()` (`model_actor.gd:1246-1256`), which `_animate()` calls UNCONDITIONALLY after every
successful `_play_garrison`/village dress (`:625`, `:666`). If the widened cache key fires a
re-dress whenever `role` or `scheduled_action` changes even though `_play_garrison` resolves to
the IDENTICAL clip string (e.g. `mess_hall`/`role=="queue"` walking between two queue sub-states
that both hit `chow_queue_walk`), `desync_loop` still runs: it reseeks the animation to a fresh
random phase (`_anim.seek(rng.randf() * len_s, true)`, `:1255`) and rerolls `speed_scale`
(`:1256`) — a visible POP/stutter on a clip that never actually changed, worse than the F06 bug
it's replacing (stale clip is invisible; a mid-loop reseek is a visible glitch). **Fix: only call
`desync_loop` when the clip STRING returned by `play_first`/`play` actually differs from the
previous frame's, not on every cache-key miss.** Gate it in `_animate()`, not inside
`_play_garrison`, since that's the one place that already knows both old and new state.

## Item 5 — remove unseeded `randf_range` in `_resolve_target`

Checked `civilian.gd` itself for other GLOBAL-stream consumers on this body's own tick path:
`:445` (`_on_noise`, FLEE/COWER coin flip) and `:1029` (`take_damage`, FLEE/COWER coin flip) are
the only other `randf()` calls in this file, and both are intentionally non-deterministic reactive
rolls (react to player fire), never inputs to ADR-010's "same seed, same men, same sittings"
guarantee. Every determinism-load-bearing draw in this file already goes through a seeded local
source: `hash(Vector2i(...))` at spawn (`:365`), a seeded `RandomNumberGenerator` for dressing
(`:408-410`), and `hash(name)`-derived offsets for jitter (`:1454`) and idle rotation (`:688`).
The codebase's own convention is "global `randf()` for reactive combat noise only, seeded local
RNG for anything ADR-010 protects" — `_resolve_target`'s `randf_range(-3,3)` for the home offset
is the ONE outlier that draws from the global stream on a deterministic path, and it's the thing
item 1/3 already replace with a name-hash offset. A repo-wide grep for `randf(`/`randi(` hits 73
files, but a scan of that list shows combat/VFX/AI-reaction files (bullet spread, muzzle flash,
suppression), not spawn/schedule/placement code — nothing else reads the global stream expecting
a specific ORDER relative to `_resolve_target`'s draw. **Safe to remove.** Confirm
`test_schedule_placement.gd` doesn't snapshot `RandomNumberGenerator`-global-seed state across a
run (I did not get to read that file — flagged, not verified).

## Re-pick-on-change: clock edge cases

- **Midnight (`sim_day` rollover):** `advance()` (`sim_clock.gd:54-58`) increments `sim_day` and
  still emits `hour_advanced`; `action_for` takes no `day` argument (`civilian_schedules.gd:28`),
  so a rollover is invisible to the schedule and item 2's guard behaves identically to any other
  hour boundary. No special case needed.
- **`SimClock.set_time` jump** (`:115-119`): fires `hour_advanced` once and burns any schedule
  events in the skipped window, but does NOT itself call anything on civilians — the NEXT
  `_bt_tick` per civilian reads the new `sim_hour` and re-picks if `action_for` differs. Fine,
  but if the jump lands mid-hour on a fractional window the OLD scheme would have missed anyway
  (`int(hour) != int(last_hour)` — a jump from 08:00 to 19.6 changes both the integer hour AND
  crosses a mess-sitting boundary), the NEW scheme picks it up correctly on the very next tick.
  Net improvement, not a regression.
- **`sleep_advance`** (`:135-156`): identical shape — one `hour_advanced` emit at the destination
  hour, all intermediate schedule entries burned unfired (`:146-150`). Civilians don't listen to
  `hour_advanced` directly (grep shows `_bt_tick` reads `sim_hour` polled, not signal-driven), so
  a civilian asleep through a `sleep_advance` simply re-picks on its next physics tick against the
  new `sim_hour` — correct, no double-entry.
- **Pause:** `_process_step` (`:39-42`) returns before `advance()` when `paused` — `sim_hour` is
  frozen, `action_for` returns the same value every tick, the new guard is a no-op (string
  compare against itself). No cost difference from today.
- **38x demo clock:** `real_to_sim_ratio` scales `delta*ratio/3600` in `advance()` — at 38x,
  1 real second ≈ 0.0106 sim-hour. `_bt_tick` runs every PHYSICS frame regardless of demo speed
  (it's not throttled by `real_to_sim_ratio`), so the re-pick check runs at the same ~60Hz it
  always did; only the RATE at which `action_for`'s result actually changes goes up (more hour/
  sub-hour crossings per real second). At 38x, a 0.4h mess window (24 real seconds at 1x) becomes
  ~0.63 real seconds — comfortably longer than one physics tick, so no window is skippable by the
  demo clock's speed alone. No double-entry effect found from clock behavior. The double-entry
  risk is entirely in item 4 (desync_loop on a same-clip re-dress), not in the clock interaction.

## Item 4 addendum — nav vs zero jitter (item 3 cross-check)

`nav_router.step()`'s 3m restake threshold (`:118`, `distance_squared_to > 9.0`) only re-issues
`agent.target_position` when the CLAMPED target moves >3m from the CURRENT stake — it does not
gate on the CIVILIAN's own position, so a stationary man settled exactly on a zero-jitter station
never re-triggers a restake (his `_bt_settle` target is constant once `dest` resolves). No
oscillation risk from the restake threshold itself. The real risk is `WORK_ARRIVE_M 0.7` combined
with the nav clamp: `_router.nearest_mesh_point(dest)` (item 3's exact-station path) can return a
point up to the navmesh's cell-height/erosion offset away from the raw marker (nav-clamped, not
identical to `dest`) — if that clamped point sits >0.7m from where `move_and_slide` actually rests
him (slope, corner rounding), `_bt_settle` reports RUNNING forever and he never reaches `SUCCESS`,
walking a small circle at 1.1 m/s (`WORK_SPEED`) around a station he can't converge on inside
0.7m. This is a real stall risk specifically INTRODUCED by removing the 1.5m jitter's slack — the
old jitter target had 1.5m+0.7m of tolerance to land inside; the zero-jitter target has only 0.7m.
**Gun crew `CAPTURE_M` (3.5m) still captures him regardless** (`gun_crew_performance.gd:38`,
`:194-195`) since 3.5m comfortably covers any sub-1m stall radius — capture is not at risk, but
the visual (a man circling his post forever) is exactly the kind of jitter the batch is supposed
to remove, just relocated from "overlapping men" to "one man near-stuck." Recommend loosening
`WORK_ARRIVE_M` to ~1.0m for zero-jitter-only destinations, or accept the nav-clamp slop into the
arrive check directly (`distance_to(nearest_mesh_point(dest))` rather than `distance_to(dest)`).

## Item 5 (the probe)

Smallest honest design: iterate `get_tree().get_nodes_in_group("civilians")` UNION
`AgentRegistry` garrison entries (civilians drop out of `"civilians"` on `_transform_to_vc`,
`:1121`, and garrison men were never guaranteed IN that group in the first place per `is_garrison`
gating throughout — confirm via `AgentRegistry.Kind.CIVILIAN` registration at spawn, `:417`, which
covers BOTH villagers and garrison uniformly and is the correct source). Per man, read: `name`,
`occupation`, `role`, `scheduled_action()` (already public, `:1240-1241`), `active_action` (the
EXECUTED action, since `_bt_settle` writes it, `:1440`), XZ distance to `working_point_pos`, XZ
distance to `home`, `actor.current_action` (public getter, `model_actor.gd:1307-1308`). Overlap:
O(n²) pairwise XZ<0.45m AND |Δy|<0.5m over ≤60 bodies is 1770 pair-checks once per sample — trivial.
Roof test: reuse `probe_roof_spawn.gd` unmodified, attach it the same way `--roof-probe` does
(`game_flow.gd:766-772`, `load(...) as GDScript`, `world.add_child(roof.new())`) rather than
reimplementing its check.

Exact headless command (pattern matches existing `--roof-probe`/`--perf-cycle` flags):
```
godot4 --headless --path C:\Users\caleb\RECONgame res://scenes/levels/demo_game.tscn \
  --npc-census-probe --demo-seed=12345 --test-save
```
(`--test-save` and `--demo-seed` per the existing flag names implied by ADR-010/the demo arc; if
`game_flow.gd` uses different literal flag spellings for seed/save, match those exactly — I did
not confirm the exact flag strings in the time box, only the attach PATTERN at `:766-772`.)

## Answers to the six questions

1. **Where does the shape break something working?** Item 4's `_anim_gen` bump interacting with
   `desync_loop` (above) — a real visual regression risk, not hypothetical.
2. **Which occupations/roles stand INSIDE a prop at zero jitter?** `detail`/`work_dig` markers
   sited within `DIG_NEAR_M` (8m) of berm/bunker/sandbag/foxhole/trench/revet/parapet meshes
   (`site_planner.gd:1236-1242`) are the likeliest candidate — "close to the berm" markers can sit
   near or inside the earthwork's own collision footprint. `hooch_sleep` (8 markers per hooch ×11
   hooches, `site_planner.gd:1327`) packs bunks tightly enough that zero jitter plus a small navmesh
   clamp could put two adjacent sleepers' hitboxes overlapping even though each has an exclusive
   marker — this is F05 territory (explicitly out of scope) but item 3 makes it MORE visible by
   removing the jitter that used to (accidentally) push men apart.
3. **Clock edge cases:** see above — no double-entry from the clock itself; the only double-entry
   risk is animation-side (item 4).
4. **Is the animation key enough?** No — needs `role` added, `dig_ok` conditionally, `_chow_seated`
   deliberately excluded (see item 4).
5. **What is SACRIFICED?** Precision for cost discipline: item 1's boot-report ledger doesn't
   exist yet and must be built or scoped down to a `push_warning` (log spam risk). Item 3 sacrifices
   the accidental anti-overlap effect jitter provided for tightly-packed shared markers (hooch
   bunks) — trading visible overlap-via-clustering for visible stall-via-zero-tolerance at exact
   stations, not a clean win, just a different failure shape that needs the arrive-radius fix
   above. Item 4 sacrifices the current "at least the pose never glitches" property for "the pose
   can now be wrong," and needs the desync-loop gate to not trade one visible bug for another.
6. **Single riskiest edit + cheapest probe:** Item 4's cache-key widen is the riskiest — it's the
   only edit that can make things worse than F06 (a visible reseek glitch instead of a stale
   clip) if `desync_loop` isn't gated on an actual clip-string change. Cheapest probe: extend the
   item 5 N0-lite census to log `(old_clip, new_clip, gen_bumped)` for one sim-hour boundary and
   assert `gen_bumped implies old_clip != new_clip` for every sample — a single boolean invariant,
   no new harness.

---

**Verdict (returned to Arbiter, ≤200 words):**

Items 1, 2, 5: AGREE, with two open items to close before landing — item 1's "boot report"
ledger doesn't exist yet (scope it or it becomes log spam), and I didn't get to read
`test_schedule_placement.gd` in the time box (READ IT before touching `_resolve_target` — it
guards the protected teleport-at-spawn behaviour).

Item 3: AMEND — zero jitter at exact stations trades "men jitter into each other" for "a man
circles his post forever," because `nearest_mesh_point`'s nav-clamp slop can exceed
`WORK_ARRIVE_M` (0.7m) with no jitter left to absorb it. Loosen arrive radius for zero-jitter
destinations or clamp-then-compare, not compare-then-clamp.

Item 4: AMEND — key must include `role` (mess_cook/mess_hall/gun_crew_arty all branch on it at
identical want+scheduled_action) and must exclude `_chow_seated` (a stateful latch, not a
schedule fact). The real landmine: `_anim_gen` bumping on every key miss will fire
`desync_loop()` even when the resolved clip STRING is unchanged, causing a visible reseek/
speed-scale pop worse than F06's stale clip. Gate `desync_loop` on actual clip-string change,
in `_animate()`.

**Riskiest edit:** item 4's cache key / `_anim_gen` interaction with `desync_loop`.

**What the Arbiter's read missed:** the `nav_router` clamp-vs-arrive-radius interaction under
zero jitter (item 3) — it's a new stall class, not covered by the brief's framing of "zero
jitter is strictly safer."
