# THE DECREE — THE PROGRESSION SPINE
## War Room 2026-09-09 · Arbiter's synthesis · **POST-DEMO-LAUNCH. NOTHING HERE SHIPS BEFORE EARLY ACCESS.**

**Convened by:** the Summoner, in five messages.
**Council:** game-designer · systems-designer · ux-designer · narrative-director · technical-director ·
devil's-advocate. All six reported. **The technical lens landed last and corrected three findings the
rest of the council had already agreed on — those corrections are folded in below, not appended.**
**Record:** `briefing.md` · `discussion.md` · `analysis/` (7 files).
**His scope ruling, verbatim, and it governs this whole document:** *"and post demo launch work."*

---

## 0 · THE HEADLINE: HE IS NOT PROPOSING A NEW DIRECTION. HE IS CLOSING THREE OF HIS OWN.

The council went looking for a pivot and found a capstone. Three findings, verified in code by the
Arbiter, not inferred:

| Date | His decree | As-built today |
|---|---|---|
| **2026-07-12** | ADR-020's first-patrol guarantee: *"**A firefight you HEAR and never reach** → the war is bigger than you, and you cannot fix it"* (`ADR-020:56`) | canon |
| **2026-08-05** | *"make it so **all radiomen are valid call options** and the menu is universal… that does feul that feeling of a larger war too"* | **SHIPPED.** `nearest_radioman()` (`field_director.gd:795-811`) searches the group, never the roster — *"wherever he came from"* |
| **2026-08-07** | the walking dice: *"a friendly element passing through, **a friendly element stuck in a real firefight**"* | **SHIPPED.** `ambient_encounters.gd`; two 4-man US elements on seeded routes (`mission_generator.gd:1005-1029`) |
| **2026-09-09** | *"the player is the solo person in this world and theres squads and world happenings all over them… come up to a radio man can also just use it to call stuff in"* | **this session** |

> **THE FINDING: the borrowed-radio mechanic he proposed today as new, he decreed on 2026-08-05, and it
> is in the shipping code. The living world of other people's fights he described, he decreed on
> 2026-08-07, and it is in the shipping code. What is missing is that the `"radioman"` group has
> exactly ONE member — his own squad's RTO (`squad_system.gd:236`, the only non-bench registration in
> the project) — and `FriendlyPatrolGroup`'s MOS pool has no RTO in it (`friendly_patrol_group.gd:36`).**
>
> **The capability is real. The population is empty. And the proposal converts ADR-020's saddest
> promise into a verb: the war is bigger than you — but you can reach a man with a radio.**

**RATIFIED IN PRINCIPLE.** Recorded as **ADR-043**, POST-DEMO, BUILD NOTHING.

---

## 1 · THE SUMMONER'S FIVE QUESTIONS, ANSWERED

### 1.1 · "Nothing gets thrown away — verify that."  → **VERIFIED. Nothing real is lost.**

The pivot **gates** the squad systems; it deletes none of them. Every squad consumer already null-checks
an empty squad (`measurements.md` §1). `setup()` already spawns `mini(SQUAD_SIZE, roster.size())`
(`squad_system.gd:71`): **the variable-size squad is half-built by accident.**

**But the blocker is bigger than the Arbiter first measured, and the technical lens caught it.** It is
not one refill and two constants. `SQUAD_SIZE` is hand-synced in **FOUR** places —
`squad_system.gd:23`, `squad_roster.gd:67`, `barracks.gd:48`, `debrief.gd:118` — and beneath them
`SquadRoster.vacancies()` (`squad_roster.gd:206-211`) returns `maxi(0, SQUAD_SIZE - living)` and is read
by `field_director.gd:2145` **and by `heli_lift.gd:417`, which calls `draft_replacements()`.**

> **THE REPLACEMENT BIRD IS A SERVO WHOSE SET-POINT IS EIGHT.** A solo player is permanently seven short
> and **the game permanently tries to fix him.** `ensure_roster()`'s refill (`:178-179`) is only half the
> blocker. The fix is one saved `CampaignState.squad_authorised` read by all four sites *and* by
> `vacancies()` — **two hours now, an unpicking job later.**

**Kept, gated, never deleted:** `SquadSystem` · formations and slot logic · `member_by_mos` ·
`_hand_off_radio` · the `fo_fac` quality path · `RadioHandset`/`RadioCord` · `_radio_check()` itself ·
`_grant_fire_support()` · the contact ledger.
**That sentence belongs in the decree because someone will misread this as "we don't need the squad."**

### 1.2 · The demo and EA scope  → **THE DEMO DOES NOT MOVE. Demo-safe items: NONE.**

His ruling settles the question the brief called the most consequential. The demo still opens with eight
men and a radio (`demo_game.gd:143-151` → `game_flow.gd:699-703`); the siege playtest remains the entry
gate; EA scope is untouched. **Nothing in this decree is on the critical path to launch, and nothing in
it may be used to justify touching a shipping file.**

The Devil's Advocate lodged the one objection that survives that ruling, and it is upheld as a warning:
the demo teaches **rung 6** — a stranger's only exposure to this game is a full squad, and the campaign
would then take it away. **That is a real discontinuity and it must be designed for, not discovered.**

### 1.3 · Solo in a lethal game  → **IT IS THE POINT — BUT THE PLAYER GOES DEAF BEFORE HE GOES LONELY.**

The UX designer and the Devil's Advocate reached the same finding from opposite intentions, which is the
strongest signal this process produces:

> **The squad is currently this game's ONLY legibility layer.** Under a 45 m jungle sight cap the
> player's information comes from men talking. Delete the squad and you have not made him lonely —
> **you have made him deaf in a game whose simulation is invisible.**

And the simulation genuinely is invisible. `combat_posture.gd` models suppression deeply and
symmetrically — `SUPPRESS_PIN 0.7`, cone spread to ×3.2, a 4 s pin-mercy grace — and **`vo_manager.gd`
has no suppression line and `mission_hud.gd` has no suppression readout.** This project has built the
deep half of Brothers in Arms and none of the legible half. Under the r4bk law, **for the player,
suppression does not exist.**

**RULING — THE SEQUENCING LAW, and it is the most important operational line in this decree:**

> **THE WORLD GETS A VOICE BEFORE THE PLAYER LOSES HIS SQUAD.**
> Suppression legibility and enemy-VO-as-contact-call ship BEFORE `ensure_roster()` stops self-healing.
> Reverse that order and the first solo playtest reports *"it's empty and I die to things I never
> heard"* — **and that verdict will be correct.**

**What the first three patrols must install** — none touching player ability (ADR-018), none gating
stealth (Pillar 3), none buying survivability with health (ADR-040 §1 forbids it outright):
1. **SEE FIRST.** One man is genuinely harder to detect than a file of six — fewer noise sources, one
   silhouette. This is not a buff; it is a property of being alone, and it rides the existing per-actor
   witness system (ADR-005) at zero cost.
