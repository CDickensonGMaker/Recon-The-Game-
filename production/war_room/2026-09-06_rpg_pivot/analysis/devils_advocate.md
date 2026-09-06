# DEVIL'S ADVOCATE — the RPG / STALKER-in-Vietnam reframe

**Session:** 2026-09-06 · **Charter:** name the specific ways this decree fails. No free lunches.
**Rule I hold myself to:** an attack without a test is an opinion. Every section below ends in a
named probe, a named measurement, or a named question for the Summoner.

**What I read:** GAME_GUIDE §1/§6/§8 · ADR-006 · ADR-015 · ADR-019 · ADR-028 · ADR-029 +
Amendments B/C + the 008/006 amendments · ADR-032 · DEMO_SHIP_BACKLOG (head + open sections) ·
DEMO_TIGHT_40 · PLAYTEST_FINDINGS_2026-08-28. Code claims are measured, file:line, this session.

---

## 0 · The one measurement that reframes the whole council

Before anything else, three numbers that nobody in this session has put next to each other:

| Fact | Source |
|---|---|
| Player walk speed **5.0 m/s**, sprint **8.0 m/s** | `scripts/player/player.gd:12-13` |
| Firebase compound half-extents **149.3 × 111.2 m** | `scripts/world/site_planner.gd:809` (`FSB_HALF`, "model space, measured") |
| Village at **185 m** from firebase centre; temple at **170 m** | `scripts/missions/mission_generator.gd` `plan_demo_world` (village `v_dir * 185.0`, temple `t_dir * 170.0`) |
| Night falls **~1184 s**; probe **1395 s**; assault **1440 s** | `scripts/levels/demo_game.gd:46,58,59` |

The compound's own footprint is 149 m in one axis and 111 m in the other. **The village and the
temple sit between roughly 36 m and 74 m outside the firebase perimeter.** The two "quests out the
wire" are, geometrically, a stroll to the end of the street.

The two bearings are `out_v.rotated(±2.35 rad)` — that is 4.70 rad apart, i.e. **90.7° of
separation, not 180°**. The "opposite flank" framing in the briefing is wrong by 90 degrees. Chord
village→temple = √(185² + 170² − 2·185·170·cos 90.7°) ≈ **253 m**.

**The full two-quest circuit, straight-line:** spawn→village ≈ 185 m, village→temple ≈ 253 m,
temple→back inside ≈ 170 m. **≈ 608 m.** Apply a generous ×1.4 for jungle, terrain and detour:
**≈ 850 m.** At WALK_SPEED that is **170 seconds**. At a *cautious* effective 2.5 m/s — crouching,
stopping, fighting — it is **340 s ≈ 5.7 minutes.**

Dusk is at 1184 s. **The walk consumes 9–29% of the pre-dusk window.**

Hold that number. It falsifies the premise of item 3 and it changes what item 8 is competing with.

---

## 1 · THE HONEST QUESTION NOBODY WANTS ASKED

### 1a · The case that recording this decree IS the risk

Lay the pivots end to end and look at the dates, not the content:

| Date | Reframe | What it superseded |
|---|---|---|
| 2026-07-12 | THE SLICE — one province, three mission types, allegiance, rank (GAME_GUIDE §6.0) | the operations layer |
| 2026-07-17 | THE OPEN PATROL SIMULATOR (ADR-029) — briefing deleted, no mission tracking, PATROL is the only type | §6.0's three mission types, ADR-008's TOC, ADR-006's payout moment |
| 2026-08-06 | THE DEMO'S SHAPE IS THE PRODUCT (GAME_GUIDE §8) — "**This supersedes §6.0's 2026-07-12 slice**… That target is now the roadmap, not the product" | ADR-029's own identity, which "ships as ROADMAP" |
| **2026-09-06** | RPG / STALKER-in-Vietnam; firebase-as-home; four factions; H&M is the senior system; ADR-006 retired; contraband replaces points | ADR-006, and by implication ADR-032's faucet and ADR-019's §4 presentation |

That is **four reframes in 51 days**, each one written down as canon, each one superseding the last
one's canon. The GAME_GUIDE §8 header says it out loud about the previous cycle: *"Every item on it
was written for a game that shipped nothing on a date."*

Now the damning detail. **2026-09-06 is not a neutral day to reframe.** It was the EA target
(GAME_GUIDE §8 THE TARGET: "STEAM EARLY ACCESS, 2026-09-06"). The gate that discharges the target
is §8.0: *"THE DEMO PLAYTHROUGH is the session entry gate… Nothing new ships until the Summoner
verifies the arc end to end."* **That gate has never been discharged.** GAME_GUIDE §8.0 itself notes
the pattern with the previous gate: *"PLAYTEST R4… was never discharged, in 30 documents."*

So the honest structure of today is: *the ship date arrives, the gate is undischarged, a
35-item defect list from the last real playtest is still open — and a new destination is named.*
That is not a coincidence you can rule out from the inside. ADR-015 exists precisely because this
project has measured its own law-half-life at **two hours** and its own tendency to record work as
done that was not done. **The failure mode ADR-015 was written against is recording, not building.
This decree is a recording.**

The mechanism by which a recorded decree moves a ship date without anyone deciding to move it:

1. It creates a **new frame of reference for "good."** Every subsequent judgement of the demo is now
   made against "does this feel like an RPG/STALKER" rather than "does the arc run end to end."
2. It **retroactively devalues finished work.** ADR-006 is retired today; ADR-032 was built on it
   ten days ago (§7 below). Work that was canon-compliant last week is now legacy.
3. It supplies an **honourable reason to not do the boring thing.** "The playtest list" is 35 items
   of bunker colliders and T-posed medics. "The RPG pivot" is the fun conversation. Nobody has to
   choose against the list; the list simply never comes up.
4. Precedent: the 2026-08-06 reframe explicitly killed the 2026-07-10 build order *because* that
   order was written for a game that shipped nothing. The reframes have a track record of eating the
   build orders, not the other way round.

### 1b · The strongest counter-case

- **It costs zero art-days and zero code today.** GAME_GUIDE §8.1 makes the art-day/code split the
  planning axis; a document costs neither. The Summoner named the constraint himself and it is the
  last sentence of his message: *"but the demo scope is still the overall goal."* That sentence is
  itself the scope wall, spoken by the only person with authority to move it (Law 3).
