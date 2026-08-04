# DEVIL'S ADVOCATE — 2026-08-03 — THE DEMO DAY RESCOPE

Every objection below carries a `file:line`. Law 2 binds me: each one names what I would sacrifice
instead. I attack the **Arbiter's shape**, never the Summoner's rulings.

---

## 0. HEADLINE

**The day arc is not a rescope of the demo. It is a new game mode wearing the demo's name — and the
single biggest reason is not content, it is that THE SUN DOES NOT MOVE IN THIS ENGINE.** Two of the
Arbiter's three load-bearing assumptions (a felt daylight arc; a 2.5-minute walk to the village) are
contradicted by shipped code. A third (the 48 FPS ceiling) was measured in a configuration that the
proposal does not describe.

---

## 1. THE SCOPE LIE

### 1.1 THE SUN IS A FOUR-STATE STEP FUNCTION. "One full day" is not renderable today.

`scripts/world/mission_weather.gd:20-25` — `TIMES` holds exactly **four** entries (DAY / DAWN / DUSK /
NIGHT), each a fixed `sun_x`, `energy`, `sun_color`, `ambient`. `_apply_time` is called from
`_on_time_period_changed` (`:77-83`), which fires **only on a `SimClock.Period` crossing**, and eases
over `TIME_EASE_SECONDS = 6.0` (`:41`).

`SimClock.period_at` (`scripts/autoload/sim_clock.gd:55-59`) puts DAY at `7.0 <= h < 17.0`.

**Therefore a 0700 → 1900 day contains exactly TWO lighting events**: the opening snap to DAY, and one
DUSK crossing at 17:00. For ~20 of the 23 minutes the sun sits at **one fixed pitch with one fixed
energy** — no shadow travel, no colour walk, no arc. The player's *only* evidence that a day passed is
the toast text and the final dusk flip.

**The r4bk Law is explicit: a feature without a visible affordance does not exist.** By that law, the
day arc — the entire premise of this rescope — **does not exist**. The Arbiter is about to spend 4x
the demo's content budget on a clock the renderer cannot show.

- **Cost to make it real:** a continuous sun driver (lerp `sun_x`/`energy`/`sun_color`/`ambient`/fog
  colour off `SimClock.sim_hour` instead of off the period signal). This is a small file
  (`mission_weather.gd`) but it touches `sight_cap.gd:25`, `MissionWeather.is_night`, and the tracer
  brightness path — all of which currently read a **period enum**, not an hour. Call it a day of work
  plus a fresh perf row (a moving sun changes nothing about shadows, since `game_world.gd:48` ships
  `shadow_enabled = false`, so this is cheap in frame cost and NOT cheap in blast radius).
- **WHAT I SACRIFICE INSTEAD:** if we will not build the continuous sun, cut the day to **two beats**
  (morning sortie, afternoon sortie) and stop calling it a day. Sell the *dusk fall* — the one
  transition the engine actually renders — as the demo's clock, and put the 4x content budget into
  the village instead.

### 1.2 THE MAP IS PHYSICALLY TOO SMALL FOR THE BEAT SHEET.

- Demo map: **512m** (`scripts/main/game_flow.gd:551`), firebase dead centre
  (`mission_generator.gd:686-688`) → **256m to every edge**.
- Village: **185m from `fsb_center`** (`mission_generator.gd:709`), fallback 165m (`:712`).
- Parapet reaches **96.1m radius** (`demo_game.gd:293-295`, citing `firebase_v3_destructibles.json`).
- Player: `WALK_SPEED 5.0`, `SPRINT_SPEED 8.0` (`scripts/player/player.gd:5-6`).

**So the gate-to-village walk is ~90-120m — twenty to twenty-five seconds at a walk.** The Arbiter's
beat sheet reserves **1:30 → 5:00** for it. To fill 3.5 minutes at walking pace you need **~1000m of
route**, which does not exist inside a 512m box whose centre is 256m from the edge and whose siege
assembly ring already reaches `ring_max 235.0` (`demo_game.gd:288`).

