# PS1 look in Godot 4.7 — setup guide (RECONgame)

**Provenance:** Caleb delivered this package 2026-08-07 (guide + `ps1_material.gdshader` +
`ps1_postprocess.gdshader`, filed alongside). An earlier agent's copy said "Catacombs of Gore" —
**that was a mistake; this is for RECONgame.** References corrected.

**Wired 2026-08-07 (his ruling: "yeah make a toggle for it") — the shaders MOVED out of this
folder to `assets/shaders/ps1_material.gdshader` + `assets/shaders/ps1_postprocess.gdshader`.**
The toggle is "PSX LOOK" in the settings screen (`scripts/ui/screens/settings_screen.gd:67-74`),
persisted as `psx_look` in `user://settings.cfg` (`scripts/autoload/game_settings.gd:14`), applied
by the `PsxLook` autoload (`scripts/autoload/psx_look.gd`) — layers 1+3 below: low internal 3D
resolution via `scaling_3d_scale` plus the postprocess pass on a negative CanvasLayer (the
SubViewport rebuild in step 1 stays the shipping option if the bilinear-upscale route reads soft;
the postprocess shader was adapted to `hint_screen_texture` + grid snap for this wiring). **OFF by
default — the ship-audit ruling stands: no default-on before the perf numbers exist (S5,
`SHIP_AUDIT_2026-08-07.md`).**

**Layer 2 wired 2026-08-08** ("lets finish wiring everything"): `scripts/visuals/psx_material.gd`
converts imported `BaseMaterial3D` surfaces to `ps1_material.gdshader` (or the new
`ps1_material_cutout.gdshader` for alpha-scissored foliage) at runtime, reading each mesh's own
`albedo_texture` off the imported material — so **step 2 below is NOT a manual per-asset job; do
not do it by hand.** Unshaded, billboarded and alpha-blended surfaces (tracers, muzzle flash, rain,
smoke) are skipped by design, and anything in the `psx_exempt` group is left alone.

**Layer 4 is already satisfied and its density number is FENCED — see §4.**

---

Three layers stack to make the DERELIKT-style look. In order of visual impact:

1. **Low internal resolution** (the single biggest thing — chunky pixels)
2. **Vertex wobble + affine texture warp** (`ps1_material.gdshader`)
3. **Color crush + dithering** (`ps1_postprocess.gdshader`)
4. **Fog + short draw distance** (WorldEnvironment) — essential for an open world

Do them in that order; each one alone already reads as "retro," and together they nail it.

---

## 1. Render the 3D world at low resolution

You want the *3D* pixelated but your UI/text crisp, so render the world into a small SubViewport
and blow it up with nearest-neighbor.

Scene layout:

```
Main (Node2D or Control)
├── SubViewport            (size = 480 x 270, or 320 x 240 for grittier)
│   ├── Camera3D
│   └── ... your whole 3D world ...
└── TextureRect            (anchors = Full Rect)
        texture           = SubViewport's texture (drag it in, or set in code)
        texture_filter    = Nearest
        material          = ShaderMaterial → ps1_postprocess.gdshader
```

SubViewport settings:
- **Size**: 480×270 (16:9, clean) or 320×240 (4:3, grittier). Lower = more retro + faster.
- **Rendering → Scaling 3D**: leave at Bilinear/1.0 — the small size *is* the effect.
- Turn on **"Own World 3D"** only if this viewport isn't picking up your scene.

To wire the texture in code (put on the TextureRect):

```gdscript
func _ready() -> void:
    var vp := $"../SubViewport"
    texture = vp.get_texture()
```

**2-minute alternative** (pixelates everything, UI included): Project Settings →
Display → Window → Stretch → **Mode = viewport**, and set the viewport
width/height to 320×240. Good for a quick test; use the SubViewport for shipping.

---

## 2. The material shader — `ps1_material.gdshader`

**RECONgame does this in code — do not hand-assign these.** `PsxMaterial.apply()` walks the tree
and converts every eligible surface, pulling `albedo_tex` / `albedo_color` / vertex-color use off
the imported material. The two manual steps below describe the generic Godot workflow only.

1. ~~On a mesh, create a **ShaderMaterial** and assign `ps1_material.gdshader`.~~
2. ~~Set **albedo_tex** to your texture.~~

Tunable uniforms:

| Uniform | Meaning | PS1-ish value |
|---|---|---|
| `snap_resolution` | Grid vertices snap to. Lower = chunkier wobble. | `240,180` (try `160,120` for heavy) |
| `wobble_amount` | 0 = no jitter, 1 = full snap | `1.0` |
| `affine_amount` | 0 = modern UVs, 1 = full texture "swim" | `0.7`–`1.0` |
| `color_steps` (post) | Per-channel color levels | `32` (15-bit) |

