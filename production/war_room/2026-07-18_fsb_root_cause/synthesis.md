# DECREE — FSB "three fixes didn't take": two diggers under one symptom
2026-07-18 · Arbiter: recon-overseer · Council: systems-designer, technical-director, devils-advocate
(full analyses in ./analysis/ — all three read code, not the plan)

## Root cause (probe-proven, named in plain language)
The firebase placement path is SINGULAR and CORRECT (one reference to the asset in the whole
codebase; origin = terrain = seat; spawn delta 0.00). The recurring wound has two independent
causes, and every prior fix targeted neither:

**CAUSE 1 — build-time craters dig through the base after placement, every build.**
`plan_patrol_world` rings "first-sign" craters 170–280m from the GATE; the gate sits ON the wire
ring, so one quadrant points across the base interior. At 47225 a LARGE_EXPLOSION sign lands at
(950,712) INSIDE the wire (terrain dug −18.6m; wire arc hangs 9–17m in the air); three more signs
chew the ring edge with ~60m radii and +7m rims. `_passable_near` has NO firebase keep-out and
CANNOT have a passability-based one: at plan time the base does not exist yet — the keep-out must
be geometric. Five call sites can place craters/villages/camps/patrol-anchors/enemy-spawns inside
the wire (systems-designer table; devils-advocate confirmed line 504 spawns VC in-base on minute
one). Craters today dig 16.8–27.3m deep (profiles are normalized ×height_scale 350 — authored
insane even at the old 280 scale; bead, not this wave).

**CAUSE 2 — the export realizes chunks at marker world-Y from ancient non-flat terrain.**
The GLB is flat; per-node translations carry six base heights {0.332, 0.387, 0.868, 1.953, 2.694,
4.797}. The GATE cluster (posts, panels, sandbags, wire, claymore line, watchtower) floats at
+4.797m — bit-identical on SOCKET_A/B_001 — 22m from the player spawn: a guard tower frame and
gate panels hanging ~3m above the player's head over flat sand. THAT is the screenshot's
foreground. The whole 434-card wire ring floats a systematic +0.332m. Hootch row +2.694, crate
group +2.144. 37 meshes carry vertex-baked offsets → the fix is per-chunk-group world translate,
NEVER per-node translation zeroing and NEVER per-mesh snapping (tower-top MG at 13m is design).
Gameplay markers (enter/exit_trigger_zone at 6.05, mg_fire_point 5.82) float with their chunks.

**Why three fixes didn't take:** fix #1 re-pointed the buried model, #2 flattened the plateau,
#3 re-exported the right selection + re-seated the save — all placement-side. The craters re-dug
the ground under the wire on every build, and the re-export faithfully reproduced the assembly's
floating markers. Classic divergent-system signature (the ADR-028 blindspot), plus a faulty
generator upstream of a correct loader.

**Screenshot provenance (honest caveat, DA):** logs rotated; "sparse/pancaked/gray" cannot be
pinned to a run. Sparse+pancaked best fit YESTERDAY'S superseded scatter export; the +4.8m gate
cluster guarantees the CURRENT export still greets the player with floating gray gate hardware.
"Gray" is real regardless: 65/97 materials in the SOURCE carry no baseColorTexture (art-side bead;
import is sane and unchanged). The finalized probe prints a near-spawn floating-mesh census to
settle which cause owns any future frame.

## The decree
1. **Keep-out becomes default-on law, one authority.** `MissionGenerator` holds a static fsb
   keep-out Rect2 set from `fsb_center` at plan AND build entry; `_passable_near` honors it BY
   DEFAULT (callers pass only extra grow). Failure returns Vector3.ZERO sentinel (never the
   in-rect origin). Handling: signs DROP (backstop) · villages/camps RETRY then deterministic
   outward projection (never drop — pacing contract, `villages2[pi % size]`) · anchors/ambient
   spawns SKIP. Grow values: craters = derived from DamageSystem LARGE profile × max intensity ×
   cell size + 10 (never a bare 70) · villages/camps = FSB_SITE_CLEARANCE (40, parity with
   find_site) · anchors/spawns = 0.
2. **Signs aim at the walk-out, not the compass rose** (DA alternative (a), adopted): the four
   sign sectors span the gate_out OUTWARD half-plane (out_angle ±90°, sectors at ±22.5°/±67.5°).
   Density preserved where the player actually walks; the inward "quadrant" was always the
   player's own base. ADR-029 §3 amended in the same change; `test_patrol_world` quadrant
   assertion rewritten to the outward fan + NEW suite assertions: no sign inside keep-out, no
   village/camp center inside keep-out(40).
