# CALEB'S LIST — everything on YOUR plate (2026-07-10)

## 0000-A. DONE 2026-09-09 (night) — the white box in the mortar pit, and a plant in the villagers' hands

Two jobs, both shipped, both gated. Nothing here needs your ruling; the open calls are at the
bottom of this section.

**1. `us_fb_ammo_crate_stack-colonly_P2` is gone from the export.** It was never a mislabelled
prop: a 24-vert / 12-tri box hull with no UV and no material, at distance 0.0000 from the real
crate, that had escaped `clear_collision()` because the `-colonly` marker sat in the MIDDLE of
its name. Godot therefore imported it as a visible mesh and drew it in default **white**,
z-fighting the textured crate in the P2 pit. Renaming it to `us_fb_ammo_crate_stack_P2` - the
obvious fix - would have been worse: that name is the real crate's, Blender appends `.001`, and
`make_collision` splits on `.`, so the untextured box would have shipped VISIBLE **and** picked up
a collider of its own. It is now `us_fb_ammo_crate_stack_P2-colonly`, marker at the end, so the
export strips it and it ships nothing. Full contract diff in `PERF_LEDGER.md` (2026-09-09 night):
one node removed, zero added, 17 predicted collider index shifts all exactly -1, every prefix
family unchanged. GLB md5 `e47eba8dd1cca16962c5c05a9f32be06` -> `6461852eff7c0c9e6dbb885b296767c7`.
**The shipped firebase now contains ZERO visible material-less meshes** - that closes the
firebase's share of the demo audit's "white surfaces on the walked path", and only the firebase's.

Three gates so it cannot ship a fourth time (it shipped in the 08-12, 09-06 and 09-09 exports):
`gen_firebase_v3.assert_colonly_terminal()` before the exporter runs · `reexport_firebase_v3.audit_colonly()`
on the shipped bytes · `tests/test_fsb_colonly_contract.tscn` on the imported Godot scene.

**2. A villager working a paddy now holds what he is planting.** Your ask, verbatim: *"even when
villagers are doing the work animation in the rice fields give them a plant in their hand."*
The clip was already the right one - `plant_seeds`, the kneeling ground-work read, at
`scripts/world/civilian.gd:74` - so no motion was authored. The gap was the prop:
`tools/make_civilians.py` welds a rice bundle onto only **2 of the 10** civilian variants, so
eight villagers in ten planted with empty fists. `civilian.gd._set_seedling()` now hangs your own
`rice_bundle` on `mixamorig_LeftHand` for the duration of the work clip and takes it away
afterwards. It uses YOUR placement, read straight off `civ_farmer_f_c.glb` rather than solved -
parity **0.000000 m**, gated by `tests/test_villager_seedling.tscn` with a control lane that fails
if a wrong transform would also pass. Left hand on purpose: `rice_sickle` is welded to the right
on `civ_farmer_m_b`, so a cutting farmer holds both.

### YOUR CALLS (nothing is blocked on these)
- **Should the bundle read as the same species as the paddy rice?** It uses `rice_bundle.glb`
  (104 tris, `gear_palette`) - your civilian locker prop. The rice the other agent is planting in
  the paddies is `rice_a/rice_b.glb` (84 tris, `jungle_palette`), a 1.2 m ground clump with no
  hand placement. Using the paddy species would mean authoring a second model and solving a grip
  you already solved, so it was not done. If the two greens read wrong side by side, say so and
  the palette gets matched.
- **Should the seedling also appear for the firebase working party?** It does not today - the
  detail man's `plant_seeds` reads as filling sandbags, and he already has the e-tool.
- **`test_suite_health` is RED and was red before this work** - 21 stranded `probe_*` scripts the
  runner never invokes, against a ratchet register holding only 2. Not touched here; it is its own
  job.

## 0000-0. READ FIRST — WHY YOUR MEN ARE STANDING AROUND. Needs your ruling, 2026-09-09

You have said this twice: **"its got people standing around but they arent performing"** and
**"all the soldiers just sit around."** Here is a cause, measured, and it is not a small one.

**glTF carries no loop flag.** Every clip arrives play-once, and the loader marks the cyclic ones
by NAME. Counted across all 232 clips in the shared library: 97 are marked to loop, **135 are
not** — and a large share of those 135 are HELD POSES AND WALK CYCLES. **A clip that plays once
and stops leaves the man frozen on its last frame.**

**Every one of these is a post you walk past and see nothing happening at:**

| the man | his clip |
|---|---|
| the M60 gunner on the wire | `m60_gunner_idle_l/r`, `m60_gunner_scan_l/r`, `m60_gunner_fire_l/r` |
| the howitzer crew | `gun_gunner`, `gun_loader`, `gun_agunner`, `gun_ammo_bearer` |
| the mortar crew | `mortar_gunner`, `mortar_dropper`, `mortar_runner` |
| men in the hooches | `hooch_locker`, `hooch_poker`, `hooch_radio` |
| the chow hall | `chow_cook_stir/check/prep`, `chow_serve_ladle`, `chow_tray_hold/wait`, `chow_eat_seated`, `chow_talk_seated_a/b` |
| the officers at their desks | `office_write`, `office_smoke` |
| the litter bearers | `litter_carry_front/rear`, `litter_load_front/rear` |
| the aid station | `med_tend_medic/patient`, `med_surgeon_table`, `med_wounded_idle`, `med_rounds_glance` |
| a man leaning on cover | `cover_wall_lean_idle` |
| seated men | `sit_bench_upright`, `sit_lip_outboard_a/b` |
| **every zombie** | `zombie_walk`, `zombie_run`, `zombie_crawl`, `zombie_stumbling`, five idles |

**WHY IT IS NOT ALREADY FIXED, and this is the whole reason it needs you.** The obvious repair is
to loop everything in those families by prefix. **That would loop a death animation.**
`zombie_death`, `zombie_dying`, `chow_sit_down`, `chow_stand_up`, `chow_tray_dump`,
`cockpit_dead` and `office_desk_transition` sit in the same families and are correctly one-shot.
A man dying forever is worse than a man standing still.

So it has to be done clip by clip, and that is a judgement about how the whole cast moves — which
is yours, not mine. **The ask is small: confirm that a held pose should loop, and the list above
gets worked through one name at a time with the one-shots left alone.**

Measured by `tools/probe_loop_flags.gd`. Related and already settled: inverting the loop list is
REFUTED (97 loop vs 135 one-shot — the inverted list would be three times longer).

## 0000-A. THE SIEGE PLAYTEST — your five defects, worked 2026-09-09

You played the siege by hand for the first time in the project's history (the assault normally opens
24 minutes in; `--stress` brings it to 45 s). Five defects came out of it. Four are fixed; the fifth
is two questions only you can answer.

### FIXED — and the reason your run could not have judged the fight

**0. `--stress` fought the night assault in daylight — mine, and it invalidated the rest.**
The flag collapsed the approach but not the clock, so the assault opened at ~06:57 instead of ~20:25.
Illumination flares, night sight caps and muzzle-flash spotting never ran at all. The stress boot now
jumps the clock to the hour the shipping arc reaches at its own assault and emits the period crossing
`set_time` skips (`scripts/levels/demo_game.gd`, `_stress_boot_hour` / `_seat_the_stress_night`).
Measured: `[STRESS] clock seated at 20:10 (NIGHT)`, and the illum walk now appears in the log where it
was absent from yours. **Treat every judgement from your run as made in the wrong lighting.**

**3. The attackers never breached because all 80 wall segments were at the compound centre.**
`fsb_main_v3.glb` is a flat scene: 80 of the 81 parapet nodes carry no node transform, the geometry is
baked into vertices, and `SitePlanner._wire_parapet_segment` seated each `Destructible` at
`mi.global_position` — the model root. Every system that reads a wall position was reading the middle
of the base: sapper targets, the perimeter measure, the overrun call, the breach scan, the blast bus.
Your log shows it: 14 sappers, 14 identical lines `[SAPPER] -> sandbag_wall at 256,256`, zero charges
planted, zero holes. Now seated from the baked AABB, with a boot audit that fails loud if the parapet
ever collapses to a point again. Measured after: `[FSB] parapet radii: 81 segment(s) spanning
49.4-96.0m` (the manifest says 49.3-96.1), 14 sappers on 14 distinct segments, 3 satchels placed,
3 breaches blown, `5 cell(s) press through the hole` each time, and the navmesh re-baking the hole.

**1. Enemy mortars killed the garrison through walls, roofs and bunkers.**
`_blast_defenders_only` was a bespoke faction-scoped damage query with no line-of-sight test, no cover
roll, no falloff shape, no stagger and no suppression — the exact thing `projectile_base`'s own comment
forbids. A man inside a bunker took the full 140. It now routes through
`CombatManager.apply_explosion_damage` like every other explosion, with one new flag (`spare_enemies`)
that keeps the only legitimate reason the bespoke path existed: the enemy's own prep fire must not
break the enemy's own assault. Defenders now get cover, the 0.4x indirect-fire reduction, knockback,
stagger and suppression — which is also the first pre-death reaction they have ever had to a shell.

**2. Men who could not be promoted at stand-to stayed civilians all night.**
`_garrison_stand_to` latched on its first call. Anyone the first pass could not take — a puppet working
the gun, a man on the lift, a body frozen mid-seat — stayed an unarmed civilian for the rest of the
fight, and so did **every replacement the resupply flew in mid-assault**. Your run delivered 9 men into
a firefight as noncombatants. It now re-scans while the wire is in contact. Measured:
`promoted 35`, then `promoted 4 (late)` twice, matching the two deliveries.

**4. Friendly NPCs on roofs — the recurrence, not the spawn.**
The spawn probe was already green; the defect was at runtime. `TerrainWatchdog`'s fall-through re-seat
ran `surface_y` every 2 seconds on every live body — a top-down ray that takes the FIRST hit, which
under a roof is the roof. Its sibling eleven lines above had been converted to `floor_y` in August with
a comment naming this exact hazard; the fall-through branch was left behind. That is why the defect
survived two previous fixes: **a correct spawn was being undone every two seconds forever.** Also fixed
the datum it fed on — `SitePlanner.fsb_garrison_plan` built marker heights on `center.y`, which is
`0.0` in the full game and a single pre-sculpt sample in the demo, not the footprint-mean height the
model was actually seated at. Re-seats now print themselves instead of teleporting men silently.

### YOUR CALL — two questions, both about how the fight is DESIGNED, not about a broken system

**Q1. Should the enemy shell the compound before the assault at all?**
`CampMortar` opens harassment fire at T+600-1020 s aimed at the exact centre of the base at maximum
(50 m) dispersion, while the siege is still 6-13 minutes away. In the shipping 24-minute arc that is
1-2 volleys landing on your garrison with no attacker anywhere on the map. It is now cover-checked and
survivable, but it is still deliberate prep fire on your men before anything is visible to shoot back
at. Keep it, delay it, or move its aim to a fringe offset instead of the middle?

**Q2. How lethal should the enemy barrage be?**
Enemy mortars: 18 m blast, 140 at the centre, a hard floor of 40 at the rim. Your own called fire:
10 m blast, same 140/40. So the enemy's tube is nearly four times the beaten area of yours, and the
40-point floor is an instant kill on an un-promoted garrison civilian (20 HP) anywhere in that 18 m.
Should the enemy tube match yours at 10 m, or is the asymmetry the point of a siege?

**Q3. Should a garrison man RUN TO THE WIRE, or hold the post he was working?**
Today a cook promoted at stand-to becomes a rifleman standing at the cook's post, `HOLD` with an 8 m
leash, facing outward. Most of those posts are deep inside the compound with buildings between the man
and the wire, so from your camera he reads as a soldier standing around in a firefight. Moving the
garrison to fighting positions is the single biggest change available to how the base reads under
attack, and it is a design change, not a bug fix — so it waits on you.

### REGISTER, TENTH PASS — the dark frame is named, and one ruling stays yours

**The unattributed physics steps are gone.** 107 of 110 this morning -> 28 of 111 after the
night's spans -> **0 of 6 sampled post-assault windows** with `ai.think` and `ai.execute`
wrapped. The cost was never hidden — `CombatManager.ai_usec_think` has counted it for months —
it was never ATTRIBUTED, so the ledger could say how much AI time a frame used but not whether
THIS frame was one. Measured: `ai.execute` 18,961 calls / 1,576 ms across the run.

**Hooch interiors no longer arrive in one frame.** All 545 shared a single visibility range with
no fade mode, so the margin was pure hysteresis. Thresholds staggered over 6 m, deterministic per
prop, so they arrive over ~10 frames of walking.

**YOUR RULING, and the stagger does not settle it.** 545 props, 1,010 surfaces, 43,941 triangles
inside a 40 m ring. Turning the fade on alpha-dithers them SEE-THROUGH (the ADR-026 opacity
bug); moving the range out to where a cot is genuinely sub-pixel costs draw calls. The standing
fix is folding each prop TYPE into one MultiMesh — 1,010 surfaces to ~11 — and that needs the
bake removed in the same change or every prop doubles. **This is a RENDER cost; the stall ledger
is script-side and headless cannot see it. Your eyes rule whether the stagger reads better than
the pop.**

**Not started, and named rather than half-built:** the jungle encounter. It is content, it wants
authored placement on walkable ground clear of a site stamp, and starting a new authored place
at the end of this session would be exactly the kind of half-finished thing the register exists
to prevent.

### REGISTER, ELEVENTH PASS — the crater is half the frame it was, and your collision ruling shipped

**Your ruling on terrain collision is BUILT and it cost nothing in accuracy.** Terrain is a
`HeightMapShape3D` now instead of a rebuilt trimesh. It is what bullets and boots hit, so it went
out with evidence and not an argument: the OLD shape was rebuilt beside the new one in the real
world and both were fired at, pristine and after a real shell.

