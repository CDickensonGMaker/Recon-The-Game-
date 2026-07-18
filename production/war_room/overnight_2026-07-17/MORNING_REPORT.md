# MORNING REPORT — overnight 2026-07-17 → 07-18
North star executed: **you leave the camp and go find problems.**

## SHIPPED (4 wave commits, all local, NO push per stop-line)
- `0f3aa3fe` **W1+W2** — THE OPEN PATROL WORLD: your fsb_main.glb IS the firebase (placed by
  your markers; gate = SOCKET_A/B mid, out-dir via FACE_OUT). Bands from the GATE: first-sign
  150-300m, villages 280-450m, camps 400-540m, one location per quadrant. Wire gate at 120m
  points a sweep (living locations only); pointer = map grease circle + compass + point-man
  re-bark (tap M) + one toast. Floating objective markers DELETED. FieldHUD live (barks render
  at the base now). Death -> field AAR -> wake at the firebase. AAR at the wire banks
  score/XP/rank (patrol = the rank clock). Squad strings into staggered file, point man 12m up.
- `7b4f852a` **W3 THE BURIAL** — briefing/offers/select/TOC-gate/insertion/exfil chain + all
  objective sensors DELETED (fossil law). MissionDirector renamed **FieldDirector**. Save
  schema v2 + migration (old saves wake at the firebase, never dead-end). Intel now buys S2's
  read on WHAT the pointed location is (1/walk-out). Resurrection tag: `pre-burial-2026-07-18`.
- `5c4af59f` **W4+E+F** — dlox structural probe LANDS (one placement path, seeded rng - law in
  the suite now). Arena: hp x1.0, night from the shared preset. terrain_lab + lab organs
  deleted. 21 billboard PNGs, 7 WW2 vehicles, 6 orphan character models, WW2 strings: gone.
  Chicken.glb wired — the white sphere is dead.

## PROBE TABLE
| probe | result |
|---|---|
| test_patrol_world (bands/quadrants/determinism/fsb/squad-8) | PASS |
| test_patrol_aar (die -> AAR -> firebase wake, Pillar 5) | PASS |
| test_placement_paths (dlox: one path + seeded rng) | PASS (caught+fixed a live global-rng draw) |
| headless boot | CLEAN after every wave |
| fossil probe | 144 vs 143 baseline — 17 new = the OLD j3ke/xj9m debt; night STARTED at 18. Register only shrank. |
| survivors (site_stamp, village_props, seat 11-socket, hitzones, head_burst, model_scale, veg_cover, world_boot, crater, relief_bounds, huey_sim, cas_sim, squad, flat_damage...) | PASS |
| pre-existing reds (14x DummyMaterial-leak sniffer family etc.) | UNCHANGED — proven pre-existing by stash-run at 74a8daf1 |
| perf row (task 45) | NOT RECORDED — windowed forbidden by stop-line; no fake numbers. First row = your walk-out. |

## Q-DEFAULTS USED (all reversible)
Q1 rank=completed patrols (LOAD-BEARING in the AAR bank) · Q2 intel->location intel (LOAD-BEARING
in the wire gate) · Q3 TOC scenery (moot — fsb_main replaced the whole set) · Q5 labs kept as
instruments (terrain_lab killed) · NEW: squadmate distance markers KEPT (Pillar 4) · bands
measured from the GATE (your base is 369x344m — center bands would sit inside it) · fsb placed
unrotated v1 · nearest village garrison LIVE, rest wake on approach (perf).

## DA ITEMS HONORED
Populate->frame->bury order held · FieldDirector survives headless · toast blackout fixed ·
death soft-lock fixed · per-patrol resets + begin/commit bracket · LW spine: AAR reuses the
result pipeline; sensors deleted per your delete-default with the resurrection tag.

## BEADED, NOT GUESSED (skips)
qjf0 arena thin-wrapper (b6lr, the last parallel world) · us_grunt_v2 retirement + sprite stubs +
second-grass surgery + crate art (new E-remainder bead) · fb_pad_supply measured 0.0 = ambiguous.

## 5 FOR YOUR EYES (morning walk-out)
1. **Walk out your gate.** Does the toast + point-man bark + pencil circle on M read as an order?
2. **fsb_main seat**: gate walkable, colliders honest, skirt vs terrain at the edges.
3. **First five minutes on any heading**: craters, then a village by ~3 min — bored-test.
4. **The file**: squad strings out behind you on the move, point man ahead — patrol or conga?
5. **Die once on purpose**: AAR reads right, wake at base feels fail-forward — and eyeball FPS
   (F3 overlay) for the first honest patrol-world number.
