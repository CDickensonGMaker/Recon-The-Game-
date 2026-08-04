# LEVEL / WORLD ARCHITECT — analysis
**War Room:** 2026-08-03 Demo Day Rescope · **Written:** 2026-08-03
**Every claim below is pointered or measured. Measurements name their command.**

---

## 0. WHAT I MEASURED THIS SESSION (not read — measured)

Ran over the shipped game GLB `assets/world/building models/structures/firebase/fsb_main_v3.glb`
(**mtime Jul 26 22:27**), parsing node names out of its JSON chunk:

| thing | measured |
|---|---|
| `work_*` markers | **198** (site_planner.gd:856 says "191 (measured)" — that line is STALE by 7) |
| pad-prefix matches (`fb_helipad`/`PSPHelipad`) | **4 nodes, ONE placement**: `fb_helipad`, `fb_helipad_i`, `PSPHelipad`, `fb_helipad_i_182-colonly` |
| chow hall (`WB_chowhall`, `work_eat`, `work_chow_*`) | **ZERO** |
| medical complex (`WB_medical`) | **ZERO** |
| duplicate-suffix form on work markers | **`.001` (dot)**, e.g. `work_rest.001`, `work_watch.020` |
| duplicate-suffix form on named keys | **`_001` (underscore)**, e.g. `SOCKET_A_001`, `FOOTPRINT_003` |

**The shipped firebase GLB is nine days old.** Neither the medical complex (built ~7/30) nor the
chow hall (built 8/3) has ever existed in Godot. Everything in §5 below follows from that one fact.

---

## 1. THE TWO AREAS

### 1a. What the village generator actually produces today

`SitePlanner.stamp_village` (`scripts/world/site_planner.gd:224-322`) produces, per village:

- 7–10 huts from `VILLAGE_HUT_MODELS`, ≥14 m apart, on flattened dry ground (`:225-242`), each in
  group `flammable_structures` (`:240`)
- one centre feature (`:244-247`)
- **a weapons cache** (`SiteLayouts.CACHE_MODEL`, `:252-254`)
- **a tunnel mouth** (`SiteLayouts.TUNNEL_MODEL`, `:256-260`) — and it is skipped entirely if the
  player satchelled it on an earlier patrol (`place_structure` `:195-202`)
- 1–2 punji traps on the approaches (`:267-270`)
- 2–4 edge pieces (hedge/gate/fence/paddy/tomb) + 1–3 yard props (`:280-291`)
- village dressing props + animals, each contributing `work_*` stations (`_stamp_village_props`
  `:333-372`), interior furnishing off the buildings' own baked markers (`:296-304`)

`MissionGenerator._build_village_site` (`scripts/missions/mission_generator.gd:966-1002`) then adds:
- **civilians** — `civ_range` men (`Vector2i(2,4)` on the patrol path, `:760`), each with an
  occupation from `CivilianSchedules.pick_occupation` and a working point (`:978-990`)
- **households**: parties of 3–6 sharing a hut and a destination (`_assign_households` `:1017-1040`)
- a campfire if NIGHT/DUSK/DAWN (`:994-995`) and 2–4 chickens as live noise traps (`:997-1001`)

### 1b. CIVILIANS EXIST IN CODE — richly. Do not build them.

`scripts/world/civilian.gd` is 38 KB and live. It has states WANDER/FLEE/COWER/GONE (`:16`), a
behaviour tree (`build_bt`, `:599+`), SimClock-driven occupation schedules
(`scripts/ai/civilian_schedules.gd`), group travel (`scripts/ai/group_walk.gd`), noncombatant death
accounting (`_record_noncombatant_death` `:565-570` → `field_director.gd:86-91`), and hitzones.