2. **BREAK CONTACT.** *The highest-risk item in the whole proposal.* Pursuit must actually release —
   the game designer's numbers to test: lose LOS in vegetation 45 s → search-last-known; 90 s or 120 m →
   quit and return to route. **If THE HUNT never releases, one contact per patrol is a death spiral and
   the pivot dies on that alone.** This is AI tuning, not design.
3. **READ SIGN.** ADR-021 §3's income must be findable **without a point man.**

**And a hard dependency the game designer is right to name:** solo does not ship before **save-anywhere**
(ADR-007 Amendment A). Solo triples exposure to the save defect, and shipping it first converts Pillar 5
into reload-and-memorise — a pillar breach, not a difficulty setting.

**One casualty of solo, named honestly:** ADR-020's first-patrol guarantee contains two beats that
**cannot exist without a point man** — *"fresh trail sign; the point man stops and calls it"* and
*"a trip wire he catches before you walk into it"* (`ADR-020:50-51`). Solo, the trip wire is a wire that
kills you with nobody to blame. **Those two beats move onto the ADR-021 follow patrol.** The other five
survive unchanged — and one of them is the pivot's own thesis.

### 1.4 · Borrowing a stranger's radio  → **THE BEST IDEA IN THE PROPOSAL, AND IT IS NEARLY BUILT.**

The plumbing all reads the **group**, not the squad: the gate (`field_director.gd:814-821`), the leash
(`RTO_RADIO_RANGE = 10.0`, `:364`), the walk-up handset grab (`player.gd:438-451`, `:1055-1058`), and
even the error copy — `"TOO FAR FROM THE RADIO - GET TO A RADIO MAN (%dM)"` — is already written for a
stranger.

**What is missing is a man to borrow from, and a price. The price is the only real design work here.**

**AND THE TECHNICAL LENS FOUND THAT HALF THE PRICE IS ALREADY BEING CHARGED — BY ACCIDENT.**

> **The radio GATE and the radio SKILL read two different authorities, and nobody has noticed.**
> The gate is group-based and squad-blind (`nearest_radioman()`, *"wherever he came from"*). But the
> skill is squad-only: `field_director.gd:554-556` reads `fo_fac` off `squad_system.member_by_mos("RTO")`,
> and the learn-by-doing credit at `:602-605` does the same.
>
> **So a call through a borrowed radioman already gets `_fo = 0`** — the widest sheaf in the game, the
> longest cooldown (25 s, no floor relief), no veteran fourth round — **and banks no skill.**

This is an ADR-023 hazard (two authorities for one concept) **and** a gift. The economics the systems
lens proposed for rung 2 — *borrowed fire is worse fire* — is what the code already does. It ships
**strictly worse with no fiction saying so, and feeding no progression.**

