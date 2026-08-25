# WORK ORDER #1 (next session) — Unit texture optimization, done right

*Caleb, 2026-08-18: "id rather have the units models optimizied, save that for the first
work order when we work on the recon game proejct next."*

## What happened today (context, all reverted)

Two batch passes halved every embedded GLB image >1MB (560 → 252MB texture payload) and a
Blender-rendered before/after bench showed the pairs near-identical. Caleb reported broken
faces/bodies and a rice hat inside a head — **he later clarified he never opened the game;
he was reacting to the bench renders, which showed the untouched ORIGINAL files on the
"before" side too.** So no in-game breakage was ever established; what read as broken was
the render presentation (neutral studio light, linear filtering on PSX textures, a rear
three-quarter VC framing that hides the head under the hat brim) or pre-existing model
truth. The revert was precautionary and stands: `git checkout -- assets`, SHA1s match
HEAD, scanner confirms the original 560.07MB. The tools survive:
`tools/shrink_master_sheets.py`, `tools/shrink_oversized_textures.py` — the whole shrink
is one command to redo.

## Lessons that bind this work order

1. **Present PSX assets faithfully or not at all**: bench renders need nearest/closest
   texture filtering and front-facing framings, clearly labeled, or Caleb reads the
   renderer's smear as a broken model.
2. **The final gate is Godot + Caleb's eye**: boot the game, look at a grunt and a
   guerilla at real play distances, he confirms, THEN commit. A Blender bench is a
   pre-check, never the verdict.

## The order

1. Re-apply the shrink (`python tools/shrink_oversized_textures.py --apply` +
   `tools/shrink_master_sheets.py --apply`), or better, shrink the shared master sheet
   once at the source blend (`us_base_v3.blend` etc.) and re-export via the normal
   pipeline — the at-source fix is the one on record as preferred.
2. Verify in Godot at play distances; check character texture import settings (VRAM
   compression mode) while in there.
3. Caleb's eye passes → commit. Budget target stays: no embedded image >1MB
   (texture budget law, RECONgame CLAUDE.md).
4. Re-measure: `python C:\Users\caleb\wyrm-workshop\tools\run.py glb_textures`.
