# HOW BIG BATTLES ARE MADE — and which half of it we are allowed to steal

**Research brief · 2026-09-09 · commissioned by the Summoner:** *"look into games like call of duty
and medal of honor on how you make large scale battles the player is fighting inside of."*

**Status of this document:** RESEARCH INPUT, not canon (ADR-014). Every claim about another game
carries its source; every claim about RECON carries a `file:line` (POINTER LAW). Where a technique is
folklore I say so in the sentence, not in a footnote.

**The live context this is written against.** The 45-man night assault runs at ~3.8 fps and the frame
is in `ai.execute` (2,650–3,010 ms per 5 s window across ~4,408 calls); GPU is ~30% of the frame. The
Summoner has ruled a behavioural LOD — cheap wave behaviour at range, full thinking AI inside 40–80 m,
sappers keep their breach behaviour — and a separate agent is building it. **This brief is the craft
research that informs that build. It proposes no implementation.**

**The constraint that governs everything below, stated first because it disqualifies most of the
material:** *their* answer is a rail. Call of Duty's big battle works because the player is in a
corridor and the outcome is authored. **Pillar 3 is no rails — any route, any order** — and the
premise is a world that runs without the player. So the question is never "how do we copy the CoD
battle." It is: **which of these techniques survive in an open, simulated, seeded world?**

---

## 0. The sources, and what each is worth

| Source | What it is | Weight |
|---|---|---|
| Butcher & Griesemer, *The Illusion of Intelligence: The Integration of AI and Level Design in Halo*, GDC 2002 | The canonical talk on making AI **readable**. | Primary, dev talk |
| Damián Isla, *Building a Better Battle: The Halo 3 AI Objectives System*, GDC 2008 | How to author a big battle **declaratively** instead of scripting it. | Primary, dev talk |
| Jeff Orkin, *Three States and a Plan: The AI of F.E.A.R.* (GDC 2006) + *Combat Dialogue in F.E.A.R.: The Illusion of Communication* (Game AI Pro 2, ch. 2) | Where the perceived intelligence actually comes from. | Primary, dev-authored |
| Michael Booth, *The AI Systems of Left 4 Dead* / *Replayable Cooperative Game Design*, GDC 2009 | A director that paces a fight without scripting it. | Primary, dev talk |
| François Cournoyer, *Massive Crowd on Assassin's Creed Unity: AI Recycling*, GDC 2015 | The only public source with **hard behavioural-LOD numbers**. | Primary, dev talk |
| COD Modding & Mapping Wiki, *Call of Duty 4: SP Keys/Values* (wiki.zeroy.com) | The actual entity keys CoD designers use to stage a battle. | Primary-adjacent: shipped tool data |
| Jesse Snyder (CoD level designer), *Infinite Spawners* (jessesnyder.org/trenches) | A CoD designer criticising his own studio's pattern. | Primary, practitioner |
| Dmitriy Iassenev interview, *Inside the AI of S.T.A.L.K.E.R.* (Game Developer) | Offline/online A-Life switching — "a world that runs without you," shipped. | Primary, dev interview |
| Bohemia Interactive Community wiki, *Arma 2: Ambient Combat Manager Module* | An **open-world** ambient war generator, documented. | Primary, official docs |
| Dave Mark, *Modular Tactical Influence Maps*, Game AI Pro 2 ch. 30 | How a machine computes "where the front is". | Primary, dev-authored |
| DICE/Frostbite, *How HDR Audio Makes Battlefield: Bad Company Go BOOM*; Battlefield 1 audio team interviews (A Sound Effect / Audio Media International) | How scale is sold in the mix. | Primary, dev |
| Mount & Blade II battle-size / reinforcement-wave documentation (community + Nexus mod docs) | The honest form of a spawn cap. | Secondary, community-verified |
| Hell Let Loose Developer Briefings + wiki; Squad/Arma crack-thump mod documentation | Front-line legibility; supersonic crack | Secondary/community — **flagged in text** |
| Vice, *The Normandy Level in Call of Duty: WWII…*; MOHAA walkthrough corpus | The failure modes and the tells | Criticism / observed behaviour, **not** dev doc |

**Two things I looked for and could NOT source, so nobody should cite them as fact:**

1. **A hard AI-actor budget for any Call of Duty campaign.** The commonly repeated "CoD only ever has
   about a dozen live enemies" is **folklore**. The CoD4 SP entity docs prove *how* spawning is
   controlled but publish no ceiling. Treat any specific number as unproven.
2. **A 2015 Inc. / EALA design postmortem for MOHAA's Omaha Beach.** It does not appear to exist in
   public. What survives is player-observed behaviour and press coverage. Everything I say about
   Omaha's mechanism below is labelled as observed, not as documented intent.

---

## 1. What is actually simulated, and what is staged

### 1.1 The only hard numbers in public: Assassin's Creed Unity

Cournoyer's GDC 2015 talk is the one place a studio published its real budget. Unity ran, on
last-gen console hardware:

- **~40 real AI** — full agents, full decision-making.
- **~120 high-resolution models** — bodies that look right up close.
- **~10,000 crowd NPCs on screen** — the rest.

