# Debate record — vegetation seat council, 2026-07-18 evening

## Convergences (independent)
- Both: cause A (clutter outside the rebuild path) is real; TD counted the 12–18
  modify_terrain calls per build, DA re-ran the magnitude probe himself (6.07m max float,
  4.4m above eye). Both: deferral of the re-scatter is correctness (grid updates after
  modify_terrain), not just perf.
- Both independently killed briefing errors: TD proved visibility_range is per-NODE
  transformed-AABB (chunk-quantized rings ARE symptom B); DA proved the same from the
  opposite direction (node-origin semantics would render clutter nowhere — the sighting
  itself falsifies it; godot#79471).

## Corrections the Arbiter accepted
- TD: emit from modify_terrain with the cell-accurate rect; _rebuild_queue is a fossil
  (nothing feeds it) — deleted; unconditional RNG draws per candidate; templates to member;
  cards cast_shadow OFF (TreeCover forgot what GroundClutter remembered).
- DA: fog math for 350m is real, the perf number is a vibe — the --card-dist lever ships and
  the Summoner's windowed A/B is the blessing gate; near_distance 46→65 priced in (arena
  solid-ring parity); attribution toggle (GroundClutter.visible=false) rides the blessing
  run; probe gets an independent physics-ray channel and an honest-limit header; bucket
  origins seat at real height so the culling stops working by accident.

## Overruled / deferred
- Naive per-chunk 350 (TD showed ±181m pop walls): replaced by 64m species buckets, ±45m.
- Water-system and GameplayGrid desyncs (DA's 5th and 6th instances): beaded P1, not this
  wave — each is its own root-cause surgery.

## Instrument law learned (bd-remembered)
MultiMesh.get_instance_transform/.buffer read back EMPTY in this 4.7 headless build —
two census probes measured nothing before tools/diag_mm_readback.gd exposed it. Validate
the ruler before the measurement; the probe file stays as the guard.
