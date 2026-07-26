# P2 — Marker-Derived Viewmodel Poses: Systems/UX Design
**Architect:** systems-designer/ux · **Date:** 2026-07-26 · **Read code, not plans** — every claim cited.
**Scope:** concrete scheme for collapsing per-gun viewmodel truth into GLB markers + .tres offsets, per `production/research/viewmodel_pipeline_deep_dive_2026-07-26.md` §6 P2 (Summoner-approved direction).

---

## 0. Three findings that CORRECT the research doc's premises

**F1 — The .tscn "baked per-gun offsets" are not per-gun. They are ONE uniform constant.**
All 11 `*_arms_viewmodel.tscn` wrappers carry the byte-identical Model transform
`Transform3D(-1, 0, 0, 0, 1, 0, 0, 0, -1, 0, -1.81, 0)` — a 180° Y-flip + 1.81 m drop
(Blender rig stands at eye height facing +Z; the camera looks down −Z):
`scenes/weapons/m16a1_arms_viewmodel.tscn:8`, `m14_arms_viewmodel.tscn:8`, `mosin_arms_viewmodel.tscn:8`,
`rpg2_arms_viewmodel.tscn:8`, and identically in ak47/colt45/ithaca/m60/m70/ppsh/rpd (verified by grep, 2026-07-26).
The sin is not per-gun scene truth; it is **eleven hand-copies of one frame-fix constant**. That changes the
death plan (§4): there is nothing per-gun to migrate, only one constant to relocate.
(`m26_grenade_viewmodel.tscn:8` and `medkit_viewmodel.tscn` carry different, genuinely per-item scales — non-gun items, out of P2 scope.)

**F2 — `bore_dir`/`ads_bore_dir` are BENCH-ONLY. The game never reads them.**
Repo-wide grep (2026-07-26): the only consumers are `viewmodel_editor.gd` (:190-219, :353-354, :385-410, :643-652)
and the declarations at `weapon_data.gd:90,94`. The player's actual shot comes from
`controller.get_aim_direction()` (`weapon_holder.gd:431`); `_get_muzzle_position()` (`weapon_holder.gd:983-991`)
is only the tracer/round spawn ORIGIN. So the "second aim system" aims nothing in-game — it is the bench's
measuring stick, persisted in 11 .tres so B-auto-align stays honest between sessions. Collapsing it is
therefore pure data hygiene with **zero gameplay risk**.

**F3 — `viewmodel_scale`: 6 .tres carry the field, but only THREE are non-1.0.**
mosin 1.1 + m70 1.1 (both `viewmodel_fov = 62.0`), m79 0.9 — and **m79 has `model_path = ""`**
(`data/weapons/m79.tres`), so its 0.9 has never once been previewable. rpg7/m72_law/m26 carry a dead `1.0`.
The research doc's "6 non-1.0 values" overstates the sunk cost by 2× (and the live cost is really 2 guns).

---

## 1. Ground truth (what the three sources actually hold today)

| Source | Contents | Pointer |
|---|---|---|
| `.tres` (15) | `hip_position/rotation`, `ads_position/rotation`, `bore_dir`, `ads_bore_dir`, `viewmodel_fov`, `viewmodel_scale` (dead), `ads_fov`, `model_path` | `weapon_data.gd:86-99` |
| `.tscn` wrapper (11 guns) | the ONE uniform frame-fix constant (F1) | each wrapper line 8 |
| GLB markers | `MuzzlePoint` in all 12 GLBs; `SightRear`+`SightFront` in **m16/m14/ak only** (binary grep of `assets/player/viewmodels/*.glb`, 2026-07-26) | renamed at export by `tools/export_viewmodel_clips.py:215-222`; `--strict` requires all three at `:104-106` |

Runtime application: `weapon_holder.gd:812-859` lerps `hip_* → ads_*` by `ads_transition`, then stacks pitch-hack
(:820-831), sprint/fire-menu dips, sway, punch. Model load `:902-928` applies `_lens_ratio` scale (:919-920,
:973-978 — dies with P1) and plays `charge_handle` via `_play_vm_draw()` (:927, :881-888).
The V-key derivation math already exists and is correct: `viewmodel_editor.gd:487-534` — sight line from marker
globals converted into model space (:503-506), shortest-arc quaternion onto camera −Z (:509-516), then translate
so SightRear sits at `(0, 0, -EYE_RELIEF=0.12)` (:496-497, :526).

