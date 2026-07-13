# ADR-022: The map is the player's memory — he marks it, and he is allowed to be wrong
**Date:** 2026-07-12 · **Status:** Accepted (Summoner decree, THE LIVING WAR) · **Depends on:** ADR-021 (the intel a patrol earns), ADR-017 (the ledger it persists in) · **Serves:** ADR-006 (avoidance pays — this is what it buys)

## Context

> *"we need to be able to annotate our map and write markers like 'heavy enemy presence in this area' or
> ways to help plan where you wanna ambush."* — Summoner, 2026-07-12

ADR-021 gave the quiet patrol an economy: **you learn the ground.** It did not give the player anywhere to
*put* what he learned. Right now that knowledge lives in his head and dies when he closes the game.

The canon already forbids the easy answer. `VISION_READOUT`: *"The map is a **topo sheet, not a minimap**."*
And Pillar 3 forbids rails. So the map cannot become a quest log with objective pins, and it cannot become a
fog-of-war overlay that fills itself in.

## Decision

> ## **THE GAME MARKS WHAT YOU SAW. YOU MARK WHAT YOU THINK.**

Two layers on one topo sheet, visually unmistakable from each other.

### 1 · OBSERVED — printed, precise, the game's hand
Facts the player **personally witnessed**, stamped automatically. This is not cheating and it is not a
minimap: you *saw* it, and a real man would have marked it.

- where you actually saw an enemy, and when (it goes **stale**, and it *looks* stale)
- a patrol node you watched them use (ADR-021)
- sign you found and stopped to read: a cold cookfire, a cache, a wired trail
- a body you left behind (and it is a **liability** — see the witness rule)
- villages, and roughly how they looked at you (ADR-019 — *sentiment in words, never a number*)

**Observed marks decay.** A contact three days old is a rumour, and the sheet says so. Intel is a
perishable good; that is the engine that keeps you patrolling.

### 2 · ANNOTATED — grease pencil, scrawled, the player's hand
Free markers and **free text**, placed by the player, persisted in the province ledger forever.

- a note: *"HEAVY PRESENCE"*, *"they always stop here"*, *"do not use this trail"*
- an **AMBUSH** mark: this is where I will kill them
- danger, rally, cache, avoid — a small vocabulary, plus words

> ### **THE GREASE-PENCIL LAW (binding)**
> **The player's own marks may be WRONG, and the game will NEVER correct them.**
>
> No validation. No auto-erase when a belief turns out false. No "(outdated)" tag. If he writes HEAVY
> PRESENCE on an empty valley, that note sits there being wrong until *he* walks back out and changes it.
>
> **The moment the map corrects him, it stops being a map and becomes a quest log.** Being wrong on paper,
> and finding out the hard way, is not a bug in the fantasy — **it is the fantasy.**

### 3 · The ambush mark is a PLAN, not a command
Marking a spot AMBUSH does not order anything. It is a note to yourself. (Ordering the squad into position
is the existing squad-order verb set, ADR-012, and stays separate.) A map that executes is a rail.

### 4 · What the squad may and may not do
The point man may **volunteer** what he reads — *"trail's been used, few days back"* — as a bark. That is
his MOS (ADR-018: a veteran point man is the one who notices). **He never marks the map for you.** The pencil
is yours.

## Consequences

**Bought:** the compounding knowledge loop that makes a long campaign feel like *your* campaign. The map
becomes the single most valuable object you own — a thing you built by walking, and the reason a mission with
no contact was still worth the evening. It also gives ADR-006's "+25 for a contact avoided" something to
*mean*: you avoided them, you watched them, you wrote down where they go, and next week you kill them there.
**This is the artifact that ties patrolling, stealth scoring, the hunt, and hearts-and-minds into one loop.**

**Sacrificed (no free lunches):**
- **A wrong map is a bad feeling, and some players will read it as a bug.** ("The game didn't tell me they
  moved!") That is the design working. It will still generate complaints, and we will not fix it.
- **Free text is a content-moderation and localisation surface** if this ever ships with any sharing feature.
  It won't at launch. Note it here so nobody is surprised later.
- **Two visual layers on one sheet is a real UI problem**, not a small one. If observed and annotated are not
  instantly distinguishable at a glance, the whole law collapses into mush.
- **Marker vocabulary will want to grow.** It must stay small. A map with thirty icon types is a spreadsheet.
- **This is a HUD feature and therefore r4bk-load-bearing:** the map has to be *good*, or the intel economy
  it serves is invisible and ADR-021's quiet patrol goes back to being a wasted evening.

**Work created:** topo-sheet map screen (exists as a stub) · the two mark layers + decay on OBSERVED · free
text entry · persistence in `ProvinceState` (ADR-017) · sign-reading as a world interaction · the point man's
trail barks. Beaded under the LIVING WAR epic (LW-11).

## Evidence

- Summoner, 2026-07-12 (verbatim above)
- `production/VISION_READOUT.md` — *"The map is a topo sheet, not a minimap."* · *"UI is diegetic-first"*
- **ADR-021** — the quiet patrol pays in ground; this is where the ground is kept
- **ADR-006** — +25/contact avoided, kills pay zero (shipped `debrief.gd`)
- **ADR-019** — village sentiment is stated in words, never as a meter; the same law governs the map

## Related

- **ADR-021** (patrols) — the routes you are trying to learn, and which rotate when you burn them
- **ADR-017** (province) — the ledger the pencil marks live in, forever
- **ADR-020** (authored threshold) — a map that executes is a rail; this one only remembers
- **ADR-012** (input doctrine) — the ambush mark is a note; orders stay on the order keys
- Pillars served: **3. Freedom** (plan your own war on paper), **5. Fail forward** (a wrong note is a story),
  **2. Atmosphere** (a grease-pencilled topo sheet is the most Vietnam object in the game)
