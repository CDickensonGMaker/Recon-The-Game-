# War Room QUICK — shotgun damage model under ADR-016 (2026-07-10)

**Summoner's query:** the shotgun has no .tres and ADR-016's flat table doesn't cover pellet spread.
One pellet-cluster value vs N-pellet hitscan — decide before it goes live (model incoming).

## The two options, tradeoffs named
- **A. One cluster value** (single ray, big flat damage, steep falloff): simplest; but no spread feel,
  no multi-zone hits, no crowd damage, and range falloff is a curve instead of an emergent miss —
  the shotgun stops being a shotgun. Sacrifices the fantasy to save ~40 lines.
- **B. N-pellet hitscan** (N rays in a cone, flat damage PER PELLET, damage aggregated per
  target+zone): real spread; head+chest+arm can share one blast; multiple enemies catch pellets;
  range falloff is emergent (fewer pellets connect); gore thresholds work naturally. Costs: 8 rays
  per trigger (trivial), an FX cap so 8 blood bursts don't spam, and pellet-vs-determinism scrutiny.

## Determinism scrutiny (the ADR-016 question)
ADR-016 bans damage ROLLS, not spatial variance — recoil and spread cones already exist. Pellet
directions are aim-space variance (same class as base_spread); each pellet's damage is a flat,
deterministic 13. The grammar holds.

## RECON fidelity
Tabletop point-blank 12ga = 2d100 (avg ~101 = a dead man). 8 pellets × 13 = 104 raw at contact —
the average IS the tabletop's, per the ADR-016 conversion law.

## DECREE: Option B — 8-pellet hitscan
- `WeaponData.pellet_count` / `pellet_spread_deg` (only >1 changes behavior; every other weapon
  untouched). `base_damage` is per-pellet.
- **Aggregation rule:** pellets sum per target+zone into ONE hit event → locational multipliers
  apply once, and GORE_WORKFLOW's single-hit thresholds (limb-off ≥ ~45) fire exactly as intended:
  4+ pellets into an arm at close range takes the arm; two rim pellets sting.
- Values of record: **8 × 13**, cone 5.5°, effective 12m / max 28m / min_mult 0.5, pump
  (BOLT_ACTION cadence ~70rpm), tube of 5, subsonic (boom, no crack).
- Stand-in viewmodel (kar98k scene) until the Summoner's model lands — swap `model_path`, done.

**Recorded as ADR-016 Amendment A (pellet weapons). Probe coverage: test_flat_damage (per-pellet
value + determinism), test_ballistics (schema/cadence/falloff).**
