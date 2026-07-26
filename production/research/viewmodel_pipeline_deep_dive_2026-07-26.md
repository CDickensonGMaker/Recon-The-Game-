# Viewmodel Deep Dive — Gun Models, Sizing, and Fixing the Editor
**Date:** 2026-07-26 (overnight research per Caleb's request)
**Inputs:** full repo audit (viewmodel_editor.gd, weapon_holder.gd, all 15 .tres, manifest/exporters), internet research on Blender 5.0 weapon workflows, and industry FPS viewmodel sizing standards. Sources cited inline.
**Status:** FINDINGS + PROPOSAL. Nothing built. Awaiting Caleb's morning review.

---

## TL;DR

1. **Sizing law:** model every gun and the arms at REAL-WORLD scale (1 Blender unit = 1 m, unit scale 1.0, all transforms applied). On-screen gun size comes from a **separate viewmodel FOV**, never from scaling the mesh. Every major engine/studio works this way (Valve, id, CoD, UE ecosystem).
2. **Our core architectural bug:** RECON fakes viewmodel FOV by **scaling the gun mesh** (`_lens_ratio`, `weapon_holder.gd:973-978`, clamp 0.6–2.2). That one decision is why the editor keeps getting worse — every pose, bore vector, and muzzle position is tuned against a scaled, distorted model, and the bench must replicate the hack byte-for-byte to not lie.
3. **The Blender→GLB export pipeline v1 we shipped 7/25 is the correct design** per the research — the community hasn't even caught up to constraint-baking + NLA tracks. The remaining problems are upstream (Blender 5 slot gotchas, 99-action staging file risks) and downstream (the editor).
4. **Proposal:** replace mesh-scaling with the industry-standard viewmodel-FOV shader (depth-squash, reverse-Z aware), collapse the 3-places-per-gun data sprawl into marker-derived poses, and put probes on everything that's currently held together by discipline. Ranked plan in §6.

---

## 1. How the pros make FPS gun models (Blender, low-poly/PSX lens)

- **Direct low-poly, no high→low bake** for PSX style. Block over a reference/detailed study model (matches our existing model-from-reference law). Apply Mirror AFTER UV unwrap so both sides share texel space.
- **Moving parts are separate objects** — bolt/charging handle, magazine, trigger, slide. Even commercial PSX packs ship guns "separated into full, body, and magazine components." Rigid parts get 100% weight to one bone or object-parent — no weight blending. ✅ *We already do this.*
- **Pivot discipline:** what matters is bone/part origin on the mechanical axis (bolt bone along travel, mag bone at the well, trigger at hinge). Part rail origins must sit so local location = 0 is a clean slider. ✅ *We learned this the hard way (ch_rail).*
- **Apply loc/rot/scale before rigging and before export** — unapplied object transforms are the #1 documented cause of broken Godot imports (bind pose vs animation channels desync). Armature first, then mesh; clear `matrix_parent_inverse` (the exact arms-mesh trap we hit in the Soviet locker).
- **Names are API** — bone name = vertex group name; object names become Godot node names; renames break animation track bindings. ✅ *Matches pipeline v1's naming freeze.*
- **Clip structure convention** (industry set): Idle, Draw, Fire, Reload, Reload_Empty, ADS_In/Out, Inspect, Sprint — looped state anims + one-shot actions. Maps directly onto what we have; nothing to change.
- **Texel density, not geometry, is what gets oversized**: Polycount standard = ~125% texel density on close-view parts, ~150% on iron sights. Hands stay real-scale (≈190 mm); "chunky FPS arms" is an artifact of low viewmodel FOV, not scaled meshes.

**Sources:** Polycount FirstPersonWeaponUV wiki, CrimsongCat PSX gun pack, Xandev/ultidigi rigging guides, bugnet.io Godot import guides, item42/80.lv FPS rig tutorial.

## 2. Blender 5.0 specifics that matter to US

Our tooling already speaks the slotted-action API (`fix_m16_rig_contract.py` uses channelbags). New findings we did NOT know:

| Finding | Risk to us | Action |
|---|---|---|
| **Slot auto-assign can silently no-op or pick the WRONG rig's slot** — NLA/constraints match any slot with the right `target_id_type`. More armatures in one file = more wrong candidates. Our staging file has **19 rigs**. | HIGH — this is a fresh "teleport bug" vector | Export pre-flight asserts `anim_data.action_slot` is the expected slot, one slot per action |
| **glTF exporter 5.0.1 live bug (#2681):** actions with a stale/inactive "Manual Frame Range" (common on FBX-imported actions) can hide absurd end frames; range is computed across ALL actions → an armature with ~30 actions took **45 min to export**. We have **99+ actions** in `fp_arms_rifle.blend`. | HIGH — export time creep, phantom frames | Add a frame-range purge to the export script |
| 4.4-era NLA-Tracks export regression (skipped first track, duped last — #2519). Fixed upstream, but our exact 5.0.x needs verifying once. | MED | One-time check: exported clip list == NLA track list (validator already does this — confirm it ran on 5.0.1) |
| "Reset pose bones between actions" exporter option exists to stop pose bleed between clips | MED | Verify it's set in `export_viewmodel_clips.py`; keep the key-everything-on-frame-1 discipline anyway |
| Saving a 4.4+ file from Blender ≤4.3 **destroys all non-first slots** | LOW (he runs 5.0.1) | Never open armory files in old Blender — same class as the Godot 4.7-only law |
| Godot `.blend` direct import always uses ACTIONS mode + no constraint bake | Already known | ✅ Confirmed our GLB-only doctrine is right; never weaken it |
| 5.0 asset browser defaults to **Packing** (embed) not linking for custom libraries | LOW | Only matters if we start an asset-library workflow (§5) |

**Big picture from the research:** nobody on the internet has a better export pipeline than the one we shipped 7/25. The constraint-bake + NLA-tracks + validator design is ahead of every addon surveyed. **Do not replace it; harden around it.**

## 3. The sizing law (the direct answer to "what's the proper way")

### 3a. Guaranteeing every model is the same scale
1. Scene: Metric, **Unit Scale = 1.0**, meters. Critical: the glTF exporter **ignores** unit scale — it writes raw Blender numbers as meters. A cm-scaled scene "looks right" in Blender and lands 100× wrong in Godot (glTF-Blender-IO #365).
2. Every exported object: scale **(1,1,1)** applied, rotation applied, delta transforms zero, `matrix_parent_inverse` identity, armature scale 1.0 **before** skinning.
3. Godot import: Root Scale 1.0 always. Per-asset Root Scale hacks are how armories drift.
4. **Verify by dimensions, not by scale fields** — `obj.dimensions` reflects evaluated world size no matter where scale hides.

### 3b. What size — real-world dimensions, reference table
Model at true size; sanity-check overall length against reality (±few % — per-part PSX proportion exaggeration like our 0.65× mag is an art call and fine, but the WEAPON's overall length should hit the table):

| Weapon | Real length | | Weapon | Real length |
|---|---|---|---|---|
| M16A1 | **986 mm** | | AK-47 | **880 mm** |
| M14 | **1,126 mm** | | PPSh-41 | **843 mm** |
| M60 | **1,105 mm** | | RPD | **1,037 mm** |
| M79 | **731 mm** | | SKS | **1,020 mm** |
| M1911 | **216 mm** | | Mosin 91/30 | **1,232 mm** |
| RPG-2 | **1,200 mm** ✅(matches our armory) | | Arms: hand ≈190 mm, forearm ≈267 mm |

Note: our M16 ruler is 0.99293 units/m — sane (0.7% off true), fine to keep as the racking standard.

### 3c. How the gun gets its on-screen size — viewmodel FOV, NOT mesh scale
- **HL2:** world FOV 75, viewmodel FOV **54** — chosen specifically so weapons could be "modeled to correct scale without appearing distorted."
- **CS:GO/CS2:** world ~90, viewmodel FOV clamped **54–68**. The entire gun-size knob is FOV.
- **id/Quake:** separate render pass with a **depth hack** so the gun never clips walls.
- Real-scale guns put the stock behind the camera → near-plane clipping is inherent, and every engine solves it with one of two tricks:
  1. **Vertex-shader projection override + depth squash** (community standard in Godot 4, used by Battlefield/Dying Light-class games in their engines): override `PROJECTION_MATRIX` with the viewmodel FOV, then `POSITION.z = mix(POSITION.z, POSITION.w, 0.9)` to squash depth so the gun never clips world geometry. **Godot 4.3+ reverse-Z: must mix toward `POSITION.w`** (old tutorials mix toward 0.0 — broken). Reference implementation: majikayogames gist + Chafmere 4.3 fix.
  2. **SubViewport + second camera** (Garbaj-style): exact FOV control but costs a viewport, gun is always-on-top (no world shadow interplay), and the FOV mismatch displaces the apparent muzzle — flash/tracer origins must come from world space.
- Shader route (1) is the fit for us: no extra viewport on a PS2-budget frame, and it composes into the existing gun material. One real caveat: it must be merged into whatever PSX material the viewmodels use (a projection override is per-material).

## 4. Why OUR viewmodel editor is going "worse to worse" — root causes

The bench itself (`scripts/weapons/viewmodel_editor.gd`, 841 lines) is decent tooling. It's sitting on four structural faults:

**RC1 — The scale hack poisons everything downstream.** `weapon_holder.gd:973-978` computes `ratio = tan(75/2)/tan(viewmodel_fov/2)` (clamped 0.6–2.2) and multiplies it into `weapon_model.scale` (:919-920). Consequences, all live today:
- Every hip/ads pose, bore vector, and eye-relief number is tuned against a **distorted model**; change a gun's `viewmodel_fov` and every one of its 6 tuned vectors is invalid.
- MuzzlePoint scales with the mesh → hip tracer origin subtly disagrees with the world.
- Near-plane clipping isn't solved, so a **pitch hack** patches it (`PITCH_OFFSET_*`, weapon_holder.gd:152-156) — the gun teleports up when you look down.
- The bench must copy the hack exactly (viewmodel_editor.gd:283, the "WYSIWYG CONTRACT") — a hand-maintained coupling that CLAUDE.md has to scream about because nothing enforces it.

**RC2 — Per-gun truth lives in 3 places and they disagree.** Pose data: 6 hand-dialed vectors in the `.tres`. A SECOND baked offset in each `*_arms_viewmodel.tscn` (M16's Model node carries a 180° flip + **hardcoded −1.81 m Y drop**). A THIRD source (GLB grip/sight markers) that could derive most of this but is only used by the V-key helper. Plus `bore_dir`/`ads_bore_dir` as a parallel aim-zero system because muzzle empties aren't aimed. Result: adding a gun = manual numbers in ≥3 files, and 4 of 15 guns still carry copy-paste stub ADS poses (`mosin`/`rpg2` share the literal same placeholder vector; mosin's ads_rotation == its hip_rotation).

**RC3 — Dead and half-wired fields erode trust.** `viewmodel_scale` is declared (`weapon_data.gd:95`), **displayed in the bench HUD** (:638), carried by 6 .tres files — and never applied anywhere. The War Room ruled "wire it" and it never happened. The bench shows a number the game ignores; that is precisely the "editor is lying to me" feel.

**RC4 — The contract only covers a quarter of the armory.** Pipeline v1's manifest/validator protect **3 of ~12** GLB guns (m16/ak/m14). The other 9 GLBs predate every safety we built, 4 weapons have no GLB at all (m79, m72_law, rpg7, shotgun), 3 have `.tres`↔scene name mismatches (m1911→colt45, shotgun→ithaca, ppsh41→ppsh), and the M14 fittings sit orphaned at root level (known `_debt`).

## 5. One staging file vs per-weapon files (flagging, not proposing)

Research says the studio standard is per-asset files + linking; our one 99-action, 19-rig `fp_arms_rifle.blend` is the solo-dev norm but concentrates risk — the M16 join break was exactly the failure class, and export cost grows with total action count (the 45-min bug). **I am NOT proposing a split now** — the staging file is the established workflow and the foundation-protection law applies. The mitigations in §6 (slot asserts, frame-range purge, per-gun strict export) buy most of the safety without touching how Caleb works. If the file keeps biting us, the fallback is: per-weapon .blend as export source, staging file only for cross-rig pose work.

## 6. Proposed next steps (ranked; nothing started)

**P1 — Kill the scale hack: real-scale viewmodels + viewmodel-FOV shader.** Replace `_lens_ratio` mesh scaling with the reverse-Z depth-squash projection shader merged into the viewmodel material. Gun renders at its own FOV, never clips walls, pitch hack dies, MuzzlePoint stays truthful, and `viewmodel_fov` becomes a real per-gun knob instead of a mesh-distorter. The bench sheds the copied hack — WYSIWYG becomes structural instead of disciplinary.
*Tradeoffs:* every tuned pose must be re-tuned (only M14 is fully tuned, so the sunk cost is one gun); touches ADR-004 territory (hip/ADS FOV contract) → needs a decree before build; shader must compose with the PSX material.

**P2 — One source of truth per gun: derive poses from GLB markers.** Promote the V-key logic: hip/ADS poses computed from grip/sight/muzzle markers at load (or at import via a post-import script), `.tres` stores only per-gun *offsets* from the derived pose. Kill the baked `.tscn` Model offsets (bake orientation into the GLB at export — the exporter already stages transforms). Delete or wire `viewmodel_scale` (with P1 it should die). Aim the muzzle empties in Blender so `bore_dir` collapses into the marker contract.
*Tradeoffs:* requires sight markers on all guns (only the finished armory guns have them — known broken link); front-loads Blender work before editor work pays off.

**P3 — Probe the discipline.** (a) Sync-contract test: assert bench camera == player camera (Y, FOV, holder transform) in the suite. (b) Scale gate in `--strict` pre-flight: `dimensions` within ±2% of the §3b reference table, scale==1, identity parent-inverse (fossil-law-style ratchet). (c) Stub-pose detector: fail validation when `ads_rotation == hip_rotation` or a known placeholder vector appears.

**P4 — Blender 5 hardening of the exporter** (small, immediate): purge manual frame ranges before export; assert expected `action_slot` per rig; confirm "reset pose bones between actions"; one-time verify of clip-list == NLA-track-list on 5.0.1.

**P5 — Close the coverage gap:** extend the manifest to all 12 GLB guns, re-export the 9 stale ones through `--strict`, fix the M14 root-level fittings debt, resolve the 3 name mismatches, then author the 4 missing weapons (m79/m72_law/rpg7/shotgun) through the hardened pipeline.

**P6 — Art passes with Caleb** (his eye, my staging): real ADS poses for the stub guns; sight-marker pass on the armory.

**Suggested order:** P4 (hours, pure safety) → P3 (locks the floor) → P1 decree + build → P2 → P5 → P6. P1 before P2 because pose derivation only makes sense against an undistorted model.

---

*Sources: Godot docs (importing 3D scenes, Camera3D), glTF-Blender-IO issues #365/#828/#1532/#2519/#2681, Blender 5.0/4.4 release notes + slotted-action upgrade guide, majikayogames viewmodel shader gist + Chafmere reverse-Z fix, HL2/CS:GO viewmodel FOV documentation, Polycount weapon wiki, weaponsystems.net/Military Factory/GlobalSecurity dimension pages, Blender Studio asset pipeline docs.*
