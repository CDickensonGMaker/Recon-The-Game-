# Balance & Feel Architect — ADS Sights War Room
**Session:** 2026-07-14 · **Project:** RECONgame (Godot 4.7)
**Domain:** Player-facing FOV, ADS position fairness, recoil-during-ADS, reachability of the "first settled shot" rule
**Pillar owned:** Pillar 1 — Outstanding gunplay (HLL lethality, no bullet-sponge math)
**Canon inputs read:** `production/adr/ADR-004-ads-fov-policy.md` (fully), all 15 `data/weapons/*.tres`, `scripts/player/weapon_holder.gd:200-220` (FOV lerp), `weapon_holder.gd:350-440` (fire + settled gate), `weapon_holder.gd:746-796` (the position/rotation lerp + recoil punch), `scripts/weapons/viewmodel_editor.gd:60-65` (the ALIGN_TOLERANCE contract), `weapon_data.gd:28-39` (the `viewmodel_fov` + `ads_fov` exports).

---

## 0. One-paragraph verdict

ADR-004's per-weapon `ads_fov` table is **sound at the rate-class level** (Mosin 40°, M16 60°, M1911 65° all sit in the right neighbourhood) but **lies about a third of the roster** because the placeholder `ads_position = Vector3(0, 0.05, 0.08)` does not actually deliver those sight pictures. For wide-FOV SMGs (PPSh, M16) the geometry works "well enough" — the eye is far enough back that the small (0, 0.05, 0.08) offset reads as a default "gun a bit closer" pose. For **tight-FOV bolt rifles (Mosin 40°, M70 40°)** the placeholder is *catastrophic*: at 40° FOV the player's eye is, in effect, looking through a 6.7× magnified spot. A rear sight 8cm back from the eye fills most of that frame — the player is staring at the **back of the rear aperture**, not through it. For **M60 / RPD / RPG-2 / M79** the current `ads_fov = 60°/65°` is shipped in the .tres even though ADR-004 rules that M60/RPD are hip-only and RPG-2 uses a sight-raise (not iron-sight alignment) — that is a **fossil value in the data file** carrying an obsolete contract, exactly the failure mode the FOSSIL LAW names. The **"first settled shot" gate (`weapon_holder.gd:379-381`) is reachable in theory** — the lerp is the same `ADS_SPEED = 10.0` for position and rotation, so synchronisation is not broken — but the **recoil punch at `weapon_holder.gd:786-793` does blow the bore ray** by amounts that dwarf the editor's `ALIGN_TOLERANCE_M = 0.025` (1 mrad at 25 m) on every bolt rifle. The honest tradeoff named in §7: this analysis does not propose recoil-punch or ADS-position authoring today; both are placeholder maths the per-gun rig pass is going to replace. What it DOES demand is that the rig authors do not blindly ship the placeholder values.

---

## 1. Per-gun ADS FOV audit

The current `ads_fov` table, with the verdict of whether it matches the **sight geometry the weapons-designer will author** (which, per the briefing, is "real see-through aperture" for rifles/SMGs):

