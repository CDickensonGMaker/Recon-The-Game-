# GAME-DESIGNER — The Player Field-Marking Layer

**Lens:** does field-marking SERVE Pillars 2 (atmosphere), 3 (freedom/recon), 4 (squad-is-the-RPG),
5 (fail-forward) and the north star "leave camp and find problems"? Judged against ADR-022 (the map
is your memory) and ADR-029 §4 (no mission tracking). **Verdict: CONDITIONAL YES.**

This is not a new system — it is ADR-022's ANNOTATED layer (`ADR-022:35-49`, "grease pencil, scrawled,
the player's hand") finally getting its verb. ADR-022 already decreed the vocabulary (danger, rally,
cache, avoid + free text), the GREASE-PENCIL LAW ("the player's marks may be WRONG and the game will
NEVER correct them", `ADR-022:42-49`), and the plan-not-command rule (`ADR-022:51-53`). Everything the
briefing asks for is a build-out of a blessed ADR, not a new decision. That is the strongest possible
footing. My job is only to defend the *feel* against the four sacrifices ADR-022 already named.

---

## 1 · FOG-OF-WAR HONESTY — the stably-wrong ranged mark

**This is GOOD design, and ADR-022 already ruled it so — but it needs a LEGIBILITY FLOOR, not an
accuracy floor.** ADR-022:68-70 lists the exact objection ("The game didn't tell me they moved!") and
answers it: *"That is the design working. It will still generate complaints, and we will not fix it."*
The glassed camp that lands ~50m off and later becomes a lie is the fantasy, verbatim: *"Being wrong on
paper, and finding out the hard way, is not a bug in the fantasy — it IS the fantasy."* (`ADR-022:49`).

But the briefing conflates two different "wrongnesses," and only one is blessed:

- **STALE-wrong** (I marked CAMP truthfully; the camp later moved). This is pure fail-forward (Pillar
  5) — the world changed, my memory didn't, and walking back to a dead mark is a *story*. NEVER
  corrected. This is the whole engine.
- **PLACEMENT-wrong** (my binocular estimate landed the mark 50m from where the camp actually was, the
  moment I made it). This is the imprecision model the briefing asks me to design. It is legitimate
  (a real man's range estimate is off), BUT it has a failure mode ADR-022 never contemplated: if the
  error is large enough that the mark points at the *wrong terrain feature*, the mark isn't fallible
  memory, it's noise. A CAMP mark that lands across a river from any camp isn't "the map is your
  memory" — it's "the map is broken," and a playtester files it as a bug correctly.

**THE LINE (my ruling): imprecision must preserve RELATIVE truth, never absolute truth.** The floor is
not "≤X metres accurate" — it is *"the mark must land on the same side of the nearest legible feature
(ridge, stream, treeline, trail) as the real thing."* Concretely: cap ranged-mark error so it scales
with range (briefing's intent) BUT clamp it to never cross a major terrain edge the player can read on
the topo sheet. Within that clamp, be as wrong as you like. This keeps the mark USEFUL as a memory
anchor ("the camp's up past the bend") while keeping it WRONG as a coordinate ("...about here"). The
player should always be able to *navigate to* his mark and *then* discover the truth on foot. If the
mark is so wrong he can't even find what he marked, the fail-forward loop never closes — he just gets
lost, which is friction, not story. **Imprecision is the texture; findability is the floor.**

Draw imprecision diegetically: the ranged mark renders as a looser/larger grease scrawl (a fat
uncertain circle), a point-blank mark as a tight one. The player *sees* his own confidence. That is
Pillar 2 atmosphere doing the UX work for free — same principle as the CO's sweep-circle at
`topo_map.gd:141`, a deliberately loose hand-drawn arc, not a pixel pin.

## 2 · THE EYES-ON COST — recon loop or friction?

**It is a REAL recon loop, and it is the mechanic that finally pays Pillar 3's "stealth is an economy,
not a gate."** The cost — stop, raise binos, hold still, estimate — is not friction *before* the fun;
it IS the fun of a recon patrol. Vietcong/SOCOM flavor is the man who lies in the treeline and *watches*.
ADR-021→ADR-006 already established that a contact AVOIDED pays +25 and a kill pays zero; ADR-022:64-66
says the map is *"what ADR-006's +25 for a contact avoided"* buys — *"you avoided them, you watched them,
you wrote down where they go, and next week you kill them there."* The mark is the RECEIPT for that
watching. Without it, avoidance is an abstract score; with it, avoidance produces a durable object.

**What the player GETS — three distinct, load-bearing payoffs, so marking is never busywork:**
1. **The map becomes his memory** (ADR-022's thesis). Knowledge that used to die on game-close now
   persists as a thing he built by walking. This is the compounding loop.
2. **The TUNNEL/CACHE mark is a COME-BACK HOOK** — the briefing's sharpest instinct. A tunnel mouth I
   can't clear now ("come back and go inside") is a self-authored future objective *without an objective
   system* — the player plants his own hook, the world doesn't hand him one. This is the north star
   ("find problems") producing its own sequel for free. It is the single best argument for the whole
   feature.
3. **The CONTACT mark is the avoidance→ambush pipeline** — I watched them use this trail, I marked it,
   next patrol I'm waiting there. This is ADR-022:66's "one loop" tying stealth, the hunt, and
   patrolling together.

**The cost must gate on LOS + stillness (briefing option), NOT be a free minimap ping.** A free ping
makes the map a radar and murders Pillar 2. Requiring you to STOP and hold LOS is what makes the mark
*earned* — and it creates the tactical tension the recon fantasy needs: to mark the camp, you must
expose yourself watching it. That risk is the price of the intel, and it is exactly the right price.

**One friction guard (Pillar-3, the "before the fun" worry is real):** marking must be OPTIONAL and
never nagged. No "you haven't marked anything" prompt, no reward for mark-count, no mark-density meter.
A player who never marks a thing must have a complete game; the map is a tool offered, never a chore
assigned. The instant the game *counts* his marks it has become the checklist §4 forbids.

## 3 · PERSISTENCE — pillar WIN or scope distraction?

**Recommend: YES, persist marks to the firebase's accumulated AO map — but as a THIN slice in Phase 2+,
gated behind proving the in-patrol mark is fun first. It is a genuine Pillar-4 / ADR-017 win, not a
distraction, PROVIDED it stays memory and never becomes a tech tree.**

The case FOR (strong): ADR-022:35 already decrees annotated marks are *"persisted in the province ledger
FOREVER"* and ADR-022:60-66 calls this persistence *"the compounding knowledge loop that makes a long
campaign feel like YOUR campaign... the single most valuable object you own."* ADR-017 (persistent
province) is the ledger it lives in. This is not new scope — it is a decreed consequence I'd be
countermanding ADR-022 to cut. A tour-long AO map that thickens patrol by patrol is the deepest
expression of Pillar 4's "you are IN it" — the squad's shared institutional memory of *this valley*,
built by *this player*. That is the RPG progression this game has instead of XP bars.

The case AGAINST / the discipline it demands: persistence is where a memory-map most easily rots into a
progress-tracker (§4 violation). The guard: **the accumulated map may AGGREGATE and DECAY marks, it may
NEVER SCORE or COMPLETE them.** No "AO 60% explored." No region-unlock. No "intel level 3." Marks age
(ADR-022:26-34, OBSERVED marks *decay* — a three-day contact is a rumour and *looks* like one) and pile
up; that is all. The player reads his own thickening scrawl and *infers* progress — the game never
asserts it. If persistence can hold that line (probe it), it is the highest-ceiling payoff in the
feature and worth the scope. If the team can't guarantee the line in Phase 1, DEFER it — an in-patrol-
only mark is still a complete, shippable feature. **Do not let persistence's scope block the core mark.**

## 4 · VOCABULARY — small set vs. the checklist

**A small MILITARY grease-pencil set is on the RIGHT side of "the squad is the RPG, not a checklist" —
IF two rules hold.** ADR-022:74-76 already names the danger: *"Marker vocabulary will want to grow. It
must stay small. A map with thirty icon types is a spreadsheet."*

Recommended set (6, matching the briefing, all pre-blessed in spirit by ADR-022:35-40's "danger, rally,
cache, avoid + words"):
**CONTACT · TRAIL · TUNNEL · CAMP · CACHE · DANGER** (+ optional free text per ADR-022:37).

The two rules that keep this a vocabulary and not a checklist:
- **Every symbol is a NOUN (a thing in the world), never a VERB or a STATUS.** CONTACT/TRAIL/TUNNEL/
  CAMP/CACHE describe *what I saw*; DANGER is *my judgment of a place*. NONE of them is "CLEAR TUNNEL,"
  "SECURE CAMP," "OBJECTIVE." The moment a symbol implies a task the player owes, it is the objective
  vocabulary ADR-029 §4 and the briefing's HARD GUARDRAIL forbid. TUNNEL is "there is a tunnel here,"
  full stop — the "go inside" is the player's *choice*, held in his head, never a checkbox on the map.
- **The set is CLOSED and the game never suggests a mark.** No "press F to mark this trail" prompt when
  you look at a trail. The point man may VOLUNTEER a bark (ADR-022:55-57 — "trail's been used, few days
  back") but *he never marks the map for you; the pencil is yours* (ADR-022:57-58). The vocabulary is a
  palette the player reaches for, never a form the game hands him to fill in.

Render them in the period grease-pencil aesthetic (bitmap scrawl, same hand as the CO's loose arc at
`topo_map.gd:141`), NOT clean modern game icons — that ties to the researched-identifier polish and
keeps Pillar 2 intact. A CONTACT mark should look drawn by a tired man with a wax pencil, not printed.

## 5 · THE SINGLE SHARPEST PILLAR TENSION (for the Summoner)

**Pillar 3/5 (a wrong, fallible map is the fantasy) vs. the playtester's bug-report reflex — and the
sharper edge under it: a fallible map is only fun if the player can still FIND what he marked.**

ADR-022 already bit the bullet that "some players will read a wrong map as a bug, and we will not fix
it" (`ADR-022:68-70`). That is settled doctrine and I uphold it. The NEW tension this feature introduces
is subtler and the Summoner should rule on it: **the ranged-imprecision model can fail in a way the
stale-mark model never does.** A stale mark is *findable but wrong* (I go to the spot, the camp's gone —
a story). A badly-placed ranged mark can be *unfindable* (I go to the spot, there was never anything
there, because my estimate was 80m off across a ridge — that's not a story, that's noise). The first is
the fantasy; the second is the frustration a tester correctly files.

**The knife-edge the Summoner must set: how loose is too loose?** Too tight and the binocular estimate
is a GPS pin (kills Pillar 2, kills the recon skill of *learning to read range*). Too loose and the
mark can't be navigated back to (kills the fail-forward loop — the come-back hook has nothing to come
back to). My recommendation (§1): clamp error to *relative* truth — never let a mark cross a legible
terrain edge — so it is always FINDABLE and never PRECISE. But where exactly that clamp sits is a feel
call only playtest can tune, and only the Summoner can bless the principle: **do we protect
findability, accepting the estimate is never truly "raw"? Or do we let the estimate be fully raw,
accepting some marks will be unfindable noise?** I recommend the former. That is the one place this
feature can betray a pillar, and it is a dial, not a binary — so it must be TUNABLE and playtested, not
hard-coded on first build.

---

## SLOTTING & PROBE (for the Arbiter)

- **Phase 1 (with the spine):** pull the parked report-verb into core AS the mark verb — aim-and-press
  drops CONTACT/TRAIL/TUNNEL, reusing FieldDirector's `_cas_ground_target` ray-march (briefing:48-51 —
  NO third aim path). In-patrol marks only, no persistence yet. This is the cheap, high-value core.
- **Phase 2+ (the pencil pass):** ranged/binocular CAMP marks with the imprecision model (§1 clamp),
  in-M-map placement, and firebase persistence (§3) — each behind a playtest gate, same as the route
  pencil.
- **§4 PROBE:** structural test asserting (a) no mark type carries a completion/status field; (b) the
  mark vocabulary enum contains only nouns/place-judgments, no verbs; (c) no mark-count or coverage
  value is ever read by HUD or scoring; (d) the game emits no "mark this" prompt. Same family as the
  four route clauses — this is the fifth clause guarding the same §4 line.
- **ADR-022 amendment:** canonize the ranged-imprecision model + the FINDABILITY FLOOR (relative-truth
  clamp, §1) as the one place the grease-pencil law meets a legibility floor. ADR-022's law stays
  intact for stale marks; the amendment governs *placement* error only.
