# ADR-014: Documentation hierarchy: CANON / LOG / DEAD
**Date:** 2026-07-10 · **Status:** Accepted (War Room audit #2) · **Supersedes/Amends:** ROADMAP_NEXT.md, ROADMAP_WAVE2.md, WAVE3_REPORT.md (as planning documents); amends CLAUDE.md's role from "narrative + law" to "law + patterns only"

## Context

Full Game Audit #2 (2026-07-10) found that the project's worst drift was not in code — strict
typing held at ~3 untyped vars across 90 files — but in the documents that govern the code. The
project accumulated four competing roadmaps at repo root (`ROADMAP.md`, `ROADMAP_NEXT.md`,
`ROADMAP_WAVE2.md`, plus `WAVE3_REPORT.md` doubling as a planner) with two rival numbering schemes
(R-, W-). `ROADMAP.md:4` promises "Canon detail lives in `production/bible/`" and "Task truth
lives in beads" — but the bible index (`production/bible/BIBLE.md:19-32`) shows only 2 of 12
sections written (05, 09), 4 seeded inline, 6 empty stubs, with just 3 files on disk. Canon lived
nowhere, so every session-end wrote a *new* dated report instead of updating a canonical one —
the structural failure mode named in the devil's-advocate analysis (§"DOC ROT AS PROCESS FAILURE").

The most dangerous rot was in CLAUDE.md, because it is injected into every model session. This
audit found it false three ways, all verified: it sells "8-directional billboard sprite characters
(CULTIC-style)" while the renderer of record is 3D ModelActor (ADR-001); its Damage System section
teaches the dead HoD grammar (`[1,6,45] = 1d6+45`, "Enemy HP: 60-80") against the live RECON-dice
grammar (ADR-003); and it declares "FOV locked at 75.0 everywhere (no ADS zoom)" while
`scripts/player/weapon_holder.gd:215-220` has per-weapon ADS zoom live since W40 (ADR-004). A
stale CLAUDE.md is not cosmetic — it is a **drift generator** that re-teaches the dead game to
every fresh session. The same class of rot: PLAYER_MANUAL.md stale within 48 hours of writing
(audit counted 9 gaps: squad secondary keys, hub `[E]` vs manual `F` interact, F5/F9 saves,
rations kit, the entire hub/survival loop), and a code comment at
`scripts/enemies/enemy_base.gd:189-191` claiming a stealth fix that `enemy_base.gd:1497`
(unconditional `_set_tier(AlertTier.COMBAT)` in `take_damage()`, beacon read at
`scripts/missions/mission_director.gd:68-71`) disproves. When "documents" can silently disagree
with code and each other, the council cannot know which one is lying.

## Decision

Every project document belongs to exactly one of three classes. Enforce the class rules.

- **CANON** — `production/GAME_GUIDE.md` (top of the hierarchy), `production/bible/` sections,
  and `production/adr/`. Canon is amended only by explicit decision (an ADR or a decree recorded
  in one), **never silently**. If code contradicts canon, one of them is wrong — a bead or ADR
  resolves the conflict; neither side drifts quietly.
- **LOG** — dated reports: PROGRESS_REPORT, WAVE reports, NIGHTSHIFT, OVERNIGHT_*, CODE_AUDIT,
  WIRING_STATUS, and kin. Logs are disposable snapshots. They are **never cited as authority**,
  may never hold the only copy of a decision, and are archived freely without ceremony.
- **DEAD** — `production/war_room/archive/` and any superseded document. Dead docs are history,
  not reference. Nothing plans against them.
- **Roadmap consolidation:** the four roadmap files collapse into `ROADMAP.md` alone.
  ROADMAP_NEXT.md, ROADMAP_WAVE2.md, and WAVE3_REPORT.md (as a planner) are DEAD; anything in
  them still true moves into ROADMAP.md or a bead before archival.
- **Task truth lives in beads, never markdown.** A markdown TODO or roadmap bullet is not a task;
  `bd ready` is the only work queue.
- **PLAYER_MANUAL.md is CANON-adjacent:** it must track the input map. Any input-map or
  player-facing control change updates the manual in the same session or files a bead.
- **CLAUDE.md stays minimal — law + patterns only — and MUST match the ADRs.** Its false
  sections (damage grammar, sprite renderer, FOV/ADS) are rewritten to code truth now (decree
  build-order item 7 / item 4). Session close updates canon in place instead of minting new
  reports.

## Consequences

**Buys:** one place to look per question (design → GAME_GUIDE/bible, decision → ADR, task → bead,
history → logs); model sessions stop being re-taught dead systems by their own law file; "which
doc is right" becomes a decidable question (CANON outranks everything except a newer explicit
decision). **Costs (named, per council law):** session-end convenience is sacrificed — writing a
fresh dated report is easier than amending canon, and this ADR forbids the easy path for
decisions; roadmap consolidation discards the W-numbering scheme and any planning nuance not
migrated; canon maintenance is a recurring tax on every session close. **Work created:** decree
item 7 (LAW & LEDGER CLEANUP) — consolidate roadmaps into ROADMAP.md, correct PLAYER_MANUAL,
rewrite CLAUDE.md's damage/renderer/FOV sections, promote GAME_GUIDE.md + ADRs to canon; the
enforcement mechanism (session-close doc hygiene, truth law) lands with ADR-015's mechanical
process laws and its GATE/verification beads.

