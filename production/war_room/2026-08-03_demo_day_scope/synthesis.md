# THE DECREE — 2026-08-03 — THE DEMO DAY RESCOPE

**Convened:** the Overseer/Director as Arbiter, at the Summoner's direction.
**Council:** game-designer · systems-designer · technical-director · ai-architect ·
level/world-architect · devil's-advocate. Six independent analyses, no cross-talk, code only.
**Standing:** the Summoner's ten rulings (briefing §0) are DECIDED and were not re-litigated.

---

## 0. THE ONE-PARAGRAPH DECREE

Three architects who never spoke to each other found the same wall: **the sun does not move.**
Lighting is a four-state table that changes only when the sim clock crosses a period boundary
(`mission_weather.gd:20-25`, `:77-83`), and DAY is a single flat block from 07:00 to 17:00. The
Summoner's "one full day" cannot be rendered as a day — **but it can be rendered as an ARC ACROSS
ALL FOUR LIGHTING STATES**, which is a better demo than the one the Arbiter proposed and costs no
new lighting code. Therefore: **spawn at 06:30 in dawn light, cross into DAY as you clear the gate,
run the day at ~38x, cross into DUSK on the afternoon return, cross into NIGHT at stand-to, and
run the assault SLOW at ~20x so it never crosses midnight** — because midnight rollover re-arms a
second siege roll, unlatches the fire-support allotment, and raises the sun mid-attack. The demo
gets four hard lighting events, one per act, in a 30-minute runtime the Summoner already ruled.
**The cost is the DAWN end card: it becomes a lie, and it dies.** Separately, the Arbiter's
proposed `SIEGE_STRENGTH = 55` **arms a known softlock** and is struck: the day may move the night
DOWN from 45 and never up.

---

## 1. WHAT THE COUNCIL PROVED THE ARBITER WRONG ABOUT

Recorded first, because the Pointer Law cuts both ways and this council was convened by the man it
corrected four times.

| Arbiter's claim | Truth | Pointer |
|---|---|---|
| "`field_mult` makes the second half SOFTER" | **Backwards.** It multiplies the WAIT, so decay makes it HARDER — and it never runs at all, because the clock resets at every wire crossing | `field_director.gd:148`, `:129`, `:132`, `:1584-1587` |
| "The LIVE_CAP collision — hunters + garrison + assault" | **The three populations never meet in any counter.** The cap walks only siege cells | `siege_director.gd:421-430`, `:435-446`; `field_director.gd:1364-1378`, `:155-162`, `:41-57` |
| "Clean day 35 / default 45 / bad day 55" | **55 arms the 7/28 trickle softlock by construction, on the worst-outcome branch** | `siege_director.gd:444` + no `set_physics_process(true)` anywhere; `demo_game.gd:44-48` |
| "1:30–4:00 walking out to the village" | **The walk is ~25 seconds.** Village at 185m, parapet 96m, walk speed 5 m/s | `mission_generator.gd:709`; `player.gd:5` |
| "The squad is 5 men" | **8** | `squad_system.gd:19` |
| "The midday return is what the chow hall is FOR" | It fires the after-action report the demo EXCLUDES, and resets the clock — making the afternoon EASIER | `field_director.gd:1564-1587` vs `demo_game.gd:20` |

**Three times in one day the codebase beat the document. Make it seven.**

---

## 2. THE SHAPE — RATIFIED

### 2.1 The clock (question A) — RULED

**Day 38x. Night 20x. A variable ratio, but for the opposite reason the briefing gave.**

The briefing wanted the night FASTER to make dawn true. The council proved that acceleration past
midnight **breaks three systems**: it re-arms a second siege roll (`siege_director.gd:171-174`),
unlatches the fire-support allotment via `_granted_day` — an exploit already named in its own
comment (`field_director.gd:1240-1245`) — and **raises the sun during the night attack**
(`mission_weather.gd:95`, `sight_cap.gd:25`).

- **Start 06:30**, not 07:00. **0700 does not exist in code** — `mission_weather.gd:40` holds
  {5.5, 10.0, 17.5, 21.0} and wins over `mission_generator.gd:248-255` via `game_flow.gd:677-679`.
  06:30 spawns in dawn light so that **DAY snapping on is the player clearing the gate.** The
  engine's hardest limitation becomes the opening beat.
- **06:30 → 21:00 = 14.5 sim hours across ~23 real minutes ≈ 38x.**
- **21:00 → the break at ~20x**, keeping the assault inside the same sim day.
- **SACRIFICED:** `AmbientWar` is hour-driven with no arc override (`ambient_war.gd:62`) — the
  distant war's density shifts with the faster day. And **the DAWN end card dies.** The demo can no
  longer claim the sun came up, because making it true costs three exploits. See Decision Queue Q1.

### 2.2 The opening (question B) — RULED

