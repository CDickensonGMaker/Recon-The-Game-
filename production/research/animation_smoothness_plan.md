# Animation Smoothness Plan — Synthesis of Three Investigation Lanes

**Date:** 2026-07-11
**Inputs:** Codebase audit (8 findings), Godot engine research (9 findings), Blender pipeline audit (8 findings)
**Scope:** Residual animation jank on rigged troopers — "really odd transitions", "gliding statues", "rotation is off a lot of the time", strafe overuse.
**Standing decree respected:** NO wholesale AnimationTree migration. One scoped proposal appears in Tier 2 and is flagged as a council decision.

Headline from the pipeline lane, worth stating up front: **the Blender→glTF→Godot export chain is clean.** fps chain 30/30/30 aligned, all 91 clips carry full 41-bone T+R+S channels, clips verified in-place. The residual jank is (a) engine-side logic and (b) authoring-side clip content — not export settings.

---

## 1. WHAT IS ACTUALLY CAUSING RESIDUAL JANK (ranked)

Duplicates across lanes have been merged. Where lanes disagreed, resolution is stated inline.

### #1 — Non-looping clips wired to persistent intents (THE surviving "gliding statue")
**Mechanism:** `_apply_loop_modes` marks clips looping only by name prefix (idle/run/walk/sprint/strafe/swim/firing). Intents `retreat`/`crippled` → `injured_walk_backwards` and `cover`/`surrender` → `kneeling_pointing` match no prefix → import play-once. A retreating enemy plays the clip once (~1–2 s), the skeleton **freezes mid-stride**, and `_execute_retreating` keeps pushing full `move_speed`. `play()` no-ops on same clip so it never restarts. Suppressed enemies freeze kneeling for the whole suppression.
**Evidence:** `scripts/visuals/model_actor.gd:150, 354-372`; `scripts/visuals/sprite_state_map.gd:102-105`; `scripts/enemies/enemy_base.gd:1391-1393`.
**Confidence: CONFIRMED.** Highest-probability source of the remaining gliding-statue complaint.

### #2 — Foot-slide: no `speed_scale` anywhere + walk band plays the run clip
**Mechanism:** Two compounding halves. (a) `speed_scale` appears nowhere in `scripts/` — every clip plays at authored 1.0× regardless of ground speed. (b) `MODEL_CLIP` maps `walk`, `patrol`, AND `aim_walk` all to `run_forward`. Combat movement runs at 0.5–0.6× `move_speed` (~2.0–2.5 m/s), patrol at 0.5× — nearly ALL non-idle movement plays a ~4+ m/s run cycle at full rate. Feet cycle ~2× faster than the ground passes. Blender lane adds a third half: exporters **delete** hips lateral-sway fcurves along with travel, stiffening gaits further.
**Evidence:** grep `speed_scale` = no matches; `sprite_state_map.gd:100-101`; `enemy_base.gd:1190-1191, 1561`; `ally_base.gd:568-569`; exporter hips-strip blocks in all five `tools/export_*.py`.
**Confidence: CONFIRMED** (rate mismatch), **LIKELY** (sway-stripping contribution).

### #3 — Yaw pops: instant `set_facing` write + discontinuous facing sources (+ probable baked clip yaw)
**Mechanism:** `set_facing` writes `global_rotation.y` instantly every physics frame with zero smoothing. Fine for one continuous source — but enemies swap between smooth aim lerp (LOS), RAW per-frame nav-step direction (no LOS; nav corners flip it in one frame), and sentry scan. Each handoff is an up-to-180° single-frame snap. Allies are worse: `_update_aim` early-returns without LOS, so an ally chasing last-known runs sideways facing a STALE aim direction, then snaps when LOS returns; stopping walking whips him to wherever he last aimed (0.09 speed² threshold swap).
**Second mechanism (Blender lane):** cover/sneak/strafe clips probe at 122–178° worst-bone deviation vs idle at frame 1 — magnitudes consistent with **whole-body yaw baked into the clips**, which ADDS on top of engine yaw when the ally cover override plays them. Hips X/Z *location* stripping does nothing about hips *rotation*.
**Evidence:** `model_actor.gd:344-348`; `enemy_base.gd:1096/1114/1431`; `ally_base.gd:245-250, 469-470`; headless probe start-pose table (cover set = top offenders).
**Confidence: CONFIRMED** (engine snap), **LIKELY — EYEBALL TEST** (baked clip yaw; probe folds stance and rotation together, needs in-engine confirmation before any Blender de-yaw pass).

