# DEVIL'S ADVOCATE — nav-truth wave, 2026-08-13

Charter: attack the three fixes, name what each sacrifices. Everything below was verified
against code this session; pointers inline. The Summoner is hands-off — the bar for "ship
today" is *provably safe or loudly flagged*. A silently-shifted siege is worse than a
delayed fix.

---

## VERDICTS UP FRONT

| Fix | Ruling | One line |
|---|---|---|
| A (double-sided nav source) | **SHIP-WITH-GUARDRAILS** — probe-gated, same session | The mesh-y consumers are clean (audited below); the danger is not the rise, it is the bake cost nobody has measured and two second-layer/roof hazards the flip creates. Gates listed; if any gate reads red, park with the readings. |
| B (soften wounded-prop colliders) | **SHIP-TODAY** with two named costs | Data-only tag flip; every consumer of `soft_cover` audited. Costs: one body can eat the whole 2-layer soft budget, and blasts now always reach through the figures (`combat_manager.gd:352`). |
| C (cover snap-to-face) | **PARK** | It is not an enemy tweak — `cover_blocked_from` and the claim broker are shared, and AllyBase runs the same sweep (`ally_base.gd:1759-1782`), so this re-tunes HIS OWN SQUAD's cover in every fight, unwatched. Landing plan written below; it fits in an hour of a watched session. |

Missing from the wave: a code-side fix for the invulnerable 81st parapet segment (evidence
already in the boot log), and the bake-cost instrument FIX A needs, which is currently a
**race-condition dead print** (`nav_baker.gd:389`).

---

## 1. FIX A — the honest mesh

### The strongest case FOR shipping it today

The scary framing — "every verified siege ran on the fiction" — cuts the other way on
inspection. What he verified in playtests was **physics behavior**: men climbing the real
mound with `move_and_slide`, paths that XZ-route around carved obstacles while lying about
y. The fix changes the y-claim to match the physics he watched; where a route honestly
dies, `NavRouter.step` already falls back to direct steering (`nav_router.gd:121-168`),
which is what the men effectively do on the fiction today. The failure floor of FIX A is
approximately today's behavior. And I audited every consumer of navmesh y I could find —
**they are all immune to the 1.7m rise**:

