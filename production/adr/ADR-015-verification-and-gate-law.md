# ADR-015: Verification law + mechanical gate (process)
**Date:** 2026-07-10 · **Status:** Accepted (War Room audit #2) · **Supersedes/Amends:** the markdown-only playtest-gate law of the 7/9 decree (commit `0822a1c`); amends the Session Completion process in `CLAUDE.md` (closing criteria for beads).

## Context
Audit #1's decree (commit `0822a1c`, 07-09 16:37) adopted a playtest-gate law in markdown: no new features while playtest P1 bugs are open. The law was violated within the same working session — BLOOD v2, a new system, landed at 18:36 (commit `84f0449`) with three playtest P1s still open, and 27 commits landed between decree and audit #2 while every playtest bead stayed open. Measured half-life of a markdown law: **~2 hours**. A law that exists only as prose in a file the workflow never consults is a wish, not a mechanism.

The second force is recorded-but-unreal work. Bead o18o (stealth witness fix, P1) was listed among "decree items executed," and the comment at `scripts/enemies/enemy_base.gd:189-191` claims "a silent, unwitnessed kill no longer summons the QRF" — but `take_damage()` still calls `_set_tier(AlertTier.COMBAT)` unconditionally at `enemy_base.gd:1497`, which stamps the global detection beacon at `:626-627` and plays the contact sting at `:641`. A ghost kill still trips "YOU'VE BEEN MADE." Similarly, commit `96114f5` (16:59) closed damage unification as done while ~20% remained: four live WW2 `.tres` files and a Mosin one-shot (1d10+68) on the basic vc_rifleman. The comment lied, the bead lied, and Pillar 3's score fell from 3.4 to 2.9 on the strength of work the ledger said was finished.

The third force is blind green. The test suite reports 38 passing scenes while the Summoner's own eyes see speck soldiers (ModelActor k=0.02–0.20 observed vs ~0.9 expected), popping terrain (3 km streaming policy on a fully-loaded 1280 m map), and a dead jungle. Headless boot tests verify that code runs, not that the game looks or performs like a game. Green without eyes certified a build the pillars would have failed.

## Decision
Process laws become mechanisms enforced by the tools, not prose enforced by memory. Three laws, binding immediately:

- **1. GATE BEAD (mechanical feature gate).**
  - Create one standing GATE bead in the RECONgame beads DB.
  - Every open playtest P1 blocks the GATE bead (`bd dep add <gate> <p1>` per open P1; maintained as playtests file new P1s).
  - Every new feature epic is blocked by the GATE bead at creation: `bd dep add <epic> <gate>`. Consequence: `bd ready` physically hides feature work while any playtest P1 is open.
  - **Exempt** (may proceed while gated): bug fixes; presentation/HUD work for already-shipped systems; items explicitly ordered by a standing decree.
- **2. VERIFICATION LAW (closing criteria).**
  - No decree item and no playtest P1 closes without one of: a headless probe, a cited measurement (before/after numbers), or a verified playtest observation.
  - The words "mitigated," "investigated," and "likely fixed" NEVER close a bead. They may only be recorded as comments on a still-open bead.
  - The closing comment must name the proof (test scene path, measurement, or playtest bead/checklist item).
- **3. TRUTH LAW (comments and canon).**
  - A code comment may not claim a behavior that a probe has not verified. Aspirational comments are written as `## TODO(<bead>):`, never as statements of fact. The lying comment at `enemy_base.gd:189-191` is the type specimen — delete it or make it true (o18o).
  - The Bible/GAME_GUIDE is amended by explicit decision only, never silently.
  - The test suite gains eyes: (a) a rendered-scale probe asserting per-character k-values (or screenshot check) so speck soldiers can never again coexist with 38 green scenes; (b) a gating FPS number — a measured baseline below which the suite fails.

## Consequences
**Buys:** laws with a half-life longer than 2 hours — `bd ready` cannot be violated by enthusiasm the way a paragraph can. The ledger becomes trustworthy again: a closed bead means proven, an open bead means real work. The next o18o becomes structurally impossible to record as done.

**Costs (named, per council law):** feature velocity is genuinely sacrificed — that is the gate's purpose, not a side effect. Every close now carries probe/measurement overhead; small fixes get slower. The FPS gate will hold the suite red until Trust-Restoration Day produces a number, meaning the suite is *expected* to fail for a period — the team must tolerate honest red instead of comfortable green. Bead hygiene overhead grows (dep edges per new P1 and per new epic).

**Work created:** create the GATE bead and wire deps to the seven open playtest P1s (o18o, a2qb, r4bk, e6qc, n2ij, zet2, ida9) — no GATE bead exists yet as of this writing; build `tests/test_stealth_witness.tscn` (silent kill → `last_combat_contact_ms` unchanged) as o18o's closing probe; add the rendered-scale probe and the FPS gate to the suite (decree build-order item 2 supplies the baseline number); rewrite `enemy_base.gd:189-191` to truth.

## Evidence
- `0822a1c` (07-09 16:37, decree adopts gate law) → `84f0449` (07-09 18:36, BLOOD v2 ships with 3 open P1s): the 2-hour half-life. 27 commits landed decree-to-audit with playtest beads open (devils_advocate.md:10, :34).
- `scripts/enemies/enemy_base.gd:189-191` — comment claims witness guard exists (verified present, verbatim).
- `scripts/enemies/enemy_base.gd:1497` — `_set_tier(AlertTier.COMBAT)` called unconditionally in `take_damage()` (verified).
- `scripts/enemies/enemy_base.gd:626-627, 641` — COMBAT tier stamps global beacon `last_combat_contact_ms` and plays `GunFX.play_combat_sting` (verified).
- `96114f5` (07-09 16:59, "beads: damage unification closed") — closed at ~80%: live WW2 `.tres`, Mosin 1d10+68 on vc_rifleman (synthesis.md, systems_designer.md:33).
- Beads o18o, a2qb, r4bk, e6qc, n2ij, zet2, ida9 — all confirmed P1/OPEN via `bd show` on 2026-07-10.
- 38 green test scenes vs. observed k=0.02–0.20 character scale, terrain pop, dead jungle (synthesis.md "wounds" 2; n2ij).

## Related
- **ADR-005** (detection beacon witness rule) — the design o18o was supposed to implement; this ADR supplies its closing probe requirement.
- **ADR-001** (renderer of record), **ADR-002** (character scale contract) — the rendered-scale probe enforces ADR-002 mechanically.
- **ADR-006** (scoring economy) — its RECON-scoring bead closes only under the Verification Law.
- Beads: GATE bead (to be created), o18o, ida9 (PLAYTEST R3, session entry point), n2ij.
- Pillars served: all five, indirectly — this ADR protects the *scorecard's honesty*; most directly Pillar 3 (Freedom), the pillar the drift wounded.