### #4 — Clip start-pose mismatch + no phase sync: every crossfade whips limbs from t=0
**Mechanism:** `play(clip, 0.18)` always starts the target clip at t=0 and never phase-matches. Quantified by headless probe (worst-bone delta vs idle frame 1): run 56°, firing 76°, reloading 69°, strafe 91°. A 90° delta traversed in 0.18 s ≈ 500°/s limb whip — reads exactly as "odd/poppy transitions" even when the funnel picks the right clip. Crossfade phase-sync between looping cycles is an AnimationTree-only feature; bare `AnimationPlayer.play(blend)` fades old-from-wherever into new-at-frame-0, so feet teleport under the blend on every gait switch. Also: fixed 0.18 s blend is wrong for most pairs (pose delta varies 3–38× by pair).
**Evidence:** probe `start_pose_spread_deg_vs_ref`; `model_actor.gd:371`; AnimationPlayer docs (custom_blend = fade only).
**Confidence: CONFIRMED** (both halves; probe data is the targeting map for the Tier 3 art pass).

### #5 — Intent/override churn cluster: four flapping mechanisms feeding mutually-interrupting crossfades
Four confirmed, related defects. Merged here because they share one symptom (clip thrash) and one fix family (latch/stability-filter):
- **(a) Debounce is a rate limiter, not a stability filter.** A 1-frame blip is ACCEPTED instantly (if 250 ms stale) then the wrong clip is locked 250 ms while the real intent is refused. Strafe re-pick reverses `move_dir`, velocity lerps through zero, speed dips into the aim band ~100 ms → `strafe_l → aim → strafe_r`, two blends per strafe flip, per combat enemy. (`enemy_base.gd:376-382, 1150-1153, 1190-1194`; `ally_base.gd:268-274`)
- **(b) Firing flag window is inverted.** `firing = not can_fire and fire_timer < 0.12` is true in the 0.12 s *before the NEXT shot* (cooldown tail), not after the current one. Burst pauses (0.4–1.2 s) and slow weapons flap fire↔aim around every shot; the fire pose winds up BEFORE the bang. (`enemy_base.gd:373, 1572-1573`; `ally_base.gd:259, 582-583`)
- **(c) Ally cover hold/peek override flips on a 1-frame boolean every burst cycle,** bypassing the debounce entirely (`_update_sprite` returns before it). Crouch↔stand double-crossfade every ~0.7–1.5 s for every covered ally, all firefight long. (`ally_base.gd:552, 559-562, 577-585, 262-264, 149-152`)
- **(d) `_anim_override` + `has_cover` leak out of COMBAT** when the target dies: ally follows the player frozen in `idle_crouching_aiming` indefinitely (a gliding crouch statue), and the stale cover leash steers him toward a rock hundreds of meters back on next contact. (`ally_base.gd:513-520` exit paths skip cleanup; only clear sites `:564/:637/:678`)
**Confidence: CONFIRMED** (all four).

### #6 — 3D physics interpolation OFF: 60 Hz stepping under any higher render rate
**Mechanism:** `project.godot` has no `[physics]` section → `physics_interpolation=false`, tick 60. All bodies move in `_physics_process`, and `set_facing` yaw writes happen on the physics tick too — so translation AND rotation quantize to 60 Hz on a 120/144/165 Hz display. Both lanes agree: enable it (4.5-reworked pipeline, automatic). Known gotchas verified: skeleton bones exempt (fine — AnimationPlayer runs in IDLE callback; do NOT switch to PHYSICS), teleports/spawns need `reset_physics_interpolation()`, eyeball one ragdoll (PhysicalBoneSimulator3D on interpolated parent).
**Evidence:** `project.godot:277-280`; movement in `enemy_base.gd:428-453`, `ally_base.gd:316-347`; godot-proposals#10770, godot#110975.
**Confidence: CONFIRMED as mechanism — impact EYEBALL-CONDITIONAL** (zero on a locked 60 Hz monitor; the fix on anything faster).

