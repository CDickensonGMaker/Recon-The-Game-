# DEVIL'S ADVOCATE — Walkable Interiors / Buildings-As-Buildings

**War Room 2026-08-12 · RECONgame · Devil's Advocate**

**Scope correction accepted before writing.** Caleb: *"theres no hard date for anything."* The
2026-09-06 EA target is his pacing target, not a deadline (already on record,
`production/SHIP_AUDIT_2026-08-11.md:3`). **Nothing below argues from schedule.** Every objection
is technical or workflow friction. Sequencing is his call alone; my job is to name what each road
costs.

**The proposal:** author all buildings — 2 screened-wall hooches with bunks, 1 dug-in earth bunker
hooch, the real officers' HQ tent, updated mortar pits with VC/NVA-armory animations, and later
whole villages and enemy camps — in Blender as *buildings*, with working doors and walkable
interiors, all part of one live world. Under-terrain bunkers entered by stairs. He prices the
remaining art at 1–2 days each.

**My verdict up front:** the four named buildings are ordinary work on a road this project already
travels, and I have no technical objection to them as *models*. My objections are to the three
words that came with them — **"working doors"**, **"walkable interiors"**, and **"whole villages
and enemy camps"** — and to the fact that the pipeline that must carry them has an un-fixed
content-eating landmine in it today.

---

## 0. THE THING I FOUND THAT MATTERS MOST

**`tools/gen_firebase_v3.py:929` still saves over the source `.blend`.**

```python
bpy.ops.wm.save_as_mainfile(filepath=blend, compress=True)   # :929  (and again at :1105)
```

Immediately before it (`:925-928`) it purges every zero-user mesh, material and image.

This is the exact call that ate the medical complex on 2026-07-31 — 894 objects, **0 collections**,
`medical_complex` gone, recovered only because `.blend1` happened to be larger than its parent
(memory `firebase-export-ate-the-medical-complex`). That memory records a **"standing fix owed:
`export_firebase()` must stop saving over the source, or must back it up itself."**

**That fix was never made.** It is 11 days later and the gun is still loaded, still pointed at the
same file, and the proposal on the table is to put *four more buildings and eventually every village
in the AO* in front of it.

I am not going to argue about interiors until this is said plainly: **the single highest-leverage
change available to this proposal is eight lines in `gen_firebase_v3.py` that copy the `.blend`
before it overwrites it.** Everything else in this document is secondary to that.

---

## 1. THE SCALE TRAP — measured, not estimated

### 1a. What one firebase actually is

I parsed `assets/world/building models/structures/firebase/fsb_main_v3.glb` directly (glTF JSON
chunk, 2026-08-12):

| metric | value |
|---|---:|
| nodes | **1,259** |
| meshes | 506 |
| primitive groups (surfaces) | 578 |
| materials | 34 |
| images | 25 |
| file size | 13.39 MB |
| **file date** | **2026-07-26** |

Top node families by count:

| count | prefix | what it is |
|---:|---|---|
| **356** | `fb_int_` | **interior dressing** |
| 160 | `fb_sbg_` | parapet segments |
| 34 | `fb_claymore` | wire |
| 26 | `prop_storage` | |
| 24 | `fb_mud` / 24 `fb_veg_` | ground + scatter |
| 22 | `fb_supply` · 20 `fb_bunker` · 16 `fb_trench` · **16 `fb_hootch`** | structures |

**Read that top row again. Interior dressing is 356 of 1,259 nodes — 28.3% of the entire firebase —
and `ART_Track_Log.md:43` says firebase interiors are *"about half done."*** Finish them and
interiors are ~40–45% of the densest site in the game.

Corroborating runtime measure, `production/DEMO_SESSION_HANDOFF_2026-07-30.md:77-78`:

> *"826 visible surfaces, of which 368 (44.6%) are the 178 `fb_int_` props, carrying 11,936 of
> 318,056 triangles (3.75%)."*

**Interiors cost ~45% of the compound's draw calls to buy 3.75% of its geometry.** That is not my
framing — it is `site_planner.gd:1328-1337`, in the codebase, written by this project.

### 1b. Why that ratio is the whole objection

`production/PERF_LEDGER.md` (ship-parity A/B/A, seed 47225, 0.75 scale, Forward+, Intel UHD):

