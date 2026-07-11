# ANIMATION WISHLIST — Blender work for Caleb

All work lands in `anim_library.blend` → one re-export propagates roster-wide
(mesh-only character contract). Ordered by payoff. Sources: smoothness plan
(`production/research/animation_smoothness_plan.md`), CoD2000 living-fight
decree, current library audit (91 clips, listed via `tools/list_clips.gd`).

## A. NEW CLIPS (things the library genuinely lacks)

| # | Clip | Why / what it unblocks | Notes |
|---|------|------------------------|-------|
| A1 | **death_from_the_left** | Death matrix v2 (bead ylma) has front/back/right + 2 headshots + 1 crouch death — LEFT is the one missing direction. | Mirror-pose death_from_right as a starting point. |
| A2 | **grenade_throw** (standing) | Enemies/allies throw grenades with NO throw animation today — the LUU DAN telegraph is audio-only. Decree wants readable telegraphs. | Crouched variant optional later. |
| A3 | **surrender / hands-up idle** | CHIEU HOI ships today borrowing kneeling_pointing (a combat pose — reads wrong). | Kneeling, hands behind head, looping. |
| A4 | **wounded_crawl** (loop) | Bleed-out fighting chance + decree "wounds over kills" doctrine. Crippled state currently borrows injured_walk_backwards. | Belly crawl, slow. |
| A5 | **stumble_hit** (short, ~0.5s) | Decree: solid hit while sprinting = visible stumble, not just a fire-rate stall. Pairs with the procedural FlinchModifier (bead xphx). | One-shot, forward lurch + recover. |
| A6 | **walk_forward_aiming** | The ≤3.2 m/s combat band now plays walk_forward — if that clip reads as patrol-relaxed rather than rifle-ready, this is the dedicated aimed-walk. **Check in bench first** — walk_forward may already read fine. | Only if eyeball says so. |

## B. CLIP SURGERY (existing clips, retiming/reposing — from the probe data)

| # | Task | Targets | Payoff |
|---|------|---------|--------|
| B1 | **Canonical rifle-ready start pose** (plan T3.4) | idle_aiming (37.6° off idle), firing_rifle (76°), reloading (69°) — repose frames 1–3 toward one shared stance | Biggest dent in "odd transitions"; these are the highest-traffic pairs. |
| B2 | **De-yaw the cover/strafe set** (plan T3.2) — **ONLY IF the bench eyeball confirms it** (order an ally into cover: does he face the wrong way / snap 90–180° entering?) | cover_sneak_l/r (172–178°), cover_to_stand (177°), crouched_sneaking_right (167°), strafe_2 (122°) | Kills cover-entry body snaps at the source. |
| B3 | **Loop seam audit** (plan T3.1) | Every looping clip: first pose == last pose | Removes the once-per-cycle rhythmic tick. Mechanical — the probe script can emit the worklist. |
| B4 | **Phase-match locomotion family** (plan T3.3) | walk/run/strafe/sprint cycles all start at left-foot contact (cyclic key slide, lossless) | Upgrades the engine's phase-seek approximation into exact on-foot switches. |

## C. EXPORTER TWEAKS (minutes each, in tools/export_*.py)

| # | Task | Why |
|---|------|-----|
| C1 | **`export_anim_slide_to_zero=True`** in all 5 exporters (plan T3.0) | All clips currently start at t=0.033s — dirty length math. **Gates the one-shot latch bead (4esw) and death→ragdoll handoff.** Do this one FIRST. |
| C2 | **Hips detrend instead of delete** (plan T3.5) | Exporters currently strip hips lateral sway along with travel — gaits read "on rails". Subtract the travel component, keep the weight-shift. A/B one unit. |
| C3 | **Medic rig decision**: export_medic_gltf.py targets `MixamoRig`, not `PSXRig` | Medic clips don't match the shared-library contract. Rename (2 lines) or declare standalone. |
| C4 | **Post-export GLB assert** (plan T2.7b) | Assert 123 channels/clip + expected clip names — the pipeline's crossfade immunity is one "optimize size" checkbox away from silently breaking. |

## D. ALREADY COVERED — do NOT make these
- Flinch clips → procedural FlinchModifier (bead xphx).
- Walk cycles → library already ships a full walk_*/sprint_*/run_* 8-direction family (the engine just started using them).
- Transition clips (start_walking, stop_walking_with_rifle, run_to_stop, cover transitions ×3, turns) → exist; engine wiring is bead-tracked (T2.6, needs one-shot latch first).
- EXPORT_ANIMATIONS=False flip (bead 00qp) → after your windowed lab confirm of the library wiring.
