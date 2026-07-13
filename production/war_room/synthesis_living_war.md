# DECREE — THE LIVING WAR

**Convened:** 2026-07-12 · **Summoner:** Caleb · **Arbiter:** recon-overseer
**Status:** DESIGN RATIFIED BY THE SUMMONER IN SESSION. Code changes gated (see §9).
**Supersedes:** nothing. **Amends:** ADR-006, ADR-008, ADR-010, GAME_GUIDE §3, §4.4, §4.6, §6.

This is the largest design decision the project has made. It converts RECONgame from *a mission
generator with a lobby* into *a war you live inside*. Everything below came out of a direct
Summoner deep-dive; the Arbiter's job here is to hold the pillars and name the bills.

---

## 1 · The fantasy, in the Summoner's words

> "A PS2 2002-styled open world Vietnam war experience. You live, patrol, fight, see the natives,
> make choices out in the field while the living breathing VC live out in the jungle and are always
> there to fight. … maybe one day you just wanna burn down the village down the road from you. but
> that'll make the locals hate you more and they will help the VC even more … the war is the story."

**Tonal anchor:** Willard in *Apocalypse Now*; the young recruit in *Platoon*. You are the main
character of a small, personal war — not a soldier in a big loud one.

**Named anti-references (binding):**
- **The "Vietnam War" sandbox game** — does everything, soft-simulated, "constant combat and chaos
  everywhere but you're not really the main character," losing its core loop to bugs while expanding
  content. **This is our failure mode. It is a scope disease, and it is contagious.**
- **PS2 CoD / Men of Valor** — cheesy scripted storyline. We do not write a plot. The war is the plot.

---

## 2 · THE PERSISTENT PROVINCE (the architecture)

**The province is a map, not a level.** Districts, villages, VC base sites, trail networks, a firebase
in one corner. It is **data** — small, saved, and the only thing that persists.

**The AO is a 1.5km window rendered into that map**, generated deterministically from
`province_seed + objective coordinates`. Only one AO is ever in memory.

```
generate(province_seed)  ->  the province, bit-identical, forever
apply(ledger)            ->  what YOU did to it
render_window(district)  ->  the 1.5km AO you actually walk in
```

