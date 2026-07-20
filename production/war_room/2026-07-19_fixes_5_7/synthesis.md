# DECREE — fixes 5–7

**Date:** 2026-07-19 · **Arbiter:** Overseer · **Council:** systems architect (water authority),
gameplay programmer (patrol routing), devil's advocate. Three independent lenses, no cross-talk.

## Ruling 1 — FIX 5 SHIPPED. The keep-out now binds routes.

`_patrol_anchors` (`scripts/missions/mission_generator.gd:156-186`) filters every anchor against
`_fsb_keepout` grown by `SitePlanner.FSB_SITE_CLEARANCE` (40.0) — the same rect the spawn sampler
uses and the same clearance the village and camp placers already use. One keep-out concept, three
consumers, as instructed.

**A second defect surfaced while implementing.** The key loop at the old `:161-163` read
`["village_center", "firebase_center", "camp_center", "insertion_lz", "exfil_lz"]`. The plan
dictionary is built with `fsb_center`, `village_centers`, `camp_centers` — **plural**. Three of those
five keys match nothing. The loop's *only* live effect was appending the gate spawn seat twice.
Villages and camps already enter the pool through `p.sites`. The whole loop is deleted (FOSSIL LAW).

The ambient-patrol spawn at `:566` also now passes the clearance; it defaulted to `keepout_grow = 0.0`
and its sample ring could land back on the seat band.

**Sacrifice, named:** a 40 m annulus outside the wire is now route-free. The wire's immediate outside
reads deader and first contact moves further out. The devil's advocate argued for the interior rect
only, to keep the base from becoming a safe zone by construction — **overruled**, because the interior
rect does not cover the spawn seat 22 m outside it (`scripts/world/site_planner.gd:504`) and therefore
does not fix the bug at all. 40 m on a 1280 m map is not a safe zone.

## Ruling 2 — FIX 6 SHIPPED, one half deferred.

`_passable_near`'s fallback is clamped (`mission_generator.gd:127-133`) and `modify_region` can no
longer return a reversed rect (`terrain/core/heightmap_storage.gd:144-147`). Both negative-controlled.

The devil's advocate's objection is upheld and **beaded rather than fixed**: an *empty* rect still
travels through `terrain_manager.gd:279-284` into `game_world.gd:406`, where a zero-size rect merges
and can expand the dirty region to the map origin. Those two files were outside the owned set this
round. Severity is low today precisely because the clamp removes the only producer.

## Ruling 3 — FIX 7 REFUSED. It is forbidden by its own brief.

The assigned one-line fix — write `_surface_h[i]` in `_trace_channel` — was **not made**, and the
15.3 % is unchanged. Two independent findings put it out of reach tonight:

1. **It would not have worked.** `is_water()` (`water_system.gd:469-476`) tests `water_map[i] > 0`,
   and `_build_water_map_from_hydrology` (`:394-412`) writes a nonzero entry for *any* type. Channel
   cells already get a type (`hydrology_map.gd:504`). A surface write cannot make a dry channel wet.
   The brief's supporting evidence was also vacuous: `test_height_authority.gd:259` guards its
   bed-vs-surface comparison with `surf > 0.0`, skipping every channel cell *because* the surface is
   0, so the quoted "0.00 m" was measured over lakes and swamps only.
2. **It would have changed movement, which the brief expressly forbade.** `gameplay_grid.gd:137-138`
   makes a WATER cell impassable when `get_water_depth() > WADE_DEPTH_M` (1.2 m, `:154`), and that
   depth is packed from `water_surface_full - terrain` (`water_system.gd:406`). Channels report 0.0
   today, so every creek is wadeable. Give them a real surface and any channel over 1.2 m becomes
   impassable to player and AI. **There is no version of "just place the water" that leaves
   passability alone** — the surface value *is* the passability input.

The real cause is two authorities with opposite metrics: `RiverGenerator` carves downhill from the six
highest **peaks** with no flow model (`river_generator.gd:63-102`), where `_accum = 1.0`, against
`HydrologyMap`'s `creek_threshold` of 200 (`hydrology_map.gd:54`). Every carved headwater is dry by
construction. That is `RECONgame-xx46`, a Summoner-level call with three lossy options.

**What was fixed in that file set:** the phantom `_trace_river` name in the `water_system.gd:428`
comment, which propagated into docs and into this round's briefs. The function is `_trace_channel`.

## Verification
- `test_terrain_desync` — **PASS, worst elevation drift 0.000 m** at all three edits.
- `test_patrol_world` — PASS, with a new route keep-out assert. Negative control fires **twice on the
  same point (204, 1047)**, which is the double-append of the spawn seat.
- `probe_patrol` — 7/7 PASS, circuits unchanged.
- `modify_region` negative control: reversed rects `(-887, -887)` and `(-3668, -3668)` without the
  guard, none with it, valid case byte-identical.
- Headless boot clean, no SCRIPT ERROR.