**Growing the map is not free**: the siege geometry at `demo_game.gd:286-296` is hand-tuned to 512m
("the kilometer-AO defaults spawn cells OFF the 512m map"), the road network, the paddy stamper and
`FSB_SITE_CLEARANCE` all re-roll, and every perf number in `PERF_LEDGER.md` was taken at 512m or at
the full-game 1280m — never at an intermediate.

- **WHAT I SACRIFICE INSTEAD:** keep 512m and **stop trying to spend minutes on walking**. The 23
  minutes must be spent on *contact and decision*, not distance. That is a better demo anyway (see §2).

### 1.3 THE ENEMY CAMP DOES NOT EXIST IN THE DEMO WORLD.

Ruling 4 says "two areas: one village, one enemy camp." The demo plan ships:
`mission_generator.gd:714` village · `:717-721` a **TEMPLE** · `:739` **`p["camp_centers"] = no_camps`**
· `:738` **`p["ambush_sites"] = no_ambush`** · `:724` **`p["first_signs"] = no_signs`**.

The builder path exists (`mission_generator.gd:763` `"vc_camp": planner.stamp_vc_camp`), so adding it
is cheap — but **the backlog does not list it and nobody has ever booted the demo with a camp in it.**
Camp population comes with `camp_director` role schedules that read `SimClock.sim_hour`
(`scripts/enemies/camp_director.gd:88,112-116`) — untested at a 31x ratio.

### 1.4 THE HONEST HOUR COST — enumerate what a 23-minute daylight patrol needs that the shipped demo does not have

| # | Required by the shape | Shipped state (pointer) | Honest cost |
|---|---|---|---|
| 1 | A felt daylight arc | 4-state step (`mission_weather.gd:20-25,77-83`) | ~1 day + a perf row |
| 2 | Enemy camp as a second area | `mission_generator.gd:739` `no_camps` | ~0.5 day code, unknown Blender |
| 3 | Destructible tunnel mouth | zero hits repo-wide for a tunnel-mouth destructible | ~1 day (Blender + `Destructible` wiring) |
| 4 | Proactive hunters on the walk-out | `field_director.gd:113-119` reactive only | ~0.5 day (see §5) |
| 5 | "3 RTO fire missions" | grants **7** (`field_director.gd:1251-1255`) | 1 line + a ruling |
| 6 | Midday return that is not an AAR | `field_director.gd:1223-1224` → `_bank_patrol:1564` | ~0.5 day |
| 7 | Multi-pad Hueys | `AirTraffic.launch` single dispatch, no pad markers in the Blender firebase | ~1 day + HIS Blender |
| 8 | Degraded revive | `health_system.gd:276-278` restores FULL HP | 1 line + a ruling |
| 9 | Chow-hall wiring | `build(n=5)` never run; nothing in Godot | ~1 day + his Blender |
| 10 | Village-as-eyes (being-seen economy) | no "seen" state feeds `SIEGE_STRENGTH` today | ~1 day |
| 11 | Day → night arithmetic + its two RTO lines | `demo_game.gd:48` is a `const int` | ~0.5 day |
| 12 | A 30-minute soak that nobody has ever run | never done | ~0.5 day of measurement alone |

**≈ 8-9 agent-days of code, PLUS at least three of his Blender sessions, PLUS an unknown number of
his playtests** — against a demo whose stated remaining bottleneck as of 7/31 was *"HIS playtest"*
(`DEMO_SHIP_BACKLOG.md:29-31`) and whose ship target was **8/9**
(`DEMO_SHIP_BACKLOG.md:317-319`).

**VERDICT: this is a NEW GAME MODE, not a rescope.** The night siege is ~15% of it. Say that out loud
to the Summoner in the decision queue, because the 8/9 date is a ruling he made against a different
object.

