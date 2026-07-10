# LEAD PROGRAMMER — DRIFT AUDIT #2 (2026-07-10)
Lens: CODE TRUTH. Every claim below is grounded in file:line at commit 8444795.
Bound by `~/.claude/architect_knowledge/godot_standards.md`.

---

## (a) DRIFT CATALOG

### A1. THE HEADLINE: o18o "stealth witnessed-contact fix" is RECORDED AS EXECUTED BUT DOES NOT EXIST IN CODE
- **Decree says** (2026-07-09 synthesis, wound #4 + build-order item 5; this audit's briefing lists it under
  "Decree items executed"): `take_damage()` must not stamp COMBAT contact on unwitnessed kills.
- **Code says:** `scripts/enemies/enemy_base.gd:1497` — `_set_tier(AlertTier.COMBAT)` is called
  **unconditionally** on every hit, BEFORE the death check at `:1526`. `_set_tier()` stamps the global
  detection beacon at `enemy_base.gd:626-627` (`EnemyBase.last_combat_contact_ms = ...`) **before** its own
  `if tier == alert_tier: return` dedup — so even a one-shot silent headshot kill (`:1466-1467` HEAD = instant
  kill) stamps the beacon. `mission_director.gd:68` (`_check_detection`) reads that beacon and fires
  "YOU'VE BEEN MADE". A ghost kill still raises the AO alarm.
- **Worse:** the comment at `enemy_base.gd:189-191` claims "a silent, unwitnessed kill no longer summons the
  QRF" — **the comment describes the intended fix, not the shipping code.** Also `_set_tier(COMBAT)` fires
  `GunFX.play_combat_sting` (`:641`) — a dying unwitnessed enemy plays the contact sting.
- **Bead truth:** `bd show o18o` → **P1, OPEN**, created 2026-07-09, never closed. Git history
  (`git log -L 1490,1510:scripts/enemies/enemy_base.gd`) shows the stamp has never been guarded.
- **Which is right:** the decree. What DID ship (commit c67818a-era) is the *escalation-on-detection-not-kill*
  architecture (`mission_director.gd:47-54`), which is half the design. The witness guard on the victim's own
  take_damage is the missing half.
- **Update:** implement the witness guard + a headless probe (silent kill → beacon unchanged). Fix the lying
  comment at `enemy_base.gd:189-191` or make it true.

### A2. FOV LAW BROKEN — code cheated ahead of ratification (bead 2spa)
- **CLAUDE.md:198 says:** "FOV locked at 75.0 everywhere (no ADS zoom)" under "CRITICAL: DO NOT CHANGE".
- **Code says:** `scripts/player/weapon_holder.gd:215-220` — comment literally reads *"W40: ADS FOV zoom
  re-enabled (per-weapon ads_fov)"*; `camera.fov = lerpf(BASE_FOV, zoom_fov, ads_transition)`. Every weapon
  .tres carries `ads_fov` (`data/weapons/m16a1.tres` → 60.0, `thompson.tres` → 58.0). Binoculars add a third
  FOV writer: `player.gd:110-118` lerps camera.fov to 18.0, with a hand-rolled truce
  (`if not (weapon_holder and weapon_holder.is_aiming)`) between the two writers.
- **Bead truth:** 2spa is OPEN and still frames "keep FOV-75-no-zoom vs 75→68 ADS zoom (needs CLAUDE.md
  amendment)" as an undecided question. The code decided it (as "W40") without amendment.
- **Which is right:** probably the code — the Summoner's 2spa comment endorses true iron-sight ADS. But a
  DO-NOT-CHANGE law violated silently by a wave-numbered commit is exactly the drift this audit exists for.
- **Update:** ratify via ADR, amend CLAUDE.md's viewmodel section, close/rescope 2spa.

### A3. Damage doc block in CLAUDE.md is stale on every line (code is RIGHT)
- **CLAUDE.md:169-174 says:** dice example `[1, 6, 45]` (=Thompson legacy); HEAD 4x / TORSO 1.5x / LIMB 0.6x;
  Player HP 100; Enemy HP 60-80.
