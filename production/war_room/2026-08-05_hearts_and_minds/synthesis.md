# THE DECREE — Hearts & Minds / The Invisible Factions System
**War Room:** 2026-08-05 · **Arbiter:** RECON Overseer · **Council:** systems designer, game designer,
writer, devil's advocate · **Status:** design document, awaiting the Summoner's rulings
**Scope:** NOT demo. Main game. One hook laid now, named and justified below.

---

## 0 · THE THING YOU NEED TO KNOW FIRST

You said, earlier today, that levelling a village makes the enemy come after you hard — *"that's the
hearts and minds invisible factions system at work."*

**There is no such system. Not one line of it exists.** `ProvinceState`, `allegiance`, `sympathy`,
`hearts_and_minds` — all four return **zero hits across the whole repo**. ADR-017 and ADR-019 are
decree with nothing behind them, 24 days old, while roughly thirty-five other decisions shipped
around them.

So something else gave you that experience, and finding out what is worth more than the rest of this
document. Three live systems are doing it, and they are doing it well:

- **The evidence ledger and the hunters.** You shoot up a place; gunshots and bodies go into a dated,
  decaying ledger; a toast says `YOU'VE BEEN MADE — THEY'RE MOVING TO CONTACT`; seventy to a hundred
  and ten seconds later, men spawn two hundred metres off *the place where it happened* and walk to
  it. Violence at a place makes armed men converge on that place, on a delay, announced in words.
  **That is hearts and minds as experienced.** It is already shipped and it is genuinely good.
- **The informer.** A villager sees you, runs, and twenty-five seconds later becomes VC. A civilian
  literally changes sides because of what he saw. Live today, and named nowhere the player can read.
- **The night.** Twelve kills on a patrol nudges the threat baseline up, and the threat tier is
  already the odds the firebase gets hit that night — 5%, 15%, 30%, 45%. **A body-count day already
  buys you a worse night.**

And one more, which is the sharpest fact this council produced. **In the demo, the assault is a fixed
timer** — 1440 seconds, 45 men — and *you ruled on 2026-08-04 that day-kills must not affect it.*
You ruled it unresponsive to your conduct, and then experienced it as retaliation for your conduct.

That is not a mistake on your part. It is the most valuable data point we have:

> **A fixed timer plus a toast that named your own act was enough to produce the felt experience of
> an invisible faction system.** The *felt* system is cheap. The *simulated* system is expensive.
> They are not the same purchase, and this project has already accidentally proven which one the
> player notices.

Everything below is built on that.

---

## 1 · WHAT THE PLAYER EXPERIENCES

You ruled this invisible — no meter, no score, no number. So the design question is: how does a man
on a trail *notice*?

**The council's structural ruling: four discrete states, never a smooth curve.** An invisible
gradient where every patrol is 3% worse than the last is indistinguishable from a bad roll, and it is
guaranteed to go unperceived. The number underneath can be continuous. **What the world renders must
snap.**

And the spine of the ladder is **subtraction, not addition**. As standing falls, the game does not
add threat — it *withdraws help*. That is tonally right and it is also cheaper to build.

### The ladder

**COOPERATIVE — they want you here.**
You hear the ville before you see it: a dog, somebody hammering. Full spread of people — kids, women,
old men, and the farmers actually out in the paddy where they should be at that hour. Two kids follow
the squad at ten metres and keep following. Laundry out. Cooking fire lit with someone *at* it. The
elder under the tree doesn't get up and doesn't stop what he's doing — that's not indifference, it's a
man who isn't afraid of you. Trails around the ville are **clean**, reliably, so you build a habit
around it. Contact still happens, but four hundred metres out, on the approaches — they can't get
close without being reported, and you never learn that's why. You just notice you keep meeting them
early.

**And one villager walks to the edge of the ville and points down a trail.** No dialogue. What he
points at is really there — a wire, a pit, a waiting element. At COOPERATIVE, **the district is your
point man.**

**WATCHFUL — the default, where a fresh ville sits.**
Everyone's present, nobody stops working. You are weather. Kids in doorways, not on the trail.
Farmers keep their backs to you. Nobody meets your eye and nobody avoids it. Traps on the approaches
at a baseline rate — nobody warns you and nobody sets one for you. Your squad says nothing; the
silence is the tell. Contact is a **hasty bump**: both sides surprised, they fire from wherever they
were standing, somebody drops, they break and run. It reads as an accident because it was.

