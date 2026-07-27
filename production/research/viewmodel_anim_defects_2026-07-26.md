# FP viewmodel animation defects — measured audit, 2026-07-26

Source of numbers: `tools/audit_viewmodel_rigs.py` (read-only, headless, never saves the blend).
Raw data: `production/research/viewmodel_rig_audit.json`. Re-run with:

```
blender -b assets/player/arms/fp_arms_rifle.blend -P tools/audit_viewmodel_rigs.py -- [gun ...]
```

Written against Caleb's 2026-07-26 playtest report: *"the ak and m14 aligned perfectly and their
animations were actually still kinda broken and robotic. the hands were inside the guns for some of
the animations. the m16 has a lot wrong — the sights don't align because bad modeling and then all
the animations are way too fast then too slow. the ppsh has prototype animations. the ak has a broken
reload animation."*

---

## A. "Way too fast then too slow" — the PPSh is being retimed by the game

`scripts/player/weapon_holder.gd:894` — `_vm_anim.speed_scale = clip_len / maxf(0.05, duration)`.
ADR-018: the gameplay timer is authoritative and the clip stretches to match it. So any gun whose
authored clip length disagrees with its `.tres` timer plays at the wrong speed.

| gun | clip | frames | clip s | authored s | **speed_scale** |
|---|---|---|---|---|---|
| m16 | reload / reload_empty / jam | 72 / 80 / 138 | 2.400 / 2.667 / 4.600 | 2.4 / 2.6667 / 4.6 | **1.00 / 1.00 / 1.00** |
| ak | reload / reload_empty / jam | 78 / 133 / 109 | 2.600 / 4.433 / 3.633 | 2.6 / 4.4333 / 3.6333 | **1.00 / 1.00 / 1.00** |
| m14 | reload / reload_empty / jam | 78 / 133 / 138 | 2.600 / 4.433 / 4.600 | 2.6 / 4.4333 / 4.6 | **1.00 / 1.00 / 1.00** |
| ppsh | reload | 78 | 2.600 | 3.400 | **0.76 — 24% too SLOW** |
| ppsh | reload_empty | 133 | 4.433 | 3.400 (falls back to reload_time) | **1.30 — 30% too FAST** |
| ppsh | jam | 109 | 3.633 | 1.100 (WeaponData default) | **3.30 — plays at 3.3×** |

`data/weapons/ppsh41.tres` sets `reload_time = 3.4` and declares **neither** `empty_reload_time` nor
`jam_clear_time`, so it inherits `weapon_data.gd:16-17` defaults (`0.0` → falls back to `reload_time`,
and `1.1`). Its clips were transplanted from the AK, so they are AK-length.

