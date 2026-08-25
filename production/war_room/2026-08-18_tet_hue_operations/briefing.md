# WAR ROOM BRIEFING — Tet Offensive / Hue City grounding + Operations design space

**Summoned:** 2026-08-18, by the Summoner directly.
**Query (his words):** "i think we should land it inside the idea of the TET OFFENSIVE and
HUE City. so we are a firebase close to those major hotspots. and i think theres a openworld
flow of patrols but we should make some real operations that the player goes on too where
they ride in a helicoptor and go to other fights. We could have combat from 1968 involved
in this. lets talk about all of the options we could do."
**Scope (his clarification):** post-DEMO-launch roadmap work — "but i think itll help shape
the game better." This is direction-shaping, not EA-scope work.

## Binding canon (architects: do not re-litigate, design WITHIN or name the amendment)

1. **Rule One:** the game must be FUN Vietnam first (Pillar).
2. **Operations decree 2026-07-28 (ruled):** OPERATIONS exist alongside the patrol loop —
   larger set-piece battles, diegetically assigned (radio/RTO, never a briefing screen),
   player is a man inside the battle, not the hero. Each operation generates its own small
   random world map. Reuses the siege's assault-and-hold shape (SiegeDirector+MarchingCell).
   His named types: helicopter assault on a large enemy camp · hold an LZ ~20min while
   reinforcements build it · secure zones while a firebase is erected · seek-and-destroy.
   City fighting is IN (modular buildings proven; cost is AI/navmesh indoors, not art).
   He rejected one-shot quick battles — persistent squad/rank/campaign state must carry.
3. **⚠ CANON TENSION — the crux of this session:** the same decree ruled "fictional unit,
   not historical re-enactment — the Hue *character* without the real dates, units or
   dead — protects the seeded-tour premise." Today's ask (Tet, Hue, 1968) leans historical.
   Every architect must take a position on the fiction↔history dial.
4. **Open-sim pivot 2026-07-17:** north star = "i just wanna leave the camp and go find
   problems." No briefing screens, no player-facing mission tracking. Operations must be
   ENCOUNTERED/assigned diegetically, never menu'd. World foundation (one WorldBuilder,
   ADR-028) is LOCKED — improve, never rebuild; ops maps are generated worlds, a parallel
   world system is off the table.
5. **ADR-029 says PATROL is the only mission type** — operations require a knowing ADR
   amendment (already flagged in the 7/28 decree).
6. **EA ruling 2026-08-06:** EA = the demo's shape (one firebase, one day, 30 min). All of
   this is ROADMAP. Nothing here may pull effort from the ship list.
7. Name stays RECON (do not re-open). Fear doctrine/lethality, casualty ledger scoreboard,
   period HUD, faction stature — all standing.

## Summoner's structural refinement (mid-summons, 2026-08-18 — this is the architecture)

"its a mix of a open world firebase sim experience that uses the seed map generator for
each player as a random area and than more focused consistant maps well hand craft for
these operations."

So: **home AO = seeded/random per player (the existing WorldBuilder path). Operations =
HAND-CRAFTED, CONSISTENT maps, shared by all players.** Note this consciously amends the
7/28 decree's "each operation generates its own small random world map" — handcrafted
replaces random for ops. Architects: treat hand-crafted op maps as the Summoner's stated
direction and design for it; the Devil's Advocate should still name what the random-map
alternative bought us and what handcrafting costs.

**Tone reference (his words, same summons):** "its a vibe of call of duty meets battlefield
meets Men of Valor meets Hell Let Loose feeling." Read that as: COD's staged operation
set-piece intensity · Battlefield's scale/vehicles/combined-arms chaos · Men of Valor's
Vietnam squad narrative grounding · Hell Let Loose's grim milsim weight and being one man
in a big fight. Architects should design toward that blend, filtered through our PSX look,
fear doctrine, and "a man inside the battle, not the hero."

## What the Summoner wants from this session

ALL the options, laid out for a talk — not a single recommendation. Breadth first:
setting/fiction options, operation-type menus, helicopter ride-along structure, how Tet
as an event could hit a living campaign, 1968-flavor combat content, what Hue-adjacent
city fighting could look like at our scale. Tradeoffs named per the Laws.
