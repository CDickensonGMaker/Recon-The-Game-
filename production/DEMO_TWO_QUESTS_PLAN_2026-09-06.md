# DEMO: TWO QUESTS OUT THE WIRE — the plan, priced. NOT BUILT.

**Date:** 2026-09-06 · **Status:** PLANNED AND PRICED. **No code was written for this.**
**Authority:** the Summoner's final message of 2026-09-06, verbatim:

> *"maybe to fill the demo up with things to do, we do have the factions element and theres two quests
> you do, and if timed right itll be dark sooner or later when they come back from those quests and the
> firebase attack happens. that sounds like a fun demo."*

**Council:** `production/war_room/2026-09-06_rpg_pivot/` · **Binds:** ADR-029 + Amendment C §4,
ADR-038, ADR-020.

---

## 0 · THE HEADLINE, AND IT REVERSES THE PREMISE

**There is no timing problem. There is a DEAD AIR problem, and the two quests do not fix it.**

Measured, not remembered:

| Fact | Source |
|---|---|
| Player walk speed **5.0 m/s**, sprint 8.0 | `scripts/player/player.gd:12-13` |
| Firebase compound half-extents **149.3 × 111.2 m** | `site_planner.gd:809` (`FSB_HALF`, "model space, measured") |
| Village **185 m** from centre · temple **170 m** · the two authored bearings are **90.7° apart, not 180°** | `mission_generator.gd` `plan_demo_world` (`out_v.rotated(±2.35)`) |
| Night falls **~1184 s** · probe **1395 s** · assault **1440 s** | `demo_game.gd:46, 58, 59` |

**The village and the camp sit roughly 36–74 m outside the wire.** The full circuit — gate → village →
camp → home — is about **850–1000 m**, which is **170 s at walk speed** and **~340–500 s at a cautious
2.5 m/s with two firefights.**

**Dusk is 1184 s away.**

| Player | Circuit | Left standing around before dusk |
|---|---|---|
| Sprints, no contact | ~110 s | **~18 min** |
| Walks, no contact | ~170 s | **~17 min** |
| Cautious, two firefights | ~340–500 s | **~11–14 min** |
| Very slow, explores every ruin | ~800 s | **~6 min** |

> **"Timed so the player returns at dusk" is not a design — it is a description of the fact that there
> is nothing else to do.** He does not return at dusk because the quests take until dusk. He returns
> when he finishes, and then he waits.

The code already knows this. `field_director.gd:1454-1456` raises the hunter pool with a comment naming
the exact failure: *"12 men at 2-4 a wave is ~7.7 minutes of contact and then an empty AO for the rest
of a 30-minute day."*

**THE REAL QUESTION FOR THE SUMMONER — and it is the one design decision worth his time today:**

> The map is 512 m and the compound is 298 × 222 m of it, so the quests **cannot be made far.**
> **They must be made SLOW** — something that spends real seconds without spending metres: a hold, a
> search that takes time, an escort, a dig, a wait for something to happen.
> **Which one do you want?**

## 1 · THE GOVERNING RULING

> **The two quests are NOT a new tasking system. They are two men putting a REASON on the two places the
> sweep selector already offers, in the order it already offers them.**

`field_director.gd:1325-1326` admits only `village` and `vc_camp` into `patrol_locations`. The village
(185 m, nearest the gate) is already first; the camp is already second; Six already hands off between
them with *"OR BRING THEM IN. YOUR CALL."* (`:1666`). **All that is missing is a human motive and a
human payoff** — which is exactly the RPG the decree asks for, and it is why this is cheap.

Build a second picker and you have rebuilt the offer board ADR-029 killed, breached Amendment C §4
clause 4, and doubled the bug surface on the one loop that must not break in the shipping demo.

## 2 · THE TWO QUESTS

### QUEST ONE — THE VILLAGE. Given by the BLACK-MARKET GANG.
- **Who:** the gang's man in the hooch nearest the supply depot. A Spec-4 with a footlocker. Not a
  quartermaster, not on your roster.
