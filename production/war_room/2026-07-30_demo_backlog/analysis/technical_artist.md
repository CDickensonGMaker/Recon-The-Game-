# TECHNICAL ARTIST — Item 7, THE FLOATING ROUND

*Written 2026-07-30. Every number below is measured from the GLB bytes on disk, the manifest, the
exporter and the .tres/.tscn. No Blender session, no Godot run. Probes are reproducible: see §7.*

---

## 0. VERDICT IN ONE PARAGRAPH

The floating round is real and it is the Mosin, but **the briefing's mechanism is wrong on three
counts, and the truth is worse.** `mosin_fp.glb` was **not produced by the pipeline at all** — it is a
hand export from 2026-07-29 20:48 that bypassed `tools/export_viewmodel_clips.py` entirely. It carries
seven `mosin_*`-prefixed clips instead of the six contract clips, it is **missing all three contract
markers** (`MuzzlePoint`/`SightFront`/`SightRear`), and **not one of its seven clips carries a single
animation channel for the stripper, the round, the gun root, or the bolt.** Because
`scripts/player/weapon_holder.gd:929` asks for the literal clip `"rifle_idle"` and
`:937` for `"charge_handle"` — neither of which exists in this GLB — **the Mosin viewmodel plays no
animation whatsoever and renders in the armature's REST pose.** The round floats because it is a
sibling of the skeleton that nothing ever moves; the rifle is in T-pose next to it for the same reason.
`tools/validate_viewmodel_glb.py mosin` already fails this GLB on 17 lines. It was simply never run.

---

## 1. THE MEASUREMENT — the briefing corrected

The `~-15.7 m` is the armory ruler station, and it is **not** cancelled by the `.tres`:
`data/weapons/mosin.tres:35` `hip_position = (0.0197, 0, -0.147)` and
`scenes/weapons/mosin_arms_viewmodel.tscn:8` `Transform3D(-1,0,0, 0,1,0, 0,0,-1, 0,-1.81, 0)` — a 180°
yaw and a −1.81 m Y drop, **no Z term at all**. The station is cancelled because the rig's own
`camera` bone sits at the station too: `camera` world = `(0, 1.743, -16.0)`. Every gun has its own
slot on the ruler (m16 z≈+0.46, m14 −3.7, ak −7.8, m79 −10.7, **mosin −16.0**, m70 −23.6, ppsh −27.0,
m60 −35.9, colt45 −55.6). All positions below are therefore quoted **relative to the `camera` bone and
then through the .tscn's 180° yaw**, i.e. real Godot camera-local metres, `[right, up, forward]`.

### 1a. Positions confirmed (clip `mosin_idle`, t=0)

| node | world | Godot cam-local `[R, U, FWD]` |
|---|---|---|
| `camera` (bone) | `(0, 1.743, −16.000)` | `[0, 0, 0]` |
| `Mosin_body` (receiver) | `(−0.157, 1.611, −15.775)` | `[+0.157, −0.132, −0.225]` |
| `Mosin` (declared `gun_root`, an empty) | `(−0.169, 1.543, −15.935)` | `[+0.169, −0.200, −0.065]` |
| `Mosin_boltknob` | `(−0.139, 1.620, −15.775)` | `[+0.139, −0.123, −0.225]` |
| **`Mosin_clip_round_1`** | `(−0.154, 1.714, −15.687)` | **`[+0.154, −0.029, −0.313]`** |
| **`stripper_clip_Mosin`** | `(−0.636, 1.659, −15.633)` | **`[+0.636, −0.085, −0.367]`** |
| `muzzle_Mosin` | `(−0.154, 1.655, −14.875)` | `[+0.154, −0.088, −1.125]` |

The briefing's two numbers check out to the millimetre (`stripper` `(−0.636, 1.659, −15.633)`,
`boltknob` `(−0.139, 1.620, −15.775)`). Its *interpretation* does not.

### 1b. **HIS WORDS ARE EXACTLY RIGHT — and it is TWO objects, not one**

