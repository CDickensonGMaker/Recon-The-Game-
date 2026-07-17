# RECONgame Cinematics — Blender Reference (2000s-era FMV look)

*Synthesized from a verified deep-research pass (103 agents, 23/25 claims confirmed). Target: "forgotten 1999–2001 Vietnam game intro, remastered." Blender 5.0 / Eevee Next, standalone FMV (not shipped to Godot).*

## 1. Multi-camera cutscene mechanism — timeline markers (NATIVE, no add-on)
- Select a camera, press **`Ctrl-B` (Bind Camera to Markers)** in the Timeline. At that marker's frame the **active camera switches** to that camera.
- **Move the marker to re-time the cut.** Bound markers auto-rename to the camera + show a camera icon.
- Markers are **shared across Dope Sheet / Graph / NLA / VSE** — set cuts once, they appear everywhere. Viewport Object-Info overlay shows the current marker name.
- Source: docs.blender.org/manual/en/latest/animation/markers.html (primary).

## 2. Camera moves — built-in "Add Camera Rigs" add-on (enable in Preferences)
- Adds **Dolly Rig, Crane Rig, 2D Camera Rig** to *Add > Camera*.
- **Crane Rig**: two animatable bones — **Arm Height** and **Arm Length** (N-panel sliders when the crane is selected) → keyable crane moves.
- **2D Camera Rig**: static, locked-off "theater-stage" shot (Rotation/Shift slider) = **the locked-tripod convention** of period game intros. Use this for our briefing establishing shots.
- ⚠️ REFUTED: there is **no** "Set DOF to Aim" dolly-zoom button — don't rely on it.
- Sources: extensions.blender.org/add-ons/add-camera-rigs/, docs.blender.org manual (primary).

## 3. The muted grade — AgX (already our default)
- **AgX view transform** (Blender 4.0+ default, current in 5.0) rolls bright/saturated values toward white like real film.
- Ships **Look presets**: "Punchy" (contrast, darkens), "Greyscale," + 7 Contrast Looks (operate in AgX Log, pivot at 0.18 middle grey). We're on AgX at −0.3 exposure.
- Sources: developer.blender.org 4.0 color-management notes, github.com/EaryChow/AgX (primary).

## 4. The PSX/PS1 look — 4 documented hardware traits to emulate
1. **Affine (non-perspective-correct) texture mapping** — UVs interpolated from screen (x,y) only, ignoring z-depth → textures **wobble/swim/warp**, worst on floors.
2. **Integer-pixel vertex snapping** — no subpixel rasterizer precision → continuous **jitter/tremor**, most visible at ~320×240. (NOTE: commonly mis-blamed on "fixed-point/no-FPU" — real cause is rasterizer, per Pikuma. Visual result identical.)
3. **15-bit dithered color** — 24-bit internal, output at 15-bit with **Bayer dithering** → signature grain.
4. Low-res textures, hard/no shadows.
- **Tool: PSX Retro Tools** (fawkek, itch.io) — supports **Blender 4.3–5.0**. Provides Geometry-Nodes **Vertex Wobble** (PS1 vertex snap; PRO adds frame-hold, per-axis amplitude) + **Color Dithering** (Bayer/Floyd–Steinberg/Atkinson, adjustable scale) + Texture Distort (affine warp). This is the fastest path — one add-on covers traits 1–3.
  - ⚠️ Open question: not independently verified that its GN nodes render clean under **Eevee Next specifically** — TEST on install.
- Sources: fawkek.itch.io/psx-retro-tools, danielilett.com (affine), pikuma.com, cosmicosmo.co, psx-spx.

## 5. Cinematography for the briefing scene
- **180-degree rule**: establish the axis of action through the two main subjects; keep the camera on ONE side of that line so screen-left/right stays consistent across cuts (Officer A always frame-right of B). Break it only on purpose.
- **Reference = Metal Gear Solid (1998)**: rendered in-engine real-time (Kojima's own testimony), **fixed deliberately-chosen angles per area**, film-language vocabulary — dramatic close-ups, sweeping wides, tense pans, deliberate blocking/framing per scene. This is our craft north-star: composed, locked shots; cut between them; slow moves.
- Sources: hakjak.com (cutscene 180), Wikipedia, MGS coverage.

## Concrete recipe for OUR shots
- **Resolution/fps**: 640×480 or 720×480 @ 24fps (current: 720×480/24). Letterbox to ~2.35 or 16:9 with black bars (VSE add-on `blender-vse-cinebars`, or compositor bars).
- **Grade**: AgX + a Contrast/Punchy Look, exposure slightly down, desaturate a touch, cool-green shadow lift for jungle.
- **PSX pass**: install PSX Retro Tools → vertex wobble (subtle), dithering at the 720×480 scale, affine texture distort on set/props.
- **Camera**: 2D/static rig for the establishing lock-off + a slow push-in; cut to a couple of fixed medium/OTS angles on the officers, all on one side of the 180 line.
- **Grain/vignette/bars**: compositor after AgX (grain specifics were the one refuted claim — hand-test rather than trust a formula).

## Open questions to resolve when we get to final look-dev
- Do PSX Retro Tools' GN nodes render clean under Eevee Next 5.0? (test on install)
- Exact compositor node graph for grain+vignette+letterbox+blocking (hand-build/test).
- Authentic FMV compression: render clean, then a deliberate low-bitrate MPEG/Bink-style pass for blocking artifacts (vs clean H.264).
- Precise per-title FMV specs (FFVII–IX, MoH, H&D, OFP) to pin exact targets beyond 640×480/720×480@24.
