# GAME DESIGNER — the demo as an experience

**Written 2026-07-30.** Lens: what the player SEES and HEARS, and whether the ship gate lands in 20
minutes. Every claim below carries a `file:line`. Where the briefing and the code disagree I say so.

---

## 0. THE ARC, VERIFIED — and the bug that eats the ship gate

The briefing's numbers are correct as of today (`scripts/levels/demo_game.gd:27-30`):

| knob | value | line |
|---|---|---|
| `PROBE_AT_S` | 600.0 | `demo_game.gd:26` |
| `SIEGE_AT_S` | 720.0 | `demo_game.gd:27` |
| `DAWN_AT_S` | 1080.0 | `demo_game.gd:28` |
| `PROBE_STRENGTH` | 11 | `demo_game.gd:29` |
| `SIEGE_STRENGTH` | 40 | `demo_game.gd:30` |
| `NAPALM_EARLY_S` | 160.0 | `demo_game.gd:100` |
| `NAPALM_ASSAULT_S` | 780.0 (`SIEGE_AT_S + 60`) | `demo_game.gd:101` |

**FINDING 1 — THE MAIN ASSAULT NEVER HAPPENS.** `_open_siege` at phase 1 calls
`d.siege.open_siege(11)` (`demo_game.gd:171, 204`), which sets `active = true`
(`siege_director.gd:155`). At 720 s phase 2 re-enters `_open_siege(40, "HERE THEY COME")` and hits the
guard at `demo_game.gd:197-203`: **`if d.siege.active: toast only`**. `SIEGE_STRENGTH = 40` is never
applied to anything. The demo's entire night is the 11-man probe, announced twice.

Could the probe have broken before 720 and re-opened the door? Measured: cells spawn at
`ring_min 190 – ring_max 235` from `fsb_center` (`demo_game.gd:189-190`), materialize at 80 m from the
objective (`marching_cell.gd:15`, capped to 220 by `demo_game.gd:193`), and march at
`MARCH_SPEED 2.2 m/s` (`marching_cell.gd:16`). That is 110–155 m of dormant march ≈ **50–70 s** before
a single body exists, then a firefight. The break needs 42.5 % of 11 = **5 dead**
(`BREAK_BASE_RATIO 0.575`, `siege_director.gd:30`; `_run_siege` → `EnemySquad.break_state`,
`siege_director.gd:210`). Five sappers killed inside the remaining ~50 s by a just-promoted garrison is
the unlikely case, not the normal one. **Normal boot: no second wave, ever.**

**FINDING 2 — THE CARD LANDS ON AN UNDECIDED FIGHT.** `MAX_DURATION_S = 480`
(`siege_director.gd:40`) measured from `open_siege` at 600 s expires at **1080 s** — the same instant
`DAWN_AT_S` fires `_dawn()` (`demo_game.gd:177-179`). The player is shown **"DAWN. YOU HELD."**
(`demo_game.gd:212`) in the same frame the assault is being force-broken for "dawn", so
`_on_siege_ended`'s own line — *"THEY'RE BREAKING — %d OF %d DOWN"* (`field_director.gd:1323`) — either
races the card or is buried under it. **The demo's climax is a coin flip on signal order.**

These two are not polish items. They are why "the VC attempt to overrun" has never been seen.

---

## 1. THE OVERRUN AS AN EXPERIENCE

He asked for an attempt to **overrun**, not a probe. An overrun, as a felt thing, is four moments in
order, and the demo currently has one of them:

1. **DREAD** — the war goes quiet and something is out there.
2. **WEIGHT** — more of them than you can shoot.
3. **THE WIRE GOES** — the perimeter stops being a wall.
4. **DECISION** — you can hear it turn, one way or the other.

The code has (2) as a number nobody applies, (3) as a satchel nobody has ever seen detonate
(`DEMO_SHIP_BACKLOG.md:63`), and (4) as a toast line. (1) does not exist at all.

### RULING 1A — the probe must ESCALATE, not be shouted over

