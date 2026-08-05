# GAME DESIGNER — Hearts & Minds: what the player EXPERIENCES

**War Room:** 2026-08-05 · **Architect:** Game Designer · **Scope:** felt experience only.
Analysis, no code. Built on the briefing's verified ground truth (nothing of this system exists;
`EvidenceLedger` and `CampaignState.add_threat_modifier` are the two live hooks).

---

## 0 · The frame

The Summoner has ruled the system INVISIBLE. That means the design problem is not "what does
allegiance do" — it is **what does a man on a trail notice**. Everything below is written from
inside the player's boots on a patrol, and every recommendation names what it sacrifices.

Two things must be true at once, and they fight each other:

1. **The player must never be told.** (ADR-019 §4)
2. **The player must not conclude the game is broken.** (ADR-019's own named failure mode)

The whole craft is in the gap between those. My position: **the tells carry the SIGNAL, and
exactly one thin diegetic channel carries the ATTRIBUTION.** Signal without attribution is
rubber-banding. Attribution without signal is a meter. You need both, and they must live in
different places — the world tells you WHAT, and the AAR names WHO, once.

**One structural ruling up front, because everything in §A depends on it:**

> **Build FOUR STATES with hysteresis, never a smooth curve.**

A continuous invisible gradient is *guaranteed* to be unnoticed — every patrol is 3% worse than
the last, which is indistinguishable from a bad roll. Discrete states with a visible delta at the
transition are the only shape a player can perceive without a readout. The internal number can be
continuous; **what the world renders must snap**, and must not flip back and forth on a boundary.
*Sacrificed:* the simulationist's smooth field, and the ability to represent "slightly annoyed."
The states must be so distinct that the player can describe them to a friend.

---

## A · THE TELL LADDER

Four rungs (plus the fifth, unlisted, that only the burned earn). Read down the columns: the game
is not adding threat as you descend — **it is withdrawing help.** That distinction is the whole
tonal argument, and it is also cheaper to build, because subtraction is free.

Cast note, load-bearing throughout: `civilian.gd:145-150` already ships
`civ_kid`, `civ_kid_b`, `civ_farmer_f/_b/_c`, `civ_elder/_b`. **Who is standing in the ville is
already a spawn-composition roll.** It is the single highest-value tell per unit of work in this
entire document.

---

### RUNG 1 — COOPERATIVE ("they want you here")

**The approach.** You hear the ville before you see it. A dog. Somebody hammering. The trail in
is packed bare earth, walked flat by feet this morning.

**The people.** Full spread — kids, women, old men, and the working-age farmers actually in the
paddy where the schedule says they should be (`civilian_schedules.gd:31-48`). Two kids break
off and follow the squad at ten metres, and keep following. Laundry is out. The cooking fire is
lit and someone is **at** it.

**The look.** The elder under the tree does not get up and does not stop what he is doing. That
is not indifference — it is a man who is not afraid of you. Villagers walking the same trail
step aside and keep walking.

**The gift.** *One named villager* (see §D) walks to the edge of the ville and **points down a
trail.** No dialogue. Whatever he points at is there — a wire, a pit, a waiting element. This is
the top of the ladder's entire payoff: **at COOPERATIVE, the district is your point man.**

**The ground.** Trails around the ville are clean. Not "fewer traps" — *clean*, and reliably so,
which is the thing the player builds a habit around and later loses.

**Your squad.** The point man's caution posture relaxes; walking pace picks up. Nobody says why.

**The net.** At the wire, the S2 line names the ville by name and does it warmly.

**The enemy.** Local contact is *displaced*, not absent: the fights happen 400m out, on the
approaches, because they cannot get close without being reported. The player never sees the
reason. He just notices he keeps meeting them early.

---

### RUNG 2 — WATCHFUL (the default; where a fresh ville sits)

**The people.** Everyone is present, but nobody stops working. You are weather. Kids are in the
doorways, not on the trail. The farmers keep their backs to you.

**The look.** Nobody meets your eye and nobody avoids it either.

**The ground.** Traps exist on the *approaches* at a baseline rate. Nobody warns you and nobody
sets one for you.

**Your squad.** Nothing. Silence is the tell.

**The enemy.** **Hasty contact.** A VC element bumps you — both sides surprised, they fire from
wherever they were standing, somebody drops, they break and run. It reads as an accident,
because it was.

**The net.** The AAR names the district as QUIET or WATCHFUL and says nothing else.

---

### RUNG 3 — CLOSED ("the ville knows something you don't")

This is the rung that must land hardest, because it is the **warning shot** — the last state from
which the player can still change his mind.

**The approach.** The paddy is empty at an hour the schedule says WORK. That is the first thing
wrong and it is visible from 200m.

**The people.** **No children. None.** Only old men, and one or two women who do not look up.
The families moved out, which means somebody told them to. Numbers are down by half.

**The look.** Work *stops* when you enter and resumes when you pass. A woman picks up a child and
carries it inside without hurrying — the unhurried part is what makes it awful.

**The ground.** The cooking fire is **banked but warm**. There is rice in a pot with nobody at it.
Sandals in the mud by a doorway. Somebody left in the last twenty minutes.

**Your squad.** Your point man stops and says the line — *"somebody knew we were coming."* This
is the ONE bark that should exist at this rung, and it must be an observation, never a judgment.

**The ground, again.** Trail traps around the ville have roughly doubled and — critically — one is
on a trail the player has walked safely before. **Familiar ground turning is the tell.** New ground
being dangerous teaches nothing; ground you trusted going bad teaches everything.

**The enemy.** **Prepared contact.** They are sited at a trail junction, in cover, facing the right
way, and they shoot first. They do not break at the first casualty. They break on a whistle, in
order, on a bearing.

**The net.** The S2 line at the wire: the district is COLD, expect contact.

---

### RUNG 4 — HOSTILE (the ville is infrastructure)

**The approach.** **The ville is empty and the fire is still burning.** That sentence is the
system's flagship image and it should be built first, before anything else in this document.
Nobody is home. The pot is on. A chicken in the path. That is it.

**The look.** There is nobody to look at you. The absence *is* the look.

**The ground.** The paddy dikes are wired. The obvious approach is the mined one. Punji at the
treeline gap you would naturally use.

**Your squad.** The point man does not bark, because there is nothing to see and he doesn't know
either. **At HOSTILE the squad goes quiet** — the player reads this as his men getting worse,
which is wrong and is exactly why §B exists.

**The enemy — the flagship consequence.** They are **where you planned to walk**.

`FieldDirector.player_route` (`field_director.gd:1180`) already carries the player's own
grease-pencil line as data, and `_pick_patrol_location` already consumes it. **At HOSTILE
standing, the drawn route leaks.** The ambush is on the line he drew, on his own paper, before he
walked it. Prepared L-shape, near element at 15m, command-initiated, with a blocking element sat
on his withdrawal bearing.

This is the most terrifying tell available in this game and it is **nearly free to build**,
because the route exists and the ambush machinery exists. Nothing else in the design produces
the specific horror of *"they read my map."*

*Sacrificed:* this must be rate-limited and it must be survivable, or it becomes a punishment
that reads as a cheat. My recommendation: it fires on **one** leg of the route per patrol, never
the first leg (he must be committed and away from the wire before it lands), and the S2 line at
the wire must have already told him the district was hostile. **Never spring a route leak on a
player the game has not already warned.** That is the fairness floor.

**The night.** Threat tier climbs through `add_threat_modifier`, and `siege_director.gd:11`
already turns that into the odds the wire gets hit: 0.05 → 0.15 → 0.30 → 0.45. So the last tell
in the ladder is that **he stops sleeping.** The system's loudest consequence is already wired
and needs no new machinery.

---

### RUNG 5 — the burned district (an axis, not a rung)

Not "more hostile." **Different in kind.** After arson:

- The ville does not repopulate. It stays a black smear on his map with nothing living in it,
  and he walks past it every patrol for thirty hours. Permanent, silent, unscored.
- Contacts stop being **local** and start being **regional** — men he meets are not from anywhere
  near there. Farmers-with-rifles are replaced by regulars: better weapons, better fire
  discipline, they do not run.
- Traps appear on ground he has walked safely for hours.
- The night chance climbs and stays climbed longer than any other input.

**Why the tells must be regional, not local:** it is the historically true thing (the bill comes
from the district, not the hamlet), it is the ADR's own "grinds against you in a way you can feel
and cannot immediately explain," AND it is the reason §B is mandatory. A consequence that cannot
be traced by the player must be *named* by the game once, or it is noise.

---

### The tell channels, ranked by value-per-unit-of-work

| # | Channel | Cost | Why it is worth it |
|---|---|---|---|
| 1 | **Village population composition** (kids/women present vs. only old men vs. empty) | Very low — a spawn roll on an existing cast | Readable at 200m, in one glance, with no UI, by a player who has never been told anything |
| 2 | **The empty ville with the warm fire** | Low — spawn suppression + a lit-fire prop | The single strongest image the system can produce |
| 3 | **Route leak → pre-positioned ambush** | Low — `player_route` is already data | The most legible consequence in the game: he drew the line himself |
| 4 | **Ambush QUALITY ladder** (hasty → prepared → L-shape) | Medium — placement + break behaviour | Turns "more enemies" (a difficulty slider) into "better enemies" (a story) |
| 5 | **The withdrawn warning** (the man who used to point, gone) | Very low | Loss aversion teaches harder than punishment, and it is a subtraction |
| 6 | **Night siege frequency** | **Already built** (`siege_director.gd:11`) | Free. The threat road is the retrofit-free answer |
| 7 | **Trail trap density on FAMILIAR ground** | Medium | Only works if the ground was trusted first |
| 8 | **Point-man bark at CLOSED** | Very low | One line, one rung; do not spread it across the ladder |

---

## B · THE LEGIBILITY PROBLEM

ADR-019 predicts the failure precisely: *burns three villes in hour two, gets mauled in hour nine,
concludes the game is broken.* It then offers "deliberately thin" briefing language as the
mitigation. **I do not think the sanctioned language, as written in the ADR, is sufficient** —
and I want to say exactly why, because this is a real disagreement with the decree's current text.

`"THE DISTRICT IS HOSTILE. EXPECT CONTACT."` states an **effect with no antecedent**. It answers
"what is happening" and it never touches "because of what." A player reading it seven hours after
the act has no route back to his own behaviour, so his most economical explanation is *the game
rolled dice* — or worse, *the game is scaling difficulty to me*. Rubber-banding is the single most
trust-destroying misread available here, and this line does not defend against it.

### The minimum legibility — three channels, no more

**1 · THE BARK, at the moment of the act.** One line from a squadmate, fired once, at the
transgression itself. **Observation with a forecast, never a judgment.**

- Good: *"Word'll be out on us by dark."* / *"They'll remember this one."*
- Forbidden: *"That was wrong, sir."* — a squadmate with a conscience is a morality meter with a
  face on it, and it is the PS2 cheese by another route.

This is the attribution ANCHOR. It costs one VO line and it is the only channel that fires while
the cause is still on screen. Without it, everything downstream is unattributable.

**2 · THE AAR SENTIMENT LINE, at the wire.** One line per patrol. It must **name the cause once,
by proper noun**:

> `BINH SON DISTRICT: HOSTILE. THEY HAVE NOT FORGOTTEN AN THO.`

That second sentence is the whole fix. It carries **no number, no magnitude, no trend, no
instruction** — it is a memory, phrased the way an S2 briefer would phrase it. **I recommend this
as a formal amendment to ADR-019 §4**: sentiment language may name a past CAUSE. It may never
name a future PRICE. *"They have not forgotten An Tho"* is diegetic memory. *"Burning villages
increases hostility"* is a tutorial and stays forbidden.

*Sacrificed:* the purest form of the invisible system. A player who wants no explanation gets one
sentence he did not ask for. I judge that cheap against the alternative, which is a player who
quits believing the game cheats.

**3 · THE S2 BOARD at the firebase.** Standing, pull-only, refreshed between patrols. Same
vocabulary. It never pushes itself into his face; he walks over and reads it or he doesn't. Its
job is to let a player who *is* suspicious go and check — the availability of the answer is what
prevents the paranoia, more than the answer itself.

### Where exactly is the line between "briefing" and "meter"?

Four clauses. A sentiment surface must fail **all four** to be a meter; passing any one of them
starts the slide.

| # | A METER has… | The briefing must therefore… |
|---|---|---|
| 1 | **Magnitude** — degrees, bars, percentages, arrows | Have **states only**, ≤4 of them, no trend indicator, no "worsening" |
| 2 | **Liveness** — it updates while you act | Update **only at the wire**, at the bank point. If he can watch it move while he does the thing, he will optimise it |
| 3 | **Completeness** — every row is populated | Be **partial**. A district he has never patrolled reads UNKNOWN forever. Missing rows are what stop a board being a scoreboard |
| 4 | **A stated rule** — it tells you what moves it | Name a **past cause**, never a future price. Memory, not mechanics |

Clause 2 is the load-bearing one and the one most likely to be lost by accident. **The moment
sentiment can be observed in the field, the player A/B-tests it.** He will shoot one villager,
check, shoot another, check. That is the tarpit ADR-019 names, and clause 2 is the only thing
standing between the design and it.

### The human-scale tell that does the most legibility work

**A named person, not a village.** One villager per ville who does one small thing for you —
points at a bearing, walks a kid away from a trail he doesn't want you on. When standing falls:

> **He is not there. Somebody else is sitting where he sat, and does not look up.**

No line, no toast, no explanation. This does more legibility work than any UI, because a player
who has *met* someone tracks his absence automatically. It is also the cheapest thing in the
document: a flag on one spawned `Civilian` and one existing schedule leaf.

### Two live bugs that gate this entire section

Both are named in the briefing and both bear directly on felt experience:

- **`on_atrocity_witnessed` has no definition anywhere** (`player.gd:249-250`), while the toast
  `"THEY SAW YOU DO THAT"` DOES fire. **The game currently makes a promise it has never once
  kept.** That toast is, right now, the loudest hearts-and-minds signal in the build — and it is
  attached to nothing. It must be wired or removed before any tell is authored on top of it.
- **`_bank_patrol` discards `civilian_deaths`** (`field_director.gd:1768-1776`), so
  `debrief.gd:89-90`'s noncombatant line only prints when the player **dies**. The bottom rung of
  the ladder has no input on a successful patrol. Nothing in §A can be built until this is fixed.

### One proportionality ruling the player must FEEL

The relative weights are the systems designer's call, but the felt shape is mine:

- **Arson is the biggest single move by a wide margin.** It must be an event, not a datum.
- **One civilian killed in a firefight must be close to noise.** If a stray round in a real
  contact carries real weight, the player learns to refuse to fight anywhere near a ville — which
  removes the most interesting terrain in the game from play and makes the system a chore.
- **Repetition is what bites.** Careless artillery three patrols running should cost more than
  the sum of its parts. The pattern is the crime, not the incident.

---

## C · THE FAST ROAD

ADR-019 §3 is binding and it is right: if burning is always wrong, this is a morality meter with
a correct answer and the tone dies. But "must pay" is not a design. Here is the payoff, concrete.

### What he gets, RIGHT NOW, for levelling a ville

**1 · The harassment stops, and he can feel it inside ten minutes.**
The informer flip already ships and is genuinely hated: `civilian.gd:336-353` — a villager sees
you, runs, and 25 seconds later *"THAT VILLAGER TALKED — THEY KNOW YOU'RE HERE."* A hostile ville
is the source of that. Burn it and **that road is gone**, for as long as it takes to rebuild.
This is the correct flagship payoff because it is not a reward the game grants — it is the removal
of a live mechanic the player already resents.

**2 · The patrol is OVER, and he is inside the wire before dark.**
In an open patrol sim the scarcest resource is **time**, and the scariest thing in the game is
being outside at night. Burning is fast and certain; searching is slow and uncertain. **Buying
your way out of a night movement is a real payment.** No score, no toast, just the sun still up.

**3 · The infrastructure goes, and the intel with it.**
Caches and tunnel mouths in the ville burn out and yield their intel — the economy that already
exists (`player.gd:897,918`; intel spends at the wire, `field_director.gd:1382-1386`) — without
the hour of careful searching. *Per `recon-bodies-give-intel-only`, no new body-search reward is
invented; this is the existing cache/document channel, delivered faster.*
**The fast road is a TIME-for-standing trade.** That is the historically true shape of it.

**4 · The district goes QUIET for two or three patrols.**
This is the crucial one and it is the one a designer's instinct will resist. **Terror works in
the short term.** Local VC lose the ville's shelter, food and eyes; local contact rate near that
ville *drops*. The player runs three clean patrols and concludes: **it worked.** He must be
allowed to conclude that, and he must be *correct* while he concludes it. If the bill arrives on
patrol two, the fast road is a trap with a delay timer and the player will read it as one.

### The bill, later and quiet

- **Regeneration outpaces attrition.** He keeps killing and the numbers never go down. Density
  climbs *district-wide*, never localising back to the ville — which is why §B's cause-naming
  line is not optional.
- **Quality, not just quantity.** Hasty contacts become prepared ones. Farmers-with-rifles become
  regulars who do not break.
- **The night.** Threat tier → `siege_director.gd:11` → 0.05 becomes 0.30. He stops sleeping.
- **The withdrawal.** No warnings, no clean trails, no man who points. He does not notice the day
  it stops. He notices the day he steps on something a man used to point at.

### The knife-edge: the SLOW road must also pay, in the same currency

If tending villages is only *"avoid the bad thing,"* it is a chore, and a chore with no meter is
an invisible chore, which is the worst object in game design. **Both roads must pay in SAFETY and
TIME** — the only two currencies this game has:

| | Fast road (burn) | Slow road (tend) |
|---|---|---|
| **Pays** | Time + safety **now** | Time + safety **later** |
| **Bills** | Safety **later** | Time **now** |
| **Feels like** | Decisive | Patient |

That symmetry is the only formulation in which neither answer is "correct," and it is the whole
design in one table.

### The balance target, stated so it can be argued with

**Burning should be net-positive for roughly the next three patrols and net-negative from roughly
patrol six onward.** On a 20-40 hour tour, a player who burns everything must be able to **win the
short game and lose the long one** — and "lose" must mean *the war grinds*, never *you lose*.
Pillar 5 (fail forward, not fail states) forbids a death spiral. **Recovery must be possible,
slow, and must require ACTION rather than time** — a district that heals by waiting teaches the
player to wait, which is the least interesting verb in the game.

*Sacrificed:* some players will burn everything and have a genuinely good six hours. That is not
a bug, that is §3 working. But it means a demo or a first impression can show the shortcut paying
and none of the bill — a marketing risk, honestly named, not a design one.

---

## D · THE FIRST TEACHING MOMENT

ADR-020 §2 already guarantees *"a villager who is a person, not a target."* It does not say what
that beat IS. Here is my nomination, and my case for why no other candidate works.

> ## THE OLD MAN WHO POINTS
>
> On the first patrol, at the guaranteed ville, one elder is sitting where elders sit
> (`civilian_schedules.gd:81-98` — `ACTION_SIT`, and `civilian.gd:428-430` already gives elders
> their own praying/sitting chain). As the squad comes in, **he gets up.** He walks to the edge
> of the ville, stops, and **points down one of the two trails out.** He says nothing. Then he
> walks back and sits down.
>
> **What he points at is there.** A wire, a punji pit, a waiting element. Take that trail and you
> eat it. Take the other one and you live.

### Why this beat and not another

**It teaches personhood through AGENCY, not vulnerability.** The default candidate — a kid, a
mother, something fragile — teaches *"villagers can be hurt,"* which is a guilt trip, which is the
PS2 cheese the Summoner rejected by name. This beat teaches *"villagers KNOW THINGS."* That is the
actual premise of hearts and minds, and it is the premise that makes both roads legible.

**It teaches the entire system in one gesture, with zero words.** These people know where the
danger is. They can choose to tell you. **Therefore they can choose not to.** The player is never
told the second half — he derives it, which is the only way it sticks.

**It is refusable, per ADR-020 §3's binding test.** Walk past. Ignore the point and take the
trail anyway. Shoot him. The game says nothing, scores nothing, and does not repeat itself.

**It is the exact inverse of a mechanic that already ships.** The informer (`civilian.gd:336-353`)
runs and tells THEM. This man stays and tells YOU. They are two ends of one wire, and the player
should meet both in hour one — ideally in the same patrol, ideally in different villes.

**It is cheap.** A schedule leaf that walks to a point, one gesture/point pose, and a trap that
already exists. Zero new systems.

**And this is the deciding argument: its ABSENCE is legible for the next thirty hours.**
On patrol nine the player walks into a ville and **nobody gets up.** He knows what that means,
instantly, without a word, because of a thing that happened in hour one. A teaching beat that
cannot later be *withdrawn* teaches nothing about a system whose whole subject is change.
Every other candidate beat I considered fails this test.

**If the player kills him:** nothing. No toast, no score, no reprimand. One squadmate line
(*"Christ."*), fired once, and the world goes quiet. That is the fossil-free, non-lecturing
version of the `"THEY SAW YOU DO THAT"` toast that currently fires into a void.

**One consequence of adopting this:** the first ville must open at **COOPERATIVE, not neutral.**
A cold start makes the top of the ladder something the player never sees and therefore never
misses, and the whole withdrawal mechanic goes with it. *Sacrificed:* the best state in the
system is given away for free in hour one, before it is earned. I judge that correct — you cannot
lose what you were never given, and this system is built almost entirely out of loss.

---

## E · WHAT THIS COSTS (no free lunches)

**1 · Nobody notices the system exists.** ADR-018:88-91 names this exact failure for silent squad
XP, and it is **worse here** — squad XP's affordance is a MAN whose behaviour you watch every
patrol; this system's affordance is a statistical field. Mitigation is the four-state ruling in §0
plus loud top and bottom rungs. *Sacrificed:* the simulationist smooth gradient, permanently.

**2 · It reads as difficulty scaling.** The most likely and most damaging misread. A player who
concludes the game rubber-bands stops trusting every other system in the build. §B's cause-naming
line is the only defence, and it is one sentence wide.

**3 · Every tell is world content.** This doubles down on civilians, which ADR-019 already names
as art-blocked and behaviourally thin. The empty-ville tell alone needs spawn suppression, a
warm-fire prop, and a composition roll. The composition roll is cheap; the props are not.

**4 · The withdrawal tells cost you the game's warmest moments.** The friendly ville is the best
thing in this world, and the system's mechanism is taking it away. A player who never earns one
never has the thing to lose — hence §D's cooperative first ville, and hence a real cost: the good
state is given away rather than earned.

**5 · A system with no readout cannot be QA'd by eye.** It needs a dev-only surface (the KEY_9
combat-lab pattern), and that surface is a fossil-law hazard the day it leaks into a build.

