# P1 Viewmodel-FOV Shader — Lead Programmer / Godot Specialist Analysis
**Date:** 2026-07-26 · Godot 4.7 Forward+ (reverse-Z since 4.3) · READ FROM CODE, pointers inline.
**Scope:** implementation design for replacing the `_lens_ratio` mesh-scale hack (`scripts/player/weapon_holder.gd:973-978`, applied `:919-920`) with a projection-override + depth-squash vertex shader. No edits made.

---

## 0. Measured facts (the ground this design stands on)

| Fact | Pointer |
|---|---|
| Viewmodel GLBs import with **embedded default materials** — `materials/extract=0`, empty `_subresources` — i.e. plain `StandardMaterial3D` per glTF surface, textures embedded/beside the GLB | `assets/player/viewmodels/m16_fp.glb.import:39-42` |
| **No PSX shader exists on viewmodels.** The project's "PSX" is NEAREST texture filtering applied to *characters only* (`model_actor.gd:288-300`, `grunt_dresser.gd:162`). Viewmodels today render **bilinear stock PBR**. There is no vertex-snapping shader anywhere in the repo (checked all 7 `.gdshader` files: terrain/water/sway/suppression only) | `Glob **/*.gdshader`; `scripts/visuals/model_actor.gd:290` |
| Viewmodel `.tscn`s are 2 nodes: root + GLB instance at `Transform3D(-1,0,0, 0,1,0, 0,0,-1, 0,-1.81,0)` (180° yaw + −1.81 Y). **MuzzlePoint / sight markers / AnimationPlayer live inside the GLB** | `scenes/weapons/m16a1_arms_viewmodel.tscn:7-8` |
| Player camera: FOV 75, **near = 0.01** (someone already fought near-clipping with the near plane), WeaponHolder identity child of camera | `scenes/player/player.tscn:25-29` |
| ADS lerps `camera.fov` from 75 to per-gun `ads_fov` (ADR-004) | `weapon_holder.gd:248-259` |
| Under the current hack the gun is a world object, so it **magnifies with the ADS zoom**. Lens ratio is computed from BASE_FOV 75 even while ADS camera is at 58-62 | `weapon_holder.gd:919, 976` |
| Hip fire: rounds + flash + noise all use the **world-space MuzzlePoint**; ADS (>0.6) fire snaps origin to the camera | `weapon_holder.gd:468-473, 489-492` |
| Tracer **is** the bullet (`weapon_data.gd:59-61`), spawned at `muzzle_pos` via `CombatManager.bullets.fire` | `weapon_holder.gd:516-519` |
| Warhead hide swaps **surface override materials** (invisible mat ↔ `null`) and scans **mesh surface material names** | `weapon_holder.gd:282-325` |
| Main world DirectionalLight has `shadow_enabled = false` | `scripts/levels/game_world.gd:48-52` |
| Import generates shadow meshes + LODs for the GLBs | `m16_fp.glb.import:27-28` |
| Depth fog IS enabled in the game world | `scripts/levels/game_world.gd:74` |
| Per-gun `viewmodel_fov` is already authored: 55 (m1911) … 66 (m60/rpg); m16a1/m14 ride the 60.0 default | `data/weapons/*.tres`, `weapon_data.gd:38` |
| `viewmodel_scale` is a dead field: declared `weapon_data.gd:95`, displayed `viewmodel_editor.gd:638`, in 6 .tres, **applied nowhere** | grep `viewmodel_scale` |
| External consumers of `weapon_model` only toggle `.visible` (binos/handset/seated) | `player.gd:401-414, 1072-1073` |
| Grenade/medkit viewmodels use a separate hardcoded `scale = 0.03` path, NOT `_lens_ratio` | `grenade_handler.gd:41` |

---

## 1. Materials: mechanism to get the shader onto the gun

Because no PSX shader exists on viewmodels, we are NOT merging into anything — we are replacing a stock imported `StandardMaterial3D` with one hand-written spatial shader that copies its albedo. Three mechanisms considered:

- **(A) Load-time conversion in a shared helper (RECOMMENDED).** After `instantiate()`, walk `MeshInstance3D`s, build a `ShaderMaterial` per surface copying `albedo_color/albedo_texture/roughness/metallic` from the imported `BaseMaterial3D`, set it as `set_surface_override_material`. One code path, called by BOTH `weapon_holder._load_weapon_model` and the bench — WYSIWYG becomes structural. No `.import` churn across 12 GLBs, survives every future re-export from the Blender pipeline untouched, and the mesh's embedded materials stay intact so `_scan_warhead`'s name matching (`weapon_holder.gd:308-309`) keeps working.
- **(B) Import-time replacement** (`import_script/path` or `materials/extract=1` + edits). Rejected: 12 `.import` files to maintain, extracted materials drift per-GLB (exactly the RC2 sprawl disease), and the FP pipeline re-exports these GLBs constantly — every re-export re-runs a hidden script whose failure mode is silent.
- **(C) Hand-set overrides in the 13 `.tscn`s.** Rejected: hand-maintained per-surface, the disease P1 exists to cure.

