# NVA / VC missing headgear — diagnosis

**Summoner's report (2026-08-12):** *"i see the nva and vc units might not have exported
properly since im not seeing thier hats on them"*

**Verdict: the export is NOT the defect.** Every hat is present in every GLB. The hats are
lost in the ENGINE, in `scripts/visuals/vc_nva_dresser.gd`, which takes the welded hat off
and hangs a library hat that lands rotated 90° and buried inside the man's neck.

---

## 1. The assets

Exported bodies: `assets/nva_vc/characters/*.glb` — 21 variants.
Sources in tree: `assets/nva_vc/characters/nva_vc_soldiers.blend`,
`assets/nva_vc/characters/vc_guerilla_v2.blend`,
`assets/nva_vc/props/nva_vc_gear_variants.blend`.
Detachable gear library: `assets/nva_vc/props/{headgear,packs,chest,belt}/*.glb`,
manifest `assets/nva_vc/props/nva_vc_gear.json`.

## 2. Test that splits the problem — do the GLBs contain hats?

Parsed the JSON chunk of all 21 character GLBs directly (throwaway script in scratchpad).
**21 / 21 carry a welded headgear mesh.** Nothing was lost at export.

| body | welded headgear mesh in GLB |
|---|---|
| nva_marksman, nva_medic, nva_mg, nva_officer, nva_regular, nva_rifleman | `pith_helmet_worn` |
| nva_mortar_dropper, nva_rpg | `pith_faded` (+ `pith_faded_band`) |
| nva_mortar_gunner, nva_rto | `pith_net` (+ band, scrim, tabs) |
| nva_mortar_runner, nva_sapper | `cap_cloth` (+ `cap_cloth_band`) |
| vc_guerilla, vc_guerilla_mosin, vc_guerilla_ppsh, vc_guerilla_rpd, vc_guerilla_rpg, vc_medic, vc_rpg, vc_sapper | `rice_hat` |
| vc_sapper_stripped | `bandana_red` |

(`cap_head`, `cap_forearm_*`, `cap_leg_*`, `cap_uparm_*` are GORE CAPS, not headwear — do
not let the word "cap" mislead a future reader.)

So this is an engine-side defect. Section 3 onward.

## 3. What the engine does at spawn

`scripts/enemies/enemy_base.gd:468-472` → `VcNvaDresser.dress(ma, rng)` for every unit
whose id begins `nva_` / `vc_` (`vc_nva_dresser.gd:113-114`).

`vc_nva_dresser.gd:289-311` `_rehang_headgear`:

1. picks a variant from the `headgear` library,
2. `_hang(...)` it on a `BoneAttachment3D` on `mixamorig_Head`,
3. **if and only if the hang returned non-empty, hides the welded hat**
   (`_set_visible_by_name(root, name, false)` for `HEADGEAR = ["pith_helmet","rice_hat"]`,
   `vc_nva_dresser.gd:52`).

The bone lookup is fine — `_socket_bone` (`vc_nva_dresser.gd:471-477`) tries both
`mixamorig:Head` and the Godot-sanitised `mixamorig_Head`. The hang SUCCEEDS. The hat is
therefore hidden and replaced. The replacement is what is wrong.

## 4. ROOT CAUSE — the library props are in the wrong reference frame

`nva_vc_gear.json` declares every socket matrix as IDENTITY and asserts in its own note:

> "IDENTITY by construction: every headgear GLB is authored with its vertices already
> expressed directly in mixamorig:Head bone-local space … A BoneAttachment3D on
> mixamorig:Head with this (identity) local transform … reproduces the fitted position
> exactly."

**That assertion is false.** Measured, not asserted:

`vc_guerilla.glb`'s welded `rice_hat`, transformed into `mixamorig:Head` node-local space
through the glTF node hierarchy (this is exactly the space a `BoneAttachment3D` reproduces):

```
X [-0.274, 0.311]   Y [ 0.081, 0.266]   Z [-0.214, 0.209]
```

The library `headgear/rice_hat_plain.glb`, same hat, raw vertex bounds:

```
X [-0.230, 0.267]   Y [-0.182, 0.177]   Z [-0.261, -0.104]
```

The axes are permuted. The library prop's up-the-skull axis is **−Z**; the socket's
up-the-skull axis is **+Y**. Match the intervals:

| welded (needed) | library (actual) |
|---|---|
| Y `[0.081, 0.266]` | −Z `[0.104, 0.261]` |
| Z `[-0.214, 0.209]` | Y `[-0.182, 0.177]` |
| X `[-0.274, 0.311]` | X `[-0.230, 0.267]` |

Required socket rotation is `Rx(+90°)`, i.e. `(x,y,z) → (x, −z, y)`. Declared: identity.

**Hung with identity the hat is tipped 90° face-down and sits at Y≈0 — the head bone's
origin, i.e. inside the neck — instead of Y≈+0.2 on the crown. It is completely enclosed
by the skull and torso, so it renders as nothing.** The welded hat has already been hidden.
Bare head.

Every one of the 12 headgear GLBs shares the same signature — centre at
`z ≈ −0.16`, `y ≈ 0` — so all 12 are in the same wrong frame:

```
cap_cloth        c=[ 0.018, -0.002, -0.158]
pith_faded       c=[ 0.000,  0.016, -0.156]
pith_foliage     c=[-0.003,  0.054, -0.153]
pith_net         c=[ 0.000,  0.016, -0.157]
pith_plain       c=[ 0.000,  0.016, -0.156]
pith_star        c=[ 0.000,  0.016, -0.156]
pith_worn        c=[ 0.000,  0.016, -0.156]
pith_worn_foliage c=[0.021,  0.016, -0.157]
rice_hat_foliage c=[ 0.017, -0.002, -0.153]
rice_hat_frayed  c=[ 0.018, -0.002, -0.183]
rice_hat_plain   c=[ 0.018, -0.002, -0.183]
```

### Independent corroboration A — the US helmet, which works

`assets/us/props/helmets/helmets.json` `socket.matrix_basis` is **not** identity; it is a
±90° rotation about X plus a small offset:

```
row0 = [ 1,  0,  0 ]
row1 = [ 0,  0,  1 ]
row2 = [ 0, -1,  0 ]
```

The US helmet family, authored the same way in Blender, needs a 90° X correction to sit on
a head. The gear manifest's note explicitly claims the NVA/VC family is different and needs
none. It is not different. That note is the defect, written into data.

### Independent corroboration B — packs are grossly un-baked

Same survey over `assets/nva_vc/props/packs/`. Six packs are not in bone-local space at all;
they are still in the roster line-up's world coordinates:

```
pack_frame            c=[2.113,  1.242, -0.068]
pack_frame_foliage    c=[1.031, -0.397, -0.398]
pack_ruck_full        c=[1.063,  1.240, -0.034]
pack_ruck_full_foliage c=[1.886, -3.326, -0.497]
pack_ruck_light       c=[0.012,  1.240, -0.032]
pack_satchel          c=[5.265,  1.237,  0.029]
pack_satchel_foliage  c=[0.676, -3.508, -0.404]
```

A pack whose vertices sit 5 metres out on X cannot be "identity by construction". The
manifest's blanket claim is disproved on its own files. Expect packs to be missing/floating
too — the Summoner has simply noticed the hats first because the silhouette is the
recognisable part.

### Independent corroboration C — several prop GLBs ship a stray armature

`headgear/pith_faded.glb` root nodes include `nva_rpg_PSXRig` at translation `[22, …]`;
`pith_net.glb` has `nva_rto_PSXRig` at `[24, …]`; `pith_plain.glb` has
`nva_regular_PSXRig` at `[8, …]`. Those X values are the roster line-up spacing in the
source .blend — a whole rig was dragged into the export. It is harmless in itself (the hat
meshes carry `skin: null` and no `JOINTS_0`, so nothing is driven by it) but it is 42 dead
nodes per hat and it is the fingerprint of an export that selected more than it meant to.
`rice_hat_plain.glb` and `rice_hat_frayed.glb` are the only clean 1-node files.

## 5. Which men actually go bare, and which do not

`_set_visible_by_name` matches on `mi.name.contains(needle)` (`vc_nva_dresser.gd:518`), and
`HEADGEAR` lists only `"pith_helmet"` and `"rice_hat"`. So the welded hat is removed only
where its mesh name contains one of those two strings. Prediction, per variant:

**BARE-HEADED (welded hat hidden, library hat buried) — 14 bodies**
`nva_marksman`, `nva_medic`, `nva_mg`, `nva_officer`, `nva_regular`, `nva_rifleman`
(`pith_helmet_worn` contains `pith_helmet`), and `vc_guerilla`, `vc_guerilla_mosin`,
`vc_guerilla_ppsh`, `vc_guerilla_rpd`, `vc_guerilla_rpg`, `vc_medic`, `vc_rpg`, `vc_sapper`
(`rice_hat`).

