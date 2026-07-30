# DEVIL'S ADVOCATE — interior-first buildings, and a firebase worth occupying

**Written 2026-07-30.** Every claim below carries a `file:line` or names the file I counted.
Where I could not verify a consumer I say so instead of asserting it. Blender was not opened,
the game was not launched, no number here is a new measurement.

**The one sentence:** this brief is 15–25 sessions, 8–12 of them HIS Blender time, aimed at a
firebase whose last two days of work he has not looked at once — and four of the nine items
are already half-built, one of them TWICE.

---

## 0. THE OBJECTION THAT OUTRANKS THE REST

**An entire demo slice shipped on 07-29 and 07-30 and not one line of it has been seen by
him.** `DEMO_SESSION_HANDOFF_2026-07-30.md:8` says it in those words. The handoff then lists
**four systems that had been shipping as if they worked and did not** (`:12-27`): the night
assault never fired, the CAS mask one-shots the player and the garrison, `ACTION_WORK` never
walked a man anywhere, and a viewmodel with prefixed clip names plays nothing.

Read that list again as a base rate. **Four of the last session's "shipped" items were
fiction, and the only reason we know is that somebody read the code.** The 07-30 work has had
no equivalent audit — `[Siege] reinforced`, the press waves, the overrun call, the garrison
illum, `_bt_work`, the convoy seating, the vulcan: all of it is a *print statement somebody
intends to fire.* A log line is a claim.

So the brief's real cost is not nine features. It is nine features **layered on top of an
unmeasured, unverified, unplaytested foundation**, where the two biggest items (more bodies in
the base, destroy everything) both land squarely on the systems most likely to be broken:
garrison behaviour and the siege.

And the parse gate is ALSO owed: `--headless --editor --quit` was never run because his editor
was open (`DEMO_SESSION_HANDOFF_2026-07-30.md:89-94`). `--check-only` **cannot prove no type
errors** — it says so itself. We do not currently know that the 07-30 tree compiles.

---

## A. SCOPE, COSTED HONESTLY

### A.1 "same with all our buildings" — the enormous item, and it is his time not mine

**Count the structures first.** Nobody in this brief has.

| set | distinct models | pointer |
|---|---|---|
| firebase families | **23** (19 of them `SOLID`, 8 `ENTERABLE`) | `tools/gen_firebase.py:770-782`, `:786-791`, `:793-795` |
| village | **27** (15 hut + 4 centre + 5 edge + 3 yard) | `scripts/world/site_layouts.gd:10-52` |
| temple | **29** GLBs on disk | `assets/world/building models/structures/temple/` |
| ruins | **22** GLBs | `.../structures/ruins/` |
| airfield / colonial / converted / infrastructure / commercial / vc_nva / loose | **~35** | `.../structures/*` |

**≈136 distinct structure models.** "Destructible, same with all our buildings" at ADR-031's
own doctrine — `intact → damaged → rubble` (`ADR-031:14-15`) — is **two authored variants per
model: ~272 new meshes.** A collapsing 6 m tower wants a third (leaning) stage, and the brief
asks for collapse specifically.

Restrict it to the firebase only and it is still **19 `SOLID` families × 2 = 38 authored
meshes**, every one of them HIS Blender time, plus a full `gen_firebase_v3.py` re-export and
re-collision pass per iteration. At a generous two families per session that is **10 sessions
of his time for the firebase alone**, and he already has E1–E5 open on that queue
(`DEMO_SHIP_BACKLOG.md:229-253`), including E2, the re-export that picks up four *already
fixed* generator changes he has not shipped yet.

**And the placement count is not the model count.** `gen_firebase_v3.py:964-1080` stands
roughly **96 placements** in one compound: ~13 bunkers on the berm line (`:967-975`), ~8 trench
runs, ~16 claymores, 6 gun pits + 6 howitzers + 6 supply niches (`:1000-1013`), 2 mortar pits,
1 TOC, 11 camp buildings (`:1024-1031`), 5 dumps + 6 sandbag stacks, 4 latrines, 3 burn
barrels, 3 water points, **4 towers** (`:1069-1071`), 1 helipad — **plus 80 parapet segments**
(`firebase_v3_destructibles.json`: `count: 80`, `hp: 140`, `segment_len: 6.0`).

### A.2 the draw-call arithmetic nobody has done, and it has the wrong sign

The non-canopy frame is **411–464 draw calls** (`PERF_LEDGER.md:901-903`). `fsb_main.glb` alone
is **681 nodes / 202 meshes / 204 surfaces** at the exact 34-FPS pose (`PERF_LEDGER.md:985`).

