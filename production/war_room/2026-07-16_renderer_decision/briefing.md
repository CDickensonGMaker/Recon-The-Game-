# War Room — Renderer Decision (Forward+ vs Mobile) — 2026-07-16

## The question
`rendering/renderer/rendering_method` was UNSET → engine default **Forward+**. Bead `365s` #3 owes a
deliberate renderer choice for the Intel UHD target. Should RECONgame ship on **Mobile**?

## Measured facts (bead t5mo, perf_probe, seed 2077, scale=1.0, vsync OFF, Intel UHD Graphics, Godot 4.7)
- **Forward+ native baseline (AO-center spawn, stationary): ~29.2 FPS** (clean-window avg). Under the 30 gate.
- **Mobile (same everything): 40.9 FPS.** +40%, clears the 30 gate **at native resolution**.
- Per-system attribution proved the frame is **fragment/fill/pipeline-bound, not primitive-bound**:
  cutting ~100k primitives + 77 draw calls (billboard range pull) moved FPS ~0; disabling ALL billboards
  bought only +3.6 FPS on Forward+. The renderer pipeline itself was the cost — hence Mobile's big win.
- Visual A/B (screenshots): Mobile render is clean and on-aesthetic (terrain/foliage/water/viewmodel/HUD
  all correct; arguably sharper). No black holes, no broken shaders.

## What the game uses (confirmed in code)
- Directional shadows: **OFF** (`game_world.gd:48`); patches/billboards force `cast_shadow=OFF`.
- MSAA: off. No SDFGI, SSIL, SSAO, glow/bloom, volumetric fog (only exponential `fog_density=0.004`),
  no screen-space reflections. Ambient = sky. One `DirectionalLight3D`, no dynamic point/spot lights placed.
- Upscaling: `scaling_3d/mode=1` (FSR1) + `scale=0.77` shipped. **FSR1 is Forward+-only** — on Mobile the
  scale falls back to bilinear. But Mobile clears 30 at native (scale 1.0), so upscaling is not needed.

## Mobile renderer known limitations (for the sacrifice ledger)
- No SSAO/SSIL/SDFGI/SSR/volumetric fog; simpler tonemap; ~8 omni/spot lights per mesh cap; no FSR1.
- Some HDR/glow/post differences.

## Your task
Independent verdict on: (1) Is Mobile SAFE for launch scope (Army grunt, one faction, jungle+arena)?
(2) What FUTURE pillar-2 atmosphere or pillar-1 clarity features would Mobile block (night villages with
many lights? volumetric god-rays? dynamic shadows if re-enabled)? (3) Config recommendation:
Mobile+native(1.0) vs Mobile+0.77-bilinear vs stay Forward+0.77. Name what is SACRIFICED. Write your
analysis to `analysis/<role>.md` and return a SHORT verdict only.
