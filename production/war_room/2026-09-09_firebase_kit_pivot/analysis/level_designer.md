# LEVEL DESIGNER — analysis

**Council:** 2026-09-09 firebase kit pivot · **Read-only session.** Caleb playing live (pid 13196);
no process touched, no window opened, **no probe run**. Every number is a direct file read, a direct
parse of the shipped GLB, or a line lifted out of a log **his own session wrote**.

---

# ASSIGNMENT 1 — "i still ahvent seen any like dirt roads in the world"

## VERDICT: **(a) BUG WITH A KNOWN CAUSE — two causes, both measured, both arithmetic.**
Not (b), not (c). The Arbiter's course correction asked me to rank five candidates. Four of the five
are **refuted**, one is **confirmed as a partial cause**, and the dominant cause is **a sixth the
Arbiter did not have**. All six are settled below by measurement, not reasoning.

---

## 0 · Answering the Arbiter's five candidates, ranked by evidence

### **(a) "THE PRINT MAY LIE" — REFUTED.**
`stamp_ground_line` early-returns on `clearing_texture == null or terrain_manager == null`
(`clearing_system.gd:248`). Neither can be null at `mission_generator.gd:909`:

- **There is no `initialize()`.** The function at `clearing_system.gd:71-78` is `_init_vegetation_map()`,
  and it is called from **`_ready()`** (`clearing_system.gd:64-65`). `ClearingSystem` is an **autoload**
  (`project.godot:40`), so `_ready()` fires at engine boot — long before any world exists.
  `clearing_texture` is non-null from the first frame of the process.
- `terrain_manager` is set at `game_world.gd:160` inside `_on_terrain_ready`, which runs before
  `build_patrol_world`.

The print does not lie about writing. **Retire this candidate.**

### **(b) "ORDERING vs THE SIGNAL / already-built chunks" — REFUTED.**
`set_shader_texture` writes to the **static, shared** material (`terrain_chunk.gd:243-249`), and every
chunk binds that same object: `mesh_instance.material_override = shared_material`
(`terrain_chunk.gd:175`). **There is ONE material for the whole terrain.** A write reaches every chunk
that exists and every chunk built afterwards, in the same instant, regardless of signal ordering.
**Retire this candidate.**

### **(c) FALLBACK MATERIAL — REFUTED.**
His own session log carries `[TerrainChunk] Using terrain shader with ground textures`
(the `_using_shader = true` branch, `terrain_chunk.gd:224-226`). The demo is on the shader path.
**Retire this candidate.**

### **(e) SCALE / OFFSET — REFUTED.**
The demo is 512 m with `CELL_SIZE 4.0` (`world_config.gd:11`). `HeightmapStorage` gives
`size = ceil(512/4) = 128`, chunk-aligned to **128** (`heightmap_storage.gd:22-34`). The shader's
overlay UV is `world_pos.xz / (terrain_size * cell_size)` (`terrain.gdshader:101`) =
**128 × 4 = 512 m = map_size exactly.** No stretch, no offset. The firebase sits at 256,256 and the
demo road runs from ~96 m to ~185 m from centre — **every coordinate positive**, nothing clipped by
`maxi(0, lo.x)`. **Retire this candidate.**

### **(d) COVERAGE — CONFIRMED, and it is cause #2 below.**
Sharpened from "check where the segments are" into an exact colour collision. See §2.

### **(f) THE ARBITER DID NOT HAVE THIS ONE — and it is the dominant cause.** See §1.

---

## 1 · CAUSE #1 (dominant) — the "cleared corridor" is a chain of TANGENT BUBBLES, so the jungle is still standing in the road every ten metres

`clear_corridor` (`road_network.gd:383-391`) calls
`VegetationManager.clear_area(p, ROAD_HALF_WIDTH_M, …)` **once per polyline point**. And:

| Constant | Value | Pointer |
|---|---|---|
| `ROAD_HALF_WIDTH_M` | **5.0** | `road_network.gd:36` |
| `POINT_SPACING_M` | **10.0** | `road_network.gd:38` |
| the clear's shape | a **sphere**: `{"c": center, "r2": radius*radius}` | `vegetation_manager.gd:519` |

**Discs of radius 5 m spaced 10 m apart are TANGENT. They do not overlap anywhere.**

- Cleared width at the midpoint between two consecutive road points: `2·√(5² − 5²)` = **0.00 m.**
- Cleared area per 10 m of road: `π·5²` = **78.5 m²** out of a nominal 10 m × 10 m = 100 m² band.
  **21.5 % of the corridor keeps its jungle — and it is the wrong 21.5 %.**
- A tree standing **1 metre off the centreline** at every 10 m interval survives untouched:
  `5² + 1² = 26 > 25`.

So the plants were **never pulled off the road**. Meanwhile the dust band underneath **is** continuous,
because `stamp_ground_line` is a true polyline stamp (`clearing_system.gd:246-277`). The result is
exactly what he described: **a brown stripe with jungle growing out of the middle of it, every ten
metres, for the whole length of the road.** You cannot see down a line you cannot see down.

**The file contradicts itself about this.** `road_network.gd:26-30` claims the corridor is
*"a corridor of open sky … a road reads as a corridor of open sky, not as a texture."*
**It is not, and it never was.** That header should be corrected in the same change that fixes the
stride (NO MORE DRIFT — see §5).

**Cheapest credible fix — a loop stride, not a system.** Decouple the clearing stride from the
polyline stride inside `clear_corridor`:

| clear stride | clear width at the pinch |
|---|---|
| 10 m (today) | **0.00 m** |
| 7 m | 7.1 m |
| **5 m** | **8.66 m** — a genuinely open 10 m corridor |

It touches neither routing, nor seating, nor the convoy, nor determinism (the stride is a constant,
not a draw). **Hours, not days.** *NOT AUTHORISED HERE — a change to a shipped system inside a ship
window is the Arbiter's call.*

---

## 2 · CAUSE #2 — where he would FIRST look for the road, the road is painted the same brown as the ground

This is the Arbiter's candidate (d), turned into arithmetic.

