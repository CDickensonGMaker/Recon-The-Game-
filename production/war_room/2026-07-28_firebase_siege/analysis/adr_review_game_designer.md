# GAME DESIGNER — review of DRAFT ADR-035 (The Siege)

**Date:** 2026-07-28 · **Architect:** game-designer · **Subject:** `production/adr/ADR-035-the-siege.md` (DRAFT)
**Scope:** does the ADR SERVE the Summoner's rulings, and does it violate a pillar. The rulings themselves
(any night · ≤3 nights · d50 · 2d6 sappers · cells of 3–6 same type · one axis · installation objectives ·
break at 40–50% · no respawn if overrun · higher lethality) are **LAW and are not re-litigated here.**

**Verdict up front: RATIFY WITH AMENDMENTS.** The engineering read is the best this council has produced —
the REAP finding, the marching-cell body/brain correction, and the stand-down catch are all real and all
load-bearing. The design side has one pillar violation, one pillar deferral dressed as a protection, one
missing number that governs the whole feature, and one wrong conclusion drawn from a correct observation.

---

## 1. PILLAR 5 (FAIL FORWARD) vs §9 — **VIOLATION, as written. Amendable.**

**Pillar text** (`production/bible/BIBLE.md:95`): *"detection escalates, **failure mutates**, a dead mission
generates the next story. Death matters and soldiers do not respawn as the same person, but this is not a
sadism simulator: the medic tries, and the squad endures. **Never reload-and-memorize.**"*

§9's defense is that losing the TOC "removes a safety net rather than showing a screen." **The screen half of
that argument is true and irrelevant, and the ADR is leaning on the half that does not matter.**

Three findings.

**(a) The screen claim is factually shaky.** §9 says *"Pillar 5 forbids one [a fail-state screen]."* The
codebase ships one: `hud.gd:357` `death_screen.visible = true`, reachable whenever `managed_by_flow` is
false. Under the flow it routes to the debrief (`field_director.gd:141-142` → `fail_mission("KIA")`). So
"we didn't add a screen" is not a pillar argument, it is a note about which of two shipped paths fires.
Pointer law: the sentence asserts a code state and cites nothing.

**(b) The real violation is the clause §9 never quotes — "never reload-and-memorize."** F5/F9 exist. §9
proposes an **unrecoverable** consequence that arrives inside a single 600-second night, decided by a d50
the player never sees, against a garrison whose strength was set by the previous two nights. That is the
exact stimulus that manufactures save-scumming: a large, opaque, permanent loss on a reloadable timescale.
Pillar 5 does not name reload-and-memorize as a style preference; it names it as the failure mode the whole
pillar exists to prevent. **§9 as written builds the stimulus and then calls itself fail-forward.**

**(c) The decisive one: §9 never describes the successor state, and "failure mutates" is unsatisfied by
silence.** Fail-forward is not "the loss is diegetic." It is *the game continues, changed.* §9 says the
anchor is "gone" and stops. Measured against what the anchor actually carries:

| Anchor function | Where it lives | State after the TOC falls, per §9 |
|---|---|---|
| Patrol banks / reputation faucet | `_bank_patrol` at the wire, `field_director.gd:941-943`, `:1202` | unspecified |
| Fire-support allotment | granted crossing the wire OUTBOUND, `:946` | unspecified |
| The armory rack (ADR-032) | `armorers_bench.gd:46-53` | unspecified |
| Rearm, sleep, the day cycle | the compound itself | unspecified |

If those simply stop, the post-overrun game is not mutated — **it is disabled**, and the player reloads
because the alternative is a walking simulator. That is a fail-state that declined to draw itself.

