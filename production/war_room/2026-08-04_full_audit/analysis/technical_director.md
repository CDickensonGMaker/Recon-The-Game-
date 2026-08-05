# TECHNICAL DIRECTOR — FULL AUDIT 2026-08-04
## Dimension: performance, tech debt, verification debt

Independent sight. Codebase read directly; every assertion carries a pointer or is marked
as a measurement to take. Working-tree note that colors everything below: **the tree is
dirty on top of `1795b519`** — `project.godot`, `scripts/combat/hitzone_builder.gd`,
`scripts/visuals/model_actor.gd`, `scripts/vehicles/seat_system.gd`,
`assets/shared/anim_library.glb` all modified, uncommitted (`git status`, 2026-08-04).
Any export cut today embeds unreviewed state.

---

## 1. THE 30-MINUTE HUNT — what else has never run that long

Method: enumerated every `static var` Array/Dictionary in `scripts/` (33 hits), then
audited every per-event append in the long-lived autoloads and directors for a bound or a
reaper. Verdict per accumulator:

### BOUNDED, verified by reading (the good news is real)
| accumulator | bound | pointer |
|---|---|---|
| bullet decals / scorch / blood / pools | FIFO 48 / 12 / 24 / 12 | `gun_fx.gd:66-69,228-231,535-536` + pop_front loops `:390,662,728,753` |
| explosions / linger / flashes / impacts | 6 / 8 / 64 / 12 | `gun_fx.gd:66-68,246,338,460,492` |
| gibs / frags | 12 / 16 FIFO | `gib_system.gd:11,194,289,355` |
| ambient-war engagements | reaped per tick | `ambient_war.gd:209` |
| air flights | reaper: arrived / vanished / `MAX_FLIGHT_SECONDS` | `air_traffic.gd:757-760` |
| siege withdrawal ghosts | `_process_reap` rally/radius/timeout | `siege_director.gd:745-769` |
| siege cells | freed + `cells.clear()` at break | `siege_director.gd:732-733` |
| enemy corpses | `queue_free` at 45 s | `enemy_base.gd:2728` |
| squad crumbs | `CRUMB_MAX 20` pop_front | `enemy_squad.gd:10,259-260` |
| evidence fixes | TTL prune + proximity merge | `evidence_ledger.gd:46-54,76-80` |
| audio voices / steps | fixed pools | `audio_manager.gd:86-88,111` |
| nav boxes | cleared per world build | `nav_baker.gd:78` |
| campaign mission_log | sliced to 40 | `campaign_state.gd:278-279` |
| unreported corpses | 48, oldest first (8/4) | `enemy_base.gd:966-1019` |
| world weapons | 24 FIFO + 3 reprieves (8/4) | `world_weapon.gd:26-29,73-92` |

### NEW FINDING N-1 — the air schedule's stagger is dead code, and the sky arrives in bursts
`air_traffic.gd:103-109` books `TRANSITS_PER_HOUR = 3` transits per daylight hour at
staggered fractional hours (`at_h = h + slot/3`, `:105`). But `SimClock._tick_schedules`
matches on **`int(s.hour) == cur_hour_int`** (`sim_clock.gd:86,91`) and only runs on an
integer-hour crossing (`sim_clock.gd:49-51`). **The fraction is truncated: all three
bookings fire on the SAME physics frame, once per sim-hour.** Each is a FORMATION of up
to 9 ships (`air_traffic.gd:39`); the ceiling of 14 (`:68`, per-ship since 8/4 `:474-478`)
caps the survivors, but up to ~14 airframes can be **instantiated on one frame**, every
~95 s of wall time at the demo's 38x — on a project whose own comments call it call-bound.
The 7/31 fix (`f8350e7f`, per-ENTRY dedup keys) fixed *collapsing to one*; it did not fix
*firing all at once*. The combat-load gate defers exactly ONE turned-away transit
(`air_traffic.gd:156-158`) — the burst itself is not deferred.
- **Never-run status:** no build has run an hour crossing at 38x with the 8/4 wiring.
- **Measurement:** M-3's 30-minute run, watch the log for `[AIR]` lines clustering on one
  timestamp and a frame-time spike at each ~95 s boundary. Pass = no visible hitch at the
  crossing; fail = stutter every 95 s.

