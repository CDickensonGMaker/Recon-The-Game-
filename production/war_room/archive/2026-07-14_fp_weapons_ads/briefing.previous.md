# BRIEFING — THE JUNGLE IS NOT PLUGGED IN

**Convened:** 2026-07-13
**Summoner:** *"i made tons of jungle terrain and destructible terrain last night. is that wired into
the game? rice paddies should be inheriting water from the game as well. do a check and tell me what
needs to happen."*

---

## The question

He built the art. **Is it wired?** Three answers, all measured, none guessed.

---

## WHAT THE ARBITER MEASURED BEFORE SUMMONING (verify if you doubt — do not re-derive)

### ✅ THE JUNGLE PATCHES ARE LIVE
`vegetation_manager.use_jungle_patches = true` → `JunglePatchLayer` loads from
`res://assets/world/vegetation/patches/`. The real boot log confirms it:
`[JunglePatch] 23 patches across 6 density classes`. **This half works.**

### ❌ BREAK 1 — THE PADDY WATER FORMAT. The bead PREDICTED this and nobody listened.
Bead `en75`'s shipped contract says, verbatim:
> *"water[] is an **ARRAY** now, was a Dictionary. half is [hx,hy] RECTANGULAR. patch_paddy_quad has
> FOUR pans. **Old parse code WILL break.**"*

**The art shipped the new contract. The parse code was never updated.**

| | |
|---|---|
| **patches.json (his art, correct)** | `"water": [ {level, half:[5.8,5.8], at}, … ]` — a **LIST**. `patch_paddy_quad` carries **4 pans**. `patch_paddy_edge` is **rectangular** (`half:[5.8, 3.275]`). 5 paddy patches. |
| **jungle_patch_layer.gd:84 (the code, stale)** | `var _water: Dictionary = {}` — and its own header still documents `"water": {level, half, at}`, the **dead** format. |

### ❌ BREAK 2 — 44 DESTRUCTIBLE TREES, ZERO LINES OF CODE
`patches.json` ships **44 destructible trees across 18 patches**, each
`{at, r (collider radius), h (bole height), th (whole tree height), slot}`, plus a `tree_ref`
declaring `{height 10.0, bole_h 7.2, trunk_r 0.32}` and three models.

**Nothing in `scripts/` or `terrain/` reads `trees[]` or `tree_ref`. Not one line.** The only
`felled/stump` hits in the entire game are `gib_system` (human gore) and one comment in
`clearing_system`. The Blender lane is complete; **the code lane was never built.**

### ❌ BREAK 3 — AND THE MODEL PATHS ARE ALREADY DEAD
`tree_ref` in the **shipped** `patches.json` points at:
```
res://assets/models/vegetation/felled_tree.glb      <- assets/models/ WAS DELETED
res://assets/models/vegetation/felled_trunk.glb        by the 615ddd0 restructure.
res://assets/models/vegetation/tree_stump.glb          The files now live in
                                                       assets/world/vegetation/
```
So even if someone wired `trees[]` today, **every tree would fail to load.** This is the landmine
found this morning — and it is not just in `tools/make_jungle_patches.py:978-980`, it is baked into
the shipped data.

### ⚠ BREAK 4 — RICE PADDY IS A GUESS, NOT HIS ART, AND IT BREAKS ADR-010
`gameplay_grid.gd:284-291` decides RICE_PADDY from **elevation and slope heuristics**:
```gdscript
if height < 5.0 and slope_val < 0.1:  return TerrainType.RICE_PADDY
...
if height < 50.0:  return TerrainType.RICE_PADDY if randf() < 0.3 else TerrainType.GRASSLAND
```
Two separate problems:
1. **It is not connected to his 5 authored paddy patches, nor to the WaterSystem.** The player wades
   a paddy because a *grid cell is labelled* RICE_PADDY, not because there is water there. The
   Summoner is right: the paddies do not inherit water from the game.
2. **`randf()` — UNSEEDED GLOBAL RNG — INSIDE WORLDGEN** (also `:478`). **ADR-010 says the province
   must rebuild bit-identical from one seed.** It cannot. This is a live determinism violation and it
   sits under the GATE bead `5i8a`.

---

## THE SUMMONER'S TWO STANDING ORDERS FOR THIS COUNCIL

1. **"always using our new godot 4.7 skills we have to make sure were doing things in the smartest way."**
   Load `~/.claude/architect_knowledge/godot_4.7_features.md`, `godot_standards.md`, and the relevant
   `GodotPrompter/skills/<topic>/` folders. Do not design a 4.2-era solution.
2. **The War Room is the default.** No build before the council.

## THE CONSTRAINTS THAT BIND EVERY ANSWER

- **PERF IS THE TOP SYSTEMIC RISK.** Last measured **19–25 FPS** — and TD found `scaling_3d/scale=0.77`,
  so *every FPS number this project has ever quoted was taken at 77% resolution and no doc says so.*
  There is still **no gating FPS number.** 44 trees/patch × 23 patch types across a 1280m AO is a
  large number of anything. **Whatever you propose, price it.**
- **ADR-010:** one seed per operation; bit-identical rebuild.
- **ADR-013:** streaming OFF at ≤2km.
- **The r4bk Law:** a feature with no HUD/visual affordance does not exist.
- **ADR-023 (THE FOSSIL LAW, new today):** when you replace a system you MUST delete the old one. A
  new dead symbol FAILS the build (`tests/test_fossils.tscn`, 79 grandfathered, register only shrinks).
- **COMMENT DISCIPLINE (new today):** comment only to state a constraint the code cannot show.
- **Pillar 2 (Atmosphere)** and **Pillar 3 (Freedom — cover is an economy)** are what destructible
  jungle serves. A tree you dive behind must stop a bullet; a tree that falls must *become* cover.

## LAW FOR THIS COUNCIL
1. **Read the code and the data. Never the plan.** The measurements above are a starting point.
2. **No cross-talk.** Your independence is the value.
3. Full analysis to `production/war_room/analysis/<name>.md`. **Return a SHORT verdict only.**
4. **Name what is sacrificed.** No free lunches. The law binds the Arbiter too.
