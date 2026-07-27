# Firebase interiors — what to wire up in the game

**Date:** 2026-07-26 · **Status:** props built in Blender, NOT exported, NOT wired.
Every code claim below carries a `file:line`. Where I could not verify a consumer I say so
rather than assert it.

The art side is done: `tools/gen_fb_interior.py` builds 21 US interior props, 1,620 tris,
average 77. The furnishing *system* already exists and works. What is missing is (a) the
assets on disk, (b) a US prop pool, (c) three code changes, and (d) a consumer for the
firebase's work stations.

---

## 0. The state of play

| piece | exists? | where |
|---|---|---|
| marker→furniture placer | **yes** | `site_planner.gd:524-538` `_furnish_interior()` |
| marker→work-station collector | **yes** | `site_planner.gd:555-566` `_collect_stations()` |
| marker finder (name-prefix, any Node3D) | **yes** | `site_planner.gd:543-552` `_find_markers()` |
| the work markers on the firebase | **yes, in Blender** | `firebase/kit/firebase_v3.1.blend` |
| 21 US interior props | **yes, in Blender** | `tools/gen_fb_interior.py` |
| US prop pool constant | **NO** | `site_layouts.gd:94-103` is village-only |
| firebase calls the furnisher | **NO** | `place_firebase_main()` never does |
| `prop_class` survives export | **NO** | see §3 |

---

## 1. Export the props (blocked on Caleb approving the look)

Target: `res://assets/us/props/interior/<name>.glb`, one file per prop, glTF binary,
+Y up, Apply Modifiers on, Cameras/Lights off, Compression off.

The 21 props and the `prop_class` each answers:

| class | props |
|---|---|
| `furniture` | fb_field_desk · fb_folding_table · fb_ammo_crate_stack |
| `seat` | fb_field_chair · fb_bench · fb_ammo_crate_stack |
| `sleep` | fb_cot |
| `radio` | fb_radio_prc25 · fb_radio_shelf · fb_field_phone |
| `plot` | fb_plotting_board · fb_map_board |
| `storage` | fb_footlocker · fb_c_ration_case · fb_jerry_can · fb_water_can |
| `storage_low` | fb_c_ration_case · fb_ammo_crate_stack |
| `cook` | fb_field_range · fb_mermite |
| `wash` | fb_wash_drum |
| `medic` | fb_litter · fb_medical_chest |
| `light` | fb_hanging_bulb |

**`fb_hanging_bulb` is the one prop whose origin is NOT on Z=0** — it hangs, so its origin is
the overhead attach point. Its marker goes on the ceiling, and `place_prop_at` (not
`place_prop`) must be used or it gets snapped to the floor — the same trap
`site_planner.gd:532-533` already documents for stilt-deck mats.

---

## 2. Add the US pool — `site_layouts.gd`

`INTERIOR_PROPS` (`site_layouts.gd:94-103`) maps every class to a Vietnamese market asset out
of `VILLAGE_PROP_DIR` (`:75`). A `prop_radio` marker in a TOC resolves to nothing today.

```gdscript
const US_PROP_DIR: String = "res://assets/us/props/interior/"
const US_INTERIOR_PROPS: Dictionary = {
    "furniture":   ["fb_field_desk", "fb_folding_table", "fb_ammo_crate_stack"],
    "seat":        ["fb_field_chair", "fb_bench", "fb_ammo_crate_stack"],
    "sleep":       ["fb_cot"],
    "radio":       ["fb_radio_prc25", "fb_radio_shelf", "fb_field_phone"],
    "plot":        ["fb_plotting_board", "fb_map_board"],
    "storage":     ["fb_footlocker", "fb_c_ration_case", "fb_jerry_can", "fb_water_can"],
    "storage_low": ["fb_c_ration_case", "fb_ammo_crate_stack"],
    "cook":        ["fb_field_range", "fb_mermite"],
    "wash":        ["fb_wash_drum"],
    "medic":       ["fb_litter", "fb_medical_chest"],
    "light":       ["fb_hanging_bulb"],
}
```

