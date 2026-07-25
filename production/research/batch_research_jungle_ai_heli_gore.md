# Batch Research: Jungle / AI Doctrine / Huey / Gore / Tools

**Date:** 2026-07-10 | **Status:** Research complete — awaiting green-light, NO implementation started
**Method:** 5 parallel research lanes (headless pipeline + vegetation, VC/US doctrine, Huey + scripted events, gore variants + downed enemies, hitbox tooling), synthesized here.
**Canon constraints honored:** GAME_GUIDE.md + 15 ADRs, AI-goals decree (`synthesis_ai_goals.md`), CoD2000 living-fight decree (`synthesis_cod2000_living_fight.md`) incl. its gates (G0 = witness bug o18o + perf day; presentation-before-punctuation).

> **POINTER CORRECTION, 2026-07-23.** This document is LOG class — never cite it as authority. Its
> `MISSION_DESIGN_RESEARCH.md` citations (`:142`, `:161`) are **dead**: that file was deleted on
> purpose by the Summoner. Do not restore it or go looking for its sections.
> **Banner extended (corrected 2026-07-25, ghost-code audit):** the same correction covers ALL
> `MISSION_DESIGN_RESEARCH.md` mentions in this file, including §6's verdict and sources lines
> (currently `:149` and `:168`) — every such citation is dead, not just the two line numbers above.

---

## 1. Headless Blender batches (model MAKING, not just export)

**Verdict: YES — already proven in this exact repo.**

`tools/make_vc_gibs.py` already does headless *procedural mesh surgery* (bmesh region cuts, cap-face generation, vertex-group weighting) via `blender -b`. Generation reliability is proven in-house, not theoretical.

**Approach:**
- Binary: `C:\Program Files\Blender Foundation\Blender 5.0\blender.exe` — NOT on PATH; invoke with full quoted path (PowerShell needs the `&` call operator).
- Established pattern: `blender -b <file.blend> -P tools/script.py` (docstrings in `tools/export_anim_library.py`, `export_viewmodel.py`, `make_vc_gibs.py`, `export_vc_guerilla.py`).
- **Reliability rule** (confirmed by Blender API docs + our own `IK_ANIMATION_WORKFLOW.md` §3): `bpy.data` + `bmesh` APIs are context-free and fully reliable in `--background`. The ONLY fragile things are `bpy.ops` operators needing a window/VIEW_3D context (e.g. `nla.bake` — we already learned this; use `anim_utils.bake_action`). `import_scene/export_scene.gltf` work fine headless.
- From-scratch generation: `blender -b --factory-startup -P script.py` (no .blend needed, no addon interference).
- **MCP vs headless:** MCP (live GUI) is for interactive authoring with Caleb's eyes — one prototype, screenshots, tuning. Known crash modes (scripted playback crashed Blender twice; black screenshots when minimized). Pure headless wins for BATCH: deterministic, repeatable, no GUI-state contamination, runs with the GUI closed.
- Recommended flow: prototype ONE variant live via MCP for visual sign-off → encode into a headless `tools/gen_*.py` → batch-run all variants.

**Split:** Claude 100% from this window (script, `blender -b` run, GLB verification via JSON-chunk parsing, Godot import test). Caleb: visual approval of prototypes only.
**Effort:** Zero new infrastructure — pipeline exists. Cost is only per-script (see §2).
**Sequencing:** No dependencies. This is the enabler for §2 and feeds §8's re-exports.
**Sources:** `tools/export_anim_library.py` (invocation docstring), `tools/make_vc_gibs.py` (headless bmesh precedent), `art_source/characters/fp_arms/IK_ANIMATION_WORKFLOW.md` §3–5, docs.blender.org/api/current/bmesh.html, memory `recongame-blender-workflow.md`.

---

## 2. Jungle vegetation batch (palms, vines, grass, sway)

**Verdict: YES — palms found; clean donor material. Needs de-duplication and grounding, not disc removal. Sway = vertex shader, skeletal rejected.**

