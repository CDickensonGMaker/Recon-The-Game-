# GAME DESIGNER — THE GRUNT CORRECTION

**Query:** The Summoner says the core fantasy is the US Army patrol that goes out to FIND AND FIGHT.
ADR-006 (shipped) pays +25 to avoid contact and −25 to have it. Resolve.

**Verdict: THE ARBITER IS RIGHT, AND THE PROPOSAL IS INCOMPLETE IN FOUR PLACES.** Fix them and it holds.

---

## 1 · WHERE THE PROPOSAL IS RIGHT

The diagnosis is exactly correct and I will not soften it: **ADR-006 is a SOG rule wearing a grunt's
uniform.** Read its own comment (`debrief.gd:21-26`) — *"a game whose whole fantasy is a recon element
that is never seen."* That sentence is now false. It was written for the wrong game. The scoring
economy in the shipped build tells a line grunt that the ideal patrol is the one where he never fires,
never finds them, and comes home. That is not *Platoon*. That is not even RECON — the tabletop's crown
rule, which we ratified and never built, is that **you set the ambush.** Setting an ambush requires
CONTACT. ADR-006 pays you to not have it.

And the proposal's core move is the strongest available: **the three-situation asymmetry is already
canon, already named "the design's lethality engine" (GAME_GUIDE:119), already in the vision
(VISION_READOUT:69-71), and has never existed in code.** We do not need a new axis. We need to build
the one we already ratified.

## 2 · WHERE IT IS WRONG — FOUR ATTACKS

### ATTACK 1 — "Reward initiative" is body-count farming with a better haircut.
If springing an ambush pays, and a group is 4–6 men, the optimal play is to ambush every group on the
map. That is a body count. **ADR-019 §3 says body count must be a LOSING strategy, and that law is
load-bearing for the entire moral spine of the game.**

**The answer, and it is the single best argument FOR the proposal:** pay for the *initiative*, never
for the *bodies*. Ambush a 6-man group and drop one man while five break and run — **same score as
killing all six.** The verdict is per-GROUP and binary. Body count is invariant. Kills still pay
literally zero, ADR-019 survives untouched, and ADR-006's one genuinely great idea is preserved.

And the economy **self-throttles for free, in already-shipped code.** A turkey shoot requires a COLD
group. Every fight you take raises the AO alarm (`EnemyBase.last_combat_contact_ms`, squad alert
sharing, `EnemySquad.report_contact`). After your second ambush there are no cold groups left to
ambush — they are ALERT, and by definition an ALERT group cannot be turkey-shot. **Initiative is a
consumable, and you spend it by using it.** You cannot farm it. Nobody has to police that; the
detection sim already does.