| Colour | Value | Pointer |
|---|---|---|
| Firebase clearing, `CLEARED` stage — *"Exposed dirt"* | `Color(0.45, 0.38, 0.28)` | `clearing_system.gd:38` |
| `FORTIFIED` stage — *"Packed earth"* | `Color(0.52, 0.45, 0.35)` | `clearing_system.gd:44` |
| **`ROAD_DUST`** | **`Color(0.42, 0.35, 0.24)`** | `road_network.gd:378` |

**The road dust is within 0.03–0.04 per channel of the ground the firebase already painted.**

The firebase stamps a `CLEARED` zone of **radius 120 m** at the compound centre
(`FSB_CLEAR_DISCS = [[Vector3.ZERO, 120.0]]`, `site_planner.gd:1078-1080`, applied by
`clear_and_flatten` → `ClearingSystem.create_zone` + `set_zone_stage(CLEARED)`,
`site_planner.gd:123-133`), at alpha up to `(1 − 0.05) = 0.95` (`clearing_system.gd:207`).

The demo road starts at the **gate**, and the wire sits **49.4–96.0 m from compound centre**
(measured, his own log: `[FSB] parapet radii: 81 segment(s) spanning 49.4-96.0m from centre`). So the
**first ~24 m of the demo road, and its entire feathered approach, lies inside the firebase's own dirt
disc.**

Composite the two writes (`clearing_system.gd:270-277`, `alpha` only ever RISES via `maxf`):

```
inside the disc:  base (0.45, 0.38, 0.28) @ a=0.95
road stamp:       lerp toward (0.42, 0.35, 0.24) @ a=0.72
result:           (0.4284, 0.3584, 0.2512)   —  ΔRGB = 0.022 / 0.022 / 0.029
```

**A ~2–3 % albedo step.** For scale, the terrain shader's own per-pixel colour noise is ±0.01
(`color_noise_strength = 0.1` at `terrain.gdshader:36`, applied as `color += vec3(variation)*0.1` at
`:122`). **The road's contrast against cleared ground is only 2–3× the terrain's own noise floor**, at
PSX fidelity, in a jungle, under a normal map.