**RULING:** keep the penalty, give it a fiction, and **move `fo_fac` onto the man on the net rather than
the squad slot** — one authority, per ADR-023. A borrowed stranger's sheaf is wide because *he* has not
walked the guns in for you; your own Sparks is tight because he has. **Named sacrifice (the technical
lens's own):** this costs your own RTO some of his uniqueness — he stops being the only skilled net and
becomes *your* skilled net. **That is a design cost and it is the Summoner's call, not the council's.**

**THE RULES, as ruled:**

| Gate | Ruling |
|---|---|
| **Availability** | Rarity IS the gate. Roughly one in three ambient elements carries a set, plus the firebase TOC. **He walks a looping route — the radio you used yesterday is four klicks north today.** |
| **Permission** | You ask the **element LEADER**, never the RTO. That is the whole social point. Rank (`CampaignState.title_tier()`) sets the tier you may ask for — never *whether*. |
| **His own state** | Reuse the shipped state, do not invent a second: `_last_contact_ms`, `_reported`, `pinned_holder` (`friendly_patrol_group.gd:16-29`). An element in contact is BUSY; his net is his own lifeline first. |
| **Budget** | **HIS, never yours, never merged.** One or two tubes, never air, per element per day. Three pots — battalion / element / personal — and merging any two deletes the ladder. |
| **Under fire** | **Refused by default**, as a voice line and not a UI state. It flips to yes **if you have put rounds on their attacker in the last 30 seconds.** *You earn the net by joining the fight.* |
| **Consequence** | Spending his stock leaves that element a mortar mission short on its next contact. Shelling his men danger-close sours him for the tour. **Borrowing has a memory, and the memory is social, not numeric.** |

**THE INTERACTION IS WORDLESS. BUILD NO DIALOGUE SYSTEM.** Unanimous across three lenses, and the brief's
premise was refuted on contact: a grep for `dialogue|conversation|talk_to` returns **zero files**. The
grammar the UX lens ruled, which needs no words at all:

- **AVAILABLE** — he stops and **turns his head to you**. The nameplate resolves. `[F]` appears.
- **COSTLY** — he holds the handset out **but does not let go of the set.** The 10 m leash becomes a
  thing you can *see*: a short cord tying you to a man who is not yours and will not move for you.
- **REFUSED** — **he does not turn.** No error, no toast. *A man who does not look at you has not
  agreed.* **Guard: the refusing man must be visibly, legibly busy — handset to his ear, map out —
  never idle, or the player reads a refusal as a broken NPC.**

**And the abuse case is answered, because the Devil is right that it is live code today.** Three teeth,
none of them a cooldown: **he walks away** · **he has one call, not a menu** · **the ask costs standing**.
Plus one the council must state plainly: **shooting a friendly RTO and taking his set is a bypass path
available in the code right now** (`_hand_off_radio` proves the radio survives its carrier). **A stolen
set must not work.** Killing an American to borrow his artillery is the one interaction this game may
never reward.

### 1.5 · Ordering and pacing  → **THE DEPTH IS RIGHT. THE UNIT IS WRONG. DO NOT COUNT MISSIONS.**

There is nothing to count: `mission_generator.gd:881` emits one type, `"PATROL"`. No campaign order, no
mission list, no numbering. A patrol is anywhere from 90 minutes to five hours.

> **TRIGGER THE SUPPLIED RTO ON A DEED, NOT AN ORDINAL:** the first wire-crossing after **(a) three
> committed excursions AND (b) one demonstrated failure the radio answers** — you watched a friendly
> element in contact you could not affect, or you broke contact under fire, or you found something too
> big to touch.

That lands most players between hours two and four — **his 4th or 5th patrol, arrived at honestly.**
Condition (b) is the whole point: **the radio always arrives as the answer to a felt problem**, which is
worth more than any tutorial ever written. *(The counter already exists: `_bank_patrol()`,
`field_director.gd:2053` — **not `:1797`, which the repo `CLAUDE.md` and several docs still cite. Stale;
see §7.**)*

### 1.6 · The command grammar  → **FOUR VERBS, NO FIFTH KEY, AND NO CURSOR TO IMPORT.**

**The period-HUD collision does not exist.** There is no command cursor, wheel, menu or order marker
anywhere in the codebase; `MOVE_TO` already designates by **aiming at the ground** (`_aim_ground_point()`,
`squad_system.gd:328-344`, one 250 m ray, layer 1 only *"so his own men are never the destination"*).
**"The weapon IS the interface" is not a proposal — it is shipped.**

**THE VERB SET.** `X` is the only order key and its meaning is **inferred from what is under the
reticle**, exactly as the shipped `FieldMarkVerb.infer()` already does (`field_mark_verb.gd:20-52`):

| Under the reticle | Order |
|---|---|
| ground | **MOVE THERE** → auto-transitions to **HOLD AND DEFEND** on arrival |
| a living enemy | **ATTACK THAT** |
| nothing, or a squadmate | **REGROUP** *(this is `C`; its toast simply reads REGROUP instead of ON ME)* |

ADR-012's permanence is untouched. The 2026-09-07 council's *"no fifth key"* stands. **One code
consequence:** `_aim_ground_point()` masks layer 1 only, so enemies (layer 3) are invisible to it —
inference needs a second ray on `1 | 4`, the same shape `_report_field_mark()` already uses
(`player.gd:268`).

**THE HARD DEPENDENCY, and it is not optional:** *"an inferred verb you cannot hear confirmed is worse
than a fifth key."* **The confirmation trifecta must ship WITH inference, never after it:**
- **WHAT** — the man who takes the order **says the order back.** Readback was 1967 voice procedure; it
  is the most period-honest confirmation available and it costs recordings, not screen.
- **WHO** — every man who receives it **turns his head to the player for ~0.4 s before he moves**, plus a
  1.5 s flash on his roster row. The roster strip **already carries per-man sub-lines**
  (`mission_hud.gd:285-291`), so this adds **zero new persistent HUD elements**.
- **WHERE** — **never draw the destination.** A marker is one clause from an objective pin (patrol
  contract §4). **The first man to arrive kneels and faces outward. The man is the marker.**
  *(This is already the shipped doctrine: `pilot_recovery.gd` — "NO marker, NO objective text — the
  smoke column IS the waypoint.")*
- **THE MISS** — a dropped ray must never be silent again (`squad_system.gd:286-288`). Answer it:
  *"say again."* **A refusal is information; silence is a bug report.**

**HOLD AND DEFEND — the state machine**, because "move here becomes hold and defend" is not a rename:

- **ARRIVE** (within 2.0 m) → **auto-transition**, never a distance test that leaves the mode unchanged.
- **ANCHOR** — best cover within ~8 m; **watch-facing = the player's aim vector at the instant of the
  order**, sector ±60°. *(This absorbs "cover that direction" for free — no fifth verb.)*

> **THE HIGHEST-LEVERAGE SENTENCE IN THE SESSION, from the technical lens: HOLD AND DEFEND IS NOT NEW
> BEHAVIOUR — IT IS THE GARRISON'S BEHAVIOUR AIMED AT A PLAYER-CHOSEN POINT.**
>
> `defense_zone` / `defense_zone_radius` (`ally_base.gd:255-256`) is a spatial **constraint that already
> survives combat**: it kills ADVANCE/FLANK at the scorer (`:1217-1219`), stops aggressive footwork at
> 0.8 of the radius (`:1571-1572`), pulls a man back past the rim (`:1600-1605`), and drops him out of
> ADVANCING outright (`:1709-1711`). `garrison_defender.gd:8` states the pattern outright: *"he holds his
> post (`defense_zone` + `OrderMode.HOLD`, so the perimeter never empties)."*
>
> **On arrival, MOVE HERE sets `defense_zone = order_pos`. That is the whole feature.** Do not write a
> second system.
- **HOLD** — indefinite. **A held post is held. There is no timer.**
- **BREAKS — exactly four:** anchor untenable → displace ≤10 m and re-hold · player DOWN (medic only) ·
  REGROUP · overrun → fall back ~25 m toward the player's last known position and re-hold.
- **THE PLAYER WALKING AWAY IS NOT A BREAK.** They hold. **You can leave men on a hill, walk off, and
  hear them die.** That is what makes MOVE HERE a commitment instead of a nav command.

> **UNRESOLVED, DELIBERATELY:** the systems lens proposed auto-rally beyond ~150 m, arguing a man you
> cannot see doing a job you cannot verify is simulation that buys nothing; the game-designer lens
> proposed they hold to the death and call you once. **Both are defensible and the difference is felt,
> not reasoned. This is a playtest question, and it is named in §5 as his.**

### 1.7 · The aimed-and-trigger-pulled attack  → **THE BEST MECHANIC IN THE PROPOSAL, AND IT IS SPENDING MEN.**

One scalar — `aggression` 0.35 → 1.0 — drives five dials: burst length, cover dwell, advance willingness,
the FEAR self-preservation threshold, and suppression output. Concretely: the suppression threshold to
advance goes 0.6 → 0.0, bound length ×2, time in cover ~3 s → ~1 s, they fire on the move, they grenade
at 25 m, and they do not break for cover until suppression exceeds 0.9.

**Expected price: one or two men out of eight, to take a dug-in MG that a deliberate ATTACK cannot take
at all.** The stall of the deliberate attack *is the design* — it is the reason to escalate.

> **THE COST MUST BE EMERGENT, NEVER A ROLL.** Do not add a casualty chance. Pillar 1 forbids death from
> hit-point math. Aggression multiplies **time out of cover** and **advance distance per bound** and
> divides **the suppression at which he goes to ground** — and the enemy's already-lethal, already-
> accurate fire does the killing. **The casualties are real, they are legible, and no die was rolled.**

**AND IT IS THE ONLY GENUINELY NEW THING IN THE PROPOSAL — the technical lens ranked it the riskiest
rung, correctly.** Two specific gaps: `_aim_ground_point()` uses collision mask **1** — world only
(`squad_system.gd:339`) — **so it cannot hit a man on layer 3 at all**; and **nothing anywhere assigns
`AllyBase.target` externally** (`CombatGoals.Context` has no called-target field). It needs a new field,
a new scorer input, a second ray and a refusal rule. **It is also the only verb that spends a named man
on a keypress, under permadeath.**

**The architecture, so it is not built as a second authority:** ATTACK is a **called target** consumed by
`CombatGoals.Context`, **biasing never forcing** ENGAGE/SUPPRESS; the aimed variant raises the bias and
spends an exposure token via `SquadCoord.request_exposure` — **already built** (`:1210-1214`).
**Not orders-as-goals in the scorer:** `CombatGoals.pick` is shared with the enemy, and a player-only
concept has no business in the enemy's brain. The scorer already has four post-pick constraint filters
(cord, zone, slot order, exposure token). **Orders belong in that layer, which is faction-agnostic by
construction — and therefore ports to the second war for free.**

**Two guards.** It must be **hard to give by accident**: the order arms on a **held** key with the weapon
**lowered and unable to fire**, so no frame is ever ambiguous — you cannot shoot while ordering, and you
cannot order while shooting. Toggled order modes are forbidden outright. And **men may refuse**: a green
element that has already lost two will not cross the open ground; a veteran element goes. **That refusal
is where ADR-018's silent behavioural veterancy finally becomes visible — Pillar 4 with teeth, delivered
by a verb instead of a stats screen.**

---

## 2 · THE TWO CANON COLLISIONS — RULED

### 2.1 · Pillar 4's anti-puppeteer clause → **IT STAYS PARKED, AND HERE IS EXACTLY WHY.**

The clause (`bible/BIBLE.md:88-94`) forbids *"a design that has you positioning individual men."* It has
been **PROVISIONAL since 2026-07-19** on his own word, and his verdict on the squad as it exists is
***"it felt like I was driving him."***

**The council does not need to open it, because the proposed grammar does not touch it.**

> **EVERY ORDER ADDRESSES THE ELEMENT. NEVER A MAN.** No *"pigman, set up on that treeline."* The medic
> already breaks on his own (RESCUE). The clause is satisfied as written, and this decree neither closes
> it nor leans on it.

**Named sacrifice, and it is a real tactical loss:** no individual tasking, ever. Squad-tactics veterans
will miss it most, and it is the single most likely thing a playtester asks for.

**Why it must still stay parked rather than be closed here:** the Devil's Charge 2 is unanswerable by
argument — *the ladder's twenty-hour payoff is more of the thing he criticised.* Only he can rule that,
and only from play. **The clause was dropped once before and its absence produced exactly the defect it
exists to prevent** (`BIBLE.md:74`). **It stays open. This decree is built so that it does not have to
be decided.**

### 2.2 · The period HUD → **RESOLVED, AND CHEAPER THAN FEARED.**

Zero new persistent HUD elements. No cursor (never existed). Order confirmation rides the roster's
existing per-man sub-lines. Order mode is shown by **the weapon lowering**, which ADR-034 already gives
every gun its own viewmodel for. ADR-030 stays deferred and non-blocking, untouched.

---

## 3 · THE GENRE, THE COMIC, AND THE FRANCHISE

### 3.1 · The genre claim
His words: *"a rpg, tactical squad war game… it sits apart from easy red 2 by not just being a sandbox
but having this story."*

**Easy Red 2, measured honestly:** 91% of 6,686 Steam reviews, ~$8.99, 100+ missions, a full mod SDK,
8-person studio. **No story, no protagonist, no narrative framing** — reviewers say so plainly.
Progression is mission-unlock order plus cosmetic dog tags. **The player is never solo**: always dropped
into a fully-manned army of interchangeable bodies. Its attested complaints are *repetitive maps and
modes* and a thin multiplayer population.

> **HONESTY REQUIRED, and the council enforces it on itself: the claim "Easy Red 2 feels empty" could
> NOT be verified. Do not use it — on a store page or in a design argument.**

**The real differentiator is not "we have a plot."** It is that **Easy Red 2's soldiers are fungible, so
relationship stakes are structurally impossible in it.** A world where *that man over there, the one with
the set on his back, is the difference between you having artillery and not* is a genuinely new
proposition — **and it turns ADR-011's 10 m leash from a punishment into the gameplay.**

**RULING: the differentiator is the BORROWED RADIO, not the comic.** The comic is the reason to care;
the radio is the reason it plays differently. Lead with the mechanic.

### 3.2 · How an authored story lives inside a world that runs without the player
**THE CARRIER RULE**, and it is the answer to the question the brief called the design problem of this game:

> **An authored beat must ride on something that MOVES WITH THE PLAYER, LOOKS FOR HIM, or WAITS
> INDEFINITELY. A beat attached to a coordinate is not a beat — it is a PLACE, and places are ADR-041's
> business.**

Three carriers, and a fourth channel:
1. **THE OBJECT HE CARRIES** — the grandfather's journal. It cannot miss him; it is on him.
2. **THE MAN BESIDE HIM** — Gus, whose decline advances on campaign time, not map position.
3. **THE THING THAT HUNTS HIM** — the sniper, who solves delivery *by being the entity that looks.*
4. **THE GUTTER** — the comic kills Sgt. Maddox in a subordinate clause. Its game form is **a bark in the
   chow line**. A report cannot miss a player. No trigger volume, no camera, no rail, and
   `vo_manager.gd` already exists. **The living world does not stage events for the player. It tells him
   about them afterwards.**

**The line that keeps the journal legal** (against the briefing-screen ban): the ban is on re-reading
**instructions**, not **literature**. **The journal may never name a place to go, a man to find, or a
thing to do.** The day an entry does, it is a briefing screen and it must be cut.

**The sniper** — four presence tiers on a hidden counter: **RUMOUR** (a bark, no entity, free) →
**SIGN** (a cold hide you can walk past) → **SILHOUETTE** (spawns at long range **with fire authority
OFF** — he watches and leaves) → **CONTACT** (he fires, once). **The Fairness Law's near-miss is not a
compromise here; it is his characterisation. The miss IS the character.** He takes only from the dead —
the helmet wall is your own KIA list rendered as a place, which is the most honest scoring this project
could have. Kill him early and **nothing announces it**: the porters stop coming and the rumours change
tense. **The game does not supply the comic's missing ending; it supplies a STOP.**

**The ending:** the comic has none — *"thats about as far of a story i had written overall."* It does not
need one. **The tour clock is the ending** — out-processing, not victory. And note the debt: **Pillar 4
promises men who "rotate home" and no tour clock exists anywhere in `scripts/`** (verified: zero hits for
`days_left`/`tour_days`/`rotate_home`/`DEROS`). The ending this story needs is a feature the pillars
already owe the game.

**The horror stays VIBE, zero systems**, per his own ruling. Delivered by: giving the horror to NPCs
(*"I swear I saw skeletons out in the bush"* — one bark, the player sees nothing); the gutter; retuning
the suppression shader and 650 Hz lowpass that **already render a psychological state on the player**;
the real Wandering Soul broadcasts; and art direction on things already modelled. **One guardrail:
exactly ONE external corroboration in the whole game, and it belongs to Louie in 1915. Corroborate the
player's own vision once and you have made a monster game.** Michael's nightmares are **CUT, not
deferred** — PANEL-ONLY means a first-person camera cannot do it.

**Gus** is an NPC with states you watch — never a thing the player becomes (that needs the sanity system
he did not authorise). **He is the ladder's DOWN-rung: the first companion the institution hands you, and
the wrong one.** Guard: *he is crying, not melting.* No monster shader, no boss fight with Gus, ever.

**Names:** the product is ***Tour of Hell: Vietnam***. ***Conquest of Worms*** names the **story layer** —
the campaign spine, in his own worm logotype, inside the paperwork motif. A player who never opens the
journal still bought a complete war game. **Michael gets no voice-over** — a narrator over the player is
the puppet ADR-020 forbids.

### 3.3 · WW1 → **narration now; playable ONLY as a by-product of the trench kit; never a separate title.**
The franchise is **already standing canon** — *"Tour of Hell"*, era-tagged, **Vietnam / Korea / WWI**,
decreed 2026-07-30. **His *"and we go to ww1 etc"* confirms canon; it opens nothing.** And WW1 is not an
abstract ambition: **it is already inside the comic**, reached through the grandfather's journal.

**Ruling:** a separate title is dead on arrival — the causal chain is the spine, and shipping the cause in
a different box means the cause never ships. **Narration ships first and should ship regardless.**
Playable is legal (ADR-039 zones; the journal-at-the-bunk is the most diegetic zone transition this
project will ever get, and closing the book must return him mid-sequence) — **but WW1 may never justify
its own art budget. If the trench kit exists for the firebase, WW1 is playable. If it does not, WW1 is
narration. The story does not get to order the tool.**

### 3.4 · **DO NOT BUILD A PERIOD-AGNOSTIC COMMUNICATIONS LADDER.**
The one place the council refuses the generalisation outright. There is no man-portable radio in 1917 —
runners, field telephones on wire, flares. To generalise the ladder you must abstract the RTO into "a way
to call support" — **and that abstracts away ADR-011, which is the most identity-defining system in this
game.** The radio is a MAN with a 10 m leash who can die and hand the set to a rifleman. **That is
Vietnam. Make it era-agnostic and you get "call support" in three wars and a soul in none.**

**REFINED BY THE TECHNICAL LENS, and the refinement matters.** The Devil is right about the *fiction* and
wrong about the *gate*. `nearest_radioman()` already asks one era-free question — *is there a living node
in group `"radioman"` within N metres?* A WW1 signaller at a field telephone, a runner, an OP: all are "a
node in a group with a reach." **The frame exists; do not build a second one.** Two things are wrongly
global and both are cheap to fix now:

1. **Reach must move onto the comms asset.** `RTO_RADIO_RANGE = 10.0` is a `const` on `FieldDirector`
   (`:364`), so reach is global. A field telephone is a fixed post with reach *along a wire*; a runner is
   **latency, not distance.**
2. **The asset token must stop being the interface.** `"prc25_handset"` is a literal mesh-name lookup
   (`radio_handset.gd:110`), `OPTIONAL_GEAR_PREFIXES = ["prc25_"]` (`model_actor.gd:445`), and
   `grunt_dresser.gd:71` keys the whole radio kit off `prc25_*`. **The gate is period-agnostic; the body
   wiring is spelled "PRC-25" in four files.**

**And the fire-support LADDER stays period CONTENT — this is where the Devil's charge lands and holds.**
`field_director.gd:558-600` is an eight-arm `match kind:`, mirrored in `fire_plan.gd:74-103`. Each arm is
a genuinely different *shape*: `arty` walks a golden-angle spiral, `spectre` puts an airframe on station,
`illum` changes the lighting. A creeping barrage, a box barrage and a gas shell are equally
shape-specific. **A generic "call fire" system would be good at no war.** Only three things around the
`match` must be agnostic — the gate (already is), the budget dict (already is, `:345-346`), and the
skill lookup (**currently is not** — see §1.4).

**What generalises is the TOOL and the TERRAIN, not the fiction.** The franchise decree's own
justification reasons about *terrain* — the cheapest layer — and is silent on weapons, AI, comms,
animation and VO, which are all of the cost. **There is no "era", "period", "theatre" or "campaign
setting" concept anywhere in this codebase** (`SimClock.Period` is time of day; `TerrainConfig.Preset` is
relief shape; the climate literally *is* the `TerrainType` enum, `vegetation_manager.gd:6-13`).
**A WW1 title introduces that abstraction layer. It does not extend one.**

### 3.5 · THE CONVERGENCE WITH THE FIREBASE KIT COUNCIL — narrower than the intent doc claims, and stronger

`FIREBASE_REWORK_INTENT.md:107` says *"a WW1 battlefield is cut terrain plus trench modules and shell
holes. **Nothing else about it changes.**"* **Five things change**, and each is cheap now and none is
free later: the vegetation enum · the work-marker vocabulary (door 15) · the ambient-war frame (which is
anchored to `player.global_position + bearing * dist`, `ambient_war.gd:58-70`, with no front, no
territory and no faction geography) · enemy VO (`VOManager.ENEMY_DIRS` is three Vietnamese folders,
`vo_manager.gd:16`, the only enemy VO source) · and the faction binary (door 14).

**What genuinely ports:** `DamageSystem.modify_terrain()`, `ClearingSystem`, the ADR-042 destructible
naming contract, `Hitzone`, the ballistic classifier, `MaterialBudget`, `InteriorPropFold`, the marker
builders, `MarchingCell`, `TerrainConfig.Preset`.
**What does not:** the bake · `place_firebase_main()` with its 2,071 runtime collider mutations ·
the tunnel/punji mechanics baked into the **save schema** (`campaign_state.gd:33-36`).

> **THE HONEST CLAIM, and it is better than the analogy: the naming contract, the destructible grammar
> and the in-engine placement loop are the only war-agnostic assets this project has — and today they
> are exercised only through a Vietnam monolith that hides their generality. THE SECOND WAR IS NOT A
> REASON TO BUILD THE KIT. IT IS THE TEST THAT TELLS YOU THE KIT WAS BUILT RIGHT.**

**One warning for that council:** do **not** generalise the assembler. `site_planner.gd` is 2,758 lines
and majority firebase-specific. Generalising it yields a placement engine that can express neither an FSB
nor a trench line. **The KIT is the generalisation; the assembler stays specific per site type.**

---

## 4 · THE DOORS TO KEEP OPEN
### *The highest-value output of a post-demo deliberation: not a plan to build now, but a list of choices that get expensive later.*

Each verified by the Arbiter against current code (`analysis/measurements.md` §12).

| # | Door | State today | Cost NOW | Cost LATER |
|---|---|---|---|---|
| **1** | **Squad size is hand-synced in FOUR places, and a Huey drives the roster back to eight** | `SQUAD_SIZE = 8` at `squad_system.gd:23`, `squad_roster.gd:67`, `barracks.gd:48`, `debrief.gd:118`; `vacancies()` (`squad_roster.gd:206-211`) feeds `heli_lift.gd:417` | **one saved `CampaignState.squad_authorised`, read by all four sites AND `vacancies()` — two hours** | **the replacement bird is a servo with set-point 8: a solo player is permanently seven short and the game permanently tries to fix him** |
| **2** | **`AllyBase.set_order()` signature** (`ally_base.gd:329`) | **28 call sites across 15 files** | add facing + intent today, defaults everywhere | a refactor across the whole AI after the next squad wave — **and until then every new order re-creates the arrived-and-idle man** |
| **3** | **`AllyBase` defaults to `OrderMode.FOLLOW`** (`:295`) | `friendly_patrol_group.gd:50-57` must **undo** it for every ambient man | make each spawner state it | **in a solo world most men are not the player's — a silent default every new spawner must remember to override is a defect generator** |
| **4** | **Radiomen are not a counted population** | one non-bench `add_to_group("radioman")` in the project (`squad_system.gd:236`) | **count radiomen as a first-class population in the census now**; reserve the MOS slot in `friendly_patrol_group.gd:36` | the already-shipped `[F] TAKE HANDSET` verb keeps pointing at nothing, and the art (a PRC-25 dress variant) arrives after the census froze |
| **5** | **The firebase stamped kit needs a `radio_post` ANCHOR** | `site_planner.gd:1130, 1173` already map `"radio"`/`"plot"` → `"radioman"` | **one named marker, while the kit is being authored** | retrofitting anchors into a frozen modular kit is per-building work. **Tell the firebase-kit council.** |
| **6** | **`_mark_dispatch(kind, target, run_dir)` has no owner field** (`field_director.gd:459`) | fire-support events do not record their source | **one string argument** | a schema migration through every consumer — and the event census is being built right now |
| **7** | **World-element identity must be SEED-DERIVED, not instance-id** | `pinned_holder` is an instance id `MissionScope.reset()` must wipe (`friendly_patrol_group.gd:19-29`) | **rule it before the census hands out ids** | a load re-keys every relationship the player built (ADR-010) |
| **8** | **Do not merge the fire-support pot** | one dict, day-latched (`field_director.gd:1488-1494`) | a net-identity getter at the day-latch, while there is one pot | a change at every call site |
| **9** | **The roster strip is hard-anchored for a fixed squad** | `_squad_panel.position = Vector2(12, -310)`, *"two lines per man"* (`mission_hud.gd:258-259`) | make it size-driven now | a layout pass — **and a one-man roster is rung 3** |
| **10** | **Companion state machines wedge the living world** | `pilot_recovery.gd` records the bug in its own header: a stuck escort **silently killed the walking dice for a whole run, and the symptom read as "the encounters are boring"** | every companion carries an unconditional timeout from its first commit, and registers in `MissionScope.reset()` | a class of bug that presents as *design failure*, not as a bug |
| **11** | **Orders are owned by the SQUAD CONTAINER, not by the player** | `SquadSystem._unhandled_input` (`squad_system.gd:275-291`) is the **only** order handler in the game; `friendly_patrol_group.gd:4-6` states other US elements *"take no orders"* | make orders act on a **listener set** owned by the player or a command node | **an RTO companion is yours but not a `SquadSystem` member — under today's architecture he is uncommandable by construction.** Rung 3 is blocked on this, not on AI |
| **12** | **`fo_fac` has two authorities** | gate reads the group; skill reads `member_by_mos("RTO")` (`field_director.gd:554-556`, `:602-605`) | move it onto the man on the net | an ADR-023 fossil hazard, and rung 2 ships silently broken |
| **13** | **`LazyGroup` spawns ONE-WAY — there is no despawn path** | `lazy_group.gd:9`, `activation_range 120.0`, `_spawned = true` and never cleared. **A patrol walked past once stays full-cost for the whole operation; the world monotonically fills and never sheds** | decide the shed rule before the living world is populated | **the living world is made of allies, and `ally_base.gd:855` ticks a flat `THINK_INTERVAL = 0.15` at any range — enemies band 0.15/0.3/0.6 by distance, civilians have `lod_tier`; allies have NO think LOD at all** |
| **14** | **Faction is a string prefix, and it is a binary** | `enemy_base.gd:305-312` — *"the id prefix IS the faction"*, returning `"vc"` if the id starts with `vc` and **`"nva"` for everything else**. No faction field on `EnemyData`; `vc_nva_dresser.gd` is named for exactly two | **one field on `EnemyData` and one function**, next time `enemy_base.gd` is opened | **the cheapest era-abstraction available.** Doctrine is already data-driven (`squad_coordinator.gd:38-49` loads `doctrine_%s.tres`) — the gap is only the label |
| **15** | **The firebase kit's work vocabulary is a `const Dictionary` in code** | `site_planner.gd:1170-1240` — `FSB_WORK_OCCUPATION` / `FSB_WORK_PRIORITY` name `chow_server`, `hooch_sleep`, `med_cot`, `latrine`, `pad`, `bunker` | move it to data **while the kit is being authored** | **a WW1 trench kit cannot add `work_firestep` / `work_sap` / `work_dugout_signals` without editing `site_planner.gd`.** This answers open question 3 of `FIREBASE_REWORK_INTENT.md` — **and the reason is the second war, not the 488/23 mismatch** |

---

## 5 · THE CALLS THAT ARE GENUINELY HIS

Put plainly, no file needed to answer (his 2026-07-19 rule):

1. **Does the player start the campaign with NO men?** Everything above follows from this one word. The
   council found it cheap to build and expensive to get wrong.
2. **The opening squad — given and taken away, or never given?** *The game designer voted against the
   whole pivot without it: you spend twenty hours earning back a thing you had on your first afternoon.
   The alternative is that a player waits twenty hours for a thing he has never seen.*
3. **Men you ordered to hold a hill and then walked away from: do they hold until they die, or come back
   to you at ~150 m?** Genuinely split council. **This is a felt question, not a reasoned one.**
4. **Is the aggressive attack allowed to share the trigger** (weapon lowered, held key, cannot fire)?
   The council says yes with guards; Pillar 1 says the trigger is sacred. **Your pillar, your call.**
5. **Gus — is the first companion the wrong one?** A companion the game gives you and then ruins is the
   comic's best material and reads to some players as punishment.
6. **WW1: is it narration until the trench kit exists?** The council says the story may not order the tool.
7. **Does a player's death start the next replacement in the same world, with the last man's name on a
   card in a footlocker?** Pillar 5 and the comic's own replacement premise meet exactly here.
   **Not the council's to decide.**
8. **Should your own radioman lose some of his uniqueness?** Fixing the `fo_fac` split means skill
   follows *the man on the net* rather than *your squad's RTO slot*. It is the correct architecture and
   it makes borrowing honest — but your own Sparks stops being the only skilled net and becomes *your*
   skilled net. **The technical lens explicitly declined to rule this one and handed it to you.**

---

## 6 · THE PHASED PLAN — POST-LAUNCH, IN DEPENDENCY ORDER

**None of this starts until the demo ships and the entry gate is discharged.** Ordering is by dependency,
not by appetite.

| Phase | What | Why it is first | Gate to the next |
|---|---|---|---|
| **P0 · PROVE THE FLOOR** | A headless probe that stands up a `SquadSystem` with an **empty roster** and ticks it. It does not exist. | The whole pivot rests on *"the squad code survives zero men"* — **currently a reading of guards, not an execution** (ADR-015) | the probe is green |
| **P1 · GIVE THE WORLD A VOICE** | Suppression legibility: enemy chatter **loses coordination, then goes silent**, in three bands. **`enemy_reload.wav` is recorded and imported in the Vietnamese voice sets with `play_enemy("reload"` having ZERO callers — a finished asset waiting for exactly this job** (Arbiter-verified). Plus enemy-VO-as-contact-call. | **The sequencing law.** The world must speak before the squad stops speaking | a playtest in which he can tell his fire is working |
| **P2 · THE BORROWED RADIO** | An RTO in ambient elements; the wordless offer/refusal grammar; element budgets; refused-under-fire-unless-you-joined-the-fight; **a stolen set does not work** | **Nearly built, needs no dialogue system, no mission counter, and it is the differentiator.** *The Devil's own words: build that rung, prove it, then argue about the other five* | he plays it and the ask feels social |
| **P3 · FIX THE ARRIVED-AND-IDLE MAN — as CONSTRAINTS, not a second authority** | Arrival becomes a **transition** that sets `defense_zone`; `set_order()` requires facing + intent; relocation is promoted out of `_execute_idle` **exactly as RESCUE already was** | **This is a bug class the project already found, already fixed once, and left standing in three places.** `ally_base.gd:1372-1377`: *"RESCUE outranks every combat state: the medic-revive bug was `set_order()` writing a variable `_execute_combat` never read, so Doc held cover while the player bled out."* **The diagnosis is in the file. FOLLOW, HOLD and MOVE_TO were never given the same fix.** And ADR-029 Amendment C §5's gate — *"enabled only once the AI provably obeys in a playtest"* — has never been run | that playtest, run and passed |
| **P3b · PRICE THE LIVING WORLD** | One headless run **under the siege, never on quiet terrain** (his own law, `PERF_LEDGER.md:2356-2359`), adding ambient elements at 0 / 8 / 24 / 48 men and walking the player past each so they materialise; record ms/physics-frame and draw calls via the existing `StallLedger` attribution | **The brief's perf premise was wrong.** At 65+ live units, think is **1.20 ms of a 37.5 ms** AI wall — ~3%. The wall is the **BODY** (hitzone sync 9.87 ms, `move_and_slide` 8.78 ms). *"A hivemind that shares thinking banks nothing; one that shares BODIES banks everything"* (`marching_cell.gd:4-8`). **Solo therefore helps MORE than expected — seven fewer bodies and their draw calls, in a call-bound project** | **a men-per-frame budget for the living world. Without it, "how many other squads" is a guess** |
| **P4 · THE VERB SET** | Reticle-inferred `X`; the readback/head-turn/kneeling-man trifecta; the say-again refusal; HOLD AND DEFEND; the aggressive attack | Depends on P3 entirely. **Do not build verbs onto an AI that cannot hear them** | he can tell what he ordered and who heard it |
| **P5 · SOLO** | `ensure_roster()` stops self-healing; squad size becomes a campaign variable; break-contact tuned; the two point-man beats move to the follow patrol | **Depends on P1 and on save-anywhere** | — |
| **P6 · THE LADDER'S BODY** | Companion (on `pilot_recovery`'s bones); the handheld as a **posture, not a possession** | The rungs that only make sense once solo is real | — |
| **P7 · THE STORY LAYER** | The journal; the gutter barks; the sniper's four tiers; Gus's states; WW1 narration | Rides existing systems; no engine work | — |

