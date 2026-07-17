# Technical Director — Arena Model Spawner: are the role exports broken, is v3 safe?

Method: read the GLB binary chunks directly (node tables, mesh tables, animation/skin
counts) plus `scripts/visuals/model_actor.gd`, `scripts/combat/gib_system.gd`,
`scripts/allies/ally_base.gd`, `scripts/levels/ai_stress_arena.gd`. No plan docs.

## 1. What the files actually contain (measured from the GLB JSON chunks)

| GLB | size | bin | nodes | meshes | **anims** | skin | Base_Human? | head_frag? | donor gear? |
|---|---|---|---|---|---|---|---|---|---|
| us_grunt_v3 | 16.5MB | 14.5 | 92 | 44 | **73** | 1 | **NO** | 01–07 | **YES** (bandolier+bando_mag0-2, ruck_bag/crossbar/rail_l/rail_r, canteen_l.002-.006) |
| us_grunt_v2 | 16.5MB | 14.5 | 88 | 40 | **73** | 1 | NO | 01–07 | partial (Cube.* donors) |
| us_grunt_m14/m60/m79 | ~16.5MB | ~14.5 | 88 | 40 | **73** | 1 | NO | 01–07 | weapon_world only |
| us_grunt_rifleman | 11.4MB | 11.4 | 78 | 36 | **0** | 1 | **YES** | 01–07 | none (only *_worn) |
| us_grunt_rto | 11.4MB | 11.4 | 78 | 36 | **0** | 1 | **YES** | 01–07 | none |
| us_grunt_pointman | 11.3MB | 11.2 | 78 | 36 | **0** | 1 | **YES** | 01–07 | none |
| us_grunt_mg/grenadier/marksman | ~11MB | ~11 | 75 | 33 | **0** | 1 | **YES** | 01–07 | none |

Node names read from the node table (Godot matches `MeshInstance3D.name` = **node** name,
not mesh name — this matters; v3's mesh datablocks are `Cube.0XX`, but the nodes are
`bandolier`, `ruck_bag`, etc.).

### The ~5MB gap is NOT missing content — it is the shared-animation design
- Old models bake **73 animation clips** into every character (`anims=73`, bin ≈14.5MB).
- Role exports carry **zero** (`anims=0`, bin ≈11MB) and borrow clips from
  `res://assets/shared/anim_library.glb` (**exists, 4.6MB**, Jul 12).
- This is the INTENDED modern pipeline. `model_actor.gd:154-155`: *"anim_library.glb
  carries every clip ONCE; character exports are mesh-only (EXPORT_ANIMATIONS=False) and
  borrow them here."* The 16MB models are the **legacy fat ones** that redundantly re-bake
  the whole library into each man.
- Both old and new carry `PSXRig` + `skin=1` (Godot generates `PSXRig/Skeleton3D` at
  import). `_merge_shared_library()` (model_actor.gd:188-218) gate at line 195 —
  `get_node_or_null("PSXRig/Skeleton3D")` — **passes** for the role exports, so they
  **animate fine**. The gap does not break them.

## 2. The ONE real defect in the role exports: Base_Human (bead eq6n)

All six role exports ship `Base_Human` — a second, full skinned body node — alongside
`us_grunt_joined`. The old models (v3/v2/m14/m60/m79) do **not** contain it.

`_apply_gib_rig_contract()` (model_actor.gd:371-417) hides donors by name: `grunt_*`,
`head_frag_*`, `cap_*`, plus `GibSystem.REGIONS[*].gear` (helmet_camo_shell,
helmet_bugjuice). `Base_Human` matches **none** of these prefixes and does not end in
`_joined`, so at line 388 it is classified as `has_body` — a body to KEEP. Nothing hides
it. **Result: two skinned bodies render on every role export.** This is exactly bead
**eq6n** (P1, open). model_actor.gd has no fix; eq6n's proposed whitelist is not
implemented.

## 3. a662 (head gibs dead) is STALE for this batch — do not act on it as written

a662 (P0) claims *"all SIX new grunts → ZERO head_frag_*"*. **Refuted by the files:**
every role export ships `head_frag_01..07`. The art was re-exported Jul 13 19:57 (after
a662 was measured). `GibSystem.dismember_head_burst` collects `head_frag_*` and would
find seven. Head gibs are **not** dead on the current role exports. a662 needs
re-measurement/closure, not action.

## 4. Is us_grunt_v3 genuinely safe? Yes — its caveat is fully runtime-masked

