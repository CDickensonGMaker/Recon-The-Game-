# Devil's Advocate — P1 (viewmodel-FOV shader) / P2 (marker-derived poses)
**Date:** 2026-07-26 · **Target:** `production/research/viewmodel_pipeline_deep_dive_2026-07-26.md` §4, §6
**Method:** code read, not the plan. All pointers verified this session.

## Ground truth verified first

- Scale hack: `scripts/player/weapon_holder.gd:973-978` (`_lens_ratio`, clamp 0.6–2.2), applied at `:919-920`. Bench copy: `scripts/weapons/viewmodel_editor.gd:283`. Pitch hack: `weapon_holder.gd:152-156`, applied `:820-831`.
- ADS zoom: `weapon_holder.gd:248-259` lerps `camera.fov` 75→`ads_fov` (ADR-004). **`_lens_ratio` uses `BASE_FOV`, not the live camera FOV** (`:976`) — this fact drives risk #2 below.
- Live `viewmodel_fov` spread: 55 (m1911) → 66 (m60/rpg2/rpg7); m16a1/m14 carry none → default 60 (`weapon_data.gd:38`). Lens ratios r = tan(37.5°)/tan(vm/2): **1.18 (vm 66) … 1.33 (vm 60) … 1.47 (vm 55)**.
- There is **no PSX vertex-snap/affine shader in the repo** (`Glob *.gdshader`: 7 files, all terrain/water/vegetation). The PSX look is `scaling_3d/mode=5, scale=0.75` + nearest texture filter (`project.godot:304-309`) + low-poly assets. The plan's "shader must compose with the PSX material" caveat is aimed at a material that does not exist — the real material problem is different (risk #4).
- Sun shadow is OFF in ship (`game_world.gd:48`, ADR-026 Amendment A) — the shadow-pass hazard of a projection override is latent, not live.

---

## RISK 1 — BLOCKER: P1 breaks all 15 guns at once, and nobody but Caleb can see it

