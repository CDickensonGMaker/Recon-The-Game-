# FP Viewmodel Animation Spec — RECONgame

Rig: PSX arms (`arms_rig.blend`), 52 bones, IK controls `handIK.R/L`, `elbowIK.R/L`,
finger `.01` bones curl (`.02/.03` copy). Grip reference: `rifle_grip.json`
(captured M14 hold — right hand at trigger, left under forestock, fingers curled).
Grip authoring helper: `tools/fp_grip.py`. Camera: eye at the `camera` bone, 74° FOV, 4:3.

## The rule that makes it scale
Every weapon's viewmodel carries an `AnimationPlayer` with the SAME clip names.
The viewmodel controller is written ONCE and every weapon reuses it — same pattern
that made the 3D character swap trivial. Clip names are the contract.

## Clip set + what each binds to (signals already emitted by the game)

| Clip | Binds to (already in code) | Notes |
|---|---|---|
| `idle` | default state | can be dead-still — `weapon_holder` already does procedural sway/breath. Don't bake sway. |
| `fire` | signal `weapon_fired` | every shot. `_punch = 1.0` readable for kick intensity. |
| `reload` | signal `reload_started` + `reload_progress(percent)` | **scale to `reload_time`** — varies per weapon (Mosin 3.8s, PPSh 3.4s) and Agility speeds it. Drive playback POSITION by `reload_progress`, don't play-and-pray. Put mag-out / mag-in on fixed timeline %s so they land on beat at any speed. |
| `reload_empty` | `reload_started` when `current_ammo == 0` | bolt locked back → needs the extra rack at the end. Longer than tactical reload. |
| `draw` | signal `weapon_switched` / `switch_started` | plays on swap-in. |
| `jam` | signal `weapon_jammed` (fires today, nothing shows it) | **tap-rack**: slap mag, rack bolt, back to ready. Variant of reload, shorter, no mag swap. **Priority gap — cheapest high-value add.** |
| `bolt_cycle` | between shots on bolt guns (Mosin, SKS), gated by `fire_rate` | lift-pull-push-turn. Trigger hand works bolt, support hand anchors. Auto weapons skip this. |
| `sprint` | lowered/running (W72 already lowers the gun) | gun-down pose sells movement; otherwise code just tilts the whole model. Pose or short loop. |

## MuzzlePoint — non-negotiable
Every weapon viewmodel needs a `MuzzlePoint` empty at the EXACT barrel tip.
`weapon_holder._get_muzzle_position()` spawns the muzzle flash + tracer from it.
Wrong place = flash from the wrong spot. (M14 viewmodel already has one.)

## Don't over-invest yet
- **ADS transition** — code lerps the whole viewmodel hip→ADS; a static aimed pose is enough. No full ADS animation needed.
- **Per-weapon idle sway** — code does procedural sway; a dead-still idle reads fine under it.

## Per-archetype reuse (from ARM_ANIMATION_SPEC.md)
- **Rifle set** (idle/fire/reload/reload_empty/draw/jam): M16, AK, M14 share verbatim.
- **Bolt variant**: Mosin/SKS = rifle set + `bolt_cycle` + stripper `reload`.
- **SMG**: PPSh — support hand on drum, drum-swap reload.
- **LMG**: M60/RPD — support hand on barrel/carry-handle, feed-tray reload (long).
- **RPG**: over-shoulder, front-load reload.

## Authoring order
1. M14 rifle set: idle ✅ → fire → reload → reload_empty → draw → jam.
2. Prove pipeline: export `m14_fp.glb`, load in Godot, bind clips to signals.
3. bolt_cycle for Mosin. Then SMG/LMG/RPG sets.

Timing/phase details for each clip: see research (in progress) — keyframe from it,
not from guesses. The rough scripted first pass was reverted; author against
reference this time.