**RULING: §9 is a fail-state wearing a diegetic hat, and it can stop being one cheaply.** The amendment is
one paragraph, and it is a design obligation, not a build: **§9 must name the morning after.** The base is
not deleted; it is *taken*. The surviving garrison and the player displace. The recovery anchor re-hosts —
a relief position, a neighbouring firebase, an ARVN outpost — and the punishment is **degradation that is
felt in the loop**: the fire-support tier drops to what a man on foot can call, the bench is gone until the
position is re-established, and the province heats. The player keeps his rank (ADR-018/032 — rank gates
authority and is *earned*, never confiscated by a bad night). That is failure mutating. It reuses ADR-020's
THE DOOR vocabulary and needs no new economy.

**The respawn gap §9 states honestly is fine and should stay stated.** But note what it means today: the
condition attaches to a system that does not exist, on top of a state (`fail_mission("KIA")`) that already
ends the run. **§9 currently changes nothing mechanically and promises everything narratively.** That is
the shape of a line that survives three years unbuilt while everyone believes it shipped. Mark it
UNFINISHED explicitly (fossil-law triage), not as a decision.

---

## 2. PILLAR 4 ("the squad is the RPG — and you are IN it, not above it") vs §5 — **respected, but
under-argued and under-built.**

**The credit ruling is CORRECT and I endorse it.** Counting every attacker death, not player-attributed
kills, is Pillar 4 in its purest form: the unit's fight is the unit's fight. It is also the only reading
that survives contact with `combat_manager.gd:149-150` (attribution would make the player's own steel 2.5×
more lethal to his own men). No argument from me.

**But the ADR uses Pillar 4 as a shield for a technical convenience, and that leaves a hole it then
shrugs at.** Consequence 2 concedes *"a passive player can still 'win' a siege the garrison fought,"*
answers *"the punishment is a degraded firebase,"* and then **never connects any player action to how
degraded that firebase gets.** Nothing in §§1–10 makes the garrison's casualty count a function of what
the player did. The punishment is asserted, not priced.

**Does he command them?** Measured:
- **The garrison: no, and correctly so.** `GarrisonDefender.promote` sets `squad_member = false` and
  `set_order(OrderMode.HOLD, post)` with `post_leash = 8.0` (`garrison_defender.gd`). `SquadSystem` only
  orders `squad_member` allies (`squad_system.gd:180`). The garrison is 24 men on posts and the player is
  not their commander. That is right — a design that has him positioning individual men is the thing
  Pillar 4 forbids by name.
- **His own squad: YES, and the ADR does not mention it.** `squad_follow` / `squad_hold` / `squad_move` /
  `squad_fire_toggle` are live bindings (`project.godot:215-233`) through `squad_system.gd:180`. Level-1
  orders ship today (ADR-029-C §5 defers only the *forgiving* Level-2 layer).

**So the ADR is wrong that illum and fire missions are the player's only siege verbs — and it is
undersell­ing the one verb that makes a siege a game rather than a shooting range.** The siege's actual
Pillar-4 decision is: *I have five men and one axis is coming. Which hole do I plug with them, and do I
stand with them or take the MG?* One 60° sector (§3) against a perimeter he cannot cover is a real
positioning problem with a real cost, made of parts that already exist. **§3 and §5 should name it.**

**AMENDMENT (Pillar 4, and it closes Consequence 2):** the siege banks a **SIEGE AAR at dawn**, on the
existing debrief terms — garrison dead, installations lost, contacts. `_bank_patrol` already refuses to
fire at home (`:941-943`) while `spawn_tracked_enemy` debits the ADR-006 ledger regardless (`:42-44`), so
**a player defending his own base is currently scored DOWN for it.** The ADR lists this under "live
defects" but does not RULE what defending is worth. Rule it: **defending banks.** Then a passive player
still "wins" the night and reads eleven dead men and a lost depot on the board in the morning. The
sacrifice stops being accepted-and-unpriced and becomes accepted-and-charged.

---

## 3. PILLAR 2 (ATMOSPHERE) vs §8 — **§8 is necessary and NOT sufficient. It is a deferral, not a
protection.**

§8 is the best catch in the document and it should ship exactly as ruled. But its own claim —
*"Without it, Pillar 2 is paid out permanently on the first night"* — is only half repaired. **With it,
Pillar 2 is paid out permanently on the third night instead.** Measured:

