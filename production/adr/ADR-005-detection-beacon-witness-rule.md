# ADR-005: Detection beacon + witnessed-contact rule
**Date:** 2026-07-10 · **Status:** Accepted (War Room audit #2) · **Supersedes/Amends:** Amends the o18o bead spec into law; corrects the false comments at `enemy_base.gd:189-191` and `mission_director.gd:51-54`; feeds Decree build-order item #1 (Stealth Restoration Bundle, synthesis.md 2026-07-10)

## Context
The entire mission-level alarm hangs on one static beacon: `EnemyBase.last_combat_contact_ms`
(`scripts/enemies/enemy_base.gd:192`). `MissionDirector._check_detection()`
(`scripts/missions/mission_director.gd:65-71`) polls it once per tick; the first stamp newer than the
mission baseline fires "YOU'VE BEEN MADE - THEY'RE MOVING TO CONTACT" (`:71`) and activates the finite
hunter pool. This beacon architecture is sound — escalation keys off *detection*, never off the kill
event itself (`mission_director.gd:47-54` correctly removed kill-triggered escalation). The half that
was never written is the witness guard on who may stamp the beacon.

As shipped, the guard does not exist. `take_damage()` calls `_set_tier(AlertTier.COMBAT)` at
`enemy_base.gd:1497` — before the death check at `:1526` — and `_set_tier()` stamps the beacon at
`:626-627` *before* its own same-tier dedup at `:628`. Trace: one suppressed round into an unwitnessed
sentry → the dying victim stamps COMBAT himself → the director reads the stamp → "YOU'VE BEEN MADE"
from a kill nobody saw or heard. The dying man even plays the contact sting (`GunFX.play_combat_sting`,
`enemy_base.gd:641`). Ghost play is voided: the ghost bonus, threat cooling, and silent-movement value
all price against an alarm the player cannot avoid.

The drift is doubled by lying documentation. The comment at `enemy_base.gd:189-191` claims "a silent,
unwitnessed kill no longer summons the QRF"; `mission_director.gd:51-54` claims "a silent, unwitnessed
kill leaves the AO cold." Both describe the *intended* rule as if shipped. Bead o18o (P1, OPEN,
2026-07-09) records the truth; audit #2 confirmed the bead over the comments (all six architects
concurred — lead_programmer.md A1, systems_designer.md, technical_director.md A2, game_designer.md A4,
devils_advocate.md A3). This is the second consecutive audit in which Pillar 3's stealth economy failed
on this exact mechanism; Freedom scored 2.9, the audit's headline decline.

A second force: if silent kills stop raising the alarm, loud kills must honestly pay their price.
GUNSHOT noise currently propagates only 55m (`scripts/autoload/noise_bus.gd:14`) — an unsuppressed
rifle shot inaudible 60m away is not a Vietnam AO. Noise, not death, must be the signal that carries.

## Decision
The global COMBAT beacon (`EnemyBase.last_combat_contact_ms`) may be stamped ONLY by witnessed contact.

- **Witness rule:** a COMBAT transition stamps the beacon only if (a) the victim survives the hit, or
  (b) a living enemy other than the victim has the contact — LOS to the event or a NoiseBus hit. A hit
  that kills an unwitnessed victim must NOT stamp the beacon, must not play the contact sting, and must
  not trip `_check_detection()`. No "YOU'VE BEEN MADE" from a silent one-shot kill. Ever.
- **The beacon is THE alarm:** mission-level escalation keys exclusively off this beacon (DETECTION),
  never off kill/death events. This half already holds (`mission_director.gd:47-54`) and is hereby law.
- **Noise is the honest price:** GUNSHOT NoiseBus base radius raised 55m → ~150m
  (`noise_bus.gd:14`). SUPPRESSED stays ~3m (`:15`) and remains unidentifiable misc noise, not a
  gunshot. Enemies who *hear* the shot reach COMBAT legitimately and stamp the beacon — a loud kill is
  witnessed by the AO itself.
- **Escalation counterplay stands:** alarm carriers/radios remain the killable escalation vector —
  witnessing enemies must reach/act on the alarm, and the player can cut that chain.
- **Truth law applies:** the false comments at `enemy_base.gd:189-191` and `mission_director.gd:51-54`
  are deleted or rewritten to describe shipped behavior only.
- **Definition of done:** bead o18o stays OPEN until a headless probe
  (`tests/test_stealth_witness.tscn` or equivalent) proves both directions: silent unwitnessed kill →
  beacon unchanged; witnessed kill → beacon stamped. "Likely fixed" does not close it (ADR-015
  verification law).

**STATUS NOTE (binding honesty):** as of this ADR the witness rule is NOT implemented. The code cited
in Context is the current, wrong behavior. This record is the law the code must be brought to, not a
description of the code.

## Consequences
**Buys:** Pillar 3 restored at its root — stealth becomes an economy, not a fail gate. Ghost bonus,
threat cooling, and silent-movement value re-activate. Suppressed weapons and one-shot placement gain
real meaning. The docs stop lying, which is worth as much as the mechanic.

**Costs (named — no free lunches):** Loud play gets strictly harder — 150m gunshots mean one
unsuppressed shot wakes most of a 1280m AO's near half; loud remains viable (Pillar 3) but stops being
free. Perfect silent play can now clear content with zero escalation pressure — the finite hunter pool
never activates — accepted, because alarm carriers/radios and patrol density remain the pacing levers.
The witness LOS/noise check adds per-hit cost in `take_damage()`; must ride the existing perception/
NoiseBus paths, not new raycast storms (perf is already unmeasured — decree item #2).

**Work created:** o18o (OPEN, P1) — implement guard, delete lying comments, ship headless probe. The
150m noise change and RECON ±25 contact scoring ship in the same Stealth Restoration Bundle (decree
build-order #1; scoring under its own new bead). Detection pip HUD affordance lands with decree item #3
(fmc8) so the player can *see* the state this rule governs.

## Evidence
- `scripts/enemies/enemy_base.gd:192` — static `last_combat_contact_ms` beacon (verified)
- `scripts/enemies/enemy_base.gd:1497` — `take_damage()` stamps COMBAT before death check at `:1526` (verified)
- `scripts/enemies/enemy_base.gd:626-627` — `_set_tier()` writes beacon before `:628` dedup (verified)
- `scripts/enemies/enemy_base.gd:641` — contact sting plays on the dying man's own transition (verified)
- `scripts/enemies/enemy_base.gd:189-191` — false comment claiming the fix shipped (verified)
- `scripts/missions/mission_director.gd:51-54` — false comment; `:65-71` `_check_detection()` polls beacon, `:71` toast (verified)
- `scripts/autoload/noise_bus.gd:14-15` — GUNSHOT 55.0 / SUPPRESSED 3.0 base radii (verified)
- Bead `RECONgame-o18o` — P1, OPEN as of 2026-07-10 (verified via `bd show`)
- `production/war_room/synthesis.md` (2026-07-10) + all six `analysis/*.md` — unanimous finding

## Related
- **Pillars served:** 3 (Freedom — stealth optional, escalation not fail-states), 1 (gunplay stakes)
- **ADRs:** ADR-015 (verification/truth law — governs how o18o closes); the RECON ±25 contact-scoring
  decision (same bundle, separate record if ratified)
- **Beads:** o18o (implementation), fmc8 (detection pip HUD), ida9 (Playtest R3 gate)
