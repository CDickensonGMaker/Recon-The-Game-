# godot-specialist — POST-EXPORT VERIFICATION, `fsb_main_v3.glb`

**Written 2026-08-12, against the export dated 2026-08-12 22:26 (47,590,084 bytes) and the
Godot import cache dated 2026-08-12 22:27.** Every number below is measured, not estimated.

**METHOD — and why it beats predicting.** The `.import` cache
(`.godot/imported/fsb_main_v3.glb-61381e299c3b0ed72b6cbb5172709998.scn`, 9.88 MB, timestamp
22:27) is **current with this export**. That file is a zstd-compressed (`RSCC`, cmode 2,
block 4096) Godot binary `PackedScene`. It was decompressed and its `_bundled` dictionary
decoded, giving the **post-import node tree exactly as `SitePlanner` will walk it** — real
node names after Godot's glTF sanitisation, real node classes, and the actual
`ConcavePolygonShape3D` resource identities. Nothing here is a guess about what Godot will
do to the names; it is a read of what Godot already did.

Scratchpad scripts (throwaway, NOT in the repo):
`…\scratchpad\parse_glb.py` (glTF JSON chunk) · `decomp.py` (RSCC→raw) · `scn3.py`
(PackedScene tree) · `verdict.py` (contract diff).

No `.blend` was opened, no MCP driven, no GLB re-exported, no game script edited. The one
write outside this file is the correction of `~/.claude/skills/recon-destructible-export/SKILL.md`,
authorised by the brief under the NO MORE DRIFT law.

---

## 0. THE NUMBERS — old vs new

| Metric | 07-26 export | **08-12 export** | source |
|---|---|---|---|
| glTF nodes | 1,259 | **5,475** | glTF JSON chunk |
| glTF meshes / materials | — | **2,356 / 156** | glTF JSON chunk |
| `-colonly` nodes | 365 | **2,368** | glTF JSON chunk |
| `-col` / `-convcol` / `-navmesh` nodes | — | **0 / 0 / 0** | glTF JSON chunk |
| Post-import Godot nodes | — | **8,098** | PackedScene `_bundled` |
| `StaticBody3D` / `CollisionShape3D` | — | **2,490 / 2,490** | PackedScene `_bundled` |
| unique `ConcavePolygonShape3D` resources | — | **1,963** | internal-resource table |
| `fb_int_` interior props | 178 (`site_planner.gd:1372`) | **572** | PackedScene |
| `work_*` markers | 191 (`site_planner.gd:952`) | **487** | PackedScene |
| parapet visual segments | 80 | **81** (80 + 1 stray) | PackedScene |
| CHOW HALL present | **NO** | **YES** | PackedScene |
| MEDICAL COMPLEX present | **NO** | **YES** | PackedScene |

**Two live doc-drift items created by this export, both cited above:** `site_planner.gd:952-953`
still says "191 work markers (measured)" — it is 487. `site_planner.gd:1372-1374` still says
"178 `fb_int_` props / 368 surfaces / 11,936 tris" — the prop count is 572. Both are `FSB_WORK_POST_CAP`
and `INTERIOR_CULL_M` rationale text; the constants themselves are still defensible, but the
measurements they cite are now wrong by 2.5x and 3.2x.

---

## 1. THE BOOT LINE — `[FSB] N concave shape(s) forced double-sided`

### Where it is emitted
`scripts/world/site_planner.gd:1476-1477`, at the end of `_repair_glb_colliders`
(`:1421`). The count comes from `_force_backface_collision` (`:1407-1418`), which is run over
every `StaticBody3D` under the firebase root at `:1468-1475`.

```gdscript
var concave := cs.shape as ConcavePolygonShape3D
if concave == null or concave.backface_collision:
    continue
concave.backface_collision = true
fixed += 1
```

### **PREDICTED COUNT: 2,048. Confidence HIGH.**

Derivation, from the import cache:

| Step | Count |
|---|---|
| `CollisionShape3D` nodes whose shape is `ConcavePolygonShape3D` | 2,490 (**all of them**) |
| …resolving to **unique** shape resources | 1,963 |
| Shapes under `fb_veg_` / `fb_sbg_seg_` bodies — **deleted** at `:1452-1454` | 86 nodes (81 parapet + 5 veg) |
| Unique shapes surviving that deletion | **1,962** |
| Re-meshed at `:1455-1457` via `create_trimesh_collision()`, each a **fresh** shape | **+86** |
| **Total counted by `_force_backface_collision`** | **2,048** |

Two things make this a prediction rather than an arithmetic identity, and both are small:
`_remesh_collider` (`:1524`) returns `false` if it cannot find the stripped-name mesh (each
miss costs 1), and the count is per **unique resource**, not per node — 137 shape resources
are shared by more than one `CollisionShape3D` (527 redundant references), and the `continue`
at `:1414` skips a shape already flipped. Both effects are already folded in above. **Floor of
the range is 1,962** (every re-mesh fails); **2,048 is the expected value.**

### What a NON-ZERO count actually means — and the drift in the comment above it

`site_planner.gd:1402-1406` says:

> *"…this holds the shipped GLB solid until that re-export lands, and **returns 0 once it has**."*

**That is impossible and it is now a live drift generator.** `backface_collision` is a
**Godot runtime property of `ConcavePolygonShape3D`, default `false`**. glTF has no way to
express it; Blender has no way to export it; the winding direction of the source mesh does not
set it. So long as the firebase ships trimesh colliders, this line will print a number roughly
equal to the trimesh count, **forever**. It printed non-zero before the export, it prints
2,048 after it, and no future export will make it 0.

Under the POINTER LAW / NO MORE DRIFT this comment must be corrected or the function deleted:
it invites the next reader to treat 2,048 as an export defect and go re-author the model, which
is exactly the failure mode the law names. I did not edit it (READ-ONLY on game code) — it is
logged here as the finding.

### Does a forced-double-sided shape break the 80 destructibles or blind SiegeDirector?

**No, on both counts. The brief's checklist conflates two independent systems.** Verified:

1. **It cannot break the naming contract.** `_force_backface_collision` (`:1407-1418`) flips one
   boolean on a shape. It renames nothing, reparents nothing, frees nothing. The destructible
   contract is purely name-based: `_wire_parapet_destructibles` (`:1641`) does
   `root.find_child(seg.name, true, false)` against **`MeshInstance3D` names**, and
   `_wire_structure_destructibles` (`:1739`) does `mi.name.begins_with(prefix)`. Neither reads
   a shape, a winding, or a `backface_collision`.
2. **Order is safe.** `_repair_glb_colliders` runs at `:1308`, `_wire_parapet_destructibles` at
   `:1310`. The repair deletes the parapet's imported body and re-creates one via
   `create_trimesh_collision()`, which parents the new `StaticBody3D` **under the
   `MeshInstance3D`** — so the parapet wiring's *child* scan at `:1670-1673` finds it before it
   ever needs the *sibling* fallback at `:1674-1678`. `[TEMPSEG] … MOVED 0` (`:1697`) should not
   print.
3. **SiegeDirector is not blinded by this line, and does not read a breach at all any more.**
   `scripts/missions/siege_director.gd:66`: *"Parapet destruction stays spectacle. **Nothing here
   reads a breach.**"* The only parapet read left is `_measure_perimeter` at `:557`, which uses
   the group for per-bearing wall radii and **returns silently on an empty group** (`:559-560`).

**So the real silent-blinding risk is the one the skill's FAILURE MODE 4 names — a parapet
manifest that no longer matches the export — not this line.** That risk is **clear today**: see §3.

**The line Caleb should actually read on boot, and the acceptance values:**

| Boot line | site_planner.gd | **Predicted** |
|---|---|---|
| `[FSB] N concave shape(s) forced double-sided` | `:1476` | **2048** (benign; see above) |
| `[FSB] ballistic tags: S soft, H hard` | `:1515` | **445 soft, 2045 hard** |
| `[FSB] parapet: N destructible segment(s)…` | `:1707` | **80 wired, 0 absent** ✅ |
| `[FSB] structures on the blast bus: …` | `:1763` | **8 bunker + 4 bunker_mg + 4 tower + 9 sandbag_stack + 3 bunker = 28** |
| `[FSB] N interior prop(s) culled past 40m` | `:1399` | **572** |
| `[FSB] replaced N box hull(s) …, M re-meshed` | `:1465` | **86 replaced, 86 re-meshed** |
| `[FSB] screen doors: N hung` | `:1713` | 11 hooches × 1 |