- `FSB_GARRISON_MAX_MEN = 24` (`site_planner.gd`) — the whole population inside the wire.
- `FSB_WORK_POST_CAP = 12` — the *visible life* of the base: 12 men sampled by deterministic stride from
  the 191 `work_*` markers, running `CivilianSchedulesS.action_for(occupation, hour)`
  (`civilian.gd:482`). The other 12 are curated posts.
- §8: **"dead men stay dead and are not replaced."** The ADR names **no faucet, anywhere, ever.**

Three nights of d50 into 24 men with no refill is a one-way ratchet to an empty compound. And because the
work-post men are only 12 of the 24, **a single bad night can erase every work post in the firebase** —
after which the base has no schedule to run, no chow line, no guard change, no man cleaning his rifle.
ADR-020 §4's living firebase is not damaged, it is *finished*, and unlike a lost bunker it never comes back.
That is a permanent Pillar 2 cost paid by a temporary event.

**AMENDMENT: name the faucet, and make it diegetic and slow.** Replacements arrive on the resupply slick
that ADR-020 §4 already lists in the mundane rotation, at a trickle (a man or two a week), and they are
**green** under ADR-018 — so the base repopulates *worse*, which is the correct emotional result and costs
nothing to author. Attrition becomes a pressure the player can feel and lose ground on, instead of a
countdown to a ghost town.

**Second gap, unstated: §8 has no identity round-trip contract.** `promote` DESTROYS the Civilian and
rebuilds the man from `_seeded_rng(stand)` (`garrison_defender.gd`). Reverting at dawn constructs a *new*
Civilian. Unless `occupation`, `working_point_pos`, `is_garrison`, the unit model and the quarters
round-robin (`FSB_GARRISON_QUARTERS`) all survive the round trip, three stand-to/stand-down cycles will
launder the base's population into interchangeable men at scrambled posts — Pillar 2 dying by drift rather
than by casualty. **§8 must state the preserved-fields contract and it must be probed.**

**Third, smaller:** the siege hard-breaks at 480 s of a 600 s night but stand-down is "at dawn." For the
remaining night the base is soldiers frozen on 8 m leashes. Name whether stand-down is dawn or
siege-end + a cooldown; "at dawn" is a choice, not a default, and the aftermath hour is the most
atmospheric hour the feature owns.

---

## 4. THE THREE NIGHTS — **attrition is the only differentiator, and it runs the wrong way.**

§8 is correct that dead-men-stay-dead is *a* dramatic engine. It is not enough, and as specified it is
structurally backwards:

> **The defender loses men permanently across the run. The attacker rerolls a fresh, independent d50
> every night.**

Night 3 can therefore be **50 attackers against a garrison of eleven**, and nothing the player did on
nights 1 and 2 changed the size of the thing coming for him. Mechanically nights 2 and 3 are the same
fight with a thinner friendly list. The player's read is not "I bled them and they came back weaker" — it
is "the game is grinding me down on a schedule." That is the sadism clause of Pillar 5, and it is the
opposite of fail-forward: **his performance authors nothing.**

**AMENDMENT — and it touches none of the Summoner's rulings.** The d50 is rolled **per siege run, not per
night.** Nights 2 and 3 attack with **what survived and was reaped** (§5 already builds the survivor set —
this is free), topped by a trickle from ADR-019's finite regional manpower pool.

What that buys, all of it for one changed noun:
- Break them hard on night 1 → **night 2 may not come at all.** The run ends when the force is spent.
  ADR-020's scarcity is restored *by play* rather than by a probability constant.
- Break them cheaply on night 1 → night 2 is the same company, angrier and thinner.
- **The player's night-1 performance authors night 2.** That is "failure mutates" and "a dead mission
  generates the next story," in the pillar's own words.

