# GAME-DESIGNER / ATMOSPHERE — analysis of proposed ADR-026 "THE PS2 BUDGET"

**Lens:** Pillar 1 (Outstanding gunplay) + Pillar 2 (Atmosphere). Read from code, not the draft.
**Date:** 2026-07-16

## What the code actually does today (the load-bearing facts)

I read the real FX path, not the proposal's description of it.

### 1. A muzzle flash is ALREADY 90% fake. The OmniLight is the garnish, not the signal.
`gun_fx.gd:241 muzzle_flash()` spawns, per shot:
- one `OmniLight3D` — energy 3.0, range 7.0 (the only real-time light), AND
- two billboard quads (`core` + `spike`) using `_flash_mat()`: `SHADING_MODE_UNSHADED`,
  `emission_enabled`, `emission_energy_multiplier 4.0`, `BLEND_MODE_ADD`.

The quads are **self-lit**. They read at full brightness regardless of scene lighting, fog, or
whether any OmniLight exists. Already capped at `MAX_FLASHES = 8`. **The thing that carries the
Fairness-Law telegraph — the bright additive POP at the muzzle — is the sprite, and the sprite does
not need the OmniLight to be seen.** The 7m OmniLight only splashes a little warm light on the
shooter's own face and the nearest wall. That is atmosphere garnish, not the readable attacker-cue.

### 2. Tracers are already fake and already night-aware — zero real-time lights.
`bullet_tracer.gd:37` — `emission_energy_multiplier = 4.5 if MissionWeather.is_night else 2.0`,
`SHADING_MODE_UNSHADED`. The comment at :35-36 is explicit: *"tracers read much brighter at night...
cheap win, no dynamic lights needed (stays perf-safe under heavy fire)."* The tracer half of the
telegraph is **already** a PS2-budget effect and has been all along. The proposal is not inventing a
new compromise here; it is generalizing a pattern the gunplay already ships and depends on.

### 3. Explosions are the same shape: emissive fireball quad (self-lit) + OmniLight (energy 8, range 16).
`gun_fx.gd:_spawn_explosion_visual`, `MAX_EXPLOSIONS = 6`. The fireball, smoke, debris are all
self-lit particles/quads. Drop the OmniLight and the explosion still reads as a bright fireball; you
lose only the one-frame environmental light-throw on surrounding jungle.

### 4. The one real-time light that does GAMEPLAY work: the illum flare.
`illum_flare.gd` — `OmniLight3D` energy 3.5, range ~42m, AND `is_lit(pos)` strips night concealment
for anything inside its circle (read by the sight/stealth economy). This light is not garnish: it is
a mechanic — Pillar 3's "you're lit too" counterplay. **This is the light the budget must protect,
not cull.** A faked flare that doesn't actually light the world would silently break the concealment
economy.

### Baseline reality: 18v18 night jungle = ~19 fps.

## THE FAIRNESS LAW IS CANON, NOT A PREFERENCE

`GAME_GUIDE.md:41-42`, `OVERSEER_CHARTER.md:50`, `BIBLE.md:57`, `bible/03_AI_DETECTION.md:12-14`,
`VISION_READOUT.md:38-40` all state it identically: *alert ≠ accuracy; first shot at an unaware
player is a near-miss; **muzzle flash / tracers / vocalizations always telegraph.***
`test_firefight_len.gd` mechanically guards the first-shot-near-miss. The telegraph is the player's
only fair warning that the war has noticed him. **Any budget rule that dims, delays, or culls the
attacker's flash/tracer below visibility at engagement range is a canon violation, not an art call.**

## VERDICT ON EACH TENSION

### (a) Does faking flashes/explosions hurt gunplay readability / the Fairness Law? — NO, if the sprite survives.
The telegraph lives in the self-lit emissive sprite, which the code already has and which the OmniLight
never provided. Dropping the per-shot OmniLight is **safe for readability** — provided the fake flash
stays a bright, unshaded, additive quad sized to be seen at night, through fog, at the engagement
ranges the AI actually opens fire from (SPOT_RANGE ~72m; contact develops across a 200m arena). The
real risk is not "fake vs real light" — it is a fake that is too small, too brief, or fog-occluded to
read at 70m. That is the line the ADR must draw in blood.

