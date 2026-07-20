# Bible 09 · Characters & Art

**Obeys Pillars:** 2 (atmosphere), 4 (attachment via recognizable soldiers). **Source:** braindump
2026-07-08. *(The old `DESIGN.md §4.9` pointer is dead — `DESIGN.md` has no numbered sections; the
renderer of record is `../adr/ADR-001-renderer-of-record.md`.)*
**Beads:** FP viewmodels epic `RECONgame-36pk`; campaign visual variety `RECONgame-4i60` children (faction types, soldier variety, slimmer models).

---

## Pipeline of record

Built in **Blender 5.0** (MCP + headless scripts), PSX/low-poly aesthetic, exported to Godot glTF/GLB
(`export_yup=True` maps Blender −Y → Godot −Z forward). Two character render paths:

> **PATH CORRECTION, 2026-07-19.** The three folders this section used to name as the pipeline of record
> — `assets/models/characters/`, `assets/models/viewmodels/`, `art_source/characters/fp_arms/` — **do not
> exist.** `assets/models/` was never created under that name and `art_source/` was deleted permanently
> (see the FOSSIL LAW entry in `../../CLAUDE.md`, the `.gitignore` rule that swallowed 1.66 GB).
> Real paths, verified: viewmodel scenes are `scenes/weapons/*_arms_viewmodel.tscn` (e.g.
> `ak47_arms_viewmodel.tscn`, `m14_arms_viewmodel.tscn`); arm textures and their anim specs are in
> `assets/player/arms/`. The US character source of truth is `us_base_v3.blend` (bd memory).

1. **Full 3D characters** — feet at origin, ~1.7132m, face −Z, sockets
   `MuzzlePoint/HandR/HandL/Head/Chest`, named animations, budget ~3–6k tris. Mixamo-rigged, gun bone-parented to `hand.R`.
2. **First-person viewmodels** (`scenes/weapons/*_arms_viewmodel.tscn`) — CC0 PSX fingerless-glove arms hold each weapon;
   one clean `arms + gun + MuzzlePoint` GLB per weapon, **same clip name `rifle_idle`** so the Godot viewmodel
   controller is written once. Feel (sway/recoil/lag) is **procedural in Godot, never baked.** Reusable **semi-auto rifle pose** captured in
   `semi_auto_rifle_pose.json` + `tools/rifle_pose.py` (0.001mm reconstruction).
   - **Bake law:** capture `pb.matrix_basis` per bone, NOT `location` + forced quaternion — IK control bones
     (`handIK/elbowIK`) are EULER-mode; forcing quaternion silently drops their rotation (100mm+ drift). See bd memory.

## Model budget & quality

- **PSX budget:** ~3–6k tris/character; textured, low-poly, retro.
- **⚠️ Known debt — "chonky" bodies (bead, `4i60` child):** current soldier/VC bodies read bulky. Fix: better
  low-poly human proportions + topology (slimmer torso/limbs, cleaner shoulder/waist loops) while staying in budget.
  Applies to the WHOLE roster going forward — fix the base mesh once, reuse.

## Modular soldier kit (drives roster appearance)

Bodies must be **modular** so 100 bios get visual variety from combinations, not 100 bespoke models.
Swappable slots keyed by the roster's `portrait_keys` (Bible 05):
- **Helmet** — several types (M1 + cover variants, boonie, beret, bare) → also carries faction identity.
- **Torso** — a few designs/textures (OG-107, tiger-stripe, flak vest, sleeves-rolled).
- **Arms** — a few (sleeved / rolled / bare), skin tone matched to face.
- **Face** — the existing face-texture set; skin-matched body.

## Faction model types — Army grunt at launch, SF/Marines = DLC

**Launch = ONE set: the US Army grunt** (M1 helmet, OG-107, standard load) on the slimmer base. All roster
variety for the 100 bios comes from the modular kit above (helmet/torso/arm/face swaps) **within** the grunt
set — plenty of variety, one silhouette to perfect.
- **Special Forces** (boonie/beret, tiger-stripe, light rig) and **Marines** (USMC cover, cammo) are
  **deferred to DLC** — helmet/torso swaps on the same slim base when built. Not launch scope.

**Tone reference for the grunt look:** Platoon / Hamburger Hill / Apocalypse Now — worn, muddy, sweat-soaked,
unglamorous. Not clean-kit operators.

## Civilians & event actors (NEW, for scripted events)

Bible 06 scripted events need non-combatant models: **roaming villagers** (men/women/kids, farm dress),
plus event-specific actors (suicide bomber reads as civilian until the beat). Low-budget, reuse VC base where sensible.

## Sprites — ⛔ KILLED BY ADR-001 (kept as history, 2026-07-19)

> **This is NOT owed work.** `../adr/ADR-001-renderer-of-record.md` is Summoner-ratified law: 3D models
> for everything; the sprite renderer is dead and `SPRITE_INTEGRATION_PLAN.md` is retired. The paragraph
> below listed a consumer-code / `_q` dedupe / manifest-muzzle-wiring backlog — **do not build any of
> it.** The only surviving allowance in ADR-001 is 2D for *far-away* action if it ever pays for itself,
> which is not this pipeline.

8-directional billboard sprites rendered from the 3D models (idle/walk/run/crouch/aim/fire/reload/flinch/death×2/prone),
AI FSM states map 1:1 to sprite states. `sprite_stage.blend` is the render source. Perf win funds jungle density.
