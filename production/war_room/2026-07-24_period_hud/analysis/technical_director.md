# Technical Director / Godot-Specialist — The Period HUD (640×480 buffer doctrine)

**Convened:** 2026-07-24 · **Lens:** render pipeline — fixed 640×480 offscreen HUD, integer nearest
blit onto the Forward+ world, scanlines at display pixels, 15fps UI tick, 8/32px bitmap font.
**Method:** judged the CODE, not the plan. All pointers verified this session.

---

## 0. What the code actually is today (verified)

- `scripts/ui/hud.gd:2` — `class HUD extends CanvasLayer`. Instanced as a `.tscn` (node paths
  `$MarginContainer/VBoxContainer/...`, `hud.gd:7-18`). Draws Control nodes directly at the
  1280×720 canvas base every frame.
- `scripts/ui/mission_hud.gd:4` — `class MissionHUD extends CanvasLayer`, built in code, added to
  `world` at `scripts/main/game_flow.gd:319-320` (`MissionHUD.new(); world.add_child(mission_hud)`).
- `scripts/ui/screens/recon_ui.gd:21-24` — `mono_font()` returns a **SystemFont** (Consolas). Every
  label in both HUDs is a vector SystemFont at arbitrary px sizes (12/13/14/15/16/17…): the exact
  anachronism the handoff names. There is no bitmap face in the repo.
- `project.godot:55-58` — viewport **1280×720**, `window/stretch/mode="canvas_items"`.
- `project.godot:299-303` — `default_texture_filter=0` (nearest, **global — canvas items included**),
  `scaling_3d/mode=5` (4.7 nearest-neighbour 3D filter), `scaling_3d/scale=0.75`.
- **Grep confirms:** zero `SubViewport`, zero `render_target_update_mode`, zero scanline/shader,
  zero `get_window().size`, zero stretch-management code anywhere in `scripts/ui/`. This is greenfield
  for the blit pipeline.
- Both HUDs lean on `create_tween()` fades (`mission_hud.gd:190-192, 203-205, 287-289`;
  `hud.gd:282-285`) — **eased transitions the handoff bans outright**. The doctrine deletes this code,
  which is a CPU win (see §5).

---

## 1. Cleanest 4.7 architecture + the coexistence question

### Recommended node graph — SubViewport → TextureRect blit

```
World (main viewport: Forward+ 3D renders here at scaling_3d 0.75, ADR-001/026 untouched)
├── (3D world, existing)
├── HudBuffer            (SubViewport)  size=640×480 (or 854×480 extend)
│                          transparent_bg=true, disable_3d=true,
│                          render_target_update_mode=UPDATE_ONCE (driven at 15Hz),
│                          canvas_item filter = nearest (project default 0)
│     └── HudRoot        (Control, 640×480) — the 4 elements at ABSOLUTE coords
│           ├── Compass  (213,0)   ├── Roster (3,307)
│           ├── Ammo     (right)   └── Reticle (318,238)
├── HudBlitLayer         (CanvasLayer, layer=100)   ← stretch NEUTRALISED (see below)
│     └── HudBlit        (TextureRect) texture=HudBuffer.get_texture(),
│                          texture_filter=NEAREST, size=640×480, scale=(N,N) integer,
│                          position snapped to integer, centred → pillar/letterbox
└── ScanlineLayer        (CanvasLayer, layer=101)   ← real display pixels
      └── Scanlines      (ColorRect, full window) shader samples SCREEN_UV*window_size
```

**Why SubViewport over the two alternatives:**

