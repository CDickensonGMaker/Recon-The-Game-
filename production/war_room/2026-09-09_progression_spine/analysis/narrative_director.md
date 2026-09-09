# NARRATIVE DIRECTOR / WRITER
## War Room 2026-09-09 · THE PROGRESSION SPINE · the story lens

Read: `briefing.md`, `analysis/evidence_pack.md`, `analysis/measurements.md`, the three
`CONQUEST_OF_WORMS_*` drafts, `adr/ADR-020-authored-threshold.md`, `adr/ADR-041-authored-places.md`,
`FIREBASE_REWORK_INTENT.md:70-120`. Nothing here proposes work before launch.

---

## 1 · THE CENTRAL TENSION — THE CARRIER RULE

An authored beat wants the player at a place at a time. The sim does not know where he is. The way out
is not to compromise between them. It is to **stop attaching beats to places and times at all.**

> **THE CARRIER RULE: an authored beat must ride on something that MOVES WITH THE PLAYER, LOOKS FOR
> HIM, or WAITS INDEFINITELY. A beat attached to a coordinate is not a beat. It is a PLACE, and places
> are ADR-041's business.**

Conquest of Worms has exactly three carriers, and it needs no fourth:

1. **THE OBJECT HE CARRIES** — the journal. It is in his ruck. It cannot miss him, because it is on
   him. It waits forever and costs nothing while it waits.
2. **THE MAN BESIDE HIM** — Gus. A squadmate whose state advances on campaign events, not on map
   position. Wherever the player goes, Gus is where the player is, or is conspicuously not.
3. **THE THING THAT HUNTS HIM** — the sniper. He does not sit at a coordinate waiting to be triggered.
   He is seeded into the AO the player is already in. He solves the delivery problem by *being the
   entity that looks*.

Each passes ADR-020's leave-test on its own terms, and it is worth saying exactly how, because that test
is the thing that must still be saying no in two years. The journal: he can walk away from his own bunk
and never open it — a book is not diminished by being unread, which is the whole point of a book. Gus:
the decline runs on campaign time whether the player watches or not; you come back from a patrol and the
necklace is on him now. The sniper: he watches, and does not fire, and the patrol walks on.

**The fourth channel, and the cheapest one this project owns: THE GUTTER.** The comic kills Sgt. Maddox
in a subordinate clause — *"ever since Sgt. Maddox ate that bullet the other week"* — and that restraint
is the whole tone. Its game form is a **bark in the chow line**. A report cannot miss a player, because a
report finds him whenever he happens to sit down. It has no trigger volume, no camera, no rail, and the
system already exists (`vo_manager.gd`). **The living world does not stage events for the player. It
tells him about them afterwards.** That is not a workaround for the sim; it is the register the comic
already writes in, and the sim is the reason we get to use it honestly.

**On the anti-re-readable law** (`DEMO_TWO_QUESTS_PLAN §5`): the ban is on re-reading **instructions**,
not on re-reading **literature**. A briefing screen is forbidden because it removes the cost of having
listened. A journal is a document that exists inside the fiction and contains no task. **The hard rule
that keeps it legal: the journal may never name a place to go, a man to find, or a thing to do.** The
day an entry does, it has become a briefing screen and it must be cut.

**SACRIFICED:** every guaranteed set-piece. There is no moment in this design the player is promised to
see. Some players will finish a campaign having never met the sniper, never opened the journal, and
having heard about Gus only in a bark. That is the price of the leave-test, and it is a real price.

---

## 2 · THE SOLO LADDER — IT IS NOT THE COMIC'S ARC, AND IT SHOULD STILL BE THE SPINE

The honest reading first, because the flattering one is wrong. **Michael is never alone.** He arrives on
page 3 into a functioning squad with a sergeant, a friend called Eyes, and an officer pushing pep pills.
The comic's isolation is *social*, not tactical — he is the man nobody has decided about yet. So the
ladder does not reproduce the comic's plot.

**It reproduces the comic's subject, which is better.** The subject is a boy being handed people by an
institution that then takes them back. Maddox is handed to him and dies in a clause. Gus is handed to him
and goes wrong. Eyes is handed to him. The ladder makes that a verb.

And it resolves ADR-021 rather than colliding with it. **ADR-021's tutorial is the comic's first act.**
New in country, you follow — Maddox sets the waypoints, you hump the Thumper, you learn the game by being
led. Then Maddox eats a bullet in the gutter, and the solo stretch is **act two, not act one**. The
ladder starts at its bottom rung because the man above you died offhand, which is the tone, the tutorial,
and the reason for the pivot in a single event. Nothing needs deleting.

**Does the ladder give the game a narrative spine it lacks? Yes — the game currently has none.** It has a
world, a reputation number and no first-person arc whatsoever. But a ladder that only goes up is a power
fantasy, and this is not one.

