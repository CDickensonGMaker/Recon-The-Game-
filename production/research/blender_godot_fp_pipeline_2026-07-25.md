# Blender → Godot FP Viewmodel Pipeline — Research

**DATE BANNER: research conducted 2026-07-25.** Web claims cite their URLs (Pointer Law); code
claims cite `file:line` in this repo. Engine/tool versions of record: Godot 4.7, Blender 5.0,
glTF-Blender-IO as shipped with Blender.

**Scope:** exporting hand-animated FP gun/arms viewmodels (multiple clips per gun, detachable
mags/charging handles, CHILD_OF handoffs) from Blender to Godot, and automating that export so
re-exports stop breaking the game.

**Ground truth first:** this repo ALREADY implements the hard 80% of the "correct" pipeline —
`tools/export_viewmodel_clips.py` bakes constraint-driven part motion to real TRS fcurves and
exports one glTF animation per NLA track (`tools/export_viewmodel_clips.py:8-24` documents exactly
why: glTF has no constraints, the exporter writes NO channels for objects without fcurves, ACTIONS
mode samples objects in isolation, non-uniform scale decomposes into tumbling rotation). Nothing
found on the web contradicts that script's doctrine; the community is still rediscovering it in
forum threads. What the web research adds is: (a) the Blender 4.4+/5.0 slotted-action landscape,
(b) which automation surface to bolt on, and (c) the validation step this pipeline is missing.

---

## 1. glTF/GLB export from Blender for animated viewmodels

### 1.1 Exporter animation modes

