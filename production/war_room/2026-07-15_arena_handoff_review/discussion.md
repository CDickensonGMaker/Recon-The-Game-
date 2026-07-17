# War Room Discussion — AI Stress Arena Hand-off Review
**2026-07-15**

## Points of agreement
All architects confirm:
- The 7 problems listed in the hand-off are observable and worth addressing.
- A single `hp_multiplier` controlling AI-vs-AI balance, player feel, gib frequency, and fight duration is a systemic defect.
- Telemetry is a prerequisite for tuning (ADR-015, Verification Law).
- Any replacement of `hp_multiplier` must delete the old path (ADR-023, Fossil Law).
- The arena is a probe/dev tool, but the systems it exercises are core to the campaign.

## Points of contention

### Priority order
- **Game Designer / UX:** front-load player feel and model selection because Pillar 1 is the most urgent violation.
- **Systems Designer / Lead Programmer:** telemetry first, then model selection, then knob split; environment can parallelize.
- **Devil's Advocate:** challenge whether 3–5 minutes is the right target and whether arena work should happen before ida9 (PLAYTEST R3) is closed.
- **Technical Director:** environment changes carry navmesh risk and should not be rushed before telemetry/model fixes are proven.

### The `hp_multiplier` split
- **Systems Designer:** strongly supports the three-knob split as the cleanest separation of concerns.
- **Devil's Advocate:** warns that more knobs without telemetry is just more guesswork; also notes ADR-016 Amendment D may already reduce sponginess (M16 torso = 70 damage, not 56).
- **Lead Programmer:** supports the split if it is arena-local and the old export is removed.

### Environment vs. balance
- **Game Designer:** cover and vegetation are the *situation* Pillar 1 demands; without them, firefights are DPS races.
- **Devil's Advocate:** more cover may mask pathfinding/cover bugs instead of fixing them.
- **Technical Director:** agrees, and adds that new geometry must be in the `nav_source` group and verified with a headless probe.

### PLAYTEST R3 gate (ida9)
- The arena is not the campaign loop, so these fixes are probe/dev-tool work and do not require ida9 to be closed first.
- However, any change to `EnemyBase`, `AllyBase`, `DamageSystem`, or `SquadSystem` that could leak into the campaign must be guarded and verified against the campaign path as soon as ida9 is exercised.

## Resolutions reached
1. Telemetry is step 0. No tuning bead closes without it.
2. Accept the three-knob split, with the old `hp_multiplier` deleted, not deprecated.
3. Model selection is a small, safe first fix that improves Pillar 2/Atmosphere immediately.
4. Environment rebuild runs in parallel with the balance work but must be navmesh-proven.
5. Suppression and gib tuning come after telemetry is live, with measurements driving the numbers.
6. The 3–5 minute target stays as the working hypothesis; telemetry will validate or revise it.
7. The Summoner is asked to confirm whether the arena is a first-class deliverable or strictly a probe, because that affects how much environment art effort we spend here.

## Authority update from the Summoner (mid-council)

The Summoner provided additional direction that resolves the arena-deliverable question and reframes the work:

1. **The arena is the lens for the final shipping world.** Work spent here is not throwaway; it reflects directly into the campaign.
2. **Firefights should be longer.** The 3–5 minute target is confirmed correct, and duration should come from tactics and survival behavior, not HP bloat.
3. **AI accuracy must be a tunable "Star Wars trooper" dial.** Default to high inaccuracy; volume of fire and exposure are the killers, not aimbot precision. The dial must be exposed for live tuning.
4. **The player dies too fast when out of cover.** AI currently zeroes in too hard; flanking and sneaking should work like Hell Let Loose / real life.
5. **AI must prioritize survival and breaking contact.** Both sides should withdraw under pressure. This aligns with the existing AI NORTH STAR bead and the AI GOAL DOCTRINE, and with the Summoner's Combat AI Design Document (GOAP survival/combat architecture).
6. **Terrain must prove LOS/flanking/hiding.** More cover and vegetation are required to validate that the hiding and sight-line systems work.

## Revised debate after the update

- **Game Designer:** the update resolves the target question and elevates environment work from "cosmetic" to "system validation." Survival/break-contact is now co-equal with the HP/damage split.
- **Systems Designer:** the accuracy dial is a new, separate lever that must coexist with the HP/damage split. It should multiply into the existing `base_accuracy_modifier` chain rather than replace it, so archetype differences survive.
- **Technical Director:** the terrain rebuild is now justified as a validation tool, but the navmesh/performance risk remains. New geometry must still join `nav_source` and pass headless boot.
- **Devil's Advocate:** the Summoner's vision is clear, but implementing "stormtrooper aim + survival AI" could produce firefights that feel slow or inconclusive if not carefully tuned. Telemetry must distinguish "longer because tactical" from "longer because nobody can hit anything."

## Resolutions revised
1. Keep telemetry as step 0, but extend it to capture accuracy and break-contact events.
2. Add an AI accuracy tunable dial as a top-priority item, not a polish item.
3. Add survival/break-contact tuning as a top-priority item.
4. Treat environment rebuild as a system-validation task, not art polish.
5. The HP/damage knob split remains, but it is now one of several levers rather than the headline fix.
6. The end-to-end probe must show a 3–5 minute fight where both sides survive longer through cover, suppression, and withdrawal — not through sponginess.
