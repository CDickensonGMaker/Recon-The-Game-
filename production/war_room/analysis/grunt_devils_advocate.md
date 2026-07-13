# DEVIL'S ADVOCATE — "The score rewards INITIATIVE, not AVOIDANCE"
**Convened:** 2026-07-13 · **Summoner's pillar correction:** *"the core game fantasy is the US Army patrolling the woods"* · **Arbiter's proposal:** replace ADR-006's ±25 avoided/detected axis with the three-situation asymmetry (TURKEY SHOOT / STAND-UP WAR / AMBUSHED).

I read the code, not the plan. Everything below is verified against `debrief.gd`, `mission_state.gd`, `mission_director.gd`, `enemy_squad.gd`, and the ADRs. Nothing here is a free lunch and I am going to say so about the Arbiter's proposal too.

---

## 0 · THE THING NOBODY IN THIS COUNCIL HAS SAID YET

**Nobody has ever played the ADR-006 economy.** It shipped 2026-07-12. It is being repealed 2026-07-13. The playtest that would have told us whether it was good (`RECONgame-ida9`, PLAYTEST R3) is still **open**, and it is one of the six P1s holding the **P0 GATE bead `RECONgame-97u3`** red.

We are relitigating a live system on **theory**, one day old, having gathered **zero** evidence about it. That is exactly the loop ADR-015's gate law was written to break. Hold that thought for Q7 — it does not sink the proposal, but it decides *how much of it we are allowed to build today*.

---

## 1 · IS THE DAY'S STEALTH WORK WASTED?

### THE PROSECUTION (strongest case that the Summoner just burned a day)

The day built an **evasion engine**. Look at what it actually is:

- **THE HUNT** (`enemy_squad.gd`): a 169 m/min expanding net that chases you, re-anchors on fresh sign, and pushes 130 m along your trail. It only ever fires **when the player is running away.**
- **WATER BREAKS TRAIL** (`enemy_squad.gd:124-130`): the counterplay to the chase. Only meaningful to a man being chased.
- **BODIES AS LIABILITIES** (`unreported_corpses`): a tax on the man who cannot afford to be found.
- **GALLERY FOREST**: concealment for a man moving unseen.
- **KNOWLEDGE_TTL 12.0** — "the squad loses the scent." *The scent.* The vocabulary of the code is the vocabulary of a **fugitive**.

A US Army line patrol that finds and fights **does not run.** It fixes, it flanks, it calls the 60 forward, it calls fire support (ADR-011). If it must withdraw, that is a mission failure state, not the loop. So: **the day's work is the machinery of a game the Summoner just told us is the DLC** — *"the DLC later content is full Special Forces E&E."* We built the SF DLC's core loop on day one of the grunt game, and today it gets demoted from *core loop* to *what happens when you screw up*.

**That demotion is REAL and it is a cost. Name it, Arbiter, and do not pretend otherwise.** The hunt was the best system built this week and it just became a failure-state garnish.

### THE DEFENCE (and it is stronger)

The prosecution confuses **the payoff** with **the sensor**.

1. **The witness rule IS the initiative mechanic.** "An unwitnessed kill is silent" is not an escape clause — it is the *precondition of a TURKEY SHOOT*. You cannot ambush a man who already knows you are there. ADR-005 is the thing that makes "undetected initiator" a state the world can actually be in. **Delete the witness rule and the Arbiter's proposal has nothing to measure.**

2. **The classifier already exists, in shipped code.** `MissionState._detected_groups` (mission_state.gd:70) is a per-group, one-way ledger of *who knows about you*. That is **precisely** the state variable the three-situation axis needs:
   - player deals first damage to a group **not in** `_detected_groups` → **TURKEY SHOOT**
   - player takes first damage from a group **not in** `_detected_groups` → **AMBUSHED**
   - anything else (mutual awareness) → **STAND-UP WAR**

   The Arbiter's proposal does not delete the day's work. **It consumes it.** The stealth systems are the sensor array; only the *scoring formula* — twelve lines in `debrief.gd` — changes.

