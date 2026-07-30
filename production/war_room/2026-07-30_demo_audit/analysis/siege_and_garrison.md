# DEMO AUDIT — THE SIEGE, THE OVERRUN, THE GARRISON

Date: 2026-07-30. Read-only code audit (no game launch, no Blender). Slice: `siege_director.gd`,
`marching_cell.gd`, `enemy_base.gd` (assault/press paths), `combat_goals.gd`, `field_director.gd`
(siege + garrison), `garrison_defender.gd`, `civilian.gd`, `civilian_schedules.gd`,
`demo_game.gd`, plus the geometry the demo overrides (`site_planner.gd`, `mission_generator.gd`,
`firebase_v3_destructibles.json`).

Every claim below carries a `file:line`. Anything I could not close by reading is marked
**UNPROVEN**.

---

## P0-1. THE WHOLE GARRISON IS SEATED ON THE WRONG GROUND, AND SO NO GARRISON MAN CAN EVER ARRIVE

`mission_generator.gd:894` / `:899` / `:903` / `:921` set the garrison's spawn Y, his
`working_point_pos` Y, his `home` (quarters) Y and the MG emplacement Y from
`world.terrain_manager.get_height_at()`.

But terrain is **not** the ground inside the firebase any more. `site_planner.gd:1156-1161`:

> `if String(body.name).begins_with(MOUND_COLLIDER_PREFIX):` … *"KEPT, not stripped (ruling
> 2026-07-29). This trimesh IS the walkable ground now. … The terrain no longer climbs, so this is
> the only ground and it must stay."*

and `site_planner.gd:1031-1033` levels the terrain to one flat `seat_norm` across
`FSB_FLATTEN_RADIUS`. `site_planner.gd:678-679` measures the model's own plate as rolling
**~1.5 m to ~5.3 m above that seat**. The correct API for "the floor here" is
`GameWorld.surface_y()` (`game_world.gd:404-418`, which raycasts layer 1 and therefore finds the
mound trimesh) — and `marching_cell.gd:169` already uses exactly that for the enemy cells.

So every garrison station is authored **1.5–5.3 m below the floor the man stands on**.

The failure is not merely cosmetic. Every garrison BT leaf tests **3-D** distance against that
target:

- `civilian.gd:737` — `if global_position.distance_to(at) > WORK_ARRIVE_M:` (`WORK_ARRIVE_M = 1.6`,
  `:716`) — this is `_bt_settle`, i.e. **work, rest, cook, sleep, fish, sit, talk** (`:748-771`).
- `civilian.gd:681` — `_bt_walk_home`, `< 1.5`
- `civilian.gd:689` — `_bt_walk_working`, `< 1.5`
- `civilian.gd:698` — `_bt_walk_fire`, `< 1.5`
- `civilian.gd:706` — `_bt_walk_market`, `< 1.5`

A man standing on the mound at `seat + 3.4` whose target is at `seat` is **3.4 m away and cannot
close**, because he cannot descend into the collider. `_bt_settle` therefore returns `RUNNING`
forever, `bb["speed"]` never drops to 0, `_wander_target` is never released.

