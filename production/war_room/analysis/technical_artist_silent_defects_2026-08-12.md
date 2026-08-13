# WAR ROOM — INDIVIDUAL SIGHT · asset/technical-artist
# SILENT PLAYER-FACING DEFECTS

**Date banner: 2026-08-12.** Every claim below carries a `file:line` or a measured fact
(GLB JSON chunk parsed directly, mtimes read off disk). **READ-ONLY audit** — no `.blend`
touched, no Blender MCP driven, no GLB re-exported, no test suite run. Caleb is live in
`firebase_v3.2.blend`; the export is his call.

Measurement tooling was written to the session scratchpad, not the repo:
`…/scratchpad/glb_anims.py`, `glb_meshes.py`, `hidenet_sim.py`.

---

## HEADLINE

Four defects were assigned. **Two are confirmed, one is REFUTED as a probe false-positive,
and one turned out to be far larger than logged.**

The trouser defect is not a skinning problem. It is a **prefix-matching bug in
`model_actor.gd`** that disables the entire gib-donor hide net on **9 of 42 character
GLBs** — and, because the guard `return`s before the reporting call, it also **disables the
warning that would have told anyone**. Those 9 units include `vc_sapper`, `nva_sapper`,
`nva_rpg`, `vc_rpg` and the mortar crew: the cast of the demo's night assault.

---

## DEFECT 1 — RPD and RPG-2 have no fire/reload animation · **CONFIRMED**

### The measurement (not the doc)

`assets/player/viewmodels/` mtimes, read off disk 2026-08-12:

| File | Size | mtime |
|---|---|---|
| `rpd_fp.glb` | 2,410,752 B | **2026-07-11 22:33** |
| `rpg2_fp.glb` | 2,388,852 B | **2026-07-11 22:33** |
| `ak_fp.glb` (control) | 3,042,032 B | 2026-07-29 22:03 |
| `m70_fp.glb` (control) | 2,949,708 B | 2026-07-28 16:55 |

GLB JSON chunk parsed, `animations[].name` enumerated:

```
rpd_fp.glb    animations (1): ['rifle_idle']
rpg2_fp.glb   animations (1): ['rifle_idle']
ak_fp.glb     animations (6): ['rifle_idle','reload','reload_empty','charge_handle','fire','jam']
m16_fp.glb    animations (6): ['rifle_idle','reload','reload_empty','charge_handle','fire','jam']
m70_fp.glb    animations (6): [same six]
colt45_fp.glb animations (6): [same six]
mosin_fp.glb  animations (6): [same six]
```

**The claim in `ART_GAPS_2026-08-07.md:198-201` is exactly right.** Both files hold one clip.

### Which clips the game expects, and which of those actually matter

`tools/viewmodel_manifest.json:151-158` (rpd) and `:349-356` (rpg2) both declare the same
six clips. Missing from both GLBs: **`reload`, `reload_empty`, `charge_handle`, `fire`, `jam`.**

But only **four** of those five are ever played. Grepping every `_play_vm_clip()` call site:

| Clip | Call site | Plays for RPD/RPG-2? |
|---|---|---|
| `reload` | `scripts/player/weapon_holder.gd:765` | **YES — missing** |
| `reload_empty` | `scripts/player/weapon_holder.gd:765` | **YES — missing** |
| `jam` | `scripts/player/weapon_holder.gd:747` | **YES — missing** |
| `charge_handle` (the DRAW) | `scripts/player/weapon_holder.gd:1023-1030` | **YES — missing** |
| `charge_handle` (post-shot rack) | `scripts/player/weapon_holder.gd:1005-1009` | No — `BOLT_ACTION` only; RPD is `firing_mode = 1` FULL_AUTO (`data/weapons/rpd.tres:10`), RPG-2 omits the line = SEMI_AUTO default |
| `fire` | **no call site anywhere in `scripts/`** | No — muzzle/recoil is procedural (`weapon_holder.gd:1003-1004`) |

### Why it is SILENT

`scripts/player/weapon_holder.gd:986`:

> `if _vm_anim == null or not _vm_anim.has_animation(clip): return`

