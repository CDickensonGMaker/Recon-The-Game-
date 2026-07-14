# War Room Briefing — 2026-07-14
# RECONgame FP Weapons: ADS Sights (Blender) + Godot Viewmodel Editor Bug

**Declared project:** RECONgame
**Charter:** `production/OVERSEER_CHARTER.md` v0.3.1
**Canon (priority order, ADR-014):** 5 Pillars → `production/adr/` → `GAME_GUIDE.md` → `production/bible/` → `DESIGN.md`
**Engine:** Godot 4.7 stable, strict GDScript
**Branch:** `audit-fixes` (2 commits ahead of origin — see §5)
**Arbiter:** Overseer agent

---

## 1. The Summoner's stated goals (in order)

1. **PRIMARY — finish ADS sights in Blender on ALL guns**
   - US guns (M14, M16A1, M60, M79, M70, Ithaca, CAR-15, etc.)
   - Soviet guns (AK-47, Mosin-Nagant, PPSh-41, RPD, etc.)
   - This is the bottleneck. Get unblocked here first.

2. **SECONDARY — fix Godot viewmodel editor issues** (do NOT start until primary done)
   - Mosin-Nagant and AK-74 are grossly offset from the FP arms mesh — player can't see them
   - Switching hipfire ↔ ADS repositions the gun while correcting for only ONE of the two transforms
   - Looks like the viewmodel rig has two competing reference frames (hipfire pose vs ADS pose) and tweening snaps between them
   - **NOTE: Owner said "AK-74" — the ROSTER has AK-47 + RPD; AK-74 is not a model. Verify the gun before decree.**

## 2. Constraints and standing laws

- **THE WAR ROOM IS THE DEFAULT PROCESS** (Summoner decree 2026-07-12; memory `war-room-is-not-optional`).
- **CANON outranks this briefing.** Pillar 1 (outstanding gunplay) is directly served.
- **GATE epic (RECONgame-k77e / LW-1..LW-9)** is the project north star — do not let viewmodel polish drift into feature-branch work.
- **Verification law (ADR-015):** no decree item closes without a probe, measurement, or verified playtest.
- **Fossil law (ADR-023):** delete the old system when you replace it.
- **Comment discipline:** no tombstones in code comments.
- **GodotPrompter skills are guidance**, not law; where they conflict with an ADR, the ADR wins.

## 3. Owner-process laws (memory-enforced)

- **recongame-blender-workflow:** Caleb poses, Claude stages/locks/exports. Pose jsons restorable. NEVER script viewport playback.
- **never-guess-in-blender:** measure the scene, act, then verify by measuring AND looking.
- **no-unprompted-screenshots:** never screenshot Blender unasked.
- **verify-in-object-space:** `scene.ray_cast` silently lies. Use `obj.ray_cast`. Never trust a matrix you didn't depsgraph-update.
- **no-mid-phase-questions:** decide autonomously in design phases; one approval gate before coding.

## 4. What's already on the table (per existing memory and beads)

| Bead | Status | Relevance to today |
|---|---|---|
| `RECONgame-2spa` (P2) | OPEN — iron-sight ADS execution | **This IS the primary work.** Per-gun ADS pass + analytic auto-align from sight markers. |
| `RECONgame-9h9f` (P2) | OPEN — auto-compute ADS alignment from sight-line markers | Tooling deliverable for the primary. M14 has markers; others need them. |
| `RECONgame-wzal` (P2) | OPEN — player-feel animation wishlist (Caleb track) | #1 priority is "ADS positions per gun" — **the primary is item 1 of wzal's list**. |
| `RECONgame-lxc3` (P2) | OPEN — real second-camera lens via transparent SubViewport | Adjacent to the editor bug; do not start until primary done. |
| `RECONgame-vi32` (P2) | OPEN — FP viewmodels lack MuzzlePoint nodes | Blocked on the Blender ADS pass; emerges from this work. |
| `RECONgame-vfnt` (P2) | OPEN — captured RPG-2 fires as 62-dmg hitscan rifle | Adjacent; do not start. |
| `RECONgame-ycib` (P2) | OPEN — WW2 WEAPON DATA decisions (BAR, Kar98k, Nagant M1895) | Adjacent; do not start. |
| `RECONgame-q9ie` (P2) | OPEN — TRUTH: grenade + M79 damage hardcoded, violates ADR-016 | Adjacent; do not start. |
| `RECONgame-8aim` (P2) | OPEN — Wire flashlight_fp.glb viewmodel into Godot equipment | Adjacent; do not start. |
| `RECONgame-e53e` (P2) | OPEN — FP arm viewmodels: remaining guns | **Same primary.** |
| `RECONgame-3aw2` (P2) | OPEN — Coverage gate: no rig ships with holes (probe_hitbox_coverage as a test) | Adjacent; do not start. |
| `RECONgame-37ob` (P1) | OPEN — COMMENT PURGE: 20% of codebase is comments | Process, ongoing. |
| `RECONgame-mmm8` (P2) | OPEN — SESSION 2026-07-12: combat foundation + audit fixes (branch audit-fixes) | Current branch context. |

## 5. Branch state (git)

- Branch: `audit-fixes`
- 2 commits ahead of origin/audit-fixes (unpushed)
- Significant unstaged working tree: `CLAUDE.md`, `PLAYER_MANUAL.md`, `weapons_us.blend`, `gear_armory.blend`, `us_base_v3.blend`, plus 5 `.tres` files (m14, m16a1, m60, m70, ppsh41), plus autoload/ally scripts.
- Two deleted blends: `helmet_v3_fitted.blend`, `satchel_m3.blend`, plus `art_source/.gdignore`.
- **SESSION-CLOSE PROTOCOL:** must push before declaring done (CLAUDE.md rule).

