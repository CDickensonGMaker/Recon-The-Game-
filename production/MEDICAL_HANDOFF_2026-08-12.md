# Medical complex + Huey — handoff, 2026-08-12

Long session. The Huey is **finished and exported**. The medical complex is **partly done**
and has one clear next job: **rebuild the office desks/chairs so the architecture lines up.**

---

## 1. HUEY — DONE AND EXPORTED (do not redo)

| File | Written | Contents |
|---|---|---|
| `assets/shared/anim_library.glb` | 12:56 | **216 clips** |
| `assets/us/vehicles/huey_v3.glb` | 12:58 | **156 nodes** |
| `assets/us/vehicles/huey_v3.blend` | saved | source |

Seven clips synced bones-only into `anim_library.blend` (213 → 220 actions) and verified
present in the GLB by parsing it: `sit_lip_outboard_a/b`, `hop_off_heli`,
`hop_off_heli_stumble`, `sit_bench_upright`, `mount_skid_step_FINAL`, `disembark_heli_FINAL`.

**Ruling: the boarding animation is CUT.** Troops are placed into seat markers instead
(*"when people get into the huey they just get placed into a seat marker until its full"*).
The mount beat is not in the reference footage — the camera cuts away — so stop looking for it.

**Seats: 18 total / 16 passenger.** `seat_system.gd` carries `seat_bench_1..6` alongside
`seat_pax_1..8`; fill order is door lip → centre bench → gunner berths. The player can occupy
any of them (`seat()` detects `enter_seat`). `_seat_clips()` hands bench seats
`sit_bench_upright` and alternates the two lip clips down the row.

**Markings:** `ARMY` + serial + `219 AHC` on the boom/fin, nose art on the aft cabin panel.
Fictitious unit invented and approved: **219th Assault Helicopter Company, "The Undertakers"** —
`VARIANT_A` PALLBEARER 66-16579 · `VARIANT_B` REAPER 67-17174 · `VARIANT_C` LAZARUS 68-15612.
`helicopter.gd::_pick_markings()` picks one per airframe at spawn. Each variant has a parent
empty named `VARIANT_A/B/C` **because glTF does not export collections as nodes** — without it
the picker silently finds nothing.

**Rotors need no animation** and adding it would break them — `helicopter.gd:44` drives them in
code so RPM spools with flight state, and line 55 warns the imported AnimationPlayer fights it.

**Detail kit:** 6 parts / 162 polys (pitot on the cockpit roof, 2 boom whips, belly VHF,
tail skid, exhaust), all built by duplicating existing airframe parts per the
no-procedural-geometry ruling. Export tool: `tools/export_huey_v3.py` (filters `PV_*`).

---

## 2. MEDICAL — WHERE IT STANDS

Working file: **`assets/shared/medical_preview.blend`** (~34.7 MB, ~570 objects).
Built by copy-and-strip from `firebase_v3.1_RECOVERED_medical.blend` (the truth source —
only ever read, never written). Tool: `tools/make_medical_preview.py`.

### Caleb's scope ruling
Three scenes only: **a surgery scene · tending laying wounded · officers in their office
writing** (the office clip is wanted for HQ tents too). Everything else was deleted —
25 figures / 446 objects and 25 orphaned markers.

### Staging areas (his preferred way of working — fix in staging, then port to the tent)
| Collection | Location | Contents |
|---|---|---|
| `MED_SURGERY_STAGE` | x 72–78, y −54..−46 | OR bed + lamp cut, surgeon, scrub nurse, anaesthetist, patient |
| `MED_BED_STAGE` | x 51–66, y −46..−39 | 3 trestles + 3 wounded + 3 attendants |
| `MED_OFFICE_STAGE` | x 52–57, y −58..−53 | 314-face desk cut + 3 officers (**needs rebuilding**) |

### DONE
- **Surgery** — patient on the real operating bed (2.05 × 0.80 m, top 5.18), crew placed at the
  bed edge facing it, surgeon bodies (`PSXRig_surgeon` donor from `us_base_v3.blend`:
  apron + mask + scrub cap), hands over the patient, staggered.
- **Beds** — 3 standing attendants, Caleb's own hand-posed arms baked in, elbows above hands,
  three different clips/rhythms/offsets: `med_or_support_high` (working),
  `med_or_support_low` (dressing), `med_rounds_glance` (clipboard).
- **Officers** — seated on the stools that were already modelled in, hands on the desk.