A missing clip is an early `return`, not an error. And `:1026-1028` falls the draw back to
`_play_vm_idle()`. **Nothing logs, nothing warns, nothing fails.**

**What the player sees:** RPD reload = **7.0 s** (`data/weapons/rpd.tres:13`) of a frozen idle
pose. RPG-2 reload = **6.5 s** (`data/weapons/rpg2.tres:11`) of a frozen idle pose. Equipping
either gun snaps it into frame with no deploy. A jam clears with the gun motionless.

### THE BONUS DEFECT — these are PRE-TRANSPLANT exports

Parsing the mesh lists exposes something the log never recorded:

```
rpd_fp.glb    meshes (2): ['Cone.001', 'ArmsMesh']            Cone.001    = 1.0295 m
rpg2_fp.glb   meshes (2): ['Cylinder.034', 'ArmsMesh']        Cylinder.034 = 1.1995 m
```

Materials on `Cone.001` are the real RPD set (`WoodRPD`, `DrumOlive`, `HeatSteel`,
`BluedSteelVC.002`) — so it is the right gun, but it is a **single fused mesh**.

`tools/viewmodel_manifest.json:160-169` declares rpd's parts as `RPD`, `RPD_drum`,
`RPD_chandle` with contact markers, and `:357-364` declares rpg2's as `RPG2`,
`RPG2_pg2_boom`. The manifest's `_staged_doc` (`:6`) dates that split to the **2026-07-27
armory transplant**.

**These GLBs predate the transplant by 16 days.** The drum, the charging handle and the
rocket do not exist as separate objects in the shipped files, so even a hand-authored reload
could not have moved them. The re-export is not just "add five clips" — it swaps a fused
placeholder assembly for the split armory gun.

### Does the source hold the retargeted clips? — YES, by strong corroboration

- Source blend `assets/player/arms/fp_arms_rifle.blend`, **10,996,474 B, mtime 2026-08-05
  16:58** (read-only stat; the file was NOT opened).
- `tools/retarget_ref_anim.py`, 48,739 B, mtime **2026-07-28 22:16** — the retarget ran.
- **Ten** manifest entries carry the identical `_note`: *"clips RETARGETED from the AK-47
  reference pack 2026-07-28"* — `ppsh`(:118), `m14`(:144), `rpd`(:170), `colt45`(:196),
  `mosin`(:245), `m70`(:269), `ithaca`(:293), `m79`(:317), `m72_law`(:341), `rpg2`(:365),
  `rpg7`(:389).
- **Of that group, every sibling that was exported carries all six clips**: `m70_fp.glb`
  (7/28 16:55), `m79_fp.glb` (7/28 16:56), `colt45_fp.glb` (7/28 16:57), `mosin_fp.glb`
  (8/5), `ithaca_fp.glb` (8/5). The retarget demonstrably landed in the blend.
- `rpd` and `rpg2` were simply **skipped on the 7/28 export run**. `m72_law` and `rpg7` were
  skipped too and have no GLB at all (`ART_GAPS_2026-08-07.md:196-197`).

### THE COMMAND, THE COST, THE RISK

Manifest gun keys confirmed at `tools/viewmodel_manifest.json:146` and `:343`:

```
python tools/export_all_viewmodels.py rpd rpg2
```

Per `tools/export_all_viewmodels.py:41-72`, each gun runs: headless Blender export
(`--strict` pre-flight) → `validate_viewmodel_glb.py` → `sync_weapon_timers.py`.

**Runtime:** ~2–5 min for both (headless Blender launches twice on an 11 MB blend), plus a
Godot reimport on next editor open.

**RISK 1 — `--strict` may refuse `rpg2` on the scale gate.**
`tools/export_viewmodel_clips.py:147-149` aborts when
`abs(span - REAL_LEN) / REAL_LEN > 0.15`. `rpg2`'s declared `real_length_m` is **0.95**
(`viewmodel_manifest.json:347`), but the shipped RPG-2 mesh measures **1.1995 m** on its long
axis — **26% drift**, well past the 15% gate. If the blend's `RPG2` root still measures ~1.2 m
the export will **refuse and stop the run**. This is the Ithaca situation verbatim: Caleb
resolved that one by raising `real_length_m` from 1.003 to 1.304 (`:293`). The RPG-2 with a
PG-2 warhead loaded genuinely is ~1.2 m, so **0.95 is likely the wrong declared length, not
the mesh**. Decide before running, or the run dies on gun two.
`rpd` is safe: 1.0295 m measured vs 1.037 declared = **0.7% drift**.