| | straight down, 3,000 rays | grazing bullet lines, 600 rays |
|---|---|---|
| pristine chunk | worst **0.24 mm** | worst **0.8 mm** |
| after a crater | worst **0.24 mm** | worst **1.5 mm** |

Zero rays hit one shape and miss the other. Shape build on a real chunk: **4.4-8.4 ms -> 0.09 ms.**
`terrain.collision` has fallen off the bench report entirely (was 175 ms across a 6-shell phase).
One correction while I was in there: it was **8,192 triangles a chunk, not 32,768** - the standing
number assumed 2 m cells and the world ships 4 m.

**Two shells' worth of work was being done for every one shell.** A crater re-materialized every
chunk it touched twice: once when the vegetation was cleared, once when the dig actually landed a
frame later. The surviving pass is the correct one - it runs after the ground moves, so plants sit
on the new ground rather than the old.

**And the cache built for exactly this last night had never once hit.** It required a chunk to be
rebuilt at an epoch one higher than any rebuild could ever stamp. One character. I only found it
because I split the measurement into hits and misses first: `36 miss, 0 hit`.

**A blast now DELETES plants from the cache instead of throwing the chunk away.** Safe because the
generator draws every random value for a plant before it asks whether the plant is in a hole - so
removing entries cannot change the others. Checked rather than believed: regenerating the same
chunk from scratch after the shell gives **2,377 plants against 2,377, with zero differences.**

| crater phase, same bench, same seed | before | after |
|---|---:|---:|
| worst single frame | 175 ms | **130 ms** |
| whole phase in crater work | 723 ms | **454 ms** |
| canopy re-scatters per 6 shells | 36 | 18, and 16 of them free |

**A gate I have to report rather than quote: the bullet-damage probe passed one run in three.**
It is the probe the hitzone change was closed on last night. It aimed at a fixed height above a
man's feet, and a head is only there in some poses, so which idle frame he had settled into decided
the result. It asks the head where it is now: 4 runs, 4 passes.

**What is left in a crater frame, and it is the last of this queue:** the chunk mesh rebuild and the
canopy MultiMesh regen. Both exist because a 5 m hole still rebuilds a whole 256 m chunk. That is
the structural fix and it is not started.

### TWO KEYS FOR YOU TO PRESS WHILE YOU PLAY — F9 and F10, 2026-09-09

You ruled "ok do it all" on the open row, and then you ruled the bench itself out: *"cuz its just
terrain with no action so its not really gauging anything."* You are right, so the two questions
that were waiting on a bench are now switches in your hands. The game tells you the keys about four
seconds after the world loads, and every press prints on screen.

- **F9 — how far the GROUND COVER draws** (grass, rice, ferns; the trees are untouched).
  150 m is what ships now -> 100 -> 250 -> all the way out like the trees. Shorter takes frames back
  and thins the distant jungle floor. **Tell me which one looks like Vietnam.**
- **F10 — how sharp the distant models stay.** 2.0 is what ships -> 1.0 (smoother shapes, costs
  frames) -> 4.0 (coarser, cheaper). If you have been seeing far trees change shape as you walk,
  press F10 once and see if it stops.

Nothing is decided by me on either one. Whatever you press is the answer.

### REGISTER, TWELFTH PASS — the crater is a patch now, and one idea was built then thrown away

**A 5 m hole no longer rebuilds a 256 m chunk.** Per shell, per chunk, it now re-derives 121 of
4,225 ground samples and 144 of 4,096 quads, and the chunk's node and its physics body are not
touched at all. The proof is the only part that matters: a patched chunk was compared against the
full rebuild it replaced and **every one of 24,576 vertices, all 4,225 collision samples, 2,000
rays and all 2,132 plants across 338 canopy meshes are identical.**

**Half of that idea was built, measured and thrown away, and it is worth a line.** The plants could
in principle be lifted onto the new ground instead of rebuilt. They cannot - because the same shell
that digs the hole knocks trees down, so the list of plants HAS changed, which is exactly the case
that trick has to refuse. It never fired once. Deleted rather than left in looking useful.

**And it nearly stayed in on a false green:** my own check counted how many times the fast path was
TRIED, not how many times it WORKED. Tried 1, worked 0, and the check said PASS.

**NO RICE IS EVER PLANTED IN THE PADDIES.** The rice-paddy ground type is set to a 0% plant chance
(`vegetation_manager.gd:63`), so the two rice models are in the world's species list and have never
been placed once. Whether paddies should have rice standing in them is a look question, and yours.

**Also yours, on the same argument as F9:** bushes are 10,938 of the world's plants and a bush is
waist-high, not canopy. Cutting them at the same distance as the grass would take back far more
than the grass does - and would thin the mid-distance jungle noticeably. Say the word and it is a
one-line change.

### CONDITION 5 — the final clean measurement, 2026-09-09

**Box verified clear at BOTH ends.** 18 post-assault windows, one real breach in the run.

| | |
|---|---|
| physics windows over 120 ms | **1 of 18** (125.4 ms, a spawn frame) |
| idle windows over 120 ms | **1 of 18** (317.3 ms, and that window IS the breach re-bake) |
| `treebreak.consume` | **gone from the report** (was 55.4 ms worst) |
| `veg.regen_flush` (its replacement) | 19.6 mean / 24.7 worst |
| `spawn.man` | 20.4 mean / 30.8 worst (was 105-120 per man this morning) |
| `terrain.crater` | 65.1 mean / 102.1 worst |

**Exactly two offenders are left and both are named:** the nav breach re-bake at 313 ms, and a
single spawn frame at 125.4 ms. Nothing else in the 45-man assault crosses the bar.

Read the sample honestly: 18 windows. The 90-window run that first reopened this condition was
taken on a dirty box. A full-length run on a verified-clean box has still not been taken, so
this is the best measurement of the night rather than a closure.

### HIS RULING — the world outside the wire cannot be destroyed

Not a defect list; a cost. **Almost nothing you can blow up outside the firebase actually blows
up.** 18 of 26 village structures, 7 of 7 VC/NVA structures, 29 of 29 temple structures, and
every ruin, colonial and airfield building are wired to nothing.

What that costs you, concretely:
- **`market_hall` is thatch and survives napalm.** You can put a full CAS run through a straw
  building and it stands.
- **`pow_cage` is wood and cannot be blown open.** There is no way in but the door.

**This is a ruling, not a fix, because wiring them changes how a mission PLAYS.** A satchel
becomes a way through a wall; a LAW becomes an entry tool; "burn the village" becomes a verb the
player can actually perform. That is a design decision about what the sandbox affords, and it is
yours. The code side is a straight lift — `_wire_structure_destructibles` already exists and
matches by prefix; `place_structure` simply never calls it.

### REGISTER, NINTH PASS — the tree break, and an inversion refuted by counting

**Felling a tree rebuilt a whole 256 m chunk, immediately, twice when a blast spanned two.**
`treebreak.consume` has carried ~55 ms across three batches. The stored scatter is updated now
and the MultiMesh rebuilt one chunk per frame — using exactly the dirty-set mechanism the epoch
work built. Safe to defer because the felled tree is out of every OTHER path's scatter before
the call returns.

**The `_LOOP_NAMES` inversion is REFUTED by counting, before anything was written.** All 232
library clips classified under the live rules: **97 LOOP, 135 ONE-SHOT.** Inverting a 45-entry
hand list into a 135-entry one makes it worse. Do not re-propose it.

**But the count found something worse than the list.** A large set of HELD POSES and LOCOMOTION
CYCLES is classified one-shot, so each plays once and **freezes on its last frame**:
`m60_gunner_idle_l/r` and `_scan_l/r`, every zombie locomotion clip (walk, run, crawl,
stumbling, five idles), `hooch_locker` / `hooch_poker` / `hooch_radio`, the chow-hall held
poses, `gun_gunner` / `gun_loader` / `mortar_gunner` and the rest of the crew set,
`office_write` / `office_smoke`, `cover_wall_lean_idle`, `litter_carry_front/rear`,
`sit_bench_upright`.

That is the frozen-mid-stride defect at scale, and **very likely part of what you keep reporting
as men not performing.** NOT fixed: each of those families also contains real one-shots
(`zombie_death`, `chow_sit_down`, `cockpit_dead`), so a prefix sweep would loop a death
animation. It changes how the whole cast moves and it wants your eyes.

**Not started, with its number attached:** the nav collector amortisation — ~215 ms of collect,
~110 of it a cull that genuinely changes geometry. Turning the shape walk into a resumable pass
is the bounded next piece of work. And the dresser rehang, 17.5 ms, still needing an
invalidation design that survives nodes being added partway through the walk.

### REGISTER, EIGHTH PASS — nav.collect, and condition 5 down to ONE offender

**Measured on a box verified clear at BOTH ends** (the first time tonight that is true), 24
post-assault windows: **physics 0 of 24 over 120 ms, worst 111.7.** Idle **1 of 24 over — 298.7
ms, and that window IS the breach re-bake.** Previously 5 physics and 2 idle over, worst
228.9/468.6.

**Read that comparison honestly: 24 clean windows against 90 dirty ones.** The rate is much
better and the physics side is under budget, but a full-length run on a clean box has not been
taken, so condition 5 is *close*, not *closed*.

**Splitting `nav.collect` found that a third of it was an instrument I added tonight.** Of
365 ms: terrain 39.6, the collider walk 314.1. Inside the walk: **my ADR-042 roof-miss audit
97.9 ms**, the real flipped-winding cull 109.8 ms, everything else below the reporting floor.
The roof geometry does not change when a wall comes down, so the audit is gated to the first
bake. Measured on a real breach: **364.8 ms at world build, 294.8 ms on the re-bake.**

Answered rather than assumed: the bake IS async (the 365 ms is entirely the main-thread
collect), and the 1.5 s debounce DOES coalesce (three holes, one re-bake).

**What is left is a design decision, not a trim:** ~215 ms of collector, ~110 of it a cull that
genuinely changes geometry. The bounded fix is amortising the collider walk across frames — the
re-bake is already debounced and a hole that becomes walkable two frames later is invisible —
but that makes the shape walk resumable and is real work.

**HIS RULING, surfaced and not started: world structures are unwired for destruction.** 18 of 26
village, 7 of 7 vc_nva, 29 of 29 temple, all ruins/colonial/airfield. `market_hall` is thatch and
survives napalm; `pow_cage` is wood and cannot be blown open. Wiring them changes how a mission
plays, not just how it looks, so it is a ruling rather than a fix.

**Still not reached:** `TreeBreakSystem.apply_blast` ~55 ms, the `_LOOP_NAMES` inversion (half
done — the resource-keyed skip is in), and the dresser rehang at 17.5 ms with its number.

### REGISTER, SEVENTH PASS — the HIGH tier, and condition 5 REOPENS

**CONDITION 5 REOPENS. The six-window result was not the whole assault.** Across 90
post-assault windows the tail carries **5 physics windows over 120 ms (worst 228.9)** and 2 idle
(worst 468.6). Reporting it rather than letting the good number stand.

Remaining causes, in order: `nav.collect` ~400-465 ms on a breach re-bake (**and this DOES fire
mid-assault - my earlier "world build only" was true of a run with no breaches and wrong in
general**), `terrain.crater` ~110 ms, `treebreak.consume` 55 ms, `spawn.man` worst 104 ms.

**My own coarse epoch was costing.** One felled tree invalidated the scatter of every chunk on
the map, and an assault fells trees continuously - `veg.build_scatter` was back at 80.1 ms
inside the fight. Per-chunk invalidation now: **worst 21.4 ms**.

**Four of the five HIGH items landed.**
- **A GP tent and the mess hall were bulletproof.** The 128 nameless colliders are Godot-MINTED
  bodies, one per `-colonly` node, called `StaticBody3D` - a name carrying no information. The
  ballistics tagger reads the collider's name, so all 132 defaulted to hard. A probe says what
  they are rather than guessing: 80 parapet segments (hard is right by accident), three
  `fb_gp_tent_i` and one `fb_mess_i` (both on the soft list for years). Reads the parent now.
- **`Destructible._ready()` made HARD the default**, and the kind sitting in it was
  `hut_thatch`. Both lists explicit, unknown kinds loud - which immediately named `sandbag`.
- **The two arms-stripping lists disagreed**: one had `arms`/`forearm` and no `finger`, the
  other had `finger` and neither. A mesh named `finger_l` was stripped from the viewmodel and
  left welded to a dropped rifle. One list now.
- **The gore lookups name their misses** - a missing stump cap is open geometry where a man's
  arm was, and it was silent. **REFUTED as a live defect:** every rig comes back clean.

**Not reached:** `_LOOP_PREFIXES`/`_LOOP_NAMES` as a miss list (the resource-keyed skip is in,
the hand-maintained list is not inverted), world structures unwired for destruction (18/26
village, 7/7 vc_nva, 29/29 temple - and that one may be a ruling), `TreeBreakSystem.apply_blast`,
and the dresser's rehang walk.

### REGISTER, SIXTH PASS — the spawn stall, and both first guesses were wrong

**The assault stall is one man arriving, and it is now less than half what it was.**

The two candidates everyone reached for were both refuted by measurement before anything was
built. Instrumenting inside a spawn: the **GLB instantiate is 0.77 ms** and the material passes
are **0.44 ms**. The 45-53 ms of "model setup" was eight tree passes over the body, and one of
them was 6.0 ms on its own.

**`_apply_loop_modes` was the single biggest thing in a spawn.** After the shared library merge
a man carries 232 clips, and those Animation resources are SHARED, not copied - every man is
handed the same objects out of one static library. So setting a loop mode is a GLOBAL write
that the 65th man performs identically to the 1st: 65 x 232 redundant string matches and
property writes, inside the frame where he is supposed to appear. Applied once per Animation
RESOURCE now (never per clip name - two rigs can each carry their own `idle`, and a name-keyed
skip would leave the second one play-once, which is the frozen-mid-stride defect).

