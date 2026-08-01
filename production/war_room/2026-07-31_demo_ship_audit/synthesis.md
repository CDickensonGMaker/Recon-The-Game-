# THE DECREE — Full Audit: Demo vs Full Game, Ship-Readiness
**2026-07-31 · Arbiter's weave · Summoner holds final authority (Law 3)**

## VERDICT ON THE WEEK
**Yes — demo shipping state by end of next week (~8/9) is realistic, on one condition: the export build and playthrough #1 happen by Monday 8/4.** The remaining work is 3-4 days of code + ~2 days of the Summoner's Blender (parallel) + 2-3 days of his playtest. What kills the date is not volume — it is ordering. Every day the first exported .exe slips, the fix loop count drops by one, and this project has NEVER run an export→play→fix loop.

**The "art blocks" premise is refuted.** The art tree is near-perfect mechanically (2 missing refs repo-wide; all 163 clips resolve; the 21 "unexported" interior props are already on disk — the CODE never places them). The true blockers are: a build that has never been exported, a 45-min playtest script that has never been run, and ONE real art dependency (the wire ring).

## STRONG SUITS (what is really working)
1. **The systems core is deep and real** — siege director (full ADR-035 spec, 4-squad assault, mortar walk-in, illum, break ratio), 2,862-line enemy AI with hot-set budgeting and the hunt net, complete casualty/medical chain both player and squad, save/load with migration, 24-voice audio, decal-capped VFX, destruction on one blast bus, one world-build path. This is not a prototype's plumbing.
2. **The demo path itself is honest engineering** — single-path boot per ADR-028, all four 7/30 P0s fixed, every aircraft scene resolves, the overrun chain is wired end to end.
3. **Art + animation pipeline discipline paid off** — zero broken animation requests, viewmodel validator, fossil ratchet 19→3, zero TODOs repo-wide, ~20 commits/day with origin level.
4. **Production self-correction is live** — the backlog audited itself and found 7 items already built.

## WEAKNESSES (where you are lacking the strongest)
1. **Verification, not construction.** Nearly everything is BUILT AND UNVERIFIED: test baseline stale since 7/27 across ~40 commits, HeliLift never run, demo never perf-measured, spawn-under-firebase unconfirmed after 5 fix rounds. The project ships code at 20/day and truth at 0/day.
2. **The last 30 seconds and the death path** — a stranger who dies freezes the arc forever (inert EXCLUDE_DEBRIEF); the end card is undismissable over a live game; double siren at t=60s; dawn card fires 80s before the siege actually ends.
3. **No exported build has ever existed.** The demo is F6-in-editor only.
4. **The sky thins mid-demo** — SimClock's dedup key (confirmed) collapses 3 air transits/hour to 1 and kills ambient air at t≈213s.
5. **The base reads dead in minute one** — 7 men animate 198 work markers because of one unmeasured config ceiling.
6. **Tracking docs drift** — several art-log entries are dead wrong (in BOTH directions); the canon index is rotten (ADR-035 numbered twice, ADR-024/027 ghosts, two pillar lists). Deferred, but it fooled a scout THIS session.
7. **Full-game only (recorded, not this week):** no sleep verb under the night economy, hearts & minds absent, rank gates nothing, two route systems with one dead and the live one wiped per patrol, siege has no stakes (ADR-036 blocked).

## THE WEEK'S PLAN (dependency-ordered)

### Code hands (Wyrm) — gate first, polish last
| Day | Item | Size |
|---|---|---|
| Fri-Mon | **W1. Demo export preset + non-F6 launch path + first-export smoke** (templates, debug-gated paths, string-built loads, fresh user://) | 1-1.5d |
| Mon | **W2. Death path** — make EXCLUDE_DEBRIEF real: demo death → restart-or-end-card, never a frozen arc | 2-4h |
| Mon-Tue | **W3. End card** — pausable, dismissable, mouse released; fixes dawn/siege overlap and double-siren in the same pass | 2-3h |
| Tue | **W4. Boot gate** — stop the double world-build (skip `start_default_operation` when demo_mode) | 1-2h |
| Tue | **W5. Loadout decision executed** — bench the M60 hip_position or pull it from the demo loadout | <1h |
| Tue-Wed | **W6. D3: furnish the firebase** — US interior pool + call `_furnish_interior` from the firebase path | 0.5d |
| Wed | **W7. Garrison ceiling** — measure the frame cost ONCE at siege scale, then set FSB_GARRISON_MAX_MEN. No more deferring to uncollected data | 2-3h |
| Wed | **W8. SimClock dedup key** (unique per-event keys) — yields to W1-W3 if the week compresses | 3-4h |
| Wed | **W9. M79 wiring** (.tscn + model_path — a whole weapon for 15 min) | 15m |

### Summoner's hands (Blender, parallel)
| Item | Size |
|---|---|
| **S1. D1 wire-ring split** (per-sector cards in gen_firebase_v3.py + re-export; nav re-bake hook exists) — the demo's centrepiece dependency | ~1d |
| **S2. D2 medical_complex export** into fsb_main_v3.glb | hours |
| **S3. Bunker embrasures + fighting step (D8/E3/E4)** — SUMMONER OVERRIDE 7/31: "I still need bunkers I can shoot thru." Waiver revoked under Law 3. Cut apertures in fb_bunker_mg/fb_bunker_fighting + firing step sized off 1.6m eye height; full recipe already written at `production/blender/FIREBASE_BLENDER_HANDOFF.md` §2/§2b/§2.5. Generator already flags both COL_TRIMESH so holes stay holes — fold into the same re-export session as S1/S2. Player-shootable needs NO code; AI-manned bunker positions stay deferred | ~1d |
| **S4. (conditional, only after playthrough #1 exists) __launcher family hold** — the RPG man at the climax | 2-3h |

### Summoner's eyes (the actual critical path, ADR-015)
- **Playthrough #1 on the FIRST exported build — target Monday 8/4.** Ugly is fine. Full DEMO_PLAYTEST_SCRIPT pass (45 min, 30 rows).
- One owner suite run before the fix batch, one after (baseline is 4 days stale).
- Playthrough #2 late week on the polished build.

### Waived this week (Law 2 — costs named in discussion.md)
Stale VC guns/ADS stubs, LAW/RPG-7, bunker slits, claymore FP, armorer-bench triage, Spooky barrels, VO/footsteps, embark teleport, canon-index repair, all Scout-2 full-game gaps.

## ALTERNATIVES CONSIDERED
- *Polish-first week* (fix every visible art item, export Friday): rejected — zero export loops have ever run; shipping blind on the highest-risk unknown.
- *Slip the date and do it all*: rejected — Summoner said no rush BUT the goal is to show off; a tight scope that ships beats a full scope that doesn't, and nothing waived is load-bearing for a 15-minute show.

## LAW 1 CHECK
No decree item violates a Pillar. W7 honors Forward+ ("claw FPS back within it") by measuring before spending. Waivers respect "FUN to walk + FEEL Vietnam" — everything kept is what a stranger's eyes touch.
