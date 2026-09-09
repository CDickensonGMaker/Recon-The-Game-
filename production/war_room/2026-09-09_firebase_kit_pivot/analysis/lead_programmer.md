# LEAD PROGRAMMER — independent sight

**Council:** 2026-09-09 firebase kit pivot · **Assignments:** (A) the ladder/sandbag wedge, (B) NPCs stacking at work points
**Method:** static analysis + a pure-python glTF probe against the shipped GLB. **No engine was launched. No game file was written.**
Probe scripts live in the session scratchpad (`glb_ladders.py`, `glb_tri.py`), not in the repo.

Measured against `assets/world/building models/structures/firebase/fsb_main_v3.glb` as it stands at 2026-09-09 13:34.
Player capsule read from `scenes/player/player.tscn:9-11,18-20` — **radius 0.40 m, height 1.80 m, origin at the feet.**
Canon character height is 1.7132 m (ADR-002 `production/adr/ADR-002*:28`, `scripts/visuals/model_actor.gd:16`); the player's
*collision* capsule is 1.80 m, so every clearance below is computed against 1.80/0.40, not against the art contract.

---

# A. "I got stuck between a ladder and sandbags getting off the ladder"

## A0. VERDICT UP FRONT

**Classification: (a) bug, known cause — with a slice of (c).**
The dismount and the step-off write the player's position with **no clearance test of any kind**, and the constants they use
put him **0.31 m inside the tower's own collider at the bottom of three of the four ladders in the game**. Every concave
shape in the firebase is then forced double-sided, so there is no surface to slide out through. The player is the only
actor in this game with no unstick watchdog.

**REFUTED: "the ladder is placed too close to sandbags in the asset."** No sandbag mesh of any family is within 3.9 m of
any ladder waypoint. Measured, all four ladders, both ends. **This is not an asset defect and no .blend needs touching.**

## A1. The ladder system — complete inventory

- `scripts/world/ladder.gd` — the whole system, 145 lines. Built from marker pairs, no scene work.
- `scripts/player/player.gd:1397-1462` — the climb state (`is_climbing`), a third movement state alongside
  `is_seated` / `is_manning_mg`.
- `scripts/player/player.gd:1644-1647` — `_physics_process` returns early while climbing, so `move_and_slide()`,
  gravity, crouch and lean are all off the table on a rail.
- `scripts/world/site_planner.gd:1706-1710` — `Ladder.build_from_markers(root)` runs AFTER the GLB root is seated.

**There are exactly four functional ladders in the entire game.** I grepped every `.glb` under `assets/` for the
`ladder_bottom` marker string: `fsb_main_v3.glb` is the only hit. The four are the guard-tower ladders
(`fb_tower_i`, `.001`, `.002`, `.003`). `scripts/world/tunnel_room.gd:73-87` builds a decorative `ladder` MeshInstance
and a `ladder_point()` — that is the tunnel exit interact, not a `Ladder`, and it is not in play here.

## A2. What happens at dismount — exactly

Three places write the player's position during a climb. **None of them tests the destination.**

| # | site | what it writes | clearance test |
|---|---|---|---|
| 1 | `player.gd:1427-1433` `_snap_to_rail()` | `global_position.x/.z = ladder.rail_point(y)` — called on mount (`:1413`) and **every physics frame** (`:1461`) | **none** |
| 2 | `player.gd:1449-1451` bottom step-off | `global_position.y = bottom_y()`, then `stop_climbing()` | **none** |
| 3 | `player.gd:1454-1457` top-out | `global_position = ladder.dismount_point()`, then `stop_climbing()` | **none** |

The two geometry functions, `scripts/world/ladder.gd:126-136`:

```gdscript
func rail_point(y: float) -> Vector3:          # :126
    var p: Vector3 = _bottom + _face * FACE_OFFSET   # FACE_OFFSET = 0.55  (:21)
    p.y = y
    return p

func dismount_point() -> Vector3:              # :133
    var p: Vector3 = _top - _face * DISMOUNT_IN      # DISMOUNT_IN  = 0.95  (:23)
    p.y = _top.y + DISMOUNT_LIP                      # DISMOUNT_LIP = 0.30  (:22)
    return p
```