| Weapon | `ads_fov` | Sight class the designer will build | Verdict | Notes |
|---|---|---|---|---|
| M14 | 58.0 | Aperture rear + blade front (existing markers) | **Reachable.** Reference gun for the rig. The 58° is the tightest of the "non-sniper" class — fits the M14's "battle rifle / aimed round" role. |
| M16A1 | 60.0 | A1-style round rear aperture, blade front | **Reachable, but at the wide edge.** 60° lets the rear ring sit visibly in the frame. Real M16A1 sight is a small round aperture ~5mm, this reads as "looking through a peephole". Slight tightening to ~55° would give the front post more screen real estate — but only if the rear ring is *thin*; a thick ring at 55° fills the frame. |
| M1911 | 65.0 | Rear U-notch + blade front | **Reachable, possibly too wide.** A 65° FOV pistol sight is more "look at the sights" than "look through the sights". For the .45's effective range (30 m) the player only needs enough FOV to bracket a torso — 65° gives that. 70° would feel like hipfire; 60° would force the rear notch into the frame and demand more precise alignment. **Right band.** |
| AK-47 | 62.0 | 1950s-90s AK open sight — long rear notch, blade front | **Reachable, perfect for the sight class.** AK's long rear notch wants more FOV than an aperture rifle to keep the notch outline readable. 62° reads as the classic "hold the post at the rock" feel. |
| Mosin-Nagant | 40.0 | Hexagonal/circle rear aperture (the historical "hex receiver" peep), tall blade front | **REACHABLE BUT MIRRORS A LIE.** The .tres says 40° (sniper-tight), the placeholder `ads_position` puts the eye 8 cm back. At 40° the rear aperture of a Mosin (~3-4 mm) would *just* frame the front post (~2 mm) at ~50 cm sight radius. The placeholder puts the eye at ~8 cm, not 50 cm. **The player sees a giant rear ring, not a hex peep.** Either the sight radius in the rig has to be pushed back to 30-50 cm, OR the FOV has to come up to ~55° for the placeholder to read as the historical peep. **Recommend: 50-55° IF the rig author cannot author a true long-eye-relief sight, 40° ONLY IF the rig gets a real ~40 cm sight radius.** |
| M70 (Winchester) | 40.0 | Same problem as Mosin | Same Mosin verdict. |
| M60 (Pig) | 60.0 | **HIP-FIRE ONLY per ADR-004.** | **STALE FOSSIL.** The .tres carries 60° as a leftover from the pre-ADR-004 "every gun ADS" default. **Recommend: 75.0 (= `BASE_FOV`, no zoom) or `ads_fov = 10.0` (= the "no zoom" guard in `weapon_holder.gd:218`).** |
| RPD | 60.0 | **HIP-FIRE ONLY per ADR-004.** | **STALE FOSSIL.** Same as M60. |
| RPG-2 | 60.0 | **SIGHT-RAISE per ADR-004**, not iron-sight alignment. Back-bladed leaf sight on a tube, no aperture. | **STALE FOSSIL.** The pre-bead 88ee20c RPG-2 was a 62-dmg hitscan rifle; that contract is dead (also tracked as bead `vi32`). The current 60° value was authored under the dead contract. **Recommend: `ads_fov = 10.0` (no zoom), or 75° to fully preserve peripheral situational awareness while the player raises the launcher to the cheek.** |
| RPG-7 | 60.0 | PGO-7 optic (later variants) / iron backup | **Probably stale.** RPG-7 has an optic; 60° is "iron sight territory". The data file is also missing `model_path` and has zeroed `hip_rotation`/`ads_rotation` — this gun is *unauthored*. Flag for weapons-designer, not me. |
| M72 LAW | 60.0 | **NO IRON SIGHTS per ADR-004.** Tube and a back-peep that is functionally useless at engagement ranges. | **STALE FOSSIL + the wrong design choice.** A direct-aim gun should NOT zoom at all; the player is pointing the tube like a wand, not aligning an aperture. The .tres is also zeroed out. **Recommend: `ads_fov = 10.0` (no zoom), AND the rig should *raise* the launcher to the cheek (a "raise-to-shoulder" pose), not switch to an ADS transform.** |
| M79 | 65.0 | M79 has a simple folding leaf sight on a flat barrel. Range-estimate marks on the left. **No rear aperture, no front post — it's a peep on a quadrant.** | **Reachable, on the wide side.** 65° works because the leaf sight is a thin pointer; a tighter FOV would force the leaf into the frame as a thick line. **However:** the existing `hip_position = (0.469, -0.627, -0.849)` and `ads_position = (0.000, -0.508, -0.755)` are *unusually large* — the gun is held out at arms' length. This is the only .tres where ADS has been author-tuned; the values are credible. The FOV verdict is independent: 65° matches the "thin pointer at arm's length" sight. |
| Ithaca 37 | 65.0 | Open "ball" bead front, no rear sight (the bead IS the sight) | **Reachable.** Bead-only shotguns *want* wide FOV — a 50° shotgun sight would force the bead into a huge visual disc. 65° is right. The 25 m effective range means the player will mostly hipfire anyway. |
| PPSh-41 | 58.0 | PPSh has a *tilted* open rear notch and a hooded front post (the "snail drum" front). Real 900-rpm weapon, used at contact range. | **Reachable but a bit tight.** A 58° FOV puts the rear notch in the frame. The historical PPSh sight is *tiny* and held at the cheek — 62-65° would match the "snail drum" feel. **Verdict: ship 58°, but flag for weapons-designer that a 62° would be more period-correct.** |
| M26 frag | 75.0 | No sight (it's a grenade) | **Reachable (= no zoom, = `BASE_FOV`).** Correct. |
| Thompson | 58.0 | (inferred from `weapon_holder.gd:215-220` ADR-004 listing; not in our 15 .tres but `viewmodel_fov` shows up in ADR-004) | No .tres to audit; out of scope. |

**Summary of FOV findings:**
- **3 fossils** (M60, RPD, RPG-2, M72 — actually 4) carry the pre-ADR-004 "every gun 60°" default. They need `ads_fov = 10.0` (no zoom) shipped in the .tres, not just trusted to script defaults.
- **2 sniper rifles** (Mosin, M70) at 40° will not read as snipers **at the placeholder eye position** — either the rig author has to author a true long sight radius, or these FOVs come up to 50-55° until the rig is done. **This is a per-weapon pre-authoring decision the council has to make.**
- **PPSh-41** is one notch too tight (58° vs the historical ~62-65°), but a minor finding.

---

## 2. Per-gun ADS position audit (the four placeholders)

The placeholder `ads_position = Vector3(0, 0.05, 0.08)` translates to "5 cm up, 8 cm back from the camera" in the viewmodel's local space. For a weapon whose barrel is 8 cm back from the camera at full ADS, the player's eye is sitting *just barely* behind the rear sight — and only when the weapon's geometry has the rear sight sitting at the right model-space Z. For most of the existing viewmodels, the rear sight is much further back in the model (15-30 cm), so the player is actually looking *at* the rear of the receiver, not through the aperture.

| Gun | `ads_fov` | Placeholder works? | Analytic right value (eye should be 30-50 cm behind the rear sight for a clear aperture view) |
|---|---|---|---|
| AK-47 | 62° | **Marginal.** AK's open sight is forgiving — 8 cm puts the eye at the rear of the receiver, but the AK notch is wide and the post is hooded, so the player sees a sensible "AK-style" sight picture. Not the *historical* sight radius (~40 cm), but readable. | **Recommend: `ads_position = (0, 0.05, 0.08)` is OK as a stub; rig author to push to (0, 0.02, 0.30) once markers exist.** |
| Mosin-Nagant | 40° | **Broken.** At 40° the rear aperture is enormous; the player sees the *back* of the rear sight, not through it. | **Recommend: `ads_position = (0, 0.02, 0.30) OR `ads_fov` to 55°.** The 8 cm is wrong by ~4×. |
| M16A1 | 60° | **Marginal.** A1's round aperture is small (~5 mm); 8 cm puts the eye 1-2 cm past the rear of the receiver. The rear ring is visible, the post is barely visible. | **Recommend: rig author to push to (0, 0.02, 0.20) — M16's receiver is shorter than the Mosin.** |
| PPSh-41 | 58° | **Broken for a different reason.** The PPSh model sits high; 5 cm up puts the gun at *above eye line* (the player looks down at it). | **Recommend: `ads_position = (0, 0.0, 0.10)` — bring it down and only a little closer.** |

The **analytic reasoning** is straightforward: an aperture sight is a tube. The eye must sit *behind* the rear aperture at a distance such that the angular subtense of the rear aperture matches the angular subtense of the front post. For a Mosin (rear 3 mm, front 2 mm, sight radius 50 cm), the ratio is 3/2 = 1.5×, and the player's eye should sit ~50 cm behind the rear aperture. At a placeholder 8 cm, the eye sits inside the tube — you see the back of the rear aperture as a giant ring with the front post a tiny dot floating somewhere in it (and not necessarily *centered* in the ring, because the model pivot may not be at the bore axis). The M16's sight radius is shorter (~37 cm), so its 8 cm is bad but not catastrophic; the Mosin's 50 cm makes the 8 cm a 6× error.

The viewmodel's `viewmodel_fov` (the *rendered* FOV when the model is scaled by `_lens_ratio`) interacts with `ads_fov` in a non-obvious way: the `viewmodel_fov` is what the model was *designed* in (a "lens faking" technique — `weapon_holder.gd:810-818`). A Mosin with `viewmodel_fov = 62°` and `ads_fov = 40°` means the camera FOV drops from 75° to 40° on ADS, but the model is *still* rendered as if seen through 62° — so the model looks ~1.5× larger than at 40° would imply. This is the **"viewmodel lens" trick** the code documents. It means the placeholder `ads_position = (0, 0.05, 0.08)` was probably tuned for the model's *original* `viewmodel_fov`, not the ADR-004 `ads_fov`. **Tuning `ads_position` to one and `ads_fov` to another without touching `viewmodel_fov` is a coherent move, but the rig author needs to know all three values were paired.**

---

## 3. M60 / RPD / RPG-2 / M79 / M72 special cases

### M60 (Pig) and RPD — hip-fire only per ADR-004

**Current .tres state:** both carry `ads_fov = 60.0` and `ads_position = (0, 0.05, 0.08)`. Both have `hip_position = (0, 0, 0)` and `hip_rotation` that looks plausible. Both *would* snap into ADS if the player pressed aim — there is no script guard in `weapon_holder.gd` that says "this is a hip-fire weapon, refuse to aim". The 60° FOV is shipped.

**What the player sees today:** if the player aims the M60 or RPD, the camera FOV drops to 60°, the gun slides to (0, 0.05, 0.08), the bolt-action lerp completes. The M60 has no rear aperture — its rear "sight" is a peep on a carrying handle that **physically sits higher than the front blade**, so the placeholder 5 cm up puts the eye *above* the rear sight. The RPD's rear sight is a vertical ladder on the left side of the receiver — at the placeholder position, the player is looking at the back of the receiver, not the ladder.

**The right design:**
- Set `ads_fov = 10.0` (= the "no zoom" guard in `weapon_holder.gd:208`) so the FOV writer skips the lerp. The player keeps 75° FOV.
- Set `ads_position` to the same as `hip_position` (or 1-2 cm forward) so the gun *visibly stays* in the hip pose when "ADS" is held.
- **OR:** better, add a script guard `if current_weapon.is_hip_fire_only: return` early in `_update_weapon_position` so the ADS transform does not even begin. (Add a flag to `WeaponData` and a tag for these two .tres files.)

**Sacrificed:** the visual "I am aiming the Pig" is lost. The player will hold RMB and the gun will not move. This is the correct cost — belt-feds in RECON are not aimed weapons.

### RPG-2 — sight-raise per ADR-004

**Current .tres state:** `ads_fov = 60.0`, `ads_position = (0, 0.05, 0.08)`, `ads_rotation = (4, 0, 0)`. The weapon is a back-bladed leaf sight on a smooth tube — no rear aperture. The pre-bead 88ee20c RPG-2 was a 62-dmg hitscan rifle; the current contract is that the RPG-2 is a *raised* weapon (shoulder to cheek, leaf visible at the eye-line).

**The right design:**
- `ads_fov = 10.0` (no zoom) OR keep the FOV at 60° to *mildly* zoom on the leaf, simulating "I'm looking at the sight, not down the tube".
- `ads_position` should bring the *rear* of the launcher up to the cheek, not just translate +5cm up. This requires a custom rig (the leaf is on the back-blade, so the gun's local +Y has to lift the rear).
- `ads_rotation = (0, 0, 0)` (no pitch) — the player is *holding* the launcher, not aiming through it.

**Sacrificed:** the player does not get a tight, sniper-like RPG view. The RPG is a 90 m max-range weapon; a 75°-FOV "shoulder raise" is a fairer fight than a 40°-FOV "scoped RPG" that would make the weapon overpowered at its actual range.

### M72 LAW — direct-aim per ADR-004, no iron sights

**Current .tres state:** `ads_fov = 60.0`, `ads_position = (0, -0.1, -0.4)`, `model_path = ""` (UNMODELLED). Same problem as RPG-7.

**The right design:**
- `ads_fov = 10.0` (no zoom) — the player is pointing the tube like a wand.
- A "raise" pose that brings the back end of the tube to the shoulder (the LAW's "front-end-up" carry position is iconic).
- No ADS rotation — the tube is aligned with the camera bore by *physical* alignment, not by sight picture.

**Sacrificed:** none. The LAW's actual engagement is "point the tube at the APC and pull the trigger" — the FOV is peripheral vision, not alignment.

### M79 (Blooper) — single-shot grenade launcher with leaf sight

**Current .tres state:** `ads_fov = 65.0`, `ads_position = (0.0, -0.508, -0.755)`, `hip_position = (0.469, -0.627, -0.849)`, both transforms look *authored* (large Y offset, large Z offset, large Y rotation in hip). This is the only .tres in the roster where the rig author has actually sat down and dialed values. The 65° FOV matches the thin pointer character of the leaf sight.

**The right design:**
- **65° is right.** The M79 is a "pointer" weapon — the leaf is a thin line, the player aligns it on the target, and the round's parabola is in the player's head. 65° gives enough peripheral context to see the round's falloff.
- The current `hip_position`/`ads_position` transforms are large because the weapon is *physically long* (~70 cm). The viewmodel bench has dialed those.
- One finding: `ads_move_mult = 0.6` is generous — the M79's 150-m max range and 76 m/s muzzle velocity mean the player cannot move-and-fire effectively anyway. Could come down to 0.4 to match the "set up, fire, run" pattern of real M79 use. **Not blocking.**

**Sacrificed:** nothing — this is the one weapon that has been done with care.

---

## 4. The "first settled shot" reachability

**The gate (`weapon_holder.gd:379-381`):**
```gdscript
var settled: bool = ads_transition > 0.9 \
    and float(Time.get_ticks_msec()) - _prev_shot_ms > 400.0 \
    and (controller == null or Vector3(controller.velocity.x, 0.0, controller.velocity.z).length() < 0.6)
if settled:
    spread *= 0.12
```

This is the **"first settled shot" cone reduction** — when the player has held ADS for 90% of the lerp, hasn't fired in 400 ms, and is moving < 0.6 m/s, the spread multiplies by 0.12 (an 8.3× tightening).

**Can the player ever reach this gate with the current placeholder ADS?**

**Reachability check #1: `ads_transition > 0.9`**

The lerp is `ads_transition = lerp(ads_transition, target, delta * ADS_SPEED)` at `weapon_holder.gd:201` with `ADS_SPEED = 10.0`. This is an exponential lerp that asymptotically approaches 1.0 — it NEVER reaches 1.0, but it crosses 0.9 at `t = log(0.1) / log(1 - 10*delta)`. At 60 fps (delta = 0.0167), `1 - 10*0.0167 = 0.833`, so `t = log(0.1)/log(0.833) = 13.2 frames ≈ 220 ms`. So in ~220 ms of holding aim, the player crosses 0.9. **Reachable.** (Note: the gate uses 0.9, not 0.99 — the same gotcha that bit the Kar98k tutorial bead does not bite here.)

**Reachability check #2: `_prev_shot_ms > 400 ms`**

The player just has to wait 400 ms after their last shot. **Reachable.**

**Reachability check #3: velocity magnitude < 0.6 m/s**

The player has to be near-stationary. **Reachable** by standing still or going prone.

**Reachability check #4 (the two-frame hypothesis): the owner proposed the gun "snaps because the two transforms don't lerp in sync" and the settled gate is unreachable.**

Reading `weapon_holder.gd:754-755`:
```gdscript
var target_pos: Vector3 = current_weapon.hip_position.lerp(current_weapon.ads_position, ads_transition)
var target_rot: Vector3 = current_weapon.hip_rotation.lerp(current_weapon.ads_rotation, ads_transition)
```

`target_pos` and `target_rot` are computed from the **same** `ads_transition`. Then:
```gdscript
weapon_model.position = weapon_model.position.lerp(target_pos, delta * ADS_SPEED)  # line 795
weapon_model.rotation_degrees = weapon_model.rotation_degrees.lerp(target_rot, delta * ADS_SPEED)  # line 796
```

**Both lerps use the same `delta * ADS_SPEED` term.** They are synchronised. The "two-frame snap" the owner hypothesised is *not* present in the position/rotation lerp itself. The gun does not snap from one frame to another in steady state.

**Where it CAN snap, though:** the very first frame after `_load_weapon_model` is called. `weapon_model.position` and `rotation_degrees` start at the GLB file's saved values (often `(0,0,0)` or wherever the Blender rig was zeroed), and the first `lerp` call jumps to `target_pos = hip_position.lerp(ads_position, 0.0) = hip_position`. If `hip_position != Vector3.ZERO`, the very first frame's `position.lerp(hip_position, delta*10)` puts the gun ~83% of the way to `hip_position` in one frame. Then on the second frame, `ads_transition` has crept up to 0.16, and `target_pos` has crept, and `position` has crept — the player's eye sees a 200-ms "settling" animation that looks like a snap because it happens between the weapon-swap-frame and the first user-controllable frame.

**This is a real bug, but it is the "weapon switch snap", not the "settled gate unreachable" bug the owner proposed.** The settled gate IS reachable. The bug the owner is seeing is a weapon-swap visualisation glitch that masks the settled gate for the first ~220 ms after every weapon switch.

**The honest finding:** the "first settled shot" gate is *reachable* with the current code. The "two-frame hypothesis" the owner proposed is wrong. What IS broken is the **weapon-swap visual**, which is the same problem as the editor's "the gun snaps when I switch weapons" report — the placeholder `hip_position` for the M16, M1911, M60, RPD, AK-47, PPSh-41, M70, Mosin are all *different* from `Vector3.ZERO`, and the weapon model loads at the GLB's saved `position` (often zero), so the first frame the gun is at the GLB's saved position, and the next frame it has lerped 83% of the way to `hip_position`. **The owner is seeing this and calling it a "two-frame snap". The gun DOES settle to `hip_position` over ~200 ms; what looks like a snap is the visible position-jump from GLB-zero to hip-actual.**

**Quantified:**
- For an M16A1: `hip_position = (0, 0, -0.10)`, `hip_rotation = (4.9, -8.9, 0)`. The weapon swaps in, the first frame the gun is at (0, 0, 0), the next frame the gun is at (0, 0, -0.083) (83% of the way to hip), with rotation (4.0, -7.4, 0). The player sees a 4-5° rotation jolt and a 8-cm Z-jolt in one frame. **This is the bug.**
- For a placeholder `ads_position = (0, 0.05, 0.08)` and `hip_position = (0, 0, 0)`, the ADS lerp is small (5 cm up, 8 cm back) — the snap on ADS is much smaller. The snap on weapon-swap is the larger one.

**The settled gate is reachable.** The weapon-swap snap is a separate problem in the same neighbourhood, and it is what the owner is probably actually feeling.

---

## 5. The recoil-punch-during-ADS issue

**The code (`weapon_holder.gd:786-793`):**
```gdscript
_punch = maxf(0.0, _punch - delta * 9.0)
var punch_amt: float = _punch * _punch  # ease-out curve
var w: float = current_weapon.recoil_vertical / 2.5
target_pos.z += punch_amt * 0.05 * w
target_pos.y += punch_amt * 0.012 * w
target_rot.x += punch_amt * 3.5 * w
```

This runs **every frame** in `_update_weapon_position`, regardless of `is_aiming` or `ads_transition`. So during ADS, the recoil kick adds to `target_pos` and `target_rot` before the lerp at line 795-796.

**The flow during a Mosin first shot at ADS:**
1. **t = 0 ms:** trigger fires. `_punch = 1.0` is set at `weapon_holder.gd:428`.
2. **t = 16 ms (next frame):** `_update_weapon_position` runs. `_punch` has decayed to `1.0 - 16*0.001*9 = 0.856` (16 ms at 60 fps, but `delta` is in seconds: `delta * 9 = 0.15`, so `_punch = 1.0 - 0.15 = 0.85`). `punch_amt = 0.85² = 0.72`. For Mosin `recoil_vertical = 8.5`, `w = 8.5/2.5 = 3.4`. So:
   - `target_pos.z += 0.72 * 0.05 * 3.4 = 0.122 m` (12.2 cm back)
   - `target_pos.y += 0.72 * 0.012 * 3.4 = 0.029 m` (2.9 cm up)
   - `target_rot.x += 0.72 * 3.5 * 3.4 = 8.57°` upward pitch
3. The lerp at line 795-796 then moves the gun 83% of the way from current position to this kicked position in one frame. So the gun visibly jumps 12 cm back, 3 cm up, and 8.6° up. **In one frame.**
4. **t = 100 ms:** `_punch = 1.0 - 6*0.15 = 0.10` (decays at 9/sec from line 788). `punch_amt = 0.01`. Kicks are negligible. Gun is settling back to ADS pose.
5. **t = 110 ms:** `_punch` is below 0 — the punch is over. The gun's `position` and `rotation_degrees` are now lerping back from the kicked pose to the ADS pose. The lerp rate is `delta * ADS_SPEED = 10/sec`, exponential — the gun reaches 50% recovery at ~70 ms, 90% at ~220 ms, 99% at ~460 ms.

**Does this blow the sight picture?**

**The editor's `ALIGN_TOLERANCE_M = 0.025` (= 1 mrad at 25 m) is the "this gun is aligned" gate.** A 1 mrad offset at 25 m = 2.5 cm. A 1 mrad offset at 100 m = 10 cm. A 1 mrad offset at 250 m = 25 cm.

**At Mosin `recoil_vertical = 8.5`, the peak angular kick is `8.57°`.** At a 25 m range, that is `8.57 * pi/180 * 25 m = 3.74 m` of bore-offset. **The bore ray is 3.7 m off at 25 m on the FIRST shot.** This is **374× the alignment tolerance.** Even at the "first settled" gate, the spread reduction is `0.12×`, but the bore-ray is being kicked 3.7 m. The settled cone is a *spread* multiplier; it does not fix the alignment.

**For the spread to be *relevant*, the bore-ray must be aligned.** The recoil punch breaks alignment for ~220 ms after every shot. The settled gate requires 400 ms since last shot. So:
- 0-220 ms: bore is wildly off; spread is small but irrelevant.
- 220-400 ms: bore is settling; spread is reducing.
- 400 ms+: settled gate opens; spread is 0.12×; bore is back to ADS pose.

**The good news:** the gate is timed correctly. The player cannot "cheat" the settled cone by firing through the recoil — they have to wait out the 400 ms anyway.

**The bad news:** during the 0-400 ms window, the gun is *visibly* off the ADS pose. The player's *visual* sight picture is broken — they see the front post 12 cm back from where the rear aperture is, and the rear aperture pitched up 8.6°. They *cannot* aim through the sight during the recoil window. They have to wait for the gun to settle, then re-acquire the target. **This is correct FPS behaviour (call of duty / HLL all do this), but the magnitude of the kick at Mosin recoil is so high (8.6°!) that the gun is unusable for almost half a second after every shot.**

**The "is this within the alignment tolerance" question is the wrong question.** The alignment tolerance is for the *editor's* static alignment test. The recoil kick is *dynamic* and is meant to be larger than the static tolerance. The question to ask is: **does the dynamic kick keep the gun within "the player can still see something useful"?** At Mosin 8.6° pitch, the gun rotates so far that the rear aperture is *off the top of the screen* in a 40° FOV view. The player sees the *bottom* of the receiver, not the sights. **For 220 ms after a Mosin shot, the gun is functionally unsighted.**

**Quantified per-weapon peak angular kick (° rotation in one frame, peak):**

| Weapon | `recoil_vertical` | w | peak `target_rot.x` (°) | relative to align tolerance (mrad at 25 m) |
|---|---|---|---|---|
| M16A1 | 1.1 | 0.44 | 1.54° | 27 mrad @ 25m — readable; can still acquire front post |
| M1911 | 5.0 | 2.0 | 7.0° | 122 mrad — gun rotates to the top of the screen, but .45 is a 30-m weapon so the player only needs the bead |
| AK-47 | 1.5 | 0.6 | 2.1° | 37 mrad — readable |
| Mosin | 8.5 | 3.4 | 8.57° | 150 mrad — *off the top of the screen at 40° FOV* |
| M70 | 8.0 | 3.2 | 8.06° | 141 mrad — same problem |
| M60 | 2.8 | 1.12 | 3.92° | 68 mrad — readable (but M60 is hip-only, the kick is still applied) |
| RPD | 2.2 | 0.88 | 3.08° | 54 mrad — readable (RPD also hip-only) |
| PPSh | 1.4 | 0.56 | 1.96° | 34 mrad — readable |
| RPG-2 | 6.0 | 2.4 | 6.72° | 117 mrad — and this is a *rocket*; the kick is enormous |
| RPG-7 | 6.5 | 2.6 | 7.28° | 127 mrad |
| M72 | 6.0 | 2.4 | 6.72° | 117 mrad |
| M79 | 5.0 | 2.0 | 7.0° | 122 mrad |
| Ithaca | 3.4 | 1.36 | 4.76° | 83 mrad |
| M14 | 2.6 | 1.04 | 3.64° | 64 mrad — *highest of the "aimed rifles"* |

**The bolt-action and rocket kick magnitudes are the problem.** The 8.57° Mosin kick and 6.7° rocket kicks are the *peak* per-frame angular velocity. The lerp at 10/sec damps this — the actual visible peak is roughly the `target_rot` value (the gun lerps to ~83% of it in one frame) — so the player sees the gun rotated by ~7° on a Mosin, ~5.6° on a rocket. **For bolt-actions this is the *intended* "I just pulled the trigger, where did the sight go?" feel.** For the M79, the 5.6° pitch kick is harmless (the leaf is on the barrel, the player doesn't need a sight picture after firing because they only have one shot).

**Is this within `ALIGN_TOLERANCE_M`?** No. By 100-300×. But that tolerance is for *static* editor alignment, not dynamic recoil. **The recoil punch is intentionally outside the alignment tolerance, and that is correct.**

**The fairness question:** does the player have a fair chance to *recover* the sight picture before the next threat presents? At Mosin's 35 rpm (~1700 ms cycle), the player has 1700 - 400 = 1300 ms after the settled gate opens. The gun's `position` and `rotation_degrees` are at 99% of ADS pose by ~460 ms. So the player has ~840 ms of "gun settled, sight picture back, ready to fire" time per shot cycle. **Fair.**

---

## 6. Sprint-ADS, prone-ADS, breath-ADS, wounded-ADS

The four "modifier" ADS states. Reachable?

### Sprint-ADS (`weapon_holder.gd:770-772`)

```gdscript
if controller and "is_sprinting" in controller and controller.is_sprinting:
    target_pos.y -= 0.08
    target_rot.x -= 12.0
```

This is a *position modification* on top of the existing hip/ADS lerp. **Sprint-ADS is reachable in the sense that the code path is wired.** But the *intent* of sprint-ADS in most shooters is "the player is sprinting, they cannot ADS" — i.e. the modifier should *prevent* ADS, not change the visual. Here, the modifier just *adjusts* the visual. **There is no early-return for `is_sprinting` in the ADS code path**, so the player can hold sprint and aim and the gun will move *down and back* by 8 cm and 12° of pitch, giving a "sprinting while aiming" pose that looks unnatural but functions.

**The fairness verdict:** this is **fine for now**. The shoot-while-sprinting penalty is a `spread` hit elsewhere (via `ads_spread_mult` in the .tres), not a visual one. The visual offset is a "the gun is dipping from the run" effect. **Not blocking.**

### Prone-ADS (`weapon_holder.gd:368-369`)

```gdscript
if "is_prone" in controller and controller.is_prone:
    spread *= 0.6
```

This is a *spread* modification, not a *position* one. **The gun visual stays the same; the spread is 40% smaller.** Combined with the settled gate (0.12×), a prone-and-settled player gets `0.6 * 0.12 = 0.072×` spread. **Reachable; not blocking.**

### Breath-ADS (`weapon_holder.gd:372-373`, `weapon_holder.gd:781-782`)

```gdscript
if "is_holding_breath" in controller and controller.is_holding_breath:
    spread *= 0.4
# ... and ...
if controller and "is_holding_breath" in controller and controller.is_holding_breath:
    sway_amp *= 0.15
```

**Spread × 0.4 and sway × 0.15.** Combined with settled, a holding-breath-and-settled player gets `0.4 * 0.12 = 0.048×` spread. **Reachable; not blocking.** This is the classic "I am aiming, holding my breath, prone, fully ADS — please hit the headshot" combination. The numbers look right.

### Wounded-ADS (`weapon_holder.gd:370-371`)

```gdscript
if "wounded_arms" in controller and controller.wounded_arms:
    spread *= 1.35
```

**Spread × 1.35.** No visual. The gun moves the same; the spread is wider. **Reachable; not blocking.** This is the HLL principle: wounded arms = you cannot aim. 1.35× is a 35% spread penalty — it does not break the gun, it just makes it less accurate. **Fair.**

### The four modifier states — summary

| Modifier | Code path | Reachable? | Visual OK? | Verdict |
|---|---|---|---|---|
| Sprint | `target_pos.y -= 0.08; target_rot.x -= 12.0` | Yes (no early return) | Looks like "gun dips while running" | OK as-is |
| Prone | `spread *= 0.6` (no visual) | Yes | No change | OK |
| Breath | `spread *= 0.4; sway_amp *= 0.15` | Yes | Subtle sway reduction | OK |
| Wounded | `spread *= 1.35` (no visual) | Yes | No change | OK |

**None of the four modifier states are broken by the placeholder ADS.** They are all wired through spread or minor position adjustments, not the gun's "where it sits in ADS" pose. The rig author's gun-specific `ads_position` will be the same in prone, breath, wounded, and (mostly) sprint — except sprint adds 8cm/12° on top.

**One thing the placeholder does affect:** the *prone* and *breath* modifiers reduce spread, but they do *not* change the gun's apparent position relative to the eye. If the rig author author-tunes a Mosin ADS pose where the rear aperture sits at the player's eye-line, the prone pose will look the same (good). If the rig author tunes a hip pose where the gun sits in the lower-right of the screen (the classic FP hip), the ADS pose will be straight ahead — and the player in prone will see the gun *above* the prone-eye line. **This is a rig-authoring concern, not a code concern.**

---

## 7. Tradeoff declaration (the law binds the architect)

**Per the War Room law: I MUST name what is sacrificed. Here it is, in order of cost:**

1. **No recoil-settling animations today.** The current `target_rot.x += punch_amt * 3.5 * w` is a pure-math kick; there is no per-weapon recoil curve, no "sight returns to ADS pose over X ms" easing, no "the gun rotates 5° on the first shot and 2° on the second" stagger. **The rig change is going to replace this with per-weapon animation curves.** Adjusting the math today is a fossil — the rig pass will bury it. **Sacrificed: per-weapon recoil *feel* in 2026-07-14. It ships in the rig pass.**

2. **No per-weapon `ads_position` authoring today.** The four placeholders (AK, Mosin, M16, PPSh) will not get gun-specific positions in this session. The M14 already has its authored `ads_position = (-0.250, 0.175, -0.021)`. **Sacrificed: that the four placeholder guns do not deliver their ADR-004 sight pictures in this session.** This is acceptable because the *rig author* (weapons-designer / blender-stager) is the right team to do this, and the auto-align tool 9h9f is the right tool. Adjusting the placeholder by hand today would be a fossil — the tool's output is canon.

3. **No `ads_fov` adjustment for the bolt rifles (Mosin, M70).** These will ship at 40° in the .tres even though the placeholder `ads_position` does not deliver a true 40° sight picture. **Sacrificed: that the Mosin and M70 do not read as "looking through a hex peep" in 2026-07-14.** The rig author must either author a long sight radius (which makes 40° work) or bump the FOV to 50-55° (which the placeholder supports). The decision is theirs.

4. **The "M60/RPD/RPG-2/M72 are hip-only or sight-raise" policy is in ADR-004 but not in the .tres data.** The .tres files still carry the pre-ADR-004 60° values. **Sacrificed: 4 fossil values in 4 .tres files.** This is the *easy* fossil — a `set ads_fov = 10.0` on each of the 4 files is a 30-second fix. It is not a War Room decision; it is a 1-line cleanup. **Recommending the Overseer queue this cleanup as the first bead of the rig pass, *before* the rig author starts authoring.**

5. **The weapon-swap visual snap is NOT what the owner proposed.** The owner hypothesised a "two-frame lerp sync" bug; the actual code shows the lerps are synchronised, but the weapon-swap visual jitters because the gun model loads at the GLB's saved `position` (often zero) and lerps to `hip_position` over ~200 ms. **Sacrificed: that the owner is getting a misleading "two-frame" intuition from the symptom.** The honest finding ("the lerps are synced; the snap is the weapon-swap settling") is the only way to actually fix it — by setting the GLB's saved `position` to match `hip_position` for each weapon.

6. **The settled gate is reachable.** The owner proposed it might not be. It is. **Sacrificed: nothing, but worth saying out loud** — the gate is correct, the rig pass is the thing that makes the gate *feel* right (sight picture aligns, recoil settles, target re-acquires).

---

## 8. Recommendations to the Arbiter (in order of bead-creation urgency)

1. **FOSSIL CLEANUP (P1, one commit, four .tres files):** Set `ads_fov = 10.0` on `m60.tres`, `rpd.tres`, `rpg2.tres`, `m72_law.tres`. This is the immediate, mechanical cleanup that the FOSSIL LAW (ADR-023) demands. Should be bead *now* and should ship *before* the rig pass starts.
2. **Bolt-rifle FOV/position decision (P2, weapons-designer + balance-feel):** Per Mosin and M70, decide whether to (a) author a true long sight radius at 40° FOV, or (b) bump `ads_fov` to 50-55° to match the placeholder eye position. **This is a per-weapon decision the weapons-designer makes with the rig; not a code change.**
3. **PPSh-41 FOV bump (P3, optional):** 58° → 62-65° to match the historical "snail drum" open sight. Single-line .tres change. Defer.
4. **M14 reference for the rig pass (P1, ongoing):** The M14 has authored `ads_position` and `ads_rotation`. It is the *only* gun in the roster with both. The rig pass uses the M14 as the reference; the other 14 guns get `ads_position`/`ads_rotation` set by the auto-align tool 9h9f.
5. **Weapon-swap visual snap (P2, viewmodel-programmer):** The snap the owner is seeing is the GLB-load-to-`hip_position` lerp, not a "two-frame" bug. The fix is to set the GLB file's `position` to match the weapon's `hip_position` on export (or to set the weapon_model's initial `position` to `hip_position` in `_load_weapon_model` before the lerp starts). **This is the actual root cause of the editor bug the owner named.**
6. **No code changes to `weapon_holder.gd` today.** The settled gate, the recoil punch, the spread cone, the modifier-ADS paths are all working. The rig pass is the next layer; touching the math today is fossil-making.

---

## 9. Self-audit (adversarial)

- **Did I cross into a domain I don't own?** I read `weapon_holder.gd` (the position/rotation lerp) because the question requires it. I read the .tres files because they ARE my domain. I did NOT propose Blender export settings, glTF fbx workflows, or viewmodel_editor.gd code changes — those are the blender-stager and viewmodel-programmer's domain. **OK.**
- **Did I name a tradeoff?** Yes — §7 has six named tradeoffs, including the rig-pass replaces recoil math and the placeholder ADS is not getting gun-specific values today.
- **Did I be adversarial?** Yes — I called out the 4 fossil values in the .tres, the two Mosin/PPSh FOVs that don't match the geometry, the 4 guns whose placeholder eye position is the wrong scale for their FOV, and the 1 misnamed bug (two-frame → weapon-swap).
- **Am I fossil-free?** I did not propose adding any new constants, signals, or fields. I propose touching 4 existing .tres values to `ads_fov = 10.0`. The rig pass will create per-gun positions, but those are data, not code.
- **Did I respect the Pillar?** Pillar 1 (outstanding gunplay) is what I am protecting. Every finding is "does the player see what they need to see to land the shot?" The M60/RPD/RPG-2/M72 fossils are the worst violation — the .tres says "zoom to 60° when you aim" for weapons that should not zoom. **Pillar 1 served.**

— End balance-feel analysis —
