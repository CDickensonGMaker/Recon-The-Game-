# Technical Director / Lead Programmer — Worldgen Wave 1

Read-only investigation. Headless probe written, run, and deleted (fossil law).
Godot 4.7.stable. All findings from reading code + running an import-material probe
and viewing the actual texture files.

---

## QUESTION 1 — THATCH TEXTURE BUG

### The premise is wrong. This is NOT a Godot import bug.

I loaded each imported hut scene headless, walked every `MeshInstance3D`, and printed
each surface's material + albedo texture. Result for the four huts named in the brief:

| GLB | surfaces | material class | albedo_texture | color | material name |
|-----|----------|----------------|----------------|-------|---------------|
| thatched_hut.glb   | 1 (`ThatchedHut`)  | StandardMaterial3D | **NOT null** → `…/thatched_hut_tmp7yog7qh4.jpg` 1024×1024 | (1,1,1,1) | `beige_wall_001.005` |
| stilt_house.glb    | 1 (`StiltHouse`)   | StandardMaterial3D | `…/stilt_house_tmpx8fkqef8.jpg` 1024×1024 | (1,1,1,1) | `wood_planks_grey.006` |
| three_room_house.glb | 1              | StandardMaterial3D | `…/three_room_house_tmp7yog7qh4.jpg` 1024×1024 | (1,1,1,1) | `beige_wall_001.004` |
| rice_storage.glb   | 1                  | StandardMaterial3D | `…/rice_storage_tmpx8fkqef8.jpg` 1024×1024 | (1,1,1,1) | `wood_planks_grey.005` |

The albedo texture is **present and resolves to a real 1024×1024 image**. Godot's
`gltf/embedded_image_handling=1` (Extract) is working perfectly — it links the external
sibling texture the GLB points at. (pagoda.glb / village_pagoda.glb are pure vertex-color
models — every material has `albedo_tex=null` by design; they are fine.)

### What's actually wrong — I opened the texture files

- `thatched_hut_tmp7yog7qh4.jpg` (33 KB, the **currently linked** albedo) = a **flat taupe
  plaster wall swatch.** No thatch, no wood, no spatial detail — a near-solid color. That is
  why the hut renders as a uniform beige blob: its one and only material is a flat wall color.
- `thatched_hut_tmpcz_ih86y.jpg` (727 KB, dated **May 13**, **orphaned / unreferenced**) = the
  **real thatch-roof albedo** — a gorgeous straw/reed texture. It sits right beside the GLB and
  nothing points at it.
- `thatched_hut_tmpwqkmdcrs.png` / `tmpj37yy6_u.png` (May 13 orphans) = the thatch normal /
  roughness maps (and a magenta placeholder). Also unreferenced.

**Timeline:** the May-13 tmp set (thatch atlas + maps) is from an earlier export that HAD thatch.
The Jul-8/Jul-9 tmp set (`tmp7yog7qh4`, `tmpswkvrx0d`) is a **re-export that regressed the
material to a flat "beige_wall" swatch.** The current `thatched_hut.glb` (Jul 9) references the
Jul-8 flat-beige file. The good thatch texture was dropped on that last Blender export.

**Note on the file coupling:** the linked `resource_path` is the *loose sibling* `_tmp*.jpg`,
NOT a path under `.godot/imported/`. That means these GLBs reference their textures by **external
URI** — they are NOT self-contained. The loose `_tmp` files are load-bearing; do not delete them.

### Root cause (one line)
Each hut GLB is a **single mesh / single StandardMaterial3D** whose sole albedo is a flat
solid-color wall swatch. The thatch atlas that used to be assigned was orphaned in the last
Blender re-export. Godot import is blameless.

### The fix, and what does NOT work

- ❌ **Candidate (a) — change `gltf/embedded_image_handling` to 2/3 (Embed) or flip
  `materials/extract`, then `--headless --import`. THIS IS A RED HERRING.** Those params only
  change *how* Godot handles whatever image the GLB points at. The GLB points at the wrong image.
  Re-importing links the same flat-beige swatch. Do not touch import params — it wastes a wave.

