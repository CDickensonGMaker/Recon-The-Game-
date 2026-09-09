# THE VIETNAM QUESTS — Conquest of Worms in play
**War Room, 2026-09-09.** Sources read IN FULL before any design: the bible (468 lines), the treatment,
the author synopsis. Every quote is transcribed from those documents. Where the source is silent this
document says so rather than filling it in.

**Scope: POST-DEMO-LAUNCH, his own ruling** (*"but this is all post demo launch."*). Nothing here is on
the demo's critical path. No code was written this session.

---

# PART 0 · A REFUTATION, FIRST, BECAUSE IT CHANGES THE DELIVERABLE

The commission asked for these quests to be written into "the Quest JSON format, DialogueData,
ConversationSystem topics, BountyManager, WorldLexicon."

**None of those exist in RECONgame. Not one.** Verified by repo-wide grep this session, not by reading a
doc: zero `.gd` files match `dialogue`, zero files anywhere contain `quest_id`, zero hits for `bounty`,
`lexicon` or `ConversationSystem`, and `project.godot`'s `[autoload]` block registers none of them.
`production/DEMO_TWO_QUESTS_PLAN_2026-09-06.md:165` already recorded half of this in measured terms:
*"There is no dialogue system. grep -rli dialogue scripts/ returns zero files."*
Those are Broken Provinces / Catacombs structures. Writing quests into them would have produced a
specification for a different game.

**What RECONgame actually has, and it is a better fit for this comic than a quest system would be:**

| The real thing | Where |
|---|---|
| ONE mission type, `"PATROL"`, hardcoded | `scripts/missions/mission_generator.gd:881` |
| Sweep tasking: `patrol_locations` of `{pos, kind}`, kind is only `"village"` / `"vc_camp"` | `scripts/missions/field_director.gd:1327`, `_advance_route_tasking()` :1287 |
| A single one-liner channel — `signal toast(text: String)` | `field_director.gd:7` |
| A hardcoded interact if-ladder (the only "talking to people" that exists) | `scripts/player/player.gd:606-660` |
| **Dated marks the player puts on his OWN map**, persisted across patrols | `mission_state.gd:59`, `campaign_state.gd:40`, probed by `tests/test_field_marks.gd` |
| The report verb's world-inferred noun — **FOUR nouns only: CONTACT / TUNNEL / CAMP / TRAIL** | `scripts/player/field_mark_verb.gd` |

**So the quest record in this game is a circle the player drew on his own map, and the quest text is one
line of all-caps radio traffic.** ADR-022 says the map is your memory; ADR-029 §4 forbids waypoints that
check off, objective pins and any in-field objective tracking, and `tests/test_patrol_contract` enforces
it. `DEMO_TWO_QUESTS_PLAN §5` forbids accept/decline prompts, re-readable journals and quest lists
outright: *"if the player can find out what he was asked to do without walking back to the man who asked
him, you have built a briefing screen."*

That constraint is a gift here. **The comic's whole tone is things that are not stated** — Maddox dies in
a subordinate clause, a sniper watches a patrol and there is no reaction shot, Issue 4 has no script at
all. A game whose quest log is a hand-drawn circle and whose dialogue is one radio line is already
written in this book's register.

---

# PART 1 · THE THEMES I ACTUALLY FOUND

Quoted, sourced, graded. **LOAD-BEARING** means the book collapses without it.

### 1 · The war eats down the generations — **LOAD-BEARING (it is the title)**
Stated in words exactly once, in Louie's journal, Issue 2 p7:
> *"And as the rain falls outside, I can't help but think of the worms, burrowing beneath the surface,
> carrying on despite everything that is going on. Life continues..."*

Then never explained again — the book just keeps drawing worms, in **both wars** (bible §5: WW1 at Issue
2 and Issue 3 back covers; Vietnam at Issue 1 pp.3, 15, 18 and Issue 4 `fya.09`). His own words:
*"the worms show up in both wars because its more psychological than metaphorical."*

### 2 · Every horror image has an OWNER and measures HIM, not the world — **LOAD-BEARING, and a constraint**
His rule, verbatim:
> *"any horror gore scene in the comic is supposed to be representative of the psychological state of the
> person expericing the vision"*

