# DEMO SHIP BACKLOG — everything between here and a shippable demo

**Opened 2026-07-29** out of the day's playtests. Ordered by the Summoner's ruling:
**allies first, then the air spectacle, then everything else.**

The ship gate, his words: *"More Hueys and jets flying around. At least a few Huey landings
with troops disembarking or unloading supplies. The base attack has parts of the base blow up.
The VC attempt to overrun the firebase."* The demo's job is **scope and spectacle immediately**.

Legend: **[C]** code, I can do it · **[B]** Blender, needs him · **[?]** needs measurement first

---

## SHIPPED 2026-08-04 — RECOIL PIVOT: AK/PPSh/M14 see-sawed from the stock (gun-range feel report)

Summoner, live at the range: *"the motion should be deriving from the barrel going up... it
feels like the barrel is going up but the motion is the butt of the gun going down and keeping
the barrel from rising from its horizon point."* Measured, not eyeballed
(`tools/probe_recoil_pivot.tscn`): the viewmodel punch (`weapon_holder.gd` `_update_weapon_position`)
rotates the model about its node origin — and three GLBs park their geometry at their armory
rack station in the rifle_idle pose, metres from that origin (root-local z, gun span):
**m16a1 0.00..−0.93 (origin AT the butt — why it felt right) · shotgun −0.88..+0.12 · ak47
+7.2..+8.1 · m14 +2.9..+4.0 · ppsh41 +27.2..+28.1**, the bench hip poses compensating with
`hip_position.z` of −8.0/−4.0/−28.0. A pitch about a pivot 4–28 m away = translation + slight
nose-up about the gun's middle: butt sags, barrel pinned. Fix (one mechanism, all guns):

- `weapon_holder.gd` — `_measure_recoil_pivot()` measures the stock-end z (gun meshes only,
  rifle_idle pose) at model load; `punch_pivot_comp()` (static) adds the translation that
  re-seats the punch rotation's pivot at that stock point. `.tres` untouched.
- Probe numbers, full-strength punch, muzzle dy vs stock dy (BEFORE → AFTER):
  m16a1 +0.024/+0.0002 → +0.024/+0.0003 (**reference preserved to 0.1 mm**) ·
  ak47 −0.158/−0.178 → +0.020/+0.0004 · ppsh41 −0.232/−0.241 → +0.008/±0.000 ·
  m14 −0.081/−0.113 → +0.032/−0.000 · shotgun −0.020/−0.021 → +0.009/+0.008 (butt no
  longer dips; character kept). Muzzle now rises, stock holds, on every gun. Headless boot
  0 SCRIPT ERROR.
- **He may want a light re-dial of AK/PPSh/M14 recoil `.tres` values** — today's numbers were
  tuned against the broken motion (PPSh at 0.35 recoil_vertical looks dialed-down to hide it).
- **FIXED 2026-08-05** (`ithaca_fp.glb`, re-export). Verified against `f026f4fa~1`: the old GLB
  had `MuzzlePoint` at +0.458 (stock end) and no sight markers at all; the new one has
  `MuzzlePoint` −0.692 co-located with `SightFront` −0.692, plus a real `SightRear` −0.025.
  The re-export also brought the rack station in (ArmsRig root z 0 → −59.546), so
  `shotgun.tres` `hip_position.z` −0.148 → −59.694 and `ads_position.z` → −59.288, per the
  AK/PPSh/M14 convention; re-aim on the bench. Same treatment applied to the new `m60_fp.glb`
  (root z −36, `hip_position` was 0,0,0). NOTE: `tools/validate_viewmodel_glb.py` passes a gun
  whose root sits metres off origin — it has no rack-station check.
- **Deep defect, deferred:** those three GLBs are off the ruler contract (station offset baked
  into every clip). Re-export would move the guns on screen and void his saved bench poses, so
  it waits for a session where he can re-aim poses after re-export.

## SHIPPED 2026-08-04 — SHOOTING THROUGH THE WORLD'S BUILDINGS (gun-range ruling)

Summoner, at the gun range: *"how do we get that shooting thru to work with our buildings
that exist in the game world?"* Measured first: `bullet_system.gd:199-209` full-stops any
untagged world collider, and for every `mesh: true` structure the collider a round hits is
the GLB's own nested `-col` StaticBody3D — which the old root-only tag never reached. **Every
thatch hut in the game was silently bulletproof.** Fixed in three places, one group API
(`soft_cover`/`hard_surface`, unchanged):

- **Structures** — `site_planner.gd` `tag_ballistics()` (new static) stamps the material
  from `CollisionTable.is_soft()` onto EVERY collision object under the placed structure,
  nested GLB bodies included (`place_structure`). Village, temple, VC camp, RTS sets covered.
- **Firebase GLB** — `_tag_fsb_ballistics()` tags all compound colliders by mesh-family name:
  soft = `FSB_SOFT_PREFIXES` (hootch, GP tent, mess, aid station, latrine, supply dump,
  water point, burn barrel, barbwire); hard = everything else (earth/sandbag/timber/bunker).
  Boot: `[FSB] ballistic tags: 35 soft, 330 hard`.
- **Destructibles** — `destructible.gd` `_ready()` tags by `kind`: `wire` soft, all other
  kinds hard (they are sandbag/earth/timber); `_do_destroy` already dropped both groups.
- **Probe** — `tools/probe_structure_ballistics.tscn` PASS: 4x M16 through a real
  `nha_tranh_01.glb` wall kills the man inside (concealment is not cover); 2x M16 into
  `bunker.glb` = 0 damage (cover still covers). Headless boot: 0 SCRIPT ERROR.
- **Re-export contract** extended: `placement_pipeline_map.md` §3.8 — soft/hard rides the
  mesh-family NAME; a renamed tent family flips bulletproof.

Vietnam-honest calls made where a name was ambiguous (noted for override): supply dump
(crates) SOFT · water point (thin-steel trailer) SOFT · burn barrel (empty drum) SOFT ·
TOC HARD (most-sandbagged structure inside the wire) · tower/timber HARD.

**Follow-on ruling, same range session, verbatim:** *"the rpg thumper grenades and any bombs
and stuff can penetrate sandbags and bunkers 50 percent of the time or something like that."*
Shipped in the blast path only (`combat_manager.gd` — `_can_damage_multipoint` replaced by
`_blast_multiplier`, all four target loops updated; bullets keep the absolute hard stop in
`bullet_system.gd`):
- Fully-blocked 8-point check + hard-cover blocker → per-target roll
  `_blast_defeat_chance(max_damage) = clamp(max_damage/380, 0.5, 0.75)` — his 50% floor for
  grenade/M79 grade, LAW/RPG-2 ~0.66, RPG-7 caps 0.75. On defeat the man takes
  `BLAST_THROUGH_COVER_MULT 0.6` of the blast (the wall bleeds the pressure, named choice).
- Soft cover (thatch/canvas) never stops blast — always defeated at the same 0.6.
- `BLAST_PROOF_PREFIXES` = `fb_terrain_mound`, `fb_berm_ring` + all untagged colliders
  (terrain): meters of earth stay absolute, so the compound berm is not half-disarmed
  against every arty shell.
- Big HE vs a live Destructible is untouched and correct: the props loop
  (`combat_manager.gd` radius-only, no LOS) still simply destroys a 110-hp sandbag.
- Probe `tools/probe_blast_cover.tscn` PASS: 20x M26 vs hard wall → 10/20 damaging; 20x
  RPG-7 → 19/20; 5x M26 vs soft wall → 5/5; 4x M16 vs the same hard wall → 0. Headless
  boot 0 SCRIPT ERROR; `probe_structure_ballistics` still PASS.

---

## SHIPPED 2026-08-04 — THE EXPLOSION DECREE (visuals x5 · destruction parity · napalm/CBU/WP/arty re-authored)

Live-judged on the bench and ruled the same night (memory `recon-explosion-scale-decree.md` + two
follow-up ruling batches). All verified by `tools/probe_fire_parity.tscn` (PASS, all seven kinds)
+ `tools/probe_fell_visual.tscn` (PASS) + clean headless boots of the project and the bench.

- **All explosion visuals x5, split from damage** — `GunFX.ORDNANCE_VISUAL_MULT`
  (`scripts/combat/gun_fx.gd:118`) multiplies the class ladder; no damage radius reads it.
  Tree-crash and structure-collapse dust pass `visual_mult 1.0` and stay off the x5.
  New `explosion_napalm` kind (scale 2.4 → root 12.0, 1.6x lifetime, heavy audio bank).
- **Destruction parity** — arty: every round craters + `explosion_heavy`
  (`field_director.gd` `_arty_impact`); mortar: `explosion_mortar` (real mortar audio profile);
  Spectre: Bofors craters every 3rd shell + Vulcan chews the zone every 4s hot
  (`spectre_gunship.gd` `VULCAN_CHEW_S`); WP: 3-round barrage leaving FireHazard burn
  (`FirePlan.WP_*`). Probe measured: arty 12 destruction calls, spectre 12, forts die to all three.
- **Napalm delivery** — 5 real tumbling canisters (`ProjectileData.tumble_rate`,
  `projectile_base.gd` `_canister_mesh`) released from the airframe on forward ballistic arcs
  (`cas_airplane.gd` `PICKLE_LEAD_M` — the old code threw late canisters BACKWARD off the plane).
  Probe measured every release ≤1.5m from the airframe at alt 34, velocities forward-down.
- **CBU is a raid** — `FirePlan.CBU_CANS 3` dispensers down the run, each raining 16 bomblets
  over its own ellipse (~134m strip), a crater per dispenser (`cas_airplane.gd` `_open_cluster_at`).
- **Live-jungle felling** — `vegetation_manager.gd` `clear_area` now swaps up to 5 canopy trees
  per blast for hinging fall visuals (FellableTree motion), FIFO-capped at 24 lying logs.
- **Battery telegraphs** — friendly arty/mortar/WP/illum play tube thump + incoming whistle
  (siege pattern, `field_director.gd` `_battery_telegraph`).
- **Illum reachable** — HUD net row 7 (`mission_hud.gd`), bench key 8, bench stock; probe proved
  the flare lights a bounded circle (target lit, +250m not lit, OmniLight range 252m).
- **Bench fix** — `FireSupportBench.wire` now points DamageSystem at the bench terrain; before
  this every bench crater/scar call silently no-opped.
- **Dispatch mark** — EVERY dispatched call (bench direct keys included) stands its FirePlan
  footprint on the target until the ordnance is down (`field_director.gd` `_mark_dispatch` +
  `DISPATCH_MARK_S`; illum got a real 180m footprint in `FirePlan`, figure moved to the one table).
- **Overfly guard** — no aircraft approach ever crosses within 40m of the player's ground
  position, danger close included (`field_director.gd` `_no_overfly_axis`, enforced inside
  `_run_axis` so every CAS strike AND F-4 flyby resolves through it). Probed across four
  geometries + two live flights by `tools/probe_run_axis.tscn` (PASS): overfly axes rotate by
  the smallest compliant angle; a target nearer than 40m gets broadside (the max possible miss);
  live airframes never closed within 40.0m. Spectre's orbit stays as-is — RULED 2026-08-04
  ("spectere is fine"), the near-overhead orbit at 130m altitude is accepted. CLOSED.

**Verify on the bench (his eyes, the real gate):** keys 1-8 fire 60m along the look axis —
1 bombs · 2 napalm (canister rack + chain above the trees) · 3 arty (8-12 round spiral barrage)
· 4 mortar · 5 spectre (watch the ground get chewed over 30s) · 6 CBU raid · 7 WP burn ·
8 illum. Still open to HIS judgment: whether napalm's bloom clears the treeline visually, and
arty barrage pattern "prettiness".

---

## AUDIT 2026-07-31 — SIX ITEMS BELOW ARE ALREADY BUILT. READ THIS FIRST.

I came here to build the air spectacle and found it shipped. Every line below is verified against
code, not against this document. **Do not build these again** — that is the divergent-systems
failure, and this backlog is currently the thing causing it.

| Item | This doc claims | The code says |
|---|---|---|
| **B1** air cadence | "schedules ONE transit per sim-hour" | `TRANSITS_PER_HOUR = 3` (`air_traffic.gd:62`), across 18 daylight hours |
| **B3** jet formations | "`CASAirplane` flies single" | `FORMATION_SIZES` (`air_traffic.gd:39`) — 6-9 Hueys, 3-5 jets, 2 skyraiders |
| **B4** air over the firebase | "routes are not aware of the compound" | `TRANSIT_KEEP_OUT_M = 150` (`:284`, applied `:294-304`), `SPECTRE_KEEP_OUT_M = 420` (`:226`, applied `:416-419`) |
| **B2** Huey landings with troops | "becomes: fly in, flare, touch down, men out" | `HeliLift.attach(heli, _friendly_director())` at `air_traffic.gd:544`, with the full inbound/ground/climbout/outbound cycle at `:518-570` |
| **C1** sapper stress room | "his ask: a sterile stress room" | `scenes/levels/sapper_room.tscn` + `scripts/levels/sapper_room.gd` exist |
| **C2** base must blow up | "the wiring to the blast bus is the gap" | The bus is wired: `combat_manager.gd:178` sweeps `AgentRegistry.props` on every explosion, `game_flow.gd:208-254` picks a LIVE parapet segment off it, `sapper_charge.gd:86` the same |

**So the demo's remaining bottleneck is NOT code.** Nearly every item on this list is *built and
unverified*, and unverified is discharged only by HIS playtest (ADR-015) — never by a probe and
never by an agent's reading. The verify lines under each item below are the actual work.

**C7 IS BUILT — HE BUILT IT HIMSELF**, commit `09cd39bf` (2026-07-30 18:27, "Four squads that flank,
not one mass that doesn't"). `siege_director.gd:285-340`: `ASSAULT_SQUADS = 4`, each with its own
`siege_assault_%d` tag and therefore its own `squad_id`, spread over `SQUAD_SPREAD_DEG 150` of arc,
with squad 2 held back as a base of fire at `SUPPORT_STANDOFF_M 90`. The reinforce path splits too
(`_build_assault(extra)`), which is the path the demo actually takes to full strength. **Do not
build this. It is the SEVENTH item this document has claimed was open while it was already
shipped** — I asked him to rule on it and he had already coded it.

**Genuinely still open:** C3b (needs his Blender) · D1's remainder (no map-edge road) · C4 (the
siege trigger is `OS.is_debug_build()`-gated at `game_flow.gd:50`, so it does not exist in a shipped
demo build).

---

## A. ALLIES AND THE GARRISON — first

**A1. [C] Ally path failures at 5-8m.** *(fix applied 7/29, unverified)*
`NavRouter` refused to clamp a target further than **4m** off the navmesh and handed the raw
unreachable point to the query - a guaranteed no-path. A garrison post inside a hootch
footprint sits further than that. Clamp limit raised to 12m with a named guard.
**Verify: the `[NAV] ally ... no path` count per boot. It was 8.**

