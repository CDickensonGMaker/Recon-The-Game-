# THE DECREE — Demo backlog, 2026-07-30

Council: systems architect · lead programmer · game designer · devil's advocate · technical
artist. Five architects, parallel, no cross-talk. Analyses in `analysis/`.

**The Arbiter overruled the council four times and the council overruled the Arbiter twice.**
Both are recorded below, because a synthesis that hides its corrections is the drift the
POINTER LAW exists to stop.

---

## WHAT THE COUNCIL FOUND THAT NOBODY WAS LOOKING FOR

**1. The demo's night assault has never happened.** `demo_game.gd:29` declared
`SIEGE_STRENGTH 40`. At 720 s `_open_siege` hit the `if d.siege.active` guard (`:197-203`)
and emitted a toast. The 600 s probe was still active *and always would be* — its
`MAX_DURATION_S 480` expires at exactly `DAWN_AT_S 1080` — so the branch was taken every
single time. **Every demo night ever played was 11 men, announced twice.** `open_siege`
also returns immediately when active (`siege_director.gd:143`), so there was no path in.
Verified independently by the Arbiter before acting.

**2. The CAS gun run kills the player and the whole garrison, and its own comment says
otherwise.** `STRAFE_MASK = 1|32|64|512` (`cas_airplane.gd:66`); layer 32 is the PLAYER
HURTBOX, proven twice over at `projectile_base.gd:111` and `ally_base.gd:441-442`. The
comment above it calls bit 32 "enemy bodies". `aircraft_20mm.tres` base_damage 87 × TORSO
2.5 = **217 against 100 HP**. Shipped 7/29, never playtested, and the demo fires scripted
gun runs at 2:40 and siege+60 s.

**3. `ACTION_WORK` never walked a man to his post.** Seven BT leaves in `civilian.gd`
(`:710/718/726/734/742/750/756`) were byte-identical freezes. Twelve scheduled actions
collapsed to four behaviours. So the entire 7/29 A3 night shift — sentry_night, gun crew,
radioman, quartermaster — **never manned anything**; it only looked right because
`place_for_current_hour()` teleports everyone at spawn. The 191-marker pipeline was
complete end to end and `bb["target_pos"]` was populated every sim hour, read by nothing.

**4. The Mosin plays no animation at all.** It exports `mosin_*`-prefixed clips; every
other gun exports bare `rifle_idle / reload / reload_empty / charge_handle / fire / jam`.
`weapon_holder.gd:929,937` ask for the literal strings, `has_animation()` returns false,
and the gun sits in its rest pose. **The floating round he reported is a symptom of this**,
not a separate bug: no clip is running to move anything. Root cause is the exporter
whitelisting by COLLECTION MEMBERSHIP rather than by the manifest's `parts`
(`export_viewmodel_clips.py:44,317-320`), and `tools/validate_viewmodel_glb.py` already
fails mosin on 17 lines — it had never been run.

---

## WHERE THE ARBITER OVERRULED THE COUNCIL

**a. "The licensed gun audio is being overwritten with synth right now."** REFUTED.
The offered proof was that `fire_m16a1_1.wav` and `fire_car15_1.wav` are byte-identical.
They were **already byte-identical at HEAD** (`d4a371c2…`), so the pair-identity proves
nothing about this session. No `git checkout` was run on his audio on the strength of it.
What DOES stand: `CREDITS.txt` credits generated files to "Snake's Authentic Gun Sounds".
That is a licensing-doc question for the Summoner, not a code fix.

**b. "Four explosion wavs were deleted and every explosion may be silent."** REFUTED.
`audio_manager._explosion_variants` (`:429-442`) tries `_1/_2/_3` and falls back to the
flat name. The 7/27 pack migration is coherent.

**c. "`ai_stress_arena.gd:56,277` reference a dead `DestructibleFortification`."** REFUTED.
Zero `.gd` hits repo-wide. Every reference lives in ADR-031 and dated war-room records,
which are archival by design, not live claims. Not a fossil.