### NEW FINDING N-2 — `_fired_event_keys` never shrinks (minor, say it anyway)
`sim_clock.gd:24,98`: one dictionary key per fired schedule entry per day, pruned only by
`clear_schedules()` (`:76-78`). Rate: ~58/day with the default air schedule (18 h × 3 + 4).
Memory-trivial across a demo or even a long campaign sitting; a leak in principle, not in
practice. Not worth code. Noted so nobody rediscovers it as a scare.

### NEW FINDING N-3 — the world-weapon ceiling exempts exactly the place the demo ends
`world_weapon.gd:87`: `_enforce_ceiling` skips any weapon within `PICKUP_RANGE_M * 2 = 5 m`
of the player. Every enemy death drops a weapon (`enemy_base.gd:2735-2744`). The demo's
climax is 45 men dying at a parapet the player is standing on — every drop inside his 5 m
bubble is exempt, so the 24 cap soft-breaches exactly during the call-bound worst case.
Bounded above by assault size (~45), so not unbounded — but the cap's protection is
weakest at the one moment it was built for. M-3's draw-call watch covers it: count
`world_weapons` group size at the end card.

### FULL-GAME-ONLY accumulators (slow, per-mission scale)
- `CampaignState.reported_marks` / `field_marks` / `pencil_marks` — appended per patrol
  (`field_director.gd:1190`, `campaign_state.gd:49`), never trimmed, persisted to cfg
  (`campaign_state.gd:316`). ~2-3 marks/patrol; a 100-patrol tour carries hundreds of
  marks the topo map presumably draws. Bound it when the campaign is real. DEMO: irrelevant
  (sandboxed cfg, `demo_game.gd:92`).
- `collapsed_tunnels` (`campaign_state.gd:479-483`) — same shape, slower.
- `EnemySquad._squads` — one dict per squad_id ever spawned, cleared per mission
  (`enemy_squad.gd:4`, `mission_scope.gd`). Bounded per mission by spawn count; a 14.5-h
  sim day with ambient circuits creates tens, not thousands. Acceptable.

---

## 2. THE 8/4 DEFUSALS THEMSELVES — never-run code, read skeptically

### 2a. `_thaw_held_cells` (`siege_director.gd:446-479`)
Logic is sound for its own door: headroom gate (`:453-455`), one-at-a-time, strength-fits
check (`:474-475`), correct hold-identification (dormant + physics-off, per the contract
comment `:436-441`). Two edge cases, both sub-critical:
- **E-1, the two-door overshoot.** A thawed cell is released but not yet `materialized`;
  `_light_check` (`:421-430`) counts only materialized men and can materialize OTHER lit
  cells up to `LIVE_CAP` in the same window, unaware of thawed cells in flight. Both doors
  spending the same room can transiently overshoot the cap by up to `THAW_HEADROOM`-scale
  amounts until `_enforce_live_cap` re-freezes. Reads as a brief flicker at the ring at
  worst; the demo authors at 45 vs cap 50 (`demo_game.gd:64-68`) precisely to avoid the
  freeze path, so in the demo this whole mechanism is a *contingency*, exercised only by
  M-2's 55-strength probe.
- **E-2, the stale print.** `:478-479` prints `materialized_men` captured before the
  release — the "%d live of cap" figure is understated by every cell released earlier in
  the same call. Cosmetic, but M-2's pass/fail reads these lines; know that the number
  lags.
- **Cannot thrash:** release requires `<= CAP-6`, re-freeze requires `>= CAP` (`:453-456`),
  a 6-man hysteresis band. Correct.

### 2b. `_bake_gun_only` (`world_weapon.gd:141-173`)
The bake itself is defensible (mesh-name + node-name arms match `:149-156`, zero-mesh
fallback to the marker box `:168-172`, materials carried `:164-165`). **One never-run trap
worth a 60-second look before trusting it:**
- **E-3, the baked transform may carry the burial offset.** The constructor's own comment
  says the viewmodel `.tscn` offsets the rig **-1.81 m underground** (`:105-107`).
  `_bake_gun_only` sets `root.transform = src.transform` (`:143`) and composes each mesh's
  transform up to the instantiated root (`_relative_transform`, `:186-192`). If that
  -1.81 m lives on a CHILD node inside the .tscn (between root and gun meshes), the baked
  gun inherits it and every dropped rifle renders 1.8 m underground — invisible, which in
  a playtest reads as "drops don't work", not as this bug. Second-order: skinned gun parts
  (bolt, magazine) are re-parented as plain `MeshInstance3D`; their vertices render in
  mesh space, which for skinned meshes is bind pose in SKELETON space — if the exporter
  authored them offset from the gun body, they detach.
  **Measurement (minutes, before M-3):** in any bench scene call
  `WorldWeapon.drop()` once per armory entry and look. Pass = every gun visible, on the
  ground, parts together. This is cheaper than discovering it 22 minutes into his one
  30-minute playtest.
