# BRIEFING — The firebase becomes a KIT, and five things he saw

**Convened:** 2026-09-09 · **Arbiter:** the Overseer · **Summoner:** Caleb, playing the build live
(pid 13196, `RECONgame (DEBUG)`) — **NEVER kill it, open no window, freeze the save layer in any probe.**

---

## THE QUERY — his words, verbatim

> "i do think the best move is to dissect all the whole parts that weve made the firebase out of and
> than make the world firebase in godot with the terrain editor tool and model placing thing i
> purposed. i think thats the best way to do this, but that means we need individual model builds with
> the work points and animations saved to those locations and certian npcs thatll spawn with certian
> building combos etc and that way we can remove people falling thru berms and stuff that weve made and
> itll look more intergrated into the world."

> "the driving convoys need to be worked on too and i still ahvent seen any like dirt roads in the
> world. npcs still stacking up at work points and even the huey drop off isnt as perfect as it was in
> the blender scenes when we reviewed the animations so im curious about that too"

> "and i got stuck between a ladder and sandbags getting off the ladder"

## What he is actually asking for, unpacked

1. **Dissect** `fsb_main_v3.glb` into its constituent parts (the parts are proven; the bake is the defect).
2. **Re-assemble in Godot** using the terrain morph/cut tool + in-engine model placement he proposed
   earlier today (recorded in `production/FIREBASE_REWORK_INTENT.md`, itself an extension of ADR-041).
3. **Each part carries its own data** — work points, animations, and the NPC types that spawn with
   certain building combinations.
4. **Stated outcome:** no more people falling through berms; a base that reads as integrated with terrain.

## HIS PRIOR PROPOSAL — FOUND, DO NOT REINVENT

`production/FIREBASE_REWORK_INTENT.md` (2026-09-09 03:21) records the tool proposal verbatim:
terrain morph/cut tool → Godot model placement → real modular parts (trenches, bunkers) + reuse of the
hooches as building sets → better firebases authored in the game world → **and the same tool builds
WW1 battlefields.** That document also records: `DamageSystem.modify_terrain()` already edits the
heightmap; `ClearingSystem` already exists; `TerrainEngine` is 691 lines. **The deformation machinery
exists. This is exposure, not invention.** The trench module is the genuinely missing part.

**ADR-041 (2026-09-06, ACCEPTED as canon, POST-DEMO — BUILD NOTHING) is the governing law:
"THE SCENE IS A PLAN, NOT A PREFAB."** Its FROZEN FILES list is the scope wall this council must
respect or explicitly ask him to thaw. Its §12 price is 20–31h for **village + temple only**.

## THE FIVE OBSERVATIONS — none may fall on the floor

Each must come back classified: **(a) bug, known cause · (b) bug, needs investigation · (c) content
never built.** With file:line evidence, not reasoning.

1. **Stuck between a ladder and sandbags dismounting a ladder** — movement/collision trap on the walked path.
2. **NPCs still stacking at work points** — prior work exists (work-point exclusivity, 2026-08-24,
   commit `5ed4b181`). Regressed? Never worked? Different failure?
3. **Huey dropoff worse than the Blender review scenes** — standing trap:
   `recon-staged-scenes-are-not-clip-banks` measured the Huey embark passengers at **5 fcurves each,
   all object location/rotation, ZERO bone channels.** Verify what shipped vs what he remembers.
4. **Driving convoys need work.**
5. **No dirt roads anywhere** — likely never built. Prove it either way.

## CONSTRAINTS BINDING THIS COUNCIL

- **The 5 Pillars.** 1 gunplay · 2 atmosphere · 3 freedom (no rails, stealth is an economy) ·
  4 the squad is the RPG · 5 fail forward.
- **The GATE (ADR-015):** the demo playthrough is open. Feature epics are blocked. Exempt: bug fixes,
  presentation for shipped systems, standing-decree items, evidence probes.
- **ADR-028** one world build path · **ADR-039** zones, one builder · **ADR-041** authored places,
  frozen files · **ADR-042** the naming-contract bug class · **ADR-010** one seed ·
  **ADR-026** PS2 budget, Intel UHD is the permanent bench.
- **Scope law:** launch = ONE faction. A big-bang re-architecture with a dead demo in the middle is
  the thing to argue against hardest.
- **Law 2 — no free lunches.** Every architect names what their recommendation sacrifices.

## FILE BOUNDARIES — THREE AGENTS ARE LIVE. DELIBERATE FREELY, EDIT NONE OF THESE.

- `terrain/vegetation/vegetation_manager.gd`, `terrain/vegetation/tree_cover_layer.gd` — vegetation agent
- `assets/.../firebase/kit/firebase_v3.2.blend`, the villager hand prop — Blender agent
- the blast/crater/VFX path, `scripts/systems/tree_break_system.gd`, `scripts/systems/damage_system.gd` — napalm agent

## DELIVERABLE

A DECREE with a **phased, costed** plan; an ADR if the pivot is ratified in principle; all five
observations triaged into the playtest list; the isolated defect **FIXED tonight with a probe that
fails when reverted**; and the short list of calls that are genuinely his.
