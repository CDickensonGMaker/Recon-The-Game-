# ADR-001: Renderer of record: 3D PSX models; sprite matrix killed
**Date:** 2026-07-10 · **Status:** Accepted (War Room audit #2) — **RATIFIED BY THE SUMMONER, 2026-07-10:** "we are using 3d models for everything in this game… 2d sprites can be used for far away action if its helpful resource wise." This ADR is now Summoner-confirmed law, exactly as written below. · **Supersedes/Amends:** CLAUDE.md line 3 (renderer clause) · DESIGN.md §4.9 · SPRITE_INTEGRATION_PLAN.md (retired) · re-affirms the audit #1 KILL ruling that was never executed

## Context
The founding docs canonize a CULTIC-style sprite renderer. CLAUDE.md:3 sells the game as
"8-directional billboard sprite characters (CULTIC-style)", and DESIGN.md:83-84 (§4.9) specifies the
full pipeline: Blender batch-renders the rigged infantry GLBs from 8 yaw angles × ~21 animation
states into sprite sheets consumed by `Sprite3D` with camera-relative frame selection. Bead
RECONgame-9xd (P1 epic, "6 VC/NVA units × 5 weapons × 21 anims render matrix") and its child
RECONgame-j8o (P1, sprite squadmates) tracked that work, with three sheet sets actually assembled
(us_grunt/m16a1, vc2_mainforce/mosin, vc5_nva/ppsh41 under `assets/NPCs/`).

The code went the other way. Commit c67818a ("3D models are the default renderer") made
`ModelActor` the character renderer of record: `scripts/enemies/enemy_base.gd:282-302`
(`_setup_visual()`) tries `ModelActor.model_exists(unit)` first, falls back to `SpriteActor` only
when a unit has no .glb, and to a capsule if neither — with the inline comment at
`enemy_base.gd:284-285`: "3D model is the default renderer (Caleb, locked)." `ally_base.gd:82,107`
mirrors the same ModelActor-first order. Audit #1's decree ruled KILL on the sprite matrix, but the
execution never happened: at audit #2 both 9xd and j8o were still OPEN at P1 (plus kkr/e0a), no A/B
far-LOD test was ever committed, and `SPRITE_INTEGRATION_PLAN.md` still sat in the repo root as if
live.

The result was three documents describing three different renderers — CLAUDE.md (injected into
every session) taught sprites, DESIGN §4.9 canonized sprites, the code shipped 3D — while the
task graph kept a dead epic marked urgent. This is the "law rot" pattern the audit #2 decree names
as its headline: the drift was in the law and the ledger, not the code. Audit #2 re-affirmed the
KILL with the instruction "close the beads this time."

## Decision
**3D low-poly PSX characters via the ModelActor pipeline ARE the renderer. The 8-directional
sprite render matrix is dead.**

- `ModelActor` (3D .glb, PSX low-poly) is the sole default character renderer for enemies and
  allies. The resolution order in `enemy_base.gd:_setup_visual()` — ModelActor → SpriteActor →
  capsule — is the canonical fallback chain; SpriteActor exists only as a no-model fallback.
- Beads RECONgame-9xd and RECONgame-j8o are CLOSED by this ADR (children kkr/e0a close with the
  epic). No new sprite-matrix rendering work may be created or scheduled.
- Sprites may return ONLY as a far-LOD, and only if an A/B test using the 3 existing assembled
  sheets (us_grunt/m16a1, vc2_mainforce/mosin, vc5_nva/ppsh41) proves a **measured** performance
  win. That test is optional evidence-gathering, not a tracked feature; a win produces a new ADR
  before any implementation bead.
- CLAUDE.md line 3 must be amended: replace the "8-directional billboard sprite characters
  (CULTIC-style)" clause with the 3D PSX ModelActor description.
- DESIGN.md §4.9 must be amended to describe the ModelActor pipeline; the sprite pipeline text
  moves to an archived/superseded note referencing this ADR. DESIGN milestone lines that schedule
  the sprite track (DESIGN.md:98,129) are void.
- `SPRITE_INTEGRATION_PLAN.md` is retired from the repo root (delete or move to archive).
- The 3 assembled sheet sets and the Blender render tooling (`tools/render_sprite_sheets.py`,
  `assemble_sheets.py`, `vc_builder.py`) are retained on disk for the optional A/B — no further
  rendering of the remaining matrix.

## Consequences
**Buys:** one renderer, one truth. Every doc, agent session, and future council plans against the
renderer that actually exists. Character art effort concentrates on .glb models and animation
clips that ModelActor already consumes; the ally/enemy visual code paths stay unified. The task
graph sheds a dead P1 epic that was distorting `bd ready` priority.

**Costs (named — no free lunches):** ~600 already-rendered sprite frames and the 15-20hr render
matrix investment path are abandoned; the CULTIC aesthetic identity is given up in favor of PSX
3D; the theorized "perf win funds jungle density" bet (DESIGN.md:84) is forfeited unless the far-
LOD A/B someday proves it. The three assembled sheets become shelf inventory.

**Work created:** close 9xd/j8o/kkr/e0a with closure notes citing this ADR · amend CLAUDE.md:3 ·
amend DESIGN.md §4.9 (+ lines 98, 129) · retire SPRITE_INTEGRATION_PLAN.md — all folded into
decree build-order item 7 (LAW & LEDGER CLEANUP). Note: the ModelActor instance-space AABB scale
bug (tiny units, k=0.02-0.20) is a consequence of betting on this renderer and is tracked
separately under decree item 2 / bead 8pbo — this ADR makes fixing it unavoidable.

## Evidence
- `CLAUDE.md:3` — "8-directional billboard sprite characters (CULTIC-style)" (verified; to be amended)
- `DESIGN.md:83-84` (§4.9), `:98`, `:129` — sprite pipeline canon + milestone scheduling (verified)
- `scripts/enemies/enemy_base.gd:182-184` — visual doc comment: ModelActor default, SpriteActor
  far-LOD/no-model fallback (verified)
- `scripts/enemies/enemy_base.gd:282-302` — `_setup_visual()` ModelActor-first resolution; `:284-285`
  "3D model is the default renderer (Caleb, locked)" (verified)
- `scripts/allies/ally_base.gd:82,107` — same ModelActor-first pattern for allies (verified; the
  devils_advocate citation of ally_base.gd:126 is off — 107 is the `model_exists` check)
- Commit `c67818a` — "3D models are the default renderer; + council review (RTCW/MoHAA)" (verified)
- Beads RECONgame-9xd (P1 epic, OPEN at ratification) and RECONgame-j8o (P1, OPEN) with children
  kkr/e0a — `bd show` verified 2026-07-10
- `assets/NPCs/` — assembled sheet folders present (US Army and Co, Vietcong and NVA) (verified)
- `SPRITE_INTEGRATION_PLAN.md` — present in repo root at ratification (verified)
- `production/war_room/synthesis.md:60-61` — the RE-AFFIRM KILL ruling; `:100-101` — tradeoff naming
- `production/war_room/analysis/devils_advocate.md:111,125-129` · `analysis/lead_programmer.md:97-100,235-236`

## Related
- ADR-015 (process laws / mechanical gates) — the enforcement mechanism ensuring this KILL actually executes
- Beads: RECONgame-9xd, RECONgame-j8o, RECONgame-kkr, RECONgame-e0a (closed by this ADR); RECONgame-8pbo
  (ModelActor AABB scale fix, decree item 2)
- Pillars served: 2 (Atmosphere — one coherent visual language, and the AABB fix path for "speck
  soldiers") · indirectly 1 (Gunplay — hit feedback on real 3D bodies via the locational damage grammar,
  ADR-002/003 family)