Kill the toast-only branch (`demo_game.gd:197-203`). Give `SiegeDirector` a **`reinforce(target: int)`**
that appends cells through the existing `_spawn_cells_for` path (`siege_director.gd:177-194`) and adds
the new men to `run_peak` (`siege_director.gd:83`), so the break ratio stays honest — the ledger is
authored to be fixed at roll time *precisely because* an observed strength is replenished by arrivals
(`siege_director.gd:78-81`); a reinforcement that raises **peak** does not break that invariant, a
reinforcement that raises only `run_strength` does.

`reinforce` also resets `_elapsed` (`siege_director.gd:86`) so the second wave gets its own duration
window instead of inheriting a clock that started with the probe. That alone fixes FINDING 2's collision.

This is the correct design, not just the cheap one: it makes the probe **mean something**. A probe that
is a separate encounter is a chore; a probe that turns out to be the enemy *finding the soft sector* and
the mass coming down that exact bearing is the story of every firebase night. `sector_bearing` is
already reused across nights for exactly this reason (`siege_director.gd:160-162`).

**SACRIFICES:** the probe can no longer be a quiet false alarm — in the demo it always becomes the
assault, which is a rail. Accepted for a 20-minute slice; the campaign path (`_maybe_open`,
`siege_director.gd:118-139`) keeps the honest roll. **PILLAR:** serves 1 (believable firefights — a
recon-then-mass doctrine is what soldiers do); strains 3 (freedom — the demo is on rails by definition).

### RULING 1B — the dawn card fires on `siege_ended`, not on a clock

`DAWN_AT_S` becomes a **ceiling**, not the trigger. `_dawn()` runs on the `siege_ended` signal
(`siege_director.gd:57`, already connected at `field_director.gd:1289`) with the 1080 s clock as the
fallback for the case where the siege never opened. The player must see
*"THEY'RE BREAKING"* → the withdrawal → **then** the card.

**SACRIFICES:** the demo's length stops being fixed at 20:00 (it can end at ~17:00 on a fast break or
run to the ceiling). **PILLAR:** serves 5 (fail forward — the night is decided by the fight, not by a
timer) and 2.

### THE BEAT SHEET

Times are seconds from boot. **NEW** = does not exist today. Everything else cites its line.

| t | beat | what he sees/hears | status |
|---|---|---|---|
| 3 | the sky is already working | 6–9 Hueys crossing low | `demo_game.gd:68` |
| 14 | **first Huey puts down on the pad** | flare, touch, men out | `demo_game.gd:69` (B2 pending) |
| 26–95 | fast movers, a second pack, the heavy | horizon traffic | `demo_game.gd:70-73` |
| 160 | **somebody else's war** | napalm on a bearing away from him | `demo_game.gd:100, 115` |
| 160–480 | the base lives | garrison working, off-duty men at markers | A3 (7/29, unverified) / A4 open |
| **480** | **THE DREAD** | **the ambient war stops.** No distant contacts for ~100 s. One dog. One far tube. | **NEW** |
| 600 | **the probe finds the wire** | sentry's shout, `MOVEMENT ON THE WIRE — STAND TO`; garrison promotes; **no siren** | `field_director.gd:1294-1298, 1246-1262` |
| 605+ | ranging rounds begin | tube thump, then whistle, then impact at 50 m dispersion | `siege_director.gd:266-292` |
| ~620 | **the wire opens once** | a sapper satchel takes a parapet segment down | C1/C2 (`destructible.gd`, `SapperCharge`) |
| **660** | **THE DEFENDERS LIGHT THEIR OWN WIRE** | first illum over the sector; the ground beyond the wire is visible and nearly empty | **NEW** (see §2) |
| 720 | **THE WEIGHT** | **THE SIREN** (`field_director.gd:1303`), `SIX: THE FIREBASE IS IN CONTACT` (`:901`), `reinforce(45)` — cells materialize at 80 m **inside the lit circle**, not out of nothing | RULING 1A |
| 720–900 | the walk tightens | mortar dispersion 50 m → 12 m over 180 s — the crescendo clock | `siege_director.gd:47-49, 271-272` |
| 780 | **gun run and napalm, danger close** | strafe down the assault's own bearing | `demo_game.gd:101, 118-122` |
| ~800–900 | **THE WIRE GOES** | a breach, and men coming **through the gap** | C3 — the doctrine gap (§1C) |
| ~900–1000 | **inside** | fighting between the hootches, the dump threatened | C3 + `on_firebase_breach` (`field_director.gd:1269`) |
| break | **DECISION** | volume of fire collapses; withdrawal; `THEY'RE BREAKING — N OF M DOWN` | `field_director.gd:1323` |
| +8 s | the card | named men, HELD/KIA | `demo_game.gd:209-235` |