`Mosin_clip_round_1` sits at `[+0.154, −0.029, −0.313]`. `Mosin_body` sits at `[+0.157, −0.132, −0.225]`.
**Lateral difference: 3 mm. Vertical difference: 103 mm. It is a single cartridge hanging 10.3 cm
directly above the receiver, 8.8 cm further out.** That is "a floating round above the rifle", literally,
with no interpretation required. **There is no second floating round elsewhere in the armory** — see §5,
where I sweep all 13 GLBs; the Mosin is the only gun in the set with an orphan mesh cluster.

The **charger body** is a separate floater: `stripper_clip_Mosin` at `[+0.636, −0.085, −0.367]` is
**48 cm to the RIGHT of its own round**, near/past the right screen edge at 62° viewmodel FOV
(`mosin.tres:20`). It is a 67 mm C-channel, so it reads as a small dark chip at the frame edge and is
easy to miss — which is why he reported the round and not the clip.

**Why 48 cm apart when the round is the charger's child?** `Mosin_clip_round_1.parent =
stripper_clip_Mosin`, local translation `(−0.4823, −0.0512, 0.0579)`. The round was linked-duplicated
and re-parented **without clearing the parent inverse** — the classic trap already recorded in
[[recon-soviet-armory-sync]]. Also: **only round 1 of the 5 is in the collection.** Rounds 2–5 do not
exist in the GLB, so the "5 LINKED duplicates" in [[recon-mosin-bolt-and-stripper]] never made it into
`RIG_Mosin`.

### 1c. **THE BRIEFING'S CLIP CLAIM IS FALSE — measured**

The briefing says "of the eight animations… only `mosin_round_load` touches the stripper, with a SINGLE
channel." Measured:

- There are **seven** animations, not eight: `mosin_charge_handle`, `mosin_idle`, `mosin_jam`,
  `mosin_load_round`, `mosin_reload_end`, `mosin_reload_start`, `mosin_rifle_idle`. There is no clip
  named `mosin_round_load`.
- **ZERO of the seven carries ANY channel for `stripper_clip_Mosin`, `Mosin_clip_round_1`, `Mosin`, or
  `Mosin_boltknob`.** Not one channel, in any clip, for any of the four.

The gun still appears in the hands during a clip because its topology is different from every other
gun: `Mosin` → `Mosin_body` → **bone `hand.L`**. It rides the *skeleton*, so the skinned pose carries
it for free. `stripper_clip_Mosin` is a **glTF root sibling of the armature** (`scenes[0].nodes = [68, 71]`
= `ArmsRig_Mosin`, `stripper_clip_Mosin`). It rides nothing. It cannot move, in any clip, ever.

### 1d. **THE HEADLINE: NO CLIP PLAYS AT ALL**

`scripts/player/weapon_holder.gd:980-982` grabs the AnimationPlayer and calls `_play_vm_draw()`:
- `:937` `if not _vm_anim.has_animation("charge_handle")` → the GLB has `mosin_charge_handle`. **No match.**
- falls to `_play_vm_idle()`, `:929` `if _vm_anim.has_animation("rifle_idle")` → the GLB has
  `mosin_rifle_idle`. **No match.** Nothing is played.

`assets/player/viewmodels/mosin_fp.glb.import` does no renaming (`animation/import=true`, no
`_subresources` overrides), and `animation/import_rest_as_RESET=false`, so there is no RESET clip and
the Skeleton3D initialises to REST.

**Rest pose, measured (Godot cam-local):** `hand.L [−0.660, −0.437, +0.051]`, `hand.R [+0.660, −0.437,
+0.051]` — **a symmetric T-pose**. `Mosin_body` goes to `[−0.521, −0.504, +0.240]` (down-left and
*behind* the eye), while `Mosin_clip_round_1` **stays exactly where §1a put it** (no channel, so rest ==
clip pose). So in game today the Mosin shows: arms straight out sideways, rifle behind/left, **and one
cartridge alone in the middle of the frame at eye level, 31 cm out.**

The Mosin is reachable in the demo three ways: the corpse-pickup swap (`scripts/player/player.gd:752`,
and `data/enemies/vc_rifleman.tres:14` + `nva_marksman.tres:14` both carry `mosin.tres`), the gun range
(`scripts/levels/gun_range.gd:9`) and the armorer's bench (`scripts/levels/armorers_bench.gd:22`). It is
**not** the default weapon — `weapon_holder.gd:180` loads `m16a1.tres` — and the M16 viewmodel is clean
(§5). So he saw this either at the bench/range or after taking a dead VC's rifle.

---

## 2. WHY IT EXPORTS WHEN IT IS NOT A DECLARED PART — the actual defect

Two defects, nested. The outer one is the one that matters.

### 2a. The manifest `parts` list is not a whitelist. Collection membership is.

`tools/export_viewmodel_clips.py:44` `objs = list(coll.objects)` → `:317-320` selects **every** object
in `RIG_<gun>` → `:326` `use_selection=True`. **The exporter never reads
`tools/viewmodel_manifest.json` at all.** `tools/export_all_viewmodels.py:33-38` passes only
`collection`, `gun_prefix`, `out`, `--strict`, `--root`, `--len` — `parts` is not among them.

`parts` is read in exactly one place repo-wide: `tools/validate_viewmodel_glb.py:100`
```
part_idx = {p: byname[p] for p in spec["parts"] if p in byname}
```
It is a **post-hoc channel assertion**, not a membership gate. And note the `if p in byname`: a declared
part that fails to export is **silently dropped from the check**. The hole is two-sided —
*undeclared objects ship, and declared objects may vanish, and neither is caught.*

So: **anything dropped into the `RIG_Mosin` collection ships to the player, animated or not.** The
stripper was built into that collection on 2026-07-28 and it has shipped ever since. The line in
[[recon-mosin-bolt-and-stripper]] — *"Stripper parts are not yet in the manifest `parts` list, so they
do not export"* — is DRIFT: the premise is right, the conclusion is backwards, and the memory should be
corrected (POINTER LAW).

The exporter's own bake filter is also not a gate: `:101-102`
```
parts = [o for o in objs if o.type != 'ARMATURE'
         and (o.constraints or (o.animation_data and o.animation_data.nla_tracks))]