The plan's cost line — *"every tuned pose must be re-tuned (only M14 is fully tuned, so the sunk cost is one gun)"* — conflates **tuned-to-spec** with **shippable**. Every gun in the armory ships TODAY with hip/ADS poses that render acceptably (they were all dialed under the scale hack; 11 of 15 have real per-gun values, 4 carry stubs per the plan's own RC2). The moment the projection override lands, **every one of those poses renders differently** (see risk 3's math). Master carries a visually broken armory until a full re-pose session happens.

And the re-pose session is Caleb-only: agents cannot run windowed Godot (standing law: no headless tests while coding, no spamming windowed instances; ADR-015 says verification = the Summoner's playtest; PLAYTEST R4 is the session entry gate). A probe can assert the projection matrix and the uniform wiring; **no probe can assert "the M14's front post sits in the rear aperture."** Shipping P1 without a same-arc bench session with Caleb is shipping a regression nobody can measure.

**The feature-flag escape hatch collides with the FOSSIL LAW** (ADR-023: replacement not shipped until predecessor deleted — two live lens systems is exactly the two-ways-to-do-one-thing the law forbids). The honest options are:
1. **One arc:** build P1 on a branch, Caleb does the full 15-gun re-pose at the bench in the same sitting, delete `_lens_ratio` + `PITCH_OFFSET_*` in the same change, merge. (Fossil-law clean; requires scheduling his hours.)
2. **Decree-sanctioned temporary flag** with a dated kill entry (the ADR-026 clause shows the council CAN authorize a transition when it names the corpse and the burial date).

**Clearing condition:** the decree must pick one of these explicitly and budget Caleb's bench hours as the critical path. "Sunk cost is one gun" must be corrected in the decree — it is ~15 guns × 2 poses + bore re-cals, plus grenade/medkit/binocular hands (they load through the same `_load_weapon_model` path and `m26_grenade.tres` carries `viewmodel_fov = 60`).

## RISK 2 — HIGH: the double-FOV interaction is real, and the plan never mentions the coupling that fixes it

Today, during ADS, the gun **magnifies with the world**: the scaled mesh is rendered through the zooming camera (`camera.fov` 75→`ads_fov`), and `_lens_ratio` stays constant because it reads `BASE_FOV` (`:976`). Mosin `ads_fov` 40 → the whole sight picture (world AND gun) magnifies ~2.1×; that is the picture the ADR-004 iron-sight pass tuned.

With a **fixed** viewmodel-FOV uniform, the world zooms and the gun does not. Every ADS sight picture shrinks relative to today — worst on the tight guns (Mosin 40, M70 ~scoped values): the front post reads roughly **half** its current apparent size against a 2× world. Sight *alignment* survives (the camera axis maps to screen center under any FOV — points on the axis stay centered), so "alignment impossible" is FALSE; but the aperture/post size relationship, eye-relief feel, and how much target the irons occlude all change, per gun, and those were what the 2spa pass hand-tuned.

To preserve today's pictures the shader FOV cannot be a per-gun constant — it must be driven **per frame** as ≈ `2·atan(tan(camera.fov/2)/r)`, i.e. a live `weapon_holder` → uniform coupling lerped with `ads_transition`. The plan sells P1 as "the bench sheds the copied hack — WYSIWYG becomes structural." Not so: the bench's WeaponHolder is a **plain Node3D** (`viewmodel_editor.gd:17` — no script), so someone must set that same uniform in the bench, mirroring the game's ADS lerp exactly (`viewmodel_editor.gd:683-689` mirrors it today). **The copied scale-multiply is replaced by a copied uniform-driver.** It is a better hack (one float, one place per rig, and it can carry a probe) — but it is not the structural absolution the plan claims, and the decree should say so.

## RISK 3 — HIGH: world-space FX detach from the drawn gun (flash, tracers), and depth squash occludes the flash

- Muzzle flash spawns as two depth-tested additive billboards **in the world scene at the world-space muzzle position** (`gun_fx.gd:253-276`; `weapon_holder.gd:473`). Hip tracers ARE the round and spawn from the same `muzzle_pos` (`bullet_system.gd:15-16`, `weapon_holder.gd:518`).
- Today these coincide with the drawn barrel because the scaled mesh **really occupies** that world position. Under a projection override, the drawn gun is displaced radially from its world-space projection by the FOV mismatch — up to ~47% of screen-radius at r=1.47 (m1911), ~33% for the vm-60 rifles. Flash and the first meters of every hip tracer visibly float off the barrel.
- Worse: depth squash writes the gun at near-plane-ish depth. The flash quads depth-test (`TRANSPARENCY_ALPHA` + `BLEND_MODE_ADD`, `gun_fx.gd:238-239`, no `no_depth_test`), so wherever the flash overlaps the gun on screen, **the gun now occludes its own muzzle flash.**
- Fix surface: parent the flash to the viewmodel and give the flash/particle materials their own projection-override variants, or compute the *drawn* muzzle position on CPU (inverting the shader math) for flash/tracer spawn while keeping the world-space one for `NoiseBus`/suppression/ballistics (`weapon_holder.gd:471-483` must keep TRUE world pos — two muzzle positions now exist, a fresh divergence hazard the plan doesn't name).
- The plan even flags this displacement for the SubViewport route (§3c option 2) and then claims the shader route avoids it. **It does not** — the displacement is a property of rendering the gun through a different projection, whichever mechanism does it.

## RISK 4 — MED-HIGH: the per-material blast radius, and the warhead ART CONTRACT

A projection override is per-material. The viewmodels import from GLB as one `StandardMaterial3D` per surface — arms, gun body, mag, bolt, warhead, across ~12 GLB guns plus grenade/medkit hands. Every surface needs conversion to a ShaderMaterial (import post-script), hand-porting whatever StandardMaterial features each uses. Specific tripwires:

- **Warhead contract** (`weapon_holder.gd:275-310`): launcher warheads are hidden by matching surfaces whose **material `resource_name` contains "warhead"**, swapped to an invisible StandardMaterial override. Material conversion/merging that renames or shares materials breaks the match silently (the rocket stops leaving the tube — the file's own comment warns exactly this). The invisible override also bypasses the projection shader; invisible-is-invisible saves us, but only by luck, and restoring `null` must land back on the shader variant.
- **Shadow pass:** an unconditional `PROJECTION_MATRIX` override corrupts any pass that renders these meshes with a different projection. Ship has sun shadow off (`game_world.gd:48`), so it's latent — but it means `cast_shadow = OFF` must be forced on every viewmodel mesh as part of P1 or the first future light that casts will smear garbage. Needs a probe, not discipline.
- PSX-fight worry from the brief: **weak**. No vertex-snap/low-res-target shader exists to fight; `scaling_3d 0.75` nearest applies after projection and is override-agnostic. ADR-026 frame cost: one more shader variant and some early-Z-favorable overdraw — negligible, no budget breach.

## RISK 5 — MED: every feel amplitude is silently retuned by the lens

Sway/punch/sprint/fire-menu-dip are **node-space translations of `weapon_model`** (`weapon_holder.gd:833-859`: sway amp 0.014/0.004, punch 0.05/0.012/3.5°, sprint −0.08, fire-menu dip −0.30 m/−60°). Today the scale hack does NOT magnify these — it scales the model's own basis, while `weapon_model.position` deltas project at world FOV. Under the projection override, ALL model-space translation projects at the viewmodel FOV → **every amplitude reads r× bigger on screen: +18% to +47% depending on the gun.** The brief's suspicion is confirmed, direction: bigger, per-gun non-uniform. Either divide the feel constants by r (coupling them to the lens — ugly) or accept a per-gun feel shift Caleb never approved. Must be named in the decree.

## RISK 6 — MED: P2's "the pose" is not a well-defined frame

The gun rides `hand.R` through authored clips; markers move every frame of `rifle_idle` (the de-robotise work deliberately animates idle). The GLB's default pose is the **bind/rest pose**, and the 7/25 M16 break proved rest ≠ authored idle can be catastrophic (rifle at +3.1X in rest). So:
- Derive **at import** → samples rest pose → garbage for any gun whose idle differs from rest.
- Derive **at load** → races `_play_vm_draw` (`weapon_holder.gd:927` plays `charge_handle` first) and races the idle loop's phase.
- The only defensible definition is "frame 0 of `rifle_idle`, sampled explicitly before use" — and then **every idle re-export silently shifts every derived pose**, invalidating the .tres offsets with no error. That is a purpose-built drift generator (the project's named disease) unless the manifest stores a derived-pose hash and `--strict` fails on mismatch. That probe is absent from the plan; without it P2 is worse than the 3-place sprawl it replaces, because at least today's sprawl doesn't move when Blender sneezes.

Also: P2's "kill the baked .tscn offsets, bake orientation into the GLB" requires re-exporting **all** guns, including the 9 GLBs that predate the pipeline (plan RC4) and the M16 whose working-tree GLB is DO-NOT-COMMIT pending Caleb's blessing. P2's critical path runs through the Blender export queue — it is gated on Caleb twice (blessing + sight-marker pass on guns that lack markers).

## RISK 7 — MED: the bench's numbers stop meaning what Caleb thinks they mean

Mechanically his muscle memory survives P2 — offsets are additive, so WASD/arrow nudges, Shift-fine, Ctrl+S, R-revert all keep behaving identically. What breaks is **semantics**: the pos/rot readout (`viewmodel_editor.gd:640-641`), the C-copy payload (`:702-708`), and the saved .tres values become offsets-from-a-derived-base — a .tres is no longer readable standing alone, and comparing numbers across guns (his current sanity check) becomes meaningless. He is the only artist; a semantics change to his one tool is a decree-level question, not an implementation detail. Cheap mitigation: display BOTH (derived base + offset + effective absolute) in the HUD.

## Smaller findings

- **Pitch-hack retirement is conditional:** depth squash stops the gun clipping INTO world geometry; it does not stop geometric near-plane clipping of vertices behind the camera plane (real-scale stocks — the plan's own §3c admits stocks sit behind the camera). The custom projection needs its own very-small near value; verify before deleting `PITCH_OFFSET_*` or the gun's butt vanishes when looking down instead of the gun teleporting up.
- `viewmodel_scale` (declared `weapon_data.gd:95`, shown `viewmodel_editor.gd:638`, never applied; still carried by 6 .tres) — P1/P2 kill it; fine, but its deletion must ride the same change (fossil law) including the `.tres` lines and the HUD row.
- ADR-004 explicitly assumes "positions are tuned at hip FOV 75" and one-writer-per-frame on `camera.fov` — P1 adds a **second projection authority** (the shader) outside that contract. The plan concedes a decree is needed; the decree must AMEND ADR-004, not sit beside it.
- 4 guns have no GLB at all (m79, m72_law, rpg7, shotgun — plan RC4). P2's marker derivation cannot cover them; the .tres-absolute path must survive for them anyway → P2 does not actually collapse to ONE source of truth until P5/P6 complete. Sequencing P2 before P5 ships a hybrid with BOTH pose systems live — fossil-law tension the plan's own ordering creates.

## What is sacrificed (no free lunch)

1. **All current pose tuning** — 15 guns, not 1 — plus Caleb's approved LOOK of the M14: projection gives genuinely different foreshortening than mesh scale (that difference is the feature; his eye is still the gate).
2. **World-space truth of gun FX** — flash/tracer must special-case the viewmodel forever; two muzzle positions (drawn vs. ballistic) exist from P1 onward.
3. **WYSIWYG-by-shared-camera** becomes WYSIWYG-by-shared-uniform — a smaller but still disciplinary coupling, needing its own probe (P3a must grow a uniform-equality assert).
4. **.tres standalone readability** (P2) — pose numbers become derivation-relative.
5. **A chunk of Caleb's bench hours** as the un-parallelizable critical path.

## What CANNOT be tested without Caleb

Sight pictures per gun per ads_fov; flash/tracer registration on the barrel; the new foreshortening look; feel amplitudes; PSX cohesion at 0.75-nearest. Probes CAN cover: uniform wiring game==bench, projection matrix math, material coverage (no StandardMaterial3D left on a viewmodel), cast_shadow off, warhead-name survival, derived-pose hash. Build every one of those probes — and still treat P1 as unverified until his playtest, per ADR-015.

## Verdict on sequencing

P4→P3→P1 is right in spirit, but P1 must be **branch-built and merged only with a same-arc Caleb re-pose session** (or a decree-sanctioned dated flag). P2 should additionally wait for P5's GLB coverage or accept it ships a two-system hybrid. The plan is directionally correct — the scale hack IS the architectural sin — but its cost accounting ("one gun", "bench sheds the hack", "shader route avoids muzzle displacement") is wrong in three load-bearing places, and each wrong claim hides Caleb-gated work.