**And escalate the SHAPE, not only the number.** Three nights of the same event at different sizes is one
event told three times. Nearly-free differentiation, in ascending order of cost:
1. **Axis memory.** Night 2's sector is not rerolled — it is **the sector that worked on night 1** (the one
   that breached, or the one that was thinnest). One stored bearing. It makes the player's repair,
   re-posting and squad-placement decisions matter, and it is how a real enemy behaves.
2. **Role emphasis by night.** Night 1 leans sapper/probe (recon by fire). Night 2 leans mortars — they
   have the range card now. Night 3 is the committed push. Same systems, different mix, zero new code —
   the cell composition is already a per-cell `EnemyData` choice.
3. **What they take, they keep.** An MG bunker lost on night 1 is not magically manned on night 2 (§8's
   own logic, applied to installations instead of only to men).

---

## 5. §10's COUPLING CLAIM — **half right, stated too confidently, and the design conclusion it draws is
wrong.**

§10: *"raising damage makes sieges EASIER... the threshold arrives sooner... Damage and the break threshold
must be retuned together."*

**What is right:** yes, at a fixed 42.5% break threshold, more damage per hit means the threshold is crossed
in less wall-clock time. The night is shorter.

**What is wrong — the claim measures the wrong variable.** "Easier" is not "shorter." Damage in this game is
symmetric: the same pass raises the AK, the RPD, the 82 mm walking rounds and the 250-damage satchel. Now
look at the two sides' postures:

| | Attackers | Defenders |
|---|---|---|
| Posture | moving, dispersed across a 60° sector, cells materializing staggered | **stationary**, `OrderMode.HOLD` on `post_anchor`, `post_leash = 8.0` |
| Indirect fire | none incoming | **mortars walking onto fixed, pre-registered positions** (§6) |
| Replacement | rerolled next night | **none — §8** |
| Concealment | dark, 18 m jungle / 56 m open sight cap | muzzle flashes from known posts |

**A fixed, un-replaced, pre-registered defender is the single worst posture there is against a lethality
increase.** §10's "the garrison fights from behind sandbags" is asserted with no cover-model pointer — and
the men most exposed are the 12 work-post men who were farmers ninety seconds ago. It is entirely plausible
that raising damage **ends the siege sooner AND costs more garrison**, which under §8's no-replacement rule
is the expensive direction, not the cheap one.

**RULING: the coupling exists, the conclusion does not follow, and the prescribed fix is the wrong lever.**

**Do not retune the break threshold against the damage constant.** Two reasons:
1. `break_state` is a **morale** statement about men (`enemy_squad.gd:109-112`, and `:111` already modulates
   it by `avg_courage`). Coupling it to a weapon damage number makes NVA courage a function of the M16's
   `base_damage`. That is nonsense in the fiction and a permanent drift generator in the code — the exact
   class of hidden coupling the fossil law exists to prevent.
2. It is a treadmill. Every future lethality pass then re-opens the siege tuning, and the two numbers chase
   each other forever.

**The design answer: let the break threshold stand and let lethality price itself in ATTRITION.** Raise
damage → the night is shorter *and* it costs more men. Survival and cost move in opposite directions, which
is exactly what a lethality pass is supposed to feel like, and it needs no coupled constant. If the siege
must be made harder to compensate, the lever the Summoner already handed us is **the count** — d50 is a
strength roll and a strength roll is the honest place to spend difficulty.

**§10 should be rewritten to say that, and it should stop claiming a direction it has not measured.** The
honest version: *"a lethality pass shortens the siege and raises its cost; whether the net reads as easier
is a MEASURED question, and the arena must answer it before the pass lands."* (Noting ADR-028 Phase 3 —
arena tuning must be re-confirmed in the real world build.)

---

## 6. IS A d50 SIEGE FUN AT THE LOW END? — **No, and the fix is one line that also kills the arithmetic
contradiction the ADR ignored.**

The prior council flagged it (`devils_advocate.md:11-24`): `2d6` is not a subset of `d50` for any roll ≤ 11
— **22% of d50 rolls** — producing "seven sappers of one man." The ADR §1 repeats the decree verbatim
(*"Sappers = 2d6 of that count"*) and **does not address it at all.** That is a spec that cannot be
implemented, and GDScript will not error on it; it will quietly produce a sapper-only night nobody ordered.

