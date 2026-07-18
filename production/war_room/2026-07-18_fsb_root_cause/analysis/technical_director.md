# TECHNICAL DIRECTOR — FSB root cause, asset/export pipeline lens

Independent verification, 2026-07-18. Method: parsed the GLB binary myself (12-byte header,
JSON chunk 310,888 B) — no Godot, no Blender, no reliance on the briefing's probes.
Artifact: `C:\Users\caleb\RECONgame\assets\building models\structures\firebase\fsb_main.glb`
(8,108,644 B, mtime 7/18 17:17, generator "Khronos glTF Blender I/O v5.0.21", 691 nodes,
203 unique meshes, 97 materials, 9 embedded images).

## 1. CAUSE 2 verified — and localized to the byte

**Structure fact that decides everything: the scene is FLAT. All 691 nodes are scene roots.
Zero parenting, zero `matrix` nodes.** There is no parent empty carrying the offset. The +Y
lives in each node's own `translation`, with a minority of meshes carrying an additional
vertex-baked component (pivot far from geometry).

### Gate cluster (world min-y 4.79–12.99)
| node | translation Y | mesh-local vtx minY | world minY |
|---|---|---|---|
| `gate_post_left_001-col` | **4.797441482543945** | 0.000 | 4.797 |
| `gate_post_right_001-col` | **4.797441482543945** | 0.000 | 4.797 |
| `gate_left_001-col` | 6.047441 | −1.250 | 4.797 |
| `gate_right_001-col` | 6.047441 | −1.250 | 4.797 |
| `claymore_line_001-col` | 4.868283 | −0.076 | 4.792 |
| `watchtower_1_001_001-col` | 3.954084 | **+0.970 (baked)** | 4.924 |
| `sandbag_heavy_039-col` | 5.366562 | −58.717 (pivot 58.7 m off; rotation-composed) | 4.826 |
| `mg_nest_1_009_001-col` | 13.104361 | 0.000 | 12.989 — **tower-top MG, elevation is intra-chunk design, NOT an error** |
| `mg_nest_1_001-col` | 6.217669 | (baked −100.03 pivot) | 6.102 |

### The smoking gun — the markers carry the same Y
The chunk-kit marker empties are exported in the GLB and sit at **exactly** the cluster bases:
- `SOCKET_A_001`, `SOCKET_B_001`, `gate_fence_001` (empty): Y = **4.797441482543945** — bit-identical to the gate posts.
- `FOOTPRINT_*` empties: distinct Y = {0.3323, 0.3873, 0.8678, 1.9525, **2.6941**} — 2.6941 is bit-identical to the hootch row; 0.3323 to the wire ring; `USSupplyDepot_*` markers 1.9525.
- `enter/exit_trigger_zone_001` at 6.047 (= gate base + 1.25), `mg_fire_point` 5.82, `tower_los_point` 13.42 — **gameplay markers float too**; anything reading marker transforms from the imported scene inherits the defect.

Mechanism proven: **chunk realization placed content at marker world-Y, and the planning
scene's markers were authored on non-flat reference terrain.** Base heights present in this
export: 0.3323 / 0.3873 / 0.8678 / 1.9525 / 2.6941 / 4.7974 (+ tower-top offsets). The
"y=0 = ground under every chunk" contract was never enforced at realize time. The global
AABB min-y = −3e−07 ≈ 0 only because ONE mesh (`mortar_pit_002-col`, vertex-recessed pit)
happens to touch 0 — which is precisely why the coarse asset probe called the GLB "HEALTHY".

### Hootch cluster
`aid_station_003-col`, `Hootch_006-col`, `Hootch_010-col`: translation Y = **2.694087505**,
vtx minY 0.000 → world 2.694. `tent_003-col`: translation Y = **−1.106** with **+18.918
baked in vertices** → world 2.695. Same cluster offset, opposite storage.

### Crate cluster (~42, 97)
125 nodes. Base = translation Y **2.144223** (posts/pallet contact, vtx minY −0.500 →
world 2.144); crates at 2.394; slat rows stepped 2.294/2.464/2.634/2.904. The stack's
internal structure is correct — the whole group is uniformly +2.144 in translations.

### Why "zero the translations" is the WRONG surgical instruction
37 mesh nodes have |vertex minY| > 2 (sandbag_heavy shared mesh pivot −58.72; mg_nest
meshes −100.03/−63.10; tent +18.92). Zeroing translation-Y on those teleports them tens of
meters. The correct operation is **world-space**: per cluster, apply ΔY = −(cluster base):
gate group **−4.797441**, hootch group **−2.694088**, crate group **−2.144223**, wire/ring
family **−0.332279** — or equivalently floor-snap each chunk GROUP (see §2). Never per-mesh
(would pancake the 13 m tower MG, crate stacks, gate panels at base+1.25).

