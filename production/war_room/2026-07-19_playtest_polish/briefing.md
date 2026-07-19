# BRIEFING — Playtest Polish Pass (Batches A/B/C)

Session: 2026-07-19. First playtest since the open-sim pivot. Owner's verdict: **the flow is RIGHT**
(leave firebase → sweep mission → village with villagers + VC). Terrain and mission flow work.
What broke immersion is polish and two missing wirings. **DO NOT TOUCH THE FLOW.**

Owner is token-constrained. ONE council for all batches. Research below is GROUNDED — do not re-derive it.

## GROUNDED FACTS (measured this session, do not re-verify)

**Damage architecture**
- Bullet raycast mask is `1 | 32 | 64 = 97`, identical for all three shooters:
  `scripts/player/weapon_holder.gd:478`, `scripts/enemies/enemy_base.gd:2021`, `scripts/allies/ally_base.gd:944`.
  `collide_with_areas = true` (`scripts/combat/bullet_system.gd:80`).
- Hittable layers therefore: 1 world, 32 player/ally hurtbox, 64 enemy hurtbox. Body capsules
  (2, 4) are deliberately excluded.
- Resolution chain `bullet_system.gd:109-152`: `col is Hitzone` → `owner_entity` + zone mult;
  else group `enemies`/`player`/`allies` → BODY ×1.0; then `take_damage(dmg, type, shooter, zone)`.
- **Civilian is on `collision_layer = 2` with NO Area3D hurtbox** (`scripts/world/civilian.gd:100`).
  Layer 2 is not in the bullet mask. `civilian.gd:234 take_damage()` exists and is UNREACHABLE by
  bullets. Villagers are bullet-transparent. Root cause of "couldn't kill civilians".
- `Hitzone._setup_groups()` (`scripts/combat/hitzone.gd:44-55`) only branches on groups
  `player` / `enemies`. Anything else keeps the layer `HitzoneBuilder.build()` was given.
- **PLAYER HAS TWO OVERLAPPING HITZONE SETS** — `scripts/player/player.gd:446` builds 11 static
  bands via `HitzoneBuilder._build_static()`, then `:456 _setup_hitzones()` builds 7 MORE
  hand-placed zones (`player.gd:880-924`), same layer 32, same groups. Whichever the ray hits first
  wins. This is a live fossil-law violation, not a theory.
- `punji_trap.gd` is a plain `Node3D` — **no Area3D, no collision, no health, no take_damage**
  (header line 3 says "layer-free"). Polls at 5Hz within 1.4m. Cannot be shot or cleared.

**Gib**
- `GibSystem` has NO registration call. It is pure by-name node inspection at call time:
  `dismember`, `dismember_head_burst`, `explosion_kill`, `clear_gibs` (`gib_system.gd:103-338`).
- **All 10 civilian GLBs already carry the full donor contract** — `grunt_head`, `grunt_forearm_l/r`,
  `grunt_leg_l/r`, `cap_*`, `head_frag_01..07`, `PSXRig`, and every `mixamorig` bone REGIONS names.
  The `grunt_` prefix is literal and universal across US/VC/civilian exports. Gib on a civilian is
  NOT architecturally blocked — only the hitzone + death wiring is missing.
- Unused-but-shipped donors in every model: `grunt_torso`, `grunt_uparm_l/r` (+caps) — no REGIONS entry.
- `hat_conical_worn` exists in the 8 adult civ GLBs and is in NO gear list → on a head-pop the hat
  stays welded to a headless corpse.

**Animation (definitive — dumped from the engine, 100 clips in `assets/shared/anim_library.glb`)**
- **WORK, COOK, FISH, TALK, REST have NO CLIP. Nothing to map them to.** `sitting` exists.
  `idle_unarmed`, `idle_unarmed_2..5`, `walking_unarmed`, `running_unarmed` exist.
