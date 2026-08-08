# PSX Style Guide — Caleb's reference, filed 2026-08-08

**Provenance:** supplied verbatim by Caleb the night of 2026-08-08 ("heres more guides toward
the psx style") as a companion to `PS1_SETUP.md`. It is a GENERAL PSX-shooter art bible; where
it conflicts with RECONgame canon, canon wins (ADR-014). Known deltas, so no reader drifts:

- §6 "billboard sprite enemies / hybrid" — **overridden by ADR-001**: the sprite renderer is
  dead; RECONgame is 3D PSX characters for everything.
- §11 "Doom-style status bar" — **overridden by the Period HUD decree**: no modern/arcade HUD,
  diegetic-first. The §11 diegetic bullet is the RECON-compliant part.
- §4 tri budgets — advisory; RECON's ruling is tri budgets = style, not perf
  (see memory/tri-budget ruling), and existing asset budgets stand.
- §10 VFX arsenal + §14 checklist — LIVE guidance for the PSX layer and future VFX passes;
  the dither-dissolve shader is banked for the toggle-gated PSX package.
- Everything else (palette discipline, texture authoring, readability rules, lighting) —
  standing art direction for the PSX look toggle and future art passes.
- **HIS TOUCHSTONE OVERRIDE (ruled 2026-08-08, same night):** *"i would look more toward Call of
  Duty, Medal of Honor, Vietcong, Men of Valor"* — *"not so much anything horror related."* So:
  §13's touchstones are replaced by the PS1/PS2-era MILITARY shooters (CoD, Medal of Honor,
  Vietcong, Men of Valor); the guide's survival-horror slant (dread, occult VFX, near-black
  horror zones, Silent Hill/RE references, VHS/static stingers) is OUT of RECONgame's
  direction. Keep the war-film reads instead: smoke, tracers, jungle haze, monsoon grey,
  flare-lit nights. Grime yes, horror no. The §10 occult/energy VFX section is for other
  projects, not this one.

---

# PSX Hardcore FPS — Art Direction & Style Guide

*For a fast, brutal, PS1-era first-person shooter in Godot 4.7. This is the visual bible: the rules that keep everything looking like one game, plus a deep VFX arsenal to pull from.*

The north star: **Quake / Doom brutality wearing PS1 skin, with survival-horror grime.** Every choice below serves two masters at once — *authentic PSX ugliness* and *split-second combat readability*. When those two fight, readability wins. A hardcore shooter that looks gorgeous but reads like mud is a bad shooter.

---

## 1. Design pillars (tape these to your monitor)

1. **Limitation is the style.** The look comes from *constraints*, not effects piled on. Low res, few colors, small textures, stiff animation. Lean into the limits instead of hiding them.
2. **Contrast over detail.** PS1 screens were tiny and muddy. You read shapes by silhouette and value, not by texture detail. Big readable silhouettes, strong dark/light separation.
3. **Everything is a little wrong.** Wobbly verts, swimming textures, dithered gradients, stepped animation. The "wrongness" is the charm — keep it consistent, don't polish it out in places.
4. **Speed dictates clarity.** This is a hardcore shooter. Enemies, projectiles, and pickups must pop instantly against the grime. Reserve your brightest, most saturated colors for *things that can kill or help you.*
5. **Dread in the walls, energy in the fight.** Environments are murky, oppressive, low-key. Combat VFX are loud, bright, and violent. The contrast between the two *is* the pacing.

---

## 2. Color & palette rules

PS1 output was effectively 15-bit (32 levels per channel) with dithering. That's not a bug to fight — it's your palette discipline.

- **Work in limited palettes per zone.** Give each area/biome a tight family of 8–16 core colors (think classic pixel-art palette discipline, just in 3D). A rusted foundry = oranges/browns/black. A frozen crypt = desaturated blues/greys/bone-white. This makes zones instantly recognizable and keeps the dithering coherent.
- **Desaturate the world, saturate the threats.** Environments live in the muddy mid-tones. Then a demon's glowing eyes, a health pickup, a plasma bolt, arterial blood — those get the pure, screaming saturated hues. Color = "pay attention to this."
- **Value first.** Squint at every scene. If the enemy silhouette disappears into the background at a squint, the values are wrong before the colors are. Fix value contrast, then color.
- **Embrace banding + dithering.** Don't fight color banding with smooth gradients — a smooth gradient reads as "modern." Let skies, fog, and lighting band and dither. It's period-correct and it's cheap.
- **Warm lights, cold shadows** (or the reverse) — pick a temperature contrast per zone and commit. Neutral-grey lighting is the enemy of mood.
- **Black is a color.** PS1 horror lived in near-black. Crushed blacks hide your draw distance, set dread, and make muzzle flashes and eye-glows *scream*. Don't be afraid to let large areas fall to near-black and light selectively.

