# Medical tent — animation pass, reconnaissance and design

Date 2026-08-03. Everything below is measured in Caleb's live Blender 5.0 session or headless
against `assets/shared/anim_library.blend`. Numbers, not impressions.

---

## 0. THE FILE-IDENTITY FINDING — read this first

The brief said the live session holds `firebase_v3.1_RECOVERED_medical.blend`. **It does not.**
Measured `bpy.data.filepath`:

```
C:\Users\caleb\RECONgame\assets\world\building models\structures\firebase\kit\firebase_v3.1.blend
```

The two files have **converged** — `firebase_v3.1.blend` was re-saved at 22:45 with the current
payload and holds all 27 collections including `bld_medical_complex` (41 objects) and the
stripped `WORKBENCH_chowhall` (136 = 39 meshes + 97 markers, matching the chow hall handoff).
Both files are 18.7 MB.

**This recreates the exact two-truth-source condition that lost the medical complex on 7/31.**
`[[firebase-truth-source]]` names RECOVERED as the only truth; that memory is now stale.
`tools/gen_firebase_v3.py:912` points at `firebase_v3.1.blend`, which as of tonight is correct
by accident rather than by decision. **This needs Caleb's ruling: one file, and delete or
archive the other.**

`firebase_v3.1.blend1` was the 7/31 stripped 6 MB corpse. My saves have rolled it with good
payload — an improvement, but note it is no longer a rollback target for anything.

### Chow marker rename — DONE, in `firebase_v3.1.blend`

Ran `tools/rename_chow_markers.py` in the live session. **Exactly 11 renames, zero leftovers**,
as predicted: `work_server_line` ×1, `work_server` ×4, `work_serve` ×4, `food_stop` ×1,
`chow_exit` ×1. Saved.

`firebase_v3.1_RECOVERED_medical.blend` still carries the OLD names and is now stale on names
*and* on the medical markers built below.

---

## 1. What actually exists

### `WORKBENCH_medical_tent` — was ONE empty

Contained exactly `WB_medical_origin`, an EMPTY at (189.03, −2.25, 0.00). No tent, no cots,
no rigs. It is not a workbench; it is a pin.

### `bld_medical_complex` — 41 objects: 1 mesh + 40 markers

`medical_complex` is **one joined mesh**: 29,448 verts, 20,511 polys, 22 material slots
(`fb_blanket`, `fb_blood`, `fb_blood_splatter`, `fb_o2green`, `fb_curtain`, `fb_redcross`,
`fb_alum`, `fb_enamel`, `fb_chrome`…). Placed at (65.335, −6.947, 4.251), **yaw 185.97°**.
World bbox (45.11, −17.92, 3.60) … (84.52, 13.59, 8.35).

**Consequence, and it drives the whole design:** the cots, the operating table, the IV stands
and the linen stacks are *not separate objects*. There is nothing to parent a man to, nothing
to place a prop against, and no origin to read. Everything must be recovered from the geometry.

### The 40 existing markers are ORPHANED IN A DIFFERENT SPACE

`prop_wounded_00..15`, `work_surgeon_N/S`, `work_triage`, `work_ward_round_0..3`,
`work_scrubnurse_N/S`, `work_anesthetist_2/5`, `work_sterilizer_7`, `work_supply_N/S`,
`work_scrub`, `work_litter_rack`, `work_medofficer_0..2`, `med_door_main`, `med_bearer_formup`,
`hq_door`, `hq_door_approach` all sit at **x ≈ 176…203, z = 0**, while the mesh they belong to
sits at **x ≈ 45…85, z 3.6…8.35**. They are ~120 m away and unrotated.

I derived the map from `prop_wounded_*` to the placed cots and it fits to **0.00 m**:

```
local_x = 200.43 − marker_x        local_y = marker_y + 2.117
```

The `x` term is a **reflection**, not a rotation — determinant −1. Combined with the mesh's own
185.97° placement, the marker set relates to the built geometry by a *mirror*. I can reproduce
the cot lattice from them exactly, but I cannot tell you *why* it is mirrored, and a mirrored
marker set is precisely the thing that silently puts every man on the wrong side.

**Ruling taken: do not reuse them.** The new markers are derived from the mesh directly, which
is unambiguous and needs no archaeology. `prop_wounded_*` and the other 39 are now fossils —
they should be deleted under the FOSSIL LAW, but that is Caleb's call, not mine.

### Medical props that DO exist as files