### #7 — Import bake at 30 fps softens fast actions
**Mechanism:** `anim_library.glb.import` has `animation/fps=30` (default). All 91 clips quantize to 30 samples/s, linearly interpolated at render rate — fast recoils/flinches/deaths/turns get corner-cut, compounding the mushy-transition read. Cost of 60: ~2× keyframe memory on ONE shared file, trivial at PSX bone counts. (Source chain is 30 fps Mixamo, so 60 buys smoother *interpolation points*, not new detail — modest win.)
**Evidence:** `assets/models/characters/anim_library.glb.import` (fps=30, `_subresources={}` = compression OFF, keep it off).
**Confidence: CONFIRMED** (setting), moderate expected visual delta — eyeball.

### #8 — Minor confirmed items
- **All clips start at t=0.0333 s** (Blender frame 1 → 1/30 s; `export_anim_slide_to_zero=False`). Harmless today; makes `Animation.length` math dirty for the beaded one-shot latch (**4esw**) and death→ragdoll handoff. Fix (one flag × 5 exporters) BEFORE building those beads.
- **Ally leap override window fixed at 900 ms** regardless of clip length; short non-looping fallbacks freeze until the window ends. (`ally_base.gd:601-605`)
- **Medic exporter targets rig `MixamoRig` not `PSXRig`** — its clips don't match the shared-library merge contract. Decide: rename (2 lines) or bead as intentionally standalone.

### Lane disagreement — RESOLVED: `remove_immutable_tracks`
The Godot lane proposed flipping `animation/remove_immutable_tracks=false` to prevent missing-track pose contamination during crossfades. The Blender lane **parsed the shipped GLB** and found every clip channel-complete (uniform 123 channels = 41 bones × T+R+S, `keep_anim_armature` default ON), and any track Godot strips is rest-identical — it would blend to the same rest value anyway. **Blender lane wins: no change needed; the pipeline is currently immune.** Action downgraded to documentation: add the two non-negotiable invariant lines to exporter docstrings + a post-export GLB assert (123 channels/clip), because the immunity is one "size optimization" checkbox away from silently breaking with symptoms identical to the historic complaint.

---

## 2. THE PLAN

### TIER 1 — Quick wins (engine-side, S effort, no art changes, shippable this week)

Each item: file targets + what Caleb will SEE change in the combat bench.

**T1.1 — Loop-mark `injured_walk_backwards` and `kneeling_pointing`.**
`model_actor.gd` `_apply_loop_modes`: replace prefix heuristic with prefix list + explicit loop-name set (add the two clips; keep `laying_breathless` one-shot).
*Bench:* retreating enemies keep walking backwards the whole retreat; suppressed enemies breathe in their kneel instead of freezing into statues; surrendered men stay alive-looking. **Kills gliding-statue cause #1 outright.**

**T1.2 — Yaw smoothing at the single owner.**
`model_actor.gd` `set_facing`: replace direct write with frame-rate-independent `lerp_angle(current, target, 1.0 - exp(-k * delta))`, k ≈ 10–14. One function, fixes every caller. Plus the one-line ally source fix: with target but no LOS, prefer velocity direction over stale `current_aim_dir` (`ally_base.gd:469-470` area).
*Bench:* no more single-frame 180° body whips at nav corners, contact gained/lost, or when an ally stops walking. Turns become fast-but-visible rotations.

**T1.3 — Firing latch.**
Both `_fire_at_target`s: set `_fired_until_ms = now + 350`; both `_update_sprite` funnels: `firing = now < _fired_until_ms`. Replaces the inverted cooldown-tail window.
*Bench:* fire pose follows the muzzle flash and holds across intra-burst gaps — one transition per burst instead of two crossfades around every shot. Slow weapons (Mosin/SKS/M79) stop pumping fire↔aim.

**T1.4 — Invert the debounce into a stability filter.**
Both funnels (`enemy_base.gd:376-382`, `ally_base.gd:268-274`): track candidate intent + first-seen timestamp; commit only after ~150–250 ms of continuous winning (fire/death still bypass). Optional: hysteresis on the speed bands (enter run >3.4, exit <3.0), mirroring the suppression-gate pattern at `ally_base.gd:428`.
*Bench:* strafe direction flips become one clean blend (`strafe_l → strafe_r`), no aim-blip in the middle; no more twitch-transitions when speed rides a band edge.

