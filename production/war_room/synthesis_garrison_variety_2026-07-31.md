# SYNTHESIS — The firebase was a smoking club (2026-07-31)

Quick council. Query: *"keep working on all the animations."* Constraint carried in from
`SESSION_HANDOFF_2026-07-30_MIXAMO.md`: **no new clips before his verification pass.** So the
work is WIRING, not authoring — the library already holds more than the game calls.

## The findings, each with its pointer

**1. Half the firebase's work markers had no job.**
`fsb_main_v3.glb` carries **198 `work_*` markers across 20 types** (measured off the glTF node
table). `FSB_WORK_OCCUPATION` (`scripts/world/site_planner.gd:821`) mapped **9 of those types**.
The other 11 — `rest` 36, `supply` is mapped but `dig` 12, `wash` 9, `smoke` 8, `medic` 4,
`latrine` 4, `pad` 4, `mortar` 4, `burn` 3, `water` 3, `gun` 20 — **107 markers, 54% of them**,
fell through to `off_duty`.

**2. `off_duty` was one chain, so it was one pose.**
`civilian.gd:_play_garrison` handed every off-duty man
`["smoking", "sitting_drinking", "sitting_talking", "idle_unarmed_5"]`, and `play_first()` plays
the FIRST clip the rig carries. Six of the seventeen curated garrison are `off_duty`, plus every
unmapped work post. **They all smoked. Together. Forever.**

Same defect on the VC side: `enemy_base.gd:CAMP_ROLE_CLIPS` — one chain per role, so every
resting man in a camp smoked in unison.

**3. Which jobs got manned was decided by geometry, not by design.**
The work-post sampler took a **positional stride** — 198 markers sorted by X, every 16th one.
The budget is only **7 men** (`FSB_GARRISON_MAX_MEN` 24 − 17 curated), so which seven jobs the
compound showed was an accident of where markers sat on the map.

**4. `cargo_carry` and `cargo_unload_stack` never looped.**
Both are wired to the quartermaster (`civilian.gd:383-389`), `cargo_carry` as a *walk cycle*.
Neither was in `model_actor.gd:_LOOP_NAMES` — so **every man moving crates finished his clip and
froze holding it.** Same bug class the 7/30 wave fixed for the ambient set; these two were missed.

**5. The aid station had a medic-shaped hole.**
`medic_treat_give` had exactly one caller (the squad revive). `medic_treat_receive` had **none**.
Seating a lone medic would have him miming surgery over bare dirt.

## The decree

- `medic` and `detail` (the working party) join the occupation table; `rest`/`smoke` are now
  mapped to `off_duty` **explicitly**, so the fall-through is a decision instead of an accident.
- The sampler is **round-robin by work type, ordered by `FSB_WORK_PRIORITY`**, spending the
  budget on what the curated posts do NOT already cover.
- **The aid station seeds itself**: a medic AND a man on the cot, taken from the first two
  `work_medic` markers before the rotation runs. This is the casualty-ledger FLOOR — an aid
  station with nobody in it is the fresh-player failure. Wounded *above* the floor remain the
  ledger's job (`campaign_state.ward_wounded`), still unbuilt.
- `off_duty` gets **six chains**, picked by the same spawn hash `_idle_variant` uses.
- Camp role chains **rotate per man**, keyed off his station so the camp rebuilds identical
  (ADR-010). **The last entry never rotates** — it is the degrade target, and promoting it to
  the head answers "what is this man doing" with "the fallback".
- `cargo_carry` / `cargo_unload_stack` added to `_LOOP_NAMES`.

Measured result, 7 work posts: **medic · patient · dig · wash · water · burn · latrine.**
Reproduce by replicating `fsb_garrison_plan`'s rotation against the GLB's work-marker table.

## WHAT IS SACRIFICED

- **`gun` (20) and `mortar` (4) markers still seat nobody.** Deliberate and unchanged — a
  mannable M60 per `gun_crew` post is not a firebase, it is a joke (the constant's own comment).
- **A patient lies on the aid station FLOOR, not on a cot.** The cots live in the new
  `medical_complex` (29k verts, `firebase_v3.1.blend`), which is **not exported and not in
  `fsb_main_v3.glb`** — the live aid station is the older `fb_aid_station_i`. Period-plausible,
  but it is a floor casualty, not a bed.
- **The full aid station (§2 of the Mixamo handoff) is still not built.** `ward_wounded` still
  has zero consumers outside `campaign_state.gd`. This session gave it a floor, not a ledger.
- **Seven men cannot show twenty jobs.** Raising `FSB_GARRISON_MAX_MEN` is a frame-cost
  decision and was not taken.
- **NONE OF THIS IS PLAYTESTED.** Parse scan clean (`--headless --editor --quit`, 0 errors).
  That proves it compiles. He judges by eye.

## Note for the next agent

`--headless --script` **cannot** run a probe that touches `SitePlanner`: it fails on
`Identifier not found: ClearingSystem` (an autoload). The editor parse scan is the honest gate;
anything needing the plan itself has to be measured against the GLB directly, or seen in game.