| file | note |
|---|---|
| `assets/us/props/interior/fb_litter.glb` (122 KB) | **the litter prop EXISTS.** `[[recon-litter-team-architecture]]` says `LitterTeam.available()` gates on `firebase/kit/fb_litter.glb` — a *different path*. Godot-side; flagged only. |
| `assets/us/props/interior/fb_medical_chest.glb` (58 KB) | aid chest |
| `assets/world/props/medical_crate.glb` (6 KB) | crate |
| `assets/us/characters/camp_clips/stretcher_carry.glb` / `stretcher_load_casualty.glb` | the 4-rig authoring references |

No IV stand, no aid bag, no separate cot as standalone files — the IV/O2 geometry is baked
into `medical_complex`.

---

## 2. THE COTS — measured, markered, gated

### Finding the cots

Connectivity clustering **failed** (772 islands across timber/canvas/blanket; zero cot-shaped —
each cot is several disconnected islands). Material-island analysis of `fb_blanket` gave 43
islands and recovered the lattice: mattresses **0.79 × 1.52**, top at local z 0.575, on a
**2.294 m** pitch, two rows at local y **−5.136** and **+4.881** (10.0 m apart).

Confirmed by **object-space raycast** (`obj.ray_cast`, per the law). First attempt cast from
local z = 3.0 and hit `fb_canvas` at z ≈ 2.70–2.85 on every slot — **that is the tent canopy**,
and it would have reported 16 canvas "cots". Re-cast from z = 2.0, under the canvas:

```
S0 0.58 blood_splatter | S1 0.57 blanket | S2 0.52 timber | S3 0.58 blood_splatter
S4 0.58 blanket        | S5 0.58 blanket | S6 0.58 blanket| S7 0.58 blood_splatter | S8 0.00 EARTH
N0 0.52 timber         | N1 0.58 splatter| N2 0.52 timber | N3 0.52 timber
N4 0.58 splatter       | N5 0.58 blanket | N6 0.52 timber | N7 0.58 splatter       | N8 0.00 EARTH
```

**COT COUNT = 16. Exactly 8 per row, 2 rows.** Slot 8 in both rows lands on `fb_earth` — no cot.
Slots reading `fb_timber` are bare frames (no blanket); they are still cots. This matches the
16 orphaned `prop_wounded_*` exactly, which is independent confirmation of the lattice.

### The lying clip — `laying_idle`

**`laying_idle` is the clip, and it already exists.** `anim_library.blend`, 376 frames,
41 bones, 340 fcurves. Measured on the PSXRig:

| | value |
|---|---|
| hips | (0.000, −0.007, **0.116**) |
| head | y **+0.563**, z 0.126 |
| feet | y −0.918 / −0.966 |
| **body Y-extent head..feet** | **1.530 m** |
| lowest body point | forearm z **0.020** → contact plane ≈ 0.0 |
| hip travel over all 376 frames | **0.001 m x / 0.004 m y** — static |
| **elbow gate** | **0 faults / 63 sampled frames** |

Mattress is **1.500 m**; body is **1.530 m** → **15 mm overhang at each end** when centred.
The cot was built for this clip.

Other candidates, rejected with reasons:
- `laying_breathless` — only 21 frames, hips z 0.066, head z rises to 0.272 (head thrown back).
  Reads as *dying*, not resting. **Keep as a variant for one or two bad cases.**
- `sleeping_laying` — 52 frames, hips at z **1.148**. Authored on an elevated surface; needs a
  −0.57 offset to sit on a cot. Usable as a second variant after that offset, not as the default.
- `prone_idle` / `wounded_crawl` — face-down / travelling (2.898 m Y-extent). Wrong beat.

### The marker contract

The marker is the **armature object root**, not the hips. In `medical_complex` local space:

```
position = (cot_x, cot_y + 0.2005, 0.575)      yaw = 0   (body +Y = head end)
```

`0.2005` re-centres the man: the clip's root is at his hips, and his head..feet midpoint sits
0.2005 m behind it. `0.575` is the mattress top. World transform = `medical_complex.matrix_world`,
giving **world yaw 185.96°** on all 16.

**Head end = +local Y.** Two independent signals agree: the cot frame timber extends past the
mattress at +Y on **both** rows and stops flush at −Y (profiled at 0.1 m steps on cots S4 and
N5); and the clip's own body direction is +Y. Both rows are laid the *same* way — they are not
mirrored about the aisle. It is **one constant** in the builder (`HEAD_PLUS_Y`); flipping it
turns all 16 cots round together. **This is the one thing I would like Caleb's eye on.**

### Built and gated

