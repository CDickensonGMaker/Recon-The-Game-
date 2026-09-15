# DEVIL'S ADVOCATE — eight asks, one session, and what each one costs (2026-09-14, evening)

Lens: break the brief before anyone builds on it. Every pointer read tonight on `RPG-build` at
`3abb6041` + the dirty tree. No game file edited. No probe run — the tree is unverified (§8) and a
probe on top of it would measure a build nobody committed. My predecessor's 9/13 positions
(`../2026-09-13_rpg_45min_hearts_and_minds/analysis/devils_advocate.md`) stand; I extend, not repeat.

**Three pointer defects in the brief itself, before anything else (POINTER LAW):**
- `briefing.md:74` cites `-044 progression spine` as if in `production/adr/`. **It is not.** It lives
  at `war_room/2026-09-09_progression_spine/ADR-044-the-progression-spine.md` with a banner: *"HIS
  SCOPE CORRECTION CLOSES THIS COUNCIL ... EVERYTHING in this ADR is NEW-SYSTEM SCOPE and POST-DEMO"*
  (`:3-8`, `:12`). `production/adr/` goes 043 → 045. Citing it as a constraint imports a post-demo
  document as canon.
- `briefing.md:60` — *"wreck = `huey_crashed.glb`"*. **No such file.** `assets/us/aircraft/` holds
  `a1_skyraider_crashed.glb` and `f4_phantom_crashed.glb` only.
