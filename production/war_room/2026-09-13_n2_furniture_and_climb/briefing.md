# BRIEFING — N2 first case: the furniture the mesh walks over and the body cannot (2026-09-13, late)

**Branch:** `BaseGame-V1` (= `RPG-build`, both at `5ddf69be`, pushed). Base-simulation work: commit on
`BaseGame-V1`, fast-forward `RPG-build`. Tree is clean.

**The Summoner's word:** "yes" to convening on the next demo blocker named by the NPC first batch's
gate (`production/war_room/2026-09-13_npc_first_batch/results.md`). The 40-minute demo handoff
(`production/DEMO_40MIN_HANDOFF_2026-09-13.md`) calls this N2, "safe placement and validate the actual
firebase". **This council is convened on the measured case only** — the men who stand against
furniture — not on the whole placement contract of handoff §5.2. Do not design `PlacementRequest`
here; fix the thing that was measured and leave the contract for its own council.

## What was measured (fourteen census runs, one column each; `evidence/stuck_rows_run14.md`)

Every stuck man in the firebase garrison has: a valid navmesh route to his post, a non-zero router
step at full speed, his target inside his baked box, nothing overlapping his capsule, the mound under
his feet at 1-4°, and a body that `move_and_slide` returns to velocity 0.00 every frame. `test_move`
10 cm toward his target names the blocker on every row:

| blocker (collider owner) | what it is | where the man is |
|---|---|---|
| `fb_int_cot_m1`, `fb_int_cot_m2`, `fb_int_cot_p1` | cots | his quarters (home spread 1-3 m) |
| `fb_int_locker_m0`, `fb_int_locker_p0` | footlockers | his quarters |
| `fb_int_radiotable`, `fb_int_radiochair` | radio set furniture | the radioman's post |
| `tent_frame_chowhall` | the chow-hall frame | the queue / counter markers |
| `MC_pit_floor` | the mortar pit's floor (its lip) | gun_crew_arty rest / off-duty at the pit |

The navmesh routes THROUGH each of these. The bake reads the real `-colonly` trimeshes (`nav_baker.gd:
40`, `_shape_step`), and `fb_int_` has been IN the bake since his 2026-08-13 ruling ("the furniture
should be real in both, not absent from both", `nav_baker.gd:821-826`). So the mesh is not missing the
furniture. It is walking over it:

- `nav_baker.gd:402`: `agent_max_climb = max(cell_height, round(0.4 / cell_height) * cell_height)`.
  The map's cell height is the engine default **0.25** (`nav_baker.gd:389-394` reads it from the
  server; `project.godot` has no `[navigation]` section). `round(1.6) * 0.25 = 0.5 m`. The comment
  above that line assumes 0.2 m cells ("0.4/0.2 in float32") — it is wrong by a cell, and every
  crater rim, sandbag lip, cot and footlocker under **0.5 m** bakes as a STEP.
- A `CharacterBody3D` has no step-up. `floor_max_angle` 45° (`nav_baker.gd:407` matches it for
  SLOPES). A vertical face taller than roughly a tenth of a metre is a wall to a 0.3 m capsule. The
  bake's own comment at `:405-408` names this "inverse fiction band" for slope and forgot climb.
- The census measured the mesh sitting **+0.05 to +0.85 m (mean +0.42)** above the men's feet
  across the compound: the mesh riding on cot tops, locker tops, sandbag skirts. `path_height_offset`
  0.45 now brings the agent's path points down to the feet (shipped, `civilian.gd:365`); it did not
  free anyone, because the step is still there in the world.
- `_update_unstick` now reads the WANTED speed (shipped): stuck rows 53 → 26 on the same seed. The
  26 left are in hooches and at the pit where a sidestep has nowhere to go and the rescue snap waits
  for "unseen" (`civilian.gd _rescue_snap`, `CombatManager.perceivable`).