- ✅ **Correct, durable fix — Blender re-export (Caleb's chair, our staging).** Reassign the
  thatch material to the roof and, critically, **split the mesh into ≥2 surfaces (roof vs
  walls/posts)** so roof=thatch, walls=bamboo/wood, each a nameable material. Today every hut is
  ONE combined surface, so any single texture tiles over the entire building. The real thatch
  atlas (`*_tmpcz_ih86y.jpg` + its normal `*_tmpwqkmdcrs.png`) already exists on disk to plug in.
  Re-export self-contained GLBs (embed textures) so we stop depending on loose `_tmp` files.

- 🩹 **Cheap Godot-only stopgap (band-aid, not a fix) — if a same-day improvement is wanted
  without Blender:** author a per-hut surface-override `StandardMaterial3D` (small `.tres`) whose
  `albedo_texture` = the orphan thatch jpg, and apply it in `place_structure`. Because the hut is
  a single combined surface, thatch would tile over the walls too — better than flat beige, still
  wrong. Not recommended over the real fix unless the playtest is tonight.

**Recommendation: bead the Blender re-export (split surfaces + reassign thatch + embed textures).
Do NOT edit `.glb.import`. The import is not the bug.**

---

## QUESTION 2 — FLATTEN FEASIBILITY

### Trace

1. `SitePlanner.clear_and_flatten(center, radius)` — `site_planner.gd:91`
   → `ClearingSystem.create_zone` + `ClearingSystem.set_zone_stage(id, CLEARED)`.

2. `ClearingSystem.set_zone_stage` → `_apply_stage_changes` — `clearing_system.gd:122,135`.
   CLEARED stage has `height_flattening = 0.7` (`STAGE_PARAMS`, line 40-44). Since flattening
   > 0, it computes the **mean heightmap value inside the zone** and builds a lerp-to-mean
   modifier, then calls `terrain_manager.modify_terrain(zone.center, zone.radius, flatten_func)`
   (line 173). **So it DOES level the heightmap — it is not merely a veg mask.**

3. `TerrainManager.modify_terrain` — `terrain_manager.gd:320`
   → `heightmap.modify_region(...)` (`heightmap_storage.gd:134`, real heightmap edit)
   → **`_rebuild_chunks_in_region(affected)`** (line 326) → `_rebuild_chunk_immediate` per
   overlapping chunk (line 350), which unloads + reloads each chunk mesh from the heightmap.
   **The rendered terrain IS rebuilt.** This path is battle-tested — every firebase, AA site,
   outpost, temple and LZ already flattens through it.

   Wiring precondition: `ClearingSystem.set_terrain_manager()` is called at
   `scripts/levels/game_world.gd:144`, so the autoload is live in the real game. (If unset,
   `_apply_stage_changes` push_warns and no-ops — a wiring-order risk, not a missing feature.)

4. **Contrast — raw heightmap edits do NOT refresh the mesh.**
   `LocationPlanner.apply_lifts` (`location_planner.gd:115`) calls `heightmap.set_cell` directly
   and never touches `modify_terrain`. In `tests/test_world_alive.gd:75` `apply_lifts` is
   followed by water regen + gameplay-grid rebuild but **NO terrain chunk rebuild** — so that
   lift is invisible on the rendered terrain (it only affects height sampling / water / grid).
   Lesson: you must go through `modify_terrain` (or otherwise rebuild chunks); a bare `set_cell`
   is silent on the mesh.

5. **`stamp_village` does NOT flatten.** `site_planner.gd:185` — firebase (line 237), aa_site
   (303), outpost (322), temple (340), lz (356) all call `clear_and_flatten`; **village does
   not.** Huts snap individually to `_terrain.get_height_at(pos)` (place_structure line 160-161),
   so on a slope each hut sits at its own ground height and neighbors stagger / tilt.

### VERDICT — CHEAP. The path already exists.

Flattening a village footprint is a **one-line add**, not a balloon. The exact leveling+rebuild
pipeline firebases use is already there. Add to the top of `stamp_village()` (mirroring
`stamp_firebase` line 237):

```gdscript
clear_and_flatten(center, SiteLayouts.VILLAGE_RING_RADIUS_MAX + 8.0)   # ≈ 26 m
```

(`VILLAGE_RING_RADIUS_MAX = 18.0`, `site_layouts.gd:76` — matches the site's own radius field.)
It must run **before** the hut loop so `place_structure`'s per-hut `get_height_at` samples the
newly-leveled ground. Functions in play, all existing:
`SitePlanner.clear_and_flatten` → `ClearingSystem.set_zone_stage(CLEARED)` →
`ClearingSystem._apply_stage_changes` → `TerrainManager.modify_terrain` →
`TerrainManager._rebuild_chunks_in_region`.

No new heightmap-leveling op, no new rebuild plumbing.

### What is sacrificed (no free lunch)

- **`clear_and_flatten` is a bundle.** It also (a) sets a clearing MASK, (b) removes vegetation
  across the radius (`_veg.clear_area`), (c) swaps the ground color to exposed dirt. For a village
  that's arguably *correct* (villages are clearings), but be explicit: the whole footprint becomes
  a cleared dirt disc with concealment vegetation stripped and the sight-cap behavior changed
  inside it. If you want leveling *without* the veg-clear/dirt, that's a NEW lighter op = the
  balloon; don't build it this wave.
- **It's a 70 %-strength lerp to the mean, not a perfect plane.** On steep ground huts may still
  tilt slightly — firebases accept this; fine for villages.
- **Gen-time cost, not per-frame.** Each call synchronously rebuilds every chunk overlapping the
  radius. 8-10 villages = 8-10 multi-chunk rebuilds at worldgen. Firebase already does several;
  acceptable, but it is not literally free at generation time.

**Minimal-if-you-want-less:** if the council decides the full dirt-disc is too much for a living
village, the cheapest partial is to call only the veg-clear + mask half (skip flattening) so the
footprint *reads* as a clearing — but the actual "huts sit level" win needs the flatten, which is
already cheap. Recommend just calling `clear_and_flatten` and accepting the dirt disc.