3. **Probe = two verdicts, signature-locked ratchet** (DA form): CRATER-CLEAR must pass today.
   MODEL-SEAT passes printing KNOWN-BAD while the defect matches the recorded signature (bases
   4.797/2.694/2.144/0.332 ±0.15); FAILS on drift OR on unexpected fix (forcing promotion to hard
   assert in the same commit). Probe also asserts FSB_HALF/AABB-center against the loaded GLB so a
   re-export cannot silently invalidate the keep-out rect or clear discs.
4. **Export fix at the source (TD prescription), pipeline versioned:** `tools/export_fsb_main.py`
   — realize copies of ASSEMBLY_fsb_battery (Caleb's file untouched, unsaved), then per
   chunk-GROUP depsgraph-evaluated floor-snap DOWNWARD ONLY (group min-y > +0.05 → translate by
   −min; dug-ins ≤ +0.05 untouched — this sidesteps the mortar-pit recess exception), assert every
   group min-y ∈ [−1.5, +0.35] or the export FAILS, normalize `-col` suffix to name end, recenter
   ground-plane XZ, export GLB. Re-import, re-run all probes, promote the ratchet. If any assert
   trips: abort, delete copies, report to the Summoner — no workarounds.
5. **No runtime mesh-snapping, no GLB byte-patching, ever** (upheld from briefing).

## Build-time amendments (what implementation taught the decree)
1. **Auto floor-snap DROPPED for assert-only** (TD's belt-and-suspenders overruled by evidence):
   faithful depsgraph realization showed Caleb's authored data grounds CORRECTLY — the marker
   heights are compensated inside the chunk collections; only the TOOLS were broken (the 17:17
   realizer dropped the compensations; `duplicates_make_real` broke transforms a second way in
   testing). A silent auto-fixer would have masked exactly this tool-bug class. The pipeline
   asserts the contact band and ABORTS instead.
2. **The suite assertion caught a FOURTH leak on its first run**: paddy-anchored villages
   (the anchor-acceptance branch) took positions with no keep-out check — seed 31337 planned a
   village inside the wire. Plugged in the same change.
3. **Genuine source faults found and grounded in-session** (staging, file NOT saved — Summoner
   saves or discards): scene-root supply-row markers INST_hootch_01.003/INST_hootch_00.003/
   INST_aid_station_00.001/INST_tent_00.001 (−2.362) and sandbag row parent
   INST_sandbag_heavy_00.013 (−0.797). These reproduce exactly the floating hootch/sandbag rows
   in the shipped GLB.
4. **The export STOPPED at authorial intent, as the mandate requires**: the live assembly
   (446 markers + scene-root rows, identical on disk since 7/17 22:37) realizes to a 1060×700m
   sprawl — 8 far planning markers (CH_gun0/2/3/c, CH_mort1/2, CH_hooch1/2 at 300–530m out)
   cannot fit the shipped 356×344 core contract. Yesterday's blessed export came from Caleb's
   manual SELECTION of the core, which evidence cannot reconstruct. `tools/export_fsb_main.py`
   is ready: select the core chunks, run it — it refuses oversized selections (extent assert),
   refuses floating chunks (contact-band assert), enforces the SOCKET/`-col`/flat/recenter
   contract, and never touches the authored file.

## Named sacrifices (Law 2)
- No craters inside/against the wire: loses "base built on shelled ground" flavor + crater ponds
  near the spawn. Signs move to the outward fan — the compass-rose promise narrows to the half the
  player walks into.
- Same-seed worlds shift post-patch (draw counts change): pre-patch saves re-seat into a shifted
  world. Dev-acceptable; Caleb should start NEW CAMPAIGN (or delete the autosave) after pulling.
- Keep-out as static state on MissionGenerator: global state, reset at every plan/build entry —
  accepted for default-on safety over parameter purity (the opt-in parameter IS the recurrence).
- Deferring crater re-tune: the AO keeps its 17–27m canyons outside the skirt until the bead runs.

## Beads (THE RECORD)
- P1 crater-scale retune: author depths in METERS ÷ height_scale (pattern at terrain_manager:478);
  targets SMALL 0.6m / MEDIUM 2m / LARGE 6–9m, rim ~15%. Touches shipped feel — Summoner blesses.
- P2 sign-vs-village separation (signs can chew village huts exactly like the wire; build stamps
  villages before digging signs).
- P2 art: 65/97 fsb_main materials carry no baseColorTexture ("gray" reading of untextured kit
  pieces) — Blender material pass on the chunk kit.
- P3 `plan_firebase_main_center` has no hard reject (water/paddy are soft penalties only).
- P3 key-drift fossils: `_patrol_anchors`/`_enemy_anchors` read `firebase_center`/`camp_center`/
  `village_center` — keys that don't exist in the patrol plan (ADR-023 lie-in-the-map; also
  starves NavBaker anchors). Includes design call: spawn keys land in the enemy circuit pool.
- P3 re-export texture staleness: extracted `fsb_main_*` textures win over changed pixels under
  the same name — delete extracted set first if texture content ever changes.