### ATTACK 2 — The game cannot see the player's eyes. "You saw them first" is unknowable.
There is no player-perception model in this codebase. None. `contact_conf` is the *enemy's* debounced
eyes-on. There is no reciprocal. **Do not build one** — it is a rabbit hole, and it would be a lie
anyway (the player's real perception is his own eyeballs on his own monitor). See §4.

### ATTACK 3 — THE BUMP. A cold sentry at 8m you reflex-shoot is not an ambush.
Under a naive "was the group cold when you opened?" rule, walking face-first into a patrol and winning
the twitch pays the same as a prepared L-shape. That is a lie about what the player did, and players
will feel it. **An ambush is PREPARED.** Gate it: the group must be cold AND (engagement range ≥ 25m
OR the player was stationary ≥ 3s before the first round). Under that, the bump grades as a MEETING
ENGAGEMENT — neutral — which is exactly what it is. The startle code at `enemy_base.gd:888-892`
already treats <15m cold contact as mutual surprise. The sim already agrees with me.

### ATTACK 4 — Triple jeopardy on the ambushed player.
Getting ambushed already costs damage (subtracted), possibly a dead man (permanent, Pillar 4), possibly
emergency exfil (−50). Adding a fat penalty on top is punishing a bad night four times. **Keep the
penalty** — it is the one thing he can prevent by walking better, and Pillar 5 demands failure have
teeth — but note the existing safety valve: `game_flow.gd:219` banks `maxi(0, score)`. A catastrophic
patrol earns **nothing**. It never earns *negative*. That is fail-forward, and it already ships.

### THE FIFTH THING NOBODY ASKED: the +75 "ghost bonus" is the worst offender in the file.
`_ghost_bonus()` pays **+75** — a bigger lump than any contact line — for firing ≤15 rounds per
objective. **It is a cash prize for pacifism**, and it survives the Arbiter's proposal untouched
because nobody looked at it. Kill it. Replace it with **FIRE DISCIPLINE: +75 for hits/shots ≥ 0.35 and
zero civilian casualties.** A grunt who makes his rounds count, whether he fired 8 or 180. Same name on
the AAR ("ROE"), opposite lesson.

---

## 3 · THE REPLACEMENT ECONOMY (concrete)

Every enemy group carries **exactly one verdict** at debrief. ADR-006's ±25 is superseded.
"Kills pay zero" is **retained as law.**

| Verdict | What it rewards | Score |
|---|---|---|
| **AMBUSH SPRUNG** (turkey shoot) | You found them, they never found you, and you executed. **THE GAME.** | **+50** |
| **MEETING ENGAGEMENT** (stand-up war) | An honest fight neither side chose. Not a failure — this is war. | **0** |
| **AMBUSHED** | They had the drop. You were the target. | **−50** |
| **COMPROMISED, NO FIGHT** | They made you and you walked away. You lost initiative and bought nothing. | **−10** |
| **SLIPPED PAST** | Never made contact. The ground is yours; they don't know you were there. | **+10** |
| **SIGN FOUND** (per piece) | Cold cookfire, cache, boot prints, wired trail — **reveals a VC patrol node** (ADR-021 §3). | **+15** |

**Unchanged:** objectives ×100 · −damage_taken · +50 speed · −50 emergency exfil · −100 POW.
**Deleted:** `CONTACT_AVOIDED = 25` / `CONTACT_DETECTED = -25` · the weapons-tight ghost bonus.

**Gates on AMBUSH SPRUNG (all three, or it downgrades to MEETING ENGAGEMENT):**
1. Group's max `alert_tier ≤ SUSPICIOUS` when the first friendly round lands on it.
2. Range ≥ 25m **or** player stationary ≥ 3s (the anti-bump gate, ATTACK 3).
3. **The opening burst produces ≥1 casualty within 5s.** A miss is not an ambush, it is a warning
   shot. This also kills the 300m-potshot-and-run farm. One casualty *gates* it; further casualties add
   **nothing** — the pay is for execution, not for bodies (ATTACK 1).

**Why these numbers.** Objectives are 200–400 a mission. A 6-group AO fully slipped pays +60 — real,
modest, never optimal. Three sprung ambushes pay +150 — **the largest single lever on the card**, which
is correct, because *initiative is the game*. Three times ambushed pays −150 plus blood, which is what a
patrol walking into three L-shapes deserves. **+10 SLIPPED vs +50 SPRUNG is the whole thesis in two
numbers: stealth still pays — it just stops being the win, because for a line grunt it isn't one.**

## 4 · THE HONEST SIGNAL — "WHO INITIATED?" (the crux)

**The honest signal is NOT "who saw whom." The engine cannot know what the player saw and must never
pretend to. The signal is: WHAT WAS THEIR ALERT TIER AT THE MOMENT THE FIRST ROUND LANDED.**

Per group, whichever fires first wins the verdict. Both hooks are **already shipped**:

| First event | Condition | Verdict |
|---|---|---|
| `take_damage(attacker)` on any member, attacker on team 1 | group max `alert_tier ≤ SUSPICIOUS` | **you initiated** → AMBUSH SPRUNG (subject to the 3 gates) |
| `take_damage(attacker)` on any member, attacker on team 1 | group max `alert_tier ≥ ALERT` | **mutual** → MEETING ENGAGEMENT |
| `_stamp_contact()` (witnessed COMBAT, `enemy_base.gd:861-869`) then that man fires | before any friendly round lands on the group | **they initiated** → AMBUSHED |
| `_stamp_contact()` fires, no rounds ever exchanged | contact breaks | **COMPROMISED, NO FIGHT** |
| Nothing ever fires | — | **SLIPPED PAST** |

**The wire already exists.** `mission_director.report_contact(group_id)` (`mission_director.gd:54`) and
`register_group()` (`:49`) are live; `MissionState._detected_groups` (`mission_state.gd:70`) is already a
per-group dictionary. This is not a new system — it is **one enum on an existing dict**, plus a
`report_engaged(group_id, initiator)` sibling call from `take_damage`. No new rays, no new perception
model, no player-eye simulation. That cheapness is the proposal's best property and it should be said
out loud in the ADR.

**Rejected signals, and why:**
- **`contact_conf`** — per-*enemy*, debounced, flickers, used for goal selection. It is not a contract
  and would produce nondeterministic verdicts on the same seed.
- **`EnemyBase.last_combat_contact_ms` (the beacon)** — *global*, not per-group. Correct for the AO
  alarm; useless for a per-group verdict. Do not overload it.
- **`alert_tier` sampled at debrief** — too late. Everyone is COMBAT by then. **The tier must be sampled
  AT THE INSTANT OF THE FIRST ROUND and frozen.** That is the entire trick.

**REQUIREMENT THIS CREATES (non-optional):** if the player cannot know he has the drop *before* he
pulls the trigger, TURKEY SHOOT is a lottery and the economy is unplayable. VISION_READOUT:161 already
promises "one subtle *being noticed* pip." **That pip is now load-bearing.** It is the initiative HUD.
Ship it with the economy or the economy is a dice roll.

## 5 · THE QUIET PATROL (Q3) — a B, never an F, never an A

A patrol with zero contact scores: **objectives (×100) + SIGN (+15 ea) + SLIPPED (+10 per group that
existed) + speed (+50).** A genuinely empty AO still pays objectives and sign. **Sometimes the woods are
empty, and the walk was still worth taking — because you came back with the map.** This is ADR-021 §3
executed literally: *"the quiet patrol pays in GROUND."* Sign must be a **scored line**, not flavor —
that is the only thing standing between "sometimes there isn't contact" and a wasted evening, and
ADR-021 already names it as the standing risk. It is never optimal (a fought patrol pays more) and never
a failure. Correct.

## 6 · THE E&E WORK IS NOT WASTED — IT IS PROMOTED (Q5)

THE HUNT (`enemy_squad.gd`, 169m/min, water breaks trail) is **what losing initiative FEELS like.** It
was built as the stealth-fail branch; under the new frame it is the **AMBUSHED branch's consequence**,
and that is a promotion, not a demotion. For the grunt: *you got made, now the woods hunt you — break
contact or die.* **That is Pillar 5 in one sentence, and it is already in the build.** Nothing is
deleted. It is recontextualized:

> **For the Army grunt, being hunted is a FAILURE STATE THAT IS STILL PLAYABLE.
> For SF/SOG in the DLC, being hunted is TUESDAY — it is the entire game.**

The DLC fork is not "new systems." It is **the same systems with the scoring table inverted** — SLIPPED
pays big, AMBUSHED is death, and there are no objectives worth a firefight. **ADR-006 is not deleted.
ADR-006 is the SF DLC's scoring ADR, and it always was.** Retitle it, don't burn it.

## 7 · PILLAR 3 SURVIVES — AND IS REPAIRED (Q6)

"Stealth is an economy, never a gate." Under shipped ADR-006, stealth was quietly *becoming* a gate —
**by economics.** The only paying strategy was to not be seen; the XP engine (`game_flow.gd:219` banks
score 1:1 into `team_xp`) gated your squad's *progression* on not fighting. A gate you can walk through
but that costs you everything is still a gate.

Under the new economy stealth is finally, genuinely an **economy**: **it is the currency you SPEND to
BUY the drop.** You are not paid for being unseen; you are paid for what being unseen lets you do.
That is the purest possible reading of the pillar, and it is the first time the code would actually
mean it.

**GAME_GUIDE amendments required:**
- §4.1 / the campaign scoring paragraph ("**Scoring pays avoidance** — +25/−25, kills pay zero") →
  "**Scoring pays INITIATIVE.** Kills pay zero." Same for **VISION_READOUT:140-142**.
- **§6 THE SLICE** must name the three-situation asymmetry as a slice deliverable. It is the lethality
  engine; the slice cannot demonstrate the fantasy without it.
- Pillar 3's text (GAME_GUIDE §1) **does not change.** It was always right. The code was wrong.

## 8 · WHAT THE PLAYER SEES (Q7 — r4bk)

```
  CONTACT REPORT
    AMBUSH SPRUNG        x2    +100     you opened. they never saw you.
    MEETING ENGAGEMENT   x1      +0     you traded first rounds.
    AMBUSHED             x1     -50     THEY SAW YOU FIRST.
    COMPROMISED          x1     -10     they made you. you walked.
    SLIPPED PAST         x3     +30     they never knew you were there.
    SIGN FOUND           x2     +30     VC ROUTE REVEALED - AN LAO VALLEY
    ENEMY KIA           x11       0     bodies are not income.
    ROE - FIRE DISCIPLINE       +75     41% rounds on target. no civilians.
```

Every line is a **verb the player performed** and a number he can move. The **AMBUSHED** line states
*why* — "THEY SAW YOU FIRST" — because that is the teaching moment and it costs one string. Kills stay
on the card at **0**, which is the loudest possible statement of what this game is about.

**And the live affordance (the real r4bk debt):** the "being noticed" pip. Without it the player is
guessing whether he has the drop, and a guessed turkey shoot is a coin flip, not a decision.

---

## 9 · WHAT IS SACRIFICED (no free lunches)

- **The pure ghost run stops being the high score.** Players who loved ADR-006's stealth-max fantasy
  lose their optimum. It remains fully *viable* (SLIPPED is positive; nothing gates on the gun) but it
  is now a B-grade patrol. **That is the Summoner's decree, and it is a real loss.** It goes to the SF
  DLC where it belongs.
- **Three new verdict gates = a fresh bug surface** at exactly the moment of first contact, the most
  chaotic 200ms in the game. The range/stationary/casualty gates will produce wrong verdicts in edge
  cases (mortars, allied-initiated contact on a FIRE order, a group split across 200m of jungle).
  Headless probes for all five verdicts, per the Verification Law, or this ships as a liar.
- **The initiative economy is only as honest as the group's alert tier at t=0.** If the AO alarm wakes
  a group *before* the player could reasonably know, he loses a turkey shoot he earned and will
  correctly call it unfair. The pip mitigates. It does not eliminate.
- **ADR-006 must be formally superseded, not quietly edited.** It shipped 2026-07-12 and three ADRs
  (019, 021, and the guide) cite its numbers. All of them need the amendment or the canon starts lying
  again — and CLAUDE.md's own warning stands: **a stale doc is not a wrong note, it is a drift
  generator.**
