# Handoff — the firebase, the hooches, and the export that had never run

**Written 2026-08-12, end of session. Pointers are `file:line` as of this date.**

---

## 0. READ THIS FIRST

**The firebase is exported and in the game for the first time since 2026-07-26.**
`assets/world/building models/structures/firebase/fsb_main_v3.glb` — 12.77 → 48.68 MB,
1,259 → 5,883 nodes. Everything finished in blends since July — the chow hall, the medical
complex, the crewed mortar pits, and now eleven hooches — was absent from the game until today.

**It was not a decision. `tools/gen_firebase_v3.py` raised `NameError` on IMPORT**: `ROOT` was
read at `:917` and `:942` and defined nowhere, so nobody could run the exporter. Fixed in
`c907cb04` (`ROOT = fb_kit.ROOT`). This predates PHASE A; it was not a regression.

**The blend holds COLLECTION INSTANCES only in `HOOCH_NEW`, which is unlinked from the scene.
The eleven placed hooches are REAL objects.** If you ever rebuild them from an instance, realize
them before export: `make_collision()` walks `sc.objects` and an instance is an EMPTY, so all
eleven would ship with **zero colliders** — invulnerable, bulletproof, non-blocking, no error.

---

## 1. What shipped

| commit | what |
|---|---|
| `aba5ca53` | 11 hooches placed, 78 stranded marker types → 0, anim library 216 → 232 clips |
| `c907cb04` | exporter `NameError`; `door_` → `COL_NONE` |
| `1c517cf8` | first firebase export since 07-26 |
| `82c3a0b0` | UTF-8 BOM stripped from 23 enemy `.tres` + 1 `.json` |
| `fbc2877d` | six hooch defects: trapped inside, staggered roof, double beds, no sandbags |
| `918c64d0` | sandbags flush; one was 10 m adrift |
| `a98ab41b` | back-ported every fix into `hooch_workbench.blend` |
| `000f966b` | hooch roofs were walkable navmesh |
| `19b2bed0` | per-face roof cull for monolithic structures |
| `5a3f2e6b` | nine more defects found by playing it |

**Marker types are registered.** `site_planner.gd` `FSB_WORK_OCCUPATION` gained `bunker`→sentry
(37 fire points that seated nobody), all `med_*` (staff→medic, `med_cot`/`med_or_patient`→
**patient** — mapping a casualty to medic stands him up and walks him round his own ward), the
`hooch_*` family, `cook_range`, `traycollector`, `trayhandoff`. `work_trayreturn` was renamed to
the `work_chow_tray_return` the code had been looking for since 08-07.

**`gun` (24), `mortar_*` (6) and `med_root` stay unmapped ON PURPOSE.**

---

## 2. OPEN — in the order I would take them

### 2a. The Chinook strands its passengers — **highest value, fully diagnosed**
`scenes/vehicles/chinook.tscn` contains **two nodes: `Chinook` and `Model`.** No `Door_Left`/
`Door_Right` (`heli_lift.gd:33-34`), and **no seat sockets at all.** So
`seat_system.gd door_staging_pos()` falls through both branches to
`_vehicle.global_position + Vector3(EXIT_PUSH_M, 0, 0)` — the airframe's own ORIGIN, 2.5 m along
world X. Delivered men are unseated *inside the fuselage*, then fly away sitting.
A Huey never hits this because its gunner socket exists.
**Fix:** add sockets + door nodes to `chinook.tscn`, or give `door_staging_pos()` a
fuselage-bounds fallback instead of the origin. Art or code — Caleb's call.

### 2b. Roof spawns are NOT fully fixed
`fb_hootch_roof_` is now in `nav_baker.gd:445 NAV_IGNORE_PREFIXES`, and monolithic structures get
a per-face cull (`_cull_roof_faces`, roof = upward faces ≥1.9 m above that shape's own base;
`fb_tower` deliberately excluded — a tower is meant to be climbed). **But `[SPAWN-TRUTH]` reads
PHYSICS COLLIDERS, not the navmesh** — the boot log still showed
`top_hit=fb_hootch_roof_m2_461`. Spawn placement is a third fix, in spawn code.

### 2c. The invisible ladder
Four `ladder_bottom`/`ladder_top` EMPTY pairs at the towers, 7.4 m apart vertically
(−75.48, 4.17), (−42.74, −46.86), (70.60, 22.55), (−25.48, 55.84). **No ladder mesh exists
anywhere.** The climb works; there is nothing to see. Missing asset.

### 2d. Duckboard plank paths connecting the buildings — HIS ASK, not started
`fb_duckboard_toc` exists (3.39 × 9.14 × 0.13) and `fb_duckboard` is already in `COL_NONE`, so a
path lays down without becoming a nav obstacle. Deferred deliberately: it depends on the final
hooch positions, which only settled at the end of this session.

### 2e. Napalm is ~20% too big — HIS ASK, not started
His words: *"it comes off like a nuclear bomb."* He believes an earlier fix uncapped it.
**Find where the size actually comes from before scaling anything** — see
`godot-billboard-discards-node-scale` in memory: the explosion size ladder was inert once
already because the number being tuned was disconnected from the thing on screen.

