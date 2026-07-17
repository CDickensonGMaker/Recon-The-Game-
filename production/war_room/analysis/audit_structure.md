# AUDIT: File-Structure Drift & Dead Resources

**Scope:** post-restructure (615ddd0 "one asset tree, one folder per faction") audit of orphaned
resources, duplicates, stale paths, structural weirdness, and import state.
**Method:** full-tree walk (excl. `.git/`, `.godot/`, `.beads/`, `tools/tts/piper/`), reference index
built from every `.gd/.tscn/.tres/.py/.bat/.ps1/.json/.gdshader/project.godot`, matched on full
`res://` path, UID, basename, **and bare stem** (critical — see Dynamic-Load Ruling), plus md5
duplicate grouping and GLB binary-chunk inspection.
**Status:** AUDIT ONLY. Nothing deleted, nothing fixed.

---

## 0. HEADLINE — THE RESTRUCTURE SILENTLY DEFEATED `.gitignore`

This is the biggest finding and it is not on the original list.

`.gitignore` carries these rules, written specifically to keep ~90 MB derived character blends out
of git:

```
# Derived character blends - regenerated from the tracked truth source, ~90 MB each.
# Committing it would repeat the 165 MB blob mistake (RECONgame-t04t).
art_source/characters/base_psx/us_base_v3.blend
art_source/characters/lineup_review.blend
art_source/characters/variants/
art_source/characters/civilians/
art_source/characters/us_troops/
art_source/characters/enemies/
art_source/characters/locker/
assets/characters/source/renders/sprites/**/_frames/
```

**Every one of those paths is now dead.** `art_source/` was deleted by 615ddd0 and its contents moved
under `assets/`. The ignore rules still name the *old* paths, so they match nothing. The blends they
were protecting landed in `assets/` **unignored**, and the same commit committed them.

`git show --diff-filter=A 615ddd0 -- '*.blend'` — **17 blends newly ADDED to history, ~1.25 GB:**

| MB | file | previously ignored as |
|----|------|----------------------|
| 129 | `assets/us/characters/us_base_v3.blend` | `art_source/characters/base_psx/us_base_v3.blend` |
| 119 | `assets/reference/review/lineup_review.blend` | `art_source/characters/lineup_review.blend` |
| 90 ×9 | `assets/civilians/characters/civ_{farmer_m,farmer_m_b,farmer_m_c,farmer_f,farmer_f_b,farmer_f_c,elder,elder_b,kid,kid_b}.blend` | `art_source/characters/civilians/` |
| 68 | `assets/us/characters/satchel_m3.blend` | `art_source/characters/locker/` |
| 62 | `assets/us/characters/gear_armory.blend` | `art_source/characters/locker/` |
| 47 | `assets/civilians/characters/civ_anim_workbench.blend` | `art_source/characters/civilians/` |
| 17 | `assets/reference/review/civilians_all_lined_up.blend` | `art_source/characters/review/` |

`.git/` is now **4.84 GB**. 45 tracked `.blend` files total **2.14 GB** in the working tree.

The `.gitignore` comment explicitly says committing these "would repeat the 165 MB blob mistake
(RECONgame-t04t)". **It has now repeated it, at ~8× the scale, and nobody noticed** — because the
ignore rule didn't error, it just stopped matching.

This is unfixable by deletion alone: the blobs are in history. It requires either accepting the
bloat or a history rewrite (`git filter-repo`), plus rewriting `.gitignore` to the new `assets/`
paths. **Council decision required.**

---

## 1. ORPHANED RESOURCES

**Raw count: 913 of 1291 asset files (`.tscn/.tres/.glb/.png/.jpg/.webp/.wav/.ogg/.mp3/.gdshader/.obj/.fbx`)
have zero textual reference anywhere — 422.0 MB.**

That raw number is **misleading and must not be acted on**. Breakdown with the dynamic-load ruling
for each class:

### 1a. NOT ORPHANS — dynamically loaded (DO NOT DELETE)

These have zero grep hits and are fully load-bearing. This is the finding that prevents a disaster.