### NOT DONE — start here
1. **REBUILD THE OFFICE DESKS AND CHAIRS.** Caleb: *"we need to remake the entire desks and
   chairs scene first… chairs fitting inside the right spots and having all the chair and desk
   architecture lining up properly."* Do NOT append new chairs — that produced two per desk.

   **MEASURED SPEC (staged coords, y = tent y − 60; floor 4.24):**

   | Element | Size | Top z | Above floor |
   |---|---|---|---|
   | desks ×3 | 1.43 × 1.40 | 4.95 | 0.71 |
   | large seats ×3 | 0.85 × 0.85 | 4.61 | 0.37 |
   | small seats ×3 | 0.54 × 0.54 | 4.67 | 0.43 |
   | items on desks ×3 | ~0.32 × 0.32 | 5.00 | — |

   **THREE FAULTS, all measured:**
   - **There are already TWO seats per desk in the mesh** — a 0.85 m block at 4.61 and a
     0.54 m one at 4.67. That is the "two chairs" Caleb sees; both are modelled in, neither
     was added by me (my appended field chairs are deleted).
   - **The seats OVERLAP the desk footprints.** Desk 0 spans X 54.42–55.84 / Y −55.24..−53.84;
     its 0.85 seat sits at X 54.95–55.79 / Y −54.74..−53.89 — i.e. *inside* the desk.
     Nothing can sit there.
   - **Heights are wrong for a seated man.** A field desk is ~0.73–0.76 and a stool ~0.45.
     Ours is a **0.37 stool under a 0.71 desk**, leaving a 0.34 m knee gap. Seating an officer
     on the 4.61 stool put his **feet 12 cm through the floor** (4.12 vs 4.24).

   Target: seat ≈ 0.45 above floor (z 4.69), desk ≈ 0.74 (z 4.98), seat placed clear of the
   desk footprint on the officer's side, one seat per desk.
2. **Officer feet are 12 cm through the floor** (4.12 vs floor 4.24) after seating them on the
   4.61 stools — the clip's leg length does not match the stool height.
3. **Officer arms** — hand-pose them; see the workflow below.
4. Medical clips are **not in the shipped `anim_library.glb`**: `med_tend_medic`,
   `med_tend_patient`, `med_wounded_idle`, and none of the 5 authored `med_*` clips.
5. **No game code reads the medical markers.** `work_pos`/`work_clip` walking exists only for
   VC camps (`camp_director.gd`, `enemy_base.gd:1660`). A friendly-side director is needed
   before any of this appears in game.

---

## 3. THE WORKFLOW THAT ACTUALLY WORKS

**Caleb poses the arms by hand; I capture and rebuild.** This beat every IK solve attempted.

```
1. He poses the arms in the viewport.
2. IMMEDIATELY capture, before any frame change — an unkeyed pose is destroyed the moment
   the action re-evaluates:  store rotation_quaternion for the 8 arm bones to a scene prop.
3. Key that pose on every frame, adding a small sine on the UPPER ARM only for the work motion
   (2-4 deg), the two arms out of phase, a different period per figure.
4. The body clip keeps driving spine/legs, so sway and weight shifts survive.
```
Diff the captured pose against the stored one to find which figure he moved (a real edit shows
~0.5+; sine motion between frames only shows ~0.02).

---

## 4. TRAPS THAT COST HOURS TODAY — READ BEFORE MEASURING ANYTHING

- **Measure furniture from VERTEX EXTENTS, never face centres.** Face centres invented a
  phantom 1.78 m operating table and made me lay the patient across a 0.70 m tool trolley,
  then place the whole crew around an axis that did not exist. Same bug made a region cut keep
  36 m of geometry because the earth pad is 78 faces covering 2,004 m².
- **A zero-influence NLA strip silently plays NOTHING** — the rig just holds whatever pose it
  last had, which reads as a broken clip rather than a disabled one. 98 strips were at 0.0.
- **`armature.pose_position == 'REST'` fakes a prone/frozen rig.** Check it first.
- **`obj.pose.bones[].head` on the ORIGINAL object returns REST** — use
  `evaluated_get(depsgraph)`. Hidden objects are not evaluated at all, and `hide_viewport`
  toggles do not take effect within the same script execution.
- **Blender 5 slotted actions**: no `action.fcurves`; an unbound slot means the action does
  nothing. NLA strips have their own `action_slot`.
- **Setting `location` on these rigs may not propagate** — assign `matrix_world` instead.
  Reading a stale `matrix_world` and re-applying an offset compounded it and threw chairs 235 m.
- **Layered action over NLA gets blended, not replaced** — baked arm keys were diluted until
  each officer got a single private action (`med_officer_desk_o0/1/2`).
- **Kneeling vs standing**: `med_tend_medic` / `medic_treat_give` / `med_officer_desk` put hips
  only 0.29–0.49 above the feet. Standing clips are `med_or_support_high/low`,
  `med_surgeon_table`, `med_rounds_glance` at 0.88.
- **Gore caps (`cap_*`) and `Base_Human` must stay hidden**, and 416 orphaned parts were piled
  at the world origin — 208 of them visible, read as floating limbs and bandages.

---

## 5. HIS RULINGS THIS SESSION

- Animation workflow is now a skill: **`recon-animation-pipeline`** — footage for beats, splice
  existing library clips, bring up the Mixamo MCP for gaps, never author cold.
- No procedural geometry — duplicate a known-good part and modify, or transplant.
- Wounded elbows resting in the trestle rail: **not an issue, do not re-flag.**
- Fewer figures that actually do something beats a full tent of static posers.
- The models/faces are wrong on the medical figures (loose limb parts rather than
  `us_grunt_joined`) — **he has parked this**; the skeleton is the same 41-bone PSXRig so all
  animation transfers if the bodies are swapped later.