**Where the dread is:** 480–600. It is the cheapest beat on this list and the demo does not have it.
`AmbientWar` rolls 1–3 events every `SimClock.hour_advanced` (`ambient_war.gd:22-33`) and never stops.
A silence flag the demo can raise for 100 s is a handful of lines and it is the difference between
"an attack started" and "something is coming".

**Where the wire goes:** ~800–900, and it must be a **hole he can point at**. The 80 authored parapet
segments are a closed ring at r = 49.3–96.1 m (briefing, measured) and now answer `is_destroyed()`.

**Where it is decided:** at the break, and it must be **heard**. Today the break is a `toast.emit` and
nothing else (`field_director.gd:1320-1329`). A night that turns in silence did not turn.

### RULING 1C — the assault must press PAST the wire

`enemy_base.gd:1305-1313` is the whole problem in eight lines: an undriven man marches to
`assault_objective`, and on arrival (or on contact) **`assault_objective = Vector3.ZERO`** — cleared
forever. He then trades shots wherever he stood. The single aim point is
`FieldDirector.siege_aim`, the bench just inside the wire (`field_director.gd:881-884`).

The design that makes an overrun: **the objective is a QUEUE, not a point.** Arrival pops the next
objective instead of clearing the field. For the demo, two entries are enough:
1. the nearest live parapet segment on the sector bearing (the wire),
2. `siege_aim` (the bench / the dump) — reachable only once (1) is destroyed or once a segment on that
   bearing reports `is_destroyed()`.

An assault element whose second objective only unlocks on a breach is doctrine, and it means the
sappers' work visibly *buys* the ground. That is legible without a single UI element.

**SACRIFICES:** an objective queue is a step toward scripted attack choreography, and it can look
suicidal (men funnelling a known gap under fire). Mitigated by leaving them undriven — contact still
takes their legs back, they just remember where they were going. **PILLAR:** serves 1; strains 1's own
"never bullet sponges" clause if the queue overrides self-preservation — so it must **not** set
`assault_driven`.

---

## 2. LEGIBILITY — the fight needs a scoreboard he can never read as a number

Canon forbids the easy answer: ADR-029 ships no objective counter, and nobody inside the perimeter can
know the attacker's strength — the code says so in its own voice at `field_director.gd:1299-1302`,
where the old *"(%d ON THE WIRE)"* copy was deliberately removed. **So no strength meter, no wave
counter, ever.** The scoreboard must be three diegetic proxies.

**WHAT ALREADY EXISTS — use it before proposing anything:**

| instrument | state | pointer |
|---|---|---|
| `FieldDirector.CRISIS_CALL` | 5 radio lines; `firebase_attack` fires on the wave latch | `field_director.gd:900-906, 1214-1230` |
| `SirenTower` | 4 detuned emitters, 900 m, 45–75 s cry, 2–5 s crank delay, silences itself, dies with its tower mesh | `siren_tower.gd:20-32, 106-152`; called `field_director.gd:1303, 1309-1314` |
| probe suppression of the siren | deliberate: *"crying the siren for three men is how the siren stops meaning anything"* | `field_director.gd:1294-1298` |
| `IllumFlare` | works, strips concealment both ways, drives `materialize_if_lit` | `illum_flare.gd:30`, `marching_cell.gd:99-105`, `sight_cap.gd:34` |
| mortar walk | dispersion 50 → 12 m over 180 s, tube thump + incoming whistle per volley | `siege_director.gd:47-49, 266-292` |
| stand-to | garrison Civilians → AllyBase defenders, prints the count including zero | `field_director.gd:1246-1262` |
| break copy | three outcomes, worded | `field_director.gd:1320-1328` |
| `_enforce_live_cap` logging | a held cell is printed, never silently dropped | `siege_director.gd:250-261` |

