# PROPOSAL — Godot wiring for the chow hall work markers

**Date:** 2026-08-03 · **Status:** PROPOSAL, not implemented. Caleb rules before any code lands.
**Scope:** GDScript only. No Blender, no `.blend`, nothing under `assets/` touched or proposed for
edit by this document.

> **THE NAMES ARE PROVISIONAL.** `work_queue` · `work_serve` · `work_server` · `work_trayreturn` ·
> `work_eat` are Blender-side working names awaiting Caleb's ruling
> (`production/SESSION_HANDOFF_2026-08-02_FIREBASE.md:87-89`). Every string in section 5 is a
> placeholder. The Godot dictionary keys must be changed to match whatever he rules, and there is
> exactly one place they appear (`FSB_WORK_OCCUPATION` / the new mess-line block), so the rename is
> a one-file edit. Do not implement until the names are fixed.

---

## 1. VERIFICATION OF THE BRIEF — what was right, what was wrong

Every line below was read out of the code today.

| Claim in the brief | Verdict | Pointer |
|---|---|---|
| `site_planner.gd` reads `work_*` empties out of the firebase GLB | **TRUE** | `scripts/world/site_planner.gd:877-917` (`_ensure_fsb_markers`) |
| "Contract at roughly `:493-494` — node name prefix `work_`, plus a glTF `work_type` extra" | **HALF WRONG — and it is a live doc fossil.** The comment at `:493-494` is orphaned: the function immediately below it at `:498` is `_stable_animals`, which has nothing to do with work markers. Worse, **`fsb_main_v3.glb` carries ZERO `extras` on its 198 `work_` nodes** (measured off the glTF JSON today), so the `work_type` extra half of that "contract" is fiction for the firebase. Only the node NAME is ever read. | comment `site_planner.gd:493-494`; wrong function at `:498`; the real name-only parse at `:906-909` |
| "Collection loop around `:561-568`, `wtype.contains("cook")` collapses to `cook`" | **TRUE but IRRELEVANT to the firebase.** That is `_collect_stations` (`:557-568`), the **village** path, called only from `:302` and `:355`. The firebase never goes through it. The `contains("cook")` collapse and the `get_meta("work_type", …)` fallback do **not** apply to the chow hall. | `site_planner.gd:557-568`, callers `:302`, `:355` |
| `work_type` → occupation map "around `:819-835`" | **TRUE** — `FSB_WORK_OCCUPATION`, `site_planner.gd:823-835` | |
| `queue`/`serve`/`server`/`trayreturn`/`eat` have no entry → fall through to `off_duty` | **TRUE** | default at `site_planner.gd:1002` (`FSB_WORK_OCCUPATION.get(wt, "off_duty")`) |
| `FSB_WORK_PRIORITY` "~`:841-846`" | **TRUE** — `site_planner.gd:841-846`, 18 entries | |
| **"`FSB_GARRISON_MAX_MEN` is 24 … budget = 7"** | **WRONG. It is 40, and the budget is 23.** Raised 24→40 on 2026-07-31 after an A/B FPS measurement (`site_planner.gd:850-853`; `production/DEMO_SHIP_BACKLOG.md:338`). `FSB_WORK_POST_CAP` was raised 12→24 in the same change (`:863`). Curated men = 17 (recount of `FSB_GARRISON_POSTS`, `:793-807`: 1+1+1+1+1+2+1+1+1+1+2+2+2). So `clampi(40 − 17, 0, 24)` = **23**. The clamp does not bind. | `site_planner.gd:936` |
| "Posts are chosen round-robin BY TYPE, not positionally" | **TRUE** | `site_planner.gd:991-1011` |
| "The new markers in the scene: 24 × `work_eat`, plus …" | **TRUE OF THE `.blend`, FALSE OF THE GAME.** The shipped `fsb_main_v3.glb` carries **198 `work_` nodes across exactly 20 types and not one chow-hall marker** — no `eat`, no `queue`, no `serve`, no `server`, no `trayreturn` (measured off the glTF node list today). The chow hall has not been exported. Godot cannot consume markers that are not in the file. | `assets/…/fsb_main_v3.glb`, glTF node names |
| "Marker facing is the +X axis … NOT +Y" | **TRUE, and it survives the export unchanged.** The convention is stated in the generator itself (`tools/build_chowhall_dining.py:5`, `tools/gen_chowhall_crew.py:406-410`). Blender→glTF axis conversion maps Blender local **+X → glTF/Godot local +X**, so the same axis is correct on both sides. **Caveat:** the 30 existing perimeter markers (`work_watch` / `work_mg` / `work_guard`) show **no correlation between any local axis and "outward from compound centre"** (mean dot ≈ ±0.16 for ±X, ±0.05 for ±Z — noise). Their yaws are effectively arbitrary. So +X is the convention *for the chow-hall markers as authored*, not something the shipped marker set can corroborate. Pin it with a probe. | see §7 R6 |

