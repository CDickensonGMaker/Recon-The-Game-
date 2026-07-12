# BLENDER WORK ORDER â€” VC rig parity with us_grunt_v2
**Bead:** RECONgame-bv4q Â· **Raised:** 2026-07-12 (Summoner playtest) Â· **Runs AFTER:** the jungle
vegetation batch currently in progress. Do not interrupt the jungle work for this.
**For:** the session holding the Blender MCP. Everything below is measured, not guessed â€” the
numbers come from `tools/probe_rig_compare.gd` and `tools/probe_silhouette.gd` (run them to verify
your own work; they are the acceptance test).

## The finding in one line
The rigs are IDENTICAL (41 bones, same rest proportions to the mm, same scale, same 100-clip
library). Every VC/grunt difference the Summoner feels â€” *"structurally they don't match, animations
aren't as smooth"* â€” is **mesh authoring**, not rigging, not code. The engine side is done and
defensive; these three fixes are pure Blender.

## Task 1 â€” JOIN THE VC BODY (highest value, do first)
**Problem:** the VC exports render **8 separate skinned meshes** â€” `vc_torso`, `vc_arm_l`,
`vc_arm_r`, `vc_head`, `vc_leg_l`, `vc_leg_r`, `vc_foot_l`, `vc_foot_r`. The grunt renders **one**
continuous skinned mesh (`us_grunt_joined`). Separate surfaces don't share a skin, so on every
animated frame the shoulder/hip/neck joints **gap open and interpenetrate** â€” the same clip that
looks clean on the grunt looks broken on the VC.

**Do:** join the 8 body parts into a single skinned mesh named **`vc_guerilla_joined`** (weld
seams, keep weights), matching the gib-rig contract the grunt already follows:
- joined body = the LIVE render mesh (visible)
- pre-cut region donors = hidden in Blender (the engine re-hides them on import anyway)
- gear (`rice_hat`, `*_world` weapons) stays bone-attached and separate â€” do NOT join gear in

**Applies to all six VC exports:** `vc_guerilla`, `_m16`, `_mosin`, `_ppsh`, `_rpd`, `_rpg`.

**Accept when:** `godot --headless --path . -s res://tools/probe_silhouette.gd` reports
`parts = 1` for every vc_* unit (grunt already reads 1).

## Task 2 â€” VC-SHAPED GIB DONORS + CAPS AT THE JOINTS
**Problem A:** the VC exports carry the **grunt's** donor meshes (`grunt_head`, `grunt_forearm_l/r`,
`grunt_uparm_l/r`, `grunt_leg_l/r`, `grunt_torso`). Pop a VC arm in game and a **US soldier's arm**
flies off.
**Problem B:** the `cap_*` wound caps are skinned **off their joints** â€” they cluster at the feet
and in mid-air (this is why the runtime currently hides all caps until a limb pops; a revealed VC
stump lands in the wrong place).

**Do:** author VC-geometry donors cut from the VC body, named exactly as the contract expects
(`GibSystem.REGIONS`): `grunt_head`, `grunt_forearm_l`, `grunt_forearm_r`, `grunt_leg_l`,
`grunt_leg_r` (+ `grunt_uparm_l/r`, `grunt_torso` for completeness). **Keep the names** â€” they are
the engine contract; only the geometry changes. Skin each `cap_*` (`cap_head`, `cap_forearm_l/r`,
`cap_uparm_l/r`, `cap_leg_l/r`, `cap_torso`) to the bone at its own joint so a revealed stump sits
in the wound.

**Accept when:** `res://tests/test_gore_rig.tscn` still PASSes, and a VC limb popped in
`dummy_lab.bat` sheds VC-colored geometry with the stump cap sitting in the wound.

## Task 3 â€” MASS / PRESENCE (Summoner's call, not a bug)
Measured: rendered height matches (VC **1.720m** vs grunt **1.741m**, both soles on the ground),
but VC **torso depth is 0.219m** vs the grunt's **0.399m** â€” literally half as thick front-to-back,
and the VC wears no ruck/bandolier/helmet. Beside a gear-laden grunt he reads as *small* even
though he is the same height.

**Ask the Summoner before changing this** â€” lean VC vs bulky GI is legitimate silhouette contrast
(and historically true). If he wants more presence: thicken the torso toward ~0.30m depth and/or
add a chest rig / satchel / ammo pouches as bone-attached gear (gear must stay OUT of the joined
body mesh and OUT of hitzone harvesting â€” the engine already excludes gear by name; keep the
existing hint words: hat/pack/pouch/belt/strap/webbing/bandolier).

