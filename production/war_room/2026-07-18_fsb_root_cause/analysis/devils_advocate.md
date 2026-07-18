# Devil's Advocate — FSB root cause & decree critique (2026-07-18)

Read: briefing.md · mission_generator.gd · site_planner.gd · game_flow.gd (enter_hub, _teardown_world) ·
damage_system.gd · terrain_watchdog.gd · nav_baker.gd · lazy_group.gd · mission_scope.gd ·
paddy_stamper.gd (grep) · test_patrol_world.gd · ADR-029 · ADR-015.

---

## 1. Does the two-cause story explain the SCREENSHOT?

**The geometry claims stand. The visual claims do not.** The two causes explain what the *probes
measured*, and only partially what the *Summoner saw*.

### What each cause actually explains
- **CAUSE 1 (craters)** explains the +7m "buried" footprint samples (rim = 0.02 norm × 400 height
  scale = 8m at intensity 1.0) and wire cards hanging over a bowl. Code order confirms it: plateau
  flatten runs at build (`site_planner.gd:549-551`), craters dig AFTER it
  (`mission_generator.gd:492-493`), every build, deterministically. This cause is solid — as a
  *measurement* explanation.
- **CAUSE 2 (gate cluster at +4.68–4.92m model space)** explains "floating a few feet above FLAT
  ground" at the spawn: the plateau gives the flat sandy ground, the mis-seated cluster gives the
  float. This is the only cause consistent with the screenshot's foreground.

### The flat-ground tension
A crater is a bowl. The screenshot shows FLAT sandy ground under the floating pieces. So **if the
floating pieces in frame are wire cards over the crater (cause 1), the ground under them should be
visibly bowled — contradiction. If they are gate-cluster pieces (cause 2), the flat ground is
consistent.** The briefing implicitly assigns the screenshot to cause 2 and the probe numbers to
cause 1, which is coherent — but it never *demonstrates* the partition. The Summoner reported "two
gate/fence panels": wire panels are cause-1 territory, gate panels cause-2. As written, the two
causes conveniently split the symptoms with no evidence saying which piece is which.

**Headless discriminator:** after `build_patrol_world`, enumerate every MeshInstance3D within ~60m
of `spawn_pos` whose world AABB bottom sits >1m above `terrain.get_height_at()`; print names.
`bwire_card_*` in that list ⇒ cause 1 is in frame and the flat ground is a real contradiction;
GATE-cluster names only ⇒ cause 2 owns the screenshot. Fully headless.

### "Gray untextured" fits NEITHER cause — and the briefing's own probe holds the third suspect
Probe #1 declares the asset HEALTHY at **488/664 surfaces textured. That is 176 untextured
surfaces — 26% of the model — inside the "healthy" verdict**, and the screenshot symptom is
literally "gray untextured pieces." Nobody cross-referenced the 176 against the gate cluster. If
the gate cluster's 25 meshes are among the 176, the entire screenshot (gray floating gate hardware
on flat ground) is explained by cause 2 + an *unnamed third defect: the visible cluster has no
materials*. Then FIX 1 + FIX 2 both land and the spawn STILL greets Caleb with gray hardware — a
fourth "fix that didn't take," judged by his eyes per rule #1.

- **Headless:** extend `diag_fsb_clusters` to print, per cluster, surfaces with
  `albedo_texture == null` (and material == null). Cheap, decisive.
- **Not headless:** a surface can carry a texture and still render gray (s3tc/VRAM-compress import
  failure, shader/UV issues). Pixels need one supervised windowed run — Caleb is at the live
  window; ask him to look, never spam windowed instances (standing law).
- **Ruled out by code read:** R92 visibility-range culling — `place_firebase_main`
  (`site_planner.gd:554-560`) never calls `_apply_visibility_range`; the only appliers are
  `place_structure`/`place_prop` (`site_planner.gd:164,330`) and ground clutter. "Sparse" is not
  distance cull of the fsb.

