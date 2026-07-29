# War Room 2026-07-29 — DEMO GAME (firebase-attack demo scene)

**Name is decreed (Summoner): DEMO GAME** — `scenes/levels/demo_game.tscn` +
`scripts/levels/demo_game.gd`.

## Summoner's query (verbatim intent)
A specific ~20-minute firebase-attack experience in a demo-sized AO slice (~400x400m ruled up from
his 200x200 ask), containing the firebase + explorable surroundings (temple ruins, a village).
*"lets make a new game scene that translates into my vision request so we can operate surgery on
this outside of the main game and include or exclude systems we might not be ready to share just yet."*

## The ask before this council
Design the DEMO SCENE ARCHITECTURE — not the minute-by-minute content (that's a later room):
1. A standalone scene (precedent: `scenes/levels/ai_stress_arena` / `support_fire_range` /
   `fire_support_bench` — standalone levels that boot without the campaign loop) that builds the
   demo slice: terrain, firebase stamp, village + temple stamps, jungle, squad, siege.
2. FIXED SEED, deterministic — same demo every boot (per-mission determinism + MissionScope exists).
3. A SYSTEM SWITCHBOARD: explicit include/exclude toggles for systems not demo-ready (e.g. save
   system? debrief? radio support? campaign persistence OFF by definition). Surgical, readable,
   one place.
4. A demo director stub owning the arc clock: dusk arrival → explore/prep window → probing attack →
   main siege (siege_director / ADR-036 d50 waves) → relief/end card. Stub = the phases + hooks,
   pacing values tuned later by playtest.
5. NOTHING in the main game may bend to serve the demo (no forks of shipped systems — reuse via
   composition; fossil law applies to any copy).

## Constraints
- Reuse: mission_generator site stamping (vc_camp/village/temple), TerrainEngine, SquadSystem,
  SiegeDirector, FieldDirector as composable parts — the council must verify which of these can
  boot OUTSIDE the campaign flow today and name the couplings that block it (coupling probe exists;
  never grep for groups — `production/` coupling read 2026-07-26).
- Perf: siege is worst-case CPU (23fps history). The demo slice is ALSO the perf bench arena.
- Canon: ADR-029 open patrol, ADR-036 siege, Forward+, fake lights, scale contract. A demo scene is
  presentation/harness, not a pillar change — but flag anything that smells like loop structure.
- 400x400m slice; boundary handling at the edge (soft turn-back, no walls per Freedom pillar —
  proposal needed).

## Output
Each architect: full analysis in analysis/<name>.md, short verdict back. Focus on TODAY's couplings
(read the code, cite file:line) and the cleanest skeleton that ships this week.
