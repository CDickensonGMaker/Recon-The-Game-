# BRIEFING — THE PROGRESSION SPINE
## War Room, 2026-09-09 · The Solo Pivot, the Radio Ladder, the Command Grammar, the Comic, the Franchise

**Convened by:** the Summoner (Caleb), in four successive messages during one session.
**Arbiter:** the Overseer.
**Status of the matter:** **POST-DEMO-LAUNCH WORK** (his ruling, verbatim: *"and post demo launch work"*).
The demo does not move. The siege playtest remains the last standing gate. EA scope is untouched.

---

## 1 · THE QUERY (his words, verbatim, in the order he said them)

### 1.1 The progression spine
> *"i think we should really shift the game from having the squad, that just the player is the solo
> person in this world and theres squads and world happenings all over them. which makes the radio man
> concept something that should be mission specific, but also if youre out in the world and come up to a
> radio man can also just use it to call stuff in and than eventually the player will get their own hand
> held radio they can call strikes. that might be a better introduction to that mechanic. make it first
> come from a mission where youre supplied a radio guy, maybe the 4th or 5th mission just to make sure
> the player understands the game by that time its happening. and than later on you can request to have a
> radio man come with you, which is like a rpg companion. and than eventually the player gets to have the
> up to 8 man squad follow them. that might be a better game play loop and makes the player feel powerful
> and a sense of growth. and also sets it apart from other war games."*

**The ladder, as he drew it:**
`solo in a living world → a mission that supplies an RTO (4th–5th) → borrowing any RTO you meet in the
world → requesting an RTO companion → your own handheld radio → up to an 8-man squad`

### 1.2 The command grammar (the top rung)
> *"and at that point you should be able to give commands in the most simple way. move here, which than
> creates a hold and defend command. regroup command or a attack command, with a aimed and trigger pulled
> attack command to be a more aggressive attack. very brothers in arms inspired"*

**The verb set, deliberately tiny:** `MOVE HERE` (which becomes HOLD AND DEFEND on arrival) · `REGROUP` ·
`ATTACK` — with an **aimed-and-trigger-pulled ATTACK** as the aggressive escalation.
*"The most simple way"* is read as a **constraint, not a preamble.*

### 1.3 The genre
> *"so its like a rpg, tactical squad war game is the best way to describe it but it sits apart from easy
> red 2 by not just being a sandbox but having this story, the comic story inside of it too"*

### 1.4 The franchise
> *"and we go to ww1 etc"*

### 1.5 The two confirmations
> *"yeah thats from the comic intergration work we did this morning"* — the three `CONQUEST_OF_WORMS_*`
> drafts in `production/` are the comic story and are canon input to this session.
> *"and post demo launch work"* — the whole line is post-demo.

---

## 2 · WHAT IS BEING DECIDED

1. Does the game's default state become **SOLO**, with the squad as an earned late-ladder capability?
2. Is the **radio a ladder** — mission-supplied → borrowed → companion → owned — and is it the tutorial?
3. Is **borrowing a stranger's RTO** a real mechanic, and what does it cost/require/risk?
4. What is the **command grammar** at the top of the ladder, and does it survive the period-HUD decree?
5. Does the ladder **generalise across wars** (Vietnam / Korea / WW1) or is it Vietnam content?
6. How does an **authored comic story** coexist with a world that runs without the player?

## 3 · WHAT IS NOT BEING DECIDED

- Nothing about the shipping demo. Nothing on the critical path to Early Access.
- No gameplay code is written this session.
- No edits to `CALEB_TODO_7_22_updated.md` or `GAME_GUIDE.md` (a second council is live in those files).

---

## 4 · BINDING CONSTRAINTS THE COUNCIL INHERITS

