# IMPLEMENTATION PLAN — The Sheet, The Route, The Hunters

**Date:** 2026-07-28 · **Status:** DRAFT — awaiting Summoner's tuning notes
**Source decrees:** `synthesis.md` (the sheet) · `patrol_route_and_hunters.md` (route + hunters)

**How to use this file:** every stage has a `TUNE:` line left blank on purpose. Write what you want
changed, cut, or numbered differently, and hand it back. Stages marked **[RULING]** cannot start until
you answer the question in them.

**Sequencing law:** Phase A before Phase B. You cannot sequence circles on paper you cannot read, and
"take the valley instead of the ridge" is not a decision if the valley is a smear.

---

# STATUS as of 2026-07-28 — ALL 20 STAGES CLOSED

Every stage is implemented and compile-verified. **Nothing here has been playtested**; a headless probe
is not a playtest, and PLAYTEST R4 remains the Summoner's standing gate.

| Phase | Stages | State |
|---|---|---|
| A — the sheet | 1,2,2a,3,4,5,6,7,8,9 | done; 1–4,7 verified by rendered images, 5/6/8/9 code-verified only |
| B — map input | 10–15 | done, compile-verified only |
| C — the hunters | 16–19 | done; `tests/test_evidence_ledger.tscn` PASSES 6/6 |
| D — canon | 20 | ADR-035 written; freehand route buried; two probes added |
| terrain (unplanned) | — | 5 presets pass 4 budgets across 25 seeds, metrics now able to fail |

**The two biggest findings of the session were both dead guards, not missing features:**
`test_terrain_relief_bounds.gd` measured a different terrain than the one that ships (wrong cell count,
wrong height basis) and its slope metric was understated 175x — three of its four assertions were
mathematically incapable of failing. A 2.7x relief overshoot lived under a green suite because of it.

**And one near-miss worth remembering:** a `HunterDirector` was written, then DELETED unbuilt on
discovering `FieldDirector._process_escalation` already was one. It would have been parallel world-build
system #15. The existing one was improved instead — which is where the telepathy bug surfaced.

---

# STATUS as of 2026-07-28, end of terrain pass

**DONE and verified by measurement + eyes:**
- Stage 1 — probe instrument (`tests/probe_topo_sheet.gd`), with its own shear bug found and fixed
- Stage 2 — `floori` band index (defensive; was never the visible defect)
- **Stage 2a — adaptive contour interval** (NEW, replaced the old Stage 2 diagnosis)
- Stage 3 — paper tone ramps over the 5–95% percentile band
- Stage 4 — sheet displays 1:1 with `TopoSheet.MAP_PIXELS`, nearest filter; the 1.09x resample is gone
- **Stage 7 — woodland green + paddy overprint.** Routed through `TerrainZoning.classify()`, which is
  THE one classifier the AI sight grid and the visible jungle already use — so the sheet cannot
  disagree with the cover the player walks into. Green screens UNDER the linework; contours stay the
  readable layer. Paddy carries a hatch. Verified on all five presets.
- **TERRAIN TRACK (unplanned, ruled in by the Summoner mid-session):** relief scaler overshoot,
  [0,1] clipping, relief-probe unit bug, slope-metric 175x bug, STEEP_MOUNTAINS walkability retune.
  All five presets now pass all four budgets across 25 seeds with metrics that can actually fail.
  See `FINDINGS_the_look.md` F1/F4/F5/F6/F7.

**DONE but UNVERIFIED IN GAME (code only):**
- Stage 5 — firebase + surveyed villages printed on the sheet

**STILL OPEN:** Stage 4 (resample), Stages 6–9 (fidelity), 10–15 (map input / route / pencil),
16–19 (hunters), 20 (canon + probes).

**ADDED THIS SESSION — now BUILT (compile-verified, unplayed):**
- **World-sim group sizes.** Hueys `[6,9]` and `FORMATION_CHANCE` 0.35→0.85 (size alone would have left
  two thirds of flights solo); `f4`/`skyhawk` added at `[3,5]` — they had never flown in a group at all;
  skyraider stays `[2,2]`, it is a prop not a jet. Convoys 3–6 with a real composition
  (`_convoy_composition`), verified by `tests/test_roads.tscn` which asserts every basename resolves on
  disk. Villager parties 3–6 — the loop guard AND the remainder rule both had 2 baked in, so changing
  the range alone would have kept producing pairs under a constant that claimed otherwise.