**d. "Cut C3 and defer the vulcan."** OVERRULED on the Summoner's ruling. He chose the
cheap C3 now with the proper version tracked, and he ruled that air may kill him — which
retires the friendly-fire objection the deferral rested on.

## WHERE THE COUNCIL OVERRULED THE ARBITER

**e. The press design the Arbiter brought in was wrong, and dangerous in a specific way.**
The proposal was a timed `press_assault(to, drive_s)` setting `assault_driven` with a
countdown. `assault_driven` short-circuits the combat FSM before the dispatch at
`enemy_base.gd:1322`, so **a driven man cannot shoot at all** — 0.40 × 4/9 ≈ 17.8% of the
assault permanently mute, up to 20 men at `LIVE_CAP`. That is the 2026-07-29 playtest bug
("the VC started running at the base and no one fought besides me") on a duty cycle, and
worse for being subtle. Worse still: a countdown expiring after `_break_siege` would clear
`assault_driven` and cancel `withdraw_to` (`marching_cell.gd:155-156`), so the man never
reaches a rally, the reap cannot collect him, and ghosts accumulate — exactly what
ADR-035 §10 gate 1 forbids.

**f. The Arbiter's fallback — "reissue the objective at the breach" — also fails**, and the
Summoner had already approved it before the refutation arrived. `enemy_base.gd:1309,1313`
clears the objective the same frame for anyone in COMBAT, i.e. everyone at the wire. Zero
mute men and zero movement. **The Summoner was told the mechanism changed.**

---

## THE DECREE

**C3 — THE OVERRUN. Bias the GOAL, never the legs.** The stall was never the objective
clearing; it was arithmetic. `combat_goals.gd` scored ADVANCE at most **0.61** for an
nva_regular (aggression 0.65, ×0.45 open-ground penalty) against an incumbent ENGAGE of
**1.19**. A full bounding rush that fires on the move already exists
(`enemy_base.gd:1572-1643`). So: one `assault_press` bool on `CombatGoals.Context`,
`PRESS_ADVANCE 0.75` (the smallest term that clears 1.19 with margin), and the ×0.45
unsupported penalty waived while pressed. Fed by `EnemyBase.siege_press`, rotated by
`SiegeDirector._rotate_press` on its existing 0.5 s poll — `PRESS_CYCLE_S 8.0`,
`PRESS_FRACTION 0.35`, deterministic phase, never a satchel man, never a probe. A pressing
man still shoots. Cleared on `_break_siege` so a withdrawal is never fought by a press.

**THE LANE IS THE GATE.** Nothing re-bakes the navmesh when a segment dies
(`nav_baker.gd:16-18`) and the barbwire is ONE merged `bwire_card_ring` of ~450 cards on
three rings (`gen_firebase_v3.py:323-372`), so three impassable rings stand outside any
hole you blow. The gate is the only opening through both — and it is also the doctrinally
correct answer: PAVN/VC night attack under *nhất điểm lưỡng diện* goes through ONE lane in
2–5 man rushes, not over a line. Parapet destruction stays spectacle. **Nothing in the
overrun reads a breach**, so nothing is blocked on art.
*Sacrificed:* a real hole in the perimeter. Per-sector wire would cost 36 draw calls where
there is 1, on a call-bound project.

**Overrun is measured, not assumed.** `inside_count()` compares each man against the wall
radius **on his own bearing**, in 36 bins measured from the `fsb_parapet` group — the
parapet runs 49.3 m to 96.1 m, so one mean radius would call men inside on one face and
outside on the opposite. `OVERRUN_MEN 3` raises `siege_overrun` ONCE; FieldDirector answers
with "THEY'RE INSIDE THE WIRE" and the siren.

**THE ESCALATION.** `SiegeDirector.reinforce(extra)` — requires `active`; grows
`run_strength` **and** `run_peak` together (strength alone drives live/peak above 1.0 and
the break can never fire; peak alone credits the player kills he never made); same
`sector_bearing`; recomputes `is_probe`; re-emits `siege_began`. Never touches `nights_run`,
`_elapsed` or `_mortar_timer`. `SIEGE_STRENGTH` 40 → **45**, and it is now a TOTAL, not an
increment: `LIVE_CAP` is 50 materialized men and an assault authored at the cap freezes its
late cells at the ring, which is the 2026-07-28 trickle failure.