> **THE LADDER MUST HAVE A DOWN. The first man the game gives you is the man who goes wrong.**

Gus is the down-rung. You are given a companion before you have earned one, and he is the wrong one.
Everything after that is earned against that memory.

**SACRIFICED:** Pillar 4's squad is deferred by hours of play, and a squad the game can take back reads
to some players as punishment rather than tone. Accepted — it is the same bet *Platoon* makes.

---

## 3 · THE SNIPER AS A SYSTEM

He is not a boss. He is **a flag on an AO with four presence tiers**, advancing on a hidden counter that
never reaches a screen (ADR-032):

- **RUMOUR** — a village vendor, a bark in the chow line. No entity spawns. Free.
- **SIGN** — a cold hide the player can walk past without noticing: brass, flattened grass, a helmet on a
  stake. A prop placed by the planner, not a trigger.
- **SILHOUETTE** — he spawns, in cover, at long range, **with fire authority OFF**. He watches, and he
  leaves. This is Issue 3 p13, and it is the design document.
- **CONTACT** — he fires. Once.

**The Fairness Law is not a compromise here; it is his characterisation.** A near-miss at an unaware
player is exactly the panel — the rifle that declines to be a threat. It routes through
`suppress_along_shot()` already, so the crack, the shader and the 650 Hz lowpass *are* his voice. **The
miss is the character.** Give him a reliable second shot that lands and you have built a different,
smaller man.

**The Ambience Law binds hardest on the abduction, and it forbids the obvious version.** He may not take
a living named ally, because a taken man the player must go and get is a mission wearing ambience's coat.

> **He takes only from the dead and the missing. The helmet wall is your KIA list, rendered as a place.**

No counter, no bookkeeping, no screen. You walk into a hole in the ground ringed with skulls (ADR-041,
authored site) and you recognise helmets. The payoff scales with your own failure, which is the most
honest scoring this project could have. And the porters who feed him hook straight into ADR-019: a
village that likes you warns you; a village that does not, feeds him.

**If the player kills him early — and he must be killable, or he is scenery — nothing announces it.** No
end card, no achievement, no replacement spawned. The porters stop coming. The rumours change tense: men
in the chow line start saying *there was* a ghost. The wall stays exactly where it is. **The game does
not supply the comic's missing ending; it supplies a STOP.**

**SACRIFICED:** an antagonist who mostly does not shoot is an antagonist a large fraction of players will
never register as a character at all. That is inherent, and the alternative — making him unmissable —
kills him.

---

## 4 · WW1 — RULING: (a) NOW, (b) CONDITIONALLY, (c) NEVER FOR THIS STORY

**(c) a separate title is dead on arrival.** The chain is the spine: the sniper is caused by Louie's
mercy. Ship the cause in a different box three years later and the cause never ships. Keep "Tour of Hell:
WWI" as a *franchise* slot for a different, unrelated war story — it is a marketing structure and a good
one — but this story's WW1 cannot leave this game.

**(a) narration is the version that ships first, and it should ship regardless.** The journal read aloud
in the dark costs voice lines and a lettering treatment. It carries the thesis, the second lettering
face, and Louie's voice at effectively zero art cost. Do this even if (b) never happens.

**(b) playable is legal and correct — conditionally, and the condition is already named.** A WW1 zone is
precisely what ADR-039 exists for, and the journal-at-the-bunk transition is the most diegetic zone
change this project will ever get. But **WW1 may never justify its own art budget.** It becomes
affordable only as a by-product: the terrain morph tool plus a modular trench kit are being proposed
right now for the firebase rework, and a WW1 battlefield is that tool's output with a different kit
(`FIREBASE_REWORK_INTENT.md:107`). **Rule: if the trench kit exists for the firebase, WW1 is playable. If
it does not, WW1 is narration.** The story does not get to order the tool.

When playable, it is Continuation C's shape — **three closed sequences, not a front**: the burial detail,
the crater with Durand, and the patrol that ends with the young German. And the leave-test survives
inside the zone: **closing the book returns him to the bunk, mid-sequence, and the sequence remembers
where he stopped.** A player must be able to put a book down.

**SACRIFICED:** a player who never opens the journal never learns why any of it is happening. Accept it.
That is what no-rails costs — and the comic pays the same price, since the chain is undrawn there too.

---

## 5 · NO ENDING — AN OPPORTUNITY, AND THE ANSWER IS ALREADY DRAWN

Not a fatal flaw. In a witness game it is barely a problem, because a witness needs an **exit**, not a
resolution. And the comic drew the exit on Issue 1 p19: *"Only 320 days left for ya?"*

> **THE TOUR CLOCK IS THE ENDING. The campaign ends when the tour ends. That is not a victory; it is
> out-processing.**

