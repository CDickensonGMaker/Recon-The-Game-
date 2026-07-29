# FINDINGS — Stage 1, the look

**Date:** 2026-07-28 · **Instrument:** `tests/probe_topo_sheet.gd` → `screenshots/topo/before_*.png`
**Method:** 5 presets × 2 seeds, rendered through the shipped `TopoSheet.render()`, AO 1,280 m,
512² sheet. Water absent (probe has no `GameplayGrid`).

---

## THE COUNCIL'S RANKED SUSPECTS WERE MOSTLY WRONG

Recorded honestly, because the ranking in `synthesis.md` §3 was reasoning without eyes and the eyes
overturned it.

| Suspect | Verdict |
|---|---|
| **S1** `int()` truncation double-band at sea level | **NOT THE BUG.** Every preset's minimum height is ≥ 0.0 (probe log). `int()` and `floori()` diverge only on negatives. Latent defect worth fixing defensively; it is not what is on screen. |
| **S2** global tonal ramp flattens relief | **Real but minor.** Visible as weak paper tone. Nowhere near the dominant defect. |
| **S3** 512²→560 px resample | **Not visible** at this resolution. Still worth fixing; not the smush. |

## WHAT IS ACTUALLY WRONG — and most of it is not the map

### F1 · Contour collapse into solid ink (RENDER-side) — the smush
`before_steep_mountains_seed1300.png`: on high-relief presets the contour bands pack tighter than one
pixel and merge into **solid brown masses**. Entire regions of the sheet carry no readable information
at all — just mud. This is the "smushed in parts" the Summoner reported.

Cause: a fixed 12 m contour interval over a 1,280 m AO with up to 350 m of relief. At 2.5 m per pixel,
steep ground crosses multiple bands per pixel and every pixel flags as a line.

Fix direction: the interval cannot be a constant. Real cartography solves this the same way — a
1:50,000 sheet of the Annamites does not use the interval of a delta sheet. Derive the interval from the
AO's measured relief, and/or suppress lines where local gradient exceeds what the interval can resolve
(real sheets omit contours on cliffs and carry a cliff symbol instead).

### F2 · Directional anisotropy — EVERY landform is combed along one diagonal (GENERATOR-side)
Visible on **every preset, every seed**. All ridges, valleys and coastlines are stretched along the same
NW–SE axis. `before_plateau_seed1400.png` is the clearest: the entire map is parallel corduroy.

Real terrain has drainage-organised structure — dendritic valleys, varied ridge orientation. This reads
as combed hair. **This is a terrain-engine defect, not a map defect** — the map is faithfully drawing
what the generator produced.

**This is a Rule #1 problem** (*the world must FEEL like Vietnam, judged by EYES*). No amount of map
polish fixes terrain that is striped.

### F3 · A hard diagonal seam, corner to corner (GENERATOR-side)
A straight dark line runs top-left to bottom-right on `coastal_hills_seed1000` and `plateau_seed1400`.
Straight lines of that length do not occur in natural terrain. A discontinuity in the noise or a
domain-warp wrap.

### F4 · PLATEAU is not a plateau (GENERATOR-side)
Probe log: `plateau` seeds 1400/1401 both produce **relief 350.0 m, min 0.0, max 350.0** — byte for byte
the same envelope as `steep_mountains`. `tests/test_terrain_relief_bounds.gd:29` budgets PLATEAU at
**200 m**. The rendered sheet shows dense ridges everywhere and no flat ground whatsoever.

Both `steep_mountains` and `plateau` saturating at exactly 0–350 suggests the relief target is clamping
at `WORLD_HEIGHT_MAX` rather than at the preset's own scale.

**Why the existing probe does not catch this:** `test_terrain_relief_bounds.gd:85` generates at
`terrain_size = 257` and scales by `intended_scale`, while the game runs 641 cells scaled by
`WORLD_HEIGHT_MAX` (`terrain_manager.gd:57`). The suite measures a different terrain from the one that
ships. **That is a probe blind spot and it is the more important finding of the two.**