| Constraint | Source | Bite |
|---|---|---|
| **Pillar 1** — death from situation, never hit-point math | GAME_GUIDE §1 | A solo player must not die to a stat |
| **Pillar 3** — stealth is an economy, never a gate; no rails | GAME_GUIDE §1 + the 2026-09-09 quest clarification | A ladder that *requires* a rung is a rail |
| **Pillar 4** — the squad is the RPG | GAME_GUIDE §1 | If the squad arrives at hour 20, Pillar 4 is deferred by 20 hours |
| **Pillar 5** — fail forward | GAME_GUIDE §1 | Solo death must generate the next story, not a reload |
| **ADR-011** — the radio is a MAN; 10m leash; **no bypass paths** | `ADR-011:` "One leash function (`_radio_check()`) gates every entry point… **No bypass paths.**" | A handheld radio is a **direct assault on ADR-011's central law** |
| **ADR-018** — rank gates AUTHORITY, never ABILITY; **THE LADDER LAW: rank gates how BIG, never WHETHER** | ADR-018 §3 | You may not start the player with *no* fire support |
| **ADR-021** — **THE PROMOTION IS THE TUTORIAL**: new-in-country **YOU FOLLOW** an NPC sergeant; trusted, **YOU LEAD** | ADR-021 §4 | **Direct collision.** ADR-021's tutorial is *being led by a squad.* His proposal's tutorial is *being alone.* |
| **ADR-023** — the fossil law: a replacement is not shipped until its predecessor is deleted | ADR-023 | Whatever this decree replaces must be named for deletion, not left standing |
| **ADR-032 / progression decree** — no XP number ever reaches a screen; rank ladder PVT→PFC→SPC→SGT→SSG | `recongame-player-progression` | The ladder's rungs must be *felt*, announced as titles, never as a progress bar |
| **ADR-030 / period HUD** — DEFERRED to final polish, explicitly non-blocking; no new persistent HUD elements | `recongame-period-hud-decree` | A Brothers-in-Arms command cursor is a modern-UI import into a period-HUD game |
| **Patrol contract §4 clauses** — waypoints never check off; no in-field counters; command names FEATURES not objective pins | `recongame-patrol-contract-decree` R2 | An order marker is one clause away from being an objective pin |
| **Fear/lethality doctrine** — FEAR-style self-preservation both sides; enemy fire lethal and accurate; *"i dont really feel like im in danger"* is the acceptance test | `recon-fear-doctrine-lethality` | A solo player in this doctrine dies fast, and that is deliberate |
| **Franchise: "Tour of Hell", era-tagged, Vietnam / Korea / WWI** | `recongame-franchise-naming-decree` (2026-07-30) | **His "we go to ww1" is a CONFIRMATION of standing canon, not a new decision** |
| **Cutscenes are standalone Blender FMV**, not engine work | `recongame-cutscenes-standalone` | The comic has a delivery pipeline that does not block the game |
| **Scope law** — KILLED / PARKED / FROZEN lists are law | GAME_GUIDE §6 | This decree PARKS; it does not thaw |

---

## 5 · THE SIX PRESSURE POINTS (the Arbiter's charge to the council)

1. **Nothing may be thrown away.** Squad cohesion, formations, squad AI, the 8-man loop and the RTO
   systems are built. Verify against code whether this proposal *gates* them or *deletes* them, and say
   plainly if anything real would be lost.
2. **Solo in a lethal game.** Is a lone player dying repeatedly the point, or a loop that punishes before
   it teaches? Rule on it, and state what the first three missions must do.
3. **Borrowing a stranger's radio** — cost, requirement, risk. It must connect to the existing
   conversation systems, not be a new prompt.
4. **Ordering and pacing.** Mission 4–5 versus how long a fresh player actually takes. The fresh-player
   testing law applies; the demo audit found **no onboarding at all.**
5. **The command grammar** must survive the period HUD, must degrade down the ladder (one borrowed RTO →
   companion → eight men), and must not become the reason the player wants the squad early.
6. **The authored story versus the living sim.** An authored story wants the player at a place at a time.
   A living sim does not care where he is. Say precisely how they coexist.

## 6 · THE TWO CANON COLLISIONS THAT MUST BE RESOLVED, NOT STEPPED AROUND

- **Pillar 4's anti-puppeteer clause** — whether the player is a soldier or a cursor floating over his own
  men. A command scheme forces the ruling. Close it, or state exactly why it stays parked.
- **The period HUD versus the Brothers-in-Arms cursor.** His own scheme contains the way out: *the weapon
  IS the interface.*

## 7 · DEVIL'S ADVOCATE — THE TWO CHARGES HE MUST BRING

1. A solo player in an open sim is a **slow, lonely game that mistakes emptiness for atmosphere**, and the
   squad is what makes moment-to-moment play readable.
2. Command mechanics **turn a soldier into an officer** and quietly delete the loneliness the solo pivot
   was FOR. The game is best at the bottom of the ladder, and the top rung undoes the premise.

## 8 · DELIVERABLE

A decree with a phased plan; an ADR if ratified in principle; **the tradeoffs named (Law 2)**; a short
list of calls that are genuinely his. Plus, because this is post-demo:

- **THE DOORS TO KEEP OPEN** — choices being made right now (firebase pivot, event census, squad AI) that
  would be expensive to reverse when this pivot begins. *This is the highest-value output of the session.*
- **A PROPER PARK** — what was decided, what was deliberately NOT decided, and what evidence would change
  it. This project loses parked decisions; this one must survive months of silence.
