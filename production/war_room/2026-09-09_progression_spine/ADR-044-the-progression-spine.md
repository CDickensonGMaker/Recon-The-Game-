# ADR-044: THE PROGRESSION SPINE — you start alone, and you earn the war

**Date:** 2026-09-09 · **Status:** **ACCEPTED IN PRINCIPLE — POST-DEMO-LAUNCH. BUILD NOTHING.**
**Decreed by:** the Summoner, in five messages, closing with *"and post demo launch work."*
**War Room:** `production/war_room/2026-09-09_progression_spine/` (briefing, discussion, synthesis, 7 analyses)
**Amends:** ADR-011 (§3 below) · ADR-021 (§4 — its second row only) · GAME_GUIDE §4.4
**Depends on:** ADR-007 Amendment A (save-anywhere) · ADR-018 · ADR-020 · ADR-029 Amdt C §5 · ADR-032 · ADR-039 · ADR-041
**Does NOT close:** Pillar 4's anti-puppeteer clause. See §6.

> **DRAFT PENDING FILING.** This file lives in the council folder, not in `production/adr/`, because a
> second council was live in the tracking docs when it was written. **It is filed as
> `production/adr/ADR-044-the-progression-spine.md` only on the Summoner's word.**
> **Numbering:** drafted as 043; **043 was taken the same day by the firebase council's modular world
> kit**, so this is **044**. Do not cite an "ADR-043 progression spine" — it never existed.

---

## Context

The Summoner proposed, verbatim:

> *"i think we should really shift the game from having the squad, that just the player is the solo
> person in this world and theres squads and world happenings all over them… if youre out in the world
> and come up to a radio man can also just use it to call stuff in and than eventually the player will
> get their own hand held radio… make it first come from a mission where youre supplied a radio guy,
> maybe the 4th or 5th mission… and than later on you can request to have a radio man come with you,
> which is like a rpg companion. and than eventually the player gets to have the up to 8 man squad
> follow them."*

And, for the top rung:

> *"you should be able to give commands in the most simple way. move here, which than creates a hold and
> defend command. regroup command or a attack command, with a aimed and trigger pulled attack command to
> be a more aggressive attack. very brothers in arms inspired"*

**The council found that this is not a new direction. It is the capstone of three decrees he already
made**, and two thirds of it is in the shipping code:

| His decree | As-built |
|---|---|
| **2026-07-12** — ADR-020's first-patrol guarantee: *"A firefight you HEAR and never reach → the war is bigger than you, and you cannot fix it"* (`ADR-020:56`) | canon |
| **2026-08-05** — *"make it so all radiomen are valid call options and the menu is universal… that does feul that feeling of a larger war too"* | **SHIPPED.** `nearest_radioman()` (`field_director.gd:795-811`) reads the group, never the roster — *"wherever he came from"* |
| **2026-08-07** — the walking dice: *"a friendly element passing through, a friendly element stuck in a real firefight"* | **SHIPPED.** `ambient_encounters.gd`; two 4-man US elements on seeded routes (`mission_generator.gd:1005-1029`) |

**What is missing is that the `"radioman"` group has exactly one member** — the player's own RTO
(`squad_system.gd:236`, the only non-bench registration in the project) — **and `FriendlyPatrolGroup`'s
MOS pool has no RTO in it** (`friendly_patrol_group.gd:36`). The capability is real; the population is
empty.

---

## Decision

### 0 · THE OPENING — RULED BY THE SUMMONER, 2026-09-09, DURING THIS COUNCIL

> ***"squad is for the demo, but for the main game itll start with the player arriving on a huey with no
> squad mates but as a new replacement to the firebase."***

**The demo keeps its squad, unchanged. The main game opens SOLO — the player arrives by Huey as a new
replacement at the firebase.**

This ruling **dissolves** the council's single largest open condition rather than overruling it. The
game-designer lens voted against the whole pivot unless the opening squad was *given and taken away*,
because a player who waits twenty hours for a thing he has never seen is waiting, not wanting.
**Under this ruling there is nothing to take away — the squad is never given.**

> **The player arrives owed nothing. That is a stronger opening than a scripted loss, and it needs no
> authored bereavement to justify it.** The dissenting condition is **satisfied by the ruling, not
> overridden by it.**

**It is also the comic's own opening.** The bible's premise line has a seventeen-year-old who *"by
November is a replacement in the 101st Airborne"*, and Michael enters Issue 1 p3 as exactly that — the
new man arriving where everyone already knows each other. **The game's opening and the book's opening
are now the same event**, and ADR-021's follow patrol (§4) is what the new replacement is walked out on.

**Three consequences that follow immediately:**

1. **THE ARRIVAL IS THE HOME OF THE ONBOARDING THIS GAME DOES NOT HAVE.** The 2026-09-07 demo audit
   measured *no in-game onboarding of any kind* — controls surface nowhere, `grep PLAYER_MANUAL` = 0
   hits. A replacement being walked in and shown where things are is diegetic, unscripted, refusable,
   and is the one place a hardcore no-rails game may legitimately teach.
