# GUN ANIMATION — THE WORKFLOW

**War Room, 2026-07-12.** Council: Technical Artist · Godot Specialist · Devil's Advocate.
**Full analyses:** `war_room/analysis/anim_*.md`

---

## ⛔ STOP. DO NOT AUTHOR A RELOAD YET. Two things must change first.

You were **right** about the shape of this — IK bones, hands locked to gun parts, the gun dismantled,
stage the parts, fill the gaps. That is genuinely how it's done. But the rig and the engine can't
execute it *today*, and if you author a reload right now you will see **nothing**, which is exactly the
loop you're stuck in.

### BLOCKER 1 — the gun is not on the rig. *(measured: `m16_fp.glb`'s glTF JSON was parsed)*

> The gun is a **static root sibling** of `ArmsRig`. No skin. No bone parent. **Zero animation channels.**
> `rifle_idle` carries **156 channels — every one a bone, not one of them touching the rifle.**
>
> **Author a reload today and your arms will perform it flawlessly while the rifle hangs motionless in
> mid-air.**

### BLOCKER 2 — the engine cannot play a second clip. *(verified, `weapon_holder.gd:939`)*

```gdscript
var vm_anim := weapon_model.find_child("AnimationPlayer", true, false) as AnimationPlayer
if vm_anim != null and vm_anim.has_animation("rifle_idle"):
    vm_anim.play("rifle_idle")
```

`vm_anim` is a **local variable.** It finds the player, plays the idle, and **throws the reference away.**
That is the **only** `.play()` call in 960 lines. There is **no reload call and no fire call.**

---

## 1 · THE GUN COMES APART — and your instinct about how was right

**The parts become BONES on `ArmsRig`, skinned 100% per part.** Not keyframed meshes; not
`BoneAttachment3D`.

- **Not keyframed meshes:** a track path like `M16A1_Rifle/Magazine:position` embeds the *gun's name*,
  which kills any shared library forever.
- **Not `BoneAttachment3D`:** that is a **follower**, not an animation target. It has exactly one correct
  job here — `MuzzlePoint` must ride the `gun` bone, or your muzzle flash spawns in **mid-air** the moment
  the rifle tilts during a reload.

### The bone chain, and the one non-obvious part

```
ArmsRig
├── hand.R / hand.L        (+ the handIK.L/R and elbowIK.L/R bones ALREADY IN YOUR RIG)
└── gun                    the receiver
    ├── magwell            *** never animated. Per-gun offset. ***
    │   └── gun_mag        the magazine
    ├── gun_bolt
    └── gun_charging_handle
```

**Why `magwell` exists — this is the detail that makes a shared library possible.** Bone tracks store the
**full local transform**, not a delta from rest. So a shared reload clip would drive the AK's magazine to
the **M16's** magazine position. **The never-animated `magwell` bone absorbs the per-gun geometry**, and
the clip expresses motion *relative to the well*. Get this wrong and every shared clip is subtly broken in
a way that looks like a rigging error and isn't.

> **AND THE MAGAZINE NEVER NEEDS REPARENTING.** In first person, **the animator owns the mag bone
> outright** and simply keyframes it into the hand and away. **Zero runtime code.** Your instinct — "lock
> the hands to the parts" — is right, and it's simpler than you feared: *the parts are just bones you pose.*

---

## 2 · YES, YOU CAN AUTHOR A RELOAD ONCE — per **family**, not per gun

**`ArmsRig` is already identical across all 13 viewmodels.** The precondition for a shared library is
already met, for free. Put the gun on the rig and every track becomes `ArmsRig/Skeleton3D:gun_mag` —
**gun-agnostic** — exactly the `PSXRig` contract your characters already use.

**Author the AR reload once → M16, CAR-15 and M14 all get it.**

**The honest limit (named, not hidden):** the AK **rocks** its magazine in; the M16 **drops** its straight
out. That is a *different motion*, not a different offset — no rig trick fixes it. Expect **~8 family
libraries**, not one. **Call it a 60–70% cut in authoring, not 100%.**

---

## 3 · ⚠ THE IMPORT LANDMINE — defuse this before you author a single clip

```
animation/remove_immutable_tracks = true      # Godot's DEFAULT
```

