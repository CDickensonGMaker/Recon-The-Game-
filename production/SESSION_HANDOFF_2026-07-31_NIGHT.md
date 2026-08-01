# SESSION HANDOFF — 2026-07-31 NIGHT (Wyrm)

## Shipped and pushed (b75f2d37, f8350e7f)
Full War Room audit (`war_room/2026-07-31_demo_ship_audit/`) then the decree's code column:
- **`build/RECON_Demo.exe` — first exported build in project history.** "Windows Demo" preset,
  custom feature `demo`, `run/main_scene.demo` override. Export templates were never installed
  on this machine (now at `%APPDATA%/Godot/export_templates/4.7.stable`, Windows only).
- Smoke-verified IN RELEASE: boot → probe(11)@20s → 4-squad assault(45)@60s → unattended
  player KIA@70s → **end card fired correctly**. Zero script errors.
- Death no longer freezes the demo; one pausable end card (dawn + KIA), RESTART/QUIT.
- ROOT FIX: world is PROCESS_MODE_PAUSABLE — tree-pause NEVER froze the war before (GameFlow's
  ALWAYS leaked via INHERIT). Full game's pause menu is genuinely a pause now.
- Double world-build on demo boot killed; double stand-to/siren on reinforce killed.
- SimClock: per-entry dedup keys (3 air transits/hr were collapsing to 1) + air books day=-1
  (sky died at first midnight rollover).
- Garrison 24→40, work posts 12→24 — **A/B measured on the exported demo: 48.0 FPS mid-siege
  at both values.** Tradeoff named: 40 defenders vs 45 attackers may soften the overrun; dial
  back toward 28-32 if holding feels safe.
- M79 wired (scene + model_path) — whole weapon, GLB was already complete.

## HIS RULINGS TONIGHT (recorded)
1. **Firebase gets a hand-crafted finish pass, 1-2 days, before the demo** — kill the AI-isms:
   the gate, the bunkers, HQ bunker interiors (wrong faces, needless stairs), placement feel.
2. **M16/AK/M14 reloads are FINE** — the audit's "frozen hands" rows are void. The defect is
   overall stiffness vs the Mosin (the bar). He wants Mosin-style idle sway + fluidity on all.
3. Guns continue at **1/day ADS wiring**, his cadence.

## THE FINDING THAT CHANGES TOMORROW'S PLAN
**The stiffness is a stale-export bug, not an animation gap.** All five `*_rifle_idle` actions
in `fp_arms_rifle.blend` are IDENTICAL (90f, 5.7mm handIK sway, measured read-only tonight).
The GLBs: mosin 3.00s idle; **m16 0.37s / ak 0.46s / m14 0.37s — pre-sway stubs.**
Fix = re-export those three (`blender -b` pipeline only). ppsh41's GLB is not at
`viewmodels/ppsh41_fp.glb` — locate before batching.

## TOMORROW'S QUEUE
1. **His Blender day — firebase finish pass** (gate, bunkers+embrasures+fighting step, HQ
   interiors, wire-ring split per sector, medical_complex export — one export session covers
   S1/S2/S3 + his new list). A generator map of gate/bunker/stairs functions was being compiled
   at wrap; re-derive from `tools/gen_firebase_v3.py` if not in memory.
2. Re-export m16/ak47/m14 viewmodels (the stiffness fix).
3. His playtest of `build\RECON_Demo.exe` (DEMO_PLAYTEST_SCRIPT, 45 min) — the critical path.
   New rows: man the MG (M60 rounds spawn point), does 40-man garrison make holding too safe.
4. Re-export the .exe after his Blender day so what he tests is what he'd hand out.

## Watch out
- His live work open in Blender at wrap: `fp_arms_rifle.blend` — nothing was written to it.
- 155 dirty files are HIS (art + weapon .tres) — stage by path only, never broad add.
- `build/` is now gitignored (1.4 GB exe).

## FIREBASE GENERATOR MAP (landed at wrap — read BEFORE the Blender day)
Full pipeline: fb_kit.py -> gen_firebase.py (the KIT, fam_* builders) -> gen_firebase_v3.py
(the SITE + export) -> gen_fb_interior.py. Hand-edit file is kit/firebase_v3.1.blend.

**His three named defects, root-caused:**
- **WRONG FACES = `box()` winding is inside-out** (`gen_firebase.py:135-150`) — all six index
  tuples reversed; doubleSided glTF hides the cull but shades interiors as lit-from-inside.
  Zero recalc_normals anywhere in the tools. FIX THE WINDING FIRST, then
  `refresh_family_meshes([...])` once BEFORE any hand-sculpt (after would eat the sculpt).
- **THE NEEDLESS STAIRS**: generated unconditionally — `gen_firebase.py:612-614` (TOC: 5
  treads for a 1.15m sink) and `:354-356` (sleeping bunker). Delete the loops, refresh.
- **THE GATE** is 22 boxes at one polar coords (`fam_gate_gap` `gen_firebase.py:447-469`,
  placed `gen_firebase_v3.py:992`) with a ±7.5° suppression wedge — a hole, not an approach.
- **AI-ism structure**: bunkers are a strict mod-4 cycle on a uniform ring offset
  (`gen_firebase_v3.py:964-975`); guns a perfect pentagon r=30; hootches a sine wave; total
  rotation budget ±3.4°. Structural, not fixable by jitter constants.

**WORKFLOW LAW for the hand pass (the generator's own comments say this):**
1. NEVER run `gen_firebase_v3.main()` again — `read_homefile(use_empty=True)` at :944 wipes
   placements. Retired the moment hand work starts.
2. Safe tools: `redress()` (ground/veg only), `refresh_family_meshes()` (mesh swap under
   placements), `furnish_firebase()` (fb_int_* only — hand props must NOT use that prefix),
   `legacy_garrison_markers()`, `export_firebase()` headless.
3. Hand-sculpting ONE instance: Make Single User (Object & Data) AND rename off the family
   stem (e.g. fb_bunker_mg_i.003 -> fb_hq_bunker_hand) or the next refresh deletes the sculpt.
4. `write_mound_manifest` step_h=0.9 conflicts with the handoff doc's modelled-banquette plan —
   zero step_h when the fighting step gets modelled or the two stack.
5. Back up firebase_v3.1.blend before every export run (export saves over it).