### One more thing the brief did not know, and it changes the whole risk picture

**Godot's glTF importer rewrites Blender's `.001` duplicate suffix to `_001`, not to `001`.**
Verified by decompressing the imported scene (`.godot/imported/fsb_main_v3.glb-6138….scn`, RSCC/Zstd)
and reading the node-name table: 198 distinct `work_*` names, **zero containing a dot**, e.g.
`work_watch`, `work_watch_001` … `work_watch_020`. That is why the `_<digits>` strip at
`site_planner.gd:906-909` works and why the type histogram is 20 and not 198. Worth recording,
because the comment at `:905` asserts it without evidence and it is the single point on which the
entire round-robin depends.

---

## 2. WHAT EXISTS — the machinery a mess line would have to use

**Spawn path (one hop, no indirection):**
`SitePlanner.fsb_garrison_plan(center)` (`site_planner.gd:922-1020`) returns
`{posts: [{pos, occupation, men, …}], quarters: [Vector3]}`. Its only caller is
`MissionGenerator._build_firebase_garrison` (`scripts/missions/mission_generator.gd:884-948`), which
spawns a `Civilian` per man, writes `occupation` and `working_point_pos`, groups it
`firebase_garrison`, and calls `build_bt()`.

**Behaviour path:** `Civilian._bt_tick` (`scripts/world/civilian.gd:652-669`) re-reads
`CivilianSchedules.action_for(occupation, sim_hour)` **once per sim hour** (`:659-663`), resolves a
target via `_resolve_target` (`:789-796`), and every scheduled action funnels into the single
`_bt_settle` (`:865-881`) — walk to the target, then hold. `_animate` (`:344-405`) picks a *shape*
(`stooped`/`seated`/`walking_unarmed`), and `_play_garrison` (`:438-501`) picks the actual clip
chain by `occupation`.

**So an occupation is three things and only three things:** a row in `FSB_WORK_OCCUPATION`, a `match`
arm in `CivilianSchedules.action_for`, and a clip branch in `Civilian._play_garrison`.

### Does the occupation system support a multi-station traversal?

**No. Every occupation is exactly one point.** `Civilian` holds a single `working_point_pos`
(`civilian.gd:100`), and `_resolve_target` (`:789-796`) can return only that point or `home ± 3 m`
jitter. There is no station list, no ordered route, no per-station dwell, no progression state.
`_bt_settle`'s own header (`:857-864`) records that it replaced seven byte-identical freezes — its
whole contract is *walk to one place and stop*.

**But there is a precedent for exactly this shape, and it is the right one to copy: `LitterTeam`
(`scripts/world/litter_team.gd`).** It is a five-phase traversal (LOAD → CARRY → UNLOAD → RETURN →
WAIT, `:29`, `:120-144`) over three bodies and two anchors. It works by taking the bodies **out** of
the BT: `Civilian.puppet = true` (`civilian.gd:113`, set at `litter_team.gd:67-69`) makes
`_physics_process` hard-return (`civilian.gd:289-291`) and suppresses `_animate` (`:347-348`), and
the driver writes position, yaw and clip itself (`litter_team.gd:169-192`). Its header says why in
one line: *"Nothing in this project phase-locks two actors."*

The plan side already carries the precedent too: `fsb_garrison_plan` seeds the aid station as an
explicit **block** rather than letting the rotation find it (`site_planner.gd:964-990`) — it emits
`medic` + `patient` posts, charges `taken = 2` against the budget, and **erases `medic` from
`type_order`** so the rotation cannot double-seat it (`:978`).

**Verdict: a mess line does not need new engine machinery. It needs the LitterTeam pattern
(a driver that owns its bodies) plus the aid-station pattern (a seeded plan block that erases its own
types from the rotation).** Both already exist and are already read by the shipping code path.