| Class | Loader | Ruling |
|-------|--------|--------|
| `assets/{us,nva_vc,civilians}/characters/*.glb` (~25 character models) | `scripts/visuals/model_actor.gd:29` `model_path(unit_id)` — searches 3 faction dirs for `<unit_id>.glb`; `all_units():41` **DirAccess-scans** those dirs | **ALIVE.** unit_ids are passed as *bare strings without `.glb`* — `squad_system.gd:75-78` (`us_grunt_m60`, `us_grunt_m79`, `us_rto`, `us_medic`), `civilian.gd:30-33` (10 `civ_*`), `insertion_ride.gd:61` (`us_pilot_white/black`), `data/enemies/*.tres` `sprite_unit` (`vc_guerilla*`), `ally_base.gd:186` (`us_grunt_v3`). A naive extension-based grep reports every one of these as an orphan. |
| `assets/audio/sfx/weapons/*.wav` (287 wavs) | `scripts/autoload/audio_manager.gd:19` `WPATH + "fire_<id>_1..3.wav"`, `mech_<id>`, `reload_<id>`, `bolt_<id>` — id from `WeaponData` | **ALIVE** for every id with a `data/weapons/*.tres`. No literal path exists anywhere. |
| `data/weapons/*.tres` (15) | `load("res://data/weapons/%s.tres" % id)` — `gun_range.gd:156`, `probe_ballistics.gd`, `test_ballistics.gd:26`; `viewmodel_editor.gd:110` **DirAccess.open("res://data/weapons")** | **ALIVE** |
| `data/enemies/*.tres` (5) | `enemy_base.gd:282` `load(enemy_data_path)`; `test_downed_enemy.gd:23` builds `"res://data/enemies/" + f` | **ALIVE** |
| `assets/textures/fx/blood/*.png` | `gun_fx.gd:331` `load("res://assets/textures/fx/blood/%s.png" % tex_name)` | **ALIVE** |
| `terrain/textures/billboards/*.png` | `billboard_vegetation.gd:105-126` `"tree%d_billboard.png" % i` (also bamboo/bush/rice) | **ALIVE** |
| `assets/world/vegetation/*.glb` | `gore_lab.gd:159` `load(VEG_DIR + variant + ".glb")`; `probe_vegetation.gd:19` | **ALIVE** |
| `assets/building models/structures/ruins/*` | `ruin_set_templates.json:3` `"pieces_dir"` → directory-scan consumption | **ALIVE** |
| `data/hitzones/*.tres` (dir currently empty) | `hitzone_builder.gd:115` `ResourceLoader.exists(tpath)`; `hitzone_editor.gd:501` `make_dir_recursive` | Empty dir is **load-bearing by name** — the editor writes into it. Deleting the folder is harmless (recreated) but it is not "junk". |

**Rule for the council: any deletion sweep that keys on "no grep hit" will delete the entire
character roster and the entire weapon audio bank.**

### 1b. REGENERABLE BYPRODUCT — 388 files, 254.4 MB (the bulk of the "orphans")

`assets/**/*.glb` are imported with `gltf/embedded_image_handling=1` (**Extract Textures**) — all 265
`.glb.import` files carry this. Godot extracts each embedded image to a sibling file named
`<glb_stem>_<gltf_image_name>.<ext>`.

**Proven, not assumed:**
- GLB binary-chunk inspection: every image in `us_grunt_v3.glb`, `vc_guerilla_ppsh.glb`,
  `civ_kid.glb` has `uri=None` + a `bufferView` → **embedded**, no external URI.
- md5 of each embedded image chunk == md5 of the sibling file, **byte-identical**, including
  mixed extensions matching the embedded mime types (`_cigs.webp`, `_insectrepl.jpg`,
  `_better textures.png`). Blender would not produce that mix; the importer would.
- The imported scene `.godot/imported/us_grunt_v3.glb-*.scn` contains **zero** `res://`,
  `ExtResource`, or `CompressedTexture` references → the runtime scene does not depend on them.

**Ruling:** dead weight at runtime, but **regenerated on next reimport**. Deleting them without
changing `embedded_image_handling` is futile — they come back. The correct action is `.gitignore`
(and/or change the import mode), not `rm`. **32 of them are tracked in git** (155 MB of sidecars
under `assets/*/characters/`).