- **WHAT I SACRIFICE INSTEAD (my actual counter-proposal):** ship the **DUSK PATROL**. One sortie out
  at ~16:00, one village, contact, the dusk fall on the walk back, stand-to, attack. That is ~15-18
  minutes, uses the ONE lighting transition the engine renders, needs no map growth, needs no camp,
  needs no midday return, and preserves ruling 1 (a real 15-30 min game), ruling 3 (spawn, form up,
  birds lifting), ruling 4 (village, and the camp becomes the stretch), ruling 5 (3 calls), ruling 9
  and ruling 10 intact. **What it costs: the chow hall does not ship in the demo, and the "full day"
  fantasy is deferred to the full game where the map is 1280m and the sun can be built properly.**

---

## 2. THE 5-MINUTE RULE VS THE BEAT SHEET — I attack the Arbiter hardest here

The beat sheet spends **1:30 → 5:00 walking**. His law: *"if a player isnt hooked by the first 5
minutes than the game isnt for them."*

Three separate problems, all pointered:

1. **The walk cannot physically last that long** (§1.2). To make it last, you must artificially slow
   the player or lengthen the route. Both are the same crime: **padding presented as pacing.**
2. **Nothing can happen during it.** The hunt net is double-gated: `_check_detection` (`:113-119`)
   arms only on a COMBAT contact, and even once armed `_process_escalation` **returns at `:143-145`
   when `evidence.best_fix()` is empty** — and the ledger is only fed by `_on_noise_evidence`
   (`:35-38`), i.e. by the player *shooting*. A player who has not fired has an empty ledger. Then
   `_hunter_timer = randf_range(70.0, 110.0)` (`:118`) delays the first spawn another **70-110
   seconds**. **Nothing in the AO can touch him during minutes 1:30-4:00. By construction.**
3. **The only content in that window is scenery**, and scenery is the one thing this project has
   already shipped — `AIR_OPENING` (`demo_game.gd:105-112`) puts birds up at 3s/14s/26s/48s and
   `AMBIENT_WAR` is on (`:22`). **The birds are already the hook, and they land in the first 30
   seconds.** Spending minutes 1:30-4:00 walking *after* the hook has fired is the classic bounce
   shape: peak at 0:30, trough at 3:00.

**The Arbiter's own briefing concedes it** at question G: *"exactly the stretch the 5-minute rule
cannot afford to leave empty."* He named the hole and then kept the walk.

- **MY OBJECTION:** minute 1:30-5:00 must contain a **contact or a decision**, not a commute. Put the
  village at contact range, or open the day already outside the wire.
- **WHAT I SACRIFICE:** the "walk out and see the AO breathe" fantasy — Pillar 2 atmosphere loses its
  slow reveal. I accept that: atmosphere is already carried by the sky package and the ambient war
  audio (`DEMO_SHIP_BACKLOG.md` D3), both of which work while the player is *doing* something.

---

## 3. THE 30-MINUTE UNTESTED SURFACE

**Nobody has ever run this build for 30 minutes.** The longest measured run in the repo is
`--print-fps` at **150 s** (`DEMO_SHIP_BACKLOG.md:339-340`). The demo's own arc ends at
`DAWN_AT_S = 420.0` (`demo_game.gd:35`). **We are proposing a 4x extension of an object whose longest
observed lifetime is 2.5 minutes.**

What I found that accumulates or degrades:

1. **`EnemyBase.unreported_corpses` — an unbounded STATIC array with an O(n·m) scan.**
   `scripts/enemies/enemy_base.gd:961` declares `static var unreported_corpses: Array[Vector3]`;
   `:1011` appends on every death; entries are removed **only** when a living, non-COMBAT enemy walks
   within range (`_check_corpse_discovery`, `:1022-1031`), and that function is called from the
   **witness heartbeat on EVERY unit** (`:804-807`). Clear a village with nobody left alive to find
   the bodies and those coordinates persist for the rest of the run. It is cleared only at
   `FieldDirector.setup` (`:22`) — i.e. once per world build. At ~80 daytime kills and ~100 live
   bodies at night this is a per-heartbeat scan that a 7-minute demo never paid for.
   *Sacrifice to fix: cap or TTL the array (physical evidence already has `DECAY_PHYSICAL_S = 900.0`
   in `scripts/enemies/evidence_ledger.gd:23` — copy that). Cost: a corpse can go stale before
   anybody finds it, which slightly weakens the stealth economy.*