The sniper may still be out there. Gus is on a plane. Nothing is answered. Pillar 4 already promises men
who rotate home and no rotation clock exists anywhere in the code — so the ending this story needs is a
feature the pillars already owe the game.

**Ruling: do not write an ending for the comic. Write an out-processing for the game.** And note the one
genuinely open fork, which is his: whether a player's death starts the next replacement in the same
world, with the last man's name on a card in a footlocker. That is Pillar 5 and the comic's own
replacement premise meeting exactly, and it is not mine to decide.

---

## 6 · THE HORROR — VIBE, ZERO SYSTEMS

His rule makes the first-person problem sharp: every horror image belongs to a mind. In first person that
mind is the player's, and **the player's mind is not authorable.** So world-state gore is illegal and a
sanity meter is unauthorised. What is left is not thin:

1. **Give the horror to NPCs.** *"I swear I saw skeletons out in the bush"* is one VO line on a man on
   the wire under flares. The player sees nothing. That is the comic's own calibration point, and it is
   the whole vibe for the price of a bark.
2. **The gutter.** Deaths reported, never staged.
3. **Reskin what exists.** The suppression shader and the 650 Hz lowpass are already a psychological
   readout rendered on the player. Darkening that register at high nerve is tuning, not a system.
4. **Wandering Soul.** Real, documented, institutional — a ghost tape over the trees at night. The army
   itself is in the hauntings business. Audio asset, no code.
5. **Art direction on things already modelled**: worms on the corpses `BodyCount` already persists;
   ordnance decals lettered *DUCK + COVER* and *FUCK YOU CHARLIE*; the draft-card and army-manual
   paperwork motif on menus and the character record.

**One guardrail, taken from his own restraint: exactly ONE external corroboration in the whole game,
ever — and it belongs to Louie, in 1915, where the nurse confirms the corpse.** Never in the player's
Vietnam. Corroborate the player's own vision once and you have made a monster game.

**SACRIFICED:** Michael's nightmares. A first-person camera cannot do a daydream that a voice interrupts.
**PANEL-ONLY means CUT, not deferred** — stop trying to adapt them.

---

## 7 · GUS — AN NPC YOU WATCH, AND HE IS THE FIRST RUNG

**Ruling: Gus is a companion the world assigns before the ladder lets you choose one, and he is the man
who goes wrong.** McCleary's line is already written: *"until Brass can get an actual spot for him, he's
going to be floating around where ever we need him to be."*

He is a **character asset with states, not a script**: the necklace appears on the model, he lags the
file, he is found sitting with a corpse, he is beaten and exiled, and one day he walks back out of the
bush. Every state advances on campaign time. **The player's only agency is whether he reports him, covers
for him, or shoots him** — governed by the existing ROE / Hearts & Minds surface, with no meter (ADR-019
§4). No new system.

**Not a thing the player can become.** That requires the sanity system he has not authorised, and it
breaks the horror rule outright. And do not leave him in the comic — he is the best drawn material in it.

**The hard guardrail, from the `fya.12` correction: he is crying, not melting. Gus stays legible as a
person to the last frame he appears in.** No monster shader, no red eyes, no boss fight with Gus. Ever.

**SACRIFICED:** an arc on campaign time will sometimes complete while the player is out on patrol, and
some players will only ever hear about it. That is the gutter and it is the tone — but it means the best
material in the source is not guaranteed to be seen.

---

## 8 · NAMES AND VOICE

**The product is *Tour of Hell: Vietnam*. The story inside it is *Conquest of Worms*.**

The franchise brand names the mechanic — a tour, and hell, and the clock that ends it. It is era-tagged
and it already carries Korea and WWI. *Conquest of Worms* is a thesis title: it promises horror in a work
that is eight-ninths dirt, and as a box name it mis-sells the game the way the pilot cover mis-sold the
comic. Its right home is **the story layer** — the campaign spine, set in his own worm logotype on the
loading screens, sitting inside the paperwork motif beside the draft cards. A player who never opens the
journal still bought a complete war game. A player who does, finds a book inside it with a name on it.

**On voice: Michael has no voice-over.** The player is Michael, and a narrator speaking over the player is
the puppet ADR-020 forbids. The comic's two lettering faces become the game's division of voice:

- **Typewriter — Vietnam — the SQUAD.** All present-tense voice in the game is other men talking near
  you. That is the register the sim can carry, and the only one that cannot miss you.
- **Cursive — 1915 — LOUIE.** The only first-person prose in the entire game is a written document that
  exists inside the fiction, and it is his grandfather's.

**SACRIFICED:** he does not get his own book's name on the box, and Michael never gets Willard's voice —
the one register the treatment correctly identified as already his. Both are real losses, and both are
the cost of a game whose player is a witness rather than a narrator.