- **The systems were already walking there.** The firebase is already home
  (`FieldDirector` wire gate, `_bank_patrol` at the wire, `SLEEP_POST_LAUNCH` parked but built).
  The garrison already has occupations and roles (`garrison_defender.gd:104-107` carries
  `garrison_occupation` / `garrison_role` across stand-to). ADR-019 already says allegiance is
  *felt, never read.* "Four factions who talk to you" is not a new system so much as **a
  presentation answer to ADR-019's §4 problem the ADR itself admitted it had no answer to.**
- **Zone-not-streaming, save-anywhere, tunnels-as-dungeons, extended DOWN** — every one of these is
  already named in ADR-013 (≤2 km loads whole), ADR-007, GAME_GUIDE §6 FROZEN, and the existing
  health/down code. None is a new direction; each is an *unfreezing schedule.*
- **The alternative to writing it down is worse.** An unrecorded destination does not go away; it
  leaks into build decisions as unspoken preference, which is exactly the drift ADR-014 and the
  fossil law exist to stop. A written ADR marked POST-DEMO can be *cited against* a leak. An
  unwritten one cannot.
- **A fourth reframe on the EA date is also just… a founder looking at a video and having a good
  idea.** That is not a pathology. It is a pathology only if it moves the build.

### 1c · What I actually believe

**Both, and the split is clean.**

The *content* of the reframe is genuinely low-risk and probably correct — it is a naming of a
destination the code already faces, and it costs nothing on the day. **I do not believe the decree
is the risk.**

**I believe the DATE is the risk, and the decree is its alibi.** The specific thing I would bet
against is not "the pivot pulls work forward." It is that **this council is the day's work
product** — that 2026-09-06 ends with a synthesis, seven new ADRs and zero of the 35 playtest items
closed, and that nobody ever says out loud "we did not ship today, here is the new date."

**Therefore: record the decree, and make the record carry a cost.** Any synthesis that ships today
must contain, in the same document, (a) the honest statement that the EA target passed undischarged,
(b) a named new date or an explicit "no date, and here is what discharges the gate," and (c) the
count of playtest items closed today. **A reframe recorded without those three lines is the fourth
pivot doing what the first three did.**

**Test that settles it:** at the next session open, run `git log --since=2026-09-06 --stat` and
count lines changed under `production/` versus under `scripts/`. If `production/` dominates by more
than 5:1, the reframe was the work, and this section was right.

---

## 2 · THE SCOPE WALL WILL LEAK — the specific mechanisms

"Record as canon, build nothing" is a policy with no enforcement surface. GAME_GUIDE §6 already has
the enforcement idiom — **"A frozen epic thaws only by explicit decree — a bead in `bd ready` is not
a thaw"** — and it still needed the parenthetical *"Tunnel MOUTHS you mark and satchel are IN SCOPE
TODAY"* to stop tunnels leaking. That parenthetical is the shape of the leak: **a post-demo system
whose cheap half is already legal.**

### The five leaks, ranked by how soon they happen

**Leak 1 — THE EXTENDED DOWN STATE. Leaks first, and probably this week.**
It is the only post-demo item on the list that is *pure code, small, and reads as a bug fix.*
`BodySwapSystem` already owns the death moment (`body_swap_system.gd:38-51`), already has a
`BLACK_SECONDS` window, already has a god-mode re-entry guard. Extending DOWN is ~30 lines inside a
file that is already open for §7 reasons. It will arrive labelled "death feel," which is
**exempt under GAME_GUIDE §9 GATE-bead exemptions ("presentation for shipped systems")**, and no
law will have been broken.
- *The sentence that lets it:* any ADR line reading "the extended DOWN state replaces a larger
  health pool." "Replaces" is a *substitution*, and a substitution reads as a change to a shipped
  system, not a new feature.
- *Mitigation:* the post-demo ADR must say **"the current DOWN behaviour is CORRECT for the demo and
  is not to be touched"**, naming `body_swap_system.gd` and `health_system` as frozen files. Freeze
  the file, not the feature — the file is checkable.
- *Test:* `git diff --stat` on those two paths at each session close; non-zero = a thaw happened
  without a decree.

**Leak 2 — SAVE ANYWHERE. Leaks second, disguised as a P0 bug fix.**
GAME_GUIDE §8.1 item 2 (STOP THE BLEEDING) already orders atomic saves, future-version rejection,
and the demo save-dir leak. That work opens `save_manager.gd` legitimately. Once you are inside the
save manager fixing a corruption class, "and while we're here, allow a save outside the wire" is
one guard clause. ADR-007 governs slots and checkpoint economy, so the change even has a home.
- *The sentence that lets it:* "save-anywhere is the post-demo save model" — because it names a
  *model*, and the demo's `EXCLUDE_SAVES := true` (`demo_game.gd:25`) means the demo has no save
  model to conflict with. There is nothing for the new model to violate.
- *Mitigation:* the ADR must state **"ADR-007's tiers/slots stand unchanged through EA; save-anywhere
  is a POST-EA amendment to ADR-007 and is not to be implemented behind a flag."** The words
  *behind a flag* matter — a dormant flag is how `SLEEP_POST_LAUNCH` ended up built-and-parked, and
  that precedent is now the project's normal.
- *Test:* grep for a new `const .*_POST_LAUNCH` or `SAVE_ANYWHERE` constant. One is a parked system.

**Leak 3 — THE FOUR FACTIONS. Leaks third, and this is the dangerous one, because it is the ONE
item that is arguably demo-scoped already.** See §5. The four factions are the *readout* for the
senior system; the men are already in the world with occupations and roles
(`garrison_defender.gd:104-107`); the [F] verb ladder in `player.gd:606-660` is a hardcoded chain
that anyone can add a branch to. "Two lines of barks per faction" is a two-hour job and reads as
atmosphere, which is Pillar 2, which is never gated.
- *The sentence that lets it:* "the factions are the readout, and they cost no new UI." **A claim
  that something costs nothing is a permission slip.** It is the single most load-bearing sentence
  in the whole synthesis and it should be treated as the highest-risk sentence in it.
- *Mitigation:* name the honest cost. There is **no dialogue system in this codebase** — verified:
  `grep -rli "dialogue" scripts/` returns **zero files**. There is no conversation, no topic tree,
  no offer presentation. The only NPC-speech surface that exists is the toast bus and barks. "Zero
  new UI" is true only if the four factions speak entirely in one-line toasts, which is a design
  constraint, not an absence of cost — and it should be written as a constraint in the ADR.
