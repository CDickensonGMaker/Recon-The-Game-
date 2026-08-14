# HANDOFF — AIR-SUPPORT STUTTER FIX (his ruling 2026-08-14, evening)

**The Summoner's ruling:** *"i think the stutter from air support needs to be addressed
first before i do the siege test."* This ORDERS the queue: the fire-support dispatch
stagger is now the top job, his siege replay (SIEGE_REPLAY_CHECKLIST.md) runs AFTER it
lands. This supersedes the earlier caution "don't touch GunFX timing before his replay"
— he has re-sequenced it himself.

---

## THE PROMPT (paste-ready — he says "RECONgame Project continue" and you do this)

> Read `production/HANDOFF_AIRSUPPORT_STUTTER_2026-08-14.md` and execute it top to
> bottom. The job: kill the fire-support spawn-burst stutter (the +2,000–4,600-node
> single frames when a napalm run / arty barrage / CBU dispatches). Order of work:
> (1) instrument the dispatch path with SpawnLedger so the attribution is PROVEN, not
> inferred; (2) re-run the crucible headless to capture the before-evidence with names;
> (3) stagger or pool the instantiation using the MarchingCell token-bucket pattern;
> (4) prove the fix with a before/after crucible comparison (FIRES worst-frame and
> hitch count are the scoreboard) and confirm the napalm/arty look is unchanged at the
> bench; (5) run the demo probe once for the siege rows; (6) records, commit, push.
> Standing constraints: no Blender, never touch his running game, zombie code protected,
> war-room a design question if one appears, loop until done. When it's green, tell him
> the siege replay is unblocked.

---

## THE EVIDENCE (from the 8/14 SpawnLedger attribution run — log was in the session
scratchpad, key lines preserved here; PERF_LEDGER tail has the summary)

Crucible headless, 5 phases. The four ledgered NPC sites (spawn_tracked_enemy,
AllyBase.spawn_ally, EnemyBase.spawn_enemy, Civilian.spawn) are CLEARED — MarchingCell's
2/frame stagger reports exactly as designed. The burst frames report NO ledgered spawns:

```
[HITCH] COMBAT 283ms | nodes +4135 (12535) objects +4815 | spawns: no spawns this frame
[HITCH] WAVE   261ms | nodes +2289 (20839) objects +3074 | spawns: no spawns this frame
[HITCH] FIRES  266ms | nodes +2701 (25043) objects +3194 | spawns: no spawns this frame
[HITCH] FIRES  282ms | nodes +4000 (27816) objects +4632 | spawns: no spawns this frame
```

- The COMBAT +4,135 frame is the arena's `_hot_start_combat` direct path (36 men ×
  ~115 nodes) — bench-only, arena is sterile by ruling, NOT the job. Do not "fix" it.
- The WAVE/FIRES +2,000–4,000 frames track the fire cycle (napalm run = airframe +
  9 canisters + GunFX procs; arty = 8–12 shells; CBU = 3 dispensers). **This is the
  demo-relevant class — the siege's 5–7 fps minimums.**
- Phase averages for context: BASELINE 9.05ms / COMBAT 10.10 / WAVE 25.92 / FIRES
  30.31 / EVERYTHING 23.09. Worst frames everywhere are the 265–283ms class.

## THE WORK

1. **Instrument before fixing (probe-before-claim).** The attribution is currently a
   negative inference. Add `SpawnLedger.note()` calls (see `scripts/world/spawn_ledger.gd`
   — static, per-physics-frame) at the fire-support instantiation sites. Find them from
   `FieldDirector.request_fire_support` (`scripts/missions/field_director.gd`) down —
   the airframe spawn, the ordnance/canister spawns, and the GunFX proc creation
   (`scripts/combat/gun_fx.gd`, the cached-proc branches). Re-run
   `res://tools/probe_crucible.tscn` headless; the hitch lines must now NAME the site.
2. **Stagger or pool.** The proven pattern is `scripts/enemies/marching_cell.gd` —
   `_take_spawn_token()`, a global per-physics-frame token bucket keyed on
   `Engine.get_physics_frames()`, no first-item exemption, cancel on teardown. Options
   in preference order: (a) spread canister/shell/proc instantiation across frames with
   a token bucket; (b) pre-pool the GunFX proc nodes at level load and reuse. Watch the
   gameplay contract: a napalm stick landing in sequence is PERIOD-CORRECT — a short
   stagger is cover, not a compromise. Do NOT change rendered sizes, velocities, or the
   ladder (`GunFX.rendered_width_m()` is law, `recon-vfx-bench-is-the-ruling-instrument`).
3. **Prove it.** Before/after crucible: FIRES worst-frame and count of >100ms hitch
   lines are the scoreboard. Then `--perf-probe --perf-siege` on the demo scene once,
   quiet box, for the siege rows. Bench-check napalm/arty by eye
   (`support_fire_range`, player-eye position) — the look must be unchanged.
4. **Records.** PERF_LEDGER row (before/after numbers), backlog entry, memory update,
   commit + push. Then tell him: **the siege replay is unblocked** — it is the gate
   re-closer (`SIEGE_REPLAY_CHECKLIST.md`) and everything else on his queue waits on it.

## STATE OF THE WORLD (2026-08-14 end of day, all pushed through `84686e80`)

- v2 fleet DONE and on the roster: m151/m35/m113 rebuilt at real dims, wrecks solid-color,
  aircraft v2s shipped. Gallery: the Night Fleet artifact (link in his chat history).
- HIS QUEUE after the siege replay: Spooky bake-off pick (v2 vs v3, NOT wired) · perf
  gate ratification (≥20 avg / ≥10 min on the wire) · detection pip (step 24) · 11
  radio-voice borderlines · heavy/mortar bench sizes · napalm audio + winded cue ·
  body-bag stack · m101 split / water-buffalo horn.
- Queued technical, not blocking: coincident/floater probe back-port to the m151/m35
  verifiers · m113 cupola traverse clamp · 6 pre-existing test_asset_probe failures
  (triaged in DEMO_SHIP_BACKLOG.md 8/14 entry — none touch new assets).
- Suite watchpoints: leak column is flaky (never convict on one reading) ·
  test_viewmodel_contract is the only KnownRed.