**Concrete failure scenario (the demo's opening shot):** the player wakes at dusk. Every man of the
garrison — sentries, gun crew, radioman, quartermaster, off-duty — is on `ACTION_WORK`
(`civilian_schedules.gd:104-208`), i.e. `_bt_settle`. Not one of them ever reaches his marker.
They all walk permanently into the ground at their post, shuffling / re-pathing on the spot, and
never play a settled idle. This is the most likely mechanical cause of "the other NPC allies just
stand there" reading wrong on screen, and it is a **superset** of the bug the 2026-07-29 rewrite
was aimed at: the leaves now name a destination they are structurally forbidden from reaching.

Two knock-ons in the same defect:

- `civilian.gd:639-650` `place_for_current_hour()` does `global_position = target` — an outright
  **teleport to a point 1.5–5.3 m under the mound**, on first physics tick (`:235-237`) and again
  on every LOD_FAR wake (`:621-622`). Depenetration will probably eject the capsule upward, but
  a pop at every wake, and men lost under thin geometry, are both live risks. **UNPROVEN**: the
  exact recovery behaviour needs a playtest.
- `garrison_defender.gd:36` snapshots `post = civ.working_point_pos`, so the promoted defender's
  `post_anchor` and `OrderMode.HOLD` target (`:58-59`) inherit the same under-floor point, with
  `post_leash = 8.0`. `mission_generator.gd:921` sinks the M60 emplacements the same way.

**Fix shape:** one call site change — `world.surface_y(...)` in place of
`terrain_manager.get_height_at(...)` at `mission_generator.gd:894, 899, 903, 921`. Consider also
making the arrive checks XZ-only, which is cheap insurance against the same class of bug.

---

## P0-2. THE MAIN SIEGE CAN BECOME UNBREAKABLE, AND REPORTS 0 KILLED — the `run_peak` hole

`siege_director.gd:189-201`:

```
if run_strength <= 0 or nights_run == 0:
    run_strength = forced_strength if forced_strength > 0 else _rng.randi_range(1, 50)
    run_peak = run_strength
elif forced_strength > 0:
    run_strength = forced_strength          # <-- run_peak NOT touched
```

`reinforce()` (`:230-247`) is careful about this and says so in its own header at `:226-228`
(*"run_peak MUST grow with run_strength"*). `open_siege`'s `elif` branch is the same hazard,
unguarded.

**Trace, demo arc.** `demo_game.gd:173-179` opens a probe of 11 at t=600 s and the assault of 45 at
t=720 s. `_open_siege` (`:186-213`) branches on `d.siege.active`.

- **If the probe is still up at 720 s** (what `demo_game.gd:203-207` assumes): `reinforce(maxi(1,
  45 - run_strength))`. `run_strength` is **fixed for the night** — nothing decrements it during an
  active siege; casualties are counted by `live_strength()` (`:301-306`), which walks the cells.
  So `extra = 34`, `run_strength = 45`, `run_peak = 45`, and `killed_count()` (`:309-310`) stays
  honest. **This path is correct.**
- **If the probe already ended** — and it will, on the `"broken"` path: 11 men break at
  `live/peak < 0.575` (`enemy_squad.gd:119-123`), i.e. the **5th** probe death — then
  `_break_siege` (`:558-586`) sets `active = false`, `run_strength = survivors` (say 6),
  `nights_run` stays 1. At 720 s `d.siege.active` is false, so the demo takes
  `open_siege(45)`. `run_strength = 6 > 0` and `nights_run = 1 ≠ 0`, so the `elif` fires:
  **`run_strength = 45` while `run_peak` remains 11.**

Consequences, all at once:

- `_run_siege:296` → `break_state(live=45, peak=11, …)` → `ratio = 4.09`, threshold ≤ 0.80 →
  **`broken` can never be true.** The assault fights to `MAX_DURATION_S` or to the last man.
- `killed_count() = maxi(0, 11 - 45) = 0` → `_on_siege_ended` (`field_director.gd:1408-1416`)
  toasts *"0 OF 11 DOWN"* after a 45-man assault.
- The reap (`:592-616`) never runs, because `_break_siege` never runs.

Also note the caller-side arithmetic: `maxi(1, strength - d.siege.run_strength)`
(`demo_game.gd:207`) silently degrades to **+1 man** if `run_strength` is ever already ≥ 45,
violating the "total, not an increment" contract stated at `demo_game.gd:30-34`. Not reachable in
today's arc (the probe is forced to 11), but it is one constant edit away.

**Fix shape:** in `open_siege`, `run_peak = maxi(run_peak, run_strength)` — or better,
`run_peak += (forced_strength - run_strength)` — on the `elif` branch.

---

## P0-3. THE ILLUM ROUND MATERIALIZES THE ENTIRE ASSAULT AT THE RING, AND THE LIVE CAP CANNOT STOP IT

`ILLUM_STANDOFF_M = 140.0` (`siege_director.gd:89`) and `IllumFlare.LIGHT_RADIUS = 30.0`
(`illum_flare.gd:11`). `is_lit()` is a flat XZ radius test (`illum_flare.gd:21-25`). So a round
lights the annulus **110 m – 170 m** from `fsb_center`, on the attack bearing — which is precisely
the lane the demo's cells walk in on (`ring_min 190 / ring_max 235`, `demo_game.gd:193-194`,
inbound at `MARCH_SPEED 2.2`, `marching_cell.gd:16`).

