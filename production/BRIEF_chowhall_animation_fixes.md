# BRIEF — chow hall animation fixes (for `blender-overseer`)

**Dispatch this to the `blender-overseer` agent verbatim at the start of the next
session.** Written 2026-08-03 after Caleb reviewed the first pass in his live Blender
window and found four defects. He is waiting on this.

---

RECONgame chow hall — fix four animation defects the owner (Caleb) found by eye.

## READ FIRST
- `production/SESSION_HANDOFF_2026-08-03_CHOWHALL.md` — what was built today and the four
  bugs already hit and fixed.
- `~/.claude/skills/crew-choreography/LESSONS.md` — the 2026-08-03 entry is this exact
  job. Load the skill.
- `CLAUDE.md`.

## FILES
- Truth source scene:
  `assets/world/building models/structures/firebase/kit/firebase_v3.1_RECOVERED_medical.blend`
  (20.1 MB). Chow hall is `WORKBENCH_chowhall` at (0, −240) — **off to the side of the
  compound**; dining block at world y −243..−247. Men are in `WORKBENCH_chowhall_rigs`.
- Clip authoring: `tools/make_chowhall_anims.py` → `assets/shared/chow_anim_workbench.blend`
- Scene dressing: `tools/gen_chowhall_crew.py` (run with `-- --save`)
- Scene renders: `tools/preview_chowhall_scene.py` → `_scratch/chow_preview/scene/`
- Blender: `C:\Program Files\Blender Foundation\Blender 5.0\blender.exe`

**Caleb keeps Blender open on the truth source.** Build headless; when done, tell him to
**File ▸ Revert**.

## STEP 1, MANDATORY: WATCH REAL CHOW HALL FOOTAGE
Owner's rulings, 8/3: *"we should be watching videos of people in chow halls to get these
motions down"* and *"use youtube"*. `yt-dlp` 2026.07.04 is installed. Pull 2–4 clips
(military mess hall / chow line / serving line / soldiers eating; Vietnam-era where
available), build contact sheets, and **write the beats down as frame numbers before
touching Blender**. Report the URLs and what each gave you. Inventing these motions is
exactly what produced the defects below.

## THE FOUR DEFECTS (his words, plus measurements)

1. **"peoples arms are bent weird and going into the tables."** At frame 1 every eater's
   left hand sits at **z = 0.750** — dead level with the tabletop (0.750) — so the hand
   mesh is half buried; elbows at 0.96, a 0.21 m drop across a 0.26 m forearm, diving into
   the table edge. There is a **partial, UNTESTED edit** to `hands_eat` in
   `make_chowhall_anims.py` (hands lifted to hips+0.24 and pushed to ~0.8 of reach so the
   forearm lies flatter) — verify or replace it. Men eating rest forearms ON the table.

2. **"no ones going thru the line."** The five line men are static at their stations;
   nothing traverses. Hard constraint: `walk_right` carries **2.000 m per 31-frame cycle**
   (1.94 m/s) and `walking_unarmed` 1.907 m per 32 — both a march. Retiming to chow-line
   speed skates the feet by the slowdown factor, which is why no shuffle was authored.
   Options: derive a genuine single-step-and-hold clip, or **re-space the `work_queue`
   markers** (currently 0.70 m apart) to match a clip's real step length — moving the props
   to fit the motion is legitimate. Decide, state the tradeoff, make men advance.

3. **"the trays are just floating in the air."** Five `tray_base` + `food_01..04` sets are
   parented to `WB_chowhall` at fixed world spots (4 at the serve stations y = −240.90, one
   at the tray return). Nobody holds them. `PSXRig_traystack` and `PSXRig_midline` have
   hands **0.34 m apart at z ≈ 1.07** — exactly tray width — miming. Bone-parent trays to
   the carrying hand with a measured offset so the tray sits between both hands, gap < 5 cm
   every frame. The 8/2 footage finding stands: **the tray is HELD, never set down**, and it
   **fills progressively** — `food_01..04` are separate meshes so Godot toggles visibility
   per station.

4. **"the cooks should be rotating back and forth doing different things."** One stir loop
   forever. `rot_cook_check`/`hands_cook_check` and `rot_cook_prep`/`hands_cook_prep` were
   added to `make_chowhall_anims.py` but are **NOT in the `CLIPS` list — unwired and
   untested.** Wire or replace them, and sequence the cook through several jobs in NLA with
   an object yaw between the range and the prep crate so he physically turns.

## NON-NEGOTIABLES (each cost real time on 8/3)
- Every pose bone into **QUATERNION** mode before assigning a clip — euler mode ignores
  quaternion channels and the clip is dead on arrival.
- Key **location on every bone** the source animates, not just Hips.
- **Verify clean-room** — reset the pose to identity before evaluating.
- `gen_chowhall_crew.py` deletes its own actions before re-appending. Keep that, or an
  upstream re-author is silently ignored.
- **Snap up-axis corrections to a quarter turn**; the clips disagree on up axis.
- Run `dedupe_images()` before saving — appending from `us_base_v3.blend` drags packed
  textures and ballooned this file 9 MB → 398 MB on 8/3. Check the size after saving.
- Off-duty men carry **nothing**: no helmet, webbing, ruck or rifle.
- **Never blanket-purge orphans** in this shared file.

## DELIVERABLE
All four fixed, gates passing, saved to the truth source, fresh renders in
`_scratch/chow_preview/scene/` (delete PNG sequences after muxing — the disk is near full).
Append findings to the crew-choreography `LESSONS.md`. Report: YouTube sources, before/after
measurements per defect, what still needs his eye, and anything deliberately not done.