**RISK 2 — hip/ADS poses were aimed against the OLD fused mesh.**
`data/weapons/rpd.tres:33-38` and `data/weapons/rpg2.tres:35-40` carry `bore_dir`,
`hip_position` and `hip_rotation` tuned on the 7/11 geometry. A transplanted gun sits on a
different origin. **Budget a bench pass** (`scenes/weapons/viewmodel_editor.tscn`, Ctrl+S
saves) after the export. Values cannot be guessed.

**RISK 3 — `sync_weapon_timers.py` will rewrite `reload_time`.** `export_all_viewmodels.py:67-72`
runs it automatically; the authored clip length becomes the gameplay timer. RPD's 7.0 s and
RPG-2's 6.5 s may move. That is the designed contract, not a bug — but it is a balance change
landing as a side effect of an art export, so it should be noticed rather than discovered.

**CLASSIFY: EXPORT (Caleb runs the command).** ~10 min of command time.
**Plus CODE/BENCH:** ~2 h for the pose re-aim on the bench, after the export lands.

---

## DEFECT 2 — `us_surgeon` draws as ONE MAN NOT TWO · **REFUTED**

**There is no duplicate spawn, no double `add_child`, no doubled marker, and no second man.
The warning is a false positive in the probe's own heuristic.**

### Where the warning comes from

`scripts/visuals/model_actor.gd:567-584`, `_report_second_body()`. The test is `:579`:

> `if box.y >= 0.6 and box.x >= 0.25:` → count it as a body

### What is actually in the file

`assets/us/characters/us_surgeon.glb` (11,265,472 B, mtime **2026-08-08 21:02**), AABBs
computed from each mesh's `POSITION` accessor `min`/`max`:

| Mesh | size (x, y, z) m | Verdict |
|---|---|---|
| `us_grunt_joined` | **1.5334 × 1.7132 × 0.2855** | the live man — 1.7132 m is the ADR-002 scale contract exactly |
| `apron_front` | **0.3944 × 0.6340 × 0.1918** | a **surgical apron**, material `SurgeonApron_bloodied`, textured `blood_splat_1` |
| `grunt_torso` (donor) | 0.3909 × 0.6522 × 0.2758 | hidden |
| `cap_torso` (donor) | 0.3909 × 0.6522 × 0.2462 | hidden |

`apron_front` is **37% of a man's height**. It is torso-sized because it is a torso garment —
its dimensions match `grunt_torso` almost exactly, which is what a correctly fitted apron
should do. It is finished, textured, deliberate art.

It trips the probe because 0.634 ≥ 0.6 and 0.394 ≥ 0.25 — it clears a "tall and wide" test
that was written to catch a whole **second man** (`Base_Human`, 1.7132 m) and has no upper
discriminator.

Simulating the full runtime hide chain over the GLB confirms only two meshes survive it:
`apron_front` and `us_grunt_joined`. That is verbatim the warning text quoted in
`ART_GAPS_2026-08-07.md:44` — **so the warning is fully explained, with zero art defect
behind it.**

### The real fix

`model_actor.gd:579` needs a discriminator that a garment cannot clear. A second MAN is
man-height. Gate on the tallest mesh in the instance rather than an absolute:

- flag only meshes within ~80% of the tallest mesh's height, **or**
- raise the bar to `box.y >= 1.2` (`grunt_leg_l` is 0.9276 m, so 1.2 still excludes every
  single donor limb while catching any real second body at 1.71 m).

**CLASSIFY: CODE FIX.** One line at `model_actor.gd:579`. **~30 min including a boot check.**
**Zero Blender work. Do not send Caleb after this one — the model is fine.**

