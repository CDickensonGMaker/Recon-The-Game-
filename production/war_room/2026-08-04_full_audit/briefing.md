# BRIEFING — 2026-08-04 — FULL AUDIT: DEMO SCOPE + FULL GAME

**Convened by:** the Overseer/Director as Arbiter, at the Summoner's direction.
**The ask, his words:** *"run a full audit of the demo scope of the game as well as the full game.
see where were weakest, strongest and where we can improve still"*

**Deliverable:** three ranked lists for BOTH the demo and the full game —
- **STRONGEST**: genuinely working, verified where possible
- **WEAKEST**: most likely to embarrass us in front of a stranger or block the ship
- **IMPROVE**: highest-leverage improvements still available, ranked by value-per-effort

## Standing facts (do not re-litigate)
1. The demo was RESCOPED 8/3 (`war_room/2026-08-03_demo_day_scope/synthesis.md`, ten rulings in §8):
   one full day at the firebase, 30 real minutes, night attack, circling Huey gunships ending
   (player survives, one flag). The 7-minute slice is DEAD. Four lighting events, 3 bombing runs
   only, radio is an object, headshot ends the demo, HLL revive paid in bandages, wounded
   squadmates CUT from demo.
2. The rescope was WIRED 8/4 (commit 1795b519; record in `production/DEMO_SHIP_BACKLOG.md` §2026-08-04).
3. **NOTHING from the 8/4 wiring has ever run.** Parse-checked only. Measurements M-1..M-5
   (8/3 synthesis §5) are ALL outstanding. M-1 gates every chow-hall decision.
4. Chow hall HALF wired: 19 chow_* clips in `assets/shared/anim_library.glb`, markers in the .blend,
   firebase GLB NOT re-exported, queue/tray/seat chain unbuilt.
5. His Blender bench: firebase re-export (dual pads + wire split + medical + bunker slits + chow
   hall; `gen_firebase_v3.py:912` default now CORRECT — do not repoint; `:1104` still stale),
   staging M60 door gunners in the Huey.
6. Prior audit 7/31 (`war_room/2026-07-31_demo_ship_audit/synthesis.md`) — read it, do not repeat it.

## Laws binding every architect
- **POINTER LAW**: every assertion cites `file:line` or names the probe. No pointer = opinion.
- **The codebase beats every document.** The backlog once claimed seven open items already shipped.
  Verify in code before claiming anything missing.
- **Law 2**: name what is sacrificed in every recommendation.
- **NO CODE.** Audit only. Where a claim needs a measurement nobody has taken, SPECIFY the
  measurement instead of guessing.
- No cross-talk. Independent sight is the value.

## The council and their dimensions
| Architect | Dimension |
|---|---|
| game-designer (demo readiness) | The 30-min arc as wired vs the ten rulings; first 5 minutes (5-minute rule is LAW); last 30 seconds; all death paths |
| systems-designer (full game) | Open-patrol loop (ADR-029), campaign/persistence, progression, night economy/sleep, hearts & minds absence, siege stakes (ADR-036), two-games boundary; deep-and-real vs scaffolded |
| ai-architect | Enemy AI, hunt net, siege director, ally AI vs the Vietcong bar, capability-not-gun doctrine, ~14 parallel-systems sprawl |
| art-director | 182 shared-library clips, 32/163 orphans, viewmodel pipeline, PSX imports, firebase kit, the Blender bench blockers |
| technical-director | Accumulators/perf, PERF_LEDGER, red test baseline since 7/27, fossil ratchet, export/build health (ONE export has ever existed); quantify BUILT-AND-UNVERIFIED and what one playtest discharges |
| devils-advocate | Attack the whole board: what embarrasses us in front of a stranger; what the other dimensions assume without proof |

Output: `analysis/<architect>.md`, full analysis there, SHORT verdict returned to the Arbiter.
