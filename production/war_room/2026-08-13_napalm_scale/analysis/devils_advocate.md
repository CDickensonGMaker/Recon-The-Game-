# DEVIL'S ADVOCATE — napalm scale pipeline (2026-08-13)

All code read directly this session; every claim carries a pointer. The briefing's pre-read was
verified, not trusted. Two of its claims cracked under verification (§1.3, §5).

---

## 1. THE SCALAR TRAP IN REVERSE — is a second wire still lying?

### 1.1 The metre-agreement claim SURVIVES verification — structurally, not just numerically
- Bench parents explosions to `self`, a plain Node3D at identity (`scripts/levels/vfx_range.gd:244`,
  `:279`); the 512 m ruler is unscaled BoxMeshes (`vfx_range.gd:73-91`).
- World parents to `tree.current_scene` (`scripts/vehicles/cas_airplane.gd:419`). In the demo,
  `current_scene` is the DemoGame root, which `extends Node` — NOT Node3D
  (`scripts/levels/demo_game.gd:12-13`). A Node3D child of a non-3D node is 3D-top-level: **no
  ancestor transform or scale can multiply the explosion root.** GameWorld's own transform is
  unreachable from the explosion's parent chain. No unit mismatch exists, confirmed.
- Player camera: no `far` override anywhere in `scenes/player/player.tscn` (only `fov = 75.0`,
  `:26`) → engine default 4000 m. Nothing clips a 513 m sprite at 210 m. FOV 75 vs bench FOV 70
  (`vfx_range.gd:127`) is a real but minor divergence.
- PSXLook is an autoload CanvasLayer acting on the viewport (`scripts/autoload/psx_look.gd:10,20-33`)
  — identical treatment on bench and world. Not a divergence.

### 1.2 BUT the ATMOSPHERE does not agree — the fogless bench is the third lie left standing
The council's plan fixes vantage and composition. The world diverges from the bench on two more
axes that no camera move fixes:

- **Fog is ALWAYS ON in the world.** `scripts/levels/game_world.gd:82-87`: `fog_enabled = true`,
  density 0.0065, `fog_aerial_perspective = 1.0`; `scripts/world/mission_weather.gd:13-17,58-60`
  re-applies 0.0065–0.035 per weather roll. No GunFX material sets `disable_fog`
  (none in `scripts/combat/gun_fx.gd`), so unshaded/additive sprites take full fog.
  At the demo's `NAPALM_RANGE_M = 210` (`demo_game.gd:234`): CLEAR transmittance
  exp(−0.0065×210) ≈ **25%** — three quarters of the fireball's contrast is fog wash. MONSOON
  (0.022) → ~1%: the strike all but vanishes. The bench Environment has **no fog at all**
  (`vfx_range.gd:110-121`); neither does the support bench (`scripts/levels/support_fire_range.gd:180-189`).
- **The convicting beats land at NIGHT.** The siege runs from ~24 min; NIGHT is sun energy 0.08,
  ambient 0.15 (`mission_weather.gd:24`). An UNSHADED emissive sprite does not dim with the sun —
  at night it is the only bright thing on screen and reads far larger against a black scene. His
  "nuclear bomb" conviction was formed at night in fog; the 8/12 map-width ladder was tuned on a
  fogless day bench.
- Corollary that proves the fixes are inseparable: world fog at the CURRENT bench's 949 m slant
  would be exp(−6.2) ≈ 0.2% — a god-cam bench with honest fog would show nothing. **Eye height
  AND world atmosphere, together, or the instrument still lies.** A bench "fixed" for vantage and
  composition but left in clean daylight air sends him into a THIRD tuning round-trip.

### 1.3 The briefing's "nothing else reads it" claim CRACKED — hut deaths ride the napalm kind
The dict `_KIND_SCALE` has no other reader (grep verified: only `gun_fx.gd`,
`tools/probe_fire_parity.gd:47-50`, comments). But the KIND STRING has a second consumer:

- `scripts/world/destructible.gd:42-44`: `BLAST_FOR = {"hut_thatch": "explosion_napalm",
  "hut_timber": "explosion_napalm", ...}` — played at `:177-178` with **no visual_mult argument,
  so the DEFAULT `ORDNANCE_VISUAL_MULT = 2.0` applies** (`gun_fx.gd:158-159`). Every village hut
  that dies renders the full napalm-class fireball — **~513 m today**. (The same function knows
  better one call later: `:200-201` passes `1.0` for the collapse dust, with a comment saying the
  spectacle mult stays off.)