**6 · Per-village state costs save schema and rebuild determinism.** ADR-010 requires the ville to
come back identical; standing is now an input to that. Systems designer's problem, but the player
feels it as continuity, so it is named here.

**7 · The fast road paying means the shortcut genuinely works for hours.** That is §3 functioning,
and it is also a first-impression risk: a short demo can show the payoff and none of the bill.

**8 · Two systems, one theme.** If the PARKED cord tokens ever unpark, they and this both narrate
atrocity — the fossil law applied to design. My recommendation: **hearts-and-minds owns the
WORLD's response; cord tokens (if ever) own the PLAYER's interiority.** If that line cannot be
held cleanly in play, cut the tokens. This system is the one the Summoner described unprompted,
twice, as the answer to "the war is the story."

**9 · The route leak is a loaded gun.** §A rung 4's flagship tell is one tuning mistake away from
reading as a cheat. It needs the rate limit, the never-on-leg-one rule, and the mandatory prior
warning, or it becomes the thing that makes a player quit.

---

## Build-order recommendation (experience-first, not systems-first)

If only a fraction of this gets built, build it in this order — each item is legible on its own
and none of them requires the one after it:

1. **Fix the two bugs.** `on_atrocity_witnessed` and `_bank_patrol`'s dropped `civilian_deaths`.
   Nothing below is honest until these are.
2. **Village population composition** (kids/women → old men only → empty). One roll, whole ladder.
3. **The empty ville with the warm fire.** The flagship image.
4. **The AAR sentiment line, with the cause named once.** The fairness floor.
5. **The old man who points** (§D), and his later absence.
6. **The night-siege road** via `add_threat_modifier` — already built; just feed it.
7. **Ambush quality ladder**, then the route leak last, once the warning channel is proven.

---

*Devil's Advocate should be pointed at: (a) whether the four-state snap is legible or merely
jarring; (b) whether the AAR cause-naming line is the thin end of a meter; (c) whether the fast
road as specced is so strong that a rational player never takes the slow one; (d) whether the
route leak can be tuned to feel earned rather than cheated.*
