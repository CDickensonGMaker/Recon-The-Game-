# BRIEFING — Authored places: are village and temple scenes, or scatter?

**Date:** 2026-09-06 · **Arbiter:** RECONgame Director · **Summoner:** Caleb

## The question (verbatim)

> *"would it be better to make the village and temple stamps in godot as scene and than in the map it
> makes a flat zone for the places? that way i can make sure the spawns are right etc?"*

The proposal: authored Godot `.tscn` scenes for village and temple sites, stamped onto a flattened zone
in the generated world, so spawns and dressing are hand-placed and verified rather than scattered.

## The Summoner's scope ruling, mid-council

> *"i guess this is post demo work."*

**BUILD NOTHING.** The contained proof on the demo's two sites is WITHDRAWN. This council records and
decrees only. Item 32 stays open as an accepted known with its measurement beside it.

## The two questions that survive the scope ruling

1. Does an authored-scene branch hold under **ADR-028** (one world-build path, protected foundation) and
   **ADR-039 clause 1** ("one builder, many places")? Genuinely content, or a second placement path?
2. Where is the **hybrid boundary** — authored for places that matter, procedural for filler — and what
   mechanically enforces it so the procedural path does not rot once authoring exists?

Plus: per-scene flatten with a blend radius, never mandatory.

## Constraints binding this council

- Pillar 3 (no rails, ever) · Pillar 2 (atmosphere) · ADR-020 (the rail/guarantee distinction)
- ADR-010 (one seed per operation) · ADR-013 (=<2km never streams)
- ADR-015 (verification law) · ADR-023 (fossil law)
- ADR-039's FROZEN FILES precedent: a recorded-but-unbuilt decree gets an enforcement surface.

## Architects summoned

technical-director · game-designer · devil's-advocate · (Arbiter holds the ADR-028/039 reading)