Examples: `assets/us/characters/us_grunt_v3_better textures.png`, `*_face_atlas_v3.png`,
`*_usarmybitmap.png`, `*_gore_tex.png`, `*_cigs.webp`, `assets/player/viewmodels/*_fp_arms_gloves_01.png`,
`assets/building models/**/*_hessian_230_*.png`.

### 1c. TRUE ORPHANS — safe to delete

| Path | Files | Size | Evidence |
|------|-------|------|----------|
| `terrain/vegetation/textures/` | 36 png | **72 MB** | Zero references. No `.gd/.tscn/.tres/.gdshader` mentions `vegetation/textures`, `_apg_`, or `Plant alpha`. Loose vendor texture dump (`_palma_3_apg_.png`, `_plant_2a_apg_.png`, `1.png`…`5.png`). The live vegetation textures are `terrain/textures/billboards/` + `terrain/textures/clutter/`. |
| WW2 weapon audio: `assets/audio/sfx/weapons/{fire,mech,reload,bolt}_{kar98k,mp40}*.wav` | 13 | 1.4 MB | Loaded only by weapon id; **no `kar98k`/`mp40` `.tres` exists** in `data/weapons/`. Audio ids on disk with no weapon: `car15`, `kar98k`, `mp40`, `sks`, `thompson`. |
| 3 orphan `.uid` (source deleted) | 3 | ~60 B | `tmp_prop_check.gd.uid` (repo root), `assets/shaders/foliage_wind.gdshader.uid`, `scripts/visuals/foliage_wind.gd.uid` |

### 1d. NOT REFERENCED BUT REACHABLE — judgment call, not junk

- `assets/us/characters/us_grunt_m14.glb` (15.8 MB) and `assets/nva_vc/characters/vc_guerilla_m16.glb`
  (12.9 MB): **no data file names these unit_ids.** But `ModelActor.all_units()` DirAccess-enumerates
  them, so `tests/test_model_scale.gd`, `tools/probe_*.gd`, and `hitzone_editor.gd` all iterate them.
  Deleting them will not break the game; it *will* change test/tool enumeration. Unbuilt-content, not
  dead content.
- `assets/building models/` unused structure GLBs: many of the 127 GLBs are placed by
  `mission_generator.gd` / `site_planner.gd` / `SiteLayouts` — but not all. Individually auditing
  which of the 127 are placed is out of scope; the tree as a whole is **live** (see §4).

---

## 2. DUPLICATES

**~300 MB wasted across 30+ md5-identical groups.** Top offenders:

| Wasted | Copies | Each | Files |
|--------|--------|------|-------|
| **95.0 MB** | 12 | 8.63 MB | `*_better textures.png` — identical texture extracted once per GLB: all 6 `vc_guerilla_*` + `us_grunt_m60/m79/v2/v3`, `us_medic`, `us_rto` |
| **50.3 MB** | 2 | 50.3 MB | `assets/us/characters/gear_armory.blend` == `assets/us/props/gear_armory.blend` *(known)* |
| **28.2 MB** | 15 | 2.02 MB | `*_hessian_230_Metal-hessian_230_Rough.png` across `building models/structures/{airfield,firebase,ruins,infrastructure}` + `vehicles` |
| **26.3 MB** | 20 | 1.38 MB | `*_face_atlas_v3.png` — one per character GLB (source of truth: `assets/shared/textures/face_atlas_v3.png`) |
| **24.1 MB** | 13 | 2.00 MB | `assets/player/viewmodels/*_fp_arms_gloves_01.png` — same glove texture ×13 viewmodels |
| **14.2 MB** | 15 | 1.01 MB | `*_corrugated_iron_*` / shared structure textures |
| **11.5 MB** | 7 | 1.91 MB | `us_grunt_*_usarmybitmap.png` |

Note: nearly all of the above are **§1b extraction byproducts** — the duplication is a *symptom* of
`embedded_image_handling=1`, not 30 separate mistakes. Fixing the import mode collapses most of this.

### Near-duplicates by name (older version still shipping)