Three hardcoded constants, **authored for the CatacombsOfGore ladder this file was ported from**
(`ladder.gd:4-5` says so explicitly), and never re-measured against this tower. There is no forward eject impulse
— `stop_climbing()` (`player.gd:1417-1424`) explicitly zeroes velocity — so whatever spot the constants name is
the spot the player is left standing in, and the very next frame `move_and_slide()` (`player.gd:1666`) has to
make sense of it.

**Collision layers.** Player is `collision_layer = 2`, `collision_mask = 5` (`player.tscn:14-15`) — he tests
against **layer 1 (world) and layer 3 (enemies)**. So the firebase colliders block him, and so does any live
enemy body. Nothing in the climb path consults either mask.

**There is no "let go of the ladder" input.** The only two exits from `is_climbing` are reaching the bottom with
S held (`:1449`) and reaching the top with W held (`:1454`), plus the ladder being freed (`:1438-1440`). Once
`stop_climbing()` deposits him in geometry, he has no verb that gets him out.

## A3. MEASURED — the actual world geometry

Pure-python glTF parse; world transforms composed down the node tree; capsule-axis-to-triangle distance against
every `*-colonly` mesh (the `-colonly` suffix is what Godot turns into collision, and
`fsb_main_v3.glb.import` confirms `root_scale = 1.0` / `use_name_suffixes = true`, while
`scenes/world/firebase_main.tscn` adds no transform — so GLB coordinates are the seated model's local
coordinates 1:1, and every relative distance below is exact).

**Clearance = distance from the capsule's axis to the nearest collider triangle. Anything below 0.40 m is
penetration.**

| ladder | TOP dismount clearance | BOTTOM step-off clearance | verdict |
|---|---|---|---|
| `ladder_bottom` (tower 0) | 0.470 m *(0.07 m of margin)* | **0.094 m — PENETRATING by 0.31 m** | `fb_tower_i_1580-colonly` |
| `ladder_bottom.001` | 0.470 m *(0.07 m)* | **0.094 m — PENETRATING by 0.31 m** | `fb_tower_i_1581-colonly` |
| `ladder_bottom.002` | clear (no collider within 3.5 m) | **0.276 m — PENETRATING by 0.12 m** | `fb_terrain_mound_1474-colonly` |
| `ladder_bottom.003` | 0.470 m *(0.07 m)* | **0.094 m — PENETRATING by 0.31 m** | `fb_tower_i_1583-colonly` |

**The bottom step-off is inside the tower on three of the four ladders, every time, deterministically.**
It is not a rare wedge — it is baked into `FACE_OFFSET = 0.55` versus a 0.40 m capsule and this tower's
leg/bracing geometry.

Sweeping `FACE_OFFSET` proves no small tweak rescues it — the obstruction is ~1 m deep along the facing:

```
FACE_OFFSET   0.55   0.70   0.85   1.00   1.20   1.50
clearance     0.09   0.00   0.00   0.09   0.29   0.52    (tower 0; .001/.003 identical to 0.03 m)
```

`0.00` means the capsule axis is **on** a triangle. You would have to push him out to 1.50 m to clear — which
is 1 m off the rungs and would put him on the far side of the berm on some towers. **A constant cannot fix this.**

### The top of the tower, mapped

Occupancy grid at the tower-0 dismount, cells 0.25 m, `#` = a 1.8×0.4 capsule cannot stand there,
`D` = the shipped dismount point, `L` = the ladder head:

```
      .....############...........
      ....##############..........
      ....##############..........
      ....##############..........
      .....####.......#...........
      .....####...................
      .....####...................
      .....####.....D...L.........
      .....####...................
      .....####...................
      .....######.................
      ....##############..........
      ....##############..........
      ....##############..........
      .....############...........
```

Measured section of tower 0: deck at **y = 9.77**, a vertical wall band from **9.8 to 10.65** capped by a flat
horizontal surface at **10.51–10.65** (193 tris at 10.53 alone), roof at **11.84–11.92**.
A 0.76–0.88 m flat-topped wall ringing a guard-tower deck **is the sandbag parapet** — that identification is
inferred from the section, not from a mesh name, because `fb_tower_i` is one merged mesh with no per-part naming.
Flagging that honestly: **INFERRED, not measured.**

So the top-out lands him:
- **0.20 m above the deck** (feet at 9.97, deck at 9.77) — a small drop, fine;
- in a **1.5 m-wide slot** with the parapet 0.75 m away in **both** ±Z directions — **0.35 m of shell clearance
  a side**;
