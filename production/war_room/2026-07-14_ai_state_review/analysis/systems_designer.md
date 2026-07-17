# Systems Designer — AI Goals, States, and Coordination

## State / Goal Matrix

| State | Enemy Goals That Enter It | Ally Goals That Enter It |
|-------|--------------------------|--------------------------|
| IDLE | HOLD_POSITION, no target | HOLD_POSITION / FOLLOW / MOVE_TO, no target |
| ALERT | INVESTIGATE (lost contact, still hunting) | *not used* |
| COMBAT | ENGAGE_TARGET, SUPPRESS_TARGET | ENGAGE_TARGET |
| SUPPRESSED | ENGAGE_TARGET while suppression > 0.7 | *not used* |
| SEEKING_COVER | SEEK_COVER | SEEK_COVER |
| FLANKING | FLANK_TARGET | *not used* |
| ADVANCING | ADVANCE | *not used* |
| RETREATING | RETREAT | *not used* |
| DEAD | death | death |

Enemy AI covers the full matrix. Ally AI only uses three states and two goals. SquadSystem adds high-level behaviors (point-scan detect ambush, grenadier thumper logic, medic revive) but these are scripted reactions, not goal states.

## Coordination Layers

1. **EnemySquad static registry** — shared target, breadcrumb trail (`crumbs`), hunt lifecycle, covering-fire report, engagement census, grenade broker. This is real small-unit coordination.
2. **SquadSystem** — 5-man US squad with persistent roster, MOS roles, orders, medic revive chain, casualty persistence. No equivalent coordination layer between allies for fire-and-maneuver.
3. **CombatManager** — central enemy list, damage application, LOS helper.

## Archetypes on Disk

- `vc_rifleman.tres` — baseline VC.
- `vc_sapper.tres` — aggressive, likely flanks/retreats.
- `vc_farmer.tres` — timid, low courage.
- `nva_regular.tres` — disciplined, higher accuracy.
- `nva_rpg.tres` — heavy weapon specialist.

Gore Lab waves already mix these: `[VC, VC, VC, VC, NVA, NVA, SAPPER]`.

## Systems Verdict

The enemy side is the strongest system. The ally side is functional but shallow: allies do not suppress, flank, advance, retreat, or share target info. The stress-test arena should exercise *enemy* breadth first, then grow ally depth.
