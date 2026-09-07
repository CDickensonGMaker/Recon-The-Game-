# SYSTEMS DESIGNER — Individual Sight
**War Room 2026-09-07 · SQUAD COHESION AS A COMBAT MECHANIC** · Phase 2, independent, no cross-talk.
All code pointers verified by reading, 2026-09-07.

---

## THE CLAIM IN ONE LINE

**Cohesion is not a new state variable. It is already built, wired on both sides, and probe-covered —
under three other names — and the only thing genuinely missing is a READ. The squad already refuses
orders. It just never says so.**

---

## 1 · IS COHESION REAL HERE, OR A RE-SKIN?

**A re-skin of THREE shipped systems, not one.** `grep -rn "cohesion\|morale" scripts/` returns exactly
one hit and it is a comment. But the substance is everywhere:

### Layer A — fire discipline: `scripts/ai/squad_coordinator.gd` (232 lines, REAL, WIRED BOTH SIDES)

This is BiA cohesion, built, running, and nobody calls it that. Per-side, per-squad records keyed
`Vector2i(side, squad)`:

- **Exposure tokens** (`request_exposure`, `:135-166`) — the *right to be out of cover*. N tokens per
  squad, doctrine-set (US 3 · NVA 3 · VC 2 · assault_press 999). `HOLD` and fire-from-cover are never
  gated. This is fire-and-movement as an economy with a hard supply.
- **The suppressor slot** (`is_suppressor`, `_elect_suppressor`, `:198-232`) — ONE base-of-fire man per
  squad, re-elected at 1200ms. Prefers a covered MG, never a token holder, prefers the passive element.
  The file cites Company of Heroes by name.
- **Covering-fire census** (`report_firing` / `has_covering_fire`, `:96-112`) — one write per trigger
  pull, 1500ms window, per squad. The comment at `ally_base.gd:186-190` records why it was rewritten:
  the old global static counted "an ambient patrol 400m away as *my squad is covering me*."
- **Two-element bounding overwatch** (`_update_elements`, `:124-133`) — registration-order parity,
  flip period 5-7s by doctrine. Element 0 leads the first bound.

Wiring is real and symmetric: `ally_base.gd:1067,1071,1128-1131,1173,1197,1211-1218,1629,2075,2321` and
`enemy_base.gd:1496,1550,1576,1602-1612,1895,2415,2995`. `mission_scope.gd:36` clears it between
missions so tokens cannot leak. Probe: `tests/test_squad_coordinator.tscn` (cases a-h). Doctrine is data
in `data/ai/doctrine_{us,nva,vc,assault_press}.tres` — no doctrine forks code.

**Not a stub. Not dead. This is the mechanic the Summoner is describing, already in the build.**

### Layer B — the break: `EnemySquad.break_state` + `SquadSystem.squad_broken`

`enemy_squad.gd:118-122` is ONE break authority for both sides: `ratio = live/peak`, threshold
`0.45 + (0.5 - avg_courage) * 0.4` clamped `[0.20, 0.80]`. `squad_system.gd:554-585` runs the player's
own squad through the *same function* on a 1s cadence and writes `squad_broken` down to every man. It
already has a HUD affordance — `"SQUAD COMBAT INEFFECTIVE - BREAKING CONTACT"` toast plus a `fall_back`
VO line — and an effect: `ally_base.gd:220` (anchor), `:227`, `:906`, `:1538` (stand-off band 1.0 vs
0.6 when broken).

### Layer C — nerve: the per-man morale that MOVES

`ally_base.gd:120-166`. `_nerve_drift` falls 0.12 per squadmate down within 25m (`on_squadmate_down`),
floors at -0.30, recovers at 0.02/s in a lull. `effective_courage()` adds `RALLY_BONUS` +0.10 when the
player is within 6m **and forward of the man toward the threat** (`_player_is_forward`). The comment at
`:130-135` records a past defect where a proximity-only bonus was permanently on.

**The recovery verb for cohesion already exists in this codebase and it is: STAND IN FRONT OF YOUR MEN.**
It is Pillar 4 by geometry, it is shipped, and it is completely invisible.

**Verdict on Q1: cohesion as a NEW variable is REFUTED. A fourth scalar sitting beside `squad_broken`,
`_nerve_drift` and the token pool is precisely the "multiple things that could accidentally be
interpreted as the same thing" the FOSSIL LAW forbids.**

---

## 2 · APPLYING THE ACCURACY LENS — WHAT IS ACTUALLY LOAD-BEARING?

