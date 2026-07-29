# BRIEFING — The topo sheet: printed knowledge, and period cartography

**Date:** 2026-07-28 · **Summoner's query:**

> *"we should first work on the map thats created during the terrainengine creation. We need a marker
> for the Firebase as well as a few of the major villages off the start since the palyer would have
> knowledge of this. and the map that we have is kinda smushed in parts. can we work on modeling it
> more after real world military maps of that era from vietnam?"*

## Two asks, one artifact

1. **Printed knowledge** — the firebase and the major villages appear on the sheet from mission start,
   because a man issued a map in 1968 already knows where his own firebase and the surveyed hamlets are.
2. **Period fidelity** — the sheet currently reads as smushed in parts; model it on the real AMS/USATOPOCOM
   sheets US forces carried in-country.

## Constraints in force

- **ADR-022** (`production/adr/ADR-022-the-map-is-your-memory.md`) — the two-layer law. OBSERVED is the
  game's hand, ANNOTATED is the player's grease pencil, and the grease-pencil law forbids the game ever
  correcting the player.
- **VISION_READOUT** — *"The map is a topo sheet, not a minimap."* · *"UI is diegetic-first."*
- **ADR-030 / period-HUD decree** — the period HUD epic is DEFERRED to final polish and must never be
  raised as a blocker. `topo_map.gd:148` already carries the carve-out note: the pixel glyph chrome
  rides with ADR-030.
- **Pillar 3 (Freedom)** — no rails. A map that hands the player his objectives is a quest log.
- **Pillar 2 (Atmosphere)** — a grease-pencilled topo sheet is the most Vietnam object in the game.

## The state of the code, with pointers

- `scripts/ui/topo_map.gd` — the whole map. 187 lines. Renders a 512² image once in `_render_base_map()`
  (`:44`), draws marks live in `_draw_overlay()` (`:132`).
- `WorldConfig.MAP_SIZE = 1280.0` (`scripts/levels/world_config.gd:9`) — the AO is 1.28 km square.
- Sites are dictionaries `{"kind", "center", "radius", "nodes"}` produced by
  `scripts/world/site_planner.gd` — kinds in play: `village` (`:306`), `firebase_main` (`:925`),
  `vc_camp` (`:961`), `temple` (`:1054`), `lz` (`:1062`). Reachable as `patrol_plan.sites`
  (`scripts/main/game_flow.gd:304`) and `built.sites` (`scripts/missions/field_director.gd:954`).
- Roads already establish the precedent this whole decree rests on — `topo_map.gd:16-24`:
  *"Roads are BASE SHEET, not intel… they are the paper, not a mark on it, and ADR-022's two-layer law
  governs MARKS."*
