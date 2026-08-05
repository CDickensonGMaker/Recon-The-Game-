# DEVIL'S ADVOCATE — Hearts & Minds / Invisible Factions
**Council:** 2026-08-05 · **Role:** attack, not build · **Every claim below carries a pointer or is marked as opinion.**

My job is to make the case that this council is about to design a system that will not be built,
would not be noticed if it were, and is already being felt by the Summoner without existing. I
believe two of those three, and I can prove the third.

---

## A · THE HEADLINE RISK — 24 days, zero lines, and the reason is structural

ADR-019 is dated **2026-07-12** and Accepted. `production/adr/` now holds ADR-035 and ADR-036.
Roughly thirty-five decisions were made, built and shipped around this one. ADR-019 shipped
**nothing**: `ProvinceState` · `allegiance` · `sympathy` · `hearts_and_minds` = **0 hits repo-wide**
(briefing, verified 2026-08-05).

The honest reason is in ADR-019's own header: **"Depends on: ADR-017 (the province must persist for
any of this to exist)."** And ADR-017 has shipped nothing either — but worse than that, **ADR-017 is
partly a fossil ADR, and nobody has noticed.**

Evidence, measured today:

1. **ADR-017's own evidence block is stale.** `ADR-017:108` cites *"`game_flow.gd:184, 198` — global
   `seed()` then a global `randi()` draw (**the determinism leak**)."* `grep -n "LOADING_TIPS\|seed("
   scripts/main/game_flow.gd` returns **nothing**. `game_flow.gd:178-202` is now bunk-spawn floor
   raycasting. The loading-tips screen was deleted with the briefing loop under ADR-029/ADR-023. The
   named leak, the ADR's central determinism argument, **no longer exists at the address given**.
   That is a POINTER LAW violation sitting inside a canon ADR.
2. **ADR-017 §4's headline decision already shipped by another route.** "The firebase lives INSIDE
   the AO… a PATROL is a mission whose window contains the firebase: you walk out the wire" is the
   shipped ADR-029 loop (`ADR-029-open-patrol-simulator.md`, ratified 2026-08-04; `_bank_patrol`,
   `field_director.gd:1768`). ADR-028 "one world build path" ate the rest.
3. **What is left of ADR-017 is the expensive half nobody has started:** `ProvinceState`, the
   two-generation determinism hash probe (`ADR-017:68-70`, "if that probe is not green, the province
   does not ship"), stable generator-indexed object IDs (`:66-67`), save migration (`:97`).

**The plain finding: ADR-019's hard dependency is on the unbuilt residue of an ADR whose premise has
been partially superseded and whose evidence has drifted.** That dependency has never been
scheduled, and there is no bead system left to schedule it in (beads RETIRED, `CLAUDE.md:401`).

**Therefore, stated plainly, as the brief demands:** *any hearts-and-minds design that routes through
`ProvinceState` is a design that will still be unbuilt in six months.* Twenty-four days of evidence
already say so, and the reason is not laziness — it is that ProvinceState is a world-generation
architecture with a binding determinism gate in front of it, and this project ships depth-first on
whatever the Summoner can see this week.

**The council must pick one and say which:**
- **(a) Build it on `CampaignState` alone.** It is already saved (`campaign_state.gd:298-327`),
  versioned (`:6`), migrated (`:383`), and the threat road is already consumed by SiegeDirector
  (`siege_director.gd:191`) and fire support (`field_director.gd:1419`). Cost: **no per-village
  granularity, ever, until ProvinceState exists.** You get one number for the whole AO. ADR-019 §2's
  per-village table becomes a per-AO table. That is a real amputation of the decree and must be
  written down as an amendment, not smuggled.
- **(b) Admit the dependency and schedule it** — meaning the determinism probe, ID scheme and save
  migration land FIRST, before one line of allegiance. Cost: months, and the demo does not care.

**What (a) sacrifices:** the ville-by-ville story ADR-019 §4 is made of. "The ville that used to wave
and now goes silent" is a *per-village* tell; a global number cannot produce it honestly — it can only
make every village go silent at once, which reads as a global mood slider, which is exactly the meter
ADR-019 §4 forbids, wearing a costume.

**What (b) sacrifices:** the system, for this year.

---

## A.2 · THE VERB DOES NOT EXIST — and this is worse than the ledger gap

Nobody has said this out loud yet, so I will.

**ADR-019 §3 is titled "THE FAST ROAD MUST GENUINELY WORK." Its fast road is burning the village.
There is no way to burn anything in this game.**

- `EvidenceLedger.on_structure_burned` (`evidence_ledger.gd:71-72`) — the briefing calls it "the arson
  hook (already exists)". `grep -rn "on_structure_burned" scripts/` returns **exactly one hit: the
  definition itself.** Zero callers. It is a fossil by the ADR-023 taxonomy — UNFINISHED: built ahead
  of its wiring.
- A full `grep -rni "burn" scripts/ --include=*.gd` finds napalm burn time (`fire_plan.gd:29`), WP
  burn (`:47-48`), illum burn (`illum_flare.gd:28`), tracers, and prose. **No structure fire, no
  arson verb, no Zippo, no hut state.**
- `ADR-031` destruction doctrine: **P5 is NOT BUILT** and sits behind a perf gate
  (`DEMO_SHIP_BACKLOG.md` PHASES line: "P4 destructible world + temples … P5 consequence hooks
  (ruling 4)"). Hearts-and-minds consequence hooks are literally scheduled as **P5, behind P0-P4.**
- And ONE crater already costs a full 256m chunk rebuild — 4,225 verts, ~24,576 `SurfaceTool` calls,
  synchronous, main thread — and is the suspected cause of *"its def laggy with everything going on"*
  (`DEMO_SHIP_BACKLOG.md:1428-1432`). Burning huts is in that same neighbourhood of cost.

**The positive column is equally empty.** `grep -rni "medcap\|tax_collector\|supply drop\|detain"`
across `scripts/` returns **zero**. ADR-019 §2's entire COOPERATIVE column — medcap, supply delivery,
tax-collector interdiction, protecting a ville from a night raid — has **not one verb behind it**.

So the honest state of ADR-019 §2 is: **a two-column table in which one column has one live input
(killing civilians, `civilian.gd:630`) and the other column has none.** Designing the equation now is
designing the exchange rate for a currency that has not been minted.

**Attack, stated hard:** a council that spends today weighting arson at −30 and medcap at +20 is
producing a document, not a system. The only inputs that can move anything this year are: civilian
deaths (live), enemy bodies left in a ville (live via `on_body_left`, `evidence_ledger.gd:67`),
gunfire near a ville (live, `on_noise:57`), and ear-taking (live at `player.gd:240-252`). **Design the
equation over those four, or admit you are writing fiction.**

---

## B · THE INVISIBILITY TRAP — it will be built, it will work, and nobody will ever perceive it

ADR-018:88-91 already convicted this exact failure mode, about a different system, in this project's
own words:

> "Silent squad XP is hard to author and impossible to see. **Its whole value is felt, not read —
> which means it is the easiest system in the game to build and have nobody notice.** … if that isn't
> legible enough to feel, **the system has failed and must be cut rather than papered over with a
> UI.**"

ADR-019 is the same bet, made larger, with a longer delay. ADR-019:104 even pre-commits the verdict:
*"If the player cannot feel it through the world within one playtest, the presentation has failed."*

**Here is why I expect it to fail that test.** The signal this system produces is *a change in the
distribution of random events*, and this game is already saturated with randomised danger the player
cannot attribute:

| Existing randomness | Pointer |
|---|---|
| Night siege roll, 5%/15%/30%/45% by tier | `siege_director.gd:11, :191` |
| Hunter dispatch timer `randf_range(70,110)` then `(100,160)×field_mult` | `field_director.gd:141, :170` |
| Hunter count `randi_range(2,4)`, bearing `randf_range(0,TAU)`, ring 180–230m | `:171-175` |
| Evidence scatter — 55m noise / 8m physical | `evidence_ledger.gd:26-27` |
| Informer existence roll (~50% base, forced 100% in demo) | `DEMO_SHIP_BACKLOG.md:566-569` |
| Baseline threat drift ±0.03/0.05 on kills | `campaign_state.gd:242-245` |

Layer an allegiance-driven ambush-density multiplier on top of that and ask honestly: **what
observation could a player make that distinguishes "the district hates me" from "I rolled badly"?**
Two patrols is n=2. Ten patrols is n=10 against a 45%-vs-30% siege chance — statistically
indistinguishable to a human, and the human is not keeping a tally because ADR-029 §4 forbids one.

**This is not the same as the squad-XP bet, and the difference makes it worse.** A veteran squadmate's
affordance is *a man in front of you doing something*: he spots a trap, he calls a contact early. That
is a discrete, attributable, repeatable event. Allegiance's proposed affordance is a *rate*. **A human
cannot perceive a rate change without a counter, and the counter is banned.**

### The acceptance test — name it or do not build it

The Summoner's own standing acceptance test for the fear/lethality work is a felt-experience gate:
**"I don't feel in danger"** (`recon-fear-doctrine-lethality`). It is a good gate because it is a
sentence he can say after ten minutes without opening a file.

The equivalent gate here, and I assert nothing weaker should be accepted:

> **THE GATE: after a session in which he treated a village badly, the Summoner must, UNPROMPTED,
> say something to the effect of "that ville has it in for me" — naming the PLACE, not the game.**

Two failure readings, and both must be pre-declared as failures:
1. He says "the game got harder" → **FAIL.** He felt escalation, not allegiance. That is
   `add_threat_modifier` doing its existing job and the new system is undetectable.
2. He says nothing, and the tell only surfaces when an agent points at the code → **FAIL, by
   ADR-019:104's own words**, and the ADR-018 remedy applies: cut it, do not add a meter.

**What proves perception, concretely:** a *discrete, attributable, local* event the player can name.
Not a density. Candidates that survive the "could this be luck?" test:
- The ville that **used to have people outside and now has none when you walk in** — binary, visible,
  local, and cheap: `civilian.gd` already owns state and schedules (`CivState`, `VILLAGE_ACTION_CLIPS`,
  `civilian_schedules.gd`). Going indoors is a schedule override, not a new system.
- A **squadmate line naming the place** — the squad already speaks; a bark keyed to a village id is
  attributable in a way no probability is.
- A **trap where you walked clean last time** — same trail, changed outcome, one patrol apart.

Everything else on ADR-019 §4's list ("trails that used to be clean and are now wired", "the ambush
that was waiting") **is a rate wearing prose.** I would strike them from the design as tells.

**What the perception-first position sacrifices:** subtlety. Villagers going indoors on a threshold is
a near-binary switch, and a switch is one step from a meter. ADR-019 §4 wants the reading to be
ambiguous; ambiguity and perceptibility are in direct tension here and **the council must say which
one it is spending.** My position: spend ambiguity. An unperceived system has no moral weight at all,
and moral weight was the entire justification.

---

## C · THE OTHER DIRECTION — he already feels it, from code that does not exist

This is the finding I would put in front of the Summoner first.

He said, today, that levelling a village makes the enemy come after him hard, and called it *"the
hearts and minds invisible factions system at work."* **There is no such system.** So something else
produced that experience, and identifying it is worth more than the rest of this council.

Three live mechanisms are candidates, and I can price each:

1. **`EvidenceLedger` + hunter dispatch — the strongest candidate, and it is genuinely good.**
   `field_director.gd:131-186`. The player shoots up a village → gunshots (`WEIGHT_GUNSHOT 1.0`) and
   bodies (`WEIGHT_BODY 2.0`) go into the ledger → `_check_detection` fires **"YOU'VE BEEN MADE -
   THEY'RE MOVING TO CONTACT"** → 70-110s later, 2-4 NVA regulars spawn 180-230m off the fix and walk
   to it, tier ALERT, with **"MOVEMENT IN THE TREES - THEY'RE LOOKING FOR YOU"**. Violence at a place
   causes armed men to converge on that place, on a delay, announced in words. **That IS
   hearts-and-minds as experienced.** It is causally honest (bodies weigh 2× a gunshot), it is
   attributable (he did a thing, a toast named it, men came), and it is already shipped.
   *It is scoped to one patrol and nothing carries across the wire (briefing).*
2. **The informer flip** — `civilian.gd:582-594` → `_transform_to_vc:651`. A villager who sees you and
   escapes becomes VC. A villager literally changes sides because of what he saw. That is the
   hearts-and-minds fantasy in miniature, live today, and **it is not named anywhere the player can
   read.**
3. **The night siege** — `siege_director.gd:191`, odds keyed to `CampaignState.threat_label()`, and
   `on_mission_end` nudges the baseline **+0.05 when kills ≥ 12** (`campaign_state.gd:242-243`). Kill
   twelve men on a patrol and the firebase is measurably likelier to be hit that night. **A body-count
   day already buys a worse night.** That is ADR-019 §5's "kills can actively cost you", shipped, on
   2026-07-something, by a different door.

**And the fourth possibility, which the council must not skip: he may be confabulating from a scripted
timer.** In the demo, the assault is **fixed**: `SIEGE_AT_S = 1440.0`, `SIEGE_STRENGTH = 45`
(`demo_game.gd:54, :69`) — and his own ruling Q3 (2026-08-04, verbatim) was *"I dont think the kills in
the day should effect the assault later on"*, recorded as **"§2.8 DROPPED, fixed 45-man assault
stands"** (`DEMO_SHIP_BACKLOG.md`, decision queue). **He ruled the demo assault independent of his
conduct, and then experienced it as retaliation for his conduct.**

That is not a criticism of him. **It is the most important data point this council has**, and it cuts
exactly one way:

> **A fixed timer, plus a toast that names his own act, was sufficient to produce the felt experience
> of an invisible faction system. The felt system is cheap. The simulated system is expensive. They
> are not the same purchase, and this project has already accidentally proven which one the player
> notices.**

**The cheapest correct move, therefore:** do not build a new system this quarter. **Strengthen and NAME
what already exists.**
- Carry `EvidenceLedger`'s residue across the wire as ONE `add_threat_modifier` call at
  `_bank_patrol` — the road is already saved, decayed and consumed. Roughly a ten-line change.
- Give the informer flip and the hunter dispatch **place-naming language** — "THEY'RE LOOKING FOR YOU"
  becomes something that names the ville, so causality is attributable instead of ambient.
- Let the AAR sentiment line (sanctioned by ADR-019 §4 as a briefing, which is diegetic) read the
  threat road that already exists.

**What that position sacrifices, and it is not small:**
- **The per-village story dies.** One threat number cannot say "Ap Bac hates you, Phu Loi does not."
  Everything ADR-019 §2 promised about districts is deferred, possibly forever.
- **The moral asymmetry dies with it.** On the `add_threat_modifier` road, killing civilians and
  killing soldiers both come out as "the AO is hotter." **The system stops being about conduct and
  becomes about noise** — which is what `EvidenceLedger` already is, and arguably the honest thing it
  should stay. If the council takes this road it must say out loud: *hearts-and-minds, v1, cannot tell
  a war crime from a firefight.*
- **It risks fossilising the ambition.** Ship "H&M v1 = threat modifier", and ADR-019 will be quietly
  marked done. That is the false-"done" disease that retired the bead system (`CLAUDE.md:401-403`).
  **Mitigation is mandatory: whatever ships must be named `THE AO REMEMBERS` or similar, NOT hearts
  and minds, and ADR-019 must stay open with an explicit "§2 unbuilt" banner.**

---

## D · WHAT ELSE BREAKS

### D.1 · A fast road that genuinely pays becomes a min-max puzzle
ADR-019 §3 is binding: burning must *actually* pay — "the sniping stops, the VC lose a base, you are
home before dark." §3's cost arrives "later, and quietly", as a recruitment rate change.

**An immediate, legible, reliable benefit paid against a delayed, illegible, probabilistic cost is not
a moral dilemma. It is a dominant strategy.** ADR-019 §4 removes the meter precisely so the player
cannot optimise — but the *payoff* is not hidden, only the cost is. Hiding the cost does not stop
optimisation; **it makes optimisation correct.** An optimiser burns every ville, because he can see
the gain and cannot see the bill, and the game's own §4 guarantees he never will.

The tension is structural and this council cannot dissolve it. It can only choose:
- **Make the cost legible** → the player optimises against the cost → §4 violated.
- **Keep the cost invisible** → burning dominates → §3's "sometimes the right call" becomes "always
  the right call" → the moral weight inverts. *The player concludes atrocity is free, which is a
  statement the game makes accidentally and cannot take back.*
- **Make the payoff unreliable** → §3 violated ("it must pay immediately and legibly").

**My recommendation: break §3, narrowly and in writing.** The fast road should pay *immediately and
legibly* on the **tactical** axis only — this contact ends, you go home now — and never on the
strategic axis. Never a cache, never intel, never score. That is defensible against §3's intent
(*Platoon* is about how easy it is), and it takes the dominant-strategy edge off. **Sacrifice: a
narrow amendment to a binding law of an Accepted ADR, which must be an amendment document, not a
council footnote.**

### D.2 · Per-village persistence = save bloat + the "wrong hut burned" failure
ADR-017:66-67 warns in its own words: *"Every persistable world object carries a deterministic
generator index — `district/kind/n`, derived from generation order, never a node name or a position
hash. **Get this wrong and the player returns to find the wrong hut burned.**"*

**The project's only shipped example of persistent world damage does exactly the forbidden thing.**
`CampaignState.remember_collapsed_tunnel` keys on a **rounded world position**
(`campaign_state.gd:479-483`) and matches with a **3.0m distance tolerance** (`:488-492`). That is a
position hash, explicitly named as wrong by ADR-017. It survives today only because collapsed tunnels
are few, coarse and forgiving. **Per-village, per-hut allegiance state cannot use that pattern**, and
the correct pattern (stable generator indices) does not exist. That is not a design decision, it is
several days of world-gen work with a hash probe in front of it (ADR-017:68-70).

Save bloat is the lesser problem but is real: `campaign_state.gd:298-327` writes a flat ConfigFile with
**no pruning of `collapsed_tunnels`, `field_marks`, `pencil_marks` or `reported_marks`** — three
unbounded arrays already ship. `mission_log` is the ONLY array trimmed (`:278-279`, cap 40). Adding
per-village conduct history to a store with three unbounded arrays and one migration branch
(`_migrate`, `:383-384`, a `push_warning` and nothing else) is adding a fourth leak to a boat that is
already taking water.

### D.3 · Only the player can kill civilians. Feature or lie — decide.
`civilian.gd:18-21`: *"Layer 10. Its own layer, in the **PLAYER's** fire masks only — AI strays pass
through villagers. Widening it to the AI masks changes who gets shot and is a Summoner call, not a
silent one."*

The consequence is total: **no AI bullet can ever kill a civilian.** Not a VC stray, not a hunter
burst, not a garrison man returning fire. Every civilian death in this game, forever, is the player's.
(Blast is the one caveat — `combat_manager.gd:168` has a `spare_garrison` branch keying on
`is_garrison`, so explosive semantics differ from bullets; worth a separate read before anyone relies
on it.)

**As a design, this is a lie about the war.** The defining civilian-casualty experience of Vietnam is
that you frequently could not tell whose round did it. A world in which the player is the sole possible
author of every dead villager is a world with a **built-in confession**: he never has to wonder, never
gets to be wrong, and can never be blamed unjustly. That deletes the most interesting moral space the
setting offers.

**As an engineering decision, it is defensible and I will argue its side:** the alternative is AI
strays killing villagers at a rate no one has budgeted, feeding a consequence system, on a frame
already CPU-bound in the AI — and a player punished for a death he did not cause, in a game with no
meter to explain it, will correctly conclude the game is broken (ADR-019:106-107 names this exact
fear).

**But the council must RULE, not inherit.** My position: **keep the layer as-is for v1** and — this is
the load-bearing part — **stop writing design that assumes carelessness kills villagers.** ADR-019 §2
lists *"careless artillery and airstrikes"* as a HOSTILE input. **Check it against the mask before
costing it.** If indirect fire does not reach villagers either, that line of the ADR is fiction and
should be struck rather than left to mislead the next reader — the POINTER LAW applied to design
tables.

### D.4 · The garrison exclusion is correct, and it hides nothing — but it hides something else
`civilian.gd:630-638`: `_record_noncombatant_death` returns early `if is_garrison` (`:633`), then
early-returns again if not in group `"civilians"` (`:635`) — which catches the revealed informer, who
is dropped from the group by `_transform_to_vc` (`:654`) without going GONE.

**Both exclusions are correct.** A garrison man is a soldier by the 2026-08-04 decree; a revealed
informer is a combatant. The tally is exactly "noncombatants", as named.

**The real defect is one level up, and it is a naming fossil.** `is_garrison` men are ARVN/friendly
soldiers running in a class called `Civilian`, in a group called `"civilians"`, and the backlog already
convicts it: *"the demo ships soldiers in a class still NAMED Civilian — named sacrifice"*
(`DEMO_SHIP_BACKLOG.md:1113`), with the soldier-class migration deferred POST-DEMO. So:
- **Their deaths land in no ledger at all.** Not the noncombatant tally (excluded at `:633`), and not
  the squad KIA path that feeds `kia_total` / `bags_unlifted` / `ward_wounded`
  (`campaign_state.gd:255-266`), which reads `result["squad_kia"]` from `SquadSystem`, and garrison
  `Civilian`s are not squad members. **A friendly soldier the player shoots inside his own wire is
  currently free.** Not a hearts-and-minds bug — a casualty-ledger hole, and the casualty ledger is
  the decreed scoreboard (`recon-casualty-ledger-is-the-scoreboard`).
- **Any hearts-and-minds design that says "civilians" while the code says `group("civilians")` will
  silently include ARVN.** Write the predicate as `noncombatant`, never as the group name.

---

## E · SCOPE — how this eats the ship date

He said NOT demo scope. Here are the specific leaks, in the order I expect them:

1. **"We need a burnable hut for the fast road."** → ADR-031 P4 destructible world → the crater cost
   (`DEMO_SHIP_BACKLOG.md:1428-1432`: one dig = full 256m chunk rebuild, synchronous, suspected cause
   of his measured lag). **This single leak can eat the demo alone.** Hard no.
2. **"Villagers should react, so we need the atrocity reaction."** → BUG A → a real
   `on_atrocity_witnessed` on `Civilian` → new BT states → a class already at 38 KB with seven BT
   leaves (`DEMO_SHIP_BACKLOG.md:198, 566`) and a measured **~6.4 ms/frame at 16-40 heads**
   (`civilian.gd:214-218`). **Behaviour work on the civilian brain is a perf change, not a polish
   pass.**
3. **"Sentiment needs an AAR line."** → touches `debrief.gd` → the debrief screen only renders on
   FAILURE today (see §F). Fixing that is a loop change on the shipping bank path.
4. **"Per-village needs stable ids."** → ADR-017 generator indices → world-gen churn → the ADR-010
   determinism contract → the probe. **Nothing about this is small.**
5. **The subtlest leak: F-8.** `DEMO_SHIP_BACKLOG.md:1184` — *"F-8 Hearts & minds thin slice —
   `civilian.gd:4-7` hook counts one thing"* — is an **open, unchecked demo backlog item**, and his Q6
   ruling put it in the value order **F-1 → F-4 → F-8 (after demo fixes)**. So a hearts-and-minds item
   is *already inside the demo backlog*. This council will be read as authorising it. **Say
   explicitly whether F-8 is in or out; do not let it drift in.**

### The ONE hook worth laying now
**One `CampaignState.add_threat_modifier` call at `_bank_patrol` (`field_director.gd:1768-1791`),
derived from what the patrol left behind.** Justification, all verified: the store is saved
(`campaign_state.gd:305`), decays per mission (`:234-239`), is already consumed by the siege roll
(`siege_director.gd:191`) and fire support (`field_director.gd:1419`), and is already read by the
player as a word in two screens (`barracks.gd:45`, `main_menu.gd:97`). **It requires no new state, no
new save key, no migration, no UI, and no per-frame cost.** It is the only hook whose absence would
later force a retrofit, because it is the only one that determines *whether anything at all survives
the wire.*

### Gold-plating — name it and refuse it now
Per-village allegiance floats · a district manpower pool · base rebuild/relocation
(ADR-019 §1, ADR-017 §10) · allegiance-driven trap density · medcap/supply/tax-collector verbs ·
`ProvinceState` · civilian sentiment animation states · any AAR sentiment line that needs new plumbing.
**Every one of these is main-game. None of them changes what he plays this month.**

---

## F · THE BUGS — one is oversold, one is the real find

### BUG B (`_bank_patrol` drops `civilian_deaths`) — **oversold. Fixing it changes NOTHING observable
today.** I traced every consumer:

- Producers: `civilian.gd:622 _die` → `:630 _record_noncombatant_death` → `field_director.gd:88
  record_noncombatant_death` → `mission_state.gd:26 record_civilian_death`. Live.
- `mission_state.gd:18-23` deliberately keeps the key out of `_base_result` (`:143-159`) — confirmed,
  the key is absent from that dict.
- `fail_mission` re-adds it by hand (`field_director.gd:210`). `_bank_patrol` does not
  (`:1768-1791`). Both confirmed.
- **`compute_score` (`debrief.gd:32-42`) reads exactly six keys:** `contacts_avoided`,
  `contacts_detected`, `damage_taken`, `time_sec`, `success`, `pow_lost`, plus `_ghost_bonus`.
  `_ghost_bonus` (`:19-21`) reads only `shots` and `success`. **`civilian_deaths` is read by neither.**
- **`CampaignState.on_mission_end`** (`:227-280`) reads `kills`, `success`, `is_anti_aa`, `aa_killed`,
  `squad_kia`, `friendly_wia`, `mission_type`, `seed`. **Not `civilian_deaths`.**
- The **only** consumer repo-wide is `debrief.gd:89-90`, the AAR line. Confirmed by
  `grep -rn "civilian_deaths" scripts/` → 5 hits total, all accounted for above.

**And there is a second, deeper reason the fix is inert.** `_bank_patrol` **never shows a debrief
screen.** It calls `DebriefScreen.compute_score(result)` statically (`field_director.gd:1774`) and
toasts. The `DebriefScreen` node is constructed only in `game_flow.gd:459`, reached from
`_on_mission_ended` (`:434`), which is connected to **`director.mission_failed`** only
(`game_flow.gd:670`). **The screen that would print "NONCOMBATANTS KILLED: N" only ever renders when
the patrol failed — and on failure `fail_mission:210` already copies the key.**

> **Precise verdict: copying `civilian_deaths` into `_bank_patrol`'s result changes zero observable
> behaviour. Not the score, not the campaign, not the save, not one pixel.** It is a correctness fix
> for a future consumer, and it is worth doing for that reason and no other — but any argument that
> hearts-and-minds is "blocked" on it is false. **The real gap is that a successful patrol has no
> debrief surface at all**, which is a much bigger and much more interesting finding than the missing
> key, and it is the thing that actually blocks ADR-019 §4's sanctioned sentiment line.

### BUG A (`on_atrocity_witnessed` is a permanent no-op) — **this one is real, and it is worse than
the briefing says.**
`player.gd:249-250` calls it behind `has_method`; `grep -rn "on_atrocity_witnessed" scripts/` returns
**two hits, both at that call site, zero definitions.** The guard is never true.

The briefing's precision point is correct and I will sharpen it. Read `player.gd:242-252`: the loop
finds a villager within `EAR_WITNESS_M`, calls the method that does not exist, **fires
`_field_toast("THEY SAW YOU DO THAT")` unconditionally, and `break`s.** So:
- The toast **always** fires when a villager is in range.
- The comment two lines above it (`:243-244`) asserts *"A villager who SEES this remembers it.
  ADR-019 governs the reaction"* — **a comment stating a system that has never run.** A tombstone for
  a corpse that was never born. This is precisely the fossil shape ADR-023 exists to kill, and
  precisely the drift the CLAUDE.md comment-discipline section says camouflages fossils.
- **The player has been told "THEY SAW YOU DO THAT" for weeks, and nothing has ever seen anything.**

**This is load-bearing for the council in one specific way:** it is the project's only existing
*attempt* at a conduct→villager reaction, it is the shape the whole ADR-019 design wants, and it has
been silently dead. **That is the single best argument that the invisibility trap (§B) is not
hypothetical — a no-op ran in this game for weeks behind a toast and nobody, including the Summoner,
noticed.** If a system that does literally nothing is indistinguishable from a working one, the
council must explain what makes the *next* one distinguishable.

---

## G · TWO SYSTEMS SAYING THE SAME THING (the fossil-law-as-design objection)

The cord tokens (`production/PARKED_cord_tokens.md`, PARKED 2026-08-05) are an
innocent→ears→Buddha moral-descent arc, read at the pause screen, riding the existing body-search
verb. ADR-019 is a moral-consequence arc, read through the world.

They are **not** duplicates, and I will not pretend otherwise: the cord is *what the player became*;
allegiance is *what the world became*. They face opposite directions.

**But they share one input — the ears — and that is where they collide.** `ears_taken` is already a
saved campaign counter (`campaign_state.gd:80, :319`). If ear-taking both fills the cord AND moves
allegiance, then a single act pays into two moral ledgers, and the player experiences it as
double-dipping the moment he notices — or, more likely, as noise, because neither ledger is legible.

**Ruling I would force: ears feed exactly one system.** My preference is the cord, because the cord is
*attributable* (he can look at it) and allegiance is not — and because ADR-019's own §4 forbids
allegiance from being lookable. **Sacrifice: the most morally loaded act in the game stops moving the
war**, which is a genuine loss and must be stated as one.

---

## H · WHAT EVERY POSITION SACRIFICES — the summary the Arbiter needs

| Position | Sacrifices |
|---|---|
| **Build on `ProvinceState` (ADR-019 as written)** | Ships in 2027 or never. 24 days of zero is the evidence. Requires the ADR-017 determinism probe, stable ids, save migration first. |
| **Build on `CampaignState` alone** | Per-village granularity, forever-until-ProvinceState. One number cannot say "this ville hates you." §2's table becomes a per-AO table and ADR-019 needs a written amendment. |
| **Strengthen + NAME what exists (my recommendation)** | The system stops being about *conduct* and becomes about *noise* — it cannot tell a war crime from a firefight. Risks ADR-019 being falsely marked done. |
| **Keep the fast road paying (§3 as written)** | Arson becomes a dominant strategy, because the payoff is visible and §4 guarantees the cost never is. |
| **Make the cost legible** | Direct §4 violation. The meter returns and the moral weight evaporates. |
| **Keep allegiance invisible (§4 as written)** | Near-certain non-perception. ADR-018:88-91 already convicted this bet, and BUG A proves a no-op survives here undetected. |
| **Perceptible tells (villagers indoors, named barks)** | Ambiguity — the tell is near-binary, and a binary is one step from the meter §4 forbids. |
| **Widen the civilian hurtbox to AI masks** | Unbudgeted civilian deaths on a CPU-bound frame, and a player punished for a death he did not cause with no meter to explain it. |
| **Keep the hurtbox player-only** | Every civilian death is a confession. The war's defining ambiguity is deleted, and ADR-019 §2's "careless artillery" line becomes fiction. |
| **Ears feed the cord only** | The game's most loaded act stops moving the war. |
| **Ears feed allegiance too** | Two ledgers, one act, neither legible. The fossil-law-as-design objection lands. |

---

## I · THE THREE THINGS I WOULD REFUSE TO LET PASS TODAY

1. **A design that names `ProvinceState`.** If the word appears in the synthesis without a schedule
   for ADR-017's determinism gate attached to it, the synthesis is a wish.
2. **An acceptance test softer than "he names the place, unprompted."** ADR-019:104 already promised a
   one-playtest gate; without a sentence he must say, that promise is unfalsifiable and the system can
   never be convicted of failing.
3. **Any weighting table over verbs that do not exist.** Arson: no verb. Medcap: no verb. Supply: no
   verb. Tax collector: no verb. Detain: no verb. **Four live inputs exist** — civilian deaths, bodies
   left, gunfire near a ville, ears taken. Design over those four or admit the document is fiction.