**There is no gate pointer in code, and the right one is not a marker. It is your own squad
leaving without you.**

Issue `OrderMode.MOVE_TO` (`ally_base.gd:160`, `:206`; `squad_system.gd:201-205`) to
`patrol_gate_pos` (`field_director.gd:991`) at **T+10 seconds**, not T+60. It is rendered by the
squadmate labels that already exist and are **already exempted from the no-rails ruling**
(`mission_hud.gd:336-368`). It respects the ADR-030 HUD deferral completely: no new UI element is
created.

- **SACRIFICED:** 60 seconds of soft rail. The order MUST expire at the gate or it becomes one.
  And the opening is hostage to compound pathing — **count the arrivals before shipping this.**

### 2.3 The beat sheet — AMENDED (the Arbiter's is struck)

| Time | Beat | Status |
|---|---|---|
| 0:00 | Spawn 06:30, dawn light, squad forming | build |
| 0:10 | The squad walks out without you | build (§2.2) |
| 0:30 | Turn the corner — birds lifting off the pad | build (§2.4) — **needs a Blender pad** |
| ~0:55 | Clear the gate — **DAY snaps on** | free, from the 06:30 start |
| ~1:20 | First-sign at 150–300m | **two disabled lines** (`mission_generator.gd:723-724`) |
| ~2:45 | **Ambient cell crosses your front — let it pass, or shoot** | build (§2.5) |
| ~4:00 | Village in sight — the enemy's eyes | mostly built (§2.6) |
| midday | **NO return.** Afternoon runs straight to the camp | **struck** |
| ~17:00 | **DUSK snaps on** during the return leg | free |
| ~21:00 | Return, chow hall, **NIGHT snaps on**, stand-to | §2.7 |
| ~23:00 | The assault | shipped |

**The midday return is STRUCK** and the chow hall moved to **21:30, before stand-to** — where it is
the last warm human beat before the wire breaks, instead of a lap the player already walked. This
also dodges the AAR collision entirely.

**SACRIFICED:** the two-sortie structure collapses to one long excursion. The Summoner asked for a
village AND a camp; he gets both, on one loop, without crossing the wire between them.

### 2.4 Multi-pad Hueys (question C) — BOUNDED, AND BLOCKED ON BLENDER

**The code is already built** — `_free_pad` walks all pads at capacity 1 (`air_traffic.gd:467-515`).
**The pads are not.** Two architects measured independently: the shipped GLB has **one pad**, and
all three pad-prefix nodes sit at the **identical position (22.18, 4.01, −41.29)**.
`air_traffic.gd:54`'s "three PSP pads" comment is **drift** — correct it. `_free_pad()` today would
land three aircraft on one square metre.

**Priced:** Huey = **27 draw calls**; Chinook = **84 calls / 12,028 tris**; baseline ~1,350 calls
where 1,000 calls ≈ 6 FPS (`PERF_LEDGER.md:686,700`). The men were never the frame cost — W7
measured **48.0 FPS at garrison 24 AND 40** (`site_planner.gd:850-853`).

**RULED: ONE new pad marker (two total). Two concurrent cycles maximum. The Chinook never
concurrent.** And **fix the dispatch bug**: `_dispatch` checks the ceiling once before the lead
(`:328`) then adds 8 wingmen unchecked (`:343-349`) — up to 22 airframes, +44% draw calls.

**The rescope's real frame cost is DAYLIGHT, not men.** `air_traffic.gd:93-108` books hours 6–23:
a day demo fires **~39 transit bookings and all 4 LZ cycles versus today's ~18 and 1** — 2.2× the
air traffic, arriving exactly where the combat-load gate is clear.

**And "birds lifting as he turns the corner" does not exist:** every `lz_cycle` begins **airborne
~280m out** (`:536-540`). A launch-from-pad path must be authored, and the flight-in time measured.

**SACRIFICED:** two pads read as a pattern, not a busy base. The Summoner's image of a working
flightline is deferred to the full game.

### 2.5 The empty walk (question G) — SHIP THE AMBIENT CELL

**The Summoner's ruling 9 — "a hunter patrol must be able to hit the player any time outside the
wire" — is structurally impossible in the shipped code.** The hunt net is double-gated: it needs a
COMBAT contact (`field_director.gd:113-119`) AND a non-empty evidence ledger fed only by player
gunfire (`:35-38`, `:143-145`), then waits 70–110 seconds (`:118`).

**RULED: one ambient cell walking a road between the village and the camp, spawned at boot,
crossing the player's front at ~2:45.** Let-pass-or-shoot teaches the entire stealth economy with
zero tutorial — which is the 5-Minute Rule satisfied by a mechanic instead of a cutscene.

**Three hard constraints the council attached:**
1. The road must stay **>90m from `fsb_center`**, or `_poll_firebase_threat` (`:1328`,
   `FSB_THREAT_MEN` 2) stands the entire 40-man garrison to at 07:05.