2. **The evidence ledger itself is FINE — do not "fix" it.** `evidence_ledger.gd:75-79` `prune()` is
   called every escalation tick (`field_director.gd:142`), decays are 240s noise / 900s physical
   (`:22-23`), and fixes merge inside `MERGE_M 40.0` (`:31`). **This one is bounded.** Pointer given
   so the council does not spend an hour on it.
3. **Corpse MESHES are fine** — freed at 45s (`enemy_base.gd:2662, :2720`).
4. **Decals are fine** — FIFO at `MAX_DECALS 48` (`scripts/combat/gun_fx.gd:69`, enforced `:753-756`).
5. **`_live_enemies` is fine** — erased on death (`field_director.gd:96`) and despawn (`:75`).
6. **The unmeasured one: `AgentRegistry.props` swept on EVERY explosion**
   (`DEMO_SHIP_BACKLOG.md:27` citing `combat_manager.gd:178`). 178 interior props
   (`DEMO_SHIP_BACKLOG.md:336-338`) + 80 parapet segments. In a 7-minute demo the explosion count is
   the siege air beats (7, `demo_game.gd:163-171`). In a 30-minute demo with 3 RTO fire missions,
   grenades, an M79 and a full night, it is hundreds. **This is a per-explosion O(props) sweep and it
   has never been profiled.**

**THE MEASUREMENT I DEMAND BEFORE ANY OF THIS IS BUILT** (it costs one unattended run, not a session):

```
build/RECON_Demo.exe -- --print-fps
```
run for **1800 seconds unattended**, player parked inside the wire, logging every 30 s:
`Performance.get_monitor(OBJECT_NODE_COUNT)`, `MEMORY_STATIC`,
`RenderingServer.get_rendering_info(RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)`,
`EnemyBase.unreported_corpses.size()`, `FieldDirector._live_enemies.size()`,
`AgentRegistry.props.size()`. **A flat node count and a flat draw call count is the pass. A rising
one names the leak.** Nothing in this council should cost-estimate a 30-minute demo before this run
exists.

---

## 4. NO SAVE + FAIL FORWARD

**The fail-forward system EXISTS and is complete.** I went looking for the hole the brief predicted
and did not find it:

- `scripts/player/health_system.gd:248-286` — `revive_handler`, `is_downed`,
  `DOWNED_BLEED_SECONDS 30.0`, `_die()` intercepts death when `can_revive()`.
- `scripts/squad/squad_system.gd:102` — SquadSystem assigns itself as the handler at squad build.
- `:224-232` `can_revive()` (needs a live MEDIC + a bandage, with a restock from a nearby
  `FieldCache.MEDICAL` at `:235-245`).
- `:292-307` `begin_revive()` — VO, "MAN DOWN! DOC IS MOVING TO YOU", drops the medical box.
- `:313-345` `_process_revive()` — Doc paths in on `OrderMode.RESCUE`, channels
  `maxf(2.5, 5.0 - medic_skill*0.4)` at ≤2.8m, then `_health.revive()`.
- `health_system.gd:210-218` — a body hit on a downed player **burns 6 s of window instead of killing
  him** (`pressure_revive`).
- Budget: `MEDIC_BANDAGES = 6` (`squad_system.gd:10`).

**So the ruling does NOT rest on vapour. It rests on two live contradictions:**

### 4.1 HIS 8/3 RULING CONTRADICTS HIS OWN 7/18 DECREE.

