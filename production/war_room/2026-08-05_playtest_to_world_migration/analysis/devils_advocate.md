# DEVIL'S ADVOCATE — what this migration costs, and what it will not fix

## 1. The premise is half wrong, and the half that is wrong is the expensive half

Caleb asked to migrate three things. Two of them **are already in the game**:

- Shoot-through materials: live in demo and patrol, four consumers, verified.
- RTO strikes with the tuned values: live — the range holds *no* copy, it calls the shipped director.

If we let him keep believing they need migrating, we will spend a session "migrating" code that is
already running, prove nothing, and hand him a build that feels identical. **The honest, uncomfortable
answer is: the reason those two do not feel present in the demo is not that they are missing. It is
that he has not walked the demo with them.** ADR-015 says feel is discharged only by his hands, and
no amount of migration substitutes for the walk.

I want that stated plainly in the decree, because the alternative is a week of theatre.

## 2. Destructible buildings buy atmosphere and NO NEW VERB

ADR-031 already conceded this in its own Consequences: *"buildings buy atmosphere but no new verb and
carry the perf tail (built last)."*

Adding HP to village huts does not change what the player can *do*. He could already shoot through
them, burn them (`flammable_structures`, `site_planner.gd:255`), and walk around them. After the
change he can flatten them — which is spectacle, not tactics, unless something reads the flattening.
Right now **nothing does**: no village-allegiance hit (ADR-019 hearts-and-minds), no ROE ledger
entry, no VC reaction. We would be shipping a destruction system with no consequence layer, in a
game whose Pillar 5 is *fail forward*.

That is not a reason to refuse it. It is a reason to refuse to call it done when the hut falls over.

## 3. The felled-tree cover argument has a hole I want on the record

The technical-director's "net zero bodies" argument is correct about **count** and silent about
**shape**. The pool shares `CylinderShape3D` per radius (`tree_cover_layer.gd:374`) and parks bodies
by moving them to `PARK_POS`. A lying log needs a rotated capsule. That means:

- a second shape family in a pool built on the assumption of one,
- an orientation to persist per candidate (the fall direction) through chunk rebuilds, and
- a candidate that must survive `_build_scatter`'s holed-position skip — **the very mechanism that
  deletes the standing tree is the mechanism that would delete the log.** The log is not a scatter
  candidate; it is an exception to the scatter. Somebody has to own that exception, and
  `TreeCoverLayer` currently has no concept of one.

"Straight lift" is wrong for this item. It is a **small rewrite of the candidate model**, and
calling it a lift is how it lands half-done.

## 4. Permanence is an unbounded tax and there is no recycler

ADR-031 §4 promised permanence *"recycling only far behind the patrol."* **The recycler does not
exist.** Today that is invisible because almost nothing is permanent. After this migration:
~100 levelled structures with hidden meshes and disabled colliders, plus every felled log, plus the
rubble `MultiMesh` array which only ever grows (`destructible.gd:_scatter_rubble` appends, never
prunes; `reset_all()` runs only on scene reset).

For a 30-minute demo: free. For the open patrol simulator the game actually is: a leak with a
measured slope of zero, because nobody has ever run a long patrol and looked.

## 5. FALLEN_MAX 24 versus ADR-031 §4 — a live contradiction

`vegetation_manager.gd:482-485` FIFO-frees fallen trees past 24. If fallen trees become cover, then
**a log a man is lying behind can be freed out from under him by a blast 200 m away.** That is a
direct violation of "permanence is sacred within the active firefight radius." The FIFO must become
distance-keyed, or cover-logs must be exempt from it. Either way it is not a one-line change and it
must not be discovered during his playtest.

## 6. Three sandbag HP numbers, and none of them is the authority

- `fire_support_bench.gd:48-55` — `sandbag_wall 140`, `sandbag_stack 90`, its own comment calls it
  *"a first pass to tune by eye."*
- `site_planner.gd:1552-1558` — `sandbag_stack 90`, matched to the bench by hand.
- `support_fire_range.gd:988` — fort HP **110**.

Three tables, hand-synchronised, drifting. ADR-023 forbids exactly this. If we now add a fourth
table for village huts, we will have institutionalised the drift. **One HP table, one file, everyone
reads it** — or refuse the migration.

## 7. What I refuse outright

- **The arena's `SPOT_*` constants.** A second perception authority. The shipped one is better and
  the arena's exists only to route around its own spawn choice.
- **The bench's unlimited fire-support stock and `_cas_cooldown = 0`.** These delete the fire-support
  economy, which is the only thing that makes a fire mission a decision.
- **`SIEGE_STRENGTH` from the arena's 30-man survival waves.** The demo already ruled 45, and the
  2026-08-03 council proved 55 arms a known softlock. The arena's number is a stress figure, not a
  design figure.
- **`MIRROR_HP 80`, `mirror_mode` weapon swaps, `player_damage_multiplier`, `ai_hp_multiplier`,
  `rng_seed`, `force_gib`, `hot_start`.** Instruments. ADR-029 Q5 ruled labs stay labs.

## 8. The thing most likely to actually ruin his playtest

Not any of the above. It is `MAX_DEFORMS_PER_MISSION = 40` (`damage_system.gd:81`) against a
30-minute continuous demo where one arty mission spends 8–12 of them. He will call three or four
fire missions, then the ground will stop cratering while the scars keep appearing, and he will
conclude the tuning he spent a day on has regressed. **We would be debugging a phantom.**