Crossing 170 → 110 m takes 27 s. Rounds go up every `ILLUM_INTERVAL_S = 70` and burn
`DURATION = 25 s`. So a large share of the cells — plausibly all of them, since the first round is
at `ILLUM_FIRST_S = 12 s` after the escalation and `reinforce` re-arms that timer at `:240` — get
lit while in the band and materialize there via `_light_check` (`:328-331`) →
`materialize_if_lit` (`marching_cell.gd:99-105`).

Result: **~45 full bodies stand up at 110–170 m instead of at 80 m**, which is the entire body cost
the MarchingCell exists to defer (`marching_cell.gd:1-8`), arriving in one clump, at the exact
moment the player is also being shelled.

And `_enforce_live_cap` (`:336-347`) cannot arrest it: it only calls
`c.set_physics_process(false)`, and `materialize_if_lit()` is called directly from `_light_check`,
not from `_physics_process`. **A capped cell still materializes when lit.** The cap is bypassed by
the game's own light.

Secondary: `_enforce_live_cap` **never re-enables** a frozen cell (`:344`). Once the cap trips,
those cells are stopped at the ring for the rest of the night, yet `live_strength()` keeps counting
their full paper strength (`marching_cell.gd:55-62`), so the break ratio is measured against men
who will never arrive.

---

## P0-4. ON ~A THIRD OF THE COMPASS THE ASSAULT MATERIALIZES *INSIDE* THE WIRE AND SPENDS THE OVERRUN BEFORE ANY FIGHT

`demo_game.gd:197`: `d.siege.cell_materialize_m = minf(d.siege.cell_materialize_m, 220.0)`.
The value it clamps is `MarchingCell.MATERIALIZE_M = 80.0` (`siege_director.gd:116`,
`marching_cell.gd:15`). `minf(80, 220) = 80` — **the override is a no-op**, a dead line that reads
as a slice-scale tuning. (If the author meant to *raise* it to 220, `minf` is the wrong function.)

