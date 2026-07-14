# War Room 2026-07-14 — FP Weapons ADS Sights + Viewmodel Editor Bug

**Phase 3: THE DEBATE**
**Project:** RECONgame
**Charter:** production/OVERSEER_CHARTER.md v0.3.1
**Canon:** production/GAME_GUIDE.md + production/adr/ (ADR-014 priority order)
**Laws:** Pillar 1 (outstanding gunplay) · ADR-004 (per-weapon ads_fov) · ADR-015 (verification) · ADR-023 (fossil law) · comment discipline · no-mid-phase-questions

**Council convened** (5 architects; 4 verdicts received; 1 long-running silencer): balance-feel, blender-stager, viewmodel-programmer, animator, weapons-designer (pending — no file written). The viewmodel-programmer and blender-stager did deep code reads; balance-feel did a per-weapon numerical audit; animator parsed every .tscn and every .glb. Weapons-designer was tasked with per-gun sight-geometry authoring; its absence is named in §6.

---

## 0. Where the council AGREES (the convergence)

This is the strongest signal the process produces — four independent sight, no cross-talk, and they converge on these five claims:

1. **The Summoner's "two competing reference frames" hypothesis is REFUTED at the scene-tree level.** All 12 arms .tscn files are byte-identical: same Model root, same `Transform3D(-1, 0, 0, 0, 1, 0, 0, 0, -1, 0, -1.81, 0)`. There is no per-gun anchor, no second scene swapped on aim-down. The "frame collision" is data-side, not scene-side. (viewmodel-programmer §1.5, animator §0, blender-stager §2.)

2. **The actual cause of "Mosin and AK grossly offset" is a .tres-completeness defect, not a code defect.** Three of fifteen .tres files — `ak47.tres`, `m70.tres`, `mosin.tres` — have an `ads_position` stub line but NO `ads_rotation` line at all. Godot loads the script default `Vector3(0, 0, 0)` (weapon_data.gd:93) for the missing rotation. The ADS rotation lerp converges to half of the hip rotation; the gun visibly spins through the transition. The bench already prints `! HIP vs ADS rot differs >90deg - ADS spin risk` for these three guns on every load (viewmodel_editor.gd:665-666). **The project has been printing the bug in its own UI and not reading it.** (viewmodel-programmer §1.3, §1.6, §10.)

3. **The "only ONE of two transforms corrects" symptom is the .tres-completeness defect above.** The position lerp at `weapon_holder.gd:754-755` is *symmetric* with the rotation lerp — same syntax, same `delta * ADS_SPEED = 10.0`, same `ads_transition` scalar. The asymmetry is *upstream*, in the .tres: 7 of 15 guns carry the stub `ads_position = (0, 0.05, 0.08)` and the stub `ads_rotation = (4, 0, 0)`. The lerp converges to the stubs; the visual reads as a 4° pitch-up and a 5cm/8cm nudge. (viewmodel-programmer §1.1, §1.3; balance-feel §0.)

4. **The `viewmodel_scale` field is a fossil.** Declared in `weapon_data.gd:89`, displayed in `viewmodel_editor.gd:646`, **never applied** by `weapon_holder.gd:817` (which only multiplies by `_lens_ratio(weapon_data)`). `CODE_AUDIT.md:112` already named this three weeks ago. M70 and Mosin carry `viewmodel_scale = 1.1`; M79 carries `0.9`; the values are silently ignored. Per ADR-023 the fossil must be wired OR deleted in the same commit as any related fix. (viewmodel-programmer §1.2, §4.4, §6.1; balance-feel §0.)

5. **The Blender export pipeline does NOT carry the sight empties through today.** `tools/export_viewmodel.py:74-79` selects `[arm, mesh, gun, muz]` and drops everything else. The M14 .blend has the three TRUTH empties (`sight_rear_M14`, `sight_front_M14`, `muzzle_M14`) per the workflow doc, but the M14 .glb has *zero* `sight*`-named nodes — verified by parsing m14_fp.glb. The exporter is the gate, not the .blend. A 5-10 line patch is required. (animator §6, §9; blender-stager §3.1.)

These five convergences are the spine of the decree. Where the architects *disagreed* (e.g. on `viewmodel_scale` wire-vs-kill, on the bolt-rifle FOV, on whether to fix the 3 incomplete or all 10 stub-bearing guns), the debate is recorded in §1.

---

## 1. Disagreements + tradeoffs (the debate)

### 1.1 `viewmodel_scale`: WIRE the fossil, or KILL it?

