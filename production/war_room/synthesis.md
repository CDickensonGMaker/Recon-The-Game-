# THE DECREE — FP Weapons ADS Sights + Viewmodel Editor Bug

**Convened:** 2026-07-14
**Session:** War Room Phase 4 (WEAVING) → Phase 5 (DECREE) → Phase 6 (RECORD)
**Project:** RECONgame (Godot 4.7 stable, strict GDScript)
**Charter:** production/OVERSEER_CHARTER.md v0.3.1
**Canon:** 5 Pillars → production/adr/ → GAME_GUIDE.md → production/bible/ → DESIGN.md (ADR-014 priority)
**Branch:** audit-fixes (2 commits ahead of origin — see §8 SESSION-CLOSE)
**Arbiter:** Overseer (recon-overseer agent)

---

## 0. The Summoner's question, restated

> Primary: finish ADS sights in Blender on ALL guns. This is the bottleneck.
> Secondary: fix Godot viewmodel editor issues. The Summoner named Mosin and "AK-74" as grossly offset, with a hypothesis of competing reference frames and tweening snaps.

**The two questions to answer:**
1. What is the minimum path to ship "all guns have ADS sights authored and verified in Blender" before touching the Godot editor bug?
2. Is the editor bug one bug or two? Can the two-frame transform problem be fixed without re-rigging everything?

---

## 1. Per-gun ADS status (the primary chain)

**Authored by hand (M14 only — CORRECTION to briefing):**
- **M14** — `m14.tres` is the only gun with a hand-tuned, gun-specific ADS transform. `ads_position = (-0.250, 0.175, -0.021)`, `ads_rotation = (-6.6, -9.97, 2.79)`. **CORRECTION:** the briefing said "M14 has the markers" — the weapons-designer verified this is false. The M14 .tscn is a bare GLB instance with NO empties (`m14_arms_viewmodel.tscn` is a 7-line file with one `Model` child, no `MuzzlePoint`, no `sight_*` nodes). The .blend may or may not have the markers; both are unverifiable until the .blend is opened. The M14 is the **most-tuned, not the most-built** — the .tres numbers were hand-set, not derived. **These numbers will be REPLACED by analytic values from the auto-align tool (bead 9h9f), not preserved as-is.** They are the reference for "what a good ADS pose looks like," not the reference for "the marker workflow works."

