# War Room Briefing — The Period HUD (640×480 buffer doctrine)

**Convened:** 2026-07-24 · **Arbiter:** recon-overseer · **Summoner:** Caleb
**Trigger:** A high-fidelity in-game HUD design handoff landed at
`C:\Users\caleb\Downloads\RECON_UI_Design_extract\design_handoff_recon_hud\`.
This is a planning gate — NO code until the Summoner blesses the decree.

## The one rule (the whole handoff hangs on it)
Author the in-game HUD into a fixed **640×480** offscreen buffer; **blit to the backbuffer
at integer scale with nearest-neighbour** (2× @1280×960, 3× @1920×1440). 16:9 → letterbox,
or extend the buffer to 854×480 keeping vertical authority at 480. Never change scale factor
mid-session. **Scanlines applied AFTER the upscale**, at one display pixel (pretend CRT), NOT
in the 640×480 buffer. Do NOT build at display res + scanline shader — that reads as fake.

## Four persistent elements MAX (absolute coords in 640×480, deliberately no shared grid)
- **Compass** (213,0, 214×41, flush top): amber gas-plasma plate. Ground #000, 2px border
  #4A3B00 (no top border), bearing "SW 224" 16px #FFB000 centred, chevrons `<<`/`>>` 8px
  #7A5A00, order line 8px #C08000 centred 4px below — clips, never wraps, lives INSIDE the plate.
- **Roster** (3,307, 171×auto): printed form on acetate. Ground #232717@88%, 2px #3E452A border,
  header #3E452A/#D8D2BE "SQUAD"|"WPNS FREE". Rows 8px, 11px pitch; name col 63px #D8D2BE (clips,
  no ellipsis — "SCHOENBER" is deliberate), role flex #8A9068, status right OK #96B45A / HIT
  #E0A030 / CRIT #C04A28 (CRIT row ground #3A1C12). Footer 8px #6E7450 "SCAN 51M". NO per-man sub-lines.
- **Ammo** (right 5, bottom 7): stencilled on world, NO panel. Hard 2px/2px/0 #000 shadow. Name
  8px #B8B098, round count 32px #E4DCC4, MAGS 2-digit zero-pad 8px, "GREN 2 MED 3" 8px. Right-aligned.
- **Reticle** (318,238, 5×5, NOT computed centre — leave it): four 3×1/1×3 ticks #96B45A, 4px gap.

**Typography:** ONE bitmap face, exactly two sizes (8px everything, 32px round count only).
Letter-spacing 0. No intermediate sizes/italics/faux-bold. HTML uses Silkscreen as stand-in →
replace with a real 8px-grid bitmap atlas + hand-tuned advance table, rendered 1:1. Menus may use
a SECOND face (Barlow Condensed 600 all-caps) — never in-game.

**Motion:** fixed tick, target 15fps UI regardless of render fps. Blink 2-on/2-off. **NO eased
transitions anywhere** (cubic-bezier = instant anachronism). Order line/roster/count swap on a frame.

**Three palettes deliberately do NOT reconcile.** Do not unify, do not extract shared accent tokens.

**HUD density (pause menu):** FULL (all four) / SPARSE (compass+order only) / NONE (reticle only).

**5 still-open items (NOT yet designed — a later epic):** (1) replace invented identifiers with
researched 1969 III Corps map sheets / PRC-25 freqs / battalion designators; (2) keyed radio
submenus (numbered/drilled/spoken, NOT a radial wheel); (3) one overloaded report verb (aim+press
= call contact over net + mark map); (4) map as an object with a cost; (5) pre-patrol planning screen.

## What the code actually is today (Arbiter's survey — read it yourself, don't trust this)
- `scripts/ui/hud.gd` (315 ln, class HUD : CanvasLayer) — ammo/mag/gren/med labels, bleed clock,
  crosshair, death screen, hitmarker, heal prompt, field prompt, action_progress. `.tscn` node tree
  (MarginContainer/VBoxContainer). Draws at display res.
- `scripts/ui/mission_hud.gd` (352 ln, class MissionHUD : CanvasLayer) — compass strip (top),
  toast queue, squad roster strip (bottom-left, with the "scanning 51m" / "ON THE NET - [T]"
  per-man sub-lines the handoff explicitly bans), fire menu (T), slot slider, damage-direction pip,
  distant-squadmate markers. Uses `ReconUI.make_label/make_panel`, `create_tween()` fades.
- `scripts/ui/screens/recon_ui.gd` (class ReconUI) — shared UI factory: SystemFont Consolas,
  OLIVE/AMBER palette, hairline 1px `make_panel`. The "one disciplined accent, uniform panels,
  hairline borders, tracked labels" the handoff calls the modern tell. Used by BOTH huds AND menus.
- `scripts/ui/topo_map.gd` (M-toggle map, ADR-022), `radio_menu.gd`, `squad_nameplate.gd`,
  `action_progress.gd`, `pause_menu.gd` (density toggle would land here; today it has no HUD options).
- `project.godot`: viewport 1280×720, stretch `canvas_items`, `default_texture_filter=0` (nearest),
  Forward+ (ADR-026 Amdt A), `scaling_3d/mode=5` nearest + `scale=0.75`. NO SubViewport/blit/bitmap
  font / scanline anywhere in the repo (verified grep).

## Binding constraints the decree must satisfy
- **ADR-001** PSX 3D renderer of record · **ADR-026 Amdt A** Forward+ is the renderer, no swaps,
  perf is top systemic risk · **ADR-023 Fossil Law** delete the replaced system, no parallels ·
  **r4bk Law** a feature without a visible HUD affordance does not exist · **ADR-012** input doctrine
  · **ADR-022** the map is your memory · **ADR-029** open patrol sim (no briefing/objective UI) ·
  Pillars: 1 believable firefights, 2 atmosphere, 3 freedom, 4 squad-is-the-RPG, 5 fail forward.

## Your charge
Read the CODE (not this brief) for your lens, load your Godot skill folder, write your full analysis
to `analysis/<role>.md`, and return ONLY a short verdict (≤200 words). Name what is sacrificed.