### 2f. `fb_int_` gets a solid box while the nav bake skips it by name
`fb_int_` is in `NAV_IGNORE_PREFIXES` but NOT in `COL_NONE`, so every interior prop is solid to
physics and invisible to pathing — navmesh says walkable, physics says solid. That is the
stuck-NPC recipe. It affects the EXISTING firebase interiors, not just the hooches, so it was
left alone deliberately. **Caleb's call.**

### 2g. Not reproduced — do not "fix" without evidence
**Poker chairs measure 0 of 44 facing away from their table.** He reported it; the blend
disagrees. Look in game before changing anything.

---

## 3. Traps this session paid for — all the same disease

**Verify by IDENTITY, never by proximity or origin.** This cost three separate wrong answers:
- Testing object **origins** against hooch footprints reported a latrine and a parapet segment
  inside a hooch. Both were ~19 m and ~49 m away. The real intruders were different objects
  entirely, found only by testing **vertices**.
- Matching sandbags to their **nearest** hooch shoved `fb_sandbag_hooch_p0_06` **10.5 m** out of
  place: it is nearer hooch 5 than the hooch 6 it belongs to, so its offset was computed against
  walls 14.55 m away. Ownership now comes from the NAME.
- A 9 m proximity cluster split each 10.97 m hooch into two groups and produced a 21-cluster
  table that read as fact.

**Godot's glTF importer strips `.001` numbering from node names.** All eleven hooches carry
Blender duplicate suffixes, so `fb_hwall_m0.001`…`.010` collapse to ONE name in Godot. Anything
pairing parts by name collapses with them — the screen doors hung 1 instead of 11 until they were
paired by distance. The `-colonly` twins are safe (`{base}_{index:03d}`, unique scene-wide).

**`matrix_world` is STALE after `libraries.load` and for any collection unlinked from the scene.**
The appended hooch measured 3.84 × 1.80 until `view_layer.update()` — a fake defect. Later, roof
and layout moves written to the unlinked `HOOCH_NEW` reported success and changed nothing.

**Rotation may not live in `rotation_euler`.** The four `A_chair_*` are QUATERNION mode; writing
`rotation_euler` is a silent no-op that reports success. Facing is
`matrix_world @ local +Y`, verified against `A_radiochair` and the cots — a backrest-centroid
heuristic gave the exact opposite answer.

**Marker floor tests: only ONE method works.** Cast DOWN from the marker to the nearest surface.
Casting from 30 m up hits every roof (144 false "buried"); measuring against terrain flags
everyone standing on a building floor (38 false "floating"); "nearest prop by origin" adds 18 more.

**Duplicating an already-parented assembly compounds `matrix_parent_inverse`** — the helmet cover
flew 0.8 m into the air. Copy as unparented siblings sharing one delta.

**Open a different blend with a `bpy.app.timers`-deferred call, never inline.** Save first, defer,
return from the handler, reprobe on the NEXT call. Inline `wm.open_mainfile` crashed Blender on
08-05. The deferred form worked cleanly four times today.

**A long export overruns the MCP reply.** The final export returned "No data received" while
Blender was alive and the GLB was written correctly. **Check the file and the process before
concluding anything failed.**

---

## 4. The lesson worth keeping

**Every defect in §1's later commits passed its contract check.** The GLB verified clean — 468
soft colliders, 0 door colliders, 209 markers, 0 manifest gaps — and the building was unusable:
you could not get out of it, the roof had a gap, there were two rows of beds, and the walls were
white. The gates verify WIRING. They do not verify that a man can live in the thing.

Three of the nine defects in `5a3f2e6b` were caused by earlier fixes in this same session.
The burial fix floated every hooch; the aisle fix stranded the radio markers so the music played
from empty floor; the sandbags were deleted on append as junk because they were parked off-site.

**Nothing substitutes for him walking it.**

---

## 5. Verification quick-reference

Boot and read three lines (`site_planner.gd:1377`, `:1538`, `:1576`):
```
[FSB] ballistic tags: 445 soft, 2045 hard
[FSB] parapet: 80 destructible segment(s) on the blast bus     <- absent must be 0
[FSB] structures on the blast bus: 11 bunker, 9 sandbag_stack, 4 tower, 4 bunker_mg
[FSB] screen doors: 11 hung                                    <- one per hooch
```
GLB gates, all passing as of `5a3f2e6b`: 14 skins / 13 animations (armatures export — no T-pose),
12 trimesh bunker-step colliders, 0 `door_*` colliders, 110 sandbags, 0 Icospheres,
209 `work_hooch` markers, 0 manifest segments absent.

---

# 6. THE OVERNIGHT PLAN — 20 steps

**Ordered so the riskiest, highest-value work happens while there is still budget to undo it,
and so nothing later depends on a step that has not been verified.**

**STANDING RULES FOR THE NIGHT**
- **Never run headless against a blend Caleb has open.** Check `bpy.data.filepath` and
  `is_dirty` first; if his Blender holds the file, work in the LIVE window over MCP.
