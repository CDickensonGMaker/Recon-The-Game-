# THE DEBATE — Hearts & Minds, 2026-08-05

Four architects worked independently with no cross-talk. This records where they converged, where
they fought, and how the Arbiter resolved it. Full analyses in `analysis/`.

---

## WHERE THEY CONVERGED (independent, and therefore the strongest signal this process produces)

**1 · NAME THE PLACE.** All four arrived at the same fix for the same problem, by four different
doors, without conferring.

- Game designer: the AAR must name the cause by proper noun — `THEY HAVE NOT FORGOTTEN AN THO` —
  and formally proposed amending ADR-019 §4 to permit it.
- Writer: at the first hostile turn per district, one bark names the place, once ever —
  `THEY AIN'T FORGOT [PLACE]`. Called it his strongest single recommendation.
- Devil's Advocate: proposed the acceptance test *"the Summoner must, unprompted, say something to
  the effect of 'that ville has it in for me' — naming the PLACE, not the game."*
- Systems designer: arrived structurally — the ledger's `reason` string IS the debrief; a list can
  answer "why did that ambush happen" and a float can only shrug.

When the systems man, the dramatist and the sceptic independently demand the same sentence, that
sentence is load-bearing. **It is the decree's centre.**

**2 · The night-siege road is free and already built.** All four found `siege_director.gd:191` →
`NIGHT_CHANCE` → 0.05/0.15/0.30/0.45 and said the same thing: feed `effective_threat()` and the
loudest consequence in the design lands with no new machinery.

**3 · Bug A is worse than reported and must be deleted rather than fixed.** Writer and DA reached
this separately. The toast fires; the reaction never has. Writer: it is the game narrating the
player's conduct in capital letters, which ADR-019 forbids on its face.

**4 · Village population composition is the highest value-per-unit-of-work tell.** Game designer
ranked it #1; DA independently named "the ville that used to have people outside and now has none"
as one of only three candidate tells that survive his *"could this be luck?"* test.

---

## WHERE THEY FOUGHT

### FIGHT 1 — Per-village, or one number?

**Systems designer:** hybrid. A per-village dated decaying conduct ledger on `CampaignState`, plus
one derived AO scalar feeding the existing threat road. Argued the `add_threat_modifier` *shape* is
correct because a list forgets by construction and carries its own reason string.

**Devil's Advocate:** per-village is a trap. ADR-017 §7 requires stable generator indices, they do
not exist, and *the project's only shipped example of persistent world damage does exactly the
forbidden thing* — `CampaignState.remember_collapsed_tunnel` keys on a rounded world position with a
3.0m tolerance (`campaign_state.gd:479-492`). Build on `CampaignState` alone with one AO number, and
write the amputation down as an amendment rather than smuggling it.

**ARBITER — the systems designer wins, and the DA's objection is what makes the win legitimate.**
The DA's case rests on the premise that stable village identity does not exist and is days of
world-gen work. **The systems designer measured that premise and it is false.** Villages are
generated one per quadrant in a fixed loop (`mission_generator.gd:550-567`); the loop ordinal IS
ADR-017 §7's deterministic generator index. It is computed today and thrown away. `HamletNames`
already assumes such an index exists. The hook is three lines, not three days.

So the choice the DA framed as *(a) global number now* vs *(b) ProvinceState never* has a third
door he did not have the measurement to see: **per-village identity without ProvinceState.** The
hybrid needs no province generator, no district, no determinism probe and no save migration.

**But the DA's warning is upheld in full and becomes binding:** the position-hash pattern is live at
`civilian.gd:309` and at `campaign_state.gd:479-492`, and it is the only village-id precedent in the
repo. Left alone it is what the next agent copies. Laying the real id does not merely enable the
ledger — it deletes the wrong answer before it becomes the convention.

### FIGHT 2 — Does the fast road pay?

**Game designer:** yes, four ways, all immediate — the informer road is deleted, the patrol is over
and you are inside the wire before dark, cache intel without the search hour, and the district goes
genuinely quiet for two or three patrols. The player must be allowed to conclude "it worked" and be
*correct* while he concludes it.

**Devil's Advocate:** then it is not a dilemma, it is a dominant strategy. An immediate, legible,
reliable benefit paid against a delayed, illegible, probabilistic cost. §4 hides the cost, which does
not stop optimisation — *it makes optimisation correct.* Recommended breaking §3 narrowly, in
writing: the fast road pays on the **tactical** axis only, never the strategic one.

**ARBITER — both, split on the DA's axis.** The game designer's four payoffs are adopted, minus one.
Three of them are tactical (harassment stops, the patrol ends, the district is quiet for a few
patrols) and survive. **The fourth — cache intel delivered faster — is struck.** Intel is the
strategic currency of this game (`recon-bodies-give-intel-only`), and paying atrocity in strategic
currency is what converts a dilemma into a solved puzzle.

