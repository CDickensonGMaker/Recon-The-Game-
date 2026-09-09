# THE DEBATE — 2026-09-09

Phase 3. Architects respond to each other. Agreements noted; disagreements explicit with the
tradeoff named. The Arbiter records conflicts rather than smoothing them.

---

## AGREEMENT 1 — THE FIVE OBSERVATIONS ARE NOT ONE PROBLEM, AND FOUR OF THEM ARE NOT THE FIREBASE

Every lens that looked at the five converged on this independently.

**UX designer, ranking by player-facing severity:**

| # | observation | severity | first ten minutes? |
|---|---|---|---|
| 1 | ladder trap | **RUN-ENDING** — on HARDCORE `can_manual_save()` is hub-only (`save_manager.gd:76-82`), so a wedged hardcore player has zero in-game recovery | likely |
| 2 | NPC stacking | **CRITICAL (Pillar 2)** — reads as the engine failing, not the world being sparse | certain |
| 3 | Huey dropoff | **HIGH — it is the demo's SECOND BEAT**, `lz_cycle` on the pad at **T+14 s** (`demo_game.gd:268`), another at T+95 s | certain |
| 4 | no dirt roads | **MEDIUM-HIGH, cheapest win on the board** | certain — squad moves out at T+10 s |
| 5 | convoys | **LOW, and gated behind roads** — a truck on bare jungle floor reads worse than no truck | no |

> **UX's decisive line: "None of the four is a firebase-geometry problem."**

**This is the finding that governs the whole session.** He reported the five in one breath with a
firebase pivot, and the natural reading is that the pivot fixes them. It does not. Four are ordinary
defects with ordinary causes, and three of them were root-caused tonight to a **single line or a single
missing stagger.**

## AGREEMENT 2 — THE KIT'S DATA WAS ALREADY BUILT IN JULY AND NEVER WIRED

Found independently by the **technical director** and the **Arbiter**, from different directions.

- `firebase_set.json` — **23 parts**, each with `markers` carrying `work_type`, `prop_class`,
  `door_width`, `face`, local `pos`. Dated 2026-07-26. **Nothing in `scripts/` reads it**; the only
  reference in the repo is `tools/gen_firebase.py:932`, which writes it.
- `firebase_v3_destructibles.json` — **all 80 wall positions** plus box, kind and hp. The code today
  reads only name/kind/hp (`site_planner.gd:2192-2205`), so **`pos` is unused data already on disk.**
- `gen_firebase_v3.py:709` `STATION_PLAN` — per-part work stations for **19 families**.

> **Technical director: "His 'work points saved to those locations' was built in July and never wired."**

And the **Arbiter's own sight** found why it was shelved — `tools/gen_firebase.py:1-13`, the tool's own
docstring: *"shipping 24 kit GLBs would be 24 files with one consumer, which ADR-023 would correctly
come for."* **The kit was killed by the fossil law for having no consumer. The pivot supplies the
consumer.** That is the strongest canon-grounded argument for the pivot in the project, and it is the
project's own words. It cuts both ways and the decree must say so: **authorise the consumer, or the
parts are a fossil again.**

## AGREEMENT 3 — THE MIGRATION IS INCREMENTAL BY CONSTRUCTION, AND THE MECHANISM IS ALREADY SHIPPING

- **Arbiter:** `SitePlanner._wire_m101_rigs()` (`site_planner.gd:846-866`) already does exactly this
  once — find the baked node by name, **hide it (never free it, its `-colonly` colliders stay live)**,
  instance a separate kit GLB at `baked.global_transform`, hide the chunk's own crew, `push_warning` on
  zero matches. Generalise that one function and you have the migration.
- **Arbiter:** the docking point exists and is already blessed. `FSB_MAIN_PATH` is
  `res://scenes/world/firebase_main.tscn` (`site_planner.gd:946`) — the game loads a **13-line scene**
  that instances the GLB and carries hand-placed markers, on the ruling of 2026-07-29, with
  ADR-028 explicitly satisfied: *"the build instances this scene exactly where it used to instance the
  GLB."*
- **Technical director**, going further and better: the legal shape is **migrate the INPUT, not the
  code** — per family, in one commit, re-export the monolith MINUS family F, stamp F from the kit under
  the same wrapper root, delete the repair code that existed for F's baked form. **One path whose input
  set shrinks by one family per commit.** Revert is one command (`reexport_firebase_v3.py`), not a code
  revert.

**The Arbiter prefers the technical director's shape over his own.** `_wire_m101_rigs` swaps VISUALS
while the bake's colliders stay live — it cannot fix a collision defect, and a firebase migrated that
way would carry two of everything. Shrinking the export is the honest version. **`_wire_m101_rigs`
remains the proof that a part can be seated correctly beside the monolith on the one path** — which is
what makes the technical director's plan credible rather than theoretical.

## AGREEMENT 4 — 14 SYSTEMS SURVIVE THE KIT UNCHANGED; THERE IS ONE HARD BREAK

