# ADR-007: Save architecture: tiers, slots, checkpoint economy
**Date:** 2026-07-10 · **Status:** Accepted (War Room audit #2) · **Supersedes/Amends:** Amends MISSION_DESIGN_RESEARCH.md §10.1 ("no quicksave"; same-seed resume deviates from its reroll guidance); supersedes the undocumented Phase A/D save behavior as the doc of record.

## Context
Phase A ported the Catacombs of Gore save architecture: versioned `SaveData` schema with per-field defaults and a sequential migration hook (`save_manager.gd:267-272`), corrupt-file guard (`save_manager.gd:159-171`), metadata-only slot browsing (`save_manager.gd:252-262`), deferred apply so a loaded position never lands in a dead scene (`save_manager.gd:176-224`), and exit-autosave wrapped so a failed save can never block quit (`save_manager.gd:39-44`). The technical director's audit called it the best-engineered new system since audit #1. It shipped with three save tiers derived from existing settings with "no new knobs" (`save_manager.gd:6-9`, `tier()` at `:72-77`) — and that derivation is where the drift lives.

The tiers were never a decision of record. MISSION_DESIGN_RESEARCH.md §10.1 says "no quicksave, checkpoints at mission-graph nodes"; the shipped default (REGULAR) allows F5/F9 anywhere plus a 30-second in-mission autosave (`save_manager.gd:47-56, 59-69`), quietly repealing Pillar 5 for the default player. Meanwhile the checkboxes that select the stricter tiers do not say so: `settings_screen.gd:58` labels HARDCORE as "(no compass, no objective markers)" and `barracks.gd:28` labels IRON MAN as "(death archives the campaign)" — a player opting into "no compass" is silently opting into a different save contract, discovered only via the refusal toast at `save_manager.gd:65`.

The backbone is also faceless. The F5 "SAVED" toast routes through `director.toast` (`save_manager.gd:292-297`); only MissionHUD listens, and the hub has no MissionHUD, so hub saves are silent. F9 quickload has no feedback of any kind (`save_manager.gd:66-69`). The HARD-tier wheels-down checkpoint writes slot 5 with no acknowledgement (`game_flow.gd:112-114`). Two robustness gaps remain: `save_game()` writes the slot file directly with no temp+rename (`save_manager.gd:92-102`), so a crash mid-write — likely, given the 30s autosave — destroys the slot; and `load_game()` migrates only `version < SCHEMA_VERSION` (`save_manager.gd:165`), so a future-version save loads silently into an old build and gets destructively re-saved downgraded.

What is genuinely right, and was verified this audit: mission results commit all-or-nothing. `begin_mission()` defers all campaign writes to memory (`campaign_state.gd:21-27, 131-132`); the debrief commits them (`campaign_state.gd:137-138`); Alt-F4 at minute three no longer permanently kills Doc while the mission log never advances. Death spends the HARD checkpoint (`game_flow.gd:221`), and IRON MAN KIA archives the whole campaign (`game_flow.gd:222-225`).

## Decision
Three save tiers, derived from existing settings AND displayed to the player. The tier ladder is ratified; its invisibility is not.

- **REGULAR** (default): F5 quicksave / F9 quickload anywhere; 30s in-mission autosave; slots 0=quick, 1-7 manual, 8=autosave, 9=exit (`save_manager.gd:12-15`).
- **HARD** (`GameSettings.hardcore`): checkpoint saves only — wheels-down at mission launch (`game_flow.gd:112-114`) and objective completion. No field quicksave. Death spends the checkpoint (`game_flow.gd:221`). Checkpoint resume re-runs the SAME seed — a deliberate, named deviation from MISSION_DESIGN_RESEARCH §10 reroll guidance: the seed-deterministic world (`game_flow.gd:95-107`) makes offer + carried state a complete resume point, and we accept "same world, retry it" over reroll.
- **IRONMAN** (`CampaignState.iron_man`): one slot, no manual save. KIA archives the campaign (`game_flow.gd:222-225`).
- **Consent rule (binding):** the HARDCORE checkbox (`settings_screen.gd:58`) and IRON MAN checkbox (`barracks.gd:28`) MUST state their save-tier consequences in their label text. A checkbox may not silently rewrite the save contract.
- **All-or-nothing commit (ratified):** mid-mission campaign writes stay in memory until debrief commit (`campaign_state.gd:21-27, 131-138`). This stands as a fail-forward win; do not regress it.
- **Backbone ratified with two REQUIRED amendments:**
  1. Atomic writes: `save_game()` writes `save_N.sav.tmp` then renames over the slot; keep prior file as `.bak` (`save_manager.gd:92-102`).
  2. Future-version rejection: `load_game()` MUST refuse (not silently accept) saves with `version > SCHEMA_VERSION` (`save_manager.gd:165`).
- **Feedback rule (binding):** every save and every load produces visible feedback on every path, including the hub. Specifically: hub gets a toast surface for F5 (`save_manager.gd:292-297` currently falls through to `print`), F9 gets load confirmation/failure feedback, and the HARD wheels-down checkpoint announces itself.

Testable: a probe can assert (a) tier label visible in save UI/checkbox copy, (b) `.tmp`+rename observable in `user://saves/`, (c) version N+1 save rejected, (d) toast emission on hub F5.

## Consequences
**Buys:** the tier ladder becomes a real difficulty contract the player consented to, not a trap; Pillar 5 gets its substrate (checkpoint economy where death costs the checkpoint, mission results that cannot be scummed mid-run); the two total-loss failure modes (mid-write crash, version downgrade) are closed; the r4bk law ("a feature without a HUD affordance doesn't exist") is finally honored for saves.

**Costs (named — no free lunches):** REGULAR's quicksave-anywhere is a standing repeal of Pillar 5 at the default setting — we accept that the default player can scum inside a mission, and rely on the all-or-nothing commit plus the visible tier ladder to sell the stricter tiers. Same-seed HARD resume means a checkpointed player can learn enemy placements across retries — accepted over §10.1's reroll for determinism and resume simplicity. Checkbox copy gets longer and scarier; some players will bounce off HARDCORE once it tells the truth. Atomic writes add file-system churn per save (negligible).

**Work created:** amendments 1-2 and the feedback rule land inside decree item 3, the PLAYER-STATE HUD LAYER (bead fmc8 milestone 0: save/load feedback + pause menu). Checkbox copy fix rides the same item. PLAYER_MANUAL gains a save section under decree item 7 (LAW & LEDGER CLEANUP). Objective-completion checkpoints for HARD are new implementation work (only wheels-down exists today).

## Evidence
All citations verified against source 2026-07-10:
- `scripts/autoload/save_manager.gd:6-9, 72-77` — tier derivation (REGULAR/HARD/IRONMAN from existing settings)
- `scripts/autoload/save_manager.gd:12-15` — slot layout; `:47-56` autosave; `:59-69` F5/F9 handling (F9 silent); `:65` refusal toast
- `scripts/autoload/save_manager.gd:92-102` — non-atomic direct write (amendment 1)
- `scripts/autoload/save_manager.gd:165` — migrates only `< SCHEMA_VERSION`; no future-version rejection (amendment 2)
- `scripts/autoload/save_manager.gd:292-297` — toast routes via `director`; hub path falls through to `print`
- `scripts/ui/screens/settings_screen.gd:58` — HARDCORE checkbox text omits save-tier consequence
- `scripts/ui/screens/barracks.gd:28` — IRON MAN checkbox text omits save-tier consequence
- `scripts/main/game_flow.gd:95-114` — per-mission seeding + silent HARD wheels-down checkpoint (slot 5)
- `scripts/main/game_flow.gd:221-225` — checkpoint spent on mission resolve; IRON MAN KIA wipe
- `scripts/autoload/campaign_state.gd:21-27, 131-138` — deferred writes / all-or-nothing debrief commit (the decree's `:20-37` citation, corrected)
- Council record: `production/war_room/synthesis.md` (audit #2 decree, "RATIFY... save-tier ladder with UI-visible tier derivation (ADR-007)"); `analysis/technical_director.md` A7; `analysis/ux_designer.md` Drifts 5 & 7; `analysis/game_designer.md` A9

## Related
- ADR-008 (walkable firebase hub) — the hub is the HARD/IRONMAN save location and currently lacks the toast surface this ADR requires
- ADR-009 (hunger parked) — hunger fields stay in `SaveData.PlayerSection` (`save_manager.gd:128`) though drain is removed
- ADR-015 (mechanical process laws) — the verification law governs how this ADR's amendments close
- Beads: fmc8 (HUD layer / save feedback), r4bk (presentation law), ida9 (Playtest R3 gate)
- Pillars served: **5. Fail forward** (primary), **3. Freedom** (tier choice as informed consent)
