# WHEN YOU RETURN — the demo-shape list, in order

*Written 2026-08-15 at his ask: "a list of steps for what I should be doing the next
time I return to the project for getting the game into demo shape."*

**Where things stand.** *(CORRECTED 2026-08-31 — this line said the air-support stutter was
"DEAD" and it claimed more than the probe proved. What 8/14 actually measured was that the
SPAWN-BURST class was dead and that the airstrike was innocent of it; the raid path itself was
never benched on its own, and no line of it was changed that day — the `62a80716` diff against
every air-support file is `SpawnLedger.note()` calls and nothing else. The raid was finally
measured alone on 2026-08-31 and it did carry real cost: see PERF_LEDGER 2026-08-31.)*
The 8/14 spawn-burst fix is real and the handoff's suspect was innocent of THAT burst: it was
mass man-instantiation, not fire-support dispatch. Your ruling was *"the stutter is fixed FIRST, my siege replay runs
AFTER."* The first half is done. **The replay is now the next thing, and it is yours.**

The plan you approved on 8/14 night is `DEMO_TIGHT_40_2026-08-14.md` — forty steps, six
blocks. This page is only the part **you** hold. Everything else I can run without you.

---

## 1. THE SIEGE REPLAY — one run, ~20 minutes, do this first

`production/SIEGE_REPLAY_CHECKLIST.md` — boot `scenes/levels/demo_game.tscn`, play the
day into the night attack, live to the end card.

**Why it is first:** it is step 1 of the approved plan and it gates Blocks 1–2. Six
separate changes are sitting at "probe-verified" waiting for your eye to make them
"verified": honest navmesh on berms and bunkers, squads pressing through satchel holes,
hooches bursting at mortar size instead of map-wide fireballs, the Chinook stick walking
out the back ramp, the napalm chain reading as ~60m bursts not one sky dome, and the
spawn ring being center-true. **Nothing downstream can be trusted until this run happens.**

You do not need to diagnose anything. Tick what reads right; where something reads wrong,
just say WHAT you saw. The probes carry the numbers.

**This run also re-opens the demo gate (ADR-015).**

---

## 2. RATIFY THE FPS GATE — one decision, 5 minutes

The charter's **#1 named systemic risk, unset since July**. The measurements are done and
waiting in `PERF_LEDGER.md`:

    demo siege, shipping scene, 0.75 scale
      quiet            33.9 avg / 9 min
      assault inbound  27.4 avg / 5 min
      assault on wire  22.6 avg / 5 min

Proposal on the table: **>= 20 avg / >= 10 min**, measured at the crucible worst-frame on
this box. On the wire that carries ~2.6fps of margin. The ~5fps minimums are GPU-led dips
now (gpu_ms_max 35–41 vs cpu_ms_max 9–10), not CPU spawn bursts — those are gone.

**Your yes makes it law and the suite gains the gate.** Without a number, "is the demo
fast enough" stays an opinion forever.

---

## 3. THE EYE RULINGS — the fire range, ~15 minutes

Sizes only you can settle, with the `[` / `]` knob live on the range:

- **heavy** (~46m now) and **mortar** (~28m now) — bank your numbers, they go into `_KIND_SCALE`
- the **day-night seam** at T+47s — your "leave it and judge" still stands; this is the judging
- **`ambient_war.gd`** horizon events at fixed scale 12.0 — do they still read at 200–800m
  against the re-anchored ladder, or did the horizon war go quiet?

---

## 4. YOUR BENCH LIST — Blender, at your pace

Sequenced, but they interleave whenever you want (steps 31–36 of the plan):

1. **M72 LAW viewmodel** — `model_path` is literally empty; the manifest already declares
   `RIG_M72_LAW`. Then `python tools/export_all_viewmodels.py m72_law`.
2. **RPD + RPG-2 re-export** — the manifest gate passes now:
   `python tools/export_all_viewmodels.py rpd rpg2`. RPG-7 needs a decision (also empty).
3. **Three re-aims on the bench** — m60 / m79 / shotgun. Their spans print every run
   (35.7 / 11.4 / 59.0); ak47 and mosin were done 8/13, so the register only shrinks.
4. **Ladder MESH for the four towers** — 7.4m `ladder_bottom`/`ladder_top` pairs. The climb
   works; **no mesh exists anywhere in the project.**
5. **Blender renames** — med/chow soft+destructible ruling, the 242 hard `fb_hwall_*`,
   medic brassard red cross.
6. **HQ + village interiors/cabinets**, non-gun handheld exports with hit-placement markers.

---

## 5. DECISIONS PARKED ON YOU (no work, just a call)

- **Spooky bake-off**: v3 is built but NOT wired. No roster switch without your word.
- **Detection pip** (step 24) — the one unshipped stealth affordance. Build it, or rule it
  post-EA. It predates the demo scope.
- **Cover-seek fix** — men stop 4–5m short of walls. The fix retunes every sightline the
  siege was tuned against, **including your own squad**, so it only lands in a session you
  are watching. Say when.
- 11 radio-voice borderlines · body-bag stack · m101 split / water-buffalo horn.

---

## WHAT I RUN WITHOUT YOU (so you don't spend your time on it)

Clean full-suite baseline on a quiet box · adjudicate `test_air_fleet`'s `[NAV] enemy on
baked region 0` row · the 1 off-mesh bunker post + 4 `fb_bunker_revet_*` capsule blocks
(posts 0/6/14/35) · the three demo perf poses (THE WALK · ONE DIG · THE BARRAGE) · the
stress crucible and its frame attribution · napalm audio bank · garrison idle variety ·
coincident/floater probe back-port to the m151/m35 gates · cupola traverse clamp.

---

## THE HONEST SHAPE OF IT

**One 20-minute playthrough unblocks more than anything else you could do.** Blocks 1–2 of
the approved plan are held behind it, and six changes are queued at probe-verified waiting
on your eye. Everything else on this page can wait; that cannot.

Second most valuable: **the FPS number**, because it converts every future perf claim from
argument into measurement.

Known-red going in, so nothing surprises you: `test_asset_probe` carries 6 pre-existing
failures (fsb_main_v3 996m band, 4 heli staged clips, original spooky raw-vs-import-scale) —
they predate the 8/14 chain and are not in `$KnownRed`, so the suite reads FAIL until they
are triaged. The A-1 wreck has a wing-in-mound z-fight. `assert_texture_names` measures the
scene, not the file.
