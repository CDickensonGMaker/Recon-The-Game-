# Lead Programmer / Game Designer — AI & Combat Legibility (Pillar 1)

**War Room, INDIVIDUAL SIGHT · 2026-08-12 · READ-ONLY AUDIT.**
Every claim carries `file:line`, read directly today against the working tree at
commit `19b2bed0` (+ uncommitted `firebase_v3.2.blend` / `gen_firebase_v3.py`).
Where I could not find a pointer, I say so — that is the finding.

Lane: cover-seek (B3), HOT_CAP / the cold tier, mounted MG (B5), ally pathing in
the compound after today's re-export.

---

## 0. THE HEADLINE — the HOT_CAP brief is working from a stale number

**`scripts/enemies/enemy_squad.gd:42` — `const HOT_CAP: int = 50`. Ceiling 64
(`:43`). Set on 2026-07-28 by commit `8074af38` (git log -S, verified).**

The brief says Caleb is "raising HOT_CAP to 26 today; it was tuned when raids were
20 men". That is not what is on disk. It was raised **12 → 50 (ceiling 16 → 64)**
by Summoner ruling two weeks ago, and the reason is written into the file at
`:37-41`: at 65+ live units think was 1.20 ms of a 37.5 ms physics wall while the
BODY was ~94% of it (`PERF_LEDGER.md:295-304`). *The throttle was on the cheapest
term in the loop.*

**Therefore, at the demo's 45-man assault (`scripts/levels/demo_game.gd:87`
`SIEGE_STRENGTH = 45`), there is no cold set at all.** 45 < 50. Every attacker
runs the full combat brain. The "19 men outside the hot set" the brief is worried
about do not exist.

Raising the cap to 26 would be a **REGRESSION of 24 slots** and would create the
exact furniture problem the brief fears. Do not do it.

### What a COLD man actually does (read in full, in case the cap ever binds again)

The tier is applied at exactly one place: `scripts/enemies/enemy_base.gd:898-904`.

| Question | Answer | Pointer |
|---|---|---|
| Still animates? | **Yes.** The animation/pose path is gated by `_body_hot`, not by the hot-set. `_body_gate_open()` returns true for anyone in `AIState.COMBAT` or above `AlertTier.RELAXED` — every besieger qualifies. | `enemy_base.gd:830-832` |
| Gravity / `move_and_slide`? | **Yes**, same gate. | `:781-782`, `:816-817` |
| Still moves and paths? | **Yes.** `_execute(capped_delta)` runs every frame for everyone, ungated. | `:796` |
| Think rate? | **Identical to hot.** Tiering does not change the interval; only distance does — `_update_think_lod`: ≤80 m → 0.15 s, 80–150 m → 0.3 s, >150 m → 0.6 s. | `:37-52`, `:31` |
| Perception / witness? | **Never tiered — the ADR-005 guard-rail.** `_update_perception` + `_check_corpse_discovery` run above the tier branch. | `:887-890`, `enemy_squad.gd:35-36` |
| Can he shoot? | **Yes**, but only at what he can personally witness, with a wide cone (exposure never ramps for him). "He sprays, he does not snipe." | `:930-948`, esp. `:945` |
| Can he be shot / die? | **Yes.** Hitzones and `_die()` are outside the tier entirely. | `:2875` |
| What he *loses* | `_find_best_target` scan, the precise LOS raycast, the scored goal stack, squad designation, `_refresh_separation`. He adopts the squad's shared contact by dictionary read. | `:917-923` vs `:930-948` |

### How the hot set is chosen, and the design flaw that is currently harmless

**First-come, and it never re-sorts.** `request_hot()` (`enemy_squad.gd:75-87`)
grants a slot to whoever asks while `_hot.size() < mini(HOT_CAP, HOT_CEILING)`.
There is **no distance term, no LOS term, no player-proximity term** — I searched
`enemy_squad.gd` end to end; **no pointer found** for any re-evaluation.

Slots are freed only by death, downing or disengage — `enemy_base.gd:1268`
(dropped out of COMBAT tier), `:2819` (downed), `:2875` (dead), plus the 8-second
lost-contact disengage at `:939-941`.

**Hysteresis:** there is none, and none is needed, because **there is no
demotion**. A hot man stays hot until he leaves the fight. Boundary flicker is
therefore impossible. The cost of that design is the opposite failure: **the hot
set is decided by spawn order, not by who the player can see.** If the cap ever
binds, the 26 men who happened to enter COMBAT first hold the brain forever —
including men 200 m away on the far berm — while the ten in the player's face run
cheap. *That* is what would read as furniture, not the cap number itself.