The glTF exporter has four animation modes (confirmed via
https://docs.blender.org/manual/en/2.91/addons/import_export/scene_gltf2.html and
https://github.com/godotengine/godot-proposals/issues/11887):

| Mode | Behavior | Verdict for viewmodels |
|---|---|---|
| **Actions** (default) | Each action (active + on NLA) becomes a glTF animation, **sampled per-object in isolation** | WRONG for multi-object rigs — a mag baked against an unposed arm lands wrong (`tools/export_viewmodel_clips.py:20-22`) |
| **Active actions merged** | All currently-assigned actions merge into ONE glTF animation | Only useful for single-clip exports |
| **NLA Tracks** | Each NLA track = one named glTF animation, whole scene evaluated together | **CORRECT** — track name becomes the Godot clip name; multi-object clips stay synchronized |
| **Scene** | Bakes the evaluated scene (constraints included) as a single animation | Bakes constraints but can't produce multiple named clips — useless for a clip library |

Supporting option: "Group by NLA track name" — actions on same-named NLA tracks across multiple
objects merge into one glTF animation (https://community.khronos.org/t/gltf-vs-glb-multiple-actions-from-blender/107469).
That is the mechanism the RIG_<gun> collections already rely on: same track name on rig + parts =
one clip.

Community consensus matches: push actions to NLA strips, name the strips, disable "export all
animation actions", let NLA be the single source of truth
(https://supermatrix.studio/blog/best-workflow-for-exporting-animated-characters-from-blender-to-godot).

### 1.2 Slotted actions (Blender 4.4+, mandatory in 5.0)

- Blender 4.4 introduced slotted actions: one Action can hold animation for multiple data-blocks
  (armature + mag object + handle object in ONE action)
  (https://devtalk.blender.org/t/blender-4-4-slotted-actions-feedback/38906,
  https://alternativeto.net/news/2025/3/blender-4-4-launches-with-a-new-slotted-actions-system-vulkan-improvements-and-more).
- glTF exporter support landed with the feature: **a multi-slot action exports as a single glTF
  animation by default**, with a fallback option to merge by NLA track name instead of by action
  (https://projects.blender.org/blender/blender/pulls/132771). Animation-pointer slots for
  non-object data were deferred past 4.4 (same PR).
- Implication for this project: the historic reason FPS rigs crammed weapon parts into one armature
  — "one action cannot animate two objects" (see §4) — is GONE in Blender 5.0. One slotted action
  per clip (`m14_reload` with slots for rig + mag + handle) is now representable, and the exporter
  emits it as one glTF animation. The NLA same-name-track convention and the multi-slot-action
  convention both arrive at the same GLB; the NLA route is the older, battle-tested one.
- Python API changes are already recorded in Claude memory (`blender-5-api.md`): `action.fcurves`
  is gone; go through `action.layers[0].strips[0].channelbag(slot)` — any export/bake tooling
  written now must use the slotted API.
- **Friction is real and recent.** The exporter-side slot handling is ~1 year old; the devtalk
  feedback thread ran to 4+ pages of workflow complaints
  (https://devtalk.blender.org/t/blender-4-4-slotted-actions-feedback/38906). Keep the NLA-tracks
  export mode as the contract; treat "one multi-slot action per clip, no NLA" as an experiment to
  run on ONE gun before adopting.

### 1.3 Constraints do NOT export — bake or lose the motion

- glTF has no constraint concept. The exporter does not bake CHILD_OF/COPY_TRANSFORM-driven motion
  in Actions or NLA modes; objects whose motion comes only from constraints get **no channels at
  all** (https://github.com/KhronosGroup/glTF-Blender-IO/issues/439,
  https://github.com/KhronosGroup/glTF-Blender-IO/issues/1251). This is precisely the "mag never
  detaches in game" failure documented at `tools/export_viewmodel_clips.py:8-13`.
- Manual escape hatch: Pose/Object → Animation → **Bake Action with Visual Keying** (+ Clear
  Constraints), historically buggy without Visual Keying
  (https://projects.blender.org/blender/blender/issues/36772). Downside: destructive — people
  duplicate the rig per export to preserve the authored constraints
  (https://github.com/KhronosGroup/glTF-Blender-IO/issues/1251).
- The repo's script does this non-destructively and better: evaluate each clip frame-by-frame,
  record `matrix_world` per part, strip constraints, write real TRS keys, export, never save the
  .blend (`tools/export_viewmodel_clips.py:14-17,26`). **Keep this approach.** No addon found does
  constraint-to-object baking per NLA clip; this script is ahead of the tooling market.

### 1.4 Transform/scale gotchas (confirmed, multiple sources)

- Apply all transforms (Ctrl+A) on everything before rigging/export; unapplied armature
  scale/rotation is the #1 reported cause of deformation garbage on import
  (https://supermatrix.studio/blog/best-workflow-for-exporting-animated-characters-from-blender-to-godot).
- **No non-uniform scale anywhere in an animated hierarchy** — glTF stores T/R/S decomposed;
  non-uniform scale + inherited rotation is a shear glTF cannot represent and it decomposes as a
  tumbling rotation (`tools/export_viewmodel_clips.py:22-24`). Enforce this in the validator (§5).
- Export `+Y up` (Godot's convention; the exporter default) and `export_apply=True` for modifiers —
  already the pattern in `tools/export_weapon_glb.py:56-58`.
- Useful exporter flags for clip hygiene: "Limit to Playback Range", "Set all glTF animations
  starting at 0", force sampling ON, and be careful with "Optimize Animation Size" — it strips
  constant channels, and a detached-mag clip may NEED a constant channel to hold the part still.

---

## 2. Godot 4 import side

### 2.1 Node-name import hints

Suffixes recognized at import (https://docs.godotengine.org/en/stable/tutorials/assets_pipeline/importing_3d_scenes/node_type_customization.html):
`-noimp` (delete node/animation), `-col`/`-convcol`/`-colonly`/`-convcolonly` (collision),
`-occ`/`-occonly`, `-navmesh`, `-rigid`, `-vehicle`/`-wheel`, material hints `-alpha`/`-vcol`, and
animation-name tokens **`loop`/`cycle`** (prefix or suffix, no hyphen required) which set the loop
flag. Cheap win: name idle/sway NLA tracks `idle-loop` etc. and looping survives every re-import
with zero .import-file configuration.

### 2.2 Import scripts and animation options

- `EditorScenePostImport._post_import(scene)` runs arbitrary `@tool` code after import — the hook
  for enforcing project-side contracts per GLB (loop modes, adding markers, asserting clips)
  (https://docs.godotengine.org/en/stable/tutorials/assets_pipeline/importing_3d_scenes/import_configuration.html).
- Relevant import options: animation FPS (match bake rate), **Trimming** and **Remove Immutable
  Tracks** (both can silently delete "boring" tracks — for viewmodels turn Remove Immutable Tracks
  OFF if a part relies on a constant hold, same reasoning as the exporter optimize flag), and
  "Import as Animation Library" mode for animation-only GLBs (same URL). The latter is the formal
  version of what this repo already does with `anim_library.glb` for third-person clips
  (memory: `recongame-corrections-2026-07-19`).
- Shared-library vs per-model clips: AnimationLibrary + retargeting is designed for humanoid
  skeletons sharing clips (https://godotengine.org/article/animation-retargeting-in-godot-4-0/).
  **For FP viewmodels it is the wrong shape** — every gun's clips are authored against that gun's
  unique part set; per-gun GLB with embedded clips (current `<gun>_fp.glb` pattern,
  `tools/export_viewmodel_clips.py:35`) is correct. Keep the shared library for the third-person
  soldier rigs only.

### 2.3 What breaks track bindings

Godot animation tracks bind by **NodePath relative to the AnimationPlayer root, plus bone name for
skeleton tracks**. Renaming a Blender object/bone or reparenting it changes the path inside the
re-imported GLB; game-side .tscn scenes that reference nodes inside the GLB (MuzzlePoint, model
paths in `scenes/weapons/*_arms_viewmodel.tscn`) break the same way. The community has no machine
fix for this — the fix is a **naming freeze**: object names, bone names, marker names, and NLA
track names are API. Renames are breaking changes and require a validator run (§5). This is the
single most common way "re-export broke my game" happens, after the constraint-bake issue.

### 2.4 Direct .blend import — verdict: NO for viewmodels

- Mechanism: Godot invokes the installed Blender headless, exports glTF with **defaults**, then
  runs the normal glTF pipeline
  (https://docs.godotengine.org/en/stable/tutorials/assets_pipeline/importing_3d_scenes/available_formats.html).
- "Defaults" is fatal here: there is no hook to run the constraint bake, and Godot does not expose
  the exporter's animation mode — an open proposal asks for exactly that (add NLA Tracks option,
  keep Actions default: https://github.com/godotengine/godot-proposals/issues/11887). So .blend
  import gives ACTIONS-mode isolation sampling and zero constraint baking — both known-broken for
  these rigs.
- Additional 4.7 headless wart: an unconfigured Blender path can fail unrelated imports in headless
  mode (https://github.com/godotengine/godot/issues/120560) — relevant because this project runs
  headless test imports.
- Fine for static props; **never** for `assets/player/viewmodels/`. Current explicit-GLB practice
  stands.

---

## 3. Automation tooling landscape

### 3.1 Headless Blender batch export (the canonical pattern)

`blender --background file.blend --python script.py -- args` is the community-standard automation
primitive (https://robertshenton.co.za/blog/blender-batch-export/); this repo already has 13
`tools/export_*.py` scripts using it. The missing layer is a **driver** that runs all of them from
one command with a manifest, instead of remembering per-gun argv triplets
(`tools/export_viewmodel_clips.py:3`).

### 3.2 Blender 4.2+ Collection Exporters

Each collection can carry persistent exporter configs (format + settings stored in the .blend);
File → Export All exports every configured collection in one click, scriptable via
`bpy.ops.collection.export_all` (https://developer.blender.org/docs/release_notes/4.2/pipeline_assets_io/,
https://superhivemarket.com/products/export-each-blender/docs). Attractive for static assets;
**does not solve viewmodels** because there is no pre-export bake hook — the constraint bake must
run first, so the custom script stays the entry point for FP rigs.

### 3.3 Addons surveyed (see §6 table)

Key finding: every addon surveyed automates *selection/looping/settings*, none automates
*constraint-to-object baking per clip*. The repo's problem is already solved by its own script; the
addons would only replace the easy part.

### 3.4 Naming-convention contracts / markers

- Blender empties survive glTF as plain nodes → Godot Node3D. Markers (muzzle, sight, shell-eject)
  as empties inside the exported collection is standard practice and already this project's marker
  contract (memory: `recon-weapons-ads-state` — marker contract on the armories).
- No off-the-shelf CI validator for "did my clips/markers survive export" was found; teams
  hand-roll checks. Khronos glTF-Validator checks spec validity, not game contracts. Conclusion:
  the validation probe must be built in-house (§5) — consistent with this project's probe law
  (memory: `recongame-observation-instrument` — "every rig MUST have a probe that EXERCISES it").

---

## 4. FPS-specific rig/export practice

- The classic forum problem: separate arm rig + gun rig exports as **split animations per rig**
  (https://forum.godotengine.org/t/what-is-the-correct-way-of-animating-and-exporting-an-fps-arms/72054),
  and the classic answer was "put weapon bones in the one armature" because a single action
  couldn't span objects (https://forum.godotengine.org/t/fps-arms-animation-for-multiple-weapons/72273,
  https://forum.godotengine.org/t/best-blender-to-godot-workflow-for-fps-viewmodel-with-multiple-weapons/135582
  — that last thread, March 2026, asks this project's exact question and got no answers; the
  community has no settled public doctrine. This repo's script IS the state of the art).
- Two viable structures:
  1. **Single armature + weapon bones** (mag_bone, bolt_bone; parts skinned 100% rigid). Pros: no
     object-level constraints to bake IF animators key bones directly; everything rides one
     skeleton. Cons: CHILD_OF-style hand↔part handoffs between bones are still constraints and
     still need baking; per-gun bone sets bloat a shared armature; retrofitting all six RECON guns
     is a rebuild.
  2. **Armature for arms + separate part objects, constraint-driven, baked at export** — the
     current RECON structure (`tools/export_viewmodel_clips.py:9-13`). Pros: parts stay clean
     separate meshes (magazine can be dropped/hidden per ADR-018-style logic in game), authoring
     stays natural (CHILD_OF influence keying), already built and shipped. Cons: mandatory bake
     step (already automated).
  Web evidence gives no reason to migrate from 2 to 1. Blender 5 slotted actions further weaken
  option 1's original rationale (§1.2).
- Keeping mag/bolt as separate animated **nodes** (not skinned into the arms mesh) is what allows
  game-side tricks — hiding the mag on empty, swapping tracers at MuzzlePoint — and matches the
  existing viewmodel scene contract (`CLAUDE.md` Viewmodel Scene Structure: Model + MuzzlePoint
  Marker3D).
- Validation practice in the wild: essentially nobody publishes automated export-contract checks;
  the standard is "open it in Godot and look." That is exactly the gap that keeps breaking this
  game on re-export.

---

## 5. RECOMMENDED PIPELINE (concrete, for this project)

The pipeline is 80% built. Do not replace it — harden and close the loop.

**A. Authoring contract (freeze it in the blend files, document in ART_Track_Log):**
- One `RIG_<GUN>` collection per gun: arms rig + gun + parts + marker empties (current shape,
  `tools/export_viewmodel_clips.py:5-6`).
- NLA track name == clip name == what game code plays. Looping clips named `*-loop` (free Godot
  loop flag, §2.1). `ZZ_REVIEW_ROW` stays the reserved review track (`tools/export_viewmodel_clips.py:36`).
- Names are API: objects, bones, markers, tracks. A rename is a breaking change and must ship with
  a validator run and a grep of `scenes/weapons/` + `data/weapons/`.
- All transforms applied; uniform scale only on anything animated (validator-enforced).

**B. Export step (existing):** `blender -b <blend> -P tools/export_viewmodel_clips.py -- RIG_X GUN out`
— world-matrix bake → strip constraints → NLA_TRACKS export → `assets/player/viewmodels/<gun>_fp.glb`.
Blender-5 note: audit the script once against the slotted-action API (`action.fcurves` is dead —
memory `blender-5-api.md`); anywhere it touches fcurves must go via channelbags.

**C. NEW — one-command driver + manifest.** `tools/viewmodel_manifest.json`: per gun → blend path,
collection, expected clip list (+lengths ±1 frame), expected part objects, expected markers.
`tools/export_all_viewmodels.ps1` (or .py) loops the manifest, runs B per gun, then runs D. One
command re-exports the whole armory identically every time; the manifest kills the
"argv-from-memory" failure mode.

**D. NEW — post-export validation probe (the missing piece).** Two cheap layers:
1. *Blender-side (same headless run):* re-import the just-written GLB into an empty scene and
   assert against the manifest — every expected clip exists, no extras, lengths match, every part
   node has ≥1 animation channel in clips where it moves (catches the silent "no channels written"
   class), every marker empty present, no non-uniform scale on any animated node. Exit nonzero on
   any miss → the driver stops and names the gun and clip.
2. *Godot-side (in the suite, runs when Caleb runs `run_all_tests.ps1`):* a probe scene that loads
   each `<gun>_fp.glb`, instantiates it, and asserts AnimationPlayer clip names against the same
   manifest + MuzzlePoint presence. This is the fresh-eyes check that the *imported* result — after
   Godot's trimming/track-removal options — still honors the contract. Turn **Remove Immutable
   Tracks OFF** on viewmodel imports (§2.2) as part of building this probe.

**E. Explicitly rejected:** direct .blend import for viewmodels (§2.4); shared AnimationLibrary for
FP clips (§2.2); migrating to a weapon-bones mega-armature (§4); any addon purchase to replace the
export core (§3.3).

**F. Optional experiment (one gun, later):** author one new clip as a single multi-slot action
(rig+mag+handle slots) in Blender 5, export via action mode, compare with the NLA path (§1.2). If
it round-trips clean it simplifies authoring for future guns; it does not obsolete the bake.

---

## 6. Candidate tools/addons

| Tool | What it does | Pros | Cons / verdict |
|---|---|---|---|
| **In-house `export_viewmodel_clips.py`** (`tools/`) | Bakes constraint motion per NLA clip, exports GLB | Solves the one problem nothing else solves; already proven | Needs Blender-5 API audit + manifest/validator wrapper. **KEEP, core of pipeline** |
| **Blender Collection Exporters** (built-in 4.2+) | Per-collection persistent export configs, Export All (https://developer.blender.org/docs/release_notes/4.2/pipeline_assets_io/) | Zero-install, scriptable, good for props/world kits | No pre-export bake hook → can't carry viewmodels. Use for static assets only |
| **Blender-Godot Pipeline (michaeljared)** (https://godotengine.org/asset-library/asset/2562) | Custom properties in Blender → collisions/scripts/multimesh/navmesh on Godot import | Best-in-class for level/prop metadata; active (v2.5.5, Sep 2025) | Forces .gltf-separate format; nothing for animation baking. Irrelevant to viewmodels |
| **Godot Game Tools (viniguerrero)** (https://viniguerrero.itch.io/godot-game-tools) | Mixamo/character batch anim processing, root motion | Free, popular for TP characters | Mixamo-shaped; useless for hand-authored FP rigs |
| **batch_export_gltf (jcroisant)** (https://gitlab.com/jcroisant/batch_export_gltf) | Export multiple collections → .glb | Tiny, free, readable source | Selection automation only; no bake. The in-house driver (§5C) supersedes it |
| **io_ggltf** (https://github.com/amadeusz-zackiewicz/io_ggltf) | Alternative scripted glTF exporter, manual bake/NLA grouping control | Most flexible exporter replacement found | Niche, maintenance risk, Blender-5/slot support unverified. Avoid |
| **Auto-Rig Pro GLTF export** (paid) | Bakes and exports per-action for ARP rigs | Mature baking UX | Assumes ARP rigs; RECON rigs are hand-built. No |
| **Khronos glTF-Validator** | Spec-validity check of GLB | Catches malformed output in CI | Doesn't check game contracts (clips/markers). Optional extra rung in §5D |

---

## Bottom line

The web has no turnkey answer; the constraint-bake + NLA-tracks doctrine already encoded in
`tools/export_viewmodel_clips.py` IS the correct 2026 pipeline, and forum threads from March 2026
show the rest of the community still stuck where this repo was before that script. The breakage on
re-export is a *contract* problem, not an *export* problem: nothing today verifies that clips,
parts, markers, and names survived the trip. Build the manifest + two-layer validator (§5C/D),
freeze the naming contract, audit the script once for the Blender-5 slotted-action API, and keep
.blend direct import away from viewmodels.