> **Ledger correction owed (NO MORE DRIFT, `CLAUDE.md:237-244`):**
> `ART_GAPS_2026-08-07.md:44`, `SHIP_AUDIT_2026-08-11.md:75` (B7) and
> `SHIP_AUDIT_2026-08-07.md:66` all carry this as a real art defect costing ~0.5 art-day.
> It is not. Correct them on contact.

---

## DEFECT 3 — medic brassard / surgeon mask are DEFAULT WHITE · **SPLIT VERDICT**

Both GLBs were re-exported **2026-08-08 21:02**, a day after the warnings were logged.
Materials parsed from the GLB JSON:

| Model | Mesh | Material | baseColorTexture | baseColorFactor |
|---|---|---|---|---|
| `us_surgeon.glb` | `mask_face` | `SurgeonMask2` | **none** | `[0.86, 0.84, 0.79, 1]` |
| `us_medic.glb` | `medic_brassard` | `medic_brassard_white` | **none** | `[0.86, 0.85, 0.82, 1]` |
| `us_medic_black.glb` | `medic_brassard` | `medic_brassard_white` | **none** | `[0.86, 0.85, 0.82, 1]` |

### 3a — Surgeon mask · **RESOLVED, close it**

`0.86, 0.84, 0.79` is a chosen bone-white, not engine default white. A 1968 surgical mask is
white. This reads correctly. It also no longer trips the probe (below). **No work owed.**

### 3b — Medic brassard · **CONFIRMED, AND THE WARNING HAS BEEN SILENCED**

This is the worst thing in this report short of Defect 4, because of *how* it went quiet.

`model_actor.gd:616` only reports a surface when its **darkest channel is below 0.9**:

> `if minf(minf(c.r, c.g), c.b) < WHITE_ALBEDO_MIN: continue    # a real palette colour - stay quiet`

`WHITE_ALBEDO_MIN = 0.9` (`model_actor.gd:627`).

The brassard's darkest channel is **0.82**. It is **below the threshold, so the probe now
stays silent** — while the armband is still **plain white with no red cross**. The 8/8
re-export moved the albedo from pure white to bone-white and, as a side effect, **turned off
the only instrument that was reporting the defect.** The material is still literally named
`medic_brassard_white`.

Proof there is no cross anywhere: `us_medic.glb` carries **exactly one** `medic_brassard`
mesh (0.0988 × 0.1194 × 0.0999 m), one material, **no `baseColorTexture`**, and no second
mesh or decal geometry. Both medic variants are identical in this respect.

Is it fixed at runtime? **No.** `_apply_untextured_gear_tints()`
(`model_actor.gd:163-181`) is the only runtime material patch, and `_GEAR_TINTS`
(`model_actor.gd:156-158`) holds **one** entry — `"bandolier_tex"`. `medic_brassard_white` is
not in it and is never touched. No `.tscn` override exists either; every character is
instanced from the GLB through `ModelActor.model_path()` (`model_actor.gd:23-30`), which
resolves a bare `unit_id` to a `.glb` and nothing else.

**Not the `[[gear-textures-are-photographs]]` bug class.** That class is a reference photo
masquerading as a texture. Here there is **no texture at all** — the surface never had one,
and the flat colour is a deliberate (wrong) choice.

**Diagnosis: the asset is incomplete, not mis-pathed.** A red cross on an armband is
2-colour geometry or a 2-colour texture. It does not exist.

### The fix — two options, and they belong to different owners

**Option A (BLENDER, correct):** give `medic_brassard` a red-cross texture, or split the
cross as its own tiny mesh with a red material, in the medic source blend. Re-export both
`us_medic` and `us_medic_black`. **~30–60 min of Caleb's time.** This is the right answer —
it puts a real cross on the band.

**Option B (CODE, a stopgap only):** add `"medic_brassard_white"` to `_GEAR_TINTS`
(`model_actor.gd:156-158`). But a tint can only make the whole band one flat colour — a
**solid red armband**, not a white band with a red cross. Historically wrong and arguably
worse than white. **Recommend against.**

**CLASSIFY: BLENDER FIX (Caleb only). ~1 h.**