---

## 3. The look as art rules (not just shader settings)

You already have the render pipeline (low-res viewport, vertex wobble, affine warp, dither, fog). Here's what each constraint means for *how you make art*:

- **Low internal res (320×240 / 480×270):** Detail below a few pixels is invisible. Don't sculpt fine detail — it turns to noise. Design for the silhouette and big shapes.
- **Affine texture warp:** Textures swim on big flat polys. So *break up big flat surfaces* — add geometry, trim, panel lines, so no single quad spans the screen. This is authoring, not shader tweaking.
- **Vertex wobble:** Geometry jitters as you move. Thin poles, wires, and tiny details wobble the worst — use them sparingly or accept the shimmer as flavor.
- **No mipmaps / nearest filter:** Distant textures crawl and sparkle. Keep far geometry simple and let fog eat it.
- **Per-vertex lighting:** Light resolves per-vertex, not per-pixel. More vertices = more lighting detail. Put your extra polys where light needs to fall nicely (a hero doorway), not on flat filler walls.

---

## 4. Geometry & poly budgets

PS1 authenticity is *low* poly, but "hardcore FPS in 2026" means you have modern headroom — spend it on enemy count and VFX, not on smooth models. Suggested ceilings (adjust to taste; these keep the silhouette-chunky feel):

| Asset | Tri budget (feel-based, not hard) |
|---|---|
| Enemy (main) | 300–900 tris |
| Boss | 1,500–4,000 tris |
| Weapon viewmodel | 500–1,500 tris |
| Small prop | 50–300 tris |
| Hero prop / set piece | up to ~2,000 tris |
| Architecture | keep walls chunky; subdivide big spans only for affine control |

Rules:
- **Flat-shade or hard normals** on most hard-surface geometry — smooth shading is un-PS1. Faceted looks correct.
- **No bevels, no chamfers, no rounded edges.** Hard 90° corners. Detail comes from the *texture*, not the mesh.
- **Silhouette is everything.** Model the reads-at-a-glance shape first. An enemy should be identifiable as a black cutout.
- **Asymmetry and jank are fine.** PS1 models were often lopsided and weird. Don't over-clean.

---

## 5. Texture authoring (the heart of the PS1 look)

This is where your 2D/painting skills carry the whole aesthetic. On PS1, *textures did the work the polygons couldn't.*

- **Small and tight:** 64×64 to 256×256. Most world textures 128×128. Weapon textures can go 256. Never 1024 — it defeats the look and wastes texel budget.
- **Paint the light in.** Bake shadow, grime, ambient occlusion, highlights *into the texture*. PS1 had almost no dynamic lighting, so texture *is* the lighting. Hand-paint dark corners, rust runs, dripping stains, scorch. This is the single biggest "feels PS1" lever and it plays to your strengths.
- **Limited palette per texture.** Index-color feel: a texture using ~16 colors reads more authentically than a photo-real one.
- **High-frequency grime, low-frequency shape.** Grunge, dither, and noise at the pixel level; clear big shapes overall.
- **Tiling trim sheets** for architecture — a few great tiling textures beat many unique ones, and it's how PS1 games were built.
- **Deliberate dithering in the texture itself.** Hand-dither gradients in your textures (not just the post shader) for double-authentic banding.
- **Consistent texel density** across the game so nothing looks accidentally hi-res. Pick a pixels-per-meter target and hold it.

---

## 6. Enemies & characters

The signature PSX-FPS choice: **sprite enemies, low-poly models, or a hybrid.**

- **Billboard sprites (Doom-style):** Hand-drawn/rendered enemy sprites always facing the camera, with 5–8 rotation angles so you can flank them. Maximum readability, maximum retro, plays hugely to your art background. Best for hordes.
- **Low-poly 3D models:** Better for melee/physical enemies and bosses; allows dismemberment and physics gibs. Keep them faceted and stiff.
- **Hybrid:** 3D bodies with sprite-based faces, muzzle flashes, or effects. Or low-poly grunts + sprite swarms.
- **Few animation frames, high impact.** Stepped, snappy animation (see §8). A 6-frame attack that *reads* beats a 30-frame smooth one.
- **Readable attack tells.** In a hardcore shooter the player must see the wind-up. Give every attack a bright, clear anticipation pose/flash — even a color shift or a glowing tell sprite.
- **Death is a spectacle.** Gib, dissolve, ragdoll-flop, or burst into sprites. Death VFX are a reward — make them loud (see VFX §10).