---

## 2. THE PREFIX CONTRACT — silent invulnerability and silent bulletproofing

**This is the highest-value section.** Each row below is a mesh family a reasonable reader
would expect to be soft and/or destructible, which fails the contract and therefore ships
**bulletproof and/or invulnerable with no error**.

Ballistics authority: `FSB_SOFT_PREFIXES` (`site_planner.gd:1488-1490`) matched against the
**collider body name** in `_tag_fsb_ballistics` (`:1493-1516`); anything unmatched joins
`hard_surface` and `bullet_system.gd:243` **stops the round dead**.
Destruction authority: `FSB_STRUCTURE_KINDS` (`site_planner.gd:1723-1736`) matched against the
**mesh name** in `_wire_structure_destructibles` (`:1739-1763`).

### A. `medical_complex` — the whole aid station is one bulletproof, invulnerable monolith ⚠ **TOP DEFECT**

The medical complex imports as **exactly two nodes**: `MeshInstance3D medical_complex` and its
collider `StaticBody3D medical_complex_2906`, both children of the GLB root.

- `medical_complex` matches **no** entry in `FSB_SOFT_PREFIXES` → `hard_surface`. A ward with
  canvas/plywood walls **stops 7.62**.
- It matches **no** entry in `FSB_STRUCTURE_KINDS` → **no `Destructible`**. It survives satchels,
  the 45-man assault, artillery and napalm, permanently.
- **`fb_aid_station` — a prefix that has been sitting in `FSB_SOFT_PREFIXES` since it was
  written — matches ZERO nodes in this export.** It is a dead entry aiming at a building that
  is now called something else.
- It is **absent from `NAV_ROOF_CULL_PREFIXES`** (`nav_baker.gd:508-510`). It is a monolith —
  roof and interior floor in one mesh, exactly the shape that list exists for — so **its roof
  bakes as walkable navmesh and men will path onto it.** This is precisely the defect commit
  19b2bed0 fixed for the five bunker/tent families, hours before this building landed.

### B. The chow hall — same three failures

Six meshes, all `hard_surface`, all invulnerable, none in the roof-cull list:

| Node | Class | Ballistics | Destructible |
|---|---|---|---|
| `tent_roof_chowhall` | MeshInstance3D | **hard** | no |
| `tent_frame_chowhall` | MeshInstance3D | **hard** | no |
| `tent_gable_chowhall` | MeshInstance3D | **hard** | no |
| `WB_chowhall_backwall` | MeshInstance3D | **hard** | no |
| `fb_chow_pot`, `fb_chow_pot_range` | MeshInstance3D | hard | no |

A **canvas tent roof that stops a rifle round** is the exact failure the skill's FAILURE MODE 2
describes. `fb_mess` is in `FSB_SOFT_PREFIXES` and matches only the old single `fb_mess_i` tent.
`WB_` is a workbench prefix — `WB_chowhall`, `WB_chowhall_001/002` are Node3D roots and
`WB_bunker_m60` / `WB_bunker_rifle` are further workbench meshes that shipped into the export.

### C. `fb_hwall_*` — 242 bulletproof hooch wall panels ⚠

22 families × 11 hooches = **242 wall panels named `fb_hwall_<slot>_<n>`**. The same hooches'
`fb_hootch_screen_*` (242 panels) and `fb_hootch_roof_*` (176 panels) **are** soft, because they
carry the `fb_hootch` prefix. `fb_hwall` does not.

**Every hooch in the compound therefore has soft screens, a soft roof and HARD WALLS.** A round
passes through the screen and stops in the plywood beside it. Pillar 1.

