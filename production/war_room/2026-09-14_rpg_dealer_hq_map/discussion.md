# THE DEBATE — 2026-09-14 (five seats; the Arbiter records agreements and names the splits)

Analyses: `analysis/technical_director.md`, `systems_designer.md`, `game_designer.md`, `writer.md`,
`devils_advocate.md`; the map study `study_large_maps.md`.

## Agreed by everyone (no debate needed)

1. **890 m does not exist.** `heightmap_storage.gd:22-31` rounds to 256 m; `terrain_manager.gd:57`
   ceils the chunk grid. 890 costs 1024 and wastes 134 m. The honest numbers are 768 (2.25x) or 1024
   (4x). (TD §1.1, DA §1.1, GD lays out inside ±384 so either works.)
2. **A third simulation tier already ships and nobody wrote it down.** `terrain_watchdog.gd:8-9`
   suspends physics + hides every enemy/ambient ally/civilian past 240 m, resumes at 210, polls every
   2 s over ALL bodies with a `floor_y` raycast each — the 58 ms worst physics step in his 9/14 log. It
   is legal only because `SUSPEND_DIST 240 > GUNSHOT 150`, an invariant nowhere tested. (TD §0, DA §1.4.)
3. **The Huey crash is UNFINISHED, not missing.** `Helicopter.State.CRASHING` + `_process_crashing`
   exist with zero writers; the ZPU refuses the slick on one string (`zpu_gun.gd:226`); `PilotRecovery`
   is the chain (wait → escort → recover/lose); `huey_crashed.glb` is on disk (the DA's "no such file"
   is wrong — `assets/us/aircraft/huey_crashed.glb`, and `collision_table.gd:86` already has its row).
   Only the `lz_cycle` slick carries men — 2 aircrew + 3–6 garrison Civilians, seated and real
   (`heli_lift.gd:137-160, :258-284`); the 11:30 pad cycle is airborne at ~667 s real. (SD §0.)
4. **A trigger → beat runner exists and is ruled KEEP.** `scripted_sequence.gd` (await steps, Pillar-3
   abort on damage/death/target) + `mission_trigger.gd` (ENTER / SIGHT / NOISE). A second runner is the
   Fossil Law. Beats are AUTHORED on it, not a new system. (DA §5.3; GD §2 proposed a JSON shape — it
   becomes the authoring format fed INTO the existing runner.)
5. **The observatory's seed exists**: `scripts/dev/observation_tools.gd` (observer cam, per-agent
   Label3D at 10 Hz, debug-gated, PULL-based, zero cost when off). Enemy has ONE state setter
   (`enemy_base.gd:2686`) and ONE tier setter (`:1655`); civilians have seven raw `state =` writes.
   (TD §4, DA §6.)
6. **Audibility is mostly a mix.** The NPC step pool exists (6 voices, `STEP_AUDIBLE_M 28`), the player
   is already a NoiseBus stimulus; sight cap 45–56 m > hearing 28 m — you see before you hear. (TD §3,
   DA §7.)
7. **The dealer has a body and a corner**: the `quartermaster` at `USSupplyDepot_001/_007`
   (`site_planner.gd:1217`). The interaction surface is `[F]` (there is no talk system). The bench-menu
   shape (`armorers_bench.gd`) is the UI. (GD §0, SD §1.1.)
8. **The tree is unverified and must be gated and committed before anything else lands.** (DA §8.)

## The splits

### S1 — Map size now, or perf gate first?
- **TD:** 1024, two constants; GPU is ring-gated (every layer draws inside a player ring), CPU scales
  with bodies not metres; load +0.6 s; the only map-driven perf term is the watchdog scan. Expected
  fps equal or better per body once the third ring engages.
- **DA:** no ledger row exists between 512 and 1280 with the demo population; the 9/11 wave named the
  GPU as binding; frustum from a hillside holds MORE of a bigger scatter field; memory unmeasured;
  the ADR-039 §6 gate's reasons apply at any size. Neutral only after distance-culling is proven.