**Note the shape: P1, P2 and P3 all improve the game that exists today, whether or not the solo pivot
ever happens.** That is deliberate. A parked decision that only pays off at the end pays off never.

---

## 7 · THE TRADEOFFS, NAMED (Council Law 2)

1. **Pillar 4 is re-hosted, not free.** The *roster fantasy* — named teammates who wound, rotate and die
   — is deferred by many hours. **It survives only if the opening squad is given and taken away.**
2. **No individual tasking, ever.** A real tactical loss, and the first thing a playtester will ask for.
3. **Suppression legibility will be range-limited.** Beyond ~60 m in canopy you can neither hear him nor
   see his posture. Fire-and-maneuver teaches itself only at close range. **BiA's ring taught at any
   distance; this does not.**
4. **The aggressive attack becomes a two-handed input under fire** — when the player is worst at inputs.
   Expect the first playtest to call it clunky. The friction is correct; the complaint will be real.
5. **Borrowing makes fire support socially expensive and occasionally unavailable when you did everything
   right.** That must be defended, not softened.
6. **Refusal-by-not-looking can read as a broken NPC.** Mitigated only by making the refusing man
   visibly busy.
7. **The wordless design means the borrowed RTO can never become a character.** The companion rung above
   must carry all characterisation on barks alone.