---

# CORRECTION, same session — F2 and F3 were the INSTRUMENT, not the game

**F2 (diagonal corduroy) and F3 (the corner-to-corner seam) do not exist in the game.** They were
produced by a defect in `probe_topo_sheet.gd` itself.

The probe derived `engine.terrain_size = int(map_size / cell_size) + 1 = 641`. But
`HeightmapStorage._init` computes `size = ceil(1280/2) = 640`, chunk-aligned to 640
(`heightmap_storage.gd:22-35`). Pouring 641² floats into a store indexed `z * 640 + x` **shears every
row by one cell.** A one-cell-per-row shear is exactly diagonal corduroy, and the wrap is exactly a
straight diagonal seam.

The game never had this: `terrain_manager.gd:96` sets `terrain_generator.terrain_size = heightmap.size`.
The probe reproduced the game's *pipeline* but not its *contract*.

**Fixed** — the probe now takes `terrain_size` from the storage, as the game does. After the fix, the
corduroy and the seam are gone on every preset and the terrain renders isotropic and drainage-organised.

**Two hypotheses were tested and refuted before the real cause was found**, both recorded so nobody
retries them:
- *Frequency magnification* (presets tuned for 1537 cells, run at 641): refuted — scaling frequency
  ×2.4, ×4, ×8, ×16 changed feature size but never removed the streaks.
- *Noise type* (SIMPLEX_SMOOTH FBM anisotropy): refuted — PERLIN, SIMPLEX and VALUE_CUBIC all showed
  the identical seam, which is what finally proved the artifact was deterministic and therefore ours.

**Method note worth keeping:** a defect that survives every change to its supposed cause is not that
defect. The seam persisting across four unrelated noise types was the tell.

---

# WHAT WAS ACTUALLY WRONG, AND WHAT WAS FIXED

## F1/F4 · The relief scaler overshot every preset by ~2.7× — REAL, FIXED

`_scale_heightmap()` used `scale = target_relief / (std * 2.0)` while its own comment promised
*"~95% of the distribution fits inside target_relief."* 95% of a normal distribution is ±2σ — **4σ
total** — so the divisor was half what the stated intent needed, and across 410k samples the tails
pushed peak-to-valley to roughly 2.7× target on every preset. STEEP_MOUNTAINS and PLATEAU then hit the
`clampf(…, 0.0, 1.0)` and came back **with their peaks and valleys sheared flat**, which is why PLATEAU
was byte-identical in envelope to STEEP_MOUNTAINS.

**Fix:** relief is now measured as a percentile spread (1%–99%) rather than inferred from σ, plus a
`RELIEF_MAX_SPAN` ceiling that makes clipping against the [0,1] clamp impossible. It only ever scales
DOWN, so it is not the old ratchet.

**Measured, `TerrainConfig.preset_relief()` target vs. probe:**

| Preset | Target | Before | After |
|---|---|---|---|
| COASTAL_HILLS | 25 m | 66.0 | **28.8** |
| RIVER_VALLEY | 40 m | 112.6 | **49.0** |
| ROLLING_HILLS | 90 m | 245.8 | **118.6** |
| STEEP_MOUNTAINS | 300 m | 350.0 *clipped* | **343.0**, min 3.9 / max 346.9 — no clipping |
| PLATEAU | 160 m | 350.0 *clipped* | **198.9**, min 69.2 / max 268.1 — distinct from mountains again |

## F5 · The relief probe has been green while measuring the wrong terrain — REAL, OPEN

`tests/test_terrain_relief_bounds.gd:110` passes `intended_scale` as the height basis; the game decodes
with `WORLD_HEIGHT_MAX` (`terrain_manager.gd:57`, `heightmap_storage.gd:12`). For COASTAL_HILLS the test
computes ~4.7 m against a 30 m budget and passes comfortably — while the shipped terrain was 66 m.
It also generates at `terrain_size = 257` rather than the 640 the game uses.