3. **The hunt survives, and is now better justified.** Under ADR-021 §2, a successful ambush **burns the route** and the VC come looking. A four-man element that just killed six men in a kill zone **breaks contact and gets out** — that is the hunt, at the moment of maximum tension, *earned* rather than triggered by cowardice. Under the old avoidance economy you were never close enough to trigger it in the first place.

**VERDICT ON Q1: ~85% preserved.** What died is the **primacy of the ghost run**, not its machinery. Bill the loss honestly: the hunt is demoted, and E&E depth built today will not be exercised as often as it was designed to be. That is a real cost and the correct one to pay.

---

## 2 · THE SHARPEST CONTRADICTION: "FIND AND FIGHT" vs "BODY COUNT IS A LOSING STRATEGY"

**IT RESOLVES — but only under two binding conditions, and if either is violated the game eats its own core fantasy.**

Read ADR-019 line 67 with a lawyer's eye: *"Body count is a strategy in this game. It is just a losing one, **if you take the shortcut to get it.**"*

The shortcut is **named in ADR-019's own table**, and every entry is an act of **conduct toward civilians**:

| Moves toward HOSTILE (ADR-019 §2) |
|---|
| Burning the village |
| Killing civilians (incl. careless artillery/airstrikes) |
| Destroying homes and livestock in a raid |
| Detaining/executing suspects |

**"Killed armed VC in a firefight in the treeline" APPEARS NOWHERE ON THAT LIST.** It is not on it because it does not belong on it.

And ADR-019 §1 makes the point positively: *"Men do not [rebuild]. Each district draws from a finite regional manpower pool, and every VC killed comes out of it."* The stated win condition is **"their strength is broken AND the districts do not hate you."** **Killing VC in the field is HALF THE WIN CONDITION.** Find-and-fight is not merely tolerated by ADR-019 — **it is mandatory.**

The two axes are **orthogonal, not opposed**:
- **ATTRITION** (kill armed men) — drains a finite pool. *You must do this to win.*
- **CONDUCT** (how you treat the ville) — sets the pool's **refill rate**. *You must not poison this or attrition is a treadmill.*

**The American war in one sentence: you can kill every VC in the province and still lose, because you made more of them than you killed.** That is not a contradiction with the grunt fantasy. **That IS the grunt fantasy**, and it is the best thing in this entire design document set.

### THE TWO BINDING CONDITIONS (violate either and the contradiction becomes REAL)

**BC-1 — ALLEGIANCE MAY NEVER READ THE KILL COUNTER.**
The instant somebody implements `allegiance -= kills * k` because it is one line and it "feels right," the game punishes the player for doing his job, and ADR-019 devours the core fantasy. Allegiance reads **conduct only**: civilian deaths, arson, structures destroyed, collateral from indirect fire, prisoner handling, fire discipline **near the ville**. A dead VC in the treeline moves allegiance by **exactly zero**. Write this into ADR-019 as law, in bold, today — because the shortcut implementation is *sitting right there* and someone will take it.

**BC-2 — THE POOL MATH MUST LET A CLEAN FIGHTER WIN.**
If `regen(COOPERATIVE district) >= player kill rate`, then fighting is pointless even when fought cleanly, and the player learns — correctly — that the gun is a lie. Clean attrition must **visibly** outrun clean regen. Hostile regen must outrun it. That gap **is** the hearts-and-minds system; if there is no gap there is no system, only a slope. This is a tuning constraint, and it is load-bearing.

### AND ONE CONDITION ON THE ARBITER'S OWN PROPOSAL

**BC-3 — TURKEY SHOOT PAYS PER ENGAGEMENT, FLAT. NEVER PER CORPSE.**
Kill 3 in an ambush or kill 9: **same score.** The reward is for **the situation you created**, not for the bodies you stacked. Scale it by kills and you have reinvented `kills × 10` with a stealth prefix, ADR-006's original wound reopens, and ADR-019 goes back to war with the score sheet. This is non-negotiable.