**CODE FIX owed regardless, and it is the more important half:** `WHITE_ALBEDO_MIN = 0.9`
(`model_actor.gd:627`) is too tight — a 0.82 bone-white is still "the palette pass never ran"
by any honest reading. Raise it to ~0.75, or (better) special-case surfaces whose material
name ends in `_white`. **~20 min.** Without this, the next asset that gets nudged to 0.85
goes dark to the instrument in exactly the same way.

---

## DEFECT 4 — LEGS CLIPPING TROUSERS · **CONFIRMED — AND IT IS A CODE BUG, NOT SKINNING**

`SHIP_AUDIT_2026-08-06.md:205` (M9), `SHIP_AUDIT_2026-08-07.md:95` (S9) and
`SHIP_AUDIT_2026-08-11.md:74` (B6) all log this as *"a skinning fix, not a texture one"* and
send it to Blender. **That routing is wrong.** It is the classic underbody-not-culled defect,
and the culling code is in GDScript.

### The mechanism

`ModelActor.setup()` (`model_actor.gd:121-142`) runs, in order:
`_apply_gib_rig_contract()` (`:137`) → `_apply_optional_gear()` (`:138`) →
`_hide_export_duplicates()` (`:139`).

`_apply_gib_rig_contract()` (`:501-549`) is the net that hides the gib donors — the bind-space
limb meshes that must not draw on a living man. Its **trigger guard** is `:509-520`:

```
if mesh_name.ends_with("_joined"):            has_body = true
elif mesh_name.begins_with("grunt_") or mesh_name.begins_with("head_frag_"):
                                              has_donors = true
elif not mesh_name.begins_with("cap_"):       has_body = true
if not (has_body and has_donors):
    return                                     # <-- model_actor.gd:520-521
```

and the hide test itself is `:541-542`:

```
var is_donor: bool = (nm.begins_with("grunt_") or nm.begins_with("head_frag_")
        or nm.begins_with("cap_") or nm == BASE_BODY_MESH) and not nm.ends_with("_joined")
```

**Both use `begins_with`.** Nine character GLBs prefix every mesh name with the unit id.

Measured, `assets/nva_vc/characters/vc_sapper.glb` (9,795,608 B, 2026-08-07 19:35):

```
vc_sapper_grunt_leg_l    0.2204 x 1.0050 x 0.2725   mats=['BlackPajama','Skin_VC']
vc_sapper_grunt_leg_r    0.2204 x 1.0050 x 0.2725   mats=['BlackPajama','Skin_VC']
vc_sapper_grunt_torso    0.3910 x 0.7194 x 0.2441   mats=['BlackPajama']
vc_sapper_grunt_head     0.1544 x 0.2210 x 0.1963   mats=['Skin_VC','face_atlas_mat','Hair_Black']
vc_sapper_cap_torso / cap_leg_l / cap_leg_r / cap_uparm_* / cap_forearm_* / cap_head
vc_sapper_joined         1.5338 x 1.7136 x 0.2725   <-- the live clothed man
```

`vc_sapper_grunt_leg_l` does **not** begin with `grunt_`. This GLB has no unprefixed
`head_frag_*` either. So `has_donors` stays **false**, and `model_actor.gd:520` **returns
before hiding anything.**

**Result: the full donor set renders stacked inside the live body — both 1.005 m legs, the
torso, both upper arms, both forearms, the head, and all eight gore caps.**

The donor legs carry `BlackPajama` (the trousers) + `Skin_VC` (the leg), skinned from
**bind-space** vertex data (`model_actor.gd:105-108` names this explicitly), while
`vc_sapper_joined` renders at **rest** scale. In bind pose the two coincide and nothing is
visible. **The instant the man moves, the donor leg shears out through the trouser.**

That is precisely and completely *"legs clip through trousers during movement, visible on
every man, every frame of movement."*

### Why nobody was ever told

`_report_second_body()` is called at **`model_actor.gd:548`** — *inside*
`_apply_gib_rig_contract()`, **after** the `return` at `:520`. On exactly the 9 units where
the net fails, the function exits before reaching the reporter.

**The instrument that would have caught this is switched off by the same line that causes it.**
This is why the defect has survived three ship audits as a vague "diagnose first" art row.