**Load-bearing subtlety for the whole design: marker positions are ANIMATION-FRAME-DEPENDENT.** The gun object
inside the GLB carries baked world-matrix TRS keys and rides hand.R (`export_viewmodel_clips.py:126-193`). The
bench derives under `rifle_idle` (`viewmodel_editor.gd:285-287`); the game at load is playing `charge_handle`
(`weapon_holder.gd:927`). A runtime-at-load derivation would sample sights mid-rack — a different pose every
boot path. **This single fact rules out runtime derivation** (§3).

---

## 2. THE RULING — derived vs authored, per field

| Field | Ruling | Rationale |
|---|---|---|
| `ads_position` / `ads_rotation` | **DERIVED** (V-key math, bench-time) **+ authored per-gun OFFSET** | The math exists and works (:487-534). Offset absorbs taste, eye-relief variance, the M70 scope case. |
| `hip_position` / `hip_rotation` | **AUTHORED — stays.** | There is no grip marker in any GLB, and none is needed: the gun rides hand.R, so the Blender-authored idle stance under the frame fix **is** the hip baseline. The current values are already tiny nudges on top of it (m14: `(0,0,-0.1)` / `(1.13,-1.90,0)`, `m14.tres:34,36`). Semantically hip_* ALREADY IS "offset from exported stance" — redefine the doc comment, don't rename the field. Deriving hip from a grip marker would be circular. |
| `bore_dir` / `ads_bore_dir` | **DERIVED → then DELETED** (fields die per-gun at re-export) | Bench-only (F2). New marker contract: the muzzle empty is AIMED in Blender (−Z down the bore). Fallback chain §5. |
| Frame-fix constant (the .tscn transform) | **BAKED AT EXPORT** (one constant, one place) | §4. |
| `viewmodel_scale` | **DELETE** — overturns the 7/14 "wire it" decree | §6. That decree predates P1; under the real-scale + FOV-shader law, a second mesh-scale knob is the scale hack reborn. |
| `viewmodel_fov` | AUTHORED (becomes the real per-gun lens knob once P1's shader consumes it) | absorbs the 3 scale values, §6. |
| `EYE_RELIEF` | stays a single derivation constant (0.12, `viewmodel_editor.gd:496`) | per-gun eye relief lives in the ADS offset's Z. No new field. |

## 3. Derivation scheme: BENCH-TIME with a probe-verified cache — not runtime

**Rejected: derive at weapon load.** Frame-dependence (§1 subtlety): at `_load_weapon_model` the draw clip is
playing; marker globals differ from the bench's idle-pose derivation, and differ again depending on when in the
frame you sample. A pose that shifts with animation timing is a WYSIWYG violation by construction.

**Adopted: the bench derives; the .tres carries the result as a verified cache.**

New `WeaponData` fields (`weapon_data.gd` Visuals group):
```gdscript
@export var ads_derived_position: Vector3 = Vector3.ZERO   ## MACHINE-written by the bench (V). Never hand-edit.
@export var ads_derived_rotation: Vector3 = Vector3.ZERO   ## degrees, same convention as ads_rotation
@export var ads_offset_position: Vector3 = Vector3.ZERO    ## Caleb's taste, on top of derived
@export var ads_offset_rotation: Vector3 = Vector3.ZERO
@export var derived_source: String = ""                    ## "<glb_path>@<md5-8>" stamp of the GLB derived against
```
`ads_position`/`ads_rotation` REMAIN and remain what the runtime reads — they become the machine-composed sum
(`derived ⊕ offset`, written by the bench at Ctrl+S). **`weapon_holder.gd:812-859` does not change by one byte.**
That is deliberate: the pose-application path is inside the WYSIWYG contract and the pitch/sway/punch stack; the
fewer moving parts there, the better.

**Composition order:** position adds (`ads_position = ads_derived_position + ads_offset_position`); rotation
composes as quaternions (`Quaternion.from_euler(derived) * Quaternion.from_euler(offset)` → euler degrees), NOT
euler addition — the derived rotations are 10–15° multi-axis (`m14.tres:37`) where euler addition visibly lies.

**The truth guarantee is a probe, not discipline** (P3 integration): headless test loads each marker-bearing gun,
plays `rifle_idle`, advances one frame, re-runs the V math, and fails if the result differs from
`ads_derived_*` beyond epsilon (0.005 m / 0.5°) or if `derived_source` doesn't match the GLB on disk. A re-exported
GLB whose sights moved now turns the suite red until someone re-benches — the "3 places disagree" disease becomes
mechanically impossible instead of merely discouraged.

**Legacy mode:** a gun whose model has no SightRear/SightFront (9 GLBs + 4 modelless) keeps today's semantics —
`ads_*` read as absolute, derived/offset fields zero, bench HUD badges it `AUTHORED (no sight markers)`. The flag
is implicit (marker lookup, same `_find_ads_marker` logic :569-585) — no new bool to rot.

## 4. Death of the .tscn wrappers

Because the offset is ONE uniform constant (F1), the options collapse:

1. **Bake at export (ADOPTED).** In `export_viewmodel_clips.py`, after recording world matrices (step 1,
   :126-144) and before write-back (step 3, :165-193): create a `CameraFrame` root empty carrying the constant,
   parent the collection roots under it, and write back keys as `matrix_world = FIX @ recorded`. Everything —
   rig, arms, gun, parts, markers — is transformed by the same constant in the same recorded frame, so **nothing
   can fight the animations**: the baked keys and the bone clips are re-authored inside the new frame together.
   The GLB comes out camera-ready; `model_path` flips to the `.glb` directly; the wrapper .tscn is **deleted in
   the same change** (fossil law). `--strict` gains an assert: gun bore at idle frame 0 points −Z ±5°.
2. Runtime basis fix in `weapon_holder`: works (a whole-model transform never fights child animations — it's what
   the wrapper does today) but moves a magic constant into code and keeps two load paths. Rejected.
3. Generated wrapper scenes from a template: honest single-source but keeps 11 files that exist to hold one
   constant. Rejected — it's F1 with extra steps.

**Interim:** a gun keeps its wrapper until it passes through the hardened exporter (P5). A P3-style probe pins the
transition: every surviving wrapper's Model transform MUST equal the constant exactly, and no `.tres` may point at
a wrapper whose GLB is camera-ready. The 4 modelless weapons (m79, m72_law, rpg7, shotgun→ithaca mismatch noted in
research §RC4) enter directly in the end-state shape when authored.

## 5. Bore collapse

New Blender contract clause: **the muzzle empty is aimed** — its −Z runs down the bore. The exporter already
renames it to `MuzzlePoint` (:215-217); `--strict` gains a self-check that PROVES aim instead of trusting it:
angle between muzzle −Z and the SightRear→SightFront line < 2° (physical sight-over-bore convergence at a 300 m
zero is ~0.17 mrad — far inside tolerance).

Bench `_bore_ray()` (:382-393) fallback chain replaces the field read:
1. **Aimed MuzzlePoint basis** (−Z), when the strict stamp says the GLB is pipeline-vNext;
2. **SightRear→SightFront direction** with origin still at MuzzlePoint — for the 3 current marker guns re-exported
   before the aimed-empty pass (angle-correct; the ~5 cm sight-height origin offset is 2 mrad at the 25 m board,
   at the bench's own `ALIGN_TOLERANCE_M` scale, :63);
3. **Legacy `bore_dir`/`ads_bore_dir` field** for the 9 stale guns, exactly as today;
4. Contract axis −Z (:387, unchanged last resort).

End state per gun: when it reaches chain step 1 or 2, its `bore_dir`/`ads_bore_dir` lines are deleted from the
.tres and — once ALL guns are through — the two fields die from `weapon_data.gd:90,94` and the editor's
I/K/U/O + Shift+B calibration keys (:190-208, :212-220) die with them (fossil law: the calibration UI exists only
because empties weren't aimed). One physical bore also retires the dual hip/ADS bore bookkeeping (:396-410) —
the model-local bore rotates with the model between hip and ADS, which is what a real gun does; the dual system
was compensation for tuning against `_lens_ratio`-distorted models (research RC1).

## 6. `viewmodel_scale`: DELETE, and the exact replacement values

Ruling: **delete** `weapon_data.gd:95`, the HUD read at `viewmodel_editor.gd:638`, the 6 `.tres` lines, and the
generator plumbing (`tools/gen_weapon_data.py:107,136,180`). The 7/14 War Room "wire it" decision
(`war_room/synthesis.md:71`) is explicitly overturned: it predates P1. With the FOV shader, per-gun on-screen
size is `viewmodel_fov`'s job; a second multiplicative mesh-scale knob re-poisons real-scale discipline and
MuzzlePoint truthfulness — it IS `_lens_ratio` with a different name.

The authored intent survives via the equivalence `tan(fov'/2) = tan(fov/2) / scale`:
| Gun | today | folded `viewmodel_fov` |
|---|---|---|
| mosin (`:20,:35`) | fov 62, scale 1.1 | **57.4** |
| m70 (`:33-34`) | fov 62, scale 1.1 | **57.4** |
| m79 (`:38-39`, no model — never rendered) | fov 62, scale 0.9 | **67.4** |
rpg7/m72_law/m26 carry `1.0` — pure line deletion. HUD line (:638) becomes `fov %.0f  vm_fov %.0f`.

## 7. Migration — the 15 .tres, in order

1. **GATE: P1 lands first.** Deriving against `_lens_ratio`-scaled models bakes the distortion into the cache
   (the V math itself runs through `weapon_model.global_transform`, :503-509, which today contains the lens
   scale). P2 code can be written in parallel; no derivation is SAVED before the shader ships. (Research §6
   ordering, reaffirmed from the code.)
2. **Schema:** add the 5 fields (§3) to `weapon_data.gd`; delete `viewmodel_scale` + fold the 3 values (§6).
   Same change: `gen_weapon_data.py` updated. Runtime untouched.
3. **Bench update** (§8) ships with the schema.
4. **Marker guns (m16, m14, ak):** post-P1 every old pose is invalid anyway (tuned against distorted models —
   research P1 tradeoffs; only M14 was ever fully tuned, `m14.tres:33-37`), so there is nothing to preserve:
   open bench → V → derived baseline appears, offsets start ZERO → Caleb nudges taste → Ctrl+S. Re-tune cost
   per gun collapses from 6 hand vectors to one V + a nudge.
5. **Legacy guns (mosin, rpg2, m70, m60, rpd, ppsh, colt45/m1911, ithaca/shotgun + m1911/shotgun name
   mismatches):** untouched, badged AUTHORED, stub poses (mosin `ads_rotation == hip_rotation`,
   `mosin.tres:38-39`; rpg2/mosin shared `ads_position = (0, 0.05, 0.08)` placeholder, `rpg2.tres:38`) flagged
   by the P3 stub detector. Each flips to derived mode when its GLB re-exports through `--strict` with sight
   markers + aimed muzzle (P5 coverage + P6 marker art pass) — at which point its wrapper dies (§4) and its
   bore lines die (§5), in that same change.
6. **Modelless (m79, m72_law, rpg7, shotgun):** authored straight into the end-state shape; never get a wrapper.
7. **Probes ship with, not after:** derive-drift probe (§3), stub detector, wrapper-constant probe (§4),
   `--strict` aim assert (§5). Per the observation-instrument lesson (7/25): each probe must EXERCISE its rig
   headlessly, not parse-check it.

## 8. What the bench becomes

Mental model shift: **nudges edit YOUR TASTE (the offset); V refreshes the MACHINE's baseline; the two never
fight.** Today a nudge and a V-press overwrite each other's work in the same field (:520-531 vs :329-340).

| Key | Today | After |
|---|---|---|
| WASD/QE/arrows/PgUp-Dn | writes `ads_position/rotation` (:163-166, :329-340) | ADS mode + derived gun: writes `ads_offset_*`; composed preview updates live. Hip/legacy: unchanged. |
| **V** (:223-224) | one-shot compute, overwrites the pose | **re-derive**: recompute `ads_derived_*` from live markers, KEEP offset, recompose. Idempotent. |
| **Shift+V** (new) | — | zero the ADS offset (snap to pure derived) |
| **B** (:222) | hip auto-align | unchanged (hip stays authored; B remains its one-key zero) |
| **I/K/U/O, Shift+B** (:190-220) | bore field calibration | legacy-mode only; hidden on derived guns; deleted with the fields (§5) |
| **R / Ctrl+S** (:210, :359-374) | snapshot/save 6 vectors | snapshot/save gains the 5 new fields; Ctrl+S recomposes then writes `derived_source` stamp |

HUD (`_update_position_display`, :627-666): line 2 `fov %.0f  vm_fov %.0f` (scale display dies); new badge line
`DERIVED (markers) + offset (dx, dy, dz)` vs `AUTHORED (no sight markers)`; unsaved-star logic extends to the new
fields; the stale-cache state (`derived_source` mismatch) shows `!! GLB CHANGED — press V` in warning color.
Instructions text (:728-750) updated to the offset vocabulary.

## 9. Tradeoffs named (no free lunches)

- **Sacrificed:** the 7/14 "wire viewmodel_scale" ruling (superseded with cause); the I/K/U/O bore-trim
  instrument (end state); byte-preservation of current tuned poses (already sacrificed by P1, not by P2).
- **Carried risk:** `.tres` still stores pose numbers (as cache+offset) — "one source of truth" is enforced by
  the drift probe, not by making derivation the only path. Accepted deliberately for a frame-deterministic
  runtime and an unchanged `weapon_holder` hot path.
- **Front-loaded Blender:** sight markers + aimed muzzles on 9 guns (P6, Caleb's hands) before derived mode is
  universal. Until then the armory is honestly two-tier, and the bench SAYS which tier a gun is in.
- **Exporter surgery (§4 step-3 rebasing)** is the riskiest single edit — it must ship with the `--strict`
  bore-direction assert in the same change, and a before/after clip-list + drift check on one gun (m14) blessed
  in-editor before the other exports re-run.