**CLOSED — the ville knows something you don't.** *This is the warning shot, the last rung from which
you can still change your mind.*
The paddy is empty at an hour it shouldn't be — visible from two hundred metres, and it's the first
thing wrong. **No children. None.** Only old men and a woman or two who don't look up. Numbers down
by half. The families moved out, which means somebody told them to. Work *stops* when you enter and
resumes when you pass. A woman picks up a child and carries it inside **without hurrying** — the
unhurried part is what makes it awful. The cooking fire is banked but warm. Rice in a pot with nobody
at it. Sandals in the mud. Somebody left in the last twenty minutes.

Your point man stops and says one line — *"somebody knew we were coming."* An observation, never a
judgement.

And a trap turns up on a trail **you have walked safely before.** New ground being dangerous teaches
nothing. Ground you trusted going bad teaches everything.

Contact becomes **prepared**: sited at a junction, in cover, facing the right way, shooting first.
They don't break at the first casualty. They break on a whistle, in order, on a bearing.

**HOSTILE — the ville is infrastructure.**
**The ville is empty and the fire is still burning.** That is the flagship image of this whole system
and it should be built before anything else in this document. Nobody home. Pot on. A chicken in the
path. That's it. There is nobody to look at you, and the absence is the look.

The paddy dikes are wired. The obvious approach is the mined one. Punji at the treeline gap you'd
naturally use. Your point man doesn't bark, because there's nothing to see and he doesn't know either
— **at HOSTILE the squad goes quiet**, and you'll read that as your men getting worse.

And the flagship consequence: **they are where you planned to walk.** Your drawn route already exists
as data the game holds. At HOSTILE, the route leaks. The L-shape sits on the line *you drew, on your
own paper, before you walked it.* Nothing else in this design produces the specific horror of *"they
read my map."*

**Then you stop sleeping.** Threat climbs, and threat is already the odds the wire gets hit at night.
The loudest consequence in the design is already wired and needs nothing new.

**BURNED — an axis, not a rung.**
Not "more hostile." Different in kind. The ville doesn't repopulate — it stays a black smear you walk
past every patrol for thirty hours, permanent, silent, unscored. Contacts stop being *local* and
become *regional*: the men you meet aren't from anywhere near there. Farmers-with-rifles are replaced
by regulars with better weapons and better fire discipline who do not run.

### What the council STRUCK from your ADR's own list of tells

ADR-019 §4 lists "trails that used to be clean and are now wired" and "the ambush that was waiting"
as tells. The Devil's Advocate is right that most of that is **a rate wearing prose**, and a human
cannot perceive a rate change without a counter — which you have banned. This game is already
saturated with unattributable randomness: siege rolls, hunter timers, 55-metre evidence scatter,
informer rolls, baseline threat drift.

**So trap density and ambush frequency are demoted to texture. They are not the signal.** The signal
is only ever a **discrete, local, attributable event you could describe to a friend**: the ville that
had people and now has none. The man who used to point, gone. A trap on ground you walked clean last
week.

### The one thing that keeps this fair

All four architects, working independently and without conferring, arrived at the same fix by four
different doors: **the game must name the place. Once.**

ADR-019's own sanctioned line — `THE DISTRICT IS HOSTILE. EXPECT CONTACT.` — states an effect with no
cause. A player reading that seven hours after the act has no route back to his own behaviour, so his
cheapest explanation is *the game is scaling difficulty to me.* That misread is the single most
trust-destroying thing available here.

So: **the sentiment line may name a past CAUSE by proper noun. It may never name a future PRICE.**

> `BINH SON DISTRICT: HOSTILE. THEY HAVE NOT FORGOTTEN AN THO.`

*"They have not forgotten An Tho"* is diegetic memory. *"Burning villages increases hostility"* is a
tutorial and stays forbidden. This is a formal amendment to ADR-019 §4 and it is **Decision 1**.

Plus one squadmate bark at the moment of the act — observation with a forecast, never judgement.
*"Word'll be out on us by dark."* Not *"that was wrong, sir"* — a squadmate with a conscience is a
morality meter with a face on it.