2. `last_combat_contact_ms` is a **global static** (`enemy_base.gd:272`) — any enemy going loud
   anywhere fires a false "YOU'VE BEEN MADE" with nothing behind it. Must be scoped or the toast
   suppressed.
3. Tag it `"hunters"` so the night arithmetic in §2.8 folds it in.

**SACRIFICED:** a genuinely stealthy player can now be found without ever having made a mistake.
That is the point — the Summoner tied ruling 9 to "the being seen aspect" — but it is a real
subtraction from Pillar 3's promise that quiet play is rewarded.

**Also: the 200m landmark is two disabled lines.** The patrol planner already places first-signs at
150–300m (`mission_generator.gd:496`, consumed `:765-769`); the demo ships zero (`:723-724`).

### 2.6 The village as the enemy's eyes — MOSTLY ALREADY BUILT

**Civilians exist** — `civilian.gd` is 38 KB of behaviour trees, SimClock schedules and households.
**The informer path is real** (`civilian.gd:582-594` → `field_director.gd:627-641`).
**The only gap is that it is a coin flip:** `mission_generator.gd:979` gives the demo village a ~50%
chance of an informer existing at all. **RULED: force it to 100% in the demo.** A 50% chance of the
demo's central idea appearing is not a design, it is a dice roll on the shop window.

**The destructible tunnel mouth is ALREADY SHIPPED — zero engineering cost.** HOLD-interact satchel,
grenadier-skill hold time, blast, nav re-bake, and cross-patrol permanence:
`player.gd:838-891`, `campaign_state.gd:478-490`, consumed at `site_planner.gd:195-202`. **Both
stampers already place one** (`:258`, `:1632`). Two non-code items remain: confirm the demo loadout
carries a satchel (`player.gd:843`), and make it findable.

**The enemy camp is a plan edit, not new content.** The stamper is built (`site_planner.gd:1629`,
dispatch `:761`); the demo simply disables camps (`mission_generator.gd:740-741`).

### 2.7 The chow hall (question I) — THE BLOCKER IS OLDER AND BIGGER THAN REPORTED

The Arbiter's finding stands and is confirmed: `gen_firebase_v3.py:912`'s default is CORRECT, do
not repoint it; `:1104` is confirmed still stale. **But that was never the real blocker.**

**MEASURED: `fsb_main_v3.glb` is dated Jul 26. It contains zero `WB_chowhall`, zero `work_eat` —
and zero `WB_medical`. The recovered medical complex has never once been in the running game.**

**AND THE MEASUREMENT NOBODY HAS EVER TAKEN, WHICH GATES EVERYTHING ELSE:** GLB markers carry
Blender's **dot** suffix (`work_rest.001`), but the parser strips only `_<int>`
(`site_planner.gd:905-909`). If Godot's importer preserves the dot, **~185 of 198 work markers
silently degrade to `off_duty`** — which would mean the aid-station seed (`:969-978`, needs ≥2
`medic`) and the litter team have **never fired in the history of this project.**

> **MEASUREMENT M-1, RUN BEFORE ANY RE-EXPORT:** run `tests/test_firebase_garrison.tscn` and print
> the occupation histogram from `fsb_garrison_plan`. **PASS** = a spread of occupations matching the
> marker families. **FAIL** = a wall of `off_duty`. This is the highest-value hour available to this
> project right now, and it costs nothing but running it.

**AND A TRAP:** exporting the chow hall as-is **silently steals garrison men** — 40 unknown `work_*`
types enter the fixed 23-man round-robin (`site_planner.gd:936`, `:992-1008`) as `off_duty` statues
sitting on the mess benches. Exclude the chow families from the garrison rotation first.

### 2.8 Does the day feed the night? (question E) — YES, DOWNWARD ONLY

**RULED: `SIEGE_STRENGTH` starts at 45 and the day may only take men away. Never add.**
The Arbiter's 55 is struck — it arms the one-way freeze latch (§3.1) on the worst-outcome branch.

Arithmetic, folding the Systems Designer's proposal within the new ceiling:
`night = 45 − hunters_killed − 8 (tunnel mouth blown)`, **clamped 28–45.**
The informer's +10 becomes "you fail to prevent the subtraction," not an addition.

**Two traps the council caught:**
- **Never price this off `state.kills`** — the bank wipes it (`field_director.gd:1584`).
- **Hunters are never reaped** (`siege_director.gd:712-716` walks only siege cells). Survivors must
  be cleared with `despawn_tracked_enemy` (`:72`) at stand-to — **as a despawn, not a casualty**, or
  the arithmetic double-counts.

