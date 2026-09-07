# PHASE 1 EVIDENCE — does cohesion already exist under another name?

**Verdict: the word "cohesion" has ZERO hits in `scripts/`. The MECHANISM is roughly 70% built and wired.**

Doc-only hits: `DESIGN.md:193` · `production/CALEB_TODO_7_22_updated.md:422` · `ADR-021-patrols.md:8`
(quoting the Summoner's own 0623 directive: *"teamwork and firing cohesion"*) ·
`war_room/2026-07-17_tiered_ai/briefing.md:35`.

## Already load-bearing (do not rebuild)

| System | Where | What it actually does |
|---|---|---|
| **Per-man nerve** | `scripts/allies/ally_base.gd:108,122,154,160,171,212,226` | `courage` rolled per MOS; `_nerve_drift` falls 0.12 per squadmate down within 25 m, floor −0.30, recovers 0.02/s **only in a real lull**. `effective_courage()` adds a `RALLY_BONUS 0.10` when the player is within 6 m **and geometrically forward of the man**. Gates cover-first and whether he will close. |
| **Squad break** | `scripts/enemies/enemy_squad.gd:118` `break_state()` — ONE authority for BOTH sides; consumed by `scripts/squad/squad_system.gd:554` | `live/peak` ratio vs a courage-shifted threshold. Toasts `SQUAD COMBAT INEFFECTIVE — BREAKING CONTACT`. Gates cover-first, blocks closing, +0.7 RETREAT. Probe: `tests/test_squad_break.gd` |
| **Two-sided suppression** | `scripts/autoload/combat_manager.gd:396,448` · `ally_base.gd:344,354` · `scripts/ai/combat_posture.gd` | Enemy fire suppresses YOUR squad and you. Instant level + `incoming_pressure` with memory. Cover-modulated accrual/recovery. Spread ×1.0→×3.2, fire ceiling 0.85, movement anchors at 0.25, flank aborts at 0.6, hard pin at 0.7, prone latch at 0.85. |
| **Refusable orders, by construction** | `scripts/ai/squad_coordinator.gd` (both sides; ally side wired at `ally_base.gd:1196,1208`) | **Exposure tokens** — leaving cover to ADVANCE/FLANK is a squad resource (3); a refused man reverts to ENGAGE. **Suppressor slot** — one elected base-of-fire per squad. **Bounding overwatch** — elements swap every 6 s. **Covering-fire census.** Doctrine as data (`data/ai/doctrine_us.tres`). Header states the law: *"Orders are REFUSABLE by construction."* Probe: `tests/test_squad_coordinator.gd` |
| **Formation + spacing** | `ally_base.gd:1420-1455,2244,2281` | Offset ring halted; **staggered file** above 3.2 m/s with hysteresis; point man 12 m ahead. Spacing is an **output only** — nothing reads dispersion as an input. |
| **Comms model — but only for fire support** | `scripts/missions/field_director.gd:363,813` · `ally_base.gd:246,298,1846` | `RTO_RADIO_RANGE 10 m`, living RTO required, returns a refusal string. Cord leash 8 m gates the RTO's own verb set. **Squad orders bypass all of it — telepathic, instant, infallible.** |
| **Identity / permadeath** | `scripts/squad/squad_roster.gd` | Names, faces, MOS, learn-by-doing skills, rank by missions, earned nicknames, real KIA, radio handoff on RTO death. |
| **Squad HUD strip** | `scripts/ui/mission_hud.gd:249,311` | Surname + status pip **derived purely from HP**. RTO net row, point-man scan row. **Nothing displays break, suppression, nerve, order mode, or acknowledgement.** |

## Genuinely absent

a. Any squad-level scalar other than the **binary** `squad_broken`.
b. Dispersion, isolation, leader loss and radio loss as morale inputs — **only casualty count moves nerve.**
c. **Visible order refusal.** *(see below — this is the finding)*
d. Any latency or comms gate on squad orders.
e. An ally-side shared-knowledge blackboard (the enemy's contact/breadcrumb/HUNT machinery has no friendly twin).
f. A regroup/rally ORDER (only the 6 m passive rally bonus, and a FOLLOW catch-up **teleport** at >40 m).
g. Any HUD readout of morale, suppression or order state.

## THE FINDING

`order_mode` is read **only inside `_execute_idle`** (`ally_base.gd:1390-1470`). A man in COMBAT,
SUPPRESSED or SEEKING_COVER never reads it (RESCUE alone pre-empts, at `:1349`).

> **A suppressed squadmate already silently ignores MOVE / FOLLOW / HOLD, and the player is told nothing.**

The mechanic the council is convened to debate — *"under fire, your orders stop working"* — **is already
in the shipping build.** It has no affordance, so under the r4bk Law it does not exist. The question is
therefore not *should we build this*; it is *do we make what is already happening legible, or delete it.*

Secondary: `squad_move` silently drops if the ray misses (`squad_system.gd:286-288`) — no toast, no VO.
One man speaks the ack for the whole squad; there is no per-man accept or refuse.

*Compiled Phase 1, 2026-09-07, by code read. Nothing here is dead code; most is probe-covered
(`test_squad_break`, `test_squad_coordinator`, `test_squad_invariants`, `test_ally_states`,
`probe_squad_posture`, `test_low_posture`).*