**FRIENDLY AIR — his ruling, verbatim:** *"i want to be able to be killed by the air but i
dont need a warning. but also dont deliberately gun run where the player is unless they
call in a danger close run."* So the MASK stays lethal to everyone and there is NO warning
call. The discipline lives in AIMING: `authored_strike` gains `danger_close`, and without it
a gun run's beaten path must miss the player by `GUN_STANDOFF_M 120`; the axis is rotated
through 12 bearings to find one that clears, then guns are dropped (napalm kept) or the run
is refused. `[G]` passes `danger_close = true` — pressing it IS calling it in, and the axis
he chose must be the axis that flies or the key is useless for tuning feel. `AirTraffic`
now keeps ambient Spectre orbits `SPECTRE_KEEP_OUT_M` off **the player**, not just his base.
*Sacrificed:* you can still be killed by air you did not call, which is the point.

**THE VULCAN IS REAL.** Fired per PHYSICS TICK, not on an interval: `VULCAN_ROUNDS_PER_TICK
3` = 90 rounds/s. Slant range √(160²+130²) = 206 m at 1030 m/s = 0.20 s flight = ~18 rounds
in the air, i.e. 18 segment raycasts a tick — `MAX_BULLETS 500` is nowhere near binding.
90/s is chosen for the ROPE: a tracer streak is speed×0.016 = 16.5 m and at `tracer_ratio 2`
that lights ~148 m of the 206 m line. Duty 2.0 s hot / 2.5 s cold. Muzzle on `-basis.x`, the
port side, which already carries the pylon bank. Dispersion is preserved by re-aiming a
fresh `_zone_point` every tick rather than trusting weapon spread — the fake gun's 25 m disc
was 25× the area of a 1.4° cone at 206 m, and losing it would make the gun read as broken.
**KEPT deliberately:** suppression (BulletSystem suppresses nobody; the fake explosion was
this gun's only source) and the report on its own 0.35 s clock (`_play_gun` reuses ONE voice,
so 90 calls/s would leave the aircraft silent).
**ADR-023 — buried in the same change:** `scripts/combat/bullet_tracer.gd` DELETED (the fake
vulcan was its only caller repo-wide), `VULCAN_DAMAGE`/`VULCAN_INTERVAL`/
`VULCAN_ROUNDS_PER_BURST`/`_vulcan_timer` gone, and `FirePlan.SPECTRE_VULCAN_KILL_M` renamed
`SPECTRE_DISPERSION_M` — it could not simply die, `fire_plan.gd:58` draws the map ring from it.
**New:** `BulletSystem.fire(..., mark_surface := true)`. `GunFX` recycles bullet holes FIFO at
`MAX_DECALS 48`, so 90 rounds/s would erase every hole the player made twice a second.

**A4 — `_bt_work` WALKS.** Walks to `bb["target_pos"]`, then holds, with a ±1.5 m offset
derived from the man's NAME so it is identical every run (ADR-010 — never Time, never an
unseeded roll). `off_duty`'s 20.5–22.0 block flipped SIT → WORK: those are the demo's own
opening hours and a base of seated men reads as a base with nothing to do.

**D3 — AMBIENT WAR: FASTER, and "rarer" REJECTED.** `_spawn_audio` called `play()` ONCE per
event; `lifetime_s` only decided when the finished node was freed. **A whole distant
engagement was one gunshot.** Now two parties 15–40 m apart ANSWER each other, each
retriggering its own voice on a burst clock: 3–8 rounds at 0.11 s (MG 6–14 at 0.075 s), then
a 2–6 s lull, going ragged in the last quarter of its life. Low-passed at 900 Hz — past
400 m a rifle has no crack, only a slap off the treeline. Lifetime 5–30 s → 14–40 s, because
5 s cannot hold a rhythm. `FIRE_CAP 2`, and a held engagement PRINTS that it was held —
a silent cap reads as coverage.
Also adopted the 7/27 pack: it was still on the generic `shot_distant.wav` for every gun in
the war while a measured `fire_<id>_dist.wav` existed for all 17.