Now read `destructible.gd:75-78`:

```gdscript
if destroyed_mesh != null:
	var mi := MeshInstance3D.new()
	mi.mesh = destroyed_mesh
	add_child(mi)
```

**Every destroyed structure that has an authored damaged/rubble mesh instantiates a fresh
`MeshInstance3D` — one unbatched draw call each.** The shared-MultiMesh rubble (`:14-16`,
`:88-101`) is genuinely one call, and that part is well built. The *authored variant* is not.
PERF_LEDGER's own binding engine truth: **"a shared material collapses NOTHING — Godot never
batches 3D draws across `GeometryInstance3D`"** (`:1010-1011`).

So: destroy 96 firebase structures and you have **added ~96 draw calls to a 411–464-call
frame — roughly +21% — and you have added them at the exact instant of peak load**, because the
only thing that destroys 96 structures is the 45-man night siege. **Destruction, as currently
built, makes the worst frame in the game worse.** That is not a tradeoff anyone has named; it
is a defect in the plan.

The honest form of the feature is: authored variants must go into the SAME MultiMesh pool as
the rubble (a `Dictionary[Mesh, MultiMesh]` keyed by variant), or the swap must be a
**surface/material change on the existing MeshInstance3D**, never a new node. Either is a real
change to `Destructible`, not a content pass.

### A.3 "way more to the firebase" on a project that just spent its perf lever

**The physics tick was halved four commits ago.** `c38647d3` — *"Physics tick 60->30
(Summoner-approved, DEMO_PERF_PLAN lever 1) … Halves the per-tick AI wall - the single largest
CPU cost at siege scale."* `project.godot:304` now reads `physics_ticks_per_second=30`.

**You do not halve the simulation rate of a shooter for atmosphere. You do it when you are out
of room.** That commit is the project telling us what its headroom is, and its own message
names the risk: *"His siege playtest is the feel gate: gunplay is pillar 1, revert on his
word."* **He has not run that playtest.** So the single largest perf win currently in the tree
is provisional — it may be reverted on Saturday — and this brief proposes to spend it before it
is banked.

What headroom actually exists, from the ledger and nothing else:
- shipped baseline at the fsb_main spawn pose: **~34 FPS**, noise floor 1.4 (`:702`, `:693`).
- **the CPU-vs-GPU split has NEVER been measured at fsb_main, ever** (`:968-971`). The
  44/52 ms pair everyone quotes is the *night stress arena at native scale* — different scene,
  population and pixel count. **It does not transfer to the hub.**
- **no jungle sightline has ever been measured** (`:972-976`), and Rule #1 is about walking.
- detectability floor is **~3 FPS / ~2.4 ms** (`:977-979`). Anything smaller is unfalsifiable.
- the only lever above noise is the canopy, +6.3 (`:700`), and the honest fix for it is a
  `Texture2DArray` far-card path — **~2.5 days, ~5.3×, and GATED as possibly-unprovable**
  (`:1003-1015`).

**Verdict on item 5: "way more to the firebase" cannot be costed and must not be started.** It
is an unbounded content instruction pointed at the one pose every FPS row in this project was
measured at. Ask him for a NUMBER (how many more structures) or a NAMED LIST, and cost that.

### A.4 the bodies arithmetic — the medical tent alone eats a seventh of the physics tick

Measured per-unit AI cost, post-body-gate: **0.214–0.231 ms per live unit per physics tick**
(`PERF_LEDGER.md:336-339`). The wall is **the BODY, ~94%**: hitzone sync ~10 ms + move_and_slide
~9 ms + execute remainder ~18 ms against think at 1.2 ms (`:296-307`).

Current siege population:
- **45** attackers (`demo_game.gd:29-30`, `SIEGE_STRENGTH` = 45 TOTAL; `siege_director.gd:36`
  `LIVE_CAP = 50`)
- **24** US garrison (`site_planner.gd:830` `FSB_GARRISON_MAX_MEN: int = 24`)
- squad + player ≈ 8
- **≈ 78 live bodies** — already ABOVE the 65–67 that produced the 38–40 ms wall (`:288`).

The brief adds: 8–12 stretcher occupants + 2–3 medical staff + 3–4 officers/radiomen + 1–2 HQ
traffic in flight = **+14 to +21 bodies → 92–99 live.**

**+21 × 0.22 ms = +4.6 ms per physics tick.** The tick budget at 30 Hz is 33.3 ms.
**The hospital dressing is ~14% of the entire physics budget** — and it is spent on men who
cannot be shot, cannot shoot, and mostly cannot move.

