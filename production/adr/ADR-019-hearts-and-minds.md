# ADR-019: Hearts & Minds — village allegiance drives VC manpower. The war is the story.
**Date:** 2026-07-12 · **Status:** Accepted (Summoner decree, THE LIVING WAR) · **Amends:** ADR-006 (the province ledger now outranks the mission score) · **Depends on:** ADR-017 (the province must persist for any of this to exist)

## Context

The Summoner's design constraint for the entire project is one sentence: **"the war is the story."** He
explicitly rejected written plot — *"i dont wanna make a fake cheesy storyline driven game like the ps2 call
of duty games or men of valor (even tho its a strong influence it kinda has a cheesy dumb story line)."*

He then, unprompted, described the mechanism that makes that possible:

> *"maybe one day you just wanna burn down the village down the road from you. but that'll make the locals
> hate you more and they will help the vc even more and they will attack you when you go down on patrol."*

That is not a side system. **That is the entire answer to "the war is the story"** — moral weight and
consequence with no cutscene, no dialogue tree, and no writer.

It also solves a structural problem ADR-017 creates. If destruction in a persistent province is permanent,
the player sterilizes the map: thirty hours in, every base is blown and the war ends with a whimper.
Seek-and-destroy degrades into a checklist — precisely the treadmill this design exists to avoid.

## Decision

### 1 · Destruction is TEMPORARY. Attrition is PERMANENT.

- **Bases, bunkers, caches, tunnel mouths REBUILD** — in a week they are back, or moved somewhere worse for
  you. The VC are a living organization, not a set of loot piles.
- **Men do not.** Each district draws from a **finite regional manpower pool**, and every VC killed comes out
  of it. (The finite-pool principle already exists for QRF, GAME_GUIDE §4.2 — this generalizes it.)

**The win condition of a province is therefore NOT "all bases destroyed." It is: their strength is broken
AND the districts do not hate you.**

### 2 · THE EQUATION

Every village carries an **allegiance** value in the province ledger. Player conduct moves it:

| Moves it toward HOSTILE | Moves it toward COOPERATIVE |
|---|---|
| Burning the village | Killing the VC tax collector / breaking a VC extortion visit |
| Killing civilians (including careless artillery and airstrikes) | Running a medcap; delivering supply |
| Destroying homes and livestock in a raid | Fire discipline near the ville; leaving it standing |
| Detaining/executing suspects | Protecting it from a VC night raid |

Allegiance drives the district's behavior — trap density on its trails, ambush frequency, whether *you* get
a warning before you walk into a wire, whether informers exist to sell you out, whether the VC get free
intel on your firebase. **And above all:**

> ## **VC manpower regenerates at a rate set by how the districts feel about you.**

### 3 · THE FAST ROAD MUST GENUINELY WORK (binding law)

**Burning the village must be the right call sometimes.** It must *actually* pay, immediately and
legibly: the sniping stops, the VC lose a base, you are home before dark, and the mission is *over*.

If it is always the wrong answer, it is a morality meter with a correct choice — **which is exactly the
cheesy PS2 thing the Summoner rejected, and it would kill the tone of the entire game.** *Platoon* is not
"don't burn villages." It is about how **easy** it is to, and what it costs you later.

The cost comes later, and it comes **quietly**: that district's recruitment rises. The body count you rack
up is replaced faster than you can generate it, and the war grinds against you in a way you can *feel* and
cannot immediately explain.

**This is the actual strategic failure of the American war in 1966–68, rebuilt as a game loop — and the
player discovers it himself, by doing it, with nobody ever telling him he is the bad guy.**

Body count is a strategy in this game. It is just a losing one, if you take the shortcut to get it.

### 4 · Allegiance is FELT, not read.

**There is no hearts-and-minds meter in the HUD.** (This is a deliberate, narrow exception to the r4bk law
— see Consequences.) The player reads the province through the world:
- the ville that used to wave and now goes silent and indoors when you walk in
- trails that used to be clean and are now wired
- the ambush that was waiting where nobody should have known you were going
- your point man saying he doesn't like this place

