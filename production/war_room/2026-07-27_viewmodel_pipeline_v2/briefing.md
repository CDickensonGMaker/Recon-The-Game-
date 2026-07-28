# WAR ROOM BRIEFING — Viewmodel Pipeline v2 (2026-07-27)

**Summoner's query (paraphrased from chat):** the M16 break and the other gun animation problems are
symptoms of a larger problem. Research the FPS genre, indie development, and Blender→Godot pipeline
practice for complex moving models/animations. Proposal on the table: add more marker points or rails
so arms and hands stop colliding with the gun during animation work.

**Trigger evidence (this session, measured 2026-07-27):**
- His playtest: M16 charge handle "hanging off the back of the gun before any animations."
- Root cause found: Blender's glTF exporter drops constant object channels unless
  `export_optimize_animation_keep_anim_object=True` — not set in `tools/export_viewmodel_clips.py:328`.
  Result: `rifle_idle`/`reload` in `m16_fp.glb` carry NO charge-handle track, and in Godot a clip with
  no track for a node leaves the node wherever the last clip left it. One `jam` or interrupted
  `reload_empty` displaces the handle permanently. Latent in ALL four exported guns.
- Otherwise the current GLB (2026-07-26 17:43) byte-matches the blend: chandle rail transform identical
  through axis conversion, 81.7mm pure-X pull, zero cross-axis leak. Origin-shift hypothesis disproven
  for the current blend/GLB pair.

**Council:** four independent research lanes, no cross-talk — `analysis/industry_rigging.md`,
`analysis/blender_godot_pipeline.md`, `analysis/indie_workflows.md`, `analysis/canon_digest.md`.

**Binding constraints:** ADR-034 (+ Amendment A: timers authored to the clip), ADR-004, ADR-018,
fossil law (ADR-023), the standing "harden, don't replace" verdict
(`production/research/viewmodel_pipeline_deep_dive_2026-07-26.md`), the 2026-07-26 ruling that
animation QUALITY authoring is the Summoner's hands, ADR-015 (look verified only by his playtest).