- **Arbiter:** both are right about different halves. The ring gates are real (TD's pointers hold);
  the absence of a measurement is also real. Resolution: the size moves behind a FLAG, headless
  proxies are measured now (draw calls / objects / memory / load / census), and the fps A/B is HIS
  windowed pair — no fps sentence is written by an agent. The watchdog slice ships regardless (it is a
  perf win on 512).

### S2 — Is the dealer a thaw of a FROZEN epic, and may he buy a rifle?
- **SD:** D1 "bring me one of theirs" (a captured AK) as the first ask, in conflict with S2.
- **DA:** `GAME_GUIDE.md:326` FROZEN "RPG shop"; the contraband guards (never from corpses · everything
  consumable · never buys a weapon); a dealer who buys captured weapons makes every corpse a price and
  loud play the economy — Pillar 3 inverted.
- **Writer:** Poteet's own line: "THAT DOOR GUN STAYS ON ITS MOUNT. I DON'T MOVE IRON. I MOVE WHAT A
  MAN EATS."
- **Arbiter:** the Summoner's words today thaw the epic (Law 3), and the council SAYS SO. The three
  guards bind. D1 is REFUSED. The dealer moves what a man eats: the case walked down to the ville, the
  slick's mail sack and ration case. Prices are objects for objects and never move (§2a); the rack
  moves.

### S3 — Is an HQ chain a rail, and is "patrol density" a meter by the back door?
- **DA:** a chain whose completion arms the assault is a rail; patrol counts are numbers read off the
  world; ambush ODDS are a rate.
- **SD:** every tasking is issued by the clock or an incident (never gated on the previous), closed
  by a probe-able predicate, and its lever is a KIND of thing present or absent: the ville's mark real /
  decoy / none; pickets 2 / 3 / 5; the warning present or withheld.
- **Arbiter:** the assault NEVER waits on a tasking (the 9/13 decree: the clock owns the arc). Levers
  are presence/absence of a KIND (who comes looking, what the ville gives, whether the warning
  comes) — a change of subject. "Ambush odds" and "patrol density" are named as day-2 plan-time
  consumers and NOT promised for the demo.

### S4 — Huey survivors: which follower system, and can the demo afford six wounded followers?
- **SD:** (c) the slick's own men (HeliLift pax — no duplicate person, handoff rule 5) + (a) the
  PilotRecovery escort generalised to `_men` + `GarrisonDefender.promote/stand_down` for the seams;
  wounded = HP band × move_speed; group holds past 60 m; no teleport for the wounded.
- **DA:** the census is red on the garrison alone; six followers into the ward door is the chow-hall
  stack; the ZPU's 420 m disc covers the pad — a slick can crash INSIDE the wire; the Skyraider's gated
  demo guarantee is re-opened.
- **Arbiter:** SD's wiring is adopted (it is the only answer with zero new men). The DA's three
  hazards become GATES: (i) the inbound leg is authored so the crash point is ≥ `FSB_SITE_CLEARANCE`
  from the wire and the wreck seat uses the same `_passable_near(..., keepout)` as the Skyraider;
  (ii) arrival fans survivors to `off_duty`/`patient` posts through `stand_down` — never six men on
  one cot; (iii) the probe over 8 seeds gates the census against the 9/13 figures. The Skyraider keeps
  the open world; the slick takes the demo's one event.

### S5 — Which comic beats, and where is the horror rule's line?
- **Writer:** four picks — THE BARRELS (dealer intro), THE CROSSING (the informer with a face), THE
  BIRD, THE WIRE AT DUSK ("I SWEAR I SAW SKELETONS" — a report, drawn nothing).
- **DA:** refuse the ears, the beating, the sniper; allow Gus arriving and placement-only beats; any
  staged gore is a monster.
- **Arbiter:** the writer's four are all inside the DA's line (none stages gore; the skeleton line is a
  report that must never coincide with a shootable enemy). THE CROSSING depends on the stream funnel
  (a terrain authoring item, S6) and is deferred with it. BARRELS, BIRD, WIRE AT DUSK are built on the
  existing runner.

### S6 — The stream funnel and the authored-place set
- **GD:** a stream deeper than `WADE_DEPTH_M 1.2` with three crossings is the funnel; the village NW,
  crash NE, camp E, temple S; the band-gated way-station.
- **DA / TD:** ADR-041 is FROZEN with `plan_demo_world` named; a dug stream is terrain authoring + three
  off-mesh links + the siege's north/east approaches; the plan's radii (165–300 m) leave the new ground
  empty unless they grow.
- **Arbiter:** this session grows the RADII (village, camp/ZPU, crash lane, temple) so places are out of
  each other's hearing on the bigger map — that is plan data, legal under ADR-039 clause 1. The stream,
  the fords, the way-station and THE CROSSING beat are the ADR-041 thaw question put to HIM by name.

### S7 — Observatory: pull-only vs a per-man decision ring
- **TD:** a 10-deep ring written at the two choke points is "free enough" (transitions are rare) and
  makes stuck reasons legible in census and bug reports.
- **DA:** any log written whether or not someone reads it is cost when off, and a second description of
  a decision drifts from the code.
- **Arbiter:** the ring is written ONLY at the existing choke points (`_change_state`, `_set_tier`,
  a new civilian setter), holds the enum NAME + a `StringName` cause the caller already knows — no
  string formatting at write time (a `PackedInt64Array` of stamps + `Array[StringName]` pairs). Formatting
  happens at READ time in the tool. Cost when off: an array write per transition. The map pane and
  time-scrub are follow-ups.
