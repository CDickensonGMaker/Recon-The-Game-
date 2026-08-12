# War Room Briefing — 2026-08-11 Playtest Defect Sweep

**Summoner's query:** "lets fix all these problems, loop until finished" — all 7 defects from
`production/PLAYTEST_FINDINGS_2026-08-11.md` (Caleb's own demo playtest, same day).

## The seven defects
1. Huey flyby audio compresses the speakers — audible crunching/clipping (mix/limiter).
2. Dropoff troops stack on top of each other at the LZ edge, then idle in a pile (need dispersal).
3. Squad never catches up when the player leaves the base — **teleport catch-up pre-approved by Caleb**.
4. Villagers and VC get stuck inside buildings (nav).
5. Dead bodies fall, then snap back UP into a standing pose while dead.
6. A corpse's belt detached weird on death (gear attachment vs. death pose).
7. AK fire SFX has a bolt-rack noise after EVERY shot (rack belongs to reload only).

## Council
- **Audio Architect** — defects 1, 7
- **Gameplay/Systems Architect** — defects 2, 3
- **AI & Animation Architect** — defects 4, 5, 6
- Devil's Advocate reviews the woven plan before any edit.

## Constraints (binding)
- Godot 4.7 only. Diagnose before budgeting: every claim cites `file:line`.
- No headless test-suite runs during the build; no launching the game on Caleb's desktop.
- Audio house contract: 48000 Hz. Real gun recordings are sacred — never regenerate them
  (`tools/gen_weapon_audio.py` landmine). AK47 has 3 real fire variants.
- Defect 4 interacts with the pending firebase export (nav geometry will change) — fix the
  logic, note the retest dependency.
- Analyses → `production/war_room/analysis/`; agents return SHORT verdicts only.
