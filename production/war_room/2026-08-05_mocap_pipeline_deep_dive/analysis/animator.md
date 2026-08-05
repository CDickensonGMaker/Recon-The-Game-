# ANIMATOR / RIGGING (blender-overseer lens) — Individual Sight

## Lane A: we are using mocap for the one job the industry does not use mocap for

I looked at how shipped FPS games actually make weapon-handling animation. The answer is
consistent and blunt:

- Weapon handling — **reload, inspect, equip, charge** — is **hand-keyed**, because the motion
  must be precise, readable, and tunable frame by frame.
- Mocap earns its keep on **interaction** motion: climbing, vaulting, melee, anything where
  organic weight and momentum are the point.
- Where studios do shoot weapon footage, it is used as **reference for keyframe work**, not as
  final output.

That is the same conclusion Caleb reached independently on 7/31, and the same conclusion the
7/27 viewmodel decree encodes: **the weapon owns named contact points; the gun leads, hands
follow.** That decree is right and it matches CoD's `tag_weapon`, Lyra's `ik_hand_gun`, and
Arma Reforger's `slot_*`/`snap_*`.

So the frustration in Lane A is not a pipeline defect. **It is the pipeline being asked to do a
job it was never the right tool for.** The gun geometry is already blessed art with a bore datum
and measured grips. The rig reduces to four IK controls. Video cannot beat authored geometry at
millimetre placement and never will.

### What video *should* supply for a weapon clip — exactly three things

1. **Beat timing.** When the mag leaves, when it seats, when the bolt goes back, when the slap
   lands. This is the expensive part of hand-keying and the part footage answers perfectly,
   because timing is a 1-D signal and depth error does not touch it.
2. **Finger curl shape.** Not position — *shape*. Which fingers wrap, which stay clear.
3. **Body English.** How far the weapon cants toward the working hand, how the shoulder rides.
   We already know from measurement that cant is the single control that decides whether a
   forearm twists 179° or 23.8°.

Everything else — where the hand is in space — comes from the contact markers.

**The build I want:** a `beats.json` per take. Frame numbers for `mag_out`, `mag_in`,
`bolt_back`, `bolt_forward`, `slap`, derived automatically from hand-velocity zero-crossings and
hand-to-prop distance minima in the existing take data. We already have the doctrine
*"measure handoff frames, never guess them"* — this makes measuring them a one-liner instead of
a constraint-influence bisection done by hand, per clip, per gun.

## Lane B: the body work is fine, the *cost* is the problem

Crews, chow hall, medical — these come out usable. His own verdict on the artillery clips:
*"came out well that way, it just took some adjusting."* The adjusting is the tax, and it has
three named sources, all of which we have already measured:

1. **Depth smear** → foot slide, hips drifting, contacts that must be re-solved by hand.
   This is the second-camera fix. It is not an animation problem.
2. **Proportion mismatch.** His body is not the PSX rig. The `caleb_body_profile.json` we made
   on 8/4 is a *convention*, not a feature — nothing in the toolkit consumes it automatically.
   Every retarget re-derives scale, and we have already been burned once by autoscale measuring
   the wrong chain (3.99×, life size × 4). **Make the profile a first-class input.**
3. **No reference-first discipline until 8/3.** Five chow hall clips authored from description
   alone put arms through tables and mimed invisible trays. His ruling fixed the cause; it needs
   a template so it cannot be skipped again.

## The lever nobody has pulled: the procedural life layer

The 7/27 council researched this and **deferred** it as P4. Every source I read this session
says the same thing again: runtime procedural motion — spring-driven sway, bob from planar
velocity, weapon lag following mouse input, recoil, breathing — is **the biggest single
anti-robotic lever available**, and it is far cheaper than any capture.

We already do idle sway and recoil punch procedurally in `weapon_holder.gd`. The layer wants
extending, not inventing. And it works on *every* clip we already have, retroactively — which is
a different economics from re-shooting footage.

**Caution, and it is a real one:** anything baked into a clip that the procedural layer also
drives gets **doubled**. This is already recorded doctrine — reference `Idle`/`Walk`/`Run` clips
are static in weapon space precisely because baking them would double the procedural motion.
Any extension of the layer needs an explicit list of what is procedural and what is baked, and
the two lists must not intersect.