**The trap to name:** the "staging illusion" (tension b) must never produce a combatant that can put
rounds on the player without rendering its own telegraphing flash + tracer. A culled/faked man who can
still damage you is the purest Fairness-Law violation possible — death from an attacker with no
muzzle flash. Staged/off-screen forces must be either (i) genuinely non-threatening ambient war, or
(ii) fully real when in weapons range of the player, telegraph and all.

### (b) Does the 8–16 entity cap betray "the war happens with or without you"? — NO. A convincing illusion is MORE atmospheric.
Pillar 2's promise is *felt scale and indifference*, not a headcount. Thirty-six clearly-visible men
tanking the frame to 19 fps deliver LESS atmosphere than a fog-walled treeline where unseen guns
flash and chatter, tracers arc out of the dark, and reinforcements trickle from the murk. Fog + dark
are simultaneously the PS2 budget's cost-saver AND atmosphere's best friend — they hide the cull
boundary and they ARE the Vietnam-night mood. This is a genuine synergy, the rare no-tradeoff. The
arena already leans on it: `_build_night_env()` fog, `ambient_war.gd`, distant flares. An implied
larger war reads as bigger than a rendered smaller one. **The cap serves Pillar 2.**

The sacrifice to name honestly: set-piece spectacle. There will never be a shot of 40 men assaulting
a wire in the open daylight. The budget bans that image. For a jungle-night war that is a fair price;
for a hypothetical Hue-in-daylight mission it would bite. Confine the promise to the fiction that fog
and dark can sell.

### (c) Does a stable framerate serve gunplay more than lush lighting? — UNAMBIGUOUSLY YES.
This is HLL lethality: 1–2 shots kill (ADR-016), damage is deterministic, the telegraphed near-miss
is a timed window. Every one of those depends on frame-accurate aim, flick, and reaction. At 19 fps
the flick misses, the near-miss window is a stutter, the input feels like mud — the gunplay pillar
dies at the framerate before any lighting ever helped it. A rock-solid 30/60 with faked lights beats
a gorgeous 19 for a twitch-lethal shooter every single time. **Framerate IS gunplay. Lush real-time
lighting is not on the same tier of the pillar.**

## WHERE THE BUDGET COULD BETRAY THE PILLARS (the guardrails)

1. **A fake flash that doesn't read at range = Fairness-Law breach.** Non-negotiable.
2. **A staged/culled man who can shoot the player without a telegraph = the worst breach.** Ban it.
3. **Culling the illum flare's real light = breaking the stealth/concealment economy (Pillar 3).**
   The flare must keep a real light (or an equivalent that actually feeds `is_lit`). It is the one
   real-time light worth its cost.
4. **Hard fog-wall + LOD snaps must not pop an enemy into existence inside the player's engagement
   range** — an enemy that materializes at 40m defeats both readability and fairness. Fade/stage them
   in beyond weapons range only.

## THE ONE HARD CONSTRAINT I ADD

> **The telegraph is sacrosanct. The OmniLight may die; the POP may not.** Every shot and explosion
> that can be perceived by or can threaten the player MUST render a self-lit (unshaded, emissive,
> additive) muzzle-flash/fireball sprite that is legibly visible at the AI's actual engagement range
> in fog and night — and any combatant able to put rounds on the player must render its own flash and
> tracer, never a culled/audio-only ghost. Faking is permitted everywhere the telegraph survives; it
> is forbidden the instant the telegraph does not.

## WHAT IS SACRIFICED (no free lunch)
- Environmental light-throw: muzzle flashes no longer briefly light the shooter's face and the wall;
  explosions no longer dance light across the canopy. Night loses dynamic-lighting drama.
- Daylight open-field spectacle: no rendered 36-man assault in the clear. The promise is confined to
  what fog and dark can sell.
- The illum flare is the lone real-time light kept on the payroll — it earns it by doing gameplay.