**And the body gate will not save it.** `WA-A2`'s payoff class is *"stationary RELAXED
unperceivable men"* (`PERF_LEDGER.md:341-348`); the gate opens for anyone **perceivable —
≤150 m and camera-forward, or inside the 20 m near-bubble** (`:319-322`). A medical tent 20 m
from the player's bunk is the **anti-payoff class**: the gate is open on every one of those
bodies, every tick, forever. Measured payoff at hub start today is **9.4% gated** (`:364-366`).

**Worse: hitzone.** ~10 ms of the wall is hitzone sync; `hitzone_builder.gd:225` does **11
`affine_inverse()` per man where 1 would do**, `hitzone.gd:38` sets `monitoring = true` for
overlaps **nothing consumes**, and the A2 gate **LEAKS** — `hitzone_builder.gd:164-166` wires
an *ungated* closure to `skeleton_updated`, so the gate covers only the physics-tick path
(`PERF_LEDGER.md:1022-1027`). Twelve wounded men lying still will pay full hitzone cost on
the render frame no matter what the gate says. **True hitzone cost is HIGHER than 10.43 ms and
is counted NOWHERE** (`:1055-1057`).

**Named sacrifice if he wants the living hospital:** either the siege loses men (45 → ~30, and
he just paid a whole session to get it to 45), or the hospital occupants are **not AI bodies at
all** — static posed meshes with no `Hitzone`, no `_physics_process`, no nav agent, swapped by
a director. The second is the only version that fits, and it costs the thing he asked for:
the wounded cannot be *checked on* by a nurse who pathfinds to them, only by canned local
choreography.

---

## B. WHAT INTERIOR-FIRST BREAKS — the duplication is not hypothetical, it SHIPPED

He has ruled the workflow. I am not arguing the ruling. I am naming where it collides.

### B.1 the concrete "same table twice" scenario — and it is LIVE TODAY

**The mortar pit exists three times in the shipped world.**

1. `gen_firebase_v3.py:1014-1018` bakes **two** `fb_mortar_pit` structures into
   `fsb_main_v3.glb`, on bearings 2.2 and 3.3 at 44 m from the battery centre. They are on
   `COL_TRIMESH` (`:851-856`), so they are real collidable pits — with **no stations, no crew,
   no code behind them.**
2. `mission_generator.gd:794-796` then stands a **third**: `MortarPit.create(world, pit_pos,
   pit_dir)` at `fsb.center + pit_dir * 10.0` — 10 m from the compound centre.
3. And `scenes/world/mortar_pit.tscn` is not a marker set. It instantiates its **own**
   `mg_nest_sandbag.glb` + `m29_mortar.glb` + `fb_ammo_crate_stack.glb`. **A whole second
   sandbag nest, tube and ammo point, in a compound that already ships two of them.**

That is the divergent-systems failure in one object: **the generator owns the geometry, and the
code owns a different copy of the same geometry, and neither knows about the other.**

It is worse than duplication. `mission_generator.gd:795` seats the code pit with
`world.terrain_manager.get_height_at(pit_pos)` — **and `game_world.gd:400` exists specifically
to warn that `get_height_at()` alone buries anyone spawned inside the firebase, because
`fsb_main_v3` IS the ground.** So the only mortar pit with claimable stations is placed by the
one method the codebase has already documented as wrong inside this compound. It is either
sunk into the mound or floating over it, and nobody has looked.

**This is exactly what item 7 ("place all the new gun pits and mortar pits") will multiply.**
Six gun pits and six howitzers are ALREADY in the GLB (`gen_firebase_v3.py:1000-1013`). If
"place them" is read as "instantiate scenes for them", the compound gets six more howitzers
beside the six it has.

### B.2 the ownership contract, and the specific interior-first hazard

The two artefacts are already correctly separated and the README says so
(`scenes/world/README_firebase_main.md`): generated content in `gen_firebase_v3.py`, hand
decisions in `firebase_main.tscn`, and `site_planner.gd:657` loads the **scene**
(`FSB_MAIN_PATH`), not the GLB — so hand-authored siblings do survive a re-export. Good.

**The hazard interior-first introduces is the third path nobody is guarding: the code
furnisher.** `site_planner.gd:520-538` `_furnish_interior()` walks a building's baked `prop_`
markers and instantiates a prop per marker. Today it fires **only on villages**
(`site_planner.gd:299` is its only caller). The moment somebody wires it to the firebase — and
`production/firebase_interior_wiring.md:264` proposes exactly that — you have:

- **the props he authored INTO the Blender interior** (baked in the GLB, interior-first), AND
- **the props the code places AT the markers those same interiors carry.**

`fsb_main_v3` ships **191 `work_` markers** (`site_planner.gd:832`) and **68 `prop_sleep`
markers** (`game_flow.gd:122`). Sixty-eight cots authored on the bunks by hand, plus 68 cots
placed at the same markers by `_furnish_interior`, is **136 cots and +68 draw calls on a
411–464-call frame.**

**The contract that must be written down before one interior is built:**
> A `prop_` marker means "CODE OWNS THIS SLOT — leave it empty in Blender."
> Geometry authored into the interior carries **no marker**.
> A room is one or the other, never both, and the generator asserts it (fail the export if a
> `prop_` marker has authored geometry within 0.5 m).

Without that line, interior-first is a licence to hand-author the exact content a live system
already places, and this project's standing blindspot is ~14 parallel world-build systems.

---

## C. FRESH BOOT — the empty hospital, and the ledger does not exist

**There is no casualty ledger.** `CampaignState` persists `threat_level`, `reputation`,
`roster`, `missions_played`, `mission_log`, `iron_man`, `player_data`, `intel_points`,
`collapsed_tunnels`, `field_marks`, `pencil_marks`, `reported_marks`, `lifetime_intel`,
`ears_taken`, `next_stash_at`, `rack_condition`, `depot_loss` (`campaign_state.gd:22-94`).
**No WIA state, no wounded pool, no casualty record of any kind.** The only casualty concept
in the game is terminal: `squad_roster.gd:164` *"replaces KIA with rookies."*

So "occupancy comes from the casualty ledger" is not a wiring job. It is:
1. a new persisted field,
2. a **`SAVE_VERSION` bump** (`campaign_state.gd:6` is `1`; the only migration precedent in the
   file is `_migrate_depot_loss` at `:100`),
3. a producer at every point a man goes down (squad, garrison, siege), and
4. a consumer that translates it into bodies-in-a-tent.

**And then the fresh player sees an EMPTY HOSPITAL IN A WAR.** Mission 0, `missions_played = 0`,
roster full and healthy, ledger empty. Twelve empty stretchers under a canvas roof with two
nurses walking rows of nobody. That is not a living world; it is a *morgue that reads as a
supply tent*, and it is **the only state anyone will ever see at the demo**, because the demo is
by definition a mission-0 boot (`GameFlow.demo_mode`).

The fresh-player law is that dev saves mask fresh-player bugs. Here it is sharper: **there is
no dev save that could have shown this, and the ledger design is the thing that makes the
first boot the worst boot.**

**Both available answers cost something, and the brief pretends neither exists:**
- **Seed the ledger** with pre-existing wounded who were never the player's casualties. Then
  occupancy is a random number with a backstory — *"a diorama with a timer"*, which
  `briefing.md:108-109` explicitly names as the failure mode. It just has better prose.
- **Ship the empty tent honestly** and let it fill. Then the demo — the thing with the ship
  gate on it — opens on the deadest room in the compound.

There is a third framing worth putting to him: **the ledger is a scoreboard of his failures
parked 20 m from his bunk.** On a fail-forward pillar that is arguably the best atmosphere in
the game. But it is a design decision with teeth, not a plumbing detail, and it should be his
ruling, not a consequence.

### C.1 the form-up-outside rule is a NAV FACT, and that is the good news

`briefing.md:113-114` asks whether the form-up-outside instruction is nav or spectacle. **It is
nav, and it is measurable.**

- `fb_aid_station`'s footprint is **8.0 × 6.0 m interior, 9.0 × 7.5 m footprint**
  (`collision_table.gd:72`).
- `nav_baker.gd:44-46`: `GRID_STEP = 4.0` (`== WorldConfig.CELL_SIZE`), `AGENT_RADIUS = 0.5`.

**A 4 m navmesh sample grid cannot resolve aisles between stretcher rows in an 8 × 6 m tent.**
Twelve stretchers plus walking room is ~2.9 m² per occupant including aisles; the navmesh sees
that room as two or three samples wide. Group formation inside is not merely tight, it is
**below the resolution of the pathfinder.** His instruction is not a stylistic preference — it
is the only thing that can work, and he arrived at it by eye. Implement it as written and say
so in the record.

---

## D. THE OCCUPIABLE BUNKER IS THE BIGGEST ITEM IN THE BRIEF DISGUISED AS THE SMALLEST

"You can occupy one and shoot out of it" reads like one afternoon. Here is what it actually
touches.