**Civilian ambiguity is BUILT, not missing.** One villager per village may be an **informer**
(`mission_generator.gd:979` — 50 % chance a village has one at all, then a random index).
An informer who escapes after seeing you calls `_transform_to_vc()` (`civilian.gd:582-594`): he
leaves the `civilians` group, his model swaps to `vc_farmer_m`, and
`FieldDirector.on_informer_escaped(from_pos, last_seen)` (`field_director.gd:627-641`) sends
`INFORMER_RESPONSE` men in on an arc away from where he last saw you.

**So "being seen" already has a diegetic organ, and it is the informer.** The gap is not the
mechanism — it is that nothing in the DEMO plan guarantees the village HAS one.

### 1c. THE ENEMY CAMP DOES NOT EXIST IN THE DEMO

`MissionGenerator.plan_demo_world` (`:666-742`) places **a village and a TEMPLE**, not a camp:
- `p.sites.append({"kind": "village", ...})` at `:714`
- `p.sites.append({"kind": "temple", ...})` at `:721`
- **`var no_camps: Array[Vector3] = []` / `p["camp_centers"] = no_camps` at `:740-741`**

`stamp_vc_camp` exists and works (`site_planner.gd:1629-1644`: tunnel + cache + 1–2 spider holes,
deliberately NOT cleared — "the jungle IS the camp's roof"), and `build_patrol_world` already
dispatches `"vc_camp"` (`mission_generator.gd:761-762`). **Adding the camp to the demo is four
lines in `plan_demo_world` plus an enemy group, not a new system.** The temple at the −135° bearing
is the natural thing it replaces, or the camp goes on a third bearing.

### 1d. WHAT IS ACTUALLY MISSING for the village to be THE ENEMY'S EYES

Not "a system". Three guarantees the demo planner does not make:

1. **The informer is a coin-flip.** `mission_generator.gd:979` gives the demo village a ~50 %
   chance of having an informer at all. In an authored 30-minute demo, "the village saw you" must
   be *guaranteed present*, not rolled. (ADR-020 §2: placement procedural, **existence
   guaranteed**.)
2. **Nothing carries "being seen" to the night.** `SIEGE_STRENGTH` is a `const int = 45`
   (`scripts/levels/demo_game.gd:48`) read once at `demo_game.gd:273`. There is no writer. The link
   the Arbiter wants does not exist in any form — and per the briefing's own r4bk caveat, it must
   come with an audible line or not be built.
3. **The cache is scenery.** `stamp_village` places `CACHE_MODEL` and returns it as `site.cache`
   (`:252-254`, `:311-312`), but the only *player verb* aimed at a village is the tunnel satchel
   (§2). The cache has no destroy/interact path. **The tunnel mouth is already the verb; the cache
   is the thing that makes finding it worth the walk** — and `field_director.gd:1112` already
   describes a "DUNGEON REWARD" for raiding a tunnel or large camp.

**SACRIFICED if we guarantee the informer:** the village stops being a coin-flip and starts being a
scripted beat in everything but name. ADR-020 §2 licenses exactly this for the *first* patrol and
warns (`ADR-020:177-179`) that the authored threshold "will constantly try to become a script."
A demo is one long first patrol, so the licence holds — but it does not extend to the campaign.

---

## 2. THE DESTRUCTIBLE TUNNEL MOUTH — **ALREADY SHIPPED. DO NOT BUILD IT.**

Memory said destructibles need no Blender work. Measured: **the whole verb is live, end to end.**