**Technical director, measured:** siege breach scan, perimeter measure, sapper targeting, nav collider
seeding, blast bus, bunk spawn, helipads, screen doors, ladders, siren — **all read GROUPS
(`fsb_parapet`, `fsb_nav_geom`) or name PREFIXES, never the root.** The single break is
`nav_baker.gd:204`, which takes `nodes[0]`, one root — **fixed by one line**: stamp every part under one
`Node3D` wrapper and return that.

> *"The consolidation work of the last six weeks already paid most of the kit's integration bill."*

This substantially weakens the "everything shipped tonight is built around the single export" objection
in the brief. **The systems are built around GROUPS AND PREFIXES, not around the bake.** ADR-042's
naming contract, which looked like the pivot's biggest liability, turns out to be what makes the pivot
survivable — names are portable, roots are not.

## AGREEMENT 5 — THE HUEY IS A ONE-CONSTANT DEFECT, AND THE STANDING TRAP WAS STALE

The brief warned the council about `recon-staged-scenes-are-not-clip-banks` — *"`HeliLift.BOARD_CLIPS`
is empty; there was never a boarding animation to harvest."* **The systems designer refuted it with
measurement, which is exactly what that lens is for.**

- `heli_lift.gd:51` is `["board_heli"]` — **not empty since 2026-08-04.** `heli_lift.gd:38-41` names
  **six real `disembark_heli_*` clips on `PSXRig`.** The diorama story is not the answer.
- The real delta: `tools/export_anim_library.py:59-63` **strips Hips X/Z from every action in the
  library.** `ART_Track_Log.md:374-381` measured both sides — source `.blend` clips travel **2.37 m**;
  the shipped `.glb` clips travel **exactly 0.0 m**.

> **In Blender he watched men travel out of the ship. In the game `seat_system.gd:613-636` teleports
> all six at once, in one frame, into a fixed polar fan, and plays the clip in place.**

**And the asymmetry that names the bug:** `board_squad` in the same file staggers by
`BOARD_STAGGER_S = 0.6` (`:158, 641-669`). **Boarding is staggered. Disembarking is not.** ~1 h, ~15
lines, mirroring a function that already exists in the same file.

Two further measured facts the systems designer surfaced that the council must not lose: the exit fan's
**7.0 m cap sits inside the 7.32 m rotor radius**, and `_exit_ground` places every man **1 m in the air
and drops him** (`seat_system.gd:852`) — where that undocumented `+1.0` is the only thing keeping
`drop` (0.510 m) under the 0.8 threshold, so **removing it makes all six disembark clips unreachable
silently.** That is an ADR-042-class trap sitting in the file anyone would edit to fix the stagger.
**Record it in the fix brief or the fix will break the clips it exists to show.**

**His memory was not wrong and the build is not lying.** He genuinely saw better motion in Blender; the
export pipeline removes the travel by design. Correct the memory file — that is NO MORE DRIFT.

## AGREEMENT 6 — THE TOOL MUST BE AN IN-GAME DEV MODE, NOT AN EDITOR PLUGIN, AND THE FACT IS DECISIVE

**Godot specialist**, and it is not close: `scenes/levels/game_world.tscn` is **six lines and one empty
`Node3D`.** Every world node is built in code at runtime (`game_world.gd:100-131`). `TerrainEngine`
`extends Node`, not `@tool`. The project has **three `@tool` scripts, all data Resources, and no
`addons/` directory at all.**

> **In the Godot editor there is no heightmap, no navmesh, no vegetation — nothing to brush.**

An `EditorPlugin` would require `@tool`-ing the entire protected foundation — *"a second execution
context for the world build, which is ADR-028's named prohibition wearing a costume."*

And the precedent already exists twice: `tools/cursor_editor.gd` is a standalone game-process authoring
tool that writes JSON into `res://` (`:263-267`), and **the free-fly camera is already written and
shipping** — `player.gd:1576-1613` photo mode, with `reset_physics_interpolation()` already handled.

**Output format:** a **JSON site plan**, not a `.tscn` — carrying part ids + local transforms + an
ordered terrain-op array + markers + a declared flatten profile. The specialist's argument is the
strongest available: **the split already exists.** `plan_demo_world()` returns a Dictionary that
`build_patrol_world()` stamps unchanged. *"The tool writes that dict by hand instead of rolling it. No
new mechanism."* This satisfies ADR-041 §3's ten contracts by construction, because ids route through
the one `place_structure()` factory.

---

## DISAGREEMENT 1 — THE ROADS. TWO LENSES, TWO ANSWERS, AND THE ARBITER IS ONE OF THEM.

**This is a real conflict and it is recorded, not smoothed.**

**UX designer:** *"`road_network.gd:26-28` / `mission_generator.gd:911-915`: the only thing a road
writes is thinned vegetation."* Classified it an r4bk violation shipped for weeks — *"he walks onto a
road drawn on his own map and cannot see it; the map teaches him his instruments lie."*

