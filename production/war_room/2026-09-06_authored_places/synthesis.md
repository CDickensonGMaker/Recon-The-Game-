# SYNTHESIS — Authored places: the scene is a plan, not a prefab

**Date:** 2026-09-06 · **Decree:** `production/adr/ADR-041-authored-places.md` ·
**Status:** POST-DEMO, BUILD NOTHING (Summoner ruling mid-council)

## The verdict in one line

**Caleb's instinct is right and his stated purpose is already legal. The Arbiter's proposed shape was
wrong and has been corrected by the council.**

## What each architect moved

**Devil's Advocate — the decisive contribution. He broke the Arbiter's own argument.**
The Arbiter opened by claiming `scenes/world/firebase_main.tscn` is a shipping precedent for authored
site composition. **It is not.** The file is **13 lines, 4 nodes, 2 `Marker3D`s** wrapping a
Blender-generated monolith — verified by direct read. It licenses *markers beside a GLB*; it does not
license authored composition, and the Arbiter was quoting a 13-line file while eliding ~200 lines of
seating machinery (mound manifest, ported height function, falloff constant, diagnostic tool). **The
precedent is struck from the reasoning.** He also produced the ten contracts `place_structure()`
discharges that a hand-instanced node skips — and the nine-day-old comment at `site_planner.gd:165-171`
in which this exact bug class ("*two tables would drift again, so there is ONE*") already cost a playtest.

**Technical Director — the mechanism and the hidden bills.**
Named the *only* way an authored scene trips the structural probe (a script under `scripts/` calling a
placement entry) and both ways passing it proves nothing (`load().instantiate()` is invisible to the
probe; `SEEDED_FILES` is a six-file whitelist). Then found three costs nobody had priced: the 230m
structure cull is **not** inherited by a directly-instanced scene; NavBaker gives an authored site a
**terrain-only bake** (mesh straight through every hut); and `clear_and_flatten()` **does not flatten** —
it is a 0.7 lerp toward the disc mean, so ~30% of relief survives and fixed local transforms float or
sink at the rim. Priced the whole thing at **20–31h**.

**Game Designer — scope and the pillar question.**
Established that **ADR-020 is not the obstacle**: it governs EVENTS, not geometry, and its §1 already
blesses hand-work by name. Found the stale citation — **ADR-039 §3 cites "ADR-020 §4" for the authored-
place reconciliation, but §4 is the Ambience Law** and says nothing of the kind. Contributed the three-
tier hybrid (markers / clusters / the AO) and the anti-creep rule. Also corrected the brief's premise:
the village is **not** out of demo scope — the two-quests plan makes it a demo playspace with a sweep.

**Arbiter — the root cause and the reframe.**
Found item 32's actual root cause by arithmetic: `_near_building` approximates buildings as a **circle**
that under-covers the rectangle's **diagonal corners** (7.85m clearance vs an 8.06m corner reach on
`nha_ruong_02`), and `chicken_coop` is zoned to exactly that band. **One line.** That reframes the whole
question: **authoring can never be justified as a bug fix**, and ADR-041 §11 forbids that argument in
advance.

## The decree

1. **THE SCENE IS A PLAN, NOT A PREFAB.** Markers, spawns and layout are authored; `place_structure()`
   remains the only thing that puts a building in the world.
2. **Three tiers.** A: markers (already legal, already shipping — his own 2026-07-29 ruling). B: clusters
   composed **in Blender**, where the naming contract lives, so `_wire_structure_destructibles` adopts
   them for free. C: the AO stays procedural — ADR-039 clause 1, not negotiable.
3. **Author the positions, seed the occupancy** — or the second playthrough is a memorised fight.
4. **Flatten is per-site, declared, and blended.** Pancakes are refused.
5. **Hand-placed does not mean correct.** Any authored-site work ships a marker-vs-navmesh probe in the
   same change, or it has moved the chow-hall defect into a new file.

## Tradeoffs named

Variety capped at the number of files somebody makes · replay freshness erodes · content debt multiplies
· the seating bill is paid by whoever tries to un-flatten it · two probes must be extended or they will
certify broken work.

## Corrections made on contact (NO MORE DRIFT)

- `production/adr/ADR-039-zones-not-streaming.md` §3 — stale ADR-020 §4 citation, corrected in place.
- `scripts/world/site_layouts.gd:2` — header claimed offsets and rotations; the file has none. Rewritten.
- `production/PLAYTEST_FINDINGS_2026-08-28.md` item 32 — now ACCEPTED-OPEN with its measurement, root
  cause and one-line fix recorded.
- The Arbiter's own firebase-precedent claim — struck, and the correction recorded in ADR-041's evidence.

## Nothing was built. No file under the frozen list was touched.