| Consumer | Why immune |
|---|---|
| `heli_lift.gd:298-299` `_bunk_on_nav` | caller overwrites y: `bunk.y = man.global_position.y` |
| `squad_system.gd:641-652` `_catchup_ground` | nav-clamps XZ then re-grounds y with a physics ray |
| `nav_router.gd:140-141` off-mesh check | `off.y = 0.0` — vertical error never counted |
| `nav_router.gd:159` arrival | FLAT distance by design |
| `nav_router.gd:44` `CLAMP_MAX_M = 12` | 1.7m rise nowhere near the refusal threshold |
| `enemy_base.gd:1834` cover arrival (3D) | cover points carry the man's own y (offsets are y=0, `:126-130`) |
| probes | drift measured in XZ only (`probe_bunker_entry.gd:84`, `probe_interior_nav.gd:68`) |
| grep for a tuned `174` | **zero hits in scripts/** — nothing is calibrated to the plane |
| sapper trigger `sapper_charge.gd:196` | physics position vs Destructible position, nav not involved |
| siege spawn ring | assault crosses "from ~200m" (`siege_director.gd:77`), outside the 185m half-box — spawns never touch the mesh |

Waypoint advance actually *improves*: `NavigationAgent3D.path_desired_distance` is a 3D
distance (stated in `test_nav_path.gd:144-145`), and today every waypoint floats 1.7m under
the man's feet.

### The case AGAINST — three hazards the flip CREATES, two of them measured

**A1. The buried fiction layer survives in patches — arithmetic from the probe log.**
`agent_height` bakes at ceil(1.8/0.2)×0.2 = **1.80m exactly** (`nav_baker.gd:321`, cell h
0.200 per the log). `filter_walkable_low_height_spans` (`nav_baker.gd:332`) culls the 174
seat only where the mound gives it < 1.8m of clearance. Measured clearances in
`bunker_entry2.log`: **1.66–1.82m** — posts 9/10 read 1.82 and post 26 reads 1.80. Where
the mound sits ≥1.8m over the seat, the flat 174 layer SURVIVES under the honest surface as
a disconnected island, and `map_get_closest_point` picks between layers arbitrarily — the
baker's own warning at `nav_baker.gd:221` and `:330`. A work post or cover point clamped
onto a buried island is a guaranteed no-path → direct-steer fallback → a new `[NAV]`
warning that reads as a regression. The briefing's verify step ("path_y ≈ 175.7 at 37
posts") cannot see this. **The probe must add a two-layer check**: at each post, count
distinct mesh y-answers within the XZ tolerance (query at y-2 and y+2; disagreement =
buried patch). If patches turn up, the real fix grows: suppress `_add_terrain` cells inside
the mound footprint for the FSB job — more surgery than the briefing scopes.

**A2. EVERY inward-wound roof becomes walkable, not just the mound.**
The flip is applied per-shape wherever `backface_collision == true` — which
`site_planner.gd:1420-1431` set on **all 2048** concave shapes, because *every* structure
winds inward (`site_planner.gd:1415-1416`). The prescription protects only the six
`NAV_ROOF_CULL_PREFIXES` families + medical (`nav_baker.gd:517-520`) and the ignored
`fb_hootch_roof_` (`:455`). Everything else with a flat top wider than the 1.0m erosion
(2×agent_radius) gains walkable roof: **the chow hall first** — `nav_baker.gd:515-516`
records that `tent_roof_chowhall` / `WB_chowhall_backwall` match no list. Those become
walkable islands at roof height next to a garrison work hub; closest-point queries near the
chow hall can land on the roof. Cheap same-change fix: add `"tent_roof_chowhall"` to
`NAV_IGNORE_PREFIXES` (a roof-only collider must be ignored, not roof-culled —
`_cull_roof_faces` measures from the shape's OWN base y at `:538-543`, and a roof-only
shape's base IS the eave, so the cull would keep the whole roof). Sweep the log's collider
names for other flat-top families (water trailer, supply crates, sandbag stacks) and accept
islands or ignore them by name — but NAME the class in the decree.

**A3. The 45–50° inverse-fiction band.**
Bake slope limit is 50° (`nav_baker.gd:327`); enemies never set `floor_max_angle`
(zero grep hits) so physics walls at the CharacterBody3D default 45°. Today the mound
contributes no surface so the band is moot. After the flip, any honest berm face between
45° and 50° is nav-walkable but physically unclimbable — the exact "path INTO walls with
full confidence" defect the baker exists to prevent (`nav_baker.gd:38-41`), now in its
one blind spot. Mitigation is one line — bake at `agent_max_slope = 45.0` — but that line
has its OWN blast radius: every non-FSB site bakes terrain with the same constant, and a
jungle slope in the band would newly seal. Ship the 45° change only with the compound
probes AND a patrol-world path count before/after.

### A4. The bake cost — the briefing's canary is miswired, twice

This is my strongest sustained objection to "just ship it".

1. **`test_nav_path` never touches the FSB bake.** It boots `game_world.tscn` (not
   demo_game), stamps ONE hut, and bakes one 20m site via `queue_site` — terrain +
   carve path only (`test_nav_path.gd:40-77`). `_walk_shapes` over the 2314 colliders is
   **never executed by the suite's nav test**. Its 10.8s measures world-gen, not the bake
   FIX A doubles. Shipping a 2× face count "because the canary is green" is shipping blind.
2. **The real instrument is a dead print.** `[NavBaker] ... %d ms total` fires only when
   `_queue.is_empty() and _active_mesh == null` (`nav_baker.gd:389`) — but `_active_mesh`
   is cleared in `_process` (`:295-298`), not in `_on_bake_done`, so the summary wins or
   loses a frame race. It lost it in `bunker_entry2.log`: the line is absent. **There is no
   recorded baseline for the FSB bake time anywhere.**
3. **The cost is paid mid-siege, not at boot.** Nothing gates boot on the bake
   (`game_world.gd:196` sets `is_world_ready` before any bake lands; the player sits on
   the bunk while it runs async). But every Destructible death calls `breach_at`
   (`destructible.gd:194-196`) which re-queues the **full 370m FSB job** — and
   `_start_bake`'s source assembly (collider walk + `get_faces()` copies + the new flip
   copies + roof cull transform math, `nav_baker.gd:340-353,476-556`) runs **on the main
   thread**, during the assault, every time a satchel opens a wall. The async worker part
   also contends with 45 men of AI on his 12-core/no-GPU box.

Honest sizing: voxelization cost scales with box AREA (1480×1480 cells at 0.25) more than
with triangle count, so the worker-side hit of doubling faces is probably well under 2× —
but "probably" is exactly what the law forbids shipping on.

**Pre-work that makes FIX A shippable (all logging, zero behavior):** print per-bake ms in
`_on_bake_done` (the delta at `:373` is already computed — just print it), print total
source face count in `_walk_shapes`, and fix the racy summary. Then the before/after is two
boot logs.

### FIX A ship gates (all must read, from the real probes — they DO load demo_game)

1. `probe_bunker_entry`: capsule-pass ≥ the current 18/37 and every remaining block named;
   **0 OFF-MESH, 0 new SEALED** (a newly SEALED post is a garrison man standing outside his
   bunker during his next playtest — that is a finding, and it PARKS the fix until routed).
2. `probe_interior_nav` + `probe_compound_nav`: no reachable→SEALED flips, 8/8 bearings
   still linked.
3. Two-layer check (new, per A1): 0 buried patches at the 37 posts and the work-marker set.
4. Per-bake ms before/after: after ≤ 2× before AND the breach re-bake's main-thread
   assembly under ~100ms (frame-hitch budget at the siege's 20-30 FPS floor).
5. One full siege in a headless run (the sapper_room bench exercises breach→rebake→walk,
   `sapper_room.gd:13-15,248-252`) with zero new `[NAV]` fallback warnings.

Sacrifice named: shipping behind gates costs the rest of today's queue if a gate reads red;
NOT shipping keeps lying to 19 of 37 routes and keeps "the AI can get in and I can't" alive
for another session. Prepared-but-parked is the correct failure mode, not silent ship.

---

## 2. FIX B — wounded-prop colliders to soft

### What I verified

- Tagging is one walk, name-prefix driven, FSB-root-scoped (`site_planner.gd:1506-1529`);
  adding a `grunt_` prefix to `FSB_SOFT_PREFIXES` (`:1501-1503`) cannot leak into
  ModelActor's gib-donor logic — different trees, and `model_actor.gd:516,541` reads mesh
  names inside character GLBs, never FSB collider groups.
- **No ledger/intel/interaction consumer exists.** The figures are bare StaticBody3D
  colliders: no Hitzone, not in AgentRegistry, not in `enemies/allies` groups, so
  `bullet_system.gd:180-190` can never route damage or score them; corpse-intel and the
  litter chain work on agents. Grepped `grunt_|wounded` across scripts/ — the aid-station
  "patient" occupation (`site_planner.gd:898,930`) and `ward_wounded`
  (`campaign_state.gd:268-279`) are LIVE-agent systems, untouched by prop groups.
- Count discipline: the boot log names the figures but nobody has counted them. The audit
  says 548; `[FSB] ballistic tags: 445 soft, 2045 hard` — print the actual `grunt_*` tally
  in the tag pass in the same change, per the briefing's own ask.

### The two costs the briefing did not price

**B1. One body is not one layer.** `soft_left = 2` (`bullet_system.gd:103`): the third soft
surface stops a round (`:232-235`). A lying figure is MANY part colliders (head, torso,
both uparms, both forearms in the log alone) — one ray through one body can cross 2-3 parts
and die inside it, or exit with the whole soft budget spent so the aid-station's far tent
wall (soft, `fb_aid_station` at `site_planner.gd:1501`) stops it. "A wounded man reads as
flesh, not sandbag" is the right ruling per-collider and still produces a sandbag per-BODY.
Bound it with `probe_penetration`/`probe_structure_ballistics` through a figure and print
the layer count; if it reads absurd the follow-up is tagging only torso parts soft and
leaving limbs… which is over-engineering a display prop. Accept and record.

**B2. Blast reach changes, not just bullets.** `combat_manager.gd:352-355`: a soft blocker
passes `BLAST_THROUGH_COVER_MULT` of blast reach ALWAYS; a hard one only on the 50% defeat
roll. Today the figures shield whatever stands behind them from explosions half the time;
after FIX B, never. Aid-station-adjacent satchel/mortar hits get slightly more lethal.
Small, real, and it belongs in the decree so the next reader does not "discover" it.

Also for the record: soft-tagging does NOT fix the two uglinesses that made this item —
mid-air ghost impacts on the +6.2–6.8m floaters (rounds still hit them; they now puff dust
instead of sparking, `bullet_system.gd:226`), and cover rays still scoring a flesh figure
as a blocker (`enemy_base.gd:2137-2145` is a raw physics ray, no group filter — same class
as every soft wall, pre-existing). The floaters stay a named Blender-side defect; do not
let the soft tag be recorded as "wounded props fixed".

Devil's aside on the ruling itself: these colliders are export ACCIDENTS (grunt_ is the
character pipeline's gib-donor prefix — a wounded-figure source got swept into the firebase
export, same family as "export ate the medical complex"). Soft-tagging legitimizes them.
The alternative — disable the colliders by prefix in the repair pass — is equally
code-side, removes ghost impacts AND fake cover, and its cost is walking through a display
body. His fb_int_ ruling ("real in both, or absent from both") points at soft-and-stay, so
soft wins — but the council should rule knowing "absent from both" was on the table for a
mesh family whose placement is already broken.

---

## 3. FIX C — cover snap-to-face: PARK

He scoped it "while he can watch". He is not watching. The briefing already knows this; my
job is to say whether the guard-railed version is safe enough to overrule that. It is not,
for one reason the briefing underweights:

**This is not an enemy change.** The snap must live in the selection path around
`cover_blocked_from`, and that static plus the offsets plus the claim broker are shared —
`ally_base.gd:1759-1782` runs the same sweep with a wider 9–13m far ring (`:1747-1751`).
Either both brains get the snap (fossil law, one definition — and then HIS SQUAD's spacing
to walls changes in every firefight, patrol and siege alike), or enemies get a fork of the
cover test (the exact divergence ADR-023 exists to forbid). Both options change things he
verified, on a day he cannot see them. The siege was tuned against men stopping short:
defenders' grenade lanes, parapet firing angles down the berm face, the leap-clip gate
(`_wall_within(1.2)`) suddenly firing across 45 attackers. That is a re-tuned siege
shipped silently — the exact thing this council was told is worse than a delayed fix.

**The landing plan (so a watched session lands it in an hour):**
1. Return the blocking hit from the selection ray (extend `cover_blocked_from` to output
   `hit.position`+collider, or a sibling static returning the Dictionary — ONE definition,
   both brains).
2. Snap = `hit.position` pulled back toward the man by 0.6m (capsule 0.4 + skin), then
   **y flattened to the candidate's ground y** — `hit.position` is at eye height
   (`enemy_base.gd:2139`, origin = candidate + UP*1.3) and the arrival test is 3D
   (`enemy_base.gd:1834`); an unflattened snap point eats 1.3m of the 1.5m arrival epsilon
   vertically and men will orbit unreachable cover.
3. Clamp: reject the snap (keep the ring point) if displacement from the candidate exceeds
   `COVER_BLOCKER_MAX_M` (2.5), if the hit collider name begins `fb_terrain_mound`/berm
   (never "snap to the hill" — that walks men UP the berm toward the parapet), or if
   `NavRouter.nearest_mesh_point` moves it again by more than ~1.0m (agent-radius erosion
   band — the mesh edge already stands 0.5m off every wall, which quietly does half the
   pull-back for free).
4. Evidence: SFR `--cover-probe` claim distances before/after (`support_fire_range.gd:772`
   prints d(claim→sandbag)); assert mean shrinks ~2m and NO claim lands inside a collider
   (shape-cast at the snap). Then his eyes on one siege.

Sacrifice named: parking keeps the 4–5m shortfall and the skipped leap anims for another
session, and keeps "men shooting from open ground next to perfectly good sandbags" in his
next playtest. That is a fair price for not re-tuning both armies unwatched.

---

## 4. THE QUEUE, RANKED (value to his next playtest × risk while unwatched)

1. **FIX B** — real value (rounds behave at the aid station), lowest risk, ships with a
   probe reading and two named costs.
2. **FIX A pre-work + probes, then the flip if gates read** — highest value in the wave
   (19/37 fictional routes, the compound's whole interior), risk contained ONLY by the
   gates; without them it is the largest unwatched behavioral change this project could
   ship in one day.
3. **The 81st parapet segment** (add to wave — see below). Small, evidenced, code-side.
4. **FIX C** — PARK with the landing plan above written into the tracking doc.

### The missing wave item: fb_sbg_seg_046_001

The boot log warns it ships INVULNERABLE (`site_planner.gd:1744-1746`); the manifest holds
`fb_sbg_seg_046` (`firebase_v3_destructibles.json:697`) and the GLB holds a `_001`
Blender-duplicate twin. A code-side fix needs no Blender: in the `unclaimed` pass
(`site_planner.gd:1731-1743`), first print its transform against its base-name twin, then
**(a) co-located duplicate → disable its collider shapes and hide its mesh** (a stacked
twin adopted as a Destructible would leave an invisible-second-wall standing after the
first one dies — a breach that LOOKS open and stops men and rounds, on the siege's own
breach axis), or **(b) offset stray → wire it exactly like the manifest 80**
(sandbag_wall / hp 140), which also corrects SiegeDirector's perimeter map
(`FSB_PARAPET_GROUP`, `site_planner.gd:1723`). Either branch is ~15 lines and removes a
live siege landmine: today a sapper party can spend charges on a wall that cannot die.

### One more disconnected wire (charter item 6)

`siege_director.gd:285-286` still justifies gate-only convergence with "nothing re-bakes
the navmesh on destroy (nav_baker.gd:16-18)" — **false since the BREACHING block landed**
(`nav_baker.gd:60-73`, `destructible.gd:190-196`), and the cited lines now point at prose
about craters. The gate-convergence DESIGN may still be right (the wire ring is merged and
the doctrine argument stands on its own), but its recorded reason is dead, and FIX A makes
the gap wider: after an honest mesh + breach re-bake, a satchel hole is a real, walkable,
navigable lane the assault deliberately ignores. Fossil law: if this wave touches siege
code, correct the comment in the same change; either way, record "should assault squads
re-lane onto sapper breaches?" as a QUEUED eye-item for him — that is a design ruling, not
a code fix.

---

## LAWS CHECK

- No decree violated: FIX A gates preserve Pillar 1 (believable firefights) by refusing to
  ship a mesh that seals a bunker unverified; FIX C park honors the Summoner's explicit
  watch condition (Law 3).
- Tradeoffs named at each ruling.
- Everything asserted above carries a pointer or names the probe that must produce it.