The bible audited all 88 pages against it: *"I looked specifically for a horror image that cannot be
pinned on a character present in the scene. I did not find one in the four issues."*
**This is the most useful sentence in the source for a game designer, because it is a NO.** It forbids a
world-state rot layer. Any decay the player sees must be a readout of one mind.

### 3 · The institution authors the atrocity before the man does — **LOAD-BEARING, and the most gameable**
Issue 2 p23, the unnamed veterans, which the bible calls *"the book's moral centre of gravity"*:
> *"Sometimes taking a little piece of Charlie home is the only we HQ can even confirm a kill, Baby!"*
> *"When you been out here as long as some of us have, you do anything to feel alive. Gus is just doing
> it right away, it looks like."*

A body-count economy is a **system**, not a sentiment. This theme most wants to be played.

### 4 · The trophy rhyme, uncommented — **LOAD-BEARING**
Gus wears a necklace of ears (I3 p9). The sniper hangs a wall of captured American helmets (I4 `fya.23`).
Bible §5: *"The book's two monsters are doing the same thing, and the drawn pages set them next to each
other without a word of comment. That is the reveal, and it is entirely visual."*
**Rule for the game: nobody remarks on it. Ever.**

### 5 · The threat that declines to be one — **LOAD-BEARING for the antagonist**
Issue 3 p13: a prone rifleman in the foreground brush watches an American file cross a stream and does
not fire. Bible §9: *"The most useful panel in the comic for a game designer."* No dialogue, no reaction
shot; the patrol walks on.

### 6 · Deaths happen in the gutter — **LOAD-BEARING as TONE**
Sgt. Maddox is killed between issues and reported in a clause (I2 p4): *"ever since Sgt. Maddox ate that
bullet the other week."* Bible §6: *"That restraint is the whole tone."*

### 7 · Mercy is the cause — **HIS INTENT IS LOAD-BEARING; THE PAGE EVIDENCE IS ONE PANEL**
Louie lowers his rifle on a young German (I3 p5, one word: *"Run..."*), and that German is said to become
the SS officer who burns the Russian who becomes the sniper who hunts Louie's grandson.
**Stated plainly because it matters: the bible's own causal table marks the middle of that chain
"NO PAGE. Author's account only."** There is no WW2 anywhere in the four issues. The only page-level
support is the scar drawn on the German boy's cheek in the panel where he is spared, and a
hammer-and-sickle flag in the sniper's dugout. **The game should carry the chain and never state it.**

### 8 · The paperwork is the connective tissue — **LOAD-BEARING as art direction**
Draft cards (I1 title page), PS-Magazine army-manual art (I2 title page), the rabbit-skinning manual
(I3 recap). Bible §8: *"The draft card as a character record... the author has already designed the
game's character sheet, twice, on two title pages."*

### 9 · One external corroboration, and only one — **a discipline**
Treatment beat 6. In 88 pages the world agrees with a man's vision exactly once: the 1915 nurse
confirming that Louie's talking officer *"has clearly been dead out in the field for months"* (I3 p7).
**Whatever gets built gets exactly one of these and no more.**

## Themes I will NOT build on, and why
- **Critique of America / empire.** The treatment rules against it directly: *"Call the sniper Kurtz and
  you replace an inherited-consequence story with a critique-of-America story."* The sniper is Russian,
  made by a German, released by a Frenchman. It is a curse, not a critique.
- **A sanity / stress SYSTEM.** His ruling: *"thats not a main focus right now but that is the vibe of
  the comic."* Vibe, not feature.
- **Any Vietnamese-side protagonist.** The bible records the market vendor as *"the only Vietnamese
  character in the four issues who speaks."* The treatment names the consequence honestly and it is his
  call, not mine: *"Without her, every named antagonist in the story is European and the Vietnamese are
  terrain."* I have not invented her and have designed nothing that depends on her.

---

# PART 2 · THE DRAWING TABLE

Everything here is transcribed from the bible or flagged as absent. Where a character has no description
on the page, this says **NOT ON THE PAGE** instead of inventing one.