- *Test:* `tests/probe_no_dialogue_system.gd` — assert zero files under `scripts/` matching
  `dialogue|conversation|topic_tree`. It stays green until someone builds the thing nobody costed.

**Leak 4 — TUNNELS AS DUNGEONS.** Lowest immediate risk (GAME_GUIDE §6 already fights this fight
explicitly and won), but the highest *magnitude* if it goes. `scripts/world/tunnel_room.gd` already
exists; `player.gd:617-620` already has `[F] CLIMB OUT` and `[F] SEARCH THE CACHE`. **There is
already a tunnel interior.** The thaw is not "build tunnels," it is "add a second room" — and the
first person to add a second room will not feel like they thawed anything.
- *Mitigation:* the ADR restates §6's existing sentence verbatim and adds a countable bound: **"the
  tunnel interior is ONE room. A second `TunnelRoom` instance in a single world is a thaw."**
- *Test:* `tests/test_patrol_world` asserts `get_nodes_in_group("tunnel_rooms").size() <= 1` in the
  demo world build.

**Leak 5 — THE 2 km MAP / ZONES + HUEY BOARDING.** Least likely, because ADR-013's ≤2 km-loads-whole
rule and the 512 m `plan_demo_world` are load-bearing on perf and everyone knows it. But note
ADR-029 §6 already parked helicopters, and PLAYTEST_FINDINGS item 5 has the player *watching a Huey
fly off*. The Huey exists, flies, carries pax (`heli_lift.gd`). "Board a Huey to reach another
place" is closer than it looks.

### Does writing the ADRs actually stop the competition, or pull work forward?

**Both, and which one you get depends entirely on one authorial choice.**

An ADR written as **"here is the destination"** pulls work forward. It gives every subsequent
decision a direction to lean, it makes the destination feel designed (therefore near), and it
supplies a citation for any leak: *"ADR-0xx says the factions are the readout, so adding a bark is
compliant."* **Citability is the pull mechanism.** ADR-019 is the proof: it has sat since 2026-07-12
with a STATUS NOTE reading "NOT implemented… deferred to post-launch," and it has nonetheless been
the direction every H&M conversation leans toward for two months.

An ADR written as **"here is the destination AND here is the named file that must not change before
the gate"** does stop the competition, because it converts a preference into a diffable fact.

**So my answer to the Overseer's intent: writing them down works, but only if every post-demo ADR
carries a FROZEN FILES section naming paths.** A post-demo ADR without frozen paths is a wish, and
ADR-015 already measured the half-life of a wish at two hours.

---

## 3 · THE TWO-QUEST DESIGN — attacked with the clock

### 3a · The premise is inverted. There is no walk budget problem; there is a dead-air problem.

Per §0: the full two-quest circuit is **~850 m of real walking ≈ 170 s at walk speed, ~340 s at a
cautious 2.5 m/s effective pace.** Night is at **1184 s**. Stand-to and the probe are at **1395 s**.

| Player | Circuit time | Time standing around before dusk |
|---|---|---|
| Sprints, no contact | ~110 s | **~18 minutes** |
| Walks, no contact | ~170 s | **~17 minutes** |
| Cautious, two firefights | ~340–500 s | **~11–14 minutes** |
| Very slow, pinned repeatedly, explores all 3 extra ruins + the camp | ~800 s | **~6 minutes** |

**"Timed so the player returns at dusk" is not a design; it is a description of the fact that there
is nothing else to do.** The player does not return at dusk because the quests take until dusk. He
returns at whatever time he finishes and then waits. The brief's stated worry — "what if he is fast
and stands around for 8 minutes" — is not the edge case. **It is the median case, and it is nearer
15 minutes than 8.**

That reframes the whole item. The correct question is not *"do two quests fit before dusk"* — they
fit four times over. It is **"what does the player do for the fourteen minutes after they are done?"**
And the current answer is: hunter teams, which the demo already caps at
`_hunter_pool = maxi(_hunter_pool, 6)` (`field_director.gd:1454-1456`), with the code's own comment
naming this exact failure — *"12 men at 2-4 a wave is ~7.7 minutes of contact and then an empty AO
for the rest of a 30-minute day."* The comment says the problem is already known and the fix was to
raise the pool. **Two short quests do not fix dead air; they consume 3 minutes of a 20-minute window
and make the remaining 17 minutes more conspicuous by giving the player a reason to think he is
finished.**

- **Mitigation:** either the quests must be *far* (they cannot be — the map is 512 m and the compound
  is 298×222 m of it, `site_planner.gd:809`) or they must be *slow* (a hold, a search, an escort, a
  dig — something that spends real seconds without spending metres), or the arc must move. Of these
  three, **"slow" is the only one that fits inside the shipped world**, and it is the one design
  question worth taking to the Summoner today.
- **The measurement that settles it:** `tests/probe_demo_walk_budget.gd` — boot `plan_demo_world` at
  `DEMO_SEED`, print gate→village, village→temple, temple→gate ground distances along the navmesh
  (not straight-line), and divide by 5.0 and 2.5. **Print the resulting idle window against 1184 s.**
  This has never been run. Everything in this section is arithmetic on placement constants and
  deserves to be replaced by a navmesh number.

### 3b · Two quests = two excursions = the wire ceremony fires twice

Real, and mechanical. `_poll_wire_gate` (`field_director.gd:1425-1472`) is a latch on
`patrol_out`, using `d = min(dist to gate, dist to compound centre)` with **out at 120 m, in at
95 m.** Crossing outward runs `_pick_patrol_location()` — **ONE selector**, per ADR-029 Amendment C
§4 clause 4 — and increments `patrol_count`, calls `CampaignState.begin_mission()`, and grants fire
support. Crossing inward runs `_bank_patrol()` (`field_director.gd:2040-2075`).

Two quests can be built two ways and **both have a named cost:**