`health_system.gd:276-278`:
```gdscript
func revive() -> void:
    is_downed = false
    current_hp = max_hp
```
The comment above it (`:274-275`) cites **his own decree of 2026-07-18: "back on your feet AT FULL
HEALTH — a half-restored revive reads as still-dead."** His 8/3 ruling says *"you come back
degraded."* **Only he can break this tie, and it must go in the decision queue verbatim.** Do not let
an architect pick one.

### 4.2 THE HEADSHOT DEFEATS FAIL-FORWARD ENTIRELY — and in a no-save 30-minute demo that is the ship risk.

`health_system.gd:200-208`:
```gdscript
if Hitzone.zone_name_is_fatal(zone):
    ...
    force_death()   # bypasses the medic revive window, deliberately
```
The comment says it out loud: *"It bypasses the difficulty scalar AND the medic revive window."* This
is his own 7/27 ruling (memory: *headshots kill EVERYONE*) and ADR-016 Amendment D.

**Compose that with NO SAVE and a 30-minute run.** One rifle round to the head at minute 22 costs the
player 22 minutes, and the only button on the end card is `"RESTART THE NIGHT"` (`demo_game.gd:350`)
which calls `get_tree().reload_current_scene()` (`:362-364`) — **a full rebuild from minute zero.**

**The demo's own smoke test already proved how fast this happens:** *"unattended player KIA at 70s"*
(`DEMO_SHIP_BACKLOG.md:330`). Seventy seconds. The fail-forward budget of 6 bandages is irrelevant
when the terminal event routes around the medic entirely.

Pillar 5: *"death matters, but this is not a sadism simulator."* **A 30-minute no-save run with an
un-mitigated instant-death channel is the sadism simulator.**

- **WHAT I SACRIFICE INSTEAD, three options, cheapest first:**
  1. **A checkpoint at the wire** — the midday return is already a natural one
     (`field_director.gd:1223`). Costs: his NO SAVE ruling, which is why I list it and do not push it.
  2. **Helmet saves one headshot per run.** One flag on the player, one toast, one dented-helmet
     sound. Costs: the headshot law's absoluteness, but only for the *player*, only *once*, and only
     in the *demo*. **This is my recommendation.**
  3. **Nothing** — and accept that some fraction of players will lose 20+ minutes to one round and
     never restart. Costs: the demo's word-of-mouth, which is the demo's entire job.

---

## 5. THE INVISIBLE-CONSEQUENCE TRAP — push harder

The Arbiter says an invisible consequence is no consequence and proposes two RTO lines. **I say the
link may be MECHANICALLY NULL at the top end, not merely invisible.**

- `LIVE_CAP = 50` (`siege_director.gd:36`).
- `_enforce_live_cap` (`:440-446`) **freezes** un-materialized cells at the ring once 50 men are live,
  and prints `"cell of %d held at the ring"`.
- `_light_check` (`:427-437`) enforces the same cap on the illumination door.
- `SIEGE_STRENGTH` is currently **45 and not 50** *precisely because* an assault authored at the cap
  trickles (`demo_game.gd:44-47` — the 2026-07-28 failure).

**So the Arbiter's sketch of `55` for a bad day sits ABOVE the cap that already broke this system
once.** At 55, ten men are authored and some fraction of them **never materialize** — the player is
"punished" with bodies that do not exist. The 35/45/55 arithmetic is not a gentle 3-step dial; **the
top step re-enters the known failure mode.**

And can a player tell 35 from 55 at night? Consider what he can actually perceive: night sight is
**56m open** (`DEMO_SHIP_BACKLOG.md:141`), the assault crosses from **190-235m**
(`demo_game.gd:287-288`), and the compound is lit in **~55 s bursts with ~15 s of darkness between**
(`GARRISON_ILLUM_BURN_S 55` / `ILLUM_INTERVAL_S 70`, `DEMO_SHIP_BACKLOG.md:145-147`). **He sees a
strobing 180m disc of a 4-squad assault spread over 150° of arc.** Counting bodies is not on offer.
What he *can* perceive is **duration** and **whether they get inside the wire** — the overrun call
already exists (`siege_overrun` at `OVERRUN_MEN 3`, `DEMO_SHIP_BACKLOG.md:126-128`).

