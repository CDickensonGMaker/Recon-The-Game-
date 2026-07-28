# Lane 2 — Blender→Godot 4.x animated-weapon pipeline (web research, 2026-07-27)

## Bones vs object constraints — FORMAT FACT
- glTF 2.0 has NO constraints, drivers, or parent-inverse. Only node TRS curves, skinned joints, morphs
  survive. Everything constraint-driven must be baked (we already do — `export_viewmodel_clips.py`).
- CHILD_OF confirmed broken through export even with keyed influence:
  https://forum.godotengine.org/t/exporting-blender-gltf-format-with-child-of-bone-constraint/114602
- Community consensus: parts on BONES of one armature; multi-armature + cross-armature CHILD_OF is the
  classic failure mode. A thread that MIRRORS our situation (Arms_Rig + Armature_Weapon + 3 CHILD_OF,
  bleed between clips): https://forum.godotengine.org/t/best-workflow-for-fps-weapon-animations-with-multiple-armatures-in-blender-godot/133757
- Apply-all-transforms before export is the "#1 cause" fix for broken imports; non-uniform scale breaks
  Skeleton3D. (Our validator already gates non-uniform scale on animated nodes; the apply-transforms
  advice is FORBIDDEN wholesale on our file — defects doc §I — the bake-by-world path is our equivalent.)

## Clips — CONVENTION
- One action per clip, pushed to NLA; strip name = Godot animation name; Animation Mode = NLA Tracks.
- **Blender 4.4+ slotted-action regression: "Actions" export mode broken; NLA Tracks is the reliable
  path** (verified 4.4.3): https://blenderartists.org/t/new-4-4-animation-system-broke-my-godot-workflow/1591332
  → our NLA_TRACKS choice is not just right, it is mandatory on Blender 5.
- Godot's .blend auto-import hardcodes Animation Mode = Actions → GLB-only doctrine validated again.
  https://github.com/godotengine/godot-proposals/issues/11887
- **THE BLEED RULE (this session's M16 chandle bug, documented in the wild): keyframe ALL animated
  channels at first+last frame of every action, otherwise unkeyed channels inherit values from whatever
  was active.** Blender's exporter drops constant OBJECT channels unless
  `export_optimize_animation_keep_anim_object=True` — separate switch from
  `export_optimize_animation_size`. Sources: supermatrix.studio workflow guide, forum 133757,
  https://github.com/godotengine/godot/issues/63547
- Naming: `-loop`/`cycle` suffix (lowercase) sets loop flag on import; `-noimp` strips nodes.

## Godot-side structure
- BoneAttachment3D standard for hand-bone attachment; hazard: bone roll differs per animation source.
- Two camps: (a) shared arms + runtime assembly, (b) per-weapon GLB with arms duplicated. Majority
  opinion: (b) survives glTF cleanest — WHAT WE ALREADY DO.
- AnimationTree OneShot has known engine bugs for fire/reload (66495, 69063); many FP projects drive
  AnimationPlayer directly with play() + animation_finished — WHAT WE ALREADY DO (weapon_holder).
- Empties export as plain glTF nodes at correct transforms — our marker contract rides this.

## Validation/automation
- Headless `blender -b` export drivers + CI validation is established indie practice
  (https://drcodes.com/posts/github-actions-blender-automate-game-assets-in-30-minutes). No first-party
  GLB contract-test framework exists; bespoke GLB-parsing probes (ours) are the observed pattern.

## Viewmodel rendering
- Canonical Godot 4: projection-override vertex shader + depth squash; breaks shadow casting → shadows
  off + fake shadow. ADR-034 already implements exactly this, including the shadow rule.

## Synthesis-grade
Our pipeline already matches convention on: GLB-only, NLA_TRACKS, bake-to-TRS, headless driver,
per-weapon GLB, AnimationPlayer-direct, marker empties, validators. GAPS vs convention: (1) the
keep-anim-object flag / bookend-keys rule — LIVE BUG; (2) parts as objects + CHILD_OF is the documented
failure-prone road — we survive it only because we bake; the bake is load-bearing and must stay gated;
(3) no per-clip channel-coverage validation.
