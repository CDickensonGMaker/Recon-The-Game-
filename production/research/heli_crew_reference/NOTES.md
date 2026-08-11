# Helicopter crew motion — beats read off footage

Reference pack, 2026-08-09. **This pack is the thing the earlier two could not do: actually
look at video.** `research/huey_pilot_motion/NOTES.md` states its own limit up front —
*"I could not watch video"* — and is text research. Everything below is read off contact
sheets extracted from downloaded footage.

Caleb's ruling, 2026-08-09: *"im not going to be filming anything so just watch more footage
of helicoptors in general because alot of the animations will be the same"* and *"look at
video game footage too"*. He is right that the ergonomics transfer across airframes — the
door-gun sheet below is an OH-58-class ship and reads identically to a Huey pintle station.

## Method

`raw/` held 793 MB of source video; **deleted after extraction** per the storage-bloat law.
Sheets are 16 frames spanning each clip, 4x4:

```
ffmpeg -i <in> -vf "fps=16/<duration>,scale=400:-1,tile=4x4" -frames:v 1 sheets/<id>.jpg
```

| sheet | source id | what it is |
|---|---|---|
| `gun_real_alvxPWq4aAM` | alvxPWq4aAM | pintle-mounted SAW, gunner POV + side, 377 s |
| `gun_game_UMDoWZvQRxc` / `uM0aOmoboqk` | — | game door-gunner footage |
| `pilot_huey_SVl7RdTxGOI` | SVl7RdTxGOI | **UH-1 cockpit startup POV**, 147 s |
| `pilot_real_Z9TSgh74rdg` | Z9TSgh74rdg | helicopter pilot cockpit, controls in view, 636 s |
| `load_real_s_jqpRxAF5c` | s_jqpRxAF5c | **MEDEVAC litter load into a Blackhawk**, 59 s |
| `load_game_HM_Ssvcphhg` | — | game insertion / disembark |

**Do not try to mocap any of it.** Settled by measurement in
`research/huey_loading/NOTES.md:42-65` — the cleanest take available (82% detection, 3%
contested, no warnings) still retargeted onto PSXRig as a collapsed splayed heap, because
2D confidence stays high while depth is garbage and depth is what the retarget eats. That
note explicitly puts **game footage in the same failure class**. Footage feeds beats;
clips get built by splicing the library and hand-keying contacts.

---

## THE FINDING THAT CHANGED THE MODEL

**`grip_collective_l/r` are NOT a mirror pair, and must never be symmetrised.**

`pilot_huey_SVl7RdTxGOI` rows 2–4: the left hand is down and low on the collective while
the right hand is forward on the cyclic between the knees — and each pilot's collective sits
on **his own left**, not mirrored about the aircraft centreline.

Checked against the authored values in `huey_v3.blend`:

| marker | x | seat x | offset |
|---|---|---|---|
| `grip_collective_l` | +0.190 | +0.550 | **−0.360** |
| `grip_collective_r` | −0.910 | −0.550 | **−0.360** |
| `grip_cyclic_l` | +0.550 | +0.550 | 0.000 |
| `grip_cyclic_r` | −0.550 | −0.550 | 0.000 |

Identical signed offset — the asymmetry was deliberate and correct. A symmetry pass run on
2026-08-09 read the 0.720 magnitude difference as a defect and averaged both to ±0.55,
which put each collective under its own seat centre. Restored to the values above.
**Cyclics DO mirror (0.000 offset, between the knees). Collectives do not.**

---

## Door gunner — `gun_real_alvxPWq4aAM`

The highest-value clip in the programme: `research/huey_pilot_motion/NOTES.md` records that
both door gunners currently play `sitting`, the same clip as a passenger, while being the
most-seen crew member on a flyby (outboard, eye level, unoccluded).

Beats read off the sheet:

1. **Stowed / not firing** (r1c2) — gun hangs on the pintle with the **barrel angled UP and
   outboard**. It is not held level. This is the idle silhouette.
2. **Both hands on the gun** (r2c3, r3c3) — shoulders squared to the receiver, arms extended,
   elbows soft, not tucked. Ammo can hangs on the receiver's left and rides with the gun.
3. **Firing depressed** (r3c3) — gun pitched steeply DOWN over the terrain; the gunner's
   whole torso pitches forward with it. Depression is body-driven, not wrist-driven.