Three tiers, called *bulks*: **LoRes Bulk** (lowest, always >40 m from the player), **Autonomous
Bulk**, **Puppet Bulk**. Agents are *recycled* between tiers through a pool, so a distant body
promotes into a real agent as the player closes and demotes when he leaves — the talk's whole point
is doing that swap **without the player noticing the moment it happens**.

Read the ratio, not the absolute numbers: **40 thinking agents carried a crowd of ten thousand.**
That is a 250:1 staging ratio in a game where the crowd is not trying to kill you. RECON's 45-man
assault is asking every one of forty-five men to be a tier-1 agent, in a game where they *are* trying
to kill you. **We are running the whole battle at the top tier.**

### 1.2 Call of Duty stages, and the tool data proves it

The shipped CoD4 SP entity keys (wiki.zeroy.com) are the most honest document in this brief, because
they are the actual knobs the designers turned:

- `count` on a spawner sets how many bodies come out; **`count -1` is infinite**.
- `script_squad` — *"Group spawners/ai so they share enemy information."* Note what this is: a squad
  is not a simulated organisation, it is a **shared knowledge bus** between spawners.
- `script_nofriendlywave` — *"disables tracking of this ai for friendly_wave's."* CoD tracks allied
  AI as **waves** that advance, and this key opts a man out of it.
- `script_playerseek` / `script_delayed_playerseek` — enemies are told, by trigger, to come at you.
- `script_exploder` — *"Grouping things that explode"* — and `script_fxstart` / `script_fxstop`,
  which start and stop effects **by group**. The battlefield's explosions are a lighting cue-list.
- `script_noteworthy` — *"Used to get a string for scripted sequences mainly."*

That set of keys describes a **stage**, not a simulation: a spawn budget, a trigger, a wave, and an
effects cue-list. The spectacle layer — the explosions, the fires, the effects that read as "the war
is everywhere" — is a *separate authored track* that no AI is attached to at all.

### 1.3 The two shipped counter-examples: STALKER and Arma

Two games have shipped the *other* answer, and both are directly on RECON's premise.

- **S.T.A.L.K.E.R.'s A-Life** (Iassenev, Game Developer interview): characters within a radius of the
  player — *"usually about 150 meters, or what the game designer sets it to"* — are **online** (full
  simulation); everyone else runs **offline**, a cheap abstract simulation that still moves, fights and
  dies. The system switches individuals between the two as the player moves. This is behavioural LOD
  shipped in 2007, in an open world, as the mechanism for "the Zone lives without you."
- **Arma 2's Ambient Combat Manager** (Bohemia official wiki): spawns patrols **400–700 m** from the
  player to *"dynamically generate a war around a unit"*, with an intensity knob for how many patrols
  are live and how often they come, and it *"cleans up after itself… removes dynamic content as the
  player moves away."* The wiki states flatly: **"The generated patrols are not faked: they will fight
  with and / or against you."* Bohemia's own reasoning for the cleanup is that *"no current computer
  would be able to handle an entire Arma 2 gameworld full of AI."*

**The finding:** the open-world answer is not "stage instead of simulate." It is **simulate a moving
window and abstract everything outside it** — and both shipped implementations put the window
boundary at **150–400 m**, not at 40–80 m.

### 1.4 What RECON already has

RECON is not starting from zero on this; it is starting from a **two-thirds-built version of the
Arma/STALKER answer with the middle tier missing.**

- `scripts/ai/ambient_war.gd` — the staged tier. Distant firefights at **400–800 m** (`:66-70`),
  1–3 rolled per sim-hour, two parties **15–40 m apart answering each other** on burst clocks with
  lulls and a **ragged tail** in the last quarter (`RAGGED_FRAC 0.75`, `:37`), per-weapon distant
  reports (`fire_<id>_dist.wav`), a 900 Hz low-pass so a rifle at range is a slap off a treeline
  (`DIST_CUTOFF_HZ`, `:35`), fake emissive fireballs with **no real light**, and a hard cap of
  **two engagements sounding at once** (`FIRE_CAP 2`, `:23`). No ordnance, no agents, no cost.
  The 400 m floor is a *playtest finding* written into the file (`:64-67`): at 200 m the theatre read
  as a real engagement with no enemy — a gunship visibly strafing nothing.
- `scripts/world/ambient_encounters.gd` — the real tier, and it is **already a director** (§2.2).
- `scripts/missions/siege_director.gd` — the assault: bodies materialise on a **300–500 m ring**
  (`RING_MIN`/`RING_MAX`, `:26-27`) in cells of 3–6 and march in, with `LIVE_CAP: int = 50` (`:41`)
  set to the d50 ceiling by Summoner ruling because *"a capped assault trickles in and never reads as
  the mass attack the roll describes."*
- `mission_generator.gd:847-867` — ambient AA tracers placed on bearings around the AO.

**What is missing is exactly the middle.** There is a full-simulation tier and a zero-simulation tier
and **nothing in between**, so 45 men at 300 m are all paying tier-1 cost. That gap is the 3.8 fps.

---

## 2. Pressure without simulation — and what makes players spot it

### 2.1 The infinite spawner, criticised by the man who used it

Jesse Snyder, a Call of Duty level designer, wrote the clearest public account of the pattern:
*"The trick of course is that there's a trigger that prevents more guys from spawning in, or at
least some script condition that needs to be met."* Enemies keep coming, and *"move to the cover
point you just killed his predecessor on."*