### The time-of-day hook already exists

`SimClock` (`scripts/autoload/sim_clock.gd`) — `sim_hour`, `hour_advanced`, `time_period_changed`.
`Civilian._bt_tick:659` already re-picks the action on every integer-hour crossing, and
`CivilianSchedules.action_for` already gates behaviour by hour for eleven occupations
(`civilian_schedules.gd:25-254`). `sentry` vs `sentry_night` (`:104-132`) is the working proof that
one marker set can be manned or empty depending on the clock. **No new day-cycle plumbing is needed.**

Boot hour is one of four (`mission_generator.gd:248-255`): DAWN 6.0 · DAY 10.0 · DUSK 18.0 ·
NIGHT 22.0. **Two of the four land on a meal.** Clock rate is `real_to_sim_ratio = 60.0`
(`sim_clock.gd:17`), i.e. **one sim hour ≈ one real minute** — see the tradeoff in §5.

---

## 3. WHAT IS MISSING — the readiness gates, in order of who blocks whom

1. **The markers are not in the GLB.** 198 work markers, 20 types, no chow types. The chow hall lives
   in `firebase_v3.1_WIP_chowline.blend` / `…_RECOVERED_medical.blend` and has never been exported.
   And `tools/gen_firebase_v3.py:912` still defaults to the **stale** `firebase_v3.1.blend`
   (`SESSION_HANDOFF_2026-08-02_FIREBASE.md:14-19`) — an export today would silently ship the old
   firebase. **Fix that default before any export, or this whole proposal wires to nothing.**
2. **The clips are not in the library.** `assets/shared/anim_library.glb` carries **163 animations and
   zero `chow_*`** (measured). The nine station clips
   (`chow_cook_stir`, `chow_cook_check`, `chow_cook_prep`, `chow_serve_ladle`, `chow_tray_hold`,
   `chow_queue_step`, `chow_queue_walk`, `chow_eat_seated`, `chow_tray_dump` —
   `tools/make_chowhall_anims.py:324-343`) exist only in
   `assets/shared/chow_anim_workbench.blend`, awaiting Caleb's scrub
   (`make_chowhall_anims.py:5-6`).
3. **The props are not exported.** `fb_food_tray` / `fb_tray_stack` are not in the firebase `kit/`
   directory. Neither is `fb_litter` — which is why `LitterTeam.available()`
   (`litter_team.gd:45-46`) returns **false today** and the litter team has never once seeded in
   game. That is the existing, working gate pattern, and the mess line should copy it.
4. **The names are unruled.** §0 banner.

**Consequence: this is a design-and-sequence proposal, not a ship-this-week item.** Items 1–3 are
Blender/pipeline work owned by other agents. The Godot work is small and should land *after* them,
behind an `available()`-style gate so it is inert until they do.

---

## 4. THE BUDGET PROBLEM — what actually happens if `eat` is added naively

The brief expects "24 men spawn". **That is not what happens, and the truth is worse in a quieter
way.** Trace of `fsb_garrison_plan` as it runs today:

- `work_budget = 23` (`:936`).
- Aid station seeds `medic` + `patient`, `taken = 2`, `medic` erased from `type_order` (`:969-978`).
- Litter block skipped — `LitterTeamScript.available()` is false, no `fb_litter.glb` (`:986`).
- `type_order` = 17 remaining `FSB_WORK_PRIORITY` types + `gun` + `mortar` (present in the GLB but
  absent from the priority list, so appended in `seen_order`, `:960-962`) = **19 types**.
- Round 0 seats one man per type: `taken = 21`. Round 1 seats `dig`, `wash`: `taken = 23`. **Stop.**

**The round-robin structurally forbids 24 men at one type.** `while taken < work_budget` with an
inner `for` over every type (`:992-1011`) means no type can get a second man until every type has a
first. With 23 budget against 19 types, only the two highest-priority types ever reach `round_i = 1`.

So add five chow types naively and this is the result:

- `type_order` becomes **24**, budget is still **21** after the aid station. **Three types get ZERO
  men.** Which three depends on `seen_order`, which is the marker list sorted by world X then Z
  (`:911-916`) — i.e. **on where the chow hall happens to sit on the map.** Non-obvious, seed-stable,
  and silently destructive: three jobs that are manned today go dark, and the cause is a building
  being added on the other side of the compound.