- shipped baseline **~34 fps**
- the **only** lever above the noise floor is the canopy: **+6.3 fps, from dropping 1,018 of 1,458
  draw calls (70%)** — *"call-bound, not primitive-bound"* (`PERF_LEDGER.md:524-527`)
- sun shadow: **−0.2, inside noise.** Clutter: inside noise. Campfires: inside noise.

**This project's one measured performance lever is draw calls.** And interiors are the single most
draw-call-dense, least-triangle-dense content type it produces. Interiors are precisely the shape of
content this engine budget punishes hardest.

`ADR-036-the-fall-of-the-firebase.md:79-83` already concedes the same point from the other
direction, and credits it to a prior devil's advocate:

> *"splitting the welded firebase GLB into ~20 registered nodes is a **draw-call regression at the
> densest site in the game** (678 meshes / 1,116 bodies)… §2 taxes every hour of the game to pay for
> eight minutes of it."*

### 1c. Now project it to villages and camps

Resident world load, `PERF_LEDGER.md:267`: **`fsb_main` + 4 villages + 3 camps.**

Village stamp, `site_planner.gd:226`: **7–10 huts** + 1 centre model + 1 cache + 1 tunnel mouth +
0–2 scatter + 1–2 edge pieces, **per village**.

I measured every GLB in `assets/world/building models/structures/village/` (26 files):

| | total | per hut (avg) |
|---|---:|---:|
| nodes | 246 | ~12 |
| meshes | 157 | ~6 |
| surfaces | 251 | ~13 |

**The whole 26-model village library is 246 nodes — one fifth of one firebase.** That is what
"villages read fine at patrol distance" buys today.

Now give a village hut the firebase's interior treatment. The firebase carries **178 interior props
over roughly 10 interior-bearing structures** — call it ~18 props / ~36 nodes / ~37 surfaces of
dressing per building. A hut goes from **13 surfaces to ~50, roughly 4×.**

**4 villages × ~11 structures = ~44 buildings, plus 3 camps.** At 4× surfaces that is on the order of
**+1,600 surface draws resident in the AO** — approaching **3× the entire current firebase** (578),
spread across sites the player walks past rather than lives in.

### 1d. And the mitigation does not reach them

`site_planner.gd:1338-1356` culls interior props past **40 m** — but only nodes whose name begins
`fb_int_`, and only on the firebase root. Village and camp structures go through
`place_structure` → `_apply_visibility_range` (`site_planner.gd:209-220`), which sets **230 m** on
the whole visual subtree.

