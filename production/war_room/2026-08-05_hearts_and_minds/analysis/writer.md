# WRITER / NARRATIVE DIRECTOR — Hearts & Minds
**War Room 2026-08-05 · The Conscience of the Game · ANALYSIS ONLY, no code written**

Pointers verified this session: `scripts/player/player.gd:226-252` (ear verb + dead
`on_atrocity_witnessed` call at `:249-250`, toast at `:251`) · `scripts/ui/screens/debrief.gd:71-95`
(AAR line register; `civilian_deaths` line at `:89-90`; ROE bonus at `:91-92`) ·
`scripts/missions/field_director.gd:1141-1147` (`CRISIS_CALL`), `:1459-1492` (patrol rebark + crisis
call format), `:1455` ("AO IS %s") · `scripts/autoload/campaign_state.gd:204-223` (threat road) ·
`scripts/allies/ally_base.gd:169-177` (the ONLY bark path on AllyBase — toast channel through the
director) · `VOManager.play_squad` key set, 9 keys total, grepped repo-wide:
`movement_ahead · weapons_free · man_down · doc_moving · on_your_feet · thumper_out · contact_front ·
bandages_over_here`. **There is no line-pool bark system. There are nine VO keys and a toast channel.**
That is the whole voice budget I am writing into, and it is the single most important fact in this
analysis.

---

## A · ONE SYSTEM OR TWO?

### The verdict: ONE THEME, TWO LEDGERS, ONE INPUT ROAD. That is not a fossil.

The fossil law (ADR-023) forbids two **mechanisms doing the same job**. It does not forbid a system
having two faces. `EvidenceLedger` and `CampaignState.threat_modifiers` both track "the enemy is
interested in you" and nobody calls that a fossil, because one is within-patrol and the other is
across-patrol — different clocks, different jobs, one theme.

Hearts-and-minds and the cord are the same shape:

| | The cord (PARKED) | Hearts & minds |
|---|---|---|
| Whose ledger | **His.** What he became. | **Theirs.** What they think. |
| Where it reads | Pause / inventory, on demand, silent | The world, the AAR line, the S2 board |
| Who wrote it | He did, with his hands, one at a time | They did, watching |
| Can he see it move | Yes — that is the point, it is a souvenir | **Never** (ADR-019 §4) |
| Is it a judgment | No. It is an object. | No. It is a district's behaviour. |

**They are the two halves of one sentence: "You did this." / "They know."** Delete either half and
the sentence stops working. The cord alone is trophy-collecting with no cost — the exact "game
approving" failure `player.gd:233-235` already worries about in its own comment. Hearts-and-minds
alone is a world that reacts to a man who has no artifact of himself. Together they are *Platoon*.

### Where the fossil risk actually lives — and it is real

The fossil is not "two systems." The fossil would be **two player-facing summaries of his conduct.**

If hearts-and-minds ever grows a screen that itemises what he did — a conduct log, an "atrocities: 4"
line, an end-of-tour tally — then the cord and that screen say the same thing and one of them is
dead weight. Worse, the screen version is the *bad* version, because it is the game keeping score of
his soul, which is the lecture ADR-019 forbids.

> **RULE (binding, my recommendation): the cord is the ONLY artifact of what the player DID.
> Hearts-and-minds renders only what the DISTRICT does. It never itemises his conduct back to him,
> not at the AAR, not on the board, not ever.**

The one exception already shipped and it is correct: `debrief.gd:89-90` prints
`NONCOMBATANTS KILLED: %d` — a count, unpriced, appearing only when it is non-zero, with no comment
attached. That is a *casualty return*, a real form a real unit filed. It is a fact, not a verdict.
Keep exactly that line, that wording, and never add a companion.

### The one coupling I DO recommend: one input, two outputs

The ear verb at `player.gd:236-252` should feed **both** ledgers from **one call**, and never with a
shared number:

- `CampaignState.ears_taken += 1` → the cord grows. Private. Silent except the bucket toast.
- a witness within `EAR_WITNESS_M` → a **conduct event** posted to the village. Not "-3 allegiance
  from the necklace." The necklace has no allegiance value. **The witnessing does.**