**STILL WEARING A HAT (welded name not matched, so never hidden) — 7 bodies**
`nva_mortar_dropper`, `nva_rpg` (`pith_faded`); `nva_mortar_gunner`, `nva_rto` (`pith_net`);
`nva_mortar_runner`, `nva_sapper` (`cap_cloth`); `vc_sapper_stripped` (`bandana_red`).
These men carry an invisible second hat inside their necks but look correct.

This split is the cheapest confirmation available: **if the mortar crew, the RTO and the
sappers still have hats while the riflemen and guerillas do not, this diagnosis is right.**
Ask the Summoner, or look at any screenshot with both.

Second, orthogonal contributor: `headgear/bare` is a real library entry with `glb: null`.
`_hang` returns the pick for a null glb (`vc_nva_dresser.gd:439-441`), which counts as a
successful hang, so the welded hat comes off and the man is deliberately bareheaded. That
is ~1-in-11 by design and is NOT the bug — but it will muddy a small sample.

## 6. Dead data — the socket matrices are never read

`grep -rn "matrix_basis" scripts/` returns **nothing**. `_hang`
(`vc_nva_dresser.gd:427-470`) reads only `entry["glb"]` and `_socket_bone` reads only
`socket["bone"]`. The prop is added as a direct child of the `BoneAttachment3D` with no
transform of its own.

This matters for the fix: correcting `socket_headgear.matrix_basis` in the JSON alone
would change nothing, because no code consumes it. Either the code must start honouring it
or the correction must be baked into the GLBs.

## 7. Mismatch against the ART LOG

`production/ART_Track_Log.md` lines 906-1030 (2026-08-08 entries) claim the library was
"Exported, all bone-local to their socket bone, clean names, **verified by read-back**"
(:946), and that the gate "reports zero script errors project-wide" (:978) and "Every
manifest GLB path resolves" (:1030).

All three claims are true and all three are irrelevant to this defect:

* "verified by read-back" verified tri/vert counts and mesh names — the log's own tables at
  :906-910 are counts. It did not verify the **frame**. `pack_satchel` at x=5.265 proves
  "all bone-local" was never measured.
* "zero script errors" and "every path resolves" are existence checks. A hat hung in the
  wrong orientation throws nothing and logs nothing.
* The fit verification quoted in the manifest — *"0/26 skull verts penetrating, brim at
  brow"* — was measured **in Blender against the fitted pose**, before/independent of the
  bake to bone-local. Verified in Blender is not verified in Godot. This is the same
  verification-debt class already on the ledger from the 2026-08-11 ship audit.

The log does not overstate that the work happened; it overstates what was checked. The
gap is: **no probe ever put a library hat on a Godot skeleton and measured where it landed.**

## 8. Minimum fix

Cheapest correct fix, in order of preference:

1. **Re-bake the 12 headgear GLBs** (and the 6 broken packs) so their vertices really are in
   the socket bone's glTF-local frame — apply `Rx(+90°)`, `(x,y,z) → (x, −z, y)`, to the
   headgear meshes, and subtract the line-up offsets from the packs. This preserves the
   "identity socket, no transform in code" architecture the file is built around, and fixes
   packs and hats in one pass. Blender work, so it goes through an agent per standing law.
2. **Or** teach `_hang` to read `matrix_basis` and set `att.transform` from it, then write
   the real matrices into `nva_vc_gear.json`. One code change, one data change, no Blender.
   Does not fix the packs whose *translation* is metres off, unless per-prop matrices are
   authored.

Do NOT "fix" this by deleting the rehang — the library is the whole variety system.

**Add a gate either way:** a headless probe that instances each library prop on the real
character skeleton and asserts the prop's AABB overlaps the welded reference mesh's AABB.
That single assert would have caught the hats, the packs, and the stray PSXRigs.

## 9. Confidence and what I did not do

High confidence on the frame mismatch: it rests on measured vertex bounds from the shipped
files, the transform math through the glTF node hierarchy, and the US helmet counterexample
that carries exactly the rotation the NVA/VC manifest denies needing. It does **not** rest
on running the game.

Per constraints I did not open Blender, edit any asset, edit any code, or launch Godot. The
per-variant table in §5 is a prediction derived from `HEADGEAR` + `contains()` matching; it
is the recommended confirmation step, not an observation.