His origin finding was that *"they don't die"* was accuracy, not damage. Same suspicion here: if
cohesion wins Vietnam squad fights, **what number would actually have to move?**

**It is the EXPOSURE CLOCK, and it is already the largest lethality lever in the game.**

`ai_marksmanship.gd:79-82`: `exposure_spread_mult(t) = 1 + 1.4*(1 - t^2)` — the cone is **x2.4 fresh,
x1.0 converged**, and `:96` breathes the 1.0 deg cap with the ramp (a fixed cap silently clipped the
whole ramp away; that defect is recorded in the file). Its input is `target_visible_duration`
(`enemy_base.gd:1443-1452`), which builds at think rate and **drains at 3x** on LOS loss — ~0.8s blind
zeroes it. Alongside it: `combat_posture.gd:58-59` widens a suppressed man's cone **x1 -> x3.2**;
`MOVE_PENALTY` 1.5; cover multiplies both sides of the suppression ledger.

**So the whole cohesion fantasy is already expressible in shipped terms:**

> Cohesion = your squad's ability to hold the enemy's exposure clocks at zero and suppression high,
> while your own clocks run to one. Who has to move (a token), who shoots so the mover isn't shot (the
> suppressor slot + the census), and whose clock is running.

That is the mechanism. **It is not a new system. It is a system with no instrument panel.**

### Two real defects found, both in that instrument, both BUG-FIX class (gate-exempt)

1. **The exposure clock is ASYMMETRIC between the factions.** `enemy_base.gd:1423` (and `:1430`)
   zeroes `target_visible_duration` on target switch — *"a new victim gets a fresh exposure clock."*
   **`ally_base.gd:1036-1043` has no such reset.** A squadmate who has been staring at man A for ten
   seconds swings onto man B with a fully converged cone. Your squad is measurably better at
   target-switching than the enemy is, and no ADR ever ruled that.
2. **The ally first-shot flag never re-arms.** `ally_base.gd:2096` sets `_first_shot_fired = true` and
   nothing ever clears it; the enemy re-arms per fight at `enemy_base.gd:1313`. Currently INERT, because
   the nudge is gated on `is_player_target` and an ally never targets the player — so it is a dead
   branch, fossil-adjacent, not a live bug. Name it before someone "fixes" it into life.

---

## 3 · ADR-040 §4 — THE NAMED HOLE IS HALF THE SIZE THE ADR CLAIMS

ADR-040 §4 states the swing-on shooter *"spends no warning shot."* **Checked against code: true for the
NUDGE only, and false for the Fairness Law as a whole.**

The Fairness Law has two halves, and `aim_with_spread` (`ai_marksmanship.gd:85-104`) applies them
independently:

| Half | Gate | Fires on a swing-on? |
|---|---|---|
| `_first_shot_nudge` — deliberate 5-9 deg miss (`:53-60`, applied `:102-103`) | `force_first_miss` <- `not _first_shot_fired`, re-armed ONLY on the RELAXED/SUSPICIOUS -> COMBAT edge (`enemy_base.gd:1305-1313`) | **NO** |
| `exposure_spread_mult` — the x2.4 -> x1.0 ramp + breathing cap (`:79-82, 94-96`) | `exposure_t` <- `target_visible_duration`, **zeroed on every target change** (`enemy_base.gd:1423`) | **YES** |

So a man already fighting your squad who swings onto you **does** open with a cone widened x2.4 and a
cap that breathes with it. What he skips is one deliberate warning crack.

**Consequence, and it cuts both ways: the "highest-value single fix available" in ADR-040 buys less than
advertised, and its named cost to Pillar 1 is correspondingly smaller.** The gap is one shot, not
"no warning." That should be re-measured before it is priced, and ADR-040 §4 should be corrected on
contact (NO MORE DRIFT).

**Against the Summoner's point 6 specifically:** the near-miss window is ~one shot per shooter, on the
order of 0.3s of tape. **It is a telegraph, not a recovery window. It cannot carry the weight he wants
to put on it.** The real recovery window is already built and is 10-20x longer: nerve recovering at
0.02/s, `incoming_pressure` decaying, suppression shedding in ~3.3s, and the rally bonus.

---

## 4 · IF COHESION GATES WHICH ORDERS FUNCTION — THE STATE, AND THE ADR-018 QUESTION

**In state terms it means: `SquadSystem._unhandled_input` (`:277-291`) stops being unconditional.**
Today every one of the four orders routes straight into `_order_all` -> `a.set_order(mode, pos)` for
every living man, plus a toast and an ack VO. A gate inserts a predicate — `squad_broken`, or
`SquadCoordinator.request_exposure` returning false — between the key and `set_order`.

