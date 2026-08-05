# Animation QC Ledger (blender-overseer)

Self-improving memory for headless animation QC on `assets/shared/anim_library.blend`
(PSXRig) and, eventually, the arms-only FP viewmodel rigs. Read this at the start of
every QC session; append to it at the end. See `.claude/agents/blender-overseer.md`
for the loop this supports and `rigmap.PSXRig.yaml` for the bone map.

## 2026-07-31 — bootstrap session

### The rig's world axes are NOT what you'd guess, and MUST be measured, not assumed
`Base_Human` (the 203-vert PSX mesh) and `PSXRig` sit in standard Blender Z-up world
space (Z = height, X/Y = horizontal) — but only once you set an actual action + frame
before reading the bounding box. Reading `mesh.bound_box` or an evaluated depsgraph
bbox with NO action explicitly assigned picks up whatever pose was last saved active
in the .blend, which can be a bent-over non-rest pose and gives you a bogus, tiny,
scrambled-looking "bounding box" that leads to a broken camera calibration (this
happened on the very first render attempt this session — the render showed a folded-up
mess that had nothing to do with any real animation defect, it was a camera bug).
**Always call `qc.set_pose(rig, action, frame)` (or explicitly assign an action AND
`scene.frame_set()`) before measuring or rendering — never trust an ambient bbox.**

### A "front" camera is not a fixed world axis for this library — it's per-clip
Standing idles (`idle`, `idle_unarmed*`, `idle_crouching`) face a consistent direction
and a single front/side camera pair reads them fine. But **aiming poses are bladed**
(the character turns side-on to present a smaller silhouette while sighting) — a
camera looking straight down the world axis a standing-idle "front" would use ends up
looking almost straight down the presented arm, foreshortening it into a scrambled
mess that LOOKS broken but isn't (false positive). The true defect only showed up from
an oblique 3/4 angle (45° off that axis). **Render a turntable (`render_turntable.py`,
6-8 angles around world Z at a fixed radius/height) for anything holding a weapon, not
just a front/side pair — check the obliques (±45°) specifically, they catch what pure
front/side miss, and don't verdict BROKEN off a single foreshortened angle either.**
Confirmed on `idle_aiming` frame 6: angle 0°/180° (front/back) look scrambled, 90°/270°
(true side) look clean, 315° (3/4 front) shows the real defect (right elbow overlapping
torso). All three views are of the exact same pose.

### Live pose edits are silently clobbered while an action is still assigned
Setting `pose_bone.rotation_quaternion = ...` directly and then rendering does
**nothing** if that bone still has an active, assigned Action driving that channel —
Blender's depsgraph re-evaluates the F-curve on the next update/render and overwrites
the manual edit. This wasted a full test cycle (identical renders for every "candidate"
angle) before the cause was found. **To test a pose change, either (a) clear
`rig.animation_data.action = None` first, or (b) edit the actual F-curve keyframe
values on a scratch copy of the action (`action.copy()`), which is what you have to do
for the real fix anyway — test that way from the start.**

### The `_fixed` action-swap in `export_anim_library.py` is a live footgun
The export script silently replaces `<name>` with `<name>_fixed` at export time (see
`tools/export_anim_library.py:29-35`) if a `_fixed` sibling action exists. Found two
fossils of this: `idle_aiming_fixed` and `idle_crouching_aiming_fixed` existed
alongside their base actions, dated from some earlier session. Headless render check
showed **both `_fixed` variants are worse than the base action** — arms cross up near
the face/shoulder, completely losing the "gripping a rifle" read from every camera
angle checked, even though `idle_crouching_aiming` (the base) was already clean and
needed no fix at all. Left in place, either fossil would have **silently overwritten
this session's real fix** (and the already-clean `idle_crouching_aiming`) on the next
export, with no error and no diff visible outside Blender. **Deleted both** as part of
shipping the idle_aiming fix (fossil law: don't leave a dead "fix" the export pipeline
will resurrect). `firing_rifle_fixed` and `reloading_fixed` still exist and were NOT
touched or audited for pose quality this session — same swap risk applies to them,
flagged for a future pass, not fixed here (out of scope: not idle-family, not verified
broken).

### PSX idle clips are NOT uniformly sparse-keyed "held poses"
Hard rule 3 describes the house style as hard held poses / low keyframe counts — true
for some clips (`idle`, `idle_unarmed_4`) but **`idle_aiming` has ~27 keyframes across
64 frames on just the RightArm rotation channel alone**, a continuous subtle sway, not
a single static hold. A fix that only re-keys frame 1 (or the single flagged frame)
leaves the defect present on every other sampled frame. **When fixing a swaying/breathing
idle, apply the correction to EVERY existing keyframe of the offending channel (same
delta rotation composed onto each), not just the frame that was screenshotted.**