- Authored-but-UNMERGED civilian clips live in a Blender workbench only —
  `tools/make_civilian_anims.py` (`civ_farm_harvest`, `civ_farm_transplant`, `civ_squat_idle`,
  `civ_cower`, `civ_hands_up`, `civ_panic_run`, `civ_carry_pole_walk`). Not in the shipped GLB.
- **THE REAL ROOT CAUSE OF "civilians in crouched AIMING poses":**
  `civilian.gd:187` COWER → `"crouching"` → `:209 play_first(["idle_crouching", ...])` and
  `idle_crouching` is a RIFLEMAN CROUCH pose. And `:217` idle → `play_first(["idle", ...])` picks
  `idle` — the ARMED RIFLE idle — before ever reaching `idle_unarmed_2`.
  Every idle villager is standing in a rifle-holding pose; every cowering one is in a weapon crouch.
  Gunfire within 60m flips the whole village to FLEE/COWER (`civilian.gd:116-121`).
  **This needs ZERO new art to fix.**

**Hat / straps**
- There is NO runtime hat socket. `"HatSocket"` does not exist in the repo. The conical hat is
  BAKED at export by `tools/make_civilians.py:166 HAT_NUDGE` + `:170-174 HAT_DZ`. Caleb's two prior
  fixes are commits `0abdf2fb` and `32ccc84f` — both edited those constants. A third edit regresses
  the same way unless something MEASURES the result.
- Straps = `web_*` meshes, materials `webbing_canvas` / `webbing_steel`, authored only in
  `assets/us/characters/gear_armory.blend`. **No GDScript or .tres reads or writes them.**
  Runtime tint IS possible — `scripts/visuals/grunt_dresser.gd:180-193` already demonstrates the
  duplicate-then-mutate pattern (mutating in place tints every grunt on the map — `:14-16`).
  Caveat: `GruntDresser.dress()` has ZERO game call sites (bead 37mj), so fixing it THERE fixes nothing.

## THE FORKS — rule on each

**F1. How do civilians become shootable?** Options: (a) put civilian hitzones on 64
(enemy_hurtbox) — cheap, zero mask edits, but semantically lies and may drag civilians into
enemy-targeting greps; (b) a new civilian layer (8/128) added to all three shooter masks — honest,
but AI stray rounds then kill villagers, which touches who-gets-shot; (c) layer 32. Rule, and name
the Fairness/Pillar consequence.

**F2. The player's double hitzone set.** Fossil law says delete `_setup_hitzones()`. But this is
live combat geometry. Delete now, or bead it? What could deleting break?

**F3. Batch B1 scope.** The requested schedule→clip mapping is BLOCKED — the clips do not exist.
What ships today from the existing 100 clips to make the village read as a village and not an
ambush? Is per-action differentiation from `idle_unarmed_2..5` + `sitting` honest, or is it a lie
that hides the missing art?

**F4. Hat offset.** Fix requires a Blender re-export (out of engine, needs Caleb's eye). Owner
demands "there must not be a fourth regression". What does a headless probe assert on a BAKED
offset so the regression is caught by the machine and not by a playtest?

**F5. Straps.** Runtime tint at model load vs. .blend re-author. Which, given `dress()` is dead code?

**F6. Batch C (traps).** Trap has no collision body at all — destructibility is not a tweak, it is
new geometry + a health path. Worth it this session, or defer?

## BINDING CONSTRAINTS
- Godot 4.7 ONLY. Headless probes only — never spawn windowed Godot on the owner's desktop.
- Comment discipline (no history narration). Fossil law (delete what you replace).
- ADR-015 verification law: nothing closes without a probe/measurement.
- OWNER LOCKED: civilians killable with **NO consequence system**. Leave a flagged hook for future
  ROE/war-crime scoring. Building the consequence system is OUT OF SCOPE.
- OUT OF SCOPE, do not touch: village completion verb, terrain conform / firebase elevation,
  squad AI + enemy self-preservation (that is the blessed AI wave mwfi→qpfr), CatacombsOfGore cave
  kit, missing building textures.
