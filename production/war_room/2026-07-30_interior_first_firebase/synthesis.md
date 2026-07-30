# THE DECREE — Interior-first, a living firebase, and the sleep loop

Council: level designer/tech artist · systems architect · AI designer · devil's advocate.
Four architects, parallel, no cross-talk. Full analyses in `analysis/`.

**His deadline, stated 2026-07-30: one solid week to a shareable demo-scope build.** Everything
below is judged against that. **His clarification:** parts of the firebase exist but need
REWORKING; he wants **MASTERS** of the buildings and then more of them; **only half the compound
is occupied**; he needs more barracks and aux buildings. And a validation worth spending on:
*"getting the basic heli landing and seeing the fly bys did add to the immersion big time."*

---

## THE ONE NUMBER THAT DECIDES THE WEEK

Measured directly out of `fsb_main_v3.glb` by the Arbiter, confirming the level designer:

| | |
|---|---|
| visible draw calls in the firebase | **826** |
| of which are the 178 interior props | **368 — 44.6%** |
| share of triangles those props represent | **3.75%** |

**Nearly half the draw budget buys 4% of the geometry.** On a CALL-BOUND project
(`PERF_LEDGER.md`) that is the whole story. MultiMesh per prop type takes 178 → ~11 calls and
returns ~350 calls. **That is what funds "way more firebase."** Tri budgets are style, not perf
— already measured. Do not cut triangles; cut CALLS.

Three compounding fixes, in order of value: one material per prop mesh (a cot is 3 primitives)
368 → 178 · MultiMesh per type 178 → ~11 · `visibility_range_end ≈ 38 m`, which
`place_firebase_main` never applies at all. Plus delete ~180 per-prop `-colonly` boxes (30 of
them are invisible head-height posts on hanging bulbs).

## THE HARD CEILING NOBODY GUESSED

**MultiMesh cannot skin.** So an ANIMATED casualty costs 40–80 draw calls. Ten occupied beds =
400–800 calls, more than the entire firebase. **Ruling: cap animated patients at 3–4; every
other occupant is a shrouded static in the MultiMesh, where rotating occupancy costs ZERO
calls.** Art constraint that follows: patients must be BLANKETED. Body bags are one shared
static MultiMesh — **one call for any count.**

Same logic on bodies: patients and bags are **props, never agents**. 12 patients as Civilians
would be ≈ +7.2 ms (~18% of a 38–40 ms wall) for men who lie still. Garrison goes 24 → 28
(+2 medic, +2 orderly, +2 officer, +2 runner, −4 by dropping `FSB_WORK_POST_CAP` 12 → 8),
≈ +2.4 ms. LOD does not help: `civilian.gd:239-242` skips a body only at 300 m and the base is
~369 m wide, so the whole garrison is full-cost from inside the wire.

---

## THE SLEEP LOOP IS THE KEYSTONE — and it makes the siege reachable

His ask: lie down and sleep → clock advances 8 h → sometimes you are woken by a fellow soldier
because the firebase is under attack → straight into the fight.

**This is not a new system. It is the missing key to a system already paid for.**
`SiegeDirector._maybe_open` already rolls ONCE PER NIGHT against `NIGHT_CHANCE` by earned threat
tier (LOW 0.05 → CRITICAL 0.45) with `MAX_RUN_NIGHTS 3`. That cadence is currently
**unreachable**, because nothing makes the player present at night — which is exactly why the
demo has to FORCE a siege on a wall-clock timer. Sleep makes the roll meaningful, makes the
3-night run chain a real arc across several sleeps, and retires the forced timer.
His own spawn markers (`spawn_bunk_01/02`) are already bunk positions inside the hootch, so the
sleep station and the spawn point are the same authored place.
Existing beats to reuse, not rebuild: `_garrison_stand_to()`, `SirenTower`, the "STAND TO"
toast, and the ranging mortars that announce the night before the siren.
**Design consequence:** waking into a siege must never be a cutscene — he wakes at his bunk, in
the dark, with the siren already going. The wake-up shake is a new beat; the trigger is not.

---

## THE CASUALTY LEDGER DOES NOT EXIST — that is the finding

Confirmed independently by two architects. No casualty field in `CampaignState` or
`MissionState`; zero hits repo-wide for wounded/WIA. `result["squad_kia"]` DOES reach the AAR
(`squad_system.gd:441`) and `on_mission_end` (`:204-237`) **throws it away**, then
`ensure_roster` (`squad_roster.gd:165-173`) deletes the dead.

