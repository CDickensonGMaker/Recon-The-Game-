# SYSTEMS DESIGNER — NPC first batch (2026-09-13)

Lens: semantics of *where* each man belongs for each scheduled action, per occupation and per
marker role, read from code — not the plan.

## 1. Occupation x scheduled action -> place

Garrison (`is_garrison=true`). Working point comes from `mission_generator.gd:1219-1221`
(`station`, already fanned per-man off the post — see §3). "Post-place" = a combat/labor
station (wire, gun, radio desk, stove, dump). "Seat-place" = a place built to be sat/loafed at
(hooch marker, chow bench, gun pit at rest).

| Occupation | Action | Should resolve to | Why / evidence |
|---|---|---|---|
| sentry | work | working_point_pos (post-place) | `civilian_schedules.gd:114-119`; post = SOCKET_A/bunker/tower (`site_planner.gd:1208,1214-1215`) |
| sentry | walk_fire, walk_home | home-adjacent (walk_fire) / home | `:112-113,122` — off-post transit, no marker exists for "coffee point" |
| sentry | talk (19:00-20:00) | working_point_pos (post-place) | `:120-121` "handover to the night shift" — a briefing AT the post is correct |
| sentry | sleep | home | `:110-111` |
| sentry_night | work | working_point_pos (post-place, wire/bunker) | `:126-127` |
| **sentry_night** | **sit (13.5-15.0), talk (15.0-16.5)** | **NOT working_point_pos — a seat/hooch place, or home** | `:132-135`. This window is his DAYTIME OFF-SHIFT, right after `SLEEP` (`:131`, "sleeps through the DAY"). His `working_point_pos` is his night COMBAT post (`site_planner.gd:1214` bunker_los / SOCKET_B). Sending sit/talk there stages an off-duty man sitting at a defensive loophole in broad daylight — the exact confusion the schedule's own comment (`:123-125`) says the batch must avoid. |
| sentry_night | sleep | home | `:130-131` |
| quartermaster | work | working_point_pos (post-place, the dump) | `:143,147-149` |
| quartermaster | walk_fire, sleep | home-adjacent / home | `:140-141,145,138-139` — no SIT/TALK ever scheduled |
| gun_crew, gun_crew_arty | work | working_point_pos (post-place, the gun) | `:155-164` |
| gun_crew, gun_crew_arty | rest (23:00-4:00) | working_point_pos (AT the pit) | `:152-153` documented explicitly; no `walk_fire` bridges into it, so home is the wrong distance |
| gun_crew, gun_crew_arty | sit (11:00-12:00) | working_point_pos (at the pit, pre-chow) | `:158-159` — bridges straight into `walk_fire` (chow), consistent with staying at the gun until the walk |
| radioman | work | working_point_pos (post-place, the set) | `:169-170,172-173` |
| radioman | rest (23:30-4:30) | working_point_pos ("the net is never unmanned", `:166`) | `:167-168` — no bridging walk_fire either side |
| mess_cook | cook, work | working_point_pos (post-place: stove / servery marker `cook_range`,`chow_server*`) | `:179-188`; `site_planner.gd:1263,1269,1294` |
| mess_cook | rest (13:30-15:30) | **ambiguous** — home is defensible (a midday hooch nap, not "unmanned" the way gun/radio are) but not schedule-bridged either side (`:183-186`, no walk_fire in or out) | flag for a ruling, not a hard defect |
| mess_cook | sleep | home | `:175-176` |
| mess_hall | work (breakfast/supper window) | working_point_pos (his OWN dealt chow marker — `eat`/`chow_diner`/`queue`) | `:208-211`; occupation is literally "go stand/sit at your marker" |
| mess_hall | sit (12:00-15:00), talk (19:30-22:00) | working_point_pos (chow bench is a real seat) | `:214-216,218` |
| mess_hall | walk_fire | home-adjacent | `:213,217` — no other marker exists |
| medic | work | working_point_pos (post-place: aid station) | `:227-228,231-232,235` |
| medic | rest (23:30-5:00) | working_point_pos ("the aid station is never shut", `:220-222`), no bridging walk_fire | `:223-224` |
| medic | talk (17:00-18:00) | working_point_pos (still at the station between sick-call windows) | `:233-234` — bridged by WORK on both sides, not home |
| patient | work (always) | working_point_pos == the cot, puppet | `:236-240`; `mission_generator.gd:1177-1194` — never a schedule read at all, correctly |
| detail | work | working_point_pos (post-place: dig/burn/wash/water/latrine/pad) | `:250-251,256-257,260-261` |
| detail | rest (13:30-17:30 window, 12:00-13:30) | home (bridged by walk_fire at `:253` immediately before) | `:254-255` — schedule already routes him home via the "fire" beat, so home is the *correct* read here, unlike gun_crew/radioman/medic |
| detail | talk (19:30-21:30) | working_point_pos (crew still at the work site after knock-off) | `:262` — minor, low risk either way |
| detail | sleep | home | `:246-247` |
| off_duty | sit, talk, rest, work (all non-sleep/non-transit) | working_point_pos (his OWN hooch/rest/smoke marker — role and position are the SAME marker) | `:264-285`; marker set at `mission_generator.gd:1216-1217`, chain picked by that same `role` at `civilian.gd:137-143,715`. Position and pose already agree — this is the one occupation where the blanket rule is unconditionally right. |
| off_duty | walk_fire | home-adjacent | `:267,273,279` |