```
The stripper has **neither** a constraint nor an NLA track, so it is not baked (→ zero channels, §1c) —
**but it is still selected and still exported.** "Not bakeable" and "not exported" are two different
sets, and the pipeline treats them as one.

The `--strict` WRECKAGE CATCHER (`:198-201`, `d > 2.5 m` from `hand.R`) cannot see this either: it only
inspects `parts` (the bake list, which excludes the stripper), and 2.5 m is 5× too loose for a 0.5 m
floater anyway.

### 2b. This GLB never went through the pipeline

Independent proof, from the bytes:
- `export_viewmodel_clips.py:268-275` renames `muzzle_<GUN>`/`sight_front_<GUN>`/`sight_rear_<GUN>` to
  `MuzzlePoint`/`SightFront`/`SightRear`. **`mosin_fp.glb` still contains `muzzle_Mosin`,
  `sight_front_Mosin`, `sight_rear_Mosin` and contains no node named `MuzzlePoint`.** That rename is
  unconditional. The script did not run.
- Clip names are `mosin_*`. `retarget_ref_anim.py:400-423` authors bare `rifle_idle`/`reload`/
  `reload_empty`/`charge_handle`/`fire`/`jam`. Neither tool produces `mosin_reload_start`.
- mtimes: `fp_arms_rifle.blend` 2026-07-29 20:47, `mosin_fp.glb` 2026-07-29 20:48. Every other current
  GLB is 2026-07-28 16:54–20:22 (a single `export_all_viewmodels.py` run).

`python tools/validate_viewmodel_glb.py --no-timers` **run today** returns for mosin:
```
[FAIL] mosin (mosin_fp.glb)
   - clip set mismatch: missing=[charge_handle, fire, jam, reload, reload_empty, rifle_idle]
                        extra=[mosin_charge_handle, mosin_idle, mosin_jam, mosin_load_round,
                               mosin_reload_end, mosin_reload_start, mosin_rifle_idle]
   - marker SightRear missing / SightFront missing / MuzzlePoint missing
   - clip <each of 7> has no channel for part Mosin
   - clip <each of 7> has no channel for part Mosin_boltknob
