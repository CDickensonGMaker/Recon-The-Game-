# DECREE — The sheet is surveyed cartography. The pencil is yours.

**Date:** 2026-07-28 · **Status:** Awaiting Summoner approval (design phase; no code cut yet)
**Depends on:** ADR-022 (two-layer law), ADR-030 (period HUD deferred), ADR-021 (intel economy)

---

## 1 · THE THIRD LAYER ALREADY EXISTS, AND IT IS CALLED THE PAPER

The council's central finding: the Summoner's first ask needs **no new law and no ADR-022 amendment.**
`topo_map.gd:16-24` already ratified the exact reasoning for roads —

> *"Roads are BASE SHEET, not intel. A 1968 survey map prints roads for the same reason it prints rivers
> and contours: they are surveyed cartography, permanent terrain… they are the paper, not a mark on it,
> and ADR-022's two-layer law governs MARKS."*

A firebase and a surveyed hamlet are the same class of object as a road. **ADR-022 governs marks; this is
paper.** The firebase and the major villages get printed in the contour ink, at contour weight, from
mission start — furniture, not destinations. Saturated colour stays reserved for the grease pencil.

### What prints, and what does NOT

| Prints on the sheet | Stays off |
|---|---|
| `firebase_main` — your own installation | `vc_camp` — nobody surveyed it |
| `village` — **major sites only** (see §2) | small hamlets / outlying huts |
| roads, rivers, contours (already) | `lz` — a helicopter LZ is this week's decision, not cartography |
| named terrain features | `temple` in deep bush — ruins the discovery |

**Why the split matters (the sacrifice, named):** printing *every* village would delete ADR-021's
"you learn the ground" economy — the reason a contactless patrol was still worth the evening. Printing
*none* makes the player an amnesiac who doesn't know where he lives. The line is **surveyed vs. found.**

## 2 · THE SHEET IS AN ACCURATE SURVEY — SUMMONER'S RULING, 2026-07-28

The council proposed deliberate survey error: real L7014 sheets ran on 1950s French survey data with
patchy photo revision, and patrols did walk to printed hamlets that were no longer there. The proposal
was to seed ghost hamlets and unprinted hamlets at world-build.

**RULED AGAINST.** Summoner, verbatim:

> *"i think from a gaming perspective it should be an accurate map of the game they are playing on just
> like arma does"*

**The sheet is an accurate survey of the world that was built.** Generated at world-build, static
thereafter. No seeded ghosts, no omissions, no deliberate divergence.

**The reasoning, for future councils:** Arma's map is an accurate survey; the fog is in *where they are*,
not *where the ground is*. A map that lies about geometry is not fog of war — it is the game cheating,
and it is indistinguishable from a bug to the player reporting it. It also collides head-on with ADR-022:
being wrong on paper is supposed to be **the player's error on the player's pencil**, never the sheet's.
Falsifying the base sheet would hand the game the exact power the grease-pencil law denies it.

**Note this does not resurrect reconciliation.** The layer is still built once and never re-derived — a
village destroyed later in a campaign does not redraw the paper, for the same reason Arma's map does not.
Accuracy is a property of the survey moment, not a live binding.

## 3 · THE SMUSH — three suspects, all with pointers

**The council did not see the defect.** The Summoner reported it with his eyes, and Rule #1 makes his
eyes the authority. These are ranked suspects, not findings. **Step 1 of implementation is to LOOK at
the sheet on the flat delta preset and on the 350 m mountain preset before changing one line.**

**S1 — the double-width band at sea level (most likely).** `topo_map.gd:68` and `:71-73` compute the
contour band as `int(h / CONTOUR_INTERVAL)`. **`int()` truncates toward zero**, so band 0 spans
−12 m…+12 m — *twice* every other band. Any terrain near sea level gets one conspicuously wide,
featureless zone with no contour line through it. On the delta preset (relief 30 m,
`tests/test_terrain_relief_bounds.gd:17`) that band is most of the map. Fix is one word: `floori()`.