- **vs `Node2D._draw()` into an offscreen ViewportTexture** — the `_draw` route means hand-batching
  every glyph quad and reimplementing text layout, clipping (`compass clips, never wraps`), and the
  roster's per-column name-clip. Godot's `Label`/`RichTextLabel` inside a SubViewport give clipping,
  alignment and advance-table layout for free. The batcher is only worth it if FontFile advance
  rounding fails at 8px (it won't — see §3). **Reject the batcher for v1.**
- **vs `canvas_items` stretch with base 640×480 + snap** — this is the *tempting* one-line answer:
  set `viewport_width/height=640/480`, keep `canvas_items`. It fails the doctrine because it scales
  **both** the 2D HUD **and** (via the same root viewport) forces the whole 2D layer through one
  transform, AND it does not give you an integer factor: 720/480 and any 16:9 window height rarely
  divide evenly, so `canvas_items`' fractional stretch reintroduces the blur the buffer exists to
  kill. `canvas_items` also cannot host the scanline pass at true display pixels. **Reject.**

The **SubViewport is the only option that fully decouples the HUD's 640 grid from both the 3D
downscale grid and the window size**, which is exactly what "author at 640, blit at integer N"
demands.

### Do the two downscales stack badly? — NO, but a THIRD transform does

- `scaling_3d/scale=0.75` (mode 5, nearest) downsamples **only the 3D pass** into the main viewport.
  The `HudBuffer` SubViewport is 2D-only (`disable_3d=true`) with its own 640×480 render target — it
  **never touches the 3D scaler**. So the 3D downscale and the HUD integer-upscale are **independent
  grids that do not stack.** Good. They also need not align (opaque HUD composited over a
  transparent buffer; no shared pixel grid required).
- **The real stack hazard is `window/stretch/mode="canvas_items"` @1280×720** (`project.godot:58`).
  In this mode the engine applies a single stretch transform (window/1280×720 ≈ **1.5×** at the
  authoring window, fractional at most others) to **every CanvasLayer**, including `HudBlitLayer` and
  `ScanlineLayer`. That multiplies your carefully-computed integer N by ~1.5 → **non-integer nearest
  scale → shimmer/uneven scanlines. This is the single biggest technical risk of the whole feature.**

**Fix (two ways, pick one):**
1. **Preferred, lowest global blast radius:** keep `canvas_items` for menus; neutralise the stretch on
   the two HUD layers only. In a `HudScaler` script, read `get_window().size` (always true device
   pixels, unaffected by stretch), set each layer's `CanvasLayer.transform` to the **inverse** of the
   active stretch transform, then apply the integer scale/position in real pixels. The scanline shader
   keys spacing to real `window_size` so one scanline = one device pixel.
2. **Cleaner but global:** flip `window/stretch/mode` to `disabled` so Control coords are 1:1 with
   device pixels. Then menus (`ReconUI`, `main_menu.gd`) no longer auto-fit arbitrary windows and must
   adopt an explicit reference scale. **Sacrifice named:** menu responsive-scaling regresses; this
   touches every screen, not just the HUD. Recommend #1 for the in-game HUD, revisit #2 only if menu
   scaling is being reworked anyway.

### Where the scanline shader lives

On `ScanlineLayer` (top CanvasLayer), a **full-window ColorRect** with a `canvas_item` shader that
computes line phase from **`SCREEN_UV * window_size.y`** (device pixels), NOT from the 640 buffer.
It sits **above** `HudBlit`, so it darkens both the upscaled HUD and — if you want the CRT read on the
world too — everything. Sampling in `SCREEN_UV` guarantees "one display pixel" scanlines post-upscale.
It must **never** live inside `HudBuffer` (that would bake scanlines into the 640 grid, then upscale
them N× — the "fake" look the doctrine forbids, brief lines 12-13).

---

## 2. Letterbox vs 854×480 extend

**Letterbox (fixed 640×480, pillarboxed on 16:9) is lower risk. Recommend it for v1.**

- 640×480 is 4:3; on a 16:9 display the leftover is **pillarbox (left/right bars)**, filled #000.
  All four elements keep their published absolute coords (compass centred: 213+214=427, midpoint
  320 = 640/2 ✓). **Zero layout logic.** A period 4:3 CRT read is *more* faithful, not less.
- **854×480 extend** keeps vertical authority 480 but widens the canvas. Every "centred" element
  (compass at 213 assumes width 640) and every right-anchored element (Ammo, Roster) must become
  **anchor-relative**, not absolute — the handoff's absolute-coord contract breaks. More code, more
  QA, more ways to misplace an element per aspect ratio. **Defer to a later epic once elements are
  parameterised by canvas width.** Its only payoff is filling the pillarbox bars, which the aesthetic
  arguably wants empty anyway.

**Enforcing "vertical authority 480, never change scale mid-session":**
- Derive **once, at session boot**, from device height: `N = maxi(1, floori(window_h / 480))`
  (2× at 960–1439px tall, 3× at 1440+). Cache `N`; the blit uses only cached `N`.
- **Ignore runtime window resizes** for `N` — a mid-session resize must not re-pick the scale (that is
  the "never change mid-session" rule made mechanical). Only a deliberate resolution change in the
  options screen re-derives `N` and rebuilds, between patrols, never during one.
- The buffer size (640×480) is **constant forever**; only `N` and the centring offset vary by display.
  A structural probe can assert `HudBuffer.size == Vector2i(640,480)` and that `N` is integer.

---

## 3. Bitmap font at 8px / 32px

**Use a `FontFile` bitmap atlas (BMFont `.fnt` or a pixel TTF imported with all smoothing off) via
`add_theme_font_override`. Not the hand-drawn quad batcher.**

What renders 1:1 crisp inside the 640 buffer:
- Import the face with **`antialiasing = None`, `hinting = None`, `subpixel_positioning = Disabled`,
  `oversampling = 1.0`**, `Font.set_spacing(SPACING_GLYPH/SPACING_SPACE, 0)` for letter-spacing 0.
- **4.7 gotcha (verified, `godot_4.7_features.md:101`):** font import `hinting` default changed
  **1→3**; pixel fonts auto-disable but **set it explicitly** anyway. `subpixel_positioning` MUST be
  disabled or 8px glyphs blur across pixel boundaries — this is the #1 way a "bitmap" font still looks
  soft in Godot.
- The project already sets `default_texture_filter=0` (nearest) **globally** (`project.godot:299`),
  so the atlas samples nearest inside the SubViewport with no per-node override. One less trap.
- **32px = exactly 4×8.** Do NOT let a single 8px atlas be vector-scaled to 32 (risks half-pixel
  advances). Either author a **native 32px atlas for the digit glyphs only** (the round count is
  digits + nothing else, brief line 27), or nearest-scale the 8px digits by integer 4×. Native 32px
  digit atlas is cleanest and tiny.
- Silkscreen (the HTML stand-in) is fine as a literal placeholder, but ship a real 8px-grid atlas with
  a **hand-tuned advance table** as the brief demands — `FontFile` carries the advance table natively,
  which is precisely why the batcher is unnecessary.

The **quad batcher** only earns its keep if you need sub-advance kerning `FontFile` can't express.
At letter-spacing 0, monospace-ish 8px, it cannot — reject it and keep `Label`'s free clipping
(compass "clips never wraps", roster name-col "clips no ellipsis" = `Label.clip_text` +
`autowrap_mode=OFF`, trivial in-buffer).

---

## 4. Fixed 15fps UI tick

**SubViewport update-throttle, not a Node2D manual `queue_redraw`.**

- Set `HudBuffer.render_target_update_mode = UPDATE_ONCE`. Accumulate in `_process`: every `1.0/15.0 s`
  (a) mutate all HUD state (Label text, blink phase, count swaps) **and** (b) set the SubViewport to
  `UPDATE_ONCE` again. The buffer re-renders **15×/sec**; the `HudBlit` TextureRect samples the last
  texture every display frame at effectively zero cost.
- Do **NOT** use `UPDATE_ALWAYS` — that re-renders the 640 buffer at full render fps, throwing away the
  entire point of the throttle.
- Drive **blink (2-on/2-off), order-line swaps, count swaps** off this same 15Hz accumulator so state
  changes always coincide with a re-render — no eased tweens (the doctrine bans them; this also deletes
  the `create_tween()` churn at `mission_hud.gd:190,203,287` / `hud.gd:282`).
- **Cost:** rendering a 640×480, 2D-only, ~0.31 MP viewport 15×/sec is sub-millisecond — a rounding
  error next to the 3D pass. The throttle itself is one float compare per frame.

---

## 5. PERF (ADR-026 Amdt A — top systemic risk, Forward+, Intel UHD 19–25 fps)

**Verdict: CPU cheaper, GPU roughly neutral-to-slightly-dearer. Net acceptable, NOT a win. One line
item to watch: the fullscreen scanline pass.**

- **CPU — cheaper.** Today both HUDs re-layout Control trees, shape SystemFont text, poll squad every
  0.5s (`mission_hud.gd:225-228`), unproject markers, and run several tweens **every frame at 60Hz**.
  Proposed: all of that runs **15×/sec**, and the banned tweens are deleted. Clear CPU reduction —
  directly friendly to the perf pillar.
- **GPU fill — the honest accounting.** Current HUD draws canvas items over up to 1280×720
  (0.92 MP) every frame. Proposed per display frame = **two fullscreen textured quads**: the blit
  (~0.92 MP+ at window res) + the scanline pass (~0.92 MP, cheap fragment). The 640 buffer render
  (0.31 MP) happens only 15×/sec. So the extra GPU cost is **one fullscreen fragment pass (scanlines)
  per frame** that does not exist today. On a discrete GPU: negligible. **On Intel UHD it is real and
  measurable** — a fullscreen pass at ~1MP is not free on the exact hardware that defines the 19–25fps
  ceiling. Mitigation: the scanline pass is a natural rung on the perf-fallback ladder (disable
  scanlines first; the 640 buffer + nearest blit alone still deliver the period read).
- **Forward+ / ADR-001 / ADR-026 conflict — NONE.** `disable_3d=true` on the SubViewport means the HUD
  buffer never invokes Forward+ clustered-light/GI machinery — it's a 2D pass. No renderer swap
  (ADR-026 Amdt A satisfied); ADR-001's 3D renderer of record is untouched. **Bonus:** the HUD buffer
  has no Environment, so the specified hex colours (#FFB000, #96B45A…) render **exactly**, never pushed
  through the world's AgX tonemap — and this matches today's behaviour (canvas items already bypass 3D
  tonemap), so no regression, and the palette-fidelity the handoff demands comes for free.
- **Pixel-snapping gotchas with the existing nearest 3D downscale:**
  1. The 0.75× 3D grid and the integer HUD grid are independent — **fine** (§1). No stacking.
  2. `HudBlit` **must** sit at **integer pixel position** (round the centring offset) or the nearest
     upscale shimmers on sub-pixel placement. Enable `rendering/2d/snap/snap_2d_transforms_to_pixel`
     and `snap_2d_vertices_to_pixel`, or place the TextureRect at explicit int coords.
  3. `texture_filter` on `HudBlit` must be **nearest** — project default 0 covers it, but assert it in
     code so a theme change can't silently flip it to linear and blur the whole HUD.
  4. The **canvas_items 1.5× stretch** (§1) is the pixel-snapping killer, not the 3D scaler. Neutralise
     it or nothing downstream snaps.

---

## Recommendation (for the Arbiter)

Adopt the **SubViewport(640×480, disable_3d, transparent, UPDATE_ONCE@15Hz) → nearest TextureRect blit
at cached integer N → top-layer scanline ColorRect in device pixels** architecture. **Letterbox
(pillarbox) 640×480 for v1**, 854×480 extend deferred until elements are width-parameterised.
**FontFile bitmap atlas** (8px + native 32px digits), all smoothing off. Delete the tween fades and
the SystemFont path (`recon_ui.mono_font` stays for MENUS only — Fossil Law: the in-game HUD's use of
it dies with this change).

**Single biggest technical risk:** `window/stretch/mode="canvas_items"` @1280×720 imposes a
**non-integer ~1.5× transform on every CanvasLayer**, including the blit and scanline layers — which
destroys integer nearest-neighbour scaling and even scanline spacing. Until the HUD blit + scanline
layers are given **true device-pixel authority** (invert the stretch transform per-layer, or switch to
`disabled` and re-solve menu scaling), the 640 buffer cannot render crisp and the whole doctrine
fails silently. **Prototype the stretch-neutralised blit FIRST**, before any font or element work — if
that one seam isn't clean, nothing above it matters.

**What is sacrificed:** one extra fullscreen GPU pass per frame (scanlines) on the exact Intel-UHD
hardware that is already perf-bound; and either a per-layer stretch-inversion hack (fragile, HUD-local)
or a global `stretch=disabled` that regresses menu responsive scaling. No free lunch.