2. **THE ARRIVAL IS WHERE THE LADDER STARTS.** A replacement with **no men and no radio, set down in a
   base full of both.** Every rung above him is visible from the pad on his first morning. The ladder
   does not need to be explained; it needs to be seen.
3. **AND IT BREAKS THE REPLACEMENT BIRD — see §1.1 below. That is the first thing this ruling breaks
   and it is now P0-adjacent, not a later cleanup.**

### 0.5 · YOU EARN THE MEN — AND HE OWES NO APOLOGY FOR IT

> ***"and than over time and completing missions you earn squad members"*** ·
> ***"which isnt super historical but it works for the gaming aspect."***

**The second half of that is wrong, and the decree records it as wrong, because the correction is worth
more than the concession.**

**Vietnam ran INDIVIDUAL ROTATION.** Men arrived and left the line one at a time, on their own clocks,
not as units. A new replacement had no standing; the FNG was avoided *precisely because he got people
killed*. **What a replacement actually had to earn was other men's willingness to walk behind him.**

That is the mechanic he just described. **It is not a concession to gaming. It is the single most
Vietnam-specific personnel fact of the war, and no other shooter builds it.**

**And it is this project's own prior finding.** The 2026-09-07 squad-cohesion council concluded that
individual rotation was Vietnam's real cohesion failure — and this session verified that **Pillar 4
promises men who "rotate home" while no rotation clock exists anywhere in `scripts/`** (zero hits for
`days_left` / `tour_days` / `rotate_home` / `DEROS`). **His progression spine is that promise, finally
built. The apology converts into a pillar.**

**THE ONE GENUINELY UNHISTORICAL PART IS THE BOOKKEEPING, AND THAT IS THE DESIGN WORK.**
A mission counter that grants a man is a game ledger — and §2 already refuses counters, because
`mission_generator.gd:881` emits one mission type and there is nothing to count.

> **HANG THE GRANT ON TRUST, NEVER ON A TALLY. A man is not awarded; a man agrees to go out with you.**

What earns it is competence made visible, not a number: excursions survived · men brought back alive ·
a demonstrated failure the radio answered · fire discipline near a ville. **He gave the shape himself**
when he said mission four or five, *"just to make sure the player understands the game by that time"* —
**that is competence, not a counter.**

**THREE CONSEQUENCES, and the first one turns a defect into a feature:**

1. **THE BROKEN SERVO BECOMES THE REWARD CHANNEL.** `vacancies()` → `heli_lift.gd:417` currently flies
   replacements in to top the player back up to eight (§1.1). Under this ruling **the replacement bird
   delivers a man when a man has been EARNED.** The set-point stops being the constant `SQUAD_SIZE` and
   becomes `CampaignState.squad_authorised`. **One system, not two — and the bird you arrived on is the
   bird that brings you your men.** *(Still four hand-synced sites plus `vacancies()`; still the first
   thing the ruling breaks; still P0-adjacent.)*
2. **A ROTATION CLOCK BECOMES LOAD-BEARING, not optional.** Men who can be earned can also **go home** —
   which is Pillar 4's own text, unbuilt since it was written. A man leaving at the end of his tour is
   a loss the player cannot prevent, cannot blame himself for, and must absorb. **That is the war.**
3. **LOSING A MAN MUST COST THE TRUST THAT WON HIM, OR THE LADDER IS A RATCHET.**

**THE RATCHET RULING, reconciling this with ADR-006 Amendment B** (which made the reputation economy a
ratchet that never demotes, so a player is never stranded below his own armory tier):

> **TWO CURRENCIES, AND ONLY ONE OF THEM RATCHETS.**
> **RANK/REPUTATION — the right to ASK — ratchets and never falls** (ADR-006-B stands unamended; a
> demotion would strand the player below his own armory).
> **TRUST — the willingness of men to WALK BEHIND YOU — is spendable, and getting men killed spends it.**
> You do not lose the radio tier you earned. You lose the men, and you lose the standing that got them,
> and you earn that back by going out alone again.

**Named sacrifice:** a player who loses a squad late is put back down the ladder he has already climbed,
which some will read as punishment rather than consequence. **It is the price of the ladder meaning
anything at all** — and it is the same bet ADR-018 already made when it gave squad veterancy teeth.

### 0.7 · THE NECKLACE IS THE CHARACTER SHEET — and it is worn, not opened

> ***"and the idea of a modular necklace because the player will have the ability to add and collect
> things to their necklace (which could create skill attributes to their character instead of a
> traditional rpg system)"***

**ACCEPTED as the progression system, with one hard re-hosting that the council will not trade away.**

**Why it is right on its own merits:** it is Pillar 4's *"minimal stats, maximal attachment"* made
literal; it is **period-HUD-safe by construction** — there is nothing to draw, because the sheet is on
the body; it satisfies the standing law that *no XP or reputation number may ever reach any screen*
more purely than any UI could, because **there are no numbers, only objects**; and unlike an inventory
screen **other men can see it.** That last clause is the whole design.