## Task 4 â€” `laying_breathless` sits 1.02m in the air
Every `death_*` clip lands the body on the floor; **`laying_breathless`** (the downed/bleeding-out
pose) lies the man **1.02m above it** (`tools/probe_lying_height.gd`). The runtime now ground-clamps
that pose, so this is no longer a visible bug â€” but the clip is wrong at the source and the clamp is
a patch. Re-author the pose on the floor in the shared library and the clamp becomes a no-op.

**Accept when:** `probe_lying_height.gd` reports `lowest bone y â‰ˆ 0` for `laying_breathless`.

## Engine side: already done, do not redo
Height is ruled by the skeleton (bind-vs-rest export skew is compensated), hitzones auto-fit the
mesh, gibs scale correctly, caps hide until a pop, dead men always reach the ground. **A re-export
that fixes the source data makes those compensations no-ops â€” it will not break them.** Just
re-export; no code changes needed on landing.


---

# CLOSED 2026-07-12 (Blender session) — results, and TWO CORRECTIONS

## Task 1 — JOIN THE VC BODY — DONE
8 loose meshes -> `vc_guerilla_joined` (203 verts, 402 tris, 34 vgroups, 45 seam
verts welded, 0 unweighted). All six VC exports now report `parts = 1`
(probe_silhouette). Verified deforming clean at the shoulders/hips/neck in a run
pose. `export_vc_guerilla.py` patched: the face-atlas UV writer looked up the
object `vc_head`, which the join destroys — it would have silently no-op'd and
given every VC the same face.

## Task 2 — CORRECTION: PROBLEM A WAS A FALSE ALARM
**The VC was NOT carrying the grunt's donor meshes.** Measured two ways:
  * source blend: every `grunt_*` donor vert is 100% coincident with the VC body
  * shipped GLB: VC `grunt_forearm_l` = 38 verts, grunt's = 46 — different meshes
The donors were already VC-cut with VC materials (BlackPajama/Skin_VC). Only the
NAMES are `grunt_*`, because those names ARE the GibSystem.REGIONS contract.
Nobody was shedding a US soldier's arm. The claim was inferred from the naming,
not measured — the cited probes (rig_compare/silhouette) don't look at donors.

## Task 2 — PROBLEM B WAS REAL, AND IT WAS WORSE ON THE GRUNT
Caps sat 1.4–2.2m off their joints on the VC. But the deeper bug hit BOTH units:
a cap skinned to the SEVERED bone collapses with the limb (dismember() zeroes the
bone chain), so the stump renders hollow. A cap must ride the severed bone's
PARENT — the bone still standing after the cut.
  * VC: all 7 caps repositioned onto their joints; `cap_head` moved off `Neck`
    (which collapses) onto `Spine2`.
  * **GRUNT (the truth source) had FIVE broken caps**: cap_head rode `Neck`,
    cap_forearm_l rode `LeftForeArm`, cap_leg_r rode `RightUpLeg`, plus both
    uparm caps — every one of them a bone that gets collapsed. And `cap_leg_l`
    was a ZERO-VERT HUSK: the object existed (so nothing complained) but exported
    to nothing, so a popped left leg rendered hollow.
  * `tests/test_gore_rig.tscn` PASSED through all of this — it only asserts the
    caps exist and get revealed, not that they survive the collapse. Do not trust
    it alone.
New tool: `tools/fix_wound_caps.py` — run it on any character blend.

## Task 3 — MASS/PRESENCE — SUMMONER RULED: LEAVE HIM LEAN
Decision 2026-07-12: the lean VC vs bulky GI silhouette is legitimate contrast and
historically true. VC stays at 0.219m torso depth. **This is a decision, not a
bug — do not "fix" it.** Presence comes from bone-attached GEAR instead.

## Task 4 — laying_breathless — DONE
Re-authored on the floor at the source: lowest bone 1.073m -> -0.00m, in
us_grunt_v2.blend (anim truth source), vc_guerilla_v2.blend and anim_library.blend.
The runtime ground-clamp is now a no-op, as predicted. Tool: `tools/fix_laying_breathless.py`.

## Why this went unnoticed for months
`probe_silhouette.gd` PRINTED `parts = 8` and exited 0. Nothing was watching.
It now FAILS the run (exit 1) when a character renders as more than one skinned
body part, so the next unit cannot regress silently.