- This is LIVE IN THE DEMO: `plan_demo_world` stamps one village ~165 m from the firebase
  (`scripts/missions/mission_generator.gd:741-748`), and `site_planner.gd:1771-1773` adopts its
  `nha_*` huts as `hut_thatch`/`hut_timber` Destructibles. Siege air beats land 165–260 m out on
  siege-sector bearings (`demo_game.gd:258-266`); huts die to any explosive ≥120 dmg
  (`destructible.gd:73-74,130-135`). A drop or shell that kills a hut stacks a second 513 m dome
  on the first. **His nuke night plausibly included hut-death fireballs nobody has named.**
- Consequence both ways: retune `explosion_napalm` and hut deaths shrink in lockstep (to ~55 m —
  still ~10× a hut; possibly fine, but nobody ruled it). Park the scalar and 513 m hut-death
  fireballs stay in the shipping demo. **Either way the decree must name this coupling**, and the
  clean fix is probably its own decision: hut deaths on `visual_mult 1.0` like `:201`, or an own
  kind. Silence here is exactly the "some other disconnected wire" the morning report warns about.

### 1.4 One scalar drives WIDTH and CLIMB — the council's number targets only width
`_burst` sets `local_coords = true` (`gun_fx.gd:279`), so node scale multiplies velocities AND the
fireball's +1.2 up-gravity (`gun_fx.gd:352-355`). At the proposed ~55 m width (root scale ~24):
initial rise 14–38 m/s accelerating at ~29 m/s² over a ~1.8–3.2 s life → the plume still climbs
**~150–200 m — 11–15× the tallest tree in the game** (measured max `top_m` = 13.378 m,
`data/veg_break_bands.json`; most canopy is 5–11 m). That may be exactly his 8/4 "chain that goes
above the treelines" — or still half a nuke. Point: a ruling made on the frozen first second
under-specifies. The fixed bench must show the full lifetime, and the council must know the two
reads move on one knob.

### 1.5 Comment fossil check on the "AmbientWar" claim — NOT a fossil, and untouched by any retune
`gun_fx.gd:303-304` says AmbientWar passes big scale; verified live: `scripts/ai/ambient_war.gd:193`
calls `_spawn_explosion_visual(self, pos, 12.0, 2.5)` DIRECTLY, bypassing the kind ladder. Retuning
napalm does not move horizon events. Adjacent hazard, pre-existing: `MAX_EXPLOSIONS = 9` exactly
equals `NAPALM_DROPS` (`gun_fx.gd:71`, comment at `:68-70`), and AmbientWar shares the budget
(`ambient_war.gd:188`) — any concurrent explosion during the 9-drop run FIFO-recycles drop #1's
root mid-burn (`gun_fx.gd:313-317`). One line in the decree, not this council's fight.

---

## 2. THE TASTE RISK — the "he liked it three times" narrative is FALSE

Every "very very very large" ruling was made through a lying instrument: before 2026-08-12 the
scale lever was DISCONNECTED (`billboard_keep_scale` — the fix and its confession at
`gun_fx.gd:186-191`), and the 8/12 map-width session was tuned on the god-cam at ~949 m with one
drop, no fog, no night (`vfx_range.gd:32-33,241-244`). **The one honest look he has ever had —
ground level, at night, nine drops — he convicted as a nuclear bomb.** There is no verified
"liked it" to gut. The real taste risk runs the other way: shipping ANOTHER guessed number and
spending a second playtest night discovering it. The 50–60 m proposal is 4–6× the tallest measured
tree — defensible against his own 8/4 treeline anchor — but it is still a guess on the same axis
that produced 513. Protection against the round-trip is not a better guess; it is a knob under his
hand on an honest bench (§4), and the run-vs-drop question put to him in words (§3).

What is protected no matter what: the part he DID like in world — the ~236 m burning lane —
is damage-side (`FirePlan.NAPALM_BLAST_M = 30`, `NAPALM_BURN_S = 25`,
`scripts/gameplay/fire_plan.gd:31-34`; FireHazard visuals size from the damage radius,
`cas_airplane.gd:418`, `scripts/vehicles/fire_hazard.gd:59-129`). No visual retune touches it.
Say this out loud in the decree; it is the difference between "shrinking his spectacle" and
"shrinking one sprite".

---

## 3. LADDER INVERSION — real, visible inside the demo's own siege, and the escape hatch

At ~55 m/drop, napalm's kind scale ≈ 55 / (2.2 × 1.05 × 2.0) ≈ **12**, under `explosion_heavy`'s
24 (~111 m) (`gun_fx.gd:120-133`). `explosion_heavy` is fired by the CAS bomb
(`cas_airplane.gd:396`), the plane crash (`:249`), the arty barrage (`field_director.gd:881`), and
the sapper satchel (`scripts/enemies/placed_satchel.gd:71`). In the demo's own beat table the BOMB
lands at siege+25 s and NAPALM at +150 s (`demo_game.gd:258-266`): the audience sees a 111 m bomb,
then 55 m napalm drops, two minutes apart — per-fireball inversion of his explicit "napalm is the
biggest thing", on screen, in the shipping demo. A satchel on the wire out-rendering a napalm can
is the same violation at ten metres.