His account of the tell is precise, and it names the mechanism:

> *"On Veteran difficulty in COD games, the problem of infinite spawners are compounded because
> players are forced to move slow and methodically."*
>
> *"Now I'm only worried about 'getting to the next part' so I can 'advance the game' instead of
> 'playing the game.'"*

His prescription: **"Set the wave counters to like three or five instead of endless and forever."**

Read that carefully. The spawner is not detected by *seeing* a man appear. It is detected by the
player **discovering that killing does nothing and position does everything**. The player runs an
experiment — hold and kill, versus push and ignore — and the game answers that the second one works.
Once he knows, he is playing the trigger, not the war. **The tell is a strategy, not a visual.**

This is the single most important paragraph in this brief for RECON, because RECON's premise faces the
same experiment from the other direction: if the assault's strength is a *ledger* rather than a tap,
then holding and killing is *exactly* the winning strategy, and the player who runs the experiment
gets rewarded for it. We are structurally on the right side of Snyder's complaint — provided nothing
anywhere respawns the assault.

`siege_director.gd` is already built this way: the assault has a **strength ledger** and **breaks at
42.5% killed** (`BREAK_BASE_RATIO: float = 0.575`, `:33`), passed as the break state's base ratio
rather than as per-man cowardice, and `field_director.gd:77` records that *"a withdrawal is not a
casualty."* That is Snyder's "three or five waves" done honestly. **Do not add a tap to it.**

### 2.2 Left 4 Dead's Director: pace without authorship

Booth's GDC 2009 talks state the Director's two goals — **"Promote Replayability"** and **"Generate
Dramatic Game Pacing"** — achieved through what he named **"Structured Unpredictability"**, and he
was emphatic that it was built as *"a layered set of extremely simple, playtestable algorithms"*
rather than one opaque system.

Mechanism: the Director tracks each survivor's **estimated emotional intensity**, which rises with
injury and danger and relaxes afterward; it drops a horde when things have been quiet and backs off
after a hard fight. Population is placed using the nav mesh, **Flow Distance** (travel distance from
the start) and an **Active Area Set** that follows the group. Mobs come at randomised intervals —
*"between 90 and 180 seconds"* — from a randomised spot **behind** the survivors.

**RECON already owns this pattern, in a form better suited to an open world.**
`ambient_encounters.gd` is the walking dice, decreed 2026-08-07: **distance travelled outside the
wire is the pacing engine** — one roll per `ROLL_EVERY_M: float = 65.0` (`:19`) at
`EVENT_CHANCE: float = 0.35` (`:20`), with a 600 s find-your-feet hold, a 240 s cooldown, per-day
caps (`DAY_CAPS`, `harass 1 / patrol 2 / contact 1`) and mutual exclusion with the siege and the
pilot chain. **Standing still rolls nothing.**

That is a *better* director than L4D's for this game, and it is worth saying why: L4D paces on
**intensity**, which is a model of the player's feelings; RECON paces on **ground covered**, which is
a fact about the world. Distance-driven pacing cannot be gamed by pretending to be calm, and it
cannot punish a player for being good. The one thing L4D has that this lacks is a *relax* term —
nothing currently suppresses a roll because the player just survived something.

**And L4D's spawn placement is the one part that must not be copied.** "A randomised spot behind the
survivor team" works in a corridor the players will never re-enter. In a 512 m AO the player walks
back through that ground, and a man who was not there five minutes ago is the tell. RECON's honest
version already exists: **spawn on a ring at 300–500 m and march in** (`siege_director.gd:26-27`) —
the bodies enter from outside the world the player has audited, and the approach itself is content.

### 2.3 Mount & Blade: the honest spawn cap

Bannerlord caps how many men are on the field at once (battle size), allocates the slots between the
two armies **in proportion to their real strength**, and feeds the rest in as **reinforcement waves**
triggered when a side has lost a threshold share (default 50%, configurable 10–50%). Sieges
deliberately start the attacker under-represented and feed them in, to model the attacker's
disadvantage.

This is the correct mental model for `LIVE_CAP`. **A cap is not a lie if the pool behind it is
finite and real.** The distinction that matters:

- *Infinite spawner:* the cap conceals a tap. Killing does not reduce the enemy. **Rail.**
- *Reinforcement wave:* the cap conceals a **roster**. Every man you kill is one who will never
  arrive. **Simulation with a rendering budget.**

Same visual, opposite games. RECON is already the second one; the risk is that nothing on screen
distinguishes them to the player, which is §3's problem.

---

## 3. Making a battle LEGIBLE — the half that matters

### 3.1 The founding rule (Halo, GDC 2002)

Butcher and Griesemer's **first** design goal was not "make the AI smart." It was **make the AI
intelligible**: the player must be able to understand what the AI is doing and why. Their stated
corollary is that if the player cannot understand an AI action, **it might as well not be in the
game.** Their other rule is parity — the AI should broadly see what the player sees, do what he can
do, and be limited the way he is limited, because a player predicts an AI by assuming it is like him.

That first sentence is the r4bk Law, arrived at independently by Bungie in 2002. And it lands on
RECON with force, because RECON has a deep, tuned, symmetric suppression model that **the player
cannot see at all**:

`scripts/ai/combat_posture.gd` holds a full Company-of-Heroes-derived suppression grammar — cover
multiplies *both* sides of the ledger (`SUPPRESS_ACCRUAL_OPEN 1.35` vs `_COVERED 0.35`,
`SUPPRESS_RECOVERY_OPEN 0.7` vs `_COVERED 3.0`, `:23-26`), a heavy pin crouches anyone
(`CROUCH_SUPPRESS 0.6`), the freeze at `SUPPRESS_PIN 0.7`, a fire ceiling at
`SUPPRESS_FIRE_CEILING 0.85` with the explicit doctrine that *"a suppressed man fires WORSE and
WILDER, he does not go silent — a silent squad is a disarmed squad"* (`:15-18`), a 4-second
`PIN_MERCY_S` grace on a fresh pin, and a decay throttle while rounds still crack past
(`CRACK_RECENT_S 2.0`, `CRACK_DECAY_MULT 0.17`, `:47-48`). `enemy_base.gd:279` carries
`suppression_level`, `:2799` applies it, `:2165` scales movement off it.

**None of it reaches the player.** No bark, no HUD, and the postures it drives are read at 10 m and
invisible at 100. The most expensive-to-build battle-legibility system in this codebase is already
finished and is currently decoration on the AI's side of the screen. **This is the cheapest large win
available and it needs no new system — only a presentation layer, which is GATE-exempt work.**

### 3.2 Where the perceived intelligence actually comes from (F.E.A.R.)

Orkin's F.E.A.R. work is the strongest evidence in this brief that **legibility is not a reporting
layer on top of the sim — it is most of the perceived sim.**

- The AI's coordination is an illusion: *"none of the enemy AI in F.E.A.R. know that each other
  exists"*; the squad manager groups NPCs **by proximity** and cooperative behaviour emerges because
  aligned goals produce aligned movement. Pincers were a side effect of go-to-cover orders.
- The dialogue layer is where the intelligence is *delivered*. Orkin's chapter describes authored
  **2–3 line dialogues** fired when enough squad members are nearby and criteria are met — one man
  asks *"What's your status?"*, the hit man answers *"I'm hit!"* or *"I'm alright!"* — and he names
  three jobs it does at once: **it tells the player he hit someone**, it sells the squad as a squad,
  and it **hints at the enemy's state of health**.
- Tommy Thompson's summary of the same design: *"all they do is play animations in certain
  circumstances. It's when that animation is played in the right place at the right time it appears
  clever and when several clever animations are played in a sequence, it appears intelligent."*

Note the second job in that list. **A bark is a damage read-out that does not need a HUD.** RECON has
no enemy combat-dialogue system at all — a repo grep finds barks only on the ally side
(`ally_base.gd:286-289`, promotion toasts), and `field_director.gd:2114` records the Summoner's
ruling that a squad death is *"spoken as a KIA bark"* in the moment while the names are read at the
wire. The vocabulary and the ruling exist; the enemy half was never built.

Halo's 2002 talk names the same three channels and no more: **dialogue** (tone carries across
languages), **postures** (sneaking / running / walking — persistent state), and **gestures** (one-shot
animations: diving, throwing). RECON has postures. It has no dialogue and few legible gestures.

### 3.3 Authoring a big fight without scripting it (Halo 3)

Isla's GDC 2008 talk is the answer to "how do you make a battle happen in a space where the player
can go anywhere," and its opening argument is a complexity argument, not an aesthetic one: **the
imperative/FSM method for encounters grows as n²** in the number of encounters, so scripting stops
scaling long before the hardware does.

The replacement is **declarative**: the designer writes a **task tree** — a prioritised list of what
needs doing ("guard A, but defend B if possible", with fallbacks as subtasks) — and **squads assign
themselves** to the highest-priority unfilled task, trickling down the tree like a Plinko machine.
Details that matter:

- **Squads are the atom.** They cannot be split. Allocation is greedy, weighing travel distance,
  keeping the squad acting together, balancing the tree, and **proximity to the player**.
