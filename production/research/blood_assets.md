# Blood VFX Asset Research — RECONgame (PSX-style FPS, Godot)

Research date: 2026-07-09. Web-verified licenses. Priority: CC0 > CC-BY. Rejected: unclear / NC / no-license listings.
Needs: (1) burst/spray flipbook sheets, (2) splat decal textures, (3) blood pool (spreading).

---

## TOP 5 (ranked)

### 1. "Animations - Blood, Hit and Both :D" — Sinestesia (OpenGameArt)
- **URL:** https://opengameart.org/content/animations-blood-hit-and-both-d
- **License:** **CC0** (page license badge verified). No attribution required ("don't claim you made it" is a request, not a term).
- **Contents:** 3 sprite sheets — hit flash, blood splash, and combined. **16 frames each, 512x512 per frame** (2048x2048 sheet), PNG with transparency.
- **Style fit:** Chunky hard-edged cartoon splash, hard alpha. Downscale frames to 64-128 px and it reads perfectly as PSX-era flipbook. Excellent burst material.
- **Use for:** Blood BURST flipbook (need #1). Last frames also usable as impact decals.

### 2. "Animations - Blood Splatter 1" — Sinestesia (OpenGameArt)
- **URL:** https://opengameart.org/content/animations-blood-splatter-1
- **License:** **CC0** (verified verbatim from page sidebar). No attribution required.
- **Contents:** 2 files (SHARE BLOOD 1.png / SHARE BLOOD 2.png, ~92 KB each). **8 frames, 1024x1024 total sheet**, red AND green variants (green = alien/monster blood option), PNG alpha.
- **Style fit:** Same chunky Sinestesia style; 8 frames is right in the 4-16 sweet spot, lighter than the 16-frame set.
- **Use for:** Blood BURST flipbook, second variant for randomization; green variant for enemy types.

### 3. Material Maker library — "Blood Splash" + "Blood Stain" by unfa
- **URLs:** https://www.materialmaker.org/material?id=284 (Blood Splash) and https://www.materialmaker.org/material?id=192 (Blood Stain)
- **License:** **CC0** (both verified on materialmaker.org).
- **Contents:** Fully **procedural** blood splat/stain decal materials (made as decals for the FOSS FPS Liblast, UT99-inspired). Open in Material Maker (free tool), tweak density/sparseness/shape seed, export PNG at ANY resolution — infinite unique splat variants.
- **Style fit:** Semi-realistic by default, but exporting at 64-128 px with alpha-threshold gives ideal hard-alpha retro decals. Best answer for the POOL need: render the same stain at 3-4 increasing spread/density settings = spreading-pool frame sequence.
- **Use for:** SPLAT decals (need #2) and POOL frames (need #3).

### 4. Kenney "Splat Pack" (kenney.nl / itch.io)
- **URL:** https://kenney.nl/assets/splat-pack (also https://kenney-assets.itch.io/)
- **License:** **CC0** (Kenney's standard, verified on page). No attribution.
- **Contents:** **30+ splat sprites**, includes vector source — scale/recolor freely. Round liquid-splat silhouettes in various shapes.
- **Style fit:** Cartoony round splats; tint dark red + posterize for decals. Clean hard shapes = good hard-alpha decals, though less "gory" than hand-drawn blood.
- **Use for:** SPLAT decal variety (need #2); silhouettes also work as pool bases.

### 5. "Blood FX" — jasontomlee (itch.io)
- **URL:** https://jasontomlee.itch.io/blood-fx
- **License:** **CC-BY 4.0** — commercial use allowed, **attribution required** (credit "jasontomlee"), no redistribution of raw pack. NOT CC0 — use only if you accept a credits line.
- **Contents:** Hand-animated pixel blood effects, 2 batches, GIF + PNG sprite sheets + Aseprite sources. Frames roughly **16x16 to 48x32 px**, multiple frame counts (sprays, drips, impacts).
- **Style fit:** Genuine low-res pixel art with hard alpha — zero downscaling needed, drops straight into a retro pipeline. Best pure-pixel option found.
- **Use for:** BURST flipbooks and directional sprays (need #1) if CC-BY attribution is acceptable.

---

## Also verified (usable, lower rank)

| Asset | URL | License | Notes |
|---|---|---|---|
| Bloodsplatter & Bloodsplash Animation — overcrafted | https://opengameart.org/content/bloodsplatter-and-bloodsplash-animation | **CC0** | Pixel-art splash spritesheet + a ground splatter single frame + GIMP sources. Splatter frame = decent static pool/decal. |
| Blood splat — TobiasM | https://opengameart.org/content/blood-splat | **CC0** | Single PNG splat sprite (87.9 KB), made for shooter hit decals. Quick decal filler. |
| Blood Splatters — AntumDeluge | https://opengameart.org/content/blood-splatters | **CC0** | Tiny 32x32 red + green splat tiles. Micro-decals / particle sprites. |
| GIF Free Pixel Effects Pack #5 (Blood) — XYEzawr | https://xyezawr.itch.io/gif-free-pixel-effects-pack-5-blood-effects | Custom free license: commercial OK, modify OK, **no redistribution/resale**, credit optional. Not CC0 but commercial-safe. | Pixel-art blood animations, 100x100 canvas, sprite sheet included, 30/60 fps exports. |
| Free Pixel Effects Pack #11 - Mini Blood Splats — XYEzawr | https://xyezawr.itch.io/free-pixel-effects-pack-11-mini-blood-splats | Same custom free license as above. | 9 mini splash variants, 64x64 PNG frames. Good small hit-spray flipbooks. |
| Blood Effect Sprite Sheet — Betson/posebudios | https://opengameart.org/content/blood-effect-sprite-sheet | **CC-BY 3.0** — must credit posebudios. | 4 blood animation sets, 512x512 frames compiled to one sheet. Fine if crediting. |
| Pixelated Blood Animations — Sinestesia | https://opengameart.org/content/pixelated-blood-animations | CC-BY 3.0 (credit Sinestesia) | 2 lateral splash animations (L/R mirrored), 16 frames @ 512x512. Directional spray — useful for wall-hit sprays. |

## Rejected

- **Blood splat animations — PWL (OGA):** https://opengameart.org/content/blood-splat-animations — CC-BY-**SA** 3.0. Share-alike creates derivative-license obligations; avoid for a commercial closed project. (3 splat anims, 13-16 frames @ 480x480 — shame, but SA.)
- **"Blood effect" — SheriffObo (itch.io):** https://sheriffobo.itch.io/blood-effect — growing blood stain (would have been the perfect pool) but **no license stated anywhere on the page**. Rejected per unclear-license rule. Could email the author if desperate.
- **Kenney Particle Pack** (https://www.kenney.nl/assets/particle-pack): CC0 but contains no blood sprites — only generic smoke/spark/fire (tintable soft particles, not a fit for hard-alpha retro blood).
- **CraftPix "Blood Splash Sprite Effects Asset Pack"** (https://craftpix.net/product/blood-splash-sprite-effects-asset-pack/): paid product, not in freebies section; CraftPix free section had no dedicated blood pack at research time.

---

## Best picks per need

- **Blood BURST flipbook:** #1 Sinestesia "Blood, Hit and Both" (CC0, 16f @ 512) — downscale to 64-128 px, alpha-threshold for hard PSX edges. Mix in #2 (8f, red+green) for variety. If a credits line is fine, jasontomlee Blood FX is the most authentically low-res.
- **SPLAT decals:** unfa "Blood Splash"/"Blood Stain" via Material Maker (CC0) — export a dozen 64-128 px hard-alpha variants. Supplement with TobiasM Blood splat and Kenney Splat Pack silhouettes (all CC0).
- **Blood POOL:** No license-safe ready-made multi-frame spreading pool was found. Best route: generate 3-4 growth stages from unfa "Blood Stain" (CC0, procedural spread/density params) = a 4-frame pool flipbook. Fallback: scale/fade a single pool decal (overcrafted splatter frame or a Material Maker export) in-shader — standard PSX-era trick anyway.

## Godot integration notes

- All burst sheets are uniform grids: import as `AnimatedTexture`/`SpriteFrames` or use `particles_anim_h_frames` on a `StandardMaterial3D` for GPUParticles quad flipbooks.
- For PSX look: reimport at low res, filter OFF (nearest), alpha scissor (hard alpha), vertex-color tint for damage intensity.
- Keep a `CREDITS.md` entry for any CC-BY asset used (posebudios, Sinestesia CC-BY items, jasontomlee).