```
**The machine was already correct. It was not run.** `tests/test_viewmodel_contract.gd:44-49` would
also have gone red on both the clips and `MuzzlePoint`.

Side effect worth naming: with `MuzzlePoint` gone, `weapon_holder.gd:1039` falls back for the hip-fire
spawn point, and `viewmodel_editor.gd:273/466/611` and the `V` sight-align at `:580-590` all lose their
markers for this gun.

---

## 3. THE CORRECT FIX — in Blender, precisely

**Contract sections that bind this:** `viewmodel_manifest.json:2` (`_doc` — *names are API; renaming an
object, marker or NLA track is a breaking change*), `:3` (`_contacts_doc` — *`contacts` maps a
contact-marker empty to the part it is parented to; a hand that manipulates a part is posed TO its
marker, never eyeballed in free space*), `:6` (`_staged_doc` — *when a gun joins `guns`, move its
contacts map in **and declare its parts***), `export_viewmodel_clips.py:100-102` (bake filter),
`validate_viewmodel_glb.py:96-106` (every clip, every part, a channel).

### 3a. Blender, in `assets/player/arms/fp_arms_rifle.blend`, collection `RIG_Mosin`

1. **Seat the round in its own charger.** `Mosin_clip_round_1`'s local translation to
   `stripper_clip_Mosin` is `(−0.4823, −0.0512, 0.0579)`. Clear the stale parent inverse
   (`Object > Parent > Clear Parent Inverse` then re-place, or re-parent with *Keep Transform* off) so
   the round's local offset is its true seat in the C-channel (≈`(0, 0, ±0.0145 × n)` along the rim
   spacing). **Key the pose before running anything** — an unkeyed hand-made pose is wiped by the next
   depsgraph evaluation ([[unkeyed-pose-is-volatile]]).
2. **Build rounds 2–5.** Only `Mosin_clip_round_1` is in the collection. `mosin.tres:12`
   `magazine_size = 5`; a 5-round charger with one round in it is a modelling bug on its own.
3. **Parent the charger to the hand, not to nothing.** `stripper_clip_Mosin` must get a **`CHILD_OF`
   constraint targeting `ArmsRig_Mosin` / subtarget `hand.L`, with keyed influence** — the identical
   machinery every other gun's feed device uses, and the machinery `retarget_ref_anim.py:248-253`
   already assumes (`'mag': 'contact_clip_Mosin'` → `resolve()` at `:274-277` takes
   `contact_clip_Mosin.parent` as `mag_obj`). Adding the constraint is what makes
   `export_viewmodel_clips.py:101-102` classify it as a bakeable part, which is what gives it **real TRS
   keys in all six clips** and therefore the ability to be put back — the exact reset property
   `validate_viewmodel_glb.py:96-99` exists to enforce.
4. **Give it an off-frame home.** glTF carries **no visibility channel**, so `hide_render` cannot travel
   and there is no "hide it in idle" in this pipeline. The charger must be *parked out of frustum* in
   `rifle_idle`/`fire`/`jam`/`charge_handle` — under the left forearm, behind the camera plane
   (cam-local `FWD > 0`), which is where the arms rig stows things. It only enters frame during
   `reload`/`reload_empty`. *(A uniform scale-to-0.001 in the non-reload clips is the only other
   contract-legal option — `validate_viewmodel_glb.py:86-91` rejects only NON-uniform scale — but the
   bake writes `matrix_world` back through a T/R/S decomposition at `export_viewmodel_clips.py:227-232`,
   and a near-zero scale makes the rotation extraction ill-conditioned. **Park it, don't shrink it.**)*
5. **Add the reload beats.** The charger's on-screen performance already has a measured spec:
   `production/research/mosin_reference/NOTES.md` — Enlisted phase table, whole reload ≈3.2 s, and
   `mosin.tres:13 reload_time = 5.0` is the authority the clip gets stretched to
   (`weapon_holder.gd:917-922`). Pose the left hand **to `contact_clip_Mosin`**, never in free space
   (`_contacts_doc`). Also close the open defect from [[recon-mosin-bolt-and-stripper]]: `reload` has
   bolt travel `0.0`, inherited from a detachable-mag reference — **you cannot feed a charger into a
   closed action**, so `reload` must open the bolt like `reload_empty` does.

### 3b. Manifest — what must be declared (`tools/viewmodel_manifest.json`, `guns.mosin`)

```
"parts":    ["Mosin", "Mosin_boltknob", "stripper_clip_Mosin",
             "Mosin_clip_round_1", ... _2.._5 once they exist],
