# THE DECREE — the firebase becomes a kit, and four of his five defects were never the firebase

**2026-09-09 · Arbiter: the Overseer · Nine architects · Summoner: Caleb**

> **HE RULED IT MID-COUNCIL, so this document is a PLAN, not a verdict.**
> *"but even before that we should make a modular world building tool kit" · "and turn the firebase
> into model pieces we can build sets with" · "so i actually would want to make a better bunker" ·
> "and we need a better hq that doesnt have floating lightbulbs" · "and a better gate house."*
>
> Law 3: the Summoner holds final authority. The council's job from here is the order, the risk and
> the price. **The verdict section below is kept only because he is entitled to know what his own
> council would have advised, and because two of its findings change how the work should be phased.**

---

## 1 · THE ARGUMENT THAT SHOULD LEAD, BECAUSE IT IS HIS OWN

**A single floating lightbulb in the HQ cannot be moved without re-exporting a 43 MB monolith.**

That is the whole case, and it is not an abstraction. Tonight, in this session, a `-colonly` suffix in
the wrong position on ONE ammo crate needed a Blender re-export and his permission to touch his art
source. `fb_aid_station` matches zero nodes because the asset was renamed to `medical_complex` inside
the bake. `fb_sbg_seg_046_001` is a Blender `.001` duplicate that ships invulnerable among 80
destructible twins. Every one of those is a **five-second edit trapped behind a forty-minute pipeline
and a permission prompt.**

**In a kit, a bulb is a placed object. Anyone nudges it. Nobody opens Blender.**

> **BEFORE ANYONE CHASES THE BULBS, CHECK WHICH BULBS.** 545 `fb_int_` props were folded into 69
> MultiMeshes four hours ago (commit `d904fd70`, 13:15 today). Establish whether the bulbs float in
> the **source bake** — a placement defect, which is the argument above — or whether the fold or the
> visibility-range work moved them. The prior 2026-08-30 collision audit already measured
> *"hanging bulbs (+7.8m)"* as **correctly** above the terrain heightmap because inside the firebase
> **the model is the ground**. That number is not evidence of a defect. Measure the bulb against its
> own ceiling, not against the terrain.

## 2 · THE THREE PROOF PIECES ARE THE ACCEPTANCE TEST, NOT A CONTENT LIST

**A better bunker · a better HQ with no floating bulbs · a better gate house.** Build the toolkit far
enough to produce those three and no further.

**The gate house is the one that proves the data model**, and it should be built LAST of the three for
exactly that reason. A gate is not geometry — it is an entrance. It brings a guard post, a work point,
an animation, a check, an NPC who belongs there, a road arriving at it, and **a gap in the wire that
the defensive doctrine and the sapper breach chain both read.** If a part can carry all of that, it can
carry anything. If it cannot, better to find out on piece three than on piece thirty.

And it ties three of his five observations into one: **a gate house is where a road meets a base, and
the convoy drives the road.** Roads, convoys and the gate are one problem seen from three sides.

## 3 · THE FINDING THAT GOVERNS THE WHOLE SESSION

> **Four of the five things he reported are not firebase-geometry problems, and the kit fixes none of
> the five.**

Every lens reached this independently. The Devil's Advocate put it hardest and the Arbiter accepts it:
**the pivot fixes NONE of the five observations.** He reported them in one breath with the pivot, and
the natural reading — that dissecting the base addresses them — is false. They are ordinary defects
with ordinary causes, and three were root-caused tonight to **a single line or a single missing
stagger.**

**This does not argue against the pivot. He has ruled it and it has its own justification (§1).** It
argues that the pivot must not be sold as their fix, and that the five must be worked on their own
track, starting now.

| # | observation | classification | cause, measured |
|---|---|---|---|
| 1 | ladder wedge | **(a) known — FIXED TONIGHT** | blind teleport, no clearance test |
| 2 | NPC stacking | **(a) known, four causes at once** | the plan puts men on top of each other; no NPC avoids any other NPC |
| 3 | Huey dropoff | **(a) known** | boarding staggers, disembarking does not |
| 4 | convoys | **(a) known + PARKED BY HIM** | one convoy, alive 13–17 s, chain-pulled tail |
| 5 | dirt roads | **(a) known — TWO arithmetic causes** | tangent clearing bubbles; painted the firebase's own colour |