- **0.95 m from the ladder head** he just came off;
- with **0.07 m of margin** on the tightest surface.

**That is his sentence, verbatim: between a ladder and sandbags.** A 16×5 ring search finds a spot with 0.62 m
clearance 1.5 m away — the room exists, the code just never looks for it.

### The sandbag question, settled

Nearest mesh of **any** sandbag family (`fb_sbg_seg_*` ×80, `fb_sandbag_parapet_*` ×32, `fb_sandbag_hooch_*`,
`fb_sandbag_stack_i`, `us_mortar_pit_sandbags`) to each ladder waypoint, 3D, against the capsule's y-span:

```
ladder_bottom      TOP: none within 6 m          BOTTOM: fb_sandbag_hooch_p0_10 = 5.93 m
ladder_bottom.001  TOP: none within 6 m          BOTTOM: none within 6 m
ladder_bottom.002  TOP: none within 6 m          BOTTOM: fb_sandbag_stack_i    = 4.56 m
ladder_bottom.003  TOP: fb_sbg_seg_026 = 5.68 m  BOTTOM: fb_sbg_seg_026        = 3.91 m
```

**Nothing named "sandbag" is within 3.9 m of any ladder.** The `fb_sandbag_parapet_*` runs are the *bunker*
parapets at y ≈ 3.2–4.8, nowhere near a tower. The sandbags he hit are the tower's own parapet, integral to
`fb_tower_i` — geometry that is correct for a watchtower. **The asset is not misplaced. The constants are wrong
for it.**

## A4. Why "tight" becomes "wedged" — the mechanism

`scripts/world/site_planner.gd:1823-1832` `_force_backface_collision()`, applied to **every** `StaticBody3D`
under the firebase root at `:1884-1891`:

```gdscript
concave.backface_collision = true
```

The shipped GLB winds inward, so this was necessary to make the walls solid at all. Its side effect is that
**every firebase surface is now solid from the inside too.** A capsule deposited 0.31 m inside the tower has no
face to escape through in either direction. Without this, an embedded capsule would at least pop out through the
back; with it, it is boxed.

Note also `MOUND_COLLIDER_PREFIX` is **kept**, not stripped (`site_planner.gd:1841-1847`, ruling 2026-07-29):
"this trimesh IS the walkable ground now." So ladder `.002`'s 0.12 m mound penetration is real geometry, not a
doomed collider.

## A5. The gap that makes it unrecoverable — the player has no unstick

Grepped `unstick|stuck|depenetrat` across `scripts/`:

- `scripts/enemies/enemy_base.gd:206-232` — stuck watchdog, sidestep, direction flip, 3-flip give-up.
- `scripts/allies/ally_base.gd:56-83` — the same watchdog, mirrored; driven at `:864`.
- **`scripts/player/player.gd` — nothing. Zero hits.**

Every AI actor in this game can free itself from a wedge. The player cannot. That half of the defect is
classification **(c) — never built**, and it is why *any* placement bug anywhere in the world becomes a
session-ending trap rather than a two-second annoyance.

## A6. Classification

Against the briefing's three buckets, this splits cleanly:

- **(a) bug, known cause** — a dismount/step-off that places the player with no clearance check, into a point
  that is measurably inside a collider (bottom, 3/4 ladders) or in a 1.5 m parapet slot with 0.07 m of margin
  (top, 3/4 ladders). `ladder.gd:126-136` + `player.gd:1449-1457`. **This is the fix candidate.**
- **(c) never built** — no player stuck-detection/unstick, while both NPC base classes have one.
- **NOT (b)** — the asset is fine. Explicitly refuted above with numbers.

---

## A7. THE FIX — what I would ship tonight, and what I would not

### Candidate 1 — eject along the ladder's own facing with a shapecast · **REJECT**
The measured sweep kills it: the bottom obstruction runs from 0.55 m to past 1.20 m along `+_face`, and only
clears at 1.50 m. Ejecting along the facing pushes him **into** the slab for the first half metre and, at the
distance that works, drops him a metre off the rungs and potentially over the berm lip. **Refuted by measurement,
not by opinion.**

