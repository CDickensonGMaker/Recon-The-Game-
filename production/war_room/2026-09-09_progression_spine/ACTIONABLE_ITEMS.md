# ACTIONABLE ITEMS — for the coordinator to sequence into the tracking docs
## War Room 2026-09-09, THE PROGRESSION SPINE

**Nothing here was written into `CALEB_TODO_7_22_updated.md` or `GAME_GUIDE.md` — a second council was
live in those files.** This list is merge-ready. **Everything in group C is POST-DEMO and must not enter
any pre-launch queue.**

---

## GROUP A — DRIFT CORRECTIONS (small, and they cost nothing to make)

| # | Correction | File |
|---|---|---|
| A1 | **`_bank_patrol()` is at `field_director.gd:2053`, not `:1797`.** The repo `CLAUDE.md` cites `:1797` in the PLAYTEST R4 paragraph — **and its own text calls a stale CLAUDE.md "a DRIFT GENERATOR."** | repo `CLAUDE.md` (+ several docs) |
| A2 | **ADR-011 is 35 days stale.** His 2026-08-05 ruling made *any* radioman the net; the ADR still says the squad's RTO. Also: *"budgets rolled at briefing"* is dead prose — `_grant_fire_support()` allots once per sim day (`field_director.gd:1488-1494`). | `production/adr/ADR-011-fire-support-ladder.md` |
| A3 | **`field_director.gd:791-793` claims behaviour no probe proved** — it says borrowing a *firebase* radioman's PRC-25 now works. It does not; nothing but `squad_system.gd:236` joins the group. | comment only |
| A4 | **`GAME_GUIDE:181` says "5-man persistent fireteam"; the code says 8** in four places. | `GAME_GUIDE.md` |
| A5 | **`GAME_GUIDE:304` says the game has neither suppression nor morale**, and requires any divergence to be named in an ADR. Both are live, wired and probe-covered. **No such ADR exists.** | `GAME_GUIDE.md` + a new ADR owed |
| A6 | **`project.godot:250-254` — input action `radio` (key G), zero references.** ADR-023 fossil. Wire it or delete it. | `project.godot` |
| A7 | **ADR-024 does not exist as a file** — only a `(DRAFT)` row at `GAME_GUIDE.md:535`. | `production/adr/` |
| A8 | **`WorldSim.current_ao` is never set true**, so `count_live()` returns 0 forever — **and `tests/test_world_alive.gd:334` and `:374` print it as a measurement.** A broken instrument. | `world_sim.gd:18`, the test |
| A9 | **ADR-025 is SUPERSEDED (2026-07-20), not DRAFT.** *This session's own briefing carried the error and it is corrected here.* | this council's record; `GAME_GUIDE` ADR index |
| A10 | Stale comments: `dynamic_mission_factory.gd:1` (WorldSim has no transitions) · `mission_generator.gd:224` (no region grid, no LOD) · `squad_system.gd:22` ("village assault", retired by ADR-029) · **`player.gd:470` ships a live `print("[NETDBG]…")` on the net path.** | as listed |
| A11 | **No tour/rotation clock exists anywhere in `scripts/`** while Pillar 4 promises men who rotate home. A standing debt, not new work. | note only |

---

## GROUP B — RELAY TO OTHER LIVE COUNCILS (do not edit their files)

| # | To | Item |
|---|---|---|
| B1 | **firebase-kit council** | **Their own briefing cites `scripts/systems/tree_break_system.gd` and `scripts/systems/damage_system.gd` (`briefing.md:71-75`). There is no `scripts/systems/` directory** — the files are `scripts/world/tree_break_system.gd` and `terrain/systems/damage_system.gd`. **A live agent brief pointing at paths that do not exist.** |
| B2 | **firebase-kit council** | **The kit must carry a `radio_post` ANCHOR.** `site_planner.gd:1130, 1173` already map work markers `"radio"`/`"plot"` → occupation `"radioman"`. One named marker while the kit is authored; per-building retrofit later. |
| B3 | **firebase-kit council** | **Answer to their open question 3 (do markers ride on the parts): YES — and the reason is the second war, not the 488/23 mismatch.** `FSB_WORK_OCCUPATION`/`FSB_WORK_PRIORITY` are `const Dictionary` in `site_planner.gd:1170-1240`; **a WW1 trench kit cannot add `work_firestep`/`work_sap` without editing that file.** |
| B4 | **firebase-kit council** | **Correction to `FIREBASE_REWORK_INTENT.md:107`** (*"a WW1 battlefield is cut terrain plus trench modules and shell holes. Nothing else about it changes"*): **five things change** — the vegetation enum (`vegetation_manager.gd:6-13`, the climate literally IS the enum), the work vocabulary, the ambient-war frame (`ambient_war.gd:58-70` is anchored to the player, with no front or territory), enemy VO (`vo_manager.gd:16` — three Vietnamese folders, the only source), and the faction binary (`enemy_base.gd:305-312` — *"the id prefix IS the faction"*, `"vc"` or `"nva"`, no third branch). **Each cheap now, none free later.** |
| B5 | **firebase-kit council** | **Do NOT generalise the assembler.** `site_planner.gd` is 2,758 lines and majority firebase-specific; generalising it yields a placement engine that can express neither an FSB nor a trench line. **The KIT is the generalisation; the assembler stays specific per site type.** |
| B6 | **census agent (blast/VFX/ambient events)** | **Count radiomen as a first-class population**, and **add a SOURCE/owner field to `_mark_dispatch(kind, target, run_dir)` (`field_director.gd:459`)** — one argument now, a schema migration through every consumer later. |
| B7 | **census agent** | **Rule that world-element identity is SEED-DERIVED, not instance-id, before ids are handed out** (ADR-010). `pinned_holder` (`friendly_patrol_group.gd:19-29`) is the counter-example: an identity `MissionScope.reset()` must wipe, that can never be persisted. |