Measured against the actual perimeter (`firebase_v3_destructibles.json`, 80 segments): the parapet
radius runs **49.3 m – 96.1 m**, and 13 of the 36 bearing bins have a max radius **above 86 m**
(bins 0-3, 17-22, 33-35 in the manifest's own frame). On those bearings the 80 m materialize ring
is *inside* the wall.

A dormant cell is a bare `Node3D` with no collider, so it walks **through** the parapet and through
the merged barbwire ring, and stands its men up inside the compound. `inside_count()` (`:449-466`)
then measures `r = 80 < wall - 6` → every man of that cell counts as through the wire →
`_check_overrun` (`:471-479`) fires on the first poll, `OVERRUN_MEN = 3` being trivially met.

**Concrete failure scenario:** `sector_bearing` rolls onto a high-radius face. ~60 s after the
escalation the player hears *"THEY'RE INSIDE THE WIRE"* and the siren
(`field_director.gd:1389-1391`) — before a shot has been exchanged, with the attackers appearing
out of nothing inside his own base. The wire, the gate lane and the whole "one lane is the gate"
doctrine at `siege_director.gd:60-67` are simply bypassed.

P0-3 partially masks this (if the cells are lit at 110–170 m they materialize *outside*), which
makes the bug **seed- and timing-dependent** rather than absent — the worst kind.

---

## P1-5. THE LATE NAPALM RUN LANDS ON THE CELL RING, WHERE IT EITHER DOES NOTHING OR ENDS THE SIEGE

`demo_game.gd:104-106`: `NAPALM_ASSAULT_S = SIEGE_AT_S + 60` = t=780 s, `NAPALM_RANGE_M = 210`,
laid on `d.siege.sector_bearing` (`:124`). The cells sit at **190–235 m on that exact bearing**
(`demo_game.gd:193-194`). The strip is on top of the assault, not behind it — the comment at
`demo_game.gd:100-103` reasons from `rally_m 150`, not from `ring_min/ring_max`.

Both outcomes are wrong:

- **Cells still dormant** → `MarchingCell` has no hitzones, no `take_damage`, is not in the
  `enemies` group (only its men are, `marching_cell.gd:117-120`). The napalm passes through the
  assault with **zero effect**. The demo's marquee "answer to being overrun" hits nothing.
- **Cells materialized** (the P0-3 path makes this likely) → a scripted strike can kill enough men
  in one pass to cross `live/peak < 0.575` and **break the siege at t≈780 s**, 300 s before the
  dawn card, with no player agency in it.

---

## P1-6. HELICOPTER REPLACEMENTS NEVER JOIN THE GARRISON — the stand-to latch blocks its own re-call

`heli_lift.gd:225-231` deliberately reaches for the director's stand-to so a ship landing into a
fight puts its men on the wire:

```
if director != null and is_instance_valid(director) and director._garrison_stood_to:
    director._garrison_stand_to()
```

But `_garrison_stand_to` (`field_director.gd:1325-1328`) opens with
`if _garrison_stood_to: return`. **The guard the caller tests is the guard that makes the call a
no-op.** Delivered men stay Civilians for the whole siege — exactly the outcome the comment says it
is preventing.

Worse, they are inert even at the *next* stand-to:

- `Civilian.spawn` never sets `occupation`, and `heli_lift.gd:179-180` doesn't either. The default
  is `occupation = "farmer"` (`civilian.gd:50`) → a US garrison replacement runs the **villager**
  schedule (`civilian_schedules.gd:27-44`).
- `working_point_pos` is never set → `_resolve_target` (`civilian.gd:653-660`) falls through to
  `home + jitter` for *every* action, and `home = pos` at spawn (`civilian.gd:187`) is
  `heli.global_position` — **the airframe's position, in the air**, carrying an airborne Y.
- So the replacement mills at the pad forever and mans nothing, and if
  `place_for_current_hour()` ever runs on him it teleports him to a point in the sky.
  **UNPROVEN** whether `SeatSystem.seat()` disables his physics tick before
  `civilian.gd:235-237` fires.
- Related drift: `heli_lift.gd:183-185` claims removing him from `firebase_garrison` is what stops
  `place_for_current_hour` teleporting him. `place_for_current_hour` (`civilian.gd:639-650`) reads
  **no group at all**. The comment is a lie in the map.

---

## P1-7. THE PRESS CANCELS THE INDIVIDUAL ROUT — and that is the one place it is raised on a man who is running

Asked and answered, in order:

- **Does a pressed man still shoot? YES — verified.** `siege_press` feeds only
  `Context.assault_press` (`enemy_base.gd:1221`), which only adds `PRESS_ADVANCE 0.75` to the
  ADVANCE score (`combat_goals.gd:113-118`). `ADVANCE` → `AIState.ADVANCING`
  (`enemy_base.gd:1284-1285`) → `_execute_advancing`, which calls `_fire_at_target()` on **all
  four** of its branches (`:1592-1594`, `:1612-1613`, `:1631-1633`, `:1643-1650`). The legs stay
  with the combat brain; nothing sets `assault_driven`. This part of the design holds.
- **Dead men? No.** `siege_director.gd:387` skips `m.is_dead()`.
- **Sappers? No.** `:384` skips `c.carries_charge` cells.
- **Cleared on every exit? YES — verified.** `break`, `wiped` and `dawn` all funnel through
  `_break_siege`, which clears `siege_press` on every man of every materialized cell
  (`:571-575`) *before* `withdraw_to`, and the reaped men are despawned later (`:608-613`) with
  press already false. The only hole is a cell that has become `!is_instance_valid` (`:566`), which
  nothing in this file does.
- **Men who are WITHDRAWING: YES, and this is the defect.** The *siege's* withdrawal is safe (see
  above), but a man routing on his **own** ladder — goal `RETREAT`, the individual rout /
  Chieu-Hoi path — is still a live, non-sapper man in a materialized cell, so `_rotate_press`
  (`:386-393`) raises the press on him. `RETREAT` tops out around
  `(0.6 + 0.4 + 0.7) × self_pres × numbers` (`combat_goals.gd:123-132`), realistically 0.3–0.9,
  while pressed `ADVANCE` clears 1.0–1.3. **A pressed man cannot individually rout.** One third of
  the assault has its rout ladder switched off for as long as the press cycle keeps it on
  (`PRESS_FRACTION 0.35`, `PRESS_CYCLE_S 8`). Arguably intended by "ordered to press", but it is
  nowhere written down and it changes the feel of two thirds of the fight.