## 4 · THE FIVE, IN FULL — none fell on the floor

### 1 · THE LADDER WEDGE — **FIXED, PROVEN, AND THE SANDBAGS WERE INNOCENT**

**REFUTED first, so nobody re-derives it: no sandbag is involved.** The nearest sandbag mesh of any
family is `fb_sbg_seg_026`, **3.91 m** from any ladder waypoint. What he read as sandbags is the
tower's own parapet — deck 9.77, wall band 9.8→10.65, roof 11.84. **The asset is fine. No `.blend`
needed touching**, which matters tonight because a Blender agent is inside it.

**The real cause was worse than he described.** All three position writes in the climb state machine
wrote `global_position` with **zero clearance test**, off three constants
(`FACE_OFFSET` / `DISMOUNT_LIP` / `DISMOUNT_IN`) **ported wholesale from CatacombsOfGore** — the file
header says so — and never re-measured against this tower. Measured against `fsb_main_v3.glb`'s own
`-colonly` meshes with the player capsule (r 0.40, h 1.80):

- **The BOTTOM step-off deposits the player 0.31 m INSIDE the tower shell on 3 of the 4 ladders in the
  game, every single time.**
- The same three top out with **0.07 m** of margin.
- No constant fixes it: the obstruction is ~1 m deep, so sweeping `FACE_OFFSET` goes
  0.55 → 0.09, 0.70 → 0.00, 0.85 → 0.00, 1.20 → 0.29, 1.50 → 0.52.

**Why tight became wedged:** `site_planner.gd:1823-1832` forces `backface_collision = true` on every
concave shape in the compound. **A body written inside one has no face to escape through in either
direction.** And the player has no unstick watchdog — though `enemy_base.gd:206-232` and
`ally_base.gd:56-83` both give one to every AI. *We built it for the men who cannot file a bug report
and withheld it from the man who can.*

**SHIPPED:** `Ladder.dismount_point()` and a new `Ladder.step_off_point()` now resolve their point
against the world — 8 bearings × rings of 0.25 m to 1.5 m, lifts **both ways**, every candidate
required to fit the capsule **and have ground under it**. If nothing is clear the ladder returns
`NO_CLEAR_POINT` and **the player stays on the rail** with an on-screen line (r4bk), because a hardcore
sim may refuse an unstick but **may not walk the player into a wall he did not choose and then refuse
him one** — and on HARDCORE `can_manual_save()` is hub-only, so a wedged player has no recovery at all.

**PROVEN:** `tests/test_ladder_dismount.tscn`.
- With the fix: `PASS` — `4 ladder(s), 4 of 8 nominal point(s) blocked before resolving, 1 with no landing`.
- Resolver reverted: **6 FAILURES** — all four ladders' step-off *"is INSIDE geometry"*, plus two
  no-ground failures.

**TWO THINGS THE PROBE TAUGHT ME, both recorded because they are the lesson:**
1. **My first resolver fell back to the rail point when it found nothing — a spot in mid-air at the top
   of a tower.** The probe failed it: *"a wedge traded for a fall is not a fix."* Removed.
2. **My first probe measured a world that does not ship.** Every structure in the GLB winds inward, so
   in a bare instantiate the tower decks **have no top** and a downward ray falls through. The probe
   now forces 1,904 concave shapes double-sided to match what `place_firebase_main` does at boot. **A
   probe that skips a repair the shipping path always performs measures a world nobody plays.**

**ONE OPEN ITEM, RECORDED AS A RATCHET, NOT CLOSED.** `Ladder_1`'s top at (71.46, 10.31, −22.96) has
**no landing surface at all** — a 5 × 5 m grid at six heights finds nothing solid, no deck, no wall,
open air. The probe carries `BASELINE_NO_LANDING = 1` so the count can never grow unnoticed.
**UNVERIFIED and stated as such:** the probe forces windings but does not run the box-hull re-meshing
the shipping path also performs, so a collider that path *creates* would not exist here. **Do not
report "a tower has no deck collider" off this number until that is checked.**