### 2a. Palm donor audit (RealVietnamRTS, read-only)
Found (only 3D vegetation in the RTS repo): `C:\Users\caleb\RealVietnamRTS\assets\models\terrain\foliage\`
- `jungle_light.glb` — 1 palm, 230 verts / 116 tris, 2 prims
- `jungle_medium.glb` — 8 palms, 1,772 verts / 892 tris, 16 prims
- `jungle_heavy.glb` — 176 palms, 39,364 verts / 19,624 tris, 352 prims, 3.2 MB

All the SAME palm archetype duplicated with slight lean/scale: trunk prim (bark_willow, 150–176 verts) + fan crown prim (Palm_Leaf alpha texture, 56 verts). Consumed by RTS `tree_node.gd:20-22` / `vegetation_manager.gd:243-245`.

**Two red flags:**
1. Materials duplicated PER TREE — `jungle_heavy` has 370 materials = 352 Godot surfaces = 352 draw calls per instance. Batch MUST consolidate to one bark + one leaf material.
2. NO ground disc exists in any GLB (contrary to expectation) — but trunks FLOAT: lowest verts at y=0.32–0.65. Real fix = drop each palm base to y=0 (or sink 0.2 m). Keep a disc-removal heuristic anyway as insurance (flag loose parts that are flat <5 cm, normals within ~10° of +Y, at y-min, radially symmetric or named ground/dirt).

Extra textures for a second species: `RealVietnamRTS/terrain/vegetation/textures/` (`_palma_1..4_apg_.png`, `_kokos_apg_.png`, full CocosNucifera PBR set).

### 2b. Batch spec (`tools/gen_jungle_vegetation.py`, headless)
Import `jungle_medium.glb` → pair trunk+crown prims by horizontal proximity → extract ONE canonical palm → weld to 2 shared materials → disc heuristic → variants: 3 sizes × 2–3 leans (scale 0.7/1.0/1.35 ±10% per-axis jitter, lean 2–8°, crown yaw randomized) → base to y=0 → paint vertex-color sway mask (R: 0 roots → 1 frond tips; G: frond-tip flutter) → vines: bpy curve per vine (catenary droop from crown edges or down trunk), 2–3-sided bevel, ~30–60 tris each, leaf-alpha material, same mask scheme → downres embedded textures to 128–256 px (PSX) → export mesh-only GLBs to `RECONgame/assets/models/vegetation/` as `palm_s_01.glb` … `palm_l_03.glb` + vine variants. Per-palm budget ~116–250 tris.

### 2c. Grass + sway shader
- **Existing infra:** `scripts/world/ground_clutter.gd` = 8-layer MultiMesh billboard scatter (deterministic per 22 m cell, ALPHA_SCISSOR 0.4, CULL_DISABLED, NEAREST, shadows off, zone-aware) — ideal insertion point. `terrain/vegetation/vegetation_manager.gd:33` documents the perf ceiling: **Intel UHD integrated graphics** — this drives every choice. `poisson_sampler.gd` exists. NO wind shader exists anywhere in RECONgame yet.
- **Sway decision:** vertex-displacement spatial shader, NOT skeletal (unaffordable on Intel UHD at jungle density, and wrong-era tech — PSX games did cheap vertex wobble; can even quantize VERTEX for authentic vertex snap). In `vertex()`: sin-based offset, phase from `NODE_POSITION_WORLD` (per-instance origin — confirmed MultiMesh-compatible, the published Godot-4 grass-shader pattern) so the jungle doesn't sway in unison; two frequencies (slow trunk lean + faster frond flutter). Root anchoring: vertex-color R/G mask on palms/vines (painted by the batch — Victor Karp Godot-4 foliage method), plain `UV.y` for grass cards. Optional `INSTANCE_CUSTOM` per-instance wind strength. One ~60–90-line shader shared by palms/vines/grass, mask source a uniform switch; replicates the existing material recipe (scissor, cull off, nearest) as ShaderMaterial.
- **Grass mesh:** star-fan card = 3 quads at 60° (6 tris) or 2-quad X-cross (4 tris) — from the same batch OR pure ArrayMesh in GDScript (no Blender needed); UVs onto existing `terrain/textures/clutter/` grassland/Plant alpha textures. Swap `ground_clutter.gd`'s QuadMesh — rescatter logic unchanged.
- **Perf budget (Intel UHD):** sway is near-free; real budgets are (1) fill-rate/overdraw — tight cards, scissor not blend; (2) draw calls — one MMI per mesh+material; batch all trunks of a variant per chunk in one MMI, crowns in another (this is why material de-dup is mandatory); (3) shadows off, `visibility_range` per chunk, existing billboard system (`billboard_vegetation.gd` + `terrain/textures/billboards/`) as far-LOD — meshes near, billboards far.

**Split:** Claude: generator script, batch run, GLB verification, shader, star-fan, `ground_clutter.gd` integration, palm scatter layer, Intel UHD profiling. Caleb: eyeball canonical palm + one variant sheet, veto silhouettes, judge sway amplitude by eye; optional hand-tweak of the canonical palm before fan-out. No per-variant hand work.
**Effort:** ~3 sessions total (generator ~250–350 lines + batch + import = 1; shader + grass + integration = 1; scatter layer + billboard LOD + profiling = 1). Vines +half session. Risk: fill-rate tuning on integrated graphics, not the shader.
**Sequencing:** Independent of all gates. Pure atmosphere-pillar payoff.
**Sources:** GLB JSON chunks parsed directly; RTS `tree_node.gd` / `vegetation_manager.gd`; victorkarp.com/godot-foliage-wind; godotshaders.com multimesh grass shaders.

---

## 3. US/VC asymmetric AI doctrine

**Verdict: YES — the RealVietnamRTS study exists and is rich; mapping onto RECONgame is mostly DATA plus three small deltas. Composes cleanly with both standing decrees, no rewrites.**

### 3a. What the RTS study encodes (read-only extraction, done)
- `GAME_BIBLE.md` §6 + locked D-003: VC is fully asymmetric, not a re-skin. US = visible logistics, deliberate buildup, hold-and-clear; VC/NVA = caches/tunnels/porters, strike-and-fade, attrition.
- `doctrine-system.md` §5: VC Local Force = ambush/harassment/sappers/tunnels, night +25%, spider holes, punji, caches; Main Force = massed assault/siege, human wave, trail resupply, weakness = less stealth + logistics-dependent.
- **The AI controllers encode it as NUMBERS:** `vc_controller.gd` — aggression 0.4, retreats at 45% HP (EARLY), small frequent waves (4/40s), multi-directional, GuerrillaState {HIDING, SCOUTING, PREPARING_AMBUSH, AMBUSHING, HIT_AND_RUN, TUNNELING, RETREATING}, ambush_chance 0.4, trap loop. `nva_controller.gd` — aggression 0.8, holds to 20% HP, big waves (10/50s), single axis, StrategicState {BUILDUP → PROBING → ARTILLERY_PREP → MAIN_ASSAULT → EXPLOITATION → WITHDRAWAL}, sappers, AA, siege.
- `ambush_manager.gd`: prepared sites w/ trap lines, 15 m trigger, hold-until-triggered. Morale doc: VC +0.1 base.
- **Core portable claims:** VC retreats at 2× NVA's threshold, half as aggressive, prefers prepared ambush over meeting engagement, treats retreat as a TACTIC not a failure; NVA probes-then-masses on one axis.

### 3b. Historical enrichment (sourced)
- **One Slow, Four Quick** — slow plan (months of prep), quick advance, quick attack (surprise + "three strongs" at the weak point), quick clearance (recover weapons/casualties), quick withdrawal (pre-arranged rally points). The fight is planned BACKWARDS from the withdrawal.
- **Ambush organization** — 5 elements (lead-block, main-assault, rear-block, OPs, CP); L/V kill zones ringed with mines/boobytraps on the escape terrain; the "Maneuver" ambush re-ambushes relief forces.
- **Hugging the belt** (Gen. Nguyen Chi Thanh, post-Ia Drang 1965) — fight so close US artillery/air must check fire; move WITH the Americans when they pull back to open a fire-support gap.
- **Break-contact discipline** — every op has a pre-planned concealed withdrawal; fragment into small groups; rearguard delay elements that can pivot into counter-ambush; withdrawal timed for nightfall. Main Force fought ~1 day in 30, but tenaciously when cornered.
- **US find-fix-finish** — base of fire on contact, reserve around a flank, artillery/mortars immediately; infantry FINDS, firepower FINISHES; standard drill was pull back and let fire work — exactly what hugging countered.

### 3c. Mapping onto RECONgame (the deltas)
1. **goal_bias doctrine multipliers [S]** — one `@export Dictionary` on EnemyData, applied as a final per-goal multiplier in `_evaluate_goals` (enemy_base.gd ~879); ~10 engine lines, rest is .tres tuning. VC: ENGAGE 0.75, SEEK_COVER 1.25, RETREAT 1.4, ADVANCE 0.7, FLANK 0.8 + preferred_range down, alert_range up. NVA: ENGAGE 1.1, RETREAT 0.6, FLANK 1.25, SUPPRESS 1.15. Sapper: ADVANCE 1.4, RETREAT 0.5. Doctrine biases the ARCHETYPE; personality still biases the MAN (existing two-layer design preserved).
2. **Squad break-contact ledger + re-ambush chain [M]** — the genuinely new piece. EnemySquad tracks casualties-since-contact; at `break_contact_ratio` (VC ~0.33, NVA ~0.6, sapper 1.0=never) OR ~60–90s contact budget, ORDERED withdrawal (all members RETREAT with committed goal_timer lock, weapons kept, toward withdrawal edge/tunnel prop; one man anchors 4–6s as rearguard). Distinct from the existing morale rout (enemy_base.gd:1860-1883) — rout stays as FAILURE, this is DOCTRINE. **Re-ambush:** if an ambush-rated site (D10 geometry tags) lies on the withdrawal path and ≥2 survive, squad re-sets there hold-fire — the survivors ARE ambush v2's "knowledge of player heading" precondition, so break-contact becomes the natural feeder of enemy-initiated ambushes. Cornered check (no path or player <8 m): ledger disabled, fight in place.
3. **Hug-the-belt [S]** — per-archetype flag: threat high AND dist <10–12 m AND ≥2 squadmates alive → bias ADVANCE up instead of RETREAT. Mechanically REAL for free: full-realism FF + muzzle discipline + danger-close grenade broker mean a VC inside the squad's lanes genuinely strips the player's fire superiority. No fakery.
4. **US ally doctrine [S]** — ~90% already decreed (cover-is-a-phase, ADVANCE gated on covering fire, presence rally). Ratify one line: *"US allies fight the find-fix half; the player is the finish"* (Pillar 4: the player IS the maneuver element). Fold ally fix-on-contact bias into the same goal_bias field on AllyData.

### 3d. Composition ledger
**Composes with existing decrees:** ambush v1/D2 (L-shape = historically exact), ambush v2/D10 (setup ≥60–90s = "one slow"; break-contact feeds it), boobytrap grammar/D3 (enrichment: traps concentrate on terrain the ambush denies, not just trails — one grammar rule), patrols-with-errands/D8 (quick-clearance flavor: patrols recover weapons from dead, feeding scavenge economy), witness escalation/R2 + radio caps (disengaging survivors ARE witnesses — sneakiness has teeth both ways), squad probe/D4, morale ladder untouched (canon "Local Force breaks, NVA doesn't" stays as the failure branch beside doctrine).
**Tradeoff to name:** deliberate VC disengagement means some fights end unresolved with zero player agency in the ending — that IS the design (the quiet + the dread of the re-ambush), but it must be legible via barks and movement ("Rut lui!") or players will report "enemies despawned." Land goal_bias WITH or after the bark system.

**Split:** All Claude engine/data work. Caleb: nothing gating; optional-later spider-hole/tunnel-entrance/cache props as withdrawal destinations (v1 works with map edges; zero new anim clips needed).
**Effort:** ~3–5 sessions total; ~2 sessions (goal_bias + hug + ally fix-bias) are independent of the D10 epic and can land right after the G0 gates.
**Sequencing:** Behind G0 (witness bug o18o + perf day) per CoD2000 §2.0; goal_bias ideally after barks (Block B). Re-ambush chain rides the D10 epic.
**Sources:** RTS files above; en.wikipedia.org/wiki/NLF_and_PAVN_battle_tactics; historynet.com/vietnam-hugging-tactics; 5rar.asn.au/vc-nva-tactics; smallwarsjournal grab-their-belts; armyhistory.org find-fix-finish; armyupress US-tactics PDF; Cu Chi tunnels refs.

---

## 4. New animations needed (ANIM_WISHLIST additions)

Aggregated from all lanes. Law of the treadmill holds: v1 of EVERY system below ships with ZERO new clips — the 91-clip library (sitting, cockpit_idle/cockpit_dead/cockpit_controls, pilot_flips_switches, laying_breathless) covers all v1s. These are v2 elevations, in priority order:

| # | Clip | Unlocks | Notes |
|---|------|---------|-------|
| A4 (raise priority) | `wounded_crawl` loop | Downed-enemy micro-movement + crawl-away; VC crippled-crawler return | Already on wishlist; this research raises it |
| A3 | `surrender_idle` (hands-up) | Downed Option B (wake-into-surrender); richer surrender reads | Hard-required by Option B |
| NEW | `heli_board` (~1.5–2s: hand on floor, step on skid, turn, drop to seated — MUST end in exact `sitting` pose) | Huey boarding v2 | Author LEFT side only; right side free via `derive_actions.py mirror()` |
| NEW | `heli_exit` (~1s hop-out) | Huey dismount v2 | Same mirror trick |
| NEW | `wounded_writhe` (on-back, subtle) | Downed-enemy aliveness signal | v1 uses procedural chest-rise SkeletonModifier instead — this clip is optional polish |
| NEW (after C3) | `medic_kneel_aid` loop | Option C: VC medics dragging/reviving their wounded | Blocked on C3 (medic rig exports MixamoRig not PSXRig) |

Rejected: per-seat unique climb anims (content treadmill, zero read at PSX fidelity); skeletal vegetation sway (see §2).
Voice, not anim: withdrawal barks ("Rut lui!"), downed-man groan/whimper VO via voice_studio.py (v1 reuses existing pain grunts).

---

## 5. Hitbox visualization/tuning tool

**Verdict: YES — cheap (~1.5–2 days, zero Blender). Key finding: the tool must NOT tune the hand-placed capsule constants — those are the bug bead 90gj kills. The bench and the 90gj fix are the SAME lane.**

**Current reality (3 tiers):** (1) `hitzone.gd` — Area3D, HEAD fatal / TORSO 2.0× / GUT 1.75×+bleed / LIMB 0.75×. (2) Hand-placed T-pose band constants: `enemy_base.gd:399` (7 zones), `ally_base.gd:293` (6 — allies have no GUT zone, note for rollout). Static zones sit where the T-pose WAS while the body moves = 90gj's "no lethality" bug. (3) **The end-state already exists:** `gore_dummy.gd:118` MEASURES zones from actual bone spans (skull from Head→HeadTop_End, torso from shoulder width, limb capsules joint-to-joint) and bone-syncs per physics tick (line 203–214).

**Prerequisite refactor (IS the 90gj work):** extract gore_dummy's `_build_hitzones` + tick-sync into shared `scripts/combat/hitzone_builder.gd`, consumed by EnemyBase, AllyBase, GoreDummy, and the bench. Static bands remain as no-rig fallback.

**Rendering:** skip "Visible Collision Shapes" for tuning (one global color, draws every collider, unreliable mid-run toggle — fine only for a 10-second sanity check). Use `Shape3D.get_debug_mesh()` wireframes (line-ArrayMesh exactly matching dimensions, parented UNDER each Hitzone so it rides bone-sync for free) + semi-transparent CapsuleMesh/SphereMesh ghosts (alpha ~0.3; Godot 4 CapsuleShape3D.height and CapsuleMesh.height are both total-height, direct copy). Unshaded, `no_depth_test` x-ray (recipe proven in `gore_lab.gd:318-327`). Colors: HEAD red, TORSO yellow, GUT orange, LIMB blue, selected pulses white.

**The bench** (`scenes/tools/hitzone_bench.tscn` + root `hitzone_bench.bat`, cloning the proven viewmodel_editor pattern): auto-discover the 13 character GLBs, instantiate via `ModelActor.setup()`, play/scrub/frame-step any of the 91 clips (scrub to the worst frame of `run_forward` — that's where tuning happens), Tab/1–7 select zone, WASD/QE nudge bone-space offset, [ ] radius multiplier, - = length multiplier, R revert from snapshot, Ctrl+S save, optional click-to-test-shot raycast. **Persistence:** new `HitzoneProfile` Resource → `data/hitzones/<unit_id>.tres` — per-zone {bone, shape, radius_k, height_k, offset} as MULTIPLIERS over the rig-measured baseline (re-export never invalidates). The .tres is OPTIONAL — no file = pure measured defaults (gore lab proved they're good), so 13 units need zero files until one needs a tweak (vc6_heavy bulk, conical-hat heads). `HitzoneBuilder.build(model, profile_or_null)` = single entry point for game and bench.

**In-lab H-key overlay (ships WITH the bench):** ~40 lines in gore_lab.gd — walks group "hitzone", attaches the same HitzoneOverlay helper, read-only. Validates what the bench can't: ragdoll onset, rout sprints, dismember stumps, think-LOD under real fire — the conditions where 90gj was FELT. Doubles as 90gj's acceptance test (press H, watch red skulls ride crouching enemies). Also covers allies free.

**Explicitly recommend AGAINST** authoring hitboxes in Blender (exported empties) — bloats the mesh-only contract, duplicates what rig measurement gives free.

**Split:** Claude: everything (extraction ~half day, overlay helper ~1–2 h, bench ~1 day, lab toggle ~1 h). Caleb: double-click the bat, eyeball 13 units on the nastiest clips, nudge, Ctrl+S. If a zone can never fit, that's an export-proportions finding, not a tool fix.
**Effort:** ~1.5–2 days total including the 90gj extraction.
**Sequencing:** No gates. This UNBLOCKS the gore rollout (90gj), exploding heads (§8), and downed enemies (§9) — highest-leverage first move.
**Sources:** hitzone.gd, enemy_base.gd:399-434, ally_base.gd:293-328, gore_dummy.gd:118-214, gore_lab.gd:293-379, viewmodel_editor.gd/.tscn/.bat, `bd show RECONgame-90gj`; Godot 4 docs (Shape3D.get_debug_mesh, debug_collisions_hint semantics).

---

## 6. Scripted events (EventPrefabs)

**Verdict: YES — doctrine already ratified in-house (MISSION_DESIGN_RESEARCH.md); missing pieces are two small runtime bits (MissionTrigger, ScriptedSequence runner) + an EventPrefab wrapper that respects the finite-ledger law.**

**Research:** RTCW/MoHAA/CoD all ran the same architecture — resumable script threads, name-addressed actors, PRE-PLACED DORMANT populations woken by triggers (RTCW deliberately removed spawn-from-thin-air — a shipped-game verdict). GDScript `await` gives the coroutine layer free. STALKER's model is the right open-world hybrid: space restrictors + smart-terrain "gulags" CAPTURE passing simulated agents into scripted jobs while inside the zone, release after — events borrow actors from the sim rather than owning them. Far Cry 2's lesson (Hocking's "fault tolerance"): systemic tools must let a broken script degrade into improvisation; its infinite respawn checkpoints are the named anti-pattern our canon already rejects.

**Exists today:** MissionDirector (ledger, witness-gated escalation, toasts, fire support), LazyGroup (dormant proximity wake — THE wake primitive), spider-hole ambusher (R64), exfil wave-off/shoot-down ladder + insertion AA events (already scripted-event-shaped, hardcoded), generator complications (R79), objective sensors. **Missing:** generic MissionTrigger (spec'd in research §4: Area3D, once/count, cooldown, delay, armed/activate, activator mask) and the ScriptedSequence await-runner (§2.3) — both spec'd, neither built; no contact deck yet.

**Proposed v1 — EventPrefabs** (authored grammar, generator placement, honest triggers). An EventPrefab =
1. placement requirements against generator-tagged geometry (trail chokepoint, village edge, riverbank, LZ ring — the tagging pass D2/D7 already requires);
2. a MissionTrigger (proximity/noise/objective-state/time-window; diegetic only);
3. a cast **RESERVED FROM THE AO'S FINITE LEDGER** at generation — events never conjure men; killing the cast early is manpower the AO spent (STALKER borrow-model fused with decree R1);
4. a short await-based beat script from existing primitives (play clip, bark, move-to, wake, emit_noise).

**Pillar-3 laws for every event:** skippable (no forced path), interruptible (shooting early collapses the script; actors fall back to systemic AI — RTCW's interrupt contract), honest triggers (never camera-look or invisible advance lines), runs whether watched or not (best consumed through binos — recon IS the spectacle).

**V1 catalogue** (all from existing systems + shelf clips): L-ambush prefab (D2), trail boobytrap with tell (D3), enemy-camp ambient-life vignette, supply column on a trail (D8 seed), **crashed-bird site with cockpit_dead pilots** (ties the Huey and gore lanes together — the crash path already produces wrecks), village tell states (D11 lite), war-at-a-distance audio schedule (C4, audio-only).

**Split:** Claude: MissionTrigger + runner + framework + tagging pass + first 2–3 prefabs + tests. Caleb: nothing gating (civilians = CALEB_TODO 1 unlock village events later).
**Effort:** MissionTrigger + ScriptedSequence runner: M (2 sessions, pure infra, **safe to build pre-gate**). EventPrefab framework + first prefabs: M–L (3–5 sessions, lands post-Block-B per decree). C4 audio schedule: M (already a decree item).
**Sequencing (binding):** G0 first; presentation (Block B: barks/tracers) before punctuation (Block D events). Infra anytime; prefabs after Block B.
**Sources:** MISSION_DESIGN_RESEARCH.md §1/2.3/4/8, synthesis_cod2000_living_fight.md, mission_director.gd, lazy_group.gd, sdk.stalker-game.com (smart terrains, logic/restrictors), moddb Lost Alpha smart-terrain tutorial.

---

## 7. Helicopter seating + boarding (10-seat Huey)

**Verdict: YES — ~40% exists; the seat-socket name contract was designed in from the start and waits on Caleb's Blender side. History supports the ask.**

**Exists:** kinematic flight/crash state machine (`helicopter.gd`: IDLE→FLYING→LANDING→LANDED→TAKING_OFF→CRASHING→DESTROYED, terrain-following, shoot_down()); `insertion_ride.gd` looks up sockets BY NAME (SeatPilot/SeatCopilot/SeatDoorLeft/SeatDoorRight/DoorGunMount) with hardcoded Marker3D fallbacks; player glue-seating (enter_seat copies marker per physics frame, collision off, head-look kept; exit teleports 2.5 m / 8 m post-crash); crew are green CAPSULES; allies do NOT ride (hidden + teleported on dismount); full exfil wave-off/shoot-down/fallback-LZ ladder; green tests (test_huey_sim, test_huey_ride). Shelf clips: sitting, cockpit_idle, cockpit_dead, cockpit_controls, pilot_flips_switches. Pilot .blends ALREADY EXIST (`art_source/characters/us units/unit_us_huey_pilot_white/_black.blend`). **Gap:** no interior/sockets in the GLB (CALEB_TODO §2 unchecked); no AI seating; no rigged crew; no squad choreography; exfil improvises a lone marker.

**History (b):** UH-1D/H was stretched 41 in specifically to carry crew of 4 + a squad. Standard Vietnam crew = FOUR: Aircraft Commander + Peter Pilot, crew chief on left door M60, door gunner right. Nominal 11–13 troops was paper; practical Vietnam combat load = 6–8 US infantry (10–12 lighter ARVN). Troops sat on the floor, feet on skids. **Recommended 10-socket map:** SeatPilot + SeatCopilot (cockpit clips), DoorGunLeft + DoorGunRight (M60 pintles; DoorGunMount already a looked-up name), SeatPax1–6 (2 per side facing out on transmission benches + 2 rear, or door-edge floor sitters for the PSX-Vietnam look). Seats the 5-man squad + a rescued POW (RESCUE objective already produces one).

**Seat system spec (c):** new `scripts/vehicles/seat_system.gd` — scan GLB for Marker3D sockets by the 10-name contract (fallbacks kept so nothing breaks pre-export). Player keeps shipped glue approach (never reparent a physics body). AI occupants: physics off, collision off, out of perception targeting, glued to socket (RemoteTransform3D or per-frame), `ModelActor.play('sitting')` — add 'sitting' to `_LOOP_NAMES` for idle sway (currently holds last frame). Crew: two pilot ModelActors playing cockpit_idle, **cockpit_dead on shoot-down** (dead pilots in the wreck = free atmosphere), door gunners at the M60 mounts. Replace capsules in insertion_ride; give exfil_zone the same system.

**Boarding v1 (recommended, ship it):** walk to door → E → 0.2–0.3 s fade → seated. This is the industry-accepted fake: BF4 shipped exactly this after DICE built full enter anims and SCRAPPED them; Squad and Hell Let Loose still instant-seat today; first-person hides your own body. Allies file to the door and board on a 0.4 s stagger — the queue sells it. **V2 (Caleb, later):** TWO shared clips (`heli_board`, `heli_exit` — see §4), left side only, right side free via `derive_actions.py mirror()`; play glued at a DoorEntry marker, hard-cut to seat socket on the final frame (pose match hides the cut). Per-seat unique climbs: rejected. Pilots never need board anims.

**Caleb's GLB deliverable:** walkable cabin floor + door frames + bench seats + 10 sockets named exactly as above + M60 mount meshes at the door-gun sockets.

**Split:** Claude: SeatSystem, ally/crew seating, loop fix, exfil parity, stagger, fade, tests (extend test_huey_ride to assert 10 occupants + crew clips). Caleb: interior + 10 sockets (1 Blender session, already on TODO); finish the two pilot units; v2 clips (1 anim session).
**Effort:** Engine v1: M (2–3 sessions). Caleb sockets/interior: 1 session. V2 clips + wiring: +1 Caleb session, +S engine. Ship v1 before authoring any clip.
**Sequencing:** SeatSystem can be built NOW against fallback markers; full payoff lands when Caleb's socket export arrives. No decree gates.
**Sources:** huey.tscn, helicopter.gd, insertion_ride.gd, exfil_zone.gd, player.gd:469-491, CALEB_TODO.md §2, derive_actions.py, model_actor.gd, WAVE3_REPORT.md; Bell UH-1 variants (Wikipedia), vietnamhelicopters.org, warbirdsresourcegroup, warhistoryonline; n4g BF4 scrapped-anims; Arma 3 animation states (the expensive alternative).

---

## 8. Exploding-head gib variant

**Verdict: YES — cleanly. Pure extension of the existing hidden-donor contract (grunt_*/cap_*). No runtime mesh cutting, no new pipeline.**

**Blender (Caleb, per character .blend — us_grunt_v2 + vc_guerilla):**
1. Duplicate grunt_head, apply armature at REST pose — the spawner places rest-space geometry via pose_delta (gib_system.gd:88), so fragments MUST be authored at the head's rest location, assembled in place (NOT parked aside like splay_*).
2. Cell Fracture: Source Limit 8 (6–12 for PSX; 50 reads as gravel), Noise 0.4–0.6, Margin ~0.0005. **Blender 5.0 caveat:** Cell Fracture is no longer bundled — limited-support community extension on extensions.blender.org; fallback = 3 manual bisect-plane cuts (8 chunks, ~20 min), arguably MORE PSX-authentic.
3. Exterior faces keep original UVs/gore_tex automatically; set the fracture Material index to a second slot pointing at the wound-red region of the existing `*_gore_tex.png` so interiors read as meat.
4. Name `head_frag_01..08` (zero-padded; engine matches prefix so 6–12 fine), remove armature parenting, decimate each frag to ~20–60 tris.

**Exporter:** do NOT add head_frag_* to EXCLUDE; exporter already un-hides everything pre-export — hiding happens engine-side. Optionally extend the C4 post-export assert.

**Engine (Claude):** extend `REGIONS['HEAD']` with `'frags': 'head_frag_'`; ModelActor hides any head_frag_* MeshInstance3D on visual load (~5 lines — these are the project's first hidden-on-load donors); new `GibSystem.dismember_head_burst(model, hit_dir, gib_parent)` reusing dismember()'s bone-collapse (cap_neck stump free) + blood steps, but replacing the single head gib with N RigidBodies: radial impulse dir = (frag center − head center).normalized()*0.7 + hit_dir*0.5, force 4–7, angular ×12–16; helmet still flies as today. **Trigger (caller-owned per gib_system.gd:11):** fatal HEAD hit with amount ≥ 60 → randf() < 0.25 → burst, else existing pop; gated behind gore_level == FULL. Live game currently only fires dismember() from the gore lab — real rollout rides the same integration point as bead 90gj (§5).

**Perf:** give frags their OWN FIFO — MAX_LIVE_FRAGS=16 (two simultaneous bursts), lifetime 4–6 s, SphereShape3D (cheaper, tumbles better), mass ~0.3, layer 0/mask 1 world-only (never touch each other or actors). One burst = 9 bodies; the existing 8-ragdoll budget (~80 PhysicalBones) dwarfs this. Without its own FIFO a burst would evict the entire 12-gib limb FIFO.

**Split:** Caleb: fracture + tune + name + interior material, ~30–60 min per head (taste task — headless scripting possible but pointless, the look needs his eye). Claude: exporter check, headless re-export, dismember_head_burst + FIFO + hide-on-load, probability gate at the 90gj point, gore-lab bench key so Caleb verifies each rig with one keypress.
**Effort:** Blender 1–2 h total both blends; engine ~half a session + trigger wire-up shared with 90gj. One working day end-to-end; halves fully parallel.
**Sequencing:** after/with §5 (HitzoneBuilder + 90gj rollout) for the live-game trigger; gore-lab version can land anytime.
**Sources:** extensions.blender.org cell-fracture, blenderartists UV-preservation thread, gib_system.gd, export_us_grunt_v2.py, GORE_WORKFLOW.md, gore_dummy.gd, model_actor.gd.

---

## 9. Enemy down-not-dead (unconscious / bleed-out / secure)

**Verdict: YES for v1 with ZERO new art. One premise correction: allies have NO downed state today (ally_base.gd `_die()` kills outright) — the downed/medic/drag stack belongs to the PLAYER. So this extends the player's downed concept to enemies; ally symmetry is a later lane.**

**Trigger (take_damage, enemy_base.gd:1855, before _credit_killer/_die):** eligibility = zone != HEAD (headshots absolute — anti-sponge decree), not explosive, no gib, not surrendered (executing a surrendered man stays a real death — moral weight matters), NEVER in a wave_* group (copy try_surrender's guard, enemy_base.gd:1984, so objective counters can't soft-lock). Probability weighted by overkill: `p = clampf(0.35 - overkill/45.0*0.30, 0.0, 0.35)`, zone-scaled (LIMB ×1.3 — died-of-wounds, most plausible survivor; TORSO ×1.0; GUT ×0.5 — the bleed system owns that fate). Net: a barely-dead rifle round rolls unconscious ~25–35%; an M60 burst almost never.

**State:** `is_downed` + `laying_breathless` one-shot latch (deliberately non-looping in model_actor.gd:159); hitzones/collision stay LIVE so a finishing shot resolves zones (composes with 90gj); physics off except a light tick: bleed clock 40–90 s scaled by remaining margin, GunFX.blood_pool that re-widens on a timer (the visual clock), groan VO every 6–10 s via VOManager + NoiseBus VOICE (his moaning is a REAL sound event — enemies and allies react). `died.emit` only on true death; register in a new `downed_enemies` group, not lootable_corpses, until resolved.

**Readability (the make-or-break "I killed him, why is he up" problem):** research consensus — (1) continuous unmistakable AUDIO is the aliveness signal; a silent laying_breathless body reads as a corpse (even ACE3's own AI famously can't tell unconscious from dead and keeps shooting downed men); (2) visible micro-movement — until wounded_crawl (A4) exists, a tiny procedural chest-rise/arm-twitch SkeletonModifier; (3) an interact prompt within ~2 m; (4) the iron law from every game that gets this right: **a downed man NEVER snaps back to full combat** (Insurgency/HLL never allow it — reads as a bug, betrays the hardcore-gunplay contract).

**Design fork, tradeoffs named:**
- **OPTION A (recommended v1)** — Arma-style bleed-out only: groans, bleeds, maybe crawls once A4 lands. Player verbs: FINISH (confirmed kill), SECURE (capture — feeds the CHIEU HOI/intel economy exactly like surrender; fail-forward: even a botched loud assault yields prisoners and intel from the wounded), IGNORE (dies on the timer). Sacrifice: no dynamic comebacks — but maximal readability, zero fairness violations.
- **OPTION B** — MGS-style wake-up: after N s roll courage; wake ONLY into surrender-in-place or crawl-away, never the fight. Sacrifice: possum-ambiguity risk; hard-requires A3. Defer.
- **OPTION C** — VC medic revive (Far Cry 2 buddy-drag precedent — one of that game's most-praised beats, atmosphere-pillar gold): a squadmate channels beside the downed man; he returns ONLY as crippled crawler or surrender. Creates the authentic wounded-man-as-bait dynamic real ambush doctrine exploits; composes with the living-fight decree. Sacrifice: new squad-AI + kneeling-aid loop; medic rig blocked on C3 (exports MixamoRig not PSXRig). Slot as v2.

**Composition:** a squadmate downed-and-screaming should hit morale/pressure HARDER than a death (wounds-over-kills — feed threat_level at enemy_base.gd:1867); drag a downed enemy to concealment for a silent capture via existing ragdoll_bone grab infra; SECURE shares one economy with surrendered captures.

**Split:** Claude (all of v1): take_damage branch + probability table, downed tick, FINISH/SECURE verbs reusing the surrender-capture path, wave_* guard, bookkeeping/save, morale hook, combat-lab bench. Caleb (optional, elevating): A4 crawl, A3 surrender idle, groan VO lines (v1 reuses pain grunts), later medic loop. Nothing in v1 blocks on him.
**Effort:** v1 (Option A complete): 1–2 engine sessions, zero Blender. Readability polish: half a session. Option C: 1–2 sessions + C3 fix + one Caleb anim session — defer until v1 proves the read in playtests.
**Sequencing:** land WITH the 90gj rollout so hitzones-on-downed-bodies arrive together.
**Sources:** ACE3 medical docs + issues #8041/#7299, Far Cry 2 buddies + Blendo on FC2, Six Days forum, enemy_base.gd, health_system.gd, squad_system.gd, ally_base.gd, ANIM_WISHLIST.md.

---

## RECOMMENDED BATTLE ORDER

Ordering logic: (1) unblock the most other work first, (2) respect the CoD2000 gates (G0 = witness bug o18o + perf day; barks before events), (3) run Caleb's Blender sessions PARALLEL to engine work, never serial.

**1. HitzoneBuilder extraction + Hitzone Bench + lab overlay (§5) — GREEN-LIGHT FIRST.**
No gates, ~2 days, zero Blender, and it IS the 90gj bug fix (the "no lethality" bug). Unblocks the live gore rollout, the exploding head, and downed enemies — three lanes queue behind this one refactor. The lab H-key is 90gj's acceptance test.

**2. Jungle vegetation batch + sway shader (§1+§2) — parallel track, start immediately.**
Fully independent of every gate and every other lane. ~3 sessions, biggest atmosphere-pillar payoff per session in this document. Caleb's only cost is a sign-off look at the canonical palm. Proves the headless generation pipeline for all future batches.

**3. Exploding head (§8) + Enemy down-not-dead v1 (§9) — ride the 90gj rollout.**
Both integrate at the same point the hitzone rollout touches (take_damage / dismember triggers). Head burst: Caleb's 1–2 h fracture session can happen ANY time in parallel; engine is half a session. Downed v1 (Option A): 1–2 sessions, zero Blender. Ship both behind gore_level/rollout flags together — one combat-feel drop.

**4. Huey SeatSystem v1 (§7) — engine now, payoff when Caleb exports.**
Build SeatSystem + crew actors + fade-boarding against the existing fallback markers (2–3 sessions, no gates). The moment Caleb does his interior+sockets Blender session (already CALEB_TODO §2 — schedule it whenever he's next in Blender), the full 10-seat squad ride lights up with no additional engine work. Dead pilots in crash wrecks come free and feed the crashed-bird event prefab later.

**5. G0 gates (witness bug o18o + perf day), then VC/US goal_bias retunes (§3 item 1+3+4).**
The gates are standing decree law — clear them before any AI behavior work. goal_bias + hug-the-belt + ally fix-on-contact are ~2 sessions of data-heavy work, independent of the D10 epic. Land WITH or after barks (Block B) so VC withdrawals read as doctrine, not despawn bugs.

**6. MissionTrigger + ScriptedSequence infra (§6) — safe filler anytime; prefabs after Block B.**
The two runtime primitives are pure infra (2 sessions, buildable pre-gate whenever there's slack). The EventPrefab catalogue (L-ambush, boobytrap tell, crashed-bird site) and the break-contact→re-ambush chain (§3 item 2) land after Block B / with the D10 epic, per the decree's presentation-before-punctuation rule.

**Caleb's Blender queue (all parallel, none blocking a v1):** ① head fracture session (1–2 h, unlocks §8 fully), ② Huey interior + 10 sockets (1 session, unlocks §7 fully), ③ eyeball palm/sway sign-offs (minutes), ④ later: heli_board/heli_exit left-side clips, A4 wounded_crawl, A3 surrender idle (§4 table).

**Explicitly deferred:** Option B/C downed variants (need A3/C3), per-seat climb anims (rejected), skeletal foliage (rejected), second palm species (textures on shelf when wanted).