**What exists and is genuinely reusable — more than the briefing credits:**
- A full mount contract: `MGEmplacement` with `yaw_center()` / `yaw_span_rad()` /
  `pitch_min_rad()` / `pitch_max_rad()` (`mg_emplacement.gd:116-131`), player mount at
  `player.gd:1069` `man_mg()` with a real arc clamp, dismount at `:1102`, proximity verb at
  `player.gd:528-535` against `MGEmplacement.REACH`.
- AI occupancy: `man_by_ai()` (`mg_emplacement.gd:152`) and `garrison_defender.gd:63-67`
  promoting a `gun_crew` man to the nearest free post.
- Self-heal on a dead or freed occupant: `mg_emplacement.gd:81-90`.
- **The collision problem the briefing calls the load-bearing decision is ALREADY SOLVED.**
  `gen_firebase_v3.py:851-856` puts `fb_bunker_mg`, `fb_bunker_fighting`,
  `fb_sleeping_bunker`, `fb_tower`, `fb_gun_pit`, `fb_mortar_pit`, `fb_trench_run`, `fb_toc`,
  `fb_mess`, `fb_aid_station`, `fb_hootch`, `fb_gp_tent` on **`COL_TRIMESH`**, with the reason
  written at `:832-835`: *"a box fills every opening in the mesh it wraps - it would seal the
  bunkers shut and brick up every firing slit."* And `fb_bunker_*` are in `ENTERABLE`
  (`gen_firebase.py:793-795`), *"Verified with the player capsule (r=0.4, h=1.8), never
  asserted."*
  **Do not spend a session re-solving this.** What is open is E3 — whether the ART has an
  embrasure hole cut in it (`DEMO_SHIP_BACKLOG.md:249`). That is his Blender time, and it is
  the actual gate.

**What does NOT exist, and each is real work:**

1. **No entry or exit animation, at all.** `man_mg()` disables the player's collider, writes
   `global_position = _mg_stand_pos` and calls `reset_physics_interpolation()`
   (`player.gd:1080-1085`). `man_by_ai()` does the same to the AI (`mg_emplacement.gd:157-159`).
   **Manning a post is a teleport.** For a pintle behind sandbags in the open, a snap reads as
   "mounted". For **climbing into a bunker through a doorway**, a teleport through a wall is the
   single most immersion-breaking thing in the brief, and it violates Rule #1 by his own
   standard of judgement (his eyes).
2. **The station is the wrong shape.** A bunker is not a pintle. It wants 2–3 firing positions
   at different embrasures (the generator already authors `("watch", 2, ...)` for
   `fb_bunker_fighting` and `("mg", 1) + ("watch", 1)` for `fb_bunker_mg` —
   `gen_firebase_v3.py:619-620`), each with its **own** yaw/pitch clamp derived from **its own
   slit's** aperture, not one arc for the building. `MGEmplacement` holds exactly one occupant
   (`:30`) and one arc (`:20-22`). Either it grows a station array — which makes it `MortarPit`
   — or a third occupancy class appears, and ADR-023 will have something to say about that.
3. **AI cannot use them.** `garrison_defender.gd:126-133` searches the `mg_emplacements` group
   only. A bunker is not in it. And if bunkers ARE added to that group, the arithmetic at
   `site_planner.gd:819-820` bites immediately — the comment already says *"mission_generator
   ._place_firebase_mg spawns a mannable M60 per gun_crew post, and 20 of them is not a
   firebase, it is a joke."* Thirteen manned bunkers is that joke again.
4. **The claim/release mechanism the briefing offers is itself UNFINISHED.** `MortarPit.claim()`
   and `MortarPit.release()` (`mortar_pit.gd:49`, `:58`) have **zero callers repo-wide** —
   nothing outside `mortar_pit.gd` mentions either. The briefing cites them at `:69-70` as the
   existing pattern to mirror. **It is a pattern nobody has ever run.** Under ADR-023 triage
   that is UNFINISHED (built ahead of its wiring), not live.
   Two more while we are here: `mortar_pit.tscn` ships `station_handoff` and `ammo_point`
   markers with **zero consumers anywhere in `scripts/`** — and `mortar_pit.gd:18` `STATIONS`
   lists only three, so `station_handoff` is **unclaimable by construction.** Two fresh
   fossils against a ceiling of 19 that **only ratchets down** (`CLAUDE.md:308`).
