# DECREE — Ambient friendly patrols (2026-07-20)

Council: systems-designer, ux-designer, lead-programmer, devil's-advocate. Summoned in
parallel, no cross-talk. Summoner ruled the feature IN; the council shaped it and the
Arbiter ruled on three challenges.

## What ships

**2 friendly patrols x 4 men**, dormant until the player closes to 140m — the same
`LazyGroup` proximity contract the ambient VC patrols already use
(`mission_generator.gd:624-640`). Spawned at `mission_generator.gd:642-660`.

**Pinned is EARNED, never rolled.** A patrol reports `friendly_patrol_pinned` only when
BOTH hold: `EnemySquad.break_state(live, peak, avg_courage).broken` is true, AND an enemy
is actually engaging them. No timer, no dice.

**Pacing: at most ONE pinned call per excursion**, latched and reset at the wire gate.
`DynamicMissionFactory._seen` (`dynamic_mission_factory.gd:39`) dedupes per entity on top
of that, so a patrol can never call twice.

## Arbiter's rulings on the challenges

**1. Devil's Advocate: "the crisis is a rail" — OVERRULED.**
He is right that `raise_crisis()` takes rather than offers (`field_director.gd:609-614`).
But `friendly_firebase_under_attack` (`_poll_firebase_threat`, `:626`) is ALREADY a
sim-generated crisis the player did not cause — VC walk onto the wire on their own. The
precedent is shipped. A fourth kind does not newly create a rail. The spirit is honored in
two ways: the call requires real contact, and the topo map gets NO special case for
`pinned_patrol` (UX architect) — one radio line, one identical hand-drawn circle. It cannot
read as a tracker.

**2. Devil's Advocate: "uncapped ally AI budget" — SUSTAINED.**
Verified: only `enemy_base.gd:582` claims a hot slot. `EnemySquad.HOT_CAP` budgets enemies
only; allies are outside it entirely. Mitigations: dormancy (140m), a hard 2x4 cap, and
`terrain_watchdog` now suspends non-squad allies at distance — the exemption at `:36` was
written for a squad that follows the player and is wrong for a patrol that does not.

**3. Devil's Advocate: "friendly kills credit the player" — REAL, PRE-EXISTING, NOT FIXED
HERE.** `mission_state.gd:14` `record_kill()` is attribution-blind and
`field_director.gd:54` fires it on ANY enemy death. The player's own 8 allies already do
this. Widening the attribution system is out of scope for this change and would touch the
debrief and ADR-006 scoring. Reported to the Summoner, not silently patched.

## Bugs corrected on contact (drift law)

- `enemy_base.gd:1217` `_local_force_ratio()` — the foes loop had no distance check while
  its own comment says "Local on purpose." Now matches the friends loop at 25m. Latent for
  the player's squad already; a 400m ambient patrol would have made it systemic.
- `terrain_watchdog.gd:36` — ally suspension exemption narrowed to squad members.

## What is sacrificed

- The `"allies"` group loses a single meaning. `AllyBase.squad_member` is now the
  discriminator, and a future call site will forget to ask.
- Dormancy means a distant friendly firefight is never heard — the AO sounds emptier than
  it is. `AmbientWar` already covers distant war audio, so this is a seam, not a hole.
- Two patrols means a seed where both die leaves the AO friendless. No respawn.
- A patrol that resolves its own fight before the player walks 400m leaves him arriving at
  corpses. That is the Fairness Law's price and it is deliberate.
