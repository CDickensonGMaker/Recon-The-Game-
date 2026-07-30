# SYSTEMS DESIGNER — nobody fought because almost nobody in that base is a fighter

The Summoner's line is the important one: *"no one fought besides me, not the VC and not my
allies."* Three separate systems each contribute, and only one of them is a bug.

## Finding S1: the garrison are civilians, by design (working as written)

`scripts/missions/mission_generator.gd:864-867`, verbatim:

> They are NOT combatants and NOT squad members: they carry no EnemyBase/AllyBase and never
> enter the squad roster.

The men inside the wire are `Civilian` nodes with occupations read off the GLB's work markers.
**The white helmets are the garrison.** They become soldiers only when
`FieldDirector._garrison_stand_to()` (field_director.gd:1228) hands each one 1:1 to
`GarrisonDefender.promote` — an AllyBase holding his post. That is good design and it should
stay: a base full of men doing jobs is the Vietnam feel; a base full of men aiming rifles at
the treeline at 14:00 is a shooting gallery.

The trigger is sound too. Stand-to fires on `siege_began` (field_director.gd:1270) **or** when
≥2 live enemies come within 90 m of `fsb_center` (`FSB_THREAT_MEN = 2`, `FSB_THREAT_M = 90.0`,
field_director.gd:858-859), polled every 0.5 s.

**So why didn't they stand to?** They may well have — and then walked straight into a bunker
wall, because a promoted defender is an `AllyBase` and `AllyBase` has no navmesh inside the
firebase (see lead_programmer P1). A stand-to that produces twelve men jammed against
revetments is indistinguishable, from the player's eyes, from a stand-to that never happened.
**The nav defect masks the combat system.** It must be fixed FIRST, and the fight re-judged
after, before anyone tunes a threshold.

## Finding S2: the squad walks out weapons-tight (working as written)

`scripts/squad/squad_system.gd:74-76` sets `weapons_free = false` on every member at spawn —
Pillar 3+4 doctrine, the squad goes loud with the player. `AllyBase._may_engage`
(ally_base.gd:202) gates all firing on it. The auto-flip at squad_system.gd:261 releases them
the moment `WeaponHolder.session_shots > 0`, i.e. the player's first shot.

The Summoner FIRED. So the flip should have armed. Two candidates worth a probe, in order:
`_auto_flip_armed` never being armed for the demo boot path, or the men being weapons-free and
simply unable to REACH a firing position. Given S1, the second is far more likely, and again:
fix nav, re-judge, then tune.

## Finding S3: the VC have nothing to shoot at

`EnemyBase._think` (enemy_base.gd:600) runs a combat brain **only** at
`alert_tier == AlertTier.COMBAT`; below that, `target` is force-cleared each think
(enemy_base.gd:607). Two things keep an assaulting cell out of COMBAT while it crosses open
ground at night:

- The garrison is `Civilian` — enemies do not target civilians, so an attacking cell running at
  a base defended by cooks and radiomen has **no valid target** until it sees the player or a
  promoted defender.
- Night `SightCap` is short by decree (the 80 m materialise ring is derived from it). Men
  sprinting toward a base they cannot see anyone in stay in ALERT and keep running.

This too resolves downstream of stand-to actually producing fighters who can move.

## Recommendation

Nav first. Nothing about the fight should be TUNED until the men can walk, because every
symptom in S1–S3 is consistent with correct combat code running behind a movement failure.
Retuning a working system against a masked defect is how a project grows a second, divergent
combat path — and this project has that scar already.