**A cot inside a village hut would draw from 230 metres away.** Extending the 40 m cull to village
interiors means either naming village props `fb_int_*` (a *firebase* prefix on village art — a
naming lie this project's own fossil law forbids) or teaching a second prefix. Small code job, but
it is code that does not exist and it is not in the 1–2 art-days.

**SACRIFICED IF THIS GOES AHEAD AS PROPOSED:** the only measured performance lever the project has,
spent on the content class with the worst call-to-geometry ratio, at every site simultaneously.

---

## 2. THE RE-EXPORT TRAP — the blast radius is already a measured fact, not a hypothesis

### 2a. What one bad export costs, historically

- **2026-07-31:** an export saved over `firebase_v3.1.blend`. Result: **0 collections, no
  `medical_complex`**, 894 objects. A day of hand work gone. Recovered 8/2 only from the rolling
  `.blend1` — *"one keystroke from being destroyed"*.
- **2026-08-03:** appending the chow hall dragged packed textures. `merge_chowhall_to_firebase.py:29-31`,
  verbatim: ***"This took the firebase from 9 MB to 398 MB on 8/3."*** A 44× file-size explosion from
  merging **one** building. Every future building merge needs `dedupe_images()` run and verified.

### 2b. What the one-GLB pipeline costs *right now*, with nothing new added

`SHIP_AUDIT_2026-08-11.md:20-27`:

> *"`fsb_main_v3.glb` is still dated 2026-07-26, while `chow_hall.blend` (8/3),
> `firebase_v3.1_RECOVERED_medical.blend` (8/5) and `mortar_pit_crewed_US_v1.blend` (8/7) all sit
> stranded in Blender. **Sixteen days of finished art has not reached the game.**"*

I re-verified the file date on disk today: **`fsb_main_v3.glb` — 2026-07-26 22:27.** Still true.

**This is the trap in its purest form and it is already sprung.** Three finished buildings — the
chow hall, the medical complex, the crewed mortar pit — are *done*, and none of them is in the game,
because the act of putting them in requires a re-export of the single 1,259-node artefact that has
eaten content before. **The one-GLB architecture has already converted "finished art" into "art
nobody can play," and it did it without any of the four new buildings existing yet.**

Adding four more buildings to that GLB does not add four more items to a queue. It adds four more
items to a queue **whose service rate is currently zero.**

### 2c. What a re-export has to get right, every time

Each of these has failed at least once on record:

| # | Thing that must hold | Where | Failure mode |
|---|---|---|---|
| 1 | Source `.blend` survives the export | `gen_firebase_v3.py:929` | **UNFIXED. Ate the medical complex 7/31.** |
| 2 | Packed images de-duplicated | `merge_chowhall_to_firebase.py:29` | 9 MB → 398 MB, 8/3 |
| 3 | Faces wind **CCW seen from outside** | `FIREBASE_EXPORT_NEED_TO_DO.md` §B | All 19 families wound inward; you could stand in a bunker and shoot out through the wall |
| 4 | 80 parapet segments keep **exact names** `fb_sbg_seg_000…079` | `site_planner.gd:1590`, `firebase_v3_destructibles.json` | Exact `find_child` string match. A rename/reorder/recount silently kills destruction **and blinds `SiegeDirector`'s breach axis** |
| 5 | Mound manifest regenerated with the export | `write_mound_manifest`, `fsb_main_v3_mound.json` | The terrain is sculpted to it. Regrade the mound and every `spawn_bunk*` / `prop_sleep` marker must move in the **same session** |
| 6 | `FSB_FLATTEN_RADIUS` (215 m) still matches the footprint | `site_planner.gd` | Hardcoded to the *current* mound. Same landmine class as the `MOUND_H` bug |
| 7 | Enterable structures set `mesh: true` | `site_planner.gd:185` | Otherwise the authored box **seals the doorway shut** |

**Seven contracts, one artefact, no automated gate across them.** Item 4's only tell is a printed
count you have to read; item 3's only tell is a printed count you have to read; item 1 has no tell
at all until you open the file and find it empty.

### 2d. Iteration cost of changing one hooch

Under the one-GLB model, changing a bunk in hooch #2 means: open the 1,259-node firebase master →
edit → run an export that regenerates 160 collision twins, purges zero-user datablocks, **saves over
your source**, rewrites the mound manifest, and re-emits a 13.4 MB GLB → then verify seven contracts
→ then boot and read three print lines. **There is no unit of work smaller than "the whole
firebase."**

### 2e. The horn of the dilemma nobody has named

The obvious fix — **stop welding, ship each building as its own GLB** — is not free either.
`ADR-036:79-83` already priced it: *a draw-call regression at the densest site in the game.* And
`place_structure` (`site_planner.gd:148-204`) then demands, **per building**: a `CollisionTable`
entry, an authored material, a `mesh:true` flag, a `nav_box`, and a visibility range.

**Both horns are real. There is no free architecture here, and the proposal as stated does not say
which horn it is choosing.** That is the single question I most want answered before any modelling
starts: *is a "building" a mesh family inside `fsb_main_v3.glb`, or its own file?* The answer changes
every contract below.

---

## 3. THE NAMING-CONTRACT TRAP — two incompatible contracts, and a live landmine in his own name

### 3a. There are TWO ballistics authorities, and they disagree about granularity

**Path A — inside the firebase GLB** (`site_planner.gd:1450-1473`): walks every `CollisionObject3D`,
matches `name.begins_with(p)` against a **9-entry whitelist**, `FSB_SOFT_PREFIXES`
(`site_planner.gd:1445-1447`):

```
fb_hootch  fb_gp_tent  fb_mess  fb_aid_station  fb_latrine
fb_supply_dump  fb_water_point  fb_burn_barrel  bwire_card
```

**Everything else is `hard_surface`.** Per-mesh granularity — good. Whitelist default is the
dangerous direction — a new tent that misses the list ships bulletproof, silently.

**Path B — world buildings via `place_structure`** (`site_planner.gd:162`, `collision_table.gd:293`):
`CollisionTable.is_soft(model_name)` keyed on the **GLB file basename**, then
`tag_ballistics(body, soft)` paints **one bit over the entire subtree** (`site_planner.gd:137-144`).

**Path B is ONE BIT PER FILE.** A hooch whose walls are screen and thatch but whose sleeping end is
sandbag-revetted — exactly the "screened-wall hooches" and "dug-in earth bunker hooch" on the
table — **cannot be expressed at all.** It is either entirely shootable through or entirely
bulletproof. The interior/exterior material distinction that makes a walkable interior *mean*
something tactically has no representation in Path B.

At hundreds of village buildings, Path B is the only path. **Walkable interiors and one-bit-per-file
ballistics are incompatible ideas, and nobody has said so out loud.**

### 3b. THE LANDMINE, and it is armed by his own words

`collision_table.gd:302-312` keeps the retired filename heuristic as a "loud fallback":

```gdscript
const _SOFT_NAME_HINTS: Array[String] = ["hooch", "hootch", "hut", "thatch", "bamboo",
    "fence", "shack", "lean_to", "leanto", "basket", "drying", "hedge", "brush", "cart"]
```

The file's own header (`:188-198`) documents why this was retired:

> `barracks_bunker.glb  -> SOFT COVER (matched "rack")  *** A BUNKER ***`

**The proposal contains the phrase "dug-in earth bunker hooch."**

Any GLB whose filename contains `hooch` — `hooch_bunker_dugin.glb`, `hooch_earth_bunker.glb`,
`platoon_hooch_dug.glb` — and which is missing from `MATERIALS` **guesses SOFT and ships shootable
through.** An earth bunker you can put a 7.62 through. It is `barracks_bunker` reincarnated, and the
proposal's own vocabulary is what arms it.

It does at least `push_warning` (`:297`). Ask yourself honestly how many `push_warning` lines get
read in a boot log that already prints the FSB collider census, the ballistic tally, the interior
cull count, the backface count and the NavBaker per-region report.

### 3c. The silent one — `get_entry` does NOT warn

```gdscript
static func get_entry(model_name: String) -> Dictionary:
    return STRUCTURES.get(model_name, {"box": Vector3(3, 2, 3), "y_offset": 1.0,
                                       "footprint": Vector2(4, 4), "scale": 1.0})
```
`collision_table.gd:182-183`

**No warning. None.** An unknown model gets a silent **3 × 2 × 3 m** box. `is_soft` warns loudly for
the same gap; `get_entry` says nothing.

Consequence for a new 12 m officers' HQ tent with no table entry: a 3 m collision cube (if
`mesh:false`), and — worse, because it happens *even with* `mesh:true` (`:177-181`) — **a 3 m nav
carve under a 12 m building.** Nine metres of tent that the navmesh believes is open ground. Men
path confidently into canvas.

