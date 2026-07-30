# LEVEL DESIGNER / TECHNICAL ARTIST — interior-first against a generated firebase

**Written 2026-07-30.** Every claim carries a `file:line` or names the measurement that produced
it. Blender was NOT opened and Godot was NOT launched. The GLB numbers below come from parsing
`fsb_main_v3.glb`'s glTF JSON off disk with python, today.

---

## 0. FIVE PLACES THE CODE CONTRADICTS THE BRIEFING — the code wins

**0.1 "21 US interior props exist and are UNEXPORTED" — FALSE, twice over.**
- 21 GLBs are on disk at `assets/us/props/interior/*.glb` (dated 2026-07-26 21:20, `.import`
  siblings 21:40, so Godot has imported them).
- **178 interior prop instances are already BAKED INTO the shipped `fsb_main_v3.glb`** —
  measured by node name: `fb_int_fb_cot` ×54, `fb_int_fb_hanging_bulb` ×30,
  `fb_int_fb_ammo_crate_stack` ×25, `fb_int_fb_footlocker` ×22, `fb_int_fb_c_ration_case` ×21,
  `fb_int_fb_water_can` ×5, `jerry_can`/`folding_table` ×3, `field_chair`/`field_range`/
  `mermite`/`litter`/`medical_chest` ×2, and one each of `field_desk`, `field_phone`,
  `radio_shelf`, `plotting_board`, `map_board`.
  Produced by `tools/gen_fb_interior.py::furnish_firebase()` (`:416-488`), which was run
  manually and SAVED into `firebase/kit/firebase_v3.1.blend` — so they re-export forever.

**0.2 `production/firebase_interior_wiring.md:3` says "props built in Blender, NOT exported,
NOT wired"** and `:189` says "**73** interior prop instances baked in". Measured today: **178**.
That doc is stale at its own header and its own §8:253 already contradicts its §0 table. Under
the POINTER LAW it needs correcting on contact.

**0.3 "a firebase CHUNK KIT of 19 marker-GLB chunks" — THOSE FILES DO NOT EXIST.**
- `assets/building models/structures/firebase/chunks/` — **absent** (`ls`: No such file).
- `CHUNK_CONTRACT.md`, `recipe_fsb_battery.json`, `recipe_fsb_small.json` — **absent**
  (repo-wide `find`).
- Zero `.gd` or `.tscn` references to `chunks/`.
- The only survivor is the source blend, `production/props_workshop/firebase_chunks.blend`.

So the 2026-07-29 station decree's *"matches the existing chunk/socket contract"* points at
nothing on disk. **There is no chunk mechanism to reuse.** Whatever we build is new — which is
good news, because it frees us to build the right shape rather than the 7/17 shape (see §2).

**0.4 `site_planner.gd:743-746` asserts the fighting step "does NOT need Blender ... the
model's mound plate is stripped at load."** Both halves are now false, in the same file:
- `_repair_glb_colliders` **KEEPS** the mound collider (`:1124-1130`, "the MODEL is the ground").
- The manifest ships `step_h: 0.0` (`fsb_main_v3_mound.json`), so `_fighting_step` returns
  `0.0` on its second line (`:754-755`). **There is no fighting step anywhere today**, in
  terrain or in the model. Stale prose; NO-DRIFT applies.

**0.5 The shipped GLB PREDATES the 2026-07-29 generator edits.**
`fsb_main_v3.glb` mtime **2026-07-26 22:27**; `fsb_main_v3_mound.json` mtime **2026-07-29
19:21** — the manifest was written without an export. Measured proof in the GLB:
`fb_sbg_seg_000_001-colonly` has **24 verts** (a box) against the visual segment's 1,292.
Handoff §A2 has NOT landed and `_repair_glb_colliders`' re-mesh path is still load-bearing.
Conversely `fb_terrain_mound_208-colonly` **shares mesh index 132** with the visual (27,968
verts), so the ground trimesh IS live — §A1's flip to `COL_NONE` and back to `COL_TRIMESH`
netted out and the ground is correct today.

---

## 1. THE MEASUREMENT THAT DECIDES EVERY OTHER ANSWER

Parsed from `fsb_main_v3.glb` today:

| | count |
|---|---|
| visible mesh nodes | **430** |
| `-colonly` nodes | **365** |
| **visible SURFACES (= draw calls submitted, unculled)** | **826** |
| of which `fb_int_*` interior props | **368 (44.6%)** |
| visible triangles | **318,056** |
| of which `fb_int_*` | **11,936 (3.75%)** |

