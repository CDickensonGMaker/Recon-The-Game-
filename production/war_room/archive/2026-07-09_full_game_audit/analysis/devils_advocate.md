# DEVIL'S ADVOCATE — Full Game Audit (2026-07-09, branch `overnight-claude`)

No vibes. Every claim below carries file:line or bead evidence. The theme of this audit:
**the project builds faster than it verifies.** 106 commits in ~72h, two human playtest
sessions, three P1 playtest bugs still open, and a target-GPU framerate of 19-25.

---

## (a) Five things genuinely working

1. **The mission-loop spine is real and persistent.** Menu → seeded mission select → world
   build → objectives → exfil → XP bank → save → debrief, verified end-to-end by the audit
   that produced `production/WIRING_STATUS.md` (its "spine is solid" section holds up under
   re-inspection). `scripts/main/game_flow.gd`, `scripts/autoload/campaign_state.gd`.
2. **Cross-mission teardown is proven, not claimed.** `scripts/main/mission_scope.gd:7-10`
   documents each static-state leak *with the probe that proved it*
   (`tests/probe_smoke_all.gd` section B). This is the standard the rest of the repo should meet.
3. **Learn-by-doing XP is integrated, not bolted on.** `credit_use` has four real
   choke-point callers: medic revive (`scripts/squad/squad_system.gd:161`), point-man warning
   (`squad_system.gd:198`), RTO fire call (`scripts/missions/mission_director.gd:277`), kills
   (`scripts/enemies/enemy_base.gd:1541`). Growth mutates the roster dict in place so the
   mission-end save carries it (`scripts/squad/squad_roster.gd:61-84`). Clean seam.
4. **Fire support breadth is wired.** Six call types with budgets, fo_fac scatter scaling,
   cooldowns, RTO gating, F-4 flyby with the real model (`mission_director.gd:219-299`,
   commit d93c059). The *logic* layer is genuinely connected — the UX layer is where it rots (see risks).
5. **The project audits itself honestly.** The 8pbo perf bead *refutes its own two
   hypotheses with measurements*. The collision table was re-measured from GLB AABBs instead
   of trusted (`scripts/world/collision_table.gd:45-46`, commit 3a40714 — hangar was 40x30x12,
   not 3x2x3). WIRING_STATUS names its own dead code. This culture is the project's best asset. Keep it.

---

## (b) Top 7 risks / rots, ranked — each with the cheapest mitigation

### RISK 1 — The danger-close confirm is a lie: the second keypress switches your weapon
**Severity: shipped bug in a flagship feature, zero playtests since it landed (502e835).**

`request_fire_support()` closes the menu as its *first act* (`mission_director.gd:220`,
`fire_menu_open = false`) — *before* the danger-close check pends at `:239-242`. So when the
toast says "PRESS AGAIN TO CONFIRM":
- The slot-key handler at `:183` is gated on `fire_menu_open` — now false. The second press
  never reaches `request_fire_support`.
- Worse: `equipment_manager.gd:62` gates weapon slots on `any_fire_menu_open` — also now
  false. **The confirm press holsters your rifle and pulls out slot 3.** Mid-firefight, aiming
  at your own men.
- The only real path to confirm is: press T again (re-running the RTO/leash checks), then the
  slot key. The toast never says this.

Second bug in the same seam: `_pending_danger_close` (`:216`) **never expires, is never
cleared on menu close, and is not bound to the target position**. Pend "arty" near your squad,
decline, fight for ten minutes, then call arty near squadmates on the far side of the AO —
it fires with **no confirm**, because `_pending_danger_close == "arty"` still (`:239`).

Third gap: `_danger_close_to_squad()` (`:303-311`) checks squadmates only — napalm on your
*own* feet needs no confirm. Arguably design; name it deliberately or fix it.

**Cheapest mitigation (~8 lines):** move `fire_menu_open = false` *below* the danger-close
early-return so the menu stays open awaiting the confirm; clear `_pending_danger_close` in the
`fire_menu_open` setter when the menu closes; add a 5s expiry timestamp. Then one human test.