5. **Nav inside the bunker is plausible but unverified.** `nav_baker.gd:35-41` parses the real
   `-colonly` trimeshes for this one site precisely so *"navmesh and physics cannot disagree"* —
   which is the right architecture and may already bake bunker interiors. But `GRID_STEP = 4.0`
   against a bunker whose interior is a couple of metres across is the same resolution problem
   as the medical tent. **Measure it with a probe before promising AI will walk in.**

### D.1 destroying a bunker with a man in it — the failure is worse than the briefing says

`briefing.md:66-70` is right that `Destructible` has no occupant concept. The concrete failure
chain:

`Destructible._do_destroy()` (`destructible.gd:66-85`) hides every child `MeshInstance3D`,
**disables every child `CollisionShape3D`**, drops `soft_cover` and `hard_surface`, scatters
rubble, craters the ground, plays an explosion and emits noise. It never looks for an occupant
because it cannot: it is a `StaticBody3D` that knows about geometry.

- **If the occupant is an `MGEmplacement`-style mount, the mount is a SEPARATE NODE.** The
  firebase's MG posts are created by `mission_generator.gd:916-922` on terrain height, not
  parented to any bunker. So the bunker's meshes vanish and **a pintle, a sandbag hull and a
  gunner keep standing in the rubble, fully functional, holding an arc through open air.**
- **If the occupant is a `MortarPit`-style station, the station is claimed forever.** Nothing
  calls `release()` (see D.4 above), and unlike `MGEmplacement` — which self-heals on an
  invalid or dead occupant at `mg_emplacement.gd:81-90` — **`MortarPit` has no
  `_physics_process` and no self-heal at all.** A corpse holds that station for the rest of the
  mission, and `free_stations()` will never offer it again.
- **The collider disable is a trapdoor.** `_do_destroy` disables the *bunker's own* collision.
  Whether a man standing on a bunker's authored floor falls through depends entirely on whether
  the mound trimesh runs underneath him — and the mound is a separate object
  (`gen_firebase_v3.py:846-852`). Unverified either way. **Do not ship destructible occupied
  structures without probing this specific case.**

Minimum honest cost for item 8 **plus** the occupant half of item 9: **2 code sessions + 1–2
of his Blender sessions (embrasures, and a get-in/get-out clip)**, and it produces one new
verb. It is the most expensive thing in the brief per unit of content.

---

## E. DRIFT PATROL — claims in this repo that are no longer true

Under `CLAUDE.md:243-245`: correct or note these **in the same change** that touches them.

