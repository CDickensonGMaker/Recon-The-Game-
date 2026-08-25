## doctrine_data.gd - faction combat doctrine as DATA over the one shared core
## (War Room 2026-08-24 R2). US / NVA / VC / assault_press are .tres files in
## data/ai/ weighting the SAME knobs; no doctrine may fork code. Defaults are the
## shared-core constants, so an absent field is agreement, not a gap.
class_name DoctrineData
extends Resource

@export var id: String = ""

## ---- squad coordinator (Phase 2) ----
## How many men may hold an exposure token at once - a token is the right to be
## OUT of cover (ADVANCE / FLANK). HOLD and fire-from-cover are never gated.
@export var exposure_tokens: int = 3
## 0 disables the suppressor slot for this doctrine.
@export var suppressor_slots: int = 1
## A token expires on its own after this - the stuck-token guard (R3 sacrifice).
@export var token_ttl_ms: int = 6000
## Minimum gap between fresh grants, so movers start staggered across thinks.
@export var grant_stagger_ms: int = 500
## How long a shared last-known position is worth suppressing.
@export var suppress_point_ttl_ms: int = 8000

## ---- bounding overwatch (Phase 3) ----
## Elements swap mover/base-of-fire on this period. 0 = no element alternation
## (assault_press: the siege rotates its own press by squad, ADR-035).
@export var bound_period_ms: int = 6000

## ---- Phase-1 dials the doctrine may re-weight ----
@export var interrupt_refractory_ms: int = CombatGoals.INTERRUPT_REFRACTORY_MS
@export var fight_fresh_ms: int = CombatGoals.FIGHT_FRESH_MS
@export var cover_dwell_ms: int = 8000
