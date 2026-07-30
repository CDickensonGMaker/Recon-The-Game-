# BRIEFING — 2026-07-29 demo playtest: collision, garrison, and the fight that never happened

## The Summoner's report, verbatim intent

> Two layers of collision on the firebase. A lot of my allies were stuck in the spawn. The
> friendly NPCs that spawn in have white helmets and were also stuck in the spawn zone, so
> collision for all the models needs tightening up. But I was able to jump up and then float
> on top of the firebase. The VC started running at the base and I was shooting them — no one
> fought besides me, not the VC and not my allies. Then I was stuck on top of the firebase
> with an invisible wall there. Overall it's starting to look really good. There are a few
> alignment issues with the main firebase mound, and we need to make sure you can shoot out
> the fire slit holes of sandbags and bunkers.

## Scope binding

This is the DEMO slice (`scripts/levels/demo_game.gd`, GameFlow.demo_mode, 512 m map), but
every defect below lives in the SHARED world-build path (ADR-028: one world-build path). A
fix here lands in the full 1280 m world too. Nothing in this session is demo-only.

## Pillars in force

- **Rule #1** — it must be FUN to walk and it must FEEL like Vietnam. Judged by EYES.
- **ADR-028** — one world-build path. No parallel firebase build for the demo.
- **ADR-023 (fossil law)** — when a system is replaced, the old one is DELETED, not left dark.
- **World foundation locked** — the unified world is IMPROVED, never rebuilt.

## The six matters put to the Council

1. Two layers of collision on the firebase.
2. Allies and garrison stuck at the spawn.
3. Player can climb onto an invisible surface above the base and is then walled in.
4. Nobody fights — not the garrison, not the squad, not the VC.
5. Alignment of the main firebase mound.
6. Shooting out through fire slits in sandbags and bunkers.