### RISK 2 — The 10m radioman leash is UX theater: two inputs bypass it entirely
The leash and the whole "get on the radio" exposure (rifle down `weapon_holder.gd:173,590`,
shuffle `player.gd:610`, no sprint `player.gd:588`) apply **only to the T menu**
(`mission_director.gd:170-179`). But:
- `mortar_strike` (Y key, `:200-201`) calls `request_fire_support("mortar")` directly.
- `supply_drop` (key 8, `:202-203`) calls `request_supply_drop()` directly.

`request_fire_support` itself checks only `is_rto_alive()` (`:222`) — **no distance check**.
Press Y from 200m away from your RTO, rifle up, at a sprint: fire mission goes out. The leash
landed (2907d27) without a playtest, and the very first playtest would have found this in
minutes. Sacrifice named: the leash's entire design goal — "the radio is on his back" — is
void for the most-used call (mortar, the only one with a default budget, `:213`).

**Cheapest mitigation (~10 lines):** extract the RTO-alive + leash check from the menu-open
branch into one `_can_use_radio() -> bool` and call it at the top of `request_fire_support`
and `request_supply_drop`. Decide deliberately whether Y stays a shortcut at all.

### RISK 3 — 162 VO files, zero code plays them: the voice pipeline is a content cul-de-sac
`assets/audio/vo/` holds 162 wavs across 5+ voices (joe/bryce/john/ryan/hfc_male...), with
role assignments in `tools/voice_studio.py` (fc79743). Grep for `vo/`, `bryce`,
`radio_fire_mission`, `squad_contact` across every `.gd`: **zero matches**. `AudioManager` has
no VO path. Barks are still toast text (`squad_system.gd:201`, WIRING_STATUS "barks exist as
on-screen TEXT only"). WIRING_STATUS itself names audio/VO the "biggest felt absence" — and the
last 48h produced *more unplayed audio* rather than the player for it. That is generation
outpacing integration, in one line.

**Cheapest mitigation (one evening):** a ~40-line `VoiceBus` autoload:
`bark(role: String, key: String, pos: Vector3)` → maps to `res://assets/audio/vo/<voice>/<key>.wav`
via the VOICE_ROLES table copied out of voice_studio.py, plays through the existing
`AudioManager._acquire_voice` pool. Wire it at the ~10 places toasts already fire. The content
is *done*; only the last 5% (the part that makes it exist in-game) is missing.

### RISK 4 — Playtest debt: ~30 commits of untested systems stacked on 3 open P1 playtest bugs
Last human session: 2026-07-08 combat lab. Since then landed *without a human touching them*:
squad XP, danger-close confirm, radio UX + leash, CBU menu, explosion visuals, punji traps,
F-4 flyby, POW cage, firebase/village variety, **a global collision overhaul** (89 re-measured
entries + mesh-collision mode, 3a40714). Meanwhile the P1 bugs the last session found are all
still open:
- `a2qb` — not seated in the Huey, two heli bodies (first minute of every mission).
- `r4bk` — squad controls "gone" (suspect: F1-F4 HUD legend dropped in 33d0721 — **Pillar 4's
  primary verb is invisible**).
- `e6qc #1` — stuck-on-collision wedge, *unreproduced* — and collision just changed globally.
  If the wedge was box-collision-related, 3a40714 either fixed it or moved it. Nobody knows which.

**What breaks first in a real session, in order:** (1) the insertion Huey looks broken before
the first shot (a2qb); (2) player tries fire support, hits the danger-close weapon-switch
(Risk 1); (3) gets wedged on one of 89 new collision boxes or a mesh-collider doorway (e6qc/3a40714);
(4) all of it at 19-25 FPS (Risk 5).

**Cheapest mitigation (free):** a hard rule — **no new system lands while a P1 playtest bug is
open.** 30-minute human session as the gate before any new epic starts. The probes are good;
they cannot feel a wedge, a missing HUD legend, or a confusing confirm.

### RISK 5 — Perf: 19-25 FPS baseline, and everything since has only added cost
Bead `8pbo` (measured, honest): flat 19-25 FPS on the target Intel UHD, seed 4242, 56s probe.
Since that measurement landed: procedural explosion visuals spawning an `OmniLight3D` +
billboard + particles per blast (`scripts/combat/gun_fx.gd:109-131`; an arty mission = 6 in
~4s, `mission_director.gd:263-265`), 2-4 extra interior structures per firebase + pagoda +
bell tower per village (3a40714), per-trap `_physics_process` scanners (`punji_trap.gd:34`),
F-4 model. And a found perf smell: `_point_scan()` runs **every physics frame** — its throttle
timer `_point_scan_timer` is declared at `squad_system.gd:181` and *never used* — doing a
group-wide distance scan at 60Hz on a 20 FPS game. Pillar 1 ("outstanding gunplay") is
arithmetic-impossible at 20 FPS regardless of how good the recoil code is.

**Cheapest mitigation:** (1) 3 lines — actually use `_point_scan_timer` (0.5s). (2) Free —
re-run `tests/probe_perf_decay.gd` and append the number to `8pbo` after every landing that
adds scene content; make it a session-close gate. (3) Budget before adding: the bead itself
already says "budget this before the bush-density work" — `360a` (more bushes) must stay
frozen until 8pbo moves.

### RISK 6 — The two-window workflow is already colliding with itself
Live evidence in the working tree *right now*: 20+ modified-uncommitted `.glb` files
(punji_trap, mg_nest, sandbag_*, gate_entrance, ruins_corner...) — the Blender window
re-exporting — while the code window just baked **those same files' AABBs** into
`collision_table.gd` as 89 hand-frozen constants (3a40714). If any re-export changes
dimensions or drops/renames the `-col` trimesh nodes that `mesh: true` entries depend on
(`site_planner.gd`), the collision table silently drifts from the art: doorway blockers and
walk-through walls, the exact bug class 3a40714 existed to kill. Same exposure for
`huey.glb` (a2qb's material/body mystery) and every `.tres` both windows can touch.

**Cheapest mitigation:** (1) ownership rule, one paragraph in CLAUDE.md: Blender window owns
`.blend`/`.glb`; code window owns `.gd`/`.tres`; `collision_table.gd` is *generated, never
hand-edited*. (2) The headless-Blender measuring script from f5yf already exists — re-run it
whenever `git status` shows dirty GLBs, before any collision-dependent commit. (3) Commit or
stash art changes before code sessions.

### RISK 7 — Scope: 88 open beads, 19 P1s, 9 open epics, one person
`bd list --limit 0`: **91 issues, 88 open**, 19 P1, 9 epics. The epic load alone: campaign
overhaul (`4i60`), FP viewmodels (`36pk`), sprite matrix (`9xd`), interior mode (`gfgr`),
driveable vehicles (`rw28`), RPG shop loop (`m177`), capture/POW (`iyuh`), ride-or-walk
(`8oki`), battle director (`ccqv`) — plus coop research, 100 bios, a 17-weapon audio synth
bank filed **twice** (`ew4u` and `9qp6` are the same task), and a DLC-faction lane. This is a
3-year plan wearing a solo-dev hat. Bead hygiene is itself rotting: `hcly` is titled "(DONE)"
but still open; `xnu1` is a session log filed as an issue; the duplicate audio beads. The graph
is supposed to be session-to-session context — right now it inflates the apparent front.

Also flagged: **punji traps have no counterplay.** The point-man scan only checks
`lazy_groups` (`squad_system.gd:192`); `PunjiTrap` is in no group and no detection path.
`detect_ambush` — the skill named after this exact job — cannot see them. Freedom pillar says
informed risk; an undetectable 35-damage leg wound is a dice roll, not a decision. (~10 lines:
add traps to a group, include them in the point scan.)

**Cheapest mitigation:** the CUT/FREEZE list below, plus 15 minutes of `bd close`/merge
(hcly, ew4u↔9qp6, xnu1) per the owner's own bead-hygiene law.

---

## (c) What to CUT or FREEZE — specific

**KILL (zombie):**
- **The full sprite render matrix (`9xd`: 6 units x 5 weapons x 21 anims, 15-20h render
  queue).** 3D models are the *default* renderer by explicit decision
  (`enemy_base.gd:282-283`, c67818a); game-side sprite consumer for the matrix output was
  "zero lines" until the fallback path, and the bead's own note says "art first, code
  fitted afterward" — for a track that is now the fallback. The only live justification is
  Caleb's far-LOD idea (e6qc #4: sprites far, models near). So: **A/B the far-LOD band in the
  combat lab with the 3 sheets already assembled** (us_grunt/m16a1, vc2/mosin, vc5/ppsh) before
  a single further render-hour. If far-LOD wins, you need ~6 distance-readable anims, not 21.
  Child bead `j8o` (P1 sprite squadmates) dies with it — squadmates are 3D-model track now.

**FREEZE (explicitly post-core; do not touch until M5/M3 keystones + playtest bugs close):**
- Coop (research doc stays a doc), INTERIOR MODE (`gfgr` — already self-labeled post-core),
  driveable vehicles + turrets (`rw28`, `2kcp`, `izmf`), RPG shop loop (`m177`), CAPTURE
  (`iyuh`), battle director (`ccqv`), ride-or-walk (`8oki`), C-47 Spooky model (`y8ho`),
  gamepad (`p4z`), firebase designer dream (`222e`).
- DLC factions: already cut by the 2026-07-08 scope lock (ROADMAP.md:31-37) — **keep them
  dead**; `chil` stays P3 or closes.
- Bush density (`360a`) frozen behind 8pbo, per 8pbo's own text.

**SHRINK:**
- **100 bios → 20.** The roster loop, HQ tent, and permadeath feel identical with 20; author
  the other 80 only after one full campaign playthrough proves anyone reads them. (`ooel`)
- **Campaign overhaul (`4i60`): HQ tent as a *menu screen* first**, walkable 3D hub later.
  The XCOM loop is roster + persistence + mission offers — none of that needs a scene.
- Audio synth bank: merge `ew4u`/`9qp6`, and scope v1 to the 5 weapons actually in players'
  hands, not 17.

**The freed capacity goes to:** the 3 playtest P1s, the Risk 1/2 fire-support fixes, the
VoiceBus (Risk 3), 8pbo, and the M3/M5 keystones (`r6qe`, `gpvb`, `wbtd`) — which ROADMAP.md
already names as the actual critical path.

---

## (d) Pillar scorecard — where the pillars are currently lies

| # | Pillar | Score | Why (evidence) |
|---|--------|-------|----------------|
| 1 | Outstanding gunplay | **2/5** | The *logic* is good (hitzones, falloff, stagger). But: 19-25 FPS on target GPU (`8pbo`) — no gunplay is outstanding at 20 FPS; feedback pass `wbtd` still open; weapon audio bank unbuilt (`ew4u`); hitzones are fixed capsule offsets (`enemy_base.gd:331-337`) that do not follow 3D-model animation — the default renderer now visibly desyncs from where bullets land. |
| 2 | Atmosphere | **2/5** | Ambience is one global 2D loop (`xu94`, P1); 162 VO files silent in-game (Risk 3); squad speaks in toast text; claymore is a green box, Spooky is a box (WIRING_STATUS "placeholder visuals"). The *systems* for atmosphere exist; the sensory layer doesn't. |
| 3 | Freedom / escalation not fail-states | **3/5** | Genuinely the strongest: alert tiers, hunter escalation, emergency-exfil abort (`mission_director.gd:156-163`) are real. But player death is a hard fail (`_on_player_died` → `fail_mission("KIA")`, `:135-136`) with CAPTURE unbuilt, RTO death still hard-kills all fire support + resupply (`:222`, `:343` — named by the *previous* DA, still unaddressed), and punji traps are unavoidable dice (Risk 7). |
| 4 | The squad is the RPG | **3/5** | Learn-by-doing XP is the realest recent work (see (a)3). But the last human playtest reported **squad command controls gone** (`r4bk`, P1, open) — the pillar's primary interface is missing or invisible; squadmates' own st/ag stats still partly ignored (WIRING_STATUS 🟡); squad voices silent. An RPG about men who can't be ordered and don't speak. |
| 5 | Fail forward | **2/5** | Abort-exfil is the one true fail-forward mechanism. Death=restart, capture=unbuilt (`iyuh` frozen), wounded-out/rescue absent, and the danger-close/leash bugs (Risks 1-2) mean the punishing-but-fair fire-support fantasy currently punishes via *UI misfire*, which is failing backward. |

**Composite: 2.4/5.** The gap in every low score is the same shape: simulation built,
presentation/verification skipped. The pillars don't need new systems to stop being lies —
they need the last 5% of ten existing ones.

---

*Filed by the Devil's Advocate. Nothing else in the repo was modified.*