**THE DEVIL'S ADVOCATE IS RIGHT THAT A BODY COUNT IS IMPERCEPTIBLE.** Night sight is 56m, the
assault crosses 190–235m, illumination strobes 55s on / 15s off. **A player cannot tell 35 men from
55 at night.** Therefore the consequence is expressed in **three** places, none of which is a
number:
1. **The RTO's radio line at the gate** (`field_director.gd:667-673`) — carrier already exists.
2. **A BREACH or no breach** — the siren is already wired. This is the Devil's proposal and it is
   the best of the three: the player does not count men, he watches the wire hold or not.
3. **The end card** (`demo_game.gd:331-359`).

**If all three are not built, DO NOT BUILD THE LINK.** An invisible consequence is no consequence
(r4bk Law), and a designer's private arithmetic is not a feature.

**SACRIFICED:** a clean day earns a smaller climax. Floored at 28 so the finale never deflates —
pay the quiet player in fewer greyed-out names on the end card, not in a shorter fight.

### 2.9 The hunt pool — TOP IT UP, AND PAY THE ADR

**The second half goes soft because the pool runs dry, not because of `field_mult`.** 12 men
(`field_director.gd:106`) at 2–4 per wave (`:149`) is **~7.7 minutes of contact, then the AO is
empty forever.** In a 7-minute demo this was invisible. In a 30-minute one it is the arc breaking at
the quarter mark.

**RULED: top the pool to 6 on each OUTBOUND gate crossing**, at the same seam as the fire-support
grant (`:1221`).

**SACRIFICED, and it is a real one: this breaks ADR-035's per-operation finite-pool promise.**
"You can bleed the AO dry" stops being true inside the demo. **The ADR is not amended** — the demo
takes a documented, scoped exception, recorded here. The full game keeps the finite pool.

**Question D: LEAVE `field_mult` ALONE.** Do not invert it (the premise was backwards) and do not
spend time flattening it (it is dead code in this arc). If anything is done, move its clock off the
banked `state` — but that is full-game work, not demo work.

### 2.10 Fire support — THREE MEANS THREE, AND THE RADIO IS A MAN

**"3 fire missions" matches nothing in code.** The grant is 5–8 (`field_director.gd:1251-1255`) —
the Devil's Advocate counted up to seven: 3–4 mortar + 1 bomb + 1 arty + 2–3 illum. The shipped
demo runs the class default of `mortar 2, illum 2` (`:304-305`); `demo_game.gd` has **zero**
fire-support references.

**RULED: `{bombs 1, arty 1, mortar 1}` — three calls that are three DIFFERENT VERBS.** The
Summoner's scarcity psychology ("the first one they'll spend just to spend") only works if spending
the first one teaches something the other two build on. Three of the same thing teaches nothing.

**Three live defects to fix with it:**
- **Illumination has no menu row** (`mission_hud.gd:97-104`) though key 7 is bound (`:243`).
  **A shipped r4bk violation.**
- `_granted_day` (`:1243`) lets a post-midnight 120m step **re-arm mid-siege**. §2.1's 20x night
  ratio already prevents this; fixing it makes the prevention structural rather than incidental.
- `p["fire_support"]` (`mission_generator.gd:509`, `:675`) is read by nothing; ADR-011's pointers
  are all stale.

### 2.11 Ally AI to the Vietcong bar (question H) — RULED

The Arbiter's five verified pointers all hold. The gap is not where he was looking.

**THE FINDING: your squad cannot be wounded.** Allies go from HP≤0 straight to `_die()`
(`ally_base.gd:1485-1487`); there is no downed state and the docstring says so (`:41-42`). The
medic's only revive target is the PLAYER (`squad_system.gd:99-102`, `:313-348`).
**Meanwhile the ENEMY has `is_downed`, a `downed_pool`, and medics who drag men out**
(`enemy_base.gd:2489-2570`). **The VC recover their wounded. Your squad cannot be wounded, only
deleted.** For a Summoner who just elevated squad survivability to pillar level, that is the whole
answer to question H — and the council still recommends **CUTTING** the downed-ally system for this
demo, on the record, because it is the single most expensive item on the board. It goes in the
Decision Queue instead of being quietly dropped.

**RULED FOR THE DEMO — the minimum set that reaches the bar, in cost order:**
1. **Feed `squad_broken`/`force_ratio` to the shared scorer.** Allies never pass it
   (`ally_base.gd:782-801`); the enemy does (`enemy_base.gd:1408-1409`). The squad-break toast is a
   cheque the AI does not cash. **~2 lines.**
   *Sacrificed:* the squad will visibly leave you at the climax. That is correct, and it will read
   as a bug to a player who has never seen it.
2. **MOS-weighted courage.** MOS is read NOWHERE in the AI — one hit and it is a comment
   (`ally_base.gd:166`) — and courage is a flat `randf()` (`:296`), so **the RTO plays hero ~25% of
   the time** and skips the cover trip (`:109`). **~6 lines.**
   *Sacrificed:* a cautious RTO drags the player backward to a 10m radio leash.
