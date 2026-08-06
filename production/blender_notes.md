# RECONgame Blender conventions (project-specific)

Blender-universal lessons live in `~/.claude/architect_knowledge/blender_lessons.md`,
not here. This file is RECONgame's own conventions and asset-specific history.

---

## Huey (`assets/us/vehicles/huey_v3.blend`, `huey_v3_transport.blend`)

**2026-08-05 - full airframe reshape to match the `Bell Huey.fbx` study.**

- Pinned dims (verified, both files): length 12.77 · half-width 1.310 (2.62 total,
  correct to real UH-1H - the study's 1.439 is ~10% wide, deliberately NOT matched) ·
  lowest z 0.000 · main rotor 14.63 · tail rotor 2.59 · nose = +Y, boom = -Y.
- **Study overlay contract:** `REF_Bell_Huey`, `REF_Top_Rotor`, `REF_Back_Rotor`,
  `REF_Inside1` live ONLY in `huey_v3.blend`, `display_type='WIRE'`,
  `hide_render=True`, x centred on 0, nose-aligned to our fuselage (y=6.385),
  lowest z 0.000. A prior pass had them parked at x≈+12 (beside, not overlaid) -
  re-check this position on any resave, it silently drifts if a script re-imports.
  Never merge, copy, or ship this geometry.
- **Roofline:** single continuous loft (`fuselage_fwd` nose-to-y=-0.815,
  `fuselage_aft` = the preserved boom, y<=-0.815 unchanged) sampled directly off
  `REF_Bell_Huey` via per-station raycasts (roof = topmost hit straight down,
  belly = bottommost hit straight up, half-width = farthest horizontal hit,
  scaled by `1.310/measured_max_hw`). Roof holds 2.45-2.73 continuous, no dome -
  **3.198 is the tail FIN, not the fuselage top; do not build the body to it.**
  A small mast fairing (cone, ~0.24 m tall) sits on the roof peak - that is the
  only place "ours" is meant to exceed the study's line.
- **Cargo doors:** cut with a Boolean DIFFERENCE box that spans the FULL fuselage
  width in X (must exit the solid on both sides or it leaves a spurious cap -
  see the Blender-universal ledger) at y 1.995-4.335, z 0.65-1.99. Belly at that
  Y-range sampled ~0.32-0.43 - well clear of the door's z0, so the door does not
  clip the belly. `door_frame_l/r` in both files already matched this footprint.
- **Rotor node contract (owned by `scripts/vehicles/helicopter.gd`):**
  `main_rotor_node` default `"New_Blade_1"`, `tail_rotor_node` default
  `"New_TailBlade_2_002"` - `find_child()` by that literal name, then
  `rotate_y`/`rotate_x` in code every frame. Built ours to match those defaults
  exactly (empty pivot on the mast/shaft axis, parenting the blade + hub +
  flybar meshes) so `huey.tscn` needs no export string changes. Never bake a
  spin AnimationPlayer - the code comment says it fights the imported one.
  Blade droop: 4 degrees, a rest-pose bend applied to blade mesh verts only
  (never on the pivot/spin node).
- **Tri budget:** airframe alone (fuselage+tail fin+elevator+fairing+both
  rotors), reported separately from interior/guns - measured 3360 tris both
  files, well under the ~10k soft ceiling.
- Interior (seats, benches, racks, floor, transmission bulkhead/hump, skids,
  pintles) untouched in this pass - do not reshape it without a fresh War Room
  ruling; it was declared final ("shape correct Huey with blade animations that
  fits around the declared interior").
