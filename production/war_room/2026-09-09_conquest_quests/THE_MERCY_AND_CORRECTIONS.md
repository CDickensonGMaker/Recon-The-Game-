# THE MERCY — spec under his ruling · and three corrections to the first pass
**2026-09-09.** Companion to `synthesis.md` (this folder) and to `production/QUEST_STARTERS_VIETNAM.md`.
Written after reading the bible, treatment and synopsis in full. **Post-demo-launch. Nothing built.**

---

# PART A · HIS RULING, SPECCED

> **"even if they shoot the german, he gets away."**

**This is the spine, not a patch.** Mercy and murder produce the same man walking off. You do not
control the chain; you inherit it. That is the title stated as a mechanic.

## A1 · The mechanism that makes the fixed outcome HONEST — you never get a body

The danger named in the brief is real: a scripted miss the player can feel is worse than no choice. The
answer is not to fake the bullet. **It is to withhold the confirmation.**

- The German is **in the open, at distance, moving**, and Louie has a **bolt-action** — Lebel or
  Berthier (the kit the synopsis specifies). **One shot before he is out of it.** That is not a
  contrivance; it is the weapon.
- **Do not script the trajectory.** The round goes where the player put it. If it hits, he **takes the
  hit, staggers, goes over the lip and is gone.** Blood on the grass.
- **There is no body, ever.** Not because the game removes it — because the player cannot get to where
  he went, and the sequence ends. **A man shot at four hundred metres who runs out of sight is the most
  ordinary event in either war.** The game never has to lie.

**Consequence, and it is the good one: Louie does not know either.** He knows what he did. He does not
know what happened. So the record he writes can only be the first thing.

## A2 · Two records, and the design forces exactly two

| The player | Louie's journal entry says | Michael inherits |
|---|---|---|
| lowers the rifle | *he let a boy go* | a grandfather who spared someone |
| fires | *he fired, and does not know* | a grandfather who tried and failed to kill a boy |

**Nothing else branches. One authored moment, two records, one chain.** No world state, no flag read by
any other system, no second spine. The cost is two passages of cursive lettering.

**And Michael only ever has the journal.** He cannot check. Neither can the player, once he is Michael.
The dramatic irony belongs to the person holding the controller — which the treatment already argued is
*"the one thing this medium can do with this story and no other medium can."*

## A3 · The scar — a proposal, labelled as one

**What the page actually shows** (bible §2): the young German is drawn with *"a large, deliberate scar
down one cheek — a mark of identity applied in the panel where he is spared."* **The scar is on the page
in the MERCY version.** That is the fact.

**The proposal, offered as a proposal:** the same scar is on his face in both branches. In the mercy
branch he already had it. In the shoot branch, the player's round put it there. **One face, two
explanations, and nobody in the fiction ever learns which is true** — because Louie never sees him again
and Michael only has the journal.

This costs one face and no extra art, it does not contradict the drawn page (the scar is present either
way), and it makes the player's bullet the mark by which the SS officer is later identifiable — without
a single line of dialogue saying so. **His to accept or throw out.**

## A4 · Neither choice may pay
Sparing must not grant anything and shooting must not grant anything — no score, no rank, no unlock.
The moment one is worth more, the player is optimising a chain the whole design says he does not
control. **This also satisfies the standing law that loud play is never the optimal strategy.**

## A5 · Where it sits
**WW1, and only WW1.** This is Louie's beat (I3 p5, one word: *"Run..."*). There must NOT be a Vietnam
echo of it that the player also plays — see Correction 2. The Vietnam side of this rhyme is the sniper
declining to fire on a file at a stream (I3 p13), which the player experiences from the *receiving* end
and never as a choice.

---

# PART B · THREE CORRECTIONS TO `QUEST_STARTERS_VIETNAM.md`

Offered exactly as that file asks — deepened or overruled from the pages. Its five starters are sound;
these three things would send the build wrong.

## CORRECTION 1 — **THE SHELL HOLE cannot be the first build, because the system it names does not exist**
The starter says: *"The conversation system runs. He answers."* and recommends it as **RECOMMENDED FIRST
BUILD** on the grounds that *"the conversation system exists."*

**There is no conversation system in RECONgame.** Verified this session by repo-wide grep, not from a
doc: zero `.gd` files match `dialogue`; no `ConversationSystem`, `DialogueData`, `BountyManager`,
`WorldLexicon` or quest JSON anywhere; `project.godot`'s autoload block registers none of them.
`production/DEMO_TWO_QUESTS_PLAN_2026-09-06.md:165` recorded it already: *"There is no dialogue system.
grep -rli dialogue scripts/ returns zero files."* All NPC speech in this game today is a one-line
all-caps toast on `signal toast(text: String)` (`field_director.gd:7`).

**So THE SHELL HOLE is the most expensive of the five, not the cheapest.** A man you talk to for hours
requires a dialogue system to be written first. **It is still the best scene in the comic** — the
treatment calls the crater *"possibly the best scene in the comic"* and *"the one sequence that is
genuinely better in first person than on paper"* — but it is a headline build, not a first one.

**Its open question is also already closed by the pages.** The starter says *"the author is unsure who is
in the shell hole... The pages decide, not his summary."* The pages decided. Bible §2:
> ***"Durand is the answer the author could not remember."*** Issue 3 pp.3-7 — it is **Lt. Durand**, the
> officer from the trench, and the nurse at Issue 3 p7 is the outside witness: *"THIS man?! This man has
> clearly been dead out in the field for months."*