**A2. [?] Whatever survives A1.** If failures persist they are navmesh ISLANDS, not clamping -
the compound fragmenting into disconnected patches. Diagnose with region connectivity, not by
raising numbers.

**A3. [C] Garrison work is invisible at demo open.** Schedules rewritten 7/29 so the night
shift is the busy one (sentry_night on the wire 18:00-05:30, gun crew on the guns, radioman on
the net, quartermaster moving ammo after dark). **Needs his eyes to confirm it reads as a
working base.**

**A4. [C] Off-duty men need somewhere to BE.** *(fixed 7/30, unverified — and it was FAR
bigger than "off-duty sits around")* Seven BT leaves in `civilian.gd`
(`:710/718/726/734/742/750/756`) were **byte-identical freezes**, so twelve scheduled actions
collapsed into four behaviours and only `walk_paddy` ever used a marker. **`ACTION_WORK` never
walked a man to his post — so the entire A3 night shift below never manned anything.** It only
looked right because `place_for_current_hour()` teleports everyone at spawn. `bb["target_pos"]`
was resolved from the 191 markers every sim hour and read by nothing.
`_bt_work` now walks there and holds, with a ±1.5m offset derived from the man's NAME so it is
identical every run (ADR-010). `off_duty`'s 20.5-22.0 block flipped SIT -> WORK: those are the
demo's own opening hours.
**Verify: do the sentries WALK to the wire at dusk, or are they just standing there?**

**A5. [?] Squad members stacking.** The 2-man post overlap is fixed (stations spread by index).
If he still sees two men in one skin it is the follow-slot convergence, not spawn.

---

## B. THE AIR SPECTACLE — the ship gate's biggest item

**B1. [C] AirTraffic schedules ONE transit per sim-hour** off a random kind list
(`_seed_default_schedule`). That is ambient weather, not an opening. Needs a demo-facing
cadence: several airframes up at once, continuous movement on the horizon.

**B2. [C] Huey landings with troops.** `lz_cycle` exists as a profile. He has just built the
landing + load/unload animations, so this becomes: fly in, flare, touch down, men out, lift.
**Ask him for the clip names before building - do not guess them.**

**B3. [C] Jet formations.** `CASAirplane` flies single. A pair or a vic crossing high is pure
silhouette work and cheap.

**B4. [C] Air must not fly through the firebase.** Same class as the convoy (D1): routes are
not aware of the compound.

**B5. [?] Perf ceiling for all of it.** PERF_LEDGER says this project is call-bound. Every
airframe is draw calls. Measure before committing to a count.

---

## C. THE BASE ATTACK — ship gate items 3 and 4

**C1. [?] Nobody has ever seen the sapper detonate.** His ask: a sterile stress room - just
him, three sappers, some wire and sandbags to blow. Answers reach, detonation and destruction
in one test. Parts exist: `ai_stress_arena` pattern, `SapperCharge`, `Destructible`,
`AgentRegistry.props`.

**C2. [C] Parts of the base must blow up.** ADR-031 destruction doctrine and the 80 authored
parapet segments with HP already exist; the wiring to the blast bus is the gap.

**C3. [C] The VC must attempt to OVERRUN, not probe.** *(SHIPPED 7/30, unverified — council
`war_room/2026-07-30_demo_backlog/`)* The stall was never the objective clearing, it was
arithmetic: `combat_goals.gd` scored ADVANCE at most **0.61** for an nva_regular against an
incumbent ENGAGE of **1.19**, so the assault reached the wire and traded shots forever.
Fixed by biasing the GOAL, never the legs — `Context.assault_press` + `PRESS_ADVANCE 0.75`,
rotated over 35% of the assault every 8s by `SiegeDirector._rotate_press`. A pressing man
still shoots, which a leg override cannot do (`assault_driven` returns before the combat
dispatch at `enemy_base.gd:1322` — that is the 7/29 "nobody fought" bug).
**THE LANE IS THE GATE, deliberately.** Nothing re-bakes the navmesh on destroy
(`nav_baker.gd:16-18`) and the barbwire is one merged `bwire_card_ring` of ~450 cards on
three rings (`gen_firebase_v3.py:323-372`), so three impassable rings stand outside any hole
you blow. The gate is the only opening through both, and one lane in 2-5 man rushes is the
doctrinally correct answer anyway. **Nothing in the overrun reads a breach**, so none of it
is blocked on art.
`siege_overrun` fires once at `OVERRUN_MEN 3` measured per-bearing in 36 bins (the parapet
runs 49.3-96.1m, so one mean radius would be wrong on two thirds of the compass) ->
"THEY'RE INSIDE THE WIRE" + siren.
**Verify: do they funnel at the gate and get inside, and does the call fire once?**

**C3b. [B/C] THE REAL BREACH** — replaces the gate-only lane. Split `bwire_card_ring` per
sector in `gen_firebase_v3.py`, re-export, and re-bake nav on `Destructible` death.
**Deletion condition: when this lands, the gate stops being the whole answer.** Costs 36
draw calls where there is 1, on a call-bound project — that is why it was not paid for the demo.

**C4. [C] Siege is on a 600s/720s arc** - too slow to test. A debug trigger exists on `[J]` but
only in debug builds.

**C6. [C] THE GARRISON LIGHTS ITS OWN WIRE.** *(shipped 7/30, unverified)* Illum had only ever
reached the world through the player's own allotment (`_run_illum_mission`, which bills his
stock) or a thrown hand flare. Night sight is **56m open** and the assault crosses from
190-235m, so **the entire overrun happened in the dark** - he would hear it and never see it,
and could not watch it crest or break. New `FieldDirector.garrison_illum(at)` pops a round from
the compound's own tube and **never touches `fire_support` stock**; `SiegeDirector._walk_illum`
puts one up `ILLUM_STANDOFF_M 140` out on the attack bearing, `ILLUM_FIRST_S 12` after
stand-to, then every `ILLUM_INTERVAL_S 70`. Burn is `GARRISON_ILLUM_BURN_S 55`, deliberately
SHORTER than the interval: the ~15s of darkness between rounds is where the dread lives, and a
permanently lit compound is a lit stage. Probes are never lit - holding off in the dark is what
makes a probe read as a probe. Feeds the already-scoped `_light_check()`.
**Verify: does the lit ground show them crossing, and does it go dark again between rounds?**