**Random per campaign. Fixed and learnable within it.** A new game rolls a brand-new province (no
memorization exploit across playthroughs). For the next thirty hours it is *your* province, and you
come to know that treeline, that river bend, the trail junction where they always hit you. **Learning
your ground is half the Vietnam fantasy and it only works if the ground holds still while you learn
it.** (Summoner: *"i dont wanna a super memorized map that i spent tons of time on crafting but its
easy to 'beat'."*)

### Mission length falls out of geography — it is not a dial
| Type | Window | Insertion | Objectives | Minutes |
|---|---|---|---|---|
| **Patrol** | contains the firebase | **you walk out the wire** — no load, no ride | 1–2 | 20–30 |
| **Village raid** | a few klicks out | short ride or a long walk (player's call) | 2–3 | 30–45 |
| **Air assault** | across the province | Huey ride (already the load mask) | 3–4 | 45–60 |

Ratified target: **20–60 min average, player-paced.** The board at HQ shows all of them; the player
picks by what he has the stomach for tonight. *This replaces the flat "2–4 objectives" rule in
GAME_GUIDE §3 — objective count now scales with mission type.*

### The firebase lives INSIDE the AO
ADR-008 amended. The hub is no longer a separate scene with a separate seed. It is a place in the
world, and "patrol" means you walk out of it. This is the single cheapest change that buys the whole
open-world feel — most of it is already built.

### THE DETERMINISM BILL (non-negotiable)
Persistence is a **lie** unless generation is bit-identical. Two known leaks, both must die:
1. `game_flow.gd` seeds the **global** RNG and then draws from it (`LOADING_TIPS[randi()...]`),
   advancing the stream before the world builds. **World generation gets its own
   `RandomNumberGenerator`. Never the global one. Ever.**
2. **Every destructible thing needs an identity that survives regeneration** — a deterministic index
   from the generator (`district 3 / bunker 7`), never a node name. Get this wrong and the player
   returns to find the wrong hut burned.

**Gate (ADR-015 verification law):** a probe that generates the province twice from one seed, hashes
every object, and asserts identical. **If that probe is not green, the province does not ship.**

---

## 3 · DESTRUCTION IS TEMPORARY. ATTRITION IS PERMANENT.

The trap in "it truly remembers what I destroyed": **permanent destruction sterilizes the province.**
Thirty hours in you have blown every base and the war ends with a whimper — seek-and-destroy becomes
a checklist, which is the treadmill we hate.

So:
- **Bases, bunkers, caches, tunnel mouths REBUILD.** In a week they are back — or moved somewhere
  worse for you. The VC are a living organization, not a set of loot piles.
- **Men do not.** The province has a **finite regional manpower pool.** Every VC you kill comes out
  of it. This is already half-built (the finite QRF pool, GAME_GUIDE §4.2).

**The win condition of a province is therefore NOT "all bases destroyed." It is "their strength is
broken and the districts do not hate you."**

---

## 4 · HEARTS AND MINDS — THE ENGINE OF THE STORY

**This is the idea that makes RECONgame a game nobody else has made.** It is the mechanical answer to
"the war is the story," and it needs no cutscene, no dialogue, and no writer.

Every village has an **allegiance**. Your conduct moves it:
- Burn it, kill civilians, be careless with artillery → **hostility**
- Protect it from the VC tax collector, run a medcap, be disciplined → **cooperation**

Allegiance drives: trap warnings, ambush density in that district, whether informers exist, whether
the VC get free intel on your firebase — **and, above all:**

> ### THE EQUATION
> **VC manpower regenerates at a rate set by how the districts feel about you.**

Burn the village and you get *exactly what you wanted in the moment*: the sniping stops, the VC lose
a base, you are home before dark. **It works. It is the right call sometimes, and it must stay the
right call sometimes** — otherwise it is a morality meter with a correct answer, which is precisely
the cheesy PS2 thing the Summoner rejected. *Platoon* is not "don't burn villages." It is about how
**easy** it is to, and what it costs you later.

And the cost comes: that district's recruitment goes **up**. The body count you rack up is replaced
faster than you can generate it, and the war grinds against you in a way you can feel and cannot
immediately explain.

**That is the actual strategic failure of the American war in 1966–68, rebuilt as a game loop, and
the player discovers it himself — by doing it — with nobody ever telling him he is the bad guy.**

Body count is a strategy in this game. It is just a losing one, if you take the shortcut to get it.

**LAW: the fast road must genuinely work in the short term, or the whole system is a lecture.**

---

## 5 · PROGRESSION — RANK, NOT STATS

The Summoner asked directly: player+squad RPG skills, silent AI-only XP, or an HLL-style unlock
ladder? **Answer: all three questions have different answers.**

### 5.1 PLAYER STATS: KILLED
They fight **Pillar 1** head-on. If your rounds miss because your character has low Agility, then
death came from hit-point math and not from *situation* — the one thing this game swore it would
never do. It also makes the first ten hours feel bad in the worst way: *"my guy can't shoot yet."*

**Your aim is your aim, from mission one to mission one hundred.** No player accuracy stat, ever.
*(This amends GAME_GUIDE §4.4's "St/Ag/Al pool spend" for the PLAYER. It survives for the squad — see below.)*

### 5.2 SQUAD XP: KEPT — SILENT AND BEHAVIORAL
Not stat sheets. **Competence you can see.** Your point man starts walking you into trip wires; forty
hours later he **stops, and holds up a fist, before you get there.** The pigman's suppression tightens.
Doc reaches you faster. Learn-by-doing, no numbers shown.

**This is the teeth Pillar 4 has never had** — losing a veteran now hurts in the gut instead of on a
spreadsheet, and a free rookie is visibly, painfully *worse at his job.*

### 5.3 PLAYER RANK: NEW — IT GATES AUTHORITY, NOT ABILITY
In the real Army a PFC does not get to call an Arc Light. **Rank = trust = what you are allowed to
have on the net.** Diegetically perfect, and it never touches a bullet.

| Rank gates | It does NOT gate |
|---|---|
| **Fire support tier** — your own 60mm and a smoke marker → 105s → fast movers, napalm, Arc Light | your accuracy |
| **What you are trusted with** — a new man is not handed a village raid | your handling, recoil, sway |
| **The armory and the ruck** — better weapons *arrive with supply*, not "level 5 grants M16" | your health |
| **Cosmetics** — helmets, gear, the ruck (seen in the firebase, and on your own corpse) | anything a bullet cares about |

**WARNING (Devil's Advocate, upheld):** rank must gate **how big**, never **whether**. A hardcore
lethality game with zero fire support at rank 1 is not hardcore, it is miserable. It is a ladder,
never a wall. Fire support remains RTO-gated regardless of rank (ADR-011 stands).

---

## 6 · THE LIVING FIREBASE — SCARCITY IS THE TRICK

The Summoner wants a base that runs 24/7 without him: patrols returning, guard shifts changing, chow,
supply drops, and sometimes a sapper attack or a night raid.

**The Devil's Advocate's objection, and it is upheld:** *if all of that is always happening, we have
built the exact Battlefield chaos the Summoner just rejected.* Willard and the Platoon kid do not work
because a lot is happening. They work because **almost nothing happens, and then something unbearable
does.**

> ### THE AMBIENCE LAW
> **The living world's job is to make the quiet feel OCCUPIED, not to make the war feel BUSY.**
>
> **Every ambient event must be safe to ignore.** The moment ignoring something costs the player, it
> is not ambience — it is a mission, and it belongs on the board at HQ.

The firebase is **95% mundane**: the chow line, cards, a guard shift changing, a man cleaning his
rifle, mail coming in on a slick. All ignorable. Then, one night in twenty hours, the wire gets hit —
and it is the thing the player remembers for the rest of the campaign.

---

## 7 · THE AUTHORED THRESHOLD — the first walk out the wire

Summoner: *"the first time the players step out the wire there has to be some cool things that happen
'scripted' that will make them want to come back and see what else is going on out beyond the wire."*

This collides with **Pillar 3 (nothing is on rails. Ever.)** and with the Men of Valor rejection. The
Arbiter resolves it:

> ### **A RAIL TAKES THE CONTROLS AWAY. A GUARANTEE DOES NOT.**
> The first patrol is not *scripted*. It is **authored-dense** — the same procedural generator, with a
> weighting pass that GUARANTEES a set of encounters within 400m of the wire.

The first-patrol guarantee (each one teaches a system by being lived, never by a tutorial popup):

| The moment | What it teaches |
|---|---|
| Fresh trail sign; the point man stops and calls it | *your point man is your eyes — listen to him* |
| A trip wire he catches **before** you walk into it | *the jungle kills you, and this man just saved your life* |
| A VC patrol you can sit still and let walk past | *contact is optional, and the +25 is real* |
| A burned hut, a rotting ARVN body | *this war was here before you* |
| A firefight you HEAR and never reach | *the war is bigger than you, and you cannot fix it* |
| One gorgeous thing — a squall rolling in, Hueys crossing the treeline | *come back out here* |

**Nobody takes the stick. Nothing is on rails. You are merely PROMISED that walking out that gate is
the most interesting twenty minutes you have had.** In a purely random world your first patrol can be
forty minutes of empty green — **and that is how you lose a player forever.**

### 7.1 Set-pieces are WORLD events, never PLAYER events
**Willard does not fly the Ride of the Valkyries. He watches it from a boat.** An Arc Light on the
horizon, napalm three klicks out, a medevac lifting off with a screaming man aboard: the player is a
**witness**, never a puppet, and he can walk away from every one of them. *This is how we get
Apocalypse Now without getting Men of Valor.*

### 7.2 The interest curve is front-loaded ON PURPOSE
Hour one is dense, loud, spectacular. Hour twenty is quiet — **and by then the quiet is EARNED.** It
is dread, not boredom, because the player now knows what is out there. **We buy the right to be boring
later by being extraordinary first.** (This is what reconciles §7 with the Ambience Law in §6 — they
are the same curve at two different times.)

---

## 8 · SCOPE — THE ARBITER HOLDS THE LINE

The Summoner named the disease himself, in the other game: *"expanding the content too much and not
making a good game."* **He said it about them. It will be true of us in six months if nobody holds
the line.** The Arbiter holds it.

The vision as stated — living firebase sim, day/night, VC strategic AI, village allegiance, procedural
tunnels, helicopter assaults, booby traps, rank, squad RPG, supply logistics, fully random world — is
a five-year team project. **The question is not "can we have all this." It is: what is the smallest
version that ALREADY FEELS LIKE THIS?**

### THE SLICE (this is the build target; everything else is content bolted onto a working game)
> **One province. One firebase, inside the AO, running its clock. A VC organization living in that
> same province — bases, patrols, and a night attack that can come to your wire. Three mission types:
> PATROL / VILLAGE RAID / BASE ASSAULT. Village allegiance. Rank.**

**If that slice grips for ten hours, everything else on the list is content. If it does not, tunnels
will not save it.**

| Ruling | Items |
|---|---|
| **IN THE SLICE** | persistent province · firebase-in-AO · 3 mission types · allegiance ↔ manpower · rank · silent squad XP · living-firebase ambience · the authored threshold |
| **STAYS FROZEN** | **tunnel interiors** (a second game: different movement, light, and combat — it will eat a year). **Tunnel MOUTHS as surface objectives you mark and satchel: IN SCOPE TODAY.** Going down the hole is the **first thaw** once the core is undeniable. |
| **STAYS FROZEN** | supply logistics sim · driveable/flyable vehicles · coop · riverine · POW capture · full-volume battle director |
| **KILLED** | player stat progression (§5.1) |

---

## 9 · WHAT THIS COSTS IN CANON

| Doc | Amendment |
|---|---|
| **ADR-008** (firebase hub spine) | Hub is IN the world, not a separate scene/seed. Patrol = walk out the wire. |
| **ADR-010** (determinism) | Strengthened: world gen gets a dedicated RNG; stable generator-indexed object IDs; a two-generation hash probe is the gate. |
| **ADR-006** (scoring) | Survives, but the **province ledger outranks the mission score.** Kills still pay zero; now they also *cost* you, via §4. |
| **GAME_GUIDE §3** | The loop becomes: province → firebase (living) → HQ board → walk or fly → AO window → back. |
| **GAME_GUIDE §4.4** | Player stats killed; squad XP goes silent/behavioral; **rank added**. |
| **GAME_GUIDE §4.6** | Objective count scales by mission type (1–2 / 2–3 / 3–4), not a flat 2–4. |
| **GAME_GUIDE §6** | Slice declared; tunnel interiors reaffirmed frozen with mouths in scope. |
| **NEW: ADR-017** | The Persistent Province & the AO Window |
| **NEW: ADR-018** | Progression: rank gates authority, never ability |
| **NEW: ADR-019** | Hearts & Minds: allegiance ↔ manpower regeneration |
| **NEW: ADR-020** | The Authored Threshold: guarantees, not rails |

---

## 10 · THE BILL (named tradeoffs — no decision is free)

1. **The province ledger is a save-format break.** ADR-007's SaveData grows a province. The migration
   is already a live no-op (bead z90e) — this forces it to become real.
2. **The determinism probe will find bugs, and they will not be fun ones.** Budget for it. A province
   that comes back subtly wrong is worse than no province at all.
3. **Firebase-in-AO means the firebase is inside the perf budget of a live 1.5km world.** The hub used
   to be cheap and alone. It is not anymore.
4. **The authored threshold is hand work in a procedural game.** It is a weighting pass on the
   generator, and it will want to become a script. It must not. The Arbiter guards this.
5. **Allegiance is a systems-design tarpit** if we let it become a number the player optimizes. It
   must be felt (ambush density, trap warnings, informers), and mostly *unexplained*.
6. **We are adding a strategy layer to a project whose combat only just got good.** The combat
   foundation (T0/T1) is signed off. **T2 legibility and T3 the thinking enemy are still open, and
   this decree does not replace them — the province is worthless if the enemy inside it is stupid.**

---

## 11 · BUILD ORDER (the Arbiter's proposal — Summoner ratifies before code)

**Nothing here starts until the Summoner opens the gate.**

0. **THE THINKING ENEMY** (T3 + the stealth economy — beads pwu5, 0623, gpvb). *Unchanged and still
   first.* The province is a stage; this is the actor. A living province full of stupid VC is a
   diorama. **This also fixes the standing P0: `take_damage()` stamps the COMBAT beacon before the
   death check, so a silent kill still shouts, and a gunshot carries 55m when canon says 150m.**
1. **The determinism probe** — prove the world rebuilds bit-identical. Cheap, and it gates everything.
2. **The province ledger + firebase-in-AO** — the architecture. Patrol = walk out the wire.
3. **Hearts & minds** — allegiance ↔ manpower. The story engine.
4. **Rank + silent squad XP** — the come-back loop.
5. **The living firebase** — 24/7 ambience under the Ambience Law.
6. **The authored threshold** — the first patrol, last, because it is a weighting pass over finished
   systems and it can only be tuned once they exist.

---

*The Council has spoken. The Summoner holds final authority.*