### Judgement

At 50/45: **they read as soldiers.** At 26/45: the 19 would still move, animate,
path and fire — they would not be statues — but they would lose independent target
selection and the cover/flank goal stack, and because selection is first-come the
19 cold men would be a random 19, not the far ones. In a compound fight that is
visible: men who never break for cover while the man beside them does.

**Cheapest change that most improves it, in order:**
1. **Do nothing to HOT_CAP.** It is already 50 and 45 < 50. (0 effort)
2. If perf ever forces a cut: **add a promotion sort, not a lower cap.** In
   `request_hot`, when the roster is full, evict the hot man furthest from the
   player if the claimant is at least 20 m closer. ~12 lines in
   `enemy_squad.gd:75-87` + one `release_hot` call. That converts the cap from
   "random 19 are dumb" into "the far 19 are dumb", which the player cannot see.
   A 20 m dead-band is the hysteresis.
3. The cold tier itself already animates and fires (table above). A "cheap cold
   tier that still animates and fires slowly" **is what is already built.** Do not
   commission it again.

---

## 1. COVER-SEEK (defect B3) — the 8/07 fix IS in the code, and it is not the
##    fix for "stops short"

### Is the 8/07 fix present?

**Yes.** Commit `94de3333` (2026-08-07, *"…cover-seek blocker-distance fix
(COVER_BLOCKER_MAX_M)"*). It introduced `const COVER_BLOCKER_MAX_M: float = 2.5`
at `scripts/enemies/enemy_base.gd:133` and applied it in three places. It has
since been refactored into one shared static:

- `enemy_base.gd:2137-2145` `cover_blocked_from()` — the single ray test
- `enemy_base.gd:2113` — the bounding-advance copy
- `scripts/allies/ally_base.gd:1759-1764` — allies call the same static
  (commit `c1082163`, *"The enemy mirror: one cover ray test"*)

**What that fix actually did:** before it, ANY ray from the candidate that hit
anything at all — a treeline 40 m down-range — made the candidate "cover". It
fixed men sprinting to open ground that merely had scenery behind it. That is a
real fix and it should have improved the symptom. It did not eliminate it.

### Why a cover point still resolves short — the numbers, stacked

The candidate is **a ring around the man, never a point on the wall**:

- `enemy_base.gd:126-130` `COVER_SEARCH_OFFSETS` — 12 offsets at radii 3.0,
  3.11 and 6.0 m, `candidate = global_position + off` (`:2156`).
- `ally_base.gd:1747-1751` `ALLY_COVER_FAR_OFFSETS` — a second sweep at 9.0,
  9.05 and 13.0 m, paid only when the near ring is empty (`:1787-1788`).

A candidate qualifies when the blocker is **within 2.5 m of it**
(`enemy_base.gd:133` + `:2145`). Then arrival fires early:

- **enemies:** `enemy_base.gd:1834` — `if global_position.distance_to(current_cover) < 1.5: has_cover = true`
- **allies:** `ally_base.gd:1576` — `< 1.4`

**The stack, worst case: 2.5 m (blocker allowance) + 1.5 m (arrival epsilon) =
4.0 m from the wall face, and the man declares himself in cover.** Add
`NavigationAgent3D.target_desired_distance = 1.0` (`enemy_base.gd:3050`,
`ally_base.gd:2162`) and the nav-target restake dead-band of **3.0 m**
(`nav_router.gd:118` — `if agent.target_position.distance_squared_to(_clamp_out) > 9.0`,
i.e. a new cover point less than 3 m from the old target is never restaked at
all) and the honest worst case is **~5 m short**, not 10.

**The legibility tell is already in the code and it proves the bug is real:**
`ally_base.gd:1581` only plays the leap-into-cover clip
`if _wall_within(1.2)` — and `_wall_within` (`:1559-1565`) rays from the man
toward `current_cover`. So a man who stops 4 m short **silently skips his arrival
animation** and just stands. That is exactly what "stopped 10 m short" looks like
from the player's eye: no lean, no leap, no wall contact.

**Where the remaining distance could come from (not proven today):** the man is
also held off by the navmesh itself. `nav_baker.gd:612` inflates every boxed
structure footprint by `AGENT_RADIUS + 0.15` = **0.65 m**, and `nav_router.gd:114`
clamps the cover point to `map_get_closest_point`, which for a point inside that
inflation lands on the eroded edge. That is another ~0.65 m, not 6.

**The fix, cheapest first (~10 lines total):**
1. `enemy_base.gd:1834` / `ally_base.gd:1576` — drop the arrival epsilon to
   **0.6** (the capsule is 0.4, `enemy_base.gd:437`). Costs nothing.
2. `enemy_base.gd:133` — cut `COVER_BLOCKER_MAX_M` to **1.2**. A blocker 2.5 m
   away is not cover you are behind; it is cover you are near.
3. **The real fix, if he wants it right:** in `cover_blocked_from`
   (`enemy_base.gd:2137-2145`) the ray already returns `hit.position`. Push the
   candidate to `hit.position + (candidate - hit.position).normalized() * 0.55`
   — i.e. **snap the cover point onto the blocker's face** instead of leaving it
   where the ring happened to land. ~4 lines, one function, both brains inherit
   it because they share the static.

**Effort: 1–2 h including a bench check. Do 1+2 first; they are two constants.**

---

## 2. MOUNTED MG PRODUCES NO ROUNDS (defect B5) — CONFIRMED, and it is a
##    bug CLASS, not one weapon

### The 32.9 m figure is real

`data/weapons/m60.tres:39` —
`hip_position = Vector3(11.369393, 9.202755, -32.916264)`. **Verified by reading
the resource.**

### Is it used as a world-space muzzle origin? YES

1. `scripts/player/player.gd:1431` — `weapon_holder.mount_gun(load("res://data/weapons/m60.tres"))`
2. `scripts/player/weapon_holder.gd:1067` — `weapon_model.position = weapon_data.hip_position`
   (and `:931` lerps to it every frame). The WeaponHolder is a child of the
   Camera3D at identity, so this is metres from the eye.
3. `scripts/player/weapon_holder.gd:1116-1120` `_get_muzzle_position()` returns
   `MuzzlePoint.global_position` — the true world position of that node.
4. `scripts/player/weapon_holder.gd:514` `var muzzle_pos: Vector3 = _get_muzzle_position()`,
   `:545` `muzzle_dir = (aim_point - muzzle_pos).normalized()`,
   `:574` `CombatManager.bullets.fire(current_weapon, controller, muzzle_pos, zeroed_dir, ...)`.
5. `ViewmodelLens` is a **shader** (`scripts/weapons/viewmodel_lens.gd:23-42`,
   `:68-71`) — it scales vertices on screen. **It never moves the node.** So the
   node's world transform is exactly what the .tres says.

The muzzle origin is therefore literally the viewmodel's world position. Confirmed.

### But the raw 32.9 m is NOT the bug — the bug is that it is 3.08 m WRONG

I parsed every viewmodel GLB. The arms rigs are exported from **staged scenes
with a per-weapon lane offset baked into the rig root**, and `hip_position` exists
to cancel it. The `_arms_` scenes all carry the same 180° yaw
(`scenes/weapons/m60_arms_viewmodel.tscn:7-8` and every sibling), which flips Z —
so the contract is:

> **`hip_position.z` must equal the GLB rig-root translation.z, and
> `hip_position.x` must equal `−rig.x`.** Residual must be a pose-sized number
> (< ~0.7 m).

| weapon | GLB rig-root xyz | `hip_position` | residual | verdict |
|---|---|---|---|---|
| m16a1 | (0, 0, 0) | (0.12, −0.00, −0.17) | 0.17 | OK (reference) |
| ak47 | (0, 0, −8.000) | (0.65, 0.49, −8.012) | 0.01 z | OK |
| m14 | (0, 0, −4.000) | (−0.09, −0.08, −4.014) | 0.01 z | OK |
| mosin | (0, 0, −16.000) | (−0.06, 0.03, −15.905) | 0.10 z | OK |
| ppsh41 | (0, 0, −28.000) | (2.26, 0.39, −27.952) | **2.26 x** | SUSPECT |
| m79 | (0, 0, −12.000) | (−0.06, **1.77**, −11.897) | **1.77 y** | SUSPECT |
| rpd / rpg2 / flashlight | ~0 | ~0 | — | OK |
| **m60** | (0, 0, **−36.000**) | (**11.37, 9.20, −32.916**) | **≈ 14.9 m** | **BROKEN** |
| **m1911** (`colt45_fp.glb`) | (0, 0, **−56.000**) | (0.05, 0, −0.136) | **≈ 55.9 m** | **BROKEN** |
| **m70** sniper | (0, 0, **−24.000**) | (0.02, 0, −0.15) | **≈ 23.9 m** | **BROKEN** |
| **shotgun** (`ithaca_fp.glb`) | (0.121, −0.076, −59.546) | (**4.66, −2.29**, −59.390) | **≈ 5.3 m** | **BROKEN** |

(The non-arms items — knife, bandage, handset, m26 — compensate in the **.tscn**
instead, e.g. `scenes/weapons/knife_viewmodel.tscn` `transform … 0, 0, 76` against
a −76 rig root, and are correct.)

### The diagnosis, stated plainly

**The M60's viewmodel node sits roughly 11.4 m right, 9.2 m up and 3.1 m behind
the camera — about 15 m off.** `MuzzlePoint` rides with it. Every hip-fired round
spawns 15 m up-and-behind the player, and its direction is
`(aim_point − muzzle_pos)`, i.e. **aimed back down at the player's own position
from above and behind**. Nothing appears downrange; nothing is hit. That is
exactly "the mounted MG produces no rounds".

Two corroborating details:
- `weapon_holder.gd:517` emits the `GUNSHOT` noise at `muzzle_pos` — the AI hears
  the mounted gun **15 m off station**, which will also skew every witness check
  around the MG bunker (`e584d812`, "The MG bunker is mannable, by him and by his
  squad").
- `weapon_holder.gd:546-548` — at `ads_transition > 0.6` the muzzle is
  **overridden to the camera**. So ADS fire works and hip fire does not, on every
  broken weapon. `player.gd:1401-1432` `man_mg()` forces `is_aiming` off via
  `mount_gun` (`weapon_holder.gd:135`) — **the mounted gun is permanently hip**,
  which is why the MG is the one where it is total.

### The fix

**`data/weapons/m60.tres:39` → `hip_position = Vector3(0.0, 0.25, -36.0)`**, then
let Caleb re-aim the pose on the bench (`scenes/weapons/viewmodel_editor.tscn`,
Ctrl+S saves). Same one-line correction for `m1911.tres` (→ z −56.0),
`m70.tres` (→ z −24.0), `shotgun.tres` (→ x −0.12, y ~0, z −59.55). Check
`ppsh41` x and `m79` y on the bench.

**THE MISSING MACHINE — this is the finding that matters most.** I grepped
`tests/` and `tools/` for `hip_position`: the only hits are
`tests/test_viewmodel_poses.gd:30` (which compares hip to ADS, not to the GLB) and
`tools/gen_weapon_data.py`. **No pointer found** for any probe that asserts
`hip_position` against the rig root. Four shipped weapons are silently firing from
5–56 m off, and nothing in the suite says so. Add the assert to
`tests/test_viewmodel_contract.tscn`: parse the GLB root translation, fail if
`|hip.z − root.z| > 0.75` or `|hip.x + root.x| > 0.75`.

**Effort: the four .tres edits ~15 min. Bench re-aim: Caleb, ~30 min. The probe:
~1 h and it is worth more than the fixes.**

---

## 3. ALLY PATHFINDING THROUGH THE COMPOUND

### FIX 0 (perimeter wall absent from the bake) — **FIXED, LIVE.**

`scripts/world/nav_baker.gd:453-467` now seeds `_add_colliders`' root list from
`SitePlanner.FSB_NAV_GEOM_GROUP` (`site_planner.gd:1638`, joined at `:1705` by
parapets and `:1810` by adopted structures). The ~80 perimeter colliders are in
the bake. The second-order name hazard the handoff warned about is written into
the code as a comment at `nav_baker.gd:460-462` — **and it has come true; see
below.**

### FIX 0b (no `[navigation]` section) — **FIXED, LIVE.**

`project.godot:312-314` — `[navigation]` / `3d/default_cell_height=0.2`. And
`nav_baker.gd:325-326` now **rounds** rather than floors the climb, so
`round(0.4/0.2)*0.2 = 0.4 m`. `filter_walkable_low_height_spans = true` at
`nav_baker.gd:332` kills the buried second layer under the mound.

### FIX 2 (mesh:true buildings navigationally sealed) — **FIXED, LIVE.**

`site_planner.gd:183-188` now sets `nav_trimesh` meta instead of `nav_box` for
`mesh: true` entries, and `nav_baker.gd:599-603` routes those through
`_walk_shapes` rather than the footprint carve. Interiors bake open. The player
safe-room Pillar-1 problem is closed.

### FIX 0d (`terrain_watchdog` roof teleport) and FIX 3 (ally seating) — **FIXED.**

`scripts/missions/terrain_watchdog.gd:60` and
`scripts/missions/field_director.gd:48` both call `world.floor_y(...)` now, each
with the reason written above it.

### THE NEW DEFECT THAT LANDED TODAY — the roof cull is defeated for 3 of its 5 targets

Today's `19b2bed0` added `NAV_ROOF_CULL_PREFIXES` (`nav_baker.gd:507-509`):
`fb_gp_tent`, `fb_mess`, `fb_bunker_mg`, `fb_bunker_fighting`,
`fb_sleeping_bunker`. `_cull_roof_faces` (`:518-525`) matches on **`owner_name`**,
which `_walk_shapes` reads as `cs.get_parent().name` (`nav_baker.gd:482`).

But `site_planner.gd:1723-1726` lists `fb_bunker_fighting_i`, `fb_bunker_mg_i` and
`fb_sleeping_bunker_i` in `FSB_STRUCTURE_KINDS`, and `_adopt_structure`
(`:1772-1811`) **moves their CollisionShape3D off the imported StaticBody3D and
onto a freshly-constructed `Destructible`** (`:1805-1806`), which then joins
`FSB_NAV_GEOM_GROUP` at `:1810`.

**After adoption the shape's parent is a `Destructible` with an engine-generated
name. It begins with none of the five prefixes.** So `_cull_roof_faces` returns
those faces unchanged and **the bunker roofs bake as walkable floor again.**

By the file's own measured areas (`nav_baker.gd:503`): bunker_fighting 341.7 m² +
bunker_mg 256.8 + sleeping_bunker 192.1 = **790.6 m² still walkable**, against
gp_tent 154.0 + mess 44.7 = 198.7 m² actually culled. **~80% of the roof area the
fix was written for is untouched.** The MG bunker Caleb made mannable today
(`e584d812`) is one of the three.

Same mechanism threatens `NAV_IGNORE_PREFIXES` (`nav_baker.gd:450`), but only for
adopted names — `fb_hootch_roof_` and `door_` are not in `FSB_STRUCTURE_KINDS`, so
those two still work. I verified the GLB naming holds:
`fb_hootch_roof_*-colonly` exists (354 roof nodes) and **`door_*` has zero
`-colonly` twins** (parsed `fsb_main_v3.glb` today) — the screen-door contract is
intact.

**Fix (~6 lines):** in `_adopt_structure`, `d.name = mi.name` before
`_parent.add_child(d)` (or stash `d.set_meta("nav_name", mi.name)` and have
`_walk_shapes` prefer the meta over the parent name). Naming the Destructible
after the mesh restores every prefix contract at once and is the version that
cannot rot.

### The gate is not a choke — [OK]

`site_planner.gd:1185-1199` `fsb_gate_metrics` derives the gate from the GLB's
`SOCKET_A_001` / `SOCKET_B_001` markers. Parsed from
`assets/world/building models/structures/firebase/fsb_main_v3.glb` (re-exported
today, 2026-08-12 22:26, now **5,475 nodes** — up from the 1,259 the handoff
describes, so that section of the handoff is now stale):

- `SOCKET_A` (−75.742, 2.870, 24.082), `SOCKET_B` (−71.517, 2.870, 32.029)
- **aperture = 9.00 m.**

`AGENT_RADIUS = 0.5` (`nav_baker.gd:45`), erosion each side → **~8 m of walkable
gate**. Against a 0.4 m capsule (`enemy_base.gd:437`, `ally_base.gd:476`) that is
eight men abreast. **The gate is not the jam.** And `avoidance_enabled = false` is
explicit on all three agent classes (`enemy_base.gd:3052`, `ally_base.gd:2164`,
`civilian.gd:272`), so RVO cannot narrow it either — the tradeoff being that men
*will* interpenetrate rather than queue.

### Hooch spacing — the honest answer

I could not measure per-hooch doorway clearance without opening the GLB geometry
buffers, which is beyond a read-only pass. **No pointer found** for an authored
minimum aperture in the firebase (the `>= 14m between any two structures` rule at
`site_planner.gd:228` is the **village** stamp, not the firebase). What I can say:
the firebase bakes from real `-colonly` trimeshes, so the clearance is whatever
Blender exported, eroded by 0.5 m per side. The screen-door spec in the handoff
gives leaves of 0.80 m each → a **1.6 m aperture → ~0.6 m walkable after
erosion**. That survives, but with 10 cm of margin over the 0.4 m capsule. **This
is the number to measure after the next export**, and `tools/probe_interior_nav.gd`
and `tools/probe_compound_nav.gd` (both untracked, written today) appear to be
exactly the instruments for it.

---

## 4. Two things I did not find, stated as findings

- **No pointer found** for any distance- or LOS-based re-evaluation of the
  hot set. `enemy_squad.gd:75-87` is first-come-first-served, permanently.
- **No pointer found** for any probe that validates `hip_position` against its
  GLB rig root. Four shipping weapons are wrong and the suite is silent.