The distinction matters and it is the whole design: **taking an ear in an empty treeline costs
nothing and means everything; taking one in front of a woman costs the district and means the same
thing.** The cord does not know the difference. The village does. That is a better sentence than any
meter, and it falls out of code that is already written.

### Does my recommendation depend on the cord shipping?

**No, and it must not.** State it plainly for the Arbiter:

> **Hearts-and-minds must be complete, felt, and finished with zero tokens in the game.** The cord is
> an amplifier on a system that works without it. If it never green-lights, nothing in H&M is
> missing — the player still burns a ville, still gets the silence, still walks the wired trail.

What the cord adds is the *private* half — the thing he looks at alone in a pause menu at hour 29 and
understands without being told. That is a luxury, not a load-bearing beam. Designing H&M to lean on a
PARKED feature would be exactly the drift this project's CLAUDE.md exists to prevent.

**SACRIFICED by this position:** the tidiness of one number. An Arbiter who wants "ears drive
allegiance directly" gets a simpler system and a strictly worse one — because the moment ear count is
an allegiance input, the necklace becomes a meter with a cost, the player stops taking ears to protect
his standing, and the single most transgressive verb in the game turns into a resource-management
decision. **The cord must never be a thing he is careful about.**

---

## B · THE LANGUAGE

### B.0 The scope ruling the writing forces

**The board speaks in DISTRICTS. The field speaks in VILLAGES.**

I cannot write forty sentiment lines and the player cannot read forty. But per-village resolution is
where the moral weight lives — *that* ville, the one he burned. Resolution split:

- **Villages carry the value** (systems' call, not mine).
- **The AAR / S2 board state the DISTRICT** — one aggregate, one sentence, once per patrol.
- **The per-village truth is carried entirely by BEHAVIOUR AND BARKS** — the ville that goes indoors,
  the point man who doesn't like this one.

**SACRIFICED:** a player who burned one ville in an otherwise cooperative district gets no written
acknowledgment of that specific ville, ever. He has to notice it with his eyes. I consider that a
feature; note it is also a real cost, and it is the cost ADR-019's consequences section already warns
about ("delayed consequence is hard to learn from").

### B.1 Six sentiment states

Anchored to the **Hamlet Evaluation System** — the real MACV instrument, live from 1967, which graded
hamlets A/B/C/D/E/V. This is not decoration. It buys three things at once: it is period-correct to the
month; it is a **letter, not a number**, so it reads as bureaucracy rather than a progress bar; and it
is historically famous for being **wrong**, which is the lever that defeats optimisation (see B.3).

| # | State | HES | What it means in the world |
|---|---|---|---|
| 1 | **SECURE** | A | They flag you down before you walk into anything. Informers work FOR you. |
| 2 | **FRIENDLY** | B | Trails stay clean. Trade happens. Kids come out. |
| 3 | **WATCHFUL** | C | The default. Nobody helps, nobody sells you out. **Every district starts here.** |
| 4 | **CLOSED** | D | Doors shut when you walk in. Trails start getting wired. |
| 5 | **HOSTILE** | E | Informers sell you. Ambushes wait where nobody should have known. |
| 6 | **GONE OVER** | V | The district is theirs. Recruitment is free. Near-terminal. |

**WATCHFUL is the start state and it is deliberately not "neutral."** "Neutral" is a game word.
"Watchful" is what a village full of people who have already been visited by both armies actually is.

### B.2 The AAR line (`debrief.gd`, appended to the `lines` array, unpriced, no score column)

One line. Only when the district's state has **changed since he last saw the board** — an unchanged
district says nothing at all, because a line that prints every patrol becomes a meter with words.

| State | AAR line |
|---|---|
| A | `HAMLET SURVEY: THE DISTRICT IS REPORTING TO US.` |
| B | `HAMLET SURVEY: THE HAMLETS ARE TALKING TO US.` |
| C | `HAMLET SURVEY: NO CHANGE IN THE DISTRICT.` |
| D | `HAMLET SURVEY: THE DISTRICT HAS STOPPED TALKING.` |
| E | `HAMLET SURVEY: THE DISTRICT IS HOSTILE. EXPECT CONTACT.` |
| V | `HAMLET SURVEY: THE DISTRICT IS THEIRS. SO ARE THE TRAILS.` |

The E line is **verbatim from ADR-019 §4**. It is canon; it is the register everything else was tuned
to match; do not improve it.

### B.3 The S2 board (HQ) — and the joke that makes it safe

The board carries the letter. **And the letter is stale, dated, and sometimes wrong.**

```
HAMLET EVALUATION — II CORPS, [DISTRICT]
    RATING            C
    SURVEYED          14 DAYS AGO
    REPLACEMENTS      [see below]
```

Three lines, one screen, no history, no arrows, no deltas, no previous value.

**Why staleness is load-bearing, not flavour.** ADR-019 §4's forbidden thing is a *live* meter,
because a live meter gets optimised. A rating that is up to N patrols old, that lags the truth, and
that the player learns to distrust, **structurally cannot be optimised** — you cannot grind a number
you cannot currently read. It is also the single most historically accurate thing we could put on a
wall in 1967: HES was famously confident garbage, and the officer who believed it got people killed.

That is the underground-comix register exactly: **the horror is not the atrocity, it is the form that
was filed about it.** No joke is told. The bureaucracy is the joke.

**SACRIFICED:** some players will read a stale/wrong rating as a bug and report it. That is a real
support cost and I accept it. Mitigation is one word on the board — `SURVEYED 14 DAYS AGO` — which
is doing an enormous amount of work for four words and must never be cut for space.

### B.4 The attrition line — the counter to the treadmill

ADR-019's consequences section names this: *"the pool is going down, and he must be able to see that
it is."* One line, on the board only, never a number:

| Pool state | Line |
|---|---|
| Broken | `REPLACEMENTS: THE ONES WE ARE MEETING ARE OLD MEN AND BOYS.` |
| Thinning | `REPLACEMENTS: THEY ARE NOT FILLING THE HOLES AS FAST.` |
| Holding | `REPLACEMENTS: STRENGTH ESTIMATE UNCHANGED.` |
| Regenerating | `REPLACEMENTS: THEY ARE PUTTING MEN BACK FASTER THAN WE TAKE THEM.` |

That last line is the entire ADR-019 §3 thesis in eleven words, printed without one syllable of
judgment, on a form. It is the only place the fast road's bill is ever written down, and the player
must have to walk to a board to read it.

### B.5 Twelve squadmate barks

**Constraint honoured:** `AllyBase` has one bark path (`ally_base.gd:174-177`) — text through
`director.toast.emit()` — plus nine VO keys. New VO costs recorded lines. So: **every bark below is
written to work as TEXT on the existing toast channel**, with a VO key named for a later pass. No new
bark architecture is required by this analysis.

None of them names standing. None of them draws a conclusion. Every one is an observation a
twenty-year-old would actually say out loud.

| # | VO key | Line | Fires when |
|---|---|---|---|
| 1 | `ville_empty` | `MIDDLE OF THE DAY AND NOBODY'S OUT.` | entering a D/E ville, first time this patrol |
| 2 | `kids_ran` | `KIDS RAN. THAT'S THE TELL.` | civilians flee on approach in a D+ ville |
| 3 | `dont_like_this_ville` | `I DON'T LIKE THIS ONE.` | point man, entering E/V ville — **ADR-019 §4 names this bark by hand; it is canon** |
| 4 | `no_eye_contact` | `PAPASAN WON'T LOOK AT ME.` | a civilian in a D ville breaks LOS and goes indoors |
| 5 | `they_wave` | `THIS ONE'S STILL GOOD. THEY WAVE.` | entering an A/B ville — **the friendly side needs a voice too** |
| 6 | `sold_me_a_coke` | `LAST TIME I WAS HERE THEY SOLD ME A COKE.` | ville that has dropped ≥2 states since he last walked it |
| 7 | `watch_the_ground` | `WATCH THE GROUND. THEY BEEN BUSY OUT HERE.` | trap density above threshold on this trail |
| 8 | `somebody_talked` | `SOMEBODY KNEW WE WERE COMING.` | ambush triggered in a D+ district — **the informer's only voice** |
| 9 | `new_faces` | `THAT'S A LOT OF NEW FACES FOR A PLACE THIS SIZE.` | in a district regenerating manpower — **the ONLY tell the pool is refilling** |
| 10 | `fresh_dirt` | `FRESH DIRT BY THE TREELINE.` | recent VC activity, C+ district |
| 11 | `sick_people_here` | `DOC SAYS THEY GOT SICK PEOPLE HERE.` | medcap opportunity exists — *offers*, never instructs |
| 12 | `not_scared_anymore` | `THEY AIN'T SCARED OF US NO MORE. THAT'S WORSE.` | first entry to a V ville |

**#12 is the ceiling.** It is one inch from a theme statement and it is the furthest any character in
this game may ever go. Anything more explicit than that sentence is a lecture. If the Arbiter wants a
safety margin, cut #12 and lose nothing structural.

**#9 is the most important bark in the entire document.** VC manpower regeneration is ADR-019's
headline mechanic and it is *invisible by construction* — the player cannot see a pool. One grunt
noticing that the enemy keeps getting younger is the only sensory channel that mechanic will ever
have. **If #9 is not built, ADR-019 §2's core loop is unfeelable and the ADR has failed its own
§4 test.**

**SACRIFICED by the bark budget:** twelve lines cannot cover forty villages, so barks will repeat
inside a long tour. The mitigation is rarity gating (once per ville per patrol, hard cooldown), which
means some real standing changes go unremarked. Accepted — a bark that fires often is wallpaper, and
wallpaper is worse than silence.

---

## C · TONE GUARD — the eight ways this gets ruined

ADR-019: *"the player discovers he is the bad guy himself, by doing it, with nobody ever telling him
he is the bad guy."* Eight failure modes, one rule each.

**1 · THE SAD-MUSIC MOMENT.** A string cue, a slowdown, a desaturation when a civilian dies.
> **RULE: no audio, camera, or post-process state may ever change because of a moral event. The world
> reacts; the presentation never does.**

**2 · THE NPC WHO EXPLAINS THE THEME.** An ally saying "this is why we're losing this war."
> **RULE: a character may report an observation. A character may never state a conclusion the player
> has not already reached. If a bark contains the word "because," delete it.**

**3 · THE ACHIEVEMENT FOR MERCY.** A score line, bonus, or title for restraint.
> **RULE: virtue pays only in the currency violence pays in — quieter trails, fewer wires, a warning
> before the wire. It is never named and never scored.**
> *Live tension, flagged:* `debrief.gd:91-92` prints `ROE - WEAPONS DISCIPLINE: +75`. This is safe
> **only** because it reads as tradecraft (ADR-006's ghost bonus — don't be heard), not virtue. Never
> rename it to anything moral, and **never add a companion "NO CIVILIANS HARMED: +X" line.** That one
> line would convert the whole system into the PS2 morality meter in a single patch.

**4 · WITHHOLDING TO PUNISH.** Difficulty rising in a way the player cannot trace to an act.
> **RULE: every consequence must be a thing a real district would DO — a wired trail, a closed door,
> an informer. Never an invisible stat penalty. If the player cannot name the in-world cause
> afterwards, it is a punishment, not a consequence, and it is a bug.**

**5 · THE CONFESSION SCREEN.** An end-of-tour tally of what he did.
> **RULE: the game never sums his sins. His only tally is the cord, and he strung it himself.**

**6 · THE REDEMPTION GRIND.** Medcaps that wash a burned village clean.
> **RULE: a burned ville never returns to A. Recovery is slow, partial, and capped one grade below
> where it was. Penance must never be a viable farm — the moment it is, burning is free.**

**7 · THE KNOWING WINK.** Comix influence misread as jokes about atrocity.
> **RULE: the humour lives entirely in the institution — the confident letter grade, the fourteen-day-
> old survey, the form. The violence is played absolutely straight, every time, with no camera on it.**

**8 · THE UNEARNED VILLAIN.** A game that decides he is bad by fiat.
> **RULE: every hostile turn must trace to a specific act, at a specific place, that he could have
> chosen not to do. No ambient drift toward hostile. The war does not sour on its own.**

### The one live violation on the floor right now

`player.gd:251` — `_field_toast("THEY SAW YOU DO THAT")`.

It is failure mode **2**, in shipped code, and it fires unconditionally while the consequence it
promises (`on_atrocity_witnessed`, `:249-250`) has **zero definitions repo-wide** (briefing BUG A).

Two separate crimes:
- **The systems crime:** the toast reads as working while its only effect is dead. Fossil law.
- **The writing crime, which is worse:** *the game is narrating his conduct back to him in capital
  letters.* That toast is the exact voice ADR-019 forbids — the game leaning in to make sure he
  understood what he just did.

> **My recommendation: DELETE the toast. Do not "fix" it. Build the villager reaction instead.**
> The correct scene is: he takes the ear, and a woman thirty metres away turns and walks inside, and
> the game says nothing at all. He will feel that a hundred times more than a line of amber text, and
> it costs no words.
>
> Keep `THE NECKLACE IS GETTING HEAVY` (`:240`). That one is about the *object*, not about him — it
> is the cord speaking, not the game judging. It is on the right side of the line.

---

## D · THE ARC — what thirty hours feels like

### The clean tour

**HOUR 1 — he does not know a system exists.** ADR-020's threshold does its job: the trail sign, the
wire the point man catches, the villager who is a person. Trails are clean because everything starts
at C, not because he earned it. **Nothing tells him the villagers matter. He is simply shown one.**

**HOUR 8 — the first strategic thought, and it is his.** He notices one ville is easier to walk
through than another. He starts routing patrols that way. Not because the game suggested it — because
it is *safer*, and he worked that out himself. The board says B and he half-registers it. **This is
the hour the system becomes real, and it does so without a single line of text.**

**HOUR 20 — quiet where he walks.** The trails he uses are clean; he hears other elements in contact
on the net and never gets hit himself. Bark #5 fires. Somebody flags him down before a wire. He has
become the man who takes the long way, and he could not tell you when that happened.

**HOUR 30 — he wins and there is no fanfare.** The pool is broken; bark #9 has inverted into old men
and boys. Contact is rare. **It is a little boring, and the boredom IS the victory** — ADR-020 §5's
earned quiet, cashed in. No screen tells him he was good. His cord is short and stupid: a fang, a
spent casing, someone's Zippo. **He may not notice he won until he reads a letter A on a board he has
stopped trusting.**

### The fast road

**HOUR 1 — identical.** Same threshold, same villager. The game plays no favourites at the door.

**HOUR 2 — it works, and it works GREAT.** He burns a ville, the sniping stops, he is home before
dark. ADR-019 §3 is binding law here: **this must feel like competence, not transgression.** No music
change, no bark of reproach, no toast. The only sound is the fire.

**HOUR 8 — the trap is fully sprung and he is winning.** Enormous body count. Rank climbing (ADR-032
titles arriving on schedule — the score is a receipt and it says he is excellent). The board has gone
D. He has not connected the two, and the game will not connect them for him.

**HOUR 20 — THE DANGEROUS HOUR.** Every trail wired. Ambushes waiting where nobody should have known.
Kill count enormous and the enemy not thinning. ADR-019's own consequences section names this exact
risk: *"a player who burns three villes in hour two and gets mauled in hour nine may simply conclude
the game is broken."*

> **This hour is where the design lives or dies, and it is a WRITING problem, not a systems problem.**
> The three handrails, in order of load:
> 1. **Bark #8** `SOMEBODY KNEW WE WERE COMING.` — attributes the ambush to a *person*, not to
>    difficulty. This is the single highest-value line in the document after #9.
> 2. **Bark #6** `LAST TIME I WAS HERE THEY SOLD ME A COKE.` — the only line that spans time and
>    tells him something *changed*, without saying why.
> 3. **The stale board.** `REPLACEMENTS: THEY ARE PUTTING MEN BACK FASTER THAN WE TAKE THEM.`
>
> **My strongest single recommendation in this document:** the **first** time a named place drops to
> HOSTILE, one bark fires with that place's name in it — `THEY AIN'T FORGOT [PLACE].` Once per
> district, ever. Not an explanation. An **anchor** — one thread from an effect back to a place he
> remembers doing something at. Without at least one such anchor in thirty hours, delayed consequence
> reads as difficulty scaling and the whole ADR fails on its own §4 test.

**HOUR 30 — he is fighting a bigger war than he started, and nobody ever told him.** The province
never sterilised; bases came back worse-placed; the pool refilled behind every sweep. He pauses, and
there is a string of ears with a small Buddha on the end of it, and the game has not said one word
about it in thirty hours. **He assembled the indictment himself and it was never called one.**

### Why neither ending is authored

There is no ending screen, no verdict, no epilogue, no tally. **Both tours end in exactly the same
place: the state of a province and an object in a pause menu.** One province is quiet. One is on fire.
The game has the identical opinion about both, which is none. That is the difference between *Platoon*
and *Men of Valor*, and it is achieved entirely by things we **do not** write.

**SACRIFICED by the whole arc:** the clean player gets no payoff moment — no scene, no thanks, no
recognition — and a meaningful share of players will finish a careful thirty-hour tour feeling that
nothing acknowledged them. That is the real, unhedged price of "the game never has an opinion," and
it is exactly the price *Platoon* pays. I recommend paying it. **The compensation must be mechanical
and diegetic — quiet trails, a warning before a wire, a hamlet that reports to him — never a line of
prose thanking him for his restraint.** The moment we thank him, mode 3 wins and the system dies.

---

## Answers to the briefing questions (writer-relevant)

**Q1 · What does the player FEEL when standing moves?** Nothing on the frame it moves — that is the
design. He feels it later and elsewhere: a ville that goes indoors, bark #4, a trail that is suddenly
worth watching, bark #8 after an ambush. The felt event is always *displaced in time and place* from
the causing event, and the anchor bark (`THEY AIN'T FORGOT [PLACE]`) is the one deliberate exception.

**Q3 · Per-village, per-district, or global?** Writing forces the split: **values per village,
WORDS per district, BEHAVIOUR per village.** Sacrifice named in §B.0.

**Q5 · What hook must be laid NOW?** Two, both cheap, both writing-driven:
- **Delete `player.gd:251` and define `on_atrocity_witnessed`** — turn the dead call into a real
  conduct event. It is the only atrocity input already wired to a witness check.
- **Fix BUG B** (`_bank_patrol` dropping `civilian_deaths`). The AAR casualty line currently only ever
  prints when the player dies, which means **the one honest, unpriced record of what he did is
  invisible to every player who survives.** That is a writing failure disguised as a missing dict key.

**Q6 · Where is the moral weight, and how is it not two systems?** §A. The weight is in the gap
between the two ledgers — he keeps the souvenir, they keep the memory, and the two never reconcile on
a screen.

---

## Everything this analysis sacrifices, in one place

1. **One number would be simpler.** Refused; it costs the ear verb its transgression (§A).
2. **No per-village written acknowledgment.** The board speaks in districts; the ville he burned is
   never named in prose except by the one anchor bark (§B.0, §D).
3. **A stale rating will be reported as a bug.** Accepted; `SURVEYED 14 DAYS AGO` is the whole
   mitigation and must not be cut (§B.3).
4. **Twelve barks cannot cover forty villes.** Rarity gating means real changes go unremarked (§B.5).
5. **The clean player is never thanked.** The single largest cost in this document (§D).
6. **No redemption farm** means a player who wants to fix what he did mostly cannot (§C.6).
7. **Deleting `THEY SAW YOU DO THAT`** removes the only current feedback on the ear verb and replaces
   it with a villager animation that does not exist yet — a visible feature becomes temporarily
   invisible. Correct anyway (§C).
8. **Bark #12 and the anchor bark both sit one inch from a lecture.** They are the two lines most
   likely to age badly, and I am naming them as the first things to cut if the tone reads preachy in
   playtest.