8. **No guaranteed set-piece.** Some players finish a campaign having never met the sniper, never opened
   the journal, and having heard about Gus only in a bark. **That is what the leave-test costs.**
9. **The author does not get his own book's name on the box**, and Michael never gets Willard's voice.
10. **A green replacement companion is a punishment the player did not choose.** It is the price of
    Pillar 4 having teeth.
12. **A variable squad size costs the compile-time guarantee** that roster, spawner, barracks and debrief
    agree. Four consts that cannot silently disagree become one runtime value that can. **Mitigation is
    a probe, not a hope.**
13. **Orders-as-constraints costs the legibility of refusal.** A man obeying by *not advancing* looks
    identical to a man ignoring you — and suppression is already invisible. **An invisible constraint on
    invisible suppression reads as broken AI. The ack is the feature, not the polish; do not ship the
    verbs without it.** Constraints also stack: cord + zone + exposure refusal can freeze a man for three
    good reasons. There is one precedence rule today (*"cord outranks zone"*, `ally_base.gd:1598`); a
    third and fourth entrant needs it **written, not inferred.**
14. **Body-less ambient squads cost fidelity, and this is a genuine tension the council did not resolve.**
    `MarchingCell` makes a living world affordable — but **a `MarchingCell` cannot be shot at, walked up
    to, or borrowed from.** If the living world is where you find a stranger's radio, the cheap
    representation and the mechanic are in direct opposition, and something must give.