**T1.5 — Ally cover pose latch + override leak fix.**
(a) `ally_base.gd`: `_cover_pose_until_ms` ≈ 600 ms minimum hold before re-evaluating hold/peek chain (or drive from the T1.3 firing latch — it already gives the right signal). (b) Clear `_anim_override = ""` and `_release_cover()` in `_change_state` whenever leaving COMBAT/SEEKING_COVER. (c) Derive leap window from actual clip length (ModelActor exposes `clip_length(clip)`).
*Bench:* covered allies stop bobbing crouch↔stand every burst cycle; after the firefight ends, allies STAND UP and walk normally instead of gliding after you in a frozen crouch; next contact they take nearby cover, not a rock 200 m back.

**T1.6 — Velocity-matched playback rate + real walk clip.**
`model_actor.gd`: add `set_locomotion_speed(mps)` — for locomotion loops, `_anim.speed_scale = clampf(mps / AUTHORED_SPEED[family], 0.6, 1.4)` (run ~4.2, walk ~1.6, strafe ~2.5 as starting nominals; measure once from the library), reset 1.0 otherwise. Call from both `_update_sprite` funnels where speed is already computed. Also remap the walk/aim_walk band in `sprite_state_map.gd:100-101` to an actual walk clip from the 91-clip library instead of `run_forward`.
*Bench:* the single most visible full-roster change — feet plant against the ground at combat/patrol half-speed instead of skating. Constant-velocity slide disappears on ~all non-idle movement.

**T1.7 — Phase-preserving seek on loop→loop switches.**
`model_actor.gd` `play()`: when both outgoing and incoming clips are locomotion loops (reuse loop-set membership), capture `phase = current_animation_position / current_animation_length` before `play(clip, 0.18)`, then `seek(phase * new_length, false)`. Add a per-clip phase-offset dict only if the eyeball check shows off-foot clips.
*Bench:* walk↔run↔strafe switches keep feet on the same beat — the "teleporting feet under the blend" flavor of odd transitions goes away. (Approximation quality depends on cycle-length similarity; Tier 3 phase-matching perfects it.)

**T1.8 — Flip on 3D physics interpolation (flag only; sweep is T2.4).**
`project.godot`: `[physics] common/physics_interpolation=true`. Verify AnimationPlayer callback mode stays IDLE (default). Keep a one-line revert.
*Bench:* only visible on >60 Hz displays or during frame wobble — moving soldiers and camera-relative motion stop micro-stepping. If Caleb's monitor is 60 Hz locked, expect nothing (that's fine, it's one line). Watch for streaks on spawns — if seen, T2.4 fixes them.

### TIER 2 — Structural (M–L effort, engine + import side)

**T2.1 — `play_with_capture()` adoption (4.3+ API).**
Build the beaded **one-shot latch (4esw)** on `_anim.play_with_capture(clip, 0.15)` — it snapshots the CURRENT output pose (paused clip, override chain end, post-ragdoll, death pose) and blends from it. Route ally cover override entries and all resume-from-anything transitions through it. Directly serves **death matrix v2 (ylma)**, **FlinchModifier (xphx)** recovery, and the **death-clip→ragdoll handoff** bead. Keep plain `play(0.18)` for loop→loop (capture lerps VALUES, wrong for cycling).
*Prereq:* T3.0 (slide_to_zero) so clip-length math is exact.

