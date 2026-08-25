# SYNTHESIS — Player death & the lives economy (Arbiter's weave, 2026-08-22)

Session type: OPTIONS BOARD for the Summoner's talk. No decree issued; rulings listed at end.

## The weave
The Summoner's instinct is ratified in spirit and corrected in form. Easy Red's mechanism
(die → become another soldier → finite pool → pool empty ends it) fits this game BETTER than
Easy Red, because here the pool is already simulated: named men, a casualty ledger that is the
scoreboard, body bags that stack. But the COUNTER must never appear — a life is a named man,
and the number "40" is rejected as another game's ticket system. Two different problems were
hiding in one ask:

**1. THE DEMO (real hole, build-ready).** The siege has no exfil, so death has no fail-forward
answer; RESTART-THE-NIGHT is a Pillar 5 violation in shipped form. Fix: on `force_death`, cut
to black over a still-running war (audio never stops), amber epitaph card ("PFC <YOU> — KIA /
THE LINE HOLDS / YOU ARE SP4 DOAKES"), wake in the eyes of the nearest living man of a
pre-picked named trio with his kit; no kill-cam, no camera flight, medic-revive window
untouched. Third death = the fall-variant end card, previous bodies as KIA rows. No lives
number anywhere; the swap card and end card carry the names (r4bk satisfied). Build at
`health_system.gd:283` / garrison defenders `field_director.gd:1612-1636`. 1-2 sessions,
~80% reusable. Sacrifices named: per-death sting softens (mitigate: ugly wake-up, your rifle
on your own corpse), 3-4s blind under fire, demo determinism claim gains a caveat.

**2. THE CAMPAIGN (direction endorsed, ruling deferred post-EA).** Roster-as-pool: a life is
a living man within reach; when no man remains, the KIA chain runs as today. This finally
prices squad loss (the ADR-018 veterancy debt) and gives IRONMAN a real final death. Identity:
"the institution remembers, the man is mourned" — rank/armory persist as the slot's trust,
the personal layer dies with the body. Binds in HARD/IRONMAN; REGULAR dodges it and that is
accepted out loud (ADR-007 precedent). Amends ADR-007 + ADR-032 → post-EA council with demo
playtest data. Nothing pulls from the EA ship list.

## Sacrifices (Law 2)
Demo: softer individual death sting; blind seconds; determinism caveat. Campaign direction:
single-protagonist intimacy becomes a lineage; REGULAR-tier theater accepted; double-jeopardy
risk if rank ever resets (rejected). Deferral: the demo ships with a mechanic the campaign
does not yet honor — a known seam, recorded.

## Rulings awaited from the Summoner
R1. Greenlight the demo body-swap trio as specced (recommended). Sequencing: siege replay
    FIRST as already queued — it validates six unrelated fixes; the swap is the build after.
R2. The demo pool size: 3 men total (you + two swaps) vs 4 (you + a trio). Council leans 3.
R3. Campaign direction nod (not a decree): roster-as-pool + institution-remembers, post-EA
    council to ratify. A nod now shapes what the demo build keeps reusable.
R4. Confirm: no lives number ever rendered (extends the ADR-032 never-show-the-number law
    to death economy). Council unanimous.