With BC-1, BC-2 and BC-3 in force, there are **three independent anti-farm brakes** on body count and the design is coherent:
1. **Flat per-engagement pay** — more bodies pay nothing extra.
2. **Intel burn** (ADR-021 §2) — a successful ambush costs you the route. *You cannot farm a kill zone.*
3. **Finite pool + conduct-driven regen** (ADR-019) — atrocity makes more of them than you can kill.

**ANSWER TO Q2: NOT A CONTRADICTION. It is the game's thesis, and it only reads as a contradiction if you conflate "body count" (the McNamara metric, gotten by shortcut) with "killing the enemy" (the patrol's job). ADR-019 already draws that line. It must now draw it IN CODE.**

---

## 3 · WHAT STOPS A CORRIDOR SHOOTER?

The strategic choice is **not "fight or don't fight."** It is **"on whose terms."** The axis moved from *whether* to *who has the initiative*, and initiative is bought with:

- **INTEL** — you know their route (ADR-021 patrol nodes), so you know where to be.
- **GROUND** — you choose the ambush site (ADR-022 map marks).
- **DISCIPLINE** — the witness rule; you get one clean opening and only if nobody saw you get there.
- **BLOOD** — a finite squad (Pillar 4). You cannot afford every fight you *could* win.

**BUT — AND THIS IS THE PROPOSAL'S BIGGEST HIDDEN BILL:**

> **The game must NEVER HAND the player a TURKEY SHOOT.**

If the mission generator drops an enemy squad in front of you and you happen to shoot first, you were **paid the initiative bonus for free** — and the optimal strategy becomes *walk forward, shoot first, repeat*. **That is a corridor shooter with a scoring gimmick.**

Today, `mission_director.gd:40` calls bare `EnemyBase.spawn_enemy(parent, seated, data_path)` — men placed at points with no route. **Bead 0623 gap #1 has been open since 2026-07-08 for exactly this reason.**

**Therefore: initiative-scoring creates a HARD DEPENDENCY on ADR-021 patrol nodes.** Enemy presence must be **schedule-driven** (they are going somewhere, on a route you could have learned), never **proximity-spawned**. Without ADR-021 shipped, the Arbiter's axis is literally the rule *"shoot first, win"* — and it is a **downgrade** on ADR-006, which at least made you think about whether to shoot at all.

**The Arbiter must state this dependency in the decree or the decree is a trap.**

---

## 4 · IS THE "AMBUSHED" PENALTY FAIR, OR IS IT VICTIM-BLAMING?

**Today, in this build: it is victim-blaming. Ship it as written and you violate the Fairness Law.**

The Fairness Law (GAME_GUIDE §1) binds the game to telegraph: *"first shot at an unaware player is a near-miss · muzzle flash / tracers / vocalizations always telegraph."* The **spirit** of that law is: **the player must be able to name the tell he missed.**

So — **THE DEVIL'S TEST**, and I want it in the ADR:

> **After every AMBUSHED debrief, the player must be able to name the thing he failed to read. If he cannot, the penalty is not fair and MUST NOT BE APPLIED.**

The tells ADR-021 §3 promises — *sign: a cold cookfire, fresh boot prints, a wired trail* — **do not exist yet.** ADR-019's warning channels (a silent ville, a hostile briefing) **do not exist yet.** Penalizing a man for failing to read tells the game does not render is not design; it is a **dice roll with a lecture attached.**

**Two further objections, both serious:**

**(a) THE PENALTY IS DOUBLE-DIPPED.** Being ambushed *already* costs you, brutally and diegetically: dead squadmates (permanent — Pillar 4), wounds (`−damage_taken`, already in `compute_score`), emergency exfil (`−50`, already there), and possibly the mission. **The world already punishes it.** Adding a *number* on top does not teach; it **scolds**. The blood is the lesson. The score line is the game wagging its finger at a man who just carried a friend to the LZ.