## 2. Correct pipeline fix (judgment)

**Both ends, one pass, no hand-patching:**
1. **Source fix — re-realize from markers with Y-grounding.** In the master planning scene,
   flatten all placement markers to Y = 0 (the flat-plateau contract makes marker Y
   meaningless data; it is currently sampled ancient terrain). Realization then produces
   grounded chunks by construction, forever.
2. **Export-script grounding pass, per CHUNK GROUP** — for each realized chunk group,
   compute depsgraph-evaluated world vertex min-y across the whole group and translate the
   group by −min (object-space verification law applies: evaluate meshes, never trust the
   AABB of an un-updated matrix). This is the belt to (1)'s suspenders and the only method
   that also absorbs vertex-baked offsets (tent, sandbag pivots) without caring where they
   are stored. **It must then become an assertion**: after grounding, export FAILS if any
   chunk group min-y ∉ [−0.05, +0.05]. A silent auto-fixer with no assert would become a
   load-bearing fossil that hides upstream regressions.
3. Hand-moving 658 objects in the assembly: rejected — unauditable, doesn't fix the
   generator, next realization re-breaks it.

**Named exception:** `mortar_pit` is vertex-recessed (pit floor −0.332 below its own base).
Today the +0.332 lift accidentally makes the pit floor flush at 0; grounding it by marker
or by min-vertex sinks the pit interior below the terrain plateau (terrain will swallow it).
The grounding pass needs a per-chunk `contact_offset` attribute (default 0; mortar pit uses
rim contact). Verify pits by eye after re-export.
Godot side: `diag_fsb_seat` MODEL-SEAT stays as the independent ratchet. Law upheld: no GLB
byte-patching, no runtime snapping.

## 3. Import sanity (`fsb_main.glb.import`)

Verdict: **parameters are sane — no change required.**
- `light_baking=1` (Static, not Static Lightmaps) → `lightmap_texel_size=0.2` is **inert**
  (only read at mode 2); no UV2 unwrap cost across 658 instances. Correct for this asset.
- `generate_lods=true` / `create_shadow_meshes=true`: fine — 203 unique meshes, the 434 wire
  cards share ONE mesh resource (`bwire_card.001`), so LOD build cost is trivial.
- `embedded_image_handling=1` (Extract): working as designed. 9 embedded images ↔ 9
  extracted `fsb_main_*.png/jpg` (dated 7/17 22:38). The 7/18 reimport (17:24) correctly
  reused them — Godot does not overwrite existing extracted textures. **One real, bounded
  risk:** if a future re-export changes a texture's pixels under the same name, the stale
  extracted file silently wins. Harmless for the upcoming geometry-only re-export; if
  textures ever change, delete the `fsb_main_*` extracted images first, then reimport.
- The "gray untextured pieces" are a SOURCE issue, not import: **65 of 97 materials in the
  GLB have no baseColorTexture at all** (matches the 488/664 textured-surface count).
  Separate art bead; not this decree.
- Noted, not a defect: 616 of 661 mesh nodes carry non-uniform scale (slats/crates authored
  as scaled primitives). Godot handles it; just never "apply scale" per-object in Blender
  cleanups without accounting for the 203 shared meshes.

## 4. The 0.3–1.0 m band (460 meshes) — verdict: SYSTEMATIC LIFT, not art margin

All 434 `bwire_card_*` nodes: translation Y = **0.3322788178920746 exactly** (448 nodes
total sit at this exact value, footprint markers included); the shared card mesh's local
vertex range is **[0.000, 0.930]** — bottom edge exactly at local 0, zero art margin.
World min-y = 0.332 for every card. The perimeter wire floats a uniform **33 cm** off the
deck — knee-height daylight under every wire run, fully visible. Same defect family as the
gate (smallest of the six marker heights), and marker-Y-grounding erases all 448 in the
same stroke. The rest of the band (sandbag_heavy ring at 0.332 via +0.873 translation with
−0.541 net baked, Hootch_008/012, etc.) is the same 0.332 family.

## Bottom line
CAUSE 2 confirmed and mechanized: flat 691-root export; offsets live in per-node
translations equal to marker heights {0.332, 0.387, 0.868, 1.953, 2.694, 4.797}; a minority
of meshes store part of it in vertices. Fix at realization (markers → Y=0) plus a per-chunk
floor-snap-and-assert in the export script. Import file is innocent. The wire band is a
real 33 cm float, not margin.