- **The ask, face to face, inside the wire, never on the net:** *"There's a ville out west. When your
  patrol goes through it, I want what's in the headman's hut. Not the rice. The rest of it."*
- **What ends it:** the existing sweep — a kill in the 90 m ring with zero live hostiles fires
  `_finish_sweep("THE AREA'S CLEAR")` (`field_director.gd:1629-1630`); the map takes a dated `SWEPT`
  mark (`:1650`); Six offers the camp.
- **The quieter end:** a `FieldCache` stamped in the village, taken with the existing `[F] TAKE FROM …`
  verb (`player.gd:645-646`). **He may also just not take it, and nobody says anything.** Pillar 3.
- **The payoff at dusk:** an object that already exists — a satchel, a belt for the pigman, a gun off
  the rack. **Never points.**

### QUEST TWO — THE CAMP. Given by the TRUE BELIEVERS.
- **Who:** the lifer NCO who eats alone. Not HQ.
- **The ask:** *"There's a tube out there. It's been walking rounds onto us for a week and battalion
  says wait. I'm asking you not to wait."*
- **What ends it:** the camp is the selector's second offer; the mortar and ZPU crews are in the ring
  (`mission_generator.gd:834-841`), so the same rule fires. If a tunnel mouth is stamped there,
  satchelling it is the quieter completion. **Both roads legal.**
- **The payoff at dusk:** not an object. **He speaks to you now, and the draftees notice that he does.**

### THE THIRD QUEST DOES NOT EXIST, AND NEVER PUT ONE ON A TEMPLE
A temple has no enemies, no tunnel and no stash, so `_poll_sweep` **can never fire.** A quest whose
completion condition the engine cannot satisfy is *precisely* his 8/28 playtest wound Q2 — *"he believes
he did what was asked; it never registered as finished."* **Do not rebuild that bug as a feature.**

## 3 · ONE WALK-OUT, NOT TWO — RULE THIS EXPLICITLY OR IT WILL BE BUILT WRONG

`_poll_wire_gate` (`field_director.gd:1425-1472`) latches on `patrol_out`: out at 120 m, in at 95 m.
Crossing inward runs `_bank_patrol()`.

- **(A) Two walk-outs** (village, home, camp) makes `_bank_patrol` run **twice in one demo**:
  `patrol_count` reads 2, the `MissionState` ledger is destroyed and recreated (`:2074`),
  `_read_the_dead` and `_call_replacements` both run twice, and the player is told "PATROL 1 LOGGED"
  then "PATROL 2 LOGGED" **in a one-day demo whose fiction is a single patrol.**
- **(B) One walk-out, both quests, home once.** The machinery already supports it —
  `_advance_route_tasking` re-tasks onto the next living feature, and the code's own comment at `:1222`
  says *"One walk-out may finish many sweeps and still banks"* once.

> **RULING: (B). One walk-out, one bank.** State it in the build order, because **the first person to
> build this will build (A) — (A) is what "two quests" sounds like.**
> **Test:** `tests/test_patrol_contract` gains one assertion — *one demo run, one `_bank_patrol` call.*

## 4 · THE FOUR §4 CLAUSES (ADR-029 Amendment C) — HOW EACH IS HELD

| Clause | How this design holds it |
|---|---|
| 1 · waypoints never check off | Nothing ticks. The sweep ends in the field as it already does; the man at dusk **reads the world**, he does not read a flag |
| 2 · ground-covered never on the in-field HUD | Untouched — it stays a wire-AAR grade |
| 3 · command names features/ordinals, never pins | Forces a good law: **the net is Six; the wire is everyone else.** Faction men speak face to face and **never on the radio** |
| 4 · the route feeds only the one selector | **THIS IS THE ONE THAT BREAKS.** The obvious build writes `patrol_location` directly. `_set_patrol_location` (`:1563`) is documented as the ONE place that may. **The quest must set nothing** — it puts a reason on a tasking the selector already made |

