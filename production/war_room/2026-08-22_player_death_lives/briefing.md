# BRIEFING — Player death, respawn-as-another-man, and a lives economy (2026-08-22)

## The Summoner's words (verbatim)
"well than when i die we need to respawn me as someone else and thats where we need to
maybe work on the game loop idea different. i think the game Easy Red 1 & 2 does this
idea right where you have maybe 40 lives and when those are up the games over. otherwise
i dont really know how to keep the demo and even the game balance fair. like maybe the
demo should be 3 lives or something. lets talk about it"

Context of the ask: he was told the siege replay (demo, `scenes/levels/demo_game.tscn`)
is his next run; he is thinking about what happens when he dies during it. This is a
TALK session — an options board for his rulings, not a decree.

## Ground truth (probed 2026-08-22, cite-checked)
- Player death path: `health_system.gd:283-287 force_death()` → `GameManager.on_player_death()`
  (`game_manager.gd:54-57`, emits `player_died`, casualty cursor) → `field_director.gd:219-220
  _on_player_died() → fail_mission("KIA")` → debrief. In flow-managed play there is NO restart
  UI (`hud.gd:326-335` — "GameFlow routes death to the debrief (fail-forward)").
- There is NO respawn mechanic anywhere. Demo death → end card / RESTART DAY reboot.
- Squad: permadeath + instant free replacements; "Loss is still costless — the debt ADR-018's
  silent veterancy exists to pay" (GAME_GUIDE.md:191-195). Roster carries
  name/MOS/stats/skills/xp/kills/missions/alive/face/helmet (`squad_roster.gd:95-111`).
- Player identity: hidden reputation → REAL-RANK titles PVT→SSG gating the armory + fire
  support (ADR-032, ADR-018). Rank is bound to "you", not to any mortal body.
- Save tiers (ADR-007, GAME_GUIDE §4.7): REGULAR (F5/F9 anywhere) / HARD (hub-only) /
  IRONMAN (one slot). Mission results commit all-or-nothing at exfil, fail-forward ratified.
- Lethality canon: HLL lethality, FEAR doctrine both sides, "i dont really feel like im in
  danger" is the acceptance test. Death from situation, never bullet sponges (Pillar 1).
- Casualty ledger is the scoreboard: medical tent fills from real wounded, body bags stack
  (ruled 7/30). Garrison men are real soldiers, hot cap 50.
- Demo: 512m firebase holdout, ~20 min day→night siege→dawn end card with named roster.
- Pillars 4 & 5: "named persistent men who... die for real"; "fail forward... a dead mission
  seeds the next; never reload-and-memorize". Freedom pillar: no rails ever.

## The reference he named
Easy Red 1 & 2: on death you instantly take over another soldier of your side near the
front; the battle continues seamlessly; a finite reinforcement/ticket pool is shared by
the whole side; pool empty = defeat. Death is cheap per-man, expensive per-battle.

## Questions before the council
1. Respawn identity: when the player dies, does he BECOME another named man (squad mate,
   garrison man, replacement cherry)? What happens to rank/reputation/loadout/nickname?
2. The lives economy: what IS a "life"? An abstract counter (Easy Red's ~40)? The literal
   roster (the garrison/squad is the pool — when the men are gone, you are out of lives)?
   Per-mission vs per-campaign? How does it interact with save tiers (REGULAR F5/F9 can
   dodge any economy) and with fail-forward all-or-nothing exfil commits?
3. The demo: what should death in the siege demo do? (His instinct: ~3 lives.) The siege
   already has a named garrison and an end card — is body-swap into a defender the demo answer?
4. Balance/fairness: he says without a lives cap he cannot keep demo or game balance fair
   given HLL lethality. Is he right? What does the cap protect, what does it break?
5. Scope: EA is ~19 days out; nothing pulls from the EA ship list. What is the minimum
   honest version, and what is post-EA?

## Constraints (Law)
No pillar may be violated. Tradeoffs must be named. Cite file:line for claims about code.
Write your full analysis to this folder's analysis/<role>.md; return only a short verdict.