## CORRECTION 2 — **transposing the shell hole to Vietnam SPENDS the book's only external corroboration**
The starter proposes the shell hole as a Vietnam quest with the WW1 version as its later twin.

The bible and treatment both identify this scene as **the single moment in 88 pages when the world agrees
with a man's vision**, and they note exactly where the book puts it: *"it plants it in the past, in the
safest place... One witness, one time, one war back."* The treatment makes it a binding beat:
> *"Whatever version is built, it should get exactly one of these, and no more. The restraint is what
> keeps the horror psychological."*

**Run it twice and it stops being corroboration and becomes a rule of the world — which is the literal-
monsters adaptation the bible warns is "a different book."** Keep it in 1915, once. Michael's horror is
a different kind and the bible says so: *"Michael's visions are static and passive: things that stand
there and look back... Louie is talked to. That difference is the clearest characterisation the two men
get."* Giving Michael a talking corpse makes him Louie.

## CORRECTION 3 — **THE SHORT ROUND is already shipped; do not build it**
This corrects my own `synthesis.md` Quest 4 as much as anything. A code audit this session found every
element of it already in the game: deliberate scatter outside the shown ring
(`field_director.gd:906-927`, and the comment says it is on purpose), full damage to the player and to
civilians with 0.4x to allies (`combat_manager.gd:127-170`), a 45m danger-close second-press confirm
(`field_director.gd:541-549, 853-874`), and the tube-thump/whistle telegraph (`:899-903`).

**Demote it to one VO line for the Issue 2 p16 rhyme** — *"These are our own shells!"* — and stop.
One unpriced tension underneath it, recorded not solved: **the 0.4x indirect softening means the comic's
beat cannot land at full strength on your own men.** His call whether that stays.

---

# PART C · CONSOLIDATION — the five starters and my five are eight, not ten

| Thread | Starters file | `synthesis.md` | Ruling |
|---|---|---|---|
| **The trophies** | 1 · SOUVENIRS (finding them on patrol) | Q2 · LEAVE THE BAG (the object left behind) | **Two halves of one arc — keep both.** Accrual, then disposal. |
| **The sniper** | 3 · HIS GROUND | Q1 · THE RIFLE THAT DOES NOT FIRE + Q5 · THE DUGOUT | **Collapse to ONE thread, three faces.** A devil's-advocate pass found Q1 and Q5 are the same quest — the sniper as an empty place found after the fact. Rumour -> a hide with a sightline onto your own crossing -> the dugout. |
| **The absence** | 4 · THE CARD | Q3 · THE MAN WHO IS NOT AT STAND-TO | **The card is the affordance for the absence, not a separate quest.** Cheapest legal r4bk answer: a name missing from a roll the player has already heard ten times — subtract, don't add. |
| **The mercy** | 5 · THE MERCY | (WW1, Part A above) | **Ruled. WW1 only.** |
| **The shell hole** | 2 · THE SHELL HOLE | — | **Keep, in 1915, once. Not the first build.** |
| **The short round** | — | Q4 | **Cut to a VO line. Already shipped.** |

---

# PART D · TWO ENGINE FACTS THAT CONSTRAIN ALL OF IT
Found in code this session, recorded so no design leans on air.

1. **The command/toast channel is radio-gated, and the post-demo player starts with no radio.**
   `_radio_check()` (`field_director.gd:814-821`) gates every command toast. The pivot has the player
   **solo first, then a radio, then an RTO, then up to eight men** — so for the first tier of that
   progression the one-line channel **does not run at all.** Any quest that pays off through a radio
   line is silent until the player has earned the radio. **Design the earliest quests to pay off in
   OBJECTS AND PLACES** — which is what LEAVE THE BAG and the dugout already do, and is another reason
   they should come first.
2. **The roster has no "missing" state.** `squad_roster.gd:169-197` carries only `alive: true/false` and
   `ensure_roster` drops the dead — so a man who is absent-but-alive is **stood back up at dawn by the
   spawner.** THE CARD / stand-to needs a third state before it can exist, and the dugout's
   "recognisable helmet" is unsupportable as written because the dead man's helmet record is deleted
   before the wall is ever found. **The helmet wall should be authored and fixed at world-gen**, not
   grown from the player's losses — a wall that grows is the world-state decay layer he ruled out,
   wearing a prop's clothes, and attached to the one character the bible says never has visions.

---

# PART E · STILL OWED TO HIM
1. **Is Louie French, or an American in French service?** The bible reads the pages as *"French, from
   Aix-en-Provence"*; his own synopsis says *"a young guy from the usa who travels oversaes and joins
   the french army."* Different faces, different kit, and one whole theme rides on it.
   **This blocks drawing Louie and it blocks THE MERCY's staging.**
2. **Is Champs a Corporal or a Lieutenant?** The source contradicts itself across its own erratum.
3. **The scar proposal** (A3) — accept, or throw out.
4. **Does the 0.4x ally softening on indirect fire stay?** It caps how hard the short-round rhyme can land.
5. **A fifth map-mark noun** for a cold sniper hide. The four-noun vocabulary in
   `scripts/player/field_mark_verb.gd` is deliberate; adding to it is his call.
6. **The Vietnamese side.** The treatment's own warning stands and I have designed nothing that depends
   on resolving it: without her, *"every named antagonist in the story is European and the Vietnamese
   are terrain."*