### idle_aiming right-elbow fix — the fix of record
`mixamorig:RightArm` rotation_quaternion, all 27 keyframes, corrected by composing a
`-10°` rotation around the bone's own local X axis, **post-multiplied**
(`new = orig_quat @ Quaternion((1,0,0), radians(-10))`) — i.e. rotate further in the
bone's own currently-posed frame, not the parent/world frame. `RightForeArm` was left
untouched (rigid child follow — the whole forearm+hand swings out together with the
upper arm, which is what "rotate the elbow out" means for a 2-bone chain with no IK).
Verified clean at a0/a45/a90/a270/a315 and frames 1/6/32/64 after the fix (previously
goofy only at ~a315, frame-independent since the pose barely changes across the sway).
**If a future elbow-into-torso goof shows the same shape (aiming pose, elbow tucked),
try this exact axis/sign/order first** — X axis on the upper-arm bone, post-multiply,
8-12° magnitude, before hunting for a different axis by trial render.

### Objective bone-to-spine-centerline distance is a weak proxy, don't trust it alone
Built `elbow_torso_clearance()` (forearm-midpoint to hips->spine2 line-segment
distance) as a fast objective assist. It did NOT reliably separate goofy from clean:
`idle_aiming` (goofy) measured 0.198m on the right elbow; `idle_crouching_aiming`
(visually clean) measured a near-identical 0.205m. **The real defect is mesh-silhouette
overlap, which depends on local surface orientation, not just distance-to-centerline —
always confirm with the visual pass, use the metric only to prioritize which frames/
clips to actually look at.**

## Verdicts on record (idle family, full sweep, 2026-07-31)
| Action | Verdict | Note |
|---|---|---|
| idle | CLEAN | checked f1, f31, all 6 turntable angles |
| idle_aiming | was GOOFY, FIXED | right elbow into torso, ~a315, f1-64 (whole sway); fixed this session |
| idle_aiming__smg | CLEAN | f1, f32 |
| idle_crouching | CLEAN | f1, f32 |
| idle_crouching__smg | CLEAN | f1, f32 |
| idle_crouching_aiming | CLEAN | f1, f30; near-identical elbow clearance to the goofy idle_aiming case but visually clean — see the clearance-metric note above |
| idle_unarmed | CLEAN | f1, f60 |
| idle_unarmed_2 | CLEAN | f1, f150 (298-frame clip, very slow sway, checked start+mid) |
| idle_unarmed_3 | CLEAN | f1, f50 |
| idle_unarmed_4 | CLEAN | f1, f40 (squat/haunches idle) |
| idle_unarmed_5 | CLEAN | f1, f34 (lean idle) |

Objective pass (NaN/Inf, quat normalization, rotation-mode mismatch, scale drift,
exploded bone, loop pop, teleport pop) came back clean on all 11 idle-family actions —
this was purely a visual/GOOFY-class defect, no data integrity issue.

### Combat-family spot check (2026-07-31, same session)
Quick sweep (turntable, a0/a90/a315, 2-3 frames each) on `firing_rifle`, `reloading`,
`prone_firing_rifle`, `grenade_throw`, `plant_charge` — all CLEAN, no elbow-into-torso
found. `firing_rifle_fixed` was also rendered for comparison (different hand height —
low-ready vs. shoulder-mounted — but not obviously broken either); did not chase
further since neither base action in that pair was flagged as defective. Prone check
was shallow — the standing-height turntable camera doesn't frame a prone body well,
treat `prone_firing_rifle`/`prone_idle`/`wounded_crawl` as unverified, not clean.

## Open / not done this session
- `firing_rifle_fixed` / `reloading_fixed`: same `_fixed`-swap fossil risk as the two
  removed this session (`export_anim_library.py:29-35` swaps them in silently). Spot
  render didn't show either as broken, but they weren't put through the full
  objective+visual loop, and the pattern (a `_fixed` sibling reading differently from
  its base) is exactly what bit `idle_aiming`/`idle_crouching_aiming` this session —
  worth a real look before trusting either. Flag for next pass, do not delete blind.
- Prone-family clips (`prone_firing_rifle`, `prone_idle`, `wounded_crawl`,
  `crouch_to_prone`): camera calibration in `render_turntable.py` is tuned for
  standing-height framing and clips a prone body. Build a prone-specific camera
  center/distance before trusting any verdict on these.
- FP viewmodel rigs (`assets/player/arms/*.blend`): not touched this session.

## Export timing note
`tools/export_anim_library.py` (headless, `blender -b anim_library.blend -P
export_anim_library.py`) took **~9 minutes** for 163 clips with
`export_bake_animation=True` — don't assume a hang if the process runs long; let it
finish rather than killing and re-running (confirmed 2026-07-31, exited clean at
8m37s wall time). `godot --headless --path . res://tests/test_model_actor_animations.tscn`
re-verified `PASS: 0 failure(s)` across all 31 units afterward.