| | before | after |
|---|---|---|
| `sp.loops` | 6.0 ms/man | below the reporting floor |
| `spawn.model_passes` | 15.8 ms/man | 9.1 ms |
| **worst `spawn.man`** | **92.4 ms** | **62.4 ms** |

**A tree-walk cache I tried first bought nothing** and the commit says so. `_walk` was not the
cost. It is kept only because the iterative form beats the recursive one it replaced.

**What is left in a spawn, in order:** `spawn.dress` 17.0 ms - and inside it `dr.rehang`
17.5 ms against `dr.face` 3.4 ms, so it is hanging headgear, pack, chest and belt, not the face
atlas. `_set_visible_by_name` runs a full tree walk per needle and the rehang phase calls it
many times per man. **Not fixed on purpose:** the rehang functions ADD nodes partway through,
so a cached walk means a man in two hats or none, on a body the player is looking at. That
needs designed invalidation like the scatter cache had.
Then `spawn.anim_library` 2.66 ms (the ledger's 0.11 ms figure does not survive assault scale)
and `sp.height` 1.55 ms.

**The dark frame is mostly named now.** Unattributed worst-physics-steps in the assault went
from 107 of 110 to 28 of 111.

### REGISTER, FIFTH PASS — PERF, and done-condition 5 is finally measured

**THE ASSAULT STALLS. Measured, named, and it fails the 120 ms bar.** Nobody had taken this
number in three batches. Worst script spans in the 45-man assault, headless on `--stress`:

| cause | worst | what it is |
|---|---|---|
| `spawn.man` | 105–120 ms | ONE attacker, and two spawn per frame |
| `terrain.crater` | 131.9 ms | a shell straddling a chunk seam |
| `treebreak` | 52.7 / 50.7 ms | consume / spawn |

**`spawn.man` is the assault's real cost and it now has a breakdown**: `spawn.model_setup`
44–53 ms (instancing the body GLB) and `spawn.dress` 17–47 ms (the VC/NVA dresser). Both are
per-man work on a body instanced dozens of times in one assault — that is where the next fix
goes, and it is a bounded one.

**Fixed: every shell was re-deriving a scatter it already had.** The crater's cost was never the
hole (0.1 ms); it was `_build_scatter` walking a 256 m chunk again although a crater changes
none of its inputs — it moves the ground, not the plants. Cached with a coarse, deliberately
conservative epoch. Measured A/B, same seed, same 4,000 frames: worst crater per window
**83.0→70.9, 140.5→73.2, 126.8→65.1, 203.0→177.0, 73.1→42.3 ms**. About 40% off in four of five.

**YOUR RULING MOVED — heightmap terrain collision.** It was worth ~16–20 ms per crater among
several items. With the vegetation cost gone it is now the SECOND biggest thing in a crater
frame (15.7 of 61.5 ms, 26%), and there is no partial update for a trimesh collision shape, so
nothing short of that ruling touches it. **It got more attractive tonight, not less.**

**`nav.collect` 491.5 ms is real but is NOT an assault stall** — it fires twice during the world
build, before the arc opens. A load cost, not a fight one.

**Still not done:** `TreeBreakSystem.apply_blast` (~50 ms, confirmed real), the unattributed
idle/physics steps (107 physics + 105 idle steps in the assault still report no instrumented
cause), and the 545 hooch props appearing in one frame at 40 m.

### REGISTER, FOURTH PASS — roofs, radios and the hurtbox

**Fixed and pushed.**
20. **The TOC roof was walkable floor**, and so were all five latrine roofs — 17 navmesh
    polygons over the TOC, two or three over each latrine. A man could be PATHED up there
    deliberately, which is a different defect from the top-down re-seat that used to put him
    on a roof by accident. Both families culled; navmesh 8,782 -> 7,999 polygons.
21. **You could shoot a man's suspender clip and hurt him.** Every US grunt was harvesting
    eleven `web_*` clips, snaps and buckles into his hurtbox, plus the medic's brassard. The
    exclusion list carried "webbing" and had never matched anything, because the meshes are
    named `web_`. One underscore.
22. **A probe was passing ON that defect.** `test_hitzone_rebuild` needs two units with
    different hulls or it proves nothing, and its two only differed BECAUSE of the web gear.
    Fixing the gear made them identical and the probe went red — correctly. Its discriminator
    is a genuinely different body mesh now.
23. **The roof probe was wrong about the helipad.** A PSP pad stands 4 m proud with open air
    under it, which is that probe's exact definition of a roof, so it failed six men for
    standing where the resupply Huey had just set them down.

**REFUTED with a number.**
- Radios do NOT leak onto non-RTOs. Every unit in the demo was checked for a visible
  radio-looking mesh the opt-in list does not know. Zero. The check is permanent.
- Two of the five suspect roof structures — the supply dump and the water point — produce no
  uncut roof geometry at all. Two more are correct as they stand and are now marked so nobody
  "fixes" them: the towers are fighting positions with ladders built to them, and bunker steps
  are a floor.
- The first roof measurement reported 4,871 walkable polygons on one structure. That was a
  bounding-box artefact over the wire ring; the check judges building-sized footprints only
  now and names what it cannot judge.

**NOT STARTED, and honestly so — the queue is longer than the night.**
- `gib_system`'s six `find_child` calls with no null check (a limb vanishes with no gib).
- `_LOOP_PREFIXES` / `_LOOP_NAMES` — an unmatched clip plays once and freezes a man mid-stride.
- `Destructible._ready()` making anything not "wire" hard_surface.
- The two different arms-stripping substring lists.
- The 128 colliders literally named `StaticBody3D` — unjudgeable by name, which is ADR-042's
  thesis in its purest form.
- **ALL PERF.** The crater's 80–94 ms chunk rebuild, `TreeBreakSystem.apply_blast` at 66 ms on
  the physics tick, the 35–70 ms idle step with no attributed cause, and the 545 hooch props
  appearing in one frame at 40 m. **And nobody has yet measured the 45-man assault for a stall
  over 120 ms** — that is the last done-condition and it is untouched.

### REGISTER, THIRD PASS — the re-export and the 229

**The firebase re-export: the PIPELINE is proven, the vegetation swap is NOT done.**
The recipe on file was wrong. `gen_firebase_v3.main()` reads an empty file and rebuilds the
compound from constants — no chow hall, no medical complex, no staged crews — and never exports
at all; running it would have replaced your firebase with an older one. The real source is
`firebase_v3.2.blend`, and `tools/reexport_firebase_v3.py` is now the one command. **Proof: it
rebuilt the shipped GLB byte for byte** (same md5, same 5,812 nodes, manifest untouched, every
ballistics and parapet number identical). So the vegetation swap is now a change whose every
difference is attributable to the vegetation and nothing else.

**Why the swap itself is not in yet.** Measured the merged card geometry: 14 groups, ~1,000
quads, and each plant is ONE quad — the per-instance transforms are gone from the file, so a
swap has to recover position, yaw and scale from the quads. Footprints run from 0.98 m (grass
tuft) to 9.59 m with a 12.6 m z-span (jungle_palm_b3). A palm that big stamped at a wrong yaw or
scale is glaring, and no probe can judge it — only your eyes can. It is a bounded next job.

**Read the 229 hard-by-default families, and it found a defect I had just created.** Making the
hooch walls penetrable meant the thing that now stops a round fired into a hooch is a hanging
light bulb, a beer can or a girly mag. Bulbs, fans, beer cans and bottles, magazines, ration
cases, food trays and the hooch radio are concealment now. Soft 1,098 -> 1,249, hard 1,338 ->
1,187, unheard-of families 229 -> 214. **Furniture is deliberately left hard and is your call:**
lockers (33), chairs (44), cots, tables. A plywood locker does not stop 7.62 either, but that is
a design line, not a bug.

**The structure blast bus was silent when it failed.** `if by_kind.is_empty(): return` — an empty
result means every bunker, tower and sandbag stack in the compound is invulnerable, and it
printed nothing at all. It is a push_error now. It also revealed three prefixes that can never
match: the village huts, because the only caller is the firebase.

**Written into the art log, needs art not code:** no world weapon mesh carries a `MuzzlePoint`
marker, only your first-person viewmodels. That is why an NPC's flash still sits off the
receiver even though the direction is fixed.

### REGISTER, SECOND PASS — 2026-09-09, after the siege batch

**Fixed and pushed.**
10. **The witness rule had been broken for a month** (ADR-005 is binding law). A man heard his
    OWN alarm shout through the noise bus and re-anchored `last_known_target_pos` on his own
    feet, wiping the killer's position the witness rule had written there one line earlier.
    Every alerted enemy in the game swept outward from himself instead of toward the threat.
    Introduced 2026-08-12 by the commit that opened own-team voice ("the AI can finally hear
    itself" — it did). The bus now carries who made the sound; an ear ignores its own mouth.
11. **The rivers were cut six times deeper than the constant says.** The carve subtracted once
    per path point and the smoothed points overlap, so 1.2 m became a 7.97 m mean and a
    34.19 m worst, while the water sheet is seated from the pre-carve grade. Now a per-cell
    maximum, subtracted once: deepest cut 1.20 m against a 1.20 m cap.
12. **Two "broken" garrison men were cot patients** — posed puppets with no post and no
    schedule by design. The probe predated the aid station. Test fixed, not the code.
13. **The muzzle flash had no direction parameter at all**, and both quads were billboarded,
    so the flame spike was oriented in screen space. The bore is now threaded through all
    eight call sites; the spike aims down the barrel, the round core keeps its billboard
    because ADR-026 A.1 says the telegraph must read from every angle.
14. **Nobody on watch was watching.** `sentry_scan` / `nervous_scan` / `crouch_scan` are in
    the library, loop-flagged, and their only caller was the VC camp guard. Every US sentry,
    gun crew and radioman stood at the plain rifle idle.
15. **Nobody ever walked to a post.** Arrive radius 1.6 m was LARGER than the 1.5 m
    anti-overlap jitter, so the settle succeeded on frame one. Arrive is 0.7 m now.
16. **Every man started his loop at frame 0** — two men on the same clip were twins down to
    the frame. The de-sync code already existed and was wired to the baked props instead of
    the live men. Civilians get their own phase and a +/-12% speed now.
17. **The garrison budget paid for three men who do not exist** — two curated posts name
    markers absent from the GLB, skipped silently, still deducted.
18. **242 hooch walls and 262 casualty-figure colliders were bulletproof**, plus the chow
    hall and the canvas aid station. `fb_aid_station` was a dead prefix matching nothing.
19. **His two air rulings landed:** ambient transits 3/hour -> 1/hour, ambient flyby speeds
    -30%. Authored beats untouched.

**REFUTED with a number, do not re-litigate.**
- "Every tree, bush, fern and banana is blanket-tagged bulletproof." 12 of 27 species give
  cover (all trunks), 15 give concealment only. Printed at boot now.
- "Too many work options, so they idle too long." The opposite: 488 markers, 23 filled
  (4.7%), and the rotation dies after 12 men. `supply`, `bunker`, `watch`, `ammo`, `rest`
  and all 209 hooch markers get NOBODY.
- The T-pose could not be reproduced. A frozen-body audit runs at every build now (a visible
  skeleton with every bone on its rest pose), and the demo reports 10 visible rigs, none at
  bind pose. If he still sees one, it will name the body.

**HIS CALL — now five open questions.**
- Q1 pre-assault shelling · Q2 barrage lethality · Q3 garrison holds its post or runs to the
  wire (all three from the siege pass, above).
- **Q4: the garrison is far too small for the compound.** 36 men across 488 authored work
  markers. Raising `FSB_GARRISON_MAX_MEN` from 40 is the single biggest lever on "the base
  feels dead", and it is a design number, not a bug. The last measurement on record says the
  men are not the frame cost (48 FPS at both 24 and 40, mid-siege).
- **Q5: banana trees and fallen logs are bulletproof cover.** A banana pseudostem is water,
  not timber; `fallen_log_a/b` are flat ribbons the player is invited to hide behind.

**Found, still open.**
- 19 structures bake a roof as walkable floor (four towers, five latrines, the TOC).
- NPC muzzle flashes still use an ESTIMATED origin — no world weapon mesh in the project
  carries a `MuzzlePoint`, only the player's viewmodels. That needs art, not code.
- `test_squad` and `test_suite_health` were green on 2026-08-11 and are red now. Not chased.

### DEFECT REGISTER — 2026-09-09 session, nothing dropped silently

**Fixed and pushed (three batches).**
1. `--stress` fought the night assault in daylight. Clock now jumps to 20:10.
2. All 80 parapet segments sat on the compound centre. Seated from the baked AABB; sappers
   now blow real holes and cells press through them.
3. Enemy mortars killed through walls, roofs and bunkers. Routed through the shared explosion.
4. Stand-to latched on its first call; mid-fight replacements stayed civilians. Re-scans now.
5. `TerrainWatchdog` re-roofed men every 2 s with `surface_y`. Now `floor_y`, and it prints.
6. 242 hooch walls (`fb_hwall_*`) were bulletproof while their own roofs were penetrable.
7. 262 of 406 casualty-figure colliders were hard cover — a man's apron stopped a round.
8. The chow hall and the canvas aid station were bulletproof. `fb_aid_station` was a dead
   prefix matching nothing; the asset had been renamed `medical_complex`.
9. `test_firebase_garrison` had been timing out for a month waiting for a world
   `GameFlow._ready` stopped building. It drives the operation itself now.

**New instruments (each fails loud instead of passing silently).**
- `[FSB] parapet radii` — fails if the wall ever collapses to a point again.
- `[FSB] hard by DEFAULT` + `DEAD SOFT PREFIX` — the ballistics tagger names its misses.
- `[NavBaker] roof cull MISSES` — names structures whose roofs bake as walkable floor.
- `--pen-probe` — the firebase's ballistics, ratcheted. `tools/firebase_ballistics_baseline.json`.
- `[WATCHDOG] re-seat` — a live man being teleported is no longer silent.

**Found, NOT fixed, needs work or a ruling.**
- `test_witness_rule` FAILS (ADR-005 is a binding law): the witness is not anchored on the
  killer and the finder is not anchored on the corpse. Was green on 2026-08-11.
- `test_height_authority` REGRESSED since 2026-08-11: the water surface sits 26.71 m off the
  carved bed (tolerance 2.5 m). Terrain/hydrology, nothing to do with the siege.
- `test_firebase_garrison` now reports 4 real failures: two garrison men have no post and no
  behaviour tree at all — replacements flown in by the resupply Huey, minted at the pad.
- 19 structures bake a roof as walkable floor, 25,966 triangles: four towers, five latrines,
  the TOC, the bunker steps and the gate gap. Towers are MEANT to be walkable (they have
  ladders); the latrines and the TOC are not. Which of those five is a floor is your call.
- The nav bake's roof cull runs on the ORIGINAL winding only. The flipped pass culls
  universally, which is why this has not been worse.

### Still open, NOT fixed, flagged rather than silently changed

- The sapper doctrine's first-choice target is `"wire"`, and **no barbwire in the game is destructible
  at all** — the ring is a merged impostor with no blast-bus entry. Barbwire is your one standing art
  exemption, so whether it becomes breakable is your call.
- `enemy_base.gd:1715` deletes an attacker's assault objective permanently on first contact. With
  breaches working the objective is now re-issued through the hole, but a man who loses contact
  anywhere else still has no objective and no target and simply stops. This is why the rush turns into
  a static exchange.
- The assault breaks after losing about half its men (23 of 45), which is the authored ratio. If the
  fight ends too early for you now that they can actually get inside, that ratio is the dial.


## 0000. PLAYTEST 2026-08-27 - THE QUEUE LIVES IN ITS OWN DOC

All 35 items from your spoken notes are ordered and tagged in
`production/PLAYTEST_FINDINGS_2026-08-28.md` under `## QUEUE`. Read that first.

Fixed 2026-08-28, **all five unverified until you play them**:
- Air-support crash: `field_director.gd:860` cast a squad member to `AllyBase` before validating it,
  and `SquadSystem.members` never dropped a queue_free'd corpse (`ally_base.gd:2273`). Validate-first
  + `SquadSystem._prune_freed()` per physics frame.
- Gun-crew crash: `GarrisonDefender.promote` (`garrison_defender.gd:42,64`) calls `release_man()` and
  then `queue_free()`s the man; `release_man` never took him out of `_members`, so the freed node was
  read back as a typed `Civilian` on the next tick. Now released on the node's own `tree_exiting`.
- Item 7: the topo map sets `GameManager.is_in_menu`; `weapon_holder._handle_input` and
  `equipment_manager._handle_slot_action` gate on `can_player_act()`.
- Item 9: `scripts/world/satchel_charge.gd` (NEW) - 30-second fuse, count on the HUD
  (`MissionHUD.show_fuse`), mouth de-registers the moment the charge is set.
- Item 34: `scripts/ui/pause_menu.gd` (NEW) - ESC, RESUME / QUIT TO DESKTOP. `GameManager` still owns
  the pause state; the menu is only its face.

**Not verified by a headless boot** - the boot command was blocked by the sandbox this run. First
launch is the check.

Two structural findings that are NOT fixed and need a probe:
- A sweep only banks when you re-enter the wire (`field_director.gd:1821 _bank_patrol`). Nothing in the
  field ever confirms the objective is satisfied. That is why the mission felt broken.
- `WorkingPointResolver.resolve()` (`working_point_resolver.gd:20-28`) silently drops any working point
  it cannot resolve - bare `continue`, no warning, and it drops EVERYTHING if the site dict has no
  `root`. Prime suspect for both "under 75% of place-nodes fire" and item 24.


Everything code-side is built or tracked here; this is the hands-on Blender/eyes work only you can do,
roughly in dependency order. Companion: `BLENDER_ASSET_LIST.md` (full asset detail).

## 0001a. THE ONE WALK I NEED FROM YOU — added 2026-09-08 (later), this replaces step 1-3 below

**Read this before the older instructions under 0001; they were written against an instrument that
was not working.** `perf_before.bat` and `perf_after.bat` both wrote their `--print-fps` flag on the
wrong side of the `--` separator, so the counter never attached and **both logs you were asked to
compare contained no measurement at all**. That is fixed, and the fix is now self-checking: if the
counter fails to attach the log says `INSTRUMENT FAILED TO ATTACH` in capitals.

**Do this: double-click `perf_walk.bat`. Do the four-step walk printed at the top of it. Close the
window.** That is the whole ask. It writes a timestamped log that states its own settings, so it
cannot be mixed up with any other run.

Then tell me and I will flip the texture state and ask you for the identical walk a second time. Two
walks, roughly three minutes each, and they settle a question two months of work has been guessing at:
whether this game is slow because of what it is *drawing* or because of how *many separate times per
frame* it asks the driver to draw. Nothing else can answer it.

**AND IT IS A LOOK CHECK. Every texture in the jungle and on every soldier is now lossy-compressed.**
Look at the vines and the leaf edges in step 3 of the walk, and at a man's face up close. If anything
has gone blocky, crunchy or muddy, say so — it reverses with one command and a re-import, and no art
changes either way. **That call is yours, not mine.**

---

## 0001. PERFORMANCE PASS 2026-09-08 — TWO DOUBLE-CLICKS, AND ONLY YOU CAN TAKE THEM

The performance decree is built and headless-clean. **Nobody can tell you it is faster** — the discrete
GPU on this box is dead (ADR-026 Amendment C) and GPU milliseconds read zero headless, so the whole win
is unmeasured until you walk it.

**⚠ SUPERSEDED 2026-09-08 (later) by 0001a above — the instrument these three steps relied on was
broken when they were written. Use `perf_walk.bat`. The look-check below still stands.**

1. ~~Double-click `perf_before.bat`~~ — its log had no `[FPS]` line in it.
2. ~~Double-click `perf_after.bat`~~ — same.
3. ~~Compare the `[FPS]` lines.~~ — there were none to compare.

**AND IT IS A LOOK CHECK, NOT ONLY A NUMBER.** Three things to judge with your eyes on the AFTER run:
- **The jungle.** Leaf edges are now hard-cut instead of soft-blended. Does the canopy still read as
  jungle, or has it gone crunchy at the edges?
- **The night.** Vegetation is vertex-lit now instead of per-pixel. Grass and fronds should still go
  properly dark. If anything glows, say so.
- **The ground.** The jungle floor lost its specular sheen. Under a flare, does the mud still read wet?

If any of those is wrong, the entire material half reverses by deleting one call, and the render scale
reverses in the settings screen. Nothing here is one-way.

**One call is yours, and only after you have seen night:** the decree asked for UNSHADED grass and it
was refused and built as vertex-lit instead. Unshaded means the grass ignores the night light and glows
at full brightness in the dark — that hands your own concealment away and inverts the stealth economy.
It is one enum away if you want it after looking.

**Refuted by measurement, so it was not built:** the order also asked for the foliage to go
single-sided. It cannot. Zero of the 40 impostor cards are double-modelled (19 are lone quads, 21 are
crossed X pairs — every quad single-sided) and 116 of 117 near-ring plants are open shells. Back-face
culling this jungle would punch holes in it from half the compass. Making it safe means re-modelling
the whole plant library, which is the art-days the decree excluded.

**For the record, not for this pass:** the muzzle flash cannot aim down the bore. `gun_fx.muzzle_flash()`
takes a position and never a direction, all eight call sites pass only a point, the quads are
`BILLBOARD_ENABLED` (which throws away the node's Z-roll), and NPC flash origin comes from
`muzzle_ballistic()`'s forward-bias estimate rather than the weapon's MuzzlePoint. The 2026-09-06 scale
bump to 1.7x did not cause it, it exposed it. **The fix needs your ruling**, because bore-aligning the
spike shrinks the flash seen head-on, and head-on is exactly the telegraph the Fairness Law protects.

---

## 000. SPAWN-UNDER-FIREBASE — hardened 2026-07-30, still needs your eyes

You reported spawning under the firebase in the main game despite two authored `spawn_bunk` markers
by a hooch (`scenes/world/firebase_main.tscn`), and ruled: **regardless of seed, the firebase needs a
flat area that seats it properly — that shouldn't depend on luck.**

**Done:** `plan_firebase_main_center()` (`scripts/world/site_planner.gd`) now scores the FULL 7x7
footprint height range for every candidate site, not just the 6 clear-disc centers — flatness now
dominates the site pick, seed-independent. This is a real hardening fix for the general problem, not
a targeted patch.

**Not yet confirmed fixed:** your default seed (47225) was already documented in the code's own history
as the "lucky, flat" case — so this hardening may not be what's actually causing today's specific bug.
More likely cause: the two `spawn_bunk` markers were placed/eyeballed while testing the **demo** build
(seed 29072026, 512m map), and the main game boots a different seed/location where the mesh floor
under them sits differently. **Please check in-editor**: load the MAIN (non-demo) game, walk to the
hooch, and see if the mesh floor there is higher than where the markers sit. If so it's a marker-height
nudge, not a further code fix.

**UPDATE 2026-07-30, same thread:** you asked whether the fix needs to be world-agnostic since every
player gets a different generated world. Answer: for THIS bug specifically, no — the firebase model
(hooch, floor, roof, the two markers) is a fixed asset that moves as one rigid block every time; only
its overall placement varies per seed, never its internal geometry. So the marker's height relative to
the hooch floor is constant across every player's world, and a one-time nudge in `firebase_main.tscn`
fixes it permanently everywhere. I almost "fixed" this with a runtime raycast instead, but reverted it
— probing down from above an INTERIOR authored point risks hitting the hooch ROOF first, not the floor
(a failure mode this codebase already hit and documented at `game_world.gd:426-428`, which is why
`spawn_player_at`'s `seat_on_surface=false` path exists and deliberately skips raycasting for exactly
this case). The seed-VARYING part of this problem is the terrain seam at the model's edge, which the
flatness-scoring fix above already covers. No code changes needed for the interior spawn itself — just
your marker-height check.

**ACTUAL ROOT CAUSE FOUND 2026-07-30:** you reported the main game buries the player, squad, AND
garrison allies, while demo doesn't. Traced it — squad (`squad_system.gd:73`) and garrison
(`mission_generator.gd:911`) were already correctly using the safe `world.surface_y()` seat (fixed in
an earlier session for this exact bug class). The PLAYER wasn't: `game_flow.gd`'s `enter_hub()` had an
unconditional re-seat right after `spawn_player_at()` placed him correctly, using bare
`terrain_manager.get_height_at()` instead of `surface_y()` — it ran on EVERY boot regardless of
whether a save was actually being restored, clobbering the correct bunk-marker seat a few frames later
with the exact "buries anyone inside the firebase" height. **Fixed**: swapped to `surface_y()`, matching
squad/garrison. Also added a `push_warning` in `surface_y()` itself (`game_world.gd`) for the case
where its own raycast finds nothing and silently falls back to bare terrain height — that fallback was
invisible before; now your console will show it if it ever happens to squad or garrison too.

**STILL BROKEN after that fix — you confirmed still spawning below the firebase.** Ran a proper
3-way parallel investigation instead of guessing again (every write to player Y, a full demo-vs-main
boot diff, and a firebase-collider/physics-timing check). Found two more real bugs, both fixed
2026-07-30:

1. **A second, untouched reseat loop** — `game_world.gd:_physics_process()`, runs every ~2 seconds
   for the entire life of the world, was STILL using raw `terrain_manager.get_height_at()` (the same
   bug class as the one already fixed in `enter_hub()`, just a second occurrence in a different
   file, missed the first time). Per the "ONE GROUND" ruling, terrain under the firebase sits at the
   mound's TOE, well below the real interior floor — so if the player ever fell too far, this
   "safety net" would catch him and permanently replant him at toe height instead of the real floor,
   which reads exactly as "spawned below the firebase" even after the one-time enter_hub fix (that
   fix only touches the SPAWN MOMENT, never this ongoing loop). **Fixed**: swapped to `surface_y()`.

2. **A real physics race**, confirmed by grep (zero `await`/`process_frame` calls anywhere in the
   chain): the firebase's own colliders (its baked mound/floor body, remeshed vegetation/parapet
   trimeshes) get added via `add_child()` in `build_patrol_world()`, and the very next thing that
   happens is the `surface_y()` raycasts that seat the player/squad/garrison — same frame, no yield.
   Godot's `PhysicsServer3D` doesn't guarantee a just-added collider is raycast-queryable until the
   next physics step, so that first raycast could miss the firebase's own floor entirely and fall
   through to whatever terrain WAS already registered. **Fixed**: added two `await get_tree().
   physics_frame` yields in `enter_hub()` right after `build_patrol_world()` returns, before any
   seating happens, with the existing re-entrancy guard re-checked after each.

Full reasoning and the 3-agent findings are in the approved plan at
`~/.claude/plans/abstract-giggling-pike.md`.

**STILL BROKEN — but now we have proof of the actual cause, from your console log (2026-07-30).**
Both fixes above are real and correct but insufficient, because the problem was never the seating
*logic* — it's that **there is no collider at all under the interior floor near the hooch spawn
markers.** Evidence, straight from your log:

```
[SPAWN-TRUTH] asked spawn.y=193.56 | surface_y(spawn) now=189.18 | player landed at y=194.56 | seated=false
[SPAWN-TRUTH] seed=47225 spawn=1021,734 physics_y=189.18 array_y=189.18 delta=-0.00 top_hit=RaycastCollision player_y=190.17
```

The second line is a PRE-EXISTING probe (`game_flow.gd:_report_spawn_truth`, not written tonight)
that fires a single raycast down the ENTIRE column at the spawn XZ, from y=400 to y=-100.
`physics_y` (what it hit) and `array_y` (raw terrain height) are identical — `delta=-0.00` — and the
hit collider's name (`top_hit`) is `RaycastCollision`, the generic name Godot gives a **terrain
chunk's** collision body. That means across that whole 500m vertical probe, the ray hit nothing but
bare terrain — no firebase geometry at all. The marker sits at y=193.56; the only solid thing
registered in the physics world at that XZ is terrain at y=189.18, over 4m below.

**This is not a timing race and not a wrong-height-source bug — both of those are real and are now
fixed, but neither one applies here, because there is nothing to correctly find.** The firebase's
interior floor near this specific hooch has no collision mesh reachable in the running game. No
GDScript reseat/raycast logic can fix that; it needs the collision geometry itself checked.

**Needs your eyes in-editor/Blender, not more code:** open `firebase_main.tscn` (or the source
`fsb_main_v3.glb`/Blender file), select the hooch near the two `spawn_bunk` markers (world XZ
~1021,734 relative to a firebase centered near there — 39m from fsb centre per the `[SPAWN]` log),
and check whether that specific floor section has a collision shape at all. Given `[FSB] kept 1
mound collider(s) - the MODEL is the ground` in the boot log, it's possible the single kept mound
collider covers only the OUTER earthworks and never included this interior floor patch, or this
floor's collider was dropped/miscategorized during export. If you can tell me the mesh name for that
floor patch (or whether it has a collider in Blender at all), I can check whether
`site_planner.gd:_repair_glb_colliders()`'s repair pass is even looking at the right prefix for it —
right now it only touches `fb_terrain_mound` and `fb_veg_`/`fb_sbg_seg_` prefixes, nothing else, so
if the floor uses a different naming pattern it would silently pass through untouched either way.

**CORRECTED 2026-07-30, later same night — the "no collider" read above was wrong. Two real, live
bugs found and fixed, no Blender check needed for this specific cause (may still be worth doing as
a backstop, see below).** Ran a 3-agent read-only investigation instead of guessing again. The
`top_hit=RaycastCollision` in the log above IS the mound/terrain doing its job correctly — the
firebase's own ground-fit step (`site_planner.gd:place_firebase_main`) sculpts and audits terrain
against the mound on every boot ("`[FSB] ground: 129 samples ... worst +0.00m`" — terrain never
pokes through). The player spawns correctly (194.56, matching the 193.56 marker). What actually
drops him ~4.4m is **later terrain modification calls rebuilding the collider under/beside him
after he's already standing there**:

1. `TerrainManager.modify_terrain()` — called by the firebase's own `FSB_CLEAR_DISCS` flatten
   (`site_planner.gd:1037-1051`) and separately by authored "first-sign" craters
   (`terrain/systems/damage_system.gd:185`) — triggers `_rebuild_chunk_immediate()`
   (`terrain_manager.gd:70-85`), which frees the chunk's old collider and adds a new one
   **with no physics-frame guard**. The existing "COLLIDER RACE" fix (`game_flow.gd:600-611`)
   only guards the FIRST placement, before spawn — any later `modify_terrain` call (a crater
   authored moments after boot, near the firebase) is unguarded. Log proof: `[TerrainChunk]
   Chunk (3,3) mesh built` fires repeatedly AFTER both `[SPAWN-TRUTH]` lines — chunk (3,2) sits
   directly under the firebase, (3,3) is the adjacent chunk inside the 215m flatten radius.
   **Fixed**: `game_world.gd:_flush_terrain_dirty()` now re-seats the player (via `surface_y()`)
   immediately if a rebuilt region contains him — same pattern already used there for
   water/gameplay-grid re-seating after a terrain edit.
2. **This is also why your squad ended up UNDER the firebase model.** `TerrainWatchdog`
   (`scripts/missions/terrain_watchdog.gd`) polls `allies`/`enemies`/`civilians` every 2s to catch
   anyone who falls through terrain — but its catch logic used raw `terrain.get_height_at()`, not
   `surface_y()`. Since the mound model sits ABOVE raw terrain by design (one-ground law), the
   watchdog wasn't failing to catch your squad — it was actively "rescuing" them to a height
   BELOW the mound floor, every 2 seconds. **Fixed**: watchdog now takes the `GameWorld` and uses
   `surface_y()` for both its fall-through catch and its resume-from-suspension reseat
   (`mission_generator.gd:836` updated to `watchdog.setup(world)`).

Full reasoning: `~/.claude/plans/why-does-the-demo-fuzzy-narwhal.md`. **Not yet verified in-engine
by you** — please boot the main game, watch the `[SPAWN-TRUTH]` lines and any `[TerrainChunk]
... mesh built` rebuilds after them, and watch the squad for at least one 2s watchdog cycle while
inside the wire. If you STILL see anyone under the model after this, the earlier "check for a
literally-missing collider in Blender near the hooch" step above is the next thing to try — this
fix explains a transient collider swap, not a permanently-absent one, so it's not ruled out, just
no longer the leading theory.

## 0000. VC CAMP DENSITY — bumped 2026-07-30

You said the main AO (1280m, `WorldConfig.MAP_SIZE`) felt too sparse with only 3 VC camps clustered in
a narrow 400-540m ring around the firebase. Bumped to **5 camps** in `mission_generator.gd`
(`CAMP_COUNT`/`CAMP_CAPS`), with the outer band widening per camp (480/540/620/680/720m) instead of
clustering everyone in the same ring — should actually use the back half of the AO now. Garrison/ambush
spawning already loops off `camps.size()`, so nothing else needed to change to support more camps.

## 00. FRANCHISE NAMING — RULED 2026-07-30: "Tour of Hell"

You floated "Hell of Duty: Vietnam" (Hell Let Loose x Call of Duty pun, 90s-underground-comix-homage
spirit) as a ship name and franchise umbrella (Vietnam/Korea/WWI titles sharing TerrainEngine). War
Room flagged tone-mismatch + franchise-scale trademark exposure; you pushed back that a naming pun is
a different animal than Palworld-style mechanical cloning (fair distinction) and independently landed
on an alternative that hits the same tone. **Adopted: "Tour of Hell"** — era-tagged per title
(*Tour of Hell: Vietnam* first, then Korea/WWI). "Tour" is real military vocabulary (tour of duty),
ties to Pillar 4 (the squad rotates home, dies for real), and travels cleanly across all three eras.
Full reasoning: `production/war_room/2026-07-30_franchise_naming/synthesis.md` (pre-pivot; this
entry is the current ruling).

**Project name stays RECON internally** (7/28 decree not touched) — "Tour of Hell" is the external
brand direction. Say the word if you want RECON itself renamed too.

**Waiting on you:** nothing blocking. Optional next step whenever: quick trademark screen on "Tour of
Hell" before final commit, just for due diligence — lower stakes than the CoD-pun case, not zero.

**UPDATE 2026-07-30:** you brought two "Tour of Hell: Vietnam" key-art pieces
(`TOUROFHELL1.png`/`2.png` from `Desktop/recon game image ideas/`) — image 1 (helicopter, map,
"Born to Kill" helmet) went in as the **main menu** background (`assets/ui/menu_bg.png`), image 2
(firebase road, "FIREBASE HELL — DEATH SMILES AT EVERYONE" sign) went in as a **dedicated loading
screen** background (`assets/ui/loading_bg.png`), used only by `game_flow.gd::enter_hub()` — every
other screen (barracks, debrief, pause, settings, service record) still shares `screen_bg.png`
untouched. **Please eyeball the main menu in-editor**: the art bakes its own "TOUR OF HELL: VIETNAM"
title top-left, so I dropped the code-drawn giant "RECON" title in `main_menu.gd` to avoid a double
title and moved the button column down to y=220 to clear the art — that y-offset is an estimate off
the 600x600 mockup's proportions, not a measured value, so it may need nudging once you see it at
actual game resolution.

## 0. ONE RULING WAITING ON YOU (added 2026-07-27, overnight coupling audit)

**Do headshots kill your squad and you, or only the enemy?**

Right now a headshot is instantly fatal to an **enemy** only. Allies and the player take the ×4.0 head
multiplier but no instant-kill, so it depends on range: an ally (80 HP) dies to a point-blank M16
headshot (108 dmg) but **survives one at distance** (70 dmg). An enemy never survives either.

The rule ADR-016 wrote down ("HEAD = fatal") even has a function whose job is to say so —
`Hitzone.is_fatal_zone()` — and **no damage code calls it**; the enemy just re-types the rule by hand.
Pick one:
1. **Everyone dies to headshots** — matches ADR-016 as written and your "both factions use the same
   systems" ruling. Hardest and most consistent.
2. **Enemies only, made official** — amend ADR-016 to say so and fix the comment in `bullet_system.gd`
   that currently claims it applies to everyone. No gameplay change.
3. **Route all three through `is_fatal_zone()`** so there is ONE implementation, then pick 1 or 2.

Full detail + numbers: `production/ARCHITECTURE_COUPLING_READ_2026-07-26.md` §2.5.

## 0a. AUDIO — one thing to know, nothing blocked (added 2026-07-27)

Real gun recordings and the folk-music radio are IN and verified. Two notes, no ruling needed unless
you disagree:

**Five of the weapons you named for the gun swap do not exist in the game.** You said 5.56 → m16a1 +
**car15**, and 7.62x39 → ak47 + **sks** + rpd, then derivations for **thompson / kar98k / mp40**.
All five of those were retired by ADR-016 Amendment C — there is no `.tres` for any of them and
`tests/test_flat_damage.gd:31` fails the build if one loads. That list came from the filenames sitting
in the sfx folder, not from the weapons the game can equip. So I applied your rule to the **live**
roster instead and spent the budget on **m14 and m70, which had no audio at all** and were sounding
like a generic rifle — the m70 is your 87-damage sniper.

**But your art log says you are actively modelling the SKS and CAR-15** (`ART_Track_Log.md` §2). So
they are probably coming BACK. That is fine and costs nothing: the SKS is 7.62x39 (same source as the
AK) and the CAR-15 is 5.56 (same source as the M16). **The day either lands as a real weapon, say the
word and it gets real audio in about five minutes.** I deleted their old synth placeholders under the
fossil law rather than leave dead files pretending to be live ones.

**`m1911` kept its synth placeholder on purpose** — the pack has no pistol stock, .45 ACP is
subsonic, and you said not to ship a downgrade for the sake of coverage. Same for the shotgun and all
four launchers: no source exists.

## 0b. YOUR NEW ART IS IN NO COMMIT (added 2026-07-27)

`git status assets/` = **531 untracked files, 44 deleted**. The whole regenerated village set
(`nha_tranh_*`, `nha_san_*`, `nha_ruong_*`, `village_well_01`, `dinh_01`, `chua_01`…) and
`fsb_main_v3.glb` exist **only on this disk**. The old `thatched_hut.glb` / `stilt_house.glb` /
`well.glb` / `fsb_main.glb` are deleted from the working tree but still live in git history, so the
repo and your disk currently disagree about what the village is.

Three test/tool files were pointing at the deleted assets. **Fixed on disk, deliberately NOT
committed** — committing them before the assets would break a fresh clone:
`tests/test_nav_path.gd` (this was one of the two suite REGRESSIONS — it goes green with the fix),
`tests/test_asset_probe.gd` (your `fsb_main_v3` edit preserved), `tools/probe_penetration.gd`.

**Commit the assets and these three files together.** Until you do, the art exists in exactly one
place.

## 1. CHARACTERS (the big one)
- [x Done but need NVA models and more US variety] **Finish the better-body remake for ALL units** — the slimmer base, then rebuild:
      us_grunt, us_grunt_black, us_medic, vc1_farmer, vc2_mainforce, vc3_sapper, vc5_nva, vc6_heavy
- [WIP] **Set weapon + arm models right on every unit** — gun attach nodes / hand alignment in the
      character rigs (your words: "align all the weapons up right")
- [ x] **Radioman (RTO)** — grunt + PRC-25 backpack + handset on a cord (the 10m radio leash +
      the FP handset raise both wait on this asset)
- [x] Civilians (men/women/kids) — DONE 2026-07-12: civ_farmer_m/f, civ_elder, civ_kid + US pilots (black/white). `tools/make_civilians.py`
- [ Grunt Spawner Should be Made, we need to test this. I noticed that the custom helments I made havent been appearing.] Modular kit when ready: helmet/torso/arm variants for roster variety 

## 2. HELICOPTER FLESH-OUT (Need to spend a real day doing all of this.
- [ ] Interior: real seats, floor, door frames (walkable cabin)
- [ ] **Name the sockets in the glb**: `SeatDoorLeft`, `SeatDoorRight`, `SeatPilot`, `SeatCopilot` —
      code already looks for them and falls back to guessed offsets when missing
- [ ] Door-gunner position (M60 mount point)
- [ ] Confirm nose orientation after my 180° flip looks right in flight

## 3. FIRST-PERSON (in process of working on the movable weapon parts and the animations related to that)
- [ ] **Verify the arms placement** (my fix is a math guess — in-game eyes needed; tell me
      high/low/close and I nudge). Then: do the hands feel right at 75 FOV?
- [x] ~~Remaining viewmodels: M60, RPD, PPSh, RPG-2~~ **DONE 2026-07-10 night** — plus
      Ithaca 37, M70 sniper, Colt 45: ALL hand-set + exported (ppsh/m60/rpg2/rpd/ithaca/
      m70/colt45`_fp.glb`, rifle_idle + MuzzlePoint contract, pose jsons captured)
- [ ] **Tunnel rat viewmodel**: pistol + MX-991 flashlight two-prop export (flashlight modeled
      w/ lens LightOrigin; hold staged; needs exporter two-prop extension + Caleb final pose)
- [ ] **M26 grenade hold + export** (model done, imported to arms file with nodes)
- [ ] Engine wiring for the 7 new viewmodels: `*_arms_viewmodel.tscn` + tres (pattern = m16/ak/mosin);
      shotgun also needs `shotgun.tres` + pellet-damage decision vs ADR-016
- [ ] Per-gun idle/fidget/check animations — specs ready in `fp_arms/IDLE_ANIM_SPEC.md` +
      `IK_ANIMATION_WORKFLOW.md` (follow-the-recipe now)
- [ ] FP radio handset raise (reuses the RTO handset asset)




## 6. IN-GAME VERIFICATION PASSES (you play, I fix live via MCP)
- [ ] **The patrol loop (ADR-029)**: NEW CAMPAIGN → seated at `fsb_main` → out the wire gate on one
      diegetic pointer → find a site unguided → fair contact → squad holds → AAR banks at the gate
      (`_bank_patrol`, `scripts/missions/field_director.gd:1066`) → quit → CONTINUE puts you back at the
      firebase. No briefing UI, no board-bird, no exfil step (ADR-029).
- [ ] F5 quicksave / F9 quickload · rations [9] · weapon cleaning [0] when it fouls
- [ ] **Field marks (NEW 7/25 — ADR-022 Amdt A)**: click [MIDDLE MOUSE] while aiming at an
      enemy / tunnel mouth / hut / trail (stand still; binos up if it's far) → toast fires →
      open [M]: a big blue pencil circle with the word on it. Marks must survive walking back
      in through the wire AND a quit/CONTINUE. Tell me: is the circle too big/small, does MMB
      feel right? (Your ruling: T or MMB — T is CAS, so MMB it is.)
- [ ] Tiny-units hunt: play near spawns, I read the [MODEL] prints
- [ ] Squad keys: F1-F4 vs the new C/H/X/N — which works on your keyboard?
- [ ] Feel checks: locational damage (head/gut/limb), blood (mist/splats/pools/wounds-on-allies),
      VO (Joe radio from the RTO's back, barks, VC shouts), F-4 napalm pass, rain squall fade
- [ ] Terrain chunk pop — reproduce while I watch the stream (bead filed)

## 7. DECISIONS ONLY YOU CAN MAKE
- [I haven't heard too many voices but I see the text that appears on the screen which is helpful. Well have to combine those two elements together ] Final squad voice assignments (Joe=radio locked; confirm John/Ryan/Norman roles felt right)
- [ ] Male vs female VC voices (pitch-shifted male sample was sent)
- [Would be cooler to have a more realistic blood effects when shooting people. It just kinda pools on people. I would like bodies to look bloodier and to have the bloodpools spray more and than spread more. ] Blood look sign-off (darker? chunkier? bigger?) — generator = one-line tweaks

---

## NEXT UP (Friday priority order — the strict list, no beads)

> **SUMMONER DECREE 2026-07-25 — MAIN PRIORITY: the Blender→Godot gun/arms PIPELINE.** Automate the
> animate→export→working-in-Godot loop. HUD is pushed to background/later (ADR-030 deferral
> re-confirmed). Pipeline build starts once you bless the M16-rig diagnosis + fix path (see the
> landmine note below). Your #1 below (the animation pass itself) rides on this pipeline being trusted.

The ordered queue for the next working session. #1 is the big-difference item.

> **RESOLVED 2026-07-26 (headless, blessed fix path):** the M16 rig contract is RESTORED in
> `fp_arms_rifle.blend` (`tools/fix_m16_rig_contract.py` — CHILD_OF hold_R→hand.R, fittings re-seated
> as gun children at their last-good offsets, mag hand_handoff re-inversed at the grab frame, the
> gun's non-uniform scale baked out) and m16/ak/m14 `_fp.glb` re-exported + structurally validated
> (markers byte-match last-good, sight radius 0.5964). **YOUR GODOT STEPS: open the project in 4.7
> (or run `godot --headless --import`) so the three GLBs reimport, then viewmodel editor → M16 →
> press V — the ADS align should now frame real sights.** Known debt: the M14's fittings sit
> root-level in the .blend (works by name-lookup; the pipeline validator flags it).

1. **WEAPON ANIMATION PASS** (the huge one). Do the movable gun parts + arm rig + animation in ONE
   pass per weapon (your workflow-saving strategy), then:
   - Make the gun PARTS that should move for animations move (bolt / charging handle / mag / trigger /
     cylinder per weapon — parts-level list to be mined from `assets/player/arms/IDLE_ANIM_SPEC.md`,
     `IK_ANIMATION_WORKFLOW.md`, `VIEWMODEL_ANIM_SPEC.md`, `production/WEAPON_ADS_WORKFLOW.md`).
   - **Restage / parent every weapon to the ARMS** ("align all the weapons up right").
   - **ADS lined up right** — verify arms placement in-game (you call high/low/close, I nudge); hands
     feel right at 75 FOV; ADS down the sights aligned per `ads_fov`.
   - **Export properly** — the `_fp.glb` + `rifle_idle` + MuzzlePoint contract (the DONE 7 are the
     pattern); then the engine wiring `*_arms_viewmodel.tscn` + `.tres` for the 7 new viewmodels.
   - (Detail already in §3 above + `ART_Track_Log.md §2`.)
2. **RADIOS PLAY CUSTOM RADIO SONGS** — wire the radio-support loop to your new Audacity broadcast
   mixes (AI + real period broadcasts + ads + hiss). FP handset raise reuses the RTO handset asset.
3. **HUEYS** — §2 above: name the sockets (`SeatDoorLeft/Right/Pilot/Copilot`), door-gunner M60 mount,
   walkable interior (seats/floor/frames), confirm nose orientation after the 180° flip.
4. **NVA VARIANTS** — `vc5_nva`, `vc6_heavy` models + finalized ZPU gunner (mannable by both factions).
5. **FLESHED-OUT VILLAGE BUILDINGS** — more geometry + interiors for CQB; clear-out playspaces.
6. **BETTER FIREBASE LAYOUT** — the "full day" detailed FSB pass.

---

## SALVAGED FROM BEADS (pre-retirement, 2026-07-22)

Beads is retired (it was closing work as "done" that wasn't). These were YOUR own feature specs that
lived only in the tracker — preserved here so they aren't lost. Corroborated live work already appears
in the sections above; this is the extra stuff. Rule on the flagged one when you get a moment.

- **Airfield location type** — a distinct location (max 1 per AO), far from the firebase, found under
  attack.
- **VC-execute-villagers scripted event** — on approach to the 3rd village, VC are executing villagers;
  the player may choose to intervene.
- **Rank progression** — rank unlocks weapons at the armory + a loadout/backpack menu.
- **Medic revive economy** — revive rules/limits for the medic.
- **NPCs trigger traps** — enemies/civilians can set off placed traps, not just the player.
- **Trap density / concealment** — how many traps, how hidden.
- **Pointman-leads order** — squad command to send the pointman ahead.
- **Squad competency: veteran vs cherry** — units differ in skill/nerve.
- **Squad morale: FIGHT → SURVIVE at 45%** — squad shifts from fighting to surviving below a strength
  threshold.
- **[RULE: keep or cut?] Prerendered-cinematic (Blender FMV) direction** — a four-cutscene FMV plan.
  Not mentioned in either current source-of-truth doc; flag it — is this still a direction you want, or
  is it dropped?


## Vehicle dash radio (Caleb, 2026-07-25)

A tiny in-cab version of the field radio inside drivable vehicles, playing music while
you drive. Implementation is nearly free — `scripts/props/radio_prop.gd` is already
drop-anywhere (folder-scanned tracks, positional player); the cab version is the same
prop with a small mesh, short hear_distance (~6m), and its own music tracks dir
(vs. the AFVN broadcast set). GATED ON: player-drivable vehicles, which the ADR-029
foot-only slice parks — build the radio the same wave driving ships. Music tracks
are an asset ask (period-legal music/AFVN-style music blocks) — separate from the
5 spoken broadcasts.

## From ghost-code audit 2026-07-25

**ANSWERED 2026-07-25 — the "what spends Team XP?" decision** (the audit's `buy_skill` stray,
`GHOST_CODE_AUDIT_2026-07-25.md:101`): nothing spends it, because it is no longer XP. The pool is
the player's HIDDEN reputation — never a number on screen; it surfaces as earned rank
(PVT→PFC→SP4→SGT→SSG) and as more weapons on the armorer's rack. `buy_skill` is deleted; allies
learn by doing only. Ruling + pointers: `production/adr/ADR-032-player-reputation-titles.md`.

Three roadmap seeds surfaced by the audit (corrected 2026-07-25, ghost-code audit). **Corpse-drag
mechanic** — the ragdoll half already exists (`model_actor.gd:674 ragdoll_bone`, `:682 wake_ragdoll`);
the grab mechanic that would use it was never built. Roadmap item, not cleanup. **Squad-regroup
behavior** — the `AIGoal.REGROUP` enum member was cut by ruling 7/25 (never scored, set, or matched),
but the behavior it named ("isolated soldier rejoins his squad") remains a valid future feature if
squad cohesion ever needs it. ~~**Temple/shrine art gap**~~ — CLOSED 2026-07-26: the generated prasat
set ships, `stamp_temple_shrine()` places it, and the temple root joins `temple_shrines`
(`scripts/world/site_planner.gd:809-832`).

---

## FOR THE NEXT AUDIT PASS — wire up the nine unplaced temple statues (noted 2026-07-26)

**Verdict class: UNFINISHED, not FOSSIL (ADR-023) — do NOT delete these models.** They are built,
exported, and collision-tabled; the shrine stamp just never grew past the stair group.

`tools/gen_temples.py` ships **14 statues** and all 14 have `collision_table.gd` entries (`"mesh":
true`). `scripts/world/site_planner.gd` is the only placer in the project, and its statue block
(`:834-852`) names **five**: `guardian_01`, `guardian_02`, `naga`, `seated`, `lingam`.

**Nine have zero placement callers repo-wide:** `altar`, `apsara_01`, `apsara_02`, `garuda`,
`singha_01`, `singha_02`, `stele`, `stupa`, `naga_rail`.

Roster proposed to Caleb, unruled — he picks before anything is built:
- **singha** pair as an alternate stair guard, rolled against the dvarapalas so not every shrine
  reads the same
- **apsara** relief slabs set flat against the non-entrance wall faces (they are wall panels, not
  free-standing figures — placement must respect that)
- **naga_rail** flanking the approach as a balustrade run, seated off the same `fwd`/`side` basis
  the guardians already use
- **stele · altar · stupa · garuda** scattered in the courtyard inside the 14m site radius

The `fwd`/`side`/`reach` basis at `:838-842` already does the hard part — anything added should reuse
it rather than re-deriving the door direction. Reach is manifest-driven, so it scales with the
temple's footprint for free.

---

## FP VIEWMODEL ANIMATIONS — measured defect list (2026-07-26)

Full report: `production/research/viewmodel_anim_defects_2026-07-26.md`.
Data: `production/research/viewmodel_rig_audit.json`. Re-run the probe with
`blender -b assets/player/arms/fp_arms_rifle.blend -P tools/audit_viewmodel_rigs.py --`.

### Mine, next session (headless, no animation authoring)
1. ~~**PPSh retime**~~ — **DONE 2026-07-26.** You ruled the timer follows the animation and that the
   export should write it. Shipped as **ADR-034 Amendment A**: `tools/sync_weapon_timers.py` reads
   each clip's length from the exported GLB and writes `reload_time` / `empty_reload_time` /
   `jam_clear_time` into the .tres; the export driver runs it every time; the validator now FAILS on
   drift. All four guns measure exactly 1.00× — the PPSh was 0.76× / 1.30× / 3.30×.
   **You accepted the balance change: PPSh jam clear 1.1s → 3.63s** (reload 3.4 → 2.6s, empty → 4.43s).
   Worth feeling in a playtest — it is a long time to be defenceless.
2. Fold the **frozen-hand** check into `tests/test_viewmodel_contract` so a dead limb fails the build
   instead of waiting for a playtest. (The clip-vs-timer half is now covered by the validator.)
3. Marker parenting: manifest says `markers_under_gun: true` for all four, but AK's markers parent to
   `AK47` and M14's to `M14_gun` (the mesh, not the root). Correct the claim or the parenting.

### Caleb's, in Blender (animation quality is his hands — standing ruling 2026-07-26)
1. **AK broken reload** — `ak_mag_handoff` is a 132f action mounted under BOTH the 78f `reload` and
   the 133f `reload_empty`. Authored for the long hand path, so the mag rides a hand that isn't there
   during the short reload.
2. **Frozen hands** — `hand.R` measures 0.00 mm/frame for the ENTIRE clip in M16 reload,
   reload_empty and jam, and in AK reload and M14 reload; `hand.L` is dead through M14 jam and
   charge_handle. Biggest single cause of "robotic".
3. **M16 modeling / sights / ADS markers.** One measured lead: `M16A1_gun` is the only gun root with
   a non-identity object rotation — (2.642°, −0.021°, 89.893°).
4. **M16 leftovers from 2026-07-26**: 4 single-face floaters (3 facing down), 2 open sheets in the
   join, and the old hand height still present in the reload/reload_empty/jam gripping segments
   (only `m16_fp_idle` was shifted).
5. **PPSh**: prototype clips to re-author; the bolt was never split off the gun so it is static in
   every clip; hand-in-gun penetration is worst on this gun by a wide margin (140mm vs the M16's 23).

### Two things NOT to do
- **Do not blame the export.** We ship glTF, not FBX. `bake_anim_simplify_factor` / `bake_anim_step` /
  `add_leaf_bones` are FBX-only. `export_viewmodel_clips.py:324-332` already forces sampling, disables
  animation-size optimisation and bakes every part frame-by-frame. Nothing simplifies a curve.
- **Never run "apply all transforms + set origins to the 3D cursor"** on `fp_arms_rifle.blend`. It
  destroys the PPSh's 27 authored non-uniform-proportion children, `M16A1_ch_rail`'s slider origin,
  and the parent-inverses on guns already blessed.

**Still unproven for every gun:** the clips have only ever been watched on the bench. Nobody has
confirmed they play correctly in-game through `weapon_holder`'s reload path.

---

## ORPHAN CLIP WIRING — War Room 2026-08-02
Full record: `production/war_room/2026-08-02_orphan_clip_wiring/` (briefing · 4 analyses · discussion · synthesis).

**The audit.** `assets/shared/anim_library.glb` carries 163 clips. Measured against every `.gd`/
`.tscn`/`.tres`/`.json`: **32 have zero call site.** 8 more (`*__smg`) have no literal call site but
ARE reachable — `sprite_state_map.gd:403` builds `base + "__" + family` and `ppsh41 -> smg`.

**Root motion is stripped project-wide** (measured off the glTF Hips channel: `walk_forward` = 0.000m
is the control). The lone exception is `disembark_heli_*` at 0.200–0.534m.

### DONE this session
- **Cockpit wired.** `seat_system.gd` — `PILOT_CLIP` became a three-state map: `cockpit_idle` parked ·
  `pilot_flips_switches` one-shot on touchdown · `cockpit_controls` airborne. Driven off the existing
  `Helicopter.State`; the tick is independent of `player_boarding`, since a ship nobody can board still
  lands with visible pilots. `cockpit_controls` added to `model_actor.gd:_LOOP_NAMES` in the SAME change
  — it is not caught by `_LOOP_PREFIXES` and would have frozen the pilot on its last frame.
- **`anim_review.gd` was BROKEN and is fixed.** `ModelActor.setup()` takes a **unit_id**; the bench was
  handing it a **path** from `model_path()`, so `model_exists()` failed on every unit and the whole room
  came up empty. Pre-existing drift, unrelated to this session's work. Now boots at **163 clips, 7 pages**.
- **Crew banks added to the bench** (press `N`): MG CREW · LITTER TEAM · LITTER LOAD. Crew rows hold
  station offsets and restart on the clip's own cycle so the men stay in phase for the whole performance
  instead of being paged one at a time.
- **Litter team built** — `scripts/world/litter_team.gd` (new), seeded in `site_planner.gd`, spawned in
  `mission_generator.gd`, latched via a new `Civilian.puppet` flag. **DORMANT until the art lands, by
  design** (see blocker below).

### BLOCKED — needs Caleb
1. **THE LITTER PROP.** `fb_litter` exists only INSIDE
   `assets/us/characters/camp_clips/stretcher_carry.glb` (the 4-rig authoring reference — it also holds
   `MC_litter`, the prop's own motion clip, and a `PSXRig_casualty` pose that was never split into
   anim_library). It needs exporting standalone to
   `assets/world/building models/structures/firebase/kit/fb_litter.glb`. `LitterTeam.available()` gates
   the entire feature on that path existing, so the code is inert and harmless until it does — the same
   contract `heli_lift.gd:42-46` uses for the unmade boarding clips.
2. **JUMP / LANDING — cannot be done as ruled.** A routine is a man at a `work_*` marker doing a job, and
   a station never involves a jump. Jumping is TRAVERSAL and there is no traversal system:
   **`NavigationLink3D` appears zero times** repo-wide, so no NPC is ever airborne and the clips have no
   trigger. The player jumps (`player.gd:1671`) but is first-person — no third-person body to animate.
   The heli-skid slice was proposed and REFUSED: `disembark_heli_*` carries 0.2–0.53m of authored
   step-off, so bolting on `jump_down`/`hard_landing` risks a man landing twice.
   **His call: open a traversal epic, or leave `jump_up`/`jump_up_2`/`jump_down`/`jump_away`/
   `hard_landing` orphaned.**
3. **MG CREW — his visual check, then wire.** Measured: all four `gun_*` clips are IN PLACE (0.000–0.024m
   drift over 27.3s), so they will NOT drift apart — the wiring is mechanically safe and only the look is
   unproven. Cost if approved: a 4-man crew is **more than half the 7-man firebase work budget** on one
   position, and `site_planner` carries 20 `gun` markers.

### Deliberately left orphaned (do not "fix")
- `cockpit_dead` — no pilot damage model exists; wiring it means inventing a state to justify a 0.33s
  clip. ADR-023 forbids the dead hook.
- `turn_90_left/right`, `crouching_turn_90_left/right` — carry up to −161.6° of ROOT rotation
  (`sprite_state_map.gd:54-56`). Only the in-place `turn_left`/`turn_right` pair is safe to loop.
- `jump_away` (a dive, no grenade-flee behaviour to hang on) · `jumping_jacks` (no PT routine) ·
  `signal_move_up` (a beckon; looping it waves forever) · `crouched_sneaking_*`, `cover_reposition`,
  `rifle_turn`, `rifle_crouch_idle_to_walk`, `stop_walking_with_rifle`, `action_idle_to_standing_idle`,
  `strafe_2`, `salute`.

### Known gap, unrelated but recorded
`WEAPON_FAMILY` (`sprite_state_map.gd:385-391`) declares `mg`, `bolt`, `launcher` and `pistol` families
with **zero clips authored**. `model_actor.gd:877` warns once per family and falls back to the rifle hold
— the RPD gunner and the RPG man carry their weapons like rifles.

---

# 2026-09-07 — COMBAT LEGIBILITY (War Room `war_room/2026-09-07_squad_cohesion/`)

Full decree: `production/war_room/2026-09-07_squad_cohesion/synthesis.md`. Seven architects.
Convened as "is squad cohesion a combat mechanic"; **he reframed it mid-council** to *"realistic
feeling and looking combat... about 60 percent there, not as smooth as Call of Duty 1 or Brothers in
Arms."* The cohesion machinery turned out to be ~80% built and 0% named; the animation architecture
turned out to be **better than the reference games'**. The gap is parity and cadence, not clips.

## THE PERF BASELINE — first one ever taken on the demo
`--perf-probe` on `demo_game.tscn`, render_scale 0.75, forward_plus, seed 29072026, n=130:
**FPS avg 27.9 / min 25.0 · GPU 27.14 ms avg (32.61 max) · CPU 5.24 ms avg (8.59 max) ·
265,108 prims / 1,950 calls / 2,986 objs.**
**The GPU is the wall by 5.2x.** Huge CPU headroom, so animation CPU work is cheap. **Standing caveat:
at 27.9 FPS frame pacing competes with animation as the explanation for "not smooth" — no visual
verdict is clean until the GPU wall moves.** NOT the siege: `--perf-siege` unrun, THE WALK · ONE DIG ·
THE BARRAGE still untaken.

## BUILT (zero art-days, gate-exempt, all probes green)
Ally body parity — every clip already authored and mapped, only the ally callers were missing:
1. **Ally flinch + stumble** on `take_damage` (enemy thresholds/clips/guards verbatim, prone guard added)
2. **Ally arrival plant** — run/sprint → aim/idle/cover plays `run_to_stop` for 450 ms (display-only)
3. **THE PIN HUNKER** — a pinned man holds `cover_kneel_brace` instead of a kneeling aim.
   **Discharges the truth-law violation** where the old code cleared the override under a comment
   claiming a hunker that never existed. Plus its leak guard in `_change_state` (the brace must not
   survive SUPPRESSED→COMBAT, where `_release_cover` never runs)
4. **Cover-arrival ungated** from the layer-1 wall ray that vegetation/terrain/log cover all failed —
   now `wall OR terrain_cover >= 0.3`. Deliberately not `cover01()` (would fire on bare ground)

**Verified:** headless boot CLEAN · `test_ally_states` PASS · `test_low_posture` PASS ·
`test_squad_break` PASS · `test_squad_invariants` PASS · `test_squad_coordinator` PASS.
**No probe proves it LOOKS better — that is his eye, by the council's own closing rule.**

## AWAITING HIS RULING
- **THE TOKEN DIAL.** `doctrine_us.tres` `exposure_tokens` 3→2, `grant_stagger_ms` 600→900. Applied,
  **failed `test_squad_coordinator` ("doctrine data of record"), and was REVERTED** — the guard exists
  to catch unruled doctrine changes and it worked. **The test was NOT edited to permit it.**
  Two architects reached this independently and `siege_director.gd:615-618` already condemns the
  pattern in writing. Siege is insulated (`assault_press` = 999/0, separately guarded).
  **If approved: change the .tres AND `tests/test_squad_coordinator.gd:55` in the same commit.**
- **AIM LAYER — scoped, not built (his ruling 3).** A bounded spine-only aim modifier does **NOT** need
  the AnimationTree rewrite: **1 new file (~60-70 lines), 1 existing file touched, ~3 lines, ZERO of the
  ~30 `play()` sites, ZERO of the 8 fossil-law files.** `FlinchModifier` is the shipping precedent
  (52 lines, 2 lines of integration). **Named risk:** flinch is transient, an aim layer is persistent,
  so it fights every clip that already rotates the spine (cover lean, turn-in-place, prone) — 1 day for
  the modifier, **unknown** for the conflict set. **If an AnimationTree ever lands it lands as its own
  decreed change, never dressed as a blend-time tweak.**

## PARKED BY HIS RULING 2 (no art-days) — correct and unbuilt, he will want these
- **Rifle-ready start poses 76° apart** (`firing_rifle` 76° off `idle_aiming`, `reloading` 69°,
  `idle_aiming` 37.6° off `idle`; `ANIM_WISHLIST.md` B1). Crossfaded in 0.18 s, twice per shot, on the
  most-played transition in the game. **1-2 art-days**
- **`aim_walk` does not exist**, falls back to `walk_forward` — a man advancing under fire plays the
  patrol stroll. **1 art-day**
- **Hip lateral sway stripped by the exporter**, 31 locomotion clips (`ANIM_WISHLIST.md` C2).
  **1-2 days + full rebake**
- **Emotional-register axis + variant generation** (`tools/make_ambient_variants.py` written, never
  run). **The month.** Right answer to "samey", wrong answer to "unsmooth" — must not start first
- **FLESH IMPACT SAMPLE** — shooting a man plays `IMPACT_DIRT` under the comment *"placeholder wet tick
  until a flesh sample exists"*. **No flesh audio exists on disk**, so this is an ASSET not a wire-up
  and ruling 2 parks it. Cheapest perceptual win on the board; his own "they don't die" complaint in audio

## NEXT CODE ITEMS — ranked, gate-exempt, unbuilt
1. **Enemies have zero cover craft** — all cover clips + the arrival picker are ally-side only;
   `enemy_base` sets `has_cover = true` with no clip. **The fix is already written on the other side.**
   Largest remaining asymmetry
2. Ally grenade-throw windup (the third enemy-only one-shot)
3. **20 recorded voice lines never play** (12/25 squad, 7/15 radio) incl. the whole directional
   vocabulary and both reload lines; **the contact moment fires a text toast with no voice under it**;
   no bark at token grant or element swap
4. **No animation LOD anywhere** — all 45 men animate at full rate at the climax. Ships only with its bench
5. Per-transition blend times (0.18 s is one global constant, ~15 lines)
6. Six deceleration paths in `ally_base`, two hard-setting velocity 4.2 → 0 in one frame (bug-class)
7. `_CLIP_SPEED` holes — sprint/crouch diagonals, `run_to_stop`, **every `__smg` variant** (SMG men skate)
8. NPCs never reload (clips authored, one test-scene caller)
9. Nav restake threshold 3 m — the one surviving stutter suspect, unmeasured
10. The three council probes: stillness census · `probe_anim_churn` · resolver log

## RULED / PARKED — do not reopen
- **Six free misses: DECIDED.** Per-man near-miss stands, generous and atmospheric by ruling
- **Rotation / DEROS: OUT OF DEMO SCOPE.** Recorded, not planned. (Pillar 4's text still promises men who
  "rotate home"; no rotation clock exists in code — post-demo)
- **No cohesion resource, no meter, no number, no fifth order key.** The readout is the soldiers themselves
- **Pillar 4's provisional anti-puppeteer clause: formally OPEN, PARKED**, no urgency, his call from play

## DRIFT CORRECTED
- `GAME_GUIDE.md` §8.1 item 3's "EnemyBase has no dresser call at all / 45 clones" was **FALSE** —
  `enemy_base.gd:470` → `_dress_visual` → `VcNvaDresser.dress`. Corrected in place. Whether the variety
  **reads** is still a playtest question
- `production/research/squad_mechanics.md` — stale-baseline notice added (order enum, squad size,
  dual-bind law, formations)
- `ANIM_VARIETY_PLAN.md` **refuted** on "cower is the one gap with neither art nor code" — art existed


---

## 2026-09-08 (night) — HIS TWO RULINGS + THE STALL HUNT

### YOUR TWO ROWS FROM "ok do it all", worked 2026-09-09 (night)

**ROW 3 — the 545 firebase interior props. BUILT, headless-verified, one thing waits on your eyes.**
They are folded into one MultiMesh per type and the baked copies are removed in the same change:
**545 props -> 69 MultiMeshes, 1,010 surfaces -> 132.** Two things the old note had wrong: they
share **69** distinct meshes, not the ~11 it guessed, and 1,010 surfaces carry only 5,471
triangles of unique geometry against 43,941 of copies.
- The draw distance is measured per type now instead of a flat 40 m guess — each prop is shown
  out to where it covers two screen pixels. A helmet earns 15 m, a cot 230 m.
- **PRESS F9 IN GAME TO CYCLE IT** — MEASURED / NEAR (the old 40 m) / FAR. It prints which one
  it just picked. The right distance is your eye, not arithmetic, so it is a key and not a
  silent guess.
- The honest cost: **+67 draw calls (+14%)** against this morning, for a pop that is gone.
  Counterintuitive detail worth knowing — the fold on its own COSTS 50 of those, because a
  MultiMesh cannot be frustum-culled per prop the way 545 separate nodes could. What it buys is
  the range move, which costs +110 calls without it and +17 with it.
- **No frame or fps number is claimed.** You ruled the bench unrepresentative ("its just terrain
  with no action so its not really gauging anything") and you were right; it needs re-pointing
  into the live assault before it is quoted again.

**ROW 6 — the white box in the mortar pit. BLOCKED ON YOU, and the original plan was wrong.**
`us_fb_ammo_crate_stack-colonly_P2` is NOT a visible prop with a bad name — it is a collision
proxy sitting exactly on top of the real crate, and the rename I was given would have shipped a
duplicate solid crate on top of it. Corrected plan: move the `-colonly` to the END of the name,
which makes the exporter finally strip it, so it ships nothing at all and your blend keeps the
object. **The write to `firebase_v3.2.blend` was refused by the permission gate three times.**
Your blend is untouched. It needs you to approve the prompt or allow `blender.exe`; the script is
ready and waiting at `tools/rename_fb_ammo_crate_colonly.py`. Full detail in `PERF_LEDGER.md`.

### RULING 1 — ALL PLANTS ARE 3D MODELS. BARBWIRE IS THE ONE EXEMPTION.

His words: *"i'm still!! seeing the 2d billboard plants as the smaller terrain all over the world when I
need those to be the 3d terrain models we've made or added to the project. no more 2d terrain cards, or
3d plane spliced cards or whatever. all 3d blender models only in game"* — then: *"besides the barbwire
since that works better as cards or whatever"*.

**Second time he has raised it.** Recorded in law: `ADR-001 Amendment A` (revokes the surviving sprite
carve-out) and `ADR-026 Amendment D` (supersedes the Part A.2 card ring; kills the canopy card atlas).

**STATUS 2026-09-09 (night): DONE. ALL THREE HALVES ARE BUILT — the two runtime ones and the
firebase art bake. There are no vegetation cards left in the live world.** Details in
`production/PERF_LEDGER.md` 2026-09-09. Measured by `tools/probe_firebase_cards.gd` against the
re-exported GLB: **`0 flat (card-like), 19 volumetric`**, against 14 flat that morning.
- DONE — `scripts/world/ground_clutter.gd`: every near-ground layer is a real mesh. He confirmed
  it with his own eyes on 2026-09-09, unprompted: *"i can see the right terrain models on the
  ground now"*.
- DONE — `terrain/vegetation/tree_cover_layer.gd`: the 65–350 m card ring is deleted. ONE
  MultiMesh per (species x 64 m bucket) draws the real model 0–350 m, so the 65 m boundary that
  changed a plant's DIMENSION in one frame no longer exists. All 27 live species audited
  volumetric first (`tools/probe_far_ring_meshes.gd`); none needed substituting and no species
  was dropped. Guarded by `tests/test_tree_cover_lod.tscn`, which now FAILS if a plane or a
  second distance-gated tier ever returns.
- **COSTS FRAMES, HIS RULING OWED.** Worst 1% low 37.2 -> 30.1 fps, gpu 11.89 -> 15.54 ms, draw
  calls +17%, primitives +66% (`tools/bench_canopy.tscn`, 8 fixed yaws, ship parity). Well above
  the detectability floor. Reported as the price of his art ruling, not argued against it.
- **DONE 2026-09-09 (night) — the firebase bake. The last card population in the live world is
  gone.** All 14 card groups now carry the real species model. `tools/probe_firebase_cards.gd`
  on the re-exported GLB: **`0 flat (card-like), 19 volumetric`**.
  - **Nothing was invented and no species was substituted.** All 14 real GLBs already existed
    under the identical stem (`bush_a.glb` for `cards/bush_a_card.glb`, and so on), each a
    single-part, single-or-two-material mesh — audited on load, and the export REFUSES rather
    than substitute if one is missing.
  - **The plants stand exactly where the cards stood, and that is measured, not asserted.**
    `scatter_veg` fuses every instance of a species into ONE mesh, so the per-instance
    transforms are nowhere in the file — but `bmesh.from_mesh` appends, so instance *i* is the
    vertex block `[i*V, (i+1)*V)`. A Umeyama fit per block recovers translation, rotation and
    uniform scale at **max residual 0.0000 m across all 349 instances**
    (`tools/refit_firebase_veg.py`, which refuses to plant above 1 mm).
  - **349 instances**, not the "~360" the survey guessed. Now counted.
  - It is an EXPORT step, not a blend edit — same shape as the `-colonly` twins, generated and
    undone inside `export_firebase()`. The artist's blend still holds the cards, is never
    saved, and reverting the ruling is reverting one file.
  - **THE PRICE — see `production/PERF_LEDGER.md` 2026-09-09 for the full table.** Triangles
    28,646 -> 93,024 in the `fb_veg_` set; primitives +38.6%; **draw calls did NOT rise** (603
    -> 597). Frame cost **+0.34 ms GPU, +0.39 ms wall frame time, −4.2 fps mean** on an isolated bench at
    ~105 fps — about **1% of the shipped demo's frame**, and under the ~2.4 ms floor the canopy
    work used. The pacing numbers (worst frame, 1% low) are INSIDE this instrument's own
    run-to-run noise and are NOT reported as a result.
- Original survey, kept for the pointers (the `gen_firebase_v3.py:529-546` line below is stale:
  that table now names real models, and `VEG_BAKED_CARDS` beneath it records what was baked):
- `terrain/vegetation/tree_cover_layer.gd:15,166-169,224-226` — the 40-card far ring, 65–350 m.
- `scripts/world/ground_clutter.gd:26-35` — 7 of 8 layers are QuadMesh billboards; the 8th is the
  6-tri star-fan `grass_fan.glb`. Second star-fan site: `scripts/levels/gore_lab.gd:201-236`.
- `tools/gen_firebase_v3.py:529-546,566-612` — **~360 cards are BAKED INTO the shipped firebase GLB.**
  An art bake, not runtime code. Easy to forget; it is half the job.
- Starting stock for the far-ring LOD **meshes**: the orphaned `lp_bush_a/b/c`, `lp_fern_a/b`,
  `lp_grass_tuft_a/b`, `lp_sprout_a/b/c` (6–108 tris; `lp_bush_a` is 36 tris vs `bush_a`'s 256).
  `lp_bush_*` already have break bands and segment joints. Nothing plants any of them today.
- Measured trade: mean solid 269 tris vs mean card 3.05 tris (88x more triangles), against card
  textures totalling 173.8 MB uncompressed / 14.5 MB on disk — ~66x the unique texture bytes of every
  solid plant combined — plus `CULL_DISABLED` alpha overdraw. Cost genuinely unknown until benched.
- DO NOT TOUCH: `assets/us/props/emplacements/barbwire_card.glb` and everything keyed on the
  `bwire_card` name prefix.

### RULING 2 — "fix the physics stalls, thats whats killing it"

Full measurements in `production/PERF_LEDGER.md`, 2026-09-08 (night). Headline: **the drop is a crater.**
One large explosion = ~80–94 ms in a single idle frame, all of it a whole-256 m-chunk teardown and
rebuild triggered by a heightmap edit that itself costs 0.1 ms. The physics-side spike is
`TreeBreakSystem.apply_blast` doing unbounded per-chunk MultiMesh regen on the physics tick (23.9 ms of
a 66.6 ms step).

Shipped and verified: 495 dead monitoring Area3D turned off (damage probe PASSES) · terrain chunk mesh
build moved off SurfaceTool (worst chunk 27.0 -> 6.4 ms; worst crater 119.4 -> 80.7 ms) ·
`affine_inverse` hoisted out of the hitzone harvest loop · per-rebuild chunk print silenced.

**NEXT, in order, with measured sizes — ALL FOUR CLOSED OR RULED, 2026-09-09:**
1. ~~`veg.build_scatter` + `veg.tree_cover_mmi`~~ **DONE.** See the register pass at the top of this
   file and `PERF_LEDGER.md` 2026-09-09 (day).
2. ~~`TreeBreakSystem._consume` off the physics tick~~ **DONE overnight** (ninth pass): the stored
   scatter is updated immediately and ONE chunk per frame is redrawn. `treebreak.consume` is gone from
   the report. The comment in `tree_break_system.gd` that still said this was open has been corrected.
3. `terrain.collision` — **RULED IN BY HIM AND BUILT 2026-09-09.** **Correction: it was 8,192 triangles
   per chunk, not 32,768** (`world_config.gd:11 CELL_SIZE = 4.0`, so a 256 m chunk is 64x64 cells).
   Shipped with the ballistics evidence he asked for.
4. The structural fix behind all three: stop rebuilding a whole 256 m chunk for a 5 m crater.
   **STILL OPEN** — what is left of a crater frame is the mesh rebuild and the canopy MultiMesh regen.

### FOR HIM TO RULE ON
- ~~**Terrain collision as `HeightMapShape3D`?**~~ **RULED IN, 2026-09-09, and shipped.**
- **Plant conversion: build it next, or after more stall work?** STILL OPEN AND STILL YOURS. The stall
  work has a measured queue; the plant ruling has none of its cost measured yet.
- **The canopy real-mesh frame cost** (worst 1% low 37.2 -> 30.1 fps), **the 545 interior props'
  visibility range / fade mode**, and **`mesh_lod/lod_change/threshold_pixels`** are all still open and
  all still yours. Nothing in the 2026-09-09 stall wave touched any of them.

### OPEN / UNEXPLAINED (named, not rounded away)
- A **35–70 ms idle script step with NO instrumented cause**, present even in a completely quiet world.
- His observation, logged not chased: **"weird loading chunks happening."**
- Two successive perf conclusions ("draw-call bound", then "game-thread bound") both came from
  mislabelled columns. The columns are now correct; treat any perf read dated before 2026-09-08 night
  as unverified.

---

## NAPALM STUTTER WAVE — 2026-09-09 night (recorded by the overseer)

**FIXED and gated** (`tests/probe_napalm_stall.tscn`, full detail in `production/PERF_LEDGER.md`):
the ambient napalm frame was **`terrain.crater` at 122.2 ms of a 125.43 ms idle step**, now **13.5 ms
of 54.86 ms**. Cause: a NAPALM crater is an 88 m radius edit that spans four 256 m chunks, and none of
them was armed for the partial patch, so all four fully rebuilt in one frame. Also shipped: his
staggered tree falls, his silent falls past 350 m (proven outcome-identical), and a `[TreeCover]` print
flood cut from 439 lines per strike to 5.

### HIS CALLS — needle-movers, plain language

1. **Trees now fall over ~3.7 seconds instead of instantly. That means cover, concealment and line of
   sight change over a window** — including the sapper breach lane through felled timber, which now
   opens over seconds rather than at the blast. Good, or does the breach need to be instant?
2. **Every terrain chunk now keeps ~1 MB of working arrays so no shell ever pays a full rebuild.**
   4 MB on the demo's 512 m map. On a 2 km map that would be ~67 MB. Ship it as-is, or make it
   conditional on map size before any big map is built?
3. **Distant engagements are simulated man by man and it is the biggest cost in the game:** the AI's
   think + execute is ~30 ms of script every second with only 10 men fighting, and none of it cares
   how far away the player is. Resolving far fights abstractly (same casualties, same ledger rows,
   just not step by step) would be the single largest win available — but it changes the world-sim
   premise, so it is a council question, not an agent's. **Do you want that deliberated?**
4. **Ambient AA tracers have a standing decree as the distant-war visual, and your new ruling says
   distant war should mostly be SOUND.** The tracers did not fire in the measured window so their cost
   is unknown. Measure them first, or cut them on the ruling?
5. **We cannot tell whether the distant-war ambience (`AmbientWar`) has ever fired in a real session** —
   it only ever logged when it stayed SILENT. It now logs when it sounds. Next session's log answers it.

### QUEUED, MEASURED, NOT STARTED (ranked)

- **`terrain.veg_generate` 62.8 ms for ONE chunk** (`veg.build_scatter` 33.3 + `veg.scatter_miss` 33.3
  inside it). Spread across frames now, not made cheaper, not distance-gated. Lives in
  `terrain/vegetation/vegetation_manager.gd` — **the vegetation agent's file. Handed off.**
- **`probe_crater_veg` is RED and it is not this wave** — 1805 prune-vs-regenerate mismatches,
  reproduced identically with this wave reverted. It is the vegetation agent's in-flight feathered-hole
  and paddy-row work. **Handed off.**
- **Night events (Arc Light, rain lightning, distant napalm bloom).** `scripts/ai/ambient_war.gd`
  already is the framework — 400-800 m placement, positional audio, fake emissive with no real light
  (ADR-026). These are new `KINDS`, not new architecture. Craft notes recorded in the ledger: sound
  must lag light by distance; an Arc Light is a walking line, not a flash; lightning must not read as
  ordnance (Fairness Law); and any big night flash briefly changes what can be seen, **including the
  player** — a stealth-economy event (Pillar 2/3, ADR-005) to decide deliberately, not discover.
- **`clutter.flush` 16.3 ms x1** — distance behaviour unattributed.
