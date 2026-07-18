# WAR ROOM 2026-07-18 — FSB "three fixes didn't take" root cause

## The Summoner's report
A) The mega main firebase (fsb_main.glb) "not appearing" — spawn area shows sparse gray
untextured pieces (guard tower frame, two gate/fence panels, one pancaked slab) floating.
B) Firebase geometry floats a few FEET above the terrain at the spawn; recurs across fixes.
Three fix attempts (1b335920 buried-firebase P0, 93675838 plateau flatten, 70ffda83 re-export
+ d505d18c save re-seat) did not kill it.

## MEASURED evidence (headless probes, clean runs, seed 47225 — all reproducible)
1. `tools/diag_fsb_model.gd` (asset probe): current fsb_main.glb is HEALTHY —
   658 mesh instances, AABB 356×14×344 ring layout, 488/664 surfaces textured,
   0 hidden, global min_y = 0. The 17:20 re-export is real. Import cache fresh (17:24).
2. `tools/diag_fsb.tscn`: placement path is SINGULAR — mission_generator.build_patrol_world
   → site_planner.place_firebase_main. No scene or script anywhere else references
   `structures/firebase/*`. fsb origin = terrain = 199.81 at center; spawn delta 0.00.
3. `tools/diag_fsb_seat.tscn` (NEW, fine-grained): **TWO INDEPENDENT ROOT CAUSES**:
   - **CAUSE 1 — first-sign craters dig through the base on every build.**
     `plan_patrol_world` rings "old craters" 170–280m from the GATE in 4 quadrants; the
     gate sits ON the wire ring, so the inward quadrant IS the base. At 47225 a
     LARGE_EXPLOSION first_sign lands at (950,712) **inside the fsb rect**, digging
     terrain to 181.2 under the 199.8 seat (−18.6m); wire cards bwire_card_156..204 hang
     9–17m in the air over the bowl. Three more signs at (1200,663)/(1200,732)/(1200,432)
     sit just outside the rect but their ~60m radii + 8m RIMS chew the ring edge — the
     "+7m buried" footprint samples are crater rims, NOT flatten failure.
     `_passable_near` has NO firebase keep-out. Every world build re-digs. This is the
     divergent-system signature: fixes landed in the placement path; a second
     terrain-mutating system undoes them at build time, deterministically.
   - **CAUSE 2 — the export itself carries mis-seated clusters.** In MODEL space
     (`tools/diag_fsb_clusters.gd`): the ENTIRE GATE CLUSTER (25 meshes: gate posts,
     panels, sandbags, wire, claymore line, watchtower, mg nests) has bottoms at
     y=4.68–4.92m with EMPTY AIR beneath — the "y=0 = ground" export contract violated
     per-cluster. Player spawns 22m from the gate: the first thing he sees is a guard
     tower frame + gate panels floating ~3m above his head. **That is the screenshot.**
     Also: hootch/tent/aid-station cluster at (−86,121) bottom 2.69m; crate stacks at
     (42,97) bottom 2.26m. 120 suspended meshes total.
4. Symptom A's "sparse gray scatter" additionally matches YESTERDAY'S export (whole
   props_workshop scattered 369×344m, superseded 17:20). Logs rotated; cannot prove
   which run the screenshot came from — but with the gate cluster at +4.8m, even the NEW
   export greets the player with floating gray gate hardware, so the report stands either way.

## Proposed decree (critique this)
- FIX 1 (code, live path): `_passable_near` gains an optional `keepout: Rect2` param;
  first_signs pass fsb rect inflated by 70m (crater radius 60m + margin), with capped
  retries — a quadrant that cannot clear the wire yields NO sign (correct: that quadrant
  is your own base). Villages/camps fallback + patrol anchors pass the uninflated rect.
- FIX 2 (export, NOT code): re-export must zero the per-cluster Y offsets (gate 4.8,
  hootches 2.69, crates 2.26). Per the Summoner's law we do NOT hand-patch the GLB or
  runtime-snap meshes — name the defect exactly and route to the Blender pipeline.
- PROBE: diag_fsb_seat finalized as two verdicts: CRATER-CLEAR (must pass today) and
  MODEL-SEAT (expected FAIL until re-export; the ratchet that proves it).
- FOLLOW-UP bead: LARGE_EXPLOSION depth 0.06 normalized × height_scale 400 = 24m-deep,
  120m-wide craters — profiles likely authored for a smaller height scale; every patrol
  crater is a canyon. Needs its own decision (touches shipped damage grammar).

## Constraints (binding)
ADR-028 world foundation protected — improve, never re-fragment. ADR-023 fossil law.
ADR-010 one seed. Godot 4.7 only. No rails. Verification law: nothing closes without a probe.
