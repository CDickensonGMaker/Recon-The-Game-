# GAME DESIGNER — INDIVIDUAL SIGHT
**War Room 2026-09-07 · SQUAD COHESION AS A COMBAT MECHANIC**
Lens: player fantasy, the feel of the fight, what the player is DOING second to second, the arc across a patrol.
Written independently. No cross-talk. Every code claim below carries a `file:line` (POINTER LAW).

---

## 0 · THE CLAIM, FIRST

**Cohesion is real, it is Pillar 1's second clause, and it is ALREADY BUILT AND SHIPPING. It is invisible.
The gap the Summoner found is real — but it is not a design gap. It is an r4bk gap on a system that has
been running in the demo for two weeks and that no player, including him, can perceive.**

The game already runs, every fight, per side, per squad:

- **A base of fire.** One elected suppressor slot per squad, preferring a covered machine gunner, never a
  mover — `scripts/ai/squad_coordinator.gd:196-216`, `:180-195`.
- **Exposure tokens.** The *right to be out of cover* is rationed — 3 for US doctrine — so the squad never
  all stands up at once. HOLD and fire-from-cover are never gated. `squad_coordinator.gd:116-178`,
  `data/ai/doctrine_us.tres` (`exposure_tokens = 3`, `token_ttl_ms = 6000`, `grant_stagger_ms = 600`).
- **Two-element bounding overwatch.** Elements alternate mover / base-of-fire on a 7-second clock —
  `squad_coordinator.gd:129-138`, `doctrine_us.tres` (`bound_period_ms = 7000`).
- **A per-squad covering-fire census.** Each man knows whether *his* squad, not some patrol 400m away, is
  covering him — `squad_coordinator.gd:93-115`, consumed at `scripts/allies/ally_base.gd:189-191`.
- **Break, on one authority for both sides.** `scripts/squad/squad_system.gd:554-592` judges the player's
  squad by `EnemySquad.break_state` exactly as it judges an NVA squad. A broken squad stops closing and
  goes cover-first (`ally_base.gd:212-232`).
- **Nerve that moves inside a fight.** Falls 0.12 per mate down within 25m, recovers 0.02/s, floors at
  −0.30 — `ally_base.gd:122-158`.
- **A physical rally.** The player steadies a man only when he is within 6m **and between that man and the
  threat** — `ally_base.gd:130-135`, `:160-181`.

That list is Find/Fix/Flank/Finish. It is Brothers in Arms' fire-and-manoeuvre, running without a command
cursor and without a tactical pause, exactly as the Summoner's instinct says Vietnam should. **It shipped on
2026-08-24 and it has never made a sound.**

Search the presentation layer for any of it. The squad strip (`scripts/ui/mission_hud.gd:249-291`) shows
name, OK/HIT/CRIT/KIA, role, radio state, and the point man's scan radius. It shows **nothing** about
covering fire, bounding, exposure, nerve or break. `squad_broken` produces exactly one toast and one VO line
(`squad_system.gd:585-592`). There is no bark when the elements swap. There is no bark when a man takes a
token and moves. **The most sophisticated system in this codebase is mute.**

> **The felt problem and the actual mechanism are different systems** — the briefing's own lens, from the
> BiA modding session where *"I shoot people and they don't die"* was an accuracy bug, not a damage bug.
> Here it fires again: **"the squad has no cohesion" is a presentation defect, not a simulation defect.**

---

## 1 · WHAT "COHESION WINS THE FIGHT" ACTUALLY MEANS, SECOND TO SECOND

### The WW2 line battle vs the Vietnam ambush

BiA's fight is a **puzzle with a solution**. You arrive at a known distance from a known enemy in a known
piece of terrain. You Find, you Fix with the base-of-fire team, you Flank with the assault team, you Finish.
The tactical pause exists because the puzzle deserves consideration. Cohesion in BiA = *did you issue the
right two orders*.

The Vietnam ambush inverts every one of those. **You do not Find — you are found.** The enemy chose the
ground, the time, the axis, and whether the fight happens at all. You begin at Fix, and it is *you* who are
fixed. There is nothing to consider, because the entire tactical situation was decided before the first
round cracked. **A tactical pause in a Vietnam ambush would be a lie about the war.**

So the second-to-second play splits into three windows, and they are not the same game:

**T+0 to T+2 — THE CRACK. Nothing tactical happens.** You get down and you shoot back. There is no decision
here worth making and the design must not pretend there is. This window is governed entirely by the Fairness
Law's near-miss, and see §4 Q5 point 6 below — it is already the most generous moment in the game and nobody
has ruled on it.

**T+2 to T+8 — THE SOP.** The squad reacts *without you*. It already does: the player's first shot flips the
whole squad weapons-free automatically (`squad_system.gd:57-58`, `_auto_flip_armed`), men go cover-first by
personality (`ally_base.gd:212-224`), the coordinator elects a base of fire, tokens clamp how many are up.
**This is correct and it should stay automatic.** A squad that waits three seconds for a cherry rifleman to
press F3 is not a squad, and it is not Vietnam.

**T+8 to T+40 — THE RECOVERY. This is the game.** And what decides it is not orders. It is **geometry**.

### Cohesion is geometry, not a stat

Here is the actual content, stripped of vocabulary. When an ambush hits a patrol, the squad's problem is
that it is in the shape the *enemy* chose — strung out in file along the long axis of a trail, being
enfiladed. Winning means changing that shape: getting off the trail, getting **on line facing the ambush**,
and getting somebody putting rounds down so somebody else can move. That is all cohesion is.