### Where the line sits between "briefing" (allowed) and "meter" (forbidden)

A meter has four properties. The sentiment surface must fail **all four**:

| A meter has | So the briefing must |
|---|---|
| **Magnitude** — bars, degrees, arrows, trend | Have **states only**, four of them, no trend, no "worsening" |
| **Liveness** — it updates while you act | Update **only at the wire.** If you can watch it move while you do the thing, you will A/B-test atrocities |
| **Completeness** — every row filled | Stay **partial.** A district you've never patrolled reads UNKNOWN forever |
| **A stated rule** — it tells you what moves it | Name a **past cause**, never a future price |

Liveness is the load-bearing one and the one most likely to be lost by accident.

The writer adds a period-correct guard worth having: **the S2 board's rating is stale and dated** —
`SURVEYED 14 DAYS AGO`. That defeats optimisation structurally, it is historically accurate (the real
Hamlet Evaluation System filed exactly this way), and it is the comix joke: the horror is the form
that was filed, not the atrocity.

### The first teaching moment

> **THE OLD MAN WHO POINTS.** On the first patrol, at the guaranteed ville, an elder is sitting where
> elders sit. As the squad comes in, **he gets up.** He walks to the edge of the ville, stops, and
> **points down one of the two trails out.** Says nothing. Walks back and sits down. What he points
> at is really there. Take that trail and you eat it. Take the other one and you live.

It teaches personhood through **agency**, not vulnerability — the fragile-kid version teaches "these
people can be hurt," which is a guilt trip and the PS2 cheese you rejected by name. This teaches
"these people **know things**." From which you derive, yourself, unprompted: *therefore they can
choose not to tell me.* That is the whole system, taught in one gesture with zero words.

It is fully refusable. Walk past. Ignore him. Shoot him. The game says nothing and scores nothing.
(If you shoot him: one squadmate line — *"Christ."* — once, then the world goes quiet.)

**And the deciding argument: its absence is legible for the next thirty hours.** On patrol nine you
walk into a ville and nobody gets up. You know exactly what that means, instantly, because of
something that happened in hour one. A teaching beat that can't later be *withdrawn* teaches nothing
about a system whose whole subject is change.

*Cost, named:* the first ville must open COOPERATIVE, not neutral. The best state in the system is
given away free in hour one before it's earned. Judged correct — you cannot lose what you were never
given, and this system is built almost entirely out of loss.

---

## 2 · WHAT MOVES THE NEEDLE

**The hard truth first, and it reshapes this whole section.** The council checked every input ADR-019
names, against the code:

- **There is no way to burn anything in this game.** `on_structure_burned` exists in the evidence
  ledger with **zero callers**. The only thing that ignites a hut is a napalm run, and it doesn't
  touch the ledger. **ADR-019 is founded on the sentence "maybe one day you just wanna burn down the
  village down the road from you," and the game cannot execute it.**
- **The entire cooperative column has no verbs.** Medcap, supply delivery, tax-collector interdiction,
  detaining suspects — zero hits, all of them. Not one input behind the whole "toward COOPERATIVE"
  half of your ADR's table.

So the honest state of ADR-019 §2 is a two-column table where one column has **one** live input and
the other has **none**. Weighting arson against medcap today is writing an exchange rate for a
currency that hasn't been minted.

**Four inputs exist and can move something this year:** civilian deaths, enemy bodies left behind,
gunfire near a ville, and ears taken.

### The weights

Everything is priced in the units the game already uses. One threat band is 0.25. The biggest lever
in the game today is −0.25 (destroying an AA battery) — a battalion-level event, and **no single act
of personal conduct may exceed it.** The smallest is 0.08. Below 0.02 is beneath the resolution of a
system you're forbidden to read.

`+` moves toward HOSTILE. Scope `V` = that village. `AO` = everywhere.