### Candidate 2 — a general player stuck-detection / unstick safety valve · **SHIP LATER, NOT TONIGHT**
Highest long-term value: it covers berm wedges, prop wedges and the ones we have not found. But (i) it is a new
system on the player's hot path during the demo gate; (ii) a watchdog that teleports the player can fire
spuriously when he is *legitimately* pinned — prone in a trench, in cover in a firefight — and stealing his
position mid-contact is a Pillar-1 and Pillar-3 injury; (iii) it needs its own tuning pass and its own probe.
**Recommend it as a separate decree item for the playtest list. Do not bolt it on at midnight.**

### Candidate 3 — a clearance-tested dismount that searches for a free spot · **SHIP THIS**

Add one resolver to `scripts/world/ladder.gd` and route both exits through it.

**Change set — three edits, all in two files, all inside the ladder system:**

1. **`scripts/world/ladder.gd:133-136`** — `dismount_point()` becomes clearance-tested: compute the current
   geometric point, shape-test the player capsule there against mask 1|4 (world + enemies, matching
   `player.tscn:15`) via `get_world_3d().direct_space_state.intersect_shape()`; if blocked, spiral out
   (16 headings × radii 0.8 / 1.1 / 1.4 / 1.8, capped at ~1.8 m) and return the **nearest** free candidate that
   also has ground within 1.2 m below it (one downward raycast — this is what stops the search answering with a
   point off the tower). If nothing is free, return the geometric point unchanged, so behaviour degrades to
   today's rather than to something worse.
2. **`scripts/world/ladder.gd`, new `step_off_point() -> Vector3`** — the same resolver applied to
   `rail_point(bottom_y())`. This is the one that actually fires on 3 of 4 ladders.
3. **`scripts/player/player.gd:1449-1451`** — replace `global_position.y = bot` with
   `global_position = _ladder.call("step_off_point")`.
   **`scripts/player/player.gd:1454-1457`** already calls `dismount_point()`, so it needs **no edit** — it
   inherits the fix. That is deliberate: the smallest possible diff on the player.

**Why the resolver goes in `ladder.gd` and not `player.gd`:** it makes the corrected points *addressable
without a player instance*, which is what lets the probe below assert on the shipped function instead of
re-deriving the arithmetic and grading its own homework.

**Cost:** ~35 lines, one file plus a 1-line call site. Up to 65 shape queries, **once per dismount** — not
per frame. Unmeasurable against the Intel UHD bench (ADR-026).