### "Pancaked slab" and "sparse" fit neither cause
The cluster audit measured *bottoms*, not *heights* — a floating cluster does not pancake. A
collapsed-Y cluster is a distinct export defect class the audit didn't test (headless: per-cluster
AABB height vs authored height). And with a healthy 658-mesh ring, a viewer 22m from the gate
should see the whole 25-mesh gate complex arcing away — not four pieces. Both symptoms fit
YESTERDAY'S scattered export better; the briefing concedes logs rotated and provenance is
unprovable, then waves it off with "the report stands either way." That hand-wave is load-bearing:
**if the screenshot predates 17:20, "sparse/pancaked" may already be fixed and the residual defect
is only the +4.8m float + whatever the material audit finds.** The next run's `[SPAWN-TRUTH]` line
(`game_flow.gd:242`) plus the near-spawn mesh census settles provenance for good.

---

## 2. What the keepout SACRIFICES (name it, per council law)

1. **First-sign density in 1–2 quadrants, permanently and deterministically.** Sign quadrants are
   world-axis (`mission_generator.gd:452-456`), not gate_out-relative; the quadrant containing
   −gate_out points across a ~344m base. Band 170–280m from the gate vs rect+70m keepout reaching
   ~414m inward: that quadrant can NEVER place a compliant sign. "A quadrant that cannot clear the
   wire yields NO sign" sounds like an edge case; it is a structural, every-seed loss.