### 2 · NPC STACKING — **not a regression; the 8/24 ruling shipped and is intact**

All four claims of commit `5ed4b181` verified present today. **The ruling shipped as "one man per
marker"; the defect is that a marker is not a place.** Four causes, live simultaneously:

- **No NPC collides with or avoids any other NPC.** `civilian.gd:340,369-370`,
  `enemy_base.gd:3202-3206`, `ally_base.gd:2480-2484` — avoidance off, mask = world only, 0.30 m bodies.
  **Even a perfect claim ledger cannot stop two men standing in the same metre.**
- **The plan itself puts men on top of each other:** 35 posts / 38 men, **19 pairs under 3.0 m, five
  under 1.0 m** — five men in a 2.2 m box at the chow servery.
- `mission_generator.gd:1133` `quarters[qi % 4]` — **9 men aimed at one identical coordinate.** The
  exact modulo the 8/24 ruling killed elsewhere.
- `mission_generator.gd:1302` undoes the deal 73 lines later for village households.

**REFUTED:** multi-man posts (correctly ringed at 1.8 m) and unreleased claims. **And the 488-vs-23
ratio is a red herring — the dealer is correct.** The 23 is arithmetic: `clamp(40 − 17, 0, 24) = 23`.

**HIS RULING NEEDED** before the main fix — see §7 Q2.

### 3 · THE HUEY — **and the standing trap was STALE, corrected on contact**

The brief warned the council that `BOARD_CLIPS` is empty and there was never a boarding animation to
harvest. **The systems designer refuted it with measurement**, which is what that lens is for:
`heli_lift.gd:51` is `["board_heli"]` — not empty since 2026-08-04 — and `:38-41` names **six real
`disembark_heli_*` clips on `PSXRig`.**

**The real delta, and his memory is not wrong:** `tools/export_anim_library.py:59-63` **strips Hips
X/Z from every action in the library.** `ART_Track_Log.md:374-381` measured both sides — the source
`.blend` clips travel **2.37 m**; the shipped `.glb` clips travel **exactly 0.0 m**.

> **In Blender he watched men travel out of the ship. In the game `seat_system.gd:613-636` teleports
> all six at once, in one frame, into a fixed polar fan, and plays the clip in place.**

**The bug names itself:** `board_squad` in the same file staggers by `BOARD_STAGGER_S = 0.6`.
**Boarding is staggered. Disembarking is not.** ~1 h, ~15 lines, mirroring a function already in the
file. It is the demo's **second beat** — `lz_cycle` on the pad at **T+14 seconds**.

> **A TRAP FOR WHOEVER TAKES THIS, and it must ride in the fix brief.** `_exit_ground` places every man
> **1 m in the air and drops him** (`seat_system.gd:852`). That undocumented `+1.0` is the only thing
> keeping `drop` (0.510 m) under the 0.8 threshold — **remove it and all six disembark clips become
> unreachable, silently.** The exit fan's 7.0 m cap also sits **inside** the 7.32 m rotor radius.

### 4 · CONVOYS — **he asked for work on something he himself parked**

`GAME_GUIDE.md:326` and `PLAYTEST_FINDINGS:338`: *"Real convoy that forms up and drives out. **Your
ruling 2026-08-28: 'and same with the convoy.' Build nothing.**"*

**Two different things wear one word and the council refuses to merge them.** The PARKED thing is a
convoy that forms up and drives out as a set piece. The LIVE thing is the ambient convoy already
driving `RoadNetwork.longest_route()` — **that is what he just watched and disliked.** Polishing the
live one is a bug fix and **gate-exempt**; building the parked one is a thawed epic and is not.