Villages (`is_garrison=false`, unchanged mapping per the Arbiter's item 1 — flagged as a gap, not
attacked as wrong):

| Occupation | Action | Should resolve to | Why / evidence |
|---|---|---|---|
| farmer | walk_paddy, work | working_point_pos | `civilian.gd:1361-1364` already correct |
| **farmer** | **rest (11:00-12:00)** | **working_point_pos (shade at the paddy), not home** | `civilian_schedules.gd:39` — REST sits BETWEEN `WORK` and `WALK_HOME` (`:38-41`) with no bridging transit; walking fully home and back inside one hour reads as a round trip nobody scheduled. `_resolve_target` (`civilian.gd:1361-1366`) sends REST to home today, and item 1 leaves this untouched. |
| farmer | cook, walk_fire, walk_home | home-adjacent / home | no fire/hearth marker exists in `_build_village_site` (`mission_generator.gd:1283-1332`) — honest idle at a fixed offset is the correct fallback, just needs the name-hash swap (item 1) |
| fisherman | walk_paddy ("water-side working point"), fish | working_point_pos | `:52-53,55,59` |
| **fisherman** | **rest (12:00-13:30)** | **working_point_pos (riverside), not home** | `:57` — same bridging problem as farmer, arguably worse: a fisherman's home may be well inland of the water point |
| cook (village) | cook, walk_market | **no place exists — honest idle at home-offset** | village stamp has no hearth/market marker (`_build_village_site` never creates one); `walk_fire`/`walk_market` are fixed `home+Vector3` offsets today (`civilian.gd:1399-1414`) and stay that way under item 1 |
| elder | sit, talk, rest | **no place exists — honest idle at home-offset** | elder has no occupation-specific marker; if he wins a dealt `working_point_pos` from the shared pool (`mission_generator.gd:1312-1319`) it is a stray paddy/water point he never visits (elder's schedule never emits WORK/WALK_PADDY/FISH) — see finding below |

**Finding not in the briefing's five defects:** village `working_point_pos` is dealt from one
shared pool across ALL occupations including `elder` (`mission_generator.gd:1300-1319`,
`pick_occupation` at `civilian_schedules.gd:300-308` rolls elder 20% of the time). An elder who
draws a paddy point never uses it (his schedule has no WORK/WALK_PADDY/FISH branch), so that slot
is permanently withheld from the farmer/fisherman pool that actually needs it — a silent scarcity
bug, worse as village population climbs. Not in scope for this batch, but item 1's villager
pass touches this exact code path and should at least leave a boot-report line for it (the same
"missing content is a finding, not a silent loaf" instinct the Arbiter already applies to
`working_point_pos == ZERO`).

## 2. Exact props vs. areas

**Exact props (zero jitter is right):** `hooch_table`/`hooch_radio` (a chair/desk),
`chow_diner`/`eat`/`queue`/`chow_exit`/`cook_range`/`chow_server*` (bench, stove, servery line —
`site_planner.gd:1263-1275,1292-1295`), `med_cot`/`med_or_patient`/`med_surgical` positions
(`:1289-1291`), `hooch_sleep` (one bunk per marker), the gun/mortar firing position itself
(`gun`, `mortar` work types — one man's literal hands-on-the-weapon spot), `SOCKET_A/B`,
`bunker`/`tower_los_point`, `mg_fire_point` (a loophole you must stand square to, not near).

**Areas (a small deterministic spread is still right):** `dig`/`burn`/`latrine`/`water`/`wash`/
`pad` (a working party along a berm/trench, not nailed to one entrenching-tool mark —
`site_planner.gd:1278-1279`), `rest`/`smoke` (loafing spots, not literal furniture —
`:1303`), and any watch stretch that is a length of wire rather than a named embrasure.

**Where "working point = exclusive = zero jitter" is wrong:** it conflates "this Vector3 is
unique to this man" with "this Vector3 sits on the correct prop." A `dig` marker inside
`DIG_NEAR_M` of a berm (`site_planner.gd:1240-1247`) is exclusive-by-deal but still an AREA — a
work party of three on adjacent dig markers should not stand pixel-identical on each blade mark
every single boot; a whisper of spread (well under today's 1.5m, which is what makes men jitter
INTO each other per F04) reads as three different men digging, not one man cloned three times.
Conversely a `hooch_table` marker is exact-by-prop AND exclusive-by-deal — zero jitter there is
simply correct, not a coincidence of exclusivity.

## 3. Where the 1.8m station ring misplaces a man off his named prop

`mission_generator.gd:1200-1204`: the ring only fires when `post.men > 1`, which happens at
exactly two curated entries in `FSB_GARRISON_POSTS` (`site_planner.gd:1207-1224`):
`GUN_POINT_001` (`gun_crew`, men=2) and the three `FOOTPRINT_00{2,4,7}` (`off_duty`, men=2). Every
work-marker-rotation post (`cook_range`, `chow_server`, `dig`, …) is seeded `"men": 1`
(`site_planner.gd:1749`), so the briefing's literal "two servers on one `cook_range` marker" case
does not occur today — worth correcting in the record.

The real instance: `GUN_POINT_001` is a SINGLE-OPERATOR MG mount (`_place_firebase_mg`,
`mission_generator.gd:1272-1278`, one `MGEmplacement` at `post_pos`). The ring fans two men at
±1.8m around that one prop with `mi=0` at angle 0 and `mi=1` at `TAU/2 + jitter`
(`:1202-1204`) — a geometry that knows nothing about which side the trigger/spotter position is
on. One of the two `gun_crew` men (both `ARMED_POSTS`, both play `ARMED_WATCH_CLIPS` —
`civilian.gd:297,864-870`) can just as easily land facing away from the gun as beside it. The fix
belongs at the ring, not at `_bt_settle`'s jitter term: a 2-man post needs an authored
gunner/loader offset pair, not `TAU/men`. `FOOTPRINT_00{2,4,7}` off-duty pairs have the softer
version of the same problem — no `role` is set on a curated post (`FSB_GARRISON_POSTS` entries
carry no `role` key), so `off_duty_chain("", …)` correctly falls back to `OFF_DUTY_STANDING`
(`civilian.gd:137-143`) rather than mis-seating a man — visually survivable, but it means these
two men never read as "at" anything, only "near a footprint."

## Answers to the briefing's six questions

**Where does the proposed shape break something that currently works?** `sentry_night`'s
daytime `sit`/`talk` (§1 above) — currently wrong-but-harmless (walks home, at least looks
plausible), item 1's blanket garrison `sit/talk -> working_point_pos` makes it wrong-and-visible
(sits at his combat post off-duty). Caller: `_resolve_target` (`civilian.gd:1355`), reached every
tick once item 2 lands.

**Which occupations/marker roles would stand inside a prop or on a bad surface at an exact
station?** `gun_crew` at `GUN_POINT_001` (§3) — not "inside" the MG model, but on the wrong side
of it with 50% odds. Nothing else in `fsb_garrison_plan` currently multi-seats a single marker at
a prop scale small enough for zero jitter to matter; the AID STATION deliberately avoids seating
live men on baked-cast positions at all (`site_planner.gd:1656-1670`), which is the right
instinct applied one level up from this batch's scope.

**Re-pick-on-change at midnight / `SimClock.set_time` / `sleep_advance` / pause / 38x speed?**
Midnight wrap is safe — every schedule block is a plain `>=`/`<` float compare against
`sim_hour`, no delta math (`civilian_schedules.gd:32-287`), so a wrap to 0.0 resolves correctly
on the next read. A `set_time` jump or `sleep_advance` is *strictly better* under re-pick-on-change
than today's `int(hour) != int(last_hour)` gate (`civilian.gd:1223`) — it was already only
sampling at whole hours, so a jump was never guaranteed to land on a fresh value; re-pick fixes
that as a side effect. Under pause: no tick, no re-pick — correct, nothing should move. **The
double-entry risk is at 38x demo speed, and it compounds with F07, not just item 2:** `sim_hour`
can race past a 0.4h mess-sitting window before `CHOW_SIT_S` (a real-seconds Timer,
`civilian.gd:842-845`) fires. Landing item 2 (faster re-pick) WITHOUT item 4's `_anim_gen` guard
in the SAME change makes the existing overwrite bug more frequent, not less — the two items must
ship together, never item 2 alone. Also worth a hysteresis note: floating-point wobble at a
window boundary (`19.499999` vs `19.500001`) could flicker an action for one tick; a short poll
(as the Arbiter allows) is cheap insurance against this, a bare per-tick compare is not free of it.

**Is the animation key enough, or must `role`/`is_garrison`/`_chow_seated` be in it?** `role` must
be in it. Two men share `occupation == "off_duty"` with different `role` (`hooch_table` vs.
`smoke`) and therefore different chains from the SAME `want` (`civilian.gd:715,137-143`) — a
`want + scheduled_action` key alone cannot distinguish them if either man's `scheduled_action`
or `want` ever matches the other's. `_chow_seated` must gate the mess_hall table branch
specifically (already the mechanism F07 flags), not be part of a general cache key — it is a
latch, not a dimension of "what pose."

**What is sacrificed?** Village placement correctness is deferred wholesale (farmer/fisherman
`rest` still teleports home-and-back with no bridging transit — a real F02-shaped bug the batch
elects not to fix because the briefing scopes item 1 to "garrison + villager jitter only"). The
`sit/talk -> working_point_pos` blanket rule sacrifices per-occupation nuance that `rest` was
careful to keep (an occupation exception list) — that inconsistency is what produces the
`sentry_night` regression above. Zero jitter at multi-man curated posts sacrifices correct prop
alignment unless the ring geometry is fixed in the same change (§3) — cheap to defer, but it
should be named, not silently left for later. And the fractional-timing rewrite sacrifices two
pinned tests' stability for correctness (already flagged in the briefing) — real risk, not free.

**Single riskiest edit + cheapest probe:** The riskiest edit is the blanket
`sit/talk -> working_point_pos` for every garrison occupation (item 1) — it is a two-line change
with occupation-dependent correctness, it regresses `sentry_night` specifically, and it fails
QUIETLY: the broken window is 13:30-16:30 sim-hours, which is exactly the daytime stretch nobody
is watching (the demo opens at dusk, `game_flow.gd`/`demo_game.gd` per `CLAUDE.md`'s session
gate). The cheapest probe is NOT a new probe — it's widening `tools/probe_npc_census.gd`'s two
sample points (T+40s, one hour boundary, item 5) to include one tick inside 13:30-16:30 (or add a
third sample), and adding an occupation/action assertion alongside the existing distance check:
for `sentry`, `sentry_night`, `quartermaster`, `detail`, `mess_cook` specifically, flag
`sit`/`talk` resolving to the SAME position as `work` (post-place captured once at boot) as a
wrong-place case, exactly parallel to the ">2.0m from post" check already specified.