`tools/mark_medtent.py` — `mark()` / `mark(save=True)`. It **raycasts the lattice at run time**
rather than hardcoding it, so a rebuilt complex regenerates correct markers. Idempotent
(replaces by name, never leaves a `.001` twin). Everything parents to `work_med_root`, which
copies `medical_complex.matrix_world` — the weld-to-one-root requirement.

Run in the live session:

```
cots found: 16
markers: 16
  GATE: PASS (0 failures over 16 markers)
```

The gate (`check()`, `tools/mark_medtent.py:141`) asserts per marker: root z exactly on the
mattress; **head end AND feet end both raycast onto a cot surface, not into the air**; and no
two markers under 0.42 m. Min pair spacing measured **2.294 m**.

Saved into `firebase_v3.1.blend`. `WORKBENCH_medical_tent` now holds 18 objects
(1 pin + 1 root + 16 cot markers).

---

## 3. THE TENDING SIDE — Caleb's `civ_work` ruling, and it MEASURES OUT

Caleb: *"really we can just use the work animation for most of the patient work."*

**The clip is `civ_work`** — `tools/make_work_from_pose.py:40`, built from his own pose, with his
own note at `:36`: *"that animation works and can be used for any civilian working job."*
40 frames, arms dipping 0.18 m out of phase, no IK.

**It is NOT in `anim_library.blend`.** It lives in
`assets/civilians/characters/civ_anim_workbench.blend` (102 actions), on a **PSXRig with 41
bones — the same rig**. So it merges straight in, the same way the 19 `chow_*` clips did.
That is an unambiguous, in-scope job: `merge_chow_clips_to_library.py` is the template.

### Does a standing work clip reach a cot? Measured: YES, within 4 cm

| | `civ_work` |
|---|---|
| hips z | 0.850 (standing) |
| right hand z | **0.756** … 0.965 |
| left hand z | 0.825 … 1.043 |
| hands x | −0.505 … −0.731 (work happens to the **−X side** of the root) |
| **elbow gate** | **0 faults / 40 frames** |

Cot mattress is at 0.575; a supine man's chest surface is ≈ 0.575 + 0.22 ≈ **0.79**.
The right hand bottoms at **0.756** (3 cm into the patient) and the left at **0.825** (3.5 cm
above him). **His ruling is vindicated by measurement** — the dip lands on the patient's torso.
No new clip is needed for bandaging, checking a wound, or working a drip.

**The yaw contract that falls out of this:** the work happens 0.5–0.73 m to the root's **−X**,
so a `work_med_tend` marker must be placed and yawed so that **−X points at the cot**. Get that
sign wrong and every medic works on thin air behind him. This is the medical-tent equivalent of
the chow hall's `work_eat` seat yaw.

Rejected for cot-side tending, with measurements:
- `medic_treat_give` — hips z 0.40–0.47, hands z 0.169–0.324. **Kneeling, hands at ground level.**
  Correct for a casualty on the *floor*, 25 cm too low for a cot.
- `civ_squat_idle` — hands z 0.47, not a working pose, and it trips the elbow heuristic on every
  frame (128/128 — elbows on knees, high, hands low). Normal anatomy for a squat, but not a clip
  to put beside a cot.

---

## 4. REFERENCE FOOTAGE

`youtube.com/watch?v=fG9ocDMcs8k` — "Combat Medics in Vietnam", 341 s. Contact sheet at 1 frame
per 12 s. This is **point-of-wounding** footage, not ward footage; searches for archival
evacuation-hospital ward film returned interviews, not scenes. Beats I could actually read:

1. **Tenders are always LOW and always clustered.** Three men crouched round one casualty
   (≈ 2:24) — two working, one steadying. Never one man alone, never a man standing bolt upright
   over a casualty on the ground. At a *cot* (0.575 m) a standing bent-over pose is right; on the
   *ground* it is not, which is what the `civ_work` vs `medic_treat_give` split above encodes.
2. **Casualties lie supine with limbs loose and often flung out**, not folded neatly (≈ 3:36).
   `laying_idle` keeps the hands on the belly (y +0.25, z 0.24–0.27) — tidier than the footage.
   Acceptable under a blanket; worth one loose-armed variant if he wants it.
3. **Litter loading is two men bent at each end, heads down**, at a vehicle/aircraft sill
   (≈ 2:48). This is what `litter_load_front/rear` already do.

**Honest limitation:** I did not find ward-interior footage. The staging below is therefore
derived from the *built geometry* (where the cots, aisle, triage point and door already are) and
from the field footage, not from film of a ward. If Caleb knows a specific film, it would sharpen
the triage/ward-round rhythm.

---