- Height of each blocker's top over the man's feet (run 15, first sample; the full run lands in
  `evidence/heights_run15.md` during this council): **`fb_int_cot_m1` top +0.43 m, contact +0.35 m;
  `fb_int_cot_m2` top +0.47 m, contact +0.30 m.** Under the bake's 0.5 m climb, over the capsule's
  step. The climb theory holds for the cots; check the lockers, the tent frame and the pit lip in the
  full file. If any top is over 0.5 m the bake lost THAT one (the 2026-09-09 prop fold,
  `interior_prop_fold.gd`, folds `fb_int_` MeshInstances into MultiMeshes — check the colliders'
  association, `_shape_step`'s filter, the `nav_trimesh` meta).

Secondary, recorded, NOT this council's question: 6 rows with no map route at all; 13 rows where the
agent reports FINISHED while `map_get_path` has a route (F08); the chow-hall markers whose nearest
mesh point is one spot (cooks + diner stacked, `probe_chowhall_nav` measured 16/48 sealed before its
roof cull); 2-3 squad men spawning "2/4 dirs blocked" in the bunk area.

## Protected behaviour (do not regress)

The firebase bake's islands-by-design and its budget (`nav_baker.gd` header; one region per site,
`FSB_HALF` 185 m at 0.25 cells is already the biggest bake); `fb_veg_` stumps stay OUT of the bake
(`NAV_IGNORE_PREFIXES`, they fragmented the compound); `fb_hootch_roof_` and the roof-cull families
stay culled; the towers stay climbable via ladders; bunker steps stay floor; craters — `AGENT_MAX_
CLIMB` 0.4 exists so a crater rim is not a cliff (`:399-401`); enemies and allies share the same
bake and the same movers (`ally_base.gd:2570`, `enemy_base.gd`); one-man-per-work-point; ADR-010
determinism; the fossil law; comment discipline; the census gate (`--npc-census`) is the instrument
and must stay green on wrong-target and roofs.

## The Arbiter's proposed shape (READ THE CODE, then attack it)

Four candidate fixes, not mutually exclusive. Name which combination, and what it costs.

1. **Tell the bake the truth about climb.** Set `AGENT_MAX_CLIMB` to what a capsule actually steps
   (~0.1 m) OR keep 0.4 and give every mover a step-up. With 0.25 cells the minimum climb the code
   allows is one cell (0.25). Lowering the map's cell height (`project.godot` `[navigation]
   3d/default_cell_height`) buys precision and costs bake time (heightfield rows scale 1/cell).
2. **Carve furniture as obstructions.** Put cots, lockers, tables, chairs, the radio set and the pit
   lip into the `nav_blockers` group with a `nav_box` meta so `_add_structures` carves them with
   agent-radius inflation (`nav_baker.gd:1005-1040`), the way structures are carved. Risk: a 4×6 m
   hooch with two cots and lockers plus 0.65 m inflation each side seals itself; bunk markers sit ON
   cots (a carved hole under the post — the resolver's `nearest_mesh_point` then puts the man at the
   cot's edge, which is where a man sleeping on a cot stands anyway). `probe_interior_nav.gd` is the
   instrument ("can a man walk inside?").
3. **Give the body the step the mesh promises.** A step-up in `_step_toward` / the movers: `test_move`
   forward blocked → try up `agent_max_climb`, forward, then down. Makes 0.4-0.5 m furniture and
   sandbag lips climbable — a man walking over a cot is "correct" to the mesh and wrong to the eye.
4. **Keep placement out of the furniture.** The quarters spread (`_resolve_target`, name-hash 1-3 m)
   and `_seated` accept a candidate only if `test_move` from it toward the post is free for the
   first metre; otherwise step the angle (golden step, deterministic) until it is. Cheap, per-man,
   no bake change; does nothing for a post that is beyond a cot.

## Questions each architect must answer (in your file, with `file:line`)

- Which of 1-4, in what order, and which one is the ONE change that removes the most of the 26 for
  the least risk to the rest of the compound? Name what each sacrifices (law 2).
- Is the climb theory right? Check the height column in `evidence/` when run 15 lands; if the tops
  are over 0.5 m, say where the bake lost the furniture (`interior_prop_fold.gd`, `_shape_step`'s
  filter, the `nav_trimesh` meta, the prop lists at `site_planner.gd:2300-2320`).
- What does the mortar pit need — a ramp/step the mesh and the body agree on, or a post that is not
  behind the lip?
- Enemies and allies path on the same mesh with the same capsule. Which of 1-4 changes THEIR
  behaviour, and is that a regression (sappers at the wire, the squad's follow slots, the breach
  rebake's cost)?
- What is the cheapest probe that proves the fix: the census (`--npc-census`) stuck count on the
  shipped seed, `probe_interior_nav`, a bake polygon diff, or a new one?
- What is the single riskiest edit?

**Output:** write your full analysis to `production/war_room/2026-09-13_n2_furniture_and_climb/
analysis/<your_role>.md`. Return to the Arbiter ONLY a verdict of ≤ 200 words: the combination you
back, the riskiest edit, the one thing the Arbiter's read missed. No cross-talk. Time box: 25 minutes.
Read code, never the plan, when they disagree — the code wins.