**(b) THE ASYMMETRY SURVIVES WITHOUT THE PENALTY.** If TURKEY SHOOT pays +50 and AMBUSHED pays 0, **initiative is still the only thing that pays.** The reward carries the entire design load. The penalty is optional to the mechanism — it is *flavor with teeth*, and it bites the player at his lowest moment.

**AMENDMENT (I will fight for this one):**
- **Ship AMBUSHED at 0 today** — displayed on the AAR as information ("AMBUSHED: 2 — you were made first"), scoring nothing. The Truth Law (ADR-015) is satisfied: we display what we apply.
- **Turn the penalty on ONLY when SIGN is findable in the world** (ADR-021 §3) and the briefing names a HOSTILE district (ADR-019 §4). Then it is a price, not a punishment.
- **When it does turn on, cap it below the TURKEY SHOOT reward.** A patrol that fought, lost the opening, and still took its objectives must not come home **net negative** for having gone out and done its job. *That* is the surest way to teach the player to hide — which is the exact behavior the Summoner just told us to stop rewarding.

---

## 5 · THE EMPTY PATROL — AND THE EXPLOIT SITTING IN SHIPPED CODE

**FIRST, THE INDICTMENT OF THE CURRENT SYSTEM — this is the Arbiter's strongest card and he did not play it:**

`mission_director.gd:49` calls `state.register_group(...)` **at spawn time.** `mission_state.gd:90` computes `contacts_avoided() = _known_groups.size() - _detected_groups.size()`.

> **Therefore, in the build shipped yesterday, the player is paid +25 for every enemy group that SPAWNED AND HE NEVER MET.** He does not have to see them. He does not have to slip past them. He does not have to *know they exist*. **He can lie in a bush at the LZ, walk to exfil, and collect the MAXIMUM possible contact score in the game.**

**ADR-006 does not reward stealth. It rewards ABSENCE.** The optimal ADR-006 player is a man who does not play. The Summoner's instinct — that this is not the game — is not a preference; **it is a bug report.** He is right on the merits and the code proves it.

**SECOND, THE HOLE THE ARBITER'S PROPOSAL OPENS:**

Delete the ±25 and a quiet patrol scores `objectives × 100` **and nothing else**. But **ADR-021 §3 explicitly named the +25 as the quiet patrol's *primary income*** ("Seeing them without being seen already pays +25 each — this decree makes that the *primary income* rather than an odd tax"). **The Arbiter's proposal silently guts ADR-021 §3 and does not replace it.** The quiet patrol goes from *paid* to *paid nothing*, and the Summoner's own qualifier — *"there SHOULD be an element rewarding sneakier playing"* — is left **unfulfilled by the very decree meant to honor his correction.**

**THE FIX — and it is the single most valuable thing in this analysis. The axis is not three terms. It is FOUR:**

| Term | Pays | Why |
|---|---|---|
| **TURKEY SHOOT** (you initiated, they were cold) | **+50** flat per engagement | initiative is the game |
| **STAND-UP WAR** (mutual) | **0** | you fought fair; the objectives already paid you |
| **AMBUSHED** (they initiated) | **0 today → −25 once sign ships** | see §4 |
| **★ OBSERVED-UNSEEN** (you got eyes on a group / found sign, and they never got eyes on you) | **+25** | **THIS is the sneaky reward** |

**OBSERVED-UNSEEN replaces "avoided," and the difference is everything:**
- It is a **positive act** — you went and *found them* and lived to report it. You cannot earn it in a bush at the LZ.
- It **kills the absence exploit dead** — passive avoidance now pays **zero**.
- It pays the empty patrol in the currency ADR-021 §3 already promised (**the map**), and it is the **direct input to next week's TURKEY SHOOT**. *"The ghost run and the gun run are the same run, a week apart"* (ADR-021 §3) — this term is the mechanical bridge that makes that sentence true instead of poetic.
- It is **the Summoner's correction, exactly**: sneaking is **rewarded**, but it is no longer the game. It is **reconnaissance in service of the fight** — which is what a US Army patrol actually was.