**S2 — the global tonal ramp flattens everything.** `:78` shades paper by
`t = (h − h_min) / (h_max − h_min)` across the *whole* map. On the 350 m mountain preset
(`test_terrain_relief_bounds.gd:26`) one peak sets `h_max` and compresses all the walkable ground into a
narrow tonal sliver — the map reads as flat mush everywhere the player actually is.

**S3 — non-integer resample.** The 512² texture is stretched into a 560×560 rect (`:103`,
`EXPAND_IGNORE_SIZE`). 560/512 = 1.09375, so 1-pixel contour lines land unevenly — some doubled, some
filtered away. Render at the display size, or display at 512.

## 4 · PERIOD FIDELITY — what a real sheet has that ours does not

Modelled on the **AMS/USATOPOCOM L7014 series, 1:50,000**, the sheets actually carried in-country.

1. **JUNGLE IS GREEN.** The single biggest miss. Real sheets screen woodland in green over the paper;
   cleared ground and paddy stay white/buff. Ours is brown everywhere. This is not only atmosphere —
   it makes the sheet *tactically readable* at a glance, which is what the intel economy needs.
   The data already exists (`ClearingSystem`, `gameplay_grid`).
2. **Paddy stipple** — a distinct fill for worked ground, not the same buff as dry open ground.
3. **Road hierarchy** — a real sheet distinguishes an improved road (double line) from a cart track
   from a trail (dashed). Ours draws every segment identically at 1.6 px.
4. **Vietnamese names in period style** — hamlets labelled `ẤP <NAME>` in small caps, generated
   deterministically from the mission seed so a province is the same province every session.
5. **Honest marginalia** — the current header reads `AO TACTICAL MAP - 1:25,000` (`:100`). On a 1,280 m
   AO a 1:25,000 ratio is decorative fiction, and the grid it claims is wrong too: real 1:25,000 sheets
   print a **1,000 m** UTM grid, ours prints 100 m. **Replace the ratio with a drawn scale bar in
   metres** (self-consistent at any window size) plus a declination diagram and a grid-reference box.
   A 100 m grid is defensible and stays — it is the precision of the six-digit grid ref a real RTO
   called in — but the sheet must stop claiming a scale it does not have.

## 5 · WHAT IS SACRIFICED

- **Printed villages shrink the discovery loop.** Mitigated by surveyed-vs-found (§1) and by the
  out-of-date sheet (§2), but it is a real cost and the Summoner should know he is paying it.
- **Green overprint costs a render pass** over `gameplay_grid` at world-build. The map already does a
  512² heightmap sample loop (`:49-53`); this roughly doubles that one-time cost. It is a load screen
  cost, not a frame cost.
- **Names are a content surface.** Vietnamese hamlet names with diacritics need a font that has them,
  and they will be the first thing a native speaker judges. Better to ship a small hand-checked name
  table than a generator that produces nonsense.
- **§4 is chrome, and ADR-030 defers chrome.** The period-HUD decree parks HUD polish until final.
  Items 1–3 are *legibility*, not chrome, and are argued in scope; items 4–5 are genuinely ADR-030
  territory and should be cut if the Summoner reads them that way.

## 6 · ORDER OF WORK

| # | Work | Why first |
|---|---|---|
| 1 | **Look at the sheet** on delta + mountain presets, both seeds | Never guess; confirm the smush before touching it |
| 2 | `floori()` band fix (S1) + per-window tonal ramp (S2) + resample (S3) | One-line-class fixes to a confirmed defect |
| 3 | Firebase + major-village printing, from `sites` | The Summoner's actual ask |
| 4 | Green canopy + paddy overprint | Biggest single fidelity win |
| 5 | Road hierarchy, scale bar, names | Tapers into ADR-030 territory |

**Gate:** items 1–3 are the approved slice. 4–5 proceed only on a separate ruling.
