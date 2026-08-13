# SYNTHESIS — the bench-vs-world scale pipeline (napalm)

**Arbiter, 2026-08-13.** Four analyses in `analysis/` (godot_specialist, game_designer,
ux_designer, devils_advocate). Each read the code independently, no cross-talk.

## Where the council CONVERGED (four doors, one answer)

1. **The metre agrees; the instrument lies.** No unit mismatch exists anywhere in the
   pipeline (verified three ways, incl. DA's ancestor-scale check: the demo's
   `current_scene` extends Node — no transform possible). The 8/12 ruling was made through
   a god camera ~950 m out, on ONE drop, with no treeline in frame — vantage, composition
   and context lied; the numbers were faithfully implemented and honestly wrong.
2. **The size band: `_KIND_SCALE` 11–15 (≈50–70 m per drop).** Specialist K≈13 (60 m = the
   authored fire lane width), designer K=14 (65 m ≈ 5× the tallest measured tree, 13.378 m,
   `data/veg_break_bands.json`), UX 11–15 (chain ≈40% of screen at the 210 m ruling
   vantage; 513 m is 90% width / 159% height — "whiteout is arithmetic, not taste"),
   DA ~12 as labelled placeholder. **Decreed: 13.0 (~60 m).**
3. **The run is the bigness.** 9 drops on 22 m spacing ≈ a 240 m rolling chain — matching
   the authored 236×60 m damage/burn lane (`fire_plan.gd:83-90`), the HUD footprint
   promise, and his 8/5 "rolling wall" ruling. At 513 m/drop adjacent fireballs overlap
   96% and geometrically erase the chain into one dome; at 60 m the nine pulses read.
4. **The scalar alone cannot fix it — napalm needs its own composition.** It currently
   shares a grenade's procs and sheet ×111 (`gun_fx.gd:370-371`): a ground shock ring
   expanding to ~999 m (real napalm has no ring), a flash pop ~800 m at 133 m altitude, a
   burst emitted 155 m airborne, velocities scaled by root scale so the plume climbs at
   130–355 m/s and the linger tops ~11 km. Ring + pop + column IS the nuclear schema.
   Bound: event top ≤ ~2× width (designer), burst seated at canopy not altitude.

## Where the council SPLIT, and the weave

- **Which bench rules.** UX: upgrade `vfx_range` (vantage cycle, real-run key, treeline).
  DA: `support_fire_range` is already half-honest (real dispatch, eye height, night
  toggle) and the world's always-on fog + night are absent from ANY bench — an eye-height
  clean-air bench is a **third lying instrument**. **Weave: both, with named roles.**
  `vfx_range` = geometry/composition lab (gets vantages, real-run key, treeline band, man
  reference, honest signage — and its signage SAYS it is clean-air). `support_fire_range`
  = the RULING bench (gets world-matched fog, a live size knob, and a demo-range strike
  modifier; it already has night and the real 9-drop dispatch). **The world stays the
  final bench (ADR-015) — nothing here discharges his eye.**
- **How much ladder moves.** Designer: top three together, else the order inverts (heavy
  111 m > napalm 60 m — a satchel outblooming a napalm run). DA: whole-ladder re-opens
  five unappealed verdicts. **Weave: exactly the top three** — heavy and mortar were tuned
  in the same blind 8/12 session and carry the same taint; the small kinds (rocket,
  grenade, 40mm) predate it, were never map-anchored, never convicted — they stand.
  napalm 111→13 (~60 m) · heavy 24→10 (~46 m) · mortar 10→6 (~28 m). Order preserved:
  13 > 10 > 6 > 4 > 1 > 0.7.
- **Ship a number or park it.** DA named the cost of parking: a convicted defect ships,
  plus a fill-rate mine (~150 screen-filling alpha layers at the climax on the Intel UHD
  floor). **Weave: ship 13.0 as a LABELLED starting value awaiting his eye**, with the
  bench knob so his taste pass needs zero code edits.

## REFUTED during council (recorded so nobody re-learns them)

- Specialist's "GodotPrompter clone missing on disk" — **false**, Arbiter verified
  `~/.claude/architect_knowledge/GodotPrompter/skills/particles-vfx/` exists; the agent
  mangled its path check.