**A bone that doesn't move in a clip has its track DELETED at import.** So `idle` ends up with no
`gun_bolt` track at all — and after `reload_empty` releases the bolt, **the bolt stays locked back
forever.** You would chase that for a week and blame Blender.

**Set it `false` on every `*_fp.glb`.**

Also: **glTF carries no loop flag.** Your viewmodel has this bug *right now* — a breathing idle will
freeze on its last frame. Loop modes must be set in code at load.

---

## 4 · GODOT 4.7 GIVES YOU THREE THINGS YOU ARE NOT USING (grepped: zero hits)

| Feature | Why it matters |
|---|---|
| **`TwoBoneIK3D`** | **Your rig ALREADY has dead `handIK.L/R` + `elbowIK.L/R` bones** (`fp_grip.py:63`). You were right to keep them. Making them **live** in Godot is the escape hatch for per-gun hand correction — the support hand can find *this* gun's foregrip without re-authoring the clip. |
| **`SpringBoneSimulator3D`** | The **sling** and the **M60 belt**. Procedural follow-through on *every* clip, for free. **Best effort-to-payoff item on this entire page.** |
| **`AnimationNodeOneShot` (filtered)** | The fire layer — upper body only, over a running idle/walk. |
| Ping-pong loops (4.7) | Halve the keyframes in every breathing idle. |

---

## 5 · **AUTHOR THE JAM FIRST. NOT THE RELOAD.**

**30 frames.** It binds to `weapon_jammed`, **a signal that already fires into the void.** It is the most
dramatic moment in the game — the gun dies in your hands while a man is running at you — and it is a
**rehearsal for the back third of the reload** (mag out, clear, seat, charge). Two project docs and an
independent grep all landed on the same answer.

---

## 6 · THE ENGINE WORK (mine, ~120 lines, touching ZERO combat logic)

New `scripts/weapons/viewmodel_anim.gd` — a pure listener. **Every signal it needs already exists and
already fires** (the HUD subscribes to four of them). Plus five changes in `weapon_holder.gd`:

1. **Cache the `AnimationPlayer`** instead of throwing it away in a local var. *(This is the bug.)*
2. Set **loop modes** at load (glTF has no loop flag).
3. Branch **`reload_empty`** when `current_ammo == 0` — a dry gun needs the bolt released.
4. **Fire `reload_cancelled`.** It is declared at `weapon_holder.gd:12` and **emitted nowhere**, which
   means a reload is currently an **uninterruptible 2.5-second commitment.** That is a **Pillar 1 bug**,
   not an animation nicety. Commit the magazine at the ~60% beat; allow abort before it.
5. **`MuzzlePoint` → `BoneAttachment3D`** on the `gun` bone, or the flash detaches on every reload tilt.

---

## 7 · THE COST, STATED HONESTLY

**Putting the gun on the rig invalidates all 13 `*_fp.glb` exports and their `.tscn` wrappers**, and
`export_viewmodel.py` must **skin** the gun instead of selecting it as a static object.

**Unavoidable — and far cheaper NOW, before eight clips per weapon exist, than it will ever be again.**

---

## 8 · THE ORDER

| # | Step | Whose |
|---|---|---|
| 0 | **`remove_immutable_tracks = false`** on every `*_fp.glb` | mine, 5 min |
| 1 | **Rig the gun as bones** on `ArmsRig` (`gun → magwell → gun_mag`, bolt, charging handle). Re-export one gun — the **M16** — as the pilot. | **yours** |
| 2 | Cache the AnimationPlayer + `viewmodel_anim.gd` + fire `reload_cancelled` + MuzzlePoint on the bone | mine |
| 3 | **Author `jam`** (30 frames) on the M16. **Watch it play in-game.** | **yours** |
| 4 | Then `reload` and `reload_empty` on the M16 | **yours** |
| 5 | Roll the rig change to the other 12; author the 8 family libraries | **yours** |
| 6 | `TwoBoneIK3D` on the live `handIK` bones + `SpringBoneSimulator3D` on the sling | mine |

**Step 3 is the whole point of this ordering.** You will see a clip you made *play in the game* before you
have invested a week in animation — which is the exact failure you asked me to fix.
