# Reference: US Vietnam Weapons + PS1/PS2 Retro Style
*Research notes for low-poly Blender modeling — Hell of Duty Vietnam units.*
*Scale baseline: soldier = 1.8 m tall. All weapon lengths given in real meters so they can be modeled 1:1 against the rig.*

---

# HALF 1 — WEAPON SHAPES (US VIETNAM ERA)

## 1. M16A1 Rifle (the signature silhouette)

**Real length:** 0.99 m (about crotch-to-chin on a 1.8 m soldier — it's a LONG rifle, not a carbine).
**Weight class read:** skinny, straight, "space gun."

Silhouette landmarks, muzzle to butt:
- **Birdcage flash hider** — small cylinder with slots, ~7 cm. On low-poly: a slightly wider 6-sided cylinder cap at the muzzle. Don't model the slots; paint 2–3 dark vertical lines.
- **Triangular handguard** — the Vietnam-era tell. Cross-section is a rounded TRIANGLE (flat bottom edge, ridge on top under the barrel... actually apex-down-ish: two flat angled sides meeting at the bottom, flat-ish top). Practical low-poly: a 3–4 sided tapered prism, wider at the receiver, narrowing toward the front sight. Later A2 handguards are round — round = wrong era.
- **Front sight post** — tall triangle/A-frame sticking up ~4 cm just behind the flash hider. Essential; without it the gun reads as a toy.
- **Carry handle** — the #1 identifier. A raised rectangular bridge running along the top rear half of the receiver, with a visible GAP under it (even 1 quad of see-through space sells it). Rear sight sits at its back end.
- **Magazine: 20-round, STRAIGHT.** A flat, slightly forward-raked straight box ~13 cm long. NOT the curved 30-rounder (that's late-war/post-war and screams "modern M4" at a glance).
- **Forward assist** — small cylindrical button on the right rear of the receiver. At PS1 poly counts: paint it as a dark circle on the texture; don't model.
- **Pistol grip** — distinctly raked-back A-frame grip, separate from the trigger guard.
- **Fixed triangular-profile buttstock** — straight line from receiver to butt (the barrel, receiver, and stock are all in ONE line — no drop at the stock like wooden rifles). Buttplate is flat with a slight ridge.

**Proportions:** barrel+handguard forward of the magazine ≈ 50% of total length. Carry handle sits over the rear 30%.

**Colors:**
| Part | Color | Hex |
|---|---|---|
| Furniture (stock, grip, handguard) | Black plastic | `#1A1A1A` |
| Receiver | Very dark grey/parkerized | `#26262B` |
| Barrel/flash hider | Dark gunmetal | `#2E2E33` |
| Magazine | Grey aluminum | `#4A4A4E` |
| Optional: early-war furniture | Dark green-black (some early M16s) | `#20241E` |

Tri budget: 80–150 tris (PS1), 250–400 (PS2).

## 2. M14 Rifle (early war, 1965–67)

**Real length:** 1.12 m — noticeably LONGER than the M16, reaches mid-chest when butt is on the ground. The "old wooden rifle" of the era.
- Classic wooden one-piece stock: drop at the comb (the stock line dips down behind the receiver — opposite of the M16's straight line).
- Long exposed barrel forward of the wood, ending in a **flash suppressor with a bayonet lug** — a slotted tube ~10 cm.
- **20-rd box magazine**, straight-ish with slight curve, deeper than the M16's.
- Small rear aperture sight; hooded front sight post.
- Wooden handguard on top of barrel (paint a seam line).

**Colors:** walnut wood `#5C4326` (highlight `#7A5A35`), parkerized metal `#33363A`, dark buttplate `#222`. The wood-vs-black contrast is what separates it from the M16 at a glance.

Tri budget: 60–120 tris. It's basically a plank with a magazine — the drop-comb stock line and wood color do all the work.

## 3. M60 Machine Gun ("The Pig")

**Real length:** 1.1 m, but it reads HUGE because of bulk, not length.
- **Thick straight receiver box** — much fatter than a rifle, roughly 10×12 cm cross-section.
- **Bipod folded under the barrel** (or deployed): two thin legs hinged near the muzzle end. Model as 2 thin boxes; even folded, the lump under the front third is characteristic.
- **Top-mounted rear sight** — tall leaf sight sticking UP from the receiver top, plus the **top-mounted feed tray cover** giving the top line a stepped hump.
- **Belt of 7.62 ammo** hanging from the LEFT side — a flat ribbon of ~6–10 painted cartridges drooping in a curve. This is the single biggest "machine gun" read; never skip it. One bent plane strip with a bullet texture is enough.
- **Front half:** barrel with a long slotted metal forearm/heat shield underneath, big conical flash suppressor.
- **Pistol grip + straight inline stock** with a distinctive shoulder-rest flap (paint it).
- **Carrying handle** on top of the barrel, often flopped to the side — optional detail.

**Colors:** all black/parkerized metal `#242428`, forearm slightly browner `#2E2A26`, brass belt `#8F7433` with dark links `#3A3A3A`.

Tri budget: 150–250 tris (belt included).

## 4. M79 Grenade Launcher ("Blooper" / "Thumper")

**Real length:** 0.73 m — SHORT, like a sawn-off shotgun. Reaches about mid-thigh.
- **Huge bore:** the barrel is a fat 40 mm tube — diameter reads about 3× a rifle barrel. Exaggerate it: make the bore opening BIG and dark. A 6-sided cylinder ~4.5 cm radius.
- **Break-action:** in idle pose it's closed, but the hinge point just ahead of the trigger guard gives a visible seam/step. If you make a reload animation, the barrel tips down like a shotgun.
- **Big flip-up leaf sight** on top of the barrel, halfway down — a rectangular ladder that folds flat. Even folded, model a small raised tab.
- Wooden stock (shotgun-like, with drop) + wooden forearm under the barrel. Big rubber buttpad.

**Proportions:** barrel ≈ 50% of length, and its fatness vs the short length is the whole identity.
**Colors:** barrel/metal `#2B2E2B` (often slightly greenish parkerizing), wood `#5C4326`, rubber buttpad `#1C1C1C`. Optional gold/green 40 mm round `#8F7433` + `#4A5D3A` when reloading.

Tri budget: 50–100 tris.

## 5. M1911 Pistol

**Real length:** 0.216 m — fits inside one hand-span. As a holstered prop: a small L-shaped block on the right hip.
- Classic boxy slide, slightly rounded top; hammer nub at rear.
- Grip rakes back ~15–20°, grip length ≈ 70% of slide length.
- Trigger guard: round loop — a single quad hole or just painted shadow at PS1 scale.
**Colors:** blued steel `#26262B`, brown grips `#54402A`. Holster leather (Vietnam: black) `#1F1E1C` or brown `#4A3826`.

Tri budget: 30–60 tris. First-person viewmodel: 150–300.

## 6. Ithaca 37 Shotgun (trench/riverine)

**Real length:** ~1.0 m (20" barrel version): same class as the M16 in length but totally different silhouette.
- Wooden shotgun stock with drop, wooden **pump/slide handle** under the barrel (a ribbed cylinder chunk — paint 4–5 dark grooves).
- **Single thin barrel over a fatter tube magazine** running underneath almost to the muzzle — two parallel cylinders is the read.
- Bead front sight (skip or paint), no rear sight, receiver is smooth and rounded (no ejection port visible on the left side — Ithaca ejects from the bottom, but nobody will check).
**Colors:** wood `#5C4326`, blued metal `#26262B`.

Tri budget: 50–90 tris.

## 7. M72 LAW (rocket launcher)

**Real length:** 0.67 m closed, **0.98 m extended.** Model the extended version for firing, closed as a back-slung prop.
- It is literally **a green tube** — two telescoping cylinders, inner one slightly smaller diameter.
- Ends have black rubber caps/covers (closed) or open dark bores (extended).
- **Flip-up plastic sights** pop out of the top when extended: two small tabs sticking up near front and rear.
- Trigger is a rubber bar on TOP of the tube — no pistol grip at all. Fired off the shoulder like a bazooka.
- Yellow-and-black instruction sticker band mid-tube: paint a lighter rectangle with scribble lines — instantly reads "LAW."
**Colors:** OD green fiberglass `#4A5240`, black end caps `#1C1C1C`, decal band `#B0A268` with black text marks.

Tri budget: 30–60 tris. Easiest model in the set.

## 8. M18 Claymore Bag (prop / equipment)

- The mine itself: convexly **curved rectangular slab** (~22×13×4 cm) with "FRONT TOWARD ENEMY" side, two folding scissor legs underneath. As a placed prop: 20–40 tris, paint the embossed text as a lighter smudge line. Color: OD green `#4A5240`.
- The **carrying bag (M7 bandoleer):** a squarish canvas satchel (~25×20×8 cm) with a top flap and a wide shoulder strap, worn cross-body. On a soldier: one box + one strap ribbon, ~20 tris. Color: OD canvas `#57584A`, slightly greyer/faded than uniform green.

## 9. Proportion gotchas (what people get wrong)

1. **Weapons too short.** The M16 is nearly 1 m and the M14 is 1.12 m — over half the soldier's height. Games shrink rifles to ~60 cm and they read like SMGs. Model real length; shrink only if the rig clips.
2. **Curved 30-rd mags on the M16.** Vietnam = straight 20-rounder. The curved mag is the most common era-mistake in Vietnam games.
3. **Barrels too thick.** Rifle barrels at 1.8 m-soldier scale are pencil-thin (~2 cm). Low-poly artists fatten them to 5 cm and everything looks like a blunderbuss. Keep barrels thin; put the bulk in the receiver/handguard. (Exception: M79 — exaggerate that bore.)
4. **Missing the M16 front sight post and carry handle gap.** Those two features ARE the M16. A gap under the carry handle (even one transparent quad) matters more than 50 tris anywhere else.
5. **Stock lines:** M16 = dead straight from muzzle to buttplate. M14/M79/Ithaca = wooden stocks that DROP below the bore line. Mixing these up kills the silhouette instantly.
6. **M60 without belt** reads as a weird rifle. Belt + bipod lump are non-negotiable.
7. **Pistol grips:** M16/M60 have separate raked pistol grips; M14/Ithaca/M79 do not (continuous wooden wrist). This is a 4-tri detail that carries era identity.
8. **Scale creep on hands:** low-poly hands are usually oversized mitts; if you size the grip to the hand the whole weapon inflates. Size the weapon to the BODY, let the hand clip slightly.
9. **M72 LAW held like an RPG** (with pistol grip) — wrong; it's a bare tube hugged to the shoulder, hand cupped over the top trigger bar.
10. **Sling swivels/slings:** a single flat ribbon polygon from stock to handguard makes shouldered weapons look 10x more real, costs ~4 tris.

---

# HALF 2 — PS1/PS2 VISUAL STYLE TECHNIQUES

## 1. Poly budgets — what tri count says "PS1" vs "PS2"

Documented / community-verified numbers:
- **MGS1 (PS1, 1998):** Solid Snake ≈ **690–750 triangles** (community teardown of the actual model: ~752 tris / 442 verts). This was HIGH-end PS1 with few characters on screen.
- **Medal of Honor (PS1, 1999):** enemy soldiers ≈ **250–350 tris** — squads on screen forced it low. Bodies are 6-sided limbs, blocky boots, no fingers.
- **Typical PS1 grunt/NPC:** 200–500 tris. PS1 hero: 500–800.
- **PS2 era:** early PS2 characters 1,500–3,000 tris; mid/late PS2 (God of War 2 Kratos ≈ 5,700 including 1,200 face). **Shellshock: Nam '67 (PS2, 2004)** soldiers sit in the ~2,000–3,000 range typical of squad shooters of that year (no official teardown published; inferred from era norms).
- **PC 2003–2004:** Vietcong (2003) and Battlefield Vietnam (2004) characters ≈ 2,000–3,500 tris (Battlefield's mod tools era targeted ~2–3k for player meshes). No first-party numbers exist; these are era-standard figures.

**Targets for Hell of Duty:**
| Look | Character | Weapon (world) | Weapon (FPS viewmodel) |
|---|---|---|---|
| "PS1" | **300–600 tris** | 60–150 | 300–500 |
| "PS2" | 1,500–3,000 tris | 250–500 | 800–1,500 |

Rule of thumb: if the elbows are visible angles and the head is under 60 tris, it reads PS1. If limbs look round, it reads PS2.

## 2. Texture style

- **Resolution:** PS1 used **one 128×128 or 256×128 atlas per character** (VRAM pages were 256×256 max, palettized). Faces often got a dedicated 32×32–64×64 region. PS2: 256×256–512×512 per character. For retro style: **one 128×128 or 256×256 atlas per soldier, nearest-neighbor filtering, no mipmaps.**
- **Paint, don't model.** On PS1 EVERYTHING soft was painted: pockets, webbing straps, ammo pouches, bootlaces, collar, buttons, rank patches, even the chin strap. Geometry was reserved for silhouette only (helmet dome, backpack box, canteen lump). A flak jacket = painted chest rectangle with darker edge lines + one slightly extruded chest band at most.
- **Hand-painted shading baked into the texture:** fake ambient occlusion under straps, darker inner arms, gradient down the legs. PS1 had no real-time lighting on most character textures — the texture IS the lighting.
- **Vertex colors:** PS1's main lighting tool. Gouraud-shaded vertex colors tinted characters per-level (blue in night maps, orange near fire) and faked AO (darker verts under arms, in crotch, under helmet brim). In Godot: paint vertex colors in Blender, multiply them in the shader — this is free and extremely "PS1."
- **Affine texture warping:** PS1 had no perspective-correct texturing, so textures swim/skew on large near-camera polys. Retro shaders re-add it deliberately (see §4). Keep character polys small and it stays subtle; it's mostly a floor/wall effect.
- **Dithering + color depth:** PS1 output 15-bit color (5 bits/channel) with ordered Bayer dithering to hide banding. Modern retro shaders quantize to 15/16-bit and overlay a 4×4 Bayer matrix. This one post-process step does more for "PS1 feel" than anything on the model.

## 3. Faces

PS1 faces = **a painted texture on a nearly flat head.** MGS1 Snake's face is famously just a texture on a faceted lump (his eyes are painted squints; his mouth doesn't exist geometrically). Head geometry: 12–40 tris — a box with a cut for the jaw and maybe a nose wedge.

Landmarks that read at 32–64 px:
1. **Eyebrows** — single dark strokes, the strongest expression carrier.
2. **Eye sockets as shadow** — dark horizontal smudges, NOT detailed eyes. 2–3 px tall.
3. **Nose = shadow under it**, not the nose itself (one dark blob + optional 1 px highlight on the bridge).
4. **Mouth = one dark line**, slightly wider than the nose shadow.
5. **5 o'clock shadow / camo paint** — a darker lower-face region instantly sells "soldier."
6. **Helmet brim shadow** across the forehead — hides the hairline problem entirely and is period-perfect for the M1 steel pot.
Skin tones: use 3 values max (base, shadow, highlight). Vietnam-appropriate variety: pale `#C89878`, tan `#A87858`, dark `#6B4A34`, plus green/black facepaint variants.

## 4. Godot 4 PS1 shader resources (verified current)

- **MenacingMecha / godot-psx-style-demo** — github.com/MenacingMecha/godot-psx-style-demo (also on itch.io). THE reference project. Godot 4.x branch. Provides: vertex snapping, affine mapping ("skip perspective-correct interpolation" via `noperspective`-style trick), hardware-dither approximation, fog, wobble. Minimal parameters by design. MIT.
- **PS1/PSX Visuals — GD4 Port** — Godot Asset Library asset 4687 / github.com/scolastico/psx_visuals_gd4. Fuller plugin: vertex snapping, affine mapping, distance fog, post-process dithering via Global Shader Uniforms, autoloads that auto-convert materials at runtime. Good if you want drop-in.
- **godotshaders.com** — "PS1/PSX Model" and "PS1 Shader" pages; single-material spatial shaders you can paste and edit. Good for learning what each line does.

Core techniques the shaders implement (roll your own if you prefer):
1. **Vertex snapping:** in vertex shader, transform to clip space, snap XY to a virtual low-res grid (e.g. 320×240 or 480×270), transform back → the signature vertex jitter.
2. **Affine warping:** multiply UV by vertex `w` in vertex shader, divide by interpolated `w` in fragment — reintroduces the swim.
3. **Color quantization + dither:** `floor(color * 32)/32` per channel + 4×4 Bayer offset before quantize.
4. **Fog:** cheap distance fog with a hard-ish far plane and matching **low draw distance** — PS1 fog existed to hide pop-in; keep it colored to the sky/jungle (`#5E6B52`-ish murk works for jungle maps).
5. Render at low internal resolution (Godot: viewport at 320×240 or 640×480, stretch nearest) — cheaper and more authentic than per-effect faking.
6. Texture import settings: filter OFF (nearest), mipmaps OFF.

## 5. Pre-rendered sprite setup (Doom-style renders from the low-poly models)

What made classic Doom/Duke sprites read the way they do, and how to fake it in Blender:
- **Flat, even, slightly-toony lighting.** Doom sprites were hand-drawn or photographed clay/latex models under diffuse light. Setup: one big soft key light at ~45° upper-front, a weak fill from the opposite side, NO harsh shadows. Or simplest: **Workbench renderer / flat-shaded Emission materials** with baked texture — zero lighting variance between frames.
- **Toon/ramp shading beats PBR.** Use a 2–3 step shader-to-RGB ramp (Eevee: Shader→ShaderToRGB→ColorRamp with constant interpolation) so each surface collapses to 2–3 flat tones like pixel art. PBR speculars shimmer between rotation frames and look wrong.
- **Strong 1–2 px dark outline** reads as "sprite": Solidify modifier with flipped normals + black emission (inverted hull), or a post outline. Doom sprites all have implicit dark edges.
- **NO anti-aliasing** in the render (or render 4× and downscale with nearest) — crisp stair-stepped edges are part of the look.
- **Rim light optional:** a subtle cool rim from behind-top helps the silhouette pop against dark jungle, but keep it baked/consistent across all 8 rotation angles — light must rotate WITH the model (parent lights to the model, rotate the camera... no: rotate the MODEL, keep camera+lights fixed, which is also what keeps lighting consistent per-frame the classic way — Doom did fixed light, rotating model).
- **Render sizes:** classic Doom soldier ≈ 41×56 px. For a modern retro FPS: 64–128 px tall sprites, 8 rotations, orthographic or very long lens (135 mm+) camera to kill perspective distortion.
- **Palette-quantize the renders** afterwards (e.g. to the 16-color palette below, or a 32-color extended set) — this unifies sprites that were rendered, not drawn.

## 6. Color palette — 16 colors, US units + jungle

Philosophy: Vietnam-era US = olive drab everything, low saturation, warm greens; jungle = darker, bluer greens + red-brown mud. Keep values compressed (PS1 15-bit killed extremes).

**US soldier (8):**
| # | Use | Hex |
|---|---|---|
| 1 | OG-107 fatigues base (olive drab) | `#4A5240` |
| 2 | Fatigues shadow | `#333A2C` |
| 3 | Fatigues highlight / faded | `#6B7358` |
| 4 | M1 helmet / equipment green | `#3E4A38` |
| 5 | Webbing/canvas (M1956 gear) | `#57584A` |
| 6 | Boots / rifle wood / mud-leather | `#4A3826` |
| 7 | Skin base (tan) | `#A87858` |
| 8 | Skin shadow | `#6B4A34` |

**Weapons/metal (3):**
| 9 | Gun black (furniture) | `#1A1A1A` |
| 10 | Gunmetal / parkerized | `#33363A` |
| 11 | Brass / ammo belt | `#8F7433` |

**Jungle environment (5):**
| 12 | Canopy green (dark) | `#2E4030` |
| 13 | Foliage mid-green | `#4E6844` |
| 14 | Elephant grass / dry highlight | `#8A8A55` |
| 15 | Mud / earth red-brown | `#5C4632` |
| 16 | Fog / haze / overcast sky | `#9BA48C` |

Accents outside the 16 (use sparingly): blood `#7A2018`, tracer/muzzle `#FFD966`, VC black pajamas `#232323`, NVA khaki `#8A7A55`. Night maps: multiply everything by a blue vertex tint `#46506E` rather than adding new colors — the PS1 way.

---

## Quick spec sheet (pin this)

- **Character:** 400–600 tris, one 128×128 (hard PS1) or 256×256 (PS2-ish) atlas, nearest filter, no mips, vertex-color AO, all soft detail painted.
- **Head:** ≤40 tris, painted face, helmet-brim shadow, eyebrow+eye-smudge+mouth-line only.
- **Weapons (world):** 60–150 tris, real-world lengths (M16 0.99 m, M14 1.12 m, M60 1.1 m, M79 0.73 m, LAW 0.98 m ext.), straight 20-rd mags, thin barrels.
- **Shader:** MenacingMecha godot-psx-style-demo (GD4) — vertex snap, affine UV, 15-bit quantize + Bayer dither, colored distance fog, 320×240-ish internal viewport.
- **Sprites:** flat/toon 2–3 tone shading, fixed lights + rotating model, no AA, 1 px dark outline, quantize to palette, 8 rotations.

### Sources
- MGS1 model teardowns: polycount.com/discussion/139243 (MGS1 Case Study), sketchfab reconstruction (~752 tris)
- PS1→PS4 polygon evolution: polycount.com/discussion/187013; blog.playstation.com "Polygonal Evolution"
- Era polycount norms: polycount.com/discussion/126662 (Triangle counts for assets from various videogames)
- Godot shaders: github.com/MenacingMecha/godot-psx-style-demo; godotengine.org/asset-library/asset/4687 (PS1/PSX Visuals GD4 Port); godotshaders.com
- Weapon dimensions: standard published specs (M16A1 39", M14 44.3", M60 43.5", M79 28.8", M1911 8.5", M72A2 LAW 24.8"/34.7")