| piece | pointer |
|---|---|
| HOLD interact at a mouth to collapse it | `scripts/player/player.gd:838-864` (`_tick_satchel_hold`) |
| tap-instead-of-hold goes DOWN the hole | `player.gd:850-854` |
| hold time scales off the GRENADIER's demolitions rating (Pillar 4 — the squad is the RPG) | `player.gd:830-835` |
| the blast: 200 dmg / 60 r / 9 m, ground scar, noise, explosion FX | `player.gd:867-879` |
| the mouth leaves the world — no descent, no spider-hole surfacing | `_collapse_entrance`, `player.gd:882-891`; the enemy reads the same group at `enemy_base.gd:893-902` |
| **PERMANENCE across patrols** | `CampaignState.remember_collapsed_tunnel` / `tunnel_is_collapsed` (`scripts/autoload/campaign_state.gd:478-490`), consumed at `site_planner.gd:195-202` — a satchelled mouth is never re-placed |
| ADR-029 Amendment B compliance (world verb, no counter) | commented at `player.gd:838-841`, matches `ADR-029-amendment-B-world-verbs.md:11-17` |
| the mouth model | `SiteLayouts.TUNNEL_MODEL` = `.../vc_nva/tunnel_entrance_hidden.glb` (`site_layouts.gd:55`) |
| the player can MARK a tunnel for the RTO | `scripts/player/field_mark_verb.gd:19-28` |

The general `Destructible` component (`scripts/world/destructible.gd`) is separate and also shipped:
state-swap not fracture, shared one-draw-call rubble MultiMesh (`:12-16`), throttled destroy queue
(`drain`, `:41-47`), deterministic scatter from position (`:99-105`, ADR-010), and — importantly —
it re-bakes navigation so the hole is walkable (`breach_at`, `:82-87`). This is ADR-031 §1/§2/§5 as
written, and `ADR-031:39-43` records it as shipped in commit `1bc01c4b`.

**ACTUAL COST OF "A DESTRUCTIBLE TUNNEL MOUTH IN THE DEMO": ZERO ENGINEERING.** It ships the moment
a village or camp is stamped, because both stampers place a `TUNNEL_MODEL` (`site_planner.gd:258`,
`:1632`) and `place_structure` puts it in the `tunnel_entrances` group (`:202`).

**The two real costs, and they are not code:**
1. **Satchels.** `player.gd:88` and `:843` gate on `satchel_count`. Somebody must confirm the demo
   loadout carries ≥1 satchel, or the verb is invisible — an r4bk-Law violation with a fully built
   feature behind it.
2. **Discoverability.** Nothing tells the player HOLD does anything. That is by ADR-029 design, but
   in a 30-minute demo a player who never holds the key never sees the best verb in the build.
   This is the same problem as the gate pointer (briefing §B) and should get the same answer —
   a squad bark, not a prompt.

**SACRIFICED:** a demo that guarantees the satchel is used will pull toward a prompt. Say no once
here and ADR-020 §3's binding test keeps saying no later.

---

## 3. THE 4-MINUTE WALK — NOT EMPTY, BUT DELIBERATELY UNDER-DRESSED IN THE DEMO

### What is already alive on the route (all confirmed to run on the demo path — `game_flow.gd:605-607`
calls `plan_demo_world` then the SAME `build_patrol_world`):

| content | pointer | in demo? |
|---|---|---|
| 2–3 ambient VC patrols on circuits between the wire and the village, dormant until 140 m | `mission_generator.gd:774-790` | **YES** |
| 2 friendly US fireteams, 4 men each, same 140 m dormancy | `_spawn_friendly_patrols`, `:847-874` | **YES** |
| paddy fields stamped from the seed | `PaddyStamper.stamp`, called `:677-683` | **YES** |
| a road from the gate to the village, corridor thinned in the veg | `RoadNetwork.build` `:725-727`, `clear_corridor` `:815-818` | **YES** |
| distant war: 1–3 events/hour at 200–800 m, positional audio, two-party answering firefights, fake fireballs | `scripts/ai/ambient_war.gd:1-42` | **YES** (`demo_game.gd:22` `EXCLUDE_AMBIENT_WAR = false`) |
| air traffic incl. Huey packs of 6–9 | `scripts/ai/air_traffic.gd`, formation sizes `:39` | **YES** (`demo_game.gd:21`) |
| temple/prasat ruin on the opposite bearing | `plan_demo_world:717-721` → `stamp_temple_shrine` `site_planner.gd:1684` | **YES** |
| ground clutter, jungle flora | `scripts/world/ground_clutter.gd` | yes |

