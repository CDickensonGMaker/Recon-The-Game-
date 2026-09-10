# THE KIT PART CONTRACT — what a part must carry to be placeable (ADR-043)

**2026-09-09.** Written engine-free while the machine is reserved for a perf baseline. Every
`file:line` below was read from source this session; nothing here was run.

This is the brief for **P3: a better bunker, a better HQ without floating lightbulbs, and a better
gate house.** Build the tool far enough to produce those three and no further — they are the
acceptance test for the kit, not a content list.

**Read `recon-destructible-export` (the skill) before any export.** This document does not replace
it; it states what the *kit* adds on top of it, and the three pieces' specific gaps.

---

## 0 · THE FINDING THAT SHOULD CHANGE THE ORDER OF WORK

> ## TWO OF HIS THREE PROOF PIECES WOULD SHIP **BULLETPROOF AND INDESTRUCTIBLE** TODAY.

Both destructible vocabularies are hard-coded arrays in `site_planner.gd`, and **neither contains
the TOC or the gate**:

- `FSB_SOFT_PREFIXES` (`site_planner.gd:2013-2021`) — `fb_hootch`, `fb_gp_tent`, `fb_mess`,
  `fb_hwall`, `fb_latrine`, `fb_supply_dump`, `fb_water_point`, `fb_burn_barrel`, `bwire_card`
  (+ the merged chow-hall/aid-station names). **grep for `fb_toc`: 0 hits. For `gate`: 0 hits.**
- `FSB_STRUCTURE_KINDS` (`site_planner.gd:2512-2524`) — `fb_bunker_fighting_i`, `fb_bunker_mg_i`,
  `fb_sleeping_bunker_i`, `fb_tower_i`, `fb_sandbag_stack_i`, `nha_tranh_`, `nha_san_`,
  `nha_ruong_`. **Again: no TOC, no gate.**

Both defaults fail **silently and in the dangerous direction** — unrecognised ballistics means
`hard_surface`, unrecognised destruction means nothing is wired at all, and no error is raised
either way.

| piece | ballistics today | destruction today | what it needs |
|---|---|---|---|
| **bunker** | hard — **correct**, it is earth and timber | **works** — `fb_bunker_fighting_i` → `bunker`, 260 hp | name the meshes with the existing prefix and it is done |
| **HQ / TOC** | **hard by accident** — nobody decided this | **NOTHING** — survives satchels, artillery and napalm forever | a `FSB_STRUCTURE_KINDS` row **and** an `HP_FOR` kind |
| **gate house** | **hard by accident** | **NOTHING** | same, plus the wire-gap question in §4 |

**So the bunker is the cheap one and should be built first** — it proves the pipeline against a
prefix that already works, which means a failure there is a failure of the *tool*, not of the
vocabulary. **The HQ and the gate house each need one row added before they are worth exporting.**