| Conduct | Weight | Decays over | Scope | Buildable today? |
|---|---|---|---|---|
| Civilian killed, direct fire, per body | **+0.06** | 12 patrols | V | **Yes** — the count already exists |
| Civilian killed by artillery or airstrike | **+0.09** | 12 | V | Partial — the killer isn't recorded |
| Village structure destroyed or burned, per hut | **+0.05** | 16 | V | **No — no burn verb** |
| The ville is gone (latched at half its huts) | **+0.10** | 20 | V | No |
| Prisoner or surrendered man executed | **+0.12** | 20 | V | Partial — surrender state exists |
| Ear taken in sight of a civilian | **+0.08** | 20 | V | **No — the reaction is a dead no-op** |
| Enemy bodies left in the ville, past the third | **+0.02** | 6 | V | Partial |
| **Prisoner taken alive** | **−0.05** | 10 | AO | **Yes** — the verb ships |
| **Fire discipline** — passed within 150m of a ville and left no gunshot inside its radius | **−0.04** | 8 | V | **Yes** |
| Medical aid to a civilian | **−0.10** | 12 | V | No verb |
| Supplies delivered | **−0.06** | 10 | V | No verb |
| VC tax collector interdicted | **−0.15** | 12 | V | No verb, no actor |
| Village defended from a night raid | **−0.20** | 16 | V | No — the siege only ever attacks the firebase |

### Why these numbers, relative to each other

**Four dead civilians in one ville equals one full threat band.** That's the calibration sentence, and
four because a hooch holds a family. It means a single stray burst is a **smudge, not a catastrophe** —
and that matters, because if one accident brands you, you'll learn to refuse to fight anywhere near a
ville, which removes the most interesting terrain in the game from play.

**Artillery collateral costs 1.5× a rifle death.** Not because the corpse is different — because
*who did it* is different. A trooper who panicked is a man. A battery that dropped on a ville is the
Americans.

**Executing a prisoner (+0.12) is the most expensive single act**, against taking him alive (−0.05).
That **2.4× asymmetry between killing and taking is the moral weight, expressed as arithmetic, with
nobody lecturing.** It's also the cheapest pair to build — both hooks land within twenty lines of each
other.

**Burning is deliberately not catastrophic per hut.** Fifteen huts at a punishing rate would pin the
AO at maximum forever and turn arson into a trap door. A razed ville caps near 1.6 bands: severe,
survivable, decays in twenty patrols. **A permanent brand is a morality meter with a correct answer**,
which is exactly the thing you rejected.

**Repetition is what bites.** Careless artillery three patrols running should cost more than the sum
of its parts. The pattern is the crime, not the incident.

### The hazard you must rule on

The negative column is buildable. The positive column mostly isn't. **Ship this as written and it is a
one-way ratchet with no road back — which violates your own ADR-019 §3 by omission.**

**Fire discipline (−0.04) is the mandatory counterweight**, and it's the reason it's priced as
buildable today: it is the *only* positive earner that needs no new verb, no new actor, no new art.
It's a sweep over evidence positions against village centres, run once, at the wire. **If exactly one
positive lever ever ships, ship that one.**

### Standing laws honoured

- **Bodies give intel only.** Nothing here invents a body-search reward. Leaving bodies in a ville
  costs standing; searching them still pays only intel.
- **Garrison men are soldiers.** The predicate must be written as `noncombatant`, never as the
  civilians group — ARVN are in that group and would silently be counted as villagers.
- **Rumor-first / quest-terseness.** The sentiment line is one sentence at the wire, and the S2 board
  is pull-only. Nothing pushes itself into your face.

---

## 3 · PERSISTENCE MODEL — the recommendation

### A per-village dated, decaying conduct ledger on `CampaignState`, plus one derived AO-wide number that feeds the machinery that already exists.

Your instinct today — that faction memory should follow the same ledger-and-decay shape as the
persistent damage scarring, "but maybe not everything" — is **right, and the council endorses it
without hedging.**

Not a single number per village. A **list of dated entries**, each one knowing when it dies and why it
exists — exactly the shape the threat modifiers already use. That gives three things a single number
cannot buy at any price:

1. **Forgiveness is free and automatic.** A number needs a decay rate, a floor, a clamp and a tuning
   session. A list forgets by construction, and each entry forgets on its own schedule — a burned hut
   can outlive a stray round without a second variable.
2. **The reason is the debrief.** Each entry already carries why it exists. *"They have not forgotten
   An Tho"* is a lookup, not a threshold classifier over an opaque float.