- **Filters, not conditions.** A task carries *occupation* filters ("snipers only", "must not be in
  vehicles") that decide **who may fill it**, distinct from what activates it.
- **Exhaustion conditions** track deaths and remaining strength, so a task retires when its
  purpose is spent.
- **Reallocation is continuous.** When the player invalidates a task, squads trickle to the next
  live one; when a higher-priority task turns on, squads are pulled back up to fill it. That
  continuous re-fill is precisely what makes the system tolerate a player who does not follow a route.
- Cost is **O(n²m)** with caching and timeslicing.
- Knowledge is squad-local: a squad shares a **"clump"** — everything (allies, enemies, props,
  thrown grenades) within its region — instead of every actor querying the world.

**That last point is the perf finding hiding in a design talk.** Bungie's answer to "too many agents
thinking" was not only to think less often; it was to **make the unit of knowledge the squad, not the
man.** Forty-five individual world queries become, say, eight clump updates. RECON has
`scripts/ai/squad_coordinator.gd` and a `NavRouter`; whether the knowledge is actually shared or
merely coordinated is a code question for the LOD agent, and it is the difference between shaving the
think cost and eliminating most of it.

### 3.4 Computing "where the front is" — and getting the LOD gate for free

Dave Mark's *Modular Tactical Influence Maps* (Game AI Pro 2, ch. 30) gives the mechanism, and it is
one line long: **multiply enemy influence by ally influence, and the high values lie along the front
line.** Update rates from the same literature: strategic maps at **0.5–1 Hz**, tactical maps that
individuals consult at **2–5 Hz**.

Three things fall out of one cheap grid over a 512 m AO:

1. **Legibility.** "Where is the front" becomes a queryable number, so cues can be *emitted by state*
   rather than fired on a timer (see §7.3).
2. **The LOD gate.** A man's tier can be decided by his influence-map cell — is he *on* the contested
   line — rather than by a per-agent distance test to the player. That is a grid lookup, at 1 Hz, for
   the whole battle.
3. **The task tree's priorities.** Isla's trees are hand-authored per encounter; an influence map
   lets a *generated* tree get its priorities from the world, which is what an unscripted game needs.

### 3.5 The mil-sim answer: the front is read with the ears and the tracers

Hell Let Loose runs 50v50 across sector-divided maps with an ever-evolving front line, and — per the
game's own wiki and dev briefings — a sector is captured by **occupying any of its four grid
squares**, not a marked circle. The metagame *is* the front line. That is a multiplayer structure
RECON cannot import, but the design lesson under it is portable: **the front is a property of ground
held, and players will read it from the ground if the ground says so.**

The moment-to-moment version is **crack-thump**, and here I flag the sourcing: the *real-world*
method is well established (a supersonic round's shockwave arrives as a crack before the muzzle
report arrives as a thump; the delay estimates the range), and the *game* implementations in Arma,
Squad and Insurgency are documented in mod and community material rather than dev talks. What that
material consistently reports: **per-calibre distinct cracks so you can tell what is being fired at
you**, cracks/pops for near misses escalating to snaps for close ones, and **no crack at all from
subsonic weapons** — a subsonic weapon suppresses without cracking.

For RECON this is not flavour, it is the **Fairness Law's telegraph** and the direction-finder in one
asset: the crack says *you are under fire*, the thump says *from over there*, and the gap says *how
far*. `ambient_war.gd` already ships per-weapon distant reports and a distance low-pass; the crack is
the missing near-field half.

---

## 4. Audio — how the professionals actually sell scale

The Summoner has already ruled independently that *"random battle sounds will sell this war at large
effect more than anything else."* The research says he is right, and it says two specific things
about **how**, both of which contradict the obvious implementation.

### 4.1 Distance is recorded, not filtered (Battlefield 1)

DICE's audio team describes recording weapons *"not only from varying distances but also in different
environments. A gun shot or an automatic rifle sounds very different when fired in a forest, in a
concrete room, or out in an open field,"* and blending **discrete distance recordings** in Frostbite —
so an indoor-distant gun is *an actual recording of that gun, indoors, at distance*, not a near
recording with reverb and a low-pass on it. The samples themselves are modular: *"real recordings,
chopped up in common and unique samples that we put together in the engine."*

**RECON is already on this technique and should be told so:** the 7/27 pack ships a measured distant
report per weapon and `ambient_war.gd` loads `fire_<id>_dist.wav` per gun (`:47-48`), with a comment
recording that the previous version used one generic `shot_distant.wav` **for every gun in the war**.
That is the BF1 lesson, learned here, in this file. The gap is the **middle distance** — there are
near and far layers and nothing between, which is audibly the same gap as the AI's missing middle
tier.

### 4.2 Loudness competition, not layering (DICE HDR audio)

Frostbite's **HDR audio** tags every asset with a real-world loudness in **dB SPL spanning the whole
range of hearing**, and the system scales that down to whatever dynamic range the playback device
has. The behaviour that matters: **loud sounds make quiet ones inaudible, and the quiet ones become
audible again when they play alone.** The BF1 team put the same point in gameplay terms — an
explosion should *"completely cancel the sound of let's say a tree falling over. One sound instead of
two. Or even one sound instead of twenty in a given moment."* Their ambience beds are frequency-carved
so they *"cooperate with guns, explosions and vehicles"* rather than competing with them.

This is the opposite of the instinct a big battle produces. The instinct is *more voices*. The
professional answer is **fewer voices, correctly prioritised** — because a mix where everything is
audible is a mix where nothing is locatable, and locatability is the whole legibility budget.

**RECON already has a primitive HDR mixer and probably nobody has noticed.** `audio_manager.gd`
maintains a fixed pool of positional voices with per-voice start time and priority, where priority is
`1000.0 / (1.0 + d)` (`:287`) — nearer wins — plus a `TRANSIENT_LOCK_MS` that protects a just-started
transient from being stolen (`:302`). That is voice-stealing by distance. The step from there to HDR
is to make the priority a **loudness** (a mortar at 300 m outranks a rifle at 30 m) rather than a
pure distance, and to let a loud event **duck** the pool rather than merely evict from it.

### 4.3 The distant firefight has a rhythm, and RECON already solved it

The most instructive audio finding in this research came out of RECON's own file. `ambient_war.gd`
does not play "battle ambience." It builds a **conversation**: two parties 15–40 m apart
(`_build_shooters`), each on an independent burst clock (3–8 rounds for a rifle, 6–14 for an MG, 0.11 s
and 0.075 s between rounds), separated by lulls of **2–6 seconds**, opening at different times
(*"the two sides do not open together"*), and going **ragged** in the last quarter — bursts shorten,
lulls stretch — so an engagement *peters out* the way a real one does instead of stopping
mid-magazine. The file's own comment states the principle: *"a single source firing alone reads as a
man shooting at nothing."*

That is a better distant-war generator than anything I found described publicly, and the design note
to take from it is the one it already encodes: **scale is sold by exchange, not by density.** Two
sides answering each other reads as a war; twenty uncorrelated gunshots read as a sound effect.

The known defect worth naming while I am in the file (NO MORE DRIFT): `FIRE_CAP: int = 2` means at
most two engagements sound at once, and the file logs *"held silent — N firefights already sounding"*
for the rest. During the 45-man siege, when the whole horizon should be loud, that cap is the reason
the world outside the wire goes quiet. It is a one-constant question for the Summoner (§9), not a fix
I should make in a research brief.

---

## 5. Where these approaches fail, and what tells the player

Sorted by how likely each is to bite RECON.

1. **The strategy tell (Snyder).** The player runs the experiment — hold and kill vs. push and ignore
   — and learns that killing does nothing. *RECON's exposure:* low by design (finite ledger, break at
   42.5%) — **unless** anything ever tops up the assault. Guard it in the ADR, not in code comments.
