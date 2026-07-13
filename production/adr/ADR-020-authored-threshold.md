# ADR-020: The Authored Threshold — guarantees, not rails. And the Ambience Law.
**Date:** 2026-07-12 · **Status:** Accepted (Summoner decree, THE LIVING WAR) · **Interprets:** Pillar 3 ("Nothing is on rails. Ever.") against the Summoner's demand for an authored opening · **Governs:** the living firebase, world set-pieces, the first patrol

## Context

Two Summoner requests from the 2026-07-12 deep-dive appear to contradict Pillar 3 and each other:

**(A) The living firebase.**
> *"the firebase is the living home base that lives on its own 24/7 schedule of soldiers coming back from
> their own patrols, units waking up, going to eat food, guard shift switches, supply logistics coming in
> and dropping stuff off. and than sometimes a vc suicide attack, or a night raid by the enemy. you can be
> there or not but these things happen."*

**(B) The authored opening.**
> *"its also key that the first time the players step out the wire there has to be some cool things that
> happen 'scripted' that will make them want to come back and see what else is going on out beyond the wire."*

**(B) collides with Pillar 3** ("*objectives are places/things in the world; any route, any order… Nothing is
on rails. Ever.*") and with the Summoner's own rejection of Men of Valor's scripted storyline.

**(A) collides with the Summoner's own diagnosis of the failure case.** Of the rival "Vietnam War" sandbox
game he said: *"it felt too much like battlefield where there is constant combat and chaos everywhere but
you're not really the main character."* **If every ambient event is always firing, we have built exactly
that game.** Willard and the *Platoon* recruit do not work because a lot is happening. They work because
almost nothing happens — and then something unbearable does.

Both are resolvable. They resolve into the same curve.

## Decision

### 1 · THE RAIL/GUARANTEE DISTINCTION (the governing law)

> ## **A RAIL TAKES THE CONTROLS AWAY. A GUARANTEE DOES NOT.**

The first patrol is **not scripted. It is AUTHORED-DENSE** — the same procedural generator, run with a
**weighting pass** that guarantees a set of encounters within ~400m of the wire. Nobody takes the stick.
Nothing forces an outcome. The player is merely **promised** that walking out that gate is the most
interesting twenty minutes he has had.

**In a purely random world, the first patrol can be forty minutes of empty green — and that is how you lose
a player forever.** The guarantee exists to prevent that, and for no other reason.

### 2 · THE FIRST-PATROL GUARANTEE

Each beat teaches a system **by being lived**, never by a tutorial popup. Placement is procedural; existence
is guaranteed.

| The moment | What it teaches |
|---|---|
| Fresh trail sign; the point man stops and calls it | *your point man is your eyes — listen to him* |
| A trip wire he catches **before** you walk into it | *the jungle kills you, and this man just saved your life* |
| A VC patrol you can sit still and let walk past | *contact is optional, and the +25 is real* (ADR-006) |
| A villager who is a person, not a target | *the people are the war* (ADR-019) |
| A burned hut, a rotting ARVN body | *this war was here before you* |
| A firefight you HEAR and never reach | *the war is bigger than you, and you cannot fix it* |
| One gorgeous thing — a squall rolling in, Hueys crossing the treeline | *come back out here* |

Every one of these is **refusable**. Walk past the trail sign. Shoot the patrol instead of letting it pass.
Ignore the firefight (you must — you can never reach it). **The player may fail, skip, or spoil any beat,
and the game says nothing.**

### 3 · SET-PIECES ARE **WORLD** EVENTS, NEVER **PLAYER** EVENTS

> **Willard does not fly the Ride of the Valkyries. He watches it from a boat.**

**The player is a WITNESS, never a puppet.**

> ### **BINDING TEST — apply to every proposed set-piece:**
> **Can the player turn around and LEAVE, right now, without the game stopping him or punishing him?**
> **If no, it is a rail, and it is forbidden.**

**Note precisely what the test asks. It asks whether he can LEAVE. It does not ask whether he can REACH.**
Those are different questions, and the answer to the second one is *"sometimes, and deliberately not."*

#### The three classes of world event

Summoner, 2026-07-12: *"i do want to have the player come across other larger battles from time to time
while they are out and about… not just all big battles are staged… somethings yes should be caged from us…
that makes the distance seem larger."*

| Class | Examples | Can he reach it? | **Its job** |
|---|---|---|---|
| **THE HORIZON** (caged, on purpose) | Arc Light rolling along a far ridge · napalm three klicks out · a firefight across a river he cannot cross · fast movers going somewhere else | **No — and that is the point** | **SCALE.** The war is bigger than the AO and always will be. |
| **THE DOOR** (reachable, joinable) | Another US patrol in contact · an ARVN outpost being overrun · a VC company moving through a valley | **Yes. Join it, avoid it, or watch it and walk on.** | **AGENCY.** The war has doors in it, and walking through one is *his* choice, not ours. |
| **THE PASSER-BY** (neither) | Slicks crossing the treeline · a medevac lifting off with a screaming man aboard · a column of smoke | n/a | **TEXTURE.** |

#### 3.1 UNREACHABILITY IS HOW YOU MANUFACTURE SCALE

> **If the player can walk to everything, the world is exactly as big as the map.**

The Arc Light he can **never** reach is what tells him the war continues past the edge of what he is
allowed to touch. It is the same instrument as a mountain painted on a skybox, and it is the reason
*Apocalypse Now* feels enormous while taking place on one boat. **The cage is not a limitation we tolerate.
It is the tool that makes the distance real.** We build horizon events *deliberately* and we do not
apologize for them.

#### 3.2 THE CAGE MUST BE GEOGRAPHY, NEVER AN INVISIBLE WALL — and it must be READABLE

**LAW:** a horizon event is out of reach because of *the world* — it is across the river, over the ridge,
beyond the AO boundary, in the air. **Never because a trigger volume said no.** An invisible wall converts
scale into insult, instantly and permanently.

And the player must be able to **tell the two apart at a glance**, by distance and terrain alone. A battle
he *could* have joined but read as unreachable is a broken promise. A battle he walks two klicks toward and
finds a wall at is worse.

#### 3.3 The doors are EMERGENT, not staged (see LW-9, THE MOVING WAR)

Summoner: *"not just all big battles are staged."* Reachable battles are **not hand-placed events.** They
fall out of the province simulation — VC and friendly units move on the district map, and where they
collide, a battle **exists whether the player shows up or not.** If his AO window happens to contain one, it
is live, and he can walk into it.

#### 3.4 THE DOORS — and the two traps that would ruin them

Summoner: *"there should be random events like stuck convoys in an ambush, or a trapped squad."*

A stuck convoy in an ambush. A squad pinned and calling on the net. An ARVN outpost being overrun. A downed
bird. **He can join, avoid, or watch and walk on.** They appear on **no briefing** — they are *opportunities,
not objectives.* (This extends the "contact deck" already in GAME_GUIDE §4.6.)

**TRAP 1 — the side-quest chore.** If helping *always* pays, every door is a tax on his time and the war
becomes a checklist. **LAW: helping COSTS** — ammo, blood, and the clock on his own mission, which does not
pause — **and pays UNPREDICTABLY**: sometimes intel, sometimes a survivor who joins the roster, sometimes
nothing at all except that they lived.

**TRAP 2 — the chaos map.** If a door is always open, we have rebuilt the rival game's constant Battlefield
chaos. **LAW: doors obey the Ambience Law (§4). RARE.** A big battle should be a thing he *tells someone
about*, never a thing he expects.

#### 3.5 The mirror of Hearts & Minds

ADR-019 tracks how the **villages** feel about him. The doors track how **his own side** does.

**Driving past a pinned American squad is allowed. The game says nothing. It is never scored.** But the
firebase *knows* — and it comes back as a bark in the chow line, a line in the debrief, the brass being
slower to trust him (rank, ADR-018). That is *Platoon*, and it costs him exactly what it should cost him.

**Keep it light and keep it quiet. No meter, ever** (ADR-019 §4 governs here too). The moment it becomes a
reputation bar, it dies.

This is how we get *Apocalypse Now* without getting *Men of Valor*.

### 4 · THE AMBIENCE LAW (governs the living firebase)

> ## **The living world's job is to make the quiet feel OCCUPIED, not to make the war feel BUSY.**
>
> **Every ambient event must be safe to ignore. The moment ignoring something COSTS the player, it is not
> ambience — it is a MISSION, and it belongs on the board at HQ.**

The firebase is **95% mundane**: the chow line, cards, a guard shift changing, a man cleaning his rifle,
mail arriving on a slick, a patrol coming back in short a man. **All of it ignorable, none of it demanding.**

Then, **one night in twenty hours**, the wire gets hit — and it is the thing the player remembers for the
rest of the campaign. **Scarcity is the entire trick.** A firebase attacked every third night is a
Battlefield map.

### 5 · THE INTEREST CURVE IS FRONT-LOADED ON PURPOSE

Hour one is **dense, loud, spectacular**. Hour twenty is **quiet** — and by then the quiet is *earned*: it
is **dread, not boredom**, because the player now knows what is out there.

**We buy the right to be boring later by being extraordinary first.**

This is what reconciles §2 with §4 — they are not in tension, they are **the same curve read at two
different times.** The generator carries a **density-of-interest budget** that starts high and decays as the
campaign matures.

## Consequences

**Bought:** an opening that hooks, without a single rail, a single cutscene, or a single line of plot. A
firebase that feels inhabited without feeling like a warzone. And a principled, testable line
(§3's binding test) that any future "wouldn't it be cool if—" proposal must pass — which is the real
long-term value here, because **this ADR's job is to still be saying no in two years.**

**Sacrificed (no free lunches):**
- **The authored threshold is hand-work inside a procedural game, and it will constantly try to become a
  script.** Every iteration on it will be a pull toward "and then this happens, and THEN this happens." The
  Arbiter guards this and will lose the argument at least once.
- **Front-loading interest means the mid-game is deliberately thinner**, and some players will read that as
  the game running out of content rather than as dread. That is accepted, and it is the same bet *Platoon*
  makes.
- **The Ambience Law will make the firebase feel underused** to whoever builds it. Someone will want the wire
  hit more often "because we built the system." **No.** The system's value is in how rarely it fires.
- **Guarantees cost generator complexity** — a weighting pass over encounter placement, plus a "campaign
  maturity" input to the density budget. It is more machinery than a flat random roll, and it is machinery
  the player must never see.

**Work created:** first-patrol encounter weighting · the density-of-interest budget (campaign-maturity input)
· world-event set-piece library (Arc Light on the horizon, napalm distant, slicks overhead, distant
firefight) · the living-firebase daily schedule (mundane) · the rare firebase attack · point-man trap
callout (which is ALSO ADR-018's squad-veterancy behavior — build once, use twice). Beaded under the LIVING
WAR epic.

## Evidence

- Summoner deep-dive, 2026-07-12 (all quotations verbatim); decree at
  `production/war_room/synthesis_living_war.md` §6–7
- `production/GAME_GUIDE.md` §1, Pillar 3 — "Nothing is on rails. Ever."
- `production/GAME_GUIDE.md` §3 — the existing mission grammar ("quiet approach → recon ring → objective
  spike → lull → escalation") and `VISION_READOUT.md` ("valleys between peaks are filled with *tension, not
  threat*") — **this ADR is the doctrine that grammar was always implying**
- Summoner's named anti-reference: the rival "Vietnam War" sandbox game ("constant combat and chaos
  everywhere but you're not really the main character")

## Related

- **ADR-017** (persistent province) — the stage the guarantees are placed on
- **ADR-019** (hearts & minds) — the first patrol must teach that the villagers are people
- **ADR-018** (progression) — the point-man trap callout is the flagship squad-veterancy behavior
- **ADR-005** (witness rule) — "let the patrol walk past" only means anything if stealth actually works
- Pillars served: **3. Freedom** (defended, by defining precisely what a rail IS), **2. Atmosphere**,
  **5. Fail forward** (every guaranteed beat is refusable, spoilable, and forgiven)
