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

| part | visible meshes | colliders | verdict |
|---|---|---|---|
| `fb_bunker_fighting` | `WB_bunker_rifle` | **1** | usable — but the mesh is a Blender workbench name |
| `fb_bunker_mg` | `m60.002`, `m60_pintle`, `WB_bunker_m60` | **3** | usable — gun meshes must be excluded from the structure |
| `fb_FoxholeSandbags` | `fb_FoxholeSandbags` | **0** | **you can walk through it** |
| `fb_sandbag_heavy` | `sandbag_heavy` | **0** | **you can walk through it** |
| `fb_sandbag_light` | `fb_sandbag_light` | **0** | **you can walk through it** |
| `fb_gate_assembly` | `watchtower_1.001`, `gate_left/right`, `gate_post_left/right` | **0** | no collision, and a `.001` |
| `fb_emplacement_m101` | 119 meshes (gun, rounds, crew rigs) | **0** | not a structure; the firebase swaps it in separately |

> **FIVE OF THE SEVEN PLACEABLE PARTS HAVE NO COLLIDERS AT ALL.** A player walks through them, a
> bullet passes through them, and a `Destructible` built on one has no shape to hit. This is not a
> regression — `gen_firebase.py:1-13` says plainly that these are *"a REVIEW artefact, not a shipped
> asset set."* **It is the actual size of the P3 art job**, and it is why the two bunkers are the
> only parts that can prove the pipeline today.

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

**What P3 must still deliver per piece:** real colliders as `{base}_{i:03d}-colonly`, the marker at
the END of the name, no `.001`, and — because the authored table now carries identity — mesh names
that a human can read. The names no longer have to encode the contract, which is precisely the
freedom the kit was supposed to buy.

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
   combos."* The shape that keeps this open, and the one the part contract should adopt when parts
   are authored: a part may declare `crew` (roles it brings) and `demands`/`supplies` (what must be
   present for it to be staffed), **as strings**. A base with a TOC and a pad has a radioman because
   the TOC supplies `command` and demands `power`, not because a function says so. **Combos must emit
   post requests into the existing `fsb_garrison_plan()` list — `Civilian.spawn` stays the one door
   (ADR-028). No second spawn authority.**
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
