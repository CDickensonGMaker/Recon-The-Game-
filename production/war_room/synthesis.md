# SYNTHESIS — the replacement economy (2026-08-28)

**Query (Summoner):** *"On patrol everyone but 2 other guys died. How does the player get more units back?"*
**Council:** game-designer · systems-designer · devil's-advocate (analyses in `analysis/`).
**Status: NOTHING BUILT. Awaiting the Summoner's ruling.** This is pillar-touching (4 and 5) and is his call.

## What all three converged on, independently

1. **`SquadRoster.ensure_roster()` (`squad_roster.gd:165`) is not an economy — it is a save-migration
   shim with a refill loop bolted on.** Its `:187-200` block back-fills `skill_uses`/`xp`/`skills`/
   `face`/`helmet` onto older saves and guarantees `setup()` receives a well-formed POINTMAN, RTO and
   MEDIC. Any replacement design must keep that job and delete only the fill loops at `:177-183`.
2. **The barracks screen manufactures men on a repaint.** `barracks.gd:50` calls `ensure_roster()`
   from `_refresh()` and the call ends in `save_campaign()`. A UI paint is a content-generation event
   that writes to disk. This is a defect on any reading, whatever is ruled.
3. **Replacement generation is non-deterministic today (ADR-010).** The two call sites feed different
   seeds — field `director.state.seed_value + 12345`, barracks `missions_played + 1` — and
   `state.seed_value` is reassigned to the ephemeral `patrol_count` at `field_director.gd:1845`.
   *Which men you get depends on which screen you opened.* That is also the save-scum door.
4. **The player is never told.** Deaths bank correctly into `kia_total` / `bags_unlifted` /
   `ward_wounded` (`campaign_state.gd:256-277`) and **none of the four numbers is displayed anywhere.**
   Arrivals are silent. This is what he actually felt.

## The devil's advocate's finding, which the Arbiter accepts and which reframes the whole matter

`ensure_roster()` **does not run during a mission** — `squad_system.gd:70` fires once inside `setup()`.
Nobody was regenerated on 8/27; he finished that day with two men, which is already the right feeling.
And `demo_game.gd` resets the campaign at boot behind `EXCLUDE_SAVES`, so **the shipping build has no
"between excursions" at all.** A replacement economy built today would have zero live consumers in the
product that ships — a deliberate fossil under ADR-023.

**Therefore: this is a decision about the post-launch campaign loop, not about the run he played.**

## Decree (advisory — the Summoner rules)

**The ledger ships; the economy waits.** Name the dead and name the arrivals, at the wire and on the
roster board, using the four counters that already exist. It answers his literal question — the game
never told him — it is precondition 4 for any future economy, and it cannot make the demo unwinnable.

**The economy is gated on the AI.** Charging the player for casualties is only fair once the squad
stops causing them: findings #8 (squad fires inside the wire at nothing), #28 (does not crouch, stands
on top of the player), #33 (no friendly-fire warning), #4/#6/#22 (men lost to geometry). A cost levied
before those close teaches save-scumming — the exact failure Pillar 5 forbids — and charges the player
for our defects.

**When it does ship: the replacement bird, with a hard floor.** It reuses `heli_lift.gd`, which already
lands garrison replacements and whose own header states the intent. The floor is the design decision;
the arrival rate is only pacing. Robbing the garrison is the right campaign layer on top, and only once
the siege provably reads garrison strength.

## What is sacrificed (no free lunches)

- **Shipping the ledger alone leaves loss costless at the campaign layer** for another release. The
  player is *informed* of a consequence he does not *suffer*. A real Pillar 4 hole, left open on purpose.
- **Naming the arrivals makes the treadmill more visible, not less.** Correct trade; not a free one.
- **When the economy does ship, there will be an hour where the player is short-handed and cannot fix
  it.** That hour is the product. If the Summoner does not want that hour, the answer is no economy at
  all — never a faster cadence, which is the vending machine with a delay and will read as one.