**Without OBSERVED-UNSEEN, the empty patrol pays nothing, "walk in circles" is replaced by "walk in circles and shoot the first thing you see," and we have traded one degenerate strategy for another.**

Implementation note (cheap): `_known_groups` currently means "spawned." It must be re-scoped to mean **"the player has actually perceived this group"** — set on player LOS/spot/binocs/mark, or on finding its sign — not on spawn. That is a **one-line move of `register_group` out of `mission_director.gd:49`** and into the player's perception path. **That single line is the entire exploit fix.**

---

## 6 · SCOPE — DOES THE SLICE MOVE?

**No. And that is the strongest practical argument for adopting.**

- **GAME_GUIDE §6.0 SLICE unchanged.** One province, one firebase, three mission types (PATROL / VILLAGE RAID / BASE ASSAULT), allegiance, rank. **Nothing added.** No new art, no new levels, no new mission types.
- **What must be built (minimum viable decree):**
  1. Engagement classifier in `mission_state.gd` — reads the *existing* `_detected_groups`. ~40 lines + two hooks (player deals first damage to group X; player takes first damage from group X).
  2. `compute_score()` rewrite in `debrief.gd` (12 lines) + AAR lines naming the three situations (**r4bk Law — if the AAR does not show it, the system does not exist**).
  3. Move `register_group` from spawn → perception (the exploit fix, §5).
  4. `tests/test_xp_spend.gd:17` calls `compute_score()` and **will go red**. Update it.
  5. Headless probe (`tools/probe_config.gd` already exercises the ledger — extend it). **ADR-015 Verification Law: no closure without a probe.**
- **What must be AMENDED (documents, not code):** ADR-006 (rewritten), ADR-019 §5 + BC-1 written into §2, ADR-021 §3 (the +25 income line is now OBSERVED-UNSEEN), GAME_GUIDE §1 Pillar 3 wording ("stealth is an economy" → **"initiative is the economy; stealth buys it"**), GAME_GUIDE §4.2.
- **What must be DEFERRED:** SIGN as a findable world object, the AMBUSHED penalty, ADR-021 patrol nodes. These are the *conditions* of the full system, and they are **already beaded** (0623). They are not new scope. They are **the bill that was always coming.**

**The honest scope warning:** §3 proved that **initiative-scoring without ADR-021 patrol nodes is a corridor shooter.** So the decree ships a scoring axis whose full correctness **depends on an epic that is not built.** That is acceptable **only** if the decree says so out loud and beads the dependency. If it does not, we will ship "shoot first, win," playtest it, and conclude the design is bad when in fact it was merely half-built.

---

## 7 · OPPORTUNITY COST — 37 P1s AND A RED GATE

`bd show RECONgame-97u3`: **P0, OPEN**, blocked by six P1s — `a2qb` (player not seated in the Huey), `e6qc`, **`ida9` (PLAYTEST R3 — the session gate)**, `n2ij`, `r4bk` (squad command controls **gone**), `zet2`. It blocks nine feature epics.

**Does the gate forbid this?** No. ADR-015's exemptions are explicit: *"bug fixes, presentation for shipped systems, **decree items**."* A **Summoner pillar correction** is a decree item, and §5 proved the exploit fix is a **bug fix**. **The gate is satisfied. The work is legal.**

**But here is the bill, and it is the one I most want on the record:**

> **The squad command controls are GONE (`r4bk`). The player is not in the helicopter (`a2qb`). The jungle is too tame (`n2ij`). And this council is spending its day on the third rewrite of the score screen in four days.**

**The scoring economy is now the most-designed and least-played system in the project.** ADR-006 was written on 07-10, shipped 07-12, and is being repealed on 07-13 — **without one minute of play.** The council has become very good at reasoning about the debrief screen because the debrief screen is a `.gd` file it can read, and very slow at fixing the Huey because the Huey requires *playing the game*.

