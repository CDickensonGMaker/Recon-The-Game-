# Update from the Summoner — 2026-07-15 (during Council)

The Summoner has exercised final authority (War Room Law 3) and provided the following clarifications, which override any assumptions in the original hand-off and the first-draft synthesis:

## The arena is the lens for final shipping
The AI Stress Arena is not a throwaway probe. What gets hammered down there reflects into the final campaign world. Work spent on the arena is work spent on the shipped firefight feel.

## Firefight length target is confirmed
Fights should be longer. The 3–5 minute target for the arena is correct because it matches the target mission engagement cadence. Duration should come from tactics and survival behavior, not bullet sponges.

## AI accuracy must be a tunable "Star Wars trooper" dial
- AI aiming should be deliberately inaccurate — stormtrooper-style — especially at range and on first contact.
- Volume of fire and exposure should be the real killers, not pinpoint accuracy.
- This must be exposed as a dial the Summoner can tune up and down until it feels right.
- The current AI zeroes in on the player too hard when the player is out of cover; this is too strong.

## Survival and breaking contact are the top AI priority
The AI loop must be survival-first. Both US and VC/NVA should:
- Break contact under pressure.
- Withdraw when outnumbered or taking heavy casualties.
- Value cover and self-preservation over kills.
- Use suppression to enable movement, not just to kill.

This is the GOAP combat architecture the Summoner laid out in the Combat AI Design Document (pasted into the session), and it aligns with the existing AI NORTH STAR bead (0623) and the AI GOAL DOCTRINE.

## Terrain must prove the LOS/hiding systems
- More terrain is not cosmetic — it is required to validate that the line-of-sight and hiding systems work.
- Soldiers entrenched or facing the wrong way should not magically detect a player sneaking on their flank (Hell Let Loose / real-life behavior).
- The arena needs terrain that declares "you can be seen here" vs. "you are hidden here."

## Design document authority
The Combat AI Design Document pasted into this session is now a canonical design input for the council. It describes:
- GOAP goal evaluation (survival, protection, mission, destroy)
- Friendly behaviors: bounding overwatch, suppression, flanking, communication, target marking, medic rescue, downed-player capture
- Enemy behaviors: ambush, hit-and-run, morale, squad roles, withdrawals
- VC vs. NVA doctrine differences

## Consequences for the decree
The original council synthesis correctly identified the `hp_multiplier` split and telemetry as prerequisites, but it under-weighted:
1. The AI accuracy dial.
2. Survival/break-contact tuning.
3. Terrain as a validation tool for LOS/flanking.

These now move up in priority. The balance work is not just about numbers — it is about making the AI fight like thinking soldiers who want to live.