---

## 7. Weapons & viewmodels (the thing on screen 100% of the time)

- **Big, chunky, front-and-center.** Boomer-shooter weapons are oversized and readable, occupying a good chunk of the lower screen. Personality over realism.
- **Hand-painted, baked shading** on the viewmodel texture — same rules as world textures but you can afford 256×256.
- **Low-fps weapon animation.** Reload/fire animations stepped at ~10–15fps feel more PS1 and punchier than buttery 60fps.
- **Idle sway + walk bob**, exaggerated slightly. Bob sells speed and weight. Keep it snappy, not floaty.
- **Fire kick:** snap the viewmodel back on fire, recover fast. Pair with muzzle flash + light pop + shake (§10). This "kick" is 80% of gunfeel.
- **Sprite muzzle flashes** attached to the barrel — 2–3 frame additive sprite, random rotation/scale each shot so it never looks repeated.
- Consider **2D sprite hands/weapons** entirely (pure Doom) if you want maximum retro and to lean on your illustration skills.

---

## 8. Animation feel

- **Step the framerate.** Animate at 8–15 fps (hold frames / no interpolation) for that stop-motion PS1 stiffness. In Godot you can bake this in or snap animation sampling.
- **Snappy, poppy timing.** Fast attacks, fast anticipation, minimal easing. Hardcore combat wants immediacy.
- **Limited joints.** Fewer bones = stiffer, more authentic deformation. Rigid segments over smooth skinning.
- **Exaggerate key poses.** With few frames, each pose must carry the whole read. Push silhouettes hard.

---

## 9. Lighting & atmosphere

- **Bake almost everything.** Lightmaps or vertex-baked light for static geometry. Cheap, and it's how the era worked.
- **Fog is art, not just perf.** Colored fog sets every zone's mood and hides the draw distance. Tint it per zone; make it thick in horror areas.
- **Selective, dramatic lights.** A few strong colored lights (flickering torch, red alarm, cold monitor glow) beat even, flat lighting. Darkness between them creates dread and makes VFX pop.
- **Darkness as a mechanic.** Let the player's flashlight/muzzle flashes be the light in places. Fear of the dark is free horror.
- **Flicker everything.** Torches, faulty fluorescents, machinery. Animated light intensity adds life and menace cheaply.
- **No modern glow overdose.** A *tiny* bloom on emissive things (eyes, plasma, lava) is okay; heavy bloom kills the era instantly.

---

## 10. VFX ARSENAL — the brainstorm goldmine

*You asked for more VFX to add — here's a big menu. In the PSX idiom almost every VFX is one of five cheap primitives: a **billboard sprite / sprite-sheet**, an **additive glowing quad**, a **dither-dissolve**, a **decal**, or a **quick light pop**. Mix those and you can build anything below. Godot tools: `GPUParticles3D` (billboard + nearest texture), `AnimatedSprite3D`, `MeshInstance3D` quad with an additive material, `Decal` node, and a one-frame `OmniLight3D` flash.*

### Combat impacts (the meat of a shooter)
- **Muzzle flash** — 2–3 frame additive sprite, random rotate/scale per shot, + a 1-frame light pop. Non-negotiable.
- **Bullet impact puff** — small dust sprite burst + a dark scorch/bullet-hole decal left behind. Different puff color per surface (grey stone, orange rust, red flesh).
- **Sparks on metal/ricochet** — short additive streak sprites with gravity, quick fade.
- **Tracers** — stretched additive quads along the shot line; only on some rounds so they read.
- **Shell casings** — tiny mesh or sprite, bounce, ping sound, despawn after a few seconds.
- **Impact flash on hit target** — flash the enemy white/red for 1–2 frames (hit confirmation — critical for hardcore feel).
- **Hitmarker** — a tiny screen-space sprite tick + sound on a confirmed hit.

### Blood & gore (hardcore = wet)
- **Blood spray** — red additive/alpha sprite burst kicked in the hit direction.
- **Blood splatter decals** — sprayed on nearby walls/floor, dithered alpha, persistent.
- **Gibs** — low-poly vertex-red chunks with physics, then fade or sink.
- **Growing blood pool** — a decal that scales up under a corpse.
- **Blood mist on kill** — a bigger red puff cloud for the killing blow.
- **Player-hit screen blood** — dithered red splatter overlay on the screen edges (post FX), fading as you heal.
- **Dismemberment stumps** — sprite spurts at severed limbs.