| File | Size | Note |
|------|------|------|
| `_backups/gear_armory_BROKEN_STATE.blend` | 218 MB | **TRACKED IN GIT.** A file literally named BROKEN_STATE. |
| `_backups/gear_armory_BEFORE_civsplit.blend` | 218 MB | **TRACKED IN GIT.** |
| `_backups/weapons_us_BEFORE_{handguard,m16_split,markers,sight_rebuild,sight_work}.blend` | 285 MB | Untracked (`??`). 5-deep manual undo lineage. |
| `_backups/blend1_autosaves/` | **1.55 GB** | 28 Blender `.blend1` autosaves. Gitignored (`*.blend1`), pure local disk cost. |
| `assets/us/characters/_archive/us_base_v3_DUPLICATE_from_us_troops.blend` | 90 MB | Tracked. Name says DUPLICATE. |
| `assets/us/characters/_archive/unit_us_{grunt,grunt_slim,medic}.blend` | 12 MB | Tracked. Old lineage. |
| `assets/us/characters/weapons_v1.blend` | 2 MB | v1 alongside live `weapons_us.blend` (71 MB). |
| `assets/nva_vc/characters/vc_guerilla_v2.blend` | 56 MB | v2 is the live one; no v1 present. OK. |
| `assets/building models/vehicles/USM4A3Sherman.obj` + `us_m4_sherman.glb` | — | Two files, one Sherman, **in a Vietnam game** (see §4). |

**`_backups/` totals 2.26 GB on disk; 436 MB of it is in git.**

---

## 3. STALE PATHS

**6 distinct missing `res://` targets across 9 reference sites. ZERO are LIVE FIRE** — every one is
either guarded, inert, or a comment. That is the reassuring half of this audit.

| # | Reference site | Missing target | Class | Why |
|---|---------------|----------------|-------|-----|
| 1 | `assets/world/vegetation/patches/patches.json:7` | `res://assets/models/vegetation/felled_tree.glb` | **LANDMINE** | Baked into the shipped manifest. No `.gd` reads the `model`/`trunk_model`/`stump_model` keys today, so it is inert — but the file it points at *exists at the new path* `assets/world/vegetation/felled_tree.glb`. The day someone wires `tree_ref.model`, it fails. |
| 2 | `assets/world/vegetation/patches/patches.json:8` | `…/felled_trunk.glb` | **LANDMINE** | same |
| 3 | `assets/world/vegetation/patches/patches.json:9` | `…/tree_stump.glb` | **LANDMINE** | same |
| 4 | `tools/make_jungle_patches.py:978-980` | same 3 paths | **LANDMINE** | *(known)* The generator that **writes** `patches.json`. Regenerating patches re-emits the dead paths. Fixing the JSON without fixing the tool is a no-op. |
| 5 | `terrain/vegetation/vegetation_manager.gd:204` | `res://terrain/vegetation/models/palm_tree.blend` | **DEAD FALLBACK** | Guarded by `_load_first_mesh()` → `ResourceLoader.exists()` → prints "Path not found" → falls back to `_create_procedural_tree()`. `terrain/vegetation/models/` **does not exist at all**. Game silently runs procedural trees and has done so forever. Not a break; *is* a silent quality regression worth a bead. |
| 6 | `terrain/vegetation/vegetation_manager.gd:216` | `res://terrain/vegetation/models/grass/grass_patch.fbx` | **DEAD FALLBACK** | same → `_create_procedural_grass()` |
| 7 | `tests/test_sprite_enemy.gd:7` | `res://data/enemies/german_rifleman.tres` | **DEAD CODE / silent test hole** | Guarded at line 83: `if not ResourceLoader.exists(GERMAN): print("(already deleted - skipping)"); return`. The test **self-skips `_test_capsule_fallback()` entirely** — an entire assertion block ("enemy has neither sprite nor capsule → invisible enemy") has silently not run since the WW2 data was removed. The suite is green because the check is absent, not because it passes. |
| 8 | `assets/building models/vehicles/USM4A3Sherman.obj.import` | `source_file="res://assets/models/us/vehicles/USM4A3Sherman.obj"` | **LANDMINE** | The `.obj` exists at the new path; the `.import` still records the old `assets/models/` source. Godot will silently rewrite it on next editor reimport, but right now the import metadata is inconsistent. |
| 9 | `.gitignore` (8 rules) | `art_source/**`, `assets/characters/source/renders/sprites/**` | **LIVE FIRE (repo, not game)** | See §0. These rules match nothing and 1.25 GB got committed as a result. This is the only "live fire" in the audit — it doesn't break the running game, it breaks the repository. |
| 10 | `scripts/enemies/enemy_base.gd:366` | comment: "*The moment `nva_regular.glb` lands in `assets/models/characters/`*" | **DEAD COMMENT** | Truth-law violation. `assets/models/` no longer exists; the correct dir is `assets/nva_vc/characters/`. |
| 11 | `scripts/enemies/enemy_base.gd:354` | comment: "*archived in Base Game Assets*" | **DEAD COMMENT** | No such location in this repo. |