The tension, honestly named:
- **Napalm-only retune** → inversion above, UNLESS the council adopts the reading his own 8/5
  ruling supports: a napalm RUN is a rolling WALL (`fire_plan.gd:26-34`) — the composite ~236 m,
  nine-fireball lane out-scales any single 111 m burst, so "biggest thing in the game" is satisfied
  at the RUN level with per-drop ≤ heavy. That reading is an INTERPRETATION of his words. Put it to
  him as a plain question ("is napalm's bigness the wall, or must each fireball beat artillery?").
  Smuggling it in as an assumption is how the next conviction gets written.
- **Whole-ladder retune** → coherent geometry, but multiplies the taste surface ~6× for a
  complaint he made about ONE kind. His 8/12 night playtest showed him grenades, mortars, satchels
  and the heavy bomb in the world and he convicted only napalm — weak but real evidence the rest of
  the ladder survives ground level. Re-opening unappealed verdicts is a gift to entropy the week of
  ship.
No free lunch: pick napalm-only + the explicit question, and accept that if he answers "each
fireball must be biggest," heavy (and its four firers) re-enters scope next session.

---

## 4. WHO MOVES THE SCALAR — fix the instrument, ship a KNOB, park the decree number as a labelled placeholder

What he actually asked for (`production/MORNING_REPORT_2026-08-13.md`, "The job he asked for"):
the SCALE PIPELINE between his testing scenes and the game world — with a standing warning that
nudging the napalm scalar papers over the pipeline defect. He did not ask for a new number. Size
rulings on the fire pack are his (ADR-015 feel-discharge; the 8/12 ladder was stated in his words).

- **Case for the council shipping a number:** 513 m is a convicted defect in the shipping demo
  (his words), a preview contradiction (§7), and a fill-rate mine at the climax (§6). Demo ships
  2026-09-06; leaving it parked bets his bench session happens in time.
- **Case against:** any council number repeats the original sin — a size chosen by someone who is
  not him, on an instrument he has not blessed.

**Position: both, precisely divided.** Fix the instrument (eye-height vantage, 9-drop composition,
world fog + night — §1.2), and give the bench a live size knob that rides the SAME code path the
game uses: `play_explosion_3d` already takes `visual_mult` (`gun_fx.gd:158-159`); the bench passes
`ORDNANCE_VISUAL_MULT × knob` and prints the computed metres on its label. No second pipeline, no
bench-only scaling lie. Set the code default to the treeline-multiple (~12 kind ≈ 55 m) as a
LABELLED PLACEHOLDER — safe-not-final, awaiting his eye — because between now and his session the
demo must not carry 513. What this sacrifices: the pure "instrument-only" position (a guessed
number does enter the tree, mitigated by being bounded by his own treeline anchor and by the knob
making the correction a one-sitting job); and ~20 lines of bench-only code in ship week. Without
the knob, every taste iteration is a code-edit round-trip — the exact cost that produced tuning
through a god-cam in the first place.

---

## 5. THE SECOND BENCH — the map_size divergence is a NON-ISSUE; the real question is WHICH bench is the instrument

Verified: `FieldDirector` reads `world.map_size` only to clamp HUNTER spawn points
(`field_director.gd:179-180`) and decoy bounds (`:1355-1358`) — neither runs on a bench. CAS
ingress is hardcoded 900 m (`cas_airplane.gd:130`) and the F4 flyby spawns 200 m out (`:35,149`)
regardless of map_size. `FIELD = 200` (`support_fire_range.gd:17,133`) distorts no strike
geometry. Not a landmine for this decree; correct the briefing's suspicion in the record.