`HP_FOR` (`scripts/world/destructible.gd:80-92`) has no kind that fits either. It warns and falls
back to 100 for an unknown kind, so a missing row is survivable but arbitrary. Proposed, **his to
rule**: `command_bunker` (a dug-in TOC should outlast a fighting bunker's 260) and `gate_house`
(a timber-and-sandbag checkpoint, nearer the 180 of a tower).

> **THE SECOND-WAR DOOR THAT IS STILL SHUT, and it should be named rather than discovered.** Work
> types now come out of the part manifest as bare strings, so a WW1 part can declare
> `work_firestep` with no code change (`kit_registry.gd`, and `stamp_site_plan` never inspects the
> string). **The DESTRUCTIBLE vocabulary did not get the same treatment** — `FSB_STRUCTURE_KINDS`
> and `FSB_SOFT_PREFIXES` are still `const` arrays in `site_planner.gd`, so a trench revetment
> cannot become destructible without editing that file. **That is the same defect as the work
> dictionary, one system over.** It is not urgent for the three proof pieces (one row each) and it
> is exactly what will bite on the fortieth part. Recorded, not built.

---

## 0b · THE PART MASTERS DO NOT MEET THE CONTRACT, AND THE NUMBERS ARE WORSE THAN THE NAMES

**Measured 2026-09-09 by parsing the seven kit GLBs directly** (pure Python on the glTF JSON chunk;
no engine run). This is the census P3 has to close.

> ## CLOSED 2026-09-09 — every part has collision, and the census below is the BEFORE.
>
> `tools/add_kit_colliders.py` cut 30 `-colonly` twins and 2 renames straight into the glTF, with no
> Blender window: a twin node sharing the source mesh index and its local transform, which is exactly
> the shape `fb_bunker_fighting.glb` already shipped. Re-measured after re-import:
> **0 placed parts with no collider** (was 1 in the probe's plan, 5 across the palette) and
> **3 structures on the blast bus** where the same plan wired 1 the hour before.
> `tests/test_site_plan_roundtrip.gd`'s `NO_COLLIDER_BASELINE` is **0** and stays 0.
> `tests/test_fsb_colonly_contract.tscn` still green: 2,435 collider bodies, 0 stray, 0 white.

| part | visible meshes | colliders **before** | colliders **now** |
|---|---|---|---|
| `fb_bunker_fighting` | `WB_bunker_rifle` → **`fb_bunker_fighting`** | 1 | 1 |
| `fb_bunker_mg` | `WB_bunker_m60` → **`fb_bunker_mg`** (+ `m60`, `m60_pintle`) | 3 | 3 — the gun stays passable, deliberately |
| `fb_FoxholeSandbags` | `fb_FoxholeSandbags` | **0** | **1** |
| `fb_sandbag_heavy` | `sandbag_heavy` → **`fb_sandbag_heavy`** | **0** | **1** |
| `fb_sandbag_light` | `fb_sandbag_light` | **0** | **1** |
| `fb_gate_assembly` | `watchtower_1.001` → **`fb_gate_tower`**, + 4 renamed leaves/posts | **0** | **5** |
| `fb_emplacement_m101` | 119 meshes (gun, rounds, crew rigs) | **0** | **24** — gun, carriage, 8 parapet segs |

**THE `.001` IS GONE.** `watchtower_1.001` imported as `watchtower_1_001`; it is `fb_gate_tower` now,
and the gate takes the existing `tower` kind at 180 hp rather than the `gate_house` row this document
proposed — a watchtower on a gate is a tower, and a second kind for it would be vocabulary drift.

**THE TRAP THIS RUN FOUND, because it nearly shipped.** The tool wrote the file only when it had made
a twin. The two bunkers already had colliders, so their renames were applied to a dictionary that was
then discarded — the tool printed a clean line, `kit_parts.json` was updated to the new names, and the
next stamp wired **one structure out of three** because the GLBs still carried `WB_bunker_rifle` and
`WB_bunker_m60`. A rename-only run that writes nothing is the same silent-default bug class one layer
up. Measured and fixed the same hour; `process()` now writes on `made or renamed`.

**And the naming half, which is the defect that went red:** `fb_bunker_fighting.glb` draws
`WB_bunker_rifle` and collides as `fb_bunker_fighting_000-colonly`. **Ballistics reads the collider
name; destruction reads the mesh name.** The monolith's `_wire_structure_destructibles` matches mesh
names against `FSB_STRUCTURE_KINDS`, so it matched **nothing** — 5 meshes, 0 on the blast bus, a
compound that sappers could not breach and bullets could not penetrate.

**The fix shipped in code, not in the masters, and it is the better architecture:** a stamped part
knows its own id, so the kit resolves identity from **authored data** (`data/world/kit_parts.json`)
instead of inferring it from a Blender name. `stamp_site_plan` now refuses to stamp any part with no
authored entry, **before a single node is instanced.** A part master that never gets its names right
is still placeable; a part nobody has ruled on is not.

**What his NEW art must deliver per piece:** real colliders as `{base}_{i:03d}-colonly`, the marker at
the END of the name, no `.001`, and — because the authored table now carries identity — mesh names
that a human can read. The names no longer have to encode the contract, which is precisely the
freedom the kit was supposed to buy. **The July exports have all of that as of 2026-09-09**; the
outstanding half is the tower and HQ art, specified in §8.

> ## 0c · THREE MORE THINGS THE JULY EXPORTS GET WRONG, and none of them is a name
>
> **Measured 2026-09-09 (late) by stamping all seven parts into one 81-part firebase and rendering
> it at eye height** — `tools/probe_firebase_site.tscn`, `tools/shot_firebase_site.tscn`,
> `data/site_plans/fsb_kit_alpha.json`. The collision census above was the naming half. This is what
> was left, and only the last one is invisible from inside the engine.
>
> 1. **BOTH BUNKERS DRAW WHITE.** `fb_bunker_fighting.glb` and `fb_bunker_mg.glb` carry **0 embedded
>    images**, and their materials — `fb_earth`, `fb_timber`, `fb_psp`, `fb_sandbag_wall`, `fb_crate` —
>    have neither a `baseColorTexture` nor a `baseColorFactor`, which draws at the white default.
>    Every one of those names is the exact basename of a PNG in
>    `assets/.../firebase/tex/`, and every primitive using them carries TEXCOORD_0. It is the pack
>    step of a review export, nothing more. `tools/pack_kit_textures.py --apply` embeds them by name
>    (4 and 5 images, 407 KB and 982 KB, both under the 1 MB law) and refuses any material with no
>    matching PNG or no UVs rather than guessing. **His re-export makes the tool redundant, which is
>    the correct end state.**
> 2. **THREE PARTS ARE CENTRE-ORIGIN, violating §2.1.** `fb_sandbag_heavy` spans Y ±0.54,
>    `fb_sandbag_light` ±0.44, `fb_FoxholeSandbags` ±0.18 — symmetric about the origin, so at
>    `pos.y = 0` half of each is underground. The two bunkers and the gate are CORRECT (the bunkers
>    put 205 and 229 verts on the y=0 plane and dig a sump below it; the gate's minY is exactly 0).
>    `tools/gen_site_plan_firebase.py` carries an `OFFSET_Y` table that compensates, and it names the
>    measurement so the offsets can be set to 0.0 the day the masters are fixed.
> 3. **`fb_emplacement_m101` HAS A BURIED CREWMAN.** `grunt_*_ammo` occupies Y −1.97 … −0.70 while
>    `MC_pit_floor` bottoms at −0.39: the ammo bearer's head is roughly 1.3 m below his own floor.
>    The part's `minY -1.97` is that man, not the gun. The other three baked crew render as untextured
>    bare skin in a spread pose.
>
> **And one code finding, from the same run:** `[NAVROOF] 5 structure(s) have WALKABLE navmesh on the
> roof`, `fb_gate_tower` among them. NavBaker's roof-cull prefixes do not know the kit part names, so
> a man can path onto the tower and the bunker tops. Recorded, not fixed.

## 1 · THE TWO CONTRACTS, AND THE ONE FACT PEOPLE GET WRONG

| | reads the name of | default |
|---|---|---|
| **Ballistics** (shoot-through) | the **CollisionObject3D** — the `-colonly` body | `hard_surface` |
| **Destruction** (blast) | the **MeshInstance3D** — the visual | not destructible |

**Different functions, different nodes.** Keep the collider name derived from the mesh name
(`{base}` and `{base}_{i:03d}-colonly`). Divergence gives you half a system, and half is worse than
none because it looks like it works.

**The `-colonly` marker must be at the END of the name.** `us_fb_ammo_crate_stack-colonly_P2`
shipped as a **visible white box** z-fighting the real crate in three consecutive exports. Renaming
to drop the marker is the wrong fix and was refused once already; move the marker to the end. This
is now gated three ways, including `tests/test_fsb_colonly_contract.tscn`.

---

## 2 · WHAT THE KIT ADDS ON TOP

A kit part is a **standalone GLB** that `SitePlanner.stamp_site_plan()` instances, seats and wires.
Everything below is what makes that possible and is checked by
`tests/test_site_plan_roundtrip.tscn`.

1. **ONE ROOT, ORIGIN AT THE GROUND CONTACT POINT, +Z FORWARD.** The stamper writes
   `part.position = plan_offset` and `part.rotation.y = yaw`. Nothing re-seats a part per-mesh, so
   an origin floating above the floor floats the whole part. **Origin at the centre of the
   footprint, on the ground plane.**
2. **UPRIGHT ONLY.** `yaw_deg` is the only rotation a plan may carry (`site_plan.gd`). A part
   authored tilted cannot be corrected by the tool and will not meet the ground it is seated on.
3. **NO BAKED TRANSFORMS.** 80 of 81 parapet segments in the monolith carry no node transform —
   geometry baked into vertices — which is why the siege seated every wall at the model root and
   fourteen sappers all targeted the same point. **A kit part must carry its transform on the
   node.**
4. **NO `.001` DUPLICATES.** Blender's `.001` imports as `_001` (glTF `naming_version=2` maps `.`
   to `_`, it does not delete it). `fb_sbg_seg_046_001` shipped invulnerable among 80 destructible
   twins for weeks.
5. **TEXTURE BUDGET (his law, 2026-08-18): no embedded image over 1 MB.** Shrink the sheet in the
   source blend; `python tools/shrink_oversized_textures.py --apply` is the fallback.
6. **A part is placed by ID, and the id is `set_meta("part_id")`, never the node name.** Godot
   auto-renames duplicate children, so two of anything become `X` and `X2` and every lookup keyed on
   the name breaks silently. `stamp_site_plan` already does this; do not "fix" it by naming nodes.

---

## 3 · WORK STATIONS — the half that makes a part more than geometry

His ask was *"individual model builds with the work points and animations saved to those
locations."* **The mechanism exists and is read today** (`KitRegistry`,
`assets/.../kit/firebase_set.json`): 28 parts known, **8 already carry stations**.

A station is a marker in the manifest carrying `work_type`, plus `pos` and `face`:

```json
{ "name": "work_radio", "pos": [0.0, -1.2, 0.0], "face": 1.5708, "work_type": "radio" }
```

- **`work_type` is a BARE STRING and no code checks it against any constant.** That is deliberate
  and it is the door held open for a second war.
- **Manifest space is Blender's** — `pos` is `[x, y, z]` with Y forward and Z up. `KitRegistry`
  swaps it to Godot's `(x, z, -y)`. Author in Blender; do not pre-swap.
- **A station must stand on walkable ground.** `tests/test_marker_navmesh.tscn` measures every post
  against the baked navmesh and ratchets — today 35 posts, 5 further than 1 m, worst 1.19 m. **The
  chow-hall fix that actually shipped was not code: it was 16 of 48 markers moved in the asset after
  somebody measured each one.** A station 1.5 m inside its own wall is the defect this probe exists
  to catch, and the tool makes it easier to create, not harder.
- **Clearance, not just reachability.** Every bunker work marker in the monolith sits at exactly the
  player capsule radius from its own wall — zero margin. Leave the capsule (r 0.40) room to stand.

### What each proof piece owes

- **BUNKER** — a fire point at the embrasure with a real line of sight out (the monolith's
  `fb_bunker_mg` carries `mg_fire_point` **and** `bunker_los_point`, and the second exists because
  an embrasure that does not see out is a bunker nobody can fight from). A `door_main` marker with
  `door_width`. **Headroom: 19 of 37 bunker fire points in the monolith take a man only crouched
  and 12 take him at neither posture** — "the AI can get in and I can't" was HEADROOM, not doorways.
  Author the interior for a standing 1.8 m capsule or declare it a crouch position deliberately.
- **HQ / TOC** — `work_radio` (already in the manifest vocabulary, and
  `site_planner.gd:1130,1173` already map `radio` → occupation `radioman`, so **the radio post the
  other council asked to keep expressible is already expressible**). Map tables, plotting boards,
  field desks and radio sets — he confirmed the officers are studying **maps**. `door_main`.
  **AND THE LIGHTBULBS — see §5.**
- **GATE HOUSE** — the one that proves the data model, and therefore **built last**. It owes
  `SOCKET_A` / `SOCKET_B` / `FACE_OUT` (the existing `fb_gate_gap` convention, read by
  `fsb_gate_metrics`), a guard `work_type`, and the wire gap in §4.

---

## 4 · THE GATE IS NOT GEOMETRY — it is the data-model test

A gate brings a guard post, a work point, an animation, an NPC who belongs there, a road arriving,
and **a hole in the perimeter that two systems read**:

- `SiegeDirector._measure_perimeter` bins per-bearing wall radii off the `fsb_parapet` group and
  **returns silently when that group is empty** — so a gate that breaks the parapet wiring does not
  merely stop destruction, it un-measures the perimeter and every bearing reads "inside".
- The sapper breach chain and `NavBaker.breach_at` cut a real hole when a segment dies.

**A gate is a ROAD GAP interrupting the trench and the wire — not a fortress gate.** That is the
doctrine note in `gen_firebase.py`'s own header, and the same header measures the current
`SOCKET_A`→`SOCKET_B` span at **28.6 m, "which is a highway."** The better gate house should be a
checkpoint on a gap a truck fits through, not a castle door.

**And it ties three of his five playtest observations together:** the convoy drives
`RoadNetwork.longest_route()`, `mission_generator.gd:351` refuses to make a convoy without a road
(*"no road, no convoy — a truck does not drive through jungle"*), and the road arrives **at the
gate**. Roads, convoys and the gate house are one problem seen from three sides.

---

## 5 · THE FLOATING LIGHTBULBS — measure the right thing first

He asked for *"a better hq that doesnt have floating lightbulbs."* **Before anyone moves a bulb:**

- **545 `fb_int_` interior props were folded into 69 MultiMeshes four hours before he said it**
  (commit `d904fd70`). Establish whether the bulbs float in the **source bake** — a placement
  defect, which is the whole argument for the kit — or whether the fold or the visibility-range work
  moved them.
- **The 2026-08-30 collision audit measured "hanging bulbs (+7.8 m)" as CORRECT**, because inside
  the firebase **the model is the ground** and that probe measured height above the *terrain
  heightmap*. That number is not evidence of a defect.
- **Measure a bulb against its own ceiling, not against the terrain.**

In the kit the whole class dissolves: a bulb becomes a `prop_class` marker inside the HQ part, at
the height its own ceiling puts it, and moving it is an edit to one part rather than a re-export of
a 43 MB monolith. **That is the argument, and it should be demonstrated on this piece.**

---

## 6 · DOORS TO KEEP OPEN (from the progression council; data shape only, build nothing)

1. **Work vocabulary lives in the part.** ✅ **Done** — bare strings, checked against nothing.
2. **`radio_post` anchor.** ✅ **Already expressible** — `work_type: "radio"` is in the manifest
   vocabulary and already maps to `radioman`.
3. **NPC spawn by building combination** — *"certain npcs thatll spawn with certain building
   combos."* ✅ **WIRED 2026-09-09.** `crew` / `demands` / `supplies` are authored in
   `data/world/kit_parts.json` (not in the generated manifest, which carried none of them — twenty-two
   families, zero crew, so the door was open onto an empty room), read by `KitRegistry.crew_for` /
   `demands_for` / `supplies_for`, and resolved by `SitePlanner._plan_garrison()` into the SAME
   `{pos, occupation, men}` shape `fsb_garrison_plan()` emits, on the site dict as `garrison`.
   **It emits REQUESTS and instantiates nobody** — `Civilian.spawn` stays the one door (ADR-028).
   The combo rule is proven both ways in `tests/test_site_plan_roundtrip.gd`: `fb_gate_assembly`
   demands `perimeter`, so it posts **0** men alone and **1** beside a part that supplies it.
   A role with no occupation posts as `off_duty` and says so; `KIT_CREW_OCCUPATION` maps meaning,
   never gates placement.
4. **A neck/chest attach socket** on the character rig for a necklace prop. Not this document's
   work; recorded so it is not designed out.

---

## 7 · ACCEPTANCE — what "the kit works" means

For each of the three pieces, in order **bunker → HQ → gate house**:

- [ ] Places in `tools/kit_editor.tscn`, sits on the ground, rotates on yaw, saves, reloads.
- [ ] `G` stamps it through `SitePlanner.stamp_site_plan()` and it looks the same as the preview.
- [ ] Boot the world and read the three `[FSB]` lines: soft count matches what you exported,
      parapet **absent = 0**, and the structures line **prints at all** — if it is missing, nothing
      matched a prefix and every part is invulnerable.
- [ ] `tests/test_marker_navmesh.tscn` does not rise above its ratchet.
- [ ] `tests/test_site_plan_roundtrip.tscn` and `tests/test_kit_editor_state.tscn` green.
- [ ] `tests/test_fsb_colonly_contract.tscn` green — every `-colonly` terminal, 0 stray.
- [ ] No embedded image over 1 MB.
- [ ] A man can stand at every station the part declares, at the posture it implies.

**None of these may be run until the perf baseline is taken and the machine is released.**

> **RUN 2026-09-09 (late), on the seven parts that exist rather than on the three proof pieces.**
> The bar above is written per-piece and two of the three pieces are still his art, so the whole kit
> was put through it at once instead: `data/site_plans/fsb_kit_alpha.json`, 81 parts, one boot.
> `test_site_plan_roundtrip`, `test_kit_editor_state`, `test_fsb_colonly_contract` and
> `test_marker_navmesh` all green; 0 SCRIPT ERROR; no embedded image over 1 MB.
> `tools/probe_firebase_site.tscn` adds four measurements the per-piece list does not ask for and a
> firebase needs — **flat ground under every part over its own footprint** (0.000 m worst),
> **every collider in a ballistics group**, **a garrison with its demands met** (15 posts / 19 men,
> gate guard posted, and 0 posted for the same gate alone as a control), and **a perimeter that is
> closed except at the gate** (from outside, gate shut, the path dies 20.2 m short; blow the gate
> tower and the way in runs through the gateway).
>
> **The one it made explicit: a fighting bay is not a wall.** Five 0.35 m sandbag rings left in the
> parapet line were each a step-over for a 0.40 m nav agent, and the twelve 1 m shoulders beside the
> corner bunkers were walk-throughs. The base was open on seventeen bearings and looked closed. The
> bays moved 2.2 m behind the parapet and a seal pass fills any remaining gap wider than 0.55 m.
> **Nothing in this document would have caught that, and a screenshot never will.**


---

## 8 · THE ART LIST — what he owes the kit, and what the kit owes him back

**Written 2026-09-09 after the collision pass. He is doing the tower and the HQ himself.** Everything
below is measured off the parts already in the kit or read from the code that consumes them.

### 8.1 · Files, one GLB per part, in `assets/world/building models/structures/firebase/kit/`

| file | replaces | what it is |
|---|---|---|
| `fb_tower.glb` | the `fb_tower` manifest row, which has never had a model | the standalone watch tower |
| `fb_gate_tower.glb` *(optional)* | `fb_gate_assembly`'s tower half | only if the gate tower differs from the line tower |
| `fb_toc.glb` | the `fb_toc` manifest row, which has never had a model | the HQ / TOC, **without floating lightbulbs** |

**The filename IS the part id.** `KitRegistry._attach_models()` takes the basename, and a part is
placeable the moment its `.glb` sits beside the manifest. No import step, no registration.

### 8.2 · Mesh naming — the whole destructibility contract, in four lines

1. **One visible mesh is THE STRUCTURE, and it is named the part id**: `fb_tower`, `fb_toc`.
   That name goes in `structure_meshes` in `data/world/kit_parts.json`, and it is the mesh the blast
   bus adopts. **Exactly one per part** — `contract_gap()` refuses two, because one `Destructible`
   takes all of a part's colliders and the second would be adopted with no shape left to give it.
2. **Every solid mesh gets a collider twin named `{mesh}_{NNN}-colonly`**, marker at the **END**.
   If the export does not make them, run `python tools/add_kit_colliders.py --apply` — it cuts them
   in the glTF and never touches geometry.
3. **NO `.001` ANYWHERE.** Blender's `.001` imports as `_001` and ships invulnerable beside its twins.
   Rename in the blend before exporting.
4. **Everything else in the part is free.** Interior props, furniture, the map board, the lightbulbs —
   call them what you like. Identity comes from the authored table now, not from a name.

### 8.3 · Sizes — from the manifest rows the kit already carries

| part | footprint (X × Y × Z, Blender: Z is up) | notes |
|---|---|---|
| `fb_tower` | **3.6 × 3.6 × 9.7 m** | the current row. Anything within ±20% is fine; it is a plan offset, not a socket. |
| `fb_toc` | **7.4 × 5.6 × 5.05 m** | the current row. |

**Two constraints that are NOT negotiable:**

- **ORIGIN AT THE GROUND CONTACT POINT, +Z FORWARD, ZERO TILT.** The stamper writes
  `part.position = plan_offset` and `part.rotation.y = yaw` and re-seats nothing per-mesh. An origin
  floating above the floor floats the whole building. `yaw_deg` is the only rotation a plan may carry.
- **NO BAKED TRANSFORMS.** 80 of 81 parapet segments in the monolith carry no node transform, which is
  why fourteen sappers all attacked the same point. Keep the transform on the node.

**And one his own law already sets: no embedded image over 1 MB.** Shrink the sheet in the blend, or
`python tools/shrink_oversized_textures.py --apply` after export.

### 8.4 · Headroom — the measurement that explains "the AI can get in and I can't"

**19 of 37 bunker fire points in the monolith take a man only crouched, and 12 take him at neither
posture.** It was never the doorways. The player capsule is r 0.40 and stands 1.8 m.

- **Tower**: a man must STAND on the platform. Floor to the underside of the roof ≥ **2.0 m**, and the
  ladder or stair no steeper than ~35°.
- **HQ / TOC**: a man must STAND at the radio and at the map board. Same 2.0 m, and leave the capsule
  radius clear of the wall at every marker — every bunker marker in the monolith sits at *exactly*
  0.40 m from its own wall, zero margin.

### 8.5 · Markers the kit will read off these two parts

Empties in the blend, exported with the mesh, listed in the manifest with `work_type` or `prop_class`.
`work_type` is a bare string checked against nothing.

- **`fb_tower`** — `tower_los_point` (already in the manifest at 8.9 m up) with a real line of sight
  out; a `work_type: "watch"` post a man can stand at.
- **`fb_toc`** — `work_radio` (already there, and `radio` already maps to occupation `radioman`),
  `prop_map`, `door_main` with `door_width`. **The lightbulbs become `prop_class` markers at the
  height their own ceiling puts them** — which is the whole argument for the kit, and this is the
  piece it gets demonstrated on. Measure a bulb against its own CEILING, never against the terrain:
  the 2026-08-30 audit measured "hanging bulbs +7.8 m" as CORRECT because inside the firebase the
  model is the ground.

### 8.6 · Two rows he has to rule on, one line each

- **`fb_toc` destructible kind.** `HP_FOR` has no row that fits a dug-in command post. Proposed
  **`command_bunker` at 320 hp** (a fighting bunker is 260, the parapet datum is 140) with
  `explosion_mortar` as its death blast. **Not added — his number.**
- **`fb_tower` kind is settled**: the existing `tower`, 180 hp, `explosion_grenade`. No new row.