- **MY OBJECTION:** do not build the link as a strength number. **Build it as a BREACH number** — a
  clean day means the wire holds, a dirty day means they get inside. That is binary, visible, already
  wired to a siren, and it is what a player will actually retell.
- **WHAT I SACRIFICE:** the designer's satisfying 35/45/55 gradient. Good riddance — it is
  arithmetic nobody can read.
- **If the council insists on the strength number: cap it at 45 and let the CLEAN day drop to 35.**
  Never author above the number that already trickled once.

---

## 6. THE DOCUMENT-VS-CODE GAP — spot-check of `DEMO_SHIP_BACKLOG.md`

Five checks, chosen from its most load-bearing claims:

| Claim | Pointer | Verdict |
|---|---|---|
| C4: siege trigger is `OS.is_debug_build()`-gated | `scripts/main/game_flow.gd:50` — `if not OS.is_debug_build() or not _in_world:` | **TRUE, still open** |
| C3b: one merged `bwire_card_ring` | `tools/gen_firebase_v3.py:368,373` — one mesh, one object | **TRUE, still open** |
| A1: clamp raised to 12m | `scripts/ai/nav_router.gd:37` — `const CLAMP_MAX_M: float = 12.0` | **TRUE, shipped** |
| E5: `Base_Human` special-cased in code | `scripts/visuals/model_actor.gd:546` — `const BASE_BODY_MESH: String = "Base_Human"` | **TRUE, still patched** |
| W7: garrison 40 / work post 24 | `scripts/world/site_planner.gd:853,863` | **TRUE, shipped** |

**Current false-claim rate on this document: 0/5.** The 7/31 audit banner
(`DEMO_SHIP_BACKLOG.md:14-44`) did its job and the doc is now honest about what it once lied about.

**BUT — and this is the finding — the document's last update is 7/31 evening (`:324`), and NOTHING in
it names the chow hall loop, the tiered expansion, the medical-complex recovery, or the 32 orphaned
animation clips.** It is not stale-wrong; **it is incomplete.** Any cost estimate this council draws
from it will **UNDER-count**, which is the more dangerous direction for a 4x rescope. Its remaining
line reads *"REMAINING FOR 8/9: his bench (S1/S2/S3), his 45-min playtest, M60 bench row, playthrough
#2"* (`:345-346`) — **a list that assumes the 7-minute demo.**

---

## 7. THE LANDMINES NOBODY NAMED

### 7.1 THE MIDDAY RETURN FIRES THE AAR — and resets the mission clock.

`field_director.gd:1223-1224`:
```gdscript
elif patrol_out and d < WIRE_RETURN_M:
    patrol_out = false
    _bank_patrol()
```
`WIRE_RETURN_M = 95.0` (`:954`), `WIRE_GATE_M` outbound at 120 (`:1207`). **The Arbiter's "return
through the wire at midday" walks straight into `_bank_patrol` (`:1564`)**, which:

- emits `"BACK INSIDE THE WIRE - PATROL 1 LOGGED, N KILLS"` (`:1578-1579`) — a **debrief** toast, in a
  demo where `EXCLUDE_DEBRIEF := true` (`demo_game.gd:20`);
- may emit `"FIELD PROMOTION: ..."` (`:1572-1573`) — campaign progression, mid-demo;
- calls `CampaignState.commit_mission()` (`:1577`);
- and at **`:1584` REPLACES `state` with a fresh `MissionState`**, resetting `start_time_ms` (`:1587`).

### 7.2 THEREFORE QUESTION D IS MOOT. The hunt decay never runs.