### Code sketch — new `scripts/weapons/viewmodel_lens.gd` (static, no node)

```gdscript
class_name ViewmodelLens

const SHADER: Shader = preload("res://assets/shaders/viewmodel_lens.gdshader")

## Convert every mesh surface to the lens shader. Returns the converted
## MeshInstance3Ds so the caller can drive the per-frame fov instance uniform.
## Also returns, per [mi, surface], the override material — _refresh_warhead
## must restore THIS, never null.
static func apply(model: Node3D, wd: WeaponData) -> Array[MeshInstance3D]:
    var converted: Array[MeshInstance3D] = []
    for c in model.find_children("*", "MeshInstance3D", true):
        var mi := c as MeshInstance3D
        if mi == null or mi.mesh == null:
            continue
        mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        for s in range(mi.mesh.get_surface_count()):
            var src: BaseMaterial3D = mi.mesh.surface_get_material(s) as BaseMaterial3D
            var m := ShaderMaterial.new()
            m.shader = SHADER
            if src != null:
                m.resource_name = src.resource_name   # warhead scan keys off the NAME
                m.set_shader_parameter("albedo_tex", src.albedo_texture)
                m.set_shader_parameter("albedo_col", src.albedo_color)
                m.set_shader_parameter("roughness_val", src.roughness)
                m.set_shader_parameter("metallic_val", src.metallic)
            mi.set_surface_override_material(s, m)
        mi.set_instance_shader_parameter("viewmodel_fov", wd.viewmodel_fov)
        converted.append(mi)
    return converted
```

Cost: runs once per weapon switch over ~5-15 meshes. No caching needed (bench F5 uses `CACHE_MODE_IGNORE` and re-instantiates anyway, `viewmodel_editor.gd:274`).

**PSX filtering decision for the Arbiter:** the shader's sampler hint picks the filter. Today viewmodels are bilinear; project doctrine everywhere else is NEAREST. I recommend authoring the uniform with `filter_nearest_mipmap` (the PSX-correct choice) **but flag it as a visible look change for Caleb's eyes** — rule #1 says his eyes judge. Shipping `filter_linear_mipmap` first makes P1 a pure refactor; one-line flip later.

---

## 2. The shader — exact core, reverse-Z correct

`assets/shaders/viewmodel_lens.gdshader`:

```glsl
shader_type spatial;
render_mode cull_back, depth_draw_opaque;

uniform sampler2D albedo_tex : source_color, hint_default_white, filter_linear_mipmap;
uniform vec4 albedo_col : source_color = vec4(1.0);
uniform float roughness_val : hint_range(0.0, 1.0) = 1.0;
uniform float metallic_val : hint_range(0.0, 1.0) = 0.0;
instance uniform float viewmodel_fov = 60.0;
const float DEPTH_SQUASH = 0.9;

void vertex() {
    mat4 p = PROJECTION_MATRIX;
    // Perspective passes only: p[3][3] != 0 means an orthographic (directional-
    // shadow / depth) projection, which must pass through untouched.
    if (p[3][3] == 0.0) {
        float aspect = p[1][1] / p[0][0];
        float cotan = 1.0 / tan(radians(viewmodel_fov) * 0.5);
        p[1][1] = cotan;
        p[0][0] = cotan / aspect;
    }
    POSITION = p * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
    // Reverse-Z (4.3+): near plane is depth 1 = POSITION.w after divide. Squash
    // TOWARD w so the gun always wins the depth test. Pre-4.3 tutorials mix
    // toward 0.0 — that buries the gun IN the world on 4.7.
    POSITION.z = mix(POSITION.z, POSITION.w, DEPTH_SQUASH);
}

void fragment() {
    vec4 tex = texture(albedo_tex, UV);
    ALBEDO = tex.rgb * albedo_col.rgb * COLOR.rgb;
    ROUGHNESS = roughness_val;
    METALLIC = metallic_val;
}
```