**This asymmetry is a bug, and it is the one that scales worst.** At four buildings you would notice.
At forty-four you would not.

### 3d. The skill written to prevent all of this has itself drifted

`~/.claude/skills/recon-destructible-export/SKILL.md` is the document whose entire job is stopping
silent contract breaks. Its pointers, checked against the files today:

| skill says | actually at | drift |
|---|---|---|
| `site_planner.gd:1356 _tag_fsb_ballistics` | **`:1450`** | −94 |
| `FSB_SOFT_PREFIXES` at `:1351-1353` | **`:1445-1447`** | −94 |
| `_wire_parapet_destructibles` at `:1496` | **`:1590`** | −94 |
| `place_structure` at `:162-189` | **`:148-204`** | −14 |
| `tag_ballistics` at `:151` | **`:137`** | −14 |

**Every pointer in the destructible-export contract is wrong.** POINTER LAW, in the artefact that
exists to enforce contracts. Fix before any export run, or the next agent reads the wrong function.

**SACRIFICED:** the whitelist-default architecture is safe at ~10 hand-checked firebase families and
is not safe at ~44 procedurally-stamped village buildings. Scaling it means either auditing every
name by hand every export, or replacing the default-hard/default-guess design — neither of which is
art work, and neither of which is in the estimate.

