# THE DECREE — the map, the dealer, the HQ chain, the bird, the beats, the observatory, the ears (2026-09-14)

**Arbiter:** the RECON Overseer, for the Summoner. Council of five (`analysis/`), debate in
`discussion.md`, map study in `study_large_maps.md`. **Branches:** perf / combat / base-sim on
`BaseGame-V1` first, merged forward; game state on `RPG-build` only.

## The judgment

His eight asks are three kinds of work and the council sorts them so none is faked:

- **Wiring that finishes half-built systems** (the Huey crash, the audibility mix, the observatory
  extension, the third simulation ring): built tonight on the existing seams, gated headlessly.
- **New game state that reads the one ledger** (the HQ taskings, the dealer's two asks, three beats):
  built on `RPG-build` as data + a few predicates, felt never read (ADR-038 §2a), with the assault never
  waiting on any of it.
- **World-shape changes with no measurement behind them** (the bigger map, the stream funnel, the
  authored-place set): shipped behind a flag with headless proxies, the fps pair left for HIS window,
  and the terrain authoring put to him as the ADR-041 thaw question by name.

The 3x map is not "more jungle": it is ROOM so the village, the crash and the camp are out of each
other's hearing (GUNSHOT 150 m), which today they are not. That room is bought by moving plan radii
(legal, ADR-039 clause 1) and by making the sleeping ring correct — not by streaming (ADR-013) and not by
a hand-wired scene (ADR-041).

## Rulings

1. **MAP.** `DEMO_MAP_SIZE` becomes a flag `--demo-map=N` (default **1024** once the proxies pass;
   512 stays one flag away for his A/B). 890 is refused as a number the engine cannot build. Ships
   with: the watchdog scan TIME-SLICED (≤ 12 bodies per tick, no raycast for a suspended man), the
   sleep-radius invariant `SUSPEND_DIST > max noise radius × multiplier` asserted by a test, sappers and
   COMBAT men exempt from suspension, civilians snapped to their scheduled post on wake when unseen,
   airframe visibility 1200 → 1500. Demo plan radii grow: village ~300 m, camp/ZPU ~330 m on the
   east flank, the slick's inbound lane authored across the ZPU's disc and clear of the wire, temple
   south. **Proxies measured headlessly at 512 vs 1024, same seed:** load time, `OBJECTS_IN_FRAME` /
   `RENDER_TOTAL_DRAW_CALLS_IN_FRAME` at world-ready (headless draws nothing — node census instead),
   `MEMORY_STATIC`, census stuck/overlap. **No fps number is written by anyone but him** (`perf_walk.bat`
   at 512 and at 1024, same evening — the paired pair). ADR-013's "AO of record 1280" pointer corrected.
2. **AUTHORED PLACES.** The set of record for the demo AO: firebase (TOC, the dump), the village seen
   twice, the crash site NE, the VC camp + ZPU E, the temple + ruins S. **The stream funnel, the three
   fords, the band-gated way-station and THE CROSSING beat are the ADR-041 thaw question for HIM** —
   "thaw ADR-041 for the demo AO: yes or no" — not built tonight.
3. **THE DEALER — a thaw of the FROZEN "RPG shop", by his words today, named as such.** SSG Virgil
   Poteet, supply, the `quartermaster` at the dump. The three guards bind: never from corpses,
   everything consumable, **never a weapon in either direction** (D1 "a captured rifle" REFUSED). Two asks
   this session: **D-CASE** (walk a case down to the ville → `trade/<village>/p<n>` KIND_TRADE deed →
   the same crate model appears in the camp's cache) and **D-SACK** (the slick's mail sack vs the TOC's
   manifest: one object, two claimants). Prices are objects for objects and never move; the rack moves;
   his lines are keyed by which ids are closed, never how many; unprompted within 6 m. UI = the
   armorer's `BenchMenu` shape on `[F]`; the journal ORDERS page lists both hands' asks.
4. **THE HQ CHAIN.** `CampaignState.taskings` (id → {state, since, cause, claimant}) shared by both
   claimants. **H1 eyes-on the ville** (issued at the gate order; closes on a walk through with no
   `fire/`/`civ/` deed; band lever = what the ville gives: a real mark / a decoy / nothing + the
   responders), **H3 the downed bird** (issued BY the incident; closes on survivors registered or tags
   handed in; lever = who hunts the site: pickets 2/3/5), **H4 before dark** (issued at DUSK; closes on
   the bank; lever = the warning present or withheld, as built). H2 the camp is deferred to keep the
   day inside the clock. **The assault never waits on a tasking.** "Patrol density" and "ambush odds" are
   day-2 plan-time consumers and are not promised for the demo.
5. **THE HUEY CRASH (his ruling).** The 11:30 `lz_cycle` slick is the demo's one shoot-down (the
   Skyraider keeps the open world's 35%). `Helicopter.shoot_down(crash_pos)` writes the CRASHING state
   the code never set; the ZPU accepts `"huey"` in demo mode on the inbound leg; `PilotRecovery`
   generalises `_pilot` → `_men`. **The roll is seeded** (`mission_seed ^ hash("huey/day1")`): pilots
   alive 1–2 of 2, pax alive 1–4 of 3–6 aboard, wounded among the living with speed 1.0 / 0.6 / 0.35;
   the dead lie at the wreck (bodies give intel only; tags). Survivors are the slick's own men through
   `GarrisonDefender.promote`, FOLLOW the player in a file at the slowest man's pace, HOLD if he
   outruns them past 60 m, and `stand_down` into `firebase_garrison` (`patient` / `off_duty`) at
   `HOME_M`; the casualty ledger takes `crash_kia` / `friendly_wia`; H3 closes. The radio is the
   writer's six lines (PINK PANTHER / GRAPE / DUSTOFF), survivors' first words by role. **Gate:**
   `--crash-probe` over 8 seeds (crash fires, ranges hold and repeat per seed, a leash-walk escort with
   no man stuck twice, the garrison grows by the living, the census does not regress).
6. **BEATS on the existing runner.** Authored as JSON in `data/beats/` fed into `ScriptedSequence` +
   `MissionTrigger`, once-per-day ids, player keeps control, abort intact. Built: **THE BARRELS**
   (06:30–07:30 at the burn pad — the detail NCO's claim and Poteet's unprompted price), **THE BIRD**
   (the crash's radio + survivors' words), **THE WIRE AT DUSK** ("I SWEAR I SAW SKELETONS OUT IN THE
   BUSH" under the first flare, never when a probe man is inside the wire). THE CROSSING waits on the
   stream. Every line is §2a-checked by `test_hearts_felt`.
7. **THE OBSERVATORY.** `ObservationTools` extended into the live world on **F9** (debug builds only):
   per-agent labels with alert tier, LOD ring (NEAR / FAR / ASLEEP), awareness, last-known, last noise
   heard incl. the player's, civilian action + village band; an `ImmediateMesh` layer for sight cones,
   target lines, last-known, noise circles, witness arrows; a side pane for the selected man with a
   10-deep decision ring (enum + cause, formatted at read time) and the STUCK reason in the census's
   own vocabulary; a ledger pane (deeds + causes + band per village, taskings). Zero cost when off.
   Map pane and time-scrub are named follow-ups.
8. **JUNGLE AUDIBILITY (both branches).** `STEP_AUDIBLE_M` 28 → 48 walk / 64 sprint, crouch ×0.5;
   a distance-priority voice pick (nearest wins a full pool); one occlusion ray at voice start
   (low-pass + −9 dB when blocked); enemy/ally steps emit throttled `FOOTSTEP` noise for the allies and
   the observatory; a 2D self-step so the payer hears his own loudness. Brush/kit layers wait on wavs.
   Bench: AudioStreamPlayer3D count under `--stress=assault` printed; his ears decide the mix.

## Refused / deferred

- 890 m (unbuildable) · D1 captured-rifle trade (the guards) · H2 the camp tasking (clock) · the
  stream / fords / way-station / THE CROSSING (ADR-041 thaw — HIS call) · the second firebase, a second
  village, a plantation (GD §1.5) · the ears, the beating, the sniper, the shooting (FMV or post-demo) ·
  a per-frame far simulation (the sleeping ring is a snap on wake) · the map pane / time-scrub · a
  litter carry (no `fb_litter` export) · any fps sentence from a headless run.

## What is sacrificed (law 2)

- The Skyraider loses its demo guarantee; one event a day, the slick takes it.
- Reputation cannot be spent, only foregone: siding with Poteet costs the report that never banks.
- A CRIT survivor at 0.35 speed makes the walk home 3–4 real minutes; the programme absorbs it, a
  player may not — he can leave the man (the mercy fork) and the card says so.
- A sleeping man past 240 m is deaf to a distant firefight by design; alarms do not cross the map
  without a runner (a design item).
- Civilians snap on wake when unseen; a man with binoculars at 250 m can catch it.
- The 1024 default is a proxy-measured change, not an fps-measured one, until his pair is run.
- Occlusion is one ray; a thin wall and a hill sound the same.

## Gates before anything is called done

Headless boot 0 SCRIPT ERROR · `test_hearts_felt`, `test_demo_arc`, `test_demo_planner`, the four NPC
tests, `test_fsb_colonly_contract` green (the pre-existing red `test_firebase_garrison` named, not
hidden) · `--npc-census` with the parapet + duckboards STAMPED (the 19:00 runs had NO wire: stale
import) · `--stress=assault` 0 errors, siege breaks · `--crash-probe` 8 seeds · the map proxies 512 vs
1024 · both branches pushed.