Why each choice:
- **Derive aspect and keep every other row of `PROJECTION_MATRIX`** (near/far/reverse-Z rows come from the real camera): no world-fov uniform to keep in sync, and reverse-Z is inherited, not reimplemented.
- **`instance uniform` for fov**: one shared shader, per-gun value via `set_instance_shader_parameter` on each `MeshInstance3D` — Forward+ supports instance uniforms (the ADR'd renderer, `recongame-forward-plus-decree`). This is also what lets ADS drive it per-frame with zero material duplication.
- **Factor = 0.9** (the community-standard majikayogames value): keeps 10% of the true depth range, so the gun's ~1.2 m of internal geometry still self-occludes correctly (bolt behind receiver), while its nearest squashed depth beats any world surface farther than a few cm from the eye. Reverse-Z float depth has its best precision exactly where we squash to, so no self-z-fighting at 0.9. Do not chase 0.99+ — it buys nothing and eats self-occlusion precision.
- **`p[3][3] == 0.0` guard**: directional-shadow and any ortho depth pass see an unmodified projection. Belt-and-braces only, because:
- **Shadows: turn them OFF at conversion** (`cast_shadow = OFF` in the sketch). Reasons measured: (1) the main world sun has `shadow_enabled = false` anyway (`game_world.gd:52`); (2) a depth-squashed mesh casts from its TRUE world pose, so under any future shadowed light the gun — whose stock overlaps the player capsule — would shadow-stripe the camera; (3) omni/spot shadow passes are perspective, so the ortho guard does NOT protect them. The import's generated shadow meshes become irrelevant once cast_shadow is off.
- **Depth prepass (Forward+)**: the prepass runs this same vertex shader, so prepass depth == color-pass depth. Opaque + deterministic vertex output = no interaction. Do NOT add `depth_test_disabled`; the squash already guarantees the win and keeps gun self-occlusion.
- **Fog**: Godot spatial fog is computed from view-space `VERTEX`, which we never touch — the gun fogs by its TRUE distance (centimeters → no fog). Correct.
- **Lighting**: writing `POSITION` does not alter `VERTEX`/`NORMAL`, so the real-scale gun lights from its true world position. This is strictly better than today, where a 1.33×-scaled mesh lights at fake scale.
- **Skinned meshes**: Godot 4 applies skeleton deform before the vertex stage; custom vertex shaders on skinned GLB rigs are standard. The arms rig animates unchanged.
- **Screen-space effects caveat**: written depth is squashed, so anything reading the depth buffer (SSAO/SSR/DOF) sees the gun at the near plane. Repo has none of these (grep: fog only) — note for the future, not a cost today.

### ADS: should viewmodel FOV lerp? — Yes, derived, not hand-tuned

Today the gun magnifies with the ADS zoom because it renders through the zooming camera. A fixed vm projection would silently change that feel (sights would stop growing during ADS — every ADS pose retune would fight it). Reproduce the current magnification behavior *exactly* by deriving the effective vm fov from the live camera each frame in `_update_ads`:

```gdscript
var zoom: float = tan(deg_to_rad(camera.fov) * 0.5) / tan(deg_to_rad(BASE_FOV) * 0.5)
var vm_eff: float = rad_to_deg(2.0 * atan(tan(deg_to_rad(current_weapon.viewmodel_fov) * 0.5) * zoom))
for mi in _converted_meshes:
    mi.set_instance_shader_parameter("viewmodel_fov", vm_eff)
```

At hip (`camera.fov == 75`) this is exactly `viewmodel_fov`; at full ADS the gun magnifies by the same ratio the world does. One formula, no second knob, ADR-004 untouched (`camera.fov` code at `weapon_holder.gd:255-259` stays byte-identical). Guard the loop with `ads_transition` actually changing; setting an instance uniform on ~10 meshes is nanoseconds regardless.

---

## 3. What breaks when `_lens_ratio` dies — full consumer audit

Every hit of `_lens_ratio|weapon_model.scale|MuzzlePoint|viewmodel_fov` in the repo:

| Consumer | Pointer | Verdict |
|---|---|---|
| Scale application at load | `weapon_holder.gd:919-920` | DELETE. Replaced by `ViewmodelLens.apply()` |
| `_lens_ratio` itself | `weapon_holder.gd:973-978` | The tan-ratio survives ONLY as the apparent-muzzle math (below). The clamp [0.6, 2.2] dies with it |
| Bench copy of the hack | `viewmodel_editor.gd:283` + WYSIWYG comment `:279-282` | Same helper call (§5) |
| `_get_muzzle_position` | `weapon_holder.gd:983-991` | Marker's world position stays TRUE (shader moves pixels, not nodes). Fallback `basis.z * -0.5` at `:989` currently inherits the 1.33× scale — after P1 it becomes an honest 0.5 m. Fine |
| **Tracer/flash spawn (the real break)** | `weapon_holder.gd:468-473, 489-519` | See below |
| Noise + suppression origins | `weapon_holder.gd:471, 483` | Keep the TRUE muzzle — these are gameplay-space events; a ±8 cm visual correction has no business in them |
| Sway/bob/punch/dips | `weapon_holder.gd:833-856` | Amplitudes (sway 0.014, sprint dip 0.08, fire-menu dip 0.30, punch 0.05) were tuned against a model rendered at world FOV. Under vm FOV 60 they read ~1.33× larger on screen (screen motion of a holder-space offset scales by tan(75/2)/tan(vm/2)). Either multiply the positional offsets by `tan(vm_eff/2)/tan(37.5°)` to preserve authored feel, or fold into the retune pass. Recommend the multiplier — it makes feel constants fov-invariant forever |
| ADS pose lerp | `weapon_holder.gd:817-818` | Mechanism unchanged; every `.tres` pose is invalidated (known P1 cost — research says only M14 fully tuned; m16a1 also carries real tuned values, `m16a1.tres:33-38`, so budget TWO retunes plus stubs) |
| `_auto_align_ads_sights` basis math | `viewmodel_editor.gd:503-526` | Currently operates on a SCALED basis (comment at `:518` even apologizes for it). With scale gone the math simplifies and gets *more* correct. V-key path unaffected |
| Warhead hide/restore | `weapon_holder.gd:314-325` | **LANDMINE:** restore path sets override to `null`, which after P1 reveals the raw imported material — a world-projection warhead popping out of a vm-projection tube at the wrong size/place. Fix in the same change: store the converted override per `[mi, surface]` in `_scan_warhead` (which now runs AFTER conversion) and restore THAT instead of null |
| `viewmodel_scale` dead field | `weapon_data.gd:95`, `viewmodel_editor.gd:638`, 6 .tres | DELETE with P1 (RC3 closure; fossil law — same change, not later) |
| `dump_viewmodels.gd:23`, `test_viewmodel_contract.gd:48` | tools/tests | Read MuzzlePoint by name only — unaffected |
| Grenade/medkit `0.03` scale | `grenade_handler.gd:41` | NOT `_lens_ratio` — a legacy-asset scale. Out of P1 scope; note it so nobody "fixes" it in passing |

### The tracer/flash problem, concretely

The shader renders the barrel tip as if through the vm projection; the tracer and flash are world objects rendered through the world projection. Same world point, two screen positions → the streak visibly detaches from the barrel (for vm 60 vs world 75 the lateral gap is `1 − tan(37.5°)/tan(30°)` ≈ 25% of the muzzle's screen offset from center — obvious on an M60 hanging right of screen).

Fix: spawn *visuals* at the **apparent muzzle** — the world point whose world-projection screen position equals the vm-projection screen position of the true muzzle. Because the squash only touches depth, the mapping is a pure lateral scale in view space, and it is the old lens ratio reborn:

```gdscript
## Where the muzzle APPEARS on screen: view-space x/y scaled by the lens ratio.
func _apparent_muzzle_world(true_muzzle: Vector3, vm_eff: float) -> Vector3:
    var v: Vector3 = camera.global_transform.affine_inverse() * true_muzzle
    var r: float = tan(deg_to_rad(camera.fov) * 0.5) / tan(deg_to_rad(vm_eff) * 0.5)
    return camera.global_transform * Vector3(v.x * r, v.y * r, v.z)
```

Use it for: `GunFX.muzzle_flash` (`:473`), hip tracer/bullet spawn (`:518`), rocket spawn (`:505` — the rocket is a visible world projectile and must leave the on-screen tube). The hip round already converges onto the camera-ray aim point (`:489`), so moving its origin ~8 cm is gameplay-neutral by construction; ADS fire already spawns from the camera (`:490-492`) and needs nothing. Keep TRUE muzzle for NoiseBus and suppression (`:471, 483`).

---

## 4. Can the pitch hack retire? — Yes, with one measured caveat

The hack (`PITCH_OFFSET_*` consts `:152-156`, applied `:820-831`) lifts the gun when pitching below −38° so its world-space volume stops intersecting the terrain and getting depth-clipped. Depth squash removes that entire failure class: the gun wins the depth test against the floor no matter the pitch. **Delete the consts and the block in the same change (fossil law).**

The caveat is the OTHER clip: vertices with view-space z ≥ 0 (behind the eye plane, w ≤ 0) are frustum-clipped regardless of any depth trick — no shader can render them. Evidence it's a live concern: camera near is already 0.01 (`player.tscn:27`), and `m16a1.tres:36` has `ads_position.z = +0.08` — the model ROOT sits 8 cm behind the camera plane at full ADS, with the stock extending further back. Today those verts silently near-clip (invisible, off-frustum bottom of screen); post-P1 they still clip, and with real-scale models and retuned poses the stock may cross the plane on screen. Failure looks like triangle shards flickering at the screen edge when the stock crosses w=0.

Mitigation, in order: (1) the retune itself — pose the gun so all geometry stays in front (what every FPS does); (2) a bench warning (§5) that measures it instead of guessing; (3) if a pose demands it, per-gun tiny forward offset — NOT a resurrection of the global pitch hack.

---

## 5. The bench — structural WYSIWYG

Changes to `scripts/weapons/viewmodel_editor.gd`:
1. `:283` → `ViewmodelLens.apply(weapon_model, current_weapon)` — the SAME helper, deleting the duplicated math and the hand-maintained "WYSIWYG CONTRACT" comment block (`:279-282`). The contract stops being discipline and becomes a shared symbol.
2. ADS mode must drive the same derived `vm_eff` formula when it sets `camera.fov = ads_fov` (`:683-689`), or the bench previews ADS with hip magnification.
3. Bore laser near-end (`_bore_ray`, `:382-393`) draws from the TRUE muzzle — post-P1 it would visibly detach from the rendered barrel exactly like tracers. Draw the laser's near end from the same `_apparent_muzzle_world` helper (put it in `ViewmodelLens` too). The board-impact math stays in true world space — that is where rounds actually go.
4. Delete the `viewmodel_scale` HUD line (`:638`) with the field.
5. **New warning probe:** each `_apply_edit`, compute the model's camera-space AABB (reuse `_model_aabb`, `:553`) and flash a `! GEOMETRY BEHIND EYE — will shard-clip` warning when `max_z > -0.01`. This turns §4's caveat from a playtest surprise into a bench number, per the observation-instrument lesson: every rig gets a probe that exercises it.
6. Suite: `test_viewmodel_contract.gd` gains one assert — every `*_arms_viewmodel.tscn` mesh surface, after `ViewmodelLens.apply`, has a ShaderMaterial override whose shader is `viewmodel_lens.gdshader`, and `cast_shadow == OFF`. That is the ratchet that stops the next gun from shipping half-converted.

---

## 6. Ordered risk list

1. **All tuned poses invalidated** (m14 + m16a1 real, 4 stubs) — known, budgeted; bench-first build order makes retuning same-day work.
2. **Warhead restore-to-null resurrects the unshaded material** (`weapon_holder.gd:324-325`) — must land in the same change or the RPG-2/LAW visibly break on reload.
3. **Behind-eye geometry shard-clipping** on retuned real-scale poses (esp. long guns at ADS; `m16a1.tres` ADS z is already +0.08) — bench warning (§5.5) makes it measurable; pose forward if flagged.
4. **Sway/punch/dip amplitudes read ~1.33× bigger** — apply the fov-invariance multiplier or accept a feel pass.
5. **Tracer/flash detach from the rendered barrel** without the apparent-muzzle correction — must ship WITH the shader, not after.
6. **Shadow pass corruption if cast_shadow stays on** under any future shadowed light (ortho guard does not cover omni/spot) — conversion forces OFF; suite asserts it.
7. **Material fidelity drift**: hand shader copies albedo/roughness/metallic only; any future glTF material feature (emission, alpha) silently drops until added. Viewmodel guns today are plain textured opaque — acceptable, and the bench shows the truth instantly.
8. **Filter choice is a visible look change if we flip to NEAREST** — ship linear (today's look), offer the PSX flip as a one-line decision for Caleb's eyes.
9. Screen-depth readers (SSAO/SSR/DOF) would see the gun at the near plane — none exist in the repo today; recorded for the future.

## 7. Build order (risk-gated)

1. Shader + `ViewmodelLens` helper + weapon_holder conversion + warhead-restore fix + apparent-muzzle spawn (one change, one probe).
2. Bench: helper call, ADS vm_eff, laser origin, behind-eye warning, `viewmodel_scale` deletion (weapon_data + HUD + .tres lines).
3. Delete pitch hack consts/block + `_lens_ratio` + the `:913-918` comment block (fossil law, same PR as the thing that replaces them).
4. Retune m14 + m16a1 in the bench; stub guns keep stubs until P6.
5. Suite ratchet (§5.6).

**No blocker found.** The one thing that would have made P1 wrong — a PSX material pipeline the shader must merge with — measurably does not exist on viewmodels (`m16_fp.glb.import:39`, no repo shader touches them). The renderer is Forward+ by decree, which is exactly the pipeline where instance uniforms and the depth-prepass behavior above hold.