Minimal build, and it is small: `CampaignState.kia_total` (never clears) + `ward_wounded`, and
`MissionState.friendly_wia` fed by completed revives. Occupancy = **his seeded 1–2** + real
arrivals + drain by bearer evacuation. `SAVE_VERSION` must bump.
**Never-blink rule:** a bed may change state only pre-visibility, via a carry, or off-camera.
Graves lift the bag stack on an LZ cycle only at ≥6 bags AND ≥1 sim day old, so the first bags
always sit through a night. `kia_total` never decrements.

---

## HIS FORM-UP-OUTSIDE RULE IS A MEASURED NAV FACT

He was right by eye. `GroupWalk`'s 1.6 m spacing (`group_walk.gd:34-36`) needs ~4.2 m of clear
width; a tent aisle is 1.5–2 m. And `nav_baker.gd:44-46` `GRID_STEP 4.0` against an 8×6 m aid
station (`collision_table.gd:72`) is **below pathfinder resolution**. Forming up inside is
physically impossible, not merely ugly.
`GroupWalk` itself needs no change; three gates do — garrison men never get a `group_id`
(villager-only, `mission_generator.gd:948`), `walk_litter` must join `GROUP_WALK_ACTIONS`, and an
`override_action` must survive the sim-hour rollover or a dustoff crossing an hour yanks both
bearers mid-carry. **Trigger on `inbound`, not `ground`** — 35 s of ground time cannot cover a
46 s carry. Front bearer stops at the sill; the pivot happens outside.

**HQ traffic: door-marker despawn, and runners never enter.** Interior props are not in the
navmesh source (`nav_baker.gd:208`), so a man pathing inside clips the field desk. The tent
canvas is the occluder. Two officers and a radioman are permanent real bodies at the map inside.
Accepted hole: standing in the flap, you would see the vanish.

---

## MASTERS — why his instinct collapses the cost

The firebase is ~20 structure FAMILIES over ~80 placements but only **~8–10 distinct building
TYPES**. Destructibility per placement ≈ 272 authored meshes. **Per MASTER: 8–10.** An order of
magnitude, and the same is true of interiors. Masters are the reason his ask fits a week.

**A room is a chunk — but a `.tscn`, not a GLB**, because a GLB cannot hold a MultiMesh, a
visibility range, a `Destructible` or a shader. Ownership contract, and nothing hand-authored is
ever placed by a literal transform — **only by a marker**, which is what makes it survive a
re-export AND follow its host:
- **generator** owns ground, shell, and markers (emits a `room_*` anchor only)
- **room GLB** owns interior geometry + ONE collision proxy
- **`.tscn`** owns MultiMesh, collision, visibility range, shader, Destructible

**Delete the `fb_int_` bake in the same change or every prop doubles** (ADR-023).

## DESTRUCTION, RESOLVED AGAINST ADR-031

`FellableTree` (`fellable_tree.gd:95-137`) **already hinges and swaps** — fold it into
`Destructible` as `topple_time` and delete its duplicate `take_damage` (a second damage
authority, against ADR-031 §6). Two states only: intact → 1.2 s lean → down. **Cut the resting
"leaning" tier** — one authored mesh for one second of screen time. The lean is a transform
write on an already-drawn mesh: zero new draw calls, and it runs OFF the destruction queue, so
`STRUCTURE_LEVELS_PER_FRAME = 2` is untouched. What sells it is the silhouette leaving the
skyline, the existing burst fired at the BASE, and permanence.

**PERF WARNING before any rubble art is authored:** `destructible.gd:69-72` instantiates a fresh
`MeshInstance3D` per destroyed structure when `destroyed_mesh` is set. Nothing sets it today, so
it costs zero — but authored rubble across ~96 placements would add ~96 unbatched calls *during
the siege*, on a frame already at 411–464. **Rubble must be shared masters through one
MultiMesh**, the pattern that file already uses for scatter. Decide this before modelling.

## OCCUPANCY — ONE CONTRACT, replacing three

`Post` (a Node3D child of the structure): claim/vacate/eye/face, plus
`Post.evict_all_under(host, cause)` called by ONE new line in `Destructible._do_destroy`.
Vacate order: `dismount_mg()` first (restores the player's collider), clear `post_anchor`, then
kill — inside = dead, on the deck = dropped.
**It DELETES:** `MortarPit`'s entire occupancy API (**zero callers repo-wide — UNFINISHED, not
live**), `MGEmplacement.occupant/_clear_occupant/is_occupied/_physics_process`, and
`FellableTree`'s damage path. Three implementations become one.