**Cohesion is the measurable state of the squad's shape relative to the threat.** Are men mutually
supporting — is anyone covering anyone — or are they five men in five separate holes each fighting his own
private war? The coordinator already computes precisely that (`has_covering_fire`, the token census, the
element split). **The ambush does not drain a resource. It physically breaks your shape.** That is a real
event that already happens in the demo today, on the ground, visibly, and it needs no new system to occur.

**This is the crucial distinction and I will hold it against every other proposal in this council:** a
geometric model of cohesion produces failures the player can *see on the ground and learn from*. A resource
model produces failures he reads off a meter. Pillar 1's contract is that *death comes from situation, never
hit-point math* — and a hidden cohesion scalar deciding your fight is hit-point math relocated from the
bullet to the squad. It is the exact thing ADR-018 killed, wearing a different uniform.

---

## 2 · THE LINE GRUNT PROBLEM: DOES BiA'S MODEL BREAK, OR RESHAPE?

**It reshapes, and canon already did the reshaping — but the clause is PROVISIONAL and this council is the
moment it was reserved for.**

The merged Pillar 4 of record (`production/bible/BIBLE.md:88`) reads:

> **"The squad is the RPG — and you are IN it, not above it… You are a member of the squad, not its
> puppeteer — you suggest movement, call targets, request support, and the squad holds its own AI intent.
> A design that has you positioning individual men violates this pillar."**

BiA's command cursor is named and forbidden by that sentence. **But read the next paragraph**
(`BIBLE.md:89-95`):

> **"PROVISIONAL — under playtest review (Summoner, 2026-07-19).** Pillar 4's second clause is the one
> pillar he has flagged as open: *'pillar 4 is open to changing as i play test more. if it makes more sense
> to try to be more tactical with the troopers i will take it that way.'* … **Do not treat the
> anti-puppeteer clause as settled law until he rules from play.** The other four pillars are not
> provisional."

**This is the single most important fact in my analysis and the Council must put it in front of him.** The
whole orders-vs-SOP question is not open for us to decide. It is the one clause he explicitly reserved, and
he reserved it in exactly these words — *"more tactical with the troopers."* Brothers in Arms is what "more
tactical with the troopers" looks like. **This council is the ruling he deferred, and it should be handed to
him as a ruling, not resolved by architects.**

My recommendation on that ruling, as the game designer:

**Hold the anti-puppeteer clause. Do not import the command cursor.** Three reasons that are about feel, not
doctrine:

1. **The fantasy dies.** *Platoon · Hamburger Hill · Apocalypse Now* — GAME_GUIDE §1 and `BIBLE.md:103-106`
   — are films about men with **no control over anything**. Chris Taylor does not direct a flanking element.
   The instant the player gets a command cursor he stops being the cherry and becomes the lieutenant, and
   the whole tonal north star has to be renegotiated. That is a much larger change than it looks.
2. **You would be commanding blind.** The jungle sight cap is **45m** (GAME_GUIDE §4.9). A command cursor
   you cannot see the battlefield through is a UI that lies. BiA's cursor works because a French hedgerow at
   200m is legible from behind a wall.
3. **It is the wrong scarcity.** The tension in an ambush is that *you cannot fix it fast enough*. Handing
   the player enough authority to fix it is the removal of the game's best emotion.

**But say the sacrifice out loud:** holding the clause means the player will sometimes watch his squad do
something stupid and have no way to correct it beyond four blunt orders. That is a genuine, recurring
frustration and it is the price. The mitigation is not more orders — it is §4 Q2's readout, so that when
they do something he can at least *understand what they think they are doing*.

---

## 3 · IF THE SQUAD REACTS ON ITS OWN, WHAT IS LEFT FOR THE PLAYER?

**Two things, and both are more interesting than issuing orders.**

### (a) YOUR BODY IS THE ORDER

`ally_base.gd:130-181` already implements this and it is, I think, the best-designed thing in the codebase
that nobody knows about: the rally bonus only fires when the player is within 6m **and geometrically forward
of the man, between him and the threat.** The comment at `:131-134` records why — a proximity-only version
was permanently on, floored everyone at 0.50 courage, and made the coward branch unreachable.

That is *lead from the front* as a physics fact. **The player's contribution to cohesion is where he puts
his body**, and it is already a verb he has, on the keys he already owns, requiring no HUD and no new
binding. He decides where the line forms by walking there and standing on it, and his men steady around him.

This is Pillar 4's merged text executing perfectly: you are IN the squad, not above it, and your influence is
positional. **It is also completely invisible.** A player has no way on earth to learn this rule from play.

### (b) THE ORDERS THAT REMAIN ARE THE RIGHT FOUR

FOLLOW / HOLD / MOVE-TO / FIRE-TOGGLE (ADR-012, `project.godot:196-217`). In an ambush recovery, exactly one
of these carries the whole weight: **MOVE-TO — *the line forms there*.** That is a squad-level intent, not
puppeteering, and it is the correct granularity. FIRE-TOGGLE is the stealth economy's verb. HOLD is the
break-contact verb. FOLLOW is the reset.

**Four is enough. I want no fifth key and I will argue against one.** ADR-012 records that four prime keys
(C/H/X/N) are already spent and both bindings are permanent. A fifth order is expensive, and every candidate
I can construct ("rally", "on me", "get online") is FOLLOW with urgency — a *modifier* on an existing verb
(double-tap FOLLOW), never a new binding. **And I do not think we need it for the demo.**