3. **A concealment term in the cover search. THIS IS THE VIETCONG GAP.** `_find_cover_point` accepts
   a position only if a physics ray is BLOCKED (`ally_base.gd:1298-1303`), and grass/fern/bush have
   **no collider by contract** (`tree_cover_layer.gd:17-19`). **But the simulation already rewards
   the grass** — vegetation cuts sight (`sight_cap.gd:32-39`) and heavy jungle blocks LOS 30% per
   cell (`gameplay_grid.gd:406-411`). **The AI cannot see a reward the sim is already paying.** One
   O(1) grid read. **~12 lines + a look-check.**
   *Sacrificed:* your own men vanish into grass. Pillar 4 is legibility as much as survival — the
   squadmate nameplates must be checked in the same session.
4. **Make the grenadier's cluster thumper player-placed** via the existing `squad_move` aim. **~15
   lines.** This converts an automatic behaviour into a spendable VERB.
   *Sacrificed:* a bound key with no HUD affordance — an r4bk debt, taken knowingly.

**THE VIETCONG INSIGHT, MEASURED:** the squad owns five verbs — trap-spot (POINT), call-for-fire
(RTO), player-revive + bandages (MEDIC), sustained fire (MG), cluster thumper (GRENADIER) — and
**four of the five are AUTOMATIC.** Only the radio is spendable, which is why only the radio's loss
is felt. That is the precise mechanical reason the squad does not yet feel like *Vietcong*: losing a
man must cost you a VERB YOU WERE USING, not background rifle fire. Item 4 above converts one.

**Two defects logged, not scheduled:** trunk colliders exist only within 70m of the **player**
(`tree_cover_layer.gd:34-43`), so allies further out have **zero cover** — **CUT for the demo, on
the record.** And **MARKSMAN has a weapon and a body but is absent from `MOS_ORDER`
(`squad_roster.gd:64`) — it never spawns.**

**Scope correction: the squad is 8, not 5** (`squad_system.gd:19`).

### 2.12 The RTO question the Summoner listed as open — IT IS ALREADY ANSWERED

**The calls already stop, totally and permanently.** Two architects found it independently:
`member_by_mos` skips dead men (`squad_system.gd:168`) → `_radio_check` requires a living RTO within
10m (`field_director.gd:654-663`) → the player is kicked off the net that frame (`:257-268`). And
because allies have no downed state, "goes down" and "dies" are the same event.

**So the real question is not whether the calls stop. It is whether TOTAL DELETION is the right
punishment** when there are only three calls, no save, and no replacement. That is Pillar 5's
problem, not a feature. Council recommendation for the Summoner: allow the handset to be picked up
off the corpse (`ally_base.gd:1547-1549`) with the forward-observer factor dropped to 0, so the
punishment is a **wide, sloppy sheaf** (`:480`, `:495`, `:725`) instead of silence.

**SACRIFICED:** ADR-011's "the radio is a man." The RTO becomes a quality multiplier rather than a
hard gate. **Decision Queue Q4.**

### 2.13 Fail forward and the no-save collision — THE ARBITER'S CHIEF CONCERN

**The player's fail-forward EXISTS and is complete** (`squad_system.gd:224-345`,
`health_system.gd:248-286`, 6 bandages `:10`). Ruling 7 does not need building. Two contradictions
sit inside it instead:

1. **`revive()` restores FULL HP** (`health_system.gd:276-278`) — the Summoner's own 7/18 decree —
   versus his 8/3 ruling that you "come back degraded." **His tie to break. Decision Queue Q3.**
2. **THE HEADSHOT BYPASSES THE REVIVE WINDOW ENTIRELY** (`health_system.gd:203-208`). One round at
   minute 22 costs the player 22 minutes, and the only button is `reload_current_scene()` (`:362`).
   **Ruling 6 (no save) and ruling 7 (fail forward) are individually sound and collide at exactly
   this one code path.** The headshot law ("headshots kill everyone") is canon and the Arbiter does
   not propose overturning it — but in a no-save 30-minute demo it produces the punishment Pillar 5
   forbids. Council recommendation: a **one-per-run helmet save.** **Decision Queue Q2.**

---

## 3. THE TWO LANDMINES THAT MUST BE DEFUSED BEFORE ANY OF THIS SHIPS

### 3.1 THE ONE-WAY FREEZE LATCH — the 7/28 trickle failure, still loaded

`_enforce_live_cap` calls `set_physics_process(false)` (`siege_director.gd:444`), and
**`set_physics_process(true)` exists NOWHERE** in `marching_cell.gd` or `siege_director.gd`. A
frozen cell never marches again, still reports full paper strength (`marching_cell.gd:56-57`), so
`live/peak` never falls and **the assault can never break** — it runs to `MAX_DURATION_S` past the
end card. `SIEGE_STRENGTH = 45` is the only thing disarming it today.