**THE MINIMUM TELEGRAPHY — exactly three additions.**

**RULING 2A — the garrison lights its own wire.** This is the highest-value single line in this
analysis. `IllumFlare` today only reaches the world through the **player's** limited allotment
(`_run_illum_mission`, `field_director.gd:694-707`) or his hand flare (`player.gd:1308`). Night sight is
56 m open / 18 m jungle (`field_director.gd:690-693`) and they come from 190–235 m. **Without illum the
overrun is muzzle flashes in the dark and the player never sees the mass he is supposed to fear.** The
defenders of a real firebase kept a tube on illum all night. Ruling: while `active` and not `is_probe`,
`SiegeDirector` pops one illum over its own sector every 45–60 s. It costs the player nothing from his
allotment (it is the base's tube, not his), and it feeds `_light_check` (`siege_director.gd:242-246`),
which is already scoped to the lit circle so it cannot flashbulb the whole assault into existence.

The illum IS the scoreboard: at 660 s the lit ground is nearly empty (dread), at 760 s it is full
(weight), at the break it is empty again with backs turned (decision). No number, no HUD.

**SACRIFICES:** it devalues the player's own illum mission — his most tactical fire-support verb becomes
"the thing that was already happening". Mitigate by keeping the cadence sparse (45–60 s, one round) so
his own round is still the one that lights the *sector he chooses*. Also a real perf cost: `IllumFlare`
is a live light and ADR-026 is why explosions are fake emissives. **One at a time, hard-capped.**
**PILLAR:** serves 2 (atmosphere) and 1; strains the call budget.

**RULING 2B — the break must be audible.** On `_break_siege` (`siege_director.gd:340`): a withdrawal
signal — whistle/bugle from the tube line — and the illum stays lit over the emptying ground while the
reap runs (`_process_reap`, `siege_director.gd:368-392`, 90 s timeout). The toast at
`field_director.gd:1323` then confirms what he already heard, instead of being the only evidence.

**SACRIFICES:** a stock "enemy retreat" cue is a wargame convention and can read as gamey. Keep it
faint and far — it is the *enemy's* signal, heard across 200 m of dark, not a UI sting.

**RULING 2C — the siren is reserved for the escalation, and that is already correct.** Do not soften
`field_director.gd:1294-1298` to make the probe louder. The siren's meaning is built entirely out of the
minutes it does not sound. RULING 1A must therefore route the reinforcement through the same
`_on_siege_began`-equivalent path so the siren and `CRISIS_CALL` fire at 720 s — the escalation is where
they earn their keep, and if `reinforce` bypasses them the demo loses its loudest beat.

**Nothing else is needed.** No breach banner, no "PERIMETER COMPROMISED" toast, no red vignette. The
hole in the wire, lit, with men in it, is the most legible thing this engine can produce.

---

## 3. PROBE vs SIEGE — the forced numbers

`PROBE_MAX = 11` (`siege_director.gd:17`), `is_probe = run_strength <= PROBE_MAX`
(`siege_director.gd:157`), sappers are `2d6` clamped to strength (`siege_director.gd:171`),
`LIVE_CAP = 50` (`siege_director.gd:36`), break at 42.5 % killed (`siege_director.gd:30`).

**The probe: KEEP 11.** It is `PROBE_MAX` exactly — the largest roll that still reads as a probe. In a
demo the probe's job is not to be survivable, it is to be **legible as insufficient**: 2d6 sappers
(avg 7) plus a few regulars is enough to put satchels on the wire and kill a man, and not enough to
threaten the base. Any lower and it is three men and reads as a broken feature — the exact failure the
`PROBE_MAX` comment names (`siege_director.gd:15-17`). Any higher and it stops being a probe and steals
the escalation's thunder.

**The main assault: 40 → 45, expressed as a TOTAL, applied as `reinforce(45)`.** The defence is
arithmetic, and it is `LIVE_CAP`:

- `_enforce_live_cap` (`siege_director.gd:250-261`) freezes dormant cells once **50 materialized men**
  are alive. A frozen cell is a cell standing still in the dark at the ring. That is the "capped assault
  trickles in and never reads as the mass attack the roll describes" failure the Summoner ruled on
  2026-07-28 (`siege_director.gd:33-36`).
- 45 total, with the probe's survivors already on the field, keeps materialized men in the low-to-mid
  40s and **never touches the cap** — every man the demo rolls is on the ground, on screen, at once.
- Break at 42.5 % of 45 = **19 dead** before they pull back. Against a promoted garrison plus a squad
  plus the player, that is a fight with an arc — long enough to have a middle, short enough to be
  decided inside the ~5 minutes between 780 s and the ceiling.
- 50 (the d50 ceiling) is the wrong number precisely because it sits **at** `LIVE_CAP`: it buys five men
  and pays with the deferral that makes the assault look broken. Spectacle is not the largest number, it
  is the largest number that all arrives.

**SACRIFICES:** 45 is the demo's rail — no boot ever rolls a quiet night, which is a lie about the
campaign's actual cadence (`NIGHT_CHANCE` tops out at 0.45 for CRITICAL, `siege_director.gd:12`). And 19
dead is a lot of bodies at the perf floor. **PILLAR:** serves 1 and 2, strains 3 and the call budget.

---

## 4. D3 — AMBIENT WAR AUDIO

**RULING: FASTER. Keep the event rate; fix the SHAPE of the event.** Explicitly rejecting "less
occurring".

Why. `_roll_events` fires 1–3 events per `SimClock.hour_advanced` (`ambient_war.gd:22-33`) at 400–800 m
(`:40`), each with a `lifetime_s` of 5–30 s (`:42`) — and `_spawn_audio` plays **one one-shot**
(`ambient_war.gd:55-70`): `shot_distant.wav` for `tracers`/`gunship_attack`/`burning`,
`explosion.wav` for `artillery`/`mortar`. The `lifetime_s` field governs nothing but when the (already
finished) player is freed (`_process`, `:85-95`). So the event's *duration is fiction*: a 30-second
firefight is a single pop followed by 29 seconds of a silent audio node.

That is why his ear objected. **The defect is not frequency, it is that one shot is not a firefight.**
Making it rarer would subtract from the one pillar this system exists to serve (2, atmosphere) and would
leave the tell intact: a lone distant pop reads as a bug either way.

**What a firefight sounds like from 400–900 m at night.** The supersonic crack is directional and lost;
what arrives is the dull thump of muzzle blast, heavily low-passed by air and foliage, **late**, and
above all **in bursts**:

- 3–8 rounds inside a second, then **2–6 s of nothing**. Never metronomic — the gaps carry the meaning.
- **Two sources**, 15–40 m apart on nearly the same bearing, different timbre, answering each other in
  alternation with occasional overlap. One side is always heavier.
- An MG in longer 8–15 round rips that stand out against the rifle chatter.
- Punctuated every 10–20 s by something heavier — a grenade or a mortar — with a slap and a **tail of
  echo** that the small arms do not have.
- The whole engagement rises, plateaus, and **stops raggedly**, not on a fade.

**Implementation shape.** Give the roster entry a burst schedule and drive it from the existing
`_process` (`:85`) instead of only reaping: per source, a jittered `next_shot_ms` / `rounds_left` /
`next_burst_ms`, retriggering **one** `AudioStreamPlayer3D` per source (`play()` restarts) rather than
allocating per round. Two sources per firefight event. Low-pass it: `SirenTower` uses
`attenuation_filter_cutoff_hz = 2000` at 900 m (`siren_tower.gd:24`); distant small arms want lower,
~800–1200 Hz. Split the `KINDS` list (`ambient_war.gd:12`) so `firefight` is its own kind with the
volley shape and `artillery`/`mortar` stay single heavy events with the echo tail.

**SACRIFICES:** more voices in flight and more `_process` work — small, but this project is call-bound
and `_spawn_visual` already shares `GunFX.MAX_EXPLOSIONS` (`ambient_war.gd:74-80`). Cap concurrent
firefight events at 2. And a scripted volley pattern will become recognisable on a long listen; jitter
is the only defence. **PILLAR:** serves 2 directly — this is an atmosphere-pillar item and should be
judged by ear at the cot, not by a log line.

---

## 5. F2 — THE MAP'S TWO VERBS

**The code corrects the report.** `_on_sheet_input` (`topo_map.gd:369-386`): LEFT click calls
`_objective_at(mb.position)` and **does nothing at all unless the click lands within
`OBJECTIVE_HIT_PX` of an offered circle** (`:376-380`). RIGHT click always places a pencil mark
(`:381-386`). So the two verbs do not overlap on most of the sheet — **left-click on open paper is
simply inert**, and that inertness is what he read as "only right-click places a mark". The hint string
(`:414`) tells the truth and nobody reads hints.

**RULING: LEFT is the pencil. RIGHT is the eraser. The order circle stays a LEFT-click hotspot.**

- LEFT on open paper → place a pencil mark (`state.add_pencil_mark`, `topo_map.gd:383`) and open typing.
- LEFT within `OBJECTIVE_HIT_PX` of an offered circle → `_toggle_route` (`:399-406`). Unchanged.
- RIGHT anywhere → rub out the nearest player mark within a small radius. Nothing else.

Why this and not a modifier key or a mode toggle: **left = make a mark, right = unmake it** is the verb
pair every human has already learned from every drawing tool, and it costs nothing to discover. The
current arrangement asks the player to learn that the *primary* button is reserved for a *secondary*,
rarely-used act (re-sequencing four offered circles) while the act he does constantly is on the
secondary button. That is backwards.

It also fixes a real gap: **there is currently no way to erase a pencil mark at all.** `add_pencil_mark`
has no counterpart in this file. A grease pencil you cannot rub out is not a grease pencil, and ADR-022's
whole conceit is that the player's layer is his own fallible belief (`topo_map.gd:288-290`,
`:265-268`) — a belief he must be able to revise.