**Summary: 0 LIVE FIRE (game) · 1 LIVE FIRE (repo/.gitignore) · 5 LANDMINE · 3 DEAD FALLBACK/DEAD CODE · 2 DEAD COMMENT.**

---

## 4. STRUCTURAL WEIRDNESS

### 4a. `assets/building models/` — the folder with a space. **DO NOT RENAME CASUALLY.**

The restructure ("one asset tree, one folder per faction") **missed this tree entirely.** It kept its
pre-restructure name, including the space, and it is **235 MB / 127 GLBs — the single largest live
asset tree in the project.**

It is **heavily load-bearing with hardcoded paths**:
- `scripts/missions/mission_generator.gd:328-330`
- `scripts/world/site_planner.gd:268,281` + `SiteLayouts.{VILLAGE_HUT,VILLAGE_CENTER,FIREBASE_EXTRA}_MODELS`
- `scripts/combat/punji_trap.gd:9`
- `scenes/vehicles/{huey,f4_phantom,skyraider}.tscn` (`ext_resource` paths)
- `assets/building models/structures/ruins/ruin_set_templates.json:3` (`pieces_dir`)

Meanwhile `assets/world/structures/` — the folder the restructure *intended* as the structure home —
contains exactly **2 files** (`emplacements_batch2.blend`, `ruins_batch1.blend`).

**This is the central drift artifact:** there are two structure trees, the *new//canonical* one is
nearly empty, and the *old/misnamed* one holds all the content and all the wiring. Renaming
`assets/building models/` requires a coordinated path rewrite across 6+ files. It is real work, not a
`mv`.

### 4b. WW2 leftovers (HellOfDuty origin)