**RESOLVED 2026-07-26, same session** (Summoner's ruling: *"the game timer needs to match the
animation's original times"*, and he chose to have the export write it rather than hand-maintain it).
See **ADR-034 Amendment A**. `tools/sync_weapon_timers.py` reads each clip duration from the exported
GLB's input accessors and writes the three timer fields into the `weapon_tres` named in the manifest;
`export_all_viewmodels.py` runs it after every export, and `validate_viewmodel_glb.py` now fails on
drift (proven by perturbing `jam_clear_time` back to 1.1 — validator reports `was playing at 3.30x`
and exits 1). All four guns now measure exactly 1.00×.

PPSh accepted values: `reload_time = 2.6`, `empty_reload_time = 4.4333`, `jam_clear_time = 3.6333`.
**Balance consequence he accepted:** jam clear goes 1.1s → 3.63s. When the PPSh clips are re-authored,
the timers follow on the next export.

**M16/AK/M14 retime at exactly 1.00** — their fast/slow is authored *inside* the clip, section B.

## B. A hand is completely frozen for whole clips

Per-frame hand-bone world speed, mm/frame. `dead` = frames where the bone moves < 0.05 mm.

| gun | clip | hand.R | hand.L |
|---|---|---|---|
| m16 | reload | **0.0 max — 100% dead** | 103.6 max, avg 20.1, 1 spike |
| m16 | reload_empty | **0.0 max — 100% dead** | 131.9 max, avg 23.7, 4 spikes |
| m16 | jam | **0.0 max — 100% dead** | 64.9 max, avg 20.2, 4 spikes |
| ak | reload | **0.0 max — 100% dead** | 86.4 max, avg 15.1 |
| ak | reload_empty | 72.3 max, 43.6% dead | 86.3 max, 22.6% dead |
| ak | jam | 72.3 max, 4.6% dead | 25.2 max, **54.1% dead** |
| m14 | reload | **0.0 max — 100% dead** | 155.4 max, avg 19.5, **1 teleport** |
| m14 | reload_empty | 76.0 max, 76.7% dead | 199.8 max, 5 spikes, **1 teleport** |
| m14 | charge_handle | 76.0 max, 42.6% dead | **0.0 max — 100% dead** |
| m14 | jam | 31.8 max, 59.4% dead | **0.0 max — 100% dead** |

The firing hand not moving at all for 72–138 frames is the single largest unnamed contributor to
"robotic". A real firing hand micro-drifts even while the support hand does the work. This is
*[[fp-arms-derobotise-recipe]] cause 3 and 4* (weapon freezing, zero-velocity plateaus) in its most
extreme form — not a subtle plateau, a dead limb.

"Spikes" = consecutive frames where speed changes by >3× while above 20 mm/f. Those are the visible
lurch inside a clip. "Teleports" = >150 mm in one frame — M14 `reload` and `reload_empty` each have one.

## C. The AK broken reload — mechanism confirmed, still live

`ak_mag_handoff` is a **132-frame** action and it is the strip under **both** the 78f `reload` track
and the 133f `reload_empty` track. It was authored for the long empty-reload hand path, so under the
short tactical reload the magazine rides a hand that is somewhere else.

This is the bug class named in memory (`recon-viewmodel-ruler-offset`) and diagnosed on 2026-07-26.
The headless bake that fixed it was **reverted the same night** because it looked worse to Caleb's eye,
so the defect stands. **Fix belongs in Blender, by Caleb** — author a handoff strip timed to the 78f
reload, or retime `ak_mag_handoff` for that track.

Same pairing class elsewhere (action length ≠ the clip length it plays under), lower severity because
the parts are static holds rather than handoffs:
- `ak_bolt_home`, `ak_hold_on` (132f) under `reload` (78f); `ak_mag_home` (132f) under `jam` (109f)
- `m16_ch_home` (88f) under `reload` (72f)
- M14: every `m14_oprod_*` / `m14_hold_on` / `m14_mag_home` strip (133f) under shorter clips

## D. Hands inside the guns — measured

Skinned arm vertices within 16 cm of a hand bone, tested against gun geometry; depth = how far inside
the surface. Idle is the baseline (fingers legitimately wrap a grip); the number that matters is the
**excess over idle**.

| gun | idle | worst clip | over idle | where |
|---|---|---|---|---|
| **ppsh** | 43.0 mm | **139.8 mm** | +96.8 | reload_empty f118, jam f40 — `PPSh41_gun.004` |
| **m14** | 29.7 mm | **80.5 mm** | +50.8 | reload_empty f50 — `M14_gun` |
| **ak** | 53.4 mm | **78.2 mm** | +24.8 | reload_empty f92, jam f14 — `AK47_gun` |
| m16 | 11.6 mm | 22.8 mm | +11.2 | reload_empty f76 — `M16A1_gun` |

The M16 is by far the **cleanest** on hand placement — matching Caleb's report that the AK and M14
aligned well but had hands inside the guns. The AK's 53 mm idle baseline means its rest grip is
already deep in the receiver.

*Caveat, stated because it changes how much to trust this:* the test is `closest_point_on_mesh` plus a
normal-dot inside test, which is only rigorous on closed manifold geometry. Treat the depths as a
**ranked signal and a frame index to go look at**, not as certified millimetres.

## E. M16 — unapplied object rotation on the gun root

`M16A1_gun` object rotation = **(2.642°, −0.021°, 89.893°)**, scale 1.0 uniform. The Z is 0.107° off
square and X carries a 2.64° cant. It is the only gun root in the file with a non-identity rotation.
Candidate contributor to "the sights don't align" — to be judged in Blender alongside the modeling.

Everything else is clean: all four gun roots are 1.0 uniform scale, no non-uniform scale on any
animated object, M16 rig contract (CHILD_OF→hand.R, all four clip tracks, all three markers) reports OK.

## F. Marker parenting is inconsistent between guns

M16's three markers parent to the gun root. **AK's parent to `AK47` and M14's to `M14_gun`** — the
mesh, not the root the manifest names. Harmless today because the exporter bakes by world matrix, but
`markers_under_gun: true` in `tools/viewmodel_manifest.json` asserts something that is not literally
true for ak/m14 — and a `markers_under_gun: false` claim is exactly what hid the M14 fittings bug on
2026-07-25.

## G. Curve-handle census — and why it matters less than it looks

| gun | clip | keys | handles |
|---|---|---|---|
| m16 | reload / reload_empty / jam | 2900 / 3766 / 3453 | **AUTO + VECTOR** — the 2026-07-25 de-robotise pass held |
| ak | reload / reload_empty | 518 / 1813 | **AUTO** |
| ak | jam | 57,200 | 100% AUTO_CLAMPED |
| m14 | reload / reload_empty / charge_handle / jam | 41k / 70k / 29k / 72k | 100% AUTO_CLAMPED |
| ppsh | reload / reload_empty | 524 / 1819 | AUTO (inherited from the AK) |
| ppsh | jam | 57,200 | 100% AUTO_CLAMPED |
| all | rifle_idle | 520 | AUTO_CLAMPED (single frame — irrelevant) |

**The AUTO_CLAMPED clips are all per-frame baked** (57k–72k keys over 109–138 frames = a key on every
frame of every channel). For a densely baked action the handle type does not reach the game: the
exporter samples integer frames, so the sampled value *is* the key and the tangents are never read.
**Converting handles only helps sparse actions.** The AK `jam` and the four M14 clips are lurching in
their baked values, not their tangents — fixing those means re-authoring, not a handle sweep.

## H. The export is not eating anything — the pasted FBX advice does not apply

We export **glTF/GLB**, not FBX. `bake_anim_simplify_factor`, `bake_anim_step` and `add_leaf_bones` are
FBX-exporter properties and do not exist on the glTF exporter. `tools/export_viewmodel_clips.py:324-332`
already sets `export_force_sampling=True`, `export_optimize_animation_size=False` and
`export_animation_mode='NLA_TRACKS'`, and lines 174-246 bake every moving part frame-by-frame into real
TRS keys before the export runs. Nothing simplifies a curve anywhere in this path.

## I. DO NOT run the "apply all transforms, origins to 3D cursor" cleanup on this rig

It would break three things that are load-bearing here:
1. The PPSh has **27 static children carrying authored non-uniform proportions** (baked shear).
   Normalising them reshapes the gun ~3.5%; the validator was deliberately changed to allow them.
2. `M16A1_ch_rail`'s charge handle only slides cleanly because its **origin sits at the rail start**,
   so local X is a pure slider. Moving origins to the world cursor destroys that.
3. Non-identity `matrix_parent_inverse` is everywhere in this file **including the guns Caleb has
   already blessed**; bake-by-world makes it harmless at export. Mass-"fixing" it moves everything.

---

## Next session — build order

**Mine (headless, measurable, no animation authoring):**
1. ~~`data/weapons/ppsh41.tres` retime~~ — **DONE 2026-07-26**, and made unrepeatable: ADR-034
   Amendment A, `tools/sync_weapon_timers.py`, guard wired into the validator.
2. Re-run this audit after any Blender session; it is the regression probe for all of the above.
3. Fold the frozen-hand check (section B) into `tests/test_viewmodel_contract` so a dead limb fails
   the build instead of waiting for a playtest. The clip↔timer half of this is now covered by the
   validator.
4. Marker-parent inconsistency (section F) — correct the manifest claim or the parenting.

**Caleb's, in Blender — animation quality is his hands (standing ruling, 2026-07-26):**
1. AK `reload` mag handoff — section C. Named and located; a short fix once he is in the file.
2. Frozen `hand.R` across M16 reload/reload_empty/jam and M14 reload — section B.
3. M16 modeling + sights + ADS markers — his standing ruling; section E gives one measured lead.
4. M16 leftovers from 2026-07-26: 4 single-face floaters (3 facing down), 2 open sheets in the join,
   and the old hand height still in the reload/reload_empty/jam gripping segments (only `m16_fp_idle`
   was shifted).
5. PPSh — prototype clips to re-author; the bolt was never split off the gun so it is static in every
   clip; hand penetration is worst on this gun by a wide margin.

**Still unproven, all guns:** the clips have only ever been watched on the bench. Nobody has confirmed
they play correctly in the actual game through `weapon_holder`'s reload path.