> **MEASUREMENT M-2 (specified, not guessed):** `build/RECON_Demo.exe --print-fps`, A/B/A at
> 45 → 55 → 45, 300 s each. **FAIL if run B prints `[Siege] cell of N held at the ring`
> (`siege_director.gd:445-446`) at all, or reaches the end with no `_break_siege`.**
> Prior: FPS moves ~0. W7 measured 48.0 FPS at garrison 24 AND 40 (`site_planner.gd:850-853`).
> **The men were never the frame cost.**

### 3.2 THE LARGEST UNBUDGETED ACCUMULATOR: DROPPED WEAPONS SPAWN FIRST-PERSON VIEWMODELS

**Measured this session.** `ak47.tres:27` points at `ak_fp.glb` — **11 draw calls, 1 skin, 6
animations, first mesh named `ArmsMesh`**, offset −1.81m so the arms are buried underground.
`LIFETIME_S = 600` **has never once expired in a 7-minute demo**, and it **resets to 300s whenever
the player is within 40m** (`world_weapon.gd:87-94`).

**45 attackers dying on the wire the player is standing on ≈ 495 immortal draw calls** against a
~1,350-call baseline. In a 30-minute runtime this is the rescope's biggest single frame risk, and it
has never been visible because no one ever ran the demo long enough.

**Second leak, smaller:** `EnemyBase.unreported_corpses` is an unbounded static array
(`enemy_base.gd:961`, appended `:1011`) scanned by every unit every heartbeat (`:804-807`,
`:1022-1031`), cleared only at world build (`field_director.gd:22`). Two architects found it
independently. **Decals, corpse meshes, the evidence ledger and flight bookings are all bounded —
do not spend time there.**

**SACRIFICED if corpses are pruned:** stealth-as-an-economy loses some of its memory. Prune the
TTL, not the witness logic.

---

## 4. WHAT THIS COSTS, HONESTLY

The Devil's Advocate priced the Arbiter's original shape at **~8–9 agent-days + 3 Blender sessions**
and called it **a new game mode wearing the demo's name.** The decree above is deliberately cheaper
than what he attacked, because the council found that **most of it is already built**: the tunnel
mouth, civilians and the informer, the camp stamper, the first-signs, the pad allocator, the
player's fail-forward, and the multi-pad code are all shipped. What remains is mostly **wiring,
constants, one Blender pad, and one export.**

**But the honest number is still not small, and two of the three biggest items are ones nobody knew
about this morning:** the freeze latch, the viewmodel accumulator, and the marker-suffix question
that may mean 185 of 198 markers have never worked.

**THE BACKLOG IS HONEST — 0 false claims in 5 spot-checks — BUT IT STOPS AT 7/31.** No chow hall,
no tiered expansion. **Every estimate drawn from it UNDER-counts.** Recorded so no one treats it as
complete.

---

## 5. THE MEASUREMENTS THIS COUNCIL ORDERS (no code, no guessing)

| # | Measurement | Why it gates | Cost |
|---|---|---|---|
| **M-1** | `tests/test_firebase_garrison.tscn`, print the occupation histogram from `fsb_garrison_plan`. FAIL = a wall of `off_duty` | If the dot suffix survives import, **~185 of 198 markers are junk** and the aid station + litter team have never fired. **Gates every chow-hall and medical decision.** | minutes |
| **M-2** | `RECON_Demo.exe --print-fps`, A/B/A at strength 45 → 55 → 45, 300s each. FAIL on any `held at the ring` line or no `_break_siege` | Proves whether the freeze latch is armed. **Gates §2.8.** | ~20 min |
| **M-3** | Run the exported demo **30 minutes** with `--print-fps` and watch draw calls | Nothing has ever run 30 minutes. Confirms the viewmodel accumulator in the field. | 30 min |
| **M-4** | Count squad arrivals at the gate on the T+10 move order, 10 runs | The opening beat is hostage to compound pathing. **Gates §2.2.** | ~20 min |
| **M-5** | Time a Huey from launch-on-pad to clearing the compound | "Birds lifting as he turns the corner" needs a launch path that does not exist. **Gates §2.4.** | ~20 min |

**M-1 is the highest-value hour available to this project right now.** It costs nothing but running
it, and it may invalidate a month of marker work.

---

## 6. EVERYTHING SACRIFICED (Law 2, collected)

- **The DAWN end card.** The demo can no longer claim the sun came up.
- **The full-day illusion** — four lighting events across an arc, not a moving sun.
- **The midday return**, and with it the two-sortie structure.
- **ADR-035's finite hunt pool**, inside the demo only, by documented exception.
- **The Summoner's busy flightline** — two pads read as a pattern, not an airbase.
- **Pillar 3's quiet-play promise**, partially: the ambient cell can find a player who made no
  mistake.
