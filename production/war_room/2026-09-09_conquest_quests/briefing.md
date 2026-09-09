# BRIEFING — Vietnam quests carrying the comic, 2026-09-09

## The commission (Summoner, verbatim)
"once youve read the comic bible, lets start to come up with quests for the vietnam half of the game,
but keeping in mind the tie with ww1 at times too and lets try to create a symmetry to the experiences
that tells somewhat the same story the comic was or at least the same themes"

Follow-up, same night: **"make this story creation the top priority for this session right now"** and
**"as im going to go draw soon but i want to make this."**

## Sources read IN FULL before any design
- `production/CONQUEST_OF_WORMS_BIBLE.md` (468 lines) — what is on the page
- `production/CONQUEST_OF_WORMS_TREATMENT.md` — three continuations, seven beats
- `production/CONQUEST_OF_WORMS_AUTHOR_SYNOPSIS.md` — his verbatim spine
- ADR-038 (four camps), ADR-029 Amendment C (the patrol contract), ADR-041 (authored places)
- The dialogue grounding law, the quest quality law

## Binding constraints on every quest below
1. **ADR-029 §4 (probed):** waypoints never check off · no objective/quest tracking reaches the in-field
   HUD · command names FEATURES or ORDINALS, never pins · the route feeds only the one selector.
   **A quest may not be a checklist.**
2. **The quest quality law:** no errand quests. Every quest carries a THREAT (worsens if ignored) and a
   STORY (the giver's own reason).
3. **The dialogue grounding law:** every place, person, quest and event named in dialogue must resolve to
   a real game entity, or be an explicit LORE_ONLY whitelist entry.
4. **The horror rule (his, verbatim):** "any horror gore scene in the comic is supposed to be
   representative of the psychological state of the person expericing the vision." Every horror image has
   an OWNER. No world-state decay layer.
5. **ADR-038:** four camps — HQ, true believers, draftees/burnouts, black market. Four readings of one
   act, none of them the truth. Zero new UI. The world's own reading is WORDLESS.
6. **Pillar 3:** no rails, stealth is an economy never a gate. **Pillar 5:** fail forward.
7. **Solo player.** The post-demo pivot has the player alone, then a radio, then an RTO, then up to
   eight men. Design for the lone man.
8. **Post-demo-launch**, his own ruling. Nothing here touches the shipping demo.

## THE FAILURE MODE THIS COUNCIL EXISTS TO CATCH
Quests built to mirror a story become ILLUSTRATION — the player walks to where the theme happens and
watches it. **The theme must arrive as a choice, a consequence, or a thing the player does or fails to
do.** Anything that only works as prose is cut.