"contacts": {"contact_bolt_Mosin": "Mosin_boltknob",
             "contact_clip_Mosin": "stripper_clip_Mosin"}
```
`contact_clip_Mosin` exists in the .blend and is consumed by `retarget_ref_anim.py:251` but appears
**nowhere** in the manifest — `_staged_doc` at `:6` explicitly requires it to be moved in when the gun
joins `guns`. That omission is the same drift as the missing `parts` entry.

Also correct while touching the file: `real_length_m: 1.232` vs a measured 1.294 m across parts (5%
long, inside the `--len` gate's 15% band but wrong).

### 3c. Re-export through the pipeline, not by hand

```
python tools/export_all_viewmodels.py mosin
```
This is the whole fix for the clip names, the markers and the channels — `--strict` pre-flight, then
`validate_viewmodel_glb.py`, then `sync_weapon_timers.py`, and it stops on first failure
(`export_all_viewmodels.py:41-58`). **Revert the open GUI first** (`File > Revert`) — the headless run
reads the disk file and an open window will overwrite it on save
([[recon-mosin-bolt-and-stripper]]).

### 3d. Close the hole so the next stowaway cannot ship (this is the real deliverable)

The floating round is a symptom; **"the collection is the whitelist" is the defect.** Cheapest correct
patch, three edits:

1. `export_all_viewmodels.py:33-38` — pass the declared parts through:
   `--parts=<comma-joined spec["parts"]>`.
2. `export_viewmodel_clips.py`, inside the `if STRICT:` block — refuse to export any non-armature MESH
   object in the collection that is neither in `--parts` nor a descendant of `--root` nor a descendant
   of the rig. That is a ~6-line loop and it fails **before** a GLB is written, which is the stated
   design of the pre-flight (`:106-110`).
3. `validate_viewmodel_glb.py:100` — make a **declared part missing from the GLB an error** instead of
   silently dropping it (`if p in byname` → else-append), and add the orphan check from §7 so a
   root-sibling mesh is a FAIL. Then extend `--selftest` (`:115-154`) with the 2026-07-30 signature: a
   mesh node whose top ancestor is neither the rig nor the gun root **must FAIL**. A regression the
   selftest does not encode is a regression that comes back.

Cost: nothing at runtime. Sacrifice: every future gun must keep its `parts` list honest or the export
refuses — one more gate to satisfy when adding a weapon, which is the point.

---

## 4. THE STOPGAP FOR TODAY — and its deletion condition

He is playtesting now. **Do not put a Mosin-specific branch in `weapon_holder.gd`** — that is the
fossil shape ADR-023 was written for, and `weapon_holder` is 1000+ lines of shared player code.

### 4a. The hide

**Node path:** the GLB has two glTF roots (`scenes[0].nodes = [68, 71]` = `ArmsRig_Mosin`,
`stripper_clip_Mosin`), so Godot's import root carries both as children. Instanced under
`scenes/weapons/mosin_arms_viewmodel.tscn:7` as `Model`, the runtime path from the viewmodel scene root
is:

```
MosinArmsViewmodel/Model/stripper_clip_Mosin
```

Hiding the charger hides the round with it — `Mosin_clip_round_1` is its only mesh child, and
`Node3D.visible` propagates.

**Where:** in the **scene file**, not in code. Append to `scenes/weapons/mosin_arms_viewmodel.tscn`:

```
[node name="stripper_clip_Mosin" parent="Model"]
visible = false
```

Two properties recommend this over a `find_child(...).hide()` in `_load_weapon_model`: it is
declarative and touches no shared script, and it is **self-announcing** — the moment §3a lands and the
charger becomes a child of `Mosin_body`/`hand.L` instead of a glTF root, the path `Model/
stripper_clip_Mosin` stops resolving and Godot logs the missing node on scene load. A silent
`find_child` guarded by a null check would *not* announce anything; it would sit there forever, and the
day the charger is correctly animated it would still hide it and the reload would play with an
invisible charger and no one would know why.

### 4b. DELETION CONDITION (ADR-023) — state it in these exact terms

> **The two lines in `mosin_arms_viewmodel.tscn` must be deleted the moment
> `python tools/validate_viewmodel_glb.py mosin` exits 0.**

That single command is the whole condition, and it is observable in one line. Exit 0 means, by
construction, all of: the six contract clips are present (so `weapon_holder.gd:929/937` find their
clips and the rig stops rendering in T-pose), `MuzzlePoint`/`SightFront`/`SightRear` exist, and **every
declared part has a channel in every clip** — which after §3b includes `stripper_clip_Mosin` and
`Mosin_clip_round_1`. A charger with a channel in every clip is a charger the animation owns, and a
hidden charger the animation owns is a broken reload.

**Make the condition load-bearing today, not a note:** add `stripper_clip_Mosin` and
`Mosin_clip_round_1` to `guns.mosin.parts` **in the same change as the stopgap**. `validate_viewmodel_glb.py`
and `tests/test_viewmodel_contract.gd` then go red immediately and stay red until the Blender work
lands. **The stopgap ships with the alarm that kills it already ringing.** That is the difference
between a stopgap and a fossil, and it costs one line of JSON.

---

## 5. ARE THE OTHER 12 CLEAN? — the same probe on all of them

Two probes, both in §7. **Probe A (orphan topology):** for every non-skinned mesh node, walk to its
top ancestor. On a healthy gun that ancestor is the manifest `gun_root` and that root is animated.
**Probe B (position):** sample each GLB's idle clip at t=0 and place every non-skinned mesh node in
Godot camera-local metres.

| GLB | mtime | orphan cluster | verdict |
|---|---|---|---|
| `m16_fp.glb` | 07-28 | 4 mesh nodes, all under `M16A1_gun`, all animated | **CLEAN.** Tightest cluster in the set (`[0.08…0.11, −0.13…−0.25, −0.26…−0.46]`) |
| `ak_fp.glb` | 07-28 | 3, all under `AK47_root` | **CLEAN** (`AK47_gun` static, rides the animated root) |
| `ppsh_fp.glb` | 07-28 | 27, all under `PPSh41` | **CLEAN** — 27 draw-call-costly pieces, no floater |
| `m14_fp.glb` | 07-28 | 5, all under `M14_root` | **CLEAN** |
| `m70_fp.glb` | 07-28 | 2, all under `M70sniper_root` | **CLEAN** |
| `colt45_fp.glb` | 07-28 | 17, all under `Colt45_Pistol_root` | **CLEAN** |
| `m79_fp.glb` | 07-28 | 3, all under `M79_Launcher_root` | **CLEAN** as geometry — but `m79.tres:40 model_path = ""`, so it never loads |
| **`mosin_fp.glb`** | **07-29** | **`Mosin_clip_round_1` → top ancestor `stripper_clip_Mosin`, a glTF ROOT SIBLING of the armature, with zero animation channels** | **DIRTY — the only orphan cluster in the armory. This is the floating round.** |
| **`m60_fp.glb`** | 07-28 | 80, all under `M60_MG_root` | **DIRTY, separately.** Validator: all three markers **severed at ruler-station coords** (`SightRear` local `(2.250, 1.536, 35.311)`) — the 2026-07-25 break shape; and `M60_chandle_charge_handle` is **ANIMATED with non-uniform scale `(0.231, 0.447, 1.0)`** → glTF shear → a tumbling charging handle. `m60.tres:36` loads it. |
| **`rpd_fp.glb`** | **07-11** | 1 (`RPD_MG`, static, no split parts) | **DIRTY/STALE.** `gun_root RPD` missing, only `rifle_idle` exists (5 clips missing), no `SightFront`/`SightRear`. Predates the 07-27 transplant. `rpd.tres:32` loads it. |
| **`ithaca_fp.glb`** | **07-11** | 1 (`Ithaca37_Shotgun`) | **DIRTY/STALE**, same shape. `shotgun.tres:38` loads it. |
| **`rpg2_fp.glb`** | **07-11** | 1 (`RPG2_Launcher`) | **DIRTY/STALE**, same shape. `rpg2.tres:34` loads it. |
| `m72_law_fp.glb`, `rpg7_fp.glb` | — | **DO NOT EXIST** | Declared in the manifest, never exported. Harmless in game: `m72_law.tres:38` and `rpg7.tres:37` both have `model_path = ""`. |
| `flashlight_fp.glb` | 07-11 | 2 roots: `MX991_Flashlight` **and a stray whole `Colt45_Pistol`** at cam-local `[−0.075, −0.186, −0.369]` — dead centre of frame | **DIRTY but DEAD.** `flashlight_fp` and any flashlight viewmodel scene have **zero references repo-wide**. Same defect class as the Mosin (a stowaway root mesh from the source collection), and the same §3d gate catches both. |

**So: 8 of the 13 shipped GLBs are clean; 3 stale 07-11 exports (rpd, ithaca, rpg2) and the m60 are
separately dirty and three of those four ARE loaded by a live `.tres`; the Mosin is the only floating
round.** Re-running `python tools/export_all_viewmodels.py rpd ithaca rpg2` is a mechanical fix — the
manifest already declares their split parts and contacts (`:151-171`, `:271-293`, `:343-365`).

**No probe finds a second floating round.** The only cartridge-shaped meshes elsewhere are
`M60_bullet_01..08` / `M60_MGbullet.023`, and they are the belt, all under `M60_MG_root`, all riding
the gun.

---

## 6. WHAT IT COSTS AND WHAT IT SACRIFICES

- **Perf:** nothing either way. The project is call-bound (`production/PERF_LEDGER.md`); hiding one node
  removes one draw call, and re-parenting it removes none. The stripper's 5 rounds will *add* up to 5
  draw calls to a viewmodel that on the PPSh already carries 27 and on the M60 carries 80 — the M60,
  not the Mosin, is the viewmodel draw-call problem, and it is out of scope here.
- **Sacrificed by the stopgap:** the Mosin's reload has no visible charger for as long as it is in
  place. Given the reload does not animate at all today (§1d), that costs zero fidelity now.
- **Sacrificed by the §3d gate:** one more thing to get right when adding a weapon, and existing dirty
  guns (m60, rpd, ithaca, rpg2) will refuse to re-export until their manifests are honest. That is a
  feature: it converts four silent lies into four loud failures.
- **Pillar:** Atmosphere. A cartridge hovering in front of the player's face is the single most
  immersion-breaking artefact a viewmodel can produce, and it is worse than a missing feature because
  it reads as a bug in the *game*, not a gap in it.
- **The Mosin is not shippable in the demo either way** until §3a/§3c land: a T-posed pair of arms is
  a bigger defect than the round. If the demo cannot afford the Blender work, the honest interim is to
  **keep VC rifles un-pickupable** rather than hide one node and ship the T-pose.

---

## 7. THE PROBES (reproduce everything above)

Pure python, no Blender, no Godot. Written to scratch, not to the repo:

- **Manifest validator, already in the repo:** `python tools/validate_viewmodel_glb.py --no-timers`
  (§2b output). This is the authority and it already fails mosin, m60, rpd, ithaca, rpg2.
- **Probe A — orphan topology.** Parse the GLB JSON chunk, build the parent map, and for every node with
  `"mesh"` and without `"skin"`, walk to the top ancestor. FAIL if that ancestor is neither the manifest
  `gun_root` nor a descendant of `ArmsRig*`. **This is the probe the pipeline is missing and the one
  §3d.3 should absorb** — it is ~15 lines and it is the only check that catches the Mosin.
- **Probe B — camera-local position.** Parse the JSON **and** the BIN chunk, apply the idle clip's
  first keyframe per channel, compose world matrices, then subtract the `camera` bone and negate X and
  Z for the .tscn yaw. Produces every table in §1.

**POINTER LAW note — two live claims corrected by this analysis:**
`[[recon-mosin-bolt-and-stripper]]` says *"Stripper parts are not yet in the manifest `parts` list, so
they do not export"* — they **do** export; the manifest does not gate the export. And the briefing's
`:58-66` mechanism ("only `mosin_round_load` touches the stripper, with a SINGLE channel") is wrong:
no clip of that name exists and no clip carries any stripper channel. **Where this brief and the code
disagree, the code wins** — and it does, here, on both counts.