### Full roster sweep — 42 GLBs, runtime hide chain simulated exactly

| Tier | Units | State |
|---|---|---|
| **TIER 1 — BROKEN, contract never runs** (9) | `nva_sapper` · `vc_sapper` · `vc_sapper_stripped` · `nva_rpg` · `vc_rpg` · `nva_rto` · `nva_mortar_gunner` · `nva_mortar_dropper` · `nva_mortar_runner` | **Entire donor set + all gore caps render.** Legs (1.005 m), torso, arms, head, 7 head-frags, 8 caps. |
| **TIER 2 — head donor survives** (12) | `nva_rifleman` · `nva_regular` · `nva_mg` · `nva_marksman` · `nva_medic` · `nva_officer` · `vc_guerilla` · `vc_guerilla_mosin` · `vc_guerilla_ppsh` · `vc_guerilla_rpd` · `vc_guerilla_rpg` · `vc_medic` | Donors are named `HumanoidBase_NotOverlapping.NNN` — also outside the net. Hidden only by the **numbered-duplicate collapse** (`model_actor.gd:463-486`), which keeps the **lowest** suffix — and `.001` **is the head donor** (0.1544 × 0.2210 × 0.1963, `Skin_VC` + `face_atlas_mat` + `Hair_Black`). **Every NVA regular and VC guerilla renders a second bare head inside his head** — z-fighting on the face, scalp through the pith helmet. |
| **TIER 3 — correct by accident** (10) | all `civ_*` | Live body is `HumanoidBase_NotOverlapping.**002**` (1.5499 × 1.7132) and the donors are `.007`–`.030`. The numbered collapse keeps the lowest suffix, which here **happens to be the live man**. **One Blender re-number away from Tier 1.** |
| **TIER 4 — correct by design** (11) | all `us_grunt_*` · `us_medic` · `us_medic_black` · `us_pilot_*` · `us_surgeon` | Donors are `grunt_*` / `head_frag_*` / `cap_*` / `Base_Human` — the net matches. Exactly one body-sized mesh survives (`us_grunt_joined`). |

### Which of these ship in the demo

`scripts/missions/siege_director.gd:23` — `const SAPPER_DATA := "res://data/enemies/vc_sapper.tres"`.
Also `scripts/missions/mission_generator.gd:44-45`, `scripts/missions/lazy_group.gd:25-26`,
`scripts/levels/ai_stress_arena.gd:132-134`, `scripts/levels/burn_lab.gd:24`,
`scripts/levels/sapper_room.gd:33`, `scripts/levels/support_fire_range.gd:83`,
`scripts/main/game_flow.gd:259`.

**Tier 1 is the cast of the night assault** — the probe on the wire, the sappers, the RPG
gunners, the mortar crew. `CLAUDE.md:421-423` names the 45-man assault as the demo's climax.
The men the player looks at hardest are the ones rendering four extra limbs and eight wound
caps.

### The fix

**CODE. Match on the mesh's SUFFIX, not its prefix**, so a unit-id prefix cannot defeat it.
One shared helper, used by both the trigger at `model_actor.gd:509-519` and the test at
`:541-542`:

```
# a donor is identified by what the mesh IS, wherever the exporter put the unit id
func _is_donor_name(nm: String) -> bool:
    if nm.ends_with("_joined"):
        return false
    for tok in ["grunt_", "head_frag_", "cap_", "HumanoidBase_NotOverlapping"]:
        if nm.begins_with(tok) or nm.contains("_" + tok):
            return true
    return nm == BASE_BODY_MESH or nm.ends_with(BASE_BODY_MESH)
```

**Three cautions, and the third is the one that bites:**

1. **`HumanoidBase_NotOverlapping` must NOT be added blindly.** On every `civ_*` model the
   **live body itself** is `HumanoidBase_NotOverlapping.002`. Adding that token to the donor
   list **makes all ten civilians invisible.** The civilian live body must be identified
   first — by height (it is the only mesh at the full 1.7132 m contract) rather than by name.
   **Prefer a height-based rule for that token: a mesh at ≥95% of `TARGET_HEIGHT_M` is the
   body, never a donor.**