**Against ADR-018: ORTHOGONAL, and arguably an EXTENSION — not a violation.** ADR-018 forbids
progression touching *the player's* accuracy, recoil, sway, handling, health, stamina. A cohesion gate
touches none of those, and it is not progression at all: it is squad state, second-to-second, earned and
lost inside one firefight. ADR-018 §3 says rank gates *what is on the menu*; a cohesion gate would say
*whether the men will take it right now*. Those compose cleanly. **Where it breaks is elsewhere.**

**The actual collisions:**

- **Pillar 3 (Freedom, no rails) — THE REAL ONE.** A refused order is a rail wearing a diegetic costume.
- **ADR-021** names the follow phase as "the closest this design comes to a rail" and "may never be
  enforced." A gate that refuses MOVE-TO is that enforcement.
- **ADR-012** — four prime keys already spent, neither binding removable. There is no fifth verb going
  spare, so any proposal that needs a key is expensive before it starts.
- **`squad_coordinator.gd:11-12` states its own charter:** *"Orders are REFUSABLE by construction: the
  coordinator only shapes goal picks; survival verbs are never routed through it."* Routing PLAYER
  orders through it deliberately crosses a line the file was written to hold.
- **ADR-023 (Fossil Law)** — a fourth cohesion scalar beside three existing ones.
- **ADR-005 / ADR-006 Amendment B** — no collision found. Cohesion is a combat-tempo state; the witness
  rule is a detection state and the score's surviving SENSOR is fire discipline near a ville. Different
  clocks, no shared write.
- **THE GATE (ADR-015)** — a cohesion *system* is a feature epic and is BLOCKED. The two exposure-clock
  defects in §2 and the ADR-040 §4 correction are bug fixes and are EXEMPT.

**AND THE FINDING THAT MATTERS MOST HERE: the squad ALREADY refuses, silently.** A broken squad ordered
into the open holds at a wider stand-off (`ally_base.gd:1538`, band 1.0 vs 0.6), anchors (`:220`), and
will not close (`may_close_distance` reading `effective_courage()`, `:1687`). **The refusal is shipped.
The player reads it as his squad being stupid, because nobody tells him otherwise.**

---

## 5 · THE PLAYER-VISIBLE VERB, AND THE r4bk QUESTION

**No new verb is needed, and I would refuse one.** What is missing is a READ, not a verb.

Can cohesion claim ADR-018 §2's silent exemption ("the affordance is the man himself")? **Partly — and
it has a *better* claim than squad XP does.** XP moves over missions and is genuinely invisible;
cohesion moves second to second and is legible in posture, spacing, rate of fire and VO — it is already
half-showing. **But an ORDER GATE may never claim that exemption.** A key that silently does nothing is
the worst r4bk violation available, worse than no feature at all.

### THE CHEAPEST VERSION THAT ALREADY FEELS LIKE THIS

**Make the existing silent refusal audible. Branch the ack.** `_order_all` (`squad_system.gd:303-311`)
already selects a living acknowledging man and plays a line. Add one branch: when `squad_broken`, or
when no exposure token can be had for a MOVE-TO into the open, the ack becomes a refusal bark —
*"NEGATIVE, WE'RE PINNED"* — and the toast says so.

- **Zero new state.** Reads `squad_broken` and `SquadCoordinator.request_exposure`, both already there.
- **Zero new keys.** ADR-012 untouched.
- **Zero new HUD surface.** The toast + VO path exists and already carries the break message.
- **Pillar 3 intact** — the order is not refused, it is *answered*. The men still do what they can. The
  player learns that cohesion is a thing by being told, which is the whole ask.
- Roughly a day. Presentation for a shipped system -> plausibly GATE-EXEMPT, but say so honestly and let
  the Arbiter rule it.

Add, if a second day is available: the same treatment for the *positive* pole. When the rally bonus is
live — player within 6m and forward — one steady line. Cohesion recovery becomes something he can *hear
himself cause*.

### THE VERSION THAT EATS A MONTH

A first-class cohesion resource: its own accrual and decay curves, a meter or pip HUD, drills/rest as a
restore loop, orders hard-gated by threshold bands, retuning the whole existing morale stack so the two
do not fight, a new balance surface across four doctrines, and a tutorial for it. New state (Fossil Law),
new HUD (r4bk), new key or a re-bind (ADR-012), a rail (Pillar 3 / ADR-021), and a feature epic under an
undischarged gate. **Every one of the three systems it would sit on top of already works.**