## Evidence

- Four roadmap files at repo root — verified present: `ROADMAP.md`, `ROADMAP_NEXT.md`,
  `ROADMAP_WAVE2.md`, `WAVE3_REPORT.md`.
- `ROADMAP.md:3-4` — "Canon detail lives in `production/bible/`. Task truth lives in beads" — verified.
- `production/bible/BIBLE.md:19-32` — section map: 2 of 12 ✅, 4 🌱, 6 ⬜; only 3 bible files exist — verified
  (the audit's "9/12 unwritten" understates it: 10 of 12 lack their own written doc).
- CLAUDE.md falsehoods — verified against live file: line 3 "8-directional billboard sprite
  characters"; Damage System section "`[1,6,45] = 1d6+45` … Enemy HP: 60-80"; "FOV locked at 75.0
  everywhere (no ADS zoom)".
- `scripts/player/weapon_holder.gd:215-220` — "W40: ADS FOV zoom re-enabled (per-weapon ads_fov)" — verified.
- Lying-comment specimen: `scripts/enemies/enemy_base.gd:189-191` (claims unwitnessed kills no
  longer summon QRF) vs `enemy_base.gd:1497` (unconditional COMBAT stamp in `take_damage()`) and
  `scripts/missions/mission_director.gd:68-71` (beacon → "YOU'VE BEEN MADE") — all verified.
- `scripts/autoload/save_manager.gd:6-9` — save-tier ladder in a code comment only, pillar-5
  implications undocumented in DESIGN.md — verified (context for why decisions must live in ADRs).
- PLAYER_MANUAL.md 9 gaps — per audit #2 (synthesis.md "wound #6" / devil's advocate A6.7);
  individual gaps enumerated there, hub `[E]` prompt vs manual `F` interact among them.
- Decree: `production/war_room/synthesis.md` (2026-07-10), build order item 7 and "LAW ROT" wound #6.

## Related

- **ADR-001** (renderer of record), **ADR-003** (one damage grammar), **ADR-004** (ADS FOV
  policy) — the three CLAUDE.md sections this ADR forces into agreement with canon.
- **ADR-005** (detection beacon / witness rule) — the lying-comment case that motivates the truth law.
- **ADR-015** (decree enforcement mechanism, forthcoming per synthesis "Process laws") — the
  mechanical teeth; ADR-014 defines the classes, ADR-015 enforces the workflow.
- Beads: decree item 7 (law & ledger cleanup) and o18o (witnessed-contact fix, the canon-vs-code
  conflict of record).
- Pillars served: all five indirectly — a law book that teaches the dead game corrodes every
  pillar decision; process-compliance score 1.5 was the audit's floor.