**This is why his first impression is "there are no roads."** He walks out the gate — the one place he
would look — and the road there is invisible *by colour*. Further out, past 120 m, the colour works
fine but the trees are standing in it (cause #1). **Two independent mechanisms, in exactly the order
he would meet them.**

Fix is one constant: darken/redden `ROAD_DUST` away from the clearing palette (a laterite road is more
saturated and more orange than turned earth — something nearer `Color(0.46, 0.30, 0.17)`), and/or raise
`ROAD_DUST_STRENGTH`. **Not authorised here; it is a one-line art call and it is HIS colour to pick.**

---

## 3 · What DOES exist — so nobody re-derives it

| Piece | Pointer |
|---|---|
| The authority | `scripts/world/road_network.gd`, 458 lines, `class_name RoadNetwork` |
| Routing | A\* over the gameplay grid's own cost field, `road_network.gd:146-223` |
| Seating | `_seat_and_resample`, `:278-309` — a point's Y is always the ground's Y |
| Blockers | reads the real `nav_blockers` bodies, `:95-105` |
| Built into the world | `mission_generator.gd:909-915`, after every site is stamped |
| Convoys drive it | `mission_generator.gd:339-360`, `longest_route()` |
| Ambush planner reads it | `ambush_planner.gd:48-99`, `distance_to_road()` |
| Topo map draws it | `scripts/ui/topo_map.gd` |
| Probe, with negative controls | `tests/test_roads.gd:3-8` |

**Measured in his own session logs, 2026-09-09:**
`[ROADS] dust stamped on 163 segment line(s)` (`recon2026-09-09T13.39.43.log:378`) — 163 × 10 m ≈
**1,630 m of road** on the 1280 m patrol map (`…:5`). An earlier 512 m-scale run in the same session
logged **28 lines ≈ 280 m**, which is exactly right for the demo: `plan_demo_world` creates **one**
village (`mission_generator.gd:749`, `demo_villages = [village]`) and therefore **one** road.

---

## 4 · Traffic — does the road match anything that drives?

Yes by design; **unverified in practice**, and I will not run a probe to find out.

- The convoy takes `road_network.longest_route()` verbatim (`mission_generator.gd:347-360`). **The road
  IS the route.** There is no second path, so a fixed road is automatically a road with traffic on it.
- All five vehicle GLBs exist and resolve (`assets/us/vehicles/` — `m151_mutt_gun_jeep_v2` 101 KB,
  `m35_deuce_truck_v2` 115 KB, `m113_apc_v2` 149 KB, verified by listing).
- The column now spawns **on** the road rather than strung back off it — `convoy_spawner.gd:102-108`
  records that fix, which was the old "convoys drive through buildings" report.

**UNVERIFIED: whether a convoy has ever actually driven in his demo.** `ConvoySpawner` contains **zero
`print` calls**, so its absence from the log is not evidence either way. One named hazard is worth a
single print to settle, and it belongs on the triage list with the convoy observation he raised:

> `_wire_systems` computes `fire_day` from `SimClock.sim_day` (`mission_generator.gd:250-260`) **before**
> `demo_game.gd:162` resets the clock to day 1. `SimClock` is an **autoload**, so `sim_day` survives the
> previous run. `_spawn_due` requires `sd == cur_day` **and** `int(sh) == int(sim_hour)`
> (`convoy_spawner.gd:69-76`) — a stale day schedules the convoy on a day the demo never reaches, and it
> then fails **silently, forever.**

### `fb_road_gate` is a stub, not a road
`gen_firebase_v3.py:1086-1087` builds a mud ribbon from `R0−7` to `R0+26` at 5 m width, named
`fb_road_gate`, on `COL_NONE` (`:875`) — pure dressing, **33 m long, and then it stops.** The
procedural road starts at `gate_pos`, taken from the GLB's own `SOCKET_A/B` markers
(`site_planner.gd:1577-1591`), so the two *should* meet at the wire. **Whether they visually join —
UNVERIFIED.** One look, not a probe.

---

## 5 · NO MORE DRIFT — three stale claims found on contact

1. **`mission_generator.gd:911-913`** — *"The only write a road performs: vegetation bundles thinned
   along the corridor - never height, never terrain_type, never water."* **Stale since commit
   `85ab41cf` (2026-08-12):** `clear_corridor` now also calls `_stamp_dust()` (`road_network.gd:390`),
   which writes the ground overlay. *(The Arbiter has this and is fixing it.)*
2. **`road_network.gd:26-30`, the file's own header** — same stale claim, in the file that later adds
   the dust at `:374-405`. **The file contradicts itself.** Fix both in the same change.
3. **`road_network.gd:26-30` also claims the corridor is "a corridor of open sky."** §1 shows the
   geometry it emits is a string of tangent bubbles. The header describes a corridor the code has never
   produced.

---

## 6 · Against Pillar 2 and Pillar 3 — and the honest scope call

**Pillar 2 (Atmosphere): the fix is cheap and the payoff is large.** A laterite road out the wire with
a convoy on it is the most period-legible thing this AO could have, and ~95 % of it is already built and
running every boot. Not shipping it is throwing away a working system for want of a stride and a colour.

**Pillar 3 (Freedom): this is the constraint that decides the scope.** The road already refuses to be a
rail, deliberately and in writing — *"Roads terminate at FORDS, never bridges. A bridge is a chokepoint
with no alternative crossing, which is a rail (Pillar 3)"* (`road_network.gd:23-24`) — and the ambush
planner treats road proximity as *"a preference, never a gate"* with multiplicative weighting that
*"cannot zero a site"* (`ambush_planner.gd:4, 24`). **Do not touch either.**

And it means: **do not add more roads to make them findable.** The demo has one village, therefore one
road, on one bearing (135° off `gate_out`, `mission_generator.gd:735-745`). The temptation after fixing
the stride will be *"he still might not find it — connect the temple, connect the camps."* A VC camp on
a road is absurd on its face (`road_network.gd:85-87` says so), and a map where every bearing has a road
is a map where the player walks roads. **One road he might miss is CORRECT. Pillar 3 is the reason.**

| Work | Verdict |
|---|---|
| Clearing-stride fix — the trees standing in the road | **DEMO. It is the dominant defect.** |
| `ROAD_DUST` colour separated from the clearing palette | **DEMO. One constant, and it is his colour to pick.** |
| Convoy `fire_day` print + confirm one convoy drives | **DEMO** — his own triage item |
| Confirm `fb_road_gate` joins the routed road | **DEMO**, one look |
| Road MESH — ruts, kerbs, culverts, laterite geometry | **POST-DEMO. Build no road models.** |
| More roads / roads to camps / a followable network | **NEVER — Pillar 3** |

---
---

# ASSIGNMENT 2 — THE KIT, from a level-design lens

## 0 · What the monolith actually is (measured — direct parse of the shipped GLB)

I parsed `assets/world/building models/structures/firebase/fsb_main_v3.glb` directly (read-only, JSON
chunk, no engine):

- **5,810 nodes · 2,274 meshes**
- **4,572 of those nodes are SCENE ROOTS.** Only **423** nodes have any children at all.
- **89.3 %** of nodes carry a transform (5,191 / 5,810).
- **`fb_sbg_seg*`: 162 nodes, exactly 2 carrying a transform** — the `fb_sbg_seg_046.001` pair.

> **The briefing's central claim is CONFIRMED by independent parse: 80 of 81 perimeter wall segments
> carry no node transform.** Cross-checked against his own live log:
> `[FSB] parapet: 81 destructible segment(s) on the blast bus, 1 stray(s): 1 adopted` and
> `[FSB] parapet radii: 81 segment(s) spanning 49.4-96.0m from centre`
> (`recon2026-09-09T13.39.43.log:37-38`).

**And the finding nobody has stated yet: the GLB is not a hierarchy. It is a FLAT BAG with a naming
convention laid over it.** There is no `hootch_m0` node with children — `fb_hwall_m0`,
`fb_hootch_screen_m0` and `door_hooch_screen` are all siblings at the top level. That cuts both ways:

- **Cheaper than feared** — "dissect the parts" is a *grouping by name* job, not a tree-splitting job.
- **More dangerous than it looks** — the ONLY thing saying which wall belongs to which hootch is a name
  suffix. `fb_sbg_seg_046.001` — one Blender `.001` duplicate — is already a live defect the game
  patches at boot (`…13.39.43.log:36`). Every dissection pass is name-driven, and ADR-042 is the
  standing proof that names fail **silently**.

---

## 1 · STAMP GRANULARITY — the concrete answer

### **Per functional PLACE. Not per building, not per wall segment.** Three tiers.

**TIER 1 — SITE PARTS. This is the stamp unit: ~15 classes, ~78 placements for a base this size.**
Each is one GLB with its own transform, its own colliders, its own `work_*` markers and its own NPC
contract. Counts are **instances** (GLB node counts halved — every solid carries a `-colonly` twin):

| Part class | Instances in the current base |
|---|---|
| `hootch` | **22** (ids `m0–m7`, `p0–p7`, `gm0`, `gm3`, `gp0–gp3`; 22 wall panels + 22 screens each) |
| `supply_dump` | 11 |
| `fighting_bunker` | 8 |
| `latrine` | 6 |
| `gun_pit` (+ `howitzer` seated inside it) | 6 |
| `mg_bunker` | 4 |
| `tower` | 4 |
| `sleeping_bunker` | 3 |
| `gp_tent` | 3 |
| `water_point` | 3 |
| `burn_barrel` | 3 |
| `helipad` | 2 |
| `toc` · `mess_hall` · `medical_complex` · `gate_gap` | 1 each |
| `mortar_pit` | present (`gen_firebase_v3.py:1108`) |

**TIER 2 — LINEAR PARTS. Instanced along a spline the designer draws. Never hand-placed.**

| Part class | Instances today |
|---|---|
| `sbg_seg` (perimeter parapet) | **81** |
| `sandbag_parapet` | 32 |
| `claymore` | **17** (his log: *"17 claymore(s) armed on the wire, facing out"*) |
| `bunker_steps` | 12 |
| `trench_run` | **8** |
| `duckboard` | 1 |

The machinery for *"evenly spaced points along a polyline, seated on terrain"* **already exists and is
proven in shipping code**: `RoadNetwork._seat_and_resample` (`road_network.gd:278-309`). **Reuse it.
Do not write a second one** — ADR-028 is the one-path law and this is the same shape of problem.

**TIER 3 — DRESSING. Rides inside its Tier-1 part's GLB. The designer never sees it.**

| Class | Nodes |
|---|---|
| `fb_int_*` interior props | 1,090 nodes = **545 props** |
| `MC_*` (spent / crate / casing) | 300 |
| `prop_*` | 229 |
| `m101_round` / `m101_trail_*` | 216 |
| `door_*` | 84 nodes = 42 doors |
| `fb_mud_patch`, `fb_scorch`, `fb_veg_*` | ~90 |

The fold already ships and already works — his log:
`[FSB] interior props folded: 545 prop(s) -> 69 MultiMesh(es), 1010 surface(s) -> 132, shown to 40-230m`
(line 47). **Do not expose 900+ dressing nodes to a human placer.** That is how 545 props became 545
unique nodes and 45 % of the compound's draw calls for 4 % of its geometry.

### Why NOT per wall segment
**81 hand placements to build one perimeter is not authoring, it is data entry** — and the moment he
morphs the hill under it, all 81 are wrong at once. The ring is a *function of the terrain*, not a
composition.

### Why NOT per building
The base's real vocabulary is **15 classes, not 78 objects.** A hootch is one part used 22 times.
Treating each of the 22 as bespoke re-creates the monolith at a smaller scale, which is the whole
disease.

### While we are here — ADR-041's open question 3: **YES, work markers ride on the parts.**
488 `work_*` markers live in the bake; his live garrison census plans **35 posts and places 36 men**
(`…13.39.43.log:247`). That 14:1 mismatch exists *because* the markers are in the model and the census
is in code. Markers on parts makes it **arithmetically impossible** — see §3.

---

## 2 · THE PERIMETER — procedural on a designer-drawn spline; the gate authored

**RECOMMENDATION: procedural.** Segments instanced along a spline he draws, with `gate_gap` kept as a
single authored Tier-1 part.

### WHAT IS SACRIFICED — named plainly: **the hand-composed silhouette of the ring.**
The current perimeter spans **49.4–96.0 m from centre** (his log, line 38) — a nearly 2:1 irregularity
that reads as a compound someone dug where the ground allowed. A spline + fixed stride will read as a
**fence** unless the instancer carries per-segment yaw jitter, height jitter and a seat-to-terrain step
**from version one.** Jitter is always the feature cut when a tool runs late. **If it is not in the
first version it will never be in any version**, and every firebase in the game becomes the same fence.

### Why procedural wins anyway, on this project's own evidence

1. **The siege bug cannot recur BY CONSTRUCTION.** An instanced segment has a node transform *because
   instancing is what creates a transform*. 80 of 81 segments have none today, so every sapper targeted
   the model root and the wire was never breached. This is not a bug a kit *fixes* — it is a bug a kit
   **cannot express**.
2. **The perimeter must follow terrain he just morphed.** That is the entire content of *"less a circle,
   more fitting the hill."* An authored 81-segment ring is invalidated by the first hill edit; a spline
   re-instances for free. **You cannot have both hand-authored perimeter geometry and terrain morphing** —
   that is the real trade, and it should be put to him in exactly those words.
3. It is the only version that scales to WW1 (§5).

### Author, don't generate, exactly ONE thing: the gate.
`fb_gate_gap` is a single instance today and should stay a single authored part. The gate is the one
point on the perimeter where the player's reading of the base is decided, and `fsb_gate_metrics` already
depends on authored `SOCKET_A_001 / SOCKET_B_001 / FACE_OUT_001` markers
(`site_planner.gd:1577-1591`). **Do not let a spline compute it.**

---

## 3 · "certian npcs thatll spawn with certian building combos" — the data shape

**Do not put a spawn table on the site.** Put a **role DEMAND on the part** and a **garrison BUDGET on
the site**, and let a resolver match them. Then *"a mess hall + a stove + 3 seats implies a cook and
diners"* **falls out arithmetically** instead of being written down somewhere that can drift.

### On the PART — ships in the part's own marker scene, beside its `work_*` markers
(ADR-041 §4 Tier A: *already legal, already shipping*.)

```
provides:   the markers this part carries, each tagged { role, station_kind }
            station_kind ∈ { stove, seat, counter, radio, cot, bunk, gun, tube, bench, wire_post }

demands:    roles the part cannot function without
            mess_hall     demands { mess_cook: 1 }
            gun_pit       demands { gun_crew_arty: 3 }
            tower         demands { sentry: 1 }

invites:    roles it will host if the site can pay
            mess_hall     invites { mess_diner: 0..seat_count }
            hootch        invites { off_duty: 0..bunk_count }

pairs_with: parts that RAISE a demand when co-present within a radius
            stove within 8 m of mess_hall        →  mess_cook 1 → 2
            supply_dump within 6 m of gun_pit    →  gun_crew_arty 3 → 5
            radio inside toc                     →  radioman 1 → 2
```

### On the SITE — the PLAN, never the scene (ADR-041 §1)

```
garrison: int      # men available
priority: [ ... ]  # the order invites are bought in
```

**The site pays every `demands` first, then buys `invites` down the priority list until the budget runs
out.** Everything unpaid is simply an **empty seat** — not a bug, not a warning, not a 488-vs-23
mismatch. **The mismatch becomes unrepresentable.**

### Seeded occupancy is BINDING here — ADR-041 §5
> *"He authors WHICH POSITIONS ARE GOOD. The seed chooses WHICH ARE OCCUPIED, and by how many."*

A fully hand-placed garrison makes the second playthrough a memorised fight. Author the posts, seed the
manning. This also survives contact with his own live census, which already reports
`6 (17%) on a job that reads as IDLE` — under a budget model that becomes a **tuning number**, not a
defect.

### THE ONE RULE THAT MUST BE IN THE DATA OR THIS ROTS
**A marker that is not reachable on the baked navmesh is not a station.** ADR-041 §5's BINDING
marker-vs-navmesh probe applies verbatim. The chow-hall fix that actually shipped was **16 markers moved
in the asset** (commit `8e1129c7`), *not code*. A kit multiplies that surface from 1 compound to ~78
parts. His log already carries two live instances of the identical bug class:

```
WARNING: [FSB] 2 curated post(s) name a marker the GLB does not carry
         - GUN_POINT_001 (gun_crew x2), APPROACH_002 (mess_cook x1)
```

**That warning is the kit's future at 78× the count, unless the probe ships with the FIRST part.**

---

## 4 · "remove people falling thru berms" — IS THE BERM A SPECIAL CASE?

## **YES. And a stamped kit ALONE DOES NOT FIX IT — it moves it, and in one respect makes it worse.**

This is the most important thing in my analysis and it must be settled before the part list is agreed.

### The measured mechanism, in order

1. **The compound's walkable ground IS the model, not the terrain.**
   `site_planner.gd:1837-1842` **keeps** the mound collider, and says why:
   > *"KEPT, not stripped (ruling 2026-07-29). This trimesh IS the walkable ground now. … The terrain no
   > longer climbs, so this is the only ground and it must stay."*

   Confirmed at every boot in his own log:
   `[FSB] kept 1 mound collider(s) - the MODEL is the ground` (line 28) and
   `[FSB] ground: 129 samples, terrain sits under the model everywhere (worst +0.00m)` (line 27).

2. **That ground is a one-sided `ConcavePolygonShape3D`.** `site_planner.gd:1801-1804` records that
   `fb_terrain_mound` and `fb_berm_ring` are **100 % down-facing**, and that a concave shape collides on
   its front face only. The game force-flips them at load:
   `[FSB] 1984 concave shape(s) forced double-sided (inward winding in the shipped GLB)` (line 30).

3. **Double-sided or not, a trimesh is a SHELL with zero interior.** It has **no depenetration volume**.
   A body that gets to the wrong side is pushed *further out*, not back. A berm is precisely the geometry
   that produces that: a steep face where step/slide resolves along the surface normal, and a crest where
   a fall arrives with enough per-tick displacement to cross a zero-thickness surface.

4. **The navmesh is baked ON that shell.** `nav_baker.gd:573` —
   `NAV_GROUND_PREFIXES = ["fb_terrain_mound", "fb_berm_ring"]`. NPCs are routed onto it **by design.**
   That is why it is *"people falling thru berms"* and not only the player.

### What a stamped kit does to this

- A stamped `berm_segment` that is still a trimesh shell **falls through in exactly the same way.**
- And stamping makes it worse in one specific respect: **81 independent shells have 81 SEAMS.** The
  monolith is at least one continuous surface. A segmented ring is 81 surfaces meeting at 81 joints,
  each one a place a capsule can find a gap the sculptor never saw.

### The fix — and it is the strongest argument for HIS terrain-morph tool

> ## **Make the berm TERRAIN RELIEF, not a mesh.**

A heightfield has no seams, no winding, no backface question and no zero thickness. The machinery is
already here and already runs every time a shell lands:

- `DamageSystem.modify_terrain()` edits the heightmap and rebuilds chunks. The heightmap edit itself is
  **0.1 ms**; the 80–94 ms is the chunk rebuild — **and a rebuild cost is FREE at edit time.** The most
  expensive part of the crater system is the part an authoring tool does not pay for.
- `fsb_mound_height()` (`site_planner.gd:998-1010`) already proves the whole compound's surface can be
  expressed as a **height function**, driven by `fsb_main_v3_mound.json` and a measured falloff
  (`FSB_PLATEAU_FALLOFF = 0.107`, `:967`).

The kit then supplies the **revetment that dresses the slope** — not the slope itself.

### Say it to him in one line
> **The kit does not fix falling through berms. Making the berm GROUND instead of a MODEL does. The kit
> is what makes that affordable.**

If the pivot is ratified without settling the ground contract first, he does the entire rework and
**still falls through berms — with more seams than he has now.**

### One caveat I must name, because it is HIS ruling being argued against
`site_planner.gd:1694-1699` records his own words for why the mesh is the ground:
> *"i want that mesh mound because it showed destroyed earth and mud, so just moving the world terrain
> up doesn't fix a lot of problems. A 4m heightmap cannot draw any of that at any setting."*

**He is right about the drawing and wrong about the colliding, and both can be true.** The resolution:
**the heightfield OWNS the collision; the mesh mound stays as VISUAL ONLY** (`COL_NONE`), drawn over a
terrain sculpted to the same surface. He keeps the destroyed earth and the mud; the physics stops being
a shell. That trade is his to make and it is **the single most important call in this council.**

---

## 5 · WW1 REUSE — the part-level answer, measured against the kit manifest

Source of truth for this section: **`assets/world/building models/structures/firebase/kit/firebase_set.json`**
— 23 parts, each with tris, size, `solid`, `enterable` and markers carrying `work_type` / `prop_class`.
I parsed it directly. **It changed two of my own conclusions, and both retractions are recorded below
rather than quietly fixed** (publish only what you checked).

### RETRACTION 1 — I was WRONG earlier in this council: the trench module IS genuinely missing

Earlier in this session I wrote that `FIREBASE_REWORK_INTENT.md:102-103` was stale because
`fb_trench_run` exists, ships, and is placed 8× (`gen_firebase_v3.py:1068-1074`). **I derived that from
the NAME and the placement code. The manifest measures the object, and the object is not a trench:**

```
fb_trench_run   tris=240   size=[6.0, 2.85, 0.45]   solid=true   enterable=FALSE   markers=[]
```

**0.45 metres tall. Not enterable. Zero markers.** A trench a man fights from is 1.8–2.2 m deep. This
part is a **6 m spoil ridge / revetted parapet lip laid ON the ground** — dressing that reads as a
trench from outside and that nobody can ever stand in. `enterable: false` is the contract saying so in
the data, and the empty marker list means no station can ever exist inside it.

> **The intent doc is CORRECT and my earlier correction is WITHDRAWN. The trench module is genuinely
> missing.** What exists is a trench-shaped decoration. The Arbiter should not carry my earlier
> "correction on contact" forward — this paragraph supersedes it.

**The lesson is worth one line, because it is the exact trap this project has a law about: a name is not
a measurement.** `fb_trench_run` reads as a trench in every grep, in the generator, in the ballistics
log and in my own first pass. The manifest is the first place in this repo that says what it actually is.

### RETRACTION 2 — my earlier "~15 % kit reuse" was an impression, not a count. The real number is far better.

### 5.1 · THE PART-BY-PART SPLIT — all 23

**UNCHANGED — transfers to a WW1 battlefield with no art work at all (6 of 23, ~26 %; ~580 tris)**

| Part | tris | Why it transfers |
|---|---|---|
| `fb_sandbag_stack` | 240 | A sandbag is a sandbag, 1914–1968. Unchanged. |
| `fb_berm_arc` | 72 | 9.2 × 2.6 × 1.2 earth arc — **this IS parapet geometry**, and mirrored it is parados. |
| `fb_trench_run` | 240 | Transfers unchanged **as what it actually is** — a parapet spoil lip. Just never call it a trench. |
| `fb_water_point` | 48 | A water point is a water point. |
| `fb_latrine` | 132 | Likewise. |
| `fb_burn_barrel` | 48 | A brazier in a bay is period-correct; at 48 tris and PSX texel density the drum reads. |

**RESKIN — same geometry, same footprint, same marker contract; new texture and at most a silhouette
tweak (12 of 23, ~52 %; ~26,900 tris retained)**

| Part | tris | WW1 role | Note |
|---|---|---|---|
| `fb_gun_pit` | 4860 | field-gun position | 9 × 9 × 1 pit geometry is right as-is |
| `fb_toc` | 4780 | battalion HQ dugout | `work_radio` retags to a field telephone — a marker + prop swap, not geometry |
| `fb_bunker_mg` | 3800 | MG post / pillbox | **the strongest single transfer** — `mg_fire_point` + `bunker_los_point` + `door_main` is exactly the WW1 contract |
| `fb_aid_station` | 3516 | regimental aid post | `work_aid`/medic unchanged |
| `fb_supply_dump` | 3152 | ration & ammo dump | crate silhouettes reskin |
| `fb_sleeping_bunker` | 3002 | deep dugout bunk chamber | **1.45 m tall already — correct for a dugout** |
| `fb_bunker_fighting` | 2884 | dugout shelter | enterable, has a door |
| `fb_mortar_pit` | 1944 | Stokes / Minenwerfer pit | 4.2 × 4.2 × 1.4 pit is right |
| `fb_gp_tent` | 888 | rear-area marquee | non-solid, enterable |
| `fb_mess` | 528 | cookhouse | `work_mess`/cook unchanged |
| `fb_howitzer` | 288 | 18-pdr / 77 mm | 288 tris — a reskin here is nearly a rebuild, but a cheap one |
| `fb_wire_belt` | 144 | wire belt | wire is wire; WW1 wants **screw pickets** and **10–30 m of DEPTH**, which is many parallel instanced rows — **tool behaviour, not art** |

**VIETNAM-ONLY — geometry that does not transfer (5 of 23, ~22 %; ~9,800 tris discarded)**

| Part | tris | Why not |
|---|---|---|
| `fb_tower` | 4348 | A 9.7 m timber OP standing over a Western Front trench line is shelled flat in an hour. WW1 observation is a periscope, a sap head or a rear OP. |
| `fb_hootch` | 2644 | Tin-and-screen tropical billet. **No Western Front equivalent under any texture.** This is precisely where `FIREBASE_REWORK_INTENT.md:83-84`'s *"re use the hooches … as building sets"* fails. |
| `fb_gate_gap` | 2606 | Vietnam wire gate. **But its `SOCKET_A` / `SOCKET_B` / `FACE_OUT` marker contract transfers verbatim** — it is exactly what a communication-trench entry needs. Geometry dies, contract lives. |
| `fb_helipad` | 192 | Anachronistic by ~40 years. |
| `fb_claymore` | 36 | Anachronistic by ~45 years. |

### THE SPLIT, stated two ways — and the second is the honest one

| Measure | Unchanged | Reskin | Vietnam-only |
|---|---|---|---|
| **By part count** | 6 / 23 (26 %) | 12 / 23 (52 %) | 5 / 23 (22 %) |
| **By triangles** | 580 | 26,900 | 9,800 |
| **By triangles, cumulative** | — | **27,480 of 37,280 = 74 % of modelled geometry survives** | 26 % discarded |

**74 %, not 15 %.** My earlier figure was wrong and this table replaces it.

**But hold the number honestly: 52 % of the parts survive only through a RESKIN, and the reskin is doing
the heavy lifting.** It is defensible *for this project specifically* — at PSX texel density a reskin is
one texture, not a remodel — and it would not be defensible on a project with normal-mapped hero assets.
Say it that way to him, because the number is real but it is real for a reason that is worth naming.

### 5.2 · WHAT A WW1 BATTLEFIELD NEEDS THAT NO EXISTING PART PROVIDES

| Need | Verdict | Note |
|---|---|---|
| **The trench CUT** — 1.8–2.2 m deep, walkable, below grade | **TERRAIN WORK** | This is the morph tool, not a part. `fb_trench_run` at 0.45 m is not it (Retraction 1). |
| **Shell-hole ground** — cratered no-man's-land | **TERRAIN WORK — ALREADY EXISTS** | `DamageSystem.modify_terrain()` cuts craters today. A WW1 map is that function run thousands of times **at edit time, where its 80–94 ms rebuild is free.** **The single biggest free win in the entire proposal.** |
| **Parados** (rear bank) | **VARIANT — free** | `fb_berm_arc` (72 tris) mirrored and instanced on the other side of the same spline. Zero new art. |
| **Wire pickets, in depth** | **VARIANT** | `fb_wire_belt` reskinned to screw pickets; the 10–30 m depth is parallel rows, i.e. tool behaviour. |
| **Duckboard** (trench floor) | **VARIANT — promote an orphan** | `fb_duckboard` exists in the generator (`gen_firebase_v3.py:875`) but is **not in the 23-part manifest.** Promote and widen it. |
| **Dugout entrance** (stairs down from a trench wall) | **NEW PART — highest risk** | It is the JOIN between the linear system and the discrete parts. `fb_bunker_steps` (12 instances in the monolith) is its ancestor. |
| **Revetment** (corrugated iron / hurdle / A-frame facing) | **NEW PART, but linear and cheap** | ~2 m panel instanced along the spline, ~100–200 tris. |
| **Firestep** | **NEW PART — CALIBRATION-CRITICAL** | Firestep height + parapet crest + player eye height must agree to within centimetres or the whole line is unplayable. **Nothing in the firebase calibrates this and nothing can be inherited.** |
| **Traverse / bay** (the zigzag that stops enfilade) | **NEW PART — and it breaks the spline** | See §5.3. |
| **Sap head / listening post** | **NEW PART** | A T-terminus module. |

**Tally: 5 genuinely new parts · 3 variants of existing parts · 2 terrain jobs, one of which already ships.**

### 5.3 · THE STRUCTURAL QUESTION — and I will answer it plainly, because it is the load-bearing one

## **They are TWO DIFFERENT AUTHORING VERBS. "One tool serves both wars" is weaker than it looks — but not for the reason it first appears.**

| | Verb | Unit of authoring | What UNDO means |
|---|---|---|---|
| **Discrete emplacements** | **STAMP** | an object at a position, with a yaw, seated on the ground | "delete that object" |
| **Continuous linear systems** | **DRAW** | a **path** | "move that control point, and the entire assembly re-derives" |

A DRAW verb must keep an assembly **self-consistent** along its whole length while the path is edited:
cut depth, revetment on both walls, duckboard on the floor, firestep on the enemy side, parados on the
friendly side, traverses at intervals. **A stamping tool cannot express that.** If he hand-stamps 6 m
trench segments, he is doing precisely what the 81-segment perimeter does — data entry — and every path
edit invalidates all of it.

**And it is worse than data entry.** §4 of this analysis measured why a segmented berm is *more* prone to
falling-through than a monolith: **81 independent trimesh shells have 81 seams.** A stamped trench puts
**the player INSIDE that geometry by design**, on the wrong side of every one of those seams. A stamped
trench system is the §4 defect with the player standing in it.

### But here is the finding that rescues the reuse claim — and re-prices the tool

**The firebase ALREADY NEEDS THE DRAW VERB.** §2 of this analysis reaches that conclusion independently
and from Vietnam evidence alone: the perimeter is 81 segments, it is a *function of the terrain*, it must
re-derive when he morphs the hill, and 80 of its 81 segments carry no transform because it was never
authored as a path in the first place.

> **So it is NOT one verb reused twice. It is TWO verbs — and the firebase rework has to build BOTH of
> them anyway. WW1 then uses the same two at a larger scale.**
>
> **STAMP** → emplacements. WW1 has these too: ~12 of the 23 parts are the discrete half.
> **DRAW** → the linear system. The firebase's is a closed ring; WW1's is longer, deeper and open. **Longer, not different in kind.**

**The reuse is REAL. But it is real because the firebase needs a spline verb on its own account — not
because a firebase stamping tool happens to fit a trench system.** That is a materially different
argument from the one in `FIREBASE_REWORK_INTENT.md`, and he should be given the accurate version.

**Two consequences the Arbiter must carry into any costing:**

1. **Cost TWO authoring verbs, not one.** The DRAW verb is the harder one, it is the one that fixes the
   siege breach, and **it is the one that gets cut if the tool runs late.** If only STAMP ships, the
   perimeter stays hand-placed, the ring cannot follow a morphed hill, and the whole headline promise
   ("less a circle, fitting the hill") is not delivered.
2. **DEPTH is a third thing, and neither verb provides it.** A WW1 line is front + support + reserve —
   three parallel paths joined by communication paths. That is a **graph of splines**, and junctions
   (T, cross, corner, sap head) are exactly where a spline instancer stops working. **Genuinely new
   engineering plus 3–4 new junction parts.** The firebase never needs a junction: a ring has none.
   **This is the one part of the WW1 claim that is aspirational, and it should be named as such.**

### 5.4 · APPLYING THE GUARD — does the Vietnam demo get better on the kit's OWN merits?

**Honest answer: PARTLY, and NOT enough to build it now.** Every demo-visible defect the kit would fix
has a cheaper direct fix, and its one unique benefit is unrealisable in a one-base demo.

| Kit benefit for Vietnam | Is it real? | Is there a cheaper direct fix? |
|---|---|---|
| The siege never breached (80/81 segments, no transform) | **Real, and severe** | **YES — give the segments transforms in the re-export.** A re-export is hours; the kit is weeks. The kit makes the bug *impossible*; a re-export makes it *fixed*. |
| 488 markers / 23 staffed | Real | **YES** — prune markers in the source asset, or budget in code (§3's shape works without a kit) |
| Placement defects visible only in Godot (the chow-hall class) | **Real, and this one is genuinely better in-engine** | Partly — the marker-vs-navmesh probe (ADR-041 §5) gets most of it for far less |
| **Bases that differ and fit their hills** | **Real — and ONLY the kit delivers it** | **No cheaper fix.** But **the demo has exactly ONE base.** A one-base demo gets **zero** variety benefit. This argument is worth nothing until firebase #2. |
| "remove people falling thru berms" | **NO — §4 measured that the kit does not fix this** | **YES** — the ground contract (heightfield owns collision, mesh goes `COL_NONE` visual-only) fixes it, with or without a kit |

> ## **GUARD VERDICT: the kit does NOT pay for itself on the Vietnam demo's own merits.**
> Its one irreplaceable benefit — bases that differ and fit their terrain — **cannot be observed in a demo
> that ships one base.** Its most severe fix (the siege breach) is available today for hours of work.
> And its headline promise (no more falling through berms) **it does not actually deliver** — the ground
> contract does.
>
> **That is an argument for POST-DEMO — which is exactly what ADR-041 already ruled, on 2026-09-06, in
> his own words: *"i guess this is post demo work."*** Record this as an **independent confirmation
> arriving from a different door**, not as a new finding. The value of it is that it was reached from
> part-level measurement rather than from scope discipline, and it landed in the same place.

**What I would take to him from this section instead of a build authorisation:**
the kit's two-war case is **stronger than the intent doc argues on ART (74 %, not 15 %)** and
**weaker than it argues on TOOLING (two verbs plus a junction graph, not one tool)**. Both corrections
point the same way: **build the DRAW verb first, for the firebase perimeter, on its own Vietnam merits —
because that is the piece both wars need, the piece that closes the siege-breach bug class by
construction, and the piece that gets cut if it is scheduled second.**

---

## 6 · TRADEOFFS — what a kit sacrifices (Law 2: no free lunches)

1. **The hand-composed silhouette.** 49.4–96.0 m of authored irregularity in the ring (his log, line 38)
   goes away and returns only if per-part jitter is in the tool on day one.

2. **The specific readability HE has — and this is the real cost, not a soft one.**
   He has playtested this base since July. He knows where the TOC sits, where the wire is thin, where the
   gun line is, where the ladder is that he just got stuck on. **A kit throws that away and makes him a
   stranger in his own base.** The session entry gate is *his verified playthrough* (ADR-015). Every demo
   measurement — the 24-minute payoff, the siege shape, the walked path, the white surfaces — is
   calibrated against **this** compound. Rebuilding it resets the reference point that every gate has
   been measured against. That is a **schedule-and-judgment cost**, not an art cost, and it is the single
   best argument for leaving ADR-041's POST-DEMO ruling exactly where it is.

3. **Variety capped at the number of parts somebody felt like making.** ADR-041's own Consequences say
   this, and it binds harder here: **15 part classes means every firebase in the game is a
   re-arrangement of the same 15 things**, and re-arrangement reads as sameness faster than anyone
   expects. That is the *Men of Valor* smell this project is organised against.

4. **The proven bake is thrown away along with its defects.** 1,984 winding flips, 86 re-meshes, 545
   folded props: ugly load-time repairs that are also **the reason the base works today.** A kit re-opens
   every one at part granularity — **78 parts is 78 chances to ship a part that misses a naming prefix
   and goes silently invulnerable.** ADR-042 is the bug class; `us_fb_ammo_crate_stack-colonly_P2` and
   `fb_sbg_seg_046.001` are the standing proofs, both still in the file today.

5. **~78 stamps × the ADR-041 §12 seating bill.** ADR-041 prices *village + temple only* at **20–31 h**,
   and warns the firebase is *"~200 lines of seating machinery behind a 13-line scene"* (§6).
   **Anyone costing this kit must cost the machinery, not the placements.**

6. **Every stamp is a new placement-defect surface.** ADR-041's context line: *every expensive defect
   closed was a placement defect.* The kit converts **one** placement into **~78**.

---

## THE TWO BIGGEST LEVEL-DESIGN RISKS OF THE PIVOT

### **R1 — the base stops being a PLACE and becomes a LAYOUT.**
The current firebase reads as a compound someone built under fire: an irregular ring, a six-gun star, a
TOC dug in behind the guns. A part palette dropped onto a grid of hills produces bases that are
**correct and forgettable** — and Pillar 2 is Atmosphere. **Mitigation, and it is not optional:** the kit
ships with per-part yaw / height / offset jitter and a deliberate "wrongness" budget in version one,
**and he authors the first base BY HAND with the tool before any generator is written.** If a generator
comes first, the jitter never gets built and every firebase in the game is the same fence.

### **R2 — the berm defect survives the rebuild.**
If the berm ships as a stamped mesh part rather than terrain relief, he does the entire rework and
**still falls through berms — with 81 seams where he now has one shell.** The ground contract
(model-as-ground vs terrain-as-ground, `site_planner.gd:1837-1842` and his own 2026-07-29 ruling at
`:1694-1699`) must be **settled before the part list is agreed**, not discovered afterwards. This is the
failure mode that would make him conclude the pivot did not work — **after paying for all of it.**

---

## WHAT I RECOMMEND THE ARBITER TAKE

- **Roads: classify (a), not (b) or (c).** Two measured causes: the clearing stride leaves trees standing
  in the road every 10 m; and the dust colour is within 0.03 of the firebase's own clearing dirt, on the
  one stretch he would look at first. Both are constants. Ship both in the demo. Everything else about
  roads is post-demo or forbidden by Pillar 3. **Do not let "roads need work" become a road-art epic.**
- **Kit granularity: per functional PLACE** — ~15 Tier-1 classes, Tier-2 linear parts on a spline, Tier-3
  dressing sealed inside its part. **~78 hand placements, not 5,810 nodes and not 81 wall bricks.**
- **Perimeter: procedural on a spline, gate authored.** Jitter in v1 or never.
- **Markers ride on parts; the site holds a garrison budget.** That answers ADR-041 open question 3 and
  makes the 488/23 mismatch unrepresentable.
- **Settle the GROUND CONTRACT FIRST.** The berm becomes terrain relief (mesh visual-only) or the pivot
  does not deliver its headline promise.
- **WW1: correct BOTH halves of the intent doc's claim.** The ART case is far **stronger** than it
  argues — **74 % of modelled geometry survives** (6 parts unchanged, 12 by reskin, 5 Vietnam-only, from
  the 23-part manifest). The TOOLING case is **weaker** — it is **two authoring verbs (STAMP + DRAW)
  plus a junction graph**, not one tool. And **the trench module IS genuinely missing after all**:
  `fb_trench_run` measures **0.45 m tall, `enterable: false`, zero markers** — a parapet spoil lip, not
  a trench. **My own earlier "correction on contact" is WITHDRAWN; do not carry it forward.**
- **If anything is built first, build the DRAW verb.** It is the piece both wars need, the piece that
  closes the siege-breach bug class by construction, and the piece that gets cut if scheduled second.
- **ADR-041's POST-DEMO ruling should STAND — and §5.4 confirms it from a second door.** The kit does not
  pay for itself on the Vietnam demo's own merits: every demo-visible defect it fixes has a cheaper
  direct fix, its headline promise (berms) it does not actually deliver, and its one irreplaceable
  benefit — bases that differ and fit their hills — **cannot be observed in a demo that ships one base.**
  Nothing here argues for starting before his playthrough is discharged; tradeoff 2 argues hard against it.
