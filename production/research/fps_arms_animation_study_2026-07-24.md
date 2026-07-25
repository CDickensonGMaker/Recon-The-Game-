# FPS Arms Animation Study — 2026-07-24

Reference teardown of three purchased/downloaded FPS arm packs, measured headlessly in
Blender 5.0. Purpose: extract a clip naming + timing standard for RECON's `fp_arms`
before animating the US armory.

Sources (all in `C:\Users\caleb\Downloads\`):

| Pack | File | Format |
|---|---|---|
| Low-poly MP5 | `fps-animations-lowpoly-mp5/source/LowPoly_FPS_MP5.blend` | **.blend (native)** |
| Bolt-action sniper | `fps-animations-sniper-rifle/source/BoltActionRifle.fbx` | FBX 7400 |
| Benelli M4 | `fps-benelli-m4-animations/source/HandWithGloves_AnimateRDY.fbx` | FBX |

---

## 1. Rig comparison

| | MP5 | Sniper | Benelli |
|---|---|---|---|
| Armature | `Arms` | `Rig` | `Rig` |
| Bones | **86** | 78 (61 driven) | 59 |
| IK control rig | **YES** | no (baked) | no (baked) |
| Arms tris | **5,196** | 14,852 | 11,292 (+8,442 sleeve) |
| Weapon tris | 5,477 | 19,960 | 25,184 |
| Actions | 9 (all real) | 22 (**9 real, 13 junk**) | 9 (8 real) |
| Scene fps | 60 | 60 | 60 |

**The MP5 pack is the one to study.** It is the only native `.blend`, and the only one
that still has an editable control rig rather than a bake. Its hierarchy carries proper
FK/IK separation:

```
Root
  IK_Cntrl_L / IK_Cntrl_R      <- hand IK targets
    IndexIK / MiddleIK / RingIK / LittleIK / ThumbIK   <- per-finger IK
    IndexPT / MiddlePT / RingPT / LittlePT / ThumbPT   <- per-finger pole targets
  IK_PoleTRGT_L / _R           <- elbow poles
  ArmCtrl_L / ArmCtrl_R
UpperArm_L -> Forearm_L -> Hand_L -> Thumb00/01/02, Index01..03, ...
```

Both FBX packs lost their control rigs in the export — every bone is keyed on every
frame. Benelli's full reload alone is **254,575 keyframes** across 599 curves. They are
fine to *watch and retarget from*, painful to *edit*.

---

## 2. Timing standard (the actually valuable part)

All three were authored at 60fps. Durations converted to seconds:

| Clip | MP5 | Sniper | Benelli | **Proposed RECON** |
|---|---|---|---|---|
| Idle (loop) | 3.32s | 3.00s | 2.98s | **3.0s** |
| Walk (loop) | 1.32s | 1.25s | 0.98s | **1.25s** |
| Run (loop) | 0.65s | — | 0.48s | **0.6s** |
| Sprint (loop) | 0.48s | — | — | **0.5s** |
| Draw | 1.15s | — | — | **1.0–1.2s** |
| Fire | 0.48s | 1.67s¹ | 0.65s | **0.5s** (semi) |
| Reload — full/empty | 3.65s | 4.75s | 7.07s | **3.5–4.0s** |
| Reload — partial/tactical | 2.82s | 3.17s | 1.65s | **2.5–3.0s** |
| Inspect | 7.48s | — | — | optional |

¹ Sniper "shot" includes the full bolt cycle, which is why it is 3× the others.

**Idle converges on ~3.0s across all three independent authors.** That is a real
convention, not a coincidence — long enough not to read as a loop, short enough to stay
alive. Use it.

---

## 3. Conventions worth adopting

**Two reload clips, always.** Every pack distinguishes them:

- MP5 — `Arms_fullreload` / `Arms_notfullreload`
- Sniper — `SRifle_Reload_Full` / `SRifle_Reload`
- Benelli — `M4_ReloadFull_type1` / `M4_ReloadOne_type1` / `M4_ReloadOne_type2`

This is the **bolt-forward vs bolt-locked-back** distinction. RECON needs it for the M16
(bolt catch on empty) — the empty reload is longer because it includes the bolt release.
Benelli's `ReloadOne` variants are shotgun shell-at-a-time loads, which maps to a
tube-fed shotgun if one ever enters the armory.

**ADS vs hip fire as separate clips.** The sniper pack splits `SRifle_Shot_sight` and
`SRifle_Shot_nosight`. Directly relevant to the outstanding `fp_arms` sight-link work —
the recoil path differs when the weapon is welded to the eye.

**Last-round callout.** Benelli has `M4_Fire_LastRoundCheck` (2.15s) — fire, then the
character visibly checks the empty gun. Great texture for RECON's tension, cheap to add.

---

## 4. Cautions

1. **These are 60fps and far over RECON's PSX poly budget.** Benelli's 25k-tri gun and
   11k-tri gloved hands are non-starters. MP5's 5.2k-tri arms are the only mesh in the
   neighbourhood of usable. Study the *timing and staging*; do not import the meshes.

2. **Sniper FBX has 13 junk actions.** Anything named `Camera|...` or `Sun|...`
   (2 curves, 4 keys) is exporter garbage from the camera/light. There are also two
   orphan `FPS_Pistol_Fire` actions left over from a different weapon on the same rig.
   Filter on import.

3. **Blender 5.0 cannot import the sniper FBX out of the box.** The importer throws
   `AttributeError: 'CyclesLightSettings' object has no attribute 'cast_shadow'` because
   that property was removed in 5.0 and the FBX contains a light. Workaround — stub the
   light reader before importing:

   ```python
   from io_scene_fbx import import_fbx
   import_fbx.blen_read_light = lambda t, o, s: bpy.data.lights.new("stub", 'POINT')
   ```

4. **Licensing is unverified.** Texture names like `*_brand_friendly.png` suggest these
   are marketplace/Sketchfab assets. Studying timing is unrestricted; shipping the meshes
   or the animation data in RECON is a separate question. Check the license before any of
   it crosses into the repo.

---

## 5. Recommended next step

Adopt the MP5 clip set as the `fp_arms` standard and author RECON's clips to the
proposed durations above:

```
idle, walk, run, sprint, draw, fire, fire_ads,
reload_tactical, reload_empty, inspect
```

The MP5 IK rig is the structural model to copy for RECON's arm rig — per-finger IK with
pole targets is what makes hand-to-weapon contact hold when the gun moves during a
reload. Baked FK arms will slide off the grip.
