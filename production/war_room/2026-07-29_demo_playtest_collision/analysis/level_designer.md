# LEVEL DESIGNER — the fire slits do not exist yet

The Summoner asks that we "make sure you can shoot out the fire slit holes of sandbags and
bunkers." Measured against the generator, there is nothing yet to shoot out of.

## Finding L1: the parapet is a solid nine-course wall with no embrasures

`tools/gen_firebase_v3.py:249-280` (`parapet_segments`) builds the perimeter revetment as
~6 m destructible segments named `fb_sbg_seg_###`, each a `fb_kit.build_sandbag_wall(...,
courses=9, ...)`. Nine courses at `fb_kit.BAG_H` is a continuous wall. There is **no firing
step, no notch and no embrasure** anywhere in that path.

## Finding L2: even if a slit were modelled, the export would seal it

`fb_sbg_seg_` is not in `COL_TRIMESH` (gen_firebase_v3.py:779), so `make_collision()` falls to
the else branch and emits an **axis-aligned box hull from the segment's vertex extents**
(gen_firebase_v3.py:799-816). A box hull fills every opening in the mesh it wraps. The
generator already knows this — its own comment on `COL_TRIMESH` says *"a box would seal the
bunkers shut"*. The same is true of a slit.

Two consequences of the box hull today, beyond the slits:
- The parapet's collision top is a flat 6 m slab at the crest — a clean ledge to stand on,
  which is a second contributor to the Summoner getting on top of the perimeter.
- The box is axis-aligned in the segment's own space, so on the diagonal runs of an organic
  perimeter it is fatter than the wall it represents.

## Finding L3: the bunkers are trimesh and MAY already be shootable

`fb_bunker_mg` and `fb_bunker_fighting` ARE on `COL_TRIMESH`, so whatever aperture is modelled
into them is a real hole in the collider and lead will pass. **Unverified** — I have not
confirmed an embrasure is actually modelled in the bunker masters. This must be measured in
Blender before anyone claims bunkers work; see the Devil's Advocate on log-vs-measurement.

## Recommendation, and its cost

This is an ART task, not a code task, and it is the one item in this session that requires a
Blender re-export of `fsb_main_v3.glb`:

1. Cut a firing embrasure into a share of the parapet segments (not all — a continuous line of
   slits reads as a castle wall, not a firebase). Roughly one in three, weighted to the
   likely approach bearings.
2. Move `fb_sbg_seg_` onto `COL_TRIMESH` so the slit is a hole in the collider. Measure the
   collision cost: ~50 segments going box → trimesh is the kind of change PERF_LEDGER exists
   to catch.
3. Add a firing STEP behind the slit segments so a man's eye actually reaches it. A slit at
   sandbag course 6 with nothing to stand on is a slit nobody can use.
4. Verify (do not assume) an embrasure exists in the bunker masters.

**Ordering note.** Do this AFTER the one-ground fix. The parapet sits at
`platform_z(...) + BERM_H` (gen_firebase_v3.py:266) — its height is derived from the same
mound surface that is currently fighting the terrain. Authoring eye-height slits against a
mound whose relationship to the ground is about to change is wasted work.
