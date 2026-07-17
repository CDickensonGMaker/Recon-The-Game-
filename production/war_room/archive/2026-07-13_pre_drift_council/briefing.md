# WAR ROOM BRIEFING — FULL GAME AUDIT #2: THE DRIFT AUDIT (2026-07-10)

## The Summoner's query
A single Claude window ran for days straight building on this game. The Summoner fears **extreme design
drift**: code that no longer matches the docs, decisions made mid-stream that were never ratified, systems
that quietly diverged from the pillars. Nothing has *felt* broken in his tests — but he wants a fresh,
skeptical, full-game look from clean eyes.

Two deliverables follow this audit (the Arbiter owns them, fed by your analyses):
1. **A robust GAME GUIDE** — the single canonical reference for what this game IS, consolidating the
   drifted doc sprawl, plus formal **ADRs** for every load-bearing decision currently living only in code
   or commit messages. This guide will seed a project-specific "head honcho" agent prompt.
2. **A refreshed build-order decree** and beads records.

## Binding constraints (Pillars — judge everything against these)
1. Outstanding gunplay · 2. Atmosphere · 3. Freedom (no rails; escalation not fail-states) ·
4. The squad is the RPG · 5. Fail forward.

Technical standards in `~/.claude/architect_knowledge/godot_standards.md` are NON-NEGOTIABLE unless a
Pillar overrides.

## What changed since the last audit (2026-07-09 decree, archived at
`production/war_room/archive/2026-07-09_full_game_audit/synthesis.md` — READ IT; you are auditing
compliance with it as much as the code)
Roughly 30 commits in ~36 hours, including:
- Decree items executed: fire-support bug cluster, VO wiring (VOManager), stealth witnessed-contact fix
  (o18o — verify actually fixed), damage unification to RECON dice, locational damage rework
- BLOOD v2 + persistent wounds + gore workflow (5-phase plan, procedural blood textures)
- **CAMPAIGN LOOP OVERHAUL (unratified by any council):** PHASE A save backbone (SaveManager + SaveData
  schema), PHASE B firebase-hub loop (operation → live firebase → TOC briefing → bird), PHASES C+D
  survival v1 (hunger/condition/rations/kits) + HARD checkpoints
- FPS arms viewmodel system (fp_arms pipeline, grip nodes, idle anims)
- PSX character art pipeline (us_grunt_v2, GAME_SCALE_STANDARD.md canonical heights, emplacements, ruins)
- test_hub_loop end-to-end test (passes headless)

## The Summoner's own playtest feedback (2026-07-09, R2) — treat as ground truth
1. **TINY UNITS:** character models render as specks in-world though GLBs measure ~1.9m; capsules also
   spawn for some units (bead n2ij)
2. **TERRAIN POP:** terrain visibly jumps crossing cell boundaries — same class of bug that killed
   Catacombs terrain (bead n2ij)
3. **JUNGLE FEEL:** "jungle a white kid in america made" — flat static grass, needs wind sway, undergrowth
   layers, denser wilder composition (bead n2ij)
4. Standing directives: **perf first always**; UI/UX modernization (Delta Force/R6/Ghost Recon sleekness)
   is the declared next major focus; NPC projectiles from muzzle tip
5. Still-open playtest P1s: a2qb (Huey seating — likely fixed, unverified), r4bk (squad controls —
   mitigated with C/H/X/N secondaries, unverified), e6qc (combat-lab wedge/keybind items), zet2
   (inventory/backpack design + weapon pickup)

## Context of record (read before analyzing)
- `DESIGN.md` (approved vision, M0–M8) · `CLAUDE.md` (technical law) · `ROADMAP.md` + `ROADMAP_NEXT.md` +
  `ROADMAP_WAVE2.md` + `WAVE3_REPORT.md` (note: FOUR roadmap docs exist — that sprawl is itself evidence)
- `STATE_OF_PROJECT.md` · `RECON_ADAPTATION.md` · `MISSION_DESIGN_RESEARCH.md`
- `production/bible/` (BIBLE.md + 05_CAMPAIGN_ROSTER + 09_CHARACTERS_ART — mostly unwritten)
- `production/` reports: WIRING_STATUS, PROGRESS_REPORT, CALEB_TODO, GAME_SCALE_STANDARD, GORE_WORKFLOW
- Code: `scripts/` (90 .gd in 15 dirs), `scenes/`, `data/`, `terrain/`, `tests/` + `run_all_tests.ps1`
- Beads: 50+ open issues; open P1 keystones: 0623 (AI north star), gpvb (EnemySquad), r6qe (detection
  ambience), wbtd (gunplay feedback), 4i60 (campaign epic), 36pk (viewmodels), plus audio epics

## What each architect must deliver — `production/war_room/analysis/<role>.md`
(a) **DRIFT CATALOG** (the headline deliverable): every place where code ≠ docs, code ≠ decree, or
    docs ≠ docs. For each: what the doc/decree says, what the code actually does (file:line), which is
    RIGHT (sometimes the drift is an improvement — say so), and what to update.
(b) Top 5 strengths · (c) Top 5 weaknesses/risks ranked
(d) Pillar scorecard (1–5 per pillar from your lens) with one-line justification each
(e) The ONE thing to build/fix next and why
(f) **ADR CANDIDATES:** decisions you found living only in code/commits/memories that deserve a formal
    ADR (title + the decision + why it matters). The Arbiter will write them.
Ground every claim in file:line or doc evidence — no vibes. You are auditors, not implementers:
**write nothing outside your own analysis file.**