### Explosions & heavy weapons
- **Fireball** — classic multi-frame sprite-sheet explosion (the most PS1 thing there is), + expanding **shockwave ring** sprite, + smoke puffs, + light pop, + screen shake.
- **Rocket smoke trail** — sprite trail behind projectiles.
- **Rocket/projectile glow** — additive halo billboard on the projectile.
- **Lingering smoke** — slow-rising dark alpha sprites after a blast.
- **Ember/spark rain** — small additive particles thrown outward, gravity.
- **Debris chunks** — physics bits flung from the blast.

### Energy / plasma / occult (great for Catacombs-flavored enemies)
- **Plasma bolts** — additive glowing billboard, palette-cycle the color for shimmer.
- **Laser/beam** — stretched additive quad with scrolling UV.
- **Electrical arcs** — animated lightning sprite snapping between two points.
- **Summoning glyphs / magic circles** — additive decal on the floor, rotating, pulsing.
- **Soul wisps / spirits** — drifting additive sprites with wobble.
- **Charge-up glow** — growing additive halo around a weapon/enemy before a big attack (doubles as an attack tell).
- **Hellfire / cursed flame** — recolored fire sprites (green, blue, black-red) for occult zones.

### Enemy FX
- **Spawn-in / telefog** — Doom-style particle burst or a dither-dissolve *in*.
- **Death dissolve** — the signature PSX trick: dissolve the model away using the dither pattern (short shader below). Cheap, gorgeous, very era-correct.
- **Eye glow in the dark** — two additive sprites; the first thing you see of an enemy in a black room. Pure dread.
- **Enemy projectile trails** — additive sprite trails so incoming fire reads.
- **Aura / enrage tint** — flash or tint an enemy when it powers up.

### Environmental / atmosphere (sell the world cheaply)
- **Dust motes / floating particles** — tiny additive specks drifting in light shafts. Instantly adds depth and mood.
- **Volumetric light shafts (fake)** — additive alpha quads angled from windows/lamps. God rays for free.
- **Torch/campfire fire** — animated fire sprite + flicker light + rising ember particles.
- **Steam / gas vents** — additive/alpha puffs on a timer.
- **Dripping water** — falling drop sprite + small splash sprite + ripple decal.
- **Waterfalls / flows** — scrolling texture + mist puffs at the base.
- **Falling ash / snow / spores** — drifting particle field, tinted per zone.
- **Fireflies / glow spores** — additive wandering dots for eerie beauty.
- **Sparks from broken machinery / severed wires** — looping spark emitters.
- **Blowing paper / leaves / cinders** — flat sprites tumbling with the wind.
- **Fog patches / ground mist** — low additive/alpha fog planes drifting.
- **Blinking indicator lights, monitor flicker** — animated emissive texture frames.

### Pickups & interaction
- **Item glow + bob + spin** — additive halo, gentle vertical bob, slow spin. Classic, readable, satisfying.
- **Pickup burst** — a quick sparkle/flash sprite when grabbed + a screen-flash of the item's color.
- **Portal / warp swirl** — animated additive vortex sprite.
- **Save point / checkpoint shimmer** — soft pulsing glow.
- **Door/mechanism power-up** — sparks + light change so the player notices state changes.