## 5 · THE BRIEFING-SCREEN LINE — where a quest-giver re-grows what he killed in July

| | Verdict |
|---|---|
| One man, one ask, spoken once, face to face, no UI, forgotten if you walk away | **LEGAL** — a bark with a motive |
| Two men in two hooches, one ask each, found by walking | **LEGAL** — plurality of *people*, not of *options* |
| The ask is **re-readable** — a journal, a note, a line on the map screen | **THE LINE. Forbidden.** |
| A place you collect tasks · a list of asks · an ACCEPT/DECLINE prompt · an ask that waits for you | **THE BOARD, rebuilt. Forbidden outright.** |

> ## **THE TEST: if the player can find out what he was asked to do without walking back to the man who asked him, you have built a briefing screen.**

**Corollary, and it is uncomfortable: the player is allowed to forget the quest.** Some players will
walk out having missed both asks, sweep the village on Six's word, and have a perfectly good demo.
**That is correct and must not be softened with a reminder.**

## 6 · THE PRICE, HONESTLY

| | Cost |
|---|---|
| Faction **dressing**, all four camps (who lives where · what plays in which hooch · who acknowledges you · who does not look up) | **~1 art-day + ~1 day of code.** Substrate exists: `FSB_GARRISON_POSTS` / `FSB_GARRISON_QUARTERS` (`site_planner.gd:938-962`), eleven hooches each already given one voiced radio (`_stamp_hooch_radios`, `:2201-2240`), `RadioProp.music_dir` an exported dir |
| Two men doing **the dap** | ~1 art-day. The most expensive line, and the one worth paying |
| Two **named quest-givers** with full state, talk verb, schedule pinning, dressed faces | **3–5 days** of a 13–19 art-day budget with ship items 5, 6, 7 unfinished |

**RULING: ship the dressing for all four camps. Give exactly two men the named treatment, with the
thinnest state that works — ONE BIT, `asked` / `not asked`.** No accept, no "in progress", no completion
flag. **At dusk the man READS THE WORLD** (was the sweep swept? is the cache gone?) and speaks
accordingly. **Read the world, do not store a quest.** That collapses the state machine to a single bit
and is the difference between one day and four.

## 7 · THE THINGS THAT WILL BREAK IT

1. **The dusk payoff dead-ends at random.** The givers are `Civilian` nodes on garrison posts whose
   schedule moves them (`site_planner.gd:938-962`). If the payoff man is off at a work marker when the
   player walks back in, the demo's best beat silently fails. **Pin the two givers to a hooch billet for
   the arc**, or accept a coin-flip on the ending.
2. **THE LIVES ECONOMY IS DEAD IN DAYLIGHT — a live defect this design makes likely.** See the playtest
   queue's new item 36. The two-quest design's entire purpose is to put the player outside the wire in
   daylight, which is exactly where dying ends the run outright.
3. **Walking home in the dark with no light.** `_grant_fire_support` is once per sim day
   (`field_director.gd:1490-1492`) and the illum allotment is 2–3. This is the demo's most likely
   bad-feeling failure. **Name it; do not fix it with a rail.**
4. **There is no dialogue system.** `grep -rli "dialogue" scripts/` returns **zero files**. The
   interact verb is a hardcoded if-ladder (`player.gd:606-660`) with load-bearing priority ordering.
   The ask must be **a toast on the existing channel**, not a conversation.

## 8 · SEQUENCING — and this is the part that matters

**This plan does not go first.** The council's unanimous verdict is that the 2026-08-28 playtest defect
list is a **prerequisite** of the pivot, not a competitor to it: *you cannot demonstrate that the
firebase is home while the player cannot walk into any of its bunkers* (item 3, still open).

**Order:** the playtest list's P1 blockers → the Summoner's siege playtest (the §8.0 gate, still
undischarged) → then this.