**E.1 — "21 US interior props exist and are UNEXPORTED" is FALSE.**
`briefing.md:80`. Also `production/firebase_interior_wiring.md:3` (*"props built in Blender,
NOT exported, NOT wired"*), `:22` (*"yes, in Blender"*) and `:264` (*"Export 21 GLBs"*).
**There are exactly 21 GLBs on disk at `assets/us/props/interior/`**, imported, names matching
the wiring doc's own table: `fb_ammo_crate_stack`, `fb_bench`, `fb_c_ration_case`, `fb_cot`,
`fb_field_chair`, `fb_field_desk`, `fb_field_phone`, `fb_field_range`, `fb_folding_table`,
`fb_footlocker`, `fb_hanging_bulb`, `fb_jerry_can`, `fb_litter`, `fb_map_board`,
`fb_medical_chest`, `fb_mermite`, `fb_plotting_board`, `fb_radio_prc25`, `fb_radio_shelf`,
`fb_wash_drum`, `fb_water_can`.
**The real gap is different and worse: the art landed and the wiring did not.** `SiteLayouts`
has no `US_PROP_DIR` and no `US_INTERIOR_PROPS` — `site_layouts.gd:94-103` is village-only, and
both symbols have **zero hits repo-wide**. `place_firebase_main()` never calls
`_furnish_interior()` (its only caller is `site_planner.gd:299`, the village path). **So 21
finished props sit in the .pck and cannot appear in the game.**
Two of them — `fb_litter` and `fb_medical_chest` — are the medical tent's own dressing, already
built.

**E.2 — "The firebase chunk kit: 19 marker-GLB chunks" is FALSE.**
`briefing.md:79`. There are **no chunk GLBs anywhere** — zero files matching `*chunk*` under
`assets/`. `assets/world/building models/structures/firebase/kit/` holds **5** GLBs:
`fb_FoxholeSandbags`, `fb_emplacement_m101`, `fb_gate_assembly`, `fb_sandbag_light`, and
`fb_sandbag_heavy` — **which is BANNED** (`briefing.md:81`) **and is still on disk with a live
`.import`, i.e. still in the export path.**
`PERF_LEDGER.md:996-1000` already recorded that *"none of the 4 kit GLBs loads at runtime"*.
It is 5 now, and **`fb_emplacement_m101.glb` (14.6 MB + a 9.05 MB texture, dated 2026-07-29)
is referenced by NOTHING in `scripts/` or `tools/`.**
**Consequence for this council:** the station-architecture decree's stated mechanism —
*"stations attach as CHUNKS at `fsb_main_v3` markers"* (`briefing.md:76-78`) — **has no chunks
to attach.** Any sequencing built on that sentence is built on air.

**E.3 — "a mannable MG emplacement is the top DEFERRED feature" is FALSE, and has been for
days.** `briefing.md:83-84`; also `production/research/m60_mounted_reference/NOTES.md:3` (dated
2026-07-29) and `production/war_room/2026-07-25_support_fire_room/synthesis.md:42`.
It is **built, placed and mannable by both sides**: `MGEmplacement` (`mg_emplacement.gd`),
placed per `gun_crew` post at `mission_generator.gd:881-882`, manned by the player via
`player.gd:528-535` → `player.gd:1069` with a live arc clamp, and by AI via
`garrison_defender.gd:63-67` → `mg_emplacement.gd:152`.
**A "top deferred feature" that already ships is exactly the class of lie the FOSSIL LAW is
about**, and it is currently misdirecting the roadmap.

**E.4 — ADR-031's build state is stale, and destruction SHIPPED THROUGH ITS OWN GATE.**
`ADR-031:44-47` says *"P2 perf-proof, P4 terrain holes, P5 buildings: NOT built — held behind
the gate above."* Buildings destruction is **live**: 80 parapet segments wired to the blast bus
at `site_planner.gd:1269-1313` in group `fsb_parapet`, `is_destroyed()` added at
`destructible.gd:52`, a dev key that blows a real segment at `game_flow.gd:248-261`, plus 16
claymores.
**The gate it was held behind has never been discharged.** `ADR-031:39-42` binds destruction to
*"the worst single-frame spike measured — a napalm run + AC-47 + a live firefight, ship config,
on the Intel-UHD floor."* PERF_LEDGER's most recent session produced **NO FPS ROW at all**
(`:957-965`), and **milliseconds have never been measured at `fsb_main`, ever** (`:968-971`).
So the measurement that was supposed to authorise this feature does not exist, and the feature
is in the demo.
This is `CLAUDE.md:301-302` repeating itself: *"the GATE bead — never `bd dep`-linked. **A gate
that blocked nothing**."*

**E.5 — the mortar pit ships three times.** See B.1. `gen_firebase_v3.py:1014-1018` (two baked)
+ `mission_generator.gd:794-796` (one instantiated, with its own duplicate nest/tube/crates in
`scenes/world/mortar_pit.tscn`), the third seated by `get_height_at` which
`game_world.gd:400` documents as burying things inside this compound.

**E.6 — `LIVE_CAP` is 50 in code (`siege_director.gd:36`) and 18 in `ADR-035:253`.** Carried
over unresolved from `DEMO_SESSION_HANDOFF_2026-07-30.md:113`. `demo_game.gd:29-30` reasons off
50. The ADR is canon; **one of them is wrong and the demo's headline number depends on which.**

**E.7 — the briefing's own Collision A is overstated.** `briefing.md:52-58` presents the box-hull
problem as open and load-bearing. It was closed on 2026-07-29 in the generator
(`gen_firebase_v3.py:832-856`). Leaving it open in the briefing costs a session of
re-deliberation on solved ground.

---

## F. PRIORITISATION — what must NOT be started until the playtest returns

**The gate: he tests the demo tomorrow. Nothing that would be invalidated by his verdict may
start before it lands.**

Three specific ways the playtest can invalidate this brief:
1. **He reverts the physics tick.** `c38647d3`'s own message invites it (*"revert on his
   word"*). Every body-count decision in this brief is priced at 30 Hz.
2. **The garrison does not read as working.** A3/A4 are unverified
   (`DEMO_SHIP_BACKLOG.md:26-42`), and `_bt_work` only learned to walk yesterday. **The
   medical tent, the nurse rounds and the HQ traffic are ALL `_bt_work` on markers.** If that
   is broken, three of the brief's nine items are built on sand and the fix is upstream of all
   of them.
3. **The overrun does not fire, or fires wrong.** Then C3/C5/C6/C7 are the session and this
   brief waits regardless.

### CUT LIST — do not start these before the playtest returns

| # | item | why it waits |
|---|---|---|
| **5** | **"way more to the firebase"** | Uncostable, unbounded, aimed at the one pose every FPS row was measured at. **Refuse until he gives a count or a named list.** |
| **9** | **destructible/collapsible everything** | ~272 authored meshes at "all our buildings"; 38 for the firebase alone; **`destructible.gd:75-78` adds a draw call per destroyed structure at the moment of peak load**, so the feature must be re-architected before content is authored. And ADR-031's own perf gate is undischarged. |
| **2** | **the living medical tent** | +14–21 always-ungated bodies = ~14% of the physics tick; needs a casualty ledger that does not exist, a `SAVE_VERSION` migration, **and its first boot is empty** (§C). Needs HIS ruling on seeded-vs-empty before a line is written. |
| **8** | **occupiable bunkers** | 2 code + 1–2 Blender sessions for one verb; gated on E3 (embrasure art) which is HIS queue; and it re-opens the destroy-with-occupant hole (§D.1) that is not designed. |
| **4** | **period-accurate barracks** | Pure Blender time, and it competes directly with E1–E5, which are the items his own playtest complaints generated. |
| **1** | **interior-first as a build order** | Cannot start safely until the marker-ownership contract in §B.2 is written and asserted by the exporter. One session of contract work unblocks it and prevents a 136-model duplication class. |

### DO-FIRST — this week, playtest-independent, cheap, and each one deletes a defect

1. **The 07-30 audit and the parse gate.** Read the 07-30 tree the way the 07-30 session read
   the 07-29 tree — four of four "shipped" items were fiction last time. And run
   `--headless --editor --quit` the moment his editor is closed
   (`DEMO_SESSION_HANDOFF_2026-07-30.md:89-94`). **We do not currently know the tree compiles.**
   *~0.5 session, no Blender, no risk.*
2. **Wire the 21 props that are already on disk.** Add `US_PROP_DIR` + `US_INTERIOR_PROPS` to
   `site_layouts.gd`, make `prop_class` survive export, call `_furnish_interior()` from
   `place_firebase_main()`. **This is the largest visible-atmosphere-per-hour item in the whole
   brief and the art is finished.** Ship it with a hard per-site prop cap and print the draw-call
   delta, because 68 `prop_sleep` markers against a 411–464-call frame is real.
   *~1 session, code only, and it corrects E.1 on contact.*
3. **Kill the triple mortar pit** (§B.1) and write the marker-ownership contract (§B.2). This is
   item 7 done properly: the pits are already placed; what is missing is one canonical pit with
   claimable stations, seated on the GLB ground, and the two dead ones either removed from the
   generator or promoted. **It deletes a live bug, discharges the duplication risk before
   interior-first can multiply it, and it is prerequisite to everything in the brief.**
   *~1 session, code + one generator edit.*
4. **Better mud.** `mud_blob()` already exists (`gen_firebase_v3.py:405-448`) with splat/pool/
   puddle styles, and `fsb_main_v3_fb_mud.png` ships. Mud is **decals and merged ribbons: zero
   bodies, ~zero new draw calls, and it is the single highest atmosphere-per-millisecond item in
   the brief.** It is also the only item that pays off on Rule #1 (*fun to WALK*) directly.
   *~0.5 session, his re-export.*
5. **HQ traffic (item 3).** The cheapest of the four "living world" asks: officers and radiomen
   are `work_` markers plus `civilian_schedules` entries; the in-and-out stream is one schedule
   with two men, not a system. **+3–5 bodies, not +21.** But it is downstream of the A4 verdict
   — build it the day after he confirms sentries actually walk to the wire.
   *~1 session, code only, AFTER the playtest.*
6. **Flag the HQ reading.** `briefing.md:31-33` guesses that *"studying tents"* means map/table
   study inside the tent. **Ask him.** If it means something else, the whole HQ interior changes
   and any interior-first work on it is wasted. One question, and it is exactly the kind the
   decision queue exists for.

### What this brief SACRIFICES, said plainly

Taken whole, at 15–25 sessions with 8–12 of them his: it **spends the 60→30 physics lever
before that lever is even confirmed**, it **puts ~272 authored meshes on his Blender queue
ahead of E1–E5 — the items his own playtests generated** — it **adds draw calls to the worst
frame in the game via a destruction path that instantiates unbatched meshes**, and it **builds
three of its nine items on `_bt_work`, a function that learned to walk yesterday and has never
been seen working by the only authority that counts.**

Taken as the DO-FIRST list: ~4 sessions, one Blender re-export, **three live defects deleted**,
21 finished props made visible, mud on the ground, and the duplication contract written before
interior-first can turn one blindspot into a hundred and thirty-six.