Ranked failures of the live one: **one convoy per operation, alive 13–17 seconds** (he saw the only one
the world produces) · trailing vehicles chain-pulled toward the vehicle ahead, so the tail cuts every
bend off the road · `spacing` 6.0 m vs the deuce's 7.10 m box = **1.10 m of nose-to-tail overlap** on
75% of vehicles · yaw-only rotation, so flat trucks on slopes · `StaticBody3D`, `collision_mask = 0`,
moved by direct position writes — **it drives through the world and through the player** · silent,
frozen wheels, no dust · carries no passengers. **A+B+C ≈ 3 hours closes the four worst.**

### 5 · DIRT ROADS — **built, painted, running tonight, and invisible for two arithmetic reasons**

**A conflict the council resolved rather than smoothed.** One lens reported *"the only thing a road
writes is thinned vegetation"* — reading a **stale header comment**. Two lenses read the function.
`RoadNetwork._stamp_dust()` tints `ROAD_DUST (0.42,0.35,0.24)` at 0.72 in a 10 m band into the
`ClearingSystem` overlay the terrain shader already mixes; shipped **2026-08-12**, commit `85ab41cf`.
**And it ran today** — `[ROADS] dust stamped on 163 segment line(s)`,
`recon2026-09-09T13.39.43.log`. Both stale comments are **corrected in this change**
(`mission_generator.gd:911-915`, `road_network.gd:26-38`).

**Four of the Arbiter's five candidate causes were refuted by measurement.** The real two:

1. **THE CORRIDOR CLEAR IS A CHAIN OF TANGENT BUBBLES.** `clear_corridor` calls `clear_area(p, 5.0)`
   once per polyline point, points are **10 m apart**, and the clear is a **sphere**. Radius-5 discs at
   10 m spacing are tangent: **cleared width at the midpoint is 0.00 m**, 21.5% of the corridor keeps
   its jungle, and a tree **1 m off the centreline survives at every 10 m interval** (5²+1² = 26 > 25).
   The dust underneath *is* continuous. **The road is a brown stripe with jungle growing out of the
   middle of it, every ten metres.** Fix: clearing stride ≤ 5 m. One loop stride.
2. **THE ROAD IS PAINTED THE FIREBASE'S OWN COLOUR.** `ROAD_DUST (0.42,0.35,0.24)` versus the
   `CLEARED` stage's *"Exposed dirt"* `(0.45,0.38,0.28)`. The firebase stamps CLEARED at **radius
   120 m** and the wire sits at 49.4–96.0 m, so the road's first stretch — **where he looks first** —
   composites to **ΔRGB 0.022 / 0.022 / 0.029** against a terrain noise floor of ±0.01. **Invisible by
   colour at the gate, and full of trees further out. Two mechanisms in the exact order he meets them.**

> **The Arbiter's own §5 finding was half wrong and is corrected against himself in
> `analysis/arbiter_own_sight.md`.** I proposed a `TerrainType.ROAD` `match` arm as "nearly free"
> without reading the module header that had already refused it, with two named blockers. **I invented
> a fix out of a `match` statement for a file whose header answered me in advance, in the negative.**
> The finding that he has never seen a road survives; the fix I attached to it was not mine to invent.

## 5 · THE PLAN — phases, with the game playable at every commit

### The legal shape: MIGRATE THE INPUT, NOT THE CODE

Not a flag, not a second path, not a parallel builder. **Per family, in one commit: re-export the
monolith MINUS family F, stamp F from the kit under the same wrapper root, delete the repair code that
existed for F's baked form.** One path whose input set shrinks by one family per commit. **Revert is
one command (`reexport_firebase_v3.py`), not a code revert.**

Three facts make this credible rather than theoretical:

- **The docking point already exists and is already blessed.** `FSB_MAIN_PATH` is
  `res://scenes/world/firebase_main.tscn` — the game loads a **13-line scene** that instances the GLB
  and carries hand-placed markers, on his own 2026-07-29 ruling, with ADR-028 explicitly satisfied in
  the file's own comment: *"the build instances this scene exactly where it used to instance the GLB."*
- **The swap mechanism already shipped, once.** `SitePlanner._wire_m101_rigs()` finds a baked node by
  name, **hides it (never frees it — its `-colonly` colliders stay live)**, instances a separate kit
  GLB at `baked.global_transform`, and warns on zero matches. It is the migration, with the family as a
  parameter. *(Its limit, named: it swaps VISUALS only. Shrinking the export is the honest version.)*