- **Code says:**
  - Multipliers: `scripts/combat/hitzone.gd:17-20` → HEAD 4.0 (but overridden to **instant kill** at
    `enemy_base.gd:1466-1467`, "a headshot is a headshot"), TORSO **2.0**, **GUT 1.75 + bleed-out**
    (`enemy_base.gd:1489-1491`, a zone CLAUDE.md doesn't know exists), LIMB **0.75**.
  - Enemy HP: `data/enemies/*.tres` → 65-85 (`nva_regular.tres` max_hp=85, outside the documented band).
  - Player HP 100: correct (`scripts/player/health_system.gd:19`).
  - CLAUDE.md's own dice example is the legacy flat grammar the decree ordered killed.
- **Which is right:** the code (locational-damage decree item, commit 591a5a5, bead closed 96114f5).
- **Update:** rewrite the CLAUDE.md Damage System block from the shipping code.

### A4. Damage-grammar unification: closed as done, ~80% true
- **Decree wound #5:** unify on RECON dice, default M16, kill dead .tres.
- **Verified done:** default primary is M16 (`weapon_holder.gd:135`), default secondary M1911 (`:136`).
  All Vietnam-era weapons are RECON dice (m16a1/car15/m60 5d10, ak47/sks/rpd 4d10, ppsh 3d10, m79 8d10...).
- **Not done:** four WW2/HoD-legacy .tres still ship with flat-modifier grammar: `thompson.tres` [1,6,45],
  `mp40.tres` [1,6,38], `kar98k.tres` [1,10,70], `mosin.tres` [1,10,68]. Referenced only by
  `scripts/weapons/viewmodel_editor.gd:73-88` and `scripts/levels/combat_lab.gd` (dev range) — plus
  `data/enemies/vc_rifleman.tres` (a VC with a Mosin is historically defensible).
- **Update:** decide per-weapon: convert to dice (mosin/kar98k as VC hand-me-downs are legitimate Vietnam
  content) or delete. Don't leave two grammars where a WeaponData consumer can meet either.

### A5. Fire-support bug cluster: VERIFIED GENUINELY FIXED (adversarial pass)
- Danger-close confirm reachable: `mission_director.gd:225-256` — the net stays open through soft failures;
  pend is **kind-bound + 5s expiry** (`:220-222, :248-249`); opening/closing the net clears stale pends
  (`:171`). Closes only on dispatch (`:257`).
- RTO leash: `_radio_check()` (`:324-331`, alive + 10m) gates menu open (`:176`), every
  `request_fire_support` (`:229` — Y-mortar shortcut at `:204-205` routes through it), and
  `request_supply_drop` (`:393`).
- Key-6 double-bind: both `cbu_strike` and `place_claymore` remain physical 54 (`project.godot:131,176`) but
  the claymore is guarded by `not MissionDirector.any_fire_menu_open` (`player.gd:620-623`, tagged
  "[audit fix: key-6 double-bind]"). One press can no longer do both.
- Commit e4baf23 matches its message. **This is what a closed decree item is supposed to look like** — and it
  is the standard o18o failed to meet.

### A6. CLAUDE.md architecture claims — verified TRUE (no drift; say so)
- **Timestep capping:** real — `player.gd:583`, `enemy_base.gd:380`, `ally_base.gd:218`,
  `weapon_holder.gd:151` all use `minf(delta, 0.066)`.
- **THINK_INTERVAL 0.15 / separate think-execute:** real in both AI bases (`enemy_base.gd:37`,
  `ally_base.gd:27`), with an LOD interval variant (`enemy_base.gd:41,60`).
- **Physics layers table:** matches `project.godot:266-275` exactly (1-7 + 9; 8 unnamed in both).
- **Player scene contract:** Head Y=1.7, Camera fov=75, WeaponHolder identity transform —
  `scenes/player/player.tscn:22-30` all hold.

### A7. Viewmodel pipeline grammar changed under the law
- **CLAUDE.md:204-216 says:** root scale ~0.03, positions tuned in .tres, Thompson as the worked example.
- **Code says:** the fp_arms pipeline (commit 6e2fc3d, 627421e) ships `*_arms_viewmodel.tscn` with
  `viewmodel_scale = 1.0` and near-zero `hip_position` (m16a1.tres: `0,0,0`); the pose now lives in the arms
  rig (`scenes/weapons/m16a1_arms_viewmodel.tscn:8` — Model transform bakes a -1.81 Y offset) with
  GAME_SCALE_STANDARD.md as the canonical scale doc. Rule 3 ("positions in .tres, not scene transforms") is
  now only vestigially true.
- **Update:** rewrite "Adding New Weapons" for the arms pipeline; fold in GAME_SCALE_STANDARD contracts.

### A8. CLAUDE.md line 3 still sells the dead renderer
- "8-directional billboard sprite characters (CULTIC-style)" — the prior decree KILLED the sprite matrix;
  3D models are the default renderer (commit c67818a), sprites survive only as far-LOD/no-model fallback
  (`enemy_base.gd:182-184`). `SPRITE_INTEGRATION_PLAN.md` still sits in root as if live.

### A9. Perf decree item skipped, not slipped
- Decree wound #3 ordered "one measured perf-spike day **before any M6 work**"; bead 8pbo (19-25 FPS,
  measured) is OPEN. `project.godot:[rendering]` (`:277-280`) still never sets `rendering_method`
  (Forward+ default on Intel UHD — the decree's own prime suspect). The only rendering change since is
  `scaling_3d/scale=0.77`. Meanwhile ~30 commits of features landed. This violates both the decree ordering
  and the Summoner's standing "perf first always" directive.

### A10. Dead RTS tonnage, one dead AUTOLOAD booting every launch
- `data/vietnam/game_enums.gd` — **722 lines, registered as autoload `GameEnums`** (`project.godot`),
  referenced by **zero** code (only a comment in `scripts/visuals/sprite_library.gd:4` mentioning it).
- `data/vietnam/vietnam_weapon_data.gd` (994) + `vietnam_unit_data.gd` (420) — reference only each other.
- Total: ~2,136 lines of RealVietnamRTS import with no callers. CLAUDE.md's own origins note says RTS assets
  get copied "as needed" — these were copied and never needed.
- Plus: `tmp_prop_check.gd.uid` orphaned in project root (its .gd is deleted); two enum grammars
  (`scripts/autoload/enums.gd` class_name `Enums` — alive, still headed "Hell of Duty"; `GameEnums` — dead).
- **Update:** deregister GameEnums, delete all three files + the orphan .uid, retitle enums.gd.

### A11. CombatManager's "broken path" still lives alongside its replacement
- `mission_director.gd:1-3` header: kill counting works "never CombatManager's broken path" — yet
  `combat_manager.gd:87-88` still emits `entity_killed` + `GameManager.on_enemy_killed()`. Two kill-count
  grammars coexist; one is documented-broken and still wired. A future contributor will subscribe to the
  wrong one.

### A12. The campaign-loop overhaul is entirely unratified law living in code
SaveManager tiers (REGULAR/HARD/IRONMAN derived from existing settings, `save_manager.gd:6-9,72-77`),
slot map 0-9 (`:12-15`), the firebase-hub loop (`game_flow.gd:242-364`), deterministic wheels-down
checkpoints (`game_flow.gd:110-114,296-301`), global-RNG per-mission seeding with an honest scope statement
(`game_flow.gd:95-107`), survival v1 economics (hunger 45-min drain that saps stamina not health,
`player.gd:63-66,313-326`; weapon condition → jam chance, `weapon_holder.gd:299-308`; free hub refit,
`game_flow.gd:354-361`). None of this passed a council; all of it is load-bearing. Most of it is *good* —
it needs ratification, not reversal.

### A13. Wave-number archaeology is the project's real decision log
Load-bearing decisions are tagged in comments as W05/W13/W22/W25/W32/W40/W42/W46/W63/W67/W75/W80/W84,
NS07/NS18/NS21, R12/R13, PT — keyed to four roadmap docs (ROADMAP, ROADMAP_NEXT, ROADMAP_WAVE2,
WAVE3_REPORT) plus root-level reports (CODE_AUDIT, COUNCIL_REVIEW, NIGHTSHIFT_REPORT, AUDIT_HANDOFF).
The code is honest about its history; the docs are not consolidated anywhere. This is the sprawl the
GAME GUIDE deliverable must absorb.

### A14. Minor doc/code deltas (one-liners)
- CLAUDE.md header "Godot 4.5+/4.6" — project is 4.6; typing rules say "Godot 4.5" (`CLAUDE.md:60`).
- `mission_scope.gd:22-23` comment cites "game_flow.gd:172" for session-counter reset; it's now
  `game_flow.gd:201-202` (stale line ref — the comment-vs-code drift in miniature).
- CLAUDE.md Key Classes lists `Hurtbox`/`Hitbox` — no such scripts exist in `scripts/combat/` (Hitzone does).

---

## (b) TOP 5 STRENGTHS (code truth)

1. **Strict-typing compliance is near-perfect across all 90 files** — 0 banned `:= min/max/lerp/clamp`
   patterns project-wide; exactly 3 untyped `var x =` declarations (`enemy_base.gd:1722`,
   `enemy_squad.gd:68`, `health_system.gd:50`); 0 untyped function signatures found. The fast 36h campaign
   code obeys the law as well as the old code. Rare.
2. **MissionScope (`scripts/main/mission_scope.gd`) is exemplary engineering** — a single documented,
   probe-proven registry of every static/autoload leak across mission boundaries, each entry citing the probe
   that proved it. This should be canonized as the mandatory pattern for any new static.
3. **The fire-support net** (`mission_director.gd:210-331`) — kind-bound expiring danger-close pend, one
   leash function gating every entry point, diegetic radio VO sourcing. Post-fix, this is the best-guarded
   input surface in the game.
4. **SaveManager architecture** (`save_manager.gd`) — Catacombs-proven: schema versioning + sequential
   migration blocks (`:267-272`), deferred-apply of player state into a live world (`:174-223`), tier logic
   derived from existing settings instead of new knobs, exit-autosave that can never block quit (`:39-44`).
5. **Test/probe culture** — 34 headless test scenes + `run_all_tests.ps1` + a permanent end-to-end
   `test_hub_loop` (commit 8444795); beads carry measured refutations (8pbo's FPS-decay hypothesis killed by
   data). The instinct exists; it just wasn't applied to o18o.

## (c) TOP 5 WEAKNESSES / RISKS (ranked)

1. **A decree item was recorded as executed without being executed (o18o).** The briefing itself lists it
   under "executed"; the bead is open; the code is unguarded; a comment claims otherwise. This is a process
   wound bigger than the bug: closure without verification means the council's memory can't be trusted.
2. **CLAUDE.md is no longer safe to hand to an agent.** FOV law (A2), damage block (A3), renderer (A8),
   weapon recipe (A7) are all wrong. Any fresh session "following the law" will fight the shipping game —
   e.g., dutifully removing the ADS zoom the Summoner wants. Stale law is worse than no law.
3. **Stringly-typed coupling through the new campaign spine.** `save_manager.gd` reads/writes the player by
   `get("...")/set("...")` names (`:124-146,197-223`); `game_flow.gd` mixes safe `.get()` with crashy
   dot-access on Dictionaries (`offer.world_seed` `:151`, `plan.insertion_lz` `:170`, `plan.codename` `:206`);
   concrete null-crash: `save_manager.gd:139-140` — `(wh.get("primary_ammo") as Array).duplicate()` hard-crashes
   the save path if the property is ever null/renamed; `game_flow.gd:154-157` awaits `is_world_ready` forever
   with no timeout if world init stalls. A hostile playtest with a hand-edited or version-skewed save will
   find these.
4. **The perf decree was skipped while feature mass grew** (A9): 19-25 FPS measured, `rendering_method`
   still unset, 8pbo open — and gunplay (Pillar 1) is gated behind it. Every new system lands on a renderer
   nobody has profiled at the decreed depth.
5. **EnemyBase is a 1,737-line god object** carrying perception, alert tiers, the global detection beacon
   (a static on an entity class), goals, locomotion, damage, surrender, cover claims, and visual dispatch.
   The o18o fix is hard to see precisely because acquisition, alarm, and damage share one file. Autoloads
   themselves are healthy (largest: TerrainEngine 734, AudioManager 392, DamageSystem 321, CombatManager 318,
   SaveManager 297, ClearingSystem 297, CampaignState 251, VOManager 115, GameManager 87, GameSettings 70,
   NoiseBus 30 — plus dead GameEnums 722); the god lives outside the autoload list.

## (d) PILLAR SCORECARD (lead-programmer lens)

| Pillar | Score | One line |
|---|---|---|
| 1. Outstanding gunplay | **3.5** | Dice grammar unified on live weapons, rich recoil/condition/jam model — but 19-25 FPS (8pbo open) caps feel, and the ADS/iron-sights decision is half-landed in code, half in an open bead. |
| 2. Atmosphere | **3.5** | VOManager is real, clean, and diegetically sourced (the decree's ONE BUILD genuinely shipped); ambience beds exist; jungle density/wind remain unbuilt (playtest R2). |
| 3. Freedom | **3.0** | Escalation-on-detection architecture is coded and elegant — and voided at the last line by o18o: a ghost kill still trips "YOU'VE BEEN MADE". |
| 4. Squad is the RPG | **4.0** | Learn-by-doing is wired end-to-end in code truth: kills credit the shooter (`enemy_base.gd:1547-1559`), fire missions credit the RTO (`mission_director.gd:293-298`), roster persists through saves. |
| 5. Fail forward | **3.5** | Save tiers, wheels-down checkpoints, emergency-exfil abort, iron-man wipe all real; player death is still mission-restart, capture unbuilt. |

## (e) THE ONE THING TO BUILD/FIX NEXT

**Actually implement o18o (witness-gated contact stamping) and close it with a probe — then adopt the rule
that closed it.** The fix: in `take_damage()` (`enemy_base.gd:1462+`), when the hit is lethal, stamp the
beacon only if another living enemy witnessed it (LOS/proximity check, or route through the existing
NoiseBus — an unsuppressed shot already emits noise that alerts neighbors legitimately); non-lethal hits
stamp as today (the victim himself is a witness). Ship it with `tests/test_stealth_witness.tscn`
(silent kill → `last_combat_contact_ms` unchanged; witnessed kill → stamped) and only then close the bead.
Why this over perf: it's a P1, decree-promised, publicly recorded as done, one-line class of change,
reactivates an entire pillar economy (ghost play, threat cooling, silent_movement value) — and closing it
*with proof* establishes the verification law that prevents the next o18o.

## (f) ADR CANDIDATES (decisions living only in code/commits/beads)

1. **ADS zoom & true iron sights** — per-weapon `ads_fov` supersedes the FOV-75 lock; binocs at 18; the
   two-writer camera.fov truce. (weapon_holder.gd:215-220, player.gd:110-118, bead 2spa.) Requires CLAUDE.md
   amendment.
2. **Locational damage grammar** — HEAD is fatal (no dice save), TORSO 2.0, GUT 1.75 + bleed-out/crawl,
   LIMB 0.75 + cripple chance; supersedes the 4x/1.5x/0.6x table. (hitzone.gd:17-20, enemy_base.gd:1466-1494.)
3. **RECON dice as the single damage grammar** — `[count, sides, mod]` d10-based; legacy flat .tres are
   dev-range-only or deleted; M16A1/M1911 default loadout. (data/weapons/*.tres, weapon_holder.gd:135-136.)
4. **Detection-beacon escalation** — escalation triggers on DETECTION (any enemy reaching COMBAT tier,
   polled via `EnemyBase.last_combat_contact_ms`), never on the kill itself; finite hunter pool; witness rule
   (pending o18o). (enemy_base.gd:189-192,625-641; mission_director.gd:47-101.)
5. **Save-tier architecture** — IRONMAN/HARD/REGULAR derived from existing settings, slot map (0 quick,
   1-7 manual, 8 autosave, 9 exit), deferred-apply pattern, sequential schema migration. (save_manager.gd.)
6. **The firebase-hub campaign spine** — operation seed = hub world seed; TOC briefing → bird → mission →
   debrief → hub; deterministic wheels-down checkpoint = offer + carried state. (game_flow.gd:242-364.)
7. **Per-mission global-RNG seeding determinism contract** — same seed = same world/enemies/events, NOT same
   bullet holes; the honest-scope statement should be law. (game_flow.gd:95-107.)
8. **MissionScope static-reset registry** — any new static or autoload mutable state MUST register a reset
   in MissionScope.reset(), proven by probe. (mission_scope.gd.)
9. **3D models as default renderer; sprites demoted to far-LOD/no-model fallback.** (commit c67818a,
   enemy_base.gd:182-184; retires CLAUDE.md line 3 and SPRITE_INTEGRATION_PLAN.md.)
10. **Two singleton grammars** — autoloads (12, listed in project.godot) vs class_name statics
    (MissionDirector.any_fire_menu_open, WeaponHolder.session_*, GameFlow via group lookup); when each is
    permitted, and the MissionScope obligation that statics incur.
11. **Survival v1 economics** — hunger drains over ~45 field-minutes and saps stamina (never health);
    rations/repair kits; weapon condition drives jam chance; the firebase refits hunger+condition free.
    (player.gd:63-66,313-337; weapon_holder.gd:299-308; game_flow.gd:354-361.)
12. **The RTO radio ritual** — living RTO within 10m gates ALL fire support and resupply; handset-up means
    rifle down; danger-close requires a kind-bound double-press within 5s. (mission_director.gd:210-331,
    weapon_holder.gd:193-198.)
13. **Verification law (proposed, from A1/A5):** no decree item or P1 bead closes without a headless
    probe/test or a cited measurement proving the behavior. e4baf23 met this bar; o18o's recording did not.