`field_director.gd:130-133`:
```gdscript
var mins: float = state.elapsed_seconds() / 60.0
field_mult = clampf(1.0 - (mins - 15.0) * 0.02, 0.6, 1.0)
```
It reads `state.elapsed_seconds()` — **and `state` is destroyed and re-created at every inbound wire
crossing (`:1584`).** In the Arbiter's own 3-excursion shape **no excursion reaches 15 minutes**, so
`field_mult` is pinned at 1.0 and the decay **never fires**.

**The council is being asked to debate whether to invert a decay that is dead code in the proposed
shape.** Do not invert it. Either delete it (FOSSIL LAW) or move its clock off `state` and onto a
world-lifetime timer — and if you move it, you have just made the decay *live for the first time*,
which is a behaviour change nobody has playtested.

- **WHAT I SACRIFICE:** the "the AO leans on you harder the longer you're out" fantasy. It has never
  actually happened in a shipped patrol either, for the same reason.

### 7.3 "3 RTO FIRE MISSIONS" IS NOT WHAT THE CODE GRANTS. It grants seven.

`field_director.gd:1251-1255`:
```gdscript
fire_support = {
    "bombs": 1, "napalm": 0, "arty": 1,
    "mortar": 3 + (1 if fo >= 6 else 0), "spectre": 0, "cbu": 0,
    "illum": 2 + (1 if fo >= 4 else 0),
}
```
That is **3 (or 4) mortar + 1 bomb + 1 arty + 2 (or 3) illum = 7-9 calls**, escalating to include
napalm/CBU/Spectre at HIGH/CRITICAL threat (`:1256-1260`). His ruling — *"first one you gotta assume
most players will just do it to do it and then they will use the other two wisely"* — **only produces
its intended psychology at THREE.** At seven, the scarcity that makes call #2 and #3 feel like
decisions evaporates.

Also note `_grant_fire_support` is latched **one allotment per sim DAY** (`:1241-1245`, keyed on
`_sim_day()`), which at ~31x never rolls in 30 real minutes — so the midday re-exit correctly grants
nothing. **That part works. The count does not.**

- **RULING NEEDED FROM HIM:** is "3 fire missions" *three mortar missions* (illum and air separate),
  or *three calls of any kind*? One line of code either way; the wrong reading breaks his stated
  psychology.

### 7.4 LIVE_CAP DOES NOT CAP THE WORLD — it caps the SIEGE ONLY. Question F is worse than posed.

`_enforce_live_cap` (`siege_director.gd:440-446`) and `_light_check` (`:427-437`) both iterate
**`cells`** — the siege's own marching cells and nothing else. **Outside that cap entirely:**

- the garrison: `FSB_GARRISON_MAX_MEN = 40` (`scripts/world/site_planner.gd:853`),
  `FSB_WORK_POST_CAP = 24` (`:863`);
- the hunt net: `_hunter_pool = 12` (`field_director.gd:106`);
- the player's squad (7) + village defenders 3-4 (`mission_generator.gd:730-731`) + treeline watchers
  3-5 (`:735-736`) + 2-3 ambient LazyGroup patrols of 2-4 (`:772-781`).

**Peak concurrent bodies in the proposed shape ≈ 45 + 40 + 12 + 7 + ~14 = ~118.** The W7 A/B that
produced **48.0 FPS** (`DEMO_SHIP_BACKLOG.md:339-340`) was 150 s on the 7-minute demo, where the hunt
net had **never armed** (no daytime contact → no evidence → no hunters, per §2) and the daytime groups
were largely unspawned LazyGroups.

**The 48 FPS number does not describe this configuration and must not be quoted as if it does.** The
one hard datapoint we have on this class of load is `PERF_LEDGER.md:299` — at **65-67 live units the
AI physics wall is ~38-40 ms per physics tick**, i.e. already past a 30 Hz budget on CPU alone, before
any of the day's extra bodies.

**THE MEASUREMENT, EXACTLY** (nobody has taken it; do not guess a number):

1. Scene: `build/RECON_Demo.exe -- --print-fps` (the exported build, not the editor —
   `DEMO_SHIP_BACKLOG.md:325-327`).