- Briefing's `visibility_aabb` culling worry — the box is local and scales with the root.
- DA's own map_size fear for the second bench — `map_size` only clamps hunter LZs/decoys
  (`field_director.gd:179-180, 1355-1358`), zeroed on the bench. FIELD=200 stays.

## THE DECREE (build order)

1. **`gun_fx.gd`** — ladder: napalm 13.0 / heavy 10.0 / mortar 6.0. Napalm-specific CACHED
   composition (per-event cost zero): no shock ring, emitters seated low (burst at
   canopy, not 155 m up), climb bounded (event top ≤ ~2× width over full lifetime),
   ember velocities arcing (burning-gobbet read, not rocket exhaust). `MAX_LINGER` 8→9
   (the 9th drop of every run currently gets no lingering smoke). Static
   `bench_size_mult` (default 1.0, reset in `reset_session`) multiplied into
   `play_explosion_3d` so the ruling bench can sweep size live through the REAL path.
   Header arithmetic recomputed; "x5" fossil comments corrected here, in
   `destructible.gd:200`, and `cas_airplane.gd:401` ("Five canisters" → nine).
2. **`support_fire_range.gd`** — world-matched fog (constants from `game_world.gd:82-87`),
   `[`/`]` size-knob keys driving `GunFX.bench_size_mult` with the computed napalm width
   on the legend, SHIFT+number fires at 210 m (the demo's early-beat range) instead of
   60 m. Night toggle already exists.
3. **`vfx_range.gd`** — V cycles GOD → PLAYER-210 → PLAYER-100 (eye 1.7 m, FOV 75, level);
   N fires the real 9-drop run (constants referenced from `FirePlan`/`CASAirplane`, never
   re-typed) with the 9 burn carpets; treeline band of real vegetation GLBs at the strike
   line; 1.8 m man reference; 50 m height ladder; row-view caveat ("napalm shown as ONE
   DROP — game fires 9"); active-vantage + clean-air signage; R homes GOD. Header ~90 m
   drift corrected.
4. **Verify:** `probe_fire_parity` (behaviour counts must hold — it prints the ladder,
   gates only counts) + `test_fossils` (new symbols have callers). Full suite stays
   parked per the wave-end law; the morning scoreboard stands.

## NAMED SACRIFICES (no free lunches)

- The 8/12 map-width decree falls entirely — its letter is overturned by his own
  ground-level conviction the same night.
- The 690 m accidental sublime is gone; the satchel loses its screen-filling scream
  (111→46 m). If his eye misses the enormity, the knob finds it in minutes.
- Huts still die with the napalm-size fireball (60 m after today, was 513 m) — the class
  question goes to him, not guessed.
- The bench suite grows ~200 lines and two keys; the row view stays unfair to napalm
  (caveated, not fixed).
- Napalm AUDIO still borrows the heavy-artillery bank ×9 — after the visual shrinks, the
  sound will be the loudest thing left saying "nuke". Queued, not silently retuned.

## FOR THE SUMMONER (the decision queue — glossed, rulable without opening files)

1. **Napalm's hugeness now lives in the CHAIN, not one fireball** — nine 60 m bursts
   rolling up a 240 m lane that matches the mark on your map, then 25 s of burning
   ground. That is the reading of your 8/5 "rolling wall" ruling this decree ships.
   Confirm or overrule on the bench — `[`/`]` sweeps the size live.
2. **When a hooch dies it throws the napalm-class fireball** (was 513 m, now 60 m — still
   12× the hut). Want huts on their own smaller fire class (~20-25 m, same flame look)?
3. **Artillery (~46 m) and mortar (~28 m) moved with napalm** to keep your size order.
   Same bench, same knob — re-rule them if the eye disagrees.
4. **Napalm's sound still says nuke** (borrowed heavy-arty bank, nine at once). Queue an
   audio pass, or live with it for the demo?

## Follow-ups recorded (not this session)

- `ambient_war.gd:193` bypasses the ladder at fixed scale 12.0 (horizon events at
  200-800 m, deliberate) — after the re-anchor it equals the new napalm size; verify it
  still reads at horizon range. His eye.
- Napalm audio bank (above). — `production/DEMO_SHIP_BACKLOG.md` carries both.
