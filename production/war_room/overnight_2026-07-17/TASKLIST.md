# OVERNIGHT 2026-07-17 → 07-18 — 50 TASKS
North star: **"i just wanna leave the camp and go find problems."**
Decree base: open patrol simulator (synthesis_open_patrol_2026-07-17.md). Q1–Q6 run
on the council's RECOMMENDED defaults, every one reversible; the Summoner re-rules in
the morning.

## STOP-LINES (violating one is a failed night)
- NO `git push`, no history rewrite, no LFS surgery (yu8b is Caleb's sitting).
- NO edits to Caleb-authored .blends. Export FROM them via script only.
- NO deleting art his eyes haven't cleared — fossil-kill only zero-spawn-path items.
- 5-bead restructure stays FROZEN ("but wait tho").
- Godot 4.7 console exe only, headless; no editor, no windowed spam.
- Commit locally after each green wave; suite + fossil probe gate every commit.
- Anything ambiguous → bead comment + skip, never guess.

## A. W1 — POPULATED PATROL WORLD (the ignition-key move)
1. Extract population from the offer dict: `build()` runs off one operation seed.
2. Population bands: villages 280–450m, camps 400–540m, first-sign 150–300m.
3. Crown LocationPlanner's doctrine INTO the one `find_site` path; delete the file.
4. Re-anchor corridor ecology wire→location (exists, wrong anchors).
5. Guarantee ≥1 village + 1 camp inside 500m on ANY exit heading (probe-asserted).
6. Hub world and patrol world become THE SAME build (no objectives-less variant).
7. Determinism probe: same operation seed → bit-identical population.
8. Density probe: walk-sim 4 headings, assert first-sign ≤300m, first ville ≤450m.

## B. W2 — PATROL FRAME
9. Wire gate: 120m from firebase fires once per excursion.
10. Location pointer: pick nearest living location in push direction ±45°.
11. Diegetic only: map grease-circle + compass needle; delete floating markers.
12. Point-man bark on gate fire + repeatable (tap MAP) re-bark.
13. MissionDirector → FieldDirector rename/gut: toasts, fire support, escalation stay;
    objective tracking dies.
14. FieldHUD: barks/toasts render on patrol (hub renders them invisible today).
15. Death → field AAR screen → wake at firebase, world persists, patrol counter++.
16. Squad staggered file: point man 10–15m ahead, rear security trails.

## C. W3 — THE BURIAL (order: LAST among A–C code, per DA)
17. Extraction list executed: site stamping, squad setup, exfil hooks pulled out of
    the offer flow into the patrol frame.
18. Delete briefing UI + offer generation + select flow + TOC gate.
19. Delete dead legacy select→briefing wire (game_flow.gd:128, ADR-008 convicted).
20. Save schema bump + CONTINUE rewrite (old saves must not dead-end).
21. TOC becomes pure scenery (Q3 default yes).
22. Intel chain retargeted to locations (Q2 default retarget), W80 spend dies.
23. Rank clock = completed patrols (Q1 default yes) — data only, no UI beyond AAR line.

## D. W4 — ONE WORLD, ONE BENCH
24. dlox structural probe: fail if >1 live world-placement path / unseeded placement RNG.
25. Arena → thin wrapper over shared build (kill TerrainManagerStub/ArenaGrid).
26. Arena stops impersonating the `game_world` group; perception reads the real grid.
27. Arena `ai_hp_multiplier` default 1.5 → 1.0 (bench = campaign feel).
28. Arena night literals → shared MissionWeather values.
29. Delete terrain_lab.tscn (old-era RTS lab).
30. Seed ConvoySpawner rng + insertion_ride/weather randf off mission seed.

## E. FOSSIL KILLS (all zero-spawn-path, from game_designer_drift.md)
31. Re-point gib/hitzone tests+tools to a 7/15 grunt, then delete us_grunt_v2.glb.
32. Delete orphan models: us_grunt_m14/m60/m79, us_rto, us_medic, vc_guerilla_m16.
33. Delete WW2 vehicle fossils (sherman, halftrack, m24, jeeps, bulldozer, uh1_huey)
    + their collision_table/test rows.
34. Delete all 21 dead billboard textures.
35. Delete dead loaders: palm_tree/grass_patch paths + _create_procedural_tree.
36. Delete WW2 strings (audio_manager, gun_fx, sprite_state_map).
37. Delete sprite-renderer stubs (SpriteActor can never load art; ADR-001).
38. Kill the second grass system (untextured procedural triangles, veg_mgr:897/:587);
    GroundClutter is the one grass.
39. Fossil baseline shrink pass: bury every fossil these deletions retire.

## F. CHEAP REAL-ART WIRING (no look-check needed — replacing placeholder primitives)
40. Wire chicken.glb (kills the white sphere).
41. Supply crate: BoxMesh → cheapest real crate GLB on disk.
42. Buddhist ruin: pull the CatacombsOfGore temple from site_planner/mission_generator;
    substitute existing Vietnam-set structures; flag "needs real ruin art" bead.
43. POW camp: stop building it from US hootches if a VC structure exists; else bead it.

## G. PROBES + TRUTH
44. Full suite green + headless boot clean after EVERY wave; wave-tagged local commits.
45. Fresh perf datapoint in the populated patrol world (native, Forward+, PERF_LEDGER row).
46. k-assert + village-props + veg-density probes re-run against the patrol build.
47. FieldDirector/AAR headless probe: die → AAR → firebase wake → world persisted.

## H. PAPER (ratification-ready, nothing self-ratifies)
48. Draft ADR-029 (open patrol simulator) + amendments to ADR-008/006 — DRAFT status.
49. Bead graph updated per wave (comments, closures with proof); war-room record archived.
50. MORNING REPORT: what shipped, probe table, DA items, the Q1–Q6 defaults used,
    and the 5-item list needing Caleb's eyes in-game.

## MORNING — CALEB ONLY (not tonight, not counted)
- Re-rule Q1–Q6 where the defaults got it wrong · walk the patrol world ·
  yu8b source-line sitting + off-disk bundle copy · bless 5-bead restructure or kill it.
