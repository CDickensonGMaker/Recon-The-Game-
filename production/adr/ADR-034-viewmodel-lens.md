# ADR-034: The Viewmodel Lens — real-scale guns through their own FOV

**Date:** 2026-07-26 · **Status:** ACCEPTED (Summoner: "well fix these things than" / "if we had to remake the viewmodel tool to hit all the fixes too im open to that") — awaiting his playtest verification of the look
**Council:** production/war_room/analysis/p1_fov_shader_programmer.md · p2_marker_poses_systems.md · p1_p2_devils_advocate.md · research: production/research/viewmodel_pipeline_deep_dive_2026-07-26.md

## Decision

FP viewmodels are modeled at REAL-WORLD scale and rendered through their own
per-weapon FOV by a projection-override vertex shader with a reverse-Z depth
squash — the technique every major FPS engine uses (HL2 world 75 / viewmodel 54;
CS clamp 54–68; id's depth hack). The old mechanism — scaling the gun MESH by
`tan(75/2)/tan(vm_fov/2)` — is retired.

**The one implementation:** `scripts/weapons/viewmodel_lens.gd` (`ViewmodelLens`)
+ `assets/shaders/viewmodel_lens.gdshader`. `weapon_holder.gd` and
`viewmodel_editor.gd` both call it; the bench can no longer disagree with the
game by drifted copied math.

## Why the scale hack had to die

- Every pose/bore vector was tuned against a distorted mesh; changing a gun's
  `viewmodel_fov` invalidated all six of its tuned vectors.
- It never solved near clipping, so the pitch hack (`PITCH_OFFSET_*`) existed to
  hide the gun clipping the floor.
- The scaled MuzzlePoint subtly falsified the hip tracer origin.
- WYSIWYG between bench and game was maintained by discipline (identical copied
  math in two files), not by construction.

## Rules of the lens

1. **ADS coupling (ADR-004 untouched):** the shader uniform is
   `effective_fov(vm_fov, camera.fov)` — `tan(eff/2) = tan(cam/2)·tan(vm/2)/tan(75/2)`
   — recomputed as the camera zooms, so gun-vs-world magnification stays constant
   through the ADS transition exactly as the scaled mesh behaved.
2. **Truth vs paint:** rounds, noise, suppression spawn at the TRUE world muzzle.
   Cosmetics that must sit on the barrel AS DRAWN (muzzle flash, bench laser
   near-end) use `ViewmodelLens.apparent_point`. Two muzzle positions exist by
   design; only visuals may use the apparent one.
3. **Feel constants:** sway/punch/sprint/fire-menu translation bumps in
   `_update_weapon_position` are divided by `magnification(vm_fov)` so they read
   on screen as they did pre-lens. Poses (`hip_*`/`ads_*`) stay raw — they are
   bench-tuned under the lens.
4. **No shadows from the lens:** `ViewmodelLens.apply` forces cast_shadow OFF —
   a depth-squashed mesh must never write a shadow map. The shader modifies
   perspective passes only (`p[3][3] == 0` guard).
5. **Warhead contract preserved:** converted materials keep `resource_name`, and
   `_refresh_warhead` restores the surface to its lens override, never to null.
6. **`viewmodel_scale` is DELETED** (field, six .tres values, generator lines,
   bench display). It was declared, displayed, and applied nowhere. This
   overrules the earlier "wire it" ruling: wiring (or FOV-folding) a
   never-applied factor would CHANGE the look Caleb tuned by eye; deleting it
   changes nothing.

## The escape hatch and its kill list

`ViewmodelLens.ENABLED = false` restores the legacy mesh-scale path unchanged —
kept ONLY until the Summoner has re-posed/blessed the armory on the bench.
When he blesses, DELETE in one change (fossil law):
- the `ENABLED` const and every `else` branch reading it (weapon_holder.gd
  `_load_weapon_model`, `_update_weapon_position`, viewmodel_editor.gd load path)
- `WeaponHolder._lens_ratio` and the `PITCH_OFFSET_*` block (the depth squash
  makes floor clipping impossible)

## What is sacrificed (Devil's Advocate, accepted)

- **All 15 guns' poses shift on screen** — magnification now acts about screen
  center instead of the mesh origin. Only the M14 was fully tuned; every gun
  needs a bench pass by Caleb regardless (5 carried stub ADS poses).
- The old "gun magnifies its offsets" behavior is gone; feel constants were
  compensated, poses must be re-verified by eye (ADR-015 — probes cannot see
  look).
- .tres pose numbers are now lens-relative; reading them standalone tells you
  less than before.

## Probes

- `tests/test_viewmodel_sync_contract.gd` — bench camera == player camera
  (eye 1.7 / FOV 75 / identity holder), the old hand-maintained CLAUDE.md
  contract, now mechanical.
- `tests/test_viewmodel_poses.gd` — no NEW stub ADS poses; existing five
  grandfathered, list only shrinks.
- Export-side: `--strict` scale gate (±15% vs real length), slot asserts,
  frame-range purge (tools/export_viewmodel_clips.py).

## Next wave (recorded, not built — gated on Caleb's bench session)

Per the systems council (p2_marker_poses_systems.md): bench-derived ADS baseline
from SightRear/SightFront + per-gun offset fields; collapse `bore_dir`/
`ads_bore_dir` into aimed muzzle empties (the game never reads the bore fields —
bench-only); retire the identical `Transform3D(-1,0,0,0,1,0,0,0,-1,0,-1.81,0)`
wrapper offset by baking a camera-frame root at export. Also: tools/gen_weapon_data.py
still emits the pre-ADR-016 `base_damage = Array[int]` schema — stale generator,
fix or retire before next use.

## Amendment A — the gameplay timer is authored to the clip (2026-07-26)

**Summoner's ruling:** *"so than the game timer needs to match the animation's original times.
that makes the most sense."*

`scripts/player/weapon_holder.gd:894` fits every viewmodel clip to its gameplay timer —
`_vm_anim.speed_scale = clip_len / maxf(0.05, duration)`. ADR-018's principle stands unchanged:
the timer is authoritative and is never scaled by a stat, because handling is not a stat. What
this amendment adds is the other half of the contract — **the timer is authored to equal the clip,
so that ratio is always 1.00.** A timer that disagrees with its animation does not slow the
reload; it makes the animation play at the wrong speed.

**The defect that forced it.** `data/weapons/ppsh41.tres` set `reload_time = 3.4` and declared
neither `empty_reload_time` nor `jam_clear_time`, so it inherited the `weapon_data.gd:16-17`
defaults (`0.0` → falls back to `reload_time`; `1.1`) while carrying clips transplanted from the
AK. Measured in the shipped GLB: **reload 0.76× · reload_empty 1.30× · jam 3.30×** — the
Summoner's "way too fast then too slow", in the data, on one gun. m16/ak/m14 measured exactly
1.00 because their timers had been authored by hand to match. The convention was already right;
nothing enforced it, and the one gun that skipped the fields failed silently.

**Resolution — the export writes the number, so it is never hand-maintained** (Summoner's choice
over a hand-authored value with a failing test):

- `tools/sync_weapon_timers.py` reads each clip's duration from the **exported GLB's own input
  accessors** — the same numbers Godot loads, not the .blend's frame counts — and writes
  `reload_time` / `empty_reload_time` / `jam_clear_time` into the `weapon_tres` named in
  `tools/viewmodel_manifest.json`. `--check` reports drift and changes nothing.
- `tools/export_all_viewmodels.py` runs it after every successful export+validate.
- `tools/validate_viewmodel_glb.py` fails on drift, so a hand-edited .tres cannot pass quietly
  (`--no-timers` opts out). Proven by perturbing `jam_clear_time` back to 1.1 and confirming the
  validator reports `was playing at 3.30x` and exits 1.

**Balance consequence, accepted by the Summoner:** the PPSh jam clear becomes **3.63s**, up from
the 1.1s tap-rack default — the honest length of the clip it actually has. Its reload drops
3.4 → 2.6s and its empty reload rises to 4.43s. Ruled *"keep it — it's the honest length."*
If the PPSh clips are re-authored (they are transplanted AK performances), the timers follow
automatically on the next export.

**Sacrificed:** the .tres timers stop being a tuning dial. Wanting a faster reload now means
authoring a shorter animation, not editing a number — which is the point, but it does mean
gameplay pacing is gated on Blender work.
