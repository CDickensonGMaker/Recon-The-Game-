# BLENDER WORK ORDER — VC rig parity with us_grunt_v2
**Bead:** RECONgame-bv4q · **Raised:** 2026-07-12 (Summoner playtest) · **Runs AFTER:** the jungle
vegetation batch currently in progress. Do not interrupt the jungle work for this.
**For:** the session holding the Blender MCP. Everything below is measured, not guessed — the
numbers come from `tools/probe_rig_compare.gd` and `tools/probe_silhouette.gd` (run them to verify
your own work; they are the acceptance test).

## The finding in one line
The rigs are IDENTICAL (41 bones, same rest proportions to the mm, same scale, same 100-clip
library). Every VC/grunt difference the Summoner feels — *"structurally they don't match, animations
aren't as smooth"* — is **mesh authoring**, not rigging, not code. The engine side is done and
defensive; these three fixes are pure Blender.

## Task 1 — JOIN THE VC BODY (highest value, do first)
**Problem:** the VC exports render **8 separate skinned meshes** — `vc_torso`, `vc_arm_l`,
`vc_arm_r`, `vc_head`, `vc_leg_l`, `vc_leg_r`, `vc_foot_l`, `vc_foot_r`. The grunt renders **one**
continuous skinned mesh (`us_grunt_joined`). Separate surfaces don't share a skin, so on every
animated frame the shoulder/hip/neck joints **gap open and interpenetrate** — the same clip that
looks clean on the grunt looks broken on the VC.

**Do:** join the 8 body parts into a single skinned mesh named **`vc_guerilla_joined`** (weld
seams, keep weights), matching the gib-rig contract the grunt already follows:
- joined body = the LIVE render mesh (visible)
- pre-cut region donors = hidden in Blender (the engine re-hides them on import anyway)
- gear (`rice_hat`, `*_world` weapons) stays bone-attached and separate — do NOT join gear in

**Applies to all six VC exports:** `vc_guerilla`, `_m16`, `_mosin`, `_ppsh`, `_rpd`, `_rpg`.

**Accept when:** `godot --headless --path . -s res://tools/probe_silhouette.gd` reports
`parts = 1` for every vc_* unit (grunt already reads 1).

## Task 2 — VC-SHAPED GIB DONORS + CAPS AT THE JOINTS
**Problem A:** the VC exports carry the **grunt's** donor meshes (`grunt_head`, `grunt_forearm_l/r`,
`grunt_uparm_l/r`, `grunt_leg_l/r`, `grunt_torso`). Pop a VC arm in game and a **US soldier's arm**
flies off.
**Problem B:** the `cap_*` wound caps are skinned **off their joints** — they cluster at the feet
and in mid-air (this is why the runtime currently hides all caps until a limb pops; a revealed VC
stump lands in the wrong place).

**Do:** author VC-geometry donors cut from the VC body, named exactly as the contract expects
(`GibSystem.REGIONS`): `grunt_head`, `grunt_forearm_l`, `grunt_forearm_r`, `grunt_leg_l`,
`grunt_leg_r` (+ `grunt_uparm_l/r`, `grunt_torso` for completeness). **Keep the names** — they are
the engine contract; only the geometry changes. Skin each `cap_*` (`cap_head`, `cap_forearm_l/r`,
`cap_uparm_l/r`, `cap_leg_l/r`, `cap_torso`) to the bone at its own joint so a revealed stump sits
in the wound.

**Accept when:** `res://tests/test_gore_rig.tscn` still PASSes, and a VC limb popped in
`dummy_lab.bat` sheds VC-colored geometry with the stump cap sitting in the wound.

## Task 3 — MASS / PRESENCE (Summoner's call, not a bug)
Measured: rendered height matches (VC **1.720m** vs grunt **1.741m**, both soles on the ground),
but VC **torso depth is 0.219m** vs the grunt's **0.399m** — literally half as thick front-to-back,
and the VC wears no ruck/bandolier/helmet. Beside a gear-laden grunt he reads as *small* even
though he is the same height.

**Ask the Summoner before changing this** — lean VC vs bulky GI is legitimate silhouette contrast
(and historically true). If he wants more presence: thicken the torso toward ~0.30m depth and/or
add a chest rig / satchel / ammo pouches as bone-attached gear (gear must stay OUT of the joined
body mesh and OUT of hitzone harvesting — the engine already excludes gear by name; keep the
existing hint words: hat/pack/pouch/belt/strap/webbing/bandolier).

## Task 4 — `laying_breathless` sits 1.02m in the air
Every `death_*` clip lands the body on the floor; **`laying_breathless`** (the downed/bleeding-out
pose) lies the man **1.02m above it** (`tools/probe_lying_height.gd`). The runtime now ground-clamps
that pose, so this is no longer a visible bug — but the clip is wrong at the source and the clamp is
a patch. Re-author the pose on the floor in the shared library and the clamp becomes a no-op.

**Accept when:** `probe_lying_height.gd` reports `lowest bone y ≈ 0` for `laying_breathless`.

## Engine side: already done, do not redo
Height is ruled by the skeleton (bind-vs-rest export skew is compensated), hitzones auto-fit the
mesh, gibs scale correctly, caps hide until a pop, dead men always reach the ground. **A re-export
that fixes the source data makes those compensations no-ops — it will not break them.** Just
re-export; no code changes needed on landing.