4. **Seated, legs out** (r2c1, r2c4) — knees bent, feet on the skid/floor lip, outboard of
   the hips. Same silhouette the loading pack found for passengers.
5. **Lean-out scan** (r3c4) — torso leans OUT past the airframe line, head down, looking
   under/past the gun. Strongest single pose for a flyby read.
6. **Idle scan** (r4c1) — one hand resting on the gun, head turning aft, body relaxed back.

## Pilots — `pilot_huey_SVl7RdTxGOI`

1. **`pilot_flips_switches` is an OVERHEAD reach, not a forward one** (r1c1–c3) — the hand goes
   UP to the overhead console, fingers walking across breakers. Row 1 is almost entirely
   overhead work. Authoring this as a forward panel poke would be wrong.
2. **Forward panel touches** (r1c4, r2c2) — separate, shorter beat, reaching to the instrument
   panel face.
3. **`cockpit_controls` hold** (r2–r4) — left arm down-left and low to the collective, right
   hand forward-centre on the cyclic. The arms barely travel; the whole clip is small
   corrections. Loop it small.
4. **The two pilots are visibly doing different things** — one flies, the other is on the
   radio/panel. `seat_system.gd:153-154` dresses BOTH with one `_pilot_clip()` string, so a
   copilot variant is a code change, not just an art one.

## Crew chief / litter load — `load_real_s_jqpRxAF5c`

Fills the gap `research/huey_loading/NOTES.md:39` names: *"No crew chief reaching down to
haul men in."*

1. **Four-man litter carry** (r2c2) — two men per side, litter at waist height, crouched
   hustle, heads down under the disc.
2. **Crew chief kneels IN the doorway** (r2c4, r3c1) — one knee down on the cabin floor,
   torso out past the sill, both arms reaching DOWN and OUT to take the litter head. This is
   the missing beat.
3. **Marshalling arm** (r3c3) — crew chief stands in the door, one arm extended straight out,
   directing the carry party in.
4. **Slide, don't lift** (r4c3–c4) — the litter goes in along the cabin floor and is pushed
   inboard; nobody lifts it over anything.
5. Carry party **approaches from abeam the door**, never nose or tail — matches Caleb's
   standing side-loading ruling.

---

## What this unblocks

| clip | state | note |
|---|---|---|
| door gunner idle / scan / fire | **beats read, ready to author** | currently plays `sitting` |
| `cockpit_controls` | **beats read** | small-correction loop, arms low |
| `pilot_flips_switches` | **beats read** | overhead reach — likely wrong if already authored forward |
| `cockpit_idle` | beats read | relaxed variant of the hold |
| crew chief receive-litter | **beats read** | new clip, fills a named gap |
| `heli_board` / `heli_exit` | partial | still listed unmade in `ANIM_WISHLIST.md:124` |
| `cockpit_dead` | not covered | no footage sensible for it; hand-key |

---

# M60 DOOR GUNNER RIG — built 2026-08-10

Authored in `assets/us/vehicles/huey_v3.blend`. **The gun is driven; the hands follow.**

## Hierarchy (this is the contract — get it wrong and the whole mount swings)

```
pintle_X                      static, bolted to the airframe
├── pintle_X_mount            the BAR — mesh, NEVER moves (verified travel 0.00000 m)
└── pintle_X_traverse         YAW pivot, sits AT the gun (x +/-1.300, y 2.390, z 1.213)
    └── pintle_X_GunPivot     ELEVATION pivot, local X axis
        └── pintle_X_m60      gun mesh
            ├── MuzzlePoint   local (0, 0.65, 0.199)
            ├── grip_trigger  local (0, -0.17, 0.06)   right hand
            └── grip_fore     local (0, 0.06, 0.25)    left hand
```

**Base yaw: port −90°, starboard +90°** (aims the gun outboard). Key rotations as DELTAS off
that base — writing absolute values swings the gun to face the nose.

**Below `GunPivot` the local transforms are IDENTICAL on both sides, not mirrored** — the parent
chain already carries the mirroring. Mirroring them again put the starboard muzzle 0.55 m high.

**Elevation carries a built-in ~+17° bias** from the mount, so `actual ≈ input + 17`.

## Two bugs that cost a pass each