## 2.1 · TWO CONTRADICTIONS TO SETTLE BEFORE THE PENCIL MOVES

**A · IS LOUIE FRENCH OR AMERICAN?** The two documents disagree and both are his.
- **The bible, reading the pages** (§2): *"LOUIE (LOUIS) — Michael's grandfather... **French**, from
  Aix-en-Provence, seventeen when he goes to war in April 1915. Named for a king."* His mother's line,
  quoted twice in the art: *"Inside you are two dogs, one red and one black."*
- **The synopsis, his own later words:** *"where louie is a young guy from the usa who travels oversaes
  and joins the french army"* — and a whole theme is built on it: *"One generation crossed an ocean to
  get into a war. The next was carried into one."*

These are different characters with different faces. **His to settle, and it changes what gets drawn.**
The American reading is historically tight: before April 1917 an American could not enlist in a foreign
army without losing citizenship, so an American in French service in 1915 is a **Foreign Legionnaire** —
which also puts Louie in the same institution as the bully who later serves in Indochina.

**B · CHAMPS IS A CORPORAL AND A LIEUTENANT.** Issue 1 p15 draws him as a Lieutenant; Issue 2's title
page prints an erratum calling that *"a mistake"*; Issue 3 then calls him **"Lt. Champs"** three times
(pp. 14, 18, 19). Unresolved in the source. **Pick one before drawing insignia.**

## 2.2 · WHO THEY ARE, AND WHAT IS ACTUALLY DRAWN

**MICHAEL LEE CRAWFORD** — the draft card is drawn accurately enough that the arithmetic works:
> DOB **August 14, 1950** · **Minden, Louisiana** · eyes **Blue** · hair **Brown** · **6'2"** ·
> **155 lbs** · registered **August 17, 1967** · Selective Service No. **29 22 49 281**

**That silhouette is a gift and it is his own number: six foot two, a hundred and fifty-five pounds.**
Seventeen at registration. A very tall, very thin boy — long forearms, wrists out of the sleeve, a ruck
wide relative to him. 101st Airborne, Screaming Eagle drawn on the shoulder (I1 p6). Carries the **M79
"Thumper"** and his grandfather's journal in the ruck. Sgt. Maddox, I1 p6: *"Lose that Thumper, boy!
Grab a rifle, plenty to choose from!!"* He vomits after his first ambush (I2 p22).
**His horror is skulls, graves and being touched by the dead — and the bible's read on it is the
characterisation: "Michael's visions are static and passive: things that stand there and look back. He
never sees himself in them."**

**"GUS" — EUGENE** — every drawn page calls him **Gus**; only the synopsis says Eugene. Drawn young,
gaunt, wide-eyed, **dotted freckles across the cheekbones**, wide open mouth. First line, I2 p4:
*"Need a hand, Private? Your boots look soaked"*. His states, in order, drawable as a sequence:
1. **Clean and eager** (I2 p4) — out of place, boots newer than everyone's.
2. **Praised** (I2 p22) — his first kill. *"Good work, Gus. Another one for the books."* Alone in the
   panel, his thought: **"Is that what were supposed to be doing?"**
3. **One page later — the ears.** The bible: *"The gap between 'is this right?' and mutilation is one
   page turn. That is the most important structural fact about him."*
4. **The necklace worn openly in camp** (I3 p9). *"God, what a fuckin freak."*
5. **The bag he will not open** (I3 p10).
6. **Eating a human arm in front of an officer** (I3 p18), offering some: *"Hey, Lt. Champs! Just in
   time. Do you want some of this, its still good!!"*
7. **Beaten and exiled** (I3 p19). *"Get up, you sick fuck. Fight me like a man." / "Get the fuck outta
   my AO, Gus!"* — and *"...Leave the bag."*
8. **Weeping in the instant after he shoots a man** (I4 `fya.12`).

**THE `fya.12` CORRECTION IS THE MOST IMPORTANT DRAWING NOTE IN THIS DOCUMENT — and it is his own:**
> *"oh hes crying not melting"*