---

## 6 · WHAT IT COSTS — THE SACRIFICE, NAMED

- **The cheap version's cost: the squad gets to say no to the player, out loud.** Some players will read
  a refusal bark as broken AI, not as characterisation — and they will be *half right*, because in
  gameplay terms the squad's compliance genuinely degrades. Confirmed cost, not a hypothetical.
- **Naming cohesion at all costs mystique.** Right now a shaky squad reads as *men*. A named system
  invites it to be read as a *meter*, even without a meter — and that is Pillar 2 spent.
- **Fixing the ally exposure-clock asymmetry makes YOUR squad worse.** It is correct, it is fair, and
  the Summoner will feel it as his men getting dumber. That must be said before it ships, not after.
- **Correcting ADR-040 §4 costs a promise.** The ADR calls that fix the highest-value item against his
  durability complaint. Shrinking it to "one shot" means the durability complaint is *less* answered
  than the ADR asserts, and something else has to carry the difference.

---

## 7 · THE SUMMONER'S SIX POINTS — BY NUMBER

**1 · CONFIRM, with the lineage corrected.** Pillar 1 is *"AI that fights like soldiers AND weapons that
kill like weapons, neither subordinate"* — the BiA feel is canon, not an import. **But the inheritance
the CODE carries is not BiA's.** `combat_posture.gd:20` cites *Company of Heroes doctrine* by name,
`squad_coordinator.gd:190` cites CoH for the MG base of fire, and `combat_goals.gd:59` cites *FEAR
doctrine* for suppression. The ancestry is CoH + F.E.A.R., not Brothers in Arms. The *feel* is shared;
the machinery is not, and he should know which one he is actually building on.

**2 · CONFIRM.** Grand war at the ambient layer, fight stays squad-sized: `SQUAD_SIZE = 8`, per-squad
break thresholds on both sides, the air beats walking the compass in the demo arc. No contradiction found.

**3 · REFUTE — and this is the one worth having.** He says cohesion-as-winning-fights is a GAP with no
ADR. **The ADR gap is real; the CODE gap is not.** SquadCoordinator, break_state and nerve drift are
built, wired both ways, doctrine-driven and probe-covered. He is looking at an undocumented system and
reading it as an absent one. What is genuinely missing is the read-out and the ruling, not the machinery.

**4 · CONFIRM, harder than he stated it.** There is no "attack that" order in this game *at all* — the
verbs are FOLLOW / HOLD / MOVE-TO / FIRE-TOGGLE (`squad_system.gd:277-291`) and every engagement
decision is the men's own goal scorer. Pillar 4 already says it: *"the squad holds its own AI intent."*
**The player commands recovery, exactly as he claims — that is already the shipped architecture.**

**5 · CONFIRM as design intent, REFUTE as current build.** In this build the player usually gets Find,
not the enemy: the demo arc is a defensive siege, and the patrol contact model is the point-man scan
(`squad_system.gd:593-599`) whose radius is *extended* by the `detect_ambush` skill
(`skill_catalog.gd`, `squad_roster.gd:264`). **The shipped design is ANTI-ambush — it exists to stop you
beginning already fixed.** "You begin fixed" is aspiration, and it contradicts a skill already on the
roster. That tension needs his ruling.

**6 · REFUTE the mechanism, CONFIRM the shape.** The shape — shattered by ambush, restored over time —
is right, and three quarters of it is built. But the near-miss is **not** the recovery window: it is one
shot per shooter, and §3 shows the ramp half of the Fairness Law already fires on the swing-on case
anyway. The recovery window that exists is nerve drift + the rally bonus, and it is an order of
magnitude longer. And *"gating which orders function"* is the expensive, rail-shaped half of his idea
when **making the refusal that already happens audible** buys the same feeling for a day's work.

---

## WHAT I WOULD PUT TO THE COUNCIL

1. **Cohesion is a NAME and a READ, not a system.** Ratify the three existing layers as one named
   mechanic in an ADR. Build no fourth scalar.
2. **Ship the refusal bark.** One branch in `_order_all`. Cheapest thing on this table.
3. **Fix the ally exposure-clock asymmetry** (`ally_base.gd:1036-1043`). Bug fix, gate-exempt, and it is
   the number the accuracy lens actually points at.
4. **Correct ADR-040 §4 on contact.** The hole is one shot, not "no warning." Re-price the fix.
5. **Refuse the order gate.** Pillar 3 and ADR-021, not ADR-018, are what kill it.
