# ADR-004: ADS FOV policy: base 75, per-weapon ADS zoom ratified
**Date:** 2026-07-10 · **Status:** Accepted (War Room audit #2) · **Supersedes/Amends:** CLAUDE.md "Weapon Viewmodel System" rule 2 ("FOV locked at 75.0 everywhere (no ADS zoom)", CLAUDE.md:198); decision half of bead 2spa

## Context

The FOV-75-everywhere lock was born as a *tooling* constraint, not a design conviction: it guaranteed
the viewmodel editor (`scenes/weapons/viewmodel_editor.tscn`, Camera3D at FOV 75) and the in-game camera
stayed pixel-identical, so weapon positions tuned in the editor matched the game. It was enshrined in
CLAUDE.md's "CRITICAL: DO NOT CHANGE" viewmodel block (CLAUDE.md:198) as rule 2: "FOV locked at 75.0
everywhere (no ADS zoom)."

The code then walked away from the law without amending it. Wave 40 re-enabled per-weapon ADS zoom —
`scripts/player/weapon_holder.gd:215-220` carries the comment *"W40: ADS FOV zoom re-enabled (per-weapon
ads_fov; 0 = no zoom)"* and lerps `camera.fov` from `BASE_FOV` (75.0, `weapon_holder.gd:39`) to
`current_weapon.ads_fov` across the ADS transition. Every live weapon `.tres` carries an `ads_fov`
field (`WeaponData.ads_fov`, `scripts/weapons/weapon_data.gd:28`): M16A1/CAR-15 60.0, Thompson/PPSh/SKS
58.0, Mosin/Kar98k 40.0, M1911/M79 65.0. Binoculars added a third FOV writer:
`scripts/player/player.gd:110-118` lerps `camera.fov` to 18.0, with an explicit truce clause
(`if not (weapon_holder and weapon_holder.is_aiming)`) yielding to the ADS writer.

By audit #2 the same decision existed in **three contradictory states**: forbidden (CLAUDE.md law),
shipped (W40 code), and undecided (bead 2spa, which still framed "keep FOV-75-no-zoom vs 75→68 ADS
zoom (needs CLAUDE.md amendment)" as an open question). The Summoner's 2spa comment (2026-07-09) had
already endorsed true look-through iron sights with ADS. The devil's advocate named this "the purest
specimen of drift in the project" and put the sacred cow on the docket; the lead programmer flagged it
as ADR candidate #1. The council's finding: **the code was right, the law was stale.** This ADR buries
the dead law and ratifies the shipped behavior.

## Decision

The FOV-75-everywhere lock is REPEALED. The following is law:

- **Base/hip FOV is 75.0.** `BASE_FOV` in `weapon_holder.gd` and the viewmodel editor camera stay at
  75; hip-fire never zooms. Nothing else writes camera FOV.
- **ADS zoom is per-weapon data.** Each `WeaponData` `.tres` declares `ads_fov`; `ads_fov <= 10.0`
  means no zoom (guard at `weapon_holder.gd:218`). Values live in `data/weapons/*.tres`, never
  hardcoded in scripts. Reference points: M16A1 = 60.0; scoped/bolt rifles may go tighter
  (Mosin/Kar98k = 40.0).
- **Binoculars FOV is 18.0** (`player.gd:115`). The binocular writer must yield to the ADS writer
  (the existing `is_aiming` truce at `player.gd:117`); exactly one system may drive `camera.fov` per
  frame.
- **M60 and RPD remain hip-fire weapons; RPG-2 uses a sight-raise, not iron-sight alignment** (per
  bead 2spa's ruling). Their current `.tres` `ads_fov = 60.0` values are pending compliance under the
  2spa alignment pass.
- **CLAUDE.md's viewmodel section must be amended** to replace rule 2 with this policy. Editor/game
  sync guarantee is redefined as: positions are tuned at hip FOV 75; ADS alignment is tuned per-gun
  in the iron-sight pass.
- **The decision half of bead 2spa is CLOSED by this ADR.** The execution half — true aligned iron
  sights for rifles/SMGs (tune `ads_position`, sights already modeled in weapons_us.blend /
  weapons_v1.blend) — continues under 2spa, folded into the Batch 7 idle-anim per-gun pass.

## Consequences

**Buys:** ratifies what players already have — real sight pictures at realistic magnification serving
Pillar 1 (outstanding gunplay); ends the three-state contradiction so fresh sessions reading CLAUDE.md
stop "dutifully removing the ADS zoom the Summoner wants"; gives the binocular/ADS truce a written
contract instead of a hand-rolled convention.

**Costs (named, per council law):** the PSX-era flat-FOV purity is sacrificed; the viewmodel-editor
sync guarantee is weakened — hip positions still match the editor exactly, but ADS positions must now
be verified in-game per weapon at that weapon's `ads_fov`, one careful pass per gun. Two writers on
`camera.fov` remain a standing hazard; any third writer must be rejected in review.

**Work created:** iron-sight alignment pass across all rifles/SMGs plus M60/RPD hip-fire and RPG-2
sight-raise enforcement (bead 2spa, open); CLAUDE.md viewmodel-section rewrite (Law & Ledger cleanup,
decree build-order item 7); master-blend sync discipline — edits to weapons_us.blend do not
auto-propagate to per-gun GLBs (noted in 2spa comments).

## Evidence

- `scripts/player/weapon_holder.gd:39` — `const BASE_FOV: float = 75.0` (verified)
- `scripts/player/weapon_holder.gd:215-220` — W40 comment; `camera.fov = lerpf(BASE_FOV, zoom_fov, ads_transition)`; `ads_fov > 10.0` guard (verified)
- `scripts/weapons/weapon_data.gd:28` — `@export var ads_fov: float = 55.0` (verified)
- `data/weapons/*.tres:20` — 17 weapons carry `ads_fov`: m16a1 60.0, ak47 62.0, thompson 58.0, mosin 40.0, kar98k 40.0, m1911 65.0, m26_grenade 75.0 (no zoom), m60/rpd/rpg2/rpg7/m72_law 60.0 (verified)
- `scripts/player/player.gd:110-118` — binoculars lerp to FOV 18.0; `is_aiming` truce (verified)
- `CLAUDE.md:198` — "FOV locked at 75.0 everywhere (no ADS zoom)" — the repealed law (verified)
- Bead `RECONgame-2spa` (OPEN, P2) — decision text and Summoner's 2026-07-09 iron-sights comment (verified)
- `production/war_room/synthesis.md` — RATIFY ruling, "per-weapon ADS zoom (ADR-004)" (verified)
- `production/war_room/analysis/lead_programmer.md` §A2, §f-1; `analysis/devils_advocate.md` items 3, sacred cow 1, ADR candidate 2 (verified)

## Related

- **ADR-001** (3D models are the renderer) — sibling ratification from the same drift family: code
  ahead of law, law amended by explicit decision per the Truth law.
- **ADR-015** (mechanical process laws) — this ADR is the corrective for a DO-NOT-CHANGE law violated
  silently by a wave-numbered commit; future FOV changes require ADR amendment, not a comment.
- Beads: `2spa` (iron-sight execution, open), decree item 7 (Law & Ledger cleanup — CLAUDE.md rewrite).
- Pillars served: **1. Outstanding gunplay** (usable sight pictures at HLL lethality ranges),
  **2. Atmosphere** (binocular glassing as diegetic recon tool).