- **Intel stashes / REPORTED third ink.** `CampaignState.add_intel()` is now the ONE earn path, feeding
  a silent `lifetime_intel` that only counts up, with a per-campaign 20–30 threshold. Every "+1 INTEL"
  toast is gone — intel accrues silently or patrolling becomes farming. `FieldDirector.try_intel_stash()`
  fires from the tunnel cache (the dungeon) and marks undiscovered camps in dashed, DATED third ink that
  the game never reconciles.
- **Ear necklace — DATA ONLY.** `CampaignState.ears_taken`, growth buckets, and the witness hook
  (`on_atrocity_witnessed`, villagers within 45 m). **The mesh does not exist** — a necklace that grows
  with the count is Blender work on the FP-arms pipeline and is NOT done. The count is also inert until
  `Civilian.on_atrocity_witnessed` is implemented; the call is guarded by `has_method`, so it is a
  no-op today rather than a crash.

---

# PHASE A — THE SHEET (legibility, then fidelity)

### Stage 1 · The instrument: render the sheet outside a live session
Build a headless probe that dumps the base sheet to PNG for each terrain preset and a fixed seed set, so
every later change is judged by EYES against a before/after pair, not by reasoning.

- **Pointers:** `scripts/ui/topo_sheet.gd` (renderer, extracted 2026-07-28) · presets in
  `tests/test_terrain_relief_bounds.gd:17-29` · run with `Downloads\Godot_v4.7-stable_win64.exe`
- **Done when:** PNGs exist for delta / lowland / hill / mountain presets, ≥2 seeds each.
- **Note:** the probe passes no water predicate, so water is absent in probe output. Water is judged
  in-game only. Do not "fix" water off a probe image.
- **TUNE:**

### Stage 2 · Contour band truncation — the double-width band at sea level
`int(h / interval)` truncates toward zero, so band 0 spans −12 m…+12 m — twice every other band. Any
ground near sea level gets one wide featureless zone with no contour through it.

- **Pointers:** `scripts/ui/topo_sheet.gd` — band computation and both neighbour comparisons
- **Fix:** `floori()`. Three call sites, must change together.
- **Done when:** the delta preset shows evenly spaced contours through its lowest ground.
- **TUNE:**

### Stage 3 · Tonal ramp — one peak flattens the whole map
Paper shade is `(h − h_min) / (h_max − h_min)` across the entire AO. On the 350 m mountain preset one
peak sets `h_max` and compresses all the walkable ground into a narrow tonal sliver.

- **Fix:** ramp against a percentile band (e.g. 5th–95th) rather than absolute min/max, so outliers stop
  eating the range.
- **Done when:** mountain-preset valleys show tonal separation instead of uniform mush.
- **TUNE:** percentile window —

### Stage 4 · Resample — 512² stretched into 560 px
1.09375× scaling lands 1-pixel contour lines unevenly; some double, some filter away.

- **Pointers:** `topo_map.gd` `_build_ui()` — `custom_minimum_size` 560, `EXPAND_IGNORE_SIZE`
- **Fix:** render at display resolution, or display at 512, or nearest-neighbour. Pick one; do not stack.
- **TUNE:** target sheet size on screen —

### Stage 5 · Print the firebase and the major villages **[the original ask]**
Base-sheet layer, drawn in contour ink at contour weight — furniture, never a destination. Saturated
colour stays reserved for the grease pencil.

- **Prints:** `firebase_main`, `village` (major only) · **Stays off:** `vc_camp`, `lz`, deep-bush
  `temple`, small hamlets
- **Pointers:** site dicts from `scripts/world/site_planner.gd:306,925,961,1054,1062` · reachable as
  `patrol_plan.sites` (`scripts/main/game_flow.gd:304`) and `built.sites`
  (`scripts/missions/field_director.gd:954`) · road precedent `topo_map.gd:16-24`
- **Ruled 2026-07-28:** the sheet is an ACCURATE survey of the world built. No seeded ghosts, no
  omissions. Generated once at world-build, static thereafter (Arma model).
- **TUNE:** what counts as "major" —

### Stage 6 · Vietnamese hamlet names
Period sheets label hamlets `ẤP <NAME>` in small caps. Names generated deterministically from the
mission seed so a province is the same province every session.

- **Risk named:** a generator produces nonsense to a native speaker. Prefer a small hand-checked name
  table over procedural syllables. Font must carry Vietnamese diacritics.
- **TUNE:** name table source, or approve procedural —

### Stage 7 · Green canopy and paddy overprint — **biggest single fidelity win**
Real sheets screen woodland green over buff paper; cleared ground and paddy stay white/buff, worked
ground gets a distinct stipple. Ours is brown everywhere.

- **Why it is not merely chrome:** it is what makes a sheet readable at a glance, which is the
  precondition for route-order decisions in Phase B.
