# DISCUSSION — Player death, respawn-as-another-man, lives economy (2026-08-22)

Four independent analyses (analysis/). No cross-talk during INDIVIDUAL SIGHT. Debate below.

## Convergence (all four voices, from different doors)
1. **The demo body-swap is right, and it is the minimum honest version.** Even the Devil's
   Advocate concedes it: a siege has no exfil, so death inside the wire has no fail-forward
   answer today — "RESTART THE NIGHT" at minute 18 of a 20-minute siege (`demo_game.gd:546,582`)
   is a shipped Pillar 5 violation. Body-swap into a living named garrison defender fixes it.
2. **A "life" is a NAMED MAN, never a number.** All four reject the abstract Easy Red 40-counter:
   it turns death into currency (Pillar 4), it either refills from free rookies or becomes a
   Pillar-5-violating fail state (systems), and "LIVES: 37" violates the never-show-the-number
   decree that founded ADR-032. The pool is names on the roster; the presentation is names.
3. **Pool empty = an ENDING, not a game-over screen.** The fall-variant end card ("THE WIRE
   BROKE BEFORE DAWN", full KIA/HELD roster, your own previous bodies as KIA rows) reuses the
   existing end-card idiom (`demo_game.gd:556-590`). Cannon Fodder gravestone moment nearly free.
4. **The build point is the existing choke.** `health_system.gd:283 force_death()` — both
   bleed-out and headshot funnel there; the medic-revive interception window (:270-278) stays
   untouched and becomes MORE meaningful. Swap target: living GarrisonDefender (`AllyBase`
   soldiers, `field_director.gd:1612-1636`). Effort: 1-2 sessions, ~80% reusable for campaign.
5. **The saves loophole is accepted OUT LOUD, not smuggled.** Any lives economy under REGULAR
   (F5/F9 anywhere) is theater — ADR-007 already calls REGULAR "a standing repeal of Pillar 5"
   and permadeath lives with it. The economy binds in the demo (no saves) and HARD/IRONMAN.

## Conflicts (named, with resolutions proposed to the Arbiter)
- **Rank on death.** DA: ADR-032's single-protagonist ladder breaks — ghosting SSG rank makes
  player death partly free; resetting rank is double jeopardy; "no third answer exists."
  GD's third answer: **"the institution remembers, the man is mourned"** — rank/reputation/armory
  persist as the battalion's trust in the slot; the personal layer (nickname, service record,
  kill count) dies with the body. SD confirms ADR-032's disembodied reputation survives the swap
  for free mechanically. RESOLUTION: GD's third answer stands as the recommended campaign
  direction, but it amends ADR-032 and is post-EA — deferred to a post-EA council with playtest
  data, per the DA's scope objection (19 days to EA, undischarged ADR-015 demo gate).
- **Demo pool shape.** GD: three PRE-PICKED defenders with distinct kit (M60 man, M79 man) —
  garrison-as-pool (~50) makes the demo unloseable, reject there. SD: swap into NEAREST living
  defender + swap counter. UX: needs names knowable in advance for the swap card ("HOLDING:
  DOAKES · WEBB"). WEAVE: pre-pick the named trio at siege start; on death, wake as the nearest
  LIVING man of that trio. Kit distinctness = variety; nearest = position-honest, no teleport.
- **Campaign economy.** GD+SD sketch roster-as-pool (a life IS a living man in the mission;
  finally prices the "costless loss" debt, GAME_GUIDE:191-195; gives IRONMAN a coherent final
  death via the existing archive at `game_flow.gd:469-471`). DA: that is a core-loop rewrite
  amending ADR-007+ADR-032 — defer. RESOLUTION: direction endorsed, ruling deferred post-EA.

## The Summoner's fairness premise — judged
He is RIGHT for the demo: HLL lethality + no saves means one RPG deletes the run; a small named
pool converts variance into an economy (cheap per man, expensive per battle). He is answered
differently for the campaign: fail-forward + all-or-nothing exfil commits already ARE the
campaign's fairness mechanism; the roster is already the lives pool, unpriced.
