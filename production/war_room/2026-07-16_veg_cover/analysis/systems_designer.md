# SYSTEMS-DESIGNER — vegetation-as-cover in the AI stress arena

**(1) Coupling stamp-to-placement — CORRECT.** The "four tables must agree" trap
(gameplay_grid.gd:155-157) is a property of the *real* build pipeline
(build_from_terrain → riparian → roof). The arena has none of that; it draws meshes
directly. Stamping density in the same loop that plants the mesh makes the mesh the
*single source* — no second table to desync. It also satisfies the Fairness Law by
construction: density exists **only where foliage is visibly drawn**, so the AI's sight
advantage is always telegraphed by the thing on screen. A decoupled density table would
be the violation (invisible cover). Keep them welded.

**(2) Values — two boundary bugs.** The concealment test is strict `> 0.6`
(enemy_base.gd:1398). Elephant grass at **0.6 fails it** → concealment dead in the grass
it's named for; set **0.65**. The 45m JUNGLE cap only lands at veg=1.0; 0.85 lerps to
~59m — fine, but don't call it "45m." Bamboo 0.5 → 92m, no concealment (below threshold).

**(3) The real hole — the proof is hollow.** Contact is (0,0), OPEN; jungle sits at ±84.
The sight-cap/concealment path **never executes during the firefight** — it's tested on
scenery nobody stands in. Fix: bump the two ridge-gap bamboo clumps (±10,0, right at the
contact) to **0.65** so the center approaches actually cap sight and trigger concealment,
OR seed a medium patch on a fought-over berm. Otherwise you've wired a system the arena
can't exercise.

**Sacrificed:** you prove the *reader* (enemy_base consuming density), never the
*writer* (the real build_from_terrain path). ArenaGrid is a second authoring surface that
can silently drift from production density semantics.