### THE ACTUAL HOLE — measured, and it is one line

**`plan_demo_world` explicitly ships ZERO first-signs:**
```
scripts/missions/mission_generator.gd:723-724
    var no_signs: Array[Vector3] = []
    p["first_signs"] = no_signs
```
The patrol planner sets them (`:624`) and `build_patrol_world:765-769` consumes them: a
`LARGE_EXPLOSION` terrain scar at intensity 0.8–1.3, 40 % of them filled with crater water. The
patrol planner's own comment (`:496`) places these at **"first-sign 150–300 m"** from the gate —
**exactly the Arbiter's "something to look at by 200 m."** The demo turned them off.

So the answer to "is the walk empty?" is: **it has motion and sound but no LANDMARK.** The one piece
of authored geography designed for that exact distance band is disabled in the demo plan by two
lines, and re-enabling it is a plan edit, not a system.

**What does NOT exist anywhere in code** (checked: no hits repo-wide for `trail_sign`, `tripwire`,
`arvn_body`, `burned_hut` placement logic) — these ADR-020 §2 beats are documented and unbuilt:
- fresh trail sign with a point-man callout
- a trip wire the point man catches
- a rotting ARVN body / burned hut as a placed landmark (`burned_hut` exists only as a collision
  table entry, `scripts/world/collision_table.gd:82`, `:218` — a model with no placer)

**MY RECOMMENDATION, cheapest first:** turn the demo's first-signs back on at 150–300 m and place
ONE `burned_hut` on the road bearing. Both are placement-only; neither is a new system. The point-man
callout is the expensive one and it is also the one ADR-020 flags as build-once-use-twice with
ADR-018 veterancy — park it.

**SACRIFICED:** craters and a burnt hut are texture, not a door. They buy the 200 m beat and nothing
more. A player who wants a THING to do at 200 m still has nothing until the village at 5:00.

---

## 4. MULTI-PAD HUEYS — THE WORLD SIDE

### The scheduler ALREADY EXISTS. Verify before proposing to build.

`AirTraffic` resolves pads from the firebase GLB by NAME PREFIX and builds one `LandingZone` per
match, each `capacity = 1`, and `_free_pad()` hands out the first free one:
- prefixes: `const FSB_PAD_PREFIXES := ["PSPHelipad", "fb_helipad"]` (`air_traffic.gd:59`)
- resolver: `_firebase_lzs()` (`air_traffic.gd:467-507`) — walks the whole fsb subtree, sorts by
  name for determinism, creates an LZ at each pad's `global_position`
- allocator: `_free_pad()` (`:510-515`)
- LZ_CYCLE profile: fly in, land, sit `PAD_HOLD` seconds, lift and depart (`:518+`)
- explicit failure log if no pad matches (`:504-506`)

**So a per-pad scheduler is BUILT. What is missing is PADS.**

### MEASURED: there is exactly ONE pad in the firebase

`tools/gen_firebase_v3.py:1070` places a single helipad:
```
pad_ob = place(masters["fb_helipad"], (12.0, 46.0), 0.6, rng)
```
and the station plan gives it 4 stations: `"fb_helipad": [("pad", 4, 6.0, 8.5)]` (`:638`).
The shipped GLB confirms it: four pad-prefix name matches, but they are the master, the placed
instance, its mesh and its `-colonly` collision twin — **one placement.**

**`air_traffic.gd:54-58` claims "measured: three 15×15 m PSP pads". THAT COMMENT IS WRONG** against
the GLB in the repo today, and it is a textbook drift case: a comment asserting a measurement that
the artefact does not support. Correct it on contact.

### THE MARKER WORK A PER-PAD SCHEDULER NEEDS

1. **Place 2–3 more `fb_helipad` masters in `gen_firebase_v3.py`** near `:1070`, on the same
   `place()` call, spaced ≥ 2× `lz_radius` (7.0, `air_traffic.gd:499`) apart — call it ≥20 m centre
   to centre so two birds never claim overlapping ground. Each also needs its `ribbon()` mud track
   (`:1074-1076`) or the new pads read as painted on grass.
