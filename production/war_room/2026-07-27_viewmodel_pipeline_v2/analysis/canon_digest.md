# Lane 4 — Local canon digest (read-only sweep, 2026-07-27)

Full contract chain and rulings verified against: ADR-034, ADR-004, viewmodel_pipeline_deep_dive
_2026-07-26.md, viewmodel_anim_defects_2026-07-26.md, tools/*, GodotPrompter index.

## Pipeline of record
`fp_arms_rifle.blend` (ONE staging file, 19 rigs) → `tools/viewmodel_manifest.json` ("Names are API")
→ `blender -b` per-gun export (bake CHILD_OF motion to TRS, NLA_TRACKS, strict pre-flight: scale gate,
slot asserts, wreckage catcher >2.5m from hand.R) → `validate_viewmodel_glb.py` (clip set, markers,
non-uniform-scale gate, self-test = 2026-07-25 break signature) → `sync_weapon_timers.py` (GLB accessors
→ .tres timers, drift fails validation) → Godot GLB + wrapper .tscn + .tres poses.

## Settled rulings that BIND a redesign
- "Do not replace the pipeline; harden around it" (deep-dive verdict).
- ADR-034: real scale + lens shader, one code path, never scale a mesh; Amendment A: timers authored
  to the clip, export writes the number, never hand-edit.
- Animation QUALITY authoring is the Summoner's hands (2026-07-26 ruling; the reverted AK headless bake).
- ADR-015: look verified only by Summoner playtest.
- Forbidden: apply-all-transforms/origins-to-cursor on fp_arms_rifle.blend (defects §I).
- Fossil law: replacement ships only with the predecessor deleted.
- Grandfather ratchets only shrink (stub ADS poses, fossil baseline).

## Gaps canon itself admits
- Manifest/validators protect 4 of ~15 guns; 9 GLBs predate every safety; 4 weapons have no GLB.
- 3-places-per-gun data sprawl (.tres pose + .tscn wrapper offset + GLB markers); P2 marker-derived
  poses recorded in ADR-034 next-wave, unbuilt.
- Standing animation defects queue (Summoner's hands): AK handoff pairing, frozen hand.R clips, M14
  teleports, PPSh transplant clips, M16 2.64° root cant.
- Clips never confirmed through weapon_holder's real reload path in game.
- Frozen-hand check not yet folded into the Godot-side suite; `markers_under_gun` claim false-in-letter
  for ak/m14.

## Knowledge base recommends, not currently used
- Godot 4.4+ Animation Markers (named event points in clips — mag-out, bolt-home SFX) instead of timer math.
- Call Method tracks for frame-exact events (shell eject, mag drop).
- Skeleton modifiers: SpringBoneSimulator3D (sling sway), TwoBoneIK3D / BoneConstraint3D (4.6+ runtime
  hand-to-marker pinning — a possible runtime second layer against hands-in-gun).
- Import-dock per-clip loop modes / trimming never stated in canon — contract stops at the validator.