**(A) Two walk-outs (village, come home, temple).** Then `_bank_patrol` runs **twice** in one demo:
`patrol_count` reads 2, the state ledger is reset and re-created (`state = MissionState.new()` at
`:2074`), `_read_the_dead` runs twice, `_call_replacements` runs twice,
`CampaignState.on_mission_end` moves escalation twice, and the player sees "BACK INSIDE THE WIRE —
PATROL 1 LOGGED" then "PATROL 2 LOGGED" in a **one-day demo whose fiction is a single patrol.**
Fire support does *not* double — `_grant_fire_support` is latched on `_granted_day`
(`field_director.gd:1490-1492`) and the demo hard-overrides to 3 bombing runs (`:1524-1529`) — so
that exploit is closed. But **the AAR fires twice, and Amendment C's ground-covered grade is
computed per-bank, so the second patrol's grade is measured against a fresh ledger.**

**(B) One walk-out, both quests, come home once.** Cleaner, and the machinery already supports it:
`_advance_route_tasking` re-tasks the sweep onto the living feature nearest the next mark, and the
code comment at `:1222` says outright *"One walk-out may finish many sweeps and still banks"* once.
**This is the correct build and it costs nothing new.**

- **Recommendation:** rule (B) explicitly, today, in one sentence, or the first person to build this
  will build (A) because (A) is what "two quests" sounds like.
- **Test:** `tests/test_patrol_contract` gains an assertion: **one demo run, one `_bank_patrol` call.**

### 3c · What if he refuses both? Is the demo empty — and does forcing him breach Pillar 3?

**He cannot meaningfully refuse, and that is the actual answer.** Under ADR-029 §4 there is no offer
and no accept: crossing 120 m *is* the acceptance, and `_pick_patrol_location` picks *for* him. If
the quests are given by named NPCs before he leaves, then "refuse" means "walk out anyway," and the
wire gate still fires, still picks a location, still barks. **The demo is not empty on refusal; it
is exactly the demo that exists today.** Which is the real finding: **the two-quest design's downside
case is the shipped demo, so its value is entirely in its upside, and its upside is 3 minutes of
walking.**

