# SYSTEMS-DESIGNER — FULL-GAME SYSTEMS AUDIT
**Session:** 2026-08-04 full audit · **Dimension:** the full game's systems — deep-and-real vs scaffolded.
**Method:** code first, docs second (briefing law). Every claim carries a pointer or names the probe that would settle it.

---

## 1 · The open-patrol loop (ADR-029) — REAL, and it cycles

The patrol→bank→next-patrol cycle is genuinely closed in code, not scaffolded:

- **Walk-out:** `_poll_wire_gate()` fires at >120 m walking distance, increments `patrol_count`, opens the
  all-or-nothing campaign write window (`CampaignState.begin_mission()`), picks a living location, grants
  the day's fire-support allotment (`scripts/missions/field_director.gd:1214-1234`).
- **Walk-in:** re-crossing <95 m banks (`field_director.gd:1235-1237` → `_bank_patrol()` at `:1586-1610`):
  field marks bank, route report toasts, reputation banks with promotion toast, `CampaignState.on_mission_end`
  + `commit_mission()` land the deferred writes, then a **fresh `MissionState`** is built and
  `restore_field_marks()` re-seeds the intel layer — the gate is re-armed because `patrol_out` is false.
  Nothing blocks patrol N+1. The loop cycles by construction.
- The route-as-order system (ADR-035 route) is wired INTO the selector, not bolted on: a plan anchors the
  sweep to the living feature nearest the next mark (`field_director.gd:1506-1514`), and the AAR reports
  `PLANNED n, WALKED n` without scoring it (`:1569-1583`) — exactly the offered-not-required contract.
- Crisis outranks the standing ring (`:1495-1505`); the visited-ring resets when walked out (`:1538-1540`).
- Guard rails exist: `tests/test_patrol_aar.tscn` (death outside the wire → field AAR → wake at base),
  `tests/test_patrol_world.tscn`, `tests/test_patrol_contract.tscn`. (Whether the suite is green is the
  technical-director's dimension — red baseline since 7/27 per briefing.)

**The paper is behind the code.** ADR-029 is **still DRAFT** ("awaiting Summoner ratification",
`production/adr/ADR-029-open-patrol-simulator.md:3-4`) while its Amendment B is **RATIFIED** (2026-07-20)
and Amendment C **ACCEPTED** (2026-07-25). Two ratified amendments sit on an unratified base — the game's
entire shape rests on a draft. CLAUDE.md and the GAME_GUIDE §3 banner both describe the game AS ADR-029.
This is a one-decision fix, and it is the cheapest item on this whole board.

**Only one mission type exists.** `build_patrol_world` stamps `mission_type = "PATROL"`
(`scripts/missions/mission_generator.gd:780`) — per the ADR that is by design for the slice, but the
GAME_GUIDE's mission grammar (§3, "2–4 live objectives, exfil, debrief") describes a game that no longer
exists and is flagged "pending the Summoner's ratification call" (GAME_GUIDE §3 banner). The full game's
loop identity is decided in code and undecided on paper.

## 2 · Campaign & persistence — broad and real, with four measured defects

What genuinely persists, verified field-by-field in `scripts/autoload/campaign_state.gd:298-377`:
threat level + decaying modifiers, hidden reputation, roster (with skills/skill_uses/xp/face/helmet),
missions_played, trimmed mission log, intel (spendable + lifetime + stash threshold), **collapsed tunnels
as world memory** (`:479-492`, re-matched to the metre on regen), field/pencil/reported marks (three inks),
ears_taken, the butcher's bill (kia_total never decrements, ward saturates at 12 — `:56-71`), rack fouling
per weapon (`:469-475`), and depot_loss. This is a campaign that actually remembers, and the all-or-nothing
mid-mission deferral (`:19-27`, `begin_mission`/`commit_mission` `:285-295`) is the single best persistence
decision in the repo — Alt-F4 mid-patrol cannot bank a KIA without its consequences.

The defects, each verified at source:

1. **Non-atomic writes, both stores.** `SaveManager.save_game()` opens the slot file directly and writes
   (`scripts/autoload/save_manager.gd:103-108`); `CampaignState.save_campaign()` is a direct
   `cfg.save(save_path)` (`campaign_state.gd:325`). ADR-007's **REQUIRED amendment 1** (temp+rename+.bak,
   ADR-007 "Backbone ratified" §1) is still unimplemented. With a 30 s autosave (`save_manager.gd:22`),
   a crash mid-write destroys the slot.
