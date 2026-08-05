# LEVEL / WORLD-ARCHITECT — what the jungle actually does when you blow it up

## The single most important sentence in this council

**In the shipped world today, blowing up the jungle makes it MORE open and gives you nothing back.**

Trace it:

1. A blast calls `DamageSystem.apply_damage` → `vegetation_manager.clear_area`
   (`damage_system.gd:156`).
2. `clear_area` records a permanent hole (`vegetation_manager.gd:423`) and rebuilds every overlapping
   chunk (`:426-434` → `_rematerialize :490` → `TreeCoverLayer.generate_for_chunk`).
3. `_build_scatter` skips holed positions (`:546-548`). **The standing trunk's collision candidate is
   gone** — `TreeCoverLayer._chunk_trunks` regenerates without it, and its pooled body is released.
4. Up to **5** of those trees (`FELL_MAX_PER_BLAST`, `:446`) get a visual send-off: a bare `Node3D` +
   `MeshInstance3D` tweened over to `PI*0.47` (`_fell_tree_visual :459-485`). The file's own comment
   is honest about what that is: *"Visual only - no collider, no registry entry."*
5. Those lying trees are FIFO-freed past **24** (`FALLEN_MAX`, `:482-485`).

So: **cover is deleted, cover is never created, and the decoration that marks the loss evaporates
after 24.** Every remaining tree in the radius simply ceases to exist with no animation at all —
which is why a napalm run (60 m clear radius: 15 cells × 4 m `cell_size`, `world_config.gd:11`)
shows 5 trees falling and dozens popping out of existence.

## Correcting the briefing on canopy radii — the Arbiter was wrong

The briefing carried a suspicion that the 2026-08-05 "arty must tear the jungle" fix never reached
the main world, because `DamageSystem`'s `canopy_clear_m` → `JunglePatchLayer.blast_clear`
(`damage_system.gd:166-172`) targets a group the shipped world never populates:
`vegetation_manager.gd:114-123` is an **either/or**, and `WorldConfig.USE_TREE_COVER = true`
(`world_config.gd:21`) means the generated AO builds `TreeCoverLayer` and **never constructs a
`JunglePatchLayer` at all**.

The mechanism is confirmed — that group *is* empty in the shipped world. **But the conclusion is
wrong**, and I record the correction rather than the accusation. The main world's `clear_area`
radius is the crater radius in metres, and `cell_size` is **4.0** there versus the bench's much
smaller grid:

| Ordnance | main-world veg clear (`radius_cells × 4 m`) | arena `canopy_clear_m` |
|---|---|---|
| Grenade (SMALL) | 8 m | 0 |
| Arty / mortar (MEDIUM) | **12 m** | 13 m |
| Bomb (LARGE) | **20 m** | 18 m |
| Napalm | **60 m** | 26 m |

The shipped world already clears **as much or more canopy than the arena does**. The
`DEMO_SHIP_BACKLOG` line claiming the fix "Applies to main world AND benches (group-based)" is
loosely true in effect and false in mechanism — flag it as a pointer correction under the NO-DRIFT
law, not as a gap.

**The real gap is not radius. It is that only 5 trees per blast fall, and the fallen ones are
props.**

## Shoot-through: genuinely done, with three named holes

`place_structure` (`site_planner.gd:162`) runs `tag_ballistics` (`:189`, defined `:151`) with the
material from `CollisionTable.is_soft()`. That covers village huts, the village centre, caches,
tunnel mouths, VC camp structures, the temple and its statuary. `place_firebase_main` (`:1171`) runs
`_repair_glb_colliders` → `_tag_fsb_ballistics` (`:1341`, tag at `:1373`) over the firebase GLB.
`Destructible._ready` (`destructible.gd:30`) tags itself and un-tags on death (`:86-87`).

The tags are **not a fossil** — four live consumers, exact name match:
`bullet_system.gd:206` (soft punch-through, `dmg_scale *= 0.8`), `weapon_holder.gd:647` (shotgun
pellets through up to two soft layers), `bullet_system.gd:217` and `weapon_holder.gd:1139` (impact
FX), and `combat_manager.gd:290-292` (blast defeats cover — his ~50 % ruling).

Untagged, and each is a small honest bug:
1. **The felled log** (`fellable_tree.gd:129`) — the one thing in the game explicitly built as prone
   cover has no ballistic group, so rounds hitting it fall through to a filename heuristic.
2. **Tunnel rooms** (`tunnel_room.gd:29`) and the **resupply crate**
   (`field_director.gd:1027`).
3. Dressing props (`place_prop`, `:390-406`) have no physics body at all — deliberate, documented,
   correct.

Also a fossil: `site_planner.gd:140 _is_soft_cover(model_name)` is the old filename-hint heuristic
and is **dead in the placement path** — `place_structure:176` uses `CollisionTable.is_soft()`.

## Destruction coverage, by place

| Place | Bullet penetration | Blast damage / HP | Nav opens on breach |
|---|---|---|---|
| Firebase parapet (80 segs) | yes | **yes, 140 HP** | yes |
| Firebase bunkers / towers / sandbag stacks | yes | **yes, 260 / 180 / 90** | yes |
| Village huts, centre, cache, tunnel mouth | yes | **NO** | n/a |
| VC camp structures | yes | **NO** | n/a |
| Temple + statuary | yes | **NO** | n/a |
| Standing jungle trees | yes (trunk ring ≤70 m) | removed by veg-clear | no rebake |
| Fallen jungle trees | **no tag** | n/a | no |

**The firebase can be blown apart. The world you patrol into cannot.** That is the whole gap, said
in one line, and it is the line to put in front of Caleb.

## The permanence problem the demo hides

ADR-031 §4: permanence is sacred inside the firefight radius, recycled only far behind the patrol.
There is **no far-field recycler in code**. For a 30-minute demo that is free. For the open patrol
simulator that is a slow leak, and adding ~100 destructible structures plus persistent logs makes it
faster. Naming it as the sacrifice, not solving it here.