- **ADR-011's "the radio is a man"**, if the handset pickup is approved.
- **Downed allies and the 70m cover ring** — CUT for the demo, on the record, not dropped quietly.
- **Squad legibility**, if concealment ships without a nameplate check: your own men vanish.
- **An r4bk debt**, knowingly: a player-placed thumper on a bound key with no HUD.
- **Stealth's memory**, partially, if the corpse array gets a TTL.
- **`AmbientWar` density**, which is hour-driven and shifts under a 38x day.

---

## 7. THE DECISION QUEUE — ONLY CALEB CAN RULE THESE

*Plain words. No file names, no acronyms, no wave codes. Answer in chat; nothing below needs you to
open anything.*

**Q1. The demo can no longer end at sunrise. What does it end on?**
Making the sun genuinely come up means running the night fast enough to roll past midnight, and
midnight rollover switches three things back on that should stay off — including raising the sun in
the middle of the attack. So the attack has to run slow, and it ends somewhere around 11pm.
**Your choice:** (a) the demo ends in the dark on the attack breaking — no sunrise, no promise
broken; (b) we keep a sunrise card and accept it is a caption, not something the player watched;
(c) something else you want the last frame to be.

**Q2. A headshot skips the whole medic-revive system. Should your helmet save you once?**
You ruled that going down means your squad works on you and you come back. That works for every hit
except one to the head, which kills instantly and, with no save, throws away up to half an hour in a
single round. **Your choice:** (a) once per run, your helmet takes it and you go down instead of
dying; (b) leave it — a head shot ends the demo, that is the game being honest; (c) only outside the
wire.

**Q3. When the medic brings you back, are you patched up or wrecked?**
Right now the code puts you back at full health. In July you decided that. Today you said you should
come back degraded. Those disagree and I will not pick for you. **Your choice:** (a) full health,
you just lost time; (b) come back hurt and stay hurt; (c) hurt, but a bandage can top you back up.

**Q4. If your radioman dies, should you be able to pick the radio up off his body?**
Right now his death silences the radio permanently — no more fire missions, no exceptions. With only
three calls in the whole demo and no save, that can wipe out a third of your toolkit in one bullet.
**Your choice:** (a) leave it — losing him should hurt that much; (b) you can grab the handset, but
without him spotting the rounds land wide and sloppy; (c) another man can carry it at full quality.

**Q5. The demo has one landing pad, not three. How much of a flightline do you want?**
The code to run several pads at once already works — the firebase model only has one pad in it. Each
extra aircraft costs frame time. **Your choice:** (a) add one more pad, two aircraft moving at once
— cheap and it reads; (b) add two more and I measure whether it holds; (c) leave it at one and put
the effort elsewhere.

**Q6. Who mans the chow hall — real soldiers off your roster, or fixtures who are always there?**
If the cook and servers are rostered men, they come out of the same pool as your garrison and the
mess gets thin when the base is busy. If they are fixtures, the mess always looks alive but those
men are not really part of the base. **Your choice:** (a) rostered — the mess thins out when men are
needed elsewhere; (b) fixtures — always manned, always looks right; (c) cook fixed, servers
rostered.

**Q7. How many men eat at once?**
We proved the spacing works with one man. Nobody has ever run it with a full table. **Your choice:**
give me a number, and I will measure whether the elbows stay clear at that number before anything
ships.

**Q8. The marker names in the firebase are about to become permanent.**
The moment the game reads them, renaming one breaks things. Say the word and I lock the current
names as final, or tell me which ones you want renamed first — this is your last cheap chance.

**Q9. Your squad cannot be wounded — only killed. The enemy can be wounded and dragged to safety.**
That is backwards for a game where you just told me keeping the squad alive is a pillar. Building
wounded squadmates is the single most expensive thing on this board and the council recommends
cutting it from the demo. **Your choice:** (a) cut it, the demo ships without it and I log it for
the full game; (b) it matters more than something else on the list — tell me what to drop for it.

**Q10. Three fire missions, three different weapons.**
I am setting your three calls to one bombing run, one artillery mission, and one mortar mission
rather than three of the same. Spending the first one then teaches you something about the other
two. Say no if you wanted three of one thing.

---

# 8. THE SUMMONER'S RULINGS — 2026-08-03, ALL TEN CLOSED

*Answered in chat the night the decree landed. Law 3: the Council advises, the Summoner decides.
Where a ruling overturns something above, THE RULING WINS and the section above is superseded, not
amended in place — read this section last.*