2. **Future-version saves load silently.** `load_game()` migrates only `version < SCHEMA_VERSION`
   (`save_manager.gd:177-178`); a NEWER save loads into an old build and gets destructively re-saved
   downgraded — ADR-007 **REQUIRED amendment 2** unimplemented. Contrast: the campaign cfg DOES refuse
   (`campaign_state.gd:344-347`). One store honors the law, the other doesn't.
3. **The "two stores can never disagree" comment is false.** `to_dict()`'s header claims it "mirrors
   exactly what the cfg persists" (`campaign_state.gd:387-388`), but it omits `reported_marks`,
   `lifetime_intel`, `next_stash_at`, and `ears_taken`, all of which the cfg saves (`:316-319` vs
   `:389-408`; `from_dict` `:411-432` likewise). Loading a slot therefore keeps the CURRENT campaign's
   values for those four and then `SaveManager.apply()` immediately persists them into the loaded
   campaign's cfg (`save_manager.gd:193-194`) — cross-campaign bleed of the reported-intel layer and the
   stash clock. *Measurement:* save slot A, reset campaign, take ears/intel, load slot A, diff
   `user://campaign.cfg`.
4. **`reset_campaign()` does not clear `ward_wounded` to zero — deliberate** (seeded 2, ruled 2026-07-30,
   `:458-462`) — noted as correct, not a defect.

## 3 · Progression — three lanes, all real, one costless hole

- **Hidden reputation → level → rank** is complete and obeys the never-shown decree: quadratic curve
  capped at 40 (`campaign_state.gd:136-156`), tier titles PVT→SSG (`:136,159-169`), the ONLY bank point
  is `bank_reputation()` (`:174-177`) called from `_bank_patrol` (`field_director.gd:1594`), and the only
  tell is the promotion toast. No XP number surfaces anywhere I could find.
- **Armory tiers gate for real** — this contradicts the 7/31 synthesis's "rank gates nothing" line as
  written: `armorers_bench.gd:50` refuses any weapon with `armory_tier > title_tier()`, and seven .tres
  files carry non-zero tiers (car15/m14/shotgun=1, m60/m79=2, m70=3, m72_law=4 — `data/weapons/*.tres`).
  If "rank gates nothing" meant squad rank, that is true — `rank_for` is cosmetic address
  (`squad_roster.gd:206-209`, rank gates authority per ADR-018, and no authority mechanic reads it yet).
- **Learn-by-doing (allies only, ADR-018/032)** is live at five credit sites: `small_arms` on kills
  (`enemy_base.gd:2452`), `fo_fac` on fire calls (`field_director.gd:531`), `medic` on revives
  (`squad_system.gd:338`), `detect_ambush` twice (`:438,450`) — and it is READ: the RTO's `fo_fac` buys
  mortar/illum quantity (`field_director.gd:1259-1266`) and `roster_skill()` serves world-gen
  (`campaign_state.gd:183-188`). Skills persist through the roster save. This is a real, closed economy.
- **THE HOLE: squad loss is mechanically near-free.** `SquadRoster.ensure_roster()` drops the dead and
  back-fills every missing MOS slot with a freshly generated rookie, instantly and at no cost
  (`squad_roster.gd:165-203`), called at every squad spawn (`squad_system.gd:65`). The real costs are
  only: accumulated skills die with the man, and the butcher's bill counters tick
  (`campaign_state.gd:251-270`). No replacement delay, no under-strength patrol, no request-up-the-chain.
  Pillar 4 says men "die for real"; the campaign replaces them by the next walk-out like ammunition.

## 4 · Night economy & the sleep verb — producers without a consumer

- **SimClock is real and live**: autoload, ratio-driven, per-entry schedule dedup (the 7/31 dedup-key bug
  is FIXED — keyed `day-hour-entryindex`, `sim_clock.gd:93-98`), period signals consumed by camp schedules
  (`camp_director.gd:25`), civilian day-cycles (`civilian_schedules.gd`), garrison stand-to and the siege's
  per-night roll (`siege_director.gd:186`).
- **The sleep verb does not exist.** The only time-skip in the game is the dev-tool `[U]` cycle
  (`game_flow.gd:51,76,94`) and observation-room compressors (`observation_tools.gd:55-57`). The 68
  `prop_sleep` bunk markers in fsb_main_v3 are used solely as SPAWN points (`game_flow.gd:127-172`).
  A player who returns at dusk must either walk in circles all night at 60:1 or quit. The whole night
  economy — siege rolls per night, dawn stand-down, next-day fire-support allotment keyed to `_sim_day()`
  (`field_director.gd:1255-1258`) — is built and waiting for the one verb that lets a player traverse it.
  The memory's "sleep loop decree" (wake into siege) has its receiving systems built and its trigger absent.