**That is the actual opportunity cost, and it is not measured in hours. It is measured in the habit.**

**The mitigation is discipline, not refusal:**
- The minimum decree (§6) is **~2 hours of code** and mostly **document amendments**. It is cheap. Do it.
- **Do NOT build SIGN, the spotting/marking UI, patrol nodes, or the AMBUSHED penalty today.** Those are the epics behind the gate. Bead them under LIVING WAR and **let the gate hold them**, as it was designed to.
- **Then go close `ida9`.** Play the thing. **The next scoring ADR must cite a playtest or it does not get written.** If the council amends this axis a third time on pure theory, the process itself has failed and I will say so at the top of my next analysis.

---

## 8 · VERDICT — **AMEND**

**Not adopt, not reject. AMEND — and the amendments are not cosmetic; two of them are load-bearing.**

**The Summoner is RIGHT, and the code proves it** (§5: ADR-006 pays for *absence*, not stealth — the optimal ADR-006 player is a man who does not play). **The Arbiter's axis is RIGHT** (initiative is the correct scoring variable, and the day's stealth work is its *sensor*, not its casualty). **But the proposal as stated has a hole and a trap:**

| # | Amendment | Severity |
|---|---|---|
| **A1** | **Add the fourth term: OBSERVED-UNSEEN +25.** Without it, the quiet patrol pays nothing, ADR-021 §3's stated income is silently deleted, and the Summoner's *"element rewarding sneakier playing"* goes unbuilt by the decree meant to honor it. | **LOAD-BEARING** |
| **A2** | **Move `register_group` from spawn → player perception** (`mission_director.gd:49`). Kills the absence exploit. One line. | **BUG FIX — do it regardless** |
| **A3** | **AMBUSHED = 0 today.** Turn on the penalty only when SIGN is findable and the briefing names a hostile district. Cap it below the TURKEY SHOOT reward, always. *Do not scold a man for a tell the game never drew.* | **FAIRNESS LAW** |
| **A4** | **BC-1: allegiance NEVER reads the kill counter.** Conduct only. Write it into ADR-019 §2 in bold, today, before someone implements the one-line version. | **LOAD-BEARING** |
| **A5** | **BC-3: TURKEY SHOOT pays FLAT PER ENGAGEMENT.** Never per corpse — or `kills × 10` walks back in wearing a ghillie suit. | **LOAD-BEARING** |
| **A6** | **State the ADR-021 dependency out loud.** Initiative-scoring without schedule-driven patrols is *"shoot first, win"* — a corridor shooter. Bead it, and say so in the decree. | **HONESTY** |
| **A7** | **Ship the minimum; build nothing behind the gate. Then close `ida9` and PLAY IT.** The next scoring ADR cites a playtest or it does not get written. | **PROCESS** |

**WHAT IS SACRIFICED (no free lunches — the law binds me too):**
- **THE HUNT IS DEMOTED.** The best system built this week goes from *core loop* to *failure-state garnish*. The SF DLC's spine got built on day one of the grunt game. Real cost. Correct cost. **Say it in the decree.**
- **The pure ghost run stops being optimal.** Players who wanted *Vietcong*'s tiptoe game get a patrol game with a stealth *phase*. Some will be disappointed. The Summoner has ruled; that is his call to make, and he made it.
- **The AAR gets busier** — four scoring terms plus objectives, wounds, time, exfil, ROE, POW. The debrief is drifting toward a spreadsheet. Watch it.
- **"Who initiated" is a fresh bug surface** at the edges: an enemy who walks into your held field of fire; a grenade thrown at a group that heard you but never saw you; a group that goes COMBAT from *another* group's radio. **The probe must cover these three cases or the classifier will lie**, and a lying score sheet is worse than a wrong one.
- **And the deepest one:** we are getting better at designing this game than at building it. **Three scoring decrees, zero playtests.** Fix the Huey.

*The Devil rests.*
