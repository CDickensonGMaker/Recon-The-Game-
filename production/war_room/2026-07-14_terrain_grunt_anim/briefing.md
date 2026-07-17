# War Room Briefing — 2026-07-14

## Query (Summoner)

> "i want you to audit the entire Recongame project as well as diagnoise why the terrain engine is failing at making the maps like i wanted. im open to changing the terrain engine to get a better version of what im looking for. currently i feel like the terrain highs and lows of valleys and peaks is too strong and its basically destorying the map everytime we generate things. i also need v3 grunt models to be the us allies, with the grunt random spawner as their main mode of working. and we need all models to have their real animations linked to them with the character manager we made"

## Scope

This council addresses four specific complaints, plus a lightweight project-health cross-check against the active standing decree (`production/war_room/THE_PLAN.md`, awaiting ratification):

1. **Terrain engine diagnosis** — relief too extreme; map looks "destroyed" on generation.
2. **Terrain engine replacement** — Summoner open to swapping the generator for something better.
3. **US allies must use v3 grunt models** — current default is `us_grunt_v3`, but MOS variants may diverge.
4. **Random grunt spawner as main mode** — current `SquadSystem` spawns deterministic MOS bodies.
5. **Real animations linked to all models via the character manager** — `ModelActor` exists; verify it is actually wiring the shared `anim_library.glb` for every unit.

## Canon constraints

- `production/GAME_GUIDE.md` §4.9: 1280 m AO, chunked 256 m terrain, craterable ground, streaming OFF ≤2 km.
- `production/TERRAIN_WORKFLOW.md`: procedural heightmap is the renderer; hand-sculpted Blender terrain is forbidden because the province must regenerate from seed.
- `production/OVERSEER_CHARTER.md` §5: build order is gated by P1 playtest beads; jungle/terrain work is exempt only as bug fix / evidence-gathering.
- `production/war_room/THE_PLAN.md`: the 40/60 inhabited/empty AO archetype is awaiting ratification; any terrain fix must not collide with Steps 2–3 (per-preset height scale + lowland archetype).
- ADR-002: 1.7132 m scale contract for all characters.
- ADR-015: verification law — nothing closes without a probe/measurement/playtest.

## Architects summoned

| Architect | Domain | Focus |
|-----------|--------|-------|
| technical-director | Terrain / engine | Why the relief is extreme; whether to repair or replace |
| level-designer | Terrain / playability | What the generated ground means for the AO and E&E loop |
| lead-programmer | Characters / spawner | v3 grunt usage, random spawner, ModelActor wiring |
| technical-artist | Animation / rigs | Shared anim_library.glb, clip looping, alias resolution |
| devils-advocate | All of the above | Hidden costs, false fixes, scope creep |

## Deliverable

A single synthesis with: root causes, alternatives, the Council's recommendation, and a bead-ified implementation plan. No code until the Summoner ratifies the decree.