**The interiors are 45% of the firebase's draw calls for 4% of its triangles.** That is the
call-bound thesis (`production/PERF_LEDGER.md`, and the measured line at `:103` — *"Cutting
99,500 prims (33%) and 77 draw calls moved FPS by ~0"*) stated in one sentence, on this exact
asset. Tri budgets are style, not perf; **prop COUNT is perf, because every prop is nodes and
surfaces.**

Two compounding defects behind that 368:

**(a) Every prop carries 2–3 SURFACES.** `fb_int_fb_cot` = mesh 177, **3 primitives**;
`fb_hanging_bulb` = **2**. Cause: `gen_fb_interior.build()` appends *all ten* kit materials
(`:331-332` → `fb_kit.ensure_materials()`), and a cot genuinely paints canvas + gunmetal +
olive. 54 cots × 3 = **162 draw calls for six identical bunks in eight identical huts.**

**(b) Every prop got a `-colonly` BOX twin.** ~180 of the 365 twins are `fb_int_*`, each 24
verts, each becoming a `StaticBody3D` + shape at load. Two are actively wrong:
`fb_int_fb_hanging_bulb`'s box hull is a **0.08 × 0.08 × 1.72 m invisible post at head height
in the middle of every hootch, ×30** — and the floating-collider audit already names 2 of them
at +4.4 m (`FIREBASE_BLENDER_HANDOFF.md:257`) while calling them "correct". They hang from a
roof; the *mesh* is correct, the *collider* is a bug.

**(c) The firebase has NO visibility range at all.** `_apply_visibility_range()` exists
(`site_planner.gd:210-217`, 230 m) and **`place_firebase_main()` never calls it**
(`:1038-1069` — the whole body; it calls `_repair_glb_colliders`, `_wire_parapet_destructibles`,
`_wire_claymores`, `Ladder.build_from_markers`, `SirenTower.build_from_markers`, and nothing
else). Every cot in every hootch is submitted from anywhere in the AO the camera faces it.

For scale: PERF_LEDGER's own census (`:985`) puts **v1** `fsb_main.glb` at **204 surfaces**. v3
is **826**. A 4× regression in the frame's biggest non-canopy owner, never measured.

---

## 2. THE AUTHORING ORDER FOR ONE BUILDING, INTERIOR-FIRST

His ruling is cheap to honour here for a reason nobody has said out loud: **the firebase is not
a sculpt, it is a python program.** `gen_firebase_v3.py` + `gen_firebase.py` + `gen_fb_interior.py`
generate every shell, every placement and every interior. So "build the insides first, then the
walls around it" is not a workflow inversion — it is **writing the layout dict before writing
the `fam_` function**, and both are code I can run headless.

### The order, for one room, start to finish

**Step 1 — THE ROOM IS THE UNIT. Author the interior layout first, in metres, with nothing
around it.** A new row in `INTERIOR_LAYOUT` (`gen_fb_interior.py:343-406`). The doc comment
there is already the right doctrine and should be quoted at the council: *"Randomly scattering
class picks into a circle at the room's centre is what produced a mess hall of crate stacks
with no table... A room is a layout, not a bag of props."* Interior-first is that sentence
applied to the whole building.

**Step 2 — the layout's bounding box becomes the shell's brief.** Not the reverse. Today it is
the reverse and it shows: `fam_hootch` is 4.4 × 7.2 m (`gen_firebase.py:581`) and the interior
was fitted into it afterwards at ±1.35 m (`gen_fb_interior.py:345-353`) — which is why a hootch
holds six cots and nothing else. Measure the finished room, add revetment thickness, and write
`fam_*` to that number.

**Step 3 — the room gets its OWN markers, authored beside the props.** `work_` and `prop_`
markers become fields on the layout row, not a separate random pass. **This kills a live
defect:** `npc_points()` stamps `STATION_PLAN` posts at `rng.uniform(r0, r1)` on a random
bearing around the building centre (`gen_firebase_v3.py:701-710`). For `fb_toc`, `plot` is
r 2.4–3.2 m about a 7.4 × 5.6 m building — **the officer's map post can land inside a sandbag
wall or outside the building.** Authored markers fix it; and the affected families
(`fb_toc`, `fb_aid_station`, `fb_hootch`, `fb_mess`, `fb_gp_tent`) then come OUT of
`STATION_PLAN` so nothing double-stamps (ADR-023).

**Step 4 — export the room as ONE chunk GLB.** `assets/us/rooms/fb_room_<name>.glb`, origin at
the interior floor centre, +Y up, containing: the merged single-material prop geometry, the
`work_`/`prop_` markers, and ONE hand-authored `-colonly` collision proxy (a slab under the cot
row, a slab under the desk) — not 11 per-prop boxes. Handoff §0's proxy paragraph is the
sanctioned pattern.

**Step 5 — the generator emits one anchor marker per building and NOTHING ELSE about the
interior.** `marker("room_hootch", (0,0,0), 0.0)` inside `fam_hootch`. `_empty()`
(`gen_firebase_v3.py:639-649`) already re-emits family markers into world space, so this is one
line per family.

**Step 6 — retire the bake, in the same change.** Delete every `fb_int_*` object and every
`prop_*` empty from `firebase_v3.1.blend`. `furnish_firebase()` already has the deletion loop
(`gen_fb_interior.py:426-428`); the retirement is that loop plus a save, headless. **If both
paths live, every prop doubles** — `firebase_interior_wiring.md:157,255` says so twice and it
is the whole reason `_furnish_interior` is deliberately not called for the firebase.

**Step 7 — assemble in a Godot room scene, `scenes/world/rooms/room_<name>.tscn`.** One
`MultiMeshInstance3D` per prop mesh type (§4), the collision proxy, `visibility_range_end`, and
the `Destructible` node if the room can be blown.

**Step 8 — anchor it at runtime off the marker.** `RoomKit.build_from_markers(root)`, a
line-for-line copy of the pattern already shipping twice in the same function:
`Ladder.build_from_markers(root)` (`site_planner.gd:1050`) and
`SirenTower.build_from_markers(root)` (`:1053`), both called AFTER `root.global_position` is
set. This is the load-bearing choice and it is the answer to both halves of the council's
question:
- **an interior can never be destroyed by a re-export**, because it is not in the GLB; and
- **an interior can never be orphaned by a re-export either** — the usual failure of
  hand-placing in the .tscn is that the generator moves the hootch and the furniture stays
  behind. Reading the marker every boot means the room *follows its host*, which a hardcoded
  transform in `firebase_main.tscn` would not.
- **and it can never be duplicated**, because the bake is deleted and there is exactly one
  owner per prop.

### Ownership table — say this once and enforce it

| artefact | OWNS | must never contain |
|---|---|---|
| `tools/gen_firebase_v3.py` / `gen_firebase.py` | the GROUND (`fb_terrain_mound` trimesh + its mud vertex-colour mask), berm, parapet + embrasures, the SHELLS (`fam_*`), placement, the `room_*` anchor + `door_main` + perimeter `work_*` markers, the mound manifest, the `-colonly` twins | any interior prop; any interior marker |
| `tools/gen_fb_interior.py` | interior prop MESHES + the per-room LAYOUT + the room's own markers; exports one room GLB per room type | `furnish_firebase()` — **RETIRED** |
| `assets/us/rooms/fb_room_*.glb` | one finished interior's geometry + markers + one collision proxy | shell geometry; the ground |
| `scenes/world/rooms/room_*.tscn` | assembly: MultiMeshes, proxy body, visibility range, Destructible | positional data — it is placed by marker |
| `scripts/world/room_kit.gd` (new, copies `ladder.gd`) | marker → room instancing at build time | layout knowledge |
| `scenes/world/firebase_main.tscn` | true one-offs (the 2 `spawn_bunk_*` markers it already holds) and **material overrides on GLB nodes** (the mud shader, §5) | anything a generated marker could anchor |

**The single rule that makes it safe:** *nothing hand-authored is ever positioned by a literal
transform inside the compound; it is positioned by a marker the generator emits.* The .tscn's
job is to hold **what** and **how it looks**; the GLB's job is to hold **where**.

---

## 3. IS A "ROOM" A CHUNK? — yes, but a chunk is a `.tscn`, not a marker-GLB

**Verdict: each interior is its own marker-anchored chunk. The chunk is a Godot scene wrapping
one room GLB, not the 2026-07-17 marker-only GLB.**

Against the 19-chunk kit: **it does not exist on disk** (§0.3). There is nothing to be
consistent with, no spawner was ever built ("Game-side spawner (reads sockets/recipes) not
built yet"), and its own design — *zero meshes, INST_/SOCKET_A/SOCKET_B empties, chain the next
socket onto the previous* — solves **perimeter tiling**, a problem `parapet_segments()` +
`resample_closed()` now solve procedurally and better. Reviving a socket-chain contract to
place a medical tent's furniture would be building the 15th parallel world-build system
(`recongame-divergent-systems-blindspot`).

Against the station decree: the decree's substance is **"stations attach at markers on
`fsb_main_v3`, not modelled into the firebase mesh, so he can place 2 or 6 pits with no new
art."** A marker-anchored `.tscn` honours every word of that. Only the file format changes, and
it changes because a GLB *cannot hold* the four things a station needs:

1. a `MultiMeshInstance3D` (the only draw-call answer, §4),
2. a `visibility_range_end`,
3. the `Destructible` / `MortarPit` / `MGEmplacement` node with its `claim`/`release`,
4. a `ShaderMaterial` override.

A gun pit chunk and a barracks chunk are then the *same construct* — geometry GLB + assembly
.tscn + `room_*`/`station_*` marker — which is exactly what the decree wanted and what stops
"stations" and "interiors" becoming two systems.

**One nuance, and it is his call.** Eight `fb_hootch_i` instances sharing one
`room_hootch.tscn` means eight identical interiors. Vary them by seeding a per-instance layout
variant off the marker's own world position (ADR-010: same seed, same base — never `Time`).
Inside a MultiMesh, variety in *transforms* is free; only variety in *meshes* costs a call.

---

## 4. DRAW CALLS — how to add a lot of clutter without adding a lot of calls

Three techniques, in order of ratio. **All three already exist in this codebase.** Numbers are
measured, not estimated.

### 4.1 ONE MATERIAL PER PROP MESH — 368 → ~178 calls, no visual change
A cot is 3 surfaces because `build()` appends all ten kit slots and paints three of them. Author
the interior kit against **one palette-strip texture** (already the standing law:
`art-storage-bloat-law` — palette strips over photo maps; and the kit's 160 px/m,
`fb_kit.py:25`). One material per mesh = one primitive = one call.

**State the engine truth precisely, because the ledger already corrected a council on it**
(`PERF_LEDGER.md`, the atlas section): *"a shared material collapses NOTHING — Godot never
batches 3D draws across `GeometryInstance3D`."* Sharing a material **between nodes** buys
nothing. Reducing surfaces **within one mesh** buys a call each, because a surface *is* a draw
call. Those are different claims; only the second one is what §4.1 does.

### 4.2 MULTIMESH PER PROP TYPE PER ROOM — ~178 → ~11 calls, and count becomes FREE
This is the whole answer to "8–12 stretchers, way more of everything."

The pattern is in-repo twice and needs no invention:
- `ground_clutter.gd:211-228` `_add_bucket()` — one `MultiMesh`, `TRANSFORM_3D`, shared mesh,
  `instance_count`, per-instance transforms, `cast_shadow = OFF`, `visibility_range_end`. This
  is the template to copy verbatim.
- `destructible.gd:14-16, 88-122` — the **static shared** variant: `static var _rubble_mm`, one
  `MultiMeshInstance3D` for **every** destructible in the world, grown by appending to an
  authoritative transform array and rebuilding (`:99-101`), with the comment recording why:
  *"grow-in-place on a MultiMesh is unreliable; a rebuild is not."*

Applied: 54 cots → **1 call**. 30 bulbs → **1 call**. 25 crate stacks → **1**. The compound's
entire interior population, all 178 props of 18 types → **~18 calls, and ~11 in practice** once
each room only draws its own. **Twelve stretchers then cost exactly what two cost: one call.**
Clutter *count* stops being a budget; only clutter *variety* is a budget.

### 4.3 VISIBILITY RANGE — the free half, currently not applied at all
`_apply_visibility_range` exists and `place_firebase_main` never calls it (§1c). An interior is
invisible from outside its building, so put `visibility_range_end ≈ 35–40 m` +
`fade_mode = FADE_SELF` on each room's MultiMeshes (`ground_clutter.gd:224-226` does exactly
this at 42 m). Standing at the gate, every interior in the compound costs **zero**. Standing in
the aid station, you pay ~6 calls.

### 4.4 And delete ~180 collider nodes
Replace the per-prop `-colonly` boxes with one authored proxy per room. Add `fb_int_`/`fb_room_`
to `COL_NONE` (`gen_firebase_v3.py:821-823`) for anything walk-through, and fix the hanging bulb
(a light fixture must never own a collider — 30 invisible head-height posts).

**Net for the interiors: 368 calls → 1–11 depending on which room you stand in, with MORE props
than today.** That is the budget headroom for everything he asked for.

### 4.5 THE BODY-BAG STACK — one MultiMesh, one call, any count
`fb_body_bag` is never picked up, never opened, never animated. It has no reason to be a node.
**One static shared `MultiMeshInstance3D` for every bag at the firebase = 1 draw call for 0 to
40 bags**, using `Destructible._rubble_mm`'s exact static pattern: keep the authoritative
`Array[Transform3D]`, append on a new KIA, rebuild `instance_count` (never grow in place). A new
casualty costs **zero** new draw calls. Built as N prop nodes instead it would cost N — or 2–3N
on the current multi-material pattern.

### 4.6 THE MEDICAL TENT — the number he needs before he asks for 12 occupied beds
| element | technique | calls |
|---|---|---|
| 8–12 empty `fb_litter` (inside) + overflow (outside) | one MultiMesh | **1** |
| `fb_medical_chest`, `fb_water_can`, crates, IV stand, bulbs | one MultiMesh per type | **~5** |
| body-bag stack, any count | one shared MultiMesh | **1** |
| **`fb_casualty_shrouded`** — a blanket/poncho-covered casualty as ONE static mesh, any count | one MultiMesh | **1** |
| a casualty a medic is actively working on — skinned, animated | real node, unavoidable | **40–80 EACH** |

That last row is the whole design constraint and it is measured, not guessed:
`PERF_LEDGER.md:989` puts a US grunt at **36 nodes/44 calls vs 51–61 MeshInstance3D/71–81
surfaces (COUNT DISPUTED)**. **MultiMesh cannot do skinning** — a rigged body can never be an
instance. So **ten animated men lying on stretchers is 400–800 draw calls: more than the entire
current firebase (826) and roughly double the whole non-canopy frame (411–464,
`PERF_LEDGER.md:902`).** Ten occupied beds as characters is not a tradeoff, it is a hard no.

**The ruling that gets him the living-world read anyway:** occupancy is carried by
`fb_casualty_shrouded` in the MultiMesh, and **rotating occupancy is a change of instance
transforms — which costs zero draw calls to change, at any frequency.** Cap the *animated*
casualties at **3–4** (the ones a medic is attending, where the motion is the point). The rest
read as shrouded forms — which is also more period-true and more decent than twelve idle
breathing men.

### 4.7 Marker + naming contract for all of it
`fb_` lowercase for meshes; `prop_<class>` and `work_<type>` for markers.

New meshes: `fb_body_bag`, `fb_casualty_shrouded`, `fb_mosquito_net`, `fb_web_gear_hook`,
`fb_helmet_kit`, `fb_ruck_stack`, `fb_powder_canister`, `fb_duckboard_panel`, `fb_psp_panel`,
`fb_map_table`, `fb_status_board`, `fb_switchboard`, `fb_wire_reel`, `fb_lantern`,
`fb_clothesline`, `fb_iv_stand`.

New `PROP_CLASSES` keys (`gen_fb_interior.py:294-308`): `casualty`, `bedding`, `gear`, `floor`,
`comms`.

**TRAP — name the class, do not rely on the property.** `site_planner.gd:527` reads
`prop_class` via `get_meta`, and the kit exports with **Custom Properties OFF**
(`export_extras=False`, `gen_firebase_v3.py:925`). So `prop_class` **never survives export** —
`firebase_interior_wiring.md:79-100` documents this and the fix was never made. The class must
be IN the marker name (`prop_casualty`, `prop_gear`), the way `work_type` already survives via
the name fallback (`site_planner.gd:562-563`).

**TRAP — a new `work_` type silently becomes an off-duty man.** `FSB_WORK_OCCUPATION`
(`site_planner.gd:821-826`) maps exactly nine types and `:922` turns anything else into
`off_duty`. `work_kia`, `work_triage`, `work_litter` will each produce a man with no job unless
that dictionary is extended in the same change. Also note the suffix-stripper (`:883-887`) only
strips a trailing `_<int>`, so `work_litter_formup` survives as work_type `litter_formup` —
unmapped. **Name the bearer post `work_litter` and place it OUTSIDE the tent; the
"form up outside" rule is then geometry, not a new work type.**

Anchors: `room_hootch`, `room_toc`, `room_aid`, `stack_kia` (the collection point),
`station_gun`, `station_mortar`.

### 4.8 The body-bag stacking rule
A human remains pouch is ~**2.20 × 0.90 × 0.35 m** lying flat, dark olive/black rubberised,
full-length zip, six web carry handles. At a firebase the dead went out on the same resupply
Huey; they were **laid out in rows on PSP or a pallet near the pad, not piled** — they are
carried by handles by two men, and a tall pile is neither practical nor how it was done.

Rule: long axis parallel, **1.05 m pitch** across the row, **4 per row**; a second row begins
only when the first is full; **maximum 2 layers**, the upper layer inset 0.15 m so the stack
reads as stacked and not as one block. So 8 bags = a full row of 4 with 4 on top — which reads
from across the compound as a *collection point*, not as a prop. Site it at `stack_kia` between
the aid station and the pad edge, on a `fb_psp_panel`, which is both the honest thing and the
thing that tells the player at a glance how the patrol went.

---

## 5. BETTER MUD — what it concretely is

### How the ground is authored today, measured
- **One mesh, one material.** `fb_terrain_mound` is a 46-ring × 152-segment grid
  (`gen_firebase_v3.py:212`) = **27,968 verts, 1 primitive**, entirely `fb_earth`
  (`:232`, `idx = gf.MAT_INDEX["fb_earth"]`).
- **`fb_earth`** = `baseColorTexture` index 0, `metallicFactor 0`, `roughnessFactor 0.96`,
  `doubleSided: true` — read out of the glTF material block today. The texture is
  `fb_earth.png`, box-projected on a **1.6 m tile** at **160 px/m** (`fb_kit.py:25,171-179`).
  So the whole ~150 m compound is one 256 px tile repeated ~94 times per axis, at a constant
  roughness. **That is the "mud isn't good enough" defect: it is uniform and it tiles.**
- **The mud is separate flat decals.** `mud_blob()` (`:405-440`) builds 24 hub-and-rim fans at
  `platform_z + 0.02`, material `fb_mud` (roughness **0.55** — so a wet/dry distinction already
  exists), on `COL_NONE` (`:821`). Measured: **24 surfaces = 24 draw calls**, with hard
  30-segment polygon silhouettes and a 2 cm float over an undulating trimesh (z-fight risk).
- **Vertex colour is already in the pipeline.** The GLB carries `COLOR_0` **and** `COLOR_1`
  attributes — measured in the attribute set. So the channel is free; nothing new to plumb.
- **15 of 34 materials are `alphaMode: BLEND` and 34/34 are `doubleSided: true`** — the exact
  overdraw sin PERF_LEDGER flags as an ADR-026 violation. Do not add another blended layer.

### What "better mud" means, concretely — four changes, in order of payoff

**5.1 Bake a wetness/darkness MASK into the mound's vertex colour. Zero draw calls, zero
textures, and it kills the tiling.** 27,968 verts is a free canvas. Write per-vertex value from
data the generator already holds: proximity to `CRATERS` (`:169-194` — thrown earth is darker
and rawer), distance to the `mud_blob` centres and the `ribbon()` road/duckboard paths (traffic
churn), and local concavity of `platform_z` (water collects in the dishes — the second
difference is two extra `platform_z` calls per vertex). Then a Godot shader multiplies albedo
and *lowers roughness* where wet. This is the single biggest look change available and it costs
**nothing** in the frame.

**5.2 Delete `fb_mud_patch` as a system and fold it into 5.1 (ADR-023).** The 24 decals are 24
calls, hard-edged, and 2 cm off a curved surface. Their entire job — "mud collects where traffic
collects" — is what the vertex mask does, with soft edges, no z-fighting, no extra pass, and no
alpha. Keep the `ribbon()` roads (they carry the rut texture and a real width contract);
retire the blobs. If a blob must survive, at minimum merge all 24 into **one** object (a merged
object may then never take a box hull — handoff §3's lesson) and write rim alpha 0 so the edge
is a fade, not a polygon.

**5.3 The mud SHADER lives in `firebase_main.tscn`, not in the GLB.** An inherited scene stores
property overrides **by node path**, so a `ShaderMaterial` override on the `fb_terrain_mound`
MeshInstance3D survives every re-export as long as the node name holds — which the generator
guarantees, it is a hardcoded string (`:241`). This is the clean division: **the generator owns
the mask (data), the scene owns the look (shader).** Neither can destroy the other, and he can
tune wetness live in the editor without a Blender round trip. Wire it as a
`MeshInstance3D.material_override`, and put the same shader on the `fb_road_*` ribbons.

**5.4 Then, and only then, wetness response.** Roughness driven by the vertex mask gives
standing water a specular sheen against the 0.96 dry earth — that contrast is what reads as
"mud" rather than "brown". A rain-driven *dynamic* wetness is a second system and is NOT this;
the mask is baked at export and cannot respond to runtime rain, craters or traffic.

**What this does not fix:** a 256 px texture at 160 px/m is 1.6 m of coverage — up close it is
still a small tile, and no vertex mask hides that at the player's feet. If he wants better mud
*underfoot*, that is a bigger source texture (a second, higher-res `fb_earth` variant blended by
the same mask), and it costs VRAM on a project already carrying 413/838 LOSSLESS imports
(`PERF_LEDGER.md`).

---

## 6. BARRACKS PERIOD ACCURACY — a 1968 enlisted hootch

### What the shell is today
`fam_hootch` (`gen_firebase.py:579-598`): 4.4 × 7.2 m, sandbag revetment to **1.25 m**, four
timber posts a side at **2.35 m**, corrugated roof, **OPEN ENDS**, one `fb_earth` pad. It emits
exactly **two** markers: `door_main` and one `prop_sleep`. The interior is
`INTERIOR_LAYOUT["fb_hootch"]` (`gen_fb_interior.py:345-353`): 6 cots, 2 footlockers, 1 C-rat
case, 2 bulbs. **Eleven props for a six-man hut.** The shell is right; the room is empty.

### What one actually contained
Structure: timber frame, **corrugated galvanised iron** roof, sandbag revetment waist-to-chest,
**PSP / Marston mat (pierced-steel planking)** for floors and roof decking, sandbags laid over
the roof against mortar fragments on hardened huts, open eaves for airflow with **roll-down
canvas or plastic sheeting** against the monsoon, **duckboard over the mud**, and a sump.

Contents, per man: **M1953 aluminium-frame folding canvas cot**; a **mosquito bar net** hung
from the roof purlins by tie tapes — the defining silhouette of the space and the single most
conspicuous absence; an **air mattress** ("rubber lady") and a **poncho liner**, no sheets; a
footlocker if lucky, more often **wooden ammunition or C-ration crates** as locker, shelf, chair
and table; personal gear on nails — **steel pot with cover, M1956 web gear / pistol belt with
canteens, M1952 flak jacket draped on the cot end, rucksack**; the **M16 leaned on the frame or
in a rack**; bandoleers and claymore bags.

The character of the room: **empty 105 mm fibre powder canisters** as trash cans and lockers
(utterly characteristic and a 6-sided cylinder to build); a **Coleman lantern** or a bare bulb
on a generator-fed drop cord; a **reel-to-reel or transistor radio**; **pin-ups and photographs
pinned to the frame**; beer and soda cans; cardboard C-rat cases; a fan; a **clothesline** with
towels and fatigues. The research doc's own §6 (`firebase_research_1967_70.md:88-90`) already
binds the wear: sandbags rotted within months, so *"a meaningful fraction should read mildewed,
torn, or sprouting weeds."*

### Covered by the 21 existing props
`fb_cot` (and its rolled liner, `gen_fb_interior.py:148`) · `fb_footlocker` ·
`fb_ammo_crate_stack` · `fb_c_ration_case` · `fb_hanging_bulb` · `fb_jerry_can` ·
`fb_water_can`. The **materials** are already there too — `fb_psp` and `fb_corrugated` are kit
slots 3 and 5 (`fb_kit.py:29-30`) and `PSPHelipad` exists in the GLB, so PSP needs no new
texture work, only a panel mesh.

### Missing, ranked by what the eye reads first
1. **`fb_mosquito_net`** — the net over the cot. Nothing else changes a hootch this much. A
   4-sided taper + a ridge tape; alpha-scissor, never BLEND (ADR-026:30 and the ledger's
   overdraw finding).
2. **`fb_psp_panel` / `fb_duckboard_panel`** — the floor. Today the hootch floor is bare
   `fb_earth`, i.e. the mound. A plank/PSP deck is the difference between a hut and a shed.
3. **`fb_web_gear_hook` / `fb_helmet_kit` / `fb_ruck_stack`** — hanging gear at eye level. This
   is what says *men live here* rather than *beds are stored here*.
4. **`fb_powder_canister`** — the 105 mm fibre tube. Cheapest period signal in the set.
5. **`fb_clothesline`** — motion and colour across the interior; also a sway-shader candidate.
6. **`fb_lantern`** — warm point light, better atmosphere than the bare bulb.
7. **`fb_pinup_card`** — a wall decal card, near-zero cost.
8. **Shell-side, generator, no new props:** roll-down side sheeting on the open ends; a sandbag
   layer over part of the roof; and *one hootch in three* built up rather than all eight
   identical.

Sixteen props per hootch instead of eleven, and — because of §4.2 — **eight hootches of sixteen
prop types cost ~16 draw calls total, against today's ~250 for eleven.**

---

## 7. THE HQ / TOC INTERIOR — officers study MAPS (confirmed)

### What is there today
`fam_toc` (`gen_firebase.py:601-625`): 7.4 × 5.6 m, dug in 1.15 m, PSP floor
(**already**, `:605`), sandbag walls, timber entry steps, overhead cover, an antenna farm of
three 3.4 m masts, and a bench-and-crate suggestion of furniture built into the shell. It emits
`door_main`, one `work_radio`, and `prop_map` — which is tagged
`prop_class="furniture"` (`:623-624`), i.e. **mis-classed**; it should be `plot`.
`INTERIOR_LAYOUT["fb_toc"]` (`gen_fb_interior.py:363-372`) is 9 props: field desk, 2 chairs,
field phone, radio shelf, plotting board, map board, 2 bulbs. Measured in the GLB: `work_radio`
×4, `work_plot` ×2.

### Covered by the 21
`fb_field_desk` · `fb_field_chair` · `fb_field_phone` (TA-312) · `fb_radio_shelf` (a bank of
sets on a plank shelf — the comment at `:96` is right, that IS what an FDC looked like) ·
`fb_radio_prc25` · `fb_plotting_board` (the tilted firing chart) · `fb_map_board` (plywood +
acetate, leaned) · `fb_hanging_bulb` · `fb_ammo_crate_stack` (codebook shelf / stool) ·
`fb_folding_table`.

### Missing — and #1 is exactly what his ruling requires
1. **`fb_map_table` — THERE IS NOTHING HORIZONTAL TO LEAN OVER.** `fb_plotting_board` is a
   22°-tilted stand and `fb_map_board` is leaned against a wall. Officers "studying maps" need a
   waist-high plywood-on-sawhorses table with the 1:50,000 sheets under acetate, grease pencils
   and a range-deflection protractor on it, **and men standing on three sides**. `fb_folding_table`
   is a mess table with a bare top — the map is the point, so the map must be modelled on it.
   Without this prop the HQ ruling cannot be built.
2. **A SECOND `fb_plotting_board`.** A real FDC ran a chart *and* a check chart. Layout-only,
   zero new art — add the row.
3. **`fb_status_board`** — the wall-mounted acetate status/duty board with call signs in grease
   pencil. This single prop is what makes a room read as a *command post* rather than an office.
4. **`fb_switchboard`** (SB-22/PT, canvas-cased, twelve jack pairs) **+ `fb_wire_reel`** (DR-8
   reel with WD-1 field wire running out the door and off toward the bunker line). Cheap boxes,
   enormously period, and the wire run visually ties the TOC to the perimeter.
5. **`fb_lantern`**, and a `fb_mermite`/canteen cup on the map table (mermite exists).

### The work markers are the real HQ defect
`fam_toc` authors ONE `work_radio`; the other posts come from `STATION_PLAN["fb_toc"]` =
`radio ×3, plot ×2` stamped at a **random bearing and radius 2.4–4.6 m about the building
centre** (`gen_firebase_v3.py:623, 701-710`). For a 7.4 × 5.6 m dug-in building that can put an
officer's map post **inside a sandbag wall or outside the building entirely, at the wrong
height** (`p.z = ground_z(...)`, the *outdoor* surface, while the TOC floor is 1.15 m below it).
Interior-first fixes it by construction: the `work_plot` markers are authored **at the map
table's three standing sides**, at the room's floor Z, in the layout row — and `fb_toc` leaves
`STATION_PLAN`.

The "1–2 NPCs in and out every few minutes" needs no art: `door_main` exists (26 in the GLB) and
`_bt_work` was only fixed to actually walk to a post on 2026-07-30 (briefing). Traffic is
schedule + markers.

---

## 8. SEQUENCE — his Blender time vs mine

**The finding that should shape the plan: almost none of this is his Blender time.** The
firebase is generated by three python files. Shells, placements, interiors, markers, textures,
collision and the export are all code, run `blender -b` (handoff §4: *"Export headless.
`blender -b` only."*). He is live on the FP weapons, which genuinely are hand work. **The
firebase should not take him out of that.**

| item | whose hands | how |
|---|---|---|
| new interior props (all 16) | **mine** | `gen_fb_interior.py` box/cyl functions, headless |
| room layouts, authored markers | **mine** | `INTERIOR_LAYOUT` rows |
| one-material consolidation | **mine** | palette strip + `build()` |
| retiring the `fb_int_` bake from `v3.1.blend` | **mine** | existing delete loop + save, headless |
| mound vertex-colour mud mask | **mine** | `terrain_mound()` |
| merging/retiring `fb_mud_patch` | **mine** | generator |
| room GLB export + collision proxies | **mine** | headless |
| `room_kit.gd`, MultiMeshes, visibility range, mud shader | **mine** | code |
| fire slits, berm crest cap, fighting step | **mine if parametric** (they are: `parapet_segments`, `berm`) | generator |
| **judging the look** | **HIS, and only his** | rule #1 is his eyes |
| moving a placement he doesn't like | **his**, in `v3.1.blend` — and `refresh_family_meshes()` (`:739-762`) + `npc_points()` exist precisely so my edits don't throw his placements away | |
| a genuinely sculpted thing (a draped net he wants hand-posed, an organic mud wallow) | **his** | only if the procedural version fails his eye |

**One warning about his file.** `gen_firebase_v3.main()` opens with
`bpy.ops.wm.read_homefile(use_empty=True)` (`:944`) and saves to `firebase_v3.blend` — **not**
`v3.1`. `export_firebase()` saves to `v3.1` (`:915`). So `v3.1.blend` is the hand-tuned file and
`main()` must never be pointed at it. Also: **`npc_points()` deletes EVERY `EMPTY` in the scene**
(`:662-663`) before re-stamping. Any marker he places by hand in Blender is destroyed by the
next NPC pass. That is a second, independent reason hand-authored markers belong in Godot, not
in the .blend.

### The smallest first slice that visibly pays off: ONE HOOTCH, END TO END

Not the medical tent — the medical tent needs the casualty ledger, the shrouded-casualty mesh,
bearer choreography and a body-bag stack, and it is where the plan is most likely to stall. The
hootch is the **pattern**, it appears **eight times**, and it is where the draw-call proof lands.

1. Author `INTERIOR_LAYOUT["fb_hootch"]` properly — net, gear hooks, helmet + flak, powder
   canister, PSP/duckboard floor, clothesline, lantern, pin-ups (~16 props).
2. Collapse every interior prop to one material.
3. Export `fb_room_hootch.glb` with authored `work_rest`/`work_smoke`/`prop_*` markers and ONE
   collision proxy.
4. Delete every `fb_int_*` and `prop_*` empty from `firebase_v3.1.blend`; drop `fb_hootch` from
   `STATION_PLAN`; add `marker("room_hootch", ...)` to `fam_hootch`.
5. `room_hootch.tscn`: one MultiMesh per prop type, `visibility_range_end = 38`, the proxy body.
6. `RoomKit.build_from_markers(root)` in `place_firebase_main`, next to the Ladder and Siren
   calls that already do this.

**Measurable outcome, from today's numbers:** the eight hootches go from **~250 draw calls and
~130 collider nodes** to **~16 calls and 8 colliders**, while holding **half again as many
props** — and one hut he can stand in and judge. If his eye passes it, the same six steps run
for the TOC, the aid station, the mess, the supply tent and the bunkers, and the pattern never
needs re-arguing.

Do it in ONE session. Step 4 empties the base, and a firebase with the bake deleted and no room
scenes yet is worse than today.

---

## 9. WHAT EACH RULING SACRIFICES

**Interior-first as the build order.** You give up "ship the silhouette now, dress it later" —
until a room is finished the building is an empty shed, and there is no partial credit. Because
the shell is written to the interior's box, a late interior change can force a shell rewrite and
therefore a re-export, a `FSB_HALF` re-measure and a `diag_fsb_seat` re-run
(`FIREBASE_BLENDER_HANDOFF.md:293-294`). The order also assumes the interior's *purpose* is
settled before the geometry — which for the medical tent it currently is not (occupancy source
is still open).

**Room as a marker-anchored `.tscn`.** He loses the ability to see the assembled interior in
Blender's viewport — Godot owns the assembly, so his eye-check moves to Godot. Two files now
describe one room instead of one. And the room's floor height depends on the shell's floor
being where the marker says it is; a shell change that moves the floor silently floats or
buries the furniture, so the room GLB must be re-anchored on any shell edit.

**MultiMesh.** This is the real price. **A MultiMesh instance is not a node**: no collider, no
signal, no animation, no picking up, no destroying, no `claim`/`release`. Anything interactive
must be a real node *outside* the MultiMesh, and the split must be decided per prop up front —
which means "8–12 stretchers" becomes "1 MultiMesh + N interactive nodes" and N is a budget he
has to spend deliberately. Rebuilding a MultiMesh to change one instance rebuilds all of them
(`destructible.gd:99-101`), so very high-frequency churn is not free even though count is.

**One material per prop.** Per-part material tuning is gone: a canvas cot and its steel frame
share one palette strip, so the metal will not read as metal. Diffuse only, no PBR — already
the kit's law (`gen_fb_interior.py:9`), but it means shiny things cannot be shiny.

**Retiring the `fb_int_` bake.** There is a window in which the firebase has *fewer* interiors
than today. And the 178 baked props are the only interiors that have ever actually shipped —
deleting them bets the look on code that has not been seen yet.

**Shrouded casualties instead of animated ones.** Twelve breathing wounded men is the thing he
is imagining and it is the thing the frame cannot pay for. He gets the *count* and loses the
*motion* on all but 3–4. Some of the diorama feeling comes back.

**Vertex-colour mud.** Baked at export: it cannot respond to rain, to new craters, or to where
the player has actually walked. Dynamic wetness is a separate system and is not this.

**Deleting `fb_mud_patch`.** Loses the ability to place a puddle anywhere the mound's own
harmonics don't put one, including outside the compound.

**Marker-anchored rooms.** Eight hootches share one interior, so they read as generated unless
per-instance variation is added; and every new `work_` type is a silent `off_duty` man until
`FSB_WORK_OCCUPATION` is extended (`site_planner.gd:821-826, :922`).

**Visibility range on interiors.** A short range will pop. `FADE_SELF` softens it, but a hootch
interior fading in as he walks up is a thing he will see, and 38 m is a number to tune by eye,
not by argument.
