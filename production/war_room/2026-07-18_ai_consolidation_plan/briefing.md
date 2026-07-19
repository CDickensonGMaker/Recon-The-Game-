# WAR ROOM — AI consolidation PLAN (Summoner mandate, 2026-07-18 late)
**PLAN ONLY. No code until the Summoner blesses the decree. One approval gate — the plan
must be complete enough that the waves run afterward without mid-phase questions.**

## The mandate (Summoner)
Sharpen how the AI moves and thinks using the engine research; remove duplicate systems.
BUT: keep the hard-won arena→game_world translation layer, and preserve every shipped
behavior he asked for. Behavior-preserving on features; aggressive on plumbing.

## Inputs (read these, they are the ground truth)
- `production/research/engine_mining_2026-07-18/SYNTHESIS.md` — waves A–D mapped to measured
  liabilities (ai/agents 25–192ms CPU wall; per-think untiered perception raycasts;
  per-frame HitzoneBuilder.sync; enemies never sleep; 5 LOD authorities; dual registries;
  2469-line god class ~40% duplicated into ally_base).
- `recon_survey.md` beside it — file:line map of what exists. Zero-caller: WorldSim
  tiers/set_lod_live/abstract, SimClock.advance, apply_bullet_damage. quake3/rtcw/mohaa.md
  for mechanism details.

## Hard constraints (law for this council)
1. **PRESERVE (name per wave + the probe that proves it):** witness rule ADR-005 (silent
   kills stay silent; corpse discovery escalates — any perception rework is guarded here),
   2:1 fire discipline + hot-set, roll/crouch locomotion + cover_to_stand, patrol-mode +
   veg-cover concealment, spider-holes + tunnel retreat, suppression, squad hunt net +
   covering fire, open-patrol-sim decree (FieldDirector/wire gate/distance-gated spawns),
   gore/severed limbs, flat damage ADR-016, Fairness Law (alert≠accuracy, exposure ramp,
   first-shot near-miss, telegraphs).
2. **KEEP the arena bridge:** arena = fun/look benchmark (rule #1); consolidation ENDS with
   arena as a thin wrapper on the SAME world path (ADR-028 Phase 3), capabilities intact.
   A "duplicate" that is actually the arena-to-world bridge is a KEEP.
3. **Fossil law:** five LOD authorities → ONE tier authority; dual registries → one;
   apply_bullet_damage deleted; SimClock wired-or-deleted (council decides); WorldSim tiers
   become the authority or die to an AIDirector (council decides — never both).
4. Research waves are the MENU, not the decree — weigh against pillars; sequence for
   earliest measured-FPS payoff; night-arena bench + ps2_perf_probe before/after each wave.
5. **Fun clause:** accuracy-ramp/aim-in, duty-cycle fire, threat-spreading, leash, hearing
   priority ladder are FUN levers first (pillar 1 outranks perf) — mark them so.

## Deliverable (the Arbiter weaves from your analyses)
Decree (waves, ordering, sacrifices per Law 2) · bead graph (epic + tasks + deps, gated on
the Summoner's blessing) · keep/kill/migrate table for every named duplicate · preservation-
probe list · open questions ONLY where a pillar conflict genuinely needs the Summoner.