| | Wire (Option A) | Kill (Option B) |
|---|---|---|
| **Argument for** | The data already carries the values (M70=1.1, Mosin=1.1, M79=0.9, plus 4 [NO MODEL] guns). Killing the field loses 6 hand-authored values. (viewmodel-programmer §6.1) | The field is dead for ≥3 weeks. Killing the fossil is what ADR-023 demands when the data is the wrong shape. |
| **Argument against** | Every value in the .tres becomes load-bearing. If a .tres carries a wrong value, the gun is visibly wrong. The "the field exists but does nothing" safety is lost. | The per-gun size contract is lost entirely. M70, Mosin, M79 become locked to whatever the .glb carries. |
| **Cost** | Two lines of code (weapon_holder.gd:817, viewmodel_editor.gd:269) + visual verification. | Six .tres files lose their `viewmodel_scale =` line; the editor's HUD (line 646) loses its display. |
| **Net** | **Wins.** The data was authored; the field was clearly intended to be load-bearing; wiring it is the smaller, more honest fix. Killing it would lose information that was hand-authored into 6 of 15 .tres files. | Loses. |

**DECISION: WIRE.** `weapon_holder.gd:817` and `viewmodel_editor.gd:269` both get `* weapon_data.viewmodel_scale` (or `* current_weapon.viewmodel_scale`). Per ADR-023, this is the correct call.

### 1.2 Bolt-rifle FOV at 40°: keep tight, or relax to 50-55°?

| | 40° (current) | 50-55° (raised) |
|---|---|---|
| **Argument for** | Matches the sniper-class reading. ADR-004 ratified 40° for Mosin and M70. (balance-feel §1) | The placeholder `ads_position = (0, 0.05, 0.08)` puts the eye 8cm back. At 40° the rear aperture fills the screen — the player sees the *back* of the rear ring, not through it. The placeholder geometry only reads as a "hex peep" at 50-55°. (balance-feel §2) |
| **Argument against** | The placeholder is wrong by ~4× for a real long-eye-relief scope. The 40° is unreachable until the rig author pushes the eye back to ~50cm. | Departure from ADR-004's ratified 40°. The sniper-class promise is softened. |
| **Cost** | Requires the rig author to author a true long sight radius in the .blend. Day-1 owner work. | 2 lines in 2 .tres files. Mechanical. |
| **Net** | **Right design, wrong moment.** | **Right now, defer the long-radius author work.** |

**DECISION: KEEP 40° in the .tres; FLAG a follow-up bead (P2) for the rig author to either (a) push eye to 30-50cm in the per-gun `ads_position`, or (b) amend ADR-004 to relax the FOV.** The 40° is canon; the placeholder geometry is the problem; the geometry fix is a per-sight-geometry authoring task owned by the weapons-designer + blender-stager team.

### 1.3 Day-1 scope: fix the 3 INCOMPLETE guns, or all 10 stub-bearing guns?

| | 3 incomplete (ak47, m70, mosin) | All 10 stub-bearing |
|---|---|---|
| **Argument for** | The Summoner named these three by eye. The other 7 stub-complete guns "look wrong but function" — they are primary-chain work, not the named secondary bug. (viewmodel-programmer §6.3) | The placeholder is the SAME literal across 9 files. Fixing 3 is fixing 60% of the bug; the other 7 are the same problem. |
| **Argument against** | Leaving 7 guns at the stub pose is shipping known-wrong data. | 4 hours of bench work per gun × 7 = 28 hours, which exceeds Day-1 budget. |
| **Cost** | 3 editor sessions in the bench (B + I/K/U/O + Ctrl+S). | 7+ editor sessions. |
| **Net** | **Wins on minimum-scope grounds.** | Loses on Day-1 budget. |

**DECISION: FIX THE 3 INCOMPLETE GUNS NOW.** Open a P2 follow-up bead for the 7 stub-complete guns (m16a1, m1911, m60, ppsh41, rpd, rpg2, shotgun). Per ADR-015, the verification is the editor's HUD line `! HIP vs ADS rot differs >90deg` going silent for ak47, m70, mosin — *the silence is the verification*.

### 1.4 The M14 "has the markers" claim

The briefing said "M14 has the markers." Both the animator and the blender-stager measured that this is *true at the .blend level, false at the .glb level*. The M14 .blend carries `sight_rear_M14`, `sight_front_M14`, `muzzle_M14`; the M14 .glb carries *zero* `sight*` nodes. **The exporter is the gate.** The 5-10 line patch to `export_viewmodel.py` makes the .blend's markers reach the .glb end-to-end.