**A bare `mini(2d6, count)` clamp is the wrong fix.** It resolves the arithmetic and produces a *worse*
event: 3 attackers, 3 sappers, zero riflemen, no mortars, no axis, break math on a sample of three. The
player experiences a "siege" that is three men crawling at the wire — read as a bug, and strictly less
interesting than the raid that ships today.

**RULING — the d50 is not a siege roll. It is a STRENGTH roll, and strength names the event.** The
Summoner's dice are untouched:

| d50 | Event | Composition | What runs |
|---|---|---|---|
| **1–11** | **PROBE** (not a siege) | sappers = `mini(2d6, count)`, rest riflemen | no mortars, no axis assault, no break drama. Men in the wire, the dogs go up, somebody dies. **This is the raid that ships today, kept and renamed.** |
| **12–50** | **SIEGE** | sappers = `2d6` (≤ count by construction) | §§1–9 as written: cells, mortars, the axis, the break, the reap |

This costs nothing to build — the probe branch is the existing `launch_sapper_assault` shape — and it buys
three things at once:
1. **The arithmetic contradiction disappears by construction.** At count ≥ 12, 2d6 can never exceed it.
2. **A 3-man night becomes a legible event with its own name and its own tension** instead of a deflated
   siege.
3. **Scarcity comes back without contradicting "any night."** ~22% of rolls are probes. The wire being
   *hit* is common; the wire being *SIEGED* stays rare — which is what ADR-020 §4 is actually protecting,
   and it is protected here by composition rather than by refusing the Summoner's cadence.

A siege the player can *name* — "the night they came in force" vs "the night they probed the north wire" —
is worth more than any amount of tuned attacker count.

---

## 7. WHAT IS MISSING — ranked. Nothing here re-opens a ruling.