15. **Making the work-marker vocabulary data costs a compile-time check.** A misspelled `work_` type today
    falls to `off_duty` *deliberately, by name* (`site_planner.gd:1213-1215`); in data it falls through
    silently.
16. **THE DEVIL'S CHARGE 5, UPHELD AND ANSWERED.** The EA date passed with the gate undischarged;
    **`build/RECON_Demo.exe` is dated 2026-07-31 — verified on disk today, five and a half weeks stale**;
    the siege forms up off a 512 m map; 25 playtest items are open. **Every hour spent on this spine is
    an hour not spent there.** The answer is not that the charge is wrong — it is that **he ruled this
    post-demo, and the decree's only claim on today is §4's ten doors, nine of which are one line or one
    argument each.** *If this decree ever costs more than that before launch, it has been misused.*

---

## 8 · THE PARK — how this survives months of silence

**DECIDED:** the ladder is ratified in principle (ADR-043) · the borrowed radio is the differentiator and
builds first · no dialogue system · no fifth key · no cursor · no mission counter · orders address the
element and never a man · the handheld is a second satisfier inside `_radio_check()`, never a bypass ·
suppression legibility precedes solo · the carrier rule · WW1 is narration until the trench kit exists ·
*Tour of Hell: Vietnam* is the product and *Conquest of Worms* is the story layer.