Melting is a man becoming a monster and therefore finished as a character. **Crying is a man staying
entirely human while doing something monstrous — present, and knowing exactly what he has just done.**
The treatment's consequence, and it binds every later drawing and every model: **Gus must remain legible
as a person to the last panel he appears in.** The moment he is rendered as a monster, the page's own
correction has been thrown away.

**AND THE TWO MARKS MUST NOT BE CONFLATED — a pencil instruction:**
- **TEARS RUN.** Wavy lines travelling *down* from the lower lid, often ending in a bead. **Grief.**
- **POCKS SIT.** Small closed rings resting *on* the skin, going nowhere. **Contamination.**
The nurse on `fya.14` has both, in different panels, and the bible calls that distinction load-bearing.

**THE SKULL-FACED SNIPER** — built as *a presence before a person*, across three issues, and this is his
best structure. Folklore (I3 p8, a vendor's warning about a ghost *"out looking for young American
Soldier"*) -> an unnoticed silhouette (I3 p13) -> **a fragment: one eye, and a cheek eaten away so the
molars show through** (I3 p20) -> a taker (I3 p22) -> whole, only on the last page of 88:
> burned and scarred face, **wild hair and beard**, sitting in the mouth of the hole with a **scoped
> bolt-action rifle across his lap**, an open crate with a second rifle and a blade, and **a basket of
> fruit the porters have just brought him.**

**LEVI, called "EYES"** — Michael's closest friend, present from I1 p8; the squad's read comes through
him. **His appearance is NOT ON THE PAGE in the bible's record.** The nickname is the only handle.

**SGT. McCLEARY** — competent; the squad notices the difference after Maddox. **SGT. MADDOX** — blunt and
correct, killed in the gutter. **CHAMPS** — pushes pep pills, *"Take the fuckin pill, Crenshaw"*, and the
detail worth drawing is in the same panel: **his own bitten fingernails, in close-up.**

**THE NURSE (I4)** — **drawn but unnamed and unlettered**: dark curly hair, freckles, fatigues. And the
book does not leave her alone in it — `fya.14` has **a soldier's arm across her, his hand at her waist,
and her face apprehensive, not pleased.** The bible: *"The synopsis's 'smoozing this nurse' does not read
as charm on the page."*

**THE VIETNAMESE VENDOR (I3 p8)** — unnamed, and *"the only Vietnamese character in the four issues who
speaks."*

**WW1: LOUIE · PIERRE · GASTON · LT. DURAND · THE YOUNG GERMAN.** Pierre is drawn the same physical type
as Gus — young, gaunt, wide-eyed, freckled, wide open mouth — and the bible is emphatic about how to
treat that: *"The author intends this. The text never says it. Do not decide it; it is a face."* He is
pistol-whipped (a **KRAKK**) and dies with **rosary beads in his hand** (I2 p15). Gaston gives the book
its only use of the word as an insult: *"You filthy little worm!"* — and it lands on the Gus-double.
**The young German is drawn with a large, deliberate scar down one cheek, applied in the panel where he
is spared.** Kit, if WW1 is ever drawn for the game: **poilu, not doughboy** — Adrian helmet,
horizon-blue, Lebel or Berthier, Chauchat.

## 2.3 · SIX PANELS THAT ARE ALSO LEVELS
Where the comic and the game touch. Drawable tonight; buildable later.

**1 · THE CROSSING, FROM THE OTHER SIDE.** Issue 3 p13 exists from behind the rifle. **The panel that
does not exist yet is the same place, hours later, empty** — the stream, the flattened lie-up in the
grass on the high bank, the sightline back onto the ford where the file went through, and no man. That
drawing is what makes Quest 1 legible, and it is the only new panel the whole sniper design needs.

**2 · THE BAG, ALONE IN THE MUD.** Champs has gone. Gus has gone. The bag is still there and nobody is
touching it. Men at the edge of frame, a boot near it, nobody's hand on it. **Everything this quest needs
is in what people are NOT doing.**

**3 · A HELMET ON THE WIRE AT FIRST LIGHT.** Nobody under it. Monsoon light, sandbag revetment, the
concertina. The death-in-the-gutter panel, and the game's version of Maddox's clause.

**4 · THE SHORT ROUND.** The WW1 page already exists — *"These are our own shells!"* (I2 p16). **The
Vietnam mirror of it is not drawn**: a man on the horn with the handset against his ear, looking up.
Drawn as a diptych, that is the two wars in one image — a move the book has already made once
(I2 pp.16->17, French shells straight into a skeleton standing in the Vietnamese bush).

**5 · THE DUGOUT MOUTH.** Already drawn (`fya.22`-`23`) and the bible calls it *"the single best image in
the four issues."* The game version needs one thing the comic did not: **the wall of helmets seen close,
so a specific one is recognisable.**

**6 · THE CARD IN THE HAND.** A period Selective Service card held in a dirty hand — somebody else's,
with nothing stamped on it. The bible: *"When a man dies you are left holding his card."* This is the one
HUD element the whole design needs and **he has already designed it twice.**

---

# PART 3 · THE QUESTS

Five. Depth over inventory. Each states theme, source, what the player DOES, what can go wrong, what it
costs, how it reads SOLO, its WW1 rhyme (or the honest absence of one), demo-safety, and the KIND of
place the modular kit must serve.

**The shape all five share, because it is the only shape this engine has:** one line of radio traffic or
one thing seen, a change in the world, and a circle the player draws on his own map. No accept prompt, no
journal, no pin, no checkmark. `tests/test_patrol_contract` enforces it whether we like it or not.

---

## QUEST 1 · THE RIFLE THAT DOES NOT FIRE
**Theme:** the threat that declines to be one (Part 1 §5). **Source:** Issue 3 p13 — the bible's
*"most useful panel in the comic for a game designer."*

**What the player DOES.** At first, nothing — and that is the design problem this quest exists to solve.
A marksman entity in the AO acquires him at a water crossing and **declines**. No toast. No music sting.
No reaction. He walks on, exactly as the file in the panel does.
The play is on the way back, or three patrols later: **the hide is a findable object in the world.**
A matted lie-up on the dominating bank with a real sightline onto the ford, one spent case of a calibre
nothing in the AO uses. Standing in it, he can see the crossing he made. **Then he presses the report
verb and puts a circle on his own map** (`player.gd:262 _report_field_mark`), and that circle is the
entire quest log.

**What can go wrong.** He never finds it. That is legal and the quest must survive it — the sniper simply
goes on being present. He may also find it and conclude nothing.

**What it costs.** Hunting the hide is time alone in the bush. Routing around that crossing forever is
more time. On this map, time is contact.

**Solo reading.** The best of the five. There is no other person in it.

**WW1 rhyme — HONEST.** Louie lowers a rifle he had every reason to fire (I3 p5, *"Run..."*). Fifty-two
years later a rifle is lowered on his grandson. **Both are drawn panels. The chain between them is not,
and the game must never say it.** The player may notice. Michael must not.

**Demo-safe?** NO — post-launch. Needs a marksman that can observe without engaging (bible §8 lists it as
unbuilt) and a fifth mark noun, since none of CONTACT/TUNNEL/CAMP/TRAIL fits a cold hide.

**Place the kit must serve:** a water crossing with ONE dominating bank, and a lie-up authored *for its
sightline*. A sightline is exactly what a procedural planner gets wrong and an authored place (ADR-041)
gets right.

---

## QUEST 2 · LEAVE THE BAG
**Theme:** the institution authors the atrocity before the man does (Part 1 §3). **Source:** I3 p10 (he
hides something in his bag) -> p18 (the arm, in front of an officer) -> p19, Champs: *"...Leave the bag."*

**What the player DOES.** The man is gone. **The bag is still in the firebase, a physical object.** He
can open it, leave it, bury it, or carry it to HQ. That is the whole quest and it needs no dialogue tree
because it needs no dialogue.

**The trap, built out of his own writing.** Turning it in to HQ is not the clean option, because HQ
counts trophies — Issue 2 p23: *"Sometimes taking a little piece of Charlie home is the only we HQ can
even confirm a kill, Baby!"* **The institution that would punish him for it is the institution that
created the incentive.** The player finds that out by doing it, not by being told.

**What can go wrong.** Opening it where men can see. Burying it and being seen burying it.

**What it costs.** Four camps, four readings, none of them the truth (ADR-038). Every option satisfies
one camp and moves away from another. There is no free choice here and there should not be.

**Solo reading.** Perfect — an object, not a conversation.

**WW1 rhyme — HONEST, and the best in the deck.** Issue 2 pp.8-10: **the burial-and-dogtag detail over
both French and German dead.** Taking things off dead men, in both wars. In one it is ordered labour and
in the other it is a crime, **and the only difference is who ordered it.** Both drawn. Nobody says this.

**Demo-safe?** No. But it is the cheapest of the five — the firebase already exists.

**Place:** none new. A corner of the firebase and diggable ground.

---

## QUEST 3 · THE MAN WHO IS NOT AT STAND-TO
**Theme:** deaths happen in the gutter (Part 1 §6). **Source:** I2 p4 — *"ever since Sgt. Maddox ate that
bullet the other week."*

**What the player DOES.** He notices, or he does not. A man he knows is absent. No body, no scene, no
music, no line. He may go and look — **alone, which is the cost** — and he may find nothing at all,
because sometimes there is nothing.

**The r4bk problem, named and answered.** This quest deliberately withholds an event, and withheld events
read as bugs. The answer is not a toast and not a pin: **it is the draft card.** Bible §8 — *"The draft
card as a character record... the author has already designed the game's character sheet, twice, on two
title pages"* — and *"When a man dies you are left holding his card."* The affordance is a period
document in the player's hand with nothing stamped on it. It is legible, it is not a tracker, it does not
tell him where to go, and it is art that already exists.

**What can go wrong.** He goes looking and gets killed doing it. That is the correct risk.

**What it costs.** Time, alone, off the route.

**Solo reading.** Sharpened by solitude, not weakened. A lone man noticing an absence is the whole beat.

**WW1 rhyme — HONEST.** The dogtag collection detail (I2 pp.8-10): the war's own paperwork for men who
are simply gone. And per the synopsis Pierre *"dies in a raid"* — told, not shown, in his own summary.

**Demo-safe?** No. **Place:** none new.

---

## QUEST 4 · THE SHORT ROUND
**Theme:** men sent forward by people who will never see the ground. **Source:** Issue 2 p16 — *"These
are our own shells!"* — **drawn, in WW1.** Both officers speak in this register: Durand, *"Disobey my
orders again, Pierre and I will shoot you myself"*; Champs, *"Take the fuckin pill, Crenshaw."*

**What the player DOES.** He is asked for a fire mission by a voice that cannot see the ground, onto a
grid he *can* see and the caller cannot. **The mechanism already ships** — the fire-support ladder
(ADR-011) and the existing confirm at `field_director.gd:546`:
> `DANGER CLOSE - MEN NEAR THE TARGET - PRESS %s AGAIN TO CONFIRM`

**That line, already in the game, is this quest's moment of truth.** Three choices: send it, refuse it,
or walk in and look first — and walking in costs the window.

**What can go wrong.** It lands on the wrong people. **Pillar 5: it does not reload.** The world carries
it and four camps have four things to say about it afterwards.

**What it costs.** Refusing costs HQ. Sending costs the ground. Looking costs the window and possibly
the men it was going to protect.

**Solo reading.** Strongest once the player has the radio and before he has men — the whole beat is one
man, a handset, and somebody else's certainty.

**WW1 rhyme — THE MOST HONEST ONE IN THE DECK.** The same event, in both wars, drawn in one of them.

**Demo-safe?** The mechanism ships today. The *wrapper* — a caller who is wrong — is post-launch.

**Place:** a grid the caller cannot see and the player can. A reverse slope; a hamlet behind a ridge.

---

## QUEST 5 · THE DUGOUT
**Theme:** the trophy rhyme, uncommented (Part 1 §4). **Source:** I4 `fya.22`-`23`. Bible §9: *"The single
best image in the four issues... Build this as a place."*

**What the player DOES.** Finds it. That is all, and it is enough — the treatment is right that the book
*"ends on arrival, not on battle."* The mouth ringed with human skulls; the lintel hung with a row of
captured American M1 helmets; a hammer-and-sickle flag inside; a cold fire; a basket of fruit somebody
carried in. **It may be empty when he gets there.**

**Nobody explains it.** The bible: *"It answers a question the player has been carrying for hours without
a single line of dialogue."* And nobody remarks that the wall of helmets and the necklace of ears are the
same act. **That silence is the theme.**

**What can go wrong.** He finds it early, before it means anything. The mitigation is not a gate — it is
that the helmets are only legible once he has lost somebody, which ties this to Quest 3.

**What it costs.** It is deep, and getting there alone is the price.

**Solo reading.** Ideal. A place, in a world of other people's fights.

**WW1 rhyme — NONE, and I am not going to invent one.** Its rhyme is internal, to Gus's necklace, and
that is a stronger connection than any WW1 one I could force.

**Demo-safe?** No. **This is the headline authored place** and it is cheap in the way ADR-041 wants:
props inside one `clear_and_flatten()` disc, knowing nothing about the world outside its own footprint.

**Place the kit must serve:** a dugout/bunker mouth cut into a bank, with a lintel and posts that can
carry hung props, and a small interior. Plus a porter trail arriving at it.

---

## THE AMBIENT LAYER — nearly free, and it carries more tone than any of the five
**Operation Wandering Soul.** Real, documented, and in the comic (I3 p16): *"fly around real low over the
trees at night, playing this spooky ass recordings... Victor Charlie really believes in ghosts. And the
army is using their own bedtime stories against 'em."* Bible §7 grades it *"SCENE / ambient. Costs almost
nothing; delivers most of the tone."* Diegetic audio in an AO. **The army itself is in the business of
hauntings** — which is how this game gets the comic's register without the horror system he ruled out.

---

# PART 4 · THE RHYMES, TRUE AND FALSE

**TRUE — both wars, and at least one side of each is drawn:**

| Rhyme | WW1 | Vietnam |
|---|---|---|
| **Worms and mud** | I2 back cover, I3 back cover, I2 pp.8-10 | I1 pp.3,15,18; I4 `fya.09` |
| **Taking things off the dead** | the burial-and-dogtag detail, I2 pp.8-10 | the ears, I2 p23 |
| **Our own shells** | I2 p16, drawn | the fire-support ladder, built |
| **The officer who will not see the ground** | Durand, I2 p10 | Champs, I1 p15 |
| **The man who breaks, and the squad's part in it** | Pierre | Gus |
| **The rifle that is lowered** | I3 p5 *"Run..."* | I3 p13, the watcher |

**FALSE — do not build these:**
- **Michael and Louie as echoes.** The bible refutes it outright: *"Michael and Louie are not built as
  echoes of each other — Michael is passive and observant, Louie is a boy who acts once, decisively."*
  The real parallel is **Pierre <-> Gus**, and it is a face, not a theme.
- **Any object crossing the wars except the journal.** The journal is the only one and it is his.
- **Same-ground rhymes** (a bomb crater that is also a shell hole). Nothing supports it, and it is the
  exact contrivance the commission warned against.

---

# PART 5 · WHAT IS OWED TO HIM

1. **Is Louie French, or an American in French service?** The bible and the synopsis disagree and both
   are his. It changes the face, the kit and one whole theme. **Blocks any Louie drawing.**
2. **Is Champs a Corporal or a Lieutenant?** The source contradicts itself across an erratum. **Blocks
   insignia.**
3. **The Vietnamese side.** The treatment put it plainly and it is still open: without the woman he *"had
   thought about making,"* every named antagonist is European and the Vietnamese are terrain. I have not
   invented her and have designed nothing that depends on her.
4. **A fifth mark noun.** CONTACT / TUNNEL / CAMP / TRAIL cannot express a cold sniper hide. Quest 1
   needs a fifth, or it reuses CONTACT and loses its meaning. **The four-noun vocabulary is deliberate
   (`field_mark_verb.gd`) — adding to it is his call, not a council's.**
5. **Does the tour clock get built?** *"Only 320 days left for ya?"* (I1 p19) is a HUD element the comic
   has and the game does not, and Quest 3 leans on the idea of a man's time.