- Reprieve math is sound: max life 600 + 3×300 = 1500 s < 1800 s demo (`:22,26,207`), so
  a gun dropped at boot cannot be immortal through the ending.

### 2c. Corpse cap (`enemy_base.gd:966-1019`)
Clean. Append-then-trim while-loop cannot ratchet; `_check_corpse_discovery`'s
`remove_at(i)` inside the loop returns immediately after (`:1039` then tier-set and the
function exits by structure) — the backlog's "checked and cleared" claim verified true.
`clear()` per mission at `field_director.gd:22`.

---

## 3. TEST SUITE — what the truth channel actually is right now

- **Size:** 137 `test_*.tscn` + ~13 probe/bench scenes in `tests/` (counted 2026-08-04).
- **Last recorded run: 101 pass / 18 fail / 14 error, 2026-07-27** — and that figure was
  already flagged "unverified as of today" in `AUDIT_2026-07-28.md:128`. **No suite result
  has been recorded anywhere in `production/` in the eight days since.** The suite is not
  red; the suite is *unknown*, with a stale red memory. The known hazard (reimport after
  `class_name`, memory `recongame-baselining-hazard`) means an unknown fraction of those
  32 reds are import artifacts, not bugs.
- **Fossil ratchet: INTACT.** `tests/fossil_baseline.json:3-4` — ceiling 3, count 3,
  matching 3 entries, `grandfather_log` empty. Down from 19 on 7/24. The one mechanism in
  this project that has verifiably done its job all month.
- **The perf instrument contract holds in-editor only:** `tests/perf_probe.tscn` attaches
  via `--perf-probe` (`game_flow.gd:711-718`) — see §4 for why this is a trap on the
  export.
- The suite runs headless via `tools/overnight_suite_chunk.ps1`; owner-runs-the-suite is
  the standing law (memory `no-headless-tests-while-coding`).

---

## 4. EXPORT / BUILD HEALTH — one export has ever existed, and the instruments don't board it

- **Presets are real and sane:** `export_presets.cfg` — preset 0 "Windows Desktop", preset
  1 "Windows Demo" (`:23`), `custom_features="demo"` (`:28`) which flips the feature-tagged
  main scene `run/main_scene.demo="res://scenes/levels/demo_game.tscn"`
  (`project.godot:22`), embedded pck, console wrapper on (`debug/export_console_wrapper=1`).
  File logging is ON in the export: `project.godot:47-49` →
  `user://logs/recon.log`, 8 files. **M-4's arrival print (`demo_game.gd:327-328`) and
  every `[DEMO]`/`[AIR]`/`[Siege]` line survive into the exported build's log.** Good.
- **FINDING X-1 — `--print-fps` DOES NOT EXIST.** M-2 and M-3 (8/3 synthesis
  `synthesis.md:408-409`) are specified against `RECON_Demo.exe --print-fps`. Grep of all
  of `scripts/`: the string occurs ONCE, in a comment — `site_planner.gd:859`, which cites
  a 7/31 garrison A/B "measured on the exported demo (--print-fps)". `git log -S` shows
  that string only ever entered the repo inside that comment (`f8350e7f`). There is no
  handler. Either the 7/31 measurement used an instrument that never existed as described
  (POINTER LAW breach in shipped source), or a temporary build carried it and it was never
  landed. **As written, M-2 and M-3's FPS half cannot be executed.**