**SACRIFICES:** a mark can no longer be placed on the ~14 px under an offered circle. Trivial — a circle
already *is* a mark of that ground. And the erase verb is a new destructive action with no undo; keep the
hit radius tight so it cannot eat a mark he meant to keep. **PILLAR:** serves 3 (freedom — the map is
his plan, not the game's checklist) and 4.

**F3 stays parked**, per his explicit ask. Nothing above prejudges the Arma research: it is a two-line
rebind of verbs that already exist, and if F3 later rules for double-click-to-place or a drag-pan, this
change is what gets replaced, not something built on top of.

---

## 6. THE FLOATING ROUND — (a) ships today, and it is NOT a fossil

Measured facts from the briefing, consistent with the manifest: `mosin_fp.glb` exports
`stripper_clip_Mosin` + `Mosin_clip_round_1` as a **root** node ~0.5 m off the gun, `mosin_idle` never
touches it, and `tools/viewmodel_manifest.json:237-240` lists mosin `parts` as **only**
`["Mosin", "Mosin_boltknob"]` — the stripper is exporting **without being a declared part**.

**RULING: (a) ships today, written as a CONTRACT, not a patch. (b) remains his work and lands when he
is next in Blender.**

The judgment is a playtest judgment. He is testing **now**, and this object sits in the exact centre of
the frame he stares at for the entire 20 minutes. Of everything on this backlog it is the loudest lie in
the picture, and (b) requires his hands plus a re-export he cannot perform mid-session. A day of
playtesting through a floating cartridge costs more than the fix.

**And (a) does not become a fossil when (b) lands — provided it is written as the general rule the
manifest already implies:** *at viewmodel load, any node in the GLB that is not a declared `parts`
member, not a declared `contacts` target and not a marker is hidden.* The manifest is the authority
(`tools/viewmodel_manifest.json`), and the export gate already reads it. Then:

- The moment he declares the stripper in `parts` and seats it, **the same code stops hiding it with no
  edit.** The mechanism inverts itself; there is nothing to delete, so ADR-023 has no corpse to bury.
- It catches the **next** undeclared export on any of the nineteen rigs, instead of waiting for him to
  spot it in a playtest.
- A mosin-specific `if name == "stripper_clip_Mosin"` **would** be a fossil, and it is the version to
  refuse. Same for hiding it in `mosin_arms_viewmodel.tscn` (`scenes/weapons/mosin_arms_viewmodel.tscn`
  is a bare GLB wrapper today) — a scene-level hide is invisible to anyone reading the manifest.

**SACRIFICES:** no visible charger during the reload. Nobody will mourn a charger that was 0.5 m off the
weapon in the one clip that animated it, on a single channel. The charger-feed beat becomes **his**
Blender work — declare the stripper, seat it at the receiver, key its visibility across
`mosin_round_load` — and it should go on the art track with the other E-items, not be blocked on. Second
sacrifice: a load-time hide is silent, so it must **print what it hid**, or the next reader concludes the
Blender file is clean when it is not (POINTER LAW, and the instruments list at
`DEMO_SHIP_BACKLOG.md:136-147` is the pattern to copy).

**PILLAR:** serves 2 and 1 — the viewmodel is the one asset on screen 100 % of the time, and a prop
hanging in the air unmakes every other thing the frame is doing right.

---

## 7. THE FIRST 60 SECONDS — the one change I would make

**The player boots with no facing.** `spawn_player_at` (`game_world.gd:429-437`) writes
`global_position` and never touches rotation; `game_flow.gd:596-622` picks a cot and seats him. So he
opens his eyes pointed at whatever the player scene's default yaw is — world −Z — regardless of what is
worth looking at.

Meanwhile the demo's most expensive authored beat, the **Huey putting down on the pad with troops
disembarking** (`demo_game.gd:69`, the ship gate's own clause), fires at **14 seconds**. There is no
reason to believe it is in front of him. **A spectacle beat outside the frustum is a beat that did not
happen** — and it is the beat he asked for by name.

**Ruling: the demo boot sets the player's initial yaw so the LZ (and past it, the sector the night will
come from) is in frame at t = 0.** Diegetic and free: a man waking on a cot faces the way the cot faces,
and the cot faces the pad. Nothing else in the first minute needs to change — the sky package at 3 s and
the base's own life fill the frame perfectly well **once the frame is pointed somewhere**.

That is the cheapest line on this entire document and it is worth more to his first impression than any
other item on the list.

**SACRIFICES:** the demo asserts a camera direction, which is the first authored frame in a game whose
third pillar is no rails. It is one yaw value at boot in a slice scene that already owns the arc clock —
acceptable there and **nowhere else**.

---

## SUMMARY OF RULINGS

| # | ruling | sacrifice | pillar |
|---|---|---|---|
| 1A | probe ESCALATES via `reinforce(target)`; delete the toast-only branch | the demo's night is always the assault | +1 −3 |
| 1B | dawn card fires on `siege_ended`; 1080 s is a ceiling | demo length no longer fixed | +5 +2 |
| 1C | assault objective is a QUEUE (wire → bench), unlocked by the breach; never `assault_driven` | edges toward choreography | +1 |
| 2A | the garrison lights its own wire — siege-owned illum, 45–60 s, one at a time | devalues the player's illum; real light cost | +2 +1 |
| 2B | the break is AUDIBLE; illum holds over the emptying ground | a retreat cue can read gamey | +2 |
| 2C | the siren stays reserved for the escalation — do not soften the probe | the probe is quieter than it "should" be | +2 |
| 3 | probe 11 (keep); main assault **45 total**, never 50 — `LIVE_CAP` is the reason | rail; 19 bodies at the perf floor | +1 +2 −3 |
| 4 | ambient war: **FASTER**, event becomes a two-source burst pattern; reject "rarer" | more voices; pattern recognisable on a long listen | +2 |
| 5 | map: LEFT = pencil, RIGHT = erase, circle stays a LEFT hotspot; F3 parked | no mark under a circle; erase has no undo | +3 +4 |
| 6 | hide any GLB node not declared in the manifest, and PRINT it; (b) is his art-track work | no charger in the reload | +2 +1 |
| 7 | **set the boot yaw so the 14 s Huey landing is in frame** | the demo authors one camera direction | +2 −3 |

**The two things that must be fixed before anything else on this list matters:** `SIEGE_STRENGTH` is
never applied (`demo_game.gd:197-203`), and the dawn card races the break
(`siege_director.gd:40` vs `demo_game.gd:28`). Until those land, "the VC attempt to overrun the
firebase" cannot be seen no matter what else is built.