**This is why a 2.7× overshoot shipped under a green suite.** The unit conversion must be corrected or
the guard is decorative. Not fixed in this pass — it is a test change and wants its own verification.

## F6 · The slope budgets could never fail — REAL, FIXED

With F5's unit bug corrected the suite still reported `slope=0.0%` / `steep=0.0%` for a 336 m massif.
`test_terrain_relief_bounds.gd:140` treated `gx`/`gy` — **normalized** height deltas — as rise/run
directly. True gradient is `delta * height_scale / cell_size`, so every slope reading was understated by
350/2 = **175x**. Three of the suite's four assertions (avg slope, steep %, and effectively roughness)
were mathematically incapable of failing.

**Fixed.** With real numbers the suite immediately went red and told the truth: **78–84% of the
STEEP_MOUNTAINS AO was steeper than 30°** against a 45% budget. Unwalkable ground, straight into Rule #1.

### Retuning STEEP_MOUNTAINS to something a man can patrol

Measured, in order — note relief alone was NOT the cause:

| Change | relief | avg slope | steep % |
|---|---|---|---|
| as found (target 300 m) | 336.7 m | 43.3° | **78–84%** |
| target 300 → 200 m | 224.5 m | 33.6° | 58–67% |
| + ridge_blend 0.6→0.3, cliff_sharp 4.0→2.0, smoothing 1→3 | 220 m | 33.7° | 58–62% |
| **+ base_freq 0.003→0.0016, octaves 5→4, persistence →0.40** | **214.8 m** | **23.1°** | **16–35% PASS** |

The steepness lived in the **fine octaves of the base noise**, not in gross relief and not in the ridge
pass. Softening ridges barely moved it; enlarging the landforms and draining energy out of the high
octaves moved it decisively. STEEP_MOUNTAINS now reads as a massif with a summit, radiating spurs and
saddles rather than a field of spikes.

**All five presets PASS all four budgets across 25 seeds, with metrics that can now actually fail.**

## F7 · Fixed contour interval — REAL, FIXED

A constant 12 m interval cannot serve a 25 m delta and a 200 m massif. Coastal hills rendered with
**two contour lines** on the whole sheet; mountains rendered as solid ink. `TopoSheet.choose_interval()`
now picks from a period-plausible ladder (2/5/10/20/25/40/50 m) targeting ~15 bands across measured
relief, and the sheet margin states what it was actually drawn at. Measured: coastal 2 m, river 5 m,
rolling 10 m, mountains 20 m, plateau 20 m.

Also fixed in the same pass: `floori` for the band index (defensive — exposed only once water carving
puts heights below zero), and paper tone now ramps across the 5–95% percentile band so one peak stops
flattening every metre the player walks.

## CONSEQUENCE FOR THE PLAN

Stages 2–4 were written against the wrong diagnosis and must be rewritten:

- **Stage 2** (`floori`) demotes to a defensive one-liner, not a fix for anything visible.
- **Stage 3** (tonal ramp) stands, minor.
- **Stage 4** (resample) stands, minor.
- **NEW Stage 2a — adaptive contour interval.** This is the actual fix for the reported defect and it
  is the highest-value item in Phase A.
- **NEW — terrain-engine track.** F2/F3/F4 are not map work. They are a separate investigation into
  `terrain/core/terrain_engine.gd` and belong in their own council. Flagged to the Summoner rather than
  absorbed silently, because striped terrain and a fake plateau outrank every cartographic nicety in
  this plan.

## Reproduce

```
Godot_v4.7-stable_win64_console.exe --headless --path . res://tests/probe_topo_sheet.tscn
```
First run pays the full asset import (~25 min cold, 2.1 GB `.godot`). Warm runs complete in seconds.
