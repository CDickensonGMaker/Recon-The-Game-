# GORE WORKFLOW — making dismemberment + real blood a reality (2026-07-09)

The step-by-step to go from "red particle puff" to "a shotgun takes his arm clean off."
Grounded in what exists TODAY: the locational zone system (just shipped — every hit now knows
its zone), `GunFX` blood/decal pipeline (`scripts/combat/gun_fx.gd`), `research/gore_fx.md`
(textures/particles plan), `research/ragdoll.md` (physics plan). Build in this order.

## The design law
Gore is **feedback, not decoration**: it tells you WHERE you hit and HOW HARD. Zone system feeds it:
- LIMB hit + big damage → that limb comes OFF
- HEAD hit + big damage → headshot pop
- Explosions / point-blank shotgun → multi-gib
- Everything gets better blood (spray, decals, pools) even at low damage
Gate it all behind a `gore_level` setting (OFF / REDUCED / FULL) in GameSettings — one check, everywhere.

## PHASE 1 — Blood that reads (no Blender, ~1 session)
The plan is already written in `research/gore_fx.md`. Build order:
1. **Blood surface decals** — extract `_spawn_decal()` from `gun_fx.bullet_hole()` (:211, has the
   orientation math + FIFO cap already); on flesh hits, raycast PAST the body and splat the wall/floor
   behind. Texture: CC0 blood splats (OpenGameArt "blood_splat", Material Maker "unfa Blood Splash"),
   128-256px, nearest-filter, hard alpha (PSX look).
2. **Flipbook spray particles** — YES, 2D sprite sheets (your instinct = the GoldSrc technique):
   a 4-8 frame blood-burst sheet on a `GPUParticles3D` with `particle_flag_align_y` + alpha scissor.
   Replace the untextured red puff in `GunFX.blood()` (:174) — keep the CPU fallback.
3. **Ground pools** — on kill, floor-projected decal that tweens open over ~2s. Own FIFO cap (~16).
4. **Extend `clear_decals()`** (:229) to free the new arrays — gore must not leak across missions
   (MissionScope already calls it).
Deliverable: every firefight leaves painted evidence. Zero Blender.

## PHASE 2 — The shared gib set (ONE Blender session)
The trick that makes dismemberment cheap: **never cut character meshes.** One shared, low-poly,
PSX-budget gib set reused by EVERY enemy:
- `gib_arm.glb`, `gib_leg.glb`, `gib_head.glb`, 2-3 `gib_chunk_*.glb` (meat/bone bits) — ~100-300 tris
  each, one shared gore texture w/ wound-red ends. Model once in Blender, done forever.
- Optional: a `wound_stump` decal texture (dark red ring) to slap on the body at the removal point.
Export to `assets/models/gore/`. That is the ENTIRE Blender requirement for dismemberment.

## PHASE 3 — Limb removal (code, ~1 session)
**No mesh cutting at runtime either.** The 3-step pop:
1. **Hide the limb**: scale the limb's skeleton bone to `Vector3.ZERO`
   (`skeleton.set_bone_pose_scale`) — arm visually vanishes, works on ANY Mixamo-rigged model, and
   on capsule/sprite fallbacks just skip to step 2.
2. **Spawn the gib**: matching piece from the shared set as a `RigidBody3D` at the limb's world
   position, impulse = shot direction + up-kick + spin. 10s despawn, FIFO cap (~12 live gibs).
3. **Blood burst**: Phase-1 flipbook spray + a stump decal + a pool under the landing spot.
Trigger rules (all zone-system driven, in `take_damage`/`_die`):
- LIMB zone + single-hit damage ≥ ~45 (shotgun/M60/explosion) → that limb off (alive = crippled scream)
- HEAD zone kill + damage ≥ ~60 → head pop (helmet flies separately later)
- Kill by explosion ≤ 4m → 2-4 random gibs + torso stays
- `gore_level` gates every branch.

## PHASE 4 — Ragdoll marriage (after the ragdoll bead lands)
`research/ragdoll.md` has the plan (one shared physical-skeleton .tscn). Once corpses ragdoll:
- Dismembered ragdolls: bone already scaled to zero — ragdoll just works, minus a limb.
- PhysicalBone colliders double as **per-bone hitzones** (the ~10-zone DESIGN 4.3 target, free).
- Corpse hits spawn Phase-1 blood (no damage) — shooting bodies stays grim, not silly.

## PHASE 5 — Explosion/heavy-weapon dressing (polish)
- RPG/arty/CBU kills inside the fireball → full gib + the crater the terrain already digs.
- A "gib rain" cap so a CBU run doesn't spawn 200 rigidbodies (reuse the FX cap pattern).
- Flies buzz loop on 60s+ old corpses (one looping 3D sample, atmosphere pillar).

## What needs Blender vs what doesn't
| Piece | Blender? |
|---|---|
| Blood decals / spray / pools | NO — textures (CC0) + code |
| Limb removal (bone scale) | NO — pure code |
| The gib set (arm/leg/head/chunks) | **YES — one session, one shared set** |
| Stump/wound texture | trivial (can even be procedural) |
| Ragdoll physical skeleton | YES-ish — editor setup once, per ragdoll research |
| Per-character mesh cutting | **NEVER — that's the trap this workflow avoids** |

## Effort map
Phase 1 ≈ one evening · Phase 2 ≈ one Blender session · Phase 3 ≈ one evening ·
Phase 4 rides the ragdoll bead · Phase 5 = polish passes. Phases 1-3 alone deliver
"shotgun takes the arm off with a blood burst" — the fantasy, PSX-style, cheap.