1. **The traverse pivot was 0.775 m from the gun** (at y 3.165 while the gun sits at y 2.390),
   so yaw swept the gun through an arc and dragged the whole mount with it — exactly what Caleb
   spotted as *"the m60 whole mount is moving when i just need the gun to pivot on its bar"*.
   Moving the yaw axis onto the gun took origin travel for a 20° yaw from 0.775 m to **0.0000 m**.
2. **Re-parenting baked the base yaw into `matrix_parent_inverse`**, silently cancelling it.
   After any re-parent, set `matrix_parent_inverse` to identity and rebuild the local transform.

## Hands

IK on `mixamorig:{L,R}ForeArm`, **chain_count 4** (forearm → arm → shoulder → Spine2) + copy-rotation
on the hands at 0.85. Chain 2 leaves a **0.1676 m** gap; chain 4 closes it to **0.0192 m**, because
the gunner then *leans into the gun* instead of reaching with his arms — which is what the footage
shows him doing.

## Clips (frames, gun elevation)

| action | frames | elevation | beat |
|---|---|---|---|
| `m60_gunner_idle_{l,r}_{traverse,GunPivot}` | 96 | +21° … +24° | stowed, barrel up and outboard |
| `m60_gunner_scan_{l,r}_*` | 120 | −16° … −4° | ±16° sweep, depressed over the ground |
| `m60_gunner_fire_{l,r}_*` | 48 | −16° … −11° | steep depression + recoil shudder |

All three verified: pintle symmetry 0.00000, mount travel 0.00000, worst hand-grip gap 0.0192 m.

**Constraints do not export to glTF — bake the IK to bone keyframes before any GLB.**

## Gunner body

Grunt body + **SPH-4 pilot helmet**, no ruck, no rifle (Caleb's spec). Bare forearms (t-shirt
sleeves) and black gloves done by **material split on bone weights**, not by repainting: the
uniform atlas is 3600x5700 and SHARED by every grunt, and the body mesh datablock is shared by
all 14 crew. Single-user the gunner bodies first. Skin tone sampled from `face_atlas_v5` over
2,362 px = (0.554, 0.380, 0.269).

M60 carries a **ring sight** (1,012 → 1,162 tris, shared by both guns) — visible on every door
gun in the game footage.

## EXPORT-READY BAKES (2026-08-10)

glTF does not carry constraints, so every gunner clip exists twice in `huey_v3.blend`:

| live (IK rig, editable) | baked (export-ready) |
|---|---|
| `GS_gunner_{l,r}` + `gun_ik` / `gun_rot` constraints | `m60_gunner_{idle,scan,fire}_{l,r}_BAKED` |

The bakes were made **non-destructively** — constraints are MUTED during the write, then
re-enabled — so the live IK rig is untouched and still tweakable. All six verified holding the
hands at **0.0191–0.0192 m** from the grips with constraints OFF, i.e. the bake reproduces the
constrained result exactly.

**To export:** mute the `gun_*` constraints, assign the matching `*_BAKED` action, export.
Leaving the constraints live AND assigning a baked action double-transforms.

### Bake recipe (reusable — the naive version is unusably slow)

1. Constraints ON: record `pose_bone.matrix` (armature space, post-constraint) for every frame.
2. Mute constraints, clear `animation_data`, create the new action.
3. Replay **parents-first**, grouped by hierarchy depth, with ONE `view_layer.update()` per depth
   level — not one per bone. 41 bones is ~7 levels, so this is ~6x fewer updates.