- **Pointers:** `terrain/systems/clearing_system.gd` · `gameplay_grid` · paddy sites from `site_planner`
- **Cost:** roughly doubles the one-time 512² sample loop at world-build. Load cost, not frame cost.
- **TUNE:** green saturation, paddy fill style —

### Stage 8 · Road hierarchy
A real sheet distinguishes improved road (double line) from cart track from trail (dashed). Ours draws
every segment identically at 1.6 px.

- **Pointers:** `topo_map.gd` `_draw_roads()` · `scripts/world/road_network.gd`
- **TUNE:** how many tiers, and which existing road data maps to them —

### Stage 9 · Honest marginalia
The header claims `1:25,000` on a 1,280 m AO, and real 1:25,000 sheets print a 1,000 m grid while ours
prints 100 m. The 100 m grid is correct — six-digit-grid-ref precision — the ratio is fiction.

- **Fix:** drawn scale bar in metres (self-consistent at any window size), declination diagram, grid
  reference box. Retire the false ratio.
- **Note:** this is the stage that leans hardest into ADR-030 chrome territory. Cut it if you read it
  that way.
- **TUNE:**

---

# PHASE B — THE MAP ACCEPTS A CURSOR

Today `topo_map.gd` `_unhandled_input` does exactly one thing: toggle visibility. There is no click
handling at all. Grease-pencil marks, suspected locations, and the route planner are three features of
this one missing system.

### Stage 10 · Map input foundation
Cursor on the sheet, map↔world coordinate hit-testing, hover feedback, and a mode concept so later
tools (order, pencil) are skins rather than parallel systems.

- **Pointers:** `topo_map.gd` `_world_to_map()` exists; the inverse does not.
- **Watch:** the map is a `Control` over a captured-mouse FPS. Mouse mode must be released on open and
  restored on close, and must survive the player being shot at while the map is up.
- **RULED 2026-07-28 (Summoner):** *"the world doesnt pause when you open the map"* — reading the sheet
  is a real-time vulnerability. You are standing still, the squad keeps moving, hunters keep hunting.
- **Consequence found, needs a fix in this stage:** `topo_map.gd` `_build_ui()` lays a full-screen
  `ColorRect` at alpha 0.85 over the world. That was survivable when nothing was at stake; against a
  LIVE world it blinds the player for as long as the map is up. A man reading a map still sees the
  treeline over the top of it. Options: drop the dim, shrink it to the sheet's own footprint, or make
  the sheet a held object occupying part of the screen with the world visible around it.
- **RULED 2026-07-28 (Summoner):** *"i like it being a held object"* — the sheet is a thing in the
  player's hands, occupying part of the screen, world visible and live around it. The full-screen dim
  is DELETED, not shrunk. Note this is the ADR-030 chrome path and the most work of the three; it is
  ruled in deliberately.
- **TUNE:** which corner/side it occupies, and whether raising it slows the player —

### Stage 11 · Patrol objective circles
The world tags N locations per patrol, drawn as grease-pencil circles on the sheet.

- **Ruled:** circles are OFFERED, never REQUIRED. Skipping is legal, no fail-state.
- **Pointers:** existing single-circle precedent `topo_map.gd` `_draw_overlay()` CO's sweep circle ·
  `FieldDirector.patrol_location`
- **TUNE:** N = ? · how are the N chosen (distance band from firebase? site kind? mix?) —

### Stage 12 · Route ordering **[RULING]**
Click circles to assign visit order; reorder; clear. Route closes at the firebase. Drawn as pencil
linework connecting the numbered circles.

- **[RULING] required before build:** ADR-029 deliberately killed the briefing UI and objective counter.
  N game-chosen sites the player sequences **is a briefing** — diegetic and on paper, but a briefing.
  Confirm you want this, or confirm the offered-not-required mitigation is sufficient.
- **TUNE:** can order be changed mid-patrol, or is it locked at the wire? —

### Stage 13 · Route persistence and the AAR
Planned route banks with the patrol; the debrief reports what was actually walked against what was
planned. ADR-006 pays for what you learned, not what you ticked.

- **Pointers:** `field_director.gd:1066` `_bank_patrol` · `CampaignState` · `mission_state.gd:56`
- **TUNE:** does deviating from plan cost anything? (recommend: no) —

### Stage 14 · The grease pencil — ADR-022's ANNOTATED layer, still unbuilt
ADR-022 promised player-placed marks and free text: AMBUSH, danger, rally, cache, avoid. What shipped is
Amendment A's report verb (`field_mark_verb.gd`), which requires you to be LOOKING at a real thing —
that is an OBSERVED-layer tool wearing the pencil's name. **Suspected locations are impossible today.**