**DELIBERATELY NOT DECIDED:** Pillar 4's anti-puppeteer clause **stays parked** — this decree is built so
it need not be decided · the 150 m hold-or-rally question · whether the trigger may carry an order ·
whether the opening squad is given and taken away · the fate of the player on death.

**WHAT WOULD CHANGE THIS DECREE:**
- **P0's probe fails** → the "nothing is thrown away" finding falls, and the pivot's cost estimate is wrong.
- **Break-contact cannot be made to release** → solo is a death spiral and the pivot dies on that alone.
- **He rules from play that he wants to position individual men** → the anti-puppeteer clause closes the
  other way and the verb set grows.
- **The suppression legibility playtest fails** → solo must not proceed, whatever else is ready.
- **The trench kit is never built** → WW1 is narration, permanently.

**ADR-023 — NAMED FOR DELETION when this ships** (not before): **ADR-021 §4's SECOND ROW** (*trusted →
YOU LEAD, the squad follows you*) and its line *"if he dies before you are ready, you take over anyway"*
— superseded, with no squad left to take over. **ADR-021's FIRST ROW SURVIVES INTACT as the tutorial.**
Also: **ADR-011's *"budgets are rolled at briefing, per mission type"*** — dead prose today, since
ADR-029 deleted the briefing and `_grant_fire_support()` allots **once per sim day**
(`field_director.gd:1488-1494`). And **`OrderMode.MOVE_TO` as a terminal state.**

