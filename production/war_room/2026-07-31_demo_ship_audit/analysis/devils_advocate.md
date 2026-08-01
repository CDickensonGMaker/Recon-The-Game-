# DEVIL'S ADVOCATE — Demo Ship Audit (2026-07-31)

*Individual sight. No cross-talk. Sources: briefing.md, evidence.md; law: no free lunches.*

## 1. The "art blocks" premise is a displacement, and I'll say it plainly

The Summoner suspects art blocks are the barrier. The evidence says: 2 missing res:// refs total, 163/163 clips clean, audio guard closed. Meanwhile the two things that actually gate shipping are (a) a 45-minute playtest script that only HIS eyes can discharge (ADR-015, and it has sat unrun while ~40 commits landed) and (b) a build that has **never been exported** — the demo exists only as F6 in his editor. "Art blocks" is the comfortable story because art is work you can DO; the playtest is work you can only FACE. It risks being how the week gets spent avoiding the one task that produces verdicts instead of assets. D3 proves the inversion: the props are exported and the blocker is a half-day of *code* nobody wrote. The art tree is waiting on the game, not the reverse.

## 2. What "end of next week" actually hinges on

This project's demonstrated pattern: ~20 commits/day of building, verification perpetually deferred — test baseline stale since 7/27, KnownRed empty and unproven, HeliLift never executed, demo never perf-measured, spawn-geometry landmine unconfirmed after five fix rounds. The schedule does NOT hinge on throughput. It hinges on **iteration loops of the form: export build → play 45 min → fix what died → repeat**, and zero such loops have ever been run. Realistic failure mode of 8/9: the export preset gets made on 8/7, the first cold-boot run reveals the double world build, the SimClock air-suppression bug, and the death-freeze all at once, and there is no second loop left. **The sacrifice of choosing polish items (D5 ADS swaps, D11 Spooky guns, D7 posing) over the playtest is the sacrifice of the only feedback signal that exists.** Every polish hour spent before the first exported-build playthrough is spent blind. Demand: export preset + one full script pass by **Monday 8/4**, or the Friday date is fiction.

## 3. What breaks in a stranger's hands (never in the author's)

The author never dies, never wanders, never presses the wrong key. A stranger will, in the first ten minutes:
- **Die.** EXCLUDE_DEBRIEF is inert; death mid-assault tears the world down and the arc returns forever (`demo_game.gd:244-245`). A frozen screen after the player's first death is a review-killing bug, and the author cannot hit it because the author doesn't die.
- **Press Esc at the end card.** PauseMenu builds UNDER an undismissable opaque card with mouse captured. The demo's last impression is "the game hung."
- **Walk 256m.** Nobody has documented what the edge of a 512m slice looks like; the siege ring is already 190/235m — diagonals are thin.
- **Pick up the VC AK** (WorldWeapon pickup ships) and aim down a placeholder ADS — a stub the demo itself hands you.
- **Go prone and stay there** — his own #1 predicted failure, still unverified.
- **Alt-tab** during a captured-mouse, uncapped-delta arc — untested; uncapped delta on the arc is exactly the resume-spike class.
- **Try to board the Huey** — HeliLift never run, BOARD_CLIPS empty, embark teleports.
None of these is art. All are day-one stranger behavior. This list IS the playtest script's justification.

## 4. Scope-creep traps in this audit — true findings that must NOT enter the week

Defer, explicitly and by name: canon-index rot (ADR-024/027 ghosts, double ADR-035, dueling pillar lists), the dead route system, hearts & minds absence, rank-gates-nothing, sleep verb, WorldBuilder/zero-caller classes, doc-pointer ceiling. Cost of deferral, named honestly: the canon rot will mislead a future agent within weeks (it already misled this audit's scouts once, via the SeatSystem "zero callers" fossil); the dead route chain will eat someone's day. That is the price, and it is worth paying — every one of these is invisible in a 15-minute demo. The trap is that they are *findable*, *fixable*, and *satisfying*, which is exactly the profile of work that eats a ship week. If it can't freeze, confuse, or embarrass the demo in a stranger's hands, it does not get a line in the plan.

## 5. What the polite architects won't say

- **The garrison ceiling (7 men animating 198 markers) is a five-minute number change nobody will take because it's framed as a "frame-cost decision" — while the demo scene has never been perf-measured anyway.** You cannot defer a decision to data you refuse to collect. Measure once, set the number, done.
- The 7/30 memory already ruled the bottleneck is HIS playtest. This audit re-asked the question hoping for a different answer. It didn't get one. Convening more council sessions before the playtest runs is itself the avoidance behavior — the next deliverable is not a decree, it is a save file with 45 minutes on it.
- "Zero TODO/FIXME repo-wide" is not health; combined with 3 of 4 exclude-flags inert, it means intentions aren't recorded — the discipline hid the debt.

**Named sacrifices of my own recommendation:** front-loading the playtest burns his scarce attention early and may produce a demoralizing bug list; freezing polish until after loop 1 means the first playthrough looks worse than the tree could look. Both are cheaper than shipping blind.
