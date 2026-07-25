# ADR-030 — The period HUD buffer doctrine (a 640×480 authored buffer)

**Status:** PROPOSED — **DEFERRED to final polish of the game** by the Summoner (Caleb, 2026-07-25),
explicitly low-priority and NON-blocking. Not ratified; do not treat as law and do not treat as a blocker.
**Date:** 2026-07-24 · **Pillars:** 2 (atmosphere). **War room:**
`production/war_room/2026-07-24_period_hud/synthesis.md` (4-architect council).

---

## Proposal (held for final polish)

Author the in-game HUD into a fixed low-resolution buffer and blit it to the backbuffer at an integer scale
with nearest-neighbour, so tracked-out type, hairline borders and sub-pixel positioning become impossible —
the period look comes from the PROCESS, not a scanline shader. One bitmap face at two sizes; three
non-reconciling palettes; four persistent elements (compass, roster, ammo, reticle); no eased transitions.
Full spec + the corrected sizing math and the fossil-law consolidation of the two shipped HUD CanvasLayers
are in the war-room synthesis.

## Status detail — why it is DEFERRED, and the ripple
Caleb ruled the period-HUD LOOK is final-polish work, not near-term. Two things ride with it to final polish:
- the 640×480 authored-buffer period look itself, and
- the **pixel-glyph RENDERING of the field marks** (ADR-022 Amendment A) — the period bitmap symbols.

**What is NOT blocked:** all field-marking GAMEPLAY logic (placement, the area-circle, persistence, the
vocabulary, the §4 probes) proceeds now; only its period-correct rendering waits for this ADR. Likewise the
patrol-contract loop and destruction proceed against the current HUD.

## Open decisions (still Caleb's, when this thaws)
Authoring-buffer resolution (640×480 vs 512×448 vs 320×240) and the Phase-0 blit-seam spike remain open and
deferred with this ADR — do not ask them as blockers before final polish.

## Related
ADR-026 (Forward+ — the HUD SubViewport is 2D, no renderer conflict) · ADR-001 (PSX — the buffer reinforces
it) · ADR-022 Amendment A (the field-mark glyphs render through this) · ADR-023 (the two live HUD layers
consolidate into the buffer when this is built).