**R1 (Q1) — THE ENDING IS CIRCLING GUNSHIPS.** His words: *"either way the ending is circling
gunships."* A flight of Huey gunships with M60 gunners circling over the wire is the last image,
and the sunrise card is dead as ruled in §2.1. He was offered survive-vs-die and declined to
separate them, delegating it: **the Arbiter rules the player SURVIVES** and the flight ends the
fight, because the demo's job is hype and a player who lived comes back. **This is one flag and it
is deliberately reversible** — if playthrough #1 says the ending lands flat, flip it to the
gut-punch (player dies, flight circles the body). Do not build it in a way that makes flipping it
expensive.

**R2 (Q2) — A HEADSHOT ENDS THE DEMO. No helmet save.** His words: *"Headshot ends the demo but its
an experience, no?"* Option (b). **COST NAMED:** with no save, one round at minute 22 costs 22
minutes. The only mitigation that does not violate this ruling is the one already true — ambient
positioners roll their own RNG per boot, so a retry is a different AO, not a rerun. Do not propose a
helmet save again.

**R3 (Q3) — HELL LET LOOSE REVIVE: FULL HEALTH, PAID IN BANDAGES.** His words: *"a medic revive is a
fresh return to the game. but its eating their bandages so thats the pay out in the game systems."*
This CLOSES the July-vs-today contradiction the council refused to pick: you do NOT come back
degraded — **the SQUAD comes back degraded.** Bandages become an economy; a squad that keeps picking
you up runs dry. Supersedes the "come back degraded" line in §2.13.

**R4 (Q4) — THE RADIO IS AN OBJECT, NOT A MAN.** His words: *"IF the RTO guy dies we should be able
to have someone else pick it up. than they turn into the RTO guy. so when the squads dead no more
radio."* None of the council's three options; better than all of them. Full quality on transfer — no
sloppy-rounds penalty. Fire support dies with the SQUAD, not with one man.

**R5 (Q5) — NOT A DESIGN QUESTION.** His words: *"I haven't exported the new dual pad firebase
yet."* Two pads already exist in the .blend, unexported. The multi-pad scheduler code already works
(§2.4). This is bench work, and it folds into the SAME export session as the wire split, the medical
complex, the bunker embrasures and the chow hall.

**R6 (Q6) — ROSTERED, WITH THE ROLE LOOK.** His words: *"Rostered troops will take up position and
switch to their cook looks and proper props etc."* Option (a) plus a wardrobe requirement the council
did not offer. The dresser already swaps surfaces matched by TEXTURE, so this is a role wardrobe on
existing bodies, not new models.

**R7 (Q7) — FILL THE HALL.** His words: *"if we can fill the whole chow hall we should fill it up."*
All 24 seats. **THE TENSION, NAMED:** the garrison ceiling is 40 men (FSB_GARRISON_MAX_MEN, set by
W7 measurement 7/31). 24 men eating leaves 16 for everything else at the hour before stand-to — a
full mess and an abandoned wire. **Arbiter's recommendation: STAGGER THE MEAL IN SITTINGS** so the
hall is full but never all at once, rather than raising the ceiling and paying the frames. Not yet
ruled by him. **The elbow gate is measured at whatever number ships** — 24 men in a tent is exactly
where [[elbows-must-never-intersect]] bites.

**R8 (Q8) — ALREADY CLOSED BY HIM MID-COUNCIL.** He locked the marker names himself while the
architects sat, via `tools/rename_chow_markers.py` (idempotent, longest-prefix-first). Convention is
`work_<building>_<role>` / `prop_<building>_<thing>`. The names are now an API.

**R9 (Q9) — CUT WOUNDED SQUADMATES FROM THE DEMO, LOG FOR THE FULL GAME.** He asked what "cut and
log" meant; restated plainly and accepted. **The asymmetry being shipped:** the PLAYER can go down
and be revived (built). The ENEMY can be wounded and dragged out by their own medics (built). His
OWN MEN cannot — they are alive or they are a body, with no downed state, no bleed-out, no medic
pathing to them under fire, no drag-to-cover, no revive. **The demo therefore sells a squad-survival
pillar it cannot fully deliver, and he was told so before agreeing.** Logged as a named full-game
feature with its reason so nobody rediscovers it in three weeks and nobody builds it by accident.

**R10 (Q10) — THREE BOMBING RUNS, ALL THE SAME.** His words: *"there should be 3 bombing runs thats
it."* The council's one-bomb/one-arty/one-mortar split is OVERRULED; §2.10's differentiation is
struck. **SEPARATELY AND NOT FROM HIS ALLOTMENT:** the napalm run during the night raid stays — his
words, *"thats what players wanna see"* — plus **a few ambient napalm bursts during the day while
he is out in the field, to keep the world lively.** Napalm is SPECTACLE, scripted as a world event,
and is never billed against the three calls.

## STILL OPEN AFTER THIS PASS
- **R7's sittings-vs-ceiling** — stagger the meal, or raise the garrison ceiling and pay frames?
- Everything in §5 (the ordered measurements) is untouched by these rulings and still stands.