Two smaller press notes:
- `share = maxi(1, int(round(1.0 / 0.35))) = 3` (`:389`) → the press is **33%**, not the declared
  35%. Harmless, but the constant does not mean what it says.
- `i` only increments for **live** men (`:394`), so as casualties mount the index shifts and the
  claim at `:379-380` — *"the same man is not pressed twice running"* — is false.
- `_execute_advancing` returns immediately on `not target` (`:1581-1582`) **without zeroing
  velocity**, so a pressed man whose target dies while he is mid-goal coasts on his last velocity
  until his next think. Pre-existing, **UNPROVEN** as visible.

---

## P1-8. THE DEMO'S DAWN CARD PLAYS OVER A LIVE ASSAULT — no break, no reap, no stand-down

`MAX_DURATION_S = 480` (`siege_director.gd:40`) measured from the *escalation* at
`SIEGE_AT_S = 720` lands at **t = 1200 s**, but `DAWN_AT_S = 1080` (`demo_game.gd:28`).
`_dawn()` (`demo_game.gd:216-243`) toasts *"DAWN. YOU HELD."*, builds the end card, and **does not
touch the siege**. `active` stays true, 45 men keep attacking behind the card, and because
`siege_ended` never fires:

- no withdrawal, no `_process_reap` → the men are never despawned;
- `field_director._garrison_stand_down` (`:1423-1431`) never runs;
- the *"FIRST LIGHT — THEY'VE MELTED AWAY"* beat the arc is built around never happens.

Also note the card is unconditional: it reads "FIREBASE HELD" whether or not the compound was
overrun.

Companion note: the `_on_siege_began` re-emit. `reinforce` re-emits `siege_began`
(`siege_director.gd:247`), so `field_director._on_siege_began` (`:1372-1383`) runs a second time
with `probe = false` → a second *"STAND TO"* toast and a **second siren**, stacked on the demo's own
*"HERE THEY COME"*. Three announcements for one event.

---

## P2 — SMALLER, STILL WRONG