## 6. What "the bottleneck" really is

The ADS work has TWO chains that have to land at the same time for the player to see anything different:

**Chain A (Blender, the primary):** every gun in `weapons_us.blend` / `weapons_v1.blend` (US) and the equivalent Soviet blend (if it exists; needs verification) needs:
1. A **sight line** at y=0, z=bore+sight_height, parallel to bore
2. **Rear sight** as a real see-through aperture (thin ring, big hole — game style)
3. **Front sight** clamped to the barrel, blade tip on the sight line
4. Three empties planted: `sight_rear_<gun>`, `sight_front_<gun>`, `muzzle_<gun>` (already done for M14 only)
5. Verified by `obj.ray_cast` with a fresh depsgraph, not by render (per M16 lesson, 2026-07-12)

**Chain B (Godot, the secondary bug):** the .tres files currently ship with placeholder values:
- AK-47, Mosin, M16A1, PPSh-41: `ads_position = Vector3(0, 0.05, 0.08)` — a hardcoded stub, not gun-specific
- M16A1 and PPSh-41 have `ads_rotation = Vector3(4, 0, 0)`; AK-47 and Mosin do NOT — they fall back to whatever the script's default is (probably `Vector3.ZERO`)

The two-frame transform bug is the symptom: hip_pose → ADS_pose lerp can be undefined if the ADS vector is uninitialised, AND if the gun's rest pivot is at a different anchor than the gun model expects, the lerp snaps from one frame to the other (CLAUDE.md "if hip vs ADS rot differs >90 deg, ADS spin risk" — this is exactly that).

**Chain A is the bottleneck the Summoner named.** Chain B is the *consequence* — when Chain A is done right, Chain B mostly solves itself (auto-align from sight markers writes the correct `ads_position` AND `ads_rotation` together).

## 7. The first question for the council

**The Summoner named a gun that isn't in the roster ("AK-74").** Two possibilities:
- (a) He means the **AK-47** (the Soviet rifle the project carries), and the 74 is a slip.
- (b) He means the **AKS-74** family (5.45×39) that some Soviet RPG systems use as the NVA's modern rifle — not modelled, not in any .tres, not in `weapons_v1.blend`.

Per `no-mid-phase-questions`: **autonomously assume (a) AK-47**, the only Soviet rifle the project carries, and verify by asking only if the decree would otherwise build on a wrong gun. State the assumption in the synthesis so the owner can correct it on first read.

## 8. The minimum scope for TODAY

**Day 1 (primary only):** the US gun ADS pass + the Soviet gun ADS pass. The work is per-gun, not a system rebuild. The M14 is the reference (markers + analytics tool 9h9f already exist). The M16A1 has the second-most work done (sight rebuild complete, but needs the three empties + verify-by-raycast).

**Day 2 (secondary, only if Day 1 closes):** the editor bug. The hypothesis is that the bug is NOT actually a frame-collision between hip and ADS — it is the **placeholder `ads_position`/`ads_rotation` values** in the .tres files colliding with the `weapon_model.position.lerp(target_pos, delta * ADS_SPEED)` and `rotation_degrees.lerp(target_rot, …)` lines in `weapon_holder.gd:795-796`. When `ads_position` is identical across 4 guns, the editor is adjusting ONE gun while 3 others carry identical "ADS" values — and switching weapons looks like the gun "snaps" because the editor's live view reflects a different .tres than the game just loaded. The editor's "Mode toggle" and the snapshot/revert logic may also be in play.

The two-frame hypothesis the Summoner named is *plausible* but not the most likely root cause. The honest finding: get ADS positions right (primary), then re-test the bug (secondary). It may vanish on its own.

## 9. Architects to wake

Five architects, in parallel, independent sight, no cross-talk. Plus a Devil's Advocate on each pass.

| Role | Question they own |
|---|---|
| **weapons-designer** | Per-gun sight geometry: what rear aperture + front post look right for the PSX read, what sight line is correct, what's the analytic `ads_position` for each. |
| **blender-stager** | The `weapons_us.blend` / `weapons_v1.blend` / Soviet blend workflow: how to add the three empties without breaking existing exports, how to lock the rigs, how to export per-gun with markers. |
| **viewmodel-programmer** | The Godot side: how `weapon_holder.gd` lerps hip↔ADS, why the editor's mode toggle and the game's view can disagree, what the two-frame bug actually is, what the .tres save/load contract is. |
| **animator** | Whether the per-gun ADS transform breaks the existing `rifle_idle` clip (it shouldn't — the rig change is additive — but verify) and whether the `viewmodel_anim.gd` listener plan from `GUN_ANIMATION_WORKFLOW.md` is reachable from this work. |
| **balance-feel** | The player-facing FOV: does the per-weapon `ads_fov` (already ratified by ADR-004) actually serve the sight geometry we're authoring, or do values need to come down (e.g., Mosin at 40° FOV with a peep sight is a different game than Mosin at 40° FOV with iron posts). |
| **devil's-advocate** | Challenges every claim. Names the tradeoffs. Hunts the "two-frame" hypothesis against the code. Asks: "Is the editor bug really two bugs? Is the blender work really parallel or are there dependencies? Are we introducing new fossils?" |

## 10. Output to the synthesis (Arbiter's job)

- Per-gun ADS status (US + Soviet) with blockers named per gun
- Editor-bug root-cause verdict (two-frame vs. placeholder-tres vs. the actual culprit)
- Day-1 build order (which gun to author first, second, third, in the order the workflow demands)
- The bead set to create
- The honest "what is sacrificed" call per the law