**M1 — THERE IS NO RATE. This is the largest omission in the document.** §1 gives eligibility ("any
night") and a run cap ("≤3 consecutive"), and **no per-night probability, no cooldown between runs, and no
coupling to threat.** `SAPPER_CHANCE` is on the fossil-law kill list (§Fossil law) with **nothing named to
replace it.** Cadence is not a detail — it *is* Pillar 2's Ambience Law, it is the difference between dread
and a Battlefield map, and as written the feature will ship at whatever number the first coder types.
**Required:** a base per-night probability, a minimum quiet gap between runs, and a coupling to the shipped
threat tier (which already cools on clean patrols and heats on loud ones, `field_director.gd:951-956`) and
to ADR-019 village allegiance. Make the siege something the player's own conduct summons.

**M2 — ADR-020 §4 IS NOT CITED AND MUST BE AMENDED.** ADR-020 §4 reads, in force today: *"one night in
twenty hours, the wire gets hit... **A firebase attacked every third night is a Battlefield map**"* and
*"Someone will want the wire hit more often 'because we built the system.' **No.**"* The Summoner's
2026-07-28 cadence ruling supersedes it — **his authority is not in question.** But ADR-035 does not
mention ADR-020 anywhere, in its Related line or its body. Under ADR-014 and the pointer law that leaves
two contradictory laws live in `production/adr/`, and the next architect will enforce whichever he opens
first. **ADR-035 must carry "Amends ADR-020 §4 (the Ambience Law), per the Summoner's 2026-07-28 cadence
ruling," and ADR-020 §4 must carry the pointer back.** This is precisely the drift class CLAUDE.md names.

**M3 — What is a siege WORTH?** No AAR, no bank, no ADR-006/032 term. Defending your home currently scores
NEGATIVE (§Live defects: `spawn_tracked_enemy` debits at `:42-44`, `_bank_patrol` never fires at home,
`:941-943`). The ADR spots the defect and declines to rule the design. **Rule it** (see §2 above).

**M4 — The siege-while-on-patrol case is opened and never designed.** §1 deliberately removes the
`patrol_out` gate so a siege can fire while the player is 500 m out. That is the single most dramatic
version of this event — your base is being hit and you are in the trees. The ADR then says nothing about
it: no radio call, no run-home window, no ruling on whether the siege resolves without him. **Design it or
scope it out explicitly.** (It also interacts with M1: a siege that only fires when he is home is a
different feature from one that can fire when he is not.)

**M5 — "The TOC" is undefined as an object.** §4 makes it the one FATAL objective. ADR-029's Q3 default
ruled *"TOC is scenery."* Which marker is it, what is its health model on the ADR-031 bus, and what
distinguishes "the TOC is destroyed" from "the base is overrun"? §9's entire stake hangs on an object
nobody has specified and a prior ADR calls scenery. **Name the marker and reconcile Q3.**

**M6 — ADR-019 is absent.** A siege spends 20–50 VC. ADR-019 §1 makes regional manpower finite and
allegiance-driven. Feeding siege casualties into that pool, and letting allegiance drive whether a siege
fires at all (M1), is free depth in an already-decreed system and closes the loop between how the player
treats the villages and who comes over his wire at night. Zero mention.

**M7 — Garrison replacement faucet** (§3 above).

**M8 — Stand-down identity contract** (§3 above).

**M9 — The fail-forward successor state** (§1 above).

**M10 — Telegraph.** §2 contract 4 (dormant cells emit `NoiseBus`) is excellent and is the only warning in
the document. What else does the player get — a sentry bark, a radio call, the sim-clock hour, a change in
the base's own schedule at dusk? The minutes before the first ranging round are the best minutes this
feature has, and they are unwritten.

---

## VERDICT

**RATIFY WITH AMENDMENTS.**

The ADR is faithful to every Summoner ruling, does not smuggle back a briefing UI or an objective counter,
and its engineering findings (THE REAP, the body-not-brain correction, stand-down, the `patrol_out` /
`_bank_patrol` / `sim_day` defects) are genuine and well-pointered. It should not be sent back — sending it
back would cost a session and change none of that.

**Binding amendments before build:**

| # | Amendment | Section |
|---|---|---|
| A1 | Name the morning after — the recovery anchor re-hosts, the loop survives degraded. Mark the respawn condition UNFINISHED, not decided. | §9 |
| A2 | PROBE (d50 1–11) vs SIEGE (12–50). Resolves the 2d6/d50 contradiction by construction. | §1 |
| A3 | One d50 per RUN, not per night. Nights 2–3 attack with survivors + a trickle. Add axis memory. | §1, §8 |
| A4 | State the cadence RATE — per-night probability, inter-run gap, threat/allegiance coupling. And **amend ADR-020 §4 explicitly.** | §1 |
| A5 | Rule the siege AAR: defending banks. Closes the unpriced half of Consequence 2. | §5 |
| A6 | Name the garrison replacement faucet and the stand-down identity contract. | §8 |
| A7 | Rewrite the §10 coupling: lethality shortens the siege and raises its cost. Do NOT couple the break threshold to the damage constant; spend difficulty on the count. | §10 |
| A8 | Name the squad-order verb as the siege's Pillar-4 decision. Define the TOC as an object. | §3, §4 |

**PILLAR VIOLATION OF RECORD: Pillar 5 (Fail Forward), ADR-035 §9** — an unrecoverable loss with no
described successor state, on a save-scummable timescale, is the reload-and-memorize stimulus the pillar
names by name. Amendment A1 clears it.

**PILLAR HAZARD (not yet a violation): Pillar 2 (Atmosphere), ADR-035 §8** — the protection is a
three-night deferral of a permanent loss, because no faucet refills 24 men. Amendment A6 clears it.

**DOC-LAW DEFECT: ADR-035 §1 vs ADR-020 §4** — the Summoner's cadence ruling supersedes the Ambience Law's
scarcity clause, and ADR-035 does not record the amendment. Two contradictory live laws. Amendment A4
clears it.