**The Arbiter, measured independently, disagrees on the fact:**
- `scripts/world/road_network.gd:378-405` — `ROAD_DUST = Color(0.42,0.35,0.24)`,
  `ROAD_DUST_STRENGTH = 0.72`, `ROAD_HALF_WIDTH_M = 5.0`, `_stamp_dust()` → per-segment
  `ClearingSystem.stamp_ground_line()` → `flush_ground()`.
- `ClearingSystem.stamp_ground_line` **exists** (`clearing_system.gd:246-274`) — the `has_method` guard
  at `road_network.gd:395` passes.
- Shipped **2026-08-12, commit `85ab41cf`**, *"STEP 29: roads wear dust into the ground, using the splat
  that already existed."*
- The shader end is wired: `terrain/shaders/terrain.gdshader:104-106`,
  `color = mix(color, clearing.rgb, clearing.a)`, uniform fed at `game_world.gd:142` and refreshed by
  `_on_vegetation_updated` (`:534-537`).
- **And it ran today.** `[ROADS] dust stamped on 163 segment line(s)` appears in
  `recon2026-09-09T13.39.43.log`.

**The systems designer independently confirms the Arbiter's reading** — *"`road_network.gd:394-405`
already stamps dirt (`Color(0.42,0.35,0.24)` @ 0.72, 10 m band, 1 m/texel) along the exact polyline the
convoy drives."*

**Resolution: two of three lenses measured the same shipped paint, so UX's cited line is the STALE
COMMENT, not the code.** `mission_generator.gd:911-913` still says *"never height, never terrain_type,
never water"* — written before `85ab41cf` added the dust and never updated. **UX read the comment; the
Arbiter and the systems designer read the function.** This is the third time this session a stale
comment sent a lens down the wrong road, and it is exactly the failure `PLAYTEST_FINDINGS`' own header
warning describes.

> **THE CLASSIFICATION THEREFORE CHANGES: observation 5 is NOT "content never built."** The routing is
> built, the paint is built, the shader is wired, and the stamp fires. **It is a BUG NEEDING
> INVESTIGATION**, and the level designer holds the open thread with five ranked candidates — chief
> among them that `_stamp_dust` counts CALLS, not writes, so *"163 segment lines"* would print
> identically if every call had early-returned on a null `clearing_texture`.

**UX's severity judgement survives the correction intact, and is if anything strengthened.** A road on
his topo map (`topo_map.gd:155-162`) that he cannot see on the ground is worse when the paint exists and
fails to arrive than when it was never written.

## DISAGREEMENT 2 — DOES THE PIVOT FIX "PEOPLE FALLING THRU BERMS"?

He gave this as a benefit of the kit. **No lens has yet confirmed it, and one contradicts it.**

The 2026-09-09 register already records the measured cause of friendly NPCs on roofs, and it is **not
geometry**: `TerrainWatchdog`'s fall-through re-seat ran `surface_y` every 2 seconds on every live body
— a top-down ray taking the FIRST hit, **which under a roof is the roof**. *"A correct spawn was being
undone every two seconds forever."* That is a code defect that a kit does not touch.

**Held open for the devil's advocate**, who was tasked to prove it either way. **The decree may not
claim the pivot fixes falling-through until that returns.**

## DISAGREEMENT 3 — DOES THE KIT FIX THE 488/23 WORK-MARKER MISMATCH?

`FIREBASE_REWORK_INTENT.md` open question 3 hopes part-carried markers make the mismatch *"impossible by
construction."*

**The systems designer refutes this with arithmetic.** The 23 is **a code constant, not an authoring
accident**: `clamp(40 − 17, 0, 24) = 23` exactly (`site_planner.gd:1419, 1230, 1240, 1100-1116`).

> *"Parts make the ratio tunable per site (488 → ~150), they do not make the mismatch impossible — the
> perf cap stays."*

And the other half of the 488 is not an authoring intention either: **209 of the 488 (43%) are 19
markers × 11 duplicated hooches**, every name carrying a Blender `.001…​.011` suffix.

> **Systems designer: "His kit is not a new idea; it is undoing a duplication that already happened in
> Blender."**

**The decree must state plainly that the kit narrows this ratio and does not close it.** Claiming
otherwise is how a pivot gets oversold.

---

## THE ARBITER'S NOTE ON WHAT IS STILL OUT

Three lenses have not reported: **lead programmer** (the ladder root cause and its probe; work-point
exclusivity), **level designer** (the road thread above; stamp granularity and the part list), and the
**devil's advocate** (draw calls under instancing on an Intel UHD bench; which of the five the pivot
would NOT fix; the berm question). **The decree is not written until they land** — particularly the
draw-call measurement, which is the one technical argument that could refuse the pivot outright and
which the technical director explicitly flagged as **genuinely unknown**: `place_firebase_main` never
calls `_apply_visibility_range`, so whether a stamped compound draws more or fewer calls than the merged
monolith **has never been measured in either direction.**

A second matter — **may the war at range be resolved abstractly** — is seated in
`briefing_distant_war.md` with its own architects out. It is not a footnote to this one and it will not
be merged into it.