2. **The spawn-in-cleared-ground tell.** L4D's "behind the survivors" placement is invisible in a
   corridor and fatal in a 512 m AO the player re-walks. *RECON's exposure:* currently low — the ring
   at 300–500 m plus the march is the right answer — and it is exactly what a naive perf fix would
   break, by moving spawns closer to save the walk.
3. **The theatre-too-close tell, already measured here.** `ambient_war.gd:64-67` records a 2026-07-29
   playtest where a gunship at 200 m was visibly strafing nothing. **Fakery has a minimum range and
   this project has measured its own.** 400 m. Anything staged inside it will be caught.
4. **The un-shootable-soldier tell.** Distant silhouettes are safe. Anything the player can put a
   round into and get no answer from is the worst artefact in the class, and in RECON it would also
   collide with the witness rule (ADR-005), the casualty ledger, and the gore systems.
5. **The guidance tell (CoD WWII).** The Vice critique of the 2017 Normandy names it precisely:
   *"obvious directions by throwing arrows and waypoints"*, a QTE in place of the fight, and *"I never
   died. Not once"* — against MOHAA, where *"the gates drop, you rush the beach and desperately try to
   find cover"* with no waypoints. The author's summary — *"you don't play the new Call of Duty so
   much as you watch it unfold"* — is the failure state of over-legibility. **Legibility is a cue, not
   an instruction. The moment a cue tells the player what to do rather than what is true, it is a
   rail with a friendly face.**