2. **The probe contract breaks.** `test_patrol_world.gd:123-131` FAILS any quadrant whose nearest
   first sign is >320m — with zero signs, `best` stays 1.0e9 and the suite goes red for the wrong
   reason, on the same day the decree ships its intentional red. ADR-029 §3 ("first-sign 150–300m
   ... Probe-asserted") must be amended in the SAME change, or the decree violates its own canon.
3. Also lost: crater ponds near the wire (`_spawn_crater_water`, 40% roll) and the "base built on
   shelled ground" read on the approach — minor atmosphere, but real.
4. **The 70m inflation hard-codes a derived quantity.** Max crater radius = radius_cells 12 ×
   intensity 1.3 × cell size ≈ 62m — margin is ~8m, and the FOLLOW-UP bead proposes retuning those
   very profiles. Derive the inflation from the profile at call time or the constant silently
   under-covers after the retune.
5. Cheaper alternatives the decree never weighs: (a) aim sign quadrants relative to **gate_out's
   outward half-plane** — density stays where the player actually walks, count preserved; (b)
   inside-rect signs become **scar-decal-only "filled craters"** (no `modify_terrain`) — engineers
   filled them when the base was built; quadrant density kept, terrain untouched, historically
   correct.

---

## 3. The "expected FAIL" probe

Shipping honest red has **explicit ADR-015 precedent** — its Consequences section: *"the suite is
expected to fail for a period — the team must tolerate honest red instead of comfortable green."*
So no, a knowingly-red MODEL-SEAT verdict is not a verification-law violation; hiding the defect
would be. **But chronic red is how red-blindness starts** (ADR-015's "blind green," mirrored), and
a plain red verdict cannot distinguish "still the known defect" from "the re-export broke
something new."

**Cleanest form — the signature-locked ratchet:** MODEL-SEAT passes (prints `KNOWN-BAD, bead <id>`)
while the defect matches the *exact recorded signature* (gate cluster bottoms 4.68–4.92m ±ε,
hootch 2.69, crates 2.26, count 120); it FAILS on (a) the defect vanishing — unexpected pass forces
promotion to a hard assert in the same commit — or (b) ANY drift from the signature — a re-export
that fixes the gate but mis-seats a new cluster is caught, not camouflaged by the expected red.
Suite stays green, the defect stays named, the ratchet only tightens.

Additional un-critiqued weakness: **`FSB_HALF`, `FSB_CLEAR_DISCS`, and the marker cache are
hand-measured constants** (`site_planner.gd:459-473`). The decree orders a re-export that can
re-center or re-size the AABB, silently invalidating the crater keepout rect, the clear discs, and
CRATER-CLEAR itself. The finalized probe must assert the constants against the GLB's actual AABB,
or the re-export fixes cause 2 while quietly breaking the fix for cause 1.

---

## 4. The NEXT recurrence — build-time systems still able to reach inside the wire

**Live threat the decree does NOT cover:**
- **`mission_generator.gd:504`** — ambient-patrol LazyGroup placement:
  `_passable_near(world, rng, mid, 30.0, 120.0)` where `mid` lerps gate→village (0.3–0.7). For the
  nearest village (~240m) mid can sit ~72m from the gate; a 120m draw pointing back through the
  gate lands ~48m INSIDE the base. `activation_range = 140` (`:508`) and the player spawns 22m
  outside the gate — within range — so `lazy_group.gd:59-74` spawns 2–4 VC inside the wire on
  minute one. FIX 1 names first_signs, village/camp fallbacks, and patrol anchors; this call site
  passes nothing.

**Live until FIX 1 lands (named in decree — confirming they're real):**
- `mission_generator.gd:431-432` village fallback `_passable_near(gate + dir*360, 0, 80)` — no rect
  check anywhere in `_passable_near` (`:87-97`); an inward fallback stamps a village INSIDE the
  wire, and `stamp_village` → `clear_and_flatten` (`site_planner.gd:212`) mutates terrain/veg/grid
  there, then `_spawn_enemy_groups` (`:583-589`) garrisons it with VC and
  `apply_veg_boosts` (`game_flow.gd:316-317`) thickens jungle around it. One bad seed = a VC
  village inside the firebase.
- `mission_generator.gd:443-445` camp fallback (370–510m — mostly clears the 344m base, marginal).
- `mission_generator.gd:114-118` `_patrol_anchors` filler sweeps a 120–480m ring around a point
  22m outside the gate — circuit waypoints inside the wire.

**Design flaw over all of these: the keepout is opt-in.** `_passable_near` defaults to NO keepout;
every future caller (there will be one) re-creates this bug silently. The divergent-systems lesson
says the rect must live in ONE authority (`planner._fsb_rect` already exists,
`site_planner.gd:18`) and be honored by default, opted OUT of explicitly. A parameter added per
call site is the same class of fix as the three that didn't take.

**Cleared by code read (naming so the council stops re-suspecting them):**
- `terrain_watchdog.gd` — re-seats *bodies* only (`:55-58`), never writes terrain.
- `nav_baker.gd` — navmesh only; fsb excluded from bakes (`mission_generator.gd:529-532`).
- DamageSystem cross-build leak — `MissionScope.reset()` runs in `_teardown_world`
  (`game_flow.gd:114`) and calls `clear_all_damage()` (`mission_scope.gd:42-44`); crater budget
  and decals reset per build.
- `paddy_stamper.gd` — reads grid/terrain only (greps: `get_terrain_type_at`, `get_height_at`);
  not a mutator despite the name.

**Two adjacent finds (report, not fight):**
- `plan_firebase_main_center` (`site_planner.gd:506-528`) has **no hard reject at all** — water and
  reserved-point proximity are soft score penalties (−10/−25); a hostile map can seat the base
  overlapping water/paddy. `_footprint_valid` is never consulted for the fsb.
- Key-drift fossils: `_patrol_anchors:109` and `_enemy_anchors:361` read `firebase_center` /
  `camp_center` / `village_center` — none of these keys exist in the patrol plan (it carries
  `fsb_center`, `camp_centers`, `village_centers`). Harmless today (it's why the fsb is luckily
  absent from anchor pools), but it is exactly the lie-in-the-map ADR-023 exists for, and
  `_enemy_anchors` starves NavBaker's `should_bake` of intended anchors.

---

## Bottom line
CAUSE 1 and CAUSE 2 are real, measured, and code-confirmed — as explanations of the probes. The
SCREENSHOT is only half-claimed: gray/sparse/pancaked are unexplained by either cause, the 176
untextured surfaces sit unexamined inside the briefing's own "HEALTHY" verdict, and export
provenance is conceded unprovable. The decree fixes this instance with an opt-in parameter while
the recurrence class (build-time mutators ignorant of the wire) stays open at
`mission_generator.gd:504` and in every future `_passable_near` caller. Amend
`test_patrol_world.gd:123-131` + ADR-029 §3 in the same change as FIX 1, signature-lock the
MODEL-SEAT ratchet, assert FSB constants against the asset, and run the two headless material/
provenance audits BEFORE declaring the screenshot explained.
