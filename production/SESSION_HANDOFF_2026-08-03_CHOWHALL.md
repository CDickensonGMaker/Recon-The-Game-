# SESSION HANDOFF — 2026-08-03 · CHOW HALL

**Caleb: read the OPEN section at the bottom first.**

## WHERE THE FILES ARE

| file | what it is |
|---|---|
| `assets/.../firebase/kit/firebase_v3.1_RECOVERED_medical.blend` | **the firebase truth source, 22.1 MB.** The finished chow hall is merged back in |
| `assets/.../firebase/kit/chow_hall.blend` | **the chow hall working copy, 13.6 MB.** Iterate here, then re-run the merge |
| `assets/shared/anim_library.blend` | **186 actions, 48.6 MB.** All 19 `chow_*` clips merged in per his 8/3 ruling |

**Re-run `tools/merge_chowhall_to_firebase.py -- --save` after ANY further chow hall
work.** Two files holding the same work is what lost the medical complex on 7/31.

## THE LOOP (one man, verified end to end)
queue slot → walk to the servery → **stop at `food_stop`, wait the full 100-frame ladle**
→ sidestep the counter, tray fills → walk to a scheduled seat → sit → eat with the tray
**on the table** → stand → walk to the tray return → hand the tray to the collector →
**walk away empty-handed to `chow_exit`**, beside where he came in.

Stationed men are **trigger-driven, not looping**: the server ladles only while somebody
stands on `food_stop`; the collector receives only on arrival. Both idle arms-down on the
stock `idle_unarmed` between times, each started at its own phase so they are not in step.

## THE METHOD THAT WORKED
**Caleb poses two beats, I derive the clip and propagate it.** Every clip built that way
came out right; every clip I authored from invented hip-offsets came out wrong and he
spotted it by eye. His stances are on disk:
`production/pose_tray_hold_caleb.json` · `pose_eat_seated_caleb.json` ·
`pose_serve_dip_caleb.json` · `pose_serve_plop_caleb.json` · `pose_tray_handoff_caleb.json` ·
`pose_tray_receive_caleb.json` — each holds all 41 bones, the object transform, and the
prop's world matrix (the contract).

## LAWS ADDED THIS SESSION
- **ELBOWS NEVER ENTER A BODY OR A PROP** — his #1 complaint, made permanent. Gated in
  `chowhall_sim.build()` and written into `blender-overseer` + the crew-choreography skill.
  Note the rule is *elbow above the SHOULDER with the hand low*, and *elbow inside
  geometry* — "elbow above hand" is normal for arms hanging at the sides.
- **Every fix goes in the BUILDER, never as a live edit** — I fixed the collector's T-pose
  three times because a later rebuild regenerated the object and wiped it.
- **Blender work goes through the agents; motion comes from real footage (YouTube); use
  the base Mixamo clip rather than authoring one.**

## TOOLS
`chowhall_sim.py` (`build(n=)` — the whole sim) · `calibrate_clips.py` (per-clip up-axis
and yaw offset — ALWAYS run first) · `clip_from_caleb_pose.py` · `clip_serve_from_beats.py`
· `clip_cook_from_dip.py` · `clip_tray_receive.py` · `build_chowhall_tent.py` ·
`mark_chowhall.py` · `extract_chowhall.py` · `merge_chowhall_to_firebase.py` ·
`merge_chow_clips_to_library.py`

## MOVING THE HALL — grab `WB_chowhall`, nothing else (fixed 2026-08-03)

Dragging the hall used to blow the cook up out of proportion. Two faults, fixed in both
.blends and in the builder (`chowhall_sim.weld_to_root()` + `rigid_move_check()`, run at
the end of `build()`): the six `PSXRig_*` armatures had **no parent**, so a select-all
drag moved a deform mesh and its armature by different amounts; and **48 rigless meshes**
(`*_line2`, `*_midline`, `*_traystack`) sat at the world ORIGIN, inside the firebase, with
an Armature modifier pointing at nothing. Deleted.

`WB_chowhall` sits at y = −240 with 152 direct children — parked outside the base, same
convention as `WORKBENCH_bunkers` at y = −170. Measured after the fix: all 32 visible
rigged meshes travel exactly with the root, zero size change. The other 64 are
`hide_viewport` and cannot be measured at all — the depsgraph never evaluates them, so
they read as "did not move" whatever is true.

Pre-fix copies: `*_PREWELD_2026-08-03.blend` beside each file.

**Sited, and the men are out.** Caleb placed the hall at (−20.51, 40.83, 3.0), yaw 44°.
The firebase now ships the ROOM only — 39 meshes (tent, tables, benches, ranges, mermites,
tray stack) and 97 markers, zero armatures, 22.0 → 18.7 MB. The 6 rigs, their 117 meshes,
the hand-held trays and the 19 `chow_*` actions were removed; all 19 clips were confirmed
present in `anim_library.blend` first. The loop stays playable in `chow_hall.blend`.
`merge_chowhall_to_firebase.py` strips the men on every merge and carries the placement
across — without that it would re-append the men and shove the building back to y = −240.

## OPEN — nothing below is done

1. **`build(n=5)` has never been run.** Only n=1 is verified. The queue-slot spacing and
   the idle staggering are exactly what needs several men to prove.
2. **Marker audit + "every seat can be filled"** — 24 `work_eat` seats exist and the
   scheduler draws from all of them, but only one has ever been exercised.
3. **NONE OF THIS IS IN THE GAME.** `anim_library.glb` is not re-exported, and
   `site_planner.gd` maps no chow marker — see `PROPOSAL_chowhall_godot_wiring.md`.
   Marker names are still PROVISIONAL and await his ruling.
4. **Stopping a patrol to go eat** — his ask, and it is Godot-side, not a Blender job.
5. **VC eating from a bowl** — his next ask. The body motions already exist in the shared
   library (see [[chow-hall-clips-are-the-shared-library]]); it needs a bowl prop and a
   grip contract, not new motion.
6. **The medical tent, same workflow** — his explicit next job. Everything above is
   reusable: calibration, pose-capture-and-propagate, the elbow gate, the seat scheduler,
   the trigger-on-approach pattern.
7. **`tools/gen_firebase_v3.py:912` still defaults to the stale `firebase_v3.1.blend`** —
   unchanged since 8/2. An export today silently ships the OLD firebase.