- The chow hall itself gets **at most one man per chow type, at most 5 men, possibly 0**, against 29
  authored stations.
- Every one of them is `off_duty` (`:1002` default), so `_play_garrison:443-448` puts him in
  `OFF_DUTY_CHAINS` — **standing and smoking in the serving line.**
- `mission_generator.gd:923-925` spreads him and `_bt_settle` jitters him another 1.5 m
  (`civilian.gd:852-853, :871-872`), so he is **not on the bench, he is beside it.**
- `Civilian` never writes rotation — grep for `look_at` / `rotation.y` / `global_rotation` in
  `civilian.gd` returns **zero hits**. So he faces wherever the spawn left him. **The +X facing
  contract has no consumer at all.**

**Net: one man standing next to a bench, smoking, facing a wall, and three unrelated firebase jobs
silently unmanned.** That is a worse outcome than the current nothing, because it *looks* wired.

---

## 5. RECOMMENDED DESIGN

### R1 — The mess line is a SEEDED BLOCK, not a rotation participant

Add a block to `fsb_garrison_plan` alongside the aid station (`site_planner.gd:964-990`), same shape:
emit posts explicitly, charge `taken` once, and **erase every chow type from `type_order`** so the
round-robin can never double-seat a chow marker.

```
const FSB_MESS_TYPES: Array[String] = ["cook", "mess", "queue", "serve", "server",
    "trayreturn", "eat"]          # PROVISIONAL NAMES — awaiting his ruling
const FSB_MESS_CREW: int = 8      # 2 cooks + 2 servers + 4 in the line/at tables
```

`FSB_MESS_CREW` is **the one dial**, exactly as `FSB_WORK_POST_CAP` is for the rotation. 8 of 23 is a
third of the work budget on one building — see §6.

The block emits **one post with `men: 8`** carrying the whole marker set, not eight independent
posts. The plan dict already supports extra keys (`ward` on the litter post, `:989`), so it carries
its own station lists:

```
{"pos": <chow hall anchor>, "occupation": "mess_line", "men": FSB_MESS_CREW,
 "queue": [...], "serve": [...], "eat": [...], "cook": [...], "return": [...]}
```

**Why a block and not seven `FSB_WORK_OCCUPATION` rows:** seven rows means seven rotation entries
competing with `dig`/`wash`/`watch` for single men, which is the §4 failure. One block is one budget
decision, taken once, visible in one constant.

### R2 — The traversal is a driver, not a BT extension

New `scripts/world/mess_line.gd`, modelled directly on `litter_team.gd`. Phases:
`QUEUE → SHUFFLE → SERVED → CARRY → SIT → EAT → BUS → RETURN`. Each man is a `puppet` Civilian
(`civilian.gd:113`), so the BT, `_animate` and gravity all stand down and the driver owns position,
yaw and clip — the pattern `litter_team.gd:67-69, :169-192` already proves in this codebase.

**Do NOT extend `_bt_settle` into a multi-station walker.** Its header
(`civilian.gd:857-864`) records that it exists *because* seven divergent settle implementations
collapsed twelve scheduled actions into four behaviours. Adding a station-sequence branch to it
re-opens that exact wound, and it would fire for every occupation, not just the mess line.

**Progressive tray fill** (Caleb's idea, and what the footage shows —
`SESSION_HANDOFF_2026-08-02_FIREBASE.md:96-99`) is a `visible` toggle on `food_01..04` as the man
advances a station. The driver owns the tray node the way `LitterTeam` owns `_litter`
(`litter_team.gd:113-117`).

### R3 — The time-of-day gate is the SCHEDULE, and it is already built

Add one `match` arm to `CivilianSchedules.action_for` (`civilian_schedules.gd:26`):

```
"mess_line":
    # THREE MEALS. Off-hours the man is a working-party body, not a statue in an empty tent.
    if sim_hour >= 5.5 and sim_hour < 7.5:  return ACTION_WORK   # breakfast
    if sim_hour >= 11.5 and sim_hour < 13.0: return ACTION_WORK  # dinner
    if sim_hour >= 16.5 and sim_hour < 18.5: return ACTION_WORK  # supper
    ...otherwise WALK_HOME / REST / SLEEP
```