---

## GROUP C — POST-DEMO BUILD ITEMS (parked; do not queue before launch)

Full detail in `synthesis.md` §6. Dependency-ordered:

- **C0** Headless probe: stand up a `SquadSystem` with an **empty roster** and tick it. **It does not
  exist**, and the whole pivot rests on a reading of guards rather than an execution (ADR-015).
- **C0b — PROMOTED BY HIS 2026-09-09 RULING** (*"the main game… no squad mates… a new replacement"* +
  *"over time and completing missions you earn squad members"*). **`CampaignState.squad_authorised`,
  read by all four `SQUAD_SIZE` sites AND by `vacancies()` (`squad_roster.gd:206-211`).** Without it
  `heli_lift.gd:417` flies replacements in to top the player back to eight — **the main game would
  spend its entire length handing him the men he is supposed to earn.** Fixed, the same servo becomes
  the **reward channel**: the bird delivers a man when one has been earned. **This is the first thing
  the ruling breaks; it is no longer a later cleanup.**
- **C1** Suppression legibility (enemy chatter loses coordination then goes silent) + enemy-VO-as-contact-
  call. **`enemy_reload.wav` is recorded and imported in every `vi_*` set with zero callers.**
- **C2** The borrowed radio: an RTO in ambient elements · the wordless offer/refusal grammar · element
  budgets · refused-under-fire-unless-you-joined-the-fight · **a stolen set does not work** · unify the
  `fo_fac` authority.
- **C3** Fix the arrived-and-idle man **as constraints** (`defense_zone = order_pos`), promoting
  relocation out of `_execute_idle` exactly as RESCUE already was. **Gated by ADR-029 Amdt C §5's
  never-run playtest.**
- **C3b** Price the living world: ambient men at 0/8/24/48, **under the siege, never on quiet terrain**.
- **C4** The verb set + the confirmation trifecta (they ship together, never apart).
- **C5** Solo. **Depends on C1 and on save-anywhere.** Includes `CampaignState.squad_authorised` read by
  all four `SQUAD_SIZE` sites **and by `vacancies()`** — otherwise the replacement Huey keeps flying men
  in to top the player back up to eight.
- **C6** Companion (on `pilot_recovery.gd`'s bones) + the handheld as a posture.
- **C7** The story layer: journal · gutter barks · the sniper's four tiers · Gus's states · WW1 narration.

---

## GROUP D — HIS CALLS (8)

Listed verbatim in `synthesis.md` §5. The two that block the most downstream design:
**(1) does the player start the campaign with no men?** and **(2) is the opening squad given and taken
away?** — a lens voted against the whole pivot without (2).

---

## GROUP E — THE ONLY PART OF THIS THAT TOUCHES THE MODULAR WORLD KIT
### Four doors the kit work must not close. Nothing else in this decree is on the kit's path.

| # | Door | Why it is free now and expensive later |
|---|---|---|
| **E1** | **Work points travel WITH the models, not in a code table.** `FSB_WORK_OCCUPATION` / `FSB_WORK_PRIORITY` are `const Dictionary` in `site_planner.gd:1170-1240`. | A WW1 trench kit cannot add `work_firestep` / `work_sap` / `work_dugout_signals` without editing `site_planner.gd`. **This also answers the kit council's own open question 3 — yes, and the reason is the second war, not the 488/23 mismatch.** |
| **E2** | **One of those work points is `radio_post`.** `site_planner.gd:1130, 1173` already map `"radio"`/`"plot"` → occupation `"radioman"`. | One named marker while the kit is being authored; a per-building retrofit into a frozen kit later. It is where the whole borrowed-radio ladder eventually attaches. |
| **E3** | **NPC spawn by building COMBINATION must stay expressible.** The kit decides which men a place implies. | If spawn rules are baked per-building rather than per-combination, "a base with a TOC and a pad has a radioman" becomes unstateable. |
| **E4** | **The necklace is a PROP ATTACHMENT on the character, not a kit concern — but the attachment socket must exist.** A Blender agent is building the modular prop now. | The character export contract already names sockets (`MuzzlePoint/HandR/HandL/Head/Chest`). **A neck/chest attach point that other men can see at conversational distance is the only art dependency this decree creates.** Do not duplicate the Blender agent's work. |

**Nothing else here belongs anywhere near the demo or the kit.** Groups A (drift) and B (relays) are
free-standing; group C is post-demo build work; group D is his to rule.
