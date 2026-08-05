# BRIEFING — Orphan clip wiring (2026-08-02)

## The query
Summoner's ruling: **stretcher, cockpit and jump/landing should be part of the routines.**
MG crew (`gun_*`) is **held** — he wants to visually confirm the clips before any wiring.

## The evidence that opened this council
Audit of `assets/shared/anim_library.glb` (163 clips) against every `.gd`/`.tscn`/`.tres`/`.json`
in the repo: **32 clips have zero call site.** 8 more (`*__smg`) have no literal call site but are
reachable through `sprite_state_map.gd:403` (`base + "__" + family`, `ppsh41 -> smg`).

Measured off the glTF, every clip in scope is a **real full-body clip — 123 channels / 41 bones**,
not a stub. Nothing here is blocked on art existing.

| clip | dur | verdict entering council |
|---|---|---|
| `litter_load_front` / `litter_load_rear` | 1.07s / 1.07s | matched length — phase-lockable pair |
| `litter_carry_front` / `litter_carry_rear` | 2.40s / 2.40s | matched length — phase-lockable pair |
| `cockpit_idle` | 4.03s | **already wired** (`seat_system.gd:51`) |
| `cockpit_controls` | 1.63s | orphan |
| `pilot_flips_switches` | 4.03s | orphan |
| `cockpit_dead` | 0.33s | orphan — a slump, one-shot |
| `jump_up` / `jump_up_2` | 0.57s / 0.27s | orphan |
| `jump_down` | 0.70s | orphan |
| `jump_away` | 2.67s | orphan |
| `hard_landing` | 2.03s | orphan |
| `gun_gunner` / `gun_loader` / `gun_agunner` / `gun_ammo_bearer` | 27.30–27.40s | orphan; near-identical duration = one 4-rig ensemble, split |

## Constraints binding this council
- **Pillar 2 (Atmosphere)** — this is the pillar all three items serve. None of them touch gunplay.
- **Pillar 4 (the squad is the RPG)** — a routine the player watches, never one he micromanages.
- **ADR-029 (open patrol simulator, foot-only)** — helicopters are PARKED as a *player* verb;
  `seat_system.gd:78` `player_boarding` is opt-in and nothing enables it. But ships still LAND and
  disembark: `air_traffic.gd:546` attaches `HeliLift` and six men step off per
  `heli_lift.gd:38-41`. **Pilots are visible scenery today.**
- **ADR-015 (verification law)** — nothing closes without a probe or a verified playtest.
- **ADR-023 (fossil law)** — no dead "fix" left for a pipeline to resurrect.
- **[[recon-station-architecture]]** (2026-07-29 ruling) — manned positions use **per-role clips
  driven by the EXISTING director**, never a new parallel one, and never a baked ensemble.
- **[[recongame-divergent-systems-blindspot]]** — ~14 parallel world-build systems already cause
  recurring bugs. A new director for any of this is forbidden.
- **[[recon-firebase-work-markers]]** — the firebase work budget is **SEVEN men**, not 198. Anything
  added here spends from that seven, or it must come from outside the budget.

## The systems in play
- `scripts/world/civilian.gd:425-491` — `_play_garrison()`, the per-occupation clip chains.
- `scripts/world/site_planner.gd:961-975` — post generation; the aid station is **seeded**
  (medic + patient) rather than left to the round-robin, on his 7/30 ruling.
- `scripts/autoload/campaign_state.gd:60` — `ward_wounded`, the butcher's bill that fills the ward.
- `scripts/vehicles/seat_system.gd:51` — `PILOT_CLIP := "cockpit_idle"`, the only pilot clip.
- `scripts/enemies/enemy_base.gd:2563-2565` — the ONE precedent for a two-body synchronized haul.
- `scripts/levels/anim_review.gd` — the clip wall + driver banks (`anim_review.bat`).
