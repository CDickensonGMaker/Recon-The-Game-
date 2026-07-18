# SYSTEMS-DESIGNER — FSB root cause, FIX 1 keepout + crater scale

Lens: world-generation systems correctness. All claims below are from the code as of this session,
not the briefing.

## Q1 — Is the keepout param the right shape?

**Yes, with three amendments.** The param is the correct choke point; the amendments are about the
degenerate return, the inflation per caller, and one call site the briefing missed.

### The complete call-site inventory (there are FIVE, briefing names four)

`_passable_near` (mission_generator.gd:87-97) is called from:

| # | Line | Caller | Origin | Ring | Can it land inside the fsb rect? |
|---|------|--------|--------|------|------|
| 1 | 118 | `_patrol_anchors` filler | `insertion_lz` (spawn, 22m outside gate) | 120–480m | **YES** — spawn sits on the rect edge; inward angles put anchors up to ~460m deep across the base |
| 2 | 431 | village fallback | `gate + dir(q_ang)*360` | 0–80m | **YES** — see geometry below |
| 3 | 444 | camp fallback | `gate + dir(ang2)*440` | 0–70m | Narrowly — only in the far-corner cone (~388m from gate); thin but nonzero |
| 4 | 456 | first_signs | `gate + dir(qa)*(170–280)` | 0–40m | **YES — the measured root cause** (47225: sign at (950,712), −18.6m dig) |
| 5 | 504 | **ambient patrol spawn `ppos`** (build phase) | `gate.lerp(village, 0.3–0.7)` | 30–120m | **YES — briefing omits this one.** When a village sits trans-base (beyond the far wire — exactly what the guarded fallback will legitimately produce in the inward quadrant), the gate→village segment crosses the ENTIRE base; `mid` at t=0.3–0.7 is deep inside the wire. Enemy patrol groups can spawn mid-base today. |

### Why the rejection cannot live anywhere else

- **Not in `find_site`**: find_site already rejects the rect in band mode
  (site_planner.gd:50-51, `_fsb_rect.grow(FSB_SITE_CLEARANCE)` = grow 40). The gap is exclusively
  the `_passable_near` fallbacks and direct calls. No change needed there.
- **Not post-hoc at the call sites**: rejecting the returned point wastes the entire 60-attempt
  budget per retry and forces a nested outer retry loop — worse determinism surface (see Q2).
- **Not via passability**: at PLAN time the base does not exist yet — `place_firebase_main` runs in
  build (mission_generator.gd:483), so `gameplay_grid.is_position_passable` samples raw pre-flatten
  terrain and can NEVER reject base-interior points. The keepout must be geometric. This is also why
  the bug is deterministic per seed: nothing in the plan-time world knows the base is there.

### Amendment 1 — the degenerate return is a landmine