The driver un-puppets its men outside a meal window and hands them back to the BT; the BT walks them
to `home` (their quarters, assigned round-robin at `mission_generator.gd:940-944`). **`sentry` vs
`sentry_night` is the working proof of this pattern** (`civilian_schedules.gd:104-132`), and it costs
zero new machinery.

This solves the budget from the other end too: the mess crew are not eight men who only ever stand in
the chow hall, they are **eight men who eat and then go back to work** — so the building's cost is
amortised across the day instead of being eight permanently parked bodies.

**Named tradeoff:** at `real_to_sim_ratio = 60.0`, a two-hour meal window is **two real minutes**. A
player who boots at DAY (10.0) or NIGHT (22.0) — half the boots — walks past an empty chow hall and
the whole build is invisible to him. Two answers, both cheap, **his call**:
 **(a)** widen the windows (breakfast 05:00–08:00, dinner 11:00–14:00, supper 16:00–19:00 — ~9 of 24
 hours occupied), or **(b)** leave a permanent skeleton crew (1 cook + 1 man eating) outside the
 windows and surge to 8 during them. **Recommend (b) plus modestly widened windows:** a kitchen with
 one man scrubbing a range at 22:00 is more authentic than a widened lunch, and it guarantees the
 building never reads as abandoned.

### R4 — Facing needs a new capability, and it is three lines

`_fsb_work_markers` stores only `[origin, type]` — **the authored rotation is discarded at
`site_planner.gd:910`.** Store the yaw:

```
_fsb_work_markers.append([t2.origin, wt, atan2(t2.basis.x.x, t2.basis.x.z)])
```

…using the marker's local **+X** projected to XZ, per the generator's stated convention
(`tools/build_chowhall_dining.py:5`). Consumed only by the mess-line driver, which writes
`actor.global_rotation.y` — **the ModelActor, never the body** — exactly as
`litter_team.gd:190-192` does.

**Do not retrofit facing onto the 20 existing types.** Their authored yaws are noise (§1), so a
global change would spin 190 men to no purpose and would be indistinguishable from a regression.

### R5 — Gate the whole feature on its assets

```
static func mess_line_available() -> bool:
    return _fsb_has_type("eat") and _anim_library_has("chow_eat_seated")
```

Same shape as `LitterTeam.available()` (`litter_team.gd:45-46`). Until the export and the clip merge
land, `fsb_garrison_plan` skips the block entirely and the 23 work posts spend exactly as they do
today. **This is what makes the Godot side safe to write before the art side ships**, and it is the
established pattern in this codebase, not an invention.

---

## 6. TRADEOFFS NAMED

| We get | We pay |
|---|---|
| A legible chow hall: a queue that moves, a counter that serves, tables with men at them | **8 of 23 work posts (35%) on one building.** At the ceiling of 40 that money comes out of `dig`/`wash`/`water`/`burn`/`pad` — the working party thins visibly elsewhere in the compound. |
| Zero new schedule machinery; the meal window is `sentry_night`'s pattern reused | The chow hall is **empty for ~15 of 24 sim hours** even with widened windows. Half of boots see it empty unless R3(b) skeleton crew is adopted. |
| Traversal without touching `_bt_settle`, so no regression risk to the other 11 occupations | A **second** puppet driver in the codebase. `LitterTeam` + `MessLine` is now a pattern, and a pattern with two instances and no shared base is how divergent systems start here. Accept it for two; refactor to a shared `PuppetPerformance` base at three. |
| Facing finally consumed, per the authored convention | A third position-writing path (BT / LitterTeam / MessLine). Puppet bodies are invisible to anything that reasons about `velocity` or the nav mesh. |
| `available()` gate lets the Godot side land ahead of the art | A gated feature is a feature nobody has seen run. It must be **verified in a playtest by Caleb** before it counts as done (ADR-015), and until then it is exactly the kind of built-but-unwired code the FOSSIL LAW is about. Put a date on it. |

---

## 7. RISKS

**R1 — `tests/test_firebase_garrison.gd:13-16, :141-142` will fail on any new occupation string.**
`GARRISON_OCCUPATIONS` lists seven occupations and the probe `_fail`s on anything else. Adding
`mess_line` trips it. **And it is already stale:** the plan can emit `medic`, `patient`, `detail` and
`litter` (`site_planner.gd:975-976, :989`, `:1002` via `FSB_WORK_OCCUPATION:828-832`), none of which
are in that list; `litter` men also get no `working_point_pos`, which trips `:145-146` as well. That
probe is measuring a garrison that stopped existing on 2026-07-30. **Fix it in the same change** —
NO MORE DRIFT.