3. **It is auditable when it goes wrong.** When you ask "why did that ambush happen," a list answers.
   A number shrugs.

Capped at sixty entries. On overflow, drop the oldest *good deed* first — never the newest, never a
sin. (Dropping the player's good deeds to make room for his crimes is a bug that reads as malice.)
Decay counts **patrols, not seconds** — village memory that ran on a wall clock would forget while you
slept in the firebase.

### Why not the alternatives

| Model | Sacrifices |
|---|---|
| **One global number** | Kills the design. Your fiction is *"the ville down the road."* A global number means burning a hamlet nine hundred metres away wires the trails outside a village you were kind to. You could never learn the rule, so you could never make a *choice*, and the choice is the system. |
| **Per-district** | Districts do not exist. No district generator, no district id, no district anything. A design keyed on districts ships when `ProvinceState` ships — which, on 24 days of evidence, is **never**. |
| **Per-village only, no global number** | The pressure has nowhere to go. Every consumer that exists reads one AO-wide number. |

### The thing that makes this possible, and it's new

The Devil's Advocate's strongest objection was that per-village persistence needs stable village
identities, those don't exist, and the project's *only* shipped persistent damage does the forbidden
thing — it keys on a rounded world position with a three-metre tolerance, which is exactly what
ADR-017 warns produces "the wrong hut burned."

**The systems designer measured that premise and it's false.** Villages are already generated one per
quadrant in a fixed loop, deterministically. **The loop number IS a stable village id — it is computed
today and thrown away.** The hamlet-naming system already assumes such an index exists.

So the hook is three lines, not three days. **And this design needs no `ProvinceState`, no province
generator, no determinism probe, and no save migration.**

### What it sacrifices, named

- **The AO number smears local conduct across the map.** Wreck village A and nights get marginally
  hotter near village D. Defensible as word-of-mouth — it *is* still a fudge, and it exists only
  because districts don't.
- **Old saves start clean.** Pre-patch sins are forgiven wholesale. Free, and correct.
- **ADR-019's most quotable promise is out of reach.** *"VC manpower regenerates at a rate set by how
  the districts feel about you"* needs a persistent manpower pool, and there isn't one — the hunter
  pool is a per-mission number reset on every world build. **Say it's out of reach rather than letting
  the line ride as if it's close.** Calling a per-mission rate knob a "manpower pool" is exactly the
  drift this project legislates against.

---

## 4 · THE FEEDBACK LOOP INTO THE SIM

`CampaignState.add_threat_modifier` is the road, and it is better than it looks: saved, versioned,
decaying, and **already read by three shipped systems.**

**One change:** conduct becomes a **third term** in the threat sum. Not entries appended to the
existing modifier list — that would double-decay them and pollute the reason list you already read in
the barracks with thirteen new strings, which is a meter by accident.

The AO feels **half** of what any one ville feels. With four villages, wrecking one moves the AO
threat about +0.15 — **MODERATE toward HIGH, and your odds of being hit at night go from 15% to 30%.**
That is ADR-019's delayed cost, in numbers, delivered through machinery that already ships.

### What lands for free, what's a one-liner, what doesn't exist

**Free — these read the threat word and change the instant conduct is added to the sum:**
- **The night siege.** 5% → 15% → 30% → 45%. The loudest consequence in the design, already wired.
- **The barracks and menu sentiment word.** What you already read now includes your conduct.
- **Fire support tier.** ⚠️ **And this one is a defect, not a feature — see Decision 6.**

**One line each:** the siege strength roll (a d50 becomes a d62 under pressure) · hunter pool size ·
**trail trap density per village** (the most legible consumer in the game — literally "trails that
used to be clean and are now wired") · informer density · whether the S2 intel toast fires at all for
a village that hates you. *Withholding information is the correct move here, and your own ADR says so.*

**Does not exist, and must not be implied:**
- **Ambush pre-positioning.** The patrol-location picker reads your route and the push direction from
  the gate, and **no threat value whatsoever.** Worse: pre-positioning is in direct tension with the
  evidence ledger's founding law — that hunters converge on *what you left behind*, never on a route
  you picked in private, because a telepathic enemy reads as the game cheating. **The route leak in
  §1 is a deliberate, narrow exception to that law and it needs your ruling** (Decision 5).
- **Patrol composition.** Enemy quality is one hardcoded resource path at the spawn.
- **VC manpower regeneration.** No persistent pool anywhere.

### The perf law this ships with

The frame is CPU-bound in the AI and there's no gating FPS number, so the price must be **zero
per-frame**, not "small." It is:

> **No consumer may read conduct from a per-frame or per-think loop.** Every consumer reads it ONCE —
> at a night roll, at a walk-out, at a village stamp — and caches it.

Ten passes over a sixty-element list per patrol. Microseconds across a whole session. Plus about 6.6 KB
of save.

And note the alignment, which is not an accident: **ADR-019 forbids a live meter for moral reasons,
and the same prohibition is the performance contract. Anything the player is forbidden to read
continuously is also something the sim never needs to poll.**

*Sacrificed:* conduct can't change mid-patrol in a way the world reflects *this* patrol. Burn a ville
at minute five and the trails outside it aren't wired until you walk out again. Correct on every axis
— performance, fiction (word takes time), and your own thesis that the cost comes later and quietly.

---

## 5 · SCOPE — main game vs. what rides along now

### NOT IN THE DEMO. Ruled explicitly, because it is already drifting in.

`F-8 "Hearts & minds thin slice"` is **an open, unchecked item in the demo backlog right now**, inside
your own Q6 value order. Without an explicit ruling this council would be read as authorising it.

> **F-8 is OUT of demo scope.** It stays on the list as a main-game item with a banner saying so.

The specific ways this eats your ship date, in the order they'd arrive:

1. *"We need a burnable hut for the fast road"* → destructible buildings → the terrain cost that is
   already the suspected cause of the lag you measured. **This single leak can eat the demo alone.**
2. *"Villagers should react"* → real behaviour work on the civilian brain, which is a **performance
   change, not a polish pass** — that class is already measured at ~6.4ms/frame at 16–40 heads.
3. *"Sentiment needs an AAR line"* → touches the debrief → which turns out to be a loop change (§7).
4. *"Per-village needs stable ids"* → only this one is small, and only because of what we measured.

**Refused now, by name, as gold-plating:** a district manpower pool · base rebuild and relocation ·
medcap / supply / tax-collector verbs · `ProvinceState` · civilian sentiment animation states.
None of them changes what you play this month.

### The ONE hook to lay now: the village id

Three lines. The generator emits the quadrant number it already computes; the field director carries
it; the village stamp accepts it. Nothing reads it for months.

**Why this and not the bug fixes.** A hook is defined by what its *absence* makes expensive later.
Bug fixes can happen any Tuesday and change no data shape. But the moment a ledger ships keyed on
anything else — a world position, a hamlet name, a display-order index — **every save written from
then on is keyed on a value that isn't stable.** Move one village thirty centimetres, change one
placement constant, insert one new site kind, and every entry orphans. You come back and **the wrong
hut is burned** — the exact failure ADR-017 calls worse than no persistence at all.

**And the sharper reason: the wrong key is already in the codebase and spreading.** A village-position
hash is live today, feeding the distress-call system. It's the only village-id precedent that exists,
so it's the pattern the next agent will copy. Laying the real id doesn't just enable the ledger — it
**deletes the wrong answer before it becomes the convention.**

*Sacrificed:* a field that nothing reads for months, which is exactly the "built ahead of its wiring"
category the fossil law warns about. Mitigation: one line in the ADR naming what it's for and when it
gets wired, so the next reader triages it instead of deleting it as dead.

---

## 6 · THE MORAL WEIGHT — and the cord tokens

### One theme, two ledgers. Not a fossil.

The cord is **his** ledger — what he became. Private, pause-screen only, an object he can look at.
Hearts and minds is **theirs** — what they think. World-only, never lookable.

> *"You did this." / "They know."*

They face opposite directions, and the writer's rule holds the line: **hearts and minds renders only
what the district DOES. It never itemises the player's conduct back to him.** The cord is the only
artifact of what he did. Two player-facing summaries of his own conduct — *that* would be the fossil.

**One coupling, and only one.** The Devil's Advocate objected that ears feed both systems and the
player double-dips. He's wrong, on a distinction he didn't have: **the cord grows on COUNT, the
district reacts on WITNESS.** An ear taken in an empty treeline grows the necklace and costs nothing.
The same ear taken in front of a woman grows the necklace *and* moves the district. Different facts,
different ledgers, one call site.

That is also the answer to the cord doc's own open question — *"does the squad react to the cord?"*
The squad doesn't react to the necklace. **The village reacts to the act.**

**This design does not depend on the cord tokens shipping.** Hearts and minds must be complete and
felt with zero tokens, or it inherits a parked dependency.

### The tone guard

Your voice on this is underground-comix — twisted, loving, never a lecture, never cheap shock. ADR-019
is explicit that the player discovers he's the bad guy himself, *"with nobody ever telling him he is
the bad guy."* The failure modes that would break that:

- **The sad music moment.** Rule: the world never changes register to mark a death.
- **The NPC who explains the theme.** Rule: nobody in this game has read the design document.
- **A reward for mercy.** Rule: the clean player is **never thanked.** His compensation is mechanical
  — quiet trails, a warning before a wire — and never prose. *The moment we thank him, the system
  dies.*
- **The game withholding to punish.** Rule: withholding is how the district behaves, not how the game
  scores you.

One live tension flagged: the AAR already prints `ROE — WEAPONS DISCIPLINE: +75`. That's safe **only**
as tradecraft — a quiet patrol is a good patrol. **Never add a "NO CIVILIANS HARMED" companion line.**
That one line converts this game into a PS2 morality meter.

### Delete, don't fix: `THEY SAW YOU DO THAT`

The toast fires today. The villager reaction behind it has never once run — the function it calls
**does not exist anywhere in the codebase**, and there's a comment above it confidently describing the
reaction as governed by ADR-019. A tombstone for a corpse that was never born.

Both the writer and the sceptic reached the same verdict independently: **don't wire it. Delete it.**
It is the game narrating your conduct back to you in capital letters, which is precisely what your own
ADR forbids. Replace it with a woman turning and walking inside, silently.

Keep the necklace toast. That's the object speaking, not the game judging.

### The arc

A clean tour: hour one you're a stranger and one old man decides to help you. Hour eight you have
three villes that go quiet when the VC come through, and you don't know why your patrols are easy.
Hour twenty you notice a trail you always took is now the one they warn you off. Hour thirty you are
walking ground that is *yours*, and nobody has ever congratulated you for it.

The fast road: hour one is the same. Hour eight is **better** — the villes you burned stopped selling
you out, the patrols got shorter, you were home before dark every time and you were **right** to think
it worked. Hour twenty the men you meet aren't farmers any more, they're regulars, they don't run, and
the wire gets hit twice a week. Hour thirty you are still killing them faster than you can count and
there are still more of them, and no one has ever told you why.

**Neither ending is authored. Both are earned.**

---

## 7 · THE THREE DEFECTS THIS COUNCIL FOUND

**DEFECT 1 — `on_atrocity_witnessed` is a permanent no-op.** The player-side call sits behind a guard
that is never true, because the function is defined nowhere. The toast fires anyway. **Verdict:
delete the toast and the dead call together** (§6). And note what it proves: *a no-op ran in this game
for weeks behind a confident toast and nobody, including you, noticed.* That is the invisibility trap
demonstrated, not theorised, and it is why the acceptance gate below is non-negotiable.

**DEFECT 2 — civilian deaths are discarded on every successful patrol.** The count is fed correctly,
and the failure path copies it into the result by hand. The success path — which is the *primary* bank
point under open patrol — does not. **The number this whole system eats survives only when you die.**

*But the Devil's Advocate proved it's oversold, and I'm recording his correction because it's a bigger
finding than the bug:* fixing it changes **zero observable behaviour today.** Nothing scores it,
nothing banks it, and the one thing that would print it is a debrief screen that **a successful patrol
never shows.** The screen is only ever built from the mission-*failed* signal — and the field director
has no success signal at all. **The real gap is that a successful patrol has no debrief surface**, and
*that* is what blocks the sentiment line your own ADR sanctions. Fix the key for correctness; know
that the surface is the actual work.

**DEFECT 3 (new, found by this council) — the arson hook is itself a fossil.**
`EvidenceLedger.on_structure_burned` and its weight constant have **zero callers** anywhere — not in
scripts, scenes, data, tests or tools — and it is not in the grandfathered fossil register, so either
the probe misses it or the register is stale. Worth checking when the suite next runs. Either way:
**the hook the design wanted is dead, and there is no burn verb behind it.**

---

## 8 · THE ACCEPTANCE GATE (adopted verbatim from the Devil's Advocate)

ADR-019 already promised a one-playtest gate and left it unfalsifiable. Here is the falsifiable
version, in the shape of your own standing test for the fear work (*"I don't feel in danger"*):

> **After a session in which you treated a village badly, you must — unprompted — say something to the
> effect of *"that ville has it in for me,"* naming the PLACE, not the game.**

Two pre-declared failures:
1. You say **"the game got harder."** → **FAIL.** You felt escalation, which the threat road already
   does. The new system is undetectable.
2. You say **nothing**, and it only surfaces when an agent points at the code → **FAIL**, by ADR-019's
   own words. The remedy is the one ADR-018 already wrote: **cut it. Never paper it over with a UI.**

---

## 9 · BUILD ORDER (experience-first — each item is legible alone)

0. **Lay the village id.** Three lines, now, while the demo is being built. Nothing else from this
   document enters the demo.
1. **Delete the dead atrocity toast and its no-op call.** Fix the dropped civilian count for
   correctness.
2. **Give a successful patrol a debrief surface.** This is the real blocker.
3. **Village population composition** — kids and women, then only old men, then empty. One spawn roll
   on the cast that already ships. The whole ladder, cheapest thing in the document.
4. **The empty ville with the warm fire.** The flagship image.
5. **The AAR sentiment line that names the cause once.** The fairness floor.
6. **The old man who points** — and, thirty hours later, his absence.
7. **The conduct ledger**, feeding the threat sum. The night siege lights up for free.
8. **Trap density and informer density** per village.
9. **Ambush quality ladder** — hasty, then prepared, then the L-shape.
10. **The route leak — last**, and only once the warning channel is proven.

---

# DECISIONS ONLY YOU CAN MAKE

1. **Can the game name the place?** The council wants the after-action line to say *"THEY HAVE NOT
   FORGOTTEN AN THO"* — naming what you did, once, never what it will cost. Your ADR currently forbids
   naming a cause. Allow it, or keep the line effect-only?

2. **Should there be a Zippo?** Your whole hearts-and-minds decree is built on burning a village down,
   and the game has no way to burn anything. Build a burn verb (main game, not demo), or rewrite the
   decree around the things you *can* do — shooting the place up, leaving bodies in it, taking ears?

3. **Should the fast road pay in intel?** Council says burning should pay you **time and safety now** —
   the patrol ends, you're inside the wire before dark, the informers stop — but never intel, caches or
   score, or atrocity becomes simply the optimal play. Agree?

4. **Can AI bullets kill civilians?** Right now only *your* rounds can — every dead villager in the
   game is provably yours. That deletes the war's defining ambiguity (never knowing whose round did
   it), but the alternative punishes you for deaths you didn't cause. Keep it player-only, or open it
   up?

5. **Can the enemy ambush your drawn route?** At maximum hostility, the council wants your own
   pencil-drawn patrol route to leak, so the ambush sits on the line you drew. It is the most
   terrifying thing in the design and it breaks a standing rule that the enemy never knows a route you
   picked in private. Allow it as a narrow exception, or keep the rule absolute?

6. **Should atrocity keep buying you napalm?** Today, raising the AO's threat level unlocks napalm,
   cluster bombs and Spectre. Wreck villages, threat climbs, better ordnance arrives. That is a real
   reward for atrocity sitting in shipped code. Break the link, or leave it?

7. **Do ears move the war, or only the necklace?** Council's answer: **both, split** — the necklace
   grows on the *count*, the village reacts only when someone *watched*. Ears taken in an empty
   treeline cost nothing. Ruling?

8. **Is `F-8 Hearts & minds thin slice` out of the demo?** It's an open item in your demo backlog right
   now. The council says out. Confirm?
