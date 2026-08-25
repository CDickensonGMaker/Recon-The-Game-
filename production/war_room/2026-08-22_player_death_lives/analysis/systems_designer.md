# Systems Designer — body-swap respawn & the lives economy (2026-08-22)

## 1. The cheapest honest body-swap, and what it costs

Every death already funnels through ONE choke point: `health_system.gd:283-287 force_death()` — both
bleed-out (`_die()` :272-279 after the medic window fails) and instant headshot (:219-223, which
deliberately bypasses `_die`). That is the entire interception surface. A swap handler sits inside
`force_death()` before `GameManager.on_player_death()` (`game_manager.gd:53-57`): if the pool holds a
man, swap; else fall through to the existing KIA chain (`field_director.gd:219-220 _on_player_died →
fail_mission("KIA")`).

The swap itself is cheap because we move the PLAYER NODE, not replace it:
- **Position/camera**: teleport `player` to the target ally, free the target NPC. Squad wiring
  (F1-F4, medic chain via `revive_handler`, `squad_system.gd:121-125`), RTO leash, rank/reputation
  (ADR-032 — bound to "you", not the body) all survive untouched. Command authority is a non-problem
  mechanically; it is a FICTION problem (a PVT garrison man barking at the squad), and ADR-032's
  disembodied rank already answers it.
- **Loadout**: `player.gd:756-762 give_weapon() → equip_captured_weapon` already swaps the FP
  viewmodel from a bare path. Missing: a full `EquipmentManager` reset (grenades/claymore/slots) —
  small, but it does not exist today.
- **The corpse**: the player has no third-person body; a corpse prop must spawn at the death site so
  the ledger claim is honest. `GarrisonDefender.promote` (`field_director.gd:1612-1636`) proves
  garrison men are real `AllyBase` soldiers who already die with bodies — spawn one dead.
- **Guard rails**: swap must NOT consume the downed/medic layer (`health_system.gd:272-277`) — a life
  is burned only at `force_death`. Headshot-straight-to-swap preserves the headshot law for free.

**Effort**: demo version 1-2 sessions. Campaign-grade (roster identity adoption from
`squad_roster.gd:95-111`, save serialization, debrief lines, tier gating): +3-4 sessions, post-EA.

## 2. Ticket counter vs roster-as-pool

**Roster-as-pool wins.** A "life" = a living, un-downed allied man in the mission. It is more
legible (the end card already lists named men KIA/HELD, `demo_game.gd:568-575`), it needs no new
currency, and it interacts CORRECTLY with everything:
- **The costless-loss problem** (GAME_GUIDE:191-195): free rookie refills (`squad_roster.gd
  ensure_roster` :166+) make an abstract campaign counter of ~40 meaningless — it refills or it
  contradicts fail-forward. Roster-as-pool makes squad deaths finally COST something inside the
  mission: every man who dies is a life you can no longer spend. ADR-018's veterancy debt starts
  getting paid.
- **Pillar 5**: a campaign-wide 40-ticket "game over" is a fail-state, which Pillar 5 forbids.
  Per-mission pool exhaustion = mission failed = existing fail-forward debrief
  (`game_flow.gd:457-486`). IRONMAN already archives the campaign on KIA (:469-471) — with the pool,
  that fires only when you die with no living man left, which is exactly the ironman promise.
- **Save tiers** (`save_manager.gd:25,80-85`): REGULAR F5/F9 dodges ANY economy — accept it; the
  economy binds on HARD/IRONMAN and in the demo (no F5, only RESTART THE NIGHT,
  `demo_game.gd:594-596`). Same posture permadeath already takes.
- **Medical ledger**: downed/wounded men are not spendable; the pool is conscious men. The swapped-out
  corpse enters the ledger like any KIA (casualty cursor already moves at `game_manager.gd:56`).

He is right about fairness FOR THE DEMO: HLL lethality + 20-minute siege + no saves means one RPG at
minute 18 deletes the run. A pool converts that variance into an economy. His "~3" as extra lives
BEYOND the garrison feels arbitrary; "3 swaps, then the card" is fine for the demo, but the campaign
answer should be men-in-reach, not a number.

## 3. Demo scoping

Minimum honest demo version: on `force_death`, swap into the nearest living `GarrisonDefender`
(they exist from `_garrison_stand_to`, `field_director.gd:1612-1636`), decrement a 3-swap counter,
spawn corpse, toast the new name; counter or garrison exhausted → `_on_demo_death` end card
(`demo_game.gd:547-550`). Reusable for campaign: the `force_death` interception, swap routine,
corpse spawn (~80%). Demo-only throwaway: the 3-counter, HUD pip, card text. Restart-day is safe —
`reload_current_scene` resets the counter with the scene.

## 4. Edge cases
- **No ally in range**: pool is mission-wide; range only picks where you wake. None alive anywhere →
  sole survivor → real KIA, exactly today's chain. Preserves lethality doctrine on lone patrols.
- **Die during end card**: `_show_end_card` already guards `_card != null` (`demo_game.gd:557,543`);
  swap handler must also check it.
- **Bleed-out vs headshot**: both reach `force_death` — one seam, no divergence.

## 5. Tradeoffs (named)
Sacrificed: per-death sting — "death from situation" softens when death is a body hop; mitigate by
making the wake-up ugly (new name, ledger line, your old rifle on your old corpse). Strained: Pillar
4's "you are IN it" identity fiction. Bought: the demo becomes survivable-but-fair, squad/garrison
deaths finally cost, IRONMAN gets a coherent final-death definition.

## 6. Scope classification (EA ~19 days; EA ships the demo's shape, ruling 2026-08-06)
- **Demo-scope (= EA by that ruling, if the Summoner pulls it in)**: garrison body-swap + 3-swap
  counter + exhaustion end card. 1-2 sessions.
- **EA-scope only if demo lands early**: corpse-with-your-rifle pickup, swap toast polish.
- **Post-EA**: campaign roster-as-pool, identity adoption (face/name/skills from the roster record),
  tier gating, debrief integration, any campaign-wide ticket idea (recommend never).

**Recommendation**: build garrison body-swap behind `force_death` with a 3-swap demo counter;
adopt roster-as-pool per-mission for the campaign; reject the abstract 40-life campaign counter.