## 3. Make `prop_class` survive export — `site_planner.gd:527`

The kit spec exports with **Custom Properties off**. `work_type` survives that because
`_collect_stations` falls back to the name after `work_` (`site_planner.gd:562-563`).
`prop_class` does **not** — it is read only via `get_meta`, so with extras off every prop
marker exports classless and furnishes nothing.

Give the two readers the same behaviour rather than turning extras on for one of them:

```gdscript
# was: var pclass: String = str(m.get_meta("prop_class", ""))
var pclass: String = str(m.get_meta("prop_class", _class_from_name(m.name, "prop_")))
```

with a shared helper that strips the prefix and any Blender `.001` / glTF `_001` suffix.
`_collect_stations` should use the same helper so there is one rule, not two.

**Blender-side consequence:** markers must be named `prop_<class>` — `prop_radio`,
`prop_cook`, `prop_sleep`. The v3.1 scene currently carries `prop_bunk`, `prop_cot` and
`prop_map`, which are *object* names, not classes. Those three need renaming to
`prop_sleep`, `prop_sleep`, `prop_plot` — or the helper needs an alias table. **Renaming in
Blender is the cleaner half.**

## 4. Call the furnisher for the firebase — `site_planner.gd:798-836`

`place_firebase_main()` instantiates the GLB and returns, and never calls
`_furnish_interior()` or `_collect_stations()`. Only `stamp_village` does
(`site_planner.gd:299-300`). So the the work markers do nothing today.

Two edits:

1. `_furnish_interior(building, rng)` takes the pool and dir as arguments instead of
   hardcoding the village ones, so there is **one** furnishing path, not a second parallel
   copy for the US side (ADR-023 — the divergent-systems hazard is exactly this).
2. In `place_firebase_main`, after `root.global_position = origin`:

```gdscript
var stations: Array = []
_collect_stations(root, stations)
var furnished := _furnish_interior(root, rng,
    SiteLayouts.US_INTERIOR_PROPS, SiteLayouts.US_PROP_DIR)
nodes.append_array(furnished)
```

and add `"work_stations": stations` to the returned `site` dictionary (`:832-834`) so it
matches the shape `stamp_village` already returns (`:313`).

**`place_firebase_main(center)` has no `rng` parameter.** It needs one, and per ADR-010 it
must be seeded from position + op seed, never `Time` — otherwise a re-stamp of the same seed
furnishes differently and breaks the re-stamp contract that `clear_and_flatten` is careful
about (`site_planner.gd:110-113`).

## 5. RESOLVED — `work_stations` is the WRONG bus for the firebase, and §1–4 are the wrong fix

Traced 2026-07-26. `work_stations` is read by **`CampDirector`** (`camp_director.gd:32,68,
134-143`) — the **enemy/VC camp** director. Nothing on a `firebase_main` site consumes it.
Wiring `_collect_stations` into `place_firebase_main` would have produced a dictionary key
that no code reads: a textbook fossil.

The US garrison is a **separate, already-working pipeline**:

```
fsb_garrison_plan()            site_planner.gd:733   marker key -> {pos, occupation, men}
  -> _build_firebase_garrison  mission_generator.gd:748-777
     -> Civilian.spawn(... GARRISON_MEN)  with occupation + working_point_pos + home
     -> gun_crew posts also spawn a mannable M60 via _place_firebase_mg
```

`Civilian` runs US garrison mode off the same schedule machinery as village civilians
(`civilian.gd:50-52`), driven by `CivilianSchedulesS.action_for(occupation, hour)`.

**So the correct wiring was to feed the 251 `work_*` markers into THAT pipeline** — which is
what shipped (§8). §1–4 stay unbuilt on purpose:

- **§2 US prop pool** — not added. The 73 interior props are baked into the GLB; a pool
  constant with no caller is UNFINISHED code, not progress. Build it when something furnishes
  US structures at runtime.
- **§3 `prop_class` name fallback** — not needed while nothing furnishes the firebase.
- **§4 call `_furnish_interior`** — deliberately NOT called. It would double every baked prop.

## 8. WIRED 2026-07-26 — the work markers now populate the garrison

`site_planner.gd`:

- `_ensure_fsb_markers()` now also walks the GLB for the **`work_` name prefix** and caches
  `[pos, work_type]`, stripping Blender's `.001` / glTF `_001` duplicate suffix. Sorted by
  position so the sample is stable.
- `FSB_WORK_OCCUPATION` maps work_type to the **seven occupations the schedule machinery
  already knows**. An unmapped type becomes `off_duty` rather than inventing a schedule.
  `gun`/`mortar` deliberately do **not** map to `gun_crew`: `_place_firebase_mg` spawns a
  mannable M60 per gun_crew post, and 20 of those is not a firebase.
- `FSB_WORK_POST_CAP = 12`. ~250 markers at one man each is a crowd the frame cannot pay for.
  Sampled by a deterministic **stride**, never randomly (ADR-010: same seed, same base).
- `fsb_garrison_plan()` appends those capped posts after the 13 curated ones, alternating
  `sentry` / `sentry_night` so the wire is not empty after dark.

Net garrison: **~17 men (curated) + 12 (work markers) ≈ 29**, standing at the mess line, the
wash drums, the ammo niches and the radios instead of only the thirteen original posts.
`FSB_WORK_POST_CAP` is the one dial if that reads as too many or too few.

**Nothing has been run.** No suite, no editor, no playtest.

---

## 6. SHIPPED 2026-07-26 — v3 is now the live firebase

Done, not pending:

- `fsb_main_v3.glb` exported and `FSB_MAIN_PATH` repointed. **Verified by reading the GLB back
off disk, not from the export log:** 323 mesh nodes · 340 markers, of which **191 `work_*`**,
86 `prop_*`, 24 `door_main` and **16/16 garrison keys** · **73 interior prop instances baked
in** (cot ×15, ammo crate ×14, bulb ×10, water can ×9, C-rat ×7, footlocker ×5, chair ×3,
medical chest ×2, and one each of bench, field phone, field range, folding table, jerry can,
map board, mermite, radio shelf).
- v1 `fsb_main.glb` + its 19 loose textures moved to `firebase/_archive_v1/` behind a
  **`.gdignore`**, so Godot skips the directory entirely and cannot import a second firebase.
  `tools/export_fsb_main.py` (the v1 pipeline) went with it as `.py.v1`.
- `FSB_HALF` re-measured **82.2 × 77.3 → 149.3 × 111.2** (half-extents from the ORIGIN — the
  authored treeline reaches further on +x than −x, and `_fsb_rect` is built centred).
- `FSB_CLEAR_DISCS` five 58 m discs → **one 140 m disc**, because v3 authors its own treeline
  out to ~149 m and clearing to only ~100 m would grow procedural jungle through it.
- `test_asset_probe.gd` path + expected band (largest dim is now 271.9 m, band 250–300).
- `diag_fsb_gate_tower/clusters/model.gd` hardcoded paths → `SitePlanner.FSB_MAIN_PATH`.
- Zero surviving references to the v1 path anywhere in `.gd`/`.py`/`.tscn`.

### The near-miss worth recording

The first export was **complete and would have shipped a firebase with no garrison at all.**
`FSB_MARKER_KEYS` (`site_planner.gd:674-682`) looks markers up **by exact string** —
`SOCKET_A_001`, `GUN_POINT_001`, `FOOTPRINT_003`, `APPROACH_002` and so on — and
`FSB_GARRISON_POSTS` (`:687-701`) maps those 13 names to sentries, gun crew, quartermasters,
radioman and off-duty men. `:685-686` states the contract plainly: *"a post whose marker is
absent from the GLB is SKIPPED, never relocated to the compound center."*

