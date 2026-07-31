# ANIMATION + MODEL WISHLIST — Blender work for Caleb

All work lands in `anim_library.blend` → one re-export propagates roster-wide
(mesh-only character contract). Ordered by payoff. Sources: smoothness plan
(`production/research/animation_smoothness_plan.md`), CoD2000 living-fight
decree, current library audit (91 clips, listed via `tools/list_clips.gd`).

## LANDED 2026-07-30 via the Mixamo MCP — A1..A5 are DONE

`anim_library.glb` 124 -> **134 clips** (verified by parsing the GLB's JSON chunk, not the log).
**Mixamo clips are DROP-IN: `PSXRig` IS a Mixamo skeleton — 41/41 bone names, scale 1.0, measured
by `tools/probe_mixamo_fit.py`. There is no retarget step.** Chain: download FBX (filename stem =
house clip name) -> `tools/import_mixamo_clips.py` -> `sync_clips_into_library.py --bones-only` ->
`export_anim_library.py`.

**Second pull (medic + ambient) brought it to 156 clips, 13.64 MB.**

| Clip | Wired? |
|---|---|
| `plant_charge` | YES — `sapper_charge.gd` `PLANT_CLIP` (was chaining `mortar_dropper`) |
| `death_from_the_left` | YES — 3-way `side` test in `enemy_base.gd` + `ally_base.gd`, `death_left` intent |
| `medic_treat_give` | YES — `squad_system.gd` `_process_revive`, via new `AllyBase.set_performance()`. Cleared on all 3 exit paths; a latched override freezes a live man |
| `smoking` `sitting_drinking` `sitting_talking` `standing_talking` `telling_secret` `sleeping_laying` `sleeping_sitting` `sitting_idle_b/c` | YES — VC `CAMP_ROLE_CLIPS` (`enemy_base.gd:484`). **Fixed: the `sleep` role was playing `laying_breathless`, the DOWNED/dying clip — sleeping men read as casualties** |
| `plant_seeds` `digging` `praying` `praying_b` | YES — `civilian.gd`, keyed off `scheduled_action()` not pose; `praying` is elders on `sit`. Civilian chains still carry NO armed clip (the T-pose-not-firing-line law) |
| `smoking` (US) | YES — `off_duty` garrison occupation; `mess_cook` gets `sitting_idle_b` |
| `carry_wounded` + `being_carried` | YES — `_execute_aid` sets BOTH halves at drag start; `_reset_aid` clears `work_clip` |
| `grenade_throw` | YES — one-shot window over the lob's 1s windup (`_throw_until_ms`). The telegraph was a shout and floating text with **no body behind it** |
| `stumble_hit` | YES — the solid-hit stagger branch (`>= max_hp/3`), skipped when already low: the clip would launch a crouched man upright |
| `wounded_crawl` | YES — the `crippled` intent (was `injured_walk_backwards`, i.e. crippled men moonwalked) + a 0.8 m/s entry in `_CLIP_SPEED` |
| `medic_treat_receive` | **NO CONSUMER EXISTS.** The squad medic revives the PLAYER, who has no third-person body. Needs downed-ALLY revive to be built first |
| `salute` · `standing_arguing` · `briefing_group` · `kneeling_idle` | in the GLB, no caller. The first three are the body-language risks below — wire after you judge them |
| `prone_idle` · `crouch_to_prone` · `prone_to_crouch` · `prone_firing_rifle` | in the GLB, **needs a prone posture the state map can select** — still engine work |

**LOOP MODES (caught in the wiring pass, would have shipped as freezes):** the loop heuristic is a
prefix match, and it misses nearly every ambient clip — `sitting_idle_b` is not `sitting`,
`prone_idle` does not start with `idle`. All held poses are now named in `_LOOP_NAMES`
(`model_actor.gd`). A play-once ambient clip freezes the man the instant it ends, which is the
silent-freeze bug class exactly.

**Unjudged by eyes:** the conversational clips (`standing_arguing`, `briefing_group`, `telling_secret`)
are contemporary-Western body language and may read wrong in a village. `briefing_group` is 1401
frames and `sitting_talking_b` 1350 — the library grew 8.53 -> 13.64 MB, mostly from these.

**`__mg` / `__launcher` / `__bolt` families: DEFERRED by the Summoner, 2026-07-30** ("that's stuff we
can do later"). Not cancelled, just not now - the MG gunner and RPG man keep holding their weapons
like rifles meanwhile. Route when reopened: one arms-only hold delta -> all 9 clips of a family via
`bake_family_clip.py`, headless. Only the hold needs a human.

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

## E. WEAPON MODELS (WW2 batch — replace oversized downloaded stand-ins)

| # | Model | Faction | Status in game data |
|---|-------|---------|---------------------|
| E1 | **Thompson M1928/M1A1** | US | Weapon EXISTS (17 dmg, thompson.tres) — just needs your model to replace the downloaded one. World model + FP arms variant. |
| E2 | **BAR M1918** | US | NEW weapon — no .tres. Damage value-of-record is a Summoner/ADR-016 call (suggest M60-class 28, slower handling). |
| E3 | **Kar98k** | VC (captured/French-supplied) | Scene name exists only as a borrowed stand-in viewmodel. NEW weapon data needed (suggest near Mosin 32). |
| E4 | **Nagant M1895 revolver** (assumed from "hover revolver" — confirm) | VC | NEW weapon — no .tres (suggest M1911-class 11, 7-round, slow reload). |

Per-gun scope: world mesh (PSX budget) + `*_fp.glb` arms export on the proven
fp_arms pipeline + MuzzlePoint. Engine wiring (scenes/tres/alignment bench)
is Claude's side, same as the 7-viewmodel batch.

## F. ANIMS SURFACED BY THE BATCH RESEARCH (v2 items — every v1 ships without them)
- **heli_board + heli_exit** (author LEFT side only; mirror is free) — Huey v2
- **medic kneel-aid** — after the medic rig fix (C3)
- **wounded writhe on back** — optional; downed-enemy v1 uses laying_breathless + procedural chest-rise
- (wounded_crawl A4 and surrender idle A3 above both got PRIORITY UPGRADES — downed-enemy + capture systems consume them)

## D. ALREADY COVERED — do NOT make these
- Flinch clips → procedural FlinchModifier (bead xphx).
- Walk cycles → library already ships a full walk_*/sprint_*/run_* 8-direction family (the engine just started using them).
- Transition clips (start_walking, stop_walking_with_rifle, run_to_stop, cover transitions ×3, turns) → exist; engine wiring is bead-tracked (T2.6, needs one-shot latch first).
- EXPORT_ANIMATIONS=False flip (bead 00qp) → after your windowed lab confirm of the library wiring.