Cheapest fix is one string in `FSB_SOFT_PREFIXES` (`site_planner.gd:1488`) — `"fb_hwall"` — no
re-export. That is the whole point of the prefix design.

### D. `fb_sbg_seg_046_001` — a stray 81st parapet segment, invulnerable among 80 destructible twins ⚠

The Blender duplicate `fb_sbg_seg_046.001` imports (Godot glTF `naming_version=2` maps `.`→`_`)
as **`fb_sbg_seg_046_001`**. Measured:

- `firebase_v3_destructibles.json`: **80 segments, `fb_sbg_seg_000`…`fb_sbg_seg_079`, all
  `sandbag_wall` hp 140** — **all 80 present in the scene, 0 absent.** ✅
- The scene holds **81** parapet meshes. `fb_sbg_seg_046_001` is **not in the manifest**, so
  `_wire_parapet_destructibles` never adopts it.
- It **does** start with `fb_sbg_seg_`, so it is in `REMESH_COLLIDER_PREFIXES` (`:1368`) and gets
  its box hull re-meshed like the others — it will *look and collide* exactly like its 80
  neighbours and **never take a mark**. Sappers blow the wall on either side of it and one
  section stands.

Not a nav or siege bug — `_measure_perimeter` only reads the wired group — but a visible
Pillar-1 lie in the wire.

### E. Characters and their kit shipped as bulletproof statues — 548 collider bodies ⚠

The export bakes posed people into the world GLB, and every part carries a `-colonly` twin:

| Family | collider bodies |
|---|---|
| `MC_spent` / `MC_crate` / `MC_casing` / `MC_pit` (mortar crew set) | 148 |
| `grunt_*` (`_tend_medic0/1/2`, `_wounded1`) | 108 |
| `cap_*` | 108 |
| `OFF0_/OFF1_/OFF2_*` (3 officers: web gear, satchel, papers, desk, chair) | 78 |
| `PSXRig_med_work_surgeon/scrubnurse/anesthetist_*` + `scrub_cap` | 22 |
| **total** | **548** |

All of them fall through to `hard_surface`. A round fired at the surgeon **stops on his apron**
— no damage, no hit reaction, no penetration, because these are `StaticBody3D` on layer 1 and
not `Hitzone` (`scripts/combat/hitzone.gd`). They are also **not** in `NAV_IGNORE_PREFIXES`
(`nav_baker.gd:450`), so each punches a hole in the navmesh and erodes `agent_radius` around it —
the same mechanism the comment at `nav_baker.gd:431-433` blames for fragmenting the compound
into islands.

### F. Structure parts that survive their own structure's destruction

| Family | count | note |
|---|---|---|
| `fb_sandbag_hooch_*` | 110 | hard (correct) but invulnerable |
| `fb_sandbag_parapet` | 32 | hard (correct) but invulnerable — only `fb_sandbag_stack_i` (9) is on the bus |
| `fb_bunker_steps` | 12 | a destroyed bunker leaves its steps standing |
| `fb_bunker_revet` | 11 | and its revetment |
| `fb_trench_run_i` | 8 | `_i` convention, no kind |
| `WB_bunker_m60`, `WB_bunker_rifle` | 2 | workbench bunkers, indestructible |

### G. Two export hygiene defects

- **`us_fb_ammo_crate_stack-colonly_P2` imported as a VISIBLE `MeshInstance3D`.** Godot's
  suffix parser only fires when a name **ends** with `-colonly`; the trailing `_P2` defeats it.
  The result is a collision hull that is now **rendered** in the world, *and* it picked up its
  own separate collider `us_fb_ammo_crate_stack-colonly_P2_3393`. One mesh, drawn, that was
  never meant to be seen.
- **`Icosphere` × 20** (20 `MeshInstance3D` + 20 `StaticBody3D`, all at the GLB root). Unnamed
  Blender primitives with colliders, tagged `hard_surface`, sitting in the compound. Caleb's
  call what they are; they should not ship under a default primitive name.

### What passes cleanly ✅

