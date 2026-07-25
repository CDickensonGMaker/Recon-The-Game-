# FP Arms / M16 Reload — session handoff, 2026-07-24

Everything below is saved in `assets/player/arms/fp_arms_rifle.blend` (592 objects, 47 actions).

## Shipped this session

**19 arm rigs**, one per weapon, 4 units apart along Y, each in a `RIG_<gun>` collection with
its gun parented alongside. Every gun's `grip_R` sits within **0.004mm** of its own rig's
`handIK.R`. Includes three new props: `M26_Grenade`, `Claymore` (imported from
`assets/world/props/claymore.glb`) and a hand-modelled **H-189/GR radio handset**
(80 verts / 132 tris, olive drab).

**Both armories assembled.** US markers renamed `grip_RightHand_`/`grip_LeftHand_` →
`grip_R_`/`grip_L_` so `tools/fp_grip.py` can see them. The VC armory had **166 part
objects with no roots at all** — seven roots built and everything parented.

**Broken texture paths repaired.** The arms material pointed into the deleted `art_source/`
tree; 13 images relinked from `assets/player/arms/` using **relative** paths.

**Pose library** — `assets/player/arms/pose_library/`:
`m16_mag_grab` · `m16_mag_down` · `m16_charge_grab` · `m16_charge_pull`.
Each stores the hand matrix in **three spaces** (world, gun-relative, part-relative) plus
finger curls. The part-relative matrix is what lets a grip be re-solved when the part moves.

**`m16_reload` — 72f / 2.40s**, matching `reload_time = 2.4` in `data/weapons/m16a1.tres`.
Events on markers: `mag_out` f18 (25%), `mag_in` f44 (61%), `seat_slap` f47 (65%).
Magazine seated to **0.0mm gun-local** at every frame it should be in the rifle; grip
standoff steady at 128.7mm.

**Snapshots kept:** `m16_reload_v1` (56f, the version approved before the retime),
`m16_fp_idle`, `m16_idle`.

## What we are correcting next

**1. `m16_reload_empty` is stale — rebuild it.**
It was assembled from the 56f tactical, then the tactical was retimed to 72f to match
`reload_time`. Its first 42 frames still carry the old timing, so its mag beats no longer
line up. Rebuild on the 72f base, then re-append the charging cycle (poses are captured and
ready).

**2. Clip separation needs NLA tracks, not active actions.**
This is the bug that broke the tactical reload at f51. The rig's action and the *part*
actions live on different objects, so `m16_charge_handle` kept playing underneath
`m16_reload` and dragged the handle around on the empty reload's schedule.
Patched for now with `m16_ch_inert` (handle pinned home, follow disabled), but the real fix
is one **NLA track per clip name** — `m16_reload` and `m16_reload_empty` — each holding the
rig strip *plus* its magazine and handle strips. Strips sharing a track name merge into one
glTF animation, so each clip exports self-contained. Same pattern already proven on the
AC-47 prop clips.

**3. Decide the reload duration.** 2.40s is what the game asks for, but it is slower than
the 1.87s that read well on screen and slower than the original 2.20s. Either accept 2.40s,
or set `reload_time = 1.87` in `data/weapons/m16a1.tres` and retime back. **No game data has
been touched.**

**4. Charging-handle throw: 84.5mm vs the 43.8mm posed.** The hand keeps travelling between
f60 and f62 while still attached, dragging the handle past the captured pose. 84.5mm happens
to be almost exactly the scale-accurate M16 stroke (~84mm at this model's 0.946 scale), so
it may be a happy accident — but it is not what was posed. Owner to choose.

**5. `ANIM_TIMING.md` is wrong about retiming.** Its "scalable reload" section assumes the
engine rescales clips for Agility and clamps playback 0.85–1.25×.
`scripts/player/weapon_holder.gd:709` says the opposite: *"ADR-018: the authored time,
always. Handling is not a stat."* There is no rescaling. Normalized event markers remain
good practice; the clamp reasoning is dead and should be corrected before it misleads the
next weapon.

**6. No empty-reload branch exists in code.** `_start_reload()`
(`scripts/player/weapon_holder.gd:692`) has no `current_ammo == 0` check, so
`m16_reload_empty` has nothing to trigger it. Engine work, not animation work.
Also noted: **jam clear is hardcoded to 1.1s** (`weapon_holder.gd:698`) — that is the
`jam` / tap-rack budget when we get to it.

## Open items carried from earlier

- **`grip_R_Claymore` is a guess.** The claymore had no markers; the grip was placed at the
  body centre, quarter-depth back, firing face downrange. Unverified.
- **`M72_LAW_rearcap` sits 2.16m adrift**; `Mosin_bayonet` + `Mosin_bay_socket` ~1.5m.
  Pre-existing in the source armories, cosmetic, will look broken on those two rigs.
- **`_STALE_weapons`** (52 objects) is a fossil under ADR-023 — delete once the grips are
  re-authored and verified.
- **Orphaned `ArmsMesh`** — parent deleted, hidden, one user. Inert but confusing.
- **Marker gaps:** `Colt45_Pistol` has no `grip_L` (needs one for a two-hand hold);
  `M26_Grenade` has right-grip only, which is correct.

## Traps that cost real time — do not repeat

- **Measure parts in the part's own space.** A magazine measured in world space reads as
  "moved" purely because the rifle tilted. Gun-local for the mag, rail-local for the handle.
- **Resolve poses with no action assigned.** With an action linked, every
  `view_layer.update()` re-evaluates it and silently overwrites a pose before the keyframe
  lands.
- **Never let a "fingers" dict contain the IK controls.** An idle-pose dict holding all 52
  bones reset `handIK.R` right after the tilt was applied, killing that key twice.
- **Re-solve grips in the tilted frame.** A grip derived against the level rifle misses by
  exactly the roll angle (21.4° here).
- **Prop handoffs must be CONSTANT-interpolated** and bound on the contact keyframe, not
  one frame either side.
- **Copied objects inherit `hide_viewport`,** and Blender does not evaluate transforms on
  hidden objects — producing phantom 64m/72m errors.
- **Duplicated armatures keep constraints pointed at the ORIGINAL rig.** All 19 copies
  inherited a `COPY_TRANSFORMS` aimed at `STALE_grip_L_M60_MG`, so every left hand was
  wearing the M60's grip.
