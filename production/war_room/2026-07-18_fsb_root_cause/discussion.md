# Debate record — FSB root cause council, 2026-07-18

## Convergences (independent, no cross-talk — strongest signal)
- All three: placement path singular; causes are (1) build-time craters, (2) marker-Y realization.
- SD + DA independently found the SAME missed call site (mission_generator.gd:504 ambient-patrol
  spawn) — VC can spawn inside the wire on minute one, today.
- SD + TD independently corrected the briefing's scale numbers (height_scale 350, not 400;
  crater radius 60m max — the 70m grow survives but must be derived, not hard-coded).

## Corrections the Arbiter accepted against the briefing
- SD: sentinel on `_passable_near` degenerate return (origin IS the in-rect point for signs);
  villages RETRY never DROP (`villages2[pi % size]` + garrison loops break otherwise); village/camp
  fallback grow(40) for parity with find_site — an unequal fallback is the divergent-system disease
  itself.
- TD: never zero translations (37 meshes carry vertex-baked offsets, sandbag pivot −58.7m,
  mg_nest −100m); fix is per-chunk-GROUP world translate; markers (SOCKET/trigger zones) float too
  and must re-ground with their chunks; the "HEALTHY" asset verdict was an artifact of ONE
  vertex-recessed mesh (mortar pit) touching y=0.
- DA: keep-out must be DEFAULT-ON in `_passable_near` (opt-in parameters are the same fix-class as
  the three failed fixes); sign sectors aim into the gate_out outward half-plane instead of
  dropping (density preserved where the player walks); MODEL-SEAT probe must be signature-locked
  (chronic red breeds red-blindness; plain red can't tell known-defect from new-defect); probe must
  assert FSB_HALF/center against the loaded GLB or a re-export silently breaks the crater fix;
  "gray" is NOT explained until the gate cluster is cross-referenced against the 176 untextured
  surfaces — census added to the probe.

## Overruled / deferred
- DA's "scar-decal-only filled craters inside the rect": rejected — a second crater grammar
  (render-only) is a new parallel system; ADR-023 spirit.
- SD's crater meter re-tune: bead, Summoner blesses (shipped feel).
- DA's provenance doubt on the screenshot: accepted as caveat, decree proceeds — the +4.8m gate
  cluster guarantees the CURRENT export fails Caleb's eyes regardless of which run he photographed.

## Cleared suspects (so future councils stop re-litigating)
TerrainWatchdog (re-seats bodies, never terrain) · NavBaker (navmesh only; fsb excluded) ·
DamageSystem cross-build leak (MissionScope.reset → clear_all_damage) · PaddyStamper (read-only)
· R92 visibility-range cull (fsb path never applies one) · Godot import params (sane; one bounded
texture-staleness risk beaded).
