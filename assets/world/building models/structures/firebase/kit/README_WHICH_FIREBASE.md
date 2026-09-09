# Which firebase file is canon — settled 2026-08-12

**CANON: `firebase_v3.2.blend`.** Build anything new from this one.

It is `firebase_v3.1.blend` (2026-08-03) with the rebuilt medical office merged in.
2019 objects · 302 `work_*` markers · 30 collections.

## Why v3.1 was the base and not the newer file

`firebase_v3.1_RECOVERED_medical.blend` (08-05) is *newer* but was **not** a superset —
it had **lost 23 work markers** that 08-03 still had: `work_med_cot_00`–`15`,
`work_med_root`, `work_chow_diner` ×4, `work_chow_exit`, `work_chow_trigger`.
Its extra 1,181 objects were PSXRig crew figures, since superseded.

Architecture was **identical** across every v3.1 variant — 92 bunker objects, 41 sandbags,
`fb_road_gate` + `fb_gate_gap_i`, `fb_berm_ring`, `fb_terrain_mound`, the chow hall tent.
So nothing was given up by taking the older file.

## What v3.2 adds

- Old office furniture **cut** from `medical_complex` (18 islands / 144 verts: legless
  1.43 × 1.40 × 0.05 desk slabs, 0.85 seat blocks sitting *inside* the desk footprint,
  4 cm dots pretending to be legs). Mesh 29,448 → 29,304 verts.
- Three real desk stations in `MED_OFFICE_TENT` — `fb_field_desk` + the 0.45-seat office
  chair + paper stacks, one per `work_med_officer_*` marker.
- Three seated officers, hips on seat to within 0.0002 m, on staggered clips
  (`office_write` @1, `office_smoke` @−59, `office_write` @−47) so they never read as clones.
- `MARKERS_medical` — **18 fresh markers** rebuilt from real figure positions. The old
  `work_med_cot_*` set were fossils: present in the file, zero users, all at (0,0,0).
  Each new marker carries `work_clip`, `work_posture`, `work_phase`, `face_yaw_deg`,
  `hip_above_floor`.
- New clips: `office_write` (96f), `office_smoke` (144f), `office_desk_transition` (36f).

## Still in this folder

- `firebase_v3.1_RECOVERED_medical.blend` — **kept on purpose.** It is the medical truth
  source read by `tools/build_medical_workbench.py`, `tools/extract_chowhall.py` and
  `tools/gen_medical_crew.py`. Re-point those three before archiving it.
- `chow_hall.blend`, `NEW_sandbag.blend`, `fb_sandbag_kit_review.blend` — component files,
  not firebase builds.

## Archived to `_archive_2026-08-12/`

`firebase_v3.1` · `firebase_v3.1_RECOVERED_medical_PREWELD_2026-08-03` ·
`firebase_v3.1_WIP_chowline` · `firebase_v3` · `firebase_v2.1` · `firebase_v2_layout` ·
`firebase_kit_review` · `firebase_kit_review_flatsandbags`

Moved, not deleted. Some are write-targets of `gen_firebase*.py`, which will simply
recreate them if run — those generators are legacy and predate v3.2.

## DONE — corrected 2026-09-09

`fsb_main_v3.glb` was re-exported from this blend on **2026-09-06** and DOES carry the chow
hall and the medical complex. The section that stood here said it was still the 2026-07-26
export and had neither; that was true when written and false for three days before anyone
read it again.

**The re-export recipe, proven 2026-09-09:**
`blender --background --python tools/reexport_firebase_v3.py` — opens THIS blend, emits the
`-colonly` twins, exports, strips them, then halves the oversized textures (this blend holds
the full-size sheets, so every export restores them and the shrink must run again). That
sequence reproduced the shipped GLB **byte for byte**, md5
`6ce1bfbf35bcd9f7b9b090a23d705083`. It never saves the blend.

**Do NOT re-export with `gen_firebase_v3.main()`.** It reads an EMPTY homefile and rebuilds
the compound from constants — no chow hall, no medical complex, no staged crews — and it
never calls `export_firebase()` at all. It would replace this firebase with an older one.

Known defects still in this blend, both named by the export tool at open time:
- `fb_sbg_seg_046.001` — a Blender duplicate of a manifest segment. Godot adopts it onto the
  blast bus now, but it owns no collider (its twin's prefix claims it first).
- ~~`us_fb_ammo_crate_stack-colonly_P2`~~ **FIXED 2026-09-09.** Renamed here to
  `us_fb_ammo_crate_stack_P2-colonly` (marker at the END), so `clear_collision()` finally
  matches it and strips it before export. It ships nothing; the real crate keeps its own
  generated collider. Guarded by `tests/test_fsb_colonly_contract.tscn` and by
  `gen_firebase_v3.assert_colonly_terminal()` at export.

No GDScript reads `work_med*` / `work_chow*` yet either — `work_pos`/`work_clip` walking
exists only for VC camps (`camp_director.gd`, `enemy_base.gd:1660`).