- `briefing.md:64` — *"a small reusable trigger → staged-beat system"* as if none exists.
  `scripts/missions/scripted_sequence.gd` + `mission_trigger.gd` exist, ruled KEEP by him 2026-07-20
  (`scripted_sequence.gd:3-6`), with the Pillar-3 law already written in (`:19`: *"A sequence NEVER
  disables an agent's take_damage, perception..."*). Building a second one is the Fossil Law.

---

## 1 · THE 3x MAP — "better performance is somewhere we're really getting"

### 1.1 The number is not 3x. It is 4x of the thing that costs.
`terrain_manager.gd:57`: `chunks_per_side = int(ceil(map_size / chunk_size))`. 512 → 2×2 = **4
chunks**. 890 → ceil(3.48) = 4×4 = **16 chunks**. "3x area, ~900 m side" is a 4x chunk grid: 4x
terrain mesh builds, 4x `create_trimesh_shape()` cooks, 4x `generate_for_chunk` veg scatter, all
synchronous behind the load screen (ADR-013 context, `terrain_manager.gd:209-227, 261+`). The honest
choices are 768 (3×3 = 9, **2.25x**) or 1024 (16, **4x**). 890 buys 1024's cost for 890's ground.

### 1.2 What the 512 world already is, and what ×3–4 does to it
The 9/10 census (`memory/recon-perf-audit-2026-09-10`, `tools/probe_scene_census.tscn`): **21,859
nodes · 4,757 MeshInstance3D (1.52 M tris, 4,125 with NO visibility range) · 3,631
MultiMeshInstance3D at 7.8 instances each (27 species × 64 m buckets = the 1,200–2,400 draw calls)**.
Veg scatter is per chunk. ×4 chunks → ~14,500 MultiMesh nodes, ~19,000 no-range MeshInstances. The
9/11 evening verdict (`memory/recon-fps-audit-2026-09-11`): *"CPU is no longer the wall; the GPU is."*
A 4x scatter field with no visibility ranges lands on the wall that is binding. From a hillside on
an 890 m map the frustum holds MORE of it, not the same.

**Honest expected delta: negative, by an amount nobody can state.** No row in `PERF_LEDGER.md` was
ever taken on a map between 512 and 1280 with the demo's population. The 1280 rows are pre-9/08
and pre-LOD. The claim "better performance" has zero evidence on the bigger map and two mechanisms
against it (draw-call scaling, resident chunk memory).

### 1.3 What would have to be true for it to be neutral
Exactly the hard gate GAME_GUIDE §6.1 already put on the 2 km map (`GAME_GUIDE.md:344`): *"PARKED
behind a hard gate: terrain LOD/distance-culling shipped and measured, AND placement bands that
scale."* That gate was written for 2 km; every reason in it applies at 890. Distance culling on
the 4,125 range-less meshes and 256 m canopy buckets (audit misuse #3) must ship and be MEASURED
FIRST, on the 512 slice, A/B — the same bench that proves the 3x map neutral proves the 512 slice
faster. **The perf work is the gate, and it is worth doing on the map he has.** Then, and only
then, `DEMO_MAP_SIZE` (`game_flow.gd:586`) moves.

### 1.4 The sim beyond 240 m does not exist — so what does 3x buy?
`terrain_watchdog.gd:9-10`: `SUSPEND_DIST 240`, `RESUME_DIST 210`; `:41-58` sets
`physics_process(false)` and `visible = false` on every enemy, non-squad ally and civilian past it,
every 2 s (`POLL_SECONDS 2.0`, `:7`). On the 512 slice the 240 m disc (181 k m²) is ~69 % of the
map (262 k m²) from the centre. On 890² (792 k m²) it is **23 %**. Three quarters of the "3x map" is
frozen from wherever the player stands — no hunters converging, no VC "hunting the crash site by
H&M / presence" (`briefing.md:61`), no patrol density to feel, no civilians reacting. The dealer/HQ
chains promise a world that reacts across the map; the watchdog guarantees it cannot, and the
`ai_lod.gd` far tier (`PROMOTE_M 80 / DEMOTE_M 105`) never engages past 240 because the man is
already off. **The larger map is either scenery, or it costs raising `SUSPEND_DIST` — which is
exactly the CPU the 9/11 wave just bought back.**

### 1.5 The walk arithmetic — the brief's own number is wrong, and the correction cuts the other way
The brief assumes grunt speed ~1.3 m/s. `player.gd:12-13`: `WALK_SPEED 5.0`, `SPRINT_SPEED 8.0`;
`ally_base.gd:13` `move_speed 5.6`. At 5 m/s, 800 m out = **160 s real = 72 sim min at 27x**; out and
back = 5.3 real min = 2.4 sim hours. Not 20 minutes. So 3x does NOT make the day too long — it makes
the 512 slice **too short**: the village at 185 m (`mission_generator.gd:770-773`; NOT the 280–450 m
open-patrol band, which is `site_planner.gd:39`'s comment for the 1280 map) is 37 s from the gate;
the camp at 300 m (`:854-856`) is a minute. Against the 9/13 arc (night at 1667 s) the 25-minute day
on the 512 slice is 25 minutes of ground that takes 3 to cross. **That is the real argument for room,
and it is an argument about PACING, not performance.** It is answered as well by a 5 m/s → 2.5 m/s
jungle walk (a constant) as by 4x the chunks — and the constant costs 0 fps. Nobody has measured
which the player would rather have. The pilot chain's `ESCORT_TIMEOUT_S 420` (`pilot_recovery.gd:28`)
and `CRASH_AHEAD_M 220` (`:18`) were tuned for the small map; on 890 m a crash 220 m ahead of a
transit can sit 600 m from the wire — 7 minutes at pilot pace, with detours, is a coin flip on
`_lose()` (`:236-241`).

### 1.6 Memory
15.6 GB box, ~20.6 GB commit, ~17 GB committed idle with his usual load
(`memory/laptop-commit-ceiling`). 4x trimesh colliders + 4x heightmap + 4x scatter + 4x nav bake
input is unmeasured. Nobody has ever printed `Performance.get_monitor(MEMORY_STATIC)` for the demo
world. **Must be measured on the 512 slice before the number is touched**, or the first symptom will
be his editor dying at load with GIMP open.

**Sacrificed if we proceed:** the 9/14 numbers (mean 37.5 / median 34 / p95 68) with no measured
replacement; the ADR-039 §6 gate crossed by a smaller number; a boot 4x longer; the 240 m sim disc
exposed as 23 % of the world. **If we refuse:** the 512 slice stays a 3-minute walk with the village
37 s from the gate and the escort a formality — the pacing gap is real and the map is one of two
fixes for it.

---

## 2 · THE DEALER

### 2.1 He is FROZEN by name
`GAME_GUIDE.md:326` FROZEN (post-core): *"... capture/POW epic · full-volume battle director · **RPG
shop** · ride-or-walk"*. `:330`: *"A frozen epic thaws only by explicit decree."* §6.1 (`:338-341`)
records contraband as *"the reward currency ... Canon, three guards: never from corpses · everything
consumable · never buys a weapon"*. The brief's dealer *"trades"* and *"what he moves reaches the
village / the enemy"* — a market with two sides. His words today are a decree, and Law 3 says he can
thaw it. But the council must SAY it is a thaw of a FROZEN epic, name the three guards as binding,
and not call it "wiring the faction line" (ADR-038 §1 gives the black market a *price list*, `:47`,
which is a REGISTER of speech, not a shop).

### 2.2 Loot as the optimal strategy
ADR-044's guard on trophies (`ADR-044:239-247`) was designed against a loot treadmill; it is
post-demo. The 7/30 ruling (*"searching a man is not a slot machine"*, quoted `ADR-044:249-253`)
deleted the corpse roll. A dealer who buys CAPTURED WEAPONS makes every corpse a price. The only
thing that stops loud play from being the optimal kit strategy is the "never buys a weapon" guard
run in BOTH directions: he does not BUY guns either. If he buys AKs, the demo's 45-man assault is a
45-AK payday and the H&M ledger's `fire/` deed is the cost of doing business. **The trade table
must be: consumables in, consumables out, and nothing that came off a body.** If the council writes
one line where a rifle has a price, Pillar 3's "stealth is an economy" is inverted — noise becomes
the economy.

### 2.3 The price list is a number
ADR-038 §2a (`:96-104`): *"no numerals, no comparatives of degree"* in a faction LINE. A shop screen
with prices is numerals on the black-market voice by construction, and "prices went up since you
went through" is the DIRECTION OF CHANGE the law forbids. The only §2a-legal dealer is one whose
prices never move with the ledger — at which point he is not "integrated to the enemy presence"
and the ask's premise is gone. **Pick one:** a shop (prices, static, not an H&M readout) or a voice
(the worked sample `:70`, no numbers, unprompted). Both is the meter with a till.

### 2.4 Zero code exists
`grep -rli "contraband|black_market|dealer|barter" scripts/` → nothing. `DynamicMissionFactory`
(`dynamic_mission_factory.gd:14-75`) offers locations, not asks. There is no inventory of tradeables,
no verb, no UI. "Chain of quests" for a man who does not exist is a system, not a wire.

**Sacrificed if we proceed:** the FROZEN row (silently); the corpse ruling under pressure; a §2a
breach on the first price. **If we refuse:** the demo has no second voice at the wire and the
black market stays canned — which is what ADR-038 §5 says it is today anyway.

---

## 3 · THE HQ CHAIN

### 3.1 A chain is a rail unless every link can be skipped
Pillar 3. The existing tasking is a picker, not a chain: `_advance_route_tasking`
(`field_director.gd:1392`) and *"THE ONE PLACE the sweep's location changes"* (`:1666-1669`) — one
area offered over a live net, never a sequence. A "chain" with the shoot-down as a *fixed point*
(`briefing.md:61`) and the assault triggered by completion (handoff §0A, "quest-triggered assault")
is a rail with the lights off. The test: can a player who ignores HQ from minute 1 still get the
crash, the escort, the dusk and the assault? Under the 9/13 decree, yes — the clock owns the arc.
The moment the assault waits on a tasking, no.

### 3.2 The back-door meter
"Village trust changes patrol density, ambush odds" (`briefing.md:57-58`). A player counts men. Two
patrols today vs four tomorrow is a number, read off the world instead of the HUD, and it is
UNAMBIGUOUS — worse than §2a's "with causal annotation" case. The 9/13 decree's bands
(`hm_ledger.gd:45-54`: hostile/wary/quiet from KINDS, never counts) were built so no consumer could
read a gradient. Patrol density from a band is 3 fixed states — the player still learns "kill a
civilian = double patrols." Ambush *odds* are worse: odds are a rate, and a rate is banned outright.
**Legal shape:** presence/absence of a KIND of thing (a wire across the trail, a patrol that now
walks the road instead of the paddy) — a change of subject, never of quantity.

### 3.3 Causality in one 45-minute day
`fresh-player-testing-law`. The 9/13 DA (§3.1) already showed the paddy consumer needs the player
to look at one paddy twice. An HQ chain that reads "village trust" needs him to (a) act at the
village, (b) see the enemy behave differently, (c) attribute (b) to (a) — inside one day, with the
watchdog freezing everything past 240 m (§1.4). He will attribute the assault to the clock, because
it IS the clock. **No fresh player perceives H&M → enemy presence in one sitting unless a line says
it, and a line that says it is the meter.** The honest demo claim is the 9/13 decree's: one wordless
village reading and one warning present-or-withheld. The HQ chain adds a THIRD reading of the same
three deeds.

**Sacrificed if we proceed:** Pillar 3 at the assault trigger; §2a through patrol counts; a fresh
player who never sees the causality. **If we refuse:** the HQ "office" (ADR-038 §1) stays a
toast source; the RPG premise is carried by the pilot and the partner, not by orders.

---

## 4 · THE HUEY CRASH

### 4.1 The existing system shoots down a SKYRAIDER, not a Huey
`zpu_gun.gd:226-227`: `if plane == null or _flight_kind(t) != "skyraider": return`. `request_down`
takes a `CASAirplane` (`pilot_recovery.gd:60`); the wreck is `a1_skyraider_crashed.glb` (`:12`);
ONE `_pilot: AllyBase` (`:41`). `Helicopter` has a `CRASHING` state with a fall path
(`helicopter.gd:261-272`) and **nothing in the repo ever sets it** (`grep "state = State.CRASHING"`
→ 0 in `helicopter.gd`; `seat_system.gd:369, :410` only READ it). No `crashed` signal on
`Helicopter`, no wreck swap, no asset. "Wire to a sensible existing system" is honest only as: the
PilotRecovery *chain* (wait → escort → recover/lose) survives; the shoot-down, the airframe, the
wreck, the survivor count and the follower fan-out are all new. The uncommitted tree already made the
Skyraider guaranteed in demo mode (`zpu_gun.gd:233`, dirty) — the 9/13 decree item 4c. **Switching
the airframe re-opens a decree item that has not been gated yet.**

### 4.2 Where the ZPU lives vs. where a Huey flies
The gun stands beside the camp, 300 m from the FSB on the temple flank (`mission_generator.gd:854-856,
:953-961`); `ENGAGE_M 420` (`zpu_gun.gd:20`). 300 < 420: **the gun's engage disc covers the
firebase pad.** Hueys fly LZ cycles onto that pad (`air_traffic.gd:804`, `_dispatch_lz_cycle`).
`_process_crashing` flies 18 m/s forward, 16 m/s down (`helicopter.gd:263-264`): from 60 m AGL that is
~70 m of forward travel. A slick hit on final over the wire crashes INSIDE the wire with
`apply_explosion_damage(150, 40, r=10)` + a `SMALL_EXPLOSION` crater (`:270-272`) — on the garrison,
on the pad, and the crater breaches the compound navmesh and forces the collider-path rebake
(~110 ms, `memory/recon-fps-audit-2026-09-11`). "Fixed point, in view" therefore needs an AUTHORED
transit leg the ZPU can see that does NOT cross the wire — a route, which is the thing ADR-041 says
must be a plan (post-demo, `ADR-041:3-4`). Without it the crash site is wherever the gaggle was,
which is the 9/13 DA's §3.1 finding again with rotors.

### 4.3 The roll
His ranges: pilots 1–2, pax 1–4 → **2 to 6 survivors, never 0.** All-dead is impossible by his own
numbers; the "dice roll" is the SIZE of the escort, not whether there is one. Say so, so the council
does not design a `_lose()` branch for a case that cannot occur. But 2–6 wounded men following is
the follower class the NPC batch is still red on: `ally_base.gd:1511-1574` FOLLOW slots at 2.5–4.5 m
(`:493`), `_refresh_separation` (`:2407-2430`) pushing a `limit_length(1.0)`, stuck detector at
0.3 m/s (`:57-83`). The census still reads 14 stuck / 6 overlaps on the garrison alone
(`memory/recon-playtest-2026-09-14`, gates line). Six followers through jungle scatter to a 30 m
`HOME_M` (`pilot_recovery.gd:22`) — `_tick_escort` reads ONE pilot's distance (`:243`); with six, who
counts as arrived? The first? All? A man stuck on a tree 200 m back is `_lose()` for everyone or a
recovery with a corpse in the green, and the litter team (does not exist in code — `grep litter` →
0) is a new system the brief does not cost.

### 4.4 The census gates
`test_firebase_garrison` is red at HEAD (57 men, the pre-warm's 17 parked off-map,
`memory/recon-npc-first-batch-2026-09-13`). Six more AllyBase bodies arriving at the wire, MOVE_TO
`_ward_pos()` (`:250, :273`) one after another into the aid station — the ward door is one spot;
the 9/13 decree parks ONE pilot there on HOLD. Six is the chow-hall stack (cooks + diner at one mesh
point, same memory). The overlap count goes up by construction.

**Sacrificed if we proceed:** the gated 9/13 pilot item re-opened; a new airframe path, wreck asset
(his art-day or a Blender agent), a route the ZPU can see, N-follower escort logic, a ward for six;
the risk of a slick on the pad. **If we refuse:** the Skyraider chain ships as decreed — one pilot,
one ward door, spectacle intact. The Huey is the better picture and the worse gamble for THIS demo.

---

## 5 · SCRIPTED EVENTS FROM THE COMIC

### 5.1 The rule is a NO, and it forbids the obvious beats
His rule, verbatim (`war_room/2026-09-09_conquest_quests/synthesis.md:64-65`): *"any horror gore
scene in the comic is supposed to be representative of the psychological state of the person
experiencing the vision."* The synthesis: *"It forbids a world-state rot layer. Any decay the player
sees must be a readout of one mind"* (`:69-70`). In-engine that mind is the PLAYER's, and the demo
player has been in-country for 45 minutes. A skeleton in web gear (I2 p17) or worms on a parapet
are Michael's state after months. Staged in the demo they are a monster, which he has forbidden
(*"no fantasy elements"*, ADR-038 context `:16`).

### 5.2 Eugene without a monster
Gus is a person across three issues (bible `:63-70`; synthesis `:165-178`: floating → praised for a
kill → the ears → beaten and driven out, I3 p19). His arc IS the H&M arc — the institution authors
the atrocity before the man does (`:72-78`). A 45-minute demo can carry ONE Gus beat and only the
FIRST: the new replacement, unassigned, eager, at the wire — because that beat is the player's own
mirror (he is also new) and needs no gore. The ears (I2 p23, I3 p9) require a squad that has been
out for weeks and a rule that *"nobody remarks on it. Ever"* (`:84`) — unstageable as an EVENT
because an event is a remark. **Refuse:** the ears; the necklace; the beating; the skull-faced
sniper as a presence (three issues of build-up, `:195`); the `fya.12` shooting. **Allow:** Gus
arriving; the bag alone in the mud (panel 2, `:235-237` — "everything this quest needs is in what
people are NOT doing", i.e. placement, not a sequence); a helmet on the wire at first light
(panel 3) — but the demo has no first light (`demo_game.gd` "THE DAWN CARD IS DEAD").

### 5.3 Rails, and the system that already exists
`scripted_sequence.gd` is an await runner with `move / play_clip / bark / signal / spawn_prop /
hand_off` steps (`:9-18`) and a hurt/death abort (`:140-146`) — it BREAKS when the world interrupts
it, which is the Pillar-3-legal shape. `mission_trigger.gd:9-12` has ENTER / SIGHT (real raycast) /
NOISE modes. **Nothing new needs writing to stage a beat; what needs writing is the beat, on a
trigger, with the abort intact.** A "cutscene" that suppresses the abort is the rail. His memory
rule keeps cutscenes standalone (`memory/recon-cow-cast-wave-2026-09-12:64`
`[[recongame-cutscenes-standalone]]`); in-engine beats and FMV do not share a system.

**Sacrificed if we proceed:** a second beat runner (Fossil Law) if anyone builds one; a Gus beat
that reads as a stranger's anecdote; anything gore reads as a monster. **If we refuse:** the comic
stays post-demo, which is his own 2026-09-09 ruling (`synthesis.md:6`).

---

## 6 · THE OBSERVATORY

### 6.1 It exists, and it is the right shape
`scripts/dev/observation_tools.gd` — observer cam that makes the AI blind to the watcher (`:4-6`),
a `Label3D` per agent at `OVERLAY_HZ 10` reading `current_state / current_goal / order_mode /
alert_tier / suppression_level / target` by `agent.get()` (`:205-230`), SimClock and time_scale
controls (`:10-11`), `OS.is_debug_build()` gated (`:32, :39`). It PULLS. Pull is why it costs zero
when off: no signal connections, no per-man string built unless the overlay is on. `observation_room.gd`
is the level for it. **The ask is an extension: add noise-heard, last-known
(`enemy_base.gd:207`), witness chain, the H&M band, civilian reaction to the readout string.**

### 6.2 The cost that sneaks in
A "thought process" pane implies a per-man LOG — a ring of strings appended at think time (6–7 Hz ×
45 men × a `String` alloc each = ~300 allocations/s on the hot path the 9/09 LOD was built to
shrink, `ai_lod.gd:7-12`). If the log is written whether or not anyone reads it, the tool costs
when off. If the log is a second place where a decision is described, it drifts from the code the
instant a goal is renamed — a second source of truth, the Truth-law failure. **Legal shape:** the
pane renders the LIVE fields the AI acts on, pulled at 10 Hz when open, and nothing is written
anywhere when it is closed. A "thought" is the goal enum's name plus the inputs that chose it,
formatted at read time.

### 6.3 Scope creep
Map pane, time-scrub: a time-scrub is a recording — save the state of 45 men per tick to scrub
it, which is the persistence work the handoff (§0) says NOT to make a demo prerequisite. The map
pane is the journal's MAP tab (ADR-045 §1) with agents drawn on it — a second map renderer. **One
session builds the readout string and the H&M pane. Nothing else.**

### 6.4 It is evidence-gathering, and that is why it is GATE-exempt
GAME_GUIDE §8.0: the gate blocks feature work until his playthrough. A dev instrument that lets HIM
see alertness, senses and the ledger while he plays IS the playthrough's instrument
(`DEMO_40MIN_HANDOFF` F12: *"Current probes do not prove the player's reported experience"*). It
gathers what ADR-015 demands. It must stay out of the shipped build (`is_debug_build`) and out of
the census gates, and it must not be allowed to become the reason the readout is "verified" — a
tool showing a band changed is not a player FEELING it (ADR-038 §2).

**Sacrificed if we proceed:** ~a session of dev-tool work that ships nothing player-facing; the
temptation to write logs into the hot path. **If we refuse:** he keeps reading logs, and the
9/13 H&M consumers ship with nobody able to watch them work.

---

## 7 · JUNGLE AUDIBILITY

### 7.1 The stimulus exists; the SOUND exists; the range is inverted
NoiseBus `FOOTSTEP 8 m / FOOTSTEP_SPRINT 16 m` (`noise_bus.gd:21-22`) — the AI's hearing. The
player's ears: `AudioManager.play_step_3d` (`audio_manager.gd:114-130`), a pool of `STEP_VOICES 6`
(`:98`), **`STEP_AUDIBLE_M 28.0`** (`:99`), halved when crouched (`:120`), on the WEAPONS bus, called
every 0.85 m of travel by every enemy and ally (`enemy_base.gd:1208-1211`, `ally_base.gd:973-976`).
Jungle sight: ~45 m clearing cap (the 7/12 landmine), 56 m at night (9/13 DA §2). **A man is
audible at 28 m and visible at 45–56 m. You see him before you hear him. That is the whole
complaint, and it is two constants and a bus.** Not a system. Civilians do not step at all
(`grep play_step_3d civilian.gd` → 0) — the village is silent.

### 7.2 What 45 men do to a 6-voice pool
Six voices, first-free wins (`:121-123`), no priority, no distance sort. In the assault the six
nearest-in-time, not nearest-in-space, men own the pool; the sapper at 12 m loses the slot to a
lane-walker at 27 m. Raising `STEP_AUDIBLE_M` to 60 without a distance-priority pick makes the
assault a wall of identical `step_dirt.wav` — the HLL feeling is ONE man's footsteps, alone, which
is a MIX decision (occlusion by canopy, a jungle bus with low-pass, the weapons bus ducking it).
**Pooling AudioStreamPlayer3D is already done (39 sites, `grep`); the ask is a mix and a priority
pick — both branches, both cheap, both need HIS ears in a window, not a probe.**

### 7.3 "The same for you"
The player already emits `FOOTSTEP` at `3.0 * quiet_mult` (`player.gd:1588-1593`); the AI already
hears it. What he cannot hear is his OWN loudness — there is no 2D self-step at a level that tells
him he is loud. That is one `AudioStreamPlayer` and a curve, and it is the half of the ask that is
Pillar-3 stealth-economy (the cost of moving is audible to the payer).

**Sacrificed if we proceed as a "system":** a second audio path beside `play_step_3d`. **If
we do it as a mix:** nothing — except that a headless probe cannot gate it and he must listen.

---

## 8 · THE SESSION

### 8.1 The tree is the first problem
`git status` on `RPG-build`: **13 modified files, 268 insertions**, and `scripts/world/hm_ledger.gd`
+ `tests/test_hearts_felt.gd` UNTRACKED. That is the 9/13 decree's stage 1 (clock 27/12, ledger,
producers in `civilian.gd:1093-1097, :1190-1191, :1311`, `field_director.gd:11`, the ZPU demo
boolean, `test_demo_arc` re-pinned) — sitting uncommitted while eight new asks arrive. Its gates
(`synthesis.md:103-110`: arc test green, hearts-felt green, four NPC tests, a hearts probe, stress 0
errors, commit + push both branches) show no record of having run. Plus the modeler agents' output
(`fb_sandbag_heavy.glb` modified, `fb_duckboard.glb` + `fsb_main_duckboards.json` untracked). **Three
tests were red at HEAD before any of this** (`test_group_walk`, `test_friendly_patrols`,
`test_firebase_garrison`). Nothing built tonight can be gated until the tree is either committed
with its gates run or stashed.

### 8.2 The order I would not deviate from
1. **Gate and commit what is already in the tree** (9/13 stage 1 + the art). Run its own listed
   gates. If red, that is the session.
2. **Measure before any fps sentence** (§8.4).
3. **Audibility as a mix** (§7) — two constants, a priority pick, his ears.
4. **Observatory extension** (§6) — evidence-gathering, gate-exempt, pull-only.
5. **One Gus beat on the EXISTING sequence runner** (§5.2), trigger at the wire, abort intact.
6. Everything else — map, dealer, HQ chain, Huey — is a decree question for HIM, glossed: *"3x map
   = 4x chunks, the sim is frozen past 240 m, and no number exists for it; the RPG shop is on your
   FROZEN list; the Huey replaces a gated Skyraider chain."* Not a build.

### 8.3 What to cut when wall time runs out
Cut from the bottom: 5, then 4, then 3. Never cut 1. If 1 is red, nothing below it is real.

### 8.4 What must be measured before any fps sentence is written
- A paired A/B on the 512 slice at the same revision, windowed, `perf_walk` AND `--stress=assault`,
  quiet box (`tasklist | grep Godot` = 1, `memory/recon-fps-audit-2026-09-11`), `bench-the-game-not-
  the-scenery`: the assault live, craters, trees. Mean / median / p95 / worst named span. Nothing
  from a headless run may be called fps.
- `Performance.get_monitor(MEMORY_STATIC)` + `RENDER_TOTAL_DRAW_CALLS_IN_FRAME` + `OBJECTS_IN_FRAME`
  at world-ready and at the assault peak, 512 vs the candidate size, same seed.
- The census (`--npc-census --test-save`) with the stand-to held: stuck / overlaps / wrong-target,
  before and after ANY follower change (§4.3).
- `phys.terrain_watchdog` worst step (58 ms today) — it scans three whole groups every 2 s; 4x the
  map does not change the man count, but the parked reserve at z≈865 is still being re-seated
  forever (`memory/recon-playtest-2026-09-14`) and will be on any map.
`never-conclude-from-one-axis`: one seed, one route, one window is one axis. Two seeds, two routes.

**Sacrificed by this order:** his four biggest asks leave the session as QUESTIONS, not builds.
**Sacrificed by any other order:** an unverified 268-line tree under eight more changes, and an fps
claim with no row behind it — the exact 9/09 failure (*"built and measured by nobody"*).