**R2 — Spawning 24 men. Structurally impossible via the rotation** (§4), but **entirely possible via
a seeded block**, which is the mechanism being proposed. `FSB_MESS_CREW` is the guard, and
`fsb_garrison_plan` must assert `taken + FSB_MESS_CREW <= work_budget` before emitting, and skip the
block otherwise — the aid station already does this (`site_planner.gd:970`, `:986`).

**R3 — Breaking the garrison ceiling.** `men: 8` on one post dict is counted correctly by the
`work_budget` arithmetic *only if* `taken` is incremented by 8, not 1. Getting that wrong ships 47
men against a documented ceiling of 40 and turns `test_firebase_garrison.gd:118-119` red. This exact
bug has happened before: `site_planner.gd:859-862` records the compound reaching **29 men against a
documented ceiling of 24** because two caps were held as independent constants.

**R4 — Double-seating.** If the chow types are added to `FSB_WORK_OCCUPATION` *and* seeded as a
block, the rotation will put a second man on the same markers. **Erasing the types from `type_order`
is mandatory, not optional** — the aid station's `type_order.erase("medic")` (`:978`) is there for
exactly this reason.

**R5 — Precedent: `gun` / `mortar` map to nothing ON PURPOSE.** `site_planner.gd:821-822` states it:
`mission_generator._place_firebase_mg` (`:955-961`) spawns a mannable M60 per `gun_crew` post, and 20
of them "is not a firebase, it is a joke." **`eat` is the same class of trap** — a marker type whose
naive consumer scales with marker count. The 24 `work_gun` posts and 24 `work_bunker` posts the
Blender side added on 2026-08-02 (`SESSION_HANDOFF_2026-08-02_FIREBASE.md:48, :60-64, :150-152`) are
**two more unmapped types arriving in the same export**, which will push `type_order` from 19 to 21
before a single chow type is added. Budget the export as a whole, not the chow hall alone.

**R6 — The facing axis is asserted, not corroborated.** The generator says +X
(`build_chowhall_dining.py:5`); the shipped markers cannot confirm it (§1). If the Blender agents
change the convention, Godot spins every seated man to face a wall and nothing fails loudly. **Land a
probe** that asserts, over the exported chow markers, that the two `work_eat` markers flanking a
table have +X axes that are roughly anti-parallel and point across the table. That is a shape the
data can prove.

**R7 — Ground height.** `mission_generator.gd:933` overwrites the marker's authored Y with
`world.surface_y(pos) + 0.5`, discarding the bench height the marker carries. That is *correct* for
feet-on-floor seated clips (`chow_eat_seated` derives from `sitting_idle_b`, authored against a
0.46 m bench — `make_chowhall_anims.py:27-30`), **but only if `surface_y` returns the chow-hall
floor.** The mound became the walkable ground on 2026-07-29 and a post seated on terrain instead sits
1.5–5.3 m under the surface (`mission_generator.gd:927-932`). A new structure with a new floor is
precisely the condition that produced that bug. **Measure `surface_y` at a `work_eat` marker before
trusting it.**

**R8 — `_bt_settle`'s 1.5 m hash jitter (`civilian.gd:852-853, :871-872`) and
`mission_generator.gd:923-925`'s 1.8 m index spread both destroy exact seating.** The puppet path
(R2) sidesteps both by construction. Any implementation that keeps the men on the BT will put them
beside the bench, not on it.

**R9 — Static marker cache.** `_ensure_fsb_markers` early-returns on a non-empty `_fsb_markers`
(`site_planner.gd:878-879`) and the cache is `static`. A new type list computed once per process is
fine, but a test that stubs marker data must clear it or it will read the previous world's set.

---

## 8. IMPLEMENTATION ORDER — do not start before §3's gates and Caleb's naming ruling

