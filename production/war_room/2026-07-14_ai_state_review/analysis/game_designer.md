# Game Designer — AI in Service of the Fantasy

## What the AI Currently Delivers

- **Vietnam jungle tension:** alert tiers, spider-hole ambush, last-known-position hunt, corpse discovery, tunnel retreat.
- **Unfair-but-readable enemies:** exposure ramp (first shots miss), suppression reactions, courage/determination stats.
- **Squad presence:** persistent 5-man fireteam with MOS roles, barks, medic revive.

## What Is Missing for the Fantasy

- **Allies do not feel like a fireteam.** They follow and shoot, but they do not bound forward, provide covering fire, call contacts, or react to suppression as a team. The scripted barks are good, but the behavior underneath is solo.
- **No AI memory beyond last-known pos.** Enemies do not communicate "player went left," they do not set ambushes at exfil, they do not react to dead friends beyond a single corpse check.
- **No stealth-vs-combat arc.** Alert tier exists, but missions rarely give the player a long enough "unseen" phase for it to matter.
- **No civilian AI state machine.** Civilians exist as models but have no behavior state (cower, flee, hands-up) — bead `RECONgame-jlo4` is open.

## Arena Relevance

The AI Combat Stress Test Arena is the right tool to prove the *enemy* state machine under controlled conditions. It should not try to test the full Vietnam fantasy; it should test whether each enemy goal/state behaves believably when exposed.