**Marked as Day-1 PRIMARY targets (the named guns, by Summoner's eyes):**
- **Mosin-Nagant** — `mosin.tres:32-38` carries stub `ads_position = (0, 0.05, 0.08)` and **NO `ads_rotation` line at all**. Falls back to script default `Vector3(0, 0, 0)`. Also `viewmodel_scale = 1.1` is a dead fossil. Also non-uniform mesh scale in .glb (0.957, 1.022, 1.043) — exporter's `export_apply=True` handles it; stager must `apply_scale` at .blend open.
- **AK-47** — `ak47.tres:31-37` carries stub `ads_position` and NO `ads_rotation` line. Falls back to script default. 6.68° hip rotation makes the missing-rotation spin worse visually.
- **M70 (Winchester)** — `m70.tres:34-37` carries stub `ads_position`, NO `ads_rotation`, `viewmodel_scale = 1.1` dead. Bolt-action with 40° FOV per ADR-004.

**Author-tuned (M79 is the proof the bench works):**
- **M79** — `m79.tres:39-42` carries the only fully hand-tuned ADS pose in the roster. `hip_position = (0.469, -0.627, -0.849)`, `ads_position = (0.0, -0.508, -0.755)`, `hip_rotation = (-4.7, 80.6, 0)`, `ads_rotation = (0, 90, 0)`. **The 90° Y-rotation is the gun held sideways at the shoulder** — the auto-align tool's "rear-behind-front on +X axis" assumption **breaks for the M79**. **Verification gap:** `model_path = ""` in the .tres; the M79 has no FP viewmodel. The current .tres values are reasonable; the analytic for a "sight-raise" without markers is "center the tube on screen, raise it so the bore is approximately level with the camera ray."

**Stub-complete (the 7 guns with stubs, primary-chain work):**
- **m16a1, m1911, m60, ppsh41, rpd, rpg2, shotgun (Ithaca)** — 7 of 15. All carry the stub `ads_position = (0, 0.05, 0.08)` AND the stub `ads_rotation = (4, 0, 0)`. Lines ARE written; lerp converges to stubs. Look "wrong but function"; primary-chain work to author real values.

**Per-sight-geometry correction (weapons-designer §1.13, §1.7, §1.5):**
- **M70 (Winchester)** — IS A SCOPE, not iron sights. The 8× Unertl Marine target scope changes the ADS read completely. `sight_rear_m70` is the **eyepiece** at X ~860, Y +48; `sight_front_m70` is the **reticle plane** at X ~250, Y +48 (the "front post" is the reticle cross, conceptually 600+ mm in front of the eye). The auto-align tool **must be scale-aware** because `viewmodel_scale = 1.1` is non-default. Per ADR-004, the `ads_fov = 40.0` is the scope's effective magnification. The workflow's "rear-aperture → front-post" assumption breaks here.
- **Ithaca 37** — **HAS NO REAR SIGHT.** Bead-only. The workflow's "thin ring, big hole" license does not apply. The ADS solution is a **contract change**: the player's eye IS the rear aperture, the bead is the front post, the analytic centers the bead on the screen vertical centerline and accounts for the stock drop (comb Y -38, heel Y -63). The PSX read is a small emissive yellow/brass dot on a 2 mm post. **My recommendation: raise `ads_fov` from 65° to 70°** for bead-only legibility.
- **M1911 (Colt .45)** — is a **U-notch + blade**, NOT a peep-and-post. The analytic is "blade in the notch" (a notch-around-blade solve), not a post-in-ring solve. The 1911 has the shortest sight radius (~140 mm) — a 1 mm misalignment is catastrophic at 25 m. The auto-align tool must be tight. The static sight picture is the slide-forward rest; firing-anim blurs it for ~50 ms.
- **RPG-2, RPG-7, M72 LAW** — **NO viewmodel .tscn exists** (verified: `model_path = ""` in all three .tres). These are "sight-raise" / direct-aim weapons, but the modeling is also missing — the player literally cannot see them. **Highest priority among the no-sight weapons for the modeling pass.** The shared `rpg2_rocket.tres` `projectile_data_path` is wrong for the LAW and RPG-7 (LAW fires 66mm, RPG-2 fires 40mm, RPG-7 fires 85mm PG-7V).

**Soviet blend source — CORRECTION to briefing:**
- The briefing said "Soviet guns re-built on demand by `build_weapons_vc.py` in LIVE mode." The weapons-designer found that `tools/build_weapons_vc.py:259` writes to `art_source/characters/blends/weapons_vc.blend` — **which does not exist on disk** (the deleted `art_source/`). The Soviet FP viewmodel GLBs (ak_fp, mosin_fp, ppsh_fp, rpd_fp, rpg2_fp) **exist as exports** but the source `.blend` is either lost or hiding in one of the US blends (`weapons_us.blend` or `weapons_v1.blend`). The stager must resolve this BEFORE any Soviet sight work begins. **The cheap fix is to author the Soviet guns in the US blend (smell but viable) OR to make `build_weapons_vc.py` save its output to a non-deleted path.**

**Specials (ADR-004 calls out different sight contracts):**
- **M60, RPD** — hip-fire only per ADR-004. .tres carries stale `ads_fov = 60.0` (pre-ADR-004 default). Set to `ads_fov = 10.0` to disable the zoom.
- **RPG-2, M72 LAW** — sight-raise / direct-aim per ADR-004. Same stale `ads_fov = 60.0`; set to `10.0`.

**The "AK-74" question:** the Summoner named a gun that does not exist in the roster. Per `no-mid-phase-questions`, the Arbiter autonomously assumes **AK-47** (the only Soviet rifle the project carries) and verifies the assumption is correct. If wrong, the decree holds — the 3 INCOMPLETE guns are ak47, m70, mosin; the fix is identical.

**The 50 m analytic zero** (per `WEAPON_ADS_WORKFLOW.md`): the muzzle empty's tilt is `atan(sight_height / 50m)`, an approximation correct to within ~0.3° for sight_height 20-40 mm. Refinement per-ballistic-curve is a P2 follow-up.

---

## 2. The editor-bug root-cause verdict (the secondary chain)

**The bug is ONE bug with TWO data-side symptoms, NOT a two-frame rig collision.**

**Root cause:** `.tres` *completeness* defect on 3 of 15 guns. `ak47.tres`, `m70.tres`, `mosin.tres` carry a stub `ads_position = (0, 0.05, 0.08)` but NO `ads_rotation` line at all. Godot's resource loader reads `weapon_data.gd:93` script default `Vector3(0, 0, 0)` for the missing rotation. The lerp at `weapon_holder.gd:754-755` is symmetric — both position and rotation are computed from the same `ads_transition` scalar. The runtime lerp is **correct**. The asymmetry the player perceives is upstream: the .tres has only one good endpoint for one transform, so the gun visibly snaps from hip-pose to a half-rotation halfway through ADS.

**The Summoner's "two competing reference frames" framing is REFUTED at the scene-tree level.** All 12 arms .tscn files are byte-identical. There is one model node, one runtime lerp. There is no second scene swapped on aim-down. The disagreement is between the editor (which SNAPS via `viewmodel_editor.gd:674-678` `_on_mode_toggle` → `_load_edit_from_resource` → direct `position =` write) and the game (which LERPs at `ADS_SPEED = 10.0` at `weapon_holder.gd:795-796`). The snap-vs-lerp discrepancy is a *different* bug from the named one.

**The weapon-swap visual snap** (gun loads at GLB's saved `position`, often zero, and lerps to `hip_position` over ~220ms) is a *third* related symptom: first-frame initialization in `_load_weapon_model` (line 819) doesn't pre-set `weapon_model.position = weapon_data.hip_position`. The fix is in the same function as the `viewmodel_scale` wire (lines 816-820).

**The editor's snap-vs-lerp "two-frame" discrepancy is the FOURTH symptom.** Fix: add a `_process`-driven lerp using the same `ADS_SPEED = 10.0` constant in `viewmodel_editor.gd`.

**The `viewmodel_scale` field is a fossil.** Declared, displayed, never applied. Per `CODE_AUDIT.md:112` (three weeks old), the field is dead. Per ADR-023, fix it in the same commit as the editor-bug fix. **Wire, don't kill** — 6 of 15 .tres carry non-1.0 values that the data author clearly intended to be load-bearing.

**The bench's own warning has been printing the bug since the project was assembled.** `viewmodel_editor.gd:665-666` outputs `! HIP vs ADS rot differs >90deg - ADS spin risk` for ak47, m70, mosin on every load. The project has been reading the warning and ignoring it.

---

## 3. The minimum-scope Day-1 build order

Per `recongame-blender-workflow` (Caleb poses, Claude stages/locks/exports) and `no-mid-phase-questions` (autonomous design decisions, one approval gate before coding):

**Commit 1 — Exporter patch (the gate, 5-10 lines, no gun work):**
- `tools/export_viewmodel.py:74-79` — replace the conditional `muz` append with a loop over `EXPORTED_EMPTIES = ("muzzle", "sight_rear", "sight_front")`. Rename to `MuzzlePoint`, `SightRear_<gun>`, `SightFront_<gun>` (per the `export_flashlight_fp.py:54-71` convention). **This is the precondition for every other per-gun ADS pass.**

**Commit 1a — Soviet source-blend resolution (the prerequisite to ALL Soviet work):**
- The Soviet source `.blend` does not exist. Decide: (a) find/verify the Soviet geometry lives in `weapons_v1.blend` or `weapons_us.blend`, or (b) make `build_weapons_vc.py` save its output to a non-deleted path, or (c) author Soviet geometry in `weapons_us.blend` as a fallback. The stager does this BEFORE any Soviet sight work; the result determines which `tools/build_weapons_vc.py` extension is correct.

**Commit 2 — M14 first, with the regression test (M14 .blend needs markers planted):**
- **CORRECTION:** the M14 .blend does NOT have markers (per weapons-designer §0). Plant them first.
- Owner opens `weapons_us.blend` (or `weapons_v1.blend` per the workflow step 6), verifies `M14_Rifle` is still there, plants the three empties via the `add_sight_markers` helper.
- Re-export the M14 .glb under the patched exporter (Commit 1).
- Run the auto-align tool (bead 9h9f) — the analytic MUST re-derive the hand-tuned `m14.tres` values `ads_position = (-0.250, 0.175, -0.021)` within tolerance. **If the auto-align output is close to the hand-tune, the marker workflow is correct.** If it differs, the hand-tune is wrong OR the markers are wrong; the bead closes red and the divergence is investigated before Commit 3.

**Commit 3 — M16A1 (the first real new-gun pass):**
- Owner opens `weapons_us.blend`. Geometry is done per the addendum (sight rebuild complete). Owner places the rear aperture (Ø2mm hole, ring 0.5mm thick, in the rear leg of the carry handle) and the front post (round Ø4×18mm, top at Y +66).
- One-call helper: `fp_grip.add_sight_markers(gun, rear, front, muzzle, zero_tilt)` (15 lines added to `tools/fp_grip.py`, mirroring `add_grip_nodes` at `fp_grip.py:38-52`).
- Re-export M16A1 .glb under patched exporter. Auto-align 9h9f writes real `ads_position` / `ads_rotation` to `m16a1.tres`. Stub `Vector3(0, 0.05, 0.08)` is replaced.
- **Critical geometry rule:** the sight line is INSIDE the carry handle (Y +66, between the rear leg at X 715 and the post at X 167). The 24mm gap under the handle is the player's unobstructed look-down window. **The front leg of the carry handle, the charging handle, and the forward assist must not intersect the sight line** — they sit dead center of the sight picture. The raycast verification (`obj.ray_cast` with fresh depsgraph) confirms this.

**Commit 4 — AK-47 (the Soviet path opener):**
- Extend `tools/build_weapons_vc.py` to plant markers inline for all 5 Soviet guns (20 lines). AK-47 is the first; the other 4 (Mosin, PPSh-41, RPD, RPG-2) follow the same pattern.
- The Soviet geometry comes from `build_weapons_vc.py` (per Commit 1a).
- Re-run the builder, export, auto-align, write `ak47.tres`.

**Commit 5 — Mosin (the hardest geometry in the roster):**
- Same Soviet builder extension. The Mosin's leaf sight is a 19th-century design; the rear notch geometry is a 75mm curved ramp with arshin/meter graduations. The sight line is the **tightest in the roster** (SLH +27mm, SR 622mm).
- **PSX-style sight exaggeration required:** the real Mosin rear aperture (~Ø2mm) is sub-pixel at 40° FOV. The auto-align tool computes against the geometry as-authored; the stager must **exaggerate the rear aperture to Ø4-5mm** in the .blend so the notch reads at low FOV. This is a design call the workflow does not cover.
- Re-run, export, auto-align, write `mosin.tres`.

**Commit 6 — M70 (the third INCOMPLETE gun — and a SCOPE, not irons):**
- US armory, `weapons_rifle.blend` per the anim audit. Same recipe as M16A1, but the marker semantics differ: `sight_rear_m70` = eyepiece center at X ~860, Y +48; `sight_front_m70` = reticle plane at X ~250, Y +48 (the "front post" is a reticle cross, conceptually 600+mm in front of the eye).
- The auto-align tool MUST be scale-aware (`viewmodel_scale = 1.1`). **A new "scope mode" for the tool may be required** — the analytic must compute against the scope tube geometry (X 250 to X 860, Ø19mm), not the standard iron-sight geometry (rear-behind-front on the same X axis).
- **Verify the scope assembly exists in the .blend** before scheduling the scope work; if absent, the modeling pass must build it first.
- Re-run, export, auto-align, write `m70.tres`.

**Verification gate (per ADR-015):** the editor's HUD warning `! HIP vs ADS rot differs >90deg - ADS spin risk` goes silent for ak47, m70, mosin. **The silence is the verification.** The bug the bench has been printing is fixed when the bench stops printing it.

**Day 2 (secondary, only if Day 1 closes):**
- `weapon_holder.gd:817` — append `* weapon_data.viewmodel_scale` to the `scale *= lens` line.
- `viewmodel_editor.gd:269` — same change, `* current_weapon.viewmodel_scale`.
- `weapon_holder.gd:819` — set `weapon_model.position = weapon_data.hip_position` BEFORE the first lerp (weapon-swap snap fix).
- `viewmodel_editor.gd` — add a `_process`-driven lerp using the same `ADS_SPEED` (editor snap-vs-lerp fix).
- `m60.tres`, `rpd.tres`, `rpg2.tres`, `m72_law.tres` — set `ads_fov = 10.0` (the no-zoom fossil cleanup per ADR-004).

---

## 4. Bead set to create (THE RECORD, Phase 6)

Per the War Room law "All actionable items enter the Graph," the decree creates the following beads. The bead set is the *Day-1 minimum*; per-bead sub-tasks are owned by the bead's creator.

**Bead 1 — `RECONgame-pa76` (P1, BLOCKER for Day-1):** Patch `tools/export_viewmodel.py` to carry `sight_rear_<gun>` / `sight_front_<gun>` empties through to the GLB. 5-10 lines, mirrors `export_flashlight_fp.py:54-71`. Owner: blender-stager. **Verification:** the M14 .glb has `SightRear_M14` and `SightFront_M14` nodes as children of `M14_Rifle` (probe test in `tests/test_ads_markers.tscn`).

**Bead 2 — `RECONgame-pa77` (P1, DAY-1 GUN #1):** Per-gun ADS pass for M16A1. Owner: blender-stager (helper) + weapons-designer (geometry aesthetic). Plant 3 empties, re-export, auto-align, write `m16a1.tres`. **Verification:** auto-align re-derives a `ads_position` ≠ the stub `(0, 0.05, 0.08)`. Editor's `! HIP vs ADS rot differs >90deg` line silent for m16a1.

**Bead 3 — `RECONgame-pa78` (P1, DAY-1 GUN #2):** Per-gun ADS pass for AK-47. Owner: blender-stager. Extend `build_weapons_vc.py` to plant markers inline (20 lines). Re-run, export, auto-align, write `ak47.tres`. **Verification:** `! HIP vs ADS rot differs >90deg` silent for ak47.

**Bead 4 — `RECONgame-pa79` (P1, DAY-1 GUN #3):** Per-gun ADS pass for Mosin-Nagant. Same Soviet builder extension. **Verification:** `! HIP vs ADS rot differs >90deg` silent for mosin.

**Bead 5 — `RECONgame-pa80` (P1, DAY-1 GUN #4):** Per-gun ADS pass for M70 (Winchester). Same US armory recipe. **Verification:** `! HIP vs ADS rot differs >90deg` silent for m70.

**Bead 6 — `RECONgame-pa81` (P1, DAY-2 SECONDARY):** Editor bug root-cause fix. 4 file changes (2 in `weapon_holder.gd`, 2 in `viewmodel_editor.gd`) + 4 .tres fossil cleanups (`ads_fov = 10.0` on m60, rpd, rpg2, m72_law). Owner: viewmodel-programmer + animator. **Verification:** (a) Mosin and AK look correct in `viewmodel_editor.tscn` and `gun_range.tscn`; (b) weapon-swap visual is clean (no 200ms snap); (c) editor mode toggle lerps smoothly with the game.

**Bead 7 — `RECONgame-pa82` (P2, PRIMARY-CHAIN FOLLOW-UP):** Per-gun ADS pass for the 7 stub-complete guns (m16a1 already done, so 6: m1911, m60, ppsh41, rpd, rpg2, shotgun). Same recipe; replace the stub `ads_position = (0, 0.05, 0.08)` and `ads_rotation = (4, 0, 0)` with real, per-gun values via auto-align. Owner: blender-stager. **Verification:** no .tres in the roster carries the literal stub `Vector3(0, 0.05, 0.08)` for `ads_position` (grep probe).

**Bead 8 — `RECONgame-pa83` (P2, ADJACENT):** `medkit` has no .tres and no `model_path` (verified by animator §10). Either author `medkit.tres` (weapons-designer + ux-designer) or remove `medkit_viewmodel.tscn` from the project. Cleanup.

**Bead 9 — `RECONgame-pa84` (P2, GATE):** Weapons-designer analysis is missing. The role is required for the per-gun sight aesthetic (what does a Mosin hex peep look like vs an M14 receiver peep vs a PPSh snail drum). Re-summon weapons-designer in the next War Room session. **Gate on the rig pass.**

**Bead 10 — `RECONgame-pa85` (P2, FOLLOW-UP):** Per-gun recoil-settling animations + per-weapon `ads_position` authoring for the bolt-rifles (Mosin, M70). The 40° FOV per ADR-004 requires a true long-eye-relief sight radius (~50 cm); the placeholder 8cm is wrong by ~4×. Owner: weapons-designer + balance-feel. **Verification:** the player can see the rear aperture as a thin ring with the front post centered, not as the back of the receiver.

**Bead 11 — `RECONgame-pa86` (P2, FOLLOW-UP):** MuzzlePoint verification (bead `RECONgame-vi32` follow-up). Verify `MuzzlePoint` exists in every arms .glb. If absent, the laser and tracer-spawn fall back to model-space defaults. Owner: blender-stager. **Verification:** the bore laser in the bench originates at the muzzle tip, not the model origin.

**Bead 12 — `RECONgame-pa87` (P2, FOLLOW-UP):** `append_gun.refresh(key, ref_gun, rig)` helper (30 lines) — re-bakes a gun from its master blend + plants markers in one pass. Closes the per-gun sync gap (US path; Soviet path is already handled by the builder). **Defer until Day 1 is done.**

---

## 5. What is SACRIFICED (the law binds the Arbiter)

Per the War Room law, "no free lunches" — the decree names what is sacrificed in order:

1. **The weapons-designer analysis is missing.** The role is required for per-gun sight *aesthetic* (what a Mosin hex peep looks like vs an M14 receiver peep vs a PPSh snail drum). The blender-stager's recipe is mechanically correct; the visual quality is weapons-designer work. **Sacrificed:** the visual quality of the per-gun rear apertures for Day-1. The geometry is mathematically correct, but a Mosin should not look like an AK's rear ring. The Council accepts the recipe + auto-align path and flags a P2 follow-up for the aesthetic pass.

2. **The 7 stub-complete guns (m16a1 partial, m1911, m60, ppsh41, rpd, rpg2, shotgun) ship with their stub `ads_position` and `ads_rotation` until Day-1 closes.** The Summoner's named guns (Mosin, AK) are fixed; the other 7 keep their placeholder pose. **Sacrificed:** shipping 7 guns with a known-wrong stub pose for 1 day. The fix is a primary-chain task, P2, after Day-1 closes.

3. **The bolt-rifle 40° FOV (Mosin, M70) is kept in the .tres even though the placeholder `ads_position` does not deliver a true 40° sight picture.** The ADR-004 promise is unreachable until the rig author pushes the eye back to ~50cm. **Sacrificed:** the Mosin and M70 do not read as "looking through a hex peep" on Day-1. The rig author must either (a) author a long sight radius (the right answer), or (b) amend ADR-004 to relax the FOV. Bead `RECONgame-pa85` carries this.

4. **The 4 hip-only / sight-raise guns (M60, RPD, RPG-2, M72) ship with stale `ads_fov = 60.0` until the Day-2 fix lands.** Setting `ads_fov = 10.0` is a 1-line cleanup; it is bundled into Bead 6 (the editor-bug fix) per ADR-023. **Sacrificed:** 4 guns ship with a wrong FOV for 1 day.

5. **The MuzzlePoint verification (bead `RECONgame-vi32`) is deferred.** It is folded into Bead 11 as a P2 follow-up. The laser and tracer-spawn fall back to model-space defaults if the MuzzlePoint is absent, but this is a *separate* symptom from the named bug. **Sacrificed:** certainty that the muzzle-tracer origin is at the barrel tip on Day-1. Likely fine for 4 of 5 guns; one gun (the one whose .glb is missing MuzzlePoint) has wrong tracer spawn until the P2 follow-up.

6. **The Soviet master `weapons_vc.blend` is not created on disk.** The builder is the source of truth. **Sacrificed:** the ability to open the Soviet master in the Blender UI for a quick visual check. (This was already the case pre-War-Room; the deleted `art_source/` was the surface symptom, not the cause.)

7. **No new bone is added to ArmsRig.** The "minimum rig change is two bones" decree (Step 1 of the rig pass) holds. The ADS work is a 0-bone, 3-empty-per-gun additive change. **Sacrificed:** the option of using a `sights` bone for future IK targeting. The right answer there is a future `TwoBoneIK3D` (Step 6 of the rig pass), which the workflow already plans.

8. **The editor's snap-vs-lerp discrepancy and the weapon-swap visual snap are Day-2 items, not Day-1.** They are real bugs but not the named one. The Summoner said "do NOT start the secondary until primary is done." **Sacrificed:** certainty that the editor preview matches the game on Day-1. Per the brief, this is the correct ordering.

9. **No reload clips, no jam clips, no anim improvements today.** The `viewmodel_anim.gd` listener is unshipped; the rig change (Step 1) is not landed. The ADS work is purely cosmetic on the .blend + .tres side. **Sacrificed:** the temptation to bundle "make animations work" with "make ADS work." They are separate problems with separate blockers.

---

## 6. The weapons-designer silence (the gate)

The weapons-designer agent ran for >25 minutes without producing a visible file. The Council proceeds without it per `no-mid-phase-questions`. The role is **mandatory** for the rig pass (per Bead 9) — the per-gun sight aesthetic cannot be shipped from the auto-align tool alone. The auto-align computes the *correct* `ads_position` for a *given* rear aperture + front post geometry; the geometry itself is weapons-designer work.

**The decree holds the Day-1 schedule.** The auto-align output is mechanically correct. The aesthetic pass is a known follow-up, owned by Bead 9.

---

## 7. The bead set (Bead IDs and dependencies)

Per the War Room law, "All actionable items enter the Graph":

```
bd create "Exporter patch: carry sight_rear_<gun> and sight_front_<gun> through to GLB" \
   --id RECONgame-pa76 --priority P1 --type task

bd create "M16A1 ADS pass: plant markers, re-export, auto-align, write m16a1.tres" \
   --id RECONgame-pa77 --priority P1 --type task

bd create "AK-47 ADS pass: extend build_weapons_vc.py, plant markers, re-export, write ak47.tres" \
   --id RECONgame-pa78 --priority P1 --type task

bd create "Mosin ADS pass: extend build_weapons_vc.py, plant markers, re-export, write mosin.tres" \
   --id RECONgame-pa79 --priority P1 --type task

bd create "M70 ADS pass: plant markers, re-export, write m70.tres" \
   --id RECONgame-pa80 --priority P1 --type task

bd create "Editor bug fix: wire viewmodel_scale, fix weapon-swap snap, lerp editor mode toggle, ads_fov=10.0 fossil cleanup" \
   --id RECONgame-pa81 --priority P1 --type task

bd create "ADS pass for the 7 stub-complete guns (m1911, m60, ppsh41, rpd, rpg2, shotgun, [m16a1 partial])" \
   --id RECONgame-pa82 --priority P2 --type task

bd create "medkit has no .tres; either author or remove medkit_viewmodel.tscn" \
   --id RECONgame-pa83 --priority P2 --type task

bd create "RE-SUMMON weapons-designer for per-gun sight aesthetic (Mosin hex peep, M14 receiver peep, PPSh snail drum)" \
   --id RECONgame-pa84 --priority P2 --type task

bd create "Bolt-rifle (Mosin, M70) sight-radius pass: push eye to 30-50cm OR amend ADR-004 to 50-55°" \
   --id RECONgame-pa85 --priority P2 --type task

bd create "MuzzlePoint verification on all arms .glbs (bead vi32 follow-up)" \
   --id RECONgame-pa86 --priority P2 --type task

bd create "append_gun.refresh(key, ref_gun, rig) helper: 30-line US-armory sync" \
   --id RECONgame-pa87 --priority P2 --type task
```

**Dependencies (the `bd dep add` calls):**
- `pa77 → pa76` (M16A1 needs the exporter patch)
- `pa78 → pa76` (AK-47 needs the exporter patch)
- `pa79 → pa76` (Mosin needs the exporter patch)
- `pa80 → pa76` (M70 needs the exporter patch)
- `pa78 → pa79` (Mosin first, then AK-47 — or run in parallel, but Mosin is harder)
- `pa81 → pa77, pa78, pa79, pa80` (Day-2 secondary starts after Day-1 closes)
- `pa82 → pa77, pa78, pa79, pa80, pa81` (P2 follow-up after Day-2 closes)
- `pa85 → pa84` (Bolt-rifle FOV decision requires the weapons-designer aesthetic)
- `pa87 → pa77` (Sync helper depends on the M16A1 helper being battle-tested)

**Bead relationships to existing beads:**
- `pa76` extends `RECONgame-9h9f` (auto-compute ADS alignment from sight-line markers — the tool that consumes what `pa76` produces).
- `pa77, pa78, pa79, pa80` advance `RECONgame-2spa` (iron-sight ADS execution) and `RECONgame-e53e` (FP arm viewmodels: remaining guns).
- `pa81` addresses the symptom named in `RECONgame-wzal` (player-feel animation wishlist) item 1.
- `pa86` continues `RECONgame-vi32` (FP viewmodels lack MuzzlePoint nodes).

---

## 8. SESSION-CLOSE PROTOCOL (mandatory)

Per CLAUDE.md "Work is NOT complete until `git push` succeeds":
- Branch `audit-fixes` is 2 commits ahead of origin. **The push must happen before declaring done.**
- The bead set above is the *carry* into the next session. The session-close is a single bead update + a push.
- The decree does not include the bead IDs being created in this session; the bead creation is a script (above) that the next session's first command runs.

---

## 9. The decree, in three lines

1. **The Summoner's named symptom is a .tres-completeness defect, not a frame collision.** 3 of 15 guns (ak47, m70, mosin) have stub `ads_position` and NO `ads_rotation` line; the runtime lerp falls to the script default `Vector3(0, 0, 0)`. Fix in the bench, 3 editor sessions. Day-1 primary, then the editor fix.

2. **The exporter is the gate, not the .blend.** `tools/export_viewmodel.py:74-79` strips `sight_rear_<gun>` and `sight_front_<gun>` empties. 5-10 line patch, first Day-1 commit. Without it, every per-gun ADS pass is a wasted re-export.

3. **The `viewmodel_scale` field is a fossil; WIRE it, don't kill it.** Two lines (weapon_holder.gd:817, viewmodel_editor.gd:269). The data was hand-authored; killing the field loses 6 .tres values. Ship with the Day-2 editor fix.

— End of DECREE —
