# ADR-001: Renderer of record: 3D PSX models; sprite matrix killed
**Date:** 2026-07-10 · **Status:** Accepted (War Room audit #2) — **RATIFIED BY THE SUMMONER, 2026-07-10:** "we are using 3d models for everything in this game… 2d sprites can be used for far away action if its helpful resource wise." This ADR is now Summoner-confirmed law, exactly as written below. · **Supersedes/Amends:** CLAUDE.md line 3 (renderer clause) · DESIGN.md §4.9 · SPRITE_INTEGRATION_PLAN.md (retired) · re-affirms the audit #1 KILL ruling that was never executed

> **POINTER CORRECTION, 2026-07-19 — the ruling is unchanged; only its citations were checked.**
> Every `DESIGN.md §4.9` reference in this ADR (`:2, :24, :44, :64`) is a **dead pointer**: `DESIGN.md`
> has no numbered sections at all — its headings are prose. The amendment this ADR ordered there has no
> target, so nothing is owed against it. The ADR's substance is intact and remains law: **3D models for
> everything; the sprite renderer is dead.** Corrected downstream this pass:
> `../bible/09_CHARACTERS_ART.md` still listed the killed sprite pipeline as owed work.

## AMENDMENT A — THE SPRITE CARVE-OUT IS REVOKED (Summoner, 2026-09-08)

**His words, verbatim:** *"i'm still!! seeing the 2d billboard plants as the smaller terrain all over
the world when i need those to be the 3d terrain models we've made or added to the project. no more 2d
terrain cards, or 3d plane spliced cards or whatever. all 3d blender models only in game"* — and
immediately after: *"besides the barbwire since that works better as cards or whatever"*.

**What this changes.** The ratification line at the top of this ADR left one door open: *"2d sprites can
be used for far away action if its helpful resource wise."* **That door is now closed.** Every plant
renders as a real 3D mesh at every distance. No impostor cards, no crossed quads, no star-fans, no
billboards. Where the far ring genuinely cannot afford the full solid, the answer is a **lower-poly LOD
MESH of the same plant** — still a real 3D model — never a card.

**THE ONE EXEMPTION: barbwire.** `assets/us/props/emplacements/barbwire_card.glb` stays a card by his
explicit carve-out. Nothing else inherits it.

**Note this is his SECOND raising of it.** Treat it as a standing ask that was not executed, not a new
idea.

**What it makes dead.** The far-LOD A/B this ADR permitted ("Sprites may return ONLY as a far-LOD, and
only if an A/B test proves a measured performance win") can no longer produce a shippable result for
vegetation, because a win would not license a card. The canopy card atlas planned as Phase 2a of the
graphics work is cancelled with it — there will be no cards to atlas.

**Scope of the work this creates, as surveyed 2026-09-08 (pointers, not estimates):**
- `terrain/vegetation/tree_cover_layer.gd:15` `CARD_DIR`, consumed at `:166-169` and `:224-226` — the
  40-card far ring at 65-350 m. 28 species are actually planted (`vegetation_manager.gd:47-55`).
- `scripts/world/ground_clutter.gd:26-35` — 7 of 8 layers are `QuadMesh` billboards with
  `CULL_DISABLED`; the 8th rides `grass_fan.glb`, a 6-triangle star-fan, which the ruling also names.
  Second star-fan call site: `scripts/levels/gore_lab.gd:201-236`.
- `tools/gen_firebase_v3.py:529-546, 566-612` — **~360 vegetation cards are BAKED INTO the shipped
  firebase GLB** as `fb_veg_*` merged meshes. This is an art bake, not runtime code: re-running that
  script is the only way to change it. It is the least visible half of the work and it must not be
  forgotten.
- Orphaned low-poly plant meshes exist, but **only some of them are real** - corrected 2026-09-08 after
  a geometry audit (face-normal count, planarity, area distribution), because triangle count alone
  cannot tell a model from a card. **REAL:** `lp_bush_a` (36 tris, 16 normals), `lp_bush_b` (36/15),
  `lp_bush_c` (54/18), `lp_fern_a` (72/29), `lp_fern_b` (108/46), `lp_grass_tuft_b` (54/23) - genuine
  low-poly volumes and the correct starting stock for the far-ring LOD meshes. **CARDS, do not use:**
  `lp_grass_tuft_a`, `lp_sprout_a`, `lp_sprout_b`, `lp_sprout_c` - all 6 tris / 3 normals with area
  split in exact thirds, i.e. three crossed quads, the same construction as `grass_fan.glb`. An earlier
  line here called the whole `lp_*` set real 3D; that was wrong and is retracted.
- **Two shipped assets that LOOK like models and are not:** `fallen_log_a.glb` (184 tris but 12 normals,
  90.9% of area near-horizontal, 69% on one downward sheet) and `fallen_log_b.glb` (97.1% horizontal,
  4:1 flat cross-section) are flat ribbons. `moss_a/b.glb` are flat ground decals (100% horizontal),
  which is defensible for moss. The logs are not defensible: `TreeCoverLayer.COVER_TRUNK` plants both as
  cover-givers with a 0.45 m collider, so the player is invited to take cover behind a ribbon. **OWED
  ART: a volumetric fallen log at ~2-3 m.** The only real deadwood today is `felled_trunk.glb` (8.37 m)
  and `felled_tree.glb` (a 9.3 m tree), both too large for clutter, plus `tree_stump.glb` (1.75 m, real).
- **No mushroom, fungus, flower, boulder or pebble asset exists anywhere in the project**, in any format.
  The four rocks in `assets/world/rocks/` (`rock_small_a/b`, `rock_cluster_a`, `rock_half_buried_a`) are
  genuinely volumetric (37-122 normals) and were orphaned - nothing referenced them before this ruling.

**Measured facts that bear on the swap, so it is not costed by guess** (GLB binary parse, 2026-09-08):
mean solid plant = 269 tris, mean card = 3.05 tris, an 88x triangle increase for the far ring. Against
that, the 40 card textures are 768 px wide with unbounded non-power-of-two heights up to 768x8838, and
total **173.8 MB uncompressed / 14.5 MB on disk — about 66x the unique texture bytes of every solid
plant combined** (the solids share 5 distinct textures totalling ~0.22 MB). The cards also draw with
`CULL_DISABLED` alpha fill. So the swap trades triangles for a large texture-memory and overdraw
refund, and the cost is genuinely unknown until measured — it is not assumed to be a loss.

**Status: RULED, NOT YET BUILT.** Priority was moved to the physics stalls by the Summoner on the same
day; this amendment records the ruling so it cannot be lost again while that work runs.

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