**The risk that outlives this:** destruction is not a validity change. `_do_destroy` never frees
the node, so every `is_instance_valid()` self-heal misses it — `mg_emplacement.gd:83-90` and
`player.gd:1126` both pass forever, and `siren_tower.gd:149` already worked around it by reading
a *mesh's* `.visible`. `Destructible.is_destroyed()` exists with **zero callers**; if this change
does not make it THE answer, the next three features each invent their own guess.

## BETTER MUD — free, and the best atmosphere-per-millisecond on the list

Today: a 27,968-vert mound with ONE `fb_earth` material, 256 px box-projected at 1.6 m —
uniform and visibly tiling — plus 24 flat opaque `fb_mud_patch` decals = 24 draw calls with hard
polygon edges sitting 2 cm off a curved surface.
Ruling: **bake a wetness mask into the mound's vertex colour** (`COLOR_0` is already in the
pipeline) from craters, traffic paths and concavity — zero draw calls, and it kills the tile.
**Retire `fb_mud_patch` into it** (ADR-023). Put the shader as a `material_override` on
`fb_terrain_mound` in `firebase_main.tscn` — inherited scenes override by node path, so it
survives every re-export. Generator owns the mask; the scene owns the look.

---

## DRIFT CORRECTED ON CONTACT (measured, 2026-07-30)

- **"21 props UNEXPORTED" is FALSE** — 21 GLBs on disk since 7/26 **and 178 instances baked into
  `fsb_main_v3.glb`**. The aid station already holds 2 litters; the HQ's map board, plotting
  board, field desk, radio shelf and field phone already exist and are placed.
- **The "19 marker-GLB chunk kit" DOES NOT EXIST.** No `chunks/` dir, no contract, no recipes,
  zero `.gd` references. The firebase asset dir holds **7 GLBs**: `fsb_main_v3`, archived
  `fsb_main`, and 5 kit pieces — one of which is the **BANNED** `fb_sandbag_heavy`, still
  importable. **The station-attaches-as-chunks decree has no chunks to attach.**
- **The mortar pit exists THREE times** — 2 baked (`fb_mortar_pit_i` ×2) + 1 instanced at
  `mission_generator.gd:796` with its own nest/tube/crates, seated by `get_height_at` which
  `game_world.gd:400` says buries things in this compound.
- **"Mannable MG is the top DEFERRED feature" is FALSE** — built, placed and manned on both
  sides (`mission_generator.gd:882`, `player.gd:1069`, `garrison_defender.gd:63-67`).
- **`site_planner.gd:743-751` contradicts itself** — claims the fighting step needs no Blender
  and the mound plate is stripped; `:1124-1130` keeps the plate, and manifest `step_h: 0.0`
  makes `_fighting_step` return 0, **so no fighting step exists anywhere**.
- **The shipped GLB (7/26) predates the 7/29 generator edits** — sandbag colliders are still
  24-vert boxes in the asset the game actually loads.
- **Six BT leaves are STILL byte-identical freezes** (`_bt_rest/_bt_cook/_bt_sleep/_bt_fish/
  _bt_sit/_bt_talk`). Only `_bt_work` was fixed on 2026-07-30, so `mess_cook` still cooks
  wherever he happens to stand.
- **`CampDirector` has no path to a `Civilian`** — it is the VC camp director, NOT the firebase
  mechanism the station decree implies.

---

## THE WEEK

His Blender time and the code run in PARALLEL. That is the schedule.

**BLOCKER, before any tent art: interior-first has no consumer.** `US_INTERIOR_PROPS` has zero
hits and `place_firebase_main` never calls `_furnish_interior`/`_collect_stations`.

**Slice 1 — ONE HOOTCH, END TO END (the proof).** ~16 props, one material, one room GLB, the
`fb_int_` bake deleted, MultiMesh + visibility range, a `RoomKit` marker anchor. Eight hootches
go **~250 calls → ~16** with half again as many props. One session, and it is the template for
every master after it. **Nothing else starts until this lands.**

**Then, in order:** better mud (zero calls, biggest atmosphere return) · the casualty ledger +
body-bag MultiMesh · the barracks and aux MASTERS to fill the empty half · the `Post` occupancy
contract + tower topple · HQ traffic and nurse rounds (only after A4 is confirmed by his eyes).

**CUT to protect the week:** occupiable-and-shootable bunkers (the slits and proxies exist, but
camera, aim clamping, entry/exit animation and AI usage are a feature, not a fix) ·
"all buildings destructible" → only what the siege attacks, towers and wall bunkers ·
"way more firebase" as an open-ended ask — it needs a LIST before it can be costed.

**The real risk is not scope.** Nothing from 07-29 or 07-30 has met his eyes, a previous audit
found 4 of 4 "shipped" items were fiction, and the full parse gate is still owed because his
editor was open. **His playtest is the critical path, not features.**