### Screen & post FX (where "hardcore" lives)
- **Screen shake** — on fire, impacts, explosions, heavy footsteps. The #1 feel multiplier. Tune per event size.
- **Hit-stop / freeze frames** — a few ms of frozen time on big hits/kills. Makes impacts *land*.
- **Damage vignette / red pulse** — screen edges flash red when hurt; sustained red tint at low health.
- **White flash** — one bright frame on a big hit, explosion, or crit.
- **Low-health palette shift** — desaturate + push red/dark as health drops. Mood + information at once.
- **Chromatic aberration pulse** — a *subtle*, brief RGB split on hits (use sparingly — it's a modern tell if overdone).
- **CRT / scanline / interlace overlay** — optional toggle for full retro-TV vibe.
- **VHS tracking / signal glitch** — for horror stingers, jump-scares, or corrupted zones.
- **Screen static / noise** — on damage, on a "radio," or as an occult intrusion.
- **Radial blur / punch-zoom** — a quick FOV kick on dashes, big shots, or taking heavy damage.
- **Berserk/rage tint** — full-screen color wash when a power kicks in.

### Bonus: the dither-dissolve shader (your signature death/spawn effect)
Drop this on a `ShaderMaterial` and animate `dissolve` 0→1 (spawn) or 1→0 (death). It eats the mesh away using an ordered pattern — extremely PS1.

```glsl
shader_type spatial;
render_mode vertex_lighting, cull_disabled;

uniform sampler2D albedo_tex : source_color, filter_nearest;
uniform float dissolve : hint_range(0.0, 1.0) = 1.0; // 1 = fully visible, 0 = gone
uniform vec3 edge_color : source_color = vec3(1.0, 0.2, 0.05); // glowing edge

const float bayer[16] = {
     0.0,  8.0,  2.0, 10.0,
    12.0,  4.0, 14.0,  6.0,
     3.0, 11.0,  1.0,  9.0,
    15.0,  7.0, 13.0,  5.0
};

void fragment() {
    ivec2 p = ivec2(mod(FRAGCOORD.xy, 4.0));
    float threshold = (bayer[p.x + p.y * 4] + 0.5) / 16.0;
    if (threshold > dissolve) {
        discard; // this pixel has burned away
    }
    vec3 tex = texture(albedo_tex, UV).rgb;
    // glowing edge on the pixels about to vanish
    float edge = step(dissolve - 0.12, threshold);
    ALBEDO = mix(tex, edge_color, edge);
    EMISSION = edge_color * edge * 2.0;
}
```

### VFX discipline (so it stays PSX, not modern)
- **Sprites and additive quads over fancy particles.** If it could exist on PS1 hardware, it fits. Volumetric smoke and soft particles read as modern.
- **Nearest-filter every VFX texture**, keep them small, and **dither their alpha** — soft feathered edges break the spell.
- **Low frame counts.** A 4-frame explosion loop is more authentic than a 32-frame one.
- **Palette-cycle** glows and energy instead of smooth color lerps — it shimmers the retro way.
- **Budget them like a shooter, not a tech demo:** dozens on screen at once during a fight, all cheap. Quantity + punch beats fidelity.
- **Every VFX pairs with sound + (usually) a light pop and/or shake.** The eye and ear together are what make hits feel "hardcore."

---

## 11. UI / HUD

- **Big, chunky, bitmap fonts.** Pixel fonts, no anti-aliasing, rendered at the low res.
- **Doom-style status bar** (optional but iconic): a big bottom bar with weapon, ammo, health, maybe a reactive face/portrait. Huge personality, huge readability.
- **Dithered panels & borders**, limited palette, matching the world.
- **Diegetic where possible** — ammo counter on the gun, health as a visible player state — deepens immersion, very survival-horror.
- **Readable damage/state feedback** — health color-codes, low-health screen state, clear ammo-empty cue. In a hardcore shooter the HUD must be glanceable mid-firefight.
- **Keep it minimal during combat**, expressive in menus. Crosshair simple and high-contrast.

---

## 12. Readability rules for hardcore combat (don't skip this)

The one real risk of the PSX look in a *fast* shooter: the grime hides the threats. Enforce these:

- **Threats are the brightest, most saturated things on screen.** Everything else is muted.
- **Enemy silhouettes must break from the background** at all times — via value, rim, eye-glow, or a subtle outline in dark zones.
- **Projectiles glow and trail** so incoming danger is unmissable.
- **Every hit has instant feedback** — flash + sound + shake. The player should never wonder if a shot connected.
- **Attack tells are bright and early.** Grime can hide a wind-up; a glow can't.
- **Keep the play-space value-separated from the detail-noise.** Floors/walls can be busy; the *air the enemies move through* stays clean.

---

## 13. Reference touchstones (study these)

- **Doom / Doom II, Quake / Quake II** — pace, weapon feel, sprite enemies, level flow.
- **DERELIKT, Dusk, Cultic, Fallen Aces, Selaco, Post Void** — modern retro-FPS art direction done right.
- **PS1 survival horror (Silent Hill, early Resident Evil)** — fog, dread, palette, texture painting.
- **Quake II PS1 port** — the actual affine/subdivision behavior you're emulating.

---

## 14. The one-page checklist

- [ ] Tight per-zone palettes; world muted, threats saturated
- [ ] Value contrast checked by squinting at every scene
- [ ] Textures small, hand-painted with baked light + grime, tight palettes
- [ ] Models chunky, faceted, hard edges, strong silhouettes; big surfaces subdivided for affine
- [ ] Enemies read as black cutouts; clear bright attack tells
- [ ] Weapons big and central; snappy low-fps anim; fire kick + flash + shake
- [ ] Animation stepped at 8–15 fps
- [ ] Lighting baked, colored, flickering, selective; darkness used on purpose
- [ ] VFX built from sprites/additive quads/dither, nearest-filtered, low frame counts
- [ ] Every hit: flash + sound + light pop + shake
- [ ] HUD chunky, bitmap, glanceable in combat
- [ ] Modern effects (bloom, soft particles, smooth AA) kept off or minimal