| # | Finding | Pointer |
|---|---------|---------|
| 9 | `inside_count` takes the **max** radius per 10° bin, then subtracts a flat 6 m. On the steep faces the manifest's own radius moves 6–9 m *within* one bin (bins 3-4: 81.8→87.4 and 72.4→78.7; 16-17, 33 likewise), so the effective inside-margin swings between ~0 m and ~13 m depending on bearing. Men merely standing at the wall's outer face register as through it → premature OVERRUN. | `siege_director.gd:414-424`, `:449-466` |
| 10 | The one empty bin (bin 20, the gate gap) inherits **96.1 m** from bin 19 while its other neighbour is 89.4 m — a 7 m outward error exactly where the lane is. The fill loop itself is sound (wrap-around seed from the last non-zero bin, `:427-435`); no divide-by-zero and no out-of-range anywhere — `fposmod`/`clampi` are correct at `:422-423` and `:445-446`, and an empty group degrades safely to "nothing can be inside" (`:410-411`, `:450`). | `siege_director.gd:427-435` |
| 11 | `_bt_walk_fire` and `_bt_walk_home` have **no per-man jitter** — `home + Vector3(2,0,2)` and bare `home`. `_bt_settle` was given a name-hashed offset for exactly this reason (`:733-736`). Quarters are handed out round-robin (`mission_generator.gd:901-905`), so several men share one `home` and will stand inside each other at chow and at lights-out — the same "rifleman standing inside the marksman" defect the post spread was written to kill. | `civilian.gd:696`, `:680`, `:733-736` |
| 12 | `GarrisonDefender.stand_down` carries `garrison_occupation` and `garrison_unit` in meta (`:82-83`) but **not `home`**. The rebuilt Civilian's `home` becomes wherever he stood at dawn — on the wire (`Civilian.spawn` → `civilian.gd:187`). After night 1 the garrison sleeps, rests and cooks at its fighting positions. The docstring's claim to hand back "his job and his face" is two thirds true. | `garrison_defender.gd:93-114` |
| 13 | `stand_down`'s occupation default is `"cook"` — a **villager** occupation. The garrison's is `mess_cook` (`civilian_schedules.gd:170`). A man whose meta is lost runs the wrong schedule table. | `garrison_defender.gd:101` |
| 14 | `REAP_RADIUS_M = 600` is unreachable on a 512 m map (max distance from centre ≈ 362 m at a corner), and is **not** in the override set. The reap therefore rests entirely on `at_rally` (20 m) or the 90 s timeout. Works, but one of its three conditions is dead in the demo — as is the `ring_min/ring_max/rally/mortar_standoff` list's omission of `ILLUM_STANDOFF_M` (see P0-3). | `siege_director.gd:43`, `:608`; `demo_game.gd:192-197` |
| 15 | Map-edge check, for the record: **nothing lands off the map.** `ring_max 235`, `mortar_standoff 170`, `rally 150`, `NAPALM_RANGE 210` all sit inside the 256 m half-extent, worst case 21 m of margin on an axis bearing. But cells at 190–235 m are **outside the NavBaker firebase box** (`nav_baker.gd:43`, half 185 m) — harmless only because MarchingCell steers straight-line and its men materialize well inside. | `demo_game.gd:192-197`, `nav_baker.gd:43` |
| 16 | Two contradictory comment blocks inside one function about whether terrain reproduces the mound: `:1004-1012` says it does, `:1021-1030` says it explicitly does not. Drift, in the exact function P0-1 turns on. Correct on contact. | `site_planner.gd:1004-1030` |

---

## WHAT I CHECKED AND FOUND SOUND

- `_measure_perimeter` bin arithmetic, empty-bin fill, and the empty-group degradation. No
  divide-by-zero, no index out of range, safe on a parapet-less map.
- The press's shoot path — a pressed man does fire, on every ADVANCE branch.
- Press clearing on break / wipe / dawn / reap / despawn.
- `reinforce`'s own ledger discipline (`run_strength` and `run_peak` grow together; `nights_run`,
  `_elapsed` and `_mortar_timer` deliberately untouched) — the bug is in `open_siege`, not here.
- `_mortar_impact` excludes attackers from its own blast (`:528-553`), so the ranging walk cannot
  break the assault it belongs to.
- `withdraw_to`'s synchronous satchel disarm-and-detach (`marching_cell.gd:141-152`).
- The garrison schedule rewrite reads correctly for a night shift: at dusk, sentry, sentry_night,
  gun_crew, radioman and quartermaster are all on `ACTION_WORK` → `working_point_pos`, i.e. their
  own posts. No garrison occupation resolves to an off-base location. `home` is never
  `Vector3.ZERO` (`civilian.gd:187` defaults it to the spawn point), so the map-corner failure the
  brief asked about **does not occur** — for men built by `_build_firebase_garrison`. It is only
  the heli replacements (P1-6) whose `home` is nonsense.
- Group bookkeeping: `promote`/`stand_down` move a man between `firebase_garrison` and
  `garrison_promoted` exactly once each; the stand-to latch plus the per-man group check make
  double-promotion impossible; `get_nodes_in_group` snapshots make the mutate-while-iterating in
  `_garrison_stand_down` safe; `heli_lift.garrison_strength()` counts both groups deliberately
  (`:107-108`) and only ever adds/removes **Civilians**, never a promoted AllyBase. No
  double-count found.