2. Force the configuration that has never existed: fire `[J]` (siege) **while** the hunt net is armed.
   Since `[J]` is `OS.is_debug_build()`-gated (`game_flow.gd:50`), this needs a debug build **or** the
   demo's own arc plus a scripted contact — say so rather than assuming the exported build can do it.
3. Read, at 10 s intervals across the whole siege:
   `CombatManager.bodies_run` / `bodies_gated` (the census added by WA-A2, `PERF_LEDGER.md:325-326`),
   `CombatManager.ai_usec_*` buckets, `RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME`, and the
   `"[Siege] cell of N held at the ring"` line (`siege_director.gd:445-446`) — **a single occurrence
   of that print during the run means the assault is trickling again.**
4. Compare against the same run with the hunt pool forced to 0. **That delta is the price of ruling 9.**

### 7.5 MULTI-PAD HUEYS COLLIDE WITH THE ONE MEASURED CEILING.

`AIR_MAX_IN_SKY = 14` (`demo_game.gd:117`) with its own comment: *"this project is CALL-BOUND, and a
nine-ship pack is nine sets of rotor meshes."* `FORMATION_SIZES` puts **6-9 Hueys** up per transit
(`DEMO_SHIP_BACKLOG.md:23`). **Two concurrent pad cycles plus one ambient transit already exceeds 14.**
The ledger's only ranked lever is the canopy at **+6.3 FPS for 70% of draw calls**
(`PERF_LEDGER.md:695-705`) — meaning draw calls *are* the currency, and airframes spend it.
- **WHAT I SACRIFICE:** stagger the pads so **only one is ever in its loud phase**, and accept that
  "several pads" reads as *sequential* rather than *simultaneous*. The player cannot look at two pads
  at once anyway.

### 7.6 THE 23-MINUTE DAY BREAKS THE CIVILIAN AND CAMP SCHEDULES' ASSUMPTIONS.

Every civilian behaviour and every camp role is keyed to `sim_hour` bands
(`scripts/ai/civilian_schedules.gd:28-231`, `scripts/enemies/camp_director.gd:88,112-116`), and
`_bt_work` walks a man to a marker and **holds** (`DEMO_SHIP_BACKLOG.md:64-74`). At ~31x a sim hour is
**~116 real seconds** — so a villager arrives at his post and stands there for two real minutes before
the next schedule tick. At the demo's current 110x it is 33 s and reads as bustle. **Slowing the clock
makes the village LESS alive, not more.** Nobody has looked at a village at 31x.

- **WHAT I SACRIFICE:** either accept a stiller village, or add per-man jitter inside the hour band —
  another unbudgeted job.

---

## 8. WHAT I WOULD SHIP (the whole sacrifice, stated once)

**Ship the DUSK PATROL at ~18 minutes, not the DAY at 30.**

- **KEEP:** spawn + form up + birds on the corner turn (ruling 3 — already built,
  `demo_game.gd:105-112`); one village that is the enemy's eyes; 3 fire missions; the hunt net armed
  by an ambient cell; fail-forward with the medic; the dusk fall; stand-to; the attack.
- **CUT:** the midday return (and with it the chow hall's demo debut), the enemy camp as a second
  area, the 23-minute daylight, the multi-pad simultaneity, and the 35/45/55 gradient.
- **ADD ONE THING NOT ON ANYONE'S LIST:** the helmet that eats one headshot. Without it the no-save
  ruling and the headshot law compose into a demo that punishes 20 minutes of good play with one
  round, and Pillar 5 forbids exactly that.
- **WHAT THIS SACRIFICES, named plainly:** the chow hall does not appear in the demo, the "full day"
  is deferred to the full game where the map is big enough and the sun can be built to move, and the
  demo's runtime lands under his 30-minute benchmark. **I would rather ship 18 honest minutes on
  8/9 than 30 padded ones in September.**