**What this sacrifices — Law 2, no free lunch:**
- The dismount point becomes **non-deterministic with respect to world state**: a sentry standing at
  `tower_los_point` (measured **1.36 m** from every top dismount — a real `sentry` work post,
  `site_planner.gd:1108) will now push the player's landing spot around. Two climbs of the same ladder can end
  in different places. That is the correct trade, but it is a change in feel.
- **It does not fix the tower.** The player still tops out into a 1.5 m parapet slot; he is merely guaranteed
  not to be *inside* anything. The slot is a level-design fact and belongs to the kit pivot, not to tonight.
- **It does not cover any other wedge in the world.** Only ladders. The general unstick is still owed.
- A search that finds nothing silently falls back to today's broken point. That is deliberate (never worse
  than shipped), but it means a future geometry change could re-break this **without the probe going red** —
  unless the probe asserts on the *resolved* point, which is exactly why it must, and does below.

## A8. THE PROBE — designed to go red the moment the fix is reverted

**File: `tests/test_ladder_dismount.gd` + `tests/test_ladder_dismount.tscn`.**

**The name matters and is not cosmetic.** `run_all_tests.ps1:27` globs
`Get-ChildItem "$root\tests" -Filter "test_*.tscn"`. **A file named `probe_ladder_dismount.tscn` would never run
in the suite** — it would be exactly the GATE bead that gated nothing (ADR-023's own example). It must be
`test_*`.

House style copied from `tests/probe_hooch_path.gd` (stand the real world at a fixed seed → `SitePlanner` →
assert → `_finish()` → `get_tree().quit(0/1)`), run with `-- --test-save` so `CampaignState`
(`scripts/autoload/campaign_state.gd:202-204`) redirects to `user://campaign_test.cfg` and **the save layer is
never touched**.

**Construction — fully deterministic, no player, no input:**
1. Instantiate `res://scenes/levels/game_world.tscn` with `mission_seed = 4242`, `spawn_player_on_ready = false`;
   wait for `is_world_ready`.
2. `SitePlanner.find_site(rng, 120.0)` → `place_firebase_main(centre)`. That call already runs
   `_repair_glb_colliders` and `Ladder.build_from_markers` (`site_planner.gd:1704-1710`), so the colliders under
   test are the **shipped, backface-forced** ones — not the raw GLB.
3. `await get_tree().physics_frame` ×2 so the static bodies are live in the space.
4. Collect every `Ladder` node under the site root.

**Assertions:**
- **`ladders.size() == 4`** — hard fail otherwise. Without this the whole probe passes green on zero ladders,
  which is the `green-validator-can-pass-empty-work` trap this repo has already been bitten by.
- For each ladder, for **both** `dismount_point()` and `step_off_point()`: build a `CapsuleShape3D`
  (radius 0.40, height 1.80 — read from the constants, not retyped), place it at `point + Vector3.UP * 0.9`,
  and run `direct_space_state.intersect_shape()` with `collision_mask = 1` and `max_results = 8`.
  **Assert zero results.**
- For each resolved point, cast a ray 1.2 m down and **assert it hits** — this is what catches a search that
  "solves" the wedge by answering with a point in mid-air off the platform.
- Print, per ladder, the resolved point, its overlap count and its ground distance. **A boolean probe is not an
  instrument** — the numbers are what let the next reader tell a fix from a coincidence.

**Why it goes red on revert:** revert the resolver and `dismount_point()` returns
`_top - _face*0.95` again, and the bottom exit returns to `rail_point(bottom_y())`. The measurement above says
those points overlap `fb_tower_i_*-colonly` on **three of four ladders** at the bottom by 0.31 m. `intersect_shape`
returns non-empty. **Three failures, immediately.** The probe cannot pass against the reverted code, because the
penetration is in the constants, not in a race.

**Honest limit:** the probe tests *static* geometry. It does **not** prove the player can walk out of the 1.5 m
parapet slot, and it does **not** cover a live sentry standing at `tower_los_point` 1.36 m away — mask 1 only.
Extending it to mask 5 would make it flap with garrison RNG. That gap is real and I am naming it rather than
hiding it behind a green tick.

**Confidence, section A: HIGH on the geometry and the code path** — every number is measured off the shipped
GLB and the source as it stands today. **MEDIUM on "this specific defect is the one he hit"** — I did not run
the game and did not see his wedge. Three of four ladders put him 0.31 m inside a collider at the bottom and
the other three put him in a 1.5 m parapet slot at the top, so a wedge on this path is close to certain, but
I cannot tell you which end he was on.

---

# B. "NPCs still stacking up at work points"

## B0. VERDICT UP FRONT

**Classification: (a) bug, known cause. Multiple independent causes, all measured, all live simultaneously.**

The 2026-08-24 ruling was implemented faithfully as **"one man per marker."** The defect is that
**a marker is not a place.** Nothing in this codebase enforces a minimum *distance* between two assigned men,
and nothing pushes two overlapping bodies apart.

## B1. The prior work is INTACT — all four claims verified against today's source

| `5ed4b181` claim | status | evidence |
|---|---|---|
| `camp_director` walks `idx < size`, no modulo | **PRESENT** | `scripts/enemies/camp_director.gd:132-140` |
| `mission_generator` deals work posts without replacement | **PRESENT** | `scripts/missions/mission_generator.gd:1226-1229` (`wp_deal.pop_at`) |
| `heli_lift` dropoff claim check | **PRESENT** | `scripts/vehicles/heli_lift.gd:326-330, 363-378` (`_point_unclaimed`, `POINT_CLAIM_M = 2.0`) |
| DIG classified within 8 m of an earthwork | **PRESENT** | `scripts/world/site_planner.gd:1133` (`DIG_NEAR_M = 8.0`), applied `:1377-1388` |

**This is not a regression.** Nothing was lost. The exclusivity that shipped simply never covered the failure
mode that is visible.

**There is no claim/release ledger.** The only real claim/release pair in the repo is `MortarPit`
(`scripts/world/mortar_pit.gd:64,73,78`, consumed once at `scripts/allies/garrison_defender.gd:168-180`).
Everything else is deal-at-spawn. `heli_lift._point_unclaimed` is a **live group scan**, not a ledger — and it
is the **only spatial exclusivity test in the game**, and the initial garrison build never calls it.

## B2. Which hypotheses are true, which are refuted

**(d) NO SEPARATION AND NO AVOIDANCE — TRUE. This is the load-bearing cause.**

- `scripts/world/civilian.gd:340` — `nav.avoidance_enabled = false`
- `scripts/world/civilian.gd:369-370` — `collision_layer = 2`, `collision_mask = 1` (**world only**)
- `scripts/enemies/enemy_base.gd:3202, 3205-3206` — same
- `scripts/allies/ally_base.gd:2480, 2483-2484` — same

**No NPC in this game collides with, or avoids, any other NPC.** Body radius is 0.30 m
(`civilian.gd:321`). Any two destinations closer than ~0.7 m render as one body inside another, permanently,
with nothing in the engine to resolve it. **Even a perfect claim ledger would still look like a pile** whenever
two *different* markers are within arm's reach — which the next section shows they routinely are.

**(e) A PATH THAT BYPASSES THE CLAIM — TRUE, and large.**

- `civilian.gd:1239-1270` — `_bt_walk_home` sets `_wander_target = home` **exactly**; `_bt_walk_fire` →
  `home + Vector3(2,0,2)` exactly; `_bt_walk_market` → `home + (-3,0,4)`. All three ignore `working_point_pos`
  *and* `bb["target_pos"]`, with **zero per-man offset**.
- `home` is dealt by a **MODULO**: `mission_generator.gd:1133` — `quarters[qi % quarters.size()]`.
  **Four** quarters markers (`site_planner.gd:1121-1123`) against **36** men reaching that line →
  **nine men aimed at one identical coordinate.** This is precisely the `% size()` pattern the 8/24 ruling
  killed in `camp_director`, still alive for quarters.
- `civilian.gd:1217-1222` maps only WORK / WALK_PADDY / FISH to the working point. REST, COOK, SIT, TALK,
  SLEEP — 7 of 12 scheduled actions — resolve to `home + randf(-3,3)`, re-rolled hourly.

**(b) A PER-INSTANCE LEDGER, TWO DIRECTORS ON ONE MARKER — TRUE** (VC camp, not the FSB).
`mission_generator.gd:835` and `:840` append **two** LazyGroups at the *identical* camp position
(`camp_mortar_crew` ×3, `zpu_crew` ×2). Each calls `_stations_near()` (`:1317`), which returns the **same Array
object** (`:293-299`). Each LazyGroup stands up its own `CampDirector` (`scripts/missions/lazy_group.gd:110-111`),
and both walk `stations[idx]` from `idx = 0` (`camp_director.gd:119-141`). Station 0 gets one man from each.

**(c) CLAIMED BY INDEX, POSITION ROLLED SEPARATELY — refuted at spawn, true at runtime in a weaker form.**
Spawn is correct (`mission_generator.gd:1110-1131`). But `civilian.gd:1308-1312` re-derives the standing spot
every settle as a **1.5 m ring at `hash(name) % 360` degrees** — a roll, not a slot. It lowers the average
collision rate and guarantees nothing.

**(a) A CLAIM NEVER RELEASED — REFUTED as a cause.** There is no persistent ledger to leak. The one live scan
(`heli_lift.gd:368-378`) skips only invalid instances, so a dead-not-yet-freed man keeps blocking his point —
that **over**-claims and pushes arrivals *away*. That is the opposite of stacking.

**(f) MULTI-MAN POSTS — REFUTED.** `mission_generator.gd:1110-1114` expands `men: N` around a 1.8 m ring
(`a = TAU*mi/men_n`, `r = 1.8`); a two-man post lands 3.6 m apart. **This one is genuinely fixed** — worth
saying out loud, since it was the obvious suspect.

## B3. The specific hole, measured off the shipped GLB

`SitePlanner.fsb_garrison_plan()` reproduced against `fsb_main_v3.glb`. 488 work markers confirmed. 14 of 16
named marker keys present — **`GUN_POINT_001` and `APPROACH_002` are missing from the GLB**, so those posts are
silently skipped and curated men = 14, not 17. (That is a second, quieter ADR-042-shaped naming-contract miss.)

**Result: 35 posts / 38 men. Nineteen pairs of planned man-stations are under 3.0 m apart. Five are under 1.0 m.**

```
0.55 m  chow_diner       <-> queue              1.85 m  chow_server_line <-> queue
0.61 m  chow_server      <-> queue              1.85 m  FP003_radio      <-> radio
0.81 m  wash             <-> water              2.15 m  chow_server      <-> chow_server_line
0.89 m  OR_a             <-> OR_b               2.17 m  eat              <-> queue
0.91 m  radio            <-> plot               2.26 m  mortar_2         <-> mortar_3
1.05 m  chow_server      <-> chow_diner         2.37 m  SOCKET_B         <-> guard
1.16 m  mortar_1         <-> mortar_2           2.52 m  eat              <-> chow_diner
1.34 m  chow_server_line <-> chow_diner         2.69 m  mg_fire          <-> watch
1.56 m  chow_server      <-> eat                2.75 m  FP003_radio      <-> plot
1.69 m  mg_fire          <-> bunker_los
```

**Five men are planned into a 2.2 m box at the chow servery.** Add the 1.5 m random-angle jitter, subtract all
collision and all avoidance, and that is a pile of men — exactly the report.

**The 488-markers-vs-23-staffed ratio is a RED HERRING, and the council should say so plainly.** The dealer is
correct and sampling density is not the fault. The fault is that **no stage — plan, spawn, or behaviour tree —
ever asks "is this within arm's reach of another man?"**, while `heli_lift` has had exactly that rule
(`POINT_CLAIM_M = 2.0`) since 8/24 and it was never applied to the initial build.

**Second hole, separate population (village):** `mission_generator.gd:1302` — `_assign_households` runs *after*
the deal and overwrites every party member's point with the head's:
`c.working_point_pos = head.working_point_pos`. A household is 3–6 men (`:1278-1279`). **The `wp_deal.pop_at` at
`:1229` is undone 73 lines later.** `GROUP_WALK_ACTIONS` (`civilian.gd:47-49`) covers only the four `walk_*`
actions, so the formation spread ends the moment they arrive.

**Why no test caught it:** `tests/test_firebase_garrison.gd:179-180` asserts every man *has* a working point.
It never asserts two men have *different* or *separated* ones. Green validator, empty work.

## B4. A source comment that is WRONG — correct on contact

`site_planner.gd:1476-1480` states: *"The surgical positions around the table carry no baked body."*
**Refuted by the GLB.** All three surgical markers have a baked body standing on them —
**unskinned static MeshInstances**, which is why every existing instrument is blind to them
(`_animate_fsb_baked_cast` only touches rigs with moving tracks; the T-pose audit at `site_planner.gd:820-835`
only scans `Skeleton3D`):

| baked node | world pos | marker | Δ |
|---|---|---|---|
| `PSXRig_med_work_surgeon_N_us_grunt_joined` | (74.86, 4.25, 7.90) | `work_med_surgeon` | **0.01 m** |
| `PSXRig_med_work_scrubnurse_N_us_grunt_joined` | (75.16, 4.25, 8.76) | `work_med_scrubnurse` | **0.02 m** |
| `PSXRig_med_work_anesthetist_5_us_grunt_joined` | (74.02, 4.25, 8.33) | `work_med_anesthetist` | 0.03 m |

`site_planner.gd:1488-1494` seeds **2 live medics** onto `med_surgeon` and `med_scrubnurse`. **Two live men are
spawned 1–2 cm inside two baked bodies.** Nothing hides them (`_wire_m101_rigs:861-862` hides only the M101 crew).

The *skinned* baked cast is correctly excluded — the `wt.begins_with("med")` skip at `site_planner.gd:1456`
holds, and **no other marker family in the GLB carries a baked body.** Only the three OR positions were
mis-audited. Per the POINTER LAW and the no-drift rule, that comment must be corrected in whatever change
touches this function.

**Latent, not yet firing:** the pool exclusion at `site_planner.gd:1435` tests `wt == "gun" or wt == "mortar"`,
but the six mortar markers reduce to `mortar_0_gunner` / `mortar_0_dropper` / … (the ordinal strip at
`:1371-1375` cannot flatten them; `_arty_pits` at `:1278` uses `begins_with("mortar_")`, the pool build does
not). They enter the round-robin *and* get seeded as an arty crew. They survive only because they sort to the
tail of `type_order` and the budget (24) runs out around index 13. **Raise `FSB_WORK_POST_CAP` or
`FSB_GARRISON_MAX_MEN` and three men spawn on top of the mortar crew.**

## B5. The fix — isolated enough to ship, in priority order

**A. Spatial exclusion on the plan — the real fix.** `scripts/world/site_planner.gd:1574`, immediately before
`return {"posts": posts, "quarters": quarters}`: filter `posts` so no accepted post's `pos` lies within **2.0 m**
(XZ only) of an already-accepted one, keeping the earlier. The drop order is already the priority order —
curated first, then OR/cots, then arty, then the rotation. Expand `men > 1` on the 1.8 m ring *before* testing.
~10 lines, one function, deterministic, removes all 19 close pairs. The budget shortfall is absorbed by the
existing census print at `mission_generator.gd:1173`. Hoist the 2.0 m from `heli_lift.POINT_CLAIM_M` rather than
typing a second magic number — one rule, one place.

**B. The OR seed.** `scripts/world/site_planner.gd:1246` — drop `med_surgeon` / `med_scrubnurse` /
`med_anesthetist` from `MED_SURGICAL_TYPES`, and correct the false comment at `:1476-1480` in the same change.
One line plus the comment. Note **fix A alone does not catch this** — the baked bodies are GLB geometry, not
posts, so the distance filter never sees them.

**C. Village households.** `scripts/missions/mission_generator.gd:1302` — delete
`c.working_point_pos = head.working_point_pos`. One line. Members keep the point `wp_deal` dealt them; group
travel is unaffected, because `_group_walk_apply` (`civilian.gd:1112-1123`) drives followers off the lead's
`group_destination` during the four `walk_*` actions and hands them back on arrival.

**DO NOT ship tonight: the `quarters[qi % 4]` fix** (`mission_generator.gd:1133`). It is real and it is probably
the **biggest** visual pile — nine men on one point at every `walk_fire` hour — but `home` also feeds sleep
placement, LZ keep-out (`civilian.gd:1302-1306`) and `heli_lift`'s bunk ring. It wants a council pass, not a
midnight edit.

**What all of this sacrifices:** fix A costs **men on the ground**. Dropping every post within 2 m of a taken
one thins the compound — the chow line goes from five men to two. He has complained about an *empty*-feeling
base before. **Fewer men, correctly spaced, is a trade the Arbiter should put to him rather than assume.**
It also does not touch (d): NPCs still have no mutual collision, so any *future* pair of close destinations
still interpenetrates. The durable fix is avoidance or body collision, and that is a perf decision on the
Intel UHD bench (ADR-026), not a tonight decision.

**Confidence, section B: HIGH on every number** — all measured from the shipped GLB and today's source, not
from the commit message.
**What I could not prove:** I did not run the game and did not see the stack he saw. Four independent causes
are live simultaneously — the chow line (5 men in 2.2 m), the hooch quarters (9 men on one point), the aid
station (2 live men inside 2 baked bodies), and village households (3–6 on one paddy point) — and I cannot tell
you which one he was looking at. I also could not measure the navmesh, so I cannot rule out
`nav_router.gd:63-76` `nearest_mesh_point` collapsing two nearby markers onto one *identical* mesh point; that
would make the close pairs exactly coincident rather than merely overlapping, and it needs a runtime probe.

---

# RECOMMENDATION TO THE ARBITER

**Ship A tonight.** The ladder resolver is the isolated defect the briefing asks for: two files, ~35 lines,
one call site, a deterministic 0.31 m penetration to point at, and a probe that cannot pass against the
reverted code. It is a bug fix, so it is exempt under the ADR-015 gate.

**Do not ship B tonight** unless he rules on the trade. Fix B-A is ten lines, but it visibly thins the
compound, and "how many men in the chow line" is his call, not mine. B-B (the OR seed, two live men inside two
baked bodies) is the one piece of B I would ship unasked — it is a one-line deletion plus a comment
correction, it has no design content, and it removes a defect that is on the walked path.

**Both A and B point at the same thing, and it is the pivot's best argument:** the firebase's placement data
was authored once, in Blender, against constants that were never re-measured in the engine — and there is no
stage anywhere that asks "can a man actually stand here?" A kit assembled in-engine, where every part carries
its own validated stand-points, is exactly the mechanism that would have caught both of these at author time.
That is a genuine point for the pivot. It is **not** an argument for doing it before the demo ships.