`_passable_near` line 97: `return origin  # degenerate but never invalid`. With a keepout that
comment becomes a lie: for first_signs the origin itself (`gate + dir*170–280`) is the point INSIDE
the rect. If all attempts fail, returning origin silently violates the keepout and re-digs the base.
When `keepout != Rect2()`, the failure return must be a detectable sentinel (Vector3.ZERO is safe —
the success path clamps x,z to ≥80, so ZERO is unreachable as a valid result) and every keepout
caller must handle it: signs DROP (briefing's rule, correct — that quadrant is your own base),
villages RETRY/keep (see risk below), anchors/ppos skip that candidate.

### Amendment 2 — inflation per caller

- **first_signs +70m: correct number.** Max crater radius = `int(radius_cells 12 × intensity 1.3)`
  = 15 cells × cell_size 4.0 (WorldConfig.CELL_SIZE, world_config.gd:11, wired game_world.gd:85)
  = **60m**. 70 covers it with 10m margin, and incidentally protects the spawn ring (gate−out×22)
  and the armorer's bench (spawn−out×10, mission_generator.gd:518) — both sit ≤32m outside the rect
  edge, inside the +70 skirt. Good.
- **Village/camp fallbacks: use `rect.grow(FSB_SITE_CLEARANCE)` (40), not the uninflated rect.**
  The primary path (find_site) rejects at grow(40); an uninflated fallback is allowed to put a
  village center ON the wire line that the primary path would have rejected 40m out. Parity or the
  fallback remains a second, slightly-different rule — the exact divergent-system disease this
  session is treating.
- **Patrol anchors (118) + ambient patrol spawn (504): uninflated rect is right.** An enemy probing
  the wire is flavor; an enemy inside it is a bug.

### Amendment 3 — call site 5 (line 504) must be in this change

Same param, one more one-line edit, and it closes a live spawn-inside-the-wire path that FIX 1's own
village guard makes MORE likely (guarded inward-quadrant villages legitimately land beyond the far
wire, which is precisely the trans-base configuration that puts `mid` inside the rect).

### Village fallback geometry (Q3 evidence, computed)

FSB_HALF = (178, 172.2) (site_planner.gd:460); gate sits on the wire ring (perimeter of the
356×344.4m rect); model placed UNROTATED so the gate's world direction is constant across all seeds.
For the quadrant pointing across the base: far wire is ~344–356m from the gate along the inward
centerline (far corners ~388m). Village fallback samples `gate + dir*360` jittered 0–80m → distances
280–440m from the gate. 280–344m along an inward ray is **inside the rect**, on flat, freshly
flattened, fully passable ground — the passability check will happily accept it. A village stamped
inside your own wire is a seed roll away. Camp fallback (370–510m) only clips the far-corner cone —
thinner, but the guard is the same one-line change.

**Verdict on Q3: guard villages+camps in THIS change**, as the briefing already proposes (with the
grow-40 amendment). Beading it separately leaves a known catastrophic placement behind a seed roll
while the file is already open.

## Q2 — Determinism (ADR-010)

**Acceptable, and not a new hazard class.** Draw counts in this stream are ALREADY variable:
`_passable_near` early-returns on the first passable candidate (line 96) and `find_site` early-breaks
at score>0.95 (site_planner.gd:82-83). ADR-010's contract is same-seed reproducibility, not
cross-version stability, and reproducibility is preserved: the keepout rect derives from
`fsb_center`, which is drawn from the SAME stream BEFORE any keepout consumer runs
(plan_patrol_world:392 precedes villages:407, camps:439, signs:452). Rejection is a pure function of
(seed-derived terrain, fixed rect). Same seed in, same world out.

Conditions to keep it clean:
1. **Rejection goes INSIDE the existing attempt loop** — each attempt still consumes exactly 2 draws
   (`a`, `r`); keepout only changes how many attempts run, which is the pre-existing variability.
   Do NOT add an outer caller-side retry loop that re-enters `_passable_near`; "capped retries" should
   mean the existing attempts budget (raise 60→90 for keepout callers if wanted), then sentinel.
2. **No rng consumption in the failure path** — a dropped sign must consume zero extra draws.
3. **Downstream shift is real but benign**: a dropped sign shortens `p.first_signs`, so build's
   per-sign draws (intensity + water roll, lines 493-495) shift everything after them in the
   build stream (seed+777). Deterministic, but any probe asserting counts (signs 4–8) must adapt.
4. **The one real casualty: pre-patch saves.** Any save that re-plans the world from its stored seed
   re-seats entities into a shifted world (different village/camp/sign positions for the same seed).
   Whoever owns the save path (d505d18c re-seat) must be told; acceptable in dev, but name it.

Worse-scramble hazard to avoid: if village fallback DROPS on failure, `villages.size()` shrinks —
build's patrol loop indexes `villages2[pi % villages2.size()]` (line 502) and the garrison loop count
changes (line 467), breaking the one-village-per-quadrant pacing promise. **Villages must retry
within the guarded sampler (which reaches the legitimate strip beyond the far wire), never drop.
Only SIGNS drop.** Signs are decoration; villages are load-bearing structure.

## Q4 — Crater scale (recommendation only, no change this wave)

**Where the multiply happens**: `DAMAGE_PROFILES` depths are normalized; the crater modifier writes
normalized values into heightmap data (heightmap_storage.modify_region:145, clamped 0–1 at
set_cell:57). Meters appear only on read: `sample_world` line 64 `sample_bilinear(...) *
height_scale` and mesh build (terrain_chunk.gd:67). The live `height_scale` is
**WORLD_HEIGHT_MAX = 350.0** (terrain_manager.gd:17, assigned to heightmap at generate_terrain:132)
— NOT 400 (briefing) and NOT the legacy @export 280 (terrain_manager.gd:18).

**What a crater digs today** (center depression = full `depth` at falloff 1.0; radius =
`int(radius_cells × intensity) × 4.0m`):

| Profile | Depth @ i=1.0 | Radius @ i=1.0 | Patrol-world roll (i 0.8–1.3) | Rim @ i=1.0 |
|---|---|---|---|---|
| SMALL (grenade/mortar) | **5.25m** | 12m | — | +1.75m |
| MEDIUM (artillery) | **12.25m** | 24m | — | +4.2m |
| LARGE (bomb) | **21.0m** | 48m | depth 16.8–27.3m, radius 36–60m | +7.0m (to +9.1m) |

Cross-check against the measured evidence: 0.06 × 0.886 × 350 = 18.6m — the briefing's −18.6m dig at
47225 is intensity ≈0.886. The math closes; only the briefing's "×400 = 24m" figure is off (it's
×350 = 21m at i=1.0).