| Item | Status |
|------|--------|
| `assets/building models/vehicles/USM4A3Sherman.obj` + `us_m4_sherman.glb` | A **Sherman tank** in a Vietnam game. Two files, same subject. The `.obj.import` also carries a stale `source_file` (§3 #8). |
| `assets/audio/sfx/weapons/*_{kar98k,mp40}*.wav` (13 files, 1.4 MB) | Orphan — no matching weapon `.tres`. |
| `tools/make_ww2_guns.py` | Builds `thompson`, `bar`, `kar98k`. None ship. Generator for dead content. |
| `scripts/visuals/sprite_state_map.gd:182` `"kar98k": "bolt"` | Harmless dead table entry. |
| `scripts/autoload/audio_manager.gd:148`, `scripts/combat/gun_fx.gd:69` | `n.contains("mp40")` in SMG classifier lists — harmless dead branch. |
| `tests/test_sprite_enemy.gd` `GERMAN` const | Self-skipping dead test (§3 #7). |
| `data/enemies/german_rifleman.tres` | Already deleted — only the guarded reference remains. |
| Sprite renderer generally | ADR-001 declares it dead, but `SpriteActor`/`SpriteLibrary`/`SpriteManifest`/`sprite_state_map` remain as the fallback path. `assets/reference/review/sprite_stage.blend` is the only sprite asset left. Intentional per ADR-001's fallback wording, but worth a council look. |

### 4c. Root junk

- `tmp_prop_check.gd.uid` — a `.uid` sidecar at the **repo root** whose `.gd` is gone. Pure junk.
- `tools/probe_drift_scale.gd`, `tools/probe_orphaned_art.gd` and ~8 other `probe_*.gd` — untracked/ad-hoc
  probes living in `tools/`. Acceptable (they're tools), but note the project already ships its own
  orphan probe (`tools/probe_orphaned_art.gd`) that evidently wasn't run before the restructure.
- Test/probe scenes are **correctly** segregated (`tests/`, `scenes/tools/hitzone_editor.tscn`). No
  probe scenes found polluting `scenes/levels/` (only `game_world`, `gore_lab`, `gun_range`). Clean.

### 4d. Empty folders (confirmed)

`addons/` · `assets/civilians/textures/` · `assets/nva_vc/props/` · `data/hitzones/` ·
`tools/tts/piper/pkgconfig/`

Caveat: **`data/hitzones/` is not junk** — `hitzone_editor.gd:501` `make_dir_recursive_absolute`s it
and writes tuning `.tres` into it; `hitzone_builder.gd:115` reads from it. It is empty because no
tuning has been saved, not because it is dead.

### 4e. Doc sprawl vs. ADR-014 (canon violation)

ADR-014 ("Documentation hierarchy: CANON / LOG / DEAD") states in its own header:

> **Supersedes/Amends:** ROADMAP_NEXT.md, ROADMAP_WAVE2.md, WAVE3_REPORT.md (as planning documents)

and defines LOG-tier docs as *"disposable snapshots… **never cited as authority**"*.

**All three superseded docs are still sitting at the repo root**, visually indistinguishable from
canon. Root holds **16 `.md` files**; `production/` holds another **20** plus `adr/` and `bible/`.

Worse — **`CLAUDE.md` itself contradicts ADR-014.** It says:

> **Read these before designing anything:** `DESIGN.md`, `STATE_OF_PROJECT.md`,
> `MISSION_DESIGN_RESEARCH.md`, `RECON_ADAPTATION.md`

…while ADR-014 puts canon at `production/GAME_GUIDE.md` + `production/adr/` and demotes the rest to
LOG. CLAUDE.md is injected into **every session**, so it is steering every agent at LOG-tier docs as
if they were law. CLAUDE.md's own damage table carries a warning that a stale CLAUDE.md
*"is not a wrong note — it is a **DRIFT GENERATOR**."* That warning currently applies to the file
containing it.

Root docs that ADR-014 classes as LOG/DEAD but which still sit at root:
`ROADMAP.md`, `ROADMAP_NEXT.md`, `ROADMAP_WAVE2.md`, `WAVE3_REPORT.md`, `NIGHTSHIFT_REPORT.md`,
`CODE_AUDIT.md`, `AUDIT_HANDOFF.md`, `COUNCIL_REVIEW.md`, `SPRITE_INTEGRATION_PLAN.md`
(the last describes the renderer ADR-001 killed).

---

## 5. IMPORT STATE — essentially clean

| Check | Result |
|-------|--------|
| Orphan `.import` (source file missing) | **0** |
| Orphan `.uid` (source file missing) | **3** — `tmp_prop_check.gd.uid`, `assets/shaders/foliage_wind.gdshader.uid`, `scripts/visuals/foliage_wind.gd.uid` |
| `.import` with `source_file=` pointing at a missing path | **1** — `assets/building models/vehicles/USM4A3Sherman.obj.import` → `res://assets/models/us/vehicles/USM4A3Sherman.obj` |
| **Duplicate / colliding UIDs** | **0** across **1459** tracked UIDs |
| Autoloads resolving | 12/12 *(confirmed)* |
| `ext_resource` paths resolving | 103/103 *(confirmed)* |

The restructure was executed carefully at the **UID** level — Godot's UID indirection absorbed the
moves and no scene or resource link broke. **The engine-facing side of the restructure is sound.**
The damage is entirely in (a) git/`.gitignore`, (b) hand-written string paths in `.py`/`.json`, and
(c) documentation.

---

## 6. WHAT IS SAFE TO DELETE vs WHAT ONLY LOOKS DEAD

### SAFE TO DELETE (high confidence)

| Item | Reclaims | Notes |
|------|----------|-------|
| `_backups/blend1_autosaves/` (28 files) | **1.55 GB** | Blender autosaves. Gitignored. Local disk only. |
| `_backups/weapons_us_BEFORE_*.blend` (5) | 285 MB | Untracked manual undo lineage. |
| `_backups/gear_armory_{BROKEN_STATE,BEFORE_civsplit}.blend` | 436 MB (disk) | **Tracked** — `git rm` removes from HEAD but not history. |
| `terrain/vegetation/textures/` (36 png) | **72 MB** | Zero references, confirmed. |
| WW2 audio `*_{kar98k,mp40}*.wav` (13) | 1.4 MB | No matching weapon `.tres`. |
| 3 orphan `.uid` + `tmp_prop_check.gd.uid` | ~0 | Pure junk. |
| `assets/us/props/gear_armory.blend` **or** `assets/us/characters/gear_armory.blend` (one of the two) | 50 MB | md5-identical. Keep one, decide which folder is canonical. |
| `assets/us/characters/_archive/` (4 blends incl. `*_DUPLICATE_*`) | ~102 MB | Self-labelled archive. |
| Empty dirs: `addons/`, `assets/civilians/textures/`, `assets/nva_vc/props/`, `tools/tts/piper/pkgconfig/` | 0 | Cosmetic. **Keep `data/hitzones/`** — the editor writes into it. |

### LOOKS DEAD — IS NOT. DO NOT DELETE.

1. **`assets/{us,nva_vc,civilians}/characters/*.glb`** — ~25 character models, zero grep hits.
   `ModelActor.model_path()` resolves them from **bare `unit_id` strings** and `all_units()`
   DirAccess-scans the folders. Deleting these deletes the entire cast: the squad (`us_grunt_m60`,
   `us_grunt_m79`, `us_rto`, `us_medic`), the aircrew, all 10 civilians, and every VC.
2. **`assets/audio/sfx/weapons/*.wav`** (287 files) — every weapon sound is composed at runtime as
   `"fire_" + weapon_id + "_1.wav"`. No literal path exists in the codebase. A grep-based sweep
   silences the entire game.
3. **`assets/building models/`** (235 MB, 127 GLBs) — the space in the folder name looks like drift.
   It is the **live, hardcoded, load-bearing** structure/vehicle/aircraft tree (mission_generator,
   site_planner, punji_trap, all three vehicle scenes). `assets/world/structures/` — the "correct"
   new home — has only 2 files. Renaming requires a coordinated 6-file path rewrite.
4. **`data/hitzones/`** (empty) — `hitzone_editor.gd` creates and writes into it by name.
5. **388 GLB sidecar textures (254 MB)** — genuinely unreferenced at runtime, but **`.gitignore`
   them, don't `rm` them**: `embedded_image_handling=1` makes Godot re-extract them on the next
   reimport. Deleting is futile until the import mode changes.
6. **`assets/us/characters/us_grunt_m14.glb`, `assets/nva_vc/characters/vc_guerilla_m16.glb`** —
   no data file names them, but `all_units()` enumerates them into tests and tools. Unbuilt content,
   not dead content.

### REQUIRES A DECISION, NOT A DELETION

- **§0 git bloat (1.25 GB in history, `.git` = 4.84 GB).** Deletion cannot fix history. Options:
  accept, or `git filter-repo`. **Either way `.gitignore` must be rewritten to `assets/` paths
  immediately, or the next blend export re-commits another gigabyte.**
- **`assets/building models/` rename** — the correct end-state per the restructure's own stated goal,
  but it is a code change across 6+ files, not a folder move.
- **Doc hierarchy** — ADR-014 already ruled; the ruling was never executed. Archiving
  `ROADMAP_NEXT/ROADMAP_WAVE2/WAVE3_REPORT` and correcting CLAUDE.md's "read these first" list is
  enforcement of existing canon, not a new decision.

---

## APPENDIX — hard counts

- Files scanned (excl. `.git`, `.godot`, `.beads`, piper): **~3,100**
- Asset files considered for orphan status: **1,291**
- Zero-reference after full stem/UID/path matching: **913 (422.0 MB)**
  - of which regenerable GLB sidecar byproducts: **388 (254.4 MB)**
  - of which true orphans: **~49 (73.4 MB)**
  - remainder: unplaced `building models` GLBs + misc, individually reachable
- md5-duplicate waste: **~300 MB** across 30+ groups
- `_backups/`: **2.26 GB** on disk (436 MB tracked)
- `.git/`: **4.84 GB**; tracked `.blend`: **45 files / 2.14 GB**
- Blends newly committed by 615ddd0: **17 / ~1.25 GB**
- Stale `res://` targets: **6 distinct / 9 sites** — 0 live-fire in game
- Dead `.gitignore` rules: **8**
- UID collisions: **0 / 1459**
- Empty dirs: **5** (one of which, `data/hitzones/`, is load-bearing)