And the Arbiter finds a fifth payoff neither man proposed, because the systems designer found it in
shipped code and presented it as a *feature*: wrecking villages raises threat, and
`field_director.gd:1425-1429` grants napalm and CBU at HIGH, Spectre at CRITICAL. **Atrocity
currently buys ordnance.** That is the dominant-strategy loop closing on itself inside code that
already runs, and it is a defect. It is Decision 6 below because the fix touches a shipped system.

### FIGHT 3 — Will anyone ever notice?

**Devil's Advocate, at length:** no. The signal is a change in the distribution of random events in
a game already saturated with unattributable randomness (six sources, all pointered). A human cannot
perceive a rate change without a counter, and the counter is banned. ADR-018:88-91 already convicted
this exact bet. And Bug A is the proof it is not hypothetical — *a no-op ran in this game for weeks
behind a toast and nobody, including the Summoner, noticed.*

**Game designer:** agreed on the diagnosis, disagreed on the cure. Four discrete states with
hysteresis, never a smooth curve. The internal number may be continuous; **what the world renders
must snap.**

**ARBITER — the DA's diagnosis is upheld and it reshapes the build order.** He is right that a rate
is imperceptible, and right that ADR-019 §4's own list of tells is largely *"a rate wearing prose."*
Trail-trap density and ambush frequency are struck as *primary* tells; they are texture, not signal.

What survives is what all four independently converged on: **discrete, local, attributable events
that the player can name.** The empty ville with the warm fire. The man who used to point, gone.
A trap on ground you walked clean last week. And the sentence that names the place.

The DA's acceptance test is adopted verbatim as the gate.

### FIGHT 4 — One system or two, with the cord tokens?

**Writer:** not a fossil. The cord is HIS ledger — what he became, private, pause-only. Hearts and
minds is THEIRS — what they think, world-only. *"You did this." / "They know."* One coupling only:
the ear verb feeds both from one call — **the cord grows on COUNT, the district reacts on WITNESS.**

**Devil's Advocate:** they share one input and that is where they collide. Ruled that ears must feed
exactly one system, and preferred the cord because the cord is attributable and allegiance is
forbidden from being lookable.

**ARBITER — the writer wins on a distinction the DA did not have.** The DA's double-dipping
objection assumes both ledgers key on the same fact. They do not. An ear taken in an empty treeline
grows the necklace and costs nothing; the same ear taken in front of a woman grows the necklace *and*
moves the district. **The count and the witness are different facts, and the split is exactly the
seam the PARKED cord doc left open** (its open question 2: *"does the squad react to the cord?"*).

The writer's constraint is adopted as law: **hearts and minds renders only what the district DOES.
It never itemises the player's conduct back to him.** The cord is the only artifact of what he did.

### FIGHT 5 — What is the retrofit hook?

**Systems designer:** the village id. Bug B is a real bug fixable any Tuesday with no data-shape
cost; village identity is different in kind, because a ledger keyed on anything else orphans on any
generator change.

**Devil's Advocate:** one `add_threat_modifier` call at `_bank_patrol` — the only hook whose absence
forces a retrofit, because it is the only one that determines whether anything survives the wire.

**ARBITER — the systems designer.** The DA's candidate is not a hook, it is v1's first line of
implementation; it can be added on any day at no cost, because it writes into a store that already
exists. A hook is defined by what its *absence* makes expensive later, and only the village id
qualifies: every save written without it is keyed on a value that is not stable under generator
change. That is ADR-017 §8's "wrong hut burned," which that ADR calls worse than no persistence.

---

## WHAT THE DEVIL'S ADVOCATE PROVED THAT NOBODY CAN ARGUE WITH

Three findings survived every rebuttal and are recorded as facts, not positions:

1. **There is no burn verb.** `EvidenceLedger.on_structure_burned` has zero callers; the only thing
   that ignites a hut is `cas_airplane.gd:383-384` and it does not touch the ledger. ADR-019 is
   founded on a sentence the game cannot execute. *(Found independently by the systems designer.)*

2. **Bug B is inert today, and the real gap is bigger.** `_bank_patrol` never shows a debrief screen
   at all — `DebriefScreen` is constructed only at `game_flow.gd:459`, reached from a handler wired to
   `director.mission_failed` (`game_flow.gd:670`). **A successful patrol has no debrief surface.**
   That, not the missing key, is what blocks ADR-019 §4's sanctioned sentiment line.

3. **F-8 "Hearts & minds thin slice" is already an open item in the demo backlog**
   (`DEMO_SHIP_BACKLOG.md:1184`), inside his own Q6 value order. This council would otherwise be read
   as authorising it. It is ruled OUT below, explicitly.

He also surfaced the session's sharpest fact: the demo assault is a **fixed timer** —
`SIEGE_AT_S = 1440.0`, `SIEGE_STRENGTH = 45` (`demo_game.gd:54, :69`) — and the Summoner himself
ruled on 2026-08-04 that day-kills must not affect it. He then experienced it as retaliation for his
conduct. **A fixed timer plus a toast naming his own act was sufficient to produce the felt
experience of an invisible faction system.** That is the cheapest lesson in this document and it
shapes the entire build order.