**T2.2 — Scoped AnimationTree proposal: upper/lower body split (COUNCIL DECISION REQUIRED).**
The honest minimum for fire-upper-over-run-legs is one small `AnimationNodeBlendTree` per rigged character: locomotion input → filtered `OneShot` (filter spine_01 up through arms/head, **NEVER `mixamorig:Hips`** — parent propagation drags the legs) for fire/reload/throw. The intent funnel survives: ModelActor keeps resolving clip names, routes locomotion into the tree when present, `play_upper(clip)` fires the OneShot. Deactivate tree before `pose_end_of`/ragdoll. Alternatives evaluated and rejected (see §4). This is scoped/局部 use, not wholesale migration — it needs an explicit decree amendment. If approved, fold in the 4.7 locomotion BlendSpace2D (speed × lateral) with `SYNC_MODE_CYCLIC_MUTABLE` + named blend points — engine-level cycle sync replaces the T1.7 seek trick AND the discrete strafe_l/r hard picks (the strafe-overuse complaint) in one node. Effort L. Sacrifice named: two animation code paths until v1 rigs retire; AnimationPlayer↔AnimationTree blend semantics are documented-inconsistent (godot#70207), so blend feel re-tunes.

**T2.3 — Import fps 30→60 on `anim_library.glb`** (and any character GLBs still carrying baked clips). One `.import` line, reimport, eyeball a fire/death/turn. Leave compression OFF (lossy, known jitter source).

**T2.4 — Physics interpolation completion sweep.**
`reset_physics_interpolation()` after every teleport/spawn/warp: `spawn_enemy` placement, ally spawn, unstick nudges, casualty placement via `pose_end_of`. Audit `player.gd` for `_process`-time body-transform writes (camera bob/recoil belong on a visual child). Eyeball one ragdoll death (PhysicalBoneSimulator3D-on-interpolated-parent risk, low).

**T2.5 — LookAtModifier3D head-aim (4.4+).**
Cheapest "alive, not statue" win: enemies/allies turn heads toward target/heard sounds, zero new clips. Composes with the shipped SeveredBonesModifier pattern. Set `relative` explicitly — the 4.7 default flip (true→false) makes old snippets behave differently. Same lane as FlinchModifier (**xphx**) — build as siblings.

**T2.6 — Wire existing-but-unused transition clips into the funnel.**
The library already ships `start_walking`, `stop_walking_with_rifle`, `run_to_stop`, `idle_to_run`-family clips that the funnel never plays. Zero Blender hours; needs the T2.1 one-shot latch as the playback mechanism. Do after T1 lands — T1.4/T1.7 may make most pairs acceptable without them.

**T2.7 — Pipeline guard-rails (S, do alongside anything above).**
(a) `export_anim_slide_to_zero=True` in all five exporters (**T3.0 prereq — do first**). (b) Extend the post-export GLB probe into a standing check: assert 123 channels/clip, 30 Hz effective, expected clip-name set, no NaN/inf in output accessors. (c) Docstring invariants: `keep_anim_armature` stays ON; `remove_immutable_tracks` safe ONLY while channel-complete. (d) Decide the medic `MixamoRig`→`PSXRig` question explicitly.

### TIER 3 — Art-side (Blender, anim_library.blend single-file pipeline — every fix propagates roster-wide on re-export; characters never re-export, mesh-only contract)

Ordered by payoff/hour, targeted by the probe data. Each step independently shippable.

**T3.0 — Exporter slide-to-zero flag** (listed in T2.7a; it's the gate for bead 4esw/handoff length math).
**T3.1 — Loop seam audit** (hours, mechanical): for every looping clip assert first pose == last pose; probe script extends trivially to emit the worklist. A seam mismatch is a rhythmic tick every cycle.
**T3.2 — De-yaw the cover/strafe set** *(pending the eyeball test in §3)*: sample hips world yaw at frame 1, rotate all hips rotation keys by the inverse so each clip faces canonical forward. **Do BEFORE any engine-side cover-facing compensation or you compensate twice.** Targets: `cover_sneak_l/r` (172–178°), `cover_to_stand` (177°), `crouched_sneaking_r` (167°), `strafe_1` (122°).
**T3.3 — Phase-match the locomotion family**: cyclically slide keys so every walk/run/strafe/sprint cycle starts at left-foot contact (lossless on loops). Upgrades T1.7's approximation into exact on-foot switches; standardizes where transitions land.
**T3.4 — Canonical rifle-ready start pose** on the stationary combat set (idle_aiming 37.6° off idle, firing_rifle 76°, reloading 69°): repose frames 1–3 toward one shared stance. Biggest dent in "odd transitions" for the least art skill — these are the highest-traffic funnel pairs (≤0.5 m/s aim/fire band).
**T3.5 — Hips detrend instead of delete** in the shared exporter helper (factor the five duplicate strip blocks into one module): per clip/axis subtract the linear travel component (loops: cyclic per-frame mean) so travel → 0 but lateral weight-shift sway SURVIVES. Reversible; source .blend still has all curves. A/B one unit.
**T3.6 — Dedicated transition clips** only for pairs still ugly after T3.3+T3.4. Last resort, most hours.
**T3.7 — Per-transition blend-time table** (engine-side, but data comes from the probe): fixed 0.18 s is wrong across a 3–38× pose-delta spread — 0.05–0.10 s for fire, 0.25–0.35 s for big stance changes. Small dict in `model_actor.gd` keyed by (from_family, to_family). Do after T3.4 shrinks the deltas, or you tune twice.

### Bead composition
| Existing bead | Plan items that serve it |
|---|---|
| one-shot latch (**4esw**) | T2.1 (build ON `play_with_capture`), T3.0 (exact lengths), T2.6 (its first consumers) |
| death matrix v2 (**ylma**) | T2.1 (capture-based entries), T1.1 loop-set groundwork (explicit per-clip loop manifest is the long-term home) |
| FlinchModifier (**xphx**) | T2.5 (LookAtModifier sibling, same SkeletonModifier lane), T2.1 (capture recovery) |
| death-clip→ragdoll handoff (unbeaded ID) | T2.1, T3.0, T2.4 (ragdoll-under-interpolation eyeball) |

New beads to file at THE RECORD: one per T1 item (T1.1–T1.8, all S), T2.1–T2.7, T3.0–T3.7, plus the medic-rig decision. T1 items have no dependencies among themselves except T1.3→T1.5 (cover latch can reuse the firing latch signal).

---

## 3. EYEBALL PROTOCOL — combat bench checklist

Caleb judges visually; each behavior below maps to specific plan items so feedback lands on the right bead. Suggested bench: zoo/combat scene, 3–4 enemies + 2 allies, one long sightline, one cover rock.

**Before ANY fixes — two calibration checks:**
1. **Monitor check (decides T1.8 weight):** what Hz is the play display? If 144/165 Hz, expect T1.8 to matter a lot; if 60, skip judging it.
2. **Cover-yaw check (decides T3.2):** order an ally into cover. Does he peek/lean facing the WRONG direction or snap 90–180° entering/leaving cover? YES → baked clip yaw confirmed, T3.2 goes on the Blender queue. NO → downgrade T3.2, the probe numbers were stance not yaw.

**Per-fix checklist — stare at these, in this order:**

| # | Stare at | BAD (before) | GOOD (after) | Plan item |
|---|---|---|---|---|
| 1 | Enemy retreating after losing a fight | Freezes mid-stride, slides backwards like a statue | Walks backwards continuously the whole retreat | T1.1 |
| 2 | Suppressed enemy behind cover | Frozen kneel, dead-still | Holds kneel with the loop alive | T1.1 |
| 3 | Ally after the last enemy dies | Follows you gliding in a frozen crouch | Stands up, walks normally | T1.5 |
| 4 | Ally in cover during a firefight | Bobs crouch↔stand every burst (~1/sec) | Holds pose through bursts, changes stance rarely and deliberately | T1.5 (+T1.3) |
| 5 | Enemy strafing in combat, watch a direction flip | Stutters: strafe→aim-blip→strafe, double blend | One clean blend to the other strafe | T1.4 |
| 6 | Any shooter with a slow weapon (Mosin) | Pumps between aim and fire poses around every shot; fire pose BEFORE the bang | Fire pose lands WITH the shot, holds briefly, settles to aim once | T1.3 |
| 7 | Enemy walking a nav path around corners; ally who stops walking | Whole body snaps instantly to new heading / whips to old aim direction | Fast smooth turn, no single-frame snap | T1.2 |
| 8 | Feet of ANY combat-moving or patrolling trooper, mid-distance | Feet cycle visibly faster than ground passes (skating) | Feet plant and track the ground | T1.6 |
| 9 | A trooper accelerating walk→run or run→strafe | Feet teleport to a new stride position under the blend | Stride carries through the switch on the same beat | T1.7 (later T3.3) |
| 10 | Whole scene panning, high-Hz monitor only | Soldiers micro-step/judder against the smooth camera | Motion matches camera smoothness | T1.8/T2.4 |
| 11 | Transitions into/out of firing at standstill | Limb whip — arms lash between stances in ~0.2 s | Arms move, but don't LASH | T3.4 (+T3.7) |
| 12 | Fast actions: recoil, flinch, death fall | Slightly mushy/corner-cut motion | Crisper snap on fast moves | T2.3 |
| 13 | Walking gait character, side view | Pelvis dead-level laterally, "on rails" stiffness | Subtle side-to-side weight shift | T3.5 |
| 14 | Looping clip watched for 3+ cycles (run, kneel) | Rhythmic tick/pop once per cycle | Seamless loop | T3.1 |

**Reporting shorthand for Caleb:** name the row number + trooper type ("row 5, enemy strafe still stutters") — that maps 1:1 to a bead.

**Verification order after Tier 1 ships:** rows 1–8 should ALL change in one build. Anything in rows 1–8 still bad after Tier 1 means either the fix regressed or the cause was misattributed — flag it before starting Tier 2.

---

## 4. WHAT WE REJECT (tradeoffs named)

1. **Wholesale AnimationTree migration.** Already rejected by decree; nothing in three lanes overturns it. The scoped T2.2 BlendTree is the ONLY Tree exposure proposed, and it's gated on a council decision. *Sacrificed:* engine-native state-machine sync conveniences stay unused; we keep hand-rolling intent logic — which is fine, the funnel works.

2. **Root motion for locomotion.** Works on plain AnimationPlayer (`root_motion_track` is on AnimationMixer) but inverts authority: clips would drive position while our AI (nav paths, suppression retreats, formation moves) commands velocity — reconciling means clamping root deltas every tick, plus known engine grinding against physics bodies (godot#90402). And the Mixamo library is in-place: no root translation exists to extract without re-authoring root bones per clip (effort L, per-clip). *Sacrificed:* perfect foot-planting during authored one-shots (cover leaps, melee) — revisit ONLY for those specific clips if T1.6+T3 leaves them ugly.

3. **Flipping `remove_immutable_tracks=false`** (Godot lane's proposal). GLB parse proves the pipeline is channel-complete, making the flip a no-op with a memory cost. *Sacrificed:* nothing — replaced by the documented invariant + GLB assert (T2.7). If a future export ever ships channel-incomplete clips, revisit `deterministic=true` on the merged AnimationPlayer first (zero-reimport), watching that deaths still settle (zero-weight pulls toward rest).

4. **Animation compression.** Confirmed OFF; stays off. Documented lossy bitpacking, known jitter source. *Sacrificed:* a few MB on one shared file. Nothing at PSX bone counts.

5. **Two-AnimationPlayer layering for the body split.** Mechanically possible but requires per-clip track surgery (strip leg tracks from every fire/reload/throw clip) across 91 clips, with two independent unsynced crossfade timelines — hand-reinventing the engine's filter feature. *Sacrificed:* a no-Tree body split; T2.2 is strictly cheaper to maintain.

6. **Custom SkeletonModifier3D for playing authored clips.** Modifiers are the right lane for PROCEDURAL adjustment (Flinch, LookAt, SeveredBones) and the wrong lane for authored clip playback — you'd reimplement pose sampling, blending, and crossfades by hand. *Sacrificed:* nothing; the modifier lane stays open for xphx/T2.5.

7. **AnimationPlayer `callback_mode_process = PHYSICS`.** Tempting "sync everything to physics" instinct, but it makes bone animation quantize to 60 Hz — the exact artifact T1.8 removes. Bones already update per rendered frame in IDLE mode. *Sacrificed:* nothing.

8. **Draco compression / `keep_anim_armature` off / NLA_TRACKS export mode.** All three are documented footguns (mis-indexed clips in 4.4.x NLA mode; T-pose bleed from channel-stripping; mesh corruption risk). The current ACTIONS-mode exporter block is frozen as pipeline standard. *Sacrificed:* file size we don't need.

9. **Fixing everything in Blender first.** The art pass (Tier 3) has the highest ceiling but the worst leverage-per-day and blocks on nothing shipping meanwhile. Tier 1 is eight S-effort engine fixes that attack five of the seven top causes THIS WEEK. *Sacrificed:* some Tier 1 work (T1.7 seek trick, T3.7 blend table) gets superseded or re-tuned if T2.2/T3.3 land later — acceptable rework, days not weeks.
