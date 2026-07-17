# Grunt Viewer — lead-programmer / godot-specialist analysis

Read: `scripts/visuals/grunt_dresser.gd`, `scripts/visuals/model_actor.gd` (both READ-ONLY, bead eq6n),
`scripts/tools/hitzone_editor.gd`, `scripts/tools/grunt_viewer.gd` (EXISTS), `scripts/tools/grunt_randomizer.gd`
(EXISTS), `tools/export_us_squad.py`, `tools/merge_face_skin_material.py`, `tests/test_model_scale.gd`,
`tests/test_fossils.gd`, `assets/us/props/helmets/helmets.json`, and the **binary GLB JSON chunks** of every
`assets/us/characters/*.glb` (parsed headers, dumped material + mesh-node names — not trusting any doc).

## 0. Ground truth first: the plan is half-built, and the GLBs contradict the dresser

**Already on disk:** `scripts/tools/grunt_viewer.gd` and `scripts/tools/grunt_randomizer.gd` exist and are
complete, working code. Missing: `scenes/tools/grunt_viewer.tscn`, `grunt_viewer.bat`, and the probe
(`tests/test_grunt_dresser.{gd,tscn}` — nothing named that in `tests/`). The build task is therefore
"finish the wiring + write the probe," not greenfield.

**The GLB truth (from the JSON chunks, per file):**

| unit | `helmet_shell_worn` | face material | `prc25_*` meshes | `ruck_pack_worn` |
|---|---|---|---|---|
| us_grunt_rifleman | YES | `face_atlas_mat` | **none** | no (part meshes `ruck_body`…) |
| us_grunt_grenadier | YES | `face_atlas_mat` | none | no |
| us_grunt_mg | YES | `face_atlas_mat` | none | no |
| us_grunt_marksman | YES | `face_atlas_mat` | none | no |
| us_grunt_pointman | YES | `face_atlas_mat` | **none** | no |
| us_grunt_rto | YES | `face_atlas_mat` | `prc25_radio_pack`, `prc25_antenna`, `prc25_handset` | no |
| us_rto | YES | `face_atlas_mat` | `prc25_radio_pack`, `_antenna`, `_handset`, `_cord` | no |
| us_medic | YES | `face_atlas_mat` | none | **yes** |
| us_grunt_v3 | YES | `face_atlas_mat` | none | **yes** |
| us_grunt_v2 / m14 / m60 / m79 | **no** | `face_atlas_mat` | none | no |
| us_pilot_white / _black | **no** | `us_pilot_*_skin` + `face_atlas_mat` | none | no |

Three live mismatches against the (read-only) dresser:

1. **`GruntDresser.FACE_MATERIAL = "grunt_face_skin"` matches NOTHING on any GLB on disk.** Every export
   carries `face_atlas_mat` (and a separate skin material folded or not). `tools/merge_face_skin_material.py`
   is the pipeline step that renames/merges to `grunt_face_skin` — but it writes
   `us_v3_soldier_lineup.blend` while `tools/export_us_squad.py` exports from **`us_base_v3.blend`**. The
   7/15 exports were made without the merge in their source. **Face/skin randomize is a silent no-op on
   every unit today.** (Skin/face *consistency* still can't break — nothing moves — but variety = 0.)
2. **No rifleman/pointman radio.** `model_actor.gd:273` says "the PRC-25 ships inside the rifleman and
   pointman GLBs" — it does not, in the current exports. Only the two RTOs carry it, and they are
   `CARRIES_RADIO` (always visible, never dresser-toggled).
3. **`GEAR_TOGGLES["radio"]` names `prc25_pack`; the exported mesh is `prc25_radio_pack`.**
   `_set_visible_by_name` uses `contains("prc25_pack")` — `"prc25_radio_pack"` does NOT contain that
   substring. Even after a corrected re-export, the pack body won't toggle (antenna/handset will). This is
   the exporter's HEIGHT_EXCLUDE war story ("shipped once as a rename prc25_radio_pack") biting again from
   the other side.

None of these are ours to fix (dresser/model_actor owned by the other window; exporter is a pipeline run).
**They must go to the Arbiter as a bead for the eq6n window:** re-run merge on the correct lineup blend
(or point the exporter at the merged one), re-export the six, add prc25 meshes to rifleman/pointman in the
lineup, and reconcile `prc25_pack` vs `prc25_radio_pack`. The viewer is still worth shipping now — helmet
swap (15 variants, all GLBs present per helmets.json), ruck on medic, role lock, clips, and the refusal
path all work today — but the RANDOMIZE button's face line will not change the model until the re-export.

## 1. Role list for the dropdown

`GruntRandomizer.roles()` (existing) is filesystem-derived: every `us_*` unit except
`NON_ROLES = ["us_grunt_v2", "us_grunt_v3"]`. That currently yields:
grenadier, m14, m60, m79, marksman, mg, pointman, rifleman, rto, us_medic, us_pilot_black,
us_pilot_white, us_rto — **too wide.**

- **Real dressable roles** (stock `helmet_shell_worn` + face atlas material, i.e. GruntDresser fully
  applies): **us_grunt_rifleman, us_grunt_grenadier, us_grunt_mg, us_grunt_rto, us_grunt_marksman,
  us_grunt_pointman** (the six `export_us_squad.py` TAGS) **+ us_medic + us_rto**.
- **Legacy/base — exclude:** `us_grunt_v2`, `us_grunt_v3` (already excluded; base rigs — v2 is the hitzone
  reference rig), **`us_grunt_m14`, `us_grunt_m60`, `us_grunt_m79`** (old-generation exports: ~2 MB JSON
  chununks = baked animations, **no `helmet_shell_worn`** → `_swap_helmet` push_warnings and does nothing),
  **`us_pilot_white`, `us_pilot_black`** (no steel pot, flight-helmet silhouette, not grunts).
- **Correction:** extend `NON_ROLES` (our file) to
  `["us_grunt_v2", "us_grunt_v3", "us_grunt_m14", "us_grunt_m60", "us_grunt_m79", "us_pilot_white", "us_pilot_black"]`.
  Keep the filesystem derivation — a future correct export self-registers.
- Welded weapons per GLB (why role lock = weapon lock, no separate weapon dropdown needed): rifleman
  carries `m16_world` welded; each role GLB welds its own weapon the same way (that is the whole reason
  the six are separate exports). Random role ⇒ random weapon for free; locked role ⇒ locked weapon.

## 2. Radio-legal units

Law (dresser + model_actor): legal = has `prc25_*` in GLB AND not `RADIO_FORBIDDEN`
(marksman/mg/grenadier) AND not `CARRIES_RADIO` (us_grunt_rto/us_rto).

- **Intended set:** us_grunt_rifleman, us_grunt_pointman.
- **Actual set on current GLBs: EMPTY.** Rifleman/pointman have no prc25 meshes; the RTOs are
  CARRIES_RADIO. `GruntRandomizer._radio_legal()` already probes the instance for a `prc25_pack` mesh, so
  it correctly offers radio to no one today — safe, silent, and self-healing after re-export **except**
  that its needle `"prc25_pack"` has the same substring problem as GEAR_TOGGLES if the re-export keeps the
  `prc25_radio_pack` name. Ours to hedge: probe for `"prc25_"` prefix instead (our file), and let the
  dresser mismatch be the other window's bead.
- The refusal path is fully testable today: marksman/mg/grenadier GLBs exist, `dress(actor, rng,
  {"radio": true})` must return `out["radio"] == false` + push_warning.

## 3. Orbit camera + Control UI coexistence

The existing `grunt_viewer.gd` already has the correct minimal pattern, and it is the right one:

- **Put orbit in `_unhandled_input()`** (it is). Godot's input pipeline delivers events to Control GUI
  *before* unhandled input; any click/wheel over the PanelContainer, OptionButtons, or Button is consumed
  by the GUI and never reaches the orbit handler. No `mouse_filter` fiddling, no manual rect tests. This
  is the idiomatic 4.x answer.
- Pivot orbit: `_pivot.rotation = Vector3(pitch, yaw, 0)` with default YXZ euler order = yaw then pitch —
  correct; camera at `(0, 0, dist)` child of pivot; pitch clamped. Wheel zoom clamped 1.2–8.0. Good.
- **One real bug to fix while finishing the scene:** stuck-drag. If LMB is pressed over the 3D view
  (`_dragging = true`) and *released over a Control*, the release can be consumed by the GUI and
  `_dragging` stays true — the camera then orbits with the button up until the next click. Cheapest
  robust fix, in `_process` or at the top of `_unhandled_input`:
  `if _dragging and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT): _dragging = false`.
  (hitzone_editor sidesteps this by using `_input`, which is why it must never gain Control UI.)
- Optional polish, not required: `Input.set_default_cursor_shape` / capture during drag. Skip — bench tool.

## 4. Strict typing / 4.7 / headless-probe viability

- **Headless works.** `tests/test_model_scale.gd` is the proven pattern: plain `Node3D` scene root,
  `await get_tree().process_frame`, `ModelActor.new(); add_child(actor); actor.setup(unit)`, run via
  `godot --headless --path . res://tests/test_grunt_dresser.tscn`. `--headless` loads GLBs, materials,
  textures, skeletons fine (dummy rendering server; resources are real). `get_active_material`,
  `surface_get_material`, `duplicate()`, `set_surface_override_material`, `BoneAttachment3D`,
  `stock.get_aabb()` all function headless. Do the `await process_frame` **before calling dress()** so
  `_swap_helmet`'s `stock.global_transform` reads a settled tree (matches the existing probe discipline).
  FAIL lines + `get_tree().quit(1)` exactly as test_model_scale does.
- **The probe as specified is a vacuous-pass trap.** "Assert same `uv1_offset` on every `grunt_face_skin`
  surface" passes with ZERO matching surfaces — which is the current reality. The probe MUST assert
  `matched_surfaces >= 1` per dressed grunt, and must read the needle from
  `GruntDresser.FACE_MATERIAL` (reading the read-only class's const is allowed; copying the string is a
  drift generator). **That assertion will be RED on day one against the current GLBs.** That is the honest
  outcome; a red probe is the mechanical form of the re-export bead. If the Arbiter wants a green suite
  meanwhile, split it: face-consistency assertions gated behind `matched >= 1` with a loud
  `WARN: face material absent from GLBs (stale export)` line + a dedicated red `FAIL` only in a separate
  probe — but my recommendation is one probe, red, bead filed, because a warning nobody reads is how
  `face_atlas_mat` shipped in the first place.
- **Per-instance duplication test:** dress two actors with different `face` opts, then assert their
  override materials are different Resource instances (`mat_a != mat_b`) AND different offsets. Note
  today this also cannot bite (no matching surfaces) — same gate as above.
- **Determinism test is sound but order-sensitive:** `GruntRandomizer.spawn` consumes rng in fixed order
  (role pick → ruck roll → radio roll → dress: face → helmet), `roles()` is sorted, and
  `GruntDresser.dress` iterates `GEAR_TOGGLES` (a const Dictionary — Godot Dictionaries preserve insertion
  order, stable) not the caller's opts. Same seed + same locked role ⇒ identical loadout dict. Assert
  with two fresh `RandomNumberGenerator`s, same `.seed`. Do NOT reuse one rng across the two spawns.
- Strict-typing nits in the existing viewer (fix while adding the tscn): `_actor = got["actor"]` and
  `_loadout = got["loadout"]` assign Variant to typed vars — write
  `_actor = got["actor"] as ModelActor` / `_loadout = got["loadout"] as Dictionary` per project rules.
  `for i in clips.size()` is fine (int range). Lambda in `item_selected.connect(func(_i: int) -> void: ...)`
  is 4.x-correct.
- 4.7 note: nothing in this plan touches 4.7-new surface area; no gotchas beyond the above.
- Bench-runner note: `grunt_viewer.bat` should clone `hitzone_editor.bat` verbatim (hardcoded
  `Godot_v4.7-stable_win64.exe` path, `--path "%~dp0" res://scenes/tools/grunt_viewer.tscn`).

## 5. Fossil probe exposure (test_fossils / ADR-023)

New/existing files under `res://scripts` are SCANNED for declarations; `res://scenes`, `res://tests` are
REF_DIRS only (test funcs are never judged).

- `grunt_randomizer.gd`: `NON_ROLES`, `RUCK_CHANCE`, `RADIO_CHANCE`, `roles`, `spawn`, `_radio_legal`,
  `_has_mesh` — each referenced at least once outside its declaration (viewer calls `roles`/`spawn`; the
  rest internal). freq > 1 for all. **Clean — provided the probe file also lands**, because `spawn` and
  `roles` are currently referenced only by `grunt_viewer.gd` (already ≥2 total). No trip.
- `grunt_viewer.gd`: all consts used; `_ready`/`_process`/`_unhandled_input` are LIFECYCLE-exempt; every
  other func is called or `.connect`-ed in-file (identifier tally counts those). No signals declared. No trip.
- **Watch-outs:** (a) if the stuck-drag fix removes the last use of a const, delete the const in the same
  edit; (b) do NOT reference dresser internals in comments as bare identifiers expecting them to count —
  comments are stripped; (c) the probe `.gd` lives in `tests/` so nothing it declares is judged, but the
  identifiers it *uses* keep `GruntRandomizer` symbols alive — good.
- The `.tscn` must reference the script by path/uid as usual; a `.bat` at repo root is outside REF_DIRS
  and REF_EXTS — irrelevant to the probe.
- Current baseline: this feature buries no baseline entries and must add none. Run
  `test_fossils.tscn` after the tscn+probe land; expected "no new fossils".

## Build list (what actually remains)

1. `scenes/tools/grunt_viewer.tscn` — Node3D root + `scripts/tools/grunt_viewer.gd` (script exists).
2. `grunt_viewer.bat` — clone of hitzone_editor.bat with the new scene path.
3. `tests/test_grunt_dresser.{gd,tscn}` — the five assertions, with `matched >= 1` guard (expected RED on
   the face assertions until re-export; everything else GREEN: refusal, helmet swap, determinism).
4. Small edits to the two files we own: widen `NON_ROLES`, `_radio_legal` needle → `"prc25_"` prefix,
   stuck-drag release check, two `as` casts.
5. **Bead for the eq6n window (Arbiter to file):** merge-script/exporter blend mismatch
   (`us_v3_soldier_lineup.blend` vs `us_base_v3.blend`) → `grunt_face_skin` absent from all GLBs;
   rifleman/pointman prc25 meshes missing vs model_actor.gd:273's contract; `GEAR_TOGGLES` `prc25_pack`
   vs exported `prc25_radio_pack`.

Tradeoff named: shipping the viewer now means a RANDOMIZE button whose face line lies (logs a cell, model
doesn't change) until the re-export bead closes — mitigated by the red probe making the lie mechanical.
