# SYSTEMS DESIGNER — independent sight

## The three items are not one problem. They are three different KINDS of problem.

**Stretcher = a content problem.** Every system it needs already exists. The aid station is already
seeded with a medic and a patient (`site_planner.gd:967-975`). The ward already has a number
(`campaign_state.gd:60 ward_wounded`). The clips are matched-length pairs. What is missing is one
driver that walks a pair of men through load → carry → unload. That is authoring, not architecture.

**Cockpit = a presentation problem.** `seat_system.gd:51` hardcodes ONE clip for the pilot and there
are three more in the library. A Huey that lands, sits, and lifts off should not have a pilot in the
identical pose through all three. This is a variable swap and a state hook. Cheapest item on the
board by an order of magnitude.

**Jump/landing = a systems problem with no system.** This is the one that does not fit.

## Why jump does not belong to "routines"

A routine, in this codebase, is a man walking to a `work_*` marker and playing a role chain there
(`enemy_base.gd:work_pos`, `civilian.gd:_play_garrison`). **A station never involves a jump.** There
is no routine in the game where a jump is the correct pose, because a routine is by definition a
man standing still doing a job.

Jumping belongs to **traversal**, and traversal is where the gap is. Godot navmesh agents never
leave the mesh. The firebase has a berm, trenches, foxholes and a wire — all of which a man should
be able to go over — and today an NPC either walks the long way around or the navmesh is baked flat
enough that the obstacle is not an obstacle. Either way, **no NPC in this game is ever airborne**,
so there is no moment at which `jump_up` or `hard_landing` could fire.

## Where the jump clips DO have a live hook today

One place, and only one: **the helicopter.** `heli_lift.gd:38-41` already runs six per-man disembark
clips. A man stepping off a skid is a `jump_down`, and a man stepping off a skid while the ship is
still light on the ground is a `hard_landing`. That is a real, bounded, in-scope home for two of the
six orphans, and it needs no navigation work at all.

`jump_away` is a dive — its natural hook is a grenade reaction, and there is no grenade-flee
behaviour in `enemy_base.gd`/`ally_base.gd` to hang it on. `jump_up`/`jump_up_2` are vertical
mantles with no obstacle to mantle. `jumping_jacks` is PT and there is no PT routine.

## Recommendation
Wire stretcher and cockpit now. Take the heli-skid slice of jump/landing now. Declare the rest of
the jump family blocked on a traversal epic and say so out loud rather than half-wiring it.