An **intel/after-action summary at the debrief and at the HQ board** may state district *sentiment* in
plain language ("THE DISTRICT IS HOSTILE. EXPECT CONTACT.") — that is a briefing, which is diegetic. **A
live numeric meter is forbidden**, because the moment allegiance is a number, the player optimizes it and
the moral weight evaporates.

### 5 · Scoring

ADR-006 stands: **+25 contact avoided, −25 detected, kills pay ZERO.** But it is now demoted — **the mission
score is a receipt; the province ledger is the game.** Kills no longer merely fail to pay: via §2 they can
actively *cost* you, on a delay, through the district that watched you make them.

**STATUS NOTE (binding honesty, added 2026-08-07):** NOT implemented. No allegiance value, sentiment
ledger, conduct tracking, or district manpower pool exists in code — `scripts/world/civilian.gd:718-722`
records the deferral in so many words ("ADR-019's sentiment ledger does not exist and is deferred
... sentiment moves in words, never as a number"). Deferred to the post-launch open-patrol world per
the Summoner's EA scope ruling of 2026-08-06 (EA ships the demo's shape). This record is the law the
code will be brought to, not a description of the code.

## Consequences

**Bought:** *Platoon*'s moral weight with zero written plot — the thing the Summoner most wants and the
thing no other Vietnam shooter has built. A province that cannot be sterilized into a checklist. A reason
for civilians to exist mechanically (the Summoner is modeling them now — beads zbmi/jlo4). A campaign that
"remembers" in a way the player can feel rather than read in a stats screen. And a genuine, unforced answer
to "why not just kill everything," that never once lectures.

**Sacrificed (no free lunches):**
- **This is a systems-design tarpit** if allegiance becomes a number the player optimizes. Guarding that
  means *withholding information*, which is user-hostile in every other genre and is the correct call here.
  It will feel wrong to build. Build it anyway.
- **A deliberate, narrow r4bk violation** (a load-bearing system with no HUD affordance). Accepted **only**
  because the affordance is the world itself, and because a meter would destroy the system's entire point.
  **If the player cannot feel it through the world within one playtest, the presentation has failed** — and
  the fix is *more world*, never a meter.
- **Delayed consequence is hard to learn from and easy to experience as unfairness.** A player who burns
  three villes in hour two and gets mauled in hour nine may simply conclude the game is broken. The debrief
  and HQ-board *briefing language* is the only sanctioned mitigation, and it is deliberately thin.
- **It doubles down on civilians**, which are art-blocked (bead zbmi) and behaviorally unspecified (jlo4).
- **Rebuilding bases means the player's work is undone**, which some players read as a treadmill. The
  counter is that *attrition is permanent* and must be legible in the briefing — the pool is going down, and
  he must be able to see that it is.

**Work created:** allegiance in `ProvinceState` · conduct-tracking (arson, civilian casualties, medcap,
tax-collector interdiction) · district manpower pool + regeneration tied to allegiance · base/cache rebuild
+ relocation · allegiance-driven trap/ambush/informer density · briefing + debrief sentiment language ·
civilian behavior (jlo4). Beaded under the LIVING WAR epic.

## Evidence

- Summoner deep-dive, 2026-07-12 (verbatim above); decree at `production/war_room/synthesis_living_war.md` §3–4
- `production/GAME_GUIDE.md` §4.2 — the **finite** QRF manpower pool (the principle this generalizes);
  "Civilians inform on a timer"
- **ADR-006** — avoidance pays, kills pay zero (shipped 2026-07-12 in `scripts/ui/screens/debrief.gd`)
- **ADR-017** — the province ledger this lives in
- Beads: **zbmi** (civilians: engine wiring), **jlo4** (civilian threat response — what triggers hands_up
  vs cower vs flee: *the Summoner's own open question, now load-bearing*)

## Related

- **ADR-017** (persistent province) — hard dependency; this is the ledger's most important column
- **ADR-006** (scoring) — survives, demoted: the score is a receipt, the province is the game
- **ADR-005** (witness rule) — allegiance's near neighbor: who saw you, and who tells
- **ADR-020** (authored threshold) — the first patrol must *teach* that the villagers are people
- Pillars served: **5. Fail forward** (the war mutates from what you did), **2. Atmosphere** (moral weight),
  **3. Freedom** (burning it down is a real, viable, respected choice)
