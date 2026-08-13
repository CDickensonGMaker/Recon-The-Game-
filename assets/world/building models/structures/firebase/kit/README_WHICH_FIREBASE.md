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

## NOT DONE

`fsb_main_v3.glb` — the GLB the game actually loads (`game_world.gd:400`) — is still the
**2026-07-26** export. It contains **no chow hall and no medical complex**. None of the
above reaches the game until it is re-exported, and that export must honour the
destructible naming contract or the new buildings ship invulnerable and bulletproof.

No GDScript reads `work_med*` / `work_chow*` yet either — `work_pos`/`work_clip` walking
exists only for VC camps (`camp_director.gd`, `enemy_base.gd:1660`).