- **14 systems survive a kit UNCHANGED, and there is exactly ONE hard break.** Siege breach scan,
  perimeter measure, sapper targeting, nav collider seeding, blast bus, bunk spawn, helipads, screen
  doors, ladders, siren — **all read GROUPS (`fsb_parapet`, `fsb_nav_geom`) or name PREFIXES, never the
  root.** The break is `nav_baker.gd:204` taking `nodes[0]`, one root — **fixed by one line**: stamp
  every part under one `Node3D` wrapper and return that.

> **The consolidation work of the last six weeks already paid most of the kit's integration bill.**
> ADR-042's naming contract, which looked like the pivot's biggest liability, is what makes it
> survivable: **names are portable, roots are not.**

### And half the kit already exists on disk, unread by any game code

- **`firebase_set.json` — 23 parts**, each with markers carrying `work_type`, `prop_class`,
  `door_width`, `face` and local `pos`. Dated **2026-07-26**. **Nothing in `scripts/` reads it.**
- **`firebase_v3_destructibles.json`** — all **80 wall positions** plus box, kind, hp. The code reads
  only name/kind/hp, so **`pos` is unused data already sitting there.**
- **`gen_firebase_v3.py:709` `STATION_PLAN`** — per-part work stations for **19 families**.
- **`gen_firebase_v3.py:1041-1045`** already builds all 23 as separate masters, and `:503-522` is
  `place(master, pos, bearing)` — **a collision-aware stamper. The firebase is ALREADY assembled from
  stamped modular parts, in Python.**

> **His "work points and animations saved to those locations" was designed and built in July, and
> shelved for one reason.** `gen_firebase.py:1-13`: *"shipping 24 kit GLBs would be 24 files with one
> consumer, **which ADR-023 would correctly come for**."* **The kit was killed by the fossil law for
> having no consumer. His ruling supplies the consumer.** That cuts both ways and the phase order
> honours it: **the consumer ships before the parts multiply**, or they are a fossil again.

### THE PHASES

| # | phase | deliverable | risk |
|---|---|---|---|
| **P0** | **Marker data to disk** | Kills a **free defect found in the demo's own load path**: `_ensure_fsb_markers` builds the full 5,812-node scene and `free()`s it purely to read ~500 markers, at PLAN time, and then the world builds it **again**. Deletes 82 lines, needs no ruling, carries 100% into the kit. | none |
| **P1** | **The wrapper root + probe extension** | One `Node3D` parent; `nav_baker.gd:204` one-line fix; extend `test_site_stamp` for composites; **the marker-vs-navmesh probe ADR-041 §5 makes BINDING** | low |
| **P2** | **THE TOOL, minimum viable** | In-game dev mode (see below). Writes a **JSON site plan**. Enough to place, nudge, rotate, save, reload. | medium |
| **P3** | **THE THREE PROOF PIECES** | bunker → HQ → **gate house last** (it proves the metadata) | art-bound |
| **P4** | **PARAPET FIRST** | 80 positions **already on disk**; deletes 62 lines of stray reconciliation. Cheapest family, not the hardest. | low |
| **P5** | emplacements, towers, bunkers | | low |
| **P6** | marker + garrison re-base | **the one non-atomic commit — 484 lines** | **high** |
| **P7** | buildings + interiors | **see the draw-call warning** | medium |
| **P8** | **THE GROUND — behind his ruling, TWO commits** | | **irreversible** |
| **P9** | fossil deletion | ADR-023 discharge | low |

**Hours: 43–67 engineering, 60–91 all-in** for the kit. **90–145** including the terrain morph tool.
Calibrated two ways against ADR-041 §12's own 20–31 h for village+temple — code-surface ratio and
bottom-up per phase — **and the two agree within 12%.**

### THE TOOL: in-game dev mode, and it is not close

