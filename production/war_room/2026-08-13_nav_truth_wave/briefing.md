# BRIEFING — the nav-truth wave: down-facing ground, casualty-prop colliders, cover-seek

**Convened 2026-08-13, day session.** The Summoner is hands-off today and ruled: work the
code-side queue, audit, fix. Three evidenced fixes; council verifies and rules before build.

**SUMMONER RULING, mid-council (2026-08-13, verbatim): "make the ai walk all the real
geometry in the game."** FIX A ships by decree — the council's ship/park question is
resolved; its analyses now bind the HOW (winding scope, roof-cull order, guardrails,
verification). The deliberate nav-ignore rulings (fb_veg_, door_, fb_hootch_roof_) stand —
this decree makes the GROUND honest, it does not overturn those.

## FIX A — the navmesh under the compound is baked on the WRONG GROUND

**Measured (tools/probe_bunker_entry.tscn, extended this session with a physics pass):**
- 37/37 bunker fire points "nav-reachable" — but **19 of 37 routes are physically blocked**,
  every block by `fb_terrain_mound` (the compound's ground-of-record, ruling 2026-07-29).
- At every block: **nav path_y = exactly 174.00; physics ground = 175.66–175.82.** The navmesh
  floats ~1.7 m under the real mound surface — routes tunnel through berm volume. Nav
  reachability inside the compound is fiction. Log: scratchpad `bunker_entry2.log`.
- Boot log: `[FSB] 2048 concave shape(s) forced double-sided (inward winding in the shipped
  GLB)` — physics is repaired via `backface_collision=true` (`site_planner.gd:1420-1431`);
  the nav bake takes the same 2314 colliders via `_shape_faces` → `concave.get_faces()` RAW
  (`nav_baker.gd:563-566`) — winding intact, down-facing ground contributes no walkable
  surface, the flat terrain seat wins. This silently defeats the baker's own stated contract
  ("the exact colliders move_and_slide() hits, so navmesh and physics cannot disagree",
  `nav_baker.gd:36-41`).
- Consequence chain: garrison men "get in" because they are PLACED at posts and because paths
  are fiction that physics happens to tolerate (move_and_slide climbs the berm the nav calls
  flat); the player walks honest physics and reads it as "the AI can get in and I can't".

**Proposed fix:** in `_walk_shapes`, when the shape is `ConcavePolygonShape3D` with
`backface_collision == true`, append the winding-flipped copy of its faces BEFORE
`_cull_roof_faces` (so flipped roof faces still cull). Nav source becomes double-sided exactly
where physics is. Verify: rebake; probe must show path_y ≈ 175.7 over the mound; capsule-pass
rate must rise; any post that goes honestly SEALED is a real finding, not a regression.

**Questions for council:** bake-cost risk (faces double for 2048 shapes — the FSB bake is
runtime, `test_nav_path` measures it at ~10.8 s total); walls becoming walkable on top
(parapet crest ~0.9 m wide vs agent_radius 0.5 erosion); interaction with
`NAV_ROOF_CULL_PREFIXES` and `NAV_IGNORE_PREFIXES`; whether AGENT_MAX_CLIMB 0.4 handles the
now-honest berm slopes and bunker steps, or routes to some posts honestly die (then what).

## FIX B — casualty-prop part colliders are tagged hard and float in the air

**Measured (same boot log):** `[FSB] ballistic tags: 445 soft, 2045 hard` and
`[FSB] 1566 collider(s) floating >3m off the ground; worst: … grunt_head_wounded1_3304 +6.8m,
grunt_uparm_r_wounded1_3309 +6.5m, grunt_uparm_l_wounded1_3308 +6.5m,
grunt_forearm_l_wounded1_3302 +6.2m`. Character-part colliders (`grunt_*_wounded1` — the
wounded-casualty display figures) ship inside `fsb_main_v3.glb`, get blanket-tagged hard by
the ballistic pass, stop rounds with no hit reaction (props, no Hitzone), enter the nav walk,
and some float metres off the ground. This is the audit's "548 character-part colliders"
item, now named. (The floating list also contains legitimate hangers — `fb_int_fb_hanging_bulb`
— the >3 m check is partly noise; do not act on it wholesale.)

**Questions for council:** count the actual `grunt_*` collider population in the walk (verify
548 or correct it); rule the right class — lean: `soft_cover` (rounds penetrate; a wounded man
reads as flesh, not sandbag) and they STAY in the nav bake per his fb_int_ ruling ("real in
both, or absent from both"); what to do about the floaters (placement is Blender-side — name
it, don't fix it here); confirm no ledger/casualty-scoring path reads these props.

## FIX C — cover-seek stops 4–5 m short (audit-prescribed, now his standing ask)

Three additive terms, all pinned: `COVER_BLOCKER_MAX_M = 2.5` (`enemy_base.gd:133`), arrival
epsilon 1.5 (`enemy_base.gd:1834`), NavRouter restake dead-band 3.0 m
(`nav_router.gd:118`, distance_squared > 9.0). Candidates are ring points around the man
(`COVER_SEARCH_OFFSETS`, `enemy_base.gd:126-130`), never a wall face. The leap clip gates on
`_wall_within(1.2)`, so short men skip their arrival animation — proof the shortfall is real.
**Prescription (2026-08-12 audit):** in the selection path, snap the claimed cover point to
the blocking face — `hit.position` from `cover_blocked_from` (`enemy_base.gd:2137-2145`),
pulled back ~capsule radius toward the man.

**Questions for council:** exact snap geometry (pull-back distance; keep the point on-mesh —
NavRouter clamps via map_get_closest_point); does the shared path also serve AllyBase (one
definition, fossil law); the risk HE flagged — this moves men closer to every wall the siege
was tuned against, and he is NOT watching today: what probe evidence suffices (SFR
--cover-probe cover-to-sandbag distances before/after; the [COVER] claim distance prints),
and what gets flagged loudest for his next playtest.

## Constraints

- No Blender. No bench-hands work. His eye items get QUEUED, not guessed.
- Verify-before-claim: every fix ships with its probe reading, before/after.
- The leak column cannot convict anything on one reading (AUDIT-12 flakiness, measured).
- Suite runs at wave end only. `test_nav_path` now passes in ~10.8 s — it is the bake-cost
  canary for FIX A.
- Fossil law: touched files get their drift corrected in the same change.
