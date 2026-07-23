# AI LIVING-WORLD ROADMAP

Source: `7 22 AI Future Improvements.txt` (Caleb's design manifesto, 2026-07-22).
This turns that philosophy into a prioritized, tagged backlog. Tags:
`[CODE]` GDScript, no art/owner input · `[ART]` needs Blender models/anims ·
`[OWNER]` needs a design/tuning decision from Caleb · `[BIG]` multi-session system.

**Thesis (his words):** *"The goal is not to create combat AI. The goal is to
simulate human lives during wartime."* The **95% Rule** — 95% of an NPC's life is
non-combat (guard duty, sandbags, digging, writing home, C-rations, patrols where
nothing happens); the 10-minute firefight matters *because* of the other 23h50m.

## What already exists (build on, don't rebuild)
- Combat AI: goal/state brain, think/execute LOD, suppression + alert tiers
  (`enemy_base.gd`), squad allies (`ally_base.gd`), now a shared `CombatPosture`
  and faction-blind suppression intake (this session).
- World sim spine: `sim_clock.gd` (time-of-day + schedules), `ambient_war.gd`
  (offscreen firefight ambience), `air_traffic.gd` (flyover scheduling), patrols,
  convoys (`convoy_spawner.gd` — flagged empty-vehicle-array bug), `AgentRegistry`.
- Radio broadcasts (`assets/audio/Radio Vietnam`) + the new field-radio prop.

## Priority backlog

### Tier 1 — highest immersion-per-cost, mostly CODE
1. **NPC purpose/activity states (Life First, #1 + 95% Rule)** `[BIG][CODE+ART]` —
   an idle "duty" layer over the combat brain: guard, dig, clean weapon, cook, haul,
   rest, smoke, cards, listen to radio. Combat INTERRUPTS; on all-clear, return to
   duty. Pure-code duties (guard/patrol/rest/watch) ship first; the rest gate on
   anims (see Tier-art). Hooks: `sim_clock` schedules, existing patrol code.
2. **Personality traits (#4)** `[CODE][OWNER]` — permanent per-NPC floats (bravery,
   discipline, aggression, patience, paranoia, fatigue-tolerance) on `EnemyData`/
   ally data; bias EXISTING decisions (cover gate, fire discipline, hold vs push,
   suppression recovery). Owner decides trait→behavior mappings. Two riflemen differ.
3. **Emotion/morale layer (#5)** `[CODE][OWNER]` — calm→suspicious→confident→scared→
   panicked→exhausted, shifted by events (friend dies, win, hunger, sleep). Partly
   overlaps suppression/morale already in `enemy_base`; extend, don't duplicate.
4. **Ambient micro-behaviors (#12)** `[ART]` — stretch, yawn, light a cigarette,
   swat mosquitoes, check watch, look at photo. Almost all need short idle anims
   (owner). Cheap to schedule once the clips exist.

### Tier 2 — world runs without the player (#2, #13)
5. **Offscreen camp/village routines** `[BIG][CODE]` — camps run shifts, meals,
   repairs; villages have day cycles; patrols leave on schedule; convoys move
   (fix the empty-vehicle-array bug first). Driven by `sim_clock`.
6. **Civilian lives (#8)** `[BIG][CODE+ART]` — wake, farm, cook, trade, travel, and
   react to military activity (hide/flee/mourn). Some anims needed.

### Tier 3 — memory & consequence (heavier data/persistence)
7. **NPC memory (#3)** `[BIG][OWNER]` — remember who they fought, where friends
   died, dangerous roads, recent ambushes; bias future behavior. Persistence-heavy.
8. **Relationships (#6)** `[BIG][OWNER]` — friend/leader/mentor/rival/family graph;
   a close death hits morale far harder than a stranger's.
9. **World history (#9)** `[BIG][OWNER]` — burned villages, mined roads, destroyed
   convoys/bridges persist and change future events. Ties into save system.
10. **Logistics create stories (#10)** `[BIG][OWNER]` — ammo/fuel/food/medicine/
    batteries consumed; supplies travel; destroying logistics changes battles.
11. **NPCs make mistakes (#11)** `[CODE][OWNER]` — misidentify sounds, lose
    confidence, get distracted, panic (code); trip/fumble (art). A taste call.

## Deferred from this session (AI-merge pass, 2026-07-22)
- **Part B — full enemy/ally class merge** into a shared `AICombatant` base
  (lift suppression → posture → cover-seek up, prune the ~2,500-line duplication).
  Part A (shared `CombatPosture` + faction-blind suppression) shipped; the
  structural base-class collapse is the follow-on. Stage it behind the AI probes.
- **True SUPPRESSED freeze-state for allies** `[OWNER]` — allies now crouch +
  seek cover + hold fire under pin, but have no hard "frozen" state like enemies.
  Adding one may make the squad feel frozen — Caleb's eyes needed before wiring it.
- **Dedicated cover-shooting anims** `[ART]` — pop-up-over-sandbags,
  lean-around-a-ruined-corner-and-fire. The current fix reuses crouch/peek/hold
  clips; these would elevate the read.
- **Seek-cover approach polish** — units used to commit the crouch/lean ~10m out;
  fixed this session (crouch only near cover, wall-lean only at a wall).