- **Build:** place a mark anywhere on the sheet, from the sheet, with no line of sight required.
- **Binding:** the grease-pencil law — the game NEVER validates, corrects, or auto-erases a player mark.
- **TUNE:** marker vocabulary — ADR-022 warns it must stay small; 30 icon types is a spreadsheet —

### Stage 15 · Free text on marks
Typed notes on a mark, persisted in the province ledger forever.

- **Noted in ADR-022:** free text is a moderation/localisation surface if sharing ever exists. It won't
  at launch.
- **TUNE:** character limit, and does text render on the sheet or only on hover? —

---

# PHASE C — THE ENEMY HUNTS BACK

### Stage 16 · The evidence ledger
Hunters must never read the player's chosen order — that is telepathy and reads as the game cheating.
They converge on evidence the player actually left.

| Evidence | Yields |
|---|---|
| gunfire | bearing + timestamp, decaying to a stale fix |
| bodies left behind | ADR-022 already calls a body a liability; witness rule is written |
| villages that saw you | ADR-019 sentiment, already modelled |
| burned/damaged structures | location + grudge |
| tracks through worked ground | direction of travel |

- **Build:** one ledger of timestamped, position-bearing, DECAYING fixes. Fixes may be wrong and stale.
- **TUNE:** decay rate per evidence type · how wrong a stale fix is allowed to be —

### Stage 17 · Hunter teams — the cap is the design
Small dedicated VC teams whose goal is the player, not a post. **Hard cap per patrol, no respawn when
destroyed**, so killing one is a permanent win for that patrol.

- **Pointers:** must draw from the FROZEN finite-VC-pool work when it thaws — not a new spawner, or we
  grow parallel world-build system #15. See Claude memory *RECON VC manpower research*.
- **TUNE:** cap = 2? · team size? · do they exist from patrol start or spawn on first evidence? —

### Stage 18 · Converge-on-evidence AI
New behaviour, not a reskin. Standing patrols walk fixed routes; hunters pursue stale, wrong-able fixes,
lose the trail, cast about, and give up.

- **Do NOT** build this by widening `patrol_generator` until it does both — that is exactly the
  divergent-systems failure this project already has.
- **Pointers:** `scripts/enemies/patrol_generator.gd` · `camp_director.gd` · think/execute split per
  CLAUDE.md AI patterns
- **TUNE:** give-up time · how close a hunter gets before it becomes a fair contact —

### Stage 19 · Close the stealth loop
ADR-006 pays +25 for a contact avoided, and today that is a number in a debrief. With hunters, avoiding
contact is what keeps two dedicated teams off your back — stealth becomes mechanically load-bearing.
Tune until "hit the noisy site last" is a decision a player actually makes.

- **Sacrifice named:** difficulty variance rises sharply. A quiet player may never meet a hunter; a loud
  one meets both, far from the wire. That is the design working, and it will read as unfair to someone.
- **TUNE:**

---

# PHASE D — DON'T LEAVE FOSSILS

### Stage 20 · Canon, probes, and the gate
- **ADR amendments:** ADR-022 (the base-sheet third layer; the ANNOTATED layer finally built) ·
  ADR-029 (route ordering vs the killed briefing) · new ADR for hunter teams
- **FOSSIL LAW:** when the route planner ships, the freehand-pencil concept from the 2026-07-24 decree
  is DEAD — delete it from the docs in the same change, do not leave it readable as live.
- **POINTER LAW:** every claim in these war-room docs gets a `file:line` or a date banner.
- **Probes:** sheet-render probe (Stage 1) stays in the suite · evidence-ledger probe · hunter-cap probe
  that fails if more than the cap can exist
- **SESSION ENTRY GATE:** PLAYTEST R4 is still standing and is discharged only by your verified
  playtest — never by a probe, never by my reading.
- **TUNE:**

---

## Dependency summary

```
A1 look
 └─ A2,A3,A4 render fixes ──┐
 A5 print sites ────────────┼─ B10 input foundation ─ B11 circles ─ B12 order [RULING] ─ B13 AAR
 A6..A9 fidelity (optional) ┘                       └─ B14 pencil ─ B15 free text

C16 evidence ledger ─ C17 hunter teams ─ C18 converge AI ─ C19 stealth loop
     (C runs independent of A/B; C17 gated on finite-VC-pool thaw)

D20 closes everything
```

**Open rulings blocking work:** Stage 12 (briefing tension). Everything else can proceed on the tuning
notes you write into this file.