2. **Re-export the GLB** (§5). Nothing else. The resolver picks them up by prefix automatically.
3. **A HAZARD to check before trusting more pads:** the resolver matches *every* node whose name
   begins with the prefix, including mesh children and `-colonly` twins (`air_traffic.gd:491-494`).
   Today that yields 4 LZs on 1 pad — three of them stacked on ground already occupied, so
   `_free_pad()` can hand a second bird the same square metre. **MEASUREMENT REQUIRED:** print
   `_pad_lzs` positions on boot and confirm distinct spacing; if they collide, the filter needs to
   exclude `-colonly` and non-leaf duplicates BEFORE more pads multiply the fault.
4. **Per-route jitter** is a frame-side question (the technical director's), not a marker question.

**SACRIFICED:** every extra pad is PSP mesh + mud ribbon + a bird that may occupy it, and this
project is call-bound (`production/PERF_LEDGER.md`, briefing §C). Pads are cheap; the *birds on
them* are not. The world side can deliver three pads for near-zero; the decision to fly three
airframes concurrently is not mine to make.

---

## 5. THE CHOW HALL WIRING — THE REAL REMAINING WORK

### 5a. Confirming the Arbiter's correction

Confirmed by mtime: `firebase_v3.1.blend` **Aug 3 22:58** vs `firebase_v3.1_RECOVERED_medical.blend`
**Aug 3 22:30**. The default at `tools/gen_firebase_v3.py:912`
(`blend = blend or os.path.join(gf.KIT_DIR, "firebase_v3.1.blend")`) points at the NEWER file.
**Do not repoint it.**

**`tools/gen_firebase_v3.py:1104` IS STILL STALE — CONFIRMED.** In `main()`:
```
tools/gen_firebase_v3.py:1104
    blend = os.path.join(gf.KIT_DIR, "firebase_v3.blend")
    bpy.ops.wm.save_as_mainfile(filepath=blend, compress=True)
```
`firebase_v3.blend` on disk is **2.26 MB, Jul 26 20:44** — versus 19.6 MB for the v3.1 line. That is
the pre-medical, pre-chow-hall generator output. **Running `main()` writes there and will not touch
the truth source** — which is safe, but means any generator change (e.g. the extra helipads in §4)
lands in a file nothing exports from. Whoever adds pads must reconcile `:1104` with `:912` in the
same change, or the pads exist in a dead .blend.

### 5b. THE REAL BLOCKER — nobody has re-exported the firebase since July 26

**Measured:** `fsb_main_v3.glb` mtime **Jul 26 22:27**. Zero `WB_chowhall`, zero `work_eat`, zero
`WB_medical` in its node names. `scenes/world/firebase_main.tscn:3` instances that exact GLB, and
`SitePlanner.FSB_MAIN_PATH` (`site_planner.gd:659`) loads that scene.

**Consequence nobody has stated yet: the MEDICAL COMPLEX has never been in the game either.**
`site_planner.gd:964-990` seeds a medic + patient at the aid station and conditionally a 3-man
litter team — off `work_medic` markers. The GLB carries exactly **four** medic markers
(`work_medic`, `.001`, `.002`, `.003`) from the old aid station. The medical complex Caleb built on
7/30 and recovered on 8/2 is not in the game and never was.

So the export is not one item on a chow-hall list. **It is the single act that ships two buildings.**

### 5c. THE `.001` HAZARD — the highest-value measurement in this whole analysis

`SitePlanner._ensure_fsb_markers` derives a work_type by trimming `work_` and then stripping a
trailing **`_<int>`**:
```
scripts/world/site_planner.gd:905-909
    var wt: String = String(nd.name).trim_prefix("work_")
    var cut: int = wt.rfind("_")
    if cut > 0 and wt.substr(cut + 1).is_valid_int():
        wt = wt.substr(0, cut)
```
**But the GLB's work markers carry Blender's dot form**, measured: `work_rest.001`, `work_watch.020`,
`work_supply.030`. Only the 14 first-of-family markers are bare. (The `_001` names the code was
written against — `SOCKET_A_001`, `FOOTPRINT_003` — come from a different emitter,
`legacy_garrison_markers()` at `gen_firebase_v3.py:770`, which writes the underscore literally.)

Godot forbids `.` in node names and strips invalid characters on import, so the imported names are
most likely `work_rest001` — from which `rfind("_")` returns −1 and **the suffix is never stripped**.

**If that is true, then today, in the shipped build:**
- `by_type` in `fsb_garrison_plan` (`site_planner.gd:944-952`) holds ~185 singleton junk types
  instead of ~14 real ones
- `FSB_WORK_OCCUPATION` (`:823-835`) matches only the 14 bare names; every other marker falls
  through to **`off_duty`** (`:1002`)
- the AID STATION SEED at `:969-978` requires `med_pool.size() >= 2`, but only ONE marker is named
  bare `work_medic` — **so the medic-and-patient seed never fires, and the litter team
  (`:986-990`, needs ≥3) has never fired either**

**I did not run the engine, so I do not assert it. SPECIFY THE MEASUREMENT:**
```
godot --headless --path . res://tests/test_firebase_garrison.tscn
```
and, decisively, a throwaway scene that prints the occupation histogram:
`SitePlanner.fsb_garrison_plan(Vector3.ZERO)["posts"]` → count by `occupation`.
**Read:** if `off_duty` dominates and `medic`/`patient` are absent, the strip is broken.
This is a five-minute measurement that decides whether the firebase interior is alive at all (§6),
and it must be taken **before** the re-export, so the before/after is interpretable.

### 5d. THE SECOND-ORDER EFFECT OF EXPORTING THE CHOW HALL

`_ensure_fsb_markers` reads **every** node starting with `work_` in the whole GLB
(`site_planner.gd:893-910`). The chow hall adds `work_eat` ×24, `work_chow_diner*` ×4,
`work_chow_server*` ×5, `work_chow_trigger`, `work_chow_exit`, `work_cook*` ×3 — roughly **+40**.

Those types are **not in `FSB_WORK_OCCUPATION`**, so they become `off_duty` (`:1002`), and unknown
types are appended to `type_order` after the priority list (`:960-962`) — but the round-robin's
FIRST pass visits every type (`:992-1008`), so **chow markers will take garrison men on round 0**.

**The garrison budget is fixed at 23** (`FSB_GARRISON_MAX_MEN` 40 − 17 curated,
`:853`/`:936`/`_fsb_curated_men` `:867-871`). Exporting the chow hall therefore **silently
reallocates existing garrison men to the mess benches as `off_duty` statues** — no code change, no
warning. That is the chow hall shipping as furniture with men frozen on it, which is worse than not
shipping it.

**So the REAL remaining work, ordered:**

1. **Measure the `.001` strip** (§5c) — everything downstream depends on it.
2. **Re-export** `fsb_main_v3.glb` from `firebase_v3.1.blend` via `gen_firebase_v3.py`'s
   `export_firebase()` default (`:912`). Ships the chow hall AND the medical complex.
   Check `scenes/world/firebase_main.tscn` still resolves — it carries `index="1259"` on its
   `SpawnMarkers` node (`firebase_main.tscn:7`), and the GLB gains ~136 objects.
3. **Teach `FSB_WORK_OCCUPATION` the chow types** — or, better, **exclude the chow families from
   the garrison round-robin entirely** and let the chow scheduler own them. A marker cannot serve
   two schedulers.
4. **`site_planner.gd` must expose the chow families as AI nodes** (handoff §"WHAT TO TARGET" 1) —
   under the **NEW LOCKED names** (`work_chow_diner*`, `work_chow_server*`, `work_chow_trigger`,
   `work_chow_exit`; `work_eat` ×24, `prop_seat` ×10, `work_queue` ×3, `line_step_*` unchanged).
   The handoff's own table shows the OLD names — read the correction at
   `HANDOFF_chowhall_godot_wiring_2026-08-03.md:98-108`, not the table at `:45-56`.
5. **A seat scheduler that HOLDS a seat** for the whole sit→eat→stand window, or two men share a
   bench (handoff `:80-82`).
6. **Idle phase stagger** for cook/server/collector — Caleb's explicit note that all idling men
   loop in lockstep (`handoff:69-72`). `SitePlanner._play_idle` (`site_planner.gd:571-579`) plays
   from frame 0 every time. **That is the fossil-shaped bug behind his complaint**, and it affects
   every idling prop in the game, not just the chow hall.
7. **Stopping a patrol to eat** (handoff `:83`) — SimClock-side, and the smallest of these.
8. **Correct `site_planner.gd:856`** ("191 markers (measured)" → 198) in the same change.

### 5e. THE THREE OPEN RULINGS, IN PLAIN WORDS FOR CALEB

> **(a) The names on the chow-hall markers.**
> Every spot in the mess hall — where a man queues, where he stands to get his food, which seat he
> sits in — is a named point in the Blender file. Right now those names live only in Blender. The
> moment the game's code starts reading them, renaming one silently breaks the mess hall and
> nothing warns us. You already picked the new names on 8/3
> (`work_chow_diner`, `work_chow_server`, `work_chow_trigger`, `work_chow_exit`).
> **The question is just: are those final?** Say yes and we write them into code today. Say
> "maybe" and we wait, because a rename after wiring costs a full re-export plus a code chase.
>
> **What it costs you to say yes:** the names are locked for the life of the project.
> **What it costs to wait:** the mess hall stays empty in the demo.

> **(b) The cook, the server, and the man who takes the trays — real soldiers, or furniture?**
> Option 1: they are three of your forty garrison men, pulled off the roster, and if the mess cook
> gets killed in the night attack, nobody serves breakfast. Option 2: the station is always manned
> — a cook is simply there whenever the mess is open, like a light that is on.
> **Option 1 is the game you keep describing** (the squad is people, and losing a man costs a verb).
> **Option 2 never breaks and never means anything.**
>
> **What Option 1 costs:** three of your twenty-three flexible garrison slots, permanently, and a
> hole in the world when they die. **What Option 2 costs:** the mess hall becomes scenery that
> happens to move.

> **(c) How many men eat at once?**
> The hall has 24 seats. In Blender the whole sequence has only ever been tested with ONE man
> walking it, so we know one man fits and nothing else. Somebody has to pick the number for the
> game — 5? 8? 12? — knowing that the more men, the more the queue spacing has never been proven
> and the more bodies the frame pays for.
> **The safe answer is 5**, because that is the number the Blender test was written for
> (`build(n=5)`, never run), and the number can go up after we look at it once.
>
> **What picking 5 costs:** a 24-seat hall that is mostly empty at midday. **What picking 12 costs:**
> a queue nobody has ever watched, on a frame budget that is already the project's top risk.

---

## 6. THE MIDDAY RETURN — IS THE INTERIOR WORTH COMING BACK TO?

### Verified alive inside the wire today

| thing | pointer |
|---|---|
| **198 work markers** in the GLB | **measured this session**; the round-robin that spends them is `site_planner.gd:938-1011` |
| up to **40 garrison men**, curated posts + work posts | `FSB_GARRISON_MAX_MEN = 40` (`:853`); 17 curated (`FSB_GARRISON_POSTS`, `:793-807`), remainder capped at 24 (`FSB_WORK_POST_CAP`, `:863`) |
| garrison men run **SimClock hour-driven occupations**, sleep in quarters, walk between quarters and post | `mission_generator.gd:877-935`; quarters `site_planner.gd:811-813`; schedules `scripts/ai/civilian_schedules.gd` |
| **sentry shifts alternate** so the wire is not empty after dark | `site_planner.gd:1003-1005` |
| **aid station seeded with a medic AND a patient** — deliberately, so the medic does not mime surgery on dirt | `site_planner.gd:964-978` |
| **litter team** carrying a wounded man across the compound, but ONLY when the ward is above its floor | `site_planner.gd:979-990`, `scripts/world/litter_team.gd:45`; ledger `campaign_state.gd:60,65,266-270` |
| armorer's bench just inside the wire (ADR-018) | `mission_generator.gd:794-799` |
| mortar pit with crew-station markers, set square to the gate axis | `mission_generator.gd:801-808` |
| mannable M60 emplacements | `MGEmplacement.create`, `mission_generator.gd:960-961` |
| parapet + structure destructibles wired across the compound | `site_planner.gd:1433-1531` |
| claymores on the wire | `site_planner.gd:1577` |
| stand-to: every garrison civilian promotes 1:1 to a fighting `AllyBase` | `field_director.gd:1359-1378`, `scripts/allies/garrison_defender.gd:26` |

### THE VERDICT ON §6

**Yes — the interior is the most densely authored space in the game, and it is the ONLY place with
a casualty ledger that changes what you see.** A litter team crossing the yard at midday because
YOUR men got hurt on the morning patrol is the single strongest atmosphere beat in the build
(`site_planner.gd:979-984` says exactly this), and it is already conditional on the real ledger.

**But two things must be true before it earns a midday return, and I can only assert one:**

1. **The chow hall must actually be in the GLB.** Measured: it is not. Without it, midday inside the
   wire is the same 198 markers the player already walked past at 0700 — and ADR-020 §4's Ambience
   Law means none of it demands anything of him. **The chow hall is the one thing that makes the
   return a DESTINATION rather than a lap.** That is the strongest argument in this document for
   prioritising the re-export.
2. **The work-marker types must actually resolve** (§5c). If the `.001` strip is broken, most of
   those 40 men are `off_duty` standing at markers whose job the game could not read, the aid
   station has no patient, and the litter team has never once crossed the yard. **Everything in the
   table above that makes the return worth taking hangs on a measurement nobody has taken.**

**SACRIFICED by making the midday return load-bearing:** the demo acquires a soft rail. ADR-020 §3's
binding test asks *can the player turn around and leave?* — and the answer must stay yes. If the
chow hall becomes the only way to refill satchels or get bandages, the return is a gate and Pillar 3
is broken. **The return must be worth taking and safe to skip.** Feed him, let him watch the litter
team, let a man on the mess line say something about the morning — and let him walk straight back
out the gate having eaten nothing, with the game saying nothing.

---

## 7. LAW 2 — WHAT THIS ANALYSIS SACRIFICES, PLAINLY

- **Guaranteeing the informer** turns "the village saw you" from emergence into authorship. Licensed
  by ADR-020 §2 for a first patrol, and a demo is one long first patrol — but the licence expires
  the moment this pattern is copied into the campaign generator.
- **Re-enabling first-signs at 150–300 m** buys the 200 m beat with craters. Craters are texture, not
  a door (ADR-020 §3). The walk gets something to look at and still nothing to DO.
- **More pads** costs mesh, mud ribbons and — if birds actually fly them — draw calls on a
  call-bound frame. World side is cheap; the airframes are not.
- **Adding the VC camp to the demo plan** costs the temple its bearing, or costs a third bearing on
  a 512 m map that already holds a firebase, a village and a temple. Something gets crowded.
- **Wiring the chow hall** spends garrison slots and frame on men who are eating instead of
  fighting, and locks a marker vocabulary for the life of the project.
- **Not wiring it** leaves 19 authored animation clips and a fully built, tented, sited building
  sitting in a .blend that has never been exported — and leaves the midday return with no reason
  to exist.