**DECISION: M14 = the reference for .blend authoring workflow; the .glb marker absence is fixed by the same exporter patch.** The bead for the patch is the highest-priority Day-1 item because *every* per-gun ADS pass is wasted re-export without it.

### 1.5 The editor's snap-vs-lerp "two-frame" bug

The Summoner proposed "the viewmodel rig has two competing reference frames and tweening snaps between them." The viewmodel-programmer REFUTED this at the scene-tree level (all 12 .tscn files are byte-identical) and the animator confirmed: there is one model node, one runtime lerp. **What is true:** the editor's mode toggle (`viewmodel_editor.gd:674-678`) calls `_load_edit_from_resource()` which writes `weapon_model.position = edit_position` *directly* — the editor SNAPS. The game LERPs at `ADS_SPEED = 10.0` (`weapon_holder.gd:795-796`). **The disagreement is snap-vs-lerp, not frame-collision.** Fix is editor-side: add a `_process`-driven lerp using the same `ADS_SPEED` for symmetry.

**DECISION: This is a Day-2 (secondary) item per the briefing.** Flag for the post-Primary pass. The fix is mechanical (one `_process` lerp in the editor's `_on_mode_toggle`) and orthogonal to the per-gun ADS authoring. The "weapon-swap visual snap" the balance-feel architect measured (gun loads at GLB's saved `position`, often zero, and lerps to `hip_position` over ~200ms) is a *related* symptom but a *different* fix: set the GLB's saved `position` to match `hip_position` on export, or initialize `weapon_model.position = hip_position` in `_load_weapon_model` *before* the lerp starts.

### 1.6 The "weapon-swap snap" vs the "ADS snap"

The balance-feel architect found a second snap: when the player swaps weapons, the new gun loads at the GLB's saved `position` (often zero) and lerps to `hip_position` over ~220ms. The player sees a 4-5° rotation jolt and an 8cm Z-jolt in one frame. This is NOT the "two-frame" bug — it is a *first-frame* bug. Fix: set `weapon_model.position = weapon_data.hip_position` in `_load_weapon_model` *before* the first lerp call.

**DECISION: Fold into the Day-2 secondary fix.** The 2-line patch is in the same function as the `viewmodel_scale` wire (weapon_holder.gd:816-820). Both ship together, both verified by the same editor session.

---

## 2. The architects respond to each other

**balance-feel → viewmodel-programmer:** "You are right that the lerp code is correct. But you should name the *player's perception* as a constraint, not just the math. The weapon-swap snap is real, even if the lerp is smooth. A 200ms settling animation that LOOKS like a snap to the player IS a snap. Name it."

**viewmodel-programmer → balance-feel:** "Agreed. The weapon-swap snap is the player-facing symptom, and it is the editor's snap-vs-lerp distinction at weapon-load. The fix is in `_load_weapon_model` (line 819): set `weapon_model.position = weapon_data.hip_position` *before* the first `_process` lerp. Same line as the `viewmodel_scale` wire. Two-line patch."

**animator → blender-stager:** "The export set patch is mine to flag, yours to write. The 5-line patch is the precondition for the entire primary chain — without it, every per-gun ADS pass is wasted re-export. Make it the Day-1 first commit."

**blender-stager → animator:** "Agreed. Day-1 first commit is the exporter patch. Then M16A1 (US, geometry done), then AK-47 (Soviet, extend the builder), then M14 re-export (regression test), then Mosin (hardest geometry). The 30-line `append_gun.refresh` helper is a one-day follow-up if the Day-1 manual-replace pattern becomes a bottleneck."

**viewmodel-programmer → blender-stager:** "I want to be sure: when you patch `export_viewmodel.py`, are you including the `sight_rear_<gun>` and `sight_front_<gun>` renames, or are you leaving them as gun-specific names? If you rename them to `SightRear_<gun>` / `SightFront_<gun>` inside the GLB, the auto-align tool (bead 9h9f) can find them by name. If you leave them, the tool needs a per-gun lookup table."

**blender-stager → viewmodel-programmer:** "Renaming. The `export_flashlight_fp.py:54-71` pattern (light_origin → LightOrigin) is the convention. Same for the sight empties. The auto-align tool gets a clean string match."

**balance-feel → animator:** "Your `rifle_idle` survival verdict is comforting, but I want to be paranoid: if the `rifle_pose.verify` check fails on a per-gun export, who owns the rollback? The owner poses; you stage. The verify is a measurement. If the rig drifts, the owner's pose is the truth — and the right rollback is `rifle_pose.apply(arm)` to restore the captured hold."