`scenes/levels/game_world.tscn` is **six lines and one empty `Node3D`.** Every world node is built in
code at runtime. `TerrainEngine` is not `@tool`. The project has **three `@tool` scripts, all data
Resources, and no `addons/` directory at all.** **In the Godot editor there is no heightmap, no
navmesh, no vegetation — nothing to brush.** An `EditorPlugin` would require `@tool`-ing the protected
foundation: *"a second execution context for the world build, which is ADR-028's named prohibition
wearing a costume."*

Precedent exists twice: `tools/cursor_editor.gd` is a standalone game-process authoring tool that
writes JSON into `res://`, and **the free-fly camera is already written and shipping**
(`player.gd:1576-1613`, photo mode, with `reset_physics_interpolation()` already handled).

**Output: a JSON site plan** — part ids + local transforms + an ordered terrain-op array + markers +
a declared flatten profile. **Never a composed `.tscn`** (ADR-041 §3's ten contracts). The decisive
argument is that **the split already exists**: `plan_demo_world()` returns a Dictionary that
`build_patrol_world()` stamps unchanged. *"The tool writes that dict by hand instead of rolling it. No
new mechanism."*

**Two facts that will otherwise be discovered in week three:**
- **A TRENCH CANNOT BE A TERRAIN CUT.** `CELL_SIZE = 4.0`, and the code already says it in his words
  at `site_planner.gd:1680`: *"A 4m heightmap cannot draw any of that at any setting."* Dropping to
  1 m cells is **×16 on every heightmap cost** — refused on the Intel UHD bench. **The cut is a SEAT;
  the trench is a MESH.**
- **Half the edit cost is vegetation, and a tool can just turn it off.** Of the 81.5 ms rebuild,
  **42.5 ms is `terrain.veg_generate`.** Null the veg manager during a stroke, regen on mouse-up:
  ~81 ms → ~33 ms. **The expensive part of the crater system is free in an editor.**

### GRANULARITY: per functional PLACE, three tiers

The GLB is **5,810 nodes, 4,572 of them scene ROOTS, only 423 with children — a flat bag, not a
hierarchy.**

- **Tier 1 STAMP (~15 classes, ~78 placements):** hootch ×22, supply_dump ×11, fighting_bunker ×8,
  latrine ×6, gun_pit ×6, mg_bunker ×4, tower ×4, sleeping_bunker ×3, gp_tent ×3, water_point ×3,
  burn_barrel ×3, helipad ×2, toc / mess / medical / gate_gap ×1.
- **Tier 2 DRAW (spline):** sbg_seg ×81, sandbag_parapet ×32, claymore ×17, bunker_steps ×12,
  trench_run ×8. **Reuse `RoadNetwork._seat_and_resample` — do not write a second polyline resampler.**
- **Tier 3 sealed inside its part:** 545 interior props, 300 `MC_*`, 229 `prop_*`, 216 `m101_*`.

**So the kit needs TWO verbs, STAMP and DRAW.** That is worth knowing now: a firebase perimeter, a
trench line and a road are the same verb, and it is not the one that places a bunker.

### THE DATA MODEL — and the doors that must stay open

```gdscript
class_name SitePart extends Resource
@export var part_id: StringName          # "hooch", "mortar_pit", "gate_house"
@export var model: PackedScene           # one part, own transform, own colliders
@export var footprint: Vector2           # feeds CollisionTable + NavBaker
@export var stations: Array[Dictionary]  # [{local, work_type, role}]
@export var crew: Array[Dictionary]      # [{role, occupation, n}]
@export var demands: Array[StringName]   # needs present to be staffed
@export var supplies: Array[StringName]  # offers to the site
@export var clips: Dictionary            # work_type -> clip name
@export var terrain_op: StringName       # flatten | cut | none
```

Combos emit **post requests** into the existing `fsb_garrison_plan()` list — `Civilian.spawn` stays the
one door (ADR-028). `site_planner.gd:650-666` already reads `work_`-prefixed nodes, so **parts need no
new collector.**

**DOORS TO KEEP OPEN for the post-demo solo-player pivot** (the other council's matter — its primitives
are the same as these, and getting this wrong costs a second migration): `stations` and `crew` must be
**data on the part, not code in the planner**; `demands`/`supplies` must be **strings, not enums**, so
a new NPC role never needs a code change; and **a part must be placeable without a firebase around
it**, or authored villages and temples cannot reuse the kit and ADR-041's Tier B stays unbuilt.

**HONEST LIMIT, so it is not oversold:** part-carried markers make the 488/23 ratio **tunable**
(488 → ~150). **They do not make the mismatch impossible** — the 23 is a perf cap in code. And 209 of
the 488 (43%) are **19 markers × 11 duplicated hooches** carrying Blender `.001…011` suffixes: *"his
kit is not a new idea; it is undoing a duplication that already happened in Blender."*

## 6 · WHAT BREAKS, AND THE THREE THINGS THAT COULD REFUSE A PHASE

**1 · THE DRAW-CALL REGRESSION — the strongest technical objection, and nobody else would raise it.**
`fsb_main_v3.glb`: **5,810 nodes · 4,437 mesh nodes · 2,274 meshes · 159 materials · 342,219 tris ·
5,753 instance-weighted surfaces.** The naive "200 instances = 200 calls" is refused — the monolith is
already 4,437 mesh nodes. **The real argument is that stamping destroys the one batching win this
project has, and it shipped four hours ago.** `InteriorPropFold` (`d904fd70`, 13:15 today): **545 props
→ 69 MultiMeshes, 1,010 surfaces → 132**, and its own header says *"69 MultiMeshes each span all eleven
hooches."* **Stamp the hooches separately and each MultiMesh holds ~1 instance** — zero batching win,
**and** you give up per-node frustum culling the fold measured at **+50 draw calls**. **878 surfaces at
stake, on a permanent Intel UHD bench.**

> **MultiMesh cannot rescue it, and the fold's own header says why:** it was legal only because
> *"nothing here matches `FSB_STRUCTURE_KINDS` or `FSB_SOFT_PREFIXES`."* **There is no `queue_free()`
> for MultiMesh instance 37, and the kit's parts are by definition the destructible ones — exactly the
> set instancing cannot help.** No counter was found.
>
> **THEREFORE: P7 (buildings + interiors) is the phase that must be benched before it is built, and
> the interior-prop fold must not be undone to get there.** The honest unknown cuts both ways:
> `place_firebase_main` **never** calls `_apply_visibility_range`, so whether a stamped compound draws
> more or fewer calls than the merged monolith **has never been measured in either direction.**

**2 · THE BERM DOES NOT GET FIXED BY THE KIT, AND HE SHOULD KNOW THAT BEFORE P8.** He gave *"remove
people falling thru berms"* as a benefit. **It is false as stated.** `berm()` sweeps `fb_berm_ring` as
**exactly two quad strips — no bottom face, no end caps.** A `ConcavePolygonShape3D` has no interior;
forcing backface collision makes both faces solid but **gives the shell no volume.** A stamped
`fb_berm_arc` built by the same code has the identical hole — **with 81 seams instead of 1.** The
compound's ground **IS the model**, one-sided, force-flipped 1,904× at boot, and the navmesh is baked
onto it, which is why NPCs fall too.

> **The real fix is the one he proposed himself: the heightfield owns collision, the mesh mound goes
> visual-only.** That is **the single most important call in this council and it must be settled before
> the part list** — it is P8, it is irreversible, and it is the one place where his terrain-morph idea
> is not a convenience but the actual repair.
>
> **P8 MUST BE TWO COMMITS.** `fb_terrain_mound` **is the floor**, and also nav ground and blast-proof.
> Deleting it fails **silently** by putting the player 3.4 m under the world — and last time the floor
> moved, the spawn walked to a village 142 m away. Terrain reproduces the mound first
> (`fsb_mound_height()` is **already ported and reads the manifest** — it was turned off, not deleted),
> **verified with him standing on it**, and only then is it stripped.

**3 · THE FRANCHISE ARGUMENT IS A TIEBREAKER, NOT THE CASE — and the coordinator's own guard is
upheld.** WW1 is post-demo-launch by his ruling. The test stands: **the Vietnam work must be worth it on
its own merits; if it is, WW1 is a bonus; if it is not, WW1 rescues nothing.** Of the 23 parts, **6
transfer unchanged, 12 with a reskin, 5 are Vietnam-only — 74% of triangles survive.** But structurally
a firebase is a **ring of discrete emplacements** and a WW1 line is a **continuous zigzag system with
depth**, so the reuse needs **STAMP + DRAW + a junction graph, not one tool**. What rescues the claim is
that **the firebase needs DRAW anyway** (Tier 2 above). **And one correction of record: `fb_trench_run`
is `tris=240, size=[6.0, 2.85, 0.45], enterable=FALSE, markers=[]` — 0.45 m tall, nobody can stand in
it. It is a parapet spoil lip. `FIREBASE_REWORK_INTENT.md` is RIGHT that the trench module is missing**,
and a lens that first said otherwise withdrew it.

## 7 · THE CALLS THAT ARE GENUINELY HIS

**Q1 · THE GROUND (P8) — the biggest one.** Do we move firebase collision off the model mesh and onto
the terrain heightfield, leaving the mound as visuals only? **It is the actual fix for men falling
through berms, the kit does not fix that without it, and it is the one irreversible step.** He already
asked for the terrain-morph tool that makes it possible; this is the decision to *use* it that way.

**Q2 · NPC STACKING — the fix visibly thins the compound.** A 10-line spatial filter closes the worst
piles, but the chow line goes **5 men → 2**, and he has complained about an empty-feeling base before.
**Thin the crowd to stop the stacking, or keep the crowd and accept the overlap?** *(The one-line
`quarters[qi % 4]` modulo fix is not tonight's — `home` also feeds sleep, LZ keep-out and the bunk ring.)*

**Q3 · CONVOYS — he asked for work he parked himself.** Polishing the ambient convoy is a gate-exempt
bug fix (≈3 h for the four worst). Reviving *"forms up and drives out"* is a **thaw** and needs his
word. **Which did he mean?**

**Q4 · THE THREE PROOF PIECES ARE ART-DAY WORK, AND ART IS THE BINDING CONSTRAINT.** A better bunker, a
better HQ and a better gate house at his measured velocity of 1–2 models per day. **Do these come out
of the demo's remaining art-days, or after it?**

---

## 8 · WHAT WAS SACRIFICED — Law 2, and the Arbiter is bound by it too

- **He loses a base he can navigate without thinking.** Playtesting bought that familiarity, and it was
  paid for with the very defects this fixes.
- **The pacing contract moves.** All patrol density bands measure from `GATE_POS`; demo sites are
  bearing-locked at 185/170 m; the siege's measured geometry (treeline ~149 m, rally 150 m, napalm
  210 m) is tuned against the base that exists.
- **During a rebuild the playtest cannot run** — *"a plan whose first act is to turn off the sensor that
  found all five of these."* **That is the argument for the strangler phasing and against any big bang.**
- **The base may become a LAYOUT instead of a place.** The ring's authored 49.4–96.0 m irregularity is
  what makes it read as dug under fire. **Per-part jitter must be in v1 or it never ships, and he must
  author the first base by hand before any generator exists.**
- **Every authored place is content debt**, and art is already the binding constraint.
- **And the honest one:** every cheap win the UX lens recommends is *dressing* — lobing the vegetation
  clear, surfacing the road at the gate, dressing the toe with spoil and ruts. **None of it fixes why
  men fall through berms or stack on work points. The kit's real bill comes due at P8, in full.**

**The 20% that buys 80% of "integrated into the world", for the record, because it is cheap and it is
not the kit:** the base sits as **a perfect 280 m circular clearing inside a perfect 342 m circular
flatten, on a 512 m map** — two concentric discs covering two-thirds of the world's width, drawn twice
in register. **A kit-built base inside the same two circles reads identically.** Lobe the **vegetation**
disc (it already takes multiple entries); **never** lobe the heightmap disc, whose radius is sized to
the crater-free guarantee rect and the spawn ring.