## 5 · Hearts & minds — an ACCEPTED ADR with zero systems behind it

ADR-019 is **Accepted** (2026-07-12) and its economy is absent from code, verified by exhaustion:

- `allegiance` appears in exactly two comments repo-wide (`garrison_defender.gd:5`,
  `agent_registry.gd:12`) — no ledger, no variable, no store. The district manpower pool does not exist.
- **What DOES exist and is real:** the informer path — a rolled informer per village
  (`mission_generator.gd:1010-1016`), a 25 s inform clock after seeing the player
  (`civilian.gd:297-307`), escape → `on_informer_escaped` spawns a 4-man response from the far side
  (`field_director.gd:639-658`, one answer per patrol via `_informer_answered`). This is the single
  live H&M mechanic in the game.
- **The attach point is deliberately built and deliberately empty:** civilians are killable with NO
  consequence — `_record_noncombatant_death()` is "the single hook a future ROE/war-crime ledger
  attaches to; it is called on every noncombatant death and is intentionally empty" (`civilian.gd:4-7`).
  `fail_mission` names civilian deaths in the AAR but `compute_score` never reads the key
  (`field_director.gd:194-197`). Burning the village down the road costs nothing, contradicting the
  Summoner's founding sentence for ADR-019.
- `ears_taken` is counted with bark buckets (`player.gd:236-238`) and NOTHING in the world reads it —
  the "the world is allowed to have an opinion" clause (`campaign_state.gd:78-80`) is an IOU.

This is the widest gap between paper status (Accepted) and code (absent) in the entire canon.

## 6 · Siege stakes (ADR-035/036) — a real fight with a comment where its consequences should be

- **The fight is deep**: 776-line director, threat-tier nightly probability (`siege_director.gd:186`),
  run-carried strength (survivors field nights 2-3, wipe ends the run — `:735-738`), a real withdrawal/
  reap terminal state so routed men don't ghost the AO forever (`:744-771`), probe-vs-siege split,
  garrison stand-to/stand-down with permanent garrison dead (`field_director.gd:1481-1492`).
- **One stake is fully closed**: the satchel-at-the-bench depot breach — producer at
  `field_director.gd:1405-1415` (immediate mortar/arty loss + `CampaignState.depot_loss`), consumer at
  the NEXT walk-out's allotment (`:1283-1292`, consumed then cleared, with the honest toast). Persistent,
  not permanent, exactly as designed.
- **THE SCAFFOLD: the night's AAR is a comment, not code.** `field_director.gd:1466-1468` states: *"The
  night banks its own AAR. _bank_patrol only fires on crossing the wire inward, so a siege fought at home
  produced no butcher's bill at all."* The handler below it (`_on_siege_ended`, `:1469-1478`) toasts and
  stands the garrison down — **nothing banks.** The only two banking sites in the file are `fail_mission`
  (`:194`) and `_bank_patrol` (`:1591-1599`), both requiring the player to have crossed the wire. Ally KIA
  from a home-fought siege sit in `state.flags["squad_kia"]` until the player happens to take (and return
  from) a later patrol — or are lost with a fresh `MissionState` if he dies first. The comment describes
  the fix; the code still has the bug the comment says it fixed. *Measurement:* trigger a siege without
  ever leaving the wire, let an ally die, reach dawn, diff `user://campaign.cfg` — predicted: `kia_total`
  unchanged, no reputation delta.
- **ADR-036 is honestly BLOCKED** (header: nine dependencies missing) and the blocker is verified still
  true: the firebase is one baked GLB node (`site_planner.gd:904-925` returns `"nodes": [root]`). An
  overrun today emits a toast (`field_director.gd:1450-1452`) and changes nothing in the campaign; death
  always wakes you at the firebase (`game_flow.gd:668`) whether or not it was overrun an hour ago. A
  three-night siege, won or lost, alters: depot stock for one patrol, garrison headcount, and nothing else.

## 7 · The two-games boundary — clean

- No runtime code references RealVietnamRTS. All crossings are one-way, read-only ASSET imports in tools:
  `tools/extract_fsb_sources.py:5-27` (explicitly "READ-ONLY on RealVietnamRTS"),
  `tools/make_jungle_vegetation.py:35`; `collision_table.gd:3` cites RTS scene sizes as provenance only.