v3 carries donor gear (x1bs / x1bs.1): `bandolier`+`bando_mag0/1/2`,
`ruck_bag`/`ruck_crossbar`/`ruck_rail_l`/`ruck_rail_r` beside `bandolier_worn` /
`ruck_pack_worn`, and numbered `canteen_l.002..006`. **But runtime cleanup already hides
every one of them:**
- `_hide_export_duplicates()` (model_actor.gd:311-359): `bandolier_worn` → hides
  `bandolier`+`bando_mag*`; `ruck_pack_worn` → hides `ruck_bag`/`ruck_crossbar`/`ruck_rail_*`;
  numbered-dup collapse keeps `canteen_l.002`, hides `.003-.006`.
- `_apply_gib_rig_contract()`: hides `helmet_camo_shell`/`helmet_bugjuice`/`grunt_*`/`cap_*`/`head_frag_*`.

So v3 renders exactly one body + `helmet_shell_worn` + `bandolier_worn` + `ruck_pack_worn` +
`pouch_belt_worn` + one canteen + `m16_world`. Clean. It also has **73 baked anims** (self-
sufficient even if the shared library ever fails) and **no Base_Human**. x1bs.1 is a .glb-
hygiene re-export nicety, not a runtime blocker.

Decisive contrast: v3's extra meshes are all covered by existing cleanup rules; the role
exports' extra (Base_Human) is covered by **none**. That runtime cleanup does NOT save the
role exports — there is no Base_Human rule to invoke.

## 5. Where the arena stands

`ai_stress_arena.gd:34-41` maps MOS → role exports (pointman/rto/rifleman/grenadier/mg) —
i.e. it currently spawns the double-body models. `squad_system.gd:71-78` mixes v3 with role
bodies. `ally_base.gd:154` default `sprite_unit = "us_grunt_v3"`. Resolution
(`ModelActor.model_path`, model_actor.gd:22-29) is a bare `unit_id + ".glb"` folder search —
swapping the arena to `us_grunt_v3` is a one-string change per MOS, no rig/anim dependency
risk (v3 self-animates).

## Bead ledger (avoid duplicates)
- **eq6n** (P1) — Base_Human second body. THE real role-export defect. Live, unfixed. ✔ covers it.
- **x1bs / x1bs.1** (P1) — v3 donor-gear double-render. Real but **fully runtime-masked**; x1bs.1 = clean re-export task, not a blocker.
- **a662** (P0) — head gibs dead / zero head_frag. **STALE** — current role exports have all 7 frags. Re-measure or close.
- **s14j** (P0), **bgfq** (P0) — art-pipeline drift (no-scene blends; base-blend disposability). Unrelated to the render defects and to the arena model choice.

## ADDENDUM — is us_grunt_v2 a safe SECOND body? (coordinator follow-up)

Measured from the GLB node table:
- **(1) NO Base_Human / no second body** — confirmed, 0 present.
- **(2) head_frag_01..07** — all seven present.
- **(3) anims=73 baked** — self-sufficient, animates WITHOUT the shared library (also has PSXRig+skin so it would resolve the library too — but doesn't need it).
- **(4) donor gear:** v2 carries the RAW donor kit — `bandolier`+`bando_mag0/1/2`, `ruck_bag`/`ruck_crossbar`/`ruck_rail_l`/`ruck_rail_r`, `canteen_l.002-.006`, `helmet_camo_shell`/`helmet_bugjuice` — but **has NONE of v3's `*_worn` meshes** (no `bandolier_worn`, `ruck_pack_worn`, `pouch_belt_worn`, `helmet_shell_worn`). Consequence in `_hide_export_duplicates()` (model_actor.gd:311-334): the donor-hide branch is gated on the `*_worn` twin existing, so it **does not fire** — the donor ruck/bandolier stay visible. That is FINE: with no `*_worn` twin there is **no double-render** (x1bs's bug is two copies; v2 has one). The numbered-canteen collapse DOES fire (keeps `canteen_l.002`). The gib contract hides `helmet_camo_shell`/`helmet_bugjuice`/`grunt_*`/`cap_*`/`head_frag_*`.

Net render: body + m16 + one bandolier + one ruck + one canteen, helmeted. Single-layered, clean.

Peer quality: v2 and v3 are same-day siblings (v2 Jul 12 11:43, v3 12:04), same `HumanoidBase`, same texture atlases (`*_better textures`, `face_atlas_v3`). v3 is just the later cut that split gear into `*_worn` for cleaner gibbing. v2 is a reasonable visual peer — **not** a visibly older/worse model.

ONE eyeball to close it: v2's helmet is not a `*_worn` mesh; per bead x1bs (in-engine measured) v2 has a helmet **welded into the joined body**, so hiding the `camo_shell`/`bugjuice` donors leaves it helmeted. The bytes can't prove the welded helmet — one test spawn confirms it.

Verdict: **YES, v2 is a safe second general-purpose body alongside v3.** The ideal peers (rifleman/pointman, also m16) are OFF the table until eq6n's Base_Human is fixed. v2 is the best available clean second body today.