---

## 4. "WORKING DOORS" AND "WALKABLE INTERIORS" — the systems that do not exist

### 4a. There is no door system. At all.

Repo-wide grep for doors in `scripts/`: **zero** generic door code. What exists:

- Huey cabin doors — a bespoke two-clip slide on the airframe (`heli_lift.gd:184-203`)
- Punji trap lids — *"GLB carries the doors as two separate clips"* (`punji_trap.gd:115`)
- `wall_straight_door.glb` — a ruins wall with a door-shaped **hole**. Not a door.

Both real cases are hardcoded `AnimationPlayer` clips on one specific prop. **Neither is a system.**

### 4b. There is no interaction registry either

`_try_field_interact` (`player.gd:949+`) is a **hardcoded if/else priority ladder**: medic crate →
tunnel exit → tunnel cache → MG emplacement → RTO handset → temple shrine → tunnel entrance. One
`interact` key, one fixed chain, no registration, no proximity arbitration.

Every door in the world would have to be inserted into that chain and would then **compete for the
same key** with the medkit crate, the MG mount and the RTO. `player.gd:950-951` already worries about
exactly this: *"First because it is the smallest, most specific target in reach — a man standing over
it is reaching for it, not for the MG two metres past it."* Now put a door frame around them both.

**"Working doors" is a code feature — an interaction registry with spatial arbitration — priced at
zero and scheduled as art.**

### 4c. AI cannot enter ANY building placed by `place_structure`, and never has

This is the finding I would most like on the record.

`place_structure` (`site_planner.gd:176-181`) sets `nav_blockers` + `nav_box` = the **full building
box** — *including for `mesh:true` enterable buildings.* `nav_baker._add_structures`
(`nav_baker.gd:441-459`) then calls `add_projected_obstruction()` on that footprint, **inflated by
`AGENT_RADIUS + 0.15`**.

**Every village hut is a solid navmesh hole, inflated 0.65 m beyond its own walls.**

`collision_table.gd:11` says of the village set: *"ALL trimesh: these are enterable, and a box hull
would seal the doorway the generator verified you can walk through."* The doorway is walkable **for
the player**. The navmesh has never had a polygon inside any of these buildings. **The AI has never
been able to follow you in, and cannot today.**

`NAV_IGNORE_PREFIXES` (`nav_baker.gd:371`) is `["fb_veg_", "fb_int_"]` — firebase-only, and it
exempts *props*, not buildings.

**A walkable interior the AI cannot enter is not cover. It is a safe room.** The player who steps
inside becomes unreachable by anything nav-bound. Against Pillar 1 (*believable firefights*) and
Pillar 5 (*fail forward, not a sadism simulator — but death matters*), **an invulnerability closet in
every hut is worse than no interior at all.** Enemies stack outside a doorway they will never cross.