| # | Change | Anchor |
|---|---|---|
| 0 | **BLOCKED ON HIM.** Ruling on `work_queue` / `work_serve` / `work_server` / `work_trayreturn` / `work_eat`. Every string below is provisional. | `SESSION_HANDOFF_2026-08-02_FIREBASE.md:87-89` |
| 0b | **BLOCKED ON ART.** Export the chow hall from the truth-source `.blend` (after fixing the stale default) + merge the nine `chow_*` clips into `anim_library.glb` + export `fb_food_tray`/`fb_tray_stack`. Not this proposal's work. | `tools/gen_firebase_v3.py:912`; `make_chowhall_anims.py:324-343` |
| 1 | **Fix the doc fossil.** The `work_*` contract comment sits above the wrong function and claims a `work_type` glTF extra that does not exist in the firebase GLB. Move it to `_ensure_fsb_markers` and correct it. Record that the importer maps `.001 → _001` (verified). | `site_planner.gd:493-497` → `:877` |
| 2 | **Un-stale the garrison probe.** Add `medic`, `patient`, `detail`, `litter` to `GARRISON_OCCUPATIONS`; exempt `litter` from the `working_point_pos` assertion. Do this first so step 6 has a truthful gate. | `tests/test_firebase_garrison.gd:13-16, :141-142, :145-146` |
| 3 | **Carry the yaw.** Append the +X-derived yaw as a third element of each `_fsb_work_markers` entry. Read-only for now — no consumer yet, so no behaviour change. | `site_planner.gd:910` |
| 4 | **`mess_line_available()`** — assert the chow marker types are present in the GLB *and* `chow_eat_seated` is in the animation library. Copy the shape of `LitterTeam.available()`. | new, beside `site_planner.gd:877`; pattern at `litter_team.gd:45-46` |
| 5 | **Seed the block.** `FSB_MESS_TYPES` + `FSB_MESS_CREW` consts; emit the `mess_line` post with its station lists; `taken += FSB_MESS_CREW`; **erase every chow type from `type_order`**; guard on `taken + FSB_MESS_CREW <= work_budget` and on `mess_line_available()`. | `site_planner.gd:963-990` (beside the aid station), consts near `:841` |
| 6 | **Schedule arm** `"mess_line"` — three meal windows, plus the R3(b) skeleton crew if he rules that way. | `civilian_schedules.gd:26` |
| 7 | **`scripts/world/mess_line.gd`** — the puppet driver. Phases, per-station dwell, `actor.global_rotation.y` from the marker yaw, tray `food_01..04` visibility per station, un-puppet outside the meal window. | new; pattern `litter_team.gd` in full |
| 8 | **Spawn hookup** — recognise `occupation == "mess_line"` and hand the men to the driver whole, exactly as the `litter` branch does; `continue` past the per-man station spread so nobody gets a `working_point_pos` or a BT. | `mission_generator.gd:898-915` |
| 9 | **Clip branches** in `_play_garrison` for the mess crew, guarded so a missing `chow_*` degrades to `cargo_unload_stack` / `sitting_idle_b` rather than a weapon pose. | `civilian.gd:438-501` |
| 10 | **Probes:** the +X facing assertion (R6); `surface_y` at a `work_eat` marker (R7); a garrison headcount that still reads `FSB_GARRISON_MAX_MEN` from the planner and never restates it (R3). | `tests/test_firebase_garrison.gd:18-20` |
| 11 | **Caleb playtests it.** ADR-015 — not discharged by a probe, not by an agent's reading. | |

---

## 9. OPEN QUESTIONS FOR HIM

1. **Marker names.** `work_queue` / `work_serve` / `work_server` / `work_trayreturn` / `work_eat` —
   ruled as-is, or renamed? Note the handoff describes the serve station as `work_mess`
   (`SESSION_HANDOFF_2026-08-02_FIREBASE.md:85`) while the brief lists both `work_serve` **and**
   `work_server`. Those are two different types to the round-robin and one of them is probably a typo.
2. **`FSB_MESS_CREW` = 8?** That is 35% of the work-post budget on one building, taken from the
   working party. Higher makes the chow hall the liveliest place in the compound; lower makes it a
   detail. §6 names the cost either way.
3. **Empty-hours policy** — R3(a) widened windows, or R3(b) permanent skeleton crew + surge?
   Recommendation is (b), because half of boots land outside any meal window and one man scrubbing a
   range at 22:00 is truer than a three-hour lunch.
4. **Do `work_bunker` (24) and `work_gun` (24) get occupations in the same pass?** They arrive in the
   same export and add two more types to a budget that is already fully spent. If they stay unmapped
   they become 48 `off_duty` men's worth of rotation entries competing with the chow hall.