- **FINDING X-2 — the only FPS instrument crashes the export.** `game_flow.gd:713` does
  `(load("res://tests/perf_probe.tscn") as PackedScene).instantiate()` when `--perf-probe`
  is passed — and `tests/*` is excluded from both presets (`export_presets.cfg:11,31`).
  On the export that load returns null and the call is a null-instance crash. So the
  exported demo has **zero** FPS instrumentation: no `--print-fps`, no probe, only the
  editor. M-3's "watch draw calls" currently has no legal way to happen on the .exe.
  (Also: Godot user args need the `--` separator — `RECON_Demo.exe -- --flag` — worth
  putting in the M-spec so a run isn't silently unflagged.)
- **X-3, smaller:** the one existing export (`b75f2d37`, 7/31, `build/RECON_Demo.exe`) is
  four commits and one dirty tree behind HEAD. Nothing from `1795b519` has ever been
  exported at all. And `project.godot` sits modified-uncommitted right now — the renderer
  key has been silently stripped by an editor save once before (PERF_LEDGER measurement
  contract, corrected 2026-07-26); diff it before the next export.

**SPECIFIED FIX-SHAPE (no code now, Law of the brief):** the cheapest honest instrument is
a ~20-line always-compiled FPS/draw-call printer gated on a user arg, living in `scripts/`
(not `tests/`), printing 1 Hz to stdout+log. Minutes of work, and it unblocks M-2, M-3 and
every future exported measurement. Until it lands, M-3 degrades to "run 30 minutes and
watch with your eyes + read `user://logs/recon.log` afterward" — which still discharges
most of the ledger below, but banks no draw-call number.

---

## 5. VERIFICATION DEBT — the ledger

Baseline for "verified": the 7/31 exported-demo session (garrison A/B, `f8350e7f` commit
message) is the last time ANY build ran outside the editor; the Summoner's last verified
playtest of the current arc: none — the arc was rescoped 8/3 and wired 8/4 and has never
run (briefing standing fact 3). Session entry gate PLAYTEST R4 also stands undischarged
(CLAUDE.md, OVERSEER_CHARTER.md:95).

### BUILT-AND-UNVERIFIED LEDGER (2026-08-04)

| # | system | pointer | discharged by | still dark after M-1..M-5? |
|---|---|---|---|---|
| 1 | Freeze latch + thaw | `siege_director.gd:446-479` | **M-2** (needs strength > cap) | no |
| 2 | Viewmodel bake for drops | `world_weapon.gd:141-173` | pre-M-3 bench look (E-3) + **M-3** | no |
| 3 | World-weapon FIFO/reprieves | `world_weapon.gd:26-92,198-209` | **M-3** | parapet exemption N-3 needs the end-card count |
| 4 | Corpse memory cap | `enemy_base.gd:966-1019` | **M-3** | no |
| 5 | 38x/20x arc clock + seam | `demo_game.gd:39-54,350-355` | **M-3** | no |
| 6 | Opening gate order | `demo_game.gd:289-328` | **M-4** | no |
| 7 | Demo world signs + camp | `mission_generator.gd:624,738,796` | **M-3** | no |
| 8 | False-alarm detection fix | `field_director.gd:122` | **M-3** | only if a clean-kill run happens |
| 9 | Air ceiling per-ship + pad de-dup | `air_traffic.gd:453-478,592-654` | **M-3 + M-5** | no |
| 10 | Gunship `gun_orbit` ending | `demo_game.gd:412-428`, air_traffic orbit | **M-3** (must reach 30:00) | no |
| 11 | Radio-as-object handoff | `squad_system.gd:567,582` | NONE of M-1..5 — fires only when the RTO dies | **YES — dark** |
| 12 | Fire-support bombs:3 allotment | field_director allotment | **M-3** only if he calls it | **conditionally dark** |
| 13 | Chow-hall occupation mapping | civilian_schedules + site_planner | **M-1** gates; needs his GLB re-export | **YES — blocked** |
| 14 | 19 chow clips (uncommitted GLB) | `assets/shared/anim_library.glb` (dirty) | nothing — unwired | **YES** |
| 15 | Air burst-at-hour-crossing (N-1) | `sim_clock.gd:86,91` + `air_traffic.gd:105` | **M-3** hitch watch | no |
| 16 | Suite state itself | 101/18/14 @ 7/27, `AUDIT_2026-07-28.md:128` | none — needs a suite run | **YES** |
| 17 | Export of ANY post-7/31 code | one export ever, `b75f2d37` | **M-3 requires cutting export #2** | no (cutting it IS the discharge) |

**Count: 17 built-and-unverified items. One 30-minute exported playtest (M-3) plus
M-1/M-2/M-4/M-5 discharges 12 of 17.** Still dark afterward: radio handoff (#11 — needs a
staged RTO death; add "get the RTO killed once" to the playtest script and it costs
nothing), chow hall (#13/#14 — blocked on his Blender bench + M-1), the suite (#16 — one
headless overnight), and conditionally the fire-support call (#12 — script it into M-3).
The standing "ships at 20/day, verifies at 0/day" arithmetic: everything in §2 of the 8/4
backlog was parse-checked only; the entire defusal layer's correctness is currently a
claim by the author, me included.

---

## 6. RANKED LISTS

### STRONGEST
1. **The bounding discipline is now real and near-total** [DEMO+FULL] — 15 audited
   accumulator families all carry FIFO caps, TTLs or reapers (§1 table). One session of
   hunting found zero *unbounded* runtime accumulators; the two new findings are burst
   and exemption shapes, not leaks. The GunFX FIFO pattern has propagated everywhere.
2. **The fossil ratchet** [FULL] — 19 → 3, ceiling honest, log empty
   (`fossil_baseline.json:3-10`). The one continuously-verified truth mechanism.
3. **Export scaffolding is genuinely ship-shaped** [DEMO] — feature-tagged demo main
   scene (`project.godot:22` + `export_presets.cfg:28`), sandboxed saves
   (`demo_game.gd:81-95` closes both leak holes it documents), file logging into the
   export (`project.godot:47-49`). The .exe path is a working road, walked once.

### WEAKEST
1. **The measurements are specified against instruments that do not exist** [DEMO] —
   M-2/M-3 name `--print-fps` (no handler anywhere; only occurrence is a comment citing a
   past measurement, `site_planner.gd:859`), and the fallback instrument crashes the
   export (`game_flow.gd:713` loads excluded `res://tests/perf_probe.tscn`). The
   verification plan cannot currently be executed as written. This is verification debt
   about the verification plan itself.
2. **17 built-and-unverified systems, including every 8/4 landmine defusal** [DEMO] —
   §5 ledger. The demo's entire arc, ending, and both accumulator fixes have executed
   zero times. Highest-risk single item: E-3, the baked drop possibly rendering
   underground — a bug that would read as a missing feature in his one playtest.
3. **The truth channel is stale at both ends** [FULL] — suite unknown since 7/27
   (`AUDIT_2026-07-28.md:128`), PLAYTEST R4 undischarged, and the dirty working tree
   (incl. `project.godot`) means even "HEAD" is not a defined build to verify against.

### IMPROVE (value per effort, priced)
1. **Land a shipped-code FPS/call printer + fix the M-2/M-3 spec** [DEMO] — ~20 lines +
   a doc edit; unblocks both gated measurements and every future exported number.
   Value: enormous (it is the prerequisite of the whole verification plan). Effort:
   under an hour. *Sacrifice: a permanent debug surface in shipped code.*
2. **The 60-second drop-bench look (E-3) before his playtest** [DEMO] — minutes; converts
   the single most likely playtest-ruining unknown into a known.
   *Sacrifice: none worth naming.*
3. **De-burst the air schedule** (honor the fractional hour, or queue-and-drip the
   hour's bookings) [DEMO+FULL] — small, kills a predicted every-95-s hitch source on
   call-bound hardware (N-1). *Sacrifice: the sky gets slightly less punctual; and it is
   a pre-verification change to never-run code — reasonable to sequence AFTER M-3
   confirms the hitch is real.*
4. **One headless suite run + re-baseline against the reimport hazard** [FULL] — ~an
   hour unattended; turns "101/18/14, dated, unverified" back into a truth channel.
   *Sacrifice: the baselining hazard itself — a careless re-baseline can bless real
   reds; triage each red against 7/27's list, never regenerate blind.*
5. **Bound `reported_marks`/`field_marks` when the campaign becomes the product**
   [FULL GAME only] — defer; demo-irrelevant.

### Law 2, said once for the whole file
The 8/4 caps traded permanence for the frame: 24 guns, 48 remembered bodies, 3 reprieves
are all *memory of the war* sold for draw calls — the right trade, but it is stealth's
and permanence's coin that paid. And every IMPROVE above spends the scarcest resource
this project has: the Summoner's bench time before his playtest. Items 1-2 are priced
under an hour combined precisely so they do not compete with M-3 for it.