**Subdivision tip (this is what DERELIKT does):** affine warp gets extreme on
big flat polygons. Give floors/walls a few extra edge loops so a single quad
isn't stretched across the whole screen. Some warp = good; a swimming floor =
too much. Dial `affine_amount` down or subdivide.

**Lighting:** the shader uses `vertex_lighting` (per-vertex Gouraud) — keep
your lights few and simple. For big static geometry, prefer **baked lightmaps**
or paint light into **vertex colors** (the shader multiplies them in via
`use_vertex_color`) and it'll look period-correct *and* run fast.

---

## 3. Post-process — `ps1_postprocess.gdshader`

Already placed on the display TextureRect in step 1. It crushes color to ~15-bit
and applies ordered Bayer dithering aligned to the low-res pixels. Lower
`color_steps` (16, 8) for stronger banding; raise `dither_strength` for a
grainier gradient.

---

## 4. Fog + draw distance (critical for open world)

PS1 hid its tiny draw distance behind fog — and for an open-world AO this is
also your performance lever.

Add a **WorldEnvironment** node → new **Environment**:
- **Background**: Color (a dark tone that matches your fog), or a low sky.
- **Fog → Enabled**: on.
  - Mode **Exponential**, `Density` ≈ `0.02`–`0.08`.
  - Set **Fog Light Color** to your mood color (murky jungle green/grey for RECONgame).
- Optionally enable **Depth Fog** with `Begin`/`End` for a hard curtain.
- **Turn OFF**: Glow/Bloom, SSAO, SSR, SSIL, Volumetric fog — none of that is PS1.
  A tiny bit of glow is the only modern touch worth considering.

On your **Camera3D**, pull **Far** in to ~40–80 m so geometry dissolves into fog
right where the fog hits full opacity. Then use **Visibility Range / LOD** on
meshes and occlusion culling so the open world actually streams.

**RECONgame status 2026-08-08 — ALREADY DONE, AND THE NUMBERS ABOVE ARE FORBIDDEN HERE.**
`game_world.gd:72-87` already builds this environment: fog on at `0.0065` with aerial perspective,
sky scatter, and **no** glow/SSAO/SSR/SSIL/volumetric fog anywhere in the project. So §4's
checklist is satisfied without a line of new code.

**Do NOT raise density to the `0.02–0.08` this guide suggests, and do NOT pull camera Far to 40–80m.**
`game_world.gd:77-81` fences the density under a fairness floor: an open-ground enemy at the 140m AI
sight cap (`enemy_base.SIGHT_CAP_OPEN`) must remain a visible hazy silhouette, so fog can never hide
a shootable target. Denser fog or a nearer Far plane makes the AI able to see what the player cannot
— a direct Pillar 1 violation. Fog is `MissionWeather`'s (`scripts/world/mission_weather.gd:12-18`,
which reaches `0.035` only in FOG weather, where the AI sight cap drops to `0.35` in step). The look
toggle deliberately does not touch it.

---

## 5. Texture import (do this once per texture)

Select textures in the FileSystem → **Import** tab:
- **Filter**: Off (the shader also forces nearest, but this keeps thumbnails honest).
- **Mipmaps**: Off for max authenticity (PS1 had none) — expect some distant
  shimmer. Turn on if the shimmer bothers you at open-world distances.
- Keep source textures **small** (128×128 / 256×256) with tight, limited palettes.
  This is the texture-artist half of the look and it's where your 2D skills pay off.

---

## Quick checklist for RECONgame

- [x] Low internal 3D res — `scaling_3d_scale` to 270p (`psx_look.gd TARGET_HEIGHT_PX`)
- [x] `ps1_postprocess.gdshader` on a negative CanvasLayer, UI stays crisp
- [x] `ps1_material.gdshader` on world meshes — automatic, `PsxMaterial.apply()`
- [x] WorldEnvironment fog on, modern effects off — `game_world.gd:72-87`, and **camera Far stays
      where it is** (the fairness floor, §4)
- [ ] `affine_amount` tuned against the real kit; extra edge loops on big floors/walls if the
      warp swims (default is `0.85`, not the guide's `1.0`, for exactly this reason)
- [ ] Textures imported small, nearest, no mipmaps
- [ ] Bake lighting for static geometry; keep dynamic lights few
- [ ] **Perf numbers (S5) — the gate on default-on. Nothing here has ever run.**