**C7. [C] ONE SHARED `squad_id` THROTTLES THE WHOLE ASSAULT.** *(found 7/30 — **HE HAS RULED,
2026-07-30, restated 7/31**: "there should be four squads with the enemy assault teams and they
should all be trying to flank and maneuver to get into the firebase and not just one large thought
bubble." The DECISION is closed; only the scope below was ever open. Do not re-ask it — this
document saying "needs a council ruling" is what caused it to be asked twice.)* `field_director.gd:51` sets
`enemy.squad_id = hash(group_tag)`, so all 45 `siege_assault` men are ONE squad.
`SQUAD_GRENADE_COOLDOWN_MS 12000` therefore allows **one grenade every 12s across the entire
assault**. The structurally correct fix is one squad per `MarchingCell` (the class docstring
already calls a cell a fireteam) - but `squad_id` is also read by
`EnemySquad.has_covering_fire` (every man currently always has it, worth +0.2 ADVANCE),
`force_ratio`, and `is_broken` (the whole assault currently breaks as one body, alongside
SiegeDirector's own separate ledger), and `spawn_tracked_enemy:56` has already registered the
contact ledger under that id. Changing it moves four systems at once.

**C5. [C] THE DEMO'S NIGHT ASSAULT HAD NEVER HAPPENED.** *(fixed 7/30, unverified)*
`demo_game.gd:29` declared `SIEGE_STRENGTH 40`, but at 720s `_open_siege` hit the
`if d.siege.active` guard (`:197-203`) and emitted a toast. The 600s probe was still active
**and always would be** — its `MAX_DURATION_S 480` expires at exactly `DAWN_AT_S 1080` — so
that branch was taken every single time. **Every demo night ever played was 11 men,
announced twice.** New `SiegeDirector.reinforce(extra)` grows `run_strength` AND `run_peak`
together (strength alone puts live/peak above 1.0 and the break can never fire; peak alone
credits kills the player never made). `SIEGE_STRENGTH` is now **45 TOTAL**, not an increment:
`LIVE_CAP` is 50 and an assault authored at the cap freezes its late cells at the ring, the
2026-07-28 trickle failure.
**Verify: `[Siege] reinforced +34 - the assault is now 45 men` at 720s.**

---

## D. WORLD AND VEHICLES

**D1. [C] Convoys drive through buildings.** *(two real defects fixed 7/30, unverified; the full
routing job DEFERRED - and this item's original diagnosis was WRONG)*
Routing already exists: `mission_generator.gd:337-342` uses `road_network.longest_route()` and
refuses to spawn without a road. But `build(gate, villages)` makes the **gate the hub and
villages the spokes**, so there is **no map-edge road** and a convoy drives OUTWARD from the base
into a village.
**Fixed 7/30 — the column was born in the buildings.** `convoy_spawner.gd` strung vehicles
2..N straight back along `-heading` from `route[0]`, a line through whatever happens to be
there: six vehicles at 6m reaches 30m behind the start, and when the start is the wire gate
those trucks stand INSIDE the compound. They now occupy the first stretch of their own route by
ARC LENGTH (`_seat_along_route`), lead furthest along, so every vehicle begins on the surveyed
line.
**Fixed 7/30 — the column crabbed.** `convoy.gd` never touched rotation after spawn, so every
vehicle held its spawn yaw through every bend. Now `_face_along` lerps yaw toward the direction
of travel at `TURN_RATE 3.0`, using the same `atan2(x, z)` the spawner seats with so spawning and
driving agree.
**Still open:** no map-edge road (routes end at a village centre), trucks collide with nothing,
`road_network.gd:155-171` reads only terrain type + slope on a **12m** grid cell so a hut is
smaller than one cell and this router can never miss a building. Driving a road properly is one
session; driving through the gate is multi-session (interior routing through `-colonly`
trimeshes + a motor-pool datum). Largely invisible in a 512m firebase-holdout slice.

**D2. [C] Spooky keep-out.** Done 7/29 - ambient gunship orbit pushed 420m off `fsb_center`
after it strafed the player's own compound. Verify it never recurs.

**D3. [C] Ambient war audio.** *(fixed 7/30, unverified)* Ruled **FASTER**; "less occurring"
rejected. `_spawn_audio` called `play()` ONCE per event and `lifetime_s` only decided when the
finished node was freed — **a whole distant engagement was one gunshot.** Now two parties
15-40m apart ANSWER each other, each retriggering its own voice: 3-8 rounds at 0.11s (MG 6-14
at 0.075s), then a 2-6s lull, going ragged in the last quarter. Low-passed at 900Hz — past
400m a rifle has no crack, only a slap off the treeline. Lifetime 5-30s -> 14-40s (5s cannot
hold a rhythm). `FIRE_CAP 2`, and a held engagement PRINTS that it was held.
Also adopted the 7/27 pack: it was still using the generic `shot_distant.wav` for every gun in
the war while a measured `fire_<id>_dist.wav` existed for all 17.

---

## B6-B7. THE AIR, 7/30

**B6. [C] Spooky's vulcan fires REAL ROUNDS.** *(shipped 7/30, unverified)* It used to pick a
ground point, paint three decorative tracers at it and apply a small explosion there — the
tracers carried no damage and a man behind the berm was spared by a visibility guess instead of
by the berm, while the same aircraft's Bofors fired real arcing shells. Now per PHYSICS TICK,
3 rounds = 90/s: slant range √(160²+130²) = 206m at 1030 m/s = 0.20s flight = ~18 rounds in
the air, so `MAX_BULLETS 500` is nowhere near binding. 90/s is for the ROPE — a streak is
speed×0.016 = 16.5m, at `tracer_ratio 2` that lights ~148m of the 206m line. Duty 2.0s hot /
2.5s cold. Dispersion preserved by re-aiming a fresh `_zone_point` each tick, NOT by weapon
spread: the fake 25m disc was 25× the area of a 1.4° cone at 206m and losing it would make the
gun read as broken. KEPT: suppression (BulletSystem suppresses nobody — the fake explosion was
this gun's only source) and the report on its own 0.35s clock (`_play_gun` reuses ONE voice).
**ADR-023, same change:** `scripts/combat/bullet_tracer.gd` DELETED (only caller repo-wide),
`VULCAN_DAMAGE`/`_INTERVAL`/`_ROUNDS_PER_BURST`/`_vulcan_timer` gone,
`FirePlan.SPECTRE_VULCAN_KILL_M` -> `SPECTRE_DISPERSION_M` (it could not just die,
`fire_plan.gd:58` draws the map ring from it). New `BulletSystem.fire(..., mark_surface := true)`
— `GunFX` recycles holes FIFO at `MAX_DECALS 48`, so 90/s would erase every player bullet hole
twice a second.

**B7. [C] AIR CAN KILL YOU — and never aims at you unless you ask.** *(shipped 7/30,
unverified)* **`STRAFE_MASK = 1|32|64|512` includes the PLAYER HURTBOX and every ALLY** (layer
32, proven at `projectile_base.gd:111` and `ally_base.gd:441-442`) while its own comment called
bit 32 "enemy bodies". 87 × TORSO 2.5 = **217 vs 100 HP — one round, instant death.** Shipped
7/29 and never playtested, with scripted demo gun runs at 2:40 and siege+60s.
**His ruling 2026-07-30:** *"i want to be able to be killed by the air but i dont need a
warning. but also dont deliberately gun run where the player is unless they call in a danger
close run."* So the mask STAYS lethal and there is NO warning. The discipline is in AIMING:
`authored_strike(..., danger_close)` requires a gun run's beaten path to miss him by
`GUN_STANDOFF_M 120`, rotating through 12 bearings, then dropping guns (keeping napalm) or
refusing the run. `[G]` passes `danger_close = true` — pressing it IS calling it in, and the
axis he chose must fly or the key is useless for tuning. `AirTraffic` now keeps ambient Spectre
orbits off **the player**, not just his base.

## E. ART AND MATERIALS — his side

**E1. [B] Ten materials on default white, no texture.** Named by the boot probe:
`Walnut`, `Walnut.001`, `.003`, `.004` (Ithaca 37 furniture, M79 stock, M70 sniper stock),
`MitchellCamo` + `Webbing` (helmet shell, EVERY body), `bandolier_tex`.
**The `.00N` duplicates are separate slots - fixing "Walnut" alone misses the sniper and shotgun.**

**E2. [B] Firebase re-export** picks up four already-fixed generator changes: mound plate
collision off, parapet to trimesh, five merged veg objects to trimesh, mound manifest.
See `production/blender/FIREBASE_BLENDER_HANDOFF.md`.

**E3. [B] Fire slits + bunker embrasures.** Handoff §2.

**E4. [B] The fighting step.** Parapet top is 2.39m against a 1.6m eye, and the berm crest is a
knife edge with the wall on it. Spec with numbers in handoff §2b. **This is the "stuck in the
dirt mounds" report.**

**E5. [B] `Base_Human` out of the US body export** (or renamed `grunt_base_human`). Patched in
code; the special case deletes itself once the export lands. Handoff §5.

**E6. [C] Skin/face mismatch.** Fixed 7/29 - the dresser now slides every surface that samples
the face atlas, matched by TEXTURE not by material name, so face and body can never diverge.
Warns loudly if a body carries skin that is not on the atlas. **Needs his eyes.**

---

## F. THE MAP

**F1. [C] M opened nothing.** Fixed - the control's rect was 0x0 so the bottom-right-anchored
sheet drew off-screen. Boot now warns if the rect is ever too small for the sheet.

**F2. [C] Only right-click places marks.** *(fixed 7/30, unverified — and the CODE corrected
the report)* Left-click was never fighting the order circle: off a circle it did **nothing**
(`topo_map.gd:376-380`). The map's main verb was simply on the button nobody reaches for first.
**LEFT is now the pencil** — a circle is a small hotspot and still takes a left click, so they
cannot compete for a pixel — and **RIGHT is the eraser**, which the sheet has NEVER had; marks
went on and stayed forever. New `MissionState.erase_pencil_mark_near`, 45m grab radius. The
grease-pencil law forbids the GAME erasing a mark; it says nothing about the player.

**F3. [?] The note verb is not intuitive.** His ask: **research how Arma does its map** and
learn from it before redesigning. Not started.

**F4. [?] Held-object map in the player's hand.** His design question - a flat plane in the
hand with the live sheet on it, versus the current screen-space corner draw. Deferred by him.

---

## THE INSTRUMENTS BUILT TODAY — keep them, they earn their keep

Each of these turned a playtest complaint into a named line in the log:

- `[FSB] one ground` - terrain vs the authored mound, warns past 0.6m
- `[FSB] N collider(s) floating >3m` - caught the four invisible veg slabs
- `[MODEL] renders N body-sized meshes` - caught `Base_Human` inside every soldier
- `[MODEL] N surface(s) left on DEFAULT WHITE` - named all ten white materials
- `[DRESSER]` stranded-skin and missing-stock-helmet warnings
- `[TOPO]` rect-too-small warning
- `[FSB] stand to: promoted N` - the garrison question, answered every boot

---

## 2026-07-31 WAR ROOM AUDIT POINTER
Full audit (demo vs full game, ship verdict) decreed at
`production/war_room/2026-07-31_demo_ship_audit/synthesis.md` (evidence + debate alongside).
Verdict: shippable by 8/9 IF export preset + playthrough #1 land by Mon 8/4.
Week plan: W1 export/launch → W2 death-path freeze → W3 end card → W4 boot gate → W5 M60 →
W6 furnish interiors → W7 garrison ceiling (measure once) → W8 SimClock air dedup → W9 M79.
His bench: S1 wire-ring split, S2 medical_complex export. All else WAIVED (costs named in discussion.md).
AMENDMENT 7/31: Summoner revoked the D8 waiver — bunkers must be shootable-through. Added as S3
(embrasures + fighting step, his Blender, recipe in blender/FIREBASE_BLENDER_HANDOFF.md §2/§2b/§2.5,
fold into the S1/S2 re-export). AI-manned bunker positions stay deferred.
UPDATE 7/31 (evening, Wyrm): W1-W9 DISCHARGED except two that closed differently.
- W1 SHIPPED: build/RECON_Demo.exe exists (first export in project history; templates were
  never installed). "Windows Demo" preset, custom feature "demo", run/main_scene.demo override.
  Smoke-verified in RELEASE: boot -> probe(11) -> 4-squad(45) -> unattended player KIA at 70s
  -> end card. Zero script errors.
- W2/W3 SHIPPED: KIA routes to a shared pausable end card (RESTART/QUIT, mouse freed);
  double-siren fixed (reinforce announces only probe->assault). ROOT FIX: world is now
  PROCESS_MODE_PAUSABLE - tree-pause NEVER froze the war before, in the full game either.
- W4 SHIPPED: no more double world-build on demo boot.
- W5 -> HIS BENCH: M60 reaches the demo via the MG emplacement (cannot pull); hip_position
  fix is a bench-eyes job. NEW PLAYTEST ROW: man the MG, check where rounds land.
- W6 CLOSED INVALID: interiors are NOT empty - 178 baked props confirmed in the release log
  ("[FSB] 178 interior prop(s) culled past 40m"). Furnishing would DOUBLE them (doc §5 was
  right; the audit scout was wrong). HeliLift also ran live: "[LIFT] delivered 4 - 28/28".
- W7 MEASURED AND SET: FSB_GARRISON_MAX_MEN 24->40, FSB_WORK_POST_CAP 12->24.
  A/B on the exported demo (150s): mid-siege 48.0 FPS at BOTH values. *(Provenance broken —
  the `--print-fps` this row cited did not exist until 2026-08-04; treat 48.0 as unverified.)*
  TRADEOFF NAMED: 40 defenders vs 45 attackers may soften the overrun drama - if holding
  feels safe now, dial back toward 28-32. Playtest row.
- W8 SHIPPED: SimClock dedup key now per-entry (3 transits/hr were collapsing to 1) and
  air books day=-1 (the sky died at the first midnight rollover).
- W9 SHIPPED: m79_arms_viewmodel.tscn + model_path - the Blooper is a whole weapon now.
REMAINING FOR 8/9: his bench (S1 wire split, S2 medical export, S3 bunker slits), his
45-min playtest on build/RECON_Demo.exe, M60 bench row, playthrough #2 on the polished build.

---

# AMENDMENT 2026-08-03 â€” THE DAY RESCOPE (War Room decree)

**Decree:** `production/war_room/2026-08-03_demo_day_scope/synthesis.md`. Six architects, code only.
The Summoner rescoped the demo from the 7-minute night slice to a **~30-minute one-day arc ending
with the night attack**. His ten rulings are recorded in that session's `briefing.md` Â§0 and are
DECIDED â€” do not re-open them.

**READ BEFORE COSTING ANYTHING:** this backlog was spot-checked 5/5 HONEST by the Devil's Advocate
(C4 `game_flow.gd:50`, C3b `gen_firebase_v3.py:368`, A1 `nav_router.gd:37`, E5 `model_actor.gd:546`,
W7 `site_planner.gd:853`) â€” **but it stops at 7/31.** No chow hall, no tiered expansion, no rescope.
Every estimate drawn from it **UNDER-counts**.

## D-0. MEASUREMENTS FIRST â€” these gate the build, nobody has ever run them

| # | Measurement | Gates | Note |
|---|---|---|---|
| **M-1** | `tests/test_firebase_garrison.tscn` then print the occupation histogram from `fsb_garrison_plan`. **FAIL = a wall of `off_duty`.** GLB markers carry Blender's DOT suffix (`work_rest.001`); `site_planner.gd:905-909` strips only `_<int>`. If the dot survives import, **~185 of 198 markers are junk** and the aid-station seed (`:969-978`) + litter team have **never fired**. | every chow-hall and medical decision, and the whole marker convention | **HIGHEST-VALUE HOUR AVAILABLE. RUN IT FIRST.** |
| **M-2** | `build/RECON_Demo.exe --print-fps`, A/B/A at `SIEGE_STRENGTH` 45 â†’ 55 â†’ 45, 300s each. **FAIL if run B prints `[Siege] cell of N held at the ring` (`siege_director.gd:445-446`) at all, or ends with no `_break_siege`.** *(Spec repaired 2026-08-04: `--print-fps` now exists — `scripts/dev/fps_printer.gd`, attached in `game_flow.gd:enter_hub`. It did NOT exist when this row was written.)* | D-1 and D-9 | prior: FPS moves ~0 |
| **M-3** | Run the exported demo **30 minutes** with `--print-fps`, watch draw calls *(flag real as of 2026-08-04, see M-2)* | D-2 | nothing has EVER run 30 min |
| **M-4** | Count squad arrivals at the gate on a T+10 move order, 10 runs | D-4 | pathing risk |
| **M-5** | Time a Huey from launch-on-pad to clearing the compound | D-6 | no launch path exists |

## D-1 â€¦ D-2. THE TWO LANDMINES â€” defuse before anything ships

- **D-1 [C] THE ONE-WAY FREEZE LATCH â€” the 7/28 trickle failure, still loaded.**
  `_enforce_live_cap` calls `set_physics_process(false)` (`siege_director.gd:444`) and
  **`set_physics_process(true)` exists NOWHERE** in `marching_cell.gd` / `siege_director.gd`. A
  frozen cell never marches again but still reports full paper strength (`marching_cell.gd:56-57`),
  so `live/peak` never falls and **the assault can never break.** `SIEGE_STRENGTH = 45` is the only
  thing disarming it. **DECREED: the day may move night strength DOWN from 45 and NEVER up. The
  Arbiter's proposed 55 is STRUCK â€” it arms this on the worst-outcome branch.**
- **D-2 [C] DROPPED WEAPONS SPAWN FIRST-PERSON VIEWMODELS â€” the largest unbudgeted accumulator.**
  MEASURED: `ak47.tres:27` points at `ak_fp.glb` = **11 draw calls, 1 skin, 6 anims, `ArmsMesh`**,
  offset âˆ’1.81m (buried underground). `LIFETIME_S = 600` has **never once expired** in a 7-minute
  demo and **resets to 300s whenever the player is within 40m** (`world_weapon.gd:87-94`). 45
  attackers dying on the wire the player is standing on is **~495 immortal draw calls** against a
  ~1,350-call baseline. Secondary: `EnemyBase.unreported_corpses` is unbounded (`enemy_base.gd:961`,
  appended `:1011`), scanned by every unit every heartbeat (`:804-807`, `:1022-1031`), cleared only
  at world build. Decals, corpse meshes, evidence ledger and flight bookings are all **bounded â€” do
  not spend time there.**

## D-3 â€¦ D-10. THE ARC

- **D-3 [C] THE CLOCK: day 38x, night 20x. Start 06:30, NOT 07:00.**
  **0700 does not exist in code** â€” `mission_weather.gd:40` holds {5.5, 10.0, 17.5, 21.0} and wins
  over `mission_generator.gd:248-255` via `game_flow.gd:677-679`. **THE SUN DOES NOT MOVE**
  (`mission_weather.gd:20-25`, `:77-83`): lighting changes only on a period crossing, and DAY is one
  flat block 07:00â€“17:00. So the arc is sold as **four lighting events, one per act** â€” spawn in
  dawn, DAY snaps as you clear the gate, DUSK on the return, NIGHT at stand-to. **The night must run
  SLOW**: crossing midnight re-arms a second siege roll (`siege_director.gd:171-174`), unlatches the
  fire-support allotment (`field_director.gd:1240-1245`) and **raises the sun mid-attack**.
  Sacrificed: the DAWN end card, and `AmbientWar`'s hour-driven density (`ambient_war.gd:62`).
- **D-4 [C] THE OPENING: the squad walks out without you at T+10s.** There is no gate pointer in
  code. Use `OrderMode.MOVE_TO` (`ally_base.gd:160`, `:206`; `squad_system.gd:201-205`) to
  `patrol_gate_pos` (`field_director.gd:991`), rendered by the squadmate labels already exempt from
  the no-rails ruling (`mission_hud.gd:336-368`). **Respects the ADR-030 HUD deferral â€” no new UI.**
  The order MUST expire at the gate. Gated on M-4.
- **D-5 [C] THE AMBIENT CELL â€” ruling 9 is structurally impossible today.** The hunt net is
  double-gated: it needs a COMBAT contact (`field_director.gd:113-119`) AND a non-empty evidence
  ledger fed only by player gunfire (`:35-38`, `:143-145`), then waits 70â€“110s (`:118`). Ship ONE
  cell walking a road between village and camp, spawned at boot, crossing the player's front at
  ~2:45 â€” let-pass-or-shoot. **Three hard constraints:** the road must stay **>90m from
  `fsb_center`** or `_poll_firebase_threat` (`:1328`, `FSB_THREAT_MEN` 2) stands all 40 men to at
  07:05; `last_combat_contact_ms` is a **global static** (`enemy_base.gd:272`) so any enemy going
  loud fires a false "YOU'VE BEEN MADE"; tag it `"hunters"` so D-9 folds it in.
- **D-6 [B]+[C] MULTI-PAD: the code is built, THE PADS ARE NOT.** `_free_pad` already walks all pads
  at capacity 1 (`air_traffic.gd:467-515`). **MEASURED twice independently: the shipped GLB has ONE
  pad â€” all three pad-prefix nodes sit at the identical position (22.18, 4.01, âˆ’41.29).**
  `air_traffic.gd:54` ("three PSP pads") is **DRIFT â€” correct the comment.** Priced: Huey = **27
  draw calls**, Chinook = **84 calls / 12,028 tris**, baseline ~1,350 where 1,000 calls is ~6 FPS
  (`PERF_LEDGER.md:686,700`). **RULED: ONE new pad marker (two total), two concurrent cycles max,
  Chinook never concurrent.** **BUG:** `_dispatch` checks the ceiling once before the lead (`:328`)
  then adds 8 wingmen unchecked (`:343-349`) â€” up to 22 airframes, +44% calls. **AND no heli ever
  starts ON a pad** â€” every `lz_cycle` begins airborne ~280m out (`:536-540`), so his "birds lifting
  as he turns the corner" needs a launch path that does not exist. Gated on M-5.
  **The rescope's real frame cost is DAYLIGHT, not men:** `air_traffic.gd:93-108` books hours 6â€“23,
  so a day demo fires **~39 transits + all 4 LZ cycles versus today's ~18 + 1.**
- **D-7 [C] THE MIDDAY RETURN IS STRUCK. The chow hall moves to 21:30, before stand-to.** The return
  fires the after-action report the demo EXCLUDES (`field_director.gd:1564-1578` vs
  `demo_game.gd:20`) â€” debrief toasts and a possible FIELD PROMOTION â€” and `_bank_patrol` resets
  `state.start_time_ms` (`:1584`), **making the afternoon easier.** Sacrificed: the two-sortie
  structure.
- **D-8 [C] THE VILLAGE IS MOSTLY BUILT.** Civilians exist (`civilian.gd`, 38 KB, behaviour trees +
  SimClock schedules + households); the informer path is real (`civilian.gd:582-594` to
  `field_director.gd:627-641`). **The gap is a coin flip** â€” `mission_generator.gd:979` gives the
  demo village a ~50% chance of an informer existing at all. **RULED: force it to 100% in the
  demo.** Also **first-signs are TWO DISABLED LINES** â€” the planner already places them at 150â€“300m
  (`:496`, consumed `:765-769`); the demo ships zero (`:723-724`). And **the enemy camp is a PLAN
  EDIT** â€” the stamper is built (`site_planner.gd:1629`, dispatch `:761`), the demo just disables
  camps (`mission_generator.gd:740-741`).
  **THE DESTRUCTIBLE TUNNEL MOUTH IS ALREADY SHIPPED â€” ZERO ENGINEERING COST.** HOLD-interact
  satchel, grenadier-skill hold time, blast, nav re-bake, cross-patrol permanence
  (`player.gd:838-891`, `campaign_state.gd:478-490`, consumed `site_planner.gd:195-202`); **both
  stampers already place one** (`:258`, `:1632`). Only remaining: confirm the demo loadout carries a
  satchel (`player.gd:843`), and discoverability.
- **D-9 [C] DAY FEEDS NIGHT, DOWNWARD ONLY.** `night = 45 âˆ’ hunters_killed âˆ’ 8 (mouth blown)`,
  **clamped 28â€“45.** **Never price it off `state.kills`** â€” the bank wipes it
  (`field_director.gd:1584`). **Hunters are never reaped** (`siege_director.gd:712-716` walks only
  siege cells) â€” clear survivors with `despawn_tracked_enemy` (`:72`) at stand-to, **as a despawn,
  not a casualty.** **A BODY COUNT IS IMPERCEPTIBLE** (night sight 56m, the assault crosses
  190â€“235m, illum strobes 55s on / 15s off) â€” so express it in three places, none of them a number:
  the RTO's gate line (`field_director.gd:667-673`), a **BREACH or no breach** (the siren is already
  wired), and the end card (`demo_game.gd:331-359`). **IF ALL THREE ARE NOT BUILT, DO NOT BUILD THE
  LINK** (r4bk Law).
- **D-10 [C] TOP THE HUNT POOL TO 6 ON EACH OUTBOUND GATE CROSSING** (same seam as the fire-support
  grant, `field_director.gd:1221`). 12 men (`:106`) at 2â€“4 per wave (`:149`) is **~7.7 minutes of
  contact, then the AO is empty forever** â€” invisible at 7 minutes, arc-breaking at 30.
  **SACRIFICED: ADR-035's finite-pool promise, inside the demo only, by documented exception. The
  ADR is NOT amended.**
  **QUESTION D IS CLOSED â€” the Arbiter's premise was BACKWARDS.** `field_mult` multiplies the WAIT
  (`field_director.gd:148`, its own comment `:129`), so decay makes the AO HARDER; and it never runs
  at all because `state` resets at every wire crossing (`:132`, `:1584-1587`). **Do not invert it.
  Do not flatten it. Leave it.**

## D-11 â€¦ D-13. FIRE SUPPORT, ALLIES, FAIL-FORWARD

- **D-11 [C] THREE CALLS = THREE DIFFERENT VERBS: one bombing run, one artillery, one mortar.**
  "3" matches nothing shipped â€” the grant is **5â€“8** (`field_director.gd:1251-1255`: up to 3â€“4
  mortar + 1 bomb + 1 arty + 2â€“3 illum), and the demo actually runs the class default `mortar 2,
  illum 2` (`:304-305`) because `demo_game.gd` has **zero** fire-support references. **Three defects
  to fix alongside it:** **illumination has NO menu row** (`mission_hud.gd:97-104`) though key 7 is
  bound (`:243`) â€” **a shipped r4bk violation**; `_granted_day` (`:1243`) lets a post-midnight 120m
  step **re-arm mid-siege** (D-3's slow night prevents this incidentally â€” make it structural); and
  `p["fire_support"]` (`mission_generator.gd:509`, `:675`) is read by nothing, with ADR-011's
  pointers all stale.
- **D-12 [C] ALLY AI TO THE VIETCONG BAR â€” minimum set, in cost order.** The Arbiter's five verified
  pointers all HOLD (`ally_base.gd:78-117`, `:233-235`, `:395-409`, `:97`). **Scope correction: the
  squad is 8, not 5** (`squad_system.gd:19`).
  1. **~2 lines â€” feed `squad_broken` / `force_ratio` to the shared scorer.** Allies never do
     (`ally_base.gd:782-801`); the enemy does (`enemy_base.gd:1408-1409`). The squad-break toast is
     a cheque the AI does not cash. *Sacrificed: the squad will visibly leave you at the climax.*
  2. **~6 lines â€” MOS-weighted courage.** MOS is read **NOWHERE** in the AI (one hit, and it is a
     comment, `ally_base.gd:166`); courage is a flat `randf()` (`:296`), so **the RTO plays hero
     ~25% of the time** and skips the cover trip (`:109`). *Sacrificed: a 10m radio leash dragging
     the player backward.*
  3. **~12 lines + a look-check â€” A CONCEALMENT TERM. THIS IS THE VIETCONG GAP.**
     `_find_cover_point` accepts a position only if a physics ray is BLOCKED
     (`ally_base.gd:1298-1303`), and grass/fern/bush have **no collider by contract**
     (`tree_cover_layer.gd:17-19`). **But the simulation ALREADY rewards the grass** â€” vegetation
     cuts sight (`sight_cap.gd:32-39`) and heavy jungle blocks LOS 30% per cell
     (`gameplay_grid.gd:406-411`). **The AI cannot see a reward the sim is already paying. One O(1)
     grid read.** *Sacrificed: your own men vanish into grass â€” check the squadmate nameplates in
     the same session.*
  4. **~15 lines â€” make the grenadier's cluster thumper PLAYER-PLACED** via the existing
     `squad_move` aim. **THE VIETCONG INSIGHT, MEASURED:** the squad owns five verbs â€” trap-spot,
     call-for-fire, player-revive + bandages, sustained fire, cluster thumper â€” and **four of the
     five are AUTOMATIC**, which is precisely why only the radio's loss is ever felt. This converts
     one. *Sacrificed: an r4bk debt â€” a bound key with no HUD, taken knowingly.*
  **CUT FOR THE DEMO, ON THE RECORD (not dropped quietly):** downed allies (see Q9), and the 70m
  trunk-collider ring â€” colliders exist only within 70m of the **player**
  (`tree_cover_layer.gd:34-43`), so allies further out have **zero cover at all**.
  **LOGGED:** MARKSMAN has a weapon and a body but is absent from `MOS_ORDER` (`squad_roster.gd:64`)
  â€” **it never spawns.**
- **D-13 [C] FAIL-FORWARD ALREADY EXISTS AND IS COMPLETE** (`squad_system.gd:224-345`,
  `health_system.gd:248-286`, 6 bandages `:10`). **Ruling 7 needs no build.** Two contradictions sit
  inside it instead, both for the Summoner: `revive()` restores **FULL HP**
  (`health_system.gd:276-278`, his 7/18 decree) versus his 8/3 "come back degraded" (**Q3**); and
  **the headshot BYPASSES the revive window entirely** (`:203-208`) â€” one round at minute 22 costs
  22 minutes, and the only button is `reload_current_scene()` (`:362`). **Ruling 6 (no save) and
  ruling 7 (fail forward) collide at exactly this one code path** (**Q2**).
  **THE RTO QUESTION HE LISTED AS OPEN IS ALREADY ANSWERED BY THE CODE:** the calls stop totally and
  permanently â€” `member_by_mos` skips dead men (`squad_system.gd:168`), `_radio_check` needs a living
  RTO within 10m (`field_director.gd:654-663`), and the player is kicked off the net that frame
  (`:257-268`); with no downed state, "goes down" and "dies" are the same event. The real question
  is whether total deletion is the right punishment (**Q4**).

## D-14. CHOW HALL / FIREBASE EXPORT â€” the blocker is older and bigger than reported

The Arbiter's finding **STANDS**: `tools/gen_firebase_v3.py:912`'s default is **CORRECT â€” DO NOT
REPOINT IT**; `:1104` is **confirmed still stale**. **But that was never the real blocker.**
**MEASURED: `fsb_main_v3.glb` is dated Jul 26. It contains zero `WB_chowhall`, zero `work_eat` â€” and
ZERO `WB_medical`. The recovered medical complex has never once been in the running game.**
**TRAP:** exporting the chow hall as-is **silently steals garrison men** â€” 40 unknown `work_*` types
enter the fixed 23-man round-robin (`site_planner.gd:936`, `:992-1008`) as `off_duty` statues on the
mess benches. **Exclude the chow families from the garrison rotation before exporting.**
**Gated on M-1** â€” if the dot suffix survives import, the whole marker convention is the bug.

## D-15. THE DECISION QUEUE â€” blocked on the Summoner

Ten questions, glossed in plain words, at `synthesis.md Â§7`. **Q1** what the demo ends on now that a
true sunrise costs three exploits Â· **Q2** should the helmet save you once from a headshot Â· **Q3**
full health or degraded after a revive Â· **Q4** can the radio be picked up off the RTO's body Â·
**Q5** how many landing pads Â· **Q6** chow hall manned by rostered men or by fixtures Â· **Q7** how
many men eat at once Â· **Q8** lock the marker names as final Â· **Q9** confirm cutting wounded
squadmates Â· **Q10** confirm three calls means three different weapons.

**EVERYTHING SACRIFICED (Law 2, collected):** the DAWN end card Â· the full-day illusion Â· the midday
return and with it the two-sortie structure Â· ADR-035's finite hunt pool (demo-only exception) Â· the
busy flightline Â· part of Pillar 3's quiet-play promise (the ambient cell can find a blameless
player) Â· ADR-011's "the radio is a man" (if Q4 passes) Â· downed allies and the 70m cover ring Â·
squad legibility (if concealment ships without a nameplate check) Â· an r4bk debt on the thumper Â·
part of stealth's memory (if the corpse array gets a TTL) Â· `AmbientWar` density under a 38x day.


---

## 2026-08-04 — THE RESCOPE, WIRED (Wyrm, coding window)

> **CORRECTED BY THE 2026-08-04 FULL AUDIT (see the AUDIT section below):** this section
> OVERCLAIMS. Five ruled items are NOT in code (hunter top-up, §2.8 arithmetic, informer 100%,
> §2.11 ally items, "hunters" tag), the 06:30 start is defeated by a boot race (demo starts
> 17:30 DUSK), and the ruled ending renders ~2-3s. Pointers in
> `war_room/2026-08-04_full_audit/synthesis.md`.

Executes `war_room/2026-08-03_demo_day_scope/synthesis.md` including his §8 rulings.
Every item below is CODE WRITTEN AND PARSE-CHECKED, **NONE OF IT IS RUN.** The two
landmines in particular are discharged only by M-2 and M-3 on the exported build.

**THE TWO LANDMINES — DEFUSED**
- **Freeze latch.** `siege_director._enforce_live_cap` froze dormant cells and nothing
  anywhere called `set_physics_process(true)`, so a held cell never marched again while
  still reporting full paper strength - `live/peak` could never fall and the assault could
  never break. New `_thaw_held_cells` releases them as the dead make room, one at a time,
  only while a cell's own strength fits, behind `THAW_HEADROOM 6` so it cannot thrash.
- **Viewmodel accumulator.** Verified by reading the GLB: `ak_fp.glb` carries `ArmsMesh`,
  a skinned ~40-bone skeleton and 6 animations, and EVERY weapon `.tres` points
  `model_path` at its first-person viewmodel - so every dropped rifle instanced the whole
  rig, arms 1.81m underground. `world_weapon._bake_gun_only` now keeps the gun meshes as
  flat unskinned `MeshInstance3D`s at rest pose and drops the arms, skeleton and
  AnimationPlayer. Plus `MAX_WORLD_WEAPONS 24` FIFO (the GunFX pattern) and
  `MAX_REPRIEVES 3` - the old grace was granted for STANDING NEARBY, the default state at
  the wire. `EnemyBase.unreported_corpses` bounded at 48, oldest forgotten first, witness
  logic untouched.
- **NOT a bug, checked and cleared:** `_check_corpse_discovery`'s `remove_at(i)` inside
  `for i in range(size())` returns immediately after the removal. No index fault.

**THE ARC** — `demo_game.gd`: 06:30 start (`SimClock.set_time` after the build, because the
generator seeds its own hour and the weather table wins over it), day 38x, night 20x
switching once at the 1380s seam, probe 1395 / assault 1440 / end 1800. Dawn card gone;
`ENDING_PLAYER_SURVIVES` is the single flag for his Q1 delegation.

**THE OPENING** — `_tick_opening`: T+10 `MOVE_TO` on `patrol_gate_pos`, released on arrival
or by a 210s clock, whichever lands first, then everyone back to FOLLOW. The release line
prints `N/M arrived`, which is **M-4's measurement**. No new UI element (ADR-030 intact).

**THE WALK OUT** — `plan_demo_world` used to declare `no_signs` and `no_camps`. Both were
lies about the demo's own content: it now places 2-3 first-signs at 150-300m on the
outbound bearing, and **an enemy camp at ~300m on the opposite flank from the village**
(his rescope: "one village and one enemy camp"). Ambient walking patrols were ALREADY
built and already ship - `build_patrol_world` spawns 2-3 `LazyGroup` circuits between the
gate and the sites. Do not build a second ambient-cell system.

**THE FALSE ALARM** — `_check_detection` fired "YOU'VE BEEN MADE" off
`EnemyBase.last_combat_contact_ms`, a GLOBAL static that rises when any enemy anywhere goes
loud. The hunter spawn already refused to send anyone without an evidence fix, so the toast
was a promise the system would not keep - nearly unreachable in 7 minutes, routine across a
30-minute day with ambient cells walking. The alarm now requires what the hunters require.

**AIR** — `_dispatch` checked the ceiling once before the lead then added up to 8 wingmen
unchecked (22 airframes against a ceiling of 14, on a call-bound project); the check now
binds every ship and a truncated pack prints. `FSB_PAD_PREFIXES` comment said "measured:
three 15x15m PSP pads" - **drift**: three nodes match and all three sit at the same
position, so `_free_pad` would land three aircraft on one square metre. `_firebase_lzs`
now de-duplicates co-located markers past `PAD_DISTINCT_M 12`. A second REAL pad is his
Blender bench, and he has said the dual-pad firebase is built but unexported.

**FIRE SUPPORT / THE RADIO** — demo allotment is `bombs: 3` and zero of everything else
(his ruling, overruling the council's bomb/arty/mortar split). Napalm at the raid and the
daytime bursts are scripted spectacle billed to nobody, and `garrison_illum` never touched
this stock, so zeroing illum costs the player no light. **The radio is now an object**:
`SquadSystem._hand_off_radio` reassigns the RTO *MOS* to the nearest living man on the
radioman's death, so all eight downstream `member_by_mos("RTO")` call sites keep working
untouched and the heir carries it at full quality. Fire support dies with the SQUAD.
This supersedes ADR-011's "the radio is a man" for the squad net.

**CHOW HALL — HALF WIRED, AND THE HALF THAT IS BLOCKED IS NAMED.** Marker families now map
to occupations (`chow_server*` -> `mess_cook` as a post; `eat`/`queue`/`chow_diner` ->
a new `mess_hall` schedule) and are in the work priority. `civilian_schedules.action_for`
takes an optional `who` so a man's **sitting** is derived from his own node name - the same
ADR-010 identity the work offset uses. **THREE SITTINGS, deliberately:** filling all 24
seats at once against a 40-man ceiling leaves 16 men running the firebase in the hour
before stand-to - a full mess and an abandoned wire.
**NOT BUILT: the 19-clip queue/tray/seat chain**, because the chow markers are not in the
shipped GLB yet (his re-export) and because **M-1 gates every chow-hall decision** - if the
dot suffix does not survive import, ~185 of 198 markers are junk and this is built on sand.

**STILL OPEN**
- ~~The gunship ending flies the wrong shape.~~ **BUILT 2026-08-04.** New `gun_orbit`
  profile: a pair enters on its own bearing from `ORBIT_INBOUND_M 330`, crosses to the far
  side and walks a 12-waypoint circle at `ORBIT_RADIUS_M 130` / `ORBIT_ALTITUDE_M 45` for
  `ORBIT_SECONDS 75`, then runs out. Flown as WAYPOINTS rather than a parametric curve so it
  reuses Helicopter's existing speed ramp, altitude lerp and yaw lerp instead of adding a
  second movement model. **The reaper was the trap:** it deletes any flight within 20m of
  its destination, and an orbiting ship is within 20m of its waypoint by design - the
  gunships would have vanished one lap in. `orbit_in`/`orbit` are now in the `settled` list.
  Budget: ~90s of the 240s `MAX_FLIGHT_SECONDS` at the Huey's 50 m/s.
  **NO DOOR GUN, deliberately** - his ruling 2026-08-04 mid-build ("dont build the gun...
  im going to stage that in a heuy eventually. i just want that idea to be there"). The
  huey.tscn carries no gunner rig, so a firing gun today would be rounds leaving an empty
  doorway. The hook when his staged gunner lands is the `orbit` phase.
- **Every measurement M-1..M-5.** Nothing here has been run.

---

## 2026-08-04 — FULL AUDIT (War Room, six architects; decree at `war_room/2026-08-04_full_audit/synthesis.md`)

**AUDIT ONLY — no code written. Every pointer verified against the tree this day.**

### DEMO fixes ordered (value/effort order; sacrifices named in synthesis §4)
- [x] **W-1 Clock race** — **BUILT 2026-08-04.** The fossil is dead: the demo plan now carries
      `"time": "DAWN"` (`mission_generator.gd:674-676`), and `demo_game.gd` awaits the
      `_in_world` latch before `SimClock.set_time(1, 6.5)` (`demo_game.gd:101-109`). 06:30 sits
      inside the plan's DAWN period so the no-period-signal limit of set_time never bites.
      Verified by M-6 below.
- [x] **W-2 Radio heir guard** — **BUILT 2026-08-04** per Q1: the MEDIC is skipped outright,
      nearest RIFLEMAN first, nearest other non-medic specialist as last resort
      (`squad_system.gd:_hand_off_radio`, the MEDIC/RIFLEMAN triage loop). M-7 still to run.
- [x] **W-3 (SHRUNK per Q3) — BUILT 2026-08-04.** Hunter top-up to 6 at the outbound gate seam,
      demo-only (`field_director.gd:_poll_wire_gate`, above `_grant_fire_support()`); informer
      100% in demo, full-game draw order untouched (`mission_generator.gd:_build_village_site`);
      "hunters" node group on the field hunters (`field_director.gd:_process_escalation`) AND the
      demo ambient cells (`lazy_group.gd:_spawn_men`); §2.11 items 1-3: allies now feed
      `squad_broken`/`force_ratio` to the shared scorer with a sides-swapped
      `_local_force_ratio` (`ally_base.gd`), MOS-weighted courage via `SquadSystem.MOS_COURAGE`
      (RTO caps at 0.55 — under the 0.75 hero bar), and a concealment term in
      `AllyBase._find_cover_point` (MEDIUM/HEAVY_JUNGLE cells claimable when no hard block
      answers). **§2.8 day-feeds-night DROPPED per Q3 — not built, per the ruling.**
      Squadmate-nameplate legibility check rides his next playtest (named sacrifice).
- [x] **W-4 Verification instrument** — **BUILT 2026-08-04.** `--print-fps` is now REAL:
      `scripts/dev/fps_printer.gd` (export-safe, no res://tests dependency), attached in
      `game_flow.gd:enter_hub` beside the probe; `--perf-probe` now warns instead of
      null-crashing an export (`game_flow.gd`, packed_probe null guard). M-2/M-3 as written in
      this file now name a flag that exists. The 7/31 "48.0 FPS via --print-fps" A/B is flagged
      as broken-provenance at `site_planner.gd:859-861`.
- [x] **W-5 Guarantee the ending** — **BUILT 2026-08-04** per Q2: freeze waits for
      `AirTraffic.orbit_on_station()` (not wall-clock; 25s spawn-failure guard only), finale
      pair spawns at `ORBIT_FINALE_INBOUND_M 200` and is EXEMPT from the airframe ceiling
      (`air_traffic.gd:_dispatch_gun_orbit(finale)`), and the frozen frame + card hold until he
      exits the program — no timer, no key-continue (`demo_game.gd:_ending`).
      `ENDING_PLAYER_SURVIVES` remains the one flag. M-8 still to run.
- [x] **W-6** — **BUILT 2026-08-04.** The 1-in-20 random night roll is demo-gated
      (`siege_director.gd:_maybe_open`, `GameFlow.demo_mode` early return; full game keeps it),
      and the speed seam now tracks `MissionWeather.is_night` — it lands when night actually
      falls (~1184s on the 06:30 arc), not at a wall-clock constant (`demo_game.gd`,
      `DAY_END_S` deleted).
- [ ] **W-7 Eyes-on drop check** — baked drops may render 1.81m underground
      (`world_weapon.gd:143,186-192`). 60 seconds before his playtest.
- [ ] **W-10 (NEW, his playtest 2026-08-04) — RECOIL BENCH SESSION, WITH HIM.** His ruling: M16
      recoil "feels real and right" = THE REFERENCE FEEL; PPSh is "all over the place." Feel
      discharges only by his hands (ADR-015). Measured table (all `data/weapons/*.tres`,
      2026-08-04) — the convict is the PRODUCT of rate and random horizontal: **PPSh 900rpm x
      `recoil_horizontal 0.9` = ~13.5 deg/s of jitter vs the M16 reference's ~6.25** (M16: 750rpm,
      v 1.1, h 0.5 default, recovery 14; PPSh: v 1.4, h 0.9, recovery 11; AK shares h 0.9 but at
      ~600rpm). Nothing is order-of-magnitude broken, so nothing was retuned unilaterally.
      Bench starting numbers: PPSh `recoil_horizontal` 0.9 -> ~0.55, `recoil_recovery` 11 -> 13-14.
- [ ] **W-9 (NEW, his playtest 2026-08-04) — "Nobody disembarked from the landed Huey."
      CONVICTED, two counts, by reading the code:**
      (1) **DELIVER is unreachable in a healthy base.** `HeliLift._choose_mission` delivers only
      when garrison < `ESTABLISHMENT 28` (`heli_lift.gd:96-97`) — but the garrison is seeded at
      `FSB_GARRISON_MAX_MEN 40` (`site_planner.gd:864`), so EVERY lz_cycle is an EXTRACT until
      12+ garrison men die. The men he saw inside were the pilots + already-seated extract pax;
      on an EXTRACT nobody is supposed to get out. The disembark show he was promised can
      currently only fire mid/post-siege.
      (2) **Nobody visibly walks up to load.** `SeatSystem.board_squad` issues MOVE_TO only to
      `AllyBase` (`seat_system.gd:332-334`); garrison `Civilian`s have no public move verb
      (`civilian.gd` — `_step_toward` is BT-internal), so an extracted man is GLUE-TELEPORTED
      into his seat at the 0.6s stagger (`_board_one` → `seat()`). Reads as men popping into
      the cabin. Fix needs a walk-to-door verb on Civilian or routing extract through the BT —
      not a triage-scope change; priced here for the queue.
      **2026-08-04 UPDATE (animation half only, count 2 still open):** authored `board_heli`
      from footage-derived beats (approach/grab/mount/settle-to-floor), gated on the elbow
      invariant (max 0.019, clean), and wired `HeliLift.BOARD_CLIPS = ["board_heli"]`
      (`heli_lift.gd:46`, was empty). `civ.actor.play_first(BOARD_CLIPS)` now plays a real
      climb-and-sit performance instead of nothing — but the `Civilian`-is-not-`AllyBase` cast
      failure above is UNCHANGED, so the man still doesn't walk to the door first; he plays the
      mount animation wherever he happens to be standing, then glue-teleports into the seat as
      before. **Count 2 needs the move-verb fix on top of this before it reads right; the
      animation is ready and waiting for it.** Detail + QC numbers: `production/ART_Track_Log.md`
      2026-08-04 entry.
      **2026-08-04 EVENING UPDATE — count 2 BUILT, awaits his eyes.** War Room
      `war_room/2026-08-04_garrison_soldiers/` decreed a boarding LATCH, not a promotion:
      `Civilian.board_target` (`civilian.gd`, walked in the WANDER branch at
      `BOARD_WALK_SPEED` 1.8), set by `SeatSystem.board_squad` (`seat_system.gd` — the
      `as AllyBase` cast now has a Civilian branch), and `_board_one` is ARRIVAL-GATED:
      retries every 0.4s until the man is within 3.0m of the door (cap ~24s, then the
      ship abandons him and the latch clears), plays `board_heli` AT the door, seats
      after a 1.6s mount beat (`BOARD_MOUNT_S` is a timed const, not a measured clip
      length — named sacrifice, synthesis §4). Headless boot clean, 0 SCRIPT ERROR.
      **MEASURED WORKING 2026-08-04 late (instrumented demo run, seed 29072026):**
      `[SEATS] boarder at the door after ~3.2s walk - mounting` → `seated in seat_pax_1`,
      and a second man `~12.8s walk` → `seat_pax_2` — DURING a live stand-to, which
      exempted exactly the 2 latched boarders (43 of 45 promoted). Two earlier failures
      taught two fixes: the arrival gate now measures to the AIRFRAME (8.0m, XZ), never
      the door staging point — the staging point sits off the LEFT door, the heli is in
      no navmesh, and approach from the right pressed men against the fuselage 6-11m
      from target for the full 24s. CLOSE on his playtest (ADR-015).
- [ ] **W-12 (NEW, his live playtest 2026-08-04 late — FOUR convictions, evening fix train
      applied same night, ALL await his eyes):**
      (1) **All replacements were RADIOMEN — FIXED.** `Civilian.spawn` derives model, face
      AND dress from a POSITION hash (`civilian.gd:186-189`), and `heli_lift._load_pax`
      minted the whole stick at one point (`heli.global_position`) — one man, n times.
      Sticks now mint at per-man offsets (`heli_lift.gd _load_pax`).
      (2) **Delivered men stood on the pad forever — FIXED.** Pax landed with occupation
      "farmer" (Civilian default), no working point, and `home` = the pad, so the schedule
      held them where they stood. `_deliver` now hands each man to camp life: off_duty/
      detail occupation + a bunk point inside the compound, deterministic per man
      (ADR-010), `_placed_for_hour` latched so he WALKS off the pad, never teleports.
      (3) **A FEMALE (Asian villager) face on a US grunt — FIXED, HIS RULING** (verbatim:
      "thats immposible to do make sure we fix that"). The shared 10x7 face atlas
      (`assets/shared/textures/face_atlas_v3.png`, VERIFIED BY EYES) carries female cells
      (13,14,16,22,23,32,33,41,52), a turban (49) and a legacy bottom row 60-69 including
      Asian villager faces — and `GruntDresser.dress` drew `randi() % 70` across all of it.
      US soldier draws now come from `GruntDresser.US_FACES` (49 male cells); explicit
      `opts["face"]` still bypasses for the bench. Villagers don't use the dresser
      (`grunt_randomizer.gd:96-97` — us_* only), so they are untouched.
      (4) **PHANTOM PATROL banked with 7 kills while he never left the wire — FIXED,
      BOTH HALVES (credit half built 2026-08-04 late, awaits his verify).**
      GATE: `_poll_wire_gate` (`field_director.gd:1221`) requires >120m from the gate
      AND from `fsb_center`. CREDIT: attribution already existed end-to-end — every
      damage path carries the attacker (`bullet_system.gd:178`,
      `combat_manager.gd apply_explosion_damage`), and `EnemyBase._last_attacker` is
      group-gated to player/allies at `enemy_base.gd take_damage` — so the scoping was
      a small change, taken under his "i didnt do anything" ruling. BEFORE:
      `_on_enemy_died` banked EVERY death in the AO. AFTER: a kill banks only when
      `patrol_out` is true AND the killer is the player or a `squad_member` AllyBase
      (promoted garrison spawns with `squad_member=false`, `garrison_defender.gd:57`;
      friendly patrols likewise). New `EnemyBase.last_friendly_attacker()` is the
      credit source. Headless boot clean.
      **VERIFY (his eyes):** patrol out, shoot 2, squad kills 1 → "PATROL N LOGGED,
      3 KILLS"; sit out a base defense → next AAR banks 0.
      **TWO GLOSSED EDGES, his call if either bothers him:** (a) base-defense and siege
      kills now bank NOWHERE (they were only ever mis-banked into the patrol AAR; F-1
      "bank the night" is the logged home for siege accounting); (b) air kills never
      credit the patrol — including a danger-close run HE called in (the killer is the
      airframe). Both are conservative reads of "kills he made".
      **STILL OPEN, not reproduced:** (5) rooftop NPC spawns near LZ→hooch persist on his
      build — the COMPLETE placement pipeline is now mapped with suspects ranked at
      `war_room/2026-08-04_garrison_soldiers/placement_pipeline_map.md` (top candidates:
      tracked-enemy spawns and the terrain_watchdog LOD reseat still ride `surface_y`;
      heli-delivered pax get pad-height homes) — re-judge on the NEW GLB, no fixes
      against the old geometry by decree; (6) squad "stuck by collision boxes" —
      a 4-direction pen probe now prints at boot (`squad_system.gd setup`,
      `[SQUAD] spawn <MOS> at (...) - N/4 dirs blocked`); on seed 29072026 all 8 men
      probed 0-1/4 blocked at spawn, so the pen is NOT at spawn — next suspect is the
      hootch doorway during follow (fresh-navmesh law, agent radius vs door width). His
      next run's `[SQUAD]` lines are the evidence to bring; (7) wrong animations for the
      action — partially explained by (2) farmer-occupation pax + the permanent stand-to
      (fixed via the W-10 alarm gate); re-judge after this build.
- [ ] **W-11b VERIFY (his report 2026-08-04 late): "i see napalm called out but have yet to see
      a huge explosion."** Plausibly W-11 itself — the dead-author callback sat in the detonation
      path, so napalm may NEVER have fully detonated for him. HIS RULING same night: "just double
      it anyways and if its too big ill dial it back" → `FirePlan.NAPALM_BLAST_M` 10.0 → 20.0
      (one constant; drives fireball, fire carpet AND damage circle — the strip is now ~40m wide
      of overlapping 20m fires). Verify row: on the fixed build, call a napalm run and judge by
      eyes; dial the constant to taste.
- [x] **W-11 napalm impact callback — BUILT 2026-08-04 late (structural fix, not a guessed
      guard).** The trace (`Nonexistent function '_ignite_nearby_structures' in base
      'Node3D (TerrainChunk)'`) shows the terminal lambda's self-dispatch resolving against
      a RECYCLED object after the plane's reap — the shell outlives the aircraft, and the
      projectile-side guard (`projectile_base.gd:374` checks `get_object()`) passes because
      the binding still reports a live object. Why :301-303 "worked": they are autoload/
      static calls, and `get_tree()` exists on the wrong base too; only :304 named a method
      the impostor lacks. The exact rebinding mechanism stays engine-side and unproven —
      so the fix removes the dependency instead of guarding it: **every deferred terminal
      lambda in `cas_airplane.gd` is now self-free** (captured `tree: SceneTree` for
      FireHazard/GunFX scene lookups; `_ignite_nearby_structures` is `static func
      (tree, impact)`), bomb + napalm + CBU bomblet paths all converted, and the CBU
      open-timer gained the same `is_instance_valid(self)` guard the napalm stagger has.
      No behavior change; structures now ignite even from a reaped plane's rack. Headless
      boot clean. **Verify: his next napalm run, grep the log for SCRIPT ERROR.**
- [ ] **W-10 (NEW, his ruling 2026-08-04, verbatim: "Garrison men are soldiers they shoudnt
      be civilians. They can fight and react to enemies so thats not correct." + "and we need
      to make sure VC units arent lableed as civilans too in their camps.") — GARRISON
      SOLDIERS. War Room `war_room/2026-08-04_garrison_soldiers/` (3 architects, synthesis
      has the full decree). DEMO SLICE BUILT 2026-08-04 evening, awaits his playtest:**
      (1) **Soldiers answer fire** — the garrison deaf gate (`civilian.gd` `_on_noise`
      `if is_garrison: return`) replaced: enemy-team GUNSHOT/EXPLOSION audible at the man
      (distance ≤ emitted radius), or a hit from an enemy, raises
      `FieldDirector.garrison_alarm(at)` → the EXISTING `_garrison_stand_to()` promote path
      (garrison_defender.gd — one path, ADR-023). Before this, stand-to had exactly 3 doors
      (siege, ≥2-in-90m poll, heli into a fight) and a lone sapper was ignored forever.
      **AMENDED same night after his live run:** the alarm is gated to sources within
      `GARRISON_ALARM_M` 120m of `fsb_center` — ungated, the demo's near-constant ambient
      contact kept the garrison PERMANENTLY promoted and camp life read as dead ("no one
      moves around or does anything"). A fight 300m out is the AO's business.
      **CRASH FIXED same night:** `GarrisonDefender.stand_down` built its model list with a
      ternary (`[unit] if ... else GARRISON_MEN`) which types as plain Array → runtime
      assign error → EVERY stand-down deleted the man instead of restoring him (measured:
      48-man garrison fell to 4 in one night of my instrumented run; log flood
      `Trying to assign an array of type "Array" to "Array[String]"` at
      garrison_defender.gd stand_down). The all-clear multiplied its firing rate, which is
      *[entry truncated here by an earlier write — the sentence ends mid-clause; the fix
      itself is described complete above. Noted on contact 2026-08-04, NO MORE DRIFT.]*

- [ ] **W-13 (Summoner ruling 2026-08-04, verbatim: "follow me to safety instead of us being
      outside in the line of cover... get him to be behind me when im in cover and theres an
      intense firefight.") — RTO CORD DOCTRINE. BUILT 2026-08-04, awaits his playtest.**
      No new command verbs (Pillar 4); the RTO's OWN cover search gained two doctrine
      weights, RTO-only + player-alive gated, in the §2.11 scoring seam — one path, both
      the hard-cover and concealment passes route through `AllyBase._claim_scored`
      (`ally_base.gd`, above `_find_cover_point`); the shared claim broker and ENEMY
      scoring are untouched (the bias is caller-side in the ally copy only).
      (1) **CORD LEASH** — `RTO_CORD_LEASH 8.0` (10m net cord minus margin): candidates
      beyond 8m of the player are dropped; if none survive, nearest-to-player wins
      outright. (2) **SHADOW WEIGHT** — `RTO_SHADOW_WEIGHT 3.0` bonus by the flat-plane
      dot of candidate→player vs candidate→threat ("get behind the man with the map");
      a bonus, never a filter. `net_planted` precedent verified, not changed: the plant
      binds only IDLE/FOLLOW (`ally_base.gd:968`), combat states already override it
      under direct fire, and SEEKING_COVER opens only via suppression or the shared
      scorer with a live target — so a planted RTO is yanked only in a fight, and the
      leash makes the yank a shuffle near the player. Logic lives in AllyBase, so demo
      and bench behave identically.
      **MEASURED (`tools/probe_rto_cover.tscn`, 5/5 PASS, headless 0 SCRIPT ERROR):**
      wall behind the player → RTO cover 1.09m from player, shadow dot 1.000 (RIFLEMAN
      control same spot: 5.00m, dot 0.850 — unbiased path intact); RTO strayed to 14.56m
      with only far cover → fallback picks the candidate 8.94m from the player while the
      RIFLEMAN control takes his own 3m rock 17.46m out.
      **VERIFY (his eyes):** take cover in a firefight with the net open or SPARKS
      following — he should tuck in behind you instead of holding a rock across the
      danger space.

- [ ] **W-14 (Summoner ruling 2026-08-04: "sandbags and a few more trees and a squad of 5
      enemies shooting at us... prove the loop that the allies will fall in their supposed
      places while taking cover.") — SUPPORT-FIRE BENCH IS NOW A LIVE-FIRE COVER LAB.
      BUILT 2026-08-04, awaits his playtest.** All in `scripts/levels/support_fire_range.gd`
      (scene-build only; fire_preview/cas_airplane/field_director/FirePlan untouched):
      6-bag low sandbag arc at the spawn (one bag BEHIND the player for the W-13 shadow spot),
      tree field densified 24→57 trunks with near clumps, 4 riflemen (TEX/PREACHER/JUNIOR/
      MOOSE, courage pinned 0.20–0.32 — the rally bonus put nerve on the CombatGoals
      cover-vs-engage knife edge and the break became a per-run coin flip) on the BenchSquad
      roster in FOLLOW, in-code navmesh baked arena-style (`lab_navmesh` group, 567 polys).
      **[9] launches a 5-man VC/NVA assault** from the far tree line (3 press via
      `assault_driven`, 2 NVA base of fire) with the arena hot-start contact seam + a
      half-bar opening-volley suppression seed (below the 0.6 seek band and the pin gate).
      **Witness:** every claimed cover point draws a sphere + nick label (yellow moving,
      green held, cyan RTO), claim/hold/release printed to console — bench-only, gated in
      this scene script.
      **MEASURED (`support_fire_range.tscn ++ --cover-probe`, headless, 0 SCRIPT ERROR):**
      5/5 men CLAIM within ~2s of [9] and 5/5 reach HOLD within 1.4m of the claim; claims
      land 1.8–5.9m from the nearest sandbag on the friendly side; SPARKS claims the rear
      bag 5.0m from the player at **shadow_dot 1.00** (player exactly between his cover and
      the threat — W-13 satisfied); the enemy squad presses and lives 15s+ (5→2→1 across
      the samples).
      **VERIFY (his eyes):** boot the bench, set up, press [9], watch the markers pop and
      the men fall into them.

- [ ] **W-15 (Summoner rulings 2026-08-04, same lab session) — RTO CORD + ALLY COMMITMENT
      + FEAR DOCTRINE + LETHALITY. BUILT, awaits his playtest.**
      (1) **RTO cord over everything** (`ally_base.gd`): no FLANK/ADVANCE goals under the
      cord, beyond 8m his only legal move is toward the player (COMBAT + lost-sight
      branches), commits to his hole until the player moves off the cord.
      (2) **Ally commitment** (`ally_base.gd` + `combat_goals.gd` Context.incumbent_mult):
      cover dwell 8s (`ALLY_COVER_DWELL_MS`), goal-switch cooldown 3s (survival verbs
      exempt), incumbent 1.6 ally / 1.5 enemy / 1.25 pressed (C3 press calibration
      preserved); a covered man whose target drops holds the rock and retargets instead
      of standing down (`_execute_combat` + `_hostiles_remain`).
      **MEASURED (bench SQUIRRELLY-METER):** goal switches 17.5-34.9/min -> 2-8/min;
      cover dwells 1.4-2.1s -> 4-8.6s; RTO max dist from player 11.5m -> 5.2-10.2m.
      (3) **FEAR doctrine, BOTH sides** (`combat_goals.gd`): under un-answered fire and
      unpressed, ADVANCE x0.15 / FLANK x0.4; SUPPRESS +0.15 vs an unsuppressed target;
      RETREAT floor 0.5 when outnumbered <0.6; Context.target_suppressed fed by both
      callers. Press men exempt everywhere (siege decree C3 intact).
      **MEASURED:** advances-under-unanswered-fire 0.0 man-s across two 30s assaults.
      (4) **Lethality** (`ai_marksmanship.gd` cap 1.2->1.0 deg, EXPOSURE_PEAK 2.0->1.4;
      `enemy_base.gd` accuracy floors up ~0.1/archetype, self-pres floors up 0.1;
      `data/enemies/*.tres` exposure_ramp_time trimmed ~30%; damage table UNTOUCHED,
      Fairness Law mercy round + ramp intact, torso aim unchanged).
      **MEASURED (bench LETHALITY probe, 3 VC bolt rifles at 40/50/60m vs exposed still
      player):** hits/100 46 -> 75; time-to-first-hit from cold acquisition 5.3s;
      suppressed (0.9) shooters fire ZERO rounds - cover protects.
      (5) **Assault scaled** ([9] = 10 men: 2x2 MG/NVA bases of fire + 2x3 bounding
      maneuver, waves STACK): two runs - enemies lose 4-6/10, REACH the line (6-8m),
      **ally squad 5/5 dead in ~30s both runs (headless: no player rifle, no fire
      support)**. Bench-only perf note: headless cannot measure the Intel-UHD floor
      with ~16 AI - measure on his box.
      **NEEDS HIS EYES:** whether 5/5 friendly dead per assault reads as danger or as
      fragile friendlies - ally accuracy floors were NOT raised (enemy-only personality
      code), so the lethality raise is asymmetric; a council should rule if allies get
      the same floors.

- [ ] **W-16 (Summoner convictions 2026-08-04) — FIRE-MISSION DAMAGE AUDIT + CONTACT
      FUZES + THREAT-CORRIDOR JUNGLE PROMOTION. BUILT + MEASURED, awaits his eyes.**
      (1) **Damage audit (`support_fire_range.tscn ++ --strike-probe`):** every kind vs
      a 6-man standing cluster - arty/mortar/bombs/napalm/cbu/spectre all 6/6 killed
      (420 dmg = full wipe), WP 3-5/6 (small blast, correct), **arty on a TREELINE
      cluster 6/6 killed** (his acceptance test), enemy siege mortars kill player
      (100->0) + 3/3 allies. The 0.4x indirect mitigation discounts FRIENDLIES only -
      but 8 rounds still killed all 4 bystanders (danger close is danger). **On the
      bench nothing is broken** - if his live run showed nothing, it predates today's
      fixes or is live-world-terrain specific; the LOS-from-ground-level suspect is
      now moot because bursts sit at contact height.
      (2) **Contact fuzes (decree, verbatim "if a bomb hits the tree above you thats
      gonna blow up... blast downward"):** munitions already segment-cast layer 1 every
      tick (`projectile_base.gd:264-291`, `hits_world=true` in every shell .tres); the
      defeat was the four tube terminals flattening the burst to `get_height_at`. Fixed
      in `_arty_impact`/`_mortar_impact`/`_wp_impact` (field_director) + siege
      `_mortar_impact`: burst stays at contact height (`maxf(pos.y, floor)`), craters
      only dig when the burst is <=2m off the floor, WP's burn patch drops to the floor
      beneath its burst. CAS lambdas already honored contact. Dud/arming untouched
      (all support ordnance arming_distance 0).
      **MEASURED (`++ --airburst-probe`):** crown contact at 4.9m kills the man beside
      the trunk; ground burst is SHIELDED by a 1.4m sandbag (untouched); the same crown
      burst over the same wall kills him - directional pressure both ways.
      (3) **Threat corridors (`tree_cover_layer.gd`):** ordnance promotes REAL trunk
      colliders from the EXISTING 70m-ring pool (no second mechanism) via
      `threat_zone`/`threat_corridor` + expiring zones (ZONE_MAX 16, expiry-first
      eviction, dedupe-refresh). Fed by: `_mark_dispatch` (footprint + air-run
      corridor), `CombatManager.spawn_projectile` (every flying explosive, both
      factions), `Grenade` first tick, `SapperCharge.setup`, siege
      `fire_mortar_volley`. No mine class exists (verified zero `class_name` hits).
      **MEASURED (`++ --corridor-probe`):** 0 baseline -> 40/40 promoted on dispatch ->
      contact burst ON a promoted trunk at 2.8m -> 0 after expiry; 10 stacked strikes
      hold 40 promoted with zones capped at 16 and pool stable at 40; full demotion to
      0/0 after all expiries - leak-proof.
      **HONEST LIMIT + his-eyes flags:** canopy contact needs a trunk collider - the
      promotion covers wherever ordnance goes, but collider height is TRUNK_HEIGHT 3m
      (trunk hits, not high-canopy hits); grass/fern/bush stay concealment by contract.
      Napalm canisters contact-fuze like the rest (jungle canopy bursts) - flagged, his
      call if the strip should force ground function. Live-jungle felling itself is the
      pre-existing `vegetation_manager.clear_area` path (`:400-437`).
      how it surfaced. Promote also now skips boarding/seated/puppet men (measured: 43 of
      45 promoted with exactly the 2 lift boarders exempt).
      (2) **All-clear** — `_poll_firebase_threat` stands an alarm stand-to down after ~90s
      of empty wire (`ALARM_CLEAR_POLLS` 180 × 0.5s, `near == 0`, never while
      `siege.active`); toast "STAND DOWN - THE WIRE'S QUIET".
      (3) **A dead garrison man is a soldier on the ledger** — `_record_noncombatant_death`
      excludes `is_garrison`; he stays in the `civilians` group so `spare_garrison` blast
      semantics (`combat_manager.gd:114-166`) are untouched.
      (4) **W-9 count 2** — see the W-9 update above (board latch, same decree).
      **VC AUDIT: CLEAN, 3 independent passes** — VC camp life is already on EnemyBase
      (`camp_director.gd:29`, `enemy_base.gd:584`); no armed VC runs as Civilian; the
      informer swaps model only after GONE+invisible. NO VC change shipped, on purpose.
      **POST-DEMO (decreed in principle, GATED):** migrate garrison onto the soldier class
      per the VC pattern and DELETE GarrisonDefender + the double-group bookkeeping in the
      same change (fossil law). Preconditions before it may start: static hitzone bands +
      3-tier LOD + the schedule brain ported (Civilian's bands exist because bone-synced
      hulls measured ~6.4ms/frame at 16-40 heads, `civilian.gd:214-218`; AllyBase pins
      zones HOT with no LOD). Blast-radius map:
      `war_room/2026-08-04_garrison_soldiers/analysis/systems_designer.md`. Until then the
      demo ships soldiers in a class still NAMED Civilian — named sacrifice, synthesis §4.
- [x] **W-8 De-burst air transits** — **BUILT 2026-08-04.** SimClock schedules now fire at their
      FRACTIONAL hour via `_fire_window` (`sim_clock.gd:advance`/`set_time`;
      `_tick_schedules` deleted, fossil law); the three per-hour transit bookings at
      h+0/20/40min spread across the hour instead of one frame. `test_schedule_reset.gd`
      updated to the new firing model.

### 2026-08-04 EVENING — HIS LIVE PLAYTEST CONVICTIONS (triage same day)
- [x] **Squad never follows + NPCs on rooftops — ONE BUG, FIXED.** Every derived seat used
      `surface_y` (top-down ray, first hit = the ROOF over any covered point): the squad ring
      around the indoor bunk (`squad_system.gd:73`) and every garrison post/working
      point/quarters (`mission_generator.gd:_build_firebase_garrison`) — men stood on roofs,
      off the navmesh, where no order could move them (run-3 stderr: "[NAV] garrison on baked
      region 0, 257.5m to target, no path"). Fix: `fsb_garrison_plan` no longer ZEROES the
      authored marker heights (`site_planner.gd`, five `.y = 0.0` deleted) and the new
      `GameWorld.floor_y` (`game_world.gd`) probes a 3m reach DOWN from the authored height —
      the `_firebase_bunk` pattern, generalized. Squad + garrison + litter + MG + quarters all
      reseated through it. **Needs his eyes at next boot.**
- [x] **"Z put me inside the ground" — FIXED, and it was PRONE, not crouch.** Input map truth:
      crouch is ALREADY Ctrl (`project.godot:93-95`, physical 4194326), Z = `prone`
      (`:214-218`), X = `squad_move` (`:231-233`) — his keybind ruling is already satisfied; Z/X
      are shipping verbs, kept. The sink: `PRONE_HEIGHT 0.5 < 2*radius`, and Godot's height
      setter silently shrinks the capsule radius 0.4 -> 0.25 (MEASURED on 4.7, probe script)
      with nothing restoring it — one prone left a pencil capsule that slips mound-trimesh
      seams. Fix: radius re-asserted every posture frame (`player.gd:_handle_crouch`,
      `CAPSULE_RADIUS` const pinned to `player.tscn:10`).
- [x] **Huey lands, someone aboard, nothing happens — FIXED for the demo.** Two counts
      convicted (W-9 below has the full read): DELIVER unreachable at garrison 40 >=
      ESTABLISHMENT 28, and extract men glue-teleport aboard. Demo fix: EXTRACT sorties become
      **ROTATIONS** (`heli_lift.gd`: `Mission.ROTATE`, demo-only) — replacements fly in loaded,
      walk off with the disembark clips, the same headcount lifts out (`_rotated_off` guard,
      net garrison ~0). Full game keeps pure need-driven logistics. The invisible walk-up
      (W-9 count 2) remains open.
- [x] **Two Chinooks landed overlapping — FIXED.** The pad was claimed at TOUCHDOWN
      (`helicopter.gd:_process_landing`), so two cycles dispatched inside one fly-in window
      both saw a free pad — and the demo's authored 95s chinook lands exactly when the
      schedule's 7.5h lz_cycle arrives at 38x. Fix: reservation moved to assignment
      (`Helicopter.fly_to`), released on take_off AND on `_exit_tree` so a reaped flight
      cannot hold the pad forever. Second dispatch now falls back to an overflight.
- [ ] **His FREEZE — NOT REPRODUCED, one instrument artifact ruled out.** Under the godot MCP
      the game froze twice at exactly 51,577 buffered bytes: the MCP stops draining stdout,
      the pipe fills, `print()` blocks the main thread (window Not Responding at ~3% CPU) —
      an INSTRUMENT artifact, not the game (memory: godot-mcp-pipe-freeze). A file-redirected
      run then held 43-47 FPS for 6.5 minutes to a clean window-close exit, zero script
      errors. One real error found and fixed on the way: a reaped CAS plane's shells called a
      dead lambda (`projectile_base.gd:_apply_aoe_damage` — `is_valid()` does not check a
      lambda's captured instance; dead author's round now falls through to the shared
      explosion). His freeze on the DUSK-boot build stays OPEN — if it recurs on the DAWN
      build, capture how he launched (editor vs export) first.

### Housekeeping flag (2026-08-04, Overseer)
- A pre-existing `git stash` entry named **"autostash"** sits in this repo (27 files,
  122+/745-, touches `tools/viewmodel_manifest.json`) — it predates the 8/4 fix-train
  session and was NOT created or consumed by it. Inspect with
  `git stash show -p "stash@{0}"` before dropping; it may hold a lost session's work.
- The worktree also carries ~15 modified + ~195 untracked files from OTHER sessions
  (Blender WIP, viewmodels, seat_system/model_actor/hitzone_builder edits) — left
  uncommitted on purpose; they are not the fix train's to ship.

### FULL-GAME items logged (not demo work)
- [ ] **F-1 Bank the night** — siege AAR handler banks nothing under a comment claiming it does
      (`field_director.gd:1466-1478`). Machinery ~120 lines away.
- [ ] **F-2 ADR-007 amendments + false `to_dict` mirror** (drops 4 fields, cross-campaign bleed).
- [x] **F-3 Ratify ADR-029** — **DONE 2026-08-04** per Q5: header now ACCEPTED
      (`production/adr/ADR-029-open-patrol-simulator.md:3`); the four "ADR-029 draft" code
      banners corrected on contact (`game_flow.gd`, `mission_generator.gd`, `field_director.gd`).
- [ ] **F-4 Sleep verb** with siege-wake interrupt (night economy has no consumer).
- [ ] **F-5 M-AI-1** — forced 50+20 thaw test; `_thaw_held_cells` can NEVER run in the demo
      (45 < LIVE_CAP 50) and double-spends headroom (`siege_director.gd:448-479`).
- [ ] **F-6 Place the 21 interior props** — pure code, on disk since 7/31, unclaimed twice.
- [ ] **F-7 MARKSMAN into `MOS_ORDER`** (`squad_roster.gd:64`) or delete the alternate-draw promise.
- [ ] **F-8 Hearts & minds thin slice** — `civilian.gd:4-7` hook counts one thing.
- [ ] Correct ART_Track_Log on next touch (chow clips ARE merged; seven chow types mapped).

### Decision queue — RULED 2026-08-04 (his words verbatim)
- **Q1:** "medics cant pick up radio, and riflemen should be first to pick it up" → W-2 spec.
- **Q2:** "final hold stays until they click out of the program to end the demo" → W-5 spec.
- **Q3:** "I dont think the kills in the day should effect the assault later on" → §2.8 DROPPED,
  fixed 45-man assault stands.
- **Q4:** "whatever works" → council rec stands: THREE SITTINGS, base never empties.
  **STATUS 2026-08-04: the sitting schedule is ALREADY CODED** — `civilian_schedules.gd:196-207`
  derives a man's sitting from his own name (`_sitting_for`, `:296`; breakfast 06:00+24min
  steps, supper 19:30+24min steps). **GATED on his bench:** the chow markers are not in the
  shipped `fsb_main_v3.glb` (Jul 26), so no code change can light it before the M-1 histogram
  + re-export. Nothing further to wire on the code side.
- **Q5:** "do whatever" → ratify ADR-029 as-is (F-3).
- **Q6:** "doesnt matter" → audit's value order stands: F-1 → F-4 → F-8 (after demo fixes).

## 2026-08-04 — SEGMENTED TREES (his ruling, live at the destruction chamber)

**Summoner, verbatim:** *"i know how to solve our problem with the higher up tree destruction,
we need to make our tree models split apart in more areas."*

Today a tree is ONE piece: `FellableTree` hinges the whole standing GLB at its BASE regardless
of where the blast hit (`scripts/world/fellable_tree.gd:72-106` — `_begin_fall` picks only a
direction, never a height) and swaps to a single `felled_trunk.glb` log. A canopy hit felling
the entire trunk from the roots is the defect he named.

**The solve, two halves:**
1. **ART — segment the tree models.** `felled_tree.glb` (and the live-world tree models when
   the TreeCoverLayer path ships) get authored as stacked separable segments — lower trunk /
   upper trunk / canopy at minimum — sharing one contract for joint heights. Blender job.
2. **CODE — break at the joint nearest the blast.** `FellableTree` picks the break joint from
   the blast's height, hinges only the segments ABOVE it (they become the falling piece and the
   downed cover), and leaves the segments BELOW standing as a snag with a shortened collider.
   State-swap stays the law — never fracture, never RigidBody (ADR-031).

Not built; awaiting his chamber verdict on today's destruction pass before the art job is
dispatched.

## 2026-08-04 — CHAMBER SESSION RULINGS (live, support_fire_range)

His words, in order: *"still didnt quite seem like enemies were dying to the artillery"* /
*"maybe we need to increase the damage higher"* / *"tone down the enemy accuracy by 15
percent i was killed pretty quickly"* / *"given we have hard blocks we survived alot longer
but in the jungle it wouldnt be anything"* / *"but also we do need to test what jungle
combat feels like"*.

- **Arty shell 200/60 → 260/90** (`field_director.gd` `_arty_impact`). At 260 max / 90 min
  the full 14 m blast radius kills an enemy (HP 65–85) in the OPEN; behind hard cover the
  0.6 through-cover mult still leaves survivors at range — which matches his hard-blocks
  read. Side effect, accepted: `_blast_defeat_chance` keys off max_damage, so a 105 mm shell
  now defeats sandbag-grade cover ~68% instead of ~53% (`combat_manager.gd:246-247`).
- **Enemy accuracy at the PLAYER −15%**: new `PLAYER_TONE_MULT 1.15` widens both the spread
  and the breathing cone cap on the is_player_target branch only
  (`ai_marksmanship.gd`). Allies and the AI-vs-AI mirror untouched; tests reference the
  consts symbolically, still green. This partially rebalances the 2026-08-04 lethality
  ruling (cap 1.2→1.0) — his call, made live after dying too fast in the chamber.
- **Launcher bats de-drifted**: all 12 root `.bat` files pointed at the DELETED
  `Downloads\Godot_v4.7...` exe (sapper_room at a bare `godot`); repointed to
  `C:\Users\caleb\_tools\godot47\`.
- **NEXT: jungle combat feel** — `night_jungle_bench.bat` (ai_stress_arena, dense night
  jungle, US vs VC) launched for him with the new tuning; his verdict pending. The segmented
  trees ruling (§ above) rides on the same verdict.

## 2026-08-04 — JUNGLE-BENCH VERDICT + THE EVENING WORK WAVE (all BUILT, his eye pending)

**His verdict on the night-jungle run: "that was pretty fun and intense... the combat in that
run felt good and frantic and i was having real fun doing it."** Rule #1 witnessed in the
combat lab. Orders that came with it, all built same evening:

- **FLOATING CORPSES (arena + range, even gibbed) — root-caused and fixed.** Two stacked
  mechanisms in `model_actor.gd`: (1) `physical_bones_stop_simulation()` at the 4s settle
  reverted the skeleton to its pre-ragdoll pose (the simulator is a SkeletonModifier), so
  EVERY ragdolled corpse snapped back to its death-moment pose — and the `_die()` flat-corpse
  guard deliberately skips ragdolled bodies; (2) `ground_current_pose()` measured against the
  actor's own origin, which death freezes mid-air under explosion knockback. Fix:
  `sleep_ragdoll()` now BAKES the simulated pose into the bone poses before stopping (settle
  path routes through it), and grounding ray-probes the real floor (layer 1, own-origin
  fallback on a miss).
- **RTO RADIO, his three rulings:** [F] on the RTO passes the handset INSTANTLY (RadioMenu
  DELETED per fossil law, tests rewritten: `test_radio_handset.gd` A/D, `test_squad_identity`
  §8); on the net the RTO leashes 4.5 m off the player's BACK (`AllyBase.radio_leash`,
  `RADIO_LEASH_M`, own FOLLOW branch — formation slot untouched off-net); **the cord NEVER
  rips the handset away** (`radio_handset.gd` snap deleted, `cord_snapped` signal removed,
  cord_length 3→8 m to cover the leash). Prompt now reads TAKE/RETURN HANDSET.
- **ROUNDS BOARD (bench):** `support_fire_range.gd` top-left legend, live counts per tier
  from `director.fire_support` ("x3" / "- OUT"), keys 1-8 + [9] assault + LMB/RMB/[T]. The
  main-game HUD already had this (mission_hud.gd fire panel) — the bench just never did.
- **BUNKERS EXPORTED AND PLACED:** blender agent exported his two originals from
  `WORKBENCH_bunkers` (y≈-170) — `fb_bunker_mg.glb` (668 KB, mounted M60 included) +
  `fb_bunker_fighting.glb` (139 KB) into the kit dir; `-colonly` twins share the real mesh so
  the slits stay OPEN; truth source untouched (worked from a copy, deleted after). Placed
  flanking the line in `support_fire_range.gd` (`BUNKERS`) and in the arena firebase corner
  (`_build_firebase`). **GATED on one editor import pass** — fresh GLBs print a graceful
  skip until then.
- **ARENA READABILITY + DESTRUCTIBLE TREES (his ruling):** jungle carve in
  `ai_stress_arena.gd` `_build_jungle` — grassland inside `CLEAR_RADIUS_M 38` of
  `FIREBASE_ORIGIN` (-62, 62), light-jungle band to 52 m, heavy beyond; AI sight grid
  stamped honest to match; `_plant_fellable_treeline()` puts 26 real FellableTrees on the
  rim arc so blasts drop trunks he can watch fall. Arena night env is ALREADY the shared
  MissionWeather preset + shared GunFX x5 explosions (ship parity, ADR-026) — nothing
  changed there; if he means a specific main-world look beyond that, that's a new ask.
- **STILL OPEN WITH HIM:** M60 mounted FPS view placement ("i still also need to figure out
  how to place the m60 mounted fps view") — note `[F] MAN THE GUN` / `mg_emplacement.gd`
  exists, and the exported `fb_bunker_mg.glb` carries a mounted M60 + `mg_fire_point`
  marker: the natural mount. Needs his bench session. Medical-complex animation agent still
  running (blender-overseer, med_anim_workbench pipeline).

## 2026-08-05 — THE DEFENSIVE ZONE DOCTRINE (his decree, live from the wave run)

**His words:** *"instantly they go hunting and attack and no one was trying to defend the
firebase we had. we need to create this idea of defensive zones since no real us army unit
would be full of the gung ho assaulters even if they were strong. the usual contact on
defense is hold and fight. thats why the vc are trying to mortar us and overwhelm us."*

Built same session, arena-scoped, on the two existing grounding precedents (the RTO cord
gate in `_think` and the cord-pull in `_execute_combat`):
- `AllyBase.defense_zone` + `defense_zone_radius` (0 = no zone, patrol AI untouched).
  Zoned man: scorer never hands him ADVANCE/FLANK (`ally_base.gd` goal gate), his
  close-the-distance footwork stops at 0.8× the rim, past the rim his one legal move is
  back onto his ground (zone-pull, cord outranks zone), and a zone landing mid-push flips
  ADVANCING → COMBAT. Cover search is already local, so zoned men fight from cover on
  their ground. RETREAT/SEEK_COVER stay legal — a breaking man still breaks (Pillar 5).
- Arena: `_assign_defense_zones()` on every wave start — all living US men get one of 3
  wire sectors (16 m radius, MOVE_TO their sector, RESCUE exempt), so the siege is
  defended, not hunted.
- **FULL-GAME INTEGRATION IS COUNCIL WORK, not done:** garrison at fsb_main (its stations
  should BE zones), patrol-squad "strongpoint" verb for the player, enemy camp defenders
  using the same doctrine (EnemyBase has no zone yet). The AllyBase mechanism is the seed.
- **AMENDMENT, his words same session:** *"what ties into the main game is when ambient
  squads form up to go on patrol they switch from defense to 'attack walk this route'."*
  The doctrine is a TWO-STATE life: DEFEND (zone held, hold-and-fight) ⇄ PATROL (zone
  released, walk the route, fight forward). **THE GATE IS THE SWITCH (his words):** *"the
  gate for the switch off is when they walk out the gates just like when and where players
  return to fire base"* — crossing the wire gate flips the state in BOTH directions, the
  same diegetic seam where the player's patrol banks (`_bank_patrol`,
  `field_director.gd`; the W-3 hunter top-up already keys off that gate seam). One
  doorway, one law, player and ambient squads alike. The VC already live this shape (camp guards hold, `patrol_route`
  squads walk) — the US side mirrors it. DEPENDENCY: main-game garrison men are
  Civilian-class until the POST-DEMO soldier-class migration (garrison decree 2026-08-04),
  so ambient US patrols forming up out of zones ride that migration; the schedule
  machinery that would drive form-up times already exists (`civilian_schedules.gd`).

## 2026-08-05 — SURVIVAL WAVES + ARTY MUST TEAR THE JUNGLE (his live-run convictions)

- **Survival mode (his order):** arena siege is now 30-man waves (`SIEGE_STRENGTH 30`),
  auto-chained 15 s after each break until the player falls, with a wave counter and a
  final "N WAVES HELD" toast (`_on_siege_ended` chain). Random 81mm illum pops over the
  fight every 20–45 s while waves run (`_random_illum_tick` → `_illum_burst`, no stock).
- **PERF: "its def laggy with everything going on" (his run, 30-man waves + 18v18, Intel
  UHD).** He ruled the load stays — *"thats what doing these large waves are for."* The
  stress test produced its first bill: `MAX_ACTIVE_RAGDOLLS` 256 → 12 (`model_actor.gd`) —
  the 2026-07-28 NO-CAP ruling existed only because capped men froze standing, and the
  8/4 settle-flat guard cured that; the const's own comment authorized the number's return
  when the bill showed. FURTHER TUNING GATED ON MEASUREMENT: the arena perf overlay
  (CPU/GPU split, per-system buckets, spike catcher, F1 jungle / F2 clutter / F3 lights /
  F4 characters / F6 shadows attribution toggles) is the instrument; his readout during a
  laggy wave names the next cut. ADR-026 Part B remains the standing systemic answer.
- **"i dont really see anything happen to the jungle" — root cause, fixed.** Three stacked
  facts: bench terrain never digs (by design), the scar radius for arty computes to ~4 m
  (3 cells × 0.9 × 2 m — invisible under canopy at night), and `JunglePatchLayer` was
  invisible to DamageSystem entirely — batched 12 m tiles took no blast. Fix:
  `JunglePatchLayer.blast_clear(pos, r)` fells whole patch tiles (zero-scale, indices
  stable, permanent), layers self-register in group `jungle_patch_layer`, and
  `DamageSystem.apply_damage` routes every blast through it at a new per-profile
  `canopy_clear_m` (arty 13 · bomb 18 · napalm 26 · grenade/bunker 0 — a grenade must not
  drop a jungle tile). Tile origins sit up to ~8.5 m from an impact, hence radii larger
  than the crater's. Applies to main world AND benches (group-based).

**POINTER CORRECTION 2026-08-05 (NO-DRIFT law):** the last sentence above is false in mechanism.
`vegetation_manager.gd:114-123` is an either/or and `WorldConfig.USE_TREE_COVER = true`
(`world_config.gd:21`), so the generated AO builds `TreeCoverLayer` and **never constructs a
`JunglePatchLayer`** — the `jungle_patch_layer` group is empty in the shipped world and
`blast_clear` runs on the benches only. The OUTCOME claim still holds by a different path: the main
world's `clear_area` clears vegetation at `radius_cells × cell_size 4.0` = **8 m grenade · 12 m
arty/mortar · 20 m bomb · 60 m napalm**, i.e. as much or more canopy than the arena's tile-fell
radii. Radius is not the gap; see the migration decree.

## 2026-08-05 — THE MIGRATION DECREE (playtest zones → demo & game world)

Full record: `production/war_room/2026-08-05_playtest_to_world_migration/`
(briefing + 5 analyses + discussion + synthesis). Council: systems-designer, technical-director,
world-architect, game-designer, devil's-advocate. Code only.

**ALREADY TRANSFERS — no work exists:** shoot-through materials (tagged at `site_planner.gd:189`
and `:1373`; four live consumers) · RTO fire support with every 8/4 tuned value (the range holds no
copy — `support_fire_range.gd:91` wires the shipped `FieldDirector`) · threat-corridor tree promotion
· firebase destruction (parapet **140 HP × 80 segs**, bunkers 260, towers 180, sandbag stacks 90 —
`site_planner.gd:1542-1615`, nav rebake via `destructible.gd:92-94` → `nav_baker.gd:193`).

**MECHANICAL LIFTS, in order:**
- **M-1 · crater budget.** `MAX_DEFORMS_PER_MISSION = 40` (`damage_system.gd:81`) and every
  ground-burst arty round spends one (`field_director.gd:842`) → 3–5 fire missions exhausts it and
  the ground silently stops cratering mid-demo. Make it a rolling window. **DO FIRST.**
- **M-2 · world structures get HP** — call `_wire_structure_destructibles`/`_adopt_structure`
  (`site_planner.gd:1561-1615`) from `place_structure` (`:162`). Matches by mesh-name prefix, no
  Blender re-export, lands in demo AND patrol at once (`game_flow.gd:582, :606`). Straight lift.
- **M-3 · one HP table** — three exist and have already drifted (`fire_support_bench.gd:48-55` ·
  `site_planner.gd:1552-1558` · `support_fire_range.gd:988` fort HP 110). **Blocks M-2.**
- **M-4 · ballistic tags** on the felled log (`fellable_tree.gd:129`), `tunnel_room.gd:29`,
  `field_director.gd:1027`.
- **M-5 · arena stops writing on the game.** `EnemySquad.tiering_enabled = false`
  (`ai_stress_arena.gd:304`, static, never restored — **ADR-026 Part B tiering off for the process**)
  and `GibSystem.gib_lifetime_s = 25.0` (`:305`). `GameSettings.ai_vs_ai_cone_mult` (`:308`) is a real
  mechanism with zero effect at defaults — hygiene.
- **M-6 · delete the arena hook in shipped bullet code** — `bullet_system.gd:172-176` duck-types
  `get_player_damage_mult()`; only provider is `ai_stress_arena.gd:2031-2032` (ADR-023).
- **M-7 · drift pass:** `site_planner.gd:1479-1484` (pre-fix problem statement above its own fix) ·
  `:1491-1492`/`:1536-1537` (SiegeDirector does NOT read a breach — `siege_director.gd:63-67`) ·
  `ai_stress_arena.gd:1954-1955` · dead `site_planner.gd:140 _is_soft_cover()`.

**NEEDS HIS RULING:** fallen trees become real cover (a small rewrite of the tree-candidate model,
net-zero physics bodies inside the ADR-033 ring, but needs a rotated-capsule shape family, a
hole-surviving candidate, and the 24-log FIFO fixed against ADR-031 permanence) · destruction reach ·
segmented trees (council: WAIT until logs are cover) · defensive-zone full-game integration.

**REFUSED:** arena `SPOT_*` constants (second perception authority, ADR-023) · bench unlimited stock
+ `_cas_cooldown = 0` (deletes the fire-support economy) · arena `SIEGE_STRENGTH` survival figure ·
every instrument dial (ADR-029 Q5).

**PERF, HONESTLY:** structure HP and log colliders are both priced from structure and are cheap
(no per-instance process, adopted colliders, one shared rubble draw call, 2 levellings/frame,
net-zero bodies in the 1280 ring). **UNKNOWN and unmeasured: any jungle sightline, ever**
(`PERF_LEDGER.md:968-975`). Probes named: **A — THE WALK** (zero code, `game_world.gd:481`),
**B — THE BARRAGE SPIKE** (this is the ADR-031 gate, open since 2026-07-25), **C — the log ring**
(extend `tests/test_trunk_ring.gd`).

**SEVEN DECISIONS FOR THE SUMMONER** — see `synthesis.md` closing section.

## 2026-08-05 — HIS SEVEN RULINGS + THE ORDERED BUILD PLAN

Full plan: `production/war_room/2026-08-05_playtest_to_world_migration/build_plan.md`.

**FIVE THINGS THAT CHANGED THE PLAN:**
1. **His "on call" collider ruling is already how the game works.** ADR-033 left NO permanent tree
   colliders; a 1280-body pool serves a 70 m player-keyed ring plus time-boxed threat zones. So
   ruling 1 (fallen trees are cover) is implemented as **data, not colliders** — and that collapses
   ruling 6 (persistence) into the same change. `TreeCoverLayer.COVER_TRUNK:20-28` **already carries
   radii for `fallen_log_a/b`, `felled_trunk`, `tree_stump`.**
2. **`tools/make_felled_tree.py`'s own docstring specifies ruling 1 verbatim** ("what it LEAVES is
   COVER") and `felled_trunk.glb` + `tree_stump.glb` are on disk. This is finishing an unwired
   pipeline, not a new feature.
3. **Ruling 2's premise is wrong.** `MAX_DEFORMS_PER_MISSION`'s comment claims it bounds frame
   spikes; `TERRAIN_DEFORMS_PER_FRAME = 1` already does that completely. The 40 is a cumulative
   work ceiling bounding **no memory at all**. ONE crater = a whole 256 m chunk rebuild (4,225 verts,
   8,192 tris, ~24,576 GDScript `SurfaceTool` calls + `create_trimesh_shape` + full veg re-scatter),
   synchronous main thread — **likely the direct cause of "its def laggy with everything going on."**
   The answer is a measurement (P0-B), possibly a cheaper dig, not a bigger number.
4. **Ruling 4's system does not exist.** `ProvinceState`/allegiance/sympathy = **zero hits repo-wide**.
   ADR-017/019 are pure decree. Scoped to two live hooks: `EvidenceLedger` (in-patrol retaliation,
   `field_director.gd:132-187`) + `CampaignState.add_threat_modifier` (`campaign_state.gd:222`,
   persistent, already read by SiegeDirector).
5. **Ruling 5 collides with the 8/4 no-procedural-geometry law — his own wording resolves it.**
   "take an existing tree and fragment more parts of it" = mesh surgery on the existing GLB, never a
   `make_jungle_flora.py` re-run. Headless-feasible. Needs his eye on cut heights, snag silhouette,
   fallen-canopy read.

**BULLET PROMOTION — briefing corrected.** The gap is narrower than "bullets don't promote": the
player already carries a permanent 70 m collider bubble, and ADR-033 *ratified* "beyond 70 m bullets
do not strike trunks." The real defect is **asymmetric** — an enemy beyond 70 m has no working cover
of his own. **And the dedupe does NOT save corridors:** `_add_zone` needs BOTH endpoints within 4 m,
which at 250 m is 0.92° — less than aim jitter, so most rounds would pay a full `_update_ring`.
**Fix: anchor promotion to the SHOOTER'S POSITION** (stable → dedupe actually hits). Starting points
only: radius 8 m, duration 2.0 s. Positive finding: `ZONE_MAX` eviction takes the soonest-to-expire,
so short bullet zones can never displace a live shell corridor. Stays clear of the rejected
gaze-based promotion — keyed to weapons firing, never to what is on screen.

**PHASES:** P0 measure (THE WALK · ONE DIG · THE BARRAGE = the ADR-031 gate) → P1 landmines (crater
ceiling · **unbounded scar `Decal` nodes, never freed during play** · **`_in_veg_hole` linear scan
over every hole ever, per plant, per rebuild** · arena static leaks · bullet hook · drift) → P2 fell
registry (rulings 1+6) → P3 shooter-anchored bullet promotion → P4 destructible world + temples
(rulings 3) → P5 consequence hooks (ruling 4) → P6 defensive zones (ruling 7) → P7 segmented trees
(plan only).

**FOSSIL BLOCKER ON RULING 7:** `AllyBase` has TWO hold-ground systems — `post_anchor`/`post_leash`
(`ally_base.gd:161-164`, garrison) and `defense_zone`/`defense_zone_radius` (`:138-139`, arena).
Merge before adding a third caller. `EnemyBase` has **none** — enemy zones are a design build,
**deferred** on depth-over-breadth.

**BUGS FOUND:** `_bank_patrol` (`field_director.gd:1768-1791`) never copies `civilian_deaths` — every
successful patrol silently discards it · `player.gd:249` calls `on_atrocity_witnessed`, which
`Civilian` does not implement (permanent no-op) · scar decal Y is sampled before the queued dig runs.

**SCOPED DOWN on his "few very fleshed out systems" brief:** ruling 4 → two hooks not ADR-019 ·
ruling 7 → US side only · ruling 5 → one archetype (broadleaf) before fourteen species.

**CHARTER DRIFT:** `OVERSEER_CHARTER.md §8/§10.3` still mandates driving `bd`; `CLAUDE.md:401-408`
retired it 2026-07-22 and forbids running it. Repo law wins; charter to be corrected.