## 5. THE TRIMMED CLIP LIST

His two rulings collapse this from a motion-authoring project into a **staging** job.
**Nothing in the "author" column is approved — each is a question, not a plan.**

### Already exists — use as-is, zero authoring

| beat | clip | frames | source |
|---|---|---|---|
| wounded man on a cot | **`laying_idle`** | 376 | anim_library |
| wounded man, bad case | `laying_breathless` | 21 | anim_library |
| wounded man, asleep | `sleeping_laying` | 52 | anim_library, needs −0.57 z offset |
| medic tending a cot | **`civ_work`** | 40 | civ_anim_workbench — **needs merging into anim_library** |
| medic treating a man on the ground | `medic_treat_give` | 260 | anim_library |
| that man receiving it | `medic_treat_receive` | 260 | anim_library, phase-locked pair |
| litter carry, two men | `litter_carry_front` / `_rear` | 72 / 72 | anim_library, matched, in place |
| litter load, two men | `litter_load_front` / `_rear` | 32 / 32 | anim_library, matched, in place |
| casualty carried over a shoulder | `carry_wounded` + `being_carried` | 301 / 158 | anim_library, pair |
| walking wounded | `injured_walk_backwards` | 41 | anim_library |
| casualty dragging himself | `wounded_crawl` | 71 | anim_library |
| idle between tasks | `idle_unarmed` … `_5`, `kneeling_idle` | — | stagger the phase per man |

All elbow-gated: 0 faults except `being_carried` 3/79 and `wounded_crawl` 1/71, both in poses
where a raised elbow is genuine anatomy. Worth an eye, not a fix.

### Possibly worth authoring — each must clear a high bar

| beat | why `civ_work` cannot carry it | verdict |
|---|---|---|
| lifting a man **off** a cot onto a litter | a lift is a whole-body weight transfer between two men and a third body; the work dip is a hand motion | **the only strong candidate.** Needs Caleb's pose at 2 beats (grip, and lifted) |
| a man sitting up on a cot, bandaged | `sitting`/`sitting_idle_b` exist but are floor/bench-height; hips would need re-seating to 0.575 | **cheap variant, not a new clip** |
| doctor at a table | `civ_work` at table height already reads | **cut** |
| bandaging / IV / chart | ruled by Caleb, and measured to land within 4 cm | **cut** |

---

## 6. MARKER FAMILIES — `work_<building>_<role>` / `prop_<building>_<thing>`

Per his 2026-08-03 ruling. No two families here differ by one letter.

| name | n | status |
|---|---|---|
| `work_med_root` | 1 | **BUILT** — everything parents to it, welds the tent to one object |
| `work_med_cot_00..15` | **16** | **BUILT AND GATED** — a wounded man lies here, `laying_idle` |
| `work_med_tend_00..15` | 16 | proposed — one per cot, −X facing the cot, `civ_work` |
| `work_med_triage` | 1 | proposed — where a casualty is first put down |
| `work_med_ward_walk_0..3` | 4 | proposed — the aisle path a man walks between cots |
| `work_med_bearer_form` | 2 | proposed — where a litter pair forms up |
| `work_med_door` | 1 | proposed — the tent entrance trigger |
| `prop_med_litter_00..n` | ? | proposed — `fb_litter.glb` anchors |
| `prop_med_aidbag_*` | ? | proposed — aid-bag rest points |

Only the first two exist. **The rest await his ruling on names before I build them**, because
the chow hall's lesson is that renaming after Godot reads them is the expensive moment.

---

## 7. WHAT I AM NOT SURE ABOUT

1. **Head end.** `HEAD_PLUS_Y` rests on the frame-timber asymmetry plus the clip's own +Y. Two
   signals, both indirect. There is **no pillow** on these cots — the mattress is dead flat at
   0.575 across its whole length — so geometry cannot settle it outright. One constant, flips
   all 16.
2. **Why the old marker set is mirrored** (det −1) relative to the placed mesh. I sidestepped it
   rather than solved it. If those 40 markers are ever wanted back, this must be understood first.
3. **Which firebase file is the truth.** Two files, same payload, now diverging on marker names.
   Needs a ruling, not a guess.
4. **No ward-interior footage found.** The triage/ward-round rhythm is inferred from geometry.
5. **Whether 16 wounded men at once is the right density.** 16 cots exist; the chow hall showed
   that a scheduler, not a full house, is what reads well. `CampaignState.ward_wounded` already
   exists as the population source.
6. **How many men the tent should hold at all.** Untested — `build(n=5)` was never run on the
   chow hall either, and that is still open.