### Is that more or less interesting than issuing orders?

**More**, and specifically: issuing orders is interesting *once*. Position is interesting *always*, because
the terrain is different every time. An order system's skill ceiling is "learn the four right orders." A
positional system's ceiling is "read this piece of ground." The second one is the game we are actually
building — Pillar 3, the seeded world generates the tactical problems.

**Named cost:** positional influence is far harder to *teach* than a button, and a player who never notices
it never gets the game's best mechanic. That is precisely the r4bk debt below, and it is why I will not let
cohesion claim ADR-018 §2's silent exemption.

---

## 4 · THE FIVE MANDATORY ANSWERS

### Q1 — Is cohesion a real mechanic here, or a re-skin of suppression/morale we already have?

**It is REAL, it is DISTINCT from suppression and morale, and we already have all three — we present none
of them.** They are three different quantities and it matters that the council not merge them:

| | What it measures | Where it lives | Presented? |
|---|---|---|---|
| **Suppression** | *this man's* incoming pressure | `ally_base.gd` `incoming_pressure`, `ANCHOR_SUPPRESS` | no |
| **Morale / nerve** | *this man's* willingness to fight | `ally_base.gd:122-158` nerve drift; `squad_system.gd:554-592` break | one toast, one VO line |
| **Cohesion** | **the SQUAD'S SHAPE — who is covering whom, who may move, which element is up** | `squad_coordinator.gd` (whole file) | **nothing, anywhere** |

Cohesion is the only one of the three that is a *relational* property. Suppression and morale are per-man
scalars; cohesion is a graph. That is why it is not a re-skin, and it is also why it is the hardest of the
three to show.

**So the answer to "is cohesion a first-class combat mechanic in RECONgame" is: it already is one, and it is
the only first-class mechanic in the game with a zero-byte presentation layer.**

### Q2 — If real, what is the player-visible verb? (r4bk binds.)

**No new verb. The verbs are his feet and MOVE-TO, both of which he already has. The missing thing is not a
verb at all — it is a SENSE.** r4bk binds on *affordance*, not on *input*, and the affordance cohesion needs
is audio, not a key.

**And cohesion may NOT claim ADR-018 §2's silent exemption. Here is the reason, and it is a hard one:**

ADR-018 §2's exemption works because *the affordance is the man himself* — a veteran point man raising a
fist before a trip wire is a visible body doing a legible thing at 5m. **Cohesion has no equivalent body,
because cohesion is not a man, it is the shape of five men — and in jungle at a 45m sight cap you cannot
see the shape of your own squad.** That is not a UI failure. It is Pillar 2 working correctly. **The
geometry is structurally unwitnessable, so the silent exemption is unavailable to it, and the affordance
must be one the jungle does not block: SOUND.**

**The proposal, in priority order, cheapest and best first:**

1. **VOICE ON THE EVENTS THAT ALREADY FIRE.** The bounding element swaps every 7 seconds
   (`doctrine_us.tres bound_period_ms`); a token is granted and released (`squad_coordinator.gd:144-179`);
   the suppressor slot is elected (`:200-216`). **Nobody says a word.** Wire `VOManager.play_squad` to those
   three existing events: *"MOVING!"* on the token grant and the covering man's *"MOVE!"* answer; *"I'M
   UP!"* on the element swap; *"SUPPRESSING — GO!"* on the slot. This is the single cheapest, highest-feel
   change available in this project. Zero art-days, zero pixels, zero keys, and it converts a mute
   simulation into the most BiA-feeling thing in the game. **The player will not SEE fire and manoeuvre. He
   will HEAR it, from behind a bush, at 20m — which is exactly how a grunt experiences it.**
2. **ONE WORD IN THE STRIP THAT ALREADY EXISTS.** `mission_hud.gd:271` already writes
   `"SQUAD // WEAPONS FREE"`. Make it two facts: `"SQUAD // WEAPONS FREE // ON LINE"`, with three states —
   **ON LINE** (someone is covering, elements alternating) / **STRUNG OUT** (no covering-fire census, men
   spread past the file deadzone) / **BROKEN** (`squad_broken`, already computed at `squad_system.gd:578`).
   A word, never a bar, never a percentage. All three read off data that exists today.
3. **A GLYPH PER MAN in the rows that already exist** (`mission_hud.gd:274-291`) — covering / moving /
   pinned / down. One character. Not a bar.

**Item 1 alone is most of the win. Items 2 and 3 are the fallback if voice does not land.**

### Q3 — What does it cost? Name the sacrifice.

**Four costs, and the first one is the real one.**

1. **MAKING THE COORDINATOR AUDIBLE MAKES IT AUDITABLE — and it may not survive the audit.** Today nobody
   can tell whether the bounding overwatch is genuinely good, because nobody can perceive it. The moment men
   call *"MOVING!"* and *"COVERING!"*, the Summoner and every player will hear immediately whether the squad
   is truly bounding or thrashing — men calling "moving" while standing still, elements swapping while
   nobody is in cover, a suppressor slot firing at a point up to eight seconds stale
   (`suppress_point_ttl_ms = 8000`). **Expect to spend days on AI you believed was finished.** This is the
   correct cost to pay — a system nobody can evaluate is a system nobody can improve — but it is not a free
   win and it must not be sold to him as one.
2. **A legible state becomes a farmed state.** "ON LINE" will be chased. Guard: **cohesion is a SENSOR,
   never a FAUCET** — ADR-006 Amendment B §4's line, applied here. It may never bank, never pay rank, never
   appear in the AAR as a number.