6. **The advancing-ally tell (MOHAA, observed not documented).** Player-side accounts of Omaha
   consistently report that *your allies only advance when you do*. Whether or not that was the
   authored intent — and I could not find a dev source either way — it is a mechanism that would fail
   two RECON pillars at once (freedom, and the squad's own AI intent), and it is worth naming
   explicitly so nobody imports it under the banner of "make the assault feel like Omaha."
7. **The dialogue tells the truth, or it becomes noise (Orkin).** Orkin names the failure he shipped:
   the dialogue wasn't approached systematically — it was invoked from many points in the C++ codebase
   — producing *"lots of trial and error to get timing, responses, and repetition issues right."* A
   bark system built ad hoc across call sites is a repetition machine. Build it as one channel with
   one arbiter, or don't build it.

---

## 6. THE THREE LISTS

Each entry names what it costs **here**, and points at the system it turns on.

### A. USABLE AS-IS — the technique is orthogonal to scripting

| # | Technique | Source | Cost here |
|---|---|---|---|
| A1 | **Tiered behavioural LOD with an explicit budget and a recycling pool.** Promote/demote between tiers so the swap is invisible. | AC Unity (40 real / 120 hi-res / 10,000); STALKER A-Life (~150 m online radius) | The LOD agent's build. This brief contributes the numbers and the caution in §7.1. |
| A2 | **Squad-local knowledge ("clump") instead of per-agent world queries.** LOD the *knowledge*, not the lethality. | Halo 3 (Isla) | Medium code, **largest perf lever named in this brief** — attacks `ai.execute` at the root rather than throttling it. Touches `squad_coordinator.gd`, `enemy_base.gd`. |
| A3 | **Enemy combat dialogue as request/response pairs**, arbitrated in ONE channel. Fires on state: taking fire, hit, pinned, reloading, moving, lost contact. | F.E.A.R. (Orkin); Halo 2002 | VO assets + one arbiter. **The missing HUD affordance for suppression (r4bk).** No new simulation — the state already exists at `combat_posture.gd:11-48`. |
| A4 | **Crack-thump: supersonic crack near-field, muzzle report delayed by range, no crack from subsonic.** Per-calibre cracks. | Arma/Squad/Insurgency (community-documented); real-world method | Audio assets + a timing offset in the shot path. Doubles as the Fairness Law telegraph and the direction-finder. |
| A5 | **Multi-distance recorded gun reports (near / MID / far), blended.** | Battlefield 1 (DICE) | Assets only. The near and far layers exist (`ambient_war.gd:47`); the middle is missing. |
| A6 | **Loudness-priority mixing (HDR): let loud events suppress quiet ones and duck the bed.** | DICE HDR audio (Frostbite) | Small. `audio_manager.gd:287` already prioritises by distance — change the metric to loudness and add ducking. |
| A7 | **Influence map (ally × enemy) at 0.5–1 Hz to compute the front.** | Dave Mark, Game AI Pro 2 ch. 30 | One grid + one tick. Pays three ways (§3.4): legibility source, LOD gate, and generated-task priorities. |
| A8 | **A staged distant-war layer that never fires ordnance and never comes closer than the measured fakery floor.** | Arma ACM (400–700 m); RECON's own 400 m finding | **Already shipped** (`ambient_war.gd`). Cost is zero; the open question is `FIRE_CAP 2` during a siege. |

### B. USABLE IF ADAPTED — say how

| # | Technique | The adaptation that makes it legal |
|---|---|---|
| B1 | **The task tree** (Halo 3): declarative priorities, squads self-assign, continuous reallocation, occupation filters, exhaustion conditions. | Halo's trees are **hand-authored per encounter**. Ours must be **generated from the seeded situation**, with priorities read off the influence map (A7), and one hard prohibition: **no task may name an outcome.** "Take the north wire" is a task. "Breach at T+240" is a rail. `siege_director.gd` already runs a primitive one-axis version (attack sector + cells + break ratio); this generalises it. |
| B2 | **The Director** (L4D): pace by intensity, drop pressure after quiet, back off after a hard fight. | Keep RECON's **distance-driven** dice (`ambient_encounters.gd`) as the base — a fact about the world beats a model of the player's feelings — and add only the **relax** term (suppress a roll shortly after a real fight). **Never** import L4D's "spawn behind the player"; keep the 300–500 m ring and the march. |
| B3 | **Reinforcement waves** (Mount & Blade): a live cap fed from a finite pool, waves triggered at a casualty threshold. | This is the honest reading of `LIVE_CAP 50`. Adaptation: make the pool **explicit, finite, and legible in consequence** — the man you killed tonight is not in tomorrow's roll. That is what separates a rendering budget from an infinite spawner **in the player's experiment** (§2.1), and it feeds Pillar 5 directly. |
| B4 | **Scripted vignettes / effects cue-lists** (CoD `script_noteworthy`, `script_exploder`, `script_fxstart`). | Allowed **only for events that are true in the sim** — a Huey crossing that is really flying, a tube really ranging, a fire really burning. The cue-list may control *presentation* of a real event. It may never *be* the event. |
| B5 | **Corpses and wrecks as the record of the battle** — the ground tells you where the fighting was. | RECON has gib/corpse/burning systems. Adaptation: a **corpse budget** and a decision to persist the day's dead rather than despawn them, so the AO reads its own history. Costs memory and draw calls; buy it with the LOD savings, not before. |
| B6 | **Front-line legibility from held ground** (HLL sectors). | Cannot import the sector metagame (multiplayer, symmetric). **Can** import the principle: derive the front from the influence map and express it **diegetically** — where the tracers converge, where the smoke is, which way the wounded are walking. A minimap front line is the CoD-WWII failure mode (§5.5). |

### C. INCOMPATIBLE — and why

| # | Technique | Why it cannot come in |
|---|---|---|
| C1 | **Infinite spawner gated on player advance** (`count -1` + trigger). | Makes the outcome a function of the player's *position* rather than his *fight*. Kills Pillar 3 (the route is now the answer) and Pillar 5 (nothing you did mattered). Snyder, who shipped it, says use 3–5 waves. |
| C2 | **Allies that only advance when the player advances** (observed in MOHAA Omaha). | Directly contradicts "the war happens with or without you" (Pillar 2) and Pillar 4 — the squad holds its own AI intent; a squad that is a function of the player's Z coordinate is a prop. |
| C3 | **QTEs, cinematic set-pieces, waypoint arrows and objective markers pointing at the fight.** | The CoD WWII failure state (§5.5). Legibility says *what is true*; these say *what to do*. |
| C4 | **Spawning combatants in ground the player has cleared, or inside his back arc, out of sight.** | Works in a corridor, is the loudest possible tell in a re-walkable 512 m AO. |
| C5 | **Per-encounter hand-authored task trees keyed to one route.** | The declarative *form* is fine (B1); binding it to an authored approach is the rail arriving through the back door. |
| C6 | **"Battle dressing" AI — soldiers whose only job is to die on animation, and staged casualties inside the player's reach.** | Fails the witness rule (ADR-005), corrupts the casualty ledger, and collides with the gore/body systems. **Distant silhouettes beyond the 400 m fakery floor are fine; anything shootable must be real.** |
| C7 | **A director that authors the result** — the assault takes the wire on a clock, the player's squad dies on schedule. | This is the line, and §7 defends it. |

---

## 7. The line — tested, and re-cut

The commission's line: *use these techniques to make a battle **read**, never to decide who **wins**
it.* I was asked to test it rather than assume it. **The line is right and I would keep it, but it is
stated at the wrong altitude and, as worded, it will be violated by accident.** Three corrections.

### 7.1 The real boundary is REACH, not read-vs-win

"Read vs win" is a statement about *intent*, and intent is not checkable in a code review. The
checkable version is a statement about **reach**:

> **Anything the player can reach, shoot, or be shot by is simulated. Everything else may be staged.**

This is the rule STALKER and Arma both shipped (150 m online radius; 400–700 m ambient spawn ring),
and it is the rule RECON already discovered empirically — the 400 m fakery floor written into
`ambient_war.gd:64-67` after a playtest caught a gunship strafing nothing at 200 m.

**And this is where I have a caution for the LOD agent, which is the most load-bearing paragraph in
this brief.** The ruled boundary is *40–80 m*. That is **inside lethal rifle range**. A man at 79 m
running "cheap wave behaviour" is a man who can kill the player with degraded decision-making — which
is not a perf optimisation, it is a **Fairness Law violation**: alert ≠ accuracy, accuracy ramps with
exposure, and a cheap agent has no exposure model. Compare the shipped precedents: AC Unity's 40 m
LoRes boundary is for *civilians who cannot hurt you*; STALKER's is 150 m; Arma's ambient ring starts
at 400 m.

The literature's answer is that the tier must be chosen by **role and engagement, not by distance
alone**:

- **Anyone with line of fire to the player, or whom the player has line of fire to, is tier-1
  regardless of range.** Distance decides the *default*; contact overrides it.
- **Tier transitions need hysteresis** (promote at one radius, demote at a larger one) or men on the
  boundary thrash — the AC Unity talk's whole emphasis is swapping *without the player noticing*.
- **LOD the knowledge, not the lethality** (Halo 3's clump, A2). A cheap man may know less, query
  less often, and share his squad's picture instead of building his own. He must not shoot with a
  different fairness model than an expensive one, or the player learns that men at 90 m are safe and
  men at 70 m are not — and *that* is a strategy tell of exactly Snyder's kind.

### 7.2 The director may set the ODDS, never the OUTCOME

The second cut, and the one that makes the line usable day to day:

> Choosing that **45 men come tonight, from the north, at 0230** is authoring the situation.
> Choosing that **they take the wire** is authoring the result.

RECON is already on the right side of this and should be told where: the assault breaks at a **ratio
of its own dead** (`siege_director.gd:33`), not on a clock; the mortars **bracket** and keep a
residual error deliberately, because *"a residual error is the ground a man can move to"* — the file
states the design outright: *punishing, not absolute (Pillar 5)*. A man who hears the tube and runs
takes nothing. That is a *rule* producing a *result*, which is the whole distinction.

### 7.3 Where I'd argue the line is wrong as stated — and what replaces it

The commission invited an argument with evidence, and there is one. **Legibility techniques are not
outcome-neutral, and pretending they are will produce a bad rule.** Orkin's F.E.A.R. dialogue exists
partly to *"hint to the player the enemy's state of health"*; Halo's stated first goal is that the
player understand what the AI is doing. Both **make the player better**, and a better player wins more
fights. Making the battle read **will** change who wins it.

That is not a violation — it is the point. It moves the outcome toward the **player's skill** and away
from **the author's intent**, which is Pillar 3 pointing in the same direction as Pillar 1. So "never
decide who wins" cannot mean "never affect the result."

The precise thing to forbid is narrower and it is testable:

> **A cue must be emitted by state, never by schedule.**
>
> A bark fires because `suppression_level` crossed `SUPPRESS_PIN`. Tracers converge because men are
> really firing there. The horizon glows because something is really burning. **No cue may be fired
> by a timer, a trigger volume, or a director that wants the player to believe something the sim
> does not support** — that is the single mechanism by which staging becomes a rail, and it is
> greppable in review.

That formulation subsumes the Summoner's line, survives the counter-argument, and can be enforced.
**If this brief produces one ADR clause, it should be that sentence, plus §7.1's reach rule.**

---

## 8. What I would tell the LOD agent, in one paragraph

Do not tier by distance alone: anyone in mutual line of fire with the player is tier-1 at any range,
because a cheap agent has no exposure model and the Fairness Law is not LOD-able. Put hysteresis on
the boundary and recycle bodies through a pool so the swap is never observable (AC Unity). Attack the
cost at the root before throttling the rate: make the **squad** the unit of world knowledge, not the
man (Halo 3's clump), and drive tier selection off a 1 Hz influence-map lookup rather than 45
per-agent distance tests (Game AI Pro 2 ch. 30). Do not move spawns closer to save the march — the
300–500 m ring and the walk-in are what keep the assault from reading as a spawner. And when a man
drops to the cheap tier, spend a fraction of what you saved on **making him legible** — a posture, a
bark, a tracer — because a cheap man who is visibly suppressed reads as more of a soldier than an
expensive man who is silent.

---

## 9. Questions only the Summoner can rule on

1. **`FIRE_CAP = 2`** (`ambient_war.gd:23`) — during the 45-man siege, should the distant-war cap
   lift so the horizon stays loud, or does the siege own the mix entirely?
2. **Enemy barks** — are we willing to spend VO on the enemy side? It is the single largest
   legibility win available and the r4bk fix for a suppression model that is already finished and
   completely invisible.
3. **Corpse persistence for the demo day** — keep the dead where they fell so the ground records the
   battle (costs memory/draw), or keep despawning?
4. **The LOD boundary** — 40–80 m was ruled before this research. Every shipped precedent puts the
   *behaviour* boundary at 150–400 m and gates the cheap tier on **not being in contact**. Does the
   ruling stand, or does it become "distance sets the default, contact overrides it"?
