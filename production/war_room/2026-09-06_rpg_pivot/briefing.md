# WAR ROOM BRIEFING — 2026-09-06 · THE RPG PIVOT

**Convened by:** the Summoner (Caleb), in a long working conversation, 2026-09-06 — his own EA target date.
**Arbiter:** the Overseer/Director.
**Class:** PILLAR-LEVEL. Reframes the project's identity. Convened BEFORE any build, per charter §8.
**Standing:** RECORD AS CANON. Build authority this session is deliberately narrow (§5 below).

---

## 1 · The trigger

The Summoner saw an AI-generated "Skyrim in Vietnam" video and it crystallised a reframe he had been
circling for two months. His framing:

> RECONgame is an **RPG / STALKER-in-Vietnam**, not a firebase sim. NPCs give you problems. You live
> in a whole Vietnam world rather than being a soldier on one patrol at a time. **No fantasy elements.**

*Apocalypse Now* is his favourite film and the tonal target.

## 2 · What he decided (thirteen items, his words condensed)

1. **The firebase IS home.** Answered directly, no hedge.
2. **Four factions inside the wire, a la *Platoon*:** HQ (must be kept happy) · the black-market gang ·
   the straight-laced anti-communist true believers · the draftees and burnouts who don't want to be
   there and who push you toward the black market.
3. **The 1960s racial element** — present because it is historically true (the racist bunch, the soul
   brothers, the burnouts and junkies of Vietnam media). He is explicit that he does not think he is
   the writer to handle it as a *plot* and does not want it done badly. **Agreed approach: social
   geography, never storyline** — *Platoon*'s two-hooch structure. It lives in who sits where, what is
   on the radio, whose hooch you are welcome in, the dap, small refusals. Rules held: no slurs as
   ambient flavour · individuals are never representatives · **the player is NEVER the arbiter** (no
   "fix the racism" quest, no Tolerant/Bigot dialogue options) · let the **DRAFT** carry the class and
   race truth (who got sent versus who got a deferment). **Presence without plot.**
4. **Hearts & Minds stays and is the SENIOR system** — the world-state dial, the thing he felt Skyrim
   lacked. ADR-019 already amends ADR-006 to make the province ledger outrank the mission score, so
   this is already law and needs no new decree.