4. Keyframe location + rotation (respect each bone's `rotation_mode`).
5. Un-mute constraints, restore the previous action.

**Trap:** `keyframe_insert` on a rig writes into whatever action is ACTIVE. During the pilot
overhead build this silently added a `constraints["oh_ik"].influence` fcurve to
`cockpit_controls` — a SHARED library clip — extending its range 1-49 to 1-90. Caught by hashing
the action before and after. Always hash a shared action you did not intend to modify.

## New pilot clip

`pilot_flips_switches_overhead` — 90 frames, 410 fcurves, baked, constraint-free. Right hand
reaches an overhead console at z 1.98 (peak **+0.299 m above head height**). Replaces the library
`pilot_flips_switches`, which is byte-identical to `cockpit_idle` and peaks 0.206 m BELOW the head.
Arm reach measured 0.526 m from a shoulder at z 1.599, so max hand height is ~2.125 m — the roof
console is comfortably in range.

---

## 2026-08-10 — SEATING & POSTURE PASS

Second footage pass, same method (`yt-dlp` -> 4x4 contact sheet -> **read the image** -> delete raws).
7 clips fetched, **2 discarded before any beat was written**, and one of the discards is a finding
in itself. ~1.1 GB of raw video deleted; the whole pack is now 2.7 MB.

| sheet / frame | source id | what it is | verdict |
|---|---|---|---|
| `sheets/seating_ev63R_soRjo.jpg` | ev63R_soRjo | **UH-1 cockpit from the cabin, both seats, in flight, 203 s** | the pass's best clip |
| `frames/seat_av_details.jpg` (top row) | AVuvrQ5n9EM | **Vietnam-era door gunner at his M60, side-on from outside** | best gunner frame in the programme |
| `frames/seat_gunner_fire_strip.jpg` | Fc4z5GAuWqE | colour period gunner from inboard, firing + stowed | high value |
| `frames/seat_gunner_door_strip.jpg` | Fc4z5GAuWqE | period gunner, helmet marked "SAT", hands on gun, close | high value |
| `frames/seat_collective_hand_{a,b,c}.jpg` | mRUFRebsBzU | **UH-1 cyclic and collective grips, gloved hands, close-up** | hand poses |
| `frames/seat_crewchief_gun_{a,b}.jpg`, `seat_pilot_rear_b.jpg` | DlhP_YP5KFA | modern USMC crew chief at the door gun + pilot from behind | posture only |
| `sheets/seating_sIAMVsfdE4k.jpg` | sIAMVsfdE4k | DCS Huey door gunner (game) | corroboration only |
| ~~Wdsvemrti-U~~ | — | **AI-GENERATED SLOP** — "WW2: FORGOTTEN 45", invented captions, a cabin interior that is not any real airframe, distorted faces | **DELETED, wrote no beats** |
| ~~BEZ5uA8Uspg, xytxCr1uAdk~~ | — | real footage but no cabin/cockpit content | deleted |

**NEW HAZARD, and it is now a search hazard for every future pass: AI-generated "archive footage"
ranks in YouTube search for Vietnam war terms.** It looks correct at thumbnail size and it is
*confidently wrong* about exactly the thing this pack exists to establish — where a man sits and what
his hands touch. The tell was the captions ("Because Tomorrow Kovacs Will Strap On The M60 Again")
and the interior geometry, not the figures. **Read the sheet before you trust the search result.**

---

### A. DOOR GUNNER — how he sits and holds the M60

1. **The gun is at chest height and the mount hangs off the door-frame post, not off a floor
   pedestal.** SEEN — `seat_av_details.jpg` r1: the bracket is at the top of the door aperture, gun
   body level with the gunner's sternum, barrel angled DOWN and OUTBOARD.
   *Consistent with the rig already built: `pintle_X_traverse` at z 1.213 is about chest height on a
   seated body. No change indicated.*
2. **Both forearms are HORIZONTAL, elbows DOWN and close to the ribs — not flared.** SEEN —
   `seat_av_details.jpg` r1 and `seat_gunner_door_strip.jpg` r2c1-c2. **This contradicts the modern
   USMC crew chief** (`seat_crewchief_gun_a.jpg`), whose elbows ride UP near shoulder height on a
   heavier weapon. **Author the Vietnam M60 pose with elbows down.**
3. **Firing hand = pistol grip; support hand = OVER THE TOP of the receiver / feed-cover, palm down —
   NOT on a forend and NOT on the barrel.** SEEN — `seat_gunner_door_strip.jpg` r2c1-c2, the clearest
   single frame in the pack; corroborated by `seat_gunner_bw_strip.jpg` r2c1-c2 (grey nomex gloves on
   the receiver top, belt running under the wrist).
   *The rig's `grip_fore` at local (0, 0.06, 0.25) is a forend position. **Open question for the next
   rig pass: move it onto the receiver top, or accept the forend as a stylised read at PSX distance.***
4. **Body is turned ~90 deg OUTBOARD, square to the gun — the airframe axis runs across his back.**
   SEEN — `seat_av_details.jpg` r1, `seat_gunner_fire_strip.jpg` r1c2-c3. The hips do NOT stay facing
   forward with a twisted torso; the whole body rotates.
5. **Head is UPRIGHT and BEHIND the receiver — no cheek weld, chin roughly level, eyes over the top
   of the gun.** SEEN — `seat_gunner_door_strip.jpg` r2c1. He aims off tracer, not off a sight picture.
6. **He sits LOW: at the moment of firing his head is at roughly the vertical MIDPOINT of the door
   aperture, not near its top.** SEEN — `seat_gunner_fire_strip.jpg` r1c1-c4.
7. **Standing / half-crouched is a real second pose, used when the gun is elevated.** SEEN —
   `seat_gunner_fire_strip.jpg` r2c2: torso vertical, hips off the seat, leaning over a gun whose
   barrel points UP ~+25 deg, head looking DOWN past it. This is the transition between the stowed
   silhouette and a firing pass.
8. **Ammo can is bracketed on the gun's right and rides WITH it; the belt hangs in a visible free loop
   across the gunner's forearm/thigh.** SEEN — `seat_av_details.jpg` r1, `seat_gunner_fire_strip.jpg`
   r1c2-c3. A rigid belt reads wrong immediately at this camera distance.
9. **Torso pitch is the elevation control.** SEEN — confirms the 2026-08-09 beat. Depressing the gun
   pitches the whole upper body forward; the arm angles hold.
10. **Chicken plate: the gunner wears a bulky light-tan chest protector over the flight suit.** SEEN —
    `seat_av_details.jpg` r1, the torso silhouette is visibly thickened forward of the sternum.
11. **NOT SEEN — the seat itself.** In every real frame the gunner's hips and whatever is under them
    are occluded by the airframe or the gun. **Seat vs. armour plate vs. bare floor is UNRESOLVED
    from footage.** Do not author a seat mesh on the strength of this pass.
12. **NOT SEEN — the monkey strap / gunner's tether.** Zero frames across seven clips. Neither
    confirmed nor refuted. If it is wanted, it is a research gap, not a beat.
13. **NOT SEEN — foot position.** Feet are below frame in every usable gunner shot. The 2026-08-09
    "feet on the skid/floor lip" beat is NOT corroborated by this pass and stays single-sourced.

### B. PILOT / COPILOT — how they sit

Primary source `sheets/seating_ev63R_soRjo.jpg` — a real UH-1 cockpit filmed from the cabin, in
flight, both seats in frame for the full 203 s. **Caveat: modern crew — headsets not SPH-4 helmets,
no chicken plates.** The skeleton and the hands transfer; the kit does not.

14. **The seat back is a flat hard shell whose top edge sits at the NAPE — the base of the skull. The
    whole head clears it; there is no headrest.** SEEN — `seating_ev63R_soRjo.jpg` r1c2, r2c3, r4c2;
    `frames/seat_pilot_cockpit_rear.jpg`.
15. **Spine is UPRIGHT against the back, shoulders relaxed and slightly rounded, chin level. No slump,
    no forward hunch over the panel.** SEEN — every row of `seating_ev63R_soRjo.jpg`.
16. **Right hand on the cyclic: the arm hangs DOWN-AND-FORWARD, elbow near the hip, hand at about
    mid-thigh / waist height and slightly INBOARD of the knee. Forearm ~30-40 deg below horizontal.**
    SEEN — `seating_ev63R_soRjo.jpg` r1c2, r2c1, r2c4, r3c2, r4c4.
17. **Left arm hangs LOW at the left side and the left shoulder drops slightly below the right.**
    SEEN — `seating_ev63R_soRjo.jpg` r2c3, r4c2. **Independently confirms the asymmetry finding of
    2026-08-09** — the pose is not mirror-symmetric, and a symmetry pass will destroy it again.
18. **Cyclic grip: the hand wraps from BEHIND/SIDE like a handshake — thumb on the top button, index
    finger on the front trigger. The stick is vertical, between the knees.** SEEN —
    `seat_collective_hand_a.jpg` (red force-trim button under the thumb, radio trigger under the index).
19. **Collective grip: the hand comes over the lever from ABOVE, palm DOWN, fingers curled round the
    far side, thumb on the near side, wrist nearly flat, forearm roughly PARALLEL to the lever, elbow
    back near the hip.** SEEN — `seat_collective_hand_c.jpg`. This is a completely different wrist
    orientation from the cyclic hand — **the two hands must not share a pose.**
20. **The collective runs low and near-horizontal ALONGSIDE / OVER the left thigh, at about thigh
    height.** SEEN — `seat_collective_hand_b.jpg` (tan flightsuit leg at frame left, lever crossing it).
21. **The flying hand barely travels; the clip is small corrections.** SEEN — confirms 2026-08-09.
    Across 16 frames spanning 203 s the cyclic hand never leaves the grip and never moves more than
    about a hand's width.
22. **Head-turn to look out the side window is a real, frequent idle beat — ~45 deg yaw, chin stays
    level, shoulders do not follow.** SEEN — `seating_ev63R_soRjo.jpg` r1c3, r3c1, r3c3.
23. **The two seats are separated by a wide centre pedestal; inboard shoulders sit roughly one
    seat-width apart, and both crew hold the SAME posture in that frame — this is not a
    "one flies, one doesn't" moment.** SEEN — `seating_ev63R_soRjo.jpg` r4c2. Combined with the
    2026-08-09 beat (the two men *do* visibly diverge at other times), the copilot needs BOTH a
    matched-hold and a divergent variant. `seat_system.gd:153-154` still dresses both from one
    `_pilot_clip()` string, so that remains a code change.
24. **Shoulder harness: two straps in an inverted V over the chest to a central buckle, worn over the
    flight suit.** SEEN — `seat_av_details.jpg` r2 (period Huey pilot through the windscreen) and
    `seat_pilot_rear_b.jpg` (both shoulders, from behind).
25. **NOT SEEN — feet on the pedals.** No frame in any clip shows a pilot's legs or the anti-torque
    pedals. **Seat fore-aft position, knee angle and pedal reach are ALL UNRESOLVED.** Anything
    authored below the pilots' hips is invention and must be flagged as such.
26. **NOT SEEN — a chicken plate on a pilot.** The period pilot frame (`seat_av_details.jpg` r2) shows
    flight suit and harness with no visible plate; the modern crew wear none. Not refuted (a plate
    could sit under the harness), but this pack has no footage support for modelling one on a Huey
    pilot.

### C. PASSENGERS / GRUNTS IN THE CABIN — **THE GAP DID NOT CLOSE**

27. **NOT SEEN — all of it.** Three separate searches aimed squarely at this ("troops sitting in huey
    door legs out", "troops legs hanging out door air assault 1st cav", "inside huey cabin infantry
    riding to landing zone") returned **zero usable in-flight cabin interiors with troops aboard.**
    Every hit was exterior flyby, ground loading/unloading, cockpit, or the AI slop. Specifically
    unresolved: **floor vs. bench seats · legs dangling out the door · ruck worn vs. between the feet ·
    weapon between the knees vs. muzzle-down.**
28. **The one thing this pass CAN say about the cabin is negative and worth keeping:** in every real
    exterior of a loaded Huey here (`seating_43tzd08z2UQ.jpg` r2c4 and r3c4,
    `seating_AVuvrQ5n9EM.jpg` r4c4) the men visible in the door aperture are **upright and high in
    the frame, shoulders above the sill** — i.e. seated ON something, not sprawled on the floor. That
    is a silhouette read from ~100 m, not a posture beat, and it is the limit of what was seen.
29. **Recommendation:** this gap will not close via YouTube keyword search. It needs a named source —
    a specific documentary, or period still photography — and should be run as its own pass rather
    than bolted onto a crew-posture sweep.

### What changed vs. what was confirmed

| beat | status |
|---|---|
| collective/cyclic asymmetry (2026-08-09) | **CONFIRMED** from a second, unrelated clip |
| gunner elevates by pitching the torso | **CONFIRMED** |
| gunner idle = barrel UP and outboard | **CONFIRMED** (`seat_gunner_fire_strip.jpg` r2c1-c2) |
| gunner support hand on a FOREND | **CHALLENGED** — footage puts it on the receiver TOP, palm down, while the rig has `grip_fore` at local (0, 0.06, 0.25). Open question for the next rig pass. |
| gunner elbows | **NEW / SPECIFIED** — elbows DOWN, forearms horizontal. Do not copy the modern crew-chief flared-elbow pose. |
| collective hand orientation | **NEW** — palm down, over the top, wrist flat. Distinct from the cyclic hand. |
| pilot seat-back height | **NEW** — top edge at the nape, head fully clear, no headrest. |
| gunner's seat / monkey strap / feet | **STILL UNRESOLVED — flag anything authored there as invented** |
| pilot legs, pedals, seat fore-aft | **STILL UNRESOLVED — same flag** |
| passengers in the cabin | **STILL UNRESOLVED — needs its own named-source pass** |