v3's markers were named `SOCKET_A`, `work_gun`, `work_mg` — no `_001`, and the NPC pass had
**renamed `GUN_POINT` to `work_gun` and `mg_fire_point` to `work_mg`**. Every post would have
silently found nothing. `gen_firebase_v3.legacy_garrison_markers()` now emits all 16 names
verbatim and reports any it cannot place; it printed 16/16.

**FOOTPRINT_\* are not the ground-contact ring the v1 comment called them** —
`FSB_GARRISON_QUARTERS` (`:705-707`) uses them as *where off-shift men sleep*, so v3 puts them
on hootches and the TOC.

## 7. COLLISION + LADDERS — done 2026-07-26

**Collision.** The first three exports shipped **zero** collision and the player would have
fallen through the whole base. `gen_firebase_v3.make_collision()` now emits a `-colonly` twin
per solid object, and `export_firebase()` generates → exports → strips them, so the .blend
never carries them (they would drift the moment anything moved).

- **365 twins: 52 trimesh, 313 box, 65 left passable.** Trimesh for anything with a doorway,
  a pit or a walkable surface — a box would seal the bunkers shut and flatten the cratered
  mound. Alpha cards, mud patches, scorch, roads and duckboards stay walk-through.
- Cost: **+0.38 MB**. Trimesh twins share the source mesh datablock, so glTF writes it once.
- **The naming trap:** Godot only builds collision from nodes whose name ENDS with
  `-colonly`. Blender appends its `.001` duplicate suffix AFTER the name, so
  `fb_hootch-colonly.001` exports as `fb_hootch-colonly_001` and silently imports as an
  invisible mesh with no collision. Every twin is numbered BEFORE the suffix instead.
- Verified by reading the GLB back off disk: 430 visual, 365 collision, **0 colonly nodes
  Godot would miss**.

**Ladders.** Ported from CatacombsOfGore rather than written fresh — `scripts/world/ladder.gd`
+ `is_climbing` in `player.gd` + the `is_seated`-style guard in `weapon_holder.gd`. Geometry
is marker-driven (`ladder_bottom*` / `ladder_top*`), built by
`Ladder.build_from_markers(root)` from `place_firebase_main` AFTER the root is seated.
**4 tower ladders, 7.40 m rise each.** Full architecture and the four constraints that make
it work: Claude memory `ladder-climb-architecture`.

**NEW `class_name Ladder` → Godot REIMPORT before the suite** (baselining hazard).

## 8. Still open

- Everything in §1–§5 above (US pool constant, `prop_class` name fallback, calling the
  furnisher, and the **unverified** work-station consumer).
- Interior props are currently **baked into the firebase GLB** (73 of them). If the runtime
  furnishing path in §4 is ever wired for the firebase, it must NOT also run here or every
  prop doubles.
- **Nothing has been run.** No suite, no editor, no playtest. `diag_fsb_seat` asserts the
  consts against the loaded GLB and is the right first check — Caleb runs it.

---

## Order of work

1. Caleb approves the prop look in Blender.
2. Export 21 GLBs + `-colonly` twins to `assets/us/props/interior/`.
3. Rename `prop_bunk`/`prop_cot`/`prop_map` to class names in the firebase scene.
4. `site_layouts.gd` — add `US_PROP_DIR` + `US_INTERIOR_PROPS`.
5. `site_planner.gd` — parameterise `_furnish_interior`, add the name fallback for
   `prop_class`, call both from `place_firebase_main`, add the `rng` parameter.
6. **Check §5 before believing any of it moves NPCs.**
7. Re-measure `FSB_HALF` / `FSB_CLEAR_DISCS` when v3 is exported as the live firebase.
