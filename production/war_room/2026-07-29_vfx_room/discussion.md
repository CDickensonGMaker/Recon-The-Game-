# Discussion record — VFX Realism Pass (2026-07-29)

Four architects, independent, no cross-talk. Verdicts condensed; full analyses in `analysis/`.

- **technical_artist**: pooled warm-started GPUParticles3D flipbooks on shared materials; explosion
  = 5-layer stack; smoke = 28-puff cluster slaved to `current_radius()`; napalm = flame cards on
  the exact hazard disc; one grayscale sheet tinted per use; <400 KB new textures; zero lights.
- **tech_director**: GO on GPUParticles3D (blood/gibs stay CPU). Conditions: preallocation/warm-up,
  ≤8 shared materials, split caps, ≤2.5ms GPU / ~0ms CPU steady state. #1 risk: smoke overdraw on
  Intel UHD — bench before ship.
- **game_designer**: priority = explosions → napalm → smoke → dust. Laws: explosion scale from real
  blast radius; smoke renders ≤ blocks_sight sphere; fire renders ≥ damage radius; FLASH_SECONDS
  and all gameplay constants untouchable.
- **devils_advocate**: "realistic" must mean 2002-school or it violates ADR-026's ratified
  sacrifice; GPU headroom is unmeasured on this laptop; lingering visuals must not saturate
  MAX_EXPLOSIONS (siege arty); bless only inside the existing lifecycle skeleton with a bench.

Convergence from four doors on: GPU flipbooks, period aesthetic, gameplay-truth slaving, the
overdraw bench, fossil-law deletion. Conflicts and resolutions in `synthesis.md`.

## Build deviation from decree (named, per Truth Law)
The decree said "pooled + preallocated emitters." The build ships **per-event nodes on SHARED
warmed resources** instead: the probe `test_fake_lights.gd` requires each explosion to spawn its
visual under the CALLER's parent, and the expensive cost (material/pipeline compile) lives in the
resources, not the nodes. The stutter goal is met by `game_world._warm_effects()` warming every
new effect (explosion stack, smoke cloud, fire hazard) behind the loading screen. If the bench
shows node-alloc cost, revisit.

## Summoner rulings taken mid-session (verbatim intent)
1. Textures: *"i wouldnt mind making our own animaitons but i am using blender currently right
   now. is it something you could work on headless and i can confirm it later?"* → own sheets
   rendered via a SEPARATE `blender -b` instance (his live session untouched); Kenney CC0 fills
   static-sprite slots; he eye-confirms the sheets later.
2. Scope add: *"flame FX for the guns"* → muzzle flash upgraded to real muzzle-flame sprites in
   the same pass (probe contract + FLASH_SECONDS untouched).
3. Queued after VFX: remaining VC variants, full NVA roster, medic investigation (US medic EXISTS
   in code — squad_system.gd:200 revive chain — but has never fired for him in play; enemy medic
   does not exist).