- Residual risk (small, named): both tool scripts hardcode absolute `C:\Users\caleb\RealVietnamRTS\...`
  paths — if that repo moves or is re-skinned to BP IP (per the standing two-games ruling), firebase-kit
  and vegetation REGENERATION breaks silently. No shipped-game exposure; a regen-time trap only.

---

## STRONGEST (full game, this lens)
1. **The open-patrol loop cycles for real** — gate → bank → fresh state → re-armed gate, with all-or-nothing
   campaign commits and the route system wired into the selector, not around it
   (`field_director.gd:1214-1237, 1586-1610`; `campaign_state.gd:285-295`).
2. **Campaign memory breadth** — collapsed tunnels, three ink layers, rack fouling, the never-healing
   butcher's bill, depot loss: the world verbs genuinely persist (`campaign_state.gd:298-377, 479-492`).
3. **Progression is three real lanes** — hidden rep→rank with a working armory gate
   (`armorers_bench.gd:50` + 7 tiered .tres), and a closed learn-by-doing economy with five credit sites
   and real readers (`field_director.gd:531,1259-1266`).

## WEAKEST (full game, this lens)
1. **Hearts & minds: Accepted on paper, absent in code** — no allegiance ledger anywhere; civilian murder
   is free by explicit empty hook (`civilian.gd:4-7`); only the informer path lives.
2. **The siege pays out in a comment** — no night AAR bank (`field_director.gd:1466-1478`), ADR-036
   blocked, overrun is a toast: the game's biggest set-piece changes ~nothing in the campaign.
3. **Night economy has no player-facing consumer** — no sleep verb; the only time-skip is a dev key
   (`game_flow.gd:51-94`); 68 bunks are spawn markers only.
4. **Persistence robustness** — non-atomic writes in both stores, silent future-version load, and the
   false "mirrors exactly" contract dropping four fields (`save_manager.gd:103-108,177`;
   `campaign_state.gd:387-408`).

## IMPROVE (ranked by value-per-effort)
1. **Bank the night** — make `_on_siege_ended` commit a siege AAR (squad_kia → butcher's bill, reputation,
   threat). Effort: small (the banking machinery exists 120 lines away). Value: the flagship set-piece
   finally writes to the campaign. *Sacrificed:* a subsequent patrol's AAR must not double-count the same
   flags — the ledger split is the actual work.
2. **ADR-007's two required amendments + the mirror fix** — temp+rename atomic writes, refuse
   `version > SCHEMA_VERSION`, add the four missing fields to `to_dict`/`from_dict`. Effort: tiny.
   Value: every other system's persistence stops being crash-lottery. *Sacrificed:* nothing real.
3. **The sleep verb** — interact at a bunk → SimClock skip with siege-roll interrupt (wake into the
   attack, per the standing decree). Effort: moderate (skip exists as dev code; the interrupt is the new
   part). Value: unlocks the entire built night economy + the sleep-loop decree. *Sacrificed:* skipped
   nights must still roll sieges/ambient or the skip becomes a safety exploit.
4. **Ratify (or formally amend) ADR-029** — a decision, not code. Effort: one session question. Value:
   the game's shape stops resting on a draft with ratified amendments hanging off it. *Sacrificed:* the
   GAME_GUIDE §3 mission grammar must be rewritten or explicitly parked — someone's cherished exfil/debrief
   text dies.
5. **Replacement cost for rookies** — dead MOS slot stays empty for the NEXT patrol (one-patrol
   requisition delay) before `ensure_roster` fills it. Effort: small (`squad_roster.gd:174-185`). Value:
   Pillar 4's "die for real" gains a mechanical tooth. *Sacrificed:* under-strength patrols can compound a
   losing streak — needs the fail-forward read, not a difficulty spiral.
6. **Minimal allegiance ledger** — one int per village, fed by the already-called empty hook
   (`_record_noncombatant_death`), informer outcomes, and ears; read by informer roll chance and siege
   probability. Effort: medium. Value: ADR-019 stops being fiction; burning the village finally costs.
   *Sacrificed:* tuning burden and the discipline to keep it UI-less (ADR-029's no-panel law).

## THE SCAFFOLD PRETENDING TO BE A SYSTEM
The **siege night's AAR**: `field_director.gd:1466-1468` asserts "The night banks its own AAR" — the
handler below (`:1469-1478`) banks nothing, and the file's only banking sites (`:194`, `:1591-1599`)
require crossing the wire. A siege fought at home still produces no butcher's bill, which is the exact
defect the comment claims was fixed. Runner-up: ADR-019 Hearts & Minds — Accepted 2026-07-12, and
`allegiance` exists in this codebase only inside two comments.