And it argues the book's thesis as a mechanic. In *Conquest of Worms* the horror is a person going, and
Gus's decline is trophies. **If the player's capability comes from what he took off the dead, then
getting stronger IS becoming Gus.** Most war games' progression means nothing; this one means the title.

---

#### 0.7.1 · THE RE-HOSTING — the necklace may not touch anything a bullet cares about

**ADR-018 §1 is absolute and this ADR does not amend it:**
*"No player progression may touch accuracy, recoil, sway, handling, health, or stamina. **Ever.**"*

**Three separate laws converge on the same answer, which is how the Arbiter knows it is the right one:**

1. **ADR-018 / Pillar 1** — a charm that improved your aim is hit-point math wearing a fetish.
2. **His own RPG-pivot decree: NO FANTASY ELEMENTS.** A charm that actually stopped a bullet is the
   supernatural entering a game he defined by its absence.
3. **His own horror rule, verbatim:** *"any horror gore scene in the comic is supposed to be
   representative of the psychological state of the person expericing the vision."* Horror is a readout
   of a mind, never a thing in the world. **A charm that works is a thing in the world.**

> **THE RULING: THE NECKLACE IS A SOCIAL ORGAN, NOT A STAT BLOCK. It changes what the WORLD does about
> you — never what your hands do.** A charm in 1967 had a real effect, and the real effect was on the
> man wearing it and the men who saw it. **That is exactly what the game should model, and it is free.**

**The legal attribute space** — precisely the space ADR-018 §3 leaves open when it lists what rank may
gate:

| Legal — the world's response | ILLEGAL — forever |
|---|---|
| **What you may carry** — ruck and capacity (ADR-018 blesses *"capacity grows"* by name) | accuracy, recoil, sway, handling |
| **What you may ASK for** — the fire-support tier, and **who will hand you a handset** (§3's borrowed radio reads permission off standing) | health, stamina, bleed-out time |
| **Who will walk behind you** — the earned-squad ladder of §0.5 | detection radius, noise, sight range *(a stealth stat is player ability by another name; Pillar 3 says stealth is an economy, not a stat)* |
| **How villagers, factions and the four camps read you** (ADR-019, ADR-038) | anything a bullet cares about |
| **What men SAY to you and about you** — the gutter | reload speed, ADS time, breath hold |

**Named sacrifice, and it is real:** a player who expects an RPG will look at his necklace and ask what
the numbers are. **There are none, and there never will be.** If the world's response is not legible
enough to feel like power, this system has failed the same way ADR-018's silent squad veterancy can fail
— **and the answer is the same: more world, never a meter.**

#### 0.7.2 · TWO AXES, AND THE SOURCE GAVE US ONE FOR FREE

The comic already separates them: a Vietnamese vendor **sells** Gus a protective charm; the ears are
**taken.**

| | **BOUGHT / GIVEN** — a charm, a St Christopher, a ring traded for, a thing a villager pressed on you | **TAKEN** — a trophy off a body |
|---|---|---|
| Trust cost | **none** | **yes, and it is visible** |
| What it buys | standing with the people who gave it; small carry and access gains | the same capability band, faster and cheaper |
| Who reacts | villagers warmly, men neutrally | **men, and not warmly** |
| Reversible | you may take it off | **you may take it off. They already saw it.** |

> **CAPABILITY UP, STANDING DOWN. THE NECKLACE IS HOW YOU SPEND TRUST FOR CAPABILITY.**

**This completes the two-currency model of §0.5 and it was the piece that was missing:**
**RANK/REPUTATION — the right to ASK — ratchets and never falls.**
**TRUST — the willingness of men to walk behind you — is spendable.**
**The necklace is the SHOP where trust is spent, and the price tag is around your neck where everyone
can read it.** That is a real RPG decision — deliberate, visible, self-destructive, chosen — and it is
his book's argument in mechanical form.

#### 0.7.3 · THE REFUSAL THRESHOLD IS THE EARNED-SQUAD LADDER RUNNING IN REVERSE — no new system

Past a threshold, **men decline to go out with you.** That is §0.5's grant mechanism read backwards, and
it needs nothing new: the same trust that buys a man withdraws him. Gus was beaten by an officer and
driven out of the AO for exactly this (Issue 3 p19), and the squad is already arguing about whether it
is acceptable in Issue 2 p23 — **so the world's reaction is authored in the source and does not have to
be invented.**

**Three guards that stop it becoming a loot treadmill:**
1. **ONE TROPHY PER MAN, NEVER RANDOM, NEVER A DROP.** *(This is what keeps it inside his own
   2026-07-30 ruling — see 0.7.4.)*
2. **NO SLOT THAT MUST BE FILLED.** A bare cord is a complete build. The necklace never displays an
   empty socket, because an empty socket is a quest.
3. **THE COST IS PAID ON SIGHT, NOT ON PICKUP.** Taking it in the green costs nothing until a man sees
   it. **Wearing it is the decision; taking it is only the opportunity.** That single rule is what makes
   this a choice rather than a tax, and it is why the object must be worn to work.

#### 0.7.4 · THE COLLISION WITH HIS OWN 2026-07-30 RULING — HIS CALL, NOT THE COUNCIL'S

> **His ruling, 2026-07-30, verbatim:** *"the only random thing we're getting from bodies should be
> intel points…"* — and the reasoning the council must respect: **"searching a man is not a slot
> machine."** The 20%/40%/20% corpse roll was deleted the same day. A related council line reads
> *"contraband comes from CACHES AND SITES, never from corpses."*

**A trophy is taken from a body. That is the collision, and it is named rather than assumed away.**

**The council's reading — offered, not ruled:** the 7/30 ruling forbids a **slot machine**, and a trophy
is not one. It is **not random, not a drop, not a reward roll, one per man, and it costs you something.**
The ruling's own stated reason is satisfied. The `lootable_corpses` group already exists
(`enemy_base.gd:3045`, `:3103`) and bodies are already searchable for intel, so there is no new verb —
only a new, deliberate, priced outcome on an existing one.

**But it is his ruling and only he can widen it. Flagged in §5 of the synthesis.**

#### 0.7.5 · WHAT THIS FORECLOSES, AND WHAT IT COSTS

- **It forecloses a stat screen, permanently.** Once the sheet is an object on the body, adding a numeric
  character panel later would contradict the whole design. **That is the point, and it is a door closing
  on purpose.**
- **It forecloses "found a cool thing, strictly better."** Every taken item has a price, so the pure
  upside pickup — the staple reward of the genre — does not exist here. Some players will read that as
  the game punishing exploration.
- **It puts art on the critical path of progression.** A necklace whose items do not read at a glance,
  on a PSX-budget model, at conversational distance, **is a character sheet nobody can read** — and the
  whole design rests on other men seeing it. *(A Blender agent is building the modular prop now; this
  council does not duplicate that work.)*
- **It costs the player the ability to un-know a decision.** He can remove the necklace; the men have
  already seen it. That is deliberate and it will feel unfair to someone.
- **And the honest risk:** if the world's reaction is thin, the necklace is jewellery. **It is only a
  progression system to the exact extent the NPCs are.**

#### 0.7.6 · THE THIRD CONSEQUENCE — the world starts to look wrong. **DIRECTION, NOT A RATIFIED FEATURE.**

> ***"yeah if the player goes too blood lusty it changes their experineces i guess."***

**The "i guess" is recorded honestly and it governs this whole subsection.** This is a direction he
sketched, not a feature he ordered. **Nothing here is authorised, and the decree must not overbuild it.**

**What it completes: the necklace now has three consequences, and none of them needs a new system.**

| | Consequence | Mechanism |
|---|---|---|
| **1** | **Capability up** | the necklace is the skill sheet, worn (§0.7.1) |
| **2** | **Trust down** | men see it; the earned-squad ladder runs in reverse (§0.7.3) |
| **3** | **The player's own perception degrades** | **his own horror rule, applied** — see below |

**On (3), the mechanism is already written in his canon and it is exact.** His binding rule: *"any horror
gore scene in the comic is supposed to be representative of the psychological state of the person
expericing the vision."* So a player who takes trophies **gets his own visions escalating** — the same
battlefield showing him what it showed Gus. The reference frame is `fya.11`: **Gus sees the living men in
a chow line rendered as corpses.**

> **NO SANITY METER. NO HUD. NO NUMBER. The player is never told. He notices the world has started to
> look wrong.**

**And it closes a question the bible raised and left open.** A worms-and-decay layer built as **world
state** would break his rule outright, because the horror must be **point-of-view and state-driven.**
**The necklace supplies the state** — and the driver is **a choice the player made**, which is
categorically better than a stress meter that ticks on its own. *(It also stays inside §0.7.1's ban: a
vision is not accuracy, recoil, health or stamina. The player's hands are untouched. Only his eyes lie.)*

**PARKED, on his own standing ruling:** *"we could still add a horror level and it comes from like stress
and shit but thats not a main focus right now but that is the vibe of the comic."* **The VIBE, not a
feature. Post-demo. Build nothing.**

**The only reason to record it now is to tell the horror layer what its INPUT is** when someone eventually
builds it: **not a timer, not a meter — the necklace.** And the bible's note stands that whoever builds it
starts from the **existing nerve and suppression systems** (`combat_posture.gd`, the suppression shader,
the 650 Hz lowpass — a psychological readout already rendered on the player), **never from a decal.**

#### 0.7.7 · FOUR HARD CONSTRAINTS ON THE HORROR LAYER — he raised this against his own idea, and he is right

> ***"hmm this can be a fine line tho cuz if youre just suddenly seeing zobies and gore it doesnt make
> much sense."***

**He is guarding the documentary register, which is the thing that makes the book what it is.** These are
written as **binding constraints, not taste notes** — every one is drawn from his own pages, so they are
enforceable rather than anyone's opinion.

**1 · A VISION IS NEVER A THREAT. State this first, because it is the rule that prevents the drift.**
A vision **cannot damage the player, cannot be shot, cannot be interacted with, and does not react to
being aimed at.** It has no collider, no faction, no health, and no entry in any target list.
**The moment horror can hurt you or take a bullet, it is a monster, and the game has become something
else.**

**2 · RATIO — THE BOOK IS EIGHT-NINTHS DIRT.** The bible §6 counts roughly **one page in eight** going
strange, and names exactly which: four Michael nightmares, the Durand crater, two back covers, Eugene's
splash. Everything else is burning shit barrels and waiting in the grass. **So even at maximum bloodlust
the horror is RARE and BRIEF. It is never a state the player enters and lives in, and it may never become
an ambience that stays on.** A permanent filter is the failure mode.

**3 · IT IS THE ORDINARY GOING WRONG, NOT MONSTERS ARRIVING.** The reference is `fya.11` — men in a chow
line rendered as corpses. **The same men. Still standing in line. Nothing attacks, nobody rises.**
**NO NEW ENTITY SPAWNS.** Existing, real, harmless things are rendered wrong for a moment, and then they
are not.

**4 · DOUBT BEATS SPECTACLE — and the bible names the calibration point.** Issue 1 p16, night watch under
flares: *"I swear I saw skeletons out in the bush."* §5 calls that *"the book's calibration point — a
frightened man's report, not an event."* **The strongest version of this system is the player being
unsure, with nobody else reacting, rather than being shown a horror.**
And §5 again: **Michael's visions are static and passive — things that stand there and look back — and he
never sees himself in them.** Only Louie's are interactive, and that difference is the two men's clearest
characterisation. **The player is Michael. The player's horror is PASSIVE, by canon.**

> **THE PROJECT-SPECIFIC HAZARD, NAMED SO NOBODY ARRIVES AT IT INNOCENTLY.** This repo contains a **live,
> complete zombie mode** — `scripts/zombies/` (`zombie_audio.gd`, `zombie_barricade.gd`),
> `scripts/levels/vc_zombies.gd`, `scripts/visuals/zombie_dresser.gd`, `zombie_randomizer.gd` — and the
> Summoner has ruled it **must never be deleted.**
>
> **A horror layer built without the four constraints above will find that code and reach for it**, because
> it is right there, it is finished, and it renders exactly the imagery the vision wants. **The result is
> precisely the game he just said would not make sense.** The zombie code is a separate mode and it is not
> the horror layer's asset library. **Any future agent that wires a `vc_zombie` into a Michael vision has
> violated this ADR.**

**The line where this stops being progression and becomes the book's ending is §5 call 2d, and it is his
alone: can the player go as far as Gus did, and what happens if he does.**

### 1 · THE LADDER

`solo, no net` → `a mission supplies an RTO` → `borrow any radioman you can reach` → `an RTO companion`
→ `your own handheld` → `up to eight men`

**Each rung is strictly better in ONE axis and strictly worse in another**, or it is not a rung — it is
just more power. The axes are latency, tier ceiling, sheaf quality, leash, risk, and whose budget you
spend. **A rung gates CAPABILITY, never CONTENT.**

> **THE BINDING GUARD, and it is what keeps the ladder legal under Pillar 3:
> THE SQUAD BUYS YOU GROUND YOU CAN HOLD. IT NEVER BUYS YOU GROUND YOU CAN REACH.**
> Every place, cache, ville and tunnel mouth in the world must be reachable and usable by one man. If a
> rung is ever required to enter a place, the ladder has become a rail.

**ADR-018's LADDER LAW survives, restated:** *rank gates how BIG, never WHETHER.* Rung 0 does not breach
it, because **being off the net is a POSITION, not a rank gate.** A player may always reach a net within
a bounded walk.

### 2 · THE RUNG IS TRIGGERED BY A DEED, NEVER BY A MISSION NUMBER

There is nothing to count: `mission_generator.gd:881` emits one type, `"PATROL"`. **The supplied RTO
arrives at the first wire-crossing after three committed excursions AND one demonstrated failure the
radio answers.** Condition two is the design: **the radio always arrives as the answer to a felt
problem.**

### 3 · ADR-011 IS AMENDED, NOT SUPERSEDED

> **A bypass is a call path that does not call `_radio_check()`. Adding a new SOURCE that
> `_radio_check()` ACCEPTS is not a bypass. What `_radio_check()` accepts may be amended; that
> everything calls it may never be.**

That sentence saves ADR-011 whole. The man stops being the only net and becomes **the best net.**

**Three amendments ADR-011 owes regardless of this decree:**
1. **"The radio is a man… your squad's RTO" is already superseded in practice** by his 2026-08-05 ruling,
   and has been for 35 days. Any radioman is the net.
2. **"Budgets are rolled at briefing, per mission type" is dead prose.** ADR-029 deleted the briefing;
   `_grant_fire_support()` allots **once per sim day** (`field_director.gd:1488-1494`).
3. **The `fo_fac` authority is split and must be unified.** The gate reads the group; the skill reads
   `member_by_mos("RTO")` (`:554-556`, `:602-605`). **Skill belongs to the man on the net.**

**The handheld is a POSTURE, not a possession.** To transmit you go static — down on a knee, antenna up,
rifle stowed, no movement, no firing — and the animation is visible and audible. It carries tubes and
*unadjusted* artillery only, never fast movers, at a fixed `fo_fac` of 0 and a flat cooldown; it occupies
a ruck slot; it can be shot off you and left on your corpse. **Strictly worse in five axes, better in
exactly one: leash.**

**A STOLEN SET DOES NOT WORK.** `_hand_off_radio()` proves the radio survives its carrier, so shooting a
friendly radioman and taking his handset is a bypass path available in the code today. **Killing an
American to borrow his artillery is the one interaction this game may never reward.**

### 4 · ADR-021 SURVIVES — ITS FIRST ROW INTACT, ITS SECOND ROW SUPERSEDED

ADR-021 §4 has two rows and only one dies.

- **ROW 1 — *NEW IN COUNTRY: YOU FOLLOW.* SURVIVES INTACT.** It remains the tutorial: a cherry walking
  behind an NPC sergeant's patrol, learning trail sign and trip wires by being led. Diegetic, unscripted,
  no popups. **This project has no other ratified onboarding, and the demo audit measured that it has
  none in practice.**
- **ROW 2 — *TRUSTED: YOU LEAD, the squad follows YOU.* SUPERSEDED**, and **named for deletion under
  ADR-023** when this ships — along with its line *"if he dies before you are ready, you take over
  anyway,"* which has no squad left to take over.

**The opening is therefore neither "you are alone" nor "you lead men." It is: you are a cherry attached
to somebody else's patrol, and that squad is never yours.** At the end of the first patrol they walk back
through the wire to their own hootch, and tomorrow you go out alone.

> **You do not wait twenty hours for a thing you have never seen. You spend twenty hours earning back a
> thing you had on your first afternoon.**

**ADR-020's first-patrol guarantee keeps all seven beats, but two of them — *"the point man stops and
calls it"* and *"a trip wire he catches before you walk into it"* (`ADR-020:50-51`) — move onto the
follow patrol.** They cannot exist without a point man.

### 5 · THE COMMAND GRAMMAR — ONE KEY, INFERRED, NO CURSOR, NO FIFTH KEY

`X` is the only order key and its meaning is inferred from what is under the reticle, exactly as the
shipped `FieldMarkVerb.infer()` already does (`field_mark_verb.gd:20-52`):

| Under the reticle | Order |
|---|---|
| ground | **MOVE THERE** → auto-transitions to HOLD AND DEFEND on arrival |
| a living enemy | **ATTACK THAT** (aggressive variant: held key, weapon lowered and unable to fire, then trigger) |
| nothing, or a squadmate | **REGROUP** |

ADR-012's permanence is untouched; C/H/N keep their meanings. **There is no command cursor, ring, wheel
or order marker in this game and none will be added** — `MOVE_TO` already designates by aiming at the
ground (`squad_system.gd:328-344`). **The weapon IS the interface, and it is shipped.**

**HOLD AND DEFEND IS THE GARRISON'S BEHAVIOUR AIMED AT A PLAYER-CHOSEN POINT.** On arrival, MOVE HERE
sets `defense_zone = order_pos` — a constraint that **already survives combat** (`ally_base.gd:255-256`,
scorer `:1217-1219`, footwork `:1571-1572`, rim-pull `:1600-1605`, ADVANCE kill `:1709-1711`), used today
by `garrison_defender.gd:75-76`. **Do not write a second system.** Watch-facing is the player's aim
vector at the instant of the order, ±60° — which absorbs "cover that direction" for free.

**Hold is indefinite. The player walking away is not a break.** They hold until they are dead.

**ORDERS ARE CONSTRAINTS, NOT A SECOND AUTHORITY.** `CombatGoals.pick` is shared with the enemy; a
player-only concept has no business in the enemy's brain. The scorer already has four post-pick
constraint filters (cord, zone, slot order, exposure token) — **orders belong in that layer, which is
faction-agnostic by construction and therefore ports to a second war for free.**

**THE CONFIRMATION TRIFECTA SHIPS WITH THE VERBS, NEVER AFTER THEM.** An inferred verb you cannot hear
confirmed is worse than a fifth key. **WHAT:** the man says the order back (1967 voice procedure).
**WHO:** every man who receives it turns his head to you for ~0.4 s, plus a flash on his existing roster
sub-line — **zero new persistent HUD elements.** **WHERE:** never draw the destination; **the first man
to arrive kneels and faces outward — the man is the marker.** **THE MISS:** a dropped ray answers *"say
again."* **A refusal is information; silence is a bug report.**

**THE AGGRESSIVE ATTACK COSTS MEN, AND THE COST IS EMERGENT.** One scalar (`aggression` 0.35 → 1.0)
drives five dials: the suppression threshold to advance 0.6 → 0.0, bound length ×2, cover dwell ~3 s →
~1 s, fire on the move, no break for cover below 0.9 suppression. **No casualty roll — Pillar 1 forbids
death from hit-point math.** Aggression multiplies time out of cover and divides the suppression at which
a man goes to ground; the enemy's already-lethal fire does the killing. Expected price: one or two men
out of eight, to take a position a deliberate attack cannot take at all. **And men may refuse** — a green
element that has already lost two will not cross the open ground. **That refusal is where ADR-018's
silent veterancy finally becomes visible.**

### 6 · PILLAR 4's ANTI-PUPPETEER CLAUSE STAYS PARKED — AND THIS ADR IS BUILT SO IT NEED NOT MOVE

**Every order addresses the ELEMENT. Never a man.** No individual tasking, ever. The clause
(`bible/BIBLE.md:88-94`) is satisfied as written. **This decree neither closes the clause nor leans on
it.** It remains his to rule, from play (his own words, 2026-07-19; restated 2026-09-07).

**Named sacrifice:** no *"pigman, set up on that treeline."* A real tactical loss, and the most likely
thing a playtester will ask for.

### 7 · THE SEQUENCING LAW

> **THE WORLD GETS A VOICE BEFORE THE PLAYER LOSES HIS SQUAD.**

Suppression is the deepest system in this codebase (`combat_posture.gd`) and **the player has no channel
to observe any of it on the enemy** — `vo_manager.gd` has no suppression line, `mission_hud.gd` has no
readout. **This project has built the deep half of Brothers in Arms and none of the legible half.** Under
the r4bk law, for the player, suppression does not exist.

The squad is currently this game's **only** legibility layer. **Remove it first and you have not made
the player lonely — you have made him deaf.** Suppression legibility and enemy-VO-as-contact-call ship
BEFORE `ensure_roster()` stops self-healing.

**Two further hard dependencies:** solo does not ship before **save-anywhere** (or Pillar 5 becomes
reload-and-memorise), and **break-contact must actually release** — if THE HUNT never lets go, one
contact per patrol is a death spiral and the pivot dies on that alone.

### 8 · THE STORY LAYER — THE CARRIER RULE

> **An authored beat must ride on something that MOVES WITH THE PLAYER, LOOKS FOR HIM, or WAITS
> INDEFINITELY. A beat attached to a coordinate is not a beat — it is a PLACE, and places are ADR-041's
> business.**

Three carriers — **the journal he carries**, **the man beside him** (Gus, advancing on campaign time),
**the thing that hunts him** (the sniper, who solves delivery by being the entity that looks) — and a
fourth channel, **THE GUTTER**: the comic kills a sergeant in a subordinate clause, and its game form is
a bark in the chow line. **The living world does not stage events for the player. It tells him about
them afterwards.**

**The journal may never name a place to go, a man to find, or a thing to do.** The day an entry does, it
has become a briefing screen and it must be cut.

**The product is *Tour of Hell: Vietnam*** (franchise decree, 2026-07-30, era-tagged Vietnam/Korea/WWI).
***Conquest of Worms* names the story layer, not the box.** Michael gets no voice-over — a narrator over
the player is the puppet ADR-020 forbids.

**WW1 is narration now, playable only as a by-product of the trench kit, never a separate title.**
**The story does not get to order the tool.**

### 9 · DO NOT ABSTRACT THE FIRE-SUPPORT LADDER INTO A PERIOD-AGNOSTIC "CALL SUPPORT" SYSTEM

The **gate** already generalises — *is there a living node in group `"radioman"` within N metres?* is
era-free, and a WW1 signaller, a runner or an OP all fit it. Two things are wrongly global and are cheap
to fix: **reach must move onto the comms asset** (`RTO_RADIO_RANGE` is a global const), and **the asset
token must stop being the interface** (`prc25_*` is spelled into four files).

**But the eight arms are period CONTENT and stay content.** Artillery walks a spiral, Spooky puts an
airframe on station, illum changes the lighting; a creeping barrage and a gas shell are equally
shape-specific. **A generic "call fire" system would be good at no war.**

---

## Consequences

**BOUGHT:** a progression spine the game has never had; a differentiator that is mechanical rather than a
store-page claim (*strangers in the world matter, because that man's radio is the difference between you
having artillery and not*); ADR-020's saddest promise converted into a verb; a tutorial that is the
comic's first act; and **ADR-011's 10 m leash turned from a punishment into the gameplay.**

**SACRIFICED — the full list is `synthesis.md` §7; the largest four:**
1. **Pillar 4's roster fantasy is deferred by many hours.** It survives *only* if the opening squad is
   given and taken away. Without that framing, the pivot is a demotion of a pillar and should be refused.
2. **No individual tasking, ever.**
3. **Suppression legibility will be range-limited** — beyond ~60 m in canopy you can neither hear him nor
   see his posture. Brothers in Arms' ring taught at any distance; this will not.
4. **No guaranteed set-piece.** Some players will finish a campaign having never met the sniper and never
   opened the journal. That is what the leave-test costs.

**AND THE COST OF THIS DECREE EXISTING AT ALL, named because the Devil's Advocate was right to press it:**
the EA date passed with the entry gate undischarged, `build/RECON_Demo.exe` is dated 2026-07-31, the siege
forms up off a 512 m map, and 25 playtest items are open. **Every hour spent here is an hour not spent
there.** The answer is not that the charge is wrong — it is that he ruled this post-demo, and **this
decree's only claim on today is its ten-plus doors, most of which are one line or one argument each. If
it ever costs more than that before launch, it has been misused.**

---

## FROZEN FILES

**Per the 2026-09-06 enforcement rule, every post-demo ADR names its paths. NO CHANGE to any file below
may be justified by this ADR before Early Access ships and the entry gate is discharged.**

```
scripts/squad/squad_system.gd          scripts/squad/squad_roster.gd
scripts/allies/ally_base.gd            scripts/allies/garrison_defender.gd
scripts/missions/field_director.gd     scripts/missions/friendly_patrol_group.gd
scripts/missions/mission_generator.gd  scripts/world/ambient_encounters.gd
scripts/world/pilot_recovery.gd        scripts/player/player.gd
scripts/gameplay/radio_handset.gd      scripts/ui/mission_hud.gd
scripts/autoload/campaign_state.gd     scripts/autoload/vo_manager.gd
scripts/ai/combat_posture.gd           scripts/vehicles/heli_lift.gd
project.godot (input map)
```

**AND THE MECHANISM THAT MAY NOT BE USED.** The 2026-09-06 council forbade the
`SLEEP_POST_LAUNCH`-style **parked-but-built constant by name**, as the leak mechanism it already proved
to be. **This ADR may not be implemented behind a gating boolean "so it is ready."** It is built when it
is authorised, or it is not built.

---

## Evidence

Every pointer below was verified against source during the session (pointer law).

- `scripts/missions/field_director.gd:789-794` — his 2026-08-05 ruling, in the code, verbatim
- `scripts/missions/field_director.gd:795-822` — `nearest_radioman()` / `_radio_check()`; `:364` the leash
- `scripts/missions/field_director.gd:554-556`, `:602-605` — the `fo_fac` authority split
- `scripts/missions/field_director.gd:1488-1494` — one allotment per sim day (ADR-011's dead prose)
- `scripts/squad/squad_system.gd:236` — the ONLY non-bench `add_to_group("radioman")` in the project
- `scripts/missions/friendly_patrol_group.gd:4-6`, `:36` — ambient US elements; the MOS pool with no RTO
- `scripts/allies/garrison_defender.gd:14` — *"the firebase radioman is background — never the player's RTO"*
- `scripts/world/ambient_encounters.gd:1-6` — the walking dice, his 2026-08-07 decree
- `scripts/missions/mission_generator.gd:1005-1029` — two 4-man friendly patrols, seeded
- `scripts/allies/ally_base.gd:295, 329, 1372-1377, 1417-1491` — order_mode read only in `_execute_idle`;
  the RESCUE fix that names the bug class
- `scripts/allies/ally_base.gd:255-256`, `:1217-1219`, `:1571-1572`, `:1600-1605`, `:1709-1711` —
  `defense_zone` as a constraint that survives combat
- `scripts/squad/squad_roster.gd:178-179`, `:206-211`; `scripts/vehicles/heli_lift.gd:417` — the refill,
  and the replacement bird as a servo with set-point 8
- `scripts/world/pilot_recovery.gd` — the companion lifecycle already shipped, and its wedge warning
- `scripts/ui/field_mark_verb.gd:20-52` — the shipped precedent for a reticle-inferred verb
- `PERF_LEDGER.md:295-300` — think 1.20 ms of a 37.5 ms AI wall; the body is the cost
- `production/adr/ADR-020-authored-threshold.md:50-51, 56` — the first-patrol guarantee
- `production/adr/ADR-021-patrols.md` §4 — the two rows
- `production/bible/BIBLE.md:88-94` — Pillar 4's provisional clause
- `assets/audio/vo/vi_*/enemy_reload.wav` — recorded, imported, **zero callers**

## Related

- **ADR-011** — amended, not superseded. The one gate stands; what it accepts widens.
- **ADR-021** — first row intact; second row superseded and named for deletion.
- **ADR-029 Amdt C §5** — its gate (*"enabled only once the AI provably obeys in a playtest"*) binds this
  work. **It was written for this proposal before the proposal was made, and it is still shut.**
- **ADR-023** — three deletions named in `synthesis.md` §8.
- **ADR-041 / ADR-039** — an NPC radioman is seeded and planned, never hand-placed.
- Pillars served: **3 Freedom** (capability gated, content never), **4 The squad is the RPG** (re-hosted:
  the men you borrow, protect and lose arrive from hour one), **2 Atmosphere**, **5 Fail forward**.
  Pillar **1** is untouched by construction — no rung, verb or rung-gate moves a bullet.