- `door_hooch_leaf_l/r` and `door_hooch_screen` (44 meshes): **zero `StaticBody3D`**. Commit
  c907cb04 held — the screen-door leaves carry no collider, and `door_` is in
  `NAV_IGNORE_PREFIXES` so a leaf could not seal a doorway even if one ever got a collider.
- All 5 `FSB_STRUCTURE_KINDS` firebase prefixes match: 8 `fb_bunker_fighting_i`,
  4 `fb_bunker_mg_i`, 3 `fb_sleeping_bunker_i`, 4 `fb_tower_i`, 9 `fb_sandbag_stack_i` = **28
  structures on the blast bus** (was 17 in the skill's example line).
- The parapet manifest is **exact**: 80 named, 80 found, 0 absent.

---

## 3. ARTILLERY CREW — **BUILT, WIRED, AND HALF OF IT IS STRANDED BY A NAME**

The memory note *"recon-artillery-crew-is-built-and-stranded"* is **superseded for the
howitzers and still true for the mortars**, for a reason nobody has looked at since the export.

**The driver exists and is complete:**
- `scripts/world/gun_crew_performance.gd` — `class_name GunCrewPerformance`, the phase-locked
  pit loop, piece animation `PIECE_CLIP = "M101Rig"` played at `:205-212`.
- `scripts/world/civilian.gd:891-912` find-or-creates the pit driver within
  `GunCrewPerformance.PIT_RADIUS`; `:618-635` plays the per-seat clips
  (`gun_gunner` / `gun_loader` / `gun_agunner` / `gun_ammo_bearer`, and
  `mortar_gunner` / `mortar_dropper` / `mortar_runner` when `role == "mortar"`).
- `scripts/ai/civilian_schedules.gd:150-160` gives `gun_crew_arty` a round-the-clock schedule.
- `site_planner.gd:1132-1152` seeds one whole crew per weapon type off `_arty_pits()` (`:977`).

**The defect.** `_arty_pits()` (`site_planner.gd:982-983`) selects markers with
`wt != "gun" and wt != "mortar": continue`. The work-type string is produced by
`_ensure_fsb_markers` (`site_planner.gd:1041-1046`), which strips **one** trailing `_<int>`.
Measured against the real post-import names:

| Marker names in this export | resolved `work_type` | result |
|---|---|---|
| `work_gun`, `work_gun_001` … `work_gun_023` (24) | `gun` | ✅ clusters into pits, 1 crew of 4 seeded |
| `work_mortar_0_gunner` / `_dropper` / `_runner` | `mortar_0_gunner` … | ❌ **not `"mortar"`** |
| `work_mortar_1_gunner` / `_dropper` / `_runner` | `mortar_1_gunner` … | ❌ **not `"mortar"`** |

**Both mortar pits are invisible to `_arty_pits()`.** `crews_seeded["mortar"]` never increments,
no `gun_crew_arty` post is ever created for them, and the six markers are also absent from
`FSB_WORK_OCCUPATION` (`:871-916`) and `FSB_WORK_PRIORITY` (`:922-942`) — so they fall through
`FSB_WORK_OCCUPATION.get(wt, "off_duty")` at `:1163` to **`off_duty`**, seated last in marker
order. The finished `mortar_gunner`/`mortar_dropper`/`mortar_runner` clips at `civilian.gd:631`
have **no caller**, and the crewed mortar pit reads as three men loafing in a hole.

`site_planner.gd:963-968` still describes the *old* convention — *"2 mortar pits x3 markers"* —
which was true when the markers were called `work_mortar`. The export added role names. The
parser did not.

**Fix is data, not code:** add `"mortar_0_gunner"`, `"mortar_0_dropper"`, `"mortar_0_runner"`
(and `_1_`) handling — either a second strip pass in `_ensure_fsb_markers`, or a
`wt.begins_with("mortar")` test at `:982`. No re-export needed.

---

## 4. CHOW-HALL DINER CHAIN — **THE HANDOFF CLAIM IS SUPERSEDED. IT IS WIRED.**

`HANDOFF_CODE_FIXES_2026-08-12.md:280-283` states *"No GDScript reads `work_med*` /
`work_chow*` / `work_medofficer*`. A friendly-side director does not exist."* **That was true
when it was written and is false now** — commit `aba5ca53` ("every work marker wired to a real
job") landed after it.

Today's chain, with pointers:

1. `site_planner.gd:1013-1053 _ensure_fsb_markers` harvests every `work_*` Node3D out of the GLB.
2. `site_planner.gd:871-916 FSB_WORK_OCCUPATION` maps the type → a Civilian occupation. It
   explicitly covers `chow_server`, `chow_server_line`, `chow_diner`, `chow_trigger`,
   `chow_exit`, `chow_tray_return`, `eat`, `queue`, `cook_range`, `traycollector`,
   `trayhandoff` (`:881-887`, `:904-907`) **and** `med_surgeon`, `med_scrubnurse`,
   `med_anesthetist`, `med_tend`, `med_officer`, `med_cot`, `med_or_patient` (`:901-903`).
3. `site_planner.gd:1108-1131` seeds the aid station whole (medic + patient, plus the litter
   team when the ward is above its floor).
4. `scripts/world/civilian.gd:641-...` drives the diner clips per `role`
   (`chow_queue_walk`, `chow_tray_carry_walk`, `chow_queue_step`, `chow_tray_wait`, …);
   `:605-617` drives the servery/stove side.
5. `scripts/ai/civilian_schedules.gd:202-212` gives `mess_hall` a two-sitting breakfast/supper
   schedule so the hall fills and empties.

The handoff's `work_pos`/`work_clip` note remains correct **for the enemy side only** —
`scripts/enemies/camp_director.gd:103-130` and `scripts/enemies/enemy_base.gd:1697-1699`. The
friendly side is a **different mechanism** (Civilian occupations + `role`), which is why a
`work_med*` grep came up empty: nothing greps for the marker name, `_ensure_fsb_markers` reads
the prefix and hands the *type* down.

### But 194 of the 487 markers fall through to `off_duty`

Same one-strip bug as the mortars. Measured, resolving every marker exactly as
`site_planner.gd:1042-1045` does:

| Resolved work_type | markers | mapped? |
|---|---|---|
| `hooch_sleep_0` … `hooch_sleep_7` | 8 × 11 = 88 | ❌ table has `hooch_sleep` (`:912`) |
| `hooch_table_0` … `hooch_table_3` | 4 × 11 = 44 | ❌ table has `hooch_table` |
| `hooch_locker_0` … `hooch_locker_2` | 3 × 11 = 33 | ❌ table has `hooch_locker` |
| `hooch_radio_1`, `hooch_radio_2` | 2 × 11 = 22 | ❌ table has `hooch_radio` |
| `med_root` | 1 | ❌ a container empty named `work_med_root` |
| `mortar_[01]_gunner/dropper/runner` | 6 | ❌ see §3 |
| **total falling through to `off_duty`** | **194 of 487 (40%)** | |

The names are `work_hooch_sleep_0_001` … `_011` — an **authored slot ordinal** followed by a
**Blender duplicate ordinal**. `_ensure_fsb_markers` strips one; two are present. For the
hooch families the damage is mild (`hooch_*` maps to `off_duty` anyway, `:908-913`), but it is
mild **by luck**: the comment at `:908-911` says off_duty here must be *stated so the
fall-through is a decision, not an accident* — and today it is an accident again, because the
stated entry is never the one that matches. `med_cot_0…6`, `med_officer_0…2`, `med_tend_0…2`
strip correctly and **do** map, so the aid station itself is fine.

`work_med_root` should not carry the `work_` prefix at all — it is a container empty and it
consumes a work post.

---

## 5. FIX 0 / 0b / 0c / 0d — status against today's commits (the handoff predates all of them)

### FIX 0 — perimeter wall missing from the navmesh → **FIXED**
`scripts/world/nav_baker.gd:453-465`. `_add_colliders` now seeds its walk from
`SitePlanner.FSB_NAV_GEOM_GROUP` in addition to the root:
```gdscript
for d in get_tree().get_nodes_in_group(SitePlanner.FSB_NAV_GEOM_GROUP):
```
The group is defined at `site_planner.gd:1638` and joined by **both** the parapet
(`:1705`) and every adopted structure (`:1810`) — deliberately a *different* group from
`FSB_PARAPET_GROUP` (`:1630`) so a bunker cannot move the siege's idea of the wire
(`:1635-1637`). The second-order name hazard the handoff flagged is acknowledged in-code at
`nav_baker.gd:460-462`. Commit dd211aa8. **Predicted effect: all 80 parapet + 28 structure
colliders now reach the bake.**

### FIX 0b — no `[navigation]` section → **FIXED, and better than the handoff's proposal**
`project.godot:312-314`:
```
[navigation]
3d/default_cell_height=0.2
```
And the handoff's real complaint — the silent halving of the step — is fixed at the source:
`nav_baker.gd:325-326` now uses `maxf(nav.cell_height, roundf(AGENT_MAX_CLIMB / nav.cell_height) * nav.cell_height)`.
`roundf`, not `floor` (commit 35e26973, *"agent_max_climb was still being halved by a float"*).
`filter_walkable_low_height_spans = true` is set at `nav_baker.gd:332`, closing the handoff's
"suspected, unproven" second-walkable-layer item. The value is printed on every bake at
`nav_baker.gd:376-380`, so it is now checkable rather than inferable.

### FIX 0c — `-colonly` colliders are siblings, 23 structures never hand them over → **FIXED, and the premise is confirmed**
`site_planner.gd:1791-1795` (`_adopt_structure`) and `:1674-1678` (`_wire_parapet_destructibles`)
both now scan `mi.get_parent().get_children()` for a `StaticBody3D` whose name
`begins_with(mi.name)`, and preserve `shape.global_transform` across the move (`:1804-1807`,
`:1691-1694`) — the transform preservation the handoff asked for.

**The flat-GLB premise is measured true, and it is more extreme than claimed:** of 8,098
imported nodes, **4,761 are direct children of the GLB root** (2,367 `StaticBody3D`,
1,739 `MeshInstance3D`, 654 `Node3D`), depth histogram `{1: 4761, 2: 3159, 3: 150, 4: 22, 5: 5}`.
`medical_complex` and its collider `medical_complex_2906` are root siblings — exactly the shape
the sibling lookup was written for.

### FIX 0d — `terrain_watchdog.gd` teleports allies onto roofs → **FIXED**
`scripts/missions/terrain_watchdog.gd:60`: `body.global_position.y = world.floor_y(body.global_position) + 0.5`,
with the reasoning at `:55-59`. The remaining `surface_y` at `:64` is the fall-through
re-seat for a man who has fallen *below* the ground — correct per the handoff's own rule
(arbitrary outdoor point → `surface_y`). Commit c09c540a.

**All four are closed. None of the four should be re-opened.** What is *not* closed is the
roof-cull list: `NAV_ROOF_CULL_PREFIXES` (`nav_baker.gd:508-510`) covers
`fb_gp_tent`/`fb_mess`/`fb_bunker_mg`/`fb_bunker_fighting`/`fb_sleeping_bunker` and **misses
both buildings that landed in this export** — `medical_complex` and the chow hall are
monolithic single meshes whose roofs will bake walkable. That is FIX 0-class, newly created by
this export, and it is the one nav item I would put in front of Caleb tonight.

---

## 6. THE SKILL DOC — the drift claim is CONFIRMED, and I corrected it

`HANDOFF_CODE_FIXES_2026-08-12.md:301-302` claimed every `file:line` in
`~/.claude/skills/recon-destructible-export/SKILL.md` was stale by ~94 lines. **Confirmed, and
the drift is larger and non-uniform** — between +94 and +178 lines depending on the symbol,
because functions were inserted between them. Verified sample, each read from source today:

| Skill said | Truth |
|---|---|
| `site_planner.gd:1356 _tag_fsb_ballistics` | **`:1493`** (`:1356` is a comment about parapet box hulls) |
| `:151 tag_ballistics` | **`:139`** (`:151` is `var model_name := …`) |
| `FSB_SOFT_PREFIXES (:1351-1353)` | **`:1488-1490`** |
| ballistic tally print `:1377` | **`:1515`** |
| `_wire_parapet_destructibles (:1496)` | **`:1641`** |
| parapet print `:1538` | **`:1707`** |
| `_wire_structure_destructibles (:1561)` | **`:1739`** |
| `FSB_STRUCTURE_KINDS (:1552-1558)` | **`:1723-1736`** |
| structures print `:1576` | **`:1763`** |
| `place_structure (:162-189)` | **`:150-199`** |
| `bullet_system.gd:216` | **`:232` (soft) / `:243` (hard)** |
| `collision_table.gd:296-306` hints | **`:320-321`**; `is_soft` **`:311`**; the bug story **`:201-206`** |
| `destructible.gd:73-101`, `_ensure_rubble_mm (:119-137)` | file is **`scripts/world/destructible.gd`**; `_do_destroy` **`:170`**, `_ensure_rubble_mm` **`:221`** |
| `game_flow.gd:249-292` sapper lens | **`:227-282`** |

Three **substantive** errors, not just line drift, also corrected:

1. **`destroyed_mesh` is no longer "supported and unused."** `destructible.gd:174-175` now calls
   `ruin_mesh_for(kind)` (`:89`, cached, backed by `RUIN_FOR` at `:29` and `RUINS_DIR` at `:28`).
   Real ruin art is loaded when authored; the grey MultiMesh boxes are the fallback.
2. **HP is no longer authored in `site_planner.gd:1553`.** It is `Destructible.HP_FOR` (`:66`)
   read through `hp_for()` (`:79`), which `push_warning`s on an unknown kind. The skill's
   "three drifted HP tables" FAILURE MODE 8 is stale.
3. **The siege no longer reads a breach axis off the parapet.** `siege_director.gd:66` states it
   outright. The skill's *"A broken manifest doesn't just stop destruction — it blinds the
   siege"* overstates it: what breaks is `_measure_perimeter` (`:557`), which returns silently on
   an empty group.

Also updated: `FSB_STRUCTURE_KINDS` now carries **8** prefixes — the three village families
`nha_tranh_` / `nha_san_` / `nha_ruong_` were added 2026-08-07 (`site_planner.gd:1733-1735`),
which changes the skill's §4 "THE GAP" claim; and `place_structure` still does not call
`_wire_structure_destructibles` (`:1709` is the only call site), so the gap itself stands but
the naming half of it is now pre-solved.

The skill doc has been corrected in place — the one write authorised by the brief.

---

## 7. WHAT I WOULD PUT IN FRONT OF THE SUMMONER

Ranked by Pillar-1 damage per line of fix. All except the last are **data or one string** — no
re-export, no Blender.

1. **`medical_complex` and the chow hall are bulletproof, invulnerable, and their roofs bake
   walkable.** Three separate one-line lists: `FSB_SOFT_PREFIXES` (`:1488`),
   `FSB_STRUCTURE_KINDS` (`:1723`), `NAV_ROOF_CULL_PREFIXES` (`nav_baker.gd:508`). The medical
   complex is a single mesh, so "blowing it up" means the whole building at once — that is a
   design call for him, but *bulletproof* is not.
2. **`fb_hwall` → 242 bulletproof hooch walls.** One string in `FSB_SOFT_PREFIXES`.
3. **194 of 487 work markers (40%) resolve to `off_duty`**, including both crewed mortar pits,
   because `_ensure_fsb_markers` (`:1042-1045`) strips one trailing ordinal and this export has
   two. The mortar clips exist and have no caller.
4. **548 character-part colliders** tagged `hard_surface`, carving navmesh and stopping rounds
   with no hit reaction.
5. **`fb_sbg_seg_046_001`** — one invulnerable segment hiding among 80 destructible ones.
6. **`us_fb_ammo_crate_stack-colonly_P2` renders as visible geometry** and **20 `Icosphere`
   bodies** ship at the root. Blender-side; his call, not a code fix.
7. **`site_planner.gd:1402-1406`'s "returns 0 once the re-export lands"** is unachievable by
   construction and will send the next reader back into Blender. Correct the comment or delete
   the function.