- **Never `wm.open_mainfile` inline** — save, `bpy.app.timers.register`, return, reprobe.
- **Commit after every step that changes a tracked file.** A night's work in one commit is
  unreviewable and unrevertable.
- **A step is DONE when its gate passes, not when the edit lands.** Gates are stated per step.
- **If a step is blocked, SKIP IT and continue** — record why. Do not improvise around a
  blocker at 3am; that is how the sandbags got deleted.
- **Do not touch** `scripts/ui/`, `cursors.json`, `game_manager.gd`, `screen_door.gd` audio, or
  anything under `production/war_room/analysis/` — another session owns those.

### Phase A — finish what is diagnosed (1–6)
1. **Chinook sockets.** Add `seat_*` sockets + `Door_Left`/`Door_Right` to `chinook.tscn`, OR
   give `seat_system.gd door_staging_pos()` a fuselage-bounds fallback. **Gate:** a demo run
   logs delivered men leaving the ship; no man remains parented to the airframe after `_deliver`.
2. **Roof spawn placement.** `[SPAWN-TRUTH]` reads physics, not navmesh. Make spawn placement
   reject a hit whose collider name starts with a roof prefix and re-probe downward.
   **Gate:** boot logs no `top_hit=fb_hootch_roof_*`.
3. **`fb_int_` collider/nav mismatch (§2f).** Decide ONE way and make both agree: either add
   `fb_int_` to `COL_NONE` (no collider, matches the nav skip) or remove it from
   `NAV_IGNORE_PREFIXES`. **Gate:** no prop is both solid to physics and invisible to pathing.
4. **Napalm −20%.** FIRST find where the on-screen size actually comes from — see
   `godot-billboard-discards-node-scale`. **Gate:** measured radius on screen drops ~20%, and
   the number you changed is provably the one that drives it.
5. **`fb_sbg_seg_046.001`** exists in the scene but not in the manifest, so it ships as an
   indestructible parapet piece. Remove it or add it. **Gate:** scene segment count == manifest count.
6. **Re-export + full gate sweep.** **Gate:** the four `[FSB]` lines, plus 0 manifest absent,
   0 `door_*` colliders, 14+ skins.

### Phase B — the things he asked for (7–10)
7. **Duckboard paths.** Lay `fb_duckboard_toc` runs connecting: pad → TOC, TOC → mess,
   mess → hooch row, hooch row → aid station, aid station → latrines. Follow the ground; do not
   bridge gaps. **Gate:** every run sits ≤0.05 m off terrain along its length.
8. **Duckboards must not become obstacles.** They are already `COL_NONE`; confirm after export.
   **Gate:** 0 duckboard colliders in the GLB.
9. **Ladder mesh** at the four tower `ladder_bottom`/`ladder_top` pairs (7.4 m rungs).
   **Gate:** a mesh spans each pair; `[FSB]` ladder warning gone.
10. **Re-export + gate sweep.**

### Phase C — the debt that will bite next (11–15)
11. **Rebuild `HOOCH_NEW` from the corrected `hooch_workbench.blend`.** Its current state is
    UNVERIFIED — moves were written while it was unlinked and never confirmed.
    **Gate:** master matches a placed hooch part-for-part.
12. **4 actions still do not export** from `anim_library.blend` (236 actions → 232 clips). Find
    which and why. **Gate:** blend action count == GLB clip count, or each gap is explained.
13. **`tools/export_anim_library.bat` points at a path that does not exist**
    (`art_source/characters/base_psx/anim_library.blend`). Fix or delete it — a launcher that
    cannot run is a fossil.
14. **Add a playable-space gate to the export**: fail when an enclosed structure has <1.9 m
    clear headroom through its entrance, or its floor sits below the ground it covers. Both of
    today's worst defects would have failed it before the game ever loaded.
15. **Add a duplicate-name gate**: warn when two exported nodes collapse to the same name after
    `.001` stripping. That bug hung 1 door instead of 11.

### Phase D — verification, not building (16–20)
16. **Boot and read the four `[FSB]` lines.** Record them in this file.
17. **Walk one hooch end to end** (headless probe or scripted actor): in the door, down the
    aisle, onto a bunk, out the far side. **Gate:** no blocked segment.
18. **Confirm the medics are posed, not T-posed** — 14 skins shipped but that is not proof they
    play. **Gate:** a screenshot or a bone-transform read showing non-rest pose in game.
19. **Confirm bunker entry** now the steps are trimesh. **Gate:** an agent paths from outside to
    a `work_bunker` marker inside.
20. **Write the morning report**: what passed, what failed, what was skipped and why.
    **Every unverified claim marked as unverified.** Update this handoff and Claude memory.

**DO NOT ATTEMPT OVERNIGHT:** anything needing his judgement — the poker chairs (§2g, does not
reproduce), the `fb_int_` ruling if it turns out to change existing firebase interiors visibly,
or re-placing the hooch row. Leave those in the morning report as questions.
