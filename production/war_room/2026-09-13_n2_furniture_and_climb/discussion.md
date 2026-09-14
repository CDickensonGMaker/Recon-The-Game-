# DISCUSSION — N2 first case: furniture and climb (2026-09-13, late)

Three architects, no cross-talk: `analysis/systems_designer.md`, `analysis/lead_programmer.md`,
`analysis/devils_advocate.md`.

## Where the Arbiter's briefing was wrong (all three, from different doors)

- **The climb is 0.40 m, not 0.5.** `project.godot:317-319` sets `navigation/3d/default_cell_height
  = 0.2`; every bake prints `h=0.200 climb=0.40`. The nav_baker comment at `:389-393` ("project.godot
  has no [navigation] section, so the map runs at the 0.25 default") is a fossil, and the briefing
  repeated it. Corrected in the same change (no-drift law).
- **Three furniture behaviours, not one** (DA measured them from the mesh, not the census):
  lockers and the pit kerb (tops 0.22-0.39) are RIDDEN — the mesh climbs them as one step; cots
  (0.43-0.55, one at 0.72) are RIDDEN as two ~0.3 steps (rail, then mattress — LP); the radio chair
  and table (0.86-0.90 tall) are HOLES — they punched the mesh, agent-radius erosion widened the gap,
  and the two radio rows are men PLACED in the eroded gap 1.1 m off the mesh, not men blocked by a step.
- **The cot top captures the nearest-point query** (SD): 11 of the 15 quarters rows read NO ROUTE or
  a 2-point path because `map_get_closest_point` snapped to the cot-top island above the man; the
  route it found was onto the cot. Carving (SD) or dropping the islands with `region_min_size` (LP:
  a cot top is ~3×7 cells; `region_min_size` is a SIDE, squared) both remove that.
- **The 1.2 m gate refuses both escape hatches** (LP, DA, SD independently): `NavRouter.OFF_MESH_M
  1.2` (`nav_router.gd:36`) is compared XZ-flat; a man 0.9-1.2 m off the mesh is neither steered
  back by `step()` nor snapped by `_rescue_snap`. 8-10 of the 26 rows sit in that band.
- **53 → 26 was mostly reclassification** (DA, from the logs' own `post` column): walking rows went
  8 → 23, arrivals moved 48 → 58, the "away" count stayed 33-36. The unstick change made men MOVE; it
  bought ~10 real arrivals. The census's gate must count ARRIVALS, not the absence of a flag.

## The four fixes, judged

| fix | SD | LP | DA |
|---|---|---|---|
| 1 climb 0.4 → 0.2 (+ region_min_size 5) | REJECT: berms, crater rims, bunker steps fragment; cell 0.1 = ~6× bake | BACK, first, behind an outside-to-TOC `map_get_path` gate | REFUSE: at 0.2 every slope over 38.7° is a mesh cliff the body still walks; the crater ruling reverses; the assault re-routes; cots become erosion holes |
| 2 carve furniture | BACK, first: world-space XZ hull per shape, inflate 0.5, drop its faces; removes 17/26 incl. the capture | REJECT: 0.65 inflation seals every hooch; dominated by 1 | ONLY after `probe_interior_nav` proves a 0.3-inflated carve leaves a hooch walkable; NEVER the tent frame (13.6 m AABB) or `MC_pit_floor` (18.8 m plates) |
| 3 step-up, civilians only, ≤ 0.4 | BACK, second: one number for bake and body | NOT NOW for enemies/allies (the assault would vault 61/181 sandbag parts the mesh already climbs) | BACK for civilians, gated on wanted speed AND zero slide |
| 4 placement rejects a furnished spot | BACK, third: golden-angle free-candidate | BACK as the cheap second (floor test in `_resolve_target`) | BACK in support-identity form: reject a spot whose support ray hits `fb_int_` or whose snap moved > 0.3 m |
| OFF_MESH_M 1.2 → 0.5 | named the band | BACK, first, zero risk | agrees the band exists |

## Resolution, by reading the code and the count

1. **Fix 1 is refused.** Two of three refuse it with the same concrete cost (slopes and crater rims
   the body still walks become mesh cliffs; the assault re-routes) and the third only backs it behind
   a gate that does not exist. The climb stays 0.40. What LP wanted from it — dropping the cot-top
   islands — is available without the climb change (`region_min_size`, or the carve) and is deferred
   to a measured A/B (below).
2. **OFF_MESH_M 0.5 ships first.** Three doors, one number, no bake change; it is the agent radius,
   and it frees the hole-side men that no other fix reaches.
3. **The civilian step-up ships,** capped at `NavBaker.AGENT_MAX_CLIMB` (0.4), only when the mover
   wanted speed and the slide returned none, only on the floor, never for allies or enemies. It makes
   the bake's promise true for the men whose whole life is walking between hooch, post and pit.
4. **The placement check ships** in the DA's support-identity form: a home-spread candidate (and a
   rescue snap) is refused if the ray under it lands on an `fb_int_` collider or the nav snap moved it
   more than 0.3 m XZ; the angle steps by the golden step, up to eight tries, then the raw spot. Same
   determinism as before (name hash; no roll).
5. **The capture mechanism (cot-top islands) is deferred** to an A/B the next session can run in one
   sitting: `region_min_size 5` versus a 0.3-inflated carve of cots/lockers/radio furniture only,
   judged by `probe_interior_nav` (every hooch walkable), a bake polygon diff, the tower platforms
   still reachable, and the census arrivals. Neither ships tonight because both change the mesh the
   assault paths on.
6. **The census counts arrivals.** Per sample: post-bound men within `WORK_ARRIVE_M` of the resolved
   post (arrived) and further than 2 m (away). The decree's gate is arrivals up and away down on the
   shipped seed, with wrong-target and roofs at 0.
7. **`path_height_offset` 0.45 stays** (DA: the +0.42 m is the compound's baseline under men on open
   floor, +0.21..+0.52; it is correct geometry) until a climb change ever moves the baseline.
8. **The fossil comment** at `nav_baker.gd:389-393` is corrected in the same change, and the pit kerb
   (0.35 m on an 18.8 m deck) and the ~0.45 m bunker-step risers are recorded as CONTENT: they need
   ramps or a lower riser, not nav (LP).

## What each architect found that the others did not

- SD: the capture mechanism; the carve must be hull-based (the flat-GLB origins and the compound's
  yaw make a `nav_box` meta wrong); 8 of 26 rows in the 0.89-1.20 m band.
- LP: the fossil premise; cots are two 0.3 m steps; `region_min_size` is the cheap island killer; the
  escape hatches share the 1.2 gate; sandbag parts the mesh already climbs (61/181) forbid a shared
  step-up.
- DA: three behaviours not one; the radio furniture are holes; 53 → 26 is reclassification and the
  gate must be arrivals; never carve the tent frame or the pit plates; the "real in both" ruling is
  honoured by the step-up and the placement check and quietly reversed by a carve that drops faces.