3. **Naming the thing invites the meter.** The moment "cohesion" is a word in this project, someone builds a
   bar. Any ADR out of this council must forbid the bar in the same sentence it names the concept, the way
   ADR-040 §1 forbids the health pool.
4. **The demo's climax is a SIEGE, not an ambush.** In the firebase assault the squad is static in a trench
   and the cohesion loop barely applies. Cohesion-as-recovery lives only in the day half — out the wire,
   hunter teams (`field_director.gd:112-182`) — for perhaps two contacts in thirty minutes. **Honest scope
   statement: this makes the demo better; it does not carry the demo.**

### Q4 — Where does it collide with an existing ADR?

| ADR | Collision | Ruling |
|---|---|---|
| **ADR-018** | Any cohesion number that changes *how well men shoot* is player-stat progression by another route. | **Hard line: cohesion may change what men DO, never how well they SHOOT.** The existing code already respects this — nerve drives `wants_cover_first` / `may_close_distance` (`ally_base.gd:212-232`), never spread; `skill` is rolled once at spawn (`:140-152`). Keep that boundary exactly where it is. |
| **ADR-012** | Four prime keys spent; neither binding removable. | **No fifth order.** Any rally verb is a modifier on FOLLOW, and not in demo scope. |
| **ADR-020** | An order that stops working *is the controls being taken away* — the rail test's spirit. | **Order-gating is forbidden.** See Q5 point 6. |
| **ADR-006-B §4** | "Body count may move HQ's words, never HQ's grant." | Same shape: **cohesion may move the squad's behaviour, never the player's reputation faucet.** |
| **ADR-040 §3 + §5** | **The collision that matters.** Losing cohesion is precisely how you arrive at the down state — and out on patrol `BodySwapSystem` does not exist, so the down state *is* the entire safety net, with **zero verbs** (`player.gd:1922-1945`). | **Cohesion's failure state routes straight into the game's least-finished thirty seconds.** You cannot ship a cohesion mechanic that is *interesting to lose* before ADR-040 §3's LOOK + VOICE exists. §3 is PARKED and its files are FROZEN. Name this dependency in the decree. |
| **r4bk / ADR-018 §2** | May cohesion be silent, as squad XP is? | **No** — see Q2. The 45m sight cap makes squad geometry structurally unwitnessable, so the exemption is unavailable and the affordance must be audio. |
| **THE GATE (§8.0)** | Which side? | **Split, honestly:** the voice wiring and the two-word strip are *presentation for a shipped system* — **GATE-EXEMPT by §8.0's own exemption list**, though they should still not start before his playthrough. ADR-040 §4's near-miss hole is a **bug fix — GATE-EXEMPT**, and already named as such. **Any cohesion resource, meter, drill layer or order gate is a feature epic — GATE-BLOCKED, and I recommend it never be built at all.** |

### Q5 — Which of the Summoner's six points does canon CONFIRM, and which does it REFUTE?

**1 — PARTLY CONFIRMED, wrong pointer, and the truth is stronger than the claim.**
Pillar 1 as written in GAME_GUIDE §1 says HLL lethality and names no BiA. But the **merged pillar text of
record** (`BIBLE.md:85`) reads: *"Believable firefights — AI that fights like soldiers and weapons that kill
like weapons, neither subordinate. **Squads spread, use cover, suppress and manoeuvre**…"* — that clause is
Brothers in Arms, verbatim, in **Pillar 1**. So: the FEEL is canon and it is Pillar 1's own second half.
Brothers in Arms is not named anywhere in canon; the named references are Platoon / Hamburger Hill /
Apocalypse Now for tone and Arma / OFP / SOCOM / Vietcong for mechanics. That distinction matters, because
§2 shows the BiA *command model* is a separate question with a separate answer.

**2 — CONFIRMED, but credited to the wrong law and under-credited.**
It is not Pillar 2 that solves the WW2-spectacle problem. It is **ADR-020 §3** — THE HORIZON (caged on
purpose) / THE DOOR (reachable, joinable) / THE PASSER-BY — and especially **§3.1: *"if the player can walk
to everything, the world is exactly as big as the map."*** That is a far more specific and already-ratified
answer than "atmosphere," and it comes with a binding test and a law that the cage must be **geography,
never an invisible wall** (§3.2). His instinct is right and the machinery is already decreed.