**F2 — THE CODE CORRECTED THE REPORT.** Left-click was not fighting the order circle: off a
circle it did **nothing** (`topo_map.gd:376-380`). The map's main verb was on the button
nobody reaches for first. **LEFT is now the pencil** (a circle is a small hotspot and still
takes a left click, so they cannot compete for a pixel); **RIGHT is the eraser**, which the
sheet has never had — marks went on and stayed forever. New
`MissionState.erase_pencil_mark_near`. The grease-pencil law forbids the GAME erasing a
mark; it says nothing about the player. F3 (Arma research) stays parked at his request.

---

## NOT DONE, AND WHY

- **D1 CONVOYS — DEFERRED.** The brief's premise is wrong: routing already exists
  (`mission_generator.gd:337-342` refuses to spawn without a road), but `build(gate,
  villages)` makes the gate the hub, so there is **no map-edge road** and convoys drive
  outward into a village. The visible defect is `convoy_spawner.gd:86` stringing the column
  along `-heading`, dropping vehicles 2–6 up to 30 m INSIDE the wire — that is the "drives
  through buildings". Driving the road is one session; driving through the gate is
  multi-session. Invisible in a 512 m firebase-holdout slice.
- **THE MOSIN — HIS, AND CLOSED.** His instruction mid-session: *"skip anything with the
  mosin, im live working on that, and this might be interfering with it."* He was re-exporting
  it live (the clip list changed between two separate measurements twenty minutes apart).
  Nothing here wrote to a Mosin asset: the GLB was parsed read-only, no Blender tool ran, and
  **no Godot-side workaround was shipped** — a runtime hide would have masked a gun that plays
  nothing. It is excluded from all commits after the safety commit.
  **The transferable finding is a CODE contract, not his art:** `weapon_holder.gd:929,937` ask
  for the literal clip names `rifle_idle` and `charge_handle`, so ANY viewmodel exported with
  prefixed clip names silently plays nothing. That is worth a validator line for all 19 rigs.
- **THE FULL PARSE GATE.** His Godot editor was open; two editors writing `.godot/` can
  corrupt the import cache. `--check-only --script` over all 17 changed files produced
  **zero `Parse Error`s** (the syntax pass) and 13 `Compile Error: Identifier not found`,
  every one naming one of the 14 autoloads in `project.godot:32-44` — the documented blind
  spot. That proves no syntax errors and **cannot** prove no type errors. The full
  `--headless --editor --quit` scan is owed the moment his editor is closed.

## TRACKED, WITH DELETION CONDITIONS

- **The real breach** replaces the gate lane: split `bwire_card_ring` per sector in
  `gen_firebase_v3.py`, re-export, add a nav re-bake on `Destructible` death. When that
  lands, the gate-only lane stops being the whole answer.
- **`m60` markers are severed at ruler coords** and `M60_chandle_charge_handle` carries
  non-uniform scale (0.231, 0.447, 1.0) — a tumbling charge handle, live via `m60.tres:36`.
- **`rpd`, `ithaca`, `rpg2` are stale 2026-07-11 exports**: wrong gun-root name, only
  `rifle_idle`, no sights. All three loaded by live `.tres`. Manifest already declares their
  parts, so this is a mechanical re-export.
- **`flashlight_fp.glb` contains a stray whole `Colt45_Pistol`** dead centre of frame. Zero
  references, harmless today.
- **`LIVE_CAP` is 50 in code, 18 in ADR-035:253.** One of them is wrong and the ADR is canon.
- **One shared `squad_id`** throttles the entire assault to one grenade per 12 s.
- **`_crowding_cost` is O(all claims) inside a sort comparator** — superlinear, revealed not
  caused by this work.
- **If sappers are ever re-aimed at the wire**, `on_firebase_breach` will falsely toast "the
  munitions dump is gone" and really zero his mortars.