**animator → balance-feel:** "Confirmed. The `rifle_pose.apply(arm)` helper at `tools/rifle_pose.py:38-50` is the rollback. The verify-then-restore pattern is a per-gun commit, not a Day-1 one-shot. The pre/post snapshot diff is a `tests/fixtures/rifle_idle_pre_ads.json` baseline (the fossil-law pattern)."

---

## 3. The cross-cutting findings (architect-agnostic)

1. **The M14 .tres is the only complete, tuned gun in the roster.** It is the reference. After the Day-1 fix, ak47/m70/mosin join it as "complete" guns; the 7 stub-complete guns remain primary-chain work.

2. **The M79 is the only gun with a *fully author-tuned* ADS pose.** Its `ads_position = (0.0, -0.508, -0.755)`, `ads_rotation = (0, 90, 0)`, `hip_position = (0.469, -0.627, -0.849)` are the result of a real bench session. The 65° FOV matches the leaf-sight geometry. The M79 is the proof that the bench *works* when used.

3. **The "settled shot" gate is reachable.** All four architects (balance-feel primarily) confirmed the gate at `weapon_holder.gd:379-381` is correctly timed and the ADS_SPEED-synchronized lerp reaches 90% completion in ~220ms. The Summoner's "two-frame" intuition was wrong on this point; the gate is fine.

4. **The recoil punch (8.57° peak for Mosin, 6.7° for RPG) is INTENTIONALLY outside the editor's `ALIGN_TOLERANCE_M = 0.025`.** The editor's tolerance is for *static* alignment; the recoil kick is *dynamic*. The two are not comparable. The settled gate's 400ms wait absorbs the recoil correctly. **No change to recoil math today.** (balance-feel §5.)

5. **The four "hip-only / sight-raise" guns (M60, RPD, RPG-2, M72) carry stale `ads_fov = 60.0` values.** Per ADR-004, M60/RPD are hip-only and RPG-2/M72 are sight-raise. The 60° FOV is the pre-ADR-004 default. **This is a 1-line cleanup in 4 .tres files** (set `ads_fov = 10.0` for the no-zoom guard at `weapon_holder.gd:218`) — *the easy fossil*, exactly what ADR-023 wants deleted in the same commit as any related fix. (balance-feel §3, §8.)

---

## 4. What the council COULD NOT converge on (the silencer)

**weapons-designer was tasked with per-gun sight geometry** (rear aperture + front post for the PSX read, analytic `ads_position` per gun, what sight radius matches what FOV). The agent has not produced an analysis file. The blender-stager has covered most of the geometry (per-gun constants from blueprints, the `add_sight_markers` helper, the Soviet extension). **The weapons-designer is the missing link on per-gun *aesthetic* sight authoring** — what does an M14 rear aperture look like vs a Mosin hex peep vs a PPSh snail drum? The blender-stager's recipe is mechanically correct; the visual quality is weapons-designer work.

**DECISION: Proceed with the synthesis without the weapons-designer analysis. The synthesis will name this as a P2 follow-up bead and as a hard gate on the rig-pass.**

---

## 5. The open questions for the council (carried forward)

1. **Does the bolt-rifle long-eye-relief scope (M70 40° + the right `ads_position`) need a `viewmodel_fov` revision, or is the lens math already correct?** (balance-feel §2 — the *viewmodel_fov × ads_fov* interaction is a non-obvious coupling.)
2. **Does the AK-47's tilted 6.68° hip rotation interact with the missing `ads_rotation` to produce a worse spin than the Mosin?** (viewmodel-programmer §1.6 — measured, the AK spin is ~3.3° midpoint vs the Mosin's 1.0°, but the visual is worse because the AK is shorter and the spin is in the visible frame.)
3. **Does the PPSh-41 58° FOV need to come up to 62-65° to match the historical "snail drum" open sight?** (balance-feel §1 — single-line change, defer to weapons-designer.)
4. **Should the `MuzzlePoint` find_child pattern (recursive, non-owned) be tightened to a direct child reference once the rig change lands?** (animator §3 — out of scope today, follow-up on Step 1 of the rig change.)

---

## 6. The weapons-designer silence (the law binds the Arbiter too)

The council's process law says "the value is the independence of sight." Five architects convened; four produced; one ran long. Per `no-mid-phase-questions`, the Arbiter proceeds without the missing analysis, names the gap in the synthesis, and flags a follow-up bead. **The weapons-designer is the only role missing; every other seat is filled.** The synthesis (next file) is the decree.

— End of DEBATE —