Forcing him would breach Pillar 3 ("Nothing is on rails. Ever.") and ADR-029 §4 ("No player-facing
mission tracking, ever"). But nobody needs to force him, so this is a non-issue **provided the ADR
does not add a gate**. The specific sentence to forbid: *"the night attack begins once both quests
are complete."* That is a rail, it is exactly how a designer would "fix" the timing problem in §3a,
and it would be the first rail in the project's history.

- **Test:** `tests/test_patrol_contract` clause 5 (new): **`SIEGE_AT_S` and `PROBE_AT_S` are read
  only from the arc clock; no quest/objective state may appear in their condition.** Assert by
  running the demo headless with zero quests touched and confirming the siege still fires at 1440 s.

### 3d · What if he dies out there at 900 s — a live, un-decreed defect this design makes likely

**This is the most concrete find in my analysis and it is not hypothetical.**

`BodySwapSystem._pick_pool()` (`body_swap_system.gd:56-69`) draws the lives pool from the node group
`garrison_promoted`. That group is populated **only** by `GarrisonDefender.promote()`
(`garrison_defender.gd:100`), which is called only from `FieldDirector._stand_to()`
(`field_director.gd:1775`). The file's own header comment states it: *"The pool is picked ONCE from
the promoted garrison (they exist from stand-to; a death before any man stands to is a real KIA)."*

Stand-to happens at night / on alarm. **A death at 900 s is before stand-to.** So:

1. `_pick_pool()` finds **zero** candidates.
2. **`_picked = true` latches on line 57, before the candidate scan.** The pool is now permanently
   empty for the run — even after the garrison stands to at 1395 s.
3. `try_swap()` returns false, `_on_demo_death` fires (`demo_game.gd:570`), end card
   **"YOU FELL BEFORE DAWN"** at T+15 min. **The player never sees the siege — the thing the whole
   demo is built to deliver.**

The documented lives economy (4 men, ruled 2026-08-24) **does not exist during the entire daylight
half of the demo.** And the two-quest design's entire purpose is to put the player *outside the
wire, in contact, during exactly that window.* **It multiplies the exposure to a defect that is
already live and undiscovered.**

Second-order, if the pool *were* populated: `_nearest_living()` (`:72-83`) picks the nearest pool
member, and pool members are garrison men **inside the compound**. A death at the temple, 250 m out,
would wake the player inside the wire mid-quest with `patrol_out` still true and someone else's
weapon — an unintended teleport home that silently voids the excursion.

- **Mitigation A (correctness):** move `_picked = true` to *after* the candidate scan, and only set
  it if `candidates.size() > 0`. One line. Or draw the daylight pool from the player's own squad.
- **Mitigation B (design):** this is a Summoner call — is a pre-stand-to death meant to be a real,
  final KIA? The comment says yes. If yes, **the two-quest design must be judged knowing that the
  demo's daylight half is one-life and its night half is four-life**, and nothing tells the player.
- **Test:** `tests/probe_daylight_death.tscn` — boot the demo, force `player.health_system` death at
  T+900 s, assert whether `BodySwapSystem.try_swap()` returned true and print
  `get_nodes_in_group("garrison_promoted").size()`. **This probe has never been written and I would
  run it before any other item in this synthesis.**

### 3e · What if he is still outside the wire at 1395 s?

The siege aims at `fsb_center` — "the bench, just inside the wire" (`field_director.gd:1150`). The
probe and the assault fire on the arc clock (`demo_game.gd:447,451`), unconditionally. A player 250 m
out in the dark at the temple experiences **the demo's climax as distant noise and a toast.** The
`END_BACKSTOP_S` at 2700 s (`:74`) is generous enough that he can walk back, but he will arrive
mid-assault into a fight already resolving.

- **Test:** `tests/probe_late_return.tscn` — teleport the player to the temple at 1350 s, run to
  `siege_ended`, and print whether the end card fired with the player having ever been within
  `GARRISON_ALARM_M` (120 m) of the wire. If the demo can end with the player never in the fight,
  that is a shipping defect regardless of the pivot.

---

## 4 · QUEST GIVERS RE-GROW THE THING HE KILLED

### The case, made as strongly as I can make it

ADR-029's decree is verbatim: *"Remove the whole briefing part of the game. The game itself is an
open simulator with no mission tracking that the player needs to worry about."* §7 deletes "the
briefing/offer/select/exfil-bird chain… under ADR-023 with a save-schema migration." The 008/006
amendment deletes "the legacy select→briefing menu wire."

**An offer board is: a place you go, a set of enumerated tasks, and an act of selection.** Two quests
from two named NPCs at the firebase is *a place you go, a set of enumerated tasks, and an act of
selection.* The only differences are (a) the offers are spoken instead of listed and (b) there are
two of them instead of four. **Neither difference is structural.** It is the offer board with a face
on it.

### The slippery slope, named step by step — each step is small and each is defensible

1. **Two named NPCs give two tasks.** Diegetic, no UI. Legal today.
2. *"I forgot which one the sergeant said."* → **the task is repeatable on the [F] verb.** Still
   diegetic. Still legal.
3. *"I still forget once I'm 200 m out."* → **the task echoes on the radio net.** Amendment C §4
   clause 2 permits command tasking over the net. Still legal.
4. *"I can't tell if I did it."* → **a completion bark.** Reasonable. But a completion bark **is a
   waypoint checking off** — Amendment C §4 clause 1: *"waypoints never check off."* **First
   clause broken. Nobody notices, because it is a voice line, not a pin.**
5. *"Which quest was which?"* → **the topo map circles both.** ADR-022's grease circle is one
   circle for one selector. Two circles from two givers = **two selectors** — Amendment C §4
   clause 4 broken.
6. *"How many are left?"* → **an objective counter.** ADR-029 §4 broken, ADR-029 Amendment B's
   line ("world verb legal, objective counter not") broken. **The briefing screen is back, in
   pieces, and every piece arrived as a usability fix.**

**Step 4 is the tripwire and it is only three reasonable requests deep from step 1.** Nobody in
that chain does anything wrong.

### The specific sentence that would authorise all of it

Anything of the form *"the quest givers are diegetic, so the §4 clauses do not apply."* Diegesis is
about **presentation**; §4's clauses are about **information**. A voice that tells you a waypoint
checked off has broken clause 1 as thoroughly as a checkbox would. Any post-demo ADR that leans on
"diegetic" as its compliance argument has already lost this.

### The test that catches it

**Extend `tests/test_patrol_contract` with three assertions, not one:**

1. **Clause 1 (checkoff):** after a scripted quest completion, assert **no toast, bark, or map layer
   changes state as a function of quest completion.** The way to make this checkable is to require
   quest state to live in one named object and assert that no UI node reads it — a
   `test_only_liveness` style reference sweep.
2. **Clause 4 (one selector):** assert `_pick_patrol_location` is called **exactly once per
   excursion** in a two-quest run, and that `patrol_location` holds exactly one Vector3 at any time.
   This is the single strongest structural guard — the moment two quests need two live locations,
   the probe goes red and the leak is visible on the day it happens, not three ADRs later.
3. **Clause 2 (ground covered / no in-field HUD):** already probed; extend to assert no quest string
   reaches `mission_hud`.

Combined with §3b's "one `_bank_patrol` per demo run," that is four cheap assertions that make the
whole slope diffable. **These cost less to write than this section cost to read.**

---

## 5 · FACTIONS-AS-READOUT — attacking "zero new UI"

### The claim under test

That four faction voices at the firebase solve ADR-019's problem — *"If the player cannot feel it
through the world within one playtest, the presentation has failed — and the fix is more world,
never a meter"* — at zero UI cost.

### Attack 1 — the honest cost is not zero, it is a system that does not exist

`grep -rli "dialogue" scripts/` returns **zero files**. There is no conversation system, no topic
tree, no offer presentation, no NPC speech surface beyond the toast bus and barks. The interact verb
is a **hardcoded if-ladder** at `player.gd:606-660` — sleep rack, MG, tunnel, handset, shrine, tunnel
mouth, medic, gunner. Every faction voice is a new branch in that ladder plus a new speech surface.

**"Zero new UI" is only true if all four factions speak exclusively in one-line toasts.** That is a
real and probably correct constraint — but it must be written as a constraint, not celebrated as an
absence of cost. Because the moment someone wants two lines, they build a dialogue box, and a
dialogue box at the firebase **is** the briefing screen (§4).

### Attack 2 — what if he never talks to them?

Then H&M has **no readout at all**, and ADR-019's r4bk exemption becomes indefensible. ADR-019 §4
already accepted "a deliberate, narrow r4bk violation," justified because *"the affordance is the
world itself."* Faction voices are **not** the world itself — they are an opt-in verb behind a
keypress at a location. **A readout you must seek is weaker than the world-affordances ADR-019 named**
(the ville that goes silent; the wired trail; the point man's line). Those are unmissable. A
sergeant by the TOC is missable, and in a 30-minute demo with 17 minutes of dead air the player will
still probably miss him, because there is nothing telling him the man is worth talking to.

- **Mitigation:** at least one of the four factions must speak **unprompted** — a bark on proximity,
  not on [F]. That is the only version that inherits ADR-019 §4's justification.
- **Test:** fresh-player protocol (DEMO_TIGHT_40 step 37, already his law, already unrun). One
  20-minute run by someone who knows nothing; **ask them afterward what the men thought of them.**
  If they cannot answer, the readout failed. This is the only test that can settle it and it costs
  one person and 20 minutes.

### Attack 3 — noise, contradiction, and nagging

Four voices reading one hidden number will read as **four different opinions**, which is either
noise (the player learns nothing) or contradiction (HQ says one thing, the burnouts another).
Contradiction is *good drama* and *bad instrumentation*, and ADR-019 needs instrumentation — its
whole named failure mode is *"A player who burns three villes in hour two and gets mauled in hour
nine may simply conclude the game is broken."* Four contradictory readings make the game *more*
likely to read as broken, not less, because the player cannot triangulate.

And a voice that fires every time you walk past becomes **nagging** — the single most common
complaint about companion barks in every game that has them.

- **Mitigation:** the four factions must not be four independent readings of one number. They should
  be **one reading, refracted** — the same fact, four attitudes toward it. "The villes down south
  won't talk to anyone since you came through" said with satisfaction by one faction and with dread
  by another is one datum and two characters. Four *different facts* is noise.
- **Test:** write the four lines for one province state and read them aloud. If a player could
  construct four different beliefs about the province from them, they are noise.

### Attack 4 — is four voices a meter with extra steps? And is prose MORE optimisable than a number?

**This is the sharpest question in the brief and the honest answer is uncomfortable: yes, and yes.**

ADR-019 §4's reasoning is *"the moment allegiance is a number, the player optimizes it and the moral
weight evaporates."* But the thing that enables optimisation is **not numerality — it is
unambiguity plus a tight feedback loop.**

*"The villes down south won't talk to anyone since you came through"* is:
- **unambiguous** (it names the cause: you; it names the effect: they won't talk),
- **prompt** (you hear it the same session), and
- **actionable** (do less of that).

A number like `allegiance: 42` is unambiguous but **not** actionable without a second data point.
**The sentence is a better optimisation signal than the number**, because it carries causal
attribution the number does not. A player farming allegiance would prefer the sentence.

So the four voices are a meter with extra steps — **and specifically a meter with a causal
annotation, which is a strictly better meter.** ADR-019's §4 defence does not survive contact with
this design as literally described.

**But — and this is the counter I would actually hold — that is fine, because ADR-019 §4's real
target was never information. It was *precision*.** A number invites *titration*: burn the ville,
watch it go 42→38, learn the exchange rate, and price atrocity. Prose refuses titration: you cannot
tell whether one ville or three moved the sentence, so you cannot build the exchange rate. **The
protection is imprecision, not silence.**

- **Therefore the binding constraint on the faction voices, which must be in the ADR:** *a faction
  line may name a cause and a mood, but must never imply a magnitude or a rate.* "Since you came
  through" is legal. "Since the third village" is not. "They're colder than last week" is not — it
  implies a scale.
- **Test:** `tests/test_faction_lines.gd` — the faction line table must contain zero digits, zero
  comparatives of degree (`more`, `less`, `colder`, `worse`), and zero counts. **A grep-able law.**
  This is the rare presentation rule that a probe can actually enforce, and it should be written
  before the first line is.

---

## 6 · THE RACIAL ELEMENT

The Summoner said he does not think he is the writer to handle it and does not want it done badly.
**That sentence is the most important input to this section, and it deserves to be answered, not
managed around.**

### The honest case for CUTTING it from launch scope

1. **He told you the truth about his own capability and you should believe him.** GAME_GUIDE §1
   names the tonal north star (Platoon / Hamburger Hill / Apocalypse Now) and ADR-019 records his
   explicit rejection of written plot — *"i dont wanna make a fake cheesy storyline driven game."*
   The whole project's design thesis is **"the war is the story," achieved with no writer.** Racial
   social geography is the one element on the entire board that **cannot** be produced by systems.
   It requires authored prose from a specific author with a specific ear. **It is the only part of
   this design that violates the project's own founding constraint.**
2. **There is no writer, no dialogue system (§5, verified zero files), and no writing budget.**
   GAME_GUIDE §8.1 budgets in art-days at a measured velocity. Writing days appear nowhere. The
   store page, capsule and trailer are already flagged as *"his days, and they were never budgeted."*
3. **"Presence without plot" is the hardest version, not the easiest.** Plot gives you a place to
   put the meaning. Presence-without-plot means every instance must land on its own with no
   scaffolding — which requires *more* skill, not less. The approach as agreed is the expert
   difficulty setting.
4. **The demo is 30 minutes and one firebase.** Social geography needs time and repetition to read
   as geography. In 30 minutes it cannot read as *structure*; it can only read as *incidents*. And
   isolated racial incidents with no structure around them is precisely the failure mode.
5. **Cutting costs almost nothing dramatically.** The class truth of the draft — poor kids, no
   deferment, everyone here because nobody could buy them out — carries **most** of the intended
   weight and is race-neutral to state. The Summoner's own agreed framing already says *"the draft
   carries the class truth."* You can ship the class truth at launch and the racial layer later,
   with a writer, and lose very little of the intended effect.

### The honest case for KEEPING it

1. **Its absence is also a statement, and a worse one.** A 1968 US Army firebase with no Black
   soldiers, or with Black soldiers who are visually present and socially undifferentiated, is
   **not neutral** — it is a specific and well-documented erasure that critics notice immediately
   and name. There is no "no position" option here. **You are choosing between two positions.**
2. **It is not decoration; it is the period.** Racial tension in rear-area units in 1968–70 is not
   a theme layered onto the Vietnam grunt experience, it is a load-bearing fact of it. A project
   whose stated ambition is a hardcore, honest, unglamorous grunt game and whose north star is
   *Platoon* — a film in which the platoon's fracture is the entire drama — cannot omit it and
   still claim the ambition.
3. **Social geography is the cheapest possible implementation and it is nearly free.** Who sits
   with whom in the chow hall. Who is on the burn detail. Whose hooch has the record player. **This
   requires zero words.** It is placement, and placement is already a system
   (`working_point_resolver.gd`, `site_layouts.gd`). The version that needs a writer is the version
   with dialogue; the version without dialogue needs a level designer.
4. **The agreed guardrails are the right ones and they are unusually well specified** — no slurs as
   ambient flavour, individuals never representatives, the player never the arbiter. Those three
   rules exclude the overwhelming majority of ways this goes wrong.

### The failure modes that would actually get the game written about badly

Ranked by likelihood × severity. These are the specific things, not vague worry:

1. **Slurs as ambient atmosphere.** The single highest-risk item and already excluded by the agreed
   approach. Keep it excluded, in writing, as a hard rule with no exception clause — because the
   exception clause ("only when the fiction demands it") is how it comes back.
2. **The one Black character who exists to have one racial line.** This is the *representative*
   failure and it is the most common one in games. Already named by the guardrails. The test is
   countable (below).
3. **The player as absolver.** A quest where the player resolves a racial conflict and everyone
   feels better. This is the *Green Book* failure. Already excluded by "the player is never the
   arbiter," and it is the failure most likely to arrive as a well-meant design suggestion, because
   it is the shape every quest system pulls toward.
4. **Systemic mechanisation.** A "racial tension" variable, a morale modifier, anything numeric.
   ADR-019's §4 logic applies with far more force here: the moment it is a number it is a dial, and
   a dial on racial tension is indefensible on its own terms and unanswerable in a review.
5. **The un-flagged worse one that nobody has mentioned: the Vietnamese.** Every guardrail written
   so far is about race *inside* the American firebase. The game's actual racial exposure is
   larger — the VC/NVA, the villagers, and above all **the civilian model who exists to be shot at**
   and about whom ADR-019 is candid (*"it doubles down on civilians, which are art-blocked and
   behaviourally unspecified"*). A game that handles the American racial layer carefully and treats
   Vietnamese civilians as ambient targets has **not** solved its problem; it has solved the smaller
   half of it while making the larger half more conspicuous by contrast. **This is the real
   write-about-it-badly risk and it currently has no guardrail at all.**

### Recommendation

**Keep it, at the smallest and least verbal scale that exists, and cut the verbal layer entirely
from launch.** Specifically:

- **SHIP:** social geography as *placement only*. Chow hall seating, work details, hooch groupings.
  Zero authored lines. This is level-design work, it needs no writer, it costs no writing days, and
  **it is the version his own stated approach describes.**
- **CUT from launch:** every authored line of racial content, including the "good" ones. Not because
  they would be bad, but because he told you he is not the writer for them and he is the authority
  (Law 3). A writer can be brought in post-launch and the placement layer will be waiting for them.
- **ADD the missing guardrail:** the same care extends to the Vietnamese, and the first place it
  bites is the civilian. That is a bigger open item than the American layer and it is already on the
  board as ADR-019's named art/behaviour gap.
- **Test:** the countable one. **Before ship, list every named character with a speaking line and
  every one who is visually non-white. If the intersection is exactly the set who speak about race,
  the representative failure has occurred.** That is a checkable, five-minute audit and it is the
  only test in this section that is not a matter of taste.

---

## 7 · RETIRING ADR-006 — what silently breaks

**ADR-006's `compute_score()` is not a scoring display. It is the ONLY faucet in the game's entire
progression economy.** Retiring it without a named replacement breaks five things, four of them
silently.

The chain, measured (`scripts/ui/screens/debrief.gd:32-42` → `CampaignState.bank_reputation`
→ `campaign_state.gd` level/title → `armorers_bench.gd` rack + `field_director.gd` fire support):

`compute_score(r)` = `contacts_avoided×25 + contacts_detected×(−25) − damage_taken + 50 (fast) + 75 (ghost) − 100 (POW)`.

Exactly two callers:
- `scripts/missions/field_director.gd:2058` — `bank_reputation(compute_score(result))` at the wire
- `scripts/main/game_flow.gd:469` — the same at mission end

**Retire ADR-006 and both callers bank a function that no longer has a definition — or, worse, one
that returns near-zero.** Then:

| What breaks | How it presents | Evidence |
|---|---|---|
| **1. Rank never advances.** `reputation` never grows → `level()` stays 1 → `title_tier()` stays 0 → the player is PVT forever. | Silent. Nothing errors. The player simply never gets promoted. | ADR-032 ladder, `campaign_state.gd:62-95` |
| **2. The armory rack serves base kit forever.** `rack_for_tier(0)` = M16A1 + M1911 only. **Ithaca 37, M14, M79, M60, M70, M72 LAW become permanently unreachable** — six weapons, five of which have finished art and .tres data. | Silent, and reads as "the bench is broken." | `armorers_bench.gd:46-53`; tiers in `data/weapons/*.tres:9` |
| **3. The ONLY visible progression event in the game disappears.** ADR-032 §"The tell": `FIELD PROMOTION: <RANK>` is *the* tell. It fires from `bank_reputation` returning true (`field_director.gd:2058-2059`). No promotions → no tell → **a progression system with zero HUD affordance, which is a direct r4bk violation.** | Silent. | ADR-032 "The tell" |
| **4. Fire support is permanently cut to the PVT floor.** `_grant_fire_support` (`field_director.gd:1511-1519`) reads `CampaignState.title_tier()`: at rank 0 it zeroes `bombs` and `napalm` and decrements `mortar`. **The player never gets air support in the campaign, ever.** (The demo is immune — it hard-overrides to 3 bombing runs at `:1524-1529`. So this breaks in the campaign and is *invisible in the demo playthrough*, which is the worst possible combination.) | Silent, and undetectable at the gate. | `field_director.gd:1511-1529` |
| **5. Two probes and one test go red or, worse, vacuously green.** `tests/test_reputation.tscn` asserts ladder order, promotion-fires-at-gates, and per-tier rack contents. `tests/test_xp_spend.gd:17` calls `compute_score()` directly. | Loud (good) — but only if the suite is run, and GAME_GUIDE §8.1 item 1 says the last baseline is 2026-07-27, **unverified since**. | ADR-032 §Probe; ADR-006 §Work created |

### The one thing that does NOT break

`CampaignState.on_mission_end(result)` and `threat_label()` — escalation — read the result dict, not
the score. Escalation survives. That matters, because escalation is what the *demo* visibly uses.

### The trap in "contraband replaces points"

Contraband is a **currency**, not a **faucet**. A currency is spent; a faucet fills the reputation
pool that gates rank and the rack. If contraband replaces ADR-006, someone must answer: **does
carrying contraband home bank reputation?** If yes, then contraband is the faucet and the game now
teaches *loot the bodies* — which is precisely the "loud play is the optimal XP strategy" wound that
ADR-006 was written to close (ADR-006 §Context: *"the XP economy… literally trains loud play"*).
**Retiring ADR-006 for contraband risks re-opening ADR-006's original wound with a different noun.**

- **Mitigation, and it is one sentence:** **no ADR may retire ADR-006 without naming its replacement
  faucet in the same document, with the two call sites (`field_director.gd:2058`,
  `game_flow.gd:469`) named.** "Retired" with no successor is not a decision, it is a hole.
- **Test:** `tests/test_reputation.tscn` gains one assertion: **after a scripted successful patrol,
  `CampaignState.reputation` is strictly greater than it was before.** That single assertion turns
  all four silent breakages into one loud red line, whatever the faucet ends up being.

---

## 8 · THE PLAYTEST LIST vs THE PIVOT — blunt

**The playtest list is the real work today. It is not close.**

His words: *"right now to get that more real, we need to make sure the last long list of things i
mentioned from my playtest has been fixed."* Read the sentence structure. **"To get that more real"**
— the pivot is the *goal clause*; the defect list is the *means clause*. He is not asking which to
do. He is saying the list is how the pivot becomes real. **The council is at risk of answering a
question he did not ask while leaving unanswered the one he did.**

The state of that list, counted from `PLAYTEST_FINDINGS_2026-08-28.md`:

- **P0 crashes:** 2, both fixed **1a52e3dd, both still unverified by his eye.**
- **P1, "BLOCKS THE SIEGE RUN":** items 3, 4, 5, 6 open, 8 open-with-hypothesis. Item 3 is
  **"cannot enter ANY bunker."** Item 6 is **"NPC squads spawn on the hooch ROOF."** Item 4 is
  **"NPCs fall through the ground."**
- **P3 systems:** 10, 22, 24, 28, 29, 33 open.
- **P4 art/layout:** ~16 open, tagged [BLENDER] or [SCENE-LAYOUT] — his own hands.

**Roughly 20+ open items, and at least four of them are P1 items whose header says they block the
siege run — the siege run being the exact thing GAME_GUIDE §8.0 names as the session entry gate
that has never been discharged.**

Set that next to what the pivot buys today. Per §3a, the two-quest design adds **~170 seconds of
walking to a 20-minute window that already has 17 minutes of dead air**, and per §3c its refusal
case is the demo that already exists. Its measurable contribution to the demo is close to zero.
Meanwhile:

- A player who cannot enter a bunker (item 3) **cannot use the firebase as a firebase during the
  siege the whole demo builds toward.**
- NPCs on the hooch roof and falling through the ground (items 4, 6) are the **first two things a
  stranger sees**, in a demo whose stated job is *"scope and spectacle immediately."*
- The lives economy is dead for the daylight half of every run (§3d) and nobody knows it.

**And the sharpest version of the argument:** the pivot is a claim about what the game *is*. The
defect list is a claim about whether it *works*. **You cannot demonstrate that the firebase is home
while the player cannot walk into its bunkers.** The pivot's own thesis is materially blocked by
item 3 of the list he asked about. The two are not competing priorities — **the list is a
prerequisite of the pivot**, and treating them as alternatives is the category error of the day.

**Recommendation:** record the decree — it costs nothing, §1 concedes that — but the **decree's own
first build item must be the playtest list**, and the synthesis must state the count of items closed
today. If the answer is zero, the synthesis should say zero.

**Test:** it is a count, and it is free. At session close, count the open `[ ]` rows in
`production/PLAYTEST_FINDINGS_2026-08-28.md` before and after. **If the number did not move, the day
went to documents.**

---

## 9 · Summary of tests this analysis asks for

Ordered by value per minute. Nothing here needs the Summoner's time except the last two.

| # | Test | Settles |
|---|---|---|
| 1 | `tests/probe_daylight_death.tscn` — force death at T+900 s, print `garrison_promoted` size and whether `try_swap()` returned true | §3d — a live defect, unknown, one line to fix |
| 2 | `tests/test_reputation.tscn` + "reputation strictly increases after a successful patrol" | §7 — turns four silent breakages into one red line |
| 3 | `tests/test_patrol_contract` + "exactly one `_bank_patrol` per demo run" and "exactly one live `patrol_location`" | §3b, §4 — the offer-board slope becomes diffable |
| 4 | `tests/probe_demo_walk_budget.gd` — navmesh distances gate→village→temple→gate, ÷5.0 and ÷2.5, against 1184 s | §3a — replaces my arithmetic with a measurement |
| 5 | `tests/probe_late_return.tscn` — player at the temple at 1350 s; can the demo end with him never in the fight? | §3e |
| 6 | `tests/test_faction_lines.gd` — zero digits, zero comparatives of degree, zero counts in the faction line table | §5 — the imprecision law, grep-enforceable |
| 7 | `tests/probe_no_dialogue_system.gd` — zero files matching `dialogue\|conversation\|topic_tree` | §2 leak 3 |
| 8 | `git diff --stat` on `body_swap_system.gd`, `health_system`, `save_manager.gd` at each session close | §2 leaks 1 and 2 |
| 9 | **Fresh-player protocol** (DEMO_TIGHT_40 step 37, his own law, never run): 20 minutes, then *"what did the men think of you?"* | §5 — the only test that can settle factions-as-readout |
| 10 | **The named-character audit** before ship: speaking characters × visually non-white; is the intersection exactly those who speak about race? | §6 |

---

## 10 · The five holes, ranked

1. **The lives economy does not exist during the daylight half of the demo, and the two-quest
   design's whole purpose is to put the player there.** `_pick_pool` latches `_picked = true` before
   finding zero candidates (`body_swap_system.gd:56-69`); the pool comes only from `garrison_promoted`,
   populated only at stand-to (`garrison_defender.gd:100` ← `field_director.gd:1775`). A death at
   900 s ends the run at T+15 min and permanently disables swapping.
   **Mitigation:** move `_picked = true` after the candidate scan; probe #1.

2. **Retiring ADR-006 silently kills rank, the armory rack (six weapons), the only visible
   progression event, and campaign fire support — and item 4 is invisible in the demo, because the
   demo hard-overrides fire support.**
   **Mitigation:** no ADR retires ADR-006 without naming the replacement faucet and the two call
   sites; probe #2.

3. **The two-quest premise is inverted.** ~850 m of walking ≈ 170–340 s against a 1184 s window.
   The problem is 14 minutes of dead air, not a missed dusk.
   **Mitigation:** measure it (probe #4) and take the real question — *"what fills the window?"* —
   to the Summoner instead of the fake one.

4. **"Zero new UI" is the highest-risk sentence in the synthesis.** There is no dialogue system —
   zero files. The interact verb is a hardcoded ladder at `player.gd:606-660`. And four voices are a
   meter with causal annotation, which is a *better* meter than a number; ADR-019 §4's defence does
   not survive as written. What actually protects it is **imprecision, not silence.**
   **Mitigation:** write the imprecision law (no magnitudes, no rates, no counts) and enforce it
   with probe #6; require at least one unprompted faction voice.

5. **The scope wall has no enforcement surface, and the four most citable leaks are DOWN state,
   save-anywhere, the factions, and a second tunnel room — each of which arrives as a bug fix,
   a P0, atmosphere, or "one more room."**
   **Mitigation:** every post-demo ADR carries a **FROZEN FILES** section naming paths, and
   `SLEEP_POST_LAUNCH`-style parked-but-built constants are explicitly forbidden as the leak
   mechanism they have already proven to be; probe #8.

---

## 11 · The two verdicts

**Item 1 (is recording the decree the risk?):** No — the decree is cheap, honest and points where the
code already faces; **the risk is the date, and the decree is its alibi**, so record it only inside a
synthesis that also states plainly that the 2026-09-06 EA target passed with the §8.0 gate
undischarged.

**Item 8 (pivot or the playtest list?):** **The list, and it is not a close call** — it is not a
competing priority but a prerequisite, because you cannot demonstrate that the firebase is home
while the player cannot walk into a single one of its bunkers.