**Were they authored for a smaller scale?** The profiles came over in the TerrainEngine copy where
every default was height_scale 280 — even there LARGE = 16.8m, so they were unrealistic before this
project touched them; "Normalized depth (0-1 scale)" authoring only produces sane craters on a
tens-of-meters lab world. Reality check: a B-52 750lb bomb crater is ~9m deep × ~14m wide; a
mortar/grenade scrape is 0.3–1m. SMALL is ~5–10× too deep; LARGE is ~2–3× too deep and 4–8× too
wide. Worse: depth is constant in NORMALIZED units while per-preset relief varies
(_preset_height_scale: COASTAL_HILLS 25m … STEEP_MOUNTAINS 300m) — on a 25m-relief coastal AO a
LARGE crater digs 21m into 25m of total relief, clamping to bedrock 0. Every paddy-country crater is
a proportional canyon.

**Recommendation for the bead (not this wave)**: author depths in METERS and normalize at apply
time. The codebase already has the exact pattern — terrain_manager.gd:478
`depth_normalized = (carve_depth_meters * falloff) / height_scale` (river carving). Suggested meter
targets when the bead runs: SMALL 0.6m, MEDIUM 2m, LARGE 6–9m, rim ~15% of depth. Also note
`int(radius_cells × intensity)` truncation makes SMALL at i=0.8 a 2-cell (8m) crater — fine, just
document it when retuning.

## Bead separately (out of this wave's scope, discovered while reading)

1. **Signs can chew VILLAGES the same way they chew the base.** Sign band 170–280m from gate;
   village band 240–470m; max crater radius 60m — overlap is real, and nothing enforces sign-to-site
   separation (`_passable_near` checks neither `placed_sites` nor `_reserved`). Build order stamps
   villages (483-491) BEFORE digging signs (492-495): a hut on a crater rim un-seats exactly like the
   wire cards did. Same fix shape (keepout against site discs) but a design decision on whether a
   cratered village edge is flavor or bug — not this wave.
2. **`_patrol_anchors` unconditionally appends `insertion_lz`/`exfil_lz`** (both = player spawn,
   22m from the gate) into the enemy patrol circuit pool (lines 109-111; the "firebase_center"/
   "village_center"/"camp_center" keys don't exist in the patrol-world dict — only the spawn keys
   land). Enemy circuits legally route to the player's spawn point. Design call, name it to the
   game-designer.

## Tradeoffs named (Law 2)

- FIX 1 sacrifices sign density in the inward quadrant (correct — it's your base) and shifts every
  same-seed world post-patch (villages/camps move; pre-patch saves re-seat wrong).
- Guarding villages via retry-not-drop sacrifices a little placement quality in the inward quadrant
  (the legitimate strip beyond the far wire is narrow) to keep the 4-village pacing contract.
- Deferring the crater-scale bead means every patrol world keeps digging 17–27m canyons behind the
  keepout skirt until the bead lands — the keepout only protects the base, not the AO's plausibility.