5. **THE KEY SYNTHESIS — factions are the READOUT for Hearts & Minds.** The world stays subtle; the men
   at the firebase are how the player HEARS what the province thinks of him ("the villes down south
   won't talk to anyone since you came through"). One action gets four different readings — world, HQ,
   true believers, draftees, black market. This couples two systems into one loop with **zero new UI**
   and is the proposed answer to ADR-019's own named risk: invisible bookkeeping felt as unfairness.
6. **The ADR-006 mission score is RETIRED.** Demoted by ADR-019, stripped of visible numbers by
   ADR-032, and its screen deleted by ADR-029. Its moral survives by relocating: fire discipline near a
   ville **is** allegiance; body count becomes **HQ's opinion**, not a law of the universe.
7. **Contraband becomes the reward currency** instead of points (Overseer's proposal; he did not object).
8. **Map to 2km per side** — inside ADR-013's existing "less-than-or-equal-2km loads whole" policy.
   **POST-DEMO.** With the insight that a persistent province pays the world load ONCE per session,
   not per patrol.
9. **ZONES, NOT STREAMING.** STALKER is ~10 zones with loading screens, not one seamless map. Separate
   areas (Huey assaults, operations, staged areas) are how the game feels larger — and chunk streaming
   **never has to be written**, dodging the Catacombs bug class entirely. Two lines the Arbiter attached:
   **(a) one builder, many places** — a new outdoor AO is the same world-build path with a different
   seed/config (legal under ADR-028; exactly what the arena is); interiors and tunnels are authored
   scenes; a hand-wired bespoke area is FORBIDDEN and must fail the structural probe.
   **(b) You BOARD the Huey, you don't SELECT it** — the bird is a place on the pad with a crew chief,
   not a mission menu. This is what keeps ADR-029 intact and stops the briefing/mission-select loop he
   killed in July from re-growing.
10. **Save anywhere** — POST-DEMO, and the big technical bill (ADR-007 + ADR-010 rewrite; the living
    world must serialise).
11. **Tunnels as dungeons** — TUNNEL is already one of the six nouns in the field-marking vocabulary,
    so the loop is: find a hole on patrol, mark it, come back kitted for it, go down.
12. **Player durability.** He asked for a more durable, less instantly-dead player. **The Arbiter pushed
    back** — it breaches Pillar 1 (never bullet sponges) and reverses his own 2026-08-04 lethality
    ruling. Resolved instead as: (a) save-anywhere removes most of the pain · (b) **extend the DOWN
    state, not the health pool** — a survivable, tense downed/crawl/medic-under-fire state, which
    strengthens Pillar 4 instead of weakening Pillar 1 · (c) verify the Fairness Law's "first shot at
    an unaware player is a near-miss" is actually firing · (d) turn up the muzzle flash. Headshot law
    untouched. **He accepted this.**
13. **Apocalypse Now: steal the STRUCTURE, not the story.** No river-journey-to-a-mad-colonel — that is
    *Heart of Darkness* and reads as a rip. What is stealable: **the descent as a chain of
    self-contained vignette LOCATIONS**, each further out and less commanded, authority dissolving with
    distance. Do Lung Bridge ("Who's the commanding officer here?" "Ain't you?") is the model — **a
    PLACE that says everything, not a cutscene.**

## 3 · THE SCOPE WALL (the binding constraint on this whole session)

He ended with: **"but the demo scope is still the overall goal."**

The 2026-08-06 EA ruling stands. EA ships **the demo's shape** — one firebase, one day, ~30 real
minutes, 512m, `plan_demo_world` — because it is the only part of the game ever playtested to a
verdict, while PLAYTEST R4 has been open in 30 documents and discharged in none.

**Therefore items 8, 9, 10, 11 and 12b are RECORD AS CANON, BUILD NOTHING.** They are written down
precisely so they stop competing with shipping.

## 4 · The one new demo-scoped design (his final message, verbatim)

> *"maybe to fill the demo up with things to do, we do have the factions element and theres two quests
> you do, and if timed right itll be dark sooner or later when they come back from those quests and the
> firebase attack happens. that sounds like a fun demo."*

The demo shape becomes: **factions present as dressing → two quests out the wire → timed so the player
returns at dusk → night stand-to → the firebase attack.**

It must ride the EXISTING arc clock and the EXISTING 512m world. The council judges hard whether two
quests fit inside demo scope without re-growing the briefing/mission-select loop ADR-029 killed. They
must be **PEOPLE at the firebase pointing at LANDMARKS**, never pins that check off. The four §4
clauses of ADR-029 Amendment C bind.

## 5 · Build authority this session

| Allowed | Forbidden |
|---|---|
| ADRs, amendments, the decree record | Any code for items 8-13 |
| The demo two-quest plan — **priced, not built** | Building the two quests |
| The playtest defect status table, with evidence | Touching `scripts/combat/gun_fx.gd` (the Summoner is editing the muzzle flash in parallel) |

## 6 · Also on the table — his real work item

> *"right now to get that more real, we need to make sure the last long list of things i mentioned from
> my playtest has been fixed."*

The 2026-08-28 list, 35 items. A status table with file:line evidence, probe-before-claim, is the
demo's real gate alongside his siege playtest. **This outranks the decree in urgency and the council
is told so.**

## 7 · Council summoned

| Architect | Lens |
|---|---|
| Game designer + Writer | the two quests · faction dressing · the racial element as craft · the readout lines · the vignette places |
| Systems designer | the H&M/faction coupling as a system · retiring ADR-006 without breaking rank · contraband · the down state · **the Fairness-Law near-miss probe** |
| Technical director | 2km arithmetic · zones as an enforceable contract · board-don't-select on existing machinery · the save-anywhere bill · tunnels · **the gating FPS sentence** |
| Devil's advocate | the fourth-pivot risk · how the scope wall leaks · the two-quest timing attack · quest-givers as the offer board in a hat · factions-as-readout as a meter with extra steps · the racial element's cut case |

## 8 · Standing facts the council was given (measured, not remembered)

- **The arc**, `scripts/levels/demo_game.gd`: `START_HOUR` 6.5 · `DAY_RATIO` 38x · night at ~1184s real
  · `PROBE_AT_S` 1395 · `SIEGE_AT_S` 1440 · `END_BACKSTOP_S` 2700 (a backstop only — the raid ends the
  demo, his 2026-08-07 ruling; the dawn card is dead).
  **This corrects the "probe@600 / siege@720 / dawn card@1080" numbers still in circulation.**
- **The geography**, `mission_generator.gd` `plan_demo_world`: firebase dead centre of 512m · one
  village ~185m on one flank · one temple ~170m on the opposite flank · up to three jungle ruins at
  140-175m on other bearings · one enemy camp · paddies, roads, craters. Every temple and ruin already
  carries an `[F] SEARCH THE SHRINE` verb.
- **The sweep machinery already exists and already finishes in the field** — `field_director.gd`
  `_poll_sweep` / `_finish_sweep` / `_set_patrol_location`. Six offers the next place by bearing and
  distance with "OR BRING THEM IN. YOUR CALL." No pin, nothing ticks off, walking home is legal.
