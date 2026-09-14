# THE DECREE — N2 first case: the furniture the mesh walks over and the body cannot (2026-09-13, late)

**Arbiter:** Claude (Fable 5.1), for the Summoner. Council: `analysis/systems_designer.md`,
`analysis/lead_programmer.md`, `analysis/devils_advocate.md`; debate in `discussion.md`. Convened on
his "yes". Branch: base simulation, commits on `BaseGame-V1`, fast-forwarded into `RPG-build`.

## The judgment

The men who stand still in their quarters are not short of a route and not wedged. The bake's climb
is **0.40 m** (0.2 m cells, `project.godot:317-319`, the nav_baker comment that says otherwise is a
fossil), so the mesh RIDES every locker (0.28-0.39), the pit kerb (0.22-0.39) and every cot (as two
~0.3 steps), while a `CharacterBody3D` capsule with its origin at the feet steps over nothing; the
radio chair and table are HOLES that punched the mesh, with the men placed in the eroded gap beside
them 1.1 m off the mesh where both escape hatches (`NavRouter.step`, `_rescue_snap`) refuse to act
because of one shared 1.2 m gate; and a cot top is an island that captures `map_get_closest_point`,
so the resolver sends a man onto the cot. The unstick change shipped earlier tonight made these men
move (walking rows 8 → 23) and bought about ten real arrivals; the gate that matters is arrivals.

## The build (one change, one commit on `BaseGame-V1`, in this order, each measured)

1. **The census counts arrivals.** Per sample and in the summary: post-bound men within
   `WORK_ARRIVE_M` of the resolved post (ARRIVED), farther than 2 m (AWAY), and walking. The gate for
   this batch is ARRIVED up and AWAY down on the shipped seed, wrong-target 0, roofs 0.
2. **`NavRouter.OFF_MESH_M` 1.2 → 0.5** (`nav_router.gd:36`): the agent radius, compared XZ-flat. A
   man 0.5-1.2 m off the mesh is now steered back by `step()` and snapped by `_rescue_snap` when
   unseen. Shared by allies and enemies; smoke-tested under `--stress=assault`.
3. **A civilian step-up, capped at `NavBaker.AGENT_MAX_CLIMB` (0.4).** After the slide, when the
   mover wanted more than 0.3 m/s and the slide returned under 0.05 m/s on the floor, the body tests
   up 0.4, forward 0.25 along the wanted direction, and takes the step if both are clear; gravity
   settles the landing. Civilians only — never `AllyBase`, never `EnemyBase` (the assault would vault
   61 of 181 sandbag parts the mesh already climbs).
4. **Placement refuses a furnished spot.** A home-spread candidate in `_resolve_target`, and the point
   `_rescue_snap` / `place_for_current_hour` seat on, is refused when the support ray under it lands on
   an `fb_int_` collider or the nav snap moved it more than 0.3 m XZ; the spread angle steps by the
   golden step, up to eight tries, then the raw spot. Name-hash seeded, no roll (ADR-010).
5. **The fossil at `nav_baker.gd:389-393` is corrected** (the map's cell height is 0.2 from
   `project.godot`, the climb is 0.40) in the same change.

## Refused and deferred

- **Climb 0.4 → 0.2 (fix 1): refused.** Two of three name the same cost: every slope over 38.7° the
  body still walks becomes a mesh cliff, crater rims and berms fragment, the assault re-routes, and
  cots turn from steps into erosion holes. The climb stays 0.40.
- **The cot-top islands (carve vs `region_min_size 5`): deferred to a measured A/B**, one sitting:
  `region_min_size` 5 (a SIDE — 5 cells = 1 m; Godot squares it) against a 0.3 m-inflated carve of
  cots, lockers and radio furniture only (never the tent frame, 13.6 m; never `MC_pit_floor`,
  18.8 m plates), judged by `probe_interior_nav` (every hooch walkable), a bake polygon diff, the
  tower platforms still reachable, and the census arrivals. Both change the mesh the assault paths
  on; neither ships tonight.
- **`path_height_offset` 0.45 stays** — the +0.42 m is the compound's baseline under men on open
  floor, and it is correct geometry.
- **The pit kerb (0.35 m on an 18.8 m deck) and the bunker-step risers (~0.45 m)** are CONTENT: a
  ramp or a lower riser in the kit, not nav.

## What is sacrificed (law 2)

- A civilian will visibly step onto a cot, a locker or the pit kerb when it is between him and his
  post. The mesh already said he may; the eye will now see it. The A/B decides whether the furniture
  leaves the mesh instead.
- Enemies and allies get none of the step-up: an ally hemmed in by furniture stays hemmed in tonight.
- OFF_MESH_M 0.5 makes an enemy 0.6 m off the mesh walk back onto it before pathing; a wire-side
  sapper who used to bee-line 1 m to his breach point now takes a half-step first.
- The gate is harder: arrivals, not the absence of a flag.

## Gates before this is called done

- Census on the shipped seed: ARRIVED up and AWAY down against run 15 (arrivals 58, away 33-36, stuck
  26), wrong-target 0, roofs 0, 0 `SCRIPT ERROR`, no rise in `[NAV-FALLBACK]`.
- `--stress=assault` headless smoke (~3 min): the siege still opens, sappers reach the wire, no new
  `SCRIPT ERROR`.
- `test_bt_civilian`, `test_schedule_placement`, `test_offview_liveness`, `test_fossils` green.
- Commit on `BaseGame-V1`, fast-forward `RPG-build`, push both.

## Next after this

The cot-top A/B (above). Then the second council's decree (`2026-09-13_rpg_45min_hearts_and_minds/`)
builds on `RPG-build`.