---

## 9 · DRIFT FOUND ON CONTACT (NO MORE DRIFT — reported, not silently edited; other councils are live in these files)

1. **`_bank_patrol()` is at `field_director.gd:2053`, not `:1797`.** The repo `CLAUDE.md` cites `:1797`
   in the PLAYTEST R4 paragraph — **and `CLAUDE.md` is injected into every session, which its own text
   calls "a DRIFT GENERATOR."** One-line fix, deliberately not made here.
2. **ADR-011 was superseded in practice on 2026-08-05 and never amended.** It still reads *"the radio is
   a MAN … a LIVING RTO"* keyed to the squad; his ruling made it **any** radioman, and the code obeys the
   ruling. **35 days stale.**
3. **`field_director.gd:791-793` claims behaviour no probe proved** (truth law): it says the fix means
   *"standing next to a firebase radioman with a live PRC-25"* now works. **It still does not** — nothing
   but `squad_system.gd:236` ever joins the group, and `garrison_defender.gd:14` says the firebase
   radioman is *"never the player's RTO."*
4. **`GAME_GUIDE §4.4:181` says "5-man persistent fireteam"; the code says 8**, in two constants.
5. **`GAME_GUIDE:304` says the game has neither suppression nor morale** and requires any divergence to
   be named in an ADR. **Suppression, nerve and two-sided squad-break are live, wired, probe-covered
   code. The guide is in breach of its own rule, and no such ADR exists.**
6. **`project.godot:250-254` defines input action `radio` on key G with zero script references** — an
   ADR-023 fossil, and the obvious bind for the handheld. **Wire it or delete it.**
7. **ADR-024 does not exist as a file** — it is a `(DRAFT)` row at `GAME_GUIDE.md:535` and nothing else.
   The cinematic-direction ADR has never been written.
8. **No tour/rotation clock exists anywhere in `scripts/`**, while Pillar 4 promises men who rotate home.
9. **`enemy_reload.wav` is recorded and imported in the Vietnamese voice sets and `play_enemy("reload"`
   has zero callers** — an unused finished asset, and exactly the one P1 needs.
10. **THIS SESSION'S OWN BRIEF WAS WRONG ABOUT ADR-025.** It is not DRAFT.
    `ADR-025-lod-tier-simulation.md:3` reads **SUPERSEDED 2026-07-20**, and `:10` reads *"Do not extend
    `WorldSim`, and do not wire `materialize_near`/`dematerialize_far`."* Its blessed successor
    `AIDirector` has **zero implementation files.** *(The Arbiter's own briefing carried the error; it is
    corrected here rather than left standing.)*
11. **BROKEN INSTRUMENT: `WorldSim.current_ao` is written `false` (`world_sim.gd:18`) and set `true`
    nowhere in the repo**, so `count_live()` (`:23-28`) returns **0, unconditionally, forever** — and
    `tests/test_world_alive.gd:334` and `:374` **print it as a measurement.** A probe reporting a
    constant as a finding.
12. **`dynamic_mission_factory.gd:1`** claims to turn *"WorldSim state transitions"* into missions.
    `WorldSim` has no transitions of any kind.
13. **`mission_generator.gd:224`** — *"register all spawned enemies so the region grid can LOD them."*
    There is no region grid and no LOD.
14. **`squad_system.gd:22`** — *"Player-led squad for the village assault."* That mission type was
    retired by ADR-029.
15. **`player.gd:470`** — a live `print("[NETDBG] set_on_net(...)")` on the shipping net path.
16. **CROSS-COUNCIL, RELAYED NOT EDITED:** the firebase-kit council's own briefing
    (`2026-09-09_firebase_kit_pivot/briefing.md:71-75`) gives an agent's file boundary as
    `scripts/systems/tree_break_system.gd` and `scripts/systems/damage_system.gd`. **There is no
    `scripts/systems/` directory** — the files are `scripts/world/tree_break_system.gd` and
    `terrain/systems/damage_system.gd`. **A live agent brief pointing at paths that do not exist.**
    Flagged to the coordinator; not edited, because that council owns the file.