The finding the council should not walk past: **support_fire_range already IS most of the bench
the council wants to build** — player at eye height behind sandbags, the REAL 9-drop run through
`request_fire_support` (`support_fire_range.gd:561-588`), real segmented trees, a night toggle
matched to world values (`:196-217`). What it lacks: fog (`:180-189`), field size (a 236 m strip
overhangs the 200 m field; veg fades at 70 m, `:440,499`), and range (its direct keys fire at
60 m vs the demo's 210 m). Meanwhile vfx_range carries two stacked generations of stale size
comments in its own header ("~90 m wide" AND "sized to cover the 512 m square",
`vfx_range.gd:29-31`) — drift inside the instrument itself. **Decree must name ONE scene as the
scale instrument and give that one the world's atmosphere.** Two half-honest benches is the
mechanism that produced this defect; fixing both halfway reproduces it.

---

## 6. PERF — the current 513 m version is a hidden fill-rate mine; the retune is a silent dividend, not a cost

Arithmetic, not measurement (the perf probe only just learned to measure GPU ms — morning report
§2): at 210 m with FOV 75 the frame spans ~322 m. One drop at root scale 222 emits 6 fire sprites
at ~390–635 m each (`gun_fx.gd:350-372`: 2.2 m quad × 0.8–1.3 × 222), 3 core sprites ~200–300 m
(`:377-390`), a flash quad to ~800 m (`:326-342,494`), a ring tweened to ~1000 m (`:409-425,496`),
and up to 8 linger-smoke sprites at 577–1039 m alive ~11.3 s (`:468-487`). Nine drops inside 0.9 s
(`cas_airplane.gd:405-422`) ≈ on the order of **150+ screen-filling alpha/additive layers**
stacked over the 45-man night siege (`demo_game.gd:87`) on the Intel UHD floor — the named
smoke-overdraw risk class, detonating at the exact climax. At ~55 m/drop each sprite covers ~3% of
the frame at that range: roughly a hundredfold fill cut. The smaller version ADDS cost nowhere —
same node and particle counts; FireHazard visuals size from the damage radius (untouched,
`fire_hazard.gd:59-129`); the scorch decal is already clamped (`SCORCH_MAX_M = 44`,
`gun_fx.gd:507-511`). Two honest edges: claim this as a look fix with a perf dividend, never as
perf work (content-first law); and if the council parks the scalar at 513 awaiting his hand, it
knowingly parks this hazard in the shipping demo — say so in the decree.

---

## 7. TEST/PROBE/HUD EXPOSURE — nothing reds; the HUD actually argues FOR the retune

- `tools/probe_fire_parity.gd` PRINTS the ladder (`:46-50`) and gates only canisters/fires/felled
  (`:112-115`). No red on any scalar move. `tests/test_fake_lights.gd:77` fires a default grenade —
  unaffected. Grep confirms no other `_KIND_SCALE` reader.
- `scripts/ui/mission_hud.gd:138` and `scripts/gameplay/fire_preview.gd:86` draw the napalm
  placement promise from `FirePlan.footprint`: a **236 × 60 m rect** (`fire_plan.gd:83-90`). Today
  the rendered drop (513 m) is ~8.5× wider than the 60 m lane the player was shown — the preview
  lies. At ~55 m/drop the fireball width ≈ the promised lane. **The treeline-multiple number
  re-couples promise to visual**; nobody in the briefing named this, and it is the strongest
  code-side argument the ~55 m anchor has.
- FOSSIL LAW tickets that MUST ride the same change (touched files): `gun_fx.gd:114-119` header
  says "mortar ~37m", computed 10 × 2.2 × 1.05 × 2.0 ≈ 46 m; `gun_fx.gd:126-131` napalm comment
  ("one drop covers the whole 512m demo square") rewrites with the new anchor; `vfx_range.gd:29-31`
  double-generation header; `vfx_range.gd:37-42` `ROW_SPACING = 620` / `CAM_ROW` are laid out for
  the 513 read and must shrink with it or the side-by-side bench mis-frames; `_AUDIO_KIND` borrow
  (`gun_fx.gd:149`) — napalm still SOUNDS like artillery; fine, but note it so the ears ladder is
  a known open item, not drift.

---

## VERDICT SUMMARY (for the weave)

1. Metre agreement verified true; vantage/composition fixes necessary but INSUFFICIENT — the
   world's always-on fog and the night light are two more instrument lies, and a fogless daylight
   bench guarantees a third round-trip of his time.
2. Landmine: hut deaths fire "explosion_napalm" at full ordnance mult (`destructible.gd:42-44,
   177-178`), live in the demo's village 165 m out — the scalar has a second consumer nobody named,
   and it moves (or stays 513) with whatever the council does.
3. One scalar sets width AND a climb that stays 150–200 m even at the proposed 55 m — rule on the
   full lifetime, not the first frame.
4. Napalm-only retune inverts per-fireball vs heavy inside the demo's own beat table; the wall-
   reading of his 8/5 ruling is the escape hatch but needs HIS yes. Whole-ladder retune re-opens
   verdicts he never appealed.
5. Ship the fixed instrument + a `visual_mult` knob on the game's own code path; the ~12 kind
   default enters as a labelled placeholder, his to overwrite in one sitting. Park nothing at 513:
   it is a convicted look defect, a preview contradiction, and a fill-rate mine at the climax.
6. support_fire_range map_size fear is refuted; the real second-bench question is that it already
   half-is the honest instrument — name ONE bench as the scale truth and give it the atmosphere.