**3 — REFUTED, twice, and this is the most valuable finding in my analysis.**
*(a)* **Pillar 4 is not about attachment.** He read the superseded text. GAME_GUIDE §1's *"minimal stats,
maximal attachment"* was merged and amended on 2026-07-19; the text of record (`BIBLE.md:88`) is a
**combat-authority clause**: *"you are IN it, not above it… you suggest movement, call targets… a design
that has you positioning individual men violates this pillar."* That is a sentence about winning fights, not
about feelings.
*(b)* **"No ADR appears to cover this" — cohesion is covered in Pillar 1 itself** (*"squads spread, use
cover, suppress and manoeuvre"*) **and it is BUILT.** `squad_coordinator.gd` ships a suppressor slot,
exposure tokens, a per-squad covering-fire census and two-element bounding overwatch, with per-faction
doctrine in `data/ai/*.tres`, from the 2026-08-24 council. **The gap he found is real but it is one layer
down from where he put it: not a missing mechanic — a missing affordance.**

**4 — CONFIRMED, and stronger than he stated: it is law, and it is already code.**
The merged Pillar 4 forbids the player positioning individual men outright, and the SOP already fires
without orders — the squad auto-goes-loud on the player's first shot (`squad_system.gd:57-58`) and the
coordinator runs with no player input at all. **His instinct is already canon and already shipping.**
**One correction that must go to him personally:** that Pillar 4 clause is **PROVISIONAL** — he flagged it
open on 2026-07-19 pending playtest (*"if it makes more sense to try to be more tactical with the troopers i
will take it that way"*, `BIBLE.md:89-95`), and it is the only provisional clause in the five pillars. **This
council is the ruling he deferred. It belongs to him, not to us.** My recommendation is in §2: hold the
clause, and pay for it with the readout instead.

**5 — CONFIRMED as design, with one correction that improves it.**
Yes: you begin already fixed, and the Find phase is gone from the firefight. But ADR-021 §3 shows it did not
disappear — **it moved out of the firefight and into the week**: *"PATROL TO LEARN THE GROUND. USE THE
GROUND TO KILL THEM… the ghost run and the gun run are the same run, a week apart."* Find/Fix is the quiet
patrol. Flank/Finish is the ambush you set with what you learned. **The BiA loop is not truncated in
RECONgame; it is stretched across sessions** — a better structure than BiA's, and already ratified. That is
the arc across a patrol my lens was asked for, and it already exists on paper.

**6 — SPLIT. The order-gate half is REFUTED. The near-miss half is CONFIRMED and ALREADY TRUE, unruled.**

*REFUTED — "a resource that gates which orders function":*
- There are exactly **four** orders and every one is survival-critical. Taking HOLD or FIRE-TOGGLE away
  mid-ambush is not tension; it is a dead button, and **players read a non-responding key as a bug, every
  time, without exception.** ADR-012 forbids removing either binding besides.
- **It is the controls being taken away in the exact moment the player most needs them** — ADR-020's rail
  test in spirit if not in letter.
- **It is hit-point math relocated from the bullet to the button.** A hidden scalar deciding whether your
  input works is precisely what ADR-018 killed and what Pillar 1 forbids: *death from situation, never from
  a stat sheet.* A player who dies because his cohesion number was low did not die from situation.
- **"Drills restore" requires a training layer that does not exist** and is far outside the 2026-09-06 EA
  scope wall.

*REFUTED — "the ambush SHATTERS it":* not as a stat. **The shatter is physical and it already happens** —
men scatter to cover, the file breaks, and the catchup system exists precisely because they end up 40m
adrift (`squad_system.gd:686-763`). Modelling that physical fact as a draining number adds nothing the world
does not already do, and it costs the legibility of §1's geometric model.

*CONFIRMED, and further than he knew — the near-miss is ALREADY the recovery window:*
**ADR-040 §4** records that the Fairness Law's first-shot near-miss flag is **per-man, not per-engagement** —
so *"a six-man ambush opens with six independent near-misses, and opening lethality scales inversely with
ambush size."* The ADR calls it *"generous and atmospheric"* and states plainly: **nobody ruled it.** That is
exactly the mercy window his point 6 wants to build, and it is already in the game, unnamed and unpriced.
**It does not need a cohesion resource to become load-bearing. It needs his ruling.** And in the same
section, ADR-040 §4 names the hole that most hurts the ambush case — *the near-miss triggers on the SHOOTER
ENTERING COMBAT, not on the player being unaware,* so a man already fighting your squad who swings onto you
spends no warning shot. **That fix is a bug fix, GATE-EXEMPT, and it is the highest-value single change in
this entire subject area.**

---

## 5 · THE FAILURE STATE — what a player who is bad at this experiences

The briefing asks this, and it is the question that decides between the two models.

**Under the resource / order-gate model:** he presses X, nothing happens, and he does not know why. He dies.
He blames the game, correctly, because the game did take the controls. Nothing was learned and the death was
not legible. **This is the worst failure state available in this design space and it is disqualifying on its
own.**

**Under the geometric model — and this is what already happens in the build today:** he walks his men down a
trail in file. The ambush is laid on the long axis of the file, which is what an ambush is. Six near-misses
buy him about a second and a half. He runs one of the two textbook wrong ways — deeper into the kill zone,
or back down the trail he came up. Two men drop; every man within 25m loses 0.12 nerve
(`ally_base.gd:154-158`); the squad falls under its break threshold; `"SQUAD COMBAT INEFFECTIVE - BREAKING
CONTACT"` prints and `fall_back` plays (`squad_system.gd:585-592`). His men stop closing and anchor
(`ally_base.gd:226-232`). He is alone and forward, with hunter teams converging on the evidence ledger. He
goes down. The down state has **no verbs**, and out on patrol there is **no body swap** — thirty seconds as
furniture (ADR-040 §3, §5).

**That chain is entirely real today, and it is the whole argument in one paragraph.** Every step of it is
legible in the world — the file, the trail, the men dropping, the men stopping — *except the last thirty
seconds, which are blank.* So:

> **Cohesion's failure state IS ADR-040's parked work. Making cohesion matter makes losing it matter, and
> the place you land when you lose it is the least finished thirty seconds in the game.**

That dependency should be stated in whatever decree comes out of this council, because it will otherwise be
discovered the hard way, in a playtest, after the feature lands.

---

## 6 · WHAT I WOULD ACTUALLY DO, IN ORDER

1. **RULE THE PROVISIONAL PILLAR.** Put `BIBLE.md:89-95` in front of him. Orders vs SOP is his reserved
   call and this is the session it was reserved for. Everything below assumes he holds the clause.
2. **CLOSE ADR-040 §4's NEAR-MISS HOLE.** Bug fix, GATE-EXEMPT, already named, highest value per hour in
   this whole subject. And **ask him to rule the per-man near-miss** — six free misses in a six-man ambush
   is either the mercy window he wants or a bug, and nobody has decided which.
3. **GIVE THE COORDINATOR A VOICE.** Three VO hooks on events that already fire. Presentation for a shipped
   system, GATE-EXEMPT, zero art-days. **This is the change that will make him feel Brothers in Arms.**
4. **ONE WORD IN THE SQUAD STRIP.** ON LINE / STRUNG OUT / BROKEN. Existing panel, existing data.
5. **BUILD NO COHESION RESOURCE. EVER.** Write the refusal into the ADR beside the concept, in ADR-040's
   style, so the meter is answered with a document rather than a number when it comes back — and it will
   come back.
6. **RECORD THE DEPENDENCY:** cohesion's failure state needs ADR-040 §3 (LOOK + VOICE), which is PARKED with
   FROZEN files. Do not let a cohesion epic thaw it by the side door.

---

## 7 · THE SACRIFICE, NAMED PLAINLY

**I am telling this council that the mechanic the Summoner wants is already built, and that the work is
presentation. The cost of being right about that is that presentation exposes the simulation.** Voice makes
the bounding audible, and audible means judged. If `squad_coordinator.gd` turns out to bound badly — and
eight-second-stale suppress points and six-second token TTLs give it room to — then this proposal does not
deliver a finished feature. It delivers a diagnosis, and a bill.

**I would still take that trade, because right now nobody in this project — including the man who is going
to ship it — can tell whether the best system in the codebase works at all.**


---

## PHASE 3 — RESPONSE TO THE REFRAME

**His words:** *"for the demo im not worried about the rotation effect of the squad AI. i just want realistic
feeling and looking combat coming from both the allied npcs and the enemy npcs. right now its like 60
percent there, but not as smooth looking as a call of duty 1 or brothers in arms."*

---

### 1 · THE RULING: ANIMATION VS LEGIBILITY

**My split: roughly 25% animation, 75% legibility — and "legibility" here means CADENCE AND COMMITMENT, not
UI.**

I went and looked at the animation layer before ruling, because it would be cheap and wrong to assume it is
the weak half. It is not the weak half. This build has, today:

- a **0.18s crossfade** on every clip change, with a comment recording *why* — "hard cuts between clips read
  as pops" (`scripts/visuals/model_actor.gd:1033-1034`);
- **foot-planting by playback rate** — `set_locomotion_speed` divides real ground speed by the clip's
  authored metres-per-second and scales playback (`model_actor.gd:1078-1086`), so feet plant instead of
  skating;
- **8-octant directional locomotion** (`sprite_state_map.gd:_with_octant`), a **turn-in-place** intent off
  measured root rotation (`:28-58`), a **crouch family** with its own speed cap so a crouch reads as a
  crouch and not a skate (Bible 04 Law 3), a **prone** path, and a **`cover_to_stand` transition** with a
  1.5s debounce against cover-thrash;
- an **additive directional flinch** that punches the spine without replacing the clip
  (`scripts/visuals/flinch_modifier.gd`), so a running man keeps running while he takes a round;
- **yaw smoothing** at `1.0 - exp(-12.0 * dt)` (`model_actor.gd:980`).

**Call of Duty 1 had none of that.** No octant strafes, no speed-matched playback, no additive flinch, and
its blend times were coarser than 0.18s. **If a 2003 game with a fraction of this rig reads smoother, the
missing thing is categorically not clips.** That is the finding, and it is the one only this seat can make:
the technical artist auditing blend times will find good blend times and report the system healthy, which is
true and does not answer his complaint.

**What CoD1 and BiA have that this build does not is DIRECTION.** In those games, a soldier makes one
decision, runs one clean uninterrupted line to a hand-placed spot, and then **stays there, still, for a long
time.** Most enemies visible on screen at any given instant in CoD1 are **not moving at all**. Stillness is
what makes motion legible. Motion against motion is noise.

**This build has continuous nav steering toward a scored cover point, re-evaluated at 6.7 Hz**
(`THINK_INTERVAL 0.15`). Even with good hysteresis — 2.5s interrupt refractory
(`combat_goals.gd:26`), 8s cover dwell (`doctrine_us.tres`), the `_cover_fail_count` lockout — the *path* a
man walks is a continuously-corrected curve, not a committed dash. The eye reads a corrected curve as
**milling**. It reads a straight line that starts hard and stops hard as **soldiering**.

---

### 2 · THE PROJECT ALREADY LEARNED THIS LESSON — IN THE SIEGE, AND IT WROTE IT DOWN

This is the most important thing I found in Phase 3. `scripts/missions/siege_director.gd:615-619`, on the
press rotation, carries this comment:

> *"THE PRESS ROTATES BY SQUAD, not by man. Scattering the press across individuals put **a third of every
> squad walking while the men beside them held — which reads as indecision, not as fire and movement.** A
> whole squad rushing while the others shoot is the thing that looks like soldiering, and it is why the
> squads exist."*

**Somebody on this project already hit his exact complaint, diagnosed it correctly, fixed it, and recorded
the rule — for the siege only.** The rule is: *the moving unit must be a whole visible group, never a
fraction of one.*

**Now apply that rule to the squad fight, where it was never applied.** US doctrine grants **3 exposure
tokens** to a squad of 5–8 (`data/ai/doctrine_us.tres`, `squad_system.gd:23 SQUAD_SIZE = 8`). NVA is 3, VC
is 2. **Three of five men moving while two hold is, precisely and literally, "a third of every squad walking
while the men beside them held."** The siege comment condemns that pattern by name. The squad-scale fight
does it every fight.

**And the machinery to fix it already exists and is already wired.** `squad_coordinator.gd:129-138` splits
the squad into two elements and alternates them on `bound_period_ms` (US 7000, NVA/VC 5000). The tokens are
just not element-scoped tightly enough to make the split visible. **Correction is data, not code:** drop US
`exposure_tokens` to **2**, raise `grant_stagger_ms` from 600 to ~900 so movement starts are visibly
sequenced rather than near-simultaneous, and verify that a granted token is refused to the PASSIVE element
outright rather than merely deprioritised. That is a `.tres` edit and a probe. **Zero art-days.**

*(Correction to a claim I nearly made: `assault_press` sets `exposure_tokens = 999`, `grant_stagger_ms = 0`,
`bound_period_ms = 0` — which looks like the governors switched off in the siege. It is not. The siege
replaces them with its own **coarser, squad-granular** rotation on an 8-second cycle
(`siege_director.gd:66 PRESS_CYCLE_S = 8.0`, `:608-640`). That is the correct architecture and it is the one
I am asking be extended downward. I record the near-miss because "compare like poses before calling it
broken" is a standing law here.)*

---

### 3 · THE MISSING 40%, RANKED FROM THE PLAYER'S SEAT

He gave a number. Here is my ordered guess at what it is made of, most to least, from the seat:

**1. NOTHING IS EVER STILL. (~15 of the 40)** Too many men moving at once, and each move is too short. The
frame has no rest state, so there is no baseline against which movement reads as *an event*. This is the
whole of the CoD1/BiA difference and it is a tuning problem, not an art problem.

**2. MOVES ARE NOT COMMITTED. (~10)** A man drifts toward cover with continuous correction rather than
running one line and stopping hard. Nav steering plus a 6.7 Hz brain produces curved, hesitant paths.
BiA men commit and arrive.

**3. NOTHING TELEGRAPHS ITS INTENT. (~7)** The Fairness Law binds the *enemy* to telegraph to the player
(flash, tracers, voices). **Nothing binds the squad to telegraph to the player.** A man about to move gives
no tell: no look at his destination, no half-second wind-up, no shout. In BiA a bound is *announced* before
it happens, so the eye is already pointed at the man when he goes. **This is a design gap, not an animation
gap, and it is the cheapest item on this list.**

**4. THE PIVOT SLIDE. (~5)** `turn_l`/`turn_r` fires only when the intent is otherwise `idle`
(`sprite_state_map.gd:57`). A man **aiming** who swings 90° to a new threat therefore rotates his whole body
with no stepping animation under it — the classic sliding-pivot tell, and it happens constantly in a
firefight because that is when men reorient. Narrow, specific, probably a one-line intent-gate widening.

**5. FOOT SLIDE OUTSIDE THE BAND. (~3)** `set_locomotion_speed` clamps playback to **0.6–1.4×**
(`model_actor.gd:1084`). Any real speed outside that window slides. The crouch cap (1.9 m/s) and combat
speed multiplier (`COMBAT_SPEED_MULT 0.48` on a 5.6 base = 2.7 m/s) should be checked against each clip's
authored rate; a clamp that saturates is a slide with a good comment on it.

**WHAT I WOULD TEST FIRST — and it is cheap, falsifiable, and nobody has run it:**

> **THE STILLNESS CENSUS.** In the arena, over 60 seconds of a live fight: (a) what fraction of visible men
> are in motion at any instant, and (b) what is the **median duration of one continuous movement**?
>
> **My prediction, on the record so it can be wrong:** motion fraction well above 40%, and median move
> duration **under 1.5 seconds**. CoD1 would score roughly 20–30% and 2–4 seconds. If the census comes back
> at CoD1's numbers, I am wrong and the answer really is animation — and that is worth knowing in one
> afternoon rather than after a week of clip work.

This is a **probe**, therefore GATE-exempt as evidence-gathering, and it prices the entire question before
anyone spends an art-day.

---

### 4 · THE SIGHT-CAP TENSION — HONESTLY RESOLVED, AND I WAS PARTLY WRONG

**He does refute me, and I change the position.** In Phase 2 I argued the affordance "must be" audio because
squad geometry is structurally unwitnessable at a 45m sight cap. That conflated two different readouts:

- **THE SQUAD'S GLOBAL SHAPE** — who is where, is the line formed, is anyone flanking. **Still
  unwitnessable at engagement range. I hold that.**
- **ONE MAN'S STATE** — is he moving, holding, covering, pinned, hit. **Fully witnessable, and he is right.**

**The resolving fact is that the readable range is much shorter than the engagement range, and that is
fine — because the men whose state you need to read are YOUR OWN, and they are standing next to you.** The
follow slots roll at **2.5–4.5m** (`ally_base.gd`), the nameplate identifies a man at **5m**
(`squad_nameplate.gd:11`), and the rally geometry only works inside **6m** (`ally_base.gd:130`). **Your
squad lives inside conversational range, well under the sight cap.** So posture-as-state is not blocked by
the jungle at all — the jungle blocks you reading the *enemy's* shape, which is correct and is the game.

**So the two channels are complementary, not competing:** the man you can see reads off his body; the two
men you cannot see read off voice. **I withdraw "the affordance must be audio." The correct statement is
that audio covers the off-screen half of the squad, and the body covers the on-screen half — and he has
named the on-screen half as the priority.** He is right, and it is the cheaper half.

---

### 5 · THE SIEGE — WHAT ACTUALLY HURTS THERE

The demo climaxes with 45 men on the wire (`SIEGE_STRENGTH`), and that is the trailer shot. Ranked by what
hurts most **in a siege specifically**, which is a different list from the patrol list:

1. **EVERY MAN IS A CLONE.** GAME_GUIDE §8 step 3 already names it: **`EnemyBase` has no dresser call at
   all**, and the art is on disk. **Forty-five identical men is a smoothness defect even though it is not an
   animation defect** — the eye reads repetition as cheapness and attributes it to the animation. In a
   5-man patrol contact you never see enough men at once to notice. In a 45-man assault it is the first
   thing you see, and it will be in every frame of the trailer. **Highest-value single item for how the
   siege LOOKS, it is already on the ship order, and it costs zero new art.**
2. **DEATHS AND FLINCHES AT VOLUME.** In a siege you see many men hit per second. The flinch is additive and
   good; the death set is `randi_range` across a clip list (`model_actor.gd:945`). Repetition across 45 men
   in 90 seconds is far more visible than in a patrol fight. Worth a count of how many death clips exist
   before anything else is authored.
3. **SILHOUETTE AT RANGE.** A siege is fought at 60–120m across cleared fields of fire — *longer* than the
   jungle sight cap, not shorter. At that range posture is the only thing resolvable and faces are nothing.
   Which means: **the siege is where posture-as-state pays and where nameplate/HUD readouts pay nothing.**
   This reinforces his reframe rather than my Phase 2 position.
4. **The press cadence is already right** (squad-granular, 8s) — **do not touch it.** If the siege reads
   better than the patrol fights today, §2 is why, and that is the evidence for the §2 proposal.

---

### 6 · THE ARENA IS THE RIGHT INSTRUMENT — WITH ONE PRECONDITION

**Yes.** Pillar 1's text of record names it as its own gate: *"the stress-test arena is the gate: if
soldiers cannot fight believably in a deliberately ugly arena, beautiful terrain will not save the game"*
(`BIBLE.md:85`). `scenes/levels/ai_stress_arena.tscn` exists and its script is 2,504 lines.

**And "60 percent" should be measured there, not in the demo**, for one reason: the demo confounds the
measurement. In the demo you cannot separate *"the AI moves badly"* from *"I cannot see the AI"* —
vegetation occlusion, a 45m sight cap, night, weather and draw distance all sit between his eye and the
behaviour. The arena removes every one of those. **A judgement of smoothness taken through a jungle is a
judgement of the jungle.**

**THE PRECONDITION, and it is not optional:** the last measured framerate is **19–25 FPS** with
`rendering_method` unset, and the three perf probes (THE WALK / ONE DIG / THE BARRAGE) **have never been
run** (GAME_GUIDE §4.9, §8 step 1). **At 20 FPS, everything looks unsmooth, and a human being cannot tell
frame-pacing judder from animation blending — he will attribute the stutter to the animation and he will be
wrong.** Ship-order step 1 exists for exactly this and it is the gate on this whole question.

> **Run the perf probes first, or the arena measurement is contaminated and the 60% number means nothing.**

Two further conditions: run the arena **separately under US and under NVA/VC doctrine** (they are different
`.tres` files producing genuinely different-looking fights, and *"both the allied npcs and the enemy npcs"*
is his phrasing), and run it **with the stillness census instrumented** (§3) so the session produces a
number and not an impression.

---

### 7 · POSITIONS I CHANGE, STATED PLAINLY

1. **I WITHDRAW the HUD word** — the `ON LINE / STRUNG OUT / BROKEN` addition to the squad strip
   (Phase 2 §4 Q2 item 2) and the per-man glyph (item 3). **He answered the readout question with an answer
   nobody in Phase 2 offered: the readout is the soldiers.** He is right, it is better, and a HUD word would
   have been a UI patch over a motion defect. **Dropped from my recommendation entirely.**
2. **I WITHDRAW "the affordance must be audio."** See §4. Audio covers the off-screen half; the body covers
   the on-screen half; the on-screen half is the priority and the cheaper one.
3. **I RE-RANK MY OWN ORDER.** Phase 2 had voice at #3 and treated it as the headline. It now sits behind
   **the stillness census** and **the exposure-token/stagger retune**, and its justification narrows from
   "cohesion needs a sense" to **"movement needs a telegraph"** (§3 item 3) — which is a better reason and
   serves both halves of his sentence.
4. **I HOLD, unchanged:** cohesion is not a resource and never becomes one; no fifth key; the order-gate is
   refused; and cohesion's failure state still routes into ADR-040's parked down state.
5. **DEROS / rotation:** parked on his word. Noted, not argued.

**And I hold my Phase 2 diagnosis, which he has now confirmed in his own words:** the felt problem and the
actual mechanism are different systems. He said *"looking"* and *"smooth"* and everyone's hand went to the
animation budget. **The mechanism is how often men decide and how many of them move at once.** That is a
`.tres` file and a probe, not an art wave.

### The sacrifice, again, named

**If the stillness census comes back saying men already move as rarely and as decisively as CoD1's, I am
wrong, this whole section is wrong, and the answer really is clips — which is the expensive answer, in
art-days, against a 13–19 day budget.** That is the risk in my position and I would rather it be written
down before the probe runs than explained afterwards.