Fixing it means the firebase treatment — feeding real `-colonly` trimeshes into the bake per building
(`nav_baker.gd:36-42`, written specifically because the projected-carve path *"would run flat through
every bunker and berm, and the men would path INTO walls with full confidence — worse than no
navmesh, because it would look deliberate"*). That is a per-building nav re-architecture, at
~44 buildings, and it is code.

### 4d. Under-terrain bunkers entered by stairs — three hard blockers

1. **The navmesh source is a solid heightmap sheet.** `_add_terrain` (`nav_baker.gd:326-344`)
   synthesises terrain faces at 4 m steps across the whole region box. **A room dug under that sheet
   bakes underneath a solid nav floor.** There is no hole-punching in the terrain and none in the
   nav source.
2. **`agent_max_climb` is 0.4 m** (`nav_baker.gd:270`), agent height 1.8 m, radius 0.5 m
   (`:46-47`). A stairwell must be a Recast-walkable ramp under a 1.8 m headroom clearance the whole
   way down. A dug-in hooch with a low roof — which is the entire visual point of a dug-in
   hooch — is right at or under that clearance.
3. **The only under-terrain precedent is a teleport, not stairs.** `TunnelRoom`
   (`tunnel_room.gd:15-20`) instantiates a procedural box room **40 m below** the entrance and
   *warps* the player in and out (`player.gd:962-967`). No AI, no navmesh, no stairs, and one of the
   three engine-exempt real-time lights in the whole game (`tunnel_room.gd:55`, named in
   `PERF_LEDGER.md:474`).

**"Under-terrain bunker entered by stairs" has no precedent, no nav support, and no terrain support.
It is a research task wearing a modelling task's clothes.**

---

## 5. ITERATION COST vs. THE 1–2 DAY ESTIMATE — a workflow argument, not a calendar one

I am **not** claiming he cannot model a hooch in 1–2 days. `ART_GAPS_2026-08-07.md:7-8` records his
own measured velocity — *"~1 large animation sequence OR 1–2 models per working day"* — and the
history backs it. **The modelling estimate is credible.**

**The estimate is not wrong. It is scoped to the wrong verb.** It prices *modelling*. It does not
price *landing*.

### What the record shows about landing

| build | modelled | in the game |
|---|---|---|
| chow hall | 8/2–8/3 (`ART_Track_Log.md:264`) | **no** — `fsb_main_v3.glb` is 7/26 |
| medical complex | built, eaten 7/31, recovered 8/2, anims 8/12 | **no** |
| crewed mortar pit | 8/7 | **no** |

**Three buildings finished across ten days; zero landed.** `SHIP_AUDIT_2026-08-11.md:22-27` calls
this out as *"sixteen days of finished art has not reached the game"* and names it **"the scope
problem… an art bottleneck that has not moved."**

The bottleneck is **demonstrably not modelling speed.** It is the seven-contract re-export in §2c
sitting on an un-fixed content-eating save (§0). **Adding buildings upstream of a blocked valve
does not produce buildings in the game; it produces more `.blend` files with finished work in them.**

### The steps between "modelled" and "in the game," none of them in the 1–2 days

`CollisionTable` entry · authored material (or the §3b landmine fires) · `mesh:true` · winding
verify · ballistic prefix or `MATERIALS` row · destructible manifest regenerated *from the same
export* · mound manifest + marker re-placement in the same session · nav re-bake verified ·
`FSB_FLATTEN_RADIUS` re-checked · `dedupe_images` run · three boot-log counts read.

**Every one of those has failed on this project at least once, in writing.**

### There is also a prior scope ruling this proposal crosses

`ART_GAPS_2026-08-07.md`, WORLD table, verbatim:

| Missing | Cost | Notes |
|---|---|---|
| **Firebase interiors** — "about half done" | **1–2 art-days** | Day half of the arc. |
| **Village buildings fleshed out / CQB geometry** — *his ask* | **large** | **[POST-LAUNCH]** — cut by the EA scope ruling. *"Villages read fine at patrol distance."* |

**The four named buildings sit inside a ruling already made. "Whole villages and enemy camps" is a
reversal of one.** I am not saying he cannot reverse his own ruling — he obviously can, and it is his
alone to make. I am saying the reversal should be *made deliberately and named as one*, not arrive
attached to a hooch estimate. Reversing it silently is how this project generates drift.

**SACRIFICED, named plainly:** every art-day spent on interiors is a day not spent on the six
priced, unbuilt items sitting in `ART_GAPS` right now — `m72_law_fp.glb` (a **failing test**: the LAW
is reachable from the armorer's bench and has no viewmodel), the M79 at 60%, M26 hip markers,
NVA/VC headgear, the ZPU #2 gunner, the `us_pilot_white` gib contract (**also failing**). And the
`fb_howitzer_i` pieces are still **statues — 6 static meshes, 0 animations** — under a fully built,
fully wired artillery crew. **That last one is the sharpest opportunity cost on the board: the crew
is done and the gun it serves does not move.**

---

## 6. THE CHEAPEST FAKE — what buys 80% for ~10%

Ordered cheapest-first. Every item reuses machinery that already exists and ships.

### 6.1 The recessed doorway (the single best trade)
Boolean a **1.5–2.5 m dark recess** into the doorway of the existing 26 village GLBs. The eye reads
depth; the player can step *into* the threshold; no room is modelled, no nav changes, no ballistics
change, no new `CollisionTable` entry. Roughly **one boolean per hut on models that already exist.**
This is the single highest read-per-hour operation available.

### 6.2 One interior kit, instanced — never per-building interiors
The firebase's 178 props over ~10 buildings is **~18 hand-placed props per building**. Author **one**
`int_hooch_kit` — bunk, mosquito net, footlocker, hanging bulb, footwear — and instance it. A fix is
then *one edit*, not forty-four. `site_planner.gd:1338-1356` already has the prefix-driven 40 m cull;
generalise `INTERIOR_PROP_PREFIX` from `fb_int_` to a shared `int_` and villages inherit it free.
Folding each prop *type* into a MultiMesh (368 surfaces → ~11) is already named in-code as *"the
rest"* of the fix (`:1336-1337`) and is the correct answer to §1's draw-call problem.

### 6.3 Doors without a door system
A **hanging poncho / screen-door card** on a two-frame `AnimationPlayer` fired by an `Area3D`
trigger. No interaction key. No insertion into `_try_field_interact`'s chain. No arbitration against
the medkit crate. The Huey cabin door already proves the exact pattern
(`heli_lift.gd:184-203`). **A screen door that swings as you walk through reads more "lived-in" than
a hinged door you must press F to open — and costs a fraction of it.**

### 6.4 Sell the interior with light and sound, not geometry
12 ambience beds exist and every one is wired (`ART_Track_Log.md:78-80`). Darkness plus a muffled
audio transition plus a recessed threshold is most of what "this is a place people live" means.
`gun_fx`'s unshaded additive-billboard technique (`PERF_LEDGER.md:466-470`) gives a hanging-bulb glow
with **zero real-time lights** — ADR-026 compliant, and measured as inside the noise floor.

### 6.5 If a building must genuinely be enterable: one archetype, instanced
Build the two screened hooches as an **interior-first master** — his own decree, applied to the Huey
(`ART_Track_Log.md:374-377`) — and instance it. One nav treatment, one collision contract, one
ballistic tag, one place to fix a bug. **Not forty-four bespoke rooms.**

### 6.6 What the fake sacrifices — said honestly, because no decision is free
- **No CQB.** No room-clearing, no "the squad stacks on the door." That is a genuine Pillar-1 loss
  and I will not pretend otherwise.
- **No interior firefight.** A recess is concealment, not a fighting position.
- **The dug-in hippie bunker loses its punch.** *Platoon*'s underground scene is a *room* — that one
  specifically may be worth building for real, as a one-off, precisely because it is a set-piece and
  not a template.

**But note what the fake also AVOIDS**, which is not a cost — it is the whole argument: **a walkable
room the AI cannot path into is a player invulnerability closet** (§4c). A recess you can stand in
but not hide in is *more* Pillar-1-honest than a room the enemy is nav-forbidden to enter. **Until
the nav work in §4c is done, the fake is not merely cheaper — it is more correct.**

---

## 7. BROKEN / FOSSIL — found while looking

| # | Finding | Pointer | Severity |
|---|---|---|---|
| **B1** | **`export_firebase()` still saves over the source `.blend`, after a zero-user purge.** The "standing fix owed" from the 7/31 medical-complex loss was never made. | `tools/gen_firebase_v3.py:929`, `:1105` | **CRITICAL — live** |
| **B2** | **`CollisionTable.get_entry` silently defaults to a 3×2×3 box, no warning** — asymmetric with `is_soft`'s loud warning at `:297`. Drives *both* collision and the nav carve. | `collision_table.gd:182-183` | **High** |
| **B3** | **`_SOFT_NAME_HINTS` still contains `hooch`/`hootch`/`hut`/`bamboo`.** A "dug-in earth bunker hooch" GLB missing from `MATERIALS` guesses **SOFT** — a bunker you can shoot through. `barracks_bunker` reincarnated by the proposal's own vocabulary. | `collision_table.gd:303-304` | **High** |
| **B4** | **Every `file:line` in the `recon-destructible-export` skill is wrong** (94-line drift on five pointers). The contract document that exists to prevent silent breaks has itself drifted. | see §3d | **High — POINTER LAW** |
| **B5** | **Four runtime GLB patches are pre-fossils.** `_repair_glb_colliders` `:1378`, `_force_backface_collision` `:1364`, `_remesh_collider` `:1481`, `_cull_interior_props` `:1343`. Their own comment: *"When the re-exported GLB lands both counts come back 0 and this whole function is deleted"* (`:1295-1296`). They have been about-to-be-deleted since 7/29. **Any new export must be checked against them**, or they silently re-repair (or fail to repair) new geometry. | `site_planner.gd:1293-1296` | Medium |
| **B6** | **AI cannot path inside any `place_structure` building, and never could.** Full-footprint projected obstruction inflated by `AGENT_RADIUS + 0.15`, applied even to `mesh:true` "enterable" models. | `site_planner.gd:176-181` + `nav_baker.gd:441-459` | **High — design-invalidating for §4c** |
| **B7** | Surface-count drift: `DEMO_SESSION_HANDOFF_2026-07-30.md:77` says **826 visible surfaces / 178 props / 368 surfaces**; the GLB parses to **578 primitive groups / 356 `fb_int_` nodes**. Two counts, different things, neither doc says which. | see §1a | Low — doc hygiene |
| **B8** | `ART_Track_Log.md:45` asserts *"Roads — LIVE (as of 2026-07-24)"* with his own contradiction on the same line: *"I haven't seen any real roads in the game as of 8/6."* Unresolved for six days. | `ART_Track_Log.md:45` | Low — but it is a live doc lying |

---

## 8. THE OBJECTIONS, RANKED

1. **B1 — the export still eats its own source.** Everything else is downstream. Eight lines.
2. **The valve is shut, not the tap.** Three finished buildings, zero landed, ten days
   (`SHIP_AUDIT_2026-08-11.md:22-27`). More buildings upstream of a blocked re-export produce more
   stranded `.blend` files, not more game.
3. **B6 — AI cannot enter any village building.** A walkable interior the enemy is nav-forbidden to
   cross is a player safe room. **Against Pillar 1.** This alone should change the shape of the
   interior plan, independent of everything else.
4. **Interiors are the worst possible content class for this engine budget.** 45% of draw calls for
   3.75% of geometry, in a project whose *only* measured lever is draw calls. And the 40 m cull that
   makes it survivable is firebase-only; villages draw interiors from 230 m.
5. **"Working doors" is uncosted code**, not art — there is no door system and no interaction
   registry, only a hardcoded seven-branch key chain.
6. **B3 — the naming landmine is armed by the proposal's own words.** `hooch` + `bunker` in one
   filename = a shootable-through bunker, silently, on a `push_warning` nobody reads.
7. **Under-terrain stairs have no precedent, no nav support, no terrain support.** The only existing
   under-terrain space is a teleport.
8. **One bit of ballistics per file (§3a)** cannot express a screened hooch with a sandbagged sleeping
   end — the exact building on the table.
9. **"Whole villages and enemy camps" reverses a ruling made 5 days ago** (`ART_GAPS_2026-08-07`,
   *[POST-LAUNCH], large*). His to reverse — but it should be reversed *out loud*.

---

## 9. WHAT I WOULD MAKE THE COUNCIL ANSWER BEFORE ANY MODELLING BEGINS

1. **Is a "building" a mesh family inside `fsb_main_v3.glb`, or its own GLB?** Both horns cost
   (§2e). The answer changes every contract in §3.
2. **Is B1 fixed first?** If not, name who is copying the `.blend` before every export, by hand,
   every time.
3. **Does AI need to enter these interiors?** If yes, the per-building nav rework (§4c) is in scope
   and is *code*. If no, the recess (§6.1) is strictly better than a room.
4. **Do "working doors" mean an interaction registry?** If yes it is a code feature. If no, §6.3
   costs almost nothing.
5. **What comes off the board?** `m72_law_fp.glb` and `us_pilot_white`'s gib contract are **failing
   tests today**, and the artillery crew is fully built and wired behind **six howitzer statues with
   zero animations.** Those are the days interiors would be spending.

---

*No decision is free. The recessed-doorway fake sacrifices CQB and the interior firefight, and that is
a real Pillar-1 loss. Full walkable interiors sacrifice the project's only measured performance
lever, hand a player-only safe room to every hut until the nav work is done, and route four more
buildings through an export that still overwrites its own source. **I am not arguing he should not
build them. I am arguing that until §0 is fixed and §4c is answered, the buildings will not arrive —
and that the recess is not merely cheaper than the room, it is more correct than the room.***