2. **Move `_report_second_body()` / `_report_untextured()` out of `_apply_gib_rig_contract()`.**
   They sit at `:548-549`, downstream of the `:520` `return`, and they must run on every unit
   — especially the ones where the net bails. Call them from `setup()` after `:139`, which
   also fixes a second ordering bug: today they run **before** `_apply_optional_gear()` and
   `_hide_export_duplicates()` have hidden anything, so they judge a half-built instance.
3. **`GibSystem` resolves donors by bare mesh name via `find_child()`**
   (`gib_system.gd:73-95`, `:131-177`, `:243-244`; `REGIONS` at `:22-50`). Prefixed names such
   as `vc_sapper_grunt_leg_l` will not resolve against a `grunt_leg_l` lookup either — so
   **the 9 Tier-1 units very likely cannot gib at all.** Confirm against
   `test_gib_contract_all` before shipping the visibility fix; hiding the donors without
   fixing the lookup would trade "clipping legs" for "an enemy who cannot be dismembered."
   This is out of my lane but it is the same root cause and it must not be split from it.

**CLASSIFY: CODE FIX (an agent can do it).** Roughly **3–4 h**: ~1 h for the matcher + the
civilian height guard, ~30 min to relocate the reporters, ~1 h to verify the gib contract
across the 9 Tier-1 units, ~1 h boot check across all 42.

**Zero Blender work, zero re-exports.** The art is correct. The GLBs are correct. **A rename
in the exporter would fix it too, but that is 42 re-exports of Caleb's time to work around
four lines of GDScript — do not send this to Blender.**

---

## SUMMARY LEDGER

| # | Defect | Verdict | Owner | Estimate |
|---|---|---|---|---|
| 1 | RPD / RPG-2 have no reload, jam or draw clip | **CONFIRMED** | **EXPORT** (Caleb) + bench re-aim | 10 min run · +2 h bench |
| 1b | Both are pre-transplant fused-mesh exports (no split drum / chandle / rocket) | **CONFIRMED, new** | rides the same export | — |
| 1c | `rpg2` `real_length_m = 0.95` vs 1.1995 m measured → `--strict` will likely refuse | **RISK, new** | decide before running | 5 min |
| 2 | `us_surgeon` draws as two men | **REFUTED** — probe heuristic false-positives on a 0.634 m apron | **CODE** (`model_actor.gd:579`) | 30 min |
| 3a | Surgeon mask default white | **RESOLVED** by the 8/8 re-export (0.86/0.84/0.79 chosen) | none | 0 |
| 3b | Medic brassard has no red cross | **CONFIRMED** | **BLENDER** (Caleb) | ~1 h |
| 3c | `WHITE_ALBEDO_MIN = 0.9` now silently passes the 0.82 brassard | **CONFIRMED, new** | **CODE** (`model_actor.gd:627`) | 20 min |
| 4 | Legs clip trousers | **CONFIRMED — code, not skinning.** Hide net disabled on 9 GLBs by `begins_with` vs a unit-id prefix | **CODE** (`model_actor.gd:509-521`, `:541-542`) | 3–4 h |
| 4b | 12 NVA/VC units render a second bare head (`HumanoidBase_NotOverlapping.001`) | **CONFIRMED, new** | same fix | included |
| 4c | 10 civilians are correct only by numeric accident | **CONFIRMED, new** | same fix (height guard) | included |
| 4d | `_report_second_body()` sits downstream of the `:520` return — the probe is dead on exactly the broken units | **CONFIRMED, new** | **CODE** | included |
| 4e | Tier-1 units likely cannot gib (prefixed names defeat `find_child`) | **SUSPECTED** — verify | **CODE**, adjacent lane | 1 h verify |

**Total code work in my lane: ~5 h — under one working day.**
**Total Caleb work: ~1 h Blender (brassard) + ~10 min export + one decision on `rpg2`'s
declared length.**

**The single highest-value item is Defect 4.** It is four lines of GDScript, it costs Caleb
nothing, and it is currently disfiguring every enemy in the demo's climax.
